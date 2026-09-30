extends RefCounted

## Bridges' Insane ladder (tools/insane/README.md's contract). Insane is
## Lantern Night: an 11x11 sea of 30 islets where a lantern counts the islets
## it is joined to rather than its planks (puzzles/bridges_gen.gd). The
## lanterns are lit best first while the board stays unique, and it is solved
## as a player would: the four rules by propagation, then suppositions.
##
## The rung is how many suppositions crossed a count off; Hard's own grade
## (propagation) finishes none of the kept boards, so HARD_RUNG keeps every
## board that needs at least one. `work` is the suppositions tried. A board
## the suppositions cannot finish is reported not unique, so it is never kept:
## a banked board is always finishable without a guess.

const Gen = preload("res://puzzles/bridges_gen.gd")

const HARD_RUNG := 0

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	return Gen.to_bank(Gen.generate_lanterns(rng))

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var plain := Gen.solve_logic(b.n, b.islets, b.need, b.lanterns, false)
	var deep := Gen.solve_logic(b.n, b.islets, b.need, b.lanterns, true)
	return {"rung": 0 if plain.ok else int(deep.supposed), "work": int(deep.probes),
		"unique": bool(deep.ok), "lanterns": b.lanterns.size(), "islets": b.islets.size()}
