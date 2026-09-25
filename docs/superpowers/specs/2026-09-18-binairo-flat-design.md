# Binairo, flat: a 2D board to judge against the island — design

Date: 2026-09-18. Status: approved for planning.

Reference: `docs/art/concept-binairo-flat.png`, the user's mock of a flat
Binairo (2026-09-18): three phone screens (the board on day 5, the board with
a palette, the win screen) and a sheet of parts. The current game is the
island in `puzzles/binairo3d.gd` under the chrome of
`docs/superpowers/specs/2026-09-14-binairo-hud-design.md`.

## 0. The question this answers

The user is not sure the 3D approach is the right one. This builds Binairo a
second time as a flat, illustrated, heavily animated 2D screen after the
reference, beside the island version, so both can be played on the phone and
judged against each other. Nothing else in the game changes; the other
eleven boards, the turns and the campsite menu stay as they are. The verdict
decides which Binairo lives on, and whether the other boards follow.

## 1. Decisions taken with the user (2026-09-18)

| Question | Decision |
|---|---|
| How much of the screen goes 2D | The whole in-game screen, as the reference: flat board, illustrated suns and moons, cream chrome, palette, tip card, win screen. Binairo only. |
| Filling a cell | Tap cycles empty, sun, moon, as today. The palette arms a brush: while a symbol is armed, cells take it directly. |
| First artefact | A playable Godot prototype, not a concept tab. The reference is the concept picture. |
| How it is built | Faces drawn from parts in code so every part animates; a flat host that extends today's host and swaps only the chrome; the Binairo rules pulled out of the cube script into a state class. The island script is not touched. |
| Difficulty control | Out. The reference's Easy / Normal / Hard segment is not built; the board keeps the registry's difficulty as every board does. |
| Hearts, levels | Out. There are no lives and no levels; it is a daily. |

## 2. Non-goals

- Any change to the island Binairo, the other boards, the turns, the menu or
  the shared theme's existing variants. New theme variants are added; none
  is altered.
- A difficulty control on the screen, hearts, a level progress bar or a
  Next Level flow. All three appear in the reference and none applies.
- Sound. Every effect names its cue through the existing hook as before.
- Localisation of the board's strings. The boards are hardcoded English until
  the registry's own blurbs get keyed.
- Sharing from the win screen. `share_glyphs()` stays available for later.
- Tests. Per the user's MVP rule no test files are written; verification is
  by harness and by eye (section 11).

## 3. Layout

Portrait, `canvas_items` stretch with `expand` aspect: 1080 wide by 1920 or
taller. One column with the host's margins (40 each side, 40 plus the safe
inset top and bottom), panels 20 apart.

```
 [<]   🌱BINAIRO                [↶] [💡3] [⚙]     top bar        180
       BALANCE BRINGS HARMONY
 ┌ 🌲  Day 5 ──────────────────────────────┐
 │     Moss Harbour                        │      day card       120
 └─────────────────────────────────────────┘
 ┌─────────────────────────────────────────┐
 │        the grid, square, centred        │      board card     all that is left
 │        6x6, or 8x8 on hard              │
 └─────────────────────────────────────────┘
            [ ☀ ]   [ ☾ ]   [ × ]                 palette row    150
    [↻ Reset]                    [✔ Check]        actions        130
 ┌ (sprout)  Never three alike in a line ──┐
 └─────────────────────────────────────────┘      tip card       140
```

Fixed rows and gaps come to 900 at the top and bottom margins, so the board
card gets 1020 at 1920 tall and more on a longer phone. The grid inside it is
a square of the card's shorter inner side.

- **Top bar**: back (110 square), the wordmark block expanding, then undo,
  hint with its count badge and settings (110 square each, 16 apart), all
  the existing `IconButton` in the paper variant. Undo and Hint stay up
  here: the reference never fits both its pill row and its palette on one
  screen, and the badge already carries the count. The wordmark is a
  `Label` in the shared `GameWordmark` variation (Fredoka 700, 84 px, `TEXT`) as
  mixed-case `BINAiRO`, with the leaf icon sprouting from its A, the shared
  golden sun over the lowercase i, and `Balance brings harmony` under it in
  sentence case. This is a deliberate departure from
  the carved-sign rule in `CLAUDE.md`, for this screen only, and is why the
  flat chrome is a host of its own.
