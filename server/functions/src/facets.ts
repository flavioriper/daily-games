import type {Drawing} from "./generate";
import {decoded} from "./pictures";

/**
 * A drawing read as flat regions of colour, for the boards whose picture is
 * shapes rather than beads: Yarn Hoop's low-poly panels (hoop.ts) and
 * Gumdrop's jelly chunks (jelly.ts). The image model draws the thing in the
 * board's own style -- a low-poly illustration of flat facets, a sticker in
 * the six flavours -- and this reads the regions back out of it: the white
 * board round it taken away, the region grown a flat colour at a time, the
 * seams of soft pixels between two regions given to the nearer, and each
 * region's outline traced on the pixels' corners.
 *
 * The outlines are traced as one network: where three regions (or two and
 * the board) meet is a corner every one of them shares, and the run of
 * boundary between two such corners is simplified once, for both sides,
 * so two neighbours' outlines always meet exactly and a pin on one is a
 * pin on the other.
 */

/** Pixels a side the drawing is read at. */
export const SIDE = 256;

export interface Raster {
  n: number;
  /** r, g, b a pixel, 0-255, row by row. */
  rgb: Float32Array;
}

/** The drawing scaled to SIDE (each pixel the mean of the ones it covers),
 *  centred on white when it is not square. */
export function raster(d: Drawing, n = SIDE): Raster {
  const px = decoded(d);
  const rgb = new Float32Array(n * n * 3).fill(255);
  const scale = Math.max(px.width, px.height) / n;
  const ox = (n - px.width / scale) / 2, oy = (n - px.height / scale) / 2;
  const sum = new Float64Array(n * n * 4);
  const ch = px.data.length / (px.width * px.height);
  for (let y = 0; y < px.height; y++) {
    const ty = Math.floor(y / scale + oy);
    if (ty < 0 || ty >= n) continue;
    for (let x = 0; x < px.width; x++) {
      const tx = Math.floor(x / scale + ox);
      if (tx < 0 || tx >= n) continue;
      const i = (y * px.width + x) * ch, t = (ty * n + tx) * 4;
      sum[t] += px.data[i]; sum[t + 1] += px.data[i + 1]; sum[t + 2] += px.data[i + 2]; sum[t + 3] += 1;
    }
  }
  for (let i = 0; i < n * n; i++) {
    if (sum[i * 4 + 3] === 0) continue;
    for (let c = 0; c < 3; c++) rgb[i * 3 + c] = sum[i * 4 + c] / sum[i * 4 + 3];
  }
  return {n, rgb};
}

export function dist(a: ArrayLike<number>, ai: number, b: ArrayLike<number>, bi: number): number {
  const dr = a[ai] - b[bi], dg = a[ai + 1] - b[bi + 1], db = a[ai + 2] - b[bi + 2];
  return Math.sqrt(dr * dr + dg * dg + db * db);
}

const N4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];

/** The board Yarn Hoop's drawings are asked on: a green screen, since a
 *  low-poly thing may be white (a teapot's lit facets came at 250, the
 *  white board's own shade) and the image model paints "magenta" as a hot
 *  pink that eats a red thing's edge. Gumdrop's stickers stay on white:
 *  none of the six flavours is near it. */
export const KEY_WORDS = "a plain flat solid pure green-screen chroma key background (#00FF00) filling the whole picture edge to edge";
/** The board is flooded from the picture's edge: a pixel near the board's
 *  colour (the edge's median: the model's magenta is a hot pink, shaded)
 *  joins while it differs from the board pixel beside it by under STEP, so
 *  the flood follows a board's gentle shading and stops at the sharp edge
 *  of the thing, even a pink one. */
const KEY_NEAR = 110;
const STEP = 12;
const KEY_SEED = 45;

