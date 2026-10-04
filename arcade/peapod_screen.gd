extends Control

## Peapod: the sixth game on the Arcade tab, a pea cannon against crates
## that come down with a number on each (spec
## docs/superpowers/specs/2026-10-04-arcade-peapod-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the score, the best and the wave, and under them the garden in the
## Arcade's wooden frame: the sky the crates come down, the cart on the
## grass at its foot.
##
## Play: slide anywhere to roll the cart; it never stops firing. The game is
## arcade/peapod_sim.gd, stepped at its fixed DT; this screen draws it and
## plays its events.
##
## Drawing: the garden (sky, hills, grass) is one still mesh, built on
## resize. Everything that moves is drawn by one Control over it: a cached
## mesh a crate, a plate, a token and a part of the cart, moved by the
## transform, their numbers lettered over them, and two live meshes for the
## peas, the sparks and the line.

signal closed

const Sim = preload("res://arcade/peapod_sim.gd")
const Art = preload("res://arcade/peapod_art.gd")
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
## What the phone knocks for (docs/agents/haptics.md). The gun never stops
## and a volley's peas land several to a frame, so only the end card's cue is
## mapped: the events ask through `_feel` and the frame knocks once, with the
## strongest. The shots and the peas landing play through `_quiet`, which
## knocks for nothing.
const HAPTICS := {"new_best": Haptics.WIN}
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "peapod"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
## The most sim steps one frame may run, so a stall never fast-forwards.
const MAX_STEPS := 4
## The finger's slide, times this, is the cart's.
const GAIN := 1.35
## Where the grass begins, in field units: under the cart's wheels.
const TURF := Sim.CART_Y + 9.0
const RECOIL := 0.09
const SKY_TOP := Color("8fd0f0")
const SKY_LOW := Color("e2f5fb")
const PEAK := Color("8fb4e6")
const PEAK_FAR := Color("a9c6ee")
const HILL := Color("a5d68a")
const HILL_NEAR := Color("8fc873")
const GRASS := Color("84c957")
const GRASS_DEEP := Color("63ad42")
const ALARM := Color("ff6f61")
const HEAT := Color("ffb03b")
## A streak's word, by its length, loudest first.
const WORDS := [[75, "PP_WORD_5"], [50, "PP_WORD_4"], [35, "PP_WORD_3"], [20, "PP_WORD_2"], [10, "PP_WORD_1"]]
const GOT := {Sim.Kind.PEA: "PP_GOT_PEA", Sim.Kind.RATE: "PP_GOT_RATE", Sim.Kind.POWER: "PP_GOT_POWER", Sim.Kind.TWIN: "PP_GOT_TWIN",
	Sim.Kind.FAN: "PP_GOT_FAN", Sim.Kind.PIERCE: "PP_GOT_PIERCE", Sim.Kind.BURST: "PP_GOT_BURST", Sim.Kind.MAGNET: "PP_GOT_MAGNET",
	Sim.Kind.FROST: "PP_GOT_FROST", Sim.Kind.SHOVE: "PP_GOT_SHOVE"}
## What a rotten gift took, by the gift it undid (-1: nothing left to take).
const ROT := {Sim.Kind.PEA: "PP_ROT_PEA", Sim.Kind.RATE: "PP_ROT_RATE", Sim.Kind.POWER: "PP_ROT_POWER", -1: "PP_ROT_NONE"}
## The sound a gift is caught with, where it has one of its own.
const CATCH_CUE := {Sim.Kind.TWIN: "twin", Sim.Kind.FAN: "pod", Sim.Kind.PIERCE: "pod", Sim.Kind.BURST: "pod", Sim.Kind.FROST: "frost",
	Sim.Kind.SHOVE: "shove"}
const MAX_POPS := 12
const MAX_SPARKS := 40

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
## The gun's own voice: the shots and the peas landing, which nothing knocks
## for.
var _quiet: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _score_l: Label
var _best_l: Label
var _wave_l: Label
var _banner: Label
var _sub: Label
var _banner_tw: Tween
var _pause_card: Control
var _end: Control
var _over: Control
var _acc := 0.0
var _paused := false
var _started_at := 0
var _best := 0
var _shown_score := -1
var _roll := 0.0
var _beat_best := false
## The knock this frame's events asked for, the strongest of them (-1: none).
var _knock := -1
## Pixels a field unit, and where the field's origin lands in `field`.
var _u := 2.4
var _origin := Vector2.ZERO
var _scene: ArrayMesh
var _live_top: ArrayMesh
## Built with the garden and only moved or tinted after: the chalk line's
## dashes and the plates under the gun's three numbers.
var _dashes: ArrayMesh
var _chips: ArrayMesh
## Every pea in the air is one draw a look, every spark one more (checkup,
## 2026-10-04: a pea laid into a mesh in script each frame was most of a
## frame once the gun was full and a millipede let the peas fly far).
var _pea_mm: Array = []
var _pea_buf: Array = []
var _spark_mm: MultiMesh
## The crates and the plates the same way, one draw a look of them: a wall
## of forty-five was forty-five draws, and the phone pays by the draw.
## ArrayMesh -> [MultiMesh, its buffer, how many this frame].
var _cast: Dictionary = {}
var _spark_buf := PackedFloat32Array()
## The screen's own clock, for motion the sim does not own; it stops with
## the pause.
var _clock := 0.0
## The finger sliding the cart: the touch, where it came down and where the
## cart was then.
var _touch := -1
var _mouse := false
var _touch_from := Vector2.ZERO
var _cart_from := 0.0
## When each crate or plate last took a pea, by its id, for the flash.
var _hit_at := {}
## Sparks where a pea lands: {pos, t, col}.
var _sparks: Array = []
## Numbers rising off a crate gone: {pos, text, t, col, big}.
var _pops: Array = []
var _shot_at := -10.0
var _wheel := 0.0
var _last_x := 0.0
var _lean := 0.0
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _seat: Control
## The loud rewards over the whole screen (arcade/rewards.gd).
var _rw: Rewards
## The warm glow a long streak lights round the garden (0..1), and the red
## one as the line is neared.
var _heat := 0.0
var _alarm := 0.0
var _flash := 0.0
var _flash_col := Color.WHITE
## The millipede head's number and where it goes, lettered after the peas.
var _head_tag: Array = []
var _end_score: Label
var _end_at := 0.0

func puzzle_id() -> String:
	return GAME

