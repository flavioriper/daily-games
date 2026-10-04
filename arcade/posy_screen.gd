extends Control

## Posy: the eighth game on the Arcade tab, a swap-three garden (spec
## docs/superpowers/specs/2026-09-27-arcade-posy-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the day and the score, the day's goals and the moves left, the bed
## in a pale wooden frame with hedges round it, and under it the four tools
## with what is left of each.
##
## Play: drag a tile onto a neighbour (or tap one, then the other) to swap
## them; a swap that lines up three or more (or a square of four) is taken.
## Tap a special to set it off, for a move. A tap while the bed is playing
## something out hurries it along. The game is
## arcade/posy_sim.gd, which resolves a move at once and leaves every
## cascade step as an event; this screen plays them in order off a queue,
## keeping its own picture of where every tile is, so the bed on screen
## runs behind the sim's until the queue is empty.
##
## Drawing: the bed is one still mesh built on resize; every tile is one
## cached mesh moved by the transform; the glows, beams and sparkles are one
## live mesh under the tiles and one over them.

signal closed

const Sim = preload("res://arcade/posy_sim.gd")
const Art = preload("res://arcade/posy_art.gd")
const Record = preload("res://arcade/arcade_record.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
## What the phone knocks for (docs/agents/haptics.md). A move plays out by
## itself, a cascade step at a time, and `select`, `swap`, `goal` and
## `convert` are shared or are not the hand's, so only the end card's cue is
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

const GAME := "posy"
const MARGIN := 40
const GAP := 20
const HUD_H := 130.0
const TOOLS_H := 150.0
const FRAME := 18
const BACKDROP_BLEED := 90.0
## A swap's slide, and the pull a tile falls with (cells a second squared)
## from this pace.
const SWAP_T := 0.16
const SLIDE_V := 8.0
const GRAVITY := 60.0
const FALL_V0 := 4.0
## How long a picked tile takes to go, and a step's wait with a blast in it.
const PICK_T := 0.24
const BLAST_T := 0.3
## A bee's flight from its tile to its mark.
const BEE_T := 0.3
## How much faster everything plays while a tap hurries it.
const HURRY := 2.6
## How far a drag has to go, in cells, before it is a swap.
const DRAG := 0.32
## Seconds without a move before the bed shows one.
const HINT_AFTER := 5.0
const FLIGHT_T := 0.55
const CONFETTI := [Color("e8453c"), Color("f6c53d"), Color("3fa3ea"), Color("5dbb4a"), Color("9b52c4")]
## The words a long cascade earns, by its step.
const WORDS := {3: "PS_WORD_1", 5: "PS_WORD_2", 7: "PS_WORD_3", 9: "PS_WORD_4"}
## What a special says when it is made.
const MADE_WORDS := {Sim.Sp.ROW: "PS_MADE_BREEZE", Sim.Sp.COL: "PS_MADE_BREEZE", Sim.Sp.BOMB: "PS_MADE_BOMB", Sim.Sp.RAINBOW: "PS_MADE_RAINBOW", Sim.Sp.BEE: "PS_MADE_BEE"}
## The stickers' letters, cycled for the big words.
const STICKER_COLS := [Color("ff6f61"), Color("ffb03b"), Color("ffd84d"), Color("7fd66a"), Color("5cb8ff"), Color("b77be6")]
## The most bits (petals, sparks, stars) alive at once, in each layer.
const MAX_BITS := 420
## A star from the moves plate to each tile the day's end turns: the gap
## between two, and how long each flies.
const BLOOM_STEP := 0.08
const BLOOM_FLIGHT := 0.42

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
## The tutorial card: the top bar's ?, the settings' How to play and the
## first play (ui/hud/screen_tutor.gd).
var tutor: RefCounted
var field: Control
var _fx: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _frame: PanelContainer
var _hedge: Control
var _day_l: Label
var _score_l: Label
var _moves_l: Label
var _moves_plate: Control
var _goal_plates: Array = []
var _tool_buttons := {}
var _badges := {}
var _banner: Label
var _sub: Label
var _sub_pill: Control
var _banner_tw: Tween
var _end: Control
var _seat: Control
var _air: Control
var _air_fx: Node2D
var _started_at := 0
var _best := 0
var _roll := 0.0
var _beat_best := false
var _clock := 0.0
## Pixels a cell, and the bed's top-left in `field`.
var _u := 100.0
var _origin := Vector2.ZERO
var _bed: ArrayMesh
var _live: ArrayMesh
var _live_over: ArrayMesh
var _hedge_mesh: ArrayMesh
var _hedge_rect := Rect2()
## The screen's own picture of the bed, which runs behind the sim's while
## the queue plays: id -> {pos: Vector2 (column, row, in cells), to: Vector2i,
## k, sp, lit, vel, hold, pop, squash, amt, bump, glow, wig}.
var _tiles := {}
## Tiles being picked: {k, sp, pos, into (Vector2 or INF), t}.
var _dying: Array = []
## Breezes, bombs and rainbows going off: {kind, cell, t, ...}.
var _beams: Array = []
## Numbers rising off a pick: {pos (px), text, t, col, big}.
var _pops: Array = []
## Tiles flying up to their goal: {k, from, ctrl, to, t, goal}.
var _flights: Array = []
## Events waiting their turn, the seconds before the next, and whether the
## next waits for the bed to be still as well.
var _queue: Array = []
var _wait := 0.0
var _settle := false
## What the paper row shows: it follows the queue, not the sim.
var _shown_goals: Array = []
var _shown_moves := 0
var _shown_day := 1
var _shown_score := 0
## Goal counts still in the air, per goal index.
var _owed := {}
var _shake := 0.0
var _shake_off := Vector2.ZERO
## The finger: where it went down and the tile under it.
var _press := Vector2i(-1, -1)
var _press_at := Vector2.ZERO
var _selected := Vector2i(-1, -1)
var _armed := -1
var _swap_a := Vector2i(-1, -1)
var _idle := 0.0
var _hint: Array = []
var _glints: Array = []
var _glint_wait := 1.5
var _over_said := false
## Petals, leaves, sparks, stars and rings flung about, in the field's
## pixels and in the air's: {pos, vel, rot, spin, t, life, kind, col, size}.
## A bit whose `t` is below zero is still waiting to be thrown.
var _bits: Array = []
var _air_bits: Array = []
## Words lettered over everything, each letter hopping in on its own:
## {text, at (air px), t, life, size, rainbow, col, rays, tilt, id}.
var _stickers: Array = []
## Sunbursts behind a special just made: {pos (cells), t, col}.
var _bursts: Array = []
## A flash over the whole bed, and the glow a long cascade builds up
## round its edges.
var _flash := 0.0
var _flash_col := Color.WHITE
var _heat := 0.0
## The stars a day's end hands out: {n, t, at (air px), said}.
var _stars := {}
## Seconds of petals still to rain after a day is done.
var _rain := 0.0
var _day_moves := 20
var _blooming := false
## Goals whose completion has been cheered on the plate: index -> seconds.
var _goal_cheer := {}
## Tools given as a gift still in the air, so the badge waits for them.
var _gift_owed := {}
var _air_live: ArrayMesh
var _seat_mesh: ArrayMesh
var _end_score: Label
var _end_at := 0.0
## The bed's ground as the queue has it: cell -> {block, hp, weed, hit, grow}
## (`hit` and `grow` seconds since a knock and since it came in, -1 at
## rest). Changes a bee is still flying to wait in `_ground_later`.
var _ground := {}
var _ground_later: Array = []
## The offer of more moves, while it is up.
var _offer: Control
var _hurry := false
## The knock this frame asked for (`_feel`), or -1.
var _knock := -1
## A move of the hand's whose first tiles are yet to be picked: its knock
## lands with them. `_by_hand` while what plays out is the hand's (not the
## day's bloom or a booster's); `_bumped` once the move has had its bump.
var _pending := false
var _by_hand := false
var _bumped := false

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
	tutor = ScreenTutor.new(self, puzzle_id(), "Posy")
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	_ask(false)

# --- building ---

func _build() -> void:
	var page := ColorRect.new()
	page.color = Color("f6eedb")
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_backdrop = Vistas.board_plate(GAME, Pal.LEAF_DEEP)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_backdrop)
	_hedge = Control.new()
	_hedge.name = "Hedge"
	_hedge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hedge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hedge.draw.connect(_draw_hedge)
	add_child(_hedge)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Posy", tr("PS_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())

	_frame = PanelContainer.new()
	_frame.name = "Frame"
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Art.BOARD
	box.set_corner_radius_all(40)
	box.border_color = Color("fbf3e2")
	box.set_border_width_all(8)
	box.set_content_margin_all(FRAME)
	box.shadow_color = Color(0.25, 0.16, 0.05, 0.22)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 8)
	_frame.add_theme_stylebox_override("panel", box)
	_frame.resized.connect(func() -> void: _hedge.queue_redraw())
	# the frame hugs the square bed, centred in whatever room the column
	# leaves it
	var room := Control.new()
	room.name = "Room"
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.resized.connect(func() -> void:
		var side := minf(room.size.x, room.size.y)
		_frame.size = Vector2(room.size.x, side)
		_frame.position = Vector2(0, floorf((room.size.y - side) * 0.5)))
	room.add_child(_frame)
	col.add_child(room)
	field = Control.new()
	field.name = "Field"
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.resized.connect(_layout_field)
	field.gui_input.connect(_on_field_input)
	_frame.add_child(field)
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
	_banner.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.1, 0.6))
	_banner.add_theme_constant_override("outline_size", 16)
	over.add_child(_banner)
	_sub_pill = PanelContainer.new()
	_sub_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := CozyTheme.lifted(Color("fffaf0", 0.96), 34, 18)
	pill.content_margin_left = 30
	pill.content_margin_right = 30
	_sub_pill.add_theme_stylebox_override("panel", pill)
	_sub_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	over.add_child(_sub_pill)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetBody"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Art.INK)
	_sub_pill.add_child(_sub)
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

func _paper() -> PanelContainer:
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 30, 8))
	return plate

func _icon(painter: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: painter.call(c))
	c.resized.connect(c.queue_redraw)
	return c

## The day and the score, the goals, and the moves left, as the mock has
## them: one paper plate each.
func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 12)
	var day := _paper()
	day.size_flags_stretch_ratio = 1.55
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	day.add_child(line)
	var sprout := _icon(func(ci: Control) -> void:
		ci.draw_mesh(Art.sprout(minf(ci.size.x, ci.size.y) * 0.95), null, Transform2D(0.0, ci.size * 0.5)))
	sprout.custom_minimum_size = Vector2(56, 70)
	line.add_child(sprout)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -6)
	line.add_child(words)
	_day_l = Label.new()
	_day_l.theme_type_variation = "SheetTitle"
	words.add_child(_day_l)
	_score_l = Label.new()
	_score_l.theme_type_variation = "MenuKicker"
	words.add_child(_score_l)
	row.add_child(day)
	for i in 3:
		var plate := _paper()
		plate.size_flags_stretch_ratio = 0.8
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", -4)
		plate.add_child(col)
		var idx := i
		var pic := _icon(func(ci: Control) -> void: _draw_goal_icon(ci, idx))
		pic.custom_minimum_size = Vector2(0, 58)
		col.add_child(pic)
		var count := Label.new()
		count.theme_type_variation = "MenuKicker"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(count)
		row.add_child(plate)
		_goal_plates.append({"plate": plate, "pic": pic, "count": count})
	_moves_plate = _paper()
	_moves_plate.size_flags_stretch_ratio = 0.95
	var mc := VBoxContainer.new()
	mc.alignment = BoxContainer.ALIGNMENT_CENTER
	mc.add_theme_constant_override("separation", -6)
	_moves_plate.add_child(mc)
	var kicker := Label.new()
	kicker.text = "PS_MOVES"
	kicker.theme_type_variation = "MenuKicker"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mc.add_child(kicker)
	_moves_l = Label.new()
	_moves_l.theme_type_variation = "SheetTitle"
	_moves_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mc.add_child(_moves_l)
	row.add_child(_moves_plate)
	return row

func _draw_goal_icon(ci: Control, i: int) -> void:
	if i >= _shown_goals.size():
		return
	var g: Dictionary = _shown_goals[i]
	var s := minf(ci.size.y, ci.size.x) * 0.95
	var c := ci.size * 0.5
	ci.draw_mesh(Art.tile(int(g.k), s), null, Transform2D(0.0, c))
	if int(g.got) - int(_owed.get(i, 0)) >= int(g.need):
		# done: a green seal with a tick, stamped on
		var since := float(_goal_cheer.get(i, 1.0))
		var sc := 1.0 if Motion.reduce else lerpf(2.4, 1.0, Motion.back_out(clampf(since / 0.3, 0.0, 1.0)))
		var at := c + Vector2(s * 0.34, s * 0.3)
		ci.draw_set_transform(at, (1.0 - clampf(since / 0.3, 0.0, 1.0)) * -0.6, Vector2(sc, sc))
		ci.draw_circle(Vector2(0, 2), s * 0.23, Color(0.1, 0.25, 0.05, 0.3))
		ci.draw_circle(Vector2.ZERO, s * 0.23, Art.LEAF_DEEP)
		ci.draw_arc(Vector2.ZERO, s * 0.19, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 2.0)
		ci.draw_polyline(PackedVector2Array([Vector2(-s * 0.1, 0), Vector2(-s * 0.02, s * 0.08), Vector2(s * 0.11, -s * 0.08)]), Color("fffaf0"), maxf(2.0, s * 0.06))
		ci.draw_set_transform(Vector2.ZERO)

