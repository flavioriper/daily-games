extends RefCounted

## Fairy Lights' Insane ladder (tools/insane/README.md's contract). Insane is
## Wish Tags: an 8x8 garden where some lanterns wear a paper tag saying how
## many lengths of wire lie between them and the post
## (puzzles/fairy_lights_gen.gd, `generate_tags`). The garden is one the
## propagate-only solver cannot finish, and one the tag solver cannot finish
## with no tags either; the tags left are the fewest, in a seeded stripping
## order, that let the tag solver finish without a guess.
##
## The rung is 0 when the propagate-only solver (Hard's, `Gen.solvable`)
## finishes the garden, and otherwise 1 plus the suppositions the tag solver
## needed that struck a candidate -- so HARD_RUNG 0 keeps out anything
## Hard's solver could do, and the miner keeps the gardens that needed the
## most suppositions. `work` is the candidates the tag solver tried.

const Gen = preload("res://puzzles/fairy_lights_gen.gd")

const HARD_RUNG := 0

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	return Gen.to_bank(Gen.generate_tags(rng))

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var n: int = b.n
	var lanterns := 0
	for m in b.sol:
		if Gen.degree(m) == 1:
			lanterns += 1
	if Gen.solvable(n, b.sol):
		return {"rung": 0, "work": 0, "unique": true, "tags": b.tags.size(), "lanterns": lanterns}
	var proof := Gen.solve_tags(n, b.post, b.sol, b.tags)
	var bare := Gen.solve_tags(n, b.post, b.sol, {})
	return {"rung": 1 + int(proof.rung), "work": int(proof.work),
		"unique": bool(proof.ok) and not bool(bare.ok),
		"tags": b.tags.size(), "lanterns": lanterns}
