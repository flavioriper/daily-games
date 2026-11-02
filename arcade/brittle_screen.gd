extends Control

## Brittle: an Arcade game, a tin of nut brittle cut in numbered squares and a
## stream of sugar balls poured at it from a scoop (spec
## docs/superpowers/specs/2026-11-02-arcade-brittle-design.md). Laid as the
## daily boards: the wooden floor over the whole screen, on the 40 margin the
## flat top bar and its tools row, with the step and the score on a paper pill
## where the row's gap is, and under them the tin as large as it goes.
##
## Play: hold the tin and slide to aim, let go to pour. Every ball takes one
## off a square it strikes. When the last ball is home the squares come down
## a row and a new row is laid; a square past the last row ends the run. The
## plums are one more ball each.
##
## Undo takes the last volley back, the bulb shows the next aim further, and
## the arrow calls the balls home. The game is arcade/brittle_sim.gd; the tin
## (arcade/brittle_board.gd) draws it, runs it and says what it has shown
## (`beat`), and this screen plays that.

signal closed

const Sim = preload("res://arcade/brittle_sim.gd")
const Art = preload("res://arcade/brittle_art.gd")
const Board = preload("res://arcade/brittle_board.gd")
const Record = preload("res://arcade/arcade_record.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "brittle"
const TITLE := "Brittle"
const MARGIN := 40
const GAP := 20
const PILL_R := 30
const CLEAR_CARD := 780
## The end card's cues (docs/agents/haptics.md); everything else asks through
## `_feel`, and a frame knocks once, with the strongest asked.
const HAPTICS := {"new_best": Haptics.WIN, "game_over": Haptics.LOSE}
## The score lettered over the tin as it passes each of these.
const MILESTONES := [100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000]
## A step lettered every this many.
const STEP_EVERY := 10
## The words of a volley by the squares it broke: [from, key].
const CRUSHES := [[12, "BT_CRUSH_4"], [9, "BT_CRUSH_3"], [6, "BT_CRUSH_2"], [4, "BT_CRUSH_1"]]
## No cue climbs past five semitones (docs/agents/sound.md): a square's crack
## climbs half a semitone a square through a volley.
const CLIMB_TOP := 1.335
const CLIMB_STEP := 0.5
const TICK_VARY := 0.06
## How many crumbs a square throws: a volley can break a dozen at once.
const CRUMBS := 7
const BANNER_HOLD := 1.6

var sim: RefCounted
var board: Control
var _boosts: Array = []
var _boosted := false
var _chance_used := false
var _run_gold := 0
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var _held := false
var _fx: Node2D
var _world: Control
var _world_mesh: ArrayMesh
var _margins: MarginContainer
var _step_l: Label
var _score_l: Label
var _best_k: Label
var _recall: Button
var _end: Control
var _clear_card: Control
var _started_at := 0
var _best := 0
var _shown_score := -1
var _shown_step := -1
var _beat_best := false
var _knock := -1
var _clock := 0.0
var _over_told := false
var _seat: Control
var _rw: Rewards
var _milestone := 0
var _end_score: Label
var _end_at := 0.0
var _crush_words := 0

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), TITLE, _hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	_ask(false)

