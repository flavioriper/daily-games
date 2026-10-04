extends RefCounted

## Bridges' Insane ladder (tools/insane/README.md's contract). Insane is
## Lantern Night: an 11x11 sea of 30 islets where a lantern counts the islets
## it is joined to rather than its planks (puzzles/bridges_gen.gd). Islets
## are lit in a shuffled walk while the four rules still finish the board
## (Gen.reasoned): no supposition, no guess (the user, 2026-10-04).
##
## The rung is how many lanterns the board kept: a lantern hides its planks,
## so the more of them, the less the numbers say. Gen.LANTERN_MIN is the gate
## (HARD_RUNG is one under it); `work` is the islets.

const Gen = preload("res://puzzles/bridges_gen.gd")

const HARD_RUNG := Gen.LANTERN_MIN - 1

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	return Gen.to_bank(Gen.generate_lanterns(rng))

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var lanes: Dictionary = Gen.lanes_for(b.n, b.islets)
	return {"rung": b.lanterns.size(), "work": b.islets.size(),
		"unique": Gen.reasoned(b.n, b.islets, b.need, lanes, b.lanterns)}
