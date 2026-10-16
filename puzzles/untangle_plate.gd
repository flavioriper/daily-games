extends RefCounted

## Untangle's plate: where the holes are. The ring is one plate of several. A
## hoop is a ring bent into a cushion square, a hexagon or a triangle, its
## holes round its edge; a board is a wooden plate drilled all over, a square
## grid or a honeycomb, so a peg can stand in the middle with ropes on every
## side of it.
##
## Holes are points in the plate's own units (a ring's holes lie on the unit
## circle, y down, hole 0 at the top, then clockwise) and the rule reads them
## through one table: `o`, the turn of every three holes. Two ropes cross when
## each one's pegs lie on either side of the other's line (`crosses`), which on
## a ring is the old rule of holes interleaving round it.
##
## No three holes lie on one line: a hoop's sides bow outward and a board's
## holes are drilled a little off the lattice (`JITTER`, the same on every
## copy of a plate), so the turn of three holes is never nought.
##
## Spec: docs/superpowers/specs/2026-10-16-untangle-plates-design.md.

## A board's holes stand this share of their spacing off the lattice.
const JITTER := 0.075
## A board's wood reaches this many spacings past its outer holes.
const BOARD_MARGIN := 0.62
## A hoop's wood is this wide either side of its holes, in hole-circle units
## (the ring's: (1 - RING_IN) / (1 + RING_IN) of the board's ring).
const HOOP_HALF := 0.1173
## How round a bowed hoop is between its corners (0 straight, 1 a circle).
const BOW := {"square": 0.0, "hex": 0.3, "tri": 0.34}
const EDGE_STEPS := 360

## The plate's id as a day stores it, e.g. "ring:13", "hex:14", "grid:4x5".
var id := ""
## "ring", "hoop" or "board".
var kind := ""
## "ring", "square", "hex", "tri" (hoops), "grid", "honey" (boards).
var shape := ""
var n := 0
var pts := PackedVector2Array()
## True when every hole is on the edge of the plate in order round it: the
## ring and the hoops. A rope's way round such a plate is the old ring rule.
var convex := false
## A ring or hoop: its centre line, closed, dense, in plate units.
var curve := PackedVector2Array()
## A board: its wooden edge, closed, in plate units.
var outline := PackedVector2Array()
## Half the plate's size with its wood, in plate units.
var ext := Vector2.ONE
## The usual distance between neighbouring holes, and the longest between any
## two.
var spacing := 1.0
var maxd := 2.0
## The distance between holes a and b at dd[a * n + b].
var dd := PackedFloat32Array()
## The edge's distance from the middle, a step a degree from +x, clockwise
## on screen (`edge_at`).
var edge := PackedFloat32Array()
## The turn of holes (a, b, c): o[(a * n + b) * n + c] is 1 when c lies to
## the left of a -> b (screen y down: clockwise), else 0.
var o := PackedByteArray()

static var _made := {}

## The plate an id names, made once and shared (it never changes).
static func of(plate_id: String) -> RefCounted:
	if _made.has(plate_id):
		return _made[plate_id]
	var pl = load("res://puzzles/untangle_plate.gd").new()
	pl._build(plate_id)
	_made[plate_id] = pl
	return pl

## A ring of `holes`: today's board, kept for the tutorial and any old day.
static func ring(holes: int) -> RefCounted:
	return of("ring:%d" % holes)

func _build(plate_id: String) -> void:
	id = plate_id
	var parts := plate_id.split(":")
	shape = parts[0]
	var size := parts[1] if parts.size() > 1 else "10"
	match shape:
		"ring":
			kind = "ring"
			convex = true
			n = int(size)
			for h in n:
				pts.append(Vector2.from_angle(TAU * float(h) / n - PI * 0.5))
			curve = _circle(96)
		"square", "hex", "tri":
			kind = "hoop"
			convex = true
			n = int(size)
			curve = _hoop_curve(shape)
			pts = _along(curve, n)
		"grid":
			kind = "board"
			var rc := size.split("x")
			_grid(int(rc[0]), int(rc[1]))
		"honey":
			kind = "board"
			_honey(int(size))
		_:
			push_error("Untangle: no plate %s" % plate_id)
			_build("ring:10")
			return
	if kind == "board":
		_jitter()
	_measure()
	_turns()
	_edges()
	dd.resize(n * n)
	for a in n:
		for b in n:
			dd[a * n + b] = pts[a].distance_to(pts[b])

# --- hoops ---

