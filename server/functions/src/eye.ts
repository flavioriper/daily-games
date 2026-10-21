import {PNG} from "pngjs";
import {ask} from "./generate";
import {Theme, Thing} from "./theme";

/**
 * The eye: a reviewer model shown what the player will see (a render of the
 * picture's map, or the bead picture itself) and, when there is one, the
 * drawing it was made from. It names the thing among the day's things and a
 * decoy, and scores the picture the way a polished product is scored, so a
 * game keeps a picture only when it reads and looks finished
 * (docs/superpowers/specs/2026-10-21-picture-ports-design.md).
 */

export type Game = "hoop" | "jelly" | "pixel";

export interface Verdict {
  /** The choice it named, lower case, or "none". */
  pick: string;
  /** 0 to 10; 0 when the answer carried no number. */
  score: number;
  /** Empty unless something does not belong in a game for children. */
  wrong: string;
  /** One sentence on what would most improve it. */
  notes: string;
  /** It named the thing and found nothing wrong. */
  ok: boolean;
}

/** The score a picture needs to be kept, by game. The bead pictures are not
 *  gated on a score, only on the reviewer naming the thing (goal 5). */
export const FLOOR: Record<Game, number> = {hoop: 7, jelly: 7, pixel: 0};

/** Named beside the day's things, so a reviewer who cannot tell has
 *  somewhere to be wrong. */
export const DECOYS = ["umbrella", "bicycle", "guitar", "rocket", "anchor", "teapot", "kite", "snail"];

export function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** What the first picture is, in the reviewer's own words, by game. */
const SEEN: Record<Game, string> = {
  hoop: "a mesh of flat coloured panels",
  jelly: "a jelly of a few flat candy colours",
  pixel: "a small picture made of coloured squares, pixel art of very few squares, so it is rough",
};

/** The spike's two wordings of where a picture must belong, kept as they ran. */
const BELONG: Record<Game, string> = {hoop: "a game for children", jelly: "a children's game", pixel: "a game for children"};

const EYE = (game: Game, drawing: boolean) => `You review pictures for a children's puzzle game. You are shown the picture the player will see (${SEEN[game]})${drawing ? " and, after it, the drawing it was made from" : ""}. Judge the FIRST picture, strictly and honestly, as a polished product would be judged. Answer one JSON object: "pick" is which thing the first picture shows, exactly one of the choices given or "none"; "score" is 0 to 10 (10 is elegant, complete and polished, 7 is good enough to ship, under 5 is not); "wrong" is an empty string unless something does not belong in ${BELONG[game]}; "notes" is one sentence naming what would most improve it.`;

const RUBRIC: Record<Game, string> = {
  hoop: "A low-poly picture of the thing: the WHOLE thing is present with every part a child expects, in its true colours; the facets read as soft light and shade; nothing but the thing; it looks elegant and polished and faithful to the drawing.",
  jelly: "A flat jelly of the thing in a few candy colours: the silhouette is sharp, clean and true to the thing so a child names it at once; the parts are big and well proportioned; no stray blobs, slivers or ragged edges; it looks elegant and polished.",
  pixel: "You are shown one small picture made of coloured squares, from a children's puzzle game: pixel art of very few squares, so it is rough. Say honestly what you see. \"wrong\" is an empty string unless the picture shows something that does not belong in a game for children, or a letter, a word or a logo. Roughness is not wrong.",
};

const EYE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["pick", "score", "wrong", "notes"],
  properties: {pick: {type: "string"}, score: {type: "number"}, wrong: {type: "string"}, notes: {type: "string"}},
};

export const dataUrl = (mime: string, bytes: Buffer): string => `data:${mime};base64,${bytes.toString("base64")}`;

/** The reviewer's look at one picture. `render` is what the player sees and
 *  `source` the drawing it was made from, both data URLs. The choices are
 *  the day's things and one that is not, in an order fixed by the day. */
