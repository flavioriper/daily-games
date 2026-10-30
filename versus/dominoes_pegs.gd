extends Control

## Dominoes' scoring board: All Fives has been pegged on a board with holes
## since long before anybody counted it on a phone. A strip of pine with a
## line of holes for each side, one hole for each five points, the target
## at the far end. Each side's peg hops up its line a hole at a time when
## it scores, and says so (`hopped`), so the pops ride the pegs (house
## sound rule 6).
##
## The strip is one mesh, built when the size or the target changes; a peg
## is one cached mesh under a transform. Nothing runs at rest.

## A peg of `side` reached the next hole, the `n`th of this run.
signal hopped(side: int, n: int)

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const HEIGHT := 66.0
const PAD := 34.0
## Seconds a hole, and how far a peg leaves the board on its way.
const HOP_TIME := 0.08
const HOP_PX := 12.0
const HOLE_R := 4.5
const PEG_R := 11.0
const STEP := 5
const SUN := Color("f2b632")
const MOON := Color("8f96d6")

var _target := 120
var _mesh: ArrayMesh
var _pegs: Array[ArrayMesh] = []
var _key := Vector2.ZERO
## Where each peg stands, in holes, the hole it is going to, and how far
## along this hop it is, 0 to 1.
var _at := [0, 0]
var _to := [0, 0]
var _u := [0.0, 0.0]
var _run := [0, 0]

func _init() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

## A new game to `target`: both pegs home.
func reset(target: int) -> void:
	if target != _target:
		_mesh = null
	_target = target
	_at = [0, 0]
	_to = [0, 0]
	_u = [0.0, 0.0]
	queue_redraw()

## `side` has `score` points: its peg sets off for the hole that is.
func score(side: int, points: int) -> void:
	var hole: int = mini(points, _target) / STEP
	if hole == _to[side]:
		return
	_to[side] = hole
	_run[side] = 0
	if Motion.reduce:
		_at[side] = hole
		_u[side] = 0.0
		hopped.emit(side, 0)
		queue_redraw()
		return
	set_process(true)

func is_hopping() -> bool:
	return _at[0] != _to[0] or _at[1] != _to[1]

func _process(delta: float) -> void:
	for side in 2:
		if _at[side] >= _to[side]:
			continue
		_u[side] += delta / HOP_TIME
		if _u[side] >= 1.0:
			_u[side] = 0.0
			_at[side] += 1
			hopped.emit(side, _run[side])
			_run[side] += 1
	if not is_hopping():
		set_process(false)
	queue_redraw()

func _hole(side: int, n: float) -> Vector2:
	var holes := float(_target) / STEP
	return Vector2(PAD + (size.x - PAD * 2.0) * n / holes, HEIGHT * (0.3 if side == 0 else 0.7))

func _draw() -> void:
	if size.x <= 0.0:
		return
	if _mesh == null or _key != size:
		_key = size
		_mesh = _build()
		_pegs = [_peg(SUN), _peg(MOON)]
	draw_mesh(_mesh, null)
	for side in 2:
		var at := _hole(side, _at[side] + _u[side])
		at.y -= HOP_PX * sin(PI * _u[side])
		draw_mesh(_pegs[side], null, Transform2D(0.0, at))

func _build() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(Vector2(0.0, 5.0), size, 20.0), Color(0.2, 0.1, 0.04, 0.3))
	b.fan(Face.Builder.round_rect(Vector2(0.0, 3.0), Vector2(size.x, HEIGHT), 20.0), Scenery.PINE_DEEP)
	b.fan(Face.Builder.round_rect(Vector2.ZERO, Vector2(size.x, HEIGHT), 20.0), Scenery.PINE)
	var holes := _target / STEP
	for side in 2:
		for n in holes + 1:
			var at := _hole(side, n)
			var big := n % 5 == 0
			b.disc(at, HOLE_R + (1.5 if big else 0.0), Color(0.24, 0.13, 0.05, 0.75))
	# the far end: a flag of brass past the last hole
	var end := Vector2(size.x - PAD + 16.0, HEIGHT * 0.5)
	b.stroke(PackedVector2Array([end + Vector2(0.0, -20.0), end + Vector2(0.0, 20.0)]), 4.0, Color("7a4a2a"))
	b.polygon(PackedVector2Array([end + Vector2(2.0, -20.0), end + Vector2(2.0, -4.0), end + Vector2(-16.0, -12.0)]), Color("d9a441"))
	return b.mesh()

static func _peg(col: Color) -> ArrayMesh:
	var b := Face.Builder.new()
	b.disc(Vector2(1.0, 3.0), PEG_R, Color(0.1, 0.05, 0.02, 0.35))
	b.disc(Vector2.ZERO, PEG_R, col.darkened(0.2))
	b.disc(Vector2(-1.0, -2.0), PEG_R - 2.5, col)
	b.disc(Vector2(-3.0, -5.0), 2.5, Color(1, 1, 1, 0.6))
	return b.mesh()
