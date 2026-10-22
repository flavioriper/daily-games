import {ask, available} from "./generate";
import type {Theme} from "./theme";
import bank from "./clues_bank.json";

/**
 * Five Clues' day (puzzles/clues2d.gd): rounds of a hidden idea and five
 * clue words that all belong to it, shown one at a time from the least
 * telling to the most; the player types the idea. In English, Portuguese
 * and Spanish, each language's clues chosen natively.
 *
 * A model writes a band's rounds and a second, blind pass guesses them: the
 * reviewer is shown each language's clues in order, with no idea, and names
 * the idea itself, saying after which clue it was sure. A round survives
 * only when the reviewer's guess is one the game accepts (`accepts`, as the
 * phone judges a typed line) in every language, it was sure, found nothing
 * to say, and (past Easy) needed more than the first clue. What is left
 * short is the bank's (content/clues.json, copied beside this file by `npm
 * run build`), the same rounds a phone that never reached the network deals.
 */

export const LANGS = ["en", "pt", "es"] as const;
export type Lang = (typeof LANGS)[number];

/** Rounds a band asks, Easy to Insane, and the bank's tier each draws from
 *  (Insane takes the hard tier's tail, so a day never repeats a round). */
export const ROUNDS = [3, 3, 4, 4];
export const TIER = [0, 1, 2, 2];
export const CLUES = 5;
/** Rounds asked of the model a band, so the review has some to turn down. */
const DRAFTS = [5, 5, 6, 6];
const CLUE_MAX = 16;
const LABEL_MAX = 34;
const ACCEPT_MAX = 26;
/** A phrase shorter than this, folded, matches only a line that is it. */
export const CONTAINS_MIN = 4;

export interface Wording {
  /** The idea as it is shown once found. */
  label: string;
  clues: string[];
  /** Phrases a typed line is accepted for (see accepts()). */
  accept: string[];
}

export interface Round {
  id: string;
  en: Wording;
  pt: Wording;
  es: Wording;
}

export interface Day {
  v: 1;
  source: "model" | "bank" | "mixed";
  bands: Round[][];
}

// --- words ---

const FOLD: Record<string, string> = {
  "á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "å": "a",
  "é": "e", "è": "e", "ê": "e", "ë": "e",
  "í": "i", "ì": "i", "î": "i", "ï": "i",
  "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o",
  "ú": "u", "ù": "u", "û": "u", "ü": "u",
  "ç": "c", "ñ": "n", "ý": "y", "ß": "ss", "æ": "ae", "œ": "oe",
};

/** `s` as the game's keyboard could have typed it: lower case, no accents,
 *  letters only (puzzles/clues_state.gd folds the same way). */
export function norm(s: string): string {
  let out = "";
  for (const ch of s.normalize("NFC").toLowerCase()) {
    if (ch >= "a" && ch <= "z") out += ch;
    else if (FOLD[ch] !== undefined) out += FOLD[ch];
  }
  return out;
}

/** Whether a typed line names the idea: it is one of the phrases, folded,
 *  or holds one of CONTAINS_MIN letters or more; a phrase's last "s" may be
 *  left off. puzzles/clues_state.gd accepts exactly the same. */
export function accepts(w: Wording, line: string): boolean {
  const typed = norm(line);
  if (typed === "") return false;
  for (const a of w.accept) {
    const f = norm(a);
    const forms = f.length > CONTAINS_MIN && f.endsWith("s") ? [f, f.slice(0, -1)] : [f];
    for (const form of forms) {
      if (form === "") continue;
      if (typed === form) return true;
      if (form.length >= CONTAINS_MIN && typed.includes(form)) return true;
    }
  }
  return false;
}

