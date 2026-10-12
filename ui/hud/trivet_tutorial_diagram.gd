extends Control

## One page of Trivet's tutorial: a small table played by a hand. The page
## holds the game's own table (arcade/trivet_board.gd) with nothing of the
## screen round it -- no bar, no plates, no sound, no knock -- laid with a
## tray set up for the lesson, and a finger that carries the hand's stacks
## to their places through the table's own `press`, `drag` and `release`.
## So the mats hop, gather and are put away exactly as on the screen.
## `lesson` picks the page (set before it enters the tree):
##
## - PLACE: an empty tray; the three stacks are set down one by one and the
##   next three come.
## - GATHER: three stacks in a row with one colour on top; the mats leave
##   two of them for the third.
## - CLEAR: seven of a colour and three more: ten, put away.
## - CHAIN: a stack put away uncovers a colour that gathers and goes too.
## - LEVELS: the whole tray with its lids; the score passes a level and a
##   lid is lifted.
## - TOOLS: the brush takes a stack off, then a fresh hand is dealt.
## - BOOSTS: the two boosters and the Second chance, drawn as chips.
## - HUD: the top bar's Reset, gear and ?, drawn as they are.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/trivet_sim.gd")
const Art = preload("res://arcade/trivet_art.gd")
const Board = preload("res://arcade/trivet_board.gd")
const Boosters = preload("res://arcade/boosters.gd")

enum Lesson { PLACE, GATHER, CLEAR, CHAIN, LEVELS, TOOLS, BOOSTS, HUD }

## A carry takes this long from the cloth to its place; a tap's finger stays
## down this long.
const CARRY_T := 0.85
const TAP_DOWN := 0.22
const FINGER_ALPHA := 0.16
## The table's cloth and tools at this much of the screen's.
const UI := 0.5

var lesson: int = Lesson.PLACE

var _board: Control
var _over: Control
var _begun := false
var _t := 0.0
var _length := 7.0
## What the hand does: {at, slot, cell} carries, {at, tool} and {at, tap}
## (a place) taps. `_done` is how many have begun.
var _steps: Array = []
var _done := 0
var _carry := {}
var _tap_at := -10.0
var _tap_pos := Vector2.ZERO
## Points lettered where a stack was put away: {text, pos, at}.
var _notes: Array = []
var _finger_shown: ArrayMesh
var _rows_shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if _played():
		_board = Board.new()
		_board.interactive = false
		_board.ui = UI
		_board.beat.connect(_on_beat)
		add_child(_board)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.z_index = 6
		_over.draw.connect(_draw_over)
		add_child(_over)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _played() -> bool:
	return lesson != Lesson.BOOSTS and lesson != Lesson.HUD

func _layout() -> void:
	if not _played():
		queue_redraw()
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# the table is a rounded plate in the page, no wider than twice its height
	var w := minf(size.x, size.y * 2.0)
	_board.size = Vector2(w, size.y)
	_board.position = Vector2((size.x - w) * 0.5, 0.0).round()
	_board.layout()
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

func _cell(game: RefCounted, q: int, r: int) -> int:
	return int(game._index[Vector2i(q, r)])

