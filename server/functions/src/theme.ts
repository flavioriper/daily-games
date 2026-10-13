import {ask, available} from "./generate";

/**
 * The day's theme (docs/superpowers/specs/2026-10-13-daily-theme-design.md):
 * one small cosy place or moment, the scene a picture of it shows, three
 * single things out of that scene, and a few words about it. It is made
 * before any game's day, and the games that can are made around it.
 *
 * A model writes it and a second reads it for what does not belong in a
 * game anybody may open. A theme that fails either is no theme: makeTheme
 * answers null and the day's games deal as they do without one.
 */

export const LANGS = ["en", "pt", "es"] as const;

export interface Thing {
  /** A slug. */
  id: string;
  /** What it is called, in English: a noun or two. */
  name: string;
  /** And in Portuguese and Spanish, as a board names the picture. */
  pt: string;
  es: string;
  /** What to draw: the thing with its colours. */
  draw: string;
}

export interface Theme {
  v: 1;
  id: string;
  name: {en: string; pt: string; es: string};
  scene: string;
  objects: Thing[];
  words: {en: string[]; pt: string[]; es: string[]};
}

/** Things a theme has, and words a language. */
export const THINGS = 3;
const WORDS = 8;
const SCENE_MAX = 320;
const DRAW_MAX = 160;
/** Themes written before one is given up on. */
const TRIES = 2;

const SLUG = /^[a-z][a-z0-9_]{1,30}$/;

function text(v: unknown, max: number): v is string {
  return typeof v === "string" && v.trim().length > 0 && v.length <= max;
}

export function validTheme(t: unknown): t is Theme {
  const o = t as Theme;
  if (typeof o !== "object" || o === null || !SLUG.test(String(o.id))) return false;
  if (!text(o.scene, SCENE_MAX)) return false;
  if (!Array.isArray(o.objects) || o.objects.length !== THINGS) return false;
  const ids = new Set<string>();
  for (const x of o.objects) {
    if (typeof x !== "object" || x === null) return false;
    if (!SLUG.test(String(x.id)) || !text(x.name, 30) || !text(x.draw, DRAW_MAX)) return false;
    if (!text(x.pt, 30) || !text(x.es, 30)) return false;
    ids.add(x.id);
  }
  if (ids.size !== THINGS) return false;
  for (const lang of LANGS) {
    if (!text(o.name?.[lang], 30)) return false;
    const words = o.words?.[lang];
    if (!Array.isArray(words) || words.length < 1 || !words.every((w) => text(w, 20))) return false;
  }
  return true;
}

const WRITER = `You choose the theme of the day for a cosy daily puzzle game played by all ages, in English, Portuguese and Spanish.

A theme is one small, warm place or moment: a campfire at dusk, a bakery in the morning, a window on a rainy day, a tide pool, a garden shed, a picnic. Never a holiday, a religion, a country, a brand, a film, a real person, anything scary or sad, anything with writing in it.

The theme is drawn as pixel pictures of very few squares, so everything in it must be a big simple shape a child would name at once.

- "scene": one sentence, what a single picture of the theme shows: four to six big things and where they are, in several areas of different colour, so that no sky, wall or floor is half the picture. No people's faces, no text.
- "objects": exactly ${THINGS} single things from that scene, the simplest first. Each must be recognisable by its outline alone when drawn in a grid of ten by ten squares (a mushroom, a mug, a tent: yes; a book, a blanket, a cloud of steam: no). "draw" says the thing with its colours, clearly different ones: three or four for the first ("a red mushroom with white spots and a cream stem"), five for the second, seven for the third, which is the one with the most to it. None of them is a thin or spindly shape: each fills most of a square. None is mostly one colour (a red apple, a blue teapot: no; a striped mug, a slice of watermelon, a toadstool: yes). "name" is its plain English name, one or two words, and "pt" and "es" the same in Portuguese (Brazil) and Spanish.
- "name": the theme's name, two or three words, in each language.
- "words": ${WORDS} common single nouns about the theme in each language, four to eight letters, lowercase.
- "id" values are lowercase English slugs.`;