## The four tools, each a paper chip with its picture and a badge of how
## many are left.
func _build_tools() -> Control:
	var row := HBoxContainer.new()
	row.name = "Tools"
	row.custom_minimum_size.y = TOOLS_H
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for tool in [Sim.Tool.TROWEL, Sim.Tool.SWAP, Sim.Tool.BOMB, Sim.Tool.RAINBOW]:
		row.add_child(_tool_chip(tool))
	return row

func _tool_chip(tool: int) -> Control:
	var b := Button.new()
	b.name = "Tool_" + Sim.TOOL_KEYS[tool]
	b.custom_minimum_size = Vector2(170, TOOLS_H - 14)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.focus_mode = Control.FOCUS_NONE
	_style_chip(b, false)
	var pic := _icon(func(ci: Control) -> void:
		var s := minf(ci.size.y, ci.size.x) * 0.72
		ci.draw_mesh(Art.tool_icon(Sim.TOOL_KEYS[tool], s), null, Transform2D(0.0, ci.size * 0.5)))
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(pic)
	var badge := _icon(func(ci: Control) -> void: _draw_badge(ci, tool))
	badge.size = Vector2(56, 56)
	badge.position = Vector2(170 - 40, -18)
	b.add_child(badge)
	_badges[tool] = badge
	b.pressed.connect(_on_tool.bind(tool))
	_tool_buttons[tool] = b
	return b

func _draw_badge(ci: Control, tool: int) -> void:
	if sim == null:
		return
	var n := int(sim.tools.get(tool, 0)) - int(_gift_owed.get(tool, 0))
	var c := ci.size * 0.5
	var r := ci.size.x * 0.44
	ci.draw_circle(c + Vector2(0, 3), r, Color(0.1, 0.2, 0.35, 0.25))
	ci.draw_circle(c, r, Art.BADGE if n > 0 else Color("a9a298"))
	ci.draw_arc(c, r - 2.0, 0.0, TAU, 32, Color("fffaf0"), 4.0)
	var font := get_theme_font("font", "MenuKicker")
	var fs := 30
	var text := str(n)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fffaf0"))

## A tool chip's paper; an armed one is lit in the sun's colour.
func _style_chip(b: Button, lit: bool) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill := Color("fbe3a0") if lit else (Color("fcf7ef") if st != "pressed" else Color("f1e6d2"))
		var sb := CozyTheme.lifted(fill, 34, 8)
		if lit:
			sb.border_color = Color("e0a92e")
			sb.set_border_width_all(4)
		b.add_theme_stylebox_override(st, sb)

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The bed is COLS by ROWS cells, scaled to the room and centred.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_u = floorf(minf((s.x - 16.0) / Sim.COLS, (s.y - 16.0) / Sim.ROWS))
	var board := Vector2(Sim.COLS, Sim.ROWS) * _u
	_origin = Vector2(floorf((s.x - board.x) * 0.5), floorf((s.y - board.y) * 0.5))
	_bed = _build_bed()
	var box: Control = _banner.get_meta("box")
	box.position = Vector2(24, s.y * 0.32)
	box.size = Vector2(s.x - 48, 0)
	field.queue_redraw()

## The centre of a cell, in the field's pixels (fractions allowed).
func px(c: float, r: float) -> Vector2:
	return _origin + Vector2((c + 0.5) * _u, (r + 0.5) * _u)

func cell_at(at: Vector2) -> Vector2i:
	var f := (at - _origin) / _u
	var cell := Vector2i(floori(f.x), floori(f.y))
	if cell.x < 0 or cell.x >= Sim.COLS or cell.y < 0 or cell.y >= Sim.ROWS:
		return Vector2i(-1, -1)
	return cell

# --- the game ---

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	_seat = null
	sim = Sim.new()
	Boosters.apply(GAME, sim, _boosts)
	_boosted = not _boosts.is_empty()
	_chance_used = false
	_run_gold = 0
	_tiles.clear()
	_dying.clear()
	_beams.clear()
	_pops.clear()
	_flights.clear()
	_queue.clear()
	_owed.clear()
	_wait = 0.0
	_settle = false
	_shake = 0.0
	_roll = 0.0
	_shown_score = 0
	_beat_best = false
	_press = Vector2i(-1, -1)
	_selected = Vector2i(-1, -1)
	_armed = -1
	_swap_a = Vector2i(-1, -1)
	_idle = 0.0
	_hint = []
	_glints.clear()
	_over_said = false
	_bits.clear()
	_air_bits.clear()
	_stickers.clear()
	_bursts.clear()
	_flash = 0.0
	_heat = 0.0
	_stars = {}
	_rain = 0.0
	_blooming = false
	_goal_cheer.clear()
	_gift_owed.clear()
	_end_score = null
	_ground.clear()
	_ground_later.clear()
	_hurry = false
	_knock = -1
	_pending = false
	_by_hand = false
	_bumped = false
	if _offer != null:
		_offer.queue_free()
		_offer = null
	for tool: int in _tool_buttons:
		_style_chip(_tool_buttons[tool], false)
	_best = Record.best(GAME)
	_started_at = Time.get_ticks_msec()
	_refresh_hud()
	top_bar.refresh(self)
	_fx.cue("start")
	_take_events()
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
	_clock += delta
	if _hurry and not busy():
		_hurry = false
	var d := delta * (HURRY if _hurry else 1.0)
	_animate(d)
	_run_queue(d)
	_refresh_hud(delta)
	_knock_now()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	field.queue_redraw()
	if _air_busy():
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

static func _all_met(goals: Array) -> bool:
	for g: Dictionary in goals:
		if int(g.got) < int(g.need):
			return false
	return true

## The sim's new events join the back of the queue.
func _take_events() -> void:
	_queue.append_array(sim.events)
	sim.events.clear()

## Whether the bed is still playing something out: the queue, a tile moving.
func busy() -> bool:
	return not _queue.is_empty() or _wait > 0.0 or _moving()

func _moving() -> bool:
	for id in _tiles:
		var t: Dictionary = _tiles[id]
		if float(t.hold) > 0.0 or t.pos != Vector2(t.to) or not (t.turn as Dictionary).is_empty():
			return true
	return false

func _run_queue(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		return
	if _settle and _moving():
		return
	_settle = false
	while not _queue.is_empty() and _wait <= 0.0 and not _settle:
		_apply(_queue.pop_front())

func _new_tile(pos: Vector2, to: Vector2i, k: int, sp: int) -> Dictionary:
	return {"pos": pos, "to": to, "k": k, "sp": sp, "lit": false, "vel": 0.0, "hold": 0.0, "pop": -1.0,
		"squash": -1.0, "amt": 0.0, "bump": -1.0, "glow": -1.0, "wig": -1.0, "turn": {}}

## Whether the air layer has anything to draw this frame.
func _air_busy() -> bool:
	return not (_flights.is_empty() and _air_bits.is_empty() and _stickers.is_empty() and _stars.is_empty() and _rain <= 0.0)

func _animate(delta: float) -> void:
	for id in _tiles:
		var t: Dictionary = _tiles[id]
		var want := Vector2(t.to)
		if float(t.hold) > 0.0:
			t.hold = float(t.hold) - delta
		elif Motion.reduce:
			t.pos = want
		elif t.pos.y < want.y - 0.001 and absf(t.pos.x - want.x) < 0.001:
			t.vel = maxf(float(t.vel), FALL_V0) + GRAVITY * delta
			t.pos.y = minf(want.y, t.pos.y + float(t.vel) * delta)
			if t.pos.y >= want.y:
				_squash(t, clampf(float(t.vel) * 0.01, 0.05, 0.14))
				t.vel = 0.0
		elif t.pos != want:
			t.pos = t.pos.move_toward(want, SLIDE_V * delta)
			if t.pos == want:
				_squash(t, 0.05)
		for key in ["squash", "bump", "pop", "glow", "wig"]:
			if float(t[key]) >= 0.0:
				t[key] = float(t[key]) + delta
		if float(t.wig) > 0.8:
			t.wig = -1.0
		if not (t.turn as Dictionary).is_empty():
			t.turn.wait = float(t.turn.wait) - delta
			if float(t.turn.wait) <= 0.0:
				_turn_now(t)
	for d: Dictionary in _dying:
		d.t += delta
	_dying = _dying.filter(func(d: Dictionary) -> bool: return d.t < PICK_T + 0.05 or (d.has("vel") and d.t < 1.4))
	for d: Dictionary in _dying:
		if d.has("vel"):
			d.vel.y += 60.0 * delta
			d.pos += (d.vel as Vector2) * delta
	for b: Dictionary in _beams:
		b.t += delta
		if String(b.kind) == "bee" and b.t >= BEE_T and not b.get("home", false):
			b.home = true
			var to: Vector2i = b.to
			if to.x >= 0:
				var at := px(to.x, to.y)
				_fx.puff(at, Color("f6c53d"), 8)
				_spray(_bits, at, Color("f6c53d"), 6, 460.0, "star", 0.8)
				_ring(_bits, at, _u * 1.1, Color("fff4c2"))
				_fx.cue("bee_hit", randf_range(0.95, 1.1), -4.0)
				if b.has("carry"):
					_shake = maxf(_shake, 0.3)
	_beams = _beams.filter(func(b: Dictionary) -> bool: return b.t < 0.6)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 1.0)
	_fly(delta)
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 14.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO
	# a bed left alone shows a move
	if _press.x >= 0 or busy() or sim.is_over() or _armed >= 0:
		_idle = 0.0
		_hint = []
	else:
		_idle += delta
		if _idle >= HINT_AFTER and _hint.is_empty():
			_hint = sim.hint()
	_twinkle(delta)
	_animate_rewards(delta)
	if sim.is_over() and not _over_said and not busy():
		_over_said = true
		_feel(Haptics.LOSE)
		_game_over()
	if sim.is_offered() and _offer == null and not busy():
		_show_offer()
	_step_ground(delta)

## The rewards' own clocks: the bits in both layers, the stickers, the
## sunbursts, the flash, the cascade's glow, the day's stars and its rain.
func _animate_rewards(delta: float) -> void:
	_step_bits(_bits, delta)
	_step_bits(_air_bits, delta)
	for st: Dictionary in _stickers:
		st.t += delta
	_stickers = _stickers.filter(func(st: Dictionary) -> bool: return st.t < st.life)
	for b: Dictionary in _bursts:
		b.t += delta
	_bursts = _bursts.filter(func(b: Dictionary) -> bool: return b.t < 0.9)
	_flash = maxf(0.0, _flash - delta * 2.6)
	if not busy():
		_heat = maxf(0.0, _heat - delta * 0.8)
	for i in _goal_cheer:
		_goal_cheer[i] = float(_goal_cheer[i]) + delta
	if not _stars.is_empty():
		_stars.t = float(_stars.t) + delta
		for i in 3:
			var land := 0.35 + 0.28 * i
			if float(_stars.t) >= land and not (_stars.said as Dictionary).has(i):
				_stars.said[i] = true
				var at: Vector2 = _stars.at + Vector2((i - 1) * 110.0, -18.0 if i == 1 else 0.0)
				if i < int(_stars.n):
					_fx.cue("goal", 1.0 + 0.18 * i, -2.0)
					_spray(_air_bits, at, Art.GOLD, 10, 520.0, "star", 1.2)
					_spray(_air_bits, at, Color("fffaf0"), 6, 380.0, "spark", 1.0)
					_ring(_air_bits, at, 90.0, Art.GOLD)
		if float(_stars.t) > 2.4:
			_stars = {}
	if _rain > 0.0:
		_rain -= delta
		if not Motion.reduce and randf() < delta * 26.0:
			var w := _air.size.x
			var col: Color = CONFETTI[randi() % CONFETTI.size()] if randf() < 0.6 else Art.RAINBOW[randi() % Art.RAINBOW.size()]
			_air_bits.append({"pos": Vector2(randf_range(0.0, w), -30.0), "vel": Vector2(randf_range(-60.0, 60.0), randf_range(120.0, 260.0)),
				"rot": randf() * TAU, "spin": randf_range(-4.0, 4.0), "t": 0.0, "life": 3.2, "kind": "petal" if randf() < 0.55 else "confetti",
				"col": col, "size": randf_range(0.9, 1.4), "float": true})

