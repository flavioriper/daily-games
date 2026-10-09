extends Control

## Beeline: the eighth game on the Arcade tab, the tap-to-fly game re-dressed
## as a bee in a garden (spec
## docs/superpowers/specs/2026-10-09-arcade-beeline-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the score, the best and the next ribbon, and under them the garden
## in a wooden frame: a morning sky, far hills, the lawn, and the hedges
## coming with a gap in each.
##
## Play: a tap anywhere in the garden is one beat of her wings. The game is
## arcade/beeline_sim.gd, stepped at its fixed DT; this screen draws it and
## plays its events.
##
## Drawing: one Control. The sky is a still mesh built on resize; the
## clouds, the hills and the lawn are tiles slid by the transform; a hedge
## is one of two cached columns stood on its gap's edge; the bee is her
## body and her wings, turned and squashed by the transform. The dewdrop,
## the pollen and the leaves are one live mesh over them.

signal closed

const Sim = preload("res://arcade/beeline_sim.gd")
const Art = preload("res://arcade/beeline_art.gd")
const Record = preload("res://arcade/arcade_record.gd")
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
## What the phone knocks for (docs/agents/haptics.md). A beat of the wings
## is felt as its sound's echo; the events that share a frame (`pass` and
## `ribbon`, `bump` and `dew`) ask through `_feel` and the frame knocks once,
## with the strongest. Only the end card's cue is mapped.
const HAPTICS := {"new_best": Haptics.WIN}
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "beeline"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
## The most sim steps one frame may run, so a stall never fast-forwards.
const MAX_STEPS := 24
## Where she flies, as a part of the garden's width from its left edge.
const BEE_AT := 0.3
## How far the far things slide for every unit she flies.
const CLOUD_SLIDE := 0.12
const HILL_SLIDE := 0.3
## Her lean: nose up on a beat, nose down as she sinks (radians).
const LEAN_UP := -0.42
const LEAN_DOWN := 0.95
## The score lettered over the garden as it passes each of these, past the
## ribbons.
const MILESTONES := [50, 75, 100, 150, 200, 300, 500]
const LEAF_COLS := [Art.HEDGE, Art.HEDGE_HI, Art.HEDGE_DEEP]
const POLLEN := Color("fbe08a")

var sim: RefCounted
## The run's boosters and whether it was helped (arcade/boosters.gd): a best
## made so is marked. The Second chance is offered once a run, and the gold
## the run earned goes on the end card.
var _boosts: Array = []
var _boosted := false
var _chance_used := false
var _run_gold := 0
var top_bar: Control
var settings_sheet: Control
## The tutorial card: the top bar's ?, the settings' How to play and the
## first play (ui/hud/screen_tutor.gd).
var tutor: RefCounted
var field: Control
var _fx: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _score_l: Label
var _best_l: Label
var _next_l: Label
var _banner: Label
var _sub: Label
var _banner_tw: Tween
var _pause_card: Control
var _end: Control
var _acc := 0.0
var _paused := false
var _started_at := 0
var _best := 0
var _shown_score := -1
var _beat_best := false
## The knock this frame's events asked for, the strongest of them (-1: none).
var _knock := -1
## Pixels a field unit, and her place across the garden, in pixels.
var _u := 3.0
var _bee_x := 100.0
var _sky: ArrayMesh
var _live: ArrayMesh
## The screen's own clock, for motion the sim does not own; it stops with
## the pause.
var _clock := 0.0
## Her lean as drawn, eased toward what her speed asks.
var _lean := 0.0
## When she last beat her wings and when the score last rose, on `_clock`.
var _flap_at := -10.0
var _pass_at := -10.0
## Bits in the garden's own space: {kind, pos (field units, x along the
## garden), t, seed, col}. Pollen off a beat, leaves off a hedge, a ring
## where a gap was passed, a dewdrop's burst.
var _bits: Array = []
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _flash := 0.0
## She met a hedge this run and is on her way down: the grass is then only
## heard.
var _bumped := false
var _seat: Control
## The loud rewards over the whole screen (arcade/rewards.gd).
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
	tutor = ScreenTutor.new(self, puzzle_id(), "Beeline", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	# before any run: the boost card may stand first, and the bar would wear
	# the Undo and the bulb this game has not got until Play
	top_bar.refresh(self)
	_ask(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if sim != null and sim.phase == Sim.Phase.PLAY and _end == null:
			_pause(true)

# --- building ---

func _build() -> void:
	var page := ColorRect.new()
	page.color = Pal.PAPER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_backdrop = Vistas.board_plate(GAME, Pal.LEAF_DEEP)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_backdrop)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Beeline", tr("BL_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void:
		_pause(true)
		settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())
	col.add_child(_build_frame())
	_rw = Rewards.new()
	add_child(_rw)
	_apply_insets()

