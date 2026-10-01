extends Control

## One page of Balance's tutorial: the board's seesaw in little -- its
## trestle, stone keel, notched plank with the distance pips, the spirit
## level and its bubble, the basket, and on Insane the springy bales -- with
## one move played on a loop over a caption that says what it means. The
## weights here are the page's own (an apple 2, a pear 1, a pumpkin 3, an
## acorn 2), which the real board keeps secret. `lesson` picks the page (set
## before it enters the tree):
##
## - DRAG: an apple is dragged from the basket into a cup and the beam
##   leans; then it is tapped and hops home.
## - WEIGH: the apple alone in cup 1 reads its weight on the level; in cup 3
##   it pulls three times as hard.
## - LEVEL: a pinned pumpkin leans the beam; the apple in cup 1 is not
##   enough, in cup 3 it is dead level, and the plank goes gold.
## - HINT: the apple flies to its cup by itself and is pinned there in gold.
## - SUN: every move sinks the sun a step, and the pill counts what is left.
## - BALES: a beam pushed past the glass bumps the bale, and every loose
##   fruit on that side bounces home.
##
## Performance checkup, 2026-10-01: the one generic card became these pages.

const Fruit = preload("res://ui/faces/fruit.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Rewards = preload("res://arcade/rewards.gd")
const CozyTheme = preload("res://ui/theme.gd")

enum Lesson { DRAG, WEIGH, LEVEL, HINT, SUN, BALES }

const BASKET := 99
const REACH := 3
## The board's own proportions, in cups (balance2d.gd).
const R := 0.41
const SEAT := 1.02
const PLANK_T := 0.3
const OVER := 0.55
const VIAL_UP := 1.02
const VIAL_W := 2.3
const VIAL_H := 0.3
const TICKS := 5
const TICK := 0.03
const A_MAX := 0.1635
const GLASS := 5
const LEGS := 1.75
const FLY := 0.55
const DRAG_TIME := 0.9
const BEAM_EASE := 5.0
## The page's weights by fruit kind: apple, pear, pumpkin, acorn.
const WEIGHT := [2, 1, 3, 2, 2]

var lesson: int = Lesson.DRAG

var _caption: Label
var _cup := 80.0
var _pivot := Vector2.ZERO
var _ground := 0.0
var _basket := Rect2()
var _a := 0.0
var _clock := 0.0
var _loop := 0.0
var _script: Array = []
var _next := 0
## {kind, at (cup or BASKET), slot, pinned, gold, face, fly: {from, t0, dur, high, drag}}
var _fruit: Array = []
var _tap_at := Vector2.INF
var _tap_t := -10.0
var _gold_t := -10.0
var _boing_t := -10.0
var _sun := 0
var _sun_shown := 0.0
var _tag := ""
var _started := false
var _front: Control
## Kept until the next draw replaces them: a canvas holds a mesh's RID only.
var _back_mesh: ArrayMesh
var _front_mesh: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the fruit go between this control's own drawing (the seesaw's back)
	# and the front layer (the cups' lips, the basket's weave, the pins)
	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.draw.connect(_draw_front)
	add_child(_front)
	add_child(_caption)
	resized.connect(func() -> void: call_deferred("_start"))
	call_deferred("_start")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _started:
		call_deferred("_start")

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	_started = true
	_caption.position = Vector2(20.0, size.y - 92.0)
	_caption.size = Vector2(size.x - 40.0, 88.0)
	var room := size.y - 96.0
	var span := 2.0 * (REACH + OVER) + (1.6 if lesson == Lesson.BALES else 0.4)
	_cup = minf(size.x / (span + 0.6), room / 4.75)
	_pivot = Vector2(size.x * 0.5, _cup * (VIAL_UP + 0.62) + 8.0)
	if lesson == Lesson.SUN:
		_pivot.x = size.x * 0.56
	_ground = _pivot.y + LEGS * _cup
	var bw := _cup * 3.4
	_basket = Rect2(Vector2(size.x * 0.5 - bw * 0.5, _ground + _cup * 0.32), Vector2(bw, _cup * 0.8))
	_scene()
	if Motion.reduce:
		_still()
		set_process(false)
		queue_redraw()
		return
	set_process(true)

