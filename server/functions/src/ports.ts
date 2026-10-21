import type {Firestore} from "firebase-admin/firestore";
import type {Verdict} from "./eye";

/**
 * What the night records of a picture port: every try at a game's picture
 * for a band (a model's map, the pixel reader's, a written one), what was
 * wrong with it and what the eye made of it, and the drawing and render of
 * the try that was kept, so the dashboard can show why a day's picture is
 * the one it is (docs/superpowers/specs/2026-10-21-picture-ports-design.md).
 *
 * A port is staged a document of its own under `themes/{day}/ports/{portId}`
 * and published as `days/{day}/ports/{portId}`, where the day viewer (an
 * anonymous signed-in client, firestore.rules) reads it. One document a
 * port, never several in one: a shrunk JPEG is some 30 to 60 KB and a
 * document is capped at 1 MiB, but a band's tries and two drawings of it
 * are all a document should be asked to hold.
 */

export interface PortTry {
  /** Its number among the band's tries, from 0. */
  n: number;
  /** "map": a model's map off the drawing; "reader": the pixels read;
   *  "written": a model's own picture. */
  route: "map" | "reader" | "written";
  /** Why it was refused before the eye saw it; "" when it was not. */
  why: string;
  verdict?: Verdict;
  kept: boolean;
  /** What was thrown, when something was. */
  error?: string;
}

export interface Port {
  game: "hoop" | "jelly";
  band: number;
  thing: string;
  tries: PortTry[];
  /** The kept try's drawing and render, base64 JPEG shrunk as the vistas are. */
  source?: string;
  render?: string;
}

/** What was thrown, as a try records it: the message, cut short. */
export function said(e: unknown): string {
  return String(e instanceof Error ? e.message : e).slice(0, 300);
}

/** One line on the night's log for a try: its error, its refusal, or what
 *  the eye made of it. */
export function logTry(game: Port["game"], day: number, band: number, thing: string, t: PortTry): void {
  const what = t.error ?? (t.why !== "" ? t.why : `${t.verdict?.pick} ${t.verdict?.score}${t.kept ? ", kept" : ""}`);
  console.log(`${game}: day ${day}, band ${band}, ${thing} try ${t.n} (${t.route}): ${what}`);
}

/** A port's document id, the same staged and published. */
export function portId(p: Port): string {
  return `${p.game}${p.band}_${p.thing}`;
}

/** A port as the fields of its document: the tries as one JSON string, the
 *  drawing and render as they are, and nothing for what a port lacks
 *  (Firestore refuses undefined). */
function fields(p: Port): Record<string, unknown> {
  const doc: Record<string, unknown> = {game: p.game, band: p.band, thing: p.thing, tries: JSON.stringify(p.tries)};
  if (p.source !== undefined) doc.source = p.source;
  if (p.render !== undefined) doc.render = p.render;
  return doc;
}

/** Stages `ports` of `day`, a document each; a port made again replaces its
 *  document. */
export async function stagePorts(db: Firestore, day: number, ports: Port[]): Promise<void> {
  for (const p of ports) await db.doc(`themes/${day}/ports/${portId(p)}`).set(fields(p));
}

/**
 * Publishes every staged port of `day` once each (create(), never set(), as
 * the pictures are: a port already there is left, however it got there).
 * Returns how many port documents the day has after.
 */
export async function publishPorts(db: Firestore, day: number): Promise<number> {
  const staged = await db.collection(`themes/${day}/ports`).get();
  for (const from of staged.docs) {
    const to = db.doc(`days/${day}/ports/${from.id}`);
    try {
      await to.create(from.data());
    } catch (e) {
      if (!(await to.get()).exists) throw e;
    }
  }
  const after = (await db.collection(`days/${day}/ports`).count().get()).data().count;
  console.log(`themeday: day ${day}, ${after} ports published`);
  return after;
}