## The wooden frame with the garden in it: the field, the two lines of
## lettering over it and the effects. The tutorial's small garden
## (ui/hud/beeline_tutorial_diagram.gd) is this and the plates, nothing else.
func _build_frame() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color("6e4a2f")
	box.set_corner_radius_all(36)
	box.border_color = Color("9c6b45")
	box.set_border_width_all(6)
	box.set_content_margin_all(FRAME)
	box.shadow_color = Color(0.2, 0.1, 0.05, 0.25)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 6)
	frame.add_theme_stylebox_override("panel", box)
	field = Control.new()
	field.name = "Field"
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.resized.connect(_layout_field)
	field.gui_input.connect(_on_field_input)
	frame.add_child(field)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	field.add_child(_fx)

	var over := VBoxContainer.new()
	over.alignment = BoxContainer.ALIGNMENT_CENTER
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(over)
	_banner = Label.new()
	_banner.theme_type_variation = "WellDone"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", Color("fffaf0"))
	_banner.add_theme_color_override("font_shadow_color", Color(0.29, 0.23, 0.16, 0.6))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	_banner.add_theme_color_override("font_outline_color", Art.INK)
	_banner.add_theme_constant_override("outline_size", 12)
	over.add_child(_banner)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetTitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Art.INK)
	over.add_child(_sub)
	over.modulate.a = 0.0
	_banner.set_meta("box", over)
	return frame

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["FF_SCORE", "FF_BEST", "BL_NEXT"]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.size_flags_stretch_ratio = 1.25 if key == "FF_SCORE" else 1.0
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
	_score_l = made[0]
	_best_l = made[1]
	_next_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The garden is as tall as the room: the sky and the strip of lawn under
## it. A wider room shows more of the garden ahead.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_u = s.y / (Sim.H + Art.GROUND)
	_bee_x = s.x * BEE_AT
	_sky = Art.sky(s)
	if _banner != null:
		_place_banner()
	field.queue_redraw()

func _place_banner() -> void:
	var box: Control = _banner.get_meta("box")
	box.reset_size()
	box.size.x = field.size.x
	box.position = Vector2(0, field.size.y * 0.24)
	box.pivot_offset = box.size * 0.5

## A point of the garden (x along it, y down from the sky's top, in field
## units) in the field's pixels.
func px(p: Vector2) -> Vector2:
	var along: float = sim.x if sim != null else 0.0
	return Vector2(_bee_x + (p.x - along) * _u, p.y * _u)

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
	_acc = 0.0
	_paused = false
	_bits.clear()
	_shake = 0.0
	_flash = 0.0
	_bumped = false
	_lean = 0.0
	_flap_at = -10.0
	_pass_at = -10.0
	_beat_best = false
	_milestone = 0
	_end_score = null
	_rw.clear()
	_best = Record.best(GAME)
	_shown_score = -1
	_started_at = Time.get_ticks_msec()
	if _pause_card != null:
		_pause_card.queue_free()
		_pause_card = null
	_refresh_hud()
	top_bar.refresh(self)
	_fx.cue("start")
	_play_events()
	Analytics.track("arcade_start", {"game": GAME, "boosts": ",".join(_boosts)})

