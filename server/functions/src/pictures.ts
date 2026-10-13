import jpeg from "jpeg-js";
import {PNG} from "pngjs";
import Beads = require("./beads");
import {ask, available, draw, Drawing} from "./generate";
import {Theme, Thing} from "./theme";

/**
 * The day's bead pictures, for Pixel Garden, Button Box and Toy Cannons
 * (docs/superpowers/specs/2026-10-13-daily-theme-design.md). The levels
 * zoom out: three single things from the theme's scene at 10, 12 and 16
 * squares, and the scene itself at 24 and 32.
 *
 * An image model draws; tools/beads.js (the dashboard's Picture maker, the
 * same file) makes the drawing into beads; and a picture is published only
 * when it keeps the bank's rules and a second model, shown the beads and
 * never the drawing, sees in them what was asked for. A size whose drafts
 * all fail is left out, and the board deals that level from its bank.
 */

export interface Picture {
  /** The thing's id, or "scene". */
  id: string;
  rows: string[];
}

export interface Pictures {
  v: 1;
  theme: string;
  /** By size: "10", "12", "16", "24", "32". A size not here is the bank's. */
  sizes: Record<string, Picture>;
}

/** What became of one size of one draft: for the dashboard, not the phone. */
export interface Tried {
  size: number;
  rows: string[];
  checks: Beads.Check[];
  /** What the blind look said; absent when the rules already turned it down. */
  look?: {said: string; wrong: string; ok: boolean};
  kept: boolean;
}

export interface Draft {
  /** The thing's id, or "scene". */
  what: string;
  draft: number;
  /** The drawing's file, when the caller kept it. */
  file?: string;
  error?: string;
  tried: Tried[];
}

/** Drawings of one thing before its sizes are the bank's: two days of four
 *  things must end inside the function's 1,800 seconds. */
export const DRAFTS = 3;

/** Named beside the day's three things, so a reviewer who cannot tell has
 *  somewhere to be wrong. */
const DECOYS = ["umbrella", "bicycle", "guitar", "rocket", "anchor", "teapot", "kite", "snail"];

/** At the most this many decoys share a word with the day's things. */
const THINGS_AT_MOST = 3;

/** The colours a thing is asked to be drawn in, by the size it is for: the
 *  most its band lets a picture have. */
const INKS: Record<number, string> = {10: "four", 12: "five", 16: "seven"};

const OBJECT = (what: string, size: number) => `Draw ONE thing: ${what}. Alone, centred and large on a plain pure white background. A children's sticker drawing: flat solid colours, a thick dark brown outline, chunky simple shapes, in exactly ${INKS[size]} clearly different colours, each over a good part of it. No shading, no gradients, no highlights, no shadow under it, no white sticker border round it, nothing else in the picture, no text or letters. A square picture.`;

const SCENE = (what: string) => `Draw this scene as a flat children's illustration that fills the whole square picture from edge to edge, with no border, no frame and no white margin: ${what} Flat solid colours with thick dark brown outlines, a few big simple shapes, eight to ten clearly different colours and no one colour over a third of the picture. No shading, no gradients, no text or letters, no faces.`;

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** A drawing's pixels, whichever of the two formats the model answered in. */
export function decoded(d: Drawing): {data: Uint8Array; width: number; height: number} {
  if (d.mime === "image/png") {
    const png = PNG.sync.read(d.bytes);
    return {data: png.data, width: png.width, height: png.height};
  }
  return jpeg.decode(d.bytes, {useTArray: true, maxMemoryUsageInMB: 512});
}

/** A picture's rows as a PNG a model can look at: a square of colour a
 *  bead, bare linen where there is none. */
export function shown(rows: string[]): string {
  const n = rows.length;
  const cell = Math.max(8, Math.floor(448 / n));
  const png = new PNG({width: n * cell, height: n * cell});
  for (let y = 0; y < n * cell; y++) {
    for (let x = 0; x < n * cell; x++) {
      const ch = rows[Math.floor(y / cell)][Math.floor(x / cell)];
      const hex = ch === "." ? "efe2c6" : Beads.PALETTE[ch] ?? "ff00ff";
      const i = 4 * (y * n * cell + x);
      png.data[i] = parseInt(hex.slice(0, 2), 16);
      png.data[i + 1] = parseInt(hex.slice(2, 4), 16);
      png.data[i + 2] = parseInt(hex.slice(4, 6), 16);
      png.data[i + 3] = 255;
    }
  }
  return `data:image/png;base64,${PNG.sync.write(png).toString("base64")}`;
}

const LOOKER = `You are shown one small picture made of coloured squares, from a children's puzzle game: pixel art of very few squares, so it is rough. Say honestly what you see; you are not told what it is meant to be. "wrong" is an empty string unless the picture shows something that does not belong in a game for children, or a letter, a word or a logo. Roughness is not wrong.`;

const PICK_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["pick", "wrong"],
  properties: {pick: {type: "string"}, wrong: {type: "string"}},
};

const SEES_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["sees", "wrong"],
  properties: {sees: {type: "string"}, wrong: {type: "string"}},
};

const SAME_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["same"],
  properties: {same: {type: "boolean"}},
};

/** A single thing: the reviewer picks among the day's three and one that
 *  is not the day's. A mug of a hundred squares is named by nobody cold. */
