import {boardKey, Raster} from "./facets";
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
 *  where two panels meet. The first pin given an id keeps it; a pin
 *  without a number for x or y is let go, and its id is then unknown. */
function snap(got: ModelMap, n: number, stats: Stats): {pins: P[]; of: Map<number, number>} {
  const near = 0.35 * 100 / n;
  const pins: P[] = [];
  const of = new Map<number, number>();
  for (const p of got.pins) {
    const id = Number(p.id);
    if (of.has(id)) { stats.dropped++; continue; }
    const x = Number(p.x) / n * 100, y = Number(p.y) / n * 100;
    if (!Number.isFinite(x) || !Number.isFinite(y)) { stats.dropped++; continue; }
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
 *  pin on one side goes in, in order along it, and never twice into one
 *  panel (a pin by two sides of a thin panel goes in by the first). */
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
        if (p.k.includes(i) || k.includes(i)) continue;
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

/** What the phone would refuse, the first of: a panel outside 3 to
 *  MOST_CORNERS corners, a pin twice in one panel, a pin inside a panel it
 *  is not a corner of, a side three panels share, too few panels, too many;
 *  "" when none. Checked here rather than trusted to the steps above. */
function check(w: Work, band: number): string {
  for (const p of w.panels) {
    if (p.k.length < 3 || p.k.length > MOST_CORNERS) return `a panel of ${p.k.length} corners`;
    if (new Set(p.k).size < p.k.length) return "a pin twice in one panel";
  }
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

/** The same checks on a placed mesh, again after colourFrom has dropped
 *  the background. "Pins inside" works on the square as on the image: its
 *  room of 0.05 is a cross product, a hair at either scale. */
export function checkMesh(mesh: Mesh, band: number): string {
  const pins: P[] = [];
  for (let i = 0; i < mesh.pins.length; i += 2) pins.push([mesh.pins[i], mesh.pins[i + 1]]);
  return check({pins, panels: mesh.panels}, band);
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
const onBoard = (a: number[], b: number[]) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]) <= 60;

/** A colour's hue in degrees and its chroma (max less min, 0..255). */
function hueOf(r: number, g: number, b: number): {hue: number; chroma: number} {
  const hi = Math.max(r, g, b), chroma = hi - Math.min(r, g, b);
  if (chroma === 0) return {hue: 0, chroma};
  const h = hi === r ? ((g - b) / chroma + 6) % 6 : hi === g ? (b - r) / chroma + 2 : (r - g) / chroma + 4;
  return {hue: h * 60, chroma};
}
/** A pixel this near a board's hue, and this coloured, is the key: the
 *  board itself, or a thin part's edge blended into it (the kettle's
 *  handle, 2026-10-21: a dark grey edged in sage read as green). The
 *  window is tight, since cyan is under 30 degrees from a blue thing; the
 *  floor is chroma, not saturation, so a near-black edge is never taken. */
const KEY_HUE = 25;
const KEY_CHROMA = 12;

/**
 * Each panel coloured with the drawing's mean over it (the model's hex is
 * a guess; the drawing is the truth), read off the raster through the box,
 * leaving out every pixel of the key's hue (isKey), so a thin part mapped
 * a little wider than it is keeps its own colour, not one tinted by the
 * board round it. A panel over nothing but the key, or whose mean comes
 * out within 60 of the board, is the background the
 * model took for part of the thing, and is dropped with any pin only it
 * used, and what is left placed in the square again. The board is measured
 * twice: as the drawing painted it, the median of the raster's edge (the
 * reader's boardKey: flash paints the key muted, a sage for green, a shaded
 * pink for magenta, far more than 60 from the pure hex), and as the key's
 * own hex. A panel too thin to cover any pixel's centre takes the mean of
 * the measured neighbours it shares a side with, and with none the pixel
 * under its middle, so it never keeps the model's string (which may be no
 * colour at all, and the phone drops a band with one bad colour). Returns
 * how many were dropped. `why` is left as repairMesh found it: the caller
 * has the band, and checks again with checkMesh.
 */
export function colourFrom(r: Raster, mesh: Mesh, key: string): number {
  const boards = [boardKey(r), rgbOf(key)];
  const hues = boards.map((b) => hueOf(b[0], b[1], b[2])).filter((h) => h.chroma >= KEY_CHROMA).map((h) => h.hue);
  const isKey = (at: number) => {
    const {hue, chroma} = hueOf(r.rgb[at], r.rgb[at + 1], r.rgb[at + 2]);
    return chroma >= KEY_CHROMA && hues.some((h) => Math.min(Math.abs(hue - h), 360 - Math.abs(hue - h)) <= KEY_HUE);
  };
  const px = r.n / 100;
  const pixelsOf = (p: HoopPanel) => p.k.map((i) => [(mesh.pins[2 * i] / mesh.box.s + mesh.box.x0) * px, (mesh.pins[2 * i + 1] / mesh.box.s + mesh.box.y0) * px]);
  const means: (number[] | null)[] = mesh.panels.map((p) => {
    const sum = [0, 0, 0];
    let count = 0, covered = 0;
    scan(pixelsOf(p), r.n, (x, y) => {
      const at = (y * r.n + x) * 3;
      covered++;
      if (isKey(at)) return;
      for (let c = 0; c < 3; c++) sum[c] += r.rgb[at + c];
      count++;
    });
    // a panel over nothing but the key is the board, and is dropped below
    if (covered > 0 && count === 0) return boards[0];
    return count > 0 ? sum.map((v) => v / count) : null;
  });
  // the thin ones from their neighbours' measures, never from another thin
  // one's borrowed colour, so the order they come in changes nothing
  const bySide = new Map<string, number[]>();
  mesh.panels.forEach((p, j) => {
    for (let s = 0; s < p.k.length; s++) {
      const a = p.k[s], b = p.k[(s + 1) % p.k.length];
      const side = a < b ? `${a},${b}` : `${b},${a}`;
      bySide.set(side, [...(bySide.get(side) ?? []), j]);
    }
  });
  const colours = mesh.panels.map((p, j) => {
    if (means[j] !== null) return means[j]!;
    const sum = [0, 0, 0];
    let count = 0;
    for (let s = 0; s < p.k.length; s++) {
      const a = p.k[s], b = p.k[(s + 1) % p.k.length];
      for (const o of bySide.get(a < b ? `${a},${b}` : `${b},${a}`) ?? []) {
        const m = means[o];
        if (o === j || m === null || boards.some((bg) => onBoard(m, bg))) continue;
        for (let c = 0; c < 3; c++) sum[c] += m[c];
        count++;
      }
    }
    if (count > 0) return sum.map((v) => v / count);
    const pts = pixelsOf(p);
    const at = (v: number) => Math.max(0, Math.min(r.n - 1, Math.floor(v / pts.length)));
    const x = at(pts.reduce((t, q) => t + q[0], 0)), y = at(pts.reduce((t, q) => t + q[1], 0));
    return [0, 1, 2].map((c) => r.rgb[(y * r.n + x) * 3 + c]);
  });
  const kept: HoopPanel[] = [];
  mesh.panels.forEach((p, j) => {
    const mean = colours[j];
    if (boards.some((bg) => onBoard(mean, bg))) return;
    p.c = "#" + mean.map((v) => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0")).join("");
    kept.push(p);
  });
  const dropped = mesh.panels.length - kept.length;
  const w: Work = {pins: [], panels: kept};
  for (let i = 0; i < mesh.pins.length; i += 2) w.pins.push([mesh.pins[i], mesh.pins[i + 1]]);
  renumber(w);
  if (dropped > 0 && w.pins.length > 0) {
    // placed again, so a background panel dropped at the border leaves the
    // thing centred and filling the square, not shifted and shrunk
    for (const q of w.pins) { q[0] = q[0] / mesh.box.s + mesh.box.x0; q[1] = q[1] / mesh.box.s + mesh.box.y0; }
    const placed = place(w);
    mesh.pins = placed.pins;
    mesh.box = placed.box;
  } else {
    mesh.pins = w.pins.flat();
  }
  mesh.panels = kept;
  mesh.stats.kept = kept.length;
  return dropped;
}
