extends Control

## Deckchair: the ninth game on the Arcade tab, the seven-column card game
## for one (spec docs/superpowers/specs/2026-10-10-arcade-deckchair-design.md).
## The flat boards' top bar (back, the title in ink, undo, the bulb,
## restart, settings), a paper row with the score, the best and the time,
## and under them the table in a wooden frame (arcade/deckchair_table.gd).
##
## The game is arcade/deckchair_sim.gd; the table draws it and takes the
## fingers. This screen keeps the run round it: the boosters before, the
## sounds, the words over the table, the card that comes up at a dead end
## (Undo, or Finish and keep the score), the sweep once every card is face
## up, the Second chance and the end card.
##
## The cards are marks, so the game has no mascot: the end card's seat is a
## fan of cards.

signal closed

const Sim = preload("res://arcade/deckchair_sim.gd")
const Art = preload("res://arcade/deckchair_art.gd")
const Table = preload("res://arcade/deckchair_table.gd")
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
## What the phone knocks for (docs/agents/haptics.md). A card lifted, set
## down or turned off the stock is felt as its sound's echo; these are the
## cues with a kind of their own.
const HAPTICS := {"home": Haptics.TAP, "flip": Haptics.TICK, "nope": Haptics.WARN, "hint": Haptics.GOOD,
	"stuck": Haptics.BAD, "suit": Haptics.GOOD, "win": Haptics.WIN, "new_best": Haptics.WIN}
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "deckchair"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
## The sweep: a beat after the last card turns up, then a card home this
## often.
const SWEEP_WAIT := 0.6
const SWEEP_GAP := 0.085
## Of the sweep's cards, one in this many is felt.
const SWEEP_FELT := 4
## The win is held this long before the end card.
const WIN_HOLD := 2.2

