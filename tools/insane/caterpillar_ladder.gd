extends RefCounted

## Caterpillar's Insane ladder (tools/insane/README.md's contract). Insane is
## Peckish: an 8x8 garden whose middle leaves carry no numbers -- any order
## -- and a tummy that holds Gen.PECK_HUNGER bare squares between bites.
## Every board is proved to have exactly one walk under those rules.
##
## There is no technique ladder, so the rung is Gen.traps: how many legal
## steps along the answer lead off it, each one a heart on Insane. `work`
## is the fences. HARD_RUNG keeps every proved board; the miner sorts the
## most trap-laden first.

const Gen = preload("res://puzzles/caterpillar_gen.gd")

const HARD_RUNG := 0

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var g := Gen.generate_peckish(rng, Gen.PECK_SIDE, Gen.PECK_SIDE, Gen.PECK_HUNGER,
		Gen.PECK_FENCES, Gen.PECK_CAP)
	return Gen.to_bank(g) if g.unique else {}

static func grade(board: Dictionary) -> Dictionary:
	var g := Gen.from_bank(board)
	if g.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var s := Gen.count(g.cols, g.rows, g.leaves, Array(g.hedges), 2, 400000, g.hunger)
	return {"rung": Gen.traps(g), "work": g.hedges.size(), "unique": s.count == 1 and not s.capped}
