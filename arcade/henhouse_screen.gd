extends Control

## Henhouse: the fourth game on the Arcade tab, an egg farm run from one
## hen to retirement (spec
## docs/superpowers/specs/2026-09-27-arcade-henhouse-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the money, the flock and the time, the farm in the Arcade's wooden
## frame (the pen on top with the water tank and the feed silo either side,
## the barn's belt along the bottom running to the crate), and the shop
## under it in two tabs with the retire button.
##
## Play, one finger: press on an egg to pick it up (with the basket, every
## egg near it) and let go over the crate to sell or the belt to send it
## along; stroke the hens to make them lay faster; tap the tank or the silo
## to refill it; tap a chick to put it to sleep. The game is
## arcade/henhouse_sim.gd, stepped at its fixed DT; this screen draws it and
## plays its events.
##
## Drawing: the farm is a still mesh built on resize and whenever the barn's
## machines change, and a front mesh of the machines' bodies the belt runs
## under. Every frame, one live mesh under the birds (troughs, belt, eggs),
## one draw call a bird (sorted by depth, mirrored by the transform), and
## one live mesh over them (the machines at work, carried and held eggs,
## hearts, bubbles), then the few words drawn as text.

signal closed

const Sim = preload("res://arcade/henhouse_sim.gd")
const Art = preload("res://arcade/henhouse_art.gd")
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

