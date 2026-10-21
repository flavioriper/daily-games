import {useEffect, useState} from "react";
import beadsSource from "../../beads.js?raw";
import {readDay, readPorts, shiftDay, todayUtc} from "./day.js";

// The bead palette from the one file the dashboard and the functions share.
const Beads = new Function(`${beadsSource}\nreturn Beads;`)();

// puzzles/gumdrop_sim.gd FLAVOURS, in jelly.ts FLAVOURS' order.
const FLAVOUR = {cherry: "#e2495a", orange: "#f39237", lemon: "#f4d44a", lime: "#79c94f", blueberry: "#4a86df", grape: "#9a62d2"};
const BANDS = ["Easy", "Medium", "Hard", "Insane"];
const LANGS = ["en", "pt", "es"];

// Who reads which bead slot (buttons_state.gd THEMED_KEY, hoop_state.gd
// THEMED_SIDE); Pixel Garden, Toy Cannons and Paper Planes take one by size.
const JEWEL_BOX = [10, 12, 32, 48];
const HOOP_FALLBACK = [24, 32, 48, 48];

function readers(size) {
  const out = [];
  JEWEL_BOX.forEach((s, b) => s === size && out.push(`Jewel Box ${BANDS[b]}`));
  HOOP_FALLBACK.forEach((s, b) => s === size && out.push(`Yarn Hoop ${BANDS[b]} (no hoop drawing)`));
  return out.join(" · ");
}

function BeadPicture({pic, size}) {
  const rows = pic.rows;
  const cell = Math.max(5, Math.min(16, Math.floor(360 / rows.length)));
  const w = rows[0].length;
  const counts = {};
  for (const row of rows) for (const ch of row) if (ch !== ".") counts[ch] = (counts[ch] ?? 0) + 1;
  return (
    <figure className="card">
      <svg width={w * cell} height={rows.length * cell} shapeRendering="crispEdges">
        {rows.flatMap((row, y) => [...row].map((ch, x) => ch === "." ? null :
          <rect key={`${x},${y}`} x={x * cell} y={y * cell} width={cell} height={cell} fill={`#${Beads.PALETTE[ch]}`} />))}
      </svg>
      <figcaption>
        <b>{pic.name.en}</b> · slot {size} · drawn {w}×{rows.length} · {Object.keys(counts).length} colours ·{" "}
        {Object.values(counts).reduce((a, b) => a + b, 0)} beads
        <small>{readers(size)}</small>
      </figcaption>
    </figure>
  );
}

// spike_jelly_map.js GUM: the gummy finish, one filter for every jelly on the page.
function GumDefs() {
  return (
    <svg width={0} height={0} style={{position: "absolute"}} aria-hidden="true">
      <defs>
        <filter id="gum" x="-20%" y="-20%" width="140%" height="140%" primitiveUnits="userSpaceOnUse">
          <feGaussianBlur in="SourceAlpha" stdDeviation="2.2" result="bump" />
          <feSpecularLighting in="bump" surfaceScale="7" specularConstant="0.85" specularExponent="18" lightingColor="#ffffff" result="spec"><fePointLight x="20" y="-10" z="120" /></feSpecularLighting>
          <feComposite in="spec" in2="SourceAlpha" operator="in" result="specIn" />
          <feGaussianBlur in="SourceAlpha" stdDeviation="3.5" result="soft" />
          <feComposite in="soft" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="innerA" />
          <feFlood floodColor="#3a1a30" floodOpacity="0.35" result="dark" /><feComposite in="dark" in2="innerA" operator="in" result="rim" />
          <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="sh" /><feOffset in="sh" dx="1.5" dy="2.5" result="shOff" />
          <feFlood floodColor="#5a3a2a" floodOpacity="0.25" /><feComposite in2="shOff" operator="in" result="shadow" />
          <feMerge><feMergeNode in="shadow" /><feMergeNode in="SourceGraphic" /><feMergeNode in="rim" /><feMergeNode in="specIn" /></feMerge>
        </filter>
      </defs>
    </svg>
  );
}

// One port's record under its game: the picture it read and the render of what
// the night made of it (the kept try's), with that try's score and notes.
function PortRow({port}) {
  if (!port) return null;
  const kept = port.tries.find((t) => t.kept);
  const last = port.tries[port.tries.length - 1];
  const shown = kept ?? last;
  const verdict = kept?.verdict;
  return (
    <div className="port">
      {port.source && <img src={`data:image/jpeg;base64,${port.source}`} alt="source" />}
      {port.render && <img src={`data:image/jpeg;base64,${port.render}`} alt="render" />}
      <div className="verdict">
        {kept ? <>
          <b>{verdict ? `score ${verdict.score}` : "no verdict"}</b> · try {kept.n} of {port.tries.length}
          {verdict?.notes && <span>{verdict.notes}</span>}
          {kept.route === "reader" && <span>fell back to the pixel reader</span>}
        </> : <>
          <b>nothing kept</b> · {port.tries.length} {port.tries.length === 1 ? "try" : "tries"}
          {shown && <span>{shown.error ?? shown.why}</span>}
        </>}
      </div>
    </div>
  );
}

