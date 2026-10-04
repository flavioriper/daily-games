extends RefCounted

## Sudoku's Insane ladder (tools/insane/README.md's contract). Insane is
## Hilltops: a 9x9 grid where a hill in a cell counts how many of the four
## cells beside it hold a smaller number (puzzles/sudoku_gen.gd). It is dug
## as low as reasoning with the hills goes, every hill reasoning can do
## without is taken out, and it is solved as a player would: singles, the
## pencil's steps and the hills' reckoning (Gen.deduce). No supposition, no
## guess (the user, 2026-10-04).
##
## The rung is the cells left empty; HARD_RUNG keeps the grids with fewer
## givens than any plain grid can have and keep one answer (seventeen), so
## the hills are how a player gets in. `work` is the cells without a hill.

const Gen = preload("res://puzzles/sudoku_gen.gd")

const HARD_RUNG := 81 - 17

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
	var givens := Gen.givens_of(b.puzzle)
	var hills := Gen.hill_total(b.hills)
	return {"rung": 81 - givens, "work": 81 - hills, "unique": Gen.deduce(b.puzzle, Gen.PENCIL, b.hills),
		"givens": givens, "hills": hills}
