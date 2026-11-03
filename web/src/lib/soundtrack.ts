// soundtrack.ts: the game's soundtrack as it is in the repo right now, for the
// local admin page (src/app/admin, `next dev` only). Nothing here is copied:
// core/music.gd gives the order and titles the game plays, tools/gen_music.py
// the prompt each take was made from, assets/music the files themselves.
import { execFileSync } from "node:child_process";
import { readFileSync, statSync } from "node:fs";
import path from "node:path";

export const REPO = path.resolve(process.cwd(), "..");
export const MUSIC_DIR = path.join(REPO, "assets/music");

export type Track = {
  n: number;
  id: string;
  title: string;
  letter: string | null;
  prompt: string | null;
  seconds: number | null;
  bytes: number | null;
};

export type Soundtrack = {
  tracks: Track[];
  volume: number | null;
  cross: number | null;
  crossNext: number | null;
  lufs: number | null;
};

function num(src: string, re: RegExp): number | null {
  const m = src.match(re);
  return m ? Number(m[1]) : null;
}

function seconds(file: string): number | null {
  try {
    const out = execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file], {
      encoding: "utf8",
    });
    return Number(out.trim()) || null;
  } catch {
    return null;
  }
}

export function readSoundtrack(): Soundtrack {
  const music = readFileSync(path.join(REPO, "core/music.gd"), "utf8");
  const gen = readFileSync(path.join(REPO, "tools/gen_music.py"), "utf8");
  const made = new Map<string, { letter: string; prompt: string }>();
  for (const m of gen.matchAll(/"(\w+)": \("(\w+)", "[^"]*",\s*'([^']*)'\)/g)) {
    made.set(m[1], { letter: m[2], prompt: m[3] });
  }
  const tracks: Track[] = [];
  for (const m of music.matchAll(/\{"id": "(\w+)", "title": "([^"]+)"\}/g)) {
    const file = path.join(MUSIC_DIR, `${m[1]}.ogg`);
    let bytes: number | null = null;
    try {
      bytes = statSync(file).size;
    } catch {
      /* listed in the game but the file is missing: the page says so */
    }
    tracks.push({
      n: tracks.length + 1,
      id: m[1],
      title: m[2],
      letter: made.get(m[1])?.letter ?? null,
      prompt: made.get(m[1])?.prompt ?? null,
      seconds: bytes === null ? null : seconds(file),
      bytes,
    });
  }
  return {
    tracks,
    volume: num(music, /^const VOLUME := ([\d.]+)/m),
    cross: num(music, /^const CROSS := ([\d.]+)/m),
    crossNext: num(music, /^const CROSS_NEXT := ([\d.]+)/m),
    lufs: num(gen, /^LUFS = (-?[\d.]+)/m),
  };
}
