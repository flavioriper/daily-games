extends RefCounted

## Tally's drawings (arcade/tally_board.gd lays them). A sheet of squared
## paper on a wooden desk; walnut belts with brass chevrons; cream wooden
## tokens; painted wooden blocks for the machines, each with its sign carved
## in cream, its A and B sides notches cut in with cream chevrons pointing
## in (one, two), its way out a dark spout with a brass chevron pointing
## away; the counting box a teal chest with a cream panel. Everything is built once at
## U units to a square, about the square's middle facing east, and laid by
## the board's transform: nothing is keyed by a size that changes.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/tally_sim.gd")
const Icons = preload("res://ui/icons.gd")

const U := 100.0

const DESK := Color("b98a5e")
const DESK_LOW := Color("a3764c")
const PAPER := Color("f7f0e1")
const PAPER_SHADE := Color(0.29, 0.21, 0.15, 0.22)
const GRID := Color("e6dbc3")
const GRID_FIVE := Color("dccdb0")
const MARGIN_LINE := Color("eab7a8")
const INK := Color("4a3626")
const PENCIL := Color("7f93ab")
const PENCIL_SHUT := Color("c7bca8")
const WALNUT := Color("5e3d27")
const WALNUT_EDGE := Color("452c1c")
const WALNUT_HI := Color("74503a")
const BRASS := Color("e3b65c")
const TOKEN := Color("fbf3e2")
const TOKEN_RIM := Color("d8c29a")
const TOKEN_SHADE := Color(0.29, 0.21, 0.15, 0.28)
const TARGET := Color("f2b53a")
const CREAM := Color("fffaf0")
const SHADE := Color(0.29, 0.21, 0.15, 0.25)
const GHOST := Color("7fbf86")
const WARN := Color("e98a6a")
const AMBER := Color("f2a13a")

## The painted woods, by kind.
const PAINT := {
	Sim.ADD: Color("8fbf7a"), Sim.MUL: Color("7fa7d6"), Sim.SUB: Color("b48cc4"),
	Sim.DIV: Color("e0956a"), Sim.POW: Color("d6b25c"), Sim.DIG: Color("c46a5a"),
	Sim.CRATE: Color("6fb3a8"), Sim.BOX: Color("4f9fa0"), Sim.BELT: WALNUT, Sim.BRIDGE: Color("c99a6c"),
	Sim.SPLIT: BRASS, Sim.JOIN: BRASS,
}

static var _cache := {}

static func _keep(key, b: Face.Builder) -> ArrayMesh:
	var m := b.mesh()
	_cache[key] = m
	return m

## A square's middle, in mesh units, for square `t`.
static func mid(t: Vector2i) -> Vector2:
	return (Vector2(t) + Vector2(0.5, 0.5)) * U

static func dir_v(d: int) -> Vector2:
	return Vector2(Sim.DIRS[d])

# --- the desk and the paper ---

## The desk round the paper (a margin of `rim` squares) and the paper with
## its squares ruled, a firmer line every five, a red margin down the left.
static func paper(w: int, h: int, rim: float) -> ArrayMesh:
	var key := ["paper", w, h, rim]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := Rect2(Vector2(-rim, -rim) * U, Vector2(w + rim * 2.0, h + rim * 2.0) * U)
	b.polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), DESK)
	# the grain: long soft streaks
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for k in 46:
		var y := lerpf(r.position.y, r.end.y, rng.randf())
		var x0 := lerpf(r.position.x, r.end.x, rng.randf() * 0.7)
		var run_len := r.size.x * rng.randf_range(0.15, 0.45)
		b.stroke(PackedVector2Array([Vector2(x0, y), Vector2(x0 + run_len * 0.5, y + rng.randf_range(-12, 12)), Vector2(x0 + run_len, y)]), rng.randf_range(6.0, 18.0), Color(DESK_LOW, 0.35))
	var sheet := Rect2(Vector2.ZERO, Vector2(w, h) * U)
	b.polygon(Face.Builder.round_rect(sheet.position + Vector2(10, 22), sheet.size, 18.0), PAPER_SHADE)
	b.polygon(Face.Builder.round_rect(sheet.position, sheet.size, 14.0), PAPER)
	for x in range(1, w):
		var c := GRID_FIVE if x % 5 == 0 else GRID
		b.polygon(_bar(Vector2(x * U, 4.0), Vector2(x * U, h * U - 4.0), 3.0 if x % 5 == 0 else 2.0), c)
	for y in range(1, h):
		var c := GRID_FIVE if y % 5 == 0 else GRID
		b.polygon(_bar(Vector2(4.0, y * U), Vector2(w * U - 4.0, y * U), 3.0 if y % 5 == 0 else 2.0), c)
	b.polygon(_bar(Vector2(1.4 * U, 6.0), Vector2(1.4 * U, h * U - 6.0), 4.0), MARGIN_LINE)
	return _keep(key, b)

