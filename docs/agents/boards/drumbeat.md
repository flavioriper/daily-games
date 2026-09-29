# Drumbeat

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Drumbeat is the twenty-eighth card** (2026-09-28,
  `puzzles/drumbeat2d.gd`, `puzzles/drumbeat_state.gd`,
  `ui/faces/drumbeat_parts.gd`, spec `2026-09-28-drumbeat-flat-design.md`,
  no concept tab -- built while the user was away). The drum-festival
  rhythm game the spec names once to forbid; **it is called Drumbeat**.
  It is a grid board, not an Arcade game, by the user's word: clearing the
  day's song (soul gauge at or over 80% when it ends) is the solve, and a
  song under the line is played again. Red notes on the drum's skin, blue
  anywhere else, big notes with two fingers, drumrolls, balloons, Go-Go.
  Two things travel: **a rhythm game's music and charts come out of one
  script** (`tools/gen_drumbeat.py` synthesises three original songs and
  writes `content/drumbeat.json` off the same bar grid, charts written at
  Hard and thinned to Medium/Easy by a minimum gap), and **a sound fired on
  every note needs its own voice pool**: `Fx2D.cue` drops a repeat inside
  60 ms. The clock is the music's playback position corrected by the mix
  and the output latency, with a per-phone timing nudge on the start card
  (`user://drumbeat.cfg`). `tests/_shot_drumbeat.gd` plays it with a bot;
  `tests/_probe_drumbeat.gd` plays every chart headless. 63-73 draw calls
  in play, ~124 in Go-Go, ANGLE agreeing. 16 cues generated, one take a
  cue, and the songs, awaiting the user's listen.
  **Polished and made loud on 2026-09-28** (the spec's section 7): a crowd
  of critters (`Parts.critter`) that gathers as the soul gauge fills and
  cheers, fireworks, fever tiers off the combo (lit rails, a drum aura,
  edge glow), the combo on the drum's skin, the beat shown by the ring,
  lanterns, drum and a marquee of its tacks, streak words, a count-in, and
  a 3.2 s finale. **A look that only turns and swells is a cached mesh
  under the transform**: the rainbow aura rebuilt a frame cost up to 6 ms
  here. 79 draw calls in play, ~141 at Go-Go's start, idle 5-8 ms and
  ~10 ms over Go-Go's burst, ANGLE agreeing; reduce motion ~4-5 ms.
  `tests/_shot_drumbeat.gd` keeps its own progress file and sets `reduce`
  after `main.tscn` loads (set before, it never took).
