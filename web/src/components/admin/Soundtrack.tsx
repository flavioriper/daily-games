"use client";
// Soundtrack.tsx: the admin page's soundtrack section. One audio element for
// the whole list; when a track ends the next one plays, in the game's order,
// the way the game's deck moves on (core/music.gd).

import { useEffect, useRef, useState } from "react";
import type { Soundtrack as Data } from "@/lib/soundtrack";

const clock = (s: number | null) => {
  if (s === null || !Number.isFinite(s)) return "–";
  const m = Math.floor(s / 60);
  return `${m}:${String(Math.floor(s % 60)).padStart(2, "0")}`;
};
const mb = (b: number | null) => (b === null ? "–" : `${(b / 1048576).toFixed(2)} MB`);

export default function Soundtrack({ tracks, volume, cross, crossNext, lufs }: Data) {
  const audio = useRef<HTMLAudioElement>(null);
  const [current, setCurrent] = useState<number | null>(null);
  const [playing, setPlaying] = useState(false);
  const [at, setAt] = useState(0);
  const [open, setOpen] = useState<string | null>(null);

  const total = tracks.reduce((s, t) => s + (t.seconds ?? 0), 0);
  const missing = tracks.filter((t) => t.bytes === null);

  const play = (i: number) => {
    const a = audio.current;
    if (!a) return;
    if (current === i) {
      if (a.paused) void a.play();
      else a.pause();
      return;
    }
    setCurrent(i);
    setAt(0);
    a.src = `/admin/music/${tracks[i].id}`;
    void a.play();
  };

  useEffect(() => {
    const a = audio.current;
    if (!a) return;
    const tick = () => setAt(a.currentTime);
    const on = () => setPlaying(true);
    const off = () => setPlaying(false);
    a.addEventListener("timeupdate", tick);
    a.addEventListener("play", on);
    a.addEventListener("pause", off);
    return () => {
      a.removeEventListener("timeupdate", tick);
      a.removeEventListener("play", on);
      a.removeEventListener("pause", off);
    };
  }, []);

  const ended = () => {
    if (current === null) return;
    const next = (current + 1) % tracks.length;
    if (tracks[next].bytes !== null) play(next);
  };

  const seek = (i: number, e: React.MouseEvent<HTMLDivElement>) => {
    const a = audio.current;
    const len = tracks[i].seconds;
    if (!a || current !== i || !len) return;
    const r = e.currentTarget.getBoundingClientRect();
    a.currentTime = ((e.clientX - r.left) / r.width) * len;
  };

  return (
    <section className="card">
      <div className="card-head">
        <div>
          <h2>Soundtrack</h2>
          <p className="dim">
            {tracks.length} tracks, {clock(total)} in all, in the order the game plays them. Each launch starts on the
            track after the last visit&apos;s, and the deck moves on by one when a track runs out or Next is pressed.
          </p>
        </div>
      </div>

      <dl className="facts">
        <div><dt>Default volume</dt><dd>{volume ?? "–"}</dd></div>
        <div><dt>Crossfade</dt><dd>{cross ?? "–"} s</dd></div>
        <div><dt>Crossfade on Next</dt><dd>{crossNext ?? "–"} s</dd></div>
        <div><dt>Loudness</dt><dd>{lufs ?? "–"} LUFS</dd></div>
      </dl>

      {missing.length > 0 && (
        <p className="error">Listed in core/music.gd but missing from assets/music: {missing.map((t) => t.id).join(", ")}</p>
      )}

      <audio ref={audio} onEnded={ended} preload="none" />

      <ol className="playlist">
        {tracks.map((t, i) => {
          const on = current === i;
          return (
            <li key={t.id} className={on ? "on" : ""}>
              <button
                className="play"
                onClick={() => play(i)}
                disabled={t.bytes === null}
                aria-label={on && playing ? `Pause ${t.title}` : `Play ${t.title}`}
              >
                {on && playing ? "❚❚" : "▶"}
              </button>
              <div className="body">
                <div className="line">
                  <span className="n">{t.n}</span>
                  <strong>{t.title}</strong>
                  <code>{t.id}</code>
                  <span className="dim meta">
                    {clock(t.seconds)} · {mb(t.bytes)}
                    {t.letter && ` · take ${t.letter}`}
                  </span>
                  {t.prompt && (
                    <button className="ghost small-btn" onClick={() => setOpen(open === t.id ? null : t.id)}>
                      {open === t.id ? "Hide prompt" : "Prompt"}
                    </button>
                  )}
                </div>
                <div className="progress" onClick={(e) => seek(i, e)} title={on ? "Click to seek" : undefined}>
                  <span style={{ width: on && t.seconds ? `${(at / t.seconds) * 100}%` : "0%" }} />
                </div>
                {on && <p className="dim time">{clock(at)} / {clock(t.seconds)}</p>}
                {open === t.id && <p className="prompt">{t.prompt}</p>}
              </div>
            </li>
          );
        })}
      </ol>
      <p className="dim small">
        Read live from <code>core/music.gd</code>, <code>tools/gen_music.py</code> and <code>assets/music/</code>.
        Reload after changing them.
      </p>
    </section>
  );
}
