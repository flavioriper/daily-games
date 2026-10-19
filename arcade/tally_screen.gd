extends Control

## Tally: the fourteenth game on the Arcade tab, a number factory on a sheet
## of squared paper (spec docs/superpowers/specs/2026-10-15-arcade-tally-design.md).
## **The paper is the whole screen**, edge to edge (the rule since
## 2026-10-10). Over it lie the flat boards' top bar, a plate row (the
## counting box's goal, the flow sheet's bars -- what comes into the box a
## second, arcade/tally_flow.gd -- and the upgrades with a dot when one can
## be bought)
## and at the foot the tray: one row docked to the screen's bottom edge, the
## tools handed over so far (Look, Belt, Dig, Rotate, Remove, Parts, the
## Crate, the five operators, as they open), sliding sideways under a finger
## when they outgrow the screen (the user, 2026-10-19: "a fixed bottom menu
## with just 1 row, and scrollable to left. Only show unlocked ones"); the
## held tool pressed again is put down. The
## board's hand (arcade/tally_board.gd) traces paths and drops ghosts with
## pills; after a path laid or a lift an **undo chip** (a round paper button
## at the tray's top-left corner) rests for UNDO_FOR seconds and takes that
## one gesture back (spec 2026-10-15-tally-builder-and-tree-design.md).
##
## **A kept game, like the Factory**: no run, no end card, no gold. The sim
## (arcade/tally_sim.gd) is loaded when the screen opens and saved after a
## change, every twenty seconds, when the app loses focus and when the
## screen is left. The paper runs only while it is on screen.
##
## The moments (arcade/rewards.gd over everything): a level done is named
## with confetti and the box glows; a piece handed over hops into the tray;
## a number now dug lights its pencil rings; an upgrade that can be bought
## rings its button; the box's tick is heard for a target coming in, quietly
## and not too often.
##
## **Picks and parts** (the user, 2026-10-19): a finger held on the paper
## under Look picks pieces with a rectangle (the board's pick pill: Copy,
## Duplicate, Remove with an Undo after it, Save as part). A part is a
## template: the tray's Parts slot opens their card (arcade/tally_parts.gd),
## Place hands the board the template to set down as plain pieces, the bin
## throws it away; nothing set down from it changes with it.

signal closed

const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Board = preload("res://arcade/tally_board.gd")
const Shop = preload("res://arcade/tally_shop.gd")
const Parts = preload("res://arcade/tally_parts.gd")
const Flow = preload("res://arcade/tally_flow.gd")
const Card = preload("res://arcade/tally_card.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")
const Rewards = preload("res://arcade/rewards.gd")
const Face = preload("res://ui/faces/face.gd")

const GAME := "tally"
const MARGIN := 40
const GAP := 20
const HUD_H := 120.0
const ROW_H := 128.0
const TRAY_H := ROW_H + 20.0
## A slot's width once the tools outgrow the tray, and the room at its ends.
const SLOT_W := 122.0
const TRAY_PAD := 12.0
const TRAY_SLOP := 14.0
const SAVE_EVERY := 20.0
const SAVE_AFTER := 4.0
## The box's tick for a target coming in, at most this often.
const HIT_GAP := 0.14
## A machine's sum is a pop at most this often, so a busy paper patters.
const OP_GAP := 0.16
## The open shop catches up with the tally at most this often.
const SHOP_EVERY := 0.25
## The tray's tools in order: the hands, the belt and the dig, then what is
## set down on the paper after. A slot is a place among those open.
const TOOLS := ["move", "belt", "dig", "turn", "remove", "parts", "crate", "add", "mul", "sub", "div", "pow"]
const HAPTICS := {}
## The undo chip: how long it rests, its disc's radius, how far it stands
## over the tray's top-left corner.
const UNDO_FOR := 6.0
const UNDO_R := 46.0
const UNDO_OVER := Vector2(6.0, -30.0)
## The Straight toggle's capsule.
const LINE_W := 220.0
const LINE_H := 64.0

var sim: RefCounted
var top_bar: Control
var settings_sheet: Control
var tutor: RefCounted
var board: Control
var tray: Control
var hud: Control
var _fx: Node2D
var _rw: Rewards
var _margins: MarginContainer
var _font: Font
var _clock := 0.0
var _knock := -1
var _saved_at := 0.0
var _changed_at := -1.0
var _opened_at := 0
var _hit_at := -10.0
var _said_at := {}
## What the open shop last showed: the tally's count and level, and when.
var _shop_saw := Vector2i(-1, -1)
var _shop_at := -10.0
var _chip_at := {}
var _slot_down := -1
var _slot_touch := -2
## The tray slid this far left; where the finger went down on it, whether it
## is sliding, and how fast it was going when let go.
var _tray_x := 0.0
var _tray_from := Vector2.ZERO
var _tray_x0 := 0.0
var _tray_slid := false
var _tray_vel := 0.0
var _tray_moved_at := 0
var _tray_style: StyleBoxFlat
var _hud_down := -1
var _hud_live: ArrayMesh
var _tray_live: ArrayMesh
var _marks_live: ArrayMesh
var _shown_got := -1
var _bar := 0.0
var _ready_on := false
var _ready_n := 0
var undo_chip: Control
## The Straight toggle, up over the tray's top-right corner while Belt is held.
var line_chip: Control
var _line_down := false
var _line_at := -10.0
var _line_live: ArrayMesh
var _undo_at := -10.0
var _undo_down := false
var _undo_live: ArrayMesh

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_font = theme.get_font("font", "SheetTitle")
	sim = Sim.load_saved()
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Tally")
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	# the tray is laid by hand, so a new size lays it again
	resized.connect(_apply_insets)
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_opened_at = Time.get_ticks_msec()
	_ready_on = sim.any_ready()
	_fx.cue("start")
	_first_hint.call_deferred()
	Analytics.track("tally_enter", {"level": sim.level, "made": sim.made})

