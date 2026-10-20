# Factory Rewired Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Factory's land of forests and markets with a top-down floor of three programmable robots, a node sheet, parts, a battery and one charging bay, through milestone 1 (belts, Fast plug, Fast treads) with the milestone trigger on pace.

**Architecture:** `factory/sim.gd` stays the one pure-data 10 Hz sim and keeps its belt machinery; everything about plates, forests, machines and goals leaves, and a new `factory/bots.gd` walks each robot's node graph a tick at a time inside `_tick`. The view is rebuilt on `factory/life.gd` (top-down, no turn) and `factory/art.gd` (fewer, new meshes), the screen keeps its camera, belt drawer and pill and gains robot chips, a pace pill and a new `factory/sheet.gd` node editor drawn as one baked mesh. Tally's `Batch` moves to `ui/hud/batch.gd` so both games instance pieces the same way.

**Tech Stack:** Godot 4 GDScript, gl_compatibility renderer, `ui/hud/piece_pill.gd`, `ui/hud/screen_tutor.gd`, `ui/faces/face.gd` mesh builder, `tools/gen_sfx.py` + `tools/sfx_bank/`, headless probes and windowed shot harnesses.

**Spec:** `docs/superpowers/specs/2026-10-20-factory-rewired-design.md` (the plan argues from it; executors read both). The clickable reference is `docs/brainstorm/concepts.html#factory`.

## Global Constraints

- Branch `feat/factory-rewired`, worked in place (no worktree). The user merges to `main` and pushes; never push.
- No new test files: the checks are `tests/_probe_factory.gd` (headless) and `tests/_shot_factory.gd` / `tests/_shot_factory_menu.gd` (windowed), rewritten. Throwaway probes are fine and deleted after.
- Parse before any harness: `godot --headless --path . --check-only --script res://<file>.gd`.
- Windowed harness flags, in this order: `caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top [--rendering-driver opengl3_angle] --script res://tests/_shot_factory.gd -- <outdir>`; one at a time; run under `ulimit -f 2000000` and `timeout 600`; quote the second of two readings.
- Budget 855 draw calls on `opengl3_angle`; no `instance uniform`; a drawing is one baked `ArrayMesh`, a repeated piece a `Batch`.
- Sim durations in ticks (`TICK 0.1`): Move 4 a tile (Fast treads 2), Pick/Release/skip/bump 4, body 2, charge 1 unit a tick (Fast plug 2), intake 1 square per 10 ticks up to 6, battery 30 units. No offline catch-up. Prices flat.
- The reference game is never named in code, comments, commits or on screen. Characters are code (`ui/faces/`), never images. Text through `locale/ui.csv` in en, pt, es.
- `Analytics.start()`, `Backend`, `Ads.start()` only from `world/main.gd`.
- Save `user://factory.cfg`, section `factory`, `VERSION 5`; a `VERSION 4` file is wiped quietly.

## Review Focus

1. A node inserted on the loop-back wire (the `+` past the last node) must keep the loop: the new node's `out` goes to `body`. Pinned in Task 3's probe (`insert after last keeps loop`).
2. A wire that makes a cycle not through the body (Move → Pick → Move) must not hang the walk or the sheet: `walk` returns a finite list with `closed == false`, the robot runs the cycle, never charges and goes flat. Pinned in Task 3's probe (`cycle off the body goes flat`).
3. A Move that meets the floor's edge part way (Move ← 4 from x = 2) walks 2, bumps once for 1 unit and 4 ticks, drops the rest and goes on. Pinned in Task 3's probe (`bump mid move`).
4. Save and load mid-move and mid-charge (`t`, `left`, `charging`, counters, the pace stamps) replay identically. Pinned in Task 4's probe (`round trip mid loop`).
5. A part taken off while its node is running: the node is skipped from the next tick with a `!`, nothing crashes, and because it was an edit the robot is home first. Pinned in Task 3's probe (`unfit mid node`).

---

### Task 0: Branch and the brainstorm's files

**Files:**
- Commit: `docs/superpowers/specs/2026-10-20-factory-rewired-design.md`, `docs/brainstorm/concepts.html`, this plan.

- [ ] **Step 1: Branch from main**

Run: `git checkout -b feat/factory-rewired`
Expected: `Switched to a new branch 'feat/factory-rewired'`

- [ ] **Step 2: Commit the spec, the concept tab and the plan**

```bash
git add docs/superpowers/specs/2026-10-20-factory-rewired-design.md docs/brainstorm/concepts.html docs/superpowers/plans/2026-10-20-factory-rewired.md
git commit -m "docs(factory): the rewired concept tab, spec two and its plan"
```

### Task 1: Tally's Batch, shared

**Files:**
- Create: `ui/hud/batch.gd`
- Modify: `arcade/tally_board.gd:238-297` (the `class Batch` block and `_batch`)
- Check: `tests/_probe_tally.gd`, `tests/_shot_tally.gd`

**Interfaces:**
- Produces: `ui/hud/batch.gd` (`extends RefCounted`): `_init(m: ArrayMesh)`, `put(xf: Transform2D, col := Color.WHITE) -> void`, `draw(l: Node2D) -> void`, `var n: int`, `var mm: MultiMesh`. The body is the class moved as it is.

- [ ] **Step 1: Move the class**

Create `ui/hud/batch.gd` with the `Batch` class body from `arcade/tally_board.gd` (header comment: a MultiMesh of one mesh filled a frame at a time, owned by Tally and the Factory). In `tally_board.gd` delete `class Batch` and add `const Batch = preload("res://ui/hud/batch.gd")`; `_batch`, `_clear_batches`, `_draw_batches`, `batched` keep their bodies.

- [ ] **Step 2: Parse and probe Tally**

Run: `godot --headless --path . --check-only --script res://arcade/tally_board.gd && godot --headless --path . --script res://tests/_probe_tally.gd`
Expected: no parse error; the probe's last line reports `0 failed`.

- [ ] **Step 3: Tally's windowed harness, once**

Run: `ulimit -f 2000000; timeout 600 caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_tally.gd -- /tmp/tally_shots > /tmp/tally.log 2>&1; grep -c FAIL /tmp/tally.log`
Expected: `0`

- [ ] **Step 4: Commit**

```bash
git add ui/hud/batch.gd arcade/tally_board.gd
git commit -m "refactor(tally): Batch lifted to ui/hud/batch.gd for the Factory to share"
```

### Task 2: The sim cut to the floor

