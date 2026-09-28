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
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")
const Rewards = preload("res://arcade/rewards.gd")

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
const DUSK := Color("b07aa0")
const CLOUD := Color("a79fd0")
const PETAL := Color("c7a6d8")
const PETAL_WARM := Color("f2b5a0")
## Kills this close together (seconds) run a chain.
const CHAIN_GAP := 1.5
## A chain's word, by its length, loudest first.
const WORDS := [[40, "FF_WORD_5"], [30, "FF_WORD_4"], [20, "FF_WORD_3"], [12, "FF_WORD_2"], [6, "FF_WORD_1"]]
const HEAT := Color("ffb03b")
## Every this many points the score is lettered over the field.
const MILESTONE := 10000

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
var _back: ArrayMesh
var _beam_voice: AudioStreamPlayer
var _pops: Array = []   # {pos, text, t, big}
## The screen's own clock, for motion the sim does not own; it stops with
## the pause.
var _clock := 0.0
## Each bug's last state and when it changed, by id: the seat's landing
## squash and the dive's wind-up read it.
var _vis := {}
## Kill bursts: {pos (field units), t, col, big, seed}.
var _bursts: Array = []
## Shake and hit-stop, both decaying in seconds.
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _freeze := 0.0
## The firefly's lean into its movement, the muzzle flash, when it last
## rose in, and the lantern's wake (field units, newest last).
var _lean := 0.0
var _prev_px := 0.0
var _muzzle := 0.0
var _ready_at := -10.0
var _wake: Array = []
var _wake_t := 0.0
## The score as shown, rolling up to the real one.
var _roll := 0.0
var _beat_best := false
## Built once a size and moved by the draw transform, never rebuilt to
## move: the grass in four clumps that sway by skew, the two clouds, and
## the stars in six twinkle groups (two depths, three clocks) that scroll.
var _grass_meshes: Array = []   # {mesh, phase}
var _cloud_meshes: Array = []
var _star_meshes: Array = []
var _grass_base := 0.0
var _over: ArrayMesh
var _seat: Control
## The loud rewards over the whole screen (arcade/rewards.gd).
var _rw: Rewards
## Kills in a row, each within CHAIN_GAP of the last, and the seconds since
## the last; the warm glow a long chain lights round the field (0..1).
var _chain := 0
var _chain_t := 99.0
var _best_chain := 0
var _heat := 0.0
var _heat_mesh: ArrayMesh
## The field's flash after a big moment, fading, and its colour.
var _flash := 0.0
var _flash_col := Color.WHITE
var _next_milestone := MILESTONE
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
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	_ask()

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
	_rw = Rewards.new()
	_rw.set_additive(true)
	add_child(_rw)
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
	Boosters.apply(GAME, sim, _boosts)
	_boosted = not _boosts.is_empty()
	_chance_used = false
	_run_gold = 0
	_acc = 0.0
	_paused = false
	_pops.clear()
	_bursts.clear()
	_vis.clear()
	_wake.clear()
	_shake = 0.0
	_freeze = 0.0
	_lean = 0.0
	_prev_px = sim.px
	_ready_at = _clock
	_roll = 0.0
	_beat_best = false
	_chain = 0
	_chain_t = 99.0
	_best_chain = 0
	_heat = 0.0
	_flash = 0.0
	_next_milestone = MILESTONE
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
		_hands()
		if _freeze > 0.0:
			_freeze -= delta
		else:
			_acc += minf(delta, Sim.DT * MAX_STEPS)
			while _acc >= Sim.DT:
				_acc -= Sim.DT
				sim.step()
				_play_events()
		_animate(delta)
	_beam_sound()
	_refresh_hud(delta)
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()
	field.queue_redraw()

