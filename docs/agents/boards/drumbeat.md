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
  **Rebuilt on 2026-10-01 as four drums** (spec
  `2026-10-01-drumbeat-polish-design.md`): a guitar-highway path of four
  lanes to the big, hand, jingle and tongue drums, each with a face and its
  own synthesised voice; taps, chords, holds (ribbons), rolls, balloons.
  Three lessons travel. **A chart must be made from the same events as the
  music**: the hand-written sixteenth strings ran beside the tune, and
  players heard "weird rhythms" -- `gen_drumbeat.py`'s `bar_events` now feeds
  both. **Android reports no output latency** (`get_output_latency()` is 0),
  so a rhythm board measures the phone with a tap-along before its first
  song and keeps the result. **The song's clock runs off the microsecond
  clock and is only steered by the playback position** (≤1 ms a frame, never
  back); easing toward the position every frame made the notes shuffle.
  Hard 3 hearts, Insane 2 (three misses in a row, or a song under the line);
  out of hearts the music winds down. **Insane is Echo**: bars in pairs, the
  second repeats the first with its berries hidden. The tune is its own stem
  and dips while notes are let past. `_shot_drumbeat.gd` takes `tune`,
  `revive` and `miss full` (out of hearts) and puts `user://drumbeat.cfg`
  back; `_probe_drumbeat.gd -- jitter slips lag`. 84-137 draw calls in play,
  ~222 at Go-Go's burst (ANGLE 250). `_win.gd` has no driver for it (a
  real-time board), so it reports FAIL there by construction.
  **Rebuilt on 2026-10-03 as one road** (the user's reference and word; the
  playable mock is `docs/brainstorm/concepts.html#drumbeat`). The four lanes
  were a misreading: what was meant was one track, every berry riding it
  right to left into one ring, and several drums to tap in place of the
  reference's kinds of stroke. A berry names its drum by its colour and by
  the drum's mark under it on the road's strip (dot, triangle, square; the
  same mark is on the drum's skin), and the drum the next berry wants glows
  as it nears the ring. **One drum on Easy, two on Medium, three on Hard and
  Insane, never more** (`State.DRUMS`, `DRUM_KINDS`: big; big and tongue;
  big, hand and tongue -- the jingle drum is out of the band, its voice and
  drawing still in the tree). Two at once are twins, one over the other
  (`_rows`). **A day's song is 21-25 seconds** (the user: twenty to thirty at
  most): a bar of pick-up, a verse, a Go-Go chorus, a last chord, and
  `gen_drumbeat.py` writes each level's chart for its own drums
  (`DRUM_COUNT`, `tune_lanes`); Echo pairs from the verse's first bar. With
  songs this short the fever tiers are combos of 10, 25 and 50 and the conga
  comes at 30. The judging, gauge, hearts, clock and tap-along are as they
  were. Hard through the win on native GL: 84-107 draws in play, 207-263 at
  Go-Go's burst (ANGLE the same counts); suite 249741/0.
  `_shot_drumbeat.gd` no longer waits for a balloon a song does not have.
  The whole concepts page no longer renders in headless Chrome inside 100 s;
  shoot one tab from a standalone copy (the head, the tab's section, its
  script).
- **Checkup (2026-10-03, `docs/agents/checkup.md` row 28).** The board still
  redraws every frame, but nearly nothing is made on the frame: `_shape(id)`
  makes each drawing once at this layout (the S_ constants: bar line, bead,
  marks, ribbon ends and body, ring, pulse, flash, wash, rails, veil and its
  stars, glow, ripple and burst steps, the gauge's ticks, glint, star,
  hearts, and the gauge's fill a shape a width) and three `RunMesh`es with no
  rooms copy them: `_road` (under the berries), `_top` (gauge, hearts, glow,
  bursts) and `_over` (ripples and the edge glow, over the drums). A tinted
  shape is in slot 0 and painted through `_q` (24 steps). `_drum_look` is a
  drum with its mark baked in; `_fw` holds a firework's 32 steps and
  `_draw_fireworks` copies them into the sky's mesh; `_queue_warm` makes the
  song's looks two a frame from the open; `_first` skips the notes long
  gone. `_staged()` is the stage (sky, lanterns, crowd, Tam, fireworks,
  cards, combo): the tutorial's board answers false. The tutorial is
  `ui/hud/drumbeat_tutorial_diagram.gd` (lessons STRIKE, DRUMS, HOLD, ROLL,
  SOUL, ECHO, HUD): a `Road` with no music or voices running a hand-made
  chart, a finger a drum. The song pauses when the ? or the settings come up
  (the edge of `clock_held`); a tap on a drum goes on. No Undo. Probe:
  `tests/_probe_perf.gd -- drumbeat d=3 to=40` plays the whole song with a
  bot on the frame; `song=parade|festival|gallop`, `x=db_count`, `x=db_hud`,
  `x=db_spike`.
- **Haptics (2026-10-03, `docs/agents/haptics.md` row 28).** A stroke that
  played a berry taps from `strike`; what it earned (a combo called, the
  golden berry, a pop, a hidden bar) is the knock in its place. Probe:
  `tests/_probe_perf.gd -- drumbeat d=<n> x=buzz` (`_buzz_drumbeat` lets
  berries past by `_db_hold`, runs out of hearts on Hard and Insane, then
  the bot plays the song through).
