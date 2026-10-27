# Peeplet Brand, the app: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The first screen's header wears the icon's DAILY / PUZZLES tiles over the day's own painting, the sprout face is gone from the game and the day's Peeplet pair sits where it was, the difficulty sheet asks again on a card, and the app is named Peeplet: Daily Puzzles.

**Architecture:** One new drawn control, `ui/menu/word_tiles.gd`, draws a word as Hidden Word's pieces with Mosaic letters as one mesh; the header and the opening both use it. The day's pair is one static helper, `core/cast.gd`, that every seat reads. Every Peeplet on a screen is a `ui/peeplet_view.gd`. The difficulty sheet comes back as it was before commit 93105bbd.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility; the suite `godot --headless --path . --script tests/run_tests.gd`; harness `tests/_shot_menu.gd` at `--resolution 810x1440 --always-on-top --rendering-driver opengl3_angle`.

**Spec:** `docs/superpowers/specs/2026-10-27-peeplet-brand-design.md` (Parts B and A, "The difficulty sheet comes back"). The companion plan `2026-10-27-peeplet-brand-night.md` builds Part C; Task 3 here reads the `cast` field that plan publishes.

## Global Constraints

- Budget 855 draw calls; a drawing is one `ArrayMesh` issued as one `draw_mesh`, kept until the next replaces it.
- No `instance uniform`; check on `--rendering-driver opengl3_angle`.
- Harnesses one at a time, `--resolution 810x1440` before `--script`, `--always-on-top`, under `caffeinate -d -i -u`, two readings, quote the second. Run Godot under `ulimit -f 200000` and `timeout`.
- The Peeplet is never hand-drawn or baked to an image on a screen: always `ui/peeplet_view.gd`.
- Renamed genres: never the original game's name anywhere.
- Text goes through `locale/ui.csv`; titles stay English.
- Honour `Motion.reduce`; a held PeepletView honours `set_idle` (core/power.gd picks it up).
- `godot --headless --check-only --script <file>` on every edited script before a harness.
- Commit locally after each task; never push.
- Before task 1, commit any stray uncommitted work as its own commit (the user's preference).

## Review Focus

1. A card tapped twice fast opens two hosts: `_open` keeps its `_swiped` guard and the sheet's `close_then` is the only path to `_open_at` (Task 5 test).
2. A themed day whose vistas arrive after the menu is built: the header changes in place through the `themed_vistas` group (Task 2 test).
3. A persona index past the list (a cast published after the list shrank, or a corrupted doc): `Cast.pair` clamps and never indexes out of range (Task 3 test).
4. A PeepletView left redrawing on a hidden sheet: Streak's and the remove-ads sheet's views hold `idle_fps 0` and are freed with the sheet (Task 4 check in the harness: draw calls equal before and after opening and closing the sheet).
5. The save folder on this Mac after the rename: `user://` still resolves to `Peeplet Daily` (Task 7 verification).

---

### Task 1: The word tiles control

**Files:**
- Create: `ui/menu/word_tiles.gd`
- Create: `tests/test_word_tiles.gd`
- Reference: `ui/menu/cards/hiddenword.gd:174-184` (`_piece`), `ui/faces/mosaic_tile.gd:173` (`Mosaic.letter`), `puzzles/hidden_word2d.gd:101-103, 1495` (RADIUS, BEVEL, EDGE_MIX, RIM_LIGHT), `ui/opening.gd:56` (TILES colours), `tests/test_hidden_word.gd` (how a suite test is shaped), `tests/run_tests.gd` (how tests are listed).

**Interfaces:**
- Produces: `class_name WordTiles extends Control` with
  - `const ROWS := ["DAILY", "PUZZLES"]`
  - `const COLOURS := {"DAILY": [PAPER, BUTTER, PAPER, LEAF, PAPER], "PUZZLES": [SKY, PAPER, BUTTER, CORAL, SKY, PAPER, LEAF]}` where the five colours are `Pal.PAPER`, `Pal.SUN_TILE`, `Pal.LEAF`, the opening's `BLUE` and `CORAL` (copy their values from `ui/opening.gd` into `const` here; the opening then reads them from WordTiles).
  - `const TILT := [-3.0, 2.0, -1.0, 3.0, -2.0, 2.0, -2.0, 1.0, -3.0, 2.0, -1.0, 3.0]` degrees, one a tile in reading order.
  - `@export var tile := 60.0` (px, a tile's side at 1080 design width), `@export var gap := 0.12` (of a tile), `@export var indent := 0.45` (the second row's left shift, in tiles).
  - `var shown := 12` (tiles drawn, in reading order: the opening lays them one at a time by setting this; 12 draws all).
  - `func tile_rect(i: int) -> Rect2` (local rect of tile i, before tilt).
  - `func total_size() -> Vector2`.
  - The drawing: one `ArrayMesh` of the tiles (`_piece` as hiddenword.gd cuts it, each under its own `Transform2D` rotation about the tile's centre), built on `_build()` and kept, drawn with one `draw_mesh`; the letters over it with `Mosaic.letter` (12 draw commands, as the Hidden Word card does). `shown` only changes which tiles are issued, not the mesh.

- [ ] **Step 1: Write the failing test** in `tests/test_word_tiles.gd`, registered in `tests/run_tests.gd` the way the others are:

```gdscript
func test_layout():
	var w := WordTiles.new()
	w.tile = 60.0
	assert_eq(w.tile_rect(0).position, Vector2.ZERO)
	assert_eq(w.tile_rect(1).position.x, 60.0 * 1.12)
	assert_eq(w.tile_rect(5).position.y, 60.0 * 1.12)          # P, first of row two
	assert_eq(w.tile_rect(5).position.x, 60.0 * 0.45)          # the indent
	assert_eq(w.total_size(), Vector2(60.0 * (7 * 1.12 - 0.12 + 0.45), 60.0 * (2 * 1.12 - 0.12)))
	assert_eq(WordTiles.ROWS.size(), 2)
	assert_eq(WordTiles.COLOURS["PUZZLES"].size(), 7)
```

- [ ] **Step 2: Run it and see it fail**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | grep -A3 word_tiles`
Expected: a parse failure naming `WordTiles`.

- [ ] **Step 3: Implement `ui/menu/word_tiles.gd`** as the Interfaces block says. The piece cut is `hiddenword.gd`'s `_piece` moved here as `static func piece(b, at, s, fill, deep, rim)`; hiddenword.gd calls `WordTiles.piece` and loses its own copy (same component, one code). `deep = fill.lerp(Pal.TEXT, Board.EDGE_MIX)`, `rim = fill.lerp(Pal.SURFACE, Board.RIM_LIGHT)`. Letters are ink (`Pal.TEXT`) on paper tiles and `Pal.SURFACE` on coloured ones.

- [ ] **Step 4: Parse and test**

Run: `godot --headless --check-only --script ui/menu/word_tiles.gd && godot --headless --check-only --script ui/menu/cards/hiddenword.gd && godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`
Expected: the suite's pass count up by one, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add ui/menu/word_tiles.gd tests/test_word_tiles.gd tests/run_tests.gd ui/menu/cards/hiddenword.gd
git commit -m "feat(menu): WordTiles, the icon's DAILY / PUZZLES tiles as one drawn control"
```

---

### Task 2: The header: tiles, no faces, the day's painting behind

**Files:**
- Modify: `ui/menu/menu_header.gd` (TITLE, the title block 167-189, the pair 190-230, `enter` 308-347, the constants 60-98)
- Modify: `ui/menu/vistas.gd:324-330` (`header_plate`)
- Modify: `ui/menu.gd:449` (the backdrop), and the `themed_vistas` group join
- Modify: `tests/_shot_menu.gd` (no change to flags; used to measure)
- Modify: `docs/agents/first-screen.md` (append the history)

**Interfaces:**
- Consumes: `WordTiles` (Task 1); `ThemedVistas.texture(time: String) -> Texture2D` and `ThemedVistas.GROUP`; `Vistas.point_at(plate, vista_or_texture, zoom, focus, tint)` (it already takes a texture, spec 2026-10-17).
- Produces: `MenuHeader.vistas_arrived()` (called through the group like `day_row.gd:141`); `Vistas.header_plate() -> ColorRect` unchanged in signature but pointing at the themed dusk when there is one; `Vistas.set_header_vista(plate: ColorRect) -> void` (re-points an existing plate: themed dusk if `ThemedVistas.texture("dusk") != null`, else `HEADER` as today).

- [ ] **Step 1: Header without faces.** In `menu_header.gd` delete `SunFace`, `MoonFace`, `_sun`, `_moon`, `_sun_seat`, `_moon_seat`, `_face_seat`, `_place_pair`, `_sprig`, `_draw_sprig`, `_sprig_progress`, `SPRIG_*`, `SUN_*`, `MOON_*`, `FACE_RISE`, `PAIR_*`; delete the Label `_title` and `_sun_dot`; `TITLE` goes. The title block holds a `WordTiles` named "Tiles" (tile 60.0) and the motto under it. `refresh_motion` and `set_idle` paths that touched the faces now touch nothing.

- [ ] **Step 2: The entrance.** `enter(delay, fade)`: the tiles' `shown` goes 0 to 12 one every 0.085 s from `delay + TITLE_AT` (a tween on `shown` with `TRANS_LINEAR`, stepped by `int`), the block lifts into place as today (`TITLE_LIFT`, `TITLE_TIME`), the motto fades at `MOTTO_AT`, the buttons scale in as today. Under `Motion.reduce` everything stands finished.

- [ ] **Step 3: The day's painting.** In `vistas.gd` add `static func set_header_vista(plate: ColorRect) -> void` (themed dusk first, as `set_day_vista` prefers the themed afternoon at `THEMED_DAY`; same zoom `HEADER[1]` and focus `HEADER[2]`, tint `Pal.ACCENT`); `header_plate()` calls it. In `menu.gd`, after `_backdrop = Vistas.header_plate()`, add the backdrop to `ThemedVistas.GROUP`, and give the menu (or a small handler on the plate) a `vistas_arrived()` that calls `Vistas.set_header_vista(_backdrop)`. Follow how `world/main.gd` tells the group (grep `ThemedVistas.GROUP` in `world/main.gd`).

- [ ] **Step 4: Parse and suite**

Run: `for f in ui/menu/menu_header.gd ui/menu/vistas.gd ui/menu.gd; do godot --headless --check-only --script $f || echo FAIL $f; done; godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`
Expected: no FAIL, suite 0 failures.

- [ ] **Step 5: Measure, twice, bundled and themed**

Run: `ulimit -f 200000; caffeinate -d -i -u timeout 120 godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_menu.gd` twice; then `tools/themed_play.sh 20261019 vistas` and the same run twice, then `tools/themed_play.sh off`.
Expected: `max_draw_calls` under the previous reading (the sun, moon and sprig were draws; the tiles are one mesh plus twelve letters), a screenshot at `/tmp/shot_menu_1.png` showing the tiles over the dusk, and over the trial day's dusk painting on the themed run. Look at both PNGs.

- [ ] **Step 6: Docs and commit.** Append to `docs/agents/first-screen.md` under a "The tiles wordmark and the day's painting (2026-10-27)" heading: the user's words from the spec, the readings, and that the sun and moon faces now live only where they are pieces.

```bash
git add ui/menu/menu_header.gd ui/menu/vistas.gd ui/menu.gd docs/agents/first-screen.md
git commit -m "feat(menu): the header wears the DAILY / PUZZLES tiles over the day's own dusk; the sun, the moon and the sprig go"
```

---

### Task 3: The day's pair

**Files:**
- Create: `core/cast.gd`
- Create: `tests/test_cast.gd`
- Modify: `core/themed_vistas.gd` (keep the `cast` field of the day's document)
- Reference: `peeplet/peeplet_personas.gd` (`ALL`, `count()`, `get_persona(i)`), `core/daily.gd:47` (`fnv1a`), `core/daily.gd:20` (`date_key`).

**Interfaces:**
- Consumes: `ThemedVistas` static store; the night plan's `Vistas.cast: [number, number]` in `days/{day}/turns/vistas`.
- Produces: `class_name Cast` with
  - `static func pair(day: int = Daily.date_key()) -> Array[int]`: the published cast when `ThemedVistas.cast()` has two ints, each clamped to `0..PeepletPersonas.count()-1`; else the seeded pair.
  - `static func seeded(day: int) -> Array[int]`: `a = fnv1a("cast-a-" + str(day)) % n`, `b = fnv1a("cast-b-" + str(day)) % n`, and if `b == a` then `b = (a + 1) % n`, over the eligible personas only (below).
  - `static func eligible() -> Array[int]`: persona indices whose coat is one of `PeepletPalette.BODY` 0..7 (the flat coats) and whose hat is in `PLAIN_HATS := ["", "bandana", "beanie", "bow", "cap", "chefHat", "earmuffs", "sunhat", "topHat", "partyHat", "mushroomCap", "flowerCrown"]`.
  - `static func persona(which: int, day: int = Daily.date_key()) -> Dictionary`: `PeepletPersonas.get_persona(pair(day)[which])`.
  - `static func dress(view, which: int, day: int = Daily.date_key()) -> void`: sets `view.color_index`, `view.headgear`, `view.eyewear` from the persona.
- `ThemedVistas.cast() -> Array` returns the document's `cast` or `[]`.

- [ ] **Step 1: Write the failing test** `tests/test_cast.gd`:

```gdscript
func test_seeded_pair_is_two_distinct_eligible():
	var p := Cast.seeded(20261027)
	assert_eq(p.size(), 2)
	assert_true(p[0] != p[1])
	assert_true(p[0] in Cast.eligible() and p[1] in Cast.eligible())
	assert_eq(Cast.seeded(20261027), p)             # stable
	assert_true(Cast.seeded(20261028) != p)          # moves with the day
	# The vector the server must match (night plan, Task 2): print it once
	# and paste it here, then `node lib/cli.js cast 20261027` must print the same.
	print("cast vector 20261027 = ", p)

func test_published_cast_clamps():
	ThemedVistas.adopt({"v": 1, "theme": "t", "name": {"en": "T"}, "times": {}, "cast": [3, 99999]})
	var p := Cast.pair(Daily.date_key())
	assert_eq(p[0], 3)
	assert_eq(p[1], PeepletPersonas.count() - 1)
	ThemedVistas.reload()
```

(`adopt` with empty times leaves `_tex` empty; `cast()` must still read the field. If `_take` drops the doc on empty times, store `cast` before that check.)

- [ ] **Step 2: Run, see it fail** (`Cast` unknown).

- [ ] **Step 3: Implement `core/cast.gd` and `ThemedVistas.cast()`** per Interfaces. The same seed rule is written in the night plan's `cast.ts` (Task 2 there); the strings `"cast-a-"`/`"cast-b-"` and the eligibility rule are the contract.

- [ ] **Step 4: Parse and test**; expected two new passes, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/cast.gd tests/test_cast.gd tests/run_tests.gd core/themed_vistas.gd
git commit -m "feat(cast): the day's pair of Peeplets, seeded by the day or published with the vistas"
```

---

### Task 4: Every sprout seat becomes a Peeplet; the sprout face goes

**Files:**
- Delete: `ui/faces/sprout_face.gd` (and its `.uid`)
- Modify: `ui/menu/cards/hiddenword.gd:19, 50-54, 229-234` (the sprout on the tump)
- Modify: `puzzles/hidden_word2d.gd:65, 406-410, 694-697, 949, 1838-1900` (`_sprout`, `_raise_sprout`, `_ride_sprout`)
- Modify: `ui/menu/card_art.gd:323` (Word Trail: no character)
- Modify: `ui/menu/streak_tab.gd:103-110`
- Modify: `ui/hud/remove_ads_sheet.gd:110-116`
- Modify: `docs/agents/boards/hidden_word.md`, `docs/agents/first-screen.md` (Streak), `docs/agents/ads-and-purchase.md` (the sheet)
- Reference: `ui/menu/cards/pie.gd:69-84` (two held PeepletViews on a card: `frame_height 1.0`, `aim_y 0.46`, `idle_fps 0.0`), `puzzles/pie2d.gd:511-557` (`_seat_cast`, `_breathe`, `_laugh`), `ui/peeplet_view.gd` (`walker`, `set_idle`).

**Interfaces:**
- Consumes: `Cast.dress(view, which)`, `PeepletView` (`color_index`, `headgear`, `eyewear`, `frame_height`, `aim_y`, `idle_fps`, `walker.trigger_laugh()`, `walker.sit`/grieve as pie2d.gd uses them).
- Produces: nothing other tasks use.

- [ ] **Step 1: Hidden Word card.** Replace the `SproutFace` on the tump with a `PeepletView` dressed as `Cast.persona(0)`, `idle_fps 0.0`, framed as Pie's card, sized to the old `SPROUT` box. The card doc comment's "the sprout waits on a tump" becomes the Peeplet.

- [ ] **Step 2: Hidden Word board.** `_sprout: Control` becomes a `PeepletView` built on the first reveal (same place, `_raise_sprout` renamed `_raise_peeplet`), dressed as `Cast.persona(0)`, `idle_fps 0.0`; on a win it `trigger_laugh()`s and on a loss it sits (as `pie2d.gd` and the walker API do); the old `hat`/`glasses` progress fields go (the persona wears its own). `_ride_sprout` keeps its motion, renamed.

- [ ] **Step 3: Word Trail card.** `card_art.gd:323`: drop the `_seat(SproutFace...)` line; the field stays.

- [ ] **Step 4: Streak Today card.** The `SproutFace` on the rock becomes a `PeepletView` dressed as `Cast.persona(0)`, sitting (`walker` sit as pie2d.gd seats), `idle_fps 0.0`, same box.

- [ ] **Step 5: Remove-ads sheet.** The `SproutFace` becomes a `PeepletView` dressed as `Cast.persona(1)`, standing, `idle_fps 0.0`, same box.

- [ ] **Step 6: Delete `ui/faces/sprout_face.gd`**; grep `SproutFace` across the repo and `docs/` and fix every reference (`tests/` included).

Run: `grep -rn "SproutFace\|sprout_face" --include=*.gd . ; for f in ui/menu/cards/hiddenword.gd puzzles/hidden_word2d.gd ui/menu/card_art.gd ui/menu/streak_tab.gd ui/hud/remove_ads_sheet.gd; do godot --headless --check-only --script $f || echo FAIL $f; done; godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`
Expected: no matches, no FAIL, 0 failures.

- [ ] **Step 7: Win harness and the menu**

Run: `ulimit -f 200000; caffeinate -d -i -u timeout 180 godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_win.gd -- hiddenword` (see the harness header for its args), then `_shot_menu.gd` with `streak` twice.
Expected: `_win hiddenword PASS`; the Peeplet visible in `/tmp` shots on the reveal and on Streak's Today card; the menu reading within budget.

- [ ] **Step 8: Docs and commit**

```bash
git add -A ui/faces ui/menu/cards/hiddenword.gd puzzles/hidden_word2d.gd ui/menu/card_art.gd ui/menu/streak_tab.gd ui/hud/remove_ads_sheet.gd docs/agents
git commit -m "feat(peeplet): the sprout face goes; the day's Peeplets take its seats on Hidden Word, Streak and the remove-ads sheet"
```

---

### Task 5: The difficulty sheet comes back

**Files:**
- Modify: `ui/menu.gd:43-51, 217-222, 359-376, 1573-1600` (reverse the `ui/menu.gd` hunk of 93105bbd: `DifficultySheet` preload, `difficulty_sheet` var, built and `chose.connect(_open_at)`, `_open` asks the sheet for `pick_difficulty` entries)
- Modify: `ui/menu/difficulty_sheet.gd:79-93, 94-165` (`ask` marks the row last played)
- Modify: `ui/registry.gd:153-160` (the Sudoku comment)
- Modify: `tests/_shot_menu.gd:96-100` (the `diff[=id]` shot back)
- Modify: `docs/agents/first-screen.md` ("The difficulty sheet retired" section gets its sequel)

**Interfaces:**
- Consumes: `Progress.last_level(id) -> int`, `DifficultySheet.ask(entry)`, `signal chose(entry, difficulty)`.
- Produces: `DifficultySheet._row(level, d, done, on_press, last: bool)`: when `last`, the go draws a ring in `Pal.ACCENT` round it (the Versus sheet passes `false`).

- [ ] **Step 1: Write the failing test** `tests/test_menu_open.gd` (a headless SceneTree test: build `ui/menu.gd` offline as `tests/_offline_main.gd` does, call `_open(Registry.find("sudoku"))`, assert `difficulty_sheet.visible` and no `FlatHost` child mounted; then `difficulty_sheet.chose.emit(entry, 2)` and assert one host mounted at difficulty 2 and `Progress.last_level("sudoku") == 2`). If building the menu headless is not possible (see `_offline_main.gd`), make it a windowed probe `tests/_probe_sheet.gd` that prints `PASS`/`FAIL` and record that choice in the commit message.

- [ ] **Step 2: Run, see it fail** (`difficulty_sheet` undefined).

- [ ] **Step 3: Restore the sheet** per Files; `_start_level` stays (the sheet's `ask` uses it to mark `last`), `_open_at` keeps saving `set_last_level`.

- [ ] **Step 4: Run the test**, then the suite; 0 failures.

- [ ] **Step 5: Measure** `_shot_menu.gd -- diff=sudoku` twice on opengl3_angle (sheet open), with and without the trial themed day adopted (`tools/themed_play.sh 20261019 vistas` / `off`).
Expected: within budget; the four rows show the four painted times on the themed run.

- [ ] **Step 6: Commit**

```bash
git add ui/menu.gd ui/menu/difficulty_sheet.gd ui/registry.gd tests/_shot_menu.gd tests/test_menu_open.gd tests/run_tests.gd docs/agents/first-screen.md
git commit -m "feat(menu): a puzzle card asks on the difficulty sheet again, the row last played ringed"
```

---

### Task 6: The opening lays the tiles

**Files:**
- Modify: `ui/opening.gd` (the 3x3 grid, `_draw_sprout`, `_draw_word`, `WORD`, `TILES`, `_tile_mesh`, `_stem_mesh`, `_leaf_mesh`, `_sun_mesh`, `_ribbon`)
- Modify: `docs/agents/opening.md`
- Reference: `world/boot.gd`, `ui/opening.gd:97-130` (the clock constants), `docs/agents/opening.md` "The grid built one by one".

**Interfaces:**
- Consumes: `WordTiles` (Task 1): its mesh and `shown`; `ui/peeplet_view.gd`.
- Produces: `Opening.landed(rank)` keeps its meaning (a tile set down) so the sounds in `world/boot.gd` stay wired; ranks now run 0..11.

- [ ] **Step 1: The tiles.** The 3x3 grid, the sprout, the word and the sun go. A `WordTiles` child (tile `TILE` scaled by `u` as the grid was) stands where the grid stood; the tiles come in one by one in reading order 0.085 s apart from `TILE_AT`, each with its puff and `landed(rank)`; the ripple every 2.6 s runs over the twelve. `SETTLED` becomes `TILE_AT + 12 * TILE_STEP + TILE_TIME + 0.4`. Leaving: the tiles pop out in the run they came in. Reduce motion: finished from the first frame.

- [ ] **Step 2: The Peeplet, measured.** Time `load("res://ui/peeplet_view.gd").new()` plus its first `_rebuild()` on this Mac with `Time.get_ticks_usec()` printed from a throwaway probe. If under 150 ms here, add a `PeepletView` (dressed `Cast.persona(0)`, `idle_fps 0`) that hops in behind the tiles after the twelfth lands (`Motion.drop_in_lift`); otherwise leave it out and write the number in `opening.md`. The phone's number is owed either way; say so in the doc.

- [ ] **Step 3: Parse, then watch it**

Run: `godot --headless --check-only --script ui/opening.gd && ulimit -f 200000; caffeinate -d -i -u timeout 60 godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle` (the game itself; it opens on the boot scene).
Expected: the twelve tiles lay down with their pops, the ripple runs, the first screen's header shows the same tiles.

- [ ] **Step 4: Docs and commit** (`opening.md`: a "The tiles (2026-10-27)" section with the draw-call count printed by the probe, the load time, and whether the Peeplet made it).

```bash
git add ui/opening.gd docs/agents/opening.md
git commit -m "feat(opening): the DAILY / PUZZLES tiles come together, as the icon; the grid, the sprout and the lettered word go"
```

---

### Task 7: The name

**Files:**
- Modify: `project.godot:28` (`config/name`), add `config/use_custom_user_dir=true` and `config/custom_user_dir_name="Peeplet Daily"` in `[application]`
- Modify: `export_presets.cfg:47` (`package/name="Peeplet"`), and the iOS preset gains `application/name="Peeplet"` (Godot's iOS preset key for the display name; check `godot --help` or the preset docs for the exact key in 4.7)
- Modify: `locale/ui.csv:993` (`FRIENDS_INVITE_TEXT` en/pt/es: "Peeplet: Daily Puzzles")
- Modify: `server/functions/src/generate.ts:117` (`X-Title`), `server/site/index.html`, `server/site/f/index.html`, `server/site/peeplet/privacy/index.html` ("Peeplet Daily Puzzles" to "Peeplet: Daily Puzzles")
- Modify: `docs/roadmap-to-release.md` (the name line; a follow-on line: listing text, feature graphic and shots to refresh after the header ships; the store renames by hand)
- Modify: `CLAUDE.md` (the Peeplet exception paragraph widens per the spec's "Docs and rules")
- Create: `docs/art/peeplet-brand.md` (per the spec: what the Peeplet is, personas, where it appears, where it never does, the sheet rule from the night plan)

- [ ] **Step 1: Pin the save folder first**, then rename. Verify: `godot --headless --path . --script tests/_offline_main.gd` (or any headless script printing `OS.get_user_data_dir()`) prints a path ending in `Peeplet Daily`.

- [ ] **Step 2: The strings.** Reimport after the csv edit (`godot --headless --path . --import`, per the reimport memory). `grep -rn "Peeplet Daily" --include=*.gd --include=*.csv --include=*.html --include=*.ts . | grep -v "custom_user_dir\|docs/"` lists nothing but the user-dir line.

- [ ] **Step 3: Suite and a parse of every touched script**; 0 failures.

- [ ] **Step 4: Commit**

```bash
git add project.godot export_presets.cfg locale/ui.csv server/functions/src/generate.ts server/site docs/roadmap-to-release.md CLAUDE.md docs/art/peeplet-brand.md
git commit -m "feat(brand): Peeplet: Daily Puzzles -- the app's name, the invite text and the site; the save folder pinned; the Peeplet brand note"
```

The store titles on Play Console and App Store Connect are the user's, by hand.
