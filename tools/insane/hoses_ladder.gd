extends RefCounted

## Hosepipes' Insane (Seedlings) bank (content/insane/hoses.json). The contract is
## tools/insane/README.md's.
##
## A bed proven to have one answer (puzzles/hoses_gen.gd) takes from a tenth
## of a second to a few on the Mac at this band, too slow for a phone at
## board open, so the days are mined here and the live deal is only the
## fallback. There is no technique ladder: every kept bed is proven unique
## by the full search, `rung` is 0 and `work` the nodes the proof
## searched (more is a more tangled bed).

const Gen = preload("res://puzzles/hoses_gen.gd")

const HARD_RUNG := -1

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	return Gen.to_bank(Gen.deal(rng, 3))

static func grade(board: Dictionary) -> Dictionary:
	var day := Gen.from_bank(board)
	if day.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var work := Gen.effort(day)
	return {"rung": 0, "work": maxi(work, 0), "unique": work >= 0}
