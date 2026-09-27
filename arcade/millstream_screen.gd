extends Control

## Millstream: the fifth game on the Arcade tab, a small factory in a
## painted valley (spec docs/superpowers/specs/2026-09-27-arcade-millstream-design.md).
## The flat boards' top bar (back, the title in ink, restart, settings), a
## paper row with the stock and the time, the valley in the Arcade's wooden
## frame, and the panel under it: the milestone card with its Hand in
## button, and the tools.
##
## Play, by touch and never by walking: one finger pans, two pinch to zoom
## (the wheel on a desktop), and a tap acts. A tap on an iron deposit digs
## an ore (hold to keep digging), on a kiln collects its ingots and loads
## its hopper, on the Mill hands the milestone in. With the Kiln tool a tap
## places one (the ghost shows where while the finger is down), with the
## eraser a tap lifts one. The game is arcade/millstream_sim.gd, stepped at
## its fixed DT; this screen draws it, plays its events and keeps the save
## (user://millstream.cfg), which the factory resumes from.
##
## Drawing, all through the camera's transform so a pan or a zoom rebuilds
## nothing: the valley (one mesh, built once), the buildings (one mesh,
## rebuilt when one is placed or lifted), then one live mesh a frame (the
## wheel, the kilns' fire, smoke and stores, flying ore and ingots, the
## ghost), then the few numbers as text.

signal closed

const Sim = preload("res://arcade/millstream_sim.gd")
const Art = preload("res://arcade/millstream_art.gd")
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
const Analytics = preload("res://core/analytics.gd")

const GAME := "millstream"
const SAVE_PATH := "user://millstream.cfg"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
const PANEL_H := 330.0
const BACKDROP_BLEED := 90.0
const MAX_STEPS := 12
const AUTOSAVE := 30.0
## A finger that moves this far (screen px) is panning, not tapping.
const SLOP := 18.0
## Held on a deposit this long, the finger digs, and again every DIG_EVERY.
const HOLD := 0.35
const DIG_EVERY := 0.28
const HINT_HOLD := 4.5
const TAG := Color("fffaf0")
const LOW_RED := Color("e2645c")

var sim: Sim
var top_bar: Control
var settings_sheet: Control
var field: Control
var _fx: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _ore_l: Label
var _ingot_l: Label
var _time_l: Label
var _banner: Label
var _sub: Label
var _banner_tw: Tween
var _toast: PanelContainer
var _toast_l: Label
var _toast_tw: Tween
var _ms_kicker: Label
var _ms_title: Label
var _ms_bar: Control
var _hand_in: Button
var _chips := {}
var _clock := 0.0
var _acc := 0.0
var _save_acc := 0.0
var _paused := false
## The camera: the world point (world px) at the field's centre, and the
## screen pixels a world pixel takes.
var _cam := Vector2.ZERO
var _zoom := 1.0
var _fitted := false
## The fingers down on the field: index -> screen position.
var _touches := {}
var _press_at := Vector2.ZERO
var _press_t := 0.0
var _panning := false
var _pinch_d := 0.0
var _pinch_zoom := 1.0
var _dig_t := 0.0
var _digging := false
var _tool := ""
## The placing ghost: its top-left cell, while the finger is down.
var _ghost := Vector2i(-99, -99)
var _ghost_live := false
var _ground: ArrayMesh
var _built: ArrayMesh
var _live: ArrayMesh
var _built_key := "?"
## Effects in world px: fliers {from, to, t, dur, what}, pops {at, text, t, col}.
var _fliers: Array = []
var _pops: Array = []
var _shake := {}
var _hints_said := {}
var _started := false
var _brook: AudioStreamPlayer

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
	_open()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()

