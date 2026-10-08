extends Control

## The air hockey table as the players see it, standing on end: the wooden
## frame with a goal's slot cut in each short rail, the pale top with its
## air holes and painted lines (baked once into one mesh, rebuilt only when
## the table is resized), and over it one live mesh a frame for the puck,
## the two mallets, their shadows and whatever just happened.
##
## The pieces take the game's soft painted cel (docs/art/shading-direction.md):
## a coloured shadow rather than a black one, a darker body with the lit face
## laid over it toward the light, one small highlight, no outline. The bottom
## mallet is the sun's gold and the top one the moon's blue, the two sides
## every Versus scoreboard already has.
##
## Input: a finger anywhere on the table leads a mallet, which rides a little
## ahead of it (LIFT) so the thumb does not cover what it is steering. With
## one hand (`hands` [true, false]) every touch is the bottom mallet's. With
## two (`hands` [true, true], two players on one phone) a press belongs to
## the half it lands in, one finger a mallet. The table only says where each
## hand wants its mallet (`sim.aim`); the sim moves it.

## A finger came down for `seat`.
signal touched(seat: int)

const Sim = preload("res://versus/hockey_sim.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

## The wooden rail round the top, metres, and its corner.
const RAIL := 0.062
const FRAME_R := 0.085
## How far ahead of the finger its mallet rides, metres.
const LIFT := 0.085
## The air holes' pitch, metres.
const HOLES := 0.064

const TOP := Color("eef3ea")
const TOP_LIT := Color("fbfdf8")
const TOP_EDGE := Color("d5dfd3")
const HOLE_DOT := Color(0.32, 0.42, 0.4, 0.2)
const WOOD := Color("9a6540")
const WOOD_LIT := Color("b98052")
const WOOD_DEEP := Color("64402a")
const LIP := Color("f6ead2")
const SLOT := Color("2a1c14")
const INK := Color(0.3, 0.6, 0.57, 0.5)
## The two sides: the body, its lit face, its shade.
const SIDE := [
	[Color("f5a623"), Color("fbc75c"), Color("c97c12")],
	[Color("7d8fd9"), Color("a9b6ec"), Color("5262ad")],
]
const PUCK := Color("3f4652")
const PUCK_LIT := Color("5a6272")
const PUCK_DEEP := Color("2b303a")
const SHADOW := Color(0.2, 0.26, 0.3, 0.22)
const LIGHT := Vector2(-0.45, -0.6)
## The motion: how many frames of trail a fast puck leaves and the speed under
## which it has none, how long a contact's flash and a goal's glow last, and
## how long a struck mallet takes to settle.
const TRAIL := 8
const TRAIL_SPEED := 1.4
const FLASH := 0.26
const GLOW := 0.9
const BUMP := 0.22

var sim: RefCounted
## Which seats a finger leads.
var hands := [true, false]
var interactive := false
## A picture, not a game (the Versus tab's card): drawn once per resize.
var still := false

var ppm := 100.0
var origin := Vector2.ZERO
var _table: ArrayMesh
var _live: ArrayMesh
var _shown: Array = []
## The touch leading each seat (-1 none; MOUSE for the desktop's pointer).
var _finger := [-1, -1]
const MOUSE := 99
var _trail: Array[Vector2] = []
## Contacts still showing: {kind, at (metres), t, strength, seat}.
var _flashes: Array = []
## Each goal's glow, seconds left (the goal at the bottom is 0).
var _glow := [0.0, 0.0]
## Each mallet's squash after a hit, seconds left.
var _bump := [0.0, 0.0]
## The puck dropping into a goal: where from, into which end, seconds in.
var _sink := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still else Control.MOUSE_FILTER_STOP
	resized.connect(_relayout)
	_relayout()

func _relayout() -> void:
	var span := Vector2(Sim.W, Sim.L) + Vector2.ONE * 2.0 * RAIL
	if size.x <= 0.0 or size.y <= 0.0:
		return
	ppm = minf(size.x / span.x, size.y / span.y)
	origin = (size - span * ppm) * 0.5 + Vector2.ONE * RAIL * ppm
	_table = null
	queue_redraw()

func px(p: Vector2) -> Vector2:
	return origin + p * ppm

func metres(p: Vector2) -> Vector2:
	return (p - origin) / ppm

## The table's outer rectangle in this control's pixels.
func frame_rect() -> Rect2:
	return Rect2(origin - Vector2.ONE * RAIL * ppm, Vector2(Sim.W, Sim.L) * ppm + Vector2.ONE * 2.0 * RAIL * ppm)

func _process(delta: float) -> void:
	if still:
		return
	for f in _flashes:
		f.t += delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return f.t < FLASH)
	for k in 2:
		_glow[k] = maxf(0.0, _glow[k] - delta)
		_bump[k] = maxf(0.0, _bump[k] - delta)
	if not _sink.is_empty():
		_sink.t += delta
		if _sink.t > 0.3:
			_sink = {}
	_track_trail()
	queue_redraw()

