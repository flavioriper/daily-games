extends Control

## Firefly: the first game on the Arcade tab, a formation shooter after the
## 1981 arcade genre, re-dressed as a night garden (spec
## docs/superpowers/specs/2026-09-27-arcade-firefly-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the score, the best and the stage, and under them the field: a
## night sky over the garden's hedges in a wooden frame.
##
## Play: put a finger anywhere on the field and slide it; the firefly
## follows the slide (not the finger's spot, so the thumb never hides it)
## and fires while the finger is down. On a keyboard, the arrows or A and D
## move and space fires. The game is arcade/firefly_sim.gd, stepped at its
## fixed DT; this screen draws it and plays its events.

signal closed

const Sim = preload("res://arcade/firefly_sim.gd")
const Art = preload("res://arcade/firefly_art.gd")
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

const GAME := "firefly"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
## A slide of the finger moves the firefly this much further than the
## finger went, so a thumb crosses the field without leaving its corner.
const GAIN := 1.35
## The most sim steps one frame may run, so a stall never fast-forwards.
const MAX_STEPS := 12
const SKY_TOP := Color("1d2147")
const SKY_LOW := Color("4a3f6e")
const HEDGE := Color("1f3a3a")
const HEDGE_FAR := Color("2c4a52")
const STAR := Color("fff6c9")
const SHOT := Color("fff1a8")
const BULLET := Color("f4a7a0")
const BEAM := Color("d9dcff")

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var field: Control
var _fx: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _score_l: Label
var _best_l: Label
var _stage_l: Label
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
## The finger: where it went down and where the firefly was then.
var _touch := -1
var _touch_from := Vector2.ZERO
var _ship_from := 0.0
var _mouse := false
## Pixels a field unit, and where the field's origin lands in `field`.
var _u := 4.0
var _origin := Vector2.ZERO
var _sky: ArrayMesh
var _live: ArrayMesh
var _beam_voice: AudioStreamPlayer
var _pops: Array = []   # {pos, text, t}

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
	_backdrop = Vistas.board_plate(GAME, Pal.MOON_INK)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_backdrop)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Firefly", tr("FF_MOTTO"), true)
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
	_banner.add_theme_color_override("font_color", Color("fff1d6"))
	_banner.add_theme_color_override("font_shadow_color", Color(0.1, 0.08, 0.2, 0.6))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	over.add_child(_banner)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetTitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Color("e9ecfa"))
	over.add_child(_sub)
	over.modulate.a = 0.0
	_banner.set_meta("box", over)

	_beam_voice = AudioStreamPlayer.new()
	add_child(_beam_voice)
	var beam_path := "res://assets/sfx/firefly/beam.ogg"
	if ResourceLoader.exists(beam_path):
		var stream: AudioStreamOggVorbis = (load(beam_path) as AudioStreamOggVorbis).duplicate()
		stream.loop = true
		_beam_voice.stream = stream
		_beam_voice.volume_db = -4.0
	_apply_insets()

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["FF_SCORE", "FF_BEST", "FF_STAGE"]:
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
	_stage_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The field is scaled to the room, width first: a phone is taller than the
## field, and the extra sky goes above the swarm.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_u = minf(s.x / Sim.W, s.y / Sim.H)
	_origin = Vector2((s.x - Sim.W * _u) * 0.5, s.y - Sim.H * _u)
	_sky = _build_sky()
	var box: Control = _banner.get_meta("box")
	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2(0, s.y * 0.34)
	box.size.x = s.x
	field.queue_redraw()

func px(p: Vector2) -> Vector2:
	return _origin + p * _u

# --- the game ---

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	sim = Sim.new()
	_acc = 0.0
	_paused = false
	_pops.clear()
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
		_hands()
		_acc += minf(delta, Sim.DT * MAX_STEPS)
		while _acc >= Sim.DT:
			_acc -= Sim.DT
			sim.step()
			_play_events()
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 0.9)
	_beam_sound()
	_refresh_hud()
	field.queue_redraw()

func _hands() -> void:
	var axis := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		axis += 1.0
	sim.axis = axis
	var keys := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP)
	sim.fire = keys or _touch != -1 or _mouse

func _on_field_input(event: InputEvent) -> void:
	if _paused:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			if _end == null and not settings_sheet.is_open():
				_pause(false)
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
	_ship_from = sim.px
	sim.target_x = sim.px

