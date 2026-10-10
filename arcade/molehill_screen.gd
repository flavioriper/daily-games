extends Control

## Molehill: the third game on the Arcade tab, the whack-a-mole of the
## boardwalk cabinets re-dressed as a lawn (spec
## docs/superpowers/specs/2026-09-27-arcade-molehill-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the score, the best and the time left, and under them the lawn in
## a wooden frame: twelve molehills, three across and four down.
##
## Play: tap a mole while it is up. Every finger counts, so two thumbs can
## play. The game is arcade/molehill_sim.gd, stepped at its fixed DT; this
## screen draws it and plays its events.
##
## Drawing: the lawn and the back of every mound are one still mesh, built
## on resize. Each hill has two children of the field in row order, a
## clipping Control the mole stands in (its bottom edge is the hole's mouth,
## so a mole lowered by the transform sinks out of sight) and the mound's
## front lip over it; a row's moles then stand in front of the row behind.
## The mallets, the dirt, the stars and the numbers are one live mesh over
## all of it.

signal closed

const Sim = preload("res://arcade/molehill_sim.gd")
const Art = preload("res://arcade/molehill_art.gd")
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
## What the phone knocks for (docs/agents/haptics.md). A whack's cues come
## several to a frame (`whack`, `combo`, `streak_lost`) and `clang`, `combo`
## and `tick` are shared, so only the end card's is mapped: the events ask
## through `_feel` and the frame knocks once, with the strongest.
const HAPTICS := {"new_best": Haptics.WIN}
const Face = preload("res://ui/faces/face.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "molehill"
## No sound the screen pitches climbs past five semitones (the cozy rules).
const CLIMB_TOP := 1.335
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
## The most sim steps one frame may run, so a stall never fast-forwards.
const MAX_STEPS := 12
## How long a mallet's swing is drawn: down, a beat on the ground, lifted.
const SWING := 0.09
const MALLET_LIFE := 0.34
## The mallet's angle on the ground, and how far back it is raised.
const MALLET_IMPACT := -0.55
const MALLET_RAISE := 0.95
const LAWN := Color("a9cf78")
const LAWN_STRIPE := Color("9cc46c")
const LAWN_DEEP := Color("86b35a")
const HEDGE := Color("5f8f4a")
const HEDGE_DEEP := Color("4a7a3c")
const PETALS := [Color("f4a7a0"), Color("fbe3a0"), Color("c7a6d8"), Color("fff6ea")]
const TIME_GOOD := Color("7fa84a")
const TIME_LATE := Color("e2645c")
const FRENZY_TINT := Color("ffcf6a")
const CLOVER := Color("7fae52")
const IMPACT_LIFE := 0.2
## The highest a number's baseline may rise, clear of the time bar.
const POP_TOP := 96.0
## How high a mole peeks out before the round and after it, as a rise.
const PEEK := 0.58
const PEEK_OVER := 0.8
## A streak's word, by its length, loudest first.
const WORDS := [[40, "MH_WORD_6"], [30, "MH_WORD_5"], [20, "MH_WORD_4"], [15, "MH_WORD_3"], [10, "MH_WORD_2"], [5, "MH_WORD_1"]]
## Whacks this close together (seconds) are one flurry: Double!, Triple!
const FLURRY_GAP := 0.32
const FLURRY := ["", "", "MH_DOUBLE", "MH_TRIPLE", "MH_QUAD"]
const HEAT := Color("ffb03b")
const SHARD := Color("d9774a")
## The score lettered over the lawn as it passes each of these.
const MILESTONES := [250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 7500, 10000, 15000, 20000]

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
var _time_l: Label
## The score plate's kicker, which reads the streak while there is one.
var _score_k: Label
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
var _u := 3.0
var _origin := Vector2.ZERO
var _lawn: ArrayMesh
var _live: ArrayMesh
var _lip: ArrayMesh
## One a hill: {clip: Control, lip: Control}.
var _views: Array = []
## The screen's own clock, for motion the sim does not own; it stops with
## the pause.
var _clock := 0.0
## Mallets in flight: {pos (field units), t, hit}.
var _mallets: Array = []
## Dirt bursts: {pos, t, col, seed, big}.
var _bursts: Array = []
## Numbers rising off a whack: {pos, text, t, col, big, rays, drift}.
var _pops: Array = []
## Impact stars where a mallet lands on a head: {pos, t, gold}.
var _impacts: Array = []
## When each hill last took a whack, for the squash (and a pot's clang).
var _hit_at: Array = []
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _seat: Control
## The loud rewards over the whole screen (arcade/rewards.gd).
var _rw: Rewards
## Whacks in the current flurry, and when the last landed.
var _flurry := 0
var _last_whack := -10.0
## The warm glow a long streak lights round the lawn (0..1).
var _heat := 0.0
## The lawn's flash after a big moment, fading, and its colour.
var _flash := 0.0
var _flash_col := Color.WHITE
var _milestone := 0
## The last seconds, painted big on the lawn under the moles.
var _count_n := 0
var _count_at := -10.0
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
	tutor = ScreenTutor.new(self, puzzle_id(), "Molehill", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	# before any round: the boost card may stand first, and the bar would wear
	# the Undo and the bulb this game has not got until Play
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

	top_bar = FlatTopBar.new("Molehill", tr("MH_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void:
		_pause(true)
		settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())

	col.add_child(_build_frame())

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

## The wooden frame with the lawn in it: the field, a clip and a lip for each
## hill, the live layer and the effects. The tutorial's small lawn
## (ui/hud/molehill_tutorial_diagram.gd) is this and the plates, nothing else.
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
	for i in _hill_count():
		var clip := Control.new()
		clip.name = "Hill%d" % i
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.draw.connect(_draw_mole.bind(i))
		field.add_child(clip)
		var lip := Control.new()
		lip.name = "Lip%d" % i
		lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lip.draw.connect(_draw_lip.bind(i))
		field.add_child(lip)
		_views.append({"clip": clip, "lip": lip})
		_hit_at.append(-10.0)
	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	field.add_child(_over)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	field.add_child(_fx)

	return frame

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["FF_SCORE", "FF_BEST", "MH_TIME"]:
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
		if key == "FF_SCORE":
			_score_k = kicker
	_score_l = made[0]
	_best_l = made[1]
	_time_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The lawn is scaled to the room and centred: a phone is taller than the
## field, and the extra lawn goes half above and half below.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var units := _field_units()
	_u = minf(s.x / units.x, s.y / units.y)
	_origin = Vector2((s.x - units.x * _u) * 0.5, (s.y - units.y * _u) * 0.5)
	_lawn = _build_lawn()
	var lb := Face.Builder.new()
	Art.mound_front(lb, Vector2.ZERO, _u)
	_lip = lb.mesh()
	for i in _hill_count():
		var h := px(_hill_pos(i))
		var clip: Control = _views[i].clip
		var half := Sim.W / Sim.COLS * 0.5 * _u
		clip.position = Vector2(h.x - half, h.y - 110.0 * _u)
		clip.size = Vector2(half * 2.0, 110.0 * _u + 8.0 * _u)
		var lip: Control = _views[i].lip
		lip.position = h
		lip.size = Vector2.ZERO
	if _banner != null:
		var box: Control = _banner.get_meta("box")
		box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		box.position = Vector2(0, s.y * 0.36)
		box.size.x = s.x
	_redraw_all()

## The hills this lawn shows, where each one's hole is and the field they
## stand in, in field units: the sim's twelve, three across and four down. A
## tutorial page stands a single row of them.
func _hill_count() -> int:
	return Sim.HILLS

func _hill_pos(i: int) -> Vector2:
	return Sim.hill_pos(i)

func _field_units() -> Vector2:
	return Vector2(Sim.W, Sim.H)

func px(p: Vector2) -> Vector2:
	return _origin + p * _u

## A point in the field's pixels, in field units.
func unit(at: Vector2) -> Vector2:
	return (at - _origin) / _u

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
	_mallets.clear()
	_bursts.clear()
	_pops.clear()
	_impacts.clear()
	for i in Sim.HILLS:
		_hit_at[i] = -10.0
	_shake = 0.0
	_roll = 0.0
	_beat_best = false
	_flurry = 0
	_last_whack = -10.0
	_heat = 0.0
	_flash = 0.0
	_milestone = 0
	_count_n = 0
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

## The tutorial card's pages (ui/hud/screen_tutor.gd), each a small lawn
## played by this screen and the sim (ui/hud/molehill_tutorial_diagram.gd).
## Every number in the text is the sim's own.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/molehill_tutorial_diagram.gd")
	var pts: Dictionary = Sim.POINTS
	var steps := [
		[Diagram.Lesson.WHACK, "TUT_MOLEHILL_WHACK", tr("TUT_MOLEHILL_WHACK_BODY") % [pts[Sim.Kind.MOLE], Sim.QUICK]],
		[Diagram.Lesson.CAST, "TUT_MOLEHILL_CAST", tr("TUT_MOLEHILL_CAST_BODY") % [pts[Sim.Kind.GOLD], pts[Sim.Kind.POT]]],
		[Diagram.Lesson.RABBIT, "TUT_MOLEHILL_RABBIT", tr("TUT_MOLEHILL_RABBIT_BODY") % Sim.BUNNY_COST],
		[Diagram.Lesson.STREAK, "TUT_MOLEHILL_STREAK", tr("TUT_MOLEHILL_STREAK_BODY") % Sim.STEPS],
		[Diagram.Lesson.FRENZY, "TUT_MOLEHILL_FRENZY", tr("TUT_MOLEHILL_FRENZY_BODY") % [int(Sim.ROUND), int(Sim.FRENZY)]],
		[Diagram.Lesson.BOOSTS, "TUT_MOLEHILL_BOOSTS", tr("TUT_MOLEHILL_BOOSTS_BODY")],
		[Diagram.Lesson.HUD, "TUT_MOLEHILL_HUD", tr("TUT_MOLEHILL_HUD_BODY")],
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
	for v: Dictionary in _views:
		(v.clip as Control).queue_redraw()
		(v.lip as Control).queue_redraw()
	_over.queue_redraw()

func _animate(delta: float) -> void:
	for m: Dictionary in _mallets:
		m.t += delta
	_mallets = _mallets.filter(func(m: Dictionary) -> bool: return m.t < MALLET_LIFE)
	for bu: Dictionary in _bursts:
		bu.t += delta
	_bursts = _bursts.filter(func(bu: Dictionary) -> bool: return bu.t < 0.5)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 0.9)
	for im: Dictionary in _impacts:
		im.t += delta
	_impacts = _impacts.filter(func(im: Dictionary) -> bool: return im.t < IMPACT_LIFE)
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 12.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO
	_rw.bounds = Rect2(_rw.at(field, Vector2.ZERO), field.size)
	_rw.step(delta)
	var want := clampf((sim.streak - 4) / 16.0, 0.0, 1.0) if sim.phase == Sim.Phase.PLAY else 0.0
	_heat = move_toward(_heat, want, delta * (1.5 if want > _heat else 0.8))
	_flash = maxf(0.0, _flash - delta * 2.6)

func _on_field_input(event: InputEvent) -> void:
	var at := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
	if at == Vector2.INF:
		return
	if _paused:
		if _end == null and not settings_sheet.is_open():
			_pause(false)
		return
	tap(unit(at))

## A tap at a point of the field, in field units: the mallet comes down
## there (on the mole's head when it lands on one) and the sim is told.
func tap(p: Vector2) -> void:
	if sim == null or sim.phase != Sim.Phase.PLAY:
		return
	swing(Sim.hill_at(p), p)

## The mallet down at `p` on hill `i` (-1: on no hill).
func swing(i: int, p: Vector2) -> void:
	var got: String = sim.whack(i)
	var where := p
	if got != "miss" and i >= 0:
		where = _hill_pos(i) + Vector2(0, -44.0)
	var ground := _hill_pos(i) if got != "miss" and i >= 0 else p
	_mallets.append({"pos": where, "ground": ground, "t": 0.0, "hit": got != "miss"})
	if got == "miss" and i < 0:
		_fx.cue("miss", randf_range(0.94, 1.06), -4.0)
		_burst(p, LAWN_DEEP, false)
	_play_events()

## The tutorial card stops the run and leaves it paused, a tap from going on.
func _tutor_hold(on: bool) -> void:
	if on and sim != null and not sim.is_over() and _end == null:
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
	line.text = "FF_RESUME"
	line.theme_type_variation = "SheetTitle"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_color_override("font_color", Color("fffaf0"))
	col.add_child(line)
	return scrim

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		var hill: int = ev.get("hill", -1)
		var top := _hill_pos(hill) + Vector2(0, -44.0) if hill >= 0 else Vector2.ZERO
		match String(ev.type):
			"ready":
				_show_banner(tr("MH_READY"), tr("MH_READY_LINE"), 1.1)
			"go":
				_show_banner(tr("MH_GO"), "", 0.4)
				_fx.cue("go")
			"up":
				_fx.cue("pop_up", randf_range(0.94, 1.06), -8.0)
				_burst(_hill_pos(hill) + Vector2(0, -3.0), Art.SOIL_HI, false, 0.6)
			"hit":
				_hit_at[hill] = _clock
				var kind: int = ev.kind
				var gold := kind == Sim.Kind.GOLD
				_fx.cue("whack_gold" if gold else ("crack" if kind == Sim.Kind.POT else "whack"), randf_range(0.94, 1.06))
				_burst(_hill_pos(hill) + Vector2(0, -6.0), Art.SOIL_HI, gold or kind == Sim.Kind.POT)
				if gold:
					_fx.sparkle(px(top), Art.GOLD)
				if kind == Sim.Kind.POT:
					_fx.puff(px(top + Vector2(0, -14.0)), Art.POT, 7)
				_pop(top + Vector2(0, -16.0), "+%d" % ev.points, Pal.SUN if gold or ev.quick else Color("fffaf0"), gold)
				_impacts.append({"pos": top + Vector2(0, -10.0), "t": 0.0, "gold": gold})
				if gold:
					_fx.ring(px(top), 34.0 * _u, Art.GOLD)
				_shake = maxf(_shake, 0.35 if gold else 0.2)
				# the mallet on a head; only the golden mole is more
				_feel(Haptics.BUMP if gold else Haptics.TAP)
				_on_hit(hill, kind, bool(ev.quick))
			"clang":
				_hit_at[hill] = _clock
				_fx.cue("clang", randf_range(0.95, 1.05))
				_feel(Haptics.TAP)
				_fx.sparkle(px(top + Vector2(0, -16.0)), Art.POT_RIM)
				_impacts.append({"pos": top + Vector2(0, -20.0), "t": 0.0, "gold": false})
				_shake = maxf(_shake, 0.2)
				_rw.spray(_in_rw(top + Vector2(0, -20.0)), SHARD, 4, 460.0, "shard", 0.8)
				_rw.spray(_in_rw(top + Vector2(0, -20.0)), Color("fffaf0"), 3, 380.0, "spark", 0.8)
				_rw.sticker(tr("MH_CLANG"), _in_rw(top + Vector2(0, -40.0)), 46, 0.8, false, Art.POT_RIM, false, "clang%d" % hill, 30.0)
			"bunny":
				_hit_at[hill] = _clock
				_fx.cue("bunny")
				_feel(Haptics.BAD)
				_pop(top + Vector2(0, -16.0), "-%d" % Sim.BUNNY_COST, Color("f4a7a0"), true)
				_fx.puff(px(top + Vector2(0, -20.0)), Color("f4a7a0"), 6)
				_shake = maxf(_shake, 0.6)
				_rw.sticker(tr("MH_NOT_BUNNY"), _in_rw(top + Vector2(0, -52.0)), 60, 1.4, false, Color("f4a7a0"), false, "bunny", 30.0)
				_rw.spray(_in_rw(top + Vector2(0, -24.0)), Color("f4a7a0"), 8, 480.0, "heart", 1.0)
				_rw.spray(_in_rw(top + Vector2(0, -24.0)), Art.CARROT, 3, 420.0, "shard", 0.8)
				_flash_now(Color("f4a7a0"), 0.35)
			"miss":
				_fx.cue("miss", randf_range(0.94, 1.06), -4.0)
				_burst(_hill_pos(hill) + Vector2(0, 2.0), Art.SOIL, false)
			"escape":
				_fx.cue("escape", randf_range(0.94, 1.06), -6.0)
				# the raspberry it blows on its way down
				_fx.puff(px(top + Vector2(3.0, 22.0)), Color("fffaf0"), 4)
			"combo":
				# a tick a semitone a step, five in all
				_fx.cue("combo", minf(pow(2.0, (int(ev.mult) - 2) / 12.0), CLIMB_TOP))
				_feel(Haptics.BUMP)
				_on_combo(hill, int(ev.mult))
				_score_k.pivot_offset = _score_k.size * 0.5
				Motion.bump(_score_k, 0.3, 0.35)
			"forgiven":
				# Steady hand (arcade/boosters.gd) kept the streak
				_fx.cue("clang", 1.2, -6.0)
				_feel(Haptics.GOOD)
				var where := top + Vector2(0, -40.0) if hill >= 0 else Vector2(Sim.W * 0.5, Sim.H * 0.5)
				_rw.sticker(tr("BST_STEADY_POP"), _in_rw(where), 54, 1.0, false, Pal.GOOD, false, "steady", 30.0)
			"streak_lost":
				_fx.cue("streak_lost", 1.0, -3.0)
				_feel(Haptics.WARN)
				Motion.shiver(_score_k)
				if String(ev.why) != "bunny":
					var where := top + Vector2(0, -40.0) if hill >= 0 else Vector2(Sim.W * 0.5, Sim.H * 0.5)
					_rw.sticker(tr("MH_TOO_SLOW") if String(ev.why) == "escape" else tr("MH_OOPS"), _in_rw(where), 54, 1.1, false,
						Color("c9c2d6"), false, "lost", 30.0)
			"frenzy":
				_show_banner(tr("MH_FRENZY"), tr("MH_FRENZY_LINE"), 1.2)
				_fx.cue("frenzy")
				_flash_now(FRENZY_TINT, 0.5)
				_rw.rain(1.8, ["confetti", "star"], [FRENZY_TINT, Pal.SUN, Color("f4a7a0"), Color("fffaf0")])
			"tick":
				_fx.cue("tick", 1.0 + 0.06 * (5 - int(ev.left)))
				_time_l.pivot_offset = _time_l.size * 0.5
				Motion.bump(_time_l, 0.2, 0.25)
				_count_n = int(ev.left)
				_count_at = _clock
			"time_up":
				# the bell: the whacks after it land on nothing
				_feel(Haptics.THUD)
				_time_up()
	sim.events.clear()

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
## best follows it once passed. The clock reads whole seconds, and goes
## rose in the last ten.
func _refresh_hud(delta := 0.0) -> void:
	if sim == null:
		return
	if sim.score != _shown_score:
		if sim.score > _shown_score and _shown_score >= 0:
			_score_l.pivot_offset = _score_l.size * 0.5
			Motion.bump(_score_l, 0.14, 0.26)
		_shown_score = sim.score
		if not _beat_best and _best > 0 and sim.score > _best:
			_beat_best = true
			_best_l.pivot_offset = _best_l.size * 0.5
			Motion.bump(_best_l, 0.3, 0.4)
			_new_best_passed()
		_score_moments()
	if Motion.reduce or sim.score < _roll:
		_roll = sim.score
	else:
		_roll = move_toward(_roll, sim.score, maxf(delta * absf(sim.score - _roll) * 10.0, delta * 300.0))
	var shown := Record.grouped(int(_roll))
	if _score_l.text != shown:
		_score_l.text = shown
		_best_l.text = Record.grouped(maxi(_best, int(_roll)))
	var kick := "FF_SCORE"
	if sim.streak >= 2:
		kick = tr("MH_STREAK") % [sim.streak, sim.multiplier()]
	if _score_k.text != kick:
		_score_k.text = kick
		if sim.multiplier() > 1:
			_score_k.add_theme_color_override("font_color", Pal.PUMPKIN_DEEP)
		else:
			_score_k.remove_theme_color_override("font_color")
	var secs := str(int(ceilf(sim.time_left())))
	if _time_l.text != secs:
		_time_l.text = secs
		var late: bool = sim.time_left() <= Sim.FRENZY and sim.phase == Sim.Phase.PLAY
		if late:
			_time_l.add_theme_color_override("font_color", TIME_LATE)
		else:
			_time_l.remove_theme_color_override("font_color")

# --- drawing ---

## The still lawn, built on resize: mown stripes, a hedge along the top
## with flowers in it, tufts and daisies, and the back of every mound.
func _build_lawn() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), LAWN)
	# mown stripes, diagonal, as a mower leaves them
	var w := 70.0
	var k := -int(s.y / w) - 1
	while k * w < s.x + s.y:
		if k % 2 == 0:
			var x0 := k * w
			b.fan(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + w, 0), Vector2(x0 + w - s.y * 0.35, s.y), Vector2(x0 - s.y * 0.35, s.y)]), Color(LAWN_STRIPE, 0.55))
		k += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# sunlit patches, soft and wide, and clover in the shade between them
	for i in 5:
		var c := Vector2(rng.randf() * s.x, rng.randf_range(0.15, 0.95) * s.y)
		b.ellipse(c, rng.randf_range(120.0, 200.0), rng.randf_range(50.0, 80.0), Color(1, 1, 0.85, 0.07))
	for i in 14:
		var c := Vector2(rng.randf() * s.x, rng.randf_range(0.12, 1.0) * s.y)
		for q in 3:
			b.disc(c + Vector2.from_angle(TAU * q / 3.0 - PI * 0.5) * 6.0, 6.0, CLOVER)
			b.disc(c + Vector2.from_angle(TAU * q / 3.0 - PI * 0.5) * 6.0 + Vector2(-1.5, -1.5), 2.4, Color(1, 1, 1, 0.12))
	# the hedge along the top edge, scalloped, with blossom in it, and the
	# shade it throws on the lawn
	var hedge_h := maxf(_origin.y + 10.0 * _u, 26.0)
	var shade := Color(0.2, 0.3, 0.1, 0.22)
	var clear := Color(0.2, 0.3, 0.1, 0.0)
	_quad(b, [Vector2(0, hedge_h), Vector2(s.x, hedge_h), Vector2(s.x, hedge_h + 90.0), Vector2(0, hedge_h + 90.0)], [shade, shade, clear, clear])
	b.fan(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, hedge_h), Vector2(0, hedge_h)]), HEDGE_DEEP)
	var n := int(s.x / 60.0) + 2
	for i in n:
		var c := Vector2(i * 60.0 - 10.0, hedge_h + rng.randf_range(-6.0, 2.0))
		b.ellipse(c + Vector2(0, 5), 40.0, 22.0, Color(HEDGE_DEEP, 0.9))
		b.ellipse(c, 38.0, 20.0, HEDGE)
		b.ellipse(c + Vector2(-8, -8), 16.0, 8.0, HEDGE.lightened(0.1))
	for i in n * 2:
		var c := Vector2(rng.randf() * s.x, rng.randf_range(6.0, hedge_h + 8.0))
		var col: Color = PETALS[i % PETALS.size()]
		for p in 5:
			b.disc(c + Vector2.from_angle(TAU * p / 5.0 + i) * 4.5, 3.8, col)
		b.disc(c, 2.6, Color("fbe3a0") if col != Color("fbe3a0") else Color("f4a7a0"))
	# tufts and daisies scattered over the lawn, clear of the hills
	for i in 60:
		var p := Vector2(rng.randf() * s.x, rng.randf_range(hedge_h + 20.0, s.y))
		var near := false
		for h in _hill_count():
			var d := (p - px(_hill_pos(h))) / _u
			if absf(d.x) < 52.0 and d.y > -22.0 and d.y < 30.0:
				near = true
		if near:
			continue
		if i % 5 == 0:
			for q in 5:
				b.disc(p + Vector2.from_angle(TAU * q / 5.0) * 5.0, 4.0, Color("fffaf0"))
			b.disc(p, 3.0, Color("f2c14e"))
		else:
			for q in 3:
				var tip := p + Vector2((q - 1) * 6.0, -14.0 - q % 2 * 5.0)
				b.stroke(PackedVector2Array([p + Vector2((q - 1) * 2.0, 0), tip]), 3.0, LAWN_DEEP)
	# the lawn darkens a little toward the frame
	var dim := Color(0.18, 0.25, 0.08, 0.16)
	var e := 60.0
	_quad(b, [Vector2(0, s.y), Vector2(e, s.y - e), Vector2(s.x - e, s.y - e), s], [dim, clear, clear, dim])
	_quad(b, [Vector2(0, hedge_h), Vector2(e, hedge_h), Vector2(e, s.y - e), Vector2(0, s.y)], [dim, clear, clear, dim])
	_quad(b, [Vector2(s.x, hedge_h), Vector2(s.x, s.y), Vector2(s.x - e, s.y - e), Vector2(s.x - e, hedge_h)], [dim, dim, clear, clear])
	for h in _hill_count():
		Art.mound_back(b, px(_hill_pos(h)), _u)
	return b.mesh()