const GAME := "henhouse"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
const PANEL_H := 450.0
const BACKDROP_BLEED := 90.0
const MAX_STEPS := 12
const GRASS := Color("a9cf78")
const GRASS_DEEP := Color("8fbd62")
const GRASS_HI := Color("bddb8e")
const DIRT := Color("d8bf8c")
const STRAW := Color("ecd08a")
const STRAW_DEEP := Color("cfae62")
const PLANK := Color("b98556")
const PLANK_DEEP := Color("9c6b45")
const PLANK_HI := Color("cf9d6c")
const TAG := Color("fffaf0")
const LOW_RED := Color("e2645c")
const HINT_HOLD := 4.5
## The birds are drawn this much larger than a field unit, and the eggs
## this big, so a thumb finds them on a phone.
const BIRD := 1.3
const EGG_R := 6.2

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var field: Control
var _fx: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _money_l: Label
var _flock_l: Label
var _time_l: Label
var _banner: Label
var _sub: Label
var _banner_tw: Tween
var _toast: PanelContainer
var _toast_l: Label
var _toast_tw: Tween
var _pause_card: Control
var _end: Control
var _panel_box: VBoxContainer
var _grid: GridContainer
var _tab := "farm"
var _tab_btns := {}
var _retire_btn: Button
var _chips: Array = []
var _radio: AudioStreamPlayer
var _acc := 0.0
var _paused := false
var _started_at := 0
var _clock := 0.0
var _u := 2.6
var _origin := Vector2.ZERO
var _ground: ArrayMesh
var _front: ArrayMesh
var _under: ArrayMesh
var _over: ArrayMesh
var _built_key := ""
## The finger: held egg ids, where it is (field units), whether it strokes.
var _held: Array = []
var _finger := Vector2.INF
var _stroking := false
var _pressed := false
## Effects: hearts {pos, t}, pops {pos, text, t, col, big}, bubbles {id, text, t}.
var _hearts: Array = []
var _pops: Array = []
var _bubble := {}
var _heart_at := {}
var _machine_at := {"washer": -10.0, "stamp": -10.0, "packer": -10.0}
var _sold_acc := 0.0
var _sold_gold := false
var _sold_at := -10.0
var _refill_at := {"feed": -10.0, "water": -10.0}
var _hints_said := {}
var _shown_money := -1
var _roll := 0.0
var _bumped := {}

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

	top_bar = FlatTopBar.new("Henhouse", tr("HH_MOTTO"), true)
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
	over.alignment = BoxContainer.ALIGNMENT_CENTER
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_color_override("font_color", Color("fffaf0"))
	_sub.add_theme_color_override("font_shadow_color", Color(0.2, 0.14, 0.06, 0.5))
	_sub.add_theme_constant_override("shadow_offset_y", 3)
	over.add_child(_sub)
	over.modulate.a = 0.0
	_banner.set_meta("box", over)

	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 28, 14))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast_l = Label.new()
	_toast_l.theme_type_variation = "SheetBody"
	_toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_l)
	field.add_child(_toast)

	var panel := PanelContainer.new()
	panel.name = "Shop"
	panel.custom_minimum_size.y = PANEL_H
	panel.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 36, 18))
	col.add_child(panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	panel.add_child(_panel_box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	_panel_box.add_child(tabs)
	for key in ["farm", "factory"]:
		var b := Button.new()
		b.name = "Tab_" + key
		b.text = "HH_TAB_" + key.to_upper()
		b.add_theme_font_override("font", CozyTheme.display(700))
		b.add_theme_font_size_override("font_size", 32)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(220, 84)
		b.pressed.connect(_set_tab.bind(key))
		tabs.add_child(b)
		_tab_btns[key] = b
	_retire_btn = _RetireButton.new(self)
	_retire_btn.name = "Retire"
	_retire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_retire_btn.custom_minimum_size.y = 84
	_retire_btn.pressed.connect(_on_buy.bind("retire"))
	tabs.add_child(_retire_btn)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_box.add_child(_grid)

	_radio = AudioStreamPlayer.new()
	var radio_path := "res://assets/sfx/henhouse/radio.ogg"
	if ResourceLoader.exists(radio_path):
		var stream: AudioStreamOggVorbis = (load(radio_path) as AudioStreamOggVorbis).duplicate()
		stream.loop = true
		_radio.stream = stream
	_radio.volume_db = -4.0
	add_child(_radio)
	_apply_insets()

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["HH_MONEY", "HH_FLOCK", "MH_TIME"]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.size_flags_stretch_ratio = 1.5 if key == "HH_MONEY" else 1.0
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
	_money_l = made[0]
	_flock_l = made[1]
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

## The farm is scaled to the room and centred.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_u = minf(s.x / Sim.W, s.y / Sim.H)
	_origin = Vector2((s.x - Sim.W * _u) * 0.5, (s.y - Sim.H * _u) * 0.5)
	_built_key = ""
	var box: Control = _banner.get_meta("box")
	box.position = Vector2(20, s.y * 0.26)
	box.size = Vector2(s.x - 40, 0)
	field.queue_redraw()

func px(p: Vector2) -> Vector2:
	return _origin + p * _u

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
	_held.clear()
	_finger = Vector2.INF
	_stroking = false
	_pressed = false
	_hearts.clear()
	_pops.clear()
	_bubble = {}
	_heart_at.clear()
	_hints_said.clear()
	_sold_acc = 0.0
	_shown_money = -1
	_roll = sim.money
	_built_key = ""
	_started_at = Time.get_ticks_msec()
	if _radio.playing:
		_radio.stop()
	if _pause_card != null:
		_pause_card.queue_free()
		_pause_card = null
	_set_tab("farm")
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
		_hints()
	_refresh_hud(delta)
	_refresh_chips()
	field.queue_redraw()
	if _end != null and _end.has_meta("seat"):
		(_end.get_meta("seat") as Control).queue_redraw()

func _animate(delta: float) -> void:
	for h: Dictionary in _hearts:
		h.t += delta
	_hearts = _hearts.filter(func(h: Dictionary) -> bool: return h.t < 0.9)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 1.0)
	if not _bubble.is_empty():
		_bubble.t += delta
		if _bubble.t > 2.4:
			_bubble = {}
	# the crate's takings, a pop at a time rather than one a coin
	if _sold_acc > 0.0 and _clock - _sold_at > 0.18:
		_sold_at = _clock
		_pop(Vector2(Sim.CRATE.get_center().x, Sim.CRATE.position.y - 4.0), "+$" + _money(_sold_acc), Pal.SUN if _sold_gold else Color("fffaf0"), _sold_gold)
		_sold_acc = 0.0
		_sold_gold = false

# --- the finger ---

func _on_field_input(event: InputEvent) -> void:
	var at := Vector2.INF
	var down := false
	var up := false
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.index != 0:
			return
		at = te.position
		down = te.pressed
		up = not te.pressed
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		if de.index != 0:
			return
		at = de.position
	elif event is InputEventMouseButton:
		var me := event as InputEventMouseButton
		if me.button_index != MOUSE_BUTTON_LEFT:
			return
		at = me.position
		down = me.pressed
		up = not me.pressed
	elif event is InputEventMouseMotion:
		if not _pressed:
			return
		at = (event as InputEventMouseMotion).position
	else:
		return
	if _paused:
		if down and _end == null and not settings_sheet.is_open():
			_pause(false)
		return
	var p := unit(at)
	if down:
		press(p)
	elif up:
		lift(p)
	else:
		move(p)

## A finger coming down at a point of the field, in field units: a trough
## is refilled, an egg is picked up, a chick is put to sleep, or a stroke
## begins.
func press(p: Vector2) -> void:
	_pressed = true
	_finger = p
	_stroking = false
	if sim == null or sim.phase != Sim.Phase.PLAY:
		return
	if Sim.TANK.grow(8.0).has_point(p):
		_refill("water")
		return
	if Sim.SILO.grow(8.0).has_point(p):
		_refill("feed")
		return
	_held = sim.grab(p)
	if not _held.is_empty():
		sim.hold_at(_held, p)
		_play_events()
		return
	if sim.tap_chick(p) >= 0:
		_play_events()
		return
	_stroking = true

func move(p: Vector2) -> void:
	if not _pressed or sim == null:
		return
	var moved := (p - _finger).length() if _finger != Vector2.INF else 0.0
	_finger = p
	if not _held.is_empty():
		sim.hold_at(_held, p)
	elif _stroking and moved > 0.0:
		for id: int in sim.pet(p, moved):
			if _clock - float(_heart_at.get(id, -10.0)) > 0.28:
				_heart_at[id] = _clock
				var h: Dictionary = sim.hen_by_id(id)
				if not h.is_empty():
					_hearts.append({"pos": h.pos + Vector2(randf_range(-4, 4), -34.0), "t": 0.0})
					_fx.cue("pet", randf_range(0.9, 1.15), -2.0)
				_hint_once("pet_done", "")

func lift(p: Vector2) -> void:
	_pressed = false
	_stroking = false
	_finger = Vector2.INF
	if sim == null or _held.is_empty():
		return
	var ids := _held.duplicate()
	_held.clear()
	sim.release(ids, p)
	_play_events()

func _refill(which: String) -> void:
	if sim.refill(which):
		_refill_at[which] = _clock
	_play_events()

func _on_buy(item: String) -> void:
	if sim == null:
		return
	sim.buy(item)
	_play_events()

func _pause(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	if _radio.stream != null:
		_radio.stream_paused = on
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
	for pair in [["FF_PAUSED", "WellDone"], ["FF_RESUME", "SheetTitle"]]:
		var l := Label.new()
		l.text = pair[0]
		l.theme_type_variation = pair[1]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color("fffaf0"))
		col.add_child(l)
	return scrim

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		match String(ev.type):
			"ready":
				_show_banner(tr("HH_READY"), tr("HH_READY_LINE"), 1.2)
			"go":
				pass
			"hen":
				if sim.phase == Sim.Phase.PLAY:
					_fx.cue("cluck", randf_range(0.92, 1.1))
					_bubble = {"id": ev.id, "text": tr("HH_HELLO") % ev.name, "t": 0.0}
			"lay":
				_fx.cue("lay", randf_range(0.9, 1.15), -2.0)
				if ev.gold:
					_fx.sparkle(px(ev.pos), Art.EGG_GOLD)
				_hint_once("drag", tr("HH_HINT_DRAG") if not sim.has("belt") else "")
			"pick":
				_fx.cue("pick", randf_range(0.95, 1.1))
			"drop":
				_fx.cue("drop", randf_range(0.95, 1.1))
			"sell":
				_sold_acc += float(ev.value)
				_sold_gold = _sold_gold or bool(ev.gold)
				if ev.gold:
					_fx.cue("sell_gold")
					_fx.sparkle(px(Sim.CRATE.get_center()), Art.EGG_GOLD)
				else:
					_fx.cue("sell", randf_range(0.92, 1.12), -2.0)
				_bump(_money_l)
				if sim.sold == 3 and not sim.has("belt"):
					_hint_once("belt", tr("HH_HINT_BELT"))
			"washer", "stamp", "packer":
				_machine_at[ev.type] = _clock
				_fx.cue({"washer": "wash", "stamp": "stamp", "packer": "box"}[ev.type], randf_range(0.94, 1.08), -3.0)
			"bought":
				_on_bought(ev)
			"refused":
				_fx.cue("refused")
				if int(ev.price) > 0:
					_say(tr("HH_NEED") % _money(float(ev.price)), 1.6)
			"refill":
				_fx.cue(ev.which, randf_range(0.95, 1.05))
				var box: Rect2 = Sim.SILO if ev.which == "feed" else Sim.TANK
				_fx.puff(px(box.get_center() + Vector2(0, -box.size.y * 0.3)), Art.GRAIN if ev.which == "feed" else Art.WATER, 6)
				_pop(box.get_center() + Vector2(0, -box.size.y * 0.5 - 8.0), "-$" + _money(float(ev.cost)), Color("fffaf0"), false)
			"low":
				_fx.cue("hungry")
				_hint_once("refill", tr("HH_HINT_REFILL"))
			"starving":
				_fx.cue("hungry", 0.9)
				_say(tr("HH_HINT_STARVING"), 3.0)
			"lost":
				_fx.cue("lost")
				_fx.puff(px(ev.pos + Vector2(0, -10)), Color("fffaf0"), 10)
				_say(tr("HH_LOST") % ev.name, 2.4)
			"hatch":
				_fx.cue("hatch")
				_fx.puff(px(ev.pos), Art.EGG_FERTILE, 7)
				_hint_once("chick", tr("HH_HINT_CHICK"))
			"grown":
				_fx.cue("grow")
				_fx.sparkle(px(ev.pos + Vector2(0, -14)), Pal.SUN)
			"sleep":
				_fx.cue("sleep")
			"wake":
				_fx.cue("pick", 1.3)
			"squirrel_drop":
				_fx.cue("drop", randf_range(1.0, 1.15), -4.0)
			"retire":
				_finish(true)
			"closed":
				_finish(false)
	sim.events.clear()

func _on_bought(ev: Dictionary) -> void:
	var item: String = ev.item
	_fx.cue("buy")
	match item:
		"rooster":
			_fx.cue("rooster")
			_hint_once("rooster", tr("HH_HINT_ROOSTER"))
		"squirrel":
			_fx.cue("squirrel")
		"radio":
			if _radio.stream != null:
				_radio.play()
		"belt":
			_hint_once("belt_bought", tr("HH_HINT_BELT_BOUGHT"))
		"basket":
			_hint_once("basket", tr("HH_HINT_BASKET"))
	for chip: _ShopChip in _chips:
		if chip.item == item:
			chip.pivot_offset = chip.size * 0.5
			Motion.bump(chip, 0.2, 0.3)
			_fx.sparkle(chip.global_position - field.global_position + chip.size * 0.5, Pal.SUN)
	_built_key = ""

func _bump(l: Control) -> void:
	if _clock - float(_bumped.get(l, -10.0)) < 0.2:
		return
	_bumped[l] = _clock
	l.pivot_offset = l.size * 0.5
	Motion.bump(l, 0.12, 0.22)

## Each of the few lessons the farm teaches, said once a run, when it
## first applies.
func _hints() -> void:
	if sim.phase != Sim.Phase.PLAY:
		return
	if sim.t > 45.0 and sim.petted < 0.2 and sim.adults() > 0:
		_hint_once("pet", tr("HH_HINT_PET"))
	if sim.money >= Sim.RETIRE:
		_hint_once("retire", tr("HH_HINT_RETIRE"))

func _hint_once(key: String, text: String) -> void:
	if _hints_said.has(key):
		return
	_hints_said[key] = true
	if text != "":
		_say(text, HINT_HOLD)

func _say(text: String, hold: float) -> void:
	var w := minf(field.size.x - 60.0, 760.0)
	# Wrapped here rather than by the label: an autowrapping label measures
	# itself at its old width, a pixel, and comes out thousands tall.
	_toast_l.text = _wrap(text, w - 36.0)
	_toast.custom_minimum_size.x = w
	_toast.reset_size()
	_toast.size.x = w
	_toast.position = Vector2((field.size.x - w) * 0.5, px(Vector2(0, Sim.FENCE.end.y)).y - _toast.size.y - 12.0)
	Motion.stop(_toast_tw)
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tw.tween_interval(hold)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.35)

