extends Control

## A match of air hockey: the fourth game on the Versus tab, laid as the daily
## boards: the wooden floor over the whole screen, on the rows' 40 margin the
## flat top bar and its tools row, with the score on a pill where the row's
## gap is, and under them the table as large as it goes.
##
## Play: put a finger on the table and the gold mallet goes with it, a little
## ahead of the thumb. Knock the puck into the slot in the far rail; first to
## seven. Whoever was scored on gets the puck back in their own half.
##
## **The power table** (versus/hockey_sim.gd): tokens lie on the table and the
## puck run through one gives it to whoever struck last, a second puck, a big
## mallet, a goal stood open, the other arm mired, a golden puck worth two.
##
## The other mallet is the computer's at three levels (versus/hockey_ai.gd:
## how fast its arm is, how late it sees, how far off its aim) -- or, on the
## fourth chip, **another person on the same phone** (level Record.LOCAL):
## the table takes two fingers, one a half, and nothing is recorded, since
## both players are the player. There is no game online: the live transport
## is a turn's (versus/online/match.gd: a move, then the other seat's, a
## minute each), and this game has no turns.
##
## The physics and the score are versus/hockey_sim.gd, the drawing and the
## fingers versus/hockey_table.gd.

signal closed

const Sim = preload("res://versus/hockey_sim.gd")
const AI = preload("res://versus/hockey_ai.gd")
const Table = preload("res://versus/hockey_table.gd")
const Record = preload("res://versus/versus_record.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Rewards = preload("res://arcade/rewards.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")

const GAME := "hockey"
const TITLE := "Air Hockey"
const MARGIN := 40
const GAP := 20
const PILL_R := 30
const CLEAR_CARD := 780
const QUIPS := 3
## How the moon's words come, one time in this many tries, and how far apart
## stickers of the small kind stand, seconds.
const QUIP_ODDS := 0.6
const STICKER_GAP := 1.6
## A goal this fast is a rocket, m/s. Rally stickers from this many crossings,
## then every this many.
const ROCKET := 3.7
const RALLY_FROM := 6
const RALLY_EVERY := 4
## A comeback is a level score from this many behind.
const COMEBACK := 3
## With a match on it, the last of the puck's run to a mouth plays at this
## speed: everybody gets to watch it.
const SLOW_MO := 0.4
const SLOW_MO_NEAR := 0.28
## Seconds: the beat between a goal and the puck coming back, and how long a
## line stays up.
const AFTER_GOAL := 1.25
const TOAST_HOLD := 1.7
## How long the table keeps the match's last goal to itself before the end
## card comes up over it: the light down the rails (Table.LAP) and the
## winner's hops. Nothing under reduce motion.
const WIN_HOLD := 1.1
## The level names by level; Record.LOCAL is two players on this phone.
const LEVELS := {0: "DIFF_EASY", 1: "DIFF_MEDIUM", 2: "DIFF_HARD", Record.LOCAL: "VS_TWO"}
## A hit this hard (m/s closing) is as loud as a hit gets.
const FULL_HIT := 6.0

enum State { PLAY, GOAL, OVER }

var level := 1
var sim: RefCounted
var bot: RefCounted
var table: Control
var top_bar: Control
var settings_sheet: Control
## The tutorial card: the top bar's ?, the settings' How to play and the
## first play (ui/hud/screen_tutor.gd).
var tutor: RefCounted
## The card is up: the puck and both mallets wait under it.
var _held := false
var _state := State.PLAY
var _acc := 0.0
var _rng := RandomNumberGenerator.new()
## Who serves the match's first puck; it swaps every match.
var _first := 0
## How many times each mallet has struck the puck this match.
var _hits := [0, 0]
var _pause := 0.0
var _serve_to := 0
var _fx: Node2D
## What the phone knocks for (docs/agents/haptics.md). The table's own cues
## (`strike`, `wall`, `post`) ring for both mallets and are not mapped; the
## hand's own hit knocks through `_fx.buzz`.
const HAPTICS := {"goal": Haptics.GOOD, "conceded": Haptics.WARN, "win": Haptics.WIN, "lose": Haptics.LOSE}
## The puck's whisper on its cushion of air: one looping voice whose level
## follows how fast it is going.
var _glide: AudioStreamPlayer
## The glide's level at full speed, linear. The user, 2026-10-10: "waaaay
## more subtle, since it's a sound user will heard all the time" -- it was
## 0.7 of a file at -14, and is this of one at -22, 13 dB down in all.
const GLIDE_TOP := 0.45
var _world: Control
var _world_mesh: ArrayMesh
var _rw: Rewards
var _margins: MarginContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween
var _end: Control
var _end_tw: Tween
# --- the scoreboard ---
var _scores: Array[Label] = []
var _faces: Array = []
var _clock_label: Label
var _pips: Control
var _clock_shown := -1
## The pip a goal just filled (its seat and which) and the seconds since: it
## takes Motion's bump as the score beside it does.
var _pip_seat := -1
var _pip_at := 0
var _pip_t := 99.0
var _clear_card: Control
## This match's goals in a row by the same side and who scored them, the worst
## each side has been behind, the longest rally, the saves.
var _in_row := 0
var _row_by := -1
var _worst := [0, 0]
var _best_rally := 0
var _saves := [0, 0]
var _sticker_at := -10.0

func _init(the_level := 1) -> void:
	level = the_level if LEVELS.has(the_level) else 1

func puzzle_id() -> String:
	return GAME

func two_players() -> bool:
	return level == Record.LOCAL

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_rng.randomize()
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), TITLE, _hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	_first = 0
	_new_match()
	top_bar.enter(0.0)
	Analytics.track("versus_start", {"game": GAME, "level": level})

