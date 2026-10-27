import fs from "node:fs";
import path from "node:path";
import {createHash} from "node:crypto";
import jpeg from "jpeg-js";
import {ask, available, draw, Drawing, shapesModel} from "./generate";
import {describe, seeded} from "./cast";
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
/** The fifth painting (2026-10-27): the menu header's own, the same theme seen
 *  from farther away and from another side, so it is not the day card's
 *  afternoon twice. Not a time of day: it is painted on its own, at golden hour. */
export const HEADER_KEY = "header";
/** A painting's place in the day: one of the four times, or the header. */
export type Slot = Time | typeof HEADER_KEY;

/** What a phone is sent: a JPEG this wide, the drawing's own shape kept
 *  (21:9; a plate crops it with cover, by fractions). */
export const WIDTH = 1024;
const QUALITY = [82, 74, 66];
/** Base64 a vista may be: four stay well under a document's 1 MiB. */
const MAX_B64 = 200 * 1024;
const ASPECT = "21:9";
/** The bench keeps the painter's full-size drawing under `<name>` + this (a PNG). */
export const FULL_SUFFIX = "-full";

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

const NEVER = "No humans, no human faces, no text, no letters or numbers anywhere (no signs with writing, no labels), no logo, no signature, " +
  "no watermark, no border or frame. The Peeplets are the only creatures with faces.";

/** The first painting: the place, at morning, in the reference's style, with
 *  the day's two Peeplets (the second attached picture) in the right two thirds. */
const FIRST = (t: Theme, pair: [number, number]) => `Paint a wide landscape background for a cosy puzzle game, of this place: ${t.scene} (The day's theme: ${t.name.en}.) ` +
  `Shown at ${LIGHT.morning}. Paint it in exactly the style of the first attached picture: a hand-painted storybook illustration, soft painterly ` +
  `brushwork, rich warm saturated colours, rounded friendly shapes, foliage framing the edges, depth to distant hills or sky. Copy only the ` +
  `style: not the attached picture's place, buildings or things. A wide view of the whole place with its things in it, never a close-up of ` +
  `one thing; the left third calm and simple, since words are laid over it. ` +
  `Two Peeplets, the small round creatures of the second attached picture, exactly as drawn there: a round body, two short arms, two stubby legs, ` +
  `two eyes, no fingers, no neck. Both stand on their two legs, with both arms and both legs in plain view, in poses taken from the reference ` +
  `sheet, never seated, hidden behind anything or cut off by the frame. Each Peeplet's body is one plain colour all over, with no clothes, no robe, no jacket; only the hat is worn. ` +
  `One is ${describe(pair[0])}, the other ${describe(pair[1])}. They are ` +
  `${t.cast ?? "doing something small together that fits the place"}, in the right two thirds of the painting, each about one seventh of the ` +
  `painting's height, small figures in a wide place, never the main subject, painted in the same brushwork as the place. ${NEVER}`;

/** The header: the same place from a rise or its far edge, at golden hour, the
 *  left half empty for the game's name; no Peeplet sheet, no creatures. */
const HEADER = (t: Theme) => `Paint a wide landscape background for a cosy puzzle game, of the same place as this: ${t.scene} (The day's theme: ${t.name.en}.) ` +
  `but seen from a different side and from much farther away than a scene painted at eye level would be: a view across the whole place from a rise or ` +
  `from its far edge, the horizon low, a big soft sky taking the upper half, golden-hour light (the low sun behind soft clouds, long warm light). ` +
  `Paint it in exactly the style of the attached picture: a hand-painted storybook illustration, soft painterly brushwork, rich warm saturated ` +
  `colours, rounded friendly shapes, depth to distant hills or sky. Copy only the style: not the attached picture's place, buildings or things. ` +
  `The LEFT HALF calm and simple: sky, haze and soft ground only, no building, tree, animal or thing in it, since the game's name is laid over it. ` +
  `No creatures, no figures, no Peeplets. ${NEVER}`;

/** The others: the morning painted again at `time`. */
const AGAIN = (time: Time) => `The attached picture is a painting of a place at morning. Paint exactly the same place again, from exactly ` +
  `the same viewpoint and framing, with the same buildings, trees, paths and things in the same spots, with the same two Peeplets in the same ` +
  `spots and poses, in the same painting style, but at ${LIGHT[time]}. Change only the light, the sky and the colours the time of day gives. ${NEVER}`;

