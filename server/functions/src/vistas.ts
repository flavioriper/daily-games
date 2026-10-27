import fs from "node:fs";
import path from "node:path";
import jpeg from "jpeg-js";
import {ask, available, draw, Drawing, shapesModel} from "./generate";
import {decoded} from "./pictures";
import {Theme} from "./theme";

/**
 * The day's painted vistas (docs/superpowers/specs/2026-10-17-themed-vistas-
 * design.md): the theme's place painted four times, morning, afternoon,
 * dusk and night, for the difficulty sheet's four rows (ui/menu/vistas.gd's
 * LEVELS, a day going down) and the day card (the afternoon). The six
 * vistas the user supplied stay in the build as the fallback.
 *
 * The morning is painted from the theme's scene with the meadow vista shown
 * as the style; the other three are the morning painted again at their
 * time, so the four are one place. A reviewer sees each beside the morning
 * and turns down text, people, the wrong time or another place.
 */

export const TIMES = ["morning", "afternoon", "dusk", "night"] as const;
export type Time = typeof TIMES[number];

/** What a phone is sent: a JPEG this wide, the drawing's own shape kept
 *  (21:9; a plate crops it with cover, by fractions). */
export const WIDTH = 1024;
const QUALITY = [82, 74, 66];
/** Base64 a vista may be: four stay well under a document's 1 MiB. */
const MAX_B64 = 200 * 1024;
const ASPECT = "21:9";

/** The painting model: the shape boards' (flash on Vertex), whose quota is
 *  not the pixel pictures' pro (2026-10-16) and which painted the first
 *  trial day's four as one place in a minute (2026-10-17);
 *  DAILY_VISTA_MODEL over it. */
export function vistaModel(): string {
  return (process.env.DAILY_VISTA_MODEL ?? "").trim() || shapesModel();
}

const LIGHT: Record<Time, string> = {
  morning: "a fresh clear morning: soft golden-white sunlight, a pale blue sky with a few soft white clouds, dewy fresh greens",
  afternoon: "a golden late afternoon: warm amber sunlight from low in the sky, long soft shadows, honey-coloured light on everything, a warm pale sky",
  dusk: "a glowing sunset at dusk: the sun low on the horizon, a peach, pink and lilac sky, long warm shadows, the first lanterns and windows lit",
  night: "a calm starry night: a deep indigo and violet sky full of stars with a crescent moon, cool blue moonlight on everything, lanterns and windows glowing warm",
};

const NEVER = "No people, no faces, no text, no letters or numbers anywhere (no signs with writing, no labels), no logo, no signature, no watermark, no border or frame.";

/** The first painting: the place, at morning, in the reference's style. */
const FIRST = (t: Theme) => `Paint a wide landscape background for a cosy puzzle game, of this place: ${t.scene} (The day's theme: ${t.name.en}.) ` +
  `Shown at ${LIGHT.morning}. Paint it in exactly the style of the attached picture: a hand-painted storybook illustration, soft painterly ` +
  `brushwork, rich warm saturated colours, rounded friendly shapes, foliage framing the edges, depth to distant hills or sky. Copy only the ` +
  `style: not the attached picture's place, buildings or things. A wide view of the whole place with its things in it, never a close-up of ` +
  `one thing; the left third calm and simple, since words are laid over it. ${NEVER}`;

/** The others: the morning painted again at `time`. */
const AGAIN = (time: Time) => `The attached picture is a painting of a place at morning. Paint exactly the same place again, from exactly ` +
  `the same viewpoint and framing, with the same buildings, trees, paths and things in the same spots, in the same painting style, but at ` +
  `${LIGHT[time]}. Change only the light, the sky and the colours the time of day gives. ${NEVER}`;

const REVIEWER = `You check painted backgrounds for a cosy daily puzzle game played by all ages. You are shown one or two paintings and ` +
  `answer in JSON. A painting is turned down for any of: text, letters, numbers, a logo or a signature anywhere in it; a person or a face; ` +
  `anything frightening, violent or unsuitable for children; not a wide painted landscape (a close-up of one thing, a photo, a pattern); ` +
  `the light not the time of day asked; or, when there is a first painting to compare, a different place or a different framing from it ` +
  `(the light and sky changing is expected). Say what is wrong in "wrong", or leave it empty when nothing is.`;

const REVIEW_SCHEMA = {
  type: "object",
  properties: {wrong: {type: "string"}},
  required: ["wrong"],
  additionalProperties: false,
};

let style: Drawing | null = null;
/** The meadow vista, copied beside the build (package.json's build). */
function styleRef(): Drawing {
  if (style === null) {
    style = {mime: "image/png", bytes: fs.readFileSync(path.join(__dirname, "vista_style.png"))};
  }
  return style;
}

