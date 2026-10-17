import fs from "node:fs";
import path from "node:path";
import {makeDay as acornDay} from "./acorn";
import {cost, Drawing} from "./generate";
import {BANDS as HOOP_BANDS, HoopPicture, makeHoop} from "./hoop";
import {bankPrompts, cleaned, makeDay as pearlDay, Prompt} from "./pearl";
import {makeJellies} from "./jelly";
import {makeDay as picturesDay} from "./pictures";
import {makeTheme, themed} from "./theme";
import {makeWords} from "./words";

/**
 * The night's work by hand (tools/acorn_day.sh, tools/pearl_day.sh,
 * tools/publish_day.sh):
 *
 *   node lib/cli.js day [game] [yyyymmdd]
 *       prints the day `game` (acorn when not named, or pearl) would
 *       publish: written by the model when OPENROUTER_API_KEY is set, by
 *       the bank when it is not, when DAILY_MODEL=off or where the model
 *       fails. Writes nothing.
 *   node lib/cli.js bank pearl <level> <count> <outfile>
 *       writes <count> new reviewed prompts of that level into Pearl Dive's
 *       bank source (tools/pearl/level<N>.json), after the ones the file
 *       holds, told what all three level files beside it already ask.
 *       tools/build_pearl.py turns the three into content/pearl.json.
 *   node lib/cli.js themed <yyyymmdd> <days> <outdir> [themes-dir]
 *       the theme and the bead pictures of each of those days, as the
 *       night would make them, into <outdir>/<day>.json with every drawing
 *       beside it and what became of each draft: what the dashboard's
 *       Themed days shows (tools/themed_days.sh). A day already there is
 *       not made again. Publishes nothing; costs what the models cost.
 *       With [themes-dir], a day made there lends its theme and only the
 *       pictures are new (DAILY_PICTURE_STYLE=pixel against the first way).
 *   node lib/cli.js quizzes <day.json>...
 *       Golden Acorn's and Pearl Dive's days on each file's theme (two or
 *       three questions a band, three prompts a day), into the file as
 *       `quizzes`, for the dashboard. The night's reviewer reads them, so
 *       this costs what a published day does.
 *   node lib/cli.js words <day.json>...
 *       Hidden Word's and Word Trail's words (words.ts) for days the
 *       command above made, into each file's pictures document; the
 *       pictures and the jellies are left as they are.
 *   node lib/cli.js publish
 *       runs publishDays for today and tomorrow against whatever project
 *       the credentials name -- the day a game ships on, which the 03:00
 *       scheduler never reaches. Run by a person.
 */

const DAYS: Record<string, (day: number) => Promise<unknown>> = {
  acorn: (day) => acornDay(day),
  pearl: (day) => pearlDay(day),
};

function readList(file: string): Prompt[] {
  if (!fs.existsSync(file)) return [];
  const got = JSON.parse(fs.readFileSync(file, "utf8"));
  return Array.isArray(got) ? got : [];
}

/** Pearl Dive's bank, grown by `count` prompts of `level`. */
async function growBank(level: number, count: number, outfile: string): Promise<string> {
  const held = readList(outfile);
  const taken: string[] = [];
  for (let l = 0; l < 3; l++) {
    for (const p of readList(path.join(path.dirname(outfile), `level${l}.json`))) taken.push(p.en.ask);
  }
  let top = 0;
  for (const p of held) top = Math.max(top, Number(p.id.slice(1)) || 0);
  const letter = "emh"[level];
  const fresh = await bankPrompts(level, count, taken,
    (n) => `${letter}${String(top + 1 + n).padStart(3, "0")}`);
  // One prompt a line: the file is read and mended by hand.
  const all = [...held, ...fresh].map((p) => cleaned(p)).filter((p): p is Prompt => p !== null);
  fs.writeFileSync(outfile, `[\n${all.map((p) => JSON.stringify(p)).join(",\n")}\n]\n`);
  return `${outfile}: ${fresh.length} new, ${all.length} in all`;
}

/** Keeps each drawing as a file beside the day's, for the dashboard. */
function drawingsBeside(file: string): (name: string, d: Drawing) => void {
  return (name, d) => fs.writeFileSync(path.join(path.dirname(file), `${name}.${d.mime === "image/png" ? "png" : "jpg"}`), d.bytes);
}

