extends RefCounted

## How Big?'s drawings: the silhouettes of the things the board sizes, and
## the marks that go with them (a measure's bracket, the grip, a heart).
## Builder shapes and not a Control, as ui/faces/horse_parts.gd and
## ui/faces/patch_cloth.gd are: the board bakes a round into one mesh, and
## the menu card and the tutorial draw the same shapes.
##
## A silhouette is data, never an image: content/how_big_shapes.json holds
## each thing's outline loops and its triangles (tools/build_how_big.py cuts
## them from the vector sources), in the thing's own units with the box's
## top left at the origin and y down. `fill` lays the triangles down under a
## transform and feathers every loop -- outward round the body, inward round
## a hole -- at the size it is drawn, so a silhouette is rebuilt as it is
## sized rather than scaled, and its edge stays a pixel and a half soft
## whether it is an ant or a whale.

const State = preload("res://puzzles/how_big_state.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

static var _prep: Dictionary = {}

## A thing's shape, read once: {"size", "tris": PackedVector2Array, "loops":
## [PackedVector2Array], "rims": [PackedVector2Array]} -- a rim is a loop's
## unit normals, pointing away from the ink.
static func prep(id: String) -> Dictionary:
	if _prep.has(id):
		return _prep[id]
	var src: Dictionary = State.shape(id)
	var out := {"size": Vector2(float(src.get("w", 1.0)), float(src.get("h", 1.0))),
		"tris": _points(src.get("tris", [])), "loops": [], "rims": []}
	var loops: Array = []
	for raw in src.get("loops", []):
		var pts := _points(raw)
		if pts.size() >= 3:
			loops.append(pts)
	for i in loops.size():
		var pts: PackedVector2Array = loops[i]
		# A loop inside an odd number of the others is a hole.
		var depth := 0
		for j in loops.size():
			if j != i and Geometry2D.is_point_in_polygon(pts[0], loops[j]):
				depth += 1
		out.loops.append(pts)
		out.rims.append(_rim(pts, depth % 2 == 1))
	_prep[id] = out
	return out

static func _points(raw) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not (raw is Array):
		return pts
	pts.resize(raw.size() / 2)
	for k in pts.size():
		pts[k] = Vector2(float(raw[k * 2]), float(raw[k * 2 + 1]))
	return pts

static func _rim(points: PackedVector2Array, hole: bool) -> PackedVector2Array:
	var n := points.size()
	var area := 0.0
	for i in n:
		var j := (i + 1) % n
		area += points[i].x * points[j].y - points[j].x * points[i].y
	var out := (1.0 if area > 0.0 else -1.0) * (-1.0 if hole else 1.0)
	var rim := PackedVector2Array()
	rim.resize(n)
	for i in n:
		var e0 := (points[i] - points[(i - 1 + n) % n]).normalized()
		var e1 := (points[(i + 1) % n] - points[i]).normalized()
		var nrm := Vector2(e0.y, -e0.x) + Vector2(e1.y, -e1.x)
		if nrm.length_squared() < 1e-8:
			nrm = Vector2(e1.y, -e1.x)
		rim[i] = nrm.normalized() * out
	return rim

## The shape's box in its own units.
static func size_of(id: String) -> Vector2:
	return prep(id).size

## Width over height.
static func aspect(id: String) -> float:
	var s: Vector2 = prep(id).size
	return s.x / maxf(s.y, 1.0)

## The transform that stands the shape with its box's bottom left on `foot`
## (or its bottom right, `from_right`) and its longer side `long_px` long.
static func stand(id: String, foot: Vector2, long_px: float, from_right := false) -> Transform2D:
	var s: Vector2 = prep(id).size
	var k := long_px / maxf(s.x, s.y)
	var at := foot - Vector2(s.x * k if from_right else 0.0, s.y * k)
	return Transform2D(0.0, Vector2(k, k), 0.0, at)

## The silhouette in `colour`, under `xf` (the shape's units to pixels).
static func fill(b: Face.Builder, id: String, xf: Transform2D, colour: Color) -> void:
	var p := prep(id)
	var tris: PackedVector2Array = xf * (p.tris as PackedVector2Array)
	var first := b.verts.size()
	b.verts.append_array(tris)
	var cs := PackedColorArray()
	cs.resize(tris.size())
	cs.fill(colour)
	b.cols.append_array(cs)
	var ix := PackedInt32Array()
	ix.resize(tris.size())
	for k in tris.size():
		ix[k] = first + k
	b.idx.append_array(ix)
	var clear := Color(colour, 0.0)
	for li in p.loops.size():
		var pts: PackedVector2Array = xf * (p.loops[li] as PackedVector2Array)
		var rim: PackedVector2Array = p.rims[li]
		var n := pts.size()
		var base := b.verts.size()
		var vs := PackedVector2Array()
		vs.resize(n * 2)
		var cc := PackedColorArray()
		cc.resize(n * 2)
		for i in n:
			vs[i] = pts[i]
			vs[n + i] = pts[i] + rim[i] * Face.FEATHER
			cc[i] = colour
			cc[n + i] = clear
		b.verts.append_array(vs)
		b.cols.append_array(cc)
		var fx := PackedInt32Array()
		fx.resize(n * 6)
		for i in n:
			var j := (i + 1) % n
			var w := i * 6
			fx[w] = base + i
			fx[w + 1] = base + j
			fx[w + 2] = base + n + j
			fx[w + 3] = base + i
			fx[w + 4] = base + n + j
			fx[w + 5] = base + n + i
		b.idx.append_array(fx)

## Every loop of the shape as a line of `width`.
static func outline(b: Face.Builder, id: String, xf: Transform2D, width: float, colour: Color) -> void:
	for loop: PackedVector2Array in prep(id).loops:
		b.stroke(xf * loop, width, colour, true)

## A measure's bracket from `a` to `b`: a line with a short foot at each end,
## standing off to `side` (a unit vector across it).
static func bracket(b: Face.Builder, a: Vector2, z: Vector2, side: Vector2, colour: Color, width := 4.0, foot := 12.0) -> void:
	b.stroke(PackedVector2Array([a, z]), width, colour)
	b.stroke(PackedVector2Array([a - side * foot, a + side * foot]), width, colour)
	b.stroke(PackedVector2Array([z - side * foot, z + side * foot]), width, colour)

## The grip on the corner the finger sizes by: a disc with a two-headed
## arrow along `dir`.
static func grip(b: Face.Builder, at: Vector2, r: float, dir: Vector2, face: Color, ink: Color) -> void:
	b.disc(at, r + 3.0, ink)
	b.disc(at, r, face)
	var d := dir.normalized()
	var side := Vector2(-d.y, d.x)
	var reach := r * 0.52
	b.stroke(PackedVector2Array([at - d * reach, at + d * reach]), r * 0.16, ink)
	for s: float in [-1.0, 1.0]:
		var tip: Vector2 = at + d * reach * s
		b.stroke(PackedVector2Array([tip - d * s * r * 0.3 + side * r * 0.26, tip,
			tip - d * s * r * 0.3 - side * r * 0.26]), r * 0.16, ink)

## A heart about `at`, `r` across its half width.
static func heart(b: Face.Builder, at: Vector2, r: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	var lobe := r * 0.52
	var left := Face.Builder.arc_points(at + Vector2(-lobe, -r * 0.2), lobe, PI * 0.82, PI * 2.0)
	pts.append_array(left.slice(0, left.size() - 1))
	pts.append_array(Face.Builder.arc_points(at + Vector2(lobe, -r * 0.2), lobe, PI, PI * 2.18))
	pts.append(at + Vector2(0.0, r * 0.95))
	b.polygon(pts, colour)
