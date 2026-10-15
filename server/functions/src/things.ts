import type {Firestore} from "firebase-admin/firestore";
import jpeg from "jpeg-js";
import {PNG} from "pngjs";
import {ask, available, draw, Drawing} from "./generate";
import {maskOf, Shape, shapePng, traced} from "./silhouette";
import {Theme} from "./theme";
import bundled from "./how_big_bank.json";

/**
 * How Big?'s new things, a few a day on the day's theme (the user,
 * 2026-10-15: "we must find a way to wire the daily process to add new
 * objects into it"; animals and drawn objects both, and the pool grows).
 *
 * A thing is written by the writer (its names, its size with the page it
 * came from, both sides of its box), and then has to get past a
 * supervisor, the user's word for it: "that's why we need a supervisor to
 * check outcome quality and ask to redo if it's poor". Three gates:
 *
 *  A. the size: the reviewer is asked the thing's size cold, and the two
 *     must agree within SIZE_AGREE (the grade gives 100 within 6%, so a
 *     loose truth costs the player points they earned);
 *  B. the box: the silhouette's other side at that size must come within
 *     BOX_AGREE of the thing's real one, as the reviewer gives it in A
 *     (the writer's own was often off: a herring gull 0.3 m tall, 2026-10-15). This is the crocodile of
 *     2026-10-15, a lunge on a slant whose box stood 2 m tall beside a
 *     door: a drawing posed or tilted is turned down here, with numbers;
 *  C. the look: the reviewer is shown the silhouette as the phone draws it
 *     and must name it blind (judged by a second question), and say the
 *     drawing is a clean side view standing as the thing stands.
 *
 * A drawing turned down is redone, told why (the jelly loop's way,
 * jelly.ts). An animal's silhouette is PhyloPic's, CC0 or Public Domain
 * Mark only, as tools/build_how_big.py takes them; the next of its species
 * is tried when one fails. An object is drawn by the image model.
 *
 * A kept thing joins the pool, `things/{id}` (server only, as `themes/`
 * is), and the day's `pictures` content carries the day's new ones and a
 * few of the pool's (OLD), never the whole pool: a document holds 1 MB and
 * a shape is some 5 to 10 KB. The phone pairs them with its own thirty
 * (puzzles/how_big_state.gd); the format is content/how_big.json's row and
 * content/how_big_shapes.json's shape in one.
 */

/** New things a day. */
export const NEW = 2;
/** Things the writer offers, so a few can fall at the gates. */
const OFFERED = 4;
/** Pool things a day carries beside the new ones. */
export const OLD = 6;
/** Drawings a thing may have. */
const DRAWS = 3;
/** The two sizes agree when the bigger over the smaller is at most this. */
const SIZE_AGREE = 1.2;
/** The box's other side over the real one, both ways. A first run turned
 *  a gull down at 1.45 on the writer's own figure; the poses it is for
 *  come out far past this (the crocodile 2.9x, a seal sat up 2.7x). */
const BOX_AGREE = 1.6;

export interface Words3 {
  en: string;
  pt: string;
  es: string;
}

/** A thing as the phone reads it. */
export interface DayThing {
  id: string;
  kind: "animal" | "object";
  name: Words3;
  fact: Words3;
  size_m: number;
  measure: "long" | "tall";
  from: 0;
  to: 1;
  source: string;
  /** The day it was made on. */
  born: number;
  /** PhyloPic's page and its licence, or the image model's name. */
  credit: string;
  shape: Shape;
}

/** What became of a thing, for the log. */
export interface ThingTry {
  what: string;
  kept: boolean;
  why: string[];
}

interface Offer {
  slug: string;
  kind: "animal" | "object";
  taxon: string;
  name: Words3;
  fact: Words3;
  source: string;
  measure: "long" | "tall";
  size_m: number;
  other_m: number;
  draw: string;
}

