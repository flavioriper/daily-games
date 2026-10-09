extends Control

## A game of Toy Boats: the fifth game on the Versus tab, built the way
## checkers is (versus/checkers_screen.gd). The flat boards' top bar, a
## scoreboard with the sun for you and the moon for the other player and the
## pebbles you have thrown between them, and on the wooden deck the folding
## box: your pond and your slate (versus/boats_board.gd).
##
## The game is the one sold in a box with two grids and a fleet of plastic
## ships, renamed as every genre here is; the rules (versus/boats_rules.gd)
## are that game's: ten by ten, boats of 5, 4, 3, 3 and 2 laid along a row or
## a column and never over one another, a throw a turn, miss or hit said, a
## boat named when it sinks, and the first fleet all sunk loses.
##
## A game begins with the boats being laid out (drag to move, tap to turn,
## Shuffle, Ready). Who throws first swaps every game. The other player is
## versus/boats_ai.gd at one of three levels, which sees only what a player
## would.
##
## **Level 3 is Online** (versus/online/online.gd), against a stranger or a
## friend, and it is the one game here in which the two ends do not hold the
## same position: each keeps its fleet to itself. So nothing an end is told
## can be checked when it is told. Instead each end first sends a seal of its
## fleet (`Rules.seal`: a SHA-256 of the fleet and a salt), answers are taken
## as given, and when a fleet is all sunk both show fleet and salt: one that
## does not match its seal, or does not agree with every answer that was
## given for it, is a foul. What goes over the wire is under "online" below.

signal closed

const Rules = preload("res://versus/boats_rules.gd")
const AI = preload("res://versus/boats_ai.gd")
const Board = preload("res://versus/boats_board.gd")
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
## What the phone knocks for (docs/agents/haptics.md). The board's cues ring
## for both players and are not mapped: the hand's throws knock by `_fx.buzz`.
const HAPTICS := {"hint": Haptics.GOOD, "win": Haptics.WIN, "lose": Haptics.LOSE}
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Online = preload("res://versus/online/online.gd")

const GAME := "boats"
const TITLE := "Toy Boats"
const MARGIN := 40
const GAP := 20
const SCORE_H := 128.0
const DECK_PAD := 18
const BACKDROP_BLEED := 90.0
const HINTS := 3
## Seconds: how long the computer takes to aim (and up to how much longer),
## how long your pebble is in the air before its answer, and the beat before
## the end card.
const AIM_MIN := 0.7
const AIM_MORE := 0.6
const FLIGHT := 0.45
const END_WAIT := 1.8
const TOAST_HOLD := 2.0
const LEVELS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "VS_ONLINE"]
## The room a name has on a scoreboard plate, beside its face.
const NAME_W := 250.0
## Online: with this many seconds left to lay the boats out, they are taken
## as they lie; and how long the winner's fleet is waited for after the word
## that the game is over.
const LAY_AT := 4
const SHOW_WAIT := 4.0
const BOATS := ["BTS_BOAT_0", "BTS_BOAT_1", "BTS_BOAT_2", "BTS_BOAT_3", "BTS_BOAT_4"]

## WAIT is online's: the box laid and still while the lobby looks. PLACE is
## the boats being laid out, READY (online) laid and waiting for the other
## player's, SWAP the grids changing places. YOURS to throw; FLY your pebble
## in the air; THEIRS the other player aiming; ANIM a landing being watched;
## SHOW (online) your fleet all sunk, waiting to see the winner's.
enum State { WAIT, ENTER, PLACE, READY, SWAP, YOURS, FLY, THEIRS, ANIM, SHOW, OVER }

