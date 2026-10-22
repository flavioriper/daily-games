extends RefCounted

## Paper Box's pieces (spec docs/superpowers/specs/2026-10-22-paperbox-design.md):
## the six papers, the net's squares at any fold, the box seen from its
## corner, the stamps, a struck box's hatch, the shelf spot and the board's
## shadows. Everything goes into a Face.Builder, so a board bakes what it
## shows into one mesh.
##
## One renderer serves the flat net, the fold and the boxes: `sheet()` takes
## squares already placed in 3D (puzzles/paperbox_fold.gd's frames) and a
## projection, sorts them far to near and paints each square's paint side or
## its kraft back, whichever faces the eye. `box()` paints a picture (three
## faces) on a unit box through the same face painter, so a folded net and
## the box it matches look the same to the pixel.

const Face = preload("res://ui/faces/face.gd")
const Fold = preload("res://puzzles/paperbox_fold.gd")
const Pal = preload("res://core/palette.gd")

## The six papers, by colour index: sun, berry, leaf, sky, plum, petal.
const PAPER := [Color("f2bf4c"), Color("de6a5e"), Color("7db46a"), Color("5199d6"), Color("9a86d2"), Color("f0a6c6")]
## The papers' own lines, deepened.
const LINE := [Color("c7932a"), Color("b44c42"), Color("5a8f4a"), Color("336fae"), Color("7562ab"), Color("cc7aa0")]
## The back of the paper, plain kraft.
const KRAFT := Color("dcc59e")
const KRAFT_LINE := Color("b49a72")
## A stamp: cream ink.
const STAMP := Color("fffaf0")
## A struck box's hatch and cross, in pencil.
const PENCIL := Color("6b5a4a")
const CROSS := Color("d0574f")
const SHADOW := Color(0.36, 0.27, 0.2, 0.18)
## The light, from over the left shoulder, for the faces' form shading.
const LIGHT := Vector3(0.18, 0.42, 1.0)

## How a face of normal `n` (in the eye's world) is lit: 0.86 at its
## darkest to 1.05 where the light falls full on it.
static func lit(n: Vector3) -> float:
	return lerpf(0.86, 1.05, clampf(n.normalized().dot(LIGHT.normalized()), 0.0, 1.0))

static func _shade(c: Color, k: float) -> Color:
	if k >= 1.0:
		return c.lerp(Color.WHITE, (k - 1.0) * 2.0)
	return c.darkened((1.0 - k) * 1.1)

## One paper face: its outline `pts` (projected), filled and edged.
static func face(b: Face.Builder, pts: PackedVector2Array, fill: Color, line: Color, width: float) -> void:
	b.polygon(pts, fill)
	b.stroke(pts, width, line, true)

## A stamp: a cream arrow on a face, pointing along `way` from `centre`
## (3D), `across` the face's other way, through `proj`.
static func stamp(b: Face.Builder, proj: Callable, centre: Vector3, way: Vector3, across: Vector3, alpha := 1.0) -> void:
	var p := func(u: float, v: float) -> Vector2: return proj.call(centre + way * u + across * v)
	var pts := PackedVector2Array([p.call(0.33, 0.0), p.call(0.04, 0.25), p.call(0.04, 0.1), p.call(-0.3, 0.1),
		p.call(-0.3, -0.1), p.call(0.04, -0.1), p.call(0.04, -0.25)])
	b.polygon(pts, Color(STAMP, 0.95 * alpha))