function Hoop({hoop, band, port}) {
  const p = hoop.pins;
  const points = (k) => k.map((i) => `${p[2 * i] * 3},${p[2 * i + 1] * 3}`).join(" ");
  return (
    <figure className="card">
      <svg width={300} height={300}>
        {hoop.panels.map((panel, i) => <polygon key={i} points={points(panel.k)} fill={panel.c} stroke={panel.c} strokeWidth={0.6} />)}
      </svg>
      <figcaption><b>{hoop.name.en}</b> · {BANDS[band]} · {hoop.panels.length} panels · {p.length / 2} pins</figcaption>
      <PortRow port={port} />
    </figure>
  );
}

// jelly.ts polygon(), point for point (without its winding fix, which a
// drawing does not need).
function outline(s) {
  const n = s.n;
  if (s.kind === "ell") {
    const [x, y, rx, ry, rot = 0] = n;
    return Array.from({length: 40}, (_, i) => {
      const a = 2 * Math.PI * i / 40, px = Math.cos(a) * rx, py = Math.sin(a) * ry;
      return [x + px * Math.cos(rot) - py * Math.sin(rot), y + px * Math.sin(rot) + py * Math.cos(rot)];
    });
  }
  if (s.kind === "box") {
    const [x, y, w, h] = n;
    const r = Math.min(n[4] ?? 0, Math.min(w, h) * 0.5);
    if (r <= 0) return [[x, y], [x + w, y], [x + w, y + h], [x, y + h]];
    const mids = [[x + w - r, y + r], [x + w - r, y + h - r], [x + r, y + h - r], [x + r, y + r]];
    const out = [];
    for (let k = 0; k < 4; k++) {
      for (let i = 0; i < 7; i++) {
        const a = -Math.PI * 0.5 + Math.PI * 0.5 * k + Math.PI * 0.5 * i / 6;
        out.push([mids[k][0] + Math.cos(a) * r, mids[k][1] + Math.sin(a) * r]);
      }
    }
    return out;
  }
  let p = [];
  for (let i = 0; i + 1 < n.length; i += 2) p.push([n[i], n[i + 1]]);
  for (let t = 0; t < (s.kind === "soft" ? 2 : 1); t++) {
    const q = [];
    for (let i = 0; i < p.length; i++) {
      const a = p[i], b = p[(i + 1) % p.length];
      q.push([a[0] + (b[0] - a[0]) * 0.25, a[1] + (b[1] - a[1]) * 0.25]);
      q.push([a[0] + (b[0] - a[0]) * 0.75, a[1] + (b[1] - a[1]) * 0.75]);
    }
    p = q;
  }
  return p;
}

function Jelly({jelly, port}) {
  const flavours = [...new Set(jelly.parts.map((part) => part.flavour))];
  return (
    <figure className="card small">
      <svg width={200} height={200} viewBox="0 0 100 100">
        <g filter="url(#gum)">
          {jelly.parts.flatMap((part, i) => part.shapes.map((s, j) =>
            <polygon key={`${i}.${j}`} points={outline(s).map((v) => v.join(",")).join(" ")}
              fill={FLAVOUR[part.flavour]} stroke={FLAVOUR[part.flavour]} strokeWidth={0.4} strokeLinejoin="round" />))}
        </g>
      </svg>
      <figcaption><b>{jelly.name.en}</b> · {jelly.parts.length} parts · {flavours.join(", ")}</figcaption>
      <PortRow port={port} />
    </figure>
  );
}

function HiddenWord({words, lang}) {
  return <p className="words">{(words?.[lang] ?? []).map((w) => <span key={w}>{w}</span>)}</p>;
}

function WordTrail({words, lang}) {
  const byLength = words?.[lang] ?? {};
  return (
    <table className="lengths"><tbody>
      {Object.entries(byLength).map(([n, list]) =>
        <tr key={n}><th>{n} letters</th><td className="words">{list.map((w) => <span key={w}>{w}</span>)}</td></tr>)}
    </tbody></table>
  );
}

function Acorn({acorn, lang}) {
  return acorn.bands.map((band, b) => (
    <details key={b} open={b === 0}>
      <summary>{b < 3 ? BANDS[b] : "Climb"} · {band.length} questions</summary>
      <ol className="quiz">
        {band.map((q) => (
          <li key={q.id}>
            <div className="q">{q[lang].q} <small>{q.cat}</small></div>
            <div className="right">✔ {q[lang].right}</div>
            <div className="wrong">✘ {q[lang].wrong.join(" · ")}</div>
            <div className="why">{q[lang].why}</div>
          </li>
        ))}
      </ol>
    </details>
  ));
}

