# Binairo polish sub-project 2: the HUD rebuild — design

Date: 2026-09-14. Status: approved for planning.

Parent: `docs/superpowers/specs/2026-09-13-binairo-polish-design.md` (the
three-sub-project split, the motion library this builds on, and the decisions
table it inherits). Concept reference: `docs/art/concept-binairo-hud.png`,
the Binairo screen with its chrome (wordmark with leaf, back / undo / hint /
settings, the day card, the rules parchment, the working-line card, Reset and
Check, the motto footer). The character peeking beside the board in that image
is a placeholder: this project's mascots are the ten on the user's mascot
sheet (POM, NIBO, LUNA, BIBI, MOSS, KIKO, FINN, BRUNO, ZED, PIP; POM is
modelled at `art/mascot_pom.blend`), not Peeplets. No mascot is placed in this
sub-project.

## Goal

Replace the prototype shell around every board with the concept's HUD, with
real behaviour behind every button, on Binairo first and without breaking the
other nine prototypes. Build the shared theme (fonts, card styles, button
styles, icons) once, so the menu can take it later with no further design
work.

## Decisions taken with the user (2026-09-14)

| Question | Decision |
|---|---|
| Mascot on the stage in this pass | No. POM is placed with the lantern and the sign in sub-project 3. The HUD leaves the top-left of the board slot clear. |
| Working-line card | Row **and** column of the last tapped cell, two lines in one card, stateless. |
| Fonts | Fredoka (display) and Nunito (body), both OFL from Google Fonts. |
| Structure | Composable HUD: a thin host, one small script per panel under `ui/hud/`, puzzle capabilities as optional base-class methods with "unsupported" defaults. |
| Layout | The stack below, with three departures from the concept: cards sit in a row above the board rather than floating over it; the live timer and move count leave the HUD (they stay on the puzzle for the solved card); the prototype's New button moves into the settings sheet. |
| Remaining calls | Left to the agent by the user ("build it everything") and recorded in the sections below. |

## Non-goals

- The menu's own layout rebuild. The theme applies to it automatically
  through `CozyTheme.make()`; nothing else changes there.
- The solve celebration and the sliding stats card (sub-project 3). The
  solved overlay keeps its behaviour and only takes the theme.
- Sound. Every new effect names its cue through `Fx.cue` as before.
- Any 3D prop (lantern, sign, mascot).
- Converting another board to 3D or giving another board undo / hint / check.

## 1. Layout

Portrait, `canvas_items` stretch with `expand` aspect, so the viewport is
1080 wide by at least 1920 tall (or taller on long phones; wider on tablets).
Everything anchors; the board slot takes what is left.

```
 [<]   BINAIRO🍃                 [↶] [💡3] [⚙]     top bar        120
       balance brings harmony
 ┌ Day 12 ───────┐        ┌ RULES ────────────┐
 │ Sunlit Cliffs │        │ • Never three ... │     cards row      fits content
 └───────────────┘        │ • Equal count ... │
                          └───────────────────┘

                    board slot                       everything left over

 ┌ Row 3  ●●◌◌◌◌ 4/6 ┐   [↺ Reset]  [✔ Check]      action bar     150
 │ Col 5  ●◌◌◌◌◌ 2/6 │
 └───────────────────┘
          THINK · BALANCE · COMPLETE                 motto footer   50
```

- Root margins 40 left and right, 40 top plus the safe-area top inset, 40
  bottom plus the safe-area bottom inset. The inset comes from
  `DisplayServer.get_display_safe_area()` converted into viewport units
  (zero on the desktop). Panels are separated by 20.
- The **top bar** is a horizontal row: back (110 x 110 icon button), the
  wordmark block expanding in the middle, then undo, hint and settings (110 x
  110 each, separated by 16). The wordmark block is a vertical pair: the
  puzzle title in `Wordmark` (Fredoka 700, 72 px, `SURFACE` fill, `OUTLINE`
  outline 8 px) with a leaf icon drawn just past its last glyph, and the
  puzzle's motto in `Motto` (Nunito 700, 24 px, upper case, `TEXT_DIM`).
- The **cards row** is a horizontal row: the day card (min 420 wide, sizes to
  content, top-aligned) then a spacer then the rules card (max 520 wide,
  sizes to its wrapped text, top-aligned). The viewport is never narrower
  than 1080 under `expand`, so the row never needs to wrap.