var level := 1
var pond: RefCounted
var slate: RefCounted
var board: Control
var _deck_mesh: ArrayMesh
var _deck_key := Rect2()
var top_bar: Control
var settings_sheet: Control
## The tutorial card: the top bar's ?, the settings' How to play and the
## first play (ui/hud/screen_tutor.gd).
var tutor: RefCounted
## Whether the player throws first this game.
var first := true
var _state := State.WAIT
## Whose throw it is once play has begun.
var _mine := true
var _hints := HINTS
var _hint := -1
## True while the tutorial card is over the board.
var _held := false
var _game := 0
## The computer's pond and what it has learned of the player's.
var _their_pond: RefCounted
var _their_slate: RefCounted
## What the computer's side is waiting to do, and when: "aim" (its throw) or
## "answer" (the answer to the player's pebble at `_flying`).
var _due := ""
var _due_at := 0.0
var _flying := -1
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _fx: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween
var _end: Control
var _plates: Array = []
var _faces: Array = []
var _status: Array[Label] = []
var _names: Array[Label] = []
var _move_label: Label
## Beside the small grid: the words and buttons of laying out, then the
## heading over the boats left to sink.
var _panel: VBoxContainer
var _panel_line: Label
var _shuffle: Button
var _ready_b: Button
## The game online, when the level is Record.ONLINE; null against the
## computer (and again once the lobby's "Play the computer" is taken).
var online: Node
## The other seat's messages not taken yet: one can land while a pebble is
## still being watched.
var _inbox: Array[Dictionary] = []
## Online: this end's salt, whether its seal has gone, and the other's seal.
var _salt := ""
var _sealed := false
var _their_seal := ""
## What the other seat said the result was, for a game not yet over here.
var _online_end := ""
var _show_at := 0.0
## Whether laying out has been announced this game (Shuffle deals again).
var _told_lay := false

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
	tutor = ScreenTutor.new(self, puzzle_id(), TITLE, _hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	first = Record.last_colour(GAME) == 0
	if level == Record.ONLINE:
		_go_online()
	else:
		_new_game()
	top_bar.enter(0.0)
	Analytics.track("versus_start", {"game": GAME, "level": level})

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

	# The motto names the moon: a game online has its own.
	top_bar = FlatTopBar.new(TITLE, tr("VS_ONLINE_MOTTO" if level == Record.ONLINE else "BTS_MOTTO"), true)
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
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.add_child(inset)
	board = Board.new()
	board.name = "Board"
	board.resized.connect(func() -> void:
		deck.queue_redraw()
		_place_panel.call_deferred())
	board.aimed.connect(_on_aimed)
	board.settled.connect(_on_settled)
	board.moved.connect(func() -> void: _fx.buzz(Haptics.TAP))
	board.refused.connect(func(reason: String) -> void:
		_say(tr("BTS_TRIED") if reason == "tried" else tr("BTS_NO_ROOM")))
	inset.add_child(board)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	add_child(_fx)

	_panel = VBoxContainer.new()
	_panel.name = "Panel"
	_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_theme_constant_override("separation", 14)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel_line = Label.new()
	_panel_line.theme_type_variation = "CardBlurb"
	_panel_line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_panel_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_line.add_theme_color_override("font_color", Color("fff6e6"))
	_panel.add_child(_panel_line)
	_ready_b = Dialog.primary("check", tr("BTS_READY"))
	_ready_b.name = "Ready"
	_ready_b.pressed.connect(_on_ready)
	_panel.add_child(_ready_b)
	_shuffle = Dialog.secondary("reset", tr("BTS_SHUFFLE"))
	_shuffle.name = "Shuffle"
	_shuffle.pressed.connect(_on_shuffle)
	_panel.add_child(_shuffle)

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

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + SCORE_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The same wooden terrace snooker's table stands on, the whole height of
## the deck: planks with their joints, grain and knots, and petals and
## leaves blown into the room round the board. One mesh, built once a
## layout.
func _draw_deck(deck: Control) -> void:
	if deck.size.x <= 0.0 or board == null or board.used_rect.size.y <= 0.0:
		return
	var key := Rect2(deck.size, board.used_rect.position + board.used_rect.size)
	if _deck_mesh == null or key != _deck_key:
		_deck_key = key
		_deck_mesh = _build_deck(deck.size)
	deck.draw_mesh(_deck_mesh, null)

func _build_deck(sz: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	var radius := 36.0
	var clip := Face.Builder.round_rect(Vector2.ZERO, sz, radius)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	b.fan(clip, Color("a06d45"))
	var plank := 58.0
	var y := 0.0
	while y < sz.y:
		var h := minf(plank, sz.y - y)
		var tone := Color("b98457").lerp(Color("a06d45"), rng.randf())
		_clip_into(b, _plank_rect(Vector2(0.0, y), Vector2(sz.x, h - 3.0)), tone, clip)
		_clip_into(b, _plank_rect(Vector2(0.0, y), Vector2(sz.x, 2.0)), Color(1, 1, 1, 0.12), clip)
		var joint := rng.randf_range(0.2, 0.8) * sz.x
		_clip_into(b, _plank_rect(Vector2(joint, y + 4.0), Vector2(3.0, h - 10.0)), Color(0.3, 0.17, 0.08, 0.35), clip)
		for g in 2:
			var gy := y + h * (0.3 + 0.35 * g) + rng.randf_range(-4.0, 4.0)
			var ph := rng.randf() * TAU
			var x0 := radius + rng.randf_range(0.0, sz.x * 0.3)
			var x1 := minf(sz.x - radius, x0 + rng.randf_range(sz.x * 0.3, sz.x * 0.6))
			var pts := PackedVector2Array()
			var x := x0
			while x <= x1:
				pts.append(Vector2(x, gy + sin(x / 60.0 + ph) * 2.5))
				x += 18.0
			if pts.size() > 1:
				b.stroke(pts, 1.8, Color(0.35, 0.2, 0.1, 0.14))
		if rng.randf() < 0.3:
			var kp := Vector2(rng.randf_range(radius * 2.0, sz.x - radius * 2.0), y + h * 0.5)
			b.stroke(Face.Builder.ring(kp, 13.0, 5.5), 2.0, Color(0.35, 0.2, 0.1, 0.25), true)
		y += plank
	# the edge of the terrace falls into shade
	for k in 3:
		b.stroke(Face.Builder.round_rect(Vector2.ONE * (5.0 + k * 10.0), sz - Vector2.ONE * (10.0 + k * 20.0), radius - 5.0 - k * 10.0),
			10.0, Color(0.25, 0.12, 0.05, 0.08), true)
	# petals and leaves blown on, never under the board
	var keep_out := Rect2(board.used_rect.position + Vector2.ONE * DECK_PAD, board.used_rect.size).grow(16.0)
	var placed := 0
	var tries := 0
	while placed < 14 and tries < 300:
		tries += 1
		var p := Vector2(rng.randf_range(40.0, sz.x - 40.0), rng.randf_range(34.0, sz.y - 34.0))
		if keep_out.has_point(p):
			continue
		var ang := rng.randf() * TAU
		var pts := PackedVector2Array()
		var leaf := placed % 3 == 2
		var r := rng.randf_range(18.0, 26.0) if leaf else rng.randf_range(12.0, 17.0)
		for k in 14:
			var a := TAU * float(k) / 14.0
			var rr := r * (0.55 + 0.45 * cos(a * 0.5) * cos(a * 0.5)) if not leaf else r
			pts.append(p + Vector2(cos(a) * rr, sin(a) * rr * (0.42 if leaf else 0.6)).rotated(ang))
		var shade := PackedVector2Array()
		for q in pts:
			shade.append(q + Vector2(2.0, 3.0))
		b.polygon(shade, Color(0.3, 0.15, 0.05, 0.25))
		var col: Color = Pal.LEAF if leaf else (Pal.FLOWER_TILE if placed % 2 == 0 else Pal.FLOWER)
		b.polygon(pts, col)
		if leaf:
			b.stroke(PackedVector2Array([p - Vector2(r * 1.2, 0.0).rotated(ang), p + Vector2(r * 0.8, 0.0).rotated(ang)]), 2.0,
				Color(Pal.LEAF_DEEP, 0.7))
		placed += 1
	return b.mesh()

static func _plank_rect(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])

static func _clip_into(b: Face.Builder, pts: PackedVector2Array, col: Color, clip: PackedVector2Array) -> void:
	for piece in Geometry2D.intersect_polygons(pts, clip):
		b.polygon(piece, col)

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
		name_l.text = "SNK_YOU" if p == 0 else "SNK_BOT"
		name_l.theme_type_variation = "SheetTitle"
		name_l.horizontal_alignment = align
		var status := Label.new()
		status.theme_type_variation = "CardBlurb"
		status.horizontal_alignment = align
		words.add_child(name_l)
		words.add_child(status)
		_status.append(status)
		_names.append(name_l)
		if p == 0:
			inner.add_child(seat)
			inner.add_child(words)
		else:
			inner.add_child(words)
			inner.add_child(seat)
		_plates.append(plate)
		if p == 1:
			row.add_child(_build_move_panel())
		row.add_child(plate)
	return row

func _build_move_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 30, 10))
	panel.custom_minimum_size.x = 200
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -6)
	panel.add_child(col)
	var kicker := Label.new()
	kicker.text = "BTS_THROWS"
	kicker.theme_type_variation = "MenuKicker"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	_move_label = Label.new()
	_move_label.theme_type_variation = "DayBig"
	_move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_move_label)
	return panel

