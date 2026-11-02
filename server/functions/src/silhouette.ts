import earcut = require("earcut");
import {PNG} from "pngjs";

/**
 * A silhouette picture to How Big?'s shape data, in the format of
 * content/how_big_shapes.json (tools/build_how_big.py writes the bundled
 * thirty): {w, h, loops, tris}, the larger side of the box 1000, the box's
 * top left at the origin, y down, integer coordinates; a loop is a flat
 * [x, y, x, y, ...] ring (a hole is a loop inside an odd number of others,
 * as ui/faces/how_big_art.gd reads it) and `tris` six numbers a triangle.
 *
 * The picture is any raster where the thing is dark or opaque and the rest
 * is light or clear: a PhyloPic raster (black on transparent) or a drawing
 * (black on white). It is cut to a mask, the mask's edges are followed into
 * rings, the rings are thinned to MAX_POINTS (Ramer-Douglas-Peucker) and
 * triangulated with earcut, the algorithm the Python build uses.
 */

export interface Shape {
  w: number;
  h: number;
  loops: number[][];
  tris: number[];
}

export const SIDE = 1000;
/** The bundled shapes are 60 to 374 points; the Python build caps at 400. */
export const MAX_POINTS = 400;
/** The mask is followed at this many pixels across its longer side. */
const TRACE_SIDE = 480;
/** A piece of ink smaller than this share of the largest is a speck. */
const SPECK = 0.01;
/** A hole smaller than this share of the ink is filled. */
const PINHOLE = 0.002;

export interface Mask {
  w: number;
  h: number;
  on: Uint8Array;
}

/** The ink of an RGBA picture: opaque and dark. */
export function maskOf(data: Uint8Array, width: number, height: number): Mask {
  const on = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i++) {
    const a = data[4 * i + 3];
    const lum = 0.299 * data[4 * i] + 0.587 * data[4 * i + 1] + 0.114 * data[4 * i + 2];
    on[i] = a >= 128 && lum < 128 ? 1 : 0;
  }
  return {w: width, h: height, on};
}

/** The mask cropped to its ink, at most TRACE_SIDE across (a pixel is ink
 *  when half of what it stands for is), with a clear pixel round it. */
function fitted(m: Mask): Mask | null {
  let x0 = m.w, y0 = m.h, x1 = -1, y1 = -1;
  for (let y = 0; y < m.h; y++) {
    for (let x = 0; x < m.w; x++) {
      if (m.on[y * m.w + x] === 0) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  if (x1 < 0) return null;
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
  const k = Math.min(1, TRACE_SIDE / Math.max(bw, bh));
  const w = Math.max(1, Math.round(bw * k)), h = Math.max(1, Math.round(bh * k));
  const out = new Uint8Array((w + 2) * (h + 2));
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const sx0 = x0 + Math.floor(x / k), sx1 = Math.max(sx0 + 1, x0 + Math.floor((x + 1) / k));
      const sy0 = y0 + Math.floor(y / k), sy1 = Math.max(sy0 + 1, y0 + Math.floor((y + 1) / k));
      let ink = 0, all = 0;
      for (let sy = sy0; sy < Math.min(sy1, m.h); sy++) {
        for (let sx = sx0; sx < Math.min(sx1, m.w); sx++) {
          ink += m.on[sy * m.w + sx];
          all++;
        }
      }
      out[(y + 1) * (w + 2) + x + 1] = all > 0 && ink * 2 >= all ? 1 : 0;
    }
  }
  return {w: w + 2, h: h + 2, on: out};
}

/** Pieces of ink below SPECK of the largest cleared, and clear pockets
 *  below PINHOLE of the ink filled (4-connected flood fills). */
function cleaned(m: Mask): void {
  const label = new Int32Array(m.w * m.h).fill(-1);
  const pieces: {ink: number; size: number; cells: number[]}[] = [];
  for (let start = 0; start < m.w * m.h; start++) {
    if (label[start] !== -1) continue;
    const ink = m.on[start];
    const cells: number[] = [start];
    label[start] = pieces.length;
    for (let i = 0; i < cells.length; i++) {
      const c = cells[i], x = c % m.w, y = Math.floor(c / m.w);
      for (const n of [x > 0 ? c - 1 : -1, x < m.w - 1 ? c + 1 : -1, y > 0 ? c - m.w : -1, y < m.h - 1 ? c + m.w : -1]) {
        if (n >= 0 && label[n] === -1 && m.on[n] === ink) {
          label[n] = pieces.length;
          cells.push(n);
        }
      }
    }
    pieces.push({ink, size: cells.length, cells});
  }
  const inks = pieces.filter((p) => p.ink === 1);
  const largest = Math.max(0, ...inks.map((p) => p.size));
  const total = inks.reduce((s, p) => s + p.size, 0);
  pieces.forEach((p, i) => {
    // The clear piece holding the corner is the outside, never a hole.
    if (p.ink === 1 && p.size < SPECK * largest) for (const c of p.cells) m.on[c] = 0;
    if (p.ink === 0 && i !== label[0] && p.size < PINHOLE * total) for (const c of p.cells) m.on[c] = 1;
  });
}

