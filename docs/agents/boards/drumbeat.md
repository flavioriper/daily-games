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
- **Sounds redone against the cozy rules (2026-10-10, `docs/agents/sound.md`,
  the `drumbeat` row).** The 26 cues of `tools/gen_sfx.py` are low ticks,
  breaths and muffled notes, none above -8; `fail` is kept. The balloon's
  tock climbs 0.028 a stroke and holds at five semitones (`CLIMB_TOP`,
  `BALLOON_CLIMB`; it was 0.04 a stroke up to 1.48). The drums, the songs,
  their tunes and the tap-along (`tools/gen_drumbeat.py`, eleven files) are
  untouched and still fail the measure: owed. Unheard.

**One drum, pitched (2026-10-10).** The user: the blue drum's "metalic sound
is terrible, all tambors should have basically the same drum sound only with
different pitches". `tools/gen_drumbeat.py drums` writes `drum_0` to `drum_3`
from one `drum(ratio)`: a felt-beaten skin at 1, 1.5, 2 and 2.67 times 105
Hz, a little shorter as it rises, its octave and twelfth strong enough
that a phone's speaker (nothing under 250 Hz) still plays each its own note. `DRUM_KINDS` still plays 0, then 0
and 3, then 0, 1 and 3. Unheard.

### The festival evening is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/drumbeat_world.gd` is the festival's
evening kept light (cream over the host's rows, apricot, the stage's low
sky), the sun going down behind the hills, a cloud and two early stars in
the gap of the tools row, and the festival mat from the horizon past the
foot with crossed drumsticks, a tambourine and confetti under the drums.
**The scene runs edge to edge** from under the tools row to the foot (a
road cut at the margins would read as a panel): the Control is moved down
under the rows and every bare `size` became `_sz()`. The paper card,
the dark sky with its stars and moon, and the mat went to the world. On
the win there is no scale: the scene tilts down into the win's span, the
drums fade out, the cat curls up on the road, and the sparks, the rewards
and the cat drop to z 0 so nothing draws over the host's cards.

- Registry: `bleed`, `level_card`; `capabilities()` is still empty,
  so Undo and Hint stand greyed on the tools row and the bin restarts.
- `opengl3_angle`, 810x1440, `tests/_shot_drumbeat.gd -- <dir> d=0
  full`: 93 to 103 draw calls in the song, 124 in Go-Go, 82 on the win.
- Decided for the user, unconfirmed: a light evening; a stage of 332 at
  1920 (about 500 in the card); drums 8% larger. Owed: a phone, the user's
  ear on nothing having moved in time.

### Made fun (2026-10-29)

The user: "make trestle and drumbeat experience way better to play, and game
itself way funnier to play, right now nobody likes it". The genre's
references are praised for clear right/wrong cues and forgiving windows,
and faulted for not saying whether a stroke was early or late.

- **Measured first** (`tests/_probe_db_fun.gd -- sd lag wrong skip`, a
  thumb off by a normal error around a lag, a share of strokes on the wrong
  drum or none, ten seeds a song). Before: a player 60 ms off, 30 ms late,
  8% wrong and 5% missed cleared Easy 27/30, Medium 9/30, Hard 0/30; one
  45 ms off cleared Insane 0/30.
- **Fairer gauge and windows** (`drumbeat_state.gd`): GOOD 75/70/60/55 ms,
  OK 140/130/120/110, BAD 170/160/150/140; an OK fills three quarters of a
  GOOD (`OK_GAIN`, was a half), a BAD drains one GOOD (`BAD_DRAIN`, was
  two). Now: 60 ms off with no lag clears 30/25/19/3 of 30; 45 ms off with
  5% wrong 30/30/30/26 (the bot plays Echo's hidden bars from perfect
  memory); 90 ms off with 15% wrong still clears no Hard (21/4/0/0).
  Charts and music untouched.
- **Early or late** under an OK or a struck BAD at the ring (`EARLY_FONT`,
  blue early, apricot late; the keys `DB_EARLY`/`DB_LATE` were the tune
  card's).
- **The timing follows the hand** (`_follow_hand`, at the song's end): with
  12 strokes that played a note and their median off by 25 ms or more, the
  phone's timing moves 0.8 of the way, at most 60 ms a song, and the next
  card says so over its Tune button (`DB_FOLLOWED`).
- `_shot_drumbeat.gd late` / `late=<ms>` strikes every tap that late and
  shoots `2d_late`. Medium at 135 ms late: the missed card read "Timing +60
  ms to match your taps". Suite 303252/0. Not on a phone; unheard.