## The screen's own motion, a frame at a time: pops and bursts age, the
## shake dies, the firefly leans and its wake is laid.
func _animate(delta: float) -> void:
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 0.9)
	for bu: Dictionary in _bursts:
		bu.t += delta
	_bursts = _bursts.filter(func(bu: Dictionary) -> bool: return bu.t < (0.9 if bu.big else 0.55))
	_shake = maxf(0.0, _shake - delta * 2.4)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 16.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO
	_muzzle = maxf(0.0, _muzzle - delta)
	var vx: float = (sim.px - _prev_px) / maxf(delta, 0.0001)
	_prev_px = sim.px
	var want := 0.0 if Motion.reduce else clampf(vx / 300.0 * 0.4, -0.34, 0.34)
	_lean = lerpf(_lean, want, 1.0 - exp(-delta * 12.0))
	_wake_t += delta
	if _wake_t >= 0.03:
		_wake_t = 0.0
		if sim.ship == Sim.Ship.ALIVE:
			for x: float in sim.ship_xs():
				_wake.append({"pos": Vector2(x, Sim.PLAYER_Y + 5.0), "t": 0.0})
	for w: Dictionary in _wake:
		w.t += delta
	_wake = _wake.filter(func(w: Dictionary) -> bool: return w.t < 0.4)
	# Each bug's state changes, for the landing and the wind-up.
	var seen := {}
	for e: Dictionary in sim.enemies:
		var v: Dictionary = _vis.get(e.id, {})
		if v.is_empty() or int(v.st) != int(e.st):
			v = {"st": e.st, "was": v.get("st", Sim.St.WAIT), "since": _clock}
		seen[e.id] = v
	_vis = seen
	_animate_rewards(delta)

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
				_muzzle = 0.09
			"pop":
				var kind: int = ev.kind
				var colour: Color = {Sim.Kind.GNAT: Art.GNAT_BODY, Sim.Kind.BEETLE: Art.BEETLE_SHELL,
					Sim.Kind.MOTH: Art.MOTH_WING, Sim.Kind.ROGUE: Art.ROGUE_BODY}[kind]
				_fx.puff(at, colour, 7 if kind == Sim.Kind.MOTH else 4)
				_fx.cue("pop_moth" if kind == Sim.Kind.MOTH else "pop", randf_range(0.92, 1.1))
				var big := kind == Sim.Kind.MOTH or kind == Sim.Kind.ROGUE
				_burst(ev.pos, colour, big)
				if big:
					_shake = maxf(_shake, 0.32)
				_pops.append({"pos": ev.pos, "text": "+%d" % int(ev.points), "t": 0.0, "big": int(ev.points) >= 400,
					"small": int(ev.points) < 150})
				_on_kill(ev, colour)
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
				_shake = maxf(_shake, 0.4)
				_rw.sticker(tr("FF_OH_NO"), _in_rw(ev.pos + Vector2(0, -26.0)), 56, 1.1, false, Art.MOTH_HURT, false, "caught")
			"carried":
				_fx.cue("carried")
			"rescue":
				_fx.cue("rescue")
				_fx.sparkle(at, Art.GLOW)
				_burst(ev.pos, Art.GLOW, false)
				_rw.sticker(tr("FF_SAVED"), _in_rw(ev.pos + Vector2(0, -22.0)), 60, 1.2, false, Art.GLOW, false, "saved", 30.0)
				_rw.spray(_in_rw(ev.pos), Art.GLOW, 12, 520.0, "mote", 1.2)
				_rw.spray(_in_rw(ev.pos), Color("fffaf0"), 6, 480.0, "spark", 1.0)
			"docked":
				_fx.cue("docked")
				_fx.ring(at, 30.0 * _u * 0.3, Art.GLOW)
				var dock := _in_rw(ev.pos)
				if sim.pair:
					_rw.sticker(tr("FF_DOUBLE"), _in_rw(Vector2(Sim.W * 0.5, Sim.H * 0.55)), 78, 1.6, true, Color.WHITE, true, "double")
					_flash_now(Art.GLOW, 0.35)
				_rw.ring(dock, 36.0 * _u, Color(Art.GLOW, 0.9))
				_rw.ring(dock, 22.0 * _u, Color("fffaf0", 0.9), 0.08)
				_rw.spray(dock, Art.GLOW, 14, 700.0, "star", 0.9)
				_rw.spray(dock, Color("fffaf0"), 8, 560.0, "spark", 1.1)
			"captive_lost":
				_fx.puff(at, Art.FIREFLY_SHIELD, 6)
				_burst(ev.pos, Art.FIREFLY_SHIELD, false)
				_fx.cue("ship_pop")
			"rogue":
				_fx.cue("rogue")
			"ship_pop":
				_break_chain()
				_rw.spray(_in_rw(ev.pos), Art.FIREFLY_SHIELD, 10, 620.0, "shard", 1.0)
				_rw.spray(_in_rw(ev.pos), Art.GLOW, 10, 520.0, "mote", 1.0)
				_rw.sticker(tr("FF_OUCH"), _in_rw(ev.pos + Vector2(0, -30.0)), 60, 1.0, false, Art.FIREFLY_SHIELD, false, "ouch", 30.0)
				_fx.puff(at, Art.GLOW, 12)
				_fx.puff(at, Art.FIREFLY_SHIELD, 8)
				_burst(ev.pos, Art.GLOW, true)
				_burst(ev.pos, Art.FIREFLY_SHIELD, false)
				_fx.cue("ship_pop")
				_shake = 1.0
				_freeze = 0.12
				_wake.clear()
			"ready":
				_show_banner(tr("FF_READY"), "", 1.2)
				_ready_at = _clock
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
				_flyby_result(perfect, int(ev.bonus))
			"stage_clear":
				_fx.cue("clear")
				_stage_cleared()
			"extra_ship":
				_fx.cue("extra")
				_extra_ship()
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
	box.pivot_offset = Vector2(box.size.x * 0.5, box.size.y * 0.5)
	Motion.stop(_banner_tw)
	_banner_tw = create_tween()
	if Motion.reduce:
		box.scale = Vector2.ONE
		_banner_tw.tween_property(box, "modulate:a", 1.0, 0.2)
		_banner_tw.tween_interval(hold)
		_banner_tw.tween_property(box, "modulate:a", 0.0, 0.35)
		return
	# In with a pop from small, out lifting and fading a little larger.
	box.scale = Vector2(0.6, 0.6)
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(box, "modulate:a", 1.0, 0.16)
	_banner_tw.tween_property(box, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(hold)
	_banner_tw.chain().tween_property(box, "modulate:a", 0.0, 0.35)
	_banner_tw.tween_property(box, "scale", Vector2(1.12, 1.12), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

# --- the rewards ---

## A point of the field, in field units, in the rewards layer's pixels.
func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(field, px(p) + _shake_off)

## A point of the field, as a fraction of its size, in the rewards layer.
func _field_at(fx: float, fy: float) -> Vector2:
	return _rw.at(field, Vector2(field.size.x * fx, field.size.y * fy))

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

## A kill's rewards: scraps of the bug's colour and sparks; a moth or a
## rogue throws gold stars that fly home to the score; an escort's double
## and a rogue are lettered; the kill is counted into the chain.
func _on_kill(ev: Dictionary, colour: Color) -> void:
	var at := _in_rw(ev.pos)
	var kind: int = ev.kind
	var pts: int = ev.points
	var k := _u / 4.0
	_rw.spray(at, colour, 6, 460.0, "confetti", 0.8 * k)
	_rw.spray(at, Art.GLOW_HOT, 4, 400.0, "spark", 0.9 * k)
	if kind == Sim.Kind.MOTH or kind == Sim.Kind.ROGUE:
		_rw.spray(at, Pal.SUN, 8, 640.0, "star", 0.9 * k)
		_rw.ring(at, 26.0 * _u, Color(colour.lightened(0.3), 0.85))
		_rw.spray(at, Pal.SUN, 3, 500.0, "star", 0.8, 0.05, _plate_at(_score_l))
	if kind == Sim.Kind.MOTH and pts >= 800 and not sim.challenge():
		_rw.sticker(tr("FF_ESCORT") % int(pts / 400.0), _in_rw(ev.pos + Vector2(0, -24.0)), 60, 1.5, true, Color.WHITE, true, "escort", 40.0)
		_rw.spray(at, Color("fffaf0"), 10, 720.0, "spark", 1.2)
		_rw.ring(at, 44.0 * _u, Color(Pal.SUN, 0.9), 0.08)
		_flash_now(Art.GLOW, 0.4)
	elif kind == Sim.Kind.ROGUE:
		_rw.sticker(tr("FF_ROGUE_DOWN"), _in_rw(ev.pos + Vector2(0, -24.0)), 56, 1.3, false, Art.ROGUE_BODY.lightened(0.3), false, "rogue", 30.0)
	_count_chain()

## A kill within CHAIN_GAP of the last runs the chain on: from three its
## count is lettered up in the sky, and at each step of WORDS its word over
## the field, louder each time, flashing it and flinging stars at the score.
func _count_chain() -> void:
	_chain = _chain + 1 if _chain_t <= CHAIN_GAP else 1
	_chain_t = 0.0
	_best_chain = maxi(_best_chain, _chain)
	if _chain >= 3:
		_rw.sticker(tr("FF_CHAIN") % _chain, _field_at(0.5, 0.045), 40 + mini(_chain, 30), 1.3, false, Pal.SUN.lerp(HEAT, clampf(_chain / 30.0, 0.0, 1.0)), false, "chain", 0.0, true)
	for i in WORDS.size():
		if _chain == int(WORDS[i][0]):
			var tier := WORDS.size() - 1 - i
			_rw.sticker(tr(WORDS[i][1]), _field_at(0.5, 0.5), 72 + 10 * tier, 1.3 + 0.15 * tier, true, Color.WHITE, tier >= 1, "word", 24.0)
			_rw.spray(_field_at(0.5, 0.5), Pal.SUN, 6 + 3 * tier, 720.0, "star", 1.0)
			_rw.spray(_field_at(0.5, 0.5), Color("fffaf0"), 6 + 2 * tier, 620.0, "spark", 1.2)
			_rw.spray(_field_at(0.5, 0.5), Pal.SUN, 3 + tier, 520.0, "star", 0.8, 0.1, _plate_at(_score_l))
			_flash_now(Color("fff6c9"), 0.2 + 0.08 * tier)
			_shake = maxf(_shake, 0.2 + 0.08 * tier)
			_fx.cue("docked", 1.0 + 0.08 * tier, -2.0)
			if tier >= 3:
				_rw.rain(1.6, ["star", "confetti", "mote"], [Art.GLOW, Pal.SUN, Art.MOTH_WING, Art.BEETLE_SHELL, Art.GNAT_BODY])
			break

func _break_chain() -> void:
	_chain = 0
	_chain_t = 99.0

## A stage cleared: lettered over a sunburst, the field flashes, stars fly
## off the stage flags and a short rain falls.
func _stage_cleared() -> void:
	_rw.sticker(tr("FF_CLEAR"), _field_at(0.5, 0.6), 96, 1.5, true, Color.WHITE, true, "clear")
	_rw.spray(_field_at(0.5, 0.6), Pal.SUN, 14, 800.0, "star", 1.1)
	_rw.spray(_rw.at(field, field.size - Vector2(60.0, 40.0)), Pal.SUN, 10, 700.0, "star", 1.0)
	_rw.rain(1.4, ["star", "confetti"], [Art.GLOW, Pal.SUN, Pal.FLOWER, Art.MOTH_WING])
	_flash_now(Color("fff6c9"), 0.3)

## The flyby's tally: every hit a star flying home to the score; a perfect
## one lettered in gold with a rain of coins and stars.
func _flyby_result(perfect: bool, bonus: int) -> void:
	var at := _field_at(0.5, 0.62)
	_rw.sticker("+" + Record.grouped(bonus), at, 84 if perfect else 64, 2.6, perfect, Pal.SUN, perfect, "bonus", 40.0)
	_rw.spray(at, Pal.SUN, mini(4 + int(bonus / 500.0), 24), 620.0, "star", 0.9, 0.3, _plate_at(_score_l))
	if perfect:
		_rw.spray(at, Pal.SUN, 20, 900.0, "coin", 1.2)
		_rw.ring(at, 300.0, Color(Pal.SUN, 0.9))
		_rw.rain(3.4, ["coin", "star", "confetti"], [Pal.SUN, Art.GLOW, Pal.FLOWER, Art.MOTH_WING])
		_flash_now(Pal.SUN, 0.6)
		_shake = maxf(_shake, 0.5)

## An extra firefly: lettered over a sunburst, and lantern motes flying to
## the spare lanterns in the corner.
func _extra_ship() -> void:
	var at := _field_at(0.5, 0.66)
	_rw.sticker(tr("FF_EXTRA"), at, 70, 1.8, true, Color.WHITE, true, "extra")
	var left: int = sim.ships - (1 if sim.ship != Sim.Ship.DEAD else 0)
	var home := _rw.at(field, Vector2(30.0 + clampi(left - 1, 0, 5) * 38.0, field.size.y - 26.0))
	_rw.spray(at, Art.GLOW, 12, 600.0, "mote", 1.4, 0.2, home)
	_rw.spray(at, Color("fffaf0"), 10, 600.0, "spark", 1.2)
	_flash_now(Art.GLOW, 0.3)

## The score passing a round number, and the best being passed: lettered,
## with stars out of the plate.
func _score_moments() -> void:
	if sim.score >= _next_milestone:
		var m := _next_milestone
		while _next_milestone <= sim.score:
			_next_milestone += MILESTONE
		_rw.sticker(Record.grouped(m) + "!", _field_at(0.5, 0.12), 64, 1.4, true, Color.WHITE, true, "milestone")
		_rw.spray(_plate_at(_score_l), Pal.SUN, 10, 520.0, "star", 0.9)
		_rw.ring(_plate_at(_score_l), 140.0, Color(Pal.SUN, 0.9))

func _new_best_passed() -> void:
	_rw.sticker(tr("FF_NEW_BEST"), _field_at(0.5, 0.2), 64, 1.8, true, Color.WHITE, true, "best")
	_rw.spray(_plate_at(_best_l), Pal.SUN, 14, 620.0, "star", 1.0)
	_rw.spray(_plate_at(_best_l), Color("fffaf0"), 8, 520.0, "spark", 1.1)
	_rw.ring(_plate_at(_best_l), 160.0, Color(Pal.SUN, 0.9))
	_rw.rain(1.6, ["confetti", "star"], [Art.GLOW, Pal.SUN, Pal.FLOWER, Art.MOTH_WING, Art.BEETLE_SHELL])
	_fx.cue("extra", 1.1, -3.0)

## The field flashes `col`, `amount` at most.
func _flash_now(col: Color, amount: float) -> void:
	if Motion.reduce:
		return
	_flash = maxf(_flash, amount)
	_flash_col = col

## The rewards' clocks: the layer, the chain's window, its glow and the
## flash.
func _animate_rewards(delta: float) -> void:
	_rw.bounds = Rect2(_rw.at(field, Vector2.ZERO), field.size)
	_rw.step(delta)
	_chain_t += delta
	if _chain_t > CHAIN_GAP:
		_chain = 0
	var want := clampf((_chain - 5) / 15.0, 0.0, 1.0)
	_heat = move_toward(_heat, want, delta * (1.5 if want > _heat else 0.6))
	_flash = maxf(0.0, _flash - delta * 2.4)

## The score rolls up to the real one and gives a beat when it lands; the
## best follows it once it is passed, with a beat of its own.
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
		_roll = move_toward(_roll, sim.score, maxf(delta * (sim.score - _roll) * 9.0, delta * 400.0))
	var shown := Record.grouped(int(_roll))
	if _score_l.text != shown:
		_score_l.text = shown
		_best_l.text = Record.grouped(maxi(_best, int(_roll)))
	_stage_l.text = str(sim.stage)

# --- drawing ---

## The still backdrop, built on resize: the sky with a dusk glow over the
## hills, the moon, the far hills and the near hedge. The grass and the
## flowers on the hedge are laid out here but drawn live, so they sway.
func _build_sky() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	# The sky, a gradient down to the hedges' dusk.
	_quad(b, Vector2.ZERO, s, SKY_TOP, SKY_LOW)
	# A warm glow along the horizon, under the hills.
	_quad(b, Vector2(0, s.y - 230.0), Vector2(s.x, 130.0), Color(DUSK, 0.0), Color(DUSK, 0.32))
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
	var mid := PackedVector2Array()
	var near := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var x := s.x * i / n
		far.append(Vector2(x, s.y - 110.0 - 40.0 * sin(i * 0.7) - 20.0 * sin(i * 1.9)))
		mid.append(Vector2(x, s.y - 78.0 - 18.0 * sin(i * 1.1 + 2.0) - 8.0 * sin(i * 2.7)))
		near.append(Vector2(x, s.y - 46.0 - 16.0 * absf(sin(i * 1.3))))
	for foot in [Vector2(s.x, s.y), Vector2(0, s.y)]:
		far.append(foot)
		mid.append(foot)
		near.append(foot)
	b.polygon(far, HEDGE_FAR)
	b.polygon(mid, HEDGE_FAR.lerp(HEDGE, 0.55))
	b.polygon(near, HEDGE)
	# Rounded shrub tops along the hedge line.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 9:
		var c := Vector2(rng.randf() * s.x, s.y - rng.randf_range(44.0, 58.0))
		b.ellipse(c, rng.randf_range(26.0, 44.0), rng.randf_range(16.0, 24.0), HEDGE.lightened(0.04))
	_build_grass(s, rng)
	_build_clouds()
	_build_stars(s)
	return b.mesh()

## The grass and the flowers in four clumps across the hedge, each built
## with its base on y 0 so a skew sways the tips and leaves the roots.
func _build_grass(s: Vector2, rng: RandomNumberGenerator) -> void:
	_grass_base = s.y - 26.0
	var clumps: Array = []
	for g in 4:
		clumps.append(Face.Builder.new())
	for i in 40:
		var x := rng.randf() * s.x
		var cb: Face.Builder = clumps[mini(int(x / s.x * 4.0), 3)]
		var base := Vector2(x, 0)
		var tip := base + Vector2(rng.randf_range(-14, 14), -rng.randf_range(30, 72))
		var ctrl := base.lerp(tip, 0.5) + Vector2(rng.randf_range(-8, 8), 0)
		cb.stroke(Face.Builder.bezier2(base, ctrl, tip, 6), 4.0, HEDGE.lightened(rng.randf_range(0.05, 0.14)))
	for i in 8:
		var c := Vector2(rng.randf() * s.x, -rng.randf_range(24, 56))
		var cb: Face.Builder = clumps[mini(int(c.x / s.x * 4.0), 3)]
		for k in 5:
			cb.disc(c + Vector2.from_angle(TAU * k / 5.0 + i) * 6.0, 5.0, Color(PETAL if i % 3 else PETAL_WARM, 0.85))
		cb.disc(c, 4.0, Color("fff1a8", 0.95))
	_grass_meshes.clear()
	for g in 4:
		var cb: Face.Builder = clumps[g]
		if not cb.verts.is_empty():
			_grass_meshes.append({"mesh": cb.mesh(), "phase": g * 0.9})

func _build_clouds() -> void:
	_cloud_meshes.clear()
	for k in 2:
		var cb := Face.Builder.new()
		var grow := 1.0 + k * 0.3
		for p in [Vector2(-60, 8), Vector2(-20, -6), Vector2(24, -2), Vector2(62, 10)]:
			cb.ellipse(p * grow, 48.0 * grow, 22.0 * grow, Color(CLOUD, 0.16 - k * 0.04))
		_cloud_meshes.append(cb.mesh())

## The stars over one period of their scroll, so a mesh drawn twice, one
## period apart, wraps; the brightest wear a cross.
func _build_stars(s: Vector2) -> void:
	_star_meshes.clear()
	var period := s.y - 60.0
	var groups: Array = []
	for g in 6:
		groups.append(Face.Builder.new())
	for layer in 2:
		for i in 34:
			var h := float((i * 7919 + layer * 104729) % 1000) / 1000.0
			var k := float((i * 3571 + layer * 7) % 1000) / 1000.0
			var at := Vector2(h * s.x, k * period)
			var r := (1.6 if layer == 0 else 2.4) * (0.7 + 0.5 * h)
			var sb: Face.Builder = groups[layer * 3 + i % 3]
			var col := Color(STAR, 0.35 if layer == 0 else 0.7)
			sb.disc(at, r, col)
			if layer == 1 and i % 6 == 0:
				var arm := r * 2.6
				sb.stroke(PackedVector2Array([at - Vector2(arm, 0), at + Vector2(arm, 0)]), 1.2, Color(STAR, 0.4))
				sb.stroke(PackedVector2Array([at - Vector2(0, arm), at + Vector2(0, arm)]), 1.2, Color(STAR, 0.4))
	for g in 6:
		_star_meshes.append((groups[g] as Face.Builder).mesh())

## A rectangle with a vertical gradient.
static func _quad(b: Face.Builder, at: Vector2, size: Vector2, top_col: Color, low_col: Color) -> void:
	var i := b.vertex(at, top_col)
	b.vertex(at + Vector2(size.x, 0), top_col)
	b.vertex(at + size, low_col)
	b.vertex(at + Vector2(0, size.y), low_col)
	b.tri(i, i + 1, i + 2)
	b.tri(i, i + 2, i + 3)

## A soft streak from `head` back to `tail`, full colour at the head and
## nothing at the tail.
static func _streak(b: Face.Builder, head: Vector2, tail: Vector2, width: float, col: Color) -> void:
	var d := head - tail
	if d.length_squared() < 0.01:
		return
	var side := d.normalized().orthogonal() * width * 0.5
	var i := b.vertex(head + side, col)
	b.vertex(head - side, col)
	b.vertex(tail, Color(col, 0.0))
	b.tri(i, i + 1, i + 2)
	var cap := b.vertex(head + d.normalized() * width * 0.5, col)
	b.tri(i, cap, i + 1)

static func _kind_colour(kind: int) -> Color:
	match kind:
		Sim.Kind.GNAT:
			return Art.GNAT_BODY
		Sim.Kind.BEETLE:
			return Art.BEETLE_SHELL
		Sim.Kind.MOTH:
			return Art.MOTH_WING
	return Art.ROGUE_BODY

## A pseudo-random 0..1 from two numbers, for bursts that must look the
## same every frame they are drawn.
static func _hash(a: float, b: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)

func _burst(at: Vector2, col: Color, big: bool) -> void:
	_bursts.append({"pos": at, "t": 0.0, "col": col, "big": big, "seed": randf() * 100.0})

func _draw_field() -> void:
	if _sky == null:
		_layout_field()
	if _sky != null:
		field.draw_mesh(_sky, null)
	if sim == null:
		return
	# The backdrop's live layer, which never shakes.
	_draw_stars()
	_draw_clouds()
	_draw_grass()
	var b := Face.Builder.new()
	_draw_sky_life(b)
	if _heat > 0.01:
		var beat := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 9.0)
		Rewards.edge_glow(b, Rect2(Vector2.ZERO, field.size), HEAT.lerp(Art.BEETLE_SHELL, _heat), _heat, beat)
	_draw_ships_left(b)
	if not b.verts.is_empty():
		_live = b.mesh()
		field.draw_mesh(_live, null)
	# Everything in play shakes together.
	field.draw_set_transform(_shake_off)
	var a := Face.Builder.new()
	_draw_beams(a)
	_draw_trails(a)
	_draw_halos(a)
	_draw_shots(a)
	if not a.verts.is_empty():
		_back = a.mesh()
		field.draw_mesh(_back, null)
	var frame := int(sim.t * 7.0) % 2
	for e: Dictionary in sim.enemies:
		if e.st == Sim.St.WAIT or e.st == Sim.St.DEAD:
			continue
		var look: int = {Sim.Kind.GNAT: Art.Look.GNAT, Sim.Kind.BEETLE: Art.Look.BEETLE,
			Sim.Kind.MOTH: Art.Look.MOTH_HURT if e.hurt else Art.Look.MOTH, Sim.Kind.ROGUE: Art.Look.ROGUE}[e.kind]
		var f := frame if e.st != Sim.St.FORM else (int(sim.t * 3.0 + e.slot.x * 0.5) % 2)
		var xf := _bug_xform(e)
		if e.captive:
			var hang: Vector2 = e.pos + Sim.captive_offset(e)
			var sway := 0.0 if Motion.reduce else sin(_clock * 2.6) * 0.18
			field.draw_mesh(Art.mesh(Art.Look.CAPTIVE, 0, _u), null, Transform2D(e.heading + PI * 1.5 + sway, px(hang)))
		var tint := Color(1.8, 1.8, 1.8) if e.flash > 0.0 else Color.WHITE
		field.draw_mesh(Art.mesh(look, f, _u), null, xf, tint)
	_draw_player(frame)
	var o := Face.Builder.new()
	_draw_bursts(o)
	_draw_muzzle(o)
	if not o.verts.is_empty():
		_over = o.mesh()
		field.draw_mesh(_over, null)
	_draw_pops()
	field.draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		field.draw_rect(Rect2(Vector2.ZERO, field.size), Color(_flash_col, _flash * 0.35))

## A bug's draw transform: its heading, and the screen's own beats on top
## of where the sim put it -- a seated bug bobs on its own phase and
## squashes as it lands, a diver wriggles as it peels off, a hit one is
## knocked back and swells.
func _bug_xform(e: Dictionary) -> Transform2D:
	var pos: Vector2 = e.pos
	var rot: float = e.heading + PI * 0.5
	var sc := Vector2.ONE
	if not Motion.reduce:
		var v: Dictionary = _vis.get(e.id, {})
		var since := _clock - float(v.get("since", -10.0))
		var was: int = v.get("was", Sim.St.WAIT)
		match int(e.st):
			Sim.St.FORM:
				var ph: float = _clock * 2.4 + e.slot.x * 0.7 + e.slot.y * 1.3
				pos.y += sin(ph) * 0.9
				sc.y *= 1.0 + 0.04 * sin(ph * 2.0)
				if was == Sim.St.RETURN and since < 0.4:
					var u := since / 0.4
					var amt := 0.26 * sin(u * PI) * (1.0 - u)
					sc *= Vector2(1.0 + amt, 1.0 - amt)
				if e.hurt:
					rot += sin(_clock * 17.0) * 0.06
			Sim.St.DIVE:
				if was == Sim.St.FORM and since < 0.45:
					var u := since / 0.45
					rot += sin(u * PI * 3.0) * 0.45 * (1.0 - u)
					sc *= 1.0 + 0.16 * sin(u * PI)
			Sim.St.BEAM:
				pos.y += sin(_clock * 3.0) * 0.8
		if e.flash > 0.0:
			var k: float = e.flash / 0.12
			sc *= 1.0 + 0.22 * k
			pos.y -= 1.6 * k
	return Transform2D(rot, sc, 0.0, px(pos))

## Where the firefly is drawn: rising in after a respawn, kicked down a
## little by each volley.
func _ship_at(x: float) -> Vector2:
	var y := Sim.PLAYER_Y
	var since := _clock - _ready_at
	if since < 0.5 and not Motion.reduce:
		y += (1.0 - Motion.back_out(since / 0.5)) * 34.0
	y += _muzzle / 0.09 * 1.4
	return px(Vector2(x, y))

func _draw_player(frame: int) -> void:
	var flap := int(_clock * (11.0 if absf(_lean) > 0.08 else 7.0)) % 2
	if sim.ship == Sim.Ship.ALIVE:
		var since := _clock - _ready_at
		var alpha := 1.0
		if since < 1.3:
			alpha = 0.4 if int(since * 12.0) % 2 == 0 else 1.0
		var sc := Vector2(1.0 - absf(_lean) * 0.22, 1.0)
		for x: float in sim.ship_xs():
			field.draw_mesh(Art.mesh(Art.Look.FIREFLY, flap, _u), null, Transform2D(_lean, sc, 0.0, _ship_at(x)), Color(1, 1, 1, alpha))
	elif sim.ship == Sim.Ship.CAPTURED:
		field.draw_mesh(Art.mesh(Art.Look.FIREFLY, 0, _u), null, Transform2D(sim.caught_spin, px(sim.caught_pos)), Color(1, 0.8, 0.85))
	if not sim.freed.is_empty():
		field.draw_mesh(Art.mesh(Art.Look.FIREFLY, frame, _u), null, Transform2D(sim.freed.spin, px(sim.freed.pos)))

## The starfield drifts down past the swarm, two depths of it, each
## group of stars twinkling on its own clock.
func _draw_stars() -> void:
	var period := field.size.y - 60.0
	var scroll: float = 0.0 if Motion.reduce else sim.t
	for g in _star_meshes.size():
		var layer := int(g / 3.0)
		var o := fmod(scroll * (14.0 if layer == 0 else 30.0), period)
		var tw := 0.55 + 0.45 * sin(sim.t * (1.5 + (g % 3) * 0.9) + g * 2.1)
		for shift in [o, o - period]:
			field.draw_mesh(_star_meshes[g], null, Transform2D(0.0, Vector2(0, shift)), Color(1, 1, 1, tw))

func _draw_clouds() -> void:
	var s := field.size
	var drift := 0.0 if Motion.reduce else _clock
	for k in _cloud_meshes.size():
		var w := s.x + 360.0
		var x := fmod(drift * (7.0 + k * 4.0) + k * w * 0.55, w) - 180.0
		field.draw_mesh(_cloud_meshes[k], null, Transform2D(0.0, Vector2(x, s.y * (0.09 + k * 0.1))))

## The night's own life: a star that falls now and then, and the
## garden's fireflies blinking over the hedge.
func _draw_sky_life(b: Face.Builder) -> void:
	var s := field.size
	if not Motion.reduce:
		var period := 9.0
		var n := floorf(_clock / period)
		var lt := _clock - n * period
		if lt < 0.8:
			var u := lt / 0.8
			var start := Vector2((0.35 + 0.6 * _hash(n, 1.0)) * s.x, (0.04 + 0.22 * _hash(n, 2.0)) * s.y)
			var dir := Vector2(-0.82, 0.5).normalized()
			var head := start + dir * u * s.x * 0.5
			var a := sin(u * PI)
			_streak(b, head, head - dir * s.x * 0.16 * a, 3.2, Color(STAR, 0.85 * a))
			b.disc(head, 2.6, Color(Color.WHITE, a))
	for i in 9:
		var base := Vector2(_hash(i, 3.0) * s.x, s.y - 70.0 - _hash(i, 4.0) * 150.0)
		var a := 0.6
		if not Motion.reduce:
			base += Vector2(sin(_clock * 0.4 + i * 1.7) * 30.0, sin(_clock * 0.6 + i) * 14.0)
			a = clampf(sin(_clock * (0.8 + 0.1 * i) + i * 2.1) * 1.6 - 0.5, 0.0, 1.0)
		if a <= 0.0:
			continue
		b.disc(base, 10.0, Color(Art.GLOW, 0.12 * a))
		b.disc(base, 3.2, Color(Art.GLOW_HOT, 0.9 * a))

## The hedge's grass and flowers, each clump swaying on its own phase.
func _draw_grass() -> void:
	for g: Dictionary in _grass_meshes:
		var skew := 0.0 if Motion.reduce else sin(_clock * 1.4 + float(g.phase)) * 0.09
		field.draw_mesh(g.mesh, null, Transform2D(0.0, Vector2.ONE, skew, Vector2(0, _grass_base)))

## A moth's silk beam: a cone of pale light brightest at the moth, bands
## that ripple downward, silk motes drifting in it and a pool of light
## where it meets the ground. A caught firefly hangs on silk threads.
func _draw_beams(b: Face.Builder) -> void:
	for e: Dictionary in sim.enemies:
		if e.st != Sim.St.BEAM or e.beam <= 0.0:
			continue
		var top := px(e.pos + Vector2(0, 7))
		var bottom_y := px(Vector2(0, Sim.PLAYER_Y + 10.0)).y
		var half: float = 16.0 * _u * e.beam
		var reach: float = lerpf(top.y, bottom_y, e.beam)
		var i := b.vertex(top + Vector2(-3.0 * _u, 0), Color(BEAM, 0.42))
		b.vertex(top + Vector2(3.0 * _u, 0), Color(BEAM, 0.42))
		b.vertex(Vector2(top.x + half, reach), Color(BEAM, 0.1))
		b.vertex(Vector2(top.x - half, reach), Color(BEAM, 0.1))
		b.tri(i, i + 1, i + 2)
		b.tri(i, i + 2, i + 3)
		for side in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([top + Vector2(side * 3.0 * _u, 0), Vector2(top.x + side * half, reach)]), 0.5 * _u, Color(BEAM, 0.4))
		var bands := 7
		for k in bands:
			var f := fmod(float(k) / bands + sim.t * 0.9, 1.0)
			var y := lerpf(top.y, reach, f)
			var w := lerpf(3.0 * _u, half, f)
			b.stroke(PackedVector2Array([Vector2(top.x - w, y), Vector2(top.x + w, y)]), 0.9 * _u, Color(BEAM, 0.55 * (1.0 - f * 0.6)))
		for k in 10:
			var f := fmod(k * 0.137 + sim.t * 0.55, 1.0)
			var y := lerpf(top.y, reach, f)
			var w := lerpf(3.0 * _u, half, f)
			var x := top.x + sin(k * 3.1 + sim.t * 2.0) * w * 0.75
			b.disc(Vector2(x, y), 0.7 * _u, Color(Color.WHITE, 0.7 * sin(f * PI)))
		if e.beam >= 1.0:
			b.ellipse(Vector2(top.x, bottom_y), half * 1.1, 3.0 * _u, Color(BEAM, 0.22))
	if sim.ship == Sim.Ship.CAPTURED:
		for e: Dictionary in sim.enemies:
			if e.id == sim.caught_by:
				var from := px(e.pos + Vector2(0, 6))
				var to := px(sim.caught_pos)
				for k in 3:
					var bow := sin(sim.t * 4.0 + k * 2.0) * 3.0 * _u + (k - 1) * 2.0 * _u
					var ctrl := from.lerp(to, 0.5) + Vector2(bow, 0)
					b.stroke(Face.Builder.bezier2(from + Vector2((k - 1) * 1.5 * _u, 0), ctrl, to, 10), 0.35 * _u, Color(Art.SILK, 0.7))

