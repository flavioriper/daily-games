import data from "@/data/games.json";

export type Group = "puzzles" | "arcade" | "versus";
export type Lang = "en" | "pt" | "es";

export type Game = {
  id: string;
  title: string;
  group: Group;
  text: Record<Lang, string>;
  // The pale plate under its tile, mixed from the screen's own colours.
  tint: string;
};

// The hero's fan of phones, left to right; scripts/gen_games.py cuts them.
export const HERO_PHONES = ["minigolf", "honeycomb", "buttons", "boats", "posy"];

export const GAMES = data as Game[];

// Message locale to the game's own locale columns.
export function langOf(locale: string): Lang {
  return locale === "pt-BR" ? "pt" : locale === "es" ? "es" : "en";
}
