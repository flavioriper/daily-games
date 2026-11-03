// /admin/games, local only: every game on the menu's grid, in order, read
// from ui/registry.gd on each load. A game with its own admin page links to it.
import Link from "next/link";
import { en, registry } from "@/lib/admin/repo";

export const dynamic = "force-dynamic";

/** Games whose admin page is built (src/app/admin/games/[id]). */
const WIRED = new Set(["how_big"]);

export default function GamesPage() {
  const games = registry();
  return (
    <div className="shell">
      <header className="top">
        <h1>Games</h1>
        <p className="dim">{games.length} on the menu&apos;s grid, in the order the game shows them.</p>
      </header>
      <section className="card">
        <ol className="games">
          {games.map((g, i) => {
            const blurb = g.block.match(/^\t\t"blurb": "(\w+)"/m)?.[1];
            const body = (
              <>
                <span className="n">{i + 1}</span>
                <span className="g-main">
                  <strong>{g.title}</strong>
                  <code>{g.id}</code>
                  {blurb && <span className="dim g-blurb">{en(blurb)}</span>}
                </span>
                <span className="g-tags">
                  <span className="tag">{g.skill}</span>
                  {WIRED.has(g.id) ? <span className="tag on">Open</span> : <span className="tag off">Not wired yet</span>}
                </span>
              </>
            );
            return (
              <li key={g.id} className={WIRED.has(g.id) ? "wired" : ""}>
                {WIRED.has(g.id) ? <Link href={`/admin/games/${g.id}`}>{body}</Link> : <div>{body}</div>}
              </li>
            );
          })}
        </ol>
      </section>
    </div>
  );
}
