# The Arcade tab and Firefly

2026-09-27. Built in one sitting while the user was away, from their brief:
"add a new arcade bottomnav, we gonna add some arcade solo games. First one
is galaga like game, check on web for references. Build it, include sfx."

## 1. The tab

A fifth tab on the bottom bar, between Versus and Stats: **Arcade**
(`BAR_ARCADE`; the same word in pt and es). Its icon is a joystick with a
fire button (`ui/icons.gd`'s `arcade`, the hole is the ball's shine). Five
tabs fit the 1080 bar at 200 each; the longest label, `Sequência`, still
clears its pill.

The body (`ui/menu/arcade_tab.gd`) takes the day row's and the grid's room,
as Versus, Stats and Streak do: one card a game and a dim "more arcade soon"
card under it. A game card is a banner (the night vista, `Vistas.CARDS`'s
`firefly`, with the game's own cast drawn still over it), the name, the best
score, a line, the furthest stage and Play. It has no levels: an arcade game
gets harder as it goes. Scores are kept on the device in
`user://arcade.cfg` (`arcade/arcade_record.gd`), never sent.

The fit is the Versus tab's (drop the lines, then shorten the pictures), with
one difference that is a fix: the lines are measured off the font at the
column's width, not read off the labels. A wrapped Label hidden before its
first layout has a width of one pixel and measures thousands tall, so a fit
that reads it always decides the lines do not fit.

## 2. The game

**It is called Firefly and nothing else**, in code, in a comment or on
screen. The reference is Namco's 1981 *Galaga*, named here once to forbid
it. What was taken from it, checked against Wikipedia's and StrategyWiki's
accounts of the arcade game:

- A ship at the bottom that moves sideways and has **two volleys in the air
  at most**.
- A swarm of forty that **flies in along looping paths** in five waves and
  takes its seats: four bosses on top, sixteen of the middle kind in two
  rows of eight, twenty of the small kind in two rows of ten. The swarm
  sways while it gathers and breathes in and out once it has.
- Bugs **peel off and dive** in curves at the ship, firing, and come back in
  over the top to their seats. A boss dives with up to two escorts.
- Scoring: small 50 seated and 100 diving, middle 80 and 160, boss 150
  seated and 400 diving, doubled for each escort shot down first (800,
  1600).
- A boss with two hits, whose first hit changes its colour.
- The **capture beam**: a boss dives alone, stops above the ship and opens a
  beam; a ship caught in it is carried up and lost, and hangs under the
  boss. Shoot that boss **while it is diving** and the ship comes back and
  docks beside yours: a **pair** that fires two shots a volley and is twice
  the target (a hit loses one half, not a life). Shoot it **in its seat**
  instead and the captive turns against you (a rogue, 500 and 1000).
- A **challenging stage** third and every fourth after: forty bugs fly
  through without firing, 100 each, 10,000 for all forty.
- Extra ships at 20,000 and 70,000 and every 70,000 after; three to start.

The re-dress is the garden at night. You are a **firefly** with a lantern
tail and you shoot sparks. The swarm is **gnats** (small), **ladybirds**
(middle) and **moths** (the bosses; their beam is silk). A captive is your
firefly wound in silk; a rogue is one turned rose. The challenging stage is
a **flyby**. Stage flags stand in the bottom-right corner (a sun flag for
ten), spare fireflies as lanterns bottom-left.

## 3. Controls

A finger anywhere on the field: the firefly **follows the slide, not the
finger's spot**, at 1.35 times the slide, so the thumb never covers it and
a small movement crosses the field; a slide past a wall re-anchors so
coming back moves at once. **Holding the finger fires**; the two-volley
limit is the rate. On a keyboard, arrows or A/D and space. Leaving the app
or opening settings pauses; a tap resumes.

## 4. Build

- `arcade/firefly_sim.gd`: the whole game as pure data in field units
  (240 by 372, y down), stepped at a fixed 1/120 s. Paths are Catmull-Rom
  through fractions of the field; a bug walks its path by arc length with a
  cursor (`pi`, `pbase`) so a step is not a walk from the start. The screen
  sets `target_x`, `axis` and `fire` and drains `events`.
- `arcade/firefly_art.gd`: the cast as builder meshes at the origin facing
  up, in pixels for a field unit, cached per look, wing frame and scale, and
  turned by the draw transform -- never rebuilt to move. Shared with the
  tab's banner.
- `arcade/firefly_screen.gd`: the flat top bar (back, title, restart,
  settings), a paper row (score, best, stage), the field in a wooden frame.
  The sky, moon and hedges are one mesh built on resize; stars, shots,
  bullets, beams and the corner marks are one live mesh a frame; each bug is
  one `draw_mesh`. It sits in the `versus_host` group so Android's back
  reaches it.
- `ui/menu.gd`'s `_open_arcade` mounts it and closes back to the tab.

Measured with `tests/_shot_firefly.gd` at `--resolution 810x1440`: **101**
draw calls on the tab, **43** on the stage banner, **82** with the full
swarm seated, **49** in a flyby. The sim costs about 4.3 ms of CPU a game
second headless (`tests/_probe_firefly.gd`, which plays it with a bot and
tallies the events).

## 5. Sounds

`tools/gen_sfx.py firefly`, 22 cues, one take each, awaiting the user's
listen. They take a new style, `ARCADE` ("soft warm 8-bit chiptune"), in
place of the house marimba, because a shooter's zaps want a synth; it is
kept soft and rounded to sit beside the rest. `beam` loops while a beam is
open; `shoot` is the quietest cue, since it fires several times a second.

## 6. Analytics

`arcade_start` (game), `arcade_end` (score, stage, seconds, fired, hits,
kills, best), `arcade_abandon` (score, stage); restart sends the boards'
`board_reset` with `puzzle_id` firefly.

## 7. Open

- Difficulty is tuned by a bot, not a thumb: a phone session should judge
  the dive rate, bullet speed and the 1.35 slide gain.
- The pt/es strings are machine-fluent.
