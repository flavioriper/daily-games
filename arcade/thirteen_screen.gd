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
## How far a pebble taken into the chain is held up off the sand, in cells.
const LIFT := 0.08
const FLIGHT_T := 0.6
## How long a new number's reveal holds before it flies to the plate, and
## the flight.
const REVEAL_HOLD := 0.75
const REVEAL_FLY := 0.42
const CONFETTI := [Color("f2b632"), Color("ec7f8c"), Color("6fb4e2"), Color("5fae5a"), Color("c98ac6")]
## A long chain's word, by the chain's length, longest first.
const WORDS := [[10, "LT_WORD_5"], [8, "LT_WORD_4"], [6, "LT_WORD_3"], [5, "LT_WORD_2"], [4, "LT_WORD_1"]]
## The lengths a chain being drawn rings out at.
const TIERS := [4, 5, 6, 8, 10]
const STICKER_COLS := [Color("ff6f61"), Color("ffb03b"), Color("ffd84d"), Color("7fd66a"), Color("5cb8ff"), Color("b77be6")]
## The most bits alive in one layer at once.
const MAX_BITS := 420

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
## The last pebble taken into the chain, the one that hops.
var _newest := Vector2i(-1, -1)
## The finger over the field while a chain is drawn, for the tether.
var _finger := Vector2.INF
## The live layer over the pebbles (glints), kept until the next replaces it.
var _live_over: ArrayMesh
## Glints running over a pebble: {id, t}; seconds to the next.
var _glints: Array = []
var _glint_wait := 1.5
## A new biggest number from 7 up, shown big over the tray and flown up to
## the plate: {v, t, prev, hold, from}.
var _reveal := {}
## Seconds to the tools' next nudge while the tray is stuck.
var _stuck_pulse := 0.0
var _sub_pill: Control
var _stuck_said := true
## Bits flung about, in the field's pixels and in the air's: chips, sparks,
## stars, coins, clovers, confetti and rings.
## {pos, vel, rot, spin, t, life, kind, col, size, float?}
var _bits: Array = []
var _air_bits: Array = []
## Words lettered a hopping letter at a time: {text, at, t, life, size,
## rainbow, col, rays, tilt, id}.
var _stickers: Array = []
## The tray's flash after a big merge, fading, and its colour.
var _flash := 0.0
var _flash_col := Color.WHITE
## Chains of four or more in a row, and the warm glow round the tray it
## lights (0..1).
var _streak := 0
var _heat := 0.0
## Seconds of coins and clovers still raining down over the screen.
var _rain := 0.0
## The longest tier the chain being drawn has rung out at.
var _tier := 0
var _air_live: ArrayMesh
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
	# the line under it on a paper pill, so it reads over any pebbles
	_sub_pill = PanelContainer.new()
	_sub_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := CozyTheme.lifted(Color("fffaf0", 0.96), 34, 18)
	pill.content_margin_left = 30
	pill.content_margin_right = 30
	_sub_pill.add_theme_stylebox_override("panel", pill)
	over.add_child(_sub_pill)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetBody"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_color_override("font_color", Art.INK)
	_sub_pill.add_child(_sub)
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
	var card := PanelContainer.new()
	card.name = "Stuck"
	card.visible = false
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fffaf0"), 40, 30))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var head := Label.new()
	head.text = "LT_STUCK"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var line := Label.new()
	line.text = "LT_STUCK_LINE"
	line.theme_type_variation = "SheetBody"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	return card

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
	_stuck_box.size = Vector2(s.x - 120, 0)
	_stuck_box.position = Vector2(60, s.y * 0.5 - _stuck_box.get_combined_minimum_size().y * 0.5)
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
	_glints.clear()
	_reveal = {}
	_finger = Vector2.INF
	_newest = Vector2i(-1, -1)
	_stuck_box.visible = false
	_stuck_said = true
	_bits.clear()
	_air_bits.clear()
	_stickers.clear()
	_flash = 0.0
	_streak = 0
	_heat = 0.0
	_rain = 0.0
	_tier = 0
	_end_score = null
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
	_air.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()