## A plain bar from `a` to `b`, `w` wide, unfeathered.
static func _bar(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var n := (b - a).normalized().orthogonal() * w * 0.5
	return PackedVector2Array([a + n, b + n, b - n, a - n])

## A printed number's pencil ring about the square's middle.
static func print_ring(b: Face.Builder, at: Vector2, open: bool) -> void:
	var c := PENCIL if open else PENCIL_SHUT
	b.stroke(Face.Builder.ring(at, U * 0.36, U * 0.36), 5.0, Color(c, 0.85), true)
	if open:
		b.disc(at, U * 0.33, Color(c, 0.08))

# --- belts ---

## The path a token takes over a square, entry edge to exit edge through the
## middle in two straight legs (a corner is square, as the bed is): `a` the
## way it is going as it comes in, `x` as it leaves.
static func path(at: Vector2, a: int, x: int, p: float) -> Vector2:
	var e := at - dir_v(a) * U * 0.5
	var o := at + dir_v(x) * U * 0.5
	if p < 0.5:
		return e.lerp(at, p * 2.0)
	return at.lerp(o, p * 2.0 - 1.0)

static func path_tan(a: int, x: int, p: float) -> Vector2:
	return dir_v(a) if p < 0.5 else dir_v(x)

## A bar from `a` to `b`, `w` wide, run on `ext` past each end: square ends.
static func _leg(a: Vector2, b: Vector2, w: float, ext: float) -> PackedVector2Array:
	var v := (b - a).normalized()
	var n := v.orthogonal() * w * 0.5
	var a2 := a - v * ext
	var b2 := b + v * ext
	return PackedVector2Array([a2 + n, b2 + n, b2 - n, a2 - n])

## The belts' widths: the dark edge and the walnut inside.
const BED_W := U * 0.72
const BED_IN := U * 0.58

## One belt square's bed into `b`: a straight walnut strip with darker edges
## from the edge it is entered by to the one it is left by, a corner square
## (two legs meeting in the middle, no curve).
static func bed_into(b: Face.Builder, at: Vector2, a: int, x: int) -> void:
	var e := at - dir_v(a) * U * 0.5
	var o := at + dir_v(x) * U * 0.5
	for pass_w: Array in [[BED_W, WALNUT_EDGE], [BED_IN, WALNUT]]:
		var w: float = pass_w[0]
		if a == x:
			b.polygon(_leg(e, o, w, 0.0), pass_w[1])
		else:
			b.polygon(_leg(e, at, w, w * 0.5), pass_w[1])
			b.polygon(_leg(at, o, w, 0.0), pass_w[1])

## A belt square's bed about the origin, built once a shape.
static func bed(a: int, x: int) -> ArrayMesh:
	var key := ["bed", a, x]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.feather = 2.4
	bed_into(b, Vector2.ZERO, a, x)
	return _keep(key, b)


## A brass chevron about the origin pointing east, built once.
static func chevron() -> ArrayMesh:
	if _cache.has("chev"):
		return _cache["chev"]
	var b := Face.Builder.new()
	var s := U * 0.11
	b.stroke(PackedVector2Array([Vector2(-s, -s * 1.3), Vector2(s * 0.6, 0), Vector2(-s, s * 1.3)]), U * 0.06, Color(BRASS, 0.9))
	return _keep("chev", b)

## A bridge's deck: the across lane lifted on a light plank over the other.
static func deck(across: int) -> ArrayMesh:
	var key := ["deck", across % 2]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var horiz := across % 2 == 0
	var long := Vector2(U * 0.5, 0) if horiz else Vector2(0, U * 0.5)
	var wide := Vector2(0, U * 0.36) if horiz else Vector2(U * 0.36, 0)
	b.polygon(PackedVector2Array([-long - wide + Vector2(0, 10), long - wide + Vector2(0, 10), long + wide + Vector2(0, 10), -long + wide + Vector2(0, 10)]), SHADE)
	b.polygon(PackedVector2Array([-long - wide, long - wide, long + wide, -long + wide]), Color("c99a6c"))
	b.polygon(PackedVector2Array([-long - wide * 0.78, long - wide * 0.78, long + wide * 0.78, -long + wide * 0.78]), WALNUT)
	for side in [-1.0, 1.0]:
		b.polygon(_bar(-long + wide * side * 0.9, long + wide * side * 0.9, 6.0), Color("a87b50"))
	return _keep(key, b)

# --- tokens ---

## A token: a cream wooden disc with a rim and its shadow, about the origin;
## `ring` a target's sun ring. `lod` 0 is seen close, 1 at the usual zoom, 2
## far out (one disc and its rim, few sides: hundreds are laid a frame).
static func token(ring: bool, lod := 0) -> ArrayMesh:
	var key := ["token", ring, lod]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.detail = [1.0, 0.45, 0.16][lod]
	b.feather = [1.3, 2.4, 6.0][lod]
	var r := U * 0.31
	if lod < 2:
		b.disc(Vector2(0, U * 0.05), r, TOKEN_SHADE)
	b.disc(Vector2.ZERO, r, TOKEN_RIM)
	b.disc(Vector2(0, -U * 0.02), r * 0.86, TOKEN)
	if ring:
		b.stroke(Face.Builder.ring(Vector2(0, -U * 0.02), r * 0.98, r * 0.98, b.detail), U * 0.07, TARGET, true)
	return _keep(key, b)

const TOKEN_R := 0.31

# --- pieces ---

## A painted block of `col` about the origin, a square `s` units across,
## with a lip under it and a light top edge.
static func block_into(b: Face.Builder, s: float, col: Color, at := Vector2.ZERO) -> void:
	var h := s * 0.5
	b.polygon(Face.Builder.round_rect(at + Vector2(-h, -h + 12.0), Vector2(s, s), 16.0), SHADE)
	b.polygon(Face.Builder.round_rect(at + Vector2(-h, -h + 6.0), Vector2(s, s), 16.0), col.darkened(0.22))
	b.polygon(Face.Builder.round_rect(at + Vector2(-h, -h), Vector2(s, s), 16.0), col)
	b.polygon(Face.Builder.round_rect(at + Vector2(-h + 8.0, -h + 6.0), Vector2(s - 16.0, s * 0.22), 10.0), Color(1, 1, 1, 0.16))

## An operator's squares: how far in from a square's edge its block stands,
## how deep an input's notch is cut, the reach of a spout.
const CELL_IN := U * 0.04
const NOTCH_D := U * 0.2
const MOUTH_W := U * 0.04

## The notch cut into an input square from its back edge: `c` the square's
## middle, `v` the way the machine faces (the way a token goes in).
static func notch_poly(c: Vector2, v: Vector2, grow := 0.0) -> PackedVector2Array:
	var n := v.orthogonal()
	var lip := c - v * (U * 0.5 + 2.0)
	var deep := c - v * (U * 0.5 - CELL_IN - NOTCH_D + grow)
	var we := U * 0.17 + grow
	var wi := U * 0.1 + grow
	return PackedVector2Array([lip - n * we, lip + n * we, deep + n * wi, deep - n * wi])

## Where an input's notch is, for a pulse ring: its middle.
static func notch_mid(c: Vector2, v: Vector2) -> Vector2:
	return c - v * (U * 0.5 - (CELL_IN + NOTCH_D) * 0.5)

## A notch's chevrons pointing in, along `v`: one on A's, two on B's.
static func notch_chevrons(c: Vector2, v: Vector2, many: int) -> Array:
	var n := v.orthogonal()
	var m := notch_mid(c, v)
	var w := U * 0.07
	var d := U * 0.03
	var at: Array = [m] if many == 1 else [m - v * U * 0.04, m + v * U * 0.04]
	var out := []
	for p: Vector2 in at:
		out.append(PackedVector2Array([p - v * d - n * w, p + v * d, p - v * d + n * w]))
	return out

## A machine's squares as [middle, role] about its root's middle, facing `f`.
static func cells(k: int, f: int) -> Array:
	var out := []
	for c: Array in Sim.footprint(k, Vector2i.ZERO, f):
		out.append([Vector2(c[0] as Vector2i) * U, int(c[1])])
	return out

## An operator facing `f` about its root square's middle, drawn as it lies
## (the letters and the sign stay upright, so a mesh a facing): one painted
## block over all its squares, the answer squares light, A and B a shade
## down; A and B each a notch cut into its back edge with cream chevrons
## pointing in (one, two) and its letter; the answer a dark spout out of its
## front edge with a brass chevron pointing away and the sign; the
## divider's remainder a smaller spout and an R.
static func machine(k: int, f := 0) -> ArrayMesh:
	var key := ["machine", k, f]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var col: Color = PAINT[k]
	var v := dir_v(f)
	var cs := cells(k, f)
	var h := U * 0.5 - CELL_IN
	# spouts first: they come out from under the block
	for c: Array in cs:
		if int(c[1]) == Sim.R_OUT or int(c[1]) == Sim.R_REM:
			_spout_at(b, c[0], v, 1.0 if int(c[1]) == Sim.R_OUT else 0.8)
	for layer in 3:
		for c: Array in cs:
			var at: Vector2 = c[0]
			var fill := col if int(c[1]) == Sim.R_OUT or int(c[1]) == Sim.R_REM else col.darkened(0.14)
			var r := Rect2(at - Vector2(h, h), Vector2(h, h) * 2.0)
			# a square reaches over to a neighbour of the same machine: one block
			for o: Array in cs:
				var d: Vector2 = (o[0] as Vector2) - at
				if d.length() < U * 1.01 and d.length() > 1.0:
					r = r.expand(at + d * 0.5 + d.orthogonal().normalized() * h).expand(at + d * 0.5 - d.orthogonal().normalized() * h)
			match layer:
				0:
					b.polygon(_rect(r, Vector2(0, 12.0)), SHADE)
				1:
					b.polygon(_rect(r, Vector2(0, 6.0)), col.darkened(0.3))
				2:
					b.polygon(_rect(r, Vector2.ZERO), fill)
	# one sign for the answer, over all its squares (the adder's two)
	var mid := Vector2.ZERO
	var outs := 0
	for c: Array in cs:
		if int(c[1]) == Sim.R_OUT:
			mid += c[0]
			outs += 1
	sign_into(b, k, mid / maxf(1.0, outs), U * (0.19 if outs > 1 else 0.15), CREAM)
	for c: Array in cs:
		var at: Vector2 = c[0]
		match int(c[1]):
			Sim.R_A, Sim.R_B:
				var many := 1 if int(c[1]) == Sim.R_A else 2
				b.polygon(notch_poly(at, v), WALNUT_EDGE)
				for ch: PackedVector2Array in notch_chevrons(at, v, many):
					b.stroke(ch, MOUTH_W, TOKEN)
				letter_into(b, "A" if many == 1 else "B", at + v * U * 0.08, U * 0.15, CREAM)
			Sim.R_REM:
				letter_into(b, "R", at, U * 0.13, CREAM)
	return _keep(key, b)

static func _rect(r: Rect2, off: Vector2) -> PackedVector2Array:
	return PackedVector2Array([r.position + off, Vector2(r.end.x, r.position.y) + off, r.end + off, Vector2(r.position.x, r.end.y) + off])

## A letter in strokes about `at`, `r` its half height, upright.
static func letter_into(b: Face.Builder, ch: String, at: Vector2, r: float, c: Color) -> void:
	var w := r * 0.3
	var q := r * 0.62
	match ch:
		"A":
			b.stroke(PackedVector2Array([at + Vector2(-q, r), at + Vector2(0, -r), at + Vector2(q, r)]), w, c)
			b.stroke(PackedVector2Array([at + Vector2(-q * 0.5, r * 0.3), at + Vector2(q * 0.5, r * 0.3)]), w, c)
		"B", "R":
			var x0 := at.x - q * 0.75
			b.stroke(PackedVector2Array([Vector2(x0, at.y - r), Vector2(x0, at.y + r)]), w, c)
			var top := PackedVector2Array([Vector2(x0, at.y - r)])
			top.append_array(Face.Builder.arc_points(Vector2(at.x + q * 0.05, at.y - r * 0.5), r * 0.5, -PI * 0.5, PI * 0.5))
			top.append(Vector2(x0, at.y))
			b.stroke(top, w, c)
			if ch == "B":
				var low := PackedVector2Array([Vector2(x0, at.y)])
				low.append_array(Face.Builder.arc_points(Vector2(at.x + q * 0.15, at.y + r * 0.5), r * 0.5, -PI * 0.5, PI * 0.5))
				low.append(Vector2(x0, at.y + r))
				b.stroke(low, w, c)
			else:
				b.stroke(PackedVector2Array([at + Vector2(-q * 0.1, 0), at + Vector2(q * 0.75, r)]), w, c)

## A way out from the square at `at` going `v`: a dark spout from under the
## block to the square's edge, a brass chevron pointing away. `s` its size.
static func _spout_at(b: Face.Builder, at: Vector2, v: Vector2, s: float) -> void:
	var n := v.orthogonal()
	var base := at + v * (U * 0.5 - CELL_IN - U * 0.12)
	var tip := at + v * U * 0.5
	var wb := U * 0.2 * s
	var wt := U * 0.15 * s
	b.polygon(PackedVector2Array([base + n * (wb + 6.0) + Vector2(0, 8.0), tip + n * (wt + 6.0) + Vector2(0, 8.0), tip - n * (wt + 6.0) + Vector2(0, 8.0), base - n * (wb + 6.0) + Vector2(0, 8.0)]), SHADE)
	b.polygon(PackedVector2Array([base + n * wb, tip + n * wt, tip - n * wt, base - n * wb]), WALNUT_EDGE)
	var c := at + v * (U * 0.5 - CELL_IN * 0.5)
	var w := U * 0.085 * s
	var q := U * 0.04 * s
	b.stroke(PackedVector2Array([c - v * q + n * w, c + v * q, c - v * q - n * w]), U * 0.05 * s, BRASS)

## A splitter's or a combiner's plate over its belt square, facing `f`: a
## brass square with three chevrons, pointing out to the front and both
## sides (a splitter) or in from the back and both sides (a combiner).
static func junction(k: int, f: int) -> ArrayMesh:
	var key := ["junction", k, f]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var h := U * 0.25
	b.polygon(_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Vector2(0, 6.0)), SHADE)
	b.polygon(_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Vector2.ZERO), BRASS)
	b.polygon(_rect(Rect2(-h + 5.0, -h + 5.0, h * 2.0 - 10.0, h * 2.0 - 10.0), Vector2.ZERO), BRASS.lightened(0.18))
	var ways := [f, Sim.left_of(f), Sim.right_of(f)] if k == Sim.SPLIT else [f, Sim.left_of(f), Sim.right_of(f)]
	for d: int in ways:
		var v := dir_v(d)
		var n := v.orthogonal()
		# a splitter's point away from the middle; a combiner's toward the front
		var pv := v if k == Sim.SPLIT else dir_v(f)
		var at := v * U * 0.13 if k == Sim.SPLIT else -v * U * 0.13 + (dir_v(f) * U * 0.26 if d == f else Vector2.ZERO)
		if k == Sim.JOIN and d != f:
			pv = -v
		var pn := pv.orthogonal()
		b.stroke(PackedVector2Array([at - pv * U * 0.04 + pn * U * 0.06, at + pv * U * 0.04, at - pv * U * 0.04 - pn * U * 0.06]), U * 0.045, WALNUT_EDGE)
	return _keep(key, b)

