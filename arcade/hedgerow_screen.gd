extends Control

## Hedgerow: the second game on the Arcade tab, a mazing tower defence
## after the element tower-defence genre, re-dressed as a garden (spec
## docs/superpowers/specs/2026-09-27-arcade-hedgerow-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the gold, the lives and the wave, the lawn in a wooden frame, and a
## paper panel under it that shows what a tap can do.
##
## Play: tap a bare cell and the panel offers the towers you can plant
## there; tap a tower and it offers the upgrade, the duals it can fuse into
## and the sale. With nothing chosen the panel sends the next wave early
## (the break's seconds come back as gold) and sets the speed. The game is
## arcade/hedgerow_sim.gd, stepped at its fixed DT; this screen draws it
## and plays its events.

signal closed

const Sim = preload("res://arcade/hedgerow_sim.gd")
const Art = preload("res://arcade/hedgerow_art.gd")
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

const GAME := "hedgerow"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const PANEL_H := 262.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
## Cells of hedge above the lawn and of vegetable patch below it.
const TOP := 0.75
const FOOT := 0.95
const MAX_STEPS := 8
const SHOT_LIFE := 0.2
const LAWN := Color("9cc46a")
const LAWN_ALT := Color("93bb62")
const LAWN_EDGE := Color("7fa84a")
const HEDGE := Color("4f7f3a")
const HEDGE_DEEP := Color("3c6630")
const HEDGE_HI := Color("6a9a4a")
const SOIL := Color("8a6242")
const SOIL_DEEP := Color("6e4a2f")
const CABBAGE := Color("a9d27a")
const CABBAGE_DEEP := Color("7fae52")
const ROUTE := Color(1.0, 0.98, 0.9, 0.5)
const PICK_HI := Color("fff1a8")
const BAD_CELL := Color(0.85, 0.3, 0.25, 0.35)

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var field: Control
var _fx: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _gold_l: Label
var _lives_l: Label
var _wave_l: Label
var _banner: Label
var _sub: Label
var _banner_tw: Tween
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _panel_key := ""
var _pause_card: Control
var _pick_card: Control
var _end: Control
var _seat: Control
var _acc := 0.0
var _paused := false
var _fast := false
var _started_at := 0
var _best := 0
var _clock := 0.0
## Pixels a cell, and where cell (0, 0)'s corner lands in `field`.
var _u := 80.0
var _origin := Vector2.ZERO
var _lawn: ArrayMesh
var _towers_mesh: ArrayMesh
var _live: ArrayMesh
var _over: ArrayMesh
var _towers_dirty := true
## What a tap has chosen: a bare cell, or a tower's cell.
var _sel := Vector2i(-1, -1)
var _shots: Array = []    # {from, to: Array, key, t, level}
var _pulses: Array = []   # {at, r, col, t}
var _pops: Array = []     # {pos, text, t, col}
var _hit_at := {}         # creep id -> clock of its last hit
var _ang := {}            # creep id -> drawn heading
var _grow := {}           # cell -> clock it last changed, for the pop in
var _shot_cue_at := 0.0
var _shown_gold := -1
var _shown_lives := -1
var _shown_wave := -1
var _shown_send := ""
var _send_btn: IconButton

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

	top_bar = FlatTopBar.new("Hedgerow", tr("HR_MOTTO"), true)
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
	_banner.add_theme_color_override("font_shadow_color", Color(0.15, 0.2, 0.08, 0.6))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	over.add_child(_banner)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetTitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Color("fffaf0"))
	_sub.add_theme_color_override("font_shadow_color", Color(0.15, 0.2, 0.08, 0.6))
	_sub.add_theme_constant_override("shadow_offset_y", 3)
	over.add_child(_sub)
	over.modulate.a = 0.0
	_banner.set_meta("box", over)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size.y = PANEL_H
	_panel.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 36, 18))
	col.add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_panel_box)
	_apply_insets()

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["HR_GOLD", "HR_LIVES", "HR_WAVE"]:
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
	_gold_l = made[0]
	_lives_l = made[1]
	_wave_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The lawn is scaled to the room: the hedge on top, the rows, and the
## vegetable patch under them, centred with hedge down the sides.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_u = minf(s.x / Sim.COLS, s.y / (Sim.ROWS + TOP + FOOT))
	var used := Vector2(Sim.COLS * _u, (Sim.ROWS + TOP + FOOT) * _u)
	_origin = Vector2((s.x - used.x) * 0.5, (s.y - used.y) * 0.5 + TOP * _u)
	_lawn = _build_lawn()
	_towers_dirty = true
	var box: Control = _banner.get_meta("box")
	box.position = Vector2(0, s.y * 0.3)
	box.size.x = s.x
	if _pick_card != null:
		_pick_card.size = s
	field.queue_redraw()

func px(p: Vector2) -> Vector2:
	return _origin + p * _u

func cell_at(at: Vector2) -> Vector2i:
	var p := (at - _origin) / _u
	return Vector2i(floori(p.x), floori(p.y))

# --- the game ---

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	sim = Sim.new()
	_acc = 0.0
	_paused = false
	_fast = false
	_sel = Vector2i(-1, -1)
	_shots.clear()
	_pulses.clear()
	_pops.clear()
	_hit_at.clear()
	_ang.clear()
	_grow.clear()
	_towers_dirty = true
	_best = Record.best(GAME)
	_shown_gold = -1
	_shown_lives = -1
	_shown_wave = -1
	_started_at = Time.get_ticks_msec()
	if _pause_card != null:
		_pause_card.queue_free()
		_pause_card = null
	_refresh_hud()
	_refresh_panel(true)
	top_bar.refresh(self)
	_fx.cue("start")
	_show_banner(tr("HR_WELCOME"), tr("HR_WELCOME_LINE"), 2.4)
	_open_pick.call_deferred()
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
	if not _paused and _pick_card == null:
		_clock += delta
		var speed := 2.0 if _fast else 1.0
		_acc += minf(delta * speed, Sim.DT * MAX_STEPS * speed)
		while _acc >= Sim.DT:
			_acc -= Sim.DT
			sim.step()
			_play_events()
		_animate(delta)
	elif not sim.events.is_empty():
		_play_events()
	_refresh_hud()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	field.queue_redraw()

