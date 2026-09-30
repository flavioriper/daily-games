extends RefCounted

## Mushroom Patch's Insane ladder (tools/insane/README.md's contract). Insane
## is Fairy Rings: a 9x9 patch of fourteen mushrooms where half the numbers
## are fairy rings, counting the sixteen cells two steps out instead of the
## eight touching (puzzles/mushroom_gen.gd). It is carved with the subsets
## solver, then again with suppositions allowed.
##
## The rung is how many cells the deep solve had to reach by supposing one
## answer and following the rules to a contradiction; Hard's solver (plain
## rules, the count and subsets) needs none, so HARD_RUNG keeps only fields
## that need at least one. `work` is the suppositions it tried.

const Gen = preload("res://puzzles/mushroom_gen.gd")

const N := 9
const K := 14
const HARD_RUNG := 0

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var out := Gen.generate(rng, N, K, true, 0.0, float(Gen.RING_SHARE[3]), true)
	if not out.ok:
		return {}
	return Gen.to_bank(out)

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board, true)
	if b.is_empty() or not b.ok:
		return {"rung": -1, "work": 0, "unique": false}
	var plain := Gen.solve(b.given, b.n, b.k, true, b.rings, false)
	var deep := Gen.solve(b.given, b.n, b.k, true, b.rings, true)
	return {"rung": 0 if plain.ok else int(deep.supposed), "work": int(deep.probes),
		"unique": bool(deep.ok)}