var sim: RefCounted
## A harness names the deal; under nothing the sim shuffles for itself.
var deal_seed := -1
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
var table: Table
var _fx: Node2D
## The sweep's cards are heard and not felt: a second Fx2D with its buzzes
## off, as Peapod's gun has.
var _quiet: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _score_l: Label
var _best_l: Label
var _time_l: Label
var _stuck: Control
var _end: Control
var _held := false
var _started_at := 0
var _best := 0
var _shown_score := -1
var _shown_secs := -1
var _beat_best := false
var _clock := 0.0
var _sweep_t := -1.0
var _swept := 0
var _undos := 0
var _hinted := 0
var _seat: Control
## The loud rewards over the whole screen (arcade/rewards.gd).
var _rw: Rewards
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
	tutor = ScreenTutor.new(self, puzzle_id(), "Deckchair", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	top_bar.refresh(self)
	_ask(false)

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

	top_bar = FlatTopBar.new("Deckchair", tr("DC_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.undo.connect(_on_undo)
	top_bar.hint.connect(_on_hint)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())
	col.add_child(_build_frame())
	_rw = Rewards.new()
	add_child(_rw)
	_apply_insets()

## The wooden frame with the table in it, and the dead end's card docked at
## its foot.
func _build_frame() -> PanelContainer:
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
	table = Table.new()
	table.name = "Table"
	table.said.connect(_on_said)
	table.played.connect(_on_event)
	table.acted.connect(_on_acted)
	frame.add_child(table)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	table.add_child(_fx)
	_quiet = Fx2D.new()
	_quiet.buzzes = false
	table.add_child(_quiet)
	return frame

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["FF_SCORE", "FF_BEST", "DC_TIME"]:
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
	_time_l = made[2]
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

# --- the game ---

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	_hide_stuck()
	sim = Sim.new(deal_seed)
	Boosters.apply(GAME, sim, _boosts)
	_boosted = not _boosts.is_empty()
	_chance_used = false
	_run_gold = 0
	_beat_best = false
	_sweep_t = -1.0
	_swept = 0
	_undos = 0
	_hinted = 0
	_end_score = null
	_rw.clear()
	_best = Record.best(GAME)
	_shown_score = -1
	_shown_secs = -1
	_started_at = Time.get_ticks_msec()
	table.sim = sim
	table.interactive = true
	_fx.cue("deal")
	table.play_events()
	_refresh_hud()
	top_bar.refresh(self)
	Analytics.track("arcade_start", {"game": GAME, "boosts": ",".join(_boosts)})

## The tutorial card's pages (ui/hud/screen_tutor.gd), each a small table
## played by a hand (ui/hud/deckchair_tutorial_diagram.gd). Every number in
## the text is the sim's own.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/deckchair_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.BUILD, "TUT_DECKCHAIR_BUILD", tr("TUT_DECKCHAIR_BUILD_BODY")],
		[Diagram.Lesson.TURN, "TUT_DECKCHAIR_TURN", tr("TUT_DECKCHAIR_TURN_BODY")],
		[Diagram.Lesson.HOME, "TUT_DECKCHAIR_HOME", tr("TUT_DECKCHAIR_HOME_BODY")],
		[Diagram.Lesson.STOCK, "TUT_DECKCHAIR_STOCK", tr("TUT_DECKCHAIR_STOCK_BODY")],
		[Diagram.Lesson.KING, "TUT_DECKCHAIR_KING", tr("TUT_DECKCHAIR_KING_BODY")],
		[Diagram.Lesson.SCORE, "TUT_DECKCHAIR_SCORE", tr("TUT_DECKCHAIR_SCORE_BODY")],
		[Diagram.Lesson.BOOSTS, "TUT_DECKCHAIR_BOOSTS", tr("TUT_DECKCHAIR_BOOSTS_BODY")],
		[Diagram.Lesson.HUD, "TUT_DECKCHAIR_HUD", tr("TUT_DECKCHAIR_HUD_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func capabilities() -> Array:
	return ["undo", "hint"]

func is_done() -> bool:
	return sim != null and sim.is_over()

## Never, as the other Arcade games: a deal won is over, and Restart stays
## the way to the next.
func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return sim != null and sim.can_undo()

func hints_left() -> int:
	return sim.hints if sim != null and not sim.sweeping else 0

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	if not _held and not settings_sheet.is_open():
		sim.tick(delta)
		if _sweep_t >= 0.0:
			_sweep_t -= delta
			while _sweep_t < 0.0 and sim.sweeping:
				_sweep_t += SWEEP_GAP
				if not sim.sweep_step():
					break
				table.play_events()
	_rw.bounds = Rect2(_rw.at(table, Vector2.ZERO), table.size)
	_rw.step(delta)
	_refresh_hud()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()

## The tutorial card holds the clock while it is up.
func _tutor_hold(on: bool) -> void:
	_held = on

func _on_undo() -> void:
	if sim == null or not sim.undo():
		return
	_undos += 1
	table.play_events()

func _on_hint() -> void:
	if sim == null:
		return
	var m: Dictionary = sim.hint()
	if m.is_empty():
		_fx.cue("nope")
		return
	_hinted += 1
	table.show_hint(m)
	_fx.cue("hint")
	Analytics.track("hint_used", {"puzzle_id": GAME})
	top_bar.refresh(self)

# --- what the table says ---

func _on_said(cue: String, pitch: float) -> void:
	if sim != null and sim.sweeping and cue == "home":
		_swept += 1
		_quiet.cue("home", pitch)
		if _swept % SWEEP_FELT == 1:
			_fx.buzz(Haptics.TICK)
		return
	_fx.cue(cue, pitch)

func _on_acted() -> void:
	top_bar.refresh(self)
	if sim != null and not sim.stuck:
		_hide_stuck()

func _on_event(ev: Dictionary) -> void:
	match String(ev.type):
		"move":
			var to: Vector2i = ev.to
			var card: int = (ev.cards as Array)[0]
			if to.x == Sim.At.HOME and Sim.rank_of(card) == Sim.KING:
				_suit_home(to.y)
		"stuck":
			_show_stuck()
		"sweep":
			_sweep_t = SWEEP_WAIT
			_rw.sticker(tr("DC_SWEEP"), _over_table(0.5), 60, 1.4, true, Color.WHITE, false, "sweep")
		"win":
			_on_win(int(ev.bonus))
		"over":
			_run_over()
		"revive":
			_hide_stuck()
			_rw.sticker(tr("CHANCE_GO"), _over_table(0.5), 64, 1.3, true, Color.WHITE, false, "revive")

func _over_table(down: float) -> Vector2:
	return _rw.at(table, table.size * Vector2(0.5, down))

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

## A suit all the way home: its king down, stars off the pile.
func _suit_home(suit: int) -> void:
	var at := _rw.at(table, table.home_at(suit) + table.card_size() * 0.5)
	_fx.cue("suit")
	_rw.spray(at, Art.HALO, 12, 620.0, "star", 1.0)
	_rw.spray(at, Color("fffaf0"), 8, 480.0, "spark", 1.0)
	_rw.ring(at, 170.0, Color(Art.HALO, 0.9))

func _on_win(bonus: int) -> void:
	_hide_stuck()
	table.interactive = false
	_fx.cue("win")
	var mid := _over_table(0.42)
	_rw.sticker(tr("DC_WON"), mid, 70, WIN_HOLD, true, Color.WHITE, true, "won")
	_rw.sticker(tr("DC_BONUS") % Record.grouped(bonus), mid + Vector2(0, 110), 44, WIN_HOLD, false, Color("fff4c2"), false, "bonus")
	_rw.spray(mid, Pal.SUN, 18, 760.0, "star", 1.1, 0.1, _plate_at(_score_l))
	_rw.rain(WIN_HOLD, ["confetti", "star"], Rewards.CONFETTI)
	get_tree().create_timer(WIN_HOLD).timeout.connect(_run_over)

# --- the dead end ---

## Nothing gets anywhere any more: a card at the table's foot, under the
## columns and off them, with the two ways out. The table above it stays
## the player's: a move that finds a way on puts it away.
func _show_stuck() -> void:
	if _stuck != null or sim == null or sim.is_over():
		return
	_fx.cue("stuck")
	var card := PanelContainer.new()
	card.name = "Stuck"
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 30, 18))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var head := Label.new()
	head.text = "DC_STUCK"
	head.theme_type_variation = "SheetTitle"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var line := Label.new()
	line.text = "DC_STUCK_LINE"
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var undo := Dialog.secondary("undo", tr("DC_STUCK_UNDO"))
	undo.name = "Undo"
	undo.disabled = not sim.can_undo()
	undo.pressed.connect(_on_undo)
	row.add_child(undo)
	var finish := Dialog.primary("check", tr("DC_FINISH"))
	finish.name = "Finish"
	finish.pressed.connect(_on_finish)
	row.add_child(finish)
	# the two share the card's width, whatever a dialog's button asks for
	for button: Button in [undo, finish]:
		button.custom_minimum_size.x = 0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# held to the table's foot by a box, so the wrapped line is measured at
	# the card's width (a wrapped Label sized by anchors alone has a width of
	# one before its first layout and comes out thousands tall)
	var holder := MarginContainer.new()
	holder.name = "StuckHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_bottom"]:
		holder.add_theme_constant_override(side, 24)
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	line.custom_minimum_size.x = 400
	holder.add_child(card)
	table.add_child(holder)
	_stuck = holder
	Motion.appear(holder, 0.0, 1.0, 0.25)

func _hide_stuck() -> void:
	if _stuck != null:
		_stuck.queue_free()
		_stuck = null

func _on_finish() -> void:
	if sim == null or sim.is_over():
		return
	_fx.buzz(Haptics.TAP)
	sim.finish()
	table.play_events()

func _refresh_hud() -> void:
	if sim == null:
		return
	var secs := int(sim.t)
	if secs != _shown_secs:
		_shown_secs = secs
		_time_l.text = "%d:%02d" % [secs / 60, secs % 60]
	if sim.score == _shown_score:
		return
	_shown_score = sim.score
	_score_l.text = Record.grouped(sim.score)
	_best_l.text = Record.grouped(maxi(_best, sim.score))
	if not _beat_best and _best > 0 and sim.score > _best:
		_beat_best = true
		_best_l.pivot_offset = _best_l.size * 0.5
		Motion.bump(_best_l, 0.3, 0.4)
		_rw.spray(_plate_at(_best_l), Pal.SUN, 14, 620.0, "star", 1.0)
		_rw.ring(_plate_at(_best_l), 160.0, Color(Pal.SUN, 0.9))
		_fx.buzz(Haptics.BUMP)

# --- the end ---

func _run_over() -> void:
	if sim == null or not sim.is_over():
		return
	_hide_stuck()
	if _offer_chance():
		return
	table.interactive = false
	var won: bool = sim.phase == Sim.Phase.WON
	var better := Record.add(GAME, sim.score, sim.home_count(), _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.home_count(),
		"seconds": secs, "moves": sim.moves, "passes": sim.passes, "undos": _undos, "hints": _hinted,
		"won": won, "best": better})
	Ads.note_finished()
	top_bar.refresh(self)
	get_tree().create_timer(0.3 if won else 0.6).timeout.connect(_show_end.bind(better))

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
	var won: bool = sim.phase == Sim.Phase.WON
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
	seat.custom_minimum_size = Vector2(0, 230)
	# A fan of four cards over a sunburst: each suit's top card at home, the
	# kings on a deal won, a back for a suit that never left.
	var shown_at := _clock
	var tops := []
	for suit in Sim.SUITS:
		tops.append(suit * Sim.RANKS + int(sim.home[suit]) - 1 if int(sim.home[suit]) > 0 else -1)
	var font := CozyTheme.display(700)
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 120.0)
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.4) / 0.35, 0.0, 1.0)
		if glow > 0.0:
			var rb := Face.Builder.new()
			var rr := 200.0 * Motion.back_out(glow)
			rb.disc(c, rr * 0.5, Color(Color("fff4c2"), 0.45))
			Rewards.sunrays(rb, c, rr * 0.2, rr, 14, t * 0.5, Color(Rewards.GOLD if better or won else Pal.SUN, 0.5))
			Rewards.sunrays(rb, c, rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
			var rm := rb.mesh()
			seat.set_meta("rays", rm)
			seat.draw_mesh(rm, null)
		var w := 104.0
		for k in 4:
			var lean := (k - 1.5) * 0.2 + sin(t * 1.6 + k) * 0.015
			var foot := c + Vector2(0, 190.0)
			var xf := Transform2D(lean, foot) * Transform2D(0.0, Vector2(-w * 0.5, -250.0))
			seat.draw_set_transform_matrix(xf)
			var top: int = tops[k]
			if top < 0:
				seat.draw_mesh(Art.back(w), null)
				continue
			seat.draw_mesh(Art.face(k, w), null)
			var text: String = Art.RANKS[Sim.rank_of(top)]
			var wide := text.length() > 1
			seat.draw_string(font, Vector2((0.07 if wide else 0.11) * w, 0.325 * w), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				int(w * (0.27 if wide else 0.31)), Art.ink(top))
		seat.draw_set_transform_matrix(Transform2D.IDENTITY))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else ("DC_END_WON" if won else "DC_END_CARD")
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
	var secs := int(sim.t)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 14)
	for pair in [["%d/%d" % [sim.home_count(), Sim.DECK], "DC_STAT_HOME"], [str(sim.moves), "DC_STAT_MOVES"],
			["%d:%02d" % [secs / 60, secs % 60], "DC_STAT_TIME"]]:
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
	if won:
		best_line.text = tr("DC_BONUS") % Record.grouped(sim.bonus) + "  ·  " + best_line.text
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
## burst of stars when it gets there.
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
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.home_count()})
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
		_hide_stuck()
		sim = null
		table.sim = null
		table.queue_redraw()
	var card := BoostCard.new(GAME)
	card.name = "BoostCard"
	card.play.connect(func(ids: Array) -> void:
		_boosts = ids
		_new_game()
		_fx.buzz(Haptics.TAP))
	add_child(card)

## At a dead end finished, once a run: the Second chance, when one is held
## or the gold for one is. True while it is up; No thanks ends the run as it
## would have. A deal won has nothing to be given.
func _offer_chance() -> bool:
	if _chance_used or sim.phase != Sim.Phase.OVER or not SecondChance.wanted() or sim.score <= 0:
		return false
	_chance_used = true
	var card := SecondChance.new(GAME)
	card.name = "SecondChance"
	card.taken.connect(func() -> void:
		_boosted = true
		Boosters.revive(GAME, sim)
		_fx.buzz(Haptics.GOOD)
		_fx.cue("recycle")
		table.interactive = true
		table.play_events()
		top_bar.refresh(self))
	card.declined.connect(_run_over)
	add_child(card)
	return true
