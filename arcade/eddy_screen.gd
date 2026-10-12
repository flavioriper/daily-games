extends Control

## Eddy: the tenth game on the Arcade tab, a whirlpool steered about a pond
## (spec docs/superpowers/specs/2026-10-10-arcade-eddy-design.md). **The
## pond is the whole screen**, edge to edge, as the Factory's land is (the
## user, 2026-10-10: "the screen should fit everything, just like the
## factory does, it's gonna be a pattern from now on"): no page and no
## frame. Over it lie the flat boards' top bar (back, the title in ink,
## restart, settings), a paper row with the score, the bank of drops and the
## whirlpool's level, and at the foot the pad the thumb steers by.
##
## **A run is one of many** (the user, 2026-10-11: "a slow incremental where
## user buy upgrades to go further and further, not a one take game", spec
## docs/superpowers/specs/2026-10-11-eddy-incremental-design.md): what it
## scores is banked as drops (arcade/eddy_upgrades.gd), and the shop
## (arcade/eddy_shop.gd) is opened from the button under the opening lines
## and from the end card. A fresh run is fitted with what was bought. Eddy
## has no gold boosters any more.
##
## **A run ending is a turn done, not a loss** (the user, 2026-10-11: "when
## the time is up, instead of showing a you lose, it should show a message
## about the turn end and a summary of numbers, and show a button so user go
## do upgrade to spend points and go into next run"). The end card says the
## time is up and which run it was, counts the drops it made, sums it up
## (what went down, the level, the seconds, the bank, the best), and leads
## with Upgrades: the shop opened from there closes into the next run. No
## Second chance is offered here, and nothing sounds or knocks like a miss.
##
## **The pond is far bigger than the screen, and a camera looks at a part of
## it** (the user, 2026-10-10: "a fixed bigger water scene with all objects
## rendered, and camera start to zoom out as user get bigger and start to
## get bigger elements, something like .io games does. Camera moves as the
## player try to move outside camera on edges"). The pond is the sim's WIDE
## by TALL on every phone. What is looked at is the open water between the
## plates and the pad (`_window`): `Sim.view_of` units across it, wider as
## the core grows, and the whirlpool goes about its middle freely and takes
## the camera along only from EDGE of its side (`_follow`). The camera
## stops with the open water a mouth's width past the bank, so by a bank
## the plates and the pad lie over the grass beyond it.
##
## Play: the pad's knob is leaned and the whirlpool goes that way, faster
## the further it is leaned. What floats is drawn in by the water alone
## (arcade/eddy_sim.gd, stepped at its fixed DT); this screen draws it and
## plays its events.
##
## Drawing: one Control for the pond. The water and its bank are a still
## mesh built on resize; the whirlpool is its mouth and its streaks, turned
## and grown by the transform; everything afloat is one cached mesh under
## its own transform, and what is out of the field is not drawn at all.
## Nothing is rebuilt as the camera moves or widens: the pond and each thing
## are built once at POND_U and THING_U and scaled. The spin's bar and the rings a thing leaves going
## down are one live mesh over them. The pad is a second Control: its base,
## the growing's arc round it, and the knob.

signal closed