## An operator's sign about `at`, `r` its half size.
static func sign_into(b: Face.Builder, k: int, at: Vector2, r: float, c: Color) -> void:
	var w := r * 0.36
	match k:
		Sim.ADD:
			b.stroke(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(r, 0)]), w, c)
			b.stroke(PackedVector2Array([at + Vector2(0, -r), at + Vector2(0, r)]), w, c)
		Sim.MUL:
			var q := r * 0.78
			b.stroke(PackedVector2Array([at + Vector2(-q, -q), at + Vector2(q, q)]), w, c)
			b.stroke(PackedVector2Array([at + Vector2(-q, q), at + Vector2(q, -q)]), w, c)
		Sim.SUB:
			b.stroke(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(r, 0)]), w, c)
		Sim.DIV:
			b.stroke(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(r, 0)]), w, c)
			b.disc(at + Vector2(0, -r * 0.72), w * 0.62, c)
			b.disc(at + Vector2(0, r * 0.72), w * 0.62, c)
		Sim.POW:
			b.stroke(PackedVector2Array([at + Vector2(-r * 0.85, r * 0.5), at + Vector2(0, -r * 0.65), at + Vector2(r * 0.85, r * 0.5)]), w, c)

## A dig: a squat brick block with a dark mouth, the number it digs written
## over it by the board.
static func dig() -> ArrayMesh:
	if _cache.has("dig"):
		return _cache["dig"]
	var b := Face.Builder.new()
	var col: Color = PAINT[Sim.DIG]
	block_into(b, U * 0.86, col)
	b.disc(Vector2(0, 0), U * 0.27, col.darkened(0.35))
	b.disc(Vector2(0, -2), U * 0.23, Color("fbe9d0"))
	return _keep("dig", b)

