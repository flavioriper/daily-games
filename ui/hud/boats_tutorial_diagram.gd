extends Control

## One page of Toy Boats' tutorial, played by the box itself: the pond on the
## left and the slate on the right (versus/boats_board.gd as a picture, deaf
## to the player's own hands), and a finger that does to them what a thumb
## does -- lifts a boat and carries it, taps one round, slides over the slate
## and lets go. The pebbles are answered by a pond of the page's own, by the
## rules. `lesson` picks the page (set before it enters the tree):
##
## - LAY: a boat carried to a new place, another tapped round.
## - THROW: two throws, a miss chalked as a ring and a hit as a cross.
## - HUNT: from one hit, a square beside it, then along the line to the end.
## - SINK: the other player's pebbles on the pond, a miss and the peg that
##   sinks a boat; then the slate's last cross and the boat chalked whole.
## - BAR: the bulb rings a square and the throw there is a hit.
##
## A page is a list of [seconds, what, ...] and starts over when it ends.
## Under reduce motion it stands on one moment of its lesson. It plays no
## sound and buzzes nothing: a picture has no Fx2D.

const Rules = preload("res://versus/boats_rules.gd")
const Board = preload("res://versus/boats_board.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { LAY, THROW, HUNT, SINK, BAR }

const FINGER_R := 26.0
const FINGER_ALPHA := 0.2
## A pebble's time in the air before the slate hears.
const FLIGHT := 0.45
## The player's fleet on every page, and the hidden one the slate is about.
const MINE := [Vector3i(1, 1, 0), Vector3i(7, 3, 1), Vector3i(2, 4, 0), Vector3i(0, 6, 1), Vector3i(4, 8, 0)]
const THEIRS := [Vector3i(4, 1, 0), Vector3i(1, 3, 1), Vector3i(3, 5, 0), Vector3i(8, 4, 1), Vector3i(6, 8, 0)]

var lesson: int = Lesson.LAY
var _board: Control
var _over: Control
var _pond: RefCounted
var _slate: RefCounted
var _their: RefCounted
var _script: Array = []
var _len := 6.0
var _next := 0
var _t := 0.0
## The finger: where it came from and is going (grid, then a point in the
## board), when it set off and for how long; whether it shows and is down.
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _go_at := 0.0
var _go_for := 0.001
var _shown := false
var _down := false
## Answers owed to pebbles in the air: [when, square].
var _owed: Array = []

static func c(x: int, y: int) -> int:
	return Rules.cell(x, y)

## A lesson's script and its length: [seconds, what, ...]. `go` moves the
## finger to a square of a grid (0 the pond, 1 the slate) over some time;
## `down` and `up` press and let go; `strike` is the other player's pebble;
## `hint` the bulb; `hide` takes the finger away.
static func script_of(the_lesson: int) -> Dictionary:
	match the_lesson:
		Lesson.LAY:
			return {"len": 8.0, "still": 3.0, "lay": true, "script": [
				[0.6, "go", 0, c(3, 4), 0.01], [0.9, "down"], [1.1, "go", 0, c(4, 6), 0.9], [2.2, "up"],
				[3.2, "go", 0, c(7, 4), 0.7], [4.1, "down"], [4.25, "up"],
				[5.2, "go", 0, c(5, 8), 0.6], [6.0, "down"], [6.2, "go", 0, c(6, 2), 0.9], [7.3, "up"], [7.6, "hide"]]}
		Lesson.THROW:
			return {"len": 8.0, "still": 6.0, "script": [
				[0.6, "go", 1, c(2, 7), 0.01], [0.8, "down"], [0.9, "go", 1, c(6, 3), 1.0], [2.2, "up"],
				[3.6, "go", 1, c(6, 6), 0.4], [4.0, "down"], [4.1, "go", 1, c(5, 5), 0.8], [5.2, "up"], [5.6, "hide"]]}
		Lesson.HUNT:
			return {"len": 10.5, "still": 9.0, "marks": [[c(4, 5), true], [c(7, 1), false], [c(2, 8), false]], "script": [
				[0.7, "go", 1, c(4, 4), 0.01], [0.9, "down"], [1.3, "up"],
				[2.6, "go", 1, c(5, 5), 0.4], [3.0, "down"], [3.4, "up"],
				[4.7, "go", 1, c(6, 5), 0.4], [5.1, "down"], [5.5, "up"],
				[6.8, "go", 1, c(3, 5), 0.5], [7.3, "down"], [7.7, "up"], [8.1, "hide"]]}
		Lesson.SINK:
			return {"len": 10.0, "still": 8.6, "struck": [c(2, 4), c(3, 4), c(8, 8)],
				"marks": [[c(6, 8), true], [c(3, 2), false], [c(9, 6), false], [c(0, 0), false]], "script": [
				[0.8, "strike", c(5, 6)], [2.6, "strike", c(4, 4)],
				[4.8, "go", 1, c(7, 8), 0.01], [5.0, "down"], [5.4, "up"], [5.8, "hide"]]}
	return {"len": 7.0, "still": 5.4, "marks": [[c(8, 5), true], [c(2, 2), false], [c(5, 7), false], [c(0, 9), false]], "script": [
		[1.0, "hint", c(8, 6)],
		[2.6, "go", 1, c(8, 6), 0.01], [2.9, "down"], [3.4, "up"], [3.9, "hide"]]}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = Board.new()
	_board.still = true
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_finger)
	add_child(_over)
	_begin()
	if Motion.reduce:
		# One moment of the lesson, everything before it having happened.
		var d := script_of(lesson)
		_board.set_process(false)
		while _t < float(d.still):
			_step(0.05)
			_board._process(0.05)
		_shown = false
		set_process(false)