// --- the bank ---

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** A tier in the day's order, by the hash of the day and the round's id,
 *  hashed twice (acorn.ts's reason); puzzles/clues_state.gd sorts the same. */
export function ordered(tier: Round[], day: number): Round[] {
  const keyed = tier.map((r) => ({r, k: fnv1a(String(fnv1a(`clues|${day}|${r.id}`)))}));
  keyed.sort((a, b) => a.k - b.k || (a.r.id < b.r.id ? -1 : 1));
  return keyed.map((e) => e.r);
}

/** The bank's day: each band the head of its tier's order, Insane the hard
 *  tier's tail. */
export function bankDay(day: number, tiers: Round[][] = bank.tiers as Round[][]): Round[][] {
  return ROUNDS.map((n, b) => {
    const o = ordered(tiers[TIER[b]] ?? [], day);
    return b === 3 ? o.slice(Math.max(0, o.length - n)) : o.slice(0, n);
  });
}

// --- what a round must be ---

function validWording(w: unknown): w is Wording {
  if (typeof w !== "object" || w === null) return false;
  const x = w as Record<string, unknown>;
  if (typeof x.label !== "string" || x.label.trim() === "" || x.label.length > LABEL_MAX) return false;
  if (!Array.isArray(x.clues) || x.clues.length !== CLUES) return false;
  const seen = new Set<string>();
  for (const c of x.clues) {
    if (typeof c !== "string" || c.trim() === "" || c.length > CLUE_MAX) return false;
    seen.add(norm(c));
  }
  if (seen.size !== CLUES) return false;
  if (!Array.isArray(x.accept) || x.accept.length < 2 || x.accept.length > 12) return false;
  for (const a of x.accept) {
    if (typeof a !== "string" || norm(a).length < 3 || a.length > ACCEPT_MAX) return false;
  }
  // a clue that is itself accepted would give the round away
  return !x.clues.some((c) => accepts(x as unknown as Wording, String(c)));
}

export function validRound(r: unknown): r is Round {
  if (typeof r !== "object" || r === null) return false;
  const x = r as Record<string, unknown>;
  if (typeof x.id !== "string") return false;
  return LANGS.every((l) => validWording(x[l]));
}

// --- the writer ---

const WORDING_SCHEMA = {
  type: "object",
  properties: {
    label: {type: "string"},
    clues: {type: "array", items: {type: "string"}},
    accept: {type: "array", items: {type: "string"}},
  },
  required: ["label", "clues", "accept"],
  additionalProperties: false,
};

const ROUND_SCHEMA = {
  type: "object",
  properties: {en: WORDING_SCHEMA, pt: WORDING_SCHEMA, es: WORDING_SCHEMA},
  required: ["en", "pt", "es"],
  additionalProperties: false,
};

const BAND_SCHEMA = {
  type: "object",
  properties: {rounds: {type: "array", items: ROUND_SCHEMA}},
  required: ["rounds"],
  additionalProperties: false,
};

const WRITER = `You write the daily clue puzzle of a cozy mobile game played \
by families in Brazil, Latin America and the English-speaking world. A round \
hides one idea (a category: things with stripes, kinds of knot, words before \
"house"); five clue words that all belong to it are shown one at a time, and \
the player types the idea as soon as they see it.

What every round must be:
- One clear idea a player can name in a few words once they see it.
- Five clues, every one a plain thing that belongs to the idea: a noun of \
one or two ordinary words, at most 14 characters, never an adjective, a \
description or a riddle ("long nose" and "pours liquid" are not clues), and \
never a word of the idea's own name. They are ordered from the least \
telling (it also belongs to other ideas, so the first clue alone rarely \
gives the idea away) to the most telling (the fifth all but names it).
- Fair to a player anywhere and for all ages: no brands, no people's names, \
nothing violent, political or for adults only.
- Written three times: English (en), Brazilian Portuguese (pt) and neutral \
Latin American Spanish (es), each language's clues chosen natively for the \
idea, never word for word. An idea built on a double meaning or a partner \
word that does not survive translation gets a natural idea of its own in \
that language, of the same difficulty.
- "label": the idea as shown once found, a few words (at most 30 characters).
- "accept": 3 to 8 key words in that language, each of which alone tells \
the idea apart ("farm animals": farm, farmyard, barnyard; never "animals", \
which a wrong line would hold too), with their plurals and common variants \
(spout, spouts). The game accepts a typed line that contains any of them, \
folded to lower-case letters with no accents or spaces, so each is four \
letters or more and unlikely inside a wrong line; a key word of three \
letters is given with the word before it ("con asa", "with lid").`;

const BRIEFS = [
  (n: number) => `${n} easy rounds: everyday ideas a ten-year-old can name, the third clue usually enough.`,
  (n: number) => `${n} rounds of everyday ideas, the first two clues fitting several ideas.`,
  (n: number) => `${n} hard rounds: subtler ideas (a hidden property, a partner word, a shared use), the first three clues misleading.`,
  (n: number) => `${n} hard rounds: subtler ideas (a hidden property, a partner word, a shared use), the first three clues misleading.`,
];

function writerPrompt(day: number, band: number, taken: string[]): string {
  const stale = taken.length === 0 ? "" :
    `\n\nIdeas used lately, not to be used again nor anything close:\n${taken.map((r) => `- ${r}`).join("\n")}`;
  return `Write the clue rounds for day ${day}: ${BRIEFS[band](DRAFTS[band])} No two rounds share an idea.${stale}`;
}

// --- the reviewer ---

const GUESS_SCHEMA = {
  type: "object",
  properties: {
    guesses: {
      type: "array",
      items: {
        type: "object",
        properties: {
          id: {type: "string"},
          lang: {type: "string", enum: [...LANGS]},
          guess: {type: "string"},
          clue: {type: "integer"},
          sure: {type: "boolean"},
          issue: {type: "string", enum: ["none", "arguable", "obscure", "translation", "unsuitable", "giveaway"]},
        },
        required: ["id", "lang", "guess", "clue", "sure", "issue"],
        additionalProperties: false,
      },
    },
  },
  required: ["guesses"],
  additionalProperties: false,
};

const REVIEWER = `You test a family clue puzzle before it is published in \
English, Portuguese and Spanish. Each round is five clue words, shown in \
order, that all belong to one hidden idea (a category). You are not told \
the idea.

For every round in every language: name the idea yourself in a few words of \
that language ("guess"), say after how many clues (1 to 5) you were sure \
("clue"), whether you are sure your idea is the one meant and that every \
clue belongs to it ("sure"), and the one thing wrong with the round, if \
anything ("issue"):
- arguable: the clues fit more than one idea equally well, or a clue does \
not belong.
- obscure: most adults would never name it.
- translation: the language's clues read unnaturally or only work in \
another language.
- unsuitable: not for a family game.
- giveaway: the first clue alone names it.
- none: a good round.

Be strict. An idea you would not stake your name on is not "sure".`;

interface Guess {
  id: string;
  lang: string;
  guess: string;
  clue: number;
  sure: boolean;
  issue: string;
}

function reviewPrompt(rounds: Round[]): string {
  const blocks: string[] = [];
  for (const r of rounds) {
    for (const l of LANGS) {
      blocks.push(`[${r.id}] ${l}: ${r[l].clues.map((c, i) => `${i + 1}) ${c}`).join("  ")}`);
    }
  }
  return `Name the idea of these ${rounds.length} rounds, each in all three languages: ` +
    `one guess a round a language, by its id and language.\n\n${blocks.join("\n")}`;
}