# --- building the screen ---

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

	top_bar = FlatTopBar.new("Millstream", tr("MS_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
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
	_banner.add_theme_color_override("font_color", TAG)
	_banner.add_theme_color_override("font_shadow_color", Color(0.2, 0.14, 0.06, 0.55))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	over.add_child(_banner)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetTitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", TAG)
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

	col.add_child(_build_panel())

	# the valley's bed: the brook and the wheel, looped very quietly
	_brook = AudioStreamPlayer.new()
	var brook_path := "res://assets/sfx/%s/brook.ogg" % GAME
	if ResourceLoader.exists(brook_path):
		var stream: AudioStreamOggVorbis = (load(brook_path) as AudioStreamOggVorbis).duplicate()
		stream.loop = true
		_brook.stream = stream
	_brook.volume_db = -8.0
	add_child(_brook)
	_apply_insets()

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["MS_ORE", "MS_INGOTS", "MH_TIME"]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_ore_l = made[0]
	_ingot_l = made[1]
	_time_l = made[2]
	return row

## The panel under the valley: the milestone card on top, the tools under.
func _build_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size.y = PANEL_H
	panel.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 36, 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var ms := HBoxContainer.new()
	ms.add_theme_constant_override("separation", 16)
	box.add_child(ms)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	ms.add_child(words)
	_ms_kicker = Label.new()
	_ms_kicker.theme_type_variation = "MenuKicker"
	words.add_child(_ms_kicker)
	_ms_title = Label.new()
	_ms_title.theme_type_variation = "SheetTitle"
	words.add_child(_ms_title)
	_ms_bar = _Bar.new(self)
	_ms_bar.custom_minimum_size.y = 34
	words.add_child(_ms_bar)
	_hand_in = Button.new()
	_hand_in.name = "HandIn"
	_hand_in.text = "MS_HAND_IN"
	_hand_in.theme_type_variation = "SunButton"
	_hand_in.custom_minimum_size = Vector2(250, 96)
	_hand_in.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_in.focus_mode = Control.FOCUS_NONE
	_hand_in.pressed.connect(_on_hand_in)
	ms.add_child(_hand_in)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	tools.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tools)
	for kind in ["kiln", "eraser", "drill"]:
		var chip := _Chip.new(self, kind)
		chip.name = "Tool_" + kind
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(_on_tool.bind(kind))
		tools.add_child(chip)
		_chips[kind] = chip
	return panel

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	if not _fitted:
		_fitted = true
		_zoom = s.x / (10.0 * Art.TILE)
		_cam = Vector2(7.0, 13.0) * Art.TILE
	_clamp_cam()
	var box: Control = _banner.get_meta("box")
	box.position = Vector2(20, s.y * 0.26)
	box.size = Vector2(s.x - 40, 0)
	field.queue_redraw()

# --- the camera ---

func _world_size() -> Vector2:
	return Vector2(Sim.COLS, Sim.ROWS) * Art.TILE

func _min_zoom() -> float:
	var w := _world_size()
	return minf(field.size.x / w.x, field.size.y / w.y)

func _max_zoom() -> float:
	return field.size.x / (3.5 * Art.TILE)

## Keeps the valley in view: a side smaller than the field is centred, a
## larger one cannot be dragged past its edge.
func _clamp_cam() -> void:
	_zoom = clampf(_zoom, _min_zoom(), _max_zoom())
	var half := field.size * 0.5 / _zoom
	var w := _world_size()
	for axis in 2:
		if half[axis] * 2.0 >= w[axis]:
			_cam[axis] = w[axis] * 0.5
		else:
			_cam[axis] = clampf(_cam[axis], half[axis], w[axis] - half[axis])

func _view() -> Transform2D:
	return Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, field.size * 0.5 - _cam * _zoom)

## A world point (world px) on the screen (field px), and back.
func screen(p: Vector2) -> Vector2:
	return (p - _cam) * _zoom + field.size * 0.5

func world(at: Vector2) -> Vector2:
	return (at - field.size * 0.5) / _zoom + _cam

func cell_at(at: Vector2) -> Vector2i:
	var p := world(at) / Art.TILE
	return Vector2i(floori(p.x), floori(p.y))

## Where a 2x2 goes for a finger at `at`: centred on the grid corner nearest it.
func _foot_at(at: Vector2) -> Vector2i:
	var p := world(at) / Art.TILE
	return Vector2i(roundi(p.x) - 1, roundi(p.y) - 1)

func _zoom_about(at: Vector2, z: float) -> void:
	var before := world(at)
	_zoom = z
	_clamp_cam()
	_cam += before - world(at)
	_clamp_cam()

# --- the game ---

func _open() -> void:
	var resumed := false
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK and cfg.has_section_key("game", "state"):
		sim = Sim.from_dict(cfg.get_value("game", "state", {})) as Sim
		resumed = sim.t > 0.0
		var cam: Variant = cfg.get_value("game", "cam", null)
		if cam is Vector3:
			_cam = Vector2(cam.x, cam.y)
			_zoom = cam.z
			_fitted = true
	else:
		sim = Sim.new()
	_begin(resumed)

