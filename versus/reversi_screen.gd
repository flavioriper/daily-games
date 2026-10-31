extends Control

## A game of Reversi: the eighth game on the Versus tab, laid as the daily
## boards: the wooden floor over the whole screen, on the rows' 40 margin the
## flat top bar and its tools row with the count of discs on a pill, the two
## plates, the row of tricks (buttons above the board) and the board
## (versus/reversi_board.gd).
##
## Against the computer and on one phone a game has **tricks**, one use each
## (versus/reversi_rules.gd): a stone on a square, a disc swiped, a second disc.
## On Easy and Medium a finger on a square reads what it does: gold takes a
## corner, red hands one over, sky shuts them out. Your moves are judged on the
## worker as they are made, and the end card draws the game and lets you try
## your worst move again.
##
## The rules (versus/reversi_rules.gd) are the game's as it is played now:
## eight by eight, four discs in the middle, a disc a turn where it shuts a
## run of the other side's between two of your own, every run shut turned
## over, a side with no square passed over, and the most discs at the end.
## Who moves first swaps every game; your discs are always the sun's.
##
## The other player is versus/reversi_ai.gd at one of three levels, thinking
## on a worker thread. **Level 3 is Online** (versus/online/online.gd),
## against a stranger or a friend: both ends hold the same board, so a move
## is its square and nothing else needs saying. What goes over the wire is
## under "online" below.

signal closed