## The panel beside the small grid: what it says and holds for the state.
func _place_panel() -> void:
	if board == null or board.size.x <= 0.0:
		return
	var room: Rect2 = board.panel_rect()
	var lay := _state == State.PLACE or _state == State.ENTER
	var wait := _state == State.READY
	var play := not lay and not wait and _state != State.WAIT and _state != State.SWAP
	_panel.visible = lay or wait or play
	_ready_b.visible = lay
	_shuffle.visible = lay
	_ready_b.disabled = _state != State.PLACE
	_shuffle.disabled = _state != State.PLACE
	_panel.alignment = BoxContainer.ALIGNMENT_BEGIN if play else BoxContainer.ALIGNMENT_CENTER
	if lay:
		_panel_line.text = tr("BTS_LAY")
	elif wait:
		_panel_line.text = tr("BTS_WAITING") % online.rival()
	else:
		_panel_line.text = tr("BTS_TO_SINK")
	_panel_line.custom_minimum_size.x = room.size.x
	_panel.global_position = board.global_position + room.position
	_panel.size = room.size

## Whose throw it is, on the plates: the one to throw lit and saying so, the
## other counting its boats.
func _refresh_board() -> void:
	var playing := _state == State.YOURS or _state == State.FLY or _state == State.THEIRS or _state == State.ANIM
	for p in 2:
		var mine: bool = playing and _mine == (p == 0)
		var box := CozyTheme.lifted(Pal.SURFACE if mine else Color("f7f0e4"), 30, 10)
		if mine:
			box.border_color = Pal.ACCENT_2
			box.set_border_width_all(4)
		_plates[p].add_theme_stylebox_override("panel", box)
		_plates[p].modulate.a = 1.0 if mine or not playing else 0.82
		var left: int = (pond if p == 0 else slate).afloat()
		var line := tr("BTS_AFLOAT_ONE" if left == 1 else "BTS_AFLOAT_N") % left
		if mine:
			line = tr("BTS_YOUR_THROW") if p == 0 else tr("BTS_AIMING")
		elif _state == State.PLACE or _state == State.ENTER:
			line = tr("BTS_LAYING") if p == 0 or online != null else ""
		elif _state == State.READY:
			line = tr("BTS_IS_READY") if p == 0 else tr("BTS_LAYING")
		elif _state == State.WAIT:
			line = ""
		_status[p].text = line
		if online != null:
			# The side the match is waiting on carries its seconds.
			var on := _state != State.WAIT and _state != State.ENTER and _state != State.OVER and _state != State.SHOW \
				and _state != State.SWAP and _state != State.ANIM and _clock_mine() == (p == 0)
			online.dress(_status[p], line, on, p == 0)
	var shown := str(slate.shots)
	if _move_label.text != shown:
		_move_label.text = shown
		_move_label.pivot_offset = _move_label.size * 0.5
		if playing:
			Motion.bump(_move_label, 0.2, 0.25)
	top_bar.refresh(self)
	_place_panel()

