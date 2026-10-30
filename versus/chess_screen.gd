extends Control

## A game of chess against the computer: the second game on the Versus
## tab. The flat boards' top bar (back, the title in ink with its sprout,
## undo, reset, a hint with its count, settings), a scoreboard with the sun
## for you and the moon for the computer and the move number between them,
## and the board on the same wooden deck snooker's table stands on.
##
## The tournament board since 2026-10-30 (the user: "make chess experience way
## better ... more professional tools"): your pieces at the bottom whichever
## colour you have, the other player's plate over the board and yours under
## it, each with its clock, the score sheet under that and the tools at the
## foot. A clock of your choosing (versus/chess_options.gd), moves queued for
## your turn, a pen for arrows and squares, every move graded
## (versus/chess_grade.gd), the opening named, and a review of the game after
## it, with its accuracy and a go at your mistakes again.
##
## The other player is versus/chess_ai.gd, thinking on a worker thread. The
## rules are versus/chess_rules.gd, the board and its animation
## versus/chess_board.gd, the look and the motion of the pieces a skin
## (versus/chess_skin.gd).
##
## **Level 3 is Online** (spec 2026-10-04-versus-online-design.md): the other
## player is a stranger, and `online` (versus/online/online.gd) is everything
## about that which is not chess. What is chess's own is under "online" below:
## the board idles behind the lobby (State.WAIT), the seat that opens is
## white, the computer's seat is the match -- a move is `{m: int}`, the very
## int the rules make, so a promotion's piece, a castle and an en passant
## travel in it -- and a move the rules do not list is a foul.

signal closed

const Rules = preload("res://versus/chess_rules.gd")
const AI = preload("res://versus/chess_ai.gd")
const Board = preload("res://versus/chess_board.gd")
const ChessSkin = preload("res://versus/chess_skin.gd")
const Record = preload("res://versus/versus_record.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
## What the phone knocks for (docs/agents/haptics.md). `check` rings for
## either king and is not mapped: `_after_move` warns for yours.
const HAPTICS := {"hint": Haptics.GOOD, "win": Haptics.WIN, "lose": Haptics.LOSE,
	"draw": Haptics.BUMP}
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const Face = preload("res://ui/faces/face.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Analytics = preload("res://core/analytics.gd")
const Online = preload("res://versus/online/online.gd")
const Notes = preload("res://versus/chess_notes.gd")
const Grade = preload("res://versus/chess_grade.gd")
const Strip = preload("res://versus/chess_strip.gd")
const Options = preload("res://versus/chess_options.gd")

const GAME := "chess"
const MARGIN := 40
const GAP := 20
const DECK_PAD := 8
const PLATE_H := 92.0
const FACE_PX := 68.0
const TOOL := 84.0
const BACKDROP_BLEED := 90.0
const HINTS := 3
## Pauses, seconds: the shortest the computer seems to think, how long it
## holds its piece up before moving it, and the beat before the end card.
const THINK_MIN := 0.6
const PONDER := 0.35
const END_WAIT := 1.8
## A mate waits longer: the king's crown is still rolling to a stop.
const MATE_WAIT := 2.6
const TOAST_HOLD := 2.2
const LEVELS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "VS_ONLINE"]
## The room a name has on a scoreboard plate, beside its face.
const NAME_W := 420.0
## The clock turns red under this, and the phone knocks once at BUZZ_AT.
const CLOCK_LOW := 20.0
const BUZZ_AT := 10.0
## A game online also has the match's minute a move: seconds of it to go when
## it comes up on the plate.
const MOVE_LIMIT_SHOWN := 20
## The clock of a game online: the same for both, whatever each has chosen.
const ONLINE_CLOCK := [300, 3]
## A rating the computer's levels stand at, and yours when you begin.
const BOT_RATING := [600, 1100, 1500]
const START_RATING := 800.0
const RATING_K := 24.0
## How long a line of the moon's stays on its plate, and how long a second
## press on Resign is waited for.
const QUIP_HOLD := 3.6
const RESIGN_HOLD := 3.0

## WAIT is online's: the board laid and still while the lobby looks.
enum State { ENTER, YOURS, THINK, ANIM, REWIND, OVER, WAIT, RETRY }

var level := 1
var rules: RefCounted
var board: Control
var _deck_mesh: ArrayMesh
var _deck_key := Rect2()
var top_bar: Control
var settings_sheet: Control
## The tutorial card: the top bar's ?, the settings' How to play and the
## first play (ui/hud/screen_tutor.gd).
var tutor: RefCounted
## The colour the player moves this game.
var player := Rules.WHITE
var _state := State.ENTER
var _history: Array = []
var _rewinds := 0
var _hints := HINTS
## The move the bulb is showing, -1 when none: asking again while it is up
## shows it again and spends nothing.
var _hint_move := -1
var _undos := 0
## True while the tutorial card is over the board.
var _held := false
var _game := 0
var _task := -1
var _box: Array = []
var _task_for := ""
var _task_game := 0
var _think_at := 0.0
var _rng := RandomNumberGenerator.new()
var _fx: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _deck: Control
var _room: MarginContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween
var _end: Control
var _plates: Array = []
var _faces: Array = []
var _status: Array[Label] = []
var _names: Array[Label] = []
## Each plate's clock: the pill and its digits.
var _clock_pills: Array[PanelContainer] = []
var _clock_labels: Array[Label] = []
## Seconds left, by plate: 0 yours, 1 the other's.
var _clock := [0.0, 0.0]
var _clock_ink := [Color.BLACK, Color.BLACK]
var _increment := 0.0
var _clocked := false
var _warned := false
## What you played and what it was, by ply: the int, the notation, and the
## verdict once there is one (versus/chess_grade.gd's judge).
var _moves: Array = []
var _sans: Array = []
var _grades := {}
## The position before your last move and the move, for the verdict that is
## worked out alongside the computer's answer.
var _judge_game: RefCounted
var _judge_ply := -1
## A move the worker has been given to play out: its seed.
var _strip: Control
var _tools: HBoxContainer
var _tool_prev: Button
var _tool_next: Button
var _tool_pen: Button
var _tool_gear: Button
var _tool_resign: Button
var _line: Label
var _pen_row: HBoxContainer
var _options: Control
## The move on show when it is not the game's last, -1 at the live board.
var _view := -1
var _reviewing := false
var _review_row: HBoxContainer
var _try_button: Button
var _retry_ply := -1
var _retry_game: RefCounted
## The plies still to be graded after the game, and how many there were.
var _grade_queue: Array = []
var _grade_total := 0
var _quip_until := 0.0
var _resign_until := 0.0
## The rating before this game's result, and whether the game counts.
var _rating_delta := 0
var _end_args: Array = []
var _practice := false
## The game online, when the level is Record.ONLINE; null against the
## computer (and again once the lobby's "Play the computer" is taken).
var online: Node
## The other seat's moves not played yet: one can land while this seat's own
## is still in the air.
var _inbox: Array[int] = []
## What the other seat said the result was ("won", "lost", "draw" from here),
## for a board that has not got there by its own rules.
var _online_end := ""

func _init(the_level := 1) -> void:
	level = clampi(the_level, 0, Record.ONLINE)

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_rng.randomize()
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Chess", _hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	player = Rules.WHITE if Record.last_colour(GAME) == Rules.WHITE else Rules.BLACK
	if level == Record.ONLINE:
		_go_online()
	else:
		_new_game()
	top_bar.enter(0.0)
	Analytics.track("versus_start", {"game": GAME, "level": level})

func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

# --- building ---

func _build() -> void:
	var page := ColorRect.new()
	page.color = Pal.PAPER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_backdrop = Vistas.board_plate(GAME, Pal.ACCENT)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_backdrop)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_margins.add_child(col)

	# The motto names the moon: a game online has its own.
	top_bar = FlatTopBar.new("Chess", tr("VS_ONLINE_MOTTO" if level == Record.ONLINE else "CHS_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.undo.connect(_on_undo)
	top_bar.reset.connect(_on_reset)
	top_bar.hint.connect(_on_hint)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	var bar_room := MarginContainer.new()
	bar_room.add_theme_constant_override("margin_left", MARGIN)
	bar_room.add_theme_constant_override("margin_right", MARGIN)
	bar_room.add_child(top_bar)
	col.add_child(bar_room)

	var deck := Control.new()
	deck.name = "Deck"
	deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.draw.connect(_draw_deck.bind(deck))
	deck.resized.connect(deck.queue_redraw)
	col.add_child(deck)
	_deck = deck
	_room = MarginContainer.new()
	_room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room.add_theme_constant_override("margin_left", DECK_PAD)
	_room.add_theme_constant_override("margin_right", DECK_PAD)
	_room.add_theme_constant_override("margin_top", 10)
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.add_child(_room)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.add_child(stack)
	# Every button stands above the board, never below it (the user, 2026-10-30).
	_strip = Strip.new()
	_strip.picked.connect(_on_strip)
	stack.add_child(_build_tools())
	stack.add_child(_strip)
	stack.add_child(_build_plate(1))
	board = Board.new()
	board.name = "Board"
	board.skin = ChessSkin.named(Record.skin(GAME))
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.resized.connect(deck.queue_redraw)
	board.chosen.connect(_on_chosen)
	board.settled.connect(_on_settled)
	board.badge_pressed.connect(_on_badge)
	board.refused.connect(func(reason: String) -> void:
		_say(tr("CHS_KING_SAFE") if reason == "king" else tr("CHS_STUCK")))
	stack.add_child(board)
	stack.add_child(_build_plate(0))
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	add_child(_fx)

	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 30, 14))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast_label = Label.new()
	_toast_label.theme_type_variation = "SheetBody"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size.x = 560
	_toast.add_child(_toast_label)
	add_child(_toast)
	_apply_insets()

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_top", GAP + int(insets.x))
	_room.add_theme_constant_override("margin_bottom", 12 + int(insets.y))
	_backdrop.offset_bottom = GAP + insets.x + FlatTopBar.HEIGHT + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The same wooden terrace snooker's table stands on, the whole height of
