import {ask, available} from "./generate";
import bank from "./acorn_bank.json";

/**
 * Golden Acorn's day (puzzles/acorn2d.gd): four bands of questions, each
 * with four answers, in English, Portuguese and Spanish.
 *
 * A model writes the day and a second, blind pass reviews it: the reviewer
 * is shown every question with its answers shuffled and unmarked, answers it
 * on its own, and says whether anything about it is arguable, dated or lost
 * in translation. A question survives only when the reviewer picked the
 * answer the writer marked, was sure, and found nothing to say. What is left
 * short is filled from the bank the game ships (content/acorn.json, copied
 * beside this file by `npm run build`), and a day the model could not write
 * at all is the bank's day -- the same one a phone that never reached the
 * network deals itself, so a failed night is not a blank day and not a
 * different day either.
 *
 * The contract of one question is tools/acorn/CONTRACT.md.
 */

export const LANGS = ["en", "pt", "es"] as const;
export type Lang = (typeof LANGS)[number];

export const CATS = ["nature", "science", "geography", "history", "arts",
  "food", "sports", "words", "everyday"];

export interface Wording {
  q: string;
  right: string;
  wrong: string[];
  why: string;
}

export interface Question {
  id: string;
  cat: string;
  en: Wording;
  pt: Wording;
  es: Wording;
}

export interface Day {
  v: 1;
  /** Where the questions came from: all the model's, all the bank's, or both. */
  source: "model" | "bank" | "mixed";
  bands: Question[][];
}

/** Questions a band asks: Easy, Medium, Hard, and the Climb. */
export const ASKS = [7, 7, 7, 10];
/** How many of each tier the bank's Climb takes, easy to expert. */
export const CLIMB = [3, 3, 2, 2];
/** How many the model is asked for, so the review has some to turn down. */
const DRAFTS = [9, 9, 9, 13];

/** The longest a line may be and still fit the card (the contract's limits,
 *  with a little grace for a model that counts loosely). */
const Q_MAX = 120;
const ANSWER_MAX = 30;
const WHY_MAX = 130;

// --- the bank ---

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** A tier in the day's order: by the hash of the day and the question's id.
 *  puzzles/acorn_state.gd sorts the same way. */
export function ordered(tier: Question[], day: number): Question[] {
  // Hashed twice: FNV's last byte barely stirs the top bits, so ids that
  // differ in their last digit would otherwise sort side by side.
  const keyed = tier.map((q) => ({q, k: fnv1a(String(fnv1a(`acorn|${day}|${q.id}`)))}));
  keyed.sort((a, b) => a.k - b.k || (a.q.id < b.q.id ? -1 : 1));
  return keyed.map((e) => e.q);
}

/** The bank's day: each band the head of its tier's order, and the Climb the
 *  tail of every tier's, so no question is asked twice in a day. */
export function bankDay(day: number, tiers: Question[][] = bank.tiers as Question[][]): Question[][] {
  const orders = tiers.map((t) => ordered(t, day));
  const bands: Question[][] = [];
  for (let b = 0; b < 3; b++) bands.push(orders[b].slice(0, ASKS[b]));
  const climb: Question[] = [];
  for (let t = 0; t < CLIMB.length; t++) {
    const o = orders[t];
    climb.push(...o.slice(o.length - CLIMB[t]));
  }
  bands.push(climb);
  return bands;
}

// --- what a question must be ---

function validWording(w: unknown): w is Wording {
  if (typeof w !== "object" || w === null) return false;
  const x = w as Record<string, unknown>;
  if (typeof x.q !== "string" || x.q.trim() === "" || x.q.length > Q_MAX) return false;
  if (typeof x.why !== "string" || x.why.length > WHY_MAX) return false;
  if (!Array.isArray(x.wrong) || x.wrong.length !== 3) return false;
  const answers = [x.right, ...x.wrong];
  const seen = new Set<string>();
  for (const a of answers) {
    if (typeof a !== "string" || a.trim() === "" || a.length > ANSWER_MAX) return false;
    seen.add(a.trim().toLowerCase());
  }
  return seen.size === 4;
}

export function validQuestion(q: unknown): q is Question {
  if (typeof q !== "object" || q === null) return false;
  const x = q as Record<string, unknown>;
  if (typeof x.id !== "string" || typeof x.cat !== "string") return false;
  return LANGS.every((l) => validWording(x[l]));
}

// --- the writer ---

const WORDING_SCHEMA = {
  type: "object",
  properties: {
    q: {type: "string"},
    right: {type: "string"},
    wrong: {type: "array", items: {type: "string"}},
    why: {type: "string"},
  },
  required: ["q", "right", "wrong", "why"],
  additionalProperties: false,
};