func _slide(at: Vector2) -> void:
	sim.target_x = _ship_from + (at.x - _touch_from.x) / _u * GAIN
	# A slide past the wall re-anchors, so coming back moves at once.
	var lo := Sim.PLAYER_R + 4.0
	var hi := Sim.W - lo
	if sim.target_x < lo or sim.target_x > hi:
		sim.target_x = clampf(sim.target_x, lo, hi)
		_touch_from = at
		_ship_from = sim.target_x

func _pause(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	_touch = -1
	_mouse = false
	if on:
		_pause_card = _build_pause()
		field.add_child(_pause_card)
		Motion.appear(_pause_card, 0.0, 1.0, 0.2)
		if _beam_voice.playing:
			_beam_voice.stream_paused = true
	elif _pause_card != null:
		_pause_card.queue_free()
		_pause_card = null
		_beam_voice.stream_paused = false

func _build_pause() -> Control:
	var scrim := ColorRect.new()
	scrim.color = Color(0.08, 0.07, 0.18, 0.55)
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
	head.add_theme_color_override("font_color", Color("fff1d6"))
	col.add_child(head)
	var line := Label.new()
	line.text = "FF_RESUME"
	line.theme_type_variation = "SheetTitle"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_color_override("font_color", Color("e9ecfa"))
	col.add_child(line)
	return scrim

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		var at := px(ev.get("pos", Vector2.ZERO))
		match String(ev.type):
			"shoot":
				_fx.cue("shoot", randf_range(0.96, 1.06), -4.0)
			"pop":
				var kind: int = ev.kind
				var colour: Color = {Sim.Kind.GNAT: Art.GNAT_BODY, Sim.Kind.BEETLE: Art.BEETLE_SHELL,
					Sim.Kind.MOTH: Art.MOTH_WING, Sim.Kind.ROGUE: Art.ROGUE_BODY}[kind]
				_fx.puff(at, colour, 9 if kind == Sim.Kind.MOTH else 6)
				_fx.cue("pop_moth" if kind == Sim.Kind.MOTH else "pop", randf_range(0.92, 1.1))
				if int(ev.points) >= 150 and not sim.challenge() or int(ev.points) >= 400:
					_pops.append({"pos": ev.pos, "text": str(ev.points), "t": 0.0})
			"hurt":
				_fx.cue("hurt")
				_fx.sparkle(at, Art.MOTH_HURT)
			"dive":
				if int(ev.kind) == Sim.Kind.MOTH or randf() < 0.5:
					_fx.cue("dive", randf_range(0.95, 1.05), -6.0)
			"beam":
				_fx.cue("beam_open")
			"captured":
				_fx.cue("captured")
			"carried":
				_fx.cue("carried")
			"rescue":
				_fx.cue("rescue")
				_fx.sparkle(at, Art.GLOW)
			"docked":
				_fx.cue("docked")
				_fx.ring(at, 30.0 * _u * 0.3, Art.GLOW)
			"captive_lost":
				_fx.puff(at, Art.FIREFLY_SHIELD, 6)
				_fx.cue("ship_pop")
			"rogue":
				_fx.cue("rogue")
			"ship_pop":
				_fx.puff(at, Art.GLOW, 12)
				_fx.puff(at, Art.FIREFLY_SHIELD, 8)
				_fx.cue("ship_pop")
			"ready":
				_show_banner(tr("FF_READY"), "", 1.2)
			"stage_start":
				_show_banner(tr("FF_STAGE_N") % ev.stage, "", 1.8)
				if int(ev.stage) > 1:
					_fx.cue("stage")
			"challenge_start":
				_show_banner(tr("FF_FLYBY"), tr("FF_FLYBY_LINE"), 2.2)
				_fx.cue("flyby")
			"challenge_result":
				var perfect: bool = ev.hits == ev.total
				_show_banner(tr("FF_PERFECT") if perfect else tr("FF_HITS") % [ev.hits, ev.total],
					tr("FF_BONUS") % Record.grouped(ev.bonus), 3.0)
				_fx.cue("perfect" if perfect else "result")
			"stage_clear":
				_fx.cue("clear")
			"extra_ship":
				_fx.cue("extra")
				_say_small(tr("FF_EXTRA"))
			"game_over":
				_game_over()
	sim.events.clear()

## The beam hums while any moth holds one open.
func _beam_sound() -> void:
	var open := false
	if sim != null and not _paused:
		for e: Dictionary in sim.enemies:
			if e.st == Sim.St.BEAM and e.beam > 0.2:
				open = true
	if open and not _beam_voice.playing and _beam_voice.stream != null:
		_beam_voice.play()
	elif not open and _beam_voice.playing:
		_beam_voice.stop()

func _show_banner(text: String, sub: String, hold: float) -> void:
	_banner.text = text
	_sub.text = sub
	_sub.visible = sub != ""
	var box: Control = _banner.get_meta("box")
	box.reset_size()
	box.size.x = field.size.x
	box.position = Vector2(0, field.size.y * 0.34)
	Motion.stop(_banner_tw)
	_banner_tw = create_tween()
	_banner_tw.tween_property(box, "modulate:a", 1.0, 0.2)
	_banner_tw.tween_interval(hold)
	_banner_tw.tween_property(box, "modulate:a", 0.0, 0.35)

func _say_small(text: String) -> void:
	_pops.append({"pos": Vector2(Sim.W * 0.5, Sim.H * 0.6), "text": text, "t": 0.0})

func _refresh_hud() -> void:
	if sim == null:
		return
	if sim.score != _shown_score:
		_shown_score = sim.score
		_score_l.text = Record.grouped(sim.score)
		_best_l.text = Record.grouped(maxi(_best, sim.score))
	_stage_l.text = str(sim.stage)

# --- drawing ---

func _build_sky() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	# The sky, a gradient down to the hedges' dusk.
	var top := b.vertex(Vector2.ZERO, SKY_TOP)
	b.vertex(Vector2(s.x, 0), SKY_TOP)
	b.vertex(Vector2(s.x, s.y), SKY_LOW)
	b.vertex(Vector2(0, s.y), SKY_LOW)
	b.tri(top, top + 1, top + 2)
	b.tri(top, top + 2, top + 3)
	# The moon, with a soft halo.
	var moon := Vector2(s.x * 0.8, s.y * 0.1)
	var r := s.x * 0.06
	for k in 4:
		b.disc(moon, r * (2.6 - k * 0.4), Color(Pal.MOON, 0.04 + k * 0.02))
	b.disc(moon, r, Color("f6f1e6"))
	b.disc(moon + Vector2(r * 0.35, -r * 0.2), r * 0.25, Color("e6dfcf"))
	b.disc(moon + Vector2(-r * 0.3, r * 0.35), r * 0.16, Color("e6dfcf"))
	# Far hills and the near hedge along the bottom, the firefly flying over.
	var far := PackedVector2Array()
	var near := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var x := s.x * i / n
		far.append(Vector2(x, s.y - 110.0 - 40.0 * sin(i * 0.7) - 20.0 * sin(i * 1.9)))
		near.append(Vector2(x, s.y - 46.0 - 16.0 * absf(sin(i * 1.3))))
	far.append(Vector2(s.x, s.y))
	far.append(Vector2(0, s.y))
	near.append(Vector2(s.x, s.y))
	near.append(Vector2(0, s.y))
	b.polygon(far, HEDGE_FAR)
	b.polygon(near, HEDGE)
	# Tall grass and a few flower heads on the hedge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 34:
		var x := rng.randf() * s.x
		var base := Vector2(x, s.y - 30.0)
		var tip := base + Vector2(rng.randf_range(-14, 14), -rng.randf_range(30, 70))
		b.stroke(Face.Builder.bezier2(base, base.lerp(tip, 0.5) + Vector2(rng.randf_range(-8, 8), 0), tip, 6), 4.0, HEDGE.lightened(0.08))
	for i in 7:
		var c := Vector2(rng.randf() * s.x, s.y - rng.randf_range(50, 80))
		for k in 5:
			b.disc(c + Vector2.from_angle(TAU * k / 5.0) * 6.0, 5.0, Color("c7a6d8", 0.8))
		b.disc(c, 4.0, Color("fff1a8", 0.9))
	return b.mesh()

func _draw_field() -> void:
	if _sky == null:
		_layout_field()
	if _sky != null:
		field.draw_mesh(_sky, null)
	if sim == null:
		return
	var b := Face.Builder.new()
	_draw_stars(b)
	_draw_beams(b)
	_draw_shots(b)
	_draw_ships_left(b)
	_live = b.mesh()
	field.draw_mesh(_live, null)
	var frame := int(sim.t * 7.0) % 2
	for e: Dictionary in sim.enemies:
		if e.st == Sim.St.WAIT or e.st == Sim.St.DEAD:
			continue
		var look: int = {Sim.Kind.GNAT: Art.Look.GNAT, Sim.Kind.BEETLE: Art.Look.BEETLE,
			Sim.Kind.MOTH: Art.Look.MOTH_HURT if e.hurt else Art.Look.MOTH, Sim.Kind.ROGUE: Art.Look.ROGUE}[e.kind]
		var f := frame if e.st != Sim.St.FORM else (int(sim.t * 3.0 + e.slot.x * 0.5) % 2)
		var rot: float = e.heading + PI * 0.5
		if e.captive:
			var hang: Vector2 = e.pos + Sim.captive_offset(e)
			field.draw_mesh(Art.mesh(Art.Look.CAPTIVE, 0, _u), null, Transform2D(rot + PI, px(hang)))
		var tint := Color(1.7, 1.7, 1.7) if e.flash > 0.0 else Color.WHITE
		field.draw_mesh(Art.mesh(look, f, _u), null, Transform2D(rot, px(e.pos)), tint)
	if sim.ship == Sim.Ship.ALIVE:
		for x: float in sim.ship_xs():
			field.draw_mesh(Art.mesh(Art.Look.FIREFLY, frame, _u), null, Transform2D(0.0, px(Vector2(x, Sim.PLAYER_Y))))
	elif sim.ship == Sim.Ship.CAPTURED:
		field.draw_mesh(Art.mesh(Art.Look.FIREFLY, 0, _u), null, Transform2D(sim.caught_spin, px(sim.caught_pos)), Color(1, 0.8, 0.85))
	if not sim.freed.is_empty():
		field.draw_mesh(Art.mesh(Art.Look.FIREFLY, frame, _u), null, Transform2D(sim.freed.spin, px(sim.freed.pos)))
	var font := get_theme_font("font", "SheetTitle")
	for p: Dictionary in _pops:
		var a := 1.0 - clampf((p.t - 0.5) / 0.4, 0.0, 1.0)
		var at := px(p.pos) + Vector2(0, -p.t * 40.0)
		var size := 34
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		field.draw_string(font, at + Vector2(-w * 0.5 + 2, 3), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.1, 0.08, 0.2, 0.5 * a))
		field.draw_string(font, at + Vector2(-w * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Art.GLOW_HOT, a))

