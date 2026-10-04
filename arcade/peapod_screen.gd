extends Control

## Peapod: the sixth game on the Arcade tab, a pea cannon against crates
## that come down with a number on each (spec
## docs/superpowers/specs/2026-10-04-arcade-peapod-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the score, the best and the wave, and under them the garden on the
## flat boards' parchment card, hedges round its foot: a pale sky the crates
## come down, the sun watching from it, the cart on the grass.
##
## Play: slide anywhere to roll the cart; it never stops firing. The game is
## arcade/peapod_sim.gd, stepped at its fixed DT; this screen draws it and
## plays its events.
##
## Drawing: the garden (sky, hills, grass) is one still mesh, built on
## resize. Everything that moves is drawn by one Control over it: a cached
## mesh a crate, a plate, a token and a part of the cart, moved by the
## transform and gathered a MultiMesh a look, their numbers lettered over
## them in ink, and one live mesh for what is laid fresh each frame.
##
## The soft pass (the spec's section 7): Lucky Thirteen's pastel pieces and
## Posy's card and hedges; a gift caught flies to its place on the grass, a
## crate gone leaves its shape swelling away, a streak is counted on a paper
## pill with its time running down, a wave cleared is stamped one to three
## stars and that many flowers come up along the grass, the pod wears a
## crown once the best is passed, and the big moments are held a beat.

signal closed

const Sim = preload("res://arcade/peapod_sim.gd")
const Art = preload("res://arcade/peapod_art.gd")
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
## What the phone knocks for (docs/agents/haptics.md). The gun never stops
## and a volley's peas land several to a frame, so only the end card's cue is
## mapped: the events ask through `_feel` and the frame knocks once, with the
## strongest. The shots and the peas landing play through `_quiet`, which
## knocks for nothing.
const HAPTICS := {"new_best": Haptics.WIN}
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "peapod"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
## The most sim steps one frame may run, so a stall never fast-forwards.
const MAX_STEPS := 4
## The finger's slide, times this, is the cart's.
const GAIN := 1.35
## Where the grass begins, in field units: under the cart's wheels.
const TURF := Sim.CART_Y + 9.0
const RECOIL := 0.09
const SKY_TOP := Color("d3e9f4")
const SKY_LOW := Color("f9f3e3")
const HILL_FAR := Color("d6e8c8")
const HILL := Color("c2deac")
const HILL_NEAR := Color("b0d596")
const GRASS := Color("a5d385")
const GRASS_DEEP := Color("8fc56f")
const GRASS_LIP := Color("c8e8ab")
const BUSH := [Color("8fc56f"), Color("a0d07f"), Color("b3db93")]
const ALARM := Color("f07f72")
const HEAT := Color("f6b866")
const FROST := Color("8fd0ee")
const STAR_OFF := Color("dccfb6")
## A gift on its way from the cart to its place on the grass.
const FLIGHT_T := 0.5
## The shape a crate gone leaves, swelling away.
const GHOST_T := 0.18
## A streak is counted on its pill from this many.
const STREAK_FROM := 5
## The stars a cleared wave is stamped: three if the line was never nearer
## than the first of these, two under the second.
const STAR_PEAKS := [0.2, 0.65]
const STAR_STEP := 0.22
const MAX_BLOOMS := 30
## The gun's three numbers on the grass, left to right.
const GUN := [Sim.Kind.PEA, Sim.Kind.RATE, Sim.Kind.POWER]
## The stickers' letters, in Lucky Thirteen's pastels.
const STICKER_COLS := [Color("f08a80"), Color("f6b866"), Color("f0d36a"), Color("9ed48a"), Color("86c2ee"), Color("c19be0")]
## How round the garden's corners are, inside the card's.
const ROUND := 22.0
## A streak's word, by its length, loudest first.
const WORDS := [[75, "PP_WORD_5"], [50, "PP_WORD_4"], [35, "PP_WORD_3"], [20, "PP_WORD_2"], [10, "PP_WORD_1"]]
const GOT := {Sim.Kind.PEA: "PP_GOT_PEA", Sim.Kind.RATE: "PP_GOT_RATE", Sim.Kind.POWER: "PP_GOT_POWER", Sim.Kind.TWIN: "PP_GOT_TWIN",
	Sim.Kind.FAN: "PP_GOT_FAN", Sim.Kind.PIERCE: "PP_GOT_PIERCE", Sim.Kind.BURST: "PP_GOT_BURST", Sim.Kind.MAGNET: "PP_GOT_MAGNET",
	Sim.Kind.FROST: "PP_GOT_FROST", Sim.Kind.SHOVE: "PP_GOT_SHOVE"}
## What a rotten gift took, by the gift it undid (-1: nothing left to take).
const ROT := {Sim.Kind.PEA: "PP_ROT_PEA", Sim.Kind.RATE: "PP_ROT_RATE", Sim.Kind.POWER: "PP_ROT_POWER", -1: "PP_ROT_NONE"}
## The sound a gift is caught with, where it has one of its own.
const CATCH_CUE := {Sim.Kind.TWIN: "twin", Sim.Kind.FAN: "pod", Sim.Kind.PIERCE: "pod", Sim.Kind.BURST: "pod", Sim.Kind.FROST: "frost",
	Sim.Kind.SHOVE: "shove"}
const MAX_POPS := 12
const MAX_SPARKS := 40
const SunFace = preload("res://ui/faces/sun_face.gd")

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
## The gun's own voice: the shots and the peas landing, which nothing knocks
## for.
var _quiet: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _score_l: Label
var _best_l: Label
var _wave_l: Label
var _sub: Label
var _sub_pill: PanelContainer
var _banner_tw: Tween
## The hedges round the card's foot, and the sun in the garden's sky.
var _hedge: Control
var _hedge_mesh: ArrayMesh
var _hedge_rect := Rect2()
var _frame: PanelContainer
var _sun: Control
var _pause_card: Control
var _end: Control
var _over: Control
var _acc := 0.0
var _paused := false
var _started_at := 0
var _best := 0
var _shown_score := -1
var _roll := 0.0
var _beat_best := false
## The knock this frame's events asked for, the strongest of them (-1: none).
var _knock := -1
## Pixels a field unit, and where the field's origin lands in `field`.
var _u := 2.4
var _origin := Vector2.ZERO
var _scene: ArrayMesh
var _land: ArrayMesh
var _live_top: ArrayMesh
## Built with the garden and only moved or tinted after: the chalk line's
## dashes and the plates under the gun's three numbers.
var _dashes: ArrayMesh
var _chips: ArrayMesh
var _text_fs := 13
## Every pea in the air is one draw a look, every spark one more (checkup,
## 2026-10-04: a pea laid into a mesh in script each frame was most of a
## frame once the gun was full and a millipede let the peas fly far).
var _pea_mm: Array = []
var _pea_buf: Array = []
var _spark_mm: MultiMesh
## The crates and the plates the same way, one draw a look of them: a wall
## of forty-five was forty-five draws, and the phone pays by the draw.
## ArrayMesh -> [MultiMesh, its buffer, how many this frame].
## One Dictionary a draw of the frame (`_cast_turn`).
var _casts: Array = []
var _cast_turn := 0
var _spark_buf := PackedFloat32Array()
## The screen's own clock, for motion the sim does not own; it stops with
## the pause.
var _clock := 0.0
## The finger sliding the cart: the touch, where it came down and where the
## cart was then.
var _touch := -1
var _mouse := false
var _touch_from := Vector2.ZERO
var _cart_from := 0.0
## When each crate or plate last took a pea, by its id, for the flash.
var _hit_at := {}
## Sparks where a pea lands: {pos, t, col}.
var _sparks: Array = []
## Numbers rising off a crate gone: {pos, text, t, col, big}.
var _pops: Array = []
var _shot_at := -10.0
var _wheel := 0.0
var _last_x := 0.0
var _lean := 0.0
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _seat: Control
## The loud rewards over the whole screen (arcade/rewards.gd).
var _rw: Rewards
## The warm glow a long streak lights round the garden (0..1), and the red
## one as the line is neared.
var _heat := 0.0
var _alarm := 0.0
var _flash := 0.0
var _flash_col := Color.WHITE
## The millipede head's number and where it goes, lettered after the peas.
var _head_tag: Array = []
var _end_score: Label
var _end_at := 0.0
## Crates and plates just gone: {pos, round, col, t}.
var _ghosts: Array = []
## Gifts flying to their place on the grass: {kind, from, t}.
var _flights: Array = []
## When each of the gun's three numbers, and each running gift, last took
## one in (by chip 0..2, and by Sim.Kind), for the bump.
var _chip_at := {}
## The streak's pill: how many it shows, when it last went up, and how far
## it has come in (0..1).
var _streak_n := 0
var _streak_at := -10.0
var _streak_in := 0.0
## The wave's stars: how near the line came, and the stamping of the last
## clear ({at, stars, said}).
var _wave_peak := 0.0
var _clear := {}
## The flowers the run has grown: {x, look, at, lean}.
var _blooms: Array = []
## The cart's hop ({at, tall, time}) and the crown it wears.
var _hop := {}
var _crown_at := -1.0
var _dust_at := 0.0
## The beat a big moment is held: seconds left of it, and how slow.
var _hold_t := 0.0
var _hold_k := 1.0

func puzzle_id() -> String:
	return GAME

