extends Control

## Lucky Thirteen: the seventh game on the Arcade tab, a number merge played
## by drawing chains (spec
## docs/superpowers/specs/2026-09-27-arcade-thirteen-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the score, the best and the biggest pebble, the tray in the
## Arcade's wooden frame, and under it the clovers and the five tools.
##
## Play: press on a pebble and drag through three or more touching pebbles
## of its number (diagonals count; drag back to take the last one off), then
## let go: they merge into the last one, a number higher. The game is
## arcade/thirteen_sim.gd, which resolves a move at once; this screen draws
## the tray settling after it and plays its events.
##
## Drawing: the raked sand is one still mesh built on resize; every pebble
## is one cached mesh moved by the transform with its number lettered over
## it; the chain, the halos and the sparks are one live mesh.

signal closed

const Sim = preload("res://arcade/thirteen_sim.gd")
const Art = preload("res://arcade/thirteen_art.gd")
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

const GAME := "thirteen"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const TOOLS_H := 150.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
## Cells a second a pebble slides at when a tool moves it, and the pull a
## pebble falls into a gap with (cells a second squared), from this pace.
const SLIDE_V := 9.0
const GRAVITY := 70.0
const FALL_V0 := 3.0
## How long a merged-away pebble takes to roll along the chain into the one
## it joined, and how much later each one after it sets off.
const JOIN_T := 0.2
const JOIN_STEP := 0.025
## How far from a pebble's centre a finger has to come to take it into the
## chain, in cells: under half, so a diagonal drag does not catch the
## pebbles beside the corner it cuts.
const HIT := 0.42
## Seconds without a move before the tray shows one.
const HINT_AFTER := 7.0
const FLIGHT_T := 0.6
const CONFETTI := [Color("f2b632"), Color("ec7f8c"), Color("6fb4e2"), Color("5fae5a"), Color("c98ac6")]

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var field: Control
var _fx: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _score_l: Label
var _best_l: Label
var _score_k: Label
var _big_view: Control
var _clover_l: Label
var _clover_icon: Control
var _tool_buttons := {}
var _price_l := {}
var _banner: Label
var _sub: Label
var _banner_tw: Tween
var _stuck_box: Control
var _end: Control
var _seat: Control
var _started_at := 0
var _best := 0
var _shown_score := -1
var _roll := 0.0
var _beat_best := false
var _clock := 0.0
## Pixels a cell, and the tray's top-left in `field`.
var _u := 100.0
var _origin := Vector2.ZERO
var _bed: ArrayMesh
var _live: ArrayMesh
## One a pebble in the tray: id -> {pos: Vector2 (column, row, in cells),
## v, vel, hold: seconds before it may move, squash, amt, bump, pop,
## pending (the number it takes once the chain has rolled in), pend_t}.
var _vis := {}
## Pebbles rolling along the chain into the one they joined:
## {v, path: Array of cells, from: index on it, t}.
var _joins: Array = []
## Pebbles knocked out of the tray: {v, pos (px), vel, spin, rot, t}.
var _debris: Array = []
## Numbers rising off a merge: {pos (cells), text, t, col, big}.
var _pops: Array = []
var _flights: Array = []
var _owed := 0
var _afford := {}
var _air: Control
var _air_fx: Node2D
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _dragging := false
var _last_at := Vector2.ZERO
var _armed := -1
var _swap_a := Vector2i(-1, -1)
var _idle := 0.0
var _hint: Array = []
var _big_t := 1.0
## Seconds since the chain last changed, for its pebbles' little hop.
var _chain_t := 0.0

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

	top_bar = FlatTopBar.new("Lucky Thirteen", tr("LT_MOTTO"), true)
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
	_banner.add_theme_color_override("font_color", Color("fffaf0"))
	_banner.add_theme_color_override("font_shadow_color", Color(0.2, 0.14, 0.06, 0.6))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	_banner.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.1, 0.55))
	_banner.add_theme_constant_override("outline_size", 14)
	over.add_child(_banner)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetTitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_color_override("font_color", Color("fffaf0"))
	_sub.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.1, 0.55))
	_sub.add_theme_constant_override("outline_size", 12)
	over.add_child(_sub)
	over.modulate.a = 0.0
	_banner.set_meta("box", over)

	_stuck_box = _build_stuck()
	field.add_child(_stuck_box)

	col.add_child(_build_tools())
	_air = Control.new()
	_air.name = "Air"
	_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_air.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_air.draw.connect(_draw_air)
	add_child(_air)
	_air_fx = Fx2D.new()
	_air.add_child(_air_fx)
	_apply_insets()

func _plate(key: String, ratio: float) -> Array:
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_stretch_ratio = ratio
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
	return [plate, words, kicker]

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["FF_SCORE", "FF_BEST"]:
		var parts := _plate(key, 1.3 if key == "FF_SCORE" else 1.0)
		var value := Label.new()
		value.text = "0"
		value.theme_type_variation = "SheetTitle"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parts[1].add_child(value)
		row.add_child(parts[0])
		made.append(value)
		if key == "FF_SCORE":
			_score_k = parts[2]
	_score_l = made[0]
	_best_l = made[1]
	# the biggest pebble so far, drawn beside its kicker
	var parts := _plate("LT_BIGGEST", 0.8)
	_big_view = Control.new()
	_big_view.custom_minimum_size = Vector2(0, 60)
	_big_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_view.draw.connect(_draw_biggest)
	parts[1].add_child(_big_view)
	row.add_child(parts[0])
	return row