/** The board's colour: the median of the picture's edge. */
export function boardKey(r: Raster): number[] {
  const n = r.n;
  const edge: number[][] = [[], [], []];
  for (let k = 0; k < n; k++) {
    for (const i of [k, (n - 1) * n + k, k * n, k * n + n - 1]) for (let c = 0; c < 3; c++) edge[c].push(r.rgb[i * 3 + c]);
  }
  return edge.map((v) => v.sort((x, y) => x - y)[v.length >> 1]);
}

/** Regions of the board's own colour that touch it (the shadow a drawing
 *  casts on its green screen, a tray's corners) made board. */
export function unshadow(reg: Regions, r: Raster): Regions {
  const key = boardKey(r);
  const n = reg.n;
  const label = reg.label.slice();
  const touches = new Uint8Array(reg.size.length);
  for (let i = 0; i < n * n; i++) {
    const l = reg.label[i];
    if (l < 0) continue;
    const x = i % n, y = (i - x) / n;
    if (x === 0 || y === 0 || x === n - 1 || y === n - 1 || reg.label[i - 1] < 0 || reg.label[i + 1] < 0 ||
      reg.label[i - n] < 0 || reg.label[i + n] < 0) touches[l] = 1;
  }
  let gone = false;
  for (let l = 0; l < reg.size.length; l++) {
    if (!touches[l] || dist(reg.colour[l], 0, key, 0) >= SHADOW) continue;
    for (let i = 0; i < n * n; i++) if (label[i] === l) label[i] = -1;
    gone = true;
  }
  return gone ? split(compact(n, label, r)) : reg;
}
/** How near the board's colour a region is the board's shadow. */
const SHADOW = 80;

export function board(r: Raster): Uint8Array {
  const n = r.n;
  const bg = new Uint8Array(n * n);
  const key = boardKey(r);
  const near = (i: number, by: number) => dist(r.rgb, i * 3, key, 0) < by;
  const stack: number[] = [];
  for (let k = 0; k < n; k++) {
    for (const i of [k, (n - 1) * n + k, k * n, k * n + n - 1]) {
      if (!bg[i] && near(i, KEY_SEED)) { bg[i] = 1; stack.push(i); }
    }
  }
  while (stack.length > 0) {
    const i = stack.pop() as number;
    const x = i % n, y = (i - x) / n;
    for (const [dx, dy] of N4) {
      const px = x + dx, py = y + dy;
      if (px < 0 || py < 0 || px >= n || py >= n) continue;
      const j = py * n + px;
      if (!bg[j] && near(j, KEY_NEAR) && dist(r.rgb, j * 3, r.rgb, i * 3) < STEP) { bg[j] = 1; stack.push(j); }
    }
  }
  // the board seen through the thing (a mug's handle, the gap under an
  // arch): a patch of the board's colour the edge does not reach, big
  // enough not to be a highlight
  const pure = (i: number) => near(i, KEY_SEED);
  const seen = new Uint8Array(n * n);
  for (let i = 0; i < n * n; i++) {
    if (bg[i] || seen[i] || !pure(i)) continue;
    const patch = [i];
    seen[i] = 1;
    for (let q = 0; q < patch.length; q++) {
      const k = patch[q], x = k % n, y = (k - x) / n;
      for (const [dx, dy] of N4) {
        const px = x + dx, py = y + dy;
        if (px < 0 || py < 0 || px >= n || py >= n) continue;
        const j = py * n + px;
        if (!seen[j] && !bg[j] && pure(j)) { seen[j] = 1; patch.push(j); }
      }
    }
    if (patch.length >= HOLE) for (const k of patch) bg[k] = 1;
  }
  return bg;
}
/** A region under a band's floor is grown rather than joined when it holds
 *  this share of the floor and is this far in colour from every neighbour. */
const SALIENT_FROM = 0.2;
const SALIENT = 90;
/** Pixels of the board's colour inside a drawing taken for the board behind it. */
const HOLE = 150;

export interface Regions {
  n: number;
  /** Each pixel's region, -1 the board. */
  label: Int32Array;
  /** A region's mean colour, r g b. */
  colour: number[][];
  size: number[];
}