## The tutorial's pages, each a slice of this garden played by a finger
## (ui/hud/peapod_tutorial_diagram.gd): the slide, the numbers and the line,
## the gifts, the pods, the special crates, the millipede, and the boosters
## and the top bar.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/peapod_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.SLIDE, "TUT_PEAPOD_SLIDE", tr("TUT_PEAPOD_SLIDE_BODY")],
		[Diagram.Lesson.CRATES, "TUT_PEAPOD_CRATES", tr("TUT_PEAPOD_CRATES_BODY")],
		[Diagram.Lesson.GIFTS, "TUT_PEAPOD_GIFTS", tr("TUT_PEAPOD_GIFTS_BODY")],
		[Diagram.Lesson.PODS, "TUT_PEAPOD_PODS", tr("TUT_PEAPOD_PODS_BODY") % int(Sim.POD_TIME)],
		[Diagram.Lesson.SPECIAL, "TUT_PEAPOD_SPECIAL", tr("TUT_PEAPOD_SPECIAL_BODY")],
		[Diagram.Lesson.MILLI, "TUT_PEAPOD_MILLI", tr("TUT_PEAPOD_MILLI_BODY")],
		[Diagram.Lesson.HUD, "TUT_PEAPOD_HUD", tr("TUT_PEAPOD_HUD_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Peapod", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	# before the boost card, so the bar behind it is already this game's
	top_bar.refresh(self)
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

	top_bar = FlatTopBar.new("Peapod", tr("PEAPOD_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void:
		_pause(true)
		settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())

	_frame = PanelContainer.new()
	_frame.name = "Frame"
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# the flat boards' card (ui/flat/flat_host.gd): parchment, a hairline, a
	# soft shadow
	var box := CozyTheme.lifted(Pal.PARCHMENT, 36, FRAME)
	box.set_border_width_all(2)
	box.border_color = Color(Pal.LINE, 0.35)
	_frame.add_theme_stylebox_override("panel", box)
	_frame.resized.connect(func() -> void: _hedge.queue_redraw())
	col.add_child(_frame)
	field = Control.new()
	field.name = "Field"
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.resized.connect(_layout_field)
	field.gui_input.connect(_on_field_input)
	_frame.add_child(field)
	# the sun in the garden's sky, under everything that moves: it watches
	# the cart, beams through a streak and frets as the line is neared
	_sun = SunFace.new()
	_sun.name = "Sun"
	_sun.shadowless = true
	field.add_child(_sun)
	_sun.set_idle(true)
	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	field.add_child(_over)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	field.add_child(_fx)
	_quiet = Fx2D.new()
	_quiet.buzzes = false
	field.add_child(_quiet)

	# the line under a banner, on a paper pill (Posy's)
	_sub_pill = PanelContainer.new()
	_sub_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := CozyTheme.lifted(Color("fffaf0", 0.96), 34, 18)
	pill.content_margin_left = 30
	pill.content_margin_right = 30
	_sub_pill.add_theme_stylebox_override("panel", pill)
	field.add_child(_sub_pill)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetBody"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Art.INK)
	_sub_pill.add_child(_sub)
	_sub_pill.modulate.a = 0.0
	_rw = Rewards.new()
	_rw.sticker_cols = STICKER_COLS
	add_child(_rw)
	_apply_insets()

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["FF_SCORE", "FF_BEST", "PP_WAVE"]:
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
	_wave_l = made[2]
	_wave_l.text = "1"
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The garden is scaled to the room and stood on its bottom edge: a phone is
## taller than the field, and the extra is sky the crates come down through.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_fit(s)
	_scene = _build_scene()
	_land = _build_land()
	_casts.clear()
	_dashes = _build_dashes()
	_chips = _build_chips()
	_text_fs = int(12.0 * _u)
	if _sun != null:
		var side := 58.0 * _u
		_sun.size = Vector2(side, side)
		_sun.position = _sun_at() - _sun.size * 0.5
	if _hedge != null:
		_hedge.queue_redraw()
	_redraw_all()

## The field's unit and origin in a room `s` (a tutorial page stands a slice
## of the garden in its own: ui/hud/peapod_tutorial_diagram.gd).
func _fit(s: Vector2) -> void:
	_u = minf(s.x / Sim.W, s.y / Sim.H)
	_origin = Vector2((s.x - Sim.W * _u) * 0.5, s.y - Sim.H * _u)

func px(p: Vector2) -> Vector2:
	return _origin + p * _u

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
	_touch = -1
	_mouse = false
	_hit_at.clear()
	_sparks.clear()
	_pops.clear()
	_shot_at = -10.0
	_last_x = sim.x
	_lean = 0.0
	_shake = 0.0
	_roll = 0.0
	_beat_best = false
	_heat = 0.0
	_alarm = 0.0
	_flash = 0.0
	_end_score = null
	_ghosts.clear()
	_flights.clear()
	_chip_at.clear()
	_streak_n = 0
	_streak_in = 0.0
	_wave_peak = 0.0
	_clear = {}
	_blooms.clear()
	_hop = {}
	_crown_at = -1.0
	_hold_t = 0.0
	if _sun != null:
		_sun.hat = 0.0
	_rw.clear()
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
		var d := delta * _pace(delta)
		_clock += d
		_keys()
		_acc += minf(d, Sim.DT * MAX_STEPS)
		while _acc >= Sim.DT:
			_acc -= Sim.DT
			sim.step()
			_play_events()
		_animate(d)
	_refresh_hud(delta)
	_knock_now()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()
	_redraw_all()

## How fast the run goes this frame: slowed for the beat a big moment is
## held, and eased back out of it.
func _pace(delta: float) -> float:
	if _hold_t <= 0.0:
		return 1.0
	_hold_t -= delta
	return lerpf(1.0, _hold_k, clampf(_hold_t / 0.1, 0.0, 1.0))

## Holds the run at `pace` of its speed for `seconds`: a big moment's beat.
func _hold(seconds: float, pace: float) -> void:
	if Motion.reduce:
		return
	_hold_t = maxf(_hold_t, seconds)
	_hold_k = pace

## Asks for a knock this frame; the strongest asked for is the one played.
func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _knock_now() -> void:
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1

func _redraw_all() -> void:
	field.queue_redraw()
	_over.queue_redraw()

func _animate(delta: float) -> void:
	for sp: Dictionary in _sparks:
		sp.t += delta
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return sp.t < 0.22)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 0.8)
	if _hit_at.size() > 240:
		_hit_at.clear()
	# the wheels turn as far as the cart rolled, and it leans into the roll
	var moved: float = sim.x - _last_x
	_last_x = sim.x
	_wheel += moved / 9.0
	var want_lean := 0.0 if Motion.reduce else clampf(moved / maxf(delta, 0.001) / 900.0, -1.0, 1.0) * 0.12
	_lean = lerpf(_lean, want_lean, minf(1.0, delta * 14.0))
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 12.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO
	_rw.bounds = Rect2(_rw.at(field, Vector2.ZERO), field.size)
	_rw.step(delta)
	var playing: bool = sim.phase == Sim.Phase.PLAY
	var want := clampf((sim.streak - 6) / 30.0, 0.0, 1.0) if playing else 0.0
	_heat = move_toward(_heat, want, delta * (1.5 if want > _heat else 0.8))
	_alarm = move_toward(_alarm, sim.danger(), delta * 2.0)
	_flash = maxf(0.0, _flash - delta * 2.6)
	for g: Dictionary in _ghosts:
		g.t += delta
	_ghosts = _ghosts.filter(func(g: Dictionary) -> bool: return g.t < GHOST_T)
	_step_flights(delta)
	# the streak's pill: in while a streak of five or more runs, out after
	var live: bool = playing and sim.streak >= STREAK_FROM
	if live:
		if sim.streak > _streak_n:
			_streak_at = _clock
		_streak_n = sim.streak
	_streak_in = move_toward(_streak_in, 1.0 if live else 0.0, delta * (7.0 if live else 3.0))
	_wave_peak = maxf(_wave_peak, sim.danger())
	_step_clear()
	# a puff off the wheels of a cart rolled hard
	if not Motion.reduce and absf(moved) > 6.0 * delta * 60.0 and _clock - _dust_at > 0.09:
		_dust_at = _clock
		_rw.spray(_in_rw(Vector2(sim.x - signf(moved) * 15.0, TURF - 2.0)), Color("fffaf0", 0.9), 1, 90.0, "mote", 0.7)
	_mood_sun()

## The sun's face: worried as the line is neared and at the end, beaming
## through a streak and a cleared wave; its eyes follow the cart.
func _mood_sun() -> void:
	if _sun == null:
		return
	var want: int = Face.Expr.HAPPY
	if sim.is_over() or _alarm > 0.35:
		want = Face.Expr.WORRIED
	elif _heat > 0.25 or not _clear.is_empty():
		want = Face.Expr.JOY
	if _sun.expression != want:
		_sun.expression = want
	var to := px(Vector2(sim.x, Sim.CART_Y)).x - (_sun.position.x + _sun.size.x * 0.5)
	var look := Vector2(signf(to) if absf(to) > field.size.x * 0.15 else 0.0, 1.0)
	if _sun.look != look:
		_sun.look = look

## The gifts on their way to the grass: each lands on its place with a bump.
func _step_flights(delta: float) -> void:
	if _flights.is_empty():
		return
	for f: Dictionary in _flights:
		f.t += delta
		if f.t >= FLIGHT_T:
			_chip_at[int(f.kind)] = _clock
			_quiet.cue("hit", 1.5, -7.0)
			_rw.ring(_rw.at(field, _home_of(f.kind) + _shake_off), 15.0 * _u, Color(Art.GIFT[int(f.kind)], 0.9), 0.0, 0.3)
	_flights = _flights.filter(func(f: Dictionary) -> bool: return f.t < FLIGHT_T)

## Where a gift caught comes to rest: the gun's line for a pea, the rate
## and the weight, its ring on the right for one that runs down.
func _home_of(kind: int) -> Vector2:
	var k := GUN.find(kind)
	if k >= 0:
		return _gun_chip(k)
	var timed := _timed()
	for i in timed.size():
		if int(timed[i][0]) == kind:
			return _timed_at(i)
	return _timed_at(0)

## A thing on the grass swells as a gift lands on it and settles.
func _bump(kind: int) -> float:
	var since: float = _clock - float(_chip_at.get(kind, -10.0))
	if since > 0.5 or Motion.reduce:
		return 1.0
	return 1.0 + 0.28 * exp(-since * 9.0) * cos(since * 22.0)

## The stamping of a cleared wave: its stars one at a time, each a note
## higher, and a flower up out of the grass for each.
func _step_clear() -> void:
	if _clear.is_empty():
		return
	var since: float = _clock - float(_clear.at)
	while int(_clear.said) < int(_clear.stars) and since >= 0.35 + STAR_STEP * int(_clear.said):
		var k: int = _clear.said
		_clear.said = k + 1
		_fx.cue("catch", 1.0 + 0.14 * k, -3.0)
		_feel(Haptics.TICK)
		var at := _rw.at(field, _star_at(k) + _shake_off)
		_rw.spray(at, Pal.SUN, 6, 420.0, "star", 0.8)
		_rw.ring(at, 26.0 * _u, Color(Pal.SUN, 0.8))
		_bloom()
	if since > 1.5:
		_clear = {}

func _star_at(k: int) -> Vector2:
	return field.size * Vector2(0.5, 0.3) + Vector2((k - 1) * 36.0, 78.0) * _u

## A flower comes up somewhere along the grass, clear of the others.
func _bloom() -> void:
	if _blooms.size() >= MAX_BLOOMS:
		return
	var x := 0.0
	for attempt in 12:
		x = randf_range(10.0, Sim.W - 10.0)
		var free := true
		for bl: Dictionary in _blooms:
			if absf(float(bl.x) - x) < 9.0:
				free = false
				break
		if free:
			break
	var look := randi() % Art.BLOOM.size()
	_blooms.append({"x": x, "y": randf_range(1.0, 5.0), "look": look, "at": _clock, "size": randf_range(0.85, 1.15)})
	_rw.spray(_in_rw(Vector2(x, TURF - 8.0)), Art.BLOOM[look][0], 5, 260.0, "confetti", 0.7)

func _keys() -> void:
	var axis := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		axis += 1.0
	sim.axis = axis

func _on_field_input(event: InputEvent) -> void:
	if _paused:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			if _end == null and not settings_sheet.is_open():
				_pause(false)
		return
	if sim == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1:
			_touch = t.index
			_grab(t.position)
		elif not t.pressed and t.index == _touch:
			_touch = -1
			sim.target_x = NAN
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch:
			_slide(d.position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		_mouse = m.pressed and _touch == -1
		if _mouse:
			_grab(m.position)
		elif _touch == -1:
			sim.target_x = NAN
	elif event is InputEventMouseMotion and _mouse:
		_slide((event as InputEventMouseMotion).position)

func _grab(at: Vector2) -> void:
	_touch_from = at
	_cart_from = sim.x
	sim.target_x = sim.x

## A slide, not a spot: the cart moves as far as the finger did, and a
## little more.
func _slide(at: Vector2) -> void:
	sim.target_x = _cart_from + (at.x - _touch_from.x) / _u * GAIN
	# A slide past the wall re-anchors, so coming back moves at once.
	var lo := Sim.CART_HALF
	var hi := Sim.W - lo
	if sim.target_x < lo or sim.target_x > hi:
		sim.target_x = clampf(sim.target_x, lo, hi)
		_touch_from = at
		_cart_from = sim.target_x

## The tutorial card stops the run and leaves it paused, a tap from going on.
func _tutor_hold(on: bool) -> void:
	if on and sim != null and not sim.is_over() and _end == null:
		_pause(true)

func _pause(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	if on:
		_touch = -1
		_mouse = false
		if sim != null:
			sim.target_x = NAN
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
		var pos: Vector2 = ev.get("pos", Vector2.ZERO)
		match String(ev.type):
			"ready":
				_show_banner(tr("PP_READY"), tr("PP_READY_LINE"), 1.0)
			"go":
				_fx.cue("go")
			"wave":
				_wave_peak = 0.0
				var milli: bool = ev.kind == Sim.Wave.MILLI
				if int(ev.wave) > 1:
					_show_banner(tr("PP_WAVE_N") % int(ev.wave), tr("PP_MILLI_LINE") if milli else "", 0.7)
					_fx.cue("milli" if milli else "wave")
				_wave_l.pivot_offset = _wave_l.size * 0.5
				Motion.bump(_wave_l, 0.3, 0.35)
			"shot":
				_shot_at = _clock
				_quiet.cue("shot", randf_range(0.94, 1.08), -4.0)
			"hit":
				_hit_at[ev.id] = _clock
				if not ev.quiet:
					_spark(pos, Art.colour(ev.kind, 1).lerp(Color("fffaf0"), 0.6) if Sim.holds_token(ev.kind) else Color("fffaf0"))
					if ev.kind == Sim.Kind.IRON:
						_quiet.cue("clank", randf_range(0.92, 1.1), -6.0)
					else:
						_quiet.cue("hit", randf_range(0.9, 1.15), -6.0)
			"kill":
				_on_kill(ev)
			"token":
				_fx.cue("gift", 0.7 if ev.kind == Sim.Kind.ROT else randf_range(0.96, 1.06))
				_rw.ring(_in_rw(pos), 26.0 * _u, Color(Art.colour(ev.kind, 1), 0.9))
			"catch":
				_on_catch(ev)
			"token_lost":
				_fx.cue("lost", 1.0, -6.0)
				_fx.puff(px(pos), Color("fffaf0"), 4)
			"boom":
				_fx.cue("boom")
				_feel(Haptics.THUD)
				_shake = maxf(_shake, 0.7)
				_hold(0.07, 0.4)
				_flash_now(Color("ffd65c"), 0.4)
				_rw.ring(_in_rw(pos), 78.0 * _u, Color("ffd65c", 0.95))
				_rw.ring(_in_rw(pos), 52.0 * _u, Color("fffaf0", 0.9), 0.06)
				_rw.spray(_in_rw(pos), Art.CRACKER, 12, 760.0, "shard", 1.0)
				_rw.spray(_in_rw(pos), Color("ffd65c"), 10, 820.0, "spark", 1.3)
				_rw.sticker(tr("PP_BOOM"), _in_rw(pos + Vector2(0, -26.0)), 60, 0.9, false, Color("ffd65c"), false, "boom", 30.0)
			"knock":
				_fx.cue("knock", randf_range(0.95, 1.08), -4.0)
			"twin_off":
				_fx.cue("twin_off", 1.0, -4.0)
				_fx.puff(px(Vector2(ev.x, Sim.CART_Y - 10.0)), Pal.PEAR, 7)
			"pod_off":
				_fx.cue("twin_off", 1.25, -8.0)
			"clear":
				_on_clear(ev)
			"warn":
				_fx.cue("warn")
				_feel(Haptics.WARN)
				_rw.sticker(tr("PP_CAREFUL"), _rw.at(field, field.size * Vector2(0.5, 0.52)), 62, 1.1, false, ALARM, false, "warn")
			"over":
				_fx.cue("over")
				_feel(Haptics.LOSE)
				_shake = maxf(_shake, 0.9)
				_hold(0.4, 0.3)
				_flash_now(ALARM, 0.5)
				_game_over()
			"revive":
				_flash_now(Color("fffaf0"), 0.5)
				_rw.ring(_in_rw(Vector2(sim.x, Sim.CART_Y)), 160.0 * _u, Color(Pal.SUN, 0.9))
	sim.events.clear()

func _spark(at: Vector2, col: Color) -> void:
	if _sparks.size() < MAX_SPARKS:
		_sparks.append({"pos": at, "t": 0.0, "col": col, "turn": randf() * TAU})

## A crate or a plate gone: chips of its paint, its number rising, and by
## what it was a golden shower, a head's end, or the streak's word.
func _on_kill(ev: Dictionary) -> void:
	var pos: Vector2 = ev.pos
	var kind: int = ev.kind
	var col := Art.colour(kind, int(ev.max))
	var at := _in_rw(pos)
	var k := _u / 2.4
	var popped: bool = ev.popped
	var head := kind == Sim.Kind.HEAD
	var round: bool = head or sim.wave_kind == Sim.Wave.MILLI
	_ghosts.append({"pos": pos, "round": round, "col": col.lerp(Color("fffaf0"), 0.45), "t": 0.0, "big": head})
	_rw.spray(at, col, 3 if popped else 6, 460.0, "shard", 0.9 * k)
	_rw.spray(at, Color("fffaf0"), 2 if popped else 3, 400.0, "spark", 0.9 * k)
	_spark(pos, col.lightened(0.4))
	var gold := kind == Sim.Kind.GOLD
	if _pops.size() >= MAX_POPS:
		_pops.pop_front()
	_pops.append({"pos": pos, "text": "+" + Art.short(int(ev.points)), "t": 0.0, "col": Color("fff1c2") if gold or head else Color("fffaf0"),
		"rim": Art.GOLD_INK if gold else Art.deepen(col).darkened(0.3), "big": gold or head, "drift": randf_range(-1.0, 1.0)})
	var streak: int = ev.streak
	if head:
		_fx.cue("head")
		_feel(Haptics.THUD)
		_shake = maxf(_shake, 0.6)
		_hold(0.2, 0.25)
		_flash_now(Color("fffaf0"), 0.4)
		_rw.sticker(tr("PP_SQUASHED"), _in_rw(pos + Vector2(0, -34.0)), 76, 1.3, true, Color.WHITE, true, "head", 30.0)
		_rw.ring(at, 90.0 * _u, Color(Pal.SUN, 0.9))
		_rw.spray(at, Art.HEAD, 12, 700.0, "shard", 1.1 * k)
		_rw.spray(at, Pal.SUN, 10, 760.0, "star", 1.0)
	elif gold:
		_fx.cue("pop_gold")
		_feel(Haptics.BUMP)
		_shake = maxf(_shake, 0.3)
		_flash_now(Art.GOLD, 0.3)
		_rw.spray(at, Art.GOLD, 14, 720.0, "coin", 1.0 * k)
		_rw.spray(at, Pal.SUN, 4, 520.0, "star", 0.8, 0.1, _plate_at(_score_l))
		_rw.ring(at, 44.0 * _u, Color(Art.GOLD, 0.9))
		_rw.sticker(tr("PP_GOLDEN"), _in_rw(pos + Vector2(0, -28.0)), 58, 1.1, true, Color.WHITE, true, "gold", 30.0)
	else:
		_fx.cue("pop", minf(1.5, 1.0 + 0.025 * streak), -8.0 if popped else 0.0)
		_feel(Haptics.TICK if popped else Haptics.TAP)
		_shake = maxf(_shake, 0.12)
	for i in WORDS.size():
		if streak == int(WORDS[i][0]):
			var tier := WORDS.size() - 1 - i
			var mid := _rw.at(field, field.size * Vector2(0.5, 0.42))
			_rw.sticker(tr(WORDS[i][1]), mid, 72 + 8 * tier, 1.3 + 0.12 * tier, true, Color.WHITE, tier >= 1, "word", 24.0)
			_rw.spray(mid, Pal.SUN, 6 + 3 * tier, 760.0, "star", 1.0)
			_rw.spray(mid, STICKER_COLS[tier % STICKER_COLS.size()], 8 + 2 * tier, 700.0, "confetti", 1.0)
			_flash_now(Color("fffaf0"), 0.2 + 0.06 * tier)
			_fx.cue("word", 1.0 + 0.06 * tier)
			_feel(Haptics.BUMP)
			if tier >= 3:
				_rw.rain(1.6, ["confetti", "star"], STICKER_COLS)
			break

## A gift caught: what it gave, lettered over the cart, and stars home to
## the gun's line on the grass.
func _on_catch(ev: Dictionary) -> void:
	var got: int = ev.got
	var at := _in_rw(Vector2(sim.x, Sim.CART_Y - 44.0))
	var col: Color = Art.GIFT[got]
	if got == Sim.Kind.ROT:
		# a rotten one: what it took, lettered in its own murk, and a shudder
		_fx.cue("rot")
		_feel(Haptics.WARN)
		_shake = maxf(_shake, 0.4)
		_flash_now(Art.ROT_INK, 0.35)
		_rw.sticker(tr(ROT[int(ev.lost)]), at + Vector2(0, -30.0), 58, 1.1, false, Color("d9c7e0"), false, "got", 34.0)
		_rw.spray(at, Art.ROT_INK, 8, 420.0, "shard", 0.9)
		return
	_fx.cue(CATCH_CUE.get(got, "catch"), 1.0 + 0.04 * (sim.peas + sim.rate_lv))
	_feel(Haptics.GOOD)
	_hop = {"at": _clock, "tall": 3.5, "time": 0.22, "twice": false}
	if got == Sim.Kind.SHOVE:
		_rw.ring(_in_rw(Vector2(Sim.W * 0.5, Sim.CART_Y - 60.0)), 200.0 * _u, Color(col, 0.9))
		_shake = maxf(_shake, 0.3)
	elif not Motion.reduce:
		# it flies to its place on the grass
		_flights.append({"kind": got, "from": px(Vector2(sim.x, Sim.CART_Y - 30.0)), "t": 0.0})
	else:
		_chip_at[got] = _clock
	_rw.sticker(tr(GOT[got]), at + Vector2(0, -30.0), 58, 1.1, false, col.lightened(0.25), false, "got", 34.0)
	_rw.ring(_in_rw(Vector2(sim.x, Sim.CART_Y - 14.0)), 40.0 * _u, Color(col, 0.9))
	_rw.spray(at, col, 8, 520.0, "star", 0.9)
	_rw.spray(at, Color("fffaf0"), 6, 460.0, "spark", 1.0)
	_flash_now(col, 0.16)

## A wave cleared: lettered, its bonus under it, one to three stars stamped
## by how far off the line was kept (a flower for each: `_step_clear`), the
## cart hopping and the pod letting off a volley of its own, a short rain.
func _on_clear(ev: Dictionary) -> void:
	var mid := _rw.at(field, field.size * Vector2(0.5, 0.3))
	_fx.cue("clear")
	_feel(Haptics.BUMP)
	var stars := 3 if _wave_peak < float(STAR_PEAKS[0]) else (2 if _wave_peak < float(STAR_PEAKS[1]) else 1)
	_clear = {"at": _clock, "stars": stars, "said": 0}
	_hop = {"at": _clock, "tall": 11.0, "time": 0.7, "twice": true}
	_hold(0.16, 0.35)
	_rw.sticker(tr("PP_CLEARED"), mid, 78, 1.3, true, Color.WHITE, true, "clear", 0.0, true)
	_rw.sticker("+" + Record.grouped(int(ev.bonus)), mid + Vector2(0, 34.0 * _u), 46, 1.3, false, Pal.SUN, false, "clear_bonus", 0.0, true)
	_rw.spray(mid, Pal.SUN, 12, 780.0, "star", 1.0)
	_rw.spray(mid, Pal.SUN, 5, 520.0, "star", 0.8, 0.15, _plate_at(_score_l))
	var mouth := _in_rw(Vector2(sim.x, Sim.CART_Y - 46.0))
	for i in STICKER_COLS.size():
		_rw.spray(mouth, STICKER_COLS[i], 3, 900.0, "confetti", 0.9, 0.05 * i)
	_rw.rain(1.2, ["confetti", "star"], STICKER_COLS)
	_flash_now(Color("fffaf0"), 0.25)

## A banner: the word as a sticker, a letter hopping in at a time, and the
## line under it on a paper pill.
func _show_banner(text: String, sub: String, hold: float) -> void:
	var mid := field.size * Vector2(0.5, 0.36)
	_rw.sticker(text, _rw.at(field, mid), 92, hold + 0.75, true, Color.WHITE, false, "banner", 0.0, true)
	Motion.stop(_banner_tw)
	_sub.text = sub
	if sub == "":
		_sub_pill.modulate.a = 0.0
		return
	_sub_pill.reset_size()
	_sub_pill.position = Vector2((field.size.x - _sub_pill.size.x) * 0.5, mid.y + 60.0)
	_sub_pill.pivot_offset = _sub_pill.size * 0.5
	_banner_tw = create_tween()
	if Motion.reduce:
		_sub_pill.scale = Vector2.ONE
		_banner_tw.tween_property(_sub_pill, "modulate:a", 1.0, 0.15)
		_banner_tw.tween_interval(hold)
		_banner_tw.tween_property(_sub_pill, "modulate:a", 0.0, 0.3)
		return
	_sub_pill.scale = Vector2(0.7, 0.7)
	_sub_pill.modulate.a = 0.0
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(_sub_pill, "modulate:a", 1.0, 0.14).set_delay(0.12)
	_banner_tw.tween_property(_sub_pill, "scale", Vector2.ONE, 0.34).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(hold)
	_banner_tw.chain().tween_property(_sub_pill, "modulate:a", 0.0, 0.3)

## The score rolls up to the real one and gives a beat when it lands; the
## best follows it once passed.
func _refresh_hud(delta := 0.0) -> void:
	if sim == null:
		return
	if sim.score != _shown_score:
		if sim.score > _shown_score and _shown_score >= 0:
			_score_l.pivot_offset = _score_l.size * 0.5
			Motion.bump(_score_l, 0.1, 0.2)
		_shown_score = sim.score
		if not _beat_best and _best > 0 and sim.score > _best:
			_beat_best = true
			_best_l.pivot_offset = _best_l.size * 0.5
			Motion.bump(_best_l, 0.3, 0.4)
			_new_best_passed()
	if Motion.reduce or sim.score < _roll:
		_roll = sim.score
	else:
		_roll = move_toward(_roll, sim.score, maxf(delta * absf(sim.score - _roll) * 10.0, delta * 300.0))
	var shown := Record.grouped(int(_roll))
	if _score_l.text != shown:
		_score_l.text = shown
		_best_l.text = Record.grouped(maxi(_best, int(_roll)))
	var wave := str(maxi(1, sim.wave))
	if _wave_l.text != wave:
		_wave_l.text = wave

# --- drawing ---

## Where the sun stands: low on the right, coming up from behind the far
## hills, clear of the sky the crates come down.
func _sun_at() -> Vector2:
	return px(Vector2(Sim.W * 0.8, TURF - 94.0))

## The garden's foot from `y0` down, its round corners kept.
func _foot(b: Face.Builder, y0: float, col: Color) -> void:
	var s := field.size
	var pts := PackedVector2Array([Vector2(0, y0), Vector2(s.x, y0)])
	pts.append_array(Face.Builder.arc_points(Vector2(s.x - ROUND, s.y - ROUND), ROUND, 0.0, PI * 0.5))
	pts.append_array(Face.Builder.arc_points(Vector2(ROUND, s.y - ROUND), ROUND, PI * 0.5, PI))
	b.fan(pts, col)

## The still sky, built on resize: pale blue going to cream at the grass,
## and the sun's glow.
func _build_scene() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	var k := _u / 2.4
	var turf := px(Vector2(0, TURF)).y
	# the sky: one rounded sheet, a colour a vertex by how far down it is
	var rim := Face.Builder.round_rect(Vector2.ZERO, s, ROUND)
	var mid := b.vertex(s * 0.5, SKY_TOP.lerp(SKY_LOW, clampf(s.y * 0.5 / turf, 0.0, 1.0)))
	var first := -1
	var prev := -1
	for p in rim:
		var i := b.vertex(p, SKY_TOP.lerp(SKY_LOW, clampf(p.y / turf, 0.0, 1.0)))
		if prev >= 0:
			b.tri(mid, prev, i)
		else:
			first = i
		prev = i
	b.tri(mid, prev, first)
	# the sun's glow and rays; its face is a node of its own over them, and
	# where there is none (a tutorial page) a plain pale disc
	var sun := _sun_at()
	b.disc(sun, 62.0 * k, Color(1, 0.96, 0.78, 0.4))
	Rewards.sunrays(b, sun, 56.0 * k, 124.0 * k, 12, 0.2, Color(1, 0.95, 0.72, 0.26))
	if _sun == null:
		b.disc(sun, 40.0 * k, Color("fdeeb5"))
	return b.mesh()

## The still land, laid over the sky and the sun: three rows of soft hills
## with round trees and bushes on them, and the grass the cart rolls on.
func _build_land() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	var turf := px(Vector2(0, TURF)).y
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	# three rows of hills, the far one palest
	for i in 3:
		b.ellipse(Vector2(s.x * (0.12 + 0.38 * i), turf + 12.0 * _u), s.x * 0.34, (72.0 + 16.0 * ((i + 1) % 2)) * _u, HILL_FAR)
	for i in 4:
		b.ellipse(Vector2(s.x * 0.33 * i, turf + 8.0 * _u), s.x * 0.26, (40.0 + 10.0 * (i % 2)) * _u, HILL)
	for i in 3:
		b.ellipse(Vector2(s.x * (0.2 + 0.36 * i), turf + 6.0 * _u), s.x * 0.24, (20.0 + 6.0 * (i % 2)) * _u, HILL_NEAR)
	# a few round trees along them
	for i in 6:
		var at := Vector2(s.x * rng.randf_range(0.05, 0.95), turf - rng.randf_range(5.0, 22.0) * _u)
		var r := rng.randf_range(5.0, 8.0) * _u
		b.fan(Face.Builder.round_rect(at + Vector2(-r * 0.14, 0), Vector2(r * 0.28, r * 1.1), r * 0.1), Color("c9a172", 0.8))
		b.disc(at + Vector2(0, -r * 0.34), r, BUSH[0])
		b.disc(at + Vector2(-r * 0.12, -r * 0.5), r * 0.78, BUSH[1])
		b.disc(at + Vector2(-r * 0.3, -r * 0.74), r * 0.36, Color(1, 1, 1, 0.16))
	# and Posy's bushes at the garden's sides, starred with daisies
	for side in [0.0, 1.0]:
		for i in 3:
			var at := Vector2(s.x * (side + (0.02 + 0.07 * i) * (1.0 - 2.0 * side)), turf - rng.randf_range(0.0, 6.0) * _u)
			var r := rng.randf_range(9.0, 13.0) * _u
			for layer in 3:
				b.disc(at + Vector2(rng.randf_range(-2.0, 2.0) * _u, -layer * r * 0.24), r * (1.0 - 0.2 * layer), BUSH[layer])
			var d := at + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.9, -0.3)) * r
			for q in 5:
				b.disc(d + Vector2.from_angle(TAU * q / 5.0) * 1.7 * _u, 1.35 * _u, Color("fffaf0"))
			b.disc(d, 1.1 * _u, Color("f6cb5e"))
	# the grass: a pale lip, and a scalloped edge to the deeper turf under it
	_foot(b, turf, GRASS)
	b.fan(PackedVector2Array([Vector2(0, turf), Vector2(s.x, turf), Vector2(s.x, turf + 2.6 * _u), Vector2(0, turf + 2.6 * _u)]), GRASS_LIP)
	var y0 := turf + 15.0 * _u
	var scallop := 8.0 * _u
	var x := scallop * 0.5
	while x < s.x:
		b.disc(Vector2(x, y0), scallop * 0.62, GRASS_DEEP)
		x += scallop
	_foot(b, y0, GRASS_DEEP)
	return b.mesh()

## The hedges round the card's foot (Posy's): leafy bushes poking out past
## its sides and lower corners, built once for the card where it stands.
func _draw_hedge() -> void:
	if _frame == null or _frame.size.x <= 0.0:
		return
	var rect := Rect2(_hedge.get_global_transform().affine_inverse() * _frame.global_position, _frame.size)
	if _hedge_mesh == null or rect != _hedge_rect:
		_hedge_rect = rect
		var b := Face.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var spots: Array = []
		var y := rect.end.y - rect.size.y * 0.3
		while y < rect.end.y + 30.0:
			for side in [0, 1]:
				var x: float = rect.position.x - 4.0 if side == 0 else rect.end.x + 4.0
				spots.append(Vector2(x + rng.randf_range(-12.0, 12.0), y))
			y += rng.randf_range(84.0, 130.0)
		for corner in [Vector2(rect.position.x, rect.end.y), rect.end]:
			for i in 3:
				spots.append(corner + Vector2(rng.randf_range(-36.0, 36.0), rng.randf_range(-26.0, 22.0)))
		for layer in 3:
			for p: Vector2 in spots:
				var r := rng.randf_range(32.0, 52.0) * (1.0 - layer * 0.18)
				b.disc(p + Vector2(rng.randf_range(-10.0, 10.0), -layer * 10.0), r, BUSH[layer])
		for p: Vector2 in spots:
			if rng.randf() < 0.55:
				var at := p + Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-28.0, 0.0))
				for q in 6:
					b.disc(at + Vector2.from_angle(TAU * q / 6.0) * 7.0, 5.2, Color("fffaf0"))
				b.disc(at, 4.2, Color("f6cb5e"))
		_hedge_mesh = b.mesh()
	_hedge.draw_mesh(_hedge_mesh, null)