func _begin(resumed: bool) -> void:
	_acc = 0.0
	_save_acc = 0.0
	_fliers.clear()
	_pops.clear()
	_hints_said.clear()
	_built_key = "?"
	_set_tool("")
	_refresh()
	top_bar.refresh(self)
	_fx.cue("start")
	if _brook.stream != null and not _brook.playing:
		_brook.play()
	Analytics.track("arcade_start", {"game": GAME, "resumed": resumed})
	_started = true
	if resumed:
		_hints_said["dig"] = true

func save() -> void:
	if sim == null:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("game", "state", sim.to_dict())
	cfg.set_value("game", "cam", Vector3(_cam.x, _cam.y, _zoom))
	cfg.save(SAVE_PATH)

func capabilities() -> Array:
	return []

func is_done() -> bool:
	return false

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

func hints_left() -> int:
	return 0

func _process(delta: float) -> void:
	if sim == null:
		return
	_paused = settings_sheet.is_open()
	if _brook.stream != null:
		_brook.stream_paused = _paused
	if not _paused:
		_clock += delta
		_acc += minf(delta, Sim.DT * MAX_STEPS)
		while _acc >= Sim.DT:
			_acc -= Sim.DT
			sim.step()
			_play_events()
		_save_acc += delta
		if _save_acc >= AUTOSAVE:
			_save_acc = 0.0
			save()
		_held_dig(delta)
		_animate(delta)
		_hints()
	_refresh()
	field.queue_redraw()

func _animate(delta: float) -> void:
	for f: Dictionary in _fliers:
		f.t += delta
	_fliers = _fliers.filter(func(f: Dictionary) -> bool: return f.t < f.dur)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 1.0)
	for id in _shake.keys():
		_shake[id] = float(_shake[id]) - delta
		if _shake[id] <= 0.0:
			_shake.erase(id)

# --- the finger ---

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		_finger(te.index, te.position, 1 if te.pressed else -1)
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		_finger(de.index, de.position, 0)
	elif event is InputEventMouseButton:
		var me := event as InputEventMouseButton
		if me.button_index == MOUSE_BUTTON_WHEEL_UP and me.pressed:
			_zoom_about(me.position, _zoom * 1.1)
		elif me.button_index == MOUSE_BUTTON_WHEEL_DOWN and me.pressed:
			_zoom_about(me.position, _zoom / 1.1)
		elif me.button_index == MOUSE_BUTTON_LEFT:
			_finger(0, me.position, 1 if me.pressed else -1)
	elif event is InputEventMouseMotion:
		if _touches.has(0) and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_finger(0, (event as InputEventMouseMotion).position, 0)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_zoom_about(mg.position, _zoom * mg.factor)

## One finger's news: `phase` 1 down, 0 moved, -1 up.
func _finger(index: int, at: Vector2, phase: int) -> void:
	if phase == 1:
		_touches[index] = at
		if _touches.size() == 1:
			press(at)
		elif _touches.size() == 2:
			# a second finger turns the gesture into a pinch; nothing is tapped
			_panning = true
			_digging = false
			_ghost_live = false
			var pts: Array = _touches.values()
			_pinch_d = maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
			_pinch_zoom = _zoom
		return
	if not _touches.has(index):
		return
	if phase == 0:
		var was: Vector2 = _touches[index]
		_touches[index] = at
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var mid: Vector2 = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
			var d := maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
			_zoom_about(mid, _pinch_zoom * d / _pinch_d)
			_cam -= (at - was) * 0.5 / _zoom
			_clamp_cam()
			return
		move(at, was)
		return
	_touches.erase(index)
	if _touches.is_empty():
		lift(at)
	elif _touches.size() == 1:
		# back to one finger: it pans from where it is
		_panning = true

func press(at: Vector2) -> void:
	_press_at = at
	_press_t = _clock
	_panning = false
	_digging = false
	_dig_t = 0.0
	if _tool == "kiln":
		_ghost = _foot_at(at)
		_ghost_live = true

