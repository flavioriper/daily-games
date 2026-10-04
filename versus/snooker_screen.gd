extends Control

## A frame of snooker against the computer: the first game on the Versus
## tab. The flat boards' top bar (back, the title in ink with its sprout,
## reset and a hint with its count, settings), a scoreboard with the sun for
## you and the moon for the computer, and under them the table on a wooden
## deck with the spin pad in a column beside it -- the reference layout's
## ball tally column, given the control instead, since the scoreboard
## already says what is on.
##
## Play: press the table to aim, then drag the cue itself back and let go;
## the pace is how far it was drawn (versus/snooker_table.gd). With
## the cue ball in hand, drag it round the D first. The hint (three a frame)
## asks the computer's own planner for your best shot and lays its line,
## tip and pace out for you to play or ignore.
##
## Local only for now: the other player is versus/snooker_ai.gd, thinking on
## a worker thread so the screen never stalls. The rules are
## versus/snooker_rules.gd and the physics versus/snooker_sim.gd.
##
## **Level 3 is Online** (spec 2026-10-04-versus-online-design.md): the other
## player is a stranger, and `online` (versus/online/online.gd) is everything
## about that which is not snooker. What is snooker's own is under "online"
## below, and it is not what chess and checkers do, because two phones cannot
## be trusted to roll a shot alike: **the player at the table is the
## authority.** Letting go sends the shot; the other end shows the cue play it
## and rolls it on its own table, so the balls move at once. When the
## shooter's table has stopped and its referee has judged, it sends the table
## and the referee's whole state, and the other end -- which has refereed
## nothing -- takes both as sent, sliding any ball that came to rest elsewhere.

signal closed

const Sim = preload("res://versus/snooker_sim.gd")
const Rules = preload("res://versus/snooker_rules.gd")
const AI = preload("res://versus/snooker_ai.gd")
const Table = preload("res://versus/snooker_table.gd")
const Controls = preload("res://versus/snooker_controls.gd")
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
const IconButton = preload("res://ui/hud/icon_button.gd")
const Analytics = preload("res://core/analytics.gd")
const Online = preload("res://versus/online/online.gd")

const GAME := "snooker"
const MARGIN := 40
const GAP := 20
const SCORE_H := 128.0
const COLUMN_W := 150.0
const DECK_PAD := 18
const BACKDROP_BLEED := 90.0
const HINTS := 3
## Pauses, seconds: the shortest the computer seems to think, how long it
## takes to swing onto its line and to draw the cue back, and the beat after
## the balls stop before the next turn.
const THINK_MIN := 0.7
const AIM_SWING := 0.75
const AIM_PULL := 0.45
const AFTER := 0.7
const TOAST_HOLD := 2.2
## The level names, the difficulty sheet's keys.
const LEVELS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "VS_ONLINE"]
## The room a name and its clock have on a scoreboard plate, beside the face.
const NAME_W := 226.0
## Online: how long a ball takes to slide to where the shooter's table has
## it, and how much quicker the cue shows a shot when this end is behind.
const SLIDE := 0.15
const HURRY := 0.4

## LOBBY and SETTLE are online's: the table racked and still while the lobby
## looks, and this end's roll of the other player's shot over, waiting for
## their table. Online, THINK is the other player aiming.
enum State { AIM, THINK, AI_AIM, STROKE, ROLL, WAIT, OVER, LOBBY, SETTLE }

var level := 1
var sim: RefCounted
var rules: RefCounted
var table: Control
var top_bar: Control
var spin_pad: Control
var settings_sheet: Control
## The tutorial card: the top bar's ?, the settings' How to play and the
## first play (ui/hud/screen_tutor.gd).
var tutor: RefCounted
## The card is up: the balls, the computer's arm and its thinking wait under
## it, so no shot is played (or heard) behind a page.
var _held := false
var _state := State.WAIT
var _acc := 0.0
var _rng := RandomNumberGenerator.new()
var _hints := HINTS
var _breaker := 0
var _shots := 0
var _break_off := true
## The worker thread's job: its id, the box it writes into, what it is for
## ("ai" or "hint") and which frame it belongs to (a reset orphans it).
var _task := -1
var _box: Array = []
var _task_for := ""
var _task_frame := 0
var _frame := 0
var _think_at := 0.0
var _ai_shot := {}
var _ai_tw: Tween
var _fx: Node2D
## What the phone knocks for (docs/agents/haptics.md): the table's own cues
## (`strike`, `clack`, `cushion`, `pot`, `foul`) ring for both players and are
## not mapped; the hand's shot knocks through `_fx.buzz`.
const HAPTICS := {"hint": Haptics.GOOD, "win": Haptics.WIN, "lose": Haptics.LOSE}
## The cue is at the end of its draw (ticked once), and this shot's pot has
## bumped.
var _full := false
var _pot_felt := false
## The cloth's rumble: one looping voice whose level follows how fast the
## balls are running, so a break roars and a last creeping ball fades out.
var _roll: AudioStreamPlayer
var _backdrop: ColorRect
var _margins: MarginContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween
var _end: Control
## The re-spotted black is announced once.
var _respot_said := false
# --- the scoreboard ---
var _plates: Array = []
var _scores: Array[Label] = []
var _faces: Array = []
var _on_draw: Control
var _on_label: Label
var _break_label: Label
## The scores as last shown, counted up toward the real ones; the ball on
## as last drawn, so a change can pop.
var _shown_scores := [0, 0]
var _count_tw: Tween
var _last_on := ""
var _names: Array[Label] = []
## The game online, when the level is Record.ONLINE; null against the
## computer (and again once the lobby's "Play the computer" is taken).
var online: Node
## The other seat's messages not taken yet, in order: its next shot can land
## while this table is still rolling the last.
var _inbox: Array[Dictionary] = []
## What the other seat said the result was ("won", "lost" from here), for a
## table that has not got there by what it was sent.
var _online_end := ""
## Which balls were on the table when the other player's shot was shown: a
## table sent back with a red on it that was not is no table.
var _on_before: Array = []
## How far this table's own roll of the other player's shots ended from
## theirs, before it took theirs: shots taken, the worst gap in metres, how
## many balls had to move and how many were on one table and off the other
## (tests/_probe_online.gd prints it).
var drift := {"shots": 0, "worst": 0.0, "moved": 0, "pots": 0}