- The **board slot** is a `Control` with `SIZE_EXPAND_FILL`. The paper card
  behind 2D boards stays inside it, hidden for 3D boards, as today.
- The **action bar** is a horizontal row of three: the line card (min 420
  wide, `SIZE_EXPAND_FILL`), Reset (min 260 x 130), Check (min 260 x 130),
  separated by 20. Whichever of the three the puzzle does not support is
  hidden and the others take its space.
- The **footer** is one centred label in `Motto`: the puzzle's footer motto.
- The solved **overlay** covers everything: a scrim in `PAPER` at 0.85 and a
  centred paper card with the stats in `CardTitle` and `CardBody`. Tapping
  anywhere dismisses it, as today.
- The **settings sheet** sits above the overlay: a scrim in `OUTLINE` at 0.35
  and a paper card anchored to the bottom, full width minus the margins, that
  slides up.

Per-puzzle text comes from the registry entry: `title` (exists), plus two new
optional keys `motto` and `footer`. Binairo gets `"Balance brings harmony"`
and `"Think · Balance · Complete"`. A missing key gives an empty label that
takes no space.

## 2. Components

Every panel is a `Control` script under `ui/hud/` with the same shape: it
builds its own children from the theme in `_ready`, keeps them under one
`_inner` `Control` (so its entrance can move `_inner.position` without
fighting the container it sits in), and exposes:

```gdscript
func enter(delay: float) -> void   # runs the entrance; a no-op end state under reduce
func refresh(puzzle) -> void       # re-reads the puzzle; every panel tolerates puzzle == null
```

| Script | Shows | Signals | Reads from the puzzle |
|---|---|---|---|
| `ui/hud/top_bar.gd` | back, wordmark + leaf + motto, undo, hint with badge, settings | `back`, `undo`, `hint`, `settings` | `capabilities()`, `can_undo()`, `hints_left()`, `is_done()` |
| `ui/hud/day_card.gd` | island icon, `Day N`, island name | none | nothing; the host calls `set_day(n, name)` |
| `ui/hud/rules_card.gd` | `RULES` heading, bullets | none | `rules()` split into sentences |
| `ui/hud/line_card.gd` | two lines: label, dots, count | none | `line_state()`, `board_size()` |
| `ui/hud/action_bar.gd` | line card, Reset, Check | `reset`, `check` | `capabilities()`, `is_done()` |
| `ui/hud/settings_sheet.gd` | Reduce motion toggle, New puzzle (prototype), Close | `reduce_changed(on)`, `new_puzzle`, `closed` | nothing |
| `ui/hud/icon_button.gd` | a `Button` drawing one vector icon, optional label, optional badge | inherits `pressed` | nothing |

`IconButton` is the one button class the HUD uses. `icon: String` names an
entry in `Icons`; `label: String` (empty for the square icon buttons) puts
text right of the icon; `badge: int` (0 hides) draws a `WATER` circle with the
number in `Badge` at the top-right corner. It sets `pivot_offset` to its
centre on resize and runs `Motion.squash(self, 0.10, 0.18)` on `button_down`.
`theme_type_variation` picks the look: `IconButton` (paper), `PrimaryButton`
(sun), `DarkButton` (slate).

**Rules bullets.** `rules_card` splits `rules()` on `". "` and strips the
trailing full stop, so Binairo's one sentence of three clauses becomes three
bullets only if written as three sentences; Binairo's `rules()` is rewritten
as three sentences: "Fill every cell with a sun or a moon. Never three alike
in a line. Every line has an equal count of each, and no two lines are
identical."

**Line card rendering.** Each line is a label (`CardBody`, `MOON` on slate),
then one dot per cell drawn in `_draw` (radius 9, gap 8; filled `SUN` for a
sun, filled `MOON` for a moon, a 2 px `MOON` ring at 0.5 alpha for empty),
then the count `k/n` where `k` is the filled cells. Labels are 1-based:
`Row 3`, `Col 5`. Before the first tap, or after `focus_changed` with no
focus, the card shows `Tap a tile` dimmed with `n` hollow dots and no count.
The whole card refreshes on `moved` and `focus_changed`.