func _notification(what: int) -> void:
	if sim == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		sim.save()

## A new paper says where to begin, once.
func _first_hint() -> void:
	if sim.level == 1 and sim.digs.is_empty() and _rw != null:
		_rw.sticker(tr("TL_HINT_START"), _rw.at(self, size * Vector2(0.5, 0.36)), 40, 4.0, false, Color("fff4c2"), false, "hint", 0.0, true)

# --- building ---

func _build() -> void:
	board = Board.new()
	board.name = "Board"
	board.sim = sim
	board.font = _font
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.refused.connect(_on_refused)
	board.touched.connect(func(pitch: float) -> void:
		_fx.touch(pitch)
		_feel(Haptics.TAP))
	board.asked.connect(_show_piece)
	board.box_asked.connect(_show_box)
	board.part_saved.connect(_on_part_saved)
	add_child(board)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	board.add_child(_fx)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Tally", tr("TL_MOTTO"), false)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	hud = Control.new()
	hud.name = "Hud"
	hud.custom_minimum_size.y = HUD_H
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.draw.connect(_draw_hud)
	hud.gui_input.connect(_on_hud_input)
	col.add_child(hud)

	# the tray is docked to the bottom edge, the full width, under the margins
	tray = Control.new()
	tray.name = "Tray"
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	tray.clip_contents = true
	tray.draw.connect(_draw_tray)
	tray.gui_input.connect(_on_tray_input)
	add_child(tray)
	_tray_style = CozyTheme.lifted(Color("fcf7ef"), 36, 8)
	_tray_style.corner_radius_bottom_left = 0
	_tray_style.corner_radius_bottom_right = 0
	_tray_style.shadow_offset = Vector2(0.0, -4.0)

	undo_chip = Control.new()
	undo_chip.name = "UndoChip"
	undo_chip.size = Vector2.ONE * (UNDO_R * 2.0 + 16.0)
	undo_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	undo_chip.visible = false
	undo_chip.draw.connect(_draw_undo)
	undo_chip.gui_input.connect(_on_undo_input)
	add_child(undo_chip)

	line_chip = Control.new()
	line_chip.name = "LineChip"
	line_chip.size = Vector2(LINE_W + 16.0, LINE_H + 16.0)
	line_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	line_chip.visible = false
	line_chip.draw.connect(_draw_line_chip)
	line_chip.gui_input.connect(_on_line_input)
	add_child(line_chip)

	_rw = Rewards.new()
	add_child(_rw)
	_apply_insets()

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_lay_board()

## The paper fills the screen; its camera looks at the room between the
## plates and the tray.
func _lay_board() -> void:
	if board == null or size.x <= 0.0:
		return
	var insets := SafeArea.insets(self)
	var top := MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + GAP
	var foot := insets.y + TRAY_H + GAP
	board.set_view(Rect2(0.0, top, size.x, maxf(60.0, size.y - top - foot)))
	tray.position = Vector2(0.0, size.y - insets.y - TRAY_H)
	tray.size = Vector2(size.x, TRAY_H + insets.y)
	_tray_x = clampf(_tray_x, 0.0, _tray_most())
	# the undo chip's disc stands on the tray's top-left corner
	var corner := Vector2(MARGIN, size.y - insets.y - TRAY_H)
	undo_chip.position = corner + Vector2(UNDO_R, 0.0) + UNDO_OVER - undo_chip.size * 0.5
	# the Straight toggle on its top-right corner
	var right := Vector2(size.x - MARGIN, corner.y)
	line_chip.position = right + Vector2(-LINE_W * 0.5 - 6.0, -LINE_H * 0.5 - 22.0) - line_chip.size * 0.5

