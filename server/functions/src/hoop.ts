import fs from "node:fs";
import path from "node:path";
import {ask, draw, Drawing, shapesModel} from "./generate";
import {dataUrl, FLOOR, judge, renderPolygons} from "./eye";
import {gridOver, GRID_N} from "./grid";
import {checkMesh, colourFrom, ModelMap, repairMesh} from "./mesh";
import {Port, PortTry} from "./ports";
import {shrunk} from "./vistas";
import {area, board, compact, dissolve, fewer, grow, join, network, raster, Raster, Regions, SIDE, split, touching, unring, unshadow} from "./facets";
import {keyFor, keyWords, Key, KEY_HEX} from "./key";
import {Theme, Thing} from "./theme";

/**
 * The day's Yarn Hoop pictures (puzzles/hoop_state.gd): a thing of the
 * theme a band, drawn by the image model as a low-poly illustration -- flat
 * facets, each one colour, shaded by the facet -- and read back as the
 * board's panels: the facets' corners are the pins and every facet a panel
 * of three to seven corners (one with more, or bent in, is cut along its
 * own corners into such panels). Until 2026-10-16 the board cut the day's
 * bead picture into triangles on the phone, and a picture whose readable
 * parts were one-square lines (a shell's spiral, a fish's eye) came out a
 * blob of one colour (the user: "images on gumdrop and yarn hoop are
 * terrible").
 *
 * Shipped as geometry, so the phone lays exactly what was checked here.
 */

export interface HoopPanel {
  /** Its corners, indexes into the pins, clockwise on screen. */
  k: number[];
  /** Its colour, "#rrggbb". */
  c: string;
}

export interface HoopPicture {
  id: string;
  name: {en: string; pt: string; es: string};
  /** The pins, x and y in turn, in a square of 100 the thing is centred in. */
  pins: number[];
  panels: HoopPanel[];
}

/** By band: the facets the drawing is asked for, the most panels kept
 *  (Insane is played through the zoom), the least room between two pins in
 *  the 256-pixel reading (a finger's width on the whole view: some 16 on
 *  Easy, 8 on Hard), and how closely the facets' sides are followed. */
export const BANDS = [
  {facets: "25 to 35 large", most: 40, least: 13, tol: 2.2},
  {facets: "40 to 55", most: 60, least: 10, tol: 1.8},
  {facets: "70 to 90", most: 95, least: 8, tol: 1.5},
  {facets: "130 to 170 small", most: 170, least: 6, tol: 1.2},
];
/** The fewest panels a band's picture may come to. */
export const LEAST_PANELS = [16, 26, 40, 80];
export const MOST_CORNERS = 7;

export const PROMPT = (what: string, band: number, key: Key, creature: boolean) => `A low-poly illustration of ${what}, built from at least 150 and about 200 small flat polygon facets (mostly triangles) on every band, the big surfaces broken into many small facets too: a soft, muted, harmonious palette of gentle earthy pastels; each facet is ONE flat solid colour; neighbouring facets shift subtly in tone as if lit softly from the top left (a light, a mid and a shadow tone of each colour); crisp straight edges; no outlines, no lines between facets, no gradient inside a facet, no texture. ${creature ? "" : "It is an object: no face, no eyes, no mouth. "}One thing only, centred and large, filling most of the picture, on ${keyWords(key)}; no cast shadow, no ground, nothing else, no text. A square picture.`;

type P = number[];

function cross(o: P, a: P, b: P): number {
  return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
}

/** Whether a clockwise-on-screen polygon bends nowhere inward (a straight
 *  corner allowed). */
export function convex(p: P[]): boolean {
  for (let i = 0; i < p.length; i++) {
    if (cross(p[i], p[(i + 1) % p.length], p[(i + 2) % p.length]) < -1e-6) return false;
  }
  return true;
}

function smallestAngle(a: P, b: P, c: P): number {
  const ang = (o: P, u: P, v: P) => {
    const x1 = u[0] - o[0], y1 = u[1] - o[1], x2 = v[0] - o[0], y2 = v[1] - o[1];
    return Math.acos(Math.max(-1, Math.min(1, (x1 * x2 + y1 * y2) / (Math.hypot(x1, y1) * Math.hypot(x2, y2) || 1))));
  };
  return Math.min(ang(a, b, c), ang(b, c, a), ang(c, a, b));
}

