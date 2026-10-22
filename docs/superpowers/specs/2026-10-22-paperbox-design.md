# Paper Box: a space board

2026-10-22, built unattended (the user: "start next roadmap daily puzzle, do
everything autonomous, wire animations, sounds, everything to make it fully
playable and complete like other games"). Roadmap item 12
(`docs/roadmap-next-boards.md`), the last buildable one: items 4 (Four
Shelves) and 9 (Five Clues) wait on the user's functions deploy. The mock is
the roadmap page's (`docs/brainstorm/next-daily-boards.html`), so there is no
concept tab, as with the boards before it.

The genre is the mental-rotation test of folding a flat cube net in the
head. It is a generic test with no product name; the board is **Paper Box**
in code, comments, commits and on screen.

## 1. The game

A flat paper net of six coloured squares lies on a green cutting mat on a
craft table, and three or four paper boxes stand on the table under it,
each seen from its corner (top, right and left faces). Exactly one is the
box the net folds into. Tap it.

- **A wrong box** shivers, is struck off with pencil hatching and a red
  cross, and is counted. It costs nothing else; pick again.
- **The right box** sets the net folding up into its box in front of the
  player: the net tilts toward the eye, each square hinges down after the
  one it hangs from, the shut box turns to show the very corner that was
  picked, then flies to its spot on the shelf on the wall.
- **Five boxes on the shelf** is the day.

No Undo (a pick is a pick), no bin (a day started over would be a day
already seen), no Check (the board says itself whether a pick was right).
**The bulb** strikes one wrong box off (3/2/1/1 a day). It never picks.

## 2. Bands (`puzzles/paperbox_state.gd`)

| | nets | boxes | wrong boxes | bulbs |
|---|---|---|---|---|
| Easy | the six crosses | 3 | two OPPOSITE | 3 |
| Medium | all eleven | 3 | one OPPOSITE, one FLIPPED (or MIRROR) | 2 |
| Hard | all eleven | 4 | three FLIPPED (one may be MIRROR) | 1 |
| Insane, **Stamped** | all eleven | 4 | two TURNED, one FLIPPED (or MIRROR) | 1 |

- **OPPOSITE**: a face takes the colour of the side opposite another shown
  face, so the box shows two sides that never meet. The trick the tutorial
  teaches: two squares with one between them in a straight row are
  opposite.
- **FLIPPED**: a face takes the colour of its own opposite side: three
  sides that do meet at a corner, but round it the wrong way.
- **MIRROR**: the whole picture in a mirror (right and left faces traded).
- **TURNED** (Insane only): every side carries a cream arrow stamp; the
  colours are right but one arrow is turned.

**Every wrong box is proven, never assumed.** `puzzles/paperbox_fold.gd`
folds the net (one model, used for the rules and the animation alike) and
lists the 24 pictures the box shows across its turns; a wrong box is kept
only when none of them is it. **Each wrong box starts from its own turn of
the box**, never from the right picture: built from the right picture,
every wrong box differed from it in one face and the right box was the one
the others agreed with (a shortcut past the folding). `tests/_probe_paperbox.gd`
checks every net folds to six sides and 24 distinct pictures from every
root, and deals 365 days a band: every round has exactly one right box at
its answer, the band's count of boxes, all different; the right box is the
one the others agree with most in 7-12% of rounds (14 of 1825 on Insane),
and the one they agree with least in 2-21%, so neither is a tell. A day
deals in 2 ms.

Five rounds a day, a different net each when the band has one left. Nets
lie wide on the mat (turned when taller than wide), turned and mirrored at
random; the square that stays flat in the fold is one with the most
neighbours.

## 3. The screen

A bleed board (`"bleed": true`, `"tray": "none"`, `"actions": false`,
`"level_card": true`). From the top of the span: a wooden shelf with five
dashed spots for the day's boxes, the table's far edge, the cutting mat
(grid, ruler ticks, "Which box does it fold into?") with the net in it,
the boxes across the foot, and the line "Box 2 of 5 · 1 wrong pick" with a
pencil and a roll of paper tape either side of it.

The world (`puzzles/paperbox_world.gd`): a cream wall with the window's
light, the shelf on brackets, warm table planks with grain, the mat, the
pencil and the tape. The papers, the boxes, the stamps, the hatch and the
shelf spots are `ui/faces/paperbox_art.gd`. One renderer (`sheet()`)
draws the squares placed in 3D through a projection, far to near, each
square's paint side or its kraft back as it faces the eye; `box()` paints a
picture through the same face painter, so a folded net and the box it
matches look the same. Faces are lit by their normal (a form shade, top
lightest, left darkest), never to signal a state: a struck box is hatched,
crossed and dimmed whole.

Six papers: sun, berry, leaf, sky, plum and petal. No character: the
pieces are marks.

Motion: the net slides onto the mat from the right as a round begins and
the boxes drop in after it; a wrong box shivers and its hatch pops in; the
right box hops inside a leaf ring while the others fade; the fold (0.38 s
tilt, a hinge every 0.15 s taking 0.34 s each, a 0.5 s turn by slerp, 0.4 s
shown, a 0.42 s arc to the shelf); the five boxes hop in a wave on the
win, where the shelf alone fills the win's span. Under reduce motion a
right pick puts its box on the shelf at once and nothing slides, drops,
shivers or hops.

## 4. Sound and touch

Every action is a pop from the bank (`tools/gen_sfx.py` set `paperbox`):
`pick` the token, `wrong` the tongue twice falling, `fold` one wrap a hinge
(pitched up a hinge at a time, so the run rides the fold), `made` three
wraps rising, `shelf` the token (pitched up a box at a time), `hush` a quiet
pebble, `enter` a run of tokens. `hint`, `solved`, `confetti` and `party`
(the day with no wrong pick) are Honeycomb's takes, copied. Nothing was
bought. Haptics: `docs/agents/haptics.md` row 28j.

## 5. Brain report

Space. Timed (not in `Brain.UNTIMED`): how fast a box is seen is part of
the skill. `skill_quality()` is 1 - 0.2 a wrong pick (the bulb's strikes
cost only through the hint penalty). Tips `BRAIN_PB_1..4`. Share line: 📦
and a square a box, green right first time, yellow after one wrong pick,
red after more.

## 6. Decided for the user, unconfirmed

- The bands above, the kinds of wrong box per band, and Stamped as
  Insane's rule (an arrow on every side; a turned arrow is a wrong box).
- Five rounds a day at every band.
- Picking goes on after a wrong box (no lives, no reveal).
- The bulb strikes a wrong box rather than showing a fold.
- A wrong pick costs a fifth of the quality score.
- The fold plays about 2.7 s on every right pick (the payoff), with taps
  hushed while it plays.
- The six paper colours; the arrow as the stamp.

Not yet seen or heard: the sounds are unheard, pt/es unread by a speaker,
reduce motion unseen, nothing played on a phone. Medium, Hard (on ANGLE) and
Insane were shot, with every tutorial page and the card.