## The tutorial, a page a lesson, each played by the table itself
## (ui/hud/hockey_tutorial_diagram.gd). The same on every level.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/hockey_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.LEAD, "TUT_HOCKEY_LEAD", tr("TUT_HOCKEY_LEAD_BODY")],
		[Diagram.Lesson.SCORE, "TUT_HOCKEY_SCORE", tr("TUT_HOCKEY_SCORE_BODY") % Sim.TARGET],
		[Diagram.Lesson.BLOCK, "TUT_HOCKEY_BLOCK", tr("TUT_HOCKEY_BLOCK_BODY")],
		[Diagram.Lesson.BANK, "TUT_HOCKEY_BANK", tr("TUT_HOCKEY_BANK_BODY")],
		[Diagram.Lesson.POWERS, "TUT_HOCKEY_POWERS", tr("TUT_HOCKEY_POWERS_BODY")],
		[Diagram.Lesson.TWO, "TUT_HOCKEY_TWO", tr("TUT_HOCKEY_TWO_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The card going up (true) or leaving: see `_held`.
func _hold(on: bool) -> void:
	_held = on
	if on:
		table.let_go()

# --- building ---

func _build() -> void:
	_world = Control.new()
	_world.name = "World"
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.draw.connect(func() -> void:
		if _world_mesh != null:
			_world.draw_mesh(_world_mesh, null))
	_world.resized.connect(_paint_world)
	add_child(_world)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new(TITLE, tr("HKY_MOTTO"), true, false, true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_ask_clear)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	top_bar.tint_motto(Color("4a2f12"))
	col.add_child(_build_tools())

	table = Table.new()
	table.name = "Table"
	table.hands = [true, two_players()]
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.saved.connect(_on_saved)
	table.touched.connect(func(_seat: int) -> void:
		_hush()
		_fx.touch())
	col.add_child(table)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	table.add_child(_fx)
	_rw = Rewards.new()
	add_child(_rw)
	_glide = AudioStreamPlayer.new()
	_glide.volume_db = -80.0
	var glide_path := "res://assets/sfx/hockey/glide.ogg"
	if ResourceLoader.exists(glide_path):
		var stream: AudioStreamOggVorbis = (load(glide_path) as AudioStreamOggVorbis).duplicate()
		stream.loop = true
		_glide.stream = stream
	add_child(_glide)

	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 30, 14))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast_label = Label.new()
	_toast_label.theme_type_variation = "SheetBody"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_toast.add_child(_toast_label)
	add_child(_toast)
	_apply_insets()

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))