func _run(col: int, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(col)
	return out

## The lesson from its top: a tray set up for it and the hand's first move
## a moment away.
func _reset() -> void:
	if not _played() or not is_inside_tree() or size.x <= 0.0:
		return
	var whole := lesson == Lesson.LEVELS
	var game: RefCounted = Sim.new(9, Sim.R if whole else 1)
	_steps = []
	_length = 7.0
	match lesson:
		Lesson.PLACE:
			game.hand = [[0, 0], [1, 1, 2], [2, 2, 2]]
			_steps = [{"at": 0.7, "slot": 0, "cell": _cell(game, 0, 0)}, {"at": 2.0, "slot": 1, "cell": _cell(game, 1, -1)},
				{"at": 3.3, "slot": 2, "cell": _cell(game, -1, 1)}]
			_length = 6.4
		Lesson.GATHER:
			game.stacks[_cell(game, -1, 0)] = [1, 1, 0, 0]
			game.stacks[_cell(game, 1, 0)] = [0, 0, 0]
			game.hand = [[2, 0, 0], [1, 1], [2, 2, 2]]
			_steps = [{"at": 0.9, "slot": 0, "cell": _cell(game, 0, 0)}]
			_length = 5.6
		Lesson.CLEAR:
			game.stacks[_cell(game, 1, 0)] = _run(0, 7)
			game.stacks[_cell(game, -1, 1)] = [2, 2, 1]
			game.hand = [[0, 0, 0], [1, 1], [2, 2, 2]]
			_steps = [{"at": 0.9, "slot": 0, "cell": _cell(game, 0, 0)}]
			_length = 5.6
		Lesson.CHAIN:
			game.stacks[_cell(game, 1, 0)] = _run(0, 7)
			game.stacks[_cell(game, -1, 0)] = _run(1, 9)
			game.hand = [[1, 0, 0, 0], [2, 2], [2, 2, 2]]
			_steps = [{"at": 0.9, "slot": 0, "cell": _cell(game, 0, 0)}]
			_length = 6.6
		Lesson.LEVELS:
			game.stacks[_cell(game, 1, 0)] = _run(0, 7)
			game.stacks[_cell(game, -1, 1)] = [2, 2, 1]
			game.stacks[_cell(game, 0, -2)] = [1, 1, 2, 2]
			game.hand = [[0, 0, 0], [1, 1], [2, 2, 2]]
			game.score = Sim.goal(1) - 6
			_steps = [{"at": 0.9, "slot": 0, "cell": _cell(game, 0, 0)}]
			_length = 6.0
		Lesson.TOOLS:
			game.stacks[_cell(game, 1, 0)] = [0, 0, 1, 1, 2, 0]
			game.stacks[_cell(game, -1, 0)] = [1, 1, 1]
			game.stacks[_cell(game, 0, 1)] = [2, 2]
			game.hand = [[2, 1, 0], [0, 1], [1, 2, 0]]
			_steps = [{"at": 0.8, "tool": "sweep"}, {"at": 1.7, "tap": _cell(game, 1, 0)}, {"at": 3.4, "tool": "deal"}]
			_length = 6.0
	game.events.clear()
	game.events.append({"type": "deal", "fresh": false, "hand": game.hand.duplicate(true)})
	_board.lay(game)
	_t = 0.0
	_done = 0
	_carry = {}
	_tap_at = -10.0
	_notes.clear()
	if Motion.reduce:
		# a still page: everything the hand does, done
		for i in 3:
			_board._process(0.0)
		for step: Dictionary in _steps:
			_begin(step)
			if not _carry.is_empty():
				_board.drag(_carry.to)
				_board.release(_carry.to)
				_carry = {}
			for i in 40:
				_board._process(0.05)
		_done = _steps.size()
	_over.queue_redraw()

func _begin(step: Dictionary) -> void:
	if step.has("slot"):
		var from: Vector2 = _board.slot_px(int(step.slot)) - Vector2(0, _board._hand_u * 0.3)
		var to: Vector2 = _board.place_px(int(step.cell)) + Vector2(0, Board.CARRY_UP * _board._u)
		_carry = {"from": from, "to": to, "at": _t}
		_board.press(from)
	elif step.has("tool"):
		_tap(_board.tool_px(String(step.tool)))
	else:
		_tap(_board.place_px(int(step.tap)))

func _tap(at: Vector2) -> void:
	_tap_at = _t
	_tap_pos = at
	_board.press(at)
	_board.release(at)

func _process(delta: float) -> void:
	if not _played() or not _begun or Motion.reduce:
		return
	_t += delta
	while _done < _steps.size() and _t >= float(_steps[_done].at) and _carry.is_empty():
		_begin(_steps[_done])
		_done += 1
	if not _carry.is_empty():
		var k := clampf((_t - float(_carry.at)) / CARRY_T, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var from: Vector2 = _carry.from
		var to: Vector2 = _carry.to
		_board.drag(from.lerp(to, e))
		if k >= 1.0:
			_board.release(to)
			_carry = {}
	_notes = _notes.filter(func(n: Dictionary) -> bool: return _t - float(n.at) < 1.2)
	_over.queue_redraw()
	if _t >= _length:
		_reset()

func _on_beat(what: String, data: Dictionary) -> void:
	if what == "clear":
		_notes.append({"text": "+%d" % int(data.pts), "pos": data.at, "at": _t, "col": Art.FELT[int(data.col)]})

# --- drawing ---

## The finger where the hand is, and the points of a stack put away.
func _draw_over() -> void:
	if _board == null or _board.sim == null:
		return
	var font: Font = CozyTheme.display(700)
	for n: Dictionary in _notes:
		var k := clampf((_t - float(n.at)) / 1.2, 0.0, 1.0)
		var pos: Vector2 = _board.position + n.pos - Vector2(0, 50.0 + 50.0 * k)
		var text := String(n.text)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		_over.draw_string_outline(font, pos - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 10, Color(Art.INK, 1.0 - k * k))
		_over.draw_string(font, pos - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(Art.CREAM, 1.0 - k * k))
	var at := Vector2.INF
	var down := false
	if not _carry.is_empty():
		at = _board._finger
		down = true
	elif _t - _tap_at < TAP_DOWN + 0.3:
		at = _tap_pos
		down = _t - _tap_at < TAP_DOWN
	if at == Vector2.INF:
		return
	at += _board.position
	var r := size.y * 0.06 * (0.85 if down else 1.0)
	var b := Face.Builder.new()
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.8 if down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 4.0, Color(Pal.TEXT, 0.55), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

## The chip pages: the boosters with what each does, and the top bar's
## buttons drawn as they are on the screen beside what they do here.
func _draw() -> void:
	if _played() or size.x <= 0.0:
		return
	var rows: Array = []
	if lesson == Lesson.BOOSTS:
		rows = [
			[Boosters.icon("tv_brush"), tr("TUT_TRIVET_BOOST_BRUSH_N") % Boosters.TV_BRUSHES],
			[Boosters.icon("tv_hand"), tr("TUT_TRIVET_BOOST_HAND_N") % Boosters.TV_HANDS],
			[Boosters.icon(Boosters.CHANCE), tr("TUT_TRIVET_BOOST_CHANCE_N") % Sim.REVIVE_TAKES],
		]
	else:
		rows = [
			["reset", tr("TUT_TRIVET_HUD_RESET")],
			["gear", tr("TUT_TRIVET_HUD_GEAR")],
			["help", tr("TUT_TRIVET_HUD_HELP")],
		]
	var boosts := lesson == Lesson.BOOSTS
	var row_h := size.y / rows.size()
	var chip := minf(104.0, row_h * 0.72)
	var x0 := 36.0
	var b := Face.Builder.new()
	var centres: Array = []
	for k in rows.size():
		var c := Vector2(x0 + chip * 0.5, row_h * (k + 0.5))
		centres.append(c)
		if boosts:
			# a booster is a disc in its game's colour, the Second chance gold
			var tint: Color = Boosters.tint(Boosters.CHANCE if k == 2 else "tv_brush")
			b.disc(c + Vector2(0, 6.0), chip * 0.5, Color(Pal.TEXT, 0.16))
			b.disc(c, chip * 0.5, tint)
		else:
			var at := c - Vector2(chip, chip) * 0.5
			b.polygon(Face.Builder.round_rect(at + Vector2(0, 6.0), Vector2(chip, chip), 26.0), Color(Pal.TEXT, 0.16))
			b.polygon(Face.Builder.round_rect(at, Vector2(chip, chip), 26.0), Pal.SURFACE)
	_rows_shown = b.mesh()
	draw_mesh(_rows_shown, null)
	var font: Font = CozyTheme.display(700)
	var tx := x0 + chip + 28.0
	var wide := size.x - tx - 24.0
	for k in rows.size():
		var c: Vector2 = centres[k]
		Icons.paint(self, String(rows[k][0]), Rect2(c - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54),
			Pal.SURFACE if boosts else Pal.TEXT, Color.TRANSPARENT if boosts else Pal.SURFACE)
		var line := String(rows[k][1])
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30)
		draw_multiline_string(font, Vector2(tx, c.y - lines.y * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30, -1, Pal.TEXT)