const QUESTION_SCHEMA = {
  type: "object",
  properties: {
    cat: {type: "string", enum: CATS},
    en: WORDING_SCHEMA,
    pt: WORDING_SCHEMA,
    es: WORDING_SCHEMA,
  },
  required: ["cat", "en", "pt", "es"],
  additionalProperties: false,
};

const BAND_SCHEMA = {
  type: "object",
  properties: {
    questions: {type: "array", items: QUESTION_SCHEMA},
  },
  required: ["questions"],
  additionalProperties: false,
};

const WRITER = `You write the daily quiz of a cozy mobile game played by \
families in Brazil, Latin America and the English-speaking world. Every \
question has four answers and exactly one of them is right.

What every question must be:
- A solid, well-documented fact, right beyond argument, and still right in \
ten years: no records that fall, nothing "current", no populations or prices.
- Fair to a player anywhere: most questions are about the wide world, and a \
few each day have a Brazilian or Latin American flavour.
- For all ages: nothing violent, political, sexual, about religious doctrine \
or built around a brand.
- Plainly worded. A question is hard because the knowledge is rare, never \
because the wording is a trap. No "all of the above", no "which is NOT".
- Three wrong answers of the same kind as the right one, plausible to \
somebody who does not know, and wrong beyond argument. The right answer must \
not stand out by its length or its form.
- Written three times: English (en), Brazilian Portuguese (pt) and neutral \
Latin American Spanish (es), each in natural words rather than word for \
word, with the three wrong answers in the same order in all three.
- Short enough for a phone: a question at most 110 characters, an answer at \
most 26, and "why" one friendly sentence of at most 110 that teaches \
something about the right answer instead of repeating it.

The game shuffles the answers itself.`;

interface Draft {
  cat: string;
  en: Wording;
  pt: Wording;
  es: Wording;
}

/** What each band is asked for. */
const BRIEFS = [
  (n: number) => `${n} easy questions: ones nine adults in ten and most ten-year-olds can answer.`,
  (n: number) => `${n} medium questions of school general knowledge: about half of adults know each.`,
  (n: number) => `${n} hard questions: ones one adult in four knows, and a keen quiz player usually does.`,
  (n: number) => `${n} questions in rising order, a quiz show's ladder: the first three easy, ` +
    "then steadily harder, and the last three what one adult in ten knows.",
];

/** A band a request: a cheap model's answer has a low ceiling, and a band
 *  that fails costs the day one band and not four. `taken` is what the last
 *  days asked and what today's earlier bands already have. */
function writerPrompt(day: number, band: number, taken: string[]): string {
  const stale = taken.length === 0 ? "" :
    `\n\nAlready asked, so not to be asked again nor anything close to it:\n${taken.map((r) => `- ${r}`).join("\n")}`;
  return `Write part of the quiz for day ${day}: ${BRIEFS[band](DRAFTS[band])}

Spread them over these subjects, no more than two on one: ${CATS.join(", ")}. \
No fact may be asked twice.${stale}`;
}

// --- the reviewer ---

const REVIEW_SCHEMA = {
  type: "object",
  properties: {
    verdicts: {
      type: "array",
      items: {
        type: "object",
        properties: {
          id: {type: "string"},
          pick: {type: "string", enum: ["A", "B", "C", "D"]},
          sure: {type: "boolean"},
          issue: {
            type: "string",
            enum: ["none", "arguable", "dated", "translation", "unsuitable", "giveaway"],
          },
        },
        required: ["id", "pick", "sure", "issue"],
        additionalProperties: false,
      },
    },
  },
  required: ["verdicts"],
  additionalProperties: false,
};

const REVIEWER = `You are the fact checker of a family quiz, and the last \
reader before it is published to players in English, Portuguese and Spanish. \
You are shown questions with four answers each and are not told which answer \
the writer meant.

For every question: answer it yourself from what you know ("pick"), say \
whether you are sure that answer is right and the other three are wrong \
("sure"), and name the one thing wrong with the question, if anything \
("issue"):
- arguable: more than one answer can be defended, or none is quite right, or \
the wording is unclear.
- dated: the answer could change with time.
- translation: the Portuguese or the Spanish does not ask the same thing or \
does not offer the same answers as the English, or reads unnaturally.
- unsuitable: not for a family game played by all ages.
- giveaway: the right answer stands out without knowing anything.
- none: a good question.

Be strict. A question you would not stake your name on is not "sure".`;

interface Verdict {
  id: string;
  pick: string;
  sure: boolean;
  issue: string;
}

/** The order a question's four answers are shown in to the reviewer: a
 *  shuffle of [right, wrong...] by the question's id, so the right one's
 *  place says nothing. */
