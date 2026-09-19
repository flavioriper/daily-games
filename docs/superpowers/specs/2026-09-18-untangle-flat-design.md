# Untangle, flat: the fifth screen on trial

Status: built, 2026-09-18; polished onto the flat vocabulary 2026-09-19 (section 11). Concept page:
`docs/brainstorm/concepts.html#untangle`. Sibling specs:
`2026-09-18-binairo-flat-design.md`, `2026-09-18-codebreak-flat-design.md`,
`2026-09-18-balance-flat-design.md`, `2026-09-18-shikaku-flat-design.md`.

Untangle is a planar graph you have to re-draw: seven to fourteen lanterns,
cords between them, drag until no two cords cross.

**This is the screen with the strongest case for going flat, and the case is
about honesty rather than polish.** `puzzles/untangle3d.gd` says it in its own
header: the rope you see on the island is a sagging chain of Verlet points,
but the rule is tested on the *straight segment* between two posts. It defends
that honestly -- a rope pinned at both ends and pulled straight down settles in
the vertical plane through its posts, and that plane projects from above to
exactly the segment -- but the player is not looking from above, and what they
are reading is a curve standing in for a line. Flat, the cord is drawn taut and
the line read is the line tested. Everything else on this page follows from
that one sentence.

## 1. What was built

| File | New? | Job |
|---|---|---|
| `puzzles/untangle_state.gd` | new | The rules, scene-free: positions, cords, the crossings and *where each one meets*, the pile rule, every move. |
| `puzzles/untangle2d.gd` | new | The flat board: the field, the cords, the knots, the lanterns, the input and the sprout's lines. |
| `ui/faces/lantern_face.gd` | new | The cast: a paper lantern in one of five papers, with a halo when it lights. |
| `core/palette.gd` | edit | The five papers, the cord and its shade, the knot's rose. |
| `ui/registry.gd` | edit | `untangle` goes flat; `untangle_island` keeps the island board on the menu. |
| `tests/_win.gd` | edit | One driver solves both boards. |

The generator is untouched. `puzzles/untangle_gen.gd` -- the Delaunay spread,
the thinning toward 1.7 cords a lantern, the re-roll until the board handed
out is actually tangled, `MIN_SEP` and `is_untangled` -- is the island's, and
both boards call it with the same ladder, so a day hands out the same tangle to
each. Measured on the boards this page was built against: easy is 7 lanterns
and 12 cords, medium 10 and 17, hard 14 and 24, opening at about 4, 26 and 53
crossings.

## 2. The state is the one truth

`untangle_state.gd` holds the positions in the generator's normalised square,
the cords, the pegs a hint has planted, the history, and the result of one
scan: which cords are caught, **where each crossing meets**, and which lanterns
are piled on each other. The island reddens a caught rope and leaves the player
to find where, because a point floating over a stage has nothing to stand on; a
flat board can draw the knot on the spot, and `segment_intersects_segment`
already returns it. That is the one thing the flat state knows that the
island's does not.

The board draws this and nothing else. The island script still carries its own
copy until the two screens are judged; whichever survives, this is the one
truth to keep.

Zero crossings alone is not a win, here as there: dragging every lantern into
one heap makes every cord zero-length and trivially crossing-free, so
`min_separation` is checked exactly as the game checks it. Verified by piling
all fourteen on one point: `crossings=0`, `crowded=14`, `solved=false`, and the
sprout says so.

## 3. The field and the cord

- **The field fills the card; it is not a square inside it.** The generator
  works in a unit square and a crossing survives any affine map, so stretching
  that square to the card is the identical puzzle with bigger lanterns and more
  room between them. The insets are 104 either side, 84 at the top and 176 at
  the bottom -- the deep one, because the ring is the node and the lantern
  hangs below it.
- **Straight, except in your hand.** A cord takes slack in proportion to how
  fast the lantern it hangs off is travelling, and is straight again within
  about half a second of the drop. Two springs do it (`SAG_*`, `SWING_*`),
  integrated per frame; both are stilled under reduce motion.