## The clovers on the left, then the five tools: each a paper chip with its
## picture and its price, dimmed until it can be bought.
func _build_tools() -> Control:
	var row := HBoxContainer.new()
	row.name = "Tools"
	row.custom_minimum_size.y = TOOLS_H
	row.add_theme_constant_override("separation", 12)
	var bank := _plate("LT_CLOVERS", 1.0)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 4)
	bank[1].add_child(line)
	_clover_icon = _icon(func(ci: Control) -> void:
		ci.draw_mesh(Art.clover(ci.size.y * 0.95), null, Transform2D(0.0, ci.size * 0.5)))
	_clover_icon.custom_minimum_size = Vector2(44, 52)
	line.add_child(_clover_icon)
	_clover_l = Label.new()
	_clover_l.text = "0"
	_clover_l.theme_type_variation = "SheetTitle"
	line.add_child(_clover_l)
	row.add_child(bank[0])
	for tool in [Sim.Tool.UNDO, Sim.Tool.SWAP, Sim.Tool.PLUCK, Sim.Tool.SHUFFLE, Sim.Tool.LIFT]:
		row.add_child(_tool_chip(tool))
	return row

func _icon(painter: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: painter.call(c))
	c.resized.connect(c.queue_redraw)
	return c

func _tool_chip(tool: int) -> Control:
	var b := Button.new()
	b.name = "Tool_" + Sim.TOOL_KEYS[tool]
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	_style_chip(b, false)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var pic := _icon(func(ci: Control) -> void:
		var s := minf(ci.size.y, ci.size.x) * 1.12
		ci.draw_mesh(Art.tool_icon(Sim.TOOL_KEYS[tool], s), null, Transform2D(0.0, ci.size * 0.5)))
	pic.custom_minimum_size = Vector2(0, 80)
	col.add_child(pic)
	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", 2)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(price)
	var leaf := _icon(func(ci: Control) -> void:
		ci.draw_mesh(Art.clover(ci.size.y * 0.8), null, Transform2D(0.0, ci.size * 0.5)))
	leaf.custom_minimum_size = Vector2(26, 32)
	price.add_child(leaf)
	var cost := Label.new()
	cost.text = str(Sim.COSTS[tool])
	cost.theme_type_variation = "MenuKicker"
	price.add_child(cost)
	_price_l[tool] = cost
	b.pressed.connect(_on_tool.bind(tool))
	_tool_buttons[tool] = b
	return b

## A tool chip's paper; an armed one is lit in the sun's colour.
func _style_chip(b: Button, lit: bool) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill := Color("fbe3a0") if lit else (Color("fcf7ef") if st != "pressed" else Color("f1e6d2"))
		var sb := CozyTheme.lifted(fill, 30, 8)
		if lit:
			sb.border_color = Color("e0a92e")
			sb.set_border_width_all(4)
		b.add_theme_stylebox_override(st, sb)

## Under the tray when it is stuck: what happened, and the way out.
func _build_stuck() -> Control:
	var col := VBoxContainer.new()
	col.name = "Stuck"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.visible = false
	var line := Label.new()
	line.text = "LT_STUCK_LINE"
	line.theme_type_variation = "SheetTitle"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_color_override("font_color", Color("fffaf0"))
	line.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.1, 0.6))
	line.add_theme_constant_override("outline_size", 12)
	col.add_child(line)
	var end := IconButton.new("chevron_right", tr("LT_END_GAME"), "SunButton")
	end.name = "EndGame"
	end.custom_minimum_size = Vector2(420, 100)
	end.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	end.pressed.connect(func() -> void:
		if sim != null:
			sim.give_up()
			_play_events())
	col.add_child(end)
	return col

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The tray is COLS by ROWS cells, scaled to the room and centred.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_u = floorf(minf((s.x - 36.0) / Sim.COLS, (s.y - 36.0) / Sim.ROWS))
	var board := Vector2(Sim.COLS, Sim.ROWS) * _u
	_origin = Vector2(floorf((s.x - board.x) * 0.5), floorf((s.y - board.y) * 0.5))
	_bed = _build_bed()
	var box: Control = _banner.get_meta("box")
	box.position = Vector2(24, s.y * 0.3)
	box.size = Vector2(s.x - 48, 0)
	_stuck_box.position = Vector2(24, s.y * 0.5)
	_stuck_box.size = Vector2(s.x - 48, 0)
	field.queue_redraw()

## The centre of a cell, in the field's pixels (fractions allowed).
func px(c: float, r: float) -> Vector2:
	return _origin + Vector2((c + 0.5) * _u, (r + 0.5) * _u)

## The cell a point is over, or (-1, -1); with `near`, only within HIT of
## its centre.
func cell_at(at: Vector2, near := false) -> Vector2i:
	var f := (at - _origin) / _u
	var cell := Vector2i(floori(f.x), floori(f.y))
	if cell.x < 0 or cell.x >= Sim.COLS or cell.y < 0 or cell.y >= Sim.ROWS:
		return Vector2i(-1, -1)
	if near and (f - Vector2(cell) - Vector2(0.5, 0.5)).length() > HIT:
		return Vector2i(-1, -1)
	return cell

# --- the game ---

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	_seat = null
	sim = Sim.new()
	_vis.clear()
	_joins.clear()
	_debris.clear()
	_pops.clear()
	_flights.clear()
	_owed = 0
	_afford.clear()
	_shake = 0.0
	_roll = 0.0
	_beat_best = false
	_dragging = false
	_armed = -1
	_swap_a = Vector2i(-1, -1)
	_idle = 0.0
	_hint = []
	_stuck_box.visible = false
	for tool: int in _tool_buttons:
		_style_chip(_tool_buttons[tool], false)
	_best = Record.best(GAME)
	_shown_score = -1
	_started_at = Time.get_ticks_msec()
	# the opening tray rolls in, a column at a time
	for c in Sim.COLS:
		for r in Sim.ROWS:
			var cell: Dictionary = sim.grid[c][r]
			var vis := _new_vis(Vector2(c, r - Sim.ROWS - 0.5), int(cell.v))
			vis.hold = 0.0 if Motion.reduce else 0.05 * c + 0.03 * (Sim.ROWS - r)
			_vis[cell.id] = vis
	_refresh_hud()
	top_bar.refresh(self)
	_fx.cue("start")
	_play_events()
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
	_clock += delta
	_animate(delta)
	_refresh_hud(delta)
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	field.queue_redraw()

