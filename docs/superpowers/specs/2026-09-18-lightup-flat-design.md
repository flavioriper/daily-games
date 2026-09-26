# Light Up, flat: the seventh screen on trial

Status: built, 2026-09-18. Concept page:
`docs/brainstorm/concepts.html#lightup`. Sibling specs:
`2026-09-18-binairo-flat-design.md`, `...-codebreak-`, `...-balance-`,
`...-shikaku-`, `...-untangle-` and `...-tents-flat-design.md`.

Akari: set lanterns in a walled court so every floor stone is lit, no lantern
lights another, and each numbered block touches exactly its number of
lanterns.

## 1. What flat buys here, honestly

**The floor, and the beam.** Light Up has no marker for its main condition: a
stone no lamp reaches is a cold grey, a lit one is warm, and that is the whole
of "every stone must be lit". So the thing the player reads is a *field of
flat tints* — up to 35 of them on a hard court.

- **The floor is the display, and the floor is what a tilted camera ruins.** On
  the island that field is seen at seven degrees, where the far rows are a few
  pixels tall, foreshortened, and half in the shade of the blocks standing in
  front of them: precisely the information you look at most, rendered worst.
  Square-on, every stone is the same size and the same tint wherever it sits.
- **The island already had to fight for it once.** `core/palette.gd` records
  the first pass: unlit stone at `b4ab97`, one and a half stops off lamplight,
  and the toon ramp ate the whole difference under the island sun. The fix was
  to push the pair nearly three stops apart and cool the dark end. That margin
  was bought to survive a lit 3D ramp; flat, the same two colours are simply
  the two colours.
- **And it buys the beam.** Flat can draw the shaft of light itself down the
  row and the column, cell by cell as it travels, which is the rule made into a
  picture: you see exactly how far a lamp reaches and exactly what stopped it.
  The island casts light onto the floor stones and no further, because a
  visible beam at seven degrees is a smear across the court.
- **What it costs is the court.** The island's version is a real place with
  rough stone standing in it and lamplight pooling on flagstones, and that is
  more atmospheric than tinted tiles on parchment. This screen trades a lit
  room for a legible diagram. Whether that is the right trade for a puzzle
  whose difficulty is entirely in the reading is section 9's first question.

## 2. What was built

| File | New? | Job |
|---|---|---|
| `puzzles/lightup_state.gd` | new | The rules, scene-free: the grid, what is on each stone, how far each lamp reaches, and every gesture that changes it. |
| `puzzles/lightup2d.gd` | new | The flat board: the court, the beams, the blocks, the chips, the gesture and the sprout's lines. |
| `ui/faces/court_lantern.gd` | new | The lamp: Untangle's paper lantern with the cord and tassel off it and an iron foot under it. |
| `core/palette.gd` | edit | The four bottom edges the flat court needs, and its own lit stone (section 3). |
| `ui/registry.gd` | edit | `lightup` goes flat; `lightup_island` keeps the island board, seeded from the same day. |
| `tests/_win.gd` | edit | One driver solves both boards. |

The generator is untouched. `puzzles/lightup_gen.gd` — the greedy placement,
the uniqueness search and the clue stripper — is the island's, and both boards
run the same ladder (5×5 at 24% blocks, 6×6 at 22%, 7×7 at 20%), so a day
lights the same court on each.

## 3. The state is the one truth, with two deliberate differences

`lightup_state.gd` is `lightup3d.gd`'s logic ported, except that:

- **A gesture is a move, not a tap.** The flat board sweeps a run of chips in
  one drag, so the history records a *list* of stones rather than a single one.
  Measured: a six-stone sweep is `moves=1`, `history=1`, and one undo clears
  all six. This is Tents' answer carried across unchanged; two of the seven
  screens now rule cells out by the handful, with the same finger movement.
- **A tap is one state, not a cycle.** Whatever is on the stone comes off, and
  a bare stone gets a lamp. The island cycles blank → lamp → chip → blank,
  which costs two taps for every chip.

The win test is the generator's own three conditions rather than a comparison
with the stored answer — clues exact, no two lamps in sight of each other,
every stone lit — exactly as the island tests it. `lit` (how many cells of
beam the nearest lamp is away) lives in the state rather than the board,
because the travelling wave staggers on it and the blocks' counts read from
it: it is a fact about the puzzle, not about the drawing.