func _init(the_level := 1) -> void:
	level = clampi(the_level, 0, Record.ONLINE)

func puzzle_id() -> String:
	return GAME

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_rng.randomize()
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Snooker", _hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	_breaker = 0
	if level == Record.ONLINE:
		_go_online()
	else:
		_new_frame()
	top_bar.enter(0.0)
	Analytics.track("versus_start", {"game": GAME, "level": level})

func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

## The tutorial, a page a lesson, each played by the table itself on a few
## hand-placed balls (ui/hud/snooker_tutorial_diagram.gd). The same on every
## level: the level is only how steady the computer's arm is.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/snooker_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.AIM, "TUT_SNOOKER_AIM", tr("TUT_SNOOKER_AIM_BODY")],
		[Diagram.Lesson.ORDER, "TUT_SNOOKER_ORDER", tr("TUT_SNOOKER_ORDER_BODY")],
		[Diagram.Lesson.WORTH, "TUT_SNOOKER_WORTH", tr("TUT_SNOOKER_WORTH_BODY")],
		[Diagram.Lesson.FOUL, "TUT_SNOOKER_FOUL", tr("TUT_SNOOKER_FOUL_BODY")],
		[Diagram.Lesson.SPIN, "TUT_SNOOKER_SPIN", tr("TUT_SNOOKER_SPIN_BODY")],
		[Diagram.Lesson.HINT, "TUT_SNOOKER_HINT", tr("TUT_SNOOKER_HINT_BODY") % HINTS],
		[Diagram.Lesson.HUD, "TUT_SNOOKER_HUD", tr("TUT_SNOOKER_HUD_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.pace = _speed_for
		d.hints = HINTS
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The card going up (true) or leaving: see `_held`.
## Online nothing waits: the other player's clock is running, and a table
## that stopped rolling would never send what it owes.
func _hold(on: bool) -> void:
	if online != null:
		return
	_held = on
	if _ai_tw != null and _ai_tw.is_valid():
		if on:
			_ai_tw.pause()
		else:
			_ai_tw.play()

# --- building ---

func _build() -> void:
	var page := ColorRect.new()
	page.color = Pal.PAPER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_backdrop = Vistas.board_plate(GAME, Pal.ACCENT_2)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_backdrop)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	# A game online has its own motto, as chess and checkers do.
	top_bar = FlatTopBar.new("Snooker", tr("VS_ONLINE_MOTTO" if level == Record.ONLINE else "SNK_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.hint.connect(_on_hint)
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	inset.add_child(row)

	var side_col := VBoxContainer.new()
	side_col.custom_minimum_size.x = COLUMN_W
	side_col.add_theme_constant_override("separation", 6)
	row.add_child(side_col)
	side_col.add_child(_caption("SNK_SPIN"))
	spin_pad = Controls.SpinPad.new()
	spin_pad.changed.connect(func() -> void: table.tip = spin_pad.tip)
	side_col.add_child(spin_pad)

	table = Table.new()
	table.name = "Table"
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.aimed.connect(func() -> void:
		table.hint_power = 0.0
		_hush())
	table.pulling.connect(_on_pull)
	table.placed.connect(func() -> void: _fx.buzz(Haptics.TAP))
	table.released.connect(_on_release)
	row.add_child(table)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	table.add_child(_fx)
	_roll = AudioStreamPlayer.new()
	_roll.volume_db = -80.0
	var roll_path := "res://assets/sfx/snooker/roll.ogg"
	if ResourceLoader.exists(roll_path):
		var stream: AudioStreamOggVorbis = (load(roll_path) as AudioStreamOggVorbis).duplicate()
		stream.loop = true
		_roll.stream = stream
	add_child(_roll)

	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 30, 14))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast_label = Label.new()
	_toast_label.theme_type_variation = "SheetBody"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size.x = 560
	_toast.add_child(_toast_label)
	add_child(_toast)
	_apply_insets()

func _caption(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.theme_type_variation = "MenuKicker"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

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
	rng.seed = 5
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
	# A soft vignette at the deck's edge, so the table sits in light.
	for k in 3:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(36)
		s.bg_color = Color.TRANSPARENT
		s.set_border_width_all(10 + k * 10)
		s.border_color = Color(0.25, 0.12, 0.05, 0.07)
		deck.draw_style_box(s, rect)

func _build_scoreboard() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = SCORE_H
	row.add_theme_constant_override("separation", 16)
	for p in 2:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.size_flags_stretch_ratio = 1.0
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
		name_l.text = "SNK_YOU" if p == 0 else "SNK_BOT"
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
			row.add_child(_build_on_panel())
		row.add_child(plate)
	return row

func _build_on_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 30, 10))
	panel.custom_minimum_size.x = 250
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	_on_label = Label.new()
	_on_label.text = "SNK_BALL_ON"
	_on_label.theme_type_variation = "MenuKicker"
	_on_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_on_label)
	_on_draw = Control.new()
	_on_draw.custom_minimum_size = Vector2(220, 40)
	_on_draw.draw.connect(_draw_on)
	col.add_child(_on_draw)
	_break_label = Label.new()
	_break_label.theme_type_variation = "CardBlurb"
	_break_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_break_label)
	return panel