## Bits move: thrown, pulled down, slowed by the air, a petal fluttering
## side to side as it falls.
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
			v.y = minf(v.y + 120.0 * delta, 240.0)
			b.pos += Vector2(v.x + sin(b.t * 3.0 + b.rot) * 70.0, v.y) * delta
		else:
			v *= drag
			v.y += (1500.0 if String(b.kind) != "petal" and String(b.kind) != "leaf" else 700.0) * delta
			b.pos += v * delta
			if String(b.kind) == "petal" or String(b.kind) == "leaf":
				b.pos.x += sin(b.t * 7.0 + b.rot) * 40.0 * delta
		b.vel = v
		b.rot += float(b.spin) * delta
	var keep := bits.filter(func(b: Dictionary) -> bool: return b.t < b.life)
	bits.clear()
	bits.append_array(keep)

## Throws `n` bits of `kind` out of `at`, into `bits` (the field's or the
## air's), at up to `speed` pixels a second.
func _spray(bits: Array, at: Vector2, col: Color, n: int, speed: float, kind := "petal", size := 1.0, delay := 0.0) -> void:
	if Motion.reduce:
		return
	n = mini(n, MAX_BITS - bits.size())
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.35, 1.0) + Vector2(0, -speed * 0.35)
		bits.append({"pos": at, "vel": v, "rot": randf() * TAU, "spin": randf_range(-10.0, 10.0), "t": -delay,
			"life": randf_range(0.55, 0.95) + (0.4 if kind == "petal" or kind == "leaf" else 0.0), "kind": kind,
			"col": col, "size": size * randf_range(0.7, 1.25)})

## A ring swelling out of `at` to `radius` and fading.
func _ring(bits: Array, at: Vector2, radius: float, col: Color, delay := 0.0) -> void:
	if Motion.reduce:
		return
	bits.append({"pos": at, "vel": Vector2.ZERO, "rot": 0.0, "spin": 0.0, "t": -delay, "life": 0.45, "kind": "ring",
		"col": col, "size": radius})

## A word lettered at `at` in the air's pixels, each letter hopping in on
## its own. `rainbow` letters it in the sticker colours, else in `col`;
## `rays` sets a sunburst turning behind it. A sticker with an `id`
## replaces the one before it with the same id.
func _sticker(text: String, at: Vector2, size: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "") -> void:
	if id != "":
		_stickers = _stickers.filter(func(st: Dictionary) -> bool: return String(st.id) != id)
	_stickers.append({"text": text, "at": at, "t": 0.0, "life": life, "size": size, "rainbow": rainbow, "col": col,
		"rays": rays and not Motion.reduce, "tilt": 0.0 if Motion.reduce else randf_range(-0.08, 0.08), "id": id})
	_air.queue_redraw()

## Where the bed's centre is, in the air's pixels, give or take a fraction
## of the bed.
func _bed_at(fx: float, fy: float) -> Vector2:
	return _in_air(field, _origin + Vector2(Sim.COLS * _u * fx, Sim.ROWS * _u * fy))

func _squash(t: Dictionary, amt: float) -> void:
	if Motion.reduce:
		return
	t.squash = 0.0
	t.amt = amt

## Now and then a tile at rest glints and another gives a little wiggle.
func _twinkle(delta: float) -> void:
	for g: Dictionary in _glints:
		g.t += delta
	_glints = _glints.filter(func(g: Dictionary) -> bool: return g.t < 0.7 and _tiles.has(g.id))
	if Motion.reduce or _tiles.is_empty() or busy():
		return
	_glint_wait -= delta
	if _glint_wait > 0.0:
		return
	_glint_wait = randf_range(0.8, 2.0)
	var ids := _tiles.keys()
	_glints.append({"id": ids[randi() % ids.size()], "t": 0.0})
	if randf() < 0.5:
		var other: Dictionary = _tiles[ids[randi() % ids.size()]]
		if float(other.wig) < 0.0:
			other.wig = 0.0

func _fly(delta: float) -> void:
	if _flights.is_empty():
		return
	for f: Dictionary in _flights:
		f.t += delta
		if f.t >= float(f.get("time", FLIGHT_T)) and not f.get("home", false):
			f.home = true
			match String(f.get("kind", "goal")):
				"star":
					_star_home(f)
				"tool":
					_gift_home(f)
				_:
					var i: int = f.goal
					_owed[i] = maxi(0, int(_owed.get(i, 0)) - 1)
					if i < _goal_plates.size():
						_kick(_goal_plates[i].pic, 0.22, 0.24)
						var col := Art.paint(int(f.k))
						_spray(_air_bits, f.to, col.lightened(0.25), 4, 300.0, "petal", 0.8)
						_ring(_air_bits, f.to, 46.0, col.lightened(0.3))
					_fx.cue("collect", randf_range(0.95, 1.2), -6.0)
	_flights = _flights.filter(func(f: Dictionary) -> bool: return not f.get("home", false))
	_air.queue_redraw()

## A bloom star lands on its tile: the tile turns, the moves count down.
func _star_home(f: Dictionary) -> void:
	if _tiles.has(f.id):
		_turn_now(_tiles[f.id])

## The tile turns to what the sim made of it: a breeze, at the day's end.
func _turn_now(t: Dictionary) -> void:
	var turn: Dictionary = t.turn
	if turn.is_empty():
		return
	t.turn = {}
	t.k = int(turn.k)
	t.sp = int(turn.sp)
	t.glow = 0.0
	t.bump = 0.0
	var at := px(t.pos.x, t.pos.y)
	_fx.sparkle(at, Art.GOLD)
	if bool(turn.get("bloom", false)):
		_shown_moves = maxi(0, _shown_moves - 1)
		_fx.cue("convert", 1.0 + 0.04 * float(turn.get("n", 0)), -4.0)
		_spray(_bits, at, Art.GOLD, 6, 420.0, "star", 0.8)
		_pops.append({"pos": at, "text": "+%d" % Sim.MOVE_BONUS, "t": 0.0, "col": Pal.SUN, "big": false})

## The day's gift lands in its chip.
func _gift_home(f: Dictionary) -> void:
	var tool: int = f.tool
	_gift_owed[tool] = maxi(0, int(_gift_owed.get(tool, 0)) - 1)
	var b: Control = _tool_buttons[tool]
	_kick(b, 0.3, 0.4)
	var at := _in_air(b, b.size * 0.5)
	_spray(_air_bits, at, Pal.SUN, 12, 520.0, "star", 1.1)
	_ring(_air_bits, at, 120.0, Art.GOLD)
	_sticker("+1", at + Vector2(0, -110), 60, 1.1, false, Pal.SUN)
	_fx.cue("gift")
	_badges[tool].queue_redraw()

