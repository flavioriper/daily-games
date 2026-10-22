# Picket Sums: a numbers board

2026-10-22, built unattended (the user: "start next roadmap daily puzzle,
do everything autonomous, wire animations, sounds, everything to make it
fully playable and complete like other games"). Roadmap item 6
(`docs/roadmap-next-boards.md`); item 4, Four Shelves, still waits on the
user's functions deploy. The mock is the roadmap page's
(`docs/brainstorm/next-daily-boards.html`, `picket()`), so there is no
concept tab, as with Glimpse, Birdsong, Domino Patio and Teacups.

The genre it follows is the Sudoku variant with summed cages (Killer
Sudoku). That name is never used in code, comments, commits or on screen:
the board is **Picket Sums**, and its cages are **plots**.

## 1. The game

Sudoku's grid, fenced into garden plots. Every row, column and region holds
each number once (Sudoku's rule), and each plot's numbers add up to the
number on its wooden tag, never one twice. Tap a cell, then a number; the
pencil, the cross, Undo and the bulb are Sudoku's own.

A plot whose numbers are all in and add up turns **green**: its cells light
leaf-gold one after another, its tag hops and a `plot` pop plays. A plot
that can no longer come true (a number twice, over its tag, or full and
short) turns **rose** and its tag shakes. Nothing is judged against the
answer: the rose is read off the player's own numbers, as Sudoku's clashes
are. The selected cell's plot is fenced in gold.

## 2. Bands (`puzzles/picket_gen.gd`)

| | grid | plot sizes | reasoner | numbers written in | bulbs | from |
|---|---|---|---|---|---|---|
| Easy | 6 x 6 | 2-3 | singles + sums | 0-3 | 3 | live, ~4 ms |
| Medium | 6 x 6 | 2-4 | + pencil + unit sums | 0-1 | 3 | live, <40 ms |
| Hard | 9 x 9 | 2-4 | + pencil + unit sums | 0-4 | 1 | bank `picket_hard` (120) |
| Insane, **Lost Tags** | 9 x 9 | 2-5 | + pencil + unit sums | 1-6 | 1 | bank `picket` (120) |

**Every day is solved by reasoning, never a guess** (Sudoku's rule since
2026-10-04). The reasoner is Sudoku's singles and pencil steps plus two of
this board's: a plot's **sums** (each cell keeps only the numbers some way
of filling its plot to the tag uses) and, past Easy, the **unit sum** a
player reckons: a row, column or region adds up to 1 + ... + N, so the cells
of it no tagged plot inside it covers add to what is left (a plot of its own
when four cells or fewer). A fencing that stalls the reasoner gets a number
of the answer written in where it was least sure, until it goes through;
the fencing that needed fewest is the day.

**Lost Tags** (Insane's rule, harder by less to go on): up to six plots of
three or more lose their tag. Their numbers still never repeat. A tag is
only taken off while the reasoner still finishes the grid without it.

A nine fenced and reasoned through costs 0.5-2 s in GDScript on the Mac,
too slow at board open on a phone, so Hard and Insane are **mined**
(`tools/insane/picket_hard_ladder.gd`, `picket_ladder.gd`, run through
`tools/mine_insane.gd`) and the live deal is their fallback. The phone
checks a banked day cheaply (`PG.from_bank`: a legal answer, givens and
tags that agree with it, plots that never repeat); every one of the 240 was
re-proved by the reasoner after mining.

## 3. The screen

**It is Sudoku's board** (`puzzles/picket2d.gd` extends `sudoku2d.gd`,
which gained two hooks, `_new_state` and `_new_world`): the tray, panels,
washes, digit pad, waves, daisies, party and seal. Its own:

- **Fences**: each plot outlined 7.5 px inside its cells (at a 100 cell) by
  a faint rail and dashes of wood (pickets), the dashes centred on each run
  so corners meet on a picket. One mesh with the tags' markers, rebuilt only
  when the cell, the selected plot, a standing or a moving tag changes.
- **Tags**: a little cream marker with a wood edge over each plot's
  top-left corner (its first cell in reading order), the sum in body 800;
  `?` on a lost tag. The pencil marks sit a little down and right of
  Sudoku's, clear of it.
- **The world** (`puzzles/picket_world.gd`): a mown lawn, a white picket
  fence across the tools row with daisies at its foot, clover, dew that
  breathes, and the raised bed's rail at the foot.
- **The card** (`ui/menu/cards/picket.gd`): Sudoku's card with its fragment
  fenced and tagged; the go tile's plot reads 9 and holds a 2.

Under reduce motion a plot simply turns green or rose: no light-up, hop or
shake.

## 4. Sound and touch

Sudoku's set whole (house pops: token, wrap, pebble, tongue, lip), copied
into `build/sfx_raw/picket/` and never bought, plus `plot`: three wraps
rising (2, 5, 9 steps). Haptics: Sudoku's map, and `plot` a bump
(`docs/agents/haptics.md` row 28e).

## 5. Brain report

Logic (arithmetic folded into Logic, the roadmap's call). Timed, so not in
`Brain.UNTIMED`; no `skill_quality()`: time and hints only, as the roadmap
said. Tips `BRAIN_PK_1..4`.

## 6. Decided for the user, unconfirmed

- The bands above, and Lost Tags as Insane's rule (up to six).
- Givens where the reasoner stalls, rather than none at all (a plain
  summed-cage grid usually has none; ours has 0-6).
- Undo on every band (Sudoku's Insane has none).
- Green and rose plots, the gold selected fence, the look of the tags.
- Placing the card right after Sudoku's in the registry.