function inTri(p: P, a: P, b: P, c: P): boolean {
  return cross(a, b, p) >= 0 && cross(b, c, p) >= 0 && cross(c, a, p) >= 0;
}

/** Ears clipped, the best-shaped ear first, of a clockwise-on-screen
 *  polygon given as pin indexes; [] when it will not go. */
export function ears(ids: number[], pins: P[]): number[][] {
  const left = ids.slice();
  const out: number[][] = [];
  while (left.length > 3) {
    let best = -1, bestA = -1;
    for (let i = 0; i < left.length; i++) {
      const a = pins[left[(i + left.length - 1) % left.length]], b = pins[left[i]], c = pins[left[(i + 1) % left.length]];
      if (cross(a, b, c) <= 1e-9) continue;
      let clear = true;
      for (const j of left) {
        const q = pins[j];
        if (q === a || q === b || q === c) continue;
        if (inTri(q, a, b, c)) { clear = false; break; }
      }
      if (!clear) continue;
      const ang = smallestAngle(a, b, c);
      if (ang > bestA) { bestA = ang; best = i; }
    }
    if (best < 0) return [];
    out.push([left[(best + left.length - 1) % left.length], left[best], left[(best + 1) % left.length]]);
    left.splice(best, 1);
  }
  out.push(left);
  return out;
}

/** Pieces of one region joined back across their shared sides while the
 *  join stays convex and within MOST_CORNERS: Hertel and Mehlhorn's way. */
export function regroup(pieces: number[][], pins: P[]): number[][] {
  let list = pieces.map((p) => p.slice());
  for (let changed = true; changed;) {
    changed = false;
    let best: [number, number, number[]] | null = null;
    for (let a = 0; a < list.length && best === null; a++) {
      for (let b = a + 1; b < list.length; b++) {
        const joined = glue(list[a], list[b]);
        if (joined === null || joined.length > MOST_CORNERS || !convex(joined.map((i) => pins[i]))) continue;
        best = [a, b, joined];
        break;
      }
    }
    if (best !== null) {
      list[best[0]] = best[2];
      list = list.filter((_, i) => i !== best![1]);
      changed = true;
    }
  }
  return list;
}

/** Two polygons that share exactly one side as one, or null. */
function glue(a: number[], b: number[]): number[] | null {
  for (let i = 0; i < a.length; i++) {
    const p = a[i], q = a[(i + 1) % a.length];
    // b runs the side the other way
    const j = b.indexOf(q);
    if (j < 0 || b[(j + 1) % b.length] !== p) continue;
    const out: number[] = [];
    for (let k = 0; k < a.length; k++) out.push(a[(i + 1 + k) % a.length]);
    // a from q round to p, then b's corners after p up to before q
    for (let k = 2; k < b.length; k++) out.push(b[(j + k) % b.length]);
    return new Set(out).size === out.length ? out : null;
  }
  return null;
}

/**
 * The regions' outlines as pins and panels. Pins nearer than `least` are
 * made one (where four facets meet the drawing often has two corners a
 * pixel apart); an outline left under three corners is let go.
 */
