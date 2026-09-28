extends Control

## A game of checkers against the computer: the third game on the Versus
## tab, built the way chess is (versus/chess_screen.gd). The flat boards'
## top bar (back, the title in ink with its sprout, undo, reset, a hint with
## its count, settings), a scoreboard with the sun for you and the moon for
## the computer and the move number between them, and the board on the same
## wooden deck.
##
## You always play the cream pieces at the bottom; which colour they move
## as swaps every game (Play again), so the computer opens every other one.
## Brazilian rules (versus/checkers_rules.gd): capturing is compulsory and
## the most pieces must be taken, so when a capture is on, the pieces that
## can make it wear a ring. Local only for now: the other player is
## versus/checkers_ai.gd, thinking on a worker thread. The board and its
## animation are versus/checkers_board.gd, the look and the motion of the
## pieces a skin (versus/checkers_skin.gd).

signal closed

const Rules = preload("res://versus/checkers_rules.gd")
const AI = preload("res://versus/checkers_ai.gd")
const Board = preload("res://versus/checkers_board.gd")
const CheckersSkin = preload("res://versus/checkers_skin.gd")
const Record = preload("res://versus/versus_record.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const Face = preload("res://ui/faces/face.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Analytics = preload("res://core/analytics.gd")

const GAME := "checkers"
const MARGIN := 40
const GAP := 20
const SCORE_H := 128.0
const DECK_PAD := 18
const BACKDROP_BLEED := 90.0
const HINTS := 3
## Pauses, seconds: the shortest the computer seems to think, how long it
## holds its piece up before moving it, and the beat before the end card.
const THINK_MIN := 0.6
const PONDER := 0.35
## Before the end card: long enough for the losers to turn over.
const END_WAIT := 2.4
const TOAST_HOLD := 2.2
const LEVELS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD"]

enum State { ENTER, YOURS, THINK, ANIM, REWIND, OVER }

var level := 1
var rules: RefCounted
var board: Control
var _deck_mesh: ArrayMesh
var _deck_key := Rect2()
var top_bar: Control
var settings_sheet: Control
## The colour the player moves this game.
var player := Rules.LIGHT
var _state := State.ENTER
var _history: Array = []
var _rewinds := 0
var _hints := HINTS
var _undos := 0
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
var _move_label: Label
## Whether the compulsory capture has been explained this game.
var _told_must := false

func _init(the_level := 1) -> void:
	level = clampi(the_level, 0, 2)

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
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	player = Rules.LIGHT if Record.last_colour(GAME) == Rules.LIGHT else Rules.DARK
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

	top_bar = FlatTopBar.new("Checkers", tr("CKR_MOTTO"), true)
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
	board.skin = CheckersSkin.named(Record.skin(GAME))
	board.resized.connect(deck.queue_redraw)
	board.chosen.connect(_on_chosen)
	board.settled.connect(_on_settled)
	board.refused.connect(func(reason: String) -> void:
		_say(tr("CKR_MUST") if reason == "must" else tr("CKR_STUCK")))
	inset.add_child(board)
	_fx = Fx2D.new()
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

## Whose turn it is, on the plates: the one to move lit and saying so.
func _refresh_board() -> void:
	var over := _state == State.OVER
	for p in 2:
		var mine: bool = not over and (rules.turn == player) == (p == 0)
		var box := CozyTheme.lifted(Pal.SURFACE if mine else Color("f7f0e4"), 30, 10)
		if mine:
			box.border_color = Pal.ACCENT_2
			box.set_border_width_all(4)
		_plates[p].add_theme_stylebox_override("panel", box)
		_plates[p].modulate.a = 1.0 if mine or over else 0.82
		var colour_key := "CHS_FIRST" if (player == rules.first_side()) == (p == 0) else "CHS_SECOND"
		var line := tr(colour_key)
		if mine:
			line = tr("CHS_TO_MOVE") if p == 0 else tr("CHS_THINKS")
			if p == 0 and _state == State.YOURS and rules.must_capture():
				line = tr("CKR_CAPTURE")
		_status[p].text = line
	var shown := str(_move_number())
	if _move_label.text != shown:
		_move_label.text = shown
		_move_label.pivot_offset = _move_label.size * 0.5
		if _state != State.ENTER:
			Motion.bump(_move_label, 0.2, 0.25)
	top_bar.refresh(self)

# --- the top bar's view of this screen (FlatTopBar.refresh) ---

func capabilities() -> Array:
	return ["undo", "hint"]

func is_done() -> bool:
	return _state == State.OVER

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return _state == State.YOURS and _history.size() >= (2 if player == rules.first_side() else 3)

## The move number, a move being one each.
func _move_number() -> int:
	return rules.ply / 2 + 1

func hints_left() -> int:
	return _hints if _state == State.YOURS else 0

# --- the game ---

func _new_game() -> void:
	_game += 1
	rules = Rules.new()
	_history.clear()
	_hints = HINTS
	_undos = 0
	_told_must = false
	_state = State.ENTER
	if _end != null:
		_end.queue_free()
		_end = null
	for f in _faces:
		f.expression = Face.Expr.HAPPY
	board.interactive = false
	board.setup(rules, player, true)
	_refresh_board()
	if Motion.reduce:
		_start_turn.call_deferred()

func _on_settled() -> void:
	match _state:
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
	if mine:
		_state = State.YOURS
		board.interactive = true
		var must := PackedInt32Array()
		for m: PackedInt32Array in rules.legal_moves():
			if Rules.mv_ncaps(m) > 0 and not must.has(m[0]):
				must.append(m[0])
		board.set_must(must)
		if not must.is_empty() and not _told_must:
			_told_must = true
			_say(tr("CKR_MUST_FIRST"))
		elif _history.size() < 2:
			_say(tr("CHS_YOUR_MOVE"))
	else:
		_state = State.THINK
		board.interactive = false
		board.set_thinking(true)
		if _history.is_empty():
			_say(tr("CHS_BOT_FIRST"))
		_think("ai")
	_refresh_board()

func _on_chosen(m: PackedInt32Array) -> void:
	if _state != State.YOURS:
		return
	_play(m)

func _play(m: PackedInt32Array) -> void:
	var d: Dictionary = rules.describe(m)
	rules.make(m)
	_history.append(d)
	_state = State.ANIM
	board.interactive = false
	board.set_hint(PackedInt32Array())
	board.set_must(PackedInt32Array())
	_hush()
	board.play(d)
	_refresh_board()
	if not (d.caps as Array).is_empty():
		var taker := 0 if int(d.side) == player else 1
		_react(taker, Face.Expr.JOY)
		_react(1 - taker, Face.Expr.WORRIED)
	elif bool(d.crown):
		_react(0 if int(d.side) == player else 1, Face.Expr.JOY)

func _after_move() -> void:
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

func _process(_delta: float) -> void:
	_poll_think()

func _think(kind: String) -> void:
	if _task != -1:
		return
	var copy: RefCounted = rules.copy()
	var lv := level if kind == "ai" else 2
	var budget := -1 if kind == "ai" else AI.HINT_BUDGET_MS
	var seed := _rng.randi()
	var box: Array = [PackedInt32Array()]
	_box = box
	_task_for = kind
	_task_game = _game
	_think_at = Time.get_ticks_msec() / 1000.0
	_task = WorkerThreadPool.add_task(func() -> void: box[0] = AI.new().plan(copy, lv, seed, budget))

func _poll_think() -> void:
	if _task == -1 or not WorkerThreadPool.is_task_completed(_task):
		return
	var kind := _task_for
	if kind == "ai" and Time.get_ticks_msec() / 1000.0 - _think_at < THINK_MIN:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var m: PackedInt32Array = _box[0]
	if kind == "ai" and _task_game == _game and _state == State.THINK and not m.is_empty():
		_bot_moves(m)
		return
	if kind == "hint" and _task_game == _game and _state == State.YOURS and not m.is_empty():
		board.set_hint(m)
		_fx.cue("hint")
		_say(tr("CHS_HINT_LINE"))
	if _state == State.THINK:
		_think("ai")

## The computer picks its piece up, holds it a beat, and moves.
func _bot_moves(m: PackedInt32Array) -> void:
	_state = State.ANIM
	board.set_thinking(false)
	board.set_lifted(Rules.mv_from(m))
	var game := _game
	get_tree().create_timer(0.0 if Motion.reduce else PONDER).timeout.connect(func() -> void:
		if _game != game or not is_inside_tree():
			return
		_state = State.THINK
		_play(m))

func _on_hint() -> void:
	if _state != State.YOURS or _hints <= 0 or _task != -1:
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
	_rewinds = 2
	_state = State.REWIND
	board.interactive = false
	board.set_hint(PackedInt32Array())
	board.set_must(PackedInt32Array())
	_hush()
	_rewind_one()
	Analytics.track("undo_used", {"puzzle_id": GAME, "undos": _undos})

func _rewind_one() -> void:
	_rewinds -= 1
	var d: Dictionary = _history.pop_back()
	rules.unmake()
	board.rewind(d)
	_refresh_board()

# --- the end ---

func _finish(status: int) -> void:
	_state = State.OVER
	board.interactive = false
	board.set_must(PackedInt32Array())
	var outcome := "draw"
	var reason := ""
	match status:
		Rules.NO_MOVES:
			var loser: int = rules.turn
			outcome = "lost" if loser == player else "won"
			var left: Vector2i = rules.count(loser)
			reason = "CKR_ALL_TAKEN" if left.x + left.y == 0 else "CKR_BLOCKED"
		Rules.QUIET:
			reason = "CKR_DRAW_QUIET"
		_:
			reason = "CHS_DRAW_REPEAT"
	board.finish(outcome)
	_refresh_board()
	if outcome == "draw":
		Record.add_draw(GAME, level)
	else:
		Record.add(GAME, level, outcome == "won")
	Analytics.track("versus_end", {"game": GAME, "level": level, "won": outcome == "won",
		"result": outcome, "moves": _move_number(), "undos": _undos,
		"taken": rules.lost(1 - player), "lost": rules.lost(player),
		"colour": "light" if player == Rules.LIGHT else "dark"})
	_fx.cue({"won": "win", "lost": "lose", "draw": "draw"}[outcome])
	_faces[0].expression = Face.Expr.JOY if outcome == "won" else (Face.Expr.WORRIED if outcome == "lost" else Face.Expr.SLEEPY)
	_faces[1].expression = Face.Expr.JOY if outcome == "lost" else (Face.Expr.WORRIED if outcome == "won" else Face.Expr.SLEEPY)
	if outcome == "draw":
		_say(tr(reason))
	var game := _game
	get_tree().create_timer(0.3 if Motion.reduce else END_WAIT).timeout.connect(func() -> void:
		if _game != game or not is_inside_tree():
			return
		_end = _build_end(outcome, reason)
		add_child(_end)
		Motion.appear(_end, 0.0, 1.0, 0.3)
		_celebrate(outcome == "won"))

func _build_end(outcome: String, reason: String) -> Control:
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
	var face: Control = MoonFace.new() if outcome == "lost" else SunFace.new()
	face.size = Vector2(170, 170)
	face.position = Vector2(820 * 0.5 - 40 - 85, 0)
	face.expression = Face.Expr.SLEEPY if outcome == "draw" else Face.Expr.JOY
	seat.add_child(face)
	col.add_child(seat)
	var head := Label.new()
	head.text = {"won": "CHS_WIN", "lost": "CHS_LOSE", "draw": "CKR_DRAW"}[outcome]
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var why := Label.new()
	why.text = tr(reason) % _move_number() if outcome != "draw" else tr(reason)
	why.theme_type_variation = "SheetBody"
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(why)
	var line := Label.new()
	line.text = "%s  ·  %s" % [tr(LEVELS[level]), Record.record_line(GAME, level)]
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var again := Dialog.primary("reset", tr("SNK_AGAIN"))
	again.pressed.connect(func() -> void:
		player = 1 - player
		Record.set_last_colour(GAME, player)
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
	var cols := [Pal.KNIGHT_CREAM, Pal.KNIGHT_ROSE, Pal.CROWN, Pal.LEAF, Pal.SUN_RAY]
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

## Over the computer's planter at the top, where it hides no piece in play.
func _place_toast() -> void:
	_toast.reset_size()
	var at: Rect2 = board.get_global_rect()
	var frame: Rect2 = board.frame_rect()
	var sz := _toast.get_combined_minimum_size()
	var top := maxf(at.position.y + board.used_rect.position.y, at.position.y + frame.position.y + board.cell * 0.4 - sz.y)
	_toast.global_position = Vector2(at.position.x + frame.get_center().x - sz.x * 0.5, top)

func _on_reset() -> void:
	if _state == State.ANIM or _state == State.REWIND:
		return
	Analytics.track("board_reset", {"puzzle_id": GAME})
	_new_game()

func _on_back() -> void:
	if _state != State.OVER and _history.size() > 0:
		Analytics.track("versus_abandon", {"game": GAME, "level": level, "moves": _move_number()})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
