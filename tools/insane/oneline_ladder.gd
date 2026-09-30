extends RefCounted

## One Line's Insane ladder (tools/insane/README.md's contract). One Line's
## Insane is a rule, not only a bigger lattice: Sunny Spells, a 5x5 lattice
## where some lines are sun-baked and the snail may never cross two sunny
## lines in a row (Gen.generate_sun plants the sun along a random trail, so
## every figure has a walk).
##
## There is no technique ladder, so the "rung" is how often a player who
## knows the old rule and not the new one fails: Gen.sun_blind_odds walks the
## figure WALKS times at random, never taking a refused line and never
## stranding the figure, and the rung is the per-mille of those walks that
## still dead-end. Hard's rule is Fleury's alone (a blind walk there always
## finishes), so HARD_RUNG keeps only figures that fail over 96.5% of such walks.
## `work` is the dead steps along the planted trail: how many allowed,
## unstranding steps a player could take there that no walk finishes from.

const Gen = preload("res://puzzles/oneline_gen.gd")

const COLS := 5
const ROWS := 5
const FILL := 0.5
const ODDS := 0.7
const WALKS := 400
const LINES_MIN := 34
const LINES_MAX := 46
const HARD_RUNG := 965

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var out := Gen.generate_sun(rng, COLS, ROWS, FILL, ODDS)
	return {} if out.is_empty() else Gen.to_bank(out, COLS, ROWS)

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var sun := Gen.Sun.new(b.edges, b.sunny)
	var fine: bool = b.trail.size() == b.edges.size() and b.edges.size() >= LINES_MIN \
		and b.edges.size() <= LINES_MAX and (b.starts.is_empty() or b.starts.has(b.start))
	# The planted trail is legal and leaves no two sunny lines in a row.
	var walked := 0
	var at: int = b.start
	var dry := false
	var traps := 0
	for i in b.trail:
		for pair in sun.adj.get(at, []):
			var j: int = pair[1]
			if walked & (1 << j) or (dry and b.sunny[j]) or j == i:
				continue
			sun.dead = {}
			if not sun.can_finish(walked | (1 << j), pair[0], b.sunny[j]):
				traps += 1
		var e: Vector2i = b.edges[i]
		if (walked & (1 << i)) or (e.x != at and e.y != at) or (dry and b.sunny[i]):
			fine = false
			break
		at = e.y if e.x == at else e.x
		walked |= 1 << i
		dry = b.sunny[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(board.get("lines", ""))
	var blind := Gen.sun_blind_odds(rng, b.edges, b.nodes, b.sunny, WALKS)
	return {"rung": int(round((1.0 - blind) * 1000.0)), "work": traps, "unique": fine}
