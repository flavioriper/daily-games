extends VBoxContainer

## The Versus tab: games played against someone rather than against the
## day's board. Snooker, chess and checkers (versus/snooker_screen.gd,
## versus/chess_screen.gd, versus/checkers_screen.gd), and the someone is the
## computer at one of three levels or, on the fourth chip, another player
## online (level Record.ONLINE; versus/online/). Its body takes the day row's
## and the grid's room, the way Stats and Streak do, under the same header
## and over the same bar.
##
## One card a game: a painted banner with the game's own drawing lying
## across it (still, so it costs meshes and no frame), the name and the
## record at the chip picked, a line, and the four chips beside Play.
## Each game remembers its own chip.
##
## Above the cards, one row: Friends, with how many of them are online now.
## It opens the Friends sheet (ui/menu/friends_sheet.gd, through `friends`),
## where a friend is asked to one of these three games. The row is one more
## child of this column, so its height comes out of the room _fit measures.
##
## Three cards are more than a short screen holds once an ad banner takes
## its share, so the tab measures the room the menu's column leaves it
## (_fit) and gives up, in turn, the lines under the names and then some of
## the pictures' height, rather than push the bar off the screen.

signal play(game: String, level: int)
## The Friends row was pressed.
signal friends

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const SunDot = preload("res://ui/sun_dot.gd")
const Record = preload("res://versus/versus_record.gd")
const Sim = preload("res://versus/snooker_sim.gd")
const Table = preload("res://versus/snooker_table.gd")
const ChessSkin = preload("res://versus/chess_skin.gd")
const Rules = preload("res://versus/chess_rules.gd")
const CheckersSkin = preload("res://versus/checkers_skin.gd")
const CheckersRules = preload("res://versus/checkers_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Social = preload("res://core/social.gd")
const SheetParts = preload("res://ui/hud/sheet_parts.gd")
const Icons = preload("res://ui/icons.gd")

const GAP := 20
const PAD := 24
const RADIUS := 36
const ART_H := 150.0
## The pictures' height once the room is short.
const ART_H_SHORT := 96.0
const CHIP_H := 84
const LEVELS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "VS_ONLINE"]
## The line under the name while the Online chip is the one picked.
const ONLINE_BLURB := "VS_ONLINE_BLURB"
const GAMES := ["snooker", "chess", "checkers"]
const NAMES := {"snooker": "Snooker", "chess": "Chess", "checkers": "Checkers"}
const BLURBS := {"snooker": "VS_SNOOKER_BLURB", "chess": "VS_CHESS_BLURB", "checkers": "VS_CHECKERS_BLURB"}
const FILL := Color("fcf7ef")
## The Friends row: its height, the plaque on it and the plaque's tint.
const FRIENDS_H := 108.0
const FRIENDS_PLAQUE := 72.0
const FRIENDS_TINT := Color("f4b8a4")
const ONLINE_INK := Color("4f8a31")
static var PLAIN := CanvasItemMaterial.new()

var _level := {}
var _chips := {}
var _record := {}
var _snooker_art: Control
var _table: Control
var _blurbs: Array[Label] = []
var _blurb := {}
var _arts: Array[Control] = []
var friends_row: Button
var _friends_sub: Label
var _friends_dot: Control
## How many friends the row last counted online.
var _friends_on := 0

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_friends_row())
	for game: String in GAMES:
		_level[game] = clampi(Record.last_level(game), 0, LEVELS.size() - 1)
		add_child(_game_card(game))

func _game_card(game: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, RADIUS, PAD))
	card.material = PLAIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(col)
	var art := Vistas.card_plate(game, Pal.ACCENT_2 if game == "snooker" else Pal.ACCENT)
	art.custom_minimum_size.y = ART_H
	# A tall phone's spare height goes to the pictures, not to a gap under
	# the cards.
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.clip_contents = true
	col.add_child(art)
	_arts.append(art)
	if game == "snooker":
		_snooker_banner(art)
	else:
		var lineup: Control = ChessLineup.new() if game == "chess" else CheckersLineup.new()
		lineup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.add_child(lineup)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var name_l := Label.new()
	name_l.text = NAMES[game]
	name_l.theme_type_variation = "CardName"
	head.add_child(name_l)
	name_l.add_child(SunDot.new(name_l))
	var rec := Label.new()
	rec.theme_type_variation = "CardBlurb"
	rec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(rec)
	_record[game] = rec
	var blurb := Label.new()
	blurb.text = BLURBS[game]
	blurb.theme_type_variation = "CardBlurb"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)
	_blurbs.append(blurb)
	_blurb[game] = blurb

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var chips: Array[Button] = []
	for i in LEVELS.size():
		var b := Button.new()
		b.text = LEVELS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = CHIP_H
		b.add_theme_font_size_override("font_size", 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick.bind(game, i))
		row.add_child(b)
		chips.append(b)
	_chips[game] = chips
	var go := IconButton.new("chevron_right", tr("VS_PLAY"), "SunButton")
	go.name = "Play_" + game
	go.custom_minimum_size = Vector2(230, CHIP_H)
	go.pressed.connect(func() -> void:
		Record.set_last_level(game, _level[game])
		play.emit(game, _level[game]))
	row.add_child(go)
	_paint_chips(game)
	return card

