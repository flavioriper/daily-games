extends Control

## Stackwood: the sixth game on the Arcade tab, a falling-block number merge
## (spec docs/superpowers/specs/2026-09-27-arcade-stackwood-design.md). The
## flat boards' top bar (back, the title in ink, restart, settings), a paper
## row with the score, the best and the next block, the shelf in the
## Arcade's wooden frame, and under it the acorns and the three tools.
##
## Play: press on the shelf and slide to steer the falling block over a
## column; let go and it drops. Left alone it keeps falling, faster with
## every block. The game is arcade/stackwood_sim.gd, stepped at its fixed
## DT; this screen draws it and plays its events.
##
## Drawing: the shelf's back wall is one still mesh built on resize; every
## block is one cached mesh moved by the transform with its number lettered
## over it; the trails, bolts, sparks and the lane are one live mesh.

signal closed

const Sim = preload("res://arcade/stackwood_sim.gd")
const Art = preload("res://arcade/stackwood_art.gd")
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

const GAME := "stackwood"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const TOOLS_H := 150.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
const MAX_STEPS := 12
## Cells a second a settled block falls into a gap at, and slides sideways.
const SETTLE_V := 16.0
## How long a merged-away block takes to slide into the one it joined.
const JOIN_T := 0.16
const WALL := Color("f3e6cf")
const WALL_DEEP := Color("e6d3b3")
const LANE := Color("fffaf0")
const DANGER := Color("e2645c")
const SHELF := Color("b98556")
const SHELF_DEEP := Color("946440")
const CONFETTI := [Color("f7dc9c"), Color("ee8d6e"), Color("9391dc"), Color("5fc1ad"), Color("f2b632")]

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
var _next_view: Control
var _acorn_l: Label
var _acorn_icon: Control
var _tool_buttons := {}
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
var _roll := 0.0
var _beat_best := false
var _clock := 0.0
## Pixels a cell, and the shelf's top-left (the spawn lane's) in `field`.
var _u := 100.0
var _origin := Vector2.ZERO
var _wall: ArrayMesh
var _live: ArrayMesh
## One a block on the shelf: id -> {pos: Vector2 (column, row, in cells),
## v, bump: seconds since it last grew, -1 for never}.
var _vis := {}
## Blocks merged away sliding into the one they joined: {v, from, to, t}.
var _joins: Array = []
## Blocks blown or zapped away, and the tumble at the end: {v, pos, vel, spin, rot, t}.
var _debris: Array = []
## Bolts from the sky to zapped blocks: {to (px), t, seed}.
var _bolts: Array = []
## Numbers rising off a merge: {pos (cells), text, t, col, big, rays}.
var _pops: Array = []
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _dragging := false
var _lane := -1
var _danger := false
var _seat: Control
var _milestones := {}

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

	top_bar = FlatTopBar.new("Stackwood", tr("SW_MOTTO"), true)
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

	col.add_child(_build_tools())
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
	# the next block, drawn small beside its kicker
	var parts := _plate("SW_NEXT", 0.8)
	_next_view = Control.new()
	_next_view.custom_minimum_size = Vector2(0, 60)
	_next_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_view.draw.connect(_draw_next)
	parts[1].add_child(_next_view)
	row.add_child(parts[0])
	return row

