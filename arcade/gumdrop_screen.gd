extends Control

## Gumdrop: the eleventh game on the Arcade tab, clear jelly in a walled
## mould coloured with a dropper of syrup to match a card (spec
## docs/superpowers/specs/2026-10-10-arcade-gumdrop-design.md). **The
## kitchen table is the whole screen**, edge to edge (CLAUDE.md: a game's
## world fills the screen): on it lie the card with the picture of what is
## wanted, the tray with the mould, the pots of syrup and the two round
## buttons, and over it the flat boards' top bar and a paper row with the
## score, the best and the mould's number.
##
## Play: a finger drawn over the tray moves the dropper's tip as far as the
## finger goes (it need not be on the tip, so it never hides it) and a tap
## puts the tip there; a pot touched is the flavour in the dropper; the
## pink button squeezes for as long as it is held; the gold one serves the
## mould. The syrup is arcade/gumdrop_sim.gd's, stepped at its fixed DT;
## this screen draws it and plays its events. How near the card the mould
## is stays hidden while it is played (a ? beside the card, since
## 2026-10-11): serving it is the check, and the number is told then.
##
## Drawing: three Controls one over the other. The field draws the table,
## the tray and the mould's floor. The syrup is the sim's grid as one small
## texture drawn once through shaders/gumdrop_syrup_2d.gdshader. The top
## draws the mould's walls over it, the card, the pots, the buttons, the
## dropper and one live mesh. Every one of those is a cached mesh under a
## transform; a mould's three are built when it is dealt.

signal closed