func _draw_field() -> void:
	if _scene == null:
		_layout_field()
	if _scene != null:
		field.draw_mesh(_scene, null)

## Over the sky and the sun the land, and then everything that moves, back
## to front: the clouds (under the land), the line, the crates
## or the millipede and their numbers, the peas and the sparks, what is
## laid fresh (the streak's pill, the stars, the glows), the gun's line and
## what is running down, the flowers, the gifts on their way down, the
## carts, the gifts flying home and the numbers going up.
func _draw_over() -> void:
	if sim == null:
		return
	var font := Art.font()
	_cast_turn = 0
	_over.draw_set_transform(Vector2.ZERO)
	_draw_clouds()
	if _land != null:
		_over.draw_mesh(_land, null)
	_over.draw_set_transform(_shake_off)
	if sim.frost_t > 0.0:
		# the frost: a pale wash over the garden, going as it runs out
		_over.draw_rect(Rect2(Vector2.ZERO, field.size), Color(FROST, 0.2 * minf(1.0, sim.frost_t)))
	_draw_line()
	var top := Face.Builder.new()
	_head_tag = []
	_draw_ghosts()
	if sim.wave_kind == Sim.Wave.WALL:
		_draw_wall(font)
	else:
		_draw_milli(font, top)
	_draw_peas()
	_draw_sparks()
	_draw_muzzle(top)
	var timed := _timed()
	_draw_timed_seats(top, timed)
	_draw_streak_pill(top)
	_draw_stars(top)
	if sim.frost_t > 0.0:
		Rewards.edge_glow(top, Rect2(Vector2.ZERO, field.size), FROST, minf(1.0, sim.frost_t), 0.6)
	if _heat > 0.01:
		var hb := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 9.0)
		Rewards.edge_glow(top, Rect2(Vector2.ZERO, field.size), HEAT.lerp(ALARM, _heat), _heat, hb)
	if _alarm > 0.01:
		var ab := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 11.0)
		Rewards.edge_glow(top, Rect2(Vector2.ZERO, field.size), ALARM, _alarm, ab)
	if not top.verts.is_empty():
		_live_top = top.mesh()
		_over.draw_mesh(_live_top, null)
	if _chips != null:
		_over.draw_mesh(_chips, null)
	# the medallions on the gun's line, and what is running down
	for k in GUN.size():
		var sc := 0.62 * _bump(GUN[k])
		_cast_add(Art.token(GUN[k], _u), Transform2D(0.0, Vector2(sc, sc), 0.0, _gun_chip(k)), Color.WHITE)
	for k in timed.size():
		var blink: bool = float(timed[k][1]) < 0.2 and fmod(_clock, 0.3) < 0.12 and not Motion.reduce
		var sc := 0.6 * _bump(timed[k][0])
		_cast_add(Art.token(timed[k][0], _u), Transform2D(0.0, Vector2(sc, sc), 0.0, _timed_at(k)), Color(1, 1, 1, 0.45 if blink else 1.0))
	_draw_blooms()
	for tk: Dictionary in sim.tokens:
		var bob := 1.0 if Motion.reduce else 1.0 + 0.08 * sin(_clock * 9.0 + float(tk.id))
		var tilt := 0.0 if Motion.reduce else sin(_clock * 4.0 + float(tk.id)) * 0.18
		_cast_add(Art.token(tk.kind, _u), Transform2D(tilt, Vector2(bob, bob), 0.0, px(Vector2(tk.x, tk.y))), Color.WHITE)
	_cast_draw()
	if not _head_tag.is_empty():
		Art.number(_over, font, px(_head_tag[0]), _head_tag[1], Sim.SEG_R * 1.25 * _u, 1.0, Sim.Kind.HEAD)
	if sim.twin_t > 0.0:
		_draw_cart(sim.twin_x, true)
	_draw_cart(sim.x, false)
	_draw_flights()
	_draw_gun_words(font)
	_draw_streak_words(font)
	_draw_pops(font)
	_over.draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		_over.draw_rect(Rect2(Vector2.ZERO, field.size), Color(_flash_col, _flash * 0.4))

