# The Insane ladder contract

Each board needing a bank gets one script here, `<puzzle_id>_ladder.gd`,
never loaded by the game -- `tools/mine_insane.gd` is the only thing that
`load()`s it. A ladder is `extends RefCounted` (or any plain script) with:

- `static func candidate(rng: RandomNumberGenerator) -> Dictionary` -- one
  board from the board's own generator at its Insane band's knobs, in the
  state's `from_bank` encoding.
- `static func grade(board: Dictionary) -> Dictionary` -- `{"rung": int,
  "work": int, "unique": bool}`: the lowest solver rung that finishes the
  board (never guessing) plus that rung's work, and whether it is unique.
- `const HARD_RUNG: int` -- the highest rung Hard's own generator accepts;
  a candidate is kept only if its rung is strictly above this.

Run: `godot --headless --path . --script tools/mine_insane.gd -- sudoku 400`
(tries default to `count * 50`; pass a third argument to override).

A mined bank is not proven until its board's own `from_bank` path re-proves
it unique and re-grades it, and Hard's own solver is shown to fail on it --
the miner and the ladder run off the phone and can drift from what ships.