## Squares placed in 3D: `frames` (per square), their colours and stamp
## ways, painted through `proj` (Vector3 -> Vector2) for an eye looking
## along `eye` (toward the viewer). `width` is the paper's edge in pixels.
static func sheet(b: Face.Builder, frames: Array, colours: Array, ways: Array, proj: Callable, eye: Vector3, width: float) -> void:
	var order: Array[int] = []
	var depth: Array[float] = []
	for i in frames.size():
		order.append(i)
		depth.append(((frames[i] as Transform3D) * Vector3(0.5, 0.5, 0.0)).dot(eye))
	order.sort_custom(func(a: int, c: int) -> bool: return depth[a] < depth[c])
	for i in order:
		var f: Transform3D = frames[i]
		var pts := PackedVector2Array()
		for corner in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]:
			pts.append(proj.call(f * corner))
		var n := f.basis * Vector3(0, 0, 1)
		var front := n.dot(eye) >= 0.0
		var k := lit(n if front else -n)
		var c: int = int(colours[i])
		if front:
			face(b, pts, _shade(PAPER[c], k), LINE[c], width)
			var w: int = int(ways[i]) if i < ways.size() else -1
			if w >= 0:
				var way2: Vector2i = Fold.WAYS[w]
				var way := f.basis * Vector3(way2.x, way2.y, 0)
				stamp(b, proj, f * Vector3(0.5, 0.5, 0.0), way, n.cross(way))
		else:
			face(b, pts, _shade(KRAFT, k), KRAFT_LINE, width)

## A box showing `pic` (Fold.picture()), its middle at `at`, `s` pixels a
## side's half diagonal (Fold.project's unit): the top, the right and the
## left faces of a unit box.
static func box(b: Face.Builder, at: Vector2, s: float, pic: Array, width: float) -> void:
	var proj := func(p: Vector3) -> Vector2: return at + Fold.project(p) * s
	for slot in [2, 1, 0]:
		var n := Vector3(Fold.SHOWN[slot] as Vector3i)
		# the face's two ways across, so its corners run round it
		var u := Vector3(0, 1, 0) if slot == 1 else Vector3(1, 0, 0)
		var v := n.cross(u)
		var c := n * 0.5
		var pts := PackedVector2Array()
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			pts.append(proj.call(c + u * (q.x * 0.5) + v * (q.y * 0.5)))
		var col: int = int((pic[slot] as Array)[0])
		face(b, pts, _shade(PAPER[col], lit(n)), LINE[col], width)
		var m: Vector3i = (pic[slot] as Array)[1]
		if m != Vector3i.ZERO:
			var way := Vector3(m)
			stamp(b, proj, c, way, n.cross(way))

## The box's outline (its hexagon), for a hatch or a ring.
static func outline(at: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in [Vector3(0.5, -0.5, 0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5),
			Vector3(-0.5, 0.5, -0.5), Vector3(-0.5, 0.5, 0.5), Vector3(-0.5, -0.5, 0.5)]:
		pts.append(at + Fold.project(p) * s)
	return pts

## A box's soft shadow on the table under it.
static func shadow(b: Face.Builder, at: Vector2, s: float) -> void:
	var foot := at + Vector2(0.0, s * 0.95)
	b.ellipse(foot, s * 1.05, s * 0.32, SHADOW)
	b.ellipse(foot, s * 0.8, s * 0.22, Color(SHADOW, SHADOW.a * 0.8))

## A struck box: pencil hatching across its outline and a cross over it.
static func struck(b: Face.Builder, at: Vector2, s: float) -> void:
	var hex := outline(at, s)
	var step := s * 0.22
	var x := -s * 2.0
	while x < s * 2.0:
		var line := PackedVector2Array([at + Vector2(x - s, -s * 1.2), at + Vector2(x + s, s * 1.2)])
		for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(line, hex):
			if piece.size() >= 2:
				b.stroke(piece, maxf(1.5, s * 0.03), Color(PENCIL, 0.55))
		x += step
	var r := s * 0.42
	var w := maxf(3.0, s * 0.1)
	b.stroke(PackedVector2Array([at + Vector2(-r, -r), at + Vector2(r, r)]), w, CROSS)
	b.stroke(PackedVector2Array([at + Vector2(r, -r), at + Vector2(-r, r)]), w, CROSS)

## An empty shelf spot: a faint dashed box outline.
static func spot(b: Face.Builder, at: Vector2, s: float) -> void:
	var hex := outline(at, s)
	var n := hex.size()
	for i in n:
		var a := hex[i]
		var c := hex[(i + 1) % n]
		for k in 3:
			var t0 := (k * 2.0 + 0.4) / 6.0
			var t1 := (k * 2.0 + 1.4) / 6.0
			b.stroke(PackedVector2Array([a.lerp(c, t0), a.lerp(c, t1)]), maxf(1.5, s * 0.05), Color(KRAFT_LINE, 0.55))
