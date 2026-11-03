// Gets a batch of How Big? things ready to make (tools/how_big/batch_things.sh):
// the production pool, so nothing the night already kept is offered again,
// and day files, each {day, theme}, cycling the themes the night has staged.
// Read only; uses this Mac's Application Default Credentials.
//
//   node tools/how_big/batch_prep.mjs [count]     (default 50 day files)
//
// Run again, it adds `count` day files after those there and keeps the
// batch's pool.json, so nothing a run has kept is lost.
import { createRequire } from "node:module";
import { existsSync, mkdirSync, writeFileSync, readdirSync } from "node:fs";
import path from "node:path";

const here = path.dirname(new URL(import.meta.url).pathname);
const root = path.resolve(here, "../..");
const require = createRequire(path.join(root, "server/functions/package.json"));
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const out = path.join(root, "build/how_big_batch");
const count = Number(process.argv[2] ?? 50);
initializeApp({ credential: applicationDefault(), projectId: "daily-games-420bf" });
const db = getFirestore();

const pool = [];
for (const d of (await db.collection("things").get()).docs) {
  try { pool.push(JSON.parse(d.get("json"))); } catch { /* skipped, as the phone skips it */ }
}
const themes = [];
for (const d of (await db.collection("themes").get()).docs) {
  try {
    const t = JSON.parse(d.get("theme"));
    if (t && t.name && t.objects) themes.push({ day: Number(d.id), theme: t });
  } catch { /* a day with no theme */ }
}
if (themes.length === 0) throw new Error("no staged themes in themes/");

mkdirSync(out, { recursive: true });
if (!existsSync(path.join(out, "pool.json"))) {
  writeFileSync(path.join(out, "pool.json"), JSON.stringify(pool));
  writeFileSync(path.join(out, "night_ids.json"), JSON.stringify(pool.map((t) => t.id)));
}
const there = readdirSync(out).filter((f) => /^day-\d+\.json$/.test(f)).length;
for (let i = there; i < there + count; i++) {
  const t = themes[i % themes.length];
  writeFileSync(path.join(out, `day-${String(i + 1).padStart(3, "0")}.json`), JSON.stringify({ day: t.day, theme: t.theme }));
}
console.log(`pool ${pool.length} (the night's), ${themes.length} themes, ${count} day files in ${path.relative(root, out)}`);
