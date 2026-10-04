extends RefCounted

## Nonogram's Insane ladder (tools/insane/README.md's contract). Insane is
## Leaf Fall: on a 10x10 (or a 9x11 or 11x9) picture, the wind has tumbled
## some lines' numbers -- every run is there, in any order.
##
## A candidate tumbles every line whose order says something (Gen.can_tumble),
## and while line logic alone (Gen.Lines.line_solve, a tumbled line read in
## every order its numbers allow) does not fill the picture, it puts back the
## order of one line that crosses the cells left open, and tries again. No
## supposition, no guess (the user, 2026-10-04): every board kept is finished
## by reading lines.
##
## The rung is how many lines stayed tumbled: the more leaves, the less the
## clues say. LEAVES_MIN is the gate (HARD_RUNG is one under it); `work` is
## the lines line logic had to read.

const Gen = preload("res://puzzles/nonogram_gen.gd")

## A board keeps at least this many tumbled lines, or it is not Leaf Fall.
const LEAVES_MIN := 8
const HARD_RUNG := LEAVES_MIN - 1
const RETRIES := 24
## The picture's grain (Gen.picture): a smooth blob line-solves even with
## its numbers tumbled; a little raw noise gives lines of several runs.
const GRAIN_MIN := 0.1
const GRAIN_MAX := 0.2

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var shape := Gen.shape_for(rng, 3)
	var bmp := Gen.picture(rng, shape.x, shape.y, rng.randf_range(GRAIN_MIN, GRAIN_MAX))
	if bmp.is_empty():
		return {}
	var c := Gen.clues_of(bmp, shape.x, shape.y)
	var lines: Array = c.rows + c.cols
	var tumbled: Array = []
	for clue in lines:
		tumbled.append(Gen.can_tumble(clue))
	for _i in RETRIES:
		var solver := Gen.Lines.new(c.rows, c.cols, tumbled)
		var g := solver.line_solve()
		if g.is_empty():
			return {}
		if solver.matches(g, bmp):
			return Gen.to_bank(bmp, shape.x, shape.y, tumbled)
		# Put back the order of one tumbled line through the open cells.
		var open: Array = []
		for y in shape.y:
			for x in shape.x:
				if not ((int(g.f[y]) | int(g.e[y])) & (1 << x)):
					if tumbled[y] and not open.has(y):
						open.append(y)
					if tumbled[shape.y + x] and not open.has(shape.y + x):
						open.append(shape.y + x)
		if open.is_empty():
			return {}
		tumbled[open[rng.randi_range(0, open.size() - 1)]] = false
	return {}

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	if b.is_empty():
		return {"rung": -1, "work": 0, "unique": false}
	var leaves := 0
	for f in b.tumbled:
		if f:
			leaves += 1
	var solver := Gen.Lines.new(b.rows, b.cols, b.tumbled)
	var g := solver.line_solve()
	return {"rung": leaves, "work": solver.nodes, "unique": solver.matches(g, b.bitmap)}