func _show_banner(text: String, sub: String, hold: float) -> void:
	_banner.text = text
	_sub.text = sub
	_sub.visible = sub != ""
	var box: Control = _banner.get_meta("box")
	box.reset_size()
	box.size.x = field.size.x - 40.0
	box.position = Vector2(20, field.size.y * 0.26)
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

## `text` broken into lines no wider than `wide` in the toast's face.
func _wrap(text: String, wide: float) -> String:
	var font := _toast_l.get_theme_font("font")
	var fs := _toast_l.get_theme_font_size("font_size")
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > wide:
			lines.append(line)
			line = word
		else:
			line = next
	if line != "":
		lines.append(line)
	return "\n".join(lines)

## Money as the player's language groups it, whole dollars.
static func _money(v: float) -> String:
	return Record.grouped(int(floor(v)))

static func clock_text(secs: int) -> String:
	return "%d:%02d" % [secs / 60, secs % 60]

func _refresh_hud(delta := 0.0) -> void:
	if sim == null:
		return
	if Motion.reduce or sim.money < _roll:
		_roll = sim.money
	else:
		_roll = move_toward(_roll, sim.money, maxf(delta * absf(sim.money - _roll) * 8.0, delta * 40.0))
	var shown := "$" + _money(_roll)
	if _money_l.text != shown:
		_money_l.text = shown
	var fl := "%d/%d" % [sim.flock(), Sim.MAX_FLOCK]
	if _flock_l.text != fl:
		_flock_l.text = fl
		if sim.hungry():
			_flock_l.add_theme_color_override("font_color", LOW_RED)
	if not sim.hungry():
		_flock_l.remove_theme_color_override("font_color")
	else:
		_flock_l.add_theme_color_override("font_color", LOW_RED)
	var secs := clock_text(int(sim.t))
	if _time_l.text != secs:
		_time_l.text = secs

# --- the shop ---

func _set_tab(key: String) -> void:
	_tab = key
	for k: String in _tab_btns:
		var b: Button = _tab_btns[k]
		var on := k == key
		for st in ["normal", "hover", "focus", "pressed"]:
			b.add_theme_stylebox_override(st, CozyTheme.chip(Pal.SUN if on else Color("efe7da"), 26))
		b.add_theme_color_override("font_color", Pal.TEXT if on else Pal.TEXT_DIM)
		b.add_theme_color_override("font_hover_color", Pal.TEXT)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_chips.clear()
	var items: Array = Sim.FARM if key == "farm" else Sim.FACTORY
	for item: String in items:
		var chip := _ShopChip.new(self, item)
		chip.name = "Buy_" + item
		chip.pressed.connect(_on_buy.bind(item))
		_grid.add_child(chip)
		_chips.append(chip)

func _refresh_chips() -> void:
	for chip: _ShopChip in _chips:
		chip.sync()
	if _retire_btn != null:
		(_retire_btn as _RetireButton).sync()

# --- drawing ---

## The farm's still parts: the lawn and the pen, the fence, the troughs'
## frames, the barn wall, the belt's bed and the crate. Built on resize and
## when the barn changes.
func _build_ground() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	var u := _u
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), GRASS_DEEP)
	var top := px(Vector2(0, 0))
	var barn_y := px(Vector2(0, Sim.FENCE.end.y + 6.0)).y
	b.fan(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, barn_y), Vector2(0, barn_y)]), GRASS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# mown patches, clover and flowers across the lawn
	for i in 7:
		var c := Vector2(rng.randf() * s.x, rng.randf_range(0.05, 0.9) * barn_y)
		b.ellipse(c, rng.randf_range(90.0, 170.0), rng.randf_range(36.0, 60.0), Color(GRASS_HI, 0.35))
	# the pen's floor: trodden earth with straw, inside the fence
	var pen := Rect2(px(Sim.FENCE.position + Vector2(4, 6)), Sim.FENCE.size * u - Vector2(8, 10) * u)
	b.fan(Face.Builder.round_rect(pen.position, pen.size, 18.0 * u * 0.4), Color(DIRT, 0.55))
	for i in 38:
		var c := pen.position + Vector2(rng.randf() * pen.size.x, rng.randf() * pen.size.y)
		var a := rng.randf() * PI
		b.stroke(PackedVector2Array([c, c + Vector2.from_angle(a) * rng.randf_range(4.0, 9.0) * u]), 0.9 * u, STRAW if i % 3 else STRAW_DEEP)
	for i in 16:
		var c := pen.position + Vector2(rng.randf() * pen.size.x, rng.randf() * pen.size.y)
		for q in 3:
			b.stroke(PackedVector2Array([c + Vector2((q - 1) * 2.0, 0), c + Vector2((q - 1) * 3.0, -7.0 - q % 2 * 3.0)]), 2.4, GRASS_DEEP.darkened(0.05))
	# nests of straw in two corners
	for nc in [Vector2(Sim.FENCE.position.x + 30, Sim.FENCE.position.y + 30), Vector2(Sim.FENCE.end.x - 34, Sim.FENCE.position.y + 34)]:
		b.ellipse(px(nc), 20.0 * u, 9.0 * u, STRAW_DEEP)
		b.ellipse(px(nc) + Vector2(0, -1.5 * u), 16.0 * u, 6.5 * u, STRAW)
		for k in 10:
			var a := TAU * k / 10.0
			b.stroke(PackedVector2Array([px(nc) + Vector2(cos(a) * 12.0, sin(a) * 5.0) * u, px(nc) + Vector2(cos(a) * 19.0, sin(a) * 8.5) * u]), 0.9 * u, STRAW_DEEP)
	# the flowers along the top edge
	for i in int(s.x / 50.0) + 1:
		var c := Vector2(i * 50.0 + rng.randf_range(0, 30), top.y + rng.randf_range(6.0, 16.0) * u)
		if c.y > px(Vector2(0, Sim.FENCE.position.y)).y - 4:
			continue
		var colr: Color = [Color("f4a7a0"), Color("fbe3a0"), Color("fffaf0"), Color("c7a6d8")][i % 4]
		for q in 5:
			b.disc(c + Vector2.from_angle(TAU * q / 5.0) * 4.0, 3.4, colr)
		b.disc(c, 2.4, Color("f2c14e"))
	_fence(b, u)
	_trough_frame(b, Sim.TANK, u, true)
	_trough_frame(b, Sim.SILO, u, false)
	# the barn wall: planks under a beam
	var wall := Rect2(Vector2(0, barn_y), Vector2(s.x, s.y - barn_y))
	b.fan(PackedVector2Array([wall.position, Vector2(s.x, barn_y), s, Vector2(0, s.y)]), PLANK)
	var pw := 22.0 * u
	var x := 0.0
	var k := 0
	while x < s.x:
		b.stroke(PackedVector2Array([Vector2(x, barn_y), Vector2(x, s.y)]), 1.2 * u, PLANK_DEEP)
		b.stroke(PackedVector2Array([Vector2(x + 2.5 * u, barn_y + 2), Vector2(x + 2.5 * u, s.y)]), 0.8 * u, Color(PLANK_HI, 0.5))
		for n in 2:
			b.disc(Vector2(x + pw * 0.5 + (k % 3 - 1) * 3.0 * u, barn_y + (12.0 + n * 34.0 + (k % 2) * 9.0) * u), 0.9 * u, PLANK_DEEP)
		x += pw
		k += 1
	b.fan(PackedVector2Array([Vector2(0, barn_y - 4.0 * u), Vector2(s.x, barn_y - 4.0 * u), Vector2(s.x, barn_y + 4.0 * u), Vector2(0, barn_y + 4.0 * u)]), PLANK_DEEP)
	b.fan(PackedVector2Array([Vector2(0, barn_y - 4.0 * u), Vector2(s.x, barn_y - 4.0 * u), Vector2(s.x, barn_y - 1.5 * u), Vector2(0, barn_y - 1.5 * u)]), PLANK_HI)
	_belt_bed(b, u)
	_crate(b, u, false)
	# the squirrels' stump, once there are squirrels
	if sim.has("squirrel"):
		var st := px(Sim.SQUIRREL_HOME + Vector2(-8, 8))
		b.ellipse(st + Vector2(0, 2 * u), 14.0 * u, 5.0 * u, Color(0.2, 0.14, 0.06, 0.25))
		b.fan(Face.Builder.round_rect(st + Vector2(-12, -14) * u, Vector2(24, 16) * u, 3.0 * u), Art.WOOD_DEEP)
		b.ellipse(st + Vector2(0, -14) * u, 12.0 * u, 4.0 * u, Art.WOOD_HI)
		b.ellipse(st + Vector2(0, -14) * u, 7.0 * u, 2.2 * u, Art.WOOD)
		b.ellipse(st + Vector2(0, -4) * u, 4.0 * u, 5.0 * u, Color("3e2a1f"))
	return b.mesh()

