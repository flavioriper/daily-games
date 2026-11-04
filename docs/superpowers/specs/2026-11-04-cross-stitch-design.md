# Cross Stitch

2026-11-04, the first of the five word boards in `docs/roadmap-word-boards.md`
(the user: "let's tackle the next docs/roadmap-word-boards.md item ... Do it
autonomous, commit to main when done"). Built straight from the roadmap's
entry and its published mock; no concept tab was made first, which is the
house's usual order, because the user asked for it to be done unattended.
Calls A (build order) and E (house names) were taken as accepted.

The genre is a swap-the-letters crossword grid; its best-known daily
version is named once in the roadmap, to forbid it, and never in code,
comments, commits or on screen.

## The board

- **A sampler**: six five-letter words on a 5 by 5 linen with four holes
  (cells 6, 8, 16, 18): three across on rows 0/2/4, three down on columns
  0/2/4, agreeing on the nine crossings. 21 letters.
- **Dealt shuffled**; swap any two letters that are not in place by
  dragging one onto the other, or tapping one then the other.
- **Marks** (Hidden Word's colours, so the Words row reads as one family):
  green, stitched, in its place and locked; amber, on the right thread:
  the letter belongs in that word somewhere else (a crossing cell reads
  both its words); a stray is plain linen. Amber is counted per word,
  greens first, then the word's still-needed letters handed out reading
  the word from its start.
- **Swaps**: the band's budget is the sampler's fewest swaps plus a spare
  (`SPARE` 6/5/5/6). The fewest is solved exactly, never assumed: the
  misplaced letters less the most rings their letter graph splits into
  (`State.fewest_from`, the same solver as `tools/build_crossstitch.py`,
  checked against a brute-force search). A swap is final: no Undo, the bin
  shut (`can_reset` false), as a committed row on Hidden Word.
- **Stars** on the tools row's pill (ui/flat/star_line.gd), with the swaps
  left: what the way stands at, `used + to_go` against the fewest: 3 at
  the fewest, 2 within two more, 1 after. A star lost falls with the lip.
- **Bulb, two presses**: the first (one hint) rings two letters that go in
  each other's place (else one letter and the place it wants, by a swap
  that cuts the fewest by one) and threads them in gold; the second swaps
  them, free. The bulb's swaps are always on a fewest path.
- **Out of swaps**: patches sag; Code Break's `out_of_rows.gd` card in this
  board's words: Three more swaps (the `row` rewarded placement, once a
  day) or Show the sampler (every letter flies home; `finish_unsolved`).
  When the swaps left fall below the fewest still needed the board says so
  once (`CS_SAY_TIGHT`).

## Bands

| Band | Words | Fewest | Budget | Rule |
|---|---|---|---|---|
| Easy | Hidden Word's easy + medium answers | 6 | 12 | an across and a down word dealt whole |
| Medium | the same | 8 | 13 | |
| Hard | every answer | 10 | 15 | |
| Insane, *Loose Thread* | every answer | 10 | 16 | no amber |

Banks (`content/insane/crossstitch_<band>[.lang].json`, read through
`InsaneBank`): 365 a band in English; Hard and Insane 365 in pt and es;
Easy/Medium 136/132 in pt and 187/185 in es, because each word may stand in
at most 14 samplers and the common pools are 358 (pt) and 366 (es) words.
They repeat sooner; widening `WORD_CAP` or the pool is the lever.

## Motion and sound

Enter: patches pop in on a diagonal stagger (token run). Pick: lifts and
bobs (pebble). Drag: rides the finger. Swap: two arcs, one over and one
under, lifted at mid-flight (two wraps); marks change as they land, with a
bump. Stitched: a green ring per patch (two wraps rising). Word whole: a
gold running stitch sewn round it by a needle (`SEW_TIME`), a sparkle,
"WORD stitched!" (three wraps to the octave). Refused: a shiver and the
tongue. Win: a wave of hops across the diagonals, confetti; party when
perfect with no bulb. Out: the sag, the tongue falling, the card.
Every cue is a pop from `tools/sfx_bank/` (set `crossstitch` in
`tools/gen_sfx.py`); hint, solved, confetti and party are Honeycomb's raw
takes, never bought. All unheard.

## The world

A sewing table (Scenery.planks) with a linen runner, the sampler's wooden
stretcher frame, the linen's weave, a cross-stitched flower in each hole,
two spools and a tomato pincushion at the foot.