## The page as it opens: the fleets, what is already on the slate and the
## pond, and the script from its top.
func _begin() -> void:
	var d := script_of(lesson)
	_script = d.script
	_len = d.len
	_next = 0
	_t = 0.0
	_owed.clear()
	_shown = false
	_down = false
	_pond = Rules.new()
	_pond.lay(MINE)
	_their = Rules.new()
	_their.lay(THEIRS)
	_slate = Rules.new()
	for m: Array in d.get("marks", []):
		_their.fire(m[0])
		_slate.note(m[0], Rules.HIT if m[1] else Rules.MISS)
	for sq: int in d.get("struck", []):
		_pond.fire(sq)
	_board.setup(_pond, _slate, bool(d.get("lay", false)))

func _process(delta: float) -> void:
	_step(delta)
	_over.queue_redraw()

func _step(delta: float) -> void:
	_t += delta
	if _t >= _len:
		_begin()
		return
	while _next < _script.size() and _t >= float(_script[_next][0]):
		_do(_script[_next])
		_next += 1
	while not _owed.is_empty() and _t >= float(_owed[0][0]):
		var sq: int = _owed.pop_front()[1]
		var a: Dictionary = _their.fire(sq)
		_slate.note(sq, a.r, a.boat, _their.boats[a.boat] if int(a.r) == Rules.SUNK else Rules.HIDDEN)
		_board.answer(sq, a.r, a.boat)
	# What a held finger does as it moves: carries a boat, or lights the
	# slate's row and column.
	if _down:
		var at := _finger()
		if _board.laying:
			_board._carry(at)
		else:
			var q: Vector2i = _board._square_at(1, at)
			var sq := Rules.cell(q.x, q.y) if Board._on_grid(q) else -1
			if sq != _board._over:
				_board._over = sq
				_board._touch()

func _do(e: Array) -> void:
	match String(e[1]):
		"go":
			_from = _finger() if _shown else _board.point_of(e[2], e[3])
			_to = _board.point_of(e[2], e[3])
			_go_at = _t
			_go_for = maxf(float(e[4]), 0.001)
			_shown = true
		"down":
			_down = true
			if _board.laying:
				_board._lift(_finger())
		"up":
			_down = false
			if _board.laying:
				_board._drop()
			else:
				var sq: int = _board._over
				_board._over = -1
				if sq >= 0 and _slate.marks[sq] == Rules.UNKNOWN:
					_board.aim(sq)
					_owed.append([_t + FLIGHT, sq])
		"strike":
			var a: Dictionary = _pond.fire(e[2])
			_board.strike(e[2], a.r, a.boat)
		"hint":
			_board.set_hint(e[2])
		"hide":
			_shown = false

## Where the finger is now, in the board's own space.
func _finger() -> Vector2:
	var u := clampf((_t - _go_at) / _go_for, 0.0, 1.0)
	return _from.lerp(_to, u * u * (3.0 - 2.0 * u))

func _draw_finger() -> void:
	if not _shown:
		return
	var at := _finger()
	var r := FINGER_R * (0.86 if _down else 1.0)
	_over.draw_circle(at, r, Color(Pal.TEXT, FINGER_ALPHA + (0.1 if _down else 0.0)), true, -1.0, true)
	_over.draw_arc(at, r, 0.0, TAU, 40, Color(Pal.SURFACE, 0.7), 3.0, true)