const Sim = preload("res://arcade/gumdrop_sim.gd")
const Mould = preload("res://arcade/gumdrop_mould.gd")
const Art = preload("res://arcade/gumdrop_art.gd")
const Syrup = preload("res://shaders/gumdrop_syrup_2d.gdshader")
const Record = preload("res://arcade/arcade_record.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
## What the phone knocks for (docs/agents/haptics.md). The events that share
## a frame ask through `_feel` and the frame knocks once, with the
## strongest. Only the end card's cue is mapped.
const HAPTICS := {"new_best": Haptics.WIN}
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "gumdrop"
## The two gold boosters the game had before 2026-10-11 (fuller pots,
## taller walls), and what one cost: held ones are given back in gold when
## the screen opens (core/wallet.gd).
const OLD := ["gd_full", "gd_tall"]
const OLD_PRICE := 120
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
## The card over the tray, the row the pots stand in, the squeeze button's
## radius and the serve button's, and how far apart the pots stand.
const CARD := Vector2(500.0, 180.0)
const POT_H := 150.0
const POT_GAP := 150.0
const SQUEEZE_R := 104.0
const SERVE_R := 66.0
const SERVE_OFF := 250.0
## The dropper's length in pixels and how far it leans.
const DROPPER := 250.0
const LEAN := 0.55
## A finger that has moved less than this far has tapped.
const TAP_PX := 14.0
## The most sim steps one frame may run, so a stall never fast-forwards.
const MAX_STEPS := 6
## Seconds between two of the dropper's ticks while it is squeezed.
const POUR_GAP := 0.17
## The score lettered over the table as it passes each of these.
const MILESTONES := [300, 600, 1000, 1500, 2000, 3000, 5000]
## The cozy rules (docs/agents/sound.md): no cue climbs past five semitones,
## and a tick that repeats varies by TICK_VARY and climbs nothing.
const CLIMB_TOP := 1.335
const TICK_VARY := 0.06

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
var _syrup: Control
var _top: Control
var _fx: Node2D
var _margins: MarginContainer
var _score_l: Label
var _best_l: Label
var _level_l: Label
var _match_l: Label
var _need_l: Label
var _banner: Label
var _sub: Label
var _banner_tw: Tween
var _end: Control
var _acc := 0.0
var _started_at := 0
var _best := 0
var _shown_score := -1
var _shown_level := -1
var _shown_match := -1
var _beat_best := false
## The knock this frame's events asked for, the strongest of them (-1: none).
var _knock := -1
## Where everything lies on the table (`_place`): the tray's square, pixels
## a mould unit, the card, each pot's foot, and the two buttons' middles.
var _tray := Rect2()
var _u := 6.0
var _card := Rect2()
var _pot_at: Array = []
var _squeeze_at := Vector2.ZERO
var _serve_at := Vector2.ZERO
var _table: ArrayMesh
var _table_of := Vector2.ZERO
## The dealt mould's meshes and what they were built for.
var _floor: ArrayMesh
var _walls: ArrayMesh
var _picture: ArrayMesh
var _built_for := {}
var _built_u := 0.0
## The syrup's texture and the bytes it is made of.
var _bytes := PackedByteArray()
var _img: Image
var _tex: ImageTexture
var _stale := true
var _live: ArrayMesh
## The screen's own clock, for motion the sim does not own.
var _clock := 0.0
## The fingers: the one drawing the dropper about (-1 none, -2 the mouse),
## where it was last and how far it has gone, and the one on the squeeze
## button.
var _aim_by := -1
var _aim_moved := 0.0
var _squeeze_by := -1
var _serve_down := -10.0
## The dropper as drawn: its tip eased to the sim's, and how squashed its
## bulb is.
var _tip := Vector2(50, 50)
var _squash := 0.0
var _pour_at := -10.0
var _pick_at := -10.0
var _deal_at := -10.0
var _verdict_at := -10.0
var _wobble := 0.0
var _slid := false
## Rings on the jelly, in mould units: {pos, t, life, r, col}.
var _bits: Array = []
var _seat: Control
## The loud rewards over the whole screen (arcade/rewards.gd).
var _rw: Rewards
var _milestone := 0
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
	tutor = ScreenTutor.new(self, puzzle_id(), "Gumdrop", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	# before any run: the boost card may stand first, and the bar would wear
	# the Undo and the bulb this game has not got until Play
	top_bar.refresh(self)
	_ask(false)
	# the two gold boosters the game had before come back as gold
	var back := 0
	for id: String in OLD:
		back += Wallet.refund(id, OLD_PRICE)
	if back > 0:
		_rw.sticker(tr("GD_REFUND") % back, _rw.at(self, size * Vector2(0.5, 0.5)), 44, 3.0, false, Color("fff4c2"), false, "refund")

# --- building ---

func _build() -> void:
	var table := _build_field()
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(table)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Gumdrop", tr("GD_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())
	_rw = Rewards.new()
	add_child(_rw)
	_apply_insets()

## The table: the field, the syrup over it, the top over that, the card's
## two lines, the lettering and the effects.
func _build_field() -> Control:
	field = Control.new()
	field.name = "Field"
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.resized.connect(_layout_field)
	field.gui_input.connect(_on_field_input)
	_syrup = Control.new()
	_syrup.name = "Syrup"
	_syrup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_syrup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_syrup.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_syrup.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var mat := ShaderMaterial.new()
	mat.shader = Syrup
	_syrup.material = mat
	_syrup.draw.connect(_draw_syrup)
	field.add_child(_syrup)
	_top = Control.new()
	_top.name = "Top"
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top.draw.connect(_draw_top)
	field.add_child(_top)
	_bytes.resize(Sim.N * Sim.N * 4)
	_bytes.fill(0)
	_img = Image.create_from_data(Sim.N, Sim.N, false, Image.FORMAT_RGBA8, _bytes)
	_tex = ImageTexture.create_from_image(_img)

	# a ? while the mould is played, its number once it is served
	_match_l = Label.new()
	_match_l.theme_type_variation = "DayBig"
	_match_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_match_l.text = "?"
	field.add_child(_match_l)
	_need_l = Label.new()
	_need_l.theme_type_variation = "MenuKicker"
	_need_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_need_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(_need_l)

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
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_color_override("font_color", Color("fffaf0"))
	_banner.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0.2, 0.6))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	_banner.add_theme_color_override("font_outline_color", Art.INK)
	_banner.add_theme_constant_override("outline_size", 12)
	over.add_child(_banner)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetTitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_color_override("font_color", Color("fffaf0"))
	_sub.add_theme_color_override("font_outline_color", Art.INK)
	_sub.add_theme_constant_override("outline_size", 8)
	over.add_child(_sub)
	over.modulate.a = 0.0
	_banner.set_meta("box", over)
	return field

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var made := []
	for key in ["FF_SCORE", "FF_BEST", "GD_MOULD"]:
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
	_level_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_layout_field()

## What of the field the top bar and the plates cover, and what is kept
## clear at its foot.
func _bands() -> Vector2:
	var insets := SafeArea.insets(self)
	return Vector2(MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + GAP, MARGIN + insets.y)

## How many pots the mould has stood by it.
func _pots() -> int:
	return sim.pots.size() if sim != null else 2

