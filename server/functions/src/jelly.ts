import {ask, available, draw, Drawing, shapesModel} from "./generate";
import {board, compact, dissolve, fewer, join, touching, outlines, raster, Raster, Regions, simplify, split, area as signedArea} from "./facets";
import {DEFAULT_ROWS_MODEL} from "./pictures";
import {keyFor, keyWords, Key} from "./key";
import {dataUrl, FLOOR, judge, renderPolygons, Verdict} from "./eye";
import {gridOver, JELLY_GRID_N} from "./grid";
import {logTry as logLine, Port, PortTry, said} from "./ports";
import {shrunk} from "./vistas";
import {Theme, Thing} from "./theme";

/**
 * The day's Gumdrop jellies (docs/superpowers/specs/
 * 2026-10-14-gumdrop-themed-jelly-design.md): the theme's things, one a
 * mould -- Easy's two, Medium's three, Hard's four, Insane's five, each
 * band's at its own rules -- written as a jelly's parts -- the same ellipses, rounded boxes and
 * soft polygons puzzles/gumdrop_mould.gd's twenty-nine are made of, so a
 * themed jelly is built and drawn by the same code as theirs.
 *
 * Since 2026-10-21 the thing is drawn as a sticker and a reviewer model,
 * shown it under a numbered grid, writes the parts (mapJelly); the pixel
 * reader (readJelly) and a text model writing from words are the
 * fallbacks. The band's rules below are checked in code on the same shapes
 * the phone builds, and the eye (eye.ts) is shown the jelly as the phone
 * lays it and has to name the thing and score it well. A thing whose tries
 * all fail is left out, and the board fills that place from its
 * twenty-nine.
 *
 * The rules are written twice, here and in core/themed_pictures.gd
 * (JELLY_RULES): the two change together.
 */

export const FLAVOURS = ["cherry", "orange", "lemon", "lime", "blueberry", "grape"] as const;
export type Flavour = typeof FLAVOURS[number];
export const KINDS = ["ell", "box", "soft", "sharp"] as const;

export interface Shape {
  /** ell: x, y, rx, ry, turn (radians); box: x, y, w, h, corner radius;
   *  soft and sharp: x, y pairs, their corners cut twice and once. */
  kind: typeof KINDS[number];
  n: number[];
}

export interface Part {
  flavour: Flavour;
  shapes: Shape[];
}

export interface Jelly {
  /** The thing's id. */
  id: string;
  name: {en: string; pt: string; es: string};
  /** The one underneath first. */
  parts: Part[];
}

export interface JellyTry {
  band: number;
  /** Drawn as a sticker and mapped or read (since 2026-10-16), or written
   *  as shapes. Every ask behind it is on the thing's Port. */
  route?: "drawn" | "written";
  what: string;
  parts?: Part[];
  /** What the rules found, "" when it keeps them. */
  why: string;
  /** The eye on the parts kept, or on the last it saw. */
  verdict?: Verdict;
  kept: boolean;
  error?: string;
}

/** By band: how many flavours, how many of them mixed (orange, lime,
 *  grape), and how many chunks. Hard leaves a mixed pot out and Insane
 *  stands only the three pigments, so theirs must have mixed ones. */
export const RULES = [
  {flavours: [2, 2], mixed: 0, chunks: [2, 5]},
  {flavours: [3, 3], mixed: 0, chunks: [3, 7]},
  {flavours: [3, 4], mixed: 1, chunks: [3, 10]},
  {flavours: [4, 6], mixed: 2, chunks: [4, 14]},
];
/** The sim's grid (puzzles/gumdrop_sim.gd N): a chunk must show this many
 *  of its squares, and the jelly cover this share of them. */
const GRID = 36;
export const LEAST_SQUARES = 9;
export const COVER = [0.2, 0.75];
/** Every point of every shape inside this much of the field's 100. */
export const EDGE = [4, 96];
export const MOST_PARTS = 8;
export const MOST_SHAPES = 8;
/** The phone makes a cell of every piece a later chunk leaves of an
 *  earlier one (gumdrop_mould.gd build_parts, 2026-10-14), a piece under
 *  SLIVER of the field's 100 by 100 going to the chunk that cut it; its
 *  passes hold CELLS_TOP cells, so a jelly whose cut pieces come to more
 *  is dropped there, and so refused here. */
const CELLS_TOP = 16;
const SLIVER = 24;
export const MOST_POINTS = 16;
const TRIES = 2;

type V = [number, number];

function ccw(p: V[]): V[] {
  let a = 0;
  for (let i = 0; i < p.length; i++) {
    const q = p[(i + 1) % p.length];
    a += p[i][0] * q[1] - q[0] * p[i][1];
  }
  // y down: Godot's is_polygon_clockwise is a positive sum here
  return a > 0 ? p.slice().reverse() : p;
}

/** A shape's outline, point for point as gumdrop_mould.gd makes it. */
export function polygon(s: Shape): V[] {
  const n = s.n;
  if (s.kind === "ell") {
    const [x, y, rx, ry, rot = 0] = n;
    const out: V[] = [];
    for (let i = 0; i < 40; i++) {
      const a = 2 * Math.PI * i / 40;
      const px = Math.cos(a) * rx, py = Math.sin(a) * ry;
      out.push([x + px * Math.cos(rot) - py * Math.sin(rot), y + px * Math.sin(rot) + py * Math.cos(rot)]);
    }
    return ccw(out);
  }
  if (s.kind === "box") {
    const [x, y, w, h] = n;
    const r = Math.min(n[4] ?? 0, Math.min(w, h) * 0.5);
    if (r <= 0) return ccw([[x, y], [x + w, y], [x + w, y + h], [x, y + h]]);
    const mids: V[] = [[x + w - r, y + r], [x + w - r, y + h - r], [x + r, y + h - r], [x + r, y + r]];
    const out: V[] = [];
    for (let k = 0; k < 4; k++) {
      for (let i = 0; i < 7; i++) {
        const a = -Math.PI * 0.5 + Math.PI * 0.5 * k + Math.PI * 0.5 * i / 6;
        out.push([mids[k][0] + Math.cos(a) * r, mids[k][1] + Math.sin(a) * r]);
      }
    }
    return ccw(out);
  }
  let p: V[] = [];
  for (let i = 0; i + 1 < n.length; i += 2) p.push([n[i], n[i + 1]]);
  for (let t = 0; t < (s.kind === "soft" ? 2 : 1); t++) {
    const q: V[] = [];
    for (let i = 0; i < p.length; i++) {
      const a = p[i], b = p[(i + 1) % p.length];
      q.push([a[0] + (b[0] - a[0]) * 0.25, a[1] + (b[1] - a[1]) * 0.25]);
      q.push([a[0] + (b[0] - a[0]) * 0.75, a[1] + (b[1] - a[1]) * 0.75]);
    }
    p = q;
  }
  return ccw(p);
}

