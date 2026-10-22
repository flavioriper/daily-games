# Glimpse

2026-10-22. The first board of `docs/roadmap-next-boards.md` and the first
board to train **Memory**, the sixth skill. Built unattended on the user's
word ("start next roadmap daily puzzle, do everything autonomous"), so the
roadmap's two open calls were taken as recommended: Memory is a sixth
skill; arithmetic stays inside Logic. No concept tab: the roadmap page
(`docs/brainstorm/next-daily-boards.html`) already drew the board.

Follows the copy-from-memory genre of the brain trainers. House name:
Glimpse.

## The play

Pixel Garden's pegboard, box, plates and iron, run as they are
(`puzzles/glimpse2d.gd` extends `puzzles/pixel_garden2d.gd`). Once the board
has popped in, the day's picture is held up big over the pegboard for a few
seconds, with a bar of time running down over it; the last three seconds
pop. A tap anywhere puts it down sooner. Then it goes back onto the pattern
card, which is covered: an eye and a pip a look left.

The player rebuilds the picture from memory. The box holds exactly the
beads it needs. When every bead is on the board the iron passes: a plate
that is right fuses, a bead in the wrong place hops back into the box. That
is the only feedback: **no hint and no Check** (both read the picture out).
Undo and Reset stay. A tap on the cover holds the picture up again for 1.6 s
and spends a look; with none left it refuses (`GL_NO_LOOKS`).

| Band | Pegs | Colours | Beads | Shown | Looks |
|---|---|---|---|---|---|
| Easy | 6 × 6 | 2 | 8 | 5 s | 3 |
| Medium | 6 × 6 | 3 | 12 | 6 s | 2 |
| Hard | 8 × 8 | 3 | 16 | 6 s | 1 |
| Insane | 8 × 8 | 4 | 22 | 7 s | 1 |

## The picture

Made for the day, not banked (`puzzles/glimpse_state.gd`,
`make_picture`): a blob grown cell by cell on the left half of the board
from a cell beside the middle, mirrored onto the right, centred top to foot;
a 2x2 block is let in only half the time, so the shape keeps arms and gaps.
Its colours are patches grown from seeds spread over the blob (farthest of
three tries), from ten far-apart bead colours. A sprite reads as a thing,
which is easier to hold in mind than noise. Pixel Garden's bank (10 × 10 and
up, 30-70% filled) was too big to remember in a few seconds, so it is not
used. The day's rng picks everything, so the four bands are four dailies.

## Score

`skill_quality()` = the share of the picture's beads whose peg got the right
colour the first time anything was seated on it (`first`, kept through Undo,
Reset and the iron), less 0.1 a look spent. Flawless (the seal) is every
bead right first time with no look. The win's line says how many were right
first time (`GL_WIN_FIRST`, `GL_WIN_ALL`).

## Memory, the sixth skill

`core/brain.gd` `SKILLS` gains `memory` (colour `Pal.CAT[5]`, `6bb1d6`),
`ui/icons.gd` `skill_memory` (a card of four squares, two filled),
`SKILL_MEMORY` and `SKILL_MEMORY_LINE` in three languages. The brain
report's rows follow `SKILLS.size()`. Until a player has played Glimpse,
the report's "lowest" line points every player at it; that is intended.

## Calls taken here, unconfirmed

- The band table above (sizes, show times, looks).
- A look costs 0.1 of quality; the first show is free.
- Mirror symmetry on every band, Insane included.
- The cover's look (an eye, pips) and the card's bug.
- The sounds: Pixel Garden's takes a step off, plus `show`, `hide` and
  `count` from takes on disk. Unheard.
