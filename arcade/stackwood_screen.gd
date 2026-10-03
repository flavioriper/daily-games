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
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
## What the phone knocks for (docs/agents/haptics.md). The shelf settles by
## itself after a drop, a round of merges at a time, and `move`, `wild` and
## `warn` are shared or are not the hand's, so only the end card's cue is
## mapped: the events ask through `_feel` and the frame knocks once, with
## the strongest.
const HAPTICS := {"new_best": Haptics.WIN}
const Face = preload("res://ui/faces/face.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")

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
## How fast the falling block's drawing chases its column (the angular
## frequency of a critically damped spring), and how far it leans into the move.
const STEER_W := 30.0
const LEAN := 0.03
## Cells a second squared a settling block falls with, and the pace it starts at.
const GRAVITY := 90.0
const SETTLE_V0 := 4.0
## How long an acorn takes to fly from a merge to the bank.
const FLIGHT_T := 0.6
const BUNTING := [Color("f7dc9c"), Color("ee8d6e"), Color("9fcfb6"), Color("9391dc"), Color("f5b77e")]
const CONFETTI := [Color("f7dc9c"), Color("ee8d6e"), Color("9391dc"), Color("5fc1ad"), Color("f2b632")]
## A merge's word, by how loud it was (the chain, plus one for every extra
## block a single block took in at once), loudest first.
const WORDS := [[6, "SW_WORD_5"], [5, "SW_WORD_4"], [4, "SW_WORD_3"], [3, "SW_WORD_2"], [2, "SW_WORD_1"]]
const STICKER_COLS := [Color("ff6f61"), Color("ffb03b"), Color("ffd84d"), Color("7fd66a"), Color("5cb8ff"), Color("b77be6")]
const COMBO := Color("ff8a3d")
## The most bits alive in one layer at once.
const MAX_BITS := 420

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
## The knock this frame's events asked for, the strongest of them (-1: none);
## whether the block on the shelf was let go by the hand, and whether this
## drop (or bomb, or zap) has had its one bump for what it set off: a
## chain's later rounds add nothing.
var _knock := -1
var _by_hand := false
var _answered := false
var _seat: Control
var _milestones := {}
## The falling block's drawn column, its pace, and the piece it belongs to.
var _px := 2.0
var _pv := 0.0
var _piece_id := -1
var _was_dropping := false
## Merged blocks flashing white: {pos (cells), t}.
var _flashes: Array = []
## Acorns flying from a merge to the bank: {from, ctrl, to (px, in _air), t, value}.
var _flights: Array = []
## Acorns earned but still in the air, so the bank counts them as they land.
var _owed := 0
var _afford := {}
var _air: Control
var _air_fx: Node2D
var _next_t := 1.0
## Bits flung about, in the field's pixels and in the air's: splinters,
## sparks, stars, acorns, confetti and rings.
## {pos, vel, rot, spin, t, life, kind, col, size, float?}
var _bits: Array = []
var _air_bits: Array = []
## Words lettered a hopping letter at a time: {text, at, t, life, size,
## rainbow, col, rays, tilt, id}.
var _stickers: Array = []
## The shelf's flash after a big moment, fading, and its colour.
var _flash := 0.0
var _flash_col := Color.WHITE
## Drops in a row that merged, and the warm glow round the shelf it lights
## (0..1). A drop has landed since the last spawn; it has merged.
var _streak := 0
var _heat := 0.0
var _landed := false
var _drop_merged := false
## Seconds of acorns and confetti still raining down over the screen.
var _rain := 0.0
## The newest biggest block, waiting for its merge to say where it is.
var _new_max := 0
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
	_fx.haptics = HAPTICS
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
	Boosters.apply(GAME, sim, _boosts)
	_boosted = not _boosts.is_empty()
	_chance_used = false
	_run_gold = 0
	_acc = 0.0
	_paused = false
	_vis.clear()
	_joins.clear()
	_debris.clear()
	_bolts.clear()
	_pops.clear()
	_flashes.clear()
	_flights.clear()
	_owed = 0
	_afford.clear()
	_bits.clear()
	_air_bits.clear()
	_stickers.clear()
	_flash = 0.0
	_streak = 0
	_heat = 0.0
	_landed = false
	_drop_merged = false
	_rain = 0.0
	_new_max = 0
	_end_score = null
	_piece_id = -1
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
	field.queue_redraw()
	_air.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()

## Asks for a knock this frame; the strongest asked for is the one played.
func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _knock_now() -> void:
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1

## Whether the block just landed at (c, row) touches one of its own number,
## so the shelf's first round will merge it.
func _will_merge(c: int, row: int, v: int) -> bool:
	for n: Vector2i in [Vector2i(c - 1, row), Vector2i(c + 1, row), Vector2i(c, row - 1)]:
		if n.x < 0 or n.x >= Sim.COLS or n.y < 0 or n.y >= sim.height(n.x):
			continue
		if int(sim.cols[n.x][n.y].v) == v:
			return true
	return false

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
				_vis[bl.id] = _new_vis(want, bl.v)
			var vis: Dictionary = _vis[bl.id]
			if Motion.reduce or vis.pos.y < want.y:
				vis.pos = want
			else:
				vis.pos.x = move_toward(vis.pos.x, want.x, SETTLE_V * delta)
				if vis.pos.y > want.y:
					# it falls into the gap under gravity, and lands with a squash
					vis.vel = maxf(float(vis.vel), SETTLE_V0) + GRAVITY * delta
					vis.pos.y = maxf(want.y, vis.pos.y - vis.vel * delta)
					if vis.pos.y <= want.y:
						_squash(vis, clampf(float(vis.vel) * 0.012, 0.05, 0.16))
						vis.vel = 0.0
			if vis.squash >= 0.0:
				vis.squash += delta
			vis.dip += delta
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
	for f: Dictionary in _flashes:
		f.t += delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return f.t < 0.25)
	_next_t += delta
	_steer(delta)
	_fly(delta)
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
		_feel(Haptics.WARN)
	elif _danger and not danger and not sim.is_over():
		_phew()
		_feel(Haptics.GOOD)
	_danger = danger
	_animate_rewards(delta)

