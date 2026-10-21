import {draw, Drawing, shapesModel} from "./generate";
import {area, board, compact, dissolve, fewer, grow, join, network, raster, Raster, Regions, SIDE, split, touching, unring, unshadow} from "./facets";
import {keyFor, keyWords, Key} from "./key";
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
const TRIES = 2;

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

/** The theme's thing for `band` drawn and read, up to TRIES drawings; null
 *  when none will do, and the board cuts the day's bead picture as before.
 *  `keep` is handed each drawing (the dashboard's files). */
export async function makeHoop(day: number, theme: Theme, band: number, keep?: (name: string, d: Drawing) => void): Promise<HoopPicture | null> {
  const thing: Thing = theme.objects[Math.min(band + 1, theme.objects.length - 1)];
  const {key, creature} = await keyFor(thing);
  for (let n = 0; n < TRIES; n++) {
    try {
      const drawing = await draw(PROMPT(thing.draw, band, key, creature), shapesModel());
      keep?.(`${day}_hoop${band}_${thing.id}_${n}`, drawing);
      const got = readHoop(drawing, band);
      if (got.why !== "") {
        console.log(`hoop: day ${day}, band ${band}, ${thing.id} drawing ${n}: ${got.why}`);
        continue;
      }
      console.log(`hoop: day ${day}, band ${band}, ${thing.id}: ${got.panels.length} panels, ${got.pins.length / 2} pins`);
      return {id: thing.id, name: {en: thing.name, pt: thing.pt, es: thing.es}, pins: got.pins, panels: got.panels};
    } catch (e) {
      console.error(`hoop: day ${day}, band ${band}, ${thing.id}, drawing ${n} failed`, e);
    }
  }
  return null;
}

export {SIDE};