func move(at: Vector2, was: Vector2) -> void:
	if not _panning and at.distance_to(_press_at) > SLOP:
		_panning = true
		_ghost_live = false
		_digging = false
		# the slop is paid back, so the valley does not jump
		was = _press_at
	if _panning:
		_cam -= (at - was) / _zoom
		_clamp_cam()

func lift(at: Vector2) -> void:
	var tapped := not _panning and not _digging
	_ghost_live = false
	_digging = false
	if tapped:
		tap(at)
	_panning = false

## Held still on a live deposit, the finger keeps digging.
func _held_dig(delta: float) -> void:
	if _touches.size() != 1 or _panning or _tool != "":
		return
	if not _digging:
		if _clock - _press_t < HOLD:
			return
		var i := sim.deposit_at(cell_at(_press_at))
		if i < 0 or not Sim.is_live(i):
			return
		_digging = true
		_dig_t = 0.0
		_dig(cell_at(_press_at))
		return
	_dig_t += delta
	if _dig_t >= DIG_EVERY:
		_dig_t -= DIG_EVERY
		_dig(cell_at(_press_at))

func tap(at: Vector2) -> void:
	var c := cell_at(at)
	match _tool:
		"kiln":
			var foot := _foot_at(at)
			if sim.place("kiln", foot):
				save()
			_play_events()
			if not sim.affordable("kiln"):
				_set_tool("")
			return
		"eraser":
			var b: Dictionary = sim.building_at(c)
			if b.is_empty():
				_say(tr("MS_ERASE_WHAT"), 2.5)
				_fx.cue("refused")
			else:
				sim.remove(b.id)
				_play_events()
				save()
			return
	if sim.deposit_at(c) >= 0:
		_dig(c)
		return
	var b: Dictionary = sim.building_at(c)
	if not b.is_empty():
		sim.tend(b.id)
		_play_events()
		return
	if sim.owner_at(c) == "mill":
		if sim.can_hand_in():
			_on_hand_in()
		else:
			_say(_need_text(), 3.0)
		return

func _dig(c: Vector2i) -> void:
	sim.dig(c)
	_play_events()

func _on_tool(kind: String) -> void:
	if kind == "drill":
		_say(tr("MS_DRILL_LATER"), 3.0)
		_fx.cue("refused")
		_set_tool(_tool)
		return
	if kind == "kiln" and _tool != "kiln" and not sim.affordable("kiln"):
		_say(tr("MS_KILN_COST_SHORT") % int(Sim.COSTS.kiln.iron_ore), 3.0)
		_fx.cue("refused")
		_set_tool(_tool)
		return
	_set_tool("" if _tool == kind else kind)
	if _tool == "kiln":
		_hint_once("place", tr("MS_HINT_PLACE"))

func _set_tool(kind: String) -> void:
	_tool = kind
	for k: String in _chips:
		(_chips[k] as Button).button_pressed = k == kind
		(_chips[k] as Control).queue_redraw()