## The pen's fence: posts with two rails, round the pen.
func _fence(b: Face.Builder, u: float) -> void:
	var r := Sim.FENCE
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var z: Vector2 = corners[(side + 1) % 4]
		for rail in [5.0, 12.0]:
			b.stroke(PackedVector2Array([px(a) + Vector2(0, -rail * u + 8.0 * u), px(z) + Vector2(0, -rail * u + 8.0 * u)]), 2.6 * u, Art.WOOD_DEEP)
			b.stroke(PackedVector2Array([px(a) + Vector2(0, -rail * u + 7.3 * u), px(z) + Vector2(0, -rail * u + 7.3 * u)]), 1.2 * u, Art.WOOD_HI)
		var n := int((z - a).length() / 34.0)
		for i in n + 1:
			var p := px(a.lerp(z, float(i) / maxf(1.0, n)))
			b.ellipse(p + Vector2(0, 8.5 * u), 3.4 * u, 1.3 * u, Color(0.2, 0.14, 0.06, 0.25))
			b.fan(Face.Builder.round_rect(p + Vector2(-2.2, -9.0) * u, Vector2(4.4, 17.5) * u, 1.6 * u), Art.WOOD)
			b.fan(Face.Builder.round_rect(p + Vector2(-2.2, -9.0) * u, Vector2(1.5, 17.5) * u, 0.8 * u), Art.WOOD_HI)
			b.fan(PackedVector2Array([p + Vector2(-2.2, -9.0) * u, p + Vector2(2.2, -9.0) * u, p + Vector2(0, -11.2) * u]), Art.WOOD)

## A trough's tube: a glass tank of water on legs, or a tall silo of grain.
func _trough_frame(b: Face.Builder, r: Rect2, u: float, tank: bool) -> void:
	var at := px(r.position)
	var size := r.size * u
	b.ellipse(at + Vector2(size.x * 0.5, size.y + 6 * u), size.x * 0.7, 3.0 * u, Color(0.2, 0.14, 0.06, 0.25))
	var rim := Art.METAL_DEEP if tank else Art.SILO_DEEP
	var body := Color("dfeef5") if tank else Color("f3dcc4")
	b.fan(Face.Builder.round_rect(at + Vector2(-2.5, -2.5) * u, size + Vector2(5, 5) * u, 7.0 * u), rim)
	b.fan(Face.Builder.round_rect(at, size, 6.0 * u), body)
	# the cap and the spout into a little dish
	b.fan(Face.Builder.round_rect(at + Vector2(-4.0, -7.0) * u, Vector2(size.x + 8.0 * u, 7.0 * u), 3.0 * u), rim)
	b.fan(Face.Builder.round_rect(at + Vector2(size.x * 0.5 - 4.0 * u, size.y), Vector2(8.0, 6.0) * u, 2.0 * u), rim)
	var dish := at + Vector2(size.x * 0.5, size.y + 8.0 * u)
	b.ellipse(dish, 12.0 * u, 3.8 * u, rim)
	b.ellipse(dish + Vector2(0, -0.8 * u), 10.0 * u, 2.6 * u, Art.WATER if tank else Art.GRAIN)
	# the gauge's ticks
	for k in range(1, 4):
		var y := at.y + size.y * k / 4.0
		b.stroke(PackedVector2Array([Vector2(at.x + 2.0 * u, y), Vector2(at.x + 7.0 * u, y)]), 0.8 * u, Color(rim, 0.6))

## The belt's bed, its legs and rollers; greyed until the belt is bought.
func _belt_bed(b: Face.Builder, u: float) -> void:
	var owned: bool = sim.has("belt")
	var x0 := px(Vector2(Sim.BELT_X0 - 6.0, Sim.BELT_Y)).x
	var x1 := px(Vector2(Sim.CRATE.position.x + 6.0, Sim.BELT_Y)).x
	var y := px(Vector2(0, Sim.BELT_Y)).y
	var hh := (Sim.BELT_HALF + 2.0) * u
	for lx in [x0 + 14.0 * u, (x0 + x1) * 0.5, x1 - 14.0 * u]:
		b.fan(Face.Builder.round_rect(Vector2(lx - 2.5 * u, y), Vector2(5.0 * u, (Sim.H - Sim.BELT_Y) * u), 1.5 * u), Art.METAL_DEEP)
	b.ellipse(Vector2((x0 + x1) * 0.5, y + hh + 5.0 * u), (x1 - x0) * 0.5, 4.0 * u, Color(0.2, 0.12, 0.05, 0.25))
	b.fan(Face.Builder.round_rect(Vector2(x0, y - hh), Vector2(x1 - x0, hh * 2.0), hh), Art.METAL_DEEP if owned else Color(Art.METAL_DEEP, 0.45))
	b.fan(Face.Builder.round_rect(Vector2(x0 + 2.0 * u, y - hh + 2.0 * u), Vector2(x1 - x0 - 4.0 * u, hh * 2.0 - 4.0 * u), hh - 2.0 * u),
		Art.BELT if owned else Color(Art.METAL, 0.5))
	if not owned:
		# a sign on the idle belt: it is for sale
		var c := Vector2((x0 + x1) * 0.5, y)
		b.fan(Face.Builder.round_rect(c + Vector2(-24, -8) * u, Vector2(48, 16) * u, 4.0 * u), Color("fffaf0", 0.85))

## The crate at the belt's end: a wooden crate under a striped awning, and
## a coin sign.
func _crate(b: Face.Builder, u: float, glow: bool) -> void:
	var r := Sim.CRATE
	var at := px(r.position)
	var size := r.size * u
	if glow:
		b.fan(Face.Builder.round_rect(at + Vector2(-6, -6) * u, size + Vector2(12, 12) * u, 10.0 * u), Color(Pal.SUN, 0.35))
		return
	b.ellipse(at + Vector2(size.x * 0.5, size.y + 2.0 * u), size.x * 0.6, 4.0 * u, Color(0.2, 0.12, 0.05, 0.3))
	b.fan(Face.Builder.round_rect(at + Vector2(0, size.y * 0.3), Vector2(size.x, size.y * 0.7), 3.0 * u), Art.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(2, size.y * 0.3 / u + 2) * u, Vector2(size.x - 4.0 * u, size.y * 0.7 - 4.0 * u), 2.0 * u), Art.WOOD)
	for k in 3:
		var yy := at.y + size.y * (0.42 + k * 0.18)
		b.stroke(PackedVector2Array([Vector2(at.x + 3 * u, yy), Vector2(at.x + size.x - 3 * u, yy)]), 1.0 * u, Art.WOOD_DEEP)
	# the straw inside, where the eggs go
	b.ellipse(at + Vector2(size.x * 0.5, size.y * 0.32), size.x * 0.44, 4.0 * u, STRAW)
	# the awning, striped, on two poles
	for px_ in [at.x + 3.0 * u, at.x + size.x - 3.0 * u]:
		b.stroke(PackedVector2Array([Vector2(px_, at.y + size.y * 0.3), Vector2(px_, at.y - 6.0 * u)]), 1.6 * u, Art.WOOD_DEEP)
	var aw := at + Vector2(-4.0 * u, -14.0 * u)
	var n := 6
	var ww := (size.x + 8.0 * u) / n
	for k in n:
		var x := aw.x + k * ww
		b.fan(PackedVector2Array([Vector2(x, aw.y), Vector2(x + ww, aw.y), Vector2(x + ww, aw.y + 9.0 * u), Vector2(x, aw.y + 9.0 * u)]),
			Color("e2645c") if k % 2 == 0 else Color("fffaf0"))
		b.disc(Vector2(x + ww * 0.5, aw.y + 9.0 * u), ww * 0.5, Color("e2645c") if k % 2 == 0 else Color("fffaf0"))
	# the coin sign on the crate
	var coin := at + Vector2(size.x * 0.5, size.y * 0.7)
	b.disc(coin, 7.0 * u, Art.EGG_GOLD_DEEP)
	b.disc(coin, 5.6 * u, Pal.SUN)