const Sim = preload("res://arcade/eddy_sim.gd")
const Art = preload("res://arcade/eddy_art.gd")
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
## What the phone knocks for (docs/agents/haptics.md). The events that share
## a frame (a leaf down and a level, two leaves) ask through `_feel` and the
## frame knocks once, with the strongest. Only the end card's cue is mapped.
const HAPTICS := {"new_best": Haptics.WIN}
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Upgrades = preload("res://arcade/eddy_upgrades.gd")
const Shop = preload("res://arcade/eddy_shop.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "eddy"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
## The strip the pad sits in, the pad's half-width in it, how far the knob
## travels from the middle, and the lean under which the knob is at rest.
const PAD_H := 250.0
const PAD_R := 108.0
const KNOB_R := 46.0
const TRAVEL := 70.0
const DEAD := 0.12
## The most sim steps one frame may run, so a stall never fast-forwards.
const MAX_STEPS := 12
## The whirlpool's meshes are built for a core this many pixels and scaled.
const CORE_PX := 48.0
## The pixels a pond unit the pond's mesh and a thing's are built at, the
## camera scaling them from there, and the grass drawn beyond the bank.
const POND_U := 3.0
const THING_U := 4.0
const TURF := 220.0
## The part of the open water, from each side, where the whirlpool takes
## the camera along with it.
const EDGE := 0.3
## The score lettered over the pond as it passes each of these.
const MILESTONES := [100, 200, 300, 500, 750, 1000, 1500, 2000, 3000, 5000, 7500, 10000]
## The locale key said when a level first takes a kind.
const OPENS := {Sim.Kind.DUCK: "ED_OPEN_DUCK", Sim.Kind.BOAT: "ED_OPEN_BOAT", Sim.Kind.BALL: "ED_OPEN_BALL",
	Sim.Kind.BUCKET: "ED_OPEN_BUCKET", Sim.Kind.CAN: "ED_OPEN_CAN", Sim.Kind.LILO: "ED_OPEN_LILO",
	Sim.Kind.RAFT: "ED_OPEN_RAFT", Sim.Kind.ROWBOAT: "ED_OPEN_ROWBOAT"}
## The cozy rules (docs/agents/sound.md): no cue climbs past five semitones,
## and a tick that repeats varies by TICK_VARY and climbs nothing.
const CLIMB_TOP := 1.335
const TICK_VARY := 0.06

var sim: RefCounted
## The gold the run earned, for the end card.
var _run_gold := 0
var top_bar: Control
var settings_sheet: Control
## The tutorial card: the top bar's ?, the settings' How to play and the
## first play (ui/hud/screen_tutor.gd).
var tutor: RefCounted
var field: Control
var pad: Control
var _fx: Node2D
var _margins: MarginContainer
var _score_l: Label
var _bank_l: Label
## The drops banked before this run; the plate shows them with the run's.
var _bank := 0
var _banked := false
## The Upgrades button under the opening lines, and the end card's bank.
var _shop_b: Button
var _end_bank: Label
var _level_l: Label
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
var _shown_level := -1
var _beat_best := false
## The knock this frame's events asked for, the strongest of them (-1: none).
var _knock := -1
## Pixels a pond unit, and where the pond's corner lies in the field: both
## the camera's (`_look`), which is the pond's point at the middle of the
## open water.
var _u := 2.0
var _o := Vector2.ZERO
var _cam := Vector2(Sim.WIDE, Sim.TALL) * 0.5
var _pond: ArrayMesh
var _pond_of := Vector2.ZERO
var _live: ArrayMesh
var _pad_live: ArrayMesh
## The screen's own clock, for motion the sim does not own; it stops with
## the pause.
var _clock := 0.0
## The pad: the knob's place from its middle in pixels, and the finger that
## holds it (-1 none, -2 the mouse).
var _knob := Vector2.ZERO
var _held := -1
## The whirlpool as drawn: its core eased to the sim's, and how far its
## mouth and its streaks have turned.
var _core := Sim.CORE
var _turn := 0.0
var _turn_far := 0.0
## Rings on the water, in pond units: {pos, t, life, r, col}.
var _bits: Array = []
## When the score last rose and when a level was last made, on `_clock`.
var _pass_at := -10.0
var _level_at := -10.0
var _low_at := -10.0
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
	tutor = ScreenTutor.new(self, puzzle_id(), "Eddy", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	# before any run: the boost card may stand first, and the bar would wear
	# the Undo and the bulb this game has not got until Play
	top_bar.refresh(self)
	_ask(false)
	# the two gold boosters Eddy had before its shop come back as gold
	var back := 0
	for id: String in Upgrades.OLD:
		back += Wallet.refund(id, Upgrades.OLD_PRICE)
	if back > 0:
		_rw.sticker(tr("ED_REFUND") % back, _rw.at(self, size * Vector2(0.5, 0.5)), 44, 3.0, false, Color("fff4c2"), false, "refund")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if sim != null and sim.phase == Sim.Phase.PLAY and _end == null:
			_pause(true)

# --- building ---

func _build() -> void:
	var water := _build_field()
	water.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(water)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Eddy", tr("ED_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void:
		_pause(true)
		settings_sheet.open())
	col.add_child(top_bar)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_build_hud())
	var open := Control.new()
	open.size_flags_vertical = Control.SIZE_EXPAND_FILL
	open.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(open)
	col.add_child(_build_pad())
	_rw = Rewards.new()
	add_child(_rw)
	_apply_insets()

## A wooden frame with the pond in it: the tutorial's small pond
## (ui/hud/eddy_tutorial_diagram.gd) is this, the pad and the plates. The
## screen itself has no frame.
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
	frame.add_child(_build_field())
	return frame

## The pond: the field, the two lines of lettering over it and the effects.
func _build_field() -> Control:
	field = Control.new()
	field.name = "Field"
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.draw.connect(_draw_field)
	field.resized.connect(_layout_field)
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
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_color_override("font_color", Color("fffaf0"))
	_banner.add_theme_color_override("font_shadow_color", Color(0.14, 0.26, 0.34, 0.6))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	_banner.add_theme_color_override("font_outline_color", Art.INK)
	_banner.add_theme_constant_override("outline_size", 12)
	over.add_child(_banner)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetTitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_color_override("font_color", Color("fffaf0"))
	_sub.add_theme_color_override("font_outline_color", Art.INK)
	_sub.add_theme_constant_override("outline_size", 8)
	over.add_child(_sub)
	# the shop, before a run: it keeps its own size under the two lines
	_shop_b = Dialog.secondary("trend", tr("ED_SHOP"))
	_shop_b.name = "Shop"
	_shop_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_shop_b.visible = false
	_shop_b.pressed.connect(_open_shop)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(gap)
	over.add_child(_shop_b)
	over.modulate.a = 0.0
	_banner.set_meta("box", over)
	return field

