# Super Slider

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Super Slider is the twenty-fifth card** (2026-09-26,
  `puzzles/slider2d.gd`, spec `2026-09-26-super-slider-flat-design.md`, no
  concept tab -- built while the user was away). The 4x5 sliding-block
  family after a handheld the user brought: drag blocks through the empty
  cells (round corners, one drag one move) until the big red block walks out
  of the gate at the bottom. The name is the user's; the handheld sells as
  *Super Slide*, one letter off. Two things travel: **a position is one int**
  (twenty 3-bit cell codes, so like blocks are interchangeable and a
  neighbour is `key - here + there`), and **one breadth-first pass over the
  whole graph plus one back from the goals gives every position's distance**,
  so a hint from anywhere is a lookup -- it reproduces the classic layout's
  published 25,955 positions and 81 moves in 0.3 s on this Mac (1.2 s for
  the largest shipped graph, 105k positions), and runs on a
  `WorkerThreadPool` task from the moment the tray opens; a closed tray
  tells it to stop rather than waiting. The trays are
  mined (`tools/mine_slider.gd`, `tools/merge_slider.py`,
  `content/slider.json`), never grown on the phone. Drawing is
  `ui/faces/slider_block.gd`, shared with the menu card; the board clips,
  because the big block walks out past the frame. 67 draw calls bare and
  played, 68 on ANGLE. Sounds generated (2026-09-26), one take a cue,
  awaiting the user's listen.
  **Polished on 2026-09-26** (the spec's section 8): bushes, clover and
  daisies on the lawn, a grained frame with brass corner pegs, hollows in the
  empty cells, plank doors with a latch, grained blocks; a held block glides
  after the finger and leans with its speed, kicks dust, knocks and makes its
  neighbour flinch; the big block watches the held one and blinks; a hint
  leaves a dotted trail; the big block hops out in three steps. 68 played,
  67 on ANGLE, reduce motion pixel-still.