## The tutorial card's pages, each a small tin played by a hand
## (ui/hud/brittle_tutorial_diagram.gd).
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/brittle_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.AIM, "TUT_BRITTLE_AIM", tr("TUT_BRITTLE_AIM_BODY")],
		[Diagram.Lesson.CRACK, "TUT_BRITTLE_CRACK", tr("TUT_BRITTLE_CRACK_BODY")],
		[Diagram.Lesson.PLUM, "TUT_BRITTLE_PLUM", tr("TUT_BRITTLE_PLUM_BODY")],
		[Diagram.Lesson.RISE, "TUT_BRITTLE_RISE", tr("TUT_BRITTLE_RISE_BODY")],
		[Diagram.Lesson.SWEETS, "TUT_BRITTLE_SWEETS", tr("TUT_BRITTLE_SWEETS_BODY")],
		[Diagram.Lesson.TOOLS, "TUT_BRITTLE_TOOLS", tr("TUT_BRITTLE_TOOLS_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func _hold(on: bool) -> void:
	_held = on
	if on:
		board.let_go()

# --- building ---

func _build() -> void:
	_world = Control.new()
	_world.name = "World"
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.draw.connect(func() -> void:
		if _world_mesh != null:
			_world.draw_mesh(_world_mesh, null))
	_world.resized.connect(_paint_world)
	add_child(_world)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new(TITLE, tr("BT_MOTTO"), true, false, true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_ask_clear)
	top_bar.undo.connect(_on_undo)
	top_bar.hint.connect(_on_sight)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	top_bar.tint_motto(Color("4a2f12"))
	col.add_child(_build_tools())

	board = Board.new()
	board.name = "Board"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.beat.connect(_on_beat)
	col.add_child(board)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	board.add_child(_fx)
	_rw = Rewards.new()
	add_child(_rw)
	_apply_insets()

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))

func _paint_world() -> void:
	if _world == null or _world.size.x <= 0.0:
		return
	var b := Face.Builder.new()
	Scenery.planks(b, _world.size, 11)
	_world_mesh = b.mesh()
	_world.queue_redraw()

## Undo, the bin, a paper pill with the step and the score where the row's gap
## is, then the arrow that calls the balls home, and the bulb.
func _build_tools() -> Control:
	var row: HBoxContainer = top_bar.tools
	var pill := PanelContainer.new()
	pill.name = "Score"
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.custom_minimum_size.y = FlatTopBar.BUTTON.y
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, PILL_R, 6))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 20)
	pill.add_child(line)
	var step_col := _pill_column("BT_STEP")
	line.add_child(step_col[0])
	_step_l = step_col[2]
	var score_col := _pill_column("FF_BEST")
	line.add_child(score_col[0])
	_best_k = score_col[1]
	_best_k.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_score_l = score_col[2]
	for child in row.get_children():
		if child is Control and not (child is Button):
			child.visible = false
	row.add_child(pill)
	row.move_child(pill, top_bar.hint_button.get_index())
	_recall = IconButton.new("arrow_down", "", "IconButton")
	_recall.name = "Recall"
	_recall.custom_minimum_size = FlatTopBar.BUTTON
	_recall.pressed.connect(_on_recall)
	_recall.set_enabled(false)
	row.add_child(_recall)
	row.move_child(_recall, top_bar.hint_button.get_index())
	return row

func _pill_column(key: String) -> Array:
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", -6)
	var kicker := Label.new()
	kicker.text = key
	kicker.theme_type_variation = "MenuKicker"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(kicker)
	var value := Label.new()
	value.text = "0"
	value.theme_type_variation = "SheetTitle"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	words.add_child(value)
	return [words, kicker, value]

# --- the game ---

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	_close_clear()
	sim = Sim.new()
	Boosters.apply(GAME, sim, _boosts)
	_boosted = not _boosts.is_empty()
	_chance_used = false
	_run_gold = 0
	_beat_best = false
	_milestone = 0
	_over_told = false
	_end_score = null
	_rw.clear()
	_best = Record.best(GAME)
	_shown_score = -1
	_shown_step = -1
	_started_at = Time.get_ticks_msec()
	board.interactive = true
	board.long_sight = false
	board.lay(sim)
	_refresh_hud()
	top_bar.refresh(self)
	_fx.cue("start")
	Analytics.track("arcade_start", {"game": GAME, "boosts": ",".join(_boosts)})

func capabilities() -> Array:
	return ["undo", "hint"]

func is_done() -> bool:
	return sim != null and sim.is_over()

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return sim != null and sim.can_undo() and board.settled()

func hints_left() -> int:
	return 0 if sim == null or board.long_sight else int(sim.sights)