## The machines' bodies over the belt, the eggs pass under them; a machine
## not bought is a faint outline, so the belt says what it could become.
func _build_front() -> ArrayMesh:
	var b := Face.Builder.new()
	var u := _u
	for m: String in Sim.MACHINE_X:
		var c := px(Vector2(Sim.MACHINE_X[m], Sim.BELT_Y))
		var owned: bool = sim.has(m)
		if not owned:
			if sim.has("belt"):
				b.stroke(Face.Builder.round_rect(c + Vector2(-14, -34) * u, Vector2(28, 22) * u, 5.0 * u), 1.0 * u, Color(1, 1, 1, 0.35), true)
			continue
		match m:
			"washer":
				b.fan(Face.Builder.round_rect(c + Vector2(-16, -38) * u, Vector2(32, 24) * u, 6.0 * u), Art.WASHER_DEEP)
				b.fan(Face.Builder.round_rect(c + Vector2(-15, -38) * u, Vector2(30, 21) * u, 5.0 * u), Art.WASHER)
				b.disc(c + Vector2(-7, -29) * u, 3.4 * u, Color("dff1fb"))
				b.disc(c + Vector2(-7, -29) * u, 1.6 * u, Art.WASHER_DEEP)
				b.fan(Face.Builder.round_rect(c + Vector2(-10, -15) * u, Vector2(20, 3) * u, 1.0 * u), Art.METAL_DEEP)
				for side in [-1.0, 1.0]:
					b.fan(Face.Builder.round_rect(c + Vector2(side * 15.0 - 2.0, -16) * u, Vector2(4, 22) * u, 1.5 * u), Art.METAL_DEEP)
			"stamp":
				for side in [-1.0, 1.0]:
					b.fan(Face.Builder.round_rect(c + Vector2(side * 13.0 - 2.0, -40) * u, Vector2(4, 46) * u, 1.5 * u), Art.METAL_DEEP)
				b.fan(Face.Builder.round_rect(c + Vector2(-15, -44) * u, Vector2(30, 8) * u, 3.0 * u), Art.PRESS_DEEP)
				b.fan(Face.Builder.round_rect(c + Vector2(-14, -44) * u, Vector2(28, 6) * u, 2.5 * u), Art.PRESS)
			"packer":
				b.fan(Face.Builder.round_rect(c + Vector2(-17, -40) * u, Vector2(34, 26) * u, 4.0 * u), Art.CARTON_DEEP)
				b.fan(Face.Builder.round_rect(c + Vector2(-16, -40) * u, Vector2(32, 23) * u, 3.5 * u), Art.CARTON)
				for k in 3:
					Art.egg(b, c + Vector2(-9 + k * 9, -30) * u, 3.6 * u, false, false, true, true, true)
				for side in [-1.0, 1.0]:
					b.fan(Face.Builder.round_rect(c + Vector2(side * 16.0 - 2.0, -16) * u, Vector2(4, 22) * u, 1.5 * u), Art.METAL_DEEP)
	# the crate's front lip, over the eggs going in
	var r := Sim.CRATE
	var at := px(r.position)
	var size := r.size * u
	b.fan(Face.Builder.round_rect(at + Vector2(0, size.y * 0.36), Vector2(size.x, 7.0 * u), 2.0 * u), Art.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(0, size.y * 0.36), Vector2(size.x, 4.0 * u), 2.0 * u), Art.WOOD_HI)
	if b.verts.is_empty():
		return null
	return b.mesh()

func _draw_field() -> void:
	if sim == null or field.size.x <= 0.0:
		return
	var key := "%s/%d,%d,%d,%d,%d" % [field.size, int(sim.has("belt")), int(sim.has("washer")), int(sim.has("stamp")), int(sim.has("packer")), int(sim.has("squirrel"))]
	if key != _built_key:
		_built_key = key
		_ground = _build_ground()
		_front = _build_front()
	field.draw_mesh(_ground, null)
	var b := Face.Builder.new()
	_draw_troughs(b)
	_draw_belt(b)
	_draw_eggs(b, false)
	_draw_glow(b)
	_under = b.mesh() if not b.verts.is_empty() else null
	if _under != null:
		field.draw_mesh(_under, null)
	_draw_birds()
	if _front != null:
		field.draw_mesh(_front, null)
	var o := Face.Builder.new()
	_draw_machines(o)
	_draw_eggs(o, true)
	_draw_marks(o)
	_draw_hearts(o)
	_draw_bubble_box(o)
	_over = o.mesh() if not o.verts.is_empty() else null
	if _over != null:
		field.draw_mesh(_over, null)
	_draw_words()

## The troughs' levels, going red when low; a price tag over each once it
## is worth refilling.
func _draw_troughs(b: Face.Builder) -> void:
	var u := _u
	for which in ["water", "feed"]:
		var r: Rect2 = Sim.TANK if which == "water" else Sim.SILO
		var lv: float = (sim.water if which == "water" else sim.feed) / sim.cap()
		var at := px(r.position)
		var size := r.size * u
		var low := lv < Sim.LOW
		var col := Art.WATER if which == "water" else Art.GRAIN
		var deep := Art.WATER_DEEP if which == "water" else Art.GRAIN_DEEP
		if low:
			var beat := 0.5 + 0.5 * sin(_clock * 8.0) if not Motion.reduce else 0.5
			b.fan(Face.Builder.round_rect(at + Vector2(-6, -6) * u, size + Vector2(12, 12) * u, 9.0 * u), Color(LOW_RED, 0.25 + 0.3 * beat))
		var fill_h := (size.y - 4.0 * u) * clampf(lv, 0.0, 1.0)
		if fill_h > 1.0:
			var f0 := Vector2(at.x + 2.0 * u, at.y + size.y - 2.0 * u - fill_h)
			b.fan(Face.Builder.round_rect(f0, Vector2(size.x - 4.0 * u, fill_h), minf(4.0 * u, fill_h * 0.5)), deep)
			b.fan(Face.Builder.round_rect(f0 + Vector2(2.0 * u, 0), Vector2(size.x - 9.0 * u, fill_h), minf(3.0 * u, fill_h * 0.5)), col)
			if which == "water" and not Motion.reduce:
				for k in 2:
					var by := f0.y + fill_h * fmod(1.0 - fmod(_clock * 0.3 + k * 0.5, 1.0), 1.0)
					b.disc(Vector2(at.x + size.x * (0.35 + k * 0.3), by), 1.4 * u, Color(1, 1, 1, 0.5))
			elif which == "feed":
				for k in 4:
					b.disc(Vector2(at.x + size.x * (0.25 + k * 0.17), f0.y + 2.0 * u), 1.6 * u, GRAIN_BITS[k % 2])
		# the glass's gleam
		b.fan(Face.Builder.round_rect(at + Vector2(size.x - 7.0 * u, 6.0 * u), Vector2(2.5 * u, size.y - 12.0 * u), 1.2 * u), Color(1, 1, 1, 0.45))
		var since: float = _clock - float(_refill_at[which])
		if since < 0.4 and not Motion.reduce:
			b.fan(Face.Builder.round_rect(at, size, 6.0 * u), Color(1, 1, 1, 0.5 * (1.0 - since / 0.4)))
		# the tag
		if lv < 0.6 and sim.phase == Sim.Phase.PLAY:
			var tag := at + Vector2(size.x * 0.5, -16.0 * u)
			var w := 30.0 * u
			var bob := 0.0 if Motion.reduce or not low else sin(_clock * 6.0) * 2.0 * u
			b.fan(Face.Builder.round_rect(tag + Vector2(-w * 0.5, -8.0 * u + bob), Vector2(w, 12.0 * u), 5.0 * u), Color(0.2, 0.14, 0.06, 0.2))
			b.fan(Face.Builder.round_rect(tag + Vector2(-w * 0.5, -9.5 * u + bob), Vector2(w, 12.0 * u), 5.0 * u), LOW_RED if low else TAG)

const GRAIN_BITS := [Color("f7d882"), Color("d19a36")]

