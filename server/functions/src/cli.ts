import fs from "node:fs";
import path from "node:path";
import {makeDay as acornDay} from "./acorn";
import {bankPuzzles, makeDay as shelvesDay, Puzzle as ShelvesPuzzle} from "./shelves";
import {bankRounds, makeDay as cluesDay, Round as CluesRound} from "./clues";
import {anthropicModel, cost, draw, Drawing, modelFor, tokens} from "./generate";
import {BANDS as HOOP_BANDS, HoopPicture, makeHoop} from "./hoop";
import {bankPrompts, cleaned, makeDay as pearlDay, Prompt} from "./pearl";
import {makeJellies} from "./jelly";
import type {Port} from "./ports";
import {makeDay as picturesDay} from "./pictures";
import {describe, eligible, seeded} from "./cast";
import {makeTheme, themed} from "./theme";
import {makeWords} from "./words";
import {FULL_SUFFIX, makeVista, reviewPainting, rubricHash, shrunk, Time, TIMES as VISTA_TIMES, Vistas, vistaModel} from "./vistas";

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
 *   node lib/cli.js theme <yyyymmdd> <out.json> [recent-day.json | text to avoid]...
 *       the day's theme alone, as {day, theme}, told not to repeat the
 *       themes of the recent files named (the Peeplet bench's days).
 *   node lib/cli.js decoys <painting.png> <out-dir> [defect...]
 *       the painting edited once for each defect in DEFECTS (or those named),
 *       as decoy-<n>-<defect>.png and a phone-size .jpg beside it: paintings
 *       that must be turned down, for the bench the reviewer is judged on.
 *   node lib/cli.js review-bench <bench-dir> [--rescore] [--pass N] [--only <file.jpg>...]
 *       the night's reviewer (vistas.ts reviewPainting) over every painting in
 *       the Peeplet bench, scored against labels.json into <bench-dir>/report.json
 *       (tools/days/peeplet-bench/README.md). Unlabelled files are reviewed too and
 *       listed, not scored. --rescore reads report.json's verdicts again against
 *       the labels as they are now, with no review. Runs on Anthropic's API.
 *       --only reviews just the named .jpg files (names, not paths) and merges
 *       their verdicts into report.json's, then rescores everything: a few
 *       new decoys cost a few cents, not a pass. It refuses when the rubric
 *       changed since the report.
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

/** What the bench's decoys are made to show: [name, the edit, subtle]. The
 *  last two are subtle: the reviewer may miss them, and the user labels them. */
export const DEFECTS: [string, string, boolean?][] = [
  ["third-arm", "give one Peeplet a third arm"],
  ["missing-leg", "remove one of a Peeplet's legs"],
  ["fingers", "give a Peeplet human hands with fingers"],
  ["human", "replace one Peeplet with a small human child"],
  ["neck", "give a Peeplet a long neck"],
  ["fused", "fuse a Peeplet's arm into its body so it melts in", true],
  ["long-arm", "make one Peeplet's arm slightly longer than the other", true],
];

interface Label {verdict: "pass" | "fail"; defect: string; subtle: boolean}
interface Verdict {wrong: string; peeplets: number}

/** The bench's scores of `verdicts` against `labels` (labelled files only;
 *  a file whose review errored is counted apart and judged neither way). */
export function scoreBench(labels: Record<string, Label>, verdicts: Record<string, Verdict>) {
  const deformedPassed: string[] = [], goodRejected: string[] = [], subtlePassed: string[] = [];
  const countErrors: string[] = [], errors: string[] = [];
  let passLabelled = 0;
  for (const [file, label] of Object.entries(labels)) {
    const v = verdicts[file];
    if (v === undefined) continue;
    if (label.verdict === "pass") passLabelled++;
    if (v.wrong.startsWith("ERROR:")) {
      errors.push(file);
      continue;
    }
    if (label.verdict === "fail" && v.wrong === "") (label.subtle ? subtlePassed : deformedPassed).push(file);
    if (label.verdict === "pass" && v.wrong !== "") goodRejected.push(file);
    if (label.verdict === "pass" && v.peeplets !== 2) countErrors.push(file);
  }
  return {deformedPassed, goodRejected, countErrors, subtlePassed, errors, passLabelled};
}

/** The bench's day-of-file, time and morning (the day's morning that passed at paint time). */
function benchFile(dir: string, file: string): {theme: Day["theme"]; time: Time; image: Drawing; morning: Drawing | null} {
  const [day, rest] = file.split("_");
  const time = /^vista-(morning|afternoon|dusk|night)-/.exec(rest)?.[1] as Time;
  const info = JSON.parse(fs.readFileSync(path.join(dir, `${day}.json`), "utf8")) as Day;
  const named = (f: string): Drawing => {
    const bytes = fs.readFileSync(path.join(dir, f));
    return {mime: bytes[0] === 0x89 ? "image/png" : "image/jpeg", bytes};
  };
  const base = file.replace(/\.jpg$/, "");
  // The painter's full-size PNG when it is on disk (a painting's `-full`, a decoy's own), else the JPEG.
  const full = [base.includes("_decoy-") ? `${base}.png` : `${base}${FULL_SUFFIX}.png`, file].find((f) => fs.existsSync(path.join(dir, f))) as string;
  let morning: Drawing | null = null;
  if (time !== "morning") {
    // At paint time the reviewer saw the morning as shrunk for the phone: its JPEG.
    const m = info.vistaTries.find((t) => t.time === "morning" && t.wrong === "");
    if (m === undefined) throw new Error(`${file}: its day has no morning that passed`);
    morning = named(m.name);
  }
  return {theme: info.theme, time, image: named(full), morning};
}

interface Day {day: number; theme: import("./theme").Theme; vistaTries: {time: string; name: string; wrong: string; peeplets: number}[]}

/** review-bench: the reviewer over every painting in `dir`, scored, into report.json. */
async function reviewBench(dir: string, rescore: boolean, passArg: number | null, only: string[] | null, print: (s: string) => void): Promise<void> {
  const labels = JSON.parse(fs.readFileSync(path.join(dir, "labels.json"), "utf8")) as Record<string, Label>;
  const reportFile = path.join(dir, "report.json");
  const before = fs.existsSync(reportFile) ? JSON.parse(fs.readFileSync(reportFile, "utf8")) : null;
  let verdicts: Record<string, Verdict> = {};
  let spend = {costUsd: 0, inputTokens: 0, outputTokens: 0};
  if (rescore && only !== null) throw new Error("--rescore and --only do not go together");
  if (rescore) {
    if (before === null) throw new Error("no report.json to rescore");
    verdicts = before.verdicts;
    spend = {costUsd: before.costUsd, inputTokens: before.inputTokens ?? 0, outputTokens: before.outputTokens ?? 0};
  } else {
    // Anthropic direct only: OpenRouter has no credit, and a silent fall to it is a bug, not a retry.
    const model = modelFor("review");
    if (anthropicModel(model) === null) throw new Error(`the reviewer (${model}) would not go to Anthropic's API: ANTHROPIC_API_KEY unset or the model not anthropic/*`);
    const files = fs.readdirSync(dir).filter((f) => /^\d{8}_vista-.*\.jpg$/.test(f)).sort();
    if (only !== null) {
      // The named files only, merged into the report's verdicts: the rest keep their word, so the rubric must be the one that gave it.
      if (before === null) throw new Error("--only needs a report.json to merge into");
      if (before.rubric !== rubricHash()) throw new Error("the rubric changed since report.json: review the whole bench (without --only)");
      const missing = only.filter((f) => !files.includes(f));
      if (missing.length > 0) throw new Error(`not in the bench: ${missing.join(", ")}`);
      verdicts = before.verdicts;
      files.splice(0, files.length, ...only);
    }
    for (const file of files) {
      const {theme, time, image, morning} = benchFile(dir, file);
      let got: Verdict | null = null;
      for (let attempt = 0; attempt < 2 && got === null; attempt++) {
        try {
          got = await reviewPainting(theme, time, image, morning);
        } catch (e) {
          const msg = String(e).replace(/sk-[A-Za-z0-9_-]+/g, "sk-…").slice(0, 200);
          console.error(`review-bench: ${file} attempt ${attempt}: ${msg}`);
          if (attempt === 0) await new Promise((r) => setTimeout(r, 20000));
          else got = {wrong: `ERROR: ${msg}`, peeplets: 0};
        }
      }
      verdicts[file] = got as Verdict;
      const label = labels[file];
      print(`${file.padEnd(52)} ${label === undefined ? "unlabelled" : `${label.verdict}${label.defect === "" ? "" : "/" + label.defect}${label.subtle ? "(subtle)" : ""}`.padEnd(14)} ` +
        `${verdicts[file].wrong === "" ? "PASSED" : "turned down"} ${verdicts[file].peeplets}P  ${verdicts[file].wrong.slice(0, 110)}`);
    }
    const t = tokens();
    // With --only, this run's spend is added to the report's.
    const base = only !== null ? {costUsd: before.costUsd, inputTokens: before.inputTokens ?? 0, outputTokens: before.outputTokens ?? 0} : {costUsd: 0, inputTokens: 0, outputTokens: 0};
    spend = {costUsd: Math.round((base.costUsd + cost()) * 10000) / 10000, inputTokens: base.inputTokens + t.input, outputTokens: base.outputTokens + t.output};
  }
  const score = scoreBench(labels, verdicts);
  const unlabelled = Object.fromEntries(Object.entries(verdicts).filter(([f]) => labels[f] === undefined));
  const report = {
    pass: rescore || only !== null ? before.pass : passArg ?? (before?.pass ?? 0) + 1,
    rubric: rescore || only !== null ? before.rubric : rubricHash(),
    deformedPassed: score.deformedPassed, goodRejected: score.goodRejected, countErrors: score.countErrors.length,
    countErrorFiles: score.countErrors, subtlePassed: score.subtlePassed, errors: score.errors,
    passLabelled: score.passLabelled, ...spend, unlabelled, verdicts,
  };
  fs.writeFileSync(reportFile, JSON.stringify(report, null, 1) + "\n");
  const gate = score.deformedPassed.length === 0 && score.goodRejected.length / Math.max(1, score.passLabelled) < 1 / 3;
  print(`pass ${report.pass}${rescore ? " (rescored)" : ""}: deformed passed ${score.deformedPassed.length} ${JSON.stringify(score.deformedPassed)}, ` +
    `subtle passed ${score.subtlePassed.length}, good rejected ${score.goodRejected.length}/${score.passLabelled}, ` +
    `count errors ${score.countErrors.length}, review errors ${score.errors.length}, unlabelled ${Object.keys(unlabelled).length}; ` +
    `tokens ${spend.inputTokens} in / ${spend.outputTokens} out, counted US$${spend.costUsd}; gate ${gate ? "HOLDS" : "FAILS"}`);
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
  } else if (what === "theme" && args.length >= 2) {
    // The day's theme alone, for the bench's days.
    // A file names a theme to avoid; anything else is a line of text to avoid.
    const recent = args.slice(2).flatMap((f) => f.endsWith(".json") ? themed(JSON.parse(fs.readFileSync(f, "utf8")).theme) : [f]);
    const theme = await makeTheme(Number(args[0]), recent);
    if (theme === null) {
      console.error("theme: none");
      process.exitCode = 1;
    } else {
      fs.writeFileSync(args[1], JSON.stringify({day: Number(args[0]), theme}));
      print(`${args[0]}: ${theme.name.en}: ${theme.scene}\n  cast: ${theme.cast ?? "-"}\n  US$${cost().toFixed(2)} so far`);
    }
  } else if (what === "decoys" && args.length >= 2) {
    // One edit of the painting a defect, for the bench's decoys.
    const picked = args.slice(2);
    const painting: Drawing = {mime: "image/png", bytes: fs.readFileSync(args[0])};
    fs.mkdirSync(args[1], {recursive: true});
    for (const [n, [name, edit]] of DEFECTS.entries()) {
      if (picked.length > 0 && !picked.includes(name)) continue;
      const base = path.join(args[1], `decoy-${n + 1}-${name}`);
      const prefix = path.basename(args[0]).replace(/\.png$/, "").replace(/-full$/, "");
      const out = `${prefix}_${path.basename(base)}`;
      try {
        const got = await draw(`Edit the attached painting: ${edit}. Change nothing else.`, vistaModel(), {images: [painting], aspect: "21:9"});
        fs.writeFileSync(path.join(args[1], `${out}.png`), got.bytes);
        fs.writeFileSync(path.join(args[1], `${out}.jpg`), shrunk(got).bytes);
        print(`${out}: ${edit}; US$${cost().toFixed(2)} so far`);
      } catch (e) {
        console.error(`decoys: ${out} failed`, e);
      }
    }
  } else if (what === "review-bench" && args.length >= 1) {
    const flags = args.filter((a) => a.startsWith("--"));
    const passAt = args.indexOf("--pass");
    const passArg = passAt >= 0 ? Number(args[passAt + 1]) : null;
    // --only <file.jpg>...: the files after it, up to the next flag.
    const onlyAt = args.indexOf("--only");
    const only = onlyAt < 0 ? null : args.slice(onlyAt + 1).filter((a, i, all) => !a.startsWith("--") && !all.slice(0, i).some((b) => b.startsWith("--")));
    await reviewBench(args[0], flags.includes("--rescore"), passArg, only, print);
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
        const kept = `${day.day}_${name}.${name.endsWith(FULL_SUFFIX) ? "png" : "jpg"}`;
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
        tries.filter((t) => t.wrong !== "").map((t) => `${t.time}: ${t.wrong}`).join("; ") + `; US$${cost().toFixed(2)} so far`);
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
    console.error("usage: cli.js day [acorn|pearl] [yyyymmdd] | bank pearl <level> <count> <outfile> | themed <yyyymmdd> <days> <outdir> [themes-dir] | cast <yyyymmdd> | theme <yyyymmdd> <out.json> [recent.json|text]... | decoys <png> <out-dir> [defect...] | review-bench <bench-dir> [--rescore] [--pass N] [--only <file.jpg>...] | vistas <day.json>... | jellies <day.json>... | hoops <day.json>... | words <day.json>... | quizzes <day.json>... | publish");
    process.exitCode = 2;
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