const REVIEWER = `You check painted backgrounds for a cosy daily puzzle game played by all ages. You are shown a reference sheet of the game's ` +
  `creature, the Peeplet, first, then one or two paintings, and answer in JSON. The reference sheet is the only truth about how a Peeplet is built: ` +
  `a round body that is the head too (no neck, nothing between the face and the body), exactly two short stubby nub arms of the same short length ` +
  `(each far shorter than the body is wide), two stubby legs with feet below (a seated Peeplet shows both feet in front of it), two eyes, no fingers. ` +
  `Paintings from the painter are often flawed in a limb in a way that is easy to miss at a glance, so hunt for it: go over each Peeplet one by one ` +
  `against the sheet and note in "limbs", in your own words, its body colour and hat, then what each arm and each leg really looks like ` +
  `(where it starts, where it ends, how far it sticks out from the body in body widths, whether its tip is rounded or flared, spread or hand-like, ` +
  `whether it runs into the body, into the other Peeplet or into a thing it holds) and how many legs or feet show. Do not assume a limb is ` +
  `fine because the pose is cheerful. The sheet's arms are small round-tipped nubs that stick out less than a quarter of the body's width. ` +
  `An arm that reaches out to hold or point at something is still an arm, and it must be short; a third arm is wrong even when it holds a thing; an arm ` +
  `that sticks out more than half the body's width, or ends in a flared, spread or hand-like tip, is too long. Count the feet and legs as well: ` +
  `two, one each side, and a Peeplet that shows one is missing one (unless the other is plainly hidden behind a thing); two limbs that run together ` +
  `into one are fused. Pass a painting only when you looked for these flaws and found none. ` +
  `A painting is turned down for any of: text, letters, numbers, a ` +
  `logo or a signature anywhere in it; any human or human-shaped figure; a Peeplet (the creature on the reference sheet) with more or fewer than ` +
  `two arms or two legs (a seated or half-hidden Peeplet still shows two feet or two legs; a leg that is missing, or that cannot be told from the other, counts as fewer), ` +
  `a limb fused, melted, doubled, merged into the body or into a held thing, bent the wrong way, or longer than the body is wide (an arm ` +
  `that reaches as far as the body is wide or farther is too long), hands with fingers, a neck (a stalk or a ` +
  `narrow part between the face and the body), a second head or ` +
  `face, more than two eyes, or a body that is not one round blob; a Peeplet in the left third of the painting; a Peeplet whose body is larger than ` +
  `about a quarter of the painting's height (clearly over a quarter, past 27%; a body near a quarter is fine) or smaller than a twentieth (a Peeplet's height is measured by its body, its hat excluded); no Peeplet at all, or more than three; anything frightening, violent or unsuitable for ` +
  `children; not a wide painted landscape (a close-up of one thing, a photo, a pattern); the light not the time of day asked; or, when there is a ` +
  `first painting to compare, a different place or a different framing from it (the light and sky changing is expected; so are the lights that are lit at dusk or night: windows, lanterns, the fire and their glow are the time of day and never a different place), or Peeplets that are not the ` +
  `same as the first painting's: when a painting at morning is shown beside the one to judge, the Peeplets in it must be the same Peeplets, the same ` +
  `number, each with the same body colour and the same hat or headgear and each in the same spot; a Peeplet that is added, gone or in another ` +
  `colour is wrong (the night may darken the colours and add glow, but a purple Peeplet stays purple and a pair stays a pair). Say what is wrong in ` +
  `"wrong", or leave it empty when nothing is: if your "limbs" note found any defect in a limb, "wrong" must not be empty. Answer "peeplets" with ` +
  `how many Peeplets you count in the painting being judged.`;

/** The reviewer's per-call prompts (the morning on its own; an edit beside its morning; the header on its own). */
const REVIEW_FIRST = (theme: Theme, time: Time) =>
  `The first picture is the reference sheet of the Peeplet. The second is the painting to judge, of the theme "${theme.name.en}" (${theme.scene}), meant to be at ${time}. Go over each Peeplet's limbs.`;
const REVIEW_EDIT = (time: Time) =>
  `The first picture is the reference sheet of the Peeplet. The second is a painting at morning; the third is meant to be the same place at ${time}. Judge the third. ` +
  `First count the Peeplets in the second picture and note each one's body colour and hat; the third must show those same Peeplets, no more, no fewer, no recoloured. ` +
  `Then go over each Peeplet's limbs in the third.`;

/** The header's reviewer: REVIEWER's Peeplet rules (a sheet first, two to three
 *  Peeplets wanted) would contradict a painting that must have none, so it has
 *  its own short system prompt. */
const REVIEWER_HEADER = `You check painted backgrounds for a cosy daily puzzle game played by all ages, and answer in JSON. You are shown one painting ` +
  `and no reference sheet. Be strict: hunt for any creature, animal, figure or Peeplet (a small round creature with two eyes), any text, ` +
  `letters or numbers, and any thing standing out in the area the brief keeps calm, and say what you find; distant soft scenery is not a thing standing out.`;