## The acorns on the left, then the three tools: each a paper chip with its
## picture and its price, dimmed until it can be bought.
func _build_tools() -> Control:
	var row := HBoxContainer.new()
	row.name = "Tools"
	row.custom_minimum_size.y = TOOLS_H
	row.add_theme_constant_override("separation", 16)
	var bank := _plate("SW_ACORNS", 0.9)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 6)
	bank[1].add_child(line)
	_acorn_icon = _icon(func(ci: Control) -> void:
		ci.draw_mesh(Art.acorn(ci.size.y * 0.9), null, Transform2D(0.0, ci.size * 0.5)))
	_acorn_icon.custom_minimum_size = Vector2(48, 56)
	line.add_child(_acorn_icon)
	_acorn_l = Label.new()
	_acorn_l.text = "0"
	_acorn_l.theme_type_variation = "SheetTitle"
	line.add_child(_acorn_l)
	row.add_child(bank[0])
	for tool in [Sim.Tool.WILD, Sim.Tool.BOMB, Sim.Tool.ZAP]:
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
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := CozyTheme.lifted(Color("fcf7ef") if st != "pressed" else Color("f1e6d2"), 30, 8)
		b.add_theme_stylebox_override(st, sb)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var pic := _icon(func(ci: Control) -> void:
		var s := minf(ci.size.y, ci.size.x) * 0.92
		var c := ci.size * 0.5
		var m: ArrayMesh = Art.zap(s * 1.05) if tool == Sim.Tool.ZAP else Art.block(0 if tool == Sim.Tool.WILD else -1, s)
		ci.draw_mesh(m, null, Transform2D(0.0, c)))
	pic.custom_minimum_size = Vector2(0, 76)
	col.add_child(pic)
	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", 2)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(price)
	var nut := _icon(func(ci: Control) -> void:
		ci.draw_mesh(Art.acorn(ci.size.y * 0.8), null, Transform2D(0.0, ci.size * 0.5)))
	nut.custom_minimum_size = Vector2(26, 34)
	price.add_child(nut)
	var cost := Label.new()
	cost.text = str(Sim.COSTS[tool])
	cost.theme_type_variation = "MenuKicker"
	price.add_child(cost)
	b.pressed.connect(_on_tool.bind(tool))
	_tool_buttons[tool] = b
	return b

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The shelf is COLS cells wide and ROWS + 1 tall (the top one the lane a
## block falls in from), with a plank under it; scaled to the room and
## centred.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_u = floorf(minf((s.x - 24.0) / Sim.COLS, (s.y - 40.0) / (Sim.ROWS + 1.35)))
	var board := Vector2(Sim.COLS, Sim.ROWS + 1) * _u
	_origin = Vector2(floorf((s.x - board.x) * 0.5), floorf((s.y - board.y - 0.35 * _u) * 0.5))
	_wall = _build_wall()
	var box: Control = _banner.get_meta("box")
	box.position = Vector2(24, s.y * 0.3)
	box.size = Vector2(s.x - 48, 0)
	field.queue_redraw()

## The centre of a cell, in the field's pixels: column `c`, row `r` up from
## the floor (fractions allowed).
func px(c: float, r: float) -> Vector2:
	return _origin + Vector2((c + 0.5) * _u, (Sim.ROWS + 0.5 - r) * _u)

func _column_at(x: float) -> int:
	return clampi(int(floorf((x - _origin.x) / _u)), 0, Sim.COLS - 1)

# --- the game ---

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	sim = Sim.new()
	_acc = 0.0
	_paused = false
	_vis.clear()
	_joins.clear()
	_debris.clear()
	_bolts.clear()
	_pops.clear()
	_milestones.clear()
	_shake = 0.0
	_roll = 0.0
	_beat_best = false
	_danger = false
	_dragging = false
	_lane = -1
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
	field.queue_redraw()

func _animate(delta: float) -> void:
	# every block on the shelf settles toward its cell
	var seen := {}
	for c in Sim.COLS:
		var col: Array = sim.cols[c]
		for i in col.size():
			var bl: Dictionary = col[i]
			seen[bl.id] = true
			var want := Vector2(c, i)
			if not _vis.has(bl.id):
				_vis[bl.id] = {"pos": want, "v": bl.v, "bump": -1.0}
			var vis: Dictionary = _vis[bl.id]
			if Motion.reduce:
				vis.pos = want
			else:
				vis.pos = Vector2(move_toward(vis.pos.x, want.x, SETTLE_V * delta), move_toward(vis.pos.y, want.y, SETTLE_V * delta))
			if int(vis.v) != int(bl.v):
				vis.v = bl.v
				vis.bump = 0.0
			if vis.bump >= 0.0:
				vis.bump += delta
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
	for bo: Dictionary in _bolts:
		bo.t += delta
	_bolts = _bolts.filter(func(bo: Dictionary) -> bool: return bo.t < 0.35)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 0.9)
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 14.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO
	var danger := false
	for c in Sim.COLS:
		if sim.height(c) >= Sim.ROWS - 1:
			danger = true
	if danger and not _danger and not sim.is_over():
		_fx.cue("warn")
	_danger = danger

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
	if at == Vector2.INF:
		return
	if _paused:
		if pressed and _end == null and not settings_sheet.is_open():
			_pause(false)
		return
	if pressed:
		_dragging = true
	if not _dragging:
		return
	_lane = _column_at(at.x)
	aim(_lane)
	if released:
		_dragging = false
		_lane = -1
		drop()