func can_reset() -> bool:
	return true

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	board.paused = _waiting()
	_refresh_hud()
	_knock_now()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()
	var can_call: bool = sim.flying() and int(sim.fired) > 0
	if can_call == _recall.disabled:
		_recall.set_enabled(can_call)
	if sim.is_over() and not _over_told and board.settled():
		_over_told = true
		_run_over()

func _waiting() -> bool:
	return _held or settings_sheet.is_open() or _clear_card != null or get_node_or_null("BoostCard") != null or get_node_or_null("SecondChance") != null

func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _knock_now() -> void:
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1

func _vary() -> float:
	return randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY)

func _climb(steps: float) -> float:
	return minf(pow(2.0, steps * CLIMB_STEP / 12.0), CLIMB_TOP)

func _spot(p: Vector2) -> Vector2:
	return _rw.at(board, board.px(p))

func _mid(down := 0.42) -> Vector2:
	var f: Rect2 = board.frame_rect()
	return _rw.at(board, f.position + f.size * Vector2(0.5, down))

# --- what the tin shows ---

func _on_beat(what: String, data: Dictionary) -> void:
	match what:
		"tap", "press":
			_fx.touch()
		"aim":
			_fx.cue("aim", _vary())
		"cancel":
			_fx.cue("cancel")
		"fired":
			_fx.cue("fire")
			_feel(Haptics.TAP)
			if board.long_sight:
				board.long_sight = false
				sim.sights -= 1
			top_bar.refresh(self)
		"hit":
			# The sim's gap is in its own seconds: fx2d's keeps it to a tick a
			# real moment when a long volley runs at four times the speed,
			# and a spark more than that is noise.
			_fx.cue("hit", _vary())
			if board.pace() <= 1.0:
				_rw.spray(_spot(data.at), Art.SUGAR, 2, 260.0, "spark", 0.6)
		"wall":
			_fx.cue("wall", _vary())
		"break":
			_on_break(data)
		"pop":
			_fx.cue("pop")
			_feel(Haptics.BUMP)
			_rw.ring(_spot(data.at), 240.0, Color(Art.FIZZ, 0.9))
			_rw.spray(_spot(data.at), Art.FIZZ, 14, 760.0, "star", 1.0)
		"plus":
			_fx.cue("plus", _vary())
			_feel(Haptics.TICK)
			_rw.ring(_spot(data.at), 90.0, Color(Art.PLUM.lightened(0.3), 0.9))
			_rw.sticker("+1", _spot(data.at) - Vector2(0, 30.0), 54, 0.8, false, Art.PLUM.lightened(0.5), false, "", 50.0)
		"line":
			_fx.cue("line", _vary())
			_feel(Haptics.TAP)
		"fizz":
			_fx.cue("fizz", _vary())
		"land":
			_fx.cue("land")
		"recall":
			_fx.cue("recall")
			_feel(Haptics.TAP)
		"clear":
			_on_clean(data)
		"volley":
			_on_volley(data)
		"descend":
			_on_descend(data)
		"tight":
			_fx.cue("warn")
			_feel(Haptics.WARN)
			_rw.sticker(tr("BT_TIGHT"), _mid(0.9), 52, 1.5, false, Color("ffd9a0"), false, "tight")
		"over":
			_fx.cue("over")
			_feel(Haptics.BAD)
		"revive":
			_rw.sticker(tr("CHANCE_GO"), _mid(), 64, 1.2, false, Color.WHITE, false, "revive")
			top_bar.refresh(self)

## A square gone: crumbs of its flavour, some home to the score.
func _on_break(data: Dictionary) -> void:
	var crush := int(data.crush)
	var col: Color = Art.FLAVOUR[Art.band(int(data.full), sim.step_n)]
	var at := _spot(data.at)
	_fx.cue("crack", _climb(crush - 1) * _vary(), 0.0, 0.0)
	_feel(Haptics.TAP)
	_rw.spray(at, col.lightened(0.15), CRUMBS, 520.0, "mote", 1.0)
	_rw.spray(at, Art.CREAM, 3, 420.0, "spark", 0.9, 0.0, _rw.at(_score_l, _score_l.size * 0.5))
	_rw.ring(at, board.cell_px() * 0.8, Color(col.lightened(0.3), 0.85))