/** The header is judged alone, with no sheet: a landscape with no creature at all. */
const REVIEW_HEADER = (theme: Theme) =>
  `The only picture is the header painting of the theme "${theme.name.en}" (${theme.scene}): a wide landscape of that kind of place, meant to be at golden hour (the low sun, ` +
  `long warm light), judged on its own, with no other painting beside it and no reference sheet. It must show NO Peeplet and no creature or figure of ` +
  `any kind: "peeplets" must be 0, and any count above 0 is wrong. Its LEFT HALF must be calm, since the game's name is laid over its upper part: a building, a large tree, an animal, a thing or a ` +
  `foreground bush standing in the left half is wrong; sky, clouds, haze, far hills and soft ground are fine, and so are small, soft, distant ` +
  `trees or bushes on far hills below the horizon (they sit under the lettering, not in it). It must be a wide painted landscape of that kind of place, not a close-up or a pattern. The usual hard rules ` +
  `apply: no text, letters, numbers, logo or signature, no humans or human-shaped figures, nothing frightening, violent or unsuitable for children. ` +
  `Put what you see of any creature or figure in "limbs" (or "none"), and leave "wrong" empty when nothing is wrong.`;

/**
 * A fingerprint of the reviewer's rubric (its system prompt, its two
 * per-call prompts and its answer schema), so the bench's report.json knows
 * which rubric its verdicts came from. The painter's prompts (FIRST, AGAIN,
 * NEVER) are not in it: they change what is painted, not how it is judged.
 * REVIEW_HEADER is not in it either: the bench scores the four vistas only.
 */
export function rubricHash(): string {
  const blank = {name: {en: "", pt: "", es: ""}, scene: ""} as unknown as Theme;
  return createHash("sha1").update([REVIEWER, REVIEW_FIRST(blank, "morning"), REVIEW_EDIT("afternoon"), JSON.stringify(REVIEW_SCHEMA)].join("\n---\n")).digest("hex");
}

