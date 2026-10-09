extends Control

## A game of Penny Drop: the sixth game on the Versus tab, built the way
## checkers is (versus/checkers_screen.gd). The flat boards' top bar, a
## scoreboard with the sun for you and the moon for the other player and the
## move number between them, and on the wooden deck the rack
## (versus/penny_board.gd).
##
## The game is the one sold as an upright plastic grid and two colours of
## discs, renamed as every genre here is; the rules (versus/penny_rules.gd)
## are that game's: seven slots by six, a penny a turn into a slot with room,
## it falls as far as it can, the first four in a line win, a full rack is a
## draw. Who drops first swaps every game; your pennies are always the sun's.
##
## The other player is versus/penny_ai.gd at one of three levels, thinking on
## a worker thread. **Level 3 is Online** (versus/online/online.gd), against
## a stranger or a friend: both ends hold the same rack, so a move is its
## column and nothing else needs saying. What goes over the wire is under
## "online" below.

signal closed

const Rules = preload("res://versus/penny_rules.gd")
const AI = preload("res://versus/penny_ai.gd")
const Board = preload("res://versus/penny_board.gd")
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
## What the phone knocks for (docs/agents/haptics.md). The board's cues ring
## for both players and are not mapped: the hand's own drop knocks by
## `_fx.buzz`.
const HAPTICS := {"hint": Haptics.GOOD, "win": Haptics.WIN, "lose": Haptics.LOSE, "draw": Haptics.GOOD}
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Online = preload("res://versus/online/online.gd")

const GAME := "penny"
const TITLE := "Penny Drop"
const MARGIN := 40
const GAP := 20
const SCORE_H := 128.0
const DECK_PAD := 18
const BACKDROP_BLEED := 90.0
const HINTS := 3
## Seconds: the least the computer is seen to think, how long its penny hangs
## over the slot it chose, and the beat before the end card.
const THINK_MIN := 0.7
const PONDER := 0.4
const END_WAIT := 2.0
const TOAST_HOLD := 2.2
const LEVELS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "VS_ONLINE"]
## The room a name has on a scoreboard plate, beside its face.
const NAME_W := 250.0

## WAIT is online's: the rack empty and still while the lobby looks. ENTER the
## rack being emptied for a new game; YOURS to drop; THINK the other player
## choosing; ANIM a penny in the air; REWIND pennies being taken back.
enum State { WAIT, ENTER, YOURS, THINK, ANIM, REWIND, OVER }

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
## The rules' side the player is: Rules.FIRST drops first.
var player := Rules.FIRST
var _state := State.WAIT
var _rewinds := 0
var _hints := HINTS
## The bulb's column for the position it was asked about, -1 none.
var _hint_col := -1
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
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween
var _end: Control
var _plates: Array = []
var _faces: Array = []
var _status: Array[Label] = []
var _names: Array[Label] = []
var _move_label: Label
## The game online, when the level is Record.ONLINE; null against the
## computer (and again once the lobby's "Play the computer" is taken).
var online: Node
## The other seat's columns not played yet (-1 for a message that was not a
## column): one can land while this seat's own penny is still in the air.
var _inbox: Array[int] = []
## What the other seat said the result was, for a game not yet over here.
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
	tutor = ScreenTutor.new(self, puzzle_id(), TITLE, _hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	player = Rules.FIRST if Record.last_colour(GAME) == Rules.FIRST else Rules.SECOND
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
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	# The motto names the moon: a game online has its own.
	top_bar = FlatTopBar.new(TITLE, tr("VS_ONLINE_MOTTO" if level == Record.ONLINE else "PNY_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.undo.connect(_on_undo)
	top_bar.reset.connect(_on_reset)
	top_bar.hint.connect(_on_hint)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_scoreboard())

	var deck := Control.new()
	deck.name = "Deck"
	deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.draw.connect(_draw_deck.bind(deck))
	deck.resized.connect(deck.queue_redraw)
	col.add_child(deck)
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, DECK_PAD)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.add_child(inset)
	board = Board.new()
	board.name = "Board"
	board.resized.connect(deck.queue_redraw)
	board.chosen.connect(_on_chosen)
	board.settled.connect(_on_settled)
	board.refused.connect(func(_reason: String) -> void:
		_fx.buzz(Haptics.WARN)
		_say(tr("PNY_FULL")))
	inset.add_child(board)
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
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + SCORE_H + BACKDROP_BLEED
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
	var radius := 36.0
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
	# petals and leaves blown on, never under the board
	var keep_out := Rect2(board.used_rect.position + Vector2.ONE * DECK_PAD, board.used_rect.size).grow(16.0)
	var placed := 0
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

func _build_scoreboard() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = SCORE_H
	row.add_theme_constant_override("separation", 16)
	for p in 2:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 12)
		inner.alignment = BoxContainer.ALIGNMENT_BEGIN if p == 0 else BoxContainer.ALIGNMENT_END
		plate.add_child(inner)
		var seat := Control.new()
		seat.custom_minimum_size = Vector2(88, 88)
		seat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var face: Control = SunFace.new() if p == 0 else MoonFace.new()
		face.size = Vector2(88, 88)
		seat.add_child(face)
		_faces.append(face)
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", -4)
		var align := HORIZONTAL_ALIGNMENT_LEFT if p == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var name_l := Label.new()
		name_l.text = "SNK_YOU" if p == 0 else "SNK_BOT"
		name_l.theme_type_variation = "SheetTitle"
		name_l.horizontal_alignment = align
		var status := Label.new()
		status.theme_type_variation = "CardBlurb"
		status.horizontal_alignment = align
		words.add_child(name_l)
		words.add_child(status)
		_status.append(status)
		_names.append(name_l)
		if p == 0:
			inner.add_child(seat)
			inner.add_child(words)
		else:
			inner.add_child(words)
			inner.add_child(seat)
		_plates.append(plate)
		if p == 1:
			row.add_child(_build_move_panel())
		row.add_child(plate)
	return row