**Host.** `ui/puzzle_host.gd` keeps `setup(entry, difficulty)`, `closed`,
`_puzzle`, `_overlay`, `_spawn`, `_on_reset`, `_on_new` and `_on_solved`,
which the win and screenshot harnesses reach. It builds the stack of section
1, connects panel signals to puzzle actions, forwards `moved`, `solved` and
`focus_changed` to `refresh()` on every panel, asks `Progress` for the day
on every spawn, and runs the entrance (section 5). It loses the timer
`_process`. Panel instances are kept in named fields (`top_bar`, `day_card`,
`rules_card`, `action_bar`, `settings_sheet`) so tests and harnesses can
reach them.

Amendment: the panels share a base script, `ui/hud/panel.gd`, which owns
`_inner`, the minimum-size plumbing and `enter()`. `ui/hud/line_card.gd` is a
plain `PanelContainer` inside the action bar, not a panel of its own.

Amendment (2026-09-15): the rules leave the cards row so the board can take
the room. `ui/hud/rules_card.gd` is gone; `ui/hud/help_card.gd` (a panel
holding one `IconButton`, `help` glyph, "How to play", signal `open`) stands
at the right of the day card and the host opens `ui/hud/rules_sheet.gd`, a
parchment sheet with a "How to play" heading, the same bullets and a Got it
button. Both sheets extend `ui/hud/sheet.gd`, which owns the scrim, the card
and the slide; the slide moves a full-rect wrapper rather than the card, so
a card whose height is still settling is never frozen at a stale height.
`IconButton` widens its `custom_minimum_size` to fit its glyph and label.
The host's fields are now `help_card` and `rules_sheet`. The camera rig's
`fit` re-centres the board inside the distance search (it used to re-centre
only between three passes and stopped about a quarter too far out on deep
boards), so every board frames tight to its slot.

Amendment (2026-09-15, the menu): the menu takes the theme, as the goal
foresaw. `ui/menu.gd` now lays out, over the bare island (no paper scrim),
a `TopBar` without its back button (a blank of the button's size keeps the
wordmark centred against the gear), the `DayCard`, a scrolling column of
`ui/hud/puzzle_card.gd` (a panel: paper card, a lettered medallion in a
`Palette.CAT` colour with the buttons' deeper bottom edge, title, blurb
wrapped to the card, a sun chevron pill; a flat Button over the paper
squashes and tints it on press and emits `open`) and the motto footer, with
the HUD's entrance choreography (top bar, day card, cards in a capped
stagger, footer) replayed on every return from a puzzle. Opening the menu
counts the day (`Progress.touch()`), so the card never reads Day 0. The
settings sheet applies the reduce-motion toggle itself (persist, still the
world) and takes a `show_new` flag so the menu can leave out the prototype
row; both screens only refresh their chrome on `reduce_changed`. The
safe-area insets moved to `ui/safe_area.gd`. `Icons` gained
`chevron_right`. `tests/_shot.gd` waits out the menu's re-entrance before
its final shot.

## 3. Puzzle capabilities

`core/puzzle_base.gd` grows optional hooks. Defaults mean "unsupported", so
the nine 2D prototypes compile unchanged and the HUD hides what they lack.

```gdscript
signal focus_changed                 # a board that tracks a focused cell emits this

var hints_used: int = 0
var checks: int = 0

## Which optional actions this puzzle supports: any of "undo", "hint", "check", "lines".
func capabilities() -> Array[String]: return []
func can_undo() -> bool: return false
## Reverts the last move. True when something was undone.
func undo() -> bool: return false
func hints_left() -> int: return 0
## Fills one cell from the solution. True when a cell was filled.
func hint() -> bool: return false
## Marks cells that differ from the solution. Returns how many, -1 when unsupported.
func check() -> int: return -1
## {} when nothing is focused, else {"row": {"index": r, "cells": [...]},
## "col": {"index": c, "cells": [...]}} with cell values -1 empty, 0 sun, 1 moon
## (Binairo's encoding; the line card is Binairo's card for now).
func line_state() -> Dictionary: return {}
## Runs the solved check without counting a move (hints and undos use this).
func check_solved() -> void
```

`note_move()` becomes `moves += 1; moved.emit(); check_solved()`.

### Binairo

`capabilities()` returns all four.

**History and undo.** `_history: Array[Vector3i]` of `(r, c, previous value)`.
A tap on a free cell pushes before it changes the grid. `undo()`:

- False when `is_done()` or the history is empty.
- Pops `(r, c, prev)`. `_settle(r, c)`, `_grid[r][c] = prev`,
  `_turns[r][c] -= 1`, `_roll(r, c, -1)`: the prism rolls one third **away**
  from the player, the only unwinding roll in the game. `_roll` takes the
  sign from `thirds`; the time is `ROLL_TIME` for one third either way.