/** Regions renumbered 0.. in order, the empty ones gone, their colours and
 *  sizes counted again off `r`. */
export function compact(n: number, label: Int32Array, r: Raster | null, colour: number[][] = []): Regions {
  const map = new Map<number, number>();
  const out = new Int32Array(n * n).fill(-1);
  const sum: number[][] = [];
  for (let i = 0; i < n * n; i++) {
    const l = label[i];
    if (l < 0) continue;
    let k = map.get(l);
    if (k === undefined) {
      k = map.size;
      map.set(l, k);
      sum.push([0, 0, 0, 0, ...(colour[l] ?? [])]);
    }
    out[i] = k;
    if (r !== null) for (let c = 0; c < 3; c++) sum[k][c] += r.rgb[i * 3 + c];
    sum[k][3] += 1;
  }
  return {
    n, label: out,
    colour: sum.map((s) => r !== null ? [s[0] / s[3], s[1] / s[3], s[2] / s[3]] : s.slice(4, 7)),
    size: sum.map((s) => s[3]),
  };
}

/** 4-connected pieces of each label, a region each. */
export function split(reg: Regions): Regions {
  const n = reg.n;
  const out = new Int32Array(n * n).fill(-1);
  const colour: number[][] = [];
  let next = 0;
  for (let i = 0; i < n * n; i++) {
    if (reg.label[i] < 0 || out[i] >= 0) continue;
    const l = reg.label[i];
    out[i] = next;
    const stack = [i];
    while (stack.length > 0) {
      const k = stack.pop() as number;
      const x = k % n, y = (k - x) / n;
      for (const [dx, dy] of N4) {
        const px = x + dx, py = y + dy;
        if (px < 0 || py < 0 || px >= n || py >= n) continue;
        const j = py * n + px;
        if (out[j] < 0 && reg.label[j] === l) { out[j] = next; stack.push(j); }
      }
    }
    colour.push(reg.colour[l]);
    next++;
  }
  return compact(n, out, null, colour);
}

/** Flat regions grown off `r`: a pixel joins its neighbour's region while
 *  it is within `tol` of the colour the region started from. */
export function grow(r: Raster, bg: Uint8Array, tol: number): Regions {
  const n = r.n;
  const label = new Int32Array(n * n).fill(-1);
  let next = 0;
  for (let i = 0; i < n * n; i++) {
    if (bg[i] || label[i] >= 0) continue;
    label[i] = next;
    const stack = [i];
    while (stack.length > 0) {
      const k = stack.pop() as number;
      const x = k % n, y = (k - x) / n;
      for (const [dx, dy] of N4) {
        const px = x + dx, py = y + dy;
        if (px < 0 || py < 0 || px >= n || py >= n) continue;
        const j = py * n + px;
        if (label[j] < 0 && !bg[j] && dist(r.rgb, j * 3, r.rgb, i * 3) < tol) { label[j] = next; stack.push(j); }
      }
    }
    next++;
  }
  return compact(n, label, r);
}

/** Whether pixel `i` of region `l` has `depth` pixels of it every way. */
function deep(reg: Regions, i: number, depth: number): boolean {
  const n = reg.n, x = i % n, y = (i - x) / n, l = reg.label[i];
  for (let dy = -depth; dy <= depth; dy++) {
    for (let dx = -depth; dx <= depth; dx++) {
      const px = x + dx, py = y + dy;
      if (px < 0 || py < 0 || px >= n || py >= n || reg.label[py * n + px] !== l) return false;
    }
  }
  return true;
}

/**
 * The seams and specks dissolved: a region under `least` pixels, or one
 * with no pixel `depth` deep inside it (the soft pixels along an edge, a
 * hairline), is unpicked and its pixels given one ring at a time to the
 * neighbour nearest them in colour; a pixel the board alone touches goes
 * to the board when it is pale, else to the region that reaches it first.
 */