## The starfield drifts down past the swarm, two depths of it; each star
## twinkles on its own clock.
func _draw_stars(b: Face.Builder) -> void:
	var s := field.size
	var scroll: float = 0.0 if Motion.reduce else sim.t
	for layer in 2:
		var speed := 14.0 if layer == 0 else 30.0
		for i in 34:
			var h := float((i * 7919 + layer * 104729) % 1000) / 1000.0
			var k := float((i * 3571 + layer * 7) % 1000) / 1000.0
			var y := fmod(k * s.y + scroll * speed, s.y - 60.0)
			var x := h * s.x
			var tw := 0.55 + 0.45 * sin(sim.t * (1.5 + h * 2.0) + i)
			var r := (1.6 if layer == 0 else 2.4) * (0.7 + 0.5 * h)
			b.disc(Vector2(x, y), r, Color(STAR, (0.35 if layer == 0 else 0.7) * tw))

## A moth's silk beam: a cone of pale light in bands that ripple downward.
func _draw_beams(b: Face.Builder) -> void:
	for e: Dictionary in sim.enemies:
		if e.st != Sim.St.BEAM or e.beam <= 0.0:
			continue
		var top := px(e.pos + Vector2(0, 7))
		var bottom_y := px(Vector2(0, Sim.PLAYER_Y + 10.0)).y
		var half: float = 16.0 * _u * e.beam
		var reach: float = lerpf(top.y, bottom_y, e.beam)
		var cone := PackedVector2Array([top + Vector2(-3.0 * _u, 0), top + Vector2(3.0 * _u, 0),
			Vector2(top.x + half, reach), Vector2(top.x - half, reach)])
		b.fan(cone, Color(BEAM, 0.18))
		var bands := 7
		for k in bands:
			var f := fmod(float(k) / bands + sim.t * 0.9, 1.0)
			var y := lerpf(top.y, reach, f)
			var w := lerpf(3.0 * _u, half, f)
			b.stroke(PackedVector2Array([Vector2(top.x - w, y), Vector2(top.x + w, y)]), 0.9 * _u, Color(BEAM, 0.55 * (1.0 - f * 0.6)))

