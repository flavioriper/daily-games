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

## Made fun (2026-10-29)

The user: "make teacup experience way better to play, and game itself way
funnier to play, right now nobody likes it ... include the peeplet chars
rather than fruits, like it's done on who ate the pie".

- **Measured first** (`tests/_probe_tc_fun.gd`, 80 days a band, a player
  who lifts an unseen cup first, goes straight to a twin they remember and
  forgets with age): 49-64% of turns are blind guesses (the genre), and a
  casual player's lapses p50/p90 are 0/1, 1/3, 1/3, 3/5 by band. The
  remembered half of the game said nothing until the win.
- **The friends are Peeplets**: the day's ten personas
  (`peeplet/peeplet_personas.gd`), one a coat so two never read alike at a
  cup's size, drawn after every older rng draw so the cups and places of a
  day are what they were (`State.persona`, in `day_dict`'s solution). One
  live `ui/peeplet_view.gd` a cup, held still; a friend under a lifted cup
  breathes (UP_FPS 12), slumps on a miss (walker `grieving`), laughs on a
  pair and along the win's wave. Shown only when no cup stands on it.
- **The table is laid row by row**: the board draws the saucers and rims;
  each row is a `Cast<i>` (its Peeplets) and a `Lid<i>` (its cups and the
  names of the friends under lifted cups) so a nearer row stands in front;
  `Top` draws the count, the stars and the toast. A friend's view moves to
  its place's row (a waltz) by `reparent`. A lifted cup rides higher
  (RISE 2.2, SLIDE 0.6) so the Peeplet and its hat are clear of it.
- **Names**: a friend's name sits on its saucer's lip while its cup is up
  (the brain tip "name each friend" made visible).
- **Runs**: pairs in a row climb the pair cue and say so every third
  (toast); a pair found by memory rings its saucers; best run of 3+ on the
  win; kept in the completion record.
- **A lapse says why**: the toast names whose twin was passed over and the
  saucer it stands on is rimmed in berry for RIM_TIME.
- **Live stars** (`ui/flat/star_line.gd`) by lapses + bulbs,
  `State.STARS_CUT` [[0,2],[1,3],[1,3],[3,5]], beside the pair count (the
  lift count left the line; it stays on the win).
- **The bulb reads before it acts**: with a cup in hand the first press
  (one hint) says whether its twin has been seen and, when not, rims the
  cups never lifted in leaf green (gold would be lost in the saucers' own line); a second press while that cup is up lifts the
  twin, free. With no cup in hand a hidden pair peeks at once, as before.
  The tutorial's HINT page presses twice.
- **The menu card**: two live Bea twins (persona 2) in place of the baked
  berries; the lifted cup is drawn by a layer over the front one. 11 draw
  calls.
- Deals, lapse rule, Waltz, sounds untouched. opengl3_angle 810x1440: d=1
  108-114 play, 178 won; d=3 116-122, 183 won; tutorial page 150-163.
  `_win.gd teacups` PASS (lapse toast + rim, reading, free second press,
  a view a cup); suite 303252/0. Unseen on a phone (up to 20 SubViewports,
  as Pie's Insane).
