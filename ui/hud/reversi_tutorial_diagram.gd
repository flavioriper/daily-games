extends Control

## One page of Reversi's tutorial, played by the board itself
## (versus/reversi_board.gd, deaf to the player's own hands and silent), and
## a finger that does to it what a thumb does: goes down on a square, and
## lets go. `lesson` picks the page (set before it enters the tree):
##
## - PLACE: a disc shuts one of the moon's between two of the sun's and it
##   turns; the moon answers the same way; another.
## - MANY: one disc shutting runs along four lines at once.
## - PASS: a disc that leaves the moon no square, and the sun moving again.
## - CORNER: a corner taken along an edge, and the moon turning what it can,
##   which is never the corner.
## - BAR: the bulb rings a square and the disc goes there.
##
## A page is the board it opens on and a list of [seconds, what, ...], and it
## starts over when it ends. Under reduce motion it stands on the board as
## the lesson leaves it.

const Rules = preload("res://versus/reversi_rules.gd")
const Board = preload("res://versus/reversi_board.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { PLACE, MANY, PASS, CORNER, BAR }

const FINGER_R := 26.0
const FINGER_ALPHA := 0.2
## The opening, as the rules lay it.
const OPENING := ["........", "........", "........", "...ox...", "...xo...", "........", "........", "........"]

var lesson: int = Lesson.PLACE
var _board: Control
var _over: Control
var _rules: RefCounted
var _script: Array = []
var _len := 6.0
var _next := 0
var _t := 0.0
## The finger: the squares it came from and is going to (as points in
## squares), when it set off and for how long; whether it shows and is down.
var _from := Vector2(3.5, 3.5)
var _to := Vector2(3.5, 3.5)
var _go_at := 0.0
var _go_for := 0.001
var _shown := false
var _down := false

## A lesson: the board it opens on (`x` the sun's discs, which move first,
## `o` the moon's), its length and its script of [seconds, what, ...]. `go`
## moves the finger to a square (x, y) over some time; `down` and `up` press
## and let go, `up` setting the sun's disc where the finger is; `lift` rings
## the moon's square and `play` sets its disc there; `hint` is the bulb;
## `hide` takes the finger away.
static func script_of(the_lesson: int) -> Dictionary:
	match the_lesson:
		Lesson.PLACE:
			return {"len": 10.5, "rows": OPENING, "script": [
				[0.8, "go", 5, 4, 0.01], [1.2, "down"], [2.2, "up"], [2.4, "hide"],
				[4.0, "lift", 5, 5], [4.7, "play", 5, 5],
				[6.4, "go", 5, 6, 0.01], [6.8, "down"], [7.8, "up"], [8.0, "hide"]]}
		Lesson.MANY:
			return {"len": 7.5, "rows": [
				"........",
				"....x...",
				"..x.o.o.",
				"...oo...",
				".xoo....",
				".....o..",
				"......x.",
				"........"], "script": [
				[0.9, "go", 4, 4, 0.01], [1.3, "down"], [3.0, "up"], [3.2, "hide"]]}
		Lesson.PASS:
			return {"len": 9.5, "rows": [
				"xo......",
				"........",
				"........",
				"....xo..",
				"........",
				"........",
				"........",
				"......ox"], "script": [
				[0.9, "go", 6, 3, 0.01], [1.3, "down"], [2.2, "up"], [2.4, "hide"],
				[4.6, "go", 2, 0, 0.01], [5.0, "down"], [5.9, "up"], [6.1, "hide"]]}
		Lesson.CORNER:
			return {"len": 9.0, "rows": [
				".ooox...",
				".xo.....",
				"..ox....",
				"........",
				"........",
				"........",
				"........",
				"........"], "script": [
				[0.9, "go", 0, 0, 0.01], [1.3, "down"], [2.4, "up"], [2.6, "hide"],
				[4.4, "lift", 0, 1], [5.1, "play", 0, 1]]}
	return {"len": 8.5, "rows": OPENING, "script": [
		[1.0, "hint", 2, 3],
		[2.8, "go", 2, 3, 0.01], [3.2, "down"], [3.9, "up"], [4.1, "hide"],
		[5.4, "lift", 2, 2], [6.1, "play", 2, 2]]}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = Board.new()
	_board.deaf = true
	_board.tally = false
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_finger)
	add_child(_over)
	_begin()
	if Motion.reduce:
		# The board as the lesson leaves it: every disc of the script set down.
		for e: Array in _script:
			match String(e[1]):
				"go":
					_to = Vector2(float(e[2]), float(e[3]))
				"up":
					_rules.make(Rules.cell(int(_to.x), int(_to.y)))
				"play":
					_rules.make(Rules.cell(e[2], e[3]))
		_board.setup(_rules, Rules.FIRST)
		set_process(false)

## The page as it opens: the board the lesson starts on, and the script from
## its top.
func _begin() -> void:
	var d := script_of(lesson)
	_script = d.script
	_len = d.len
	_next = 0
	_t = 0.0
	_shown = false
	_down = false
	_rules = Rules.new()
	_rules.lay(d.rows, Rules.FIRST)
	_board.setup(_rules, Rules.FIRST)
	_board.interactive = _rules.turn == Rules.FIRST

func _process(delta: float) -> void:
	_t += delta
	if _t >= _len:
		_begin()
	while _next < _script.size() and _t >= float(_script[_next][0]):
		_do(_script[_next])
		_next += 1
	_over.queue_redraw()

func _do(e: Array) -> void:
	match String(e[1]):
		"go":
			var to := Vector2(float(e[2]), float(e[3]))
			_from = _finger() if _shown else to
			_to = to
			_go_at = _t
			_go_for = maxf(float(e[4]), 0.001)
			_shown = true
		"down":
			_down = true
			_board._down = true
			_board._over = Rules.cell(int(_to.x), int(_to.y))
			_board.queue_redraw()
		"up":
			_down = false
			_put(Rules.cell(int(_to.x), int(_to.y)))
		"lift":
			_board.set_lifted(Rules.cell(e[2], e[3]))
		"play":
			_put(Rules.cell(e[2], e[3]))
		"hint":
			_board.set_hint(Rules.cell(e[2], e[3]))
		"hide":
			_shown = false

## The side to move's disc goes on `cell`; the dots are the sun's alone.
func _put(cell: int) -> void:
	var side: int = _rules.turn
	var turned: PackedInt32Array = _rules.make(cell)
	_board.interactive = false
	if turned.is_empty():
		return
	_board.play(cell, turned, side)
	var run: int = _next
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if is_inside_tree() and _next >= run and not _rules.over:
			_board.interactive = _rules.turn == Rules.FIRST)

## The square the finger is over now, as a point in squares.
func _finger() -> Vector2:
	var u := clampf((_t - _go_at) / _go_for, 0.0, 1.0)
	return _from.lerp(_to, u * u * (3.0 - 2.0 * u))

func _draw_finger() -> void:
	if not _shown:
		return
	# A little under the square's middle, as a thumb lies, so the disc shows.
	var at: Vector2 = _board.point_of((_finger() + Vector2(0.5, 0.72)) * Board.U)
	var r := FINGER_R * (0.86 if _down else 1.0)
	_over.draw_circle(at, r, Color(Pal.TEXT, FINGER_ALPHA + (0.1 if _down else 0.0)), true, -1.0, true)
	_over.draw_arc(at, r, 0.0, TAU, 40, Color(Pal.SURFACE, 0.7), 3.0, true)
