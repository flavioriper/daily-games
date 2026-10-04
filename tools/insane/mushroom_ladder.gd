extends RefCounted

## Mushroom Patch's Insane ladder (tools/insane/README.md's contract). Insane
## is Fairy Rings: a 9x9 patch of fourteen mushrooms where half the numbers
## are fairy rings, counting the sixteen cells two steps out instead of the
## eight touching (puzzles/mushroom_gen.gd). It is carved with the subsets
## solver and nothing else: no supposition, no guess (the user, 2026-10-04).
##
## A field is kept when the subsets solver finishes it and the plain rules
## alone do not. The rung is the cells left covered or carved away -- the
## fewer numbers, the harder -- and RINGS_MIN fairy rings must have survived
## the carve, or it is not Fairy Rings. `work` is the rings.

const Gen = preload("res://puzzles/mushroom_gen.gd")

const N := 9
const K := 14
const HARD_RUNG := 0
const RINGS_MIN := 6

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var out := Gen.generate(rng, N, K, true, 0.0, float(Gen.RING_SHARE[3]))
	if not out.ok:
		return {}
	return Gen.to_bank(out)

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board, true)
	if b.is_empty() or not b.ok:
		return {"rung": -1, "work": 0, "unique": false}
	var rings: int = b.rings.size()
	var fits: bool = rings >= RINGS_MIN and not Gen.solvable(b.given, b.n, b.k, false, b.rings)
	return {"rung": b.n * b.n - b.given.size(), "work": rings, "unique": fits,
		"givens": b.given.size(), "rings": rings}
