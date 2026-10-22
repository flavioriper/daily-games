# Five Clues

- **Five Clues is a Puzzles card (2026-10-22)**, roadmap item 9, under
  Words. Clue cards on a cork board turn one at a time; type the idea they
  share. Spec `docs/superpowers/specs/2026-10-22-clues-design.md`. Id
  `clues`, prefix `FC_`.
- Files: `puzzles/clues2d.gd`, `puzzles/clues_state.gd`,
  `puzzles/clues_world.gd`, `ui/faces/clues_art.gd` (card, back, pin, the
  round pills), `ui/hud/clues_tutorial_diagram.gd`, `ui/menu/cards/clues.gd`;
  the night's `server/functions/src/clues.ts`. Hearts on Insane are
  `shelves_art.gd`'s.
- **It types**: `"tray": "keys"`, Hidden Word's keyboard handed over by
  `set_tray` (Pearl Dive's three calls). Enter is every move.
- **A typed line is judged as the server judges it**: `State.accepts` and
  `clues.ts accepts` fold the same way (`norm`) and accept the same. Change
  one and change both.
- **A card is up only once it has a turn time** (`_turned_at[i] > -INF`):
  the first build read -INF as long turned and showed every word at once.
- The bank's order is the server's (`ordered`, double FNV of
  `clues|<day>|<id>`); Hard takes the hard tier's head, Insane its tail.
- Harness: `tests/_win.gd -- clues` (every key a real touch on the tray: an
  empty Enter, a wrong word, the bulb, the accepted word, Enter);
  `tests/_shot_clues.gd -- <dir> d=<0..3> [tut=<page>|card]`.