export function dissolve(reg: Regions, r: Raster, least: number, depth: number): Regions {
  const n = reg.n;
  const label = reg.label.slice();
  const keep = new Uint8Array(reg.size.length);
  for (let i = 0; i < n * n; i++) {
    const l = reg.label[i];
    if (l >= 0 && !keep[l] && reg.size[l] >= least && deep(reg, i, depth)) keep[l] = 1;
  }
  const open: number[] = [];
  for (let i = 0; i < n * n; i++) {
    if (label[i] >= 0 && !keep[label[i]]) { label[i] = -2; open.push(i); }
  }
  let left = open;
  while (left.length > 0) {
    const give: [number, number][] = [];
    const still: number[] = [];
    for (const i of left) {
      const x = i % n, y = (i - x) / n;
      let best = -2, bestD = Infinity;
      for (const [dx, dy] of N4) {
        const px = x + dx, py = y + dy;
        if (px < 0 || py < 0 || px >= n || py >= n) continue;
        const l = label[py * n + px];
        if (l < 0) continue;
        const d = dist(r.rgb, i * 3, reg.colour[l], 0);
        if (d < bestD) { bestD = d; best = l; }
      }
      if (best >= 0) give.push([i, best]);
      else still.push(i);
    }
    if (give.length === 0) {
      for (const i of still) label[i] = -1;
      break;
    }
    for (const [i, l] of give) label[i] = l;
    left = still;
  }
  return split(compact(n, label, r));
}

/** Each region's neighbours and the length of boundary they share. */
export function touching(reg: Regions): Map<number, number>[] {
  const n = reg.n;
  const out = reg.size.map(() => new Map<number, number>());
  for (let y = 0; y < n; y++) {
    for (let x = 0; x < n; x++) {
      const a = reg.label[y * n + x];
      if (a < 0) continue;
      for (const [dx, dy] of [[1, 0], [0, 1]]) {
        if (x + dx >= n || y + dy >= n) continue;
        const b = reg.label[(y + dy) * n + x + dx];
        if (b < 0 || b === a) continue;
        out[a].set(b, (out[a].get(b) ?? 0) + 1);
        out[b].set(a, (out[b].get(a) ?? 0) + 1);
      }
    }
  }
  return out;
}

/** Region `b` taken into region `a`. */
export function join(reg: Regions, a: number, b: number): void {
  for (let i = 0; i < reg.label.length; i++) if (reg.label[i] === b) reg.label[i] = a;
  const s = reg.size[a] + reg.size[b];
  reg.colour[a] = reg.colour[a].map((v, c) => (v * reg.size[a] + reg.colour[b][c] * reg.size[b]) / s);
  reg.size[a] = s;
  reg.size[b] = 0;
}

/** Neighbours of near colour joined, the nearest pair first (a small one
 *  is drawn to its neighbours sooner), until `most` regions are left. */
