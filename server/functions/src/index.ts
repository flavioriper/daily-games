import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {asked, makeDay} from "./acorn";
import {asked as pearlAsked, makeDay as pearlDay} from "./pearl";

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
 * The published content, one entry per game that has a day to publish.
 *
 * A day's document, once created, is what every player gets. `make` is
 * handed the day and what the game's last days published (newest first), so
 * a game whose day is written by a model can tell it what not to repeat. It
 * must not throw for want of a model: see acorn.ts, which answers from the
 * bank the game ships. docs/agents/turns-and-backend.md, "A day written by a
 * model", is the contract a new game follows.
 */
export const GAMES: Record<string, (day: number, recent: unknown[]) => Promise<unknown>> = {
  acorn: (day, recent) => makeDay(day, recent.flatMap(asked)),
  // Three days back and no further: good kinds are a few hundred, a day
  // takes twenty-six, and a writer forbidden ten days of them goes looking
  // among moons and cacti.
  pearl: (day, recent) => pearlDay(day, recent.slice(0, 3).flatMap(pearlAsked)),
};

/** How many days back a game is shown of itself. */
export const RECENT_DAYS = 10;

/**
 * Games that publish nothing and only keep a crowd: a daily board sends one
 * score a solve and reads the day's histogram back. Trestle sends its
 * bridge's cost as a share of the budget (0..100), one tally a difficulty,
 * so the level every player of that tally built on is the same one
 * (docs/superpowers/specs/2026-09-28-trestle-flat-design.md, section 9).
 */
export const SCORED = ["trestle_0", "trestle_1", "trestle_2", "trestle_3"];

/** Every game a submit may name and the rollup totals. */
export const TALLIED = [...Object.keys(GAMES), ...SCORED];

/** The longest string a guess may be. A guess is client data written under
 *  the player's own document, and anonymous sign-up is free and
 *  self-service, so anything unbounded here is a free blob store. */
export const GUESS_MAX_CHARS = 64;

/** A guess is a number, a short string, a bool, or nothing at all. It goes to
 *  the server untouched and comes back to the client untouched, so this is
 *  the only place its shape is decided. */
export function validGuess(g: unknown): boolean {
  if (g === null || g === undefined) return true;
  if (typeof g === "boolean") return true;
  if (typeof g === "number") return Number.isFinite(g);
  return typeof g === "string" && g.length <= GUESS_MAX_CHARS;
}

function turnDoc(day: number, game: string) {
  return db.doc(`days/${day}/turns/${game}`);
}

/**
 * Today's content and tomorrow's. Tomorrow is the point -- a day published a
 * night ahead means a missed night is not a blank day -- and today is the
 * repair: a run that threw, a paused scheduler or a first deploy landing
 * after 03:00 would otherwise leave a day nobody can write, since a v2
 * scheduled function cannot be hand-triggered.
 *
 * create(), never set(): a day already published is left exactly as it is.
 * Rewriting one would change the answer under players who had already
 * locked, for any game whose content is drawn rather than derived. An
 * ALREADY_EXISTS is the normal case and is swallowed; anything else throws,
 * so a genuine write failure fails the run instead of passing for a skip.
 */
export const publishDay = onSchedule({
  schedule: "0 3 * * *",
  // A written day is minutes, not the default's one: Golden Acorn's about
  // three and a half (acorn.ts: a band written, a band reviewed) and Pearl
  // Dive's about six (pearl.ts: some fifty requests, five at a time), so a
  // first night, which writes today and tomorrow, is near twenty. The most
  // a scheduled function is given.
  timeoutSeconds: 1800,
  memory: "512MiB",
  secrets: ["OPENROUTER_API_KEY"],
}, async () => {
  await publishDays(new Date());
});

function parsed(json: unknown): unknown {
  try {
    return JSON.parse(String(json));
  } catch {
    return null;
  }
}

/** What `game` published on the days before `day`, newest first. */
async function recentDays(game: string, day: Date): Promise<unknown[]> {
  const out: unknown[] = [];
  for (let back = 1; back <= RECENT_DAYS; back++) {
    const snap = await turnDoc(dayKey(new Date(day.getTime() - back * 86400000)), game).get();
    if (snap.exists) out.push(parsed(snap.get("json")));
  }
  return out;
}

/** The body of publishDay, apart from it so a harness can run the real thing:
 *  `functions:shell` cannot invoke a v2 scheduled function. A day already
 *  there is never made again -- making one may cost a model's time. */