## The tutorial card's pages (ui/hud/screen_tutor.gd), each a small garden
## flown by this screen and the sim (ui/hud/beeline_tutorial_diagram.gd).
## Every number in the text is the sim's own.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/beeline_tutorial_diagram.gd")
	var r: Array = Sim.RIBBONS
	var steps := [
		[Diagram.Lesson.FLY, "TUT_BEELINE_FLY", tr("TUT_BEELINE_FLY_BODY")],
		[Diagram.Lesson.GAPS, "TUT_BEELINE_GAPS", tr("TUT_BEELINE_GAPS_BODY")],
		[Diagram.Lesson.BUMP, "TUT_BEELINE_BUMP", tr("TUT_BEELINE_BUMP_BODY")],
		[Diagram.Lesson.RIBBONS, "TUT_BEELINE_RIBBONS", tr("TUT_BEELINE_RIBBONS_BODY") % [r[0], r[1], r[2], r[3]]],
		[Diagram.Lesson.BOOSTS, "TUT_BEELINE_BOOSTS", tr("TUT_BEELINE_BOOSTS_BODY")],
		[Diagram.Lesson.HUD, "TUT_BEELINE_HUD", tr("TUT_BEELINE_HUD_BODY")],
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
	if not _paused:
		_clock += delta
		_acc += minf(delta, Sim.DT * MAX_STEPS)
		while _acc >= Sim.DT:
			_acc -= Sim.DT
			sim.step()
			_play_events()
		_animate(delta)
	_refresh_hud()
	_knock_now()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()
	field.queue_redraw()

## Asks for a knock this frame; the strongest asked for is the one played.
func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _knock_now() -> void:
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1

func _animate(delta: float) -> void:
	for bit: Dictionary in _bits:
		bit.t += delta
	_bits = _bits.filter(func(bit: Dictionary) -> bool: return bit.t < bit.life)
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 12.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO
	_flash = maxf(0.0, _flash - delta * 3.0)
	var want := 0.0
	match sim.phase:
		Sim.Phase.PLAY:
			want = remap(clampf(sim.v, Sim.FLAP_V, Sim.MAX_FALL), Sim.FLAP_V, Sim.MAX_FALL, LEAN_UP, LEAN_DOWN)
			# level through most of the rise and the first of the fall
			if sim.v < 120.0:
				want = lerpf(LEAN_UP, 0.0, clampf((sim.v - Sim.FLAP_V) / (120.0 - Sim.FLAP_V), 0.0, 1.0) * 0.5)
		Sim.Phase.FALL:
			want = _lean + delta * 9.0
		Sim.Phase.OVER:
			want = 0.5
	_lean = want if sim.phase == Sim.Phase.FALL else lerpf(_lean, want, minf(1.0, delta * 14.0))
	_rw.bounds = Rect2(_rw.at(field, Vector2.ZERO), field.size)
	_rw.step(delta)

func _on_field_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	if _paused:
		if _end != null or settings_sheet.is_open():
			return
		# the tap that takes the run up again is a beat too, so she is not
		# dropped from where she was held
		_pause(false)
	beat()

## One beat of her wings, told to the sim.
func beat() -> void:
	if sim == null or _paused or sim.phase == Sim.Phase.FALL or sim.phase == Sim.Phase.OVER:
		return
	sim.flap()
	_play_events()

## The tutorial card stops the run and leaves it paused, a tap from going on.
func _tutor_hold(on: bool) -> void:
	if on and sim != null and sim.phase == Sim.Phase.PLAY and _end == null:
		_pause(true)

func _pause(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	if on:
		_pause_card = _build_pause()
		field.add_child(_pause_card)
		Motion.appear(_pause_card, 0.0, 1.0, 0.2)
	elif _pause_card != null:
		_pause_card.queue_free()
		_pause_card = null

func _build_pause() -> Control:
	var scrim := ColorRect.new()
	scrim.color = Color(0.16, 0.12, 0.06, 0.5)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(col)
	var head := Label.new()
	head.text = "FF_PAUSED"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", Color("fffaf0"))
	col.add_child(head)
	var line := Label.new()
	line.text = "BL_RESUME"
	line.theme_type_variation = "SheetTitle"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_color_override("font_color", Color("fffaf0"))
	col.add_child(line)
	return scrim

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		var at := Vector2(sim.x, sim.y)
		match String(ev.type):
			"ready":
				_hint(tr("BL_READY"), tr("BL_READY_LINE"))
			"go":
				_hint("", "")
			"flap":
				_flap_at = _clock
				_fx.cue("flap", randf_range(0.94, 1.06))
				for k in 3:
					_bit("pollen", at + Vector2(-Art.BEE * 0.7, 3.0 + 3.0 * k), POLLEN, 0.55)
			"pass":
				_pass_at = _clock
				_fx.cue("pass", 1.0 + 0.012 * mini(int(ev.n) % 10, 9))
				_feel(Haptics.TICK)
				_bit("ring", Vector2(sim.x - Sim.R, float(ev.cy)), Color("fffaf0"), 0.4)
			"ribbon":
				_on_ribbon(int(ev.tier))
			"dew":
				_fx.cue("dew")
				_feel(Haptics.BUMP)
				_bit("burst", at, Art.DEW, 0.5)
				_shake = maxf(_shake, 0.3)
				_rw.sticker(tr("BL_DEW_POP"), _in_rw(at + Vector2(0, -34.0)), 54, 1.1, false, Color("8fd0e6"), false, "dew", 30.0)
				_rw.spray(_in_rw(at), Art.DEW, 10, 520.0, "spark", 1.0)
			"bump":
				_fx.cue("bump")
				_feel(Haptics.BAD)
				_bumped = true
				_shake = maxf(_shake, 0.7)
				_flash = 0.5 if not Motion.reduce else 0.0
				for k in 12:
					_bit("leaf", at + Vector2(Sim.R, 0.0), LEAF_COLS[k % LEAF_COLS.size()], 0.8)
				_rw.spray(_in_rw(at), Color("fffaf0"), 6, 420.0, "spark", 0.9)
			"land":
				# after a hedge the grass is only heard; flown into, it is the bump
				_fx.cue("land")
				if not _bumped:
					_feel(Haptics.BAD)
					_shake = maxf(_shake, 0.5)
				for k in 6:
					_bit("leaf", Vector2(sim.x, Sim.H - 2.0), Art.LAWN_HI if k % 2 == 0 else Art.LAWN_DEEP, 0.6)
			"over":
				_run_over()
			"revive":
				_bumped = false
				_hint(tr("CHANCE_GO"), tr("BL_READY_LINE"))
				_bit("burst", at, Art.DEW, 0.5)
	sim.events.clear()

func _bit(kind: String, pos: Vector2, col: Color, life: float) -> void:
	_bits.append({"kind": kind, "pos": pos, "t": 0.0, "life": life, "col": col, "seed": randf() * 100.0})

## The two lines over the garden before the first beat: up while there is
## something to say, gone on the beat.
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
	box.scale = Vector2.ONE
	_banner_tw = create_tween()
	_banner_tw.tween_property(box, "modulate:a", 1.0, 0.2)

## The score and the best are plain numbers here, one a gap; the third
## plate reads the score the next ribbon is won at.
func _refresh_hud() -> void:
	if sim == null:
		return
	if sim.score == _shown_score:
		return
	if sim.score > _shown_score and _shown_score >= 0:
		_score_l.pivot_offset = _score_l.size * 0.5
		Motion.bump(_score_l, 0.14, 0.26)
	_shown_score = sim.score
	_score_l.text = Record.grouped(sim.score)
	_best_l.text = Record.grouped(maxi(_best, sim.score))
	_next_l.text = str(Sim.RIBBONS[sim.ribbons]) if sim.ribbons < Sim.RIBBONS.size() else "%d/%d" % [sim.ribbons, Sim.RIBBONS.size()]
	if not _beat_best and _best > 0 and sim.score > _best:
		_beat_best = true
		_best_l.pivot_offset = _best_l.size * 0.5
		Motion.bump(_best_l, 0.3, 0.4)
		_new_best_passed()
	_score_moments()

# --- drawing ---

func _draw_field() -> void:
	if _sky == null:
		_layout_field()
	if _sky == null:
		return
	var s := field.size
	var along: float = sim.x if sim != null else 0.0
	var ground_y := Sim.H * _u
	field.draw_set_transform(_shake_off)
	field.draw_mesh(_sky, null)
	# the clouds drift by themselves as well, so a garden at rest is not still
	var drift := 0.0 if Motion.reduce else _clock * 3.0
	_tiles(Art.clouds(_u), Art.CLOUD_TILE, along * CLOUD_SLIDE + drift, 0.0)
	_tiles(Art.hills(_u), Art.HILL_TILE, along * HILL_SLIDE, ground_y)
	if sim != null:
		_draw_gates()
	_tiles(Art.ground(_u), Art.GROUND_TILE, along, ground_y)
	if sim != null:
		_draw_bee()
		_draw_live()
		_draw_score()
	if _flash > 0.0:
		field.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.5 * _flash))
	field.draw_set_transform(Vector2.ZERO)

