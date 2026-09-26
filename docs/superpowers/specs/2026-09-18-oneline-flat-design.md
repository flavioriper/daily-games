# One Line, flat: the eighth screen on trial

Status: built, 2026-09-18. Concept page:
`docs/brainstorm/concepts.html#oneline`. Sibling specs:
`2026-09-18-binairo-flat-design.md`, `...-codebreak-`, `...-balance-`,
`...-shikaku-`, `...-untangle-`, `...-tents-` and
`...-lightup-flat-design.md`.

An Eulerian path: walk every line of the figure exactly once without lifting
your finger. Walk into a part of the figure you cannot get back out of and the
rest is stranded, however carefully you continue.

## 1. What flat buys here, honestly

**The figure is a drawing, and this one is drawn on a lattice.**

- **Half its lines are diagonals** -- measured, 9.2 of 20.5 on hard -- and the
  diagonals are what stop it reading as a plain grid. Seen at seven degrees a
  45-degree plank is not at 45 degrees any more: the lattice shears, the near
  rows stretch, the far rows crowd, and the shape the player is asked to trace
  is a shape the camera invented. Square-on, the figure is the figure.
- **The whole of it has to be legible at once.** Unlike every other board in
  the set, One Line asks a question about the *global* shape -- is what is
  left still all in one piece from where I stand -- and the player answers it
  by looking at the whole figure. That is the worst possible thing to
  foreshorten.
- **Crossings stop being a rendering problem.** The lines cross; that is what
  makes these figures figures. On the stage two planks at the same height
  share a coplanar patch of top face wherever they meet, which z-fights, and
  `oneline3d.gd` answers it by lifting every plank 0.0008 per edge index
  (`PLANK_STACK`) -- a stack twenty planks and 0.016 units tall, chosen to
  stay under the bevel. Flat, the later stroke is simply on top. The flat
  board goes one better than the mock here: it draws **every stone line in one
  pass and every plank over them in a second**, so a walked line is never cut
  where an unwalked one crosses it. The island cannot do that at all.
- **And it buys the walker.** The island has no walker: the player's finger is
  the walker and the planks rise behind it. Flat, a small character rides the
  stroke and lays the line as it goes, which makes "without lifting your
  finger" literal, gives the board something alive between moves, and costs a
  canvas two cached meshes. On the stage that same thing is a rigged model, a
  path animation and a draw call per frame.
- **What it costs is the jetty.** The island's version reads as a real place
  you could walk out onto; the flat one is an ink-and-parchment diagram with a
  snail on it. That is a fair trade for legibility, not a free one.

## 2. What was built

| File | New? | Job |
|---|---|---|
| `puzzles/oneline_state.gd` | new | The rules, scene-free: the figure, what has been walked, where the stroke stands, and every move that changes them. |
| `puzzles/oneline2d.gd` | new | The flat board: the figure, the planks, the posts, the walker, the gesture and the sprout's lines. |
| `ui/faces/snail_face.gd` | new | The walker. The one new species the eight flat screens have added since Code Break's friends (section 4). |
| `core/palette.gd` | edit | The bottom edges a flat board needs, the brighter plank of a finished trail, the colour of a stranded line, and the snail. |
| `ui/registry.gd` | edit | `oneline` goes flat; `oneline_island` keeps the island board, seeded from the same day. |
| `tests/_win.gd` | edit | One driver solves both boards. |

The generator is untouched. `puzzles/oneline_gen.gd` -- the sown lattice, the
largest component, the parity fix and Hierholzer's trail -- is the island's,
and both boards run the same ladder (3x3 at 0.55 fill, 4x3 at 0.5, 4x4 at
0.45), so a day draws the same figure on each.

## 3. The state is the one truth

`oneline_state.gd` is `oneline3d.gd`'s logic ported, with no scene under it and
two things made explicit that the island kept in its scene:

- **Which end a plank grows from.** A line is an unordered pair, so
  `lay_from` records the post the walker actually crossed *from*. Without it
  half of all steps would lay their trail against the snail rather than behind
  it -- the island never needed it, because its plank is a solid that scales
  from the middle.