## the deck: planks with their joints, grain and knots, and petals and
## leaves blown into the room round the board. One mesh, built once a
## layout.
func _draw_deck(deck: Control) -> void:
	if deck.size.x <= 0.0 or board == null or board.used_rect.size.y <= 0.0:
		return
	var key := Rect2(deck.size, board.used_rect.position + board.used_rect.size)
	if _deck_mesh == null or key != _deck_key:
		_deck_key = key
		_deck_mesh = _build_deck(deck.size)
	deck.draw_mesh(_deck_mesh, null)

func _build_deck(sz: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	var radius := 0.0
	var clip := Face.Builder.round_rect(Vector2.ZERO, sz, radius)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	b.fan(clip, Color("a06d45"))
	var plank := 58.0
	var y := 0.0
	while y < sz.y:
		var h := minf(plank, sz.y - y)
		var tone := Color("b98457").lerp(Color("a06d45"), rng.randf())
		_clip_into(b, _plank_rect(Vector2(0.0, y), Vector2(sz.x, h - 3.0)), tone, clip)
		_clip_into(b, _plank_rect(Vector2(0.0, y), Vector2(sz.x, 2.0)), Color(1, 1, 1, 0.12), clip)
		var joint := rng.randf_range(0.2, 0.8) * sz.x
		_clip_into(b, _plank_rect(Vector2(joint, y + 4.0), Vector2(3.0, h - 10.0)), Color(0.3, 0.17, 0.08, 0.35), clip)
		for g in 2:
			var gy := y + h * (0.3 + 0.35 * g) + rng.randf_range(-4.0, 4.0)
			var ph := rng.randf() * TAU
			var x0 := radius + rng.randf_range(0.0, sz.x * 0.3)
			var x1 := minf(sz.x - radius, x0 + rng.randf_range(sz.x * 0.3, sz.x * 0.6))
			var pts := PackedVector2Array()
			var x := x0
			while x <= x1:
				pts.append(Vector2(x, gy + sin(x / 60.0 + ph) * 2.5))
				x += 18.0
			if pts.size() > 1:
				b.stroke(pts, 1.8, Color(0.35, 0.2, 0.1, 0.14))
		if rng.randf() < 0.3:
			var kp := Vector2(rng.randf_range(radius * 2.0, sz.x - radius * 2.0), y + h * 0.5)
			b.stroke(Face.Builder.ring(kp, 13.0, 5.5), 2.0, Color(0.35, 0.2, 0.1, 0.25), true)
		y += plank
	# the edge of the terrace falls into shade
	for k in 3:
		b.stroke(Face.Builder.round_rect(Vector2.ONE * (5.0 + k * 10.0), sz - Vector2.ONE * (10.0 + k * 20.0), radius - 5.0 - k * 10.0),
			10.0, Color(0.25, 0.12, 0.05, 0.08), true)
	# petals and leaves blown on, never under the board; a tournament board
	# stands on a swept floor
	var keep_out := Rect2(board.used_rect.position + Vector2.ONE * DECK_PAD, board.used_rect.size).grow(16.0)
	var placed := 0 if board.skin.cartoon() else 14
	var tries := 0
	while placed < 14 and tries < 300:
		tries += 1
		var p := Vector2(rng.randf_range(40.0, sz.x - 40.0), rng.randf_range(34.0, sz.y - 34.0))
		if keep_out.has_point(p):
			continue
		var ang := rng.randf() * TAU
		var pts := PackedVector2Array()
		var leaf := placed % 3 == 2
		var r := rng.randf_range(18.0, 26.0) if leaf else rng.randf_range(12.0, 17.0)
		for k in 14:
			var a := TAU * float(k) / 14.0
			var rr := r * (0.55 + 0.45 * cos(a * 0.5) * cos(a * 0.5)) if not leaf else r
			pts.append(p + Vector2(cos(a) * rr, sin(a) * rr * (0.42 if leaf else 0.6)).rotated(ang))
		var shade := PackedVector2Array()
		for q in pts:
			shade.append(q + Vector2(2.0, 3.0))
		b.polygon(shade, Color(0.3, 0.15, 0.05, 0.25))
		var col: Color = Pal.LEAF if leaf else (Pal.FLOWER_TILE if placed % 2 == 0 else Pal.FLOWER)
		b.polygon(pts, col)
		if leaf:
			b.stroke(PackedVector2Array([p - Vector2(r * 1.2, 0.0).rotated(ang), p + Vector2(r * 0.8, 0.0).rotated(ang)]), 2.0,
				Color(Pal.LEAF_DEEP, 0.7))
		placed += 1
	return b.mesh()

static func _plank_rect(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])

static func _clip_into(b: Face.Builder, pts: PackedVector2Array, col: Color, clip: PackedVector2Array) -> void:
	for piece in Geometry2D.intersect_polygons(pts, clip):
		b.polygon(piece, col)

