# Peeplet Brand, the night: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The day's four painted vistas carry the day's two Peeplets, drawn from a reference sheet of the live look, and a reviewer calibrated on a labelled bench turns down any painting with a deformed Peeplet or a human before it reaches a phone.

**Architecture:** One PNG sheet rendered by a Godot harness feeds both the painter and the reviewer in `server/functions/src/vistas.ts`. `cast.ts` mirrors the phone's persona list and seed so the painted pair is the pair the phone shows. A bench under `tools/days/peeplet-bench/` holds paintings, decoys and hand labels; `cli.js review-bench` scores the reviewer against them and is the gate.

**Tech Stack:** TypeScript on Node (`server/functions`, `npm run build`, `node lib/cli.js`), flash image on Vertex (`gemini-2.5-flash-image`), Opus over OpenRouter for review, Godot 4.7 for the sheet harness, Python 3 with PIL for the bench's review page.

**Spec:** `docs/superpowers/specs/2026-10-27-peeplet-brand-design.md`, Part C. The companion plan `2026-10-27-peeplet-brand-app.md` reads the `cast` this plan publishes (its Task 3 names the seed rule).

## Global Constraints

- Nothing is deployed from this plan: `tools/deploy_functions.sh` is the user's. The functions keep building (`npm run build` green) after every task.
- Money: the bench is under US$15 in all (about 50 flash paintings at ~US$0.04, 16 decoy edits, and up to three Opus review passes at ~US$4). Ask the user before any run past that. OpenRouter must have balance; check `cost()` in the CLI's output.
- Vertex credentials for local runs come from the user's login (`tools/themed_days.sh` shows the env); run paintings serially, never in parallel with a themeDay emulator.
- The sheet is the one baked Peeplet image allowed: rendered by its harness, never hand-edited, rebuilt when the look changes, never shipped to a phone (`server/` is `.gdignore`d).
- Harness rules as in the app plan (resolution flag before `--script`, `--always-on-top`, `caffeinate`, `ulimit -f`).
- Commit locally after each task; never push. Work on `feat/peeplet-brand`.
- **No new suite tests** (the user's standing rule): checks are throwaway `tests/_probe_*.gd` scripts or CLI lines, never `tests/test_*.gd`.
- `peeplet/peeplet_personas.gd` has no `class_name`: preload it.

## Review Focus

1. A painting where the model drew a human child instead of a Peeplet: the reviewer's "human" rule must fire even when the figure is small and far (Task 4 decoys include one).
2. A morning that passes and a night edit that bends an arm: every time is reviewed, not just the morning (Task 3 test: `makeVista` for `night` calls `ask` with the sheet attached).
3. A day with no eligible cast (the persona list filtered to nothing by a future edit): `cast.ts` falls back to indices 0 and 1 rather than throwing (Task 2 test).
4. The reviewer rejecting every painting on a bad day: `themeDay` still publishes nothing rather than half, and the logs say why (Task 3: the `turned down` log line carries the reason; `publishVistas` unchanged).
5. An old `themes/{day}` staged before `cast` existed: `publishVistas` writes `cast` from the seed when the staged theme has none (Task 3 test).

---

### Task 1: The reference sheet

**Files:**
- Create: `tests/_shot_peeplet_sheet.gd` (after `tests/_shot_peeplet.gd`)
- Create: `server/functions/assets/peeplet_sheet.png` (the harness's output, committed)
- Modify: `server/functions/package.json:10` (the build copies it to `lib/peeplet_sheet.png` beside `vista_style.png`)
- Modify: `docs/agents/days-dashboard.md` (a "The Peeplet sheet" note: what it holds, how to rebuild)

**Interfaces:**
- Produces: `lib/peeplet_sheet.png`, 2048 wide, flat `Pal.PAPER` ground, eight cells in two rows: front idle, three-quarter (`turn` 35), side (`turn` 90), back (`turn` 180), sitting, laughing, one in a hat (`sunhat`, coat 5) and one in eyewear (`roundglasses`, coat 6); the first six in coat 0 (coral). A small ink label under each cell naming the pose. No ink outline (whatever `PeepletFur.ink` is in the repo; the harness takes `ink` as `_shot_peeplet.gd` does and the committed sheet records which in `days-dashboard.md`).

- [ ] **Step 1: Write the harness.** Copy `_shot_peeplet.gd`'s shape: `--resolution 2048x1024`, `out=<path>` writes one PNG after `WARM` seconds (one frame, not sixty), prints the draw calls, quits. Poses through `walker` as `_shot_peeplet.gd` triggers them.

- [ ] **Step 2: Render it**

Run: `ulimit -f 200000; caffeinate -d -i -u timeout 60 godot --path . --resolution 2048x1024 --always-on-top --script res://tests/_shot_peeplet_sheet.gd -- out=server/functions/assets/peeplet_sheet.png`
Expected: the PNG written; open it and check all eight cells read (two arms, two legs, the face, the hat and the glasses on).

- [ ] **Step 3: The build copies it**: append `&& cp assets/peeplet_sheet.png lib/peeplet_sheet.png` to `package.json`'s `build`; `cd server/functions && npm run build && ls -la lib/peeplet_sheet.png`.

- [ ] **Step 4: Commit**

```bash
git add tests/_shot_peeplet_sheet.gd server/functions/assets/peeplet_sheet.png server/functions/package.json docs/agents/days-dashboard.md
git commit -m "feat(night): the Peeplet reference sheet, rendered from the live look for the painter and the reviewer"
```

---

### Task 2: The cast on the server

**Files:**
- Create: `server/functions/src/cast.ts`
- Create: `server/functions/src/cast_personas.json` (generated: name, coat, hat, eyes per persona, in `ALL` order)
- Create: `tools/export_personas.gd` (a headless script that writes that JSON from `peeplet/peeplet_personas.gd`; run by hand when the list changes)
- Create: `tests/_probe_cast_parity.gd` (throwaway: the JSON matches `PeepletPersonas.ALL` entry by entry, prints PASS/FAIL)
- Modify: `server/functions/src/theme.ts:32-40` (`Theme.cast?: string`, the writer's prompt and schema gain it)
- Modify: `server/functions/src/vistas.ts:180-190` (`Vistas.cast: [number, number]`)
- Reference: `server/functions/src/eye.ts:37` (`fnv1a`, the same function as `core/daily.gd:47`), `peeplet/peeplet_palette.gd:17-30` (coats 0..7 are flat).

**Interfaces:**
- Consumes: `fnv1a(s: string): number` from `eye.ts`.
- Produces, in `cast.ts`:
  - `export const PLAIN_HATS = ["", "bandana", "beanie", "bow", "cap", "chefHat", "earmuffs", "sunhat", "topHat", "partyHat", "mushroomCap", "flowerCrown"]`
  - `export const HAT_WORDS: Record<string, string>` ("sunhat" to "a straw sun hat", "cap" to "a baseball cap", "beanie" to "a knitted beanie", "bow" to "a bow on its head", "chefHat" to "a white chef's hat", "earmuffs" to "fluffy earmuffs", "topHat" to "a top hat", "partyHat" to "a cone party hat", "mushroomCap" to "a red spotted mushroom cap", "flowerCrown" to "a crown of small flowers", "bandana" to "a bandana tied on its head", "" to "no hat")
  - `export const COAT_WORDS: string[]` for coats 0..7 (coral, mint, sky blue, butter yellow, lavender, peach, sage green, slate grey)
  - `export function eligible(): number[]`
  - `export function seeded(day: number): [number, number]` with exactly the app plan's rule: `a = fnv1a("cast-a-" + day) % eligible.length`, `b = fnv1a("cast-b-" + day) % eligible.length`, `b === a ? (a + 1) % n : b`, indices mapped through `eligible()`; `[0, 1]` when fewer than two are eligible.
  - `export function describe(i: number): string` ("a Peeplet in a <coat> coat wearing <hat>").
- `Theme.cast?: string` (one line, the pair's doing); `Vistas.cast: [number, number]`.

- [ ] **Step 1: Write the failing probe.** In `tests/_probe_cast_parity.gd`: load `res://server/functions/src/cast_personas.json`… (`server/` is gdignored, so read it with `FileAccess` by absolute project path `ProjectSettings.globalize_path("res://") + "server/functions/src/cast_personas.json"`), assert its length equals `PeepletPersonas.count()` and each entry's name/coat/hat/eyes equal `get_persona(i)`'s. In `server/functions`, a `node lib/cli.js cast 20261027` command prints the pair and the two descriptions (there is no test runner; the CLI line is the check, and the parity test is the Godot suite's).

- [ ] **Step 2: Implement** per Interfaces: `tools/export_personas.gd` writes the JSON; `cast.ts`; `theme.ts` writer prompt gains `"cast": one short line of what two small creatures could be doing in that scene together (rolling a hay bale, sharing a picnic blanket), no people` and the schema a `cast` string, optional in `validTheme`; `cli.ts` gains `cast <day>`.

- [ ] **Step 3: Verify**

Run: `godot --headless --path . --script tools/export_personas.gd && godot --headless --path . --script tests/_probe_cast_parity.gd && cd server/functions && npm run build && node lib/cli.js cast 20261027 && node lib/cli.js cast 20261028`
Expected: PASS; two different pairs printed, each two distinct indices with plain hats and flat coats.
Then parity: the Godot suite prints `cast vector 20261027 = [a, b]` (app plan, Task 3); `node lib/cli.js cast 20261027` must print the same two indices. If they differ, the hashes differ (JS `fnv1a` must be 32-bit unsigned over UTF-8 bytes, as `core/daily.gd:47`): fix `cast.ts` until they agree, and keep the vector in `days-dashboard.md`.

- [ ] **Step 4: Commit**

```bash
git add server/functions/src/cast.ts server/functions/src/cast_personas.json tools/export_personas.gd tests/_probe_cast_parity.gd server/functions/src/theme.ts server/functions/src/vistas.ts server/functions/src/cli.ts
git commit -m "feat(night): the day's cast on the server, the same pair the phone seeds, with plain hats and flat coats in words"
```

---

### Task 3: The painter and the reviewer

**Files:**
- Modify: `server/functions/src/vistas.ts:40-72` (`NEVER`, `FIRST`, `AGAIN`, `REVIEWER`, `REVIEW_SCHEMA`), `74-81` (a `sheetRef()` beside `styleRef()`), `118-170` (`makeVista`: review the full painting, attach the sheet, log the count)
- Modify: `server/functions/src/themeday.ts:238-245` (the morning gets `tries 2`), `166-180` (`publishVistas` writes `cast`), `43` (`TRIES = 3`)
- Modify: `server/functions/src/cli.ts:233-259` (`vistas` passes `cast`, prints `peeplets` counts)
- Modify: `docs/agents/turns-and-backend.md:134-150` (the vista step's new shape)

**Interfaces:**
- Consumes: `cast.ts` (`seeded`, `describe`), `Theme.cast`.
- Produces: `makeVista(day, theme, time, morning, keep?, tries = 2, pair = seeded(day))` returning `{vista, tries: {name, wrong, peeplets, size}[]}` (`size` the painter's native `WxH`); `REVIEW_SCHEMA` is `{wrong: string, peeplets: integer}`; `export function reviewPainting(theme, time, drawn: Drawing, morning: Drawing | null): Promise<{wrong: string; peeplets: number}>` (the review alone, for the bench).

- [ ] **Step 1: The prompts.** Rewrite per the spec's Part C:
  - `NEVER`: "No humans, no human faces, no text, ... no border or frame. The Peeplets are the only creatures with faces."
  - `FIRST(t, pair)`: the existing text plus: "Two Peeplets, the small round creatures of the second attached picture, exactly as drawn there: a round body, two short arms, two stubby legs, two eyes, no fingers, no neck. One is ${describe(pair[0])}, the other ${describe(pair[1])}. They are ${t.cast ?? "doing something small together that fits the place"}, in the right two thirds of the painting, each between an eighth and a fifth of the painting's height, painted in the same brushwork as the place."
  - `AGAIN(time)`: adds "with the same two Peeplets in the same spots and poses".
  - `REVIEWER`: the existing rules with "a person or a face" replaced by the spec's rubric: any human or human-shaped figure; a Peeplet (the creature on the reference sheet shown first) with more or fewer than two arms or two legs, a limb fused, melted, doubled, bent the wrong way or longer than the body, hands with fingers, a neck, a second head or face, more than two eyes, a body that is not one round blob; a Peeplet in the left third; a Peeplet larger than a fifth of the height or smaller than a twentieth; zero Peeplets; more than three. Answer `peeplets` with how many you count.
- Images sent to the reviewer: `[sheet, (morning,) painting]`, the prompt saying which is which.

- [ ] **Step 2: `makeVista`.** Review `drawn` (full size) and shrink only a passing one; `keep` still gets the small one plus, under the bench, the full one (`keep(name + "-full", drawn)`). `log.push({name, wrong, peeplets})`. The `console.error` on a turndown keeps its reason text. Lift the review into `reviewPainting`.

- [ ] **Step 3: `themeday.ts`.** `TRIES = 3`; the `vista` step passes `tries: time === "morning" ? 2 : 1`; `publishVistas` adds `cast: seeded(day)` to `made`.

- [ ] **Step 4: Build and a dry run**

Run: `cd server/functions && npm run build && node lib/cli.js vistas ../../tools/days/themed-vistas/20261019.json`
Expected: four paintings pass or the log says why each was turned down with a `peeplets` count; the JPEGs beside the JSON show two Peeplets. Look at them. Cost printed. **Also print the painter's native size** (`decoded(drawn).width x height`) on every try: if flash answers about 1024 wide, reviewing "the full painting" buys nothing over the phone JPEG and a Peeplet at an eighth of the height is ~56 px, which is the first calibration finding; write it in `days-dashboard.md` and tell the user, since it moves the crop-and-enlarge lever earlier.

- [ ] **Step 5: Commit**

```bash
git add server/functions/src/vistas.ts server/functions/src/themeday.ts server/functions/src/cli.ts docs/agents/turns-and-backend.md tools/days/themed-vistas
git commit -m "feat(night): the day's two Peeplets painted into the vistas from the sheet; the reviewer counts limbs and turns down humans"
```

---

### Task 4: The bench: paintings, decoys, labels

**Files:**
- Create: `tools/days/peeplet-bench/` (paintings as `<day>_vista-<time>-<try>-full.png`, decoys as `decoy-<n>-<defect>.png`, `labels.json`, `index.html`)
- Create: `tools/peeplet_bench.py` (builds `index.html`: every image in a grid with its name and a pass / fail / defect note from `labels.json`; `--label <name> <verdict> [note]` writes a label)
- Modify: `server/functions/src/cli.ts` (`decoys <painting.png> <out-dir>`: for each defect in `DEFECTS`, asks flash to edit the painting with that defect and writes the result)

**Interfaces:**
- Produces: `labels.json`: `{ "<file>": {"verdict": "pass" | "fail", "defect": "" | "third-arm" | "missing-leg" | "fingers" | "human" | "neck" | "fused" | "long-arm" | "other", "subtle": bool} }`.
- `DEFECTS` in `cli.ts`: `[["third-arm", "give one Peeplet a third arm"], ["missing-leg", "remove one of a Peeplet's legs"], ["fingers", "give a Peeplet human hands with fingers"], ["human", "replace one Peeplet with a small human child"], ["neck", "give a Peeplet a long neck"], ["fused", "fuse a Peeplet's arm into its body so it melts in", true], ["long-arm", "make one Peeplet's arm slightly longer than the other", true]]` (the last two subtle); each edit prompt is "Edit the attached painting: <defect>. Change nothing else."

- [ ] **Step 1: Paint the set.** Pick eight days from `tools/days/*.json` with varied scenes (name them in the commit); copy each to `tools/days/peeplet-bench/<day>.json`; run `node lib/cli.js vistas` on all eight (each morning two tries, the edits one). Expected: about 40-50 full-size PNGs. Note the cost printed; stop and tell the user if it passes US$4.

- [ ] **Step 2: Decoys.** On eight passing paintings run `node lib/cli.js decoys <png> tools/days/peeplet-bench/` with the five obvious defects spread over them (two each minus three), and the two subtle on four more. Sixteen files.

- [ ] **Step 3: The review page.** `python3 -I tools/peeplet_bench.py` writes `index.html`; open it (`open tools/days/peeplet-bench/index.html`). Label every obvious one yourself with `--label`; list the subtle decoys and any painting you are unsure of for the user, in one message, and stop until they answer. (This is the hard pause in the spec.)

- [ ] **Step 4: Commit** the set, labels and page.

```bash
git add tools/days/peeplet-bench tools/peeplet_bench.py server/functions/src/cli.ts
git commit -m "feat(bench): the Peeplet review bench -- paintings, decoys with named defects, hand labels and a review page"
```

---

### Task 5: Score the reviewer and gate it

**Files:**
- Modify: `server/functions/src/cli.ts` (`review-bench <dir>`: runs `reviewPainting` over every labelled file, prints a table and a summary, writes `report.json`)
- Modify: `docs/agents/days-dashboard.md` (a bench table: pass number, prompt change, deformed-passed, good-rejected, count error)
- Modify: `server/functions/src/vistas.ts` (`REVIEWER` wording iterated until the gate holds)

**Interfaces:**
- Consumes: `reviewPainting` (Task 3), `labels.json` (Task 4).
- Produces: `report.json`: `{pass: n, deformedPassed: [files], goodRejected: [files], countErrors: n, subtlePassed: [files], costUsd}`.

- [ ] **Step 1: The command.** For each labelled file: theme from the day's JSON (decoys take their source painting's day), `time` from the name, morning from the set when the time is not morning; `reviewPainting` and compare: a `fail`-labelled file with `wrong === ""` is deformed-passed (subtle ones counted apart); a `pass`-labelled with `wrong !== ""` is good-rejected; `peeplets !== 2` on a pass-labelled painting is a count error.

- [ ] **Step 2: Run it**

Run: `cd server/functions && npm run build && node lib/cli.js review-bench ../../tools/days/peeplet-bench`
Expected: the table; cost about US$4. Record the row in `days-dashboard.md`.

- [ ] **Step 3: Iterate the rubric** on what let a deformed one through or rejected a good one (wording, order of rules, naming the sheet). At most three runs. Gate: `deformedPassed` empty (obvious defects) and `goodRejected.length / passLabelled < 1/3`. If the third run fails the gate, stop and tell the user, with the report, before any crop-and-enlarge work.

- [ ] **Step 4: Commit** after each run with its row.

```bash
git add server/functions/src/cli.ts server/functions/src/vistas.ts tools/days/peeplet-bench/report.json docs/agents/days-dashboard.md
git commit -m "feat(bench): review-bench scores the reviewer; rubric pass N: <deformed-passed> deformed passed, <good-rejected> good rejected"
```

---

### Task 6: The dashboard and the docs

**Files:**
- Modify: `tools/build_dashboard.py` (Themed days shows the `peeplets` count per vista try and links the bench page)
- Modify: `docs/agents/days-dashboard.md`, `CLAUDE.md` (the never-bake carve-out: the sheet), `docs/art/peeplet-brand.md` (the sheet rule; created by the app plan's Task 7 if that ran first, else create it here)

- [ ] **Step 1:** `python3 tools/build_dashboard.py` builds; open and check the bench link and the counts.
- [ ] **Step 2: Commit**

```bash
git add tools/build_dashboard.py docs/agents/days-dashboard.md CLAUDE.md docs/art/peeplet-brand.md
git commit -m "docs(night): the bench on the dashboard; the sheet is the one baked Peeplet, rebuilt by its harness"
```

Deploying `themeDay` with all this is the user's call (`tools/deploy_functions.sh`), after the gate holds.