# --- the top bar's view of this screen (FlatTopBar.refresh) ---

## No undo: a pebble thrown has told you something.
func capabilities() -> Array:
	return ["hint"]

func is_done() -> bool:
	return _state == State.OVER

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

## The bulb and Reset are the computer's games' alone: online they stay on
## the bar, greyed.
func hints_left() -> int:
	return _hints if _state == State.YOURS and online == null else 0

## The bulb's badge: the count stays up while the bulb waits its turn.
func hints_held() -> int:
	return _hints if online == null else 0

## Reset waits out a pebble in the air.
func can_reset() -> bool:
	return online == null and (_state == State.PLACE or _state == State.YOURS or _state == State.THEIRS or _state == State.OVER)

## The How to play card's pages (ui/hud/how_to_play.gd), each played on the
## box itself by ui/hud/boats_tutorial_diagram.gd. The level only changes how
## well the computer aims, so the pages are the same on all three.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/boats_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.LAY, "TUT_BOATS_LAY", tr("TUT_BOATS_LAY_BODY")],
		[Diagram.Lesson.THROW, "TUT_BOATS_THROW", tr("TUT_BOATS_THROW_BODY")],
		[Diagram.Lesson.HUNT, "TUT_BOATS_HUNT", tr("TUT_BOATS_HUNT_BODY")],
		[Diagram.Lesson.SINK, "TUT_BOATS_SINK", tr("TUT_BOATS_SINK_BODY")],
		[Diagram.Lesson.BAR, "TUT_BOATS_BAR",
			tr("TUT_BOATS_BAR_BODY_ONE") if HINTS == 1 else tr("TUT_BOATS_BAR_BODY_N") % HINTS],
	]
	var pages := []
	for step: Array in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

# --- the game ---

func _new_game() -> void:
	_lay(State.ENTER)