func _new_vis(pos: Vector2, v: int) -> Dictionary:
	return {"pos": pos, "v": v, "vel": 0.0, "hold": 0.0, "squash": -1.0, "amt": 0.0, "bump": -1.0, "pop": -1.0, "pending": 0, "pend_t": 0.0,
		"nudge": Vector2.ZERO, "nudge_t": -1.0, "wig": -1.0}

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
			if vis.nudge_t >= 0.0:
				vis.nudge_t += delta
				if vis.nudge_t > 0.6:
					vis.nudge_t = -1.0
			if vis.wig >= 0.0:
				vis.wig += delta
				if vis.wig > 0.8:
					vis.wig = -1.0
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
	_twinkle(delta)
	_advance_reveal(delta)
	_animate_rewards(delta)
	if sim.phase == Sim.Phase.STUCK and not _stuck_said and _reveal.is_empty() and not busy() \
			and (_banner.get_meta("box") as Control).modulate.a < 0.05:
		_stuck_said = true
		_fx.cue("stuck")
		_stuck_pulse = 0.6
		_stuck_box.visible = true
		_stuck_box.size = Vector2(field.size.x - 120, 0)
		_stuck_box.position = Vector2(60, field.size.y * 0.5 - _stuck_box.get_combined_minimum_size().y * 0.5)
		if not Motion.reduce:
			_stuck_box.pivot_offset = _stuck_box.get_combined_minimum_size() * Vector2(0, 0.5) + Vector2(_stuck_box.size.x * 0.5, 0)
			_stuck_box.scale = Vector2(0.7, 0.7)
			_stuck_box.create_tween().tween_property(_stuck_box, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# stuck: the tools the bank can buy nudge now and then, the way out
	if _stuck_box.visible and not Motion.reduce:
		_stuck_pulse -= delta
		if _stuck_pulse <= 0.0:
			_stuck_pulse = 1.6
			for tool: int in _tool_buttons:
				if _afford.get(tool, false):
					_kick(_tool_buttons[tool], 0.1, 0.3)

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

## Now and then a pebble at rest glints and another gives a little wiggle;
## a thirteen or past it glints more often.
func _twinkle(delta: float) -> void:
	for g: Dictionary in _glints:
		g.t += delta
	_glints = _glints.filter(func(g: Dictionary) -> bool: return g.t < 0.7 and _vis.has(g.id))
	if Motion.reduce or _vis.is_empty() or sim.phase != Sim.Phase.PLAY:
		return
	_glint_wait -= delta
	if _glint_wait > 0.0:
		return
	_glint_wait = randf_range(0.9, 2.2)
	var ids := _vis.keys()
	var pick: int = ids[randi() % ids.size()]
	for id: int in ids:
		if int(_vis[id].v) >= Sim.GOAL and randf() < 0.5:
			pick = id
	_glints.append({"id": pick, "t": 0.0})
	if not _dragging and not busy() and randf() < 0.45:
		var other: Dictionary = _vis[ids[randi() % ids.size()]]
		if other.wig < 0.0:
			other.wig = 0.0

func _advance_reveal(delta: float) -> void:
	if _reveal.is_empty():
		return
	_reveal.t += delta
	# the moment it arrives, big, in the middle: stars and rings burst out of
	# it; a thirteen flashes the tray gold and sets coins raining
	if _reveal.t >= 0.3 and not _reveal.get("burst", false):
		_reveal.burst = true
		var v: int = _reveal.v
		var mid := _in_air(field, Vector2(field.size.x * 0.5, field.size.y * 0.4))
		var gold := v >= Sim.GOAL
		_spray(_air_bits, mid, Art.GOLD, 22 if gold else 12, 900.0 if gold else 700.0, "star", 1.4)
		_spray(_air_bits, mid, Color("fffaf0"), 14, 700.0, "spark", 1.3)
		_spray(_air_bits, mid, Art.paint(v), 16, 800.0, "chip", 1.4)
		_ring(_air_bits, mid, _u * 2.4, Color(Art.paint(v).lightened(0.4), 0.9))
		_ring(_air_bits, mid, _u * 3.4, Color(Art.GOLD, 0.7), 0.12)
		if gold:
			_ring(_air_bits, mid, _u * 4.4, Color("fffaf0", 0.8), 0.24)
			_spray(_air_bits, mid, Art.GOLD, 16, 900.0, "coin", 1.3)
			_spray(_air_bits, mid, Art.CLOVER, 10, 800.0, "clover", 1.2)
			_flash_now(Art.GOLD, 0.8)
			_rain = maxf(_rain, 3.2 if v == Sim.GOAL else 1.8)
			_sticker(tr("LT_LUCKY") if v == Sim.GOAL else tr("LT_BEYOND"), _in_air(field, Vector2(field.size.x * 0.5, field.size.y * 0.12)), 92, 2.6, true, Color.WHITE, true, "word")
		else:
			_flash_now(Art.paint(v).lightened(0.5), 0.35)
			_sticker(tr("LT_NEW"), _in_air(field, Vector2(field.size.x * 0.5, field.size.y * 0.13)), 70, 1.5, true, Color.WHITE, false, "word")
	if _reveal.t >= float(_reveal.hold) + REVEAL_FLY:
		var landed: int = _reveal.v
		_reveal = {}
		_big_t = 0.0
		_kick(_big_view, 0.3, 0.35)
		var plate := _in_air(_big_view, _big_view.size * 0.5)
		_air_fx.sparkle(plate, Color("fffaf0"))
		_spray(_air_bits, plate, Art.GOLD, 10, 520.0, "star", 0.9)
		_spray(_air_bits, plate, Art.paint(landed), 8, 420.0, "chip", 0.8)
		_ring(_air_bits, plate, 110.0, Color(Art.GOLD, 0.9))
		_fx.cue("land", 1.3, -2.0)
		_air.queue_redraw()

## The rewards' own clocks: the bits in both layers, the stickers, the
## flash, the streak's glow and the rain.
func _animate_rewards(delta: float) -> void:
	_step_bits(_bits, delta)
	_step_bits(_air_bits, delta)
	for st: Dictionary in _stickers:
		st.t += delta
	_stickers = _stickers.filter(func(st: Dictionary) -> bool: return st.t < st.life)
	_flash = maxf(0.0, _flash - delta * 2.4)
	var want := clampf((_streak - 1) / 4.0, 0.0, 1.0)
	_heat = move_toward(_heat, want, delta * (1.5 if want > _heat else 0.5))
	if _rain > 0.0:
		_rain -= delta
		if not Motion.reduce and randf() < delta * 30.0:
			var w := _air.size.x
			var r := randf()
			var kind := "coin" if r < 0.45 else ("clover" if r < 0.7 else "confetti")
			_air_bits.append({"pos": Vector2(randf_range(0.0, w), -40.0), "vel": Vector2(randf_range(-60.0, 60.0), randf_range(160.0, 300.0)),
				"rot": randf() * TAU, "spin": randf_range(-4.0, 4.0), "t": 0.0, "life": 3.6, "kind": kind,
				"col": CONFETTI[randi() % CONFETTI.size()], "size": randf_range(1.0, 1.5), "float": true})

## Bits move: thrown, pulled down, slowed by the air; rain drifts down
## swaying.
func _step_bits(bits: Array, delta: float) -> void:
	if bits.is_empty():
		return
	var drag := exp(-delta * 2.2)
	for b: Dictionary in bits:
		b.t += delta
		if b.t < 0.0 or String(b.kind) == "ring":
			continue
		var v: Vector2 = b.vel
		if b.get("float", false):
			v.y = minf(v.y + 120.0 * delta, 300.0)
			b.pos += Vector2(v.x + sin(b.t * 3.0 + b.rot) * 70.0, v.y) * delta
		else:
			v *= drag
			v.y += (800.0 if String(b.kind) == "confetti" or String(b.kind) == "clover" else 1700.0) * delta
			b.pos += v * delta
		b.vel = v
		b.rot += float(b.spin) * delta
	var keep := bits.filter(func(b: Dictionary) -> bool: return b.t < b.life)
	bits.clear()
	bits.append_array(keep)

## Throws `n` bits of `kind` out of `at`, into `bits` (the field's or the
## air's), at up to `speed` pixels a second.
func _spray(bits: Array, at: Vector2, col: Color, n: int, speed: float, kind := "spark", size := 1.0, delay := 0.0) -> void:
	if Motion.reduce:
		return
	n = mini(n, MAX_BITS - bits.size())
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.35, 1.0) + Vector2(0, -speed * 0.4)
		bits.append({"pos": at, "vel": v, "rot": randf() * TAU, "spin": randf_range(-10.0, 10.0), "t": -delay,
			"life": randf_range(0.55, 0.95) + (0.5 if kind == "confetti" or kind == "clover" or kind == "coin" else 0.0), "kind": kind,
			"col": col, "size": size * randf_range(0.7, 1.25)})