## The tutorial's pages, each a slice of this garden played by a finger
## (ui/hud/peapod_tutorial_diagram.gd): the slide, the numbers and the line,
## the gifts, the pods, the special crates, the millipede, and the boosters
## and the top bar.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/peapod_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.SLIDE, "TUT_PEAPOD_SLIDE", tr("TUT_PEAPOD_SLIDE_BODY")],
		[Diagram.Lesson.CRATES, "TUT_PEAPOD_CRATES", tr("TUT_PEAPOD_CRATES_BODY")],
		[Diagram.Lesson.GIFTS, "TUT_PEAPOD_GIFTS", tr("TUT_PEAPOD_GIFTS_BODY")],
		[Diagram.Lesson.PODS, "TUT_PEAPOD_PODS", tr("TUT_PEAPOD_PODS_BODY") % int(Sim.POD_TIME)],
		[Diagram.Lesson.SPECIAL, "TUT_PEAPOD_SPECIAL", tr("TUT_PEAPOD_SPECIAL_BODY")],
		[Diagram.Lesson.MILLI, "TUT_PEAPOD_MILLI", tr("TUT_PEAPOD_MILLI_BODY")],
		[Diagram.Lesson.HUD, "TUT_PEAPOD_HUD", tr("TUT_PEAPOD_HUD_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Peapod", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	# before the boost card, so the bar behind it is already this game's
	top_bar.refresh(self)
	_ask(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if sim != null and not sim.is_over() and _end == null:
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

	top_bar = FlatTopBar.new("Peapod", tr("PEAPOD_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void:
		_pause(true)
		settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())

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
	col.add_child(frame)
	field = Control.new()
	field.name = "Field"
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.resized.connect(_layout_field)
	field.gui_input.connect(_on_field_input)
	frame.add_child(field)
	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	field.add_child(_over)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	field.add_child(_fx)
	_quiet = Fx2D.new()
	_quiet.buzzes = false
	field.add_child(_quiet)

	var over := VBoxContainer.new()
	over.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	over.alignment = BoxContainer.ALIGNMENT_CENTER
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.grow_horizontal = Control.GROW_DIRECTION_BOTH
	over.grow_vertical = Control.GROW_DIRECTION_BOTH
	field.add_child(over)
	_banner = Label.new()
	_banner.theme_type_variation = "WellDone"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", Color("fffaf0"))
	_banner.add_theme_color_override("font_shadow_color", Color(0.2, 0.14, 0.06, 0.55))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	over.add_child(_banner)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetTitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Color("fffaf0"))
	_sub.add_theme_color_override("font_shadow_color", Color(0.2, 0.14, 0.06, 0.5))
	_sub.add_theme_constant_override("shadow_offset_y", 3)
	over.add_child(_sub)
	over.modulate.a = 0.0
	_banner.set_meta("box", over)
	_rw = Rewards.new()
	add_child(_rw)
	_apply_insets()

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["FF_SCORE", "FF_BEST", "PP_WAVE"]:
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
	_wave_l = made[2]
	_wave_l.text = "1"
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The garden is scaled to the room and stood on its bottom edge: a phone is
## taller than the field, and the extra is sky the crates come down through.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_fit(s)
	_scene = _build_scene()
	_cast.clear()
	_dashes = _build_dashes()
	_chips = _build_chips()
	var box: Control = _banner.get_meta("box")
	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2(0, s.y * 0.36)
	box.size.x = s.x
	_redraw_all()

## The field's unit and origin in a room `s` (a tutorial page stands a slice
## of the garden in its own: ui/hud/peapod_tutorial_diagram.gd).
func _fit(s: Vector2) -> void:
	_u = minf(s.x / Sim.W, s.y / Sim.H)
	_origin = Vector2((s.x - Sim.W * _u) * 0.5, s.y - Sim.H * _u)

func px(p: Vector2) -> Vector2:
	return _origin + p * _u

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
	_touch = -1
	_mouse = false
	_hit_at.clear()
	_sparks.clear()
	_pops.clear()
	_shot_at = -10.0
	_last_x = sim.x
	_lean = 0.0
	_shake = 0.0
	_roll = 0.0
	_beat_best = false
	_heat = 0.0
	_alarm = 0.0
	_flash = 0.0
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
	Analytics.track("arcade_start", {"game": GAME, "boosts": ",".join(_boosts)})

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
		_keys()
		_acc += minf(delta, Sim.DT * MAX_STEPS)
		while _acc >= Sim.DT:
			_acc -= Sim.DT
			sim.step()
			_play_events()
		_animate(delta)
	_refresh_hud(delta)
	_knock_now()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()
	_redraw_all()

## Asks for a knock this frame; the strongest asked for is the one played.
func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _knock_now() -> void:
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1

func _redraw_all() -> void:
	field.queue_redraw()
	_over.queue_redraw()

func _animate(delta: float) -> void:
	for sp: Dictionary in _sparks:
		sp.t += delta
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return sp.t < 0.22)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 0.8)
	if _hit_at.size() > 240:
		_hit_at.clear()
	# the wheels turn as far as the cart rolled, and it leans into the roll
	var moved: float = sim.x - _last_x
	_last_x = sim.x
	_wheel += moved / 9.0
	var want_lean := 0.0 if Motion.reduce else clampf(moved / maxf(delta, 0.001) / 900.0, -1.0, 1.0) * 0.12
	_lean = lerpf(_lean, want_lean, minf(1.0, delta * 14.0))
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 12.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO
	_rw.bounds = Rect2(_rw.at(field, Vector2.ZERO), field.size)
	_rw.step(delta)
	var playing: bool = sim.phase == Sim.Phase.PLAY
	var want := clampf((sim.streak - 6) / 30.0, 0.0, 1.0) if playing else 0.0
	_heat = move_toward(_heat, want, delta * (1.5 if want > _heat else 0.8))
	_alarm = move_toward(_alarm, sim.danger(), delta * 2.0)
	_flash = maxf(0.0, _flash - delta * 2.6)

func _keys() -> void:
	var axis := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		axis += 1.0
	sim.axis = axis

func _on_field_input(event: InputEvent) -> void:
	if _paused:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			if _end == null and not settings_sheet.is_open():
				_pause(false)
		return
	if sim == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1:
			_touch = t.index
			_grab(t.position)
		elif not t.pressed and t.index == _touch:
			_touch = -1
			sim.target_x = NAN
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch:
			_slide(d.position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		_mouse = m.pressed and _touch == -1
		if _mouse:
			_grab(m.position)
		elif _touch == -1:
			sim.target_x = NAN
	elif event is InputEventMouseMotion and _mouse:
		_slide((event as InputEventMouseMotion).position)

func _grab(at: Vector2) -> void:
	_touch_from = at
	_cart_from = sim.x
	sim.target_x = sim.x

## A slide, not a spot: the cart moves as far as the finger did, and a
## little more.
func _slide(at: Vector2) -> void:
	sim.target_x = _cart_from + (at.x - _touch_from.x) / _u * GAIN
	# A slide past the wall re-anchors, so coming back moves at once.
	var lo := Sim.CART_HALF
	var hi := Sim.W - lo
	if sim.target_x < lo or sim.target_x > hi:
		sim.target_x = clampf(sim.target_x, lo, hi)
		_touch_from = at
		_cart_from = sim.target_x

## The tutorial card stops the run and leaves it paused, a tap from going on.
func _tutor_hold(on: bool) -> void:
	if on and sim != null and not sim.is_over() and _end == null:
		_pause(true)

func _pause(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	if on:
		_touch = -1
		_mouse = false
		if sim != null:
			sim.target_x = NAN
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
	line.text = "FF_RESUME"
	line.theme_type_variation = "SheetTitle"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_color_override("font_color", Color("fffaf0"))
	col.add_child(line)
	return scrim

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		var pos: Vector2 = ev.get("pos", Vector2.ZERO)
		match String(ev.type):
			"ready":
				_show_banner(tr("PP_READY"), tr("PP_READY_LINE"), 1.0)
			"go":
				_fx.cue("go")
			"wave":
				var milli: bool = ev.kind == Sim.Wave.MILLI
				if int(ev.wave) > 1:
					_show_banner(tr("PP_WAVE_N") % int(ev.wave), tr("PP_MILLI_LINE") if milli else "", 0.7)
					_fx.cue("milli" if milli else "wave")
				_wave_l.pivot_offset = _wave_l.size * 0.5
				Motion.bump(_wave_l, 0.3, 0.35)
			"shot":
				_shot_at = _clock
				_quiet.cue("shot", randf_range(0.94, 1.08), -4.0)
			"hit":
				_hit_at[ev.id] = _clock
				if not ev.quiet:
					_spark(pos, Color("fffaf0"))
					if ev.kind == Sim.Kind.IRON:
						_quiet.cue("clank", randf_range(0.92, 1.1), -6.0)
					else:
						_quiet.cue("hit", randf_range(0.9, 1.15), -6.0)
			"kill":
				_on_kill(ev)
			"token":
				_fx.cue("gift", 0.7 if ev.kind == Sim.Kind.ROT else randf_range(0.96, 1.06))
				_rw.ring(_in_rw(pos), 26.0 * _u, Color(Art.colour(ev.kind, 1), 0.9))
			"catch":
				_on_catch(ev)
			"token_lost":
				_fx.cue("lost", 1.0, -6.0)
				_fx.puff(px(pos), Color("fffaf0"), 4)
			"boom":
				_fx.cue("boom")
				_feel(Haptics.THUD)
				_shake = maxf(_shake, 0.7)
				_flash_now(Color("ffd65c"), 0.4)
				_rw.ring(_in_rw(pos), 78.0 * _u, Color("ffd65c", 0.95))
				_rw.ring(_in_rw(pos), 52.0 * _u, Color("fffaf0", 0.9), 0.06)
				_rw.spray(_in_rw(pos), Art.CRACKER, 12, 760.0, "shard", 1.0)
				_rw.spray(_in_rw(pos), Color("ffd65c"), 10, 820.0, "spark", 1.3)
				_rw.sticker(tr("PP_BOOM"), _in_rw(pos + Vector2(0, -26.0)), 60, 0.9, false, Color("ffd65c"), false, "boom", 30.0)
			"knock":
				_fx.cue("knock", randf_range(0.95, 1.08), -4.0)
			"twin_off":
				_fx.cue("twin_off", 1.0, -4.0)
				_fx.puff(px(Vector2(ev.x, Sim.CART_Y - 10.0)), Pal.PEAR, 7)
			"pod_off":
				_fx.cue("twin_off", 1.25, -8.0)
			"clear":
				_on_clear(ev)
			"warn":
				_fx.cue("warn")
				_feel(Haptics.WARN)
				_rw.sticker(tr("PP_CAREFUL"), _rw.at(field, field.size * Vector2(0.5, 0.52)), 62, 1.1, false, ALARM, false, "warn")
			"over":
				_fx.cue("over")
				_feel(Haptics.LOSE)
				_shake = maxf(_shake, 0.9)
				_flash_now(ALARM, 0.5)
				_game_over()
			"revive":
				_flash_now(Color("fffaf0"), 0.5)
				_rw.ring(_in_rw(Vector2(sim.x, Sim.CART_Y)), 160.0 * _u, Color(Pal.SUN, 0.9))
	sim.events.clear()

func _spark(at: Vector2, col: Color) -> void:
	if _sparks.size() < MAX_SPARKS:
		_sparks.append({"pos": at, "t": 0.0, "col": col, "turn": randf() * TAU})

## A crate or a plate gone: chips of its paint, its number rising, and by
## what it was a golden shower, a head's end, or the streak's word.
func _on_kill(ev: Dictionary) -> void:
	var pos: Vector2 = ev.pos
	var kind: int = ev.kind
	var col := Art.colour(kind, int(ev.max))
	var at := _in_rw(pos)
	var k := _u / 2.4
	var popped: bool = ev.popped
	_rw.spray(at, col, 3 if popped else 6, 460.0, "shard", 0.9 * k)
	_rw.spray(at, Color("fffaf0"), 2 if popped else 3, 400.0, "spark", 0.9 * k)
	_spark(pos, col.lightened(0.4))
	var gold := kind == Sim.Kind.GOLD
	var head := kind == Sim.Kind.HEAD
	if _pops.size() >= MAX_POPS:
		_pops.pop_front()
	_pops.append({"pos": pos, "text": "+" + Art.short(int(ev.points)), "t": 0.0, "col": Pal.SUN if gold or head else Color("fffaf0"),
		"big": gold or head, "drift": randf_range(-1.0, 1.0)})
	var streak: int = ev.streak
	if head:
		_fx.cue("head")
		_feel(Haptics.THUD)
		_shake = maxf(_shake, 0.6)
		_flash_now(Color("fffaf0"), 0.4)
		_rw.sticker(tr("PP_SQUASHED"), _in_rw(pos + Vector2(0, -34.0)), 76, 1.3, true, Color.WHITE, true, "head", 30.0)
		_rw.ring(at, 90.0 * _u, Color(Pal.SUN, 0.9))
		_rw.spray(at, Art.HEAD, 12, 700.0, "shard", 1.1 * k)
		_rw.spray(at, Pal.SUN, 10, 760.0, "star", 1.0)
	elif gold:
		_fx.cue("pop_gold")
		_feel(Haptics.BUMP)
		_shake = maxf(_shake, 0.3)
		_flash_now(Art.GOLD, 0.3)
		_rw.spray(at, Art.GOLD, 14, 720.0, "coin", 1.0 * k)
		_rw.spray(at, Pal.SUN, 4, 520.0, "star", 0.8, 0.1, _plate_at(_score_l))
		_rw.ring(at, 44.0 * _u, Color(Art.GOLD, 0.9))
		_rw.sticker(tr("PP_GOLDEN"), _in_rw(pos + Vector2(0, -28.0)), 58, 1.1, true, Color.WHITE, true, "gold", 30.0)
	else:
		_fx.cue("pop", minf(1.5, 1.0 + 0.025 * streak), -8.0 if popped else 0.0)
		_feel(Haptics.TICK if popped else Haptics.TAP)
		_shake = maxf(_shake, 0.12)
	for i in WORDS.size():
		if streak == int(WORDS[i][0]):
			var tier := WORDS.size() - 1 - i
			var mid := _rw.at(field, field.size * Vector2(0.5, 0.42))
			_rw.sticker(tr(WORDS[i][1]), mid, 72 + 8 * tier, 1.3 + 0.12 * tier, true, Color.WHITE, tier >= 1, "word", 24.0)
			_rw.spray(mid, Pal.SUN, 6 + 3 * tier, 760.0, "star", 1.0)
			_rw.spray(mid, Rewards.CONFETTI[tier % Rewards.CONFETTI.size()], 8 + 2 * tier, 700.0, "confetti", 1.0)
			_flash_now(Color("fffaf0"), 0.2 + 0.06 * tier)
			_fx.cue("word", 1.0 + 0.06 * tier)
			_feel(Haptics.BUMP)
			if tier >= 3:
				_rw.rain(1.6, ["confetti", "star"], Rewards.CONFETTI)
			break

## A gift caught: what it gave, lettered over the cart, and stars home to
## the gun's line on the grass.
func _on_catch(ev: Dictionary) -> void:
	var got: int = ev.got
	var at := _in_rw(Vector2(sim.x, Sim.CART_Y - 44.0))
	var col: Color = Art.GIFT[got]
	if got == Sim.Kind.ROT:
		# a rotten one: what it took, lettered in its own murk, and a shudder
		_fx.cue("rot")
		_feel(Haptics.WARN)
		_shake = maxf(_shake, 0.4)
		_flash_now(Art.ROT_INK, 0.35)
		_rw.sticker(tr(ROT[int(ev.lost)]), at + Vector2(0, -30.0), 58, 1.1, false, Color("d9c7e0"), false, "got", 34.0)
		_rw.spray(at, Art.ROT_INK, 8, 420.0, "shard", 0.9)
		return
	_fx.cue(CATCH_CUE.get(got, "catch"), 1.0 + 0.04 * (sim.peas + sim.rate_lv))
	_feel(Haptics.GOOD)
	if got == Sim.Kind.SHOVE:
		_rw.ring(_in_rw(Vector2(Sim.W * 0.5, Sim.CART_Y - 60.0)), 200.0 * _u, Color(col, 0.9))
		_shake = maxf(_shake, 0.3)
	_rw.sticker(tr(GOT[got]), at + Vector2(0, -30.0), 58, 1.1, false, col.lightened(0.25), false, "got", 34.0)
	_rw.ring(_in_rw(Vector2(sim.x, Sim.CART_Y - 14.0)), 40.0 * _u, Color(col, 0.9))
	_rw.spray(at, col, 8, 520.0, "star", 0.9)
	_rw.spray(at, Color("fffaf0"), 6, 460.0, "spark", 1.0)
	_flash_now(col, 0.16)

## A wave cleared: lettered, its bonus under it, a short rain.
func _on_clear(ev: Dictionary) -> void:
	var mid := _rw.at(field, field.size * Vector2(0.5, 0.3))
	_fx.cue("clear")
	_feel(Haptics.BUMP)
	_rw.sticker(tr("PP_CLEARED"), mid, 78, 1.3, true, Color.WHITE, true, "clear")
	_rw.sticker("+" + Record.grouped(int(ev.bonus)), mid + Vector2(0, 86.0), 46, 1.3, false, Pal.SUN, false, "clear_bonus")
	_rw.spray(mid, Pal.SUN, 12, 780.0, "star", 1.0)
	_rw.spray(mid, Pal.SUN, 5, 520.0, "star", 0.8, 0.15, _plate_at(_score_l))
	_rw.rain(1.2, ["confetti", "star"], Rewards.CONFETTI)
	_flash_now(Color("fffaf0"), 0.25)

func _show_banner(text: String, sub: String, hold: float) -> void:
	_banner.text = text
	_sub.text = sub
	_sub.visible = sub != ""
	var box: Control = _banner.get_meta("box")
	box.reset_size()
	box.size.x = field.size.x
	box.position = Vector2(0, field.size.y * 0.36)
	box.pivot_offset = Vector2(box.size.x * 0.5, box.size.y * 0.5)
	Motion.stop(_banner_tw)
	_banner_tw = create_tween()
	if Motion.reduce:
		box.scale = Vector2.ONE
		_banner_tw.tween_property(box, "modulate:a", 1.0, 0.15)
		_banner_tw.tween_interval(hold)
		_banner_tw.tween_property(box, "modulate:a", 0.0, 0.3)
		return
	box.scale = Vector2(0.6, 0.6)
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(box, "modulate:a", 1.0, 0.14)
	_banner_tw.tween_property(box, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(hold)
	_banner_tw.chain().tween_property(box, "modulate:a", 0.0, 0.3)
	_banner_tw.tween_property(box, "scale", Vector2(1.12, 1.12), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## The score rolls up to the real one and gives a beat when it lands; the
## best follows it once passed.
func _refresh_hud(delta := 0.0) -> void:
	if sim == null:
		return
	if sim.score != _shown_score:
		if sim.score > _shown_score and _shown_score >= 0:
			_score_l.pivot_offset = _score_l.size * 0.5
			Motion.bump(_score_l, 0.1, 0.2)
		_shown_score = sim.score
		if not _beat_best and _best > 0 and sim.score > _best:
			_beat_best = true
			_best_l.pivot_offset = _best_l.size * 0.5
			Motion.bump(_best_l, 0.3, 0.4)
			_new_best_passed()
	if Motion.reduce or sim.score < _roll:
		_roll = sim.score
	else:
		_roll = move_toward(_roll, sim.score, maxf(delta * absf(sim.score - _roll) * 10.0, delta * 300.0))
	var shown := Record.grouped(int(_roll))
	if _score_l.text != shown:
		_score_l.text = shown
		_best_l.text = Record.grouped(maxi(_best, int(_roll)))
	var wave := str(maxi(1, sim.wave))
	if _wave_l.text != wave:
		_wave_l.text = wave

# --- drawing ---

## A quad with a colour at each corner, for the gradients.
static func _quad(b: Face.Builder, p: Array, c: Array) -> void:
	var i0 := b.vertex(p[0], c[0])
	var i1 := b.vertex(p[1], c[1])
	var i2 := b.vertex(p[2], c[2])
	var i3 := b.vertex(p[3], c[3])
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)

## A pseudo-random 0..1 from two numbers, the same every frame.
static func _hash(a: float, b: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)

## The still garden, built on resize: the sky with a sun and clouds in it,
## far peaks, nearer hills with trees, and the grass the cart rolls on.
func _build_scene() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	var turf := px(Vector2(0, TURF)).y
	_quad(b, [Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, turf), Vector2(0, turf)], [SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW])
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	# the sun, pale, with a ring of rays
	var sun := Vector2(s.x * 0.8, s.y * 0.13)
	b.disc(sun, 64.0 * _u / 2.4, Color(1, 0.98, 0.8, 0.35))
	Rewards.sunrays(b, sun, 50.0 * _u / 2.4, 110.0 * _u / 2.4, 12, 0.2, Color(1, 0.98, 0.8, 0.18))
	b.disc(sun, 40.0 * _u / 2.4, Color("fff4c2"))
	for i in 4:
		var c := Vector2(s.x * (0.12 + 0.26 * i + rng.randf_range(-0.05, 0.05)), s.y * rng.randf_range(0.06, 0.34))
		var w := rng.randf_range(60.0, 96.0) * _u / 2.4
		for k in 3:
			b.ellipse(c + Vector2((k - 1) * w * 0.55, (k % 2) * w * 0.1), w * 0.5, w * 0.24, Color(1, 1, 1, 0.55))
		b.ellipse(c + Vector2(0, -w * 0.16), w * 0.42, w * 0.26, Color(1, 1, 1, 0.6))
	# two rows of peaks, the far one paler
	var foot := turf - 26.0 * _u
	for layer in 2:
		var col := PEAK_FAR if layer == 0 else PEAK
		var n := 3 + layer
		for i in n:
			var cx := s.x * ((i + 0.5 + rng.randf_range(-0.25, 0.25)) / n)
			var tall := (150.0 - 46.0 * layer + rng.randf_range(-20.0, 26.0)) * _u
			var wide := tall * rng.randf_range(0.8, 1.05)
			b.fan(PackedVector2Array([Vector2(cx - wide, turf), Vector2(cx, foot - tall), Vector2(cx + wide, turf)]), col)
			b.fan(PackedVector2Array([Vector2(cx, foot - tall), Vector2(cx + wide * 0.18, foot - tall * 0.72), Vector2(cx, foot - tall * 0.8),
				Vector2(cx - wide * 0.14, foot - tall * 0.7)]), Color(1, 1, 1, 0.5))
	# the hills in front of them, with a few round trees
	for i in 4:
		var cx := s.x * (0.1 + 0.27 * i)
		b.ellipse(Vector2(cx, turf + 6.0 * _u), s.x * 0.24, (30.0 + 9.0 * (i % 2)) * _u, HILL if i % 2 == 0 else HILL_NEAR)
	for i in 7:
		var at := Vector2(s.x * rng.randf_range(0.04, 0.96), turf - rng.randf_range(4.0, 18.0) * _u)
		var r := rng.randf_range(5.0, 8.0) * _u
		b.fan(Face.Builder.round_rect(at + Vector2(-r * 0.14, 0), Vector2(r * 0.28, r * 1.1), r * 0.1), Color("8a6a45", 0.7))
		b.disc(at + Vector2(0, -r * 0.4), r, Color("6fb060", 0.85))
		b.disc(at + Vector2(-r * 0.3, -r * 0.7), r * 0.4, Color(1, 1, 1, 0.12))
	# the grass: a pale lip, a row of blades cut into the darker turf, daisies
	b.fan(PackedVector2Array([Vector2(0, turf), Vector2(s.x, turf), s, Vector2(0, s.y)]), GRASS)
	b.fan(PackedVector2Array([Vector2(0, turf), Vector2(s.x, turf), Vector2(s.x, turf + 3.0 * _u), Vector2(0, turf + 3.0 * _u)]), GRASS.lightened(0.22))
	var blade := 9.0 * _u
	var y0 := turf + 8.0 * _u
	var zig := PackedVector2Array([Vector2(0, s.y), Vector2(0, y0 + blade)])
	var x := 0.0
	while x < s.x + blade:
		zig.append(Vector2(x + blade * 0.5, y0))
		zig.append(Vector2(x + blade, y0 + blade))
		x += blade
	zig.append(Vector2(s.x, s.y))
	b.polygon(zig, GRASS_DEEP)
	for i in 9:
		# clear of the gun's line, which stands on the left
		var p := Vector2(s.x * rng.randf_range(0.64, 1.0), rng.randf_range(y0 + blade * 1.6, s.y - 8.0))
		for q in 5:
			b.disc(p + Vector2.from_angle(TAU * q / 5.0) * 1.6 * _u, 1.3 * _u, Color("fffaf0"))
		b.disc(p, 1.0 * _u, Color("f2c14e"))
	return b.mesh()

func _draw_field() -> void:
	if _scene == null:
		_layout_field()
	if _scene != null:
		field.draw_mesh(_scene, null)

## Everything that moves, back to front: the line, the crates or the
## millipede and their numbers, the peas and the sparks, the gifts on their
## way down, the carts, the gun's line and the numbers going up.
func _draw_over() -> void:
	if sim == null:
		return
	_over.draw_set_transform(_shake_off)
	var font := Art.font()
	if sim.frost_t > 0.0:
		# the frost: a pale wash over the garden, going as it runs out
		_over.draw_rect(Rect2(Vector2.ZERO, field.size), Color(Art.GIFT[Sim.Kind.FROST], 0.2 * minf(1.0, sim.frost_t)))
	_draw_line()
	var top := Face.Builder.new()
	_head_tag = []
	if sim.wave_kind == Sim.Wave.WALL:
		_draw_wall(font)
	else:
		_draw_milli(font, top)
	_draw_peas()
	_draw_sparks()
	_draw_muzzle(top)
	var timed := _timed()
	_draw_timed_rings(top, timed)
	if _heat > 0.01:
		var hb := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 9.0)
		Rewards.edge_glow(top, Rect2(Vector2.ZERO, field.size), HEAT.lerp(ALARM, _heat), _heat, hb)
	if _alarm > 0.01:
		var ab := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 11.0)
		Rewards.edge_glow(top, Rect2(Vector2.ZERO, field.size), ALARM, _alarm, ab)
	if not top.verts.is_empty():
		_live_top = top.mesh()
		_over.draw_mesh(_live_top, null)
	if _chips != null:
		_over.draw_mesh(_chips, null)
	for k in timed.size():
		var blink: bool = float(timed[k][1]) < 0.2 and fmod(_clock, 0.3) < 0.12 and not Motion.reduce
		_over.draw_mesh(Art.token(timed[k][0], _u), null, Transform2D(0.0, Vector2(0.6, 0.6), 0.0, _timed_at(k)), Color(1, 1, 1, 0.45 if blink else 1.0))
	if not _head_tag.is_empty():
		Art.number(_over, font, px(_head_tag[0]), _head_tag[1], Sim.SEG_R * 1.25 * _u)
	for tk: Dictionary in sim.tokens:
		var bob := 1.0 if Motion.reduce else 1.0 + 0.08 * sin(_clock * 9.0 + float(tk.id))
		var tilt := 0.0 if Motion.reduce else sin(_clock * 4.0 + float(tk.id)) * 0.18
		_over.draw_mesh(Art.token(tk.kind, _u), null, Transform2D(tilt, Vector2(bob, bob), 0.0, px(Vector2(tk.x, tk.y))))
	if sim.twin_t > 0.0:
		_draw_cart(sim.twin_x, true)
	_draw_cart(sim.x, false)
	_draw_gun_words(font)
	_draw_pops(font)
	_over.draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		_over.draw_rect(Rect2(Vector2.ZERO, field.size), Color(_flash_col, _flash * 0.4))

## The line nothing may reach: chalk dashes across the garden, turning red
## and running as something nears it. The dashes are one mesh built with
## the garden; the run is its transform and the red its tint.
func _build_dashes() -> ArrayMesh:
	var b := Face.Builder.new()
	var dash := 9.0 * _u
	var x := -dash * 2.0
	while x < field.size.x + dash * 2.0:
		b.fan(Face.Builder.round_rect(Vector2(x, -1.2 * _u), Vector2(dash, 2.4 * _u), 1.2 * _u), Color.WHITE)
		x += dash * 2.0
	return b.mesh()

func _draw_line() -> void:
	if _dashes == null:
		return
	var y := px(Vector2(0, Sim.DANGER + 6.0)).y
	var col := Color("fffaf0", 0.4).lerp(Color(ALARM, 0.9), _alarm)
	var dash := 9.0 * _u
	var run := 0.0 if Motion.reduce else fmod(_clock * 30.0 * _alarm, dash * 2.0)
	_over.draw_mesh(_dashes, null, Transform2D(0.0, Vector2(run - dash * 2.0, y)), col)

## One MultiMesh a look of pea, as many shown as are in the air.
func _draw_peas() -> void:
	var looks := 3
	if _pea_mm.is_empty():
		for k in looks:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			_pea_mm.append(mm)
			_pea_buf.append(PackedFloat32Array())
	var counts := [0, 0, 0]
	var u := _u
	var ox := _origin.x
	var oy := _origin.y
	for p: Dictionary in sim.shots:
		var k: int = p.k
		var buf: PackedFloat32Array = _pea_buf[k]
		var o: int = counts[k] * 8
		if o + 8 > buf.size():
			buf.resize(o + 8 * 64)
		buf[o] = 1.0
		buf[o + 3] = ox + float(p.x) * u
		buf[o + 5] = 1.0
		buf[o + 7] = oy + float(p.y) * u
		_pea_buf[k] = buf
		counts[k] += 1
	for k in looks:
		if counts[k] == 0:
			continue
		var mm: MultiMesh = _pea_mm[k]
		var buf: PackedFloat32Array = _pea_buf[k]
		var mesh := Art.shot(k, _u)
		if mm.mesh != mesh:
			mm.mesh = mesh
		if mm.instance_count * 8 != buf.size():
			mm.instance_count = buf.size() / 8
		mm.visible_instance_count = counts[k]
		mm.buffer = buf
		_over.draw_multimesh(mm, null)

## How a crate or a plate sits this frame: knocked by the pea that just
## landed (a squeeze and a white flash), else as it is.
func _knocked(id: int) -> Array:
	var since: float = _clock - float(_hit_at.get(id, -10.0))
	if since > 0.1:
		return [Vector2.ONE, Color.WHITE]
	var k := 1.0 - since / 0.1
	var sc := Vector2.ONE if Motion.reduce else Vector2(1.0 + 0.07 * k, 1.0 - 0.09 * k)
	return [sc, Color(1.0 + 0.22 * k, 1.0 + 0.22 * k, 1.0 + 0.22 * k)]

## One more of `mesh` this frame, under `xf` and tinted `col`.
func _cast_add(mesh: ArrayMesh, xf: Transform2D, col: Color) -> void:
	var g: Array = _cast.get(mesh, [])
	if g.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = mesh
		g = [mm, PackedFloat32Array(), 0]
		_cast[mesh] = g
	var buf: PackedFloat32Array = g[1]
	var o: int = int(g[2]) * 12
	if o + 12 > buf.size():
		buf.resize(o + 12 * 8)
	buf[o] = xf.x.x
	buf[o + 1] = xf.y.x
	buf[o + 3] = xf.origin.x
	buf[o + 4] = xf.x.y
	buf[o + 5] = xf.y.y
	buf[o + 7] = xf.origin.y
	buf[o + 8] = col.r
	buf[o + 9] = col.g
	buf[o + 10] = col.b
	buf[o + 11] = col.a
	g[1] = buf
	g[2] = int(g[2]) + 1

## Draws what `_cast_add` gathered and empties it for the next frame.
func _cast_draw() -> void:
	for mesh in _cast:
		var g: Array = _cast[mesh]
		var n: int = g[2]
		if n == 0:
			continue
		var mm: MultiMesh = g[0]
		var buf: PackedFloat32Array = g[1]
		if mm.instance_count * 12 != buf.size():
			mm.instance_count = buf.size() / 12
		mm.visible_instance_count = n
		mm.buffer = buf
		_over.draw_multimesh(mm, null)
		g[2] = 0

func _draw_wall(font: Font) -> void:
	var numbered: Array = []
	for r in sim.rows.size():
		var row: Array = sim.rows[r]
		for c in Sim.COLS:
			if row[c] == null:
				continue
			var cell: Dictionary = row[c]
			var at: Vector2 = sim.cell_pos(r, c)
			if at.y < -Sim.CELL_H - _origin.y / _u:
				continue
			var kn := _knocked(cell.id)
			var kind: int = cell.kind
			var tier := Art.tier_of(cell.hp) if kind == Sim.Kind.CRATE else 0
			var sway := 0.0
			if Sim.holds_token(kind) and not Motion.reduce:
				sway = sin(_clock * 5.0 + c * 1.7 + r) * 0.04
			_cast_add(Art.crate(kind, tier, _u), Transform2D(sway, kn[0], 0.0, px(at)), kn[1])
			if kind == Sim.Kind.CRATE or kind == Sim.Kind.GOLD or kind == Sim.Kind.IRON:
				numbered.append([at, cell.hp])
	_cast_draw()
	for n: Array in numbered:
		Art.number(_over, font, px(n[0] + Vector2(0, -2.2)), n[1], (Sim.CELL_H - 3.0) * _u)

func _draw_milli(font: Font, top: Face.Builder) -> void:
	var numbered: Array = []
	var head_at: Array = []
	# tail first, so each plate laps the one behind it and the head laps all
	for i in range(sim.segs.size() - 1, -1, -1):
		var sg: Dictionary = sim.segs[i]
		var s: float = sg.s
		if s < -Sim.SEG_R - _origin.x / _u:
			continue
		var at: Vector2 = Sim.path_at(s)
		var kn := _knocked(sg.id)
		var sc: Vector2 = kn[0]
		var jitter := Vector2.ZERO
		if not Motion.reduce:
			var beat := 1.0 + 0.04 * sin(_clock * 7.0 - i * 0.9)
			sc *= Vector2(beat, beat)
			if float(sg.dying) >= 0.0:
				jitter = Vector2(sin(_clock * 90.0 + i), cos(_clock * 70.0 + i)) * 1.5
		if sg.kind == Sim.Kind.HEAD:
			var ahead: Vector2 = Sim.path_at(s + 3.0) - at
			var ang := ahead.angle() if ahead.length_squared() > 0.0001 else 0.0
			var cross: bool = sim.danger() > 0.35 or sim.is_over()
			head_at = [Art.head(_u, cross), Transform2D(ang, sc, 0.0, px(at)), kn[1]]
			# the pupils, turned with the head and watching the cart
			var look := (Vector2(sim.x, Sim.CART_Y) - at).normalized()
			var r := Sim.HEAD_R * _u
			for side in [-1.0, 1.0]:
				var eye := px(at) + Vector2(r * 0.36, side * r * 0.4 - 1.0 * _u).rotated(ang)
				top.disc(eye + look * r * 0.12, r * 0.15, Art.FEELER)
			# its number on a dark plate over it, lettered last so nothing laps it
			var tag := at + Vector2(0, -Sim.HEAD_R - 9.0)
			var wide := (9.0 + 5.0 * Art.short(sg.hp).length()) * _u
			top.fan(Face.Builder.round_rect(px(tag) - Vector2(wide, 7.5 * _u), Vector2(wide * 2.0, 15.0 * _u), 7.5 * _u), Color(Art.HEAD_DEEP, 0.92))
			_head_tag = [tag, sg.hp]
			continue
		var kind: int = sg.kind
		var tier := Art.tier_of(sg.hp) if kind == Sim.Kind.CRATE else 0
		_cast_add(Art.plate(kind, tier, _u), Transform2D(0.0, sc, 0.0, px(at + jitter)), kn[1])
		if kind == Sim.Kind.CRATE or kind == Sim.Kind.GOLD or kind == Sim.Kind.IRON:
			numbered.append([at + Vector2(0, -0.6), sg.hp, 1.0])
	_cast_draw()
	if not head_at.is_empty():
		_over.draw_mesh(head_at[0], null, head_at[1], head_at[2])
	for n: Array in numbered:
		Art.number(_over, font, px(n[0]), n[1], Sim.SEG_R * 1.7 * _u * float(n[2]))

func _draw_sparks() -> void:
	if _sparks.is_empty():
		return
	if _spark_mm == null:
		_spark_mm = MultiMesh.new()
		_spark_mm.transform_format = MultiMesh.TRANSFORM_2D
		_spark_mm.use_colors = true
		_spark_mm.mesh = Art.spark()
		_spark_mm.instance_count = MAX_SPARKS
		_spark_buf.resize(MAX_SPARKS * 12)
	var n := mini(_sparks.size(), MAX_SPARKS)
	for i in n:
		var sp: Dictionary = _sparks[i]
		var k: float = sp.t / 0.22
		var c := px(sp.pos)
		var r := (4.0 + 7.0 * k) * _u
		var ca := cos(float(sp.turn)) * r
		var sa := sin(float(sp.turn)) * r
		var col: Color = sp.col
		var o := i * 12
		_spark_buf[o] = ca
		_spark_buf[o + 1] = -sa
		_spark_buf[o + 3] = c.x
		_spark_buf[o + 4] = sa
		_spark_buf[o + 5] = ca
		_spark_buf[o + 7] = c.y
		_spark_buf[o + 8] = col.r
		_spark_buf[o + 9] = col.g
		_spark_buf[o + 10] = col.b
		_spark_buf[o + 11] = 1.0 - k
	_spark_mm.visible_instance_count = n
	_spark_mm.buffer = _spark_buf
	_over.draw_multimesh(_spark_mm, null)

## The flash at each pod's mouth just after a volley.
func _draw_muzzle(b: Face.Builder) -> void:
	var since := _clock - _shot_at
	if since > 0.07 or Motion.reduce or sim.phase != Sim.Phase.PLAY:
		return
	var a := 1.0 - since / 0.07
	var xs: Array = [sim.x]
	if sim.twin_t > 0.0:
		xs.append(sim.twin_x)
	for x: float in xs:
		var c := px(Vector2(x, Sim.CART_Y - 40.0))
		var pts := PackedVector2Array()
		for k in 12:
			pts.append(c + Vector2.from_angle(TAU * k / 12.0 + _clock * 7.0) * (11.0 if k % 2 == 0 else 5.0) * _u)
		b.polygon(pts, Color("fff1a8", 0.9 * a))
		b.disc(c, 4.0 * _u, Color(1, 1, 1, a))

## A cart: the pod sunk into its cradle by the shot just fired, the box, and
## two wheels turned as far as it has rolled. The helper's is smaller.
func _draw_cart(x: float, helper: bool) -> void:
	var u := _u * (0.8 if helper else 1.0)
	var foot := px(Vector2(x, TURF)) - Vector2(0, 9.0 * u)
	var since := _clock - _shot_at
	var kick := 0.0
	if since < RECOIL and not Motion.reduce and sim.phase == Sim.Phase.PLAY:
		kick = 1.0 - since / RECOIL
	var tint := Color.WHITE
	if helper and sim.twin_t < 2.5 and fmod(_clock, 0.3) < 0.12 and not Motion.reduce:
		tint = Color(1, 1, 1, 0.45)
	var lean := Transform2D(_lean, foot)
	_over.draw_mesh(Art.barrel(u, helper), null, lean * Transform2D(0.0, Vector2(1.0 + 0.1 * kick, 1.0 - 0.14 * kick), 0.0, Vector2(0, (-12.0 + 4.0 * kick) * u)), tint)
	_over.draw_mesh(Art.cart(u, helper), null, lean, tint)
	for side in [-1.0, 1.0]:
		_over.draw_mesh(Art.wheel(u), null, Transform2D(_wheel, foot + Vector2(side * 13.0 * u, 0)), tint)

## The gun's line on the grass: a picture for the peas, the rate and the
## pea's weight, each with its number beside it.
func _gun_chip(k: int) -> Vector2:
	return px(Vector2(18.0 + 56.0 * k, Sim.H - 13.0))

func _build_chips() -> ArrayMesh:
	var b := Face.Builder.new()
	var kinds := [Sim.Kind.PEA, Sim.Kind.RATE, Sim.Kind.POWER]
	for k in 3:
		var c := _gun_chip(k)
		b.fan(Face.Builder.round_rect(c + Vector2(-13.0, -9.5) * _u, Vector2(50.0, 19.0) * _u, 9.0 * _u), Color(0.12, 0.25, 0.06, 0.35))
		b.disc(c, 8.0 * _u, Art.GIFT[kinds[k]])
		if k == 0:
			Art.pea(b, c, 4.0 * _u)
		else:
			Art.icon(b, kinds[k], c, 13.0 * _u)
	return b.mesh()

## What is running down, as [kind, the part of it left]: the pod held, the
## magnet, the frost and the helper, lettered from the right of the grass.
func _timed() -> Array:
	var out: Array = []
	if sim.pod_t > 0.0:
		out.append([sim.pod, sim.pod_t / Sim.POD_TIME])
	if sim.magnet_t > 0.0:
		out.append([Sim.Kind.MAGNET, sim.magnet_t / Sim.MAGNET_TIME])
	if sim.frost_t > 0.0:
		out.append([Sim.Kind.FROST, sim.frost_t / Sim.FROST_TIME])
	if sim.twin_t > 0.0:
		out.append([Sim.Kind.TWIN, sim.twin_t / Sim.TWIN_TIME])
	return out

func _timed_at(k: int) -> Vector2:
	return px(Vector2(Sim.W - 14.0 - 24.0 * k, Sim.H - 13.0))

## Under each: a dark plate and a pale ring that runs down with it.
func _draw_timed_rings(b: Face.Builder, timed: Array) -> void:
	for k in timed.size():
		var c := _timed_at(k)
		b.disc(c, 10.5 * _u, Color(0.12, 0.25, 0.06, 0.45))
		var part := clampf(float(timed[k][1]), 0.0, 1.0)
		if part > 0.02:
			b.stroke(Face.Builder.arc_points(c, 9.4 * _u, -PI * 0.5, -PI * 0.5 + TAU * part), 1.8 * _u, Color("fffaf0"))

func _draw_gun_words(font: Font) -> void:
	var values := [sim.peas, sim.rate_lv + 1, sim.power]
	var fs := int(13.0 * _u)
	for k in 3:
		var text := "x%s" % Art.short(values[k])
		var at := _gun_chip(k) + Vector2(11.0 * _u, fs * 0.36)
		_over.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fffaf0"))

## The numbers off a crate gone, lettered like stickers: popping big and
## settling, rising and drifting as they fade.
func _draw_pops(font: Font) -> void:
	for p: Dictionary in _pops:
		var a := 1.0 - clampf((p.t - 0.45) / 0.35, 0.0, 1.0)
		var rise := 26.0 * _u * (1.0 - exp(-p.t * 4.5))
		var at := px(p.pos) + Vector2(p.drift * 10.0 * p.t, -rise)
		var full := int((19.0 if p.big else 14.0) * _u)
		var fs := full if Motion.reduce else maxi(8, int(lerpf(full * 0.4, full * 1.0, Motion.back_out(minf(1.0, p.t / 0.2)))))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := at + Vector2(-w * 0.5, 0)
		_over.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(Art.INK, a))
		_over.draw_string(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.col, a))

