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
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Analytics = preload("res://core/analytics.gd")

const GAME := "molehill"
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
const LAWN := Color("a9cf78")
const LAWN_STRIPE := Color("9cc46c")
const LAWN_DEEP := Color("86b35a")
const HEDGE := Color("5f8f4a")
const HEDGE_DEEP := Color("4a7a3c")
const PETALS := [Color("f4a7a0"), Color("fbe3a0"), Color("c7a6d8"), Color("fff6ea")]
const TIME_GOOD := Color("7fa84a")
const TIME_LATE := Color("e2645c")
const FRENZY_TINT := Color("ffcf6a")

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
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
## Numbers rising off a whack: {pos, text, t, col, big}.
var _pops: Array = []
## When each hill last took a whack, for the squash (and a pot's clang).
var _hit_at: Array = []
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _seat: Control

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
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	_new_game()

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
	for i in Sim.HILLS:
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
	field.add_child(_fx)

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
	_apply_insets()

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
	_u = minf(s.x / Sim.W, s.y / Sim.H)
	_origin = Vector2((s.x - Sim.W * _u) * 0.5, (s.y - Sim.H * _u) * 0.5)
	_lawn = _build_lawn()
	var lb := Face.Builder.new()
	Art.mound_front(lb, Vector2.ZERO, _u)
	_lip = lb.mesh()
	for i in Sim.HILLS:
		var h := px(Sim.hill_pos(i))
		var clip: Control = _views[i].clip
		var half := Sim.W / Sim.COLS * 0.5 * _u
		clip.position = Vector2(h.x - half, h.y - 110.0 * _u)
		clip.size = Vector2(half * 2.0, 110.0 * _u + 8.0 * _u)
		var lip: Control = _views[i].lip
		lip.position = h
		lip.size = Vector2.ZERO
	var box: Control = _banner.get_meta("box")
	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2(0, s.y * 0.36)
	box.size.x = s.x
	_redraw_all()

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
	_acc = 0.0
	_paused = false
	_mallets.clear()
	_bursts.clear()
	_pops.clear()
	for i in Sim.HILLS:
		_hit_at[i] = -10.0
	_shake = 0.0
	_roll = 0.0
	_beat_best = false
	_best = Record.best(GAME)
	_shown_score = -1
	_started_at = Time.get_ticks_msec()
	if _pause_card != null:
		_pause_card.queue_free()
		_pause_card = null
	_refresh_hud()
	top_bar.refresh(self)
	_fx.cue("start")
	Analytics.track("arcade_start", {"game": GAME})

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
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	_redraw_all()

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
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 12.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO

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
	var i: int = Sim.hill_at(p)
	var got: String = sim.whack(i)
	var where := p
	if got != "miss" and i >= 0:
		where = Sim.hill_pos(i) + Vector2(0, -44.0)
	_mallets.append({"pos": where, "t": 0.0, "hit": got != "miss"})
	if got == "miss" and i < 0:
		_fx.cue("miss", randf_range(0.9, 1.1), -4.0)
		_burst(p, LAWN_DEEP, false)
	_play_events()

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
		var top := Sim.hill_pos(hill) + Vector2(0, -44.0) if hill >= 0 else Vector2.ZERO
		match String(ev.type):
			"ready":
				_show_banner(tr("MH_READY"), tr("MH_READY_LINE"), 1.1)
			"go":
				_show_banner(tr("MH_GO"), "", 0.4)
				_fx.cue("go")
			"up":
				_fx.cue("pop_up", randf_range(0.92, 1.12), -8.0)
			"hit":
				_hit_at[hill] = _clock
				var kind: int = ev.kind
				var gold := kind == Sim.Kind.GOLD
				_fx.cue("whack_gold" if gold else ("crack" if kind == Sim.Kind.POT else "whack"), randf_range(0.94, 1.08))
				_burst(Sim.hill_pos(hill) + Vector2(0, -6.0), Art.SOIL_HI, gold or kind == Sim.Kind.POT)
				if gold:
					_fx.sparkle(px(top), Art.GOLD)
				if kind == Sim.Kind.POT:
					_fx.puff(px(top + Vector2(0, -14.0)), Art.POT, 7)
				_pops.append({"pos": top + Vector2(0, -16.0), "text": "+%d" % ev.points, "t": 0.0,
					"col": Pal.SUN if gold or ev.quick else Color("fffaf0"), "big": gold})
				_shake = maxf(_shake, 0.35 if gold else 0.2)
			"clang":
				_hit_at[hill] = _clock
				_fx.cue("clang", randf_range(0.95, 1.05))
				_fx.sparkle(px(top + Vector2(0, -16.0)), Art.POT_RIM)
				_shake = maxf(_shake, 0.2)
			"bunny":
				_hit_at[hill] = _clock
				_fx.cue("bunny")
				_pops.append({"pos": top + Vector2(0, -16.0), "text": "-%d" % Sim.BUNNY_COST, "t": 0.0, "col": Color("f4a7a0"), "big": true})
				_shake = maxf(_shake, 0.6)
			"miss":
				_fx.cue("miss", randf_range(0.9, 1.1), -4.0)
				_burst(Sim.hill_pos(hill) + Vector2(0, 2.0), Art.SOIL, false)
			"escape":
				_fx.cue("escape", randf_range(0.95, 1.08), -6.0)
			"combo":
				_fx.cue("combo", 1.0 + 0.08 * (int(ev.mult) - 2))
				_pops.append({"pos": top + Vector2(0, -16.0), "text": tr("MH_COMBO") % ev.mult, "t": -0.25, "col": Pal.SUN, "big": true})
			"streak_lost":
				_fx.cue("streak_lost", 1.0, -3.0)
			"frenzy":
				_show_banner(tr("MH_FRENZY"), tr("MH_FRENZY_LINE"), 1.2)
				_fx.cue("frenzy")
			"tick":
				_fx.cue("tick", 1.0 + 0.06 * (5 - int(ev.left)))
				_time_l.pivot_offset = _time_l.size * 0.5
				Motion.bump(_time_l, 0.2, 0.25)
			"time_up":
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
	# the hedge along the top edge, scalloped, with blossom in it
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var hedge_h := maxf(_origin.y + 10.0 * _u, 26.0)
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
		for h in Sim.HILLS:
			var d := (p - px(Sim.hill_pos(h))) / _u
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
	for h in Sim.HILLS:
		Art.mound_back(b, px(Sim.hill_pos(h)), _u)
	return b.mesh()

