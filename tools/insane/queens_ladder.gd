extends RefCounted

## Queens' Insane ladder (tools/insane/README.md's contract). Insane is
## Morning Mist: on a 10x10 court, mist has faded the seam between two pairs
## of neighbouring patches; each misty patch takes two queens, every row and
## column still one (Gen.mist).
##
## The rung is the per-mille of the court that singles, bands and reach
## (puzzles/queens_logic.gd, rungs 1 and 2) leave undecided: the share a
## player can only reach by supposing a queen and following her to a
## contradiction. Hard's courts leave nothing (or almost nothing) there, so
## HARD_RUNG keeps boards where more than half the court is open. `work` is
## the suppositions the deep solve took.

const Gen = preload("res://puzzles/queens_gen.gd")
const Logic = preload("res://puzzles/queens_logic.gd")

const N := 10
const MISTS := 2
const HARD_RUNG := 500

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var out := Gen.mist(rng, N, MISTS)
	if out.is_empty() or not out.ok:
		return {}
	return Gen.to_bank(out)

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board, true)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var g := Logic.grade(Gen._flatten(b.region, b.n), b.n, b.quota)
	var unique := bool(b.ok) and Gen.solve_count(b.region, b.n, 2, b.quota) == 1 \
		and (b.mist as Array).size() == MISTS
	return {"rung": int(round(float(g.open2) * 1000.0 / float(b.n * b.n))), "work": int(g.probes),
		"unique": unique and bool(g.solved)}