## The floor: planks over the whole screen. One mesh, built once a layout.
func _paint_world() -> void:
	if _world == null or _world.size.x <= 0.0:
		return
	var b := Face.Builder.new()
	Scenery.planks(b, _world.size, 9)
	_world_mesh = b.mesh()
	_world.queue_redraw()

## The bar's tools row with the score on a paper pill where its gap is: Undo
## and the bulb greyed (a live game has neither), the bin, the pill. Each
## side's face and goals, the pips of the race between them, and the clock.
func _build_tools() -> Control:
	var row: HBoxContainer = top_bar.tools
	var pill := PanelContainer.new()
	pill.name = "Score"
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.custom_minimum_size.y = FlatTopBar.BUTTON.y
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, PILL_R, 10))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 8)
	pill.add_child(line)
	for p in 2:
		var seat := Control.new()
		seat.custom_minimum_size = Vector2(72, 72)
		seat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var face: Control = SunFace.new() if p == 0 else MoonFace.new()
		face.size = Vector2(72, 72)
		seat.add_child(face)
		_faces.append(face)
		var score := Label.new()
		score.text = "0"
		score.theme_type_variation = "SheetTitle"
		score.custom_minimum_size.x = 44
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_scores.append(score)
		if p == 0:
			line.add_child(seat)
			line.add_child(score)
			line.add_child(_build_middle())
		else:
			line.add_child(score)
			line.add_child(seat)
	for child in row.get_children():
		if child is Control and not (child is Button):
			child.visible = false
	row.add_child(pill)
	row.move_child(pill, top_bar.hint_button.get_index())
	return row

## Between the two: each side's goals as pips, and how long it has run.
func _build_middle() -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", -4)
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(150, 44)
	_pips.draw.connect(_draw_pips)
	col.add_child(_pips)
	_clock_label = Label.new()
	_clock_label.theme_type_variation = "MenuKicker"
	_clock_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_clock_label)
	return col

## Two rows of seven: a filled dot a goal, gold on top for the bottom mallet's
## and blue under it for the top one's, so the race is read at a glance.
func _draw_pips() -> void:
	if sim == null:
		return
	var n := Sim.TARGET
	var r := 6.0
	var step := minf(24.0, (_pips.size.x - 2.0 * r) / float(n - 1))
	var x0 := (_pips.size.x - step * (n - 1)) * 0.5
	for p in 2:
		var y := _pips.size.y * (0.28 if p == 0 else 0.74)
		var tint: Color = Table.SIDE[p][0]
		for i in n:
			var c := Vector2(x0 + step * i, y)
			if i < int(sim.scores[p]):
				var pop := Motion.bump_scale(_pip_t, Motion.BUMP * 2.0) if p == _pip_seat and i == _pip_at else 1.0
				_pips.draw_circle(c, r * pop, tint, true, -1.0, true)
			else:
				_pips.draw_circle(c, r - 1.5, Color(Pal.LINE, 0.55), false, 2.0, true)

func _name_key(p: int) -> String:
	if two_players():
		return "HKY_SUN" if p == 0 else "HKY_MOON"
	return "SNK_YOU" if p == 0 else "SNK_BOT"

func _refresh_board() -> void:
	for p in 2:
		_scores[p].text = str(sim.scores[p])
	_pips.queue_redraw()
	top_bar.refresh(self)

# --- the top bar's view of this screen (FlatTopBar.refresh) ---

func capabilities() -> Array:
	return []

func is_done() -> bool:
	return sim != null and sim.over

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

func hints_left() -> int:
	return 0

func can_reset() -> bool:
	return true

## The bin asks, as on a daily board, unless nobody has touched the puck yet.
func _ask_clear() -> void:
	if _clear_card != null:
		return
	if _hits[0] + _hits[1] == 0 or sim.over:
		_on_reset()
		return
	table.let_go()
	var scrim := Dialog.scrim()
	scrim.name = "ClearCard"
	_clear_card = scrim
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			_close_clear())
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(CLEAR_CARD)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	col.add_child(Dialog.head("HKY_CLEAR_TITLE", "bin"))
	var body := Label.new()
	body.text = "HKY_CLEAR_BODY"
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var keep := Dialog.primary("check", tr("CLEAR_NO"))
	keep.name = "Keep"
	keep.pressed.connect(_close_clear)
	var yes := Dialog.secondary("bin", tr("HKY_CLEAR_YES"))
	yes.name = "Clear"
	yes.pressed.connect(func() -> void:
		_close_clear()
		_on_reset())
	Dialog.buttons(col, keep, yes)
	add_child(scrim)
	Motion.appear(scrim, 0.0, 1.0, 0.2)