## A fresh box: the boats set down for laying out (ENTER), or simply there,
## for the lobby to stand over (WAIT).
func _lay(state: State) -> void:
	_game += 1
	pond = Rules.new()
	pond.lay(Rules.random_fleet(_rng, true))
	slate = Rules.new()
	_their_pond = null
	_their_slate = Rules.new()
	_inbox.clear()
	_online_end = ""
	_salt = ""
	_sealed = false
	_their_seal = ""
	_hints = HINTS
	_hint = -1
	_due = ""
	_flying = -1
	_mine = first
	_told_lay = false
	_state = state
	if _end != null:
		_end.queue_free()
		_end = null
	for f in _faces:
		f.expression = Face.Expr.HAPPY
	board.interactive = false
	board.setup(pond, slate, true, state == State.ENTER)
	_refresh_board()

func _on_settled() -> void:
	match _state:
		State.ENTER:
			_state = State.PLACE
			board.interactive = true
			if not _told_lay:
				_told_lay = true
				_say(tr("BTS_LAY_FIRST"))
			_refresh_board()
			_take_online()
		State.SWAP:
			_start_turn()
		State.ANIM:
			_after_landing()

func _on_shuffle() -> void:
	if _state != State.PLACE:
		return
	_fx.buzz(Haptics.TAP)
	pond.lay(Rules.random_fleet(_rng, true))
	board.setup(pond, slate, true, true)
	_state = State.ENTER
	board.interactive = false
	_refresh_board()

## The boats are laid. Against the computer play begins; online the seal goes
## when it is this seat's turn to send it, and play begins once both have.
func _on_ready() -> void:
	if _state != State.PLACE:
		return
	_fx.buzz(Haptics.TAP)
	_fx.cue("ready")
	board.interactive = false
	_hush()
	if online == null:
		_their_pond = Rules.new()
		_their_pond.lay(AI.fleet(level, _rng))
		_begin_play()
		return
	_state = State.READY
	_refresh_board()
	_seal_if_due()

func _begin_play() -> void:
	_state = State.SWAP
	board.begin_play()
	_refresh_board()

func _start_turn() -> void:
	if _mine:
		_state = State.YOURS
		board.interactive = true
		if slate.shots == 0:
			_say(tr("BTS_YOU_FIRST"))
	else:
		_state = State.THEIRS
		board.interactive = false
		if _their_slate.shots == 0 and pond.shots == 0:
			_say(tr("BTS_BOT_FIRST") if online == null else online.first_line())
		if online == null:
			_due = "aim"
			_due_at = _clock + AIM_MIN + _rng.randf() * AIM_MORE
		else:
			_take_online()
	_refresh_board()

## The player let go on a square of the slate: the pebble is thrown.
func _on_aimed(c: int) -> void:
	if _state != State.YOURS or slate.marks[c] != Rules.UNKNOWN:
		return
	_state = State.FLY
	_flying = c
	_hint = -1
	board.interactive = false
	board.aim(c)
	_fx.buzz(Haptics.TAP)
	_hush()
	if online == null:
		_due = "answer"
		_due_at = _clock + (0.1 if Motion.reduce else FLIGHT)
	else:
		online.send({"s": c})
	_refresh_board()

## The answer to the player's pebble: written on the slate and chalked in.
## False when it is an answer that cannot be (online: a foul).
func _hear(c: int, r: int, i: int, b: Vector3i) -> bool:
	if not slate.note(c, r, i, b):
		return false
	_flying = -1
	_state = State.ANIM
	board.answer(c, r, i)
	if r == Rules.MISS:
		_say(tr("BTS_MISS"))
	else:
		_fx.buzz(Haptics.GOOD if r == Rules.SUNK else Haptics.BUMP)
		_say(tr("BTS_SANK") % tr(BOATS[i]) if r == Rules.SUNK else tr("BTS_HIT"))
		_react(0, Face.Expr.JOY)
		_react(1, Face.Expr.WORRIED)
	_refresh_board()
	return true

## The other player's pebble at `c` of the pond: answered by the rules and
## shown landing. The answer, for whoever asked.
func _take(c: int) -> Dictionary:
	var a: Dictionary = pond.fire(c)
	if int(a.r) == Rules.NONE:
		return a
	_state = State.ANIM
	board.strike(c, a.r, a.boat)
	if int(a.r) != Rules.MISS:
		_react(1, Face.Expr.JOY)
		_react(0, Face.Expr.WORRIED)
		if int(a.r) == Rules.SUNK:
			_fx.buzz(Haptics.WARN)
			_say(tr("BTS_LOST_BOAT") % tr(BOATS[a.boat]))
	_refresh_board()
	return a