## A crate: a teal box with slats; its number and count written by the board.
static func crate() -> ArrayMesh:
	if _cache.has("crate"):
		return _cache["crate"]
	var b := Face.Builder.new()
	var col: Color = PAINT[Sim.CRATE]
	block_into(b, U * 0.86, col)
	for y in [-0.24, 0.24]:
		b.polygon(_bar(Vector2(-U * 0.36, U * y), Vector2(U * 0.36, U * y), 7.0), col.darkened(0.15))
	b.polygon(Face.Builder.round_rect(Vector2(-U * 0.3, -U * 0.17), Vector2(U * 0.6, U * 0.32), 10.0), Color("fbf3e2"))
	return _keep("crate", b)

## The counting box over HUB by HUB squares from its top left corner at the
## origin: a teal chest with a wooden rim and a cream panel the board writes
## on, and a slot on each side.
static func box() -> ArrayMesh:
	if _cache.has("box"):
		return _cache["box"]
	var b := Face.Builder.new()
	var s := Sim.HUB * U
	var col: Color = PAINT[Sim.BOX]
	b.polygon(Face.Builder.round_rect(Vector2(10, 26), Vector2(s - 20, s - 20), 30.0), SHADE)
	b.polygon(Face.Builder.round_rect(Vector2(8, 16), Vector2(s - 16, s - 16), 30.0), col.darkened(0.28))
	b.polygon(Face.Builder.round_rect(Vector2(8, 8), Vector2(s - 16, s - 16), 30.0), col)
	b.polygon(Face.Builder.round_rect(Vector2(20, 14), Vector2(s - 40, 30), 14.0), Color(1, 1, 1, 0.18))
	# the slots round the rim, one a square on each side
	for k in Sim.HUB:
		var m := (k + 0.5) * U
		for at: Vector2 in [Vector2(m, 22), Vector2(m, s - 22), Vector2(22, m), Vector2(s - 22, m)]:
			b.disc(at, 10.0, col.darkened(0.35))
	b.polygon(Face.Builder.round_rect(Vector2(52, 52), Vector2(s - 104, s - 104), 22.0), col.darkened(0.18))
	b.polygon(Face.Builder.round_rect(Vector2(56, 52), Vector2(s - 112, s - 110), 20.0), Color("fbf3e2"))
	return _keep("box", b)