func _on_hand_in() -> void:
	if sim.hand_in():
		save()
	_play_events()

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		match String(ev.type):
			"dig":
				var r := Sim.deposit_rect(ev.dep)
				var c := (Vector2(r.position) + Vector2(1, 1)) * Art.TILE
				var from := c + Vector2(randf_range(-24, 24), randf_range(-24, 8))
				_fliers.append({"from": from, "to": from + Vector2(randf_range(-30, 30), -90), "t": 0.0, "dur": 0.55, "what": "ore", "arc": 50.0})
				_pops.append({"at": from + Vector2(0, -40), "text": "+1", "t": 0.0, "col": TAG})
				_shake["dep:%d" % ev.dep] = 0.12
				_fx.cue("dig", randf_range(0.9, 1.12), -2.0)
				_fx.puff(screen(from), Art.ROCK_HI, 3)
			"locked":
				_say(tr("MS_LOCKED_" + String(ev.res).to_upper()), 3.0)
				_fx.cue("refused")
			"placed":
				var at := (Vector2(ev.cell) + Vector2(1, 1)) * Art.TILE
				_fx.cue("place")
				_fx.puff(screen(at + Vector2(0, 30)), Color("e8dcc4"), 8)
				_shake["b:%d" % ev.id] = 0.25
				_hint_once("tend", tr("MS_HINT_TEND"))
			"removed":
				var at := (Vector2(ev.cell) + Vector2(1, 1)) * Art.TILE
				_fx.cue("remove")
				_fx.puff(screen(at), Color("e8dcc4"), 10)
			"refused":
				var why := String(ev.why)
				if why == "cost":
					_say(tr("MS_KILN_COST_SHORT") % int(Sim.COSTS.kiln.iron_ore), 3.0)
				elif why == "milestone":
					_say(_need_text(), 3.0)
				else:
					_say(tr("MS_NO_ROOM_" + why.to_upper()), 2.5)
				_fx.cue("refused")
			"load":
				var b: Dictionary = sim.by_id(ev.id)
				var mouth := _mouth(b)
				for k in mini(int(ev.n), 5):
					var from := mouth + Vector2(randf_range(-60, 60), 70 + k * 6)
					_fliers.append({"from": from, "to": mouth, "t": -k * 0.06, "dur": 0.4 + k * 0.06, "what": "ore", "arc": 40.0})
				_pops.append({"at": mouth + Vector2(0, -70), "text": "+%d" % ev.n, "t": 0.0, "col": Art.ORE.iron[2]})
				_fx.cue("load", randf_range(0.95, 1.08))
			"collect":
				var b: Dictionary = sim.by_id(ev.id)
				var mouth := _mouth(b)
				for k in mini(int(ev.n), 6):
					_fliers.append({"from": mouth, "to": mouth + Vector2(randf_range(-40, 40), -110), "t": -k * 0.05, "dur": 0.5 + k * 0.05, "what": "ingot", "arc": 30.0})
				_pops.append({"at": mouth + Vector2(0, -120), "text": "+%d" % ev.n, "t": 0.0, "col": Art.INGOT_HI})
				_fx.cue("collect", randf_range(0.95, 1.06))
			"idle":
				var why := String(ev.why)
				_say(tr("MS_KILN_FULL") if why == "full" else tr("MS_KILN_NO_ORE"), 2.5)
				_fx.cue("refused")
			"smelt":
				var b: Dictionary = sim.by_id(ev.id)
				_fx.cue("smelt", randf_range(0.92, 1.1), -6.0)
				_shake["glow:%d" % ev.id] = 0.3
				if not b.is_empty() and int(b.shelf) == Sim.SHELF:
					_say(tr("MS_KILN_FULL"), 2.5)
			"milestone":
				_on_milestone(ev)
	sim.events.clear()

func _on_milestone(ev: Dictionary) -> void:
	var mill := (Vector2(Sim.MILL.position) + Vector2(Sim.MILL.size) * 0.5) * Art.TILE
	_fx.cue("hand_in")
	_fx.sparkle(screen(mill), Pal.SUN)
	_fx.ring(screen(mill), 90.0 * _zoom * 2.0)
	if not ev.done:
		return
	var secs := int(round(sim.done_t))
	var better := Record.add_time(GAME, secs, sim.milestone)
	Analytics.track("arcade_end", {"game": GAME, "score": secs, "stage": sim.milestone, "won": true,
		"mined": sim.mined, "smelted": sim.smelted, "kilns": sim.buildings.size()})
	_show_banner(tr("MS_M1_DONE"), tr("MS_M1_NEXT") % _clock_text(secs), 4.5)
	_fx.cue("new_best" if better else "milestone")
	_celebrate(mill)

func _celebrate(at: Vector2) -> void:
	if Motion.reduce:
		return
	var cols := [Pal.SUN, Art.INGOT_HI, Art.ORE.iron[2], Color("fff6e0")]
	for k in 8:
		var fx := _fx
		get_tree().create_timer(k * 0.12).timeout.connect(func() -> void:
			if is_instance_valid(fx):
				fx.puff(screen(at + Vector2(randf_range(-120, 120), randf_range(-100, 60))), cols[k % cols.size()], 12))

func _mouth(b: Dictionary) -> Vector2:
	if b.is_empty():
		return Vector2.ZERO
	return (Vector2(b.cell) + Vector2(1, 1)) * Art.TILE + Vector2(0, 18)

## Each lesson the valley teaches, said once, when it first applies.
func _hints() -> void:
	if _clock > 1.2:
		_hint_once("dig", tr("MS_HINT_DIG"))
	if int(sim.stock.iron_ore) >= int(Sim.COSTS.kiln.iron_ore) and sim.buildings.is_empty():
		_hint_once("kiln", tr("MS_HINT_KILN"))
	if sim.can_hand_in():
		_hint_once("hand_in", tr("MS_HINT_HAND_IN"))

