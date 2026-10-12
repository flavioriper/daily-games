extends Control

## Trivet: the thirteenth game on the Arcade tab, stacks of felt mats sorted
## on a wooden tray (spec
## docs/superpowers/specs/2026-10-12-arcade-trivet-design.md). **The table
## is the whole screen**, edge to edge (the house's pattern since
## 2026-10-10): no page and no frame. Over it lie the flat boards' top bar
## (back, the title in ink, restart, settings) and a paper row with the
## score, the best and the level with how far along it the score is.
##
## Play: one of the hand's three stacks is carried to an empty place, or
## tapped and then the place is. Stacks that touch with one colour on top
## gather, ten of a colour are put away, and the tray full with no brush
## left ends the run. The game is arcade/trivet_sim.gd; the table
## (arcade/trivet_board.gd) draws it, takes the fingers and says what it has
## shown (`beat`), and this screen plays that: the sound, the knock, the
## stickers and the cards.

signal closed

const Sim = preload("res://arcade/trivet_sim.gd")
const Art = preload("res://arcade/trivet_art.gd")
const Board = preload("res://arcade/trivet_board.gd")
const Record = preload("res://arcade/arcade_record.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
## What the phone knocks for (docs/agents/haptics.md). A mat landing and a
## mat put away are felt as their sound's echo, climbing with it; what
## shares a frame asks through `_feel` and the frame knocks once, with the
## strongest. Only the end card's cues are mapped.
const HAPTICS := {"new_best": Haptics.WIN, "game_over": Haptics.LOSE}
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "trivet"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
## The score lettered over the table as it passes each of these.
const MILESTONES := [100, 250, 500, 750, 1000, 1500, 2000, 3000, 5000]
## The cozy rules (docs/agents/sound.md): no cue climbs past five semitones
## and a tick that repeats is never the same twice. A mat's tick climbs half
## a semitone a mat through one move's gathering.
const CLIMB_TOP := 1.335
const CLIMB_STEP := 0.5
const TICK_VARY := 0.06

var sim: RefCounted
var board: Control
## The run's boosters and whether it was helped (arcade/boosters.gd): a best
## made so is marked. The Second chance is offered once a run.
var _boosts: Array = []
var _boosted := false
var _chance_used := false
var _run_gold := 0
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var _fx: Node2D
var _margins: MarginContainer
var _score_l: Label
var _best_l: Label
var _level_l: Label
var _level_k: Label
var _banner: Label
var _sub: Label
var _banner_tw: Tween
var _end: Control
var _started_at := 0
var _best := 0
var _shown_score := -1
var _shown_level := -1
var _beat_best := false
var _knock := -1
var _clock := 0.0
## Mats landed since the last stack was set down: the tick's climb.
var _hops := 0
var _over_told := false
var _seat: Control
var _rw: Rewards
var _milestone := 0
var _end_score: Label
var _end_at := 0.0

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
	tutor = ScreenTutor.new(self, puzzle_id(), "Trivet")
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_ask(false)

# --- building ---

func _build() -> void:
	board = Board.new()
	board.name = "Board"
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.beat.connect(_on_beat)
	add_child(board)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	board.add_child(_fx)

	var over := VBoxContainer.new()
	over.alignment = BoxContainer.ALIGNMENT_CENTER
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(over)
	_banner = Label.new()
	_banner.theme_type_variation = "WellDone"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_color_override("font_color", Art.CREAM)
	_banner.add_theme_color_override("font_shadow_color", Color(0.29, 0.21, 0.15, 0.6))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	_banner.add_theme_color_override("font_outline_color", Art.INK)
	_banner.add_theme_constant_override("outline_size", 12)
	over.add_child(_banner)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetTitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_color_override("font_color", Art.CREAM)
	_sub.add_theme_color_override("font_outline_color", Art.INK)
	_sub.add_theme_constant_override("outline_size", 8)
	over.add_child(_sub)
	over.modulate.a = 0.0
	_banner.set_meta("box", over)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margins.add_child(col)
	top_bar = FlatTopBar.new("Trivet", tr("TV_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())
	_rw = Rewards.new()
	add_child(_rw)
	_apply_insets()

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var made := []
	for key in ["FF_SCORE", "FF_BEST", "TV_LEVEL"]:
		var plate := PanelContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.size_flags_stretch_ratio = 1.25 if key == "TV_LEVEL" else 1.0
		plate.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 30, 8))
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", -6)
		plate.add_child(words)
		var kicker := Label.new()
		kicker.text = key
		kicker.theme_type_variation = "MenuKicker"
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(kicker)
		var value := Label.new()
		value.text = "0"
		value.theme_type_variation = "SheetTitle"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(value)
		row.add_child(plate)
		made.append(value)
		if key == "TV_LEVEL":
			_level_k = kicker
	_score_l = made[0]
	_best_l = made[1]
	_level_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	board.top_band = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + GAP
	board.foot_band = MARGIN * 0.5 + insets.y
	board.layout()
	_place_banner()

func _place_banner() -> void:
	if _banner == null:
		return
	var box: Control = _banner.get_meta("box")
	box.size.x = size.x * 0.86
	box.reset_size()
	box.size.x = size.x * 0.86
	box.position = Vector2(size.x * 0.07, board.top_band + 6.0)
	box.pivot_offset = box.size * 0.5

# --- the game ---

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	sim = Sim.new()
	Boosters.apply(GAME, sim, _boosts)
	_boosted = not _boosts.is_empty()
	_chance_used = false
	_run_gold = 0
	_beat_best = false
	_milestone = 0
	_hops = 0
	_over_told = false
	_end_score = null
	_rw.clear()
	_best = Record.best(GAME)
	_shown_score = -1
	_shown_level = -1
	_started_at = Time.get_ticks_msec()
	board.lay(sim)
	_refresh_hud()
	top_bar.refresh(self)
	_fx.cue("start")
	Analytics.track("arcade_start", {"game": GAME, "boosts": ",".join(_boosts)})

## The tutorial card's pages (ui/hud/screen_tutor.gd), each a small table
## played by a hand (ui/hud/trivet_tutorial_diagram.gd). Every number in the
## text is the sim's own.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/trivet_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.PLACE, "TUT_TRIVET_PLACE", tr("TUT_TRIVET_PLACE_BODY") % Sim.HAND],
		[Diagram.Lesson.GATHER, "TUT_TRIVET_GATHER", tr("TUT_TRIVET_GATHER_BODY")],
		[Diagram.Lesson.CLEAR, "TUT_TRIVET_CLEAR", tr("TUT_TRIVET_CLEAR_BODY") % Sim.CLEAR],
		[Diagram.Lesson.CHAIN, "TUT_TRIVET_CHAIN", tr("TUT_TRIVET_CHAIN_BODY")],
		[Diagram.Lesson.LEVELS, "TUT_TRIVET_LEVELS", tr("TUT_TRIVET_LEVELS_BODY") % [Sim.COLOURS_FROM, Sim.COLOURS_MOST]],
		[Diagram.Lesson.TOOLS, "TUT_TRIVET_TOOLS", tr("TUT_TRIVET_TOOLS_BODY")],
		[Diagram.Lesson.BOOSTS, "TUT_TRIVET_BOOSTS", tr("TUT_TRIVET_BOOSTS_BODY")],
		[Diagram.Lesson.HUD, "TUT_TRIVET_HUD", tr("TUT_TRIVET_HUD_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func capabilities() -> Array:
	return []

func is_done() -> bool:
	return sim != null and sim.is_over()

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

func hints_left() -> int:
	return 0

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	_refresh_hud()
	_knock_now()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()
	# the run is over once the table has shown the last of it
	if sim.is_over() and not _over_told and board.settled():
		_over_told = true
		_run_over()

## Asks for a knock this frame; the strongest asked for is the one played.
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

# --- what the table shows ---

func _on_beat(what: String, data: Dictionary) -> void:
	match what:
		"ready":
			_hint(tr("TV_READY"), tr("TV_READY_LINE") % Sim.CLEAR)
		"lift":
			_fx.cue("lift", _vary())
		"back":
			_fx.cue("back")
		"arm", "disarm":
			_fx.touch()
		"place":
			_hops = 0
			_hint("", "")
			_fx.cue("place", _vary())
			_feel(Haptics.TAP)
		"hop":
			_fx.cue("hop", _climb(_hops) * _vary())
			_hops += 1
		"gather":
			pass
		"pop":
			_fx.cue("pop", _climb(int(data.k)) * _vary())
		"clear":
			_on_clear(data)
		"level":
			_on_level(data)
		"deal":
			_fx.cue("deal")
		"redeal":
			_feel(Haptics.TAP)
		"sweep":
			_fx.cue("sweep")
			_feel(Haptics.BUMP)
			_hint("", "")
		"nope":
			_fx.cue("nope")
			_feel(Haptics.WARN)
		"tight":
			_fx.cue("warn")
			_feel(Haptics.WARN)
			_rw.sticker(tr("TV_TIGHT"), _rw.at(board, Vector2(size.x * 0.5, board.top_band + 70.0)), 46, 1.6, false, Color("ffd9a0"), false, "tight")
		"full":
			_fx.cue("warn")
			_feel(Haptics.WARN)
			_hint(tr("TV_FULL"), tr("TV_FULL_LINE"))
		"over":
			_fx.cue("over")
			_feel(Haptics.BAD)
		"revive":
			_hint(tr("CHANCE_GO"), "")
			get_tree().create_timer(1.2).timeout.connect(func() -> void: _hint("", ""))

## A stack put away: its points lettered where it stood, motes of its felt
## home to the score, and the more for each stack the same move had put
## away before it.
func _on_clear(data: Dictionary) -> void:
	var chain := int(data.chain)
	var col: Color = Art.FELT[int(data.col)]
	var at := _rw.at(board, data.at)
	_fx.cue("clear" if chain <= 1 else ("combo" if chain == 2 else "combo_big"), _climb(2.0 * maxi(chain - 3, 0)))
	_feel(Haptics.GOOD if chain <= 1 else Haptics.WIN)
	_rw.sticker("+%d" % int(data.pts), at - Vector2(0, 70.0), 56 + 8 * mini(chain, 3), 1.1, false, col.lightened(0.45), false, "", 40.0)
	_rw.spray(at, col.lightened(0.15), 8 + 4 * mini(chain, 3), 560.0, "mote", 1.1, 0.0, _plate_at(_score_l))
	_rw.spray(at, Art.CREAM, 5 + 2 * chain, 480.0, "spark", 0.9)
	_rw.ring(at, 170.0 + 40.0 * mini(chain, 3), Color(col.lightened(0.3), 0.9))
	if chain >= 2:
		var word := tr("TV_CHAIN_2") if chain == 2 else (tr("TV_CHAIN_3") if chain == 3 else tr("TV_CHAIN_N") % chain)
		_rw.sticker(word, _rw.at(board, Vector2(size.x * 0.5, board.top_band + 150.0)), 62 + 6 * mini(chain, 4), 1.4, chain >= 3, Color.WHITE, chain >= 3, "chain")
		_rw.spray(at, Pal.SUN, 6 + 3 * chain, 640.0, "star", 1.0)

func _on_level(data: Dictionary) -> void:
	_fx.cue("level")
	_feel(Haptics.GOOD)
	var at := _rw.at(board, Vector2(size.x * 0.5, board.top_band + 230.0))
	_rw.sticker(tr("TV_LEVEL_UP") % int(data.n), at, 70, 1.6, true, Color.WHITE, true, "level")
	_rw.spray(at, Pal.SUN, 12, 700.0, "star", 1.0)
	_rw.spray(at, Art.CREAM, 8, 560.0, "spark", 1.0)
	var lines: Array = []
	if int(data.colour) >= 0:
		lines.append(tr("TV_NEW_COLOUR"))
	if int(data.open) >= 0:
		lines.append(tr("TV_NEW_PLACE"))
	if String(data.tool) == "sweep":
		lines.append(tr("TV_NEW_BRUSH"))
	elif String(data.tool) == "deal":
		lines.append(tr("TV_NEW_HAND"))
	if not lines.is_empty():
		var tint: Color = Art.FELT[int(data.colour)].lightened(0.4) if int(data.colour) >= 0 else Color("fff4c2")
		_rw.sticker(" · ".join(lines), at + Vector2(0, 84.0), 40, 2.0, false, tint, false, "level_line")
	_level_l.pivot_offset = _level_l.size * 0.5
	Motion.bump(_level_l, 0.3, 0.4)

## The two lines over the table: up while there is something to say.
func _hint(text: String, sub: String) -> void:
	var box: Control = _banner.get_meta("box")
	Motion.stop(_banner_tw)
	if text == "":
		_banner_tw = create_tween()
		_banner_tw.tween_property(box, "modulate:a", 0.0, 0.18)
		return
	_banner.text = text
	_sub.text = sub
	_sub.visible = sub != ""
	_place_banner()
	_banner_tw = create_tween()
	_banner_tw.tween_property(box, "modulate:a", 1.0, 0.2)

## The plates read the score as far as the table has shown it: a stack's
## points are counted when its last mat is put away, not when it was set
## down.
func _refresh_hud() -> void:
	if sim == null:
		return
	var score: int = board.shown_score
	var level: int = board.shown_level
	if score == _shown_score and level == _shown_level:
		return
	if score > _shown_score and _shown_score >= 0:
		_score_l.pivot_offset = _score_l.size * 0.5
		Motion.bump(_score_l, 0.14, 0.26)
	_shown_score = score
	_shown_level = level
	_score_l.text = Record.grouped(score)
	_best_l.text = Record.grouped(maxi(_best, score))
	_level_k.text = tr("TV_LEVEL_N") % level
	_level_l.text = "%d/%d" % [score, Sim.goal(level)]
	if not _beat_best and _best > 0 and score > _best:
		_beat_best = true
		_best_l.pivot_offset = _best_l.size * 0.5
		Motion.bump(_best_l, 0.3, 0.4)
		_new_best_passed()
	_score_moments(score)

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

func _score_moments(score: int) -> void:
	var m := 0
	for v: int in MILESTONES:
		if score >= v and v > _milestone:
			m = v
	if m > 0:
		_milestone = m
		_rw.sticker(Record.grouped(m) + "!", _rw.at(board, Vector2(size.x * 0.5, size.y * 0.42)), 64, 1.2, true, Color.WHITE, false, "milestone")
		_rw.spray(_plate_at(_score_l), Pal.SUN, 10, 520.0, "star", 0.9)
		_rw.ring(_plate_at(_score_l), 140.0, Color(Pal.SUN, 0.9))
		_feel(Haptics.BUMP)

func _new_best_passed() -> void:
	_rw.sticker(tr("FF_NEW_BEST"), _rw.at(board, Vector2(size.x * 0.5, size.y * 0.5)), 60, 1.6, true, Color.WHITE, false, "best")
	_rw.spray(_plate_at(_best_l), Pal.SUN, 14, 620.0, "star", 1.0)
	_rw.ring(_plate_at(_best_l), 160.0, Color(Pal.SUN, 0.9))
	_feel(Haptics.BUMP)

# --- the end ---

func _run_over() -> void:
	if _offer_chance():
		return
	var better := Record.add(GAME, sim.score, sim.level, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.level,
		"seconds": secs, "placed": sim.placed, "chain": sim.best_chain, "best": better})
	Ads.note_finished()
	top_bar.refresh(self)
	get_tree().create_timer(0.9).timeout.connect(_show_end.bind(better))

func _show_end(better: bool) -> void:
	if sim == null or not sim.is_over() or _end != null:
		return
	_fx.cue("new_best" if better else "game_over")
	_end = _build_end(better)
	add_child(_end)
	# the rewards (their rain and bursts) stay over the card
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
	seat.custom_minimum_size = Vector2(0, 230)
	# Three stacks side by side over a sunburst, the middle one the tallest.
	var piles := [Art.stack([2, 2, 2]), Art.stack([0, 0, 1, 1, 3, 3]), Art.stack([4, 4, 5, 5])]
	var shown_at := _clock
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 150.0)
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.4) / 0.35, 0.0, 1.0)
		if glow > 0.0:
			var rb := Face.Builder.new()
			var rr := 190.0 * Motion.back_out(glow)
			rb.disc(c - Vector2(0, 40.0), rr * 0.5, Color(Color("fff4c2"), 0.45))
			Rewards.sunrays(rb, c - Vector2(0, 40.0), rr * 0.2, rr, 14, t * 0.5, Color(Rewards.GOLD if better else Pal.SUN, 0.5))
			Rewards.sunrays(rb, c - Vector2(0, 40.0), rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
			var rm := rb.mesh()
			seat.set_meta("rays", rm)
			seat.draw_mesh(rm, null)
		for k in 3:
			var hop := 0.0 if Motion.reduce or not better else -10.0 * absf(sin(t * 3.0 + k * 0.7))
			var s := (0.62 if k == 1 else 0.5)
			seat.draw_mesh(piles[k], null, Transform2D(0.0, Vector2(s, s), 0.0, c + Vector2((k - 1) * 150.0, hop + (0.0 if k == 1 else -6.0)))))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "TV_END_CARD"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# the longer languages take two lines rather than widen the card
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
	for pair in [[str(sim.level), "TV_STAT_LEVEL"], [str(sim.cleared), "TV_STAT_MATS"], ["x%d" % maxi(sim.best_chain, 1), "TV_STAT_CHAIN"]]:
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