function inside(p: V[], x: number, y: number): boolean {
  let hit = false;
  for (let i = 0, j = p.length - 1; i < p.length; j = i++) {
    if ((p[i][1] > y) !== (p[j][1] > y) && x < (p[j][0] - p[i][0]) * (y - p[i][1]) / (p[j][1] - p[i][1]) + p[i][0]) hit = !hit;
  }
  return hit;
}

/** 4-connected pieces of a boolean grid of side n. */
function pieces(on: boolean[], n: number): number[][] {
  const seen = new Uint8Array(n * n);
  const out: number[][] = [];
  for (let i = 0; i < n * n; i++) {
    if (!on[i] || seen[i]) continue;
    const piece: number[] = [];
    const stack = [i];
    seen[i] = 1;
    while (stack.length > 0) {
      const k = stack.pop() as number;
      piece.push(k);
      const x = k % n, y = Math.floor(k / n);
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const px = x + dx, py = y + dy;
        if (px < 0 || py < 0 || px >= n || py >= n) continue;
        const j = py * n + px;
        if (on[j] && !seen[j]) { seen[j] = 1; stack.push(j); }
      }
    }
    out.push(piece);
  }
  return out;
}

/** The parts' chunks laid on a grid of side n: each square's chunk (the
 *  last that holds it, as cell_at finds it), -1 bare; and how many chunks. */
export function laid(parts: Part[], n: number): {at: Int32Array; chunks: number; flavourOf: number[]} {
  const at = new Int32Array(n * n).fill(-1);
  const flavourOf: number[] = [];
  let chunk = 0;
  for (const part of parts) {
    const polys = part.shapes.map(polygon);
    const on: boolean[] = [];
    for (let i = 0; i < n * n; i++) {
      const x = (i % n + 0.5) * 100 / n, y = (Math.floor(i / n) + 0.5) * 100 / n;
      on.push(polys.some((p) => inside(p, x, y)));
    }
    for (const piece of pieces(on, n)) {
      for (const k of piece) at[k] = chunk;
      flavourOf.push(FLAVOURS.indexOf(part.flavour));
      chunk++;
    }
  }
  return {at, chunks: chunk, flavourOf};
}

/** What is wrong with `parts` for `band`, "" when nothing is. */
export function why(parts: unknown, band: number): string {
  const rule = RULES[band];
  if (!Array.isArray(parts) || parts.length === 0 || parts.length > MOST_PARTS) return "parts";
  for (const p of parts as Part[]) {
    if (typeof p !== "object" || p === null || !FLAVOURS.includes(p.flavour)) return "a flavour";
    if (!Array.isArray(p.shapes) || p.shapes.length === 0 || p.shapes.length > MOST_SHAPES) return "a part's shapes";
    for (const s of p.shapes) {
      if (typeof s !== "object" || s === null || !KINDS.includes(s.kind) || !Array.isArray(s.n)) return "a shape";
      if (!s.n.every((v) => typeof v === "number" && Number.isFinite(v))) return "a shape's numbers";
      const want = s.kind === "ell" ? [4, 5] : s.kind === "box" ? [4, 5] : [6, 2 * MOST_POINTS];
      if (s.n.length < want[0] || s.n.length > want[1] || (s.kind !== "ell" && s.kind !== "box" && s.n.length % 2 === 1)) return `a ${s.kind}'s numbers`;
      if ((s.kind === "ell" || s.kind === "box") && (s.n[2] < 2 || s.n[3] < 2)) return `a ${s.kind} too thin`;
      if (polygon(s).some(([x, y]) => x < EDGE[0] || y < EDGE[0] || x > EDGE[1] || y > EDGE[1])) return "off the field";
    }
  }
  const used = new Set((parts as Part[]).map((p) => FLAVOURS.indexOf(p.flavour)));
  if (used.size < rule.flavours[0] || used.size > rule.flavours[1]) return `${used.size} flavours`;
  if ([...used].filter((f) => f % 2 === 1).length < rule.mixed) return "too few mixed flavours";
  // The chunks as build() makes them: each part's shapes joined, a piece
  // apart a chunk of its own. Read finely, so two shapes that touch join.
  const fine = laid(parts as Part[], 100);
  if (fine.chunks < rule.chunks[0] || fine.chunks > rule.chunks[1]) return `${fine.chunks} chunks`;
  if (pieces(Array.from(fine.at, (c) => c >= 0), 100).length !== 1) return "more than one piece of jelly";
  let cells = 0;
  for (let c = 0; c < fine.chunks; c++) {
    const cut = pieces(Array.from(fine.at, (k) => k === c), 100).filter((p) => p.length >= SLIVER).length;
    cells += Math.max(1, cut);
  }
  if (cells > CELLS_TOP) return `${cells} cells once cut`;
  // What each chunk shows of the sim's grid, read off the fine one at
  // each square's middle, so a chunk is the same chunk in both.
  const shows = new Array(fine.chunks).fill(0);
  let covered = 0;
  for (let i = 0; i < GRID * GRID; i++) {
    const x = Math.floor((i % GRID + 0.5) * 100 / GRID), y = Math.floor((Math.floor(i / GRID) + 0.5) * 100 / GRID);
    const c = fine.at[y * 100 + x];
    if (c >= 0) { shows[c]++; covered++; }
  }
  if (shows.some((k) => k < LEAST_SQUARES)) return "a chunk too small to pour in";
  const share = covered / (GRID * GRID);
  if (share < COVER[0] || share > COVER[1]) return `covers ${Math.round(share * 100)}%`;
  return "";
}

/** The bead letters a flavour is shown in to the blind look. */
const BEAD = ["r", "o", "y", "i", "b", "u"];