export function panels(reg: Regions, tol: number, least: number): {pins: P[]; panels: {k: number[]; region: number}[]} {
  const net = network(reg, tol);
  const m = reg.n + 1;
  const pinOf = new Map<number, number>();
  const pins: P[] = [];
  const loops: {ids: number[]; region: number}[] = [];
  net.loops.forEach((loop, idx) => {
    const ids: number[] = [];
    for (const c of loop) {
      if (!net.kept.has(c)) continue;
      let k = pinOf.get(c);
      if (k === undefined) {
        k = pins.length;
        pinOf.set(c, k);
        pins.push([c % m, (c - (c % m)) / m]);
      }
      if (ids[ids.length - 1] !== k) ids.push(k);
    }
    while (ids.length > 1 && ids[0] === ids[ids.length - 1]) ids.pop();
    // the region of the loop: the label left of its first step
    loops.push({ids, region: regionOf(reg, loop)});
    void idx;
  });
  // pins too near made one, the nearest first, whether a side joins them
  // or not, and even where an outline closes under 3 corners (it is let go
  // below, its neighbours meeting along its long side): kept, a sliver left
  // two pins a pixel apart and three facets meeting a knot of three (the
  // user, 2026-10-20: "still grouping points together")
  const root = pins.map((_, i) => i);
  const find = (i: number): number => (root[i] === i ? i : (root[i] = find(root[i])));
  const near: [number, number, number][] = [];
  for (let a = 0; a < pins.length; a++) {
    for (let b = a + 1; b < pins.length; b++) {
      const d = Math.hypot(pins[a][0] - pins[b][0], pins[a][1] - pins[b][1]);
      if (d < least) near.push([d, a, b]);
    }
  }
  near.sort((x, y) => x[0] - y[0]);
  // the pin more outlines meet at stays where it is (moved, it would drag
  // the sides of every outline on it across their neighbours), and before
  // that one on the picture's edge, so the thing's outline is kept
  const meets = pins.map(() => 0);
  const once = new Map<string, boolean>();
  for (const {ids} of loops) {
    for (let i = 0; i < ids.length; i++) {
      const a = ids[i], b = ids[(i + 1) % ids.length];
      meets[a] += 1;
      const key = a < b ? `${a},${b}` : `${b},${a}`;
      once.set(key, !once.has(key));
    }
  }
  for (const [key, edge] of once) {
    if (!edge) continue;
    for (const i of key.split(",")) meets[Number(i)] += 1000;
  }
  for (const [, a, b] of near) {
    const ra = find(a), rb = find(b);
    if (ra === rb) continue;
    if (Math.hypot(pins[ra][0] - pins[rb][0], pins[ra][1] - pins[rb][1]) >= least) continue;
    const [keep, gone] = meets[ra] > meets[rb] || (meets[ra] === meets[rb] && ra < rb) ? [ra, rb] : [rb, ra];
    meets[keep] += meets[gone];
    root[gone] = keep;
  }
  const out: {k: number[]; region: number}[] = [];
  const drops: string[] = [];
  for (const {ids, region} of loops) {
    const k: number[] = [];
    for (const i of ids) {
      const r = find(i);
      if (k[k.length - 1] !== r) k.push(r);
    }
    while (k.length > 1 && k[0] === k[k.length - 1]) k.pop();
    for (const loop of simpleLoops(k)) {
      if (loop.length < 3) continue;
      const a = area(loop.map((i) => pins[i]));
      if (Math.abs(a) < least * least * 0.15) { drops.push(`r${region} area ${Math.round(a)}`); continue; }
      const cw = a > 0 ? loop : loop.slice().reverse();
      if (cw.length <= MOST_CORNERS && convex(cw.map((i) => pins[i]))) {
        out.push({k: cw, region});
        continue;
      }
      const tris = ears(cw, pins);
      if (tris.length === 0) drops.push(`r${region} no ears of ${cw.length}`);
      for (const piece of regroup(tris, pins)) out.push({k: piece, region});
    }
  }
  // the pins in use, numbered again
  const used = new Map<number, number>();
  const kept: P[] = [];
  for (const p of out) {
    p.k = p.k.map((i) => {
      let j = used.get(i);
      if (j === undefined) { j = kept.length; used.set(i, j); kept.push(pins[i]); }
      return j;
    });
  }
  if (drops.length > 0 && process.env.HOOP_DEBUG) console.log("dropped:", drops.join("; "));
  return {pins: kept, panels: out};
}

/** An outline that passes a pin twice (a region pinched to a point) as
 *  the loops either side of the pinch. */
function simpleLoops(k: number[]): number[][] {
  const out: number[][] = [];
  const stack: number[] = [];
  for (const i of k) {
    const at = stack.indexOf(i);
    if (at >= 0) {
      out.push(stack.splice(at + 1));
    } else {
      stack.push(i);
    }
  }
  out.push(stack);
  return out;
}

/** How many pins lie inside a panel they are not a corner of: none, in a
 *  cut whose panels tile without overlapping. */
export function overlaps(pins: P[], list: {k: number[]}[], which = false): number | Set<number> {
  let bad = 0;
  const caught = new Set<number>();
  const users = pins.map(() => [] as number[]);
  list.forEach((p, k) => { for (const i of p.k) users[i].push(k); });
  for (const [k, p] of list.entries()) {
    const poly = p.k.map((i) => pins[i]);
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const [x, y] of poly) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
    pins.forEach(([x, y], i) => {
      if (x <= x0 || x >= x1 || y <= y0 || y >= y1 || p.k.includes(i)) return;
      // strictly inside: every side's cross product the same sign, with room
      let inside = true;
      for (let m = 0; m < poly.length && inside; m++) {
        if (cross(poly[m], poly[(m + 1) % poly.length], [x, y]) <= 0.05) inside = false;
      }
      if (inside) {
        bad++;
        caught.add(k);
        for (const u of users[i]) caught.add(u);
      }
    });
  }
  return which ? caught : bad;
}