- **A step reports what it did** (`STEP_NONE`, `STEP_OK`, `STEP_WALKED`), so
  the board can tell a drag that strayed past an unreachable post (say
  nothing) from a tap on a line already walked (dip the post and name the
  rule).

Everything Hint and Check need is one question asked twice:
`walkable_from()`, whether the unwalked lines can all still be taken in one
stroke from where the player stands, and `stranded()`, the lines that can no
longer be reached at all. There is no search anywhere in the puzzle -- only a
degree count -- which is why generation is free.

The opening post is not a move and cannot be undone; Reset is what takes it
back. That is the island's behaviour, kept deliberately, and it is section
10's last call.

## 4. The cast is one character, and it is new

The walker is `ui/faces/snail_face.gd`. Eight screens in, the flat cast is
five fruit, seven friends, two lanterns, a marker, a tent, a tree, a sun and a
moon, and **not one of them walks anywhere**. A snail earns the exception
because its trail is the mechanic: the line you may not lift your finger off
is the line it leaves behind. The alternative was giving every post a face,
which is the family's usual move and would have put fourteen of them on a hard
board.

Two layers, so the walker costs two cached meshes a frame however it is
turned: the shell, foot, spiral and eyestalks, which never change, and the
head's one eye and mouth, which carry the expression. The turn and the rock are
the Control's own transform and never a rebuild -- the drawing faces right and
a negative `scale.x` mirrors it, which is why the face sits on the head and
not on the shell: a mirrored shell is still a shell, and a mirrored face would
read as a second animal.

It wears three faces: HAPPY, STRAIN the moment a step strands something, and
JOY on the win. It blinks on the family's own timer through `Face.set_idle`.

## 5. What the board says, and what it will not

The one way to lose One Line is to strand lines behind you. **The board does
not draw that in advance.** Live reachability -- fading every step that would
cut the figure in two -- was on the table and was turned down, because
avoiding stranding *is* the difficulty, and a board that greys out the wrong
moves has played the puzzle for you.

So the warning comes after the fact: the stranded lines go cool grey
(`PLANK_LOST`) the instant it happens, the walker strains, and the sprout says
how many and what to do about it (undo back to the fork). Check flashes the
same lines on demand and counts them.

Measured over 200 generated figures a step, **three boards in five carry a
dead-end post** (123, 123 and 121 of 200), and on a figure with two odd posts
one of them is usually that dead end -- so the classic way to lose is to walk
into it while most of the figure is unwalked. That single case is most of what
this puzzle is, and it is why the board will not draw it for you.

**The posts keep the island's four caps**: `ACCENT_2` terracotta under the
walker, `GOOD` green where the stroke may begin, `ACCENT` teal where lines are
still to walk, `POST_SPENT` pale stone once a post is finished with. The green
matters most, and the measurement says so: **199 of 200 easy and medium
figures and all 200 hard ones have exactly two odd posts**, so the opening is
forced almost every time and the two green caps are the first thing to read.

**A hint is allowed to refuse.** It walks one line whose far end still leaves
everything else walkable, so it can never be the move that strands the figure;
when no such line exists it says so rather than inventing one. That is the
island's behaviour exactly, and the one place a hint in this game does nothing.

## 6. The gesture

- **Press a green post and drag.** The stroke steps whenever the finger comes
  within a thumb of a neighbouring post, because the line between two posts is
  never in doubt, so there is nothing to aim at but the post itself.
- **Taps work too**: the same reach, one step at a time, which is what a
  player with a small screen and a big thumb will actually do. The win harness
  drives the whole trail this way.
- A drag that strays onto a post with no line left to walk is refused
  silently; a tap on one is refused with a dip and a line from the sprout.
- The reach is 0.42 of a lattice step: **138 design pixels on easy and 102 on
  the other two steps, which is 50 and 37 CSS pixels on a 390-wide phone**
  around a post 40 and 30 across. It is the tightest gesture of the eight flat
  screens, and section 10's second call.

## 7. The screen

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `ONE LINE` with the leaf, `ONE STROKE, NO LIFTING`, then Undo, Hint with its count and Settings. |
| Day card | 120 | The day and its name. |
| Board card | cut to the figure | The figure on parchment, centred in what is left. |
| Actions | 130 | Reset and Check. |
| Tip card | 140 | The sprout and one line. |