func _new_vis(pos: Vector2, v: int) -> Dictionary:
	return {"pos": pos, "v": v, "bump": -1.0, "vel": 0.0, "squash": -1.0, "amt": 0.0, "dip": 9.0, "dip_amt": 0.0}

func _squash(vis: Dictionary, amt: float) -> void:
	if Motion.reduce:
		return
	vis.squash = 0.0
	vis.amt = amt

## The falling block's drawing chases its column on a spring and leans into
## the move; a new piece starts over its own column.
func _steer(delta: float) -> void:
	if sim.piece.is_empty():
		return
	var want := float(sim.piece.col)
	_was_dropping = bool(sim.piece.dropping)
	if int(sim.piece.id) != _piece_id or Motion.reduce:
		_piece_id = int(sim.piece.id)
		_px = want
		_pv = 0.0
		return
	# the spring solved exactly, so a long frame cannot throw it off
	var x0 := _px - want
	var k := _pv + STEER_W * x0
	var ex := exp(-STEER_W * delta)
	_px = want + (x0 + k * delta) * ex
	_pv = (k - STEER_W * (x0 + k * delta)) * ex
	if absf(want - _px) < 0.002 and absf(_pv) < 0.05:
		_px = want
		_pv = 0.0

## Acorns in the air: when one lands in the bank, the bank counts it.
func _fly(delta: float) -> void:
	if _flights.is_empty():
		return
	for f: Dictionary in _flights:
		f.t += delta
		if f.t >= FLIGHT_T and not f.get("home", false):
			f.home = true
			_owed = maxi(0, _owed - int(f.value))
			_kick(_acorn_icon, 0.22, 0.22)
			_kick(_acorn_l, 0.14, 0.22)
			var bank := _in_air(_acorn_icon, _acorn_icon.size * 0.5)
			_spray(_air_bits, bank, Art.ACORN, 2, 280.0, "acorn", 0.5)
			_spray(_air_bits, bank, Color("fffaf0"), 3, 260.0, "spark", 0.7)
			if f.get("first", false):
				_ring(_air_bits, bank, 80.0, Color(Art.GOLD, 0.9))
				_sticker("+%d" % int(f.total), bank + Vector2(0, -80.0), 46, 0.8, false, Art.ACORN.lightened(0.15), false, "acorns")
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
			"spawn":
				_next_t = 0.0
				# a drop that landed and merged nothing breaks the combo
				if _landed and not _drop_merged:
					_streak = 0
				_landed = false
			"land":
				var vis := _new_vis(Vector2(ev.col, ev.row), int(ev.v))
				vis.bump = 0.0 if ev.wild else -1.0
				_vis[ev.id] = vis
				_squash(vis, 0.2 if _was_dropping else 0.11)
				# the column under it takes the knock, a little later the further down
				for id in _vis:
					var under: Dictionary = _vis[id]
					if id == ev.id or roundi(under.pos.x) != int(ev.col) or under.pos.y >= float(ev.row):
						continue
					var down: float = float(ev.row) - under.pos.y
					under.dip = -0.035 * (down - 1.0)
					under.dip_amt = (0.07 if _was_dropping else 0.04) * pow(0.7, down - 1.0)
				_fx.cue("land", randf_range(0.92, 1.06))
				_landed = true
				_drop_merged = false
				# One tap a drop: a block let go taps as it lands, or, when
				# it is about to merge, as it merges a tenth of a second on;
				# over the line it leaves the knock to the lose. One that
				# fell by itself says nothing.
				_answered = false
				_by_hand = bool(ev.get("dropped", false))
				if _by_hand and int(ev.row) < Sim.ROWS and not _will_merge(int(ev.col), int(ev.row), int(ev.v)):
					_feel(Haptics.TAP)
				if _was_dropping:
					_spray(_bits, px(ev.col, ev.row - 0.45), Art.WOOD_HI, 5, 260.0, "splinter", _u / 150.0)
				for side in [-0.42, 0.42]:
					_fx.puff(px(ev.col + side, ev.row - 0.48), Color(Art.WOOD_HI, 0.9), 3)
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
				_feel(Haptics.THUD)
				_answered = true
				_fx.puff(px(ev.col, ev.row), Color("fffaf0"), 14)
				_fx.puff(px(ev.col, ev.row), Pal.SUN, 8)
				_fx.ring(px(ev.col, ev.row), 1.4 * _u, Color("ffb05c"))
				_spray(_bits, px(ev.col, ev.row), Art.SPARK, 16, 900.0, "spark", _u / 110.0)
				_spray(_bits, px(ev.col, ev.row), Color("ffb05c"), 10, 800.0, "star", _u / 150.0)
				_shake = maxf(_shake, 0.8)
			"blast":
				for g: Dictionary in ev.blocks:
					_fling(int(g.v), Vector2(g.col, g.row))
					_spray(_bits, px(g.col, g.row), Art.paint(int(g.v)), 7, 700.0, "splinter", _u / 110.0)
				_flash_now(Color("ffcf8a"), 0.6)
			"zap":
				_fx.cue("zap")
				_feel(Haptics.BUMP)
				_answered = true
				for g: Dictionary in ev.blocks:
					_bolts.append({"to": px(g.col, g.row), "t": 0.0, "seed": randf() * 10.0})
					_fling(int(g.v), Vector2(g.col, g.row))
					_fx.sparkle(px(g.col, g.row), Art.ZAP)
					_spray(_bits, px(g.col, g.row), Art.ZAP, 5, 520.0, "spark", _u / 110.0)
					_spray(_bits, px(g.col, g.row), Art.paint(int(g.v)), 4, 560.0, "splinter", _u / 110.0)
				_flash_now(Art.ZAP.lightened(0.4), 0.5)
				_shake = maxf(_shake, 0.4)
			"tool":
				match String(ev.tool):
					"wild":
						_fx.cue("buy")
						_feel(Haptics.TAP)
						_show_banner(tr("SW_WILD"), tr("SW_WILD_LINE"), 0.7)
					"bomb":
						_fx.cue("fuse")
						_feel(Haptics.TAP)
						_show_banner(tr("SW_BOMB"), tr("SW_BOMB_LINE"), 0.7)
					"zap":
						_show_banner(tr("SW_ZAP"), tr("SW_ZAP_LINE"), 0.7)
				_kick(_acorn_l, 0.25, 0.3)
			"refused":
				_fx.cue("refused")
				var b: Control = _tool_buttons[{"wild": Sim.Tool.WILD, "bomb": Sim.Tool.BOMB, "zap": Sim.Tool.ZAP}[ev.tool]]
				Motion.shiver(b)
			"over":
				_feel(Haptics.LOSE)
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
		_pop(to + Vector2(0, 0.3), "+%s" % Record.grouped(int(m.v) * chain), Pal.SUN if chain > 1 else Art.paint(int(m.v)).lightened(0.45), big or chain >= 3)
		_merge_bits(m, chain)
		_fx.puff(px(to.x, to.y), Art.paint(int(m.v)), 6)
		if not Motion.reduce:
			_flashes.append({"id": m.id, "t": 0.0})
			_fx.ring(px(to.x, to.y), 0.75 * _u, Art.paint(int(m.v)).lightened(0.2))
		if big:
			_fx.sparkle(px(to.x, to.y), Color("fffaf0"))
			_fx.ring(px(to.x, to.y), 1.2 * _u, Art.GOLD)
	_launch_acorns(ev)
	_fx.cue("merge", minf(1.0 + 0.09 * (chain - 1), 1.6))
	# A merge is the common right move, the tap its drop held back; a chain
	# bumps once, at its second round.
	if not _answered:
		if chain == 1:
			if _by_hand:
				_feel(Haptics.TAP)
		else:
			_answered = true
			_feel(Haptics.BUMP)
	if not _drop_merged:
		_drop_merged = true
		_streak += 1
	if chain >= 2:
		_fx.cue("chain", minf(1.0 + 0.07 * (chain - 2), 1.5))
		_kick(_score_k, 0.3, 0.35)
		_shake = maxf(_shake, 0.15 + 0.05 * chain)
	if chain >= 3:
		_flash_now(Color("fffaf0"), minf(0.6, 0.25 + 0.08 * (chain - 3)))
		_spray(_air_bits, _in_air(_score_l, _score_l.size * 0.5), Pal.SUN, 4 + 2 * chain, 380.0, "star", 0.9, 0.2)
	_merge_words(ev)

