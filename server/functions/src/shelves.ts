import {ask, available} from "./generate";
import type {Theme} from "./theme";
import bank from "./shelves_bank.json";

/**
 * Four Shelves' day (puzzles/shelves2d.gd): a puzzle a band of words hiding
 * in groups of four, in English, Portuguese and Spanish. Easy hides three
 * groups (twelve words), Medium and Hard four, Insane five (Crowded Pantry).
 *
 * A group is a shared idea (kinds of bread, things with keys, words before
 * "fish"), never a pun across languages: each language's words are its
 * own, chosen natively under the same idea, so a group stands in all three.
 *
 * A model writes a band's puzzles and a second, blind pass sorts them: the
 * reviewer is shown each language's words shuffled with no groups and puts
 * them on shelves itself. A puzzle survives only when the reviewer's shelves
 * are the writer's in every language, it was sure, and it found nothing to
 * say. What is left short is filled from the bank the game ships
 * (content/shelves.json, copied beside this file by `npm run build`), the
 * same puzzle a phone that never reached the network deals itself.
 */

export const LANGS = ["en", "pt", "es"] as const;
export type Lang = (typeof LANGS)[number];

/** Groups a band hides, Easy to Insane. */
export const GROUPS = [3, 4, 4, 5];
/** Puzzles the model is asked for a band, so the review has some to turn down. */
const DRAFTS = 3;
/** The longest a word and a group's name may be (a word fills a tile). */
const WORD_MAX = 12;
const LABEL_MAX = 34;

export interface Group {
  label: string;
  words: string[];
}

export interface Wording {
  groups: Group[];
}

export interface Puzzle {
  id: string;
  en: Wording;
  pt: Wording;
  es: Wording;
}

export interface Day {
  v: 1;
  source: "model" | "bank" | "mixed";
  /** A band null when neither the model nor the bank had one: the phone
   *  deals that band from its own bank. */
  bands: (Puzzle | null)[];
}

// --- the bank ---

export function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** A tier's puzzle for a day: the one whose hash of the day and its id is
 *  least. puzzles/shelves_state.gd picks the same way. Hashed twice, as
 *  Golden Acorn's are: FNV's last byte barely stirs the top bits. */
export function bankPick(tier: Puzzle[], day: number): Puzzle {
  let best = tier[0];
  let low = Infinity;
  for (const p of tier) {
    const k = fnv1a(String(fnv1a(`shelves|${day}|${p.id}`)));
    if (k < low || (k === low && p.id < best.id)) {
      low = k;
      best = p;
    }
  }
  return best;
}

/** The bank's puzzle a band; null for a band whose tier is empty (a bank
 *  still being grown), which the phone deals from its own copy. */
export function bankDay(day: number, tiers: Puzzle[][] = bank.tiers as Puzzle[][]): (Puzzle | null)[] {
  return GROUPS.map((_, b) => (tiers[b] ?? []).length > 0 ? bankPick(tiers[b], day) : null);
}

// --- what a puzzle must be ---

/** A word as the game compares it: trimmed, upper case. */
export function norm(w: string): string {
  return w.trim().toLocaleUpperCase();
}

function validWording(w: unknown, groups: number): w is Wording {
  if (typeof w !== "object" || w === null) return false;
  const g = (w as Record<string, unknown>).groups;
  if (!Array.isArray(g) || g.length !== groups) return false;
  const seen = new Set<string>();
  for (const x of g) {
    if (typeof x !== "object" || x === null) return false;
    const label = (x as Record<string, unknown>).label;
    const words = (x as Record<string, unknown>).words;
    if (typeof label !== "string" || label.trim() === "" || label.length > LABEL_MAX) return false;
    if (!Array.isArray(words) || words.length !== 4) return false;
    for (const word of words) {
      if (typeof word !== "string") return false;
      const n = norm(word);
      if (n === "" || n.length > WORD_MAX || /\s/.test(n)) return false;
      seen.add(n);
    }
  }
  return seen.size === groups * 4;
}

export function validPuzzle(p: unknown, band: number): p is Puzzle {
  if (typeof p !== "object" || p === null) return false;
  const x = p as Record<string, unknown>;
  if (typeof x.id !== "string") return false;
  return LANGS.every((l) => validWording(x[l], GROUPS[band]));
}

/** Upper case, trimmed words: what the phone shows and compares. */
export function tidy(p: Puzzle): Puzzle {
  const out = {id: p.id} as Puzzle;
  for (const l of LANGS) {
    out[l] = {groups: p[l].groups.map((g) => ({label: g.label.trim(), words: g.words.map(norm)}))};
  }
  return out;
}

// --- the writer ---

const GROUP_SCHEMA = {
  type: "object",
  properties: {
    label: {type: "string"},
    words: {type: "array", items: {type: "string"}},
  },
  required: ["label", "words"],
  additionalProperties: false,
};

const WORDING_SCHEMA = {
  type: "object",
  properties: {groups: {type: "array", items: GROUP_SCHEMA}},
  required: ["groups"],
  additionalProperties: false,
};

