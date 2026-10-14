import {ask, available} from "./generate";
import {DEFAULT_ROWS_MODEL, lookThing, Tried} from "./pictures";
import {Theme, Thing} from "./theme";

/**
 * The day's Gumdrop jellies (docs/superpowers/specs/
 * 2026-10-14-gumdrop-themed-jelly-design.md): the theme's things, one a
 * mould -- Easy's two, Medium's three, Hard's four, Insane's five, each
 * band's at its own rules -- written as a jelly's parts -- the same ellipses, rounded boxes and
 * soft polygons puzzles/gumdrop_mould.gd's twenty-nine are made of, so a
 * themed jelly is built and drawn by the same code as theirs.
 *
 * A text model writes the parts; the band's rules below are checked in
 * code on the same shapes the phone builds; and the blind look of the bead
 * pictures (lookThing) is shown the jelly laid as beads in its flavours'
 * colours and has to name the thing. A band whose tries all fail is left
 * out, and the board fills that place from its twenty-nine.
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
  what: string;
  parts?: Part[];
  /** What the rules found, "" when it keeps them. */
  why: string;
  look?: Tried["look"];
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
const MOST_PARTS = 8;
const MOST_SHAPES = 8;
/** The phone makes a cell of every piece a later chunk leaves of an
 *  earlier one (gumdrop_mould.gd build_parts, 2026-10-14), a piece under
 *  SLIVER of the field's 100 by 100 going to the chunk that cut it; its
 *  passes hold CELLS_TOP cells, so a jelly whose cut pieces come to more
 *  is dropped there, and so refused here. */
const CELLS_TOP = 16;
const SLIVER = 24;
const MOST_POINTS = 16;
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
 *  list a band in the theme's order, and what became of every try. A thing
 *  whose tries all fail is left out of its band's list, and the board fills
 *  its place from the twenty-nine. Never throws. */
export async function makeJellies(day: number, theme: Theme, only?: number): Promise<{jellies: Record<string, Jelly[]>; tries: JellyTry[]}> {
  const jellies: Record<string, Jelly[]> = {};
  const tries: JellyTry[] = [];
  if (!available()) return {jellies, tries};
  const model = (process.env.DAILY_ROWS_MODEL ?? "").trim() || DEFAULT_ROWS_MODEL;
  // One jelly: up to TRIES writes, each told why the last was turned down.
  const one = async (band: number, thing: Thing): Promise<Jelly | null> => {
    let last = "";
    for (let n = 0; n < TRIES; n++) {
      const t: JellyTry = {band, what: thing.id, why: "", kept: false};
      tries.push(t);
      try {
        const got = await ask<{parts: Part[]}>({system: SYSTEM, prompt: asked(thing, band, last), schema: SCHEMA, model});
        t.parts = got.parts;
        t.why = why(got.parts, band);
        last = t.why;
        if (t.why !== "") continue;
        t.look = await lookThing(day, beads(got.parts), thing, theme);
        if (!t.look.ok) {
          last = `shown to someone, they took it for ${t.look.said || "nothing"}`;
          continue;
        }
        t.kept = true;
        return {id: thing.id, name: {en: thing.name, pt: thing.pt, es: thing.es}, parts: got.parts};
      } catch (e) {
        t.error = String(e).slice(0, 300);
        console.error(`jelly: day ${day}, band ${band}, ${thing.id}, try ${n} failed`, e);
      }
    }
    return null;
  };
  // Fourteen jellies a day, one request at a time: side by side, the four
  // bands' Opus requests ran past OpenRouter's in-flight credit budget
  // (HTTP 402, 2026-10-14).
  // `only`: that band alone, so the night writes a band a run (index.ts).
  for (let band = 0; band < RULES.length; band++) {
    if (only !== undefined && band !== only) continue;
    const list: Jelly[] = [];
    for (const thing of theme.objects.slice(0, MOULDS[band])) {
      const got = await one(band, thing);
      if (got !== null) list.push(got);
    }
    if (list.length > 0) jellies[band] = list;
  }
  const kept = Object.entries(jellies).map(([b, l]) => `${b}:${l.length}`).join(" ");
  console.log(`jelly: day ${day} (${theme.id}), kept ${kept || "none"} in ${tries.length} tries`);
  return {jellies, tries};
}