func _draw_field() -> void:
	if _lawn == null:
		_layout_field()
	if _lawn != null:
		field.draw_mesh(_lawn, null)
	_draw_count()

## The last seconds, a numeral painted big on the lawn under the moles:
## thumped in, then fading.
func _draw_count() -> void:
	var since := _clock - _count_at
	if _count_n <= 0 or since > 1.0 or sim == null or sim.phase != Sim.Phase.PLAY:
		return
	var font := CozyTheme.display(700)
	var fs := 420
	var text := str(_count_n)
	var sc := 1.0 if Motion.reduce else lerpf(1.6, 1.0, Motion.back_out(minf(1.0, since / 0.25)))
	var a := 1.0 - clampf((since - 0.55) / 0.45, 0.0, 1.0)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	field.draw_set_transform(field.size * 0.5, 0.0, Vector2(sc, sc))
	var o := Vector2(-w * 0.5, fs * 0.36)
	var col := TIME_LATE.lerp(Color("f08a3c"), (_count_n - 1) / 4.0)
	field.draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 36, Color(Color("fffaf0"), 0.5 * a))
	field.draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(col.darkened(0.35), 0.6 * a))
	field.draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.6 * a))
	field.draw_set_transform(Vector2.ZERO)

## Which look a hill's creature wears now.
func _look(i: int) -> int:
	var h: Dictionary = sim.hills[i]
	var bonked: bool = h.st == Sim.St.BONKED or (h.st == Sim.St.SINK and h.done)
	match int(h.kind):
		Sim.Kind.GOLD:
			return Art.Look.GOLD_DIZZY if bonked else Art.Look.GOLD
		Sim.Kind.POT:
			if bonked:
				return Art.Look.POT_DIZZY
			return Art.Look.POT_CRACKED if h.hp < 2 else Art.Look.POT
		Sim.Kind.BUNNY:
			return Art.Look.BUNNY_DIZZY if bonked else Art.Look.BUNNY
	if bonked:
		return Art.Look.MOLE_DIZZY
	# A mole about to get away sticks its tongue out.
	if (h.st == Sim.St.UP and h.t > h.up * 0.72) or (h.st == Sim.St.SINK and not h.done):
		return Art.Look.MOLE_TEASE
	return Art.Look.MOLE

