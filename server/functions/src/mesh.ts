import {Raster} from "./facets";
import {scan} from "./eye";
import {BANDS, convex, ears, HoopPanel, LEAST_PANELS, MOST_CORNERS, overlaps, regroup} from "./hoop";

/**
 * A vision model's Yarn Hoop map made into a mesh the phone accepts. The
 * model reads the pins and panels off a drawing with a numbered grid over
 * it, and its answer is near but never exact: two pins a hair apart that
 * are one corner, a panel's corner lying in the middle of its neighbour's
 * side, a panel bent inward, an id it never gave. Each of those is mended
 * here in turn, and what could not be mended is said in `why` with the
 * words readHoop uses, so the night treats a model's map as it treats one
 * read off the pixels.
 */

/** The model's answer: pins in grid units, panels as lists of pin ids. */
export interface ModelMap {
  pins: {id: number; x: number; y: number}[];
  panels: {pins: number[]; colour: string}[];
}

export interface Mesh {
  /** x and y in turn, in the square of 100 the thing is centred in. */
  pins: number[];
  panels: HoopPanel[];
  /** The image's 0-100 to that square: square = (image - x0) * s, and the
   *  same in y (the centring folded into x0 and y0). */
  box: {x0: number; y0: number; s: number};
  stats: {asked: number; kept: number; snapped: number; dropped: number; tees: number; clipped: number};
  why: string;
}

type P = number[];
type Stats = Mesh["stats"];

/** The mesh while it is mended: pins in the image's 0-100. */
interface Work {
  pins: P[];
  panels: {k: number[]; c: string}[];
}

/** Twice the signed area: positive when clockwise on screen (y down). */
function area2(poly: P[]): number {
  let a = 0;
  for (let i = 0; i < poly.length; i++) {
    const q = poly[(i + 1) % poly.length];
    a += poly[i][0] * q[1] - q[0] * poly[i][1];
  }
  return a;
}

/** A list of pins with a repeated one taken out where it comes again, and
 *  a last one that closes back on the first let go. */
function fold(k: number[]): number[] {
  const out: number[] = [];
  for (const i of k) if (!out.includes(i)) out.push(i);
  return out;
}

/** The grid read into the image's 0-100, and pins within a third of a
 *  square of one another made one: the model names the same corner twice
 *  where two panels meet. The first pin given an id keeps it. */
function snap(got: ModelMap, n: number, stats: Stats): {pins: P[]; of: Map<number, number>} {
  const near = 0.35 * 100 / n;
  const pins: P[] = [];
  const of = new Map<number, number>();
  for (const p of got.pins) {
    const id = Number(p.id);
    if (of.has(id)) { stats.dropped++; continue; }
    const x = Number(p.x) / n * 100, y = Number(p.y) / n * 100;
    let k = pins.findIndex((q) => Math.hypot(q[0] - x, q[1] - y) < near);
    if (k < 0) { k = pins.length; pins.push([x, y]); } else stats.snapped++;
    of.set(id, k);
  }
  return {pins, of};
}

/** The panels on the snapped pins: an id the model never gave let go, a
 *  pin listed twice folded, a panel left under 3 corners (or with no room
 *  inside) dropped, and every panel turned clockwise on screen, which the
 *  checks and the ear clipping take for granted. */
function drop(got: ModelMap, pins: P[], of: Map<number, number>, stats: Stats): Work {
  const panels: Work["panels"] = [];
  for (const pa of got.panels) {
    const k: number[] = [];
    for (const id of pa.pins) {
      const i = of.get(Number(id));
      if (i === undefined) stats.dropped++;
      else k.push(i);
    }
    const ids = fold(k);
    const a = area2(ids.map((i) => pins[i]));
    if (ids.length < 3 || Math.abs(a) < 1e-6) { stats.dropped++; continue; }
    panels.push({k: a > 0 ? ids : ids.reverse(), c: String(pa.colour)});
  }
  return {pins, panels};
}

/** How far along a-b the point lies, 0 to 1, when it lies on the side
 *  (within `tol`, and between 2% and 98% along it); -1 when not. */
function along(pt: P, a: P, b: P, tol: number): number {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  const len2 = dx * dx + dy * dy;
  if (len2 === 0) return -1;
  const t = ((pt[0] - a[0]) * dx + (pt[1] - a[1]) * dy) / len2;
  if (t <= 0.02 || t >= 0.98) return -1;
  const d = Math.abs(dx * (pt[1] - a[1]) - dy * (pt[0] - a[0])) / Math.sqrt(len2);
  return d < tol ? t : -1;
}

/** A pin lying on another panel's side made a corner of that side: where
 *  two small panels meet a big one the model leaves the big one's side
 *  whole, and the phone sees a pin dropped in the middle of a string. Every
 *  pin on one side goes in, in order along it. */
