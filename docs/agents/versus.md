<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Versus

**The bar has four tabs since 2026-09-26** (five since 2026-09-27, with
Arcade -- see below): Puzzles (the daily grid, which
was Home; its key is still `home`), **Versus**, Stats and Streak. Versus
holds games played against someone -- snooker, chess and checkers; the first
is **snooker**, against the
computer only for now (spec `2026-09-26-versus-snooker-design.md`). It is not
a registry entry and not a `PuzzleBase`: `versus/snooker_screen.gd` is its own
screen, mounted by `ui/menu.gd`'s `_open_versus` the way a board host is,
closing back to the Versus tab (`_show_list("versus")`), and Android's back
reaches it through the `versus_host` group.

- **The physics is pure data** (`versus/snooker_sim.gd`, metres and
  seconds, regulation table on end, balls and pockets 1.3x): slide-then-roll
  cloth, spin as surface speed, collisions rewound to their time of impact.
  Run `tests/_probe_snooker.gd` after touching it.
- **The referee reads the table as it stood before the shot**: pots are off
  the table by the time `judge()` runs, so the colour on is
  `next_colour_before(pots)`. Reading it afterwards made every legal colour
  a foul and no frame ever ended; `tests/_probe_snooker_frame.gd` (computer
  against computer, `LEVEL`, `SEED`, `VERBOSE`) is what caught it and should
  finish a frame at every level.
- **The computer plans on a worker thread** against a copy of the table,
  inside a 1.8 s budget; the screen polls the task every frame whatever its
  state, so a hint still thinking when the turn passes never blocks the
  computer's own turn.
