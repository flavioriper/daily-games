extends RefCounted

## Sunbeam's Insane ladder (tools/insane/README.md's contract). Insane is
## Shy Dew: the light may never be let go on a dewdrop, until the one move
## that lights every drop at once and ends in the bud. Every board is proved
## to have exactly one answer (Gen.count) and a dark way to it from its
## opening (Gen.dark_path, breadth first, exact).
##
## There is no technique ladder, so the rung is the detour: how many moves
## the shortest dark way takes beyond one a piece. `work` is the traps: how
## many of the opening's legal moves would dry a drop. HARD_RUNG -1 keeps
## every proved board; the miner sorts the longest detours first.

const Gen = preload("res://puzzles/sunbeam_gen.gd")

const HARD_RUNG := -1

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var g := Gen.generate_shy(rng)
	return Gen.to_bank(g) if not g.is_empty() else {}

static func grade(board: Dictionary) -> Dictionary:
	var g := Gen.from_bank(board)
	if g.is_empty():
		return {"rung": -2, "work": 0, "unique": false}
	var d := Gen.dark_path(g, g.drops, g.start)
	var f := Gen.Fast.new(g, g.drops)
	var traps := 0
	var pos: PackedInt32Array = g.start.duplicate()
	for p in f.np:
		var was := pos[p]
		for q in f.rails[p]:
			if q == was or not f.fits(pos, p, q):
				continue
			pos[p] = q
			var r := f.probe(pos)
			if r.x > 0 and r.y == 0:
				traps += 1
		pos[p] = was
	return {"rung": d - int(g.par), "work": traps, "unique": Gen.count(g, 2) == 1 and d > 0}
