# Sunbeam

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Sunbeam is the twenty-second card** (2026-09-26, `puzzles/sunbeam2d.gd`,
  spec `2026-09-26-sunbeam-flat-design.md`, mock
  `docs/brainstorm/concepts.html#sunbeam`). A greenhouse floor: drag brass
  mirrors and copper cups along their rails, the beam re-traced live; light
  every dewdrop, then end in the bud. The reference ships as a game this
  repo names once in the spec to forbid; **it is called Sunbeam and nothing
  else**. Two things travel: **a proof bounded by the pieces' own freedom
  needs no cap** -- `sunbeam_gen.gd`'s `count()` follows the beam and
  branches only on a peg it reaches, so it is exhaustive at 83 ms worst
  (Hard) -- and **hit-test a two-cell piece as the box round both cells**:
  a cup's middle is the line between them, the point a thumb aims at, and a
  per-cell strict test missed it. **What is drawn is a ray, what is judged
  is the grid**: the beam is cast against each piece where it is drawn
  (mid-drag, mid-settle) so it bends continuously, and on pegs it equals the
  grid trace, which alone decides the win. Its drawing is `ui/faces/sunbeam_parts.gd`,
  shared with the menu card. 65 draw calls played, 68 solved, ANGLE agreeing.
  Sounds generated (2026-09-26), one take a cue, awaiting the user's listen.
  **Polished on 2026-09-26** (the spec's amendment): a dressed greenhouse (a
  potting shelf, a window box, light shafts, slab tiles, moss), the glow wide
  enough to pool on the floor, pulses flowing out of the sun and a twinkling
  star on every struck mirror at rest, a lift, a sheen and a landing peg on
  a held piece and a dip and a puff when it lands, a bloom that unfurls (the
  shut bud used to vanish as it began), and a gold wave down the beam on the
  win. 65 at rest, 69 solved; a drag frame costs ~1.7 ms more on this Mac.
- **The second polish, 2026-10-01** (unattended, spec
  `2026-10-01-sunbeam-polish-design.md`): Hard and Insane can be lost, and
  the rule is about **where the light is let go**, never where a piece
  stands -- holding a piece is a free peek, and a move released with the
  light resting on a **sleeper** costs a heart and slides back
  (`State.judge`, `_misstep`). Hard's sleepers are three **snails**
  (`Gen.lay_snails`: never on a reference way home, where near misses put the
  light); Insane is **Shy Dew**, whose sleepers are the drops themselves, so
  the last move lights them all at once (`Gen.dark_path`, exact BFS over
  arrangements on the lean tracer `Gen.Fast`; 200 banked floors, each needing
  a detour). Two lessons: **a board with no wrong placement can still judge
  its release** -- price the state a move is let go in, and prove a way home
  through unpriced states, so backtracking is always safe; and **"long ago"
  is not a negative time** -- `t - 100` read as "never" in the first 100 s
  after launch and showed a restored day's bud shut (both clocks use `AGO`
  now). Rewards, party and the GLASSHOUSE sound set as Caterpillar's. Peak
  107 draw calls (out of hearts), ANGLE agreeing on the solve.