- **Day card**: `CozyTheme.card(SURFACE, 28, LINE, 6, 24)` full width, a
  new `tree` icon (64) in `LEAF` at the left, "Day N" in `CardTitle` over the
  island's name in `CardBlurb`, both from `core/progress.gd` as today.
- **Board card**: `card(PARCHMENT, 32, LINE, 6, 24)`; the grid described in
  section 4 sits centred in it.
- **Palette row**: three 140-square chips 24 apart, centred (section 5).
- **Actions**: Reset in the paper `IconButton` variant at the column's left
  edge, Check in `PrimaryButton` at its right, both 260 by 130 as today.
- **Tip card**: `card(SURFACE, 28, LINE, 6, 24)`, the sprout (88) at the
  left and one line of body text (Nunito 500, 28 px, `TEXT`, wrapping to
  two lines) filling the rest. Tapping it opens the rules sheet. It replaces
  the How to play card and the working-line card. The motto footer goes.

## 4. The board

**Tiles.** Rounded squares (radius 18) 10 apart, drawn with `StyleBoxFlat`:
alternating `TILE_LIGHT` and `SURFACE_HI` in a checker, each with a 4 px
bottom edge in `LINE` at half alpha, the theme's soft rim. A given's tile is
`STONE_GIVEN` with a full-strength edge, so it reads as fixed without a mark.
A hint's tile takes the given look the moment it is filled. Under a broken
line the fill blends toward `BAD_TILE` (section 6).

**Faces.** The sun is a disc in `SUN` with eight rounded rays in `SUN_RAY`
and a lighter highlight arc at the upper left; the moon is a crescent in
`MOON_INK` open to the upper right with a `MOON_DEEP` shade along its inner
edge. Both carry two eyes, a smile and two `CHEEK` cheeks in the reference's
proportions, and a soft offset shadow of their own silhouette under them
(ink at 8 percent, 3 px down). A face fills 72 percent of its tile.