func _close_clear() -> void:
	if _clear_card != null:
		_clear_card.queue_free()
		_clear_card = null

# --- the match ---

func _new_match() -> void:
	Motion.stop(_end_tw)
	_end_tw = null
	_pip_seat = -1
	if _end != null:
		_end.queue_free()
		_end = null
	_close_clear()
	sim = Sim.new()
	sim.powers = true
	sim.rng.randomize()
	sim.reset(_first)
	_in_row = 0
	_row_by = -1
	_worst = [0, 0]
	_best_rally = 0
	_saves = [0, 0]
	_rw.clear()
	table.sim = sim
	table.let_go()
	bot = null if two_players() else AI.new(1, level, _rng.randi() | 1)
	_hits = [0, 0]
	_acc = 0.0
	_clock_shown = -1
	_state = State.PLAY
	table.interactive = true
	for p in 2:
		_faces[p].expression = Face.Expr.HAPPY
	_refresh_board()
	_tick_clock()
	_served(_first)

## The puck is down in `to`'s half.
func _served(to: int) -> void:
	if bot != null:
		bot.served()
	_fx.cue("serve")
	if two_players():
		_say(tr("HKY_SERVE_SUN" if to == 0 else "HKY_SERVE_MOON"))
	else:
		_say(tr("HKY_SERVE_YOU" if to == 0 else "HKY_SERVE_BOT"))

func _process(delta: float) -> void:
	# Nothing moves under the tutorial's card or the settings: the computer
	# would score into an empty goal.
	var waiting: bool = _held or settings_sheet.is_open() or _clear_card != null
	_rw.step(delta)
	if not waiting and _state != State.OVER:
		_acc += minf(delta, 0.05) * _pace()
		while _acc >= Sim.DT:
			_acc -= Sim.DT
			if bot != null:
				bot.drive(sim, Sim.DT)
			sim.step()
		_play_events()
		if _state == State.GOAL:
			_pause -= delta
			if _pause <= 0.0:
				_state = State.PLAY
				for p in 2:
					_faces[p].expression = Face.Expr.HAPPY
				sim.serve(_serve_to)
				_served(_serve_to)
		_tick_clock()
	if _pip_t < Motion.BUMP_TIME:
		_pip_t += delta
		_pips.queue_redraw()
	_glide_sound(delta, waiting)

## A puck about to go in with the match on it plays slowly.
func _pace() -> float:
	if Motion.reduce or not sim.puck_on or sim.scores.max() < Sim.TARGET - 1:
		return 1.0
	var end: int = 0 if sim.puck_vel.y > 0.0 else 1
	var rail: float = Sim.L if end == 0 else 0.0
	var close: bool = absf(sim.puck.y - rail) < SLOW_MO_NEAR and absf(sim.puck.x - Sim.W * 0.5) < sim.goal_half(end)
	return SLOW_MO if close and sim.puck_vel.length() > 1.0 else 1.0

func _tick_clock() -> void:
	var s := int(sim.clock)
	if s == _clock_shown:
		return
	_clock_shown = s
	_clock_label.text = "%d:%02d" % [s / 60, s % 60]

## Loud as the contact was hard: a nudge is a tick, a full swing a crack.
## The floor is 0.4 since the ticks went low and quiet (2026-10-10): at 0.14
## a nudge played under what a phone's speaker gives back.
func _hit_db(speed: float) -> float:
	return linear_to_db(clampf(0.4 + 0.6 * speed / FULL_HIT, 0.4, 1.0))