const Rules = preload("res://versus/reversi_rules.gd")
const AI = preload("res://versus/reversi_ai.gd")
const Board = preload("res://versus/reversi_board.gd")
const Record = preload("res://versus/versus_record.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Rewards = preload("res://arcade/rewards.gd")
const Tricks = preload("res://versus/penny_tricks.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
## What the phone knocks for (docs/agents/haptics.md). The board's cues ring
## for both players and are not mapped: the hand's own disc knocks by
## `_fx.buzz`.
const HAPTICS := {"hint": Haptics.GOOD, "win": Haptics.WIN, "lose": Haptics.LOSE, "draw": Haptics.GOOD}
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Online = preload("res://versus/online/online.gd")

const GAME := "reversi"
const TITLE := "Reversi"
const MARGIN := 40
const GAP := 20
const SCORE_H := 112.0
const PILL_R := 30
const CLEAR_CARD := 780
const QUIPS := 3
const QUIP_ODDS := 0.6
## The trick row, the discs a big move turns, a mistake worth going back to
## (the eval's units: a corner is 120), the room the only good move must leave
## the rest, and the moves a position needs before that means much.
const TRICKS := [Rules.STONE, Rules.SWIPE, Rules.ENCORE]
const TRICK_WORDS := {Rules.STONE: "RVS_STONE", Rules.SWIPE: "RVS_SWIPE", Rules.ENCORE: "RVS_ENCORE"}
const BIG_MOVE := 7
const HUGE_MOVE := 11
const WORST := 60
const ONLY_GAP := 90
const ONLY_MOVES := 4
## A lead lost by this many and won back is a comeback.
const COMEBACK := 12
const HINTS := 3
## Seconds: the least the computer is seen to think, how long the square it
## chose is ringed before its disc is down, how much longer it waits when the
## player has just been passed over, and the beat before the end card.
const THINK_MIN := 0.45
const PONDER := 0.25
const PASS_WAIT := 1.2
const END_WAIT := 2.0
const TOAST_HOLD := 2.2
const LEVELS := {0: "DIFF_EASY", 1: "DIFF_MEDIUM", 2: "DIFF_HARD", Record.ONLINE: "VS_ONLINE", Record.LOCAL: "VS_TWO"}
## What Easy and Medium read for a finger.
const READS_UP_TO := 1
## The room a name has on a scoreboard plate, beside its face.
const NAME_W := 250.0

## WAIT is online's: the board at its opening and still while the lobby
## looks. ENTER the board being cleared for a new game; YOURS to move; THINK
## the other player choosing; ANIM discs turning; REWIND a move being taken
## back.
enum State { WAIT, ENTER, YOURS, THINK, ANIM, REWIND, OVER }

var level := 1
var rules: RefCounted
var board: Control
var top_bar: Control
var settings_sheet: Control
## The tutorial card: the top bar's ?, the settings' How to play and the
## first play (ui/hud/screen_tutor.gd).
var tutor: RefCounted
## The rules' side the player is: Rules.FIRST moves first.
var player := Rules.FIRST
var _state := State.WAIT
var _hints := HINTS
## The bulb's square for the position it was asked about, -1 none.
var _hint_cell := -1
var _undos := 0
## True while the tutorial card is over the board.
var _held := false
var _game := 0
var _task := -1
var _box: Array = []
var _task_for := ""
var _task_game := 0
var _think_at := 0.0
var _think_for := THINK_MIN
var _rng := RandomNumberGenerator.new()
var _fx: Node2D
var _world: Control
var _world_mesh: ArrayMesh
var _rw: Rewards
var _margins: MarginContainer
var _tricks: Control
var _mini: Control
## The trick in hand.
var _armed := 0
var _clear_card: Control
## Each move of yours as it stood: {before, cell, loss, eval}, oldest first.
var _log: Array = []
## This run is a go at the worst move: nothing is recorded.
var _retrying := false
## How far behind you have been, and the moves that were the only good one.
var _deepest := 0
var _only_moves := 0
## The position the player's move is being judged from, and the move.
var _judging: RefCounted
var _judged_cell := -1
## The move being shown: who made it (-1 nobody to speak of), where, how many
## discs it turned.
var _moved_by := -1
var _moved_cell := -1
var _moved_n := 0
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween
var _end: Control
var _plates: Array = []
var _faces: Array = []
var _status: Array[Label] = []
var _names: Array[Label] = []
var _count_label: Label
## The game online, when the level is Record.ONLINE; null against the
## computer (and again once the lobby's "Play the computer" is taken).
var online: Node
## The other seat's squares not played yet (-1 for a message that was not a
## square): one can land while this seat's own discs are still turning.
var _inbox: Array[int] = []
## What the other seat said the result was, for a game not yet over here.
var _online_end := ""

func _init(the_level := 1) -> void:
	level = the_level if LEVELS.has(the_level) else 1

func local() -> bool:
	return level == Record.LOCAL

## Tricks are the computer's games' and one phone's: online has none.
func tricky() -> bool:
	return online == null and level != Record.ONLINE

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
	tutor = ScreenTutor.new(self, puzzle_id(), TITLE, _hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	player = Rules.FIRST if Record.last_colour(GAME) == Rules.FIRST else Rules.SECOND
	if level == Record.ONLINE:
		_go_online()
	else:
		_new_game()
	top_bar.enter(0.0)
	Analytics.track("versus_start", {"game": GAME, "level": level})

func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

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

	# The motto names the moon: a game online has its own.
	top_bar = FlatTopBar.new(TITLE, tr("VS_ONLINE_MOTTO" if level == Record.ONLINE else "RVS_MOTTO"), true, false, true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.undo.connect(_on_undo)
	top_bar.reset.connect(_ask_clear)
	top_bar.hint.connect(_on_hint)
	top_bar.settings.connect(func() -> void: settings_sheet.open())
	col.add_child(top_bar)
	top_bar.tint_motto(Color("4a2f12"))
	col.add_child(_build_tools())
	col.add_child(_build_scoreboard())
	_tricks = Tricks.new(TRICKS, TRICK_WORDS, _paint_trick)
	_tricks.name = "Tricks"
	_tricks.picked.connect(_on_trick)
	col.add_child(_tricks)
	_tricks.visible = tricky()

	board = Board.new()
	board.name = "Board"
	board.row_over = true
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_set_reader()
	board.chosen.connect(_on_chosen)
	board.settled.connect(_on_settled)
	board.targeted.connect(_on_targeted)
	board.peeked.connect(_on_peeked)
	board.refused.connect(func(reason: String) -> void:
		_fx.buzz(Haptics.WARN)
		_say(tr({"taken": "RVS_TAKEN", "trick": "RVS_NOT_THERE"}.get(reason, "RVS_NO_RUN"))))
	col.add_child(board)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	add_child(_fx)
	_rw = Rewards.new()
	add_child(_rw)

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

## Easy and Medium read a square under the finger.
func _set_reader() -> void:
	board.reader = (func(cell: int) -> Dictionary: return AI.read(rules, cell)) if level <= READS_UP_TO else Callable()

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
	Scenery.planks(b, _world.size, 5)
	_world_mesh = b.mesh()
	_world.queue_redraw()

## The bar's tools row with the discs on a paper pill where its gap is: Undo,
## the bin, the pill, the bulb.
func _build_tools() -> Control:
	var row: HBoxContainer = top_bar.tools
	var pill := PanelContainer.new()
	pill.name = "Discs"
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.custom_minimum_size.y = FlatTopBar.BUTTON.y
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, PILL_R, 10))
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -6)
	pill.add_child(words)
	var kicker := Label.new()
	kicker.text = "RVS_DISCS"
	kicker.theme_type_variation = "MenuKicker"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(kicker)
	_count_label = Label.new()
	_count_label.theme_type_variation = "SheetTitle"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(_count_label)
	for child in row.get_children():
		if child is Control and not (child is Button):
			child.visible = false
	row.add_child(pill)
	row.move_child(pill, top_bar.hint_button.get_index())
	return row

## A trick's drawing, in a box of side 2r.
static func _paint_trick(b: Face.Builder, kind: int, c: Vector2, r: float) -> void:
	if kind == Rules.STONE:
		b.ellipse(c + Vector2(0.0, r * 0.14), r * 0.86, r * 0.68, Board.STONE_DEEP)
		b.ellipse(c, r * 0.86, r * 0.66, Board.STONE_FACE)
		b.ellipse(c + Vector2(-r * 0.2, -r * 0.2), r * 0.5, r * 0.32, Board.STONE_LIT)
		b.ellipse(c + Vector2(r * 0.34, -r * 0.34), r * 0.36, r * 0.2, Board.MOSS)
	elif kind == Rules.SWIPE:
		# a disc, half each face, and the hand's arc round it
		b.disc(c, r * 0.66, Board.DISC[1])
		var half := Face.Builder.arc_points(c, r * 0.66, -PI * 0.5, PI * 0.5)
		b.fan(half, Board.DISC[0])
		b.stroke(Face.Builder.ring(c, r * 0.66, r * 0.66), r * 0.08, Board.RING[0], true)
		b.stroke(Face.Builder.arc_points(c, r * 0.92, PI * 1.1, PI * 1.9), r * 0.14, Color("c8695f"), false, true)
	else:
		for k in 2:
			var at := c + Vector2((k * 2 - 1) * r * 0.32, 0.0)
			b.disc(at + Vector2(0.0, r * 0.06), r * 0.58, Board.RING[0].darkened(0.3))
			b.disc(at, r * 0.56, Board.DISC[0])
			b.stroke(Face.Builder.ring(at, r * 0.38, r * 0.38), r * 0.05, Board.RING[0], true)
			b.disc(at, r * 0.13, Board.STAMP[0])

func _build_scoreboard() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = SCORE_H
	row.add_theme_constant_override("separation", 16)
	for p in 2:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		words.add_theme_constant_override("separation", -4)
		var align := HORIZONTAL_ALIGNMENT_LEFT if p == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var name_l := Label.new()
		name_l.text = (("HKY_SUN" if p == 0 else "HKY_MOON") if local() else ("SNK_YOU" if p == 0 else "SNK_BOT"))
		name_l.theme_type_variation = "SheetTitle"
		name_l.horizontal_alignment = align
		var status := Label.new()
		status.theme_type_variation = "CardBlurb"
		status.horizontal_alignment = align
		words.add_child(name_l)
		words.add_child(status)
		if p == 1:
			_mini = Tricks.Mini.new(_paint_trick, TRICKS)
			_mini.size_flags_horizontal = Control.SIZE_SHRINK_END
			words.add_child(_mini)
		_status.append(status)
		_names.append(name_l)
		if p == 0:
			inner.add_child(seat)
			inner.add_child(words)
		else:
			inner.add_child(words)
			inner.add_child(seat)
		_plates.append(plate)
		row.add_child(plate)
	return row

## Whose turn it is, on the plates: the one to move lit and saying so. The
## counts between them are the board's as the rules have it.
func _refresh_board() -> void:
	var over := _state == State.OVER or _state == State.WAIT
	for p in 2:
		var mine: bool = not over and (rules.turn == player) == (p == 0)
		var box := CozyTheme.lifted(Pal.SURFACE if mine else Color("f7f0e4"), 30, 10)
		if mine:
			box.border_color = Pal.ACCENT_2
			box.set_border_width_all(4)
		_plates[p].add_theme_stylebox_override("panel", box)
		_plates[p].modulate.a = 1.0 if mine or over else 0.82
		var line := tr("CHS_FIRST" if (player == Rules.FIRST) == (p == 0) else "CHS_SECOND")
		if mine:
			line = tr("CHS_TO_MOVE") if p == 0 or local() else tr("CHS_THINKS")
		if _state == State.WAIT:
			line = ""
		_status[p].text = line
		if online != null:
			# The side to move carries its seconds.
			online.dress(_status[p], line, mine and _state != State.ENTER, p == 0)
	_show_tricks()
	var shown := "%d · %d" % [rules.count(player), rules.count(1 - player)]
	if _count_label.text != shown:
		_count_label.text = shown
		_count_label.pivot_offset = _count_label.size * 0.5
		if _state != State.ENTER and _state != State.WAIT:
			Motion.bump(_count_label, 0.2, 0.25)
	top_bar.refresh(self)

## The row: whoever's hand is to move on one phone, yours otherwise.
func _show_tricks() -> void:
	if not tricky():
		_tricks.visible = false
		_mini.show_stock(0)
		return
	_tricks.visible = true
	var side: int = rules.turn if local() else player
	_tricks.show_stock(int(rules.tricks[side]), _armed, _state == State.YOURS and rules.tricks_open())
	_mini.show_stock(0 if local() else int(rules.tricks[1 - player]))

# --- the top bar's view of this screen (FlatTopBar.refresh) ---

func capabilities() -> Array:
	return ["undo", "hint"]

func is_done() -> bool:
	return _state == State.OVER

func is_solved() -> bool:
	return false

## Undo, the bulb and Reset are the computer's games' alone: online they
## stay on the bar, greyed. Undo needs a disc of the player's own to take
## back.
func can_undo() -> bool:
	if online != null or local() or _state != State.YOURS:
		return false
	for h: Array in rules.history:
		if h[2] == player:
			return true
	return false

## The discs set down so far, by either side.
func _move_number() -> int:
	return rules.ply

func hints_left() -> int:
	return _hints if _state == State.YOURS and online == null and not local() else 0

## The bulb's badge: the count stays up while the bulb waits its turn.
func hints_held() -> int:
	return _hints if online == null and not local() else 0

## Reset waits out discs still turning.
func can_reset() -> bool:
	return online == null and _state != State.ANIM and _state != State.REWIND and _state != State.ENTER

## The How to play card's pages (ui/hud/how_to_play.gd), each played on the
## board itself by ui/hud/reversi_tutorial_diagram.gd. The level only changes
## how well the computer plays, so the pages are the same on all three.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/reversi_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.PLACE, "TUT_REVERSI_PLACE", tr("TUT_REVERSI_PLACE_BODY")],
		[Diagram.Lesson.MANY, "TUT_REVERSI_MANY", tr("TUT_REVERSI_MANY_BODY")],
		[Diagram.Lesson.PASS, "TUT_REVERSI_PASS", tr("TUT_REVERSI_PASS_BODY")],
		[Diagram.Lesson.CORNER, "TUT_REVERSI_CORNER", tr("TUT_REVERSI_CORNER_BODY")],
		[Diagram.Lesson.BAR, "TUT_REVERSI_BAR",
			tr("TUT_REVERSI_BAR_BODY_ONE") if HINTS == 1 else tr("TUT_REVERSI_BAR_BODY_N") % HINTS],
	]
	if tricky():
		steps.insert(steps.size() - 1, [Diagram.Lesson.TRICKS, "TUT_REVERSI_TRICKS", tr("TUT_REVERSI_TRICKS_BODY")])
	var pages := []
	for step: Array in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

