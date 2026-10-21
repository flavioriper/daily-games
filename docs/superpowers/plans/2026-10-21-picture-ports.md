# Picture Ports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every night, Yarn Hoop's and Gumdrop's pictures are written as maps by a vision model from a flash drawing, checked by the night's geometry, scored by a reviewer shown what the player will see, and published with their record; Gumdrop's card picture gets the gummy finish in the game and the viewer.

**Architecture:** The night (`server/functions`, `themeWork`) keeps its steps; each picture port draws on a per-thing key colour, lays a numbered grid over the drawing, asks the reviewer model for the map in grid coordinates, repairs and checks the mesh with the phone's rules, colours it from the drawing, renders it as the game draws it and asks the eye to name and score it. The best try above the floor is kept; the pixel readers of today are the fallback. Each port's tries, source and render are published a document a picture under `days/{day}/ports/` for the viewer. The phone's documents do not change shape; only `gumdrop_art.gd`'s card picture changes.

**Tech Stack:** TypeScript on Firebase Functions (node 22, `pngjs`, `jpeg-js`, the Anthropic SDK through `generate.ts` `ask`/`draw`), Firestore rules, the Vite + React day viewer, Godot 4 GDScript.

**Spec:** `docs/superpowers/specs/2026-10-21-picture-ports-design.md` (the spike scripts and fixtures beside it in `2026-10-21-picture-ports-spike/`).

## Global Constraints

