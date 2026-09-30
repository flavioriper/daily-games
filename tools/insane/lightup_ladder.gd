extends RefCounted

## Light Up's Insane ladder (tools/insane/README.md's contract). Light Up's
## Insane is a rule, not a bigger court: Cat Naps, a 10x10 court where four
## to six cats sit on open stones, each wanting exactly her number of lamps
## shining on her (0 napping, 1 basking, 2 greedy), and every block number
## that can go while the answer stays unique is taken off
## (Gen.generate_cats). Taking numbers off proves the court once per block,
## so it is mined here and the phone only reads the answer (State.setup).
##
## There is no technique ladder, so the "rung" is the blocks with no number.
## Hard's 7x7 shows 0 to 15 bare blocks, 5.8 on average and 9 or fewer on 86%
## of 200 seeds, so a kept court has at least ten. `unique` is re-proved from
## the bank encoding with the cats counting, and again with their numbers
## ignored (their stones still take no lamp and need no light), which has to
## find a second answer: the rule carries the day. `work` is the solver's
## nodes on the proof.

const Gen = preload("res://puzzles/lightup_gen.gd")

const W := 10
const H := 10
const WALL_PCT := 0.18
const HARD_RUNG := 9

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var out := Gen.generate_cats(rng, W, H, WALL_PCT)
	return {} if out.is_empty() else Gen.to_bank(out)

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var bare := 0
	var naps := 0
	var greedy := 0
	for row in b.grid:
		for v in row:
			if v == Gen.WALL:
				bare += 1
			elif v == Gen.CAT:
				naps += 1
			elif v == Gen.CAT + 2:
				greedy += 1
	var proof: Dictionary = Gen.solve_cats(b.grid, b.w, b.h, 2)
	var once: bool = int(proof.count) == 1
	var bearing: bool = int(Gen.solve_cats(b.grid, b.w, b.h, 2, true).count) >= 2
	var valid: bool = Gen.is_valid(b.grid, b.bulbs, b.w, b.h)
	return {"rung": bare, "work": int(proof.nodes),
		"unique": once and bearing and valid and naps >= 1 and greedy >= 1}