## One player's plate, full width: the face, the name and what they are doing,
## and the clock at the end.
func _build_plate(p: int) -> Control:
	var plate := PanelContainer.new()
	plate.custom_minimum_size.y = PLATE_H
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	plate.add_child(inner)
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(FACE_PX, FACE_PX)
	seat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var face: Control = SunFace.new() if p == 0 else MoonFace.new()
	face.size = Vector2(FACE_PX, FACE_PX)
	seat.add_child(face)
	inner.add_child(seat)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -8)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := Label.new()
	name_l.text = "SNK_YOU" if p == 0 else "SNK_BOT"
	name_l.theme_type_variation = "SheetBody"
	name_l.add_theme_font_size_override("font_size", 36)
	var status := Label.new()
	status.theme_type_variation = "CardBlurb"
	status.clip_text = true
	words.add_child(name_l)
	words.add_child(status)
	inner.add_child(words)
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.custom_minimum_size = Vector2(176, 72)
	var digits := Label.new()
	digits.theme_type_variation = "DayBig"
	digits.add_theme_font_size_override("font_size", 46)
	digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	digits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	digits.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pill.add_child(digits)
	inner.add_child(pill)
	_faces.resize(2)
	_status.resize(2)
	_names.resize(2)
	_plates.resize(2)
	_clock_pills.resize(2)
	_clock_labels.resize(2)
	_faces[p] = face
	_status[p] = status
	_names[p] = name_l
	_plates[p] = plate
	_clock_pills[p] = pill
	_clock_labels[p] = digits
	return plate

## The row over the board: back and forward through the moves, what the game is,
## and the pen, the options and Resign. The pen's colours take the words' place
## while it is down, and the review has a row of its own.
func _build_tools() -> Control:
	var foot := Control.new()
	foot.custom_minimum_size.y = TOOL
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tools = HBoxContainer.new()
	_tools.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tools.add_theme_constant_override("separation", 10)
	foot.add_child(_tools)
	_tool_prev = _tool("chevron_left", func() -> void: _step(-1))
	_tool_next = _tool("chevron_right", func() -> void: _step(1))
	_line = Label.new()
	_line.theme_type_variation = "SheetBody"
	_line.add_theme_font_size_override("font_size", 30)
	_line.add_theme_color_override("font_color", Pal.PAPER)
	_line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_line.clip_text = true
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tools.add_child(_line)
	_pen_row = HBoxContainer.new()
	_pen_row.add_theme_constant_override("separation", 8)
	_pen_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pen_row.alignment = BoxContainer.ALIGNMENT_END
	_pen_row.visible = false
	_tools.add_child(_pen_row)
	for i in Board.PEN.size():
		var dot := Button.new()
		dot.focus_mode = Control.FOCUS_NONE
		dot.custom_minimum_size = Vector2(TOOL * 0.8, TOOL * 0.8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.pressed.connect(func() -> void:
			board.pen_colour = i
			_paint_pen())
		_pen_row.add_child(dot)
	var rub := _tool("bin", func() -> void:
		board.clear_pen()
		_fx.buzz(Haptics.TICK))
	rub.reparent(_pen_row)
	_tool_pen = _tool("pencil", _toggle_pen)
	_tool_gear = _tool("gear", _open_options)
	_tool_resign = _tool("cross", _on_resign)
	_review_row = HBoxContainer.new()
	_review_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_review_row.add_theme_constant_override("separation", 10)
	_review_row.visible = false
	foot.add_child(_review_row)
	_tool("chevron_left", func() -> void: _step(-1)).reparent(_review_row)
	_tool("chevron_right", func() -> void: _step(1)).reparent(_review_row)
	_tool("eye", _next_mistake).reparent(_review_row)
	_try_button = Dialog.primary("reset", tr("CHS_TRY_AGAIN"))
	_try_button.custom_minimum_size = Vector2(0.0, TOOL)
	_try_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_try_button.pressed.connect(_try_again)
	_review_row.add_child(_try_button)
	_tool("check", _leave_review).reparent(_review_row)
	return foot

func _tool(icon: String, pressed: Callable) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = Vector2(TOOL, TOOL)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(pressed)
	_tools.add_child(b)
	return b

## Whose turn it is, on the plates: the one to move lit and saying so.
func _refresh_board() -> void:
	var over := _state == State.OVER or _state == State.WAIT or _state == State.RETRY
	var quipping := Time.get_ticks_msec() / 1000.0 < _quip_until
	for p in 2:
		var mine: bool = not over and (rules.turn == player) == (p == 0)
		var box := CozyTheme.lifted(Pal.SURFACE if mine else Color("f7f0e4"), 24, 8)
		if mine:
			box.border_color = Pal.ACCENT_2
			box.set_border_width_all(4)
		_plates[p].add_theme_stylebox_override("panel", box)
		var colour_key := "CHS_COLOUR_WHITE" if (player == Rules.WHITE) == (p == 0) else "CHS_COLOUR_BLACK"
		var line := tr(colour_key)
		if mine:
			line = tr("CHS_TO_MOVE") if p == 0 else tr("CHS_THINKS")
			# Not before the checking piece has landed.
			if rules.in_check() and _state != State.ANIM:
				line = tr("CHS_IN_CHECK")
		if _state == State.WAIT:
			line = ""
		if p == 1 and quipping:
			continue
		_status[p].text = line
		if online != null:
			# The match's minute a move still stands behind the clocks: it
			# shows when it starts to matter.
			online.dress(_status[p], line, mine and _state != State.ENTER and online.seconds(p == 0) <= MOVE_LIMIT_SHOWN, p == 0)
	_names[0].text = tr("SNK_YOU") if online != null else "%s  ·  %d" % [tr("SNK_YOU"), _rating()]
	_paint_clocks()
	_refresh_line()
	top_bar.refresh(self)
	_refresh_tools()

## The tool row's words: the opening, and past it how far the game has got.
func _refresh_line() -> void:
	if _pen_row == null:
		return
	var name_ := Notes.opening_of(_moves.slice(0, 16))
	_line.text = name_ if name_ != "" else tr("CHS_MOVE_N") % rules.fullmove

func _refresh_tools() -> void:
	var some := _sans.size() > 0
	_tool_prev.set_enabled(some and _view != 0)
	_tool_next.set_enabled(_view >= 0)
	_tool_resign.set_enabled(_state != State.OVER and _state != State.WAIT and some)

# --- the top bar's view of this screen (FlatTopBar.refresh) ---

func capabilities() -> Array:
	return ["undo", "hint"]

func is_done() -> bool:
	return _state == State.OVER

func is_solved() -> bool:
	return false

## Undo, the bulb and Reset are the computer's games' alone: online they
## stay on the bar, greyed.
func can_undo() -> bool:
	return online == null and not _clocked and _state == State.YOURS and _history.size() >= (2 if player == Rules.WHITE else 3)

func hints_left() -> int:
	return _hints if _state == State.YOURS and online == null and not _clocked else 0

## The bulb's badge: the count stays up while the bulb waits its turn.
func hints_held() -> int:
	return _hints if online == null and not _clocked else 0

## Reset waits out a move in the air, as `_on_reset` does.
func can_reset() -> bool:
	return online == null and _state != State.ANIM and _state != State.REWIND

## The card's pages (ui/hud/chess_tutorial_diagram.gd): the board itself on
## a few pieces. The levels change only how well the computer plays, so the
## pages are the same on all three.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/chess_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.MOVE, "TUT_CHESS_MOVE", tr("TUT_CHESS_MOVE_BODY")],
		[Diagram.Lesson.LINES, "TUT_CHESS_LINES", tr("TUT_CHESS_LINES_BODY")],
		[Diagram.Lesson.STEPS, "TUT_CHESS_STEPS", tr("TUT_CHESS_STEPS_BODY")],
		[Diagram.Lesson.CHECK, "TUT_CHESS_CHECK", tr("TUT_CHESS_CHECK_BODY")],
		[Diagram.Lesson.SPECIAL, "TUT_CHESS_SPECIAL", tr("TUT_CHESS_SPECIAL_BODY")],
		[Diagram.Lesson.DRAW, "TUT_CHESS_DRAW", tr("TUT_CHESS_DRAW_BODY")],
		[Diagram.Lesson.BAR, "TUT_CHESS_BAR", tr("TUT_CHESS_BAR_BODY") % HINTS],
		[Diagram.Lesson.MOVE, "TUT_CHESS_TOOLS", tr("TUT_CHESS_TOOLS_BODY")],
	]
	var pages := []
	for step: Array in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.skin = board.skin
		d.hints = HINTS
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