## The balls on as little painted balls: a red, the six colours, or the one
## colour next in order; a free ball shows a gold ring round them.
func _draw_on() -> void:
	if rules == null:
		return
	var ids: Array = []
	match rules.phase:
		Rules.RED:
			ids = [1]
		Rules.COLOUR:
			for id in range(Sim.YELLOW, Sim.BLACK + 1):
				if sim.on[id]:
					ids.append(id)
		_:
			var n: int = rules.next_colour()
			if n != -1:
				ids = [n]
	var r := 15.0
	var step := r * 2.0 + 6.0
	var x0 := (_on_draw.size.x - step * (ids.size() - 1)) * 0.5
	var y := _on_draw.size.y * 0.5
	for i in ids.size():
		var id: int = ids[i]
		var col: Color = Table.RED if Sim.is_red(id) else Table.BALL[id]
		var c := Vector2(x0 + step * i, y)
		_on_draw.draw_circle(c + Vector2(2, 3), r, Color(0, 0, 0, 0.15))
		_on_draw.draw_circle(c, r, col.darkened(0.25))
		_on_draw.draw_circle(c + Vector2(-1.5, -1.5), r * 0.86, col)
		_on_draw.draw_circle(c + Vector2(-r * 0.4, -r * 0.45), r * 0.2, Color(1, 1, 1, 0.8))
	if rules.free_ball:
		_on_draw.draw_arc(Vector2(_on_draw.size.x * 0.5, y), minf(_on_draw.size.x * 0.5, step * ids.size() * 0.5 + 6.0), 0, TAU, 48, Pal.SUN, 3.0, true)

func _refresh_board() -> void:
	_count_up()
	for p in 2:
		var on: bool = rules.turn == p and not rules.over and _state != State.OVER and _state != State.LOBBY
		var box := CozyTheme.lifted(Pal.SURFACE if on else Color("f7f0e4"), 30, 10)
		if on:
			box.border_color = Pal.ACCENT_2
			box.set_border_width_all(4)
		_plates[p].add_theme_stylebox_override("panel", box)
		_plates[p].modulate.a = 1.0 if on else 0.82
	var brk: int = rules.breaks[rules.turn]
	var bits: Array = []
	if brk > 0:
		bits.append(tr("SNK_BREAK") % brk)
	bits.append(tr("SNK_LEFT") % rules.remaining())
	_break_label.text = "  ·  ".join(bits)
	_on_label.text = "SNK_FREE_BALL" if rules.free_ball else "SNK_BALL_ON"
	_on_draw.queue_redraw()
	var on_now := "%s/%s/%s" % [str(rules.phase), str(rules.next_colour()), str(rules.free_ball)]
	if on_now != _last_on and _last_on != "":
		_on_draw.pivot_offset = _on_draw.size * 0.5
		Motion.bump(_on_draw, 0.3, 0.3)
	_last_on = on_now
	_dress_clocks()
	top_bar.refresh(self)

## The scores tick up to what they are now, a point at a time, and a score
## that went down (a new frame) simply shows.
func _count_up() -> void:
	Motion.stop(_count_tw)
	var from: Array = _shown_scores.duplicate()
	var to: Array = [rules.scores[0], rules.scores[1]]
	var steps := maxi(to[0] - from[0], to[1] - from[1])
	if steps <= 0 or Motion.reduce:
		_shown_scores = to
		for p in 2:
			_scores[p].text = str(to[p])
		return
	_count_tw = create_tween()
	_count_tw.tween_method(func(u: float) -> void:
		for p in 2:
			var v := int(round(lerpf(from[p], to[p], u))) if to[p] >= from[p] else int(to[p])
			if _scores[p].text != str(v):
				_scores[p].text = str(v)
		_shown_scores = [int(_scores[0].text), int(_scores[1].text)],
		0.0, 1.0, clampf(0.08 * steps, 0.2, 0.9))

## "+N" rises off a score plate in the sun's gold and fades.
func _float_points(player: int, n: int) -> void:
	if Motion.reduce:
		return
	var l := Label.new()
	l.text = "+%d" % n
	l.theme_type_variation = "DayBig"
	l.add_theme_color_override("font_color", Pal.SUN)
	l.add_theme_color_override("font_outline_color", Pal.SURFACE)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var at: Rect2 = _scores[player].get_global_rect()
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	l.global_position = at.get_center() - l.size * 0.5 + Vector2(90.0 if player == 0 else -90.0, 10.0)
	l.scale = Vector2.ONE * 0.6
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)

# --- the top bar's view of this screen (FlatTopBar.refresh) ---

func capabilities() -> Array:
	return ["hint"]

func is_done() -> bool:
	return rules != null and (rules.over or _state == State.OVER)

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

## The bulb and Reset are the computer's games' alone: online they stay on
## the bar, greyed.
func hints_left() -> int:
	return _hints if _state == State.AIM and online == null else 0

## The bulb's badge: the count stays up while the bulb waits its turn.
func hints_held() -> int:
	return _hints if online == null else 0

func can_reset() -> bool:
	return online == null and _state != State.STROKE

# --- the frame ---

func _new_frame() -> void:
	_lay()
	_start_turn()

## A fresh table, racked: for a frame, or for the lobby to stand over.
func _lay() -> void:
	_frame += 1
	_state = State.WAIT
	_inbox.clear()
	_online_end = ""
	table.slide({}, 0.0)
	Motion.stop(_ai_tw)
	sim = Sim.new()
	rules = Rules.new(sim, _breaker)
	table.sim = sim
	table.power = 0.0
	table.hint_dir = Vector2.ZERO
	table.aim_dir = Vector2(0.0, -1.0)
	table.cue_away()
	_shown_scores = [0, 0]
	_hints = HINTS
	_shots = 0
	_break_off = true
	_acc = 0.0
	if _end != null:
		_end.queue_free()
		_end = null