## Bugs in flight leave a soft streak of their own colour.
func _draw_trails(b: Face.Builder) -> void:
	if Motion.reduce:
		return
	for e: Dictionary in sim.enemies:
		var st: int = e.st
		if st != Sim.St.DIVE and st != Sim.St.ENTER and st != Sim.St.RETURN and st != Sim.St.FLYBY:
			continue
		var dir := Vector2.from_angle(e.heading)
		var head := px(e.pos - dir * 3.0)
		var tail := px(e.pos - dir * 15.0)
		_streak(b, head, tail, 4.0 * _u, Color(_kind_colour(e.kind).lerp(Color.WHITE, 0.3), 0.3))

## The firefly's lantern breathes a halo round it, and a moving firefly
## leaves a wake of glowing motes.
func _draw_halos(b: Face.Builder) -> void:
	for w: Dictionary in _wake:
		var a: float = 1.0 - w.t / 0.4
		var p := px(w.pos + Vector2(0, w.t * 22.0))
		b.disc(p, (1.8 * a + 0.5) * _u, Color(Art.GLOW, 0.4 * a))
	if sim.ship != Sim.Ship.ALIVE:
		return
	var pulse := 0.5 + 0.5 * sin(_clock * 4.2)
	if Motion.reduce:
		pulse = 0.5
	for x: float in sim.ship_xs():
		var c := _ship_at(x) + Vector2(0, 5.2 * _u).rotated(_lean)
		b.disc(c, (12.0 + 2.5 * pulse) * _u, Color(Art.GLOW, 0.05 + 0.04 * pulse))
		b.disc(c, 7.0 * _u, Color(Art.GLOW, 0.1 + 0.05 * pulse))

