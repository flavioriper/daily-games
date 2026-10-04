extends RefCounted

## Sudoku's Hard bank, mined with the Insane miner under the id "sudoku_hard"
## (content/insane/sudoku_hard.json), as Queens' Hard is. The contract is
## tools/insane/README.md's.
##
## Every grid is dug by reasoning (Gen.dig asks Gen.deduce, never a search),
## so no grid asks for a guess; but only one nine in eight dug that way
## stalls singles and wants the pencil's steps, and drawing grids until one
## does cost 194 ms mean and 313 ms worst on the Mac. A board is kept when
## the pencil finishes it and singles alone do not, within Hard's givens.
## The rung is the cells left empty; `work` is unused.

const Gen = preload("res://puzzles/sudoku_gen.gd")

const HARD_RUNG := -1

## Gen's cell tables are static and shared: built once here, as the script
## loads on the main thread, and never while the miner's threads read them.
static var _warm := _warm_up()

static func _warm_up() -> bool:
	Gen.use(9)
	return true

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var sol := Gen.full_grid(rng)
	var puz := Gen.dig(rng, sol, int(Gen.TARGET[2]), -1, PackedInt32Array(), Gen.PENCIL)
	return Gen.to_bank({"puzzle": puz, "solution": sol, "hills": PackedInt32Array()})

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var none := PackedInt32Array()
	var givens := Gen.givens_of(b.puzzle)
	var fits := givens <= int(Gen.TARGET[2]) + int(Gen.GIVENS_SLACK[2]) \
		and Gen.deduce(b.puzzle, Gen.PENCIL, none) and not Gen.deduce(b.puzzle, Gen.SINGLES, none)
	return {"rung": 81 - givens, "work": 0, "unique": fits, "givens": givens}