## Three clouds drifting across the top of the sky, round and round.
func _draw_clouds() -> void:
	var s := field.size
	var w := 84.0 * _u / 2.4
	var mesh := Art.cloud(w)
	var t := 0.0 if Motion.reduce else _clock
	for i in 3:
		var span := s.x + w * 2.0
		var x := fposmod(s.x * (0.1 + 0.37 * i) + t * (5.0 + 2.5 * i), span) - w
		var sc := 1.0 + 0.25 * (i % 2)
		_cast_add(mesh, Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(x, s.y * (0.07 + 0.11 * i))), Color(1, 1, 1, 0.75))
	_cast_draw()

## The line nothing may reach: soft dashes across the garden, turning red
## and running as something nears it. The dashes are one mesh built with
## the garden; the run is its transform and the red its tint.
func _build_dashes() -> ArrayMesh:
	var b := Face.Builder.new()
	var dash := 9.0 * _u
	var x := -dash * 2.0
	while x < field.size.x + dash * 2.0:
		b.fan(Face.Builder.round_rect(Vector2(x, -1.2 * _u), Vector2(dash, 2.4 * _u), 1.2 * _u), Color.WHITE)
		x += dash * 2.0
	return b.mesh()

func _draw_line() -> void:
	if _dashes == null:
		return
	var y := px(Vector2(0, Sim.DANGER + 6.0)).y
	var col := Color("fffaf0", 0.85).lerp(Color(ALARM, 0.95), _alarm)
	var dash := 9.0 * _u
	var run := 0.0 if Motion.reduce else fmod(_clock * 30.0 * _alarm, dash * 2.0)
	_over.draw_mesh(_dashes, null, Transform2D(0.0, Vector2(run - dash * 2.0, y)), col)

