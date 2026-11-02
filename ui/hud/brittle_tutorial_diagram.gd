extends Control

## One page of Brittle's tutorial: a small tin played by a hand. The page holds
## the game's own board (arcade/brittle_board.gd) with nothing of the screen
## round it, laid with a tin set up for the lesson, and a finger that aims and
## lets go through the board's own `press`, `drag` and `release`. So the balls
## fly, the numbers fall and the row comes down as on the screen. `lesson`
## picks the page (set before it enters the tree):
##
## - AIM: the finger slides, the dots follow, and the stream goes up.
## - CRACK: a banked shot off the wall into a square about to break.
## - PLUM: a ball through a plum, and the count by the scoop goes up.
## - RISE: squares a row over the last line come down after the volley.
## - SWEETS: a line through a row, sparks and popping candy.
## - TOOLS: the three buttons, drawn as they are on the screen.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/brittle_sim.gd")
const Board = preload("res://arcade/brittle_board.gd")

enum Lesson { AIM, CRACK, PLUM, RISE, SWEETS, TOOLS }

const FINGER_ALPHA := 0.16
const SLIDE_T := 0.9
const LENGTH := 6.0

var lesson: int = Lesson.AIM

var _board: Control
var _over: Control
var _begun := false
var _t := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _fired := false
var _finger_shown: ArrayMesh
var _rows_shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if lesson != Lesson.TOOLS:
		_board = Board.new()
		_board.interactive = false
		add_child(_board)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.draw.connect(_draw_over)
		add_child(_over)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	if _begun:
		call_deferred("_reset")

func _layout() -> void:
	if lesson == Lesson.TOOLS:
		queue_redraw()
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_board.size = size
	_board.layout()
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

func _square(g: RefCounted, r: int, c: int, value: int, what: int = Sim.Kind.SQUARE) -> void:
	var i: int = Sim.index(r, c)
	g.kind[i] = what
	g.hp[i] = value
	g.full[i] = value

## The lesson from its top: a tin set up for it, the aim from `from` to `to`
## (field units) a moment away.
func _reset() -> void:
	if lesson == Lesson.TOOLS or not is_inside_tree() or size.x <= 0.0:
		return
	var g: RefCounted = Sim.new(3)
	g.kind.fill(Sim.Kind.NONE)
	g.step_n = 6
	g.balls = 6
	var aim := Vector2(3.5, 2.5)
	match lesson:
		Lesson.AIM:
			_square(g, 1, 2, 4)
			_square(g, 2, 4, 7)
			_square(g, 3, 3, 3)
		Lesson.CRACK:
			g.balls = 4
			_square(g, 2, 5, 2)
			_square(g, 2, 3, 9)
			_square(g, 4, 1, 6, Sim.Kind.TL)
			aim = Vector2(6.8, 4.2)
		Lesson.PLUM:
			g.kind[Sim.index(4, 3)] = Sim.Kind.PLUS
			g.kind[Sim.index(2, 2)] = Sim.Kind.PLUS
			_square(g, 1, 3, 8)
			g.balls = 3
			aim = Vector2(3.5, 4.5)
		Lesson.RISE:
			for c in [0, 2, 3, 5]:
				_square(g, Sim.ROWS - 2, c, 20)
			_square(g, 5, 4, 12)
			g.balls = 2
			aim = Vector2(1.5, 3.0)
		Lesson.SWEETS:
			g.kind[Sim.index(3, 3)] = Sim.Kind.ROW
			g.kind[Sim.index(1, 4)] = Sim.Kind.FIZZ
			for c in [0, 1, 5, 6]:
				_square(g, 3, c, 3)
			_square(g, 2, 2, 1, Sim.Kind.POP)
			_square(g, 1, 2, 4)
			_square(g, 2, 1, 4)
			_square(g, 2, 3, 4)
			aim = Vector2(3.5, 3.5)
	_board.lay(g)
	_board.paused = false
	_from = _board.px(Vector2(g.home_x, 7.0))
	_to = _board.px(aim)
	_fired = false
	_t = 0.0

func _process(delta: float) -> void:
	if lesson == Lesson.TOOLS or not _begun or Motion.reduce or _board.sim == null:
		return
	var was := _t
	_t += delta
	if was < 0.6 and _t >= 0.6:
		_board.press(_from)
	if _t >= 0.6 and not _fired:
		var k := clampf((_t - 0.6) / SLIDE_T, 0.0, 1.0)
		_board.drag(_from.lerp(_to, k * k * (3.0 - 2.0 * k)))
		if k >= 1.0:
			_fired = true
			_board.release(_to)
	_over.queue_redraw()
	if _t >= LENGTH and _board.sim.phase == Sim.Phase.AIM or _t >= LENGTH * 2.0:
		_reset()

func _draw_over() -> void:
	if _t < 0.6 or _fired:
		return
	var k := clampf((_t - 0.6) / SLIDE_T, 0.0, 1.0)
	var at := _from.lerp(_to, k * k * (3.0 - 2.0 * k))
	var r := size.y * 0.05
	var b := Face.Builder.new()
	b.disc(at, r, Color(Color.WHITE, FINGER_ALPHA * 1.8))
	b.stroke(Face.Builder.ring(at, r, r), 4.0, Color(Color.WHITE, 0.7), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

## The tools page: the three buttons beside what they do.
func _draw() -> void:
	if lesson != Lesson.TOOLS or size.x <= 0.0:
		return
	var rows := [["undo", tr("TUT_BRITTLE_TOOL_UNDO")], ["bulb", tr("TUT_BRITTLE_TOOL_BULB")], ["arrow_down", tr("TUT_BRITTLE_TOOL_ARROW")]]
	var row_h := size.y / rows.size()
	var chip := minf(104.0, row_h * 0.72)
	var x0 := 36.0
	var b := Face.Builder.new()
	var centres: Array = []
	for k in rows.size():
		var c := Vector2(x0 + chip * 0.5, row_h * (k + 0.5))
		centres.append(c)
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
		Icons.paint(self, String(rows[k][0]), Rect2(c - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54), Pal.TEXT, Pal.SURFACE)
		var line := String(rows[k][1])
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30)
		draw_multiline_string(font, Vector2(tx, c.y - lines.y * 0.5 + 30.0 * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, wide, 30, -1, Pal.TEXT)