func _animate(delta: float) -> void:
	for s: Dictionary in _shots:
		s.t += delta
	_shots = _shots.filter(func(s: Dictionary) -> bool: return s.t < SHOT_LIFE)
	for p: Dictionary in _pulses:
		p.t += delta
	_pulses = _pulses.filter(func(p: Dictionary) -> bool: return p.t < 0.4)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 0.9)
	# each pest's drawn heading eases toward where it is going
	var seen := {}
	for c: Dictionary in sim.creeps:
		var want: float
		if c.air:
			want = PI * 0.5 + cos(c.pos.y * 0.7 + c.phase) * 0.5
		else:
			var d: Vector2 = c.to - c.pos
			want = d.angle() if d.length_squared() > 0.0001 else float(_ang.get(c.id, PI * 0.5))
		var was: float = _ang.get(c.id, want)
		seen[c.id] = lerp_angle(was, want, 1.0 - exp(-delta * 12.0))
	_ang = seen

func _on_field_input(event: InputEvent) -> void:
	if _paused:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			if _end == null and not settings_sheet.is_open():
				_pause(false)
		return
	if sim == null or sim.is_over() or _pick_card != null:
		return
	var tap := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tap = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tap = (event as InputEventMouseButton).position
	if tap == Vector2.INF:
		return
	field.accept_event()
	_tap(cell_at(tap))

func _tap(c: Vector2i) -> void:
	if not Sim.inside(c) or c == _sel:
		_select(Vector2i(-1, -1))
		return
	_select(c)
	_fx.cue("select")

func _select(c: Vector2i) -> void:
	_sel = c
	_refresh_panel(true)

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
	scrim.color = Color(0.12, 0.18, 0.08, 0.5)
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

# --- the panel ---

## The panel under the lawn, rebuilt when what it shows changes: the next
## wave with nothing chosen, the towers for a bare cell, or a tower's own
## moves. `force` rebuilds even when the key is the same.
func _refresh_panel(force := false) -> void:
	if sim == null:
		return
	var tw: Dictionary = sim.at.get(_sel, {})
	var key := "none"
	if not tw.is_empty():
		key = "tower/%d/%s/%d/%d" % [tw.id, tw.key, tw.level, sim.picked.size()]
	elif Sim.inside(_sel):
		key = "cell/%d,%d/%d/%s" % [_sel.x, _sel.y, sim.picked.size(), sim.build_block(_sel)]
	key += "/g%d" % _gold_step()
	if key == _panel_key and not force:
		return
	_panel_key = key
	for c in _panel_box.get_children():
		_panel_box.remove_child(c)
		c.queue_free()
	_send_btn = null
	_shown_send = ""
	if not tw.is_empty():
		_panel_tower(tw)
	elif Sim.inside(_sel):
		_panel_cell(_sel)
	else:
		_panel_wave()

## The gold, coarsely, so the panel re-enables its chips when a price comes
## within reach without rebuilding every coin.
func _gold_step() -> int:
	var prices := [20, 30, 40, 60, 100, 110, 150, 220, 260, 520, 700]
	var n := 0
	for p: int in prices:
		if sim.gold >= p:
			n += 1
	return n

func _panel_head(text: String, line: String) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_panel_box.add_child(head)
	var name_l := Label.new()
	name_l.text = text
	name_l.theme_type_variation = "SheetTitle"
	head.add_child(name_l)
	var sub := Label.new()
	sub.text = line
	sub.theme_type_variation = "SheetBodyDim"
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.max_lines_visible = 2
	head.add_child(sub)

func _chip_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_box.add_child(row)
	return row

func _panel_wave() -> void:
	var n: int = sim.wave + 1 if sim.phase == Sim.Phase.BUILD else sim.wave
	if n > Sim.WAVES:
		n = Sim.WAVES
	var kind := Sim.wave_kind(n)
	var el := Sim.wave_el(n)
	var what: String = tr("HR_K_%d" % kind)
	if el != Sim.El.NONE:
		what += "  ·  " + tr("HR_EL_" + String(Sim.EL_KEY[el]).to_upper())
	_panel_head(tr("HR_WAVE_N") % n, what)
	var row := _chip_row()
	var send := IconButton.new("chevron_right", " ", "SunButton")
	send.name = "Send"
	send.custom_minimum_size = Vector2(560, 130)
	send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	send.pressed.connect(_on_send)
	row.add_child(send)
	_send_btn = send
	var speed := IconButton.new("chevron_right", "x2" if not _fast else "x1")
	speed.name = "Speed"
	speed.custom_minimum_size = Vector2(200, 130)
	speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed.pressed.connect(func() -> void:
		_fast = not _fast
		_refresh_panel(true))
	row.add_child(speed)
	var sign := _WaveSign.new(kind, el)
	sign.custom_minimum_size = Vector2(130, 130)
	sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sign)
	_update_send()

## The send button's words follow the break's clock.
func _update_send() -> void:
	if _send_btn == null or not is_instance_valid(_send_btn):
		return
	var text: String
	if sim.pick_pending:
		text = tr("HR_PICK_FIRST")
	elif sim.phase == Sim.Phase.WAVE:
		text = tr("HR_INCOMING")
	elif sim.wave == 0:
		text = tr("HR_SEND_FIRST") % int(ceil(sim.next_in))
	else:
		text = tr("HR_SEND") % [int(ceil(sim.next_in)), int(sim.next_in * 0.5)]
	if text == _shown_send:
		return
	_shown_send = text
	_send_btn.label_text = text
	if _send_btn._label != null:
		_send_btn._label.text = text
	_send_btn.disabled = not sim.can_send()