# --- the game ---

func _new_game() -> void:
	if online == null:
		match Options.colour():
			1:
				player = Rules.WHITE
			2:
				player = Rules.BLACK
	_lay(State.ENTER)
	if Motion.reduce:
		_start_turn.call_deferred()

## A fresh set on the board: dropping in for a game (ENTER), or simply
## there, for the lobby to stand over (WAIT).
func _lay(state: State) -> void:
	_game += 1
	rules = Rules.new()
	_history.clear()
	_inbox.clear()
	_online_end = ""
	_hints = HINTS
	_hint_move = -1
	_undos = 0
	_state = state
	_moves = []
	_sans = []
	_grades = {}
	_judge_game = null
	_view = -1
	_reviewing = false
	_grade_queue = []
	_practice = false
	_quip_until = 0.0
	_strip.clear()
	_set_clock()
	_review_row.visible = false
	_tools.visible = true
	board.eval_bar = -1.0
	board.clear_pen()
	board.clear_premoves()
	board.premoving = false
	if _end != null:
		_end.queue_free()
		_end = null
	for f in _faces:
		f.expression = Face.Expr.HAPPY
	board.interactive = false
	board.setup(rules, player, state == State.ENTER)
	_refresh_board()

func _on_settled() -> void:
	match _state:
		State.RETRY:
			_retry_settled()
		State.ENTER:
			_start_turn()
		State.ANIM:
			_after_move()
		State.REWIND:
			if _rewinds > 0:
				_rewind_one()
			else:
				_start_turn()

func _start_turn() -> void:
	var status: int = rules.status()
	if status != Rules.PLAYING:
		_finish(status)
		return
	var mine: bool = rules.turn == player
	if online != null and _online_end != "" and (mine or _inbox.is_empty()):
		# The other seat said the game is over, every move it sent has been
		# played, and by this board's rules -- the same rules -- it is not.
		_online_end = ""
		online.foul()
		return
	if mine:
		_state = State.YOURS
		board.interactive = true
		_show_verdict()
		if _take_premove():
			return
		board.turn_came()
		if rules.in_check():
			_say(tr("CHS_CHECK"))
		elif _history.size() < 2:
			_say(tr("CHS_YOUR_MOVE"))
	else:
		_state = State.THINK
		board.interactive = false
		board.premoving = _can_premove()
		board.set_thinking(true)
		if _history.is_empty():
			_say(tr("CHS_BOT_FIRST") if online == null else online.first_line())
		if online == null:
			_think("ai")
		else:
			_take_online()
	_refresh_board()

func _on_chosen(m: int) -> void:
	if _state == State.RETRY:
		_retry_chosen(m)
		return
	if _state != State.YOURS:
		return
	# One knock a move: a tap as it is chosen, unless the move earns the
	# board's bump (a capture, a promotion).
	var d: Dictionary = rules.describe(m)
	if int(d.captured) == 0 and int(d.promo) == 0:
		_fx.buzz(Haptics.TAP)
	_play(m)

func _play(m: int) -> void:
	_back_to_live()
	var d: Dictionary = rules.describe(m)
	var hand := int(d.side) == player
	if hand and online == null and Options.on("grades"):
		_judge_game = rules.copy()
		_judge_ply = _moves.size()
	_moves.append(m)
	_sans.append(Notes.san(rules, m))
	if _clocked and _moves.size() > 2:
		_clock[0 if hand else 1] += _increment
	rules.make(m)
	_history.append(d)
	_strip.set_moves(_sans)
	_state = State.ANIM
	board.interactive = false
	board.premoving = _can_premove()
	board.set_hint(-1)
	_hint_move = -1
	_hush()
	board.play(d)
	if online != null and hand:
		online.send({"m": m})
	_refresh_board()
	if int(d.captured) != 0:
		var taker := 0 if hand else 1
		_react(taker, Face.Expr.JOY)
		_react(1 - taker, Face.Expr.WORRIED)

func _after_move() -> void:
	if rules.in_check():
		var king: int = rules.kings[rules.turn]
		board.set_check(king)
		board.tremble(king)
		_fx.cue("check")
		# Their check on you is a warn; a mate is the lose alone.
		if rules.turn == player and rules.status() == Rules.PLAYING:
			_fx.buzz(Haptics.WARN)
		_react(0 if rules.turn == player else 1, Face.Expr.WORRIED)
	else:
		board.set_check(-1)
	_start_turn()

## A face on the scoreboard shows `expr` for a moment.
func _react(p: int, expr: int) -> void:
	var face: Control = _faces[p]
	face.expression = expr
	var game := _game
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(face) and _game == game and _state != State.OVER:
			face.expression = Face.Expr.HAPPY)

# --- thinking, for the computer and the hint ---

func _process(delta: float) -> void:
	# The computer's answer waits while the tutorial card is up, so no move
	# is played (or heard) behind a page.
	if not _held:
		_poll_think()
		_tick_clock(delta)
	if _quip_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _quip_until:
		_quip_until = 0.0
		_refresh_board()

func _hold(on: bool) -> void:
	_held = on

func _think(kind: String) -> void:
	if _task != -1:
		return
	var copy: RefCounted = rules.copy()
	var lv := level if kind == "ai" else 2
	var budget := -1 if kind == "ai" else AI.HINT_BUDGET_MS
	var seed := _rng.randi()
	var box: Array = [-1, {}]
	_box = box
	_task_for = kind
	_task_game = _game
	_think_at = Time.get_ticks_msec() / 1000.0
	var played: Array = _moves.duplicate()
	if kind == "ai" and _clocked:
		# Never more than its share of what is left on its clock.
		budget = mini(AI.BUDGET_MS[level], maxi(int(_clock[1] * 1000.0 / 30.0 + _increment * 500.0), 40))
	var judging: RefCounted = _judge_game if kind == "ai" else null
	var judged_move: int = _moves[_judge_ply] if judging != null else -1
	var judged_ply := _judge_ply
	_judge_game = null
	var in_book := judging != null and _in_book(judged_ply)
	_task = WorkerThreadPool.add_task(func() -> void:
		box[0] = AI.new().plan(copy, lv, seed, budget, played)
		if judging != null:
			var j: Dictionary = {"grade": Grade.BOOK, "best": judged_move, "score": 0, "cost": 0.0, "chance": 50.0} \
				if in_book else Grade.judge(judging, judged_move, seed)
			j["ply"] = judged_ply
			box[1] = j)

func _poll_think() -> void:
	if _task == -1 or not WorkerThreadPool.is_task_completed(_task):
		return
	var kind := _task_for
	if kind == "ai" and Time.get_ticks_msec() / 1000.0 - _think_at < THINK_MIN:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var m: int = _box[0]
	if _task_game == _game and not (_box[1] as Dictionary).is_empty():
		_note_verdict(_box[1])
	if kind == "grade":
		_grade_next()
		return
	if kind == "retry":
		_retry_judged()
		return
	if kind == "ai" and _task_game == _game and _state == State.THINK and m >= 0:
		_bot_moves(m)
		return
	if kind == "hint" and _task_game == _game and _state == State.YOURS and m >= 0:
		_hint_move = m
		_practice = true
		board.set_hint(m)
		_fx.cue("hint")
		_say(tr("CHS_HINT_LINE"))
	if _state == State.THINK:
		_think("ai")