func _track_trail() -> void:
	if sim == null or Motion.reduce:
		_trail.clear()
		return
	if sim.puck_on and sim.puck_vel.length() > TRAIL_SPEED:
		_trail.append(sim.puck)
		if _trail.size() > TRAIL:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()

## A contact the players should see: "mallet" (with its seat), "wall", "post".
func flash(kind: String, at: Vector2, strength: float, seat := -1) -> void:
	if seat >= 0:
		_bump[seat] = BUMP
	if Motion.reduce:
		return
	_flashes.append({"kind": kind, "at": at, "t": 0.0, "strength": clampf(strength, 0.15, 1.0), "seat": seat})

## The puck went in at `end` (0 the bottom goal) from `at`.
func goal(end: int, at: Vector2) -> void:
	_glow[end] = GLOW
	_trail.clear()
	if not Motion.reduce:
		_sink = {"from": at, "end": end, "t": 0.0}

## Nobody is leading a mallet any more (a goal, the end, a card going up).
func let_go() -> void:
	_finger = [-1, -1]

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if not interactive or sim == null:
		return
	var id := -1
	var press := false
	var release := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		id = event.index
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag:
		id = event.index
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		id = MOUSE
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		id = MOUSE
		at = event.position
	else:
		return
	accept_event()
	var seat := _finger.find(id)
	if release:
		if seat != -1:
			_finger[seat] = -1
		return
	if press and seat == -1:
		seat = _seat_for(at)
		if seat == -1 or _finger[seat] != -1:
			return
		_finger[seat] = id
		touched.emit(seat)
	if seat == -1:
		return
	var lift := Vector2(0.0, -LIFT if seat == 0 else LIFT)
	sim.aim[seat] = Sim.clamp_half(seat, metres(at) + lift)

## Whose press this is: with one hand always the bottom mallet's, with two
## the half it landed in.
func _seat_for(at: Vector2) -> int:
	if hands[0] and hands[1]:
		return 0 if metres(at).y >= Sim.L * 0.5 else 1
	if hands[0]:
		return 0
	return 1 if hands[1] else -1

# --- drawing ---

func _draw() -> void:
	if sim == null or size.x <= 0.0:
		return
	if _table == null:
		_table = _build_table()
	draw_mesh(_table, null)
	_live = _build_live()
	draw_mesh(_live, null)
	_shown = [_table, _live]