## Where a hill's creature is looking, -1, 0 or 1: each looks about on its
## own clock, never under reduce motion.
func _gaze(i: int) -> int:
	if Motion.reduce:
		return 0
	var v := sin(_clock * 0.9 + i * 2.3)
	return 1 if v > 0.45 else (-1 if v < -0.45 else 0)

func _blinks(i: int) -> bool:
	return not Motion.reduce and fmod(_clock + i * 0.61, 3.1) < 0.11

## A mesh for a look, turned and blinking when the look has open eyes.
func _mesh_for(look: int, i: int) -> ArrayMesh:
	if look in [Art.Look.MOLE, Art.Look.GOLD, Art.Look.POT, Art.Look.BUNNY]:
		return Art.mesh(look, _u, _gaze(i), _blinks(i))
	return Art.mesh(look, _u)

## An empty hill's peek: before the round every mole peeks out to look
## about and ducks on the go; after it they come up to jeer. 0 is hidden.
func _peek(i: int) -> float:
	var ease := func(k: float) -> float: return k if Motion.reduce else Motion.back_out(k)
	match sim.phase:
		Sim.Phase.READY:
			var k := clampf((sim.phase_t - 0.3 - _hash(i, 3.0) * 0.8) / 0.22, 0.0, 1.0)
			return PEEK * ease.call(k)
		Sim.Phase.PLAY:
			if sim.phase_t < 0.14:
				return PEEK * (1.0 - sim.phase_t / 0.14)
		Sim.Phase.OVER:
			var k := clampf((sim.phase_t - 0.35 - _hash(i, 5.0) * 0.5) / 0.2, 0.0, 1.0)
			return PEEK_OVER * ease.call(k)
	return 0.0

