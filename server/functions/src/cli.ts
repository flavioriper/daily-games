import fs from "node:fs";
import path from "node:path";
import {makeDay as acornDay} from "./acorn";
import {bankPuzzles, makeDay as shelvesDay, Puzzle as ShelvesPuzzle} from "./shelves";
import {bankRounds, makeDay as cluesDay, Round as CluesRound} from "./clues";
import {cost, Drawing} from "./generate";
import {BANDS as HOOP_BANDS, HoopPicture, makeHoop} from "./hoop";
import {bankPrompts, cleaned, makeDay as pearlDay, Prompt} from "./pearl";
import {makeJellies} from "./jelly";
import type {Port} from "./ports";
import {makeDay as picturesDay} from "./pictures";
import {describe, eligible, seeded} from "./cast";
import {makeTheme, themed} from "./theme";
import {makeWords} from "./words";
import {makeVista, TIMES as VISTA_TIMES, Vistas} from "./vistas";

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
 *   node lib/cli.js vistas <day.json>...
 *       the day's four painted vistas (vistas.ts) for days already made:
 *       each painting beside the file as <day>_vista-<time>-<try>.jpg, the
 *       reviewer's word on each in `vistaTries`, and what a phone would be
 *       sent in `vistas` when all four passed (tools/themed_play.sh).
 *   node lib/cli.js words <day.json>...
 *       Hidden Word's and Word Trail's words (words.ts) for days the
 *       command above made, into each file's pictures document; the
 *       pictures and the jellies are left as they are.
 *   node lib/cli.js cast <yyyymmdd>
 *       the day's two Peeplets (cast.ts) and what a painter is told of
 *       each; the phone seeds the same pair (core/cast.gd).
 *   node lib/cli.js publish
 *       runs publishDays for today and tomorrow against whatever project
 *       the credentials name -- the day a game ships on, which the 03:00
 *       scheduler never reaches. Run by a person.
 */