## A strip's tiles laid across the garden, slid `along` units to the left.
func _tiles(mesh: ArrayMesh, tile: float, along: float, y: float) -> void:
	var w := tile * _u
	var x := -fposmod(along * _u, w)
	while x < field.size.x:
		field.draw_mesh(mesh, null, Transform2D(0.0, Vector2(x, y)))
		x += w

func _draw_gates() -> void:
	var up := Art.hedge(_u, false)
	var down := Art.hedge(_u, true)
	var reach := (Sim.GATE_W + 8.0) * _u
	for g: Dictionary in sim.gates:
		var x := px(Vector2(float(g.x) + Sim.GATE_W * 0.5, 0.0)).x
		if x < -reach or x > field.size.x + reach:
			continue
		var top: float = (float(g.cy) - float(g.gap) * 0.5) * _u
		var bottom: float = (float(g.cy) + float(g.gap) * 0.5) * _u
		field.draw_mesh(down, null, Transform2D(0.0, Vector2(x, top)))
		field.draw_mesh(up, null, Transform2D(0.0, Vector2(x, bottom)))
		# the gap a ribbon is won at wears it
		var tier := Sim.RIBBONS.find(int(g.n) + 1) + 1
		if tier > 0:
			field.draw_mesh(Art.ribbon(tier, 7.0 * _u), null, Transform2D(0.0, Vector2(x, bottom + 10.0 * _u)))

