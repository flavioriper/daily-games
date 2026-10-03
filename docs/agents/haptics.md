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