# --- input ---

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
	if at == Vector2.INF or sim == null or sim.is_over() or sim.is_offered() or settings_sheet.is_open():
		return
	_idle = 0.0
	if pressed:
		# a move may be made while tiles are still landing, once the queue
		# has caught up with the sim; a tap before then hurries it
		if not _queue.is_empty() or _wait > 0.0:
			if not Motion.reduce:
				_hurry = true
			return
		var cell := cell_at(at)
		if cell.x < 0:
			return
		if _armed >= 0:
			_target(cell)
			return
		_press = cell
		_press_at = at
		return
	if _press.x < 0:
		return
	if released:
		var cell := _press
		_press = Vector2i(-1, -1)
		# a tap: pick a tile, or swap it with the one picked before
		if _selected.x >= 0 and Sim.adjacent(_selected, cell):
			var a := _selected
			_selected = Vector2i(-1, -1)
			_try_swap(a, cell)
		elif _selected == cell:
			_selected = Vector2i(-1, -1)
		elif _selected.x < 0 and sim.special(cell) != Sim.Sp.NONE:
			# a special tapped on its own goes off where it stands
			_hint = []
			sim.fire(cell)
			_take_events()
		else:
			_selected = cell
			_fx.cue("select", 1.0, -4.0)
			if _tiles.has(_id_at(cell)):
				_tiles[_id_at(cell)].bump = 0.0
		return
	# a drag far enough toward a neighbour swaps with it
	var d := (at - _press_at) / _u
	if maxf(absf(d.x), absf(d.y)) >= DRAG:
		var dir := Vector2i(int(signf(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, int(signf(d.y)))
		var a := _press
		_press = Vector2i(-1, -1)
		_selected = Vector2i(-1, -1)
		var b := a + dir
		if sim.inside(b):
			_try_swap(a, b)

func _id_at(cell: Vector2i) -> int:
	var t: Dictionary = sim.at(cell)
	return int(t.id) if not t.is_empty() else -1

func _try_swap(a: Vector2i, b: Vector2i) -> void:
	_hint = []
	sim.swap(a, b)
	_take_events()

## A tap with a tool armed: the trowel, the bomb and the rainbow seed act on
## the tile tapped, the swap on the second of two neighbours.
func _target(cell: Vector2i) -> void:
	var tool := _armed
	if tool < 0:
		return
	if tool == Sim.Tool.SWAP:
		if _swap_a.x < 0 or _swap_a == cell:
			_swap_a = cell if _swap_a != cell else Vector2i(-1, -1)
			_fx.cue("select")
			return
		if not sim.can_target(tool, _swap_a, cell):
			_swap_a = cell
			_fx.cue("select")
			return
		var a := _swap_a
		_disarm()
		sim.use(tool, a, cell)
	else:
		if not sim.can_target(tool, cell):
			_fx.cue("refused")
			Motion.shiver(_tool_buttons[tool])
			return
		_disarm()
		sim.use(tool, cell)
	_take_events()

func _on_tool(tool: int) -> void:
	if sim == null or sim.is_over():
		return
	if _armed == tool:
		_disarm()
		return
	_disarm()
	if not sim.can_use(tool) or busy():
		_fx.cue("refused")
		Motion.shiver(_tool_buttons[tool])
		return
	_armed = tool
	_swap_a = Vector2i(-1, -1)
	_selected = Vector2i(-1, -1)
	_style_chip(_tool_buttons[tool], true)
	_fx.cue("arm")
	var lines := {Sim.Tool.TROWEL: "PS_TROWEL_LINE", Sim.Tool.SWAP: "PS_SWAP_LINE", Sim.Tool.BOMB: "PS_BOMB_LINE", Sim.Tool.RAINBOW: "PS_RAINBOW_LINE"}
	_show_banner("", tr(lines[tool]), 1.1)

func _disarm() -> void:
	if _armed >= 0:
		_style_chip(_tool_buttons[_armed], false)
	_armed = -1
	_swap_a = Vector2i(-1, -1)

# --- events ---

## One event off the queue, and how long the next waits for it.
func _apply(ev: Dictionary) -> void:
	var quick := Motion.reduce
	match String(ev.type):
		"deal":
			_on_deal(ev)
			_wait = 0.1 if quick else 0.25
			_settle = true
		"swap":
			var ta: Dictionary = _tiles.get(ev.ida, {})
			var tb: Dictionary = _tiles.get(ev.idb, {})
			if ta.is_empty() or tb.is_empty():
				return
			ta.to = ev.b
			tb.to = ev.a
			if bool(ev.ok):
				_fx.cue("swap")
				if not bool(ev.get("free", false)):
					# the move's knock lands with its first tiles (`_on_clear`)
					_pending = true
					_by_hand = true
					_bumped = false
					_shown_moves -= 1
					if _shown_moves <= 5 and _shown_moves > 0:
						_kick(_moves_plate, 0.16, 0.3)
					if _shown_moves == 1:
						_sticker(tr("PS_LAST_MOVE"), _in_air(_moves_plate, _moves_plate.size * 0.5) + Vector2(-60, 120), 46, 1.4, false, Color("ff6f61"))
				_wait = 0.0 if quick else SWAP_T
			else:
				_fx.cue("bad_swap")
				_queue.push_front({"type": "unswap", "ida": ev.ida, "idb": ev.idb, "a": ev.a, "b": ev.b})
				_wait = 0.0 if quick else SWAP_T
		"unswap":
			var ta: Dictionary = _tiles.get(ev.ida, {})
			var tb: Dictionary = _tiles.get(ev.idb, {})
			if not ta.is_empty():
				ta.to = ev.a
				ta.wig = 0.0
			if not tb.is_empty():
				tb.to = ev.b
				tb.wig = 0.0
			_settle = true
		"clear":
			_on_clear(ev)
			var blast := not (ev.blasts as Array).is_empty()
			# a long cascade plays its later steps quicker
			var pace := maxf(0.6, 1.0 - 0.07 * (int(ev.step) - 1))
			_wait = 0.05 if quick else (BLAST_T if blast else PICK_T) * pace
		"fire":
			_fx.cue("select", 1.3, -2.0)
			_pending = true
			_by_hand = true
			_bumped = false
			_shown_moves -= 1
			if _tiles.has(ev.id):
				_tiles[ev.id].bump = 0.0
			if _shown_moves <= 5 and _shown_moves > 0:
				_kick(_moves_plate, 0.16, 0.3)
			_wait = 0.0 if quick else 0.1
		"moss":
			_on_moss(ev)
			_wait = 0.05 if quick else 0.35
		"offer":
			pass
		"more_moves":
			_shown_moves += int(ev.moves)
			_kick(_moves_plate, 0.35, 0.45)
			var at := _in_air(_moves_plate, _moves_plate.size * 0.5)
			_spray(_air_bits, at, Pal.SUN, 14, 560.0, "star", 1.1)
			_ring(_air_bits, at, 120.0, Art.GOLD)
			_sticker(tr("PS_MORE_MOVES") % int(ev.moves), at + Vector2(-80, 130), 56, 1.4, false, Pal.SUN)
			_fx.cue("more_moves")
			_feel(Haptics.GOOD)
			_wait = 0.0 if quick else 0.4
		"fall":
			var landed := false
			for f: Dictionary in ev.falls:
				if _tiles.has(f.id):
					_tiles[f.id].to = Vector2i(int(f.col), int(f.to))
			for f: Dictionary in ev.fresh:
				var t := _new_tile(Vector2(f.col, float(f.from)), Vector2i(int(f.col), int(f.row)), int(f.k), int(f.sp))
				_tiles[f.id] = t
				landed = true
			if landed:
				_fx.cue("land", randf_range(0.9, 1.1), -8.0)
			_settle = true
		"convert":
			if bool(ev.get("bloom", false)) and not quick:
				_bloom_stars(ev.tiles)
				_wait = BLOOM_STEP * (ev.tiles as Array).size() + BLOOM_FLIGHT + 0.25
			else:
				for c: Dictionary in ev.tiles:
					if _tiles.has(c.id):
						var t: Dictionary = _tiles[c.id]
						t.k = int(c.k)
						t.sp = int(c.sp)
						t.glow = 0.0
						t.bump = 0.0
						var at := px(c.cell.x, c.cell.y)
						_fx.sparkle(at, Art.GOLD)
						_spray(_bits, at, Art.GOLD, 4, 360.0, "star", 0.7)
				if bool(ev.get("bloom", false)):
					_shown_moves = 0
				_fx.cue("convert")
				_wait = 0.1 if quick else 0.35
		"shuffle":
			for s: Dictionary in ev.tiles:
				if _tiles.has(s.id):
					_tiles[s.id].to = s.cell
			_fx.cue("shuffle")
			_show_banner("", tr("PS_SHUFFLE"), 0.8)
			_shake = maxf(_shake, 0.35)
			_wait = 0.1 if quick else 0.5
			_settle = true
		"goal_done":
			pass
		"day_done":
			_fx.cue("day_done")
			_feel(Haptics.BUMP)
			_by_hand = false
			_blooming = true
			_heat = 0.0
			var left := int(ev.left)
			var n := 1 + int(left >= ceili(_day_moves * 0.2)) + int(left >= ceili(_day_moves * 0.4))
			var mid := _bed_at(0.5, 0.3)
			_sticker(tr("PS_DAY_DONE"), mid, 96, 2.4, true, Color.WHITE, true, "day")
			_show_banner("", tr("PS_BONUS") % [left, Record.grouped(int(ev.bonus))], 1.8, 0.64)
			if not quick:
				_stars = {"n": n, "t": 0.0, "at": mid + Vector2(0, 150), "said": {}}
				_rain = 3.2
			_shown_score += int(ev.bonus)
			_flash_col = Color("fff4c2")
			_flash = 0.6
			_confetti()
			_wait = 0.2 if quick else 1.3
		"gift":
			var tool: int = Sim.TOOL_KEYS.find_key(String(ev.tool))
			var b: Control = _tool_buttons[tool]
			if quick:
				_kick(b, 0.2, 0.35)
				_fx.cue("gift")
				_badges[tool].queue_redraw()
				_wait = 0.1
			else:
				_gift_owed[tool] = int(_gift_owed.get(tool, 0)) + 1
				_badges[tool].queue_redraw()
				var from := _bed_at(0.5, 0.5)
				var to := _in_air(b, b.size * 0.5)
				_flights.append({"kind": "tool", "tool": tool, "from": from, "ctrl": from.lerp(to, 0.5) + Vector2(260.0, -120.0),
					"to": to, "t": -0.15, "time": 0.8, "goal": -1, "k": 0})
				_sticker(tr("PS_GIFT"), from + Vector2(0, -150), 58, 1.3, false, Pal.SUN)
				_fx.cue("arm", 1.2, -4.0)
				_wait = 0.8
		"tool":
			# a tool used taps, and what it picks at once adds nothing
			_feel(Haptics.TAP)
			_pending = false
			_by_hand = true
			_bumped = false
			_badges[Sim.TOOL_KEYS.find_key(String(ev.tool))].queue_redraw()
			var cell: Vector2i = ev.cell
			match String(ev.tool):
				"trowel":
					_fx.cue("trowel")
					_fx.puff(px(cell.x, cell.y), Color("b58a55"), 8)
				"bomb":
					_fx.cue("bomb")
				"rainbow":
					_fx.cue("rainbow")
		"refused":
			_fx.cue("refused")
		"over":
			pass
	top_bar.refresh(self)

func _on_deal(ev: Dictionary) -> void:
	# the day before (if any) drops away under the new one
	for id in _tiles:
		var t: Dictionary = _tiles[id]
		if not Motion.reduce:
			_dying.append({"k": t.k, "sp": t.sp, "pos": t.pos, "into": Vector2.INF, "t": 0.0,
				"vel": Vector2(randf_range(-2.0, 2.0), randf_range(-6.0, -2.0))})
	_tiles.clear()
	for d: Dictionary in ev.tiles:
		var cell: Vector2i = d.cell
		var t := _new_tile(Vector2(cell.x, cell.y - Sim.ROWS - 1.0), cell, int(d.k), int(d.sp))
		t.hold = 0.0 if Motion.reduce else 0.35 + 0.04 * cell.x + 0.025 * (Sim.ROWS - cell.y)
		_tiles[d.id] = t
	_ground.clear()
	_ground_later.clear()
	for g: Dictionary in ev.get("cells", []):
		_ground[g.cell] = {"block": int(g.block), "hp": int(g.hp), "weed": int(g.weed), "hit": -1.0,
			"grow": -1.0 if Motion.reduce else -0.3 - 0.03 * (g.cell as Vector2i).x, "pending": not Motion.reduce}
	_bed = _build_bed()
	_shown_day = int(ev.day)
	_shown_moves = int(ev.moves)
	_shown_goals = (ev.goals as Array).duplicate(true)
	_owed.clear()
	for p: Dictionary in _goal_plates:
		p.pic.queue_redraw()
	_fx.cue("deal")
	_pending = false
	_by_hand = false
	_day_moves = int(ev.moves)
	_blooming = false
	_goal_cheer.clear()
	_sticker(tr("PS_DAY") % _shown_day, _bed_at(0.5, 0.3), 104, 1.8, true, Color.WHITE, true, "day")
	_show_banner("", _goal_line(), 1.3, 0.5)
	_kick(_day_l, 0.2, 0.3)

## A cell's ground changes: now, or after `wait` seconds while a bee flies
## there. A weed pulled throws leaves; a stone knocked jolts and chips; a
## stone broken or moss cleared bursts.
func _ground_change(cell: Vector2i, change: Dictionary, wait := 0.0) -> void:
	if wait > 0.0 and not Motion.reduce:
		_ground_later.append({"cell": cell, "change": change, "wait": wait})
		return
	var g: Dictionary = _ground.get(cell, {"block": Sim.Block.NONE, "hp": 0, "weed": 0, "hit": -1.0, "grow": -1.0})
	var at := px(cell.x, cell.y)
	if change.has("weed"):
		g.weed = int(change.weed)
		_spray(_bits, at, Art.WEED, 7, 420.0, "leaf", 0.9)
		_spray(_bits, at, Art.SOIL, 4, 300.0, "seed", 0.9)
		_ring(_bits, at, _u * 0.7, Color(Art.WEED.lightened(0.4), 0.9))
		_fx.cue("weed", randf_range(0.95, 1.1), -4.0)
	if change.has("block"):
		var was := int(change.get("was", g.block))
		g.block = int(change.block)
		g.hp = int(change.get("hp", 0))
		g.hit = 0.0
		if was == Sim.Block.STONE:
			var broke := int(change.block) == Sim.Block.NONE
			_spray(_bits, at, Art.STONE, 10 if broke else 5, 620.0 if broke else 420.0, "seed", 1.3 if broke else 1.0)
			_spray(_bits, at, Color("fffaf0"), 3, 300.0, "spark", 0.8)
			if broke:
				_fx.puff(at, Art.STONE.lightened(0.3), 10)
				_ring(_bits, at, _u * 1.1, Color(Art.STONE.lightened(0.4), 0.9))
				_shake = maxf(_shake, 0.2)
			_fx.cue("stone_break" if broke else "stone", randf_range(0.95, 1.1), -3.0)
		elif was == Sim.Block.MOSS:
			_fx.puff(at, Art.MOSS.lightened(0.2), 8)
			_spray(_bits, at, Art.MOSS.lightened(0.15), 8, 460.0, "leaf", 1.0)
			_fx.cue("moss_clear", randf_range(0.95, 1.1), -4.0)
	g.pending = false
	if int(g.block) == Sim.Block.NONE and int(g.weed) <= 0:
		_ground.erase(cell)
	else:
		_ground[cell] = g

## The ground's own clocks: a knock's jolt, things coming in, and the changes
## waiting for a bee.
func _step_ground(delta: float) -> void:
	for cell: Vector2i in _ground:
		var g: Dictionary = _ground[cell]
		if float(g.hit) >= 0.0:
			g.hit = float(g.hit) + delta if float(g.hit) < 0.8 else -1.0
		if bool(g.get("pending", false)) or float(g.grow) >= 0.0:
			g.grow = float(g.grow) + delta
			if float(g.grow) >= 0.0:
				g.pending = false
			if float(g.grow) > 0.5:
				g.grow = -1.0
	if _ground_later.is_empty():
		return
	for w: Dictionary in _ground_later:
		w.wait = float(w.wait) - delta
	var due := _ground_later.filter(func(w: Dictionary) -> bool: return float(w.wait) <= 0.0)
	_ground_later = _ground_later.filter(func(w: Dictionary) -> bool: return float(w.wait) > 0.0)
	for w: Dictionary in due:
		_ground_change(w.cell, w.change)

## Moss left alone creeps into the tile beside it: the tile is swallowed and
## a new cushion swells up in its place.
func _on_moss(ev: Dictionary) -> void:
	var cell: Vector2i = ev.cell
	if _tiles.has(ev.id):
		var t: Dictionary = _tiles[ev.id]
		if not Motion.reduce:
			_dying.append({"k": int(t.k), "sp": int(t.sp), "pos": t.pos, "into": Vector2.INF, "t": 0.0})
		_tiles.erase(ev.id)
	var old: Dictionary = _ground.get(cell, {})
	_ground[cell] = {"block": Sim.Block.MOSS, "hp": 0, "weed": int(old.get("weed", 0)), "hit": -1.0,
		"grow": -1.0 if Motion.reduce else 0.0, "pending": false}
	var from: Vector2i = ev.from
	if _ground.has(from):
		_ground[from].hit = 0.0
	var at := px(cell.x, cell.y)
	_spray(_bits, at, Art.MOSS, 6, 300.0, "leaf", 0.9)
	_fx.cue("moss", randf_range(0.95, 1.05), -3.0)
	_shown_goals = (ev.goals as Array).duplicate(true)
	for p: Dictionary in _goal_plates:
		p.pic.queue_redraw()

# --- the offer ---

## Out of moves short of the day: a card offering five more moves, once a
## game, with what the day still wants.
func _show_offer() -> void:
	_disarm()
	_press = Vector2i(-1, -1)
	_selected = Vector2i(-1, -1)
	var short := 0
	for g: Dictionary in sim.goals:
		short += maxi(0, int(g.need) - int(g.got))
	_fx.cue("offer")
	_feel(Haptics.WARN)
	var scrim := Dialog.scrim()
	scrim.name = "Offer"
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(780)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	# the day's goals as they stand, each with what is still wanted
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	for g: Dictionary in sim.goals:
		var left := maxi(0, int(g.need) - int(g.got))
		var k := int(g.k)
		var pic := _icon(func(ci: Control) -> void:
			var sz := minf(ci.size.x, ci.size.y) * 0.8
			ci.draw_mesh(Art.tile(k, sz), null, Transform2D(0.0, Vector2(ci.size.x * 0.5, ci.size.y * 0.42)))
			var font := get_theme_font("font", "SheetTitle")
			var text := "✓" if left == 0 else str(left)
			var fs := 34
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := Vector2(ci.size.x * 0.5 - w * 0.5, ci.size.y - 4)
			ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color("fffaf0"))
			ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.LEAF_DEEP if left == 0 else Color("d0503f")))
		pic.custom_minimum_size = Vector2(120, 140)
		row.add_child(pic)
	col.add_child(row)
	var head := Label.new()
	head.text = "PS_OFFER_TITLE"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var line := Label.new()
	line.text = tr("PS_OFFER_LINE_ONE") if short == 1 else tr("PS_OFFER_LINE_N") % short
	line.theme_type_variation = "SheetBody"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	var take := Dialog.primary("reset", tr("PS_OFFER_TAKE") % Sim.MORE_MOVES)
	take.name = "Take"
	take.pressed.connect(_take_offer)
	var end := Dialog.secondary("chevron_right", tr("PS_OFFER_END"))
	end.name = "End"
	end.pressed.connect(_end_offer)
	Dialog.buttons(col, take, end)
	_offer = scrim
	add_child(scrim)
	Motion.appear(scrim, 0.0, 1.0, 0.25)
	if not Motion.reduce:
		card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
		card.scale = Vector2.ONE * 0.8
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _take_offer() -> void:
	if _offer != null:
		_offer.queue_free()
		_offer = null
	if sim.keep_going():
		_take_events()