## The strip at the pond's foot with the pad in its middle, where either
## thumb reaches it and neither hides the water that is played on.
func _build_pad() -> Control:
	pad = Control.new()
	pad.name = "Pad"
	pad.custom_minimum_size.y = PAD_H
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	pad.draw.connect(_draw_pad)
	pad.gui_input.connect(_on_pad_input)
	return pad

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["FF_SCORE", "ED_BANK", "ED_LEVEL"]:
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
	_bank_l = made[1]
	_level_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_layout_field()

## The pond's two bands in the field's pixels: what the top bar and the
## plates cover, and what the pad's strip does. None on a tutorial page.
func _bands() -> Vector2:
	var insets := SafeArea.insets(self)
	return Vector2(MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + GAP, MARGIN + insets.y + PAD_H)

## The open water in the field's pixels: the field less its two bands.
func _window() -> Rect2:
	var bands := _bands()
	return Rect2(0.0, bands.x, field.size.x, maxf(1.0, field.size.y - bands.x - bands.y))

func _pond_size() -> Vector2:
	return Vector2(sim.w, sim.h) if sim != null else Vector2(Sim.WIDE, Sim.TALL)

## The room changing (the ad banner comes up a second after the screen) moves
## the camera's window and nothing on the water.
func _layout_field() -> void:
	if field.size.x <= 0.0 or field.size.y <= 0.0:
		return
	if _pond == null or _pond_of != _pond_size():
		_pond_of = _pond_size()
		_pond = Art.pond(_pond_of * POND_U, POND_U, _turf())
	_look()
	if _banner != null:
		_place_banner()
	field.queue_redraw()

func _place_banner() -> void:
	var box: Control = _banner.get_meta("box")
	box.size.x = field.size.x * 0.86
	box.reset_size()
	box.size.x = field.size.x * 0.86
	box.position = Vector2(field.size.x * 0.07, _bands().x + (field.size.y - _bands().x - _bands().y) * 0.14)
	box.pivot_offset = box.size * 0.5

## The grass drawn beyond the bank, in pond units: a tutorial page's pond is
## framed and has none.
func _turf() -> float:
	return TURF

## How many pond units the open water shows across: more as the whirlpool
## grows, on the core as drawn, so the look widens as smoothly as it swells.
func _across() -> float:
	return Sim.view_of(_core)

## The camera goes with the whirlpool only once it is within EDGE of a side
## of the open water, and stops at the bank: a pond narrower than what is
## looked at is held by its middle.
func _follow() -> void:
	var seen := _window().size / _u
	var pond := _pond_size()
	# past the bank by the mouth's own width, so a whirlpool against a bank is
	# still whole on the screen
	var past := Art.RIM + _core * 1.5
	for axis in 2:
		var slack: float = seen[axis] * (0.5 - EDGE)
		var lo: float = seen[axis] * 0.5 - past
		var hi: float = pond[axis] + past - seen[axis] * 0.5
		_cam[axis] = pond[axis] * 0.5 if lo > hi else clampf(clampf(_cam[axis], sim.pos[axis] - slack, sim.pos[axis] + slack), lo, hi)

## The camera for this frame: `_u` and `_o`.
func _look() -> void:
	if field.size.x <= 0.0 or field.size.y <= 0.0:
		return
	var win := _window()
	_u = win.size.x / _across()
	if sim != null:
		_follow()
	_o = win.get_center() - _cam * _u

## A point of the pond, in units, in the field's pixels.
func px(p: Vector2) -> Vector2:
	return _o + p * _u

# --- the game ---

func _fresh_sim() -> void:
	sim = Sim.new()
	Upgrades.fit(sim)
	_core = sim.core()
	_cam = sim.pos
	_shown_level = -1
	sim.events.clear()

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	_fresh_sim()
	_bank = Upgrades.drops()
	_banked = false
	_end_bank = null
	_run_gold = 0
	_acc = 0.0
	_paused = false
	_bits.clear()
	_knob = Vector2.ZERO
	_held = -1
	_pass_at = -10.0
	_level_at = -10.0
	_low_at = -10.0
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
	_layout_field()
	_refresh_hud()
	top_bar.refresh(self)
	_fx.cue("start")
	_hint(tr("ED_READY"), tr("ED_READY_LINE"))
	var ups := Upgrades.levels()
	Analytics.track("arcade_start", {"game": GAME, "spin": ups.spin, "pull": ups.pull, "mouth": ups.mouth, "reach": ups.reach, "speed": ups.speed})