const WORDS3 = {
  type: "object",
  additionalProperties: false,
  required: ["en", "pt", "es"],
  properties: {en: {type: "string"}, pt: {type: "string"}, es: {type: "string"}},
};

const OFFER_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["things"],
  properties: {
    things: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["slug", "kind", "taxon", "name", "fact", "source", "measure", "size_m", "other_m", "draw"],
        properties: {
          slug: {type: "string"},
          kind: {type: "string", enum: ["animal", "object"]},
          taxon: {type: "string"},
          name: WORDS3,
          fact: WORDS3,
          source: {type: "string"},
          measure: {type: "string", enum: ["long", "tall"]},
          size_m: {type: "number"},
          other_m: {type: "number"},
          draw: {type: "string"},
        },
      },
    },
  },
};

const WRITER = `You pick things for How Big?, a family puzzle game: the player sees one thing at its true size beside another and drags the second to the size they think it is. Every size must be true, since the game grades the player against it.

Each thing is one real thing with a well-known typical size a person can picture: an adult animal of one species, or a standard object whose size hardly varies (a grand piano, a park bench, a school bus, a bowling pin), never something that comes in every size (a box, a lamp, a tree, a house, a rock). Nothing scary, gory or unkind.

The thing is seen from the side, standing or lying as it naturally does at rest: never leaping, rearing, flying with wings up or tilted.
- "measure" is "long" for a thing seen longer than tall from the side (most animals, vehicles, a bench) and "tall" for one taller than long (a giraffe, a penguin, a door, a lighthouse).
- "size_m" is that side of the whole thing as seen, in metres: for "long", nose to tail tip, tail included; for "tall", the ground to its very top (head, ears or antlers included).
- "other_m" is the other side of the same side-on box, in metres: how tall a "long" thing stands from the ground to its top, how long a "tall" thing is from front to back. A saltwater crocodile is long, 4.2 m, other_m about 0.7.
- "source" is the web page the size comes from (Wikipedia or another reference); the size must be the one that page gives for a typical adult or a standard one.

"slug": a short lowercase id, letters and underscores. "taxon": for an animal its scientific name, genus and species ("Crocodylus porosus"); for an object "". "name": a noun or two, a capital first letter, no article, in English, Brazilian Portuguese and Spanish ("Grand piano", "Piano de cauda", "Piano de cola"). "fact": one true, surprising line about it, at most 100 characters, in all three. "draw": for an object, what it looks like from the side, plainly, in one sentence; for an animal "".`;

const SIZER = `You know the typical sizes of animals and objects. Answer from what you know, in metres, for a typical adult animal or a standard object, the whole thing as seen from the side: for a length, nose to tail tip with the tail; for a height, the ground to its very top.`;

const SIZE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["metres", "other_metres"],
  properties: {metres: {type: "number"}, other_metres: {type: "number"}},
};

const LOOKER = `You check silhouettes for a family puzzle game before players see them. You are shown one solid silhouette, dark on cream. Be strict: a player has to recognise it at a glance and judge its size from it.`;

const LOOK_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["sees", "side_view", "pose_ok", "clean", "problem"],
  properties: {
    sees: {type: "string"},
    side_view: {type: "boolean"},
    pose_ok: {type: "boolean"},
    clean: {type: "boolean"},
    problem: {type: "string"},
  },
};

const JUDGE = `You decide whether someone recognised a silhouette. "same" is true when what they said names the thing, or a kind a player told the thing's name would happily accept (a goose seen as "a duck", a wine bottle as "a bottle"). It is false when they named something else, or only a shape or a vague kind that fits many things ("a rectangle", "a circle", "a box", "a ball" for one particular ball, "an animal", "a bird" for a particular bird whose shape should show).`;

const SAME_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["same"],
  properties: {same: {type: "boolean"}},
};

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