## Steer the falling block toward a column (the harness drives this too).
func aim(c: int) -> void:
	if sim != null:
		sim.aim(c)
		_play_events()

func drop() -> void:
	if sim != null:
		sim.drop()
		_play_events()

func _on_tool(tool: int) -> void:
	if sim == null or _paused:
		return
	sim.use(tool)
	_play_events()

func _pause(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	_dragging = false
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
		match String(ev.type):
			"ready":
				_show_banner(tr("FF_READY"), tr("SW_READY_LINE"), 1.0)
			"go":
				_show_banner(tr("SW_GO"), "", 0.3)
				_fx.cue("go")
			"move":
				_fx.cue("move", randf_range(0.95, 1.08), -2.0)
			"drop":
				_fx.cue("drop", randf_range(0.95, 1.05))
			"land":
				_vis[ev.id] = {"pos": Vector2(ev.col, ev.row), "v": ev.v, "bump": 0.0 if ev.wild else -1.0}
				_fx.cue("land", randf_range(0.92, 1.06))
				_fx.puff(px(ev.col, ev.row - 0.45), Color(Art.WOOD_HI, 0.9), 4)
				if ev.wild:
					_fx.cue("wild")
					_fx.sparkle(px(ev.col, ev.row), Color("fffaf0"))
				_shake = maxf(_shake, 0.12)
			"merge":
				_on_merge(ev)
			"chain_end":
				pass
			"new_max":
				_on_new_max(int(ev.v))
			"retired":
				_show_banner(tr("SW_RETIRED") % int(ev.v), tr("SW_RETIRED_LINE"), 1.1)
				_fx.cue("retired")
			"bomb":
				_fx.cue("bomb")
				_fx.puff(px(ev.col, ev.row), Color("fffaf0"), 14)
				_fx.puff(px(ev.col, ev.row), Pal.SUN, 8)
				_fx.ring(px(ev.col, ev.row), 1.4 * _u, Color("ffb05c"))
				_shake = maxf(_shake, 0.8)
			"blast":
				for g: Dictionary in ev.blocks:
					_fling(int(g.v), Vector2(g.col, g.row))
			"zap":
				_fx.cue("zap")
				for g: Dictionary in ev.blocks:
					_bolts.append({"to": px(g.col, g.row), "t": 0.0, "seed": randf() * 10.0})
					_fling(int(g.v), Vector2(g.col, g.row))
					_fx.sparkle(px(g.col, g.row), Art.ZAP)
				_shake = maxf(_shake, 0.4)
			"tool":
				match String(ev.tool):
					"wild":
						_fx.cue("buy")
						_show_banner(tr("SW_WILD"), tr("SW_WILD_LINE"), 0.7)
					"bomb":
						_fx.cue("fuse")
						_show_banner(tr("SW_BOMB"), tr("SW_BOMB_LINE"), 0.7)
					"zap":
						_show_banner(tr("SW_ZAP"), tr("SW_ZAP_LINE"), 0.7)
				_acorn_l.pivot_offset = _acorn_l.size * 0.5
				Motion.bump(_acorn_l, 0.25, 0.3)
			"refused":
				_fx.cue("refused")
				var b: Control = _tool_buttons[{"wild": Sim.Tool.WILD, "bomb": Sim.Tool.BOMB, "zap": Sim.Tool.ZAP}[ev.tool]]
				Motion.shiver(b)
			"over":
				_topple()
	sim.events.clear()

func _on_merge(ev: Dictionary) -> void:
	var chain: int = ev.chain
	for m: Dictionary in ev.merges:
		var to := Vector2(m.col, m.row)
		for f: Dictionary in m.from:
			var from: Vector2 = (_vis[f.id].pos if _vis.has(f.id) else Vector2(f.col, f.row))
			var v: int = int(_vis[f.id].v) if _vis.has(f.id) else int(m.v) >> (m.from as Array).size()
			_joins.append({"v": v, "from": from, "to": to, "t": 0.0})
			_vis.erase(f.id)
		if _vis.has(m.id):
			_vis[m.id].v = m.v
			_vis[m.id].bump = 0.0
		var big := int(m.v) >= 128
		_pop(to + Vector2(0, 0.3), "+%s" % Record.grouped(int(m.v) * chain), Pal.SUN if chain > 1 else Color("fffaf0"), big)
		_fx.puff(px(to.x, to.y), Art.paint(int(m.v)), 6)
		if big:
			_fx.sparkle(px(to.x, to.y), Color("fffaf0"))
	_fx.cue("merge", minf(1.0 + 0.09 * (chain - 1), 1.6))
	if chain >= 2:
		# one chain label at a time: the new count replaces the last
		_pops = _pops.filter(func(q: Dictionary) -> bool: return not q.rays)
		var p := _pop(Vector2((Sim.COLS - 1) * 0.5, Sim.ROWS - 1.2), tr("SW_CHAIN") % chain, Pal.SUN, true)
		p.rays = true
		p.t = -0.1
		_fx.cue("chain", minf(1.0 + 0.07 * (chain - 2), 1.5))
		_score_k.pivot_offset = _score_k.size * 0.5
		Motion.bump(_score_k, 0.3, 0.35)
		_shake = maxf(_shake, 0.15 + 0.05 * chain)

func _on_new_max(v: int) -> void:
	if v < 256 or _milestones.has(v):
		return
	_milestones[v] = true
	if v == 2048:
		_show_banner("2048!", tr("SW_2048_LINE"), 1.4)
		_fx.cue("milestone")
		_confetti()
	elif v > 2048:
		_show_banner(Record.grouped(v) + "!", "", 1.0)
		_fx.cue("milestone")
		_confetti()
	else:
		_show_banner(Record.grouped(v) + "!", "", 0.6)
		_fx.cue("big")

func _confetti() -> void:
	if Motion.reduce:
		return
	for k in 7:
		var at := Vector2(field.size.x * (0.12 + 0.76 * k / 6.0), field.size.y * (0.25 + 0.1 * (k % 2)))
		var t := get_tree().create_timer(0.1 * k)
		t.timeout.connect(func() -> void:
			if is_instance_valid(_fx):
				_fx.puff(at, CONFETTI[k % CONFETTI.size()], 10))

## A block knocked off the shelf: it flies out, spinning, and falls away.
func _fling(v: int, cell: Vector2) -> void:
	var at := px(cell.x, cell.y)
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.4, -0.6)).normalized()
	_debris.append({"v": v, "pos": at, "vel": dir * randf_range(500.0, 900.0), "spin": randf_range(-8.0, 8.0), "rot": 0.0, "t": 0.0})