export function fewer(reg: Regions, r: Raster, most: number, floor = 0, keepColours = false): Regions {
  let live = reg.size.filter((s) => s > 0).length;
  // a small region that stands out from everything round it (a seed, an
  // eye, a spot) is what the picture is read by: grown a ring at a time
  // into its neighbours until it holds `floor`, rather than lost
  if (floor > 0) {
    const n = reg.n;
    const near = touching(reg);
    for (let a = 0; a < reg.size.length; a++) {
      if (reg.size[a] === 0 || reg.size[a] >= floor || reg.size[a] < floor * SALIENT_FROM) continue;
      let closest = Infinity;
      for (const [b] of near[a]) closest = Math.min(closest, dist(reg.colour[a], 0, reg.colour[b], 0));
      if (closest < SALIENT || !Number.isFinite(closest)) continue;
      for (let ring = 0; ring < 8 && reg.size[a] < floor; ring++) {
        const take: number[] = [];
        for (let i = 0; i < n * n; i++) {
          const l = reg.label[i];
          if (l < 0 || l === a) continue;
          const x = i % n, y = (i - x) / n;
          if ((x > 0 && reg.label[i - 1] === a) || (x < n - 1 && reg.label[i + 1] === a) ||
            (y > 0 && reg.label[i - n] === a) || (y < n - 1 && reg.label[i + n] === a)) take.push(i);
        }
        for (const i of take) {
          reg.size[reg.label[i]]--;
          reg.label[i] = a;
          reg.size[a]++;
        }
      }
    }
  }
  // then every region still under `floor` pixels, the smallest first, into
  // the neighbour it is nearest in colour along the most shared boundary
  for (;;) {
    let small = -1;
    for (let a = 0; a < reg.size.length; a++) {
      if (reg.size[a] > 0 && reg.size[a] < floor && (small < 0 || reg.size[a] < reg.size[small])) small = a;
    }
    if (small < 0) break;
    const near = touching(reg)[small];
    let to = -1, toCost = Infinity;
    for (const [b, shared] of near) {
      if (reg.size[b] === 0) continue;
      const cost = (dist(reg.colour[small], 0, reg.colour[b], 0) + 8) / Math.sqrt(shared);
      if (cost < toCost) { toCost = cost; to = b; }
    }
    if (to < 0) {
      // alone on the board: let go
      for (let i = 0; i < reg.label.length; i++) if (reg.label[i] === small) reg.label[i] = -1;
      reg.size[small] = 0;
    } else {
      const keepColour = reg.colour[to];
      join(reg, to, small);
      reg.colour[to] = keepColour;
    }
    live--;
  }
  while (live > most) {
    const near = touching(reg);
    let best: [number, number] = [-1, -1];
    let bestCost = Infinity;
    for (let a = 0; a < near.length; a++) {
      if (reg.size[a] === 0) continue;
      for (const [b, shared] of near[a]) {
        if (b <= a || reg.size[b] === 0) continue;
        const small = Math.min(reg.size[a], reg.size[b]);
        const d = dist(reg.colour[a], 0, reg.colour[b], 0);
        // what stands out is joined last
        const cost = d * (d > SALIENT ? 4 : 1) * Math.sqrt(small) / Math.sqrt(shared);
        if (cost < bestCost) { bestCost = cost; best = [a, b]; }
      }
    }
    if (best[0] < 0) break;
    const [a, b] = reg.size[best[0]] >= reg.size[best[1]] ? best : [best[1], best[0]];
    const kept = reg.colour[a];
    join(reg, a, b);
    if (keepColours) reg.colour[a] = kept;
    live--;
  }
  return keepColours ? split(compact(reg.n, reg.label, null, reg.colour)) : split(compact(reg.n, reg.label, r));
}

/**
 * A region that rings another (an eye's white round its pupil) cut in two
 * through the middle of what it holds, a straight line down, so every
 * region is an outline with nothing inside it but itself: a panel and a
 * chunk are both one outline.
 */