- **The crossings are read off the drawn points, not the logical ones**
  (`_scan_px`). A hint slides a lantern to its peg over 0.35 s, and a cord that
  reddened or cleared before the lantern arrived would be describing a board
  that is not on screen yet. Twenty-four cords is 276 pairs a frame, and only
  on the frames something moves.

## 4. The lanterns

The cast is **paper lanterns**, five papers taken by index -- amber, rose,
moss, river, plum -- so a board of fourteen repeats a colour rather than
inventing a sixth. The camp already stands a lantern on its path, so this
borrows from the world the way Balance's apple borrowed from Code Break.

- **A node is a ring; the lantern hangs under it.** The cords meet at a small
  ring drawn on the point the rule is about, and the paper hangs an arm's
  length below it and swings. Fling one and the body lags behind the point.
- **A face answers the cords, never the answer.** A crowded lantern squashes
  and strains; everyone grins when the board comes undone. None of that says
  anything the cords are not already saying.
- **Lit is the reward, not the state.** They are unlit for the whole puzzle. On
  the win the light runs out from one lantern along the cords, hop by hop, each
  one warming with a halo as it arrives -- so the board finishes by proving it
  is one connected string, which is the one thing about the graph the player
  never sees while playing.

`lit` is snapped to five levels before it reaches `Face`'s mesh cache, so a run
of fourteen lanterns costs at most five meshes a paper rather than one a frame.

## 5. The knot

Both cords redden **and** a knot is drawn exactly where they meet: the
difference between a board that says something is wrong and one that points at
it. Knots turn gently, and one coming undone puffs a ring where it was, so a
drag that fixes two at once is felt as two.

**It is an endgame instrument.** A hard board opens at about fifty crossings,
and fifty markers is not a signal, it is a rash. The knots fade in as the board
comes down past sixteen and are at full strength by a dozen, which leaves easy
marked from the first frame and hard marked from about its halfway point. Above
that the cords carry it alone, which is what the island does all the way
through.

All the knots share one mesh, drawn once per crossing with its own turn, so the
marker layer costs at most sixteen draw commands and usually none.

## 6. The screen

Top bar (Back, `UNTANGLE` with the leaf, `EVERY KNOT COMES UNDONE`, then Undo,
**Reset**, Hint and Settings), day card, the board card, the tip card.

**No actions row and no Check**, and here that drops nothing: `capabilities()`
is undo and hint, and this board never had a Check to lose -- a knot is either
drawn or it is not. Reset joins the top bar, as it did on Balance. The registry
says `"shell": "flat"`, `"tray": "none"`, `"actions": false`, and the flat host
measures its bottom slot from the one row it built.

## 7. Input and motion

Touch and drag only, as every flat board takes them. A tap grabs the nearest
lantern within 1.9 R of its **ring or its body**: the point that matters is the
ring and the thing the player is looking at is the paper, and they are an arm
apart. One drag is one move; a tap that moved nothing is not a move and is not
undoable.

| Moment | What happens |
|---|---|
| Entrance | The lanterns drop from above, one per 0.035 s in index order, each cord appearing with the later of its two ends. |
| Pick up · drag | The lantern grows a tenth, the body swings against the direction of travel, and every cord on it takes slack. Knots appear and pop under the finger, live. |
| Drop | Everything springs back to straight. |
| Undo | Slides the last dragged lantern back to where it was picked up. Counts no move. |
| Hint | A lantern *in a knot* slides to the place the generator's own untangled drawing put it, a green ring pulses out, and it is on its peg: the ring goes green and it can never be dragged again. Counts no move. |
| Reset | Walks every free lantern home one per 0.04 s, so the tangle visibly re-forms rather than snapping back. |
| Solved | The light runs along the cords from the first lantern outward, each one sparkling as it lights, and the cords warm behind it. |

Nothing here is a tween. Positions, springs, entrances and the light run are
integrated and interpolated in `_process` against a clock, because the picture
of a lantern moves under a finger that is still moving it and a tween would be
fighting the drag. The frame is skipped entirely when nothing is moving
(`_animating`): measured, a board left alone goes quiet and redraws nothing.

