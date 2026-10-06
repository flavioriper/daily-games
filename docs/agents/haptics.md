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

**What is heard is felt (2026-10-03, second word from the user).** With the
first pass done the user played Lucky Thirteen and found it "incomplete": the
pebbles sound under the finger as they are picked, and the phone knocked only
as they merged. The ask: "all sounds should have an equivalent haptic feedback
with different intensities and styles". So the sparse rule below is no longer
"silence unless a board chose a knock":

- `Fx2D.cue` knocks an **ECHO**, a new weakest kind, for every cue the board
  gave no kind, at the moment its sound really plays (a file exists, the
  60 ms `CUE_GAP` let it through, the stream is under 4 s so a song or a
  drone is not a knock). Its strength follows the sound: `volume_db` and
  `pitch` become the gain, so Thirteen's chain climbs in the hand as it
  climbs in the ear and a quiet landing is fainter still.
- An ECHO ranks under everything, so a knock the board chose on that frame
  (or still in the motor) is the one felt, and no row of the table below
  changes: the echoes fill what was silent between them.
- The button click and the menu's page turn echo too (`ui/ui_sound.gd`).
- A tutorial's board is still silent (`fx.buzzes = false`).
- **The kinds now differ in shape as well as weight.** Where the phone
  composes primitives (`VibrationEffect.startComposition`, Android 11 and up
  with `areAllPrimitivesSupported`; `Haptics.COMPOSED`) each kind is built
  from tick / click / thud at its own strength. Elsewhere the predefined
  effects carry the shape (`Haptics.EFFECTS`), and a tap is now a click so it
  stands over an echo's tick.