func _new_vis(pos: Vector2, v: int) -> Dictionary:
	return {"pos": pos, "v": v, "vel": 0.0, "hold": 0.0, "squash": -1.0, "amt": 0.0, "bump": -1.0, "pop": -1.0, "pending": 0, "pend_t": 0.0}

func _animate(delta: float) -> void:
	# every pebble in the tray settles toward its cell: down a gap under
	# gravity, sideways (a swap, a shuffle, an undo) at a slide
	var seen := {}
	for c in Sim.COLS:
		for r in Sim.ROWS:
			var cell: Dictionary = sim.grid[c][r]
			if cell.is_empty():
				continue
			seen[cell.id] = true
			var want := Vector2(c, r)
			if not _vis.has(cell.id):
				var fresh := _new_vis(want, int(cell.v))
				fresh.pop = 0.0
				_vis[cell.id] = fresh
			var vis: Dictionary = _vis[cell.id]
			if vis.pend_t > 0.0:
				vis.pend_t -= delta
				if vis.pend_t <= 0.0:
					vis.v = vis.pending
					vis.pending = 0
					vis.bump = 0.0
			elif int(vis.v) != int(cell.v) and vis.pending == 0:
				vis.v = cell.v
				vis.bump = 0.0
			if vis.hold > 0.0:
				vis.hold -= delta
			elif Motion.reduce:
				vis.pos = want
			elif vis.pos.y < want.y - 0.001 and absf(vis.pos.x - want.x) < 0.001:
				vis.vel = maxf(float(vis.vel), FALL_V0) + GRAVITY * delta
				vis.pos.y = minf(want.y, vis.pos.y + vis.vel * delta)
				if vis.pos.y >= want.y:
					_squash(vis, clampf(float(vis.vel) * 0.012, 0.05, 0.15))
					vis.vel = 0.0
					_fx.cue("land", randf_range(0.9, 1.15), -4.0)
			elif vis.pos != want:
				vis.pos = vis.pos.move_toward(want, SLIDE_V * delta)
				if vis.pos == want:
					_squash(vis, 0.06)
			if vis.squash >= 0.0:
				vis.squash += delta
			if vis.bump >= 0.0:
				vis.bump += delta
			if vis.pop >= 0.0:
				vis.pop += delta
	for id in _vis.keys():
		if not seen.has(id):
			_vis.erase(id)
	for j: Dictionary in _joins:
		j.t += delta
	_joins = _joins.filter(func(j: Dictionary) -> bool: return j.t < JOIN_T)
	for d: Dictionary in _debris:
		d.t += delta
		d.vel.y += 2600.0 * delta
		d.pos += d.vel * delta
		d.rot += d.spin * delta
	_debris = _debris.filter(func(d: Dictionary) -> bool: return d.t < 1.6 and d.pos.y < field.size.y + _u)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 0.9)
	_big_t += delta
	_chain_t += delta
	_fly(delta)
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 12.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO
	# a tray left alone shows a move
	if _dragging or busy() or sim.phase != Sim.Phase.PLAY or _armed >= 0:
		_idle = 0.0
		_hint = []
	else:
		_idle += delta
		if _idle >= HINT_AFTER and _hint.is_empty():
			_hint = sim.hint()

## Whether the tray is still settling: a chain rolling in, a pebble falling
## or sliding. A new chain waits for it.
func busy() -> bool:
	if not _joins.is_empty():
		return true
	for id in _vis:
		var vis: Dictionary = _vis[id]
		var p := sim_cell(id)
		if vis.hold > 0.0 or vis.pend_t > 0.0 or (p.x >= 0 and vis.pos != Vector2(p)):
			return true
	return false

func sim_cell(id: int) -> Vector2i:
	for c in Sim.COLS:
		for r in Sim.ROWS:
			var cell: Dictionary = sim.grid[c][r]
			if not cell.is_empty() and int(cell.id) == id:
				return Vector2i(c, r)
	return Vector2i(-1, -1)

func _squash(vis: Dictionary, amt: float) -> void:
	if Motion.reduce:
		return
	vis.squash = 0.0
	vis.amt = amt

func _fly(delta: float) -> void:
	if _flights.is_empty():
		return
	for f: Dictionary in _flights:
		f.t += delta
		if f.t >= FLIGHT_T and not f.get("home", false):
			f.home = true
			_owed = maxi(0, _owed - int(f.value))
			_kick(_clover_icon, 0.22, 0.22)
			_kick(_clover_l, 0.14, 0.22)
	_flights = _flights.filter(func(f: Dictionary) -> bool: return not f.get("home", false))
	_air.queue_redraw()

func _on_field_input(event: InputEvent) -> void:
	var at := Vector2.INF
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.index != 0:
			return
		at = t.position
		pressed = t.pressed
		released = not t.pressed
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != 0:
			return
		at = d.position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
		pressed = (event as InputEventMouseButton).pressed
		released = not pressed
	elif event is InputEventMouseMotion:
		at = (event as InputEventMouseMotion).position
	if at == Vector2.INF or sim == null or sim.is_over() or settings_sheet.is_open():
		return
	_idle = 0.0
	if pressed:
		if _armed >= 0:
			_target(cell_at(at))
			return
		if busy():
			return
		var cell := cell_at(at)
		if cell.x >= 0 and sim.begin(cell):
			_dragging = true
			_last_at = at
			_play_events()
		return
	if not _dragging:
		return
	if released:
		_dragging = false
		sim.commit()
		_play_events()
		return
	# walk the finger's way from where it last was, so a quick drag does not
	# skip a pebble it crossed
	var step := _u * 0.2
	var n := maxi(1, ceili(_last_at.distance_to(at) / step))
	for k in range(1, n + 1):
		var p := _last_at.lerp(at, float(k) / n)
		var cell := cell_at(p, true)
		if cell.x >= 0:
			sim.extend(cell)
	_last_at = at
	_play_events()

