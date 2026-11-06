import type {Firestore} from "firebase-admin/firestore";
import Beads = require("./beads");
import type {Jelly} from "./jelly";
import {BANDS as HOOP_BANDS, HoopPicture, makeHoop} from "./hoop";
import {bySide, Picture, pixelBand, Pictures} from "./pictures";
import {makeCast, makeTheme, Theme, themed, validTheme} from "./theme";
import {dayList, DayThing, grow, makeThings, pool} from "./things";
import {makeWords, Words} from "./words";
import {Port, publishPorts, stagePorts} from "./ports";
import {seeded} from "./cast";
import {boxOf, HEADER_KEY, makeHeader, makeVista, TIMES as VISTA_TIMES, Vistas} from "./vistas";

/**
 * The daily theme at night (docs/superpowers/specs/2026-10-13-daily-theme-
 * design.md, stage 4): the theme, the word boards' words,
 * Yarn Hoop's low-poly pictures (hoop.ts)
 * and the bead pictures, made a step at a time into a staging document,
 * `themes/{day}` (server only: firestore.rules denies it to every client),
 * and published once as the `pictures` content a phone reads
 * (`days/{day}/turns/pictures`, core/themed_pictures.gd). The day's four
 * painted vistas (vistas.ts) are staged a document each under
 * `themes/{day}/vistas/{time}` (four JPEGs would crowd the day's own
 * document) and published as `days/{day}/turns/vistas` once all four are
 * there (core/themed_vistas.gd). The hoop steps' port records
 * (ports.ts) are staged a document each under `themes/{day}/ports/{id}` and
 * published as `days/{day}/ports/{id}` with the pictures.
 *
 * Why steps: a pixel picture day took 26 to 39 minutes on the Mac (Vertex
 * draws two a minute), and a scheduled function is given 1,800 s. So
 * `themeWork` runs every half hour and does the next step not yet done, for
 * today, tomorrow and the day after, until its own budget is spent; each
 * step is saved as it ends. The day after tomorrow is the point: its theme
 * is there a whole day before the quizzes (publishDays, 03:00) are written
 * on it, and its pictures a day before they are published.
 *
 * A step that did not make all it should is tried again on a later run, up
 * to TRIES, keeping what it has (the user, 2026-11-02: a player meets the
 * bank only in a critical case). A day is published when it is finished, or
 * at CLOSING the evening before with what it has, so a phone holds it when
 * the day turns; a day that has come and is published is not worked on. The
 * afternoon, dusk and night vistas are edits of the morning: they are not
 * run, and no try is counted, while the morning is neither done nor given up.
 * The `header` step (the menu header's own painting, the place from farther
 * away) needs no morning and is staged beside the four; it is optional when
 * publishing, but a day waits for it like any step.
 *
 * The paintings come first (the user, 2026-11-06: "start the new theme by
 * the images, if none pass after some retries, go for another theme"): right
 * after the theme, the morning vista; a morning turned down on RECAST_AFTER
 * runs is painted on with a new cast line (makeCast), and one given up after
 * MORNING_RUNS throws the theme away for a new one (retheme), up to THEMES a
 * day, while the day is still RETHEME_LEAD_MS off. Only then is anything
 * else spent on the theme. The last theme a day may have keeps going without
 * its paintings, so a day is never left without a theme.
 */

/** The steps of a day, in order. */
export const STEPS: string[] = ["theme", ...VISTA_TIMES.map((_, i) => `vista${i}`), HEADER_KEY,
  "words", "things", ...HOOP_BANDS.map((_, b) => `hoop${b}`), ...Beads.SIZES.map((s) => `pic${s}`)];
/** Runs a step may have before it is given up on. */
const TRIES = 6;
/** Runs the morning vista may have (two paintings a run) before the theme is
 *  given up on: eight paintings, the last four on new cast lines. */
