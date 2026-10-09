extends Control

## One page of Dominoes' tutorial, played by the table itself
## (versus/dominoes_board.gd, deaf to the player's own hands and silent), and
## a finger that does to it what a thumb does: taps a tile, a place, the
## boneyard. `lesson` picks the page (set before it enters the tree):
##
## - MATCH: three tiles laid where their numbers match, the moon answering.
## - ENDS: a tile that fits both ends picked up and a place chosen, then a
##   double laid across.
## - DRAW: nothing fits, two tiles drawn, the second laid.
## - OUT: the last tile laid, and the other hand turned up to be counted.
## - BAR: the bulb rings a tile and its place, and the tile goes there.
##
## A page is a hand set by hand (Rules.lay) and a list of [seconds, what,
## ...], and it starts over when it ends. Under reduce motion it stands on
## the table as the lesson leaves it.

const Rules = preload("res://versus/dominoes_rules.gd")
const Board = preload("res://versus/dominoes_board.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { MATCH, ENDS, DRAW, OUT, BAR }

const FINGER_R := 26.0
const FINGER_ALPHA := 0.2
## How long before a tap the finger sets off for it, and how long it takes.
const LEAD := 0.75
const TRAVEL := 0.55

var lesson: int = Lesson.MATCH
var _board: Control
var _over: Control
var _rules: RefCounted
var _script: Array = []
var _len := 6.0
var _next := 0
var _t := 0.0
## The finger: where it came from and is going, when it set off, the script
## entry it is on its way to, whether it shows, and when it last went down.
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _go_at := 0.0
var _aimed := -1
var _shown := false
var _down_at := -10.0

static func T(a: int, b: int) -> int:
	return Rules.id(a, b)

## The first `n` tiles that are none of `used`, for a boneyard nobody draws
## from.
static func _rest(used: Array, n: int) -> Array:
	var out := []
	for t in Rules.TILES:
		if out.size() < n and not used.has(t):
			out.append(t)
	return out

## A lesson: the sun's hand, the moon's, the tiles already on the line (as
## moves from an empty one), the boneyard's last tiles (the last is drawn
## first), its length and its script of [seconds, what, ...]. `tap` taps one
## of the sun's tiles: it is laid if it fits one end, picked up if it fits
## both; `end` taps the place a move would put the picked tile; `draw` taps
## the boneyard; `bot` is the moon's move; `hint` is the bulb; `hide` takes
## the finger away.
static func script_of(the_lesson: int) -> Dictionary:
	match the_lesson:
		Lesson.MATCH:
			return {"len": 10.5, "sun": [T(4, 2), T(5, 5), T(3, 1), T(6, 0)], "moon": [T(2, 5), T(6, 3), T(1, 1), T(0, 0)],
				"line": [T(6, 4) * 2], "draws": [], "script": [
				[1.4, "tap", T(4, 2)], [3.2, "bot", T(2, 5) * 2], [4.9, "tap", T(5, 5)],
				[6.6, "bot", T(6, 3) * 2 + 1], [8.3, "tap", T(3, 1)], [8.8, "hide"]]}
		Lesson.ENDS:
			return {"len": 10.5, "sun": [T(5, 3), T(3, 3), T(2, 0)], "moon": [T(3, 1), T(4, 4), T(6, 1)],
				"line": [T(3, 6) * 2, T(6, 5) * 2 + 1], "draws": [], "script": [
				[1.4, "tap", T(5, 3)], [3.2, "end", T(5, 3) * 2 + 1], [5.2, "bot", T(3, 1) * 2],
				[7.0, "tap", T(3, 3)], [7.6, "hide"]]}
		Lesson.DRAW:
			return {"len": 9.5, "sun": [T(4, 2), T(3, 1)], "moon": [T(5, 5), T(4, 1), T(3, 0)],
				"line": [T(6, 6) * 2], "draws": [T(6, 2), T(5, 0)], "script": [
				[1.6, "draw"], [3.4, "draw"], [5.4, "tap", T(6, 2)], [6.0, "hide"]]}
		Lesson.OUT:
			return {"len": 8.0, "sun": [T(5, 1)], "moon": [T(4, 3), T(3, 0)],
				"line": [T(2, 4) * 2, T(4, 4) * 2 + 1, T(2, 6) * 2, T(4, 5) * 2 + 1, T(6, 6) * 2], "draws": [], "script": [
				[1.6, "tap", T(5, 1)], [2.2, "hide"]]}
	return {"len": 9.0, "sun": [T(6, 4), T(2, 1), T(5, 3)], "moon": [T(4, 4), T(3, 0), T(1, 1)],
		"line": [T(6, 6) * 2, T(6, 5) * 2 + 1], "draws": [], "script": [
		[1.2, "hint", T(6, 4) * 2], [3.6, "tap", T(6, 4)], [4.2, "hide"], [5.8, "bot", T(4, 4) * 2]]}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = Board.new()
	_board.deaf = true
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_finger)
	add_child(_over)
	_begin()
	if Motion.reduce:
		# The table as the lesson leaves it: every move of the script made.
		for e: Array in _script:
			_do(e, true)
		_board.setup(_rules, Rules.FIRST)
		_board.reveal(_rules.hand_over)
		set_process(false)