func _draw_mole(i: int) -> void:
	if sim == null:
		return
	var clip: Control = _views[i].clip
	var h: Dictionary = sim.hills[i]
	var foot := Vector2(clip.size.x * 0.5, 110.0 * _u)
	if h.st == Sim.St.EMPTY:
		var peek := _peek(i)
		if peek <= 0.0:
			return
		var jeer: bool = sim.phase == Sim.Phase.OVER
		var tilt := 0.0 if Motion.reduce else sin(_clock * (7.0 if jeer else 2.0) + i) * (0.1 if jeer else 0.05)
		var look := _mesh_for(Art.Look.MOLE, i) if not jeer else Art.mesh(Art.Look.MOLE_TEASE, _u)
		clip.draw_set_transform(_shake_off, 0.0, Vector2.ONE)
		clip.draw_mesh(look, null, Transform2D(tilt, foot + Vector2(0, (1.0 - peek) * Art.DEPTH * _u)))
		clip.draw_set_transform(Vector2.ZERO)
		return
	var drop: float = (1.0 - sim.rise(i)) * Art.DEPTH * _u
	var sc := Vector2.ONE
	var rot := 0.0
	var off := Vector2.ZERO
	if not Motion.reduce:
		match int(h.st):
			Sim.St.RISE:
				# stretched thin as it shoots out of the hole
				sc = Vector2(0.86, 1.16)
			Sim.St.UP:
				# the pop's overshoot, then breathing and looking about
				var k := clampf(h.t / 0.24, 0.0, 1.0)
				var pop := sin(k * PI) * (1.0 - k)
				sc = Vector2(1.0 + 0.14 * pop, 1.0 - 0.12 * pop)
				var ph: float = _clock * 5.0 + i * 1.7
				sc.y *= 1.0 + 0.035 * sin(ph)
				rot = sin(_clock * 2.3 + i) * 0.05
				if h.kind != Sim.Kind.BUNNY and h.t > h.up * 0.72:
					rot = sin(_clock * 18.0) * 0.1
			Sim.St.SINK:
				# ducking: squeezed thin on the way down
				sc = Vector2(0.9, 1.08)
		var since: float = _clock - float(_hit_at[i])
		if since < 0.4:
			var k := since / 0.4
			if h.st == Sim.St.BONKED or h.done:
				# flattened like a pancake, springing back
				var wob := cos(k * PI * 2.5) * (1.0 - k) * (1.0 - k) * 0.42
				sc *= Vector2(1.0 + wob, 1.0 - wob)
			else:
				# a pot knocked but still on: a wobble
				rot += sin(since * 40.0) * 0.18 * (1.0 - k)
		if h.st == Sim.St.BONKED:
			rot += sin(_clock * 9.0) * 0.07
	var tint := Color.WHITE
	var since2: float = _clock - float(_hit_at[i])
	if since2 < 0.08:
		tint = Color(1.6, 1.6, 1.6)
	clip.draw_set_transform(_shake_off, 0.0, Vector2.ONE)
	clip.draw_mesh(_mesh_for(_look(i), i), null, Transform2D(rot, sc, 0.0, foot + Vector2(0, drop) + off), tint)
	clip.draw_set_transform(Vector2.ZERO)