func _build_move_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 30, 10))
	panel.custom_minimum_size.x = 200
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -6)
	panel.add_child(col)
	var kicker := Label.new()
	kicker.text = "CHS_MOVE"
	kicker.theme_type_variation = "MenuKicker"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	_move_label = Label.new()
	_move_label.theme_type_variation = "DayBig"
	_move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_move_label)
	return panel

## Whose turn it is, on the plates: the one to drop lit and saying so.
func _refresh_board() -> void:
	var over := _state == State.OVER or _state == State.WAIT
	for p in 2:
		var mine: bool = not over and (rules.turn == player) == (p == 0)
		var box := CozyTheme.lifted(Pal.SURFACE if mine else Color("f7f0e4"), 30, 10)
		if mine:
			box.border_color = Pal.ACCENT_2
			box.set_border_width_all(4)
		_plates[p].add_theme_stylebox_override("panel", box)
		_plates[p].modulate.a = 1.0 if mine or over else 0.82
		var line := tr("CHS_FIRST" if (player == Rules.FIRST) == (p == 0) else "CHS_SECOND")
		if mine:
			line = tr("CHS_TO_MOVE") if p == 0 else tr("CHS_THINKS")
		if _state == State.WAIT:
			line = ""
		_status[p].text = line
		if online != null:
			# The side to drop carries its seconds.
			online.dress(_status[p], line, mine and _state != State.ENTER, p == 0)
	var shown := str(_move_number())
	if _move_label.text != shown:
		_move_label.text = shown
		_move_label.pivot_offset = _move_label.size * 0.5
		if _state != State.ENTER and _state != State.WAIT:
			Motion.bump(_move_label, 0.2, 0.25)
	top_bar.refresh(self)

# --- the top bar's view of this screen (FlatTopBar.refresh) ---

func capabilities() -> Array:
	return ["undo", "hint"]

func is_done() -> bool:
	return _state == State.OVER

func is_solved() -> bool:
	return false

## Undo, the bulb and Reset are the computer's games' alone: online they
## stay on the bar, greyed. Undo needs a drop of the player's own to take
## back.
func can_undo() -> bool:
	return online == null and _state == State.YOURS and rules.ply >= (2 if player == Rules.FIRST else 3)

## The move number, a move being a penny each: the one being played, or the
## one that ended the game.
func _move_number() -> int:
	return (rules.ply + 1) / 2 if rules.status() != Rules.PLAYING else rules.ply / 2 + 1

func hints_left() -> int:
	return _hints if _state == State.YOURS and online == null else 0

## The bulb's badge: the count stays up while the bulb waits its turn.
func hints_held() -> int:
	return _hints if online == null else 0

## Reset waits out a penny in the air.
func can_reset() -> bool:
	return online == null and _state != State.ANIM and _state != State.REWIND and _state != State.ENTER