## A ring swelling out of `at` to `radius` and fading.
func _ring(bits: Array, at: Vector2, radius: float, col: Color, delay := 0.0) -> void:
	if Motion.reduce:
		return
	bits.append({"pos": at, "vel": Vector2.ZERO, "rot": 0.0, "spin": 0.0, "t": -delay, "life": 0.45, "kind": "ring",
		"col": col, "size": radius})

## The tray flashes `col`, `amount` at most.
func _flash_now(col: Color, amount: float) -> void:
	if Motion.reduce:
		return
	_flash = maxf(_flash, amount)
	_flash_col = col

## A word lettered at `at` in the air's pixels, each letter hopping in on
## its own, fitted to the tray's width. `rainbow` letters it in the sticker
## colours, else in `col`; `rays` sets a sunburst turning behind it. A
## sticker with an `id` replaces the one before it with the same id.
func _sticker(text: String, at: Vector2, size: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "") -> void:
	if id != "":
		_stickers = _stickers.filter(func(st: Dictionary) -> bool: return String(st.id) != id)
	var room := field.size.x - 40.0
	var w := Art.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if w > room:
		size = int(size * room / w)
	var edge := _in_air(field, Vector2.ZERO).x
	at.x = clampf(at.x, edge + minf(w, room) * 0.5 + 20.0, edge + field.size.x - minf(w, room) * 0.5 - 20.0)
	_stickers.append({"text": text, "at": at, "t": 0.0, "life": life, "size": size, "rainbow": rainbow, "col": col,
		"rays": rays and not Motion.reduce, "tilt": 0.0 if Motion.reduce else randf_range(-0.08, 0.08), "id": id})

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
			var bank := _in_air(_clover_icon, _clover_icon.size * 0.5)
			_spray(_air_bits, bank, Art.CLOVER, 3, 300.0, "clover", 0.6)
			_spray(_air_bits, bank, Color("fffaf0"), 3, 260.0, "spark", 0.7)
			if f.get("first", false):
				_ring(_air_bits, bank, 80.0, Color(Art.CLOVER.lightened(0.3), 0.9))
				_sticker("+%d" % int(f.total), bank + Vector2(0, -70.0), 46, 0.8, false, Art.CLOVER, false, "clover")
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
			_finger = at
			_play_events()
		return
	if not _dragging:
		return
	if released:
		_dragging = false
		_finger = Vector2.INF
		# every pebble of the chain drops back into its hollow
		for p: Vector2i in sim.path:
			var held: Dictionary = sim.at(p)
			if not held.is_empty() and _vis.has(held.id):
				_squash(_vis[held.id], 0.07)
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
	_finger = at
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
				_newest = ev.cell
				_fx.cue("select", minf(0.9 + 0.07 * (int(ev.n) - 1), 1.9))
				if int(ev.n) == 1:
					_tier = 0
				_ring_tier(ev.cell, int(ev.n))
			"unselect":
				# a tier given back rings again when the chain regrows past it
				_tier = 0
				for t: int in TIERS:
					if sim.path.size() >= t:
						_tier = t
				_chain_t = 0.0
				_newest = sim.path[-1] if not sim.path.is_empty() else Vector2i(-1, -1)
				var gone: Dictionary = sim.at(ev.cell)
				if not gone.is_empty() and _vis.has(gone.id):
					_squash(_vis[gone.id], 0.1)
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
				# the reveal carries the thirteen; the fanfare and the
				# confetti land with it
				if Motion.reduce:
					_show_banner("13!", tr("LT_GOAL_LINE"), 1.6)
				var wait := 0.0 if Motion.reduce else JOIN_T
				get_tree().create_timer(wait).timeout.connect(func() -> void:
					if not is_instance_valid(_fx):
						return
					_fx.cue("goal")
					_confetti()
					_shake = maxf(_shake, 0.5))
			"stuck":
				# said once the tray has settled and any reveal has landed
				_stuck_said = false
			"tool":
				_on_tool_event(ev)
			"refused":
				_fx.cue("refused")
				var t: int = Sim.TOOL_KEYS.find_key(String(ev.tool))
				Motion.shiver(_tool_buttons[t])
			"over":
				_game_over()
	sim.events.clear()
	if sim.phase != Sim.Phase.STUCK:
		_stuck_box.visible = false
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
	_pop(Vector2(into) + Vector2(0, -0.3), "+%s" % Record.grouped(int(ev.points)), Art.paint(int(ev.v)).lightened(0.4) if n < 6 else Pal.SUN, big or n >= 5)
	var delay := 0.0 if Motion.reduce else JOIN_T
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(_fx):
			return
		_fx.puff(at, Art.paint(int(ev.v)), 6)
		_fx.ring(at, 0.75 * _u, Art.paint(int(ev.v)).lightened(0.25))
		_fx.cue("merge", clampf(0.85 + 0.05 * int(ev.v), 0.85, 1.6))
		_knock(into, 0.05 + 0.012 * n)
		_merge_burst(ev, at)
		if bool(ev.get("new_max", false)):
			_fx.sparkle(at, Color("fffaf0"))
			if int(ev.v) != Sim.GOAL:
				_fx.cue("new_number")
			if int(ev.v) >= 7 and not Motion.reduce:
				_reveal = {"v": int(ev.v), "t": 0.0, "prev": int(ev.v) - 1,
					"hold": REVEAL_HOLD * (1.8 if int(ev.v) >= Sim.GOAL else 1.0),
					"from": _in_air(field, at)}
			else:
				_big_t = 0.0
				_kick(_big_view, 0.3, 0.35)
				if int(ev.v) >= 7:
					_show_banner("%d!" % int(ev.v), "", 0.6)
		if big:
			_fx.ring(at, 1.2 * _u, Art.GOLD))
	_launch_clovers(ev)
	_streak = _streak + 1 if n >= 4 else 0
	if n >= 6:
		_kick(_score_k, 0.3, 0.35)
		_shake = maxf(_shake, 0.1 + 0.02 * n)