func _draw_shots(b: Face.Builder) -> void:
	for s: Dictionary in sim.shots:
		var at := px(s.pos)
		_streak(b, at, at + Vector2(0, 11.0 * _u), 2.6 * _u, Color(Art.GLOW, 0.55))
		b.ellipse(at, 2.4 * _u, 3.8 * _u, Color(Art.GLOW, 0.22))
		b.ellipse(at, 0.9 * _u, 2.4 * _u, SHOT)
		b.ellipse(at + Vector2(0, -0.4 * _u), 0.45 * _u, 1.4 * _u, Color.WHITE)
	for bl: Dictionary in sim.bullets:
		var at := px(bl.pos)
		var vel: Vector2 = bl.vel
		_streak(b, at, at - vel.normalized() * 6.0 * _u, 2.2 * _u, Color(BULLET, 0.35))
		var pulse := 0.5 + 0.5 * sin(_clock * 14.0 + at.x)
		b.disc(at, (2.2 + 0.5 * pulse) * _u, Color(BULLET, 0.22))
		var spin := _clock * 10.0 + at.x * 0.1
		var seed_xf := Transform2D(spin, at)
		b.fan(seed_xf * Face.Builder.ring(Vector2.ZERO, 0.9 * _u, 1.4 * _u), BULLET)
		b.disc(seed_xf * Vector2(-0.25 * _u, -0.45 * _u), 0.4 * _u, Color.WHITE)