/** `d` made a phone's JPEG: WIDTH wide (each pixel the mean of those it
 *  covers), at the best quality that keeps under MAX_B64. */
export function shrunk(d: Drawing): Drawing {
  const px = decoded(d);
  const ch = px.data.length / (px.width * px.height);
  const w = Math.min(WIDTH, px.width);
  const h = Math.round(px.height * w / px.width);
  const sum = new Float64Array(w * h * 4);
  for (let y = 0; y < px.height; y++) {
    const ty = Math.min(h - 1, Math.floor(y * h / px.height));
    for (let x = 0; x < px.width; x++) {
      const tx = Math.min(w - 1, Math.floor(x * w / px.width));
      const i = (y * px.width + x) * ch, o = (ty * w + tx) * 4;
      sum[o] += px.data[i]; sum[o + 1] += px.data[i + 1]; sum[o + 2] += px.data[i + 2]; sum[o + 3]++;
    }
  }
  const out = Buffer.alloc(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    const n = Math.max(1, sum[i * 4 + 3]);
    out[i * 4] = sum[i * 4] / n; out[i * 4 + 1] = sum[i * 4 + 1] / n; out[i * 4 + 2] = sum[i * 4 + 2] / n; out[i * 4 + 3] = 255;
  }
  let bytes: Buffer = Buffer.alloc(0);
  for (const q of QUALITY) {
    bytes = Buffer.from(jpeg.encode({data: out, width: w, height: h}, q).data);
    if (bytes.toString("base64").length <= MAX_B64) break;
  }
  return {mime: "image/jpeg", bytes};
}

function dataUrl(d: Drawing): string {
  return `data:${d.mime};base64,${d.bytes.toString("base64")}`;
}

/**
 * The vista of `time`, shrunk for a phone, or null when no painting passed.
 * `morning` (already shrunk) is the one the others are painted from and
 * seen beside; `keep` is told of every painting made. Never throws.
 */
export async function makeVista(day: number, theme: Theme, time: Time, morning: Drawing | null,
  keep?: (name: string, d: Drawing) => string, tries = 2): Promise<{vista: Drawing | null; tries: {name: string; wrong: string}[]}> {
  const log: {name: string; wrong: string}[] = [];
  if (!available() || (time !== "morning" && morning === null)) return {vista: null, tries: log};
  const prompt = time === "morning" ? FIRST(theme) : AGAIN(time);
  const shown = time === "morning" ? [styleRef()] : [morning as Drawing];
  for (let attempt = 0; attempt < tries; attempt++) {
    const name = `vista-${time}-${attempt}`;
    try {
      let drawn: Drawing;
      try {
        drawn = await draw(prompt, vistaModel(), {images: shown, aspect: ASPECT});
      } catch (e) {
        if (vistaModel() === shapesModel()) throw e;
        console.error(`vistas: day ${day}, ${time}: ${vistaModel()} would not draw, asking ${shapesModel()}`, e);
        drawn = await draw(prompt, shapesModel(), {images: shown, aspect: ASPECT});
      }
      const small = shrunk(drawn);
      keep?.(name, small);
      const review = await ask<{wrong: string}>({
        system: REVIEWER,
        prompt: time === "morning" ?
          `One painting, of the theme "${theme.name.en}" (${theme.scene}), meant to be at ${time}.` :
          `The first painting is at morning; the second is meant to be the same place at ${time}. Judge the second.`,
        images: time === "morning" ? [dataUrl(small)] : [dataUrl(morning as Drawing), dataUrl(small)],
        schema: REVIEW_SCHEMA,
        role: "review",
      });
      const wrong = String(review.wrong ?? "").trim();
      log.push({name, wrong});
      if (wrong === "") return {vista: small, tries: log};
      console.error(`vistas: day ${day}, ${time}, try ${attempt}: turned down: ${wrong}`);
    } catch (e) {
      log.push({name, wrong: `failed: ${String(e).slice(0, 200)}`});
      console.error(`vistas: day ${day}, ${time}, try ${attempt} failed`, e);
    }
  }
  return {vista: null, tries: log};
}

/** What a phone reads (`days/{day}/turns/vistas`, core/themed_vistas.gd). */
export interface Vistas {
  v: 1;
  theme: string;
  /** The theme's name, which the day card shows in place of the island's. */
  name: {en: string; pt: string; es: string};
  /** A JPEG a time, base64. */
  times: Record<Time, string>;
  /** The day's two Peeplets, indices into the persona list (cast.ts). */
  cast: [number, number];
}