## The pebbles round a merge are knocked outward by it and rock back.
func _knock(at: Vector2i, amt: float) -> void:
	if Motion.reduce:
		return
	for id in _vis:
		var vis: Dictionary = _vis[id]
		var d: Vector2 = vis.pos - Vector2(at)
		var far := d.length()
		if far < 0.1 or far > 2.3:
			continue
		vis.nudge = d / far * amt * (1.6 - far * 0.5)
		vis.nudge_t = 0.0

## A chain being drawn that reaches four, five, six, eight or ten rings
## out from its newest pebble and throws a few sparks, brighter each tier.
func _ring_tier(cell: Vector2i, n: int) -> void:
	if not TIERS.has(n) or n <= _tier:
		return
	_tier = n
	var at := px(cell.x, cell.y) - Vector2(0, _u * LIFT)
	var i := TIERS.find(n)
	var col: Color = STICKER_COLS[i % STICKER_COLS.size()]
	_ring(_bits, at, _u * (0.8 + 0.15 * i), Color(col, 0.9))
	_spray(_bits, at, Color("fffaf0"), 4 + 2 * i, 380.0 + 60.0 * i, "spark", _u / 110.0)
	if n >= 6:
		_spray(_bits, at, Art.GOLD, 2 + i, 420.0, "star", _u / 150.0)

## What a merge throws, as the chain lands in its last pebble: chips of the
## old number's paint, sparks, stars for a long one; a word for four or
## more, lettered bigger the longer the chain, and the streak under it; a
## flash for six or more.
func _merge_burst(ev: Dictionary, at: Vector2) -> void:
	var n: int = ev.n
	var v: int = ev.v
	var k := _u / 110.0
	_spray(_bits, at, Art.paint(v - 1), mini(4 + n * 2, 26), 360.0 + 45.0 * n, "chip", k)
	_spray(_bits, at, Color("fffaf0"), 3 + n, 320.0 + 30.0 * n, "spark", k)
	if n >= 5:
		_spray(_bits, at, Art.GOLD, n, 520.0 + 30.0 * n, "star", k * 0.8)
		_ring(_bits, at, _u * (1.2 + 0.12 * n), Color(Art.paint(v).lightened(0.3), 0.8), 0.06)
	if n >= 6:
		_flash_now(Color("fffaf0"), minf(0.65, 0.3 + 0.05 * (n - 6)))
		_spray(_air_bits, _in_air(_score_l, _score_l.size * 0.5), Pal.SUN, 8, 380.0, "star", 0.9, 0.25)
	# the word, over the merge (or up top, out of a reveal's way)
	var word := ""
	var tier := 0
	for i in WORDS.size():
		if n >= int(WORDS[i][0]):
			word = tr(WORDS[i][1])
			tier = WORDS.size() - 1 - i
			break
	var reveal: bool = bool(ev.get("new_max", false)) and v >= 7 and not Motion.reduce
	var spot := Vector2(field.size.x * 0.5, field.size.y * 0.12) if reveal else px(ev.cell.x, ev.cell.y) - Vector2(0, _u * 0.95)
	spot.y = clampf(spot.y, 70.0, field.size.y - 90.0)
	if word != "" and not reveal:
		_sticker(word, _in_air(field, spot), 64 + 10 * tier, 1.0 + 0.15 * tier, true, Color.WHITE, tier >= 2, "word")
	if _streak >= 2:
		_sticker(tr("LT_STREAK") % _streak, _in_air(field, spot + Vector2(0, 70.0 + 8.0 * tier)), 44, 1.2, false, Color("ff8a3d"), false, "streak")
		_spray(_bits, at, Color("ffb03b"), mini(2 * _streak, 12), 440.0, "spark", k)

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
			_spray(_bits, px(cell.x, cell.y), Art.paint(int(ev.v)), 10, 500.0, "chip", _u / 110.0)
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
			_spray(_bits, px(cell.x, cell.y), Art.GOLD, 8, 460.0, "star", _u / 150.0)

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
		_flights.append({"from": from, "ctrl": ctrl, "to": to, "t": -JOIN_T - 0.07 * k, "value": value, "spin": randf_range(-6.0, 6.0),
			"first": k == 0, "total": got})
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
	_sub_pill.visible = sub != ""
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
	# a few shells and grit washed into the sand between the hollows
	for k in 7:
		var c := rng.randi_range(0, Sim.COLS - 2)
		var r := rng.randi_range(0, Sim.ROWS - 2)
		var p := px(c + 0.5, r + 0.5) + Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08)) * _u
		if k % 2 == 0:
			_shell(b, p, _u * rng.randf_range(0.11, 0.15), rng.randf_range(-0.8, 0.8))
		else:
			for q in 3:
				var g := p + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * _u * 0.06
				b.disc(g, _u * rng.randf_range(0.012, 0.022), Color(Art.SAND_DEEP.darkened(0.2), 0.7))
	return b.mesh()

