# Untangle: the wooden ring, physical rope, thread and a kitten

2026-09-29. Built unattended at the user's word ("polish the untangle game,
add more smooth animations, reinforce that the sfx sounds are really cozy,
add more visual rewards even if silly ... make sure the insane difficulty is
really insane, with something totally new (something only us do) ... user can
also fail on insane and hard ... redo the game to be more align with this
untangle instead of the current one, with a more realistic wire physic",
with a screenshot of a wooden ring of pegs and thick rope). No concept tab
(the same call as Balance's seesaw, 2026-09-27); every section is the agent's
own and open to review. Built on `feat/untangle-rope`. It replaces the
2026-09-18 lantern board (`2026-09-18-untangle-flat-design.md`), which stays
for its history.

## 1. What the game is now

A **wooden ring** of peg holes stands on embroidered linen. Each **rope**
runs from one peg to its twin. A move **lifts a peg out of its hole and drops
it in an empty hole**; its rope goes with it. The ring is untangled when **no
two ropes cross**. Because rope ends never leave the ring, two ropes cross
exactly when their four hole indices interleave round it
(`untangle_gen.gd: crosses`), so the rule is a one-line test on integers and
the picture (near-straight ropes between pegs) agrees with it.

There is no free dragging any more: the old lanterns moved anywhere on the
card, which made the puzzle "wiggle until nothing crosses". Now the pegs are
the puzzle: N holes, R ropes, N - 2R holes empty, and every move spends one.

**Reach** is the second rule. A rope is as long as its span needs plus what
the band allows (`min_reach`, `extra`), and a peg cannot be dropped in a hole
farther from its rope's other end than that. A drag past it pulls the rope
tight (the peg stops giving, strains, the rope thins), the far holes stay
dark, and a tap on one says so. Short ropes are what turn "move anything
anywhere" into "what to move first".

Hand: press-drag-release, or tap a peg (it lifts and every hole it can go to
glows) and tap a hole. A press within 1.9 peg radii grabs the nearest peg; a
hole within 1.9 radii of the held peg is the target (red reticle); the peg
hovers above the finger. A peg with nowhere to go shakes and the sprout says
so.

## 2. The rope

`puzzles/untangle_rope.gd`: 15 points, Verlet, 120 Hz fixed step, 9
constraint passes, a weak bend pull, friction 0.972 per step (a rope on
cloth). Both ends are pinned at the pegs as drawn. **The rest length follows
the gap between the pegs** (plus 0.4% slack) up to the rope's own length, so
the rope is always nearly the line the rule tests; the life is what is added
to it: a dropped peg **whips** the middle sideways and gives the rope 2.2% more
slack that decays over about a quarter second, a lifted peg takes up slack, a
rope pulled to its limit rings when let go, and one rope a few seconds
stirs by itself. A rope at rest is asleep (24 quiet steps) and costs nothing.

Drawn as a thick cotton rope: a shadow (parts from the rope while lifted), a
dark edge, the body, a pale strip, and slanted grooves every 0.66 widths with a
pale companion. **Over and under**: the rope moved last lies on top
(`state.order`), and the one in the hand is drawn last; each rope's shadow is
in its own mesh so it falls on the ropes below.

Ten rope colours were considered; nine ship (`ROPES`), one per rope, with the
same colour inlaid in both of its pegs so a peg's twin can be found. **No state
is signalled by a shade of a rope's own colour**: a crossing is a coral bead
with a halo (visible once 12 or fewer remain), a refused peg shakes, a taut
rope thins.

## 3. Bands

| band | holes | ropes | empty | reach | thread | kitten | hints |
|---|---|---|---|---|---|---|---|
| Easy | 10 | 4 | 2 | full | - | - | 3 |
| Medium | 13 | 6 | 1 | 60% of half the ring or the span | - | - | 3 |
| Hard | 17 | 8 | 1 | 50% | par + 3 | - | 1 |
| Insane | 19 | 9 | 1 | 50% | par + 3 | **yes** | 0 (videos) |

**Par** is a beam search's answer (`Gen.way_home`, width 36, depth 14, score
= smallest set of ropes that must move first, then crossings): a real way
home, not proven shortest. A deal is kept only when par is high enough for
its band (2, 4, 6, 6). Measured on this Mac, 12 boards each: a greedy player
who always makes the move that leaves the fewest crossings solves Hard in
par + 1 to par + 7 and Insane in par + 0 to par + 16 (median about par + 6),
against thread of par + 3 -- so a careful player passes and a greedy one
fails about half the time on Hard and most of the time on Insane. The fair
argument is constructive: the answer is a real move list, it fits the thread,
and the hint replays it.

Generation is a walk out of a crossing-free layout (`_pick_away`: each step
chosen to deepen the tangle most) followed by the search. Mean / worst on this
Mac: Easy 2 / 3 ms, Medium 9 / 14, Hard 57 / 250, Insane 71 / 155. A deal
tries at most 16 walks and keeps the best: a count, not a clock, so a day is the
same board on every device (an earlier draft cut it off after 350 ms, which
would have dealt a slow phone a different board).

## 4. Thread: Hard and Insane can be lost