## The tutorial card's pages (ui/hud/screen_tutor.gd), each a small pond
## played by this screen and the sim (ui/hud/eddy_tutorial_diagram.gd).
## Every number in the text is the sim's own.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/eddy_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.STEER, "TUT_EDDY_STEER", tr("TUT_EDDY_STEER_BODY")],
		[Diagram.Lesson.SWEEP, "TUT_EDDY_SWEEP", tr("TUT_EDDY_SWEEP_BODY")],
		[Diagram.Lesson.GROW, "TUT_EDDY_GROW", tr("TUT_EDDY_GROW_BODY") % [Sim.LEVELS, Sim.level_for(Sim.Kind.DUCK)]],
		[Diagram.Lesson.SPIN, "TUT_EDDY_SPIN", tr("TUT_EDDY_SPIN_BODY") % [int(Sim.SPIN), int(Sim.SPIN_BACK)]],
		[Diagram.Lesson.SHOP, "TUT_EDDY_SHOP", tr("TUT_EDDY_SHOP_BODY")],
		[Diagram.Lesson.HUD, "TUT_EDDY_HUD", tr("TUT_EDDY_HUD_BODY")],
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
			sim.steer(_lean())
			sim.step()
			_play_events()
		_animate(delta)
		_look()
	_refresh_hud()
	_knock_now()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()
	field.queue_redraw()
	pad.queue_redraw()

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
	_core = lerpf(_core, sim.core(), minf(1.0, delta * 5.0))
	# the mouth turns as the core's water does, the streaks as the water two
	# cores out: a quarter as fast
	var w: float = Sim.turn_of(sim.level) / sim.core() * sim.strength()
	if Motion.reduce:
		w *= 0.35
	_turn += w * delta
	_turn_far += w * 0.25 * delta
	if _held == -1:
		_knob = _knob.lerp(Vector2.ZERO, minf(1.0, delta * 18.0))
	_rw.bounds = Rect2(_rw.at(field, Vector2.ZERO), field.size)
	_rw.step(delta)

# --- the pad ---

## The pad's lean as the sim takes it: nothing under DEAD, then all the way
## to 1 at the knob's full travel.
func _lean() -> Vector2:
	var k := _knob.length() / TRAVEL
	if k < DEAD or _paused:
		return Vector2.ZERO
	return _knob.normalized() * clampf((k - DEAD) / (1.0 - DEAD), 0.0, 1.0)

func _pad_mid() -> Vector2:
	return pad.size * 0.5

func _on_pad_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _held == -1:
			_grab(touch.index, touch.position)
		elif not touch.pressed and touch.index == _held:
			_held = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _held:
			_knob = (drag.position - _pad_mid()).limit_length(TRAVEL)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click := event as InputEventMouseButton
		if click.pressed and _held == -1:
			_grab(-2, click.position)
		elif not click.pressed and _held == -2:
			_held = -1
	elif event is InputEventMouseMotion and _held == -2:
		_knob = ((event as InputEventMouseMotion).position - _pad_mid()).limit_length(TRAVEL)