# --- the rewards ---

## A point of the garden, in field units, in the rewards layer's pixels.
func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(field, px(p) + _shake_off)

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

func _new_best_passed() -> void:
	_rw.sticker(tr("FF_NEW_BEST"), _rw.at(field, field.size * Vector2(0.5, 0.2)), 66, 1.8, true, Color.WHITE, true, "best")
	_rw.spray(_plate_at(_best_l), Pal.SUN, 14, 620.0, "star", 1.0)
	_rw.spray(_plate_at(_best_l), Art.GOLD, 10, 620.0, "coin", 1.0)
	_rw.ring(_plate_at(_best_l), 160.0, Color(Pal.SUN, 0.9))
	_rw.rain(1.6, ["confetti", "star"], Rewards.CONFETTI)
	_fx.cue("word", 1.3, -3.0)
	_feel(Haptics.BUMP)

## The garden flashes `col`, `amount` at most.
func _flash_now(col: Color, amount: float) -> void:
	if Motion.reduce:
		return
	_flash = maxf(_flash, amount)
	_flash_col = col

# --- the end ---

func _game_over() -> void:
	if _offer_chance():
		return
	var better := Record.add(GAME, sim.score, sim.wave, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.wave,
		"seconds": secs, "kills": sim.kills, "caught": sim.caught, "fired": sim.fired,
		"peas": sim.peas, "rate": sim.rate_lv, "power": sim.power, "best": better})
	Ads.note_finished()
	_show_banner(tr("FF_GAME_OVER"), "", 1.2)
	top_bar.refresh(self)
	get_tree().create_timer(1.6).timeout.connect(_show_end.bind(better))

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
	seat.custom_minimum_size = Vector2(0, 226)
	seat.clip_contents = true
	# The cart on a tuft of grass, still firing: peas going up out of the pod
	# in a row, a sunburst turning behind it once the card is up.
	var u := 3.4
	var shown_at := _clock
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 178.0)
		var b := Face.Builder.new()
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.5) / 0.35, 0.0, 1.0)
		if glow > 0.0:
			var rc := c + Vector2(0, -70.0)
			var rr := 200.0 * Motion.back_out(glow)
			b.disc(rc, rr * 0.5, Color(Color("fff4c2"), 0.45))
			Rewards.sunrays(b, rc, rr * 0.2, rr, 14, t * 0.5, Color(Art.GOLD if better else Pal.SUN, 0.5))
			Rewards.sunrays(b, rc, rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
		b.ellipse(c + Vector2(0, 34.0), 150.0, 22.0, GRASS)
		b.ellipse(c + Vector2(0, 30.0), 140.0, 16.0, GRASS.lightened(0.15))
		for k in 4:
			var up := fmod(t * 1.6 + k * 0.25, 1.0)
			Art.pea(b, c + Vector2(0, -44.0 * u - up * 120.0), 3.4 * u, 1.0 - up)
		var m := b.mesh()
		seat.set_meta("keep", m)
		seat.draw_mesh(m, null)
		var kick := 0.0 if Motion.reduce else maxf(0.0, 1.0 - fmod(t * 1.6, 0.25) / 0.09)
		var foot := c + Vector2(0, 21.0 - 9.0 * u + 9.0 * u)
		seat.draw_mesh(Art.barrel(u), null, Transform2D(0.0, Vector2(1.0 + 0.1 * kick, 1.0 - 0.14 * kick), 0.0, foot + Vector2(0, (-12.0 + 4.0 * kick) * u)))
		seat.draw_mesh(Art.cart(u), null, Transform2D(0.0, foot))
		for side in [-1.0, 1.0]:
			seat.draw_mesh(Art.wheel(u), null, Transform2D(sin(t * 1.3) * 0.4, foot + Vector2(side * 13.0 * u, 0))))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "PP_END_CARD"
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
	for pair in [[str(sim.wave), "PP_STAT_WAVE"], [Record.grouped(sim.kills), "PP_STAT_CRATES"], [str(sim.caught), "PP_STAT_GIFTS"]]:
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
		if not Motion.reduce:
			var i := stats.get_child_count() - 1
			plate.modulate.a = 0.0
			plate.resized.connect(func() -> void: plate.pivot_offset = plate.size * 0.5)
			plate.scale = Vector2(0.4, 0.4)
			var tw := plate.create_tween().set_parallel(true)
			tw.tween_property(plate, "modulate:a", 1.0, 0.2).set_delay(1.3 + 0.15 * i)
			tw.tween_property(plate, "scale", Vector2.ONE, 0.4).set_delay(1.3 + 0.15 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
## burst of coins when it gets there.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 1.1, 0.0, 1.0)
	var shown := int(sim.score * (1.0 - pow(1.0 - k, 3.0)))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
		if int(_clock * 20.0) % 2 == 0:
			_quiet.cue("hit", 0.9 + 0.8 * k, -8.0)
	if k >= 1.0:
		_end_score.pivot_offset = _end_score.size * 0.5
		Motion.bump(_end_score, 0.25, 0.4)
		var at := _rw.at(_end_score, _end_score.size * 0.5)
		_rw.spray(at, Pal.SUN, 12, 620.0, "star", 1.1)
		_rw.spray(at, Art.GOLD, 12, 620.0, "coin", 1.1)
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
	if not better:
		return
	_rw.rain(3.5, ["confetti", "coin", "star"], Rewards.CONFETTI)
	var fx := Fx2D.new()
	_end.add_child(fx)
	var cols := [Art.GOLD, Art.POD, Art.GIFT[Sim.Kind.PEA], Pal.FLOWER, Pal.SUN_RAY, Art.GIFT[Sim.Kind.RATE]]
	var mid := size * 0.5
	for k in 8:
		var at := mid + Vector2.from_angle(TAU * k / 8.0 - PI * 0.5) * Vector2(400.0, 330.0)
		var t := get_tree().create_timer(0.25 + 0.14 * k)
		t.timeout.connect(func() -> void:
			if is_instance_valid(fx):
				fx.puff(at, cols[k % cols.size()], 12))

# --- chrome ---

func _on_reset() -> void:
	if sim != null and not sim.is_over():
		Analytics.track("board_reset", {"puzzle_id": GAME})
	_ask()

func _on_back() -> void:
	if sim != null and not sim.is_over() and sim.score > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.wave})
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
	var card := BoostCard.new(GAME)
	card.name = "BoostCard"
	card.play.connect(func(ids: Array) -> void:
		_boosts = ids
		_new_game()
		_fx.buzz(Haptics.TAP))
	add_child(card)

## At game over, once a run: the Second chance, when one is held or the gold
## for one is. True while it is up; No thanks ends the run as it would have.
func _offer_chance() -> bool:
	if _chance_used or not SecondChance.wanted():
		return false
	_chance_used = true
	var card := SecondChance.new(GAME)
	card.name = "SecondChance"
	card.taken.connect(func() -> void:
		_boosted = true
		Boosters.revive(GAME, sim)
		_fx.buzz(Haptics.GOOD)
		_show_banner(tr("CHANCE_GO"), "", 1.0)
		_play_events()
		top_bar.refresh(self))
	card.declined.connect(_game_over)
	add_child(card)
	return true