# --- the game ---

func _new_game() -> void:
	_lay(State.ENTER)

## The board at its opening: cleared for a game (ENTER), or simply there,
## for the lobby to stand over (WAIT).
func _lay(state: State) -> void:
	_game += 1
	rules = Rules.new()
	_inbox.clear()
	_online_end = ""
	_hints = HINTS
	_hint_cell = -1
	_undos = 0
	_state = state
	_armed = 0
	board.armed = 0
	_log.clear()
	_retrying = false
	_deepest = 0
	_only_moves = 0
	_judging = null
	_moved_by = -1
	_rw.clear()
	_close_clear()
	if tricky():
		rules.tricks[player] = Rules.ALL_TRICKS
		rules.tricks[1 - player] = Rules.ALL_TRICKS if local() else int(AI.STOCK[level])
	if _end != null:
		_end.queue_free()
		_end = null
	for f in _faces:
		f.expression = Face.Expr.HAPPY
	board.interactive = false
	board.setup(rules, player, state == State.ENTER)
	_refresh_board()

func _on_settled() -> void:
	if _state == State.ANIM:
		_moment()
	if _state == State.ENTER or _state == State.ANIM or _state == State.REWIND:
		_start_turn()

## What the move just shown was, the moon's as loud as yours.
func _moment() -> void:
	var by := _moved_by
	if by < 0:
		return
	_moved_by = -1
	var p := 0 if by == player else 1
	var mid: Vector2 = _rw.at(board, board.point_of(Board.GRID * 0.5))
	var lead: int = rules.count(player) - rules.count(1 - player)
	_deepest = mini(_deepest, lead)
	if _moved_cell in Rules.CORNERS:
		_rw.sticker(tr("RVS_CORNER"), _rw.at(board, board.point_of(Board.mid(_moved_cell))), 76, 0.9, false, Color("ffe7a0"), false, "corner")
		_faces[p].expression = Face.Expr.JOY
		_faces[1 - p].expression = Face.Expr.WORRIED
		_quip("CORNER_ME" if by == player else "CORNER_MOON")
	elif _moved_n >= BIG_MOVE:
		var huge := _moved_n >= HUGE_MOVE
		_rw.sticker(tr("RVS_BIG") % _moved_n, mid, 96 if huge else 80, 1.0, huge, Color.WHITE, huge, "big")
		_quip("BIG_ME" if by == player else "BIG_MOON")
	elif rules.passed and not rules.over and rules.turn == by:
		_rw.sticker(tr("RVS_SHUT"), mid, 76, 0.9, false, Color("cfeefa"), false, "shut")
		_quip("SHUT_ME" if by == player else "SHUT_MOON")
	elif by == player and _deepest <= -COMEBACK and lead > 0 and not local():
		_deepest = 0
		_rw.sticker(tr("RVS_COMEBACK"), mid, 96, 1.1, true, Color.WHITE, true, "comeback")
		_fx.cue("hint")