const MORNING_RUNS = 4;
/** Morning runs turned down before the cast line is written again, every run after. */
const RECAST_AFTER = 2;
/** Themes a day may go through for want of a morning that passes. */
const THEMES = 3;
/** A day is given a new theme only while its start is this far off: the
 *  quizzes are written on the staged theme at 03:00 the day before
 *  (publishDay), 21 hours ahead, and must not be written on a dropped one. */
const RETHEME_LEAD_MS = 22 * 60 * 60 * 1000;
/** The UTC hour the eve of a day publishes what it has: the day turns at
 *  00:00, and two half-hour runs a phone's fetch ahead is room enough. */
const CLOSING = 22;
/** A run starts no step past this: the longest step seen is some ten
 *  minutes (a picture band four on the emulator trial, its Pearl-sized
 *  ones longer on the Mac), and the function is given thirty. */
const START_BUDGET_MS = 15 * 60 * 1000;
/** How long a run holds the lease (the function's own timeout). */
const LEASE_MS = 30 * 60 * 1000;
/** The room a run keeps before its lease ends, past the last call a port
 *  begins: a map ask begun just before then may run its 240 s timeout with
 *  the SDK's retries, and the step must still be counted, the lease let go
 *  and the run's publish made before the platform ends the function. */
const RUN_ROOM_MS = 6 * 60 * 1000;
/** Days back a new theme is told of. */
const RECENT = 30;

interface Staged {
  theme?: string;
  words?: string;
  things?: string;
  jellies?: Record<string, string>;
  hoops?: Record<string, string>;
  pictures?: Record<string, string>;
  tries?: Record<string, number>;
  done?: string[];
  /** Cast lines the morning was painted on and turned down for. */
  casts?: string[];
  /** themed() of the themes this day threw away for want of paintings. */
  dropped?: string[];
  /** How many themes this day has gone through, the staged one included. */
  themes?: number;
}

function staging(db: Firestore, day: number) {
  return db.doc(`themes/${day}`);
}

function parsed<T>(json: unknown): T | null {
  try {
    return typeof json === "string" ? JSON.parse(json) as T : null;
  } catch {
    return null;
  }
}

/** The staged theme of `day`, or null. */
export async function stagedTheme(db: Firestore, day: number): Promise<Theme | null> {
  const t = parsed<Theme>((await staging(db, day).get()).get("theme"));
  return validTheme(t) ? t : null;
}

/** Whether every step of a staged day has run its course. */
function finished(s: Staged): boolean {
  if (s.done?.includes("theme") && s.theme === undefined) return true;
  return STEPS.every((step) => s.done?.includes(step));
}

/** True for every step after the morning vista while the morning is neither
 *  done nor given up (both put "vista0" in `done`): the afternoon, dusk and
 *  night are edits of it, and since 2026-11-06 nothing else is spent on a
 *  theme that may yet be thrown away for want of a morning. They are not run
 *  and no try is counted; the day is not `finished` meanwhile, so it waits. */
function waitsForMorning(step: string, s: Staged): boolean {
  return step !== "theme" && step !== "vista0" && !s.done?.includes("vista0");
}

/** The `pictures` content a staged day comes to, or null with no theme. */
function content(s: Staged): Pictures | null {
  const theme = parsed<Theme>(s.theme);
  if (!validTheme(theme)) return null;
  const sizes: Record<string, Picture> = {};
  for (const [size, json] of Object.entries(s.pictures ?? {})) {
    const p = parsed<Picture>(json);
    if (p !== null) sizes[size] = p;
  }
  bySide(sizes, []);
  const doc: Pictures = {v: 1, theme: theme.id, sizes};
  const jellies: Record<string, Jelly[]> = {};
  for (const [band, json] of Object.entries(s.jellies ?? {})) {
    const list = parsed<Jelly[]>(json);
    if (list !== null && list.length > 0) jellies[band] = list;
  }
  if (Object.keys(jellies).length > 0) doc.jellies = jellies;
  const hoops: Record<string, HoopPicture> = {};
  for (const [band, json] of Object.entries(s.hoops ?? {})) {
    const h = parsed<HoopPicture>(json);
    if (h !== null) hoops[band] = h;
  }
  if (Object.keys(hoops).length > 0) doc.hoops = hoops;
  const words = parsed<Words>(s.words);
  if (words !== null) doc.words = words;
  const things = parsed<DayThing[]>(s.things);
  if (things !== null && things.length > 0) doc.things = things;
  return doc;
}