## The acorns a merge earned fly up out of it and into the bank, a few at a
## time; the bank counts each as it lands.
func _launch_acorns(ev: Dictionary) -> void:
	var nuts: int = ev.acorns
	if nuts <= 0 or Motion.reduce:
		return
	var n := mini(nuts, 5)
	var to := _in_air(_acorn_icon, _acorn_icon.size * 0.5)
	var merges: Array = ev.merges
	for k in n:
		var m: Dictionary = merges[k % merges.size()]
		var from := _in_air(field, px(m.col, m.row) + _shake_off)
		var ctrl := from.lerp(to, 0.35) + Vector2(randf_range(-160.0, 160.0), -260.0)
		var value := nuts / n + (1 if k < nuts % n else 0)
		_flights.append({"from": from, "ctrl": ctrl, "to": to, "t": -0.12 - 0.07 * k, "value": value, "spin": randf_range(-6.0, 6.0),
			"first": k == 0, "total": nuts})
		_owed += value

## What one block's merge throws: splinters of the old number's paint and
## sparks; from 128 gold stars and a second ring; the newest biggest block
## a burst of stars in its own paint.
func _merge_bits(m: Dictionary, chain: int) -> void:
	var at := px(m.col, m.row)
	var v: int = m.v
	var took: int = (m.from as Array).size()
	var k := _u / 110.0
	_spray(_bits, at, Art.paint(v >> took), mini(5 + 3 * took + 2 * chain, 24), 380.0 + 50.0 * chain, "splinter", k)
	_spray(_bits, at, Color("fffaf0"), 3 + 2 * chain, 340.0 + 30.0 * chain, "spark", k)
	if v >= 128 or chain >= 3:
		_spray(_bits, at, Art.GOLD, 3 + chain, 520.0 + 30.0 * chain, "star", k * 0.8)
		_ring(_bits, at, _u * (1.3 + 0.15 * chain), Color(Art.paint(v).lightened(0.3), 0.8), 0.06)
	if v == _new_max:
		_new_max = 0
		_spray(_bits, at, Art.paint(v).lightened(0.2), 12, 760.0, "star", k)
		_spray(_bits, at, Color("fffaf0"), 8, 640.0, "spark", k * 1.2)
		_ring(_bits, at, _u * 2.2, Color(Art.GOLD, 0.85), 0.1)

## A loud merge's word over it, lettered bigger the louder it was, with the
## chain's count under it; drops that merged in a row add the combo.
func _merge_words(ev: Dictionary) -> void:
	var chain: int = ev.chain
	var merges: Array = ev.merges
	var took := 1
	for m: Dictionary in merges:
		took = maxi(took, (m.from as Array).size())
	var loud := chain + took - 1
	var word := ""
	var tier := 0
	for i in WORDS.size():
		if loud >= int(WORDS[i][0]):
			word = tr(WORDS[i][1])
			tier = WORDS.size() - 1 - i
			break
	var m0: Dictionary = merges[0]
	var spot := px(m0.col, m0.row) - Vector2(0, _u * 0.95)
	# clear of a new biggest block's number up top
	var low := field.size.y * (0.34 if _has_sticker("max") else 0.1)
	spot.x = field.size.x * 0.5
	# the whole stack (word, chain, combo) stands clear of the floor
	spot.y = clampf(spot.y, low, field.size.y * 0.55)
	var under := spot
	if word != "":
		_sticker(word, _in_air(field, spot), 64 + 10 * tier, 1.0 + 0.15 * tier, true, Color.WHITE, tier >= 2, "word")
		under = spot + Vector2(0, 74.0 + 10.0 * tier)
	if chain >= 2:
		_sticker(tr("SW_CHAIN") % chain, _in_air(field, under), 44, 1.1, false, Pal.SUN, false, "chain")
		under += Vector2(0, 64.0)
	if _streak >= 2:
		_sticker(tr("SW_COMBO") % _streak, _in_air(field, under), 40, 1.1, false, COMBO, false, "combo")
		_spray(_bits, px(m0.col, m0.row), COMBO, mini(2 * _streak, 12), 440.0, "spark", _u / 110.0)

func _has_sticker(id: String) -> bool:
	for st: Dictionary in _stickers:
		if String(st.id) == id:
			return true
	return false

