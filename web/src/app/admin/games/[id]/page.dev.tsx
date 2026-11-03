// /admin/games/<id>, local only. How Big? is the first game wired: its specs,
// its players and its library. Each section fails on its own, so a missing
// credential never hides what the repo can show.
import Link from "next/link";
import { notFound } from "next/navigation";
import { GoogleError, whoAmI } from "@/lib/admin/google";
import {
  EVENTS,
  ID,
  NEEDED_DIMS,
  NEEDED_METS,
  RANGES,
  type RangeKey,
  type Shape,
  type Thing,
  library,
  players,
  pool,
  specs,
} from "@/lib/admin/howbig";

export const dynamic = "force-dynamic";

const BANDS = ["Easy", "Medium", "Hard", "Insane"];
const fmt = (n: number) => n.toLocaleString("en-US");
const pct = (n: number) => `${Math.round(n * 100)}%`;

export default async function GamePage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ range?: string }>;
}) {
  const { id } = await params;
  if (id !== ID) notFound();
  const { range: r } = await searchParams;
  const range: RangeKey = (RANGES.find((x) => x.key === r)?.key ?? "28") as RangeKey;
  const s = specs();
  const lib = library();
  const [poolResult, playersResult, me] = await Promise.all([
    pool().then((v) => ({ ok: v }), (e: unknown) => ({ err: e })),
    players(range).then((v) => ({ ok: v }), (e: unknown) => ({ err: e })),
    whoAmI(),
  ]);

  return (
    <div className="shell">
      <header className="top">
        <p className="dim"><Link href="/admin/games">Games</Link> / {s.title}</p>
        <h1>{s.title}</h1>
        <p className="dim">{s.blurb}</p>
      </header>

      <nav className="jump">
        <a href="#specs">Specs</a>
        <a href="#players">Players</a>
        <a href="#library">Library</a>
      </nav>

      <Specs s={s} />
      <PlayersPanel result={playersResult} range={range} me={me} />
      <Library bundled={lib} pool={poolResult} />
    </div>
  );
}

// ---------------- Specs ----------------