## Where she is drawn: the sim's place, bobbing a little while she hovers.
func _bee_at() -> Vector2:
	var at := Vector2(_bee_x, sim.y * _u)
	if sim.phase == Sim.Phase.READY and not Motion.reduce:
		at.y += sin(_clock * 4.2) * 4.0 * _u
	return at

func _draw_bee() -> void:
	var at := _bee_at()
	var look := Art.Look.FLY
	if sim.phase == Sim.Phase.FALL or sim.phase == Sim.Phase.OVER:
		look = Art.Look.DIZZY
	elif _clock - _pass_at < 0.3:
		look = Art.Look.GLAD
	var sc := Vector2.ONE
	var beat := 1.0
	if not Motion.reduce:
		var since := _clock - _flap_at
		if since < 0.16:
			var k := 1.0 - since / 0.16
			sc = Vector2(1.0 - 0.1 * k, 1.0 + 0.12 * k)
		beat = 0.3 + 0.7 * absf(sin(_clock * 46.0))
		if sim.phase == Sim.Phase.OVER:
			beat = 0.35
	var xf := Transform2D(_lean, sc, 0.0, at)
	# passing through things, she is pale
	var tint := Color(1, 1, 1, 0.6 + 0.3 * sin(_clock * 20.0)) if sim.ghost > 0.0 and sim.phase == Sim.Phase.PLAY else Color.WHITE
	field.draw_mesh(Art.wings(_u), null, xf * Transform2D(0.0, Vector2(1.0, beat), 0.0, Art.WING_AT * _u), tint)
	field.draw_mesh(Art.bee(look, _u), null, xf, tint)