func _draw_shots(b: Face.Builder) -> void:
	for s: Dictionary in sim.shots:
		var at := px(s.pos)
		b.ellipse(at, 2.2 * _u, 3.6 * _u, Color(Art.GLOW, 0.25))
		b.ellipse(at, 0.9 * _u, 2.4 * _u, SHOT)
		b.ellipse(at, 0.45 * _u, 1.4 * _u, Color.WHITE)
	for bl: Dictionary in sim.bullets:
		var at := px(bl.pos)
		b.disc(at, 2.2 * _u, Color(BULLET, 0.25))
		b.disc(at, 1.1 * _u, BULLET)
		b.disc(at + Vector2(-0.3, -0.3) * _u, 0.45 * _u, Color.WHITE)

## The ships in reserve as small lanterns in the bottom-left corner, and a
## flag a stage in the bottom-right.
func _draw_ships_left(b: Face.Builder) -> void:
	var s := field.size
	var left: int = sim.ships - (1 if sim.ship != Sim.Ship.DEAD else 0)
	for i in clampi(left, 0, 6):
		var c := Vector2(30.0 + i * 38.0, s.y - 26.0)
		b.disc(c, 13.0, Color(Art.GLOW, 0.25))
		b.ellipse(c, 7.0, 8.5, Art.GLOW)
		b.ellipse(c + Vector2(0, -7), 6.0, 4.5, Art.FIREFLY_SHIELD)
	var flags: int = sim.stage
	var tens := int(flags / 10.0)
	var ones := flags % 10
	var x := s.x - 22.0
	for i in ones + tens:
		var big := i >= ones
		var h := 44.0 if big else 34.0
		var foot := Vector2(x, s.y - 12.0)
		b.stroke(PackedVector2Array([foot, foot + Vector2(0, -h)]), 4.0, Color("e9ecfa", 0.9))
		var cloth := Pal.SUN if big else Pal.FLOWER
		var w := 24.0 if big else 19.0
		b.fan(PackedVector2Array([foot + Vector2(-1.0, -h), foot + Vector2(-w, -h + 7.0), foot + Vector2(-1.0, -h + 15.0)]), cloth)
		x -= 27.0 if big else 22.0