The bottom slot is **290**: the tip card, the actions row and the gap between
them -- the same as Tents and Light Up. The registry asks for no tray
(`"tray": "none"`) and keeps the actions row, because Check has something to
count.

The lattice keeps **square spacing** -- the same distance across as down --
so a diagonal stays a diagonal; the card is then cut to the figure and
**centred** (`card_height`, `card_centred`), the third board of the eight to
break the family's rule of pinning the board under the day card.

Measured in the real design space (1080 wide, a 1190-tall slot):

| Step | Lattice | Cell | Card | Air | Post across | Reach |
|---|---|---|---|---|---|---|
| Easy | 3x3 | 328.6 | 1000 | 190 | 112 | 138 |
| Medium | 4x3 | 242.1 | 758 | **432** | 82 | 102 |
| Hard | 4x4 | 242.1 | 1000 | 190 | 82 | 102 |

Easy is capped by the width, medium and hard by the width too. Medium's
lattice is wider than it is tall, so its card is squat and it leaves 432 of
air -- a third of the slot, and considerably worse than the mock's predicted
253, because the game's slot is taller than the mock's. It is the widest air
of the eight screens and it is section 10's first call. Nothing was changed to
hide it: medium's lattice is the island's, and moving it would either shear
the diagonals or break the twins' shared ladder.

## 8. Motion

| Moment | What happens |
|---|---|
| Entrance | The stone lines fade in one per 0.02 s in index order from 0.14 s, then the posts drop onto the parchment from 0.2 s on a diagonal wave, caps already coloured. |
| Beginning | The walker arrives on the post with a pop. A post the stroke may not begin at answers with a dip and a line from the sprout instead. |
| Walking a line | The walker travels it in 0.28 s -- the island's own `LAY_TIME` -- rocking as it goes and facing the way it is heading, and the plank grows behind it from the end it was crossed from. |
| Stranding | The stranded lines cool to grey the instant it happens and the walker strains. Nothing is dimmed before the step. |
| Hint | A green ring pulses out of the post it is sending you to, sparks rise off it, and the line is walked. |
| Check | Every stranded line shakes in place and the sprout counts them. |
| Undo | The plank sinks back to stone over the same 0.28 s and the walker walks back onto the post it came from. It counts no move. |
| Solved | Every plank warms to `PLANK_HI` along the trail in walk order, 0.06 s apart, and the walker hops on the post the stroke ended on, damped so it lands. |

Two implementation notes worth keeping:

- **The entrance has two waves, and the mesh has to follow the later one.**
  The board only rebuilds while `_animating()` says something is moving, and
  the first version asked only the posts' wave. On a figure with twenty lines
  the lines' wave outlasts it, so the last few chords froze at four fifths of
  their fade -- two pale lines that never arrived, found on a rendered frame
  and not in a test.
- **A canvas command holds a mesh by RID, not by reference.** Rebuilding the
  figure every frame and dropping the previous mesh leaves the renderer
  drawing a freed RID ("Parameter mesh is null", and an empty card) on any
  frame rendered without a queued redraw flushed first -- which is what
  `RenderingServer.force_draw()` in a harness does. This board keeps the mesh
  its last `_draw` handed over in `_shown`, as `lightup2d.gd` does.

## 9. Measured

- Suite `passed=2086 failed=0`; win harness `winnable=21/21`, both `oneline`
  and `oneline_island` driven through real touch events, with the board-fit and
  HUD checks (one hint, one check) included. The flat board answers the
  island's own names (`_edges`, `_nodes`, `_walked`, `node_to_local`), so one
  driver solves both twins.
- Draw calls against the 855 budget: **61** on a fresh figure, **63** part
  walked and 63 on a stranded one, **40** on the win screen.
- The ladder, over 200 generated figures a step: easy 3x3 with 11.8 lines (4.9
  diagonal) over 8.4 posts; medium 4x3 with 15.2 (6.7) over 10.7; hard 4x4
  with 20.5 (9.2) over 14.1. Hierholzer returned a full trail on every one of
  the 600, and 598 of them have exactly two odd posts.