## 8. The tip card and the win

The sprout carries the rule while the board is untouched (three lines, cycled),
then counts knots off as they go -- "One knot gone. 25 still to go.", "One knot
left. Nearly there." -- and warns about the pile when there are no crossings
but no room either. `tip_line()` is the whole interface.

The win is Balance's and Shikaku's shape: the board **is** the answer, so it
does not leave. The chrome fades, the board card slides down and shrinks, the
field re-fits into it lit, and "Well done! / Not a knot left." comes in above
with the day card's stats and Back to camp. `flat_win()` offers no cast for the
same reason. `win_delay()` is 2.0 s, the length of the light's run.

## 9. Measured

On this Mac at 1080x1920, through `world/main.tscn`:

| | Draw calls |
|---|---|
| Medium board, at rest (10 lanterns, 17 cords) | 75 |
| Hard board, at rest (14 lanterns, 24 cords) | 83 |
| The light running on the win | 88 |

Against the 855 budget in `docs/art/blender-contract.md`, with the stage hidden
under the flat host's opaque page. The whole board is four kinds of draw: one
mesh for every cord, ring, arm and puff together; one shared mesh per knot; one
or two per lantern; the particles.

Suite 2086/0. Win harness 18/18, both Untangles included -- the flat board
answers the island's own names (`nodes`, `_pos`, `_locked`, `_crossings`,
`node_to_local`, `planar_to_local`), so one driver solves both.

## 10. Calls this screen is still for

- **Is the straight cord worth the rope?** The island's rope is the best piece
  of motion in the game and this trades it for a line with a spring in it. If
  the flat board does not feel better to *read*, that is a real loss, not a
  wash. This is the whole question and it is a phone question.
- **Does the ring-and-body split confuse the grab?** The mock grabs on either;
  the alternative is a lantern centred on its own node, which reads as a ball
  on a string and loses the swing.
- **Fourteen lanterns and twenty-four cords on a phone.** Hard opens at about
  fifty crossings and every cord is red at that point. Whether that is a board
  or a plate of spaghetti is a thing to look at, not to argue -- and it is a
  question about the difficulty ladder, which the island inherits unchanged.
- **Reset in the top bar, twice now.** Two of the five flat screens have no
  actions row. That is either the family settling into two shapes -- boards
  that submit and boards that do not -- or it is a row that should never have
  existed.
- **Whether the knot marker makes the puzzle too easy.** It removes the search
  for *where* and leaves only the search for *what to move*. The fade-in past a
  dozen is one answer; hiding them until the last handful is another.
- **Whether a hint should hang a lantern on a peg for good.** It is the
  island's behaviour and it is generous, but on a board whose solution is not
  unique it also quietly commits the player to the generator's drawing.

## 11. Amendment: the polish of 2026-09-19

The user asked for Untangle to be polished with proper animations on
Binairo's pattern, smoother and more elegant, and for the pattern to be kept
so the other boards take it. Built straight in Godot, as Code Break's and
Balance's were, with this amendment and `docs/art/flat-motion.md` as the
record. The layout is kept. Section 7's "Nothing here is a tween" is
superseded by what follows; sections 3 to 5 stand.

**Two hands.** Untangle is the first flat board whose motion was integrated
against a clock rather than tweened, and it stays that way for the *point*:
the drag, the cord's slack and the lantern's swing (the two springs), and the
scripted walks all run in `_process`, because a tween would fight a finger
that is still moving the thing. What the *paper* does is the family's
vocabulary (`core/motion.gd`), and it can be because every lantern now
stands in a slot the board owns: the slot takes the ring's place and the
swing every frame, and the face hangs inside it where `pop_in`, `lift` and
`hop` tween its scale and height without the placement writing over them.
The rule is recorded as the second half of the doc's rule 2; what is drawn
into the cord mesh (rings, arms, cords) reads the recipes' constants and
draws the family's overshoot as a curve (rule 8).