/** The mask's edges as closed rings of pixel corners, ink on the right of
 *  every step (y down): outlines one way round, holes the other. */
function rings(m: Mask): number[][][] {
  const W = m.w + 1;
  const ink = (x: number, y: number) => x >= 0 && y >= 0 && x < m.w && y < m.h && m.on[y * m.w + x] === 1;
  const out = new Map<number, number[]>();
  const add = (ax: number, ay: number, bx: number, by: number) => {
    const k = ay * W + ax;
    const list = out.get(k);
    if (list === undefined) out.set(k, [by * W + bx]);
    else list.push(by * W + bx);
  };
  for (let y = 0; y < m.h; y++) {
    for (let x = 0; x < m.w; x++) {
      if (!ink(x, y)) continue;
      if (!ink(x, y - 1)) add(x, y, x + 1, y);
      if (!ink(x + 1, y)) add(x + 1, y, x + 1, y + 1);
      if (!ink(x, y + 1)) add(x + 1, y + 1, x, y + 1);
      if (!ink(x - 1, y)) add(x, y + 1, x, y);
    }
  }
  const loops: number[][][] = [];
  const dir = (a: number, b: number): [number, number] => [b % W - a % W, Math.floor(b / W) - Math.floor(a / W)];
  for (const [first, list] of out) {
    while (list.length > 0) {
      const ring: number[][] = [];
      let at = first;
      let next = list.pop() as number;
      for (let guard = 0; guard < 4 * m.w * m.h; guard++) {
        ring.push([at % W, Math.floor(at / W)]);
        const [dx, dy] = dir(at, next);
        at = next;
        if (at === first && ring.length > 2) break;
        const exits = out.get(at) ?? [];
        if (exits.length === 0) break;
        // Where two corners of ink only touch, turn right: the two are
        // followed as two rings, never one ring through a point.
        let pick = 0;
        if (exits.length > 1) {
          const rank = (e: number) => {
            const [ex, ey] = dir(at, e);
            const cross = dx * ey - dy * ex;
            return cross > 0 ? 0 : cross === 0 ? 1 : 2;
          };
          for (let i = 1; i < exits.length; i++) if (rank(exits[i]) < rank(exits[pick])) pick = i;
        }
        next = exits.splice(pick, 1)[0];
      }
      if (ring.length >= 4) loops.push(ring);
    }
  }
  return loops;
}

function area(ring: number[][]): number {
  let s = 0;
  for (let i = 0; i < ring.length; i++) {
    const [ax, ay] = ring[i], [bx, by] = ring[(i + 1) % ring.length];
    s += ax * by - bx * ay;
  }
  return s / 2;
}

function lineDist(p: number[], a: number[], b: number[]): number {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  const len = Math.hypot(dx, dy);
  if (len === 0) return Math.hypot(p[0] - a[0], p[1] - a[1]);
  return Math.abs(dy * p[0] - dx * p[1] + b[0] * a[1] - b[1] * a[0]) / len;
}

function rdp(pts: number[][], tol: number): number[][] {
  if (pts.length < 3) return pts;
  let far = 0, at = 0;
  for (let i = 1; i < pts.length - 1; i++) {
    const d = lineDist(pts[i], pts[0], pts[pts.length - 1]);
    if (d > far) {
      far = d;
      at = i;
    }
  }
  if (far <= tol) return [pts[0], pts[pts.length - 1]];
  return [...rdp(pts.slice(0, at + 1), tol).slice(0, -1), ...rdp(pts.slice(at), tol)];
}

/** A closed ring thinned: cut at its two points furthest apart. */
function thinned(ring: number[][], tol: number): number[][] {
  let far = 0, at = 0;
  for (let i = 1; i < ring.length; i++) {
    const d = Math.hypot(ring[i][0] - ring[0][0], ring[i][1] - ring[0][1]);
    if (d > far) {
      far = d;
      at = i;
    }
  }
  const a = rdp(ring.slice(0, at + 1), tol);
  const b = rdp([...ring.slice(at), ring[0]], tol);
  return [...a.slice(0, -1), ...b.slice(0, -1)];
}

function inside(p: number[], ring: number[][]): boolean {
  let hit = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i], [xj, yj] = ring[j];
    if ((yi > p[1]) !== (yj > p[1]) && p[0] < (xj - xi) * (p[1] - yi) / (yj - yi) + xi) hit = !hit;
  }
  return hit;
}

/**
 * The shape of the ink in `m`, or a reason it has none. Throws nothing.
 */