## A finger down on the pad: the knob goes under it, and a paused run goes on.
func _grab(index: int, at: Vector2) -> void:
	if sim == null or sim.phase == Sim.Phase.DRAIN or sim.phase == Sim.Phase.OVER:
		return
	if _paused:
		if _end != null or settings_sheet.is_open():
			return
		_pause(false)
	_held = index
	_knob = (at - _pad_mid()).limit_length(TRAVEL)
	_fx.touch(randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
	_fx.buzz(Haptics.TAP)

## The tutorial card stops the run and leaves it paused, a touch from going on.
func _tutor_hold(on: bool) -> void:
	if on and sim != null and sim.phase == Sim.Phase.PLAY and _end == null:
		_pause(true)

func _pause(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	if on:
		_held = -1
		_knob = Vector2.ZERO
		_pause_card = _build_pause()
		field.add_child(_pause_card)
		Motion.appear(_pause_card, 0.0, 1.0, 0.2)
	elif _pause_card != null:
		_pause_card.queue_free()
		_pause_card = null

func _build_pause() -> Control:
	var scrim := ColorRect.new()
	scrim.color = Color(0.08, 0.16, 0.22, 0.5)
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
	line.text = "ED_RESUME"
	line.theme_type_variation = "SheetTitle"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_color_override("font_color", Color("fffaf0"))
	col.add_child(line)
	return scrim

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		match String(ev.type):
			"go":
				_hint("", "")
			"catch":
				_ring(ev.at, float(Sim.KINDS[ev.kind].r) * 1.6, 0.4, Art.FOAM)
			"swallow":
				_on_swallow(ev)
			"level":
				_on_level(int(ev.n), ev.opens)
			"too_big":
				_rw.sticker(tr("ED_TOO_BIG") % int(ev.level), _in_rw(ev.at + Vector2(0, -22.0)), 40, 1.4, false, Color("fffaf0"), false, "too_big", 20.0)
			"low":
				_low_at = _clock
				_fx.cue("low")
				_feel(Haptics.BUMP)
				_rw.sticker(tr("ED_LOW"), _rw.at(field, field.size * Vector2(0.5, 0.24)), 50, 1.4, false, Art.SPIN_LOW.lightened(0.3), false, "low")
			"drain":
				_fx.cue("drain")
				_feel(Haptics.BUMP)
				_held = -1
				_ring(sim.pos, sim.reach(), 1.2, Art.FOAM)
			"over":
				_run_over()
	sim.events.clear()

## A thing gone down: a small one is a tick and a ring, a toy a deeper knock
## with its points lettered where it went.
func _on_swallow(ev: Dictionary) -> void:
	_pass_at = _clock
	var at: Vector2 = ev.at
	if int(ev.tier) >= 2:
		_fx.cue("gulp", randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
		_feel(Haptics.BUMP)
		_ring(at, _core * 2.4, 0.7, Art.FOAM)
		_ring(at, _core * 1.6, 0.5, Art.FOAM)
		_rw.sticker("+%d" % int(ev.value), _in_rw(at + Vector2(0, -_core - 10.0)), 56, 1.0, false, Color("fff4c2"), false, "", 40.0)
		_rw.spray(_in_rw(at), Art.FOAM, 8, 420.0, "spark", 0.9)
		_rw.spray(_in_rw(at), Pal.SUN, 4, 520.0, "star", 0.8, 0.1, _plate_at(_score_l))
	else:
		_fx.cue("plop", randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
		_feel(Haptics.TICK)
		_ring(at, _core * 1.5, 0.45, Art.FOAM)

## A level made: the whirlpool swells, its number is lettered over the pond,
## and what its mouth now takes is said under it.
func _on_level(n: int, opens: Array) -> void:
	_level_at = _clock
	# what was too big a moment ago may not be any more
	_rw.stickers = _rw.stickers.filter(func(st: Dictionary) -> bool: return String(st.id) != "too_big")
	_fx.cue("level", minf(1.0 + 0.03 * (n - 2), CLIMB_TOP))
	_feel(Haptics.GOOD)
	var at := _rw.at(field, field.size * Vector2(0.5, 0.3))
	_rw.sticker(tr("ED_LEVEL_UP") % n, at, 66, 1.4, n >= Sim.LEVELS, Art.WATER_HI, true, "level")
	for kind: int in opens:
		_rw.sticker(tr(OPENS[kind]), at + Vector2(0, 86.0), 44, 1.8, false, Color("fff4c2"), false, "opens")
	_rw.spray(_in_rw(sim.pos), Art.FOAM, 10, 620.0, "spark", 1.0)
	_rw.spray(_in_rw(sim.pos), Pal.SUN, 3 + n / 2, 520.0, "star", 0.8, 0.15, _plate_at(_level_l))
	_ring(sim.pos, sim.reach(), 0.8, Art.FOAM)
	_ring(sim.pos, sim.reach() * 0.6, 0.6, Art.FOAM)
	if n >= Sim.LEVELS:
		_rw.rain(1.8, ["confetti", "star"], Rewards.CONFETTI)

func _ring(at: Vector2, r: float, life: float, col: Color) -> void:
	if Motion.reduce:
		return
	_bits.append({"pos": at, "t": 0.0, "life": life, "r": r, "col": col})

## The two lines over the pond before the pad is touched: up while there is
## something to say, gone on the first lean.
func _hint(text: String, sub: String) -> void:
	var box: Control = _banner.get_meta("box")
	Motion.stop(_banner_tw)
	# the shop is offered only before a run has begun
	_shop_b.visible = text != "" and sim != null and sim.phase == Sim.Phase.READY and sim.t <= 0.0
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

## A plate's number pops from its own size, whatever the last pop was doing:
## `Motion.bump` comes home to the scale it found, and a sweep scores again
## before the last pop is home, so each began bigger than the one before (the
## user, 2026-10-12, of a 74 three plates tall: "number is huge").
static func pop(l: Label, amount: float, time: float) -> void:
	if l.has_meta("pop"):
		Motion.stop(l.get_meta("pop"))
	l.scale = Vector2.ONE
	l.pivot_offset = l.size * 0.5
	l.set_meta("pop", Motion.bump(l, amount, time))

## The bank as the plate letters it: with the run's score while it is being
## made, and alone once the run has been banked.
func _bank_text() -> String:
	return Record.grouped(_bank + (0 if _banked else sim.score))

func _refresh_hud() -> void:
	if sim == null:
		return
	if sim.level != _shown_level:
		if _shown_level >= 0 and sim.level > _shown_level:
			pop(_level_l, 0.3, 0.4)
		_shown_level = sim.level
		_level_l.text = "%d/%d" % [sim.level, Sim.LEVELS]
	if sim.score == _shown_score:
		return
	if sim.score > _shown_score and _shown_score >= 0:
		pop(_score_l, 0.14, 0.26)
	_shown_score = sim.score
	_score_l.text = Record.grouped(sim.score)
	_bank_l.text = _bank_text()
	if not _beat_best and _best > 0 and sim.score > _best:
		_beat_best = true
		_new_best_passed()
	_score_moments()

# --- drawing ---

func _draw_field() -> void:
	if _pond == null:
		_layout_field()
	if _pond == null:
		return
	field.draw_rect(Rect2(Vector2.ZERO, field.size), Art.BANK)
	field.draw_mesh(_pond, null, Transform2D(0.0, Vector2.ONE * (_u / POND_U), 0.0, _o))
	if sim == null:
		return
	var grow := _u / THING_U
	var seen := Rect2(Vector2.ZERO, field.size)
	# the whirlpool lies under everything afloat: a thing drawn in is seen on
	# its mouth all the way, never under it until it is caught (the user,
	# 2026-10-10: "it show under the whirlpool for a second")
	var live: float = sim.strength()
	if live > 0.0:
		var at := px(sim.pos)
		var swell := 1.0
		if not Motion.reduce and _clock - _level_at < 0.5:
			swell += 0.16 * sin((_clock - _level_at) / 0.5 * PI)
		var sc := _core * _u / CORE_PX * swell * (0.5 + 0.5 * live)
		field.draw_mesh(Art.streaks(CORE_PX), null, Transform2D(_turn_far, Vector2(sc, sc), 0.0, at), Color(1, 1, 1, live))
		field.draw_mesh(Art.funnel(CORE_PX), null, Transform2D(_turn, Vector2(sc, sc), 0.0, at), Color(1, 1, 1, live))
	# what floats, the small things under the toys, and over them what is
	# going down
	var sinking: Array = []
	for tier: int in range(1, Sim.TIERS + 1):
		for th: Dictionary in sim.things:
			if int(Sim.KINDS[th.kind].tier) != tier:
				continue
			if not seen.grow(float(Sim.KINDS[th.kind].r) * 1.6 * _u).has_point(px(th.pos)):
				continue
			if float(th.sink) >= 0.0:
				sinking.append(th)
				continue
			var sc := 1.0
			if tier >= 2 and not Motion.reduce:
				sc += 0.03 * sin(_clock * 2.2 + float(th.id))
			var a := clampf(float(th.age) / 0.5, 0.0, 1.0)
			field.draw_mesh(Art.thing(th.kind, th.look, THING_U), null, Transform2D(float(th.ang), Vector2(sc, sc) * grow, 0.0, px(th.pos)), Color(1, 1, 1, a))
	for th: Dictionary in sinking:
		var k := clampf(float(th.sink) / float(Sim.KINDS[th.kind].sink), 0.0, 1.0)
		var sc := 1.0 - 0.8 * k * k
		var tint := Color.WHITE.lerp(Art.WATER_DARK, 0.7 * k)
		tint.a = 1.0 - k * k * k
		field.draw_mesh(Art.thing(th.kind, th.look, THING_U), null, Transform2D(float(th.ang), Vector2(sc, sc) * grow, 0.0, px(th.pos)), tint)
	_draw_live()

## The rings on the water and the spin's bar across the pond's top: one mesh.
func _draw_live() -> void:
	var b := Face.Builder.new()
	for bit: Dictionary in _bits:
		var k: float = bit.t / bit.life
		var r: float = float(bit.r) * _u * (0.3 + 0.7 * k)
		b.stroke(Face.Builder.ring(px(bit.pos), r, r), maxf(1.5, 1.4 * _u * (1.0 - k)), Color(bit.col, 0.7 * (1.0 - k)), true)
	bar_into(b)
	_live = b.mesh()
	if _live != null:
		field.draw_mesh(_live, null)

## The spin left: a cream bar across the top of the pond, blue while there
## is plenty and amber when it runs low, with a beat as a level gives some
## back.
func bar_into(b: Face.Builder) -> void:
	var s := field.size
	var w := minf(s.x * 0.62, 420.0)
	var tall := clampf(s.y * 0.028, 12.0, 22.0)
	var under := _bands().x
	var at := Vector2((s.x - w) * 0.5, (under + tall * 0.5) if under > 0.0 else (maxf(_o.y, 0.0) + Art.RIM * _u + tall * 0.9))
	var part: float = clampf(sim.spin / sim.spin_full, 0.0, 1.0)
	var low: bool = part <= Sim.LOW
	if not Motion.reduce and _clock - _level_at < 0.3:
		var beat := 1.0 + 0.25 * sin((_clock - _level_at) / 0.3 * PI)
		at.y -= tall * (beat - 1.0) * 0.5
		tall *= beat
	b.fan(Face.Builder.round_rect(at + Vector2(-4.0, -4.0), Vector2(w + 8.0, tall + 8.0), tall * 0.5 + 4.0), Color(Art.INK, 0.35))
	b.fan(Face.Builder.round_rect(at, Vector2(w, tall), tall * 0.5), Art.BAR_BACK)
	if part > 0.0:
		var col := Art.SPIN_LOW if low else Art.SPIN
		if low and not Motion.reduce:
			col = col.lerp(Art.BAR_BACK, 0.3 + 0.3 * sin(_clock * 9.0))
		b.fan(Face.Builder.round_rect(at, Vector2(maxf(tall, w * part), tall), tall * 0.5), col)
		b.fan(Face.Builder.round_rect(at + Vector2(tall * 0.4, tall * 0.18), Vector2(maxf(tall * 0.2, w * part - tall * 0.8), tall * 0.22), tall * 0.11), Color(1, 1, 1, 0.4))

## The pad: its base, the growing's arc round it and the knob.
func _draw_pad() -> void:
	var mid := _pad_mid()
	var r := minf(PAD_R, pad.size.y * 0.5 - 12.0)
	if r <= 8.0:
		return
	var k := r / PAD_R
	var b := Face.Builder.new()
	# the growing toward the next level, a ring round the pad
	var ring_r := r + 9.0
	b.stroke(Face.Builder.ring(mid, ring_r, ring_r), 7.0, Color(Art.INK, 0.14), true)
	if sim != null:
		var part: float = 1.0 if sim.level >= Sim.LEVELS else float(sim.grown) / float(sim.need())
		if part > 0.0:
			b.stroke(Face.Builder.arc_points(mid, ring_r, -PI * 0.5, -PI * 0.5 + TAU * minf(part, 1.0)), 7.0, Art.SPIN if sim.level < Sim.LEVELS else Pal.SUN)
	_pad_live = b.mesh()
	if _pad_live != null:
		pad.draw_mesh(_pad_live, null)
	pad.draw_mesh(Art.pad_base(r), null, Transform2D(0.0, mid))
	var press := 0.94 if _held != -1 else 1.0
	var turn := 0.0 if sim == null else _turn
	pad.draw_mesh(Art.pad_knob(KNOB_R * k), null, Transform2D(turn, Vector2(press, press), 0.0, mid + _knob * k),
		Color(0.9, 0.9, 0.9) if _held != -1 else Color.WHITE)

# --- the rewards ---

## A point of the pond, in units, in the rewards layer's pixels.
func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(field, px(p))

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

## The score passing a round number.
func _score_moments() -> void:
	var m := 0
	for v: int in MILESTONES:
		if sim.score >= v and v > _milestone:
			m = v
	if m > 0:
		_milestone = m
		_rw.sticker(Record.grouped(m) + "!", _rw.at(field, field.size * Vector2(0.5, 0.5)), 64, 1.2, true, Color.WHITE, false, "milestone")
		_rw.spray(_plate_at(_score_l), Pal.SUN, 10, 520.0, "star", 0.9)
		_rw.ring(_plate_at(_score_l), 140.0, Color(Pal.SUN, 0.9))
		_feel(Haptics.BUMP)

func _new_best_passed() -> void:
	_rw.sticker(tr("FF_NEW_BEST"), _rw.at(field, field.size * Vector2(0.5, 0.62)), 60, 1.6, true, Color.WHITE, false, "best")
	_rw.spray(_plate_at(_score_l), Pal.SUN, 14, 620.0, "star", 1.0)
	_rw.ring(_plate_at(_score_l), 160.0, Color(Pal.SUN, 0.9))
	_feel(Haptics.BUMP)

# --- the end ---

func _run_over() -> void:
	# the furthest a whirlpool has grown is the stage the tab's card reads
	var better := Record.add(GAME, sim.score, sim.level, false)
	# the run's score is its drops: banked once, here
	_bank = Upgrades.bank(sim.score)
	_banked = true
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.level,
		"seconds": secs, "small": sim.taken[1], "big": sim.taken[2], "great": sim.taken[3], "huge": sim.taken[4],
		"bank": _bank, "best": better})
	Ads.note_finished()
	top_bar.refresh(self)
	get_tree().create_timer(0.7).timeout.connect(_show_end.bind(better))

func _show_end(better: bool) -> void:
	if sim == null or not sim.is_over() or _end != null:
		return
	# a turn done: the level's two notes up, never the falling three
	_fx.cue("new_best" if better else "level")
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
	# A small whirlpool turning over a sunburst, with the duck going round it
	# and a leaf after her.
	var shown_at := _clock
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 112.0)
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.4) / 0.35, 0.0, 1.0)
		var rb := Face.Builder.new()
		if glow > 0.0:
			var rr := 190.0 * Motion.back_out(glow)
			rb.disc(c, rr * 0.5, Color(Color("fff4c2"), 0.45))
			Rewards.sunrays(rb, c, rr * 0.2, rr, 14, t * 0.5, Color(Rewards.GOLD if better else Pal.SUN, 0.5))
			Rewards.sunrays(rb, c, rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
		rb.disc(c, 96.0, Art.WATER)
		rb.disc(c, 88.0, Art.WATER_HI)
		var rm := rb.mesh()
		seat.set_meta("rays", rm)
		seat.draw_mesh(rm, null)
		seat.draw_mesh(Art.funnel(30.0), null, Transform2D(t * 3.0, c))
		var a := t * 1.4
		seat.draw_mesh(Art.thing(Sim.Kind.LEAF, 1, 4.6), null, Transform2D(a * 1.7, c + Vector2.from_angle(a + 2.6) * 62.0))
		seat.draw_mesh(Art.thing(Sim.Kind.DUCK, 0, 3.4), null, Transform2D(a + PI * 0.5, c + Vector2.from_angle(a) * 60.0)))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "ED_END_CARD"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# the longer languages take two lines rather than widen the card
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 740
	col.add_child(head)
	var line := Label.new()
	line.name = "Line"
	line.text = tr("ED_END_LINE") % Record.plays(GAME)
	line.theme_type_variation = "SheetBody"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 740
	col.add_child(line)
	# what the run made, counted up beside a drop
	var made := HBoxContainer.new()
	made.alignment = BoxContainer.ALIGNMENT_CENTER
	made.add_theme_constant_override("separation", 12)
	made.add_child(Shop.drop_icon(72.0))
	var score := Label.new()
	score.text = "+" + (Record.grouped(sim.score) if Motion.reduce else "0")
	if not Motion.reduce:
		_end_score = score
	score.theme_type_variation = "DayBig"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.add_child(score)
	col.add_child(made)
	var secs := int(sim.t)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 14)
	var down := 0
	for n: int in sim.taken:
		down += n
	for pair in [[str(down), "ED_STAT_TAKEN"], ["%d/%d" % [sim.level, Sim.LEVELS], "ED_STAT_LEVEL"],
			["%d:%02d" % [secs / 60, secs % 60], "ED_STAT_TIME"]]:
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
	# the bank the run went into, to be spent
	var banked := HBoxContainer.new()
	banked.alignment = BoxContainer.ALIGNMENT_CENTER
	banked.add_theme_constant_override("separation", 14)
	var plus := Label.new()
	plus.text = "ED_TO_SPEND"
	plus.theme_type_variation = "SheetBody"
	banked.add_child(plus)
	var pill := Shop.drops_pill(40.0)
	_end_bank = pill.get_node("Row/Count")
	_end_bank.text = Record.grouped(_bank)
	banked.add_child(pill)
	col.add_child(banked)
	var best_line := Label.new()
	best_line.text = tr("FF_NEW_BEST") if better else tr("FF_BEST_LINE") % Record.grouped(Record.best(GAME))
	best_line.theme_type_variation = "SheetBodyDim"
	best_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(best_line)
	# the shop leads, always: a run is played to be spent, and the shop
	# closes into the next one
	var shop := Dialog.primary("trend", tr("ED_SHOP"))
	shop.name = "Shop"
	shop.pressed.connect(_open_shop)
	var again := Dialog.secondary("chevron_right", tr("ED_NEXT"))
	again.name = "Again"
	again.pressed.connect(_ask)
	var stack := Dialog.buttons(col, shop, again, GoldDoubler.new(_run_gold) if _run_gold > 0 else null)
	var back := Dialog.secondary("chevron_left", tr("FF_BACK"))
	back.size_flags_horizontal = Control.SIZE_FILL
	back.pressed.connect(_on_back)
	stack.add_child(back)
	return scrim