## Lays the table: the card, the tray under it as big as the room allows,
## the pots under the tray and the buttons at the foot, the squeeze in the
## middle where either thumb reaches it and the serve to its left (the
## right thumb hides the lower right).
func _place() -> void:
	var bands := _bands()
	var s := field.size
	var room := maxf(1.0, s.y - bands.x - bands.y)
	var fixed := CARD.y + GAP * 2.0 + POT_H + GAP + SQUEEZE_R * 2.0 + GAP
	var side := clampf(minf(s.x - MARGIN * 2.0 - 30.0, room - fixed), 160.0, 1000.0)
	var y := bands.x + maxf(0.0, (room - fixed - side) * 0.5)
	_card = Rect2((s.x - CARD.x) * 0.5, y + 8.0, CARD.x, CARD.y)
	y += CARD.y + GAP * 2.0
	_tray = Rect2((s.x - side) * 0.5, y, side, side)
	_u = side / Mould.SIDE
	y += side + GAP + POT_H
	_pot_at.clear()
	var n := _pots()
	for i in n:
		_pot_at.append(Vector2(s.x * 0.5 + (i - (n - 1) * 0.5) * POT_GAP, y - 14.0))
	y += GAP + SQUEEZE_R
	_squeeze_at = Vector2(s.x * 0.5, y)
	_serve_at = Vector2(s.x * 0.5 - SERVE_OFF, y + 10.0)

func _layout_field() -> void:
	if field.size.x <= 0.0 or field.size.y <= 0.0:
		return
	if _table == null or _table_of != field.size:
		_table_of = field.size
		_table = Art.table(field.size)
	_place()
	_place_labels()
	if _banner != null:
		_place_banner()
	_redraw()

func _place_labels() -> void:
	var right := Rect2(_card.position + Vector2(CARD.y + 10.0, 0), Vector2(_card.size.x - CARD.y - 30.0, _card.size.y))
	_match_l.size = Vector2(right.size.x, 96.0)
	_match_l.position = right.position + Vector2(0, 22.0)
	_need_l.size = Vector2(right.size.x, 40.0)
	_need_l.position = right.position + Vector2(0, 118.0)

func _place_banner() -> void:
	var box: Control = _banner.get_meta("box")
	box.size.x = field.size.x * 0.86
	box.reset_size()
	box.size.x = field.size.x * 0.86
	box.position = Vector2(field.size.x * 0.07, _tray.position.y + _tray.size.y * 0.3)
	box.pivot_offset = box.size * 0.5

func _redraw() -> void:
	field.queue_redraw()
	_syrup.queue_redraw()
	_top.queue_redraw()

## A point of the mould on the field, and back.
func px(p: Vector2) -> Vector2:
	return _group() * (p * _u)

func to_mould(p: Vector2) -> Vector2:
	return (p - _tray.position) / _u

## The tray's own transform: where it lies, slid aside as a served mould
## leaves and the next comes, and shaken as a jelly is when it is judged.
func _group() -> Transform2D:
	var at := _tray.position
	var sc := Vector2.ONE
	if not Motion.reduce:
		at.x += _slide() * field.size.x
		var since := _clock - _verdict_at
		if since >= 0.0 and since < 1.6:
			var w := _wobble * sin(since * 19.0) * exp(-since * 3.0)
			sc = Vector2(1.0 + w, 1.0 - w)
	var mid := _tray.size * 0.5
	return Transform2D(0.0, sc, 0.0, at + mid - mid * sc)

## How far aside the tray is, in screens: off to the left as a mould that
## passed is taken away, in from the right as the next is set down.
func _slide() -> float:
	if sim == null:
		return 0.0
	if sim.phase == Sim.Phase.SHOW and bool(sim.verdict.get("pass", false)):
		var k := clampf((sim.phase_t - (Sim.SHOW_T - 0.4)) / 0.4, 0.0, 1.0)
		return -k * k * 1.1
	var k2 := clampf((_clock - _deal_at) / 0.45, 0.0, 1.0)
	return (1.0 - Motion.back_out(k2)) * 1.1 if _slid else 0.0

# --- the game ---