func _quip(kind: String) -> void:
	if online == null and not local() and randf() < QUIP_ODDS:
		_say(tr("RVS_Q_%s_%d" % [kind, 1 + randi() % QUIPS]))

func _start_turn() -> void:
	var status: int = rules.status()
	if status != Rules.PLAYING:
		_finish(status)
		return
	# On one phone every turn is a hand's.
	var mine: bool = rules.turn == player or local()
	if online != null and mine and not _inbox.is_empty():
		# A move sent when, by this board's rules, the turn was not theirs.
		_inbox.clear()
		online.foul()
		return
	if online != null and _online_end != "" and (mine or _inbox.is_empty()):
		# The other seat said the game is over, every move it sent has been
		# played, and by this board's rules -- the same rules -- it is not.
		_online_end = ""
		online.foul()
		return
	# The side that just moved moves again: the other had no square.
	var again: bool = rules.passed and rules.ply > 0
	if again:
		_fx.cue("pass")
		board.knock(1 - rules.turn)
		if not mine:
			_fx.buzz(Haptics.WARN)
		if local():
			_say(tr("RVS_PASS_LOCAL") % tr("HKY_MOON" if rules.turn == player else "HKY_SUN"))
		else:
			_say(tr("RVS_PASS_THEM" if mine else "RVS_PASS_YOU"))
	if mine:
		_state = State.YOURS
		board.interactive = true
		if local() and not again:
			_say(tr("RVS_LOCAL_TURN") % tr("HKY_SUN" if rules.turn == player else "HKY_MOON"))
		elif rules.ply < 2 and not again:
			_say(tr("RVS_YOUR_MOVE"))
	else:
		_state = State.THINK
		board.interactive = false
		if rules.ply == 0:
			_say(tr("CHS_BOT_FIRST") if online == null else online.first_line())
		if online == null:
			_think_for = THINK_MIN + (PASS_WAIT if again else 0.0)
			_think("ai")
		else:
			_take_online()
	_refresh_board()

## The player let go over a square that may be played.
func _on_chosen(cell: int) -> void:
	if _state != State.YOURS or not rules.can(cell):
		return
	_fx.buzz(Haptics.TAP)
	_play(cell)

