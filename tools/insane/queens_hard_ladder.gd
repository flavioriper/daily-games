extends RefCounted

## Queens' Hard bank, mined with the Insane miner under the id "queens_hard"
## (content/insane/queens_hard.json) because grading a live 9x9 on the phone
## was too slow: 184 ms median and 914 ms worst on the Mac, drawing courts
## until one fit. The contract is tools/insane/README.md's.
##
## A board is kept when it fits Hard (Gen.fits: two bands over several lines,
## or a supposition, and still no guess). The rung ranks them for the cut and
## is a score, not a share of the court: 300 for needing a supposition, 100 a
## band over several lines, 10 each time the player had to think. Mined
## 2026-09-30: 127 of the 200 need a supposition, the rest two to five wide
## bands.

const Gen = preload("res://puzzles/queens_gen.gd")
const Logic = preload("res://puzzles/queens_logic.gd")

const N := 9
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
	var rung := mini(999, (300 if not bool(g.solved2) else 0) + 100 * int(g.wide) + 10 * int(g.thinks))
	return {"rung": rung, "work": int(g.probes), "unique": bool(b.ok) and Gen.fits(2, g)}