## The How to play card's pages (ui/hud/how_to_play.gd), each played on the
## rack itself by ui/hud/penny_tutorial_diagram.gd. The level only changes
## how well the computer plays, so the pages are the same on all three.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/penny_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.DROP, "TUT_PENNY_DROP", tr("TUT_PENNY_DROP_BODY")],
		[Diagram.Lesson.LINE, "TUT_PENNY_LINE", tr("TUT_PENNY_LINE_BODY")],
		[Diagram.Lesson.BLOCK, "TUT_PENNY_BLOCK", tr("TUT_PENNY_BLOCK_BODY")],
		[Diagram.Lesson.TWO, "TUT_PENNY_TWO", tr("TUT_PENNY_TWO_BODY")],
		[Diagram.Lesson.BAR, "TUT_PENNY_BAR",
			tr("TUT_PENNY_BAR_BODY_ONE") if HINTS == 1 else tr("TUT_PENNY_BAR_BODY_N") % HINTS],
	]
	var pages := []
	for step: Array in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

# --- the game ---

func _new_game() -> void:
	_lay(State.ENTER)

## An empty rack: emptied for a game (ENTER), or simply there, for the lobby
## to stand over (WAIT).
func _lay(state: State) -> void:
	_game += 1
	rules = Rules.new()
	_inbox.clear()
	_online_end = ""
	_hints = HINTS
	_hint_col = -1
	_undos = 0
	_state = state
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
		State.ENTER, State.ANIM:
			_start_turn()
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
		# played, and by this rack's rules -- the same rules -- it is not.
		_online_end = ""
		online.foul()
		return
	board.set_waiting(rules.turn)
	if mine:
		_state = State.YOURS
		board.interactive = true
		if rules.ply < 2:
			_say(tr("PNY_YOUR_MOVE"))
	else:
		_state = State.THINK
		board.interactive = false
		board.set_thinking(true)
		if rules.ply == 0:
			_say(tr("CHS_BOT_FIRST") if online == null else online.first_line())
		if online == null:
			_think("ai")
		else:
			_take_online()
	_refresh_board()

## The player let go over a column with room.
func _on_chosen(col: int) -> void:
	if _state != State.YOURS or not rules.can(col):
		return
	_fx.buzz(Haptics.TAP)
	_play(col)

func _play(col: int) -> void:
	var side: int = rules.turn
	var cell: int = rules.make(col)
	_state = State.ANIM
	board.interactive = false
	_hint_col = -1
	_hush()
	board.play(cell, side)
	if online != null and side == player:
		online.send({"m": col})
	_refresh_board()

# --- thinking, for the computer and the hint ---

func _process(_delta: float) -> void:
	# The computer's answer waits while the tutorial card is up, so no penny
	# is dropped (or heard) behind a page.
	if not _held:
		_poll_think()

func _hold(on: bool) -> void:
	_held = on

func _think(kind: String) -> void:
	if _task != -1:
		return
	var copy: RefCounted = rules.copy()
	var lv := level if kind == "ai" else 2
	var budget := -1 if kind == "ai" else AI.HINT_BUDGET_MS
	var seed := _rng.randi()
	var box: Array = [-1]
	_box = box
	_task_for = kind
	_task_game = _game
	_think_at = Time.get_ticks_msec() / 1000.0
	_task = WorkerThreadPool.add_task(func() -> void: box[0] = AI.new().plan(copy, lv, seed, budget))

func _poll_think() -> void:
	if _task == -1 or not WorkerThreadPool.is_task_completed(_task):
		return
	var kind := _task_for
	if kind == "ai" and Time.get_ticks_msec() / 1000.0 - _think_at < (0.05 if Motion.reduce else THINK_MIN):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var col: int = _box[0]
	if kind == "ai" and _task_game == _game and _state == State.THINK and col >= 0:
		_bot_moves(col)
		return
	if kind == "hint" and _task_game == _game and _state == State.YOURS and col >= 0:
		_hint_col = col
		board.set_hint(col)
		_fx.cue("hint")
		_say(tr("PNY_HINT_LINE"))
	if _state == State.THINK and online == null:
		_think("ai")

## The other player's penny goes over its slot, hangs a beat, and drops.
func _bot_moves(col: int) -> void:
	_state = State.ANIM
	board.set_lifted(col)
	var game := _game
	get_tree().create_timer(0.0 if Motion.reduce else PONDER).timeout.connect(func() -> void:
		# An online game can end (a resignation, a clock) inside the beat.
		if _game != game or not is_inside_tree() or _state != State.ANIM:
			return
		_play(col))