func _draw_field() -> void:
	if _lawn == null:
		_layout_field()
	if _lawn != null:
		field.draw_mesh(_lawn, null)
	# the frenzy's warm pulse over the lawn
	if sim != null and sim.frenzy() and not Motion.reduce:
		var a := 0.07 + 0.05 * sin(_clock * 8.0)
		field.draw_rect(Rect2(Vector2.ZERO, field.size), Color(FRENZY_TINT, a))

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

func _draw_mole(i: int) -> void:
	if sim == null:
		return
	var clip: Control = _views[i].clip
	var h: Dictionary = sim.hills[i]
	if h.st == Sim.St.EMPTY:
		return
	var foot := Vector2(clip.size.x * 0.5, 110.0 * _u)
	var drop: float = (1.0 - sim.rise(i)) * Art.DEPTH * _u
	var sc := Vector2.ONE
	var rot := 0.0
	var off := Vector2.ZERO
	if not Motion.reduce:
		match int(h.st):
			Sim.St.RISE:
				sc = Vector2(0.92, 1.1)
			Sim.St.UP:
				var ph: float = _clock * 5.0 + i * 1.7
				sc.y *= 1.0 + 0.035 * sin(ph)
				rot = sin(_clock * 2.3 + i) * 0.05
				if h.kind != Sim.Kind.BUNNY and h.t > h.up * 0.72:
					rot = sin(_clock * 18.0) * 0.1
		var since: float = _clock - float(_hit_at[i])
		if since < 0.35:
			var k := since / 0.35
			var amt := 0.32 * (1.0 - k) * (1.0 - k)
			if h.st == Sim.St.BONKED or h.done:
				sc *= Vector2(1.0 + amt, 1.0 - amt)
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
	clip.draw_mesh(Art.mesh(_look(i), _u), null, Transform2D(rot, sc, 0.0, foot + Vector2(0, drop) + off), tint)
	clip.draw_set_transform(Vector2.ZERO)

