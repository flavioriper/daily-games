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
 * A model writes a band's puzzles, red herrings named ("traps", TRAPS a
 * band, every language), and a second, blind pass solves them: the
 * reviewer is shown each language's words shuffled with no groups and puts
 * them on shelves itself, says how often it was fooled on the way and what
 * is wrong. A puzzle survives only when the reviewer's shelves are the
 * writer's in every language, it found nothing wrong, and (past Easy) it
 * was fooled at least once; its shelves are then ordered as the reviewer
 * found them. Being unsure is no longer a fault (2026-10-28: the old "sure"
 * gate turned down every board with a real red herring). What is left short is filled from the bank the game ships
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

/** Red herrings each language's set must carry, Easy to Insane: a word of
 *  one shelf that plainly seems to belong on another. A board with none is
 *  sorted at a glance and nobody enjoys it (2026-10-28: the first bank had
 *  none, and "nobody likes it"). */
export const TRAPS = [1, 3, 4, 5];
/** More than this and the board stops being fair: four hearts a day. */
const TRAPS_MAX = 8;

/** A word that looks as if it goes on another shelf: `word` sits in one
 *  group and seems to fit group `seems` (an index into the same groups). */
export interface Trap {
  word: string;
  seems: number;
}

const GROUP_SCHEMA = {
  type: "object",
  properties: {
    label: {type: "string"},
    words: {type: "array", items: {type: "string"}},
  },
  required: ["label", "words"],
  additionalProperties: false,
};

const TRAP_SCHEMA = {
  type: "object",
  properties: {word: {type: "string"}, seems: {type: "integer"}},
  required: ["word", "seems"],
  additionalProperties: false,
};