func _panel_cell(c: Vector2i) -> void:
	var why: String = sim.build_block(c)
	if why == "edge":
		_panel_head(tr("HR_CELL"), tr("HR_EDGE"))
		return
	_panel_head(tr("HR_CELL"), tr("HR_BLOCKS") if why == "blocks" else (tr("HR_BUSY") if why == "busy" else tr("HR_CELL_LINE")))
	if why != "":
		return
	var row := _chip_row()
	var keys: Array = Sim.BASIC.duplicate()
	for e: int in sim.picked:
		keys.append(Sim.EL_KEY[e])
	for key: String in keys:
		var cost: int = Sim.TOWERS[key].cost[0]
		var chip := _TowerChip.new(key, 0, "%d" % cost, sim.gold >= cost)
		chip.name = "Build_" + key
		chip.pressed.connect(func() -> void:
			if sim.build(c, key):
				_grow[c] = _clock
				_towers_dirty = true
			_play_events()
			_refresh_panel(true))
		row.add_child(chip)

func _panel_tower(tw: Dictionary) -> void:
	var d: Dictionary = Sim.TOWERS[tw.key]
	var title: String = tr("HR_T_" + String(tw.key).to_upper())
	if (d.cost as Array).size() > 1:
		title += "  " + tr("HR_LEVEL") % (tw.level + 1)
	_panel_head(title, tr("HR_D_" + String(tw.key).to_upper()))
	var row := _chip_row()
	var up: int = sim.upgrade_cost(tw)
	if up > 0:
		var chip := _TowerChip.new(tw.key, tw.level + 1, "%d" % up, sim.gold >= up, tr("HR_UPGRADE"))
		chip.name = "Upgrade"
		chip.pressed.connect(func() -> void:
			if sim.upgrade(tw):
				_grow[tw.cell] = _clock
				_towers_dirty = true
			_play_events()
			_refresh_panel(true))
		row.add_child(chip)
	for key: String in sim.fusions(tw):
		var cost: int = Sim.TOWERS[key].cost[0]
		var chip := _TowerChip.new(key, 0, "%d" % cost, sim.gold >= cost, tr("HR_T_" + key.to_upper()))
		chip.name = "Fuse_" + key
		chip.pressed.connect(func() -> void:
			if sim.fuse(tw, key):
				_grow[tw.cell] = _clock
				_towers_dirty = true
			_play_events()
			_refresh_panel(true))
		row.add_child(chip)
	var sell := _TowerChip.new("", 0, "+%d" % sim.sell_value(tw), true, tr("HR_SELL"))
	sell.name = "Sell"
	sell.pressed.connect(func() -> void:
		sim.sell(tw)
		_towers_dirty = true
		_play_events()
		_select(Vector2i(-1, -1)))
	row.add_child(sell)

func _on_send() -> void:
	if sim.send_wave():
		_play_events()
	_refresh_panel(true)

# --- the element pick ---

## The pick: six orbs, the ones already taken dimmed, each with what it is
## strong against. The game waits while it is open.
func _open_pick() -> void:
	if sim == null or not sim.pick_pending or _pick_card != null or sim.is_over():
		return
	var scrim := ColorRect.new()
	scrim.name = "Pick"
	scrim.color = Color(0.12, 0.18, 0.08, 0.55)
	scrim.position = Vector2.ZERO
	scrim.size = field.size
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	field.add_child(scrim)
	_pick_card = scrim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 40, 28))
	card.custom_minimum_size.x = minf(field.size.x - 40.0, 860.0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	var head := Label.new()
	head.text = tr("HR_PICK") if sim.picked.is_empty() else tr("HR_PICK_N") % (sim.picked.size() + 1)
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var line := Label.new()
	line.text = tr("HR_PICK_LINE")
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)
	for e: int in Sim.ELEMENTS:
		var b := _ElementChip.new(e, sim.picked.has(e))
		b.name = "Pick_" + String(Sim.EL_KEY[e])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = sim.picked.has(e)
		b.pressed.connect(_on_pick.bind(e))
		grid.add_child(b)
	Motion.appear(scrim, 0.0, 1.0, 0.25)