## A kill's burst: a flash, a ring going out and shards of the bug's colour
## flung wide and falling. A big one (a moth, a rogue, the firefly) throws
## further and lasts longer.
func _draw_bursts(b: Face.Builder) -> void:
	for bu: Dictionary in _bursts:
		var big: bool = bu.big
		var life := 0.9 if big else 0.55
		var u: float = bu.t / life
		var ease := 1.0 - pow(1.0 - u, 3.0)
		var col: Color = bu.col
		var c := px(bu.pos)
		var fade := (1.0 - u)
		# The flash swells and collapses at full strength: a light fading
		# through alpha over the night sky reads as grey smoke.
		var k := u * 3.2
		if k < 1.0:
			var swell := sin(k * PI) * (1.0 - k * 0.3)
			b.disc(c, (_flash_r(big) * swell + 0.5) * _u, Color(Art.GLOW_HOT, 0.9))
			b.disc(c, (_flash_r(big) * 0.5 * swell + 0.3) * _u, Color.WHITE)
		var r := (4.0 + (20.0 if big else 11.0) * ease) * _u
		b.stroke(Face.Builder.ring(c, r, r), 1.4 * _u * fade, col.lerp(Color.WHITE, 0.35), true)
		var n := 12 if big else 8
		for i in n:
			var sd: float = bu.seed
			var dir := Vector2.from_angle(TAU * i / n + _hash(sd, i) * 0.6)
			var d := (22.0 if big else 14.0) * (0.6 + 0.8 * _hash(sd + 1.0, i)) * ease
			var p := c + (dir * d + Vector2(0, 10.0 * u * u)) * _u
			var sz := (2.2 if big else 1.6) * fade * _u
			var side := dir.orthogonal()
			var shard := col if i % 2 == 0 else col.lerp(Color.WHITE, 0.55)
			b.fan(PackedVector2Array([p + dir * sz * 1.6, p + side * sz * 0.7, p - dir * sz * 1.6, p - side * sz * 0.7]), shard)

