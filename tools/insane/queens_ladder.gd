extends RefCounted

## Queens' Insane ladder (tools/insane/README.md's contract). Insane is the
## game Hard is, only bigger and harder (the user, 2026-10-16: "just a hard
## board but way harder and bigger, instead of adding issues to it"): a plain
## 12x12 court, one queen a row, a column and a patch, no misty patches.
##
## Every court kept finishes on singles, bands and reach
## (puzzles/queens_logic.gd): no supposition, no guess (the user,
## 2026-10-04). Hard keeps two bands over several lines (Gen.fits); Insane
## keeps WIDE of them. The rung is Hard's score, 100 a band over several
## lines and 10 each time the player had to think, and ranks the cut.
## `work` is the times the player had to think.

const Gen = preload("res://puzzles/queens_gen.gd")
const Logic = preload("res://puzzles/queens_logic.gd")

const N := 12
const WIDE := 3
const HARD_RUNG := -1

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var out := Gen.generate(rng, N, Gen.KEEP)
	if not out.ok:
		return {}
	return Gen.to_bank(out)

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board, true)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var g := Logic.grade(Gen._flatten(b.region, b.n), b.n, b.quota)
	return {"rung": mini(999, 100 * int(g.wide) + 10 * int(g.thinks)), "work": int(g.thinks),
		"unique": bool(b.ok) and bool(g.solved2) and int(g.wide) >= WIDE}
