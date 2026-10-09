import fs from "node:fs";
import path from "node:path";
import {makeDay as acornDay} from "./acorn";
import {bankPrompts, cleaned, makeDay as pearlDay, Prompt} from "./pearl";

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
  } else if (what === "publish") {
    // Loaded here and not at the top: index.ts wakes the admin SDK, which a
    // dry run has no credentials for and no use of.
    const {publishDays} = await import("./index");
    await publishDays(new Date());
    print("published");
  } else {
    console.error("usage: cli.js day [acorn|pearl] [yyyymmdd] | bank pearl <level> <count> <outfile> | publish");
    process.exitCode = 2;
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
