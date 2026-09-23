# The first screen, flat — and the legacy split

**Date:** 2026-09-18
**Mock:** `docs/art/concept-menu-flat.png` (the user's), playable at
`docs/brainstorm/concepts.html#menu`
**Replaces:** the campsite menu (`docs/superpowers/specs/2026-09-16-low-horizon-design.md`
and the menu sections of `2026-09-14-binairo-hud-design.md`)

## 1. What this is

The campsite goes and a page of cards takes its place. Twelve boards in a
grid of three, a day row over them, a bottom bar under them, and the
wordmark drawn in ink rather than extruded in wood.

At the same time the whole 3D game — the camp, the thirteen island boards,
How Big?, the toon pipeline, the stage and every model — moves to `legacy/`
and stays reachable behind the bar's **More** tab. Nothing is deleted.

Decided with the user on 2026-09-18:

| Question | Answer |
|---|---|
| What happens to the 3D | All of it moves to `legacy/`, all of it stays reachable |
| How many cards | **Twelve**, not the nine that have flat boards |
| The other three | Pipes, Horse Pen and Snake Apple, drawn as **soon** cards |
| What draws a card's picture | The flat boards' own cast (`ui/faces/`), never an image |
| Hearts, calendar badge, day chevron | **Decoration.** They count and lead to nothing |
| Bottom bar | Drawn with four tabs; Home and More work, Stats and Streak do not |
| Where the old game is reached | The **More** tab |
| How Big? | Moves to legacy with everything else |

## 2. The screen

Sizes are the game's own 1080-wide design space, at 1920 tall.

| Row | Height | What is in it |
|---|---|---|
| Header | 380 | Settings and calendar top right; `Daily` at 140 with a golden sun for the dot of its i and the sprig growing out of the a beside it, the two-line motto under; the sun-and-moon pair at the right, at 190 and 166. |
| Day row | 180 | A tree on a pale plate, `Day N` at 56 over the day's name at 38, three hearts, a chevron button. |
| Grid | 1070 | Twelve cards, three across and four down, 320 by ~252 with a 20 gutter. |
| Bottom bar | 150 | Home, Stats, Streak, More. |

Margins are the HUD's 40, gutters its 20, and the bar sits above the
safe-area inset `ui/safe_area.gd` gives every screen.

**The heights are a budget, not a taste.** 1920 less 80 of margin, 60 of
gaps, 180 of day row and 150 of bar leaves 1070 for four rows: 252 a card.
A card spends that on a 92 picture, a 34 name, two 23 blurb lines and a 16
inset — which is why the card carries its own paper stylebox rather than
`CozyTheme.paper_card()`, whose 24 inset and the mock's 118 picture came to
277 a card and pushed the bar off the bottom of the screen. Any change to
the header, the day row or the bar comes out of the picture.

**The menu paints its own page.** The campsite used to fill the frame, so
the old menu never drew a background and the viewport's clear colour — the
stage's sky — filled the gaps. With no stage there is nothing behind this
screen, so `_build_list` lays a `Pal.PAPER` ColorRect under everything.

## 3. The twelve cards

Each card's picture is `ui/menu/card_art.gd`: a Control that seats the
board's own characters in a 320 by 118 box and scales them to the card. It
is never an image, never a render of a model (CLAUDE.md, "never bake a model
down to an image") and never a `SubViewport`.

| Card | Picture | From |
|---|---|---|
| Binairo | the sun and the moon, overlapping | `sun_face.gd`, `moon_face.gd` |
| Code Break | three friends on a wooden tray | `friends.gd` |
| Balance | two fruit riding a tilted beam | `fruit.gd` |
| Untangle | four lanterns, two cords crossing | `lantern_face.gd` |
| Shikaku | a five-by-three field, two plots ruled off | `marker_face.gd` |
| Tents | a tent between two conifers | `tent_face.gd`, `conifer_face.gd` |
| Light Up | a lamp lighting its row, a block with its count | `court_lantern.gd` |
| One Line | the snail mid-stroke on four posts | `snail_face.gd` |
| Nonogram | a three-by-three of the picture with its clues | drawn (the tiles are builder shapes, not a Control) |
| Pipes | an elbow of pipe over two blocks | drawn |
| Horse Pen | a bale and a horse | drawn |
| Snake Apple | the worm reaching for an apple | drawn |

A new card costs one branch of `_build` and, if it needs furniture under the
cast, one of `_draw`. Its name takes the shared rounded title face and the
golden sun over every lowercase i. That is the diorama's bargain without the
`World3D`.

**A `soon` card** keeps its picture and its name at 55% ink, wears a pale
`SOON` pill over the picture's top-right corner, has no go button, and emits
`blocked` rather than `open` — the menu answers with a line saying where its
island version is. The pill hangs off the card, **not** off `_inner`: that
is a PanelContainer, and a second child there is stretched to fill the card
and hides everything under it.

The three sit together as the last row on purpose. Three dimmed cards
scattered through the grid read as a bug; three in a row read as a roadmap.

## 4. The day row, the hearts and the calendar

`Day N` and the day's name come from `core/progress.gd`, which already has
both. **Everything else on the row is a picture of a feature that does not
exist**: two hearts filled of three, a `1` badge on the calendar, a chevron
that squashes and does nothing. This is written here, in the code comments
of `day_row.gd` and `menu_header.gd`, and on the concept page, so that
nobody later reads a progression system into a drawing of one. There is no
three-a-day goal, no streak health and no lives.

What the hearts should count is the next thing this screen needs designed.

## 5. The legacy split

### 5.1 What moved

```
legacy/core/     stage_view, stage_board, turn_base, toon, models, lettering,
                 placeholders, platform, shapes, board_math
legacy/world/    the whole stage: ambient, backdrop, camera_rig, camp, fx,
                 mascot, scenery, soft_focus, stage(.gd/.tscn)
legacy/puzzles/  the nine islands, pipes_iso, horse3d, rope3d, snake3d and
                 the four generators only they use
legacy/turns/    how_big.gd
legacy/ui/       island_host, turn_host, camp_menu (was ui/menu.gd)
legacy/ui/hud/   top_bar, day_card, help_card, action_bar, line_card,
                 palette_tray, peg_button, piece_tray, status_card,
                 puzzle_card, sign_view, model_view, card_scene, title_view
```

`ui/hud/` keeps what both shells share: `panel.gd`, `icon_button.gd`,
`sheet.gd`, `settings_sheet.gd`, `rules_sheet.gd`.

### 5.2 The two knots, and why cutting them was the point

A folder move alone would have been a label. Two things tied the live 2D
game to the 3D stack, and both are cut:

**`core/puzzle_base.gd` extended `StageView`.** Every flat board inherited
stage mounting, camera fitting and board-plane ray picking it never called.
`PuzzleBase` is now a plain `Control` holding the board contract and the
counters. The island boards extend `legacy/core/stage_board.gd`, which
carries `StageView`'s machinery and **a frozen copy of the contract**.

The copy is deliberate. GDScript is single-inheritance and those boards need
the stage underneath, which the flat boards must never load. A frozen copy
also means a later change to the live contract cannot break thirteen retired
boards. `class_name StageView` is gone with it: nothing live should be able
to reach the stage by a global name.

**`ui/flat/flat_host.gd` extended the island host.** `ui/puzzle_host.gd`
built the island rows itself, and the flat host inherited and overrode them
— so every flat board loaded the carved sign, which loads the model views,
which load the whole toon and model pipeline. The host is now shell-neutral
(setup, the board slot, the sheets, the spawn, the analytics, every
handler); `_build_chrome` and `_enter` are the two methods a shell fills,
and there are two shells: `ui/flat/flat_host.gd` and
`legacy/ui/island_host.gd`. Neither is the default — a host with no chrome
pushes an error rather than falling back.

One smaller thread: `ui/fx2d.gd` borrowed `world/fx.gd`'s star texture. It
owns its own now, a twelve-line duplicate, on the same reasoning.

After the cut, **nothing the first screen can reach loads a line from
`legacy/`**, and retiring the folder later really is deleting it and its
`Registry.LEGACY` entries.

### 5.3 The registry

`Registry.PUZZLES` is the grid: twelve entries in drawing order, the nine
flat ones and the three `soon`. `Registry.LEGACY` is the old game: the nine
`*_island` boards, `pipes_island`, `horse_island`, `snake_island`, `rope`
and `how_big`. Pipes, Horse Pen and Snake Apple were renamed to `*_island`
so the grid could take their plain ids; each keeps `seed_as` at the grid's
id, so the day's puzzle does not move when one of them is drawn flat.

A grid entry gains `short`: the card's own two-line blurb. At 320 wide a
card fits about seventeen characters a line, which the registry's longer
`blurb` — still what the rules sheet and the legacy menu show — does not.

### 5.4 The stage, on demand

`world/main.tscn` no longer carries a `Stage`. The first screen and the nine
flat boards never build a `World3D` at all. Picking a line in the More sheet
calls `ui/menu.gd`'s `_raise_stage`, which instantiates
`legacy/world/stage.tscn` beside the UI canvas; closing the host frees it.

The last row of the sheet is **the campsite menu itself**, so the screen the
game used to open on is still reachable rather than merely still on disk.
Opened that way it is `embedded`: it draws a back button it never needed as
the root screen and emits `closed` like any host, and its cards are
`Registry.LEGACY`.

## 6. Motion

| Moment | What happens |
|---|---|
| Entrance | The wordmark lifts in, its sprig grows, and the sun and moon rise a beat apart while the utility buttons scale in quietly. The day row drops in at 0.1; the cards rise 60 in reading order, 0.05 apart capped at 0.4; the bar comes up last at 0.5. |
| Idle | The sun's rays turn once in 40 s and the moon rocks, as on Binairo's board; the small sun on the i turns with them and glints every 3.5 to 6.5 s, its rays flaring and a pale shine rising and fading over the boards' flash timings. Nothing else moves; the campsite's wind and pollen do not come here. |
| Press | The card squashes 6% and its paper darkens. A `soon` card squashes 3%. |
| Reduce motion | All of it instant and still, through `core/motion.gd` as everywhere else. |

## 7. Measured

On this Mac at 1080×1920, `tests/_shot_menu.gd`:

- **291 draw calls**, against the campsite's 338 and the 855 budget.
- **8.33 ms mean idle** — which is exactly the 120 Hz vsync cap, so the true
  cost is *at most* that and the number is a ceiling, not a measurement. The
  point that can be made honestly: the campsite measured ~13 ms, above the
  cap, and this screen is inside it.
- `tests/_win.gd`, windowed: **9/9** flat boards still win.
- The suite: **2086 passed, 0 failed**, the same count as before the move.

Still owed: a look at the 252-tall card on a real phone. Two blurb lines fit
where three do not; whether two are enough to tell twelve puzzles apart is a
device question, not a browser one.

## 8. What was given up

The campsite is the best-looking screen the game has had: painted, lit,
framed by a shift lens, with an animated scout, grass that blows in a gust
and a live diorama of real pieces in every card. Cards on cream cannot
answer that, and this document should not pretend otherwise — the trade is a
picture for a product. Three things bought it:

1. The first screen should look like the game. Nine of twelve boards are
   flat cream screens; a painted 3D camp in front of them promises something
   that is no longer behind the cards.
2. Twelve cards do not fit a hero. The camp wanted a strip 250 tall at the
   least, the cards want 1070 of 1920, and pages of nine were the
   compromise. Flat, the whole registry stands on one screen and the pager
   goes with it.
3. A page of nine dioramas was 318 draw calls, each in its own SubViewport
   with its own World3D.

The camp is not deleted, and More is a real door. But nobody will see it by
accident again.

## Amendment, 2026-09-23: the page is fitted to the screen

A fixed three by four left a 9:20 phone with a ~530 px empty band under
the grid, and nothing turned the page but the chevrons. `ui/menu.gd`'s
`_fit_grid` now fits columns of 320 and rows of 252 to whatever room the
header, day row and bar leave, grows each picture up to 118 with the
spare height and then opens the row gaps; a screen that holds every card
gets one page. Row gaps may close to 16 (the day row is 188, not 180). A
horizontal swipe on the grid turns the page. The 1080x1920 page is
unchanged: still twelve cards, 3x4.


## Amendment, 2026-09-23: the done seal

A finished card wears a check seal, not a DONE pill: a 46 green disc with a
cream check, set in a 4 px paper ring, pinned over the top right corner of
the picture and hanging 9 past it on both edges. It has no word on it. The pill
sat over the picture itself (it was placed 14 from the card's corner, but the
picture starts 16 in) and cut into Code Break's pouch, Nonogram's clues and
Word Trail's tiles; at that size its check read as a square root; and a
page of eleven green pills read louder than the one card still to play. The
seal is drawn on a layer inside the picture's plate, so it squashes with the
card when pressed. It costs two draw commands a card, not three, so
page one went from 390 to 379 with eleven cards done (`tests/_shot_menu.gd`
at `810x1440`, two readings each).