export function unring(reg: Regions, r: Raster | null): Regions {
  const n = reg.n;
  for (let pass = 0; pass < 6; pass++) {
    let cut = false;
    const label = reg.label.slice();
    let next = reg.size.length;
    const colour = reg.colour.slice();
    for (let l = 0; l < reg.size.length; l++) {
      let x0 = n, y0 = n, x1 = -1, y1 = -1;
      for (let i = 0; i < n * n; i++) {
        if (reg.label[i] !== l) continue;
        const x = i % n, y = (i - x) / n;
        x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y);
      }
      if (x1 < 0) continue;
      // what of the box is not the region and cannot reach the box's edge
      const w = x1 - x0 + 3, h = y1 - y0 + 3;
      const out = new Uint8Array(w * h);
      const stack = [0];
      out[0] = 1;
      while (stack.length > 0) {
        const k = stack.pop() as number;
        const x = k % w, y = (k - x) / w;
        for (const [dx, dy] of N4) {
          const px = x + dx, py = y + dy;
          if (px < 0 || py < 0 || px >= w || py >= h) continue;
          const j = py * w + px;
          if (out[j]) continue;
          const gx = px + x0 - 1, gy = py + y0 - 1;
          const mine = gx >= 0 && gy >= 0 && gx < n && gy < n && reg.label[gy * n + gx] === l;
          if (!mine) { out[j] = 1; stack.push(j); }
        }
      }
      let sx = 0, sc = 0;
      for (let y = 1; y < h - 1; y++) {
        for (let x = 1; x < w - 1; x++) {
          const gx = x + x0 - 1, gy = y + y0 - 1;
          if (!out[y * w + x] && reg.label[gy * n + gx] !== l) { sx += gx; sc++; }
        }
      }
      if (sc === 0) continue;
      const mid = Math.round(sx / sc);
      for (let i = 0; i < n * n; i++) {
        if (reg.label[i] === l && i % n >= mid) label[i] = next;
      }
      colour.push(reg.colour[l]);
      next++;
      cut = true;
    }
    if (!cut) break;
    reg = split(compact(n, label, r, colour));
  }
  return reg;
}

// --- the outlines ---

/** Each region's outline as points in pixels, the region on the left,
 *  every corner of it (nothing simplified). */
export function outlines(reg: Regions): number[][][] {
  const m = reg.n + 1;
  const out: number[][][] = reg.size.map(() => []);
  const seen = new Uint8Array(reg.size.length);
  for (let i = 0; i < reg.n * reg.n; i++) {
    const l = reg.label[i];
    if (l < 0 || seen[l]) continue;
    seen[l] = 1;
    out[l] = walk(reg, l, i).map((c) => [c % m, (c - (c % m)) / m]);
  }
  return out;
}

/** A corner of the pixels, x + y * (n + 1). */
type Corner = number;

export interface Network {
  n: number;
  /** The corners kept as points of the outlines. */
  kept: Set<Corner>;
  /** Each region's outline, its corners in order, the region on the left. */
  loops: Corner[][];
}

function lab(reg: Regions, x: number, y: number): number {
  return x < 0 || y < 0 || x >= reg.n || y >= reg.n ? -1 : reg.label[y * reg.n + x];
}

/** A region's outline walked on the corners, the region on the left. */
function walk(reg: Regions, l: number, start: number): Corner[] {
  const n = reg.n, m = n + 1;
  const sx = start % n, sy = (start - sx) / n;
  // along the top edge of the region's first pixel, leftward
  let cx = sx + 1, cy = sy, dx = -1, dy = 0;
  const out: Corner[] = [];
  const first = [cx, cy, dx, dy];
  for (let step = 0; step < 4 * n * n; step++) {
    out.push(cx + cy * m);
    cx += dx; cy += dy;
    const lx = dy, ly = -dx;
    const aheadL = lab(reg, Math.floor(cx + 0.5 * dx + 0.5 * lx), Math.floor(cy + 0.5 * dy + 0.5 * ly)) === l;
    const aheadR = lab(reg, Math.floor(cx + 0.5 * dx - 0.5 * lx), Math.floor(cy + 0.5 * dy - 0.5 * ly)) === l;
    if (!aheadL) { [dx, dy] = [lx, ly]; } else if (aheadR) { [dx, dy] = [-lx, -ly]; }
    if (cx === first[0] && cy === first[1] && dx === first[2] && dy === first[3]) break;
  }
  return out;
}

function perp(p: number[], a: number[], b: number[]): number {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  const len = Math.hypot(dx, dy);
  if (len === 0) return Math.hypot(p[0] - a[0], p[1] - a[1]);
  return Math.abs(dy * p[0] - dx * p[1] + b[0] * a[1] - b[1] * a[0]) / len;
}

