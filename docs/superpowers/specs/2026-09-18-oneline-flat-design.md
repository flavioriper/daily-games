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
