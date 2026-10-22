# Teacups

- **Teacups is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  fifth and the third Memory board. Cups upside down on a garden tea table,
  a house friend under each, two of every friend; lift two a turn to find
  the pairs. Spec `docs/superpowers/specs/2026-10-22-teacups-design.md`.
- Files: `puzzles/teacups2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/teacups_state.gd` (bands, deal, lifts, lapses, waltz, peek),
  `puzzles/teacups_world.gd`, `ui/faces/teacup.gd` (the cup, the saucer, the
  found ring, the list of friends), `ui/hud/teacups_tutorial_diagram.gd`,
  `ui/menu/cards/teacups.gd`.
- **A cup is an id with a friend and a place.** Taps resolve a place to its
  cup through `cup_at`; Insane's waltz swaps two ids' places, so what the
  player saw follows the cup.
- **The board runs on its own clock** (`_t`, stood still while
  `clock_held`) and a queue of timed jobs (`_after`), as Birdsong's does. A
  harness steps it by calling `_process(delta)`.
- **The friends are never drawn under a standing cup** (`_gone_at` stays
  -INF until the pair is found). The first build drew all of them under
  every cup, and their edges showed under the rims, which was a memory
  cheat.
- **The board is its own tutorial**: `demo` makes it silent, deaf and laid
  in its own rect; the diagram taps places with `demo_tap`. Lessons LIFT,
  PAIR, REMEMBER, WALTZ (Insane), HINT.
- Harness: `tests/_win.gd -- teacups` (real touches, two misses, one bulb
  with a cup in hand); `tests/_shot_teacups.gd -- <dir> d=<0..3> [tut=<page>|card]`
  shoots rest, lifted, miss, a pair, the waltz (d=3), the win and the
  reopened day, with draw calls.