## A stack pulled back from the line: a word and a sigh of sparks.
func _phew() -> void:
	var at := Vector2(field.size.x * 0.5, _origin.y + _u * 1.9)
	_sticker(tr("SW_PHEW"), _in_air(field, at), 68, 1.2, false, Color("7fd66a"), false, "phew")
	_spray(_bits, at, Color("b8f0a0"), 10, 420.0, "spark", _u / 110.0)
	_fx.cue("wild", 1.2, -4.0)

## The rewards' own clocks: the bits in both layers, the stickers, the
## flash, the combo's glow and the rain.
func _animate_rewards(delta: float) -> void:
	_step_bits(_bits, delta)
	_step_bits(_air_bits, delta)
	for st: Dictionary in _stickers:
		st.t += delta
	_stickers = _stickers.filter(func(st: Dictionary) -> bool: return st.t < st.life)
	_flash = maxf(0.0, _flash - delta * 2.4)
	var want := clampf((_streak - 2) / 4.0, 0.0, 1.0)
	_heat = move_toward(_heat, want, delta * (1.5 if want > _heat else 0.5))
	if _rain > 0.0:
		_rain -= delta
		if not Motion.reduce and randf() < delta * 30.0:
			var r := randf()
			var kind := "acorn" if r < 0.4 else ("star" if r < 0.55 else "confetti")
			_air_bits.append({"pos": Vector2(randf_range(0.0, _air.size.x), -40.0), "vel": Vector2(randf_range(-60.0, 60.0), randf_range(160.0, 300.0)),
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
			v.y += (800.0 if String(b.kind) == "confetti" else 1700.0) * delta
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
			"life": randf_range(0.55, 0.95) + (0.5 if kind == "confetti" or kind == "acorn" else 0.0), "kind": kind,
			"col": col, "size": size * randf_range(0.7, 1.25)})

## A ring swelling out of `at` to `radius` and fading.
func _ring(bits: Array, at: Vector2, radius: float, col: Color, delay := 0.0) -> void:
	if Motion.reduce:
		return
	bits.append({"pos": at, "vel": Vector2.ZERO, "rot": 0.0, "spin": 0.0, "t": -delay, "life": 0.45, "kind": "ring",
		"col": col, "size": radius})

## The shelf flashes `col`, `amount` at most.
func _flash_now(col: Color, amount: float) -> void:
	if Motion.reduce:
		return
	_flash = maxf(_flash, amount)
	_flash_col = col

## A word lettered at `at` in the air's pixels, each letter hopping in on
## its own, fitted to the shelf's width. `rainbow` letters it in the sticker
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

## A new biggest block: from 64 its number is lettered up top over a
## sunburst and its merge bursts (`_merge_bits`); from 256 it rings out, and
## from 2048 the shelf flashes gold and acorns and confetti rain.
func _on_new_max(v: int) -> void:
	if v < 64 or _milestones.has(v):
		return
	_milestones[v] = true
	_new_max = v
	var top := _in_air(field, Vector2(field.size.x * 0.5, field.size.y * 0.12))
	var gold := v >= 2048
	_sticker(Record.grouped(v) + "!", top, 104 if gold else (92 if v >= 256 else 80), 2.4 if gold else 1.5, true, Color.WHITE, true, "max")
	_sticker(tr("SW_2048_LINE") if v == 2048 else tr("SW_NEW_BLOCK"), top + Vector2(0, 86.0 if gold else 74.0), 40, 2.4 if gold else 1.5,
		false, Color("fffaf0"), false, "max_line")
	# a new biggest block is its own bump, even rounds into a chain
	_feel(Haptics.BUMP)
	if gold:
		_fx.cue("milestone")
		_flash_now(Art.GOLD, 0.8)
		_rain = maxf(_rain, 3.2)
		_confetti()
	elif v >= 256:
		_fx.cue("big")
		_flash_now(Art.paint(v).lightened(0.5), 0.35)

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
			_kick(_score_l, 0.14, 0.26)
		_shown_score = sim.score
		if not _beat_best and _best > 0 and sim.score > _best:
			_beat_best = true
			_kick(_best_l, 0.3, 0.4)
			_feel(Haptics.BUMP)
	if Motion.reduce or sim.score < _roll:
		_roll = sim.score
	else:
		_roll = move_toward(_roll, sim.score, maxf(delta * absf(sim.score - _roll) * 10.0, delta * 300.0))
	var shown := Record.grouped(int(_roll))
	if _score_l.text != shown:
		_score_l.text = shown
		_best_l.text = Record.grouped(maxi(_best, int(_roll)))
	var bank := maxi(0, sim.acorns - _owed)
	var nuts := str(bank)
	if _acorn_l.text != nuts:
		_acorn_l.text = nuts
	for tool: int in _tool_buttons:
		var b: Button = _tool_buttons[tool]
		var ok: bool = bank >= int(Sim.COSTS[tool]) and not sim.is_over()
		b.modulate.a = 1.0 if ok else 0.5
		# a tool the bank has just reached hops and twinkles
		if ok and _afford.has(tool) and not _afford[tool] and not Motion.reduce:
			_kick(b, 0.12, 0.3)
			_air_fx.sparkle(_in_air(b, b.size * Vector2(0.5, 0.35)), Pal.SUN)
		_afford[tool] = ok
	_next_view.queue_redraw()

# --- drawing ---

