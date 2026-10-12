extends Control

## One page of Griddle's tutorial: the stand played by the game itself. The
## page holds the game's own world (arcade/griddle_place.gd) on a sim of
## its own (arcade/griddle_sim.gd), never saved, drawn at the screen's size
## and scaled to the page, and a finger that goes from thing to thing along
## the page's script and presses as a player's would. `lesson` picks the
## page (set before it enters the tree):
##
## - SERVE: the counter; three toasties sold one by one to the queue.
## - RUSH: a full pass and a long queue sold in one go: the rush's count and
##   sum lettered, the queue emptied.
## - FIELDS: ripe lots cut by the finger while the cart takes another.
## - YARD: full cows' milk taken, and a poorly cow tucked up.
## - OFFICE: the signboard turned up a notch, a jar that fills, a favour.
## - ROUND: the counter left to itself: the cook and the till at their own
##   pace, the queue growing.

const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/griddle_sim.gd")
const Art = preload("res://arcade/griddle_art.gd")
const Place = preload("res://arcade/griddle_place.gd")

enum Lesson { SERVE, RUSH, FIELDS, YARD, OFFICE, ROUND }

## The place is laid out as on a phone, this wide and this tall, and the
## page shows a window of it this tall, from `TOP` of the place down.
const WIDE := 1080.0
const TALL := 1250.0
const SEEN := 880.0
const TOP := {"counter": 300.0, "fields": 0.0, "yard": 0.0, "office": 0.0}
const PLACE_OF := {Lesson.SERVE: "counter", Lesson.RUSH: "counter", Lesson.FIELDS: "fields", Lesson.YARD: "yard", Lesson.OFFICE: "office", Lesson.ROUND: "counter"}
## Each lesson's script: [second, target, down from here on], and its length.
const SCRIPTS := {
	Lesson.SERVE: [[0.0, "rest", false], [0.9, "queue", false], [1.1, "queue", true], [1.3, "queue", false], [4.6, "queue", true], [4.8, "queue", false], [8.2, "queue", true], [8.4, "queue", false], [9.2, "rest", false]],
	Lesson.RUSH: [[0.0, "rest", false], [0.8, "queue", false], [1.0, "queue", true], [1.15, "queue", false], [1.5, "queue", true], [1.65, "queue", false], [2.0, "queue", true], [2.15, "queue", false],
		[2.5, "queue", true], [2.65, "queue", false], [3.0, "queue", true], [3.15, "queue", false], [3.5, "queue", true], [3.65, "queue", false], [4.6, "rest", false]],
	Lesson.FIELDS: [[0.0, "rest", false], [0.9, "lot1", false], [1.1, "lot1", true], [1.3, "lot1", false], [2.1, "lot2", false], [2.3, "lot2", true], [2.5, "lot2", false],
		[3.3, "lot4", false], [3.5, "lot4", true], [3.7, "lot4", false], [4.6, "rest", false]],
	Lesson.YARD: [[0.0, "rest", false], [0.9, "cow0", false], [1.1, "cow0", true], [1.3, "cow0", false], [2.1, "cow2", false], [2.3, "cow2", true], [2.5, "cow2", false],
		[3.4, "cow1", false], [3.6, "cow1", true], [3.8, "cow1", false], [4.8, "rest", false]],
	Lesson.OFFICE: [[0.0, "rest", false], [0.9, "notch2", false], [1.1, "notch2", true], [1.3, "notch2", false], [4.0, "fav3", false], [4.2, "fav3", true], [4.4, "fav3", false],
		[5.2, "notch1", false], [5.4, "notch1", true], [5.6, "notch1", false], [6.4, "rest", false]],
	Lesson.ROUND: [[0.0, "rest", false]],
}
const LENGTHS := {Lesson.SERVE: 10.4, Lesson.RUSH: 7.4, Lesson.FIELDS: 6.0, Lesson.YARD: 6.2, Lesson.OFFICE: 7.6, Lesson.ROUND: 12.0}

var lesson: int = Lesson.SERVE

var _world: Control
var _over_l: Control
var _sim: RefCounted
var _begun := false
var _t := 0.0
var _down := false
var _font: Font
var _sum := 0
var _links := 0
var _sum_at := -10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = CozyTheme.display(700)
	_world = Place.new()
	_world.playable = false
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.font = _font
	add_child(_world)
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
	var k := size.y / SEEN
	_world.position = Vector2.ZERO
	_world.scale = Vector2(k, k)
	_world.size = size / k
	_world.area = Rect2((size.x / k - WIDE) * 0.5 + 30.0, 16.0 - float(TOP[PLACE_OF[lesson]]), WIDE - 60.0, TALL)
	_world.fly_to = Vector2(size.x / k * 0.5, 30.0)
	_over_l.size = size
	if not _begun:
		_reset()

