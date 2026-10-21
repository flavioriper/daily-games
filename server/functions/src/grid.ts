import {PNG} from "pngjs";
import type {Drawing} from "./generate";
import {decoded} from "./pictures";

/**
 * The mapping field: a drawing with a numbered grid laid over it, so a
 * vision model can answer a map in grid coordinates (Yarn Hoop's pins and
 * panels, Gumdrop's chunks) instead of in pixels it cannot count. The
 * drawing is scaled to a square, a white margin carries the numbers, and
 * every line is numbered on all four edges so a point can be read off the
 * nearest edge. The digits come from a bitmap font in code: nothing on the
 * server's disk to ship.
 */

/** Cells a side of the hoop's grid, by band. */
export const GRID_N = [20, 24, 30, 40];
/** Cells a side of the jelly's grid (its field is 0-100, a label every 5). */
export const JELLY_GRID_N = 20;

/** Pixels a side the drawing is laid at, and the white margin round it. */
const SIDE = 1000;
const MARGIN = 44;
/** Past this many cells a side only every other line is numbered. */
const EVERY_LINE = 24;

/** Digits 0-9, five columns by seven rows, a row a string. */
const FONT: Record<string, string[]> = {
  "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
  "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
  "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
  "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
  "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
  "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
  "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
  "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
  "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
  "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
};

/** The drawing as SIDE x SIDE white-backed RGB, each pixel the mean of the
 *  ones it covers (one pixel's colour when it is blown up), a non-square
 *  drawing centred with white filling the rest. */
function square(d: Drawing): Uint8Array {
  const px = decoded(d);
  const ch = px.data.length / (px.width * px.height);
  const out = new Uint8Array(SIDE * SIDE * 3).fill(255);
  const scale = Math.max(px.width, px.height) / SIDE;
  const w = Math.round(px.width / scale), h = Math.round(px.height / scale);
  const ox = Math.floor((SIDE - w) / 2), oy = Math.floor((SIDE - h) / 2);
  for (let y = 0; y < h; y++) {
    const y0 = Math.min(px.height - 1, Math.floor(y * scale));
    const y1 = Math.min(px.height, Math.max(y0 + 1, Math.ceil((y + 1) * scale)));
    for (let x = 0; x < w; x++) {
      const x0 = Math.min(px.width - 1, Math.floor(x * scale));
      const x1 = Math.min(px.width, Math.max(x0 + 1, Math.ceil((x + 1) * scale)));
      const sum = [0, 0, 0];
      for (let sy = y0; sy < y1; sy++) {
        for (let sx = x0; sx < x1; sx++) {
          const i = (sy * px.width + sx) * ch;
          // A see-through pixel is the white it will be seen on.
          const a = ch === 4 ? px.data[i + 3] / 255 : 1;
          for (let c = 0; c < 3; c++) sum[c] += px.data[i + c] * a + 255 * (1 - a);
        }
      }
      const count = (y1 - y0) * (x1 - x0), o = ((oy + y) * SIDE + ox + x) * 3;
      for (let c = 0; c < 3; c++) out[o + c] = Math.round(sum[c] / count);
    }
  }
  return out;
}

/** The drawing with an n by n grid over it, the line i numbered i * labelStep
 *  (1 for the hoop's grid units, 5 for the jelly's 0-100 field) on all four
 *  edges: every line when n is 24 or under, every other past that. Every
 *  fifth line is darker. */
export function gridOver(d: Drawing, n: number, labelStep: number): Drawing {
  const total = SIDE + 2 * MARGIN;
  const png = new PNG({width: total, height: total});
  png.data.fill(255);
  const art = square(d);
  for (let y = 0; y < SIDE; y++) {
    for (let x = 0; x < SIDE; x++) {
      const o = ((y + MARGIN) * total + x + MARGIN) * 4, s = (y * SIDE + x) * 3;
      png.data[o] = art[s]; png.data[o + 1] = art[s + 1]; png.data[o + 2] = art[s + 2];
    }
  }
  /** Black laid over a pixel at the given opacity (0-255). */
  const ink = (x: number, y: number, alpha: number) => {
    if (x < 0 || y < 0 || x >= total || y >= total) return;
    const o = (y * total + x) * 4;
    for (let c = 0; c < 3; c++) png.data[o + c] = Math.round(png.data[o + c] * (1 - alpha / 255));
  };
  // Lines, the fifth ones darker and a pixel wider so they count at a glance.
  for (let i = 0; i <= n; i++) {
    const at = MARGIN + Math.min(SIDE - 1, Math.round((i * SIDE) / n));
    const fifth = i % 5 === 0, alpha = fifth ? 110 : 60;
    for (let t = 0; t < SIDE; t++) {
      for (let w = 0; w < (fifth ? 2 : 1); w++) {
        ink(at - w, MARGIN + t, alpha);
        ink(MARGIN + t, at - w, alpha);
      }
    }
  }
  // Numbers: the largest scale that fits the widest in the margin.
  const widest = String(n * labelStep).length;
  const k = widest <= 2 ? 3 : 2;
  const textW = (s: string) => s.length * 6 * k - k, textH = 7 * k;
  const text = (s: string, cx: number, cy: number) => {
    const x0 = Math.round(cx - textW(s) / 2), y0 = Math.round(cy - textH / 2);
    for (let g = 0; g < s.length; g++) {
      FONT[s[g]].forEach((row, r) => {
        for (let c = 0; c < 5; c++) {
          if (row[c] !== "1") continue;
          for (let dy = 0; dy < k; dy++) {
            for (let dx = 0; dx < k; dx++) ink(x0 + g * 6 * k + c * k + dx, y0 + r * k + dy, 255);
          }
        }
      });
    }
  };
  const step = n <= EVERY_LINE ? 1 : 2;
  const mid = MARGIN / 2;
  for (let i = 0; i <= n; i += step) {
    const s = String(i * labelStep);
    const at = MARGIN + Math.min(SIDE - 1, Math.round((i * SIDE) / n));
    text(s, at, mid);
    text(s, at, total - mid);
    text(s, mid, at);
    text(s, total - mid, at);
  }
  return {mime: "image/png", bytes: PNG.sync.write(png)};
}
