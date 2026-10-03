## Haptics (started 2026-10-03)

The phone buzzes through `core/haptics.gd`, and nothing else calls
`Input.vibrate_handheld`. It is a vocabulary, weakest first, and the order is
the rank:

| Kind | Feel | For |
|---|---|---|
| `TICK` | one faint pulse | a selection moved: focus, a brush armed, Undo, a clear, every button |
| `TAP` | one light pulse | a piece set down, a reset |
| `BUMP` | one firm pulse | something finished or locked: a line, a milestone, a reveal |
| `GOOD` | soft then firm | a small yes: a hint, a clean check, a heart back |
| `WARN` | two even pulses | not yet: a rule broken, a check that found something |
| `THUD` | one heavy pulse | a stamp, a slam |
| `BAD` | two hard knocks | a mistake that cost something: a heart |
| `LOSE` | a long fall | the day is lost |
| `WIN` | three rising knocks | solved |

Rules:

- **A board names kinds, never milliseconds.** The patterns live in
  `Haptics.PATTERNS`; a board that wants a new feel adds a kind there, with
  its rank, for every board.
- **A board maps its cues**: `fx.haptics = HAPTICS` (cue name -> kind) once,
  where it makes its `Fx2D`. A mapped cue buzzes whenever it fires, sound
  file or not, so a cue kept silent on purpose (Binairo's `focus`) can still
  tick. Anything that is not a cue calls `Haptics.play(kind)`.
- **One pulse in the motor.** A kind asked for while another is playing lands
  only if it outranks it. So a frame's cues come out as the strongest of
  them (place, focus, line -> the line's bump), a per-cell cue cannot rattle,
  and a button's tick never stacks on the board's answer to it.
- **Up means good, even pairs mean not yet, hard knocks cost something**:
  the same grammar as the sounds (`docs/agents/sound.md`). A win and a loss
  must never feel alike with the sound off.
- **Do not buzz what the hand did not do.** The entrance, idle life, a
  blink, scenery, the streak's pluck over a tap that already spoke: nothing.
  A buzz answers a touch or says a judgement.
- **A judgement that waits, buzzes when it lands.** Binairo's blush cue fires
  for a sun on its way to a moon; its warn waits out `WRONG_GRACE` and looks
  again (`_recolour`), like the hearts do. Map a cue only when it fires at
  the moment the player should feel it.
- **Nothing under 12 ms** (a cheap Android motor does not spin up) and
  nothing continuous: a drag ticks on the cells it crosses, it does not hum.
- **The switch**: Settings > Vibration (`[haptics] on` beside Motion's and
  Sound's, `haptics_toggled`). `Haptics.load_settings()` runs from
  `world/main.gd`. Android needs `permissions/vibrate` in the preset (set).
  Off the phone nothing buzzes, and everything else still runs.
- **Checking a board**: `Haptics.trace` (an Array) collects the name of
  every kind that lands. `tests/_probe_perf.gd -- <id> d=<n> x=buzz` runs the
  board's `_buzz_<id>` (each thing the player can do, and what landed for
  it), then plays to the win and prints the whole trace. Read the trace like
  a player: a run of right moves should be taps and bumps and end in `win`.
  Not yet felt on a phone by the user; the strengths in `PATTERNS` are a
  first guess.

"Next game on the list" means the first row below without a date.

| # | Game | Done | What buzzes |
|---|---|---|---|
| 1 | binairo | 2026-10-03 | the shared piece came with it (core/haptics.gd, the Vibration switch, every button's tick, the Android permission); tap on a tile set, tick on a clear, a given, the brush and Undo; bump on a line, a streak's confetti and the liar's unmasking; good on a hint, a clean Check and a heart back; warn on a blush that outlives the grace and on a Check that finds something; bad on a heart, lose on the last, win on the solve, thud on the flawless stamp |
| 2 | mastermind (Code Break) | | |
| 3 | balance | | |
| 4 | untangle | | |
| 5 | shikaku | | |
| 6 | tents | | |
| 7 | lightup | | |
| 8 | oneline | | |
| 9 | nonogram | | |
| 10 | queens | | |
| 11 | hiddenword | | |
| 12 | wordtrail | | |
| 13 | mushroom | | |
| 14 | sudoku | | |
| 15 | bridges | | |
| 16 | quilt | | |
| 17 | fairylights | | |
| 18 | planes | | |
| 19 | pinwheel | | |
| 20 | rings | | |
| 21 | caterpillar | | |
| 22 | sunbeam | | |
| 23 | knight | | |
| 24 | hedgehogs | | |
| 25 | slider | | |
| 26 | marigold | | |
| 27 | pixelgarden | | |
| 28 | drumbeat | | |
| 29 | trestle | | |
| 30 | snooker (Versus) | | |
| 31 | chess (Versus) | | |
| 32 | checkers (Versus) | | |
| 33 | firefly (Arcade) | | |
| 34 | molehill (Arcade) | | |
| 35 | stackwood (Arcade) | | |
| 36 | thirteen (Arcade) | | |
| 37 | posy (Arcade) | | |