func _on_pick(e: int) -> void:
	if not sim.pick(e):
		return
	if _pick_card != null:
		_pick_card.queue_free()
		_pick_card = null
	_play_events()
	_refresh_panel(true)

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		match String(ev.type):
			"shot":
				var from := Sim.centre(ev.cell)
				_shots.append({"from": from, "to": ev.to, "key": ev.key, "t": 0.0, "level": ev.level})
				_shot_cue(ev.key)
			"pulse":
				var els: Array = Sim.TOWERS[ev.key].els
				_pulses.append({"at": Sim.centre(ev.cell), "r": ev.r, "col": Art.col(els[els.size() - 1]), "t": 0.0})
				_shot_cue(ev.key)
			"hit":
				_hit_at[ev.id] = _clock
			"kill":
				var boss: bool = ev.kind == Sim.Kind.BOSS
				_fx.puff(px(ev.pos), Art.col(ev.el), 10 if boss else 4)
				if boss:
					_fx.sparkle(px(ev.pos), Pal.SUN)
					_fx.cue("kill_big")
				else:
					_fx.cue("kill", randf_range(0.9, 1.15), -2.0)
				_pops.append({"pos": ev.pos, "text": "+%d" % ev.gold, "t": 0.0, "col": Pal.SUN_RAY})
			"leak":
				_fx.cue("leak")
				_pops.append({"pos": Vector2(Sim.DOOR + 0.5, Sim.ROWS + 0.3), "text": "-%d" % ev.lives, "t": 0.0, "col": Pal.BAD})
				_lives_l.pivot_offset = _lives_l.size * 0.5
				Motion.bump(_lives_l, 0.3, 0.35)
			"stun":
				pass
			"spill":
				_shots.append({"from": ev.from, "to": [ev.to], "key": "spill", "t": 0.0, "level": 0})
			"build":
				_fx.cue("build", randf_range(0.95, 1.05))
				_fx.puff(px(Sim.centre(ev.cell)), Art.BRAMBLE, 5)
				_towers_dirty = true
			"upgrade":
				_fx.cue("upgrade")
				_fx.sparkle(px(Sim.centre(ev.cell)), Pal.SUN)
				_towers_dirty = true
			"fuse":
				_fx.cue("fuse")
				var els: Array = Sim.TOWERS[ev.key].els
				_fx.ring(px(Sim.centre(ev.cell)), _u * 0.8, Art.col(els[0]))
				_fx.sparkle(px(Sim.centre(ev.cell)), Art.col(els[1]))
				_towers_dirty = true
			"sell":
				_fx.cue("sell")
				_fx.puff(px(Sim.centre(ev.cell)), Art.SLAB, 5)
				_towers_dirty = true
			"refuse":
				_fx.cue("refuse")
				var why := String(ev.why)
				if why == "blocks":
					_show_banner(tr("HR_BLOCKS"), "", 1.2)
				elif why == "gold":
					_gold_l.pivot_offset = _gold_l.size * 0.5
					Motion.bump(_gold_l, 0.25, 0.3)
			"pick":
				_fx.cue("pick")
				var el_name := tr("HR_EL_" + String(Sim.EL_KEY[ev.el]).to_upper())
				_show_banner(el_name, tr("HR_PICKED_LINE"), 1.6)
			"pick_due":
				_open_pick.call_deferred()
			"wave":
				_fx.cue("wave")
				var line: String = tr("HR_K_%d" % ev.kind)
				if int(ev.el) != Sim.El.NONE:
					line += "  ·  " + tr("HR_EL_" + String(Sim.EL_KEY[ev.el]).to_upper())
				_show_banner(tr("HR_WAVE_N") % ev.wave, line, 1.4)
				if int(ev.early) > 0:
					_pops.append({"pos": Vector2(Sim.COLS * 0.5, 1.5), "text": "+%d" % ev.early, "t": 0.0, "col": Pal.SUN_RAY})
			"boss":
				_fx.cue("boss")
			"clear":
				_fx.cue("clear")
				if int(ev.interest) > 0:
					get_tree().create_timer(0.5).timeout.connect(func() -> void:
						if is_instance_valid(_fx):
							_fx.cue("gold"))
				_show_banner(tr("HR_CLEAR"), tr("HR_CLEAR_LINE") % [ev.bonus, ev.interest], 1.8)
			"game_over":
				_finish(false)
			"won":
				_finish(true)
	sim.events.clear()

## A shot's sound, kept to a few a second however many towers fire.
func _shot_cue(key: String) -> void:
	if _clock - _shot_cue_at < 0.07:
		return
	_shot_cue_at = _clock
	var cue := "shot_thorn"
	match key:
		"acorn":
			cue = "shot_acorn"
		"lightning":
			cue = "zap"
		"frost":
			cue = "freeze"
		"thorn":
			cue = "shot_thorn"
		_:
			var els: Array = Sim.TOWERS[key].els
			cue = "shot_" + String(Sim.EL_KEY[els[els.size() - 1]])
	_fx.cue(cue, randf_range(0.92, 1.08), -3.0)