## The computer picks its piece up, holds it a beat, and moves.
func _bot_moves(m: int) -> void:
	board.set_thinking(false)
	# A cartoon holds its piece up a beat; on a clock nobody waits for that.
	if not board.skin.cartoon() or _clocked or Motion.reduce:
		_play(m)
		return
	_state = State.ANIM
	board.set_lifted(Rules.mv_from(m))
	var game := _game
	get_tree().create_timer(PONDER).timeout.connect(func() -> void:
		# An online game can end (a resignation, a clock) inside the beat.
		if _game != game or not is_inside_tree() or _state != State.ANIM:
			return
		_state = State.THINK
		_play(m))

func _on_hint() -> void:
	if _state != State.YOURS or _task != -1 or online != null:
		return
	if _hint_move >= 0:
		board.set_hint(_hint_move)
		_say(tr("CHS_HINT_LINE"))
		return
	if _hints <= 0:
		return
	_hints -= 1
	top_bar.refresh(self)
	_say(tr("CHS_THINKING"))
	_think("hint")
	Analytics.track("hint_used", {"puzzle_id": GAME, "hints": HINTS - _hints})

# --- undo ---

## Takes back your last move and the computer's answer to it.
func _on_undo() -> void:
	if not can_undo():
		return
	_undos += 1
	_practice = true
	_rewinds = 2
	board.clear_premoves()
	_back_to_live()
	_state = State.REWIND
	_fx.buzz(Haptics.TICK)
	board.interactive = false
	board.set_hint(-1)
	_hint_move = -1
	_hush()
	_rewind_one()
	Analytics.track("undo_used", {"puzzle_id": GAME, "undos": _undos})

func _rewind_one() -> void:
	_rewinds -= 1
	var d: Dictionary = _history.pop_back()
	rules.unmake()
	_moves.pop_back()
	_sans.pop_back()
	_grades.erase(_moves.size())
	_strip.grades.erase(_moves.size())
	_strip.set_moves(_sans)
	board.rewind(d)
	if rules.in_check():
		board.set_check(rules.kings[rules.turn])
	_refresh_board()

# --- online (level 3): what is chess's own; the rest is versus/online/online.gd ---

func _go_online() -> void:
	online = Online.new(self, GAME)
	online.set_bank(ONLINE_CLOCK[0], ONLINE_CLOCK[1])
	online.seeking.connect(_on_online_seeking)
	online.started.connect(_on_online_started)
	online.move.connect(_on_online_move)
	online.over.connect(_on_online_over)
	online.ticked.connect(_on_online_ticked)
	online.computer.connect(_play_computer)
	online.closed.connect(func() -> void: closed.emit())
	add_child(online)
	online.open()

## Looking for a player (the first time, and Find another): a still set
## under the lobby, nobody in the far seat yet.
func _on_online_seeking() -> void:
	_seat_rival("")
	_lay(State.WAIT)

## Found: the seat that opens is white, and the game begins as any does.
func _on_online_started() -> void:
	player = Rules.WHITE if online.opens() else Rules.BLACK
	online.set_bank(ONLINE_CLOCK[0], ONLINE_CLOCK[1])
	_seat_rival(online.opponent)
	_new_game()

## The far plate's face and name: the other player's, or the moon's.
func _seat_rival(uid: String) -> void:
	var seat: Control = _faces[1].get_parent()
	seat.remove_child(_faces[1])
	_faces[1].queue_free()
	var face: Control = MoonFace.new()
	if uid.is_empty():
		_names[1].add_theme_font_size_override("font_size", 36)
		_names[1].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
		# Nobody yet while the lobby looks: the bot is not who is coming.
		_names[1].text = "SNK_BOT" if online == null else "…"
		face.visible = online == null
	else:
		face = online.face(FACE_PX)
		Online.fit(_names[1], online.rival(), NAME_W)
	face.size = Vector2(FACE_PX, FACE_PX)
	seat.add_child(face)
	_faces[1] = face

## The other seat's move. It is played when the board is ready for it.
func _on_online_move(d: Dictionary) -> void:
	var m: Variant = d.get("m")
	_inbox.append(int(m) if typeof(m) == TYPE_FLOAT or typeof(m) == TYPE_INT else -1)
	_take_online()

## Plays the next move waiting, if it is the other seat's turn to be seen
## moving. The move must be one this end's rules list, whole: the same from,
## to, promotion and flags. Anything else is a foul.
func _take_online() -> void:
	if _state != State.THINK or _inbox.is_empty():
		return
	var m: int = _inbox.pop_front()
	if not rules.legal_moves().has(m):
		online.foul()
		return
	_bot_moves(m)

## The match ended without this board ending it. A resignation, a clock or a
## player gone ends the game where it stands. "end" is the other seat's word
## that the game finished on the board, and it is not taken on trust: the
## rules let the seat that moved last write it with any winner, but both ends
## run the same rules, so a real ending is one this board reaches by itself
## once the last move has been played (`_start_turn` finishes on its own
## status, and the result shown is this board's). An "end" this board does
## not reach, with nothing left to play, is a foul.
func _on_online_over(outcome: String, why: String) -> void:
	if _state == State.OVER:
		return
	if why != "end":
		# A clock that ran out is said by a resignation: the rules take a
		# timeout only past the minute a move.
		var out_of_time: bool = online.flagged >= 0 or (why == "resign" and online.bank(outcome != "won") < 2.0)
		_conclude(outcome, "", -1, "flag" if out_of_time and why == "resign" else why)
		return
	_online_end = outcome
	if _state == State.YOURS or (_state == State.THINK and _inbox.is_empty()):
		_online_end = ""
		online.foul()

func _on_online_ticked() -> void:
	if _state != State.OVER and _state != State.WAIT:
		_refresh_board()

## The lobby's "Play the computer": the level last played against it, and a
## game as if that chip had been picked.
func _play_computer() -> void:
	online.queue_free()
	online = null
	level = Record.last_bot_level(GAME)
	_seat_rival("")
	_set_clock()
	top_bar.set_motto(tr("CHS_MOTTO"))
	Analytics.track("versus_start", {"game": GAME, "level": level})
	_new_game()
	tutor.first_play()

# --- the end ---

func _finish(status: int) -> void:
	var outcome := "draw"
	var reason := ""
	var king := -1
	match status:
		Rules.MATE:
			var loser: int = rules.turn
			king = rules.kings[loser]
			outcome = "lost" if loser == player else "won"
		Rules.STALEMATE:
			reason = "CHS_DRAW_STALEMATE"
		Rules.FIFTY:
			reason = "CHS_DRAW_FIFTY"
		Rules.REPETITION:
			reason = "CHS_DRAW_REPEAT"
		_:
			reason = "CHS_DRAW_MATERIAL"
	_conclude(outcome, reason, king, "")