async function lookThing(day: number, rows: string[], thing: Thing, theme: Theme): Promise<NonNullable<Tried["look"]>> {
  const names = theme.objects.map((o) => o.name.toLowerCase());
  const decoy = DECOYS.filter((d) => !names.some((n) => n.includes(d)))[fnv1a(`${day}`) % (DECOYS.length - THINGS_AT_MOST)];
  const choices = [...names, decoy].sort((a, b) => fnv1a(`${day}${rows.length}${a}`) - fnv1a(`${day}${rows.length}${b}`));
  const got = await ask<{pick: string; wrong: string}>({
    system: LOOKER,
    prompt: `Which one of these is it? Answer "pick" with exactly one of: ${choices.join(", ")}, or "none" if it is none of them.`,
    schema: PICK_SCHEMA,
    role: "review",
    images: [shown(rows)],
  });
  const said = String(got.pick ?? "").trim().toLowerCase();
  const wrong = String(got.wrong ?? "").trim();
  return {said, wrong, ok: said === thing.name.toLowerCase() && wrong === ""};
}
/** The scene: the reviewer says what it sees, and a second question, with
 *  no picture, asks whether that is the scene that was asked for. */
async function lookScene(rows: string[], theme: Theme): Promise<NonNullable<Tried["look"]>> {
  const got = await ask<{sees: string; wrong: string}>({
    system: LOOKER,
    prompt: `What does the picture show? Answer "sees" in one sentence: the place and the main things in it.`,
    schema: SEES_SCHEMA,
    role: "review",
    images: [shown(rows)],
  });
  const said = String(got.sees ?? "").trim();
  const wrong = String(got.wrong ?? "").trim();
  if (said === "" || wrong !== "") return {said, wrong, ok: false};
  const judged = await ask<{same: boolean}>({
    system: `You compare two descriptions of a picture. "same" is true when the second could fairly be a rough, low-detail view of the first: the same kind of place (outdoors on grass, a kitchen, a beach) and at least one of its main things. The second was said of a picture of very few squares, so a small thing in it is often taken for another of its size and colour (a teapot for a duck, a basket for a bench): that alone is not a difference. It is false when the second is another kind of place, or names none of the first's main things.`,
    prompt: `Asked for: ${theme.scene}\nSeen: ${said}`,
    schema: SAME_SCHEMA,
    role: "review",
  });
  return {said, wrong, ok: judged.same === true};
}

/**
 * The day's pictures and what became of every draft. `keep` is handed each
 * drawing and answers the name it was kept under (the dashboard's run keeps
 * them; the night does not). Never throws; `doc` is null when no size came
 * through, or there is no model.
 */
export async function makeDay(day: number, theme: Theme,
  keep?: (name: string, d: Drawing) => string): Promise<{doc: Pictures | null; drafts: Draft[]}> {
  const drafts: Draft[] = [];
  if (!available()) return {doc: null, drafts};
  const sizes: Record<string, Picture> = {};
  const plan: {what: string; thing: Thing | null; prompt: string; sizes: number[]}[] = [
    ...theme.objects.map((o, i) => ({what: o.id, thing: o, prompt: OBJECT(o.draw, [10, 12, 16][i]), sizes: [[10], [12], [16]][i]})),
    {what: "scene", thing: null, prompt: SCENE(theme.scene), sizes: [24, 32]},
  ];
  for (const item of plan) {
    for (let n = 0; n < DRAFTS && item.sizes.some((s) => sizes[s] === undefined); n++) {
      const draft: Draft = {what: item.what, draft: n, tried: []};
      drafts.push(draft);
      try {
        const drawing = await draw(item.prompt);
        if (keep !== undefined) draft.file = keep(`${day}_${item.what}_${n}`, drawing);
        const px = decoded(drawing);
        for (const size of item.sizes) {
          if (sizes[size] !== undefined) continue;
          // A thing is laid with a bare square round it, and edge to edge
          // when that leaves it too small for the rules (a tent is half its box).
          let rows: string[] = [];
          let checks: Beads.Check[] = [];
          for (const margin of item.thing === null ? [0] : [1, 0]) {
            rows = Beads.convert(px.data, px.width, px.height, {...Beads.optionsFor(size), margin}).rows;
            checks = Beads.check(rows, size);
            if (checks.every((c) => c.ok)) break;
          }
          const tried: Tried = {size, rows, checks, kept: false};
          draft.tried.push(tried);
          if (!tried.checks.every((c) => c.ok)) continue;
          tried.look = item.thing === null ? await lookScene(rows, theme) : await lookThing(day, rows, item.thing, theme);
          if (!tried.look.ok) continue;
          tried.kept = true;
          sizes[size] = {id: item.what, rows};
        }
      } catch (e) {
        draft.error = String(e).slice(0, 300);
        console.error(`pictures: day ${day}, ${item.what}, draft ${n} failed`, e);
      }
    }
  }
  const got = Object.keys(sizes);
  console.log(`pictures: day ${day} (${theme.id}), kept ${got.join("/") || "none"} in ${drafts.length} drawings`);
  return {doc: got.length > 0 ? {v: 1, theme: theme.id, sizes} : null, drafts};
}