/**
 * Publishes `day`'s `pictures` content from its staging, once (create(),
 * never set(), as publishDays does): only when every step has run, unless
 * `now` (the day has come, and what there is is better than nothing).
 * True when the content is there after.
 */
export async function publishPictures(db: Firestore, day: number, now: boolean): Promise<boolean> {
  const doc = db.doc(`days/${day}/turns/pictures`);
  if ((await doc.get()).exists) {
    await portsOf(db, day);
    return true;
  }
  const s = ((await staging(db, day).get()).data() ?? {}) as Staged;
  if (!now && !finished(s)) return false;
  const made = content(s);
  if (made === null) return false;
  try {
    await doc.create({json: JSON.stringify(made)});
  } catch (e) {
    if (!(await doc.get()).exists) throw e;
  }
  console.log(`themeday: day ${day} published, ${Object.keys(made.sizes).join("/") || "no"} pictures`);
  await portsOf(db, day);
  return true;
}

/** The ports of a day whose pictures are published, so a late one still
 *  lands. They are the dashboard's, not the phone's: one that cannot be
 *  published is told of and does not undo the pictures. */
async function portsOf(db: Firestore, day: number): Promise<void> {
  try {
    await publishPorts(db, day);
  } catch (e) {
    console.error(`themeday: day ${day}, ports not published`, e);
  }
}

function vista(db: Firestore, day: number, time: string) {
  return db.doc(`themes/${day}/vistas/${time}`);
}

/**
 * Publishes `day`'s vistas from their staging, once, and only when all four
 * times were painted: a ladder half the day's and half the bundled vistas
 * reads as two places. The header's painting rides along when one passed and
 * is staged; a day without one keeps the phone's dusk behind the header.
 * True when the content is there after.
 */
export async function publishVistas(db: Firestore, day: number): Promise<boolean> {
  const doc = db.doc(`days/${day}/turns/vistas`);
  if ((await doc.get()).exists) return true;
  const theme = await stagedTheme(db, day);
  if (theme === null) return false;
  const times: Record<string, string> = {};
  const boxes: NonNullable<Vistas["boxes"]> = {};
  for (const time of VISTA_TIMES) {
    const staged = await vista(db, day, time).get();
    const jpg = staged.get("jpg");
    if (typeof jpg !== "string" || jpg === "") return false;
    times[time] = jpg;
    const box = boxOf(staged.get("box"));
    if (box !== null) boxes[time] = box;
  }
  const made: Vistas = {v: 1, theme: theme.id, name: theme.name, times: times as Vistas["times"],
    cast: seeded(day)};
  if (Object.keys(boxes).length > 0) made.boxes = boxes;
  const head = (await vista(db, day, HEADER_KEY).get()).get("jpg");
  if (typeof head === "string" && head !== "") made.header = head;
  try {
    await doc.create({json: JSON.stringify(made)});
  } catch (e) {
    if (!(await doc.get()).exists) throw e;
  }
  console.log(`themeday: day ${day} vistas published${made.header === undefined ? "" : " with the header"}`);
  return true;
}

/** themed() of the staged days before `day`, newest first. */
async function recent(db: Firestore, day: Date): Promise<string[]> {
  const out: string[] = [];
  for (let back = 1; back <= RECENT; back++) {
    const t = await stagedTheme(db, keyOf(new Date(day.getTime() - back * 86400000)));
    if (t !== null) out.push(...themed(t));
  }
  return out;
}

function keyOf(d: Date): number {
  return d.getUTCFullYear() * 10000 + (d.getUTCMonth() + 1) * 100 + d.getUTCDate();
}

/** Stages a step's ports; one that cannot be staged is told of and does not
 *  lose the picture the step made. */
