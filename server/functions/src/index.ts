import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

/** A score is an integer 0..100 inclusive, so the histogram has 101 buckets. */
export const BUCKETS = 101;
/** One Firestore document takes about one write a second. Ten shards give ten,
 *  and the rollup means a client still reads exactly one document. */
export const SHARDS = 10;

const LOCALES = ["en", "pt", "es"] as const;
type Locale = (typeof LOCALES)[number];

/**
 * FNV-1a, 32 bit. core/daily.gd computes the same hash over the same string,
 * so a phone that has never reached the network derives the same day's
 * content as the one that was published here.
 */
export function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** UTC yyyymmdd, the same key Daily.date_key() makes. */
export function dayKey(d: Date): number {
  return d.getUTCFullYear() * 10000 + (d.getUTCMonth() + 1) * 100 + d.getUTCDate();
}

/**
 * The published content, one entry per turn game. guess_number is the phase 0
 * stub and is deleted when How Big? lands.
 */
export const GAMES: Record<string, (day: number) => unknown> = {
  guess_number: (day) => ({
    answer: fnv1a(`guess_number|${day}`) % 101,
    prior: {mean: 50, spread: 28},
  }),
};

function turnDoc(day: number, game: string) {
  return db.doc(`days/${day}/turns/${game}`);
}

/** Tomorrow's content, written a day ahead so a missed night is not a blank day. */
export const publishDay = onSchedule("0 3 * * *", async () => {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  const day = dayKey(d);
  for (const [game, make] of Object.entries(GAMES)) {
    await turnDoc(day, game).set({json: JSON.stringify(make(day))});
  }
});

/**
 * One submit per player per game per day, written once. A repeat answers with
 * what is already stored rather than an error, which is what makes the
 * client's retry and its offline flush safe.
 */
export const submitTurn = onRequest({cors: false}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({error: "POST only"});
    return;
  }
  const authz = req.get("Authorization") ?? "";
  const token = authz.startsWith("Bearer ") ? authz.slice(7) : "";
  let uid: string;
  try {
    uid = (await getAuth().verifyIdToken(token)).uid;
  } catch {
    res.status(401).json({error: "bad token"});
    return;
  }

  const body = (req.body ?? {}) as Record<string, unknown>;
  const game = body.game;
  const day = body.day;
  const score = body.score;
  if (typeof game !== "string" || !(game in GAMES)) {
    res.status(400).json({error: "unknown game"});
    return;
  }
  if (!Number.isInteger(day) || (day as number) < 20260101) {
    res.status(400).json({error: "bad day"});
    return;
  }
  if (!Number.isInteger(score) || (score as number) < 0 || (score as number) >= BUCKETS) {
    res.status(400).json({error: "bad score"});
    return;
  }
  const locale: Locale = LOCALES.includes(body.locale as Locale) ?
    (body.locale as Locale) : "en";
  const theDay = day as number;
  const theScore = score as number;

  // One submit a second per player, whatever they are submitting to.
  const player = db.doc(`players/${uid}`);
  const now = Date.now();
  const seen = await player.get();
  if (seen.exists && now - (seen.get("lastSubmitMs") ?? 0) < 1000) {
    res.status(429).json({error: "too fast"});
    return;
  }
  await player.set({lastSubmitMs: now}, {merge: true});

  const submit = turnDoc(theDay, game).collection("submits").doc(uid);
  try {
    await submit.create({
      score: theScore,
      guess: body.guess ?? null,
      locale,
      at: FieldValue.serverTimestamp(),
    });
  } catch {
    // Already there: two flushes raced, or the player is retrying.
    const existing = await submit.get();
    res.json({ok: true, created: false, score: existing.get("score") ?? theScore});
    return;
  }

  const shard = Math.floor(Math.random() * SHARDS);
  await turnDoc(theDay, game).collection("shards").doc(String(shard)).set({
    count: FieldValue.increment(1),
    histogram: {[String(theScore)]: FieldValue.increment(1)},
    byLocale: {[locale]: FieldValue.increment(1)},
  }, {merge: true});

  res.json({ok: true, created: true, score: theScore});
});

/** Shards into the one document a client reads. Today and yesterday, because
 *  the day rolls over in UTC and somebody is always mid-turn. */
export const rollupTally = onSchedule("every 5 minutes", async () => {
  const now = new Date();
  const yesterday = new Date(now.getTime() - 86400000);
  for (const day of [dayKey(yesterday), dayKey(now)]) {
    for (const game of Object.keys(GAMES)) {
      const shards = await turnDoc(day, game).collection("shards").get();
      if (shards.empty) continue;
      const histogram = new Array<number>(BUCKETS).fill(0);
      const byLocale: Record<string, number> = {en: 0, pt: 0, es: 0};
      let count = 0;
      for (const s of shards.docs) {
        count += (s.get("count") as number) ?? 0;
        const h = (s.get("histogram") ?? {}) as Record<string, number>;
        for (const [k, v] of Object.entries(h)) {
          const i = Number(k);
          if (Number.isInteger(i) && i >= 0 && i < BUCKETS) histogram[i] += v;
        }
        const l = (s.get("byLocale") ?? {}) as Record<string, number>;
        for (const [k, v] of Object.entries(l)) byLocale[k] = (byLocale[k] ?? 0) + v;
      }
      await turnDoc(day, game).collection("tally").doc("current")
        .set({json: JSON.stringify({count, histogram, byLocale})});
    }
  }
});