## The mound's front lip, which heaves as a mole shoves out of the hole and
## flattens under a whack, about its foot.
func _draw_lip(i: int) -> void:
	if _lip == null:
		return
	var sc := Vector2.ONE
	if sim != null and not Motion.reduce:
		var h: Dictionary = sim.hills[i]
		if h.st == Sim.St.RISE:
			var heave := sin(clampf(h.t / Sim.RISE_TIME, 0.0, 1.0) * PI)
			sc = Vector2(1.0 + 0.03 * heave, 1.0 + 0.09 * heave)
		var since: float = _clock - float(_hit_at[i])
		if since < 0.25:
			var k := (1.0 - since / 0.25) * (1.0 - since / 0.25)
			sc *= Vector2(1.0 + 0.05 * k, 1.0 - 0.12 * k)
	var pivot := Vector2(0, (Art.MOUND.y + 4.0) * _u)
	var xf := Transform2D(0.0, sc, 0.0, pivot) * Transform2D(0.0, -pivot)
	(_views[i].lip as Control).draw_mesh(_lip, null, Transform2D(0.0, _shake_off) * xf)

## Over everything: the frenzy's glow, the time bar, the dirt, the mallets'
## shadows and smears, the impact stars, the dizzy stars, a butterfly, the
## mallets and the numbers.
func _draw_over() -> void:
	if sim == null:
		return
	var b := Face.Builder.new()
	_draw_glow(b)
	_draw_time_bar(b)
	_draw_bursts(b)
	_draw_swings(b)
	_draw_impacts(b)
	_draw_stars(b)
	_draw_butterfly(b)
	_draw_rays(b)
	if not b.verts.is_empty():
		_live = b.mesh()
		_over.draw_mesh(_live, null)
	for m: Dictionary in _mallets:
		_draw_mallet(m)
	_draw_pops()
	if _flash > 0.0:
		_over.draw_rect(Rect2(Vector2.ZERO, field.size), Color(_flash_col, _flash * 0.4))

## A quad with a colour at each corner, for the gradients.
static func _quad(b: Face.Builder, p: Array, c: Array) -> void:
	var i0 := b.vertex(p[0], c[0])
	var i1 := b.vertex(p[1], c[1])
	var i2 := b.vertex(p[2], c[2])
	var i3 := b.vertex(p[3], c[3])
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)

## The frenzy: a warm glow breathing in from the lawn's edges.
func _draw_glow(b: Face.Builder) -> void:
	if _heat > 0.01:
		var hb := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 9.0)
		Rewards.edge_glow(b, Rect2(Vector2.ZERO, field.size), HEAT.lerp(Color("ff6f61"), _heat), _heat, hb)
	if not sim.frenzy():
		return
	var s := field.size
	var beat := 0.5 + 0.5 * sin(_clock * 8.0) if not Motion.reduce else 0.6
	var edge := Color(FRENZY_TINT, 0.34 + 0.2 * beat)
	var none := Color(FRENZY_TINT, 0.0)
	var w := 90.0 + 30.0 * beat
	_quad(b, [Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x - w, w), Vector2(w, w)], [edge, edge, none, none])
	_quad(b, [Vector2(0, s.y), Vector2(w, s.y - w), Vector2(s.x - w, s.y - w), s], [edge, none, none, edge])
	_quad(b, [Vector2.ZERO, Vector2(w, w), Vector2(w, s.y - w), Vector2(0, s.y)], [edge, none, none, edge])
	_quad(b, [Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - w, s.y - w), Vector2(s.x - w, w)], [edge, edge, none, none])