func _draw_lip(i: int) -> void:
	if _lip != null:
		(_views[i].lip as Control).draw_mesh(_lip, null)

## Over everything: the time bar, the dirt, the dizzy stars,
## the mallets and the numbers.
func _draw_over() -> void:
	if sim == null:
		return
	var b := Face.Builder.new()
	_draw_time_bar(b)
	_draw_bursts(b)
	_draw_stars(b)
	if not b.verts.is_empty():
		_live = b.mesh()
		_over.draw_mesh(_live, null)
	for m: Dictionary in _mallets:
		_draw_mallet(m)
	_draw_pops()

## A bar along the top of the lawn that empties with the minute, leaf green
## to rose.
func _draw_time_bar(b: Face.Builder) -> void:
	var s := field.size
	var left: float = sim.time_left() / Sim.ROUND
	var at := Vector2(24.0, 18.0)
	var size := Vector2(s.x - 48.0, 16.0)
	b.fan(Face.Builder.round_rect(at, size, 8.0), Color(0.2, 0.3, 0.1, 0.35))
	if left > 0.0:
		var col := TIME_LATE.lerp(TIME_GOOD, clampf((left * Sim.ROUND - 5.0) / 20.0, 0.0, 1.0))
		b.fan(Face.Builder.round_rect(at + Vector2(2, 2), Vector2(maxf(12.0, (size.x - 4.0) * left), size.y - 4.0), 6.0), col)

func _draw_bursts(b: Face.Builder) -> void:
	for bu: Dictionary in _bursts:
		var k: float = bu.t / 0.5
		var n := 9 if bu.big else 6
		for j in n:
			var a := TAU * j / n + float(bu.seed)
			var dist := (18.0 + 10.0 * _hash(j, bu.seed)) * k * _u
			var lift := sin(k * PI) * 10.0 * _u
			var at := px(bu.pos) + Vector2(cos(a) * dist, sin(a) * dist * 0.45 - lift)
			b.disc(at + _shake_off, (3.2 - 2.0 * k) * _u * (1.3 if bu.big else 1.0), Color(bu.col, 1.0 - k))

## Stars circling a dizzy head.
func _draw_stars(b: Face.Builder) -> void:
	for i in Sim.HILLS:
		var h: Dictionary = sim.hills[i]
		if h.st != Sim.St.BONKED:
			continue
		var c := px(Sim.hill_pos(i) + Vector2(0, -62.0)) + _shake_off
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

## The mallet: raised to one side, swung down on the spot, a beat on the
## ground, lifted away fading.
func _draw_mallet(m: Dictionary) -> void:
	var t: float = m.t
	var impact := -0.55
	var ang := impact
	var alpha := 1.0
	if not Motion.reduce:
		if t < SWING:
			ang = impact + 0.95 * (1.0 - t / SWING)
		elif t > SWING + 0.1:
			var k := (t - SWING - 0.1) / (MALLET_LIFE - SWING - 0.1)
			ang = impact + 0.5 * k
			alpha = 1.0 - k
	else:
		alpha = 1.0 - t / MALLET_LIFE
	var head := px(m.pos)
	# The hand sits down and right of the head, so the head lands on the spot.
	var hand := head - Vector2(0, -Art.HEAD_AT * _u).rotated(impact)
	var squash := 1.0
	if t >= SWING and t < SWING + 0.08 and not Motion.reduce:
		squash = 0.9
	_over.draw_mesh(Art.mallet(_u), null, Transform2D(ang, Vector2(1.0, squash), 0.0, hand + _shake_off), Color(1, 1, 1, alpha))

