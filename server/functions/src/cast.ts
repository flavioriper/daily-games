import personas from "./cast_personas.json";
import {fnv1a} from "./eye";

/**
 * The day's cast: the two Peeplets the night paints into the day's vistas
 * (docs/superpowers/specs/2026-10-27-peeplet-brand-design.md). Only the
 * personas a painter can name in words are eligible: a flat coat (a colour)
 * and a plain hat (one a child names at once). The phone picks the same two
 * with the same rule (core/cast.gd), so the seed strings and the rule below
 * are a contract: docs/agents/days-dashboard.md keeps a test vector.
 *
 * cast_personas.json is written from peeplet/peeplet_personas.gd by
 * tools/export_personas.gd, run by hand when that list changes.
 */

interface Persona {
  name: string;
  coat: number;
  hat: string;
  eyes: string;
}

const ALL = personas as Persona[];

/** The hats the painter can say in a few words, "" for none. */
export const PLAIN_HATS = ["", "bandana", "beanie", "bow", "cap", "chefHat", "earmuffs", "sunhat", "topHat",
  "partyHat", "mushroomCap", "flowerCrown"];

export const HAT_WORDS: Record<string, string> = {
  sunhat: "a straw sun hat",
  cap: "a baseball cap",
  beanie: "a knitted beanie",
  bow: "a bow on its head",
  chefHat: "a white chef's hat",
  earmuffs: "fluffy earmuffs",
  topHat: "a top hat",
  partyHat: "a cone party hat",
  mushroomCap: "a red spotted mushroom cap",
  flowerCrown: "a crown of small flowers",
  bandana: "a bandana tied on its head",
  "": "no hat",
};

/** The flat coats, PeepletPalette.BODY 0..7, as the rendered sheet reads
 *  them (coat 0 reads plain red, whatever the palette calls it). */
export const COAT_WORDS = ["red", "mint", "sky blue", "butter yellow", "lavender", "peach", "sage green", "slate grey"];

/** Indices into the persona list, in order, that can be painted from words. */
export function eligible(): number[] {
  const out: number[] = [];
  ALL.forEach((p, i) => {
    if (p.coat >= 0 && p.coat < COAT_WORDS.length && PLAIN_HATS.includes(p.hat)) out.push(i);
  });
  return out;
}

/** The day's two: day is the yyyymmdd number. When fewer than two personas
 *  are eligible, the pair is [0, 1], the first two of ALL (describe() copes
 *  with any persona, eligible or not). */
export function seeded(day: number): [number, number] {
  const list = eligible();
  const n = list.length;
  if (n < 2) return [0, 1];
  const a = fnv1a("cast-a-" + day) % n;
  const b0 = fnv1a("cast-b-" + day) % n;
  const b = b0 === a ? (a + 1) % n : b0;
  return [list[a], list[b]];
}

/** What a painter is told of persona i; total: a coat index outside
 *  COAT_WORDS reads "coloured" and a hat outside HAT_WORDS "a plain hat",
 *  never undefined. */
export function describe(i: number): string {
  const p = ALL[i];
  const c = COAT_WORDS[p.coat] ?? "coloured";
  return `a ${c} Peeplet (its whole round body is ${c}) wearing ${HAT_WORDS[p.hat] ?? "a plain hat"}`;
}
