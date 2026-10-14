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
  /** What a board calls it: the thing's name, or the theme's for the scene. */
  name: {en: string; pt: string; es: string};
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
  /** How the rows were made: a drawing averaged down ("sticker"), a pixel
   *  art drawing read at its squares ("drawn"), that drawing redrawn as rows
   *  by a text model ("redrawn"), or rows it wrote from words ("rows"). */
  route?: "sticker" | "drawn" | "redrawn" | "rows";
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
  /** A pixel art drawing: the side it was asked to be drawn at, and what
   *  the reader found in it (its squares, their pitch in the image's
   *  pixels, how many of them hold a finer drawing, and why it was not
   *  read into the band when it was not). */
  asked?: number;
  snap?: {cols: number; rows: number; pitch: number; mixed: number; w?: number; h?: number; why?: string; pooled?: number};
  error?: string;
  tried: Tried[];
}

/** Drawings of one thing before its sizes are the bank's: two days of four
 *  things must end inside the function's 1,800 seconds. */
export const DRAFTS = 3;

/** Named beside the day's three things, so a reviewer who cannot tell has
 *  somewhere to be wrong. */
const DECOYS = ["umbrella", "bicycle", "guitar", "rocket", "anchor", "teapot", "kite", "snail"];

/** The colours a thing is asked to be drawn in, by the size it is for: the
 *  most its band lets a picture have. */
const INKS: Record<number, string> = {10: "four", 12: "five", 16: "seven"};

const OBJECT = (what: string, size: number) => `Draw ONE thing: ${what}. Alone, centred and large on a plain pure white background. A children's sticker drawing: flat solid colours, a thick dark brown outline, chunky simple shapes, in exactly ${INKS[size]} clearly different colours, each over a good part of it and none over half of it. No shading, no gradients, no highlights, no shadow under it, no white sticker border round it, nothing else in the picture, no text or letters. A square picture.`;

/** "pixel" (DAILY_PICTURE_STYLE): drawn as pixel art and read at its own
 *  squares, never averaged, or redrawn or written as rows by a text model
 *  (pixelDay). Otherwise the first way, a smooth drawing averaged down. */
export function pixelStyle(): boolean {
  return (process.env.DAILY_PICTURE_STYLE ?? "").trim() === "pixel";
}
/** The model that writes rows (DAILY_ROWS_MODEL): the strongest of those
 *  tried on 2026-10-14; a cheaper writer's mushroom was a blob. */
export const DEFAULT_ROWS_MODEL = "anthropic/claude-opus-5.5";

const PIXEL_OBJECT = (what: string, side: number, colours: number) => `Pixel art sprite of ${what}, exactly ${side} by ${side} pixels, upscaled so every pixel is one big square block. No grid lines, one sprite only. Every pixel one flat colour, a one-pixel black outline around it, no anti-aliasing, no shading gradients, at most ${colours} colours. Plain white background, centred, nothing else, no text. Cute cozy kawaii style.`;

const PIXEL_SCENE = (what: string, side: number, colours: number) => `Pixel art of a whole scene, exactly ${side} by ${side} pixels, upscaled so every pixel is one big square block, filling the whole square image edge to edge with no border and no white margin: ${what} Very low resolution and chunky, no grid lines. Every pixel one flat colour, dark outlines one pixel wide, no anti-aliasing, no gradients, at most ${colours} colours, big simple shapes, no text, no people. Cute cozy style.`;

/** The image models draw a sprite about a third over the side they are
 *  asked for, and a scene about a quarter over (read off five drawings,
 *  2026-10-14): the first ask is under the band's side by that much, and
 *  each next one by what the last came out at. */
const FIRST_ASK = {thing: .75, scene: .8};
/** Drawings of one size before it is redrawn: a drawing on
 *  gemini-3-pro-image is one to four minutes with its rate limit. */
const PIXEL_DRAWINGS = 2;

const ROWS_SYSTEM = `You are a pixel artist making cute cozy pixel art for a children's bead puzzle. You draw by writing rows of letters, one letter a square; "." is an empty square. The beads are: ${Object.entries(Beads.PALETTE).map(([k, v]) => `${k} #${v}`).join(", ")}. d (dark brown) is the darkest bead and makes the outline.`;