func _on_hint() -> void:
	if _state != State.YOURS or _task != -1 or online != null:
		return
	if _hint_col >= 0:
		board.set_hint(_hint_col)
		_say(tr("PNY_HINT_LINE"))
		return
	if _hints <= 0:
		return
	_hints -= 1
	top_bar.refresh(self)
	_say(tr("CHS_THINKING"))
	_think("hint")
	Analytics.track("hint_used", {"puzzle_id": GAME, "hints": HINTS - _hints})

# --- undo ---

## Takes back your last penny and the computer's answer to it.
func _on_undo() -> void:
	if not can_undo():
		return
	_undos += 1
	_rewinds = 2
	_state = State.REWIND
	_fx.buzz(Haptics.TICK)
	board.interactive = false
	board.set_waiting(-1)
	_hint_col = -1
	_hush()
	_rewind_one()
	Analytics.track("undo_used", {"puzzle_id": GAME, "undos": _undos})

func _rewind_one() -> void:
	_rewinds -= 1
	var col: int = rules.history[rules.history.size() - 1]
	rules.unmake()
	board.rewind(rules.landing(col))
	_refresh_board()

# --- online (level 3): what is this game's own; the rest is versus/online/online.gd ---
#
# The wire, one JSON object a message: {m: column}, 0 to 6, the turn passing.
# Both ends hold the same rack, so that is all of it; the ending is each
# rack's own to reach.

func _go_online() -> void:
	online = Online.new(self, GAME)
	online.seeking.connect(_on_online_seeking)
	online.started.connect(_on_online_started)
	online.move.connect(_on_online_move)
	online.over.connect(_on_online_over)
	online.ticked.connect(_on_online_ticked)
	online.computer.connect(_play_computer)
	online.closed.connect(func() -> void: closed.emit())
	add_child(online)
	online.open()

## Looking for a player (the first time, and Find another): an empty rack
## under the lobby, nobody in the far seat yet.
func _on_online_seeking() -> void:
	_seat_rival("")
	_lay(State.WAIT)

## Found: the seat that opens drops first, and the game begins as any does.
func _on_online_started() -> void:
	player = Rules.FIRST if online.opens() else Rules.SECOND
	_seat_rival(online.opponent)
	_new_game()

## The far plate's face and name: the other player's, or the moon's.
func _seat_rival(uid: String) -> void:
	var seat: Control = _faces[1].get_parent()
	seat.remove_child(_faces[1])
	_faces[1].queue_free()
	var face: Control = MoonFace.new()
	if uid.is_empty():
		face.size = Vector2(88, 88)
		_names[1].remove_theme_font_size_override("font_size")
		_names[1].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
		# Nobody yet while the lobby looks: the bot is not who is coming.
		_names[1].text = "SNK_BOT" if online == null else "…"
		face.visible = online == null
	else:
		face = online.face(88)
		Online.fit(_names[1], online.rival(), NAME_W)
	seat.add_child(face)
	_faces[1] = face

## The other seat's move, as it was sent: one key, a whole number from 0 to
## 6. Anything else waits as -1, which no rack has room for.
func _on_online_move(d: Dictionary) -> void:
	var col := -1
	var sent: Variant = d.get("m")
	if d.size() == 1 and (typeof(sent) == TYPE_FLOAT or typeof(sent) == TYPE_INT):
		var f := float(sent)
		if f == floorf(f) and f >= 0.0 and f < Rules.W:
			col = int(f)
	_inbox.append(col)
	_take_online()

## Plays the next move waiting, if it is the other seat's turn to be seen
## dropping. A column that is not one, or has no room, is a foul.
func _take_online() -> void:
	if _state != State.THINK or _inbox.is_empty():
		return
	var col: int = _inbox.pop_front()
	if not rules.can(col):
		online.foul()
		return
	_bot_moves(col)

## The match ended without this rack ending it. A resignation, a clock or a
## player gone ends the game where it stands. "end" is the other seat's word
## that the game finished in the rack, and it is not taken on trust: the
## rules let the seat that moved last write it with any winner, but both ends
## run the same rules, so a real ending is one this rack reaches by itself
## once the last penny has landed (`_start_turn` finishes on its own status,
## and the result shown is this rack's). An "end" this rack does not reach,
## with nothing left to play, is a foul.
func _on_online_over(outcome: String, why: String) -> void:
	if _state == State.OVER:
		return
	if why != "end":
		_conclude(outcome, "", why)
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
	player = Rules.FIRST if Record.last_colour(GAME) == Rules.FIRST else Rules.SECOND
	_seat_rival("")
	for l in _status:
		l.remove_theme_color_override("font_color")
	top_bar.set_motto(tr("PNY_MOTTO"))
	Analytics.track("versus_start", {"game": GAME, "level": level})
	_new_game()
	tutor.first_play()