func _draw_pops() -> void:
	var font := get_theme_font("font", "SheetTitle")
	for p: Dictionary in _pops:
		if p.t < 0.0:
			continue
		var a := 1.0 - clampf((p.t - 0.5) / 0.4, 0.0, 1.0)
		var at := px(p.pos) + Vector2(0, -p.t * 50.0)
		var big: bool = p.get("big", false)
		var full := 52 if big else 42
		var fs := full if Motion.reduce else maxi(8, int(lerpf(14.0, full, Motion.back_out(minf(1.0, p.t / 0.26)))))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_over.draw_string(font, at + Vector2(-w * 0.5 + 2, 3), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.12, 0.05, 0.5 * a))
		_over.draw_string(font, at + Vector2(-w * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.col, a))

## A pseudo-random 0..1 from two numbers, for bursts that must look the
## same every frame they are drawn.
static func _hash(a: float, b: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)

func _burst(at: Vector2, col: Color, big: bool) -> void:
	_bursts.append({"pos": at, "t": 0.0, "col": col, "big": big, "seed": randf() * 100.0})

# --- the end ---

func _time_up() -> void:
	var better := Record.add(GAME, sim.score, sim.best_streak)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.best_streak,
		"seconds": secs, "whacked": sim.whacked, "escaped": sim.escaped, "missed": sim.missed,
		"bunnies": sim.bunnies, "best": better})
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
	Motion.appear(_end, 0.0, 1.0, 0.3)
	_celebrate(better)

func _build_end(better: bool) -> Control:
	var scrim := ColorRect.new()
	scrim.color = Color(Pal.OUTLINE, 0.35)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 44, 40))
	card.custom_minimum_size.x = 820
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(0, 200)
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
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 170.0)
		seat.draw_mesh(halves[0], null, Transform2D(0.0, c))
		var bob := (0.5 + 0.5 * sin(t * 2.4)) * 10.0
		seat.draw_mesh(Art.mesh(Art.Look.MOLE_TEASE if better else Art.Look.MOLE, u), null,
			Transform2D(sin(t * 1.7) * 0.06, c + Vector2(0, bob)))
		seat.draw_mesh(halves[1], null, Transform2D(0.0, c)))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "MH_END_CARD"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var score := Label.new()
	score.text = Record.grouped(sim.score)
	score.theme_type_variation = "DayBig"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score)
	var line := Label.new()
	var acc := int(round(100.0 * sim.whacked / maxf(1.0, sim.taps)))
	line.text = "%s  ·  %s  ·  %s" % [tr("MH_WHACKED") % sim.whacked, tr("MH_BEST_STREAK") % sim.best_streak,
		tr("FF_ACCURACY") % acc]
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var best_line := Label.new()
	best_line.text = tr("FF_BEST_LINE") % Record.grouped(Record.best(GAME))
	best_line.theme_type_variation = "SheetBodyDim"
	best_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(best_line)
	var again := IconButton.new("reset", tr("FF_AGAIN"), "SunButton")
	again.name = "Again"
	again.custom_minimum_size.y = 120
	again.pressed.connect(_new_game)
	col.add_child(again)
	var back := IconButton.new("chevron_left", tr("FF_BACK"))
	back.custom_minimum_size.y = 110
	back.pressed.connect(_on_back)
	col.add_child(back)
	return scrim

func _celebrate(better: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not better:
		return
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
	_new_game()

func _on_back() -> void:
	if sim != null and not sim.is_over() and sim.score > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.best_streak})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