# --- the scene and its script ---

func _scene() -> void:
	for f in _fruit:
		f.face.queue_free()
	_fruit = []
	_a = 0.0
	_clock = 0.0
	_next = 0
	_tap_t = -10.0
	_gold_t = -10.0
	_boing_t = -10.0
	_tag = ""
	_sun = 0
	_sun_shown = 0.0
	_script = []
	match lesson:
		Lesson.DRAG:
			_add(0)
			_add(1)
			_add(3)
			_say(0.0, "HTP_BAL_DRAG_CAP")
			_at(0.8, func() -> void: _move(0, -2, true))
			_at(2.8, func() -> void: _tap(0))
			_say(2.8, "HTP_BAL_HOME_CAP")
			_at(3.2, func() -> void: _move(0, BASKET))
			_loop = 5.4
		Lesson.WEIGH:
			_add(0)
			_add(1)
			_say(0.0, "HTP_BAL_WEIGH_CAP")
			_at(0.7, func() -> void: _move(0, 1, true))
			_at(1.9, func() -> void: _tag = "2")
			_say(3.4, "HTP_BAL_FAR_CAP")
			_at(3.4, func() -> void:
				_tag = ""
				_move(0, 3, true))
			_at(4.6, func() -> void: _tag = "6")
			_at(6.6, func() -> void:
				_tag = ""
				_move(0, BASKET))
			_loop = 7.6
		Lesson.LEVEL:
			_add(2, -2, true)
			_add(0)
			_say(0.0, "HTP_BAL_LEANS_CAP")
			_at(0.8, func() -> void: _move(1, 1, true))
			_say(2.8, "HTP_BAL_LEVEL_CAP")
			_at(2.8, func() -> void: _move(1, 3, true))
			_at(3.9, func() -> void: _cheer())
			_loop = 7.0
		Lesson.HINT:
			_add(2, -2, true)
			_add(0)
			_say(0.0, "HTP_BAL_HINT_CAP")
			_at(1.0, func() -> void:
				_fruit[1].gold = true
				_move(1, 3))
			_at(1.0 + FLY + 0.05, func() -> void: _cheer())
			_loop = 4.6
		Lesson.SUN:
			_add(0)
			_add(1)
			_add(3)
			_sun = 3
			_sun_shown = 3.0
			_say(0.0, "HTP_BAL_SUN_CAP")
			_at(0.8, func() -> void: _step_sun(func() -> void: _move(0, -1, true)))
			_at(2.3, func() -> void: _step_sun(func() -> void: _move(1, 2, true)))
			_at(3.8, func() -> void:
				_tap(1)
				_step_sun(func() -> void: _move(1, BASKET)))
			_say(4.6, "HTP_BAL_DUSK_CAP")
			_loop = 6.4
		Lesson.BALES:
			_add(1)
			_add(3)
			_add(2)
			_say(0.0, "HTP_BAL_BALES_CAP")
			_at(0.6, func() -> void: _move(0, 1, true))
			_at(1.7, func() -> void: _move(1, 2, true))
			_say(3.0, "HTP_BAL_BOING_CAP")
			_at(3.0, func() -> void: _move(2, 3, true))
			_loop = 7.0
	_layout_basket()

## The lesson's end, standing still, for reduce motion.
func _still() -> void:
	match lesson:
		Lesson.DRAG:
			_settle(0, -2)
			_caption.text = tr("HTP_BAL_DRAG_CAP")
		Lesson.WEIGH:
			_settle(0, 3)
			_tag = "6"
			_caption.text = tr("HTP_BAL_FAR_CAP")
		Lesson.LEVEL:
			_settle(1, 3)
			_gold_t = 0.0
			_caption.text = tr("HTP_BAL_LEVEL_CAP")
		Lesson.HINT:
			_fruit[1].gold = true
			_settle(1, 3)
			_caption.text = tr("HTP_BAL_HINT_CAP")
		Lesson.SUN:
			_settle(0, -1)
			_sun = 1
			_sun_shown = 1.0
			_caption.text = tr("HTP_BAL_SUN_CAP")
		Lesson.BALES:
			_settle(0, 1)
			_settle(1, 2)
			_caption.text = tr("HTP_BAL_BALES_CAP")
	_a = _target()
	_place_faces()

