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
## The print on each cloth. Its motifs are the cloth taken toward the card's
## surface (a light print) or toward the ink (a woven one), never another
## hue, so a print tells two patches apart by more than their colour -- which
## a player who cannot tell the sage from the apricot needs -- without ever
## being mistaken for a state. **The print is identity and never state**:
## `puzzles/quilt2d.gd`'s rule that no state is a shade of a piece's own
## colour stands, and nothing about a patch's print ever changes.
const PRINT_LIGHT := 0.5
const PRINT_LIGHT_ALPHA := 0.75
const PRINT_WOVEN := 0.14
const PRINT_WOVEN_ALPHA := 0.24
## How far a band of the print stops short of the patch's edge, in cells --
## clear of the rounded corner (RADIUS) and of the quilting stitch just
## inside the edge (QUILT_INSET), so no band pokes out of the cloth or runs
## under the thread.
const PRINT_MARGIN := 0.16
## The quilting stitch a sewn patch wears just inside its own edge: how far
## in, the thread's width, its dash and gap, and how pale the thread is.
const QUILT_INSET := 0.1
const QUILT_W := 0.032
const QUILT_ON := 0.11
const QUILT_OFF := 0.08
const QUILT_THREAD := 0.62
const SHADOW_ALPHA := 0.16

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

## A point in a patch's own cell units, laid on the card: scaled by `cell`,
## moved to `pos`, squashed by `sc` and turned by `rot` about the middle of
## a `span`-cell bounding box. The one mapping every part of a patch -- its
## silhouette, its print, its stitch, its shadow -- goes through, so a patch
## that pops, leans or lands can never leave its print behind.
static func place(v: Vector2, pos: Vector2, cell: float, span: Vector2i,
		sc := Vector2.ONE, rot := 0.0) -> Vector2:
	var mid := pos + Vector2(span) * cell * 0.5
	return mid + ((pos + v * cell - mid) * sc).rotated(rot)

## A cached loop laid out in pixels through `place`, then rounded. `sc` is
## the pop's squash, so a patch grows about its own middle and not about its
## top-left corner. `radius` in cells, RADIUS by default.
static func laid(loop: PackedVector2Array, pos: Vector2, cell: float, span: Vector2i,
		sc := Vector2.ONE, rot := 0.0, radius := RADIUS) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(loop.size())
	for i in loop.size():
		out[i] = place(loop[i], pos, cell, span, sc, rot)
	return round_loop(out, radius * cell * minf(absf(sc.x), absf(sc.y)))

## One patch: its silhouette in `face` over a copy of itself `EDGE` lower in
## `deep`, which is the lip every piece on these screens has.
static func patch(b, shape_loops: Array, pos: Vector2, cell: float, span: Vector2i,
		face: Color, deep: Color, sc := Vector2.ONE, alpha := 1.0, rot := 0.0) -> void:
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
		var pts := laid(loop, pos, cell, span, sc, rot)
		b.polygon(_moved(pts, Vector2(0.0, EDGE * cell)), Color(deep, alpha))
		b.polygon(pts, Color(face, alpha))

## The soft shadow a lifted patch casts: its silhouette in the ink, pushed
## `by` pixels down and across. Nothing when `by` is zero -- a patch lying on
## something casts only its lip.
static func shadow(b, shape_loops: Array, pos: Vector2, cell: float, span: Vector2i,
		by: Vector2, level: float, sc := Vector2.ONE, rot := 0.0) -> void:
	if level <= 0.0 or by == Vector2.ZERO:
		return
	for loop: PackedVector2Array in shape_loops:
		if _area(loop) <= 0.0:
			continue
		b.polygon(_moved(laid(loop, pos, cell, span, sc, rot), by),
			Color(Pal.TEXT, SHADOW_ALPHA * level))

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

