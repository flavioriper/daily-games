extends Control

## One page of the Grove's tutorial: a small pond and land drawn with the
## game's own art (valley/grove_art.gd) and, where something is chopped,
## played by the game's own sim (valley/grove_sim.gd) with a finger that
## never leaves a tree. `lesson` picks the page (set before it enters the
## tree):
##
## - CHOP: the circle on a sapling, a number a chop, and the tree comes down.
## - GIFTS: what a felled tree leaves: a log for the shared wood, a spark for
##   the grove's own energy.
## - WAIT: an empty land filling up by itself, a tree at a time.
##
## Under reduce motion each page stands still at its telling moment.

const Sim = preload("res://valley/grove_sim.gd")
const Art = preload("res://valley/grove_art.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

enum Lesson { CHOP, GIFTS, WAIT }

## Seconds a page plays before it starts over, and where a still page stands.
const LENGTH := {Lesson.CHOP: 4.2, Lesson.GIFTS: 3.0, Lesson.WAIT: 6.0}
const STILL := {Lesson.CHOP: 1.2, Lesson.GIFTS: 1.1, Lesson.WAIT: 5.0}
## Where the lesson's trees stand, in land units.
const SPOTS := [Vector2(250, 420), Vector2(430, 560), Vector2(590, 380), Vector2(330, 660), Vector2(560, 640)]
const PLATE := Vector2(250, 92)

var lesson: int = Lesson.CHOP

var _sim: RefCounted
var _t := 0.0
var _ground: ArrayMesh
var _u := 1.0
var _origin := Vector2.ZERO
var _nums: Array = []
var _fell_at := -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_start()
	_layout()
	if Motion.reduce:
		_advance(float(STILL[lesson]))
		set_process(false)

func _start() -> void:
	_t = 0.0
	_nums.clear()
	_fell_at = -1.0
	_sim = Sim.new(11)
	_sim.trees.clear()
	_sim.events.clear()
	var n := 0 if lesson == Lesson.WAIT else (1 if lesson == Lesson.GIFTS else 3)
	for i in n:
		_sim.trees.append({"id": i + 1, "tier": 0, "pos": SPOTS[i], "hp": Sim.hp_of(0), "born": -Sim.GROW})

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var room := size - Vector2(0.0, PLATE.y + 16.0 if lesson == Lesson.GIFTS else 0.0)
	_u = minf((room.x - 40.0) / Sim.LAND.x, (room.y - 60.0) / Sim.LAND.y)
	_origin = Vector2((size.x - Sim.LAND.x * _u) * 0.5, size.y - room.y + 14.0)
	_ground = Art.ground(Vector2(size.x, room.y), Rect2(_origin - Vector2(0.0, size.y - room.y), Sim.LAND * _u))
	queue_redraw()

func _process(delta: float) -> void:
	_advance(delta)
	if _t >= float(LENGTH[lesson]):
		_start()
	queue_redraw()

func _advance(delta: float) -> void:
	var left := delta
	while left > 0.0:
		var dt := minf(left, 1.0 / 30.0)
		left -= dt
		_t += dt
		for n: Dictionary in _nums:
			n.t += dt
		match lesson:
			Lesson.CHOP:
				_sim.step(dt, _t > 0.5 and not _sim.trees.is_empty() and _fell_at < 0.0, _finger())
			Lesson.GIFTS:
				_sim.step(dt, _t > 0.3 and _fell_at < 0.0, _finger())
			Lesson.WAIT:
				if _sim.trees.size() < SPOTS.size() and _t >= 0.5 + _sim.trees.size() * 1.0:
					_sim.trees.append({"id": _sim.trees.size() + 1, "tier": 0, "pos": SPOTS[_sim.trees.size()],
						"hp": Sim.hp_of(0), "born": _sim.clock})
				_sim.clock += dt
		for e: Dictionary in _sim.events:
			if e.kind == "hit":
				_nums.append({"at": e.tree.pos + Vector2(0.0, -70.0), "text": str(e.amount), "t": 0.0})
			elif e.kind == "fell":
				_fell_at = _t
		_sim.events.clear()
		_nums = _nums.filter(func(n: Dictionary) -> bool: return n.t < 0.7)

## The circle's centre, in land units: on the first tree's crown.
func _finger() -> Vector2:
	return (SPOTS[0] as Vector2) + Vector2(0.0, -Sim.RADIUS[0])

func _px(p: Vector2) -> Vector2:
	return _origin + p * _u

func _draw() -> void:
	if _ground == null:
		return
	var top := PLATE.y + 16.0 if lesson == Lesson.GIFTS else 0.0
	draw_set_transform(Vector2(0.0, top))
	draw_mesh(_ground, null)
	draw_set_transform(Vector2.ZERO)
	for tree: Dictionary in _sim.trees:
		var grown := clampf((_sim.clock - float(tree.born)) / Sim.GROW, 0.0, 1.0)
		var s := (0.15 + 0.85 * Motion.back_out(grown)) * _u * 1.5
		draw_mesh(Art.tree(0), null, Transform2D(0.0, Vector2(s, s), 0.0, _px(tree.pos)))
		if int(tree.hp) < Sim.hp_of(0):
			var w := 70.0 * _u
			var bar := Rect2(_px(tree.pos) + Vector2(-w * 0.5, 12.0 * _u), Vector2(w, 12.0 * _u))
			draw_rect(bar, Color(0.23, 0.19, 0.16, 0.35))
			draw_rect(Rect2(bar.position, Vector2(w * float(tree.hp) / Sim.hp_of(0), bar.size.y)), Color("fff6e6"))
	var font := get_theme_font("font", "SheetTitle")
	if lesson != Lesson.WAIT and _t > 0.3 and _fell_at < 0.0:
		var c := _px(_finger())
		var r: float = _sim.reach() * _u
		draw_circle(c, r, Color(1.0, 1.0, 1.0, 0.28), true, -1.0, true)
		draw_arc(c, r, 0.0, TAU, 64, Color(0.23, 0.19, 0.16, 0.75), 4.0, true)
	for n: Dictionary in _nums:
		var k: float = n.t / 0.7
		var fs := int(maxf(26.0, 44.0 * _u))
		var at := _px(n.at) + Vector2(-fs * 0.25, -k * 40.0 * _u)
		draw_string_outline(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.23, 0.19, 0.16, 0.7 * (1.0 - k)))
		draw_string(font, at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 1.0, 1.0, 1.0 - k))
	if lesson == Lesson.GIFTS:
		_draw_gifts(font)