## The panel's inside, in box units: where the board writes and the bar runs.
static func box_panel() -> Rect2:
	return Rect2(Vector2(56, 52), Vector2(Sim.HUB * U - 112, Sim.HUB * U - 110))

## A piece seen alone, `s` units across about the origin: for the tray and
## the tutorial.
static func icon(k: int) -> ArrayMesh:
	var key := ["icon", k]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	match k:
		Sim.BELT:
			bed_into(b, Vector2.ZERO, 0, 0)
			var c := chevron()
			b.append(c, Transform2D(0.0, Vector2(-U * 0.18, 0)))
			b.append(c, Transform2D(0.0, Vector2(U * 0.14, 0)))
		Sim.DIG:
			b.append(dig(), Transform2D.IDENTITY)
		Sim.CRATE:
			b.append(crate(), Transform2D.IDENTITY)
		Sim.BRIDGE:
			bed_into(b, Vector2.ZERO, 1, 1)
			b.append(deck(0), Transform2D.IDENTITY)
		Sim.SPLIT, Sim.JOIN:
			bed_into(b, Vector2.ZERO, 0, 0)
			if k == Sim.SPLIT:
				bed_into(b, Vector2.ZERO, 0, 1)
				bed_into(b, Vector2.ZERO, 0, 3)
			else:
				bed_into(b, Vector2.ZERO, 1, 0)
				bed_into(b, Vector2.ZERO, 3, 0)
			b.append(junction(k, 0), Transform2D.IDENTITY)
		_:
			# a machine facing north, drawn to fit one square
			var cs := cells(k, 3)
			var lo := Vector2.INF
			var hi := -Vector2.INF
			for c: Array in cs:
				lo = lo.min(c[0])
				hi = hi.max(c[0])
			var span := maxf(hi.x - lo.x, hi.y - lo.y) / U + 1.0
			b.append(machine(k, 3), Transform2D(0.0, Vector2.ONE / span, 0.0, -(lo + hi) * 0.5 / span))
	return _keep(key, b)