## The shelf: a wooden cabinet in a greenhouse. Its back is painted boards,
## one a column, grained and nailed; turned posts stand either side under a
## moulded crown, with ivy trailing down past them; the dashed line a stack
## must stay under runs below the spawn lane, and the cabinet stands on a
## plank held up by two brackets, a pot of seedlings at either end.
func _build_wall() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	# the room behind the shelf: a soft greenhouse light, with the panes' bars
	_quad(b, [Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)], [Color("cfe6dc"), Color("cfe6dc"), Color("e9dcc0"), Color("e9dcc0")])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for x in [s.x * 0.08, s.x * 0.92]:
		b.fan(Face.Builder.round_rect(Vector2(x - 5.0, 0), Vector2(10.0, s.y), 5.0), Color(1, 1, 0.96, 0.45))
	for y in [s.y * 0.3, s.y * 0.62]:
		b.fan(Face.Builder.round_rect(Vector2(0, y - 4.0), Vector2(s.x, 8.0), 4.0), Color(1, 1, 0.96, 0.35))
	# light falling in from the top left
	for k in 3:
		var x0 := s.x * (0.05 + 0.3 * k)
		_quad(b, [Vector2(x0, 0), Vector2(x0 + s.x * 0.12, 0), Vector2(x0 + s.x * 0.12 + s.y * 0.35, s.y), Vector2(x0 + s.y * 0.35, s.y)],
			[Color(1, 1, 0.9, 0.16), Color(1, 1, 0.9, 0.16), Color(1, 1, 0.9, 0.0), Color(1, 1, 0.9, 0.0)])
	var o := _origin
	var board := Vector2(Sim.COLS, Sim.ROWS + 1) * _u
	var foot := o.y + board.y
	# the cabinet's shadow on the glass, then its back, in boards
	b.fan(Face.Builder.round_rect(o + Vector2(-8, 4), board + Vector2(28, 10), 22.0), Color(0.25, 0.15, 0.05, 0.12))
	b.fan(Face.Builder.round_rect(o - Vector2(4, 4), board + Vector2(8, 4), 18.0), WALL)
	for c in Sim.COLS:
		var x := o.x + c * _u
		if c % 2 == 1:
			b.fan(PackedVector2Array([Vector2(x, o.y + _u), Vector2(x + _u, o.y + _u), Vector2(x + _u, foot), Vector2(x, foot)]), Color(WALL_DEEP, 0.35))
		if c > 0:
			# the groove between two boards: a shadow and a lit edge
			b.stroke(PackedVector2Array([Vector2(x, o.y + _u + 6), Vector2(x, foot - 4)]), 2.5, Color(WALL_DEEP.darkened(0.15), 0.7))
			b.stroke(PackedVector2Array([Vector2(x + 2.5, o.y + _u + 6), Vector2(x + 2.5, foot - 4)]), 1.5, Color(1, 1, 1, 0.45))
		# grain down the board, and a nail at its head and its foot
		for g in 2:
			var gx := x + _u * (0.3 + 0.4 * g) + rng.randf_range(-6.0, 6.0)
			var pts := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				pts.append(Vector2(gx + sin(t * PI * (2.0 + g) + c) * _u * 0.035, lerpf(o.y + _u + 10.0, foot - 8.0, t)))
			b.stroke(pts, 1.5, Color(WALL_DEEP.darkened(0.12), 0.35))
		for ny in [o.y + _u + 16.0, foot - 14.0]:
			b.disc(Vector2(x + _u * 0.5, ny), 3.5, Color(WALL_DEEP.darkened(0.3), 0.55))
			b.disc(Vector2(x + _u * 0.5 - 1.0, ny - 1.0), 1.5, Color(1, 1, 1, 0.4))
	# knots in the boards
	for i in 7:
		var p := o + Vector2(rng.randf() * board.x, _u + rng.randf() * (board.y - _u))
		b.ellipse(p, 8.0, 4.5, Color(WALL_DEEP.darkened(0.2), 0.35))
		b.ellipse(p, 4.0, 2.0, Color(WALL_DEEP.darkened(0.3), 0.35))
	# the spawn lane: paler, with the dashed line under it
	b.fan(Face.Builder.round_rect(o - Vector2(4, 4), Vector2(board.x + 8, _u + 4), 18.0), Color(LANE, 0.55))
	var y := o.y + _u
	b.stroke(PackedVector2Array([Vector2(o.x + 6.0, y), Vector2(o.x + board.x - 6.0, y)]), 2.0, Color(DANGER, 0.18))
	var x0 := o.x + 6.0
	while x0 < o.x + board.x - 6.0:
		b.fan(Face.Builder.round_rect(Vector2(x0, y - 3.0), Vector2(minf(22.0, o.x + board.x - 6.0 - x0), 6.0), 3.0), Color(DANGER, 0.5))
		x0 += 36.0
	# the posts either side, turned at the top, and the crown across them
	var pw := clampf(_u * 0.17, 16.0, 30.0)
	for side in [0, 1]:
		var px_ := o.x - 4.0 - pw if side == 0 else o.x + board.x + 4.0
		b.fan(Face.Builder.round_rect(Vector2(px_, o.y + 6.0), Vector2(pw, board.y - 6.0), pw * 0.4), SHELF_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(px_ + 2.0, o.y + 6.0), Vector2(pw - 5.0, board.y - 8.0), pw * 0.35), SHELF)
		b.stroke(PackedVector2Array([Vector2(px_ + pw * 0.35, o.y + 20.0), Vector2(px_ + pw * 0.35, foot - 12.0)]), 2.0, Color(1, 1, 1, 0.22))
		b.stroke(PackedVector2Array([Vector2(px_ + pw * 0.62, o.y + 40.0), Vector2(px_ + pw * 0.6, foot - 30.0)]), 1.5, Color(SHELF_DEEP, 0.6))
		for ry in [o.y + _u + 2.0, o.y + board.y * 0.55]:
			b.fan(Face.Builder.round_rect(Vector2(px_ - 2.0, ry - 5.0), Vector2(pw + 4.0, 10.0), 5.0), SHELF_DEEP)
			b.fan(Face.Builder.round_rect(Vector2(px_ - 1.0, ry - 5.0), Vector2(pw + 2.0, 6.0), 3.0), SHELF.lightened(0.12))
		# the finial, a wooden ball
		var fc := Vector2(px_ + pw * 0.5, o.y + 2.0)
		b.disc(fc + Vector2(0, 2), pw * 0.62, SHELF_DEEP)
		b.disc(fc, pw * 0.58, SHELF)
		b.disc(fc + Vector2(-pw * 0.18, -pw * 0.2), pw * 0.18, Color(1, 1, 1, 0.3))
	# ivy trailing down past the posts from the top corners
	for side in [0, 1]:
		var sx := -1.0 if side == 0 else 1.0
		var top := Vector2(o.x - 4.0 - pw * 0.5 if side == 0 else o.x + board.x + 4.0 + pw * 0.5, o.y + 8.0)
		var vine := Face.Builder.bezier3(top, top + Vector2(sx * _u * 0.35, _u * 0.9), top + Vector2(-sx * _u * 0.1, _u * 1.8), top + Vector2(sx * _u * 0.25, _u * 2.6), 22)
		b.stroke(vine, 3.0, Color("6f9c46"))
		for i in range(2, vine.size(), 3):
			var at: Vector2 = vine[i]
			var flip := 1.0 if (i / 3) % 2 == 0 else -1.0
			var leaf := at + Vector2(flip * _u * 0.09, _u * 0.02)
			var lr := _u * (0.09 + 0.02 * ((i * 7) % 3))
			b.ellipse(leaf, lr, lr * 0.7, Color("7fae52") if flip > 0 else Color("8dba58"))
			b.stroke(PackedVector2Array([at, leaf]), 1.5, Color("6f9c46"))
	# the crown, a moulded board over the top
	var crown := Vector2(o.x - pw - 14.0, o.y - 16.0)
	b.fan(Face.Builder.round_rect(crown + Vector2(0, 3), Vector2(board.x + 2.0 * pw + 28.0, 18.0), 8.0), SHELF_DEEP)
	b.fan(Face.Builder.round_rect(crown, Vector2(board.x + 2.0 * pw + 28.0, 14.0), 7.0), SHELF)
	b.fan(Face.Builder.round_rect(crown + Vector2(10, 3), Vector2(board.x + 2.0 * pw + 8.0, 3.0), 1.5), Color(1, 1, 1, 0.3))
	# the plank the shelf stands on, on two brackets
	for bx in [o.x + board.x * 0.18, o.x + board.x * 0.82]:
		var t := Vector2(bx, foot + 0.2 * _u)
		b.polygon(PackedVector2Array([t + Vector2(-_u * 0.08, 0), t + Vector2(_u * 0.08, 0), t + Vector2(_u * 0.05, _u * 0.18), t + Vector2(-_u * 0.05, _u * 0.18)]), SHELF_DEEP)
		b.polygon(PackedVector2Array([t + Vector2(-_u * 0.05, 0), t + Vector2(_u * 0.02, 0), t + Vector2(0, _u * 0.14), t + Vector2(-_u * 0.03, _u * 0.14)]), SHELF)
	b.fan(Face.Builder.round_rect(Vector2(o.x - 22, foot - 2), Vector2(board.x + 44, 0.3 * _u + 12), 12.0), SHELF_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(o.x - 22, foot - 4), Vector2(board.x + 44, 0.26 * _u), 12.0), SHELF)
	b.fan(Face.Builder.round_rect(Vector2(o.x - 12, foot), Vector2(board.x + 24, 5.0), 2.5), Color(1, 1, 1, 0.25))
	for g in 2:
		var gy := foot + 0.1 * _u + g * 0.08 * _u
		var pts := PackedVector2Array()
		for i in 17:
			var t := i / 16.0
			pts.append(Vector2(lerpf(o.x - 8.0, o.x + board.x + 8.0, t), gy + sin(t * PI * 3.0 + g) * 2.0))
		b.stroke(pts, 1.5, Color(SHELF_DEEP, 0.55))
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
	_draw_bunting(under)
	if not under.verts.is_empty():
		_live = under.mesh()
		field.draw_mesh(_live, null)
	field.draw_set_transform(_shake_off)
	# the blocks sliding into the ones they joined
	for j: Dictionary in _joins:
		var k: float = j.t / JOIN_T
		var p: Vector2 = (j.from as Vector2).lerp(j.to, k * k)
		var sc := lerpf(1.0, 0.6, k)
		# sucked in: stretched along the way it is drawn, thinned across it
		var along := Vector2(sc, sc)
		if not Motion.reduce:
			var d: Vector2 = (j.to as Vector2) - (j.from as Vector2)
			var st := 0.3 * sin(k * PI * 0.5)
			along = Vector2(sc * (1.0 + st), sc * (1.0 - st * 0.6)) if absf(d.x) > absf(d.y) else Vector2(sc * (1.0 - st * 0.6), sc * (1.0 + st))
		field.draw_mesh(Art.block(j.v, s), null, Transform2D(0.0, along, 0.0, px(p.x, p.y)), Color(1, 1, 1, 1.0 - k * 0.6))
	# the blocks on the shelf, bottom row first so a lip sits over the row under
	var order := _vis.keys()
	order.sort_custom(func(a, b) -> bool: return float(_vis[a].pos.y) < float(_vis[b].pos.y))
	for id in order:
		var vis: Dictionary = _vis[id]
		var sc := _block_scale(vis)
		var c := px(vis.pos.x, vis.pos.y)
		# squashed about its foot, so it stays standing on what is under it
		c.y += (1.0 - sc.y) * s * 0.5
		var hot: bool = _danger and sim.height(int(roundf(vis.pos.x))) >= Sim.ROWS - 1 and vis.pos.y >= Sim.ROWS - 2
		var tint := Color.WHITE
		if hot and not Motion.reduce:
			var beat := 0.5 + 0.5 * sin(_clock * 9.0)
			tint = Color(1.0, 1.0 - 0.18 * beat, 1.0 - 0.2 * beat)
			c.x += sin(_clock * 43.0 + float(id)) * 1.6
		field.draw_set_transform(c + _shake_off, 0.0, sc)
		field.draw_mesh(Art.block(vis.v, s), null, Transform2D.IDENTITY, tint)
		Art.number(field, font, Vector2.ZERO, vis.v, s)
		# a gilded block twinkles now and then, each on its own clock
		if Art.exp_of(int(vis.v)) >= 10 and not Motion.reduce:
			var tw := fmod(_clock + float(id) * 1.37, 2.6)
			if tw < 0.5:
				var k := sin(tw / 0.5 * PI)
				field.draw_mesh(Art.sparkle(s * 0.16), null, Transform2D(tw * 3.0, Vector2(k, k), 0.0, Vector2(-s * 0.3, -s * 0.28)))
	field.draw_set_transform(_shake_off)
	_draw_piece(font, s)
	# debris: knocked off and tumbling
	for d: Dictionary in _debris:
		var a := 1.0 - clampf((d.t - 1.0) / 0.6, 0.0, 1.0)
		field.draw_set_transform(d.pos + _shake_off, d.rot, Vector2.ONE)
		field.draw_mesh(Art.block(d.v, s), null, Transform2D.IDENTITY, Color(1, 1, 1, a))
		Art.number(field, font, Vector2.ZERO, d.v, s, a)
	field.draw_set_transform(Vector2.ZERO)
	var over := Face.Builder.new()
	_draw_flashes(over, s)
	_draw_streaks(over, s)
	_draw_bolts(over)
	_draw_rays(over)
	if _heat > 0.01:
		_draw_heat(over)
	_draw_bits(over, _bits)
	if not over.verts.is_empty():
		var m := over.mesh()
		field.set_meta("over", m)
		field.draw_mesh(m, null)
	if _flash > 0.0:
		field.draw_rect(Rect2(Vector2.ZERO, field.size), Color(_flash_col, _flash * 0.5))
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
	var c := px(_px, float(pc.y))
	var wob := 0.0
	var sc := Vector2.ONE
	if not Motion.reduce:
		if pc.hold > 0.0:
			var k := 1.0 - float(pc.hold) / Sim.HOLD
			sc = Vector2.ONE * Motion.back_out(clampf(k * 1.4, 0.0, 1.0))
		elif pc.dropping:
			sc = Vector2(0.88, 1.14)
		else:
			wob = sin(_clock * 3.0) * 0.04
		# it leans into a move, and squeezes a little across its speed
		wob += clampf(-_pv * LEAN, -0.24, 0.24)
		sc *= Vector2(1.0 + minf(absf(_pv) * 0.012, 0.1), 1.0 - minf(absf(_pv) * 0.008, 0.07))
	field.draw_mesh(Art.block(v, s), null, Transform2D(wob, sc, 0.0, c))
	if v > 0:
		field.draw_set_transform(c + _shake_off, wob, sc)
		Art.number(field, font, Vector2.ZERO, v, s)
		field.draw_set_transform(_shake_off)

