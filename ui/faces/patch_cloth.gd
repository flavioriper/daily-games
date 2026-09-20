extends RefCounted

## A patch of cloth, as builder shapes rather than as a Control: the one
## drawing Quilt's board, its rack and its menu card all make. A patch has no
## face on it and a board carries eight of them over a backing, so they are
## batched into one mesh the way `ui/faces/mosaic_tile.gd`'s tiles are, and
## for the same reason -- a Control per cell would be a node per square of a
## thing that is not a square.
##
## **A patch is one silhouette and not a row of cells.** Its cells' boundary
## is traced into a loop, the loop's corners are rounded, and the whole shape
## is filled over a slightly deeper copy of itself -- the lip every piece on
## these screens wears. Cloth is cut in pieces; tiling a patch out of rounded
## squares would draw the seams the game has not sewn yet.
##
## Each shape takes its scale as a Vector2, so a drawn patch can pop in with
## the family's squash and sink under the finger -- the motion vocabulary
## read as curves (docs/art/flat-motion.md, rule 8).
## Spec: docs/superpowers/specs/2026-09-20-quilt-flat-design.md, section 5.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

## A patch's rounded corner and the bottom edge under it, both in cells.
const RADIUS := 0.17
const EDGE := 0.075
## How far a cloth is taken toward the ink for its bottom edge and for the
## stitch along its seams. **Every colour on this board is a `Pal.CLOTH`
## entry or one of these two mixes of one**, so a patch, its lip and its
## stitch can never drift apart.
const DEEP := 0.22
const STITCH := 0.35

## A patch's cloth, by patch index: `Pal.CLOTH`, and see the note there for
## why Queens' `REGION` was tried first and thrown out on a rendered frame.
static func cloth(i: int) -> Color:
	return Pal.CLOTH[i % Pal.CLOTH.size()]

static func cloth_deep(i: int) -> Color:
	return cloth(i).lerp(Pal.TEXT, DEEP)

static func cloth_stitch(i: int) -> Color:
	return cloth(i).lerp(Pal.TEXT, STITCH)

## The boundary loops of a set of cells, in cell units, with straight runs
## collapsed so the fillet rounds corners and not cell boundaries.
##
## One loop for a patch and one for a backing: a patch of six cells cannot
## enclose a hole -- it takes eight -- and the generator throws away a
## backing that does. A loop is walked edge by edge, and a **pinch** (two
## cells meeting at a corner only) is turned through by taking the sharpest
## right turn on offer, which keeps the two lobes as one loop instead of
## stranding one of them.
static func loops(cells: Array) -> Array:
	var have := {}
	for c: Vector2i in cells:
		have[c] = true
	# Every outer edge, wound clockwise on screen (y down).
	var edges := {}
	for c: Vector2i in cells:
		var x := float(c.x)
		var y := float(c.y)
		if not have.has(c + Vector2i(0, -1)):
			_add(edges, Vector2(x, y), Vector2(x + 1.0, y))
		if not have.has(c + Vector2i(1, 0)):
			_add(edges, Vector2(x + 1.0, y), Vector2(x + 1.0, y + 1.0))
		if not have.has(c + Vector2i(0, 1)):
			_add(edges, Vector2(x + 1.0, y + 1.0), Vector2(x, y + 1.0))
		if not have.has(c + Vector2i(-1, 0)):
			_add(edges, Vector2(x, y + 1.0), Vector2(x, y))
	var out: Array = []
	while not edges.is_empty():
		var start: Vector2 = edges.keys()[0]
		var loop := PackedVector2Array([start])
		var here := start
		var dir := Vector2.ZERO
		while true:
			var outs: Array = edges.get(here, [])
			if outs.is_empty():
				break
			var take := 0
			if outs.size() > 1 and dir != Vector2.ZERO:
				var best := -10.0
				for i in outs.size():
					var to: Vector2 = ((outs[i] as Vector2) - here).normalized()
					var turn := dir.x * to.y - dir.y * to.x
					if turn > best:
						best = turn
						take = i
			var next: Vector2 = outs[take]
			outs.remove_at(take)
			if outs.is_empty():
				edges.erase(here)
			else:
				edges[here] = outs
			dir = (next - here).normalized()
			here = next
			if here == start:
				break
			loop.append(here)
		if loop.size() >= 4:
			out.append(_straighten(loop))
	return out