const ROWS_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["rows"],
  properties: {rows: {type: "array", items: {type: "string"}}},
};

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
  const free = DECOYS.filter((d) => !names.some((n) => n.includes(d)));
  const decoy = free.length > 0 ? free[fnv1a(`${day}`) % free.length] : "none of these";
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
  if (pixelStyle()) {
    await pixelDay(day, theme, sizes, drafts, keep);
    const got = Object.keys(sizes);
    console.log(`pictures: day ${day} (${theme.id}), pixel art, kept ${got.join("/") || "none"} in ${drafts.length} drafts`);
    return {doc: got.length > 0 ? {v: 1, theme: theme.id, sizes} : null, drafts};
  }
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
          const tried: Tried = {route: "sticker", size, rows, checks, kept: false};
          draft.tried.push(tried);
          if (!tried.checks.every((c) => c.ok)) continue;
          tried.look = item.thing === null ? await lookScene(rows, theme) : await lookThing(day, rows, item.thing, theme);
          if (!tried.look.ok) continue;
          tried.kept = true;
          sizes[size] = {id: item.what, rows, name: item.thing === null ? theme.name :
            {en: item.thing.name, pt: item.thing.pt, es: item.thing.es}};
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

/** The rules, then the blind look; a picture both pass is the size's when
 *  the size has none yet. */
async function judge(day: number, theme: Theme, thing: Thing | null, tried: Tried, sizes: Record<string, Picture>): Promise<void> {
  if (!tried.checks.every((c) => c.ok)) return;
  tried.look = thing === null ? await lookScene(tried.rows, theme) : await lookThing(day, tried.rows, thing, theme);
  if (!tried.look.ok || sizes[tried.size] !== undefined) return;
  tried.kept = true;
  sizes[tried.size] = {id: thing === null ? "scene" : thing.id, rows: tried.rows,
    name: thing === null ? theme.name : {en: thing.name, pt: thing.pt, es: thing.es}};
}

/** Rows a text model answered, when they are the band's side in beads. */
function rowsOf(out: {rows?: unknown}, size: number): string[] | null {
  const rows = Array.isArray(out.rows) ? out.rows.map((r) => String(r)) : [];
  const ok = rows.length === size && rows.every((r) => r.length === size &&
    [...r].every((c) => c === "." || Beads.PALETTE[c] !== undefined));
  return ok ? rows : null;
}

/**
 * The pixel art way, each size on its own:
 *
 * 1. **Drawn**: an image model draws pixel art, read at the squares it drew
 *    (Beads.snap) and kept only at its own size: a thing padded into the
 *    band's square, a scene a little over cut to its middle, never shrunk.
 *    A thing drawn too big is asked for again at the side that would have
 *    fitted. The image models hold no side they are asked for (2026-10-14:
 *    asked for 8 squares, 16; for 19, 67), so this often comes to nothing.
 * 2. **Redrawn**: a text model that sees pictures is shown the cleanest of
 *    those drawings and redraws it as rows of the band's side, keeping its
 *    layout and its things.
 * 3. **Written**, things only: the text model draws the thing as rows from
 *    its words alone. Run every day beside the others, for the dashboard.
 *
 * The first that passes the rules and the blind look is the size's.
 */