const THEME_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["id", "name", "scene", "objects", "words"],
  properties: {
    id: {type: "string"},
    name: {type: "object", additionalProperties: false, required: ["en", "pt", "es"],
      properties: {en: {type: "string"}, pt: {type: "string"}, es: {type: "string"}}},
    scene: {type: "string"},
    objects: {type: "array", items: {type: "object", additionalProperties: false, required: ["id", "name", "pt", "es", "draw"],
      properties: {id: {type: "string"}, name: {type: "string"}, pt: {type: "string"}, es: {type: "string"},
        draw: {type: "string"}}}},
    words: {type: "object", additionalProperties: false, required: ["en", "pt", "es"],
      properties: {en: {type: "array", items: {type: "string"}}, pt: {type: "array", items: {type: "string"}},
        es: {type: "array", items: {type: "string"}}}},
  },
};

const REVIEWER = `You check the theme of the day of a cosy puzzle game played by all ages, children among them, before it is published. Say what is wrong with it, or that nothing is. Wrong means: a holiday, a religion, a country or a people, a brand, a film or a character somebody owns, a real person, anything frightening, sad, violent or adult. "wrong" is an empty string when nothing is. A word in the lists that is misspelt, in the wrong language, not a common noun or not about the theme is not a reason to turn the theme down: name it in "bad_words", exactly as it is written, and it is left out.`;

const REVIEW_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["wrong", "bad_words"],
  properties: {wrong: {type: "string"}, bad_words: {type: "array", items: {type: "string"}}},
};

/** What a published theme is remembered by, for "not these again". */
export function themed(day: unknown): string[] {
  // Its things too: two days apart, a picnic and a porch both had a teapot.
  return validTheme(day) ? [`${day.name.en}, with ${day.objects.map((o) => o.name).join(", ")}`] : [];
}

/**
 * The theme to publish, or null. `recent` is themed() of the last days.
 * Never throws.
 */
export async function makeTheme(day: number, recent: string[] = []): Promise<Theme | null> {
  if (!available()) return null;
  for (let attempt = 0; attempt < TRIES; attempt++) {
    try {
      const got = await ask<Omit<Theme, "v">>({
        system: WRITER,
        prompt: `The theme for day ${day}.` + (recent.length > 0 ?
          `\n\nThe last days had these, so not these themes, nothing close to them, and none of their things:\n${recent.join("\n")}` : ""),
        schema: THEME_SCHEMA,
        role: "write",
      });
      // A writer's slug is as often hyphened as not: made ours, not turned down.
      const slug = (v: unknown) => String(v ?? "").toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
      const theme = {v: 1 as const, id: slug(got.id), name: got.name, scene: got.scene,
        objects: (Array.isArray(got.objects) ? got.objects : []).map((o) => ({...o, id: slug(o?.id)})), words: got.words};
      if (!validTheme(theme)) {
        console.error(`theme: day ${day}, try ${attempt}: not a theme: ${JSON.stringify(got).slice(0, 1500)}`);
        continue;
      }
      const review = await ask<{wrong: string; bad_words?: string[]}>({
        system: REVIEWER,
        prompt: JSON.stringify(theme, null, 1),
        schema: REVIEW_SCHEMA,
        role: "review",
      });
      if (String(review.wrong ?? "").trim() === "") {
        // A word the reviewer would not have is left out; a language left
        // with none keeps its list, which the word boards check for themselves.
        const bad = new Set((Array.isArray(review.bad_words) ? review.bad_words : []).map((w) => String(w).toLowerCase()));
        for (const lang of LANGS) {
          const good = theme.words[lang].filter((w) => !bad.has(w.toLowerCase()));
          if (good.length > 0) theme.words[lang] = good;
        }
        return theme;
      }
      console.error(`theme: day ${day}, try ${attempt}: turned down: ${review.wrong}`);
    } catch (e) {
      console.error(`theme: day ${day}, try ${attempt} failed`, e);
    }
  }
  return null;
}