## A tap with a tool armed: Pluck and Lift act on the pebble tapped, Swap
## on the second of two.
func _target(cell: Vector2i) -> void:
	if cell.x < 0 or busy():
		return
	var tool := _armed
	if tool == Sim.Tool.SWAP:
		if _swap_a.x < 0 or _swap_a == cell:
			_swap_a = cell if _swap_a != cell else Vector2i(-1, -1)
			_fx.cue("select")
			return
		if not sim.can_target(tool, _swap_a, cell):
			_refuse(tool, "LT_SWAP_SAME")
			return
		var a := _swap_a
		_disarm()
		sim.use(tool, a, cell)
	else:
		if not sim.can_target(tool, cell):
			_refuse(tool, "LT_LIFT_BIGGEST" if tool == Sim.Tool.LIFT else "")
			return
		_disarm()
		sim.use(tool, cell)
	_play_events()

func _refuse(tool: int, line: String) -> void:
	_fx.cue("refused")
	Motion.shiver(_tool_buttons[tool])
	if line != "":
		_show_banner("", tr(line), 0.8)

func _on_tool(tool: int) -> void:
	if sim == null or sim.is_over():
		return
	if _armed == tool:
		_disarm()
		return
	_disarm()
	if not sim.can_use(tool) or busy():
		sim.use(tool)
		_play_events()
		return
	if tool in Sim.TARGETED:
		_armed = tool
		_swap_a = Vector2i(-1, -1)
		_style_chip(_tool_buttons[tool], true)
		_fx.cue("arm")
		var lines := {Sim.Tool.SWAP: "LT_SWAP_LINE", Sim.Tool.PLUCK: "LT_PLUCK_LINE", Sim.Tool.LIFT: "LT_LIFT_LINE"}
		_show_banner("", tr(lines[tool]), 1.0)
		return
	sim.use(tool)
	_play_events()

func _disarm() -> void:
	if _armed >= 0:
		_style_chip(_tool_buttons[_armed], false)
	_armed = -1
	_swap_a = Vector2i(-1, -1)

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		match String(ev.type):
			"deal":
				_show_banner(tr("FF_READY"), tr("LT_READY_LINE"), 1.2)
			"select":
				_chain_t = 0.0
				_fx.cue("select", minf(0.9 + 0.07 * (int(ev.n) - 1), 1.9))
			"unselect":
				_chain_t = 0.0
				_fx.cue("unselect", minf(0.9 + 0.07 * int(ev.n), 1.9))
			"short":
				if int(ev.n) >= 2:
					_fx.cue("short")
					_show_banner("", tr("LT_SHORT"), 0.6)
			"merge":
				_on_merge(ev)
			"settle":
				var wait := 0.0 if Motion.reduce else JOIN_T + JOIN_STEP * 2.0
				for f: Dictionary in ev.falls:
					if _vis.has(f.id):
						_vis[f.id].hold = maxf(float(_vis[f.id].hold), wait)
				for f: Dictionary in ev.fresh:
					var vis := _new_vis(Vector2(f.col, float(f.from)), int(f.v))
					vis.hold = wait + 0.04 * f.col
					_vis[f.id] = vis
			"goal":
				_show_banner("13!", tr("LT_GOAL_LINE"), 1.6)
				_fx.cue("goal")
				_confetti()
				_shake = maxf(_shake, 0.5)
			"stuck":
				_fx.cue("stuck")
				_show_banner(tr("LT_STUCK"), "", 1.2)
			"tool":
				_on_tool_event(ev)
			"refused":
				_fx.cue("refused")
				var t: int = Sim.TOOL_KEYS.find_key(String(ev.tool))
				Motion.shiver(_tool_buttons[t])
			"over":
				_game_over()
	sim.events.clear()
	_stuck_box.visible = sim.phase == Sim.Phase.STUCK
	top_bar.refresh(self)

func _on_merge(ev: Dictionary) -> void:
	var into: Vector2i = ev.cell
	var n: int = ev.n
	var old_v: int = int(ev.v) - 1
	# the chain as drawn, in order: every pebble in it rolls along the rest
	# of it into the last
	var chain: Array = []
	for g: Dictionary in ev.gone:
		chain.append(Vector2(g.cell))
	chain.append(Vector2(into))
	if not Motion.reduce:
		for k in (ev.gone as Array).size():
			_joins.append({"v": old_v, "path": chain, "from": k, "t": -JOIN_STEP * ((ev.gone as Array).size() - 1 - k)})
	for g: Dictionary in ev.gone:
		_vis.erase(g.id)
	if _vis.has(ev.id):
		var vis: Dictionary = _vis[ev.id]
		vis.pending = int(ev.v)
		vis.pend_t = 0.0001 if Motion.reduce else JOIN_T + JOIN_STEP
	var at := px(into.x, into.y)
	var big := int(ev.v) >= 10
	_pop(Vector2(into) + Vector2(0, -0.3), "+%s" % Record.grouped(int(ev.points)), Color("fffaf0") if n < 6 else Pal.SUN, big)
	var delay := 0.0 if Motion.reduce else JOIN_T
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(_fx):
			return
		_fx.puff(at, Art.paint(int(ev.v)), 6)
		_fx.ring(at, 0.75 * _u, Art.paint(int(ev.v)).lightened(0.25))
		_fx.cue("merge", clampf(0.85 + 0.05 * int(ev.v), 0.85, 1.6))
		if bool(ev.get("new_max", false)):
			_big_t = 0.0
			_kick(_big_view, 0.3, 0.35)
			_fx.sparkle(at, Color("fffaf0"))
			if int(ev.v) != Sim.GOAL:
				_fx.cue("new_number")
				if int(ev.v) >= 7:
					_show_banner("%d!" % int(ev.v), "", 0.6)
		if big:
			_fx.ring(at, 1.2 * _u, Art.GOLD))
	_launch_clovers(ev)
	if n >= 6:
		_kick(_score_k, 0.3, 0.35)
		_shake = maxf(_shake, 0.1 + 0.02 * n)