func _show_banner(text: String, sub: String, hold: float) -> void:
	_banner.text = text
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
	var nuts := str(sim.acorns)
	if _acorn_l.text != nuts:
		_acorn_l.text = nuts
	for tool: int in _tool_buttons:
		var b: Button = _tool_buttons[tool]
		var ok: bool = sim.acorns >= int(Sim.COSTS[tool]) and not sim.is_over()
		b.modulate.a = 1.0 if ok else 0.5
	_next_view.queue_redraw()

# --- drawing ---

## The shelf's back wall: warm painted boards, a faint lane down every
## column, the dashed line a stack must stay under, and the plank it stands
## on.
func _build_wall() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	# the room behind the shelf: a soft greenhouse light
	_quad(b, [Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)], [Color("cfe6dc"), Color("cfe6dc"), Color("e9dcc0"), Color("e9dcc0")])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 6:
		var c := Vector2(rng.randf() * s.x, rng.randf_range(0.0, 0.5) * s.y)
		b.ellipse(c, rng.randf_range(80.0, 160.0), rng.randf_range(40.0, 70.0), Color(1, 1, 0.9, 0.12))
	var o := _origin
	var board := Vector2(Sim.COLS, Sim.ROWS + 1) * _u
	# the shelf's back, in boards
	b.fan(Face.Builder.round_rect(o - Vector2(10, 10), board + Vector2(20, 14), 22.0), Color(WALL_DEEP, 0.95))
	b.fan(Face.Builder.round_rect(o - Vector2(4, 4), board + Vector2(8, 4), 18.0), WALL)
	for c in Sim.COLS:
		var x := o.x + c * _u
		if c % 2 == 1:
			b.fan(PackedVector2Array([Vector2(x, o.y + _u), Vector2(x + _u, o.y + _u), Vector2(x + _u, o.y + board.y), Vector2(x, o.y + board.y)]), Color(WALL_DEEP, 0.35))
		if c > 0:
			b.stroke(PackedVector2Array([Vector2(x, o.y + _u + 6), Vector2(x, o.y + board.y - 4)]), 2.0, Color(WALL_DEEP.darkened(0.1), 0.6))
	# knots in the boards
	for i in 7:
		var p := o + Vector2(rng.randf() * board.x, _u + rng.randf() * (board.y - _u))
		b.ellipse(p, 7.0, 4.0, Color(WALL_DEEP.darkened(0.15), 0.35))
	# the spawn lane: paler, with the dashed line under it
	b.fan(Face.Builder.round_rect(o - Vector2(4, 4), Vector2(board.x + 8, _u + 4), 18.0), Color(LANE, 0.55))
	var y := o.y + _u
	var x0 := o.x + 6.0
	while x0 < o.x + board.x - 6.0:
		b.fan(Face.Builder.round_rect(Vector2(x0, y - 3.0), Vector2(minf(22.0, o.x + board.x - 6.0 - x0), 6.0), 3.0), Color(DANGER, 0.45))
		x0 += 36.0
	# the plank the shelf stands on
	var foot := o.y + board.y
	b.fan(Face.Builder.round_rect(Vector2(o.x - 22, foot - 2), Vector2(board.x + 44, 0.3 * _u + 12), 12.0), SHELF_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(o.x - 22, foot - 4), Vector2(board.x + 44, 0.26 * _u), 12.0), SHELF)
	b.fan(Face.Builder.round_rect(Vector2(o.x - 12, foot), Vector2(board.x + 24, 5.0), 2.5), Color(1, 1, 1, 0.25))
	# pots of seedlings either end of the plank, when there is room
	if o.x > 60.0:
		for side in [-1.0, 1.0]:
			var px_ := o.x - 50.0 if side < 0 else o.x + board.x + 50.0
			_pot(b, Vector2(px_, foot - 4.0), minf(o.x * 0.7, 60.0))
	return b.mesh()