function Pearl({pearl, lang}) {
  return pearl.bands.map((band, b) => (
    <details key={b} open={b === 0}>
      <summary>{b < 3 ? BANDS[b] : "One Breath"} · {band.length} prompts</summary>
      <ol className="quiz">
        {band.map((p) => (
          <li key={p.id}>
            <div className="q">{p[lang].ask} <small>level {p.level} · {p.answers.length} answers</small></div>
            {[0, 1, 2, 3].map((t) => {
              const got = p.answers.filter((a) => a.t === t);
              return got.length === 0 ? null :
                <div key={t} className="tier"><small>tier {t}</small> {got.map((a) => a[lang].join(" / ")).join(" · ")}</div>;
            })}
          </li>
        ))}
      </ol>
    </details>
  ));
}

function Section({title, note, children}) {
  return <section><h2>{title}</h2>{note && <p className="note">{note}</p>}{children}</section>;
}

export default function App() {
  const [day, setDay] = useState(todayUtc());
  const [lang, setLang] = useState("en");
  const [got, setGot] = useState(null);
  const [ports, setPorts] = useState({});
  const [error, setError] = useState(null);

  useEffect(() => {
    let live = true;
    setGot(null);
    setError(null);
    setPorts({});
    readDay(day).then((d) => live && setGot(d), (e) => live && setError(String(e)));
    // The ports are extra: a read that fails leaves the page as it was.
    readPorts(day).then((p) => live && setPorts(p), () => {});
    return () => { live = false; };
  }, [day]);

  const pictures = got?.pictures;
  const vistas = got?.vistas;
  const theme = vistas?.name?.[lang] ?? pictures?.theme;

  return (
    <main>
      <header>
        <button onClick={() => setDay(shiftDay(day, -1))}>◀</button>
        <b>{day}</b>
        <button onClick={() => setDay(shiftDay(day, 1))}>▶</button>
        <button onClick={() => setDay(todayUtc())}>today (UTC)</button>
        <span className="langs">{LANGS.map((l) =>
          <button key={l} className={l === lang ? "on" : ""} onClick={() => setLang(l)}>{l}</button>)}</span>
      </header>

      {error && <p className="error">{error}</p>}
      {!got && !error && <p>Loading…</p>}
      {got && Object.keys(got).length === 0 && <p>Nothing published for {day} yet.</p>}

      {got && Object.keys(got).length > 0 && <>
        <h1>{theme ?? "No theme"} <small>{pictures?.theme}</small></h1>

        {vistas && <Section title="Day card vistas">
          <div className="row">{Object.entries(vistas.times).map(([t, jpg]) =>
            <figure key={t} className="card"><img src={`data:image/jpeg;base64,${jpg}`} alt={t} /><figcaption>{t}</figcaption></figure>)}</div>
        </Section>}

        {pictures && <Section title="Bead pictures" note="As the server saved them; a slot not here is dealt from the board's bank.">
          <div className="row">{Object.entries(pictures.sizes).sort((a, b) => a[0] - b[0]).map(([size, pic]) =>
            <BeadPicture key={size} pic={pic} size={Number(size)} />)}</div>
        </Section>}

        {pictures?.hoops && <Section title="Yarn Hoop">
          <div className="row">{Object.entries(pictures.hoops).map(([b, hoop]) => <Hoop key={b} hoop={hoop} band={Number(b)} port={ports[`hoop${b}_${hoop.id}`]} />)}</div>
        </Section>}

        {pictures?.jellies && <Section title="Gumdrop jellies">
          <GumDefs />
          {Object.entries(pictures.jellies).map(([b, list]) => (
            <div key={b}><h3>{BANDS[b]}</h3><div className="row">{list.map((j, i) => <Jelly key={i} jelly={j} port={ports[`jelly${b}_${j.id}`]} />)}</div></div>
          ))}
        </Section>}

        {pictures?.words && <>
          <Section title="Hidden Word" note="The day's themed words (Easy only); the grid is laid on the phone.">
            <HiddenWord words={pictures.words.hiddenword} lang={lang} />
          </Section>
          <Section title="Word Trail" note="The day's themed words by length; the wheel and crossword are built on the phone.">
            <WordTrail words={pictures.words.wordtrail} lang={lang} />
          </Section>
        </>}

        {got.acorn && <Section title="Golden Acorn" note={`written by: ${got.acorn.source}`}><Acorn acorn={got.acorn} lang={lang} /></Section>}
        {got.pearl && <Section title="Pearl Dive" note={`written by: ${got.pearl.source}`}><Pearl pearl={got.pearl} lang={lang} /></Section>}
      </>}
    </main>
  );
}