/** The jelly as bead rows of 32, in its flavours' colours. */
export function beads(parts: Part[]): string[] {
  const n = 32;
  const {at, flavourOf} = laid(parts, n);
  const rows: string[] = [];
  for (let y = 0; y < n; y++) {
    let row = "";
    for (let x = 0; x < n; x++) {
      const c = at[y * n + x];
      row += c < 0 ? "." : BEAD[flavourOf[c]];
    }
    rows.push(row);
  }
  return rows;
}

const SYSTEM = `You design jellies for Gumdrop, a cosy children's puzzle: a clear jelly cast as a real thing, made of chunks the player tints with fruit syrup until each chunk is its wanted flavour. You draw in a square field 100 wide and 100 tall, x to the right and y DOWN, and keep every point between ${EDGE[0] + 2} and ${EDGE[1] - 2}.

A jelly is a list of parts, the one underneath first, each one flavour and the shapes it is made of. A later part lies over an earlier one where they overlap, so a stem first and a cap over it hides the stem's top. The flavours: cherry (red), orange, lemon (yellow), lime (green), blueberry (blue), grape (purple). No other colours, no outline, no white, no brown: pick the nearest flavour (a brown trunk is orange, white petals lemon, a grey pot blueberry).

Shapes:
- {"kind":"ell","n":[x, y, rx, ry, turn]}: an ellipse about (x, y), radii rx and ry, turned by turn radians.
- {"kind":"box","n":[x, y, w, h, r]}: a box from its top-left corner, w wide and h tall, corners rounded by r.
- {"kind":"soft","n":[x1, y1, x2, y2, ...]}: a polygon of up to ${MOST_POINTS} points, its corners well rounded; "sharp" the same, rounded less.

Each part's shapes that touch or overlap join into one chunk; a shape of a part apart from the rest is a chunk of its own. Every chunk must show plenty of itself, about 8 by 8 at the least, so no thin lines, dots or small details. The whole jelly is one piece: every chunk touches another. Big, simple, bold shapes a child would name at once, filling a good part of the field and centred.

Some of the game's own jellies:
mushroom: [{"flavour":"lemon","shapes":[{"kind":"box","n":[39,46,22,44,9]}]},{"flavour":"cherry","shapes":[{"kind":"soft","n":[13,52,16,30,30,16,50,12,70,16,84,30,87,52]}]}]
house: [{"flavour":"lemon","shapes":[{"kind":"box","n":[24,44,52,46,5]}]},{"flavour":"blueberry","shapes":[{"kind":"box","n":[42,62,16,28,5]}]},{"flavour":"cherry","shapes":[{"kind":"sharp","n":[12,50,50,10,88,50]}]}]
tree: [{"flavour":"orange","shapes":[{"kind":"box","n":[43,56,14,38,4]}]},{"flavour":"lime","shapes":[{"kind":"ell","n":[50,38,30,24,0]},{"kind":"ell","n":[32,44,14,13,0]},{"kind":"ell","n":[68,44,14,13,0]},{"kind":"ell","n":[50,22,18,13,0]}]},{"flavour":"cherry","shapes":[{"kind":"ell","n":[36,38,7,7,0]},{"kind":"ell","n":[60,28,7,7,0]},{"kind":"ell","n":[58,50,7,7,0]}]}]
butterfly: [{"flavour":"blueberry","shapes":[{"kind":"ell","n":[33,66,16,15,0]},{"kind":"ell","n":[67,66,16,15,0]}]},{"flavour":"grape","shapes":[{"kind":"ell","n":[29,36,21,19,0]},{"kind":"ell","n":[71,36,21,19,0]}]},{"flavour":"orange","shapes":[{"kind":"box","n":[44,22,12,58,6]}]}]`;

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["parts"],
  properties: {
    parts: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["flavour", "shapes"],
        properties: {
          flavour: {type: "string", enum: [...FLAVOURS]},
          shapes: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["kind", "n"],
              properties: {kind: {type: "string", enum: [...KINDS]}, n: {type: "array", items: {type: "number"}}},
            },
          },
        },
      },
    },
  },
};

function asked(thing: Thing, band: number, last: string): string {
  const rule = RULES[band];
  const flavours = rule.flavours[0] === rule.flavours[1] ? `exactly ${rule.flavours[0]}` : `${rule.flavours[0]} to ${rule.flavours[1]}`;
  const mixed = rule.mixed === 0 ? "" : ` At least ${rule.mixed} of them must be orange, lime or grape.`;
  const again = last === "" ? "" : ` Your last try was turned down: ${last}.`;
  return `Design the jelly of: ${thing.draw} Use ${flavours} different flavours.${mixed} It comes to ${rule.chunks[0]} to ${rule.chunks[1]} chunks.${again} Think about the shape first, then answer "parts".`;
}

/** Moulds a band's day has (gumdrop_mould.gd BANDS): each is a thing of
 *  the theme, the simplest first, so Easy's two are its first two. */
export const MOULDS = [2, 3, 4, 5];

/** The theme's things as jellies, by band ("0" Easy to "3" Insane), a
 *  list a band in the theme's order, what became of every try, and a Port a
 *  thing with every ask behind it. A thing whose tries all fail, or that
 *  the band's JELLY_BUDGET_MS does not reach, is left out of its band's
 *  list, and the board fills its place from the twenty-nine. `until` is the
 *  run's own limit, absolute ms, when it comes before the band's budget
 *  does. Never throws. */