func _settle(i: int, cup: int) -> void:
	_fruit[i].at = cup
	_fruit[i].fly = {}

func _add(kind: int, cup := BASKET, pinned := false) -> void:
	var face := Fruit.make(kind, _cup * SEAT, Vector2.ZERO)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.shadowless = true
	face.set_idle(not Motion.reduce)
	add_child(face)
	move_child(face, _front.get_index())
	_fruit.append({"kind": kind, "at": cup, "slot": Vector2.ZERO, "pinned": pinned, "gold": false,
		"face": face, "fly": {}, "dizzy": -10.0})

## The basket's seats, the loose fruit in order.
func _layout_basket() -> void:
	var loose := _fruit.filter(func(f: Dictionary) -> bool: return not f.pinned)
	var pitch := _cup * 1.0
	var x0 := _basket.get_center().x - pitch * (loose.size() - 1) * 0.5
	for i in loose.size():
		loose[i].slot = Vector2(x0 + pitch * i, _basket.position.y - _cup * 0.08)

func _at(t: float, what: Callable) -> void:
	_script.append([t, what])
	_script.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])

func _say(t: float, key: String) -> void:
	_at(t, func() -> void: _caption.text = tr(key))

## Fruit `i` off to `to` (a cup, or BASKET): a low carry under a finger when
## `drag`, else a hop.
func _move(i: int, to: int, drag := false) -> void:
	var f: Dictionary = _fruit[i]
	var from := _pos(f)
	f.at = to
	f.fly = {"from": from, "t0": _clock, "dur": DRAG_TIME if drag else FLY,
		"high": _cup * (0.5 if drag else 1.3), "drag": drag}

func _tap(i: int) -> void:
	_tap_at = _pos(_fruit[i])
	_tap_t = _clock

func _step_sun(then: Callable) -> void:
	_sun -= 1 if _sun > 0 else 0
	then.call()

func _cheer() -> void:
	_gold_t = _clock

func _process(delta: float) -> void:
	_clock += delta
	while _next < _script.size() and _clock >= float(_script[_next][0]):
		(_script[_next][1] as Callable).call()
		_next += 1
	if _clock >= _loop:
		_scene()
		return
	var target := _target()
	_a = lerpf(_a, target, 1.0 - exp(-delta * BEAM_EASE))
	if lesson == Lesson.BALES and absf(target) >= A_MAX - 0.001 and absf(_a) > A_MAX * 0.97 and _boing_t < 0.0:
		_boing()
	_sun_shown = lerpf(_sun_shown, float(_sun), 1.0 - exp(-delta * 3.0))
	_place_faces()
	queue_redraw()

## The springy bale, bumped: every loose fruit on the low side hops home,
## seeing stars.
func _boing() -> void:
	_boing_t = _clock
	var side := signf(_a)
	for i in _fruit.size():
		var f: Dictionary = _fruit[i]
		if not f.pinned and f.at != BASKET and signf(f.at) == side:
			_move(i, BASKET)
			f.fly.high = _cup * 2.0
			f.dizzy = _clock + FLY + 1.6

## The beam's lean for what has landed: a tick of the level per unit of pull,
## stopped by the bales.
func _torque() -> int:
	var t := 0
	for f: Dictionary in _fruit:
		if f.at != BASKET and f.fly.is_empty():
			t += WEIGHT[f.kind] * int(f.at)
	return t

func _target() -> float:
	return clampf(atan(_torque() * TICK), -A_MAX, A_MAX)

func _xf() -> Transform2D:
	return Transform2D(_a, _pivot)

func _seat_at(cup: int) -> Vector2:
	# a little into the cup's notch, as on the board
	return _xf() * Vector2(cup * _cup, -_cup * PLANK_T * 0.5 - _cup * R * 0.8)