func _on_tool_event(ev: Dictionary) -> void:
	_kick(_clover_l, 0.25, 0.3)
	match String(ev.tool):
		"undo":
			_fx.cue("undo")
			_joins.clear()
			# every pebble the undo brought back pops in where it stands
			for id in _vis:
				_vis[id].hold = 0.0
				_vis[id].pend_t = 0.0
				_vis[id].pending = 0
		"swap":
			_fx.cue("swap")
		"pluck":
			_fx.cue("pluck")
			var cell: Vector2i = ev.cell
			_fling(int(ev.v), px(cell.x, cell.y))
			_fx.puff(px(cell.x, cell.y), Art.SAND_DEEP, 8)
			_vis.erase(ev.id)
		"shuffle":
			_fx.cue("shuffle")
			_shake = maxf(_shake, 0.45)
			# the pebbles are shaken up before they slide to their new places
			if not Motion.reduce:
				for id in _vis:
					var vis: Dictionary = _vis[id]
					vis.pos += Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
		"lift":
			_fx.cue("lift")
			var cell: Vector2i = ev.cell
			_fx.sparkle(px(cell.x, cell.y), Art.GOLD)
			_fx.ring(px(cell.x, cell.y), 0.8 * _u, Art.GOLD)

## The clovers a merge earned fly up out of it and into the bank, a few at
## a time; the bank counts each as it lands.
func _launch_clovers(ev: Dictionary) -> void:
	var got: int = ev.clovers
	if got <= 0 or Motion.reduce:
		return
	var n := mini(got, 5)
	var to := _in_air(_clover_icon, _clover_icon.size * 0.5)
	var cell: Vector2i = ev.cell
	var from := _in_air(field, px(cell.x, cell.y))
	for k in n:
		var ctrl := from.lerp(to, 0.35) + Vector2(randf_range(-160.0, 160.0), -240.0)
		var value := got / n + (1 if k < got % n else 0)
		_flights.append({"from": from, "ctrl": ctrl, "to": to, "t": -JOIN_T - 0.07 * k, "value": value, "spin": randf_range(-6.0, 6.0)})
		_owed += value

## A bump that starts from rest, so a run of them never grows a label.
func _kick(node: Control, amount: float, time: float) -> void:
	var old: Tween = node.get_meta("kick") if node.has_meta("kick") else null
	Motion.stop(old)
	node.scale = Vector2.ONE
	node.pivot_offset = node.size * 0.5
	var tw := Motion.bump(node, amount, time)
	if tw != null:
		node.set_meta("kick", tw)

func _in_air(c: Control, at: Vector2) -> Vector2:
	return _air.get_global_transform().affine_inverse() * (c.get_global_transform() * at)

func _confetti() -> void:
	if Motion.reduce:
		return
	for k in 7:
		var at := Vector2(field.size.x * (0.12 + 0.76 * k / 6.0), field.size.y * (0.25 + 0.1 * (k % 2)))
		var t := get_tree().create_timer(0.1 * k)
		t.timeout.connect(func() -> void:
			if is_instance_valid(_fx):
				_fx.puff(at, CONFETTI[k % CONFETTI.size()], 10))

## A pebble knocked out of the tray: it flies out, spinning, and falls away.
func _fling(v: int, at: Vector2) -> void:
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.4, -0.6)).normalized()
	_debris.append({"v": v, "pos": at, "vel": dir * randf_range(500.0, 900.0), "spin": randf_range(-8.0, 8.0), "rot": 0.0, "t": 0.0})