# --- the end ---

func _game_over() -> void:
	_touch = -1
	_mouse = false
	var better := Record.add(GAME, sim.score, sim.stage)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.stage,
		"seconds": secs, "fired": sim.fired, "hits": sim.hits, "kills": sim.kills, "best": better})
	_show_banner(tr("FF_GAME_OVER"), "", 1.6)
	top_bar.refresh(self)
	get_tree().create_timer(1.8).timeout.connect(_show_end.bind(better))

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
	seat.custom_minimum_size = Vector2(0, 170)
	seat.draw.connect(func() -> void:
		var c := Vector2(seat.size.x * 0.5, 90)
		seat.draw_mesh(Art.mesh(Art.Look.FIREFLY, 0, 8.0), null, Transform2D(0.0, c)))
	col.add_child(seat)
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "FF_GAME_OVER_CARD"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var score := Label.new()
	score.text = Record.grouped(sim.score)
	score.theme_type_variation = "DayBig"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score)
	var line := Label.new()
	var acc := int(round(100.0 * sim.hits / maxf(1.0, sim.fired)))
	line.text = "%s  ·  %s  ·  %s" % [tr("FF_STAGE_N") % sim.stage, tr("FF_ACCURACY") % acc,
		tr("FF_BEST_LINE") % Record.grouped(Record.best(GAME))]
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
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
	var cols := [Art.GLOW, Art.BEETLE_SHELL, Art.MOTH_WING, Art.GNAT_BODY, Pal.FLOWER, Pal.SUN_RAY]
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
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.stage})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