- `_show_faces` uses `posmod(_turns[r][c], 3)`, so negative turn counts pick
  the right face. `_target_angle` already handles negatives.
- The landing puff for an away roll rises from the **far** edge
  (`z - TILE_SIDE / 2`): `_on_roll_landed` takes the direction.
- Then `_focus(r, c)`, `_bob_neighbours(r, c)`, `_recolour()`, and
  `moved.emit()` without touching `moves`. Undo cannot solve: no state in the
  history was solved, or the game would have ended there.
- `reset_board()` and `build()` clear the history. Audio cue `undo`.

**Hint.** `HINTS := 3`. `_hinted: Array[Array]` of bools per cell.
`hints_left()` is `HINTS - hints_used`. `hint()`:

- False when `is_done()` or none left.
- Picks the cell: first, the first free filled cell in reading order whose
  value differs from the solution; otherwise the empty cell with the most
  filled cells in its row plus its column, ties broken by reading order.
  False if no cell qualifies (cannot happen on an unsolved board).
- `_settle(r, c)`. Removes every history entry for `(r, c)`. Sets
  `_grid[r][c]` to the solution, rolls forward `posmod(FACE[target] -
  FACE[old], 3)` thirds (1 or 2, timings as the reset wave), marks
  `_given[r][c] = true` and `_hinted[r][c] = true`, repaints the cell at its
  current blend (so it takes the given tint), fires `fx.sparkle` at the cell
  centre at `TILE_RISE + 0.1`, `hints_used += 1`, `_focus(r, c)`,
  `_recolour()`, `moved.emit()`, `check_solved()`. Cue `hint`.
- A hinted cell is locked like a given: taps only focus and dip it.
- `reset_board()` unlocks hinted cells (`_given` and `_hinted` back to
  false, repaint) and rolls them to empty with the wave like any filled free
  cell. `hints_used` stays: three per puzzle, not per attempt. `build()`
  resets `hints_used` and `checks`.

**Check.** `check()`:

- Returns 0 when `is_done()`. Counts free, non-given, filled cells whose value
  differs from the solution; `checks += 1`.
- Each wrong cell wobbles (`Motion.wobble(pivot)`, tracked in `_wobbles[r][c]`;
  `_settle` stops it and snaps `rotation.z` to 0) and flashes: its blush fade
  is replaced by a fade from the current blend to `CHECK_BLEND` (0.5, 8/16)
  in 0.15 s then back to `_blend_target[r][c]` in 0.45 s, on the tile node,
  through the same `_paint` setter. `_blend_target` is not touched, so a
  later `_recolour` does not restart the flash.
- Cue `check` when anything was wrong, `check_ok` otherwise.

**Focus and lines.** `_focus` and `_focus_clear` emit `focus_changed`.
`line_state()` returns `{}` when `focus_cell.x < 0`, else the focused row's
values and the focused column's values with their indices.

**Solve.** On `solved` the top bar disables undo and hint and the action bar
disables Check; Reset stays.

### Host wiring

| Panel signal | Host action |
|---|---|
| `top_bar.back` | `closed.emit()` |
| `top_bar.undo` | `_puzzle.undo()`, then refresh all |
| `top_bar.hint` | `_puzzle.hint()`, then refresh all |
| `top_bar.settings` | open the settings sheet |
| `action_bar.reset` | `_puzzle.reset_board()`, hide the overlay, refresh all |
| `action_bar.check` | `var n := _puzzle.check()`; when `n == 0` the Check button shows `All good` for 1.2 s and squashes; refresh all |
| `settings_sheet.reduce_changed(on)` | `Motion.reduce = on`, `Motion.save_settings()`, `stage.ambient.refresh()` when a stage exists, refresh all |
| `settings_sheet.new_puzzle` | `_on_new()` |

## 4. Theme, fonts, icons, palette

**Fonts** in `assets/fonts/`: `Fredoka-Variable.ttf` and `Nunito-Variable.ttf`
(renamed from the google/fonts `ofl/fredoka/Fredoka[wdth,wght].ttf` and
`ofl/nunito/Nunito[wght].ttf`), each with its licence beside it as
`OFL-Fredoka.txt` and `OFL-Nunito.txt`. `CozyTheme.display(weight)` and
`CozyTheme.body(weight)` return cached `FontVariation`s with the `wght` axis
set. When a font file is missing (a stripped test project), both fall back to
`ThemeDB.fallback_font` so nothing crashes.

