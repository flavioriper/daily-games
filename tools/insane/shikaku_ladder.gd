extends RefCounted

## Shikaku's Insane ladder (tools/insane/README.md's contract). Shikaku's
## Insane is a rule, not a harder strip of Hard: an 8x10 field where three
## signs are scarecrows -- no size, no shape, their number is how many plots
## share a fence with theirs -- and every other sign is shaped with as many
## numbers taken off as stay unique (Gen.generate_crows). Taking numbers off
## proves the board once per sign, a second or so on this Mac at worst, so it
## is mined here and the phone only reads the answer (State.setup).
##
## There is no technique ladder, so the "rung" is the signs with no number,
## scarecrows included: Hard's 7x9 takes numbers off about a fifth of its
## shaped signs and never reaches HARD_RUNG. `unique` is re-proved from the
## bank encoding with the scarecrows counting, and again with them read as
## plain blank signs, which has to find a second answer (the rule carries the
## day). `work` is the plots the solver tried.

const Gen = preload("res://puzzles/shikaku_gen.gd")

const W := 8
const H := 10
const MAX_AREA := 12
const CROWS := 3
const HARD_RUNG := 7

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var out := Gen.generate_crows(rng, W, H, MAX_AREA, CROWS)
	return {} if out.is_empty() else Gen.to_bank(out)

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var blank := 0
	for c in b.clues:
		if int(c.area) == 0:
			blank += 1
	var work := [0]
	var once: bool = Gen.solve_count(b.clues, b.w, b.h, 2, true, work) == 1
	var bearing: bool = Gen.solve_count(b.clues, b.w, b.h, 2, false) >= 2
	return {"rung": blank, "work": work[0], "unique": once and bearing}