# --- the top bar's questions ---

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/tally_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.DIG, "TUT_TALLY_DIG", tr("TUT_TALLY_DIG_BODY")],
		[Diagram.Lesson.BOX, "TUT_TALLY_BOX", tr("TUT_TALLY_BOX_BODY")],
		[Diagram.Lesson.MACHINE, "TUT_TALLY_MACHINE", tr("TUT_TALLY_MACHINE_BODY")],
		[Diagram.Lesson.BELTS, "TUT_TALLY_BELTS", tr("TUT_TALLY_BELTS_BODY")],
		[Diagram.Lesson.UPGRADE, "TUT_TALLY_UPGRADE", tr("TUT_TALLY_UPGRADE_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

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

# --- the frame ---

func _busy() -> bool:
	return get_node_or_null("Card") != null or get_node_or_null("Shop") != null or get_node_or_null("Parts") != null or get_node_or_null("Flow") != null

## Too busy for the paper's own sounds: a card up.
func _quiet() -> bool:
	return _busy()

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	if not tutor.is_open():
		sim.step(minf(delta, 0.25))
	_play_events()
	_follow_shop()
	board.tick(delta)
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1
	if _changed_at >= 0.0 and _clock - _changed_at > SAVE_AFTER:
		_save()
	elif _clock - _saved_at > SAVE_EVERY:
		_save()
	var fill := float(sim.got) / maxf(1.0, float(sim.count()))
	_bar = fill if Motion.reduce else lerpf(_bar, fill, 1.0 - exp(-10.0 * delta))
	var n := 0
	for id: String in Sim.TRACKS:
		if sim.can_buy(id):
			n += 1
	_ready_n = n
	_ready_on = n > 0
	var chip_up: bool = sim.can_undo() and _clock - _undo_at < UNDO_FOR and not _busy()
	if undo_chip.visible != chip_up:
		undo_chip.visible = chip_up
		_undo_down = false
	if _slot_touch == -2 and absf(_tray_vel) > 1.0:
		# the tray's fling runs down
		_tray_x = clampf(_tray_x + _tray_vel * minf(delta, 0.05), 0.0, _tray_most())
		_tray_vel *= exp(-6.0 * delta)
		if _tray_x <= 0.0 or _tray_x >= _tray_most():
			_tray_vel = 0.0
	hud.queue_redraw()
	tray.queue_redraw()
	if chip_up:
		undo_chip.queue_redraw()
	var line_up: bool = board.tool == "belt" and not _busy()
	if line_chip.visible != line_up:
		line_chip.visible = line_up
		_line_down = false
	if line_up:
		line_chip.queue_redraw()

## Numbers into the box while the shop is open show on its plates and its
## foot as they come (the user, 2026-10-16: "i need to close and reopen").
func _follow_shop() -> void:
	var shop := get_node_or_null("Shop")
	if shop == null:
		_shop_saw = Vector2i(-1, -1)
		return
	var saw := Vector2i(sim.made, sim.level)
	if saw == _shop_saw or _clock - _shop_at < SHOP_EVERY:
		return
	_shop_saw = saw
	_shop_at = _clock
	shop.refresh()

func _save() -> void:
	_saved_at = _clock
	_changed_at = -1.0
	sim.save()

func _changed() -> void:
	if _changed_at < 0.0:
		_changed_at = _clock

## Asks for a knock this frame; the strongest asked for is the one played.
func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

# --- the sim's events ---

func _once(id: String, every: float) -> bool:
	if _clock - float(_said_at.get(id, -1000.0)) < every:
		return false
	_said_at[id] = _clock
	return true

func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(board, p)

func _square_rw(t: Vector2i) -> Vector2:
	return _in_rw(board.screen_of(Vector2(t) + Vector2(0.5, 0.5)))

func _top() -> Vector2:
	return _rw.at(self, size * Vector2(0.5, 0.4))

func _play_events() -> void:
	_play_from(sim)

func _play_from(src: RefCounted) -> void:
	if src.events.is_empty():
		return
	var evs: Array = src.events.duplicate()
	src.events.clear()
	for ev: Dictionary in evs:
		if board.sim == src:
			board.play(ev)
		match String(ev.type):
			"lay":
				_fx.cue("lay", randf_range(0.96, 1.04) * pow(2.0, mini(int(ev.n) - 1, 5) / 24.0))
				_feel(Haptics.TICK)
				_changed()
				_undo_at = _clock
			"place":
				_fx.cue("place", randf_range(0.95, 1.05))
				_feel(Haptics.TAP)
				_changed()
				_undo_at = -10.0
			"turn", "flip":
				_fx.cue("turn", randf_range(0.96, 1.04))
				_feel(Haptics.TICK)
				_changed()
				_undo_at = -10.0
			"lift", "erase":
				_fx.cue("lift", randf_range(0.95, 1.05))
				_feel(Haptics.TICK)
				_changed()
				_undo_at = _clock
			"emptied":
				_fx.cue("lift", randf_range(0.95, 1.05))
				_feel(Haptics.TICK)
				_changed()
			"undo":
				_fx.cue("lift", 0.9)
				_feel(Haptics.TICK)
				_changed()
				_undo_at = -10.0
			"part":
				_changed()
			"op":
				if _once("op", OP_GAP) and not _quiet():
					_fx.cue("op", randf_range(0.95, 1.05) * pow(2.0, mini(str(absi(int(ev.v))).length() - 1, 4) / 12.0))
			"off_target":
				_fx.cue("nope", 1.0, -6.0)
				_feel(Haptics.WARN)
				_rw.sticker(tr("TL_SAY_NOT_TARGET") % [Sim.short(int(ev.v)), Sim.short(int(ev.came))],
					_square_rw(Sim.HUB_AT + Vector2i.ONE * (Sim.HUB >> 1)) + Vector2(0, -70.0), 36, 3.2, false, Color("fffaf0"), false, "say", 20.0)
			"hit":
				if _clock - _hit_at > HIT_GAP and not _quiet():
					_hit_at = _clock
					_chip_at[-2] = _clock
					_fx.cue("deliver", randf_range(0.97, 1.03), -4.0)
			"level":
				_on_level(int(ev.n))
			"unlock":
				_on_unlock(int(ev.reward))
			"upgrade":
				_on_upgrade(String(ev.id), int(ev.level))
			"ready":
				_on_ready(String(ev.id))
			"refused":
				_on_refused(String(ev.why), board.screen_of(Vector2(ev.get("tile", Vector2i.ZERO)) + Vector2(0.5, 0.5)), int(ev.get("v", 0)))

func _on_level(n: int) -> void:
	_chip_at[-2] = _clock + 0.05
	_fx.cue("level")
	_feel(Haptics.WIN)
	var at := _top()
	_rw.sticker(tr("TL_LEVEL_DONE") % (n - 1), at, 72, 2.2, true, Color.WHITE, true, "level")
	_rw.sticker(tr("TL_NOW_ASKS") % [Sim.short(sim.target()), Sim.short(sim.count())], at + Vector2(0, 92.0), 40, 2.4, false, Color("fff4c2"), false, "asks", 0.0, true)
	_rw.rain(1.4, ["confetti", "star"], Rewards.CONFETTI)
	_rw.spray(_square_rw(Sim.HUB_AT + Vector2i.ONE * (Sim.HUB >> 1)), Pal.SUN, 14, 600.0, "star", 1.0)
	Analytics.track("tally_level", {"level": n, "made": sim.made})
	_save()

func _on_unlock(r: int) -> void:
	_fx.cue("unlock")
	_feel(Haptics.GOOD)
	var at := _top() + Vector2(0, 170.0)
	if r < 0:
		_rw.sticker(tr("TL_NEW_DIG") % -r, at, 44, 2.6, false, Color("fff4c2"), false, "unlock", 0.0, true)
		return
	_rw.sticker(tr("TL_NEW_PIECE") % tr("TL_PIECE_" + String(Sim.KIND_IDS[r]).to_upper()), at, 48, 2.6, true, Color.WHITE, true, "unlock", 0.0, true)
	var slot := slot_of(String(Sim.KIND_IDS[r]))
	if slot >= 0:
		# the new tool slides into sight and hops
		scroll_to(slot, true)
		_chip_at[slot] = _clock
		_rw.ring(_rw.at(tray, _slot_mid(slot)), 90.0, Pal.SUN)
		_rw.spray(_rw.at(tray, _slot_mid(slot)), Pal.SUN, 10, 380.0, "star", 0.9)

func _on_upgrade(id: String, level: int) -> void:
	_fx.cue("buy", randf_range(0.97, 1.03))
	_fx.cue("upgrade", minf(pow(2.0, (level - 2) * 0.25 / 12.0), 1.3))
	_feel(Haptics.GOOD)
	_rw.sticker(tr("TL_UPGRADED") % [tr("TL_TRACK_" + id.to_upper()), level], _top(), 50, 1.8, false, Color("fff4c2"), true, "up")
	Analytics.track("tally_upgrade", {"tile": id, "level": level})
	_ready_on = sim.any_ready()
	_save()

func _on_ready(id: String) -> void:
	_ready_on = true
	if not _once("ready", 6.0):
		return
	_fx.cue("ready")
	_feel(Haptics.TAP)
	_rw.sticker(tr("TL_READY") % tr("TL_TRACK_" + id.to_upper()), _rw.at(hud, _up_rect().get_center() + Vector2(-180.0, 110.0)), 36, 2.4, false, Color("fff4c2"), false, "ready")
	_rw.ring(_rw.at(hud, _up_rect().get_center()), 80.0, Pal.SUN)

## A touch the paper could not do.
func _on_refused(why: String, at: Vector2, n: int) -> void:
	var p := _in_rw(at) + Vector2(0, -60.0)
	var text := ""
	match why:
		"short":
			# a rank the ledger cannot pay: the shop shivers its bar, the ear hears no
			_fx.cue("nope")
			_feel(Haptics.WARN)
			return
		"printed":
			if sim.can_dig(n):
				text = tr("TL_SAY_DIG_IT") % n
			else:
				text = tr("TL_SAY_DIG_FROM") % [n, Sim.dig_level(n) + 1]
			_fx.touch(0.9)
			_feel(Haptics.TAP)
			_rw.sticker(text, p, 36, 1.8, false, Color("fffaf0"), false, "say", 20.0)
			return
		"not_yet":
			text = tr("TL_SAY_DIG_FROM") % [n, Sim.dig_level(n) + 1]
		"no_number":
			text = tr("TL_SAY_ON_NUMBER")
		"locked":
			text = tr("TL_SAY_LOCKED") % n
		"box":
			text = tr("TL_SAY_BOX")
		"no_room":
			text = tr("TL_SAY_NO_ROOM")
		"no_turn":
			text = tr("TL_SAY_NO_TURN")
		_:
			text = tr("TL_SAY_TAKEN")
	_fx.cue("nope")
	_feel(Haptics.WARN)
	_rw.sticker(text, p, 36, 1.6, false, Color("fffaf0"), false, "nope", 20.0)

# --- the plate row ---

func _goal_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(hud.size.x - HUD_H * 2.0 - 40.0, hud.size.y))

## The flow sheet's plate, between the goal and the upgrades.
func _flow_rect() -> Rect2:
	return Rect2(Vector2(hud.size.x - HUD_H * 2.0 - 20.0, 0.0), Vector2(HUD_H, hud.size.y))

func _up_rect() -> Rect2:
	return Rect2(Vector2(hud.size.x - HUD_H, 0.0), Vector2(HUD_H, hud.size.y))

func _draw_hud() -> void:
	if hud.size.x <= 0.0:
		return
	var g := _goal_rect()
	var u := _up_rect()
	var fr := _flow_rect()
	hud.draw_style_box(CozyTheme.lifted(Color("fcf7ef"), 30, 8), g)
	hud.draw_style_box(CozyTheme.lifted(Color("fcf7ef"), 30, 8), fr)
	hud.draw_style_box(CozyTheme.lifted(Color("fcf7ef"), 30, 8), u)
	var b := Face.Builder.new()
	var fpress := 1.0 if Motion.reduce else Motion.bump_scale(_clock - float(_chip_at.get(-3, -10.0)), 0.14, 0.2)
	var fm := fr.get_center()
	b.disc(fm + Vector2(0, 4.0), 40.0 * fpress, Color(Pal.TEXT, 0.16))
	b.disc(fm, 40.0 * fpress, Color("f3ead6"))
	var mid := Vector2(g.position.x + 70.0, g.get_center().y)
	var bar := Rect2(Vector2(g.position.x + 140.0, g.end.y - 34.0), Vector2(g.size.x - 170.0, 14.0))
	b.polygon(Face.Builder.round_rect(bar.position, bar.size, 7.0), Color(Pal.TEXT, 0.1))
	if _bar > 0.002:
		b.polygon(Face.Builder.round_rect(bar.position, Vector2(maxf(bar.size.x * _bar, 14.0), bar.size.y), 7.0), Pal.GOOD)
	var press := 1.0 if Motion.reduce else Motion.bump_scale(_clock - float(_chip_at.get(-1, -10.0)), 0.14, 0.2)
	var um := u.get_center()
	b.disc(um + Vector2(0, 4.0), 40.0 * press, Color(Pal.TEXT, 0.16))
	b.disc(um, 40.0 * press, Pal.ACCENT_DEEP)
	if _ready_on:
		# a count of the ranks that can be bought, on the sun dot
		var beat := 0.0 if Motion.reduce else 1.5 * sin(_clock * 4.0)
		b.disc(um + Vector2(32, -32), 18.0, Color("fffaf0"))
		b.disc(um + Vector2(32, -32), 14.0 + beat, Pal.SUN)
	_hud_live = b.mesh()
	hud.draw_mesh(_hud_live, null)
	if _ready_on:
		var n := str(_ready_n)
		var nw := _font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		hud.draw_string(_font, um + Vector2(32.0 - nw * 0.5, -32.0 + 19.0 * 0.36), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Pal.TEXT)
	var hop := 1.0 if Motion.reduce else Motion.bump_scale(_clock - float(_chip_at.get(-2, -10.0)), 0.08, 0.16)
	hud.draw_mesh(Art.token(true), null, Transform2D(0.0, Vector2.ONE * 1.25 * hop, 0.0, mid))
	var txt := Sim.short(sim.target())
	var fs := 34 if txt.length() <= 3 else (27 if txt.length() == 4 else 22)
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	hud.draw_string(_font, mid + Vector2(-w * 0.5, fs * 0.36 - 3.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)
	hud.draw_string(_font, Vector2(bar.position.x, g.position.y + 40.0), tr("TL_LEVEL") % sim.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ACCENT_2)
	hud.draw_string(_font, Vector2(bar.position.x, g.position.y + 76.0), tr("TL_GOAL") % [Sim.short(sim.got), Sim.short(sim.count()), Sim.short(sim.target())], HORIZONTAL_ALIGNMENT_LEFT, bar.size.x, 30, Pal.TEXT)
	Icons.paint(hud, "trend", Rect2(um - Vector2(22, 22) * press, Vector2(44, 44) * press), Pal.SURFACE)
	Icons.paint(hud, "bars", Rect2(fm - Vector2(22, 22) * fpress, Vector2(44, 44) * fpress), Art.INK)

func _on_hud_input(event: InputEvent) -> void:
	var at := Vector2(-1, -1)
	var down := false
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
	else:
		return
	var which := 1 if _up_rect().has_point(at) else (2 if _flow_rect().has_point(at) else (0 if _goal_rect().has_point(at) else -1))
	if down:
		_hud_down = which
	elif which == _hud_down and which >= 0:
		_hud_down = -1
		if which == 1:
			open_shop()
		elif which == 2:
			open_flow()
		else:
			_show_box()

# --- the tray ---

## The tray's tools, those handed over only.
func _tools() -> Array:
	return TOOLS.filter(_tool_open)

## A slot's width: the tray shared out while the tools fit, else SLOT_W.
func _slot_w() -> float:
	var n := maxi(1, _tools().size())
	return maxf(SLOT_W, (tray.size.x - TRAY_PAD * 2.0) / n)

## How far the tray can slide.
func _tray_most() -> float:
	if tray == null:
		return 0.0
	return maxf(0.0, TRAY_PAD * 2.0 + _tools().size() * _slot_w() - tray.size.x)

func _slot_mid(slot: int) -> Vector2:
	return Vector2(TRAY_PAD + _slot_w() * (slot + 0.5) - _tray_x, 14.0 + 50.0)

## The tool in `slot`.
func tool_of(slot: int) -> String:
	return _tools()[slot]

## Every slot shown, left to right.
func slots() -> Array:
	return range(_tools().size())

## The slot of tool `id`, or -1 while it is shut.
func slot_of(id: String) -> int:
	return _tools().find(id)

## The tray slid so `slot` is wholly in sight.
func scroll_to(slot: int, at_once := false) -> void:
	var w := _slot_w()
	var lo := TRAY_PAD + w * slot
	var to := clampf(_tray_x, lo + w - tray.size.x + TRAY_PAD, lo - TRAY_PAD)
	to = clampf(to, 0.0, _tray_most())
	if at_once or Motion.reduce:
		_tray_x = to
		_tray_vel = 0.0
	else:
		_tray_vel = 0.0
		var tw := create_tween()
		tw.tween_property(self, "_tray_x", to, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## The kind a tool places, or -1 for Move and Remove.
static func tool_kind(id: String) -> int:
	return int(Board.TOOL_KINDS.get(id, -1))

func _tool_open(id: String) -> bool:
	if id == "parts":
		return sim.parts_open()
	var kd := tool_kind(id)
	return kd < 0 or sim.has(kd)

## The level a shut tool comes at, as its sticker says it.
func _open_at(id: String) -> int:
	var kd := Sim.ADD if id == "parts" else tool_kind(id)
	return int(Sim.UNLOCK.get(kd, 0)) + 1

## Whether `id` is the tool in hand (Parts while copies are being set).
func _holding(id: String) -> bool:
	return board.tool == id or (id == "parts" and board.tool == "part")

## A finger on the tray: a press and release on one slot picks it; a finger
## that goes sideways past TRAY_SLOP slides the tray instead, with a fling.
func _on_tray_input(event: InputEvent) -> void:
	var at := Vector2(-1, -1)
	var id := -2
	if event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _slot_touch:
			_tray_drag(e.position)
		return
	if event is InputEventMouseMotion:
		if _slot_touch == -1:
			_tray_drag((event as InputEventMouseMotion).position)
		return
	var down := false
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
		id = (event as InputEventScreenTouch).index
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
		id = -1
	else:
		return
	var slot := _slot_at(at)
	if down:
		if _slot_touch == -2:
			_slot_down = slot
			_slot_touch = id
			_tray_from = at
			_tray_x0 = _tray_x
			_tray_slid = false
			_tray_vel = 0.0
			_tray_moved_at = Time.get_ticks_msec()
	elif id == _slot_touch:
		var was := _slot_down
		_slot_down = -1
		_slot_touch = -2
		if _tray_slid:
			_tray_slid = false
			if Time.get_ticks_msec() - _tray_moved_at > 90 or Motion.reduce:
				_tray_vel = 0.0
		elif was >= 0 and was == slot:
			press_slot(slot)

func _tray_drag(p: Vector2) -> void:
	if not _tray_slid and absf(p.x - _tray_from.x) < TRAY_SLOP:
		return
	if not _tray_slid:
		_tray_slid = true
		_slot_down = -1
	var was := _tray_x
	_tray_x = clampf(_tray_x0 - (p.x - _tray_from.x), 0.0, _tray_most())
	var now := Time.get_ticks_msec()
	_tray_vel = lerpf(_tray_vel, (_tray_x - was) / maxf(0.008, (now - _tray_moved_at) / 1000.0), 0.5)
	_tray_moved_at = now

## The slot under `at` (the tray's pixels), or -1.
func _slot_at(at: Vector2) -> int:
	var j := int(floorf((at.x + _tray_x - TRAY_PAD) / _slot_w()))
	return j if j >= 0 and j < _tools().size() else -1

## A press on the tray: picks the tool; the held tool pressed again is put
## down (Look). Nothing here turns anything (the user, 2026-10-15: a tap
## that turned a machine was how the numbers stopped).
func press_slot(slot: int) -> void:
	var id := tool_of(slot)
	_chip_at[slot] = _clock
	if not _tool_open(id):
		_fx.cue("nope")
		_feel(Haptics.WARN)
		_rw.sticker(tr("TL_SAY_LOCKED") % _open_at(id), _rw.at(tray, _slot_mid(slot) + Vector2(0, -90.0)), 34, 1.6, false, Color("fffaf0"), false, "nope", 20.0)
		return
	if id == "parts":
		if board.tool == "part":
			board.set_tool("move")
			_chip_at[0] = _clock
			_fx.touch(0.94)
			_feel(Haptics.TAP)
			return
		open_parts()
		return
	if board.tool == id and id != "move":
		board.set_tool("move")
		_chip_at[0] = _clock
		_fx.touch(0.94)
		_feel(Haptics.TAP)
		return
	board.set_tool(id)
	_fx.touch(1.0 + 0.03 * slot)
	_feel(Haptics.TAP)

# --- the undo chip ---

## The chip fades in and out with Motion; still, it is simply on or off.
func _undo_alpha() -> float:
	var t := _clock - _undo_at
	if Motion.reduce:
		return 1.0
	return clampf(minf(t * 5.0, (UNDO_FOR - t) * 2.5), 0.0, 1.0)

func _draw_undo() -> void:
	var a := _undo_alpha()
	if a <= 0.0:
		return
	var c := undo_chip.size * 0.5
	var press := 0.94 if _undo_down else 1.0
	var b := Face.Builder.new()
	b.disc(c + Vector2(0, 5.0), UNDO_R * press, Color(Pal.TEXT, 0.16 * a))
	b.disc(c, UNDO_R * press, Color(Color("fcf7ef"), a))
	b.stroke(Face.Builder.ring(c, UNDO_R * press, UNDO_R * press), 3.0, Color(Pal.SUN, 0.9 * a), true)
	Art.glyph_into(b, "undo_back", Rect2(c + Vector2(-19.0, -30.0) * press, Vector2(38.0, 38.0) * press), Color(Art.INK, a))
	_undo_live = b.mesh()
	undo_chip.draw_mesh(_undo_live, null)
	var cap := tr("TL_UNDO")
	undo_chip.draw_string(_font, Vector2(c.x - UNDO_R, c.y + 30.0 * press), cap, HORIZONTAL_ALIGNMENT_CENTER, UNDO_R * 2.0, 18, Color(Art.INK, 0.85 * a))

func _on_undo_input(event: InputEvent) -> void:
	var at := Vector2(-1, -1)
	var down := false
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
	else:
		return
	var inside := at.distance_to(undo_chip.size * 0.5) <= UNDO_R + 8.0
	if down:
		_undo_down = inside
	elif _undo_down:
		_undo_down = false
		if inside:
			undo()

## The Straight toggle: a paper capsule, a ruler line and its caption; on,
## it wears the sun and the line is straight; off, the line bends.
func _draw_line_chip() -> void:
	var r := Rect2(Vector2(8.0, 8.0), Vector2(LINE_W, LINE_H))
	var on: bool = sim.straight
	var sc := 0.95 if _line_down else (1.0 if Motion.reduce else Motion.bump_scale(_clock - _line_at, 0.12, 0.2))
	var c := r.get_center()
	line_chip.draw_set_transform(c - c * sc, 0.0, Vector2(sc, sc))
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(r.position + Vector2(0, 5.0), r.size, LINE_H * 0.5), Color(Pal.TEXT, 0.16))
	b.polygon(Face.Builder.round_rect(r.position, r.size, LINE_H * 0.5), Pal.SUN if on else Color("fcf7ef"))
	b.stroke(Face.Builder.round_rect(r.position, r.size, LINE_H * 0.5), 3.0, Color(Pal.SUN, 0.9) if not on else Color(Art.INK, 0.25), true)
	var g := Vector2(r.position.x + 34.0, c.y)
	var col := Art.INK if on else Color(Art.INK, 0.55)
	if on:
		b.stroke(PackedVector2Array([g + Vector2(-16, 12), g + Vector2(16, -12)]), 7.0, col)
	else:
		b.stroke(PackedVector2Array([g + Vector2(-16, 12), g + Vector2(-16, -8), g + Vector2(16, -8)]), 7.0, col)
	_line_live = b.mesh()
	line_chip.draw_mesh(_line_live, null)
	var cap := tr("TL_STRAIGHT_ON") if on else tr("TL_STRAIGHT_OFF")
	line_chip.draw_string(_font, Vector2(r.position.x + 60.0, c.y + 8.0), cap, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 70.0, 22, col)
	line_chip.draw_set_transform(Vector2.ZERO)

func _on_line_input(event: InputEvent) -> void:
	var at := Vector2(-1, -1)
	var down := false
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
	else:
		return
	var inside := Rect2(Vector2.ZERO, line_chip.size).grow(8.0).has_point(at)
	if down:
		_line_down = inside
	elif _line_down:
		_line_down = false
		if inside:
			toggle_straight()

## Straight lines on or off for the belt tool (the chip, or a harness).
func toggle_straight() -> void:
	sim.straight = not sim.straight
	_line_at = _clock
	_fx.touch(1.06 if sim.straight else 0.94)
	_feel(Haptics.TAP)
	_changed_at = _clock

## The last gesture taken back (the chip, or a harness).
func undo() -> void:
	if not sim.can_undo():
		return
	board.let_go()
	sim.undo()
	_undo_at = -10.0

func _draw_tray() -> void:
	if tray.size.x <= 0.0:
		return
	tray.draw_style_box(_tray_style, Rect2(Vector2(0.0, 0.0), tray.size + Vector2(0.0, 40.0)))
	var still := Motion.reduce
	var b := Face.Builder.new()
	var marks := Face.Builder.new()
	for slot: int in slots():
		var id := tool_of(slot)
		var at := _slot_mid(slot)
		var on: bool = _holding(id)
		var sc := 1.0 if still else Motion.bump_scale(_clock - float(_chip_at.get(slot, -10.0)), 0.16, 0.22)
		var open := _tool_open(id)
		if on:
			b.disc(at, 52.0 * sc, Pal.SUN)
		b.disc(at + Vector2(0, 4.0), 44.0 * sc, Color(Pal.TEXT, 0.14))
		b.disc(at, 44.0 * sc, Color("f3ead6") if open else Color("e4dccb"))
		if not open:
			Art.lock_into(marks, at, 22.0, Color(Pal.TEXT, 0.4))
		elif id == "move":
			Art.hand_into(marks, at + Vector2(0, 4.0), 24.0 * sc, Pal.TEXT_DIM)
		elif id == "remove":
			Art.eraser_into(marks, at, 24.0 * sc)
		elif id == "turn":
			Art.glyph_into(marks, "turn", Rect2(at - Vector2.ONE * 24.0 * sc, Vector2.ONE * 48.0 * sc), Pal.TEXT_DIM)
	_tray_live = b.mesh()
	tray.draw_mesh(_tray_live, null)
	_marks_live = marks.mesh() if not marks.verts.is_empty() else null
	if _marks_live != null:
		tray.draw_mesh(_marks_live, null)
	for slot: int in slots():
		var id := tool_of(slot)
		var at := _slot_mid(slot)
		var kd := Sim.PART if id == "parts" else tool_kind(id)
		if kd >= 0 and _tool_open(id):
			var sc := 1.0 if still else Motion.bump_scale(_clock - float(_chip_at.get(slot, -10.0)), 0.16, 0.22)
			tray.draw_mesh(Art.icon(kd), null, Transform2D(0.0, Vector2.ONE * 0.62 * sc, 0.0, at))
		var cap := tr("TL_TOOL_" + id.to_upper()) if _tool_open(id) else tr("TL_LEVEL_SHORT") % _open_at(id)
		var w := _slot_w()
		var col := Art.INK if _holding(id) else Color(Art.INK, 0.7)
		tray.draw_string(_font, Vector2(at.x - w * 0.5, at.y + 44.0 + 30.0), cap, HORIZONTAL_ALIGNMENT_CENTER, w, 22, col)

# --- cards ---

func _show_piece(t: Vector2i) -> void:
	if _busy():
		return
	_fx.touch()
	_feel(Haptics.TAP)
	board.let_go()
	var card := Card.new()
	card.name = "Card"
	card.sim = sim
	card.tile = t
	card.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP))
	card.chose.connect(_on_card.bind(t))
	add_child(card)
	move_child(_rw, get_child_count() - 1)