export async function makeJellies(day: number, theme: Theme, only?: number,
  keep?: (name: string, d: Drawing) => void, until?: number): Promise<{jellies: Record<string, Jelly[]>; tries: JellyTry[]; ports: Port[]}> {
  const jellies: Record<string, Jelly[]> = {};
  const tries: JellyTry[] = [];
  const ports: Port[] = [];
  if (!available()) return {jellies, tries, ports};
  // Fourteen jellies a day, one request at a time: side by side, the four
  // bands' Opus requests ran past OpenRouter's in-flight credit budget
  // (HTTP 402, 2026-10-14).
  // `only`: that band alone, so the night writes a band a run (index.ts).
  for (let band = 0; band < RULES.length; band++) {
    if (only !== undefined && band !== only) continue;
    // the budget runs from the band's start: the night writes a band a step
    const deadline = Math.min(Date.now() + JELLY_BUDGET_MS, until ?? Infinity);
    const list: Jelly[] = [];
    for (const thing of theme.objects.slice(0, MOULDS[band])) {
      const d: JellyTry = {band, what: thing.id, route: "drawn", why: "", kept: false};
      tries.push(d);
      const got = await drawJelly(day, theme, thing, band, d, keep, deadline);
      ports.push(got.port);
      const parts = got.parts ?? await writeJelly({day, theme, thing, band, deadline, port: got.port}, tries);
      if (parts !== null) list.push({id: thing.id, name: {en: thing.name, pt: thing.pt, es: thing.es}, parts});
    }
    if (list.length > 0) jellies[band] = list;
  }
  const kept = Object.entries(jellies).map(([b, l]) => `${b}:${l.length}`).join(" ");
  console.log(`jelly: day ${day} (${theme.id}), kept ${kept || "none"} in ${tries.length} tries`);
  return {jellies, tries, ports};
}

// --- a jelly drawn (2026-10-16) ---

/** The flavours' colours, puzzles/gumdrop_sim.gd FLAVOURS. */
const INKS = [[0xe2, 0x49, 0x5a], [0xf3, 0x92, 0x37], [0xf4, 0xd4, 0x4a], [0x79, 0xc9, 0x4f], [0x4a, 0x86, 0xdf], [0x9a, 0x62, 0xd2]];
const INK_NAMES = ["cherry red #e2495a", "orange #f39237", "lemon yellow #f4d44a", "lime green #79c94f", "blueberry blue #4a86df", "grape purple #9a62d2"];
/** By band: the colours the sticker is asked in, and how many shapes. */
const DRAWN = [
  {colours: "exactly 2", shapes: "2 to 4 big"},
  {colours: "exactly 3", shapes: "3 to 6 big"},
  {colours: "3 or 4", shapes: "4 to 8"},
  {colours: "4 to 6", shapes: "6 to 12"},
];
/** Where the thing is laid in the field of 100: inside EDGE, with room for
 *  the soft corners' and the grown outline's play. */
const FIT = [9, 91];
/** Pixels of the 256 reading a chunk must hold: LEAST_SQUARES of the
 *  sim's 36-grid with room to spare (a square is about six pixels). */
const DRAWN_LEAST = 520;
/** Stickers drawn for one jelly, each mapped up to JELLY_ASKS times, before
 *  the reader and then the words are tried, by band: Insane's five jellies
 *  at three each, with flash's back-offs, would pass the themeDay step's
 *  half hour (JELLY_BUDGET_MS holds the rest). */
const DRAWINGS = [3, 3, 2, 2];
/** Pixels the drawing is grown out over the board. */
const SWELL = 5;

export const STICKER = (what: string, band: number, key: Key) => {
  const rule = RULES[band];
  const mixed = rule.mixed === 0 ? "" : ` At least ${rule.mixed} of the colours you use must be orange, lime green or grape purple.`;
  return `A cute ${what} drawn as a flat children's sticker of ${DRAWN[band].shapes} smooth rounded shapes, using ${DRAWN[band].colours} of these six exact flat colours and no others: ${INK_NAMES.join(", ")}.${mixed} Each shape one solid colour, shapes touching edge to edge with no gaps. No outlines at all, no dark edge lines, no black, and no white, cream or grey anywhere in it (every part of the thing, body included, is one of the six colours), no shading, no gradients, no highlights, no texture, no thin lines or small dots. The shapes are clean and well proportioned: a sharp, true silhouette of the thing that a child names at once, drawn with care. Any spots or small details in one of the six colours too. One thing only, centred and large, filling most of the picture, on ${keyWords(key)}, nothing else, no white sticker border round it, no shadow, no text. A square picture.`;
};

/** A drawing's regions in the six flavours: each pixel the flavour nearest
 *  it, the seams and specks dissolved, chunks under DRAWN_LEAST joined to
 *  their neighbour, and the fewest joins that bring the chunks to `most`. */
function flavoured(r: Raster, most: number): {reg: Regions; flavour: number[]} {
  const n = r.n;
  const bg = board(r);
  // the white sticker border the model draws round the thing however it is
  // asked not to: pale, unsaturated, and joined to the board, it is board
  // (read as a flavour it was a lemon ring round every jelly)
  const pale = (i: number) => {
    const a = r.rgb[i * 3], b = r.rgb[i * 3 + 1], c = r.rgb[i * 3 + 2];
    return Math.min(a, b, c) > 185 && Math.max(a, b, c) - Math.min(a, b, c) < 60;
  };
  const rim: number[] = [];
  for (let i = 0; i < n * n; i++) if (bg[i]) rim.push(i);
  while (rim.length > 0) {
    const i = rim.pop() as number;
    const x = i % n, y = (i - x) / n;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const px = x + dx, py = y + dy;
      if (px < 0 || py < 0 || px >= n || py >= n) continue;
      const j = py * n + px;
      if (!bg[j] && pale(j)) { bg[j] = 1; rim.push(j); }
    }
  }
  const label = new Int32Array(n * n).fill(-1);
  for (let i = 0; i < n * n; i++) {
    if (bg[i]) continue;
    let best = 0, bestD = Infinity;
    for (let f = 0; f < INKS.length; f++) {
      const d = Math.hypot(r.rgb[i * 3] - INKS[f][0], r.rgb[i * 3 + 1] - INKS[f][1], r.rgb[i * 3 + 2] - INKS[f][2]);
      if (d < bestD) { bestD = d; best = f; }
    }
    label[i] = best;
  }
  const inked: Raster = {n, rgb: new Float32Array(n * n * 3).fill(255)};
  for (let i = 0; i < n * n; i++) if (label[i] >= 0) for (let c = 0; c < 3; c++) inked.rgb[i * 3 + c] = INKS[label[i]][c];
  let reg = split(compact(n, label, inked));
  // grown out over the board a few pixels, which joins the pieces a
  // sticker draws a hair apart (a crab's claws beside its body) into one
  // jelly and fattens a thin limb into a chunk that can be poured
  for (let ring = 0; ring < SWELL; ring++) {
    const next = reg.label.slice();
    for (let i = 0; i < n * n; i++) {
      if (reg.label[i] >= 0) continue;
      const x = i % n, y = (i - x) / n;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const px = x + dx, py = y + dy;
        if (px < 0 || py < 0 || px >= n || py >= n) continue;
        const l = reg.label[py * n + px];
        if (l >= 0) {
          next[i] = l;
          for (let c = 0; c < 3; c++) inked.rgb[i * 3 + c] = reg.colour[l][c];
          break;
        }
      }
    }
    reg.label = next;
  }
  reg = split(compact(n, reg.label, null, reg.colour));
  reg = dissolve(reg, inked, 60, 2);
  reg = fewer(reg, inked, most, DRAWN_LEAST, true);
  const flavour = reg.colour.map((c) => {
    let best = 0, bestD = Infinity;
    INKS.forEach((k, f) => { const d = Math.hypot(c[0] - k[0], c[1] - k[1], c[2] - k[2]); if (d < bestD) { bestD = d; best = f; } });
    return best;
  });
  return {reg, flavour};
}