func _hint_once(key: String, text: String) -> void:
	if _hints_said.has(key):
		return
	_hints_said[key] = true
	if text != "":
		_say(text, HINT_HOLD)

func _need_text() -> String:
	var need: Dictionary = sim.milestone_need()
	if need.is_empty():
		return tr("MS_ALL_DONE")
	return tr("MS_NEED_INGOTS") % [int(sim.stock.get("iron_ingot", 0)), int(need.get("iron_ingot", 0))]

func _say(text: String, hold: float) -> void:
	var w := minf(field.size.x - 60.0, 760.0)
	# wrapped here rather than by the label: an autowrapping label measures
	# itself at its old width and comes out thousands tall
	_toast_l.text = _wrap(text, w - 36.0)
	_toast.custom_minimum_size.x = w
	_toast.reset_size()
	_toast.size.x = w
	_toast.position = Vector2((field.size.x - w) * 0.5, field.size.y - _toast.size.y - 24.0)
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

static func _clock_text(secs: int) -> String:
	return "%d:%02d" % [secs / 60, secs % 60]

func _refresh() -> void:
	var ore := Record.grouped(int(sim.stock.get("iron_ore", 0)))
	if _ore_l.text != ore:
		_ore_l.text = ore
	var ing := Record.grouped(int(sim.stock.get("iron_ingot", 0)))
	if _ingot_l.text != ing:
		_ingot_l.text = ing
	var tm := _clock_text(int(sim.t))
	if _time_l.text != tm:
		_time_l.text = tm
	var n := mini(sim.milestone, Sim.MILESTONES.size() - 1)
	_ms_kicker.text = tr("MS_MILESTONE_N") % (n + 1)
	_ms_title.text = tr(Sim.MILESTONES[n].key) if not sim.finished() else tr("MS_ALL_DONE")
	_hand_in.disabled = not sim.can_hand_in()
	_ms_bar.queue_redraw()
	for k: String in _chips:
		(_chips[k] as Control).queue_redraw()

# --- drawing ---

func _draw_field() -> void:
	if sim == null:
		return
	if _ground == null:
		_ground = Art.ground()
	var key := str(sim.buildings.size()) + ":" + ",".join(sim.buildings.map(func(b: Dictionary) -> String: return "%d@%d.%d" % [b.id, b.cell.x, b.cell.y]))
	if key != _built_key:
		_built_key = key
		_built = _build_static()
	var view := _view()
	field.draw_set_transform_matrix(view)
	field.draw_mesh(_ground, null)
	field.draw_mesh(_built, null)
	_live = _build_live()
	field.draw_mesh(_live, null)
	field.draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_words()

## The Mill and every kiln at rest: rebuilt only when one is placed or lifted.
func _build_static() -> ArrayMesh:
	var b := Face.Builder.new()
	var order := sim.buildings.duplicate()
	order.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.cell.y < q.cell.y)
	var mill_done := false
	for bd: Dictionary in order:
		if not mill_done and bd.cell.y > Sim.MILL.position.y:
			Art.mill(b)
			mill_done = true
		Art.kiln(b, Vector2(bd.cell) * Art.TILE)
	if not mill_done:
		Art.mill(b)
	return b.mesh()