function tees(w: Work, stats: Stats): void {
  const used = new Set<number>();
  for (const p of w.panels) for (const i of p.k) used.add(i);
  const inserted = new Set<number>();
  for (const p of w.panels) {
    const k: number[] = [];
    for (let s = 0; s < p.k.length; s++) {
      const a = p.k[s], b = p.k[(s + 1) % p.k.length];
      k.push(a);
      const on: [number, number][] = [];
      for (const i of used) {
        if (p.k.includes(i)) continue;
        const t = along(w.pins[i], w.pins[a], w.pins[b], 0.3);
        if (t >= 0) on.push([t, i]);
      }
      on.sort((x, y) => x[0] - y[0]);
      for (const [, i] of on) { k.push(i); inserted.add(i); }
    }
    p.k = k;
  }
  stats.tees += inserted.size;
}

/** Two corners of one side nearer than a finger's width made one, the
 *  nearest first. The pin more panels meet at stays where it is, and before
 *  that one on the thing's outline (moved, it would drag every side on it
 *  across its neighbours), as readHoop's weld does. A weld that would leave
 *  a panel under 3 corners, or turn one inside out, is not made. */
function weld(w: Work, least: number, stats: Stats): void {
  const refused = new Set<string>();
  for (;;) {
    const meets = w.pins.map(() => 0);
    const sides = new Map<string, number>();
    for (const p of w.panels) {
      for (let s = 0; s < p.k.length; s++) {
        const a = p.k[s], b = p.k[(s + 1) % p.k.length];
        meets[a]++;
        const key = a < b ? `${a},${b}` : `${b},${a}`;
        sides.set(key, (sides.get(key) ?? 0) + 1);
      }
    }
    for (const [key, uses] of sides) if (uses === 1) for (const i of key.split(",")) meets[Number(i)] += 1000;
    let best: [number, number, number] | null = null;
    for (const key of sides.keys()) {
      if (refused.has(key)) continue;
      const [a, b] = key.split(",").map(Number);
      const d = Math.hypot(w.pins[a][0] - w.pins[b][0], w.pins[a][1] - w.pins[b][1]);
      if (d < least && (best === null || d < best[0])) best = [d, a, b];
    }
    if (best === null) return;
    const [, a, b] = best;
    const [keep, gone] = meets[a] > meets[b] || (meets[a] === meets[b] && a < b) ? [a, b] : [b, a];
    const next = w.panels.map((p) => fold(p.k.map((i) => (i === gone ? keep : i))));
    if (next.some((k) => k.length < 3 || area2(k.map((i) => w.pins[i])) <= 1e-6)) {
      refused.add(a < b ? `${a},${b}` : `${b},${a}`);
      continue;
    }
    w.panels.forEach((p, i) => { p.k = next[i]; });
    stats.snapped++;
  }
}

/** A panel bent inward, or of more than MOST_CORNERS, cut along its own
 *  corners into ears and joined back into convex pieces of 3 to 7, each
 *  keeping the panel's colour. One the ears will not take is dropped. */
function clip(w: Work, stats: Stats): void {
  const out: Work["panels"] = [];
  for (const p of w.panels) {
    if (p.k.length <= MOST_CORNERS && convex(p.k.map((i) => w.pins[i]))) { out.push(p); continue; }
    const cut = ears(p.k, w.pins);
    if (cut.length === 0) { stats.dropped++; continue; }
    stats.clipped++;
    for (const k of regroup(cut, w.pins)) out.push({k, c: p.c});
  }
  w.panels = out;
}

/** A panel laid over its neighbours let go: the model sometimes gives a
 *  patch both ways, a quad as two triangles and again across the other
 *  diagonal, and three panels then share a side, two of them on the same
 *  side of it. The panel on the most such sides goes first (the smaller of
 *  two that tie), until no side has three; the panels it lay over still
 *  cover its ground. */
function unstack(w: Work, stats: Stats): void {
  for (;;) {
    const users = new Map<string, number[]>();
    w.panels.forEach((p, j) => {
      for (let s = 0; s < p.k.length; s++) {
        const a = p.k[s], b = p.k[(s + 1) % p.k.length];
        const key = a < b ? `${a},${b}` : `${b},${a}`;
        users.set(key, [...(users.get(key) ?? []), j]);
      }
    });
    const stacked = w.panels.map(() => 0);
    for (const js of users.values()) if (js.length > 2) for (const j of js) stacked[j]++;
    let worst = -1;
    const size = (j: number) => area2(w.panels[j].k.map((i) => w.pins[i]));
    for (let j = 0; j < stacked.length; j++) {
      if (stacked[j] === 0) continue;
      if (worst < 0 || stacked[j] > stacked[worst] || (stacked[j] === stacked[worst] && size(j) < size(worst))) worst = j;
    }
    if (worst < 0) return;
    w.panels.splice(worst, 1);
    stats.dropped++;
  }
}