## One MultiMesh a look of pea, as many shown as are in the air; a pea
## flung out by the Fan leans the way it goes.
func _draw_peas() -> void:
	var looks := 3
	if _pea_mm.is_empty():
		for k in looks:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			_pea_mm.append(mm)
			_pea_buf.append(PackedFloat32Array())
	var counts := [0, 0, 0]
	var u := _u
	var ox := _origin.x
	var oy := _origin.y
	for p: Dictionary in sim.shots:
		var k: int = p.k
		var buf: PackedFloat32Array = _pea_buf[k]
		var o: int = counts[k] * 8
		if o + 8 > buf.size():
			buf.resize(o + 8 * 64)
		var vx: float = p.vx
		if vx == 0.0:
			buf[o] = 1.0
			buf[o + 1] = 0.0
			buf[o + 4] = 0.0
			buf[o + 5] = 1.0
		else:
			var a := atan2(vx, Sim.PEA_SPEED)
			buf[o] = cos(a)
			buf[o + 1] = -sin(a)
			buf[o + 4] = sin(a)
			buf[o + 5] = cos(a)
		buf[o + 3] = ox + float(p.x) * u
		buf[o + 7] = oy + float(p.y) * u
		_pea_buf[k] = buf
		counts[k] += 1
	for k in looks:
		if counts[k] == 0:
			continue
		var mm: MultiMesh = _pea_mm[k]
		var buf: PackedFloat32Array = _pea_buf[k]
		var mesh := Art.shot(k, _u)
		if mm.mesh != mesh:
			mm.mesh = mesh
		if mm.instance_count * 8 != buf.size():
			mm.instance_count = buf.size() / 8
		mm.visible_instance_count = counts[k]
		mm.buffer = buf
		_over.draw_multimesh(mm, null)