static func _flash_r(big: bool) -> float:
	return 9.0 if big else 5.5

## A volley's flash at the firefly's head.
func _draw_muzzle(b: Face.Builder) -> void:
	if _muzzle <= 0.0 or sim.ship != Sim.Ship.ALIVE:
		return
	var k := _muzzle / 0.09
	for x: float in sim.ship_xs():
		var head := _ship_at(x) + Vector2(0, -10.0 * _u).rotated(_lean)
		b.disc(head, 4.5 * _u * k, Color(Art.GLOW, 0.4 * k))
		b.fan(PackedVector2Array([head + Vector2(0, -7.0 * _u * k), head + Vector2(1.0 * _u, 0),
			head + Vector2(0, 2.0 * _u * k), head + Vector2(-1.0 * _u, 0)]), Color(Art.GLOW_HOT, k))
		b.fan(PackedVector2Array([head + Vector2(-4.0 * _u * k, 0), head + Vector2(0, -0.8 * _u),
			head + Vector2(4.0 * _u * k, 0), head + Vector2(0, 0.8 * _u)]), Color(Art.GLOW_HOT, 0.8 * k))

## Score pops spring up from small and rise as they fade.
func _draw_pops() -> void:
	var font := get_theme_font("font", "SheetTitle")
	for p: Dictionary in _pops:
		var a := 1.0 - clampf((p.t - 0.5) / 0.4, 0.0, 1.0)
		var at := px(p.pos) + Vector2(0, -p.t * 40.0)
		var big: bool = p.get("big", false)
		var full := 50 if big else (28 if p.get("small", false) else 36)
		var size := full if Motion.reduce else maxi(8, int(lerpf(12.0, full, Motion.back_out(minf(1.0, p.t / 0.28)))))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var col := Pal.SUN if big else Art.GLOW_HOT
		var o := at + Vector2(-w * 0.5, 0)
		field.draw_string_outline(font, o + Vector2(0, 3), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0.1, 0.08, 0.2, 0.45 * a))
		field.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0.16, 0.12, 0.3, 0.9 * a))
		field.draw_string(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, a))

