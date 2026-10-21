import type {Firestore} from "firebase-admin/firestore";
import Beads = require("./beads");
import {makeJellies, MOULDS, Jelly} from "./jelly";
import {BANDS as HOOP_BANDS, HoopPicture, makeHoop} from "./hoop";
import {bySide, Picture, pixelBand, Pictures} from "./pictures";
import {makeTheme, Theme, themed, validTheme} from "./theme";
import {makeWords, Words} from "./words";
import {Port, publishPorts, stagePorts} from "./ports";
import {makeVista, TIMES as VISTA_TIMES, Vistas} from "./vistas";

/**
 * The daily theme at night (docs/superpowers/specs/2026-10-13-daily-theme-
 * design.md, stage 4): the theme, the word boards' words, Gumdrop's jellies,
 * Yarn Hoop's low-poly pictures (hoop.ts)
 * and the bead pictures, made a step at a time into a staging document,
 * `themes/{day}` (server only: firestore.rules denies it to every client),
 * and published once as the `pictures` content a phone reads
 * (`days/{day}/turns/pictures`, core/themed_pictures.gd). The day's four
 * painted vistas (vistas.ts) are staged a document each under
 * `themes/{day}/vistas/{time}` (four JPEGs would crowd the day's own
 * document) and published as `days/{day}/turns/vistas` once all four are
 * there (core/themed_vistas.gd). The jelly and hoop steps' port records
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
 * A step that made nothing is tried once more on a later run, then given up
 * on: the board deals its own for that place.
 */

/** The steps of a day, in order. */
export const STEPS: string[] = ["theme", "words",
  ...MOULDS.map((_, b) => `jelly${b}`), ...HOOP_BANDS.map((_, b) => `hoop${b}`), ...Beads.SIZES.map((s) => `pic${s}`),
  ...VISTA_TIMES.map((_, i) => `vista${i}`)];
/** Runs a step may have before it is given up on. */
const TRIES = 2;
/** A run starts no step past this: the longest step seen is some ten
 *  minutes (a picture band four on the emulator trial, its Pearl-sized
 *  ones longer on the Mac), and the function is given thirty. */
const START_BUDGET_MS = 15 * 60 * 1000;
/** How long a run holds the lease (the function's own timeout). */
const LEASE_MS = 30 * 60 * 1000;
/** Days back a new theme is told of. */
const RECENT = 30;

interface Staged {
  theme?: string;
  words?: string;
  jellies?: Record<string, string>;
  hoops?: Record<string, string>;
  pictures?: Record<string, string>;
  tries?: Record<string, number>;
  done?: string[];
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
 * reads as two places. True when the content is there after.
 */
export async function publishVistas(db: Firestore, day: number): Promise<boolean> {
  const doc = db.doc(`days/${day}/turns/vistas`);
  if ((await doc.get()).exists) return true;
  const theme = await stagedTheme(db, day);
  if (theme === null) return false;
  const times: Record<string, string> = {};
  for (const time of VISTA_TIMES) {
    const jpg = (await vista(db, day, time).get()).get("jpg");
    if (typeof jpg !== "string" || jpg === "") return false;
    times[time] = jpg;
  }
  const made: Vistas = {v: 1, theme: theme.id, name: theme.name, times: times as Vistas["times"]};
  try {
    await doc.create({json: JSON.stringify(made)});
  } catch (e) {
    if (!(await doc.get()).exists) throw e;
  }
  console.log(`themeday: day ${day} vistas published`);
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

/** One step of `day`; what it saves, and whether it made anything. */
async function runStep(db: Firestore, when: Date, day: number, step: string, s: Staged):
  Promise<{save: Record<string, unknown>; made: boolean}> {
  if (step === "theme") {
    const theme = await makeTheme(day, (await recent(db, when)).slice(0, 60));
    return {save: theme === null ? {} : {theme: JSON.stringify(theme)}, made: theme !== null};
  }
  const theme = parsed<Theme>(s.theme);
  if (!validTheme(theme)) return {save: {}, made: false};
  if (step === "words") {
    const got = await makeWords(theme);
    return {save: got.words === null ? {} : {words: JSON.stringify(got.words)}, made: got.words !== null};
  }
  if (step.startsWith("jelly")) {
    const band = step.slice("jelly".length);
    const got = await makeJellies(day, theme, Number(band));
    await stage(db, day, got.ports);
    const list = got.jellies[band] ?? [];
    return {save: list.length === 0 ? {} : {[`jellies.${band}`]: JSON.stringify(list)}, made: list.length > 0};
  }
  if (step.startsWith("hoop")) {
    const band = step.slice("hoop".length);
    const {picture, port} = await makeHoop(day, theme, Number(band));
    await stage(db, day, [port]);
    return {save: picture === null ? {} : {[`hoops.${band}`]: JSON.stringify(picture)}, made: picture !== null};
  }
  if (step.startsWith("vista")) {
    const time = VISTA_TIMES[Number(step.slice("vista".length))];
    const first = time === "morning" ? null : (await vista(db, day, "morning").get()).get("jpg");
    const morning = typeof first === "string" ? {mime: "image/jpeg", bytes: Buffer.from(first, "base64")} : null;
    // One painting a run: the step is tried again on a later run (TRIES).
    const got = await makeVista(day, theme, time, morning, undefined, 1);
    if (got.vista !== null) await vista(db, day, time).set({jpg: got.vista.bytes.toString("base64")});
    return {save: {}, made: got.vista !== null};
  }
  const size = step.slice("pic".length);
  const sizes: Record<string, Picture> = {};
  await pixelBand(day, theme, Beads.SIZES.indexOf(Number(size)), sizes, []);
  const pic = sizes[size];
  return {save: pic === undefined ? {} : {[`pictures.${size}`]: JSON.stringify(pic)}, made: pic !== undefined};
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
  if (!(await lease(db, t0))) {
    console.log("themeday: another run holds the lease");
    return;
  }
  try {
    for (let ahead = 0; ahead <= 2; ahead++) {
      const when = new Date(now.getTime() + ahead * 86400000);
      const day = keyOf(when);
      const ref = staging(db, day);
      for (const step of STEPS) {
        const s = ((await ref.get()).data() ?? {}) as Staged;
        if (finished(s)) break;
        if (s.done?.includes(step)) continue;
        if (Date.now() - t0 > START_BUDGET_MS) return;
        const tries = (s.tries?.[step] ?? 0) + 1;
        let out: {save: Record<string, unknown>; made: boolean} = {save: {}, made: false};
        try {
          out = await runStep(db, when, day, step, s);
        } catch (e) {
          console.error(`themeday: day ${day}, ${step} failed`, e);
        }
        const over = out.made || tries >= TRIES;
        // update() takes the dotted paths (jellies.0, pictures.24) as fields
        // of a map; the document is made first so it has one to update.
        await ref.set({}, {merge: true});
        await ref.update({...out.save, [`tries.${step}`]: tries,
          ...(over ? {done: [...(s.done ?? []), step]} : {})});
        console.log(`themeday: day ${day}, ${step} ${out.made ? "made" : over ? "given up" : "to try again"} in ${Math.round((Date.now() - t0) / 1000)} s`);
      }
      if (ahead <= 1) {
        await publishPictures(db, day, false);
        await publishVistas(db, day);
      }
    }
  } finally {
    await db.doc("themes/_lease").set({until: 0});
  }
}