## The row above the cards: a plaque, Friends over a line that counts who is
## online, and a chevron. A Button whose face is drawn by its children, the
## way the settings rows are.
func _friends_row() -> Button:
	var row := Button.new()
	row.name = "Friends"
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size.y = FRIENDS_H
	row.material = PLAIN
	var up := CozyTheme.soft_button(FILL, RADIUS, false, 0)
	var down := CozyTheme.soft_button(FILL, RADIUS, true, 0)
	for st in ["normal", "hover", "focus"]:
		row.add_theme_stylebox_override(st, up)
	for st in ["pressed", "hover_pressed"]:
		row.add_theme_stylebox_override(st, down)
	row.pressed.connect(func() -> void: friends.emit())
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = PAD
	line.offset_right = -PAD
	line.add_theme_constant_override("separation", 22)
	row.add_child(line)
	line.add_child(SheetParts.Plaque.new("friends", FRIENDS_TINT, FRIENDS_PLAQUE))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -6)
	line.add_child(words)
	var title := Label.new()
	title.text = "FRIENDS_TITLE"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", CozyTheme.display(700))
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Pal.TEXT)
	words.add_child(title)
	var sub := HBoxContainer.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_constant_override("separation", 10)
	words.add_child(sub)
	# A filled dot beside the count, so "2 online" is not said by a colour.
	_friends_dot = Control.new()
	_friends_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_friends_dot.custom_minimum_size = Vector2(16, 16)
	_friends_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_friends_dot.draw.connect(func() -> void:
		_friends_dot.draw_circle(_friends_dot.size * 0.5, 7.0, Pal.GOOD, true, -1.0, true))
	sub.add_child(_friends_dot)
	_friends_sub = Label.new()
	_friends_sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_friends_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_friends_sub.theme_type_variation = "CardBlurb"
	_friends_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_friends_sub.clip_text = true
	sub.add_child(_friends_sub)
	var chevron := Control.new()
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.custom_minimum_size = Vector2(36, 36)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.draw.connect(func() -> void:
		Icons.paint(chevron, "chevron_right", Rect2(Vector2.ZERO, chevron.size), Pal.TEXT_DIM))
	line.add_child(chevron)
	friends_row = row
	return row

## The row's line: how many friends are online, by the last read of their
## presence; what to do with the row when there is nobody to count.
func _paint_friends() -> void:
	var all := Social.friends()
	_friends_on = 0
	for uid in all:
		if Social.is_online(uid):
			_friends_on += 1
	_friends_dot.visible = _friends_on > 0
	if all.is_empty():
		_friends_sub.text = tr("FRIENDS_ROW_NONE")
	elif _friends_on == 0:
		_friends_sub.text = tr("FRIENDS_ROW_AWAY")
	else:
		_friends_sub.text = tr("FRIENDS_ONLINE_ONE" if _friends_on == 1 else "FRIENDS_ONLINE_N") % _friends_on
	_friends_sub.add_theme_color_override("font_color", ONLINE_INK if _friends_on > 0 else Pal.TEXT_DIM)

## Reads the friends' presence, for a player who has friends: as the tab
## comes up, not on a clock (the sheet keeps its own while it is open).
func _read_friends() -> void:
	if not Social.started() or Social.friends().is_empty():
		return
	@warning_ignore("redundant_await")
	await Social.refresh_presence()
	_paint_friends()

func _snooker_banner(art: Control) -> void:
	_snooker_art = art
	var sim := Sim.new()
	_table = Table.new()
	_table.still = true
	_table.sim = sim
	_table.show_guide = false
	_table.aim_dir = (sim.pos[11] - sim.pos[Sim.CUE]).normalized()
	_table.power = 0.35
	art.add_child(_table)
	art.resized.connect(_lay_table)

## The table lies on its side across the banner, turned about its middle.
func _lay_table() -> void:
	var span := Vector2(Sim.W, Sim.L) + Vector2.ONE * 2.0 * (Table.CUSHION + Table.RAIL)
	var h := minf(_snooker_art.size.y - 30.0, (_snooker_art.size.x - 60.0) * span.x / span.y)
	var w := h * span.y / span.x
	_table.size = Vector2(h, w)
	_table.pivot_offset = _table.size * 0.5
	_table.rotation = -PI * 0.5
	_table.position = _snooker_art.size * 0.5 - _table.size * 0.5
	_table.queue_redraw()