func _show_banner(text: String, sub: String, hold: float) -> void:
	_banner.text = text
	_banner.visible = text != ""
	_sub.text = sub
	_sub.visible = sub != ""
	var box: Control = _banner.get_meta("box")
	box.size = Vector2(field.size.x - 48.0, 0)
	box.position = Vector2(24, field.size.y * 0.3)
	box.pivot_offset = Vector2(box.size.x * 0.5, 60.0)
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
	_banner_tw.tween_property(box, "scale", Vector2(1.1, 1.1), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _refresh_hud(delta := 0.0) -> void:
	if sim == null:
		return
	if sim.score != _shown_score:
		if sim.score > _shown_score and _shown_score >= 0:
			_kick(_score_l, 0.14, 0.26)
		_shown_score = sim.score
		if not _beat_best and _best > 0 and sim.score > _best:
			_beat_best = true
			_kick(_best_l, 0.3, 0.4)
	if Motion.reduce or sim.score < _roll:
		_roll = sim.score
	else:
		_roll = move_toward(_roll, sim.score, maxf(delta * absf(sim.score - _roll) * 10.0, delta * 300.0))
	var shown := Record.grouped(int(_roll))
	if _score_l.text != shown:
		_score_l.text = shown
		_best_l.text = Record.grouped(maxi(_best, int(_roll)))
	var bank := maxi(0, sim.clovers - _owed)
	var leaves := str(bank)
	if _clover_l.text != leaves:
		_clover_l.text = leaves
	for tool: int in _tool_buttons:
		var b: Button = _tool_buttons[tool]
		var price: int = sim.cost(tool)
		var label: Label = _price_l[tool]
		if label.text != str(price):
			label.text = str(price)
		var ok: bool = bank >= price and not sim.is_over() and (tool != Sim.Tool.UNDO or sim.can_undo())
		b.modulate.a = 1.0 if ok or _armed == tool else 0.5
		# a tool the bank has just reached hops and twinkles
		if ok and _afford.has(tool) and not _afford[tool] and not Motion.reduce:
			_kick(b, 0.12, 0.3)
			_air_fx.sparkle(_in_air(b, b.size * Vector2(0.5, 0.35)), Pal.SUN)
		_afford[tool] = ok
	_big_view.queue_redraw()

# --- drawing ---

## The tray's bed: fine sand raked in rows round a hollow for every pebble,
## with moss in the corners and a few clover leaves and daisies.
func _build_bed() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	_quad(b, [Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)], [Art.SAND.lightened(0.05), Art.SAND.lightened(0.05), Art.SAND.darkened(0.03), Art.SAND.darkened(0.03)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	# the rake's lines, gently waved, across the whole bed
	var y := 14.0
	while y < s.y:
		var pts := PackedVector2Array()
		for i in 25:
			var t := i / 24.0
			pts.append(Vector2(lerpf(-10.0, s.x + 10.0, t), y + sin(t * TAU * 1.5 + y * 0.02) * 6.0))
		b.stroke(pts, 3.0, Color(Art.SAND_DEEP, 0.45))
		var hi := PackedVector2Array()
		for p in pts:
			hi.append(p + Vector2(0, 3.5))
		b.stroke(hi, 1.5, Color(1, 1, 1, 0.35))
		y += 26.0
	# sunlight falling in from the top left
	for k in 3:
		var x0 := s.x * (0.02 + 0.32 * k)
		_quad(b, [Vector2(x0, 0), Vector2(x0 + s.x * 0.14, 0), Vector2(x0 + s.x * 0.14 + s.y * 0.3, s.y), Vector2(x0 + s.y * 0.3, s.y)],
			[Color(1, 1, 0.92, 0.16), Color(1, 1, 0.92, 0.16), Color(1, 1, 0.92, 0.0), Color(1, 1, 0.92, 0.0)])
	# a hollow under every pebble, the rake's lines curving round it
	for c in Sim.COLS:
		for r in Sim.ROWS:
			var at := px(c, r)
			var rr := _u * 0.47
			b.stroke(Face.Builder.ring(at, rr * 1.08, rr * 1.08), 2.0, Color(Art.SAND_DEEP, 0.55), true)
			b.disc(at, rr, Color(Art.SAND_DEEP, 0.55))
			b.disc(at + Vector2(-rr * 0.05, -rr * 0.07), rr * 0.9, Color(Art.SAND_DEEP.darkened(0.08), 0.5))
			b.stroke(Face.Builder.arc_points(at, rr * 0.98, PI * 0.1, PI * 0.9), 2.0, Color(1, 1, 1, 0.4))
	# moss creeping in at the corners, with a clover leaf or two and daisies
	for corner in [Vector2(0, 0), Vector2(s.x, 0), Vector2(0, s.y), Vector2(s.x, s.y)]:
		for i in 9:
			var p: Vector2 = corner + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * _u * 0.35
			var rr := _u * rng.randf_range(0.08, 0.16)
			b.disc(p, rr, Art.MOSS_DEEP if i % 3 == 0 else Art.MOSS)
		for i in 2:
			var p: Vector2 = corner.lerp(s * 0.5, 0.04 + 0.03 * i) + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0))
			b.disc(p, _u * 0.045, Color("fffaf0"))
			for k in 6:
				b.disc(p + Vector2.from_angle(TAU * k / 6.0) * _u * 0.05, _u * 0.03, Color("fffaf0"))
			b.disc(p, _u * 0.025, Color("f2c14e"))
	return b.mesh()

static func _quad(b: Face.Builder, p: Array, c: Array) -> void:
	var i0 := b.vertex(p[0], c[0])
	var i1 := b.vertex(p[1], c[1])
	var i2 := b.vertex(p[2], c[2])
	var i3 := b.vertex(p[3], c[3])
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)

func _draw_field() -> void:
	if _bed == null:
		_layout_field()
	if _bed == null or sim == null:
		return
	field.draw_mesh(_bed, null)
	var font := Art.font()
	var s := _u * 0.86
	var picked := {}
	for p: Vector2i in sim.path:
		picked[p] = true
	var chain_v: int = sim.value(sim.path[0]) if not sim.path.is_empty() else 0
	var stuck: bool = sim.phase == Sim.Phase.STUCK
	# the live layer under the pebbles: the chain's halos and its ribbon,
	# the hint's glow, the swap's first pick
	var under := Face.Builder.new()
	_draw_chain(under, s)
	if not under.verts.is_empty():
		_live = under.mesh()
		field.draw_mesh(_live, null, Transform2D(0.0, _shake_off))
	# the pebbles rolling along the chain into the one they joined
	for j: Dictionary in _joins:
		if j.t < 0.0:
			continue
		var k: float = j.t / JOIN_T
		var p := _along(j.path, int(j.from), k * k)
		var sc := lerpf(1.0, 0.7, k)
		field.draw_mesh(Art.pebble(j.v, s), null, Transform2D(0.0, Vector2(sc, sc), 0.0, px(p.x, p.y) + _shake_off), Color(1, 1, 1, 1.0 - k * 0.5))
	# the pebbles in the tray
	for id in _vis:
		var vis: Dictionary = _vis[id]
		var cell := Vector2i(roundi(vis.pos.x), roundi(vis.pos.y))
		var sc := _scale(vis)
		var c := px(vis.pos.x, vis.pos.y) + _shake_off
		var lifted: bool = picked.has(cell) and vis.pos == Vector2(cell)
		if lifted:
			var hop := 0.0 if Motion.reduce else sin(minf(1.0, _chain_t / 0.18) * PI) * 0.06
			sc *= 1.1 + hop
			c.y -= _u * 0.04
		elif not _hint.is_empty() and _hint.has(cell) and not Motion.reduce:
			var k := 0.5 + 0.5 * sin(_clock * 5.0 - _hint.find(cell) * 0.6)
			sc *= 1.0 + 0.05 * k
		# while a chain is drawn, the pebbles it cannot take step back
		var a := 1.0
		if not picked.is_empty() and not lifted:
			a = 0.72 if vis.v == chain_v else 0.45
		elif stuck:
			a = 0.55
		field.draw_set_transform(c, 0.0, sc)
		field.draw_mesh(Art.pebble(vis.v, s), null, Transform2D.IDENTITY, Color(1, 1, 1, a))
		Art.number(field, font, Vector2.ZERO, vis.v, s, a)
	field.draw_set_transform(Vector2.ZERO)
	if stuck:
		field.draw_rect(Rect2(Vector2.ZERO, field.size), Color(0.25, 0.16, 0.08, 0.28))
	# what the chain will make, over its last pebble
	if sim.path.size() >= Sim.MIN_CHAIN:
		var last: Vector2i = sim.path[-1]
		var nv: int = sim.value(last) + 1
		var bs := s * 0.46
		var bc := px(last.x, last.y) + Vector2(_u * 0.36, -_u * 0.4) + _shake_off
		var grow := 1.0 if Motion.reduce else Motion.back_out(minf(1.0, _chain_t / 0.2))
		field.draw_set_transform(bc, 0.0, Vector2(grow, grow))
		field.draw_mesh(Art.pebble(nv, bs), null, Transform2D.IDENTITY)
		Art.number(field, font, Vector2.ZERO, nv, bs)
		field.draw_set_transform(Vector2.ZERO)
	# pebbles plucked out or tumbling at the end
	for d: Dictionary in _debris:
		var a := 1.0 - clampf((d.t - 1.0) / 0.6, 0.0, 1.0)
		field.draw_set_transform(d.pos + _shake_off, d.rot, Vector2.ONE)
		field.draw_mesh(Art.pebble(d.v, s), null, Transform2D.IDENTITY, Color(1, 1, 1, a))
		Art.number(field, font, Vector2.ZERO, d.v, s, a)
	field.draw_set_transform(Vector2.ZERO)
	_draw_pops()