## The dewdrop round her, the pollen behind her, the leaves off a hedge and
## the ring where a gap was passed: one mesh.
func _draw_live() -> void:
	var b := Face.Builder.new()
	var at := _bee_at()
	# her shadow on the lawn, smaller from higher up
	var high := clampf(1.0 - sim.y / Sim.H, 0.0, 1.0)
	b.ellipse(Vector2(at.x, Sim.H * _u + 5.0 * _u), (13.0 - 6.0 * high) * _u, (3.2 - 1.4 * high) * _u, Color(0.2, 0.3, 0.1, 0.22 - 0.1 * high))
	if sim.dew > 0 and sim.phase != Sim.Phase.OVER:
		var wob := 1.0 if Motion.reduce else 1.0 + 0.04 * sin(_clock * 5.0)
		Art.dew_into(b, at, Art.BEE * 1.5 * _u * wob)
	for bit: Dictionary in _bits:
		var k: float = bit.t / bit.life
		var p := px(bit.pos)
		var sd: float = bit.seed
		match String(bit.kind):
			"pollen":
				var q := p + Vector2(-18.0 * k, 10.0 * k * k + sin(sd) * 4.0) * _u
				b.disc(q, (1.6 - 0.8 * k) * _u, Color(bit.col, 0.9 * (1.0 - k)))
			"leaf":
				var dir := Vector2.from_angle(sd * 7.3) * (30.0 + 40.0 * fposmod(sd, 1.0))
				var q := p + (dir * k + Vector2(0, 90.0 * k * k)) * _u
				var pts := PackedVector2Array()
				for v: Vector2 in Face.Builder.ring(Vector2.ZERO, 3.6 * _u, 1.8 * _u):
					pts.append(q + v.rotated(sd + k * 9.0))
				b.fan(pts, Color(bit.col, 1.0 - k * k))
			"ring":
				var r := (8.0 + 22.0 * k) * _u
				b.stroke(Face.Builder.ring(p, r, r), maxf(1.5, 2.4 * _u * (1.0 - k)), Color(bit.col, 0.8 * (1.0 - k)), true)
			"burst":
				Art.dew_into(b, p, Art.BEE * (1.5 + 1.6 * k) * _u, 1.0 - k)
	_live = b.mesh()
	if _live != null:
		field.draw_mesh(_live, null)

## The score, lettered big at the top of the sky the way a sticker is: ink
## under cream, with a bump on every gap.
func _draw_score() -> void:
	if sim.phase == Sim.Phase.READY and sim.score == 0:
		return
	var font := CozyTheme.display(700)
	var fs := int(46.0 * _u)
	var text := str(sim.score)
	var since := _clock - _pass_at
	var sc := 1.0 if Motion.reduce or since > 0.3 else 1.0 + 0.22 * sin(since / 0.3 * PI) * (1.0 - since / 0.3)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mid := Vector2(field.size.x * 0.5, 58.0 * _u)
	field.draw_set_transform(mid + _shake_off, 0.0, Vector2(sc, sc))
	var o := Vector2(-w * 0.5, fs * 0.36)
	field.draw_string_outline(font, o + Vector2(0, 0.06 * fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(0.2 * fs), Color(Art.INK, 0.3))
	field.draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(0.2 * fs), Art.INK)
	field.draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fffaf0"))
	field.draw_set_transform(_shake_off)

# --- the rewards ---

## A point of the garden, in field units, in the rewards layer's pixels.
func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(field, px(p) + _shake_off)

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

## A ribbon won: its name lettered over a sunburst, stars home to the score,
## and a rain for the last.
func _on_ribbon(tier: int) -> void:
	_fx.cue("ribbon", 1.0 + 0.06 * (tier - 1))
	_feel(Haptics.GOOD)
	var at := _rw.at(field, field.size * Vector2(0.5, 0.36))
	var col: Color = Art.RIBBON[tier - 1]
	_rw.sticker(tr("BL_RIBBON_%d" % tier), at, 64 + 6 * tier, 1.5, tier >= 3, col.lightened(0.25), true, "ribbon")
	_rw.spray(at, col, 8 + 3 * tier, 720.0, "star", 1.0)
	_rw.spray(at, Color("fffaf0"), 6 + 2 * tier, 600.0, "spark", 1.1)
	_rw.spray(_in_rw(Vector2(sim.x, sim.y)), Pal.SUN, 3 + tier, 520.0, "star", 0.8, 0.15, _plate_at(_next_l))
	_rw.ring(at, 220.0, Color(col, 0.9))
	_next_l.pivot_offset = _next_l.size * 0.5
	Motion.bump(_next_l, 0.3, 0.4)
	if tier >= Sim.RIBBONS.size():
		_rw.rain(1.8, ["confetti", "star"], Rewards.CONFETTI)