export async function publishDays(now: Date): Promise<void> {
  const tomorrow = new Date(now.getTime() + 86400000);
  for (const when of [now, tomorrow]) {
    const day = dayKey(when);
    for (const [game, make] of Object.entries(GAMES)) {
      const doc = turnDoc(day, game);
      if ((await doc.get()).exists) continue;
      const content = await make(day, await recentDays(game, when));
      try {
        await doc.create({json: JSON.stringify(content)});
      } catch (e) {
        if (!(await doc.get()).exists) throw e;
      }
    }
  }
}

/**
 * One submit per player per game per day, written once. A repeat answers with
 * what is already stored rather than an error, which is what makes the
 * client's retry and its offline flush safe.
 *
 * maxInstances is the bill's ceiling. This is a public endpoint, and even a
 * request carrying a garbage token costs an invocation and a verifyIdToken
 * round trip before the 401, so a flood has to shed load rather than scale
 * spend. Concurrency stays at the v2 default: raising it above one needs a
 * whole CPU, and the instance ceiling is what actually bounds the cost.
 */
export const submitTurn = onRequest({
  cors: false,
  maxInstances: 10,
  memory: "256MiB",
}, async (req, res) => {
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
  if (typeof game !== "string" || !TALLIED.includes(game)) {
    res.status(400).json({error: "unknown game"});
    return;
  }
  if (!Number.isInteger(day)) {
    res.status(400).json({error: "bad day"});
    return;
  }
  // Only today or yesterday (UTC): create-once bounds nothing when the
  // caller picks the day, since every new day key is a fresh document. A
  // stale offline flush past that window is refused, not retried forever.
  const nowForDay = new Date();
  const today = dayKey(nowForDay);
  const yesterday = dayKey(new Date(nowForDay.getTime() - 86400000));
  if (day !== today && day !== yesterday) {
    res.status(400).json({error: "bad day"});
    return;
  }
  if (!Number.isInteger(score) || (score as number) < 0 || (score as number) >= BUCKETS) {
    res.status(400).json({error: "bad score"});
    return;
  }
  if (!validGuess(body.guess)) {
    res.status(400).json({error: "bad guess"});
    return;
  }
  const locale: Locale = LOCALES.includes(body.locale as Locale) ?
    (body.locale as Locale) : "en";
  const theDay = day as number;
  const theScore = score as number;

  // A repeat answers with what is already stored rather than an error or a
  // rate limit, which is what makes the client's retry and its offline
  // flush safe -- reading back your own stored score is something the
  // security rules already entitle the player to.
  const submit = turnDoc(theDay, game).collection("submits").doc(uid);
  const already = await submit.get();
  if (already.exists) {
    res.json({ok: true, created: false, score: already.get("score")});
    return;
  }

  // One submit a second per player, whatever they are submitting to. This
  // only bounds *new* submits; it must not stand between a retry and its
  // own already-stored answer, checked above.
  const player = db.doc(`players/${uid}`);
  const now = Date.now();
  const seen = await player.get();
  if (seen.exists && now - (seen.get("lastSubmitMs") ?? 0) < 1000) {
    res.status(429).json({error: "too fast"});
    return;
  }
  await player.set({lastSubmitMs: now}, {merge: true});

  // The submit and its place in the histogram are one write or neither. A
  // shard increment that threw after a successful create used to 500 with
  // the submit standing: the client retries, the retry takes the
  // idempotency path above, answers ok, and the queue drops the item -- so
  // the histogram stays one short for that day, silently and forever.
  const shard = turnDoc(theDay, game).collection("shards")
    .doc(String(Math.floor(Math.random() * SHARDS)));
  try {
    await db.runTransaction(async (tx) => {
      tx.create(submit, {
        score: theScore,
        guess: body.guess ?? null,
        locale,
        at: FieldValue.serverTimestamp(),
      });
      tx.set(shard, {
        count: FieldValue.increment(1),
        histogram: {[String(theScore)]: FieldValue.increment(1)},
        byLocale: {[locale]: FieldValue.increment(1)},
      }, {merge: true});
    });
  } catch {
    // Either the player already submitted, or the write genuinely failed.
    // The document itself is the only trustworthy answer: do not reason
    // from the error object, and never report the caller's own just-sent
    // score as though it were the stored one. A failure here counted
    // nothing, because the transaction rolled the create back with it.
    const existing = await submit.get();
    if (!existing.exists) {
      res.status(500).json({error: "write failed"});
      return;
    }
    res.json({ok: true, created: false, score: existing.get("score")});
    return;
  }

  res.json({ok: true, created: true, score: theScore});
});

/** Shards into the one document a client reads. Today and yesterday, because
 *  the day rolls over in UTC and somebody is always mid-turn. */
export const rollupTally = onSchedule("every 5 minutes", async () => {
  const now = new Date();
  const yesterday = new Date(now.getTime() - 86400000);
  for (const day of [dayKey(yesterday), dayKey(now)]) {
    for (const game of TALLIED) {
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