## The belt's rubber running: slats sliding along toward the crate.
func _draw_belt(b: Face.Builder) -> void:
	if not sim.has("belt"):
		return
	var u := _u
	var x0 := px(Vector2(Sim.BELT_X0, Sim.BELT_Y)).x
	var x1 := px(Vector2(Sim.CRATE.position.x + 2.0, Sim.BELT_Y)).x
	var y := px(Vector2(0, Sim.BELT_Y)).y
	var hh := (Sim.BELT_HALF - 1.0) * u
	var gap := 12.0 * u
	var run := 0.0 if Motion.reduce else fmod(_clock * Sim.BELT_SPEED * u, gap)
	var x := x0 + run
	while x < x1:
		b.stroke(PackedVector2Array([Vector2(x, y - hh), Vector2(x, y + hh)]), 1.4 * u, Art.BELT_HI)
		x += gap
	for k in 2:
		var rx := x0 if k == 0 else x1
		b.disc(Vector2(rx, y), hh, Art.METAL)
		var a := 0.0 if Motion.reduce else _clock * 5.0
		b.stroke(PackedVector2Array([Vector2(rx, y) + Vector2.from_angle(a) * hh * 0.7, Vector2(rx, y) - Vector2.from_angle(a) * hh * 0.7]), 1.0 * u, Art.METAL_DEEP)

## Eggs on the ground and on the belt (`held` false), or in the finger and
## on a squirrel's back (`held` true). A new egg pops in; a held egg rides
## a little larger.
func _draw_eggs(b: Face.Builder, held: bool) -> void:
	var r := EGG_R * _u
	for e: Dictionary in sim.eggs:
		var st: int = e.st
		var up := st == Sim.Egg.HELD or st == Sim.Egg.CARRIED
		if up != held:
			continue
		var sc := 1.0
		if st == Sim.Egg.GROUND and not Motion.reduce:
			sc = Motion.back_out(clampf(e.age / 0.25, 0.0, 1.0))
			# a fertile egg about to hatch rocks
			if e.fertile and e.age > Sim.HATCH_TIME - 2.5:
				sc *= 1.0 + 0.05 * sin(_clock * 30.0)
		if st == Sim.Egg.HELD:
			sc = 1.18
		if sc <= 0.01:
			continue
		var c := px(e.pos) + Vector2(0, -r * sc)
		if st == Sim.Egg.HELD:
			c += Vector2(0, -10.0 * _u)
		Art.egg(b, c, r * sc, e.gold, e.fertile, e.washed, e.stamped, e.boxed)
		if e.gold and not Motion.reduce and fmod(_clock + e.id * 0.37, 1.6) < 0.2:
			_twinkle(b, c + Vector2(r * 0.4, -r * 0.6), r * 0.7)

func _twinkle(b: Face.Builder, c: Vector2, r: float) -> void:
	b.fan(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.2, 0), c + Vector2(0, r), c + Vector2(-r * 0.2, 0)]), Color(1, 1, 1, 0.9))
	b.fan(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, -r * 0.2), c + Vector2(r, 0), c + Vector2(0, r * 0.2)]), Color(1, 1, 1, 0.9))

## While eggs are held: the crate glows, and the belt too once bought.
func _draw_glow(b: Face.Builder) -> void:
	if _held.is_empty():
		return
	var beat := 0.5 + 0.5 * sin(_clock * 7.0) if not Motion.reduce else 0.6
	var cr := Sim.CRATE
	var near: bool = _finger != Vector2.INF and sim.over_crate(_finger)
	b.fan(Face.Builder.round_rect(px(cr.position) - Vector2(7, 7) * _u, cr.size * _u + Vector2(14, 14) * _u, 10.0 * _u), Color(Pal.SUN, (0.5 if near else 0.22) + 0.15 * beat))
	if sim.has("belt"):
		var on: bool = _finger != Vector2.INF and sim.over_belt(_finger)
		var x0 := px(Vector2(Sim.BELT_X0 - 8.0, 0)).x
		var x1 := px(Vector2(Sim.CRATE.position.x, 0)).x
		var y := px(Vector2(0, Sim.BELT_Y)).y
		var hh := (Sim.BELT_HALF + 6.0) * _u
		b.fan(Face.Builder.round_rect(Vector2(x0, y - hh), Vector2(x1 - x0, hh * 2.0), hh), Color(Pal.SUN, (0.4 if on else 0.16) + 0.12 * beat))

## One draw call a bird, sorted by depth so the nearer stands in front.
func _draw_birds() -> void:
	var all: Array = []
	for h: Dictionary in sim.hens:
		all.append([h.pos.y, 0, h])
	if not sim.rooster.is_empty():
		all.append([sim.rooster.pos.y, 1, sim.rooster])
	for s: Dictionary in sim.squirrels:
		all.append([s.pos.y, 2, s])
	all.sort_custom(func(a: Array, c: Array) -> bool: return a[0] < c[0])
	for row: Array in all:
		var who: int = row[1]
		var d: Dictionary = row[2]
		var face: float = d.face
		var moving: bool = (d.get("to", d.pos) - d.pos).length() > 1.5 if who != 2 else d.st != "home"
		var frame := 0
		if moving and not Motion.reduce:
			frame = int(_clock * 8.0 + d.get("id", 0)) % 2
		var look: int
		var plume := 0
		var bob := 0.0
		var sc := Vector2(face, 1.0)
		match who:
			0:
				plume = int(d.id) % 3
				if d.kind == Sim.Kind.CHICK:
					look = Art.Look.CHICK_SLEEP if d.asleep else Art.Look.CHICK
					var g: float = d.grow
					sc *= 0.8 + 0.4 * g
				elif d.peck > 0.0 and not Motion.reduce and fmod(d.peck, 0.25) > 0.12:
					look = Art.Look.HEN_PECK
				elif d.happy > 0.6:
					look = Art.Look.HEN_HAPPY
				else:
					look = Art.Look.HEN
				if not Motion.reduce and d.kind == Sim.Kind.HEN:
					bob = absf(sin(_clock * 8.0 + d.id)) * 1.2 * _u if moving else 0.0
					# a breath as she stands
					sc.y *= 1.0 + 0.02 * sin(_clock * 3.0 + d.id)
			1:
				look = Art.Look.ROOSTER
				if not Motion.reduce:
					bob = absf(sin(_clock * 7.0)) * 1.2 * _u if moving else 0.0
			2:
				look = Art.Look.SQUIRREL_CARRY if not d.carry.is_empty() else Art.Look.SQUIRREL
				if not Motion.reduce and d.st != "home":
					bob = absf(sin(_clock * 14.0)) * 3.0 * _u
		var m := Art.mesh(look, _u * BIRD, plume, frame)
		var tint := Color.WHITE
		if who == 0 and sim.hungry() and d.kind == Sim.Kind.HEN:
			tint = Color(0.92, 0.9, 0.88)
		field.draw_mesh(m, null, Transform2D(0.0, sc, 0.0, px(d.pos) + Vector2(0, -bob)), tint)

## The machines at work: the washer's shower, the stamp's press coming down,
## the packer's flap.
func _draw_machines(b: Face.Builder) -> void:
	var u := _u
	if sim.has("washer"):
		var c := px(Vector2(Sim.MACHINE_X.washer, Sim.BELT_Y))
		var since: float = _clock - float(_machine_at.washer)
		if since < 0.35:
			for k in 6:
				var ph := fmod(_clock * 3.0 + k * 0.17, 1.0) if not Motion.reduce else 0.5
				var x := -8.0 + k * 3.2
				b.disc(c + Vector2(x, -12.0 + ph * 12.0) * u, 1.0 * u, Color(Art.WATER, 0.85 * (1.0 - ph * 0.5)))
		b.stroke(PackedVector2Array([c + Vector2(-9, -13.5) * u, c + Vector2(9, -13.5) * u]), 1.2 * u, Color(Art.WATER, 0.9))
	if sim.has("stamp"):
		var c := px(Vector2(Sim.MACHINE_X.stamp, Sim.BELT_Y))
		var since: float = _clock - float(_machine_at.stamp)
		var down := 0.0
		if since < 0.18 and not Motion.reduce:
			down = sin(since / 0.18 * PI) * 16.0
		b.fan(Face.Builder.round_rect(c + Vector2(-3, -36 + down) * u, Vector2(6, 16) * u, 1.5 * u), Art.METAL)
		b.fan(Face.Builder.round_rect(c + Vector2(-8, -21 + down) * u, Vector2(16, 5) * u, 2.0 * u), Art.PRESS_DEEP)
		b.fan(Face.Builder.round_rect(c + Vector2(-7, -18 + down) * u, Vector2(14, 2) * u, 1.0 * u), Art.STAMP)
	if sim.has("packer"):
		var c := px(Vector2(Sim.MACHINE_X.packer, Sim.BELT_Y))
		var since: float = _clock - float(_machine_at.packer)
		var flap := 0.0 if Motion.reduce or since > 0.25 else sin(since / 0.25 * PI) * 0.8
		var hinge := c + Vector2(-12, -14) * u
		b.fan(PackedVector2Array([hinge, hinge + Vector2(24, 0).rotated(-flap) * u, hinge + Vector2(24, 3).rotated(-flap) * u, hinge + Vector2(0, 3) * u]), Art.CARTON_DEEP)