const PUZZLE_SCHEMA = {
  type: "object",
  properties: {en: WORDING_SCHEMA, pt: WORDING_SCHEMA, es: WORDING_SCHEMA},
  required: ["en", "pt", "es"],
  additionalProperties: false,
};

const BAND_SCHEMA = {
  type: "object",
  properties: {puzzles: {type: "array", items: PUZZLE_SCHEMA}},
  required: ["puzzles"],
  additionalProperties: false,
};

const WRITER = `You write the daily word-grouping puzzle of a cozy mobile \
game played by families in Brazil, Latin America and the English-speaking \
world. A puzzle is a set of words, every one belonging to exactly one hidden \
group of four; the player sorts them onto shelves, four at a time.

What every puzzle must be:
- Each group is a clear shared idea a player can name once they see it: a \
kind of thing (types of pasta), a property (things that are striped), a \
shared partner word (words that go before "ball"), a role, a place.
- **Red herrings are the point**: several words should look as though they \
belong to a second group, so the first guess is often wrong, but in the end \
exactly one way of sorting all the words works. No word may truly fit two \
groups.
- Groups are ordered from the most obvious to the most subtle.
- Every word is one ordinary dictionary word (no spaces, at most 11 letters), \
no proper names of people or brands, nothing for adults only.
- Written three times: English (en), Brazilian Portuguese (pt) and neutral \
Latin American Spanish (es), each language's words chosen natively, never \
translated word for word. The plain groups keep the same idea in all three, \
in the same order. A subtle group built on a double meaning, a partner word \
or a sound seldom survives translation ("things with keys" is two different \
words in Portuguese): for such a group, give each language its own subtle \
idea that is natural there, at the same place in the order. Each language's \
set must sort one way only, in that language.
- A group's "label" names its idea in a few words (at most 30 characters), \
in that language.`;

/** What each band is asked for. */
const BRIEFS = [
  (n: number) => `${n} easy puzzles of three groups each (12 words): ideas a ten-year-old knows, one mild red herring.`,
  (n: number) => `${n} puzzles of four groups each (16 words): everyday ideas, the last group a little subtle, a few red herrings.`,
  (n: number) => `${n} hard puzzles of four groups each (16 words): the last two groups subtle (a partner word, a hidden property), many red herrings.`,
  (n: number) => `${n} very hard puzzles of five groups each (20 words): the last two groups subtle, many red herrings across groups.`,
];

function writerPrompt(day: number, band: number, taken: string[]): string {
  const stale = taken.length === 0 ? "" :
    `\n\nGroups used lately, not to be used again nor anything close:\n${taken.map((r) => `- ${r}`).join("\n")}`;
  return `Write the shelves puzzles for day ${day}: ${BRIEFS[band](DRAFTS)} \
No group's idea may repeat across the puzzles.${stale}`;
}

// --- the reviewer ---

const SORT_SCHEMA = {
  type: "object",
  properties: {
    sorts: {
      type: "array",
      items: {
        type: "object",
        properties: {
          id: {type: "string"},
          lang: {type: "string", enum: [...LANGS]},
          shelves: {type: "array", items: {type: "array", items: {type: "string"}}},
          sure: {type: "boolean"},
          issue: {type: "string", enum: ["none", "ambiguous", "obscure", "translation", "unsuitable"]},
        },
        required: ["id", "lang", "shelves", "sure", "issue"],
        additionalProperties: false,
      },
    },
  },
  required: ["sorts"],
  additionalProperties: false,
};

const REVIEWER = `You test a family word-grouping puzzle before it is \
published in English, Portuguese and Spanish. Each puzzle is shown as a \
shuffled set of words in one language: every word belongs to exactly one \
hidden group of four. You are not told the groups.

For every puzzle in every language: sort all its words into groups of four \
yourself ("shelves", each a list of four of the words exactly as shown), say \
whether you are sure your sorting is the only one that works ("sure"), and \
name the one thing wrong with it, if anything ("issue"):
- ambiguous: a word fits two groups, or more than one sorting works.
- obscure: a group or word most adults would never get.
- translation: the language's words read unnaturally or a group only works in \
another language.
- unsuitable: not for a family game.
- none: a good puzzle.

Be strict. A sorting you would not stake your name on is not "sure".`;

interface Sort {
  id: string;
  lang: string;
  shelves: string[][];
  sure: boolean;
  issue: string;
}

/** A puzzle's words in the order the reviewer sees them: shuffled by the
 *  puzzle's id and language, so nothing about the groups shows. */
export function shuffled(p: Puzzle, l: Lang): string[] {
  const words = p[l].groups.flatMap((g) => g.words.map(norm));
  let s = fnv1a(String(fnv1a(`${p.id}|${l}`)));
  for (let i = words.length - 1; i > 0; i--) {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    const j = (s >>> 16) % (i + 1);
    [words[i], words[j]] = [words[j], words[i]];
  }
  return words;
}

function reviewPrompt(puzzles: Puzzle[]): string {
  const blocks: string[] = [];
  for (const p of puzzles) {
    for (const l of LANGS) {
      blocks.push(`[${p.id}] ${l}: ${shuffled(p, l).join(", ")}`);
    }
  }
  return `Sort these ${puzzles.length} puzzles, each in all three languages: ` +
    `one sort a puzzle a language, by its id and language.\n\n${blocks.join("\n")}`;
}