**Type variations** in `ui/theme.gd` (Godot `theme_type_variation` names):

| Name | Base | Font | Size | Colour | Notes |
|---|---|---|---|---|---|
| `Wordmark` | Label | display 700 | 72 | `SURFACE` | outline `OUTLINE` 8 px |
| `Motto` | Label | body 700 | 24 | `TEXT_DIM` | upper case set by the caller |
| `CardTitle` | Label | display 600 | 40 | `TEXT` | |
| `CardBody` | Label | body 500 | 30 | `TEXT` | |
| `OnSlateTitle` | Label | display 600 | 40 | `MOON` | day card, line card |
| `OnSlateBody` | Label | body 500 | 30 | `MOON` | |
| `Badge` | Label | display 700 | 26 | `SURFACE` | |
| `IconButton` | Button | body 700 | 34 | `TEXT` | paper card, radius 28, bottom border `LINE` 6 |
| `PrimaryButton` | Button | display 700 | 40 | `TEXT` | `SUN` fill, bottom border `SUN_DEEP` 8, radius 32 |
| `DarkButton` | Button | display 700 | 40 | `MOON` | `SLATE` fill, bottom border `SLATE_GIVEN` 8, radius 32 |

Card styleboxes as static functions: `paper_card()` (`PAPER` at 0.94, radius
28, bottom border `LINE` 6, content margin 24), `slate_card()` (`SLATE` at
0.92, radius 24, content margin 20), `parchment_card()` (`PARCHMENT` at 0.96,
radius 12, border `LINE` 3 all round, content margin 24). Pressed state on
every button variant drops the bottom border to 2 and darkens the fill toward
`LINE` by 15 percent; hover equals normal (touch has no hover).

`Button` (plain, unvariated) keeps today's paper look so the menu and the 2D
boards' own buttons (Code Break's Check) are unchanged except for the body
font.

**Palette additions** (`core/palette.gd`):

| name | hex | use |
|---|---|---|
| `SUN_DEEP` | `d88a12` | primary button's bottom border |
| `PARCHMENT` | `f3e9d2` | rules card |

Contrast, checked in `tests/test_theme.gd` with `Palette.contrast`: `TEXT` on
`PAPER`, `TEXT` on `SUN`, `MOON` on `SLATE`, `TEXT` on `PARCHMENT` all at or
above 4.5.

**Icons** in `ui/icons.gd`, pure geometry so they test headless. Every icon
is a function returning `{"polys": Array[PackedVector2Array], "lines":
Array[PackedVector2Array]}` in the unit square, and

```gdscript
const NAMES := ["chevron_left", "undo", "reset", "bulb", "gear", "check", "leaf", "island"]
static func shape(name: String) -> Dictionary
static func paint(ci: CanvasItem, name: String, rect: Rect2, colour: Color, hole := Color.TRANSPARENT) -> void
```

`paint` maps the unit square onto `rect`, fills each polygon with
`draw_colored_polygon`, strokes each polyline with `draw_polyline` at width
`0.12 * rect.size.x` with round caps, and, when `hole` is not transparent,
fills the shape's optional `"hole"` polygon in `hole` on top (the gear's
centre). Shapes: `chevron_left` (one polyline), `undo` (a 270 degree arc
polyline from 12 o'clock anticlockwise plus an arrowhead polygon at its
start), `reset` (the same arc clockwise), `bulb` (a circle polygon on a
rounded base polygon, two short rays), `gear` (eight teeth on a ring, hole in
the middle), `check` (one polyline), `leaf` (two arcs closed into a polygon
plus a midrib polyline), `island` (a mound polygon, a trunk polyline, a
canopy circle). Circles and arcs come from helpers with 24 segments.

Amendment (2026-09-14): the Motto variation is `SURFACE` with a 4 px `OUTLINE`
outline, not `TEXT_DIM`, which vanished against the sky.

## 5. Motion: new recipes, entrance, press, badge

`core/motion.gd` additions. Every recipe keeps the contract: returns the
`Tween` or `null` under reduce with the end state set.