/** The days from `first`, each told the themes before it. */
async function themedDays(first: number, count: number, outdir: string, themesFrom?: string): Promise<string> {
  fs.mkdirSync(outdir, {recursive: true});
  const start = Date.UTC(Math.floor(first / 10000), Math.floor(first / 100) % 100 - 1, first % 100);
  const recent: string[] = [];
  for (const f of fs.readdirSync(outdir).filter((n) => /^\d{8}\.json$/.test(n)).sort()) {
    recent.unshift(...themed(JSON.parse(fs.readFileSync(path.join(outdir, f), "utf8")).theme));
  }
  let made = 0;
  for (let i = 0; i < count; i++) {
    const when = new Date(start + i * 86400000);
    const day = when.getUTCFullYear() * 10000 + (when.getUTCMonth() + 1) * 100 + when.getUTCDate();
    const file = path.join(outdir, `${day}.json`);
    if (fs.existsSync(file)) continue;
    const before = cost();
    const t0 = Date.now();
    // A day another run made lends its theme, so two ways of drawing are
    // seen on the same one.
    const lent = themesFrom === undefined ? "" : path.join(themesFrom, `${day}.json`);
    const theme = lent !== "" && fs.existsSync(lent) ? JSON.parse(fs.readFileSync(lent, "utf8")).theme :
      await makeTheme(day, recent.slice(0, 60));
    const pictures = theme === null ? {doc: null, drafts: []} : await picturesDay(day, theme, (name, d) => {
      const kept = `${name}.${d.mime === "image/png" ? "png" : "jpg"}`;
      fs.writeFileSync(path.join(outdir, kept), d.bytes);
      return kept;
    });
    // Gumdrop's jellies ride in the same document (jelly.ts).
    const jelly = theme === null ? {jellies: {}, tries: []} : await makeJellies(day, theme);
    if (Object.keys(jelly.jellies).length > 0) {
      pictures.doc = {...(pictures.doc ?? {v: 1 as const, theme: theme.id, sizes: {}}), jellies: jelly.jellies};
    }
    // And the word boards' (words.ts).
    const words = theme === null ? {words: null, tries: []} : await makeWords(theme);
    if (words.words !== null) {
      pictures.doc = {...(pictures.doc ?? {v: 1 as const, theme: theme.id, sizes: {}}), words: words.words};
    }
    fs.writeFileSync(file, JSON.stringify({day, theme, pictures: pictures.doc, drafts: pictures.drafts, jellyTries: jelly.tries,
      wordsTries: words.tries,
      cost: Math.round((cost() - before) * 10000) / 10000, seconds: Math.round((Date.now() - t0) / 1000)}));
    if (theme !== null) recent.unshift(...themed(theme));
    made++;
  }
  return `${outdir}: ${made} days made, US$${cost().toFixed(2)}`;
}

