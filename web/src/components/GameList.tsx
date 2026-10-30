import Image from "next/image";
import type { Game, Lang } from "@/lib/games";

type Props = {
  id: string;
  title: string;
  intro: string;
  count: string;
  games: Game[];
  lang: Lang;
  shotOf: (name: string) => string;
};

// One shelf of games: a tile each, its screen on a plate tinted from the
// screen's own colours, its name and one line under it. A grid on a desk, a
// row that scrolls sideways on a phone.
export function GameList({ id, title, intro, count, games, lang, shotOf }: Props) {
  return (
    <section className="shelf" id={id}>
      <header>
        <div>
          <h2>{title}</h2>
          <p>{intro}</p>
        </div>
        <span className="chip">{count}</span>
      </header>
      <ol>
        {games.map((game) => (
          <li key={game.id}>
            <div className="plate" style={{ backgroundColor: game.tint }}>
              <Image
                src={`/games/${game.id}.webp`}
                alt={shotOf(game.title)}
                width={240}
                height={320}
                loading="lazy"
              />
            </div>
            <h3>{game.title}</h3>
            <p>{game.text[lang]}</p>
          </li>
        ))}
      </ol>
    </section>
  );
}