## Marks over the birds: a sleeping chick's z, a hungry hen's "!", the
## radio on the fence post, notes over it.
func _draw_marks(b: Face.Builder) -> void:
	var u := _u
	if sim.hungry():
		var beat := 1.0 if Motion.reduce else 0.85 + 0.15 * sin(_clock * 10.0)
		for h: Dictionary in sim.hens:
			if h.kind != Sim.Kind.HEN or int(h.id) % 2 == 1:
				continue
			var c := px(h.pos + Vector2(0, -42))
			b.fan(Face.Builder.round_rect(c + Vector2(-3.2, -7.5) * u * beat, Vector2(6.4, 12) * u * beat, 3.0 * u), LOW_RED)
			b.stroke(PackedVector2Array([c + Vector2(0, -5) * u, c + Vector2(0, 0) * u]), 1.4 * u, Color("fffaf0"))
			b.disc(c + Vector2(0, 2.4) * u, 0.9 * u, Color("fffaf0"))
	if sim.has("radio"):
		var at := px(Vector2(Sim.FENCE.position.x + 10.0, Sim.FENCE.position.y - 4.0))
		var hop := 0.0 if Motion.reduce else absf(sin(_clock * 6.0)) * 1.2 * u
		b.fan(Face.Builder.round_rect(at + Vector2(-9, -9) * u + Vector2(0, -hop), Vector2(18, 11) * u, 2.5 * u), Color("c45b4a"))
		b.fan(Face.Builder.round_rect(at + Vector2(-7, -7.5) * u + Vector2(0, -hop), Vector2(8, 8) * u, 1.5 * u), Color("f3e2c4"))
		b.disc(at + Vector2(5, -3.5) * u + Vector2(0, -hop), 2.2 * u, Art.INK)
		b.stroke(PackedVector2Array([at + Vector2(-5, -9) * u, at + Vector2(3, -15) * u]), 0.8 * u, Art.METAL_DEEP)
		if not Motion.reduce:
			for k in 2:
				var ph := fmod(_clock * 0.6 + k * 0.5, 1.0)
				var n := at + Vector2(10 + ph * 10.0 + k * 4.0, -14 - ph * 16.0) * u
				var a := sin(ph * PI)
				b.disc(n, 1.8 * u, Color(Art.INK, a))
				b.stroke(PackedVector2Array([n + Vector2(1.6, 0) * u, n + Vector2(1.6, -6) * u]), 0.7 * u, Color(Art.INK, a))

func _draw_hearts(b: Face.Builder) -> void:
	for h: Dictionary in _hearts:
		var k: float = h.t / 0.9
		var c := px(h.pos) + Vector2(sin(k * 7.0) * 3.0 * _u, -k * 16.0 * _u)
		var r := 3.2 * _u * (1.0 if Motion.reduce else Motion.back_out(minf(1.0, k * 4.0)))
		Art._heart(b, c, r, Color(Art.HEART, 1.0 - k * k))

## The paper under a hen's hello, over her head.
func _draw_bubble_box(b: Face.Builder) -> void:
	if _bubble.is_empty():
		return
	var h: Dictionary = sim.hen_by_id(_bubble.id)
	if h.is_empty():
		return
	var font := get_theme_font("font", "CardBlurb")
	var fs := 24
	var w := font.get_string_size(_bubble.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0
	var c := _bubble_at(h, w)
	var a := _bubble_alpha()
	b.fan(Face.Builder.round_rect(c + Vector2(-w * 0.5, -22 + 3), Vector2(w, 42), 14.0), Color(0.2, 0.14, 0.06, 0.2 * a))
	b.fan(Face.Builder.round_rect(c + Vector2(-w * 0.5, -22), Vector2(w, 42), 14.0), Color(TAG, a))
	var tip := c + Vector2(0, 20)
	b.fan(PackedVector2Array([tip + Vector2(-8, 0), tip + Vector2(8, 0), tip + Vector2(0, 10)]), Color(TAG, a))

func _bubble_at(h: Dictionary, w: float) -> Vector2:
	var c := px(h.pos + Vector2(0, -44))
	c.x = clampf(c.x, w * 0.5 + 6.0, field.size.x - w * 0.5 - 6.0)
	c.y = maxf(c.y, 30.0)
	return c

func _bubble_alpha() -> float:
	var t: float = _bubble.t
	return clampf(t / 0.15, 0.0, 1.0) * (1.0 - clampf((t - 2.0) / 0.4, 0.0, 1.0))

## The words: the troughs' tags, the belt's for-sale sign, a hen's hello,
## a sleeping chick's z and the numbers rising off the crate.
func _draw_words() -> void:
	var font := get_theme_font("font", "SheetTitle")
	var small := get_theme_font("font", "CardBlurb")
	var u := _u
	if sim.phase == Sim.Phase.PLAY:
		for which in ["water", "feed"]:
			var r: Rect2 = Sim.TANK if which == "water" else Sim.SILO
			var lv: float = (sim.water if which == "water" else sim.feed) / sim.cap()
			if lv >= 0.6:
				continue
			var low := lv < Sim.LOW
			var bob := 0.0 if Motion.reduce or not low else sin(_clock * 6.0) * 2.0 * u
			var text := "$" + _money(sim.refill_cost(which))
			var fs := int(clampf(8.0 * u, 16.0, 30.0))
			var w := small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tag := px(r.position) + Vector2(r.size.x * u * 0.5, -16.0 * u)
			field.draw_string(small, tag + Vector2(-w * 0.5, -0.5 * u + bob), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fffaf0") if low else Pal.TEXT)
	if not sim.has("belt"):
		var c := Vector2((px(Vector2(Sim.BELT_X0, 0)).x + px(Vector2(Sim.CRATE.position.x, 0)).x) * 0.5, px(Vector2(0, Sim.BELT_Y)).y)
		var text := tr("HH_FOR_SALE")
		var fs := int(clampf(8.0 * u, 16.0, 28.0))
		var w := small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		field.draw_string(small, c + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT_DIM)
	for h: Dictionary in sim.hens:
		if h.kind == Sim.Kind.CHICK and h.asleep:
			var ph := 0.0 if Motion.reduce else fmod(_clock * 0.7 + h.id * 0.3, 1.0)
			var c := px(h.pos + Vector2(8, -18 - ph * 10.0))
			field.draw_string(font, c, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 + ph * 10), Color(Art.INK, 0.8 * (1.0 - ph * 0.6)))
	if not _bubble.is_empty():
		var h: Dictionary = sim.hen_by_id(_bubble.id)
		if not h.is_empty():
			var fs := 24
			var w := small.get_string_size(_bubble.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var c := _bubble_at(h, w + 28.0)
			field.draw_string(small, c + Vector2(-w * 0.5, 8), _bubble.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.TEXT, _bubble_alpha()))
	for p: Dictionary in _pops:
		var k: float = p.t
		var a := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
		var at := px(p.pos) + Vector2(0, -40.0 * (1.0 - exp(-k * 4.0)))
		var full := 44 if p.big else 34
		var fs := full if Motion.reduce else maxi(8, int(lerpf(12.0, full, Motion.back_out(minf(1.0, k / 0.22)))))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := Vector2(clampf(at.x - w * 0.5, 4.0, field.size.x - w - 4.0), maxf(at.y, 40.0))
		field.draw_string_outline(font, o + Vector2(0, 3), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.2, 0.12, 0.05, 0.35 * a))
		field.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(Art.INK, a))
		field.draw_string(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.col, a))

func _pop(at: Vector2, text: String, col: Color, big: bool) -> void:
	_pops.append({"pos": at, "text": text, "t": 0.0, "col": col, "big": big})
	if _pops.size() > 8:
		_pops.pop_front()

# --- the end ---

