extends RefCounted

## Picket Sums' Insane (Lost Tags) bank (content/insane/picket.json), mined with the Insane
## miner as Sudoku's are. The contract is tools/insane/README.md's.
##
## A nine fenced into plots and reasoned through (puzzles/picket_gen.gd) costs
## half a second to two on the Mac, too slow for a phone at board open, so the
## days are mined here and the live deal is only the fallback. Every board is
## finished by the reasoner, never a guess. The rung is the cells left empty
## (fewer numbers written in is harder) and `work` the tags lost.

const Gen = preload("res://puzzles/sudoku_gen.gd")
const PG = preload("res://puzzles/picket_gen.gd")

const HARD_RUNG := -1

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
	return {"rung": 81 - givens, "work": Array(b.sums).count(-1), "unique": ok, "givens": givens}