export async function judge(day: number, theme: Theme, thing: Thing, game: Game, render: string, source?: string): Promise<Verdict> {
  const names = theme.objects.map((o) => o.name.toLowerCase());
  const free = DECOYS.filter((d) => !names.some((n) => n.includes(d)));
  const decoy = free.length > 0 ? free[fnv1a(`${day}`) % free.length] : "none of these";
  const choices = [...names, decoy].sort((a, b) => fnv1a(`${day}${game}${a}`) - fnv1a(`${day}${game}${b}`));
  const got = await ask<{pick: string; score: number; wrong: string; notes: string}>({
    system: EYE(game, source !== undefined),
    prompt: `Rubric: ${RUBRIC[game]}\nChoices: ${choices.join(", ")}.`,
    schema: EYE_SCHEMA,
    role: "review",
    images: source === undefined ? [render] : [render, source],
  });
  const pick = String(got.pick ?? "").trim().toLowerCase();
  const score = Number.isFinite(Number(got.score)) ? Number(got.score) : 0;
  const wrong = String(got.wrong ?? "").trim();
  const notes = String(got.notes ?? "").trim();
  console.log(`eye: ${day}, ${game}, ${thing.name}: ${pick} ${score} — ${notes}`);
  return {pick, score, wrong, notes, ok: pick === thing.name.toLowerCase() && wrong === ""};
}

const rgb = (hex: string): number[] => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));

/** Fills a polygon (points already in pixels) a row at a time, a pixel
 *  covered when its centre is inside. */
export function scan(pts: number[][], size: number, paint: (x: number, y: number) => void): void {
  for (let y = 0; y < size; y++) {
    const xs: number[] = [];
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i];
      const b = pts[(i + 1) % pts.length];
      if ((a[1] <= y + 0.5) !== (b[1] <= y + 0.5)) xs.push(a[0] + (y + 0.5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]));
    }
    xs.sort((p, q) => p - q);
    for (let i = 0; i + 1 < xs.length; i += 2) {
      for (let x = Math.max(0, Math.round(xs[i])); x < Math.min(size, Math.round(xs[i + 1])); x++) paint(x, y);
    }
  }
}

/** Polygons as a PNG: points in a square of 100, filled in order over the
 *  background. With `outline`, every polygon's sides are laid over all the
 *  fills afterwards, each a thin quad `width` wide (in the 100 square) and
 *  a half width longer at both ends so corners close. */
export function renderPolygons(polys: {pts: number[][]; fill: string}[], size: number, background: string, outline?: {colour: string; width: number}): Buffer {
  const png = new PNG({width: size, height: size});
  const put = (c: number[]) => (x: number, y: number) => {
    const i = 4 * (y * size + x);
    png.data[i] = c[0];
    png.data[i + 1] = c[1];
    png.data[i + 2] = c[2];
    png.data[i + 3] = 255;
  };
  const k = size / 100;
  const bg = put(rgb(background));
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) bg(x, y);
  for (const p of polys) scan(p.pts.map(([x, y]) => [x * k, y * k]), size, put(rgb(p.fill)));
  if (outline !== undefined) {
    const ink = put(rgb(outline.colour));
    const half = outline.width / 2;
    for (const p of polys) {
      for (let i = 0; i < p.pts.length; i++) {
        const a = p.pts[i];
        const b = p.pts[(i + 1) % p.pts.length];
        const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
        if (len === 0) continue;
        const ux = (b[0] - a[0]) / len * half;
        const uy = (b[1] - a[1]) / len * half;
        const quad = [
          [a[0] - ux - uy, a[1] - uy + ux],
          [b[0] + ux - uy, b[1] + uy + ux],
          [b[0] + ux + uy, b[1] + uy - ux],
          [a[0] - ux + uy, a[1] - uy - ux],
        ];
        scan(quad.map(([x, y]) => [x * k, y * k]), size, ink);
      }
    }
  }
  return PNG.sync.write(png);
}