async function main(): Promise<void> {
  // What is printed is the day and nothing else: the makers' own lines go
  // to the other stream.
  const print = console.log;
  console.log = console.error;
  const args = process.argv.slice(2);
  const what = args.shift();
  if (what === "day") {
    const game = args.length > 0 && DAYS[args[0]] !== undefined ? args.shift() as string : "acorn";
    const now = new Date();
    const today = now.getUTCFullYear() * 10000 + (now.getUTCMonth() + 1) * 100 + now.getUTCDate();
    const day = args[0] ? Number(args[0]) : today;
    print(JSON.stringify(await DAYS[game](day), null, 1));
  } else if (what === "bank" && args[0] === "pearl" && args.length === 4) {
    print(await growBank(Number(args[1]), Number(args[2]), args[3]));
  } else if (what === "themed" && (args.length === 3 || args.length === 4)) {
    print(await themedDays(Number(args[0]), Number(args[1]), args[2], args[3]));
  } else if (what === "quizzes" && args.length >= 1) {
    // Golden Acorn's and Pearl Dive's days on the theme of days already
    // made, beside the rest as `quizzes`, for Themed days; not what a
    // phone reads (stage 4 publishes them as the two games' own days).
    for (const file of args) {
      const day = JSON.parse(fs.readFileSync(file, "utf8"));
      if (day.theme === null) continue;
      const before = cost();
      const acorn = await acornDay(day.day, [], day.theme);
      const pearl = await pearlDay(day.day, [], day.theme);
      day.quizzes = {acorn, pearl, cost: Math.round((cost() - before) * 10000) / 10000};
      fs.writeFileSync(file, JSON.stringify(day));
      const on = (bands: {id: string}[][], t: RegExp) => bands.map((b) => b.filter((q) => t.test(q.id)).length).join("/");
      print(`${file}: acorn ${acorn.source}, themed ${on(acorn.bands, /b\dt\d+$/)}; pearl ${pearl.source}, ` +
        `themed ${on(pearl.bands, /t$/)}; US$${cost().toFixed(2)} so far`);
    }
  } else if (what === "words" && args.length >= 1) {
    // The word boards' words for days already made, the rest untouched.
    for (const file of args) {
      const day = JSON.parse(fs.readFileSync(file, "utf8"));
      if (day.theme === null) continue;
      const got = await makeWords(day.theme);
      if (got.words !== null) {
        day.pictures = {...(day.pictures ?? {v: 1, theme: day.theme.id, sizes: {}}), words: got.words};
      } else if (day.pictures) {
        delete day.pictures.words;
      }
      day.wordsTries = got.tries;
      fs.writeFileSync(file, JSON.stringify(day));
      const w = got.words;
      print(`${file}: ${w === null ? "none" : (["en", "pt", "es"] as const).map((l) =>
        `${l} hidden ${w.hiddenword[l].join("/") || "-"} trail ${Object.values(w.wordtrail[l]).flat().join("/") || "-"}`).join("; ")}, US$${cost().toFixed(2)} so far`);
    }
  } else if (what === "jellies" && args.length >= 1) {
    // Gumdrop's jellies for days already made, their pictures untouched.
    for (const file of args) {
      const day = JSON.parse(fs.readFileSync(file, "utf8"));
      if (day.theme === null) continue;
      const jelly = await makeJellies(day.day, day.theme, undefined, drawingsBeside(file));
      if (Object.keys(jelly.jellies).length > 0) {
        day.pictures = {...(day.pictures ?? {v: 1, theme: day.theme.id, sizes: {}}), jellies: jelly.jellies};
      } else if (day.pictures) {
        delete day.pictures.jellies;
      }
      day.jellyTries = jelly.tries;
      fs.writeFileSync(file, JSON.stringify(day));
      print(`${file}: ${Object.entries(jelly.jellies).map(([b, l]) => `${b}:${l.length}`).join(" ") || "none"} in ${jelly.tries.length} tries, US$${cost().toFixed(2)} so far`);
    }
  } else if (what === "hoops" && args.length >= 1) {
    // Yarn Hoop's low-poly pictures for days already made (hoop.ts).
    for (const file of args) {
      const day = JSON.parse(fs.readFileSync(file, "utf8"));
      if (day.theme === null) continue;
      const hoops: Record<string, HoopPicture> = {};
      for (let band = 0; band < HOOP_BANDS.length; band++) {
        const got = await makeHoop(day.day, day.theme, band, drawingsBeside(file));
        if (got !== null) hoops[band] = got;
      }
      if (Object.keys(hoops).length > 0) {
        day.pictures = {...(day.pictures ?? {v: 1, theme: day.theme.id, sizes: {}}), hoops};
      }
      fs.writeFileSync(file, JSON.stringify(day));
      print(`${file}: hoops ${Object.entries(hoops).map(([b, h]) => `${b}:${h.id} ${h.panels.length}`).join(" ") || "none"}`);
    }
  } else if (what === "publish") {
    // Loaded here and not at the top: index.ts wakes the admin SDK, which a
    // dry run has no credentials for and no use of.
    const {publishDays} = await import("./index");
    await publishDays(new Date());
    print("published");
  } else {
    console.error("usage: cli.js day [acorn|pearl] [yyyymmdd] | bank pearl <level> <count> <outfile> | themed <yyyymmdd> <days> <outdir> [themes-dir] | jellies <day.json>... | hoops <day.json>... | words <day.json>... | quizzes <day.json>... | publish");
    process.exitCode = 2;
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