func _start_turn() -> void:
	if _state == State.OVER:
		return
	if rules.over:
		_finish()
		return
	if online != null and _online_end != "" and (rules.turn == 0 or _inbox.is_empty()):
		# The other seat said the frame is over and this table does not see it.
		_conclude(_online_end, "end")
		return
	table.hint_dir = Vector2.ZERO
	table.hint_power = 0.0
	table.power = 0.0
	table.in_hand = rules.in_hand
	if rules.in_hand:
		_seat_cue_ball()
	table.targets = rules.legal_first()
	table.cue_in()
	_refresh_board()
	var mine: bool = rules.turn == 0
	for p in 2:
		_faces[p].expression = Face.Expr.HAPPY
	if mine:
		_state = State.AIM
		_controls(true)
		# Aim at the nearest ball on to start, so the line means something.
		_aim_near()
		if rules.free_ball:
			_say(tr("SNK_FREE"))
		elif rules.in_hand:
			_say(tr("SNK_IN_HAND"))
		else:
			_say(tr("SNK_YOUR_TURN"))
	else:
		_state = State.THINK
		_controls(false)
		if online == null:
			_say(tr("SNK_BOT_TURN"))
			_think("ai")
		else:
			_say(online.first_line() if _shots == 0 else tr("SNK_RIVAL_TURN") % online.rival())
			_take_online()
	_dress_clocks()
	top_bar.refresh(self)

func _controls(on: bool) -> void:
	table.interactive = on
	spin_pad.enabled = on
	spin_pad.queue_redraw()
	if on:
		spin_pad.set_tip(Vector2.ZERO)
		table.tip = Vector2.ZERO

## In hand, the cue ball stands somewhere free in the D.
func _seat_cue_ball() -> void:
	var here: Vector2 = Sim.clamp_d(sim.pos[Sim.CUE])
	if sim.free_at(here, Sim.CUE):
		sim.pos[Sim.CUE] = here
		return
	for k in 24:
		var p := Sim.D_CENTRE + Vector2.from_angle(PI * k / 23.0) * Sim.D_R * 0.6
		if sim.free_at(p, Sim.CUE):
			sim.pos[Sim.CUE] = p
			return

func _aim_near() -> void:
	var cue: Vector2 = sim.pos[Sim.CUE]
	var best := INF
	for id in rules.legal_first():
		var d: float = sim.pos[id].distance_to(cue)
		# A ball the cue ball can see straight on beats a nearer one behind
		# something.
		if not sim.lane_clear(cue, sim.pos[id], [Sim.CUE, id]):
			d += 100.0
		if d < best:
			best = d
			table.aim_dir = (sim.pos[id] - cue).normalized()

# --- the player's shot ---

## The reach felt in the fingers: one tick as the cue comes to the end of
## its draw, none again until it has eased off.
func _on_pull() -> void:
	_hush()
	if table.power >= 1.0:
		if not _full:
			_full = true
			_fx.buzz(Haptics.TICK)
	elif table.power < 0.9:
		_full = false

func _on_release(power: float) -> void:
	_full = false
	if _state != State.AIM:
		return
	if power < 0.03:
		table.power = 0.0
		return
	_shoot(table.aim_dir, _speed_for(power), spin_pad.tip)

## Pull to pace: a curve, so the gentle end of the slot has room for touch.
static func _speed_for(power: float) -> float:
	return maxf(0.12, Sim.MAX_SPEED * pow(power, 1.5))

static func _power_for(speed: float) -> float:
	return pow(clampf(speed / Sim.MAX_SPEED, 0.0, 1.0), 1.0 / 1.5)

func _shoot(dir: Vector2, speed: float, tip: Vector2) -> void:
	_state = State.STROKE
	_hush()
	_controls(false)
	table.in_hand = false
	table.hint_dir = Vector2.ZERO
	table.power = _power_for(speed)
	table.aim_dir = dir
	table.tip = tip
	if online != null and rules.turn == 0:
		# The shot, as the other end will play it: the pace it gets is the pace
		# struck here, to the bit.
		var cue: Vector2 = sim.pos[Sim.CUE]
		var packed := Sim.pack(PackedFloat32Array([dir.x, dir.y, speed, tip.x, tip.y, cue.x, cue.y]))
		speed = Sim.unpack(packed, 7)[2]
		online.send({"shot": packed}, true)
	_dress_clocks()
	top_bar.refresh(self)
	_pot_felt = false
	table.play_stroke(func() -> void:
		sim.strike(dir, speed, tip)
		_fx.cue("strike", lerpf(0.9, 1.15, speed / Sim.MAX_SPEED))
		if rules.turn == 0:
			_fx.buzz(Haptics.TAP)
		table.power = 0.0
		_state = State.ROLL
		_acc = 0.0)

func _process(delta: float) -> void:
	if _held:
		_roll_sound(delta)
		return
	match _state:
		State.ROLL:
			_acc += minf(delta, 0.05)
			var n := 0
			while _acc >= Sim.DT and n < 40:
				sim.step(Sim.DT)
				_acc -= Sim.DT
				n += 1
			_play_events()
			if not sim.moving():
				if online != null and rules.turn != 0:
					# The other player's shot: their referee calls it, not this one.
					_state = State.SETTLE
					_take_online()
				else:
					_judge()
	_roll_sound(delta)
	# The worker's answer is picked up whatever the screen is doing: a hint
	# still thinking when the shot is played must not hold the thread when
	# the computer's turn comes round.
	_poll_think()