func _pot(b: Face.Builder, foot: Vector2, w: float) -> void:
	b.fan(PackedVector2Array([foot + Vector2(-w * 0.5, -w * 0.8), foot + Vector2(w * 0.5, -w * 0.8), foot + Vector2(w * 0.38, 0), foot + Vector2(-w * 0.38, 0)]), Color("d9774a"))
	b.fan(Face.Builder.round_rect(foot + Vector2(-w * 0.56, -w * 0.9), Vector2(w * 1.12, w * 0.2), w * 0.06), Color("e8946a"))
	for k in 3:
		var base := foot + Vector2((k - 1) * w * 0.2, -w * 0.88)
		b.stroke(PackedVector2Array([base, base + Vector2((k - 1) * w * 0.1, -w * 0.4)]), w * 0.05, Color("6f9c46"))
		b.ellipse(base + Vector2((k - 1) * w * 0.16, -w * 0.44), w * 0.14, w * 0.08, Color("8dba58"))

static func _quad(b: Face.Builder, p: Array, c: Array) -> void:
	var i0 := b.vertex(p[0], c[0])
	var i1 := b.vertex(p[1], c[1])
	var i2 := b.vertex(p[2], c[2])
	var i3 := b.vertex(p[3], c[3])
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)

func _draw_field() -> void:
	if _wall == null:
		_layout_field()
	if _wall == null or sim == null:
		return
	field.draw_mesh(_wall, null)
	var font := Art.font()
	var s := _u - 6.0
	# the live layer under the blocks: the lane, the landing ghost, danger
	var under := Face.Builder.new()
	_draw_lane(under)
	_draw_danger(under)
	if not under.verts.is_empty():
		_live = under.mesh()
		field.draw_mesh(_live, null)
	field.draw_set_transform(_shake_off)
	# the blocks sliding into the ones they joined
	for j: Dictionary in _joins:
		var k: float = j.t / JOIN_T
		var p: Vector2 = (j.from as Vector2).lerp(j.to, k * k)
		var sc := lerpf(1.0, 0.6, k)
		field.draw_mesh(Art.block(j.v, s), null, Transform2D(0.0, Vector2(sc, sc), 0.0, px(p.x, p.y)), Color(1, 1, 1, 1.0 - k * 0.6))
	# the blocks on the shelf, bottom row first so a lip sits over the row under
	var order := _vis.keys()
	order.sort_custom(func(a, b) -> bool: return float(_vis[a].pos.y) < float(_vis[b].pos.y))
	for id in order:
		var vis: Dictionary = _vis[id]
		var sc := 1.0
		if vis.bump >= 0.0 and not Motion.reduce:
			sc = 1.0 + 0.18 * sin(clampf(vis.bump / 0.24, 0.0, 1.0) * PI)
		var c := px(vis.pos.x, vis.pos.y)
		var hot: bool = _danger and sim.height(int(roundf(vis.pos.x))) >= Sim.ROWS - 1 and vis.pos.y >= Sim.ROWS - 2
		var tint := Color.WHITE
		if hot and not Motion.reduce:
			tint = Color(1.0, 1.0 - 0.18 * (0.5 + 0.5 * sin(_clock * 9.0)), 1.0 - 0.2 * (0.5 + 0.5 * sin(_clock * 9.0)))
		field.draw_mesh(Art.block(vis.v, s), null, Transform2D(0.0, Vector2(sc, sc), 0.0, c), tint)
		Art.number(field, font, c, vis.v, s * sc)
	_draw_piece(font, s)
	# debris: knocked off and tumbling
	for d: Dictionary in _debris:
		var a := 1.0 - clampf((d.t - 1.0) / 0.6, 0.0, 1.0)
		field.draw_set_transform(d.pos + _shake_off, d.rot, Vector2.ONE)
		field.draw_mesh(Art.block(d.v, s), null, Transform2D.IDENTITY, Color(1, 1, 1, a))
		Art.number(field, font, Vector2.ZERO, d.v, s, a)
	field.draw_set_transform(Vector2.ZERO)
	var over := Face.Builder.new()
	_draw_bolts(over)
	_draw_rays(over)
	if not over.verts.is_empty():
		var m := over.mesh()
		field.set_meta("over", m)
		field.draw_mesh(m, null)
	_draw_pops()