## A trick in the row touched: in hand, or put back. An encore is no square.
func _on_trick(kind: int) -> void:
	if _state != State.YOURS:
		return
	_fx.cue("arm")
	_fx.buzz(Haptics.TICK)
	if kind == Rules.ENCORE:
		if rules.encore():
			_rw.sticker(tr("RVS_ENCORE_GO"), _rw.at(board, board.point_of(Board.GRID * 0.5)), 64, 0.8, false, Color("fff4c2"), false, "encore")
			_refresh_board()
		return
	_armed = 0 if _armed == kind else kind
	board.armed = _armed
	if _armed != 0:
		_say(tr("RVS_STONE_LINE" if _armed == Rules.STONE else "RVS_SWIPE_LINE"))
	else:
		_hush()
	_refresh_board()

## The trick in hand put on `cell`.
func _on_targeted(cell: int) -> void:
	if _state != State.YOURS:
		return
	_fx.buzz(Haptics.TAP)
	var kind := _armed
	_armed = 0
	board.armed = 0
	_trick(kind, cell)

## Either side's stone or swipe, on `cell`.
func _trick(kind: int, cell: int) -> void:
	var side: int = rules.turn
	_state = State.ANIM
	board.interactive = false
	_hint_cell = -1
	_hush()
	_moved_by = -1
	if kind == Rules.STONE:
		rules.stone(cell)
		board.stone(cell)
	else:
		rules.swipe(cell)
		board.swiped(cell, side)
	if side != player:
		_quip("TRICK")
	_rw.sticker(tr("RVS_STONE_SAID" if kind == Rules.STONE else "RVS_SWIPE_SAID"), _rw.at(board, board.point_of(Board.mid(cell))), 64, 0.8, false, Color("fff4c2"), false, "trick")
	_refresh_board()

func _on_peeked(kind: String, turned: int) -> void:
	_say(tr({"corner": "RVS_READ_CORNER", "gives": "RVS_READ_GIVES", "shut": "RVS_READ_SHUT"}[kind]) % turned)

func _play(cell: int) -> void:
	var side: int = rules.turn
	# Your move, judged on the worker while its discs turn.
	var judged: bool = online == null and not local() and side == player
	var before: RefCounted = rules.copy() if judged else null
	var turned: PackedInt32Array = rules.make(cell)
	_moved_by = side
	_moved_cell = cell
	_moved_n = turned.size()
	if judged:
		_log.append({"before": before, "cell": cell, "loss": 0, "eval": 0})
		_judging = before
		_judged_cell = cell
		_think("judge")
	_state = State.ANIM
	board.interactive = false
	_hint_cell = -1
	_hush()
	board.play(cell, turned, side)
	if online != null and side == player:
		# The turn is kept when the other seat has no square to play.
		online.send({"m": cell}, rules.turn == player and not rules.over)
	_refresh_board()

# --- thinking, for the computer and the hint ---

func _process(delta: float) -> void:
	_rw.step(delta)
	# The computer's answer waits while the tutorial card is up, so no disc
	# is set down (or heard) behind a page.
	if not _held:
		_poll_think()

func _hold(on: bool) -> void:
	_held = on

func _think(kind: String) -> void:
	if _task != -1:
		return
	var copy: RefCounted = rules.copy()
	var lv: int = clampi(level, 0, 2) if kind == "ai" else 2
	var budget := -1 if kind == "ai" else AI.HINT_BUDGET_MS
	var seed := _rng.randi()
	var box: Array = [-1]
	_box = box
	if kind == "judge":
		var from: RefCounted = _judging
		var cell := _judged_cell
		_task_for = kind
		_task_game = _game
		_think_at = Time.get_ticks_msec() / 1000.0
		_task = WorkerThreadPool.add_task(func() -> void: box[0] = AI.new().judge(from, cell))
		return
	_task_for = kind
	_task_game = _game
	_think_at = Time.get_ticks_msec() / 1000.0
	if kind == "ai":
		_task = WorkerThreadPool.add_task(func() -> void: box[0] = AI.new().plan_turn(copy, lv, seed, budget))
	else:
		_task = WorkerThreadPool.add_task(func() -> void: box[0] = AI.new().plan(copy, lv, seed, budget))

func _poll_think() -> void:
	if _task == -1 or not WorkerThreadPool.is_task_completed(_task):
		return
	var kind := _task_for
	if kind == "ai" and Time.get_ticks_msec() / 1000.0 - _think_at < (0.05 if Motion.reduce else _think_for):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if kind == "judge":
		if _task_game == _game:
			_on_judged(_box[0])
		if _state == State.THINK and online == null:
			_think("ai")
		return
	if kind == "ai":
		var plan: Dictionary = _box[0]
		if _task_game == _game and _state == State.THINK and int(plan.cell) >= -1:
			_bot_does(plan)
		return
	var cell: int = _box[0]
	if kind == "hint" and _task_game == _game and _state == State.YOURS and cell >= 0:
		_hint_cell = cell
		board.set_hint(cell)
		_fx.cue("hint")
		_say(tr("RVS_HINT_LINE"))
	if _state == State.THINK and online == null:
		_think("ai")

