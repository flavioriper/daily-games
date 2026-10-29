extends Control

## Knight's world: a castle's courtyard, edge to edge under the board and the
## host's rows (CLAUDE.md: a game's world fills the screen). It is the menu
## card's oat linen (ui/menu/cards/knight.gd) turned to pale paving: light at
## the top behind the wordmark, faint flagstones under the board, a
## horseshoe, a few hoofprints and a small crown in the gap of the tools
## row, and at the foot the court's wall with its battlements, two turrets
## under rose roofs with their pennants, the gate, and rose bushes along it
## (the rose king's own). Nothing in it has a face: only the pieces do.
##
## The foot is measured up from the bottom edge, so a taller screen keeps the
## wall under the board. One mesh, built when the rect changes and kept
## (`_shown`) until the next replaces it; five petals on the air are a
## second, on a child whose alpha breathes (still under Motion.reduce).
##
## The colours are written here: the board preloads this file, so it cannot
## preload the board.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Piece = preload("res://ui/faces/chess_piece.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const COURT_TOP := Color("f8f1e3")
const COURT_LOW := Color("ecdcc2")
const LIGHT := Color("fffaf0")
const JOINT := Color("a48a66")
const STONE := Color("e2d3b8")
const STONE_LIT := Color("efe3cc")
const STONE_DEEP := Color("c8b594")
const STONE_LINE := Color("a8926f")
const ROOF := Color("d9838b")
const ROOF_DEEP := Color("b95f69")
const DOOR := Color("b58d5e")
const DOOR_DEEP := Color("86653f")
const BUSH := Color("8fb873")
const BUSH_DEEP := Color("6f9c57")
const ROSE := Color("e8959a")
const ROSE_DEEP := Color("c26b93")
const PRINT := Color("8a7358")
const IRON := Color("9a9186")

## The flagstones start under the tools row and stop at the wall.
const PAVE_FROM := 0.275
const PAVE_ROW := 150.0
const PAVE_ALPHA := 0.06
## The wall, measured up from the bottom edge at W: its top, a merlon, and
## the turrets [x share, half width, how far over the wall, flag side].
const WALL_TOP := 232.0
const MERLON := Vector2(46.0, 30.0)
const TURRETS := [[0.115, 78.0, 96.0, 1.0], [0.875, 70.0, 78.0, -1.0]]
const GATE_X := 0.40
const GATE_HALF := 74.0
const GATE_H := 168.0
## Rose bushes along the wall's foot: [x share, radius at W].
const BUSHES := [[0.245, 46.0], [0.60, 52.0], [0.705, 40.0], [0.985, 44.0], [0.015, 38.0]]
## The tools row's gap: a horseshoe, hoofprints stepping right, a crown.
const SHOE_AT := Vector2(0.385, 0.234)
const PRINTS := [Vector2(0.465, 0.240), Vector2(0.525, 0.228), Vector2(0.585, 0.238)]
const CROWN_AT := Vector2(0.665, 0.236)
## Petals on the air: [x share, up from the bottom at W, radius, angle].
const PETALS := [[0.19, 318.0, 9.0, 0.6], [0.52, 300.0, 8.0, 2.1], [0.66, 350.0, 7.0, -0.8],
	[0.80, 322.0, 9.0, 1.4], [0.33, 362.0, 7.0, -1.9]]
const BREATH := 3.6
const BREATH_LOW := 0.4

## Whether the tools row's gap holds its horseshoe, prints and crown: the
## board's count pill stands there since 2026-10-29, and turns them off.
var gap := true
var _shown: ArrayMesh
var _air: Control
var _air_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_air = Control.new()
	_air.name = "Petals"
	_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_air.draw.connect(func() -> void:
		if _air_shown != null:
			_air.draw_mesh(_air_shown, null))
	add_child(_air)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_air, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, COURT_TOP, COURT_LOW, 0.0, size.y)
	# The morning in the wordmark's corner.
	var sun := Vector2(0.10, 0.02) * size
	for ring in [[640.0, 0.30], [420.0, 0.34], [250.0, 0.4]]:
		Scenery.soft_disc(b, sun, ring[0] * u, ring[0] * u, Color(LIGHT, ring[1]))
	var wall_y := size.y - WALL_TOP * u
	_paving(b, u, wall_y)
	if gap:
		_gap(b, u)
	_wall(b, u, wall_y)
	_shown = b.mesh()
	queue_redraw()
	var ab := Face.Builder.new()
	for p in PETALS:
		_petal(ab, Vector2(p[0] * size.x, size.y - p[1] * u), p[2] * u, p[3])
	_air_shown = ab.mesh()
	_air.size = size
	_air.queue_redraw()

## Flagstones: courses across the court, their joints staggered, very faint.
func _paving(b: Face.Builder, u: float, wall_y: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4177
	var ink := Color(JOINT, PAVE_ALPHA)
	var y := size.y * PAVE_FROM
	var row := 0
	while y < wall_y - 20.0 * u:
		b.stroke(PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y)]), 3.0 * u, ink, false, false)
		var x := (0.0 if row % 2 == 0 else 110.0) * u + rng.randf_range(40.0, 120.0) * u
		var foot := minf(y + PAVE_ROW * u, wall_y)
		while x < size.x:
			b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x, foot)]), 3.0 * u, ink, false, false)
			x += rng.randf_range(190.0, 300.0) * u
		y += PAVE_ROW * u
		row += 1

