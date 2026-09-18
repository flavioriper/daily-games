# Balance, flat: the third screen on trial

Status: built and measured, 2026-09-18. Concept page:
`docs/brainstorm/concepts.html#balance`. Sibling specs:
`2026-09-18-binairo-flat-design.md`, `2026-09-18-codebreak-flat-design.md`.

Balance is visual simultaneous equations: three to five kinds of thing with a
hidden weight from one to nine, a stack of scales that are each a true
statement, and one weight given so the scales pin down values rather than
ratios. Every beam tilts live under the guess, so **the board is its own
check** — there is nothing to submit.

This is the board the flat view should win on most clearly. A tilt is an
angle, and an angle read through the island's seven-degree camera is an angle
plus a lie. If the flat view does not win here it probably does not win.

## 1. What was built

| File | New? | Job |
|---|---|---|
| `puzzles/balance_state.gd` | new | The rules, scene-free. |
| `puzzles/balance2d.gd` | new | The flat board: the column of scales. |
| `ui/flat/weight_tray.gd` | new | The row of weight cards. |
| `ui/faces/fruit.gd` | new | The one list of the five fruit. |
| `ui/faces/pear_face.gd`, `pumpkin_face.gd`, `mushroom_face.gd` | new | Three new faces. |
| `ui/flat/flat_top_bar.gd` | edit | An optional fifth button, Reset. |
| `ui/flat/flat_host.gd` | edit | Optional actions row, measured bottom slot, `card_height`, the weights tray. |
| `ui/flat/well_done.gd` | edit | Labels under a cast, and a cast that closes up to fit. |
| `ui/puzzle_host.gd` | edit | Two guards for a screen with no action bar. |
| `ui/icons.gd`, `ui/theme.gd`, `core/palette.gd`, `core/motion.gd` | edit | `minus`/`plus`, two label variations, the fruit and scale colours, `Motion.bump`. |
| `ui/registry.gd` | edit | `balance` goes flat; `balance_island` keeps the island board. |
| `tests/_win.gd` | edit | A flat solver, and the island's moved to `balance_island`. |

**Two of the five fruit were already drawn.** The apple is `berry_face.gd` —
the Code Break mock's `berryP` and the Balance mock's `appleP` are the same
drawing number for number, and `Pal.BERRY` is `#e2645c`, the mock's apple
colour — so Balance names that fruit an apple and draws the class that
exists. The acorn is Code Break's own. That reuse is the point of having a
cast; the design had budgeted four new faces and needed three.

## 2. The rules (`balance_state.gd`)

Move for move the island's, with no scene in it: `secret`, `scales`,
`anchor`, `guess`, `locked`, `history`, and `step` / `undo` / `reset` /
`hint_shape` / `apply_hint` / `lean` / `is_level` / `is_solved`. The island
(`balance3d.gd`) still carries its own copy until the 2D-or-3D verdict, as
the standing rule has it; whichever board survives, this is the one truth to
keep.

Two deliberate differences from the island's private helpers:

- `lean(i)` is **left total less right**, the mock's sign, because that is the
  drawing these numbers have to match. The island's `_diff` is the other way
  round. Only the convention differs.
- `step(i, delta)` is the island's `_add` and `_remove` in one method, since
  the flat card's minus and plus are one gesture with two signs.

The island's own choices are kept: a hint prefers a kind the player has
wrong, drops that kind's entries from the history, and stays spent through a
reset; a reset leaves hinted weights locked.

## 3. The scale and the fruit