const WORDING_SCHEMA = {
  type: "object",
  properties: {
    groups: {type: "array", items: GROUP_SCHEMA},
    traps: {type: "array", items: TRAP_SCHEMA},
  },
  required: ["groups", "traps"],
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

/** The ideas every lazy grouping puzzle reaches for; the first bank was made
 *  of little else (instruments, fruit, pasta, pets in a dozen puzzles). */
const STOCK = [
  "musical instruments", "fruits", "vegetables", "pets", "farm animals",
  "birds", "insects", "ocean animals", "shapes", "colours", "weather",
  "kinds of pasta", "cheeses", "metals", "tools", "vehicles", "body parts",
  "clothing", "shoes", "rooms of a home", "sports", "classroom items",
  "kitchen tools", "things in the sky", "planets", "units of measure",
  "things with shells", "things with teeth", "things with faces",
  "things with keys", "palindromes",
];

const WRITER = `You write the daily word-grouping puzzle of a cozy mobile \
game played by families in Brazil, Latin America and the English-speaking \
world. A puzzle is a set of words, every one belonging to exactly one hidden \
group of four; the player sorts them onto shelves, four at a time, and four \
wrong fours end the day.

**The fun is being fooled, then seeing it.** A good board makes the player \
spot a group of four at once, try it, and lose a heart because one of those \
words was really needed somewhere else; then the hidden idea clicks and they \
laugh. A board whose groups can be read off at a glance is a failed board, \
however correct.

How a board is built:
- Start from the subtlest group (a word that goes before or after a partner \
word, a word hiding a smaller word, words that are also verbs or names of \
something else, things that can be "broken", a phrase each completes, \
a sound, a double meaning). Then pick the plain groups so that several of \
their words, and several of the subtle group's words, look as though they \
belong to another group.
- **Red herrings, on purpose**: list them in "traps", each a word and the \
index (0-based, into this language's groups) of the group it *seems* to \
belong to but does not. Typical: five words that all look like "kinds of \
bird" but only four are; a word of the plain group that also fits the \
partner word. Every trap must genuinely tempt an adult.
- Still exactly one sorting of all the words works: a trap fits its false \
group's surface, never its exact idea as the label states it. No five words \
truly share one label.
- Vary the kinds of groups within a puzzle: at most one plain "kinds of X" \
on Medium and harder; the others are properties, partner words, hidden \
words, roles, things that do something, phrases.
- Never use these tired ideas, nor anything close: ${STOCK.join(", ")}. \
Prefer vivid, playful, everyday words (food, home, nature, games, stories) \
over dull ones.
- Groups are ordered from the most obvious to the most subtle.
- Every word is one ordinary dictionary word (no spaces, at most 11 letters), \
no proper names of people or brands, nothing for adults only.
- Written three times: English (en), Brazilian Portuguese (pt) and neutral \
Latin American Spanish (es), each language's words chosen natively, never \
translated word for word, each with its own traps. The plain groups keep the \
same idea in all three, in the same order. A subtle group built on a double \
meaning, a partner word or a sound seldom survives translation: give each \
language its own subtle idea that is natural there, at the same place in the \
order. Each language's set must sort one way only, in that language.
- A group's "label" names its idea in a few words (at most 30 characters), \
in that language, said with a smile when it can ("Words before 'cake'", \
"Things that can be broken").`;

/** What each band is asked for. */
const BRIEFS = [
  (n: number) => `${n} easy puzzles of three groups each (12 words): ideas a ten-year-old knows, at least one honest red herring, and the last group a gentle twist (a partner word, a property).`,
  (n: number) => `${n} puzzles of four groups each (16 words): one plain group, the others properties or partner words, the last subtle; at least three red herrings.`,
  (n: number) => `${n} hard puzzles of four groups each (16 words): the last two groups subtle (a partner word, a hidden word, a double meaning), at least four red herrings, so an obvious-looking group of four is a trap.`,
  (n: number) => `${n} very hard puzzles of five groups each (20 words): the last two groups subtle, at least five red herrings across groups, two plausible groups of five where only four belong.`,
];

function writerPrompt(day: number, band: number, taken: string[]): string {
  const stale = taken.length === 0 ? "" :
    `\n\nGroups used lately, not to be used again nor anything close:\n${taken.map((r) => `- ${r}`).join("\n")}`;
  return `Write the shelves puzzles for day ${day}: ${BRIEFS[band](DRAFTS)} \
No group's idea may repeat across the puzzles.${stale}`;
}

/** A wording's traps that hold: the word is on the board, and the group it
 *  seems to fit is another of this wording's. */
export function goodTraps(w: Wording & {traps?: unknown}): Trap[] {
  if (!Array.isArray(w.traps)) return [];
  const seen = new Set<string>();
  const out: Trap[] = [];
  for (const t of w.traps) {
    if (typeof t !== "object" || t === null) continue;
    const word = norm(String((t as Trap).word ?? ""));
    const seems = Number((t as Trap).seems);
    const home = w.groups.findIndex((g) => g.words.some((x) => norm(x) === word));
    if (home < 0 || !Number.isInteger(seems) || seems < 0 || seems >= w.groups.length || seems === home || seen.has(word)) continue;
    seen.add(word);
    out.push({word, seems});
  }
  return out;
}

/** Whether a written puzzle carries the band's red herrings in every
 *  language, and not so many the board is a lottery. */
export function trapped(p: Puzzle, band: number): boolean {
  return LANGS.every((l) => {
    const n = goodTraps(p[l]).length;
    return n >= TRAPS[band] && n <= TRAPS_MAX;
  });
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
          fooled: {type: "integer"},
          issue: {type: "string", enum: ["none", "ambiguous", "obscure", "translation", "unsuitable", "dull"]},
        },
        required: ["id", "lang", "shelves", "fooled", "issue"],
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
hidden group of four. You are not told the groups. A good puzzle is meant to \
fool its player at first: words that seem to make a group of four but do \
not are the point, not a flaw.

For every puzzle in every language:
- Solve it as a player would. "shelves": your final sorting of all its \
words into groups of four (each a list of four of the words exactly as \
shown), **ordered from the group you found first to the one you found \
last**.
- "fooled": how many tempting wrong groups of four you noticed on the way \
(four words that looked like a group but were not one in the end), 0 when \
every group was plain at a glance.
- "issue", the one thing wrong with it, if anything:
  - ambiguous: once solved, more than one complete sorting still works \
(a fifth word fitting a group's exact idea). A decoy that only fits a \
group's surface is not ambiguous.
  - obscure: a group or word most adults would never get.
  - translation: the language's words read unnaturally or a group only works \
in another language.
  - unsuitable: not for a family game.
  - dull: no red herring worth the name; the groups can be read off at a \
glance.
  - none: a good puzzle.`;

interface Sort {
  id: string;
  lang: string;
  shelves: string[][];
  fooled: number;
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

/** `groups` in the order the reviewer found them (its shelves are the same
 *  partition): the plank colours climb with how hard a shelf really was. */
export function inFoundOrder(groups: Group[], shelves: string[][]): Group[] {
  const key = (ws: string[]) => ws.map(norm).sort().join("|");
  const at = new Map(shelves.map((s, i) => [key(s.map(String)), i]));
  return groups.slice().sort((a, b) => (at.get(key(a.words)) ?? 0) - (at.get(key(b.words)) ?? 0));
}

/** The puzzles the reviewer sorted as the writer meant in every language,
 *  with nothing to say against them, re-ordered as it found the shelves.
 *  The Easy band may be plain; every other one must have fooled it once. */
export function passing(puzzles: Puzzle[], sorts: Sort[], band = 0): Puzzle[] {
  const out: Puzzle[] = [];
  for (const p of puzzles) {
    const why: string[] = [];
    const kept = {id: p.id} as Puzzle;
    for (const l of LANGS) {
      const s = sorts.find((x) => x.id === p.id && x.lang === l);
      if (s === undefined) why.push(`${l}: no sort`);
      else if (!samePartition(p[l].groups, s.shelves)) why.push(`${l}: sorted otherwise`);
      else if (s.issue !== "none" && !(band === 0 && s.issue === "dull")) why.push(`${l}: ${s.issue}`);
      else if (band > 0 && !(Number(s.fooled) >= 1)) why.push(`${l}: fooled nobody`);
      else kept[l] = {groups: inFoundOrder(p[l].groups, s.shelves)};
    }
    if (why.length > 0) console.error(`shelves: ${p.id} turned down (${why.join("; ")}): ${p.en.groups.map((g) => g.label).join(" / ")}`);
    else out.push(kept);
  }
  return out;
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
    .filter((p) => {
      const ok = trapped(p, band);
      if (!ok) console.error(`shelves: ${p.id} turned down (red herrings ${LANGS.map((l) => goodTraps(p[l]).length).join("/")}, ${TRAPS[band]} wanted)`);
      return ok;
    })
    .map(tidy);
  if (written.length === 0) return [];
  const review = await ask<{sorts: Sort[]}>({
    system: REVIEWER,
    prompt: reviewPrompt(written),
    schema: SORT_SCHEMA,
    role: "review",
  });
  return passing(written, Array.isArray(review.sorts) ? review.sorts : [], band);
}

/**
 * The day to publish: a puzzle a band. `recent` is the groups the last days
 * used (asked()). Never throws: a band the model could not write is the
 * bank's, and with no model the whole day is.
 */
export async function makeDay(day: number, recent: string[] = [], _theme: Theme | null = null): Promise<Day> {
  const reserve = bankDay(day);
  if (!available()) return {v: 1, source: "bank", bands: reserve};
  // The bands are written side by side, each given a second try: the review
  // turns down most boards since it asks for red herrings (2026-10-28), and
  // four bands one after another twice would outrun the night's half hour.
  const write = async (b: number): Promise<Puzzle | null> => {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const list = await writeBand(day, b, recent, `d${day}b${b}${attempt > 0 ? `r${attempt}` : ""}`);
        if (list.length > 0) return list[0];
      } catch (e) {
        console.error(`shelves: band ${b} of day ${day} failed (try ${attempt + 1})`, e);
      }
    }
    return null;
  };
  const written = await Promise.all(GROUPS.map((_, b) => write(b)));
  const bands = written.map((p, b) => p ?? reserve[b]);
  const fromBank = written.filter((p) => p === null).length;
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