/** The rounds the reviewer named as the game would accept, in every
 *  language, surely, with nothing against them, and past Easy not from the
 *  first clue alone. */
export function passing(rounds: Round[], guesses: Guess[], band: number): Round[] {
  return rounds.filter((r) => {
    const why: string[] = [];
    for (const l of LANGS) {
      const g = guesses.find((x) => x.id === r.id && x.lang === l);
      if (g === undefined) why.push(`${l}: no guess`);
      else if (!accepts(r[l], g.guess)) why.push(`${l}: guessed "${g.guess}"`);
      else if (!g.sure || g.issue !== "none") why.push(`${l}: ${g.sure ? "" : "unsure "}${g.issue}`);
      else if (band > 0 && g.clue <= 1) why.push(`${l}: sure from clue 1`);
    }
    if (why.length > 0) console.error(`clues: ${r.id} turned down (${why.join("; ")}): ${r.en.label}`);
    return why.length === 0;
  });
}

// --- the day ---

/** What a published day says of itself to the next day's writer. */
export function asked(day: unknown): string[] {
  const bands = (day as Day | undefined)?.bands;
  if (!Array.isArray(bands)) return [];
  const out: string[] = [];
  for (const band of bands) {
    if (!Array.isArray(band)) continue;
    for (const r of band) if (typeof r?.en?.label === "string") out.push(r.en.label);
  }
  return out;
}

