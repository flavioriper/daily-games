// repo.ts: reading the game's own files for the local admin page (`next dev`
// only). Nothing is copied into web/; every load reads the repo as it stands.
import { readFileSync } from "node:fs";
import path from "node:path";

export const REPO = path.resolve(process.cwd(), "..");

export const read = (rel: string) => readFileSync(path.join(REPO, rel), "utf8");

/** A GDScript `const NAME := <literal>` as JSON (numbers, strings, nested arrays). */
export function gdConst<T = unknown>(src: string, name: string): T | null {
  const at = src.search(new RegExp(`^const ${name}\\s*:?=`, "m"));
  if (at < 0) return null;
  let i = src.indexOf("=", at) + 1;
  while (/\s/.test(src[i])) i++;
  let depth = 0;
  let inStr = false;
  let j = i;
  for (; j < src.length; j++) {
    const c = src[j];
    if (inStr) {
      if (c === "\\") j++;
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') inStr = true;
    else if (c === "[" || c === "{") depth++;
    else if (c === "]" || c === "}") depth--;
    if (depth === 0 && (c === "\n" || c === "#") && j > i) break;
    if (depth === 0 && (c === "]" || c === "}")) {
      j++;
      break;
    }
  }
  const lit = src
    .slice(i, j)
    .replace(/#[^\n"]*$/gm, "")
    .replace(/,(\s*[\]}])/g, "$1")
    .trim();
  try {
    return JSON.parse(lit) as T;
  } catch {
    return null;
  }
}

/** A CSV with quoted, multi-line cells (locale/*.csv). */
function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === '"' && text[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (c === '"') q = false;
      else cell += c;
    } else if (c === '"') q = true;
    else if (c === ",") {
      row.push(cell);
      cell = "";
    } else if (c === "\n") {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
    } else if (c !== "\r") cell += c;
  }
  if (cell || row.length) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

let locale: Map<string, string> | null = null;
/** English text for a locale key, from locale/ui.csv and locale/boards.csv. */
export function en(key: string): string {
  if (!locale) {
    locale = new Map();
    for (const file of ["locale/ui.csv", "locale/boards.csv"]) {
      for (const r of parseCsv(read(file)).slice(1)) if (r[0]) locale.set(r[0], (r[1] ?? "").replace(/\\n/g, "\n"));
    }
  }
  return locale.get(key) ?? key;
}

export type GameEntry = { id: string; title: string; skill: string; kind: string; block: string };

/** The menu's grid, in order, from ui/registry.gd's PUZZLES. */
export function registry(): GameEntry[] {
  locale = null; // re-read the CSVs with the registry, so a reload shows edits
  const src = read("ui/registry.gd");
  const start = src.indexOf("const PUZZLES");
  const end = src.indexOf("\nstatic func", start);
  const body = src.slice(start, end);
  const heads = [...body.matchAll(/^\t\t"id": "(\w+)",/gm)];
  return heads.map((m, k) => {
    const block = body.slice(m.index, heads[k + 1]?.index ?? body.length);
    const field = (f: string) => block.match(new RegExp(`^\\t\\t"${f}": "([^"]*)"`, "m"))?.[1] ?? "";
    return { id: m[1], title: field("title"), skill: field("skill"), kind: field("kind"), block };
  });
}