## A point `k` of the way along the chain from pebble `from` to its end.
func _along(chain: Array, from: int, k: float) -> Vector2:
	var legs := chain.size() - 1 - from
	if legs <= 0:
		return chain[-1]
	var f := k * legs
	var i := mini(int(floorf(f)), legs - 1)
	return (chain[from + i] as Vector2).lerp(chain[from + i + 1], f - i)

## The chain being drawn: a soft halo under every picked pebble and a
## ribbon through them in their paint, lit down the middle; the hint's
## glow; the swap's first pick.
func _draw_chain(b: Face.Builder, s: float) -> void:
	if not sim.path.is_empty():
		var v: int = sim.value(sim.path[0])
		var col := Art.paint(v)
		var pts := PackedVector2Array()
		for p: Vector2i in sim.path:
			pts.append(px(p.x, p.y) - Vector2(0, _u * 0.04))
		for p in pts:
			b.disc(p, s * 0.6, Color(col.lightened(0.4), 0.35))
			b.stroke(Face.Builder.ring(p, s * 0.58, s * 0.58), maxf(2.0, s * 0.035), Color("fffaf0", 0.9), true)
		if pts.size() >= 2:
			b.stroke(pts, _u * 0.24, Color(col.darkened(0.2), 0.9))
			b.stroke(pts, _u * 0.12, Color(col.lightened(0.45), 0.95))
		# three or more: the ribbon ends in a star over the last pebble
		if pts.size() >= Sim.MIN_CHAIN:
			var tip: Vector2 = pts[-1]
			b.stroke(Face.Builder.ring(tip, s * 0.64, s * 0.64), maxf(3.0, s * 0.05), Color(Pal.SUN, 0.95), true)
	if not _hint.is_empty():
		var a := 0.12 + 0.1 * sin(_clock * 5.0)
		for p: Vector2i in _hint:
			b.disc(px(p.x, p.y), s * 0.62, Color("fffaf0", a))
	if _swap_a.x >= 0:
		var at := px(_swap_a.x, _swap_a.y)
		b.stroke(Face.Builder.ring(at, s * 0.6, s * 0.6), maxf(3.0, s * 0.05), Color(Pal.SUN, 0.95), true)

## How a pebble is scaled this frame: popping in, the gulp when it grows,
## the squash when it lands.
func _scale(vis: Dictionary) -> Vector2:
	if Motion.reduce:
		return Vector2.ONE
	var sc := Vector2.ONE
	if vis.pop >= 0.0 and vis.pop < 0.4:
		sc *= Motion.back_out(clampf(vis.pop / 0.3, 0.0, 1.0))
	if vis.bump >= 0.0:
		var k := clampf(vis.bump / 0.32, 0.0, 1.0)
		var w := sin(k * PI) * (1.0 - k * 0.4)
		sc *= Vector2(1.0 + 0.24 * w - 0.08 * sin(k * TAU), 1.0 + 0.18 * w + 0.08 * sin(k * TAU))
	if vis.squash >= 0.0 and vis.squash < 0.6:
		var t: float = vis.squash
		var q := float(vis.amt) * exp(-t * 11.0) * cos(t * 30.0)
		sc *= Vector2(1.0 + q * 0.75, 1.0 - q)
	return sc