## A little scallop shell lying in the sand, ribbed, its hinge down.
func _shell(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	var fan := PackedVector2Array()
	fan.append(at + Vector2(0, r * 0.55).rotated(turn))
	for i in 11:
		var a := lerpf(PI * 1.12, PI * 1.88, i / 10.0)
		var bump := 1.0 + 0.06 * (1 if i % 2 == 0 else -1)
		fan.append(at + Vector2.from_angle(a).rotated(turn) * r * bump)
	b.polygon(fan, Color("f6d9c4"))
	for i in 5:
		var a := lerpf(PI * 1.22, PI * 1.78, i / 4.0)
		b.stroke(PackedVector2Array([fan[0], at + Vector2.from_angle(a).rotated(turn) * r * 0.92]), maxf(1.0, r * 0.07), Color("d9a88c", 0.8))
	b.ellipse(fan[0], r * 0.22, r * 0.12, Color("e8bea4"))

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
	var stuck: bool = _stuck_box.visible
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
		var ja := 1.0 - k * 0.5
		field.draw_set_transform(px(p.x, p.y) + _shake_off + Vector2(0, -_u * 0.1 * (1.0 - k)), 0.0, Vector2(sc, sc))
		field.draw_mesh(Art.pebble(j.v, s), null, Transform2D.IDENTITY, Color(1, 1, 1, ja))
		Art.number(field, font, Vector2.ZERO, j.v, s, ja)
	field.draw_set_transform(Vector2.ZERO)
	# the pebbles in the tray
	for id in _vis:
		var vis: Dictionary = _vis[id]
		var cell := Vector2i(roundi(vis.pos.x), roundi(vis.pos.y))
		var sc := _scale(vis)
		var c := px(vis.pos.x, vis.pos.y) + _shake_off + _nudge(vis) * _u
		var rot := 0.0
		if vis.wig >= 0.0 and not Motion.reduce:
			rot = 0.14 * exp(-float(vis.wig) * 5.0) * sin(float(vis.wig) * 22.0)
		var lifted: bool = picked.has(cell) and vis.pos == Vector2(cell)
		if lifted:
			# the chain is held up off the sand; the newest hops, the rest bob
			# in a wave down the chain
			var lift := LIFT
			if not Motion.reduce:
				if cell == _newest:
					lift += sin(minf(1.0, _chain_t / 0.2) * PI) * 0.1
				else:
					lift += 0.02 * sin(_clock * 6.0 - sim.path.find(cell) * 0.8)
			sc *= 1.08
			c.y -= _u * lift
		elif not _hint.is_empty() and _hint.has(cell) and not Motion.reduce:
			var k := 0.5 + 0.5 * sin(_clock * 5.0 - _hint.find(cell) * 0.6)
			sc *= 1.0 + 0.05 * k
		# while a chain is drawn, the pebbles it cannot take step back
		var a := 1.0
		if not picked.is_empty() and not lifted:
			a = 0.72 if vis.v == chain_v else 0.45
		elif stuck:
			a = 0.55
		field.draw_set_transform(c, rot, sc)
		field.draw_mesh(Art.pebble(vis.v, s), null, Transform2D.IDENTITY, Color(1, 1, 1, a))
		Art.number(field, font, Vector2.ZERO, vis.v, s, a)
	field.draw_set_transform(Vector2.ZERO)
	# glints running over pebbles at rest, and the tether to the finger
	var over := Face.Builder.new()
	_draw_over(over, s)
	if not over.verts.is_empty():
		_live_over = over.mesh()
		field.draw_mesh(_live_over, null, Transform2D(0.0, _shake_off))
	if _flash > 0.0:
		field.draw_rect(Rect2(Vector2.ZERO, field.size), Color(_flash_col, _flash * 0.5))
	if stuck:
		field.draw_rect(Rect2(Vector2.ZERO, field.size), Color(0.25, 0.16, 0.08, 0.28))
	# what the chain will make, over its last pebble
	if sim.path.size() >= Sim.MIN_CHAIN:
		var last: Vector2i = sim.path[-1]
		var nv: int = sim.value(last) + 1
		var bs := s * 0.46
		var bc := px(last.x, last.y) + Vector2(_u * 0.38, -_u * (0.42 + LIFT)) + _shake_off
		var grow := 1.0 if Motion.reduce else Motion.back_out(minf(1.0, _chain_t / 0.2))
		var tilt := 0.0 if Motion.reduce else 0.08 * sin(_clock * 4.0)
		if not Motion.reduce:
			bc.y += sin(_clock * 3.0) * _u * 0.02
			grow *= 1.0 + 0.04 * minf(8.0, sim.path.size() - Sim.MIN_CHAIN)
		field.draw_set_transform(bc, tilt, Vector2(grow, grow))
		field.draw_mesh(Art.pebble(nv, bs), null, Transform2D.IDENTITY)
		Art.number(field, font, Vector2.ZERO, nv, bs)
		# four or more: how long the chain is, in the colour of its tier
		if sim.path.size() >= 4:
			var n: int = sim.path.size()
			var label := "x%d" % n
			var fs := int(bs * 0.5)
			var tf := get_theme_font("font", "SheetTitle")
			var w := tf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var ti := 0
			for t: int in TIERS:
				if n >= t:
					ti = TIERS.find(t)
			var tc: Color = STICKER_COLS[ti % STICKER_COLS.size()]
			var o := Vector2(-w * 0.5, bs * 0.5 + fs * 0.95)
			field.draw_string_outline(tf, o, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color("fffaf0"))
			field.draw_string_outline(tf, o, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, tc.darkened(0.5))
			field.draw_string(tf, o, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
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
	# the trails the merged pebbles leave as they roll into the last
	for jn: Dictionary in _joins:
		if jn.t <= 0.0:
			continue
		var k: float = jn.t / JOIN_T
		var tail := PackedVector2Array()
		for q in 6:
			var e := maxf(0.0, k - q * 0.07)
			var at := _along(jn.path, int(jn.from), e * e)
			tail.append(px(at.x, at.y))
		b.stroke(tail, s * 0.34, Color(Art.paint(int(jn.v)).lightened(0.3), 0.35 * (1.0 - k)))
	if not sim.path.is_empty():
		var v: int = sim.value(sim.path[0])
		var col := Art.paint(v)
		var long: bool = sim.path.size() >= 5
		var pts := PackedVector2Array()
		for p: Vector2i in sim.path:
			pts.append(px(p.x, p.y) - Vector2(0, _u * LIFT))
		# the sand under each lifted pebble keeps its shadow and a glow
		for p: Vector2i in sim.path:
			var ground := px(p.x, p.y)
			b.disc(ground, s * 0.62, Color(col.lightened(0.45), 0.4))
			b.ellipse(ground + Vector2(0, s * 0.12), s * 0.42, s * 0.3, Color(0.3, 0.2, 0.08, 0.2))
		for p in pts:
			b.stroke(Face.Builder.ring(p, s * 0.58, s * 0.58), maxf(2.0, s * 0.035), Color("fffaf0", 0.9), true)
		if pts.size() >= 2:
			b.stroke(pts, _u * 0.26, Color(col.darkened(0.25), 0.92))
			b.stroke(pts, _u * 0.14, Color(col.lightened(0.45), 0.97))
			# beads of light flowing down the ribbon toward its end
			if not Motion.reduce:
				var total := 0.0
				for q in range(1, pts.size()):
					total += pts[q - 1].distance_to(pts[q])
				var gap := _u * 0.34
				var off := fmod(_clock * _u * 1.6, gap)
				var d := off
				while d < total:
					var at := _point_on(pts, d)
					b.disc(at, _u * (0.035 if not long else 0.045), Color(Pal.SUN.lightened(0.3) if long else Color("fffaf0"), 0.95))
					d += gap
		# three or more: the ribbon ends in a sun ring over the last pebble,
		# breathing
		if pts.size() >= Sim.MIN_CHAIN:
			var tip: Vector2 = pts[-1]
			var br := 1.0 if Motion.reduce else 1.0 + 0.04 * sin(_clock * 7.0)
			b.stroke(Face.Builder.ring(tip, s * 0.64 * br, s * 0.64 * br), maxf(3.0, s * 0.05), Color(Pal.SUN, 0.95), true)
	if not _hint.is_empty():
		var a := 0.12 + 0.1 * sin(_clock * 5.0)
		for p: Vector2i in _hint:
			b.disc(px(p.x, p.y), s * 0.62, Color("fffaf0", a))
	# an armed tool lights the pebbles it may be used on
	if _armed >= 0 and not busy():
		var pulse := 0.5 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 5.0)
		for c in Sim.COLS:
			for r in Sim.ROWS:
				var cell := Vector2i(c, r)
				if cell == _swap_a or sim.at(cell).is_empty():
					continue
				var ok: bool = sim.can_target(_armed, _swap_a, cell) if _armed == Sim.Tool.SWAP and _swap_a.x >= 0 else sim.can_target(_armed, cell)
				if ok:
					b.stroke(Face.Builder.ring(px(c, r), s * 0.57, s * 0.57), maxf(2.0, s * 0.03), Color(Pal.SUN, 0.35 + 0.35 * pulse), true)
	if _swap_a.x >= 0:
		var at := px(_swap_a.x, _swap_a.y)
		b.disc(at, s * 0.62, Color(Pal.SUN, 0.25))
		b.stroke(Face.Builder.ring(at, s * 0.6, s * 0.6), maxf(3.0, s * 0.05), Color(Pal.SUN, 0.95), true)

## A point `d` pixels along a polyline.
func _point_on(pts: PackedVector2Array, d: float) -> Vector2:
	for q in range(1, pts.size()):
		var leg := pts[q - 1].distance_to(pts[q])
		if d <= leg:
			return pts[q - 1].lerp(pts[q], d / maxf(leg, 0.001))
		d -= leg
	return pts[-1]

## Over the pebbles: the tether from the chain's last pebble to the finger,
## and the glints.
func _draw_over(b: Face.Builder, s: float) -> void:
	if _dragging and _finger != Vector2.INF and not sim.path.is_empty():
		var last: Vector2i = sim.path[-1]
		var from := px(last.x, last.y) - Vector2(0, _u * LIFT)
		var far := from.distance_to(_finger)
		if far > s * 0.5:
			var col := Art.paint(sim.value(sim.path[0]))
			var dir := (_finger - from) / far
			var start := from + dir * s * 0.5
			var n := int(far / (_u * 0.16))
			for q in n:
				var at := start.lerp(_finger, float(q) / maxf(1.0, n))
				b.disc(at, _u * 0.03, Color(col.darkened(0.2), 0.6))
			b.disc(_finger, _u * 0.12, Color(col.lightened(0.4), 0.45))
			b.disc(_finger, _u * 0.07, Color(col.darkened(0.1), 0.8))
	for g: Dictionary in _glints:
		if not _vis.has(g.id):
			continue
		var vis: Dictionary = _vis[g.id]
		var k: float = g.t / 0.7
		var at := px(vis.pos.x, vis.pos.y) + Vector2(-s * 0.2, -s * 0.24) + _nudge(vis) * _u
		Art.glint(b, at, s * 0.17 * sin(k * PI), k * 1.2)
	if _heat > 0.01:
		_draw_heat(b)
	_draw_bits(b, _bits)

## How far a merge has knocked a pebble off its seat, in cells.
func _nudge(vis: Dictionary) -> Vector2:
	if vis.nudge_t < 0.0:
		return Vector2.ZERO
	var t: float = vis.nudge_t
	return (vis.nudge as Vector2) * sin(minf(t / 0.06, 1.0) * PI * 0.5) * exp(-t * 7.0) * cos(maxf(0.0, t - 0.06) * 18.0)

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
	if float(vis.vel) > 0.0:
		var st := minf(0.14, float(vis.vel) * 0.006)
		sc *= Vector2(1.0 - st * 0.6, 1.0 + st)
	if vis.squash >= 0.0 and vis.squash < 0.6:
		var t: float = vis.squash
		var q := float(vis.amt) * exp(-t * 11.0) * cos(t * 30.0)
		sc *= Vector2(1.0 + q * 0.75, 1.0 - q)
	return sc

## The clovers in the air, over everything.
func _draw_air() -> void:
	var b := Face.Builder.new()
	var font := Art.font()
	for st: Dictionary in _stickers:
		if not st.rays:
			continue
		var grow := Motion.back_out(clampf(st.t / 0.35, 0.0, 1.0))
		var a := 1.0 - clampf((st.t - (st.life - 0.35)) / 0.35, 0.0, 1.0)
		var w := font.get_string_size(st.text, HORIZONTAL_ALIGNMENT_LEFT, -1, st.size).x
		var r := maxf(w * 0.62, float(st.size) * 1.5) * grow
		b.disc(st.at, r * 0.6, Color(Color("fff4c2"), 0.35 * a))
		Art.sunrays(b, st.at, r * 0.2, r, 16, _clock * 0.8, Color(Color("ffe39a"), 0.34 * a))
		Art.sunrays(b, st.at, r * 0.2, r * 0.8, 16, -_clock * 0.5 + 0.1, Color(Color("fffaf0"), 0.24 * a))
	# the clovers' trails: a fading green comet behind each
	for f: Dictionary in _flights:
		if f.t < 0.0:
			continue
		for j in range(6, 0, -1):
			var back: float = f.t - j * 0.03
			if back < 0.0:
				continue
			var kk := clampf(back / FLIGHT_T, 0.0, 1.0)
			var ee := kk * kk * (3.0 - 2.0 * kk)
			var tp: Vector2 = (f.from as Vector2).lerp(f.ctrl, ee).lerp((f.ctrl as Vector2).lerp(f.to, ee), ee)
			b.disc(tp, (7.0 - j) * 2.6, Color(Art.CLOVER.lightened(0.35), 0.1 * (7 - j)))
	_draw_bits(b, _air_bits)
	if not b.verts.is_empty():
		_air_live = b.mesh()
		_air.draw_mesh(_air_live, null)
	for f: Dictionary in _flights:
		if f.t < 0.0:
			continue
		var k := clampf(f.t / FLIGHT_T, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var p: Vector2 = (f.from as Vector2).lerp(f.ctrl, e).lerp((f.ctrl as Vector2).lerp(f.to, e), e)
		var sc := Motion.back_out(minf(1.0, f.t / 0.18)) * lerpf(1.0, 0.7, e)
		_air.draw_mesh(Art.clover(52.0), null, Transform2D(float(f.spin) * f.t, Vector2(sc, sc), 0.0, p))
	_draw_reveal()
	_draw_stickers(font)

## The warm glow a streak of long chains lights round the tray's edge,
## beating.
func _draw_heat(b: Face.Builder) -> void:
	var s := field.size
	var beat := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 9.0)
	var tint := Color("ffb03b").lerp(Color("ff6f61"), _heat)
	var edge := Color(tint, (0.25 + 0.2 * beat) * _heat)
	var none := Color(tint, 0.0)
	var w := (70.0 + 40.0 * beat) * (0.6 + 0.4 * _heat)
	_quad(b, [Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x - w, w), Vector2(w, w)], [edge, edge, none, none])
	_quad(b, [Vector2(0, s.y), Vector2(w, s.y - w), Vector2(s.x - w, s.y - w), s], [edge, none, none, edge])
	_quad(b, [Vector2.ZERO, Vector2(w, w), Vector2(w, s.y - w), Vector2(0, s.y)], [edge, none, none, edge])
	_quad(b, [Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - w, s.y - w), Vector2(s.x - w, w)], [edge, edge, none, none])