/** Douglas-Peucker: the points of `pts` kept to `tol`, ends always. */
export function simplify(pts: number[][], tol: number): boolean[] {
  const keep = pts.map(() => false);
  if (pts.length === 0) return keep;
  keep[0] = keep[pts.length - 1] = true;
  const stack: [number, number][] = [[0, pts.length - 1]];
  while (stack.length > 0) {
    const [a, b] = stack.pop() as [number, number];
    let far = -1, farD = tol;
    for (let i = a + 1; i < b; i++) {
      const d = perp(pts[i], pts[a], pts[b]);
      if (d > farD) { farD = d; far = i; }
    }
    if (far >= 0) {
      keep[far] = true;
      stack.push([a, far], [far, b]);
    }
  }
  return keep;
}

/**
 * The outlines of every region as one network, simplified to `tol` pixels:
 * a corner where three labels meet (the board counts as one) is always a
 * point, and each run of boundary between two such corners is simplified
 * once, so the two regions either side of it keep the same points.
 */
export function network(reg: Regions, tol: number): Network {
  const n = reg.n, m = n + 1;
  const xy = (c: Corner) => [c % m, (c - (c % m)) / m];
  const labels = (c: Corner) => {
    const [x, y] = xy(c);
    return [lab(reg, x - 1, y - 1), lab(reg, x, y - 1), lab(reg, x - 1, y), lab(reg, x, y)];
  };
  const node = (c: Corner) => {
    const [tl, tr, bl, br] = labels(c);
    const kinds = new Set([tl, tr, bl, br]).size;
    return kinds >= 3 || (kinds === 2 && tl === br && tr === bl);
  };
  const loops: Corner[][] = [];
  const seen = new Uint8Array(reg.size.length);
  for (let i = 0; i < n * n; i++) {
    const l = reg.label[i];
    if (l < 0 || seen[l]) continue;
    seen[l] = 1;
    loops.push(walk(reg, l, i));
  }
  // the runs between nodes, each simplified once whichever loop meets it
  const kept = new Set<Corner>();
  const done = new Set<string>();
  for (const loop of loops) {
    const at = loop.map(node);
    let starts = at.map((v, i) => (v ? i : -1)).filter((i) => i >= 0);
    if (starts.length === 0) {
      // an outline no other region's corner breaks: its first corner and
      // the corner farthest from it stand for the nodes
      const [x0, y0] = xy(loop[0]);
      let far = 0, farD = -1;
      loop.forEach((c, i) => {
        const [x, y] = xy(c);
        const d = Math.hypot(x - x0, y - y0);
        if (d > farD) { farD = d; far = i; }
      });
      kept.add(loop[0]);
      kept.add(loop[far]);
      starts = [0, far];
    }
    for (const s of starts) kept.add(loop[s]);
    for (let k = 0; k < starts.length; k++) {
      const a = starts[k], b = starts[(k + 1) % starts.length];
      const run: Corner[] = [];
      for (let i = a; ; i = (i + 1) % loop.length) {
        run.push(loop[i]);
        if (i === b && run.length > 1) break;
      }
      const key = run[0] < run[run.length - 1] ? `${run[0]},${run[1]},${run[run.length - 1]}` : `${run[run.length - 1]},${run[run.length - 2]},${run[0]}`;
      if (done.has(key)) continue;
      done.add(key);
      const forward = run[0] < run[run.length - 1] || (run[0] === run[run.length - 1] && run[1] < run[run.length - 2]);
      const ordered = forward ? run : run.slice().reverse();
      const keep = simplify(ordered.map(xy), tol);
      ordered.forEach((c, i) => { if (keep[i]) kept.add(c); });
    }
  }
  return {n, kept, loops};
}

/** A polygon's signed area, y down: positive clockwise on screen. */
export function area(p: number[][]): number {
  let a = 0;
  for (let i = 0; i < p.length; i++) {
    const q = p[(i + 1) % p.length];
    a += p[i][0] * q[1] - q[0] * p[i][1];
  }
  return a / 2;
}
