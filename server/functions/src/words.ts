import {ask, available} from "./generate";
import {LANGS, Theme} from "./theme";
import hiddenEn from "./word_lists/hidden_word.json";
import hiddenPt from "./word_lists/hidden_word.pt.json";
import hiddenEs from "./word_lists/hidden_word.es.json";
import trailEn from "./word_lists/word_trail.json";
import trailPt from "./word_lists/word_trail.pt.json";
import trailEs from "./word_lists/word_trail.es.json";

/**
 * The day's words for the two word boards (docs/superpowers/specs/
 * 2026-10-13-daily-theme-design.md, "The other boards"): the theme's
 * words, kept only where the board's own lists take them, in each
 * language. A model picks them out of the lists themselves -- the theme's
 * own eight words met Hidden Word's answers none at all on two days of six
 * in English -- and every word it names is kept only if it is in the list
 * exactly as the list spells it, so the phone, which checks the same
 * (core/themed_pictures.gd `words`), never meets one it would not deal.
 *
 * Hidden Word takes one, on Easy only: a theme known gives a harder answer
 * away. Word Trail takes one a path wherever a length has one.
 *
 * The lists are copied out of content/ by `npm run build`
 * (src/word_lists/, git-ignored): they live once.
 */

type Lang = (typeof LANGS)[number];

export interface Words {
  /** Hidden Word's answers on the theme, the best first, a language each. */
  hiddenword: Record<Lang, string[]>;
  /** Word Trail's, by length ("3" to "8"), the best first. */
  wordtrail: Record<Lang, Record<string, string[]>>;
}

const HIDDEN: Record<Lang, string[]> = {en: hiddenEn.answers, pt: hiddenPt.answers, es: hiddenEs.answers};
const TRAIL: Record<Lang, Record<string, string[]>> = {en: trailEn.words, pt: trailPt.words, es: trailEs.words};
/** At most this many kept a list: a board takes the first. */
const HIDDEN_MAX = 4;
const TRAIL_MAX = 3;

const NAMES: Record<Lang, string> = {en: "English", pt: "Portuguese (Brazil)", es: "Spanish"};

const SYSTEM = `You pick words for a cosy daily word game played by all ages. The day has a theme, and a word game that day uses words that belong to it.

You are given the theme and two lists of words in one language. Pick only words that are in the lists, spelt exactly as they are there, accents and all. A word belongs to the theme when someone told the theme would think of it at once: a thing you would see, hold, hear or do there. A word that merely could be there, or belongs to every theme (day, sun, good, home), does not.

- "hidden": up to ${HIDDEN_MAX} words out of the first list that belong to the theme, the one that belongs most first. None is better than a weak one.
- "trail": up to ${TRAIL_MAX} words of each length out of the second list that belong to the theme, the one that belongs most first, as one list.`;

const SCHEMA = {
  type: "object",
  properties: {
    hidden: {type: "array", items: {type: "string"}},
    trail: {type: "array", items: {type: "string"}},
  },
  required: ["hidden", "trail"],
  additionalProperties: false,
};

function prompt(theme: Theme, lang: Lang): string {
  const trail = Object.values(TRAIL[lang]).flat();
  return `The theme: ${theme.name[lang]} (${theme.scene}). Its things: ${theme.objects.map((o) => o[lang === "en" ? "name" : lang]).join(", ")}. Its words: ${theme.words[lang].join(", ")}.

The language: ${NAMES[lang]}.

The first list (five letters):
${HIDDEN[lang].join(" ")}

The second list (three to eight letters):
${trail.join(" ")}`;
}

/** The ones of `named` in `list`, as the list spells them, no two alike. */
function kept(named: unknown, list: string[], max: number): string[] {
  const known = new Set(list);
  const out: string[] = [];
  for (const w of Array.isArray(named) ? named : []) {
    const word = typeof w === "string" ? w.trim().toLowerCase() : "";
    if (known.has(word) && !out.includes(word)) out.push(word);
    if (out.length >= max) break;
  }
  return out;
}

/** Word Trail's by length: `named` first, then the theme's own words the
 *  lists hold, at most TRAIL_MAX a length. */
function byLength(named: unknown, theme: Theme, lang: Lang): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  const all = [...(Array.isArray(named) ? named : []), ...theme.words[lang]];
  for (const [len, list] of Object.entries(TRAIL[lang])) {
    const got = kept(all.filter((w) => typeof w === "string" && [...w.trim()].length === Number(len)), list, TRAIL_MAX);
    if (got.length > 0) out[len] = got;
  }
  return out;
}

/** What a day's words came to in one language: for the dashboard. */
export interface WordsTry {
  lang: Lang;
  named?: {hidden: unknown; trail: unknown};
  error?: string;
}

/** The day's words, or null when no language has any. Never throws: a
 *  language whose ask fails keeps only the theme's own words the lists
 *  hold. */
export async function makeWords(theme: Theme): Promise<{words: Words | null; tries: WordsTry[]}> {
  const words: Words = {hiddenword: {en: [], pt: [], es: []}, wordtrail: {en: {}, pt: {}, es: {}}};
  const tries: WordsTry[] = [];
  let any = false;
  for (const lang of LANGS) {
    const t: WordsTry = {lang};
    tries.push(t);
    let named: {hidden: unknown; trail: unknown} = {hidden: [], trail: []};
    if (available()) {
      try {
        named = await ask<{hidden: string[]; trail: string[]}>({system: SYSTEM, prompt: prompt(theme, lang), schema: SCHEMA});
        t.named = named;
      } catch (e) {
        t.error = String(e).slice(0, 300);
        console.error(`words: ${theme.id}, ${lang} failed`, e);
      }
    }
    const hidden = Array.isArray(named.hidden) ? named.hidden : [];
    words.hiddenword[lang] = kept([...hidden, ...theme.words[lang]], HIDDEN[lang], HIDDEN_MAX);
    words.wordtrail[lang] = byLength(named.trail, theme, lang);
    any ||= words.hiddenword[lang].length > 0 || Object.keys(words.wordtrail[lang]).length > 0;
  }
  return {words: any ? words : null, tries};
}