func _reset() -> void:
	_begun = true
	_t = 0.0
	_down = false
	_sum = 0
	_links = 0
	_sum_at = -10.0
	_sim = Sim.new(5)
	_sim.arrive = -1000.0
	match lesson:
		Lesson.SERVE:
			_sim.ready = 3
			_sim.queue = [0.0, 0.0, 0.0]
			_sim.loaves = 0
			_sim.lots[0].open = false
		Lesson.RUSH:
			_sim.tills = 2
			_sim.grills = 2
			_sim.ready = 6
			_sim.queue = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
			_sim.loaves = 0
			_sim.lots[0].open = false
		Lesson.FIELDS:
			_sim.cows.clear()
			_sim.cart_t = -2.6
			for i in 6:
				_sim.lots[i].open = true
				_sim.lots[i].crop = Sim.WHEAT if i % 2 == 0 else Sim.CLOVER
				_sim.lots[i].ripe = i in [0, 1, 2, 4]
				_sim.lots[i].t = 5.0
			_sim.lots[5].crop = Sim.FALLOW
			_sim.lots[5].soil = 40.0
			_sim.lots[3].soil = 45.0
		Lesson.YARD:
			_sim.lots[0].open = false
			_sim.stalls = 3
			_sim.pail_t = -100.0
			_sim.feed = 20
			for n in 2:
				_sim.cows.append(_sim._cow())
			_sim.cows[0].full = true
			_sim.cows[0].milk = 1.0
			_sim.cows[2].full = true
			_sim.cows[2].milk = 1.0
			_sim.cows[1].poorly = true
		Lesson.OFFICE:
			_sim.coins = 500
			_sim.mood.town = 52.0
			_sim.mood.garden = 12.0
			_sim.mood.crew = 30.0
			_sim.today = 84
			_sim.yesterday = 310
			_sim.served = 96
			_sim.best_rush = 7
		Lesson.ROUND:
			_sim.arrive = 0.5
			_sim.tills = 2
			_sim.loaves = 20
			_sim.cheese = 20
			_sim.ready = 2
			_sim.queue = [0.0, 3.0]
			_sim.lv.sign = 12
	_sim.events.clear()
	_world.sim = _sim
	_world.show_place(PLACE_OF[lesson])

func _target(id: String) -> Vector2:
	if id == "queue":
		return _world.queue_at(0) + Vector2(0, -60.0)
	if id.begins_with("lot"):
		return _world.lot_mid(int(id.substr(3)))
	if id.begins_with("cow"):
		return _world.cow_foot(int(id.substr(3))) - Vector2(0, _world.cow_size() * 0.4)
	if id.begins_with("notch"):
		return _world.notch_at(int(id.substr(5)))
	if id.begins_with("fav"):
		return _world.favour_rect(int(id.substr(3))).get_center()
	return Vector2(_world.area.end.x - 90.0, SEEN - 90.0)

func _process(delta: float) -> void:
	if _sim == null or not is_visible_in_tree():
		return
	_t += delta
	if _t >= float(LENGTHS[lesson]):
		_reset()
		return
	var script: Array = SCRIPTS[lesson]
	# where the finger is between the two steps the clock stands between
	var at := 0
	while at + 1 < script.size() and float(script[at + 1][0]) <= _t:
		at += 1
	var from := _target(String(script[at][1]))
	var pos := from
	if at + 1 < script.size():
		var u := clampf((_t - float(script[at][0])) / maxf(0.01, float(script[at + 1][0]) - float(script[at][0])), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		pos = from.lerp(_target(String(script[at + 1][1])), u)
	var down := bool(script[at][2])
	if down and not _down:
		_world.press(pos)
	_down = down
	_world.finger = pos if script.size() > 1 else Vector2.INF
	_world.finger_down = down
	# the office's page shows a jar filling: the town minds the loud board
	_sim.step(delta * (6.0 if lesson == Lesson.OFFICE else (1.6 if lesson == Lesson.ROUND else 1.0)))
	for ev: Dictionary in _sim.events:
		_world.play(ev)
		if String(ev.type) == "serve" and bool(ev.hand):
			_links = int(ev.n)
			_sum = int(_sim.rush_sum)
			_sum_at = _t
	_sim.events.clear()
	_world.tick(delta)
	_over_l.queue_redraw()

## The rush as it is lettered over the game: its links and its sum.
func _draw_over() -> void:
	if _links < 2 or _t - _sum_at > 2.4:
		return
	var fs := 34
	var pop := 1.0 if Motion.reduce else Motion.bump_scale(_t - _sum_at, 0.2, 0.22)
	var text := "×%d   +%d" % [_links, _sum]
	_over_l.draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5), 0.0, Vector2(pop, pop))
	_over_l.draw_string_outline(_font, Vector2(-size.x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 10, Art.INK)
	_over_l.draw_string(_font, Vector2(-size.x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("fff4c2"))
	_over_l.draw_set_transform(Vector2.ZERO)