export function shownOrder(id: string): number[] {
  const order = [0, 1, 2, 3];
  let s = fnv1a(String(fnv1a(id)));
  for (let i = 3; i > 0; i--) {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    const j = (s >>> 16) % (i + 1);  // an LCG's low bits barely change
    [order[i], order[j]] = [order[j], order[i]];
  }
  return order;
}

function reviewPrompt(questions: Question[]): string {
  const blocks = questions.map((q) => {
    const order = shownOrder(q.id);
    const lines = [`[${q.id}]`];
    for (const l of LANGS) {
      const answers = [q[l].right, ...q[l].wrong];
      const shown = order.map((k, i) => `${"ABCD"[i]}) ${answers[k]}`).join("  ");
      lines.push(`${l}: ${q[l].q}\n    ${shown}\n    note: ${q[l].why}`);
    }
    return lines.join("\n");
  });
  return `Review these ${questions.length} questions. One verdict each, by its id.\n\n${blocks.join("\n\n")}`;
}

/** The questions the reviewer answered as the writer meant, surely, with
 *  nothing to say against them. */
export function passing(questions: Question[], verdicts: Verdict[]): Question[] {
  const by = new Map(verdicts.map((v) => [v.id, v]));
  return questions.filter((q) => {
    const v = by.get(q.id);
    if (v === undefined || !v.sure || v.issue !== "none") return false;
    return shownOrder(q.id)["ABCD".indexOf(v.pick)] === 0;
  });
}

// --- the day ---

/** Cuts a rising list down to `n` from its middle, so it keeps both its easy
 *  foot and its hard head. */
function thinned(list: Question[], n: number): Question[] {
  const out = list.slice();
  while (out.length > n) out.splice(Math.floor(out.length / 2), 1);
  return out;
}

/** What a published day says of itself to the next day's writer. */
export function asked(day: unknown): string[] {
  const bands = (day as Day | undefined)?.bands;
  if (!Array.isArray(bands)) return [];
  const out: string[] = [];
  for (const band of bands) {
    if (!Array.isArray(band)) continue;
    for (const q of band) {
      if (validQuestion(q)) out.push(`${q.en.q} (${q.en.right})`);
    }
  }
  return out;
}

/** One band from the model: written, checked against the contract, then
 *  reviewed blind. Throws when the model could not be asked. */
async function writeBand(day: number, band: number, taken: string[]): Promise<Question[]> {
  const draft = await ask<{questions: Draft[]}>({
    system: WRITER,
    prompt: writerPrompt(day, band, taken),
    schema: BAND_SCHEMA,
    role: "write",
  });
  const written = (Array.isArray(draft.questions) ? draft.questions : [])
    .map((d, i) => ({id: `d${day}b${band}q${i}`, cat: d.cat, en: d.en, pt: d.pt, es: d.es}))
    .filter(validQuestion);
  if (written.length === 0) return [];
  const review = await ask<{verdicts: Verdict[]}>({
    system: REVIEWER,
    prompt: reviewPrompt(written),
    schema: REVIEW_SCHEMA,
    role: "review",
  });
  return passing(written, Array.isArray(review.verdicts) ? review.verdicts : []);
}

/**
 * The day to publish. `recent` is what the last days asked (asked()). Never
 * throws: whatever goes wrong with the model, the bank answers -- for the
 * band that failed, and for the whole day when there is no model at all.
 */
export async function makeDay(day: number, recent: string[] = []): Promise<Day> {
  const reserve = bankDay(day);
  if (!available()) return {v: 1, source: "bank", bands: reserve};
  const taken = recent.slice();
  const bands: Question[][] = [];
  const kept: number[] = [];
  let fromBank = 0;
  let fromModel = 0;
  for (let b = 0; b < ASKS.length; b++) {
    const n = ASKS[b];
    let list: Question[] = [];
    try {
      list = await writeBand(day, b, taken);
    } catch (e) {
      console.error(`acorn: band ${b} of day ${day} failed, the bank fills it`, e);
    }
    kept.push(list.length);
    let band: Question[];
    if (list.length >= n) {
      band = b === 3 ? thinned(list, n) : list.slice(0, n);
      fromModel += n;
    } else if (b === 3) {
      // The Climb has to rise, and two hands' questions spliced together
      // would not, so a short Climb is the bank's whole.
      band = reserve[b];
      fromBank += n;
    } else {
      const fill = reserve[b].slice(0, n - list.length);
      band = [...list, ...fill];
      fromBank += fill.length;
      fromModel += list.length;
    }
    bands.push(band);
    for (const q of band) taken.push(`${q.en.q} (${q.en.right})`);
  }
  console.log(`acorn: day ${day}, kept ${kept.join("/")}, ${fromBank} from the bank`);
  return {v: 1, source: fromBank === 0 ? "model" : fromModel === 0 ? "bank" : "mixed", bands};
}