func _play_events() -> void:
	for e in sim.events:
		match String(e.kind):
			"mallet":
				var who := int(e.who)
				var speed := float(e.speed)
				_hits[who] += 1
				_on_rally(int(e.rally))
				if speed > 0.12:
					_fx.cue("strike", clampf(0.86 + speed * 0.042, 0.86, 1.148), _hit_db(speed))
					table.flash("mallet", e.at, speed / FULL_HIT, who)
					if table.hands[who]:
						_fx.buzz(Haptics.TAP if speed > 2.2 else Haptics.TICK)
			"wall":
				if float(e.speed) > 0.2:
					_fx.cue("wall", clampf(0.92 + float(e.speed) * 0.04, 0.92, 1.14), _hit_db(float(e.speed)))
					table.flash("wall", e.at, float(e.speed) / FULL_HIT)
			"post":
				_fx.cue("post", clampf(0.95 + float(e.speed) * 0.03, 0.95, 1.12), _hit_db(float(e.speed)))
				table.flash("post", e.at, float(e.speed) / FULL_HIT)
			"power":
				_on_power(e)
			"goal":
				_on_goal(e)
	sim.events.clear()

func _on_rally(n: int) -> void:
	_best_rally = maxi(_best_rally, n)
	if n >= RALLY_FROM and (n - RALLY_FROM) % RALLY_EVERY == 0 and not _rw.has_sticker("rally"):
		_small(tr("HKY_RALLY") % n, "rally", Color("fff4c2"))

## A small sticker over the middle of the table, never two on top of each other.
func _small(text: String, id: String, col: Color) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _sticker_at < STICKER_GAP:
		return
	_sticker_at = now
	_rw.sticker(text, _rw.at(table, table.frame_rect().get_center()), 62, 0.8, false, col, false, id)

## The moon says something, against the computer only.
func _quip(kind: String) -> void:
	if not two_players() and randf() < QUIP_ODDS:
		_say(tr("HKY_Q_%s_%d" % [kind, 1 + randi() % QUIPS]))

func _on_saved(seat: int) -> void:
	_saves[seat] += 1
	_small(tr("HKY_SAVE"), "save", Color("cfeefa"))
	if seat == 0:
		_faces[1].expression = Face.Expr.WORRIED
		_quip("SAVED")

const POWER_WORDS := {Sim.TWIN: "HKY_P_TWIN", Sim.BIG: "HKY_P_BIG", Sim.WIDE: "HKY_P_WIDE", Sim.SLOW: "HKY_P_SLOW", Sim.GOLD: "HKY_P_GOLD"}

## A token taken: its name where it lay, and a ring of the taker's colour.
func _on_power(e: Dictionary) -> void:
	var who := int(e.who)
	var p: Vector2 = _rw.at(table, table.px(e.at))
	_rw.ring(p, 150.0, Table.SIDE[who][0])
	_rw.spray(p, Table.SIDE[who][1], 12, 620.0, "star", 1.0)
	_sticker_at = Time.get_ticks_msec() / 1000.0
	_rw.sticker(tr(POWER_WORDS[int(e.power)]), _rw.at(table, table.frame_rect().get_center()), 70, 1.0, false, Color("fff4c2"), false, "power")
	_fx.cue("token")
	if table.hands[who]:
		_fx.buzz(Haptics.GOOD)
	if who == 1 and not two_players():
		_quip("POWER")

## What a goal was: the loudest thing about it, and how loud.
func _goal_word(by: int, e: Dictionary) -> Array:
	var worth := int(e.worth)
	if bool(e.own):
		return [tr("HKY_OWN"), 84, false]
	if _in_row == 3:
		return [tr("HKY_HAT"), 104, true]
	if int(sim.scores[by]) == int(sim.scores[1 - by]) and int(_worst[by]) >= COMEBACK:
		return [tr("HKY_COMEBACK"), 104, true]
	if worth > 1:
		return [tr("HKY_DOUBLE"), 100, true]
	if int(e.banks) >= 2:
		return [tr("HKY_BANK_2"), 96, true]
	if int(e.banks) == 1:
		return [tr("HKY_BANK"), 88, false]
	if float(e.speed) >= ROCKET:
		return [tr("HKY_ROCKET"), 92, false]
	return [tr("HKY_GOAL"), 80, false]