## The two plates over the pond, and the log and the spark on their way.
func _draw_gifts(font: Font) -> void:
	var gap := 20.0
	var left := Rect2(Vector2(size.x * 0.5 - PLATE.x - gap * 0.5, 0.0), PLATE)
	var right := Rect2(Vector2(size.x * 0.5 + gap * 0.5, 0.0), PLATE)
	var box := CozyTheme.lifted(Color("fcf7ef"), 30, 8)
	var body := get_theme_font("font", "CardBlurb")
	for row: Array in [[left, "energy", "GROVE_ENERGY"], [right, "wood", "GROVE_WOOD"]]:
		var r: Rect2 = row[0]
		draw_style_box(box, r)
		draw_mesh(Art.icon(row[1]), null, Transform2D(-0.3 if row[1] == "wood" else 0.0, Vector2(0.8, 0.8), 0.0, r.position + Vector2(52.0, r.size.y * 0.5)))
		draw_string(body, r.position + Vector2(98.0, r.size.y * 0.5 + 10.0), tr(row[2]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 106.0, 28, Pal.TEXT)
	if _fell_at < 0.0:
		return
	var k := clampf((_t - _fell_at) / 0.9, 0.0, 1.0)
	var from := _px(SPOTS[0]) + Vector2(0.0, -40.0)
	for row: Array in [[left, Art.spark(), 0.9], [right, Art.log_mesh(), 0.8]]:
		var to: Vector2 = (row[0] as Rect2).position + Vector2(52.0, PLATE.y * 0.5)
		var at := from.lerp(to, k * k) + Vector2(0.0, -sin(k * PI) * 60.0)
		if k < 1.0:
			draw_mesh(row[1], null, Transform2D(k * 3.0, Vector2(row[2], row[2]), 0.0, at))