func _pick(game: String, i: int) -> void:
	_level[game] = i
	Record.set_last_level(game, i)
	_paint_chips(game)

func _paint_chips(game: String) -> void:
	var chips: Array = _chips[game]
	for i in chips.size():
		var on: bool = i == _level[game]
		var b: Button = chips[i]
		var fill := Pal.SUN_TILE if on else Pal.SURFACE
		var border := Pal.ACCENT_2 if on else Pal.LINE
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, CozyTheme.chip(fill, 28, border, 4 if on else 2, state == "pressed"))
		b.add_theme_color_override("font_color", Pal.ACCENT_2 if on else Pal.TEXT)
		b.add_theme_color_override("font_hover_color", Pal.ACCENT_2 if on else Pal.TEXT)
		b.add_theme_color_override("font_pressed_color", Pal.ACCENT_2 if on else Pal.TEXT)
	(_blurb[game] as Label).text = ONLINE_BLURB if _level[game] == Record.ONLINE else BLURBS[game]
	refresh()

func refresh() -> void:
	for game: String in GAMES:
		if _record.has(game):
			(_record[game] as Label).text = Record.record_line(game, _level[game])
	_paint_friends()
	_fit.call_deferred()

func _ready() -> void:
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _fit.call_deferred())
	var outer := _outer()
	if outer != null:
		outer.resized.connect(_fit)
	Social.hub().changed.connect(_paint_friends)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_fit.call_deferred()
		_read_friends()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _friends_sub != null:
		_paint_friends()

## What does not grow when the column overflows: the menu's column sits in
## a margin container on the full-screen list, so that is what is measured
## (ui/menu.gd's _fit_grid does the same).
func _outer() -> Control:
	var parent := get_parent()
	if parent != null and parent.get_parent() is MarginContainer:
		return parent.get_parent().get_parent() as Control
	return null

## Fits the cards to the room the column leaves between the header and the
## bar: whole if they fit, else without the lines under the names, else
## with shorter pictures too.
func _fit() -> void:
	var parent := get_parent() as Control
	if parent == null or not is_visible_in_tree():
		return
	var sep := parent.get_theme_constant("separation") if parent is BoxContainer else 0
	var other := 0.0
	var shown := 0
	for c in parent.get_children():
		if c is Control and c != self and (c as Control).visible and not (c as Control).top_level:
			other += (c as Control).get_combined_minimum_size().y
			shown += 1
	var height := parent.size.y
	var outer := _outer()
	if outer != null:
		var margins := parent.get_parent() as MarginContainer
		height = outer.size.y - margins.get_theme_constant("margin_top") - margins.get_theme_constant("margin_bottom")
	var room := height - other - sep * shown
	for level in 3:
		_compact(level)
		if get_combined_minimum_size().y <= room:
			return

func _compact(level: int) -> void:
	for b in _blurbs:
		b.visible = level == 0
	for a in _arts:
		a.custom_minimum_size.y = ART_H_SHORT if level >= 2 else ART_H

## Chess's banner: the garden set lined up on a strip of lawn squares, the
## cream side facing the rose. Drawn once, with the set's own meshes.
class ChessLineup extends Control:
	const LINE := [[Rules.ROOK, 0], [Rules.KNIGHT, 0], [Rules.KING, 0], [Rules.PAWN, 0],
		[Rules.PAWN, 1], [Rules.QUEEN, 1], [Rules.BISHOP, 1], [Rules.KNIGHT, 1]]
	var _skin: RefCounted = ChessSkin.named("garden")
	## The meshes last drawn: a canvas command holds a mesh by RID, so they
	## live until the next draw replaces them.
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var n := LINE.size()
		var c := floorf(minf(size.x * 0.9 / n, size.y * 0.52))
		if c <= 0.0:
			return
		var left := (size.x - c * n) * 0.5
		var top := size.y - c * 0.95
		_keep.clear()
		var b := Face.Builder.new()
		Scenery.soft_disc(b, Vector2(size.x * 0.5, top + c * 0.55), c * n * 0.56, c * 0.5, Color(0.15, 0.1, 0.05, 0.25))
		var strip := Face.Builder.round_rect(Vector2(left - c * 0.12, top - c * 0.12), Vector2(c * n + c * 0.24, c * 0.96), c * 0.14)
		b.fan(strip, Color("6e4a2f"))
		b.fan(Face.Builder.round_rect(Vector2(left - c * 0.12, top - c * 0.14), Vector2(c * n + c * 0.24, c * 0.92), c * 0.14), Color("9c6b45"))
		for i in n:
			var at := Vector2(left + i * c, top)
			b.fan(PackedVector2Array([at, at + Vector2(c, 0), at + Vector2(c, c * 0.7), at + Vector2(0, c * 0.7)]),
				Color("a4c088") if i % 2 == 0 else Color("f5e9cf"))
		for i in n:
			var foot := Vector2(left + (i + 0.5) * c, top + c * 0.48)
			Scenery.soft_disc(b, foot, c * 0.34, c * 0.1, Color(Pal.TEXT, 0.24))
		var ground := b.mesh()
		_keep.append(ground)
		draw_mesh(ground, null)
		for i in n:
			var type: int = LINE[i][0]
			var side: int = LINE[i][1]
			var pb := Face.Builder.new()
			var face := ChessSkin.F_JOY if type == Rules.KING or type == Rules.QUEEN else ChessSkin.F_OPEN
			_skin.build(pb, type, side, c, face, 1.0 if side == 0 else -1.0)
			var foot := Vector2(left + (i + 0.5) * c, top + c * 0.48)
			var m := pb.mesh()
			_keep.append(m)
			draw_mesh(m, null, Transform2D(0.0, foot))