```gdscript
## Puts `property` at `from`, then eases it to `to`; overshoot gives the back ease, otherwise sine in-out.
static func slide(node: Node, property: String, from, to, time: float, delay := 0.0, overshoot := true) -> Tween
## Breathes `property` between `rest` and `peak` forever, sine in-out, `period` seconds per cycle.
## `target` is the object holding the property (a material, say); defaults to `node`.
static func pulse(node: Node, property: String, rest, peak, period: float, target: Object = null) -> Tween
## Fades a CanvasItem's modulate alpha from `from` to `to`.
static func appear(item: CanvasItem, from: float, to: float, time: float, delay := 0.0) -> Tween
```

- `squash(node: Node, ...)` accepts a `Control` as well: it scales `Vector2`
  the same way (`x` wider, `y` flatter) around the control's `pivot_offset`.
- `hop(node: Node, ...)` accepts a `Control` (its `position.y` is a float
  either way).
- `_focus` in Binairo is ported: the slide uses `Motion.slide(_ring,
  "position", _ring.position, at, FOCUS_MOVE, 0.0, false)`, the pulse uses
  two `Motion.pulse` calls (scale on the ring, alpha on the material) kept in
  `_ring_pulses: Array`. Behaviour and numbers are unchanged; the focus tests
  keep passing.

**Entrance.** The host calls `enter(delay)` on every panel right after
building them, staggered: top bar 0.0, day card 0.1, rules card 0.1, action
bar 0.2, footer 0.3. Each panel slides `_inner.position` from its offset to
zero over 0.35 s with the back ease and fades `modulate` from 0 to 1 over
0.25 s: top bar from `(0, -80)`, day card from `(-120, 0)`, rules card from
`(120, 0)`, action bar from `(0, 100)`, footer alpha only. The whole HUD is in
by 0.7 s while the board is still popping. A new puzzle from the settings
sheet does not re-run the HUD entrance; only the board enters again.

**Press.** Every `IconButton` squashes on `button_down` (above). Cue `press`.

Amendment (2026-09-14): no `press` cue is fired. `Fx.cue` lives on the board
and the HUD has no handle on it; the audio layer, when it comes, will give the
HUD its own cue hook. The squash is implemented.

**Hint badge.** While `hints_left() > 0` and not done, the badge bounces:
a looping tween of `Motion.hop(badge, -6, 0.3)` then a 2.1 s interval (2.4 s
cycle). Under reduce the badge is still. At 0 the badge hides and the hint
button is disabled.

**Settings sheet.** Opening: the scrim `appear`s 0 to 1 over 0.2 s and the
card `slide`s from 300 below to its place over 0.3 s. Closing runs both in
reverse then hides. Under reduce both snap.

**All good.** On a clean check the Check button's label reads `All good` and
the button squashes; a 1.2 s one-shot tween restores `Check`. Cue `check_ok`.

## 6. Progress and settings

`core/progress.gd` (`RefCounted`, static):

```gdscript
static var path: String = "user://progress.cfg"
const ISLANDS := [
	"Sunlit Cliffs", "Moss Harbour", "Lantern Cove", "Driftwood Point",
	"Heron Shallows", "Fernwater Isle", "Pebble Reach", "Windmere Rock",
	"Tidepool Terrace", "Quiet Anchorage", "Bramble Key", "Saltgrass Hollow",
	"Kestrel Ledge", "Cinder Shoal", "Lily Landing", "Foxglove Cay",
	"Willow Strand", "Marigold Bank", "Otter Narrows", "Copper Cliffs",
	"Starling Rise", "Seagrass Flats", "Birch Haven", "Puffin Steps",
]
## Records that the player opened a puzzle today; returns the day number.
static func touch(date_key: int = Daily.date_key()) -> int
static func day() -> int
## Deterministic island name for a date.
static func island_name(date_key: int = Daily.date_key()) -> String
```

The day number is the count of **distinct UTC dates** on which a puzzle was
opened: `touch` increments `[progress] days` only when `date_key` differs
from the stored `[progress] last_date`. This departs from the parent spec's
"N counting puzzles played", because the prototype's New button would inflate
a per-puzzle count and "Day" should mean a day; the user did not rule on it
and it is recorded here for review. `island_name` is
`ISLANDS[hash(str(date_key)) % ISLANDS.size()]`. The file is separate from
`user://settings.cfg` so the two writers never race; tests point `path` at a
throwaway.