## The game is over: "won", "lost" or "draw". On the board, `reason` is a
## draw's and `king` the mated king's square; online and off the board, `why`
## is what the match said ("resign", "timeout", "left", "end").
func _conclude(outcome: String, reason: String, king: int, why: String) -> void:
	# The seat that made the last move: the side not to move now.
	var mine_last: bool = rules.turn != player
	_state = State.OVER
	_back_to_live()
	board.interactive = false
	board.premoving = false
	board.clear_premoves()
	board.set_thinking(false)
	board.finish(outcome, king)
	_rating_delta = 0
	if online == null and not _practice:
		_rating_delta = _rate(outcome)
	_refresh_board()
	if online != null:
		online.settle(outcome, why, rules.fullmove, mine_last)
	else:
		if outcome == "draw":
			Record.add_draw(GAME, level)
		else:
			Record.add(GAME, level, outcome == "won")
		Analytics.track("versus_end", {"game": GAME, "level": level, "won": outcome == "won",
			"result": outcome, "moves": rules.fullmove, "undos": _undos,
			"colour": "white" if player == Rules.WHITE else "black"})
	Ads.note_finished()
	_fx.cue({"won": "win", "lost": "lose", "draw": "draw"}[outcome])
	_faces[0].expression = Face.Expr.JOY if outcome == "won" else (Face.Expr.WORRIED if outcome == "lost" else Face.Expr.SLEEPY)
	_faces[1].expression = Face.Expr.JOY if outcome == "lost" else (Face.Expr.WORRIED if outcome == "won" else Face.Expr.SLEEPY)
	if reason != "":
		_say(tr(reason))
	var game := _game
	var wait := MATE_WAIT if king >= 0 else END_WAIT
	get_tree().create_timer(0.3 if Motion.reduce else wait).timeout.connect(func() -> void:
		if _game != game or not is_inside_tree():
			return
		_show_end(outcome, reason, why, true))

func _show_end(outcome: String, reason: String, why: String, party: bool) -> void:
	_end_args = [outcome, reason, why]
	_end = _build_end(outcome, reason, why)
	add_child(_end)
	Motion.appear(_end, 0.0, 1.0, 0.3)
	if party:
		_celebrate(outcome == "won")

func _build_end(outcome: String, reason: String, why := "") -> Control:
	var scrim := Dialog.scrim()
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(820)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(0, 130)
	var face: Control = SunFace.new()
	if outcome == "lost":
		face = MoonFace.new() if online == null else online.face(130)
	face.size = Vector2(130, 130)
	face.position = Vector2(820 * 0.5 - 40 - 65, 0)
	face.expression = Face.Expr.SLEEPY if outcome == "draw" else Face.Expr.JOY
	seat.add_child(face)
	col.add_child(seat)
	var head := Label.new()
	head.text = {"won": "CHS_WIN", "lost": "CHS_LOSE", "draw": "CHS_DRAW"}[outcome]
	if online != null:
		head.text = online.head(outcome)
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var said := Label.new()
	said.text = tr(reason) if reason != "" else tr("CHS_MATE_IN") % rules.fullmove
	# Off the board there was no mate: the match's own reason, if it has words.
	if online != null and why != "":
		said.text = online.why_line(why, outcome)
		said.visible = said.text != ""
	said.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	said.theme_type_variation = "SheetBody"
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(said)
	var line := Label.new()
	line.text = "%s  ·  %s" % [tr(LEVELS[level]), Record.record_line(GAME, level)]
	if online == null and not _practice:
		line.text += "  ·  %d (%+d)" % [_rating(), _rating_delta]
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var tally := Label.new()
	tally.text = _tally_line()
	tally.visible = tally.text != ""
	tally.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tally.theme_type_variation = "SheetBodyDim"
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tally)
	var again: Button
	if online != null:
		again = online.again_button()  # Find another
	else:
		again = Dialog.primary("reset", tr("SNK_AGAIN"))
		again.pressed.connect(func() -> void:
			player = 1 - player
			Record.set_last_colour(GAME, player)
			_fx.buzz(Haptics.TAP)
			_new_game())
	var back := Dialog.secondary("chevron_left", tr("SNK_BACK"))
	back.pressed.connect(_on_back)
	var review := Dialog.secondary("eye", tr("CHS_REVIEW"))
	review.pressed.connect(_enter_review)
	review.visible = _moves.size() >= 2
	var stack := Dialog.buttons(col, again, review)
	back.size_flags_horizontal = Control.SIZE_FILL
	stack.add_child(back)
	return scrim

func _celebrate(won: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not won:
		return
	var fx := Fx2D.new()
	_end.add_child(fx)
	var cols := [Pal.KNIGHT_CREAM, Pal.KNIGHT_ROSE, Pal.CROWN, Pal.LEAF, Pal.SUN_RAY]
	var mid := size * 0.5
	for k in 8:
		var at := mid + Vector2.from_angle(TAU * k / 8.0 - PI * 0.5) * Vector2(400.0, 330.0)
		var t := get_tree().create_timer(0.25 + 0.14 * k)
		t.timeout.connect(func() -> void:
			if is_instance_valid(fx):
				fx.puff(at, cols[k % cols.size()], 12))

# --- the clock ---

## Reads the clock for this game: what the options say, or the one an online
## game has. A game with a clock has no undo and no hints.
func _set_clock() -> void:
	var control: Array = ONLINE_CLOCK if online != null else Options.CONTROLS[Options.control()]
	_clocked = int(control[0]) > 0
	_clock = [float(control[0]), float(control[0])]
	_increment = float(control[1])
	_warned = false
	board.clock_full = float(control[0])
	_tell_board_clock()
	for pill in _clock_pills:
		pill.visible = _clocked

func _clock_running() -> bool:
	return _clocked and online == null and _moves.size() >= 2 and _state in [State.YOURS, State.THINK, State.ANIM]

func _tell_board_clock() -> void:
	board.clock_left = _clock

func _tick_clock(delta: float) -> void:
	_tell_board_clock()
	if online != null:
		_paint_clocks()
		return
	if not _clock_running() or settings_sheet.is_open() or (_options != null and _options.is_open()):
		return
	var p := 0 if rules.turn == player else 1
	_clock[p] -= minf(delta, 0.25)
	if p == 0 and _clock[0] <= BUZZ_AT and not _warned:
		_warned = true
		Haptics.play(Haptics.WARN)
	_paint_clocks()
	if _clock[p] <= 0.0:
		_clock[p] = 0.0
		_flag(p)

## Out of time. The other side wins, if it has anything to mate with.
func _flag(p: int) -> void:
	var taker: int = player if p == 1 else 1 - player
	if rules.material(taker) == 0:
		_conclude("draw", "CHS_FLAG_DRAW", -1, "")
	else:
		_conclude("lost" if p == 0 else "won", "CHS_FLAG_LOST" if p == 0 else "CHS_FLAG_WON", -1, "")

func _paint_clocks() -> void:
	if not _clocked:
		return
	var on: int = -1 if _state in [State.OVER, State.WAIT, State.ENTER, State.RETRY] else (0 if rules.turn == player else 1)
	for p in 2:
		var left: float = _clock[p] if online == null else online.bank(p == 0)
		var low := left < CLOCK_LOW
		var running := p == on
		var fill: Color = Pal.BAD if running and low else (Color("2f2a26") if running else Color("ece3d4"))
		var ink: Color = Pal.PAPER if running else Pal.TEXT
		var text := _clock_text(left)
		if _clock_labels[p].text != text or _clock_ink[p] != ink:
			_clock_labels[p].text = text
			_clock_ink[p] = ink
			_clock_labels[p].add_theme_color_override("font_color", ink)
			_clock_pills[p].add_theme_stylebox_override("panel", CozyTheme.lifted(fill, 18, 6))

## Minutes and seconds, tenths in the last ten seconds.
static func _clock_text(left: float) -> String:
	var t := maxf(left, 0.0)
	if t < 10.0:
		return "0:%04.1f" % (floorf(t * 10.0) / 10.0)
	var whole := ceili(t)
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]

# --- moves queued for your turn ---

func _can_premove() -> bool:
	return _state != State.OVER and Options.on("premoves") and _view < 0 and not _reviewing

