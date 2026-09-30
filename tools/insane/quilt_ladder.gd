extends RefCounted

## Quilt's Insane ladder (tools/insane/README.md's contract). Insane is Scrap
## Basket: a quilt of nine patches grown in the 7x7 box, dealt in one basket
## with three scraps that belong nowhere on it (puzzles/quilt_gen.gd). The
## player has to find which nine and where; the proof is an exact cover in
## which a patch may be left out, and a board is kept only when exactly one
## choice of patches covers the quilt exactly once.
##
## The rung is that proof's own cost -- the nodes its count-to-two walked --
## which is how every band of this board is graded. HARD_RUNG is Hard's own
## floor (Gen.HARD_NODES), so a banked basket always walks further than the
## least a Hard quilt may; the miner then keeps the furthest. `work` is the
## nodes again, since the proof has no second measure.

const Gen = preload("res://puzzles/quilt_gen.gd")

const HARD_RUNG := Gen.HARD_NODES

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	return Gen.to_bank(Gen.generate_scraps(rng))

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var proof := Gen.count_covers(int(b.cols), int(b.rows), b.region, b.shapes, 2)
	var scraps := 0
	for v in b.answer:
		if int(v) < 0:
			scraps += 1
	return {"rung": int(proof.nodes), "work": int(proof.nodes),
		"unique": int(proof.count) == 1 and scraps > 0, "patches": b.shapes.size(),
		"scraps": scraps}