## The score passing a round number past the last ribbon.
func _score_moments() -> void:
	var m := 0
	for v: int in MILESTONES:
		if sim.score >= v and v > _milestone:
			m = v
	if m > 0:
		_milestone = m
		_rw.sticker(Record.grouped(m) + "!", _rw.at(field, field.size * Vector2(0.5, 0.36)), 64, 1.2, true, Color.WHITE, false, "milestone")
		_rw.spray(_plate_at(_score_l), Pal.SUN, 10, 520.0, "star", 0.9)
		_rw.ring(_plate_at(_score_l), 140.0, Color(Pal.SUN, 0.9))
		_feel(Haptics.BUMP)

func _new_best_passed() -> void:
	_rw.sticker(tr("FF_NEW_BEST"), _rw.at(field, field.size * Vector2(0.5, 0.5)), 60, 1.6, true, Color.WHITE, false, "best")
	_rw.spray(_plate_at(_best_l), Pal.SUN, 14, 620.0, "star", 1.0)
	_rw.ring(_plate_at(_best_l), 160.0, Color(Pal.SUN, 0.9))
	_feel(Haptics.BUMP)

# --- the end ---

func _run_over() -> void:
	if _offer_chance():
		return
	var better := Record.add(GAME, sim.score, 0, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.ribbons,
		"seconds": secs, "flaps": sim.flaps, "best": better})
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
	_rw.bounds = Rect2()
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
	seat.custom_minimum_size = Vector2(0, 220)
	# The bee hovering over a sunburst, glad with a new best, the run's best
	# ribbon beside her.
	var u := 5.0
	var shown_at := _clock
	var tier: int = sim.ribbons
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 112.0)
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.4) / 0.35, 0.0, 1.0)
		if glow > 0.0:
			var rb := Face.Builder.new()
			var rr := 190.0 * Motion.back_out(glow)
			rb.disc(c, rr * 0.5, Color(Color("fff4c2"), 0.45))
			Rewards.sunrays(rb, c, rr * 0.2, rr, 14, t * 0.5, Color(Rewards.GOLD if better else Pal.SUN, 0.5))
			Rewards.sunrays(rb, c, rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
			if tier > 0:
				Art.ribbon_into(rb, tier, c + Vector2(150.0, 20.0), 44.0 * Motion.back_out(glow))
			var rm := rb.mesh()
			seat.set_meta("rays", rm)
			seat.draw_mesh(rm, null)
		var at := c + Vector2(0, sin(t * 3.0) * 8.0)
		var beat := 1.0 if Motion.reduce else 0.3 + 0.7 * absf(sin(t * 46.0))
		var xf := Transform2D(sin(t * 1.7) * 0.08 - 0.1, at)
		seat.draw_mesh(Art.wings(u), null, xf * Transform2D(0.0, Vector2(1.0, beat), 0.0, Art.WING_AT * u))
		seat.draw_mesh(Art.bee(Art.Look.GLAD if better or tier > 0 else Art.Look.FLY, u), null, xf))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "BL_END_CARD"
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
	var secs := int(sim.t)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 14)
	for pair in [[str(sim.flaps), "BL_STAT_FLAPS"], ["%d/%d" % [tier, Sim.RIBBONS.size()], "BL_STAT_RIBBONS"],
			["%d:%02d" % [secs / 60, secs % 60], "BL_STAT_TIME"]]:
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
## burst of stars when it gets there. A run is a handful of gaps, so the
## count is short.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 0.7, 0.0, 1.0)
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
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.ribbons})
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
## is, else straight in. A run still going when it is asked for stops there.
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
		sim = null
		_hint("", "")
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
		_fx.buzz(Haptics.GOOD)
		_fx.cue("dew")
		_play_events()
		top_bar.refresh(self))
	card.declined.connect(_run_over)
	add_child(card)
	return true