func _build_table() -> ArrayMesh:
	var b := Face.Builder.new()
	var outer := frame_rect()
	var r := FRAME_R * ppm
	var top := Rect2(origin, Vector2(Sim.W, Sim.L) * ppm)
	# The table's own shadow on the deck, soft and warm.
	for k in 4:
		var grow := 6.0 + k * 7.0
		b.fan(Face.Builder.round_rect(outer.position + Vector2(-grow * 0.5, 18.0 - grow * 0.2),
			outer.size + Vector2(grow, grow * 0.6), r + grow), Color(0.24, 0.13, 0.07, 0.09))
	# The wooden frame: a deep base, the lit top, the grain.
	b.fan(Face.Builder.round_rect(outer.position + Vector2(0.0, 7.0), outer.size, r), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(outer.position, outer.size, r), WOOD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 26:
		var long := k % 2 == 0
		var side := 1.0 if (k / 2) % 2 == 0 else 0.0
		var t := rng.randf_range(0.08, 0.72)
		var len := rng.randf_range(0.1, 0.22)
		var off := rng.randf_range(0.2, 0.8) * RAIL * ppm
		var a: Vector2
		var d: Vector2
		if long:
			a = Vector2(outer.position.x + off + side * (outer.size.x - RAIL * ppm), outer.position.y + outer.size.y * t)
			d = Vector2(0.0, outer.size.y * len)
		else:
			a = Vector2(outer.position.x + outer.size.x * t, outer.position.y + off + side * (outer.size.y - RAIL * ppm))
			d = Vector2(outer.size.x * len, 0.0)
		b.stroke(PackedVector2Array([a, a + d]), 2.0, Color(WOOD_LIT if k % 3 != 0 else WOOD_DEEP, 0.4), false, true)
	b.stroke(Face.Builder.round_rect(outer.position + Vector2.ONE * 3.0, outer.size - Vector2.ONE * 6.0, r - 3.0),
		2.5, Color(WOOD_LIT, 0.7), true, false)
	# The top's well: a dark edge, the cream lip, then the top itself.
	var well := 0.016 * ppm
	b.fan(Face.Builder.round_rect(top.position - Vector2.ONE * (well + 4.0), top.size + Vector2.ONE * (well + 4.0) * 2.0, well + 8.0), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(top.position - Vector2.ONE * well, top.size + Vector2.ONE * well * 2.0, well + 4.0), LIP)
	# The goals: a slot through the lip into the rail, trimmed in its side's colour.
	for end in 2:
		var y := origin.y + (Sim.L * ppm if end == 0 else 0.0)
		var out := 1.0 if end == 0 else -1.0
		var half := Sim.GOAL_HALF * ppm
		var deep := RAIL * ppm * 0.7
		var at := Vector2(origin.x + Sim.W * ppm * 0.5 - half, y if end == 0 else y - deep)
		b.fan(Face.Builder.round_rect(at - Vector2(5.0, 0.0 if end == 0 else 5.0), Vector2(half * 2.0 + 10.0, deep + 5.0), 9.0), SIDE[end][2])
		b.fan(Face.Builder.round_rect(at, Vector2(half * 2.0, deep), 6.0), SLOT)
		b.fan(Face.Builder.round_rect(at + Vector2(6.0, 6.0 if end == 0 else 0.0), Vector2(half * 2.0 - 12.0, deep - 6.0), 5.0), Color("1a100a"))
		# the mouth through the lip
		b.fan(PackedVector2Array([Vector2(at.x, y), Vector2(at.x + half * 2.0, y),
			Vector2(at.x + half * 2.0, y + out * (well + 1.0)), Vector2(at.x, y + out * (well + 1.0))]), SLOT)
	b.fan(Face.Builder.round_rect(top.position, top.size, 7.0), TOP_EDGE)
	b.fan(Face.Builder.round_rect(top.position + Vector2.ONE * 3.0, top.size - Vector2.ONE * 6.0, 6.0), TOP)
	# Lit from its middle, falling off toward the rails.
	var mid := top.get_center()
	for k in 12:
		var f := 1.0 - k * 0.075
		b.ellipse(mid + Vector2(-top.size.x * 0.04, -top.size.y * 0.05), top.size.x * 0.49 * f, top.size.y * 0.47 * f, Color(TOP_LIT, 0.07))
	# The air holes.
	var nx := int(floor(Sim.W / HOLES))
	var ny := int(floor(Sim.L / HOLES))
	var dot := maxf(1.2, ppm * 0.0028)
	for i in nx:
		for j in ny:
			var p := Vector2((i + 0.5) * Sim.W / nx, (j + 0.5) * Sim.L / ny)
			b.fan(_square(px(p), dot), HOLE_DOT)
	# The lines: the middle, its circle, a ring to face off in each quarter,
	# and each goal's crease in its side's colour.
	var w := maxf(2.5, ppm * 0.007)
	b.stroke(PackedVector2Array([px(Vector2(0.0, Sim.L * 0.5)), px(Vector2(Sim.W, Sim.L * 0.5))]), w, INK, false, false)
	b.disc(px(Vector2(Sim.W, Sim.L) * 0.5), 0.132 * ppm, Color(TOP, 1.0))
	b.stroke(Face.Builder.ring(px(Vector2(Sim.W, Sim.L) * 0.5), 0.13 * ppm, 0.13 * ppm), w, INK, true, false)
	b.disc(px(Vector2(Sim.W, Sim.L) * 0.5), 0.016 * ppm, INK)
	for end in 2:
		var tint: Color = SIDE[end][0]
		var gy := Sim.L if end == 0 else 0.0
		var crease := Face.Builder.arc_points(px(Vector2(Sim.W * 0.5, gy)), (Sim.GOAL_HALF + 0.06) * ppm,
			PI if end == 0 else 0.0, TAU if end == 0 else PI)
		b.fan(crease, Color(tint, 0.13))
		b.stroke(crease, w, Color(tint, 0.62), false, false)
		for sx in [0.25, 0.75]:
			var c := px(Vector2(Sim.W * sx, Sim.L * (0.74 if end == 0 else 0.26)))
			b.stroke(Face.Builder.ring(c, 0.085 * ppm, 0.085 * ppm), w * 0.8, Color(INK, 0.34), true, false)
			b.disc(c, 0.011 * ppm, Color(INK, 0.4))
	return b.mesh()

static func _square(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

func _build_live() -> ArrayMesh:
	var b := Face.Builder.new()
	# A goal's glow, under everything: the slot lights and the crease warms.
	for end in 2:
		if _glow[end] <= 0.0:
			continue
		var u: float = _glow[end] / GLOW
		var gy := Sim.L if end == 0 else 0.0
		var c := px(Vector2(Sim.W * 0.5, gy))
		var tint: Color = SIDE[1 - end][1]
		for k in 3:
			b.fan(Face.Builder.arc_points(c, (Sim.GOAL_HALF + 0.06 + 0.1 * k * (1.0 - u)) * ppm,
				PI if end == 0 else 0.0, TAU if end == 0 else PI), Color(tint, 0.22 * u))
	var shade := Vector2(0.009, 0.016) * ppm
	# shadows first, so no piece shades another's top
	for p in 2:
		b.disc(px(sim.mallet[p]) + shade * 1.3, Sim.MALLET_R * ppm * 1.02, SHADOW)
	if sim.puck_on:
		b.disc(px(sim.puck) + shade * 0.7, Sim.PUCK_R * ppm, SHADOW)
	# the puck's trail
	for i in _trail.size():
		var f := float(i + 1) / float(_trail.size() + 1)
		b.disc(px(_trail[i]), Sim.PUCK_R * ppm * (0.45 + 0.5 * f), Color(PUCK, 0.1 * f))
	if sim.puck_on:
		_puck(b, px(sim.puck), 1.0)
	elif not _sink.is_empty():
		var u2: float = clampf(float(_sink.t) / 0.3, 0.0, 1.0)
		var gy2 := Sim.L + RAIL * 0.4 if int(_sink.end) == 0 else -RAIL * 0.4
		_puck(b, px((_sink.from as Vector2).lerp(Vector2((_sink.from as Vector2).x, gy2), u2)), 1.0 - 0.75 * u2)
	for p in 2:
		var squash := 0.0
		if _bump[p] > 0.0 and not Motion.reduce:
			var bu: float = _bump[p] / BUMP
			squash = sin(bu * PI) * 0.09
		_mallet(b, px(sim.mallet[p]), p, 1.0 + squash)
	for f in _flashes:
		var u3: float = float(f.t) / FLASH
		var c2 := px(f.at)
		var s: float = f.strength
		var tint2: Color = SIDE[int(f.seat)][1] if int(f.seat) >= 0 else Color("ffffff")
		var rr := ppm * (0.02 + 0.07 * s * u3)
		for k in 6:
			var ang := TAU * k / 6.0 + 0.4
			var d := Vector2.from_angle(ang)
			b.stroke(PackedVector2Array([c2 + d * rr, c2 + d * (rr + ppm * 0.022 * s * (1.0 - u3) + 2.0)]),
				maxf(2.0, ppm * 0.008 * (1.0 - u3)), Color(tint2, 0.9 * (1.0 - u3)), false, true)
	return b.mesh()

func _puck(b: Face.Builder, at: Vector2, scale_by: float) -> void:
	var r := Sim.PUCK_R * ppm * scale_by
	b.disc(at, r, PUCK_DEEP)
	b.disc(at + LIGHT * r * 0.08, r * 0.9, PUCK)
	b.stroke(Face.Builder.ring(at + LIGHT * r * 0.08, r * 0.58, r * 0.58), maxf(1.5, r * 0.09), Color(PUCK_LIT, 0.9), true, false)
	b.disc(at + LIGHT * r * 0.5, r * 0.11, Color(1, 1, 1, 0.55))

## A mallet from straight above: the skirt, the dished top and the knob.
func _mallet(b: Face.Builder, at: Vector2, seat: int, scale_by: float) -> void:
	var r := Sim.MALLET_R * ppm * scale_by
	var body: Color = SIDE[seat][0]
	var lit: Color = SIDE[seat][1]
	var deep: Color = SIDE[seat][2]
	b.disc(at, r, deep)
	b.disc(at + LIGHT * r * 0.06, r * 0.93, body)
	b.stroke(Face.Builder.arc_points(at + LIGHT * r * 0.06, r * 0.8, PI * 0.95, PI * 1.55), maxf(2.0, r * 0.07), Color(lit, 0.9), false, true)
	b.disc(at - LIGHT * r * 0.05, r * 0.6, deep)
	b.disc(at + LIGHT * r * 0.03, r * 0.55, body.darkened(0.06))
	# the knob, standing up toward the light
	b.disc(at - LIGHT * r * 0.14, r * 0.4, Color(deep, 0.8))
	b.disc(at + LIGHT * r * 0.1, r * 0.36, deep)
	b.disc(at + LIGHT * r * 0.16, r * 0.33, lit)
	b.disc(at + LIGHT * r * 0.3, r * 0.1, Color(1, 1, 1, 0.75))