# --- the end ---

func _finish(status: int) -> void:
	if status == Rules.WON:
		_conclude("won" if rules.winner == player else "lost", "PNY_LINE_IN", "")
	else:
		_conclude("draw", "PNY_DRAW_FULL", "")

## The game is over: "won", "lost" or "draw". In the rack, `reason` says how
## (the card's line; a draw's is also the toast); online and off the rack,
## `why` is what the match said ("resign", "timeout", "left", "end").
func _conclude(outcome: String, reason: String, why: String) -> void:
	# The seat that made the last move: the side not to move now.
	var mine_last: bool = rules.turn != player
	_state = State.OVER
	board.interactive = false
	board.finish(outcome, rules.line)
	_refresh_board()
	if online != null:
		online.settle(outcome, why, _move_number(), mine_last)
	else:
		if outcome == "draw":
			Record.add_draw(GAME, level)
		else:
			Record.add(GAME, level, outcome == "won")
		Analytics.track("versus_end", {"game": GAME, "level": level, "won": outcome == "won",
			"result": outcome, "moves": _move_number(), "undos": _undos, "hints": HINTS - _hints,
			"first": player == Rules.FIRST})
	Ads.note_finished()
	_fx.cue({"won": "win", "lost": "lose", "draw": "draw"}[outcome])
	_faces[0].expression = Face.Expr.JOY if outcome == "won" else (Face.Expr.WORRIED if outcome == "lost" else Face.Expr.SLEEPY)
	_faces[1].expression = Face.Expr.JOY if outcome == "lost" else (Face.Expr.WORRIED if outcome == "won" else Face.Expr.SLEEPY)
	if outcome == "draw" and reason != "":
		_say(tr(reason))
	var game := _game
	get_tree().create_timer(0.3 if Motion.reduce else END_WAIT).timeout.connect(func() -> void:
		if _game != game or not is_inside_tree():
			return
		_end = _build_end(outcome, reason, why)
		add_child(_end)
		Motion.appear(_end, 0.0, 1.0, 0.3)
		_celebrate(outcome == "won"))

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
	seat.custom_minimum_size = Vector2(0, 170)
	var face: Control = SunFace.new()
	if outcome == "lost":
		face = MoonFace.new() if online == null else online.face(170)
	face.size = Vector2(170, 170)
	face.position = Vector2(820 * 0.5 - 40 - 85, 0)
	face.expression = Face.Expr.SLEEPY if outcome == "draw" else Face.Expr.JOY
	seat.add_child(face)
	col.add_child(seat)
	var head := Label.new()
	head.text = {"won": "PNY_WIN", "lost": "PNY_LOSE", "draw": "CHS_DRAW"}[outcome]
	if online != null:
		head.text = online.head(outcome)
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var said := Label.new()
	if reason != "":
		said.text = tr(reason) % _move_number() if outcome != "draw" else tr(reason)
	# Off the rack no line ended it: the match's own reason, if it has words.
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
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
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
	Dialog.buttons(col, again, back)
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
	var cols := [Pal.WATER_HI, Pal.SUN_RAY, Pal.BERRY, Pal.LEAF, Pal.FLOWER]
	var mid := size * 0.5
	for k in 8:
		var at := mid + Vector2.from_angle(TAU * k / 8.0 - PI * 0.5) * Vector2(400.0, 330.0)
		# bound to the effect itself, so a card closed early takes the
		# connection with it
		get_tree().create_timer(0.25 + 0.14 * k).timeout.connect(fx.puff.bind(at, cols[k % cols.size()], 12))

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

## Over the far roll of pennies, where it hides no slot the thumb is on its
## way to.
func _place_toast() -> void:
	_toast.reset_size()
	var sz := _toast.get_combined_minimum_size()
	_toast.global_position = board.global_position + board.toast_point() - sz * 0.5

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
			online.ask_leave(_move_number())
			return
	elif _state != State.OVER and rules.ply > 0:
		Analytics.track("versus_abandon", {"game": GAME, "level": level, "moves": _move_number()})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if online != null and online.back():
		return
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
