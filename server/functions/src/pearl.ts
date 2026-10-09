import {ask, available} from "./generate";
import bank from "./pearl_bank.json";

/**
 * Pearl Dive's day (puzzles/pearl2d.gd): four bands of prompts. A prompt
 * names a kind of thing and holds every answer the game knows for it, each
 * with how rare it is and how it is spelled in English, Portuguese and
 * Spanish. One answer of every prompt is its Pearl.
 *
 * The second game whose day a model writes, on the contract acorn.ts set
 * (docs/agents/turns-and-backend.md, "A day written by a model"). What is
 * its own: the day is asked for a prompt a request, several at once, after
 * one request that proposes the day's kinds; and the review does not answer
 * a question, it reads a list -- a second model, not told the tiers, says
 * which answers do not belong, how rare it finds each, and which well-known
 * ones the writer left out. A prompt that does not survive is the bank's
 * (content/pearl.json, copied beside this file by `npm run build`), and a
 * day the model could not write at all is the bank's day, the same one a
 * phone that never reached the network deals itself.
 *
 * How rare an answer is is written, not counted from what players type: a
 * bank has to work on a phone that never reached anybody.
 *
 * The contract of one prompt is tools/pearl/CONTRACT.md.
 */

export const LANGS = ["en", "pt", "es"] as const;
export type Lang = (typeof LANGS)[number];

export interface Answer {
  /** 0 what almost everybody says first, 1 well known, 2 rare, 3 deep, 4 the Pearl. */
  t: number;
  /** The name as it is shown, then every other spelling that is accepted. */
  en: string[];
  pt: string[];
  es: string[];
}

export interface Prompt {
  id: string;
  /** 0 everyday, 1 school general knowledge, 2 narrower. */
  level: number;
  en: {ask: string};
  pt: {ask: string};
  es: {ask: string};
  answers: Answer[];
}

export interface Day {
  v: 1;
  /** Where the prompts came from: all the model's, all the bank's, or both. */
  source: "model" | "bank" | "mixed";
  bands: Prompt[][];
}

/** Prompts a band asks: Easy, Medium, Hard, and One Breath. */
export const ASKS = [5, 6, 7, 8];
/** How many of each level One Breath takes, easy to hard. */
export const BREATH = [3, 3, 2];
export const PEARL = 4;

/** The limits a prompt is held to (puzzles/pearl_state.gd has the same). */
const ASK_MAX = 64;
const NAME_MAX = 26;
const FORM_MIN = 2;
const FORM_MAX = 22;
const ANSWERS_MIN = 14;
/** A list longer than this is cut from its rare end: the document is read
 *  whole by a phone. */
const ANSWERS_MAX = 70;
/** How many prompts are with the model at once. */
const POOL = 5;

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
 *  letters only. puzzles/pearl_state.gd folds the same way. */