function words3(w: unknown, most: number): Words3 | null {
  if (typeof w !== "object" || w === null) return null;
  const o = w as Record<string, unknown>;
  const out = {en: String(o.en ?? "").trim(), pt: String(o.pt ?? "").trim(), es: String(o.es ?? "").trim()};
  return out.en && out.pt && out.es && Math.max(out.en.length, out.pt.length, out.es.length) <= most ? out : null;
}

/** An offer as it may be used, or null. */
function fair(o: Offer): Offer | null {
  const slug = String(o.slug ?? "").toLowerCase().replace(/[^a-z0-9_]/g, "_").replace(/_+/g, "_").replace(/^_|_$/g, "");
  const name = words3(o.name, 28);
  const fact = words3(o.fact, 140);
  const size = Number(o.size_m), other = Number(o.other_m);
  if (!slug || name === null || fact === null) return null;
  if (!(size >= 0.003 && size <= 40) || !(other > 0 && other <= 40)) return null;
  if (o.measure !== "long" && o.measure !== "tall") return null;
  if (o.kind === "animal" && !/^[A-Z][a-z]+ [a-z-]+/.test(String(o.taxon ?? "").trim())) return null;
  if (o.kind === "object" && String(o.draw ?? "").trim() === "") return null;
  if (!/^https:\/\/\S+$/.test(String(o.source ?? "").trim())) return null;
  return {...o, slug, name, fact, size_m: size, other_m: other, taxon: String(o.taxon ?? "").trim(), source: o.source.trim()};
}

// --- PhyloPic ---

const PHYLOPIC = "https://api.phylopic.org";
const OPEN = ["https://creativecommons.org/publicdomain/zero/1.0/", "https://creativecommons.org/publicdomain/mark/1.0/"];

async function getJson(url: string): Promise<Record<string, unknown>> {
  const res = await fetch(url, {headers: {"User-Agent": "peeplet-daily/1.0"}, signal: AbortSignal.timeout(60000)});
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return await res.json() as Record<string, unknown>;
}

interface Silhouette {
  uuid: string;
  by: string;
  licence: string;
  raster: string;
}

/** The species' open silhouettes, best first: the node's own and then its
 *  clade's, CC0 or Public Domain Mark only. */
async function phylopic(taxon: string): Promise<Silhouette[]> {
  const root = await getJson(`${PHYLOPIC}/`).catch(() => ({} as Record<string, unknown>));
  const build = Number(root.build) || 0;
  const b = build > 0 ? `build=${build}&` : "";
  const nodes = await getJson(`${PHYLOPIC}/nodes?${b}filter_name=${encodeURIComponent(taxon.toLowerCase())}&page=0`);
  const href = ((nodes._links as Record<string, unknown>)?.items as {href: string}[] | undefined)?.[0]?.href ?? "";
  const node = /\/nodes\/([0-9a-f-]+)/.exec(href)?.[1];
  if (node === undefined) return [];
  const list = await getJson(`${PHYLOPIC}/images?${b}filter_clade=${node}&page=0&embed_items=true`);
  const items = ((list._embedded as Record<string, unknown>)?.items ?? []) as Record<string, unknown>[];
  const out: Silhouette[] = [];
  for (const it of items) {
    const links = it._links as Record<string, unknown>;
    const licence = String((links.license as {href?: string})?.href ?? "");
    const rasters = (links.rasterFiles ?? []) as {href: string; sizes: string}[];
    if (!OPEN.includes(licence) || rasters.length === 0) continue;
    const biggest = rasters.slice().sort((p, q) => Number(q.sizes.split("x")[0]) - Number(p.sizes.split("x")[0]))[0];
    out.push({uuid: String(it.uuid), by: String(it.attribution ?? ""), licence, raster: biggest.href});
  }
  return out;
}

function pixels(bytes: Buffer, mime: string): {data: Uint8Array; width: number; height: number} {
  if (mime === "image/png") {
    const png = PNG.sync.read(bytes);
    return {data: png.data, width: png.width, height: png.height};
  }
  return jpeg.decode(bytes, {useTArray: true, maxMemoryUsageInMB: 512});
}

