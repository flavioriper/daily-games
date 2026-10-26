# Gumdrop Fun Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Gumdrop's squeeze the fun, its serve a reveal, and a day quick: a quicker pour, a jelly that wobbles, a chunk that lands with a pop, a serve that never fails but stamps a tier, under the house sound.

**Architecture:** The day is `puzzles/gumdrop_sim.gd` (pure data, headless), the screen is `puzzles/gumdrop_table.gd` (draws, takes fingers, drives the GPU fluid `puzzles/gumdrop_fluid.gd`), the board is `puzzles/gumdrop2d.gd` (a thin `puzzle_base`). The sim gains the landing event, the all-wet serve rule and tiers in place of the mark; the table gains a jelly transform (wobble), the landing's feedback, the reveal's sweep and the tiers' showing; words and sounds follow. No fluid pass is added, no mesh is rebuilt per frame that was not already.

**Tech Stack:** Godot 4.7 GDScript, gl_compatibility (`opengl3_angle` on the phone), canvas meshes under transforms, `tools/gen_sfx.py` bank rows, locale CSVs.

**Spec:** `docs/superpowers/specs/2026-10-26-gumdrop-fun-design.md`

## Global Constraints

- Branch `feat/gumdrop-fun` (made; the spec is its first commit). Nothing is pushed: the user calls the push.
- Harnesses: `--resolution 810x1440` before `--script`, `--always-on-top`, `--rendering-driver opengl3_angle`, under `caffeinate -d -i -u`, `ulimit -f 200000` and `timeout`; one windowed run at a time, few of them; quote draw calls, not ms.
- Budget 855 draw calls; play reads 115-122 today. No new fluid pass. No per-frame mesh rebuild beyond the meter and the rings that already are.
- Honour `Motion.reduce` (`core/motion.gd`): no wobble, no sweep under it.
- The user's rules kept: no move or time limit; a chunk stops at 100% and the dye spreads as a tint in water; chunks hold their own colours; no words over the tray; the gel and tray colours unchanged; the name is Gumdrop and the followed game is never named.
- Sounds: a cue is a `bank:<take>` row in `tools/gen_sfx.py`'s `"gumdrop"` set (`docs/agents/sound.md`, "The house sound"); never a synth, never the old tick. After `tools/gen_sfx.py` and any CSV row: `godot --headless --path . --import`.
- Text through `locale/ui.csv` and `locale/boards.csv`, en/pt/es in one row; titles stay English.
- Parse check before any harness: `godot --headless --check-only --script puzzles/<file>.gd`.
- Every commit message says what the user said and when, as the repo's do.

## Review Focus