## How a crate or a plate sits this frame, as [its squeeze, how fresh the
## knock is 1..0]: squeezed by the pea that just landed, else as it is. The
## knock is shown by a white blink laid over the piece, never by its paint.
func _knocked(id: int) -> Array:
	var since: float = _clock - float(_hit_at.get(id, -10.0))
	if since > 0.12:
		return [Vector2.ONE, 0.0]
	var k := 1.0 - since / 0.12
	var sc := Vector2.ONE if Motion.reduce else Vector2(1.0 + 0.08 * k, 1.0 - 0.1 * k)
	return [sc, k]

## One more of `mesh` this frame, under `xf` and tinted `col`. What is
## gathered is drawn by the next `_cast_draw`, and each of a frame's draws
## keeps MultiMeshes of its own (`_casts`, by the draw's turn): a MultiMesh
## holds one buffer, so the same mesh drawn twice in a frame from one of
## them showed the second draw's copies both times.
func _cast_add(mesh: ArrayMesh, xf: Transform2D, col: Color) -> void:
	while _casts.size() <= _cast_turn:
		_casts.append({})
	var cast: Dictionary = _casts[_cast_turn]
	var g: Array = cast.get(mesh, [])
	if g.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = mesh
		g = [mm, PackedFloat32Array(), 0]
		cast[mesh] = g
	var buf: PackedFloat32Array = g[1]
	var o: int = int(g[2]) * 12
	if o + 12 > buf.size():
		buf.resize(o + 12 * 8)
	buf[o] = xf.x.x
	buf[o + 1] = xf.y.x
	buf[o + 3] = xf.origin.x
	buf[o + 4] = xf.x.y
	buf[o + 5] = xf.y.y
	buf[o + 7] = xf.origin.y
	buf[o + 8] = col.r
	buf[o + 9] = col.g
	buf[o + 10] = col.b
	buf[o + 11] = col.a
	g[1] = buf
	g[2] = int(g[2]) + 1

## Draws what `_cast_add` gathered since the last one and moves on to the
## frame's next draw. Called the same number of times every frame, whether
## or not anything was gathered, so a draw keeps its MultiMeshes.
func _cast_draw() -> void:
	if _casts.size() <= _cast_turn:
		_cast_turn += 1
		return
	var cast: Dictionary = _casts[_cast_turn]
	_cast_turn += 1
	for mesh in cast:
		var g: Array = cast[mesh]
		var n: int = g[2]
		if n == 0:
			continue
		var mm: MultiMesh = g[0]
		var buf: PackedFloat32Array = g[1]
		if mm.instance_count * 12 != buf.size():
			mm.instance_count = buf.size() / 12
		mm.visible_instance_count = n
		mm.buffer = buf
		_over.draw_multimesh(mm, null)
		g[2] = 0

## The shapes crates and plates just gone leave: swelling and thinning away.
func _draw_ghosts() -> void:
	for g: Dictionary in _ghosts:
		var k: float = g.t / GHOST_T
		var sc := 1.0 if Motion.reduce else 1.0 + 0.3 * (1.0 - (1.0 - k) * (1.0 - k))
		if g.big:
			sc *= Sim.HEAD_R / Sim.SEG_R
		var col: Color = g.col
		_cast_add(Art.blank(g.round, _u), Transform2D(0.0, Vector2(sc, sc), 0.0, px(g.pos)), Color(col, 0.7 * (1.0 - k)))

## The white blink over each piece a pea just landed on (`lit`: [where it
## is drawn, how fresh the knock is]).
func _draw_blinks(lit: Array, round: bool) -> void:
	var blank := Art.blank(round, _u)
	for l: Array in lit:
		_cast_add(blank, l[0], Color(1, 1, 1, 0.55 * float(l[1])))
	_cast_draw()

## The numbers, in ink: `numbered` is [where, the number, the kind, how
## fresh a knock is], and one just knocked swells a little.
func _letter(font: Font, numbered: Array, s: float) -> void:
	for n: Array in numbered:
		var c := px(n[0])
		var k: float = n[3]
		if k > 0.0 and not Motion.reduce:
			var sc := 1.0 + 0.18 * k
			_over.draw_set_transform(_shake_off + c, 0.0, Vector2(sc, sc))
			Art.number(_over, font, Vector2.ZERO, n[1], s, 1.0, n[2])
			_over.draw_set_transform(_shake_off)
		else:
			Art.number(_over, font, c, n[1], s, 1.0, n[2])

func _draw_wall(font: Font) -> void:
	var numbered: Array = []
	var lit: Array = []
	for r in sim.rows.size():
		var row: Array = sim.rows[r]
		for c in Sim.COLS:
			if row[c] == null:
				continue
			var cell: Dictionary = row[c]
			var at: Vector2 = sim.cell_pos(r, c)
			if at.y < -Sim.CELL_H - _origin.y / _u:
				continue
			var kn := _knocked(cell.id)
			var kind: int = cell.kind
			var tier := Art.tier_of(cell.hp) if kind == Sim.Kind.CRATE else 0
			var xf := Transform2D(0.0, kn[0], 0.0, px(at))
			if Sim.holds_token(kind) and not Motion.reduce:
				# a parcel sways and breathes, to be noticed
				var ph: float = _clock * 3.2 + c * 1.7 + r
				xf = Transform2D(sin(ph) * 0.04, kn[0] * (1.0 + 0.025 * sin(ph * 1.3)), 0.0, px(at))
			_cast_add(Art.crate(kind, tier, _u), xf, Color.WHITE)
			if float(kn[1]) > 0.0:
				lit.append([xf, kn[1]])
			if kind == Sim.Kind.CRATE or kind == Sim.Kind.GOLD or kind == Sim.Kind.IRON:
				numbered.append([at + Vector2(0, -Art.LIP * 0.5), cell.hp, kind, kn[1]])
	_cast_draw()
	_draw_blinks(lit, false)
	_letter(font, numbered, (Sim.CELL_H - 3.0) * _u)

func _draw_milli(font: Font, top: Face.Builder) -> void:
	var numbered: Array = []
	var lit: Array = []
	var head_at: Array = []
	# tail first, so each plate laps the one behind it and the head laps all
	for i in range(sim.segs.size() - 1, -1, -1):
		var sg: Dictionary = sim.segs[i]
		var s: float = sg.s
		if s < -Sim.SEG_R - _origin.x / _u:
			continue
		var at: Vector2 = Sim.path_at(s)
		var kn := _knocked(sg.id)
		var sc: Vector2 = kn[0]
		var jitter := Vector2.ZERO
		var waddle := 0.0
		if not Motion.reduce:
			var beat := 1.0 + 0.04 * sin(_clock * 7.0 - i * 0.9)
			sc *= Vector2(beat, beat)
			# its legs go, a plate after the one before
			waddle = 0.1 * sin(_clock * 9.0 - i * 1.3)
			if float(sg.dying) >= 0.0:
				jitter = Vector2(sin(_clock * 90.0 + i), cos(_clock * 70.0 + i)) * 1.5
		if sg.kind == Sim.Kind.HEAD:
			var ahead: Vector2 = Sim.path_at(s + 3.0) - at
			var ang := ahead.angle() if ahead.length_squared() > 0.0001 else 0.0
			var cross: bool = sim.danger() > 0.35 or sim.is_over()
			head_at = [Art.head(_u, cross), Transform2D(ang, sc, 0.0, px(at))]
			if float(kn[1]) > 0.0:
				var big := Sim.HEAD_R / Sim.SEG_R
				lit.append([Transform2D(0.0, sc * big, 0.0, px(at)), kn[1]])
			# the pupils, turned with the head and watching the cart
			var look := (Vector2(sim.x, Sim.CART_Y) - at).normalized()
			var r := Sim.HEAD_R * _u
			for side in [-1.0, 1.0]:
				var eye := px(at) + Vector2(r * 0.36, side * r * 0.4 - 1.0 * _u).rotated(ang)
				top.disc(eye + look * r * 0.12, r * 0.15, Art.FEELER)
			# its number on a paper tag over it, lettered last so nothing laps it
			var tag := at + Vector2(0, -Sim.HEAD_R - 9.0)
			var wide := (9.0 + 5.0 * Art.short(sg.hp).length()) * _u
			var tag_at := px(tag) - Vector2(wide, 7.5 * _u)
			top.fan(Face.Builder.round_rect(tag_at + Vector2(0, 1.6 * _u), Vector2(wide * 2.0, 15.0 * _u), 7.5 * _u), Color(Art.HEAD_DEEP, 0.5))
			top.fan(Face.Builder.round_rect(tag_at, Vector2(wide * 2.0, 15.0 * _u), 7.5 * _u), Art.PAPER)
			_head_tag = [tag, sg.hp]
			continue
		var kind: int = sg.kind
		var tier := Art.tier_of(sg.hp) if kind == Sim.Kind.CRATE else 0
		var xf := Transform2D(waddle, sc, 0.0, px(at + jitter))
		_cast_add(Art.plate(kind, tier, _u), xf, Color.WHITE)
		if float(kn[1]) > 0.0:
			lit.append([xf, kn[1]])
		if kind == Sim.Kind.CRATE or kind == Sim.Kind.GOLD or kind == Sim.Kind.IRON:
			numbered.append([at + Vector2(0, -Sim.SEG_R * 0.09), sg.hp, kind, kn[1]])
	_cast_draw()
	if not head_at.is_empty():
		_over.draw_mesh(head_at[0], null, head_at[1])
	_draw_blinks(lit, true)
	_letter(font, numbered, Sim.SEG_R * 1.7 * _u)