## A bar along the top of the lawn that empties with the minute, leaf green
## to rose, a spark at its end; in the frenzy it runs with stripes.
func _draw_time_bar(b: Face.Builder) -> void:
	var s := field.size
	var left: float = minf(1.0, sim.time_left() / Sim.ROUND)
	var at := Vector2(24.0, 18.0)
	var size := Vector2(s.x - 48.0, 18.0)
	b.fan(Face.Builder.round_rect(at + Vector2(0, 2), size, 9.0), Color(0.15, 0.22, 0.08, 0.3))
	b.fan(Face.Builder.round_rect(at, size, 9.0), Color(0.2, 0.3, 0.1, 0.35))
	if left <= 0.0:
		return
	var col := TIME_LATE.lerp(TIME_GOOD, clampf((left * Sim.ROUND - 5.0) / 20.0, 0.0, 1.0))
	var fill := Vector2(maxf(14.0, (size.x - 4.0) * left), size.y - 4.0)
	var f0 := at + Vector2(2, 2)
	b.fan(Face.Builder.round_rect(f0, fill, 7.0), col)
	b.fan(Face.Builder.round_rect(f0 + Vector2(4, 2), Vector2(maxf(4.0, fill.x - 8.0), 4.0), 2.0), Color(1, 1, 1, 0.3))
	if sim.frenzy():
		var run := 0.0 if Motion.reduce else fmod(_clock * 60.0, 28.0)
		var x := f0.x - 28.0 + run
		while x < f0.x + fill.x:
			var x0 := clampf(x, f0.x + 4.0, f0.x + fill.x - 4.0)
			var x1 := clampf(x + 12.0, f0.x + 4.0, f0.x + fill.x - 4.0)
			if x1 - x0 > 1.0:
				b.fan(PackedVector2Array([Vector2(x0 + 5.0, f0.y), Vector2(x1 + 5.0, f0.y), Vector2(x1, f0.y + fill.y), Vector2(x0, f0.y + fill.y)]), Color(1, 1, 1, 0.22))
			x += 28.0
	# the spark at the fill's end, a little sun burning down the fuse
	var c := f0 + Vector2(fill.x - 4.0, fill.y * 0.5)
	var flick := 1.0 if Motion.reduce else 1.0 + 0.18 * sin(_clock * (30.0 if sim.frenzy() else 9.0))
	var spin := 0.0 if Motion.reduce else _clock * 2.0
	for k in 8:
		var a := spin + TAU * k / 8.0
		b.fan(PackedVector2Array([c + Vector2.from_angle(a - 0.22) * 8.0, c + Vector2.from_angle(a) * 16.0 * flick, c + Vector2.from_angle(a + 0.22) * 8.0]), Color(Pal.SUN, 0.85))
	b.disc(c, 9.0 * flick, Pal.SUN)
	b.disc(c + Vector2(-2, -2), 4.0, Color("fff6c9"))

func _draw_bursts(b: Face.Builder) -> void:
	for bu: Dictionary in _bursts:
		var k: float = bu.t / 0.5
		var amt: float = bu.get("amount", 1.0)
		var n := 9 if bu.big else 6
		for j in n:
			var a := TAU * j / n + float(bu.seed)
			var dist := (18.0 + 10.0 * _hash(j, bu.seed)) * k * _u * amt
			var lift := sin(k * PI) * 10.0 * _u * amt
			var at := px(bu.pos) + Vector2(cos(a) * dist, sin(a) * dist * 0.45 - lift)
			var r := (3.2 - 2.0 * k) * _u * (1.3 if bu.big else 1.0) * lerpf(0.7, 1.0, amt)
			b.ellipse(at + _shake_off, r, r * 0.8, Color(bu.col, 1.0 - k))

## The mallet's angle at `t` into its swing: raised to one side, swung down
## on the spot, a beat on the ground, lifted away.
func _mallet_ang(t: float) -> float:
	if Motion.reduce:
		return MALLET_IMPACT
	if t < SWING:
		return MALLET_IMPACT + MALLET_RAISE * (1.0 - t / SWING)
	if t > SWING + 0.1:
		return MALLET_IMPACT + 0.5 * (t - SWING - 0.1) / (MALLET_LIFE - SWING - 0.1)
	return MALLET_IMPACT

func _mallet_hand(m: Dictionary) -> Vector2:
	# The hand sits down and right of the head, so the head lands on the spot.
	return px(m.pos) - Vector2(0, -Art.HEAD_AT * _u).rotated(MALLET_IMPACT)

## Under each mallet, its shadow on the ground closing in as it comes down;
## behind it, the smear of the swing.
func _draw_swings(b: Face.Builder) -> void:
	for m: Dictionary in _mallets:
		var t: float = m.t
		var ang := _mallet_ang(t)
		var close := 1.0 - clampf(absf(ang - MALLET_IMPACT) / MALLET_RAISE, 0.0, 1.0)
		var fade := 1.0 - clampf((t - SWING - 0.1) / (MALLET_LIFE - SWING - 0.1), 0.0, 1.0)
		var g := px(m.ground) + Vector2(0, 6.0 * _u)
		b.ellipse(g + _shake_off, (12.0 + 12.0 * close) * _u, (4.0 + 3.0 * close) * _u, Color(0.15, 0.08, 0.03, 0.2 * close * fade))
		if Motion.reduce or t > SWING + 0.06:
			continue
		var hand := _mallet_hand(m)
		var from := MALLET_IMPACT + MALLET_RAISE
		var to := ang
		var a := clampf(1.0 - t / (SWING + 0.06), 0.0, 1.0) * 0.4
		var pts := PackedVector2Array()
		var n := 8
		for k in n + 1:
			pts.append(hand + _shake_off + Vector2(0, -(Art.HEAD_AT + 16.0) * _u).rotated(lerpf(from, to, float(k) / n)))
		for k in range(n, -1, -1):
			pts.append(hand + _shake_off + Vector2(0, -(Art.HEAD_AT - 12.0) * _u).rotated(lerpf(from, to, float(k) / n)))
		b.polygon(pts, Color(1, 0.98, 0.9, a))

## The star a mallet makes landing on a head: a white burst with a sun in
## it, flung wide and gone.
func _draw_impacts(b: Face.Builder) -> void:
	for im: Dictionary in _impacts:
		var k: float = im.t / IMPACT_LIFE
		var grow := 1.0 if Motion.reduce else Motion.back_out(minf(1.0, k * 1.6))
		var c := px(im.pos) + _shake_off
		var r := lerpf(10.0, 30.0, grow) * _u * 0.5
		var a := 1.0 - k * k
		_burst_star(b, c, r * 1.25, Color(1, 1, 1, 0.9 * a), 0.4, k * 0.6)
		_burst_star(b, c, r * 0.7, Color(Art.GOLD if im.gold else Pal.SUN, a), 0.5, -k * 0.6)

static func _burst_star(b: Face.Builder, c: Vector2, r: float, col: Color, inner: float, turn: float) -> void:
	var pts := PackedVector2Array()
	for k in 16:
		var rr := r if k % 2 == 0 else r * inner
		pts.append(c + Vector2.from_angle(turn + TAU * k / 16.0) * rr)
	b.polygon(pts, col)

## Stars circling a dizzy head.
func _draw_stars(b: Face.Builder) -> void:
	for i in _hill_count():
		var h: Dictionary = sim.hills[i]
		if h.st != Sim.St.BONKED:
			continue
		var c := px(_hill_pos(i) + Vector2(0, -62.0)) + _shake_off
		var spin := 0.0 if Motion.reduce else _clock * 6.0
		for k in 3:
			var a := spin + TAU * k / 3.0
			var p := c + Vector2(cos(a) * 16.0 * _u, sin(a) * 5.0 * _u)
			_star(b, p, 3.4 * _u, Pal.SUN if k != 1 else Color("fffaf0"))

static func _star(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * k / 10.0) * rr)
	b.polygon(pts, col)