func _build_live() -> ArrayMesh:
	var b := Face.Builder.new()
	var turn := 0.0 if Motion.reduce else _clock * 0.9
	Art.wheel(b, turn)
	# a deposit just dug gives a small shiver of chips
	for id: String in _shake:
		if id.begins_with("dep:"):
			var r := Sim.deposit_rect(int(id.substr(4)))
			var c := (Vector2(r.position) + Vector2(1, 1)) * Art.TILE
			var k := float(_shake[id]) / 0.12
			for j in 4:
				var a := j * TAU / 4.0 + _clock * 7.0
				b.disc(c + Vector2.from_angle(a) * (26.0 + (1.0 - k) * 26.0) - Vector2(0, 10), 4.0 * k + 1.0, Color(Art.ROCK_HI, k))
	for bd: Dictionary in sim.buildings:
		_kiln_live(b, bd)
	if _tool == "kiln" and _ghost_live:
		var ok := sim.place_refusal("kiln", _ghost) == ""
		var at := Vector2(_ghost) * Art.TILE
		b.fan(Face.Builder.round_rect(at + Vector2(4, 4), Vector2(Art.TILE * 2 - 8, Art.TILE * 2 - 8), 14.0), Color(Art.OK if ok else Art.BAD, 0.28))
		Art.kiln(b, at, 0.75, Color(Art.BAD, 0.0 if ok else 0.55))
	for f: Dictionary in _fliers:
		if f.t < 0.0:
			continue
		var k: float = clampf(f.t / f.dur, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.0)
		var p: Vector2 = (f.from as Vector2).lerp(f.to, e) + Vector2(0, -sin(k * PI) * float(f.arc))
		var a := 1.0 if k < 0.7 else (1.0 - k) / 0.3
		var sub := Face.Builder.new()
		if f.what == "ore":
			Art.ore(sub, p, 11.0)
		else:
			Art.ingot(sub, p, 26.0)
		for i in sub.cols.size():
			sub.cols[i].a *= a
		_append(b, sub)
	return b.mesh()

## A kiln's live parts: the fire in its mouth (flickering while it works,
## grey embers when it stalls), smoke from the chimney, its progress, and
## its stores -- ore heaped by the hopper, ingots stacked on the shelf.
func _kiln_live(b: Face.Builder, bd: Dictionary) -> void:
	var c := (Vector2(bd.cell) + Vector2(1, 1)) * Art.TILE
	var state := Sim.kiln_state(bd)
	var mouth := c + Vector2(0, 18)
	var flick := 0.0 if Motion.reduce else sin(_clock * 13.0 + bd.id) * 0.5 + sin(_clock * 7.3 + bd.id * 2.0) * 0.5
	if state == "work":
		var glow := 1.0 + float(_shake.get("glow:%d" % bd.id, 0.0)) * 1.2
		b.ellipse(mouth + Vector2(0, 10), 34.0 * glow, 16.0 * glow, Color(Art.EMBER, 0.28))
		b.ellipse(mouth, 16.0 + flick * 1.5, 12.0 + flick, Art.EMBER)
		b.ellipse(mouth + Vector2(0, 3), 9.0 + flick, 6.0, Art.EMBER_HOT)
		# smoke, three puffs rising and fading on a loop
		for j in 3:
			var ph := fposmod((0.0 if Motion.reduce else _clock) * 0.5 + j / 3.0 + bd.id * 0.37, 1.0)
			var at := c + Vector2(26.0 + sin(ph * 5.0 + j) * 8.0, -72.0 - ph * 60.0)
			b.disc(at, 9.0 + ph * 12.0, Color(0.93, 0.9, 0.86, 0.55 * (1.0 - ph)))
		# progress under the mouth
		var w := 56.0
		var k: float = float(bd.prog) / Sim.SMELT
		b.fan(Face.Builder.round_rect(c + Vector2(-w * 0.5, 44), Vector2(w, 7), 3.5), Color(Art.SOOT, 0.5))
		b.fan(Face.Builder.round_rect(c + Vector2(-w * 0.5, 44), Vector2(maxf(7.0, w * k), 7), 3.5), Art.EMBER)
	else:
		b.ellipse(mouth, 12.0, 8.0, Color(Art.ROCK_DEEP, 0.8))
		# a small sign of what it wants: an ore bubble or a full shelf
		var tip := c + Vector2(-44, -50)
		var bob := 0.0 if Motion.reduce else sin(_clock * 3.0 + bd.id) * 3.0
		b.disc(tip + Vector2(0, bob), 20.0, Color(Art.TAG_PAPER, 0.95))
		b.disc(tip + Vector2(8, 16 + bob), 5.0, Color(Art.TAG_PAPER, 0.95))
		if state == "no_ore":
			Art.ore(b, tip + Vector2(0, bob), 10.0)
		else:
			Art.ingot(b, tip + Vector2(0, bob), 22.0)
	# the hopper: a heap of ore to the left, taller the fuller
	var heap := int(ceil(float(bd.hopper) / Sim.HOPPER * 5.0))
	for j in heap:
		Art.ore(b, c + Vector2(-54 + (j % 3) * 9, 40 - (j / 3) * 9), 8.0)
	# the shelf: ingots stacked to the right
	var stack := int(ceil(float(bd.shelf) / Sim.SHELF * 6.0))
	for j in stack:
		Art.ingot(b, c + Vector2(50 + (j % 2) * 4, 44 - j * 7), 20.0)

