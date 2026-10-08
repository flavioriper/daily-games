import {makeDay} from "./acorn";

/**
 * The night's work by hand (tools/acorn_day.sh, tools/publish_day.sh):
 *
 *   node lib/cli.js day [yyyymmdd]   prints the day Golden Acorn would
 *                                    publish: written by the model when
 *                                    OPENROUTER_API_KEY is set, by the bank
 *                                    when it is not, when DAILY_MODEL=off
 *                                    or where the model fails. Writes
 *                                    nothing.
 *   node lib/cli.js publish          runs publishDays for today and tomorrow
 *                                    against whatever project the
 *                                    credentials name -- the day a game
 *                                    ships on, which the 03:00 scheduler
 *                                    never reaches. Run by a person.
 */
async function main(): Promise<void> {
  // What is printed is the day and nothing else: the makers' own lines go
  // to the other stream.
  const print = console.log;
  console.log = console.error;
  const [what, arg] = process.argv.slice(2);
  if (what === "day") {
    const now = new Date();
    const today = now.getUTCFullYear() * 10000 + (now.getUTCMonth() + 1) * 100 + now.getUTCDate();
    const day = arg ? Number(arg) : today;
    print(JSON.stringify(await makeDay(day), null, 1));
  } else if (what === "publish") {
    // Loaded here and not at the top: index.ts wakes the admin SDK, which a
    // dry run has no credentials for and no use of.
    const {publishDays} = await import("./index");
    await publishDays(new Date());
    print("published");
  } else {
    console.error("usage: cli.js day [yyyymmdd] | publish");
    process.exitCode = 2;
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
