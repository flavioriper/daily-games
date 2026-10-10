extends Control

## One page of Deckchair's tutorial: a small table played by a hand. The
## page holds the game's own table (arcade/deckchair_table.gd) in its wooden
## frame, a few cards laid on it by hand, and a finger that taps and carries
## them through the table's own `press`, `drag`, `release` and `tap`, so a
## card moves, turns over and scores exactly as it does in the game.
## `lesson` picks the page (set before it enters the tree):
##
## - BUILD: a red six carried onto a black seven, then a five tapped onto it.
## - TURN: a nine tapped away, the card under it turning up, and again.
## - HOME: an ace and a two tapped to their piles.
## - STOCK: the stock tapped, and what it turns played onto the columns.
## - KING: a king carried, with its queen, to the empty column.
## - SCORE, BOOSTS, HUD: rows of chips, each beside what it is.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/deckchair_sim.gd")
const Table = preload("res://arcade/deckchair_table.gd")
const Boosters = preload("res://arcade/boosters.gd")

enum Lesson { BUILD, TURN, HOME, STOCK, KING, SCORE, BOOSTS, HUD }

const FRAME := 14
## The table is no wider than this for its height.
const WIDE := 1.9
const TAP_DOWN := 0.16
const CARRY_T := 0.75
const FINGER_ALPHA := 0.16
const SP := 0
const HE := 1
const CL := 2
const DI := 3

var lesson: int = Lesson.BUILD

var _frame: PanelContainer
var _table: Table
var _over: Control
var _begun := false
var _t := 0.0
var _length := 6.0
## What the hand does and when: {at, do ("tap", "stock", "carry"), card,
## kind, i}.
var _steps: Array = []
var _next := 0
var _finger := Vector2.ZERO
var _down_until := -1.0
## A carry under way: when it began, and from where to where on the table.
var _carry_from := Vector2.ZERO
var _carry_to := Vector2.ZERO
var _carry_at := -1.0
var _finger_shown: ArrayMesh
var _rows_shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if _played():
		_frame = PanelContainer.new()
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color("6e4a2f")
		box.set_corner_radius_all(28)
		box.border_color = Color("9c6b45")
		box.set_border_width_all(5)
		box.set_content_margin_all(FRAME)
		box.shadow_color = Color(0.2, 0.1, 0.05, 0.25)
		box.shadow_size = 8
		box.shadow_offset = Vector2(0, 5)
		_frame.add_theme_stylebox_override("panel", box)
		add_child(_frame)
		_table = Table.new()
		_table.interactive = false
		_table.tall_room = 2.7
		_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(_table)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.z_index = 6
		_over.draw.connect(_draw_finger)
		add_child(_over)
	resized.connect(_layout)
	call_deferred("_layout")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun:
		call_deferred("_reset")

func _played() -> bool:
	return lesson < Lesson.SCORE

func _layout() -> void:
	if not _played():
		queue_redraw()
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# the frame's shadow falls under it
	var room := size - Vector2(0, 12.0)
	_frame.size = Vector2(minf(room.x, (room.y - 2.0 * FRAME) * WIDE + 2.0 * FRAME), room.y).floor()
	_frame.position = ((room - _frame.size) * 0.5).round()
	# now, not on the frame's next sort: a lesson laid this frame is drawn in
	# the table's pixels
	_table.position = Vector2(FRAME, FRAME)
	_table.size = _frame.size - Vector2(FRAME, FRAME) * 2.0
	_over.position = Vector2.ZERO
	_over.size = size
	if not _begun and is_inside_tree():
		_begun = true
		_reset()

# --- the lessons ---

static func _c(suit: int, rank: int) -> int:
	return suit * Sim.RANKS + rank - 1

