extends Control

## A match of air hockey: the fourth game on the Versus tab. The flat boards'
## top bar (back, the title in ink with its sprout, reset, the ? and
## settings), a scoreboard with the sun for the bottom mallet and the moon
## for the top one, and under them the table on its wooden deck.
##
## Play: put a finger on the table and the gold mallet goes with it, a little
## ahead of the thumb. Knock the puck into the slot in the far rail; first to
## seven. Whoever was scored on gets the puck back in their own half.
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
const Vistas = preload("res://ui/menu/vistas.gd")
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
const SCORE_H := 128.0
const DECK_PAD := 18
const BACKDROP_BLEED := 90.0
## Seconds: the beat between a goal and the puck coming back, and how long a
## line stays up.
const AFTER_GOAL := 1.25
const TOAST_HOLD := 1.7
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
var _backdrop: ColorRect
var _margins: MarginContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween
var _end: Control
# --- the scoreboard ---
var _plates: Array = []
var _scores: Array[Label] = []
var _names: Array[Label] = []
var _faces: Array = []
var _clock_label: Label
var _pips: Control
var _clock_shown := -1

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
	var page := ColorRect.new()
	page.color = Pal.PAPER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_backdrop = Vistas.board_plate(GAME, Pal.ACCENT)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_backdrop)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new(TITLE, tr("HKY_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)

	col.add_child(_build_scoreboard())

	var deck := Control.new()
	deck.name = "Deck"
	deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.draw.connect(_draw_deck.bind(deck))
	deck.resized.connect(deck.queue_redraw)
	col.add_child(deck)
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, DECK_PAD)
	deck.add_child(inset)

	table = Table.new()
	table.name = "Table"
	table.hands = [true, two_players()]
	table.touched.connect(func(_seat: int) -> void: _hush())
	inset.add_child(table)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	table.add_child(_fx)
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
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + SCORE_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## A wooden terrace under the table: planks across, each a shade apart.
func _draw_deck(deck: Control) -> void:
	var rect := Rect2(Vector2.ZERO, deck.size)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(36)
	box.bg_color = Color("a8744c")
	deck.draw_style_box(box, rect)
	var plank := 58.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var y := 0.0
	while y < rect.size.y:
		var h := minf(plank, rect.size.y - y)
		var shade := Color("b98457").lerp(Color("a06d45"), rng.randf())
		var r := Rect2(Vector2(0.0, y), Vector2(rect.size.x, h))
		box.bg_color = shade
		box.set_corner_radius_all(0)
		if y == 0.0:
			box.corner_radius_top_left = 36
			box.corner_radius_top_right = 36
		if y + h >= rect.size.y:
			box.corner_radius_bottom_left = 36
			box.corner_radius_bottom_right = 36
		deck.draw_style_box(box, r.grow_side(SIDE_BOTTOM, -3.0))
		var joint := rng.randf_range(0.2, 0.8) * rect.size.x
		deck.draw_line(Vector2(joint, y + 4.0), Vector2(joint, y + h - 6.0), Color(0.3, 0.17, 0.08, 0.35), 3.0)
		y += plank
	for k in 3:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(36)
		s.bg_color = Color.TRANSPARENT
		s.set_border_width_all(10 + k * 10)
		s.border_color = Color(0.25, 0.12, 0.05, 0.07)
		deck.draw_style_box(s, rect)

## Seat 0, the bottom mallet, is the left plate and seat 1 the right one.
func _build_scoreboard() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = SCORE_H
	row.add_theme_constant_override("separation", 16)
	for p in 2:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 30, 10))
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 12)
		inner.alignment = BoxContainer.ALIGNMENT_BEGIN if p == 0 else BoxContainer.ALIGNMENT_END
		plate.add_child(inner)
		var seat := Control.new()
		seat.custom_minimum_size = Vector2(88, 88)
		seat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var face: Control = SunFace.new() if p == 0 else MoonFace.new()
		face.size = Vector2(88, 88)
		seat.add_child(face)
		_faces.append(face)
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", -8)
		var name_l := Label.new()
		name_l.text = _name_key(p)
		name_l.theme_type_variation = "CardBlurb"
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if p == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var score := Label.new()
		score.text = "0"
		score.theme_type_variation = "DayBig"
		score.horizontal_alignment = name_l.horizontal_alignment
		words.add_child(name_l)
		words.add_child(score)
		_names.append(name_l)
		_scores.append(score)
		if p == 0:
			inner.add_child(seat)
			inner.add_child(words)
		else:
			inner.add_child(words)
			inner.add_child(seat)
		_plates.append(plate)
		if p == 1:
			row.add_child(_build_middle())
		row.add_child(plate)
	return row