/** Whether `shelves` is exactly the partition `groups` make. */
export function samePartition(groups: Group[], shelves: string[][]): boolean {
  if (shelves.length !== groups.length) return false;
  const want = new Set(groups.map((g) => g.words.map(norm).sort().join("|")));
  for (const s of shelves) {
    if (!Array.isArray(s) || !want.delete(s.map((w) => norm(String(w))).sort().join("|"))) return false;
  }
  return want.size === 0;
}

/** The puzzles the reviewer sorted as the writer meant in every language,
 *  surely, with nothing to say against them. */
export function passing(puzzles: Puzzle[], sorts: Sort[]): Puzzle[] {
  return puzzles.filter((p) => {
    const why: string[] = [];
    for (const l of LANGS) {
      const s = sorts.find((x) => x.id === p.id && x.lang === l);
      if (s === undefined) why.push(`${l}: no sort`);
      else if (!samePartition(p[l].groups, s.shelves)) why.push(`${l}: sorted otherwise`);
      else if (!s.sure || s.issue !== "none") why.push(`${l}: ${s.sure ? "" : "unsure "}${s.issue}`);
    }
    if (why.length > 0) console.error(`shelves: ${p.id} turned down (${why.join("; ")}): ${p.en.groups.map((g) => g.label).join(" / ")}`);
    return why.length === 0;
  });
}

// --- the day ---

/** What a published day says of itself to the next day's writer: its
 *  groups' English names. */
export function asked(day: unknown): string[] {
  const bands = (day as Day | undefined)?.bands;
  if (!Array.isArray(bands)) return [];
  const out: string[] = [];
  for (const p of bands) {
    const groups = (p as Puzzle | undefined)?.en?.groups;
    if (Array.isArray(groups)) for (const g of groups) if (typeof g?.label === "string") out.push(g.label);
  }
  return out;
}

/** A band's puzzles from the model: written, checked, sorted blind. Throws
 *  when the model could not be asked. */
export async function writeBand(day: number, band: number, taken: string[], prefix = `d${day}b${band}`): Promise<Puzzle[]> {
  const draft = await ask<{puzzles: Omit<Puzzle, "id">[]}>({
    system: WRITER,
    prompt: writerPrompt(day, band, taken),
    schema: BAND_SCHEMA,
    role: "write",
  });
  const written = (Array.isArray(draft.puzzles) ? draft.puzzles : [])
    .map((d, i) => ({id: `${prefix}p${i}`, en: d.en, pt: d.pt, es: d.es}))
    .filter((p): p is Puzzle => validPuzzle(p, band))
    .map(tidy);
  if (written.length === 0) return [];
  const review = await ask<{sorts: Sort[]}>({
    system: REVIEWER,
    prompt: reviewPrompt(written),
    schema: SORT_SCHEMA,
    role: "review",
  });
  return passing(written, Array.isArray(review.sorts) ? review.sorts : []);
}

/**
 * The day to publish: a puzzle a band. `recent` is the groups the last days
 * used (asked()). Never throws: a band the model could not write is the
 * bank's, and with no model the whole day is.
 */
export async function makeDay(day: number, recent: string[] = [], _theme: Theme | null = null): Promise<Day> {
  const reserve = bankDay(day);
  if (!available()) return {v: 1, source: "bank", bands: reserve};
  const taken = recent.slice();
  const bands: (Puzzle | null)[] = [];
  let fromBank = 0;
  for (let b = 0; b < GROUPS.length; b++) {
    let list: Puzzle[] = [];
    try {
      list = await writeBand(day, b, taken);
    } catch (e) {
      console.error(`shelves: band ${b} of day ${day} failed, the bank fills it`, e);
    }
    const p = list.length > 0 ? list[0] : reserve[b];
    if (list.length === 0) fromBank++;
    bands.push(p);
    if (p !== null) taken.push(...p.en.groups.map((g) => g.label));
  }
  const source = fromBank === 0 ? "model" : fromBank === GROUPS.length ? "bank" : "mixed";
  return {v: 1, source, bands};
}

/** Puzzles for the bank: `count` reviewed ones of `band`, told what the
 *  bank already has. */
export async function bankPuzzles(band: number, count: number, taken: string[], id: (n: number) => string): Promise<Puzzle[]> {
  const out: Puzzle[] = [];
  const told = taken.slice();
  let round = 0;
  while (out.length < count && round < count * 3) {
    let got: Puzzle[] = [];
    try {
      got = await writeBand(0, band, told.slice(-160), `bank${band}r${round}`);
    } catch (e) {
      console.error(`shelves bank: band ${band} round ${round} failed`, e);
    }
    for (const p of got) {
      if (out.length >= count) break;
      const kept = {...p, id: id(out.length)};
      out.push(kept);
      told.push(...p.en.groups.map((g) => g.label));
    }
    round++;
    console.error(`shelves bank: band ${band}: ${out.length} of ${count} after ${round} rounds`);
  }
  return out;
}