func _on_goal(e: Dictionary) -> void:
	var by := int(e.by)
	var at: Vector2 = e.at
	table.goal(1 - by, at)
	_in_row = _in_row + 1 if _row_by == by else 1
	_row_by = by
	for p in 2:
		_worst[p] = maxi(int(_worst[p]), int(sim.scores[1 - p]) - int(sim.scores[p]))
	_pip_seat = by
	_pip_at = mini(int(sim.scores[by]), Sim.TARGET) - 1
	_pip_t = 0.0
	_refresh_board()
	_scores[by].pivot_offset = _scores[by].size * 0.5
	Motion.bump(_scores[by])
	_faces[by].expression = Face.Expr.JOY
	_faces[1 - by].expression = Face.Expr.WORRIED
	var word: Array = _goal_word(by, e)
	table.quake(14.0 if word[2] else 8.0)
	var mid: Vector2 = _rw.at(table, table.frame_rect().get_center())
	_sticker_at = Time.get_ticks_msec() / 1000.0
	_rw.sticker(word[0], mid, word[1], 1.15, true, Color.WHITE, word[2], "goal")
	_rw.spray(_rw.at(table, table.px(at)), Table.SIDE[by][1], 18, 820.0, "star", 1.0, 0.0, _rw.at(_scores[by], _scores[by].size * 0.5))
	# The mouth's light, the motes and the mallets' part are the table's.
	if sim.over:
		_finish()
		return
	# With two at the table every goal is somebody's: the bright cue for both.
	_fx.cue("goal" if by == 0 or two_players() else "conceded")
	if bool(e.more):
		# A puck is still on the table: nobody stops.
		return
	_state = State.GOAL
	_pause = AFTER_GOAL
	_serve_to = 1 - by
	if int(sim.scores[by]) >= Sim.TARGET - 1:
		_say(tr("HKY_MATCH_POINT"))
	elif bool(e.own):
		_quip("OWN_ME" if by == 1 else "OWN_MOON")
	else:
		_quip("CONCEDED" if by == 0 else "SCORED")

func _glide_sound(delta: float, waiting: bool) -> void:
	if _glide == null or _glide.stream == null:
		return
	var run := 0.0
	if _state == State.PLAY and not waiting and sim.puck_on:
		run = sim.puck_vel.length()
	# Heard from a drift, full by about three metres a second. Full is
	# GLIDE_TOP: the puck never stops, so this is under everything else.
	var speed := clampf(run / 3.0, 0.0, 1.0)
	var want := speed * GLIDE_TOP
	var now := db_to_linear(_glide.volume_db)
	now = move_toward(now, want, delta * (5.0 if want > now else 2.5) * GLIDE_TOP)
	_glide.volume_db = linear_to_db(maxf(now, 0.0001))
	_glide.pitch_scale = lerpf(0.94, 1.04, speed)
	if now > 0.002 and not _glide.playing:
		_glide.play()
	elif now <= 0.002 and _glide.playing:
		_glide.stop()

# --- the end ---

func _finish() -> void:
	_state = State.OVER
	table.interactive = false
	table.let_go()
	var won: bool = sim.winner == 0
	if two_players():
		Analytics.track("versus_end", {"game": GAME, "level": level, "won": won,
			"score_you": sim.scores[0], "score_bot": sim.scores[1], "shots": _hits[0] + _hits[1],
			"seconds": int(sim.clock)})
	else:
		Record.add(GAME, level, won)
		var streak: int = int(Record.option(GAME, "streak", 0)) + 1 if won else 0
		Record.set_option(GAME, "streak", streak)
		if streak > int(Record.option(GAME, "best_streak", 0)):
			Record.set_option(GAME, "best_streak", streak)
		Analytics.track("versus_end", {"game": GAME, "level": level, "won": won,
			"score_you": sim.scores[0], "score_bot": sim.scores[1], "shots": _hits[0],
			"seconds": int(sim.clock)})
	Ads.note_finished()
	_fx.cue("win" if won or two_players() else "lose")
	# The table has the last goal to itself first; the tween is the screen's,
	# so a match started over in the meantime takes the card with it.
	if Motion.reduce:
		_show_end(won)
		return
	_end_tw = create_tween()
	_end_tw.tween_interval(WIN_HOLD)
	_end_tw.tween_callback(_show_end.bind(won))