1. A tutorial page's round (`ui/hud/gumdrop_tutorial_diagram.gd`'s `Bench`, which prefills cells and serves by plan) must still serve under the all-wet rule: a page that prefills only some cells and serves would now be refused. Test in Task 2 (the bench's MATCH and MIX rounds served).
2. A finished day put back (`Sim.finish`) with old records whose pcts are under the old mark (impossible before, possible now: 30) must show the tier for that number without a "pass" of false. Test in Task 1.
3. The landing must not fire on a tutorial prefill (a cell filled at once to 100% or 150%) or when the tip is moved onto an already-full chunk without squeezing. Test in Task 1 (headless tally) and Task 4 (the table arms only while `sim.squeezing`).
4. The serve button greyed and pressed while the mould has one dry chunk: the tongue pop and a small haptic, no sticker, no serve counted. Test in Task 2.
5. The reveal's sweep and the big wobble under `Motion.reduce`: nothing moves, the stamp still shows, the day still ends. Covered by the harness's `reduce` arg in Task 6.

---

### Task 1: The sim: no mark, tiers, all-wet serve, the landing

**Files:**
- Modify: `puzzles/gumdrop_sim.gd` (consts 43-70, `need`/`verdict` 84-88, `set_day` 129, `can_serve` 339, `step` 360, `judge` 389, `_after` 408, `finish` 422)
- Modify: `tests/_probe_gumdrop.gd` (`_run` 168-187, `_insane` 189-203, `_days` 141 and 153)
- Modify: `ui/hud/gumdrop_tutorial_diagram.gd:51` (`set_day([m], MARK)` → `set_day([m])`)
- Modify: `puzzles/gumdrop2d.gd:46,127,129,208` (the mark's uses)

**Interfaces:**
- Produces: `Sim.TIER_PERFECT := 95`, `Sim.TIER_GREAT := 80`, `Sim.LAND := 0.97` (of `C_FULL`), `Sim.LAND_REARM := 0.87`; `static func tier(pct: int) -> int` returning 2 perfect, 1 great, 0 served; `func set_day(list: Array) -> void` (no mark); `func can_serve() -> bool` true only when every chunk's `tank[c] > WET` and `phase == PLAY`; `func all_wet() -> bool`; event `{"type": "land", "cell": c}` appended once per fill from `step()` when the tally crosses `LAND * C_FULL` while `squeezing`, re-armed when `tank[c]` falls under `LAND_REARM * C_FULL`; `var landed := PackedByteArray()` (a flag a cell, laid with the mould, cleared by `empty()`/`_lay()`); verdict `{"pct", "tier", "pass": true, "perfect"}` (`need` gone); `served` event carries `tier` too; `mark()` and `MARK` gone; `SETTLE_T := 0.45`, `SHOW_T := 2.0`, `RATE := 1.1` (the headless tally: 0.5 × 8.0/3.6, so the probe's hold matches the screen's).
- `_after()`: a served mould is always taken away (`index += 1`, next dealt, or `DONE` on the last); `again` is emitted only by `empty()`'s path as before (check `empty()` emits it; if `empty()` does not, leave Reset's path as it is and only delete the under-mark branch).

- [ ] **Step 1: Rewrite the probe's `_run` and `_insane` to the new rules**

In `tests/_probe_gumdrop.gd` replace the `_run` body's checks with:

```gdscript
var s = _day(0, 7)
_check("nothing to serve until every piece has colour", not s.can_serve())
s.squeeze(true); for i in 6: s.step(); s.squeeze(false)
_check("one wet chunk is not enough to serve", not s.can_serve() and s.wet())
_wet_all(s)
_check("every chunk wet: it can be served", s.can_serve())
var first: Dictionary = s.mould
var tally := _serve_as(s, 0.3)
_check("a mould served at 30%% is taken away all the same, tier 0 (%s)" % str(tally), s.index == 1 and not is_same(s.mould, first) and int(tally.get("deal", 0)) == 1 and int(s.verdict.tier) == 0 and int(tally.get("again", 0)) == 0)
_wet_all(s)
tally = _serve_as(s, 0.97)
_check("the last mould served is the day done (%s)" % str(s.marks), s.is_done() and int(tally.get("done", 0)) == 1 and s.marks == [30, 97] and s.serves == 2 and int(s.verdict.tier) == 2)
_check("tiers: 79 served, 80 great, 94 great, 95 perfect", Sim.tier(79) == 0 and Sim.tier(80) == 1 and Sim.tier(94) == 1 and Sim.tier(95) == 2)
var back = _day(0, 7)
back.finish([30, 97])
_check("a finished day put back keeps a 30 and passes", back.is_done() and back.marks == [30, 97] and bool(back.verdict["pass"]) and int(back.verdict.tier) == 2)
# the landing
var l = _day(0, 7)
l.aim(l.centre_of(0)); l.squeeze(true)
var lands := 0
for i in 240:
	l.step()
	for ev in l.events: if ev.type == "land": lands += 1
	l.events.clear()
_check("a chunk held to the card's shade lands once (%d)" % lands, lands == 1)
l.squeeze(false); l.drain(true)
for i in 60: l.step()
l.drain(false); l.squeeze(true)
for i in 240:
	l.step()
	for ev in l.events: if ev.type == "land": lands += 1
	l.events.clear()
_check("drained under the re-arm and poured again, it lands again (%d)" % lands, lands == 2)
var p = _day(0, 7)
p.filled(0, int(p.mould.want[0]), 1.2); p.step()
_check("a prefilled cell never lands", not p.events.any(func(e): return e.type == "land"))
```

`_wet_all(s)` is a new helper: for each cell `c`, `s.aim(s.centre_of(c)); s.squeeze(true); for i in 6: s.step(); s.squeeze(false)`. Rewrite `_insane` the same way: no flops, five moulds at 0.3 served are the day done in five serves, `Reset is the day from its first mould` kept. In `_days`, drop the `s.mark() == int(spec.mark)` clause and the "at %d%%" of its message. `_serve_as` must call `_wet_all` first or the serve is refused: add it inside `_serve_as`.

- [ ] **Step 2: Run the probe to see it fail**

Run: `godot --headless --script tests/_probe_gumdrop.gd 2>&1 | tail -20`
Expected: parse errors on `Sim.tier` / `tier` key, or FAIL lines on the new checks.

- [ ] **Step 3: Change the sim**

In `puzzles/gumdrop_sim.gd`: delete `MARK`, `need`, `mark()`; `set_day(list)`; `_init` calls `set_day([m])`; add the consts and `tier()`; `can_serve()` is `phase == PLAY and all_wet()`; `all_wet()` walks `tank`; `landed` sized in `_lay()` (zeroed) and zeroed by `empty()`; in `step()`'s squeeze branch, after `_tally`, if `landed[c] == 0 and tank[c] >= LAND * C_FULL`: set it and append `{"type": "land", "cell": c}`; in the drain branch and in `learn()`, if `tank[c] < LAND_REARM * C_FULL`: `landed[c] = 0`. `filled()` (the prefill) sets `landed[c] = 1` so it never lands. `judge()` builds `verdict = {"pct", "tier": tier(pct), "pass": true, "perfect": pct >= TIER_PERFECT}` and the `served` event the same keys. `_after()` always advances. `finish()` builds the same verdict shape. `SETTLE_T`, `SHOW_T`, `RATE` as the Interfaces say. Update the head comment's rules (no mark; every piece coloured to serve).

- [ ] **Step 4: Fix the three callers**

`ui/hud/gumdrop_tutorial_diagram.gd:51` → `set_day([m])`. `puzzles/gumdrop2d.gd`: `rules()` formats `GD_RULES` with `[sim.moulds.size()]` only (Task 5 rewrites the row to one `%d`); the day dict's `payload` and `metrics` lose `"mark"` and gain `"tiers": [Sim.TIER_GREAT, Sim.TIER_PERFECT]`; the MATCH page's body gets no `%` argument (Task 5 rewrites the row). Check `tools/export_days.gd` and `docs/agents/days-dashboard.md` for a reader of `mark` (`grep -rn '"mark"' tools/ server/ docs/agents/days-dashboard.md`); if one exists, leave `"mark": 0` in the payload and say so in the commit.

- [ ] **Step 5: Run the probe and the parse checks**

Run: `godot --headless --script tests/_probe_gumdrop.gd 2>&1 | grep -c FAIL; godot --headless --check-only --script puzzles/gumdrop2d.gd; godot --headless --check-only --script ui/hud/gumdrop_tutorial_diagram.gd`
Expected: `0` failures; both checks silent. (The probe's five old Insane-serves checks that failed before are gone with the rewrite.)

- [ ] **Step 6: Commit**

```bash
git add puzzles/gumdrop_sim.gd tests/_probe_gumdrop.gd ui/hud/gumdrop_tutorial_diagram.gd puzzles/gumdrop2d.gd
git commit -m "feat(gumdrop): serve never fails -- tiers in place of the mark, every piece coloured to serve, a chunk lands at 100% (the user, 2026-10-26: nobody likes it; spec 2026-10-26-gumdrop-fun)"
```

### Task 2: The table: the all-wet serve button, the tiers' showing, the card's line

**Files:**
- Modify: `puzzles/gumdrop_table.gd` (`_press` 571-615 the serve branch, `_on_served` 694-716, `_refresh_hud` 723-744)
- Modify: `ui/hud/gumdrop_tutorial_diagram.gd` (the MATCH and MIX rounds' plans: every cell wet before "serve")
- Modify: `locale/ui.csv` (new rows `GD_GREAT`, `GD_OF`; `GD_NEED`, `GD_NEEDED` deleted)

**Interfaces:**
- Consumes: Task 1's verdict `{"pct", "tier", "pass", "perfect"}`, `sim.can_serve()`, `Sim.tier()`.
- Produces: `GD_GREAT` ("Great!", "Ótimo!", "¡Genial!"), `GD_OF` ("%d OF %d", "%d DE %d", "%d DE %d"); the serve button drawn at 0.45 alpha unless `sim.can_serve()` (already so: it reads `can`).

- [ ] **Step 1: The serve branch of `_press`**

When `not sim.can_serve()`: `_fx.cue("nope")` (Task 5 adds the cue; until then it logs a missing cue, which `Fx2D.cue` tolerates: check `ui/fx2d.gd:229` and if it does not, use `_fx.touch(0.9)` until Task 5 lands) and `_fx.buzz(Haptics.WARN)`; delete the `GD_NOTHING_YET` sticker. Keep `_serve_down`.

- [ ] **Step 2: `_on_served` by tier**

Three branches on `int(ev.tier)`: 2 as today's perfect branch (gold number: `Pal.SUN` or the palette's gold, check `core/palette.gd`); 1 the `good` cue at today's climb, `Haptics.GOOD`, the number in `Pal.LEAF_DEEP`, word `GD_GREAT`; 0 the `good` cue at pitch 0.84, `Haptics.BUMP`, the number in `Art.INK`-on-white as today's pass branch, word `GD_GOOD`. `_wobble` values stay (Task 3 moves the wobble onto the jelly). No `flop`, no `GD_NEEDED`.

- [ ] **Step 3: `_refresh_hud`**

`_need_l.text` is `tr("GD_OF") % [sim.index + 1, sim.moulds.size()]` when `moulds.size() > 1`, else `""`; once served (`pct >= 0`) it is the tier's word (`GD_PERFECT`/`GD_GREAT`/`GD_GOOD`) upper-cased. `_match_l`'s colour: gold at tier 2, `Pal.LEAF_DEEP` at 1, `Art.INK` at 0.

- [ ] **Step 4: The bench's rounds**

In `ui/hud/gumdrop_tutorial_diagram.gd`, find each plan that ends in `"serve"` (around line 240) and make sure every cell of the round's mould is prefilled or squeezed before it; where a round shows "one half as the card has it, the other topped up", both halves are already wet. Run `godot --headless --check-only --script ui/hud/gumdrop_tutorial_diagram.gd`.

- [ ] **Step 5: Locale rows and import**

Add `GD_GREAT` and `GD_OF` to `locale/ui.csv` beside `GD_GOOD`; delete `GD_NEED` and `GD_NEEDED`. Run `godot --headless --path . --import 2>&1 | tail -2`.

- [ ] **Step 6: Parse and a throwaway serve check**

Run: `godot --headless --check-only --script puzzles/gumdrop_table.gd`. Then a throwaway headless script in the scratchpad that instantiates the table with a Medium day, calls `_press` on `_serve_at` with one chunk wet and asserts `sim.serves == 0`, then wets all and asserts `sim.serves == 1` after `_press`. Delete the script after.
Expected: both as asserted.

- [ ] **Step 7: Commit**

```bash
git add puzzles/gumdrop_table.gd ui/hud/gumdrop_tutorial_diagram.gd locale/ui.csv
git commit -m "feat(gumdrop): the serve button waits for every piece, the stamp is a tier, the card counts moulds (spec 2026-10-26-gumdrop-fun 4.4, 4.5)"
```

### Task 3: The jelly wobbles

**Files:**
- Modify: `puzzles/gumdrop_table.gd` (`_group` 355-373, `_draw_field` 757-768, `_draw_syrup` 770-774, `_draw_top` 776-780, `_press` 571-615, `_animate` 484-521, `_on_served` 694)

**Interfaces:**
- Produces: `func _jelly() -> Transform2D` (the jelly's own transform inside `_group()`: squash `(1 + w, 1 - w)` and skew `0.5 w` about the mould's centre `_tray.size * 0.5`, where `w = _wob_a * sin(TAU * WOB_F * t) * exp(-t / WOB_TAU) + _tremble`); `func wobble(a: float) -> void` (restarts the decay at amplitude `a` if `a > _wob_a * exp(-t/τ)`, else leaves it); consts `WOB_F := 4.5`, `WOB_TAU := 0.35`, `WOB_TAP := 0.02`, `WOB_SQUEEZE := 0.03`, `WOB_DRAIN := 0.02`, `WOB_LAND := 0.04`, `WOB_SERVE := 0.09`, `TREMBLE := 0.006`, `TREMBLE_F := 9.0`; vars `_wob_a`, `_wob_at`, `_tremble`.
- `_group()` loses its `_wobble` shake (the tray no longer shakes); `_wobble` var and its three assignments in `_on_served` go; `_on_served` calls `wobble(WOB_SERVE)`.

- [ ] **Step 1: Draw the jelly under `_jelly()`**

In `_draw_field`: the tray slab under `_group()` as today; `_floor` under `_group() * _jelly()`. In `_draw_syrup`: `draw_set_transform_matrix(_group() * _jelly())`. In `_draw_top`: `_walls` under `_group() * _jelly()`. Everything else unchanged. Under `Motion.reduce`, `_jelly()` returns `Transform2D.IDENTITY`.

- [ ] **Step 2: Set it off**

`_press`: the tray branch `wobble(WOB_TAP)`; the squeeze branch `wobble(WOB_SQUEEZE)`; the drain branch `wobble(WOB_DRAIN)`. `_animate`: `_tremble = TREMBLE * sin(TAU * TREMBLE_F * _clock)` while `sim.squeezing and sim.tip_cell() >= 0`, eased to 0 at 16/s otherwise.

- [ ] **Step 3: Parse check and one shot**

Run: `godot --headless --check-only --script puzzles/gumdrop_table.gd`, then one windowed run `tests/_shot_gumdrop.gd -- <scratch> 1` (under caffeinate, `opengl3_angle`, `ulimit -f`, `timeout 240`). Read the squeeze and the served shots: the jelly's rim must still sit inside the tray, the card and buttons unmoved; draw calls within 115-122.
Expected: the shots as described; the run's `solved: ... won true` line.

- [ ] **Step 4: Commit**

```bash
git add puzzles/gumdrop_table.gd
git commit -m "feat(gumdrop): the jelly wobbles -- a squash with a little shear under its own transform on a touch, a squeeze, a drain and the serve; the tray stays still (spec 2026-10-26-gumdrop-fun 4.2)"
```

### Task 4: A chunk lands, and the pour is quick

**Files:**
- Modify: `puzzles/gumdrop_fluid.gd:60` (`RATE := 8.0`)
- Modify: `puzzles/gumdrop_table.gd` (`_animate` 484-521 the meter block, `_play_events` 648-668, `_draw_meter` 833-856, `METER_EASE` 81)

**Interfaces:**
- Consumes: Task 1's `land` event (headless) and `Sim.LAND`, `Sim.LAND_REARM`; Task 3's `wobble(WOB_LAND)`; `Fx2D.sparkle(at, colour)` (`ui/fx2d.gd:174`) and `_fx.cue("land", pitch)` (Task 5's cue; until it lands the cue is missing: see Task 2 step 1's note).
- Produces: on screen, the table's own landing: in `_animate`'s meter block, when `sim.squeezing` and the eased `_level`'s sum first reaches `Sim.LAND * Sim.C_FULL` for `cell` with `sim.landed[cell] == 0`, the table sets `sim.landed[cell] = 1` and calls `_land(cell)`; `func _land(cell: int) -> void` does the cue, `_fx.buzz(Haptics.BUMP)`, `_fx.sparkle(_rw.at(field, px(sim.tip)), Mould.colour_of_want?)` (use `Sim.colour(...)` of the chunk's current pigments, or the picked pot's `Sim.FLAVOURS[flavour]`), `wobble(WOB_LAND)`, and sets `_land_at = _clock`; `_draw_meter` draws the rim white and the number in `Pal.LEAF_DEEP` for 0.35 s after `_land_at`. Headless the sim's `land` event calls `_land` from `_play_events` (`"land": _land(int(ev.cell))`), so a windowed run gets it from the meter and never twice (the sim's own tally lags the meter: guard with `sim.landed`). `METER_EASE := 20.0`.

- [ ] **Step 1: The rate**

`puzzles/gumdrop_fluid.gd`: `RATE := 8.0`, the comment saying 2026-10-26 "about 1.2 s to the card's shade at 92 squares". `DRAIN` stays 1.0.

- [ ] **Step 2: The landing on the table**

As the Interfaces say. The sparkle's colour: `Sim.FLAVOURS[int(sim.pots[sim.picked].flavour)]`.

- [ ] **Step 3: Parse check and the pour shot**

Run: `godot --headless --check-only --script puzzles/gumdrop_table.gd`; then one windowed `tests/_shot_gumdrop.gd -- <scratch> 1 pour` and read the printed meter numbers at 0.5, 1, 1.5 s.
Expected: the stalk's shown number about 45, 85, 100 by 1.5 s (within ±15); the console shows one `land` (add a `print("land cell %d at %.2f" % ...)` in `_land` for the harness; keep it, the harness prints such lines).

- [ ] **Step 4: Commit**

```bash
git add puzzles/gumdrop_fluid.gd puzzles/gumdrop_table.gd
git commit -m "feat(gumdrop): the pour is quick and a chunk lands -- RATE 8.0 (about 1.2 s to the card's shade), the ring snaps, a pop, a haptic, sparkles and a wobble once a fill (spec 2026-10-26-gumdrop-fun 4.1, 4.3)"
```

### Task 5: Sounds and words

**Files:**
- Modify: `tools/gen_sfx.py` (the `"gumdrop"` set, 3949-3972)
- Modify: `puzzles/gumdrop_table.gd` (`_press` the pot branch: `_fx.cue("pick", ...)` in place of `_fx.touch`)
- Modify: `locale/boards.csv:2698-2700` (`GD_RULES`, `GD_RULES_MIX` unchanged, `GD_BLURB`), `locale/ui.csv` (`TUT_GUMDROP_MATCH_BODY`, `TUT_GUMDROP_HUD_BODY`)
- Generated: `assets/sfx/gumdrop/{pick,land,nope}.ogg`

**Interfaces:**
- Produces: cues `pick` (`bank:pebble`, -16, `cut:0.14`, `tight`), `land` (`bank:wrap`, -14, `cut:0.1`, `notes:0.07:0,4`, `tight`), `nope` (`bank:tongue`, -16, `cut:0.12`, `tight`); `flop`, `game_over`, `new_best` rows deleted from the set (and their ogg files removed with `git rm`).

- [ ] **Step 1: The rows**

Add the three rows to the `"gumdrop"` set with a comment each (what moment, 2026-10-26); delete the three dead rows. Update the set's head comment: the pots pick with the pebble, a landing with the wrap, a refused serve with the tongue.

- [ ] **Step 2: Generate the set**

Run: `python3 tools/gen_sfx.py --help | head -20` to learn the set flag, then the gumdrop set only (bank rows copy the take; no API call is needed for them; if the script insists on a key for the set's non-bank rows that already exist, pass the flag that regenerates only missing cues, which `--help` names). Then `git rm assets/sfx/gumdrop/{flop,game_over,new_best}.ogg*` and `godot --headless --path . --import 2>&1 | tail -2`.
Expected: `assets/sfx/gumdrop/pick.ogg`, `land.ogg`, `nope.ogg` exist with `.import` files; `git status` shows no other set touched.

- [ ] **Step 3: The pot's cue**

`_press`'s pot branch: `_fx.cue("pick", randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))` in place of `_fx.touch(...)`; the `buzz` stays.

- [ ] **Step 4: The words**

`GD_RULES` (one `%d`, the moulds): "Colour the clear jelly to match the card. Slide over the tray to move the needle, touch a pot for its flavour and hold the pink button to squeeze: the colour spreads through its piece and stops at the card's shade. The grey button draws it back out. Serve it when every piece has colour: the nearer the card, the better the stamp, and 95%% is Perfect. Today: %d moulds." with pt and es. `GD_BLURB` unchanged unless it names the mark. `TUT_GUMDROP_MATCH_BODY` (no `%`): "The card shows the jelly as it is wanted. How near yours is stays hidden until the gold button serves it: then its number is told and stamped. Every piece needs some colour before it can be served; 95% and over is Perfect." `TUT_GUMDROP_HUD_BODY`: delete any mention of a mark or "needed". Then `godot --headless --path . --import`.

- [ ] **Step 5: Parse and a tutor shot**

Run: `godot --headless --check-only --script puzzles/gumdrop_table.gd`; one windowed `tests/_shot_gumdrop.gd -- <scratch> 1 tutor` and read the MATCH page shot: no "%d" or key name visible, the sentence as written.

- [ ] **Step 6: Commit**

```bash
git add tools/gen_sfx.py assets/sfx/gumdrop locale/boards.csv locale/ui.csv puzzles/gumdrop_table.gd
git commit -m "feat(gumdrop): the house sound -- a pebble picks a pot, a wrap lands a chunk, the tongue refuses a serve; flop and game_over gone; the rules and the match page without the mark (spec 2026-10-26-gumdrop-fun 4.6, 4.7)"
```

### Task 6: The reveal, the harness, the measure

**Files:**
- Modify: `puzzles/gumdrop_table.gd` (`_draw_syrup` 770-774, `_on_served`, a new `_draw_sweep()`; `Art` may gain `static func sweep(w: float, h: float) -> ArrayMesh` in `puzzles/gumdrop_art.gd`)
- Modify: `tests/_shot_gumdrop.gd` (the flop path 295-312: it serves a nearly clear mould, which is now refused)
- Modify: `docs/agents/boards/gumdrop.md` (a new dated section), `docs/agents/sound.md` (the gumdrop rows), `docs/agents/haptics.md` row 55

**Interfaces:**
- Consumes: Task 3's `_jelly()`, Task 2's tiers, `Motion.reduce`.
- Produces: `_sweep_at` (the serve's clock), `SWEEP_T := 0.5`, `SWEEP_DELAY := 0.1`; the sweep mesh (one soft white band: a quad with alpha 0 at both long edges and `SWEEP_A` 0.35 along its middle, `SWEEP_W` 0.28 of the tray's width wide, as long as the tray's diagonal, built once per `_u` in `_meshes()`), drawn in `_draw_syrup` after the dye quad, under `_group() * _jelly() * Transform2D(-PI/4, pos)` where `pos` runs from the lower-left corner to the upper-right over `SWEEP_T`, modulated by a fade in-and-out; the seams (`_walls`, in `_top`) draw over it. Nothing drawn when `Motion.reduce` or outside the window.
- The harness: its "flop" step now wets only one chunk and presses serve, asserting `serves == 0` and printing `refused: serves 0`; then it wets all chunks sparingly (a short squeeze in each, via the bot's path) and serves, printing the tier; the shot names stay (`3_flop` → `3_refused`, `4_again` → `4_served_low`). It then plays on as before. A new mode `reveal` shoots 0.3 s after the serve. `reduce` still runs.

- [ ] **Step 1: The sweep**

As the Interfaces say. The mesh in `Art` through `Face.Builder` or the existing quad helpers in `gumdrop_art.gd` (follow its own style; check how `Art.card` builds a soft shape).

- [ ] **Step 2: The harness**

Rewrite the flop path and add `reveal`; keep the bot. Update the file's head comment.

- [ ] **Step 3: Parse, then the runs**

Run: `godot --headless --check-only --script puzzles/gumdrop_table.gd; godot --headless --check-only --script tests/_shot_gumdrop.gd`. Then, one at a time under caffeinate/ulimit/timeout on `opengl3_angle` at 810x1440: `-- <scratch> 1`, `-- <scratch> 2 reveal`, `-- <scratch> 1 reduce`. Read the reveal shot (the band of light across the jelly, seams over it), the win shot, the refused step's line, and every `draws=` figure. Run `-- <scratch> 1` a second time and quote the second run's draw calls.
Expected: `refused: serves 0`; the day solved; draw calls in play ≤ 125 and the reveal frame ≤ 127; under `reduce` the day solves and no sweep is drawn.

- [ ] **Step 4: The suite's guard and the win check**

Run: `godot --headless --script tests/_win.gd -- gumdrop 2>&1 | tail -3` (needs a display per memory: run windowed if it reports 0/0) and the suite's parse guard (`docs/agents/ci.md` names the command; `grep -n "parse guard" docs/agents/ci.md`).
Expected: `PASS`; the guard green.

- [ ] **Step 5: The notes**

`docs/agents/boards/gumdrop.md`: a section "### Made fun to play (2026-10-26)" in the file's voice: the user's words, the diagnosis (the three points of the spec's section 1), each part with its constants, what was measured (the draw calls, the hold to 100%, the refused serve), what is unconfirmed (the user's eye, a phone, the sounds heard, pt and es) and the calls left (the spec's section 7). `docs/agents/sound.md`: the gumdrop rows for `pick`, `land`, `nope`, the three gone. `docs/agents/haptics.md` row 55: the landing (BUMP), the refused serve (WARN). CLAUDE.md's boards table needs nothing new.

- [ ] **Step 6: Commit**

```bash
git add puzzles/gumdrop_table.gd puzzles/gumdrop_art.gd tests/_shot_gumdrop.gd docs/agents/boards/gumdrop.md docs/agents/sound.md docs/agents/haptics.md
git commit -m "feat(gumdrop): the serve is a reveal -- a sweep of light over the jelly under the seams, the harness serves a refused then a low mould; measured on opengl3_angle (spec 2026-10-26-gumdrop-fun 4.4)"
```