function Specs({ s }: { s: ReturnType<typeof specs> }) {
  return (
    <section className="card" id="specs">
      <h2>Specs</h2>
      <dl className="facts">
        <div><dt>Id</dt><dd><code>{ID}</code></dd></div>
        <div><dt>Skill</dt><dd>{s.skill}</dd></div>
        <div><dt>Motto</dt><dd>{s.motto}</dd></div>
        <div><dt>Footer</dt><dd>{s.footer}</dd></div>
      </dl>
      {s.rules && <p className="prose">{s.rules}</p>}

      <h3>Levels</h3>
      <div className="table-wrap">
        <table className="grid">
          <thead>
            <tr>
              <th>Level</th><th>What the card says</th><th className="num">Rounds</th><th className="num">Hints</th>
              <th className="num">Hearts</th><th className="num">Size gap</th>
            </tr>
          </thead>
          <tbody>
            {s.levels.map((l) => (
              <tr key={l.d}>
                <th scope="row">{l.name}</th>
                <td>{l.line}</td>
                <td className="num">{s.rounds[l.d] ?? "–"}</td>
                <td className="num">{s.hints[l.d] ?? "–"}</td>
                <td className="num">{s.hearts[l.d] || "–"}</td>
                <td className="num">{s.spread[l.d] ? `${s.spread[l.d][0]}× – ${s.spread[l.d][1]}×` : "–"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="dim small">Size gap: how much bigger the larger thing&apos;s box is than the smaller&apos;s in a round.</p>

      <div className="two">
        <div>
          <h3>Scoring</h3>
          <table className="grid">
            <thead><tr><th>Guess off by</th><th className="num">Points</th><th>Card says</th></tr></thead>
            <tbody>
              {s.curve.map(([ratio, pts]) => (
                <tr key={ratio}>
                  <td>{ratio < 2 ? `${Math.round((ratio - 1) * 100)}%` : `${ratio}×`}</td>
                  <td className="num">{pts}</td>
                  <td>{s.grades.find((g) => g.at <= pts)?.word ?? ""}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="dim small">Straight lines between, in the log of the ratio; half and double score alike.</p>
        </div>
        <div>
          <h3>Other rules</h3>
          <dl className="facts single">
            <div><dt>Stars at</dt><dd>{s.starAt.map((x) => pct(x)).join(" / ")} of the day&apos;s points</dd></div>
            <div><dt>A heart is lost past</dt><dd>{s.missRatio}× off (Insane)</dd></div>
            <div><dt>A good guess, for runs</dt><dd>{s.runFrom} points or more</dd></div>
            <div><dt>Bulb says &quot;much&quot; past</dt><dd>{s.lot}×</dd></div>
            <div><dt>&quot;You made it X-sized&quot; past</dt><dd>{s.likeFrom}× off</dd></div>
          </dl>
        </div>
      </div>
      <p className="dim small">
        Read live from <code>ui/registry.gd</code>, <code>puzzles/how_big_state.gd</code> and <code>locale/boards.csv</code>.
      </p>
    </section>
  );
}

// ---------------- Players ----------------

function Fix({ e }: { e: unknown }) {
  const g = e instanceof GoogleError ? e : null;
  return (
    <div className="notice">
      <p className="error">{e instanceof Error ? e.message : String(e)}</p>
      {g?.fix && (
        <>
          <p className="dim">To fix it, run this in the Claude prompt (with the leading <code>!</code>) or a terminal, then reload:</p>
          <pre className="cmd">! {g.fix}</pre>
        </>
      )}
    </div>
  );
}

function PlayersPanel({
  result,
  range,
  me,
}: {
  result: { ok: Awaited<ReturnType<typeof players>> } | { err: unknown };
  range: RangeKey;
  me: { email: string; analytics: boolean } | null;
}) {
  return (
    <section className="card" id="players">
      <div className="card-head row">
        <div>
          <h2>Players</h2>
          <p className="dim">
            From Google Analytics: the events every board sends with <code>puzzle_id</code> {ID}. Numbers can lag up to a day.
            {me && <> Signed in as <strong>{me.email}</strong>.</>}
          </p>
        </div>
        <div className="filters">
          {RANGES.map((x) => (
            <Link key={x.key} href={`?range=${x.key}#players`} className={x.key === range ? "seg on" : "seg"} scroll={false}>
              {x.label}
            </Link>
          ))}
        </div>
      </div>
      {"err" in result ? <Fix e={result.err} /> : <PlayersBody p={result.ok} />}
    </section>
  );
}

function PlayersBody({ p }: { p: Awaited<ReturnType<typeof players>> }) {
  const missing = [
    ...NEEDED_DIMS.filter((d) => !p.dims[d]).map((d) => `${d} (dimension)`),
    ...NEEDED_METS.filter((m) => !p.mets[m]).map((m) => `${m} (metric)`),
  ];
  const total = (ev: string) => [...p.byBand.values()].reduce((s, m) => s + (m.get(ev) ?? 0), 0);
  const starts = total("puzzle_start");
  const completes = total("puzzle_complete");
  const top = Math.max(1, ...p.days.map((d) => Math.max(d.starts, d.completes)));
  const bands = [...new Set([...p.byBand.keys(), ...p.usersByBand.keys()])].sort();
  const label = (k: string) =>
    new Date(Number(k.slice(0, 4)), Number(k.slice(4, 6)) - 1, Number(k.slice(6, 8))).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
    });

  return (
    <>
      <p className="dim small">Property: {p.property.name} ({p.property.id})</p>
      {missing.length > 0 && (
        <div className="notice">
          <p className={p.dims.puzzle_id ? "" : "error"}>
            Not registered in Google Analytics yet: {missing.join(", ")}.
            {!p.dims.puzzle_id && " Without puzzle_id no event can be told apart by game, so this panel has nothing to show."}
          </p>
          <p className="dim">
            Register them in Google Analytics → Admin → Data display → Custom definitions, as event-scoped custom
            dimensions (puzzle_id, difficulty) and custom metrics (seconds, hints). Google counts them only from the day
            they are registered; earlier events cannot be split.
          </p>
        </div>
      )}
      {p.ready && (
        <>
          <div className="tiles">
            <Tile label="Players" value={fmt(p.users.get("puzzle_start") ?? 0)} sub="opened a round" />
            <Tile label="Days started" value={fmt(starts)} sub={`${fmt(total("puzzle_abandon"))} left unfinished`} />
            <Tile label="Days finished" value={fmt(completes)} sub={starts ? `${pct(completes / starts)} of starts` : ""} />
            <Tile label="Hints used" value={fmt(total("hint_used"))} sub={`${fmt(total("rules_opened"))} opened the rules`} />
          </div>

          {p.days.length > 1 && (
            <figure className="days">
              <figcaption>
                Per day: <span className="key start" /> started <span className="key done" /> finished
              </figcaption>
              <div className="day-bars">
                {p.days.map((d) => (
                  <div key={d.date} className="day" title={`${label(d.date)}: ${fmt(d.starts)} started, ${fmt(d.completes)} finished`}>
                    <span className="start" style={{ height: `${(d.starts / top) * 100}%` }} />
                    <span className="done" style={{ height: `${(d.completes / top) * 100}%` }} />
                  </div>
                ))}
              </div>
              <div className="day-axis">
                <span>{label(p.days[0].date)}</span>
                <span>{label(p.days[p.days.length - 1].date)}</span>
              </div>
            </figure>
          )}

          {p.dims.difficulty && (
            <div className="table-wrap">
              <table className="grid">
                <thead>
                  <tr>
                    <th>Level</th><th className="num">Players</th><th className="num">Started</th><th className="num">Finished</th>
                    <th className="num">Finish rate</th><th className="num">Left</th><th className="num">Hints</th>
                    <th className="num">Avg time</th><th className="num">Avg hints</th>
                  </tr>
                </thead>
                <tbody>
                  {bands.map((b) => {
                    const m = p.byBand.get(b) ?? new Map<string, number>();
                    const st = m.get("puzzle_start") ?? 0;
                    const done = m.get("puzzle_complete") ?? 0;
                    const a = p.avg.get(b);
                    return (
                      <tr key={b}>
                        <th scope="row">{BANDS[Number(b)] ?? b}</th>
                        <td className="num">{fmt(p.usersByBand.get(b) ?? 0)}</td>
                        <td className="num">{fmt(st)}</td>
                        <td className="num">{fmt(done)}</td>
                        <td className="num">{st ? pct(done / st) : "–"}</td>
                        <td className="num">{fmt(m.get("puzzle_abandon") ?? 0)}</td>
                        <td className="num">{fmt(m.get("hint_used") ?? 0)}</td>
                        <td className="num">{a?.seconds != null ? `${Math.floor(a.seconds / 60)}:${String(Math.round(a.seconds % 60)).padStart(2, "0")}` : "–"}</td>
                        <td className="num">{a?.hints != null ? a.hints.toFixed(1) : "–"}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
          <p className="dim small">Events read: {EVENTS.join(", ")}.</p>
        </>
      )}
    </>
  );
}

function Tile({ label, value, sub }: { label: string; value: string; sub: string }) {
  return (
    <div className="tile">
      <p className="tile-label">{label}</p>
      <p className="tile-value">{value}</p>
      <p className="tile-sub">{sub}</p>
    </div>
  );
}

// ---------------- Library ----------------

function Silhouette({ shape, title }: { shape: Shape | null; title: string }) {
  if (!shape) return <div className="sil missing">no shape</div>;
  const d = shape.loops
    .map((loop) => {
      let p = "";
      for (let i = 0; i + 1 < loop.length; i += 2) p += `${i ? "L" : "M"}${loop[i]} ${loop[i + 1]}`;
      return p + "Z";
    })
    .join("");
  return (
    <svg className="sil" viewBox={`0 0 ${shape.w} ${shape.h}`} role="img" aria-label={title}>
      <path d={d} fillRule="evenodd" />
    </svg>
  );
}

const metres = (m: number) => (m < 0.01 ? `${(m * 1000).toFixed(0)} mm` : m < 1 ? `${(m * 100).toFixed(m < 0.1 ? 1 : 0)} cm` : `${m.toFixed(2)} m`);

function boxOf(t: Thing): string {
  if (!t.shape || !(t.to - t.from)) return "–";
  const span = t.size_m / (t.to - t.from);
  const [w, h] = t.measure === "tall" ? [(span * t.shape.w) / t.shape.h, span] : [span, (span * t.shape.h) / t.shape.w];
  return `${metres(w)} × ${metres(h)}`;
}

function ThingCard({ t }: { t: Thing }) {
  return (
    <li className="thing">
      <Silhouette shape={t.shape} title={t.name} />
      <div>
        <p className="t-name"><strong>{t.name}</strong> <code>{t.id}</code></p>
        <p className="t-size">
          {metres(t.size_m)} {t.measure}
          {t.what && ` (${t.what})`}
          {t.from !== 0 || t.to !== 1 ? <span className="dim"> · spans {t.from}–{t.to} of its drawing</span> : null}
        </p>
        <p className="dim t-meta">
          {t.kind} · box {boxOf(t)}
          {t.born ? ` · added ${String(t.born).replace(/(\d{4})(\d{2})(\d{2})/, "$1-$2-$3")}` : ""}
        </p>
        {t.fact && <p className="t-fact">{t.fact}</p>}
        <p className="t-links">
          {t.source && <a href={t.source} target="_blank" rel="noreferrer">size source</a>}
          {t.credit && <span className="dim"> · {t.credit.startsWith("http") ? <a href={t.credit.split(" ")[0]} target="_blank" rel="noreferrer">silhouette</a> : t.credit}</span>}
        </p>
      </div>
    </li>
  );
}

function Library({ bundled, pool: result }: { bundled: Thing[]; pool: { ok: Thing[] } | { err: unknown } }) {
  const sorted = [...bundled].sort((a, b) => a.size_m - b.size_m);
  return (
    <section className="card" id="library">
      <h2>Library</h2>
      <p className="dim">
        Everything a round can deal: the {bundled.length} things shipped with the game, and the ones the night adds to the pool.
      </p>

      <h3>The night&apos;s pool {"ok" in result && <span className="dim">({result.ok.length})</span>}</h3>
      {"err" in result ? (
        <Fix e={result.err} />
      ) : result.ok.length === 0 ? (
        <p className="dim">Empty: the night has kept nothing yet.</p>
      ) : (
        <ul className="things">{result.ok.map((t) => <ThingCard key={t.id} t={t} />)}</ul>
      )}
      <p className="dim small">
        Firestore <code>things/</code> in <code>daily-games-420bf</code> (server/functions/src/things.ts). A day deals its two
        new things and six of these.
      </p>

      <h3>Shipped with the game <span className="dim">({bundled.length}, smallest first)</span></h3>
      <ul className="things">{sorted.map((t) => <ThingCard key={t.id} t={t} />)}</ul>
      <p className="dim small">
        Read live from <code>content/how_big.json</code> and <code>content/how_big_shapes.json</code> (built by
        <code>tools/build_how_big.py</code> from <code>tools/how_big/items.json</code>).
      </p>
    </section>
  );
}