// --- the gates ---

/** Gate A: the reviewer's own size, whether the two agree, and its
 *  other side of the box, which gate B goes by. */
async function sizeAgrees(o: Offer): Promise<{ok: boolean; said: number; other: number}> {
  const side = o.measure === "long" ? "long, nose to tail tip with the tail" : "tall, the ground to its very top";
  const other = o.measure === "long" ? "how tall it stands from the ground to its top, as it rests" : "how long it is from front to back, seen from the side";
  const got = await ask<{metres: number; other_metres: number}>({
    system: SIZER,
    prompt: `How ${side}, is ${o.kind === "animal" ? `an adult ${o.name.en.toLowerCase()} (${o.taxon})` : `a standard ${o.name.en.toLowerCase()}`}? Answer "metres". And "other_metres": ${other}.`,
    schema: SIZE_SCHEMA,
    role: "review",
  });
  const said = Number(got.metres);
  const off = said > 0 ? Math.max(said / o.size_m, o.size_m / said) : Infinity;
  const theirs = Number(got.other_metres);
  return {ok: off <= SIZE_AGREE, said, other: theirs > 0 ? theirs : o.other_m};
}

/** Gate B: the box's other side at the stated size against the real one;
 *  "" when it fits, else why, for the redo. */
function boxWhy(o: Offer, s: Shape): string {
  const long = o.measure === "long";
  const other = long ? o.size_m * s.h / s.w : o.size_m * s.w / s.h;
  const r = other / o.other_m;
  if (r <= BOX_AGREE && r >= 1 / BOX_AGREE) return "";
  const way = long ? "tall" : "long";
  return `at ${o.size_m} m ${o.measure} the silhouette comes out ${other.toFixed(2)} m ${way}, and the real one is about ${o.other_m} m ${way}: ` +
    (r > 1 ? `it is posed or tilted so it stands too ${long ? "high" : "deep"}; draw it level, side on, as it stands at rest` :
      `it is squashed or seen end on; draw the whole of it, side on`);
}

/** Gate C, blind: the reviewer names what it sees with no list to pick
 *  from (picking among four, a plain rectangle passed as a shipping
 *  container and a plain disc as a volleyball, 2026-10-15), a second
 *  question with no picture judges whether that is the thing, and the view,
 *  pose and cleanness are passed. */
async function lookWhy(o: Offer, s: Shape): Promise<string> {
  const got = await ask<{sees: string; side_view: boolean; pose_ok: boolean; clean: boolean; problem: string}>({
    system: LOOKER,
    prompt: `What is it? Answer "sees" with what it shows in a few words, as specifically as the shape lets you; if it is only a plain shape, say the shape.
"side_view": true when it is seen from the side (not from above, the front or at an angle).
"pose_ok": true when it stands, sits or lies as it does at rest, level on the ground (or level in the water), not leaping, rearing, diving or tilted.
"clean": true when it is one whole, clear silhouette: nothing cut off, no ground line, shadow, frame, text or second thing. A few thin gaps that help tell what it is (a ball's seams, a door's panels) are fine.
"problem": what is wrong with it in a sentence, or "" when nothing is.`,
    schema: LOOK_SCHEMA,
    role: "review",
    images: [shapePng(s)],
  });
  const sees = String(got.sees ?? "").trim();
  const problem = String(got.problem ?? "").trim();
  if (sees === "") return "shown to someone, they could not say what it is";
  const judged = await ask<{same: boolean}>({
    system: JUDGE,
    prompt: `The thing: ${o.name.en}\nThey said: ${sees}`,
    schema: SAME_SCHEMA,
    role: "review",
  });
  if (judged.same !== true) return `shown to someone with no hint, they saw ${sees}: make it unmistakably ${o.name.en.toLowerCase()} from its outline alone`;
  if (!got.side_view) return `it is not seen from the side${problem ? `: ${problem}` : ""}`;
  if (!got.pose_ok) return `its pose is wrong${problem ? `: ${problem}` : ""}`;
  if (!got.clean) return `the silhouette is not clean${problem ? `: ${problem}` : ""}`;
  return "";
}