func _pos(f: Dictionary) -> Vector2:
	var rest: Vector2 = f.slot if f.at == BASKET else _seat_at(int(f.at))
	if f.fly.is_empty():
		return rest
	var u := clampf((_clock - float(f.fly.t0)) / float(f.fly.dur), 0.0, 1.0)
	if u >= 1.0:
		f.fly = {}
		return rest
	var e := u * u * (3.0 - 2.0 * u)
	return (f.fly.from as Vector2).lerp(rest, e) + Vector2(0.0, -float(f.fly.high) * sin(PI * u))

func _place_faces() -> void:
	for f: Dictionary in _fruit:
		var p := _pos(f)
		var face: Control = f.face
		Fruit.resize(face, _cup * SEAT, p)
		face.rotation = _a if f.at != BASKET and f.fly.is_empty() else 0.0
		var expr := Face.Expr.HAPPY
		if _clock < float(f.dizzy) or (not f.fly.is_empty() and not f.fly.drag):
			expr = Face.Expr.PUZZLED
		elif not f.fly.is_empty():
			expr = Face.Expr.JOY
		elif _gold_t >= 0.0:
			expr = Face.Expr.JOY
		elif f.at != BASKET:
			var dip := _a * signf(float(f.at))
			if dip > 0.06:
				expr = Face.Expr.WORRIED
			elif dip > 0.025:
				expr = Face.Expr.STRAIN
		if face.expression != expr:
			face.expression = expr

# --- drawing ---

func _draw() -> void:
	if size.x <= 0.0 or _fruit.is_empty():
		return
	var b := Face.Builder.new()
	var top := _cup * PLANK_T * 0.5
	var half := (REACH + OVER) * _cup
	if lesson == Lesson.SUN:
		_sky(b)
	# the meadow and the trestle's shadow
	b.fan(Face.Builder.round_rect(Vector2(_cup * 0.2, _ground - 3.0), Vector2(size.x - _cup * 0.4, _basket.end.y - _ground - _cup * 0.1), _cup * 0.3),
		Pal.LAWN.lerp(Pal.PAPER, 0.25))
	Scenery.soft_disc(b, Vector2(_pivot.x, _ground + _cup * 0.08), half * 0.9, _cup * 0.16, Color(Pal.TEXT, 0.12))
	if lesson == Lesson.BALES:
		_bales(b, half, top)
	for side: float in [-1.0, 1.0]:
		var foot := Vector2(_pivot.x + side * 0.85 * _cup, _ground + _cup * 0.06)
		b.stroke(PackedVector2Array([_pivot, foot]), 0.18 * _cup, Pal.SCALE_DEEP)
	var bar_y := _pivot.y + LEGS * _cup * 0.62
	b.stroke(PackedVector2Array([Vector2(_pivot.x - 0.53 * _cup, bar_y), Vector2(_pivot.x + 0.53 * _cup, bar_y)]), 0.12 * _cup, Pal.SCALE_DEEP)
	# the keel and its stone, turning with the beam
	var xf := _xf()
	var end := Vector2(0.0, 1.1 * _cup)
	b.stroke(PackedVector2Array([xf * Vector2.ZERO, xf * end]), _cup * 0.08, Pal.SCALE_DARK)
	var sr := 0.3 * _cup
	b.ellipse(xf * end, sr * 1.12, sr, Pal.BOULDER)
	b.ellipse(xf * (end + Vector2(-sr * 0.2, -sr * 0.2)), sr * 0.7, sr * 0.55, Pal.BOULDER.lerp(Pal.PAPER, 0.25))
	_plank(b, xf, half, top)
	# the basket's inside, behind its fruit
	b.ellipse(Vector2(_basket.get_center().x, _basket.position.y + _cup * 0.1), _basket.size.x * 0.46, _cup * 0.2,
		Pal.ACORN_DEEP.lerp(Pal.WOOD_DEEP, 0.4))
	_back_mesh = b.mesh()
	draw_mesh(_back_mesh, null)
	_front.queue_redraw()