**What changed, moment by moment:**

| Moment | Now |
|---|---|
| Entrance | the rings pop and the cords fade in along `ENTER_STAGGER` 0.03 over `ENTER_POP` 0.25, drawn; each lantern pops onto its ring `ENTER_FACE_LAG` 0.12 later with the squash. The string is hung first, then the paper. The drop from 60 above is gone |
| Pick up | `Motion.lift`, new to the vocabulary as the press for a dragged thing: the paper grows to 1.1 in 0.12 and its shadow parts from it; the cords wake as before |
| Drop | the paper springs back over `RELEASE_TIME` with the back ease and hops `HOP` -6; the springs settle as before |
| Knot undone | rings through `Fx2D.ring` in `KNOT` at R, once a knot a hold; the board's own drawn puff rings are gone, as are `PUFF_*` |
| Hint, undo, reset | the walks stay, one `SLIDE_TIME` 0.3 for all three (0.35 and 0.26 were copies with a drift), reset paced through `Motion.stagger` at `HOME_STEP` 0.04; every walk hops as it lands; the hint's peg rings green through `Fx2D.ring` and sparkles *as the lantern arrives*, in place of the drawn lock ring |
| Piled up | the crowd squash is settled through `lift` on its base scale when the pile forms or breaks, not written every frame |
| Solved | the light still runs along the string one hop per `LIGHT_STEP` 0.12 from `SOLVE_DELAY` 0.25; each lantern hops `SOLVE_HOP` -10 over `SOLVE_TIME` 0.4 as its light arrives, and sparkles through `_after` with the board's generation counter |
| Idle | the knots turn gently at rest, which they did not: a redraw with the mesh the board already has, no rebuild |

Faces are written only when their look changes, as Balance's are.

**The dressing:**

- **Shadows on the wall behind.** Every lantern throws a soft shadow on the
  parchment, the family's radial disc, built into the cord mesh under the
  cords with `Scenery.soft_disc` (new, and what `Scenery.shadow()` is made
  of), so fourteen shadows cost no draw call. A shadow is anchored at the
  paper's rest and reads the paper's own height: it arrives with the pop-in,
  parts from a lifted lantern (0.34 R further down, 0.18 wider, 0.16 to 0.08
  in `TEXT`) and stays put under a hop. `LanternFace.casts` turns the face's
  own shadow layer off for this; Light Up's lamp and the menu's card keep
  theirs.
- **Scenery** through `ui/flat/scenery.gd`, drawn behind the board's own
  drawing: a cloud in each top corner (34 and 29) and five tufts along the
  bottom edge, in the 30 under the lowest a paper can hang. One mesh, one
  draw call. Decoration says so: nothing there counts anything.

**Measured** on this Mac at 1080 x 1920 through `tests/_shot_anim.gd`, whose
Untangle run now drags the first lantern over 0.35 s (`empty` skips it):

| | Draw calls | Idle |
|---|---|---|
| Medium board at rest, before | 75 | 2.94 ms |
| Medium board at rest, now | 66 | 2.92 ms |
| Now, after a drag, its swing settling into the window | 66 | 4.8 ms |

The nine draw calls saved are the faces' shadow layers, less the scenery.
Three earlier readings of 7.9 ms at rest were the machine, not the board: an
instrumented copy of the same harness read 2.9 with nothing rebuilding, and
the harness itself read 2.92 twice afterwards. Take two readings, and take
them later if they disagree with a probe.

Suite 2086/0. `tests/_win.gd` windowed 9/9, Untangle solved through the
real hint button and drags. Throwaway probes shot the entrance, the lift,
the drop and its hop, a hint's walk and landing, an undo, a reset's walk,
the light run and the win, each with and without reduce-motion (under
which the string is up at once, nothing lifts or rings, and the light is
on the moment the board is solved).

Open, still, from section 10: whether the straight cord is worth the rope,
and the phone question generally. Nothing here answers it; it only makes the
flat board move with the same hand as the other three.
