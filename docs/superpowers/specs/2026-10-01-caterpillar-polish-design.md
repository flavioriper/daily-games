# Caterpillar polish: a smooth line, hearts, Peckish, rewards and sound

2026-10-01, built unattended on `feat/caterpillar-polish` at the user's word
("let's polish the caterpillar game, add more smooth animations, reinforce
that the sfx sounds are really cozy, add more visual rewards even if silly
to the user to keep engagement, and make sure the insane difficulty is
really insane, with something totally new (something only us do) that make
the game nearly impossible, user can also fail on insane and hard ... don't
worry if you need to redo something on the logic or design, as long as it
keep the cozy vibe. Players are complaining the movement of the line is too
laggy, it start to become even more laggier as it grow, it's not smooth").

Pinwheel's and Rings' passes the same morning are the pattern for hearts,
dusk and the card, the streak, the gags, the party and the seal. The board's
own spec (`2026-09-25-caterpillar-flat-design.md` and its amendment) stands
except where this says otherwise. The calls at the end are for the user.

## 0. Why the line lagged, measured

Three causes, each confirmed before it was fixed:

1. **Every frame of a drag rebuilt everything.** The live mesh held every
   leaf (Bézier outlines and `Geometry2D.clip_polygons` for the bites), every
   fence and every segment, and a drag keeps it rebuilding every frame (the
   walk, the ripples). `tests/_probe_cat_perf.gd` (headless, CPU only, this
   Mac): **7.7 ms a frame at one segment, 25.6 ms at 47 (Hard), 28.9 ms at 62
   (Insane)** -- the growth players felt. A phone is several times slower.
2. **Squares were dropped.** Only the square under the newest touch event
   counted, so a flick that crossed two squares between events grew none of
   the one in between (it was "far" from the head) until the finger came
   back. In the same windowed harness, a drag along Hard's answer at one
   square an event kept **40 of 48** squares and averaged **35.7 ms** a
   frame.
3. **The head stuttered.** Each step restarted a 0.11 s slide from the last
   square's centre, so a step arriving mid-slide jumped the head back.

## 1. The fix

- **Layered meshes, each rebuilt only when what it shows changes**
  (`caterpillar2d.gd`'s header lists them): `still`; `under` (the hint's wash,
  the leaves, the fences, the blush); the **tail** (shadows and legs, then
  tube and rounds) baked at rest and **appended to** every `TAIL_STEP` (8)
  squares, started again only when something under the seam changed; the
  **live** stretch, the last `DYN` (16) segments, where every ripple, gulp,
  pop and the walk happen; `over` (badges); `top` (the head).
- **The live stretch is copied, not drawn.** A segment's parts -- shadow, leg
  (a unit stroke stretched to its tip by the transform), foot, round (never
  turned, so the light stays top left), spots (turned the way it faces), the
  solve's glow in five strengths -- are triangle lists baked once a layout
  (`_part`, the inner class `Soup`), and a frame only appends them through a
  transform (`Transform2D * PackedVector2Array`, native). Building the same
  stretch with the builder cost 0.4 ms a segment here.
- **Leaves and fences are cached by their look** (`_cache`, keyed by square,
  eaten, the three bites in quarters, or the fence's flash in sixths), so a
  chew re-bakes one leaf, not twelve. The bites were 11.7 ms a frame alone.
- **The drag is walked**, a fifth of a square at a time (`DRAG_SAMPLE`), so
  every square the finger crosses grows in order. A finger that cuts a
  corner into a diagonal square steps through the side square whose margin it
  crossed (`_via`), else the nearer -- **and only through one the board allows
  and the judge prices at nothing**: a corner is an ambiguous gesture and
  never costs a heart.
- **The head trails by a lag along the walked squares** (`_lag`, `_along`):
  a step adds a square to whatever lag is left (at most `LAG_MAX` 2.5), and it
  melts exponentially (`SLIDE_TAU` 0.045 s). Squares not reached yet sit under
  the head. It never jumps back and never cuts a corner, so the tube never
  kinks (the first try at this, sliding from wherever the head was drawn,
  wedged the tube on fast drags).

**After** (same probes): **1.1 ms a frame at one segment, 2.2 at 47, 2.3 at
62** -- flat. Windowed, a flick 1.5 squares an event along the whole answer
keeps **48 of 48** (Hard) and **63 of 63** (Insane) squares, at ~11-12 ms a
frame mean including the harness's own PNG saves, entrance, chewing,
confetti and particles.

## 2. Hard and Insane can be failed

| band | garden | hints | hearts | undo | judged |
|---|---|---|---|---|---|
| Easy | 5x5 | 3 | - | yes | - |
| Medium | 6x6 | 3 | - | yes | - |
| Hard | 7x7 | **1** | **3** | yes | a step that **strands** a square |
| Insane | **Peckish** 8x8 | **0** | **2** | **no** | any step **off the one walk** |

- `State.judge(n)` prices a legal step: **"strand"** -- after it an empty
  square can no longer be reached, or is left with a single way in and is not
  the last leaf (the generator's own `_viable` prune, sound: such a garden
  cannot finish), or on Peckish no leaf is left within the tummy's reach
  (`Gen._fed`); **"doom"** (Insane only) -- the step leaves the answer, and
  every garden is proved to have exactly one walk, so no walk finishes.
  Probed over 15 gardens a band (`tests/_probe_cat_judge.gd`): **the answer's
  own steps are never priced**; on Hard 858 of 1242 legal off-answer steps
  strand (69 %), on Insane all 1326 are priced, 985 of them visibly
  stranding. 0.05 ms a call.
- **Hard judges what the player can see.** A stranded square is drawn
  (blushing), so a heart is never lost for something the board cannot show;
  wandering off the answer without stranding anything is free, as before, and
  the drag back undoes it.
- **The wrong step** (`_misstep`): the stroke so far is kept as its own move,
  the caterpillar steps there and worries (WORRIED face, a shiver), the
  stranded squares blush rose and wobble and the square it stepped onto is
  ringed, a heart splits on the pill, and `EJECT_AFTER` (0.75 s) later it
  scoots back (`State.take_back`, the head running back over `SLIP_TIME`).
  Input, Undo, Hint and Reset wait (`busy()`). Lines: `CP_STRAND`, `CP_DOOM`,
  `CP_STARVE` and the hearts left.
- **Out of hearts**: dusk, the caterpillar asleep, `ui/hud/out_of_hearts.gd`
  with `CP_OUT_BODY` / `CP_OUT_REST`; Try again empties the garden with every
  heart back; One more heart once a garden.

## 3. Insane: Peckish

**The middle leaves carry no numbers -- eat them in any order -- and the
caterpillar's tummy holds only five bare squares between bites.** Leaf 1 is
marked and the last leaf wears a star; every leaf fills the tummy again; a
bare square on an empty tummy is refused for free ("Too hungry! A leaf
first.") and the tummy pill shakes. The pill of five leaf pips sits beside
the hearts and turns rose at one left, and the head worries.

- **Why it is ours**: checked 2026-10-01 against the genre's published apps
  and clones (ordered waypoints, walls, sizes, daily ladders): none drops the
  order and adds a step budget between waypoints.
- **Why it is nearly impossible**: without numbers the player no longer knows
  which leaf comes next, and the tummy makes distance the constraint -- every
  bare run must end on some leaf within five squares, and the walk still has
  to fill the garden. Every step off the one walk costs a heart, two hearts,
  no hints, no Undo (the drag back still works, and only throws right steps
  away). The mined gardens carry **29-37 tempting wrong steps** each along
  their answer (`Gen.traps`, the bank's rung).
- **The bank**: 200 gardens, 8x8, tummy 5, up to 16 fences, mined by
  `tools/insane/caterpillar_ladder.gd` through `tools/mine_insane.gd` (280 of
  320 tries proved within the 4000-node cap, ~1.2 s a try a thread, 50 s
  wall), each re-proved unique at 400k nodes by `grade`. About 12 leaves and
  13 fences a garden. One garden costs ~400 ms to make here, too slow live;
  without a bank Insane deals Hard's garden live.
- `Gen.count` / `_walk` take `hunger` (unordered leaves and the tummy);
  `Gen.context` now builds the masks every search and the state's judge read.
- `CP_LVL_3` "Peckish: 8 × 8, no numbers, a tiny tummy"; tips `CP_TIP_PECKISH`,
  `CP_TIP_TUMMY`, `CP_TIP_ANY`, `CP_TIP_HEARTS`; rules `CP_RULES_PECKISH`.
  A Peckish solve shares `😋 Peckish[ · Flawless]` and stamps the night seal.

## 4. Rewards, even silly

- **The streak**: leaves eaten in a row (a cut back past a leaf, a wrong step,
  Undo, Hint, Reset or the hearts running out ends it): `combo` up the
  pentatonic from the second, the "x3" paper bubble over the leaf from the
  third, confetti at 4, 7 and every 5.
- **A filled row or column** sparkles along its length out from the head
  (`row`).
- **Gags** on one eaten leaf in three (any nine leaves play each kind once),
  one at a time: a happy hiccup **blows a soap bubble** that swells, floats up
  wobbling and pops (`burp`); **love hearts** float off the leaf (`love`); a
  **ladybug** (drawn in code) flies in, sits on the head a moment with a
  little bow and flies off (`ladybug`).
- **The party**: the hop and the big butterfly as before, confetti twice
  (`party`), **a flutter of little butterflies** rising off five leaves
  (`flutter`, one mesh a frame), **the nap cat** hopping onto the bed's foot
  and curling up (`purr`), the sprout's **caterpillar wisdom** (one of
  twelve, `CP_CHEER_0..11`), and **the seal**: gold for Flawless (no hint,
  and no heart lost on Hard and Insane / no Undo on Easy and Medium), night
  for any Peckish ("Insane" over Flawless or Peckish). `completion_record()`
  keeps `hearts` and `flawless`; restore shows the walk, the cat asleep and
  the seal.

## 5. Motion

New: the head's lag (above); a press squash on the head; the wrong step's
worry, blush, heart split and scoot; the dusk; the tummy pill's shake; the
bubble, hearts, ladybug, flutter, cat and seal. Under reduce motion: no lag,
gags, confetti, flutter or sparkles; a wrong step only blushes, splits the
heart and takes the square back at once; cat and seal at once.

## 6. Sound

A new style, `CLOVER` (`tools/gen_sfx.py`): a sunny clover garden, soft felt
and leaf rustles, tiny wooden ticks, kalimba and music box, hushed. Re-
prompted: `place`, `munch`, `refuse`, `undo`, `hint`, `reset`, `enter`,
`solved`. New: `combo`, `confetti`, `burp`, `love`, `ladybug`, `hungry`,
`strand`, `heart_lost`, `slip`, `out_of_hearts`, `heart_back`, `stamp`,
`party`, `purr` (the house cat's), `flutter`, `row`, `fill` (Peckish's tummy
filling). `step` still has no file. Rendered on the fallback key (the main
one is out of quota); **unheard** by a person.

## 7. Numbers

`tests/_shot_caterpillar.gd` at `--resolution 810x1440 --always-on-top`,
windowed, one at a time, peak draw calls from 0.5 s:

| mode | band | peak |
|---|---|---|
| rest | Hard | 82 |
| drag (1.5 squares an event, whole answer) | Hard / Insane | 105 / 100 |
| wrong (blush, heart, scoot) | Hard | 88 |
| out (dusk, card, Try again) | Hard | **110** (ANGLE 83) |
| right (streak, gags) | Medium | 98 |
| hungry | Insane | 81 |
| solve and party | Insane | 100 (ANGLE 113) |
| restore | Insane | 91 |
| solve, reduce motion | Easy | 92 |

Peak 113, 742 under the 855 budget. Suite `passed=122403 failed=0`;
`tests/_win.gd -- caterpillar` PASS.

## 8. Calls for the user

- **Hard judges strands only; Insane judges any step off the walk.** Hard's
  hearts are lost only for a square the board shows cut off; Insane's for
  any step from which the garden cannot finish, visible or not. If Hard
  should be harsher, `judge()` drops the `difficulty >= 3` test.
- **A corner never costs a heart**: a finger that cuts a corner takes the
  side square that costs nothing, or waits. It leaks a little (the side it
  did not take might have cost one); the alternative was charging for a
  gesture the player did not make.
- **No Undo on Insane**; dragging back still takes steps back (it can only
  throw right steps away there) and Reset stays, keeping the hearts lost.
- **Tummy 5**, 8x8, about 12 leaves. 4 makes ~15 leaves (a busier garden),
  6 and 7 fewer leaves and more fences (`Gen.PECK_HUNGER`, re-mine).
- The ladybug lands on the head (the leaf's square is under it); bubble,
  ladybug, butterflies and the lag's 0.045 s were judged on stills and
  numbers only.
- Sounds unheard.

- **Review findings, fixed**: a second finger moved the stroke (the walked
  drag crawled the line between two fingers and could price the squares it
  crossed) -- only the finger that started a stroke moves it now, Quilt's
  rule; a wrong step during a cut's run-back drew the body over the squares
  just cut away -- the run-back is dropped first; Insane offered a hint by
  video though its rules say none -- `capabilities()` drops "hint" there, as
  Rings does; a wrong step onto a leaf showed it eaten (bites, gold ring, a
  full tummy) until the scoot -- it shows as it was; and Insane without a
  bank (Hard's live garden, perhaps not proved unique) no longer prices
  steps off the answer (`judge()` needs `unique`). Checked clean by the
  review with an independent solver: the judge never charged a step that
  could still finish (7,181 Hard and 5,675 Insane steps), and all 200 banked
  gardens have exactly one walk.