func _end_offer() -> void:
	if _offer != null:
		_offer.queue_free()
		_offer = null
	sim.decline()
	_take_events()

## Every tile the day's end turns gets a star thrown from the moves plate,
## one after another, and turns when it lands.
func _bloom_stars(tiles: Array) -> void:
	var from := _in_air(_moves_plate, _moves_plate.size * 0.5)
	_kick(_moves_plate, 0.25, 0.4)
	for i in tiles.size():
		var c: Dictionary = tiles[i]
		if not _tiles.has(c.id):
			continue
		var t: Dictionary = _tiles[c.id]
		t.turn = {"k": int(c.k), "sp": int(c.sp), "wait": BLOOM_STEP * i + BLOOM_FLIGHT + 0.6, "bloom": true, "n": i}
		var to := _in_air(field, px(c.cell.x, c.cell.y))
		_flights.append({"kind": "star", "id": c.id, "from": from, "ctrl": from.lerp(to, 0.5) + Vector2(randf_range(-200.0, 200.0), -260.0),
			"to": to, "t": -BLOOM_STEP * i, "time": BLOOM_FLIGHT, "goal": -1, "k": int(c.k)})

## The day's goals in words: "12 flowers, 12 leaves".
func _goal_line() -> String:
	for g: Dictionary in _shown_goals:
		match int(g.k):
			Sim.GOAL_WEED: return tr("PS_GOAL_WEEDS")
			Sim.GOAL_STONE: return tr("PS_GOAL_STONES")
			Sim.GOAL_MOSS: return tr("PS_GOAL_MOSS")
	return tr("PS_COLLECT")

func _on_clear(ev: Dictionary) -> void:
	var step: int = ev.step
	# The move's one knock, as its first tiles are picked: a tap (a special
	# made is still the tap), or a bump when it set a special off. A
	# cascade's first word bumps a move that has not; the clear that fills
	# the day leaves the bump to it.
	var day_met := _all_met(ev.goals)
	if _pending:
		_pending = false
		if not day_met and not (ev.blasts as Array).is_empty():
			_bumped = true
			_feel(Haptics.BUMP)
		else:
			_feel(Haptics.TAP)
	elif _by_hand and not _bumped and not day_met and not _blooming and WORDS.has(step):
		_bumped = true
		_feel(Haptics.BUMP)
	var made_at := {}
	for m: Dictionary in ev.made:
		made_at[m.id] = m
	var into := {}
	for m: Dictionary in ev.made:
		for c: Vector2i in m.from:
			into[c] = Vector2(m.cell)
	var old_goals := _shown_goals.duplicate(true)
	var flown := 0
	var centre := Vector2.ZERO
	# a bee's mark waits for the bee to get there
	var late := {}
	for b: Dictionary in ev.blasts:
		if String(b.kind) == "bee" and (b.to as Vector2i).x >= 0:
			late[b.to] = true
	for g: Dictionary in ev.tiles:
		var id: int = g.id
		var cell: Vector2i = g.cell
		var t: Dictionary = _tiles.get(id, {})
		var pos := Vector2(cell) if t.is_empty() else (t.pos as Vector2)
		_tiles.erase(id)
		centre += Vector2(cell)
		if not Motion.reduce:
			_dying.append({"k": int(g.k), "sp": int(g.sp), "pos": pos, "into": into.get(cell, Vector2.INF),
				"t": -BEE_T if late.has(cell) else 0.0})
		# a tile the day wants flies up to its goal (a few a step)
		for i in old_goals.size():
			var gg: Dictionary = old_goals[i]
			if int(gg.k) == int(g.k) and int(gg.got) < int(gg.need):
				gg.got = int(gg.got) + 1
				if flown < 8 and not Motion.reduce:
					flown += 1
					var from := _in_air(field, px(pos.x, pos.y))
					var to := _in_air(_goal_plates[i].pic, _goal_plates[i].pic.size * 0.5)
					_flights.append({"k": int(g.k), "from": from, "ctrl": from.lerp(to, 0.4) + Vector2(randf_range(-140.0, 140.0), -200.0),
						"to": to, "t": -0.05 * flown, "goal": i})
					_owed[i] = int(_owed.get(i, 0)) + 1
				break
		if into.get(cell, Vector2.INF) == Vector2.INF:
			var at := px(cell.x, cell.y)
			var many := (ev.tiles as Array).size() > 18
			_spray(_bits, at, Art.paint(int(g.k)).lightened(0.1), 2 if many else 4, 460.0, "leaf" if int(g.k) == 1 else "petal", 1.0)
			if not many:
				_spray(_bits, at, Color("fffaf0"), 2, 300.0, "spark", 0.7)
				_ring(_bits, at, _u * 0.55, Color(Art.paint(int(g.k)).lightened(0.5), 0.9))
	# weeds pulled, stones knocked and broken, moss cleared: the ground
	# changes (late under a bee), and what a goal wants flies up to it
	var cleared: Array = []
	for w: Dictionary in ev.get("weeds", []):
		_ground_change(w.cell, {"weed": int(w.left)}, BEE_T if late.has(w.cell) else 0.0)
		cleared.append([Sim.GOAL_WEED, w.cell])
	for bl: Dictionary in ev.get("blocks", []):
		var gone := int(bl.hp) <= 0
		_ground_change(bl.cell, {"block": Sim.Block.NONE if gone else int(bl.block), "hp": int(bl.hp), "was": int(bl.block)},
			BEE_T if late.has(bl.cell) else 0.0)
		if gone:
			cleared.append([Sim.GOAL_STONE if int(bl.block) == Sim.Block.STONE else Sim.GOAL_MOSS, bl.cell])
	for c: Array in cleared:
		for i in old_goals.size():
			var gg: Dictionary = old_goals[i]
			if int(gg.k) == int(c[0]) and int(gg.got) < int(gg.need):
				gg.got = int(gg.got) + 1
				if flown < 12 and not Motion.reduce:
					flown += 1
					var cell: Vector2i = c[1]
					var from := _in_air(field, px(cell.x, cell.y))
					var to := _in_air(_goal_plates[i].pic, _goal_plates[i].pic.size * 0.5)
					_flights.append({"k": int(c[0]), "from": from, "ctrl": from.lerp(to, 0.4) + Vector2(randf_range(-140.0, 140.0), -200.0),
						"to": to, "t": -0.05 * flown - (BEE_T if late.has(cell) else 0.0), "goal": i})
					_owed[i] = int(_owed.get(i, 0)) + 1
				break
	_shown_goals = (ev.goals as Array).duplicate(true)
	for p: Dictionary in _goal_plates:
		p.pic.queue_redraw()
	for m: Dictionary in ev.made:
		if _tiles.has(m.id):
			var t: Dictionary = _tiles[m.id]
			t.sp = int(m.sp)
			t.k = int(m.k)
			t.bump = 0.0
			t.glow = 0.0
		var at := px(m.cell.x, m.cell.y)
		_fx.sparkle(at, Color("fffaf0"))
		_fx.ring(at, 0.8 * _u, Art.GOLD)
		var bright: Color = Art.RAINBOW[randi() % 6] if int(m.sp) == Sim.Sp.RAINBOW else (Art.GOLD if int(m.sp) == Sim.Sp.BOMB or int(m.sp) == Sim.Sp.BEE else Color("5cb8ff"))
		_bursts.append({"pos": Vector2(m.cell), "t": 0.0, "col": bright})
		_spray(_bits, at, Art.GOLD, 8, 520.0, "star", 0.9)
		_ring(_bits, at, _u * 1.3, Color("fffaf0"))
		_sticker(tr(MADE_WORDS[int(m.sp)]), _in_air(field, at + Vector2(0, -_u * 0.9)), 54 if int(m.sp) != Sim.Sp.RAINBOW else 64,
			1.1, int(m.sp) == Sim.Sp.RAINBOW, bright, false, "made%d" % int(m.id))
		match int(m.sp):
			Sim.Sp.RAINBOW:
				_fx.cue("made_rainbow")
			Sim.Sp.BOMB:
				_fx.cue("made_bomb")
			Sim.Sp.BEE:
				_fx.cue("made_bee")
			_:
				_fx.cue("made_breeze")
	for id in ev.lit:
		if _tiles.has(id):
			_tiles[id].lit = true
			_tiles[id].bump = 0.0
	var loud := {}
	var board := Vector2(Sim.COLS, Sim.ROWS) * _u
	for b: Dictionary in ev.blasts:
		var beam := b.duplicate()
		beam.t = 0.0
		if String(b.kind) == "rainbow":
			beam.bend = randf_range(-0.5, 0.5)
		elif String(b.kind) == "bee":
			beam.bend = -1.0 if randf() < 0.5 else 1.0
		_beams.append(beam)
		var cell: Vector2i = b.cell
		var at := px(cell.x, cell.y)
		match String(b.kind):
			"row", "col":
				loud["breeze"] = true
				# leaves shed along the line behind the gust as it runs out
				var along := Vector2(1, 0) if String(b.kind) == "row" else Vector2(0, 1)
				for q in 7:
					for side in [-1.0, 1.0]:
						var p: Vector2 = at + along * side * (q + 0.5) * _u
						if Rect2(_origin, board).grow(4.0).has_point(p):
							_spray(_bits, p, Color("7fd66a") if q % 2 == 0 else Color("fffaf0"), 1, 260.0, "leaf" if q % 2 == 0 else "spark", 0.9, q * 0.03)
				_flash_col = Color("e8f7ff")
				_flash = maxf(_flash, 0.18)
			"bomb", "all":
				loud["bomb"] = true
				var big := String(b.kind) == "all" or int(b.get("r", 1)) > 1
				_shake = maxf(_shake, 0.45 if not big else 0.8)
				_fx.puff(at, Color("f7d44a"), 10)
				_spray(_bits, at, Color("ffb03b"), 10 if not big else 18, 900.0, "spark", 1.2)
				_spray(_bits, at, Color("f7d44a"), 6 if not big else 12, 700.0, "star", 1.0)
				_spray(_bits, at, Color("7a5230"), 6, 600.0, "seed", 1.0)
				_ring(_bits, at, _u * (2.2 if not big else 4.0), Color("fff1b0"))
				_ring(_bits, at, _u * (1.4 if not big else 2.8), Color("ffb03b"), 0.06)
				_flash_col = Color("fff1b0")
				_flash = maxf(_flash, 0.35 if not big else 0.7)
			"rainbow":
				loud["rainbow"] = true
				_shake = maxf(_shake, 0.4)
				for i in 6:
					_ring(_bits, at, _u * (1.2 + 0.5 * i), Art.RAINBOW[i], 0.04 * i)
				_flash_col = Color("fff6ff")
				_flash = maxf(_flash, 0.45)
			"bee":
				loud["bee"] = true
				_spray(_bits, at, Color("f6c53d"), 5, 380.0, "petal", 0.8)
			"dig":
				pass
	for k: String in loud:
		_fx.cue(k)
	if (ev.tiles as Array).size() > 0:
		_fx.cue("match", clampf(0.9 + 0.08 * (step - 1), 0.9, 1.7), -2.0 if loud.is_empty() else -6.0)
		centre /= float((ev.tiles as Array).size())
		var pts: int = ev.points
		_shown_score += pts
		var first: Dictionary = (ev.tiles as Array)[0]
		_pops.append({"pos": px(centre.x, centre.y), "text": "+%s" % Record.grouped(pts), "t": 0.0,
			"col": Art.paint(int(first.k)) if int(first.k) >= 0 else Pal.SUN, "big": pts >= 500})
	if _blooming:
		return
	# the cascade: a counter over the bed from the second step, a glow
	# building up round it, and a word at the long ones
	if step >= 2:
		_heat = minf(1.0, maxf(_heat, (step - 1) * 0.2))
		_sticker(tr("PS_CASCADE") % step, _bed_at(0.5, 0.0) + Vector2(0, -8), 44 + mini(step, 8) * 3, 1.2, false,
			STICKER_COLS[(step - 2) % STICKER_COLS.size()], false, "cascade")
	if WORDS.has(step):
		_sticker(tr(WORDS[step]), _bed_at(0.5, 0.42), 88 + 6 * (step - 3), 1.5, true, Color.WHITE, true, "word")
		_fx.cue("cheer", 1.0 + 0.1 * (step - 3) / 2.0)
		_spray(_air_bits, _bed_at(0.5, 0.42), Art.GOLD, 14, 700.0, "star", 1.1)
	elif step == 1 and (ev.blasts as Array).size() >= 2:
		_sticker(tr("PS_COMBO"), _bed_at(0.5, 0.42), 84, 1.3, true, Color.WHITE, true, "word")
		_fx.cue("cheer", 1.1)

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