## Checkers' banner: a strip of the board seen from above, a king at each
## end and a cream man caught mid-leap over a worried rose one. Drawn once,
## with the set's own meshes.
class CheckersLineup extends Control:
	## [square, type, side, face, lift]
	const LINE := [[0, CheckersRules.MAN, 0, CheckersSkin.F_OPEN, 0.0], [2, CheckersRules.KING, 0, CheckersSkin.F_JOY, 0.0],
		[4, CheckersRules.MAN, 1, CheckersSkin.F_WORRY, 0.0], [3.6, CheckersRules.MAN, 0, CheckersSkin.F_BRAVE, 0.75],
		[6, CheckersRules.KING, 1, CheckersSkin.F_OPEN, 0.0]]
	var _skin: RefCounted = CheckersSkin.named("garden")
	var _keep: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var n := 8
		var c := floorf(minf(size.x * 0.9 / n, size.y * 0.5))
		if c <= 0.0:
			return
		var left := (size.x - c * n) * 0.5
		var top := size.y - c * 1.12
		_keep.clear()
		var b := Face.Builder.new()
		Scenery.soft_disc(b, Vector2(size.x * 0.5, top + c * 0.6), c * n * 0.56, c * 0.55, Color(0.15, 0.1, 0.05, 0.25))
		b.fan(Face.Builder.round_rect(Vector2(left - c * 0.12, top - c * 0.1), Vector2(c * n + c * 0.24, c * 1.2), c * 0.14), Color("6e4a2f"))
		b.fan(Face.Builder.round_rect(Vector2(left - c * 0.12, top - c * 0.12), Vector2(c * n + c * 0.24, c * 1.16), c * 0.14), Color("9c6b45"))
		for i in n:
			var at := Vector2(left + i * c, top)
			b.fan(PackedVector2Array([at, at + Vector2(c, 0), at + Vector2(c, c), at + Vector2(0, c)]),
				Color("a4c088") if i % 2 == 0 else Color("f1e1c1"))
		# the leap's arc, dotted
		for k in 9:
			var f := float(k) / 8.0
			var q := Vector2(left + (2.5 + 3.0 * f) * c, top + c * 0.5 - sin(PI * f) * c * 0.8)
			b.disc(q, c * 0.035, Color(Pal.SUN, 0.7))
		for e: Array in LINE:
			var lift: float = e[4]
			var at := Vector2(left + (float(e[0]) + 0.5) * c, top + c * 0.5)
			Scenery.soft_disc(b, at + Vector2(c * (0.05 + lift * 0.2), c * (0.08 + lift * 0.1)), c * 0.42 * (1.0 - lift * 0.2), c * 0.38 * (1.0 - lift * 0.2),
				Color(Pal.TEXT, 0.22))
		var ground := b.mesh()
		_keep.append(ground)
		draw_mesh(ground, null)
		for e: Array in LINE:
			var lift: float = e[4]
			var grow := 1.0 + 0.22 * lift
			var at := Vector2(left + (float(e[0]) + 0.5) * c, top + c * 0.5 - lift * c * 0.8)
			var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, at)
			var bb := Face.Builder.new()
			_skin.build_base(bb, e[1], e[2], c)
			var base := bb.mesh()
			var tb := Face.Builder.new()
			var gaze := Vector2i(1, 1) if lift > 0.0 else (Vector2i(1, 0) if e[2] == 0 else Vector2i(-1, -1))
			_skin.build(tb, e[1], e[2], c, e[3], gaze)
			var topm := tb.mesh()
			_keep.append(base)
			_keep.append(topm)
			draw_mesh(base, null, xf)
			draw_mesh(topm, null, Transform2D(-0.35 if lift > 0.0 else 0.0, Vector2.ONE * grow, 0.0, at))