## What the judge said of your last move: what it cost, kept for the end card,
## and a word for a move only you found.
func _on_judged(j: Dictionary) -> void:
	if j.is_empty() or _log.is_empty():
		return
	var last: Dictionary = _log[_log.size() - 1]
	last.loss = int(j.best_score) - int(j.score)
	last.eval = int(j.score)
	last.best = int(j.best)
	if int(j.best) == int(last.cell) and int(j.gap) >= ONLY_GAP and (last.before as RefCounted).legal_moves().size() >= ONLY_MOVES:
		_only_moves += 1
		_rw.sticker(tr("RVS_ONLY"), _rw.at(board, board.point_of(Board.mid(last.cell))), 62, 0.9, false, Color("d6f5c9"), false, "only")

## The computer's turn: a disc, or a trick.
func _bot_does(plan: Dictionary) -> void:
	var kind := int(plan.trick)
	var cell := int(plan.cell)
	if kind == Rules.ENCORE:
		rules.encore()
		_rw.sticker(tr("RVS_ENCORE_GO"), _rw.at(board, board.point_of(Board.GRID * 0.5)), 64, 0.8, false, Color("cdd5ff"), false, "encore")
		_quip("TRICK")
		_refresh_board()
		_think("ai")
	elif kind != 0:
		_state = State.ANIM
		board.set_lifted(cell)
		var game := _game
		get_tree().create_timer(0.0 if Motion.reduce else PONDER).timeout.connect(func() -> void:
			if _game != game or not is_inside_tree() or _state != State.ANIM:
				return
			_trick(kind, cell))
	else:
		_bot_moves(cell)

## The other player's square is ringed a beat, and its disc set down.
func _bot_moves(cell: int) -> void:
	_state = State.ANIM
	board.set_lifted(cell)
	var game := _game
	get_tree().create_timer(0.0 if Motion.reduce else PONDER).timeout.connect(func() -> void:
		# An online game can end (a resignation, a clock) inside the beat.
		if _game != game or not is_inside_tree() or _state != State.ANIM:
			return
		_play(cell))

func _on_hint() -> void:
	if _state != State.YOURS or _task != -1 or online != null or local():
		return
	if _hint_cell >= 0:
		board.set_hint(_hint_cell)
		_say(tr("RVS_HINT_LINE"))
		return
	if _hints <= 0:
		return
	_hints -= 1
	top_bar.refresh(self)
	_say(tr("CHS_THINKING"))
	_think("hint")
	Analytics.track("hint_used", {"puzzle_id": GAME, "hints": HINTS - _hints})

# --- undo ---

## Takes back your last disc and whatever the computer answered it with.
func _on_undo() -> void:
	if not can_undo():
		return
	_undos += 1
	_state = State.REWIND
	_fx.buzz(Haptics.TICK)
	board.interactive = false
	_hint_cell = -1
	_hush()
	while not rules.history.is_empty():
		var side: int = rules.history[rules.history.size() - 1][2]
		rules.unmake()
		if side == player:
			break
	while not _log.is_empty() and (_log[_log.size() - 1].before as RefCounted).ply >= rules.ply:
		_log.pop_back()
	board.sync()
	_refresh_board()
	Analytics.track("undo_used", {"puzzle_id": GAME, "undos": _undos})

# --- online (level 3): what is this game's own; the rest is versus/online/online.gd ---
#
# The wire, one JSON object a message: {m: square}, 0 to 63. The turn passes,
# except from a seat whose move leaves the other with no square to play: it
# keeps the turn (`send(d, true)`) and moves again. Both ends hold the same
# board, so each works that out for itself; the ending is each board's own to
# reach.

func _go_online() -> void:
	online = Online.new(self, GAME)
	online.seeking.connect(_on_online_seeking)
	online.started.connect(_on_online_started)
	online.move.connect(_on_online_move)
	online.over.connect(_on_online_over)
	online.ticked.connect(_on_online_ticked)
	online.computer.connect(_play_computer)
	online.closed.connect(func() -> void: closed.emit())
	add_child(online)
	online.open()

## Looking for a player (the first time, and Find another): the opening's
## board under the lobby, nobody in the far seat yet.
func _on_online_seeking() -> void:
	_seat_rival("")
	_lay(State.WAIT)

## Found: the seat that opens moves first, and the game begins as any does.
func _on_online_started() -> void:
	player = Rules.FIRST if online.opens() else Rules.SECOND
	_seat_rival(online.opponent)
	_new_game()

## The far plate's face and name: the other player's, or the moon's.
func _seat_rival(uid: String) -> void:
	var seat: Control = _faces[1].get_parent()
	seat.remove_child(_faces[1])
	_faces[1].queue_free()
	var face: Control = MoonFace.new()
	if uid.is_empty():
		face.size = Vector2(88, 88)
		_names[1].remove_theme_font_size_override("font_size")
		_names[1].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
		# Nobody yet while the lobby looks: the bot is not who is coming.
		_names[1].text = "SNK_BOT" if online == null else "…"
		face.visible = online == null
	else:
		face = online.face(88)
		Online.fit(_names[1], online.rival(), NAME_W)
	seat.add_child(face)
	_faces[1] = face

## The other seat's move, as it was sent: one key, a whole number from 0 to
## 63. Anything else waits as -1, which no board can play. A move that comes
## while this seat is to move is one the other seat had no turn to make.
func _on_online_move(d: Dictionary) -> void:
	var cell := -1
	var sent: Variant = d.get("m")
	if d.size() == 1 and (typeof(sent) == TYPE_FLOAT or typeof(sent) == TYPE_INT):
		var f := float(sent)
		if f == floorf(f) and f >= 0.0 and f < Rules.CELLS:
			cell = int(f)
	if _state == State.YOURS:
		online.foul()
		return
	_inbox.append(cell)
	_take_online()