const DAYS: Record<string, (day: number) => Promise<unknown>> = {
  acorn: (day) => acornDay(day),
  pearl: (day) => pearlDay(day),
  shelves: (day) => shelvesDay(day),
  clues: (day) => cluesDay(day),
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

/** Four Shelves' bank (content/shelves.json), grown by `count` reviewed
 *  puzzles of `band`, told every group the bank already uses. */
async function growShelves(band: number, count: number, into?: string): Promise<string> {
  const file = into ?? path.join(__dirname, "../../../content/shelves.json");
  const held: {tiers: ShelvesPuzzle[][]} = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {tiers: [[], [], [], []]};
  const taken = held.tiers.flat().flatMap((p) => p.en.groups.map((g) => g.label));
  let top = 0;
  for (const p of held.tiers[band]) top = Math.max(top, Number(p.id.slice(2)) || 0);
  const fresh = await bankPuzzles(band, count, taken, (n) => `${"emhi"[band]}b${String(top + 1 + n).padStart(3, "0")}`);
  held.tiers[band].push(...fresh);
  // One puzzle a line: the file is read and mended by hand.
  fs.writeFileSync(file, `{"tiers": [\n${held.tiers.map((t) => `[\n${t.map((p) => JSON.stringify(p)).join(",\n")}\n]`).join(",\n")}\n]}\n`);
  return `${file}: band ${band} ${fresh.length} new, ${held.tiers[band].length} in all, US$${cost().toFixed(2)}`;
}

/** Five Clues' bank (content/clues.json), grown by `count` reviewed rounds
 *  of `tier`, told every idea the bank already uses. */
async function growClues(tier: number, count: number, into?: string): Promise<string> {
  const file = into ?? path.join(__dirname, "../../../content/clues.json");
  const held: {tiers: CluesRound[][]} = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {tiers: [[], [], []]};
  const taken = held.tiers.flat().map((r) => r.en.label);
  let top = 0;
  for (const r of held.tiers[tier]) top = Math.max(top, Number(r.id.slice(2)) || 0);
  const fresh = await bankRounds(tier, count, taken, (n) => `${"emh"[tier]}k${String(top + 1 + n).padStart(3, "0")}`);
  held.tiers[tier].push(...fresh);
  fs.writeFileSync(file, `{"tiers": [\n${held.tiers.map((t) => `[\n${t.map((r) => JSON.stringify(r)).join(",\n")}\n]`).join(",\n")}\n]}\n`);
  return `${file}: tier ${tier} ${fresh.length} new, ${held.tiers[tier].length} in all, US$${cost().toFixed(2)}`;
}

/** Keeps each drawing as a file beside the day's, for the dashboard. */
function drawingsBeside(file: string): (name: string, d: Drawing) => void {
  return (name, d) => fs.writeFileSync(path.join(path.dirname(file), `${name}.${d.mime === "image/png" ? "png" : "jpg"}`), d.bytes);
}

/** A night's ports for a day's JSON: the drawing and render are already
 *  files beside it, so they are left out. */
function bare(ports: Port[]): Omit<Port, "source" | "render">[] {
  return ports.map(({source, render, ...rest}) => rest);
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
    const jelly = theme === null ? {jellies: {}, tries: [], ports: []} : await makeJellies(day, theme);
    if (Object.keys(jelly.jellies).length > 0) {
      pictures.doc = {...(pictures.doc ?? {v: 1 as const, theme: theme.id, sizes: {}}), jellies: jelly.jellies};
    }
    // And the word boards' (words.ts).
    const words = theme === null ? {words: null, tries: []} : await makeWords(theme);
    if (words.words !== null) {
      pictures.doc = {...(pictures.doc ?? {v: 1 as const, theme: theme.id, sizes: {}}), words: words.words};
    }
    fs.writeFileSync(file, JSON.stringify({day, theme, pictures: pictures.doc, drafts: pictures.drafts, jellyTries: jelly.tries,
      jellyPorts: bare(jelly.ports), hoopPorts: [],
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
  } else if (what === "bank" && args[0] === "shelves" && (args.length === 3 || args.length === 4)) {
    // node lib/cli.js bank shelves <band> <count> [file]: grows
    // content/shelves.json, or [file] (bands grown side by side, merged after)
    print(await growShelves(Number(args[1]), Number(args[2]), args[3]));
  } else if (what === "bank" && args[0] === "clues" && (args.length === 3 || args.length === 4)) {
    // node lib/cli.js bank clues <tier> <count> [file]: grows content/clues.json
    print(await growClues(Number(args[1]), Number(args[2]), args[3]));
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
  } else if (what === "vistas" && args.length >= 1) {
    // The painted vistas for days already made, the rest untouched.
    for (const file of args) {
      const day = JSON.parse(fs.readFileSync(file, "utf8"));
      if (day.theme === null) continue;
      const keep = (name: string, d: {bytes: Buffer}) => {
        // The painter's full-size painting (the bench's) is a PNG, the phone's JPEG a JPEG.
        const kept = `${day.day}_${name}.${name.endsWith("-full") ? "png" : "jpg"}`;
        fs.writeFileSync(path.join(path.dirname(file), kept), d.bytes);
        return kept;
      };
      const times: Record<string, string> = {};
      const tries: {time: string; name: string; wrong: string; peeplets: number; size: string}[] = [];
      const pair = seeded(day.day);
      let morning = null;
      for (const time of VISTA_TIMES) {
        const got = await makeVista(day.day, day.theme, time, morning, keep, 2, pair);
        tries.push(...got.tries.map((t) => ({time, name: `${day.day}_${t.name}.jpg`, wrong: t.wrong, peeplets: t.peeplets, size: t.size})));
        for (const t of got.tries) print(`  ${time} ${t.name}: ${t.size}, ${t.peeplets} Peeplets, ${t.wrong === "" ? "passed" : `turned down: ${t.wrong}`}`);
        if (got.vista === null) break;
        if (time === "morning") morning = got.vista;
        times[time] = got.vista.bytes.toString("base64");
      }
      day.vistaTries = tries;
      if (Object.keys(times).length === VISTA_TIMES.length) {
        day.vistas = {v: 1, theme: day.theme.id, name: day.theme.name, times} as Vistas;
      } else {
        delete day.vistas;
      }
      fs.writeFileSync(file, JSON.stringify(day));
      print(`${file}: ${day.vistas ? "four vistas" : `stopped at ${VISTA_TIMES[Object.keys(times).length]}`} in ${tries.length} paintings, ` +
        tries.filter((t) => t.wrong !== "").map((t) => `${t.time}: ${t.wrong}`).join("; "));
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
      day.jellyPorts = bare(jelly.ports);
      fs.writeFileSync(file, JSON.stringify(day));
      print(`${file}: ${Object.entries(jelly.jellies).map(([b, l]) => `${b}:${l.length}`).join(" ") || "none"} in ${jelly.tries.length} tries, US$${cost().toFixed(2)} so far`);
    }
  } else if (what === "hoops" && args.length >= 1) {
    // Yarn Hoop's low-poly pictures for days already made (hoop.ts).
    for (const file of args) {
      const day = JSON.parse(fs.readFileSync(file, "utf8"));
      if (day.theme === null) continue;
      const hoops: Record<string, HoopPicture> = {};
      const ports: Port[] = [];
      for (let band = 0; band < HOOP_BANDS.length; band++) {
        const {picture, port} = await makeHoop(day.day, day.theme, band, drawingsBeside(file));
        if (picture !== null) hoops[band] = picture;
        ports.push(port);
      }
      day.hoopPorts = bare(ports);
      if (Object.keys(hoops).length > 0) {
        day.pictures = {...(day.pictures ?? {v: 1, theme: day.theme.id, sizes: {}}), hoops};
      }
      fs.writeFileSync(file, JSON.stringify(day));
      print(`${file}: hoops ${Object.entries(hoops).map(([b, h]) => `${b}:${h.id} ${h.panels.length}`).join(" ") || "none"}`);
    }
  } else if (what === "cast" && args.length === 1) {
    // The day's two Peeplets, as the night and the phone seed them (cast.ts).
    const day = Number(args[0]);
    const pair = seeded(day);
    print(`${day}: [${pair[0]}, ${pair[1]}] of ${eligible().length} eligible\n  ${describe(pair[0])}\n  ${describe(pair[1])}`);
  } else if (what === "publish") {
    // Loaded here and not at the top: index.ts wakes the admin SDK, which a
    // dry run has no credentials for and no use of.
    const {publishDays} = await import("./index");
    await publishDays(new Date());
    print("published");
  } else {
    console.error("usage: cli.js day [acorn|pearl] [yyyymmdd] | bank pearl <level> <count> <outfile> | themed <yyyymmdd> <days> <outdir> [themes-dir] | cast <yyyymmdd> | vistas <day.json>... | jellies <day.json>... | hoops <day.json>... | words <day.json>... | quizzes <day.json>... | publish");
    process.exitCode = 2;
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