## The clovers in the air, over everything.
func _draw_air() -> void:
	for f: Dictionary in _flights:
		if f.t < 0.0:
			continue
		var k := clampf(f.t / FLIGHT_T, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var p: Vector2 = (f.from as Vector2).lerp(f.ctrl, e).lerp((f.ctrl as Vector2).lerp(f.to, e), e)
		var sc := Motion.back_out(minf(1.0, f.t / 0.18)) * lerpf(1.0, 0.7, e)
		_air.draw_mesh(Art.clover(52.0), null, Transform2D(float(f.spin) * f.t, Vector2(sc, sc), 0.0, p))

func _pop_at(p: Dictionary) -> Vector2:
	var rise := 0.0 if p.t <= 0.0 else 70.0 * (1.0 - exp(-p.t * 4.5))
	var at := px(p.pos.x, p.pos.y) + Vector2(0, -rise)
	at.x = clampf(at.x, 90.0, field.size.x - 90.0)
	at.y = maxf(at.y, 70.0)
	return at

func _draw_pops() -> void:
	var font := get_theme_font("font", "SheetTitle")
	for p: Dictionary in _pops:
		if p.t < 0.0:
			continue
		var a := 1.0 - clampf((p.t - 0.5) / 0.4, 0.0, 1.0)
		var at := _pop_at(p)
		var full := 60 if p.big else 44
		var fs := full if Motion.reduce else maxi(8, int(lerpf(14.0, full * 1.0, Motion.back_out(minf(1.0, p.t / 0.24)))))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := at + Vector2(-w * 0.5, 0)
		field.draw_string_outline(font, o + Vector2(0, 4), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0.2, 0.12, 0.05, 0.35 * a))
		field.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(Art.INK, a))
		field.draw_string(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.col, a))

func _pop(cell: Vector2, text: String, col: Color, big: bool) -> void:
	_pops.append({"pos": cell, "text": text, "t": -JOIN_T, "col": col, "big": big})

func _draw_biggest() -> void:
	if sim == null or sim.max_v <= 0:
		return
	var s := minf(_big_view.size.y, 64.0)
	var c := _big_view.size * 0.5
	var k := 1.0 if Motion.reduce else clampf(_big_t / 0.4, 0.0, 1.0)
	var sc := Motion.back_out(k)
	_big_view.draw_set_transform(c, 0.0, Vector2(sc, sc))
	_big_view.draw_mesh(Art.pebble(sim.max_v, s), null, Transform2D.IDENTITY)
	Art.number(_big_view, Art.font(), Vector2.ZERO, sim.max_v, s)
	_big_view.draw_set_transform(Vector2.ZERO)

# --- the end ---

## The tray is done: every pebble tumbles out, then the card.
func _game_over() -> void:
	_disarm()
	_dragging = false
	_stuck_box.visible = false
	var better := Record.add(GAME, sim.score, sim.max_v)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.max_v,
		"seconds": secs, "moves": sim.moves, "merges": sim.merges, "chain": sim.best_chain,
		"tools": sim.tools_used, "reached": sim.max_v >= Sim.GOAL, "best": better})
	_fx.cue("tumble")
	_show_banner(tr("LT_OVER"), "", 1.0)
	_shake = 0.8
	for id in _vis.keys():
		var vis: Dictionary = _vis[id]
		_fling(int(vis.v), px(vis.pos.x, vis.pos.y))
	_vis.clear()
	# the pebbles are gone from the drawing, not from the sim; keep them from
	# coming back on the next frame's settle
	for c in Sim.COLS:
		for r in Sim.ROWS:
			sim.grid[c][r] = {}
	top_bar.refresh(self)
	get_tree().create_timer(1.5).timeout.connect(_show_end.bind(better))

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
	# the biggest pebble of the game dropping into a hollow between the two
	# below it, bobbing
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(0, 250)
	var biggest: int = sim.max_v
	var shown_at := _clock
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var since := _clock - shown_at
		var mid := Vector2(seat.size.x * 0.5, 230.0)
		var s := 110.0
		var font := Art.font()
		var under := [maxi(1, biggest - 2), maxi(1, biggest - 1)]
		for k in 2:
			var c := mid + Vector2((k - 0.5) * s * 1.05, -s * 0.45)
			seat.draw_mesh(Art.pebble(under[k], s), null, Transform2D(0.0, c))
			Art.number(seat, font, c, under[k], s)
		var fall := clampf((since - 0.25) / 0.3, 0.0, 1.0)
		var land := 1.0 if Motion.reduce else fall * fall
		var bob := sin(t * 2.2) * 5.0
		var sq := Vector2.ONE
		var after := since - 0.55
		if not Motion.reduce and after > 0.0 and after < 0.8:
			var q := 0.22 * exp(-after * 8.0) * cos(after * 26.0)
			sq = Vector2(1.0 + q * 0.75, 1.0 - q)
		var top := mid + Vector2(0, -s * 1.3 - (1.0 - land) * 260.0 + bob + (1.0 - sq.y) * s * 0.55)
		seat.draw_set_transform(top, sin(t * 1.5) * 0.05, sq)
		seat.draw_mesh(Art.pebble(biggest, s * 1.15), null, Transform2D.IDENTITY)
		Art.number(seat, font, Vector2.ZERO, biggest, s * 1.15, 1.0 if since > 0.3 or Motion.reduce else 0.0)
		seat.draw_set_transform(Vector2.ZERO))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else ("LT_END_LUCKY" if biggest >= Sim.GOAL else "LT_END_CARD")
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var score := Label.new()
	score.text = Record.grouped(sim.score)
	score.theme_type_variation = "DayBig"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 14)
	for pair in [[str(sim.max_v), "LT_STAT_BIGGEST"], [str(sim.moves), "LT_STAT_MOVES"], [str(sim.best_chain), "LT_STAT_CHAIN"]]:
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
	var mid := size * 0.5
	for k in 8:
		var at := mid + Vector2.from_angle(TAU * k / 8.0 - PI * 0.5) * Vector2(400.0, 330.0)
		var t := get_tree().create_timer(0.25 + 0.14 * k)
		t.timeout.connect(func() -> void:
			if is_instance_valid(fx):
				fx.puff(at, CONFETTI[k % CONFETTI.size()], 12))

# --- chrome ---

func _on_reset() -> void:
	if sim != null and not sim.is_over():
		Analytics.track("board_reset", {"puzzle_id": GAME})
	_new_game()

func _on_back() -> void:
	if sim != null and not sim.is_over() and sim.moves > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.max_v})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	if _armed >= 0:
		_disarm()
		return
	_on_back()