function drawPrompt(o: Offer, last: string): string {
  const again = last === "" ? "" : ` The last drawing was turned down: ${last}.`;
  return `A single solid pure black silhouette of ${o.draw.replace(/\.$/, "")}, seen exactly from the side, level, whole and centred, on a plain pure white background with a wide white margin. Flat black only, no shading, no ground line, no shadow, no text, no frame; it must be recognisable from its outline, so draw the parts that make it so, and where only inner lines would tell it (a ball's seams) cut them as a few thin white gaps. Square image.${again}`;
}

/** One offer through the gates: the thing, or null with why in `t`. */
async function oneThing(day: number, o: Offer, t: ThingTry): Promise<DayThing | null> {
  const size = await sizeAgrees(o);
  if (!size.ok) {
    t.why.push(`size ${o.size_m} m against the reviewer's ${size.said} m`);
    return null;
  }
  o = {...o, other_m: size.other};
  const keep = (shape: Shape, credit: string): DayThing => ({
    id: `d_${o.slug}`, kind: o.kind, name: o.name, fact: o.fact, size_m: o.size_m, measure: o.measure,
    from: 0, to: 1, source: o.source, born: day, credit, shape,
  });
  const gates = async (shape: Shape): Promise<string> => boxWhy(o, shape) || await lookWhy(o, shape);
  if (o.kind === "animal") {
    const found = (await phylopic(o.taxon)).slice(0, DRAWS + 1);
    if (found.length === 0) t.why.push(`no open silhouette of ${o.taxon}`);
    for (const sil of found) {
      const res = await fetch(sil.raster, {headers: {"User-Agent": "peeplet-daily/1.0"}, signal: AbortSignal.timeout(60000)});
      if (!res.ok) continue;
      const px = pixels(Buffer.from(await res.arrayBuffer()), "image/png");
      // Faced right, as the bundled thirty mostly are, is not asked for:
      // the board stands a thing by its box, whichever way it looks.
      const got = traced(maskOf(px.data, px.width, px.height));
      const why = "why" in got ? got.why : await gates(got.shape);
      t.why.push(`phylopic ${sil.uuid}: ${why || "kept"}`);
      if (why === "" && "shape" in got) {
        return keep(got.shape, `https://www.phylopic.org/images/${sil.uuid} ${sil.by} ${sil.licence}`);
      }
    }
    return null;
  }
  let last = "";
  for (let n = 0; n < DRAWS; n++) {
    let d: Drawing;
    try {
      d = await draw(drawPrompt(o, last));
    } catch (e) {
      t.why.push(`draw: ${String(e).slice(0, 160)}`);
      continue;
    }
    const px = pixels(d.bytes, d.mime);
    const got = traced(maskOf(px.data, px.width, px.height));
    last = "why" in got ? got.why : await gates(got.shape);
    t.why.push(`drawing ${n}: ${last || "kept"}`);
    if (last === "" && "shape" in got) return keep(got.shape, "drawn by the image model");
  }
  return null;
}

/** Whether `t` may stand in the phone's table: the client's own check
 *  (core/themed_pictures.gd things()) in short, so nothing it would drop
 *  is ever published. */
export function validThing(t: DayThing): boolean {
  const s = t.shape;
  if (!/^d_[a-z0-9_]+$/.test(t.id) || !(t.size_m > 0) || (t.measure !== "long" && t.measure !== "tall")) return false;
  if (words3(t.name, 28) === null || words3(t.fact, 140) === null) return false;
  if (!(s.w > 0 && s.h > 0 && Math.max(s.w, s.h) === 1000) || s.tris.length === 0 || s.tris.length % 6 !== 0) return false;
  return s.loops.length > 0 && s.loops.every((l) => l.length >= 6 && l.length % 2 === 0);
}

