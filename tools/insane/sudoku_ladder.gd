extends RefCounted

## Sudoku's Insane ladder (tools/insane/README.md's contract). Insane is
## Hilltops: a 9x9 grid where a hill in a cell counts how many of the four
## cells beside it hold a smaller number (puzzles/sudoku_gen.gd). It is dug
## as low as the hills allow, every hill the answer can do without is taken
## out, and it is solved as a player would: singles and the hills' reckoning,
## then suppositions.
##
## The rung is how many suppositions crossed a number out; Hard's own grade
## (singles) finishes none of them, so HARD_RUNG keeps every grid that needs
## at least one. `work` is the suppositions tried.

const Gen = preload("res://puzzles/sudoku_gen.gd")

const HARD_RUNG := 0

## Gen's cell tables are static and shared: built once here, as the script
## loads on the main thread, and never while the miner's threads read them.
static var _warm := _warm_up()

static func _warm_up() -> bool:
	Gen.use(9)
	return true

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var out := Gen.generate_hills(rng)
	return Gen.to_bank(out)

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var plain := Gen.solve_logic(b.puzzle, b.hills, false)
	var deep := Gen.solve_logic(b.puzzle, b.hills, true)
	var givens := 81 - Array(b.puzzle).count(0)
	return {"rung": 0 if plain.ok else int(deep.supposed), "work": int(deep.probes),
		"unique": bool(deep.ok), "givens": givens, "hills": Gen.hill_total(b.hills)}