**Two colours had to change, and the palette says why.** The flat court cannot
use the island's `LAMPLIGHT` for a lit stone: the beam is drawn *over* the
stone in the lantern's own `LANTERN_LIT`, and the two are within nine values of
each other, so the shaft vanished into the floor — measured on a rendered
frame, the band came out 4/10/22 per channel over the stone it crossed, about
3% in luminance. `LAMPLIT_FLOOR` (`f6d488`, the mock's own) is a shade more
saturated, and the beam went white at 0.45 rather than `LANTERN_LIT` at 0.34;
the band now measures 4/19/51. Those two numbers are the only place this board
does not take the mock's paint literally, and they were changed because
otherwise section 1's third bullet is a claim the screen does not keep.

## 4. The cast is one character

The lamp is `ui/faces/court_lantern.gd`, a subclass of Untangle's
`lantern_face.gd`: same seat, same halo, same mesh cache, with the cord and
tassel removed and an iron cap and foot added. The seventh flat screen adds no
new species.

What changes is what `lit` means. On Untangle the light was the reward at the
very end; here it is the state — a lamp you set down is burning — so a court
lamp is drawn lit from the moment it lands. Two more states ride on the
drawing: `bad` (a lamp that can see another) blushes and strains, and it is
*both* lamps, because neither is more wrong than the other; `pinned` (a lamp a
hint lit) wears green iron and a green arc at its foot, the language every
board uses for a given. Both are in the cache key, so ten lamps still share
one mesh per state.

The blocks are not characters. They are drawn into the court's mesh, plain, and
they carry no face — half of a generated court's stone says nothing at all (the
stripper removes every clue it can while the answer stays unique), and a blank
block is information too: it stops the light.

## 5. What the board says, and what it will not

Two of the three rules are shown where they break. A lamp that can see another
blushes rose and strains. A numbered block goes green the moment it touches
exactly its number and rose the moment it touches too many. The third rule —
every stone lit — needs no marker: the cold stones are the ones still to do,
and their count is the sprout's line.

**Nothing draws which lamp lit which stone.** The beam shows reach, not
ownership, and a stone lit twice looks exactly like a stone lit once. That
matters because the deduction in Light Up is about *which* lamp has to be the
one.

A block with no number never goes green — not while playing and not on the
win. It has nothing to be satisfied about.

## 6. The gesture

- **Tap** sets a lamp down, takes one up, or clears a chip.
- **Drag** sweeps chips. The direction is read off the stone the drag started
  on: begin on a chip and the sweep clears, begin anywhere else and it lays.
  The board also fills in the stones *between* drag events, which the mock does
  not: holes in a swept run would be a phone-only defect.
- **A sweep never disturbs a lamp, a block, or a lamp a hint pinned.** Measured:
  sweeping the length of a lamp's own row leaves the lamp standing and lays
  chips around it.
- A tap on a block or on a pinned lamp is refused with a dip and a line from
  the sprout rather than a move.

## 7. The screen

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `LIGHT UP` with the leaf, `LET THERE BE LIGHT`, then Undo, Hint and Settings. |
| Day card | 120 | The day and its name. |
| Board card | cut to the court | The court on parchment, centred in what is left. |
| Actions | 130 | Reset and Check. |
| Tip card | 140 | The sprout and one line. |

The bottom slot is 290: the tip card, the actions row and the gap between them.
There is no clue band to spend width on — every number is carved into a block
standing *inside* the grid — so the cell is the roomiest of the seven flat
boards. Measured at 1080 design width: **186.4 on easy, 155.3 on medium, 133.1
on hard**, capped by the width every time, which is 48 CSS pixels under a thumb
on hard against the 38 Tents had to settle for.

Because the cell is width-capped at every step, the court is square and the
space is tall, the card is cut to the court and **centred** (`card_centred()`,
which Tents added for the same shape). Measured in a 9:16 window: a 1000-tall
card in a 1190 slot, 95 above and 95 below; a taller phone gives it more.

## 8. Motion