## Plays the next move waiting, if it is the other seat's turn to be seen
## moving. A square that is not one, or shuts nothing, is a foul.
func _take_online() -> void:
	if _state != State.THINK or _inbox.is_empty():
		return
	var cell: int = _inbox.pop_front()
	if not rules.can(cell):
		online.foul()
		return
	_bot_moves(cell)

## The match ended without this board ending it. A resignation, a clock or a
## player gone ends the game where it stands. "end" is the other seat's word
## that the game finished on the board, and it is not taken on trust: the
## rules let the seat that moved last write it with any winner, but both ends
## run the same rules, so a real ending is one this board reaches by itself
## once the last disc has turned (`_start_turn` finishes on its own status,
## and the result shown is this board's). An "end" this board does not reach,
## with nothing left to play, is a foul.
func _on_online_over(outcome: String, why: String) -> void:
	if _state == State.OVER:
		return
	if why != "end":
		_conclude(outcome, "", why)
		return
	_online_end = outcome
	if _state == State.YOURS or (_state == State.THINK and _inbox.is_empty()):
		_online_end = ""
		online.foul()

func _on_online_ticked() -> void:
	if _state != State.OVER and _state != State.WAIT:
		_refresh_board()

## The lobby's "Play the computer": the level last played against it, and a
## game as if that chip had been picked.
func _play_computer() -> void:
	online.queue_free()
	online = null
	level = Record.last_bot_level(GAME)
	_set_reader()
	player = Rules.FIRST if Record.last_colour(GAME) == Rules.FIRST else Rules.SECOND
	_seat_rival("")
	for l in _status:
		l.remove_theme_color_override("font_color")
	top_bar.set_motto(tr("RVS_MOTTO"))
	Analytics.track("versus_start", {"game": GAME, "level": level})
	_new_game()
	tutor.first_play()

# --- the end ---

func _finish(status: int) -> void:
	var said := tr("RVS_END_COUNT") % [rules.count(player), rules.count(1 - player)]
	if status == Rules.WON:
		_conclude("won" if rules.winner() == player else "lost", said, "")
	else:
		_conclude("draw", tr("RVS_DRAW_EVEN") % rules.count(player), "")

## The game is over: "won", "lost" or "draw". On the board, `said` is how it
## stood (the card's line; a draw's is also the toast); online and off the
## board, `why` is what the match said ("resign", "timeout", "left", "end").
func _conclude(outcome: String, said: String, why: String) -> void:
	var mine_last: bool = rules.last_side == player
	_state = State.OVER
	board.interactive = false
	board.finish(outcome, rules.winner())
	_refresh_board()
	if online != null:
		online.settle(outcome, why, _move_number(), mine_last)
	elif not local() and not _retrying:
		if outcome == "draw":
			Record.add_draw(GAME, level)
		else:
			Record.add(GAME, level, outcome == "won")
			var streak: int = int(Record.option(GAME, "streak", 0)) + 1 if outcome == "won" else 0
			Record.set_option(GAME, "streak", streak)
			if streak > int(Record.option(GAME, "best_streak", 0)):
				Record.set_option(GAME, "best_streak", streak)
		Analytics.track("versus_end", {"game": GAME, "level": level, "won": outcome == "won",
			"result": outcome, "moves": _move_number(), "undos": _undos, "hints": HINTS - _hints,
			"discs": rules.count(player), "discs_other": rules.count(1 - player),
			"first": player == Rules.FIRST})
	Ads.note_finished()
	_fx.cue("win" if local() and outcome != "draw" else {"won": "win", "lost": "lose", "draw": "draw"}[outcome])
	if why == "" and rules.winner() >= 0 and rules.count(1 - rules.winner()) == 0:
		_rw.sticker(tr("RVS_WIPEOUT"), _rw.at(board, board.point_of(Board.GRID * 0.5)), 104, 1.5, true, Color.WHITE, true, "wipeout")
	_faces[0].expression = Face.Expr.JOY if outcome == "won" else (Face.Expr.WORRIED if outcome == "lost" else Face.Expr.SLEEPY)
	_faces[1].expression = Face.Expr.JOY if outcome == "lost" else (Face.Expr.WORRIED if outcome == "won" else Face.Expr.SLEEPY)
	if outcome == "draw" and said != "":
		_say(said)
	var game := _game
	get_tree().create_timer(0.3 if Motion.reduce else END_WAIT).timeout.connect(func() -> void:
		if _game != game or not is_inside_tree():
			return
		_end = _build_end(outcome, said, why)
		add_child(_end)
		Motion.appear(_end, 0.0, 1.0, 0.3)
		_celebrate(outcome == "won"))