- By hand, on rendered frames: the figure part walked with the walker laying a
  plank mid-line; a figure deliberately stranded (8 lines grey, the sprout
  counting them, Check agreeing); the win screen with the finished trail, the
  stats card and Back to camp; and reduce motion putting the whole figure up at
  once with no wave -- pixel-identical to a settled board.

## 10. Calls this screen is still for

- **Medium leaves 432 of air** (section 7). The options are to let the card
  fill the slot and centre the figure inside the parchment instead of cutting
  the card to it, to give medium a 4x4 lattice at a lower fill -- which would
  have to move the island's ladder too, or break the twins -- or to accept that
  one of the three steps has a short card. Nothing here is hidden, and the
  menu opens every board at medium, so this is the picture a player sees first.
- **Is a snail one species too many?** It is the ninth kind of thing in the
  flat cast, added for one board. The alternative was fourteen faced posts.
- **Does the drag actually work on a phone?** A 37-pixel reach around a
  30-pixel post, with the finger covering both, is the tightest gesture of the
  eight screens -- and unlike a tap, a drag that strays costs an undo. The
  board steps on proximity rather than on crossing the line, which is the
  forgiving choice; whether it is forgiving enough is a thumb question, not an
  argument.
- **Was refusing the live reachability right?** It is the kindest thing this
  screen could do and it was turned down on purpose. If the first real
  playtest is someone stranding a figure three times and putting the phone
  down, that decision is the thing to revisit first.
- **There is no count of lines walked anywhere on the screen.** The sprout
  says how many are left and the figure shows it in stone and wood. That is the
  family's instinct, and it is also the one number a player might genuinely
  want.
- **The opening post cannot be undone.** A player who begins on the wrong
  green post -- or lets a hint choose for them -- has Reset and nothing else.
  It is the island's behaviour and it matters little on a figure with two
  equally good openings, but it is the one move on the board that is not
  reversible.

## 11. Amendment: the polish of 2026-09-19

The user asked for One Line and Nonogram to be polished with proper
animations on Binairo's pattern, smoother and more elegant, and for the
pattern to be kept so the other boards take it. Built straight in Godot, as
the six ports before it were, with this amendment and `docs/art/flat-motion.md`
as the record. The layout is kept; sections 2 to 7 stand. Section 8's motion
is superseded by what follows.

**Drawn posts and lines, and a walker in a slot.** The figure stays one
mesh, rebuilt while an `_anim_until` clock runs that every moment extends
through `_busy_for`; the posts and lines read the recipes as curves off
`Motion` (rule 8 of the motion doc), and the board's own `_back_out`, `_dip`,
`_ring` and `_flash` are gone. The walker was already a Control; it now
stands in a slot the board positions every frame -- the ride along the line,
the facing and the rock -- so the recipes can tween the snail inside it
without the two hands writing the same property (rule 2). The pattern grew
nothing here: Light Up had completed the curve readers, and One Line needed
none it did not have.

**What changed, moment by moment:**