- **Its table sounds are foley, not the house style** (2026-09-26):
  `gen_sfx.py` appends a marimba-and-no-transients `STYLE` to every prompt,
  which turned a ball's clack into a soft boop, so a cue may name its own
  style (`FOLEY`). Clacks and cushions are as loud as the contact was hard
  (`Fx2D.cue`'s `volume_db`), and `roll` is a looping voice whose level
  follows the balls' summed speed (`_roll_sound`).
- **The pace is the cue drawn back, not a slot** (2026-09-26): press on the
  cue behind the ball and drag it back along its line; the pace is how far
  it was drawn, and letting go plays (`snooker_table.gd`'s `pulling` and
  `released`). A full draw is `REACH` 380 design px, or the room left to the
  screen's edge when the cue points at one -- a break from the D gets about
  190 -- never under `REACH_MIN` 150, and the cue follows the finger one to
  one. A ruler beside the cue fills with the pull and carries the hint's
  gold notch. The side column holds the spin pad alone.
  `tests/_tap_snooker.gd` drives it by input.
- 139 draw calls at the table since the slot went (149 with it, 146 before the polish of 2026-09-26, spec section 8), 91 on the tab (810x1440).
  The tab's picture is the real table drawn `still`, so it costs the menu
  no per-frame work.
- `tests/_shot_snooker.gd` forces a won frame for its end-card shot and puts
  `user://versus.cfg` back afterwards; a harness that finishes a frame some
  other way must do the same, or it writes a fake win into this Mac's save.

**Chess is the second Versus game** (2026-09-26, spec
`2026-09-26-versus-chess-design.md`), against the computer. The tab now holds
one card a game (banner, name and record, a line, levels beside Play), each
remembering its own level; the "more soon" card went to make room (99 draw
calls on the tab).

- **The rules are pure data** (`versus/chess_rules.gd`: every rule, draws
  included, make/unmake, Zobrist hashes). `tests/_probe_chess.gd` runs perft
  on five reference positions -- run it after touching move generation.
- **The computer** (`versus/chess_ai.gd`) is alpha-beta + quiescence in a
  time budget on a worker thread; the levels are depth and a blur on the
  scores. A move that fails low can tie the best on its bound, so an
  iterative-deepening root must keep the proven best first or a round cut
  short by the clock trusts a blunder (it played Nxf2 into Kxf2 until fixed).
- **A skin is the look and the motion, the board is everything else**:
  `versus/chess_skin.gd` is the contract (build a piece's mesh at its foot;
  answer a `Pose` for every moment: move per type, knock, idle, fidget,
  shiver, tremble, topple, cheer, promote, enter), `versus/chess_skin_garden.gd`
  the house set. Meshes are cached per type, side, face and look and moved by
  transform, never rebuilt to move. The board (`versus/chess_board.gd`) owns
  the rules' mirror (one actor a piece), the clock, the trays and the cues.
  `Skin` is a native Godot class, so the constant is `ChessSkin`.
- The player's pieces are always cream at the bottom; the colour they move
  as swaps every game. 122-129 draw calls at the board since the polish
  of 2026-09-26 (166-170 before; the terrace became one mesh), ANGLE
  agreeing. The board draws two live meshes, one under the pieces and one
  over, rebuilt a frame at a time: marks popping in, ripples, speed lines,
  the impact star, z's, the check's "!", the thought bubble and petals.
  Under reduce motion nothing idles, and two frames are pixel-identical.
- Harnesses: `tests/_shot_chess.gd` (every animation beat and the end card),
  `tests/_tap_chess.gd` (tap and drag by input), `tests/_probe_chess_game.gd`
  (a whole game through the real screen, both sides the computer; it loads
  the screen with `load()` at run time, because a `preload` compiles before
  the `Ads` autoload exists). All put `user://versus.cfg` back.

**Checkers is the third Versus game** (2026-09-26, spec
`2026-09-26-versus-checkers-design.md`), against the computer, built the way
chess is: rules, computer, skin contract, house set, board, screen.

- **Brazilian rules** (`versus/checkers_rules.gd`): flying kings, men take
  backwards, compulsory capture of the most pieces, captured pieces lifted
  at the end of the move. English draughts is the same class's AMERICAN
  flag, kept because its published perft (7 ... 36768 to depth 6) is what
  proves the move generator -- run `tests/_probe_checkers.gd` after touching
  it. A move is a `PackedInt32Array`, not chess's int: a chain can take
  eight.
- **Seen from straight above**: a pose's `lift` is drawn as growth, a rise
  up the screen and a sliding shadow; `flip` turns a piece over (the board
  draws the underside past a quarter). A piece is two meshes, `build_base`
  unturned and `build` turned by `spin`, so a twirl does not swing the
  edge band round the disc. Every piece's eyes are the board's to point
  (`_gaze_of`), quantised to eight directions and baked into the mesh key.
- A piece a move will take leaves `_at_sq` for its tray list the moment
  the move is played, but is `doomed` until the jumper is over it: it stays
  on its square watching, worried, not asleep. Anything that counts a tray
  must skip the doomed and the ones still in the air.
- 125 draw calls on the Versus tab, 130-136 at the board, ANGLE agreeing,
  unchanged by the polish of 2026-09-26 (spec section 10: a striped,
  bevelled lawn, glows in place of flat marks, heaped trays, the toast over
  the top planter, a crouch before a hop, a capture's air trail, the crown's
  sparkles, a fuller win, neighbours who chat). The tab now fits its three cards to the room (`versus_tab.gd`'s `_fit`),
  dropping the blurbs and then picture height rather than the bar.
- Harnesses: `tests/_shot_checkers.gd` (every beat; `reduce` after the
  outdir), `tests/_probe_checkers_game.gd` (a whole game, `UNDO=1` takes
  moves back). Both put `user://versus.cfg` back.

**Haptics** (2026-10-03, `docs/agents/haptics.md` rows 30-32): the cues ring
for both players, so only `hint`, `win`, `lose` (and chess's and checkers'
`draw`) are mapped; everything else is `_fx.buzz` where the hand's side is
to move. `tests/_probe_versus_buzz.gd -- snooker|chess|checkers [rm]` reads the trace through
the real screen (headless; `LEVEL`, `YOU`, `SHOTS`, `SPEED`) and puts
`user://versus.cfg` back.
