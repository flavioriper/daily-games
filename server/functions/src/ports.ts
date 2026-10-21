import type {Verdict} from "./eye";

/**
 * What the night records of a picture port: every try at a game's picture
 * for a band (a model's map, the pixel reader's, a written one), what was
 * wrong with it and what the eye made of it, and the drawing and render of
 * the try that was kept, so the dashboard can show why a day's picture is
 * the one it is (docs/superpowers/specs/2026-10-21-picture-ports-design.md).
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