## The page as it opens: the hand as it was set, and the script from its top.
func _begin() -> void:
	var d := script_of(lesson)
	_script = d.script
	_len = d.len
	_next = 0
	_t = 0.0
	_shown = false
	_aimed = -1
	var used: Array = d.sun + d.moon + d.draws
	for m: int in d.line:
		used.append(m >> 1)
	_rules = Rules.new()
	_rules.lay(d.sun, d.moon, _rest(used, 9) + d.draws, d.line)
	_board.setup(_rules, Rules.FIRST)
	_board.interactive = true
	_board.set_must_draw(_rules.can(Rules.DRAW))

func _process(delta: float) -> void:
	_t += delta
	if _t >= _len:
		_begin()
	# the finger sets off for the tap that is coming
	for i in range(_next, _script.size()):
		var e: Array = _script[i]
		if String(e[1]) in ["tap", "end", "draw"]:
			if i != _aimed and _t >= float(e[0]) - LEAD:
				_aimed = i
				var at := _point_of(e)
				_from = _finger() if _shown else at + Vector2(0.0, 60.0)
				_to = at
				_go_at = _t
				_shown = true
			break
	while _next < _script.size() and _t >= float(_script[_next][0]):
		_do(_script[_next], false)
		_next += 1
	_over.queue_redraw()

## Where a tap lands: on a tile, on a place of the line, on the boneyard.
func _point_of(e: Array) -> Vector2:
	match String(e[1]):
		"tap":
			return _board.tile_point(e[2])
		"end":
			return _board.slot_point(e[2])
	return _board.stock_point()

func _do(e: Array, quiet: bool) -> void:
	var what := String(e[1])
	var move := -1
	match what:
		"tap":
			var tile: int = e[2]
			var a: bool = _rules.fits(tile, 0)
			var b: bool = _rules.fits(tile, 1)
			if a and b and _rules.ends[0] != _rules.ends[1]:
				if not quiet:
					_board._picked = tile
					_board._place_all(false)
					_board._busy(0.4)
			else:
				move = tile * 2 + (0 if a else 1)
		"end", "bot":
			move = e[2]
		"draw":
			move = Rules.DRAW
		"hint":
			if not quiet:
				_board.set_hint(e[2])
		"hide":
			_shown = false
	if what in ["tap", "end", "draw"]:
		_down_at = _t
	if move < 0 or not _rules.make(move):
		return
	if quiet:
		return
	_board.sync()
	if _rules.hand_over:
		_board.interactive = false
		_board.reveal(true)
	else:
		_board.interactive = _rules.turn == Rules.FIRST
		_board.set_must_draw(_rules.turn == Rules.FIRST and _rules.can(Rules.DRAW))

func _finger() -> Vector2:
	var u := clampf((_t - _go_at) / TRAVEL, 0.0, 1.0)
	return _from.lerp(_to, u * u * (3.0 - 2.0 * u))

func _draw_finger() -> void:
	if not _shown:
		return
	var down := _t - _down_at < 0.22
	var at := _finger()
	var r := FINGER_R * (0.86 if down else 1.0)
	_over.draw_circle(at, r, Color(Pal.TEXT, FINGER_ALPHA + (0.1 if down else 0.0)), true, -1.0, true)
	_over.draw_arc(at, r, 0.0, TAU, 40, Color(Pal.SURFACE, 0.7), 3.0, true)