## A butterfly wandering along the hedge, clear of the moles.
func _draw_butterfly(b: Face.Builder) -> void:
	var t := 4.0 if Motion.reduce else _clock
	var w := field.size.x
	var hedge := maxf(_origin.y + 10.0 * _u, 26.0)
	var c := Vector2(w * (0.5 + 0.42 * sin(t * 0.23)), hedge + 12.0 + 14.0 * sin(t * 0.9) + 6.0 * sin(t * 2.3))
	var heading := signf(cos(t * 0.23)) if not Motion.reduce else 1.0
	var flap := 1.0 if Motion.reduce else 0.35 + 0.65 * absf(sin(t * 14.0))
	var r := 5.0 * _u
	for side in [-1.0, 1.0]:
		var x: float = side * flap
		b.ellipse(c + Vector2(x * r * 0.9, -r * 0.35), r * flap, r * 0.8, Color("f4a7a0"))
		b.ellipse(c + Vector2(x * r * 0.7, r * 0.5), r * 0.7 * flap, r * 0.55, Color("f7c6a0"))
		b.disc(c + Vector2(x * r * 0.9, -r * 0.4), r * 0.25 * flap, Color("fffaf0"))
	b.ellipse(c, r * 0.22, r * 0.75, Art.INK)
	b.stroke(PackedVector2Array([c + Vector2(0, -r * 0.6), c + Vector2(heading * r * 0.5, -r * 1.3)]), 0.25 * r, Art.INK)

## Rays turning behind a combo's number.
func _draw_rays(b: Face.Builder) -> void:
	for p: Dictionary in _pops:
		if not p.rays or p.t < 0.0:
			continue
		var a := 1.0 - clampf((p.t - 0.4) / 0.4, 0.0, 1.0)
		var c := _pop_at(p) + Vector2(0, -14.0)
		var grow := 1.0 if Motion.reduce else Motion.back_out(minf(1.0, p.t / 0.3))
		var spin: float = 0.0 if Motion.reduce else p.t * 1.6
		for k in 12:
			var ang: float = spin + TAU * k / 12.0
			b.fan(PackedVector2Array([c + Vector2.from_angle(ang - 0.1) * 22.0 * grow, c + Vector2.from_angle(ang) * 92.0 * grow, c + Vector2.from_angle(ang + 0.1) * 22.0 * grow]),
				Color(Pal.SUN if k % 2 == 0 else Color("fffaf0"), 0.45 * a))

## Where a number stands: risen quick at first, then drifting, and never
## up into the time bar.
func _pop_at(p: Dictionary) -> Vector2:
	var rise := 0.0 if p.t <= 0.0 else 64.0 * (1.0 - exp(-p.t * 4.5))
	var at := px(p.pos) + Vector2(p.drift * 18.0 * maxf(0.0, p.t), -rise)
	at.y = maxf(at.y, POP_TOP + (40.0 if p.rays else 0.0))
	return at

func _draw_mallet(m: Dictionary) -> void:
	var t: float = m.t
	var ang := _mallet_ang(t)
	var alpha := 1.0
	if Motion.reduce:
		alpha = 1.0 - t / MALLET_LIFE
	elif t > SWING + 0.1:
		alpha = 1.0 - (t - SWING - 0.1) / (MALLET_LIFE - SWING - 0.1)
	var squash := 1.0
	if t >= SWING and t < SWING + 0.08 and not Motion.reduce:
		squash = 0.86
	_over.draw_mesh(Art.mallet(_u), null, Transform2D(ang, Vector2(1.0, squash), 0.0, _mallet_hand(m) + _shake_off), Color(1, 1, 1, alpha))

## The numbers, lettered like stickers: an ink outline under the colour,
## popping big and settling, rising and drifting as they fade.
func _draw_pops() -> void:
	var font := get_theme_font("font", "SheetTitle")
	for p: Dictionary in _pops:
		if p.t < 0.0:
			continue
		var a := 1.0 - clampf((p.t - 0.5) / 0.4, 0.0, 1.0)
		var at := _pop_at(p)
		var big: bool = p.get("big", false)
		var full := 56 if big else 44
		var fs := full if Motion.reduce else maxi(8, int(lerpf(14.0, full * 1.0, Motion.back_out(minf(1.0, p.t / 0.24)))))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := at + Vector2(-w * 0.5, 0)
		_over.draw_string_outline(font, o + Vector2(0, 4), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0.2, 0.12, 0.05, 0.35 * a))
		_over.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(Art.INK, a))
		_over.draw_string(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.col, a))

## A pseudo-random 0..1 from two numbers, for bursts that must look the
## same every frame they are drawn.
static func _hash(a: float, b: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)

func _burst(at: Vector2, col: Color, big: bool, amount := 1.0) -> void:
	_bursts.append({"pos": at, "t": 0.0, "col": col, "big": big, "seed": randf() * 100.0, "amount": amount})

# --- the rewards ---

## A point of the lawn, in field units, in the rewards layer's pixels.
func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(field, px(p) + _shake_off)

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

## A whack's rewards: clods out of the hole and sparks off the head; a
## golden mole showers coins and flies stars home to the score; a pot
## breaks into shards; a quick one sparks gold. Whacks close together are a
## flurry (Double!, Triple!), and a streak's steps are worded.
func _on_hit(hill: int, kind: int, quick: bool) -> void:
	var head := _in_rw(_hill_pos(hill) + Vector2(0, -50.0))
	var hole := _in_rw(_hill_pos(hill) + Vector2(0, -4.0))
	var k := _u / 3.0
	_rw.spray(hole, Art.SOIL_HI, 6, 420.0, "clod", 0.9 * k)
	_rw.spray(head, Color("fffaf0"), 4, 420.0, "spark", 0.9 * k)
	if quick:
		_rw.spray(head, Pal.SUN, 3, 460.0, "star", 0.7 * k)
	match kind:
		Sim.Kind.GOLD:
			_rw.spray(head, Art.GOLD, 16, 760.0, "coin", 1.0 * k)
			_rw.spray(head, Pal.SUN, 4, 520.0, "star", 0.8, 0.1, _plate_at(_score_l))
			_rw.ring(head, 48.0 * _u, Color(Art.GOLD, 0.9))
			_rw.sticker(tr("MH_GOLDEN"), _in_rw(_hill_pos(hill) + Vector2(0, -80.0)), 60, 1.2, true, Color.WHITE, true, "gold%d" % hill, 30.0)
			_flash_now(Art.GOLD, 0.35)
		Sim.Kind.POT:
			_rw.spray(head, SHARD, 12, 640.0, "shard", 1.1 * k)
			_rw.spray(head, Art.POT_BAND, 5, 520.0, "shard", 0.8 * k)
			_rw.sticker(tr("MH_SMASH"), _in_rw(_hill_pos(hill) + Vector2(0, -80.0)), 56, 1.0, false, Art.POT_RIM, false, "smash%d" % hill, 30.0)
	# the flurry
	_flurry = _flurry + 1 if _clock - _last_whack <= FLURRY_GAP else 1
	_last_whack = _clock
	if _flurry >= 2:
		var word: String = FLURRY[mini(_flurry, FLURRY.size() - 1)]
		_rw.sticker(tr(word), _in_rw(_hill_pos(hill) + Vector2(0, -100.0)), 58 + 6 * mini(_flurry, 4), 1.0, true, Color.WHITE, _flurry >= 3, "flurry", 30.0)
		_rw.spray(head, Pal.SUN, 3 * _flurry, 600.0, "star", 0.9)
	# the streak's steps
	for i in WORDS.size():
		if sim.streak == int(WORDS[i][0]):
			var tier := WORDS.size() - 1 - i
			var at := _rw.at(field, field.size * Vector2(0.5, 0.42))
			_rw.sticker(tr(WORDS[i][1]), at, 72 + 8 * tier, 1.3 + 0.12 * tier, true, Color.WHITE, tier >= 1, "word", 24.0)
			_rw.spray(at, Pal.SUN, 6 + 3 * tier, 760.0, "star", 1.0)
			_rw.spray(at, Color("fffaf0"), 6 + 2 * tier, 620.0, "spark", 1.2)
			_rw.spray(at, Rewards.CONFETTI[tier % Rewards.CONFETTI.size()], 8 + 2 * tier, 700.0, "confetti", 1.0)
			_flash_now(Color("fffaf0"), 0.2 + 0.06 * tier)
			_shake = maxf(_shake, 0.25 + 0.06 * tier)
			_feel(Haptics.BUMP)
			if tier >= 3:
				_rw.rain(1.6, ["confetti", "star", "coin"], Rewards.CONFETTI)
			break