## The gap of the tools row: small, since it stands over the win's words.
func _gap(b: Face.Builder, u: float) -> void:
	_shoe(b, SHOE_AT * size, 22.0 * u, -0.35)
	for i in PRINTS.size():
		_print(b, PRINTS[i] * size, 11.0 * u, 0.25 if i % 2 == 0 else -0.2)
	Piece.crown(b, CROWN_AT * size, 110.0 * u, 0.18, 0.9)

## A horseshoe `r` across, opening down, turned by `ang`, with its nails.
func _shoe(b: Face.Builder, at: Vector2, r: float, ang: float) -> void:
	var pts := PackedVector2Array()
	for p in Face.Builder.arc_points(Vector2.ZERO, r, PI * 0.82, PI * 2.18):
		pts.append(at + (p * Vector2(0.86, 1.0)).rotated(ang))
	b.stroke(pts, r * 0.36, Color(Pal.TEXT, 0.10))
	var lit := PackedVector2Array()
	for p in pts:
		lit.append(p - Vector2(0.0, r * 0.1))
	b.stroke(lit, r * 0.34, IRON)
	for i in [3, pts.size() / 2, pts.size() - 4]:
		b.disc(lit[clampi(i, 0, lit.size() - 1)], r * 0.07, Color(Pal.TEXT, 0.45))

## A hoofprint `r` across: a small open U pressed into the court.
func _print(b: Face.Builder, at: Vector2, r: float, ang: float) -> void:
	var pts := PackedVector2Array()
	for p in Face.Builder.arc_points(Vector2.ZERO, r, PI * 0.9, PI * 2.1):
		pts.append(at + p.rotated(ang))
	b.stroke(pts, r * 0.42, Color(PRINT, 0.32))

## The court's wall along the foot: battlements, courses, the gate, two
## turrets and the rose bushes.
func _wall(b: Face.Builder, u: float, top: float) -> void:
	# its shadow on the court
	Scenery.soft_disc(b, Vector2(size.x * 0.5, top + 6.0 * u), size.x * 0.7, 40.0 * u, Color(Pal.TEXT, 0.07))
	var first := b.verts.size()
	b.polygon(_box(Vector2(-8.0, top), Vector2(size.x + 16.0, size.y - top + 8.0)), Color.WHITE)
	CardFace.shade(b, first, STONE, STONE_DEEP, top, size.y + 80.0 * u)
	# merlons, a gap between each
	var step := MERLON.x * 2.0 * u
	var x := -MERLON.x * 0.5 * u
	while x < size.x:
		b.polygon(_box(Vector2(x, top - MERLON.y * u), MERLON * u), STONE)
		b.polygon(_box(Vector2(x, top - MERLON.y * u), Vector2(MERLON.x, 6.0) * u), STONE_LIT)
		x += step
	b.polygon(_box(Vector2(-8.0, top), Vector2(size.x + 16.0, 7.0 * u)), STONE_LIT)
	# courses of stone
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var ink := Color(STONE_LINE, 0.22)
	var y := top + 58.0 * u
	var row := 0
	while y < size.y:
		b.stroke(PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y)]), 3.0 * u, ink, false, false)
		var jx := (30.0 if row % 2 == 0 else 110.0) * u
		while jx < size.x:
			if rng.randf() < 0.7:
				b.stroke(PackedVector2Array([Vector2(jx, y - 58.0 * u), Vector2(jx, y)]), 3.0 * u, ink, false, false)
			jx += 160.0 * u
		y += 58.0 * u
		row += 1
	_gate(b, u, top)
	for t in TURRETS:
		_turret(b, u, top, t[0] * size.x, t[1] * u, t[2] * u, t[3])
	for bush in BUSHES:
		_bush(b, Vector2(bush[0] * size.x, size.y - bush[1] * u * 0.25), bush[1] * u)

## The gate: an arch of darker stone, two leaves of plank with iron bands.
func _gate(b: Face.Builder, u: float, top: float) -> void:
	var mid := GATE_X * size.x
	var half := GATE_HALF * u
	var foot := size.y + 8.0
	var crown := maxf(top + 34.0 * u, size.y - GATE_H * u)
	var arch := PackedVector2Array([Vector2(mid - half, foot)])
	for p in Face.Builder.arc_points(Vector2(mid, crown + half), half, PI, TAU):
		arch.append(p)
	arch.append(Vector2(mid + half, foot))
	var rim := PackedVector2Array()
	for p in arch:
		rim.append(Vector2(mid + (p.x - mid) * 1.16, p.y - (10.0 * u if p.y < foot else 0.0)))
	b.polygon(rim, STONE_DEEP)
	b.polygon(arch, DOOR)
	for i in 5:
		var px := mid - half + half * 2.0 * float(i + 1) / 6.0
		b.stroke(PackedVector2Array([Vector2(px, crown + half * 0.35), Vector2(px, foot)]), 3.0 * u,
			Color(DOOR_DEEP, 0.5 if i != 2 else 0.9), false, false)
	for band in [0.42, 0.78]:
		var by := lerpf(crown + half, size.y, band)
		b.stroke(PackedVector2Array([Vector2(mid - half + 6.0 * u, by), Vector2(mid + half - 6.0 * u, by)]), 9.0 * u,
			Color(DOOR_DEEP, 0.85), false, false)
	b.disc(Vector2(mid - 14.0 * u, lerpf(crown + half, size.y, 0.6)), 6.0 * u, IRON)
	b.disc(Vector2(mid + 14.0 * u, lerpf(crown + half, size.y, 0.6)), 6.0 * u, IRON)