## Plays the first queued move if it is legal now, and takes the whole queue
## back if it is not. True when a move went off.
func _take_premove() -> bool:
	if board.pre.is_empty():
		return false
	var q: Array = board.pre.pop_front()
	var found := -1
	for m in rules.legal_moves():
		if Rules.mv_from(m) == q[0] and Rules.mv_to(m) == q[1] and Rules.mv_promo(m) in [0, Rules.QUEEN]:
			found = m
			break
	if found < 0:
		board.clear_premoves()
		_say(tr("CHS_PRE_OFF"))
		_fx.cue("refused")
		return false
	board.snap_next()
	_on_chosen(found)
	return true

# --- the pen ---

func _toggle_pen() -> void:
	board.pen = not board.pen
	_line.visible = not board.pen
	_pen_row.visible = board.pen
	_paint_pen()

func _paint_pen() -> void:
	_tool_pen.set_icon("check" if board.pen else "pencil")
	for i in Board.PEN.size():
		var dot: Button = _pen_row.get_child(i)
		var box := StyleBoxFlat.new()
		box.bg_color = Board.PEN[i]
		box.set_corner_radius_all(40)
		box.border_color = Pal.PAPER
		box.set_border_width_all(6 if board.pen_colour == i else 0)
		for state in ["normal", "hover", "pressed"]:
			dot.add_theme_stylebox_override(state, box)

# --- the score sheet ---

func _on_strip(ply: int) -> void:
	_show_ply(-1 if ply == _moves.size() - 1 and not _reviewing else ply)

func _step(by: int) -> void:
	var at: int = (_moves.size() - 1 if _view < 0 else _view) + by
	if at < -1 or at >= _moves.size():
		return
	_show_ply(-1 if at == _moves.size() - 1 and not _reviewing else maxi(at, 0))

## The board after `ply`, -1 for the game as it stands.
func _show_ply(ply: int) -> void:
	if ply < 0:
		_back_to_live()
	else:
		_view = ply
		board.interactive = false
		board.premoving = false
		var g: RefCounted = Rules.new()
		for i in ply + 1:
			g.make(_moves[i])
		board.show_position(g, player, _history.slice(0, ply + 1))
		board.mark_fallen(-1)
		_strip.set_current(ply)
		if _reviewing:
			_show_review_ply(ply)
	_refresh_tools()

## Back to the game after a look at a past move.
func _back_to_live() -> void:
	if _view < 0:
		return
	_view = -1
	_strip.set_current(-1)
	board.show_position(rules, player, _history)
	board.set_check(rules.kings[rules.turn] if rules.in_check() else -1)
	board.interactive = _state == State.YOURS
	board.premoving = _can_premove() and _state != State.YOURS

# --- the verdicts ---

## Whether `ply` is a move the book knows, every move up to it included.
func _in_book(ply: int) -> bool:
	var line := Notes.line_of(_moves.slice(0, ply + 1))
	for row: Array in Notes.BOOK:
		if String(row[1]) == line or String(row[1]).begins_with(line + " "):
			return true
	return false

func _note_verdict(j: Dictionary) -> void:
	var ply: int = j.ply
	_grades[ply] = j
	_strip.set_grade(ply, j.grade)
	if online != null or _state == State.OVER:
		return
	match int(j.grade):
		Grade.BLUNDER:
			_quip("CHS_Q_BLUNDER", 3)
		Grade.MISTAKE:
			_quip("CHS_Q_MISTAKE", 2)
		Grade.BRILLIANT, Grade.GREAT:
			_quip("CHS_Q_GREAT", 2)

## A line of the moon's on its plate, one of `count`.
func _quip(key: String, count: int) -> void:
	_status[1].text = tr("%s_%d" % [key, 1 + _rng.randi() % count])
	_quip_until = Time.get_ticks_msec() / 1000.0 + QUIP_HOLD
	_react(1, Face.Expr.JOY if key != "CHS_Q_GREAT" else Face.Expr.WORRIED)

## On your turn: the badge on your last move, and what is hanging.
func _show_verdict() -> void:
	if online != null:
		return
	var ply := _moves.size() - 2
	if Options.on("grades") and ply >= 0 and _grades.has(ply) and int(_history[ply].side) == player:
		board.set_badge(int(_history[ply].to), _grades[ply].grade)
	if Options.on("threats") and level < 2:
		board.set_arrows([], _hanging())

## Your pieces that can be taken for nothing, or by something cheaper, as
## [attacker, piece]; two at most, the dearest first.
func _hanging() -> Array:
	var rows: Array = []
	for sq in 64:
		var p: int = rules.board[sq]
		if p == 0 or Rules.side_of(p) != player or absi(p) == Rules.KING or absi(p) == Rules.PAWN:
			continue
		var worth: int = Grade.WORTH[absi(p)]
		var attackers: PackedInt32Array = rules.attackers_of(sq, 1 - player)
		if attackers.is_empty():
			continue
		var cheapest: int = attackers[0]
		for from in attackers:
			if Grade.WORTH[absi(rules.board[from])] < Grade.WORTH[absi(rules.board[cheapest])]:
				cheapest = from
		if not rules.attacked(sq, player) or Grade.WORTH[absi(rules.board[cheapest])] < worth:
			rows.append([worth, cheapest, sq])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out: Array = []
	for row: Array in rows.slice(0, 2):
		out.append([row[1], row[2]])
	return out

## The badge says what was wrong: the stronger move, for nothing.
func _on_badge() -> void:
	var ply := _moves.size() - 2 if _state == State.YOURS else _moves.size() - 1
	if not _grades.has(ply):
		return
	var j: Dictionary = _grades[ply]
	board.set_arrows([[Rules.mv_from(j.best), Rules.mv_to(j.best), Color(Board.PEN[0], 0.8)]])
	_say(tr("CHS_BETTER") % Notes.san(_before(ply), j.best))
	_fx.cue("hint")

## The position before `ply`.
func _before(ply: int) -> RefCounted:
	var g: RefCounted = Rules.new()
	for i in ply:
		g.make(_moves[i])
	return g

## The moves made by you that have verdicts, as costs.
func _my_costs() -> Array:
	var costs: Array = []
	for ply: int in _grades:
		if int(_history[ply].side) == player and int(_grades[ply].grade) != Grade.BOOK:
			costs.append(float(_grades[ply].cost))
	return costs

## "Accuracy 86%  ·  1 brilliant  ·  2 mistakes", for the end card and the review.
func _tally_line() -> String:
	var costs := _my_costs()
	if costs.is_empty():
		return ""
	var counts := {}
	for ply: int in _grades:
		if int(_history[ply].side) == player:
			var g: int = _grades[ply].grade
			counts[g] = int(counts.get(g, 0)) + 1
	var parts := PackedStringArray([tr("CHS_ACCURACY") % Grade.accuracy(costs)])
	for g: int in [Grade.BRILLIANT, Grade.GREAT, Grade.INACCURACY, Grade.MISTAKE, Grade.BLUNDER]:
		if counts.has(g):
			parts.append("%d %s %s" % [counts[g], Grade.SYMBOL[g], tr(Grade.KEY[g])])
	return "  ·  ".join(parts)

# --- rating ---

func _rating() -> int:
	return roundi(float(Record.option(GAME, "rating", START_RATING)))

## Moves your rating for `outcome` against this level; what it moved by.
func _rate(outcome: String) -> int:
	var mine := float(Record.option(GAME, "rating", START_RATING))
	var theirs := float(BOT_RATING[clampi(level, 0, 2)])
	var expected := 1.0 / (1.0 + pow(10.0, (theirs - mine) / 400.0))
	var scored: float = {"won": 1.0, "draw": 0.5, "lost": 0.0}[outcome]
	var after := mine + RATING_K * (scored - expected)
	Record.set_option(GAME, "rating", after)
	return roundi(after) - roundi(mine)