func _on_volley(data: Dictionary) -> void:
	var crush := int(data.crush)
	for pair: Array in CRUSHES:
		if crush >= int(pair[0]):
			var big: bool = crush >= int(CRUSHES[1][0])
			_rw.sticker(tr(pair[1]), _mid(), 66 + mini(crush, 16), 1.3, big, Color.WHITE, big, "crush")
			_fx.cue("crush")
			_feel(Haptics.GOOD)
			break
	top_bar.refresh(self)

func _on_clean(data: Dictionary) -> void:
	_fx.cue("clean")
	_feel(Haptics.WIN)
	_rw.sticker(tr("BT_CLEAN"), _mid(0.36), 84, 1.8, true, Color.WHITE, true, "clean")
	_rw.sticker("+%s" % Record.grouped(int(data.pts)), _mid(0.46), 58, 1.8, false, Color("fff4c2"), false, "clean_pts")
	_rw.spray(_mid(0.4), Pal.SUN, 22, 820.0, "star", 1.1)

func _on_descend(data: Dictionary) -> void:
	_fx.cue("descend")
	var n := int(data.step)
	if n % STEP_EVERY == 0 and not sim.is_over():
		_fx.cue("level")
		_feel(Haptics.GOOD)
		_rw.sticker(tr("BT_STEP_UP") % n, _mid(0.3), 70, 1.4, true, Color.WHITE, true, "step")
		_rw.spray(_mid(0.3), Pal.SUN, 12, 700.0, "star", 1.0)
	top_bar.refresh(self)

func _refresh_hud() -> void:
	var score: int = sim.score
	var step_n: int = sim.step_n
	if score == _shown_score and step_n == _shown_step:
		return
	if step_n != _shown_step and _shown_step >= 0:
		_step_l.pivot_offset = _step_l.size * 0.5
		Motion.bump(_step_l, 0.3, 0.4)
	_shown_step = step_n
	_shown_score = score
	_step_l.text = str(step_n)
	_score_l.text = Record.grouped(score)
	if not _beat_best and _best > 0 and score > _best:
		_beat_best = true
		_score_l.pivot_offset = _score_l.size * 0.5
		Motion.bump(_score_l, 0.3, 0.4)
		_rw.sticker(tr("FF_NEW_BEST"), _mid(0.5), 60, 1.6, true, Color.WHITE, false, "best")
		_rw.spray(_rw.at(_score_l, _score_l.size * 0.5), Pal.SUN, 14, 620.0, "star", 1.0)
		_feel(Haptics.BUMP)
	_best_k.text = tr("FF_BEST") + " " + Record.grouped(maxi(_best, score))
	var m := 0
	for v: int in MILESTONES:
		if score >= v and v > _milestone:
			m = v
	if m > 0:
		_milestone = m
		_rw.sticker(Record.grouped(m) + "!", _mid(0.2), 56, 1.1, true, Color.WHITE, false, "milestone")
		_rw.ring(_rw.at(_score_l, _score_l.size * 0.5), 130.0, Color(Pal.SUN, 0.9))
		_feel(Haptics.BUMP)

# --- the tools ---

func _on_undo() -> void:
	if not can_undo():
		return
	sim.undo()
	board.lay(sim)
	_fx.cue("undo")
	_feel(Haptics.TAP)
	_rw.sticker(_undos_line(), _mid(0.94), 50, 1.2, false, Color("fff4c2"), false, "undo")
	top_bar.refresh(self)

func _undos_line() -> String:
	var n := int(sim.undos)
	return tr("BT_UNDO_LEFT_ONE") if n == 1 else tr("BT_UNDO_LEFT_N") % n