## The lesson from its top: its cards laid, the hand back where it starts.
func _reset() -> void:
	if not _played() or not is_inside_tree() or size.x <= 0.0:
		return
	var s := Sim.new(1)
	s.stock = []
	s.waste = []
	s.home = [0, 0, 0, 0]
	s.down = [0, 0, 0, 0, 0, 0, 0]
	_steps = []
	match lesson:
		Lesson.BUILD:
			s.cols = [[_c(CL, 13)], [_c(SP, 7)], [_c(HE, 6)], [_c(DI, 11)], [_c(CL, 5)], [_c(HE, 3)], [_c(SP, 9)]]
			_steps = [
				{"at": 1.0, "do": "carry", "card": _c(HE, 6), "kind": Sim.At.COL, "i": 1},
				{"at": 3.2, "do": "tap", "card": _c(CL, 5)},
			]
			_length = 6.0
		Lesson.TURN:
			s.cols = [[_c(CL, 6), _c(HE, 8), _c(SP, 9)], [_c(DI, 10)], [_c(SP, 2), _c(DI, 7)], [_c(CL, 12)], [_c(HE, 13)], [_c(CL, 3)], [_c(DI, 5)]]
			s.down = [2, 0, 1, 0, 0, 0, 0]
			_steps = [
				{"at": 1.0, "do": "tap", "card": _c(SP, 9)},
				{"at": 2.8, "do": "tap", "card": _c(HE, 8)},
			]
			_length = 5.6
		Lesson.HOME:
			s.home = [1, 0, 0, 0]
			s.cols = [[_c(DI, 8), _c(SP, 2)], [_c(HE, 1)], [_c(DI, 5), _c(CL, 4)], [_c(SP, 11)], [_c(HE, 9)], [_c(CL, 7)], [_c(DI, 13)]]
			s.down = [1, 0, 0, 0, 0, 0, 0]
			_steps = [
				{"at": 1.0, "do": "tap", "card": _c(HE, 1)},
				{"at": 2.6, "do": "tap", "card": _c(SP, 2)},
			]
			_length = 5.4
		Lesson.STOCK:
			s.stock = [_c(CL, 2), _c(DI, 9), _c(SP, 4), _c(HE, 12), _c(CL, 8)]
			s.cols = [[_c(HE, 9)], [_c(SP, 13)], [_c(DI, 5)], [_c(CL, 11)], [_c(HE, 7)], [_c(SP, 3)], [_c(DI, 12)]]
			_steps = [
				{"at": 0.9, "do": "stock"},
				{"at": 2.0, "do": "tap", "card": _c(CL, 8)},
				{"at": 3.3, "do": "stock"},
				{"at": 4.4, "do": "tap", "card": _c(HE, 12)},
			]
			_length = 7.0
		Lesson.KING:
			s.cols = [[_c(DI, 3), _c(HE, 13), _c(SP, 12)], [], [_c(CL, 9)], [_c(DI, 6)], [_c(SP, 5)], [_c(HE, 11)], [_c(CL, 2)]]
			s.down = [1, 0, 0, 0, 0, 0, 0]
			_steps = [{"at": 1.0, "do": "carry", "card": _c(HE, 13), "kind": Sim.At.COL, "i": 1}]
			_length = 5.0
	s.sweeps = false
	s.score = 0
	s.stuck = false
	s.events.clear()
	s._plan.clear()
	_table.release(Vector2.ZERO)
	_table.sim = s
	_table._pops.clear()
	_table._sync(true)
	_t = 0.0
	_next = 0
	_carry_at = -1.0
	_down_until = -1.0
	_finger = _spot(_steps[0]) if not _steps.is_empty() else Vector2.ZERO
	_over.queue_redraw()

## Where a step's finger comes down, in the table's pixels: on the strip of
## the card that shows when another lies on it.
func _spot(step: Dictionary) -> Vector2:
	if String(step.do) == "stock":
		return _table.stock_at() + _table.card_size() * 0.5
	return _table.card_at(int(step.card)) + _table.card_size() * Vector2(0.5, 0.2)