static func _circle(steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		out.append(Vector2.from_angle(TAU * float(i) / steps - PI * 0.5))
	return out

## A closed hoop of the shape: a polygon's radius blended toward a circle's so
## its sides bow out, and the cushion square a superellipse. Starts at the top
## and runs clockwise, its widest point at 1.
static func _hoop_curve(sh: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps := 360
	for i in steps:
		var th := TAU * float(i) / steps - PI * 0.5
		var p: Vector2
		if sh == "square":
			# A superellipse, |x|^4 + |y|^4 = 1, turned so a side faces up.
			var c := cos(th)
			var s := sin(th)
			p = Vector2(signf(c) * pow(absf(c), 0.5), signf(s) * pow(absf(s), 0.5))
		else:
			var sides := 6 if sh == "hex" else 3
			var seg := TAU / sides
			# A corner at the top for the triangle, a flat top for the hexagon.
			var from_top := th + PI * 0.5 + (0.0 if sides == 3 else seg * 0.5)
			var u := fposmod(from_top, seg) - seg * 0.5
			var r_poly := cos(seg * 0.5) / cos(u)
			p = Vector2.from_angle(th) * lerpf(r_poly, 1.0, float(BOW[sh]))
		out.append(p)
	# The widest point at 1, the middle at the origin.
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in out:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var mid := (lo + hi) * 0.5
	var big := maxf(hi.x - lo.x, hi.y - lo.y) * 0.5
	for i in out.size():
		out[i] = (out[i] - mid) / big
	return out

## `count` points evenly along a closed curve by length, the first at its
## start.
static func _along(c: PackedVector2Array, count: int) -> PackedVector2Array:
	var total := 0.0
	for i in c.size():
		total += c[i].distance_to(c[(i + 1) % c.size()])
	var out := PackedVector2Array()
	var step := total / count
	var walked := 0.0
	var want := 0.0
	for i in c.size():
		var a := c[i]
		var b := c[(i + 1) % c.size()]
		var len := a.distance_to(b)
		while out.size() < count and want <= walked + len:
			out.append(a.lerp(b, (want - walked) / maxf(len, 1e-9)))
			want += step
		walked += len
	return out

# --- boards ---

func _grid(rows: int, cols: int) -> void:
	n = rows * cols
	for r in rows:
		for c in cols:
			pts.append(Vector2(float(c) - (cols - 1) * 0.5, float(r) - (rows - 1) * 0.5))
	var half := Vector2((cols - 1) * 0.5, (rows - 1) * 0.5) + Vector2.ONE * BOARD_MARGIN
	outline = _rounded_rect(half, BOARD_MARGIN * 0.9)
	_fit(half)

## A honeycomb in rows: 19 is the hexagon of side three, 23 a block of five
## rows, five and four holes in turn.
func _honey(count: int) -> void:
	var h := sqrt(3.0) * 0.5
	if count == 19:
		for row in range(-2, 3):
			var in_row := 5 - absi(row)
			for i in in_row:
				pts.append(Vector2(float(i) - (in_row - 1) * 0.5, row * h))
		var corner := 2.0 + BOARD_MARGIN * 1.12
		var hexa := PackedVector2Array()
		for k in 6:
			hexa.append(Vector2.from_angle(PI / 3.0 * k) * corner)
		outline = _round_poly(hexa, BOARD_MARGIN * 0.9)
		_fit(Vector2(corner, corner * h))
	else:
		var rows := 5
		for row in rows:
			var in_row := 5 if row % 2 == 0 else 4
			for i in in_row:
				pts.append(Vector2(float(i) - (in_row - 1) * 0.5, (row - (rows - 1) * 0.5) * h))
		var half := Vector2(2.0, (rows - 1) * 0.5 * h) + Vector2.ONE * BOARD_MARGIN
		outline = _rounded_rect(half, BOARD_MARGIN * 0.9)
		_fit(half)
	n = pts.size()

## Scales a board's holes and edge so its wood's larger half is 1.
func _fit(half: Vector2) -> void:
	var k := 1.0 / maxf(half.x, half.y)
	for i in pts.size():
		pts[i] *= k
	for i in outline.size():
		outline[i] *= k

static func _rounded_rect(half: Vector2, r: float) -> PackedVector2Array:
	var corners := PackedVector2Array([Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y)])
	return _round_poly(corners, r)

## A convex polygon, clockwise on screen, with each corner rounded by `r`.
static func _round_poly(corners: PackedVector2Array, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := corners.size()
	for i in m:
		var prev := corners[(i - 1 + m) % m]
		var here := corners[i]
		var next := corners[(i + 1) % m]
		var a := (prev - here).normalized()
		var b := (next - here).normalized()
		var half := a.angle_to(b) * 0.5
		var cut := r / tan(absf(half))
		var p0 := here + a * cut
		var p1 := here + b * cut
		# The arc from p0 to p1 about the point r in from the corner.
		var centre := here + (a + b).normalized() * (r / sin(absf(half)))
		var a0 := (p0 - centre).angle()
		var sweep := wrapf((p1 - centre).angle() - a0, -PI, PI)
		for s in 7:
			out.append(centre + Vector2.from_angle(a0 + sweep * s / 6.0) * r)
	return out

## Each hole a little off the lattice, the same way on every copy: a hash of
## its index, so no three holes stand in a row.
func _jitter() -> void:
	var near := INF
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			near = minf(near, pts[i].distance_to(pts[j]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) & 0x7fffffff
	for i in pts.size():
		pts[i] += Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * near * JITTER

func _measure() -> void:
	var near_sum := 0.0
	maxd = 0.0
	for i in n:
		var near := INF
		for j in n:
			if i == j:
				continue
			var d := pts[i].distance_to(pts[j])
			near = minf(near, d)
			maxd = maxf(maxd, d)
		near_sum += near
	spacing = near_sum / maxf(n, 1)
	if kind == "board":
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in outline:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		ext = Vector2(maxf(-lo.x, hi.x), maxf(-lo.y, hi.y))
	else:
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in curve:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		ext = Vector2(maxf(-lo.x, hi.x), maxf(-lo.y, hi.y)) + Vector2.ONE * HOOP_HALF

func _turns() -> void:
	o = PackedByteArray()
	o.resize(n * n * n)
	for a in n:
		for b in n:
			var ab := pts[b] - pts[a]
			for c in n:
				o[(a * n + b) * n + c] = 1 if ab.cross(pts[c] - pts[a]) > 0.0 else 0

# --- what the rule reads ---

## True when the rope from hole a to hole b and the rope from c to d cross.
## The four holes are distinct. Also: a peg carried from `a` straight to `b`
## passes over the rope from `c` to `d`.
func crosses(a: int, b: int, c: int, d: int) -> bool:
	var ab := (a * n + b) * n
	if o[ab + c] == o[ab + d]:
		return false
	var cd := (c * n + d) * n
	return o[cd + a] != o[cd + b]

func dist(a: int, b: int) -> float:
	return dd[a * n + b]

## The same test for a point in the air (a peg in the hand, in plate units)
## against holes.
static func seg_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	return (ab.cross(c - a) > 0.0) != (ab.cross(d - a) > 0.0) and (cd.cross(a - c) > 0.0) != (cd.cross(b - c) > 0.0)

## How far the plate's edge is from its middle toward `angle` (radians): the
## ring's and a hoop's centre line, a board's wooden edge.
func edge_at(angle: float) -> float:
	var u := fposmod(angle, TAU) / TAU * EDGE_STEPS
	var i := int(u) % EDGE_STEPS
	return lerpf(edge[i], edge[(i + 1) % EDGE_STEPS], u - floorf(u))

## True when `p` lies at least `inset` in from the edge (plate units, read
## along the way out from the middle: a hair generous at a board's corners).
func holds(p: Vector2, inset: float) -> bool:
	return p.length() <= edge_at(p.angle()) - inset

## `p` pulled straight toward the plate's middle until it lies `inset` in
## from the edge; a negative `inset` lets it out past the edge that far.
func keep_in(p: Vector2, inset: float) -> Vector2:
	return p.limit_length(maxf(edge_at(p.angle()) - inset, 0.0))

func _edges() -> void:
	edge = PackedFloat32Array()
	edge.resize(EDGE_STEPS)
	var poly := outline if kind == "board" else curve
	for i in EDGE_STEPS:
		var dir := Vector2.from_angle(TAU * float(i) / EDGE_STEPS)
		if kind == "ring":
			edge[i] = 1.0
			continue
		var far := 0.0
		for j in poly.size():
			var hit = Geometry2D.segment_intersects_segment(Vector2.ZERO, dir * 4.0, poly[j], poly[(j + 1) % poly.size()])
			if hit != null:
				far = maxf(far, (hit as Vector2).length())
		edge[i] = far