func _show_banner(text: String, sub: String, hold: float, at_y := 0.32) -> void:
	_banner.text = text
	_banner.visible = text != ""
	_sub.text = sub
	_sub_pill.visible = sub != ""
	var box: Control = _banner.get_meta("box")
	box.size = Vector2(field.size.x - 48.0, 0)
	box.position = Vector2(24, field.size.y * at_y)
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
	if Motion.reduce or _shown_score < _roll:
		_roll = _shown_score
	else:
		_roll = move_toward(_roll, _shown_score, maxf(delta * absf(_shown_score - _roll) * 8.0, delta * 400.0))
	if not _beat_best and _best > 0 and int(_roll) > _best:
		_beat_best = true
		_kick(_score_l, 0.3, 0.4)
		_fx.cue("goal", 1.3, -4.0)
		_feel(Haptics.BUMP)
	var day := tr("PS_DAY") % _shown_day
	if _day_l.text != day:
		_day_l.text = day
	var shown := tr("PS_POINTS") % Record.grouped(int(_roll))
	if _score_l.text != shown:
		_score_l.text = shown
	var mv := str(maxi(0, _shown_moves))
	if _moves_l.text != mv:
		_moves_l.text = mv
	_moves_l.add_theme_color_override("font_color", Color("d0503f") if _shown_moves <= 5 else Art.INK)
	_moves_l.pivot_offset = _moves_l.size * 0.5
	var low := _shown_moves <= 5 and _shown_moves > 0 and not _blooming and not Motion.reduce
	_moves_l.scale = Vector2.ONE * (1.0 + 0.1 * maxf(0.0, sin(_clock * (7.0 if _shown_moves <= 2 else 4.5)))) if low else Vector2.ONE
	for i in _goal_plates.size():
		var p: Dictionary = _goal_plates[i]
		p.plate.visible = i < _shown_goals.size()
		if i >= _shown_goals.size():
			continue
		var g: Dictionary = _shown_goals[i]
		var got := mini(int(g.need), int(g.got) - int(_owed.get(i, 0)))
		var text := "%d / %d" % [maxi(0, got), int(g.need)]
		if p.count.text != text:
			p.count.text = text
			p.pic.queue_redraw()
		elif float(_goal_cheer.get(i, 1.0)) < 0.5:
			p.pic.queue_redraw()
		p.count.add_theme_color_override("font_color", Art.LEAF_DEEP if got >= int(g.need) else Art.INK)
		if got >= int(g.need) and not _goal_cheer.has(i):
			_goal_cheer[i] = 0.0
			var at := _in_air(p.pic, p.pic.size * 0.5)
			_kick(p.plate, 0.2, 0.4)
			_fx.cue("goal")
			# a goal filled bumps a move that has not; the day's last is
			# the day's own bump
			if _by_hand and not _bumped and not _blooming and not _all_met(_shown_goals):
				_bumped = true
				_feel(Haptics.BUMP)
			_spray(_air_bits, at, Art.GOLD, 12, 560.0, "star", 1.0)
			_spray(_air_bits, at, Art.LEAF, 6, 420.0, "leaf", 1.0)
			_ring(_air_bits, at, 110.0, Art.LEAF)
			_sticker(tr("PS_GOAL_DONE"), at + Vector2(0, 118), 40, 1.0, false, Art.LEAF)
	for tool: int in _tool_buttons:
		var b: Button = _tool_buttons[tool]
		var ok: bool = sim.can_use(tool)
		b.modulate.a = 1.0 if ok or _armed == tool else 0.55

# --- drawing ---

## The bed: a pale board of rounded cells, every other one a shade deeper,
## with a little shine along the top of each.
func _build_bed() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, s, 28.0), Art.BOARD)
	var pad := _u * 0.05
	for c in Sim.COLS:
		for r in Sim.ROWS:
			if int((_ground.get(Vector2i(c, r), {}) as Dictionary).get("block", 0)) == Sim.Block.HOLE:
				# a hole in the bed's shape is lawn, with a daisy or two
				var mid := _origin + Vector2(c + 0.5, r + 0.5) * _u
				b.polygon(Face.Builder.round_rect(mid - Vector2(_u, _u) * 0.46, Vector2(_u, _u) * 0.92, _u * 0.3), Color(Art.LEAF, 0.28))
				for i in 2:
					var at := mid + Vector2(-0.18 + 0.36 * i, -0.12 + 0.24 * ((c + r + i) % 2)) * _u
					for k in 5:
						b.disc(at + Vector2.from_angle(TAU * k / 5.0) * _u * 0.07, _u * 0.055, Color("fffaf0"))
					b.disc(at, _u * 0.045, Color("f2c14e"))
				continue
			var at := _origin + Vector2(c, r) * _u + Vector2(pad, pad)
			var size := Vector2(_u, _u) - Vector2(pad, pad) * 2.0
			var fill := Art.CELL if (c + r) % 2 == 0 else Art.CELL.darkened(0.035)
			b.polygon(Face.Builder.round_rect(at + Vector2(0, 3), size, _u * 0.18), Color(Art.CELL_DEEP, 0.9))
			b.polygon(Face.Builder.round_rect(at, size, _u * 0.18), fill)
			b.stroke(PackedVector2Array([at + Vector2(_u * 0.2, 4), at + Vector2(size.x - _u * 0.2, 4)]), 2.0, Color(1, 1, 1, 0.5))
	return b.mesh()

## The hedges round the bed: leafy bushes along its sides, starred with
## daisies, built once for the frame where it stands.
func _draw_hedge() -> void:
	if _frame == null or _frame.size.x <= 0.0:
		return
	var rect := Rect2(_hedge.get_global_transform().affine_inverse() * _frame.global_position, _frame.size)
	if _hedge_mesh == null or rect != _hedge_rect:
		_hedge_rect = rect
		var b := Face.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var greens := [Color("4f9a45"), Color("5fae4f"), Color("73c05e")]
		var spots: Array = []
		# down both sides, poking out past the frame
		var y := rect.position.y + 20.0
		while y < rect.end.y + 40.0:
			for side in [0, 1]:
				var x: float = rect.position.x - 6.0 if side == 0 else rect.end.x + 6.0
				spots.append(Vector2(x + rng.randf_range(-14.0, 14.0), y))
			y += rng.randf_range(90.0, 150.0)
		# the corners heaped fuller
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
			for i in 3:
				spots.append(corner + Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-30.0, 30.0)))
		for layer in 3:
			for p: Vector2 in spots:
				var r := rng.randf_range(34.0, 56.0) * (1.0 - layer * 0.18)
				b.disc(p + Vector2(0, -layer * 10.0) + Vector2(rng.randf_range(-10.0, 10.0), 0), r, greens[layer])
		for p: Vector2 in spots:
			if rng.randf() < 0.55:
				var at := p + Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-30.0, 0.0))
				for k in 6:
					b.disc(at + Vector2.from_angle(TAU * k / 6.0) * 7.5, 5.5, Color("fffaf0"))
				b.disc(at, 4.5, Color("f2c14e"))
		_hedge_mesh = b.mesh()
	_hedge.draw_mesh(_hedge_mesh, null)

func _draw_field() -> void:
	if _bed == null:
		_layout_field()
	if _bed == null or sim == null:
		return
	field.draw_mesh(_bed, null, Transform2D(0.0, _shake_off))
	var s := _u * 0.8
	_draw_weeds()
	var under := Face.Builder.new()
	_draw_under(under, s)
	if not under.verts.is_empty():
		_live = under.mesh()
		field.draw_mesh(_live, null, Transform2D(0.0, _shake_off))
	# tiles going: shrinking where they stood, or into the special they made
	for d: Dictionary in _dying:
		var k: float = clampf(d.t / PICK_T, 0.0, 1.0)
		var pos: Vector2 = d.pos
		var sc := 1.0
		var a := 1.0
		if d.has("vel"):
			a = 1.0 - clampf((d.t - 0.6) / 0.7, 0.0, 1.0)
		elif d.into != Vector2.INF:
			pos = pos.lerp(d.into, k * k)
			sc = lerpf(1.0, 0.6, k)
		else:
			sc = 1.0 + 0.25 * sin(minf(1.0, k * 2.0) * PI * 0.5) - 1.25 * maxf(0.0, k - 0.4) / 0.6
			a = 1.0 - maxf(0.0, k - 0.5) * 2.0
		if sc <= 0.02 or a <= 0.0:
			continue
		_draw_tile(int(d.k), int(d.sp), false, px(pos.x, pos.y) + _shake_off, Vector2(sc, sc), 0.0, s, a)
	# the bed's tiles
	var hint_ids := {}
	for c: Vector2i in _hint:
		hint_ids[_id_at(c)] = c
	for id in _tiles:
		var t: Dictionary = _tiles[id]
		if t.pos.y < -1.0:
			continue
		var sc := _scale(t)
		var at := px(t.pos.x, t.pos.y) + _shake_off
		var rot := 0.0
		if float(t.wig) >= 0.0 and not Motion.reduce:
			rot = 0.16 * exp(-float(t.wig) * 5.0) * sin(float(t.wig) * 22.0)
		if hint_ids.has(id) and not Motion.reduce:
			var other: Vector2i = _hint[1] if hint_ids[id] == _hint[0] else _hint[0]
			var dir := Vector2(other - (hint_ids[id] as Vector2i))
			at += dir * _u * 0.07 * maxf(0.0, sin(_clock * 6.0))
		if not Motion.reduce and t.pos == Vector2(t.to) and (float(t.squash) < 0.0 or float(t.squash) > 0.6) and (float(t.bump) < 0.0 or float(t.bump) > 0.4):
			var ph: float = _clock * 2.2 + t.pos.x * 0.7 + t.pos.y * 0.45
			sc *= Vector2(1.0 - 0.018 * sin(ph), 1.0 + 0.028 * sin(ph))
		var cell := Vector2i(roundi(t.pos.x), roundi(t.pos.y))
		if (cell == _selected or cell == _swap_a) and t.pos == Vector2(t.to) and not Motion.reduce:
			sc *= 1.0 + 0.06 * sin(_clock * 8.0)
		_draw_tile(int(t.k), int(t.sp), bool(t.lit), at, sc, rot, s, 1.0)
	_draw_blocks()
	_draw_bees(s)
	var over := Face.Builder.new()
	_draw_over(over, s)
	if not over.verts.is_empty():
		_live_over = over.mesh()
		field.draw_mesh(_live_over, null, Transform2D(0.0, _shake_off))
	_draw_pops()

## A tile at `at`, scaled and turned: a seed bomb's glow under it, a
## breeze's streaks over it.
func _draw_tile(k: int, sp: int, lit: bool, at: Vector2, sc: Vector2, rot: float, s: float, a: float) -> void:
	var col := Color(1, 1, 1, a)
	field.draw_set_transform(at, rot, sc)
	if sp == Sim.Sp.BOMB:
		var hot := lit
		var g := 1.0 if Motion.reduce else 1.0 + 0.06 * sin(_clock * (9.0 if lit else 4.0))
		field.draw_set_transform(at, _clock * 0.8 if not Motion.reduce else 0.0, sc * g)
		field.draw_mesh(Art.bomb_glow(s, hot), null, Transform2D.IDENTITY, col)
		field.draw_set_transform(at, rot, sc)
	field.draw_mesh(Art.tile(k if sp != Sim.Sp.RAINBOW else -1, s), null, Transform2D.IDENTITY, col)
	if sp == Sim.Sp.ROW or sp == Sim.Sp.COL:
		var turn := rot + (PI * 0.5 if sp == Sim.Sp.COL else 0.0)
		var flow := 1.0 if Motion.reduce else 1.0 + 0.05 * sin(_clock * 6.0)
		field.draw_set_transform(at, turn, sc * Vector2(flow, 1.0))
		field.draw_mesh(Art.breeze(s), null, Transform2D.IDENTITY, col)
	elif sp == Sim.Sp.BEE:
		# the bee sits up in the tile's corner, bobbing, wings a-flutter
		var bob := 0.0 if Motion.reduce else sin(_clock * 5.0 + at.x * 0.01) * s * 0.03
		var perch := at + (Vector2(s * 0.26, -s * 0.26 + bob)).rotated(rot) * sc
		field.draw_set_transform(perch, rot - 0.2, sc)
		field.draw_mesh(Art.bee(s), null, Transform2D.IDENTITY, col)
		var flap := 1.0 if Motion.reduce else 0.55 + 0.45 * absf(sin(_clock * 26.0))
		field.draw_set_transform(perch, rot - 0.2, sc * Vector2(1.0, flap))
		field.draw_mesh(Art.bee_wings(s), null, Transform2D.IDENTITY, col)
	field.draw_set_transform(Vector2.ZERO)