## The end card's score runs up from nothing to what the run made, with a
## burst of stars when it gets there.
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
			_rw.spray(at, Color("fffaf0"), 8, 480.0, "spark", 1.1)
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
	if sim != null and not sim.is_over():
		Analytics.track("board_reset", {"puzzle_id": GAME})
	_ask()

func _on_back() -> void:
	if sim != null and not sim.is_over() and sim.score > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.level})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
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
		# Restart and Play again tap; the screen opening says nothing.
		if by_hand:
			_fx.buzz(Haptics.TAP)
		return
	if sim != null and not sim.is_over():
		_hint("", "")
	if sim == null:
		# the table is laid under the card, with nothing to play yet
		sim = Sim.new()
		board.lay(sim)
		board.interactive = true
		_over_told = true
	var card := BoostCard.new(GAME)
	card.name = "BoostCard"
	card.play.connect(func(ids: Array) -> void:
		_boosts = ids
		_new_game()
		_fx.buzz(Haptics.TAP))
	add_child(card)

## At the end, once a run: the Second chance, when one is held or the gold
## for one is. True while it is up; No thanks ends the run as it would have.
func _offer_chance() -> bool:
	if _chance_used or not SecondChance.wanted() or sim.score <= 0:
		return false
	_chance_used = true
	var card := SecondChance.new(GAME)
	card.name = "SecondChance"
	card.taken.connect(func() -> void:
		_boosted = true
		Boosters.revive(GAME, sim)
		_over_told = false
		board.play()
		_fx.buzz(Haptics.GOOD)
		_fx.cue("revive")
		top_bar.refresh(self))
	card.declined.connect(_run_over)
	add_child(card)
	return true