## Loud as the contact was hard: a kiss at a walking pace is a tick, a break
## a crack. `speed` is the closing speed in metres a second.
func _hit_db(speed: float, full: float) -> float:
	return linear_to_db(clampf(0.12 + 0.88 * speed / full, 0.12, 1.0))

func _roll_sound(delta: float) -> void:
	if _roll == null or _roll.stream == null:
		return
	var run := 0.0
	if _state == State.ROLL and not _held:
		for i in Sim.COUNT:
			if sim.on[i]:
				run += sim.vel[i].length()
	# Heard from a crawl, full by about two metres a second of ball on the cloth.
	var want := clampf(run / 2.0, 0.0, 1.0)
	var now := db_to_linear(_roll.volume_db)
	now = move_toward(now, want, delta * (6.0 if want > now else 2.5))
	_roll.volume_db = linear_to_db(maxf(now, 0.0001))
	_roll.pitch_scale = lerpf(0.85, 1.1, want)
	if now > 0.002 and not _roll.playing:
		_roll.play()
	elif now <= 0.002 and _roll.playing:
		_roll.stop()

func _play_events() -> void:
	for e in sim.events:
		match String(e.kind):
			"ball":
				_fx.cue("clack", clampf(0.85 + float(e.speed) * 0.08, 0.85, 1.25), _hit_db(float(e.speed), 3.0))
				table.flash("ball", e.at, float(e.speed) / 2.5)
			"cushion":
				if float(e.speed) > 0.08:
					_fx.cue("cushion", clampf(0.9 + float(e.speed) * 0.05, 0.9, 1.1), _hit_db(float(e.speed), 3.0))
					table.flash("cushion", e.at, float(e.speed) / 2.0)
			"pot":
				var out: Vector2 = sim.pockets[int(e.pocket)].out
				if e.has("from"):
					table.sink(int(e.id), e.from, (e.at as Vector2) + out * 0.03)
				_fx.cue("pot")
				if rules.turn == 0 and not _pot_felt and _pot_on(int(e.id)):
					_pot_felt = true
					_fx.buzz(Haptics.BUMP)
				table.flash("pot", (e.at as Vector2) + out * 0.03, 1.0)
				if int(e.id) != Sim.CUE:
					var col: Color = Table.RED if Sim.is_red(int(e.id)) else Table.BALL[int(e.id)]
					_fx.puff(table.px(e.at), col.lightened(0.2), 6)
	sim.events.clear()

## Whether a ball dropping off the hand's shot is one it was playing for:
## a ball on, and after a red the colour it struck first. The referee still
## has the last word once everything has stopped (`_judge`).
func _pot_on(id: int) -> bool:
	if id == Sim.CUE or not table.targets.has(id):
		return false
	return rules.phase != Rules.COLOUR or id == sim.first_hit

func _judge() -> void:
	_state = State.WAIT
	_shots += 1
	_break_off = false
	var res: Dictionary = rules.judge()
	if online != null:
		# The referee puts a cue ball in hand on one spot in the D whatever
		# stands there, and `_start_turn` moves it somewhere free only after the
		# beat. The table goes out before that, and a cue ball on top of another
		# ball is a table the other end refuses ("two balls in one place": a
		# foul, and a legal frame forfeited). So it is seated first.
		if rules.in_hand:
			_seat_cue_ball()
		# The table and the referee's whole state, for the other end to take as
		# they are; a ball at rest is put exactly at rest here too, so both
		# tables start the next shot the same to the bit. The turn stays with
		# this seat when it is still at the table.
		var snap: Dictionary = sim.snapshot()
		var same: Dictionary = Sim.read(snap)
		if not same.is_empty():
			sim.restore(same)
		online.send({"table": snap, "rules": rules.to_dict()}, rules.turn == 0)
	_refresh_board()
	_call(res)
	_after()

## What a judged shot looks and sounds like: the points, the foul and its
## words, the faces. `res` is the referee's `last` -- this table's own, or
## online the one the other end sent, so both show the same call.
func _call(res: Dictionary) -> void:
	var player := int(res.player)
	if bool(res.foul):
		var who := _far_name() if player == 0 else tr("SNK_YOU")
		_say(tr(String(res.reason)) + "\n" + tr("SNK_FOUL_TO") % [int(res.penalty), who])
		_fx.cue("foul")
		if player == 0:
			_fx.buzz(Haptics.WARN)
		_faces[player].expression = Face.Expr.WORRIED
		Motion.shiver(_scores[player])
		_float_points(1 - player, int(res.penalty))
	elif int(res.scored) > 0:
		_float_points(player, int(res.scored))
		_scores[player].pivot_offset = _scores[player].size * 0.5
		Motion.bump(_scores[player])
		_faces[player].expression = Face.Expr.JOY
	if rules.respotted_black and not rules.over and rules.phase == Rules.SEQUENCE and sim.on[Sim.BLACK] and rules.in_hand and _respot_said == false:
		_respot_said = true
		_say(tr("SNK_RESPOT_BLACK"))

## The beat after the balls stop, then the next turn.
func _after() -> void:
	var t := get_tree().create_timer(AFTER)
	var frame := _frame
	t.timeout.connect(func() -> void:
		if frame == _frame and is_inside_tree() and _state == State.WAIT:
			_start_turn())

# --- thinking, for the computer and the hint ---

func _think(kind: String) -> void:
	if _task != -1:
		return
	var state := {"phase": rules.phase, "free_ball": rules.free_ball, "in_hand": rules.in_hand,
		"break_off": _break_off}
	var copy: RefCounted = sim.copy()
	var lv := level if kind == "ai" else 2
	var box: Array = [null]
	_box = box
	_task_for = kind
	_task_frame = _frame
	_think_at = Time.get_ticks_msec() / 1000.0
	_task = WorkerThreadPool.add_task(func() -> void: box[0] = AI.plan(copy, state, lv))