func _on_card(id: String, t: Vector2i) -> void:
	var s := sim
	match id:
		"turn":
			s.mark()
			s.turn(t)
		"lift":
			s.mark()
			s.remove(t)
		"empty":
			s.empty_crate(t)

func _show_box() -> void:
	if _busy():
		return
	_fx.touch()
	_feel(Haptics.TAP)
	board.let_go()
	var card := Card.new()
	card.name = "Card"
	card.sim = sim
	card.box = true
	card.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP))
	add_child(card)
	move_child(_rw, get_child_count() - 1)

## The flow sheet: what comes into the box a second.
func open_flow() -> void:
	if _busy():
		return
	_chip_at[-3] = _clock
	_fx.touch()
	_feel(Haptics.TAP)
	board.let_go()
	var card := Flow.new()
	card.name = "Flow"
	card.sim = sim
	card.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP))
	add_child(card)
	move_child(_rw, get_child_count() - 1)

func open_shop() -> void:
	if _busy():
		return
	_chip_at[-1] = _clock
	_fx.touch()
	_feel(Haptics.TAP)
	board.let_go()
	var shop := Shop.new()
	shop.name = "Shop"
	shop.sim = sim
	shop.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP))
	add_child(shop)
	move_child(_rw, get_child_count() - 1)