## Weeds under the tiles, each cell's patch drawn where it lies.
func _draw_weeds() -> void:
	for cell: Vector2i in _ground:
		var g: Dictionary = _ground[cell]
		if int(g.weed) <= 0:
			continue
		var sc := _grow_scale(g)
		if sc <= 0.0:
			continue
		field.draw_set_transform(px(cell.x, cell.y) + _shake_off, 0.0, Vector2(sc, sc))
		field.draw_mesh(Art.weeds(_u * 0.92, int(g.weed)), null, Transform2D.IDENTITY)
	field.draw_set_transform(Vector2.ZERO)

## Stones and moss over the tiles (a tile falls past them, behind), a
## knocked stone jolting.
func _draw_blocks() -> void:
	for cell: Vector2i in _ground:
		var g: Dictionary = _ground[cell]
		var bl := int(g.block)
		if bl != Sim.Block.STONE and bl != Sim.Block.MOSS:
			continue
		var sc := _grow_scale(g)
		if sc <= 0.0:
			continue
		var rot := 0.0
		var hit := float(g.hit)
		if hit >= 0.0 and not Motion.reduce:
			var k := exp(-hit * 9.0)
			sc *= 1.0 + 0.12 * k * sin(hit * 30.0)
			rot = 0.12 * k * sin(hit * 24.0)
		var at := px(cell.x, cell.y) + _shake_off
		if bl == Sim.Block.MOSS and not Motion.reduce:
			sc *= 1.0 + 0.02 * sin(_clock * 1.8 + cell.x + cell.y)
		field.draw_set_transform(at, rot, Vector2(sc, sc))
		field.draw_mesh(Art.stone(_u * 0.9, int(g.hp)) if bl == Sim.Block.STONE else Art.moss(_u * 0.96), null, Transform2D.IDENTITY)
	field.draw_set_transform(Vector2.ZERO)

## A patch, stone or moss coming in pops up out of the ground once its
## `grow` clock passes nought; before then it is not there yet.
func _grow_scale(g: Dictionary) -> float:
	var grow := float(g.grow)
	if grow < 0.0:
		return 0.0 if g.get("pending", false) else 1.0
	return Motion.back_out(clampf(grow / 0.35, 0.0, 1.0))

## Bees on the wing, from their tile to their mark on a little arc, wings a
## blur.
func _draw_bees(s: float) -> void:
	for bm: Dictionary in _beams:
		if String(bm.kind) != "bee" or Motion.reduce:
			continue
		var to: Vector2i = bm.to
		if to.x < 0 or bm.t >= BEE_T:
			continue
		var p := _bee_at(bm, bm.t)
		var ahead := _bee_at(bm, bm.t + 0.02)
		var flip := ahead.x < p.x
		var sc := Vector2(1.4, 1.4) * (1.0 + 0.25 * sin(clampf(bm.t / BEE_T, 0.0, 1.0) * PI))
		if not flip:
			sc.x = -sc.x
		field.draw_set_transform(p + _shake_off, 0.0, sc)
		field.draw_mesh(Art.bee(s), null, Transform2D.IDENTITY)
		field.draw_set_transform(p + _shake_off, 0.0, sc * Vector2(1.0, 0.4 + 0.6 * absf(sin(_clock * 40.0))))
		field.draw_mesh(Art.bee_wings(s), null, Transform2D.IDENTITY)
	field.draw_set_transform(Vector2.ZERO)

## Where a bee is `t` seconds into its flight.
func _bee_at(bm: Dictionary, t: float) -> Vector2:
	var from: Vector2i = bm.cell
	var to: Vector2i = bm.to
	var a := px(from.x, from.y)
	var z := px(to.x, to.y)
	var k := clampf(t / BEE_T, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var ctrl := a.lerp(z, 0.5) + (z - a).orthogonal().normalized() * minf(_u * 1.6, a.distance_to(z) * 0.35) * float(bm.get("bend", 1.0))
	return a.lerp(ctrl, k).lerp(ctrl.lerp(z, k), k)

## Under the tiles: the picked tile's glow, a tool's first pick, the hint.
func _draw_under(b: Face.Builder, s: float) -> void:
	for cell: Vector2i in [_selected, _swap_a]:
		if cell.x >= 0:
			var at := px(cell.x, cell.y)
			b.disc(at, s * 0.62, Color(Pal.SUN, 0.28))
			b.stroke(Face.Builder.ring(at, s * 0.6, s * 0.6), maxf(3.0, s * 0.05), Color(Pal.SUN, 0.95), true)
	if not _hint.is_empty():
		var a := 0.18 + 0.12 * sin(_clock * 6.0)
		for c: Vector2i in _hint:
			b.disc(px(c.x, c.y), s * 0.6, Color("fffaf0", a))
	# a tool armed: a soft ring on every tile it could take
	if _armed >= 0 and not busy():
		var pulse := 0.5 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 5.0)
		for c in Sim.COLS:
			for r in Sim.ROWS:
				var cell := Vector2i(c, r)
				if cell == _swap_a:
					continue
				var ok: bool = sim.can_target(_armed, _swap_a, cell) if _armed == Sim.Tool.SWAP and _swap_a.x >= 0 else sim.can_target(_armed, cell)
				if ok and (_armed != Sim.Tool.SWAP or _swap_a.x >= 0):
					b.stroke(Face.Builder.ring(px(c, r), s * 0.56, s * 0.56), maxf(2.0, s * 0.03), Color(Pal.SUN, 0.3 + 0.4 * pulse), true)
	# a special just made: a sunburst turning behind it
	for bu: Dictionary in _bursts:
		var k := clampf(bu.t / 0.9, 0.0, 1.0)
		var grow := Motion.back_out(clampf(bu.t / 0.25, 0.0, 1.0))
		var at := px(bu.pos.x, bu.pos.y)
		var col: Color = bu.col
		b.disc(at, _u * 0.8 * grow, Color(col, 0.35 * (1.0 - k)))
		Art.rays(b, at, _u * 0.3, _u * 1.25 * grow, 12, bu.t * 1.6, Color(col.lightened(0.3), 0.55 * (1.0 - k)))
	# a blast's scorch under the tiles
	for bm: Dictionary in _beams:
		if String(bm.kind) == "bomb":
			var cell: Vector2i = bm.cell
			var k := clampf(bm.t / 0.5, 0.0, 1.0)
			var rad := (float(bm.get("r", 1)) + 0.5) * _u
			b.disc(px(cell.x, cell.y), rad * (0.6 + 0.4 * k), Color(Color("f7d44a"), 0.35 * (1.0 - k)))

## Over the tiles: breezes sweeping their lines, bomb rings, a rainbow's
## threads to every tile it takes, glints.
func _draw_over(b: Face.Builder, s: float) -> void:
	var board := Vector2(Sim.COLS, Sim.ROWS) * _u
	for bm: Dictionary in _beams:
		var cell: Vector2i = bm.cell
		var at := px(cell.x, cell.y)
		var t: float = bm.t
		var k := clampf(t / 0.45, 0.0, 1.0)
		var fade := 1.0 - k
		match String(bm.kind):
			"row", "col":
				var horiz := String(bm.kind) == "row"
				var reach := minf(1.0, t / 0.18)
				var w := _u * (0.55 if not bm.get("wide", false) else 0.45) * (0.4 + 0.6 * fade)
				var a := at - (Vector2(board.x, 0) if horiz else Vector2(0, board.y)) * reach
				var z := at + (Vector2(board.x, 0) if horiz else Vector2(0, board.y)) * reach
				b.stroke(PackedVector2Array([a, z]), w * 1.6, Color(Color("fff4c2"), 0.35 * fade))
				b.stroke(PackedVector2Array([a, z]), w * 0.6, Color(Color("fffaf0"), 0.9 * fade))
				if reach < 1.0 or t < 0.3:
					for head in [a, z]:
						Art.glint(b, head, _u * 0.55 * (1.0 - k * 0.5), t * 10.0, Color(1, 1, 0.92, fade))
				# gusts running out along it
				for q in 4:
					var d := (0.25 + 0.2 * q) * reach
					for side in [-1.0, 1.0]:
						var p := at + (Vector2(side * board.x * d, 0) if horiz else Vector2(0, side * board.y * d))
						var along := Vector2(side, 0) if horiz else Vector2(0, side)
						b.stroke(PackedVector2Array([p - along * _u * 0.3, p + along * _u * 0.1]), maxf(2.0, _u * 0.05), Color(1, 1, 1, 0.7 * fade))
			"bomb", "all":
				var rad := (float(bm.get("r", 1)) + 0.5) * _u if String(bm.kind) == "bomb" else board.length() * 0.5
				b.stroke(Face.Builder.ring(at, rad * (0.4 + 0.8 * k), rad * (0.4 + 0.8 * k)), maxf(3.0, _u * 0.12 * fade), Color(Color("fff1b0"), 0.9 * fade), true)
				b.disc(at, rad * 0.5 * fade, Color(Color("fffaf0"), 0.5 * fade))
			"rainbow":
				var cells: Array = bm.get("cells", [])
				var reach := minf(1.0, t / 0.2)
				var bend: float = bm.get("bend", 0.3)
				for i in cells.size():
					var to: Vector2i = cells[i]
					var end := px(to.x, to.y)
					var ctrl := at.lerp(end, 0.5) + (end - at).orthogonal() * bend
					var col: Color = Art.RAINBOW[i % Art.RAINBOW.size()]
					var arc := Face.Builder.bezier2(at, ctrl, end, 10)
					var n := maxi(2, ceili(arc.size() * reach))
					var part := arc.slice(0, n)
					var head: Vector2 = part[part.size() - 1]
					b.stroke(part, maxf(3.0, _u * 0.1), Color(col, 0.9 * fade))
					b.stroke(part, maxf(1.5, _u * 0.035), Color(1, 1, 1, 0.7 * fade))
					Art.glint(b, head, _u * 0.3 * fade, t * 6.0 + i)
				b.disc(at, _u * 0.7 * fade, Color(Color("fffaf0"), 0.5 * fade))
				Art.rays(b, at, _u * 0.3, _u * 1.6 * (0.5 + k), 12, t * 3.0, Color(Color("fff6c8"), 0.5 * fade))
			"bee":
				var to: Vector2i = bm.to
				if to.x < 0 or Motion.reduce:
					continue
				# a dotted trail behind the bee, fading from its tail
				var head := minf(t, BEE_T)
				var gone := 1.0 - clampf((t - BEE_T) / 0.3, 0.0, 1.0)
				for j in 9:
					var back := head - j * 0.03
					if back < 0.0:
						break
					b.disc(_bee_at(bm, back), maxf(2.0, _u * 0.05) * (1.0 - j / 10.0), Color(Color("fff4c2"), 0.8 * (1.0 - j / 9.0) * gone))
				if bm.has("carry") and t < BEE_T:
					Art.glint(b, _bee_at(bm, t), _u * 0.5, t * 12.0, Color(1, 0.95, 0.7, 0.9))
			"dig":
				pass
	for g: Dictionary in _glints:
		if not _tiles.has(g.id):
			continue
		var t: Dictionary = _tiles[g.id]
		var k: float = g.t / 0.7
		var at := px(t.pos.x, t.pos.y) + Vector2(-s * 0.2, -s * 0.24)
		Art.glint(b, at, s * 0.16 * sin(k * PI), k * 1.2)
	_draw_bits(b, _bits)
	# the whole bed flashes on a big blast
	if _flash > 0.0:
		b.polygon(Face.Builder.round_rect(Vector2.ZERO, field.size, 28.0), Color(_flash_col, 0.55 * _flash * _flash))
	# a long cascade warms the bed's edges
	if _heat > 0.0:
		_draw_heat(b)
	# the lit bombs spit sparks
	if not Motion.reduce:
		for id in _tiles:
			var t: Dictionary = _tiles[id]
			if bool(t.lit):
				var at := px(t.pos.x, t.pos.y) + Vector2.from_angle(_clock * 9.0) * s * 0.45
				Art.glint(b, at, s * 0.14, _clock * 4.0, Color("f7d44a"))

## A warm glow breathing in from the bed's edges while a cascade runs on.
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

static func _quad(b: Face.Builder, p: Array, c: Array) -> void:
	var i0 := b.vertex(p[0], c[0])
	var i1 := b.vertex(p[1], c[1])
	var i2 := b.vertex(p[2], c[2])
	var i3 := b.vertex(p[3], c[3])
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)