## A round turret standing `over` the wall at `x`, `half` wide: its drum,
## its own battlements, a slit window, a rose roof and a pennant.
func _turret(b: Face.Builder, u: float, top: float, x: float, half: float, over: float, flag: float) -> void:
	var head := top - over
	var first := b.verts.size()
	b.polygon(_box(Vector2(x - half, head), Vector2(half * 2.0, size.y - head + 8.0)), Color.WHITE)
	CardFace.shade(b, first, STONE_LIT, STONE_DEEP, head, size.y + 120.0 * u)
	b.polygon(_box(Vector2(x + half * 0.55, head), Vector2(half * 0.45, size.y - head + 8.0)), Color(STONE_LINE, 0.12))
	# the parapet, a little wider than the drum
	var lip := half * 1.14
	b.polygon(_box(Vector2(x - lip, head - 8.0 * u), Vector2(lip * 2.0, 26.0 * u)), STONE)
	b.polygon(_box(Vector2(x - lip, head - 8.0 * u), Vector2(lip * 2.0, 6.0 * u)), STONE_LIT)
	for i in 3:
		var mx := x - lip + lip * 2.0 * float(i) / 2.5
		b.polygon(_box(Vector2(mx, head - 30.0 * u), Vector2(lip * 0.4, 24.0 * u)), STONE)
		b.polygon(_box(Vector2(mx, head - 30.0 * u), Vector2(lip * 0.4, 5.0 * u)), STONE_LIT)
	# a slit window
	b.polygon(Face.Builder.round_rect(Vector2(x - 8.0 * u, head + 58.0 * u), Vector2(16.0, 46.0) * u, 8.0 * u),
		Color(DOOR_DEEP, 0.75))
	for cy in [head + 130.0 * u, head + 188.0 * u]:
		if cy < size.y:
			b.stroke(PackedVector2Array([Vector2(x - half, cy), Vector2(x + half, cy)]), 3.0 * u,
				Color(STONE_LINE, 0.2), false, false)
	# the roof and its pennant
	var eave := head - 30.0 * u
	var tip := Vector2(x, eave - half * 1.25)
	b.polygon(PackedVector2Array([Vector2(x - lip * 0.92, eave), tip, Vector2(x + lip * 0.92, eave)]), ROOF)
	b.polygon(PackedVector2Array([Vector2(x + lip * 0.2, eave), tip, Vector2(x + lip * 0.92, eave)]), ROOF_DEEP)
	var mast := tip - Vector2(0.0, 44.0 * u)
	b.stroke(PackedVector2Array([tip + Vector2(0.0, 4.0 * u), mast]), 4.0 * u, DOOR_DEEP)
	b.polygon(PackedVector2Array([mast, mast + Vector2(flag * 40.0, 10.0) * u, mast + Vector2(0.0, 22.0 * u)]),
		Pal.KNIGHT_CREAM)
	b.stroke(PackedVector2Array([mast, mast + Vector2(flag * 40.0, 10.0) * u, mast + Vector2(0.0, 22.0 * u)]), 2.0 * u,
		Color(PRINT, 0.5), true)

## A rose bush `r` across, in bloom.
func _bush(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(-r * 0.62, r * 0.1), r * 0.66, BUSH_DEEP)
	b.disc(at + Vector2(r * 0.66, r * 0.14), r * 0.6, BUSH_DEEP)
	b.disc(at + Vector2(0.0, -r * 0.2), r * 0.88, BUSH)
	b.disc(at + Vector2(-r * 0.2, -r * 0.42), r * 0.5, BUSH.lightened(0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 13.0) + 3
	for i in 5:
		var p := at + Vector2(rng.randf_range(-0.85, 0.85), rng.randf_range(-0.75, 0.05)) * r
		b.disc(p, r * 0.15, ROSE)
		b.disc(p + Vector2(r * 0.03, r * 0.03), r * 0.07, ROSE_DEEP)

## A rose petal `r` long along `ang`.
func _petal(b: Face.Builder, at: Vector2, r: float, ang: float) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * float(k) / 14.0
		var rr := r * (0.55 + 0.45 * cos(a * 0.5) * cos(a * 0.5))
		pts.append(at + Vector2(cos(a) * rr, sin(a) * rr * 0.62).rotated(ang))
	b.polygon(pts, Color(ROSE, 0.85))

static func _box(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])