# --- parts ---

func open_parts() -> void:
	if _busy():
		return
	_chip_at[slot_of("parts")] = _clock
	_fx.touch()
	_feel(Haptics.TAP)
	board.let_go()
	var card := Parts.new()
	card.name = "Parts"
	card.sim = sim
	card.closed.connect(func() -> void:
		_fx.touch(0.94)
		_fx.buzz(Haptics.TAP))
	card.chose.connect(_on_parts)
	add_child(card)
	move_child(_rw, get_child_count() - 1)

func _on_parts(what: String, id: int) -> void:
	match what:
		"place":
			board.set_tool("part")
			board.part_id = id
		"drop":
			sim.drop_part(id)
			_fx.cue("lift", 0.9)
			_feel(Haptics.TICK)
			if board.part_id == id and board.tool == "part":
				board.set_tool("move")
			_save()

## A pick saved as a part: said, and the Parts slot hops.
func _on_part_saved(id: int) -> void:
	_changed()
	_fx.cue("place", 1.1)
	_feel(Haptics.GOOD)
	_chip_at[slot_of("parts")] = _clock
	_rw.sticker(tr("TL_SAY_PART_SAVED") % Sim.part_title(sim.defs[id]), _top(), 36, 2.4, false, Color("fff4c2"), false, "say", 20.0)
	Analytics.track("tally_part", {"pieces": (sim.defs[id].pieces as Array).size()})

# --- chrome ---

func _on_back() -> void:
	sim.save()
	Analytics.track("tally_leave", {"seconds": int((Time.get_ticks_msec() - _opened_at) / 1000.0), "level": sim.level, "made": sim.made})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	for nm in ["Shop", "Card", "Parts"]:
		var sheet := get_node_or_null(nm)
		if sheet != null and not sheet.is_queued_for_deletion():
			sheet.closed.emit()
			sheet.queue_free()
			return
	_on_back()
