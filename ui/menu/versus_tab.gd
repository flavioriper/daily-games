extends VBoxContainer

## The Versus tab: games played against someone rather than against the
## day's board. Snooker and chess, and for now the someone is the computer
## (versus/snooker_screen.gd, versus/chess_screen.gd); online play is the
## plan the tab is named for. Its body takes the day row's and the grid's
## room, the way Stats and Streak do, under the same header and over the
## same bar.
##
## One card a game: a painted banner with the game's own drawing lying
## across it (still, so it costs meshes and no frame), the name and the
## record at the level picked, a line, and the three levels beside Play.
## Each game remembers its own level.

signal play(game: String, level: int)

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
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const GAP := 20
const PAD := 24
const RADIUS := 36
const ART_H := 150.0
const CHIP_H := 84
const LEVELS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD"]
const GAMES := ["snooker", "chess"]
const NAMES := {"snooker": "Snooker", "chess": "Chess"}
const BLURBS := {"snooker": "VS_SNOOKER_BLURB", "chess": "VS_CHESS_BLURB"}
const FILL := Color("fcf7ef")
static var PLAIN := CanvasItemMaterial.new()

var _level := {}
var _chips := {}
var _record := {}
var _snooker_art: Control
var _table: Control

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for game: String in GAMES:
		_level[game] = Record.last_level(game)
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
	if game == "snooker":
		_snooker_banner(art)
	else:
		var lineup := ChessLineup.new()
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
	refresh()

func refresh() -> void:
	for game: String in GAMES:
		if _record.has(game):
			(_record[game] as Label).text = Record.record_line(game, _level[game])

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