## How a block on the shelf is scaled this frame: the bump when it grows,
## the squash when it lands (a damped spring about its foot) and the dip
## when a block lands on its column.
func _block_scale(vis: Dictionary) -> Vector2:
	if Motion.reduce:
		return Vector2.ONE
	var sc := Vector2.ONE
	if vis.bump >= 0.0:
		# a gulp: wide first, then tall, then home
		var k := clampf(vis.bump / 0.3, 0.0, 1.0)
		var w := sin(k * PI) * (1.0 - k * 0.4)
		sc *= Vector2(1.0 + 0.2 * w - 0.08 * sin(k * TAU), 1.0 + 0.14 * w + 0.08 * sin(k * TAU))
	if vis.squash >= 0.0 and vis.squash < 0.6:
		var t: float = vis.squash
		var q := float(vis.amt) * exp(-t * 11.0) * cos(t * 30.0)
		sc *= Vector2(1.0 + q * 0.75, 1.0 - q)
	if vis.dip >= 0.0 and vis.dip < 0.2:
		var q := float(vis.dip_amt) * sin(vis.dip / 0.2 * PI)
		sc *= Vector2(1.0 + q * 0.6, 1.0 - q)
	return sc

## A merged block flashes white as it takes the other in.
func _draw_flashes(b: Face.Builder, s: float) -> void:
	for f: Dictionary in _flashes:
		if not _vis.has(f.id):
			continue
		var vis: Dictionary = _vis[f.id]
		var sc := _block_scale(vis)
		var c := px(vis.pos.x, vis.pos.y) + _shake_off
		c.y += (1.0 - sc.y) * s * 0.5
		var size := Vector2(s, s * 0.91) * sc
		var a := 0.75 * (1.0 - float(f.t) / 0.25)
		b.fan(Face.Builder.round_rect(c - Vector2(size.x * 0.5, s * 0.5 * sc.y), size, s * 0.16), Color(1, 1, 0.95, a))