## The bits flung about: petals, leaves, sparks, stars, seeds, confetti and
## rings, each fading out over the end of its life.
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
			"petal":
				Art.petal(b, at, 13.0 * sz, 8.0 * sz, rot, col)
			"leaf":
				Art.petal(b, at, 15.0 * sz, 6.0 * sz, rot, col)
				b.stroke(PackedVector2Array([at - Vector2(13.0 * sz, 0).rotated(rot), at + Vector2(12.0 * sz, 0).rotated(rot)]), 1.5, Color(col.darkened(0.3), col.a))
			"confetti":
				Art.petal(b, at, 11.0 * sz, 6.0 * sz * absf(cos(bit.t * 5.0 + rot)) + 1.0, rot, col)
			"seed":
				Art.petal(b, at, 7.0 * sz, 5.0 * sz, rot, col)
			"star":
				Art.star(b, at, 13.0 * sz * (0.6 + 0.4 * a), col, rot)
			"spark":
				Art.glint(b, at, 22.0 * sz * a, rot, Color(col, col.a))
			"ring":
				var k := clampf(bit.t / life, 0.0, 1.0)
				var r := sz * (0.3 + 0.7 * (1.0 - pow(1.0 - k, 3.0)))
				b.stroke(Face.Builder.ring(at, r, r), maxf(2.0, 14.0 * (1.0 - k)), Color(bit.col, (bit.col as Color).a * (1.0 - k)), true)

## How a tile is scaled this frame: popping in, the bump when it turns
## special, the squash when it lands, stretched as it falls.
func _scale(t: Dictionary) -> Vector2:
	if Motion.reduce:
		return Vector2.ONE
	var sc := Vector2.ONE
	if float(t.pop) >= 0.0 and float(t.pop) < 0.4:
		sc *= Motion.back_out(clampf(float(t.pop) / 0.3, 0.0, 1.0))
	if float(t.bump) >= 0.0 and float(t.bump) < 0.4:
		var k := clampf(float(t.bump) / 0.32, 0.0, 1.0)
		var w := sin(k * PI) * (1.0 - k * 0.4)
		sc *= Vector2(1.0 + 0.24 * w, 1.0 + 0.24 * w)
	if float(t.vel) > 0.0:
		var st := minf(0.12, float(t.vel) * 0.005)
		sc *= Vector2(1.0 - st * 0.6, 1.0 + st)
	if float(t.squash) >= 0.0 and float(t.squash) < 0.6:
		var q := float(t.amt) * exp(-float(t.squash) * 11.0) * cos(float(t.squash) * 30.0)
		sc *= Vector2(1.0 + q * 0.75, 1.0 - q)
	return sc

func _draw_pops() -> void:
	var font := get_theme_font("font", "SheetTitle")
	for p: Dictionary in _pops:
		var a := 1.0 - clampf((p.t - 0.55) / 0.45, 0.0, 1.0)
		var rise := 60.0 * (1.0 - exp(-p.t * 4.5))
		var at: Vector2 = p.pos + Vector2(0, -rise) + _shake_off
		at.x = clampf(at.x, 90.0, field.size.x - 90.0)
		var full := 64 if p.big else 46
		var fs := full if Motion.reduce else maxi(8, int(lerpf(14.0, full * 1.0, Motion.back_out(minf(1.0, p.t / 0.22)))))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tilt := 0.0 if Motion.reduce or not p.big else sin(p.t * 14.0) * 0.12 * exp(-p.t * 3.0)
		field.draw_set_transform(at, tilt)
		var o := Vector2(-w * 0.5, 0)
		var col: Color = p.col
		field.draw_string_outline(font, o + Vector2(0, 5), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 18, Color(0.2, 0.12, 0.05, 0.35 * a))
		field.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, Color(Color("fffaf0"), a))
		field.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(col.darkened(0.45), a))
		field.draw_string(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.lightened(0.15), a))
	field.draw_set_transform(Vector2.ZERO)

## Where a flight is `t` seconds in, on its curve.
func _flight_at(f: Dictionary, t: float) -> Vector2:
	var k := clampf(t / float(f.get("time", FLIGHT_T)), 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	return (f.from as Vector2).lerp(f.ctrl, e).lerp((f.ctrl as Vector2).lerp(f.to, e), e)

## Over everything: the stickers' sunbursts, the flights and their trails,
## the day's stars, the air's bits, then the tiles and tools in flight and
## the stickers' letters.
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
		Art.rays(b, st.at, r * 0.2, r, 16, _clock * 0.8, Color(Color("ffe39a"), 0.34 * a))
		Art.rays(b, st.at, r * 0.2, r * 0.8, 16, -_clock * 0.5 + 0.1, Color(Color("fffaf0"), 0.24 * a))
	for f: Dictionary in _flights:
		if f.t < 0.0:
			continue
		var kind := String(f.get("kind", "goal"))
		var col := Art.GOLD if kind != "goal" else Art.paint(int(f.k)).lightened(0.35)
		for j in range(6, 0, -1):
			var back: float = f.t - j * 0.028
			if back < 0.0:
				continue
			b.disc(_flight_at(f, back), (7.0 - j) * (2.4 if kind != "tool" else 4.5), Color(col, 0.1 * (7 - j)))
		if kind == "star":
			var at := _flight_at(f, f.t)
			Art.star(b, at, 26.0, Art.GOLD, f.t * 9.0)
	_draw_day_stars(b)
	_draw_bits(b, _air_bits)
	if not b.verts.is_empty():
		_air_live = b.mesh()
		_air.draw_mesh(_air_live, null)
	for f: Dictionary in _flights:
		if f.t < 0.0:
			continue
		var kind := String(f.get("kind", "goal"))
		var k := clampf(f.t / float(f.get("time", FLIGHT_T)), 0.0, 1.0)
		var p := _flight_at(f, f.t)
		if kind == "goal":
			var sc := lerpf(1.0, 0.6, k * k * (3.0 - 2.0 * k))
			_air.draw_set_transform(p, sin(f.t * 10.0) * 0.2, Vector2(sc, sc))
			_air.draw_mesh(Art.tile(int(f.k), _u * 0.7), null, Transform2D.IDENTITY)
		elif kind == "tool":
			var sc := 1.0 + 0.8 * sin(k * PI)
			_air.draw_set_transform(p, f.t * 8.0, Vector2(sc, sc))
			_air.draw_mesh(Art.tool_icon(Sim.TOOL_KEYS[int(f.tool)], 110.0), null, Transform2D.IDENTITY)
	_air.draw_set_transform(Vector2.ZERO)
	_draw_stickers(font)

## The day's stars under its sticker: earned ones slammed in one after
## another, the rest left as grey slots.
func _draw_day_stars(b: Face.Builder) -> void:
	if _stars.is_empty():
		return
	var t: float = _stars.t
	var a := 1.0 - clampf((t - 2.0) / 0.4, 0.0, 1.0)
	for i in 3:
		var at: Vector2 = _stars.at + Vector2((i - 1) * 110.0, -18.0 if i == 1 else 0.0)
		var r := 58.0 if i == 1 else 46.0
		var slot := clampf((t - 0.05) / 0.2, 0.0, 1.0)
		Art.star(b, at, r * slot, Color(Color("d8cbb2"), 0.9 * a), (i - 1) * 0.15)
		if i >= int(_stars.n):
			continue
		var land := 0.35 + 0.28 * i
		var k := clampf((t - (land - 0.2)) / 0.2, 0.0, 1.0)
		if k <= 0.0:
			continue
		var sc := lerpf(2.8, 1.0, k * k)
		if t > land:
			sc *= 1.0 + 0.1 * sin((t - land) * 5.0) * exp(-(t - land) * 2.0)
		b.disc(at, r * 1.3 * sc, Color(Color("fff4c2"), 0.3 * a))
		Art.star(b, at, r * sc, Color(Art.GOLD, a), (i - 1) * 0.15 + (1.0 - k) * 1.2)

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

# --- the end ---

func _game_over() -> void:
	if _offer_chance():
		return
	_disarm()
	_press = Vector2i(-1, -1)
	_selected = Vector2i(-1, -1)
	var better := Record.add(GAME, sim.score, sim.day, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.day,
		"seconds": secs, "moves": sim.moves, "made": sim.made, "cascade": sim.best_cascade,
		"picked": sim.picked, "tools": sim.tools_used, "best": better, "more_moves": Sim.OFFERS - int(sim.offers)})
	Ads.note_finished()
	_fx.cue("out_of_moves")
	_show_banner(tr("PS_OUT"), "", 1.0)
	top_bar.refresh(self)
	# the bed wilts: every tile tips over and drops away
	for id in _tiles.keys():
		var t: Dictionary = _tiles[id]
		if not Motion.reduce:
			_dying.append({"k": t.k, "sp": t.sp, "pos": t.pos, "into": Vector2.INF, "t": 0.0,
				"vel": Vector2(randf_range(-2.5, 2.5), randf_range(-7.0, -2.0))})
	_tiles.clear()
	get_tree().create_timer(1.4).timeout.connect(_show_end.bind(better))

func _show_end(better: bool) -> void:
	if sim == null or not sim.is_over() or _end != null:
		return
	_fx.cue("new_best" if better else "game_over")
	_end = _build_end(better)
	add_child(_end)
	Motion.appear(_end, 0.0, 1.0, 0.3)
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
	# a posy of the day's tiles, bobbing in a fan
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(0, 220)
	var shown_at := _clock
	var kinds: Array = []
	for g: Dictionary in sim.goals:
		kinds.append(int(g.k))
	for k in 6:
		if kinds.size() >= 5:
			break
		if not kinds.has(k):
			kinds.append(k)
	seat.draw.connect(func() -> void:
		var since := _clock - shown_at
		var mid := Vector2(seat.size.x * 0.5, 250.0)
		var s := 104.0
		if not Motion.reduce:
			var rb := Face.Builder.new()
			var grow := Motion.back_out(clampf(since / 0.5, 0.0, 1.0))
			rb.disc(mid + Vector2(0, -150), 150.0 * grow, Color(Color("fff4c2"), 0.6))
			Art.rays(rb, mid + Vector2(0, -150), 40.0, 250.0 * grow, 16, _clock * 0.5, Color(Color("ffe39a") if better else Color("f3e6c8"), 0.55))
			_seat_mesh = rb.mesh()
			seat.draw_mesh(_seat_mesh, null)
		for i in 5:
			var ang := lerpf(-0.9, 0.9, i / 4.0)
			var rise := 1.0 if Motion.reduce else Motion.back_out(clampf((since - 0.1 * i) / 0.35, 0.0, 1.0))
			var bob := 0.0 if Motion.reduce else sin(_clock * 2.2 + i) * 5.0
			var at := mid + Vector2.from_angle(-PI * 0.5 + ang) * 160.0 + Vector2(0, bob)
			seat.draw_set_transform(at, ang * 0.4, Vector2(rise, rise))
			seat.draw_mesh(Art.tile(kinds[i], s) if i != 2 else Art.tile(-1, s * 1.1), null, Transform2D.IDENTITY)
		seat.draw_set_transform(Vector2.ZERO))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "PS_END_CARD"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var score := Label.new()
	score.text = Record.grouped(0 if not Motion.reduce else sim.score)
	if not Motion.reduce:
		_end_score = score
		_end_at = _clock
	score.theme_type_variation = "DayBig"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 14)
	for pair in [[str(sim.day), "PS_STAT_DAY"], [str(sim.made), "PS_STAT_MADE"], [str(sim.best_cascade), "PS_STAT_CASCADE"]]:
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
			plate.modulate.a = 0.0
			var tw := plate.create_tween()
			tw.tween_interval(0.9 + 0.18 * stats.get_child_count())
			tw.tween_callback(func() -> void:
				plate.pivot_offset = plate.size * 0.5
				plate.scale = Vector2(0.4, 0.4)
				_fx.cue("land", 1.2 + 0.1 * plate.get_index(), -4.0))
			tw.tween_property(plate, "modulate:a", 1.0, 0.12)
			tw.parallel().tween_property(plate, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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

## The end card's score runs up from nothing to what the game made.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.3) / 1.1, 0.0, 1.0)
	var shown := int(sim.score * (1.0 - pow(1.0 - k, 3.0)))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
		if int(_clock * 20.0) % 2 == 0:
			_fx.cue("collect", 0.9 + 0.5 * k, -12.0)
	if k >= 1.0:
		_end_score.pivot_offset = _end_score.size * 0.5
		_kick(_end_score, 0.25, 0.4)
		_end_score = null

func _celebrate(better: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fx := Fx2D.new()
	_end.add_child(fx)
	var mid := size * 0.5
	for k in (14 if better else 5):
		var at := mid + Vector2.from_angle(TAU * k / (14.0 if better else 5.0) - PI * 0.5) * Vector2(400.0, 330.0)
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
	if sim != null and not sim.is_over() and sim.moves > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.day})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	if _offer != null:
		_end_offer()
		return
	if _armed >= 0:
		_disarm()
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
		_show_banner(tr("CHANCE_GO"), "", 1.0)
		_over_said = false
		_take_events()
		top_bar.refresh(self))
	card.declined.connect(_game_over)
	add_child(card)
	return true
