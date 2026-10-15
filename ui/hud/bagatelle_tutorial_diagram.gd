extends Control

## One page of Bagatelle's tutorial: the board played by the game itself.
## The page holds the game's own board (arcade/bagatelle_board.gd) on a sim
## of its own (arcade/bagatelle_sim.gd), never saved, and a finger that
## presses as a player's would. `lesson` picks the page (set before it
## enters the tree):
##
## - DROP: three taps across the top; the marbles fall through the pins and
##   the cups pay.
## - CUPS: the dropper left to itself, a cup one marble short of its level.
## - JAR: twenty-two clay marbles; the finger taps the jar, twenty merge
##   into two glass, and glass falls worth twenty clay.
## - STARS: a gold pin carried to the middle; every marble that touches it
##   wears its ring and pays half again.

const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Sim = preload("res://arcade/bagatelle_sim.gd")
const Art = preload("res://arcade/bagatelle_art.gd")
const Board = preload("res://arcade/bagatelle_board.gd")

enum Lesson { DROP, CUPS, JAR, STARS }

## Each lesson's finger: [second, target, down from here on]. A target is a
## point of the field ([x, y] in field units) or "jar".
const SCRIPTS := {
	Lesson.DROP: [[0.0, [500, 1100], false], [0.7, [420, 40], false], [0.8, [420, 40], true], [0.95, [420, 40], false],
		[1.6, [520, 40], false], [1.7, [520, 40], true], [1.85, [520, 40], false], [2.5, [600, 40], false], [2.6, [600, 40], true], [2.75, [600, 40], false], [3.6, [500, 1100], false]],
	Lesson.CUPS: [[0.0, [500, 1100], false]],
	Lesson.JAR: [[0.0, [500, 1100], false], [0.8, "jar", false], [1.0, "jar", true], [1.2, "jar", false], [2.2, [500, 40], false], [2.3, [500, 40], true], [2.45, [500, 40], false],
		[3.1, [480, 40], false], [3.2, [480, 40], true], [3.35, [480, 40], false], [4.2, [500, 1100], false]],
	Lesson.STARS: [[0.0, [500, 1100], false], [0.7, [269, 390], false], [0.9, [269, 390], true], [1.6, [500, 390], true], [1.75, [500, 390], false],
		[2.3, [500, 40], false], [2.4, [500, 40], true], [2.55, [500, 40], false], [2.9, [500, 40], true], [3.05, [500, 40], false], [3.4, [500, 40], true], [3.55, [500, 40], false], [4.4, [500, 1100], false]],
}
const LENGTHS := {Lesson.DROP: 7.0, Lesson.CUPS: 9.0, Lesson.JAR: 8.0, Lesson.STARS: 8.0}

var lesson: int = Lesson.DROP

var _board: Control
var _over_l: Control
var _sim: RefCounted
var _begun := false
var _t := 0.0
var _down := false
var _on_jar := false
var _finger := Vector2.INF
var _font: Font
var _said := ""
var _said_at := -10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = CozyTheme.display(700)
	_board = Board.new()
	_board.interactive = false
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.font = _font
	add_child(_board)
	_over_l = Control.new()
	_over_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_l.draw.connect(_draw_over)
	add_child(_over_l)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_board.position = Vector2.ZERO
	_board.size = size
	# the page is wider than tall: the board is laid as wide as the page and
	# the page looks at the part its lesson is about (the cups' page the
	# foot, the others the top)
	var side := size.x * 0.96
	var top := (size.y - side - 6.0) if lesson == Lesson.CUPS else -side * 0.02
	_board.set_view(Rect2(Vector2((size.x - side) * 0.5, top), Vector2(side, side)))
	_over_l.size = size
	if not _begun:
		_reset()

func _reset() -> void:
	_begun = true
	_t = 0.0
	_down = false
	_said = ""
	_said_at = -10.0
	_sim = Sim.new(11)
	match lesson:
		Lesson.DROP:
			_sim.owned[0] = 3
			_sim.jar[0] = 3
		Lesson.CUPS:
			_sim.owned[0] = 30
			_sim.jar[0] = 30
			_sim.up.auto = 30
			for c in Sim.CUPS:
				_sim.cup_lv[c] = 4
				_sim.cup_pts[c] = Sim.need(4) - 1
		Lesson.JAR:
			_sim.owned[0] = 22
			_sim.jar[0] = 22
		Lesson.STARS:
			_sim.owned[0] = 12
			_sim.jar[0] = 12
			_sim.shop.plus = 1
			_sim.bonus = {Sim.pin_near(Vector2(269, 390), Sim.DX): "plus"}
	_sim.events.clear()
	_board.sim = _sim
	_board.let_go()

func _target(id) -> Vector2:
	if id is String and id == "jar":
		return _board.jar_rect().get_center()
	return _board.screen_of(Vector2(float(id[0]), float(id[1])))

func _process(delta: float) -> void:
	if _sim == null or not is_visible_in_tree():
		return
	_t += delta
	if _t >= float(LENGTHS[lesson]):
		_reset()
		return
	var script: Array = SCRIPTS[lesson]
	var at := 0
	while at + 1 < script.size() and float(script[at + 1][0]) <= _t:
		at += 1
	var from := _target(script[at][1])
	var pos := from
	if at + 1 < script.size():
		var u := clampf((_t - float(script[at][0])) / maxf(0.01, float(script[at + 1][0]) - float(script[at][0])), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		pos = from.lerp(_target(script[at + 1][1]), u)
	var down := bool(script[at][2])
	if down and not _down:
		_on_jar = script[at][1] is String
		if _on_jar:
			# the jar's card, as the page shows it: twenty clay into two glass
			_sim.merge(0, 2)
			_said = tr("BG_TUT_MERGED")
			_said_at = _t
		else:
			_board.press(pos)
	elif down:
		if not _on_jar:
			_board.drag(pos + Vector2(0, 40.0))
	elif _down and not _on_jar:
		# the board sets a carried pin where it is drawn, over the finger
		_board.release(pos + Vector2(0, 40.0))
	_down = down
	_finger = pos if script.size() > 1 else Vector2.INF
	_sim.step(delta)
	for ev: Dictionary in _sim.events:
		_board.play(ev)
		if String(ev.type) == "bonus":
			_said = "+50%"
			_said_at = _t
		elif String(ev.type) == "cup":
			_said = tr("BG_CUP_LV") % int(ev.level)
			_said_at = _t
	_sim.events.clear()
	_sim.take_pins()
	_board.tick(delta)
	_over_l.queue_redraw()

func _draw_over() -> void:
	if _said != "" and _t - _said_at < 1.6:
		var fs := 40
		var pop := 1.0 if Motion.reduce else Motion.bump_scale(_t - _said_at, 0.2, 0.22)
		_over_l.draw_set_transform(Vector2(size.x * 0.5, size.y * 0.3), 0.0, Vector2(pop, pop))
		_over_l.draw_string_outline(_font, Vector2(-size.x * 0.5, 0), _said, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 10, Art.VELVET_LOW)
		_over_l.draw_string(_font, Vector2(-size.x * 0.5, 0), _said, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("fff4c2"))
		_over_l.draw_set_transform(Vector2.ZERO)
	if _finger != Vector2.INF:
		var r := 26.0
		_over_l.draw_circle(_finger + Vector2(0, 4.0), r, Color(0, 0, 0, 0.25), true, -1.0, true)
		_over_l.draw_circle(_finger, r, Color(1, 1, 1, 0.92), true, -1.0, true)
		_over_l.draw_circle(_finger, r * 0.62, Color(Pal.SUN, 0.9 if _down else 0.5), true, -1.0, true)