/** Only the pins a panel uses, numbered in the order the panels use them. */
function renumber(w: Work): void {
  const to = new Map<number, number>();
  const pins: P[] = [];
  for (const p of w.panels) {
    p.k = p.k.map((i) => {
      if (!to.has(i)) { to.set(i, pins.length); pins.push(w.pins[i]); }
      return to.get(i)!;
    });
  }
  w.pins = pins;
}

/** What the phone would refuse, the first of: a pin inside a panel it is
 *  not a corner of, a side three panels share, too few panels, too many;
 *  "" when none. */
function check(w: Work, band: number): string {
  const inside = overlaps(w.pins, w.panels) as number;
  if (inside > 0) return `${inside} pins inside another panel`;
  const sides = new Map<string, number>();
  for (const p of w.panels) {
    for (let s = 0; s < p.k.length; s++) {
      const a = p.k[s], b = p.k[(s + 1) % p.k.length];
      const key = a < b ? `${a},${b}` : `${b},${a}`;
      const uses = (sides.get(key) ?? 0) + 1;
      if (uses > 2) return "a side three panels share";
      sides.set(key, uses);
    }
  }
  const count = w.panels.length;
  if (count < LEAST_PANELS[band]) return `${count} panels, under ${LEAST_PANELS[band]}`;
  if (count > BANDS[band].most) return `${count} panels, over ${BANDS[band].most}`;
  return "";
}

/** Into the square of 100, the thing's box scaled to fill it and centred
 *  across, as readHoop lays a picture. */
function place(w: Work): {pins: number[]; box: Mesh["box"]} {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const [x, y] of w.pins) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const s = 100 / Math.max(x1 - x0, y1 - y0);
  const box = {x0: x0 - (100 - (x1 - x0) * s) / 2 / s, y0: y0 - (100 - (y1 - y0) * s) / 2 / s, s};
  const pins: number[] = [];
  for (const [x, y] of w.pins) pins.push(Math.round((x - box.x0) * s * 100) / 100, Math.round((y - box.y0) * s * 100) / 100);
  return {pins, box};
}

/** The model's map for an `n` grid made into a band's mesh, mended in turn
 *  and checked as readHoop checks its own. */
export function repairMesh(got: ModelMap, n: number, band: number): Mesh {
  const stats: Stats = {asked: got.panels.length, kept: 0, snapped: 0, dropped: 0, tees: 0, clipped: 0};
  const {pins, of} = snap(got, n, stats);
  const w = drop(got, pins, of, stats);
  tees(w, stats);
  weld(w, BANDS[band].least * 100 / 256, stats);
  unstack(w, stats);
  clip(w, stats);
  renumber(w);
  const why = check(w, band);
  stats.kept = w.panels.length;
  const placed = place(w);
  return {pins: placed.pins, panels: w.panels, box: placed.box, stats, why};
}

const rgbOf = (hex: string): number[] => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));

/**
 * Each panel coloured with the drawing's mean over it (the model's hex is
 * a guess; the drawing is the truth), read off the raster through the box.
 * A panel that comes out within 60 of the key colour is the background the
 * model took for part of the thing, and is dropped with any pin only it
 * used. Returns how many were dropped. `why` is left as repairMesh found
 * it: the caller has the band to check again.
 */
export function colourFrom(r: Raster, mesh: Mesh, key: string): number {
  const bg = rgbOf(key);
  const px = r.n / 100;
  const kept: HoopPanel[] = [];
  for (const p of mesh.panels) {
    const pts = p.k.map((i) => [(mesh.pins[2 * i] / mesh.box.s + mesh.box.x0) * px, (mesh.pins[2 * i + 1] / mesh.box.s + mesh.box.y0) * px]);
    const sum = [0, 0, 0];
    let count = 0;
    scan(pts, r.n, (x, y) => {
      const at = (y * r.n + x) * 3;
      for (let c = 0; c < 3; c++) sum[c] += r.rgb[at + c];
      count++;
    });
    if (count > 0) {
      const mean = sum.map((v) => v / count);
      if (Math.hypot(mean[0] - bg[0], mean[1] - bg[1], mean[2] - bg[2]) <= 60) continue;
      p.c = "#" + mean.map((v) => Math.round(v).toString(16).padStart(2, "0")).join("");
    }
    kept.push(p);
  }
  const dropped = mesh.panels.length - kept.length;
  const w: Work = {pins: [], panels: kept};
  for (let i = 0; i < mesh.pins.length; i += 2) w.pins.push([mesh.pins[i], mesh.pins[i + 1]]);
  renumber(w);
  mesh.pins = w.pins.flat();
  mesh.panels = kept;
  mesh.stats.kept = kept.length;
  return dropped;
}