async function stage(db: Firestore, day: number, ports: Port[]): Promise<void> {
  try {
    await stagePorts(db, day, ports);
  } catch (e) {
    console.error(`themeday: day ${day}, ports not staged`, e);
  }
}

/** One step of `day`; what it saves, and whether it made anything. `until`
 *  is when the ports must begin their last call (absolute ms). */
async function runStep(db: Firestore, when: Date, day: number, step: string, s: Staged, until: number):
  Promise<{save: Record<string, unknown>; made: boolean}> {
  if (step === "theme") {
    const theme = await makeTheme(day, [...(s.dropped ?? []), ...(await recent(db, when))].slice(0, 60));
    return {save: theme === null ? {} : {theme: JSON.stringify(theme)}, made: theme !== null};
  }
  let theme = parsed<Theme>(s.theme);
  if (!validTheme(theme)) return {save: {}, made: false};
  if (step === "words") {
    const got = await makeWords(theme);
    return {save: got.words === null ? {} : {words: JSON.stringify(got.words)}, made: got.words !== null};
  }
  if (step === "things") {
    // New things join the pool as they are made; the day carries them and a
    // few of the pool's. A run that makes none still stages the pool's.
    const held = await pool(db);
    const got = await makeThings(day, theme, held);
    await grow(db, got.things);
    const list = dayList(day, got.things, held);
    return {save: list.length === 0 ? {} : {things: JSON.stringify(list)}, made: got.things.length > 0};
  }
  if (step.startsWith("hoop")) {
    const band = step.slice("hoop".length);
    const {picture, port} = await makeHoop(day, theme, Number(band), undefined, until);
    await stage(db, day, [port]);
    return {save: picture === null ? {} : {[`hoops.${band}`]: JSON.stringify(picture)}, made: picture !== null};
  }
  if (step === HEADER_KEY) {
    const got = await makeHeader(day, theme, undefined, 2);
    if (got.vista !== null) await vista(db, day, HEADER_KEY).set({jpg: got.vista.bytes.toString("base64")});
    return {save: {}, made: got.vista !== null};
  }
  if (step.startsWith("vista")) {
    const time = VISTA_TIMES[Number(step.slice("vista".length))];
    const first = time === "morning" ? null : (await vista(db, day, "morning").get()).get("jpg");
    const morning = typeof first === "string" ? {mime: "image/jpeg", bytes: Buffer.from(first, "base64")} : null;
    // A morning turned down run after run is most often the cast line's
    // fault (a pair asked to hold or reach for a thing): write another.
    const recast: Record<string, unknown> = {};
    if (time === "morning" && (s.tries?.[step] ?? 0) >= RECAST_AFTER) {
      const tried = [...(s.casts ?? []), ...(theme.cast === undefined ? [] : [theme.cast])];
      const cast = await makeCast(theme, tried);
      console.log(`themeday: day ${day}, new cast line: ${cast}`);
      theme = {...theme, cast};
      recast.theme = JSON.stringify(theme);
      recast.casts = tried;
    }
    // The morning is painted twice a run (the reviewer counts its Peeplets and
    // limbs), the others once: a step is tried again on a later run (TRIES).
    const got = await makeVista(day, theme, time, morning, undefined, time === "morning" ? 2 : 1);
    if (got.vista !== null) {
      await vista(db, day, time).set({jpg: got.vista.bytes.toString("base64"), ...(got.box === null ? {} : {box: got.box})});
    }
    return {save: recast, made: got.vista !== null};
  }
  const size = step.slice("pic".length);
  const sizes: Record<string, Picture> = {};
  await pixelBand(day, theme, Beads.SIZES.indexOf(Number(size)), sizes, []);
  const pic = sizes[size];
  return {save: pic === undefined ? {} : {[`pictures.${size}`]: JSON.stringify(pic)}, made: pic !== undefined};
}

/**
 * Throws `day`'s staged theme away for a new one: the staging and what is
 * under it (the vistas, the ports) are deleted, and the next run of the
 * theme step is told of the dropped theme. True when it did; false when the
 * day has had THEMES, its pictures are published, or it is too close.
 */