function regionOf(reg: Regions, loop: number[]): number {
  const m = reg.n + 1;
  const a = loop[0], b = loop[1 % loop.length];
  const ax = a % m, ay = (a - ax) / m, bx = b % m, by = (b - bx) / m;
  const dx = bx - ax, dy = by - ay;
  // the pixel left of the step (y down: left of (dx, dy) is (dy, -dx))
  const px = Math.floor(ax + 0.5 * dx + 0.5 * dy), py = Math.floor(ay + 0.5 * dy - 0.5 * dx);
  return reg.label[py * reg.n + px];
}

const hex = (c: number[]) => "#" + c.map((v) => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0")).join("");

/** A drawing read as a band's panels; `why` says what is wrong with them,
 *  "" when nothing is. The regions are joined, nearest colours first, until
 *  the panels they are cut into come to the band's most. */
export function readHoop(d: Drawing | Raster, band: number): {pins: number[]; panels: HoopPanel[]; why: string} {
  const rule = BANDS[band];
  const r = "rgb" in d ? d : raster(d);
  const bg = board(r);
  let reg = unshadow(grow(r, bg, 16), r);
  reg = dissolve(reg, r, Math.max(8, rule.least * rule.least * 0.2), 1);
  reg = unring(reg, r);
  let regions = Math.round(rule.most * 0.8);
  let got = panels(reg, rule.tol, rule.least);
  let cut = reg;
  for (let n = 0; n < 12; n++) {
    cut = unring(fewer(split(reg), r, regions, rule.least * rule.least * 1.5, true), null);
    // a region whose simplified outline folds across a neighbour (a sliver
    // the cut left beside an eye) joined to the neighbour it shares most
    // with, the smallest of those caught first, and the cut made again
    for (let fold = 0; fold < 12; fold++) {
      got = panels(cut, rule.tol, rule.least);
      const caught = overlaps(got.pins, got.panels, true) as Set<number>;
      if (caught.size === 0) break;
      const regionsCaught = [...caught].map((k) => got.panels[k].region).filter((g) => cut.size[g] > 0);
      if (regionsCaught.length === 0) break;
      const small = regionsCaught.reduce((a, b) => (cut.size[a] <= cut.size[b] ? a : b));
      let to = -1, most = 0;
      for (const [b, shared] of touching(cut)[small]) if (shared > most) { most = shared; to = b; }
      if (to < 0) break;
      const keep = cut.colour[to];
      join(cut, to, small);
      cut.colour[to] = keep;
      cut = unring(split(compact(cut.n, cut.label, null, cut.colour)), null);
    }
    if (got.panels.length <= rule.most) break;
    regions = Math.max(4, Math.floor(regions * Math.min(0.92, rule.most / got.panels.length)));
  }
  let why = "";
  const crossed = overlaps(got.pins, got.panels) as number;
  if (crossed > 0) why = `${crossed} pins inside another panel`;
  if (got.panels.length < LEAST_PANELS[band]) why = `${got.panels.length} panels, under ${LEAST_PANELS[band]}`;
  if (got.panels.length > rule.most) why = `${got.panels.length} panels, over ${rule.most}`;
  // into a square of 100, centred
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const [x, y] of got.pins) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const s = 100 / Math.max(x1 - x0, y1 - y0);
  const ox = (100 - (x1 - x0) * s) / 2, oy = (100 - (y1 - y0) * s) / 2;
  const pins: number[] = [];
  for (const [x, y] of got.pins) pins.push(Math.round(((x - x0) * s + ox) * 100) / 100, Math.round(((y - y0) * s + oy) * 100) / 100);
  return {pins, panels: got.panels.map((p) => ({k: p.k, c: hex(cut.colour[p.region])})), why};
}

/** A band's drawings, and the model's asks for the map of each. */
export const HOOP_DRAWINGS = 2;
export const MAP_ASKS = 2;
/** A kept try scored this well is not bettered by more asks. */
const ENOUGH = 9;
/** Past this long from makeHoop's start no draw, ask, judge or reader try
 *  begins: a run may start the step 15 minutes into its 30-minute lease
 *  (themeday.ts), and a step killed mid-way is never written or given up
 *  on, so every step after it would wait. */