/** An outline grown outward by `by` along each corner's mean normal
 *  (clockwise on screen: the outside is to the left of each side). */
function grown(p: number[][], by: number): number[][] {
  return p.map((q, i) => {
    const a = p[(i + p.length - 1) % p.length], b = p[(i + 1) % p.length];
    const n1 = [q[1] - a[1], -(q[0] - a[0])], n2 = [b[1] - q[1], -(b[0] - q[0])];
    const l1 = Math.hypot(n1[0], n1[1]) || 1, l2 = Math.hypot(n2[0], n2[1]) || 1;
    const nx = n1[0] / l1 + n2[0] / l2, ny = n1[1] / l1 + n2[1] / l2;
    const l = Math.hypot(nx, ny) || 1;
    return [q[0] + nx / l * by, q[1] + ny / l * by];
  });
}

/**
 * A sticker drawing read as a jelly's parts: each region an outline of up to
 * MOST_POINTS soft corners, the biggest outline laid first so what lies
 * inside one is laid over it; a flavour's regions one part where the
 * parts would be more than MOST_PARTS. `why` says what the band's rules
 * find wrong, "" nothing.
 */
export function readJelly(d: Drawing | Raster, band: number): {parts: Part[]; why: string} {
  const r = "rgb" in d ? d : raster(d);
  const rule = RULES[band];
  const {reg, flavour} = flavoured(r, rule.chunks[1]);
  // a sticker in more flavours than the band takes loses its least-used
  // one into the chunks round it, a mixed one spared while the band still
  // needs it (asked for two colours, the model often adds a third)
  for (;;) {
    const area = new Map<number, number>();
    reg.size.forEach((sz, l) => { if (sz > 0) area.set(flavour[l], (area.get(flavour[l]) ?? 0) + sz); });
    if (area.size <= rule.flavours[1]) break;
    const mixedHeld = [...area.keys()].filter((f) => f % 2 === 1).length;
    const spare = [...area.keys()].filter((f) => f % 2 === 0 || mixedHeld > rule.mixed);
    if (spare.length === 0) break;
    const least = spare.reduce((a, b) => ((area.get(a) as number) <= (area.get(b) as number) ? a : b));
    const near = touching(reg);
    for (let l = 0; l < reg.size.length; l++) {
      if (reg.size[l] === 0 || flavour[l] !== least) continue;
      let to = -1, most = 0;
      for (const [b, shared] of near[l]) if (reg.size[b] > 0 && flavour[b] !== least && shared > most) { most = shared; to = b; }
      if (to < 0) {
        for (let i = 0; i < reg.label.length; i++) if (reg.label[i] === l) reg.label[i] = -1;
        reg.size[l] = 0;
        continue;
      }
      const keep = reg.colour[to];
      join(reg, to, l);
      reg.colour[to] = keep;
    }
  }
  const lines = outlines(reg);
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const line of lines) for (const [x, y] of line) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  if (!Number.isFinite(x0)) return {parts: [], why: "nothing drawn"};
  const s = (FIT[1] - FIT[0]) / Math.max(x1 - x0, y1 - y0);
  const ox = 50 - (x1 - x0) * s / 2, oy = 50 - (y1 - y0) * s / 2;
  const shapes: {f: number; pts: number[][]; area: number}[] = [];
  lines.forEach((line, l) => {
    if (line.length < 3 || reg.size[l] === 0) return;
    const pts = line.map(([x, y]) => [(x - x0) * s + ox, (y - y0) * s + oy]);
    let kept: number[][] = pts;
    for (let tol = 0.5; tol < 20; tol *= 1.25) {
      // a closed outline: simplified as two runs from its first point and
      // the point farthest from it
      let far = 0, farD = -1;
      pts.forEach((p, i) => { const dd = Math.hypot(p[0] - pts[0][0], p[1] - pts[0][1]); if (dd > farD) { farD = dd; far = i; } });
      const one = pts.slice(0, far + 1), two = [...pts.slice(far), pts[0]];
      const k1 = simplify(one, tol), k2 = simplify(two, tol);
      kept = [...one.filter((_, i) => k1[i]), ...two.slice(1, -1).filter((_, i) => k2[i + 1])];
      if (kept.length <= MOST_POINTS) break;
    }
    if (kept.length < 3) return;
    // y down: the walk keeps the region on its left, anticlockwise on screen
    const cw = signedArea(kept) > 0 ? kept : kept.slice().reverse();
    // grown a little, so the soft corners' rounding leaves no clear seam
    // between two chunks, and held inside EDGE
    const out = grown(cw, 0.9).map(([x, y]) => [
      Math.round(Math.min(EDGE[1] - 0.5, Math.max(EDGE[0] + 0.5, x)) * 10) / 10,
      Math.round(Math.min(EDGE[1] - 0.5, Math.max(EDGE[0] + 0.5, y)) * 10) / 10]);
    shapes.push({f: flavour[l], pts: out, area: Math.abs(signedArea(out))});
  });
  shapes.sort((a, b) => b.area - a.area);
  // a part a shape, or a flavour's shapes together when that is too many
  let parts: Part[] = shapes.map((sh) => ({flavour: FLAVOURS[sh.f], shapes: [{kind: "soft" as const, n: sh.pts.flat()}]}));
  if (parts.length > MOST_PARTS) {
    const byFlavour = new Map<string, Part>();
    parts = [];
    for (const sh of shapes) {
      const name = FLAVOURS[sh.f];
      let part = byFlavour.get(name);
      if (part === undefined) {
        part = {flavour: name, shapes: []};
        byFlavour.set(name, part);
        parts.push(part);
      }
      part.shapes.push({kind: "soft", n: sh.pts.flat()});
    }
  }
  return {parts, why: why(parts, band)};
}