func _poll_think() -> void:
	if _task == -1 or not WorkerThreadPool.is_task_completed(_task):
		return
	var kind := _task_for
	if kind == "ai" and Time.get_ticks_msec() / 1000.0 - _think_at < THINK_MIN:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var plan: Dictionary = _box[0] if _box[0] != null else {}
	if kind == "ai" and _task_frame == _frame and _state == State.THINK and not plan.is_empty():
		_play_ai(plan)
		return
	if kind == "hint" and _task_frame == _frame and not plan.is_empty():
		_show_hint(plan)
	# Whatever that was, if it is the computer's turn and it is not playing
	# yet, it thinks now.
	if _state == State.THINK:
		_think("ai")

func _play_ai(plan: Dictionary) -> void:
	_state = State.AI_AIM
	var shot := AI.deliver(plan, level, _rng)
	if rules.in_hand or _break_off:
		sim.pos[Sim.CUE] = plan.get("cue_at", sim.pos[Sim.CUE])
		table.in_hand = false
	_swing(shot.dir, float(shot.speed), shot.tip)

## The other side's arm: the cue swings onto the line, draws back and plays.
## `pace` under 1 hurries it.
func _swing(dir: Vector2, speed: float, tip: Vector2, pace := 1.0) -> void:
	var from: float = table.aim_dir.angle()
	var to: float = dir.angle()
	spin_pad.set_tip(tip)
	table.tip = tip
	Motion.stop(_ai_tw)
	_ai_tw = create_tween()
	_ai_tw.tween_method(func(a: float) -> void: table.aim_dir = Vector2.from_angle(a),
		from, from + wrapf(to - from, -PI, PI), AIM_SWING * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pull := _power_for(speed)
	_ai_tw.tween_method(func(p: float) -> void: table.power = p,
		0.0, pull, AIM_PULL * pace).set_trans(Tween.TRANS_SINE)
	_ai_tw.tween_interval(0.15 * pace)
	_ai_tw.tween_callback(func() -> void:
		_shoot(dir, speed, tip))

func _on_hint() -> void:
	if _state != State.AIM or _hints <= 0 or _task != -1 or online != null:
		return
	_hints -= 1
	top_bar.refresh(self)
	_say(tr("SNK_THINKING"))
	_think("hint")
	Analytics.track("hint_used", {"puzzle_id": GAME, "hints": HINTS - _hints})

func _show_hint(plan: Dictionary) -> void:
	if _state != State.AIM:
		return
	if rules.in_hand or _break_off:
		sim.pos[Sim.CUE] = plan.get("cue_at", sim.pos[Sim.CUE])
	table.aim_dir = plan.dir
	table.hint_dir = plan.dir
	spin_pad.set_tip(plan.tip)
	table.tip = plan.tip
	table.hint_power = _power_for(float(plan.speed))
	_fx.sparkle(table.px(sim.pos[Sim.CUE]))
	_fx.cue("hint")
	_say(tr("SNK_HINT_LINE") % int(round(table.hint_power * 100.0)))

# --- online (level 3): what is snooker's own; the rest is versus/online/online.gd ---

func _go_online() -> void:
	online = Online.new(self, GAME)
	online.seeking.connect(_on_online_seeking)
	online.started.connect(_on_online_started)
	online.move.connect(_on_online_move)
	online.over.connect(_on_online_over)
	online.ticked.connect(_dress_clocks)
	online.computer.connect(_play_computer)
	online.closed.connect(func() -> void: closed.emit())
	add_child(online)
	online.open()

## Looking for a player (the first time, and Find another): a racked table
## under the lobby, nobody in the far seat yet.
func _on_online_seeking() -> void:
	_seat_rival("")
	_lay()
	_state = State.LOBBY
	_controls(false)
	_toast.modulate.a = 0.0
	_refresh_board()

## Found: the seat that opens breaks off, and the frame begins as any does.
func _on_online_started() -> void:
	_breaker = 0 if online.opens() else 1
	_respot_said = false
	drift = {"shots": 0, "worst": 0.0, "moved": 0, "pots": 0}
	_seat_rival(online.opponent)
	_new_frame()

## The far plate's face and name: the other player's, or the moon's.
func _seat_rival(uid: String) -> void:
	var seat: Control = _faces[1].get_parent()
	seat.remove_child(_faces[1])
	_faces[1].queue_free()
	var face: Control = MoonFace.new()
	if uid.is_empty():
		face.size = Vector2(88, 88)
		_names[1].remove_theme_font_size_override("font_size")
		_names[1].remove_theme_color_override("font_color")
		_names[1].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
		# Nobody yet while the lobby looks: the bot is not who is coming.
		_names[1].text = "SNK_BOT" if online == null else "…"
		face.visible = online == null
	else:
		face = online.face(88)
		# Lettered once for the name with its clock after it, so the name does
		# not change size each time the clock comes and goes.
		Online.fit(_names[1], online.rival() + "  ·  0:00", NAME_W)
		_names[1].text = online.rival()
	seat.add_child(face)
	_faces[1] = face

## Who sits in the far seat, in words.
func _far_name() -> String:
	if online == null:
		return tr("SNK_BOT")
	return "…" if online.opponent.is_empty() else online.rival()

## The side at the table carries its seconds on its name -- only while it is
## aiming: a clock that ran through the roll would be counting the balls.
func _dress_clocks() -> void:
	if online == null:
		return
	online.dress(_names[0], tr("SNK_YOU"), _state == State.AIM, true)
	online.dress(_names[1], _far_name(), _state == State.THINK, false)

## The other seat's message, kept in order and taken when this table is ready
## for it (`_take_online`).
func _on_online_move(d: Dictionary) -> void:
	_inbox.append(d)
	_take_online()

## Takes the next message waiting, if this table is where that message
## belongs: a shot while the other player is at the table and nothing is
## rolling, their table once this end's roll of that shot is over. Anything
## else in that place is a foul.
func _take_online() -> void:
	if online == null or (_state != State.THINK and _state != State.SETTLE):
		return
	if _inbox.is_empty():
		if _online_end != "":
			_conclude(_online_end, "end")
		return
	var d: Dictionary = _inbox.pop_front()
	var ok := _show_shot(d) if _state == State.THINK else _take_table(d)
	if not ok:
		online.foul()

## The other player's shot: {shot: seven floats as Sim.pack makes them -- the
## line (x, y), the pace, the tip (x, y) and where the cue ball stood (x, y),
## which is how a placement in the D travels}. The cue shows it the way the
## computer's is shown, and this table rolls it. False for a shot nobody
## could have played.
func _show_shot(d: Dictionary) -> bool:
	if d.size() != 1:
		return false
	var f := Sim.unpack(d.get("shot"), 7)
	if f.is_empty():
		return false
	var dir := Vector2(f[0], f[1])
	var speed := f[2]
	var tip := Vector2(f[3], f[4])
	var cue := Vector2(f[5], f[6])
	if absf(dir.length() - 1.0) > 0.01 or speed <= 0.0 or speed > Sim.MAX_SPEED + 0.001 \
			or tip.length() > Sim.MAX_TIP + 0.001:
		return false
	if rules.in_hand:
		if Sim.clamp_d(cue).distance_to(cue) > 0.0001 or not sim.free_at(cue, Sim.CUE):
			return false
	elif cue.distance_to(sim.pos[Sim.CUE]) > 0.0001:
		return false
	sim.pos[Sim.CUE] = cue
	table.in_hand = false
	_on_before = sim.on.duplicate()
	_state = State.AI_AIM
	_dress_clocks()
	# Their table for this shot is already here: this end is behind, so the
	# cue wastes no time.
	_swing(dir, speed, tip, 1.0 if _inbox.is_empty() else HURRY)
	return true

## The other player's table, once their balls have stopped and their referee
## has judged: {table: Sim.snapshot(), rules: Rules.to_dict()} as they see
## them. Both are taken as sent -- this end referees nothing -- and what is
## shown (points, the foul, the faces) is read off the referee's `last`. A
## ball this table left somewhere else slides to its place. False for a table
## or a state that could not have come from the shot.
func _take_table(d: Dictionary) -> bool:
	var sent: Variant = d.get("rules")
	var t: Dictionary = Sim.read(d.get("table"))
	if d.size() != 2 or t.is_empty() or typeof(sent) != TYPE_DICTIONARY:
		return false
	var scores: Array = rules.scores.duplicate()
	if not rules.from_dict(sent, true) or not _possible(t, scores):
		return false
	var from := {}
	drift.shots += 1
	for i in Sim.COUNT:
		if sim.on[i] and t.on[i]:
			var gap: float = sim.pos[i].distance_to(t.pos[i])
			drift.worst = maxf(drift.worst, gap)
			if gap > 0.0:
				drift.moved += 1
				from[i] = sim.pos[i]
		elif sim.on[i]:
			# Down on their table and not on this one: into the nearest pocket.
			drift.pots += 1
			var best := 0
			for k in sim.pockets.size():
				if sim.pos[i].distance_to(sim.pockets[k].at) < sim.pos[i].distance_to(sim.pockets[best].at):
					best = k
			table.sink(i, sim.pos[i], sim.pockets[best].at)
		elif t.on[i] and not ((Sim.is_colour(i) or i == Sim.CUE) and sim.potted.has(i)):
			# Still up on theirs (a colour or the cue ball coming back to its
			# spot is not that).
			drift.pots += 1
	sim.restore(t)
	if not Motion.reduce:
		table.slide(from, SLIDE)
	_state = State.WAIT
	_shots += 1
	_break_off = false
	_refresh_board()
	_call(rules.last)
	_after()
	return true

## Whether the referee's state just taken could follow from the shot that was
## shown: the other player played it, nobody's score went down or leapt, a
## frame that is over has its winner ahead, and no red has come back.
func _possible(t: Dictionary, was: Array) -> bool:
	if rules.last.is_empty() or int(rules.last.player) != 1:
		return false
	var mine: int = rules.scores[0] - int(was[0])
	var theirs: int = rules.scores[1] - int(was[1])
	if mine < 0 or theirs < 0 or mine > 7 or theirs > 16 or (mine > 0 and theirs > 0):
		return false
	if rules.over and rules.scores[rules.winner] <= rules.scores[1 - rules.winner]:
		return false
	for id in range(1, Sim.REDS + 1):
		if t.on[id] and not _on_before[id]:
			return false
	return true

## The match ended without this table ending it. A resignation, a clock or a
## player gone ends the frame where it stands. "end" is the other seat's word
## that the frame is finished: its last table says so itself, and is on its
## way through `_take_online`; only a table that never gets there takes the
## word for it.
func _on_online_over(outcome: String, why: String) -> void:
	if _state == State.OVER:
		return
	if why != "end":
		_conclude(outcome, why)
		return
	_online_end = outcome
	if _state == State.AIM or _state == State.LOBBY:
		_conclude(outcome, why)
	else:
		_take_online()

## The lobby's "Play the computer": the level last played against it, and a
## frame as if that chip had been picked.
func _play_computer() -> void:
	online.queue_free()
	online = null
	level = Record.last_bot_level(GAME)
	_seat_rival("")
	_names[0].remove_theme_color_override("font_color")
	_names[0].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
	_names[0].text = "SNK_YOU"
	top_bar.set_motto(tr("SNK_MOTTO"))
	Analytics.track("versus_start", {"game": GAME, "level": level})
	_breaker = 0
	_respot_said = false
	_new_frame()
	tutor.first_play()

# --- the end ---

func _finish() -> void:
	_conclude("won" if rules.winner == 0 else "lost", "")

## The frame is over: "won" or "lost" ("draw" only if a match online says
## so). `why` is "" when it ended on the table, else what the match said
## ("resign", "timeout", "left", "end").
func _conclude(outcome: String, why: String) -> void:
	_state = State.OVER
	Motion.stop(_ai_tw)
	_controls(false)
	table.cue_away()
	_refresh_board()
	var won := outcome == "won"
	if online != null:
		# The seat that played the last shot is the one the match hears it from.
		online.settle(outcome, why, _shots, int(rules.last.get("player", -1)) == 0)
	else:
		Record.add(GAME, level, won)
		Analytics.track("versus_end", {"game": GAME, "level": level, "won": won,
			"score_you": rules.scores[0], "score_bot": rules.scores[1], "shots": _shots,
			"high_break": rules.high_break[0]})
	Ads.note_finished()
	_fx.cue("win" if won else "lose")
	_faces[0].expression = Face.Expr.JOY if won else Face.Expr.WORRIED
	_faces[1].expression = Face.Expr.JOY if outcome == "lost" else Face.Expr.WORRIED
	_end = _build_end(outcome, why)
	add_child(_end)
	Motion.appear(_end, 0.0, 1.0, 0.3)
	_celebrate(won)

func _build_end(outcome: String, why: String) -> Control:
	var won := outcome == "won"
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
	var face: Control = SunFace.new()
	if outcome == "lost":
		face = MoonFace.new() if online == null else online.face(170)
	face.size = Vector2(170, 170)
	face.position = Vector2(820 * 0.5 - 40 - 85, 0)
	face.expression = Face.Expr.JOY
	seat.add_child(face)
	col.add_child(seat)
	var head := Label.new()
	head.text = "SNK_WIN" if won else "SNK_LOSE"
	if online != null:
		head.text = online.head(outcome)
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var score := Label.new()
	score.text = "%s %d  –  %d %s" % [tr("SNK_YOU"), rules.scores[0], rules.scores[1], _far_name()]
	score.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	score.theme_type_variation = "SheetTitle"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score)
	# Off the table nobody potted the last ball: the match's own reason, if it
	# has words.
	var said := Label.new()
	said.text = online.why_line(why, outcome) if online != null else ""
	said.visible = said.text != ""
	said.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	said.theme_type_variation = "SheetBody"
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(said)
	var line := Label.new()
	line.text = "%s  ·  %s  ·  %s" % [tr("SNK_HIGH") % rules.high_break[0], tr(LEVELS[level]),
		Record.record_line(GAME, level)]
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var again: Button
	if online != null:
		again = online.again_button()  # Find another
	else:
		again = Dialog.primary("reset", tr("SNK_AGAIN"))
		again.pressed.connect(func() -> void:
			_breaker = 1 - _breaker
			_respot_said = false
			_fx.buzz(Haptics.TAP)
			_new_frame())
	var back := Dialog.secondary("chevron_left", tr("SNK_BACK"))
	back.pressed.connect(_on_back)
	Dialog.buttons(col, again, back)
	return scrim