async function retheme(db: Firestore, now: Date, day: number, s: Staged): Promise<boolean> {
  const count = s.themes ?? 1;
  if (count >= THEMES) return false;
  const start = Date.UTC(Math.floor(day / 10000), Math.floor(day / 100) % 100 - 1, day % 100);
  if (start - now.getTime() < RETHEME_LEAD_MS) return false;
  if ((await db.doc(`days/${day}/turns/pictures`).get()).exists) return false;
  const dropped = [...(s.dropped ?? []), ...themed(parsed<Theme>(s.theme))];
  const ref = staging(db, day);
  await db.recursiveDelete(ref);
  await ref.set({dropped, themes: count + 1});
  console.log(`themeday: day ${day}, no morning passed, theme ${count} dropped for a new one`);
  return true;
}

/** Takes the lease for a run, or false when another run holds it. */
async function lease(db: Firestore, now: number): Promise<boolean> {
  const ref = db.doc("themes/_lease");
  return db.runTransaction(async (tx) => {
    const until = Number((await tx.get(ref)).get("until") ?? 0);
    if (until > now) return false;
    tx.set(ref, {until: now + LEASE_MS});
    return true;
  });
}

/**
 * The body of themeWork: the next steps of today, tomorrow and the day
 * after, earliest day first, until the budget is spent; a day finished by
 * this run that is today or tomorrow is published at once.
 */
export async function themeWork(db: Firestore, now: Date): Promise<void> {
  const t0 = Date.now();
  const until = t0 + LEASE_MS - RUN_ROOM_MS;
  if (!(await lease(db, t0))) {
    console.log("themeday: another run holds the lease");
    return;
  }
  try {
    for (let ahead = 0; ahead <= 2; ahead++) {
      const when = new Date(now.getTime() + ahead * 86400000);
      const day = keyOf(when);
      const ref = staging(db, day);
      if (ahead === 0 && (await db.doc(`days/${day}/turns/pictures`).get()).exists) continue;
      again: for (;;) {
      // A morning given up (now, or on a run before this rule) throws the
      // theme away while there is time for another.
      const at = ((await ref.get()).data() ?? {}) as Staged;
      if (at.done?.includes("vista0") && at.theme !== undefined && !(await vista(db, day, "morning").get()).exists &&
        await retheme(db, now, day, at)) continue again;
      for (const step of STEPS) {
        const s = ((await ref.get()).data() ?? {}) as Staged;
        if (finished(s)) break;
        if (s.done?.includes(step)) continue;
        if (waitsForMorning(step, s)) continue;
        if (Date.now() - t0 > START_BUDGET_MS) return;
        const tries = (s.tries?.[step] ?? 0) + 1;
        const most = step === "vista0" ? MORNING_RUNS : TRIES;
        let out: {save: Record<string, unknown>; made: boolean} = {save: {}, made: false};
        try {
          out = await runStep(db, when, day, step, s, until);
        } catch (e) {
          console.error(`themeday: day ${day}, ${step} failed`, e);
        }
        const over = out.made || tries >= most;
        // update() takes the dotted paths (jellies.0, pictures.24) as fields
        // of a map; the document is made first so it has one to update.
        await ref.set({}, {merge: true});
        await ref.update({...out.save, [`tries.${step}`]: tries,
          ...(over ? {done: [...(s.done ?? []), step]} : {})});
        console.log(`themeday: day ${day}, ${step} ${out.made ? "made" : over ? "given up" : "to try again"} in ${Math.round((Date.now() - t0) / 1000)} s`);
        if (step === "vista0" && over && !out.made) continue again;
      }
      break;
      }
      if (ahead <= 1) {
        await publishPictures(db, day, ahead === 0 || now.getUTCHours() >= CLOSING);
        await publishVistas(db, day);
      }
    }
  } finally {
    await db.doc("themes/_lease").set({until: 0});
  }
}