Same pattern as Balance's sunset (2026-09-29): a row of stitches at the top
of the card, one used by each **move, undo and hint** (Reset gives nothing
back; the kitten's swipes cost nothing). A needle sits at the next stitch,
dips as one is made, and trails its thread back to a spool; the last three
stitches beat coral and the sprout says so. At zero with the board not
solved and everything landed: the pegs nod off (asleep faces, z's rising),
`thread_out` plays, and after 1.7 s Code Break's card
(`ui/hud/out_of_rows.gd`, keyed) offers **One more spool** (a rewarded video,
placement `spool`, once a board: +4 stitches on Hard, +3 on Insane, none if no
video is ready) or **Show the answer** (`finish_unsolved()`; the dealer's
layout, the pegs walk to it). `out_of_hearts` is a getter, true from the last
stitch, so the host's Back counts a loss. Undo is a stitch on Hard and off on
Insane; Reset stays (the thread does not come back, so it is not a retry).
Hints are the search's next step from wherever the pegs are now, cost a stitch,
and a video's are unlimited but cannot outlast the thread.

## 5. Insane: the kitten

Nobody else's rope puzzle has an opponent that can be read. A ginger kitten
sits in the card's corner with a **ball of yarn in the colour of the peg she
is eyeing** and a number: the moves until she pounces. That peg wears a paw
print. **After every third move she bats that peg into the empty hole nearest
to it** (clockwise first) that its rope can span. Insane has one empty hole,
so it is always the one you just left: she moves the peg that was marked into
the space your move opened, and the empty hole travels on. Her swipe is not
a move and costs no thread, and if your move solved the board she does not
come.

What makes it Insane is that her swipes are part of the solution, not noise:
they can undo your work or finish it, and the shortest way home has to be
found with them. Hovering a target hole on the move before a swipe shows a
ghost of the peg where she will put it (`State.foresee`).

**Why it is fair.** Her schedule is fixed per deal (`swipes`: move number ->
peg; past the list a fixed stand-in, `Gen.swipe_fallback`), her rule is a
pure function of the layout, and the dealer builds the board *backwards* from
a solved layout (`_cat_deal`: undo the player's move, then, when one follows
the move before it, undo her swipe, and so on to the start), so the deal's own
answer replays forward to a win (`_replays` checks it). The beam search with
her swipes played in (`way_home(..., swipes, every, moves0)`) then usually
finds one less than half as long (6 against 13) and *that* is par; the hint
uses the same search. Budget is par + 3. Bot and hint numbers in section 3.

## 6. Motion

Pegs and ropes are integrated against a clock, never tweened. A peg is on the
finger, on a flight (a drop, a return, a hint, reset's walk, the kitten's
swat) or in its hole, and the rope hangs from where the peg is drawn. Flights
ease out (cubic) over 0.22-0.42 s by distance, with an arc for hints, undo,
show-the-answer and the kitten's. Landing: a squash (0.2 s), a puff, a whip
on the rope, the drop cue. Refusal: a shake. Pop-in: the pegs on the family's
stagger, the ropes fading in once both ends are up. Lift: the cap grows 16% and
rides 0.9 radii above the finger, its shadow widens and fades (the paper
vocabulary, `core/motion.gd`). Held over a hole: the reticle beats, every other
hole it can reach glows and pulses. All under `Motion.reduce`: flights are
instant, ropes are straight, nothing pulses.

## 7. Rewards, even silly

- **Untying**: a move that clears two crossings letters "Double untie!",
  three "Triple untie!", four "Knot-be-gone!" (with the sunburst), six "Wowza
  wool!"; three clearing moves in a row "Yarn streak!"; the last knot "One to
  go!"; a move that makes three or more "Oopsie, tangled!" with a puff. Stars
  and sparkles spray from the landing hole; a ring and a spark on every cleared
  drop.
- **The solve**: the ropes glow in a light that runs along each in the order
  they lie, every peg wakes with a grin (a face drawn on its cap), a party hat
  pops onto every peg from the middle out, confetti, the rainbow "Untangled!",
  "No hints!" and the **seal** stamped on the ring's middle (gold, or on
  Insane night blue "Kitten Tamer"), worded by moves beyond par (+ hints):
  Yarn wizard, Knot ninja, Tidy hands, Got there!, Cozy finish, Second spool.
  Kept in `completion_record()` and the share line.
- **Losing**: sleepy pegs, floating z's, the kitten asleep; Show the answer
  walks them home.
- The kitten grins at the solve and pounces (paw out and back, a squash, a
  ring where the peg lands) on a swipe.

## 8. Sound

Regenerated with `tools/gen_sfx.py untangle` (ElevenLabs): real wood and
cotton rope in FOLEY for `pick`, `drop`, `put`, `taut`, `reset`, `stitch`;
kalimba/glockenspiel for the rewards (`untie`, `combo`, `oops`, `hint`,
`solved`, `stamp`, `party`, `confetti`, `reveal`), the lullaby for
`thread_out`, `thread_low`, `spool_back`, a cartoon mrrp for `pounce`. Not yet
judged by ear; the user names the ones to redo. `hover` has no file (silence
on purpose).

## 9. Cost and checks

Draw calls (the whole screen, `opengl3`, 810x1440): 77 at rest, peaks 98-123
carrying a peg. Two static-ish meshes plus one per rope, one per peg and a
soft shadow each; only a rope that is awake, lifted or fading is rebuilt
(measured: the first version rebuilt everything per frame and cost 11-18 ms
carrying a peg; cached ropes and pegs bring it to 5.7-6.9 ms against 3.4
idle). `tests/_shot_untangle.gd` shoots and plays every mode
(`rest hold taut plan wrong answer out hint undo reset perf`). Suite green,
`tests/_win.gd -- untangle` passes (hint through the HUD, then real drags
along the search's answer). Not run: a phone, ANGLE, a listen.

## 10. Open

A lost day is not saved, so reopening it deals it fresh with full thread (the
same gap as Balance's and Code Break's; it needs the host to keep an
unsolved ending per day). The kitten has one look (a ginger tabby). The
tutorial sheet and menu card show the ring, not the kitten.