func _show_banner(text: String, sub: String, hold: float) -> void:
	_banner.text = text
	_sub.text = sub
	_sub.visible = sub != ""
	var box: Control = _banner.get_meta("box")
	box.reset_size()
	box.size.x = field.size.x
	box.position = Vector2(0, field.size.y * 0.3)
	box.pivot_offset = Vector2(box.size.x * 0.5, box.size.y * 0.5)
	Motion.stop(_banner_tw)
	_banner_tw = create_tween()
	if Motion.reduce:
		box.scale = Vector2.ONE
		_banner_tw.tween_property(box, "modulate:a", 1.0, 0.2)
		_banner_tw.tween_interval(hold)
		_banner_tw.tween_property(box, "modulate:a", 0.0, 0.35)
		return
	box.scale = Vector2(0.6, 0.6)
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(box, "modulate:a", 1.0, 0.16)
	_banner_tw.tween_property(box, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(hold)
	_banner_tw.chain().tween_property(box, "modulate:a", 0.0, 0.35)
	_banner_tw.tween_property(box, "scale", Vector2(1.12, 1.12), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _refresh_hud() -> void:
	if sim == null:
		return
	if sim.gold != _shown_gold:
		_shown_gold = sim.gold
		_gold_l.text = Record.grouped(sim.gold)
		_refresh_panel()
	if sim.lives != _shown_lives:
		_shown_lives = sim.lives
		_lives_l.text = str(sim.lives)
	var w: int = maxi(1, sim.wave)
	if w != _shown_wave:
		_shown_wave = w
		_wave_l.text = "%d/%d" % [w, Sim.WAVES]
	if _sel.x >= 0 and not sim.at.has(_sel):
		_refresh_panel()
	_update_send()

# --- drawing ---

## The still lawn, built on resize: hedge round the sides and across the
## top with the gap the pests come through, the rows of grass in a soft
## check, and the vegetable patch they are after under the last row.
func _build_lawn() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), HEDGE_DEEP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# hedge texture everywhere; the lawn is laid over it
	for i in 160:
		var p := Vector2(rng.randf() * s.x, rng.randf() * s.y)
		b.disc(p, rng.randf_range(0.18, 0.34) * _u, HEDGE if i % 3 else HEDGE_HI)
	var lawn_at := px(Vector2.ZERO)
	var lawn_size := Vector2(Sim.COLS, Sim.ROWS) * _u
	b.fan(Face.Builder.round_rect(lawn_at - Vector2(6, 6), lawn_size + Vector2(12, 12), 14.0), LAWN_EDGE)
	b.fan(Face.Builder.round_rect(lawn_at, lawn_size, 10.0), LAWN)
	for y in Sim.ROWS:
		for x in Sim.COLS:
			if (x + y) % 2 == 1:
				b.fan(Face.Builder.round_rect(px(Vector2(x, y)) + Vector2(2, 2), Vector2(_u - 4, _u - 4), 8.0), LAWN_ALT)
	# grass tufts and a few daisies
	for i in 70:
		var p := lawn_at + Vector2(rng.randf() * lawn_size.x, rng.randf() * lawn_size.y)
		for k in 3:
			var tip := p + Vector2((k - 1) * 0.06 * _u, -0.12 * _u)
			b.stroke(PackedVector2Array([p, tip]), 0.025 * _u, LAWN_EDGE)
	for i in 14:
		var p := lawn_at + Vector2(rng.randf() * lawn_size.x, rng.randf() * lawn_size.y)
		for k in 5:
			b.disc(p + Vector2.from_angle(TAU * k / 5.0) * 0.05 * _u, 0.04 * _u, Color(1, 1, 1, 0.85))
		b.disc(p, 0.035 * _u, Pal.SUN_RAY)
	# the gap in the top hedge, a worn path out of it
	var gap := px(Vector2(Sim.DOOR, -TOP))
	b.fan(Face.Builder.round_rect(gap + Vector2(0.08 * _u, 0), Vector2(0.84 * _u, TOP * _u + 8.0), 10.0), SOIL)
	b.fan(Face.Builder.round_rect(gap + Vector2(0.16 * _u, 0), Vector2(0.68 * _u, TOP * _u), 8.0), SOIL.lightened(0.12))
	# the patch: tilled soil and cabbages across the foot
	var foot := px(Vector2(0, Sim.ROWS)) + Vector2(0, 8)
	var foot_size := Vector2(Sim.COLS * _u, FOOT * _u - 8)
	b.fan(Face.Builder.round_rect(foot, foot_size, 14.0), SOIL_DEEP)
	b.fan(Face.Builder.round_rect(foot + Vector2(4, 4), foot_size - Vector2(8, 10), 12.0), SOIL)
	for k in 3:
		var y := foot.y + foot_size.y * (0.25 + k * 0.25)
		b.stroke(PackedVector2Array([Vector2(foot.x + 14, y), Vector2(foot.x + foot_size.x - 14, y)]), 3.0, SOIL_DEEP)
	for i in Sim.COLS * 2:
		var c := Vector2(foot.x + (i + 0.5) * _u * 0.5, foot.y + foot_size.y * (0.4 + 0.2 * (i % 2)))
		_cabbage(b, c, _u * (0.2 + 0.03 * (i % 3)))
	return b.mesh()

static func _cabbage(b: Face.Builder, at: Vector2, r: float) -> void:
	b.ellipse(at + Vector2(0, r * 0.4), r * 1.1, r * 0.5, Color(0, 0, 0, 0.15))
	for k in 5:
		b.disc(at + Vector2.from_angle(TAU * k / 5.0 + 0.4) * r * 0.55, r * 0.6, CABBAGE_DEEP)
	b.disc(at, r * 0.7, CABBAGE)
	b.disc(at + Vector2(-r * 0.2, -r * 0.2), r * 0.3, CABBAGE.lightened(0.2))

## Every tower and the pests' walk, baked into one mesh whenever a tower
## comes, goes or changes.
func _build_towers() -> ArrayMesh:
	var b := Face.Builder.new()
	var route: Array[Vector2i] = sim.route()
	for i in range(1, route.size()):
		var a := px(Sim.centre(route[i - 1]))
		var z := px(Sim.centre(route[i]))
		for k in 3:
			b.disc(a.lerp(z, (k + 0.5) / 3.0), 0.045 * _u, ROUTE)
	for tw: Dictionary in sim.towers:
		if _growing(tw.cell):
			continue
		Art.tower_into(b, tw.key, tw.level, _u, px(Sim.centre(tw.cell)))
	return b.mesh()

func _growing(c: Vector2i) -> bool:
	return not Motion.reduce and _clock - float(_grow.get(c, -10.0)) < 0.35

func _draw_field() -> void:
	if _lawn == null:
		_layout_field()
	if _lawn == null or sim == null:
		return
	field.draw_mesh(_lawn, null)
	var growing := false
	for c: Vector2i in _grow:
		if _growing(c):
			growing = true
	if _towers_dirty or growing:
		_towers_mesh = _build_towers()
		_towers_dirty = growing
	field.draw_mesh(_towers_mesh, null)
	# a tower popping in, drawn on its own until it has landed
	for c: Vector2i in _grow:
		if _growing(c) and sim.at.has(c):
			var tw: Dictionary = sim.at[c]
			var k := (_clock - float(_grow[c])) / 0.35
			var sc := Motion.back_out(k)
			field.draw_mesh(Art.tower(tw.key, tw.level, _u), null, Transform2D(0.0, Vector2(sc, sc), 0.0, px(Sim.centre(c))))
	var under := Face.Builder.new()
	_draw_selection(under)
	_draw_pulses(under)
	if not under.verts.is_empty():
		_live = under.mesh()
		field.draw_mesh(_live, null)
	_draw_creeps()
	var o := Face.Builder.new()
	_draw_bars(o)
	_draw_shots(o)
	if not o.verts.is_empty():
		_over = o.mesh()
		field.draw_mesh(_over, null)
	_draw_pops()

func _draw_selection(b: Face.Builder) -> void:
	if not Sim.inside(_sel):
		return
	var at := px(Vector2(_sel))
	var tw: Dictionary = sim.at.get(_sel, {})
	var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
	if tw.is_empty():
		var bad: bool = sim.build_block(_sel) != ""
		b.fan(Face.Builder.round_rect(at + Vector2(3, 3), Vector2(_u - 6, _u - 6), 10.0), BAD_CELL if bad else Color(1, 1, 0.85, 0.35 + 0.15 * pulse))
		b.stroke(Face.Builder.round_rect(at + Vector2(3, 3), Vector2(_u - 6, _u - 6), 10.0), 4.0, Color(1, 1, 1, 0.9), true)
		if not bad:
			_ring(b, px(Sim.centre(_sel)), float(Sim.TOWERS.thorn.range) * _u, Color(1, 1, 1, 0.5))
		return
	var r: float = float(Sim.TOWERS[tw.key].range) * _u
	var els: Array = Sim.TOWERS[tw.key].els
	var tint: Color = Art.col(els[0]) if not els.is_empty() else Color(1, 1, 1)
	b.disc(px(Sim.centre(_sel)), r, Color(tint, 0.12))
	_ring(b, px(Sim.centre(_sel)), r, Color(tint.lightened(0.3), 0.7))
	b.stroke(Face.Builder.round_rect(at + Vector2(2, 2), Vector2(_u - 4, _u - 4), 10.0), 4.0 + 2.0 * pulse, Color(1, 1, 1, 0.9), true)

static func _ring(b: Face.Builder, at: Vector2, r: float, col: Color, width := 3.0) -> void:
	b.stroke(Face.Builder.ring(at, r, r), width, col, true)

func _draw_pulses(b: Face.Builder) -> void:
	for p: Dictionary in _pulses:
		var k: float = p.t / 0.4
		var r: float = p.r * _u * (0.3 + 0.7 * k)
		_ring(b, px(p.at), r, Color(p.col, 0.7 * (1.0 - k)), 8.0 * (1.0 - k) + 2.0)
		b.disc(px(p.at), r, Color(p.col, 0.12 * (1.0 - k)))

func _draw_creeps() -> void:
	var order: Array = sim.creeps.duplicate()
	# the flyers over the walkers
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.air) < int(b.air))
	for c: Dictionary in order:
		if not c.alive:
			continue
		var frame := int(_clock * 8.0 + c.id) % 2
		if c.stun_t > 0.0 or Motion.reduce:
			frame = 0
		var rot: float = float(_ang.get(c.id, PI * 0.5)) + PI * 0.5
		var pos: Vector2 = c.pos
		var sc := Vector2.ONE
		var since := _clock - float(_hit_at.get(c.id, -10.0))
		if since < 0.12 and not Motion.reduce:
			sc *= 1.0 + 0.18 * (1.0 - since / 0.12)
		if c.air and not Motion.reduce:
			pos.y += sin(_clock * 6.0 + c.phase) * 0.05
		var tint := Color.WHITE
		if c.stun_t > 0.0:
			tint = Color(0.75, 0.9, 1.0)
		elif c.slow > 0.0:
			tint = Color(0.85, 0.92, 1.0)
		field.draw_mesh(Art.creep(c.kind, c.el, frame, _u), null, Transform2D(rot, sc, 0.0, px(pos)), tint)