## Between the plates: what the match is to, each side's goals as pips, and
## how long it has run.
func _build_middle() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 30, 10))
	panel.custom_minimum_size.x = 250
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var kicker := Label.new()
	kicker.text = tr("HKY_FIRST_TO") % Sim.TARGET
	kicker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	kicker.theme_type_variation = "MenuKicker"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(220, 40)
	_pips.draw.connect(_draw_pips)
	col.add_child(_pips)
	_clock_label = Label.new()
	_clock_label.theme_type_variation = "CardBlurb"
	_clock_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_clock_label)
	return panel

## Two rows of seven: a filled dot a goal, gold on top for the bottom mallet's
## and blue under it for the top one's, so the race is read at a glance.
func _draw_pips() -> void:
	if sim == null:
		return
	var n := Sim.TARGET
	var r := 7.0
	var step := minf(26.0, (_pips.size.x - 2.0 * r) / float(n - 1))
	var x0 := (_pips.size.x - step * (n - 1)) * 0.5
	for p in 2:
		var y := _pips.size.y * (0.28 if p == 0 else 0.74)
		var tint: Color = Table.SIDE[p][0]
		for i in n:
			var c := Vector2(x0 + step * i, y)
			if i < int(sim.scores[p]):
				_pips.draw_circle(c, r, tint, true, -1.0, true)
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

# --- the match ---

func _new_match() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	sim = Sim.new()
	sim.reset(_first)
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
	var waiting: bool = _held or settings_sheet.is_open()
	if not waiting and _state != State.OVER:
		_acc += minf(delta, 0.05)
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
	_glide_sound(delta, waiting)

func _tick_clock() -> void:
	var s := int(sim.clock)
	if s == _clock_shown:
		return
	_clock_shown = s
	_clock_label.text = "%d:%02d" % [s / 60, s % 60]

## Loud as the contact was hard: a nudge is a tick, a full swing a crack.
func _hit_db(speed: float) -> float:
	return linear_to_db(clampf(0.14 + 0.86 * speed / FULL_HIT, 0.14, 1.0))

func _play_events() -> void:
	for e in sim.events:
		match String(e.kind):
			"mallet":
				var who := int(e.who)
				var speed := float(e.speed)
				_hits[who] += 1
				if speed > 0.12:
					_fx.cue("strike", clampf(0.86 + speed * 0.05, 0.86, 1.2), _hit_db(speed))
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
			"goal":
				_on_goal(int(e.by), e.at)
	sim.events.clear()

func _on_goal(by: int, at: Vector2) -> void:
	table.goal(1 - by, at)
	_refresh_board()
	_scores[by].pivot_offset = _scores[by].size * 0.5
	Motion.bump(_scores[by])
	_faces[by].expression = Face.Expr.JOY
	_faces[1 - by].expression = Face.Expr.WORRIED
	var mouth: Vector2 = table.px(Sim.goal_of(1 - by))
	_fx.puff(mouth, Table.SIDE[by][1], 10)
	if sim.over:
		_finish()
		return
	# With two at the table every goal is somebody's: the bright cue for both.
	_fx.cue("goal" if by == 0 or two_players() else "conceded")
	_state = State.GOAL
	_pause = AFTER_GOAL
	_serve_to = 1 - by
	var line := tr("HKY_GOAL")
	if int(sim.scores[by]) == Sim.TARGET - 1:
		line += "\n" + tr("HKY_MATCH_POINT")
	_say(line)

func _glide_sound(delta: float, waiting: bool) -> void:
	if _glide == null or _glide.stream == null:
		return
	var run := 0.0
	if _state == State.PLAY and not waiting and sim.puck_on:
		run = sim.puck_vel.length()
	# Heard from a drift, full by about three metres a second.
	var want := clampf(run / 3.0, 0.0, 1.0) * 0.7
	var now := db_to_linear(_glide.volume_db)
	now = move_toward(now, want, delta * (5.0 if want > now else 2.5))
	_glide.volume_db = linear_to_db(maxf(now, 0.0001))
	_glide.pitch_scale = lerpf(0.9, 1.12, want)
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
		Analytics.track("versus_end", {"game": GAME, "level": level, "won": won,
			"score_you": sim.scores[0], "score_bot": sim.scores[1], "shots": _hits[0],
			"seconds": int(sim.clock)})
	Ads.note_finished()
	_fx.cue("win" if won or two_players() else "lose")
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
	line.text = "  ·  ".join(bits)
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
	if sim != null and not sim.over and _hits[0] + _hits[1] > 0:
		Analytics.track("versus_abandon", {"game": GAME, "level": level, "shots": _hits[0],
			"score_you": sim.scores[0], "score_bot": sim.scores[1]})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