// --- the port: a model maps the sticker (2026-10-21) ---

/** Asks of the reviewer model a drawing: each told why the last fell short. */
export const JELLY_ASKS = 3;
/** Past this long from a band's start no draw, ask, reader or written try
 *  begins (the judge of one already asked still runs: it costs seconds,
 *  and the ask was the dear part). The run's own limit (`until`,
 *  themeday.ts) can come sooner: a run may start the step 15 minutes into
 *  its 30-minute lease, and a step the platform kills mid-way is never
 *  counted, so it is redone, Opus and all, and the run's publish never
 *  comes. */
export const JELLY_BUDGET_MS = 12 * 60 * 1000;
/** The fewest points a polygon is asked for (the checker takes three), so
 *  the soft rounding has corners to follow the drawing by. */
const LEAST_POINTS = 6;
/** The thinnest a shape is asked to be anywhere, in the field's units: a
 *  thinner one shows under LEAST_SQUARES of the sim's grid. */
const THINNEST = 6;
const BAND_NAMES = ["Easy", "Medium", "Hard", "Insane"];
/** The render the eye is shown: the jelly flat on the card's cream. */
const RENDER_SIZE = 600;
const CREAM = "#f3ead8";
const INK_HEX = INKS.map((c) => "#" + c.map((v) => v.toString(16).padStart(2, "0")).join(""));

/** The spike's ask (spike_jelly_map.js, 2026-10-21); its refusals were all
 *  rules it had not stated, so the band's rules are stated in full in the
 *  prompt (mapRules), from the checker's own constants. */
const MAPPER = `You are a sweet-maker drawing the mould of a jelly for a children's puzzle. You are shown a flat sticker drawing of one thing on a plain green, magenta or cyan background, with a grid over it numbered 0 to 100 along the top and left (and again along the bottom and right). A point's x is read along the top numbers and y along the left numbers, as decimals.

Write the jelly as a list of parts. A part has a flavour, one of: cherry (red), orange, lemon (yellow), lime (green), blueberry (blue), grape (purple), and one to ${MOST_SHAPES} shapes. A shape is {"kind":"soft","n":[x1,y1,x2,y2,...]}: a polygon of ${LEAST_POINTS} to ${MOST_POINTS} points in order round its outline, which is drawn with its corners well rounded. Rules: the parts together make ONE connected piece of jelly in the thing's silhouette, sharp and true to the drawing (every part a child expects, in the drawing's proportions), every shape inside ${FIT[0]} to ${FIT[1]} on both axes; the shapes of neighbouring parts touch or overlap a little so no gap opens between them, and a shape drawn later lies over an earlier one; a shape must be big enough to pour (never thinner than ${THINNEST} units anywhere); ignore any white sticker border, outlines, highlights or shading in the drawing and give each region the flavour nearest its colour. Use the drawing's colours as the flavours, but keep to the band's counts. Answer with JSON only.`;

const MAP_SCHEMA = {type: "object", additionalProperties: false, required: ["parts"], properties: {
  parts: {type: "array", items: {type: "object", additionalProperties: false, required: ["flavour", "shapes"], properties: {
    flavour: {type: "string", enum: [...FLAVOURS]},
    shapes: {type: "array", items: {type: "object", additionalProperties: false, required: ["kind", "n"], properties: {kind: {type: "string", enum: ["soft"]}, n: {type: "array", items: {type: "number"}}}}},
  }}},
}};

/** Every rule why() checks for `band`, in words, with its numbers. */
export function mapRules(band: number): string {
  const r = RULES[band];
  const flavours = r.flavours[0] === r.flavours[1] ? `exactly ${r.flavours[0]}` : `${r.flavours[0]} to ${r.flavours[1]}`;
  const mixed = r.mixed ? `, at least ${r.mixed} of them mixed (orange, lime or grape)` : "";
  const square = 100 / GRID;
  return `${flavours} flavours in all${mixed}; ${r.chunks[0]} to ${r.chunks[1]} chunks in all, where a chunk is one connected blob of one flavour (two shapes of one flavour that touch are one chunk); at most ${MOST_PARTS} parts and ${MOST_SHAPES} shapes a part; ${LEAST_POINTS} to ${MOST_POINTS} points a polygon, so "n" holds ${2 * LEAST_POINTS} to ${2 * MOST_POINTS} numbers, an even count; every point inside ${FIT[0]} to ${FIT[1]} on both axes; the whole jelly one connected piece; the jelly covering ${Math.round(COVER[0] * 100)}% to ${Math.round(COVER[1] * 100)}% of the field (${Math.round(COVER[0] * 10000)} to ${Math.round(COVER[1] * 10000)} of its 10000 square units: measure it before you answer); every chunk at least ${LEAST_SQUARES} squares of a ${GRID} by ${GRID} grid of the field (a square is ${square.toFixed(1)} units, so a chunk at least about ${Math.ceil(Math.sqrt(LEAST_SQUARES) * square)} by ${Math.ceil(Math.sqrt(LEAST_SQUARES) * square)} units: a dot is not a chunk); nothing thinner than ${THINNEST} units; and where a later part cuts an earlier chunk into pieces each piece is a cell of its own, at most ${CELLS_TOP} cells in all`;
}

const isNumber = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);

/** The model's answer held to the parts' shape: the schema is asked for but
 *  not trusted. Parts an array, each a flavour string and shapes an array of
 *  {kind, n} whose n are all finite numbers; null for anything else, which
 *  the caller refuses as "a shape's numbers". why() judges the rest. */