Each face is one `Control` (`ui/faces/sun_face.gd`, `moon_face.gd`,
`sprout_face.gd`, over `ui/faces/face.gd`) that draws all its parts in its
own draw call from a few tweened properties: `eye_open` (0 to 1, blink),
`expression` (HAPPY open eyes and smile, JOY closed arcs, WORRIED flat brows
and a small round mouth, SLEEPY half-lidded), `spin` (the sun's ray angle),
`rock` (the moon's tilt) and `squash` (x wide, y flat, for the pop). A
property change queues a redraw; nothing is a child node, so a 64-cell board
is 64 faces and 64 tiles, not hundreds of nodes. The same three faces draw
the palette chips, the win illustration and the tip card's sprout.

**Sprout.** A white blob (`SURFACE`) with a `LINE` outline two pixels wide,
two dot eyes, cheeks, a small smile and a pair of leaves (the leaf icon) on
its head. Its expressions are HAPPY, WORRIED and JOY.

**Colours.** New in `core/palette.gd`, all for this screen: `TILE_LIGHT`
(`fbf6ea`), `SUN_RAY` (`f9c04a`), `SUN_TILE` (`fff1d6`), `MOON_INK`
(`7d8fd9`), `MOON_DEEP` (`6273c0`), `MOON_TILE` (`e9ecfa`), `CHEEK`
(`f4a7a0`). Everything else is the palette as it stands.

## 5. Input

- **Tap** on a free cell cycles empty, sun, moon, empty. A tap on a given
  presses the tile and nothing changes, the island's dip.
- **Brush.** The palette's chips are sun, moon and clear. Tapping a chip
  arms it: it lifts 8 px and takes a 4 px border all round in its colour
  (`SUN`, `MOON_INK`, `LINE`), the others rest. While a brush is armed a tap
  on a free cell places that symbol (clear empties it); a tap that would
  change nothing still presses the tile and counts no move. Tapping the
  armed chip disarms it and taps cycle again. Reset and a new puzzle disarm.
  The brush is the puzzle's own state (`brush`, a signal `brush_changed`),
  not the host's.
- **Focus.** The last tapped cell's row and column take a tint of the
  symbol's colour at 8 percent for 1.5 s, then fade. `focus_cell` and
  `line_state()` stay as they are for anything that still reads them.
- **Touch only.** The grid handles `InputEventScreenTouch` and nothing else,
  the way `StageView` does, because the viewport hands a control both the
  mouse event and the emulated touch.
- `cell_to_local(r, c)` answers the centre of a cell, so the win harness and
  the animation probe tap this board the way they tap the island.

## 6. Motion

Everything goes through `core/motion.gd`. Decorative recipes return null
under reduce-motion and land their final state; the symbol change itself is
essential and shortens to `REDUCED_TIME`, linear. Timings in seconds; a
stagger uses `Motion.stagger`.

| Moment | What happens |
|---|---|
| Entrance | Tiles pop from scale 0 with the back ease, 0.25 each, staggered 0.03 along the diagonal (r + c) from the top left; a given's face lands 0.12 after its tile with a squash. The chrome enters as today (panels slide in, the flat host's rows in the same order). |
| Press | The tile scales to 0.94 over 0.08 and holds while the finger is down. |
| Release, changed | The old face shrinks to 0 with a quarter turn over 0.12; the new one pops from 0 with squash (x 1.15, y 0.85) to 1 over 0.22 with the back ease; the tile hops 6 px over 0.3; five tiny stars in the new symbol's colour puff from the tile's centre; the four side neighbours nudge 3 px away and back over 0.3 after a 0.04 lag. |
| Release, unchanged | The tile springs back from the press. Nothing else. |
| Idle faces | Every face blinks (`eye_open` 1 to 0.1 to 1 over 0.14) at its own random interval of 3 to 7 s. Suns turn their rays one revolution per 40 s. A third of the moons rock plus or minus 3 degrees with a 4 s period. All decorative. |
| Broken line | The line's tiles blend to `BAD_TILE` over 0.25 with the island's two heartbeats, its faces turn WORRIED, and each tile shivers 2 px once over 0.2. Fixed: fade back over 0.4, faces HAPPY. |
| Completed valid line | When a tap fills the last cell of a row or column and that line breaks nothing, its faces hop 8 px over 0.35, staggered 0.03 along the line, with JOY eyes for 0.6. |
| Hint | A ring pulses on the tile over 0.5; the face drops from 40 px above with the back ease over 0.3, sparkles rise, the tile takes the given look. |
| Check | Every wrong cell wobbles plus or minus 6 degrees over 0.45 and flashes toward `BAD_TILE` (0.15 in, 0.45 out). A clean check squashes the Check button and says All good, which exists. |
| Undo | The reverse of a release: the current face shrinks out, the previous one pops back. |
| Reset | Free cells' faces shrink out over 0.15, staggered 0.02 from the bottom left ((n - 1 - r) + c) as the island does; givens hop 4 px. |
| Solved | Every face hops 10 px over 0.4 with JOY eyes, staggered 0.04 along the diagonal, sparkles across the board, then the win state after 0.8 (section 8). |
| Palette | Arming lifts a chip 8 px over 0.18 with the back ease and fades its border in over 0.15; disarming reverses it. A press squashes the chip. |
| Focus tint | 0.12 in, 1.5 hold, 0.4 out. |

Two recipes are added to `core/motion.gd`: `wobble2d(node: Control, angle,
time)`, the damped shake on a Control's `rotation` about its centre
(`pivot_offset`), and `shiver(node: Control, px, time)`, a two-swing
horizontal nudge that ends where it began.

## 7. Teaching: the tip card

The card carries the sprout and one line. Idle, it cycles the three rules
every 8 s with a 0.25 crossfade: "Never three alike in a line", "Every line
holds as many suns as moons", "No two lines are the same". The moment a tap
breaks a line, the card names the broken rule at once and the sprout turns
WORRIED; when the line is fixed it goes back to the cycle and the sprout to
HAPPY. On a solve the sprout is JOY and the card says "Perfect balance!".
The puzzle exposes what broke through a `broken_rule() -> String` ("" when
nothing is broken), computed from the same `bad_lines` the blush uses, and
the host's tip card reads it on `moved`.

## 8. Well done

Triggered by `solved`, 0.8 s after the board's wave starts.

- The top bar and day card fade out over 0.25. The board stays where it is,
  settled and solved.
- Into the freed space a panel slides down from 200 px above over 0.4 with
  the back ease: a sun face (300) behind and to the left of a moon face
  (240) overlapping it to the lower right, both JOY; two leaf icons in
  `LEAF` at the sides; three four-point stars in `SUN`; "Well done!" in a
  new `WellDone` variation (Fredoka 700, 96 px, `TEXT`) and "Perfect
  balance!" in `CardBody` recoloured `TEXT_DIM`.
- The palette row, the actions and the tip card slide 100 px down and fade
  over 0.25. In their place, 0.15 later, a stats card and a button slide up
  from 120 px below over 0.35: the day card's look with "Day N" and the
  island's name at the left and time, moves and hints ("1:42 · 31 moves ·
  1 hint") at the right, then a full-width `PrimaryButton` "Back to camp"
  with the right chevron, which closes the host the way back does.
- The host's existing solved overlay is not shown on this screen. The
  `puzzle_complete` event fires from the host as today.

## 9. Architecture

### 9.1 `puzzles/binairo_state.gd` (`RefCounted`)

The rules with no scene in them, so the flat board and, after the verdict,
the island can share one truth. Cells are -1 empty, 0 sun, 1 moon.

- `n`, `grid`, `given`, `hinted`, `solution`, `history: Array[Vector3i]`
  (r, c, previous value), `bad: Dictionary` (`rows`, `cols`).
- `setup(out: Dictionary)` from `Gen.generate`; `is_solved()`;
  `share_glyphs()`; `line_state(focus: Vector2i)`.
- `cycle(r, c) -> bool`: the tap; false on a given. `place(r, c, v) -> bool`:
  the brush; false on a given or when nothing would change. Both push
  history and refresh `bad`.
- `undo() -> Vector3i`: the cell restored and its new value, or
  (-1, -1, -1).
- `hint_cell() -> Vector2i` (a wrong filled cell first, else the empty cell
  with the fullest row and column, as the island) and `apply_hint() ->
  Vector2i`: fills from the solution, locks the cell as given and hinted,
  drops that cell from history.
- `wrong_cells() -> Array[Vector2i]` for Check.
- `reset() -> Array[Vector2i]`: empties free cells, unlocks hinted ones,
  clears history; returns the cells that changed.
- `is_bad(r, c)`, `line_just_completed(r, c) -> Array[Vector2i]` (the cells
  of a row or column that this cell filled last and that breaks nothing;
  empty otherwise), `broken_rule() -> String`.

### 9.2 `puzzles/binairo2d.gd` (`PuzzleBase`, `is_3d()` false)

- Owns a `BinairoState`, the grid `Control`, `n` by `n` tiles (a `Panel`
  each with its face as its one child), the brush, the focus tint, every
  tween table (pops, hops, fades, wobbles, idle blinks) and an `Fx2D`.
- `capabilities()`: undo, hint, check. `undo()`, `hint()`, `check()`,
  `reset_board()`, `hints_left()` (three, not refunded by reset),
  `line_state()`, `share_glyphs()`, `rules()` as the island's.
- `build(rng, difficulty)` keeps the island's table: 6 with at least 16
  clues, 6 minimal, 8 minimal.
- `set_brush(v)`, `brush`, `brush_changed`; `broken_rule()`;
  `cell_to_local(r, c)`.
- Lays the grid out on `resized`: the square of the shorter side, centred.
  A tap mid-animation settles that cell first, so a face never starts from
  between two states.

### 9.3 The host

`ui/puzzle_host.gd` gets one refactor with no behaviour change: the panel
construction in `_ready` moves into `_build_chrome(root: VBoxContainer)`,
which `_ready` calls between building the margins and building the overlay.
Every handler, the sheets, the analytics and `_spawn` stay where they are.

`ui/flat/flat_host.gd` extends it and overrides:

- `_build_chrome`: a full-rect `ColorRect` in `PAPER` under the column (the
  page; the 3D world is hidden behind it, 9.6), then the rows of section 3
  from `ui/flat/flat_top_bar.gd` (the four buttons and the wordmark label;
  signals `back`, `undo`, `hint`, `settings`), `flat_day_card.gd`, the board
  card assigned to `_card` so `_spawn` treats it as today, `symbol_tray.gd`
  (three chips; `pick(v)`; `refresh(puzzle)` reads `brush`),
  `flat_actions.gd` (Reset, Check; the same signals as the action bar) and
  `tip_card.gd` (`refresh(puzzle)` reads `broken_rule()` and `is_done()`;
  `open` emits on tap).
- `_enter`, `_refresh`, `_on_solved` (which builds `well_done.gd` as in
  section 8 instead of showing the overlay) and `_on_reset` (which also
  disarms the brush through the puzzle).

### 9.4 Registry and menu

- The Binairo entry's `script` becomes `res://puzzles/binairo2d.gd` and it
  gains `"shell": "flat"`. `Registry.shell(entry)` answers "island" for an
  entry without one.
- A second entry `binairo_island` ("Binairo", blurb "The island board, for
  comparison.", `binairo3d.gd`, same motto and footer) keeps the 3D board on
  the menu during the test. It carries `"seed_as": "binairo"`, and the host
  seeds from `entry.get("seed_as", entry.id)`, so both cards show the same
  puzzle on the same day. Analytics still carry each entry's own id.
- `ui/menu.gd` `_open` picks `FlatHost` when the shell is flat, else the
  host it picks today.

### 9.5 `ui/fx2d.gd` (`Node2D`)

Pooled one-shot `CPUParticles2D`: four puffs (five to seven small discs
that rise, drift and shrink over 0.4) and two sparkles (four-point stars in
the caller's colour, over 0.6), picked round-robin; `puff(at, colour)`,
`sparkle(at, colour)`, and `cue(name)` recording the name exactly as
`world/fx.gd` does. Under reduce-motion the emitters do not fire.

### 9.6 The stage while the flat host is open

The menu already unmounts the campsite when a board opens. The flat host
also asks the stage to `show_setting(false)` and hides the stage node, so
nothing 3D is drawn under the opaque page, and restores both on close (the
menu's `_show_list` already calls `show_setting(true)`). The idle frame time
is measured against the island's (10).

### 9.7 Theme and icons

New variations in `ui/theme.gd`: `Wordmark2D` and `WellDone` (section 3, 8).
New icons in `ui/icons.gd`: `tree` (a round crown on a trunk) and `cross`
(the clear chip's mark). The paper wash from `CozyTheme.dress()` lands on
every new panel and button by itself.

## 10. Performance

The island Binairo idles at about 4.95 ms at 1080 by 1920 on this Mac
(handoff, 2026-09-14). The flat screen has no 3D pass to pay for, so its
idle should land at or under 4 ms with the stage hidden; if the idle blinks
and ray turns cost more than a millisecond together, the ray turn goes
first. Draw calls are not the bill here; canvas items batch. Both numbers
are taken with the animation probe (11) and written into the plan's final
report.

## 11. Verification

No test files, per the user's rule. What is done instead:

- A throwaway harness in `/tmp` screenshots the flat screen at 1080 by 1920
  after its entrance, mid-game with a brush armed and a broken line, and in
  the win state; the frames are looked at beside the reference.
- `tests/_shot_anim.gd -- binairo` captures the entrance, a tap and two
  seconds of idle, and prints the idle mean; the same run against
  `binairo_island` gives the number to compare.
- `tests/_win.gd` run windowed still solves every board, the flat one
  through `cell_to_local`.
- The existing suite runs and stays at zero failures.
- The island Binairo is opened once from its card and looks exactly as
  before.
- The phone build goes through the existing GitHub Actions run when the
  user chooses to push.

## 12. Files

New: `puzzles/binairo_state.gd`, `puzzles/binairo2d.gd`, `ui/faces/face.gd`,
`ui/faces/sun_face.gd`, `ui/faces/moon_face.gd`, `ui/faces/sprout_face.gd`,
`ui/flat/flat_host.gd`, `ui/flat/flat_top_bar.gd`, `ui/flat/flat_day_card.gd`,
`ui/flat/symbol_tray.gd`, `ui/flat/flat_actions.gd`, `ui/flat/tip_card.gd`,
`ui/flat/well_done.gd`, `ui/fx2d.gd`, `docs/art/concept-binairo-flat.png`.

Modified: `ui/puzzle_host.gd` (the `_build_chrome` extraction and
`seed_as`), `ui/menu.gd` (host by shell), `ui/registry.gd` (the two entries
and `shell()`), `ui/theme.gd` (two variations), `ui/icons.gd` (two icons),
`core/palette.gd` (seven colours), `core/motion.gd` (two recipes),
`CLAUDE.md` (a note that the flat Binairo is a test beside the island and
departs from the sign rule on purpose).

Untouched on purpose: `puzzles/binairo3d.gd`, every other board, `world/`.

## Amendments (2026-09-18, after the mock)

The design was built first as a playable canvas mock,
`docs/brainstorm/concepts.html#binairo`, and approved by the user as shown
("perfect, build it into godot"). The mock is the visual reference for the
Godot build; where it and the sections above differ, the mock wins, and the
differences are these.

- **Section 8 is replaced.** The board does not stay where it is. On the win
  the top bar and the day card fade and slide up 60 over 0.25; the palette,
  actions and tip card slide down 100 and fade over 0.25; the board card
  slides down over 0.45 (sine in-out), its top from 380 to 680 and its
  bottom up to sit 20 above the stats card, so the grid keeps nearly its
  size. The freed top 640 takes the illustration, sliding down from 200
  above over 0.4 with the back ease, 0.2 after the win starts: the sun
  (radius 130, rays to 200) at (470, 270), the moon (radius 105) at (610,
  330) in front of it, leaves at (250, 300) and (830, 300), three stars,
  "Well done!" centred at y 548 and "Perfect balance!" at 622. The stats
  card and Back to camp slide up from 120 below over 0.35, 0.35 after the
  win starts; the stats card is the day card's look with "m:ss · N moves ·
  N hints" at its right.
- **Section 3.** The day card's type is `CardTitle` (40) over `CardBody`
  (30) in `TEXT_DIM`, not `CardBlurb`. The tip card's text is 32 px, not 28.
  The wordmark is centred between the back button and the undo button, so
  it stands left of the screen's centre, as the carved sign does today; the
  user saw this in the mock and kept it. Check's label is white on the sun,
  as the reference has it.
- **Section 4.** The sun's radius is 0.26 of the tile (rays to 0.8 of it);
  the moon's outer radius 0.34 of the tile, its bite a circle of 0.78 R
  centred 0.62 R toward the upper right, its face on the lower-left body at
  0.62 R scale, centred at (-0.34 R, 0.3 R). The deeper shade sits 0.07 R
  below and the shadow 0.16 R below, both bitten 0.04 R deeper than the top
  so their edges hide under it. Resting faces have open eyes with a
  catchlight and blink; the reference's closed happy arcs appear on a
  completed line, a hint and the solve. The palette chips carry the same
  faces at radius 34 (sun) and 45 (moon). Faces are drawn with antialiased
  primitives, and a filled polygon gets an antialiased outline in its own
  colour rather than turning MSAA on for the whole 2D canvas.
- **Section 6.** The tap's outgoing face shrinks with a quarter turn over
  0.12 from the release; the incoming face pops from 0.08 after it. A hint's
  face drops from 40 above over 0.3 instead of popping. Under reduce-motion
  the outgoing face vanishes at once and the incoming one appears at once.
- **Section 11.** The win harness reads `n`, `_given`, `_solution` and
  `cell_to_local` off the board and `top_bar.hint_button` and
  `action_bar.check_button` off the host; the flat board and host keep
  those names so `tests/_win.gd` and `tests/_shot_anim.gd` need no change.

## Built (2026-09-18) and measured

Built on `feat/binairo-flat` as `e3b3d44` (the feature) and `60a097b` (the
faces as meshes). Two things the build changed against the sections above:

- **Section 4, the faces' drawing.** A face drawn live from fifty antialiased
  primitives cost the board 4 ms a frame: on gl_compatibility every canvas
  draw command is its own render object. Each face layer is now built once
  into a 2D `ArrayMesh` with vertex colours and a 1.5 px alpha-0 feather rim
  for its edges, cached by kind, size (to 2 px), expression and eye level
  (four levels for the blink), and drawn with one `draw_mesh`: three for a
  sun (shadow, rays under the spin transform, body), one for a moon or the
  sprout. A 6x6 board idles on 24 meshes. MSAA stays off.
- **Section 9.6 and the harnesses.** HUD panels' outer rects now ignore
  input (`ui/hud/panel.gd`): during the entrance a neighbour's displaced
  buttons lie over them, and `tests/_win.gd` found the tip card swallowing
  the tap on Check. The win harness also solves `binairo_island` and accepts
  the flat host's scheduled win as its overlay.

Section 10's numbers, this Mac, 1080 by 1920 windowed, vsync off, mean over
2 s of idle after a tap:

| Board | frame | render CPU | objects | draw calls |
|---|---|---|---|---|
| Flat Binairo, faces as live primitives | 8.44 ms | 3.40 ms | 1449 | 651 |
| Flat Binairo, faces as meshes (shipped) | 2.43 ms | 0.67 ms | 193 | 126 |
| Island Binairo | 4.33 ms | 1.86 ms | 817 | 716 |

Verified: the suite at 2086 checks and zero failures; `tests/_win.gd` at
fourteen of fourteen boards solved through touch, both Binairo cards among
them; thirty headless checks across tap, undo, both brushes, hint lock and
reset unlock, the tip card's rule, check, the win layout, a new puzzle after
a win and Back to camp restoring the stage; screenshots of the fresh board,
a broken line with the moon brush armed, the win screen and the 8x8 board
beside the mock.

Amendment (2026-09-18, in play): every free cell is plain `SURFACE` white,
whether empty or filled by the player; the checker of two creams in section
4 is gone and `TILE_LIGHT` with it. Givens keep their sand. The user asked
for it on the first run of the real screen.

Amendment (2026-09-25, every flat board): the win invites the next level
up. When a harder level of the same card is still unsolved today, a full-width
row sits between the stats card and Redo / Back: "Try Hard" with the level's
own line, on the sun (Insane in the night's slate, as on the difficulty
sheet), and a chevron. Back steps down to paper while the invite is shown.
It offers the first harder level not solved today, so a solved Hard is
skipped and the invite goes to Insane, and it offers nothing after Insane
or when every harder level is done; then the screen is exactly as before.
The bottom slot grows from 270 to 420 (a 130 row and a 20 gap) only when
the invite is up. Pressing it fires `next_level` (puzzle_id, difficulty,
to) and `play_level(difficulty)`; the menu frees the host and mounts a
fresh one at that level, without stopping at the list, because a level can
change the board's size and its day card line.
