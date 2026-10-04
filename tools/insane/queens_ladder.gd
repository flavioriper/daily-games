extends RefCounted

## Queens' Insane ladder (tools/insane/README.md's contract). Insane is
## Morning Mist: on a 10x10 court, mist has faded the seam between two pairs
## of neighbouring patches; each misty patch takes two queens, every row and
## column still one (Gen.mist).
##
## Every court kept finishes on singles, bands and reach
## (puzzles/queens_logic.gd), counting a misty patch as two: no supposition,
## no guess (the user, 2026-10-04). The rung is a score like Hard's, 100 a
## band over several lines and 10 each time the player had to think, and
## HARD_RUNG keeps the courts with at least one such band; the mist is what
## makes them Insane. `work` is the times the player had to think.

const Gen = preload("res://puzzles/queens_gen.gd")
const Logic = preload("res://puzzles/queens_logic.gd")

const N := 10
const MISTS := 2
const HARD_RUNG := 99

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
	var unique := bool(b.ok) and bool(g.solved2) and (b.mist as Array).size() == MISTS
	return {"rung": mini(999, 100 * int(g.wide) + 10 * int(g.thinks)), "work": int(g.thinks),
		"unique": unique}