func _build_end(outcome: String, line_said: String, why := "") -> Control:
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
	face.expression = Face.Expr.SLEEPY if outcome == "draw" else Face.Expr.JOY
	seat.add_child(face)
	col.add_child(seat)
	var head := Label.new()
	head.text = {"won": "RVS_WIN", "lost": "RVS_LOSE", "draw": "CHS_DRAW"}[outcome]
	if online != null:
		head.text = online.head(outcome)
	elif local() and outcome != "draw":
		head.text = tr("RVS_LOCAL_WON") % tr("HKY_SUN" if rules.winner() == player else "HKY_MOON")
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var said := Label.new()
	said.text = line_said
	# Off the board no count ended it: the match's own reason, if it has words.
	if online != null and why != "":
		said.text = online.why_line(why, outcome)
	said.visible = said.text != ""
	said.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	said.theme_type_variation = "SheetBody"
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(said)
	var line := Label.new()
	var bits: Array = [tr(LEVELS[level])]
	if not local():
		bits.append(Record.record_line(GAME, level))
		var streak := int(Record.option(GAME, "streak", 0))
		if streak >= 2:
			bits.append(tr("HKY_STREAK") % streak)
	line.text = "  ·  ".join(bits)
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.theme_type_variation = "SheetBodyDim"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var worst := _worst_move()
	if not worst.is_empty() and online == null and not local():
		col.add_child(_build_graph())
		var retry := Dialog.secondary("undo_back", tr("RVS_RETRY"))
		retry.pressed.connect(_retry.bind(worst))
		col.add_child(retry)
	var again: Button
	if online != null:
		again = online.again_button()  # Find another
	else:
		again = Dialog.primary("reset", tr("SNK_AGAIN"))
		again.pressed.connect(func() -> void:
			player = 1 - player
			Record.set_last_colour(GAME, player)
			_fx.buzz(Haptics.TAP)
			_new_game())
	var back := Dialog.secondary("chevron_left", tr("SNK_BACK"))
	back.pressed.connect(_on_back)
	Dialog.buttons(col, again, back)
	return scrim

## The move of yours that cost most, if one cost enough.
func _worst_move() -> Dictionary:
	var worst := {}
	var most := WORST - 1
	for m: Dictionary in _log:
		if int(m.loss) > most:
			most = int(m.loss)
			worst = m
	return worst

## The game as it went: your standing move by move, a line over the even mark,
## a dot on the worst.
func _build_graph() -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, 110)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var worst := _worst_move()
	var moves: Array = _log.duplicate()
	g.draw.connect(func() -> void:
		var w := g.size.x
		var h := g.size.y
		g.draw_line(Vector2(0.0, h * 0.5), Vector2(w, h * 0.5), Color(Pal.LINE, 0.6), 2.0)
		var pts := PackedVector2Array()
		var mark := Vector2.INF
		for i in moves.size():
			var u: float = clampf(float(moves[i].eval) / 300.0, -1.0, 1.0)
			var p := Vector2(w * (float(i) + 0.5) / maxf(1.0, moves.size()), h * 0.5 - u * h * 0.44)
			pts.append(p)
			if moves[i] == worst:
				mark = p
		if pts.size() > 1:
			g.draw_polyline(pts, Pal.ACCENT, 5.0, true)
		if mark != Vector2.INF:
			g.draw_circle(mark, 9.0, Pal.BAD, true, -1.0, true))
	return g

## Back to the worst move of the game, as it stood. Nothing it comes to counts.
func _retry(m: Dictionary) -> void:
	_fx.buzz(Haptics.TAP)
	_game += 1
	rules = (m.before as RefCounted).copy()
	_log.clear()
	_retrying = true
	_hint_cell = -1
	_armed = 0
	board.armed = 0
	_state = State.ENTER
	if _end != null:
		_end.queue_free()
		_end = null
	for f in _faces:
		f.expression = Face.Expr.HAPPY
	board.interactive = false
	board.setup(rules, player, false)
	_refresh_board()
	_start_turn()
	_say(tr("RVS_RETRY_LINE"))

## The bin asks, unless the game has not begun.
func _ask_clear() -> void:
	if _clear_card != null or not can_reset():
		return
	if rules.ply == 0:
		_on_reset()
		return
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
	body.text = "RVS_CLEAR_BODY"
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
	var cols := [Pal.WATER_HI, Pal.SUN_RAY, Pal.BERRY, Pal.LEAF, Pal.FLOWER]
	var mid := size * 0.5
	for k in 8:
		var at := mid + Vector2.from_angle(TAU * k / 8.0 - PI * 0.5) * Vector2(400.0, 330.0)
		# bound to the effect itself, so a card closed early takes the
		# connection with it
		get_tree().create_timer(0.25 + 0.14 * k).timeout.connect(fx.puff.bind(at, cols[k % cols.size()], 12))

# --- chrome ---

func _say(text: String) -> void:
	_toast_label.text = text
	_place_toast.call_deferred()
	Motion.stop(_toast_tw)
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tw.tween_interval(TOAST_HOLD)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.3)

func _hush() -> void:
	if _toast.modulate.a <= 0.0:
		return
	Motion.stop(_toast_tw)
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.2)

## Over the board's top edge, where it hides no square.
func _place_toast() -> void:
	_toast.reset_size()
	var sz := _toast.get_combined_minimum_size()
	_toast.global_position = board.global_position + board.toast_point() - sz * 0.5

func _on_reset() -> void:
	if not can_reset():
		return
	Analytics.track("board_reset", {"puzzle_id": GAME})
	_fx.buzz(Haptics.TAP)
	_new_game()

func _on_back() -> void:
	if _clear_card != null:
		_close_clear()
		return
	if online != null:
		# A game in progress is resigned, and only on a yes; versus_abandon is
		# the computer's games', online's is versus_online_end (why resign).
		if online.live() and _state != State.OVER:
			online.ask_leave(_move_number())
			return
	elif _state != State.OVER and rules.ply > 0:
		Analytics.track("versus_abandon", {"game": GAME, "level": level, "moves": _move_number()})
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
	if _clear_card != null:
		_close_clear()
		return
	_on_back()