## The ships in reserve as small lanterns in the bottom-left corner, each
## breathing its glow, and a flag a stage in the bottom-right, waving.
func _draw_ships_left(b: Face.Builder) -> void:
	var s := field.size
	var still := Motion.reduce
	var left: int = sim.ships - (1 if sim.ship != Sim.Ship.DEAD else 0)
	for i in clampi(left, 0, 6):
		var c := Vector2(30.0 + i * 38.0, s.y - 26.0)
		var pulse := 0.5 if still else 0.5 + 0.5 * sin(_clock * 3.0 + i * 1.3)
		b.disc(c, 12.0 + 3.0 * pulse, Color(Art.GLOW, 0.16 + 0.12 * pulse))
		b.ellipse(c, 7.0, 8.5, Art.GLOW)
		b.ellipse(c + Vector2(0, 2), 4.0, 4.5, Art.GLOW_HOT)
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
		var flap := 0.0 if still else sin(_clock * 4.5 + i * 0.9) * 3.0
		b.fan(PackedVector2Array([foot + Vector2(-1.0, -h), foot + Vector2(-w, -h + 7.0 + flap),
			foot + Vector2(-1.0, -h + 15.0)]), cloth)
		x -= 27.0 if big else 22.0

# --- the end ---

func _game_over() -> void:
	if _offer_chance():
		return
	_touch = -1
	_mouse = false
	var better := Record.add(GAME, sim.score, sim.stage, _boosted)
	_run_gold = Wallet.pay_run(better)
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
	seat.custom_minimum_size = Vector2(0, 170)
	# The firefly hovers over the card, bobbing and flapping, its lantern
	# breathing.
	var shown_at := _clock
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 90 + sin(t * 2.6) * 7.0)
		var pulse := 0.5 + 0.5 * sin(t * 4.2)
		# a sunburst turns behind it once the card is up, gold for a best
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.3) / 0.35, 0.0, 1.0)
		if glow > 0.0:
			var rb := Face.Builder.new()
			var rr := 150.0 * Motion.back_out(glow)
			rb.disc(c + Vector2(0, 30), rr * 0.5, Color(Color("fff4c2"), 0.4))
			Rewards.sunrays(rb, c + Vector2(0, 30), rr * 0.2, rr, 14, t * 0.5, Color(Pal.SUN if better else Art.GLOW, 0.5))
			Rewards.sunrays(rb, c + Vector2(0, 30), rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
			var rm := rb.mesh()
			seat.set_meta("rays", rm)
			seat.draw_mesh(rm, null)
		seat.draw_circle(c + Vector2(0, 42), 58.0 + 8.0 * pulse, Color(Art.GLOW, 0.12 + 0.06 * pulse))
		seat.draw_mesh(Art.mesh(Art.Look.FIREFLY, int(t * 8.0) % 2, 8.0), null, Transform2D(sin(t * 1.3) * 0.08, c)))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "FF_GAME_OVER_CARD"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	for pair in [[str(sim.stage), "FF_STAT_STAGE"], [str(sim.kills), "FF_STAT_KILLS"], [str(_best_chain), "FF_STAT_CHAIN"]]:
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
		_pop_in(plate, stats.get_child_count() - 1)
	col.add_child(stats)
	var line := Label.new()
	var acc := int(round(100.0 * sim.hits / maxf(1.0, sim.fired)))
	line.text = "%s  ·  %s" % [tr("FF_ACCURACY") % acc, tr("FF_BEST_LINE") % Record.grouped(Record.best(GAME))]
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var again := Dialog.primary("reset", tr("FF_AGAIN"))
	again.name = "Again"
	again.pressed.connect(_ask)
	var back := Dialog.secondary("chevron_left", tr("FF_BACK"))
	back.pressed.connect(_on_back)
	Dialog.buttons(col, again, back, BoosterIcon.gold_line(_run_gold) if _run_gold > 0 else null)
	return scrim