## The closed loop `pts` stroked as dashes of `on` with `off` between them,
## walked by arc length so a rounded corner dashes at the same rate a
## straight run does. `word_trail2d.gd` cuts a ring into dashes the same
## way; this one strokes them as it goes rather than handing back a list.
##
## `limit` stops the walk that far round, which is how a stitch is sewn
## rather than switched on.
static func dash_loop(b, pts: PackedVector2Array, width: float, on: float, off: float,
		ink: Color, limit := INF) -> void:
	var n := pts.size()
	if n < 2 or on <= 0.0 or off <= 0.0 or limit <= 0.0:
		return
	var run := PackedVector2Array([pts[0]])
	var lit := true
	var spent := 0.0
	var gone := 0.0
	for i in n:
		if gone >= limit:
			break
		var a := pts[i]
		var z := pts[(i + 1) % n]
		var full := a.distance_to(z)
		if full <= 0.0001:
			continue
		var span := full
		if gone + full > limit:
			span = limit - gone
			z = a.lerp(z, span / full)
		gone += span
		var walked := 0.0
		while walked < span:
			# Never zero: a dash ending exactly on a corner would otherwise
			# walk nowhere for ever.
			var want := maxf((on if lit else off) - spent, 0.0001)
			if walked + want >= span:
				spent += span - walked
				walked = span
				if lit:
					run.append(z)
			else:
				walked += want
				var p := a.lerp(z, walked / span)
				if lit:
					run.append(p)
					if run.size() >= 2:
						b.stroke(run, width, ink, false, false)
					run = PackedVector2Array()
				else:
					run = PackedVector2Array([p])
				lit = not lit
				spent = 0.0
	if lit and run.size() >= 2:
		b.stroke(run, width, ink, false, false)

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out

## The quilting stitch's thread on cloth `i`: the cloth taken most of the way
## to the surface, so it reads as white cotton that took a little of the dye.
static func cloth_thread(i: int) -> Color:
	return cloth(i).lerp(Pal.SURFACE, QUILT_THREAD)

## The loops of `cells` shrunk by `inset` cells, in cell units: where the
## quilting stitch runs. Cached by the caller -- a patch never changes shape.
static func inset_loops(cells: Array, inset := QUILT_INSET) -> Array:
	var out: Array = []
	for loop: PackedVector2Array in loops(cells):
		if _area(loop) <= 0.0:
			continue
		for shrunk: PackedVector2Array in Geometry2D.offset_polygon(loop, -inset, Geometry2D.JOIN_MITER):
			out.append(shrunk)
	return out

## The print of cloth `i` over the patch made of `cells`, laid through the
## same `place` as its silhouette. Eight prints for eight cloths, by index:
## polka dots, gingham, a sprig of flowers, pinstripes, little crosses, broad
## stripes, pin dots and diamonds. Every motif sits inside its own cell or
## runs along a row or column of the patch and stops PRINT_MARGIN short of an
## outer edge, so the print never needs clipping to the cloth and never draws
## a cell boundary inside one.
static func print_cloth(b, cells: Array, i: int, pos: Vector2, cell: float, span: Vector2i,
		sc := Vector2.ONE, alpha := 1.0, rot := 0.0) -> void:
	if alpha <= 0.0 or sc.x <= 0.0 or sc.y <= 0.0 or cell <= 0.0:
		return
	var light := Color(cloth(i).lerp(Pal.SURFACE, PRINT_LIGHT), PRINT_LIGHT_ALPHA * alpha)
	var woven := Color(cloth(i).lerp(Pal.TEXT, PRINT_WOVEN), PRINT_WOVEN_ALPHA * alpha)
	var k := i % Pal.CLOTH.size()
	var px := cell * minf(sc.x, sc.y)
	var at := func(v: Vector2) -> Vector2: return place(v, pos, cell, span, sc, rot)
	match k:
		1:
			# Gingham: woven bands both ways, darker where they cross.
			_bands(b, cells, [0.25, 0.75], 0.22, woven, true, at)
			_bands(b, cells, [0.25, 0.75], 0.22, woven, false, at)
		3:
			_bands(b, cells, [0.25, 0.75], 0.055, light, false, at)
		5:
			_bands(b, cells, [0.25, 0.75], 0.17, light, true, at)
		_:
			for c: Vector2i in cells:
				var o := Vector2(c)
				match k:
					0:
						for d: Vector2 in [Vector2(0.25, 0.25), Vector2(0.75, 0.25),
								Vector2(0.25, 0.75), Vector2(0.75, 0.75)]:
							b.disc(at.call(o + d), 0.064 * px, light)
					2:
						var mid := o + Vector2(0.5, 0.5)
						for n in 5:
							b.disc(at.call(mid + Vector2.from_angle(TAU * n / 5.0 - PI * 0.5) * 0.11),
								0.07 * px, light)
						b.disc(at.call(mid), 0.045 * px, Color(Pal.SUN_RAY, alpha * 0.9))
					4:
						for d: Vector2 in [Vector2(0.25, 0.25), Vector2(0.75, 0.75)]:
							var m := o + d
							b.stroke(PackedVector2Array([at.call(m - Vector2(0.07, 0.0)),
								at.call(m + Vector2(0.07, 0.0))]), 0.04 * px, light)
							b.stroke(PackedVector2Array([at.call(m - Vector2(0.0, 0.07)),
								at.call(m + Vector2(0.0, 0.07))]), 0.04 * px, light)
					6:
						for y in 3:
							for x in 3:
								b.disc(at.call(o + Vector2(0.21 + 0.29 * x, 0.21 + 0.29 * y)),
									0.038 * px, light)
					7:
						for d: Vector2 in [Vector2(0.25, 0.25), Vector2(0.75, 0.75)]:
							var m := o + d
							b.polygon(PackedVector2Array([at.call(m + Vector2(0.0, -0.09)),
								at.call(m + Vector2(0.07, 0.0)), at.call(m + Vector2(0.0, 0.09)),
								at.call(m + Vector2(-0.07, 0.0))]), light)

