# Super Slider polish: hard wood, hearts, Homesick, rewards and sound

2026-10-01, built unattended on `feat/slider-polish` at the user's word
("let's polish the super slides game, add more smooth animations, reinforce
that the sfx sounds are really cozy, add more visual rewards even if silly
to the user to keep engagement, and make sure the insane difficulty is
really insane, with something totally new (something only us do) that make
the game nearly impossible, user can also fail on insane and hard ...
Players are complaining a lot about how sintetic the sounds are, and moving
the pieces make them look like jelly instead of a hard piece").

Knight's, Hedgehogs' and the other passes the same day are the pattern for
hearts, dusk and the card, the streak, the gags, the party and the seal. The
board's own spec (`2026-09-26-super-slider-flat-design.md`) stands except
where this says otherwise. The calls at the end are for the user.

## 1. Hard wood (the jelly complaint)

The first pass made a held block **lean** with its speed (the leading edge
ran ahead, the sides drew in), **squash** as it landed (`LAND` 0.08),
settle on `back_out` (an overshoot), **wobble** one and a half times off a
wall, and **pop in with a scale overshoot**. Every one of those bends the
block, and together they read as jelly. All gone:

- `ui/faces/slider_block.gd`'s `block()` lost `squash` and `lean`: it can
  only draw a block whole. Its doc says why.
- A let-go block settles on an ease-out cubic over `SNAP_TIME` 0.13 and
  stops dead; its lift drops with it, so the shadow tightens as it sits down.
- A knock is **one recoil** (`KNOCK` 0.028 of a cell, in over the first
  fifth of `KNOCK_TIME` 0.2, eased back): no oscillation. The block in the
  way flinches the same way (`FLINCH` 0.016). Pushing at a shut way gives
  `RUBBER` 0.03 (was 0.07).
- The entrance sets each block **into** the tray: it falls `ENTER_DROP`
  0.45 of a cell over `ENTER_FALL` 0.2, accelerating, lifted (a long shadow)
  and lands with a small puff; no scale at all.
- The exit hops land without a squash. The only rotation anywhere is the
  twirl gag, which turns the whole block rigidly.

## 2. Bands

| band | trays | hints | hearts | undo | the cost |
|---|---|---|---|---|---|
| Easy | 8-16 | 3 | - | yes | - |
| Medium | 20-34 | 3 | - | yes | - |
| Hard | 38-56 | **2** | **3** | yes | a move that takes the big block **farther** from the gate |
| Insane | **Homesick**, 50-112 | **0** | **2** | **no** | a move after which the big block can **never** get home |

`State.HINTS_BY` / `HEARTS_BY`. A costly move lands, the big block looks
worried, a heart splits on a pill over the count line, the toast says why
(`SL_SETBACK`, `SL_DOOMED`, with hearts left), and after `SLIP_HOLD` 0.45 the
block slides back the way it came. It counts no move. Out of hearts: the big
block nods off, dusk, the card (`SL_OUT_BODY` / `SL_OUT_REST`) -- Try again
(the tray as dealt, hearts full, clock and moves zero; hints spent stay
spent), One more heart (a video, once; play goes on from where it was),
Back.

**Hard's peek.** While a held move would take the big block farther from
the gate it sweats (a drop by its brow) and looks worried, with a quiet
`fret` cue. So a heart is never a surprise on Hard: you can always carry the
block back before letting go. Judged by the solver's distances
(`State.dist_of`, never waiting for the worker); before it is done a move
is not judged.

## 3. Insane: Homesick

**The big red block is homesick: it never steps back up, only down or
sideways. Bring it down too soon and it can be stuck for good.**

- **Why it is ours**: checked 2026-10-01 against the family (Huarong Dao,
  Pennant, L'Âne rouge, Klotski apps, Rush Hour's ice and gravity variants,
  Lunar Lockout's slide-until-stop). None takes back the one reversibility
  every sliding-block puzzle has -- any move can be undone by the reverse
  move -- for one block only. One rule turns a puzzle you can always wander
  out of into one with dead ends.
- **Why it is nearly impossible**: the move every player wants to make,
  bringing the big block down, is the one that traps it. You have to plan
  the whole bottom of the tray before it descends, and the trays are 50 to
  112 moves long with no undo, no hints and two hearts. In the mined graphs
  **10 to 27% of the big block's moves strand it** (`doom` in the bank); a
  little block's move never can (its moves still reverse).
- **Fair, always**: the solver runs the Homesick graph (one-way, so the
  second pass walks the edges backwards: `Gen._reversed`) and a move is
  judged only by whether a way home is left, never by how good it is. A
  stranding move slides back, so a tray can never be left lost. A move let
  go before the solver is done waits for it (the big block looks puzzled,
  nothing else moves) instead of freezing the frame.
- **The look**: a row of brass dots across the floor at the big block's top
  edge and a brass notch on each side of the frame -- the line it never goes
  back over; it only ever moves down. Dragging the big block up: it shakes
  its head (rigid, `SHAKE` 0.04 over `SHAKE_TIME` 0.32), a `huff`, and
  `SL_HOME_UP` once a drag; the drag gives nothing upward.
- **The bank**: `tools/mine_slider_homesick.gd` walks the two-way graph of
  each tray in `content/slider.json` (then random layouts), finds every
  position's Homesick distance in one backward pass, keeps graphs where at
  least `DOOM_MIN` 8% of the big block's moves strand it, and keeps up to 8
  positions a graph within 14 moves of its deepest, at least 50 deep, each
  re-proved by the phone's own `distances(start, cap, {}, true)` from the
  position itself. `tools/merge_slider_homesick.py` caps a graph at 24
  trays and the file at 200 (`content/insane/slider.json`), dealt through
  `InsaneBank` like every Insane bank; mirrored half the days. Without the
  bank Insane deals the old two-way Insane tray with two hearts and the
  setback rule.
- `SL_LVL_3` "Homesick: the red block never goes back up"; tips
  `SL_TIP_HOME`, `SL_TIP_HOME_PLAN`, `SL_TIP_HOME_HEARTS`; rules
  `SL_RULES_HOME`. A solve shares `🏡 Homesick[ · Flawless]` and stamps the
  night seal.

## 4. Rewards, even silly

- **The streak**: kept moves that bring the big block nearer the gate (a
  move that keeps the distance leaves it be; a step back, a heart, Undo,
  Hint or Reset ends it): `combo` up the pentatonic from the second, the
  "x3" bubble over the moved block from the third, confetti at 4, 7 and
  every 5. A shortest-way solve is one long streak.
- **Gags** on one nearer move in three, off the day's hash, one at a time:
  **the twirl** (the big block hops and turns once round, rigid, sparkle
  sound), **love hearts** off its head, **a butterfly** that lands on its
  head and stays while it slides.
- **The latch**: one move from home, the gate's doors rattle on their latch
  (`latch`).
- **Halfway**: the first time the way left is half the day's, three
  sparkles over the count line.
- **The party** after the big block has walked out: a stone `hop` sound on
  each of its three hops, confetti twice, the nap cat hops onto the frame's
  foot left of the gate and curls up, sliding wisdom (`SL_CHEER_0..11`), and
  the seal: gold for Flawless (no hint and no heart lost on Hard and
  Insane, no undo on Easy and Medium), night for any Homesick.
  `completion_record()` keeps `hearts` and `flawless`.

## 5. Sound

Players called the first set synthetic. Two new styles in
`tools/gen_sfx.py`: **WALNUT** -- close-mic foley of real hardwood toy
blocks on a felt-lined walnut tray, "no synth, no electronic tones, no
beeps", every cue rolled off above 7 kHz (`warm:7000`) -- for everything a
block does (`lift`, `step`, `bump`, `slide`, `drop`, `undo` -- was a tape
rewind, `slip`, `reset`, `enter`, `gate`, `hop`, `latch`); and
**WALNUT_TUNE** -- a real kalimba and wooden music box recorded close --
for the rest (`hint`, `solved`, `fret`, `huff`, `heart_lost`,
`out_of_hearts`, `heart_back`, `combo`, `confetti`, `love`, `flutter`,
`twirl`, `stamp`, `party`), and `purr` (COZY). 27 cues, 16 new, all fresh
takes, rendered on the fallback key; **unheard** by a person.

## 6. Numbers

`tests/_shot_slider.gd` at `--resolution 810x1440 --always-on-top`,
windowed, one at a time, peak draw calls from 0.5 s (the second of two
readings where two were taken):

| mode | band | peak | ANGLE |
|---|---|---|---|
| rest | Hard | 85 | |
| fret (held) / cost | Hard | 85 | |
| out (dusk, card, Try again) | Hard | 85 (one early reading of 105 under six miners) | |
| home (head shake, stranded, slide back) | Insane | 70 | |
| streak and gags | Easy | 84 | |
| solve and party | Medium | 90 | |
| solve and party | Insane | | 77 |
| restore | Hard | 85 | |
| cost, reduce motion | Hard | 83 | |

Peak 90, 765 under the 855 budget (68 before the polish: the hearts' pill,
the count line's band and the life layer). Idle frame 4.5 ms at Hard on this
Mac, not quotable.

The suite `passed=122403 failed=0`; `tests/_probe_slider.gd` `bad=0` over
three days a band (Insane's par is the Homesick distance and its hint walk
plays it out); `tests/_win.gd -- slider` PASS.

## 7. Bugs fixed on the way

**Review findings, fixed**: the drag's "could it step there?" probe stepped
and stepped back, and on Homesick the step back (up) is refused -- a finger
resting a little below the big block dropped it a row for good (now asked
without moving it; `nudge` mode in the harness checks it); a Hint or Undo
while a drag was held kept a sweating move unjudged (busy() now covers a
held drag and a pending slide back, `_slipping`); `State.build`'s parameter
shadowed `band`.



**Restore**: a reopened, already-solved day showed the big block still in the tray with
the gate shut whenever the app had been open under 100 seconds: the restore
set the win's clock to "now less 100 s", which is negative then, and every
check read a negative clock as "not won" (Sunbeam had the same bug). The
board now keeps `_won` apart from the clock.

## 8. Calls for the user

- **Insane is Homesick.** Considered and measured first: "Tag Along" (the
  big block cannot be dragged and takes a step the way each moved block
  went) -- mined, its deepest trays were 33 moves and under 1% of moves
  stranded it, so it was neither nearly impossible nor losable.
- **Hard judges by distance, with the peek.** Without the sweat drop, three
  hearts against 38-56 moves would be a coin toss; with it, the heart is for
  letting go of a move the block warned you about.
- **A costly move slides back** rather than staying, on both bands, so a
  tray is never left stranded and Insane needs no Start over button.
- **Reset on Insane** goes back to the opening (hearts lost stay lost),
  like every Insane.
- **The bank is narrow**: deep Homesick trays come from few graph families
  (the old Insane band clustered the same way); the merge caps 24 a family.
- The look (brass line, sweat, twirl) was judged on stills only. Sounds
  unheard.