## The falling piece, and where it would land.
func _draw_piece(font: Font, s: float) -> void:
	if sim.piece.is_empty():
		return
	var pc: Dictionary = sim.piece
	var v: int = pc.v if int(pc.kind) == Sim.Piece.BLOCK else (0 if int(pc.kind) == Sim.Piece.WILD else -1)
	var land: int = sim.landing(pc.col)
	# the ghost where it would land
	if float(pc.y) - land > 0.6:
		var g := px(pc.col, land)
		field.draw_mesh(Art.block(v, s), null, Transform2D(0.0, g), Color(1, 1, 1, 0.28))
	var c := px(pc.col, float(pc.y))
	var wob := 0.0
	var sc := Vector2.ONE
	if not Motion.reduce:
		if pc.hold > 0.0:
			var k := 1.0 - float(pc.hold) / Sim.HOLD
			sc = Vector2.ONE * Motion.back_out(clampf(k * 1.4, 0.0, 1.0))
		elif pc.dropping:
			sc = Vector2(0.9, 1.12)
		else:
			wob = sin(_clock * 3.0) * 0.04
	field.draw_mesh(Art.block(v, s), null, Transform2D(wob, sc, 0.0, c))
	if v > 0:
		field.draw_set_transform(c + _shake_off, wob, sc)
		Art.number(field, font, Vector2.ZERO, v, s)
		field.draw_set_transform(_shake_off)

