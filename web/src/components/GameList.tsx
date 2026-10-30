import Image from "next/image";
import type { Game, Lang } from "@/lib/games";

type Props = {
  id: string;
  title: string;
  intro: string;
  games: Game[];
  lang: Lang;
  shotOf: (name: string) => string;
};

// One almanac section: every game on a line of its own, name first, its screen
// small at the end of the line.
export function GameList({ id, title, intro, games, lang, shotOf }: Props) {
  return (
    <section className="list" id={id}>
      <header>
        <h2>{title}</h2>
        <p>{intro}</p>
      </header>
      <ol>
        {games.map((game) => (
          <li key={game.id}>
            <div>
              <h3>{game.title}</h3>
              <p>{game.text[lang]}</p>
            </div>
            <Image
              src={`/games/${game.id}.webp`}
              alt={shotOf(game.title)}
              width={240}
              height={320}
              loading="lazy"
            />
          </li>
        ))}
      </ol>
    </section>
  );
}
