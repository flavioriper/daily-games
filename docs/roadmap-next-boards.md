# Roadmap: the next daily boards

Started 2026-10-22. Twelve candidate Puzzles-grid boards chosen to fill the
gaps in the brain map (`docs/superpowers/specs/2026-10-22-brain-skills-design.md`).
The visual page with a drawn mock of each board is
`docs/brainstorm/next-daily-boards.html`, published at
https://claude.ai/artifact/GxhHna83Ru7SGrHcJMNXWk.

Nothing here is built or specced. Each board still follows the house order:
a concept tab in `docs/brainstorm/concepts.html`, then a spec, then the build
(`Registry.PUZZLES` entry, `"skill"`, `skill_quality()`, locale keys, sounds
from `tools/sfx_bank/`, four levels). Names below are house names; the
original genre is named once, to forbid it on screen.

## Why these

The 33 Puzzles cards on 2026-10-22: Logic 9, Space 7, Planning 7, Focus 5,
Words 5. **No board trains memory and none trains arithmetic**, the two
headline categories of Lumosity, Peak and Elevate. The big competitor
dailies are mostly covered already (Queens, Binairo for Tango, Caterpillar
for Zip, Shikaku for Patches, Sudoku, Hidden Word, Word Trail). Missing ones:
Connections, Spelling Bee, Pips, Pinpoint, Clues by Sam.

## Decide first (the user's calls, open)

- [x] **Memory as a sixth skill?** Taken as recommended on 2026-10-22, with Glimpse. Touches `core/brain.gd`,
      a `skill_memory` icon in `ui/icons.gd`, `SKILL_MEMORY*` rows in
      `locale/ui.csv`, the five-spoke map on the win; colour = next free
      `Pal.CAT` (`6bb1d6`). Without it, memory boards have no honest home.
- [x] **Arithmetic: own skill or inside Logic?** Taken as recommended on 2026-10-22 (nothing changed yet): inside Logic,
      with Logic's line rewritten to mention numbers; a Numbers skill only
      if a third arithmetic board ships.

## Shortlist (start here, in this order)

- [x] **1. Glimpse** (copy-from-memory). Built 2026-10-22, `docs/agents/boards/glimpse.md`; generated mirrored sprites 6-8 square, not Pixel Garden's bank. Memory. Pixel Garden's picture shows
      3 s, then hides; rebuild it. Reuses Pixel Garden whole. Generator
      trivial, no pt/es cost. Quality: beads right on the first try.
- [x] **2. Birdsong** (Simon-style recall). Built 2026-10-22, `docs/agents/boards/birdsong.md`; drums 3/4/4/4, tunes 5/7/9/9, Insane is Whisper (only the new note sung). Memory. A growing tune on the
      drums, played back. Reuses Drumbeat's road, drums, sound bank. Trivial,
      no pt/es. Quality: longest tune without a slip.
- [x] **3. Domino Patio** (NYT Pips). Built 2026-10-22, `docs/agents/boards/patio.md`; Logic, tiles 4/6/8/8, Insane is The Spare (one tile too many). Numbers/Logic. Lay dominoes so each
      coloured bed meets its rule (sum, equal, less than). Reuses Versus
      Dominoes art. Generator moderate (uniqueness check). No pt/es. Time and
      hints only.
- [ ] **4. Four Shelves** (Connections). **Waits on the user's deploy**
      (2026-10-22): skipped for Teacups, since a board on the Acorn
      pipeline is not playable until the functions are deployed. Words. 16 words, four hidden groups.
      Rides Golden Acorn's pipeline (Haiku writes, Opus reviews), which writes
      en/pt/es; needs a deploy by the user. Quality: mistakes 0-4.

## The rest, ranked

- [x] **5. Teacups** (concentration pairs). Built 2026-10-22, `docs/agents/boards/teacups.md`; cups 12/16/20/20, Insane is Waltz (two hidden cups trade places every second miss). Memory. Trivial. Quality: flips
      vs the minimum.
- [x] **6. Picket Sums** (Killer Sudoku cages). Built 2026-10-22, `docs/agents/boards/picket.md`; 6/6/9/9, Hard and Insane banked (120 days each), Insane is Lost Tags (up to six plots lose their tag). Numbers/Logic. Reuses
      Sudoku's grid, pad, generator. Moderate.
- [x] **7. Market Sums** (24 game / NYT Digits). Built 2026-10-22, `docs/agents/boards/market.md`; fewest steps 2/3/4/5, Insane is Every Crate (all six into the order), dealt on the phone. Numbers. Six numbers to a
      target. Reuses Lattice's tiles. Trivial. Quality: steps vs shortest.
- [ ] **8. Honeycomb** (Spelling Bee). Words. wordfreq lists (licensed);
      three word lists plus a rude-word filter. Quality: share found.
- [ ] **9. Five Clues** (LinkedIn Pinpoint). Words. Acorn pipeline, Pearl
      Dive's typed answers. Quality: clues needed 1-5.
- [x] **10. Who Ate the Pie?** (Clues by Sam). Built 2026-10-22, `docs/agents/boards/pie.md`; bakers 9/12/16/20, Insane is Empty Dish (nobody says how many ate), dealt on the phone. Logic. No-guess deduction over
      eight bakers; faces from `ui/faces/`. Generator hard (solver proves
      every mark), clue templates x3 languages. Quality: wrong marks.
- [ ] **11. Hosepipes** (Flow Free). Space/Planning. Reuses Fairy Lights and
      Caterpillar path drawing. Moderate.
- [ ] **12. Paper Box** (fold-the-net). Space. Five picks a day, new small
      art. Quality: wrong picks.

## Left out on purpose

Code-break, balance scales, tents, one-line drawing and mushroom patch:
the user removed those genres on 2026-10-13 as "not so good", even though
they are the cheapest to generate. Lights Out and the 15-puzzle: too thin or
dated.