static func _add(edges: Dictionary, from: Vector2, to: Vector2) -> void:
	var outs: Array = edges.get(from, [])
	outs.append(to)
	edges[from] = outs

static func _straighten(loop: PackedVector2Array) -> PackedVector2Array:
	var n := loop.size()
	var out := PackedVector2Array()
	for i in n:
		var back := (loop[i] - loop[(i - 1 + n) % n]).normalized()
		var on := (loop[(i + 1) % n] - loop[i]).normalized()
		if back.dot(on) < 0.999:
			out.append(loop[i])
	return out

## `loop` with every corner cut back by `r` and bridged with a quadratic, as
## a closed ring. `word_trail2d.gd`'s `_filleted` is the open-ended sibling;
## this one has to turn the first corner too, and a concave corner rounds
## inward, which is what makes a notch read as folded cloth.
static func round_loop(loop: PackedVector2Array, r: float) -> PackedVector2Array:
	var n := loop.size()
	if n < 3:
		return loop
	var out := PackedVector2Array()
	for i in n:
		var here := loop[i]
		var back := loop[(i - 1 + n) % n] - here
		var on := loop[(i + 1) % n] - here
		var cut := minf(r, minf(back.length(), on.length()) * 0.5)
		var a := here + back.normalized() * cut
		var c := here + on.normalized() * cut
		out.append_array(Face.Builder.bezier2(a, here, c, 5))
		out.append(c)
	return out

## A cached loop laid out in pixels: scaled by `cell`, moved to `pos`,
## squashed about the middle of a `span`-cell bounding box by `sc`, then
## rounded. `sc` is the pop's squash, so a patch grows about its own middle
## and not about its top-left corner.
static func laid(loop: PackedVector2Array, pos: Vector2, cell: float, span: Vector2i,
		sc := Vector2.ONE) -> PackedVector2Array:
	var mid := pos + Vector2(span) * cell * 0.5
	var out := PackedVector2Array()
	out.resize(loop.size())
	for i in loop.size():
		out[i] = mid + (pos + loop[i] * cell - mid) * sc
	return round_loop(out, RADIUS * cell * minf(absf(sc.x), absf(sc.y)))

## One patch: its silhouette in `face` over a copy of itself `EDGE` lower in
## `deep`, which is the lip every piece on these screens has.
static func patch(b, shape_loops: Array, pos: Vector2, cell: float, span: Vector2i,
		face: Color, deep: Color, sc := Vector2.ONE, alpha := 1.0) -> void:
	if alpha <= 0.0 or sc.x <= 0.0 or sc.y <= 0.0:
		return
	for loop: PackedVector2Array in shape_loops:
		# An outer boundary comes off the walk clockwise and a hole's comes
		# off anticlockwise (measured, not assumed: a ring of eight cells
		# traces +18 and -2). Filling a hole would lay a bar of the deep
		# colour across it, so only the outer loops are drawn -- and a
		# backing with a hole in it is thrown away by the generator anyway.
		if _area(loop) <= 0.0:
			continue
		var pts := laid(loop, pos, cell, span, sc)
		b.polygon(_moved(pts, Vector2(0.0, EDGE * cell)), Color(deep, alpha))
		b.polygon(pts, Color(face, alpha))

## Twice the signed area of a closed loop; positive is clockwise on screen.
static func _area(loop: PackedVector2Array) -> float:
	var a := 0.0
	var n := loop.size()
	for i in n:
		var j := (i + 1) % n
		a += loop[i].x * loop[j].y - loop[j].x * loop[i].y
	return a

## The running stitch along one seam: the straight run from `a` to `b` cut
## into dashes of `on` with `off` between them, each dash a stroke of
## `width`. `reach` in 0..1 draws only that much of the seam, which is how
## the wave sews a seam rather than switching it on.
static func stitch(b, a: Vector2, to: Vector2, width: float, on: float, off: float,
		ink: Color, reach := 1.0) -> void:
	var end := a.lerp(to, clampf(reach, 0.0, 1.0))
	var span := a.distance_to(end)
	if span <= 0.0 or on <= 0.0 or off <= 0.0:
		return
	var walked := 0.0
	while walked < span:
		var next := minf(walked + on, span)
		b.stroke(PackedVector2Array([a.lerp(end, walked / span), a.lerp(end, next / span)]),
			width, ink, false, false)
		walked = next + off

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out