func _process(delta: float) -> void:
	if not _played() or not _begun or Motion.reduce or _table.sim == null:
		return
	_t += delta
	if _carry_at >= 0.0:
		var k := clampf((_t - _carry_at) / CARRY_T, 0.0, 1.0)
		_finger = _carry_from.lerp(_carry_to, k * k * (3.0 - 2.0 * k))
		_table.drag(_finger)
		if k >= 1.0:
			_table.release(_finger)
			_carry_at = -1.0
			_down_until = -1.0
	elif _next < _steps.size():
		var step: Dictionary = _steps[_next]
		# the hand drifts to where it is wanted next
		_finger = _finger.lerp(_spot(step), minf(1.0, delta * 7.0))
		if _t >= float(step.at):
			_next += 1
			_finger = _spot(step)
			match String(step.do):
				"stock":
					_table.tap_stock()
					_down_until = _t + TAP_DOWN
				"tap":
					_table.tap(int(step.card))
					_down_until = _t + TAP_DOWN
				"carry":
					_carry_from = _finger
					var to := Vector2i(int(step.kind), int(step.i))
					var top: Vector2 = _table.home_at(to.y) if to.x == Sim.At.HOME else _table.col_next(to.y)
					_carry_to = top + _table.card_size() * Vector2(0.5, 0.2)
					_carry_at = _t
					_down_until = INF
					_table.press(_finger)
	if _t >= _length:
		_reset()
	_over.queue_redraw()

# --- drawing ---

func _draw_finger() -> void:
	if _table == null or _table.sim == null or _steps.is_empty():
		return
	var down := _t < _down_until or Motion.reduce
	var at: Vector2 = _over.get_global_transform().affine_inverse() * (_table.get_global_transform() * _finger)
	var r := _table.card_size().x * 0.34 * (0.85 if down else 1.0)
	var b := Face.Builder.new()
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.8 if down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 4.0, Color(Pal.TEXT, 0.55), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)

## The chip pages: what scores, the boosters, and the top bar's buttons
## drawn as they are on the screen, each beside what it does here.
func _draw() -> void:
	if _played() or size.x <= 0.0:
		return
	var rows: Array = []
	match lesson:
		Lesson.SCORE:
			rows = [
				["home", tr("TUT_DECKCHAIR_SCORE_HOME") % Sim.PTS_HOME],
				["eye", tr("TUT_DECKCHAIR_SCORE_FLIP") % Sim.PTS_FLIP],
				["undo", tr("TUT_DECKCHAIR_SCORE_DOWN") % -Sim.PTS_DOWN],
				["clock", tr("TUT_DECKCHAIR_SCORE_TIME")],
			]
		Lesson.BOOSTS:
			rows = [
				[Boosters.icon("dc_aces"), tr("TUT_DECKCHAIR_BOOST_ACES")],
				[Boosters.icon("dc_hints"), tr("TUT_DECKCHAIR_BOOST_HINTS_N") % Boosters.DC_HINTS],
				[Boosters.icon(Boosters.CHANCE), tr("TUT_DECKCHAIR_BOOST_CHANCE")],
			]
		_:
			rows = [
				["undo", tr("TUT_DECKCHAIR_HUD_UNDO")],
				["bulb", tr("TUT_DECKCHAIR_HUD_HINT_N") % Sim.HINTS],
				["reset", tr("TUT_DECKCHAIR_HUD_RESET")],
				["gear", tr("TUT_DECKCHAIR_HUD_GEAR")],
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
			var tint: Color = Boosters.tint(Boosters.CHANCE if k == 2 else "dc_aces")
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
	var fs := 30 if rows.size() <= 3 else 27
	for k in rows.size():
		var c: Vector2 = centres[k]
		Icons.paint(self, String(rows[k][0]), Rect2(c - Vector2(chip, chip) * 0.27, Vector2(chip, chip) * 0.54),
			Pal.SURFACE if boosts else Pal.TEXT, Color.TRANSPARENT if boosts else Pal.SURFACE)
		var line := String(rows[k][1])
		var lines := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, fs)
		draw_multiline_string(font, Vector2(tx, c.y - lines.y * 0.5 + fs * 0.82), line, HORIZONTAL_ALIGNMENT_LEFT, wide, fs, -1, Pal.TEXT)
