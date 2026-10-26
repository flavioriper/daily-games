extends RefCounted

## Picket Sums' Insane bank (content/insane/picket.json), mined with the Insane
## miner as Sudoku's are. The contract is tools/insane/README.md's.
##
## A nine fenced into plots and reasoned through (puzzles/picket_gen.gd) costs
## half a second to two on the Mac, too slow for a phone at board open, so the
## days are mined here and the live deal is only the fallback. Every board is
## finished by the reasoner, never a guess. The rung is the pencil steps the
## reasoner needs (`PG.pencil_steps`; more is harder) and `work` the cells
## left empty. Lost Tags retired 2026-10-26.

const Gen = preload("res://puzzles/sudoku_gen.gd")
const PG = preload("res://puzzles/picket_gen.gd")

## Hard's bank needs the pencil 4.6 times a day on average: Insane keeps
## only days needing it more than this.
const HARD_RUNG := 5

## Gen's cell tables are static and shared: built once here, on the main
## thread, and never while the miner's threads read them.
static var _warm := _warm_up()

static func _warm_up() -> bool:
	Gen.use(9)
	return true

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	return PG.to_bank(PG.generate(rng, 3, -1))

static func grade(board: Dictionary) -> Dictionary:
	var b := PG.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var givens := Gen.givens_of(b.puzzle)
	var ok := PG.deduce(b.puzzle, b.plots, b.sums, int(PG.TIER[3]))
	return {"rung": PG.pencil_steps(b.puzzle, b.plots, b.sums), "work": 81 - givens, "unique": ok,
		"givens": givens}