func _fresh_sim() -> void:
	sim = Sim.new()
	Boosters.apply(GAME, sim, _boosts)
	_shown_level = -1
	_shown_match = -1
	sim.events.clear()

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	_fresh_sim()
	_boosted = not _boosts.is_empty()
	_chance_used = false
	_run_gold = 0
	_acc = 0.0
	_bits.clear()
	_aim_by = -1
	_squeeze_by = -1
	_deal_at = -10.0
	_verdict_at = -10.0
	_slid = false
	_beat_best = false
	_milestone = 0
	_end_score = null
	_rw.clear()
	_best = Record.best(GAME)
	_shown_score = -1
	_started_at = Time.get_ticks_msec()
	_tip = sim.tip
	_stale = true
	_layout_field()
	_refresh_hud()
	top_bar.refresh(self)
	_fx.cue("start")
	_hint(tr("GD_READY"), tr("GD_READY_LINE"))
	Analytics.track("arcade_start", {"game": GAME, "boosts": ",".join(_boosts)})

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/gumdrop_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.FILL, "TUT_GUMDROP_FILL", tr("TUT_GUMDROP_FILL_BODY")],
		[Diagram.Lesson.SOAK, "TUT_GUMDROP_SOAK", tr("TUT_GUMDROP_SOAK_BODY")],
		[Diagram.Lesson.MATCH, "TUT_GUMDROP_MATCH", tr("TUT_GUMDROP_MATCH_BODY") % [Sim.MARK, Sim.MARK_TOP]],
		[Diagram.Lesson.MIX, "TUT_GUMDROP_MIX", tr("TUT_GUMDROP_MIX_BODY") % 5],
		[Diagram.Lesson.BOOSTS, "TUT_GUMDROP_BOOSTS", tr("TUT_GUMDROP_BOOSTS_BODY")],
		[Diagram.Lesson.HUD, "TUT_GUMDROP_HUD", tr("TUT_GUMDROP_HUD_BODY")],
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
	return sim != null and sim.is_over()

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

func hints_left() -> int:
	return 0

## The game has no clock, so nothing is held while the card is up.
func _tutor_hold(_on: bool) -> void:
	_let_go()

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	_acc += minf(delta, Sim.DT * MAX_STEPS)
	while _acc >= Sim.DT:
		_acc -= Sim.DT
		_hand()
		sim.step()
		_play_events()
	_animate(delta)
	_refresh_hud()
	_knock_now()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()
	_redraw()

## The tutorial's hand works the sim from here.
func _hand() -> void:
	pass

func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _knock_now() -> void:
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1