## One of ui/icons.gd's glyphs into `b`, fitted to `rect`: its polygons
## filled and its lines stroked at the icons' own width, so a pill's buttons
## are one mesh and not a draw command a shape.
static func glyph_into(b: Face.Builder, name: String, rect: Rect2, c: Color) -> void:
	var s: Dictionary = Icons.shape(name)
	var xf := Transform2D(0.0, rect.size, 0.0, rect.position)
	for poly: PackedVector2Array in s.polys:
		b.polygon(xf * poly, c)
	for line: PackedVector2Array in s.lines:
		b.stroke(xf * line, Icons.STROKE * rect.size.x, c)

## A small padlock about the origin, `r` its half height.
static func lock_into(b: Face.Builder, at: Vector2, r: float, c: Color) -> void:
	b.stroke(Face.Builder.arc_points(at + Vector2(0, -r * 0.15), r * 0.42, PI, TAU), r * 0.2, c, false)
	b.polygon(Face.Builder.round_rect(at + Vector2(-r * 0.62, -r * 0.15), Vector2(r * 1.24, r * 0.95), r * 0.2), c)

## A hand's eraser: a pink block on a slant, for the Remove tool.
static func eraser_into(b: Face.Builder, at: Vector2, r: float) -> void:
	var xf := Transform2D(-0.6, at)
	var pts := Face.Builder.round_rect(Vector2(-r, -r * 0.45), Vector2(r * 2.0, r * 0.9), r * 0.2)
	var shade := PackedVector2Array()
	for p in pts:
		shade.append(xf * (p + Vector2(0, r * 0.18)))
	b.polygon(shade, SHADE)
	var body := PackedVector2Array()
	for p in pts:
		body.append(xf * p)
	b.polygon(body, Color("f0a3a0"))
	var band := PackedVector2Array()
	for p in Face.Builder.round_rect(Vector2(r * 0.25, -r * 0.45), Vector2(r * 0.75, r * 0.9), r * 0.18):
		band.append(xf * p)
	b.polygon(band, Color("7fa7d6"))

## An open hand for the Move tool: a palm and four soft fingers.
static func hand_into(b: Face.Builder, at: Vector2, r: float, c: Color) -> void:
	b.polygon(Face.Builder.round_rect(at + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.95), r * 0.4), c)
	for k in 4:
		var x := lerpf(-r * 0.42, r * 0.42, k / 3.0)
		var tall := r * (0.62 if k == 0 or k == 3 else 0.78)
		b.stroke(PackedVector2Array([at + Vector2(x, 0), at + Vector2(x, -tall)]), r * 0.26, c)
	b.stroke(PackedVector2Array([at + Vector2(-r * 0.5, r * 0.3), at + Vector2(-r * 0.85, -r * 0.05)]), r * 0.26, c)