# --- the review ---

func _enter_review() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	_reviewing = true
	_tools.visible = false
	_review_row.visible = true
	_grade_queue = []
	for ply in _moves.size():
		if int(_history[ply].side) == player and not _grades.has(ply):
			_grade_queue.append(ply)
	_grade_total = _grade_queue.size()
	_show_ply(_first_slip(0))
	_grade_next()

## The first of your moves from `from` on that went wrong, else the last.
func _first_slip(from: int) -> int:
	for ply in range(from, _moves.size()):
		if _grades.has(ply) and int(_grades[ply].grade) >= Grade.INACCURACY and int(_history[ply].side) == player:
			return ply
	return _moves.size() - 1

func _next_mistake() -> void:
	var from := _view + 1
	var ply := _first_slip(from)
	if ply == _moves.size() - 1 and from <= ply:
		ply = _first_slip(0)
	_show_ply(ply)

## Grades the next of your moves not yet graded, one on the worker at a time.
func _grade_next() -> void:
	if _grade_queue.is_empty() or _task != -1 or not _reviewing:
		if _reviewing and _view >= 0:
			_show_review_ply(_view)
		return
	var ply: int = _grade_queue.pop_front()
	var g := _before(ply)
	var m: int = _moves[ply]
	var seed := _rng.randi()
	var box: Array = [-1, {}]
	_box = box
	_task_for = "grade"
	_task_game = _game
	var book := _in_book(ply)
	_task = WorkerThreadPool.add_task(func() -> void:
		var j: Dictionary = {"grade": Grade.BOOK, "best": m, "score": 0, "cost": 0.0, "chance": 50.0} if book else Grade.judge(g, m, seed)
		j["ply"] = ply
		box[1] = j)
	if _view >= 0:
		_show_review_ply(_view)

## What the review says at `ply`: the badge, the stronger move in green and
## what was played in red, the bar, and Try again on a slip of yours.
func _show_review_ply(ply: int) -> void:
	var words := _tally_line()
	if not _grade_queue.is_empty():
		words = tr("CHS_REVIEWING") % [_grade_total - _grade_queue.size(), _grade_total]
	_status[0].text = words
	_status[1].text = Notes.opening_of(_moves.slice(0, 16))
	var mine := int(_history[ply].side) == player
	var arrows: Array = []
	var can_try := false
	if _grades.has(ply):
		var j: Dictionary = _grades[ply]
		board.set_badge(int(_history[ply].to), j.grade)
		if int(j.best) >= 0 and int(j.best) != _moves[ply] and int(j.grade) >= Grade.INACCURACY:
			arrows.append([Rules.mv_from(j.best), Rules.mv_to(j.best), Color(Board.PEN[0], 0.82)])
			arrows.append([int(_history[ply].from), int(_history[ply].to), Color(Board.PEN[2], 0.7)])
			can_try = mine
		var white := float(j.chance) if int(_history[ply].side) == Rules.WHITE else 100.0 - float(j.chance)
		board.eval_bar = white
	else:
		board.set_badge(-1, -1)
	board.set_arrows(arrows)
	_try_button.disabled = not can_try

func _leave_review() -> void:
	_reviewing = false
	_review_row.visible = false
	_tools.visible = true
	board.eval_bar = -1.0
	board.set_arrows([])
	_view = 0
	_back_to_live()
	_show_end(_end_args[0], _end_args[1], _end_args[2], false)

## Your slip's position again, and the move to find.
func _try_again() -> void:
	if _view < 0 or _state != State.OVER:
		return
	_retry_ply = _view
	_retry_game = _before(_view)
	_state = State.RETRY
	board.show_position(_retry_game, player, _history.slice(0, _view))
	board.set_arrows([])
	board.set_badge(-1, -1)
	board.eval_bar = -1.0
	board.interactive = true
	_say(tr("CHS_FIND_BETTER"))
	_refresh_tools()

func _retry_chosen(m: int) -> void:
	board.interactive = false
	var d: Dictionary = _retry_game.describe(m)
	var g: RefCounted = _retry_game.copy()
	_retry_game.make(m)
	board.play(d)
	var seed := _rng.randi()
	var box: Array = [-1, {}]
	_box = box
	_task_for = "retry"
	_task_game = _game
	_task = WorkerThreadPool.add_task(func() -> void:
		var j: Dictionary = Grade.judge(g, m, seed)
		box[0] = j.grade)

func _retry_settled() -> void:
	pass

func _retry_judged() -> void:
	var good: bool = int(_box[0]) <= Grade.GOOD
	_say(tr("CHS_FOUND_IT") if good else tr("CHS_NOT_QUITE"))
	_fx.cue("hint" if good else "refused")
	var game := _game
	get_tree().create_timer(1.3).timeout.connect(func() -> void:
		if _game != game or not is_inside_tree() or _state != State.RETRY:
			return
		_state = State.OVER
		if good:
			_show_ply(_retry_ply)
		else:
			_try_again())

# --- resigning and the options ---

func _on_resign() -> void:
	if _state == State.OVER or _state == State.WAIT or _sans.is_empty():
		return
	if online != null:
		online.ask_leave(rules.fullmove)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now > _resign_until:
		_resign_until = now + RESIGN_HOLD
		_say(tr("CHS_RESIGN_ASK"))
		return
	_resign_until = 0.0
	_conclude("lost", "CHS_RESIGNED", -1, "")

func _open_options() -> void:
	if _options == null:
		_options = Options.new()
		_options.name = "Options"
		add_child(_options)
		_options.changed.connect(_on_options)
	_options.open()

func _on_options() -> void:
	if board.skin.id() != Record.skin(GAME):
		board.set_skin(ChessSkin.named(Record.skin(GAME)))
		_deck_mesh = null
		_deck_key = Rect2()
		_deck.queue_redraw()
	# A clock chosen before the first move takes at once.
	if _sans.is_empty() and online == null and _state != State.OVER:
		_set_clock()
		_refresh_board()
	if not Options.on("premoves"):
		board.clear_premoves()
		board.premoving = false
	if not Options.on("threats"):
		board.set_arrows([])

# --- chrome ---

func _say(text: String) -> void:
	_toast_label.text = text
	_place_toast.call_deferred()
	Motion.stop(_toast_tw)
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tw.tween_interval(TOAST_HOLD)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.3)

func _hush() -> void:
	if _toast.modulate.a <= 0.0:
		return
	Motion.stop(_toast_tw)
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.2)

## Over the board, a little above its middle.
func _place_toast() -> void:
	_toast.reset_size()
	var at: Rect2 = board.get_global_rect()
	var frame: Rect2 = board.frame_rect()
	var w := _toast.get_combined_minimum_size().x
	_toast.global_position = Vector2(at.position.x + frame.get_center().x - w * 0.5,
		at.position.y + frame.position.y + frame.size.y * 0.4)

func _on_reset() -> void:
	if not can_reset():
		return
	Analytics.track("board_reset", {"puzzle_id": GAME})
	_fx.buzz(Haptics.TAP)
	_new_game()

func _on_back() -> void:
	if online != null:
		# A game in progress is resigned, and only on a yes; versus_abandon is
		# the computer's games', online's is versus_online_end (why resign).
		if online.live() and _state != State.OVER:
			online.ask_leave(rules.fullmove)
			return
	elif _state != State.OVER and _history.size() > 0:
		Analytics.track("versus_abandon", {"game": GAME, "level": level, "moves": rules.fullmove})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if online != null and online.back():
		return
	if tutor.close():
		return
	if _options != null and _options.is_open():
		_options.close()
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