export const HOOP_BUDGET_MS = 12 * 60 * 1000;
const BAND_NAMES = ["Easy", "Medium", "Hard", "Insane"];
/** The render the eye is shown: the board's linen and its ropes along every
 *  side, as the phone knits the picture. */
const RENDER_SIZE = 600;
const LINEN = "#efe2c6";
const ROPE = {colour: "#7a4a3a", width: 0.6};

/** The spike's ask (2026-10-21), and after it the rules the night checks
 *  the map by as the phone does: a map that breaks one is refused. */
const MAPPER = `You are a low-poly artist turning a drawing into the map of a puzzle board. The drawing is a low-poly illustration of one thing on a plain green, magenta or cyan background, with a numbered grid laid over it: the grid lines are numbered 0..N along the top and left (and again along the bottom and right). A point's x is its position along the top numbers and y its position along the left numbers, as decimals (x 7.5 is halfway between lines 7 and 8).

Write the map as pins and panels. A pin is a corner, with an integer id. A panel is one flat facet of the drawing: a list of 3 to 7 pin ids in order round its outline, and its colour as #rrggbb read off the drawing. Rules: the panels tile the THING exactly and nothing of the background: every facet of the drawing is a panel (merge only facets that are the same colour and together make a convex 3-7 sided shape); neighbouring panels share their pins and their whole side (never a corner of one panel lying in the middle of another's side, never two panels overlapping, never a gap); every panel is convex; the thing's outline is traced faithfully, every part of it (a snail's eye stalks, a kettle's spout and knob). Place every pin where the drawing's corners really are, as precisely as the grid allows. Answer with JSON only.

The map is checked exactly as the board will lay it, and refused if it breaks any of these: every panel has 3 to 7 corners and is convex; neighbouring panels share whole sides, pin for pin; no two panels overlap and no gap is left between them; no panel covers any of the background; every facet of the drawing is kept. Pins nearer together than about one grid cell are welded into one on the board, so a thin part (a handle, a stalk, a shaft, a leg) is drawn as a panel at least one grid cell wide, never thinner, or it vanishes. Use the whole panel budget: write close to the most panels the board allows, splitting the big facets along their light and shade; a map with fewer than the least it names is refused.`;

const MAP_SCHEMA = {type: "object", additionalProperties: false, required: ["pins", "panels"], properties: {
  pins: {type: "array", items: {type: "object", additionalProperties: false, required: ["id", "x", "y"], properties: {id: {type: "integer"}, x: {type: "number"}, y: {type: "number"}}}},
  panels: {type: "array", items: {type: "object", additionalProperties: false, required: ["pins", "colour"], properties: {pins: {type: "array", items: {type: "integer"}}, colour: {type: "string"}}}},
}};

const isNumber = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);

/** The model's answer held to the map's shape: the schema is asked for but
 *  not trusted, and a pin whose x or y is not a number (null, a string)
 *  would be read as a pin at 0, so it is let go here. */
function asMap(got: unknown): ModelMap {
  const o = (got ?? {}) as {pins?: unknown; panels?: unknown};
  const pins: ModelMap["pins"] = [];
  for (const p of Array.isArray(o.pins) ? o.pins : []) {
    const q = (p ?? {}) as {id?: unknown; x?: unknown; y?: unknown};
    if (isNumber(q.id) && isNumber(q.x) && isNumber(q.y)) pins.push({id: q.id, x: q.x, y: q.y});
  }
  const panels: ModelMap["panels"] = [];
  for (const p of Array.isArray(o.panels) ? o.panels : []) {
    const q = (p ?? {}) as {pins?: unknown; colour?: unknown};
    if (!Array.isArray(q.pins)) continue;
    panels.push({pins: q.pins.filter(isNumber), colour: String(q.colour ?? "")});
  }
  return {pins, panels};
}

/** The reviewer model's map of a drawing, read off it with the band's
 *  numbered grid over it. `refused` is what was wrong with its last map of
 *  the same drawing, "" for a first ask. Throws as `ask` does. */
export async function mapHoop(drawing: Drawing, thing: Thing, band: number, refused: string): Promise<ModelMap> {
  const n = GRID_N[band];
  const grid = gridOver(drawing, n, 1);
  const most = BANDS[band].most;
  const again = refused === "" ? "" : ` Your last map of this drawing fell short: ${refused}. Write it again, mending that.`;
  const got = await ask<unknown>({
    system: MAPPER,
    role: "review",
    schema: MAP_SCHEMA,
    images: [dataUrl(grid.mime, grid.bytes)],
    prompt: `The drawing is of ${thing.name}; the grid is ${n} by ${n}. The board takes at most ${most} panels (${BAND_NAMES[band]}) and refuses fewer than ${LEAST_PANELS[band]}: use the whole budget, about ${most}, and cover every facet of the drawing.${again} Write the map.`,
  });
  return asMap(got);
}

