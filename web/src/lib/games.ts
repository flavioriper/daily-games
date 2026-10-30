import data from "@/data/games.json";

export type Group = "puzzles" | "arcade" | "versus";
export type Lang = "en" | "pt" | "es";

export type Game = {
  id: string;
  title: string;
  group: Group;
  text: Record<Lang, string>;
};

export const GAMES = data as Game[];

// Message locale to the game's own locale columns.
export function langOf(locale: string): Lang {
  return locale === "pt-BR" ? "pt" : locale === "es" ? "es" : "en";
}