## The bits flung about, each fading out over the end of its life.
func _draw_bits(b: Face.Builder, bits: Array) -> void:
	for bit: Dictionary in bits:
		if bit.t < 0.0:
			continue
		var life: float = bit.life
		var a := clampf((life - bit.t) / (life * 0.35), 0.0, 1.0)
		var col: Color = bit.col
		col.a *= a
		var at: Vector2 = bit.pos
		var sz: float = bit.size
		var rot: float = bit.rot
		match String(bit.kind):
			"chip":
				Art.chip(b, at, 11.0 * sz, rot, col)
			"confetti":
				Art.petal(b, at, 11.0 * sz, 6.0 * sz * absf(cos(bit.t * 5.0 + rot)) + 1.0, rot, col)
			"star":
				Art.star(b, at, 14.0 * sz * (0.6 + 0.4 * a), col, rot)
			"spark":
				Art.glint(b, at, 22.0 * sz * a, rot, Color(col, col.a))
			"coin":
				Art.coin(b, at, 13.0 * sz, cos(bit.t * 7.0 + rot), a)
			"clover":
				Art._clover(b, at, 11.0 * sz, rot)
			"ring":
				var k := clampf(bit.t / life, 0.0, 1.0)
				var r := sz * (0.3 + 0.7 * (1.0 - pow(1.0 - k, 3.0)))
				b.stroke(Face.Builder.ring(at, r, r), maxf(2.0, 14.0 * (1.0 - k)), Color(bit.col, (bit.col as Color).a * (1.0 - k)), true)