func _on_sight() -> void:
	if not sim.can_fire() or int(sim.sights) <= 0 or board.long_sight:
		_fx.cue("nope")
		return
	board.long_sight = true
	_fx.cue("sight")
	_feel(Haptics.TAP)
	_rw.sticker(tr("BT_SIGHT"), _mid(0.94), 50, 1.2, false, Color("fff4c2"), false, "sight")
	top_bar.refresh(self)

func _on_recall() -> void:
	if sim.recall():
		_recall.set_enabled(false)

## The bin asks unless nothing has been poured.
func _ask_clear() -> void:
	if _clear_card != null:
		return
	if sim == null or int(sim.volleys) == 0 or sim.is_over():
		_on_reset()
		return
	board.let_go()
	var scrim := Dialog.scrim()
	scrim.name = "ClearCard"
	_clear_card = scrim
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			_close_clear())
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(CLEAR_CARD)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	col.add_child(Dialog.head("BT_CLEAR_TITLE", "bin"))
	var body := Label.new()
	body.text = "BT_CLEAR_BODY"
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var keep := Dialog.primary("check", tr("CLEAR_NO"))
	keep.name = "Keep"
	keep.pressed.connect(_close_clear)
	var yes := Dialog.secondary("bin", tr("BT_CLEAR_YES"))
	yes.name = "Clear"
	yes.pressed.connect(func() -> void:
		_close_clear()
		_on_reset())
	Dialog.buttons(col, keep, yes)
	add_child(scrim)
	Motion.appear(scrim, 0.0, 1.0, 0.2)

func _close_clear() -> void:
	if _clear_card != null:
		_clear_card.queue_free()
		_clear_card = null

# --- the end ---

func _run_over() -> void:
	if _offer_chance():
		return
	var better := Record.add(GAME, sim.score, sim.step_n, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.step_n, "seconds": secs,
		"balls": sim.balls, "broke": sim.broke, "volleys": sim.volleys, "best": better})
	Ads.note_finished()
	top_bar.refresh(self)
	get_tree().create_timer(0.9).timeout.connect(_show_end.bind(better))

func _show_end(better: bool) -> void:
	if sim == null or not sim.is_over() or _end != null:
		return
	_fx.cue("new_best" if better else "game_over")
	_end = _build_end(better)
	add_child(_end)
	move_child(_rw, get_child_count() - 1)
	Motion.appear(_end, 0.0, 1.0, 0.3)
	_end_at = _clock
	_celebrate(better)

func _build_end(better: bool) -> Control:
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
	seat.custom_minimum_size = Vector2(0, 210)
	var shown_at := _clock
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 110.0)
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.4) / 0.35, 0.0, 1.0)
		if glow > 0.0:
			var rb := Face.Builder.new()
			var rr := 180.0 * Motion.back_out(glow)
			rb.disc(c, rr * 0.5, Color(Color("fff4c2"), 0.45))
			Rewards.sunrays(rb, c, rr * 0.2, rr, 14, t * 0.5, Color(Rewards.GOLD if better else Pal.SUN, 0.5))
			var rm := rb.mesh()
			seat.set_meta("rays", rm)
			seat.draw_mesh(rm, null)
		for k in 3:
			var hop := 0.0 if Motion.reduce or not better else -10.0 * absf(sin(t * 3.0 + k * 0.7))
			var s := 1.15 if k == 1 else 0.9
			seat.draw_mesh(Art.piece(Sim.Kind.SQUARE, [3, 1, 4][k], [1, 0, 2][k], k), null,
				Transform2D(0.02 * (k - 1), Vector2(s, s), 0.0, c + Vector2((k - 1) * 112.0, hop + (0.0 if k == 1 else 16.0)))))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "BT_END_CARD"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 740
	col.add_child(head)
	var score := Label.new()
	score.text = Record.grouped(sim.score) if Motion.reduce else "0"
	if not Motion.reduce:
		_end_score = score
	score.theme_type_variation = "DayBig"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 14)
	for pair in [[str(sim.step_n), "BT_STAT_STEP"], [Record.grouped(sim.broke), "BT_STAT_BROKE"], [str(sim.balls), "BT_STAT_BALLS"]]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.add_theme_stylebox_override("panel", Dialog.tile())
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", -4)
		plate.add_child(words)
		var value := Label.new()
		value.text = pair[0]
		value.theme_type_variation = "SheetTitle"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(value)
		var kicker := Label.new()
		kicker.text = pair[1]
		kicker.theme_type_variation = "MenuKicker"
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(kicker)
		stats.add_child(plate)
	col.add_child(stats)
	var best_line := Label.new()
	best_line.text = tr("FF_BEST_LINE") % Record.grouped(Record.best(GAME))
	best_line.theme_type_variation = "SheetBodyDim"
	best_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(best_line)
	var again := Dialog.primary("reset", tr("FF_AGAIN"))
	again.name = "Again"
	again.pressed.connect(_ask)
	var back := Dialog.secondary("chevron_left", tr("FF_BACK"))
	back.pressed.connect(_on_back)
	Dialog.buttons(col, again, back, GoldDoubler.new(_run_gold) if _run_gold > 0 else null)
	return scrim