export function asParts(got: unknown): Part[] | null {
  const parts = (got ?? {}) as {parts?: unknown};
  if (!Array.isArray(parts.parts)) return null;
  const out: Part[] = [];
  for (const p of parts.parts) {
    const q = (p ?? {}) as {flavour?: unknown; shapes?: unknown};
    if (typeof q.flavour !== "string" || !Array.isArray(q.shapes)) return null;
    const shapes: Shape[] = [];
    for (const s of q.shapes) {
      const k = (s ?? {}) as {kind?: unknown; n?: unknown};
      if (typeof k.kind !== "string" || !Array.isArray(k.n) || !k.n.every(isNumber)) return null;
      shapes.push({kind: k.kind as Shape["kind"], n: k.n.slice()});
    }
    out.push({flavour: q.flavour as Flavour, shapes});
  }
  return out;
}

/** The reviewer model's jelly of a sticker, read off it under the field's
 *  numbered grid; null when the answer is not parts at all (asParts).
 *  `refused` is what the last answer on the same drawing was told, a
 *  sentence, "" for a first ask. Throws as `ask` does. */
export async function mapJelly(drawing: Drawing, thing: Thing, band: number, refused: string): Promise<Part[] | null> {
  const grid = gridOver(drawing, JELLY_GRID_N, 5);
  const got = await ask<unknown>({
    system: MAPPER,
    role: "review",
    schema: MAP_SCHEMA,
    images: [dataUrl(grid.mime, grid.bytes)],
    prompt: `The drawing is of ${thing.name}. The band is ${BAND_NAMES[band]}, and the board's checker refuses a jelly that breaks any of these: ${mapRules(band)}.${refused === "" ? "" : `\n${refused}`}\nWrite the jelly.`,
  });
  return asParts(got);
}

/** What one thing's tries share. */
interface Ctx {
  day: number;
  theme: Theme;
  thing: Thing;
  band: number;
  /** When no new draw, ask, reader or written try may begin:
   *  JELLY_BUDGET_MS from the band's start, or the run's limit if sooner. */
  deadline: number;
  port: Port;
}

/** The best kept try so far. */
interface Best {
  score: number;
  verdict: Verdict;
  parts: Part[];
  render: Buffer;
  /** The sticker it was read off; none for a written jelly. */
  drawing?: Drawing;
}

/** A try on the thing's port, pushed before its work starts so a throw
 *  never loses it. */
function fresh(c: Ctx, route: PortTry["route"]): PortTry {
  const t: PortTry = {n: c.port.tries.length, route, why: "", kept: false};
  c.port.tries.push(t);
  return t;
}

const logTry = (c: Ctx, t: PortTry) => logLine("jelly", c.day, c.band, c.thing.id, t);

/** Whether the budget is spent; the first try it stops on the port is
 *  recorded, the rest are simply not made. */
function late(c: Ctx, route: PortTry["route"]): boolean {
  if (Date.now() <= c.deadline) return false;
  if (!c.port.tries.some((t) => t.why === "out of time")) {
    const t = fresh(c, route);
    t.why = "out of time";
    logTry(c, t);
  }
  return true;
}

/** Parts that came through asParts checked by the band's rules into `t`;
 *  whether they keep them. */
function checked(parts: Part[] | null, band: number, t: PortTry): boolean {
  if (parts === null) {
    t.why = "a shape's numbers";
    return false;
  }
  try {
    t.why = why(parts, band);
  } catch (e) {
    t.error = `why: ${said(e)}`;
    return false;
  }
  return t.why === "";
}

/** The parts drawn as the phone lays them, each shape of each part in
 *  order, and judged (beside the sticker when there is one) into `t`; the
 *  render, or null when it could not be made or the eye asked. */
async function judged(c: Ctx, parts: Part[], t: PortTry, drawing?: Drawing): Promise<Buffer | null> {
  let png: Buffer;
  try {
    const polys = parts.flatMap((p) => p.shapes.map((s) => ({pts: polygon(s), fill: INK_HEX[FLAVOURS.indexOf(p.flavour)]})));
    png = renderPolygons(polys, RENDER_SIZE, CREAM);
  } catch (e) {
    t.error = `render: ${said(e)}`;
    return null;
  }
  try {
    t.verdict = await judge(c.day, c.theme, c.thing, "jelly", dataUrl("image/png", png),
      drawing === undefined ? undefined : dataUrl(drawing.mime, drawing.bytes));
    t.kept = t.verdict.ok && t.verdict.score >= FLOOR.jelly;
    return png;
  } catch (e) {
    t.error = `judge: ${said(e)}`;
    return null;
  }
}

/** What the next ask is told of the last one, a sentence; "" when there
 *  is nothing to tell. */
function lesson(t: PortTry, thing: Thing): string {
  if (t.why !== "" && t.why !== "out of time") return `Your last answer was refused by the board's checker: "${t.why}". Write it again so it passes.`;
  if (t.verdict !== undefined) {
    const took = t.verdict.pick === thing.name.toLowerCase() ? "" : `, took it for ${t.verdict.pick}`;
    return `A reviewer scored your last answer ${t.verdict.score} of 10${took}, and said: ${t.verdict.notes} Write it again, mending that.`;
  }
  return "";
}

/** One ask for a sticker's jelly, checked and judged, into `t`. Never
 *  throws: each stage's error is written on the try. */
async function mapTry(c: Ctx, drawing: Drawing, refused: string, t: PortTry, seen: Map<PortTry, Part[]>): Promise<Best | null> {
  let parts: Part[] | null;
  try {
    parts = await mapJelly(drawing, c.thing, c.band, refused);
  } catch (e) {
    t.error = `ask: ${said(e)}`;
    return null;
  }
  if (parts !== null) seen.set(t, parts);
  if (!checked(parts, c.band, t)) return null;
  const render = await judged(c, parts!, t, drawing);
  return render === null ? null : {score: t.verdict!.score, verdict: t.verdict!, parts: parts!, render, drawing};
}

/** The pixel reader on a sticker, judged as a map is, into `t`. */
async function readerTry(c: Ctx, drawing: Drawing, t: PortTry, seen: Map<PortTry, Part[]>): Promise<Best | null> {
  let got: ReturnType<typeof readJelly>;
  try {
    got = readJelly(drawing, c.band);
  } catch (e) {
    t.error = `read: ${said(e)}`;
    return null;
  }
  // the reader's own why: it says "nothing drawn" where why([]) says "parts"
  const parts = got.parts;
  seen.set(t, parts);
  t.why = got.why;
  if (t.why !== "") return null;
  const render = await judged(c, parts, t, drawing);
  return render === null ? null : {score: t.verdict!.score, verdict: t.verdict!, parts, render, drawing};
}