export function traced(m0: Mask): {shape: Shape} | {why: string} {
  const m = fitted(m0);
  if (m === null) return {why: "the picture has no ink in it"};
  cleaned(m);
  const raw = rings(m);
  if (raw.length === 0) return {why: "the picture has no ink in it"};
  // Thinner until the points fit, as the Python build does.
  let tol = 0.8;
  let loops: number[][][] = [];
  for (let n = 0; n < 40; n++, tol *= 1.25) {
    loops = raw.map((r) => thinned(r, tol)).filter((r) => r.length >= 3 && Math.abs(area(r)) > 0);
    if (loops.reduce((s, r) => s + r.length, 0) <= MAX_POINTS) break;
  }
  if (loops.reduce((s, r) => s + r.length, 0) > MAX_POINTS) return {why: "the outline is too ragged to draw"};
  // To the 1000 box, integer, origin at the top left.
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const r of loops) for (const [x, y] of r) {
    x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y);
  }
  const k = SIDE / Math.max(x1 - x0, y1 - y0);
  loops = loops.map((r) => r.map(([x, y]) => [Math.round((x - x0) * k), Math.round((y - y0) * k)]))
    .map((r) => r.filter((p, i) => i === 0 || p[0] !== r[i - 1][0] || p[1] !== r[i - 1][1]))
    .map((r) => r.length > 1 && r[0][0] === r[r.length - 1][0] && r[0][1] === r[r.length - 1][1] ? r.slice(0, -1) : r)
    .filter((r) => r.length >= 3 && Math.abs(area(r)) > 0);
  // Outlines and holes: a ring inside an odd number of the others is a hole.
  const depth = loops.map((r, i) => loops.filter((o, j) => j !== i && inside(r[0], o)).length);
  const outers = loops.map((_, i) => i).filter((i) => depth[i] % 2 === 0);
  const tris: number[] = [];
  let triArea = 0;
  let inkArea = 0;
  for (const o of outers) {
    const holes = loops.map((_, i) => i).filter((i) => depth[i] === depth[o] + 1 && inside(loops[i][0], loops[o]));
    const flat: number[] = [];
    const starts: number[] = [];
    for (const r of [o, ...holes]) {
      if (r !== o) starts.push(flat.length / 2);
      for (const [x, y] of loops[r]) flat.push(x, y);
    }
    inkArea += Math.abs(area(loops[o])) - holes.reduce((s, h) => s + Math.abs(area(loops[h])), 0);
    const idx = earcut(flat, starts.length > 0 ? starts : undefined);
    for (let t = 0; t < idx.length; t += 3) {
      const [a, b, c] = [idx[t], idx[t + 1], idx[t + 2]];
      const ax = flat[2 * a], ay = flat[2 * a + 1], bx = flat[2 * b], by = flat[2 * b + 1], cx = flat[2 * c], cy = flat[2 * c + 1];
      triArea += Math.abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay)) / 2;
      tris.push(ax, ay, bx, by, cx, cy);
    }
  }
  if (inkArea <= 0 || Math.abs(triArea - inkArea) > 0.02 * inkArea) {
    return {why: `the outline would not triangulate (${Math.round(triArea)} of ${Math.round(inkArea)})`};
  }
  let w = 0, h = 0;
  for (const r of loops) for (const [x, y] of r) {
    w = Math.max(w, x); h = Math.max(h, y);
  }
  return {shape: {w, h, loops: loops.map((r) => r.flat()), tris}};
}

/** A shape as a PNG data: URL a model can look at: ink on cream, the
 *  longer side `px` across, with a margin. */
export function shapePng(s: Shape, px = 448): string {
  const pad = Math.round(px * 0.08);
  const k = (px - 2 * pad) / Math.max(s.w, s.h);
  const W = Math.round(s.w * k) + 2 * pad, H = Math.round(s.h * k) + 2 * pad;
  const png = new PNG({width: W, height: H});
  for (let i = 0; i < W * H; i++) {
    png.data[4 * i] = 0xf5; png.data[4 * i + 1] = 0xef; png.data[4 * i + 2] = 0xe0; png.data[4 * i + 3] = 255;
  }
  for (let t = 0; t < s.tris.length; t += 6) {
    const p = [0, 2, 4].map((o) => [pad + s.tris[t + o] * k, pad + s.tris[t + o + 1] * k]);
    const xs = p.map((q) => q[0]), ys = p.map((q) => q[1]);
    const d = (p[1][1] - p[2][1]) * (p[0][0] - p[2][0]) + (p[2][0] - p[1][0]) * (p[0][1] - p[2][1]);
    if (d === 0) continue;
    for (let y = Math.max(0, Math.floor(Math.min(...ys))); y <= Math.min(H - 1, Math.ceil(Math.max(...ys))); y++) {
      for (let x = Math.max(0, Math.floor(Math.min(...xs))); x <= Math.min(W - 1, Math.ceil(Math.max(...xs))); x++) {
        const cx = x + 0.5, cy = y + 0.5;
        const a = ((p[1][1] - p[2][1]) * (cx - p[2][0]) + (p[2][0] - p[1][0]) * (cy - p[2][1])) / d;
        const b = ((p[2][1] - p[0][1]) * (cx - p[2][0]) + (p[0][0] - p[2][0]) * (cy - p[2][1])) / d;
        if (a < 0 || b < 0 || a + b > 1) continue;
        const i = 4 * (y * W + x);
        png.data[i] = 0x2a; png.data[i + 1] = 0x26; png.data[i + 2] = 0x22;
      }
    }
  }
  return `data:image/png;base64,${PNG.sync.write(png).toString("base64")}`;
}