## Bands across the patch, one per offset in `offsets` within each row (or
## column, `across` false), `width` cells wide. Each band runs the length of
## every unbroken run of the patch's cells along that row, stopping
## PRINT_MARGIN short of the patch's own edge, and is one quad per run -- so
## a band never breaks at a cell boundary inside the cloth.
static func _bands(b, cells: Array, offsets: Array, width: float, ink: Color,
		across: bool, at: Callable) -> void:
	var have := {}
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for c: Vector2i in cells:
		have[c] = true
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var lines := range(lo.y, hi.y + 1) if across else range(lo.x, hi.x + 1)
	var steps := range(lo.x, hi.x + 2) if across else range(lo.y, hi.y + 2)
	for line: int in lines:
		var start := -1
		for s: int in steps:
			var cell := Vector2i(s, line) if across else Vector2i(line, s)
			if have.has(cell):
				if start < 0:
					start = s
				continue
			if start < 0:
				continue
			for off: float in offsets:
				var y := float(line) + off
				var a := float(start) + PRINT_MARGIN
				var z := float(s) - PRINT_MARGIN
				var h := width * 0.5
				var q := [Vector2(a, y - h), Vector2(z, y - h), Vector2(z, y + h), Vector2(a, y + h)]
				var pts := PackedVector2Array()
				for v: Vector2 in q:
					pts.append(at.call(v if across else Vector2(v.y, v.x)))
				b.polygon(pts, ink)
			start = -1

## How far along the closed loop `pts` a walk of `dist` ends, and which way
## it is heading there: [point, direction]. Where the quilting stitch's
## needle is while it sews.
static func along(pts: PackedVector2Array, dist: float) -> Array:
	var n := pts.size()
	var left := maxf(dist, 0.0)
	for i in n:
		var a := pts[i]
		var z := pts[(i + 1) % n]
		var span := a.distance_to(z)
		if span <= 0.0001:
			continue
		if left <= span:
			return [a.lerp(z, left / span), (z - a) / span]
		left -= span
	return [pts[0], Vector2.RIGHT]

## A closed loop's length.
static func perimeter(pts: PackedVector2Array) -> float:
	var sum := 0.0
	for i in pts.size():
		sum += pts[i].distance_to(pts[(i + 1) % pts.size()])
	return sum

## The needle at the head of a stitch being sewn: a short silver sliver
## pointing the way it is going, with the eye's thread trailing behind it.
static func needle(b, at: Vector2, dir: Vector2, cell: float, thread: Color) -> void:
	var d := dir.normalized()
	var tip := at + d * 0.2 * cell
	var tail := at - d * 0.14 * cell
	b.stroke(PackedVector2Array([tail - d * 0.1 * cell + Vector2(0.0, 0.05 * cell), tail]),
		0.028 * cell, thread)
	b.stroke(PackedVector2Array([tail, tip]), 0.05 * cell, Color("b9bfc6"))
	b.stroke(PackedVector2Array([tail + d * 0.02 * cell, tip - d * 0.06 * cell]),
		0.018 * cell, Color("f4f6f8"))
