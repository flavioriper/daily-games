# Bridges polish: clarity, hearts, Lantern Night, rewards, motion and sound

2026-09-30, built unattended on `feat/bridges-polish` at the user's word
("let's polish the bridges game, add more smooth animations, reinforce that
the sfx sounds are really cozy, add more visual rewards even if silly to the
user to keep engagement, and make sure the insane difficulty is really
insane, with something totally new (something only us do) that make the game
nearly impossible, user can also fail on insane and hard ... Players are
complaining they can't understand the game quite well, seems to be poorly
done").

Sudoku's, Mushroom Patch's and Queens' passes the same day are the pattern:
the hearts, the dusk and the card, the streak, the gags, the party and the
seal. What is new here is section 1: **the board was hard to understand**,
and that came first. No concept tab: polish of a built screen with the user
away. The flat spec (`2026-09-20-bridges-flat-design.md`) stands except where
this says otherwise. The calls at the end are for the user to judge on the
phone.

## 1. Why players could not understand it, and what changed

Read against how the puzzle is taught elsewhere (the usual apps: "connect
islands with one or two bridges", tap between two islands or drag from one),
the first cut had six problems:

| problem | now |
|---|---|
| **Three planks per pair.** Every other telling allows two, and our own How-to-play caption already said "one or two bridges" while the board took three. | **Two** (`Gen.MAX_PLANKS`). Numbers run 1-8. |
| **A number said nothing about progress.** You had to count planks by eye on an 11x11. | **A ring of slots round every coin**, one per plank the number asks for, filling in wood as planks land, all green when met, all rose when over. |
| **Only one gesture**, a drag from an islet; a tap on a run wiped it. | A **tap on the water between two islets** lays a plank there too (cycles on Easy/Medium); a tap on an islet reads it out ("This islet wants 3 planks. It has 1."). A cell two bare lanes cross belongs to neither, so the drag stays for it. |
| **The near-miss was silent by design**: every number met, the islets in two groups, and nothing happened. Players read the silence as a broken board. | The line says "Every number is happy, but the islets are in 2 groups. Join them into one!" and every islet outside the biggest group pulses with a rose ring. Two groups joined by a plank sparkle. |
| **The How-to-play diagram** was two white dots and a line on a paper grid, with no numbers. | Its own sea: islets 2, 3 and 1, a finger laying two planks then one, the slot rings filling, the coins turning green. Caption: "Each number is how many planks touch it". |
| **Nothing showed the drag.** | A **ghost finger** on Easy and Medium drags from an islet to its neighbour (a lane the answer lays, nearest the middle) until the first plank lands. |

The rules text was rewritten in plain words with the network rule last and
marked most important; the tips cycle every 7 s like Sudoku's (the drag, the
slots, the tap, two at most, one network).

## 2. Hard and Insane can be failed: hearts

| band | sea | hints | hearts | Check |
|---|---|---|---|---|
| Easy (0) | 7x7, 11 islets | 3 | - | yes |
| Medium (1) | 9x9, 16 | 3 | - | yes |
| Hard (2) | 11x11, 24 | **1** | **3** | **no** |
| Insane (3) | **11x11, 30, Lantern Night** | **0** | **2** | **no** |

- **Every plank is judged as it lands** (`state.add`). The answer is unique,
  so a wrong plank is wrong by proof. Planks are only ever added there: a run
  of two right planks is refused for free ("That bridge is right and already
  has two planks. It stays.").
- **The wrong plank** rolls out from the islet the finger left and lands
  like any other, both its islets shiver, a heart splits (`heart_lost`), and
  `CRACK_AFTER` later it **cracks in two and sinks** -- each half tipping
  away, dropping and fading, with bubbles and a ring (`sink`). The state never
  kept it. The lane then carries **a buoy for good** (`state.ruled`, the
  answer's count there): a cross on its band if the lane takes nothing, a bar
  if it takes one. Another plank there is refused for free ("A buoy already
  showed no more planks go there", `ruled`).
- Input, undo, hint and reset wait while a plank sinks; `busy()` holds the
  host's hint video.
- **Out of hearts**: dusk, "The islets have dozed off", and
  `ui/hud/out_of_hearts.gd` with `BR_OUT_BODY`/`_REST`. Try again takes the
  sea back to bare water in Reset's wave with every heart back and the buoys
  gone; One more heart brings the light back.
- The hearts sit on the family's paper pill in a strip over the pool; the
  pool gives up the 64 px, the lattice does not shrink (cell 83.6 on the
  11x11, measured).

## 3. Insane: Lantern Night

**A lantern counts the islets it is joined to, not its planks.** A lantern 2
is joined to exactly two neighbours, by one plank or two each, so it says
nothing about whether it takes two, three or four planks. Every other islet
still counts planks. The puzzle's variants we found are about bridge shape or
extra rules; a search on 2026-09-30 found none that mixes a count of links
with a count of planks on one board.

- **Why it is nearly impossible**: a lantern gives away the network's shape
  and hides its weight, a number gives away the weight and hides the shape,
  and the player holds both across 30 islets, with two hearts, no hints and
  no Check, on a board that propagation (the four rules, including the
  connectivity group rule) cannot finish alone: every banked board needs 3 to
  16 suppositions.
- **The deal** (`Gen.generate_lanterns`): Insane's knobs grow a network (30
  islets, span 6, 16 loops), proved unique; then islets are lit **best
  first** -- each round lights whichever islet leaves the most lanes open
  after propagation, among those that keep the board unique -- until none
  can be. Random lighting left 59 of 60 boards propagation-solvable; best
  first moves that to about one in six, and the miner keeps the hardest.
- **The solver** gained rule 1b: a lantern's sure joins (lanes with a plank
  certain) and maybe joins (lanes that could still take one) bound its
  number; exactly enough maybes are all joined, exactly enough sures close
  the rest. `_legal` checks links on lanterns. A lantern caps no lane below
  two.
- **Graded like a player** (`Gen.solve_logic`): propagation, then
  suppositions -- lay a lane's lowest or highest count in your head, follow
  the rules, cross it off when the board breaks. Hard's own grade is
  propagation alone, and it finishes none of the banked boards.
- **Banked** (`content/insane/bridges.json`, `tools/insane/bridges_ladder.gd`,
  rung = suppositions that crossed a count off, work = suppositions tried).
  The phone checks the runs are lanes, never cross, make one network, and
  every clue is its islet's own count, and trusts the miner's uniqueness
  proof. An empty or broken bank deals a quick live one (one shuffled walk,
  tens of ms).
- **Dark islets** (no number at all) were tried alongside and dropped: the
  uniqueness proof over them took ~50 s a board and the boards came out no
  harder -- the lanterns had already spent the slack.
- How it looks: a dusk veil and reflected stars on the water, and each
  lantern a paper lantern on the moss with a cap, foot, ribs and handle over
  a warm glow; the lanterns come on after the entrance (`lanterns`) and flare
  at the party (`lanterns_glow`).
- Rules add `BR_RULES_LANTERNS`; the tips lead with `BR_TIP_LANTERN`,
  `BR_TIP_LANTERN_2` and `BR_TIP_HEARTS`. `BR_LVL_3` "Lantern Night: 30
  islets, two hearts". A tap on a lantern reads "This lantern wants 2
  friends. It is joined to 1."

## 4. Rewards, even silly

- **The streak**: right planks in a row -- on Hard and Insane the answer's,
  on Easy and Medium any plank that pushes nothing over its number. `combo`
  up the pentatonic from the second, the "x3" bubble over the plank, confetti
  at 5 and 10. A lift, a refusal, a wrong plank, an undo or a reset ends it.
- **A met islet**: its coin **flips over** into green (`COIN_FLIP`), it
  raises **a pennant** on its moss (folds if it comes apart), and three times
  in five, by its hash, a gag: **a little fish leaps** over the water beside
  it (`fish`), **hearts float up** (`love`), or its **coin twirls** a whole
  turn (`twirl`).
- **Two groups joined** sparkle along the plank (`join`).
- **The party**, after the gold wave: the islets **dance** on the beat,
  neighbours half a beat apart (`dance`), confetti twice (`party`), **a paper
  boat sails** along the pool (`boat`), on Insane the lanterns flare, and the
  line shares **a bit of bridge wisdom**, one of twelve (`BR_CHEER_0..11`: "a
  plank is just a tree that learned to swim").
- **The seal**: Flawless (no hint, and no heart lost on Hard and Insane, or
  no Check on Easy and Medium) stamps the gold seal; any Insane solve the
  night seal, "Insane" over "Flawless" or "Lanterns". `completion_record()`
  keeps `flawless` and `hearts`. `share_glyphs()` adds `🏅 Flawless` or
  `🏮 Lanterns[ · Flawless]`.
- `win_delay()` adds `PARTY_AT` + `PARTY_EXTRA`.

## 5. Motion

New: a plank **settles** after it lands (dips a hair into the water and bobs
back); the coin flip; the pennants; the wrong plank's crack and sink; the
buoys; the heart pill; the dusk; the streak bubble; the fish, love hearts and
twirl; the near-miss pulse; the ghost finger; the dance; the boat; the seal's
drop; the lanterns' glow. Under reduce motion: no gags, confetti, coach,
dance or boat; the flip and twirl stand still, the sink is instant, pennants
and the seal stand open.

## 6. Sound

Re-prompted toward soft wood, felt, gentle water and kalimba (the hollow
"bonk" and the tape-rewind undo read as a toy or a scold): `place`,
`remove`, `met`, `over`, `locked`, `undo`, `hint`, `check`, `check_ok`,
`reset`, `enter`, `solved`. New: `join`, `split`, `combo`, `confetti`,
`love`, `twirl`, `fish`, `heart_lost`, `sink`, `ruled`, `out_of_hearts`,
`heart_back`, `stamp`, `party`, `dance`, `boat`, `lanterns`,
`lanterns_glow`. Rendered on the fallback key (the first was out of
credits); **unheard**.

## 7. Numbers

**The bank**: 150 boards kept of 4000 tries (630 passed the gate), 910 ms a
try per thread, 456 s wall on 8 threads. Rungs 3 to 16, median 4;
suppositions tried 4 to 35, median 8; lanterns 9 to 14, median 10; 30 islets
each. All 150 pass the phone's checks (`from_bank`, 0.6 ms worst);
propagation alone fails on all 150; every tenth was re-proved unique on the
Mac.

**Easy to Hard** now deal different boards than before (two planks, not
three): 30 seeds a band came out in 3 / 5 / 10 ms worst, 30 / 26 / 29 of 30
guess-free, all finishable by propagation plus suppositions.

Draw-call peaks from `tests/_shot_bridges.gd -- d=<n> <mode> [rm]` (810x1440,
`--always-on-top`, `opengl3_angle`), one run each:

| mode | peak |
|---|---|
| rest, Easy (ghost finger, an islet read) | 101 |
| right, Easy (streak, flips, pennants, gags) | 101 |
| tap, Easy | 88 |
| wrong, Hard (sink, buoys, card, Try again) | 105 |
| wrong, Insane | 100 |
| right, Insane | 98 |
| solve, Easy (party, boat, seal) | 121 |
| solve, Insane (lanterns flare, night seal) | 108 |
| restore, Insane | 80 |
| solve, Hard, reduce motion | 84 |
| rest, Medium, reduce motion | 86 |

All far under the 855 budget. Suite: 123054 passed, 0 failed.
`tests/_win.gd -- bridges`: PASS.

**Found on the way, fixed**: a reopened solved day came back unlit when the
app had been open under 100 s -- `restore_completed_board` set the solve
moment to `now - 100`, which went negative, and negative was the "not
solved" sentinel. It is `-INF` now.

**Review findings, fixed**: a tap that began on the water was laid (and on
Hard judged) wherever the finger lifted, so sliding off to cancel still cost
a heart -- it now counts only if it lifts on the same lane; timers owed to a
board survived Reset (the near-miss line over bare water) -- `_wipe` bumps
`_gen`, and the near-miss re-reads the board before speaking; the last
plank's islets re-popped their pennants and rang "met" over the solve;
`can_undo()` stayed true while a plank sank and under the card; a mouse
wheel tick laid planks on desktop; a finger held down through a hint's solve
left the aim band on the finished board; a malformed bank entry could error
instead of falling back.

## 8. Calls for the user

1. **Two planks, not three**, changes every daily's board on every band.
2. **Lantern Night on the phone**: whether a paper lantern reads as "counts
   friends, not planks", and whether 30 islets at a cell of 84 stay legible.
3. **Judged planks on Hard** make Hard losable, but a plank that stays is
   known right, and Check is gone there.
4. **The near-miss is now named**, reversing the first spec's decision to
   keep it silent.
5. **The ghost finger** shows one lane the answer lays on Easy and Medium --
   a small gift of information on the easy bands.
6. **Twelve bits of bridge wisdom**: silly on purpose.
7. **Sounds are unheard.**
