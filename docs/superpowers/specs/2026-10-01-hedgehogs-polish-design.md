# Hedgehogs polish: hearts, Sleepwalkers, rewards and sound

2026-10-01, built unattended on `feat/hedgehogs-polish` at the user's word
("let's polish the hedgehogs game, add more smooth animations, reinforce
that the sfx sounds are really cozy, add more visual rewards even if silly
to the user to keep engagement, and make sure the insane difficulty is
really insane, with something totally new (something only us do) that make
the game nearly impossible, user can also fail on insane and hard ... don't
worry if you need to redo something on the logic or design, as long as it
keep the cozy vibe").

Knight's, Sunbeam's, Caterpillar's, Rings' and Pinwheel's passes the same
day are the pattern for hearts, dusk and the card, the streak, the gags,
the party and the seal. The board's own spec
(`2026-09-26-hedgehogs-flat-design.md`) stands except where this says
otherwise. The calls at the end are for the user.

## 1. Bands

| band | lawn | hints | hearts | undo | check |
|---|---|---|---|---|---|
| Easy | 8x10, 12 | 3 | - | yes | yes |
| Medium | 9x11, 17 | 3 | - | yes | yes |
| Hard | 10x11, 21 | **2** | **3** | yes | yes |
| Insane | **Sleepwalkers**, 10x11, 24 | **0** | **2** | **no** | **no** |

`State.HINTS_BY` / `HEARTS_BY`. On Easy and Medium a wrong rake still only
wakes a hedgehog (`HH_RULES_SAFE`). On Hard and Insane it wakes one *and*
splits a heart on the pill over the tally ("Oh! You woke a hedgehog. That
costs a heart."); a chord that wakes several costs one heart, not one each.
Out of hearts: the woken ones doze off, dusk falls, the card -- Try again
(the lawn as dealt, at its opening, hearts full, clock and moves zero;
hints spent stay spent), One more heart (a video, once), Back.

## 2. Insane: Sleepwalkers

**The hedgehogs walk in their sleep. Every third rake the moon's bell rings
and one sleeping hedgehog steps to a covered pile beside it. The two piles
rustle alike -- you see where it walked, never which way -- and every
number round them changes. A flag tucks a hedgehog in: it never walks from
under a flag or into one.**

- **Why it is ours**: checked 2026-10-01. Moving-mine variants exist --
  *Minesweeper Marine* shifts whole rows of blocks after each reveal,
  *Pure Skill Minesweeper* and *MineGraph* secretly relocate mines (the
  first to beat expectation, the second to punish premature guessing). None
  has a single visible step, told as an undirected pair, that the player's
  own flags can pin, with every step chosen so logic still finishes the
  lawn.
- **Why it is nearly impossible**: what you proved a moment ago can stop
  being true. A pile you had worked out was bare may now hold the
  sleepwalker; a number you had settled counts one more or one less. The
  only lever is to flag the ones you are sure of before the bell, because
  a flagged hedgehog never walks. Played by logic alone, a day sees **14
  walks on average** (`tests/_probe_hh_walk.gd`, 30 days, 10 to 19). Two
  hearts, no hints, no Undo, no Check.
- **Fair, always**: `State.walk()` lists every step (a sleeping hedgehog not
  under a flag or woken, to a covered, unflagged, empty neighbour), shuffles
  them in the day's own order (`walk_seed`), and takes the first after which
  `Gen.prove_from` -- the generator's no-guess solver, started from what the
  player can see (raked numbers, woken hedgehogs, a hint's flags; never the
  player's own flags) -- still rakes the whole lawn. Up to `WALK_TRIES` 30
  are tried; with none the bell rings and "everyone stayed snug". A step
  is never taken if a raked number touches only one of its two piles
  (`State._tells_way`): that number would go one up or one down and give
  the direction away (the review measured 54% of walks doing so before
  this rule). So every number either touches both piles and stays as it
  was, or touches neither; walks still average 13.6 a day. So at
  every moment the rest of the lawn is provable from the screen, whatever
  order the player raked in, and without remembering a single rustle. The
  probe played 30 days by logic alone after every walk: 30 solved, no guess,
  no wake; the worst rake plus walk took 5.5 ms.
- **The look**: a crescent moon and three dots after the tally's words,
  lit one a rake; on the ring the moon swings in a sun glow, the dots go
  out, both piles heave twice with a puff of leaves and a moon-blue ring,
  every changed number blinks out and pops back in, and both piles keep
  matching paw prints until the next walk. Input waits `WALK_HOLD`.
- **The numbers shown** are a copy (`_num_view`) synced after every
  gesture, except one that rang the bell: its new counts arrive with the
  rustle, never with the rake.
- Reset on Insane is the whole night over (`State.restart`, "The night
  starts over"): hedgehogs home, nobody woken, flags lifted; hearts lost
  stay lost.
- `HH_LVL_3` "Sleepwalkers: every third rake, a hedgehog wanders"; tips
  `HH_TIP_WALK`, `HH_TIP_RUSTLE`, `HH_TIP_TUCK`, `HH_TIP_BELL`,
  `HH_TIP_HEARTS`; rules `HH_RULES_WALKERS`. A solve shares
  `🌙 Sleepwalkers[ · Flawless]` and stamps the night seal; the record keeps
  where the hedgehogs ended (`hogs`) so a reopened day shows them there.

## 3. Rewards, even silly

- **The streak**: safe rakes in a row that are not hints (a wake, Undo,
  Hint, Reset or the hearts running out ends it): `combo` up the pentatonic
  from the second, the "x3" bubble over the pile from the third, confetti
  at 4, 7 and every 5.
- **Gags** on one safe rake in three, off the day's hash, one at a time:
  **an acorn** the rake turned up hops out, lands a cell along, bounces and
  rolls; **love hearts** float off the pile; **a butterfly** that napped in
  the leaves flutters up and away.
- **Whoosh**: a flood of 20 or more piles sparkles with its own sound.
- **The party** after the sleepers' wave: confetti twice, the nap cat hops
  onto the bed's foot and curls up, hedgehog wisdom (`HH_CHEER_0..11`), and
  the seal: gold for Flawless (no hint and nobody woken), night for any
  Sleepwalkers. `completion_record()` keeps `hearts`, `flawless`, and on
  Insane `hogs`.
- A row tidied (every bare cell in it raked) was considered and **left
  out**: it would tell that the row's covered piles are all hedgehogs.

## 4. Motion

New: a pile under a finger sinks into the lawn (`PRESS_DIP` over
`PRESS_IN`) and springs back on the release; the hearts' pop and split; the
dusk; the walk's heave, puffs, ring, paw prints and the numbers' blink; the
moon's swing; the acorn, hearts and butterfly; the cat and the seal. Under
reduce motion: no heave, swing or gags; the walk is simply there; cat and
seal at once.

## 5. Sound

A new style, `HARVEST` (`tools/gen_sfx.py`): an autumn lawn at dusk, dry
leaves, a little bamboo rake, felt-soft wooden taps, kalimba and a music
box. Re-prompted: all fourteen (`rake`, `gust`, `flag`, `unflag`, `woke`,
`chord`, `refuse` -- was a wooden bonk, `check`, `check_ok`, `undo` -- was a
tape rewind, `hint`, `reset`, `solved`, `enter`). New: `bell`, `snuffle`,
`heart_lost`, `out_of_hearts`, `heart_back`, `combo`, `confetti`, `love`,
`flutter`, `acorn`, `whoosh`, `stamp`, `party`, `purr` (COZY). Rendered on
the fallback key (the main one is out of quota); **unheard** by a person.

## 6. Numbers

`tests/_shot_hedgehogs.gd` at `--resolution 810x1440 --always-on-top`,
windowed, one at a time, peak draw calls from 0.5 s:

| mode | band | peak | ANGLE |
|---|---|---|---|
| rest | Insane | 79 | |
| woke | Hard | 104 | |
| out (dusk, card, Try again) | Hard | 127 | 127 |
| walk | Insane | 93 | 93 |
| streak and gags | Easy | 130 | |
| solve and party | Insane | 136 | 136 |
| solve, reduce motion | Medium | 138 | |
| restore | Insane | 134 | |

Peak 138, 717 under the 855 budget. Suite `passed=122403 failed=0`;
`tests/_win.gd -- hedgehogs` PASS.

## 7. Calls for the user

- **The walk never shows its direction.** Showing it would hand over a
  hedgehog's position every bell, which makes the mode easier than Hard.
- **Every walk is checked to keep the lawn provable** from what is on
  screen, so the mode is brutal but never a coin toss. Dropping the check
  would make it truly impossible on some days.
- **A flag pins whatever is under it**, right or wrong. A wrong flag also
  keeps a sleepwalker out of that pile, which tells the player nothing they
  did not already decide.
- **One heart per gesture**, even when a chord wakes several.
- **Every third rake** (`Gen.WALK_EVERY`); a flood counts as one rake.
- The look (moon, paws, heave) was judged on stills only. Sounds unheard.

- **Review findings, fixed**: an Insane Reset within a third of a second of
  a wake freed the woken faces under callbacks still waiting on them (a
  script error) -- Reset now bumps `_turn`, a wake holds the HUD until the
  hedgehog has popped in, and the face callbacks check the face; the walk's
  direction could be read from a number next to only one pile (above); a
  number left at nought by a walk could not be tapped -- a nought with
  covered neighbours now chords them (the direction rule also stops walks
  from making one); the record keeps the day's `woken` tally, which Try
  again and an Insane Reset put back to sleep. Checked clean by the review:
  the shown numbers after every gesture, solvability after every walk with
  wrong flags laid (0 failures in about 600 walks), every timer race, the
  band cache's key.