## Health bars over hurt pests, and the marks of what is being done to them.
func _draw_bars(b: Face.Builder) -> void:
	for c: Dictionary in sim.creeps:
		if not c.alive:
			continue
		var top: Vector2 = px(c.pos) + Vector2(0, -(0.62 if c.kind == Sim.Kind.BOSS else 0.42) * _u)
		if c.hp < c.max:
			var w := (0.9 if c.kind == Sim.Kind.BOSS else 0.56) * _u
			var k: float = clampf(c.hp / c.max, 0.0, 1.0)
			b.fan(Face.Builder.round_rect(top - Vector2(w * 0.5 + 2, 5), Vector2(w + 4, 10), 5.0), Color(0.15, 0.12, 0.1, 0.55))
			var col := Pal.GOOD if k > 0.5 else (Pal.SUN if k > 0.25 else Pal.BAD)
			b.fan(Face.Builder.round_rect(top - Vector2(w * 0.5, 3), Vector2(maxf(4.0, w * k), 6), 3.0), col)
		if c.stun_t > 0.0:
			for i in 3:
				var a := _clock * 3.0 + TAU * i / 3.0
				b.disc(px(c.pos) + Vector2.from_angle(a) * 0.3 * _u, 0.05 * _u, Color("dff4ff"))
		if c.dot_t > 0.0 or c.burn_t > 0.0:
			var col2: Color = Art.col(Sim.El.SHADE) if c.dot_t > 0.0 else Art.col(Sim.El.EMBER)
			for i in 2:
				var rise := fmod(_clock * 1.4 + i * 0.5 + c.phase, 1.0)
				b.disc(px(c.pos) + Vector2((i - 0.5) * 0.2 * _u, -rise * 0.4 * _u), 0.045 * _u * (1.0 - rise), Color(col2, 0.8))
		if c.mark_t > 0.0:
			_ring(b, px(c.pos), 0.34 * _u, Color(Art.col(Sim.El.SHADE), 0.6), 2.5)