## A landing has been watched: the game is over, or the throw passes.
func _after_landing() -> void:
	if slate.all_sunk():
		if online != null:
			# The other seat's last answer came with its fleet, checked on the
			# way in; this seat shows its own and says the game is over.
			online.send({"v": [Rules.pack(pond.boats), _salt]})
		_conclude("won", "", true)
		return
	if pond.all_sunk():
		if online != null:
			_state = State.SHOW
			_show_at = _clock + SHOW_WAIT
			_refresh_board()
			_take_online()
			return
		_conclude("lost", "", false)
		return
	_mine = not _mine
	_start_turn()

## A face on the scoreboard shows `expr` for a moment.
func _react(p: int, expr: int) -> void:
	var face: Control = _faces[p]
	face.expression = expr
	var game := _game
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(face) and _game == game and _state != State.OVER:
			face.expression = Face.Expr.HAPPY)

# --- the computer ---

func _process(delta: float) -> void:
	# Nothing of the computer's happens while the tutorial card is up.
	if _held:
		return
	_clock += delta
	if online != null:
		if _state == State.SHOW and _clock >= _show_at:
			# The game was said over and the winner's fleet never came.
			_state = State.OVER
			online.foul()
		return
	if _due == "" or _clock < _due_at:
		return
	var due := _due
	_due = ""
	if due == "aim" and _state == State.THEIRS:
		var c := AI.plan(_their_slate, level, _rng)
		var a := _take(c)
		_their_slate.note(c, a.r, a.boat, pond.boats[a.boat] if int(a.r) == Rules.SUNK else Rules.HIDDEN)
	elif due == "answer" and _state == State.FLY:
		var a: Dictionary = _their_pond.fire(_flying)
		_hear(_flying, a.r, a.boat, _their_pond.boats[a.boat] if int(a.r) == Rules.SUNK else Rules.HIDDEN)

func _hold(on: bool) -> void:
	_held = on

## The bulb: the square the best of the computer's levels would throw at.
func _on_hint() -> void:
	if _state != State.YOURS or online != null:
		return
	if _hint < 0:
		if _hints <= 0:
			return
		_hints -= 1
		_hint = AI.plan(slate, 2, _rng)
		Analytics.track("hint_used", {"puzzle_id": GAME, "hints": HINTS - _hints})
	board.set_hint(_hint)
	_fx.cue("hint")
	_say(tr("BTS_HINT_LINE"))
	top_bar.refresh(self)

# --- online (level 3): what is this game's own; the rest is versus/online/online.gd ---
#
# The wire, one JSON object a message:
#   {c: seal}            each seat once, the opener first, when its boats are laid
#   {s: square}          a throw; the turn passes
#   {r: 1|2}             its answer, miss or hit; the answerer keeps the turn and throws
#   {r: 3, i, b: [x, y, d]}   sunk: which boat and how it lay
#   {r: 3, i, b, v: [fleet, salt]}   the last boat: the loser shows its fleet, and the turn passes
#   {v: [fleet, salt]}   the winner shows its own, and ends the match

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

## Looking for a player (the first time, and Find another): a still box under
## the lobby, nobody in the far seat yet.
func _on_online_seeking() -> void:
	_seat_rival("")
	_lay(State.WAIT)

## Found: both lay their boats out at once, and the seat that opens throws
## first.
func _on_online_started() -> void:
	first = online.opens()
	_seat_rival(online.opponent)
	_new_game()
	_salt = "%08x%08x%08x%08x" % [_rng.randi(), _rng.randi(), randi(), Time.get_ticks_usec() & 0xffffffff]

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

## Whether the match is waiting on this seat: to send its seal, or to throw.
func _clock_mine() -> bool:
	if _state == State.PLACE or _state == State.READY:
		return not _sealed and (first or _their_seal != "")
	return _state == State.YOURS

## This seat's seal goes once its boats are laid and it is its turn to send:
## at once for the opener, after the opener's for the other. With both seals
## out, play begins.
func _seal_if_due() -> void:
	if _state != State.READY or _sealed or not (first or _their_seal != ""):
		return
	_sealed = true
	online.send({"c": Rules.seal(pond.boats, _salt)})
	if _their_seal != "":
		_begin_play()
	else:
		_refresh_board()

func _on_online_move(d: Dictionary) -> void:
	_inbox.append(d)
	_take_online()

static func _int_of(v: Variant, lo: int, hi: int) -> int:
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return -1
	var f := float(v)
	if f != floorf(f) or f < lo or f > hi:
		return -1
	return int(f)

## A fleet shown: [packed, salt] whose seal is `seal`. Empty when it is not.
static func _shown_fleet(v: Variant, seal: String) -> Array[Vector3i]:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2 or typeof(v[0]) != TYPE_STRING or typeof(v[1]) != TYPE_STRING:
		return []
	if (v[0] as String).length() > 32 or (v[1] as String).length() > 64:
		return []
	var fleet := Rules.unpack(v[0])
	if fleet.is_empty() or Rules.seal(fleet, v[1]) != seal:
		return []
	return fleet