## The card drops in with a little overshoot; a won frame throws the
## colours up round it, a lost one only settles.
func _celebrate(won: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not won:
		return
	var fx := Fx2D.new()
	_end.add_child(fx)
	var cols := [Table.RED, Table.BALL[Sim.YELLOW], Table.BALL[Sim.GREEN], Table.BALL[Sim.BLUE], Table.BALL[Sim.PINK], Pal.SUN_RAY]
	var mid := size * 0.5
	for k in 8:
		var at := mid + Vector2.from_angle(TAU * k / 8.0 - PI * 0.5) * Vector2(400.0, 330.0)
		var t := get_tree().create_timer(0.25 + 0.14 * k)
		t.timeout.connect(func() -> void:
			if is_instance_valid(fx):
				fx.puff(at, cols[k % cols.size()], 12))

# --- chrome ---

func _say(text: String) -> void:
	_toast_label.text = text
	_place_toast.call_deferred()
	Motion.stop(_toast_tw)
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tw.tween_interval(TOAST_HOLD)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.3)

## A line already read gives way to the player's hands.
func _hush() -> void:
	if _toast.modulate.a <= 0.0 or not (_state == State.AIM or _state == State.STROKE):
		return
	Motion.stop(_toast_tw)
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.2)

## Over the table, a little above its middle, wherever the layout has put
## it by now (the first line is said before the first layout).
func _place_toast() -> void:
	_toast.reset_size()
	var at: Rect2 = table.get_global_rect()
	var frame: Rect2 = table.frame_rect()
	var w := _toast.get_combined_minimum_size().x
	_toast.global_position = Vector2(at.position.x + frame.get_center().x - w * 0.5,
		at.position.y + frame.position.y + frame.size.y * 0.38)

func _on_reset() -> void:
	if not can_reset():
		return
	Analytics.track("board_reset", {"puzzle_id": GAME})
	_respot_said = false
	_fx.buzz(Haptics.TAP)
	_new_frame()

func _on_back() -> void:
	if online != null:
		# A frame in progress is resigned, and only on a yes; versus_abandon is
		# the computer's games', online's is versus_online_end (why resign).
		if online.live() and _state != State.OVER:
			online.ask_leave(_shots)
			return
	elif rules != null and not rules.over and _shots > 0:
		Analytics.track("versus_abandon", {"game": GAME, "level": level, "shots": _shots,
			"score_you": rules.scores[0], "score_bot": rules.scores[1]})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if online != null and online.back():
		return
	if tutor.close():
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()