## The column the finger is over, lit from the lane down to where the
## block would land.
func _draw_lane(b: Face.Builder) -> void:
	if sim.piece.is_empty():
		return
	var c: int = sim.piece.col
	var land: int = sim.landing(c)
	var top := px(c, Sim.ROWS) - Vector2(_u * 0.5, _u * 0.5)
	var bottom := px(c, land) + Vector2(_u * 0.5, -_u * 0.5)
	if bottom.y <= top.y:
		return
	var a := 0.32 if _dragging else 0.18
	_quad(b, [top, Vector2(bottom.x, top.y), bottom, Vector2(top.x, bottom.y)], [Color(LANE, 0.0), Color(LANE, 0.0), Color(LANE, a), Color(LANE, a)])

## A stack one short of the line glows rose at the line.
func _draw_danger(b: Face.Builder) -> void:
	if not _danger:
		return
	var beat := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 7.0)
	for c in Sim.COLS:
		if sim.height(c) < Sim.ROWS - 1:
			continue
		var top := px(c, Sim.ROWS) + Vector2(-_u * 0.5, _u * 0.5)
		var edge := Color(DANGER, 0.3 + 0.25 * beat)
		var none := Color(DANGER, 0.0)
		_quad(b, [top, top + Vector2(_u, 0), top + Vector2(_u, _u * 1.2), top + Vector2(0, _u * 1.2)], [edge, edge, none, none])