## Takes the other seat's next message, if the game here is where that
## message belongs: a seal while the boats are being laid, a throw when it is
## theirs to throw, an answer while this seat's pebble is in the air, a fleet
## when this one is all sunk. One that is none of those, or is not true of
## what this end knows, is a foul. A message that came early (a landing still
## being watched) waits.
func _take_online() -> void:
	if online == null or _inbox.is_empty():
		return
	if _state == State.ANIM or _state == State.SWAP or _state == State.ENTER or _state == State.OVER or _state == State.WAIT:
		return
	var d: Dictionary = _inbox.pop_front()
	var ok := false
	if _state == State.PLACE or _state == State.READY:
		# The other seat's seal: once, 64 hex characters, and from the opener
		# first.
		var c: Variant = d.get("c")
		if d.size() == 1 and typeof(c) == TYPE_STRING and (c as String).length() == 64 and (c as String).is_valid_hex_number() \
				and _their_seal == "" and (_sealed or not first):
			ok = true
			_their_seal = c
			if _sealed:
				_begin_play()
			else:
				_seal_if_due()
				_refresh_board()
	elif _state == State.THEIRS:
		var c := _int_of(d.get("s"), 0, Rules.CELLS - 1)
		if d.size() == 1 and c >= 0 and pond.marks[c] == Rules.UNKNOWN:
			ok = true
			var a := _take(c)
			var out := {"r": a.r}
			if int(a.r) == Rules.SUNK:
				var b: Vector3i = pond.boats[a.boat]
				out["i"] = a.boat
				out["b"] = [b.x, b.y, b.z]
			if pond.all_sunk():
				# The last boat: the fleet is shown, and the turn passes for the
				# winner to show theirs.
				out["v"] = [Rules.pack(pond.boats), _salt]
				online.send(out)
			else:
				online.send(out, true)
	elif _state == State.FLY:
		var r := _int_of(d.get("r"), Rules.MISS, Rules.SUNK)
		var i := -1
		var b := Rules.HIDDEN
		var keys := 1
		if r == Rules.SUNK and typeof(d.get("b")) == TYPE_ARRAY and (d.b as Array).size() == 3:
			i = _int_of(d.get("i"), 0, Rules.FLEET.size() - 1)
			b = Vector3i(_int_of(d.b[0], 0, Rules.N - 1), _int_of(d.b[1], 0, Rules.N - 1), _int_of(d.b[2], 0, 1))
			keys = 3
		# The last boat comes with the whole fleet: its seal's, and agreeing
		# with every answer on the slate once this one is written.
		var last: bool = r == Rules.SUNK and i >= 0 and slate.afloat() == 1 and not slate.sunk[i]
		var fleet: Array[Vector3i] = []
		if last:
			fleet = _shown_fleet(d.get("v"), _their_seal)
			keys = 4
		if r >= 0 and d.size() == keys and (not last or not fleet.is_empty()):
			var before: RefCounted = slate.copy()
			if before.note(_flying, r, i, b) and (not last or before.agrees(fleet)):
				ok = _hear(_flying, r, i, b)
	elif _state == State.SHOW:
		var fleet := _shown_fleet(d.get("v"), _their_seal)
		if d.size() == 1 and not fleet.is_empty() and _their_slate_agrees(fleet):
			ok = true
			_conclude("lost", "", false, fleet)
	if not ok:
		_inbox.clear()
		online.foul()
		return
	_take_online()

## Online, what this end learned of the other's pond is the slate itself.
func _their_slate_agrees(fleet: Array) -> bool:
	return slate.agrees(fleet)

## The match ended without this board ending it. A resignation, a clock or a
## player gone ends the game where it stands. "end" is the winner's word, and
## it is true only of a board whose own fleet is all sunk, where the winner's
## fleet is then waited for (`_process`); anywhere else it is a foul.
func _on_online_over(outcome: String, why: String) -> void:
	if _state == State.OVER:
		return
	if why != "end":
		_conclude(outcome, why, false)
		return
	_online_end = outcome
	if outcome != "lost" or not pond.all_sunk():
		_online_end = ""
		_state = State.OVER
		online.foul()

func _on_online_ticked() -> void:
	if _state == State.OVER or _state == State.WAIT:
		return
	# Out of time to lay the boats out: they are taken as they lie.
	if _state == State.PLACE and _clock_mine() and online.seconds(true) <= LAY_AT:
		_on_ready()
	_refresh_board()