## Speed lines over a block let go, and the bomb's fuse spitting sparks.
func _draw_streaks(b: Face.Builder, s: float) -> void:
	if sim.piece.is_empty() or Motion.reduce:
		return
	var pc: Dictionary = sim.piece
	var c := px(_px, float(pc.y)) + _shake_off
	if pc.dropping:
		for k in 3:
			var x := c.x + (k - 1) * s * 0.32
			var top := c.y - s * (0.7 + 0.5 * _hash(k, float(pc.id)))
			var run := s * (0.9 + 0.6 * _hash(k + 3, float(pc.id)))
			_quad(b, [Vector2(x - 3, top - run), Vector2(x + 3, top - run), Vector2(x + 3, top), Vector2(x - 3, top)],
				[Color(LANE, 0.0), Color(LANE, 0.0), Color(LANE, 0.7), Color(LANE, 0.7)])
	if int(pc.kind) == Sim.Piece.BOMB:
		var tip := c + Vector2(s * 0.2, -s * 0.38)
		for k in 5:
			var ph := fmod(_clock * 3.0 + k * 0.2, 1.0)
			var dir := Vector2.from_angle(-PI * 0.5 + (_hash(k, floorf(_clock * 3.0 + k * 0.2)) - 0.5) * 2.4)
			b.disc(tip + dir * ph * s * 0.3, s * 0.035 * (1.0 - ph), Color(Art.SPARK, 1.0 - ph))

## Bunting strung across the top of the shelf, swaying a little.
func _draw_bunting(b: Face.Builder) -> void:
	var board := Vector2(Sim.COLS, Sim.ROWS + 1) * _u
	var a := _origin + Vector2(-8.0, 4.0)
	var z := _origin + Vector2(board.x + 8.0, 4.0)
	var sag := _u * 0.22
	var pts := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		pts.append(a.lerp(z, t) + Vector2(0, sag * 4.0 * t * (1.0 - t)))
	b.stroke(pts, 3.0, Color(Art.WOOD_DEEP, 0.8))
	var n := 11
	var w := _u * 0.2
	for i in n:
		var t := (i + 0.5) / n
		var at := a.lerp(z, t) + Vector2(0, sag * 4.0 * t * (1.0 - t))
		var sway := 0.0 if Motion.reduce else sin(_clock * 1.7 + i * 0.9) * 0.12
		var tip := at + Vector2.from_angle(PI * 0.5 + sway) * w * 1.25
		var col: Color = BUNTING[i % BUNTING.size()]
		b.polygon(PackedVector2Array([at + Vector2(-w * 0.5, 0), at + Vector2(w * 0.5, 0), tip]), col)
		b.polygon(PackedVector2Array([at + Vector2(-w * 0.5, 0), at + Vector2(-w * 0.1, 0), tip]), Color(col.darkened(0.12), 0.9))