## Each shot as its tower throws it: a dart, an acorn's arc, an orb, a
## beam of sun, a jet of steam, a crackle of lightning along a chain.
func _draw_shots(b: Face.Builder) -> void:
	for s: Dictionary in _shots:
		var k: float = s.t / SHOT_LIFE
		var from: Vector2 = px(s.from)
		var key: String = s.key
		var targets: Array = s.to
		if targets.is_empty():
			continue
		var first: Vector2 = px(targets[0])
		match key:
			"thorn":
				var p := from.lerp(first, minf(1.0, k * 1.6))
				var dir := (first - from).normalized()
				b.stroke(PackedVector2Array([p - dir * 0.16 * _u, p]), 0.05 * _u, Art.BRAMBLE_DEEP)
			"acorn":
				var q := minf(1.0, k * 1.4)
				var p := from.lerp(first, q) + Vector2(0, -sin(q * PI) * 0.5 * _u)
				b.ellipse(p, 0.08 * _u, 0.1 * _u, Art.ACORN)
				b.ellipse(p + Vector2(0, -0.07 * _u), 0.09 * _u, 0.05 * _u, Art.ACORN_CAP)
				if q >= 1.0:
					b.disc(first, 0.9 * _u * (k - 0.7) / 0.3, Color(Art.ACORN, 0.3 * (1.0 - k)))
			"sun", "eclipse", "frost", "bloom":
				var els: Array = Sim.TOWERS[key].els
				var col: Color = Art.col(els[els.size() - 1])
				var a := 1.0 - k
				b.stroke(PackedVector2Array([from, first]), 0.16 * _u * a, Color(col, 0.35 * a))
				b.stroke(PackedVector2Array([from, first]), 0.06 * _u * a, Color(col.lightened(0.5), 0.9 * a))
				b.disc(first, 0.14 * _u * a, Color(col.lightened(0.4), 0.8 * a))
			"lightning":
				var a := 1.0 - k
				var pts := [from] + targets.map(func(p: Vector2) -> Vector2: return px(p))
				for i in range(1, pts.size()):
					_zigzag(b, pts[i - 1], pts[i], Color(Art.col(Sim.El.SUN).lightened(0.4), a), 0.05 * _u, i * 3 + int(s.t * 40.0))
			"steam":
				var end: Vector2 = first
				var a := 1.0 - k
				b.stroke(PackedVector2Array([from, end]), 0.34 * _u * (0.5 + k), Color(1, 1, 1, 0.35 * a))
				b.stroke(PackedVector2Array([from, end]), 0.14 * _u, Color(Art.col(Sim.El.RAIN).lightened(0.5), 0.6 * a))
			"spill":
				var p := from.lerp(first, minf(1.0, k * 1.5))
				b.disc(p, 0.08 * _u, Color(Art.col(Sim.El.SHADE), 0.8))
			_:
				var els: Array = Sim.TOWERS[key].els
				var col: Color = Art.col(els[0])
				var col2: Color = Art.col(els[els.size() - 1])
				for i in targets.size():
					var to := px(targets[i])
					var q := minf(1.0, k * 1.5)
					var p := from.lerp(to, q)
					var r: float = (0.1 + 0.02 * s.level) * _u
					if q < 1.0:
						b.disc(p, r * 1.7, Color(col, 0.25))
						b.disc(p, r, col2.lightened(0.2))
						b.disc(p, r * 0.5, Color(1, 1, 1, 0.8))
					else:
						var a := 1.0 - (k - 0.66) / 0.34
						b.disc(to, r * 2.4 * (1.2 - a * 0.5), Color(col2, 0.35 * a))

static func _zigzag(b: Face.Builder, a: Vector2, z: Vector2, col: Color, w: float, seed_v: int) -> void:
	var pts := PackedVector2Array([a])
	var side := (z - a).orthogonal().normalized()
	var n := 6
	for i in range(1, n):
		var j := sin(seed_v * 12.9898 + i * 78.233) * 43758.5453
		j = (j - floorf(j)) - 0.5
		pts.append(a.lerp(z, float(i) / n) + side * j * (z - a).length() * 0.25)
	pts.append(z)
	b.stroke(pts, w * 2.6, Color(col, col.a * 0.35))
	b.stroke(pts, w, col)

func _draw_pops() -> void:
	var font := get_theme_font("font", "SheetTitle")
	for p: Dictionary in _pops:
		var a := 1.0 - clampf((p.t - 0.5) / 0.4, 0.0, 1.0)
		var at := px(p.pos) + Vector2(0, -p.t * 50.0 - 0.3 * _u)
		var full := 32
		var size := full if Motion.reduce else maxi(8, int(lerpf(12.0, full, Motion.back_out(minf(1.0, p.t / 0.28)))))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		field.draw_string(font, at + Vector2(-w * 0.5 + 2, 3), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.15, 0.12, 0.05, 0.5 * a))
		field.draw_string(font, at + Vector2(-w * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(p.col, a))

# --- the end ---

func _finish(won: bool) -> void:
	_sel = Vector2i(-1, -1)
	_refresh_panel(true)
	var better := Record.add(GAME, sim.score, sim.wave)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.wave,
		"seconds": secs, "kills": sim.kills, "leaks": sim.leaks, "won": won, "best": better,
		"towers": sim.towers.size(), "picks": ",".join(PackedStringArray(sim.picked.map(func(e: int) -> String: return String(Sim.EL_KEY[e]))))})
	_show_banner(tr("HR_WON") if won else tr("FF_GAME_OVER"), "", 1.6)
	top_bar.refresh(self)
	get_tree().create_timer(1.8).timeout.connect(_show_end.bind(better, won))