- No new test suites (the user, MVP rule): each task verifies with `npx tsc` in `server/functions`, a throwaway node script on the fixtures, or an existing harness; throwaway scripts live in the scratchpad or `build/`, never committed.
- Drawings on `DAILY_SHAPES_MODEL` (flash) only, one at a time; never run `gemini-3-pro-image` locally (production's quota). Local runs that draw need the Vertex token, which only the user's shell may print: a step that draws says "run by the user" and gives the exact command.
- The reviewer model is `role: "review"` (Opus through the Anthropic key, OpenRouter otherwise), the writer `role: "write"`; nothing new is hard-coded to a model id.
- The night's step budget: `START_BUDGET_MS` 15 min to start a step, `LEASE_MS` 30 min a run. A hoop band is at most 2 drawings x 2 asks + 2 reviews + 1 key ask; a jelly band at most `DRAWINGS[band]` drawings x 3 asks + reviews a thing.
- Never the name of the game a board follows, in code, comments or commits (Yarn Hoop and Gumdrop are their only names).
- The phone must keep reading days made before this plan and days whose port fell back: `hoops` and `jellies` keep their shapes; `ports` is never read by the phone.
- `Analytics.start()`, `Backend`, `Ads.start()` only from `world/main.gd`; harnesses: `--resolution 810x1440` before `--script`, `--always-on-top`, one windowed run at a time, under `caffeinate -d -i -u`.
- Deploys (`tools/deploy_functions.sh`, `firebase deploy --only firestore:rules`, the push to `main`) are the user's; the plan ends with the functions built, not deployed. `godot --headless --path . --import` after new assets.

## Review Focus

1. A theme written before this plan has no `creature` field and a `draw` with no colour words: `keyFor` must still answer a key and the hoop prompt must still say "no face" only for an object (Task 1 pins both).
2. The model's map names a pin id twice, leaves a panel's id unknown, or lays a panel over the background: repair drops and reports, and a panel whose drawing colour is within the key's reach is dropped as background (Task 4).
3. The model's jelly puts a shape outside 10-90 or writes 9 parts: `why()` refuses, the refusal is folded into the next ask, and after the last ask the fallback runs rather than an empty band (Task 6).
4. The eye names the thing but scores under the floor on every try: the band falls back to today's reader and the port record says so; nothing is published with a score under the floor (Tasks 5, 6, 7).
5. The night's step runs out of time mid-port: every loop is bounded by constants and a thrown error inside a try leaves the earlier tries recorded (Tasks 5, 6, 7).

---

### Task 1: The key colour a thing, and the prompts that take it

**Files:**
- Create: `server/functions/src/key.ts`
- Modify: `server/functions/src/facets.ts:68` (`KEY_WORDS`), `server/functions/src/hoop.ts:50` (`PROMPT`), `server/functions/src/jelly.ts:411-415` (`STICKER`), `server/functions/src/theme.ts:16-26` (`Thing`)

**Interfaces:**
- Produces: `export type Key = "green" | "magenta" | "cyan"`; `export const KEY_HEX: Record<Key, string>` (`#00FF00`, `#FF00FF`, `#00FFFF`); `export function keyWords(key: Key): string` (the sentence `KEY_WORDS` is today, with the key's name and hex); `export async function keyFor(thing: Thing): Promise<{key: Key; creature: boolean}>` in `key.ts`; `PROMPT(what: string, band: number, key: Key, creature: boolean)`; `STICKER(what: string, band: number, key: Key)`; `Thing.creature?: boolean`.

- [ ] **Step 1: Add `creature?: boolean` to `Thing` in `theme.ts`** (optional; the theme writer's schema is not changed, so old and new themes both parse).

- [ ] **Step 2: Write `key.ts`.** `keyFor` asks the write model once (`ask`, `role: "write"`, schema `{key: enum green|magenta|cyan, creature: boolean}`, system: it is told the three keys and that the key must be the one farthest from every colour the thing has, and that `creature` is true for an animal or a character with a face) with `thing.draw` as the prompt; on any error it answers by words in `draw`: a word in `green|lime|teal|mint|olive|turquoise` gives `magenta`, else a word in `pink|magenta|purple|violet|red|rose` gives `cyan`, else `green`; `creature` false. When `thing.creature` is set, it is returned as is.

- [ ] **Step 3: Replace `KEY_WORDS` in `facets.ts` by `keyWords(key)`** and keep `export const KEY_WORDS = keyWords("green")` for any caller not yet moved. `board(r)` already floods from the edge's median, so the reader needs no change.

- [ ] **Step 4: Rewrite `PROMPT` in `hoop.ts`** to the spec's reference look (the spike's `HOOP` in `spike_ports.js`, run 2): at least 150 and about 200 small flat facets on every band, big surfaces broken into small facets too, a soft muted harmonious palette of gentle earthy pastels, each facet one flat colour, lit softly from the top left (light, mid, shadow tones), crisp edges, no outlines, no gradient in a facet, no texture; `creature` false adds "It is an object: no face, no eyes, no mouth."; on `keyWords(key)`; no cast shadow, no ground, nothing else, no text; a square picture. `BANDS[band].facets` is no longer used by the prompt (keep the field).

- [ ] **Step 5: `STICKER` takes `key`** and says `keyWords(key)` in place of the green words; its "every shape big and chunky" becomes "the shapes are clean and well proportioned: a sharp, true silhouette of the thing that a child names at once"; it forbids "white, cream or grey anywhere in it" outright.

- [ ] **Step 6: Build and check.** Run: `cd server/functions && npx tsc`. Expected: no errors. Throwaway: `node -e` calling `keyFor` on `{draw: "a green frog sitting up, with a pale yellow belly"}` prints `magenta`/`true` and on `{draw: "a red rubber rain boot with a yellow cuff"}` prints `green` or `cyan`/`false` (with `ANTHROPIC_API_KEY` from a login zsh; without a key, the word fallback gives `magenta` and `cyan`).

- [ ] **Step 7: Commit.** `git add server/functions/src && git commit -m "feat(night): a key colour a thing, the hoop and sticker prompts to the reference look"`

### Task 2: The shared eye and the renders it sees

**Files:**
- Create: `server/functions/src/eye.ts`
- Test: throwaway node on the fixtures

**Interfaces:**
- Consumes: `ask` from `generate.ts`; `Theme`, `Thing` from `theme.ts`; `fnv1a`, `DECOYS` moved out of `pictures.ts` into `eye.ts` (exported, `pictures.ts` imports them back).
- Produces:
  - `export interface Verdict {pick: string; score: number; wrong: string; notes: string; ok: boolean}` (`ok` = named the thing, `wrong` empty).
  - `export type Game = "hoop" | "jelly" | "pixel"`; `export const FLOOR: Record<Game, number> = {hoop: 7, jelly: 7, pixel: 0}` (pixel is not gated, goal 5).
  - `export async function judge(day: number, theme: Theme, thing: Thing, game: Game, render: string, source?: string): Promise<Verdict>` — `render` and `source` are data URLs; the system prompt is the spike's `EYE` (`spike_map.js`), the rubric `RUBRIC[game]` (hoop and jelly as in `spike_map.js` / `spike_jelly_map.js`; pixel: the `LOOKER` text of `pictures.ts`), the choices the day's things plus one decoy as `lookThing` builds them; `score` is 0 when the schema's number is missing.
  - `export function renderPolygons(polys: {pts: number[][]; fill: string}[], size: number, background: string, outline?: {colour: string; width: number}): Buffer` — a PNG, points in a square of 100, scan-filled in order, each polygon's outline stroked after all fills when `outline` is given (the hoop's ropes; a stroke is the polygon's sides drawn as thin filled quads).
  - `export const dataUrl = (mime: string, bytes: Buffer) => string`.

- [ ] **Step 1: Write `eye.ts`** with the four exports above; `judge` logs one line `eye: day, game, thing: pick score — notes`.

- [ ] **Step 2: Move `DECOYS` and `fnv1a` to `eye.ts`**, import them in `pictures.ts`; `lookThing` is left as is for now (Task 8 moves it).

- [ ] **Step 3: Check.** `npx tsc`. Throwaway: render the fixture `hoop0_snail_ref_map.json` (pins in grid units of 20 → x5) through `renderPolygons` with an outline and write the PNG; open it and see the snail with rope lines. Then one `judge` call on it with a hand `Theme` of the five things (costs cents): expect `pick: "snail"` and a number.

- [ ] **Step 4: Commit.** `git commit -am "feat(night): the eye, a reviewer shown what the player sees"`

### Task 3: The mapping field

**Files:**
- Create: `server/functions/src/grid.ts`

**Interfaces:**
- Consumes: `decoded` from `pictures.ts`; `PNG` from `pngjs`.
- Produces: `export const GRID_N = [20, 24, 30, 40]` (hoop, by band); `export const JELLY_GRID_N = 20`; `export function gridOver(d: Drawing, n: number, labelStep: number): Drawing` — the drawing scaled to 1000 px inside a 44 px white margin, `n` cells a side, every fifth line darker, the line index (times `labelStep`: 1 for the hoop, 5 for the jelly's 0-100 field) written at each line along all four edges (every line when `n <= 24`, every other past that), digits drawn from a 5x7 bitmap font in code (no font file), as `spike` did with PIL.

- [ ] **Step 1: Write `grid.ts`.**

- [ ] **Step 2: Check.** `npx tsc`; throwaway: `gridOver` on the fixture `hoop_style.png` at 20 and at 40, write both PNGs, open them: lines, labels on all four sides, readable.

- [ ] **Step 3: Commit.** `git commit -am "feat(night): the mapping field, a numbered grid over a drawing"`

### Task 4: The mesh repaired and checked

**Files:**
- Create: `server/functions/src/mesh.ts`
- Modify: `server/functions/src/hoop.ts:60-150` (export `convex`, `ears`, `regroup`, `MOST_CORNERS`, `LEAST_PANELS`)

**Interfaces:**
- Consumes: `ears(ids, pins)`, `regroup(pieces, pins)`, `convex(p)`, `MOST_CORNERS` from `hoop.ts`; `Raster` from `facets.ts`; `HoopPanel` from `hoop.ts`.
- Produces:
  - `export interface ModelMap {pins: {id: number; x: number; y: number}[]; panels: {pins: number[]; colour: string}[]}` (the model's answer).
  - `export interface Mesh {pins: number[]; panels: HoopPanel[]; box: {x0: number; y0: number; s: number}; stats: {asked: number; kept: number; snapped: number; dropped: number; tees: number; clipped: number}; why: string}` — `pins` flat x,y in the square of 100 centred on the thing's box (as `readHoop` centres), `box` the transform from the image's 0-100 to that square (so a panel can be read back off the raster), `panels[].k` indexes, `panels[].c` set by `colourFrom`.
  - `export function repairMesh(got: ModelMap, n: number, band: number): Mesh` — in order: grid to 0-100 of the image; snap pins within `0.35 * 100 / n`; drop repeated and unknown ids, panels under 3; insert a pin lying on another panel's side (within `0.3`, between 2% and 98% along it) into that side; weld pins nearer than `BANDS[band].least * 100 / 256` along a side, never under 3 corners; ear-clip a concave or over-7 panel with `ears` + `regroup`; renumber; centre and scale to the thing's box as `readHoop` does. `why` is "" or the first of: `"${k} pins inside another panel"`, `"a side three panels share"`, `"${panels} panels, under ${LEAST_PANELS[band]}"`, `"${panels} panels, over ${BANDS[band].most}"`.
  - `export function colourFrom(r: Raster, mesh: Mesh, key: string): number` — each panel's `c` the drawing's mean over the panel (scan fill on the raster through the box transform); a panel whose mean is within 60 of the key's hex is dropped as background; returns how many were dropped.

- [ ] **Step 1: Export the helpers from `hoop.ts`** (`export function convex/ears/regroup`, `export const MOST_CORNERS`, `export const LEAST_PANELS`).

- [ ] **Step 2: Write `mesh.ts`** (`repairMesh`, `colourFrom`). The spike's `mesh()` in `spike_map.js` is the reference for snap and the checks; T-junction insertion and ear-clipping are new.

- [ ] **Step 3: Check on the fixtures.** `npx tsc`; throwaway node over the four `*_map.json` fixtures (n = 20, 24, 30, 40; bands 0-3): print each `stats` and `why`. Expected: `why` "" on all four; `hoop1_frog_words` (2 concave, 2 triple sides in the spike) comes out with `clipped >= 2` and no triple side; `hoop3_kettle_ref` (1 tee) with `tees 1` and `why` "". Then the snail fixture with one panel's id changed to 999 and another panel listing a pin twice: `stats.dropped` counts the unknown id, the twice-listed pin is folded, `why` stays "". Render each through `renderPolygons` (Task 2) and open: whole shapes, no slivers.

- [ ] **Step 4: Commit.** `git commit -am "feat(night): a model's map repaired and checked as the phone checks it"`

### Task 5: The Yarn Hoop port

**Files:**
- Modify: `server/functions/src/hoop.ts:355-383` (`makeHoop`), `server/functions/package.json` (build copies `docs/superpowers/specs/2026-10-21-picture-ports-spike/hoop_style.png` to `lib/hoop_style.png` as it copies `vista_style.png`)
- Create: `server/functions/src/ports.ts` (the record type only; the staging and publishing come in Task 7)

**Interfaces:**
- Consumes: `keyFor`, `keyWords` (Task 1); `judge`, `renderPolygons`, `dataUrl`, `FLOOR` (Task 2); `gridOver`, `GRID_N` (Task 3); `repairMesh`, `colourFrom`, `ModelMap` (Task 4); `draw`, `ask`, `shapesModel` (`generate.ts`); `raster`, `board` (`facets.ts`); `shrunk` (`vistas.ts`).
- Produces:
  - In `ports.ts`: `export interface PortTry {n: number; route: "map" | "reader" | "written"; why: string; verdict?: Verdict; kept: boolean; error?: string}`; `export interface Port {game: "hoop" | "jelly"; band: number; thing: string; tries: PortTry[]; source?: string; render?: string}` (`source`/`render` base64 JPEG of the kept try, shrunk as the vistas are).
  - `export const MAP_ASKS = 2`, `export const HOOP_DRAWINGS = 2` in `hoop.ts`.
  - `export async function mapHoop(drawing: Drawing, thing: Thing, band: number, refused: string): Promise<ModelMap>` — `ask` with `role: "review"`, the spike's `MAPPER` system (`spike_map.js`) plus the rules the phone checks (3-7 corners, convex, shared whole sides, no overlap, no gap, nothing of the background, every facet kept, the whole panel budget used), the schema of `spike_map.js`, the image `gridOver(drawing, GRID_N[band], 1)`, the prompt naming the thing, the grid size, `BANDS[band].most`, and `refused` folded in when not "".
  - `makeHoop(day, theme, band, keep?)` now returns `Promise<{picture: HoopPicture | null; port: Port}>`: for each of `HOOP_DRAWINGS` drawings (`draw(PROMPT(thing.draw, band, key, creature), shapesModel(), {images: [styleRef()]})`, `styleRef()` reading `lib/hoop_style.png`): up to `MAP_ASKS` asks, each repaired, coloured, rendered (`renderPolygons` with the rope outline) and judged; a try is `kept` when `verdict.ok && score >= FLOOR.hoop`; the best score wins across drawings and asks; stop early at a score ≥ 9. When none is kept, `readHoop` on the last drawing is one more try (`route: "reader"`) judged the same way and kept only above the floor. The `Port` records every try; `source`/`render` are the kept try's.

- [ ] **Step 1: Add `ports.ts` with the two interfaces.**

- [ ] **Step 2: Write `mapHoop` and rework `makeHoop`** as above; every ask, repair and judge of a try sits in its own try/catch that records `error` on the `PortTry` and goes on to the next, so a thrown error never loses the tries before it; `package.json` build copies `hoop_style.png`; `cli.ts` and `themeday.ts` are made to compile against the new return (`themeday.ts` uses `got.picture` for now; Task 7 takes `got.port`).

- [ ] **Step 3: Check without drawing.** `npx tsc`. Throwaway: call `mapHoop` on the fixture drawing `hoop_style.png` (band 0, a hand `Thing` for the snail, `refused` "") and run the result through `repairMesh` + `colourFrom` + `renderPolygons`; open the PNG: a snail mesh. Costs one Opus ask.

- [ ] **Step 4: Check with drawings (run by the user).** A throwaway script `build/port_hoop.js` calling `makeHoop(20261021, theme, band)` for bands 0 and 3 with the five-thing theme and a `keep` writing the drawings; run as the spike was:
  ```
  ! cd /Users/flavioriper/dev/daily/server/functions && zsh -ilc 'VERTEX_PROJECT=production-506015 VERTEX_TOKEN_COMMAND="gcloud auth print-access-token --account andressa.t@navlio.io" node ../../build/port_hoop.js' 2>&1 | tail -20
  ```
  Expected: each band logs its tries with scores, ends with a kept picture whose `panels.length` is within `LEAST_PANELS[band]..BANDS[band].most`, and the whole run stays under 10 minutes a band.

- [ ] **Step 5: Commit.** `git commit -am "feat(hoop): the night asks a model for the map, repairs it and keeps the best the eye scores"`

### Task 6: The Gumdrop port

**Files:**
- Modify: `server/functions/src/jelly.ts:322-380` (`makeJellies`), `:583-600` (`drawJelly`), `:409` (`DRAWINGS`)

**Interfaces:**
- Consumes: Task 1 (`keyFor`, `STICKER(what, band, key)`), Task 2 (`judge`, `renderPolygons`, `dataUrl`, `FLOOR`), Task 3 (`gridOver`, `JELLY_GRID_N`), `why`, `polygon`, `readJelly`, `RULES`, `MOST_PARTS`, `MOST_SHAPES`, `MOST_POINTS`, `COVER`, `LEAST_SQUARES`, `FIT` (all in `jelly.ts`); `Port`, `PortTry` (Task 5).
- Produces:
  - `export const JELLY_ASKS = 3`.
  - `export async function mapJelly(drawing: Drawing, thing: Thing, band: number, refused: string): Promise<Part[]>` — `ask` with `role: "review"`, the spike's `MAPPER` system (`spike_jelly_map.js`) with the band's rules stated in full in the prompt: `rules(band)` as the spike builds it plus "at most `MOST_PARTS` parts, `MOST_SHAPES` shapes a part, 6 to `MOST_POINTS` points a polygon, every point inside `FIT[0]`-`FIT[1]`, the jelly covering `COVER[0]*100`% to `COVER[1]*100`% of the field, every chunk at least `LEAST_SQUARES` squares of a 36 by 36 grid of the field (a dot is not a chunk), nothing thinner than 6 units"; the schema of the spike; `refused` folded in as "Your last answer was refused by the board's checker: ... Write it again so it passes."
  - `drawJelly(day, thing, band, t, keep?)` becomes `Promise<{parts: Part[] | null; port: Port}>`: for each of `DRAWINGS[band]` drawings (`STICKER(thing.draw, band, key)` with `keyFor`'s key): up to `JELLY_ASKS` asks of `mapJelly`, each judged by `why`; a passing answer is rendered (`renderPolygons` of `polygon(s)` for every shape in order, on `#f3ead8`) and judged by the eye; kept when `ok && score >= FLOOR.jelly`; best across tries, early stop at ≥ 9. None kept: `readJelly` of the last drawing as a `"reader"` try through `why` and the eye. `makeJellies` keeps its written fallback after that (`route: "written"`) and threads every try into the `Port`; `JellyTry` gains `verdict?: Verdict`. `makeJellies` returns `{jellies, tries, ports: Port[]}`.

- [ ] **Step 1: Write `mapJelly`, rework `drawJelly` and `makeJellies`.**

- [ ] **Step 2: Check without drawing.** `npx tsc`. Throwaway: `why()` on the fixtures `jelly1_snail_map0.json` (band 1, expected "") and `jelly2_frog_map1.json` (band 2, expected `"a chunk too small to pour in"`). No sticker drawing is kept as a fixture, so the model call waits for Step 3.

- [ ] **Step 3: Check with drawings (run by the user).** `build/port_jelly.js` calling `makeJellies(20261021, theme, 2)` (Hard: four things) with the same command shape as Task 5's. Expected: at least three of four things kept with a score ≥ 7 or a logged fallback; every refusal in the log is one of `why()`'s strings and never repeats three times unchanged for one thing.

- [ ] **Step 4: Commit.** `git commit -am "feat(gumdrop): the night asks a model for the jelly, the rules stated, the eye over the render"`

### Task 7: The port record staged, published and readable

**Files:**
- Modify: `server/functions/src/ports.ts`, `server/functions/src/themeday.ts:49-56` (`Staged`), `:178-224` (`runStep`), `:118-141` (`publishPictures`), `:240-270` (the publish calls), `server/firestore.rules:7-33`, `server/functions/src/cli.ts:90-130` (`themedDays`)

**Interfaces:**
- Consumes: `Port` (Task 5), `makeHoop`'s and `makeJellies`' returns (Tasks 5, 6).
- Produces:
  - `export function portId(p: Port): string` = `${game}${band}_${thing}`.
  - `export async function stagePorts(db: Firestore, day: number, ports: Port[]): Promise<void>` — `themes/{day}/ports/{portId}` set with the `Port` as fields (`tries` as JSON string, `source`/`render` base64 strings), one document a port.
  - `export async function publishPorts(db: Firestore, day: number): Promise<number>` — every staged port copied to `days/{day}/ports/{portId}` with `create()` (exists → skip), returns how many are there after.

- [ ] **Step 1: `runStep`** for `hoop*` and `jelly*` calls `stagePorts` with the ports the step made (one for a hoop band, one a thing for a jelly band), before returning its save.

- [ ] **Step 2: `publishPictures`** calls `publishPorts(db, day)` after the `pictures` document is created (and when it already exists, so a late port still lands).

- [ ] **Step 3: Rules.** In `server/firestore.rules` add under `/days/{day}`: `match /ports/{doc} { allow read: if request.auth != null; allow write: if false; }`, beside the `turns` match.

- [ ] **Step 4: `cli.ts themedDays`** writes `hoopPorts` and `jellyPorts` into the day's JSON beside `jellyTries` (source and render dropped there; the drawings are already files).

- [ ] **Step 5: Check.** `npx tsc`; then from `server/`: `firebase emulators:exec --only firestore "true"`. Expected: the emulator loads the rules and exits 0 (a rules syntax error fails here).

- [ ] **Step 6: Commit.** `git commit -am "feat(night): a port's tries, source and render published a document a picture"`

### Task 8: Jewel Box through the eye (score and notes, nothing gated)

**Files:**
- Modify: `server/functions/src/pictures.ts:171-211` (`lookThing`), `:48-59` (`Tried.look`)

**Interfaces:**
- Consumes: `judge` (Task 2).
- Produces: `Tried.look` gains `score?: number; notes?: string`; `lookThing` calls `judge(day, theme, thing, "pixel", shown(rows))` and maps `Verdict` to `{said: pick, wrong, ok, score, notes}`; `ok` keeps today's meaning (named and not wrong), so nothing the user loves changes.

- [ ] **Step 1: Make the change.** `lookScene` stays as it is.

- [ ] **Step 2: Check.** `npx tsc`; throwaway: `lookThing` on today's published 16-side picture (read as the viewer reads it, `tools/day_viewer/src/day.js` `readDay`, or any `pictures` document the staging holds): `ok` true for its own thing, a `score` present.

- [ ] **Step 3: Commit.** `git commit -am "feat(night): the pixel reviewer answers a score and notes too"`

### Task 9: The day viewer shows the ports and the gummy finish

**Files:**
- Modify: `tools/day_viewer/src/day.js:61-73`, `tools/day_viewer/src/App.jsx:46-57` (`Hoop`), `:98-108` (`Jelly`), `:214-222`

**Interfaces:**
- Consumes: `days/{day}/ports/*` documents (Task 7) with fields `game`, `band`, `thing`, `tries` (JSON string), `source`, `render` (base64 JPEG).
- Produces: `export async function readPorts(day)` in `day.js` → `{[portId]: Port}` listed as `readDay` lists the turns (`.../days/${day}/ports?pageSize=50`, an empty list on 403 or 404 so an old day still shows); `App.jsx` passes `ports` down: a `Hoop` card shows under its SVG the port's `source` and `render` images, the kept try's score and notes, and "fell back to the pixel reader" when the kept try's route is `reader`; a `Jelly` card the same, and its SVG wears the gummy `<filter id="gum">` of `spike_jelly_map.js` (one `<defs>` on the page, every jelly `<g filter="url(#gum)">`).

- [ ] **Step 1: `readPorts` in `day.js`; `App.jsx` reads it beside `readDay` and renders as above.**

- [ ] **Step 2: Check.** `cd tools/day_viewer && npm run dev`, open `localhost:5174` on today: the hoop and jelly cards render as before (no ports published yet: no port rows, no error), the jellies wear the finish. A throwaway `ports` object pasted into the component state shows the two images and the score line.

- [ ] **Step 3: Commit.** `git commit -am "feat(viewer): the ports' drawings, renders and verdicts; jellies with the gummy finish"`

### Task 10: The gummy finish on the card's picture in the game

**Files:**
- Modify: `puzzles/gumdrop_art.gd:159-168` (`picture`)

**Interfaces:**
- Consumes: `Face.Builder` (`polygon`, `stroke`, `ellipse`, `fan`), `Geometry2D.offset_polygon`, `m.rim`, `m.outline`, `m.cells`, `m.want`, `FLAVOURS`, `GEL_LIT`.
- Produces: `static func picture(m: Dictionary, u: float) -> ArrayMesh` unchanged in signature; the mesh now lays, in order: the soft shadow (the outline moved `Vector2(1.5, 2.5) * u`, `Color(0.35, 0.23, 0.16, 0.25)`), the white rim and the cells as today, then the dark rim (the outline's inner offsets at `-1.2 * u` and `-2.4 * u` via `Geometry2D.offset_polygon(..., JOIN_ROUND)`, each a ring made of the outline minus the inner polygon drawn as a stroke of the inner polygon's sides, `Color(0.23, 0.1, 0.19, 0.18)` and `0.1`), then the sheen along the upper left (`stroke` of the outline moved `Vector2(-0.9, -1.2) * u`, width `1.4 * u`, `Color(1, 1, 1, 0.28)`, drawn last and kept inside the jelly by `Geometry2D.intersect_polygons` of the stroke's quads with the outline), and one glint placed as `gloss_of` places its ellipses (the same nine-point search, `Color(1, 1, 1, 0.35)` and `0.55`). The finish is still.

- [ ] **Step 1: Write it.** Only `picture()` changes; `floor_of` and `gloss_of` are untouched.

- [ ] **Step 2: Check it parses and draws.** `godot --headless --check-only --script puzzles/gumdrop_art.gd` → no errors. Windowed, one at a time: `caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_gumdrop.gd -- build/shots/gumdrop 1` and open the rest shot: the card's picture glossy, the tray and tint as before. Then the same with `--rendering-driver opengl3_angle` and the draw-call line it prints: within the figures in `docs/agents/boards/gumdrop.md`, no new draw (the picture is still one mesh).

- [ ] **Step 3: Commit.** `git commit -am "feat(gumdrop): the card's picture with a gummy finish"`

### Task 11: Notes and the deploy list

**Files:**
- Modify: `docs/agents/boards/hoop.md`, `docs/agents/boards/gumdrop.md`, `docs/agents/turns-and-backend.md`, `docs/agents/days-dashboard.md`

- [ ] **Step 1: Write the history** in each (what the port is, the key colour, the grid, the repair, the eye, the floor, the fallback, the `ports` collection and its rules, the viewer's rows, the gummy finish and why not on the tint), dated 2026-10-21, with the spike's numbers from the spec.

- [ ] **Step 2: The deploy list at the end of the plan's final report**: `tools/deploy_functions.sh`; `firebase deploy --only firestore:rules` from `server/`; the APK via the push to `main` (only `gumdrop_art.gd` and the viewer are phone/Mac side; the viewer needs no deploy). State that the functions deploy carries also the 2026-10-20 hoop weld.

- [ ] **Step 3: Commit.** `git commit -am "docs(agents): the picture ports"`