## A stat plate pops in after the score has run up, one after another.
func _pop_in(plate: Control, i: int) -> void:
	if Motion.reduce:
		return
	plate.modulate.a = 0.0
	plate.resized.connect(func() -> void: plate.pivot_offset = plate.size * 0.5)
	plate.scale = Vector2(0.4, 0.4)
	var tw := plate.create_tween().set_parallel(true)
	tw.tween_property(plate, "modulate:a", 1.0, 0.2).set_delay(1.3 + 0.15 * i)
	tw.tween_property(plate, "scale", Vector2.ONE, 0.4).set_delay(1.3 + 0.15 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The end card's score runs up from nothing to what the game made, with
## a burst when it gets there.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 1.1, 0.0, 1.0)
	var shown := int(sim.score * (1.0 - pow(1.0 - k, 3.0)))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
		if int(_clock * 20.0) % 2 == 0:
			_fx.cue("shoot", 0.9 + 0.8 * k, -10.0)
	if k >= 1.0:
		_end_score.pivot_offset = _end_score.size * 0.5
		Motion.bump(_end_score, 0.25, 0.4)
		var at := _rw.at(_end_score, _end_score.size * 0.5)
		_rw.spray(at, Pal.SUN, 14, 620.0, "star", 1.1)
		_rw.spray(at, Color("fffaf0"), 8, 480.0, "spark", 1.1)
		_rw.spray(at, Art.GLOW, 8, 520.0, "mote", 1.2)
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
	_rw.rain(3.5, ["confetti", "star", "mote"], [Art.GLOW, Pal.SUN, Art.MOTH_WING, Art.BEETLE_SHELL, Pal.FLOWER])
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
	_ask()

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

# --- boosters (arcade/boosters.gd) ---

## Before a run: the boost card, when a booster is held or the gold for one
## is, else straight in. A run still going when it is asked for stops there.
func _ask() -> void:
	if get_node_or_null("BoostCard") != null or get_node_or_null("SecondChance") != null:
		return
	if _end != null:
		_end.queue_free()
		_end = null
	if not BoostCard.wanted(GAME):
		_boosts = []
		_new_game()
		return
	if sim != null and not sim.is_over():
		sim = null
	var card := BoostCard.new(GAME)
	card.name = "BoostCard"
	card.play.connect(func(ids: Array) -> void:
		_boosts = ids
		_new_game())
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
		_show_banner(tr("CHANCE_GO"), "", 1.0)
		_play_events()
		top_bar.refresh(self))
	card.declined.connect(_game_over)
	add_child(card)
	return true