/** The pool's things, by id. */
export async function pool(db: Firestore): Promise<Map<string, DayThing>> {
  const out = new Map<string, DayThing>();
  for (const doc of (await db.collection("things").get()).docs) {
    try {
      const t = JSON.parse(String(doc.get("json"))) as DayThing;
      if (validThing(t)) out.set(t.id, t);
    } catch {
      // A thing that does not read is left out.
    }
  }
  return out;
}

/** Names already in the game, English, lowercase: the bundled and the pool. */
function taken(held: Iterable<DayThing>): string[] {
  const out = (bundled.items as {name_en?: string}[]).map((i) => String(i.name_en ?? "").replace(/^(a|an|the) /i, "").toLowerCase());
  for (const t of held) out.push(t.name.en.toLowerCase());
  return out.filter((n) => n !== "");
}

/**
 * The day's new things, NEW at most, each past the three gates, and what
 * became of every offer. `held` is the pool as it stands. Never throws.
 */
export async function makeThings(day: number, theme: Theme, held: Map<string, DayThing>): Promise<{things: DayThing[]; tries: ThingTry[]}> {
  const things: DayThing[] = [];
  const tries: ThingTry[] = [];
  if (!available()) return {things, tries};
  let offers: Offer[] = [];
  try {
    const got = await ask<{things: Offer[]}>({
      system: WRITER,
      prompt: `Today's theme is "${theme.name.en}": ${theme.scene} Its things are ${theme.objects.map((o) => o.name).join(", ")}.
Offer ${OFFERED} things for How Big? that belong with this theme (one of its things when it has a fair size, or an animal or object found with it), at least one animal and at least one object, of different sizes.
Already in the game, so never offer them: ${taken(held.values()).join(", ")}.`,
      schema: OFFER_SCHEMA,
    });
    offers = (got.things ?? []).map(fair).filter((o): o is Offer => o !== null);
  } catch (e) {
    console.error(`things: day ${day}, the writer failed`, e);
    return {things, tries};
  }
  const names = new Set(taken(held.values()));
  for (const o of offers) {
    if (things.length >= NEW) break;
    if (names.has(o.name.en.toLowerCase()) || held.has(`d_${o.slug}`) || things.some((t) => t.id === `d_${o.slug}`)) continue;
    const t: ThingTry = {what: `${o.slug} (${o.kind})`, kept: false, why: []};
    tries.push(t);
    try {
      const got = await oneThing(day, o, t);
      if (got !== null && validThing(got)) {
        t.kept = true;
        things.push(got);
      }
    } catch (e) {
      t.why.push(`failed: ${String(e).slice(0, 200)}`);
      console.error(`things: day ${day}, ${o.slug} failed`, e);
    }
  }
  console.log(`things: day ${day} (${theme.id}), kept ${things.map((t) => t.id).join(" ") || "none"}; ` +
    tries.map((t) => `${t.what}: ${t.why.join("; ")}`).join(" | "));
  return {things, tries};
}

/** The day's list: its new things and OLD of the pool's, picked by the day. */
export function dayList(day: number, fresh: DayThing[], held: Map<string, DayThing>): DayThing[] {
  const old = [...held.values()].filter((t) => !fresh.some((f) => f.id === t.id))
    .sort((a, b) => fnv1a(`${day}${a.id}`) - fnv1a(`${day}${b.id}`)).slice(0, OLD);
  return [...fresh, ...old];
}

/** Puts the new things in the pool (create(): a thing is never rewritten). */
export async function grow(db: Firestore, fresh: DayThing[]): Promise<void> {
  for (const t of fresh) {
    try {
      await db.doc(`things/${t.id}`).create({json: JSON.stringify(t), born: t.born});
    } catch (e) {
      if (!(await db.doc(`things/${t.id}`).get()).exists) throw e;
    }
  }
}