**Settings load moves.** `world/main.gd` (new, on the `Main` node of
`world/main.tscn`) calls `Motion.load_settings()` in `_enter_tree`, which
runs before any child enters the tree, so `Stage._ready()` and
`Ambient.refresh()` see the saved flag. `Stage._ready()` no longer loads
settings. The stage-building test suites keep pointing `Motion.settings_path`
at a throwaway file; their comments update.

## 7. Parked items from sub-project 1's final review

| Item | Done here |
|---|---|
| `Motion.slide()` / `pulse()` and port `_focus` | Section 5 |
| Move `Motion.load_settings()` out of `Stage._ready()` | Section 6 |
| Toggle calls `stage.ambient.refresh()` | Section 3, host wiring |
| Undo needs negative `_turns` (`_show_faces` used `% 3`) | Section 3, `posmod` |
| Wind offset flips on mirrored rim pieces | `shaders/toon_wind.gdshader`: the x displacement is multiplied by the sign of the model matrix's determinant, so a piece mirrored with `scale.x = -1` leans the same way as its neighbours. Judged from `_shot_anim.gd` frames. |
| Make `_shot.gd` time-based | `tests/_shot.gd` keys on elapsed seconds (open at 0.1 s, shoot at 2.0 s, close at 2.2 s per puzzle) instead of frame counts. |
| Null guards in `Ambient` / `Fx` | `Fx.puff` / `Fx.sparkle` return when their pool is empty (the node never entered the tree); `Ambient.refresh` / `splash` return when `pollen` is null or `Toon.water()` is null. |
| Draw-call baseline on `60c7256` | Measured once with a throwaway script against a temporary worktree at that commit and recorded in section 9. If the old tree cannot run the strip, the spec says so. |

## 8. Testing

Headless suites (`godot --headless --path . --script res://tests/run_tests.gd`):

- **New `tests/test_icons.gd`.** Every name in `Icons.NAMES` has a shape;
  every polygon has at least three points; every point of every polygon and
  polyline lies in the unit square; `gear` has a hole.
- **New `tests/test_progress.gd`.** With `Progress.path` on a throwaway file:
  the first `touch(A)` returns 1, `touch(A)` again returns 1, `touch(B)`
  returns 2, `day()` reads back 2 after a fresh load; `island_name` is in
  `ISLANDS` and equal for equal dates.
- **New `tests/test_theme.gd`.** `make()` yields the type variations above;
  `display()` and `body()` return a `FontVariation` with a base font; the
  four contrast pairs are at or above 4.5.
- **New `tests/test_hud.gd`** (`run_in_tree`, throwaway settings and progress
  paths, a `Stage` in the tree). Two hosts: one on a stub puzzle
  (`tests/stub_puzzle.gd`, a `PuzzleBase` with no capabilities) and one on
  Binairo. Stub: undo, hint, Check and the line card are hidden, Reset is
  shown. Binairo: all shown; the badge reads 3; the line card reads `Tap a
  tile` before any tap and `Row r+1` / `Col c+1` with the right filled counts
  after `on_board_press`; pressing the top bar's hint emits through to
  `hints_used == 1` and the badge reads 2; undo is disabled with an empty
  history and enabled after a tap; the settings toggle flips `Motion.reduce`,
  saves it, and `motion_scale` reads 0; stepping every entrance tween leaves
  every panel's `_inner.position` at zero and `modulate.a` at 1; under
  reduce `enter()` returns with that end state at once.
- **`tests/test_binairo3d.gd` extended.** Undo: after a tap then `undo()`,
  the grid value is back, `_turns` is one less, the stepped pivot angle equals
  `_target_angle`, the face-up emblem is the right one for a negative turn
  count, the history is empty and `can_undo()` is false. Hint: fills the
  solution value, locks the cell (`_given`), the tile takes the given tint,
  `hints_left()` drops to 2, three hints then `hint()` returns false; with a
  wrong filled cell present, the hint corrects it first. Check: returns the
  wrong count, a wobble runs on each wrong pivot and stepping it lands
  `rotation.z` on 0, `checks` increments, a clean board returns 0. Reset
  unlocks hinted cells and clears the history. `focus_changed` fires on a
  tap. `line_state()` matches the grid.
- **`tests/test_motion.gd` extended.** `slide` starts at `from` and lands on
  `to` on a `Node3D` and a `Control`; `pulse` returns a looping tween and is
  at `rest` after a whole period; `appear` lands on `to`; `squash` and `hop`
  on a `Control` return to the starting scale and height; all return `null`
  under reduce with the end state set.