Not felt on a phone yet (no device on this Mac's adb): the composition path
goes through JavaClassWrapper untested, and falls back to the predefined
effects if `areAllPrimitivesSupported` does not answer `true`.

The kinds, weakest first; the order is the rank:

| Kind | Composed (primitive x strength) | Predefined | For |
|---|---|---|---|
| `ECHO` | tick x 0.35, times the sound's gain | tick | a sound no kind answers |
| `TICK` | tick x 0.6 | tick | a clear, an Undo |
| `TAP` | tick x 1.0 | click | a piece set down, a reset |
| `BUMP` | click x 0.7 | click | something finished or locked: a line, a milestone, a reveal |
| `GOOD` | tick, then click (rising) | tick, then click | a small yes: a hint, a clean check, a heart back |
| `WARN` | click, click (even, soft) | double click | not yet: a rule broken, a check that found something |
| `THUD` | thud x 1.0 | heavy click | a stamp, a slam |
| `BAD` | click, then thud | heavy click | a mistake that cost something: a heart |
| `LOSE` | thud, then a weaker thud | heavy click twice | the day is lost |
| `WIN` | tick, click, click (rising) | click, click, heavy click | solved |

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
- **Less is more, but never nothing where there is a sound.** What happens
  on every touch gets the faintest knock: a button, a brush armed or a
  selection moved is an echo of its sound, and a cue with no file (Binairo's
  `focus`) is still nothing. Stronger knocks are for what is rare: a line, a
  heart, the solve.
- **Do not choose a kind for what the hand did not do.** The entrance, idle
  life, a blink, scenery, the streak's pluck over a tap that already spoke:
  no mapped kind. Where they make a sound they echo it, and that is all. A
  kind answers a touch or says a judgement.
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
  A stroke that is itself the move (Nonogram's run of tiles) is still one
  knock on release, the strongest thing it did: a tick for crosses, a tap
  for tiles, a bump for a line. One Line's drag is the other kind: each
  plank is a move, so each taps as the finger reaches its post.
- **A trail that is one move knocks once, as it is let go.** Word Trail's
  tiles tick the ear under the finger and say nothing to the hand (the word
  is the move, not its letters, and a wrong trail on Easy and Medium is no
  move at all): the release bumps when the word locks, is a bad when it
  blows a seed, and is silent when it only unwinds. What the lock earns a
  beat later (its note, a bubble, a gag) adds nothing to the bump.
- **A knock queued behind a move checks the board is not done.** Mushroom
  Patch's flower opens `POP_IN` after the move that finished its number; on
  the move that wins the patch that bump would land after the win, so the
  queued call looks at `is_done()` first.
- **A judgement the board only says in words can knock.** One Line on Easy
  and Medium has no cue for the step that strands a line (the sprout says
  it): the board warns once through `fx.buzz` on that step, by comparing
  before and after, and not again while the figure stays lost.
- **A tutorial's board does not buzz.** Many tutorial pages play a real
  copy of the board through its own `_gui_input` (Tents' `Meadow`, Light
  Up's `Court`): the copy sets `fx.buzzes = false` in its `_ready`, and the
  board knocks through `fx.buzz(kind)`, never `Haptics.play`, for whatever
  is not a cue. Check with `_probe_perf.gd -- <id> howto`: the trace must
  come back empty. (Rows 1-5 have no such copy; every later board whose
  `ui/hud/*_tutorial_diagram.gd` extends it needs the line.)
- **A count is read, not felt**: Code Break's pips land one by one and say
  nothing; the row knocks once as it is scored. Hidden Word's five flips
  the same: the row knocks once as it shows its colours, and when it earns
  a word (Warmer!) that knock is the good, not a bump and then a good (the
  word's cue is not mapped; `_react` picks the kind).
- **A cue shared by a note and a move is not mapped.** Queens' `place` is a
  cross, a queen and every cell of a sweep, Hidden Word's `type` a letter
  and the caret moved: the hand's own function knocks through `fx.buzz`
  (a tick for the cross, a tap for the queen and the letter, nothing for
  the caret).
- **A cue that settles the board is not mapped.** Bridges' `met`, `over`
  and `split` come out of the one diff every change goes through (`_settle`,
  `_network`), so a hint, an Undo and Reset fire them too: the board raises
  `_by_hand` round the hand's own move and knocks under it (a bump for an
  islet come right, a warn for one pushed over or for the islets named in
  groups).
- **A win that waits for the piece knocks when it lands.** Bridges' `solved`
  fires as the finger lifts, with the last plank still rolling out: the win
  is played `_land_lag()` later, as the wood touches and the wave sets off.
- **A judged move's milestone gives way to its heart.** Sudoku's wrong
  number can still close a row: the line's bump is skipped (`_ejecting`) and
  the heart is that move's one knock.
- **Two milestones on one move are one bump.** Quilt's fourth good drop
  throws the streak's confetti and can finish a row a tenth of a second
  later: the row's bump is skipped on a drop whose confetti flies. A
  judgement on the move replaces its tap the same way (Quilt's dead end
  warns and the patch does not tap as well).
- **A wave of the same thing bumps once, at its head.** Fairy Lights' wash
  wakes a branch's lanterns one after another, each with its `wake`: the
  turn that lit them bumps as the first one wakes, and only when a hand
  made the turn.
- **A warn gives way to the loss it announces, and is not said twice.**
  Paper Planes' clouds closing in is a warn while a heart can still blow
  them on; with none left the sky is lost a third of a second later and the
  lose is that knock, and a heart won back to a sky the player already knows
  is stuck is the good alone (`_check_stuck`, by `fx.buzz`: `stuck` is not
  mapped).
- **A judged tap that moves nothing is the heart alone.** Pinwheel's piece
  already home does not turn, so nothing taps: the one knock is the bad as
  its thread catches. (Paper Planes' crashing plane does set off up its
  lane: it taps, and is a bad as it bonks.)
- **A milestone that rides a flight knocks when it lands, for the hand
  only.** Rings' drop taps under the finger and the ring is 0.41 s in the
  air: a peg it locks bumps as it threads home, the win knocks then too
  (`_on_solved` reads the flight; `solved` is not mapped), and a drop that
  leaves no move warns there. All three come out of `_settle`, which a
  hint's ring lands through as well, so the flight carries who dropped it
  (`_by_hand`, kept across a flight landed early by the next tap).
- **A walk over every square knocks on what it reaches, not on each
  square.** Caterpillar's drag crosses the whole bed, forty to sixty
  squares in a stroke or two: a bare square says nothing, each leaf eaten
  taps, and a stroke that reached no leaf (it only walked, or took squares
  back) ticks once as the finger lifts (`_stroke_knocked`). One Line taps
  every plank because there a plank is the move; here the leaf is.
- **A piece carried along a rail knocks as it is let go, not at its pegs.**
  Sunbeam's mirror clicks from peg to peg under the finger with the light
  re-traced live, and none of that is the move: the release is, a tap, or a
  bump when it lit a drop the light had not reached (the streak's confetti
  flies on that same move and adds nothing). One thing does tick mid-drag,
  the light touching a sleeper on Hard and Insane (`stir`, `shy`): holding
  is a free peek and letting go there costs a heart, so the hand is told
  where the price is.
- **A reply is not the hand's.** Knight's rose side answers every hop: the
  answer says nothing, and the turn knocks again only for what it did to
  the player (a rose knight taken as you land, a catch as theirs lands on
  you, the board left with no way to the king once everything is still). A
  catch that costs nothing (Easy and Medium) is a warn, one that costs a
  heart is the heart.
- **A move that opens many is still one knock, and its size is the kind.**
  Hedgehogs' rake blows one pile or a flood of forty off the same tap: the
  gesture knocks once from `_after_rake` (the `rake` and `gust` cues are not
  mapped), a tap, or a bump when the flood is `BIG_GUST` piles or more, and
  the streak's confetti adds nothing to a flood that already bumped. A rake
  that wakes a hedgehog does not tap: the wake is the knock, a warn where it
  only spoils the clean lawn (Easy and Medium, as it pops up) and the heart
  where it costs one. A long press knocks under the finger as it fires, and
  the release after it says nothing.
- **A carried block is the rail again.** Super Slider's block steps a cell
  at a time under the finger, bumps walls and neighbours, and none of it is
  the move: the release taps (`slide`), a block put back says nothing. As
  with Sunbeam's sleepers, Hard ticks once mid-drag when the held move
  turns costly (`fret`) and the heart is the knock if it is let go there.
  The win knocks as the big block lands on the mat, a second before the
  `solved` cue rings on its way out of the gate.
- **A shot is the hand's, what it sets off is not.** Marigold's seed blooms
  a dozen buds in a shot, each with its `hit`: the release taps (`shoot`)
  and the flight is read, not felt, but for what the shot was for, one bump
  as its first marigold opens (on Sweethearts, as its first pair comes
  together; a marigold alone warns as it folds back at the shot's end). The
  streak's confetti is that same shot's and adds nothing. A seed back in
  the trough is a good, caught by the pot or handed back for a big shot.
  The win is the last marigold opening (`fever`), seconds before `solved`.
- **Where an action costs a heart, the heart is its knock.** Marigold's Undo
  and Reset are a tick and a tap on Easy and Medium and the bad alone on
  Hard and Insane; the `reset` cue, which the garden growing back by itself
  fires too, is not mapped.
- **A verdict that comes after the move knocks when it is given.** Pixel
  Garden's stroke knocks once as it is let go (a tap when it seated a bead,
  a tick when it only lifted; `place` and `lift` are every peg), and the
  plate it filled is judged when the iron has crossed it: a bump fused, a
  warn for beads astray that cost nothing, the heart where they do. The
  stroke that finishes the picture is the win and does not tap.
- **A drum answers only the stroke that played.** Drumbeat is struck two
  to four times a second: a stroke that played a berry taps under the
  finger (a ribbon's start, a roll's and a balloon's strokes too), and one
  in the air, on the wrong drum or too far off says nothing, so the missing
  tap is the news. What a stroke earned replaces its tap, never joins it
  (`strike` looks at `Haptics.count` round `_handle`): a bump for a combo
  called, the golden berry, a balloon popped, a hidden bar all struck. A
  ribbon kept bumps at its end, under the held finger. A run of ten or more
  broken is a warn, a berry let past before that nothing.
- **A verdict the board gives by itself knocks once, when it is given.**
  Trestle's Go taps and the test is watched, not felt: no knock for a creak,
  a snap, the splash or the tea. The verdict is the knock, a win as the cart
  reaches the far bank, a warn for a test that cost nothing, the heart
  where it costs one. A crossing after the solve (the convoy, a free
  build's test) is a good.
- **The last heart's knock is the lose.** Where the heart and the loss come
  on one frame (Drumbeat) or two seconds apart (Trestle's `FAIL_HOLD`), the
  bad is skipped for the last heart (`fx.buzz` in `_lose_heart`;
  `heart_lost` is not mapped).
- **Under reduce motion a seal lands with the win** and the win is the one
  knock: the thud asked for a hundredth of a second later does not outrank
  it (Drumbeat, Trestle).
- **Against the computer, only the hand's side knocks.** Versus cues ring
  for both players (snooker's `strike`, `pot`, `foul`; chess's `place`,
  `capture`, `check`), so none is mapped: the screen knocks through
  `_fx.buzz` where the side to move is the player's. The computer's visit is
  silent but for what it does to the player that must be answered (a check
  is a warn); a piece of yours taken, its pots and its fouls say nothing.
- **A shot on a table is the strike, and what drops.** Snooker taps as the
  tip meets the ball, not as the finger lets go (the stroke is a tenth of a
  second later and is what the hand did), is silent while the balls run,
  and bumps once as a ball it was playing for drops; the referee's foul is
  a warn when the table has stopped, seconds later, and may follow a bump
  (the ball did drop). The draw of the cue is Untangle's taut rope: one
  tick at the end of its reach.
- **One knock a move.** Chess taps a quiet move under the finger and leaves
  a capture or a promotion to the bump that lands with it a moment later,
  rather than a tap and then a bump 0.2 s apart. Checkers the same: a
  quiet move taps, a capture bumps once as its first piece is taken however
  long the chain (the wave's head), a crown bumps as it lands, and a move
  that ends the game leaves its bump to the win that lands with the piece
  (the board asks `rules.status()`).
- **A game that runs by itself knocks once a frame, with the strongest.**
  Firefly's sim is stepped twice a frame and a step can pop three bugs,
  clear the stage and pass the best: its events ask through `_feel(kind)`
  and `_knock_now` plays the frame's strongest after the steps (a mapped cue
  and a `buzz` on one frame both land and read `tap bump`). Only the end
  card's `new_best` is mapped.
- **Fire held is not felt, what it hits is.** Firefly shoots four times a
  second while the finger is down and none of it knocks, nor the slide: a
  bug shot down taps, a moth or a rogue bumps, a chain's word bumps in the
  kill's place. What the garden does to the firefly knocks by what it
  costs: a warn as the beam catches it (it can still be shot free), the bad
  as it is carried off or popped, the lose in the bad's place on the last
  one. A bug that flew into it is not a kill and does not tap.
- **An arcade run's win is its best.** A run always ends on the last life,
  which is the lose; the card knocks only when it shows a new best (the
  win), and the best passed mid-run is a bump. Restart and Play again tap as
  the run starts (after the boost card, on its Play), the screen opening
  from the menu does not, and a Second chance taken is a good.
- **A run that ends on the clock ends on a thud.** Molehill's minute is not
  lost, it is over: the bell is one heavy knock as the clock runs out (the
  taps after it are swings at nothing), and the Second chance's fifteen
  seconds end on another. The card is still the win only for a best.
- **A tap game answers the tap that hit.** Molehill is Drumbeat's drum: the
  mallet on a head taps, a swing at the lawn or an empty hill says nothing,
  and the missing tap is the news. What costs knocks by what it costs: a
  rabbit is the bad (thirty points and the streak), a streak of five or more
  lost another way is a warn, a mole let go before that nothing. A pot's two
  whacks are two taps; only the golden mole, a multiplier's step and a
  streak's word bump.
- **A merge is the right move, a chain is the milestone.** Stackwood merges
  on more than half its drops: the merge is that drop's tap (held back from
  the landing a tenth of a second, so it is not a tap and a tap), and the
  bump is for the chain's second round, once, and for a new biggest block.
  The block is carried like a rail piece (no knock per column) and a block
  nobody let go lands in silence. A tool bought taps, and what it does is
  its knock (the bomb's thud, the zap's bump), not what falls after.
- **A line that can still be stepped back from is a warn.** Stackwood's
  column one from the top warns once as it gets there and is a good when the
  shelf is pulled back; the block that goes over does not tap, the lose is
  its knock.
- **A chain drawn is a trail: it knocks once, as it lands.** Lucky
  Thirteen's chain is Word Trail's trail (the pebbles climb in the ear and
  say nothing to the hand) and its merge is Stackwood's: the right move, a
  tap, as the pebbles roll into the last one a fifth of a second after the
  finger lifts. The length is not the kind (on a young tray every other
  chain is ten long: the first pass bumped six and up and bumped thirty-nine
  moves in forty); the bump is a number the tray has not held before, and
  the thirteen is a thud.
- **A tool that frees a stuck tray is a good.** Stuck is Stackwood's line: a
  warn as the card comes up, and the tool that sets the tray moving is the
  good in its tap's place (one that leaves it stuck still taps, and the
  warn is not said again).
- **A swap knocks as its tiles are picked, and what it sets off is one
  bump.** Posy's move is felt a sixth of a second after the swap, when the
  line goes: a tap, or a bump in its place when the hand set a special off.
  A special made is the tap (the first pass bumped it too and bumped half
  the moves: its bump comes when it goes off). The cascade after is read,
  not felt, but for one bump at its first word or a goal filled, on a move
  that has not bumped. A swap that lines nothing up is a refusal and says
  nothing.
- **A day done is the stage cleared.** Posy's day bumps as it is done, and
  the clear that filled its last goal holds its own bump back for it; the
  left-over moves bursting, the stars and the gift are watched. Out of
  moves with an offer still to take is a warn as the card comes up, the
  five more a good, and only the end of it the lose.
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
  Versus screens are not registry boards: `tests/_probe_versus_buzz.gd --
  <game>` does the same through the real screen, headless, and puts
  `user://versus.cfg` back. Arcade screens: `tests/_probe_arcade_buzz.gd --
  <game>` plays a run through the real screen with a bot and prints every
  sim event against what landed with it (a throwaway wallet; puts
  `user://arcade.cfg` and `user://ads.cfg` back). A probe that acts faster than a hand must wait
  between steps (one knock holds the motor 40 ms of real time and a weaker
  one asked for meanwhile is dropped: a missing tap right after a warn is
  the probe, not the board).
  The trace says which kind landed, not how it feels: the native call
  cannot run on this Mac, so only a phone proves it.

"Next game on the list" means the first row below without a date.

**Read every row's "nothing for ..." as "no kind for ..."** since the echo
(2026-10-03): whatever in that list makes a sound now knocks an ECHO with it,
and only what is silent stays still. The kinds a row names are unchanged.

| # | Game | Done | What buzzes |
|---|---|---|---|
| 1 | binairo | 2026-10-03 | the shared piece came with it (core/haptics.gd, the Vibration switch, the Android permission); tap on a tile set, tick on a clear and Undo; bump on a line, a streak's confetti and the liar's unmasking; good on a hint, a clean Check and a heart back; warn on a blush that outlives the grace and on a Check that finds something; bad on a heart, lose on the last, win on the solve, thud on the flawless stamp; nothing for a given, the brush or a button |
| 2 | mastermind (Code Break) | 2026-10-03 | tap on a friend seated and Reset, tick on one sent back and Undo; bump once as a full row is scored (`check`, not a cue); good on a hint, a new best in the right seats (Warmer!, So close!), every friend present and a bought row; warn on Check with seats empty; lose out of rows; win as the lids come off (`_reveal`), thud as the seal lands; nothing for the pips, a palette tap on a full row, a hinted seat tapped, the clean miss's sunglasses, the Shell Game's swap, the peeks. Probed Easy and Insane; out of rows and the bought row are mapped but not probed |
| 3 | balance | 2026-10-03 | tap as a fruit the hand let go lands in a cup, tick as one tapped or dropped home gets there (`_by_hand`, not the `land`/`step` cues); good on a far toss that lands (over the tap), a hint and One more hour; bump on the beam level with fruit still to place; tick on Undo, tap on Reset; bad on Insane's bounce; lose at sunset; win on the solve, thud as the seal lands; nothing for a fruit lifted, a pinned fruit, the beam at rest off level or on its bale, the cheers, the sun tapped or getting low, and every fruit the board moves itself. Probed on all four bands; the level, the bounce and the sunset are mapped but not probed |
| 4 | untangle | 2026-10-03 | tap as the peg the hand let go lands in its hole, bump instead when that left a rope with no crossing or undid two at once (`_landed`, not the `drop` cue, which the kitten's swat and a hint's flight fire too); tick as each rope that came free pops off the ring (`_update_leaving`, 2026-10-05, not probed on a phone); tick once as the rope goes taut in the hand (`_update_held`; the pluck shares the cue and says nothing); tick on Undo, tap on Reset; good on a hint and One more spool; warn on the thread running low; lose out of thread; win on the solve (it waits for the last peg to land), thud as the seal lands; nothing for a peg lifted, selected or put back, a hole hovered, a braid cinching or unwinding under the hand, a stuck peg or a drop out of reach, a stitch, the kitten petted, pouncing or swatting, the shown answer. Probed Easy, Hard and Insane; out of thread and the spool are mapped but not probed |
| 5 | shikaku | 2026-10-03 | tap on a bed fenced (fits its sign or not: the sign's face says that), tick on one tapped away and Undo; bump where the streak's confetti flies (5, 10); good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart, lose on the last; tap on Reset and Try again; win on the solve, thud as the seal lands (`_stamp_at` + `STAMP_DROP`, flawless or Insane); nothing for the wash growing under the finger, a tap on bare ground, a drag refused on a pinned or taken bed, the sprout, the streak's pluck, the gags. Probed on all four bands; the last heart and the heart back are mapped but not probed |
| 6 | tents | 2026-10-03 | tap on a tent pitched (fair or not: its face and the chips say that), tick on one struck and Undo; one tick as a sweep is let go, laying cairns or rubbing them out (`_release`; the per-square `cairn`/`clear` are not mapped); bump on an oak given its second tent and where the streak's confetti flies; good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart, lose on the last; tap on Reset and Try again; win on the solve, thud as the seal lands (flawless or Insane); nothing for the sweep under the finger, a tree or a pegged tent tapped, the trees' hops, the streak's pluck, the gags, the tutorial's meadow. Probed Easy, Hard and Insane; the last heart, the heart back and a Check that finds something are mapped but not probed |
| 7 | lightup | 2026-10-03 | tap on a lamp set down (fair or not), tick on a lamp or a chip tapped up (`_commit`: the `strike` cue is also the board blowing a wrong lamp out, `clear` also the sweep's) and on Undo; one tick as a sweep is let go; bump on a cat whose number the hand's own tap met (`_by_hand` in `_cat_turns`: `purr` fires on Undo and a hint too) and where the streak's confetti flies; good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart, lose on the last; tap on Reset and Try again; win on the solve, thud as the seal lands (flawless or Insane); nothing for the sweep under the finger, a block, a cat or a pinned lamp tapped, a block's hop, a napping cat woken, the wrong lamp blown out, the streak's pluck, the moths, the gags, the tutorial's court. Probed on all four bands (the last heart on Hard, by a probe that slipped); the heart back is mapped but not probed |
| 8 | oneline | 2026-10-03 | tap as the walker is set down and on every plank laid, a post at a time under the drag; tick on Undo; bump where the streak's confetti flies (5, 10); warn once on Easy and Medium as a step first leaves a line out of reach (`_walk_to`, by `fx.buzz`: the step has no cue, and the steps after it on the same lost figure are plain taps); good on a hint (its own step's `lay` falls under it), a clean Check and a heart back; warn on a Check that finds a line stranded; bad on a heart as she lands, lose on the last; tap on Reset and Try again; win on the solve, thud as the seal lands (flawless or Insane); nothing for a post that may not start, a walked line or a sunny line refused, the eject's slide home, the daisies, the dew, the streak's pluck, the ladybugs, the gags, the tutorial's house. Probed Easy, Hard and Insane (the last heart on Insane); the heart back and the sunny line refused are mapped but not probed |
| 9 | nonogram | 2026-10-03 | one knock a stroke, as it is let go (`_knock` from `_release`, not the `place` cue, which a wrong tile's landing fires too): tap when it laid a tile, tick when it only crossed cells out or rubbed some out, bump when it brought a line to read right (the `bloom` cue also fires for a hint, an Undo and an eject; on Easy and Medium a line can read right and be wrong, and bumps all the same, as its daisy opens); tick on Undo; bump where the streak's confetti flies; good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart as the wrong tile lands, lose on the last; tap on Reset and Try again; win on the solve, thud as the seal lands (flawless or Insane); nothing for the cells sinking under the finger, the brush, a grouted tile tapped, the pebbles a finished line lays, the eject, the streak's pluck, the gags, the tutorial's floor. Probed on all four bands (the last heart on Insane); the heart back is mapped but not probed |
| 10 | queens | 2026-10-03 | tick on a cross tapped down and a queen tapped away, tap on a queen seated (`_tap_cycle`, `_tap_queen`: `place`/`remove` are also every cell of a sweep); one tick as a sweep is let go, laying crosses or picking them up; bump on a misty patch given its second queen and where the streak's confetti flies; tick on Undo, tap on Reset and Try again; good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart as the wrong queen's cell blushes, lose on the last; win on the solve, thud as the seal lands (flawless or Insane); nothing for a seen, pinned or shown cell tapped, the sweep under the finger, her wave, the flowers (a patch blooms on every seat), the wrong queen buzzing off, the streak's pluck, the gags, the tutorial's court. Probed Easy, Hard and Insane; the last heart, the heart back and a Check that finds something are mapped but not probed |
| 11 | hiddenword | 2026-10-03 | tap on a letter typed (`type_letter`: the `type` cue is also the caret moved to a tapped bed, which says nothing), tick on one erased; warn on an Enter refused (a short row, no word, a clue not kept); one knock a row as it shows its colours (`_react`): a bump, or a good when it earns Warmer!, So close! or Everyone's here!; on Insane a sealed row bumps as it lands and knocks again, like any row, when the snail brings its colours; good on a hint and One more row; tap on Reset; lose out of rows; win as the answer's last tile lands, thud as the seal lands (every solve has one); nothing for the five flips, the row made ready, the combo's notes, the confetti, the snail, the droop, Show the word, the gags, the tutorial's desk. Probed Easy, Hard and Insane; out of rows, One more row and a clue not kept are mapped but not probed |
| 12 | wordtrail | 2026-10-03 | one knock a trail, as it is let go: bump when the word locks (`place`), bad on Hard and Insane when it blows a seed off the dandelion (`_missed`, by `fx.buzz`: the `miss` cue is the last seed's too), lose instead as the tiles droop on the last seed; tick on Undo, tap on Reset; good on a hint and One more wish; win as the last word's wave ends (`solved` is queued for it), thud as the seal lands (every solve has one); nothing for the tiles under the finger or given back (`select`), a trail that only unwinds, one tried before, one put down off the field, the word's note, its bubble (big, quick, a streak) and its gag, the seeds running low, the lantern, the dawn, Show the words, the party, the tutorial's trail. Probed Easy, Hard and Insane; the last seed and One more wish are mapped but not probed |
| 13 | mushroom | 2026-10-03 | tap on a mushroom planted (right or not), tick on one pulled up and on a pebble tapped down or up; one tick as a sweep is let go, laying pebbles or rubbing them out (`pebble`/`remove` fire once a stroke); bump on a number the hand's own move finished, as its flower opens (`_by_hand` in `_update_blooms`: `bloom` fires for a hint, an Undo and a wilt too; on Easy and Medium a number can read finished and be wrong, and bumps all the same) and where the streak's confetti flies; tick on Undo, tap on Reset and Try again; good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart as the wrong mushroom opens, lose on the last as the patch goes to dusk; win on the solve (the winning move's own flower does not bump after it), thud as the seal lands (flawless or Insane); nothing for the sweep under the finger, a number, a hint's mushroom or a shown pebble pressed, the wilt, the streak's notes and bubble, the gags, the party, the tutorial's patch. Probed Easy, Medium, Hard and Insane; the last heart, the heart back and a Check that finds something are mapped but not probed |
| 14 | sudoku | 2026-10-03 | tap on a number written, tick on the same number tapped back out (`_apply`, by `fx.buzz`: `place` is both) and on the remove chip and Undo (they share a cue); bump on a row, column or region the hand's number finished (`_apply`, not the `line` cue: skipped under a wrong number, whose heart is the knock; on Easy and Medium a line can be finished and wrong, and bumps all the same) and where the streak's confetti flies; tap on Reset and Try again; good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart as the wrong number lands, lose on the last; win on the solve, thud as the seal lands (flawless or Insane); nothing for a cell selected, a chip with no cell, a given, a kept or a crossed-out number refused, the remove chip on nothing, the wrong number tumbling off, every one of a number home, the streak's notes and bubble, the daisies, the hills, the gags, the party, the tutorial's sheet. Probed Easy, Hard and Insane; the last heart, the heart back and a Check that finds something are mapped but not probed |
| 15 | bridges | 2026-10-03 | tap on a plank laid, dragged or tapped on the water (right or not: on Hard and Insane the heart says so as it lands), tick on a run lifted (Easy and Medium's third tap); bump as the plank lands when it brought an islet to its number, warn when it pushed one over (Easy and Medium) or left every number met with the islets in groups (`_by_hand`: `met`, `over` and `split` fire for a hint, an Undo and Reset too) and bump where the streak's confetti flies; tick on Undo, tap on Reset and Try again; good on a hint, a clean Check and a heart back; warn on a Check that finds something; bad on a heart as the wrong plank lands, lose on the last, after it sinks; win as the last plank lands (`_on_solved` + `_land_lag()`, not the `solved` cue), thud as the seal lands (flawless or Insane); nothing for an islet read, the lane lit under the finger, a drag at no islet or across a run, a full or buoyed lane, two groups joined, the plank cracking and sinking, the buoy, the streak's notes and bubble, the gags, the lanterns, the party, the tutorial's sea. Probed on all four bands (a Check that finds something on Easy and Medium); the split, the last heart and the heart back are mapped but not probed |
| 16 | quilt | 2026-10-03 | tap on a patch sewn on somewhere new (`_sewn`, by `fx.buzz`: the `place` cue is also a patch set down where it was lifted from, which is nothing, and a wrong one's landing); on Easy and Medium a warn in place of that tap when the drop leaves the quilt unfinishable (`stuck`); tick on a patch taken off the quilt by hand and on Undo (they share a cue); bump on a row or column the patch finished, as its glint sets off (`_rows_done`, not the `row` cue), and where the streak's confetti flies, one bump when both come on the same drop; tap on Reset and Try again; good on a hint and a heart back; on Hard and Insane a wrong patch taps as it lands and is a bad as its thread snaps and the heart splits, lose on the last, once it has fluttered home; win on the solve, thud as the seal lands (flawless or Insane); nothing for a patch tapped, lifted, carried, put back in the basket or set down where it lay, one turned down over the quilt (`refused`) or on a chalked spot (`ruled`), a hint's or a right one pressed, the snip, the flutter, the streak's notes and bubble, the buttons, the hearts, the boing, the cat, the bunting, the party, the tutorial's patchwork. Probed Easy, Hard and Insane; the last heart and the heart back are mapped but not probed |
| 17 | fairylights | 2026-10-03 | tap on a piece turned, the one gesture there is; bump once when the turn lit lanterns, as the wash reaches the first of them (`_on_turned`, not the `wake` cue, which rings for every lantern of a branch and for an Undo's, a hint's and Reset's too), which is where the streak's confetti flies; tick on Undo, tap on Reset and Try again; good on a hint and a heart back; on Hard and Insane a right piece turned taps and is a bad as the heart splits, lose on the last, after the fuse plays out; win on the solve, thud as the seal lands (flawless or Insane); nothing for a piece pressed, a slide off it, one every way round, pinned or clipped (`refuse`), a join's spark, a lantern put out, the fuse's sparks and its clip, the streak's notes and bubble, the moth, the hum, the love, the tags turning gold, the fireflies, the cat, the party, the tutorial's garden. Probed Easy, Hard and Insane; the last heart and the heart back are mapped but not probed |
| 18 | planes (Paper Planes) | 2026-10-03 | tap on a plane sent off, the one gesture there is (`place`); bump where the streak's confetti flies (5, 10, 20 and every 10 after); tick on Undo, tap on Reset and Try again; good on a hint and a heart back; on Hard and Insane a blocked plane taps as it sets off up its lane and is a bad as it bonks and the heart splits, lose on the last, once it has fluttered home; on Insane a warn as the clouds settle with no plane free and a heart left to blow them on (`_check_stuck`, by `fx.buzz`: with no heart left the lose is the knock, and after a heart back the good is), a bad as a tapped cloud's gust costs its heart (the `gust` cue says nothing); win on the last plane's tap, thud as the seal lands (flawless or Insane); nothing for a plane pressed or slid off, a blocked one refused on Easy and Medium, a tap swallowed while a plane flies home, the clouds' drift, the bonk and the flutter, the wake's wingbeats, the streak's notes and bubble, the loops, the birds, the love, the flock, the cat, the party, the tutorial's sky. Probed Easy, Hard and Insane (the clouds closing in and the gust on Insane, by a greedy search of the state); the last heart, the heart back and a crash into a cloud are mapped but not probed |
| 19 | pinwheel | 2026-10-03 | tap on a piece turned, the one gesture there is (`place`; what Insane's ribbons tug round with it is the same move); bump where the streak's confetti flies (4, 7, 10 and every 5 after); tick on Undo, tap on Reset and Try again; good on a hint and a heart back; on Hard and Insane a piece already home does not turn and does not tap, and is a bad as its thread catches and the heart splits (`snag` is not mapped), lose on the last, after it springs back; win on the solve (a hint that finishes the frame is the win too), thud as the seal lands (flawless or Insane); nothing for a wheel pressed, a square that is no pin, a piece pinned fast or sewn down (`refused`), a second tap swallowed while a piece swings home, the ribbons pulled taut, the gold button sewn on (`tack`), the sparkles, the streak's notes and bubble, the whirl, the love, the butterfly, the kite, the ribbons untied, the cat, the party, the tutorial's frame. Probed on all four bands; the last heart and the heart back are mapped but not probed |
| 20 | rings | 2026-10-03 | tap on a ring dropped on another peg, under the finger (`_tap`, by `fx.buzz`: the `drop` cue is also a ring put back on its own peg, which is nothing); bump as it lands when that locked a peg (`_by_hand` in `_settle`: `lock` fires for a hint's ring too) and where the streak's confetti flies (4, 7, 10 and every 5 after), one bump when both come; on Easy and Medium a warn as it lands when no move is left; tick on Undo, tap on Reset and Try again; good on a hint and a heart back; on Hard and Insane a drop that dooms the pegs taps as the ring sets off and is a bad as it wobbles there and the heart splits, lose on the last, once it has hopped home; win as the last ring lands (`_on_solved`, not the `solved` cue, which fires under the finger), thud as the seal lands (flawless or Insane); nothing for a peg pressed, a ring lifted, turned over (`tumble`) or put back, an empty or a locked peg tapped, a peg that will not take the ring (`refused`), the wobble, the hop home, the streak's notes and bubble, the twirl, the love, the bee, the hoop, the cat, the party, the tutorial's yard. Probed Easy, Hard and Insane (and Easy under reduce motion); the stuck warn, the last heart and the heart back are mapped but not probed |
| 21 | caterpillar | 2026-10-03 | tap as the caterpillar is set down on leaf 1 (`place`) and on every leaf eaten (`munch`); one tick as the finger lifts from a stroke that reached no leaf, walking bare squares or taking some back (`_release`, by `fx.buzz`: the `step` cue is every square, forward and back, and is not mapped); bump where the streak's confetti flies (4, 7, 10 and every 5 after); tick on Undo, tap on Reset and Try again; good on a hint and a heart back; on Hard and Insane a step the judge prices is the heart alone, a bad as the head gets there (no tick for the stroke it ends), lose on the last, once it has scooted back; win on the last leaf, thud as the seal lands (flawless or Insane); nothing for a square that is not leaf 1 or not the head's, the bare squares under the finger, a fence, a leaf out of turn, the last leaf too soon or an empty tummy (`refuse`, `hungry`), the worry and the scoot home (`strand`, `slip`), a row's sparkle, the tummy filling, the chews, the streak's notes and bubble, the burp, the love, the ladybug, the butterflies, the cat, the party, the tutorial's garden. Probed Easy, Hard and Insane; the last heart and the heart back are mapped but not probed |
| 22 | sunbeam | 2026-10-03 | one knock a move, as the piece is let go on another peg or an empty peg is tapped (`_after_move`, by `fx.buzz`: `slide` is not mapped): a tap, or a bump when the move lit a drop the light had not reached, which is where the streak's confetti flies (`confetti` is not mapped: one bump); on Hard and Insane one tick under the finger as the light held over a snail or a shy drop touches it (`stir`, `shy`, which fire only mid-drag), and let go there the move does not tap and is a bad as the piece lands and the heart splits, lose on the last, once it has slid back; from Easy to Hard a warn when a move of the hand's brings the light to the bud with a drop still dry (`_by_hand` in `_arrivals`: `dry` fires after an Undo, a hint and a Reset too); tick on Undo, tap on Reset and Try again; good on a hint and a heart back; win as the last piece lands and the light arrives (`solved` is queued for it; the winning release itself says nothing), thud as the seal lands (flawless or Insane); nothing for a piece lifted (`lift`), the pegs under the finger (`step`), one put back where it was lifted (`drop`), a pinned piece or a taken peg (`refuse`), the drops chiming (`dew`), the slide home (`slip`), the chorus, the streak's notes and bubble, the rainbow, the love, the butterfly, the cat, the party, the tutorial's floor. Probed on all four bands (and Hard under reduce motion); the last heart, the heart back and a pinned or taken refusal are mapped but not probed |
| 23 | knight | 2026-10-03 | tap on a hop as your knight sets off (`hop`; a hint's falls under its good); bump as it lands on a rose knight (`_play`, by `fx.buzz`: `take` rings for a hint's hop too) and where the streak's confetti flies (4, 7, 10 and every 5 after), the same landing, so one bump; a hop into their reach taps and is knocked as the rose knight lands on you, a warn on Easy and Medium (`caught`, it costs nothing) and a bad on Hard and Insane, lose on the last, once everything has slid back; from Easy to Hard a warn once the board is still on the hop that left no way to the king (`stuck`, as Start over comes up); on Insane a bad when boxed in by the brambles; tick on Undo, tap on Reset, Start over and Try again; good on a hint (the rewind too) and a heart back; win as you land on the king (`solved` is queued for the landing), thud as the seal lands (flawless or Insane); nothing for your own knight tapped, a square that is no L or a bramble (`refuse`), a hint with nothing to give, the rose side's answer, a bramble grown, a knight fenced in to nap, the slide back, the wither, the hoofprints, the streak's notes and bubble, the crown, the somersault, the love, the butterfly, the cat, the party, the tutorial's board. Probed on all four bands; the catch's heart, boxed in, the last heart and the heart back are mapped but not probed |
| 24 | hedgehogs | 2026-10-03 | one knock a rake or a chord that cleared piles (`_after_rake`, by `fx.buzz`: `rake` and `gust` are not mapped): a tap, or a bump when the flood is 20 piles or more (not for a hint's); tap on a flag dropped, tick on one lifted, the long press knocking under the finger as it fires; bump where the streak's confetti flies (4, 7, 10 and every 5 after; `confetti` is not mapped, and a flood that bumped is that move's one bump); a pile with a hedgehog under it does not tap: on Easy and Medium a warn as it pops up (`_wake`, `woke` is not mapped), on Hard and Insane a bad as the heart splits, lose on the last; a chord that wakes one taps for its piles and is knocked the same way; tick on Undo, tap on Reset and Try again; good on a hint, a clean Check and a heart back; warn on a Check that finds a flag on a bare pile; win as the sleepers' wave sets off (`solved`), thud as the seal lands (flawless or Insane); nothing for a pile pressed, a number that cannot chord, a flagged or pinned pile raked (`refuse`), the release after a long press, the Whoosh, the moon's bell, the walk and its snuffle, the streak's notes and bubble, the gags, the cat, the party, the tutorial's lawn. Probed on all four bands (Insane's win and seal by a plain run, `to=70`); a chord that wakes one, the last heart and the heart back are mapped but not probed |
| 25 | slider (Super Slider) | 2026-10-03 | one knock a move, a tap as a block is let go on another cell (`slide`, which only the hand's move fires); bump where the streak's confetti flies, as it lands (4, 7, 10 and every 5 after); on Hard one tick under the finger as the held move first takes the big block farther from the gate (`fret`), and let go there the move does not tap and is a bad as the block lands and the heart splits; on Insane a move that leaves the big block no way home is the same bad; lose on the last, once the block has slid back; tick on Undo, tap on Reset and Try again; good on a hint and a heart back; win as the big block lands on the mat (`_on_solved`, by `fx.buzz`: `solved` rings a second later, on its way out), thud as the seal lands (flawless or Insane); nothing for a block lifted (`lift`), the cells under the finger (`step`), one put back (`drop`), one pushed at a wall or a neighbour (`bump`), the big block refusing to go back up (`huff`), the slide back (`slip`), the latch, the gate, its hops out, the streak's notes and bubble, the gags, the cat, the party, the tutorial's tray. Probed Easy, Hard and Insane (Hard's and Insane's win and seal by plain runs, `to=120` and `to=150`; Easy under reduce motion); Insane's doomed move (none is one cell from the opening), the last heart and the heart back are mapped but not probed |
| 26 | marigold | 2026-10-03 | tap on a seed let go (`shoot`), the one gesture there is; one bump a shot as its first marigold opens (`_handle`, by `fx.buzz`: `hit` rings for every bud), on Insane as its first pair of sweethearts comes together (`_sweethearts`), and there a warn at the shot's end when a marigold alone folds back (`apart`); good on a seed caught by the pot (`pot`) and on seeds handed back for a big shot (`_after_pick`: `free` is also the shot's words and the multiplier), on a hint as the aim turns and on a heart back; out of seeds is a warn on Easy and Medium (`out`) and the heart on Hard and Insane, lose on the last; Undo is a tick and Reset a tap where they are free, the heart alone where they cost one (`reset` is not mapped: the garden growing back fires it too), tap on Try again; win as the last marigold opens and the garden slams to a crawl (`fever`; `solved` rings seconds later and is not mapped; the shot's bump gives way to it when its first marigold is the last), thud as the seal lands (flawless or Insane); nothing for the aim and its guide, the aim put down over the band, the buds, the clover, the violet, the walls, a seed past the pot, the blooms picked, the words, the multiplier, the streak's notes and confetti, the near miss, the jackpot pot, the garden growing back, the frog, the ducks, the cat, the party, the tutorial's garden. Probed on all four bands (Easy's and Insane's win and seal by plain runs, `to=75`; Hard under reduce motion); the last heart and the heart back are mapped but not probed |
| 27 | pixelgarden | 2026-10-03 | one knock a stroke, as it is let go (`_release`, by `fx.buzz`: `place` and `lift` are every peg under the finger): a tap when it seated a bead, a tick when it only lifted some; a plate is judged as the iron has crossed it: a bump when it fuses (`plate`; the streak's confetti is not mapped), on Easy and Medium a warn when beads go astray (`_plate_done`: `astray` rings under the heart too), on Hard and Insane a bad as the heart splits, lose on the last; tick on Undo, tap on Reset and Try again; good on a hint (not one that finishes the picture: that is the win), a clean Check and a heart back; warn on a Check that finds something; win as the last stroke is let go (`solved`; it does not tap as well), thud as the seal lands (flawless or Insane); nothing for the picture held (`peek`), a chip picked, the beads under the finger, a fused peg, one holding another colour or a colour run out (`refuse`), the iron setting off and its steam, the beads flying home, the words (Steady hand!, Whoosh!), the streak's notes, the hearts, the butterfly, the cat, the party, the tutorial's board. Probed on all four bands (Easy's and Insane's win and seal by plain runs, `to=60` and `to=90`; Hard under reduce motion, where two plates filled by one stroke are one bump); the last heart and the heart back are mapped but not probed |
| 28 | drumbeat | 2026-10-03 | tap on the stroke that starts the song and on every stroke that played a berry, under the finger (`strike`, by `fx.buzz`: a berry struck GOOD or OK, a ribbon begun, each stroke of a golden bar or a balloon); what the stroke earned is its one knock in the tap's place: bump on a combo called (10, 25, 50, 100), the golden berry, a balloon popped (`pop`), a hidden bar all struck on Insane (`echo_perfect`); bump as a ribbon is kept to its end (`hold_done`); warn on a run of ten or more broken (`break`), by a berry let past, a stroke too far off or, on Hard and Insane, a slip; on Easy and Medium a warn when the song ends under the line (`fail`); on Hard and Insane a bad on a heart (three misses in a row, or the song under the line), lose on the last (`_lose_heart`, by `fx.buzz`: `heart_lost` is not mapped); tap on Reset and Try again; good on a heart back; win as the song ends cleared (`clear`, `full_combo`), thud as the seal lands (a full combo, or Insane; under reduce motion it lands with the win and the win is the knock); nothing for a stroke in the air, on the wrong drum or too far off, a berry let past on a short run, a ribbon let go early, the tap-along and its buttons, a stroke that goes on from a pause, the count-in, the beat, Go-Go, the soul gauge and its line, the echo's bell, the conga, the shades, the words, the crowd, the fireworks, the cat, the party, the tutorial's road. No Undo, no hint, no Check. Probed on all four bands (Medium under reduce motion); a balloon (no song has one now) is mapped but not probed |
| 29 | trestle | 2026-10-03 | tap on a member laid, dragged or tapped out (`place_road`, `place_wood`, `place_rope`), tick on one tapped away (`remove`), on Undo and on Stop (they share a cue); tap on Go as the cart sets off (`go`: the convoy and a free build's test too); the test's verdict is one knock: win as the cart reaches the far bank (`solved`), on Easy and Medium a warn when it fails (`_failed`, by `fx.buzz`), on Hard and Insane a bad as the heart splits and lose on the last, as the riders nod off (`_lose_heart`: `heart_lost` is not mapped); after the solve a good for a crossing (`_crossed`: the convoy, a free build's test) and a warn for one that fails; good on a hint and a heart back; tap on Reset, Try again and the free build's Done; thud as the seal lands (flawless, or Insane; under reduce motion it lands with the win and the win is the knock); nothing for a pin or a joint tapped (`select`), a chip picked, a member refused (too long, too steep, off the zone, over budget, a hinted one tapped), Go pressed again on a promise, the bridge taking its weight, the creaks, a snap and its Crack!, the cart leaving the road, landing and the splash, the tea sloshing and spilling, the honk, the bridge settling, the prices, the score card, the clink, the ducks, the troll, the cat, the party, the tutorial's gap. Probed on all four bands (Easy's seal by a plain run, `to=32`; Medium under reduce motion); a free build's test is mapped but not probed |
| 30 | snooker (Versus) | 2026-10-03 | tap as the tip meets the ball on the hand's own shot (`_shoot`'s stroke, by `_fx.buzz`: `strike` rings for the computer's too), tap on the cue ball set down in the D (`placed`); one tick as the cue is drawn to the end of its reach, none again until it has eased under nine tenths (`_on_pull`); bump once a shot as a ball the hand was playing for drops (`_pot_on`: a ball on, and after a red the colour struck first), warn when the referee calls the hand's foul once everything has stopped (`_judge`); good on a hint as its line shows (`hint`), tap on Reset and Play again; win and lose as the frame ends (`win`, `lose`). Nothing for the aim, the spin, a cue put back, the clacks, the cushions, the roll, a ball that drops off no plan, the cue ball going in (the warn says it), the score counting up, or anything in the computer's visit: its strike, its pots, its fouls. No tutorial. Probe: `tests/_probe_versus_buzz.gd -- snooker` |
| 31 | chess (Versus) | 2026-10-03 | one knock a move: tap as a quiet move is chosen, by tap or let go on its square (`_on_chosen`; a castle too), bump in its place as a capture lands its blow (`_knock`, the hand's only) or as a pawn turns (`promote`; a capturing promotion is the capture's bump alone); warn as the computer's move leaves your king in check (`_after_move`: `check` rings for either king and is not mapped); tick on Undo (once, for the two moves walked back), good on a hint as its mark shows (`hint`), tap on Reset and Play again; win and lose as the mate lands, a bump for a draw (`win`, `lose`, `draw`), and a mate against you is the lose alone, not a warn first. Nothing for a piece picked up, put down or carried, a piece that cannot move (`refused`), the promotion picker opening, a check you give, the computer's move or its captures, the pieces coming in, the crown or the party. No tutorial. Probe: `tests/_probe_versus_buzz.gd -- chess` (`LEVEL=2 YOU=0` for the checks and the lose) |
| 32 | checkers (Versus) | 2026-10-03 | one knock a move: tap as a quiet move is chosen, by tap or let go on its square (`_on_chosen`), bump in its place as a capture takes its first piece (`_knock`, the hand's only, once however long the chain) or as a man is crowned on a quiet move (`crown`; a capturing crown is the capture's bump alone), and no bump on the move that ends the game (the win lands with the piece); tick on Undo (once, for the two moves walked back), good on a hint as its route shows (`hint`), tap on Reset and Play again; win, lose and a bump for a draw (`win`, `lose`, `draw`). Nothing for a piece picked up, put down or carried, a piece that cannot move or must capture elsewhere (`refused`), a landing chosen where routes part, the rings of the compulsory capture, the computer's move, its captures and crowns, the pieces coming in or the party. No tutorial. Probe: `tests/_probe_versus_buzz.gd -- checkers` (`LEVEL=2 YOU=0` for the lose) |
| 33 | firefly (Arcade) | 2026-10-03 | one knock a frame, the strongest its events asked for (`_feel`, `_knock_now`): tap for a bug shot down and for a moth's first hit (`pop`, `hurt`; since the shop of 2026-10-06 a bug takes several shots, and `hurt` taps only on the blow that leaves it half gone and on a lucky shot, so a quick gun's every landing is not a knock), bump in its place for a moth or a rogue, a chain's word (6, 12, 20, 30, 40), a stage cleared, a perfect flyby and the best passed mid-run; warn as the beam catches the firefly and as a shot pops your own captive (`captured`, `captive_lost`), bad as it is carried off or popped (`carried`, `ship_pop`), lose in its place on the last one (`game_over`); good as a captive is shot free (`rescue`), on an extra firefly and on a Second chance taken; win as the end card shows a new best (`new_best`, the only mapped cue); tap as a run starts from Restart, Play again or the boost card's Play. Nothing for the shots, the slide, the finger down, pause and resume, the dives, the beam opening, a bug that flew into the firefly, the captive docking, a flyby short of perfect, the stage and flyby banners, the score's round numbers, the card without a best, or the screen opening. No tutorial. Probe: `tests/_probe_arcade_buzz.gd -- firefly` (`SECS`); mapped but not seen in a probe run: `rescue`, `captive_lost`, the perfect flyby, the best passed mid-run |
| 34 | molehill (Arcade) | 2026-10-03 | Firefly's one knock a frame (`_feel`, `_knock_now`): tap as the mallet lands on a mole, on a pot's first whack (`clang`) and on the whack that breaks it; bump in its place for a golden mole, a multiplier's step (`combo`: x2 at 5, x3 at 12, x4 at 20), a streak's word (5, 10, 15, 20, 30, 40) and the best passed mid-run; bad for a rabbit whacked; warn as a streak of five or more is lost, to a swing at nothing or a mole let go (`streak_lost`; the rabbit's bad stands for its own); good as Steady hand keeps a streak (`forgiven`) and on a Second chance taken; thud as the minute ends (`time_up`: the whacks after it land on nothing); win as the end card shows a new best (`new_best`, the only mapped cue); tap as a run starts from Restart, Play again or the boost card's Play. Nothing for a swing at the lawn or an empty hill, a mole let go short of a streak, a mole coming up, a flurry's word (Double!), a round number, Ready and Go, Frenzy, the last five seconds' count, pause and resume, a tap before Go or after the bell, the card without a best, or the screen opening. No tutorial. Probe: `tests/_probe_arcade_buzz.gd -- molehill` (a whole minute, then a short second run with the best set low); mapped but not seen in a probe run: `forgiven` |
| 35 | stackwood (Arcade) | 2026-10-03 | one tap a drop: a block the hand let go taps as it lands, or, when it lands beside its own number, as it merges a tenth of a second on (`_will_merge`, `_by_hand`: the sim's `land` now says `dropped`); bump once a drop as a chain reaches its second round, and for a new biggest block from 64 up (`_on_new_max`, even rounds into a chain) and the best passed mid-run; tap as a rainbow block or a bomb is bought, bump as a zap strikes, thud as a bomb goes off, and nothing more for what a bomb or a zap sets falling (`_answered`); warn as a column first stands one from the line and good as the shelf is pulled back from it (the `_danger` edge in `_animate`; the `warn` cue is not mapped); lose as the shelf goes over (`over`: the landing that did it does not tap); good on a Second chance taken; win as the end card shows a new best (`new_best`, the only mapped cue); tap as a run starts from Restart, Play again or the boost card's Play. Nothing for the finger down or the block steered from column to column (`move`), the release itself, a block that fell by itself and what it merged, a chain's third round and after, the acorns flying home, a tool refused, a number retired, Ready and Go, pause and resume, the card without a best, or the screen opening. No tutorial. Probe: `tests/_probe_arcade_buzz.gd -- stackwood` (`SECS`, 45: the bot merges where it can, then the tools with acorns handed over, then it plays badly to the line and over); mapped but not seen in a probe run: the good off the line (Phew!), the best passed mid-run on its own frame |
| 36 | thirteen (Arcade) | 2026-10-03 | one knock a move, as the chain lands in its last pebble (`_on_merge`, `JOIN_T` after the finger lifts): a tap, a bump in its place for a new biggest number (`new_max`) or the best passed, a thud for the thirteen; nothing on the move that ends the run (the lose is its knock). Tools: a tick for Undo, a tap for a swap made, a pebble plucked, one lifted and the shuffle, a good in the tap's place when the tool got a stuck tray moving (`_on_tool_event`); warn as the stuck card comes up, once the tray has settled; lose as the tray is over, by a move or by End game (`over`); good on a Second chance taken (its shuffle adds nothing: `_reviving`); win as the end card shows a new best (`new_best`, the only mapped cue); tap as a run starts from Restart, Play again or the boost card's Play. Nothing for a pebble joined to the chain or taken back off it, a chain's tier rings (4, 5, 6, 8, 10), a long chain's word or the streak, a chain let go too short, a tool armed or put away, a swap's first pebble, a tool refused (no clovers, the same number, the biggest lifted, nothing to undo), the clovers flying home, the reveal, the hint, Ready, the card without a best, or the screen opening. No tutorial, no pause. Probe: `tests/_probe_arcade_buzz.gd -- thirteen` (`MOVES`, 40: the longest chain each move, then three twelves laid for the thirteen, the tools with clovers handed over, a tray jammed by the probe for stuck, End game); mapped but not seen in a probe run: a move that ends the run by itself, the best passed on a move that makes no new number |
| 37 | posy (Arcade) | 2026-10-03 | one knock a move, as its first tiles are picked a sixth of a second after the swap (`_pending`, `_on_clear`): a tap, a special made included, or a bump in its place when the move set a special off (a swap into one, two together, one tapped where it stands); one more bump at most while the move plays out (`_bumped`), for the cascade's first word (step 3) or a goal filled as its plate cheers; bump as the day is done (`day_done`: the clear that fills the day's last goal leaves its bump to it, and the bloom after it is silent); bump for the best passed mid-run; tap for a tool used (trowel, swap, bomb, rainbow seed: what it picks at once adds nothing); warn as the offer comes up out of moves, good as five more are taken and on a Second chance taken (`more_moves`); lose as the bed is out of moves for good, or the offer is turned down; win as the end card shows a new best (`new_best`, the only mapped cue); tap as a run starts from Restart, Play again or the boost card's Play. All of it asks through `_feel` and the frame knocks once (`_knock_now`). Nothing for a tile picked or put down, a swap that lines nothing up, the cascade's other steps and what they make or set off, a bee's flight, weeds, stones and moss, the moss creeping, the bed reshuffled, the day's bloom, stars and gift, the deal, a booster's opening bloom, the last moves' count, a tool armed, put away or refused, the hint, the card without a best, or the screen opening. No tutorial, no pause. Probe: `tests/_probe_arcade_buzz.gd -- posy` (`MOVES`, 60: the sim's own hint each move, heard through `_apply` as the queue plays; a breeze laid and tapped, the four tools, then one move left with the goals out of reach for the offer); mapped but not seen on its own line in a probe run: the goal's bump and the best's (both print as "(nothing played)") |
| 38 | peapod (Arcade) | 2026-10-04 | Firefly's one knock a frame (`_feel`, `_knock_now`), built with the game: tap as a crate or a plate is shot down (`kill`), tick in its place for a plate of the tail going off after the head, bump for a golden crate, a streak's word (10, 20, 35, 50, 75), a wave cleared and the best passed mid-run; good as a gift is caught (`catch`) and on a Second chance taken; thud as a firecracker goes off (`boom`) and as the millipede's head is shot off; warn as something first nears the line (`warn`, once until it is pushed back); good for every gift, the pods, magnet, frost and shove included (the rotten gift and its warn went on 2026-10-05); lose as the line is reached (`over`); win as the end card shows a new best (`new_best`, the only mapped cue); tap as a run starts from Restart, Play again or the boost card's Play. Nothing for the gun, which never stops: `shot`, `hit` and an iron crate's `clank` play through `_quiet`, an `Fx2D` with `buzzes` off, so they carry no echo; nothing either for the slide, the finger down, a gift crate opening or its token lost in the grass, a plate knocking the millipede back, the helper leaving, the wave's banner, pause and resume, or the screen opening. No tutorial. Probe: `tests/_probe_arcade_buzz.gd -- peapod` (`SECS`, 70); mapped but not seen in a probe run: `warn`, a streak's word. The soft pass (2026-10-04) added one: tick for each star a cleared wave is stamped (one to three, 0.22 s apart, after the clear's bump); a gift landing on the grass plays `hit` through `_quiet` and knocks for nothing. The probe's end-card step fails (`_s._end` null), as it did before the pass. **The fourth pass (2026-10-05)**: nothing is caught, so good is for a gift crate broken (`gift`, where `catch` was); the magnet and the helper are gone; tap for a card bought in the shop and for its Go; nothing for the shop opening, an energy orb landing (its click plays through `_quiet`), lightning's jumps or a burn's bites. The probe's bot shops and ran to its end cards The fifth pass (2026-10-05, gifts kept on two buttons): good still as a gift crate breaks, its gift now kept (`gift`, the sound `catch`); bump as a kept gift is started from its button (`use`, with the pod's, the frost's or the shove's sound); tick for a press on a kept gift in the beat between waves, which is refused. Nothing for a press on an empty button or for a gift pushed out by a newer one. The probe's bot presses a gift a second after it is had: `use burst -> echo bump`, `pod_off burst -> echo` seen. The eighth pass (2026-10-05): the gifts are seven counted buttons down the right side; bump as a press starts one, tick as a button refuses (none had, where an empty button did nothing before, or no wave on); the gift reaching the pod's mouth plays `hit` through `_quiet` and knocks for nothing. |
| 39 | Versus online (level 3 of rows 30-32) | 2026-10-04 | not a game of its own: what a game online adds to snooker, chess and checkers, all of it in `versus/online/online.gd` by `Haptics.play`, so no screen maps or knocks any of it; good as a player is found, with the found card (`_on_found`); one warn as your own clock reaches 10 s (`BUZZ_AT`, `_on_clock`: once a turn, armed again when the turn passes to the other seat, and never for the other player's clock); tap on Find another (`again_button`). The game's own knocks are rows 30-32 unchanged: the hand's side only, so the other player's moves, pots and fouls are as silent as the computer's (chess's warn for a check against you stands), and win, lose and draw land with the end card whatever ended the game (a resignation, a clock, a player gone). Nothing for the lobby's cards going up, nobody around, no connection, the 15 s colour change on the clock or its bump each second, the other player's clock, the dialog Back asks with, the lobby's and that dialog's buttons (Cancel, Keep looking, Play the computer, Keep playing, Resign), a resignation sent. Undo, the bulb and Reset are greyed online, so their knocks cannot land. Not probed: `tests/_probe_versus_buzz.gd` plays the computer; the shots (`tests/_shot_online.gd`) fake the clock and print no trace |
| 40 | grove (Valley) | 2026-10-05 | built with the place: tap as a tree comes down (`fell`), bump for a tile bought (`buy`), warn for one the energy does not reach (`no`); a chop that hits has no kind of its own and is felt as its click's echo, the weakest there is, because it repeats for as long as the finger is held (twice a second on a new grove, six times late on). Nothing knocks for a tree coming up. Device verdict pending |
| 40 | Friends (the sheet, the code dialog, the cards) | 2026-10-04 | no board and no `Fx2D`, so every knock is `Haptics.play`; good as an invite card or a new friend card comes up (`ui/menu.gd`, `_on_invited`, `_on_befriended`: news the hand did not make, as the found card is); good as a code makes a friend, warn for each refusal and for a paste with no code (`ui/menu/code_dialog.gd`); tick as a friend is removed, on the yes; warn with the line an invite link that failed says (`friend_link_failed`). Invite, copy, Play, the picker and Not now are buttons: the click's echo and nothing chosen. The game that follows is row 39. |
| 41 | minigolf | 2026-10-05 | built with the game: tap as the ball is let go (`putt`; a pull put back down is no putt and no knock); bump as it drops in a cup (`sink`), the win in its place on the last cup (`_on_sunk`, by `fx.buzz`: `solved` rings with it); warn as it goes in a pond (`splash`); one tick as the aim takes the bulb's line (`_pull`, by `fx.buzz`, once until the aim leaves it), good on a hint as its line shows (`hint`), tap on Reset and Try again (`reset`); lose as the strokes run out on Insane (`out_of_hearts`), good on the card's video (`heart_back`); thud as the seal lands (`_party`). Nothing chosen for the pull, the dots, a kerb, a post, the sand, the rim, a gate's swing, the hole sliding in, the card's words or the party: where they make a sound they echo it. Read by `tests/_probe_perf.gd -- minigolf d=<n> x=buzz`; not felt on a phone |
| 42 | nightlight (Arcade) | 2026-10-06 | built with the game: tap as a meteor is thrown (`throw`), bump for a tile bought and a perk drawn (`buy`, `perk`), warn for a tile the light does not reach (`no`; there is no pouch to be empty since the same day), one thud as the star goes supernova (`nova`). The game has no sound files, so nothing is felt as an echo: a body eaten, light shed and two bodies meeting are silent and unfelt, on purpose for the first two (several a second). Device verdict pending |

All 39 rows are done (2026-10-04; rows 1-37 on 2026-10-03, row 39 with Versus online). A second pass starts again at row 1.