## The lobby's "Play the computer": the level last played against it, and a
## game as if that chip had been picked.
func _play_computer() -> void:
	online.queue_free()
	online = null
	level = Record.last_bot_level(GAME)
	first = Record.last_colour(GAME) == 0
	_seat_rival("")
	for l in _status:
		l.remove_theme_color_override("font_color")
	top_bar.set_motto(tr("BTS_MOTTO"))
	Analytics.track("versus_start", {"game": GAME, "level": level})
	_new_game()
	tutor.first_play()

# --- the end ---

## The game is over: "won" or "lost". `why` is "" for a game that ended on
## the water, else what the match said ("resign", "timeout", "left").
## `mine_last` when this seat made the last move (online, the winner showing
## its fleet). `fleet` is the other player's, to chalk what was never found.
func _conclude(outcome: String, why: String, mine_last: bool, fleet: Array = []) -> void:
	_state = State.OVER
	_due = ""
	board.interactive = false
	if fleet.is_empty() and _their_pond != null:
		fleet = _their_pond.boats
	board.finish(outcome, fleet)
	_refresh_board()
	if online != null:
		online.settle(outcome, why, slate.shots, mine_last)
	else:
		Record.add(GAME, level, outcome == "won")
		Analytics.track("versus_end", {"game": GAME, "level": level, "won": outcome == "won",
			"result": outcome, "moves": slate.shots, "hints": HINTS - _hints,
			"sunk": Rules.FLEET.size() - slate.afloat(), "lost": Rules.FLEET.size() - pond.afloat(),
			"first": first})
	Ads.note_finished()
	_fx.cue("win" if outcome == "won" else "lose")
	_faces[0].expression = Face.Expr.JOY if outcome == "won" else Face.Expr.WORRIED
	_faces[1].expression = Face.Expr.JOY if outcome == "lost" else Face.Expr.WORRIED
	var game := _game
	get_tree().create_timer(0.3 if Motion.reduce else END_WAIT).timeout.connect(func() -> void:
		if _game != game or not is_inside_tree():
			return
		_end = _build_end(outcome, why)
		add_child(_end)
		Motion.appear(_end, 0.0, 1.0, 0.3)
		_celebrate(outcome == "won"))

func _build_end(outcome: String, why := "") -> Control:
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
	head.text = "BTS_WIN" if outcome == "won" else "BTS_LOSE"
	if online != null:
		head.text = online.head(outcome)
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var said := Label.new()
	if outcome == "won":
		said.text = tr("BTS_WON_IN") % slate.shots
	else:
		var left: int = slate.afloat()
		said.text = tr("BTS_LOST_LEFT_ONE" if left == 1 else "BTS_LOST_LEFT_N") % left
	# Off the water nothing was sunk to end it: the match's own reason, if it
	# has words.
	if online != null and why != "":
		said.text = online.why_line(why, outcome)
	said.visible = said.text != ""
	said.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	said.theme_type_variation = "SheetBody"
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(said)
	var line := Label.new()
	line.text = "%s  ·  %s" % [tr(LEVELS[level]), Record.record_line(GAME, level)]
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
			first = not first
			Record.set_last_colour(GAME, 0 if first else 1)
			_fx.buzz(Haptics.TAP)
			_new_game())
	var back := Dialog.secondary("chevron_left", tr("SNK_BACK"))
	back.pressed.connect(_on_back)
	Dialog.buttons(col, again, back)
	return scrim

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

## Across the gap between the two grids, where it hides no square the thumb
## is on its way to.
func _place_toast() -> void:
	_toast.reset_size()
	var at: Rect2 = board.get_global_rect()
	var room: Rect2 = board.panel_rect()
	var sz := _toast.get_combined_minimum_size()
	_toast.global_position = Vector2(at.position.x + board.used_rect.get_center().x - sz.x * 0.5,
		at.position.y + room.end.y + Board.GAP * 0.5 - sz.y * 0.5)

func _on_reset() -> void:
	if not can_reset():
		return
	Analytics.track("board_reset", {"puzzle_id": GAME})
	_fx.buzz(Haptics.TAP)
	_new_game()

func _on_back() -> void:
	if online != null:
		# A game in progress is resigned, and only on a yes; versus_abandon is
		# the computer's games', online's is versus_online_end (why resign).
		if online.live() and _state != State.OVER:
			online.ask_leave(slate.shots)
			return
	elif _state != State.OVER and slate.shots > 0:
		Analytics.track("versus_abandon", {"game": GAME, "level": level, "moves": slate.shots})
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