- **`tests/test_palette.gd`** covers the two new constants.
- **`tests/test_ambient.gd`** adds: `refresh()` and `splash()` on an
  `Ambient` that never entered the tree do not error.

Harnesses:

- **`tests/_win.gd`.** The Binairo path presses the real Hint button once and
  the real Check button once through touch events before solving, then
  reports `hints=1 checks=1` in its note. `winnable=10/10` stays.
- **`tests/_shot.gd`** goes time-based (section 7); the Binairo shot at
  1080 x 1920 is read back and judged against the concept.
- **`tests/_shot_anim.gd`** unchanged; its idle frames judge the wind fix.

Amendment (2026-09-14): the user suspended new tests for this sub-project. No
new suites were written; the existing suite, the win harness (which now
presses Hint and Check) and the screenshot harness are the checks. The tests
described above remain the intended coverage when testing resumes.

## 9. Performance

The HUD adds `Control`s, one `_draw` per icon button and per line card, and
the badge's looping tween. Budget unchanged from the parent spec: idle frame
time at or under 8 ms at 1080 x 1920 on the Mac, draw calls at most 20 above
sub-project 1's 755 at rest. Measured numbers are recorded here when the
sub-project is called done, along with the `60c7256` baseline.

Amendment (2026-09-14): measured from `_shot_anim.gd` on the Mac at
1080 x 1920: `idle frames=391 mean_ms=5.11 max_draw_calls=836`. Mean frame
time is well inside budget. Draw calls are not: the `60c7256` baseline (before
the HUD), measured the same way with a throwaway `tests/_draw_calls.gd` in a
worktree on that commit, is `draw_calls=751`, so the HUD adds about 85 draw
calls against a budgeted 20 (755 + 20 = 775 versus the measured 836). The gap
is left as a known overage for a later pass rather than fixed in this
sub-project.

Amendment (2026-09-14, controller ruling): frame time is the binding budget.
The +20 draw-call cap assumed no 2D chrome; every Label and StyleBox in the
HUD is a canvas draw call, so the cap is raised to at most 100 above 755
(855). 836 is inside it, with 2.9 ms of frame-time headroom on the Mac.

## 10. Files

New: `ui/hud/top_bar.gd`, `ui/hud/day_card.gd`, `ui/hud/rules_card.gd`,
`ui/hud/line_card.gd`, `ui/hud/action_bar.gd`, `ui/hud/settings_sheet.gd`,
`ui/hud/icon_button.gd`, `ui/icons.gd`, `core/progress.gd`, `world/main.gd`,
`assets/fonts/Fredoka-Variable.ttf`, `assets/fonts/Nunito-Variable.ttf`,
`assets/fonts/OFL-Fredoka.txt`, `assets/fonts/OFL-Nunito.txt`,
`tests/test_icons.gd`, `tests/test_progress.gd`, `tests/test_theme.gd`,
`tests/test_hud.gd`, `tests/stub_puzzle.gd`, `docs/art/concept-binairo-hud.png`.

Modified: `ui/puzzle_host.gd`, `ui/theme.gd`, `ui/registry.gd` (motto and
footer for Binairo), `core/puzzle_base.gd`, `core/motion.gd`,
`core/palette.gd`, `puzzles/binairo3d.gd`, `world/stage.gd`,
`world/main.tscn`, `world/ambient.gd`, `world/fx.gd`,
`shaders/toon_wind.gdshader`, `tests/_win.gd`, `tests/_shot.gd`,
`tests/run_tests.gd`, `tests/test_motion.gd`, `tests/test_binairo3d.gd`,
`tests/test_palette.gd`, `tests/test_ambient.gd`, `README.md`.

Amendment (2026-09-14): `ui/hud/panel.gd` is also new (see the amendment
under section 2). Struck from New: `tests/test_icons.gd`,
`tests/test_progress.gd`, `tests/test_theme.gd`, `tests/test_hud.gd` and
`tests/stub_puzzle.gd` — the user suspended new tests before they were
written (see the amendment under section 8).

## 11. What sub-project 3 relies on from here

The theme (fonts, card styles, button variants) for the solved card; `Icons`
for the share glyphs' buttons; `Motion.slide` / `appear` for the card sliding
up; `PuzzleBase.hints_used` and `checks` for the end stats; the host's panel
fields for the panels' reaction to the solve; the clear top-left of the board
slot for POM.