async function pixelDay(day: number, theme: Theme, sizes: Record<string, Picture>, drafts: Draft[],
  keep?: (name: string, d: Drawing) => string): Promise<void> {
  const plan: {size: number; thing: Thing | null}[] = [
    ...theme.objects.map((o, i) => ({size: [10, 12, 16][i], thing: o})),
    {size: 24, thing: null}, {size: 32, thing: null},
  ];
  const rowsModel = (process.env.DAILY_ROWS_MODEL ?? "").trim() || DEFAULT_ROWS_MODEL;
  for (const {size, thing} of plan) {
    const what = thing === null ? `scene${size}` : thing.id;
    const colours = Beads.RULES[size].colours[1];
    // A thing leaves a bare square at an edge (the rules want one), so it
    // fits in one less than the band's side.
    const room = thing === null ? size : size - 1;
    let side = Math.round(size * (thing === null ? FIRST_ASK.scene : FIRST_ASK.thing));
    let clean: {url: string; share: number; file?: string} | null = null;
    for (let n = 0; n < PIXEL_DRAWINGS && sizes[size] === undefined; n++) {
      const draft: Draft = {what, draft: n, asked: side, tried: []};
      drafts.push(draft);
      try {
        const drawing = await draw(thing === null ? PIXEL_SCENE(theme.scene, side, colours) : PIXEL_OBJECT(thing.draw, side, colours));
        if (keep !== undefined) draft.file = keep(`${day}_${what}_${n}`, drawing);
        const px = decoded(drawing);
        const sn = Beads.snap(px.data, px.width, px.height);
        if (sn === null) {
          draft.error = "no squares found in it";
          continue;
        }
        const share = sn.mixed / (sn.cols * sn.rows);
        if (clean === null || share < clean.share) {
          clean = {url: `data:${drawing.mime};base64,${drawing.bytes.toString("base64")}`, share, file: draft.file};
        }
        const got = Beads.fromSnap(sn, size, colours, thing === null, thing === null ? Math.round(size / 4) : 0);
        draft.snap = {cols: sn.cols, rows: sn.rows, pitch: Math.round(sn.pitch[0] * 10) / 10, mixed: sn.mixed,
          w: got.w, h: got.h, why: got.why};
        if (got.w !== undefined && got.h !== undefined && thing !== null) {
          // Never under 0.6 of the side: asked for 4 squares, a model drew
          // a literal 4 by 4 grid (2026-10-14).
          side = Math.min(size, Math.max(Math.ceil(size * .6), Math.round(side * room / Math.max(got.w, got.h))));
        }
        if (got.rows === undefined) continue;
        const tried: Tried = {route: "drawn", size, rows: got.rows, checks: Beads.check(got.rows, size), kept: false};
        draft.tried.push(tried);
        await judge(day, theme, thing, tried, sizes);
      } catch (e) {
        draft.error = String(e).slice(0, 300);
        console.error(`pictures: day ${day}, ${what}, draft ${n} failed`, e);
      }
    }
    const shape = thing === null ?
      `exactly ${size} rows of exactly ${size} letters, no empty squares, filling the picture` :
      `exactly ${size} rows of exactly ${size} letters, the thing centred and large on empty squares (".") leaving at least one empty column or row at some edge`;
    const limits = `at most ${colours} different beads including the outline, no one bead over ${thing === null ? "40% of the squares" : "half the drawn squares"}`;
    // 2, redrawn from the cleanest drawing; 3, written from words.
    const routes: {route: "redrawn" | "rows"; prompt: string; images?: string[]}[] = [];
    if (clean !== null && sizes[size] === undefined) {
      routes.push({route: "redrawn", images: [clean.url], prompt: `The picture is pixel art of ${thing === null ? "a scene" : thing.draw}. Redraw it as pixel art of ${shape}, keeping its layout and its main things recognisable: simplify, keep the dark outlines one square wide, ${limits}. Answer "rows".`});
    }
    if (thing !== null) {
      routes.push({route: "rows", prompt: `Draw ${thing.draw} as cute cozy pixel art, ${shape}. A one-square dark outline (d) around the thing, flat colours, ${limits}. Think about the shape first, then answer "rows".`});
    }
    for (const r of routes) {
      for (let n = 0; n < 2; n++) {
        const draft: Draft = {what: `${what} (${r.route})`, draft: n, tried: []};
        if (r.route === "redrawn") draft.file = clean?.file;
        drafts.push(draft);
        try {
          const rows = rowsOf(await ask<{rows: string[]}>({system: ROWS_SYSTEM, prompt: r.prompt, schema: ROWS_SCHEMA,
            model: rowsModel, images: r.images}), size);
          if (rows === null) {
            draft.error = `not ${size} rows of ${size} beads`;
            continue;
          }
          const tried: Tried = {route: r.route, size, rows, checks: Beads.check(rows, size), kept: false};
          draft.tried.push(tried);
          await judge(day, theme, thing, tried, sizes);
          if (tried.checks.every((c) => c.ok) && tried.look?.ok) break;
        } catch (e) {
          draft.error = String(e).slice(0, 300);
          console.error(`pictures: day ${day}, ${what} ${r.route}, try ${n} failed`, e);
        }
      }
    }
  }
}
