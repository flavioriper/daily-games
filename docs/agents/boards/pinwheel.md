# Pinwheel

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Pinwheel is the eighteenth board, and the first piece in the game that
  turns** (2026-09-20, `puzzles/pinwheel2d.gd`, `puzzles/pinwheel_state.gd`,
  `puzzles/pinwheel_gen.gd`, spec `2026-09-20-pinwheel-flat-design.md`, mock
  `docs/brainstorm/concepts.html#pinwheel`). A rectangular frame of cells and
  a handful of cloth polyominoes lying on it, each pinned through **one of
  its own cells** by a paper pinwheel whose board cell never moves. Tap the
  pinwheel and the piece takes a quarter turn clockwise about the pin. A cell
  two pieces are on goes dark; a cell nobody is on stays bare ground; turn
  every piece until there is neither, and the frame is covered exactly once.
  **It is called Pinwheel and nothing else**, in code, in a comment or on
  screen: Puzzmo ships the genre under its own name, which the spec records
  once in order to forbid it. It is the newest link in the chain this file
  **names rather than numbers** -- Code Break, Hidden Word, Word Trail,
  Bridges, Quilt, Paper Planes and now Pinwheel -- for the reason Paper
  Planes' bullet already gives: two branches numbered it two different ways
  on the same day.
  **A tap must skip an out-of-frame orientation, not refuse it**, and this is
  the one thing on this board a future board would otherwise re-derive the
  hard way. Rotation is a discrete state change, so a piece cannot pass
  *through* an illegal orientation on the way to a legal one: a 1x4 bar
  pinned at its end against the frame edge has its solving orientation two
  clockwise steps away with an out-of-frame step in between, and a refusing
  tap makes that solution unreachable for ever. **The generator cannot see
  it**, because it reasons about orientation *sets* and not about
  reachability, so the boards it hands out would be unsolvable and every
  test would pass. Skipping fixes it by construction: the in-frame
  orientations form a cycle, a tap advances one place round it, and every one
  is reachable from every other.
  **A pinned piece cannot translate, so it has at most four placements in the
  whole frame** -- and that is why `puzzles/quilt_gen.gd`'s header warning,
  that a patch free to rotate would make almost every region tileable a dozen
  ways and uniqueness would stop being worth proving, **does not apply here
  and must not be carried over**. Quilt's patches translate and Pinwheel's
  cannot, so Pinwheel is far *more* constrained, the exact cover collapses
  almost at once, and **the proof is the cheap stage here where it is the
  expensive one on Quilt**. There is no wall-clock give-up and no
  `graded: false`: the attempt loop is bounded by `ATTEMPTS` and the honest
  flag is Quilt's `unique: false`.
  **A legibility rule measured against the solved frame is measured against
  the state the player spends the least time in.** The piece colouring
  shipped once on a rule that forbade a shared cloth to two pieces that could
  overlap or that touched *in the answer*. Every measurement behind it was
  true -- at most seven colours over 180 boards, zero clashes over 600 -- and
  the promise was about the wrong state: over 300 seeds a band it left a
  same-cloth pair **orthogonally touching in the opening** on **149, 219 and
  241 boards of 300** (re-measured 145, 214 and 233 on a different seed
  block), and two apricot pieces edge to edge read as one shape. The fix was
  not a weaker rule but a wider graph -- one piece's orientations dilated by
  one orthogonal step meeting the other's, which holds in *every* state the
  board can be in -- and **rejecting the boards eight cloths cannot colour**,
  which costs 3, 17 and 132 extra grows out of 619, 721 and 1125, about ten
  percent on the worst band. Rejection is affordable only because generation
  is. **Any board that colours, shades or outlines its pieces to keep them
  apart should check the rule against the opening, not the answer.**
  **And a wash alone cannot signal state on pieces coloured by index.** The
  stain over a doubled-up cell was first drawn as `Pal.TEXT` at 0.30 and
  nothing else, and on the first rendered band-0 frame a coral under it came
  back as **a maroon piece** and a butter as an olive one -- not "shaded",
  *another cloth*, and a player counting pieces would have counted them. So
  the stain is also **hatched**, diagonal lines in `Pal.TEXT` at 0.20 drawn
  across the union of the stain rather than per cell, because **a hatch
  cannot be mistaken for a cloth**: nothing else on the screen is drawn in
  lines. That is Quilt's "a patch cannot blush" from the other end -- there
  the refusal could not be a colour, here the state could not be -- and
  together they are the general form: **on a board whose pieces are coloured
  by index, no state may be signalled by a shade of the piece's own colour.**
  The refusal on this board follows the same rule and is Quilt's exactly: a
  `Pal.BAD` halo stroked round the silhouette with the shiver, the cloth left
  alone.
  **The turn is its signature and the one thing it added to
  `core/motion.gd`**: `TURN_TIME` 0.26 and `turn_angle()`, a curve reader on
  `back_out`, because a quarter turn is a thing the next board may want and
  every turn before it was an idle or Hidden Word's flip, which is a scale on
  one axis and not a rotation. The piece and its pinwheel read the same
  recipe with different `time`s -- the blades go on to 1.55 times it, so the
  handle carries the overshoot the cloth does not -- which is one recipe and
  one parameter, not two numbers. The stain settles in **Queens' `_settle` in
  a fourth shape**: a snapshot of `cover` diffed before against after, each
  changed cell taking king-move distance from the pin at `Motion.WAVE_STEP`,
  derived and never stored, so a hint that walks a piece through three
  quarters and the undo that walks it back both animate with nothing to clean
  up. Only two constants are the board's own and both are shape rather than
  timing: `STAIN_ALPHA` 0.26 and `PIN_R` 0.19.
  **Its cell is 183 on the shipping band, the largest of any flat board** --
  against Paper Planes' 58 at the other end -- and that is not indulgence: the
  tap target is the pin cell and nothing else, so the input surface is `N`
  cells out of `cols * rows` and a generous cell is what stops a mis-tap
  turning a neighbour. It seats no character (the fifth board to seat none)
  and adds `ui/faces/pin_wheel.gd`, a drawing rather than a character, the
  third after Nonogram's tile and Quilt's cloth; its cloth is Quilt's
  unchanged.
  Measured with `tests/_shot_anim.gd -- pinwheel` at `--resolution 810x1440`,
  2026-09-20: **59** draw calls played and 59-60 bare (the 60 is one frame's
  worth of the wordmark's sun-dot glint, inferred and not measured), 59 under
  reduce motion, against the 855 budget -- the third-cheapest board in the
  game behind Paper Planes' 55 and Quilt's 58, and **a turn costs nothing
  measurable**, because the swinging piece, the stain and eleven pinwheels
  are all inside the same three meshes as the bare board. Queens (71, 71) and
  Word Trail (65, 65) reproduced their recorded counts as controls at both
  ends of the session, which is what makes those counts quotable; the
  milliseconds are not, because Queens read 2.83-2.89 there against the 3.83
  of its own spec. **59 again after `main` was merged in**, with Paper Planes
  in the tree. ANGLE agrees on 59 and 110,002 pixels of 1,166,400 differ by
  **no more than 1/255**, the tightest agreement between the two drivers any
  board here has recorded; the reduce-motion pair 1.5 s apart is
  pixel-identical, in both runs. Generation worst **9.08 ms** in the quiet
  session and 16.42 ms in a loaded one, against the 194 ms gate.
  **Polished on 2026-09-26** (the spec's amendment): Quilt's printed cloth
  and quilting stitch on every piece, a resting shadow that says which of
  two pieces is on top, a tufted backing, the stain's wash down to 0.12
  with a dashed outline carrying the state, and folded pinwheels at 0.28
  with the piece's deep cloth on two vanes and a brass hub (a push-pin for a
  piece pinned fast). A swing lifts and lands with a squash and a puff. An
  idle breeze spins one wheel a half turn every few seconds, never
  continuously, and the win is a gust through every wheel. 56 draw calls
  bare, 57 played, ANGLE agreeing.