func _draw_front() -> void:
	if size.x <= 0.0 or _fruit.is_empty():
		return
	var b := Face.Builder.new()
	var xf := _xf()
	var top := _cup * PLANK_T * 0.5
	var lip_w := _cup * SEAT * 0.72
	var lip_h := _cup * R * 0.24
	for x in range(-REACH, REACH + 1):
		if x == 0:
			continue
		var c := Vector2(x * _cup, -top)
		b.fan(_xf_pts(xf, Face.Builder.round_rect(c + Vector2(-lip_w * 0.5, -lip_h * 0.5), Vector2(lip_w, lip_h), lip_h * 0.5)),
			Pal.SCALE_WOOD.lerp(Pal.SCALE_DEEP, 0.45))
	# pins through the stalks: brass for a pinned fruit, gold for a hint's
	for f: Dictionary in _fruit:
		if (f.pinned or f.gold) and f.fly.is_empty() and f.at != BASKET:
			var head := _pos(f) + Vector2(0.0, -_cup * R * 1.02).rotated(_a)
			var k := _cup * 0.14
			b.stroke(PackedVector2Array([head, head + Vector2(0.0, k * 1.6).rotated(_a)]), maxf(2.0, k * 0.22), Pal.STEEL)
			b.disc(head, k * 0.62, Pal.SUN_DEEP if f.gold else Pal.BRASS_DEEP)
			b.disc(head + Vector2(-k * 0.08, -k * 0.08), k * 0.48, Pal.SUN if f.gold else Pal.BRASS)
	# the basket's woven front
	var r := _basket
	var rim_y := r.position.y + _cup * 0.22
	var body := Rect2(Vector2(r.position.x, rim_y), Vector2(r.size.x, r.end.y - rim_y))
	b.fan(Face.Builder.round_rect(body.position, body.size, _cup * 0.26), Pal.WHEAT.lerp(Pal.ACORN, 0.35))
	var rows := 2
	var row_h := (body.size.y - _cup * 0.2) / rows
	for rw in rows:
		var y := body.position.y + _cup * 0.18 + rw * row_h
		var step := _cup * 0.34
		var k := 0
		var x := body.position.x + _cup * 0.2 + (step * 0.5 if rw % 2 == 1 else 0.0)
		while x < body.end.x - _cup * 0.25:
			b.fan(Face.Builder.round_rect(Vector2(x, y), Vector2(step * 0.72, row_h * 0.62), row_h * 0.3),
				Pal.WHEAT.lerp(Pal.PAPER, 0.18) if (k + rw) % 2 == 0 else Pal.WHEAT)
			x += step
			k += 1
	b.fan(Face.Builder.round_rect(Vector2(r.position.x - 4.0, rim_y - _cup * 0.06), Vector2(r.size.x + 8.0, _cup * 0.14), _cup * 0.07), Pal.ACORN)
	# a finger on the fruit being carried, and a tap's ring
	for f: Dictionary in _fruit:
		if not f.fly.is_empty() and f.fly.drag:
			_finger(b, _pos(f) + Vector2(_cup * 0.22, _cup * 0.32))
	var tu := (_clock - _tap_t) / 0.6
	if tu >= 0.0 and tu < 1.0:
		b.stroke(Face.Builder.ring(_tap_at, _cup * (0.35 + 0.4 * tu), _cup * (0.35 + 0.4 * tu)), 5.0, Color(Pal.ACCENT, 1.0 - tu), true)
		_finger(b, _tap_at + Vector2(_cup * 0.22, _cup * 0.32))
	# the stars over a fruit a bale bounced
	for f: Dictionary in _fruit:
		if _clock < float(f.dizzy):
			var p := _pos(f)
			for k in 3:
				var ang := _clock * 5.0 + TAU * k / 3.0
				Rewards.star(b, p + Vector2(cos(ang) * _cup * 0.32, -_cup * 0.5 + sin(ang) * _cup * 0.1), _cup * 0.07, Pal.SUN, ang)
	if lesson == Lesson.SUN:
		_pill(b)
	_front_mesh = b.mesh()
	_front.draw_mesh(_front_mesh, null)
	if _tag != "":
		var font: Font = CozyTheme.display(700)
		var at := _xf() * Vector2(VIAL_W * _cup * 0.5 + _cup * 0.45, -(top + VIAL_UP * _cup))
		var fs := int(_cup * 0.5)
		var w := font.get_string_size(_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_front.draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), _tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
	if lesson == Lesson.SUN:
		var font: Font = CozyTheme.display(700)
		var fs := int(_cup * 0.36)
		var s := str(_sun)
		var c := _pill_centre()
		_front.draw_string(font, c + Vector2(_cup * 0.08, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)

static func _xf_pts(xf: Transform2D, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = xf * pts[i]
	return out

## The plank in the board's frame, turned: the board with a notch per cup,
## its shaded lower edge, the distance pips, the level on its bracket with
## the bubble at the high end, and the hub.
func _plank(b: Face.Builder, xf: Transform2D, half: float, top: float) -> void:
	var glow := 0.0
	if _gold_t >= 0.0:
		glow = 1.0 if Motion.reduce else clampf((_clock - _gold_t) / 0.3, 0.0, 1.0)
	var wood := Pal.SCALE_WOOD.lerp(Pal.SUN, 0.45 * glow)
	var pts := PackedVector2Array([Vector2(-half, -top), Vector2(half, -top), Vector2(half, top), Vector2(-half, top)])
	b.fan(_xf_pts(xf, pts), wood)
	b.fan(_xf_pts(xf, PackedVector2Array([Vector2(-half, top * 0.25), Vector2(half, top * 0.25), Vector2(half, top), Vector2(-half, top)])), Pal.SCALE_DEEP)
	for side: float in [-1.0, 1.0]:
		b.ellipse(xf * Vector2(side * half, 0.0), top * 0.5, top, Pal.SCALE_DEEP)
	var pip := maxf(2.0, _cup * 0.035)
	for x in range(-REACH, REACH + 1):
		if x == 0:
			continue
		var n := absi(x)
		for k in n:
			var px := x * _cup + (k - (n - 1) * 0.5) * pip * 2.6
			b.disc(xf * Vector2(px, top * 0.05), pip, Pal.SCALE_DARK.lerp(Pal.SCALE_DEEP, 0.2))
	# the level
	var vy := -(top + VIAL_UP * _cup)
	var vw := VIAL_W * _cup
	var vh := VIAL_H * _cup
	b.fan(_xf_pts(xf, Face.Builder.round_rect(Vector2(-_cup * 0.05, vy), Vector2(_cup * 0.1, -vy - top * 0.5), _cup * 0.04)), Pal.SCALE_DEEP)
	if glow > 0.0 or (_torque() == 0 and _on() > 0):
		Scenery.soft_disc(b, xf * Vector2(0.0, vy), vh * 2.4, vh * 1.5, Color(Pal.SUN, 0.5 * maxf(glow, 0.6)))
	b.fan(_xf_pts(xf, Face.Builder.round_rect(Vector2(-vw * 0.5 - 5.0, vy - vh * 0.5 - 5.0), Vector2(vw + 10.0, vh + 10.0), vh * 0.5 + 5.0)), Pal.BRASS)
	b.fan(_xf_pts(xf, Face.Builder.round_rect(Vector2(-vw * 0.5, vy - vh * 0.5), Vector2(vw, vh), vh * 0.5)), Pal.DEW.lerp(Pal.LEAF_LIGHT, 0.35))
	var tick := (vw * 0.5 - vh * 0.5) / (TICKS + 0.6)
	for k in range(-TICKS, TICKS + 1):
		var tall := 0.62 if k == 0 else (0.42 if absi(k) == TICKS else 0.3)
		b.fan(_xf_pts(xf, Face.Builder.round_rect(Vector2(k * tick - 1.5, vy + vh * 0.5 - vh * tall), Vector2(3.0, vh * tall), 1.5)),
			Color(Pal.TEXT, 0.6 if k == 0 else 0.35))
	var reading := clampf(tan(_a) / TICK, -TICKS - 0.6, TICKS + 0.6)
	b.ellipse(xf * Vector2(-reading * tick, vy), vh * 0.62, vh * 0.34, Color(Pal.PAPER, 0.95))
	if glow > 0.0 or (_torque() == 0 and _on() > 0):
		b.stroke(Face.Builder.ring(xf * Vector2(0.0, vy), vh * 0.78, vh * 0.48), 3.0, Pal.GOOD, true)
	# the hub
	b.disc(_pivot, _cup * 0.15, Pal.SCALE_DARK)
	b.disc(_pivot, _cup * 0.075, Pal.BRASS)
	if glow > 0.0 and not Motion.reduce:
		var u := _clock - _gold_t
		for k in 5:
			var ang := TAU * k / 5.0 + u * 1.5
			var d := _cup * (0.6 + 1.6 * clampf(u / 0.8, 0.0, 1.0))
			Rewards.star(b, xf * Vector2(0.0, vy) + Vector2(cos(ang), sin(ang) * 0.6) * d, _cup * 0.1 * clampf(1.6 - u, 0.0, 1.0), Pal.SUN, ang)

func _on() -> int:
	return _fruit.filter(func(f: Dictionary) -> bool: return f.at != BASKET and f.fly.is_empty()).size()

## Insane's bales under the ends, a red coil in each; the one the beam
## bumped squashes and springs.
func _bales(b: Face.Builder, half: float, top: float) -> void:
	var u := half - _cup * 0.35
	var bale_top := _pivot.y + u * sin(A_MAX) + top * cos(A_MAX) + 2.0
	var h := _ground + _cup * 0.08 - bale_top
	var bw := _cup * 0.9
	for side: float in [-1.0, 1.0]:
		var foot := Vector2(_pivot.x + side * u * cos(A_MAX), _ground + _cup * 0.08)
		var sy := 1.0
		var since := _clock - _boing_t
		if _boing_t >= 0.0 and signf(_a) == side and since < 0.7:
			sy = 1.0 - 0.28 * sin(since * 22.0) * exp(-since * 5.5)
		var hh := h * sy
		b.fan(Face.Builder.round_rect(foot + Vector2(-bw * 0.5, -hh), Vector2(bw, hh), _cup * 0.12), Pal.STRAW)
		b.fan(Face.Builder.round_rect(foot + Vector2(-bw * 0.5, -hh), Vector2(bw, hh * 0.3), _cup * 0.1), Pal.STRAW.lerp(Pal.PAPER, 0.35))
		var pts := PackedVector2Array()
		var y0 := -hh + hh * 0.36
		var y1 := -hh * 0.12
		for i in 9:
			pts.append(foot + Vector2((-1.0 if i % 2 == 0 else 1.0) * bw * 0.3, lerpf(y0, y1, i / 8.0)))
		b.stroke(pts, maxf(4.0, _cup * 0.08), Pal.BERRY_DEEP)

## The sky corner the sun sets in, for the SUN page: the sun sinks a step a
## move and warms as it goes.
func _sky(b: Face.Builder) -> void:
	var k := 1.0 - _sun_shown / 3.0
	var c := Vector2(_cup * 0.75, _cup * (0.7 + 1.5 * k))
	var col := Pal.SUN.lerp(Pal.PUMPKIN, k)
	Scenery.soft_disc(b, c, _cup * 0.75, _cup * 0.75, Color(col, 0.3))
	b.disc(c, _cup * 0.42, col)
	b.disc(c + Vector2(-_cup * 0.12, -_cup * 0.12), _cup * 0.14, Color(Pal.PAPER, 0.5))

func _pill_centre() -> Vector2:
	return Vector2(_cup * 0.75, _ground + _cup * 0.75)

func _pill(b: Face.Builder) -> void:
	var c := _pill_centre()
	var w := _cup * 1.0
	var h := _cup * 0.52
	b.fan(Face.Builder.round_rect(c - Vector2(w, h) * 0.5, Vector2(w, h), h * 0.5), Pal.PAPER)
	b.stroke(Face.Builder.round_rect(c - Vector2(w, h) * 0.5, Vector2(w, h), h * 0.5), 2.5, Color(Pal.TEXT, 0.25), true)
	b.disc(c + Vector2(-w * 0.22, 0.0), h * 0.28, Pal.SUN)

## A fingertip: a pale round with a soft shadow, pointing up at what it holds.
func _finger(b: Face.Builder, at: Vector2) -> void:
	var r := _cup * 0.2
	Scenery.soft_disc(b, at + Vector2(3.0, 5.0), r * 1.1, r * 1.1, Color(Pal.TEXT, 0.18))
	b.disc(at, r, Pal.PAPER)
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