Ported number for number from the mock, in art units scaled by
`_art = min(1.15, band / 250)`: a 600-wide beam (`ARM` 300) on a post with a
carved base, a dish on cords at each end, the side's fruit in the dish.
`TILT_CAP` 3, `TILT_MAX` **0.22 rad** (*not* the island's 0.26), `TILT_TIME`
0.42 with the back ease's overshoot. One unit tips a third of the way, three
or more tips all the way and no further.

The dishes are children of the band, **not of the beam**: they hang on cords,
so they stay level and upright, and placing them from the beam's angle each
frame is simpler and steadier than a second tween counter-turning them —
the island's own reason for doing the same.

A weight is a numeral and never a size. The fruit are all drawn at one size
whatever they weigh, because the puzzle is about what you cannot see. Faces
answer the beam and never the answer: the low dish strains (`Expr.WORRIED`,
the nearest thing the shared face vocabulary has to the mock's `strain`), the
high dish stays content, and both beam for 0.9 s when the beam comes level.

**The wood is cached meshes, not canvas commands.** gl_compatibility pays per
draw command, so a scale is four `draw_mesh` calls (stand, beam, two dishes)
rather than a dozen rounded rectangles, and every band on the board shares
the same three meshes through a static cache keyed by shape and art scale.
Filled shapes take the `Face.Builder` feather, since MSAA stays off for the
2D canvas.

## 4. The weight cards

One card per kind, sharing the column: the fruit at y 62, the weight as a
62px numeral centred on y 150, and a wide minus and plus at y 196. The given
kind's card is sand with a sun rim, its numeral dimmed, reads `GIVEN`, and has
no buttons. A button whose direction has run out drops to 35 percent but
still takes the press.

**Which side owns a refusal.** The tray knows from `can_minus` / `can_plus`
that a press will be refused, so it shivers the card itself; the board is
told either way and owns the sprout's reason, since only it has the words.

The card keeps the shared paper wash `CozyTheme.dress()` gives every Panel, as
the day card and the tip card beside it do; only the board card opts out.

## 5. The chrome, and the one structural departure

Top bar 180 (back, undo, **reset**, hint, settings), day card 120, board card
to the band cap, weight cards 230, tip card 140. **No actions row and no
Check**: `capabilities()` is `["undo", "hint"]`, the island's own set, and the
island's own comment already explains why — a button that read the board for
you would be the puzzle. With nothing else to put in the row, the row goes
and Reset rides up into the top bar.

That cost three small changes to shared chrome, all defaulted so the other two
screens are untouched: the registry may say `"actions": false`; the top bar
takes a third constructor argument; and the host measures its bottom slot from
the rows it actually built, because the three screens no longer agree on its
height (460, 460, 390).

A board may also ask for less of the board slot than it was given. Balance
caps its bands at 340, so a short column leaves the rest as air **above** the
weight cards — a gap under the day card would read as a mistake, a gap above
the cards reads as room. That is a fifth optional board hook,
`card_height(available)`, beside the documented `palette()`, `tip_line()`,
`flat_win()` and `win_delay()`.

Measured: easy is 2 scales in a 736-tall card, medium 3 in 1076, hard 4 at a
258-tall band filling 1090 — 736 is the number the concept page predicted.

## 6. The tip card and the win

`tip_line()` reads the scale it is pointing at out loud — "Two apples weigh
the same as one pumpkin." — cycling every 8 s on the board's own Timer through
`focus_changed`, and speaking up when a press is refused. The sentence is
composed in the board (it needs both the state and the fruit's plurals);
the plurals live in `fruit.gd`.

The win keeps the board on screen with every beam level, and puts the five
kinds with their true weights above it. `well_done.set_cast` grew an optional
`labels` array for that. It also grew a cap: at the full 190 pitch five faces
run out into the leaves and the outermost star, so a cast wider than
`CAST_SPAN` (800) closes up and its faces shrink, and the decoration on the
right steps aside. Code Break's four (760) are inside the span and unchanged.

## 7. Deviation from the mock, stated

**Reset does not unwind a unit at a time.** The mock walks every unlocked
weight down to one on a 0.05 s timer, so the column visibly unwinds. Here the
state resets at once and each *beam's* swing is staggered by its band
instead, so the change still reads down the board from the top. Mutating the
guess asynchronously would have raced with input for a cosmetic gain.

## 8. What was verified

- Suite `passed=2086 failed=0`, unchanged from `main`. (The pre-existing
  swallowed error in `test_models.gd:146` is on `main` too.)
- Win harness **16/16** windowed, including `balance` driven entirely through
  real touches on the real minus and plus buttons, and `balance_island`. Both
  report the same weights, so `seed_as` ties them to one day.
- Board fit: every dish lands inside the card the board asked for, at all
  three difficulties — what `TILT_MAX` and the band cap exist to guarantee.
- Idle cost at the hard difficulty, this Mac at 1080x1920: **262 draw calls,
  8.33 ms**. Flat Binairo measured the same way is 264 calls and 6.90 ms, so
  Balance costs the same in calls and about 1.4 ms more. Against the 855
  budget this is not close.
- Reduce-motion: no tween anywhere, beams sitting at their exact computed
  angles (`-0.22` saturated, `0.0` level, `0.073` one third), refusals still
  spoken.

Three defects were found by looking at rendered frames rather than by
reasoning, and are worth recording because each would have shipped:

1. The entrance tween captured each band's rest position before the card had
   its real height, then held it there, stacking every scale on the first.
   Fixed by giving the entrance its own node inside the band — the reason
   `ui/hud/panel.gd` separates `_inner` from the panel.
2. A weight card only restyled itself when its given-ness *changed*, so a
   card that is never given never got a stylebox and drew as a bare dark
   Panel.
3. A `Label`'s height clamps up to the line height its font needs (76px for
   the 62px numeral), which moved the numeral's centre 18px down onto the
   buttons. The box is now measured first and then hung on the mock's y.

## 9. Still to judge, on the phone

- Does a flat beam beat a stone beam in perspective? The question the screen
  exists to answer.
- Four buttons in the top bar against three on the other two flat screens.
  One constructor argument, cheap to reverse.
- Five kinds at 218px a card: the five silhouettes do read at that width in a
  rendered frame, but that is this Mac and not a phone in a hand.
- Whether `GIVEN` is needed now that the card is sand, rimmed in sun and has
  no buttons.
- Whether the sprout reading one scale at a time teaches, or whether the
  scales are already sentences and the card should say something else.