## The stickers' letters: each hops in on its own, rocks for a moment and
## the word swells away at the end; a white rim and a dark one under the
## colour, so it reads over anything.
func _draw_stickers(font: Font) -> void:
	for st: Dictionary in _stickers:
		var text: String = st.text
		var size: int = st.size
		var total := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x := -total * 0.5
		var out_a := 1.0 - clampf((st.t - (st.life - 0.3)) / 0.3, 0.0, 1.0)
		var swell := 1.0 + 0.2 * (1.0 - out_a)
		var tilt: float = st.tilt
		for i in text.length():
			var ch := text[i]
			var adv := font.get_char_size(ch.unicode_at(0), size).x
			var k := clampf((st.t - i * 0.035) / 0.28, 0.0, 1.0)
			if k <= 0.0 and not Motion.reduce:
				x += adv
				continue
			var sc := 1.0 if Motion.reduce else Motion.back_out(k)
			var hop := 0.0 if Motion.reduce else -sin(st.t * 8.0 - i * 0.55) * size * 0.09 * exp(-st.t * 1.4)
			var centre: Vector2 = st.at + (Vector2(x + adv * 0.5, hop) * swell).rotated(tilt)
			var rock := 0.0 if Motion.reduce else sin(st.t * 7.0 + i) * 0.08 * exp(-st.t * 1.2)
			_air.draw_set_transform(centre, tilt + rock, Vector2(sc, sc) * swell)
			var o := Vector2(-adv * 0.5, size * 0.36)
			var col: Color = STICKER_COLS[i % STICKER_COLS.size()] if st.rainbow else st.col
			_air.draw_char_outline(font, o + Vector2(0, size * 0.09), ch, size, int(size * 0.34), Color(0.25, 0.15, 0.05, 0.35 * out_a))
			_air.draw_char_outline(font, o, ch, size, int(size * 0.3), Color(Color("fffaf0"), out_a))
			_air.draw_char_outline(font, o, ch, size, int(size * 0.13), Color(col.darkened(0.5), out_a))
			_air.draw_char(font, o, ch, size, Color(col, out_a))
			x += adv
	_air.draw_set_transform(Vector2.ZERO)