func _append(into: Face.Builder, from: Face.Builder) -> void:
	var base := into.verts.size()
	into.verts.append_array(from.verts)
	into.cols.append_array(from.cols)
	for i in from.idx:
		into.idx.append(base + i)

## The few numbers: each kiln's shelf count, and the pops.
func _draw_words() -> void:
	var font := get_theme_font("font", "SheetTitle")
	var fs := 30
	for bd: Dictionary in sim.buildings:
		if int(bd.shelf) <= 0:
			continue
		var at := screen((Vector2(bd.cell) + Vector2(1, 1)) * Art.TILE + Vector2(52, 70))
		_word(font, str(bd.shelf), at, fs, TAG)
	for p: Dictionary in _pops:
		var k: float = p.t
		var at := screen(p.at as Vector2) + Vector2(0, -k * 40.0)
		var col: Color = p.col
		col.a = 1.0 if k < 0.6 else (1.0 - k) / 0.4
		_word(font, p.text, at, 34, col)

func _word(font: Font, text: String, at: Vector2, fs: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var o := at - Vector2(w * 0.5, -fs * 0.35)
	field.draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.23, 0.16, 0.1, col.a * 0.8))
	field.draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

# --- chrome ---

func _on_reset() -> void:
	Analytics.track("board_reset", {"puzzle_id": GAME})
	sim = Sim.new()
	_fitted = false
	_layout_field()
	save()
	_begin(false)

func _on_back() -> void:
	save()
	if sim != null and not sim.finished() and sim.t > 5.0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": 0, "stage": sim.milestone, "mined": sim.mined})
	_brook.stop()
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()

## The milestone's progress: a paper trough filling with the stock's
## ingots toward the need, the count written over it.
class _Bar extends Control:
	var _s: Control

	func _init(s: Control) -> void:
		_s = s
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sim = _s.sim
		if sim == null:
			return
		var need: Dictionary = sim.milestone_need()
		var want := int(need.get("iron_ingot", 1)) if not need.is_empty() else 1
		var have := int(sim.stock.get("iron_ingot", 0)) if not need.is_empty() else want
		var k := clampf(float(have) / want, 0.0, 1.0)
		var r := size.y * 0.5
		draw_style_box(_box(Color("e9dfcc"), r), Rect2(Vector2.ZERO, size))
		if k > 0.0:
			draw_style_box(_box(Pal.SUN if k >= 1.0 else Color("c9d3da"), r), Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * k), size.y)))
		var font := get_theme_font("font", "MenuKicker")
		var text := "%d / %d" % [mini(have, want), want] if not need.is_empty() else ""
		var fs := 24
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("3b3028"))

	func _box(c: Color, r: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(r))
		return sb

## A tool in the panel: its picture, its name and what it costs (or
## "Later" for one still to come). Lit while chosen, dimmed when short.
class _Chip extends Button:
	var _s: Control
	var kind := ""
	var _keep: ArrayMesh

	func _init(s: Control, k: String) -> void:
		_s = s
		kind = k
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(200, 150)

	func _draw() -> void:
		var sim = _s.sim
		var lit := button_pressed
		var later := kind == "drill"
		var short: bool = kind == "kiln" and sim != null and not sim.affordable("kiln")
		var pic := size.y * 0.52
		_keep = Art.icon(kind, pic)
		var a := 0.45 if later or short else 1.0
		draw_mesh(_keep, null, Transform2D(0.0, Vector2(size.x * 0.5, size.y * 0.36)))
		var font := get_theme_font("font", "MenuKicker")
		var name_t := tr("MS_TOOL_" + kind.to_upper())
		var sub := ""
		match kind:
			"kiln":
				sub = tr("MS_COST_ORE") % int(Sim.COSTS.kiln.iron_ore)
			"eraser":
				sub = tr("MS_REFUND")
			"drill":
				sub = tr("MS_LATER")
		var ink := Color("3b3028", a)
		_line(font, name_t, size.y * 0.76, 26, ink)
		_line(font, sub, size.y * 0.92, 20, Color(ink, a * 0.7) if not lit else ink)

	func _line(font: Font, text: String, y: float, fs: int, col: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
