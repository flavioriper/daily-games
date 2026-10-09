extends Control

## One page of Penny Drop's tutorial, played by the rack itself
## (versus/penny_board.gd, deaf to the player's own hands and silent), and a
## finger that does to it what a thumb does: goes down on a slot, slides to
## another, lets go. `lesson` picks the page (set before it enters the tree):
##
## - DROP: a penny slid over a slot and let fall, the moon's on top of it,
##   another beside them.
## - LINE: the fourth penny of a row, and the rings round the line.
## - BLOCK: the moon's three stopped at the top, then the moon stopping yours.
## - TWO: a third penny that leaves two places to finish, one stopped, the
##   other taken.
## - BAR: the bulb rings a slot and the penny goes there.
##
## A page is the columns already played and a list of [seconds, what, ...],
## and it starts over when it ends. Under reduce motion it stands on the
## rack as the lesson leaves it.

const Rules = preload("res://versus/penny_rules.gd")
const Board = preload("res://versus/penny_board.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { DROP, LINE, BLOCK, TWO, BAR }

const FINGER_R := 26.0
const FINGER_ALPHA := 0.2
## The row of the rack the finger rests on, counted from the top.
const FINGER_ROW := 4.3

var lesson: int = Lesson.DROP
var _board: Control
var _over: Control
var _rules: RefCounted
var _script: Array = []
var _len := 6.0
var _next := 0
var _t := 0.0
## The finger: the columns it came from and is going to, when it set off and
## for how long; whether it shows and is down.
var _from := 3.0
var _to := 3.0
var _go_at := 0.0
var _go_for := 0.001
var _shown := false
var _down := false

## A lesson: the columns played before it opens (the sun first), its length
## and its script of [seconds, what, ...]. `go` moves the finger to a column
## over some time; `down` and `up` press and let go, `up` dropping the sun's
## penny where the finger is; `lift` brings the moon's penny over a column
## and `play` drops it; `hint` is the bulb; `ring` rings a line made; `hide`
## takes the finger away.
static func script_of(the_lesson: int) -> Dictionary:
	match the_lesson:
		Lesson.DROP:
			return {"len": 9.0, "pre": [3, 3], "script": [
				[0.7, "go", 1, 0.01], [1.0, "down"], [1.2, "go", 4, 0.9], [2.4, "up"], [2.6, "hide"],
				[3.6, "lift", 4], [4.2, "play", 4],
				[5.4, "go", 5, 0.01], [5.7, "down"], [5.9, "go", 2, 0.9], [7.1, "up"], [7.3, "hide"]]}
		Lesson.LINE:
			return {"len": 7.0, "pre": [1, 1, 2, 2, 3, 6], "script": [
				[0.8, "go", 6, 0.01], [1.1, "down"], [1.3, "go", 4, 0.8], [2.4, "up"], [2.6, "hide"], [3.2, "ring"]]}
		Lesson.BLOCK:
			return {"len": 8.5, "pre": [3, 0, 4, 0, 6, 0], "script": [
				[0.8, "go", 3, 0.01], [1.1, "down"], [1.3, "go", 0, 1.0], [2.6, "up"], [2.8, "hide"],
				[4.2, "lift", 5], [4.9, "play", 5]]}
		Lesson.TWO:
			return {"len": 10.5, "pre": [2, 2, 3, 3], "script": [
				[0.8, "go", 4, 0.01], [1.1, "down"], [1.6, "up"], [1.8, "hide"],
				[3.2, "lift", 1], [3.9, "play", 1],
				[5.4, "go", 5, 0.01], [5.7, "down"], [6.2, "up"], [6.4, "hide"], [7.0, "ring"]]}
	return {"len": 8.0, "pre": [3, 3, 4, 2], "script": [
		[1.0, "hint", 5],
		[2.8, "go", 5, 0.01], [3.1, "down"], [3.7, "up"], [3.9, "hide"],
		[5.0, "lift", 6], [5.6, "play", 6]]}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = Board.new()
	_board.deaf = true
	_board.rolls = false
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_finger)
	add_child(_over)
	_begin()
	if Motion.reduce:
		# The rack as the lesson leaves it: every drop of the script made.
		for e: Array in _script:
			match String(e[1]):
				"go":
					_to = float(e[2])
				"up":
					_rules.make(int(_to))
				"play":
					_rules.make(e[2])
		_board.setup(_rules, Rules.FIRST)
		if _rules.status() == Rules.WON:
			_board.finish("", _rules.line)
		set_process(false)

## The page as it opens: the rack with what was played before, and the
## script from its top.
func _begin() -> void:
	var d := script_of(lesson)
	_script = d.script
	_len = d.len
	_next = 0
	_t = 0.0
	_shown = false
	_down = false
	_rules = Rules.new()
	for col: int in d.pre:
		_rules.make(col)
	_board.setup(_rules, Rules.FIRST)
	_board.set_waiting(Rules.FIRST)

func _process(delta: float) -> void:
	_t += delta
	if _t >= _len:
		_begin()
	while _next < _script.size() and _t >= float(_script[_next][0]):
		_do(_script[_next])
		_next += 1
	# A held finger lights the column it is over and brings the penny there.
	if _down:
		var col := clampi(int(roundf(_finger())), 0, Rules.W - 1)
		if col != _board._over:
			_board._over = col
			_board._hover_to = float(col)
	_over.queue_redraw()

func _do(e: Array) -> void:
	match String(e[1]):
		"go":
			_from = _finger() if _shown else float(e[2])
			_to = float(e[2])
			_go_at = _t
			_go_for = maxf(float(e[3]), 0.001)
			_shown = true
		"down":
			_down = true
			_board._down = true
			_board._over = -1
		"up":
			_down = false
			_drop(int(_to))
		"lift":
			_board.set_waiting(Rules.SECOND)
			_board._hover_x = 3.0
			_board.set_lifted(e[2])
		"play":
			_drop(e[2])
		"hint":
			_board.set_hint(e[2])
		"ring":
			_board.finish("", _rules.line)
		"hide":
			_shown = false

## The side to move's penny goes down `col`, and the other side's then waits.
func _drop(col: int) -> void:
	var side: int = _rules.turn
	var cell: int = _rules.make(col)
	if cell < 0:
		return
	_board.play(cell, side)
	if _rules.status() == Rules.PLAYING and side == Rules.SECOND:
		_board.set_waiting(Rules.FIRST)

## The column the finger is over now, as a fraction.
func _finger() -> float:
	var u := clampf((_t - _go_at) / _go_for, 0.0, 1.0)
	return lerpf(_from, _to, u * u * (3.0 - 2.0 * u))

func _draw_finger() -> void:
	if not _shown:
		return
	var at: Vector2 = _board.point_of(Vector2((_finger() + 0.5) * Board.U, FINGER_ROW * Board.U))
	var r := FINGER_R * (0.86 if _down else 1.0)
	_over.draw_circle(at, r, Color(Pal.TEXT, FINGER_ALPHA + (0.1 if _down else 0.0)), true, -1.0, true)
	_over.draw_arc(at, r, 0.0, TAU, 40, Color(Pal.SURFACE, 0.7), 3.0, true)