| Moment | What happens |
|---|---|
| Entrance | The flagstones fade in on a diagonal from 0.12 s, then the blocks drop onto the court from 0.2 s. |
| Setting a lamp | The lamp pops in from six tenths, and the light **travels**: each stone waits 0.035 s per cell of beam from the lamp, capped at 0.25 s, then warms over 0.22 s. Taking one up cools over 0.3 s. The island's own `LIGHT_STEP`, `LIGHT_CAP`, `LIGHT_IN` and `LIGHT_OUT`. |
| Breaking a rule | The lamp blushes and strains, and a number turns green or rose, on the frame the count changes. Nothing waits for Check. |
| Check | Every lamp the answer does not put there shakes; the sprout counts them. |
| Solved | The lamps hop in reading order a tenth of a second apart, each grinning and throwing sparks as it lands, and the chips clear away, so the last picture is the lit court rather than the working-out. |

Measured 0.09 s after a lamp lands: its own stone at 0.75 warmth, a stone two
cells out at 0.27, the far end of the beam still at 0. Six tenths of a second
later every stone on the beam is at 1.00 and the board reports itself idle.

Two implementation notes worth keeping:

- **The warmth painted so far is what a retarget starts from.** Ask for a lamp
  and take it away again inside the fade, and a single target would carry the
  stone all the way to lamplight and leave it there — a lit floor with nothing
  lighting it. The board keeps `{from, to, at, dur}` per stone and reads the
  current value before changing the target, which is the island's fix.
- **A canvas command holds a mesh by RID, not by reference.** Rebuilding the
  court every frame and dropping the previous mesh leaves the renderer drawing
  a freed RID ("Parameter mesh is null", and an empty card) on any frame
  rendered without a queued redraw being flushed first — which is what
  `RenderingServer.force_draw()` in a harness does. `lightup2d.gd` keeps the
  mesh the last `_draw` handed over in `_shown` until the next one replaces it.
  `tents2d.gd` and `untangle2d.gd` rebuild meshes the same way and do not hold
  that reference; it has never been seen in the game, where every frame flushes
  its redraws first, but it is the same shape of bug.

## 9. Measured

- Suite `passed=2086 failed=0`; win harness `winnable=20/20`, both `lightup`
  and `lightup_island` through real touch events, board fit and HUD checks
  included.
- Draw calls against the 855 budget: **62** on a fresh court, 65 mid-travel, 69
  working, **83** on a working hard court (7 lamps, 6 chips, beams crossing),
  92 at the busiest frame of the win, 66 on the win screen.
- The ladder, sampled: easy 5×5 with 6–7 blocks, 3–5 numbered, 6–8 lamps over
  18–19 stones; medium 6×6 with 9–10 blocks, 5–7 numbered, 7–9 lamps over 26–27
  stones; hard 7×7 with 14–17 blocks, 5–7 numbered, 10–13 lamps over 32–35
  stones.
- By hand: the sweep both ways, one undo taking back a whole run, a sweep
  refusing to disturb a lamp, a tap refused by a block and by a pinned lamp,
  the hint pinning for good, Check shaking the wrong lamps, the chips clearing
  on the win, the board idling the moment its entrance ends, and reduce motion
  putting the whole court up lit with no wave.

## 10. Calls this screen is still for

- **Is a diagram worth a room?** The sharpest version of the flat question yet:
  the island's court is atmospheric and the rule is legible here. Nobody should
  read seven screens as seven wins.
- **Is the beam right now that it can be seen?** It had to be brightened to
  exist at all (section 3). The tinted floor already answers "is this stone
  lit", so the shaft may be the rule made visible or a second voice saying the
  same thing louder. It is the one thing the island cannot do at all, which is
  exactly why it wants challenging rather than assuming.
- **An untouched court is the screen's dullest picture**, and worse than the
  mock predicted: a hard board sampled here opened with three of its seven
  numbers being `0`, so three blocks sit green and settled before the player
  has done anything. That is honest — a zero is satisfied by an empty court, and
  it teaches what green means for free — but the first frame is cold grey stone,
  dark blocks and three green ones.
- **Does the travelling wave slow the board down?** A quarter of a second of
  stagger per move is honest and teaches the rule, but Light Up is a board you
  tap a great deal. Halving `LIGHT_CAP` is the gentle lever; snapping the light
  on is the blunt one.
- **Ten lamps with faces, all lit, all glowing.** Ten halos on a 7×7 court is a
  lot of warm light in one card, and the faces sit on the brightest things on
  the screen. The blocks stayed plain partly for this reason; the lamps may
  still need their glow pulled down.