let style: Drawing | null = null;
/** The low-poly snail the drawings are made in the style of, copied beside
 *  the build (package.json's build). */
function styleRef(): Drawing {
  if (style === null) {
    style = {mime: "image/png", bytes: fs.readFileSync(path.join(__dirname, "hoop_style.png"))};
  }
  return style;
}

/** What one band's tries share. */
interface Ctx {
  day: number;
  theme: Theme;
  thing: Thing;
  band: number;
  key: Key;
  /** When no new call may begin (HOOP_BUDGET_MS from the start). */
  deadline: number;
  /** A try has been recorded as out of time: the first skipped is said
   *  once on the port, the rest are simply not made. */
  out: boolean;
}

/** The best kept try so far. */
interface Best {
  score: number;
  pins: number[];
  panels: HoopPanel[];
  drawing: Drawing;
  render: Buffer;
}

const said = (e: unknown) => String(e instanceof Error ? e.message : e).slice(0, 300);

/** Pins and panels drawn as the eye sees them and judged beside the drawing,
 *  into `t`; the render, or null when the eye could not be asked. */
async function judged(c: Ctx, drawing: Drawing, pins: number[], panels: HoopPanel[], t: PortTry): Promise<Buffer | null> {
  if (Date.now() > c.deadline) {
    t.why = "out of time";
    c.out = true;
    return null;
  }
  try {
    const polys = panels.map((p) => ({pts: p.k.map((i) => [pins[2 * i], pins[2 * i + 1]]), fill: p.c}));
    const png = renderPolygons(polys, RENDER_SIZE, LINEN, ROPE);
    t.verdict = await judge(c.day, c.theme, c.thing, "hoop", dataUrl("image/png", png), dataUrl(drawing.mime, drawing.bytes));
    t.kept = t.verdict.ok && t.verdict.score >= FLOOR.hoop;
    return png;
  } catch (e) {
    t.error = `judge: ${said(e)}`;
    return null;
  }
}

/** One ask for a drawing's map, repaired, coloured off the drawing (its
 *  background panels dropped), checked again and judged, into `t`. Never
 *  throws: each stage's error is written on the try. */
async function mapTry(c: Ctx, drawing: Drawing, refused: string, t: PortTry): Promise<Best | null> {
  let got: ModelMap;
  try {
    got = await mapHoop(drawing, c.thing, c.band, refused);
  } catch (e) {
    t.error = `ask: ${said(e)}`;
    return null;
  }
  let pins: number[], panels: HoopPanel[];
  try {
    const mesh = repairMesh(got, GRID_N[c.band], c.band);
    // the background dropped can bring the counts under or within the band
    colourFrom(raster(drawing), mesh, KEY_HEX[c.key]);
    t.why = checkMesh(mesh, c.band);
    pins = mesh.pins;
    panels = mesh.panels;
  } catch (e) {
    t.error = `repair: ${said(e)}`;
    return null;
  }
  if (t.why !== "") return null;
  const render = await judged(c, drawing, pins, panels, t);
  return render === null ? null : {score: t.verdict!.score, pins, panels, drawing, render};
}

/** The pixel reader on a drawing, judged as a map is, into `t`. */
async function readerTry(c: Ctx, drawing: Drawing, t: PortTry): Promise<Best | null> {
  let got: ReturnType<typeof readHoop>;
  try {
    got = readHoop(drawing, c.band);
  } catch (e) {
    t.error = `read: ${said(e)}`;
    return null;
  }
  t.why = got.why;
  if (got.why !== "") return null;
  const render = await judged(c, drawing, got.pins, got.panels, t);
  return render === null ? null : {score: t.verdict!.score, pins: got.pins, panels: got.panels, drawing, render};
}

/** What the next ask on the same drawing is told of the last one. */
function lesson(t: PortTry, thing: Thing): string {
  if (t.why !== "") return `it was refused (${t.why})`;
  if (t.verdict !== undefined) {
    const took = t.verdict.pick === thing.name.toLowerCase() ? "" : `, took it for ${t.verdict.pick}`;
    return `a reviewer scored it ${t.verdict.score} of 10${took}, and said: ${t.verdict.notes}`;
  }
  return "";
}