func _animate(delta: float) -> void:
	for bit: Dictionary in _bits:
		bit.t += delta
	_bits = _bits.filter(func(bit: Dictionary) -> bool: return bit.t < bit.life)
	_tip = _tip.lerp(sim.tip, minf(1.0, delta * 30.0))
	var pouring: bool = sim.squeezing and sim.phase <= Sim.Phase.PLAY
	_squash = lerpf(_squash, 1.0 if sim.squeezing else 0.0, minf(1.0, delta * 16.0))
	if pouring and _clock - _pour_at >= POUR_GAP:
		_pour_at = _clock
		_fx.cue("pour", randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
		_ring(sim.tip, 4.0, 0.5, Color(1, 1, 1, 0.8))
	if sim.moving or _stale:
		_stale = false
		Art.paint(sim, _bytes)
		_img.set_data(Sim.N, Sim.N, false, Image.FORMAT_RGBA8, _bytes)
		_tex.update(_img)
	_rw.bounds = Rect2(_rw.at(field, Vector2.ZERO), field.size)
	_rw.step(delta)

# --- the fingers ---

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag(drag.index, drag.relative)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click := event as InputEventMouseButton
		if click.pressed:
			_press(-2, click.position)
		else:
			_release(-2, click.position)
	elif event is InputEventMouseMotion:
		_drag(-2, (event as InputEventMouseMotion).relative)

func _busy() -> bool:
	return sim == null or _end != null or sim.phase > Sim.Phase.PLAY or get_node_or_null("BoostCard") != null \
		or get_node_or_null("SecondChance") != null

func _press(index: int, at: Vector2) -> void:
	if _busy():
		return
	if at.distance_to(_squeeze_at) <= SQUEEZE_R + 14.0:
		if _squeeze_by == -1:
			_squeeze_by = index
			sim.squeeze(true)
			_fx.touch(randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
			_fx.buzz(Haptics.TAP)
		return
	if at.distance_to(_serve_at) <= SERVE_R + 14.0:
		_serve_down = _clock
		_fx.buzz(Haptics.TAP)
		if sim.can_serve():
			sim.serve()
		else:
			# nothing in the mould yet: the button answers and says why
			_fx.touch(0.94)
			_rw.sticker(tr("GD_NOTHING_YET"), _rw.at(field, _serve_at + Vector2(60.0, -SERVE_R - 30.0)), 40, 1.3, false, Color("fffaf0"), false, "nothing")
		return
	for i in _pot_at.size():
		var foot: Vector2 = _pot_at[i]
		if Rect2(foot.x - POT_GAP * 0.5, foot.y - Art.JAR_H - 16.0, POT_GAP, Art.JAR_H + 44.0).has_point(at):
			sim.pick(i)
			_pick_at = _clock
			_fx.touch(randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
			_fx.buzz(Haptics.TAP)
			return
	if _tray.grow(24.0).has_point(at) and _aim_by == -1:
		_aim_by = index
		_aim_moved = 0.0
		_fx.touch(randf_range(1.0 - TICK_VARY, 1.0 + TICK_VARY))
		_fx.buzz(Haptics.TICK)

func _drag(index: int, by: Vector2) -> void:
	if index != _aim_by or _busy():
		return
	_aim_moved += by.length()
	if _aim_moved >= TAP_PX:
		sim.aim(sim.tip + by / _u)

func _release(index: int, at: Vector2) -> void:
	if index == _squeeze_by:
		_squeeze_by = -1
		if sim != null:
			sim.squeeze(false)
	if index == _aim_by:
		_aim_by = -1
		if not _busy() and _aim_moved < TAP_PX:
			sim.aim(to_mould(at))

func _let_go() -> void:
	_aim_by = -1
	_squeeze_by = -1
	if sim != null:
		sim.squeeze(false)

# --- events ---

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		match String(ev.type):
			"go":
				_hint("", "")
			"deal":
				_on_deal()
			"serve":
				_let_go()
				_fx.cue("serve")
			"served":
				_on_served(ev)
			"over":
				_run_over()
			"revive":
				_stale = true
				_verdict_at = -10.0
				_hint(tr("CHANCE_GO"), tr("GD_READY_LINE"))
	sim.events.clear()

func _on_deal() -> void:
	_deal_at = _clock
	_slid = sim.level > 1
	_stale = true
	_tip = sim.tip
	_bits.clear()
	_place()
	if sim.level > 1:
		_fx.cue("deal")
		_feel(Haptics.TICK)
		if bool(sim.mould.get("mixed", -1) >= 0) and sim.level == 5:
			_rw.sticker(tr("GD_MIX_NOW"), _rw.at(field, _tray.get_center() + Vector2(0, -_tray.size.y * 0.3)), 46, 2.4, false, Color("fffaf0"), false, "mix")

func _on_served(ev: Dictionary) -> void:
	_verdict_at = _clock
	var pct := int(ev.pct)
	var at := _rw.at(field, _tray.get_center())
	if bool(ev.perfect):
		_wobble = 0.09
		_fx.cue("perfect")
		_feel(Haptics.GOOD)
		_rw.sticker("%d%%" % pct, at, 110, 1.9, true, Color.WHITE, true, "pct")
		_rw.sticker(tr("GD_PERFECT"), at + Vector2(0, 110.0), 54, 1.9, false, Color("fff4c2"), false, "word")
		_rw.rain(1.6, ["confetti", "star"], Rewards.CONFETTI)
		_rw.spray(at, Pal.SUN, 10, 620.0, "star", 1.0, 0.1, _plate_at(_score_l))
	elif bool(ev["pass"]):
		_wobble = 0.06
		_fx.cue("good", minf(1.0 + 0.02 * (sim.level - 1), CLIMB_TOP))
		_feel(Haptics.GOOD)
		_rw.sticker("%d%%" % pct, at, 100, 1.9, false, Color("fffaf0"), true, "pct")
		_rw.sticker(tr("GD_GOOD"), at + Vector2(0, 104.0), 50, 1.9, false, Color("fff4c2"), false, "word")
		_rw.spray(at, Pal.SUN, 6, 520.0, "star", 0.9, 0.1, _plate_at(_score_l))
	else:
		_wobble = 0.03
		_fx.cue("flop")
		_feel(Haptics.BAD)
		_rw.sticker("%d%%" % pct, at, 100, 2.2, false, Color("fffaf0"), false, "pct")
		_rw.sticker(tr("GD_NEEDED") % int(ev.need), at + Vector2(0, 104.0), 46, 2.2, false, Color("ffd9c2"), false, "word")

func _ring(at: Vector2, r: float, life: float, col: Color) -> void:
	if Motion.reduce:
		return
	_bits.append({"pos": at, "t": 0.0, "life": life, "r": r, "col": col})

func _hint(text: String, sub: String) -> void:
	var box: Control = _banner.get_meta("box")
	Motion.stop(_banner_tw)
	if text == "":
		_banner_tw = create_tween()
		_banner_tw.tween_property(box, "modulate:a", 0.0, 0.18)
		return
	_banner.text = text
	_sub.text = sub
	_sub.visible = sub != ""
	_place_banner()
	box.scale = Vector2.ONE
	_banner_tw = create_tween()
	_banner_tw.tween_property(box, "modulate:a", 1.0, 0.2)

func _refresh_hud() -> void:
	if sim == null:
		return
	# the number is told only once the mould is served: a ? until then
	var pct := int(sim.verdict.get("pct", -1)) if sim.phase >= Sim.Phase.SHOW else -1
	if pct != _shown_match or sim.level != _shown_level:
		_shown_match = pct
		_match_l.text = "?" if pct < 0 else "%d%%" % pct
		_need_l.text = tr("GD_NEED") % sim.mark()
		# over the mark the number is the leaf's green, under it the ink
		_match_l.add_theme_color_override("font_color", Pal.LEAF_DEEP if pct >= sim.mark() else Art.INK)
	if sim.level != _shown_level:
		if _shown_level >= 0 and sim.level > _shown_level:
			_level_l.pivot_offset = _level_l.size * 0.5
			Motion.bump(_level_l, 0.3, 0.4)
		_shown_level = sim.level
		_level_l.text = str(sim.level)
	if sim.score == _shown_score:
		return
	if sim.score > _shown_score and _shown_score >= 0:
		_score_l.pivot_offset = _score_l.size * 0.5
		Motion.bump(_score_l, 0.14, 0.26)
	_shown_score = sim.score
	_score_l.text = Record.grouped(sim.score)
	_best_l.text = Record.grouped(maxi(_best, sim.score))
	if not _beat_best and _best > 0 and sim.score > _best:
		_beat_best = true
		_best_l.pivot_offset = _best_l.size * 0.5
		Motion.bump(_best_l, 0.3, 0.4)
		_new_best_passed()
	_score_moments()

# --- drawing ---

func _meshes() -> void:
	if sim == null:
		return
	if _built_u == _u and is_same(_built_for, sim.mould) and _floor != null:
		return
	_built_u = _u
	_built_for = sim.mould
	_floor = Art.floor_of(sim.mould, _u)
	_walls = Art.walls_of(sim.mould, _u)
	_picture = Art.picture(sim.mould, (CARD.y - 36.0) / Mould.SIDE)

func _draw_field() -> void:
	if _table == null:
		_layout_field()
	if _table == null:
		return
	field.draw_mesh(_table, null)
	if sim == null:
		return
	_meshes()
	var xf := _group()
	field.draw_mesh(Art.tray(_tray.size.x), null, xf)
	field.draw_mesh(_floor, null, xf)

func _draw_syrup() -> void:
	if sim == null or _tex == null:
		return
	_syrup.draw_set_transform_matrix(_group())
	_syrup.draw_texture_rect(_tex, Rect2(Vector2.ZERO, _tray.size), false)

func _draw_top() -> void:
	if sim == null or _walls == null:
		return
	var xf := _group()
	_top.draw_mesh(_walls, null, xf)
	# the card and its picture
	_top.draw_mesh(Art.card(_card.size), null, Transform2D(-0.012, _card.position))
	_top.draw_mesh(_picture, null, Transform2D(0.0, _card.position + Vector2(18.0, 18.0)))
	# the pots: the picked one stands in its ring, a little nearer
	for i in mini(_pot_at.size(), sim.pots.size()):
		var pot: Dictionary = sim.pots[i]
		var foot: Vector2 = _pot_at[i]
		var on: bool = i == sim.picked
		var sc := 1.0
		if on:
			sc = 1.08
			if not Motion.reduce and _clock - _pick_at < 0.25:
				sc += 0.1 * sin((_clock - _pick_at) / 0.25 * PI)
		var at := Transform2D(0.0, Vector2(sc, sc), 0.0, foot)
		_top.draw_mesh(Art.jar_shadow(), null, at)
		if on:
			_top.draw_mesh(Art.jar_ring(), null, at)
		_top.draw_mesh(Art.syrup(int(pot.flavour), 1.0), null, at)
		_top.draw_mesh(Art.jar(), null, at)
	# the buttons: a pressed one sinks and shades
	var can: bool = sim.can_serve()
	var sd := 0.94 if _clock - _serve_down < 0.12 else 1.0
	_top.draw_mesh(Art.serve_button(SERVE_R), null, Transform2D(0.0, Vector2(sd, sd), 0.0, _serve_at),
		Color(1, 1, 1, 1.0 if can else 0.45) * (Color(0.88, 0.88, 0.88) if sd < 1.0 else Color.WHITE))
	var held: bool = _squeeze_by != -1 or sim.squeezing
	var qd := 0.94 if held else 1.0
	_top.draw_mesh(Art.squeeze_button(SQUEEZE_R), null, Transform2D(0.0, Vector2(qd, qd), 0.0, _squeeze_at),
		Color(0.86, 0.86, 0.86) if held else Color.WHITE)
	_draw_live()
	# the dropper over all of it, leaning away to the upper right
	if sim.phase <= Sim.Phase.PLAY:
		var tip := px(_tip)
		var bob := 0.0 if Motion.reduce or sim.squeezing else 3.0 * sin(_clock * 2.4)
		var lean := Transform2D(LEAN, tip + Vector2(0, -bob))
		_top.draw_mesh(Art.dropper(int(sim.pots[sim.picked].flavour), DROPPER), null, lean)
		var squash := Vector2(1.0 + 0.2 * _squash, 1.0 - 0.3 * _squash)
		_top.draw_mesh(Art.bulb(DROPPER), null, lean * Transform2D(0.0, squash, 0.0, Vector2(0, -DROPPER + 4.0)))

func _draw_live() -> void:
	if _bits.is_empty():
		return
	var b := Face.Builder.new()
	for bit: Dictionary in _bits:
		var k: float = bit.t / bit.life
		var r: float = float(bit.r) * _u * (0.3 + 0.7 * k)
		b.stroke(Face.Builder.ring(px(bit.pos), r, r), maxf(1.5, 0.9 * _u * (1.0 - k)), Color(bit.col, bit.col.a * (1.0 - k)), true)
	_live = b.mesh()
	if _live != null:
		_top.draw_mesh(_live, null)

# --- the rewards ---

func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(field, px(p))

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

func _score_moments() -> void:
	var m := 0
	for v: int in MILESTONES:
		if sim.score >= v and v > _milestone:
			m = v
	if m > 0:
		_milestone = m
		_rw.sticker(Record.grouped(m) + "!", _rw.at(field, _card.get_center() + Vector2(0, -20.0)), 64, 1.2, true, Color.WHITE, false, "milestone")
		_rw.spray(_plate_at(_score_l), Pal.SUN, 10, 520.0, "star", 0.9)
		_rw.ring(_plate_at(_score_l), 140.0, Color(Pal.SUN, 0.9))
		_feel(Haptics.BUMP)

func _new_best_passed() -> void:
	_rw.sticker(tr("FF_NEW_BEST"), _rw.at(field, _tray.get_center() + Vector2(0, _tray.size.y * 0.36)), 60, 1.6, true, Color.WHITE, false, "best")
	_rw.spray(_plate_at(_best_l), Pal.SUN, 14, 620.0, "star", 1.0)
	_rw.ring(_plate_at(_best_l), 160.0, Color(Pal.SUN, 0.9))
	_feel(Haptics.BUMP)

# --- the end ---

func _run_over() -> void:
	if _offer_chance():
		return
	# the most moulds served in a run is the stage the tab's card reads
	var better := Record.add(GAME, sim.score, sim.served, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.served,
		"seconds": secs, "perfect": sim.perfects, "last": int(sim.verdict.get("pct", 0)), "best": better})
	Ads.note_finished()
	top_bar.refresh(self)
	get_tree().create_timer(0.5).timeout.connect(_show_end.bind(better))

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

## Three gumdrops in a row over a sunburst, each shaking as a jelly does.
func _draw_seat(seat: Control, better: bool, shown_at: float) -> void:
	var t := 0.0 if Motion.reduce else _clock
	var c := Vector2(seat.size.x * 0.5, 120.0)
	var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.4) / 0.35, 0.0, 1.0)
	var b := Face.Builder.new()
	if glow > 0.0:
		var rr := 190.0 * Motion.back_out(glow)
		b.disc(c, rr * 0.5, Color(Color("fff4c2"), 0.45))
		Rewards.sunrays(b, c, rr * 0.2, rr, 14, t * 0.5, Color(Rewards.GOLD if better else Pal.SUN, 0.5))
		Rewards.sunrays(b, c, rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
	for k in 3:
		var col: Color = Art.FLAVOURS[[0, 2, 4][k]]
		var w := 0.0 if Motion.reduce else 0.05 * sin(t * 5.0 + k * 1.7)
		var foot := c + Vector2((k - 1) * 104.0, 62.0 if k != 1 else 70.0)
		var rx := (50.0 if k != 1 else 58.0) * (1.0 + w)
		var ry := (78.0 if k != 1 else 94.0) * (1.0 - w)
		b.ellipse(foot + Vector2(4.0, 2.0), rx * 1.05, 12.0, Color(0.25, 0.14, 0.06, 0.2))
		var dome := Face.Builder.arc_points(foot, 1.0, PI, TAU)
		for i in dome.size():
			dome[i] = foot + Vector2((dome[i].x - foot.x) * rx, (dome[i].y - foot.y) * ry)
		b.polygon(dome, col.darkened(0.12))
		for i in dome.size():
			dome[i] = foot + Vector2((dome[i].x - foot.x) * 0.86 - rx * 0.06, (dome[i].y - foot.y) * 0.9 - 3.0)
		b.polygon(dome, col)
		b.ellipse(foot + Vector2(-rx * 0.36, -ry * 0.62), rx * 0.16, ry * 0.12, Color(1, 1, 1, 0.55))
	var m := b.mesh()
	seat.set_meta("mesh", m)
	seat.draw_mesh(m, null)

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
	seat.custom_minimum_size = Vector2(0, 220)
	var shown_at := _clock
	seat.draw.connect(func() -> void: _draw_seat(seat, better, shown_at))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "GD_END_CARD"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# the longer languages take two lines rather than widen the card
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 740
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
	for pair in [[str(sim.served), "GD_STAT_SERVED"], [str(sim.perfects), "GD_STAT_PERFECT"],
			["%d%%" % int(sim.verdict.get("pct", 0)), "GD_STAT_LAST"]]:
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

func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 0.9, 0.0, 1.0)
	var shown := int(round(sim.score * (1.0 - pow(1.0 - k, 3.0))))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
	if k >= 1.0:
		_end_score.pivot_offset = _end_score.size * 0.5
		Motion.bump(_end_score, 0.25, 0.4)
		if sim.score > 0:
			var at := _rw.at(_end_score, _end_score.size * 0.5)
			_rw.spray(at, Pal.SUN, 10, 620.0, "star", 1.1)
			_rw.spray(at, Color("fffaf0"), 8, 480.0, "spark", 1.1)
			_rw.ring(at, 220.0, Color(Pal.SUN, 0.9))
		_end_score = null

func _celebrate(better: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if better:
		_rw.rain(3.0, ["confetti", "star"], Rewards.CONFETTI)

# --- chrome ---

func _on_reset() -> void:
	if sim != null and not sim.is_over():
		Analytics.track("board_reset", {"puzzle_id": GAME})
	_ask()

func _on_back() -> void:
	if sim != null and not sim.is_over() and sim.score > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.served})
	closed.emit()

func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()

# --- boosters (arcade/boosters.gd) ---

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
		_hint("", "")
	var card := BoostCard.new(GAME)
	card.name = "BoostCard"
	card.play.connect(func(ids: Array) -> void:
		_boosts = ids
		_new_game()
		_fx.buzz(Haptics.TAP))
	add_child(card)

func _offer_chance() -> bool:
	if _chance_used or not SecondChance.wanted() or sim.served <= 0:
		return false
	_chance_used = true
	var card := SecondChance.new(GAME)
	card.name = "SecondChance"
	card.taken.connect(func() -> void:
		_boosted = true
		Boosters.revive(GAME, sim)
		_fx.buzz(Haptics.GOOD)
		_fx.cue("good")
		_play_events()
		top_bar.refresh(self))
	card.declined.connect(_run_over)
	add_child(card)
	return true