## A bolt of light from the top of the shelf to each zapped block.
func _draw_bolts(b: Face.Builder) -> void:
	for bo: Dictionary in _bolts:
		var k: float = bo.t / 0.35
		var a := 1.0 - k
		var from := Vector2(bo.to.x + sin(bo.seed) * _u * 0.4, 0.0)
		var pts := PackedVector2Array()
		var n := 7
		for i in n + 1:
			var t := float(i) / n
			var jig := 0.0 if i == 0 or i == n else (_hash(i, bo.seed + floorf(bo.t * 30.0)) - 0.5) * _u * 0.5
			pts.append(from.lerp(bo.to, t) + Vector2(jig, 0))
		b.stroke(pts, 16.0, Color(Art.ZAP, 0.35 * a))
		b.stroke(pts, 6.0, Color(1, 1, 1, 0.9 * a))

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
			b.fan(PackedVector2Array([c + Vector2.from_angle(ang - 0.1) * 22.0 * grow, c + Vector2.from_angle(ang) * 110.0 * grow, c + Vector2.from_angle(ang + 0.1) * 22.0 * grow]),
				Color(Pal.SUN if k % 2 == 0 else Color("fffaf0"), 0.45 * a))

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
		var big: bool = p.big
		var full := 60 if big else 44
		var fs := full if Motion.reduce else maxi(8, int(lerpf(14.0, full * 1.0, Motion.back_out(minf(1.0, p.t / 0.24)))))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := at + Vector2(-w * 0.5, 0)
		field.draw_string_outline(font, o + Vector2(0, 4), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0.2, 0.12, 0.05, 0.35 * a))
		field.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(Art.INK, a))
		field.draw_string(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.col, a))

func _draw_next() -> void:
	if sim == null:
		return
	var v: int = sim.next_value()
	if v <= 0:
		return
	var s := minf(_next_view.size.y, 64.0)
	var c := _next_view.size * 0.5
	_next_view.draw_mesh(Art.block(v, s), null, Transform2D(0.0, c))
	Art.number(_next_view, Art.font(), c, v, s)

static func _hash(a: float, b: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)

func _pop(cell: Vector2, text: String, col: Color, big: bool) -> Dictionary:
	var p := {"pos": cell, "text": text, "t": 0.0, "col": col, "big": big, "rays": false}
	_pops.append(p)
	return p

# --- the end ---

## The shelf topples: every block flies off, then the card.
func _topple() -> void:
	var better := Record.add(GAME, sim.score, sim.max_v)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.max_v,
		"seconds": secs, "drops": sim.drops, "merges": sim.merges, "chain": sim.best_chain,
		"tools": sim.tools_used, "best": better})
	_fx.cue("topple")
	_show_banner(tr("SW_TOPPLED"), "", 1.0)
	_shake = 1.0
	for id in _vis.keys():
		var vis: Dictionary = _vis[id]
		_fling(int(vis.v), vis.pos)
	_vis.clear()
	# the blocks are gone from the drawing, not from the sim; keep them from
	# coming back on the next frame's settle
	for c in Sim.COLS:
		(sim.cols[c] as Array).clear()
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
	# the biggest block of the game, on two smaller ones, bobbing
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(0, 250)
	var biggest: int = sim.max_v
	var shown_at := _clock
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var since := _clock - shown_at
		var mid := Vector2(seat.size.x * 0.5, 240.0)
		var s := 110.0
		var font := Art.font()
		var under := [maxi(2, biggest >> 2), maxi(2, biggest >> 1)]
		for k in 2:
			var c := mid + Vector2((k - 0.5) * s * 1.02, -s * 0.5)
			seat.draw_mesh(Art.block(under[k], s), null, Transform2D(0.0, c))
			Art.number(seat, font, c, under[k], s)
		var land := 1.0 if Motion.reduce else Motion.back_out(clampf((since - 0.25) / 0.35, 0.0, 1.0))
		var bob := sin(t * 2.2) * 5.0
		var top := mid + Vector2(0, -s * 1.5 - (1.0 - land) * 200.0 + bob)
		seat.draw_mesh(Art.block(biggest, s * 1.1), null, Transform2D(sin(t * 1.5) * 0.04, top))
		Art.number(seat, font, top, biggest, s * 1.1, clampf(land * 2.0, 0.0, 1.0)))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "SW_END_CARD"
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
	for pair in [[Record.grouped(sim.max_v), "SW_STAT_BLOCK"], [str(sim.merges), "SW_STAT_MERGES"], [str(sim.best_chain), "SW_STAT_CHAIN"]]:
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
	if sim != null and not sim.is_over() and sim.score > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.max_v})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
