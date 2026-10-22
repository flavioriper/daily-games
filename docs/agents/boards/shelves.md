# Four Shelves

- **Four Shelves is a Puzzles card (2026-10-22)**, roadmap item 4, under
  Words. Jam jars on a pantry dresser hide shelves of four; pick four and
  shelve them, four hearts a day. Spec
  `docs/superpowers/specs/2026-10-22-shelves-design.md`. Id `shelves`,
  prefix `FS_`.
- Files: `puzzles/shelves2d.gd`, `puzzles/shelves_state.gd`,
  `puzzles/shelves_world.gd`, `ui/faces/shelves_art.gd` (jar, halo, plank,
  shelf, the hearts drawn straight), `ui/hud/shelves_tutorial_diagram.gd`,
  `ui/menu/cards/shelves.gd`; the night's `server/functions/src/shelves.ts`.
  The keys under the dresser are Honeycomb's (`honeycomb_art.gd`'s `key`).
- **The day is fetched as Golden Acorn's is** (`_deal`: the cached document,
  else one FETCH_WAIT on the network, else the bank), and `world/main.gd`
  fetches it at boot and the next day's ahead (`AHEAD`).
- **The bank pick is the server's**: least double FNV of
  `shelves|<day>|<id>`. Change one and change both.
- **A revealed day is not a solve**: `is_solved()` is false once any shelf
  went up by Show the shelves; the reveal ends with `finish_unsolved`. The
  card's queued opening checks `_revealing`, or it opened over the reveal.
- The tutorial deals the bank's first puzzle of Easy (Insane for CROWDED),
  so a new bank changes its words.
- Harness: `tests/_win.gd -- shelves` (real touches: a close four, the same
  four again, Clear, the bulb's real button, every shelf);
  `tests/_shot_shelves.gd -- <dir> d=<0..3> [tut=<page>|card|out]`.
  `tests/_probe_shelves.gd` prints the bank's picks and plays the rules.
- Draw calls: 100-129 in play, 140-177 a tutorial page, 6 on the card.