func _show_end(won: bool) -> void:
	_end = _build_end(won)
	add_child(_end)
	Motion.appear(_end, 0.0, 1.0, 0.3)
	_celebrate(won or two_players())

func _build_end(won: bool) -> Control:
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
	seat.custom_minimum_size = Vector2(0, 170)
	var face: Control = SunFace.new() if won else MoonFace.new()
	face.size = Vector2(170, 170)
	face.position = Vector2(820 * 0.5 - 40 - 85, 0)
	face.expression = Face.Expr.JOY
	seat.add_child(face)
	col.add_child(seat)
	var head := Label.new()
	if two_players():
		head.text = "HKY_WIN_SUN" if won else "HKY_WIN_MOON"
	else:
		head.text = "HKY_WIN" if won else "HKY_LOSE"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var score := Label.new()
	score.text = "%s %d  –  %d %s" % [tr(_name_key(0)), sim.scores[0], sim.scores[1], tr(_name_key(1))]
	score.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	score.theme_type_variation = "SheetTitle"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score)
	var line := Label.new()
	var bits: Array = [_clock_label.text, tr(LEVELS[level])]
	if not two_players():
		bits.append(Record.record_line(GAME, level))
		var streak := int(Record.option(GAME, "streak", 0))
		if streak >= 2:
			bits.append(tr("HKY_STREAK") % streak)
	line.text = "  ·  ".join(bits) + "\n" + tr("HKY_END_STATS") % [_best_rally, _saves[0]]
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var again := Dialog.primary("reset", tr("SNK_AGAIN"))
	again.pressed.connect(func() -> void:
		_first = 1 - _first
		_fx.buzz(Haptics.TAP)
		_new_match())
	var back := Dialog.secondary("chevron_left", tr("SNK_BACK"))
	back.pressed.connect(_on_back)
	Dialog.buttons(col, again, back)
	return scrim

## The card drops in with a little overshoot; a won match throws the two
## sides' colours up round it, a lost one only settles.
func _celebrate(bright: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not bright:
		return
	var fx := Fx2D.new()
	_end.add_child(fx)
	var cols := [Table.SIDE[0][0], Table.SIDE[0][1], Table.SIDE[1][0], Table.SIDE[1][1], Pal.SUN_RAY, Pal.ACCENT]
	var mid := size * 0.5
	# On the puffs' own tween, so a card closed early takes the rest with it.
	var tw := fx.create_tween()
	tw.tween_interval(0.25)
	for k in 8:
		var at := mid + Vector2.from_angle(TAU * k / 8.0 - PI * 0.5) * Vector2(400.0, 330.0)
		tw.tween_callback(fx.puff.bind(at, cols[k % cols.size()], 12))
		tw.tween_interval(0.14)

# --- chrome ---

func _say(text: String) -> void:
	_toast_label.text = text
	_place_toast.call_deferred()
	Motion.stop(_toast_tw)
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tw.tween_interval(TOAST_HOLD)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.3)

## A line already read gives way to the player's hand.
func _hush() -> void:
	if _toast.modulate.a <= 0.0 or _state != State.PLAY:
		return
	Motion.stop(_toast_tw)
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.2)

## Over the middle of the table, where neither mallet reaches.
func _place_toast() -> void:
	_toast.reset_size()
	var at: Rect2 = table.get_global_rect()
	var frame: Rect2 = table.frame_rect()
	var box := _toast.get_combined_minimum_size()
	_toast.global_position = at.position + frame.get_center() - box * 0.5

func _on_reset() -> void:
	if not can_reset():
		return
	Analytics.track("board_reset", {"puzzle_id": GAME})
	_fx.buzz(Haptics.TAP)
	_new_match()

func _on_back() -> void:
	if _clear_card != null:
		_close_clear()
		return
	if sim != null and not sim.over and _hits[0] + _hits[1] > 0:
		Analytics.track("versus_abandon", {"game": GAME, "level": level, "shots": _hits[0],
			"score_you": sim.scores[0], "score_bot": sim.scores[1]})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if _clear_card != null:
		_close_clear()
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