func _finish(won: bool) -> void:
	_held.clear()
	_radio.stop()
	var secs := int(sim.t)
	var better: bool = Record.add_time(GAME, secs if won else 0, sim.best_flock)
	Analytics.track("arcade_end", {"game": GAME, "score": secs if won else 0, "stage": sim.best_flock,
		"seconds": int((Time.get_ticks_msec() - _started_at) / 1000.0), "won": won, "earned": int(sim.earned),
		"sold": sim.sold, "hatched": sim.hatched, "lost": sim.lost, "best": better})
	_fx.cue("retire" if won else "game_over")
	_show_banner(tr("HH_RETIRED") if won else tr("HH_CLOSED"), "", 1.2)
	top_bar.refresh(self)
	get_tree().create_timer(1.8).timeout.connect(_show_end.bind(better, won))

func _show_end(better: bool, won: bool) -> void:
	if sim == null or not sim.is_over() or _end != null:
		return
	if better:
		_fx.cue("new_best")
	_end = _build_end(better, won)
	add_child(_end)
	Motion.appear(_end, 0.0, 1.0, 0.3)
	_celebrate(better or won)

func _build_end(better: bool, won: bool) -> Control:
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
	# a hen, with the rooster beside her once retired, on a bed of straw
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(0, 200)
	seat.draw.connect(func() -> void:
		var c := Vector2(seat.size.x * 0.5, 176.0)
		var t := 0.0 if Motion.reduce else _clock
		var u := 5.5
		var hop := 0.0 if Motion.reduce else absf(sin(t * 3.0)) * 8.0
		var look := Art.Look.HEN_HAPPY if won else Art.Look.HEN
		if won:
			seat.draw_mesh(Art.mesh(Art.Look.ROOSTER, u * 0.9), null, Transform2D(0.0, Vector2(-1, 1), 0.0, c + Vector2(90, 0)))
			seat.draw_mesh(Art.mesh(Art.Look.CHICK, u * 0.9), null, Transform2D(0.0, c + Vector2(-96, -hop * 0.6)))
		seat.draw_mesh(Art.mesh(look, u, 1), null, Transform2D(sin(t * 1.6) * 0.04, c + Vector2(0, -hop))))
	col.add_child(seat)
	var head := Label.new()
	head.text = "HH_NEW_BEST" if better else ("HH_RETIRED" if won else "HH_CLOSED")
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var line := Label.new()
	line.text = (tr("HH_END_WON") % clock_text(int(sim.t))) if won else tr("HH_END_LOST")
	line.theme_type_variation = "SheetTitle"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 14)
	for pair in [["$" + _money(sim.earned), "HH_STAT_EARNED"], [Record.grouped(sim.sold), "HH_STAT_SOLD"], [str(sim.best_flock), "HH_STAT_FLOCK"]]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 26, 12))
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
	var best := Record.best(GAME)
	var best_line := Label.new()
	best_line.text = tr("HH_BEST_TIME") % clock_text(best) if best > 0 else ""
	best_line.theme_type_variation = "SheetBodyDim"
	best_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_line.visible = best > 0
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
	scrim.set_meta("seat", seat)
	return scrim

func _celebrate(big: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not big:
		return
	var fx := Fx2D.new()
	_end.add_child(fx)
	var cols := [Art.EGG_GOLD, Art.COMB, Art.CHICK, Pal.FLOWER, Pal.SUN_RAY, Art.WATER]
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
	if sim != null and not sim.is_over() and sim.t > 5.0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": int(sim.earned), "stage": sim.best_flock})
	_radio.stop()
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()

# --- the shop's chips ---

## A paper chip for one shop item: its picture on the left, its name, what
## it does, and its price (or Owned, or its level's pips). Dimmed when the
## money is short, but still pressable, so the refusal can say why.
class _ShopChip extends Button:
	var item := ""
	var host: Control
	var _key := ""

	func _init(h: Control, it: String) -> void:
		host = h
		item = it
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 146)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		material = CanvasItemMaterial.new()
		_style(true)

	func _style(ok: bool) -> void:
		for st in ["normal", "hover", "focus"]:
			add_theme_stylebox_override(st, CozyTheme.chip(Color("fffdf8") if ok else Color("efe7da"), 26))
		add_theme_stylebox_override("pressed", CozyTheme.chip(Color("fffdf8"), 26, Color.TRANSPARENT, 0, true))

	## Redraws when what it shows changes.
	func sync() -> void:
		var sim: RefCounted = host.sim
		if sim == null:
			return
		var p: int = sim.price(item)
		var ok: bool = p >= 0 and sim.money >= p
		var key := "%d/%s/%d" % [p, ok, sim.level(item)]
		if key != _key:
			_key = key
			_style(ok or p < 0)
			queue_redraw()

	func _draw() -> void:
		var sim: RefCounted = host.sim
		if sim == null:
			return
		var p: int = sim.price(item)
		var ok: bool = p >= 0 and sim.money >= p
		var alpha := 1.0 if ok or p < 0 else 0.55
		var pic := minf(size.y - 30.0, 100.0)
		draw_mesh(Art.icon(item, pic), null, Transform2D(0.0, Vector2(18.0 + pic * 0.5, size.y * 0.5)), Color(1, 1, 1, alpha))
		var font := get_theme_font("font", "SheetTitle")
		var small := get_theme_font("font", "CardBlurb")
		var x := 30.0 + pic
		var room := size.x - x - 10.0
		var name_s := tr("HH_I_" + item.to_upper())
		var fs := 28
		while font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room and fs > 16:
			fs -= 1
		draw_string(font, Vector2(x, 44), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.TEXT, alpha))
		var d := tr("HH_D_" + item.to_upper())
		var ds := 20
		while small.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, ds).x > room and ds > 13:
			ds -= 1
		draw_string(small, Vector2(x, 76), d, HORIZONTAL_ALIGNMENT_LEFT, -1, ds, Color(Pal.TEXT_DIM, alpha))
		var lv: int = sim.level(item)
		var most: int = sim.max_level(item)
		if item == "hen":
			lv = 0
			most = 1
		if most > 1:
			for k in most:
				draw_circle(Vector2(x + 8 + k * 18, 94), 6.0, Pal.SUN if k < lv else Color(Pal.TEXT_DIM, 0.3))
		var y := size.y - 20.0
		if p < 0:
			var word := tr("HH_OWNED") if item != "hen" else tr("HH_FULL")
			draw_string(small, Vector2(x, y), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("5f8f4a"))
			return
		var price := "$" + Record.grouped(p)
		var ps := 28
		while font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, ps).x > room - 24 and ps > 16:
			ps -= 1
		var coin := Vector2(x + 9, y - ps * 0.35)
		draw_circle(coin, 9.0, Color(Pal.SUN, alpha))
		draw_circle(coin, 5.0, Color(Pal.SUN_RAY, alpha))
		draw_string(font, Vector2(x + 24, y), price, HORIZONTAL_ALIGNMENT_LEFT, -1, ps, Pal.TEXT if ok else Pal.TEXT_DIM)

## The retire button: how far to the million, as a bar filling behind the
## word, and a sun-yellow button once it can be bought.
class _RetireButton extends Button:
	var host: Control
	var _key := ""

	func _init(h: Control) -> void:
		host = h
		focus_mode = Control.FOCUS_NONE
		material = CanvasItemMaterial.new()
		for st in ["normal", "hover", "focus", "pressed"]:
			add_theme_stylebox_override(st, CozyTheme.chip(Color("efe7da"), 26))

	func sync() -> void:
		var sim: RefCounted = host.sim
		if sim == null:
			return
		var k := int(clampf(sim.money / float(Sim.RETIRE), 0.0, 1.0) * 200.0)
		var key := str(k)
		if key != _key:
			_key = key
			queue_redraw()

	func _draw() -> void:
		var sim: RefCounted = host.sim
		if sim == null:
			return
		var f := clampf(sim.money / float(Sim.RETIRE), 0.0, 1.0)
		var ready := f >= 1.0
		var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
		if f > 0.0:
			draw_style_box(CozyTheme.chip(Pal.SUN if ready else Color("f6dc93"), 22), Rect2(r.position, Vector2(maxf(44.0, r.size.x * f), r.size.y)))
		var pic := size.y - 18.0
		draw_mesh(Art.icon("retire", pic), null, Transform2D(0.0, Vector2(16 + pic * 0.5, size.y * 0.5)))
		var font := get_theme_font("font", "SheetTitle")
		var small := get_theme_font("font", "CardBlurb")
		var word := tr("HH_RETIRE")
		draw_string(font, Vector2(28 + pic, size.y * 0.5 - 2), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.TEXT)
		draw_string(small, Vector2(28 + pic, size.y * 0.5 + 26), "$" + Record.grouped(Sim.RETIRE), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.TEXT_DIM)