## A new biggest number: the pebble rises out of its merge to the middle of
## the tray, big, over a turning sunburst, then flies up into the plate.
func _draw_reveal() -> void:
	if _reveal.is_empty():
		return
	var t: float = _reveal.t
	var hold: float = _reveal.hold
	var v: int = _reveal.v
	var gold := v >= Sim.GOAL
	var mid := _in_air(field, Vector2(field.size.x * 0.5, field.size.y * 0.4))
	var plate := _in_air(_big_view, _big_view.size * 0.5)
	var big := _u * (2.6 if gold else 2.1)
	var at: Vector2
	var size: float
	var burst := 0.0
	if t < 0.32:
		var k := Motion.back_out(t / 0.32)
		at = (_reveal.from as Vector2).lerp(mid, minf(1.0, t / 0.26))
		size = lerpf(_u * 0.86, big, k)
		burst = clampf(t / 0.32, 0.0, 1.0)
	elif t < hold:
		at = mid + Vector2(0, sin((t - 0.32) * 4.0) * 6.0)
		size = big * (1.0 + 0.03 * sin((t - 0.32) * 7.0))
		burst = 1.0
	else:
		var k := clampf((t - hold) / REVEAL_FLY, 0.0, 1.0)
		var e := k * k
		var ctrl := mid.lerp(plate, 0.5) + Vector2(0, -120.0)
		at = mid.lerp(ctrl, e).lerp(ctrl.lerp(plate, e), e)
		size = lerpf(big, 60.0, e)
		burst = 1.0 - minf(1.0, k * 2.5)
	if burst > 0.0:
		var rc := Art.GOLD if gold else Art.paint(v).lightened(0.35)
		var rs := big * 2.6 * burst
		_air.draw_mesh(Art.rays(512.0, rc, 16 if gold else 12), null, Transform2D(_clock * 0.7, Vector2(rs, rs) / 512.0, 0.0, at))
		_air.draw_mesh(Art.rays(512.0, Color("fffaf0"), 8), null, Transform2D(-_clock * 0.4, Vector2(rs, rs) * 0.7 / 512.0, 0.0, at))
	var tilt := sin(t * 3.0) * 0.06 if t < hold else 0.0
	_air.draw_set_transform(at, tilt, Vector2(size, size) / 200.0)
	_air.draw_mesh(Art.pebble(v, 200.0), null, Transform2D.IDENTITY)
	Art.number(_air, Art.font(), Vector2.ZERO, v, 200.0)
	_air.draw_set_transform(Vector2.ZERO)
	# the line under it while it holds
	if t > 0.2 and t < hold:
		var a := clampf((t - 0.2) / 0.2, 0.0, 1.0) * clampf((hold - t) / 0.15, 0.0, 1.0)
		var font := get_theme_font("font", "WellDone")
		var text := tr("LT_GOAL_LINE") if gold else "%d!" % v
		var fs := 64 if gold else 76
		var room := field.size.x - 60.0
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > room:
			fs = int(fs * room / w)
			w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := mid + Vector2(-w * 0.5, big * 0.5 + 90.0)
		_air.draw_string_outline(font, o + Vector2(0, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, Color(0.2, 0.12, 0.05, 0.35 * a))
		_air.draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, Color(Art.INK, 0.8 * a))
		_air.draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.SUN.lightened(0.2) if gold else Color("fffaf0"), a))

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
	# while a new number is on its way up, the plate keeps the old one
	var shown: int = int(_reveal.prev) if not _reveal.is_empty() else sim.max_v
	var s := minf(_big_view.size.y, 64.0)
	var c := _big_view.size * 0.5
	var k := 1.0 if Motion.reduce else clampf(_big_t / 0.4, 0.0, 1.0)
	var sc := Motion.back_out(k)
	_big_view.draw_set_transform(c, 0.0, Vector2(sc, sc))
	_big_view.draw_mesh(Art.pebble(shown, s), null, Transform2D.IDENTITY)
	Art.number(_big_view, Art.font(), Vector2.ZERO, shown, s)
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
	# the air (its rain and bursts) stays over the card
	move_child(_air, get_child_count() - 1)
	Motion.appear(_end, 0.0, 1.0, 0.3)
	_end_at = _clock
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
		# a sunburst turns behind it once it has landed, gold for a thirteen
		var glow := 1.0 if Motion.reduce else clampf((since - 0.55) / 0.3, 0.0, 1.0)
		if glow > 0.0:
			var rc := Art.GOLD if biggest >= Sim.GOAL else Art.paint(biggest).lightened(0.35)
			var rs := s * 3.2 * Motion.back_out(glow) / 512.0
			seat.draw_mesh(Art.rays(512.0, rc, 14), null, Transform2D(t * 0.5, Vector2(rs, rs), 0.0, top))
			seat.draw_mesh(Art.rays(512.0, Color("fffaf0"), 8), null, Transform2D(-t * 0.3, Vector2(rs, rs) * 0.7, 0.0, top))
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
	score.text = Record.grouped(sim.score) if Motion.reduce else "0"
	if not Motion.reduce:
		_end_score = score
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

## The end card's score runs up from nothing to what the game made, with
## a burst when it gets there.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 1.1, 0.0, 1.0)
	var shown := int(sim.score * (1.0 - pow(1.0 - k, 3.0)))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
		if int(_clock * 20.0) % 2 == 0:
			_fx.cue("select", 0.9 + 0.8 * k, -12.0)
	if k >= 1.0:
		_end_score.pivot_offset = _end_score.size * 0.5
		_kick(_end_score, 0.25, 0.4)
		var at := _in_air(_end_score, _end_score.size * 0.5)
		_spray(_air_bits, at, Art.GOLD, 14, 620.0, "star", 1.1)
		_spray(_air_bits, at, Color("fffaf0"), 8, 480.0, "spark", 1.1)
		_ring(_air_bits, at, 220.0, Color(Art.GOLD, 0.9))
		_end_score = null

func _celebrate(better: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var lucky: bool = sim.max_v >= Sim.GOAL
	if better or lucky:
		_rain = 3.5
	var fx := Fx2D.new()
	_end.add_child(fx)
	var mid := size * 0.5
	var puffs := 14 if better else (8 if lucky else 4)
	for k in puffs:
		var at := mid + Vector2.from_angle(TAU * k / float(puffs) - PI * 0.5) * Vector2(400.0, 330.0)
		var t := get_tree().create_timer(0.25 + 0.1 * k)
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