func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 0.9, 0.0, 1.0)
	var shown := int(round(sim.score * (1.0 - pow(1.0 - k, 3.0))))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
	if k >= 1.0:
		_end_score.pivot_offset = _end_score.size * 0.5
		Motion.bump(_end_score, 0.25, 0.4)
		if sim.score > 0:
			var at := _rw.at(_end_score, _end_score.size * 0.5)
			_rw.spray(at, Pal.SUN, 10, 620.0, "star", 1.1)
			_rw.ring(at, 220.0, Color(Pal.SUN, 0.9))
		_end_score = null

func _celebrate(better: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if better:
		_rw.rain(3.0, ["confetti", "star"], Rewards.CONFETTI)

# --- chrome ---

func _on_reset() -> void:
	if sim != null and not sim.is_over() and int(sim.volleys) > 0:
		Analytics.track("board_reset", {"puzzle_id": GAME})
	_ask()

func _on_back() -> void:
	if _clear_card != null:
		_close_clear()
		return
	if sim != null and not sim.is_over() and int(sim.volleys) > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.step_n})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if _clear_card != null:
		_close_clear()
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()

# --- boosters (arcade/boosters.gd) ---

## Before a run: the boost card, when a booster is held or the gold for one
## is, else straight in.
func _ask(by_hand := true) -> void:
	if get_node_or_null("BoostCard") != null or get_node_or_null("SecondChance") != null:
		return
	if _end != null:
		_end.queue_free()
		_end = null
	if not BoostCard.wanted(GAME):
		_boosts = []
		_new_game()
		if by_hand:
			_fx.buzz(Haptics.TAP)
		return
	if sim == null:
		sim = Sim.new()
		board.lay(sim)
		_over_told = true
		_refresh_hud()
	var card := BoostCard.new(GAME)
	card.name = "BoostCard"
	card.play.connect(func(ids: Array) -> void:
		_boosts = ids
		_new_game()
		_fx.buzz(Haptics.TAP))
	add_child(card)

## At the end, once a run: the Second chance. True while it is up; No thanks
## ends the run as it would have.
func _offer_chance() -> bool:
	if _chance_used or not SecondChance.wanted() or sim.score <= 0:
		return false
	_chance_used = true
	var card := SecondChance.new(GAME)
	card.name = "SecondChance"
	card.taken.connect(func() -> void:
		_boosted = true
		Boosters.revive(GAME, sim)
		board.lay(sim)
		_over_told = false
		_fx.buzz(Haptics.GOOD)
		_fx.cue("revive")
		top_bar.refresh(self))
	card.declined.connect(_run_over)
	add_child(card)
	return true