const REVIEW_SCHEMA = {
  type: "object",
  // `limbs` comes first on purpose: the model writes what it sees of each
  // Peeplet's arms and legs before it decides `wrong`.
  properties: {limbs: {type: "string"}, wrong: {type: "string"}, peeplets: {type: "integer"}},
  required: ["limbs", "wrong", "peeplets"],
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

let sheet: Drawing | null = null;
/** The Peeplet sheet (assets/peeplet_sheet.png, copied beside the build): the
 *  creature as the game draws it, shown to the painter and the reviewer. */
function sheetRef(): Drawing {
  if (sheet === null) {
    sheet = {mime: "image/png", bytes: fs.readFileSync(path.join(__dirname, "peeplet_sheet.png"))};
  }
  return sheet;
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
 * The review alone: `drawn`, the painter's full-size painting, seen with the
 * Peeplet sheet first and, for an edit, the morning before it. Answers what
 * is wrong ("" when nothing) and how many Peeplets the reviewer counts.
 */
export async function reviewPainting(theme: Theme, time: Slot, drawn: Drawing, morning: Drawing | null):
  Promise<{wrong: string; peeplets: number; limbs: string}> {
  if (time !== "morning" && time !== HEADER_KEY && morning === null) throw new Error(`the ${time} edit needs the morning painting beside it`);
  const header = time === HEADER_KEY;
  const review = await ask<{limbs: string; wrong: string; peeplets: number}>({
    system: header ? REVIEWER_HEADER : REVIEWER,
    prompt: header ? REVIEW_HEADER(theme) : time === "morning" ? REVIEW_FIRST(theme, time) : REVIEW_EDIT(time),
    images: header ? [dataUrl(drawn)] : time === "morning" || morning === null ?
      [dataUrl(sheetRef()), dataUrl(drawn)] : [dataUrl(sheetRef()), dataUrl(morning), dataUrl(drawn)],
    schema: REVIEW_SCHEMA,
    role: "review",
  });
  // Fails closed: a missing or non-numeric count is 0, and a painting passes
  // only with nothing wrong AND one to three Peeplets counted. The header is
  // the other way round: it passes only with nothing wrong AND no Peeplet.
  const n = Number(review.peeplets);
  const peeplets = Number.isFinite(n) ? Math.round(n) : 0;
  let wrong = String(review.wrong ?? "").trim();
  if (header) {
    if (wrong === "" && peeplets !== 0) wrong = `counted ${peeplets} Peeplets in the header`;
  } else if (wrong === "" && (peeplets < 1 || peeplets > 3)) {
    wrong = `counted ${peeplets} Peeplets`;
  }
  // `limbs` is the reviewer's own inspection note, kept for the bench's report.
  return {wrong, peeplets, limbs: String(review.limbs ?? "").trim()};
}

/**
 * The vista of `time`, shrunk for a phone, or null when no painting passed.
 * `morning` (already shrunk) is the one the others are painted from and
 * seen beside; `keep` is told of every painting made (the small one, and
 * under the bench the full one as `<name>` + FULL_SUFFIX). The reviewer sees the
 * painter's full-size painting; only a passing one is shrunk. `size` is the
 * painter's native WxH. Never throws.
 */
export async function makeVista(day: number, theme: Theme, time: Time, morning: Drawing | null,
  keep?: (name: string, d: Drawing) => string, tries = 2, pair: [number, number] = seeded(day)):
  Promise<{vista: Drawing | null; tries: {name: string; wrong: string; peeplets: number; size: string}[]}> {
  const log: {name: string; wrong: string; peeplets: number; size: string}[] = [];
  if (!available() || (time !== "morning" && morning === null)) return {vista: null, tries: log};
  const prompt = time === "morning" ? FIRST(theme, pair) : AGAIN(time);
  const shown = time === "morning" ? [styleRef(), sheetRef()] : [morning as Drawing];
  for (let attempt = 0; attempt < tries; attempt++) {
    const name = `vista-${time}-${attempt}`;
    let size = "";
    try {
      let drawn: Drawing;
      try {
        drawn = await draw(prompt, vistaModel(), {images: shown, aspect: ASPECT});
      } catch (e) {
        if (vistaModel() === shapesModel()) throw e;
        console.error(`vistas: day ${day}, ${time}: ${vistaModel()} would not draw, asking ${shapesModel()}`, e);
        drawn = await draw(prompt, shapesModel(), {images: shown, aspect: ASPECT});
      }
      const px = decoded(drawn);
      size = `${px.width}x${px.height}`;
      // The bench keeps the paid drawing before the review, which can fail.
      keep?.(name + FULL_SUFFIX, drawn);
      const {wrong, peeplets} = await reviewPainting(theme, time, drawn, morning);
      log.push({name, wrong, peeplets, size});
      // Only a passing painting is shrunk for a phone; the bench (`keep`) is
      // shown every try, small and full.
      const small = wrong === "" || keep !== undefined ? shrunk(drawn) : null;
      if (small !== null) keep?.(name, small);
      if (wrong === "" && small !== null) return {vista: small, tries: log};
      console.error(`vistas: day ${day}, ${time}, try ${attempt}: turned down: ${wrong}`);
    } catch (e) {
      log.push({name, wrong: `failed: ${String(e).slice(0, 200)}`, peeplets: 0, size});
      console.error(`vistas: day ${day}, ${time}, try ${attempt} failed`, e);
    }
  }
  return {vista: null, tries: log};
}

/**
 * The header painting, shrunk for a phone, or null when none passed: the
 * theme's place from another side and farther away (HEADER), painted from the
 * style reference alone (no Peeplet sheet), reviewed on its own and passed only
 * with nothing wrong and no Peeplet counted. Mirrors makeVista; never throws.
 */
export async function makeHeader(day: number, theme: Theme, keep?: (name: string, d: Drawing) => string, tries = 2):
  Promise<{vista: Drawing | null; tries: {name: string; wrong: string; peeplets: number; size: string}[]}> {
  const log: {name: string; wrong: string; peeplets: number; size: string}[] = [];
  if (!available()) return {vista: null, tries: log};
  const prompt = HEADER(theme);
  const shown = [styleRef()];
  for (let attempt = 0; attempt < tries; attempt++) {
    const name = `vista-${HEADER_KEY}-${attempt}`;
    let size = "";
    try {
      let drawn: Drawing;
      try {
        drawn = await draw(prompt, vistaModel(), {images: shown, aspect: ASPECT});
      } catch (e) {
        if (vistaModel() === shapesModel()) throw e;
        console.error(`vistas: day ${day}, ${HEADER_KEY}: ${vistaModel()} would not draw, asking ${shapesModel()}`, e);
        drawn = await draw(prompt, shapesModel(), {images: shown, aspect: ASPECT});
      }
      const px = decoded(drawn);
      size = `${px.width}x${px.height}`;
      keep?.(name + FULL_SUFFIX, drawn);
      const {wrong, peeplets} = await reviewPainting(theme, HEADER_KEY, drawn, null);
      log.push({name, wrong, peeplets, size});
      const small = wrong === "" || keep !== undefined ? shrunk(drawn) : null;
      if (small !== null) keep?.(name, small);
      if (wrong === "" && small !== null) return {vista: small, tries: log};
      console.error(`vistas: day ${day}, ${HEADER_KEY}, try ${attempt}: turned down: ${wrong}`);
    } catch (e) {
      log.push({name, wrong: `failed: ${String(e).slice(0, 200)}`, peeplets: 0, size});
      console.error(`vistas: day ${day}, ${HEADER_KEY}, try ${attempt} failed`, e);
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
  /** The menu header's own painting (a JPEG, base64), when one passed. */
  header?: string;
  /** The day's two Peeplets, indices into the persona list (cast.ts). */
  cast: [number, number];
}