func _show_end(better: bool, won: bool) -> void:
	if sim == null or not sim.is_over() or _end != null:
		return
	_fx.cue("new_best" if better else ("victory" if won else "game_over"))
	_end = _build_end(better, won)
	add_child(_end)
	Motion.appear(_end, 0.0, 1.0, 0.3)
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if better or won:
		var fx := Fx2D.new()
		_end.add_child(fx)
		var mid := size * 0.5
		for k in 8:
			var at := mid + Vector2.from_angle(TAU * k / 8.0 - PI * 0.5) * Vector2(400.0, 330.0)
			var el: int = Sim.ELEMENTS[k % 6]
			get_tree().create_timer(0.25 + 0.14 * k).timeout.connect(func() -> void:
				if is_instance_valid(fx):
					fx.puff(at, Art.col(el), 12))

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
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(0, 170)
	# a sun-orb pot with the last pest to reach it, or a ring of the orbs picked
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var mid := Vector2(seat.size.x * 0.5, 90)
		var els: Array = sim.picked if not sim.picked.is_empty() else [Sim.El.SUN]
		for i in els.size():
			var a := TAU * i / els.size() + t * 0.6
			var p := mid + Vector2(cos(a) * 150.0, sin(a) * 34.0)
			seat.draw_mesh(Art.orb_mesh(els[i], 34.0), null, Transform2D(0.0, p))
		seat.draw_mesh(Art.tower("thorn", 2, 150.0), null, Transform2D(0.0, mid + Vector2(0, sin(t * 2.4) * 5.0))))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else ("HR_WON_CARD" if won else "HR_LOST_CARD")
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(head)
	var score := Label.new()
	score.text = Record.grouped(sim.score)
	score.theme_type_variation = "DayBig"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score)
	var line := Label.new()
	line.text = "%s  ·  %s  ·  %s" % [tr("HR_WAVES_HELD") % sim.wave, tr("HR_KILLS") % sim.kills,
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

# --- chrome ---

func _on_reset() -> void:
	if sim != null and not sim.is_over():
		Analytics.track("board_reset", {"puzzle_id": GAME})
	if _pick_card != null:
		_pick_card.queue_free()
		_pick_card = null
	_new_game()

func _on_back() -> void:
	if sim != null and not sim.is_over() and sim.wave > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.wave})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	if Sim.inside(_sel):
		_select(Vector2i(-1, -1))
		return
	_on_back()

# --- the panel's chips ---

## A paper chip with a tower drawn on it and its price under it (or a word
## over the price: Upgrade, Sell, a dual's name). Dimmed when it cannot be
## afforded, but still pressable, so the refusal can say why.
class _TowerChip extends Button:
	var key := ""
	var level := 0
	var price := ""
	var word := ""
	var can := true

	func _init(k: String, lv: int, p: String, ok: bool, w := "") -> void:
		key = k
		level = lv
		price = p
		word = w
		can = ok
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(146, 170)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for st in ["normal", "hover", "focus"]:
			add_theme_stylebox_override(st, CozyTheme.chip(Color("fffdf8") if ok else Color("efe7da"), 26))
		add_theme_stylebox_override("pressed", CozyTheme.chip(Color("fffdf8"), 26, Color.TRANSPARENT, 0, true))
		material = CanvasItemMaterial.new()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 62)
		var alpha := 1.0 if can else 0.5
		if key != "":
			draw_mesh(Art.tower(key, level, 92.0), null, Transform2D(0.0, c), Color(1, 1, 1, alpha))
		else:
			# a coin purse for the sale
			draw_circle(c + Vector2(0, 4), 30.0, Art.WOOD)
			draw_circle(c + Vector2(0, 2), 26.0, Color("c99a63"))
			draw_circle(c + Vector2(-8, -6), 10.0, Pal.SUN_RAY)
			draw_circle(c + Vector2(10, -2), 10.0, Pal.SUN)
		var font := get_theme_font("font", "SheetTitle")
		var small := get_theme_font("font", "CardBlurb")
		var y := 136.0
		if word != "":
			var fs := 22
			var ww := small.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			while ww > size.x - 10 and fs > 14:
				fs -= 1
				ww = small.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(small, Vector2((size.x - ww) * 0.5, 118), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.TEXT_DIM, alpha))
			y = 152.0
		var w := font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var coin := Vector2((size.x - w) * 0.5 - 14, y - 10)
		draw_circle(coin, 9.0, Color(Pal.SUN, alpha))
		draw_circle(coin, 5.0, Color(Pal.SUN_RAY, alpha))
		draw_string(font, Vector2((size.x - w) * 0.5 + 4, y), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(Pal.TEXT if can else Pal.TEXT_DIM, 1.0))

## One element on the pick card: its orb, its name, and what it beats.
class _ElementChip extends Button:
	var el := 0
	var taken := false

	func _init(e: int, t: bool) -> void:
		el = e
		taken = t
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 120)
		for st in ["normal", "hover", "focus", "disabled"]:
			add_theme_stylebox_override(st, CozyTheme.chip(Color("fffdf8") if not t else Color("efe7da"), 28))
		add_theme_stylebox_override("pressed", CozyTheme.chip(Color("fffdf8"), 28, Color.TRANSPARENT, 0, true))
		material = CanvasItemMaterial.new()

	func _draw() -> void:
		var alpha := 0.45 if taken else 1.0
		draw_mesh(Art.orb_mesh(el, 38.0), null, Transform2D(0.0, Vector2(66, size.y * 0.5)), Color(1, 1, 1, alpha))
		var font := get_theme_font("font", "SheetTitle")
		var small := get_theme_font("font", "CardBlurb")
		var el_name := tr("HR_EL_" + String(Sim.EL_KEY[el]).to_upper())
		draw_string(font, Vector2(122, size.y * 0.5 - 4), el_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 130, 34, Color(Pal.TEXT, alpha))
		var line := tr("HR_TAKEN") if taken else tr("HR_BEATS") % tr("HR_EL_" + String(Sim.EL_KEY[Sim.beats(el)]).to_upper())
		draw_string(small, Vector2(122, size.y * 0.5 + 32), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 130, 22, Color(Pal.TEXT_DIM, alpha))

## The next wave's pest on a little lawn disc, in its element's colour.
class _WaveSign extends Control:
	var kind := 0
	var el := 0

	func _init(k: int, e: int) -> void:
		kind = k
		el = e
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, size.x * 0.46, Color("e6f0da"))
		draw_arc(c, size.x * 0.46, 0, TAU, 48, Art.col(el), 5.0, true)
		draw_mesh(Art.creep(kind, el, 0, 96.0 if kind != Sim.Kind.BOSS else 60.0), null, Transform2D(0.0, c + Vector2(0, 4)))