## The end card's score runs up from nothing to what the run made, with a
## burst of stars when it gets there.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 0.9, 0.0, 1.0)
	var shown := int(round(sim.score * (1.0 - pow(1.0 - k, 3.0))))
	var text := "+" + Record.grouped(shown)
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
	var shop := get_node_or_null("Shop")
	if shop != null and not shop.is_queued_for_deletion():
		shop.closed.emit()
		shop.queue_free()
		return
	_on_back()

# --- the shop ---

## A fresh run, fitted with what the shop has sold. A run still going when
## it is asked for stops there.
func _ask(by_hand := true) -> void:
	if get_node_or_null("Shop") != null:
		return
	_new_game()
	# Restart and Play again tap; the screen opening says nothing.
	if by_hand:
		_fx.buzz(Haptics.TAP)

## The shop over the pond: before a run, or from the end card. What is
## bought before a run fits the run that is waiting; from the end card its
## button is Next run, and closing it lays that run.
func _open_shop() -> void:
	if get_node_or_null("Shop") != null or sim == null:
		return
	if not sim.is_over() and (sim.phase != Sim.Phase.READY or sim.t > 0.0):
		return
	_fx.touch()
	_fx.buzz(Haptics.TAP)
	var shop := Shop.new()
	shop.name = "Shop"
	shop.next = sim.is_over()
	var spent := [0]
	shop.bought.connect(func(id: String, lv: int, paid: int) -> void:
		spent[0] += paid
		_fx.cue("level", minf(1.0 + 0.03 * (lv - 1), CLIMB_TOP))
		_fx.buzz(Haptics.GOOD)
		Analytics.track("eddy_upgrade", {"tile": id, "level": lv, "drops": paid}))
	shop.closed.connect(func() -> void:
		_fx.touch()
		_fx.buzz(Haptics.TAP)
		_bank = Upgrades.drops()
		_bank_l.text = _bank_text()
		if _end_bank != null and is_instance_valid(_end_bank):
			_end_bank.text = Record.grouped(_bank)
		# not through _ask: the shop is still in the tree as it says closed
		if spent[0] > 0 or sim.is_over():
			_new_game())
	add_child(shop)