| Moment | Now |
|---|---|
| Entrance | each stone line pops in wide about its own middle (`wide_pop_scale`, `ENTER_WIDE_FROM` 0.86 over `ENTER_POP` 0.25) while it fades in, in index order at `ENTER_STAGGER` 0.03 after `ENTER_DELAY`; each post pops in with the squash (`pop_in_scale`) along the diagonal `ENTER_FACE_LAG` later, its soft shadow arriving with it. The lines' 0.4 s fade and the posts' 0.14-step drop from 0.7 are gone |
| Press | the post under the finger sinks to `PRESS_SCALE` 0.94 (`press_scale`) and shades halfway to `POST_DEEP` at the bottom of the press (`SINK_SHADE` 0.5, Light Up's finding on mid-grey stone: the scale alone is five pixels on a drum this size), and springs back on release; the walker standing on it sinks with it (`press`). Nothing pressed before |
| Begin | the walker pops in with the squash (`pop_in`, `POP_IN` 0.22) in place of its own back ease from 0.01; the post hops `HOP` -6 (`hop_lift`); a puff in `ACCENT_2`, the walker's own cap; every cap takes its new colour with the Count bump (`bump_scale`), since the green starts go teal together |
| Walk | the walk itself is kept as this board's signature: `LAY_TIME` 0.28 with the plank growing under the snail. **The far post keeps the cap it wore until the walker lands**, then takes its new one with the Count bump; the post the walker left is recounted at once. On landing the post hops `HOP` over `HOP_TIME` 0.3 and a puff in `PLANK_LAID` lands with it |
| Undo | the reverse: the plank sinks back over `LAY_TIME`, the walker walks back, the post it reaches hops and its cap bumps; no puff |
| Hint | before the stroke, the walker drops in from `DROP` 40 above with the fade (`drop_in`) onto the start post, under a ring in `GOOD` through `Fx2D.ring` with a sparkle; after, it walks the safe line and the ring and the sparkle come as it lands (`_after(LAY_TIME)`), Untangle's rule for a piece that walks. The ring the mesh used to draw is gone (rule 5) |
| Wrong on Check | each stranded line wobbles about its middle (`wobble_angle`, `WOBBLE_ANGLE` 0.105 over `WOBBLE_TIME` 0.45) and blushes toward `BAD_TILE` and back (`flash_level`, `FLASH_IN` 0.15, `FLASH_OUT` 0.45). The 0.6 s horizontal shake with nine swings is gone |
| Refused | the post shivers (`shiver_offset`, `SHIVER_PX` 2 over `SHIVER_TIME` 0.2) while its drum blushes toward `BAD_TILE` (its deep edge half toward `BAD`), read off `flash_level`. The dip is gone |
| Reset | every plank shrinks to nothing about its own middle (`pop_out_scale`, without the quarter turn a long thing would only wobble through) in a wave from the far corner at `RESET_STAGGER` 0.02, kept on a leaving list since the state has forgotten it; the posts hop `RESET_HOP` -4 and their caps bump in the same wave; the walker pops out with the quarter turn where it stood (`pop_out`), the slot staying put through it. Everything vanished on one frame before |
| Solved | the planks still warm to `PLANK_HI` along the trail in walk order -- the stroke running back along itself is the signature -- but at `SOLVE_DELAY` 0.25 and `SOLVE_STAGGER` 0.04 per plank, uncapped (a capped retrace would arrive all at once at the end), each over `BRIGHT_TIME` 0.35; each post hops `SOLVE_HOP` -10 over `SOLVE_TIME` 0.4 as the warmth reaches it, and the walker last, grinning, with a sparkle. `win_delay()` is measured off the trail (`_solve_delay(n) + SOLVE_TIME + WIN_SETTLE` 0.3: about 1.4 s on easy and 1.75 on hard) in place of a flat 2.0 |

**The dressing:** the post's flat 0.13 ellipse became the family's soft disc
(`Scenery.soft_disc`, 0.24 peak in `TEXT`, since a disc that fades to its rim
reads at about half its centre), drawn at the post's rest so a hopping post
leaves it behind. The walker's shadow stays in its body mesh. No clouds or
tufts: a jetty seen from above has no sky.

**Measured** on this Mac at 1080 x 1920 through `tests/_shot_anim.gd`, whose
One Line run now stands the walker on the trail's first post and walks its
first line (`empty` skips it), two readings each:

| | Draw calls | Idle |
|---|---|---|
| Medium figure at rest, bare, before | 63 | 2.90 ms |
| Medium figure at rest, bare, now | 63, 64 | 2.86, 2.87 ms |
| Now, with a plank laid and the walker standing | 66 | 2.89, 2.91 ms |

Suite 2086/0. `tests/_win.gd` windowed 9/9, One Line solved through the real
hint button, Check and taps. A throwaway probe shot the entrance in three
frames, a refused start, the hint's drop under its ring, the walk mid-line
and its landing, an undo mid-walk, Check's wobble on two lines, the pressed
post and its release, two planks, Reset mid-wave and done, the solve wave in
three frames and the win screen, each with and without reduce-motion (under
which the figure is up at once, the walker is there or gone in one frame, the
walk and the plank are instant, nothing sinks, blushes, wobbles or rings, and
the win screen follows the last tap). The pressed post was measured on the
frame at 79 px against 84 at rest, which is the 0.94.

Open, still, from section 10: medium's air, the snail as a species, the drag
on a phone, the refused live reachability and the missing count. Nothing here
answers them; it only makes the flat board move with the same hand as the
other eight.

## 12. Amendment: the second polish, 2026-09-25

The user asked for the design and the animation to be polished. Built
directly, like the second passes of Code Break, Balance, Untangle, Shikaku,
Tents and Light Up the same evening, and this amendment is the record. The
rules, the layout, the gesture and the caps' four meanings are unchanged.

**A ford is stone, not a black bar.** On parchment with no island sun the
old `SLATE` line read as near-black, against the shading direction; it is
`FORD_STONE` now, still dark to the plank's light and well apart from
`PLANK_LOST`. Each ford casts a soft shadow down the page (`FORD_SHADOW`)
and carries a lit crest along whichever side faces up (`CREST_*`), drawn
without caps for Light Up's reason: round caps double a light line's alpha
at its ends.

**A plank is a boardwalk.** The deep wood runs underneath and the slats go
over it about `SLAT` long with a `SEAM` of it showing between each, cut
within `SLAT_TONE` of the plank's colour off a fixed hash of the line, so a
figure is laid the same every time, each with a light along its upper edge.
While the walker lays a plank **each slat lands as the walker clears it**
(`SLAT_POP`, pop-in's squash read across the plank), and a wet sheen runs
down the plank's middle behind the snail, brightest at it, fading over
`SHEEN_FADE` once it lands. Reset's shrinking planks keep their slats.

**A post has a cut face and a lipped cap**: a light on the drum's upper rim
and a darker crescent under the cap (`CAP_LIP`). **Before the stroke begins
the posts it may begin at glow green** under their drums (`GLOW_*`), which
says "start here" louder than the cap alone; the glow is in the one mesh and
static, so it costs nothing while the board is still.

**The snail was redrawn** (`ui/faces/snail_face.gd`, so the menu card and
the first-play diagram have it too). Its pale foot sank into the parchment
and an eye on its head beside two eyed stalks read as a second face: the
foot and a raised head now sit on a deep rim, the eyes are white bulbs on
the stalk tips with the pupils looking ahead, and the head keeps the mouth
and a rose cheek. STRAIN lowers the lids as well as flattening the mouth.
`SNAIL_FOOT` and `SNAIL_DEEP` are darker to match. `SNAIL_R` is 0.2, not
0.15, because the walker was a speck beside a post.

**The walker crawls.** On a post it stands on the drum's rim above the cap
(`POST_LIFT`), which it must never hide; out on a line it comes down to ride
the plank it is laying (`PLANK_LIFT`), climbing between the two within
`CLIMB` of a post. On the line it leans with the line up to `TILT_MAX`, and
it stretches and gathers (`CRAWL`, `CRAWL_RATE`) where it used to rock. A
change of heading turns it round over `TURN`, narrowing to its edge and never
to nothing, where it used to flip on one frame.

**The win lights the jetty.** As the warmth runs back along the trail in walk
order a glint runs down each plank (`GLINT`), and every cap turns toward
`SUN_RAY` as the wave reaches its post (`CAP_WARM`).
`restore_completed_board()` opens onto the settled picture, golden caps
included.

Under reduce motion none of it moves: no slat lands, no sheen, no glint, no
crawl, lean or turn, and the win's caps are golden at once.

**Measured** on this Mac at `--resolution 810x1440` with
`tests/_shot_anim.gd -- oneline`, before and after in the same session.
Draw calls are unchanged: **63** played and **60-61** bare. The played idle
reads 2.20 and 2.19 ms against 1.83 and 1.82 before, and that is the
harness's window and not a settled board: an instrumented run showed the
board rebuilding until the sheen's fade ends, about 0.1 s into the window,
and nothing after. The bare board reads 2.04 and 2.05 against 1.95 and 1.95.
The reduce-motion pair 1.5 s apart is pixel-identical, and under reduce
motion ANGLE matches the default driver to a max channel delta of 1/255. The
menu reads 260 calls. Suite 122583/0; `tests/_win.gd` windowed 21/21. A
throwaway probe walked a whole figure a tap at a time and shot every walk
mid-line and the win as it played and settled.