/** The kept try's drawing and render on the port, shrunk as the vistas are. */
function keepOnPort(c: Ctx, best: Best): void {
  try {
    if (best.drawing !== undefined) c.port.source = shrunk(best.drawing).bytes.toString("base64");
    c.port.render = shrunk({mime: "image/png", bytes: best.render}).bytes.toString("base64");
  } catch (e) {
    console.error(`jelly: day ${c.day}, band ${c.band}, ${c.thing.id}: the kept try not shrunk`, e);
  }
}

/**
 * A thing of the theme drawn as a sticker in the flavours, DRAWINGS[band]
 * times, each mapped up to JELLY_ASKS times by the reviewer model; every
 * answer checked by the band's rules and the passing ones judged by the
 * eye. The first try the eye keeps ends the thing's asks and drawings (the
 * controller, 2026-10-21: a kept jelly is good enough, more asks only cost;
 * the hoop still takes the best of its tries). When none is kept the pixel
 * reader on the last sticker is one more try. `t` is the drawn route's
 * summary, of one try: the kept one, or the last; `port` records every
 * try. Never throws.
 */
export async function drawJelly(day: number, theme: Theme, thing: Thing, band: number, t: JellyTry,
  keep?: (name: string, d: Drawing) => void, deadline = Date.now() + JELLY_BUDGET_MS): Promise<{parts: Part[] | null; port: Port}> {
  const c: Ctx = {day, theme, thing, band, deadline, port: {game: "jelly", band, thing: thing.id, tries: []}};
  // the clock first: a thing the budget does not reach asks nothing, not
  // even its key
  if (late(c, "map")) {
    t.why = "out of time";
    return {parts: null, port: c.port};
  }
  // keyFor never throws by design; caught all the same, so nothing before
  // the tries can lose the port
  let key: Key = "green";
  try {
    ({key} = await keyFor(thing));
  } catch (e) {
    console.error(`jelly: day ${day}, band ${band}, ${thing.id}: no key`, e);
  }
  // each try's parts, so the summary's parts are the try it describes
  const seen = new Map<PortTry, Part[]>();
  let best: Best | null = null;
  let last: Drawing | null = null;
  for (let n = 0; n < DRAWINGS[band] && best === null; n++) {
    if (late(c, "map")) break;
    let drawing: Drawing;
    try {
      drawing = await draw(STICKER(thing.draw, band, key), shapesModel());
    } catch (e) {
      const failed = fresh(c, "map");
      failed.error = `draw: ${said(e)}`;
      logTry(c, failed);
      continue;
    }
    last = drawing;
    try {
      keep?.(`${day}_jelly${band}_${thing.id}_${n}`, drawing);
    } catch (e) {
      console.error(`jelly: day ${day}, band ${band}, ${thing.id}: drawing ${n} not kept`, e);
    }
    let refused = "";
    for (let a = 0; a < JELLY_ASKS && best === null; a++) {
      if (late(c, "map")) break;
      const tried = fresh(c, "map");
      const got = await mapTry(c, drawing, refused, tried, seen);
      logTry(c, tried);
      if (tried.kept && got !== null) best = got;
      refused = lesson(tried, thing);
    }
  }
  if (best === null && last !== null && !late(c, "reader")) {
    const tried = fresh(c, "reader");
    const got = await readerTry(c, last, tried, seen);
    logTry(c, tried);
    if (tried.kept && got !== null) best = got;
  }
  if (best === null) {
    // the summary says how the last try ended, never "" for a thing that
    // failed (a draw that threw has only an error), with that try's parts
    const gone = c.port.tries[c.port.tries.length - 1];
    Object.assign(t, {parts: gone === undefined ? undefined : seen.get(gone), why: (gone?.why || gone?.error) ?? "nothing tried",
      error: gone?.error, verdict: gone?.verdict});
    return {parts: null, port: c.port};
  }
  keepOnPort(c, best);
  Object.assign(t, {parts: best.parts, why: "", verdict: best.verdict, kept: true});
  console.log(`jelly: day ${day}, band ${band}, ${thing.id}: ${best.parts.length} parts, score ${best.score}`);
  return {parts: best.parts, port: c.port};
}

/** The jelly written from words, as before 2026-10-16, when no drawing gave
 *  one: up to TRIES writes, each told why the last fell short, the passing
 *  ones judged by the eye on the render alone (there is no drawing), the
 *  first it keeps ending them. Each try is on `tries` and on the port. */
async function writeJelly(c: Ctx, tries: JellyTry[]): Promise<Part[] | null> {
  const model = (process.env.DAILY_ROWS_MODEL ?? "").trim() || DEFAULT_ROWS_MODEL;
  let best: Best | null = null;
  let last = "";
  for (let n = 0; n < TRIES && best === null; n++) {
    if (late(c, "written")) break;
    const t = fresh(c, "written");
    const j: JellyTry = {band: c.band, what: c.thing.id, route: "written", why: "", kept: false};
    tries.push(j);
    let parts: Part[] | null = null;
    try {
      parts = asParts(await ask<unknown>({system: SYSTEM, prompt: asked(c.thing, c.band, last), schema: SCHEMA, model}));
    } catch (e) {
      t.error = `ask: ${said(e)}`;
    }
    if (t.error === undefined && checked(parts, c.band, t)) {
      const render = await judged(c, parts!, t);
      if (t.kept && render !== null) best = {score: t.verdict!.score, verdict: t.verdict!, parts: parts!, render};
    }
    logTry(c, t);
    // never "" for a try that failed: an ask that threw has only an error
    Object.assign(j, {parts: parts ?? undefined, why: t.why || (t.error ?? ""), verdict: t.verdict, kept: t.kept, error: t.error});
    last = t.why !== "" ? t.why : t.verdict !== undefined && !t.kept ? `shown to someone, they took it for ${t.verdict.pick || "nothing"} and scored it ${t.verdict.score} of 10: ${t.verdict.notes}` : "";
  }
  if (best === null) return null;
  keepOnPort(c, best);
  return best.parts;
}
