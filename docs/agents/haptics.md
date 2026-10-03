## Haptics (started 2026-10-03)

The phone knocks through `core/haptics.gd`, and nothing else vibrates it.

**On Android a kind is one of the system's predefined effects, not a timed
pulse** (2026-10-03). The first build used `Input.vibrate_handheld`, which is
`VibrationEffect.createOneShot`: the motor spun for N ms and left to ring
20-50 ms more, the buzzy kind Android's own guidance says to avoid. The user
felt it at once ("too much", against a game whose buzz is "a subtle hit inside
the phone, not a vibration"). `createPredefined(EFFECT_TICK / EFFECT_CLICK /
EFFECT_HEAVY_CLICK)` is a waveform the phone's maker tuned and brakes, one
crisp knock, and `Haptics` calls it through the `AndroidRuntime` singleton
and `JavaClassWrapper` (no plugin). `vibrate_handheld` remains only as the
fallback (Android under 10, iOS): one short weak pulse a kind.

The kinds, weakest first; the order is the rank:

| Kind | Android effect | For |
|---|---|---|
| `TICK` | tick | a clear, an Undo |
| `TAP` | tick | a piece set down, a reset |
| `BUMP` | click | something finished or locked: a line, a milestone, a reveal |
| `GOOD` | click | a small yes: a hint, a clean check, a heart back |
| `WARN` | click | not yet: a rule broken, a check that found something |
| `THUD` | heavy click | a stamp, a slam |
| `BAD` | heavy click | a mistake that cost something: a heart |
| `LOSE` | heavy click | the day is lost |
| `WIN` | click, then heavy click | solved |

Several kinds share an effect on purpose: the kind is the meaning and the
rank, the effect is what three strengths of knock can say. Only the win is
more than one knock.

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
- **Less is more.** What happens on every touch gets the faintest knock or
  none: no buzz for a button, a focus, a brush armed or a selection moved
  (all removed 2026-10-03). Stronger knocks are for what is rare: a line, a
  heart, the solve. Never a pattern of pulses for a mistake.
- **Do not buzz what the hand did not do.** The entrance, idle life, a
  blink, scenery, the streak's pluck over a tap that already spoke: nothing.
  A buzz answers a touch or says a judgement.
- **A judgement that waits, buzzes when it lands.** Binairo's blush cue fires
  for a sun on its way to a moon; its warn waits out `WRONG_GRACE` and looks
  again (`_recolour`), like the hearts do. Map a cue only when it fires at
  the moment the player should feel it.
- **The win knocks when the player learns of it**, which is not always the
  `solved` cue: Code Break's fires under the Check press, a second before
  the lids come off, so its win is played from `_reveal`. A seal's thud is
  played from the drop's landing callback, not from the `stamp` cue that
  starts the drop.
- **A cue the board also fires for its own moves is not mapped.** Balance's
  `land` and `step` fire for a hint, Undo, Reset, a bounce and the shown
  answer as well as for the fruit the hand let go: the board marks that one
  (`_by_hand`) and knocks as it lands. A refused touch (a full row, a hinted
  seat, a pinned fruit) says nothing, like Binairo's given.
- **A milestone bumps, a right move taps.** A move that is merely right is
  what happens on every touch: Untangle's peg home is a tap and only a rope
  left free (or two crossings gone at once) is a bump; Shikaku's bed is a
  tap fitting or not, and the streak bumps only at its confetti.
- **A limit felt under the hand ticks once.** Untangle's rope going taut is
  the reach rule in the fingers: one tick as it strains, none again until it
  slackens, and nothing more when the peg is let go out of reach and flies
  home.
- **A sweep knocks once, as it is let go.** Tents' cairns and Light Up's
  chips arrive a square at a time under the finger, each with its cue: none
  is mapped, and the gesture ticks once on release if it changed anything.
- **A tutorial's board does not buzz.** Many tutorial pages play a real
  copy of the board through its own `_gui_input` (Tents' `Meadow`, Light
  Up's `Court`): the copy sets `fx.buzzes = false` in its `_ready`, and the
  board knocks through `fx.buzz(kind)`, never `Haptics.play`, for whatever
  is not a cue. Check with `_probe_perf.gd -- <id> howto`: the trace must
  come back empty. (Rows 1-5 have no such copy; every later board whose
  `ui/hud/*_tutorial_diagram.gd` extends it needs the line.)
- **A count is read, not felt**: Code Break's pips land one by one and say
  nothing; the row knocks once as it is scored.
- **Nothing continuous**: a drag knocks on the cells it crosses at most, it
  does not hum.
- **The switch**: Settings > Vibration (`[haptics] on` beside Motion's and
  Sound's, `haptics_toggled`). `Haptics.load_settings()` runs from
  `world/main.gd`. Android needs `permissions/vibrate` in the preset (set).
  Off the phone nothing buzzes, and everything else still runs.
- **Checking a board**: `Haptics.trace` (an Array) collects the name of
  every kind that lands. `tests/_probe_perf.gd -- <id> d=<n> x=buzz` runs the
  board's `_buzz_<id>` (each thing the player can do, and what landed for
  it), then plays to the win and prints the whole trace. Read the trace like
  a player: a run of right moves should be taps and bumps and end in `win`.
  The trace says which kind landed, not how it feels: the native call
  cannot run on this Mac, so only a phone proves it.

"Next game on the list" means the first row below without a date.

| # | Game | Done | What buzzes |
|---|---|---|---|
| 1 | binairo | 2026-10-03 | the shared piece came with it (core/haptics.gd, the Vibration switch, the Android permission); tap on a tile set, tick on a clear and Undo; bump on a line, a streak's confetti and the liar's unmasking; good on a hint, a clean Check and a heart back; warn on a blush that outlives the grace and on a Check that finds something; bad on a heart, lose on the last, win on the solve, thud on the flawless stamp; nothing for a given, the brush or a button |
| 2 | mastermind (Code Break) | 2026-10-03 | tap on a friend seated and Reset, tick on one sent back and Undo; bump once as a full row is scored (`check`, not a cue); good on a hint, a new best in the right seats (Warmer!, So close!), every friend present and a bought row; warn on Check with seats empty; lose out of rows; win as the lids come off (`_reveal`), thud as the seal lands; nothing for the pips, a palette tap on a full row, a hinted seat tapped, the clean miss's sunglasses, the Shell Game's swap, the peeks. Probed Easy and Insane; out of rows and the bought row are mapped but not probed |
| 3 | balance | 2026-10-03 | tap as a fruit the hand let go lands in a cup, tick as one tapped or dropped home gets there (`_by_hand`, not the `land`/`step` cues); good on a far toss that lands (over the tap), a hint and One more hour; bump on the beam level with fruit still to place; tick on Undo, tap on Reset; bad on Insane's bounce; lose at sunset; win on the solve, thud as the seal lands; nothing for a fruit lifted, a pinned fruit, the beam at rest off level or on its bale, the cheers, the sun tapped or getting low, and every fruit the board moves itself. Probed on all four bands; the level, the bounce and the sunset are mapped but not probed |
| 4 | untangle | 2026-10-03 | tap as the peg the hand let go lands in its hole, bump instead when that left a rope with no crossing or undid two at once (`_landed`, not the `drop` cue, which the kitten's swat and a hint's flight fire too); tick once as the rope goes taut in the hand (`_update_held`; the pluck shares the cue and says nothing); tick on Undo, tap on Reset; good on a hint and One more spool; warn on the thread running low; lose out of thread; win on the solve (it waits for the last peg to land), thud as the seal lands; nothing for a peg lifted, selected or put back, a hole hovered, a braid cinching or unwinding under the hand, a stuck peg or a drop out of reach, a stitch, the kitten petted, pouncing or swatting, the shown answer. Probed Easy, Hard and Insane; out of thread and the spool are mapped but not probed |
| 5 | shikaku | 2026-10-03 | tap on a bed fenced (fits its sign or not: the sign's face says that), tick on one tapped away and Undo; bump where the streak's confetti flies (5, 10); good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart, lose on the last; tap on Reset and Try again; win on the solve, thud as the seal lands (`_stamp_at` + `STAMP_DROP`, flawless or Insane); nothing for the wash growing under the finger, a tap on bare ground, a drag refused on a pinned or taken bed, the sprout, the streak's pluck, the gags. Probed on all four bands; the last heart and the heart back are mapped but not probed |
| 6 | tents | 2026-10-03 | tap on a tent pitched (fair or not: its face and the chips say that), tick on one struck and Undo; one tick as a sweep is let go, laying cairns or rubbing them out (`_release`; the per-square `cairn`/`clear` are not mapped); bump on an oak given its second tent and where the streak's confetti flies; good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart, lose on the last; tap on Reset and Try again; win on the solve, thud as the seal lands (flawless or Insane); nothing for the sweep under the finger, a tree or a pegged tent tapped, the trees' hops, the streak's pluck, the gags, the tutorial's meadow. Probed Easy, Hard and Insane; the last heart, the heart back and a Check that finds something are mapped but not probed |
| 7 | lightup | 2026-10-03 | tap on a lamp set down (fair or not), tick on a lamp or a chip tapped up (`_commit`: the `strike` cue is also the board blowing a wrong lamp out, `clear` also the sweep's) and on Undo; one tick as a sweep is let go; bump on a cat whose number the hand's own tap met (`_by_hand` in `_cat_turns`: `purr` fires on Undo and a hint too) and where the streak's confetti flies; good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart, lose on the last; tap on Reset and Try again; win on the solve, thud as the seal lands (flawless or Insane); nothing for the sweep under the finger, a block, a cat or a pinned lamp tapped, a block's hop, a napping cat woken, the wrong lamp blown out, the streak's pluck, the moths, the gags, the tutorial's court. Probed on all four bands (the last heart on Hard, by a probe that slipped); the heart back is mapped but not probed |
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
