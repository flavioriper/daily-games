extends RefCounted

## Untangle's rules, with no scene under them: the lanterns' positions in the
## generator's normalised square, the cords between them, the crossings those
## cords make and where each one meets, and every move that can change them.
## The flat board (puzzles/untangle2d.gd) draws this and nothing else, so what
## is on trial on the phone is the screen and not the game.
##
## The generator is the island's own, untouched (puzzles/untangle_gen.gd), and
## so is the ladder, so a day hands the flat card and the island the identical
## tangle. What is added here is the crossing's *position*: the island reddens
## a caught rope and leaves the player to find where, because a point floating
## over a stage has nothing to stand on; a flat board can draw the knot on the
## spot, and segment_intersects_segment already returns it.
## Spec: docs/superpowers/specs/2026-09-18-untangle-flat-design.md, section 2.

const Gen = preload("res://puzzles/untangle_gen.gd")

const HINTS := 3
## Lanterns per difficulty, the island's ladder: about 12, 17 and 24 cords,
## opening at about 9, 22 and 51 crossings.
## Insane's provisional band, replaced by the bank in batch 2.
const NODES := [7, 10, 14, 20]

var nodes: int = 7
var edges: Array = []                               # [Vector2i], a cord each
var pos: PackedVector2Array = PackedVector2Array()  # where the player has them
var start: PackedVector2Array = PackedVector2Array()
## The generator's own untangled drawing, which is what a hint reaches for.
var planar: PackedVector2Array = PackedVector2Array()
var locked: Array[bool] = []
## One entry per drag that can be taken back, newest last:
## {"node": int, "from": Vector2}.
var history: Array[Dictionary] = []

## Edge index -> true for every cord caught in a crossing.
var bad: Dictionary = {}
## One per crossing: {"key": "<edge>_<edge>", "at": Vector2} in the square.
var knots: Array = []
## Node index -> true for every lantern inside MIN_SEP of another.
var crowded: Dictionary = {}

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	nodes = NODES[clampi(difficulty, 0, NODES.size() - 1)]
	var out: Dictionary = Gen.generate(rng, nodes)
	edges = out.edges
	start = out.start
	planar = out.planar
	pos = out.start.duplicate()
	locked = []
	for i in nodes:
		locked.append(false)
	history = []
	scan()

# --- the rule ---

## Re-reads the whole board: which cords cross, where each crossing meets, and
## which lanterns are piled on each other. Every move ends here, so nothing
## else on the screen has to work any of it out.
func scan() -> void:
	bad = {}
	knots = []
	crowded = {}
	for i in edges.size():
		for j in range(i + 1, edges.size()):
			var e: Vector2i = edges[i]
			var f: Vector2i = edges[j]
			# Cords sharing a lantern always touch; that is not a crossing.
			if e.x == f.x or e.x == f.y or e.y == f.x or e.y == f.y:
				continue
			var at = Geometry2D.segment_intersects_segment(pos[e.x], pos[e.y], pos[f.x], pos[f.y])
			if at == null:
				continue
			bad[i] = true
			bad[j] = true
			knots.append({"key": "%d_%d" % [i, j], "at": at})
	for a in nodes:
		for b in range(a + 1, nodes):
			if pos[a].distance_to(pos[b]) < Gen.MIN_SEP:
				crowded[a] = true
				crowded[b] = true

func crossings() -> int:
	return knots.size()

## True when lantern `i` is an end of any cord caught in a crossing. What a
## hint picks from: moving one already out of trouble teaches nothing.
func in_knot(i: int) -> bool:
	for e in bad:
		var edge: Vector2i = edges[e]
		if edge.x == i or edge.y == i:
			return true
	return false

func is_solved() -> bool:
	return Gen.is_untangled(edges, pos)

func share_glyphs() -> String:
	return "🏮 %d lanterns · %d cords" % [nodes, edges.size()]

# --- moves ---

## A drag has begun on lantern `i`: where it stood goes on the history, and
## comes back off it if the drag turns out to have moved nothing.
func begin(i: int) -> void:
	history.append({"node": i, "from": pos[i]})

func forget() -> void:
	if not history.is_empty():
		history.pop_back()

## The held lantern follows the finger, clamped to the field: a lantern
## dragged off the edge would be unreachable afterwards.
func drag_to(i: int, p: Vector2) -> void:
	pos[i] = Vector2(clampf(p.x, 0.0, 1.0), clampf(p.y, 0.0, 1.0))
	scan()

## Puts the last dragged lantern back where it was picked up, and says which
## one and where. {} when there is nothing to take back.
func undo() -> Dictionary:
	if history.is_empty():
		return {}
	var last: Dictionary = history.pop_back()
	var i := int(last.node)
	pos[i] = last.from
	scan()
	return {"node": i, "to": pos[i]}

## Hangs one lantern on its peg: it goes to the place the generator's own
## untangled drawing put it and can never be dragged again. Prefers one that
## is in a knot. -1 when there is nothing left worth pinning.
func hint() -> int:
	var pick := -1
	for i in nodes:
		if locked[i] or pos[i].is_equal_approx(planar[i]):
			continue
		if in_knot(i):
			pick = i
			break
	if pick < 0:
		for i in nodes:
			if not locked[i] and not pos[i].is_equal_approx(planar[i]):
				pick = i
				break
	if pick < 0:
		return -1
	locked[pick] = true
	pos[pick] = planar[pick]
	var kept: Array[Dictionary] = []
	for h in history:
		if int(h.node) != pick:
			kept.append(h)
	history = kept
	scan()
	return pick

## Moves one lantern outright, for the slides the board scripts: a hint's
## walk to its peg, an undo, and reset's walk home. The position is the
## logical one and changes at once; the board animates the picture of it.
func place(i: int, p: Vector2) -> void:
	pos[i] = p
	scan()

## Back to the tangle the player was given, pegs excepted. Nothing moves
## here: the board walks the lanterns home one at a time through place(), so
## the tangle visibly re-forms rather than snapping back. Returns the ones
## with somewhere to walk to, in index order.
func reset() -> Array[int]:
	var walking: Array[int] = []
	for i in nodes:
		if locked[i] or pos[i].is_equal_approx(start[i]):
			continue
		walking.append(i)
	history = []
	return walking