**Files:**
- Modify: `factory/sim.gd` (whole file; the belt section kept)
- Modify: `tests/_probe_factory.gd` (rewritten; this task's checks are its first section)
- Delete: `tests/_shot_factory_art.gd`

**Interfaces:**
- Produces, in `factory/sim.gd`:
  - `const VERSION := 5`, `const COLS := 10`, `const ROWS := 8`, `const DIRS` (kept), `const STATIONS := {"charger": Vector2i(1, 1), "intake": Vector2i(1, 5), "stack": Vector2i(4, 1), "table": Vector2i(4, 5), "deliver": Vector2i(8, 5)}`, `const BAY := Vector2i(1, 1)`, `const QUEUE_MOST := 6`, `const FEED_TICKS := 10`, `const BOX_FULL := 4`, `const PAY_FULL := 6`, `const PAY_SQUARE := 1`, `const PRICE := {"belt": 1, "fast": 4, "bridge": 25}`, `const BELTS := ["belt", "fast", "bridge"]`, `const ONE_TILE := ["bridge"]`.
  - State: `coins: int`, `earned: int`, `queue: int`, `table: Dictionary` (empty, or a box item), `stations: Dictionary` (tile -> kind, from STATIONS), `items: Dictionary` (tile -> Array of items, lying or riding, as today), `belts`, `kinds`, `over` (kept), `robots: Array` (filled by Task 3, `[]` here), `bin: Dictionary`, `tick_n: int`, `events`, `dirty`, `alpha`, `picked`.
  - An item is `{"id": int, "kind": "square" | "box", "n": int, "at": float, "from": int, "was": Vector2}` (`n` only on a box; `colour` and `shape` absent until milestone 3).
  - `station_at(tile: Vector2i) -> String` ("" on open floor), `on_floor(tile: Vector2i) -> bool`, `can_lay(tile) -> bool` (false on a station tile), `gives(tile: Vector2i) -> Dictionary` (the item a Pick would take now, `{}` for nothing: the intake's square if `queue > 0`, a new empty box on the stack, the table's box only when `n >= BOX_FULL`, a belt tile's front item, the top of a lying stack), `take(tile: Vector2i) -> Dictionary` (does it), `takes(tile: Vector2i, it: Dictionary) -> bool` (would a Release land), `put(tile: Vector2i, it: Dictionary) -> bool` (does it: the table rule, the deliver sale through `_sell(it)`, a belt through `_belt_drop`, else lies), `_sell(it: Dictionary) -> int` (pays `PAY_FULL` for a box with `n >= BOX_FULL`, `n` for a box, `PAY_SQUARE` for a square; appends `{"type": "sale", "tile": STATIONS.deliver, "kind", "n", "amount", "coins"}`), `unlocked(kind: String) -> bool` (belts: `milestone >= 1`, Task 4; here always true), `price(kind) -> int`, `lay_belt`, `turn`, `flip_line`, `line_through`, `line_tiles`, `sell`, `sell_belts`, `item_pos`, `front_of_tile(tile) -> Dictionary` (the belt's front item or `{}`), `step`, `_tick`, `pack`, `save`, `load_saved`, `new_floor(seed)` (replaces `new_land`).
  - `_tick` order: `_feed()` (the intake queue), `_move_belts()`, `_run_robots()` (Task 3, empty here), `_pace()` (Task 4, empty here); belts that deliver onto a station call `put` for that tile (the table takes a square into a box with room, deliver sells, the intake pad and bay refuse and the belt waits).
  - `load_saved()` returns false and leaves the sim untouched for any `version != VERSION`; `factory_tab.gd` already starts new on false and overwrites on the next save (the quiet wipe).
- Consumes: nothing new.

- [ ] **Step 1: Write the probe's first section**

Rewrite `tests/_probe_factory.gd` around the kept helpers (`_ok`, `_tick`, `_run`, `_until`) with `_check_floor()`:

```gdscript
# a new floor
_ok("floor stations", sim.station_at(Vector2i(4, 5)) == "table" and sim.station_at(Vector2i(1, 1)) == "charger" and sim.station_at(Vector2i(2, 2)) == "")
_ok("no belt on a station", not sim.can_lay(Vector2i(4, 5)) and sim.can_lay(Vector2i(2, 5)))
_ok("intake fills", _after(sim, 10).queue == 1 and _after(sim, 100).queue == 6)   # one a FEED_TICKS, QUEUE_MOST at most
_ok("stack gives a box", sim.gives(Vector2i(4, 1)).kind == "box" and sim.gives(Vector2i(4, 1)).n == 0)
_ok("table takes a box then squares", sim.put(T, box) and not sim.takes(T, box) and sim.takes(T, sq) and sim.put(T, sq) and sim.table.n == 1)
_ok("table gives only a full box", sim.gives(T).is_empty() and _fill(sim, 3) and sim.gives(T).kind == "box")
_ok("deliver pays", sim.put(D, full_box) and sim.coins == 6 and sim.put(D, sq) and sim.coins == 7 and sim.put(D, empty_box) and sim.coins == 7)
_ok("floor holds a stack", sim.put(Vector2i(2, 2), sq) and sim.put(Vector2i(2, 2), sq2) and sim.take(Vector2i(2, 2)).id == sq2.id)
# a belt from the intake pad's side to the table carries a square into the box
_belt_row(sim, Vector2i(2, 5), 2, 0)   # (2,5),(3,5) facing +x into the table
_ok("belt feeds the table", sim.put(Vector2i(2, 5), sq3) and _until_table_n(sim, 2, 200))
_ok("belt waits at a full box", ... the fifth square stays on (3,5) at `at == 1.0`)
# save
_ok("round trip", Sim.new(1) loaded from sim.save() packs equal to sim.pack())
_ok("old save wiped", a cfg written with version 4 -> load_saved() == false and the sim untouched)
```

Delete `tests/_shot_factory_art.gd` (the art it shot is gone; Task 5's harness shoots the floor).

- [ ] **Step 2: Run the probe to see it fail**

Run: `godot --headless --path . --check-only --script res://tests/_probe_factory.gd; godot --headless --path . --script res://tests/_probe_factory.gd`
Expected: a parse error or script error naming `station_at` / `STATIONS` (the old sim has neither).

- [ ] **Step 3: Cut and extend the sim**

In `factory/sim.gd`: remove plates, sources, trees, forests, mines, `tap`, `_chop`, `_run_sources`, `_light`, the market and `_sell` of modules, goals and `GOALS`, `modules`, `place`, `_place_why`, `upgrade*`, `_heat`, `_run_modules`, `_burn`, `fit_stoker`, the splitter (`_split_way`, `_yields`' splitter branch, `kinds == "splitter"`), `SELLS`, `START_COINS`, `GIVES`, `KINDS`, `FOREST_AT`, `MARKET_AT`, `PLATE`, `plate_of`, `free_edges`, `buy_plate`. Rewrite the header comment as the API list above. `on_land` becomes `on_floor` (0 ≤ x < COLS, 0 ≤ y < ROWS). `tile_free` = on the floor, not a station, no belt. `put` takes an item Dictionary; `_lay_down`, `_belt_drop`, `_enter`, `_item` carry the dictionary through (an item's `kind` is read, never a `SELLS` lookup). `pack()` holds `version, seed, rng, coins, earned, acc, next_id, picked, tick_n, queue, table, belts, kinds, over, items, robots, bin, turn` (+ Task 4's pace fields). A new floor: `coins 0`, `queue 0`, `table {}`, `bin {"gripper": 1}`, `stations` from `STATIONS`.

- [ ] **Step 4: Run the probe to see it pass**

Run: `godot --headless --path . --script res://tests/_probe_factory.gd`
Expected: every `_check_floor` line `PASS`, `0 failed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add factory/sim.gd tests/_probe_factory.gd
git rm tests/_shot_factory_art.gd
git commit -m "feat(factory): the sim cut to a floor of stations, items and belts (VERSION 5)"
```

### Task 3: Robots, parts and the program walker

**Files:**
- Create: `factory/bots.gd`
- Modify: `factory/sim.gd` (robots, parts, the bin, the editing API, `_run_robots`)
- Modify: `tests/_probe_factory.gd` (`_check_robots`)

**Interfaces:**
- Produces, in `factory/sim.gd`:
  - `const PARTS := {"treads": {"gives": ["move"], "step": 4}, "gripper": {"gives": ["pick", "release"]}, "battery": {"cell": 30, "rate": 1}, "fast": {"gives": ["move"], "step": 2, "price": 30, "from": 1}, "plug": {"rate": 2, "price": 40, "from": 1}}` (`from`: the milestone that puts it in the bin; `counter`, `body2`, `cell` are the next pass and are not rows).
  - `const NODES := {"move": {"part": "treads", "ports": ["out"]}, "pick": {"part": "gripper", "ports": ["out"]}, "release": {"part": "gripper", "ports": ["out"]}}`; `const BODY := "body"`.
  - `const CELL := 30`, `const ACT_TICKS := 4`, `const BODY_TICKS := 2`.
  - `robots: Array` of robot Dictionaries: `{"name": String, "dock": Vector2i, "tile": Vector2i, "was": Vector2i, "parts": Array[String], "nodes": {id: {"kind", "facing": int, "n": int}}, "order": Array[String], "next": {id: {"out": id or ""}} (BODY has an "out" row too), "pc": String, "t": int, "left": int, "held": Dictionary, "charge": int, "charging": bool, "stuck": String ("" | "?" | "flat" | "nocell"), "bubble": String, "bubble_t": int, "counters": {}}`. `was` is the tile it stepped from, for the view's `alpha`.
  - `new_floor` builds the three robots of spec section 8 with `Bots.new_robot(name, parts, chain)` where `chain` is an Array of `[kind, facing, n]` rows plus one loose index for the Shipper (`Bots.loose_after(b, id)`).
  - Editing (each returns whether it did anything, sends the robot home via `Bots.home(b)` and appends `{"type": "edited", "robot": i}`): `set_next(i: int, from: String, port: String, to: String) -> bool` (to `""` clears; `from == to` refused), `add_node(i: int, after: String, port: String, kind: String) -> String` (the new id or ""; refused when `kind` is not given by the parts; the new node takes `after`'s old target on its `out`), `remove_node(i: int, id: String) -> bool` (every wire into `id` goes to `id`'s `out`), `set_move(i: int, id: String, facing: int, n: int) -> bool` (n clamped 1..9), `fit(i: int, part: String) -> bool` (from the bin, else bought at `PARTS[part].price` when `milestone >= from`, else `_no("coins")` / `_no("later")`), `unfit(i: int, index: int) -> bool` (back to the bin), `tow(i: int) -> bool` (only when `stuck == "flat"`: tile = dock, charge kept at 0, pc = BODY).
  - `_run_robots()`: `for b in robots: Bots.tick(self, b)`.
  - Events from the walker: `pick {robot, tile, kind}`, `release {robot, tile, kind}`, `step {robot, from, to}`, `bump {robot, tile}`, `skip {robot, id}`, `wait {robot}`, `stuck {robot}`, `flat {robot, tile}`, `charging {robot, units}`, `charged {robot}`, `sale` (from `put`).
- Produces, in `factory/bots.gd` (`extends RefCounted`, all static, the sim passed in):
  - `new_robot(name: String, parts: Array, chain: Array) -> Dictionary` (the chain's nodes get the ids `"a"`, `"b"`, ... in order, wired `body → a → b → ... → body`; nodes added later by `sim.add_node` get `"n%d"`), `loose_after(b: Dictionary, id: String) -> void` (clears `next[id].out`).
  - `walk(b: Dictionary) -> Dictionary` → `{"ids": Array[String], "closed": bool}`: follows `next[id].out` from BODY until `""`, BODY, an unknown id or a repeat; `closed` only when it reached BODY.
  - `can(b: Dictionary, kind: String) -> bool` (a part in `b.parts` whose `gives` has `kind`).
  - `step_ticks(b) -> int` (the smallest `step` among the parts that give move), `rate(b) -> int` (the largest `rate`), `cell(b) -> int`.
  - `cost(b: Dictionary) -> int`: units one loop of the reachable chain spends (a Move `n`, others 1).
  - `net(b: Dictionary) -> Vector2i`: where the reachable chain ends relative to where it starts.
  - `home(b: Dictionary) -> void`: tile = dock, pc = BODY, t = 0, stuck = "", bubble = "", counters cleared; `held` and `charge` kept.
  - `tick(sim: RefCounted, b: Dictionary) -> void`: the spec's section 5 and 6 rules, in ticks: at BODY on the bay with `charge < cell` it charges `rate` a tick until full (`charging`), else BODY_TICKS; a Move walks `n` tiles at `step_ticks` each, costing 1 a tile, bumping (ACT_TICKS, 1 unit, the rest dropped) at the floor's edge; Pick and Release are ACT_TICKS then `sim.take` / `sim.put`, a refused Release waits (`bubble "wait"`, no cost, retried next tick); a node `can` not do is skipped after ACT_TICKS for 1 unit with `bubble "!"`; `charge == 0` off the bay is `stuck "flat"`; no battery part is `stuck "nocell"`; `next[pc].out == ""` after a node is `stuck "?"`; every node done goes `_advance`.

- [ ] **Step 1: Write `_check_robots` in the probe**

```gdscript
var sim := Sim.new(3)
_ok("three on the bay", sim.robots.size() == 3 and sim.robots.all(func(b): return b.tile == Sim.BAY))
_ok("picker lacks pick", not Bots.can(sim.robots[0], "pick") and Bots.walk(sim.robots[0]).closed)
_ok("shipper loose", not Bots.walk(sim.robots[2]).closed and Bots.walk(sim.robots[2]).ids.size() == 3)
_ok("picker walks empty", _until_event(sim, "release", 400) and sim.robots[0].held.is_empty() and sim.robots[0].tile == Vector2i(4, 5))
_ok("boxer litters (4,4)", _until(sim, "release", 400) ... and sim.items.has(Vector2i(4, 4)))
_ok("shipper stops ?", _run(sim, 200); sim.robots[2].stuck == "?")
# the fixes
_ok("gripper from the bin", sim.fit(0, "gripper") and sim.bin.gripper == 0 and sim.robots[0].tile == Sim.BAY)
var pick_id := sim.add_node(0, Bots.walk(sim.robots[0]).ids[0], "out", "pick")
_ok("pick inserted after move down", pick_id != "" and Bots.walk(sim.robots[0]).ids[1] == pick_id)
_ok("picker holds a square and waits", _until_event(sim, "wait", 600) and sim.robots[0].held.kind == "square")
_ok("boxer fixed", sim.set_move(1, "c", 1, 4) and sim.set_move(1, "e", 3, 4) and Bots.net(sim.robots[1]) == Vector2i.ZERO)
_ok("shipper wired", sim.set_next(2, "c", "out", "d") and Bots.walk(sim.robots[2]).closed)
_ok("first full box pays 6", _until_event(sim, "sale", 3000) and sim.coins == 6)
# costs and charging
_ok("picker loop costs 16", Bots.cost(sim.robots[0]) == 16)
_ok("charges at the bay", _until_event(sim, "charging", 400) and sim.robots[0].tile == Sim.BAY and _until_event(sim, "charged", 40) and sim.robots[0].charge == 30)
# review focus
_ok("insert after last keeps loop", add_node(0, last_id, "out", "release") -> next[new].out == Sim.BODY and walk closed)
_ok("cycle off the body goes flat", set_next(0, last_id, "out", first_id) -> walk not closed, ids finite; _run 1200; stuck == "flat")
_ok("bump mid move", a robot with Move ← 4 from x = 2: after the bump tile == (0, y), charge down by 3, event "bump" once, pc advanced)
_ok("unfit mid node", sim.unfit(1, index_of_gripper) while pc is the Boxer's pick -> robot home, next run of that node emits "skip" and costs 1)
_ok("edit keeps charge", charge before an edit == charge after `set_move` on that robot)
_ok("tow arrives empty", a flat robot: sim.tow(i) -> tile == BAY, charge == 0, then "charging" within 3 ticks)
_ok("no cell", sim.unfit(0, index_of_battery) -> stuck == "nocell" after a tick; fit back -> runs)
```

- [ ] **Step 2: Run the probe to see it fail**

Run: `godot --headless --path . --script res://tests/_probe_factory.gd`
Expected: a script error naming `Bots` or `robots` (neither exists).

- [ ] **Step 3: Write `factory/bots.gd` and the sim's robot API**

Node ids are `"n%d" % _next_id`. The walker's `_advance(sim, b)`: `var to: String = b.next[b.pc].out`; `""` or unknown → `stuck "?"` + event `stuck`; BODY → `pc = BODY` (`counters` cleared, Task 3 has none); else `pc = to`, `t = 0`, `left = n` for a Move. A bubble is cleared after `bubble_t` ticks (`"wait"` 4, `"!"` 9, `"?"`, `"flat"`, `"nocell"` held).

- [ ] **Step 4: Run the probe to see it pass**

Run: `godot --headless --path . --script res://tests/_probe_factory.gd`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add factory/bots.gd factory/sim.gd tests/_probe_factory.gd
git commit -m "feat(factory): robots, parts, the battery and the node walker"
```

### Task 4: Pace, the hold and milestone 1

**Files:**
- Modify: `factory/sim.gd` (`_pace`, `MILESTONES`, `unlocked`, the bin by milestone, `pack`)
- Modify: `tests/_probe_factory.gd` (`_check_pace`, the pace bot)

**Interfaces:**
- Produces, in `factory/sim.gd`:
  - `const WINDOW := 600`, `const HOLD := 600`, `const MILESTONES := [{"id": "line", "every": 0}, {"id": "belts", "every": 300}, {"id": "again", "every": 150}]` (`every`: ticks a full box at most; the values of rows 1 and 2 are set in Step 3 from the bot).
  - State: `sold_at: Array[int]` (tick stamps of full-box sales in the last WINDOW), `held_for: int`, `milestone: int`.
  - `pace_ticks() -> int` (the mean gap of `sold_at`, 0 under two), `pace_s() -> float`, `milestone_open(n: int) -> bool`, `_pace()`: drops stamps older than WINDOW; `held_for` counts ticks the rate of the next milestone is met (`sold_at.size() >= 2 and pace_ticks() <= every`), reset to 0 when not; at HOLD, `milestone += 1`, `held_for = 0`, event `{"type": "milestone", "id"}`.
  - `unlocked("belt" | "fast" | "bridge") -> bool` is `milestone >= 1`; `fit` of a priced part needs `milestone >= PARTS[part].from`; `bin_rows() -> Array` of `{"part", "state": "spare" | "price" | "later" | "none", "price"}` for the sheet's tray.
  - `pack()` adds `sold_at, held_for, milestone`.
- Consumes: Task 3's walker and editing API.

- [ ] **Step 1: Write `_check_pace` and the pace bot**

```gdscript
_ok("pace blank under two", sim.pace_ticks() == 0)
# the bot: the three fixes of Task 3 on a fresh floor, then run
_fix_all(sim)
var opened := _until_event(sim, "milestone", 60000)
print("pace: %d ticks a box after the three fixes (%.1f s)" % [sim.pace_ticks(), sim.pace_s()])
_ok("milestone 1 opens from the three fixes alone", opened > 0 and sim.milestone == 1)
_ok("a total never opens it", a floor that sells one full box and then nothing for 2000 ticks keeps milestone 0 and held_for 0)
_ok("hold resets on a stall", held_for climbs, then a 700-tick stall (queue starved: set sim.queue = 0 and FEED off via a test flag) brings it to 0)
_ok("belts locked before 1", a fresh floor: not sim.unlocked("belt"); the opened floor: sim.unlocked("belt") and sim.lay_belt(Vector2i(2, 5), 0))
_ok("fast plug halves the pause", fit(0, "plug") with coins >= 40 -> the next "charging".."charged" span is half the one before)
_ok("fast treads halve the walk", fit(0, "fast") -> Bots.step_ticks(robot) == 2)
_ok("round trip mid loop", save at tick 137 of the running floor; a sim loaded from it stepped 500 ticks packs equal to the original stepped 500 ticks)
```

- [ ] **Step 2: Run the probe to see it fail**

Run: `godot --headless --path . --script res://tests/_probe_factory.gd`
Expected: a script error naming `pace_ticks`.

- [ ] **Step 3: Implement, then set the two rates from the bot**

Implement `_pace` and the milestone rows with `every` 300 and 150. Run the probe once and read its `pace:` line. Set `MILESTONES[1].every` to that reading plus 20 % (rounded to 10 ticks) and `MILESTONES[2].every` to half of it, with a comment quoting the reading and the date. Re-run.

- [ ] **Step 4: Run the probe to see it pass**

Run: `godot --headless --path . --script res://tests/_probe_factory.gd`
Expected: `0 failed`, and the `pace:` line printed.

- [ ] **Step 5: Commit**

```bash
git add factory/sim.gd tests/_probe_factory.gd
git commit -m "feat(factory): pace over a rolling minute, the hold, milestone 1 and the bin by milestone"
```

### Task 5: The floor drawn

**Files:**
- Modify: `factory/art.gd` (cut to the floor; new meshes)
- Modify: `factory/life.gd` (rewritten for a top-down floor)
- Modify: `factory/tile.gd` (only what the drawer's belt tiles need; machines' tiles removed)
- Modify: `ui/menu/factory_tab.gd` (`_fit` on `_life.bounds()`; `Art.DEPTH` gone)
- Modify: `tests/_shot_factory.gd` (rewritten; this task's section shoots the floor)

**Interfaces:**
- Produces, in `factory/art.gd` (all static, meshes built once and cached in a `static var`):
  - `const TILE := 130.0` (view units a tile), `static func at(t: Vector2) -> Vector2` (`t * TILE`), `static func tile_at(v: Vector2) -> Vector2`, `static func flat(tile: Vector2i, facing: int) -> Transform2D` (kept, for belts and ghosts), `DIRS` kept.
  - `floor_mesh(cols: int, rows: int) -> ArrayMesh` (the ground and its dots), `pad(kind: String) -> ArrayMesh` ("intake", "stack", "table", "deliver", "charger"; the charger with its bolt and cable), `fixed_belt(rows: int, up: bool) -> ArrayMesh` (the intake and deliver belts, chevrons as a MultiMesh row the life animates by offset), `square() -> ArrayMesh`, `box(n: int) -> ArrayMesh` (0..4, cached per n), `robot() -> ArrayMesh` (body, treads; the face from `ui/faces/face.gd`'s builder: two eyes, a mouth that changes with `stuck`), `bubble(kind: String) -> ArrayMesh` ("?", "!", "wait", "flat", "nocell", "charge"), `battery_bar(f: float) -> Transform2D` (the bar's scale for a fraction; one mesh), `water`/`light` kept as the field's wash and frame, `short(n)` kept, belt meshes kept.
- Produces, in `factory/life.gd`: `mount(parent: Node, with_sim: RefCounted) -> Node2D`, `hold(with_sim)`, `layer(draws: Callable, material = null, into = null) -> Node2D`, `stale()`, `seen(t: Vector2) -> Vector2` (`Art.at`; no turn), `tile_at(v: Vector2) -> Vector2`, `bounds() -> Rect2` (the floor in view units), `tile_bounds() -> Rect2`, `mid(tile: Vector2i) -> Vector2`, `event(e: Dictionary)`, `step(delta: float)`, `robot_pos(i: int) -> Vector2` (between `was` and `tile` by `sim.alpha`, view units), `item_at(tile, it) -> Vector2` (kept), `var ghosts`. Layers, back to front: ground (one mesh), belts (kept MultiMeshes), items (Batch per mesh: squares, boxes), robots (Batch for bodies; faces by `stuck`), bubbles and battery bars, ghosts. No wind material, no beaver, no `set_turn`.
- Consumes: Task 1's `ui/hud/batch.gd`, Task 3's robot fields.

- [ ] **Step 1: Write the harness's floor section**

Rewrite `tests/_shot_factory.gd` (keep `_shot`, `_ok`, the touch helpers, the throwaway save at `user://factory_harness.cfg`): build the screen on `Sim.new(7)`, step it 300 ticks, and check:

```gdscript
_ok("three robots drawn", life.robot_pos(0) != life.robot_pos(1) or sim.robots[0].tile == sim.robots[1].tile)   # positions follow tiles
_ok("picker walks between tiles", after 2 ticks mid-move: robot_pos(0) is strictly between seen(was) and seen(tile))
_shot("floor_start")          # prints draw calls; expected under 120
_ok("draw calls under budget", draws < 855)
_ok("bubble over the shipper", sim.robots[2].stuck == "?" and the bubbles layer batched >= 1)
```

- [ ] **Step 2: Run the harness to see it fail**

Run: `ulimit -f 2000000; timeout 600 caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_factory.gd -- /tmp/factory_shots > /tmp/factory.log 2>&1; tail -5 /tmp/factory.log`
Expected: a script error (`robot_pos` missing, or `Art.DEPTH`).

- [ ] **Step 3: Rewrite art and life, and fix the tab's `_fit`**

Remove from `art.gd` everything about trees, wind, plates, grass, pads (lilies), rims, machines, the market, logs and heaps, `K`/`DEEP`/`ISO`/`RISE`/`DEPTH`/`depth`; keep `water`, `light`, `short`, the belt meshes (`BELT`, `belt_under*`, bed shapes) and `flat`. `life.gd` keeps its layer/mount/custom-rect pattern and the belt filling (`_lay_belts`, `shape`, `item_at`), replaces `_fill_stand` with `_fill_robots`, drops `_fill_items`' kind table for `square`/`box(n)`. `factory_tab.gd`'s `_fit` uses `box.size` without `Art.DEPTH`.

- [ ] **Step 4: Run the harness to see it pass**

Run: the Step 2 command, then `grep -c FAIL /tmp/factory.log`
Expected: `0`; the `floor_start` shot's draw calls printed under 855.

- [ ] **Step 5: Commit**

```bash
git add factory/art.gd factory/life.gd factory/tile.gd ui/menu/factory_tab.gd tests/_shot_factory.gd
git commit -m "feat(factory): the floor drawn top-down: pads, bay, fixed belts, squares, boxes, robots"
```

### Task 6: The screen cut, robot chips and the pace pill

**Files:**
- Modify: `factory/screen.gd`
- Modify: `locale/ui.csv` (the keys this task shows)
- Modify: `tests/_shot_factory.gd` (the screen section)

**Interfaces:**
- Produces, in `factory/screen.gd`:
  - Kept: `setup`, `puzzle_id`, `_build` (minus cards), the camera (`_place_world`, `to_field`, `screen_of`, `tile_under`, `_clamp`, `set_far`, `_zoom_by_hand`, `_step_view`, `_edge_pan`), the hand (`_on_field_input`, `_press`, `_drag`, `_release`, `_let_go`, `hit`), the belt drawer (`DRAWER_TILES := ["belt", "fast", "bridge"]`), tracing (`_run_to`, `_lay_run`, `_trace_to`, `_trace_straight`, `_path_run`, `_lay_path`), the belt pill (`PILL_PLAIN`, `_open_piece`, `_piece_press`, `_draw_piece`), the coin pill, `_save`, `_on_back`, `go_back`, `tutorial_pages` (Task 8), `closed`.
  - Removed: `_turn_b`, `turn_view`, `look_at_plate`, `_goal_b` and `_draw_goal*`, `open_goals`, `open_plate`, `open_module`, `open_forest`, `_open_card`, `_card_*`, `badge_at`, `_draw_badge`, `_draw_flow`, `_fit`/`_place`/`_ghosts` for machines (belt ghosts stay), `_tap`'s source/badge/module/plus arms, `NAMES` rows of machines, `_free_b` stays (`no_cost`).
  - New: `const CHIP_H := 84.0`; `var selected := 0` (the robot the chips mark); a row of robot chips under the top bar (`robot_chip_rect(i: int) -> Rect2`, a tap selects and opens the sheet, a red dot on a chip whose robot has a fault: `not Bots.walk(b).closed or stuck != "" or a node it cannot do`); the pace pill beside the coin pill (`pace_text() -> String`: `tr("FACTORY_PACE") % sim.pace_s()` or `tr("FACTORY_PACE_NONE")`); `hit(pos)` returns `{"what": "robot", "id": i}` within `TAP * 2` of `life.robot_pos(i)`; `_tap` on a robot calls `open_sheet(i)` (Task 7's; here a stub that selects the chip); `_play_events` cues (Task 10 wires the bank; here `_fx.touch()` on `pick`, `release`, `sale` through `_on_coin`).
  - `_layout_field` starts the camera on `life.seen(Vector2(COLS * 0.5, ROWS * 0.5))` with `_near = field.size.x / (COLS * Art.TILE)` so the whole floor fits the width.
  - Locale rows added: `FACTORY_PACE` ("a box every %s s" / "uma caixa a cada %s s" / "una caja cada %s s"), `FACTORY_PACE_NONE` ("no box yet" / "nenhuma caixa ainda" / "ninguna caja aún"), `FACTORY_PICKER`, `FACTORY_BOXER`, `FACTORY_SHIPPER`; retired: every `FACTORY_*` row of machines, forests, mines, plates, goals, levels and `FACTORY_TURN`.
- Consumes: Task 5's `life.robot_pos`, Task 4's `pace_s`, `unlocked`.

- [ ] **Step 1: Write the screen section of the harness**

```gdscript
_ok("three chips", screen.robot_chip_rect(2).size.x > 0)
_ok("fault dots", the chips of all three carry a dot on a new floor)
_tap(screen.robot_chip_rect(1).get_center()); _ok("chip selects", screen.selected == 1)
_tap(screen.screen_of(Vector2(sim.robots[0].tile) + Vector2(0.5, 0.5))); _ok("robot tap selects", screen.selected == 0)
_ok("pace pill reads none", screen.pace_text() == tr("FACTORY_PACE_NONE"))
_ok("drawer locked before milestone 1", the drawer shows no belt tile on a new floor)
sim.milestone = 1; _ok("belt traced", a swipe from (2,5) to (3,5) with Belt picked lays two belts facing +x)
_shot("screen_start"); _ok("under budget", draws < 855)
```

- [ ] **Step 2: Run the harness to see it fail**

Run: the harness command of Task 5.
Expected: a script error naming `robot_chip_rect`.

- [ ] **Step 3: Cut and extend the screen**

Also delete `tests/_shot_factory_menu.gd`'s plate and forest steps (it opens through the real menu and shoots the screen; keep it to the open, one shot and the back).

- [ ] **Step 4: Run both harnesses to see them pass**

Run: the `_shot_factory` command, then the same with `_shot_factory_menu.gd`; `grep -c FAIL` on each log.
Expected: `0` and `0`.

- [ ] **Step 5: Commit**

```bash
git add factory/screen.gd locale/ui.csv tests/_shot_factory.gd tests/_shot_factory_menu.gd
git commit -m "feat(factory): the screen cut to the floor, with robot chips and the pace pill"
```

### Task 7: The sheet

**Files:**
- Create: `factory/sheet.gd`
- Modify: `factory/screen.gd` (mounts it; `open_sheet`)
- Modify: `ui/icons.gd` (if `minus`/`plus`/`turn`/`bin` lack a glyph the pill needs; `plus`, `minus`, `turn`, `bin`, `help`, `check` exist)
- Modify: `locale/ui.csv`
- Modify: `tests/_shot_factory.gd` (the sheet section)

**Interfaces:**
- Produces, in `factory/sheet.gd` (`extends Control`, laid over the lower part of the field):
  - `signal closed`; `setup(with_sim: RefCounted, fx: Node2D)`; `open(i: int)`; `close()`; `is_open() -> bool`; `var robot: int`.
  - Constants: `HEIGHT := 0.58` (of the field), `BODY := 112.0`, `NODE_H := 96.0`, `NODE_W := 96.0`, `MOVE_W := 128.0`, `GAP := 40.0`, `PORT_HIT := 80.0`, `PART := 84.0`, `TRAY_H := 110.0`, `SLIDE := 0.26` (Motion), `DRAG := 6.0`.
  - Layout (`_layout() -> Dictionary` of id -> Rect2 in the sheet's pixels, the chain from `Bots.walk` then the unreached in `order`, the body at the left, parts under it, the pane panned by `_pan: float`): `node_rect(id: String) -> Rect2`, `out_port(id: String) -> Vector2`, `in_port(id: String) -> Vector2`, `plus_rect(after: String) -> Rect2` (the `+` past a loose `out`, or the mid-wire `+`), `parts_plus_rect() -> Rect2`, `part_rect(index: int) -> Rect2`, `tray_rect(kind: String) -> Rect2` (a tray chip; `Rect2()` when the tray is closed), `tray_locked(kind: String) -> bool` (shown dim with `FACTORY_NEEDS`), `pill_button_rect(name: String) -> Rect2`.
  - Input (ScreenTouch/ScreenDrag and the mouse, as the screen's): a tap on a node selects it and opens the pill (`PiecePill`, buttons by kind: Move `["turn", "minus", "plus", "lift"]`, Pick/Release `["lift"]`, a part `["lift"]`, the body `["info"]` plus `["place"]` captioned Tow when `stuck == "flat"`); a tap on a `+` opens the tray (`_tray = {"after": id}` or `{"parts": true}`); a tap on a tray chip calls `sim.add_node` / `sim.fit`; a press on an `out` port that moves over DRAG drags a wire (`_wire = {"from": id, "at": Vector2}`) and a release on a node calls `sim.set_next(robot, from, "out", id)`; a press and release on the port without moving arms it (`_armed = id`) and the next tap on a node wires; a drag elsewhere pans; a swipe down from the handle closes.
  - Drawing: one `ArrayMesh` rebuilt on `_dirty` (set by every sim event `edited` and by `open`) through `Face.Builder`: the dotted grid, wires (cubic, the loop-back round the top with "again"), node boxes, ports (a loose `out` red, an armed one blue), glyphs (Move's arrow and count via the builder's text), labels, the parts' dashed wires and diamond ports, the `+` boxes; over it per frame: the running node's glow (`Motion`), the dragged wire, the tray, the pill (`_pill_ui.draw`).
  - The body's pill `info` shows a line under the title: `tr("FACTORY_BATTERY_LINE") % [charge, cell, Bots.cost(b), Bots.cost(b) * Sim.TICK / Bots.rate(b)]`.
- Produces, in `factory/screen.gd`: `open_sheet(i: int)` (the chips stay above it; the camera pans so `life.robot_pos(i)` is in the field's upper part), `var sheet: Control`.
- Locale rows: `FACTORY_MOVE` ("Move"), `FACTORY_PICK`, `FACTORY_RELEASE`, `FACTORY_BODY`, `FACTORY_TREADS`, `FACTORY_GRIPPER`, `FACTORY_BATTERY`, `FACTORY_FAST_TREADS`, `FACTORY_FAST_PLUG`, `FACTORY_FEWER` ("Fewer"), `FACTORY_MORE` ("More"), `FACTORY_REMOVE` ("Remove"), `FACTORY_TAKE_OFF` ("Take off"), `FACTORY_TOW` ("Tow"), `FACTORY_INFO` ("Battery"), `FACTORY_NEEDS` ("needs %s"), `FACTORY_IN_BIN` ("in the bin"), `FACTORY_LATER` ("later"), `FACTORY_AGAIN` ("again"), `FACTORY_PARTS` ("parts"), `FACTORY_ADD_NODE` ("Add a node"), `FACTORY_FIT_PART` ("Fit a part"), `FACTORY_BATTERY_LINE` ("%d of %d · %d a loop · %.1f s on the bay"), `FACTORY_FLAT` ("flat, away from the bay"), each in en, pt, es.
- Consumes: Task 3's editing API and `Bots`, Task 4's `bin_rows`, `ui/hud/piece_pill.gd`.

- [ ] **Step 1: Write the sheet section of the harness**

```gdscript
screen.open_sheet(0); _ok("sheet open", screen.sheet.is_open() and screen.sheet.robot == 0)
_ok("chain laid out", sheet.node_rect("a").position.x < sheet.node_rect("b").position.x)
_tap(sheet.plus_rect("a").get_center()); _ok("tray opens", sheet.tray_rect("move").size.x > 0 and sheet.tray_rect("pick").size.x > 0)
_ok("pick locked without a gripper", sheet.tray_locked("pick"))
_tap(sheet.parts_plus_rect().get_center()); _tap(sheet.tray_rect("gripper").get_center()); _ok("gripper fitted", sim.robots[0].parts.has("gripper"))
_tap(sheet.plus_rect("a").get_center()); _tap(sheet.tray_rect("pick").get_center()); _ok("pick inserted", Bots.walk(sim.robots[0]).ids[1] begins with "n")
_tap(sheet.node_rect("b").get_center()); _ok("move pill", sheet.pill_button_rect("plus").size.x > 0)
_tap(sheet.pill_button_rect("plus").get_center()); _ok("plus counts", sim.robots[0].nodes["b"].n == 4)
screen.open_sheet(2); _drag(sheet.out_port("c"), sheet.node_rect("d").get_center()); _ok("wire dragged", sim.robots[2].next["c"].out == "d")
_tap(sheet.out_port("d")); _tap(sheet.node_rect("e").get_center()); _ok("tap-tap wires", sim.robots[2].next["d"].out == "e")
_shot("sheet_open"); _ok("under budget", draws < 855)
_ok("sheet is one mesh", sheet draw calls (the field's count with the sheet minus without) <= 6)
```

- [ ] **Step 2: Run the harness to see it fail**

Expected: a script error naming `open_sheet` or `sheet`.

- [ ] **Step 3: Write `factory/sheet.gd` and mount it**

- [ ] **Step 4: Run the harness to see it pass**

Expected: `grep -c FAIL` → `0`; `sheet_open` under 855.

- [ ] **Step 5: Commit**

```bash
git add factory/sheet.gd factory/screen.gd ui/icons.gd locale/ui.csv tests/_shot_factory.gd
git commit -m "feat(factory): the program sheet: nodes, ports, wires, the tray, the pill, one mesh"
```

### Task 8: The tutor's six pages

**Files:**
- Modify: `ui/hud/factory_tutorial_diagram.gd` (rewritten: `enum Lesson {POWER, PICKER, BOXER, SHIPPER, BOX, SPEND}`)
- Modify: `factory/screen.gd` (`tutorial_pages`)
- Modify: `locale/ui.csv` (`TUT_FACTORY_1..6`, `TUT_FACTORY_1..6_BODY`; the four old pairs retired)
- Modify: `tests/_shot_factory.gd` (the pages shot)

**Interfaces:**
- Produces: a diagram page mounts `Life` on `Sim.new(SEED)` and plays, per lesson: POWER the floor at rest with the three `?`/`!`; PICKER the sheet's chain drawn small (`factory/sheet.gd` in a `preview := true` mode that draws its mesh into a given rect and takes no input) with the Gripper fitted and Pick inserted by `sim.fit`/`sim.add_node` at `t = 2 s`; BOXER the two Moves set to 4 at `t = 2 s`; SHIPPER the wire landing; BOX the first sale and the pause at the bay; SPEND the tray with the bin's rows. Each loops every `LENGTH` seconds; under reduce motion it stands at `STILL`.
- Consumes: Task 7's sheet (`preview` mode), Task 3's editing API.

- [ ] **Step 1: Add the pages check to the harness**

```gdscript
var pages: Array = screen.tutorial_pages()
_ok("six pages", pages.size() == 6 and pages.all(func(p): return p.title.begins_with("TUT_FACTORY_")))
mount each page's diagram at 700x500 for 3 s; _shot("tutor_%d" % i); _ok("page draws under 200", draws < 200)
```

- [ ] **Step 2: Run to see it fail** (expected: four pages, `Lesson.TREE` names)

- [ ] **Step 3: Rewrite the diagram and the pages**

- [ ] **Step 4: Run to see it pass** (`grep -c FAIL` → `0`)

- [ ] **Step 5: Commit**

```bash
git add ui/hud/factory_tutorial_diagram.gd factory/screen.gd factory/sheet.gd locale/ui.csv tests/_shot_factory.gd
git commit -m "feat(factory): the tutor's six pages: power on, three fixes, the first box, spend"
```

### Task 9: The card and the Arcade line

**Files:**
- Modify: `ui/menu/cards/arc_factory.gd` (redrawn: the floor's green, a robot of `art.gd`'s meshes carrying a box toward the go disc, a run of belt)
- Modify: `ui/menu/arcade_tab.gd:124-126` (the line: coins and the pace, `FACTORY_CARD_COINS` + ` · ` + `pace_text`)
- Modify: `ui/menu/factory_tab.gd` (the hidden card's blurb keys)
- Modify: `locale/ui.csv` (`FACTORY_CARD_BLURB` "Three robots, a sheet of nodes", `FACTORY_BLURB`, `FACTORY_MOTTO` "Every loop walks back to the bay", en/pt/es)
- Check: `tests/_shot_factory_menu.gd`

- [ ] **Step 1: Add a check to `_shot_factory_menu.gd`**: the Arcade list's Factory card says `FACTORY_CARD_COINS` with the pace after a floor that sold two boxes; `_shot("card")`.
- [ ] **Step 2: Run to see it fail.**
- [ ] **Step 3: Redraw the card; change the line.**
- [ ] **Step 4: Run to see it pass** (`grep -c FAIL` → `0`).
- [ ] **Step 5: Commit**

```bash
git add ui/menu/cards/arc_factory.gd ui/menu/arcade_tab.gd ui/menu/factory_tab.gd locale/ui.csv tests/_shot_factory_menu.gd
git commit -m "feat(factory): the card redrawn for the robots, the Arcade line says the pace"
```

### Task 10: House finish

**Files:**
- Modify: `tools/gen_sfx.py` (the `factory` set: `pick` bank:lip, `release` bank:token, `node` bank:token, `wire` bank:pebble, `fit` bank:token, `no` bank:tongue, `charge` bank:wrap at -22; `coin` kept)
- Modify: `factory/screen.gd`, `factory/sheet.gd` (`_play_events` cues: `pick`→`pick`, `release`→`release`, `edited` from a node→`node`, a wire→`wire`, `fit`→`fit`, `stuck`/`flat`/`refused`→`no`, `charging` (once per pause)→`charge`, `sale`→`coin` via `_on_coin`, `milestone`→`buy` and `Motion.bump` on the drawer; `HAPTICS := {"node": Haptics.TAP, "wire": Haptics.TICK, "fit": Haptics.BUMP, "coin": Haptics.GOOD, "no": Haptics.WARN, "milestone": Haptics.GOOD}`)
- Modify: `core/analytics.gd` callers: `Analytics.track("factory_fix", {"robot"})` when a robot's chain first closes with every node doable, `"factory_milestone" {"id"}`, `"factory_part" {"part"}`; `factory_enter` keeps `coins` and adds `milestone`.
- Modify: `docs/agents/factory.md` (a new top section "Factory, rewired (2026-10-20)": what stands, the files, the rules that bite: the one-sim rule, no catch-up, ticks, the pace hold, the quiet wipe; the land's history kept below under "The land (dropped 2026-10-20)"), `docs/agents/analytics.md` (the three events), `docs/agents/haptics.md` (the Factory rows), `docs/agents/sound.md` (the factory set row), `docs/agents/arcade.md` (the Factory card line), `docs/agents/harnesses.md` (the two harnesses' flags)
- Modify: `locale/ui.csv` (every new key checked in pt and es; `_ONE`/`_N` where a count appears)

- [ ] **Step 1: Generate and import the sounds**

Run: `python3 tools/gen_sfx.py factory && godot --headless --path . --import`
Expected: `assets/sfx/factory/{pick,release,node,wire,fit,no,charge,coin}.ogg` present; the import ends without error.

- [ ] **Step 2: Wire cues, haptics and analytics; write the docs**

- [ ] **Step 3: The phone's driver**

Run: `ulimit -f 2000000; timeout 600 caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_factory.gd -- /tmp/factory_angle > /tmp/factory_angle.log 2>&1; grep -c FAIL /tmp/factory_angle.log; grep "draw" /tmp/factory_angle.log | sort -t: -k2 -n | tail -1`
Expected: `0`; the highest draw count under 855. Run it twice and quote the second.

- [ ] **Step 4: The suite and the probes**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3; godot --headless --path . --script res://tests/_probe_factory.gd | tail -1; godot --headless --path . --script res://tests/_probe_tally.gd | tail -1; godot --headless --path . --script res://tests/_probe_start_over.gd | tail -1`
Expected: the suite `0 failed`; each probe `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add tools/gen_sfx.py assets/sfx/factory factory/screen.gd factory/sheet.gd docs/agents locale/ui.csv
git commit -m "feat(factory): pops from the bank, haptics, analytics, pt/es and the notes"
```

### Task 11: Whole-branch review and the hand-back

- [ ] **Step 1: Diff against main** (`git diff main --stat`) and check no file still names plates, forests, the market, goals or the view turn outside `docs/agents/factory.md`'s history: `grep -rn "forest\|plate\|market\|turn_view" factory/ ui/menu/factory_tab.gd ui/menu/cards/arc_factory.gd ui/hud/factory_tutorial_diagram.gd tests/_probe_factory.gd tests/_shot_factory.gd` → only comments that say "dropped".
- [ ] **Step 2: Hand back** with the probe and harness lines quoted, the pace reading from Task 4, the draw counts, and the list of the spec's "my call" numbers as they stand in `sim.gd`'s constants block, for the user to merge.