export async function writeBand(day: number, band: number, taken: string[], prefix = `d${day}b${band}`): Promise<Round[]> {
  const draft = await ask<{rounds: Omit<Round, "id">[]}>({
    system: WRITER,
    prompt: writerPrompt(day, band, taken),
    schema: BAND_SCHEMA,
    role: "write",
  });
  const written = (Array.isArray(draft.rounds) ? draft.rounds : [])
    .map((d, i) => ({id: `${prefix}r${i}`, en: d.en, pt: d.pt, es: d.es}))
    .filter((r: Round): r is Round => {
      const ok = validRound(r as unknown);
      if (!ok) console.error(`clues: ${r.id} not valid: ${JSON.stringify(r.en).slice(0, 200)}`);
      return ok;
    });
  if (written.length === 0) return [];
  const review = await ask<{guesses: Guess[]}>({
    system: REVIEWER,
    prompt: reviewPrompt(written),
    schema: GUESS_SCHEMA,
    role: "review",
  });
  return passing(written, Array.isArray(review.guesses) ? review.guesses : [], band);
}

/**
 * The day to publish. `recent` is the ideas the last days used. Never
 * throws: a band the model could not fill is the bank's, and with no model
 * the whole day is.
 */
export async function makeDay(day: number, recent: string[] = [], _theme: Theme | null = null): Promise<Day> {
  const reserve = bankDay(day);
  if (!available()) return {v: 1, source: "bank", bands: reserve};
  const taken = recent.slice();
  const bands: Round[][] = [];
  let fromBank = 0;
  for (let b = 0; b < ROUNDS.length; b++) {
    // A band short of rounds is asked once more, told what it already has.
    let list: Round[] = [];
    for (let tryNo = 0; tryNo < 2 && list.length < ROUNDS[b]; tryNo++) {
      try {
        const got = await writeBand(day, b, [...taken, ...list.map((r) => r.en.label)], `d${day}b${b}t${tryNo}`);
        list = [...list, ...got];
      } catch (e) {
        console.error(`clues: band ${b} of day ${day} failed, the bank fills it`, e);
      }
    }
    let band: Round[];
    if (list.length >= ROUNDS[b]) {
      band = list.slice(0, ROUNDS[b]);
    } else {
      band = reserve[b];
      fromBank++;
    }
    bands.push(band);
    taken.push(...band.filter((r) => r?.en !== undefined).map((r) => r.en.label));
  }
  const source = fromBank === 0 ? "model" : fromBank === ROUNDS.length ? "bank" : "mixed";
  return {v: 1, source, bands};
}

/** Rounds for the bank's `tier`: `count` reviewed ones, told what the bank
 *  already has. */
export async function bankRounds(tier: number, count: number, taken: string[], id: (n: number) => string): Promise<Round[]> {
  const out: Round[] = [];
  const told = taken.slice();
  const band = [0, 1, 2][tier];
  let round = 0;
  while (out.length < count && round < count) {
    let got: Round[] = [];
    try {
      got = await writeBand(0, band, told.slice(-200), `bank${tier}k${round}`);
    } catch (e) {
      console.error(`clues bank: tier ${tier} round ${round} failed`, e);
    }
    for (const r of got) {
      if (out.length >= count) break;
      out.push({...r, id: id(out.length)});
      told.push(r.en.label);
    }
    round++;
    console.error(`clues bank: tier ${tier}: ${out.length} of ${count} after ${round} rounds`);
  }
  return out;
}