## The acorns in the air, over everything.
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
	# the acorns' trails: a fading golden comet behind each
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
			b.disc(tp, (7.0 - j) * 2.6, Color(Art.GOLD.lightened(0.2), 0.1 * (7 - j)))
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
		_air.draw_mesh(Art.acorn(52.0), null, Transform2D(float(f.spin) * f.t, Vector2(sc, sc), 0.0, p))
	_draw_stickers(font)

## The warm glow a combo of merging drops lights round the shelf's edge,
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
			"splinter":
				Art.splinter(b, at, 13.0 * sz, rot, col)
			"confetti":
				Art.petal(b, at, 11.0 * sz, 6.0 * sz * absf(cos(bit.t * 5.0 + rot)) + 1.0, rot, col)
			"star":
				Art.star(b, at, 14.0 * sz * (0.6 + 0.4 * a), col, rot)
			"spark":
				Art.glint(b, at, 22.0 * sz * a, rot, Color(col, col.a))
			"acorn":
				Art.acorn_bit(b, at, 30.0 * sz, sin(rot) * 0.6, a)
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
	# a new next block drops into the plate and settles
	var k := 1.0 if Motion.reduce else clampf(_next_t / 0.4, 0.0, 1.0)
	var sc := Motion.back_out(k)
	c.y -= (1.0 - minf(1.0, k * 1.6)) * 30.0
	_next_view.draw_set_transform(c, 0.0, Vector2(sc, sc))
	_next_view.draw_mesh(Art.block(v, s), null, Transform2D.IDENTITY)
	Art.number(_next_view, Art.font(), Vector2.ZERO, v, s)
	_next_view.draw_set_transform(Vector2.ZERO)

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
	if _offer_chance():
		return
	var better := Record.add(GAME, sim.score, sim.max_v, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.max_v,
		"seconds": secs, "drops": sim.drops, "merges": sim.merges, "chain": sim.best_chain,
		"tools": sim.tools_used, "best": better})
	Ads.note_finished()
	_fx.cue("topple")
	_show_banner(tr("SW_TOPPLED"), "", 1.0)
	_shake = 1.0
	for id in _vis.keys():
		var vis: Dictionary = _vis[id]
		_fling(int(vis.v), vis.pos)
		_spray(_bits, px(vis.pos.x, vis.pos.y), Art.paint(int(vis.v)), 3, 600.0, "splinter", _u / 110.0)
	_vis.clear()
	_streak = 0
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
	# the air (its rain and bursts) stays over the card
	move_child(_air, get_child_count() - 1)
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
		var fall := clampf((since - 0.25) / 0.3, 0.0, 1.0)
		var land := 1.0 if Motion.reduce else fall * fall
		var bob := sin(t * 2.2) * 5.0
		# it lands on the two with a squash that springs back, about its foot
		var sq := Vector2.ONE
		var after := since - 0.55
		if not Motion.reduce and after > 0.0 and after < 0.8:
			var q := 0.22 * exp(-after * 8.0) * cos(after * 26.0)
			sq = Vector2(1.0 + q * 0.75, 1.0 - q)
		var top := mid + Vector2(0, -s * 1.5 - (1.0 - land) * 260.0 + bob + (1.0 - sq.y) * s * 0.55)
		# a sunburst turns behind it once it has landed, gold from 2048
		var glow := 1.0 if Motion.reduce else clampf((since - 0.55) / 0.3, 0.0, 1.0)
		if glow > 0.0:
			var rb := Face.Builder.new()
			var rc := Art.GOLD if biggest >= 2048 else Art.paint(biggest).lightened(0.35)
			var rr := s * 1.6 * Motion.back_out(glow)
			rb.disc(top, rr * 0.55, Color(Color("fff4c2"), 0.45))
			Art.sunrays(rb, top, rr * 0.2, rr, 14, t * 0.5, Color(rc, 0.55))
			Art.sunrays(rb, top, rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
			var rm := rb.mesh()
			seat.set_meta("rays", rm)
			seat.draw_mesh(rm, null)
		seat.draw_set_transform(top, sin(t * 1.5) * 0.04, sq)
		seat.draw_mesh(Art.block(biggest, s * 1.1), null, Transform2D.IDENTITY)
		Art.number(seat, font, Vector2.ZERO, biggest, s * 1.1, 1.0 if since > 0.3 or Motion.reduce else 0.0)
		seat.draw_set_transform(Vector2.ZERO))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "SW_END_CARD"
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
	for pair in [[Record.grouped(sim.max_v), "SW_STAT_BLOCK"], [str(sim.merges), "SW_STAT_MERGES"], [str(sim.best_chain), "SW_STAT_CHAIN"]]:
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

## The end card's score runs up from nothing to what the game made, with
## a burst when it gets there.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 1.1, 0.0, 1.0)
	var shown := int(sim.score * (1.0 - pow(1.0 - k, 3.0)))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
		if int(_clock * 20.0) % 2 == 0:
			_fx.cue("move", 0.9 + 0.8 * k, -10.0)
	if k >= 1.0:
		_end_score.pivot_offset = _end_score.size * 0.5
		_kick(_end_score, 0.25, 0.4)
		var at := _in_air(_end_score, _end_score.size * 0.5)
		_spray(_air_bits, at, Art.GOLD, 14, 620.0, "star", 1.1)
		_spray(_air_bits, at, Color("fffaf0"), 8, 480.0, "spark", 1.1)
		_spray(_air_bits, at, Art.ACORN, 6, 520.0, "acorn", 0.8)
		_ring(_air_bits, at, 220.0, Color(Art.GOLD, 0.9))
		_end_score = null

func _celebrate(better: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var grand: bool = sim.max_v >= 2048
	if better or grand:
		_rain = 3.5
	var fx := Fx2D.new()
	_end.add_child(fx)
	var mid := size * 0.5
	var puffs := 14 if better else (8 if grand else 4)
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
	_ask()

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
	card.declined.connect(_topple)
	add_child(card)
	return true