function logTry(c: Ctx, t: PortTry): void {
  const what = t.error ?? (t.why !== "" ? t.why : `${t.verdict?.pick} ${t.verdict?.score}${t.kept ? ", kept" : ""}`);
  console.log(`hoop: day ${c.day}, band ${c.band}, ${c.thing.id} try ${t.n} (${t.route}): ${what}`);
}

/**
 * The theme's thing for `band` as a model's map: HOOP_DRAWINGS drawings in
 * the style of the reference, each mapped up to MAP_ASKS times by the
 * reviewer model, and every map repaired, coloured, checked and judged; the
 * best the eye keeps wins. When none is kept the pixel reader on the last
 * drawing is one more try. `picture` is null when nothing was kept, and the
 * board cuts the day's bead picture as before; `port` records every try.
 * `keep` is handed each drawing (the dashboard's files).
 */
export async function makeHoop(day: number, theme: Theme, band: number, keep?: (name: string, d: Drawing) => void): Promise<{picture: HoopPicture | null; port: Port}> {
  const thing: Thing = theme.objects[Math.min(band + 1, theme.objects.length - 1)];
  const deadline = Date.now() + HOOP_BUDGET_MS;
  // keyFor never throws by design; caught all the same, so nothing before
  // the tries can lose the port
  let key: Key = "green", creature = false;
  try {
    ({key, creature} = await keyFor(thing));
  } catch (e) {
    console.error(`hoop: day ${day}, band ${band}, ${thing.id}: no key`, e);
  }
  const c: Ctx = {day, theme, thing, band, key, deadline, out: false};
  const port: Port = {game: "hoop", band, thing: thing.id, tries: []};
  const fresh = (route: PortTry["route"]): PortTry => {
    const t: PortTry = {n: port.tries.length, route, why: "", kept: false};
    port.tries.push(t);
    return t;
  };
  /** Whether the budget is spent; the first try it stops is recorded. */
  const late = (route: PortTry["route"]): boolean => {
    if (Date.now() <= deadline) return false;
    if (!c.out) {
      c.out = true;
      const t = fresh(route);
      t.why = "out of time";
      logTry(c, t);
    }
    return true;
  };
  let best: Best | null = null;
  let last: Drawing | null = null;
  for (let d = 0; d < HOOP_DRAWINGS && (best === null || best.score < ENOUGH); d++) {
    if (late("map")) break;
    let drawing: Drawing;
    try {
      drawing = await draw(PROMPT(thing.draw, band, key, creature), shapesModel(), {images: [styleRef()]});
    } catch (e) {
      const t = fresh("map");
      t.error = `draw: ${said(e)}`;
      logTry(c, t);
      continue;
    }
    last = drawing;
    try {
      keep?.(`${day}_hoop${band}_${thing.id}_${d}`, drawing);
    } catch (e) {
      console.error(`hoop: day ${day}, band ${band}, ${thing.id}: drawing ${d} not kept`, e);
    }
    let refused = "";
    for (let a = 0; a < MAP_ASKS && (best === null || best.score < ENOUGH); a++) {
      if (late("map")) break;
      const t = fresh("map");
      const got = await mapTry(c, drawing, refused, t);
      logTry(c, t);
      if (t.kept && got !== null && (best === null || got.score > best.score)) best = got;
      refused = lesson(t, thing);
    }
  }
  if (best === null && last !== null && !late("reader")) {
    const t = fresh("reader");
    const got = await readerTry(c, last, t);
    logTry(c, t);
    if (t.kept && got !== null) best = got;
  }
  if (best === null) return {picture: null, port};
  try {
    port.source = shrunk(best.drawing).bytes.toString("base64");
    port.render = shrunk({mime: "image/png", bytes: best.render}).bytes.toString("base64");
  } catch (e) {
    console.error(`hoop: day ${day}, band ${band}, ${thing.id}: the kept try not shrunk`, e);
  }
  console.log(`hoop: day ${day}, band ${band}, ${thing.id}: ${best.panels.length} panels, ${best.pins.length / 2} pins, score ${best.score}`);
  return {picture: {id: thing.id, name: {en: thing.name, pt: thing.pt, es: thing.es}, pins: best.pins, panels: best.panels}, port};
}

export {SIDE};