export function norm(s: string): string {
  let out = "";
  for (const ch of s.normalize("NFC").toLowerCase()) {
    if (ch >= "a" && ch <= "z") out += ch;
    else if (FOLD[ch] !== undefined) out += FOLD[ch];
  }
  return out;
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

function bankLevels(): Prompt[][] {
  return (bank as unknown as {levels: Prompt[][]}).levels;
}

/** A level in the day's order: by the hash of the day and the prompt's id,
 *  hashed twice (acorn.ts's reason). puzzles/pearl_state.gd sorts the same
 *  way. */
export function ordered(level: Prompt[], day: number): Prompt[] {
  const keyed = level.map((p) => ({p, k: fnv1a(String(fnv1a(`pearl|${day}|${p.id}`)))}));
  keyed.sort((a, b) => a.k - b.k || (a.p.id < b.p.id ? -1 : 1));
  return keyed.map((e) => e.p);
}

/** The bank's day: each band the head of its level's order, and One Breath
 *  the tail of every level's, so no prompt is asked twice in a day. */
export function bankDay(day: number, levels: Prompt[][] = bankLevels()): Prompt[][] {
  const orders = levels.map((l) => ordered(l, day));
  const bands: Prompt[][] = [];
  for (let b = 0; b < 3; b++) bands.push((orders[b] ?? []).slice(0, ASKS[b]));
  const breath: Prompt[] = [];
  for (let l = 0; l < BREATH.length; l++) {
    const o = orders[l] ?? [];
    breath.push(...o.slice(Math.max(0, o.length - BREATH[l])));
  }
  bands.push(breath);
  return bands;
}

// --- what a prompt must be ---

function validAsk(w: unknown): boolean {
  if (typeof w !== "object" || w === null) return false;
  const a = (w as Record<string, unknown>).ask;
  return typeof a === "string" && a.trim() !== "" && a.length <= ASK_MAX;
}

/** Whether a spelling can be shown and typed: letters the keyboard has, no
 *  numerals, within the line. */
function validForm(f: unknown): f is string {
  if (typeof f !== "string" || /[0-9]/.test(f)) return false;
  const n = norm(f);
  return n.length >= FORM_MIN && n.length <= FORM_MAX;
}

/** Words a name may lose from either end with its kind's word. */
const SMALL = new Set(["of", "the", "de", "do", "da", "dos", "das", "del", "la", "el", "los", "las"]);

const ARTICLE: Record<Lang, RegExp> = {
  en: /^(the|an|a)\s+/i,
  pt: /^(os|as|uma|um|o|a)\s+/i,
  es: /^(los|las|una|un|el|la)\s+/i,
};

/**
 * The kind's own word is not asked of a player: where a word stands in the
 * names of a third of a list ("Lake Titicaca", "Lake Como"; "Onion soup"),
 * every name that has it is also taken without it ("Titicaca", "Onion"),
 * unless that is already another answer's spelling; and a name that opens
 * with an article is taken without it. The phone matches whole
 * names only, so this is where the short one is made.
 */
function bareNames(answers: Answer[], seen: Record<Lang, Set<string>>): void {
  for (const l of LANGS) {
    // A title is also taken without the article it opens with ("The Scream").
    for (const a of answers) {
      for (const f of a[l].slice()) {
        const cut = f.match(ARTICLE[l]);
        if (cut === null) continue;
        const bare = f.slice(cut[0].length);
        const n = norm(bare);
        if (n.length < 3 || seen[l].has(n)) continue;
        seen[l].add(n);
        a[l].push(bare);
      }
    }
    const count = new Map<string, number>();
    const words = (f: string) => f.split(/[\s-]+/).filter((w) => w !== "");
    for (const a of answers) {
      const mine = new Set(words(a[l][0]).map(norm));
      if (mine.size < 2) continue;
      for (const w of mine) count.set(w, (count.get(w) ?? 0) + 1);
    }
    const least = Math.max(4, answers.length * 0.3);
    const common = new Set([...count].filter(([w, n]) => w.length >= 3 && n >= least).map(([w]) => w));
    if (common.size === 0) continue;
    for (const a of answers) {
      for (const f of a[l].slice()) {
        const all = words(f);
        const left = all.filter((w) => !common.has(norm(w)));
        if (left.length === all.length) continue;
        while (left.length > 0 && SMALL.has(norm(left[0]))) left.shift();
        while (left.length > 0 && SMALL.has(norm(left[left.length - 1]))) left.pop();
        const bare = left.join(" ");
        const n = norm(bare);
        if (n.length < 3 || n.length > FORM_MAX || seen[l].has(n)) continue;
        seen[l].add(n);
        a[l].push(bare);
      }
    }
  }
}

/**
 * A prompt as the contract has it, made out of whatever the model wrote, or
 * null when there is not one in it. Spellings that cannot be typed go; a
 * spelling two answers share is kept by the commoner answer and dropped
 * from the rarer; an answer left with nothing to call it in some language
 * goes; exactly one Pearl is left standing.
 */
export function cleaned(p: unknown): Prompt | null {
  if (typeof p !== "object" || p === null) return null;
  const x = p as Record<string, unknown>;
  if (typeof x.id !== "string" || !LANGS.every((l) => validAsk(x[l]))) return null;
  if (!Array.isArray(x.answers)) return null;
  const level = Math.min(2, Math.max(0, Math.trunc(Number(x.level) || 0)));
  const drafts = x.answers
    .filter((a): a is Record<string, unknown> => typeof a === "object" && a !== null)
    .map((a, at) => ({a, at, t: Math.trunc(Number(a.t))}))
    .filter((d) => d.t >= 0 && d.t <= PEARL);
  // The commoner answer first: it is the one that keeps a shared spelling.
  drafts.sort((m, n) => m.t - n.t || m.at - n.at);
  const seen: Record<Lang, Set<string>> = {en: new Set(), pt: new Set(), es: new Set()};
  const answers: Answer[] = [];
  for (const d of drafts) {
    const forms = {} as Record<Lang, string[]>;
    let whole = true;
    for (const l of LANGS) {
      const kept: string[] = [];
      const mine = new Set<string>();
      for (const f of Array.isArray(d.a[l]) ? d.a[l] as unknown[] : []) {
        if (!validForm(f)) continue;
        const text = f.normalize("NFC").trim().replace(/\s+/g, " ");
        const n = norm(text);
        if (seen[l].has(n) || mine.has(n)) continue;
        // What is shown is the first spelling, so the first must fit the plate.
        if (kept.length === 0 && text.length > NAME_MAX) continue;
        mine.add(n);
        // The shown name starts with a capital, whoever wrote it.
        kept.push(kept.length === 0 ? text.charAt(0).toUpperCase() + text.slice(1) : text);
      }
      if (kept.length === 0) whole = false;
      forms[l] = kept;
    }
    if (!whole) continue;
    for (const l of LANGS) for (const f of forms[l]) seen[l].add(norm(f));
    answers.push({t: d.t, en: forms.en, pt: forms.pt, es: forms.es});
  }
  bareNames(answers, seen);
  // One Pearl: the first that was named one, or the first deep answer.
  let pearl = answers.findIndex((a) => a.t === PEARL);
  if (pearl < 0) pearl = answers.findIndex((a) => a.t === PEARL - 1);
  if (pearl < 0) return null;
  answers.forEach((a, i) => {
    if (i === pearl) a.t = PEARL;
    else if (a.t === PEARL) a.t = PEARL - 1;
  });
  answers.sort((m, n) => m.t - n.t);
  while (answers.length > ANSWERS_MAX) answers.splice(answers.length - 2, 1);
  const out: Prompt = {
    id: x.id,
    level,
    en: {ask: (x.en as {ask: string}).ask.trim()},
    pt: {ask: (x.pt as {ask: string}).ask.trim()},
    es: {ask: (x.es as {ask: string}).ask.trim()},
    answers,
  };
  return validPrompt(out) ? out : null;
}

/** The contract, as the phone checks it (State.valid) and a little more:
 *  no spelling shared by two answers, and something on every rung, since a
 *  dive with nothing between the obvious and the Pearl is not one. */
export function validPrompt(p: unknown): p is Prompt {
  if (typeof p !== "object" || p === null) return false;
  const x = p as Record<string, unknown>;
  if (typeof x.id !== "string" || !LANGS.every((l) => validAsk(x[l]))) return false;
  if (!Array.isArray(x.answers) || x.answers.length < ANSWERS_MIN) return false;
  const rungs = [0, 0, 0, 0, 0];
  const seen: Record<Lang, Set<string>> = {en: new Set(), pt: new Set(), es: new Set()};
  for (const a of x.answers as unknown[]) {
    if (typeof a !== "object" || a === null) return false;
    const y = a as Record<string, unknown>;
    if (typeof y.t !== "number" || !Number.isInteger(y.t) || y.t < 0 || y.t > PEARL) return false;
    rungs[y.t]++;
    for (const l of LANGS) {
      const forms = y[l];
      if (!Array.isArray(forms) || forms.length === 0 || !forms.every(validForm)) return false;
      if ((forms[0] as string).length > NAME_MAX) return false;
      for (const f of forms as string[]) {
        const n = norm(f);
        if (seen[l].has(n)) return false;
        seen[l].add(n);
      }
    }
  }
  return rungs[PEARL] === 1 && rungs.slice(0, PEARL).every((n) => n >= 1);
}

// --- the day's kinds ---

const KINDS_SCHEMA = {
  type: "object",
  properties: {
    kinds: {
      type: "array",
      items: {
        type: "object",
        properties: {
          level: {type: "integer", enum: [0, 1, 2]},
          en: {type: "string"},
          pt: {type: "string"},
          es: {type: "string"},
        },
        required: ["level", "en", "pt", "es"],
        additionalProperties: false,
      },
    },
  },
  required: ["kinds"],
  additionalProperties: false,
};

const GAME = `The game: a cozy mobile game played by families in Brazil, \
Latin America and the English-speaking world. It names a kind of thing -- \
"A kind of cheese" -- and the player has a few seconds to type one thing of \
that kind on a letters-only keyboard. Any right answer counts, and the rarer \
the answer the more it is worth: the first thing everybody thinks of is \
worth little, and one special rare answer, the Pearl, is worth the most.`;

const KINDS_WRITER = `${GAME}

You choose the kinds. What every kind must be:
- A set whose members are beyond argument: "A country in Africa", "A string \
instrument", "A breed of dog". Never an opinion or a loose association ("A \
scary animal", "Something in a kitchen").
- Rich: at least thirty members that ordinary people can name, from a few \
that everybody says to some that only a keen player knows.
- About things in the world, never about spelling or language ("a word that \
starts with B" is forbidden), so that it is the same kind in English, \
Portuguese and Spanish, and its members have names in all three.
- Members named in letters: nothing whose members are numbers, dates or \
names with numerals in them.
- Timeless and for all ages: nothing "current", no brands, no living \
celebrities, nothing violent, political, sexual or about religious doctrine.
- Written as a short noun phrase of at most 50 characters, in English (en), \
Brazilian Portuguese (pt) and neutral Latin American Spanish (es), each in \
natural words.

Three levels:
- 0: broad everyday kinds a ten-year-old can answer (a fruit, a farm animal, \
something to wear).
- 1: school general knowledge (a musical instrument, a capital city in \
Europe, a bone of the human body).
- 2: narrower, for a keen quiz player (a chemical element, a river of South \
America, a play by Shakespeare) -- narrow, but still with thirty nameable \
members.`;

interface Kind {
  level: number;
  en: string;
  pt: string;
  es: string;
}

function validKind(k: unknown): k is Kind {
  if (typeof k !== "object" || k === null) return false;
  const x = k as Record<string, unknown>;
  if (typeof x.level !== "number" || ![0, 1, 2].includes(x.level)) return false;
  return LANGS.every((l) => typeof x[l] === "string" && (x[l] as string).trim() !== "" &&
    (x[l] as string).length <= ASK_MAX);
}

/** Kinds for the levels asked, `want[level]` of each and no fewer when the
 *  model obliges; none that `taken` (English asks) already has. */
async function proposeKinds(what: string, want: number[], taken: string[]): Promise<Kind[][]> {
  const stale = taken.length === 0 ? "" :
    `\n\nAlready asked, so not to be proposed again nor anything close to it:\n${taken.map((t) => `- ${t}`).join("\n")}`;
  const asks = want.map((n, l) => n > 0 ? `${n} of level ${l}` : "").filter((s) => s !== "").join(", ");
  const request = {
    system: KINDS_WRITER,
    prompt: `Propose the kinds for ${what}: ${asks} -- exactly that many and no more, a short list. ` +
      "Spread them over the wide world -- nature, food, geography, the arts, science, sports, " +
      `everyday life, history -- with no two alike.${stale}`,
    schema: KINDS_SCHEMA,
    role: "write" as const,
  };
  // Asked twice when it must be: the day hangs on this one answer, and the
  // writer has been seen to run on to the token ceiling with a list that
  // never ends (twice in five askings while the bank was written).
  let got: {kinds: unknown[]};
  try {
    got = await ask<{kinds: unknown[]}>(request);
  } catch (e) {
    console.error("pearl: the kinds failed once, asking again", e instanceof Error ? e.message : e);
    got = await ask<{kinds: unknown[]}>(request);
  }
  const have = new Set(taken.map(norm));
  const out: Kind[][] = [[], [], []];
  for (const k of Array.isArray(got.kinds) ? got.kinds : []) {
    if (!validKind(k) || have.has(norm(k.en))) continue;
    have.add(norm(k.en));
    out[k.level].push(k);
  }
  return out;
}

// --- the writer ---

const FORMS = {type: "array", items: {type: "string"}};

const ANSWER_SCHEMA = {
  type: "object",
  properties: {
    t: {type: "integer", enum: [0, 1, 2, 3, 4]},
    en: FORMS,
    pt: FORMS,
    es: FORMS,
  },
  required: ["t", "en", "pt", "es"],
  additionalProperties: false,
};

const LIST_SCHEMA = {
  type: "object",
  properties: {
    answers: {type: "array", items: ANSWER_SCHEMA},
  },
  required: ["answers"],
  additionalProperties: false,
};

const WRITER = `${GAME}

You are given one kind and write the list of answers the game will accept \
for it. The list is the judge: a player who types a right answer that is not \
on it is told it is wrong, so the list must hold every member an ordinary \
player might type -- 40 to 55 answers, more when the kind is rich -- and \
nothing that is not a member beyond argument.

Every answer has a tier, "t", for how rare an answer it is among adults \
across those countries:
- 0: what almost everybody says first. Three to six of them.
- 1: well known; many players would say it.
- 2: rare; one player in ten thinks of it.
- 3: deep; only a keen player names it, yet it is a real, checkable member \
that such a player would recognise.
- 4: the Pearl. Exactly one: a deep answer with some charm to it, one that a \
few players will be delighted to find. Not the most obscure member there is.
Have plenty on every tier from 1 to 3.

Every answer is spelled three times: "en" (English), "pt" (Brazilian \
Portuguese) and "es" (neutral Latin American Spanish). Each is a list: first \
the name most people use in that language, written as it should be shown \
(a capital first letter, accents where they belong, at most 24 characters), \
then any other name or spelling players really use for the same thing \
("Eggplant", "Aubergine"; "Hippopotamus", "Hippo"). A thing with the same \
name in all three languages is written the same three times. The game \
already ignores capitals, accents, spaces and hyphens and forgives a slip of \
one letter, so do not list those as other spellings.

Never: a numeral in a name, a brand, two answers that are the same thing, \
an answer whose name in one language is another answer's name, or a member \
that could be argued about.`;

function writerPrompt(k: Kind): string {
  return `The kind (level ${k.level}):\n- en: ${k.en}\n- pt: ${k.pt}\n- es: ${k.es}\n\nWrite its list.`;
}

// --- the reviewer ---

const REVIEW_SCHEMA = {
  type: "object",
  properties: {
    kind: {type: "string", enum: ["good", "unclear", "unsuitable", "translation"]},
    verdicts: {
      type: "array",
      items: {
        type: "object",
        properties: {
          n: {type: "integer"},
          issue: {type: "string", enum: ["none", "not_a_member", "arguable", "translation", "unsuitable"]},
          t: {type: "integer", enum: [0, 1, 2, 3]},
        },
        required: ["n", "issue", "t"],
        additionalProperties: false,
      },
    },
    missing: {
      type: "array",
      items: {
        type: "object",
        properties: {
          t: {type: "integer", enum: [0, 1, 2]},
          en: FORMS,
          pt: FORMS,
          es: FORMS,
        },
        required: ["t", "en", "pt", "es"],
        additionalProperties: false,
      },
    },
  },
  required: ["kind", "verdicts", "missing"],
  additionalProperties: false,
};

const REVIEWER = `${GAME}

You are the checker, and the last reader before a list is published. You \
are shown one kind and the numbered answers a writer listed for it, each as \
its English / Portuguese / Spanish name. You are not told how rare the \
writer thought each one.

First the kind itself ("kind"): good; unclear (its members can be argued \
about, or the three languages do not ask the same thing); unsuitable (not \
for a family game); translation (the Portuguese or Spanish reads wrongly).

Then one verdict for every answer, by its number ("n"):
- "issue": none; not_a_member (it is not of this kind); arguable (it can be \
defended and attacked); translation (the Portuguese or the Spanish name is \
wrong, or is a different thing); unsuitable.
- "t": how rare an answer you judge it to be among ordinary adults in \
Brazil, Latin America and the English-speaking world: 0 what almost \
everybody says first, 1 well known, 2 rare (one player in ten thinks of \
it), 3 deep (only a keen player names it).

Then "missing": every well-known member of the kind that the list does not \
have -- the ones a player would be cheated to see refused -- each with your \
tier (0, 1 or 2) and its names in "en", "pt" and "es", the name most people \
use first, then other names really in use. An empty list when nothing is \
missing. No numerals, no brands.

Be strict about membership: an answer you would not stake your name on is \
not "none".`;

interface Verdict {
  n: number;
  issue: string;
  t: number;
}

interface Review {
  kind: string;
  verdicts: Verdict[];
  missing: unknown[];
}

/** The order a prompt's answers are shown in to the reviewer: a shuffle by
 *  its id, so the writer's order (commonest first) says nothing. */
export function shownOrder(id: string, n: number): number[] {
  const order = Array.from({length: n}, (_, i) => i);
  let s = fnv1a(String(fnv1a(id)));
  for (let i = n - 1; i > 0; i--) {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    const j = (s >>> 16) % (i + 1);  // an LCG's low bits barely change
    [order[i], order[j]] = [order[j], order[i]];
  }
  return order;
}

function reviewPrompt(p: Prompt, order: number[]): string {
  const lines = order.map((k, i) => {
    const a = p.answers[k];
    return `${i + 1}. ${a.en.join(" = ")} / ${a.pt.join(" = ")} / ${a.es.join(" = ")}`;
  });
  return `The kind:\n- en: ${p.en.ask}\n- pt: ${p.pt.ask}\n- es: ${p.es.ask}\n\n` +
    `Its ${lines.length} answers:\n${lines.join("\n")}`;
}

/**
 * A written list after its review. An answer the reviewer found something
 * against, or said nothing of, goes. A tier the reviewer puts two or more
 * steps away moves one step toward the reviewer's: two readings of "rare"
 * differ, and the writer's is the one that saw the whole list as a ladder.
 * What the reviewer missed is added at the reviewer's tier. The Pearl is
 * the writer's unless it went, or the reviewer finds it commonplace; then
 * the first deep answer is the Pearl (cleaned() promotes it).
 */
export function merged(p: Prompt, order: number[], review: Review): Prompt | null {
  if (review.kind !== "good") return null;
  const by = new Map((Array.isArray(review.verdicts) ? review.verdicts : []).map((v) => [v.n, v]));
  const answers: unknown[] = [];
  order.forEach((k, i) => {
    const v = by.get(i + 1);
    if (v === undefined || v.issue !== "none") return;
    const a = p.answers[k];
    let t = a.t;
    if (t === PEARL) {
      if (v.t <= 1) t = 2;
    } else if (Math.abs(v.t - t) >= 2) {
      t += Math.sign(v.t - t);
    }
    answers.push({...a, t});
  });
  for (const m of Array.isArray(review.missing) ? review.missing : []) {
    if (typeof m !== "object" || m === null) continue;
    const t = Math.trunc(Number((m as Record<string, unknown>).t));
    answers.push({...m, t: Math.min(2, Math.max(0, Number.isFinite(t) ? t : 1))});
  }
  return cleaned({...p, answers});
}

/** One prompt from the model: its list written, checked against the
 *  contract, then reviewed. Null when it did not survive; throws when the
 *  model could not be asked. */
async function writePrompt(id: string, k: Kind): Promise<Prompt | null> {
  const draft = await ask<{answers: unknown[]}>({
    system: WRITER,
    prompt: writerPrompt(k),
    schema: LIST_SCHEMA,
    role: "write",
  });
  const written = cleaned({
    id, level: k.level, en: {ask: k.en}, pt: {ask: k.pt}, es: {ask: k.es},
    answers: Array.isArray(draft.answers) ? draft.answers : [],
  });
  if (written === null) return null;
  const order = shownOrder(id, written.answers.length);
  const review = await ask<Review>({
    system: REVIEWER,
    prompt: reviewPrompt(written, order),
    schema: REVIEW_SCHEMA,
    role: "review",
  });
  return merged(written, order, review);
}

/** `jobs` run `POOL` at a time, each answering its own slot; a job that
 *  throws leaves null. */
async function pooled<T>(jobs: (() => Promise<T | null>)[]): Promise<(T | null)[]> {
  const out: (T | null)[] = jobs.map(() => null);
  let next = 0;
  const worker = async () => {
    while (next < jobs.length) {
      const at = next++;
      try {
        out[at] = await jobs[at]();
      } catch (e) {
        console.error(`pearl: a prompt failed`, e instanceof Error ? e.message : e);
      }
    }
  };
  await Promise.all(Array.from({length: Math.min(POOL, jobs.length)}, worker));
  return out;
}

/**
 * Up to `want[level]` reviewed prompts of each level, ids `idOf(level, n)`.
 * The kinds are proposed with some to spare, and a second round writes the
 * spares for the prompts the first round lost. Throws when the kinds could
 * not be proposed at all.
 */
async function writePrompts(what: string, want: number[], taken: string[],
  idOf: (level: number, n: number) => string): Promise<Prompt[][]> {
  const spare = want.map((n) => n > 0 ? n + Math.max(2, Math.ceil(n / 3)) : 0);
  const kinds = await proposeKinds(what, spare, taken);
  const out: Prompt[][] = [[], [], []];
  const used = [0, 0, 0];
  for (let round = 0; round < 2; round++) {
    const jobs: (() => Promise<Prompt | null>)[] = [];
    const levels: number[] = [];
    for (let l = 0; l < 3; l++) {
      const short = want[l] - out[l].length;
      for (const k of kinds[l].slice(used[l], used[l] + short)) {
        const id = idOf(l, used[l]++);
        jobs.push(() => writePrompt(id, k));
        levels.push(l);
      }
    }
    if (jobs.length === 0) break;
    (await pooled(jobs)).forEach((p, i) => {
      if (p !== null) out[levels[i]].push(p);
    });
  }
  return out;
}

// --- the day ---

/** What a published day says of itself to the next day's writer: what it
 *  asked, in English. */
export function asked(day: unknown): string[] {
  const bands = (day as Day | undefined)?.bands;
  if (!Array.isArray(bands)) return [];
  const out: string[] = [];
  for (const band of bands) {
    if (!Array.isArray(band)) continue;
    for (const p of band) {
      const a = (p as Prompt | undefined)?.en?.ask;
      if (typeof a === "string") out.push(a);
    }
  }
  return out;
}

/** Which level each slot of each band asks: a band its own level, and One
 *  Breath three easy, three medium, two hard. */
function slotLevels(): number[][] {
  const breath: number[] = [];
  BREATH.forEach((n, l) => breath.push(...Array(n).fill(l)));
  return [Array(ASKS[0]).fill(0), Array(ASKS[1]).fill(1), Array(ASKS[2]).fill(2), breath];
}

/**
 * The day to publish. `recent` is what the last days asked (asked()). Never
 * throws: whatever goes wrong with the model, the bank answers -- for the
 * prompt that failed, and for the whole day when there is no model at all.
 */
export async function makeDay(day: number, recent: string[] = []): Promise<Day> {
  const reserve = bankDay(day);
  if (!available()) return {v: 1, source: "bank", bands: reserve};
  const slots = slotLevels();
  const want = [0, 0, 0];
  for (const band of slots) for (const l of band) want[l]++;
  let written: Prompt[][] = [[], [], []];
  try {
    // The bank's day is told too: it fills what the model loses.
    written = await writePrompts(`day ${day}`, want, [...recent, ...reserve.flat().map((p) => p.en.ask)],
      (l, n) => `d${day}l${l}k${n}`);
  } catch (e) {
    console.error(`pearl: day ${day} has no kinds, the bank's day stands`, e);
    return {v: 1, source: "bank", bands: reserve};
  }
  const kept = written.map((l) => l.length);
  const orders = bankLevels().map((l) => ordered(l, day));
  const haveAsk = new Set(written.flat().map((p) => norm(p.en.ask)));
  const haveId = new Set<string>();
  let fromBank = 0;
  let fromModel = 0;
  const bands = slots.map((band, b) => band.map((l, i) => {
    const mine = written[l].shift();
    if (mine !== undefined) {
      fromModel++;
      return mine;
    }
    // The slot's own bank prompt first, so a bank day and a patched day
    // agree where they can; then the level's order. Never one the day
    // already asks.
    const fill = [reserve[b][i], ...(orders[l] ?? [])].find((p) =>
      p !== undefined && !haveId.has(p.id) && !haveAsk.has(norm(p.en.ask)));
    if (fill === undefined) return undefined;
    haveId.add(fill.id);
    haveAsk.add(norm(fill.en.ask));
    fromBank++;
    return fill;
  }).filter((p): p is Prompt => p !== undefined));
  console.log(`pearl: day ${day}, kept ${kept.join("/")} of ${want.join("/")}, ${fromBank} from the bank`);
  return {v: 1, source: fromBank === 0 ? "model" : fromModel === 0 ? "bank" : "mixed", bands};
}

// --- the bank's own writing ---

/**
 * New prompts of one level for the bank (cli.ts, `bank pearl`): the day's
 * own writer and reviewer, asked for `count` kinds that `taken` does not
 * have. Fewer come back when some do not survive.
 */
export async function bankPrompts(level: number, count: number, taken: string[],
  idOf: (n: number) => string): Promise<Prompt[]> {
  const want = [0, 0, 0];
  want[level] = count;
  const got = await writePrompts("the game's standing bank", want, taken, (_l, n) => `new${n}`);
  return got[level].map((p, i) => ({...p, id: idOf(i)}));
}
