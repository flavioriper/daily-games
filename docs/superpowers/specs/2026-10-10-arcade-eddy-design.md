# Eddy, the Arcade tab's tenth game

2026-10-10. Built in one sitting while the user was away, from their brief
over a link and a screenshot of the reference: "is the next arcade game to
be created, check rules on web, wire everything even sound, do autonomous,
no questions. It's gonna be a water env with a wirlpool that start really
smalling and grow bigger and bigger. The cozy come from things rotating
around faster and faster before being fully drawned. Let's use some leaves,
rubber ducks, toys, let's keep only the first and second tier for now. It
should have a real phisic, if user pass too fast it doesn't have strenght
to pull, first levels can't pull big objects. User control the movement
using a fixed circle pad somewhere on screen". No concept tab came first:
nobody was there to judge one, so it went spec to Godot as the other
unattended builds have, and every call below that the brief did not make is
listed in section 7 as mine.

## 1. Where it lives

On the **Arcade tab**, the tenth card, after Deckchair
(`ui/menu/arcade_tab.gd`, `ui/menu.gd`'s `_open_arcade`). A run played alone
for a score, with the Arcade's boosters, Second chance, gold and end card.

## 2. The game

**It is called Eddy and nothing else**, in code, in a comment, in a sound
prompt, in a commit or on screen. The reference is Infidox's 2026 browser
game *Trash Flow*, named here once to forbid it. What the web gave of it
(its store page and two portals' write-ups; none has the numbers, and the
game itself was not played):

- A vacuum is steered over a field of debris and takes what it passes.
- Every piece is worth points, and the screen reads `LEVEL 1/10` with a
  bar beside it.
- A battery runs down, and the run is over when it is empty.
- Points buy two upgrades: stronger suction and a longer battery.

What was kept is that skeleton: something steered over a field of things,
each worth points; ten levels of growing; a meter that runs out and ends
the run; and the two upgrades, here as the two boosters. The rest is the
brief's: a whirlpool on a pond that starts small and grows, things that go
round faster and faster before they go down, leaves and toys in two tiers,
a real water, and a fixed round pad.

## 3. The water

`arcade/eddy_sim.gd`, pure data, a pond 600 units wide and 1000 tall on
every phone, stepped at 1/60 s (the first build's was 300 wide and as tall
as the screen; the user, 2026-10-10: "a fixed bigger water scene with all
objects rendered, and camera start to zoom out as user get bigger"). Every
kind floats there from the first, and what is new comes onto the water out
of sight.

- **The whirlpool is a vortex with a core** (a Rankine vortex): inside the
  core the water turns as one piece, outside it the turning falls off as
  one over the distance, with 0.45 of it running inward, and it is felt
  out to 4.5 cores. So a thing drawn in goes round faster the nearer it
  gets, with no rule saying so.
- **Everything afloat is moved by the water alone.** Drag: it takes up the
  water's speed over its own `tau` (a leaf 0.35 s, a petal 0.28, an acorn
  0.5, a duck 1.4, a boat 1.8, a ball 2.2). And the press toward the
  middle that turning water is under, given to a thing only as hard as its
  own going round asks. (Without the press, drag alone flings things out
  like a stone on a string; with a press owed to the water's speed rather
  than the thing's own, a whirlpool hurried past bent a still leaf in.)
- **Hurry takes nothing.** The whirlpool travels at up to 60 a second
  (five seconds across the pond; it was 150 until the user's first play:
  "speed is too fast, it should be way slower to move"). **In a hurry it
  loses its pull** (`calm()`: all of it up to a third of its fastest, a
  fifth flat out) and takes none of its core's water along, so a leaf it
  crosses flat out is tugged 2 to 21 units and left. A thing goes down
  only once it is in the mouth, goes round with the water there (`SLIP`)
  and is not being run over (`RUSH`). The streaks round the mouth thin
  away as it hurries, so the lost pull is seen.
- **A small whirlpool cannot grip a big thing.** A thing feels the water
  as the cube of (the core's radius over 1.4 of its own), up to all of it:
  a duck feels 9% at level 1, 24% at 2, 50% at 3, 89% at 4 and all of it
  at 5, where the mouth takes her. Boats go down from level 6, balls from
  7. Sat on a mouth too small, a toy turns there and "Too big until level
  N" is said.
- **Going down** is the one thing done by rule: round the middle, nearer
  and up to 3.4 times as fast, shrinking and darkening, over 0.7 to 1.5 s.

Two tiers, as the brief asked. **Tier 1**: leaves (three colours), petals
(three) and acorns, 1, 1 and 2 points, each 1 toward the growing. **Tier
2**: rubber ducks, sailing boats and beach balls, 10, 15 and 20 points and
6, 8 and 10 toward the growing. The pond keeps 44 small things afloat (two
more a level) and 4 toys (more with the levels), new ones floating in from
the banks.

**Growing.** Ten levels. The core is 7 units at level 1 and 2.6 more a
level (30.4 at ten), the turning 60 at the core's edge and 8 more a level.
Level 1 asks 6 swallowed and each level 6 more.

**The spin** is the reference's battery: 50 seconds of turning, a bar
under the plates, amber and said ("Winding down!") under a quarter.
**Every level gives 7 seconds back.** At nothing the whirlpool
unwinds over 1.4 s and the run is over.

## 4. The screen and the pad

`arcade/eddy_screen.gd`. **The pond is the whole screen, edge to edge**,
as the Factory's land is (the user, 2026-10-10: "the screen should fit
everything, just like the factory does, it's gonna be a pattern from now
on"; the first build had a paper page and the pond in a wooden frame).
**A camera looks at a part of the pond** (the same message as the bigger
pond: "something like .io games does. Camera moves as the player try to
move outside camera on edges"): the open water between the plates and the
pad shows 240 units across at level 1 and 500 at level 10, the whirlpool
roams its middle and takes the camera along from 0.3 of a side, and the
camera stops a mouth's width past the bank, grass beyond it. The whirlpool is drawn under
all that floats.
Over the water lie the top bar, three plates (score, best, the whirlpool's
level of ten) and, at the foot, **the pad in the middle**: a round of pale wood 216 pixels
across with a knob of the pond's water. The knob goes under the finger and
no further than 70 pixels from the middle; the whirlpool goes the way it
leans, faster the further (nothing under 12% of the travel), and stops when
it is let go. At the foot and in the middle, either thumb reaches it and
neither hides the water that is played on. A ring round the pad fills toward the next level.

The pond is drawn from straight above (`arcade/eddy_art.gd`): the light
lying on the water, a grassy bank all round, lily pads, stones and reeds in
the corners. The whirlpool is two meshes scaled as it grows: its mouth,
turned as fast as the core's water, and long streaks round it turned a
quarter as fast.

## 5. The Arcade's kit

- Boosters (`arcade/boosters.gd`): **Long spin** (`ed_long`: 15 seconds
  more) and **Head start** (`ed_head`: the whirlpool starts at level 3).
  They are the reference's two upgrades.
- **Second chance**: the whirlpool winds up again where it stopped with
  half its spin. Not offered to a run that took nothing.
- The record is the score; the tab's "furthest" line is the biggest
  whirlpool (`ARC_BEST_LEVEL`).

## 6. Sound and feel

`SETS["eddy"]` in `tools/gen_sfx.py`, eight cues, all of them Beeline's
three measured takes (the light button on felt, the hollow block, one
muffled kalimba note): `plop` (a small thing down, the one cue that never
stops, -20), `gulp` (a toy down), `low`, `drain`, and the notes `level`,
`start`, `game_over` and `new_best`. **Nothing here is water**: the one new
take asked for, a pebble dropped into a wooden bucket of water, came back
at 1.1 kHz with 84% of itself between 1 and 3 kHz and was not kept. Nothing
follows the turning (a sound that rose with the spin would be a whine).
The pad's press is the button's own click. `tools/measure_sfx.py eddy`: 8
files, 0 flagged. Haptics: a tap as the pad is pressed, a tick for a small
thing down, a bump for a toy, good for a level, a bump as the spin runs
low, bad as the whirlpool unwinds, the win on a new best
(`docs/agents/haptics.md` row 54).

## 7. Checked

- `tests/_probe_eddy.gd` (headless), 0 failed: a still whirlpool takes a
  leaf three cores off; flat out straight over a leaf at levels 1, 5 and
  10 it is not taken (moved 2, 9 and 21 units); at a walk it is; a duck
  two cores from a whirlpool of level 1, 2 and 4 stays afloat and at 5
  goes down; beside a level 1 whirlpool she moves 6 units in three
  seconds. A patient bot scores 362 / 537 / 699 and reaches level 9 or
  10 in 112 seconds; a slower one (it looks again twice a second and leans
  60%) 65 / 95 / 155 and level 5; one that never slows 0 / 1 / 4 and level
  1. Started at level 8, patience still makes 503 to hurry's 22.
- A still whirlpool takes every kind its mouth takes from 0.3 to 4 cores
  off at every level, in 0.7 to 14 seconds (a scratch script; the first
  two versions of the press left things orbiting for ever at levels 2 and
  up, which the bot, always on top of its leaf, never showed and the
  tutorial's shots did).
- `tests/_shot_eddy.gd` through the real menu at 810x1440, on the desktop
  driver (en and pt), on `opengl3_angle` (es) and under reduce motion: a
  ScreenTouch held on the pad through the viewport sets the whirlpool off
  and moves it; with the camera, 115 draw calls waiting, 106 in play, 206 at
  level 5, 266 to 283 grown, 308 with the end card, 321 on the tab
  with ten cards (two a row, five rows).
- `tests/_shot_howto_screen.gd -- eddy`: six pages, 137 to 146 draw calls,
  each page's frames read side by side.
- `tests/_probe_chance.gd` and `tests/_probe_wallet.gd` with Eddy added,
  0 failed (the first's overall limit raised from 90 seconds: nine games
  no longer fitted).

## 8. Calls that are mine, unconfirmed

Calls 2 and 3 were undone on 2026-10-11: see
`2026-10-11-eddy-incremental-design.md`.

1. The name, and the pond with its bank.
2. The reference's battery kept, as the spin: 50 seconds, 7 back a level.
   The brief did not ask for a clock; without one a run has no end.
3. Its upgrades bought with points between levels became the two boosters
   bought with gold; nothing is bought inside a run.
4. Two tiers read as two sizes of thing (leaves, petals, acorns; ducks,
   boats, balls), not two tiers of upgrade.
5. The pad at the pond's foot in the middle, not in a corner; the water
   under it and under the plates is out of play.
6. Ducks from level 5, boats 6, balls 7; a toy the mouth cannot take is
   still nudged, more with each level.
7. Things pass through one another: nothing afloat collides.
8. No sound of water and none that follows the spin.
9. Acorns among the small things (the brief names leaves).
10. A grown whirlpool still takes nothing flat out (`RUSH` 14, `HASTE`
    0.2); a real one that size might. How slow is slow enough: 60 a second
    is my reading of "way slower".

## 9. Not done

Nothing run on a phone (the pad under a thumb, the pond's 60 things on its
driver beyond the ANGLE shot); no sound heard by a person; pt and es
written by me and read by nobody (the run, the level and the end card were
shot in all three and fit); `tests/_probe_arcade_buzz.gd` has no Eddy bot,
so the knocks are read from the code, not traced; the reference was not
played, so its feel is taken from descriptions.