## The streak's multiplier steps up: its number lettered big over a
## sunburst, stars flying into the score's plate, the lawn flashing.
func _on_combo(hill: int, mult: int) -> void:
	var at := _rw.at(field, field.size * Vector2(0.5, 0.56))
	_rw.sticker(tr("MH_COMBO") % mult, at, 110 + 14 * (mult - 2), 1.4, true, Color.WHITE, true, "combo")
	_rw.sticker(tr("MH_POINTS_X") % mult, at + Vector2(0, 100.0 + 10.0 * (mult - 2)), 42, 1.4, false, Pal.SUN, false, "combo_line")
	_rw.spray(at, Pal.SUN, 10 + 4 * mult, 820.0, "star", 1.1)
	_rw.spray(_in_rw(_hill_pos(hill) + Vector2(0, -50.0)), Pal.SUN, 3 + mult, 520.0, "star", 0.8, 0.15, _plate_at(_score_l))
	_rw.ring(at, 260.0, Color(Pal.SUN, 0.9))
	_rw.ring(at, 180.0, Color("fffaf0", 0.9), 0.08)
	_flash_now(Pal.SUN, 0.3 + 0.08 * mult)

## The score passing a round number, and the best being passed: lettered,
## with stars out of the plate.
func _score_moments() -> void:
	var m := 0
	for v: int in MILESTONES:
		if sim.score >= v and v > _milestone:
			m = v
	if m > 0:
		_milestone = m
		_rw.sticker(Record.grouped(m) + "!", _rw.at(field, field.size * Vector2(0.5, 0.2)), 64, 1.2, true, Color.WHITE, false, "milestone")
		_rw.spray(_plate_at(_score_l), Pal.SUN, 10, 520.0, "star", 0.9)
		_rw.ring(_plate_at(_score_l), 140.0, Color(Pal.SUN, 0.9))

func _new_best_passed() -> void:
	_rw.sticker(tr("FF_NEW_BEST"), _rw.at(field, field.size * Vector2(0.5, 0.3)), 66, 1.8, true, Color.WHITE, true, "best")
	_rw.spray(_plate_at(_best_l), Pal.SUN, 14, 620.0, "star", 1.0)
	_rw.spray(_plate_at(_best_l), Art.GOLD, 10, 620.0, "coin", 1.0)
	_rw.ring(_plate_at(_best_l), 160.0, Color(Pal.SUN, 0.9))
	_rw.rain(1.6, ["confetti", "star"], Rewards.CONFETTI)
	_fx.cue("combo", 1.3, -3.0)
	_feel(Haptics.BUMP)

## The lawn flashes `col`, `amount` at most.
func _flash_now(col: Color, amount: float) -> void:
	if Motion.reduce:
		return
	_flash = maxf(_flash, amount)
	_flash_col = col

func _pop(at: Vector2, text: String, col: Color, big: bool) -> Dictionary:
	var p := {"pos": at, "text": text, "t": 0.0, "col": col, "big": big, "rays": false, "drift": randf_range(-1.0, 1.0)}
	_pops.append(p)
	return p

# --- the end ---

func _time_up() -> void:
	if _offer_chance():
		return
	var better := Record.add(GAME, sim.score, sim.best_streak, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.best_streak,
		"seconds": secs, "whacked": sim.whacked, "escaped": sim.escaped, "missed": sim.missed,
		"bunnies": sim.bunnies, "best": better})
	Ads.note_finished()
	_fx.cue("time_up")
	_show_banner(tr("MH_TIME_UP"), "", 1.2)
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
	# as tall as the mound's foot and clipped there, so the mole rising out
	# of the hole is hidden until it clears the lip
	seat.custom_minimum_size = Vector2(0, 226)
	seat.clip_contents = true
	# A mole on its mound, bobbing, cheeky with a new best. The mound's two
	# halves are built once at the origin and kept, so the canvas never
	# draws a freed mesh.
	var u := 2.4
	var back_b := Face.Builder.new()
	Art.mound_back(back_b, Vector2.ZERO, u)
	var front_b := Face.Builder.new()
	Art.mound_front(front_b, Vector2.ZERO, u)
	var halves := [back_b.mesh(), front_b.mesh()]
	seat.set_meta("keep", halves)
	var shown_at := _clock
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 170.0)
		# a sunburst turns behind the mound once the card is up, gold for a best
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.5) / 0.35, 0.0, 1.0)
		if glow > 0.0:
			var rb := Face.Builder.new()
			var rc := c + Vector2(0, -70.0)
			var rr := 200.0 * Motion.back_out(glow)
			rb.disc(rc, rr * 0.5, Color(Color("fff4c2"), 0.45))
			Rewards.sunrays(rb, rc, rr * 0.2, rr, 14, t * 0.5, Color(Art.GOLD if better else Pal.SUN, 0.5))
			Rewards.sunrays(rb, rc, rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
			var rm := rb.mesh()
			seat.set_meta("rays", rm)
			seat.draw_mesh(rm, null)
		seat.draw_mesh(halves[0], null, Transform2D(0.0, c))
		# it pops out of the hole once the card is up, then bobs about
		var since := _clock - shown_at
		var up := 1.0 if Motion.reduce else Motion.back_out(clampf((since - 0.3) / 0.3, 0.0, 1.0))
		var bob := (0.5 + 0.5 * sin(t * 2.4)) * 10.0
		var drop := (1.0 - up) * Art.DEPTH * u
		var look := Art.mesh(Art.Look.MOLE_TEASE, u) if better else Art.mesh(Art.Look.MOLE, u, 0 if Motion.reduce else roundi(sin(t * 0.8)), fmod(t, 2.8) < 0.12 and not Motion.reduce)
		seat.draw_mesh(look, null, Transform2D(sin(t * 1.7) * 0.06, c + Vector2(0, bob + drop)))
		seat.draw_mesh(halves[1], null, Transform2D(0.0, c)))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "MH_END_CARD"
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
	var acc := int(round(100.0 * sim.whacked / maxf(1.0, sim.taps)))
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 14)
	for pair in [[str(sim.whacked), "MH_STAT_WHACKED"], [str(sim.best_streak), "MH_STAT_STREAK"], ["%d%%" % acc, "MH_STAT_AIM"]]:
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

## The end card's score runs up from nothing to what the round made, with
## a burst of coins when it gets there.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 1.1, 0.0, 1.0)
	var shown := int(sim.score * (1.0 - pow(1.0 - k, 3.0)))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
		if int(_clock * 20.0) % 2 == 0:
			_fx.cue("combo", 1.0 + (CLIMB_TOP - 1.0) * k, -10.0)
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
	var cols := [Art.GOLD, Art.NOSE, Art.POT, Pal.FLOWER, Pal.SUN_RAY, TIME_GOOD]
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
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.best_streak})
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
	card.declined.connect(_time_up)
	add_child(card)
	return true