- **Should a hint pin a lantern for good?** It is the island's behaviour and the
  answer is unique, so it commits the player to nothing false — but it removes
  a stone from the puzzle permanently.
- **Should the court be centred?** The family's rule everywhere else is to pin
  the board under the day card. This is the second board of the seven to break
  it, and the only one where the air is the same above and below at every
  difficulty.

## 11. Amendment: the polish of 2026-09-19

The user asked for Light Up to be polished with proper animations on
Binairo's pattern, smoother and more elegant, and for the pattern to be
kept so the other boards take it. Built straight in Godot, as Code Break's,
Balance's, Untangle's, Shikaku's and Tents' were, with this amendment and
`docs/art/flat-motion.md` as the record. The layout is kept; sections 2 to 7
stand. Section 8's motion is superseded by what follows.

**Nodes in slots over two drawn meshes.** The lamps were already nodes; each
now stands in a slot the layout owns, so the hop, the nudge, the shiver and
the drop never fight a relayout, and takes the vocabulary straight. The
court is drawn as two meshes on one `_anim_until` clock every recipe start
extends: the **floor** (the mortar bed, a stone per cell with its warmth, the
beams), built about the court's centre so its entrance is a draw transform,
and the **ground** (a stone's blush, every shadow, the blocks, the chips),
read off the curve readers. The numbers go through `draw_set_transform` so
they squash, sink, bump and hop with the block they are carved on. Every
move -- a tap, a sweep, an undo, a hint, a reset -- goes through one
`_transition` that diffs a snapshot of the marks against the state.

**The pattern grew here.** Light Up needed the press, the hop, the nudge and
the shiver on drawn things, so `core/motion.gd` gained the readers it was
missing (`press_scale`, `hop_lift`, `nudge_offset`, `shiver_offset`,
`wobble_angle`, with `SHIVER_PX`, `SHIVER_TIME`, `WOBBLE_ANGLE` and
`WOBBLE_TIME` named beside them). Every recipe a node takes now has its
reader, so One Line and Nonogram, both drawn boards, need nothing new from
the vocabulary.

**What changed, moment by moment:**

| Moment | Now |
|---|---|
| Entrance | the court pops in wide (`wide_pop_scale`, `ENTER_WIDE_FROM` 0.86 over `ENTER_POP` 0.25) after `ENTER_DELAY`; each block pops in with the squash (`pop_in_scale`) along the diagonal at `ENTER_STAGGER` 0.03, `ENTER_FACE_LAG` after the court starts, its number and its shadow with it. The stones' diagonal fade and the blocks' 24 px drop are gone |
| Press | a lamp sinks to `PRESS_SCALE` 0.94 (`press`) and springs back; a block sinks too, drawn (`press_scale`); a bare stone or a chip's stone sinks *itself*, drawn, and goes half a step into its own deep colour as it does (`SINK_SHADE` 0.5). Tents' wash was tried first and is invisible on mid-grey stone. Nothing pressed before |
| Place | the lamp pops in with the squash (`pop_in`, `POP_IN` 0.22) in place of its own six tenths; a puff in `SUN`; the blocks and lamps on its four sides lean away `NUDGE` 3 and back (`nudge`, `nudge_offset`); every numbered block it touches bumps (`bump_scale`, the Count moment); the light travels out as before (`LIGHT_STEP` 0.035, `LIGHT_CAP` 0.25, `LIGHT_IN` 0.22) |
| Sweep | the stones under the finger sink as it passes, and on release the chips arrive in a wave along the finger's path at `ENTER_STAGGER`, each stone springing back as its chip lands (`pop_in_scale`, with the squash). No puffs. A rub-out runs the same wave with the pop out |
| Remove, undo | a lamp shrinks to nothing with the quarter turn (`pop_out`, `POP_OUT` 0.12) and a chip does the same, drawn from a leaving list after the state has forgotten it; what comes back pops in. **The beam withdraws with the floor**: a leaving lamp is kept in `_beam_out` and its shafts fade over `LIGHT_OUT` 0.3 as its stones cool, where they used to vanish on one frame |
| Hint | a ring in `LEAF` through `Fx2D.ring`, the lamp drops in from `DROP` 40 above with the fade (`drop_in`), a sparkle in `LEAF`; a chip under it pops out first; the light travels out from it |
| Wrong on Check | the lamp wobbles (`wobble2d`) and its stone blushes toward `BAD_TILE` and settles (`flash_level`), drawn into the ground. The 0.6 s horizontal shake is gone |
| Refused | a block shivers (`shiver_offset`, 0.04 of a cell) and flashes toward its own OVER rose (`BLOCK_ROSE` 0.6 at `flash_level`), which it has where a tree has nothing; a pinned lamp shivers (`shiver`) while its stone blushes; the sprout says why. The dip is gone, and a refused block showed nothing at all before |
| Reset | the chips and lamps pop out in a wave from the far corner at `RESET_STAGGER` 0.02, the blocks hop `RESET_HOP` in the same wave (`hop_lift`), the numbered blocks beside a leaving lamp bump, and the light cools in the same wave (`_relight` takes a delay per stone). Everything used to vanish at once |
| Solved | every lamp and block hops `SOLVE_HOP` -10 over `SOLVE_TIME` 0.4 along the diagonal from `SOLVE_DELAY` 0.25 at `SOLVE_STAGGER` 0.04, each lamp going to JOY as the wave reaches it, a sparkle or a puff in turn; the chips clearing away in a scatter (`CLEAR_*`) stay this board's own. `WIN_WAIT` 1.6, from 2.0; the wave ran in reading order at 0.1 apart before |

Faces are written only when their look changes; each lamp's glow follows
the warmth of its own stone, written only when the light has moved.

**The dressing:**

- **Shadows on the ground.** The lamp's shadow leaves its face mesh
  (`casts`, which `CourtLantern._layers` now honours) for the ground mesh,
  as the family's soft disc read off the lamp's own scale and fade, anchored
  at the stone so a hopping lamp leaves it behind; the block's and the
  chip's flat ellipses became the same disc, at about twice their old peak
  (0.26 and 0.24 in `TEXT`) because a disc that fades to its rim reads at
  about half its centre.
- **The court wears no edge.** The family's 6 in `LINE` under the mortar bed
  was tried and dropped: it sat 14 px above the card's own lip and read as a
  doubled line, because the bed is a hair of shade over the parchment and
  not a surface. The mortar stays as section 2 has it.
- **No clouds or tufts.** The court fills the card; a tuft in a cell would
  read as a piece.

**Measured** on this Mac at 1080 x 1920 through `tests/_shot_anim.gd`, whose
Light Up run now sets down the first lamp of the answer (`empty` skips it):

| | Draw calls | Idle |
|---|---|---|
| Medium board at rest, bare, before | 62 | 3.08, 3.12 ms |
| Medium board at rest, bare, now | 63 | 3.15, 3.27, 3.48 ms |
| Now, with one lamp lit and its beam | 65 | 3.16, 3.22 ms |

The one call added is the floor and the ground being two meshes; a lamp
costs one less than it did, its shadow layer now in the ground. One process
reported 141 calls on the bare board twice; a per-frame probe of the same
build read a flat 63 on every frame with the board never busy, and every
later run agreed, so that pair is a process outlier and not the board.

Suite 2086/0. `tests/_win.gd` windowed 9/9, Light Up solved through the real
hint button, Check and taps. A throwaway probe shot the entrance, a placed
lamp with its light travelling, a pressed block and its refusal, a sunk
stone, a sweep and its chips, a wrong lamp under Check, an undo with the
beam withdrawing, a hint, a removal, a reset, the solve wave and the win
screen, each with and without reduce-motion (under which the court and the
blocks are up at once, a lamp is there or gone in one frame with its light
on or off, nothing sinks, blushes, shivers or rings, and the win screen
follows the last tap). Found on the way and fixed in both boards: Tents'
release cleared the gesture before releasing the pressed face, so a refused
tree stayed sunk at 0.94; the order is release, then clear.

Open, still, from section 10: the beam's second voice, the dull untouched
court, the travelling wave's pace, the ten glowing faces, the pinning hint
and the centred card. Nothing here answers them; it only makes the flat
board move with the same hand as the other six.

## 12. Amendment: the second polish, 2026-09-25

The user asked for the design and the animation to be polished. Built
directly, like the second passes of Code Break, Balance, Untangle, Shikaku
and Tents the same evening, and this amendment is the record. The rules,
the layout, the chips and section 8's table are unchanged except where
named.

**A flagstone is a stone.** Each is cut within `STONE_TONE` of its tint,
carries a soft light along its crest (`CREST_ALPHA`), and on some a few
specks (`SPECK_SHARE`) or a hairline crack (`CRACK_SHARE`) in its own deep
colour, all off two fixed hashes of the stone, so a court is drawn the same
every time. The highlights are thin fans and not strokes: a stroke's round
caps overlap its body and double the alpha at each end, which on a light
line reads as a groove.

**The beam is a shaft.** It is clear at its sides and full down the middle,
with a brighter core (`BEAM_CORE`, `CORE_ALPHA`), and each stone's length of
it fades from the strength it enters with to the strength it leaves with, so
the fall along a line is smooth rather than a stair. `BEAM_HALF` went from
0.19 to 0.3 because a soft shaft reads narrower than a hard one. **Where two
lamps see each other the beam between them is rose** (`CLASH_ALPHA`): section
10's "second voice" answered by drawing the broken rule where it is broken.
The straining faces and the sprout's line are unchanged.

**The light has a front.** A stone flashes toward white as it warms, peaking
half-way through its own `LIGHT_IN` (`GLINT_ALPHA`), so the travel out from a
lamp reads as a bright edge moving down the lines. **A landing lamp's wick
catches**: a warm disc swells and fades on the floor under it (`FLARE_*`),
on a tap, an undo that puts a lamp back, a hint's drop as it lands, and on
the win. A lit stone throws light on the side of any block beside it
(`RIM_ALPHA`, `RIM_WIDTH`).

**A block is cut stone.** The odd pale and dark lozenges are gone: its crown
has a bevel of light along the top and down the left and its right side in
shade. A numbered block's number is carved into a sunk plaque with a lit
lower lip; a blank block wears two chisel marks instead. A satisfied block
still goes green and an over one rose, as before.

**The lamp is folded paper with a candle in it.** `CourtLantern` calls the
parent's `_folds`, which Untangle's pass added, with its own skin and edge
and a blushing lamp's candle kept low. Its halo flickers on two sines
(`FLICKER`, `FLICKER_PERIOD`) as a transform on the glow layer, so a flicker
rebuilds no mesh and costs the lamp's own redraw only. The menu card and the
how-to-play diagram draw this lamp and pick up the folds; neither idles it, so
neither flickers.

**The win settles into lamplight.** A glint crosses every stone on the solve
wave (`WIN_GLINT`), every lamp's wick catches as the wave reaches it, the
mortar bed warms toward `SUN` (`WARM_ALPHA`, `WARM_TIME`), and the shafts sink
to `WIN_BEAM` of their strength over the same time. Ten crossing shafts at
full strength washed the solved court white on the first rendered frame, and
once every stone is lit they have nothing left to say.
`restore_completed_board()` opens onto that settled picture.

**A bug this found.** `restore_completed_board()` marks the court solved ten
seconds ago, and the board tested `_solved_at >= 0.0` -- which is false
within ten seconds of the clock starting, so a daily reopened early in a
session drew as unsolved. It only showed now because the win's look depends
on it (before, it gated only the chips' clearing, and a restored court has
no chips). `_solved_at` now starts at `NEVER`.

Under reduce motion none of it moves: no glint, no flare, no flicker, and the
win's warm bed and settled shafts are there at once.

**Measured** on this Mac at `--resolution 810x1440` with
`tests/_shot_anim.gd -- lightup`, before and after in the same session.
Draw calls are unchanged: **64-65** played and **62-63** bare. The played
idle reads 2.25 and 2.29 ms against 2.16 and 2.14 before, which is the one
lit lamp's flicker redrawing every frame. The bare board reads 2.23 and
2.14 against 2.14 and 2.14. The reduce-motion pair a second apart is
pixel-identical, and under reduce motion ANGLE matches the default driver
to a max channel delta of 1/255. The menu reads 260 calls before and after.
Suite 122583/0; `tests/_win.gd` windowed 21/21. A throwaway probe set down
two lamps that see each other, undid them, took a hint, Checked a wrong lamp,
solved the court and restored a completed daily, and shot each.