func _draw_sparks() -> void:
	if _sparks.is_empty():
		return
	if _spark_mm == null:
		_spark_mm = MultiMesh.new()
		_spark_mm.transform_format = MultiMesh.TRANSFORM_2D
		_spark_mm.use_colors = true
		_spark_mm.mesh = Art.spark()
		_spark_mm.instance_count = MAX_SPARKS
		_spark_buf.resize(MAX_SPARKS * 12)
	var n := mini(_sparks.size(), MAX_SPARKS)
	for i in n:
		var sp: Dictionary = _sparks[i]
		var k: float = sp.t / 0.22
		var c := px(sp.pos)
		var r := (4.0 + 7.0 * k) * _u
		var ca := cos(float(sp.turn)) * r
		var sa := sin(float(sp.turn)) * r
		var col: Color = sp.col
		var o := i * 12
		_spark_buf[o] = ca
		_spark_buf[o + 1] = -sa
		_spark_buf[o + 3] = c.x
		_spark_buf[o + 4] = sa
		_spark_buf[o + 5] = ca
		_spark_buf[o + 7] = c.y
		_spark_buf[o + 8] = col.r
		_spark_buf[o + 9] = col.g
		_spark_buf[o + 10] = col.b
		_spark_buf[o + 11] = 1.0 - k
	_spark_mm.visible_instance_count = n
	_spark_mm.buffer = _spark_buf
	_over.draw_multimesh(_spark_mm, null)

## The puff at each pod's mouth just after a volley: a pale ring opening
## and going.
func _draw_muzzle(b: Face.Builder) -> void:
	var since := _clock - _shot_at
	if since > 0.1 or Motion.reduce or sim.phase != Sim.Phase.PLAY:
		return
	var k := since / 0.1
	var xs: Array = [sim.x]
	if sim.twin_t > 0.0:
		xs.append(sim.twin_x)
	for x: float in xs:
		var c := px(Vector2(x, Sim.CART_Y - 41.0))
		var r := (5.0 + 7.0 * k) * _u
		b.stroke(Face.Builder.ring(c, r, r * 0.55), (2.6 - 2.0 * k) * _u, Color(Art.PAPER, 0.9 * (1.0 - k)), true)
		b.disc(c, 3.0 * _u * (1.0 - k), Color(Art.POD_HI, 0.9 * (1.0 - k)))

## How far the cart is off the grass this frame, in pixels: a small hop as
## a gift is caught, two bounces as a wave is cleared.
func _hop_now() -> float:
	if _hop.is_empty() or Motion.reduce:
		return 0.0
	var k: float = (_clock - float(_hop.at)) / float(_hop.time)
	if k >= 1.0:
		_hop = {}
		return 0.0
	if _hop.twice:
		return absf(sin(k * TAU)) * float(_hop.tall) * _u * (1.0 - 0.5 * k)
	return sin(k * PI) * float(_hop.tall) * _u

## A cart: the pod sunk into its cradle by the shot just fired, the box, and
## two wheels turned as far as it has rolled. The helper's is smaller. The
## cart's own pod wears the crown once the best is passed.
func _draw_cart(x: float, helper: bool) -> void:
	var u := _u * (0.8 if helper else 1.0)
	var hop := _hop_now()
	var foot := px(Vector2(x, TURF)) - Vector2(0, 9.0 * u + hop)
	var since := _clock - _shot_at
	var kick := 0.0
	if since < RECOIL and not Motion.reduce and sim.phase == Sim.Phase.PLAY:
		kick = 1.0 - since / RECOIL
		kick *= kick
	var tint := Color.WHITE
	if helper and sim.twin_t < 2.5 and fmod(_clock, 0.3) < 0.12 and not Motion.reduce:
		tint = Color(1, 1, 1, 0.45)
	var lean := Transform2D(_lean, foot)
	var pod := lean * Transform2D(0.0, Vector2(1.0 + 0.08 * kick, 1.0 - 0.12 * kick), 0.0, Vector2(0, (-12.0 + 3.5 * kick) * u))
	_over.draw_mesh(Art.barrel(u, helper), null, pod, tint)
	_over.draw_mesh(Art.cart(u, helper), null, lean, tint)
	var spin := _wheel + (hop / _u) * 0.2
	for side in [-1.0, 1.0]:
		_over.draw_mesh(Art.wheel(u), null, Transform2D(spin, foot + Vector2(side * 13.0 * u, 0)), tint)
	if not helper and _crown_at >= 0.0:
		# it drops onto the pod's lip and sits there, a little askew
		var k := 1.0 if Motion.reduce else clampf((_clock - _crown_at) / 0.5, 0.0, 1.0)
		var drop := (1.0 - Motion.back_out(k)) * 40.0 * u
		_over.draw_mesh(Art.crown(u), null, pod * Transform2D(-0.3, Vector2(-6.5 * u, -30.5 * u - drop)))

## The gun's line on the grass: a paper pill each for the peas, the rate
## and the pea's weight, a medallion on it and its number beside that.
func _gun_chip(k: int) -> Vector2:
	return px(Vector2(18.0 + 56.0 * k, Sim.H - 13.0))

func _build_chips() -> ArrayMesh:
	var b := Face.Builder.new()
	for k in 3:
		var at := _gun_chip(k) + Vector2(-12.0, -9.5) * _u
		var size := Vector2(48.0, 19.0) * _u
		b.fan(Face.Builder.round_rect(at + Vector2(0, 1.8 * _u), size, 9.5 * _u), Color(0.2, 0.32, 0.1, 0.2))
		b.fan(Face.Builder.round_rect(at, size, 9.5 * _u), Art.CREAM)
	return b.mesh()

## What is running down, as [kind, the part of it left]: the pod held, the
## magnet, the frost and the helper, lettered from the right of the grass.
func _timed() -> Array:
	var out: Array = []
	if sim.pod_t > 0.0:
		out.append([sim.pod, sim.pod_t / Sim.POD_TIME])
	if sim.magnet_t > 0.0:
		out.append([Sim.Kind.MAGNET, sim.magnet_t / Sim.MAGNET_TIME])
	if sim.frost_t > 0.0:
		out.append([Sim.Kind.FROST, sim.frost_t / Sim.FROST_TIME])
	if sim.twin_t > 0.0:
		out.append([Sim.Kind.TWIN, sim.twin_t / Sim.TWIN_TIME])
	return out

func _timed_at(k: int) -> Vector2:
	return px(Vector2(Sim.W - 14.0 - 24.0 * k, Sim.H - 13.0))

## Under each: a paper seat and a ring of its own colour that runs down
## with it.
func _draw_timed_seats(b: Face.Builder, timed: Array) -> void:
	for k in timed.size():
		var c := _timed_at(k)
		b.disc(c + Vector2(0, 1.8 * _u), 10.8 * _u, Color(0.2, 0.32, 0.1, 0.2))
		b.disc(c, 10.8 * _u, Art.CREAM)
		var part := clampf(float(timed[k][1]), 0.0, 1.0)
		if part > 0.02:
			b.stroke(Face.Builder.arc_points(c, 9.2 * _u, -PI * 0.5, -PI * 0.5 + TAU * part), 1.9 * _u, Art.deepen(Art.GIFT[int(timed[k][0])]))

func _draw_gun_words(font: Font) -> void:
	var values := [sim.peas, sim.rate_lv + 1, sim.power]
	var ink := Art.INK
	for k in 3:
		var text := "x%s" % Art.short(values[k])
		var at := _gun_chip(k) + Vector2(10.5 * _u, _text_fs * 0.36)
		var sc := _bump(GUN[k])
		if sc != 1.0:
			_over.draw_set_transform(_shake_off + at, 0.0, Vector2(sc, sc))
			_over.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs, ink)
			_over.draw_set_transform(_shake_off)
		else:
			_over.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs, ink)

## The flowers the run has grown, each popping up out of the grass and
## nodding after.
func _draw_blooms() -> void:
	for bl: Dictionary in _blooms:
		var since: float = _clock - float(bl.at)
		var sc: float = bl.size
		var sway := 0.0
		if not Motion.reduce:
			sc *= Motion.back_out(clampf(since / 0.4, 0.0, 1.0))
			sway = sin(_clock * 1.7 + float(bl.x)) * 0.08 + 0.5 * exp(-since * 5.0) * sin(since * 16.0)
		if sc <= 0.01:
			continue
		_cast_add(Art.flower(bl.look, _u), Transform2D(sway, Vector2(sc, sc), 0.0, px(Vector2(bl.x, TURF + float(bl.y)))), Color.WHITE)

## The streak's pill, top and middle: paper, the count in ink (lettered by
## `_draw_streak_words`) and under it the time the streak has left, running
## down.
func _streak_rect() -> Rect2:
	var w := 78.0 * _u
	var h := 17.0 * _u
	var k := _streak_in if Motion.reduce else Motion.back_out(_streak_in)
	return Rect2(Vector2((field.size.x - w) * 0.5, 7.0 * _u - (1.0 - k) * 30.0 * _u), Vector2(w, h))

func _draw_streak_pill(b: Face.Builder) -> void:
	if _streak_in <= 0.01:
		return
	var rect := _streak_rect()
	var r := rect.size.y * 0.5
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0, 1.8 * _u), rect.size, r), Color(0.3, 0.2, 0.08, 0.16))
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), Art.CREAM)
	var left := clampf(float(sim._streak_t) / Sim.STREAK_GAP, 0.0, 1.0) if sim.streak >= STREAK_FROM else 0.0
	var bar := Vector2(rect.size.x - r * 2.0, 2.0 * _u)
	var at := rect.position + Vector2(r, rect.size.y - 4.0 * _u)
	b.fan(Face.Builder.round_rect(at, bar, bar.y * 0.5), Color(Art.CREAM_DEEP, 0.7))
	if left > 0.03:
		b.fan(Face.Builder.round_rect(at, Vector2(bar.x * left, bar.y), bar.y * 0.5), HEAT.lerp(ALARM, _heat))

