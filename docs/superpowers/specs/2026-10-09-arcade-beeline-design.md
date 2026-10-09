# Beeline, the Arcade tab's eighth game

2026-10-09. Built in one sitting while the user was away, from their brief:
"flapbird alike game is the next arcade game to be created, check rules on
web, wire everything even sound, do autonomous, no questions". No concept
tab came first: nobody was there to judge one, so it went spec to Godot as
the other unattended builds have, and every call below that the brief did
not make is listed in section 7 as mine.

## 1. Where it lives

On the **Arcade tab**, the eighth card, after Nightlight
(`ui/menu/arcade_tab.gd`, `ui/menu.gd`'s `_open_arcade`). A run played alone
for a score, with the Arcade's boosters, Second chance, gold and end card.

## 2. The game

**It is called Beeline and nothing else**, in code, in a comment, in a
sound prompt, in a commit or on screen. The reference is Dong Nguyen's 2013
phone game *Flappy Bird*, named here once to forbid it. What was taken from
it, checked on the web (the fan wiki, the open reimplementations, the
pygame learning environment's notes):

- A tap is one flap. **A flap sets the rise to one fixed speed**; it is not
  added to the last, so two quick taps do not climb twice as fast.
- Left alone she sinks under a constant pull, up to a fastest fall.
- **The world passes at one speed for the whole run.** Nothing gets faster.
- Obstacles stand evenly apart, each a pair with a gap of one height at a
  random place.
- **One gap passed is one point.** Nothing else scores.
- Touching an obstacle or the ground ends the run. After an obstacle she
  falls to the ground first.
- Medals at 10, 20, 30 and 40 points.

**No source gave the original's own constants**; the sites agree only on
the reimplementations' (a 288 x 512 field and a gap of 100 were found on
the web; obstacles 52 wide and, at 30 frames a second, a pull of 1, a flap
of -9, a fall capped at 10 and a scroll of 4 pixels a frame are the common
open clone's as I remember them, not re-read today). Those are what
`arcade/beeline_sim.gd` holds, turned into units a second: 400 of sky,
gravity 900, a flap of -270, a fall of 300 at most, 120 along, hedges 52
wide and 150 apart, a gap of 100. The sources disagree about the top of the
screen; here it holds her and costs nothing.

## 3. Its own dress and its two kindnesses

A **bee in a morning garden**: the obstacles are clipped hedges with
blossom in them (a wall of leaf with a rounded end, never a smooth column),
the ground is a lawn, the medals are four **ribbons** (clay, silver, gold,
pearl), and the gap that wins one wears it. The bee is drawn in
`arcade/beeline_art.gd` facing the way she flies; `ui/faces/bee_face.gd` is
the Queens' crowned bee seen from the front and could not be turned.

- **The first gaps are wider**: 126 at the first, closing evenly to the
  100 by the twentieth (`gap_of`).
- **A gap is never more than 80 from the last one's middle** (`MAX_STEP`).
  With a step of 130 a planless player cannot always get down in time:
  `tests/_probe_beeline.gd`'s bot, which only beats when she sinks under a
  line and plans nothing, fell at a median of 39 gaps with 130 and never in
  24,000 gaps with 80.
- She is weighed as a round body of 10 units and drawn at 15, so a near
  miss is a miss.

## 4. The Arcade's kit

- Boosters (`arcade/boosters.gd`): **Dewdrop** (`bl_dew`: the first bump
  only bursts it, and she passes through everything for 1.6 s; on the lawn
  it also lifts her) and **Wide gates** (`bl_wide`: the first ten gaps are
  30 wider).
- **Second chance**: the hedge she met is taken away, she hovers level with
  the next gap, passes through things for 1.6 s, and the next tap goes on.
  Not offered to a run that passed no gap.
- The record is the score. No "furthest" line on the card: the ribbons are
  a function of the score.

## 5. Sound and feel

`SETS["beeline"]` in `tools/gen_sfx.py`, nine cues, ElevenLabs takes. Two
never stop and are dull low taps cut short, the quietest of the set: `flap`
(-25) and `pass` (-21). The rest are occasional: `bump` and `land` (leaf and
grass foley), `dew` (a water drop), and the notes `ribbon`, `start`,
`game_over` and `new_best`, all the low muffled kalimba of Nightlight's
redo, rolled off and eased in, none above -10. Haptics: a flap is its
sound's echo, a gap a tick, a ribbon good, a dewdrop a bump, a hedge or the
lawn flown into bad, a new best the win (`docs/agents/haptics.md` row 49).

## 6. Checked

- `tests/_probe_beeline.gd` (headless): the planless bot never falls in
  600 gaps x 40 runs; with 200 ms between beats and 16 units of error it
  falls at a median of 8, with 220 ms and 22 at 3. The dewdrop, the wide
  gates, the Second chance and the ribbons' marks pass.
- `tests/_shot_beeline.gd` through the real menu at 810x1440, on the
  desktop driver (two readings), on `opengl3_angle`, under reduce motion
  and in pt and es: a ScreenTouch sent through the viewport takes her off; 56 draw
  calls waiting, 62 in play, 69-70 at a ribbon or a bump, 105 with the end
  card, 286 on the tab with eight cards.
- `tests/_shot_howto_screen.gd -- beeline`: six pages, 140-151 draw calls.
- `tests/_probe_chance.gd` and `tests/_probe_wallet.gd` with Beeline added.

## 7. Calls that are mine, unconfirmed

1. The name, the bee and the hedges.
2. The reimplementations' numbers stand in for the original's.
3. The wider first gaps and the 80-unit step between gaps (kinder than the
   reference, on purpose; `GAP_FIRST`, `GAP_CLOSES`, `MAX_STEP`).
4. The top of the sky is safe.
5. The two boosters and what the Second chance does; no chance on a run of
   zero.
6. Ribbons named clay, silver, gold and pearl.
7. The tap that takes a paused run up again is also a beat.
8. No pace rise at all, as in the reference.

## 8. Not done

Nothing run on a phone; no sound heard by a person; pt and es written by
me and read by nobody (the run and the end card were shot in both and
fit; the tutorial card in pt and en); `tests/_probe_arcade_buzz.gd` has no
Beeline bot, so the knocks are read from the code, not traced. After a
Second chance the hedge taken away keeps its number, so if it was the one
wearing a ribbon the gap that pays that ribbon does not wear it.
