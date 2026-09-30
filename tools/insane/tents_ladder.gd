extends RefCounted

## Tents' Insane ladder (tools/insane/README.md's contract). Tents' Insane is
## a rule, not a bigger strip of Hard: a 10x10 meadow where three of the trees
## are old oaks that take two tents each, and every line count that can go
## while the answer stays unique is taken off (Gen.generate_oaks). Hiding a
## count proves the board once per line, so it is mined here and the phone
## only reads the answer (State.setup).
##
## There is no technique ladder, so the "rung" is the counts taken off: Hard
## shows every count. `unique` is re-proved from the bank encoding, and again
## with the oaks allowed one tent or two, which has to find a second answer
## (the rule carries the day). `work` is the solver's nodes on the proof.

const Gen = preload("res://puzzles/tents_gen.gd")

const W := 10
const H := 10
const PINES := 10
const OAKS := 3
## Kept boards hide at least twelve of the twenty counts.
const HARD_RUNG := 11

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var out := Gen.generate_oaks(rng, W, H, PINES, OAKS)
	return {} if out.is_empty() else Gen.to_bank(out)

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var hidden := 0
	for n in b.row_counts + b.col_counts:
		if int(n) < 0:
			hidden += 1
	var once: bool = Gen.count_layouts(b.trees, b.oaks, b.row_counts, b.col_counts, b.w, b.h, 2) == 1
	var bearing: bool = Gen.count_layouts(b.trees, b.oaks, b.row_counts, b.col_counts, b.w, b.h, 2, true) >= 2
	var valid: bool = Gen.is_valid_oak_solution(b.tents, b.trees, b.oaks, b.row_counts, b.col_counts, b.w, b.h)
	return {"rung": hidden, "work": 0, "unique": once and bearing and valid}