func _draw_streak_words(font: Font) -> void:
	if _streak_in <= 0.01 or _streak_n < STREAK_FROM:
		return
	var rect := _streak_rect()
	var text := tr("PP_STREAK") % _streak_n
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs).x
	var since := _clock - _streak_at
	var sc := 1.0 if Motion.reduce or since > 0.3 else 1.0 + 0.22 * exp(-since * 12.0)
	var c := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - 1.2 * _u)
	_over.draw_set_transform(_shake_off + c, 0.0, Vector2(sc, sc))
	_over.draw_string(font, Vector2(-w * 0.5, _text_fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs, Art.INK.lerp(ALARM.darkened(0.35), _heat))
	_over.draw_set_transform(_shake_off)

## The stars a cleared wave is stamped, under its bonus: three seats, and a
## gold star popping onto each one earned.
func _draw_stars(b: Face.Builder) -> void:
	if _clear.is_empty():
		return
	var since: float = _clock - float(_clear.at)
	# they leave by shrinking: gold thinned over the sky goes to mud
	var out := 1.0 - clampf((since - 1.25) / 0.25, 0.0, 1.0)
	out *= out
	var seat := out if Motion.reduce else clampf((since - 0.15) / 0.2, 0.0, 1.0) * out
	for k in 3:
		var c := _star_at(k)
		var t := since - 0.35 - STAR_STEP * k
		var earned: bool = k < int(_clear.stars) and t > 0.0
		if seat > 0.02 and not (earned and t > 0.3):
			Rewards.star(b, c, 11.5 * _u * seat, STAR_OFF)
		if earned and out > 0.02:
			var sc := 1.0 if Motion.reduce else Motion.back_out(minf(1.0, t / 0.3))
			var turn := 0.0 if Motion.reduce else 0.5 * exp(-t * 6.0) * cos(t * 14.0)
			Rewards.star(b, c, 14.0 * _u * sc * out, Art.GOLD, turn)

## The gifts flying to their place on the grass: up off the cart and round
## in an arc, shrinking to the size they sit at.
func _draw_flights() -> void:
	for f: Dictionary in _flights:
		var k := clampf(float(f.t) / FLIGHT_T, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var from: Vector2 = f.from
		var to := _home_of(f.kind)
		var bow := from.lerp(to, 0.35) + Vector2(0, -48.0 * _u)
		var at := from.lerp(bow, e).lerp(bow.lerp(to, e), e)
		var sc := lerpf(1.0, 0.62, e) * (1.0 + 0.25 * sin(e * PI))
		_cast_add(Art.token(f.kind, _u), Transform2D(0.0, Vector2(sc, sc), 0.0, at), Color.WHITE)
		if int(f.t * 60.0) % 3 == 0:
			_spark((at - _origin) / _u, (Art.GIFT[int(f.kind)] as Color).lerp(Color("fffaf0"), 0.4))
	_cast_draw()

## The numbers off a crate gone, lettered like stickers: popping big and
## settling, rising and drifting as they fade. One size of letter, swelled
## by the transform, so no glyph is cut twice.
func _draw_pops(font: Font) -> void:
	for p: Dictionary in _pops:
		var a := 1.0 - clampf((p.t - 0.45) / 0.35, 0.0, 1.0)
		var rise := 26.0 * _u * (1.0 - exp(-p.t * 4.5))
		var at := px(p.pos) + Vector2(p.drift * 10.0 * p.t, -rise)
		var fs := int((19.0 if p.big else 14.0) * _u)
		var sc := 1.0 if Motion.reduce else lerpf(0.4, 1.0, Motion.back_out(minf(1.0, p.t / 0.2)))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := Vector2(-w * 0.5, 0)
		_over.draw_set_transform(_shake_off + at, 0.0, Vector2(sc, sc))
		_over.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, int(fs * 0.3)), Color(p.rim, a))
		_over.draw_string(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.col, a))
	_over.draw_set_transform(_shake_off)

# --- the rewards ---

## A point of the garden, in field units, in the rewards layer's pixels.
func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(field, px(p) + _shake_off)

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

func _new_best_passed() -> void:
	_rw.sticker(tr("FF_NEW_BEST"), _rw.at(field, field.size * Vector2(0.5, 0.2)), 66, 1.8, true, Color.WHITE, true, "best")
	_rw.spray(_plate_at(_best_l), Pal.SUN, 14, 620.0, "star", 1.0)
	_rw.spray(_plate_at(_best_l), Art.GOLD, 10, 620.0, "coin", 1.0)
	_rw.ring(_plate_at(_best_l), 160.0, Color(Pal.SUN, 0.9))
	_rw.rain(1.6, ["confetti", "star"], STICKER_COLS)
	_fx.cue("word", 1.3, -3.0)
	_feel(Haptics.BUMP)
	# the pod is crowned, and the sun puts its party hat on
	_crown_at = _clock
	if _sun != null:
		if Motion.reduce:
			_sun.hat = 1.0
		else:
			_sun.create_tween().tween_property(_sun, "hat", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The garden flashes `col`, `amount` at most.
func _flash_now(col: Color, amount: float) -> void:
	if Motion.reduce:
		return
	_flash = maxf(_flash, amount)
	_flash_col = col

# --- the end ---

func _game_over() -> void:
	if _offer_chance():
		return
	var better := Record.add(GAME, sim.score, sim.wave, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.wave,
		"seconds": secs, "kills": sim.kills, "caught": sim.caught, "fired": sim.fired,
		"peas": sim.peas, "rate": sim.rate_lv, "power": sim.power, "best": better})
	Ads.note_finished()
	_show_banner(tr("FF_GAME_OVER"), "", 1.2)
	top_bar.refresh(self)
	get_tree().create_timer(1.6).timeout.connect(_show_end.bind(better))

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
	seat.custom_minimum_size = Vector2(0, 226)
	seat.clip_contents = true
	# The cart on a tuft of grass, still firing: peas going up out of the pod
	# in a row, a sunburst turning behind it once the card is up.
	var u := 3.4
	var shown_at := _clock
	var grown: Array = []
	for i in mini(_blooms.size(), 8):
		grown.append(int(_blooms[i].look))
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 178.0)
		var b := Face.Builder.new()
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.5) / 0.35, 0.0, 1.0)
		if glow > 0.0:
			var rc := c + Vector2(0, -70.0)
			var rr := 200.0 * Motion.back_out(glow)
			b.disc(rc, rr * 0.5, Color(Color("fff4c2"), 0.45))
			Rewards.sunrays(b, rc, rr * 0.2, rr, 14, t * 0.5, Color(Art.GOLD if better else Pal.SUN, 0.5))
			Rewards.sunrays(b, rc, rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
		b.ellipse(c + Vector2(0, 34.0), 150.0, 22.0, GRASS_DEEP)
		b.ellipse(c + Vector2(0, 30.0), 142.0, 17.0, GRASS)
		for k in 4:
			var up := fmod(t * 1.6 + k * 0.25, 1.0)
			Art.pea(b, c + Vector2(0, -44.0 * u - up * 120.0), 3.4 * u, 1.0 - up)
		var m := b.mesh()
		seat.set_meta("keep", m)
		seat.draw_mesh(m, null)
		var kick := 0.0 if Motion.reduce else maxf(0.0, 1.0 - fmod(t * 1.6, 0.25) / 0.09)
		var foot := c + Vector2(0, 21.0 - 9.0 * u + 9.0 * u)
		seat.draw_mesh(Art.barrel(u), null, Transform2D(0.0, Vector2(1.0 + 0.1 * kick, 1.0 - 0.14 * kick), 0.0, foot + Vector2(0, (-12.0 + 4.0 * kick) * u)))
		seat.draw_mesh(Art.cart(u), null, Transform2D(0.0, foot))
		for side in [-1.0, 1.0]:
			seat.draw_mesh(Art.wheel(u), null, Transform2D(sin(t * 1.3) * 0.4, foot + Vector2(side * 13.0 * u, 0)))
		if better:
			seat.draw_mesh(Art.crown(u), null, Transform2D(-0.3, foot + Vector2(-6.5 * u, (-42.5 + 4.0 * kick) * u)))
		# the flowers the run grew, in a row either side of the cart
		for i in grown.size():
			var side := -1.0 if i % 2 == 0 else 1.0
			var at := c + Vector2(side * (92.0 + 19.0 * (i / 2)), 30.0 + 3.0 * (i % 3))
			seat.draw_mesh(Art.flower(grown[i], 2.6), null, Transform2D(sin(t * 1.7 + i) * 0.08, at)))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "PP_END_CARD"
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
	for pair in [[str(sim.wave), "PP_STAT_WAVE"], [Record.grouped(sim.kills), "PP_STAT_CRATES"], [str(sim.caught), "PP_STAT_GIFTS"]]:
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

## The end card's score runs up from nothing to what the run made, with a
## burst of coins when it gets there.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 1.1, 0.0, 1.0)
	var shown := int(sim.score * (1.0 - pow(1.0 - k, 3.0)))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
		if int(_clock * 20.0) % 2 == 0:
			_quiet.cue("hit", 0.9 + 0.8 * k, -8.0)
	if k >= 1.0:
		_end_score.pivot_offset = _end_score.size * 0.5
		Motion.bump(_end_score, 0.25, 0.4)
		var at := _rw.at(_end_score, _end_score.size * 0.5)
		_rw.spray(at, Pal.SUN, 12, 620.0, "star", 1.1)
		_rw.spray(at, Art.GOLD, 12, 620.0, "coin", 1.1)
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
	if not better:
		return
	_rw.rain(3.5, ["confetti", "coin", "star"], STICKER_COLS)
	var fx := Fx2D.new()
	_end.add_child(fx)
	var cols := [Art.GOLD, Art.POD, Art.GIFT[Sim.Kind.PEA], Pal.FLOWER, Pal.SUN_RAY, Art.GIFT[Sim.Kind.RATE]]
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
	_ask()

func _on_back() -> void:
	if sim != null and not sim.is_over() and sim.score > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.wave})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
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
	card.declined.connect(_game_over)
	add_child(card)
	return true
