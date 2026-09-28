extends "res://ui/hud/sheet.gd"

## Asks which board to play before a card whose registry entry carries
## `"pick_difficulty"` opens: one row per entry in its `"levels"`, with the
## rows already finished today checked. The menu opens the host at the
## difficulty picked; tapping the scrim or the X closes the sheet and leaves
## the player on the menu.
##
## Sudoku is the first to ask (2026-09-23): easy and medium are the 6x6 mini
## and hard is the 9x9, so the choice is a different board and not a harder
## seed of one, and a player has to be able to say which.
##
## Drawn to the user's mock on 2026-09-28: each row is a tinted card -- a
## plaque (sprout, sun, cloud, moon), the level's name with its size beside
## it, a line of its own, a painted vista washed in from the right
## (`Vistas.LEVELS`) and a round go button. Insane is the night row: ink
## fill, gold rim, a sun-coloured go.

## A row was picked; the menu opens `entry` at `difficulty`.
signal chose(entry: Dictionary, difficulty: int)

const Registry = preload("res://ui/registry.gd")
const Progress = preload("res://core/progress.gd")
const Icons = preload("res://ui/icons.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const Face = preload("res://ui/faces/face.gd")

## The registry names its levels in English; these are their keys.
const LEVEL_KEYS := {"Easy": "DIFF_EASY", "Medium": "DIFF_MEDIUM", "Hard": "DIFF_HARD", "Insane": "DIFF_INSANE"}
## Each level's own line under its name, by difficulty.
const LINE_KEYS := ["DIFF_LINE_0", "DIFF_LINE_1", "DIFF_LINE_2", "DIFF_LINE_3"]

const ROW_H := 144.0
const RADIUS := 30
const PLAQUE := 92.0
const GO := 80.0
const INSET := 24.0
## Where the painting starts, as a fraction of the row's width.
const PICTURE_FROM := 0.44

## [row fill, plaque fill, plaque ink] by difficulty; 3 is the night.
const TINTS := [
	[Color("eef3e1"), Color("dcebc6"), Color("6fa246")],
	[Color("fdf0da"), Color("fde0ae"), Color("f5a623")],
	[Color("eeebf8"), Color("dcd6f4"), Color("8e86d6")],
	[Color("262a47"), Color("1a1d35"), Color("f5b83a")],
]
const NIGHT_RIM := Color("f2b63c")

var _entry: Dictionary = {}
var _title: Label
var _list: VBoxContainer

func _build_sheet(col: VBoxContainer) -> void:
	var head := _title_row(col, "", "puzzle")
	_title = title_label
	# The blurb stands under the title, not under the badge: the two are one
	# column beside it.
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.remove_child(_title)
	words.add_child(_title)
	var blurb := Label.new()
	blurb.theme_type_variation = "SheetBodyDim"
	blurb.text = "DIFF_PICK"
	words.add_child(blurb)
	head.add_child(words)
	head.move_child(words, 1)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	col.add_child(_list)
	col.add_child(SheetParts.Divider.new())

## Shows the sheet for `entry`, its rows rebuilt so each reads today's state.
func ask(entry: Dictionary) -> void:
	_entry = entry
	_title.text = String(entry.get("title", ""))
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var levels: Array = entry.get("levels", [])
	for i in levels.size():
		var level: Dictionary = levels[i]
		var d := int(level.get("difficulty", i))
		var done := Progress.completed(Registry.progress_id(entry, d))
		_list.add_child(_row(level, clampi(d, 0, 3), done, func() -> void:
			close_then(chose.emit.bind(_entry, d))))
	open()

func _row(level: Dictionary, d: int, done: bool, on_press: Callable) -> Control:
	var night := d == 3
	var tint: Array = TINTS[d]
	var fill: Color = tint[0]
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = ROW_H
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var up := _row_style(fill, night, false)
	for s in ["normal", "hover", "disabled"]:
		button.add_theme_stylebox_override(s, up)
	button.add_theme_stylebox_override("pressed", _row_style(fill, night, true))
	button.pressed.connect(on_press)
	# The painting, set into the row's right side and washed into its fill.
	var rim := 3.0 if night else 2.0
	var plate := Vistas.side_plate(Vistas.LEVELS[d], RADIUS - rim, fill)
	plate.anchor_left = PICTURE_FROM
	plate.anchor_right = 1.0
	plate.anchor_bottom = 1.0
	plate.offset_top = rim
	plate.offset_bottom = -rim
	plate.offset_right = -rim
	button.add_child(plate)
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = INSET
	box.offset_right = -(GO + INSET + 16.0)
	box.add_theme_constant_override("separation", 26)
	button.add_child(box)
	box.add_child(LevelPlaque.new(d, tint[1], tint[2]))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 0)
	box.add_child(words)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 26)
	words.add_child(top)
	var ink: Color = Pal.PAPER if night else Pal.TEXT
	var dim: Color = Color(Pal.PAPER, 0.74) if night else Pal.TEXT_DIM
	var name := Label.new()
	name.text = LEVEL_KEYS.get(String(level.get("name", "")), String(level.get("name", "")))
	name.add_theme_font_override("font", CozyTheme.display(700))
	name.add_theme_font_size_override("font_size", 42)
	name.add_theme_color_override("font_color", ink)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(name)
	# A bare size ("6 × 6") stands beside the name behind the grid's dots and
	# the level's own line goes under it; a worded one ("4 friends, may
	# repeat") is too long for beside the name and takes the line's place.
	var meta_text := tr(String(level.get("line", "")))
	var size_only := RegEx.create_from_string("^\\d+ × \\d+$").search(meta_text) != null
	if size_only:
		var meta := HBoxContainer.new()
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta.add_theme_constant_override("separation", 14)
		top.add_child(meta)
		meta.add_child(GridDots.new(dim))
		meta.add_child(_text(meta_text, dim))
	words.add_child(_text(LINE_KEYS[d] if size_only else meta_text, dim))
	var go := GoButton.new(night, done)
	go.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	go.offset_left = -GO - INSET
	go.offset_right = -INSET
	go.offset_top = -GO * 0.5
	go.offset_bottom = GO * 0.5
	button.add_child(go)
	return button

func _text(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", CozyTheme.body(600))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", colour)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _row_style(fill: Color, night: bool, pressed: bool) -> StyleBoxFlat:
	var sb := CozyTheme.soft_button(fill, RADIUS, pressed, 0)
	if night:
		sb.bg_color = fill.lightened(0.06) if pressed else fill
		sb.set_border_width_all(3)
		sb.border_color = NIGHT_RIM
		sb.shadow_color = Color(NIGHT_RIM, 0.22 if pressed else 0.34)
		sb.shadow_size = 8 if pressed else 16
		sb.shadow_offset = Vector2(0.0, 2.0 if pressed else 4.0)
	return sb

## The level's plaque: a rounded tile in its tint and the level's sign on it
## -- a sprout, a sun, a cloud, a crescent -- built into one mesh.
class LevelPlaque extends Control:
	var level := 0
	var fill := Color.WHITE
	var ink := Color.BLACK
	var _keep: ArrayMesh

	func _init(level_: int, fill_: Color, ink_: Color) -> void:
		level = level_
		fill = fill_
		ink = ink_
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(PLAQUE, PLAQUE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(int(size.x * 0.28))
		sb.set_border_width_all(2)
		sb.border_color = fill.darkened(0.08) if level < 3 else Color(1, 1, 1, 0.08)
		sb.shadow_color = Color(fill.darkened(0.4), 0.14)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0.0, 2.0)
		sb.anti_aliasing_size = 1.0
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var b := Face.Builder.new()
		var c := size * 0.5
		var u := size.x
		match level:
			0:
				SheetParts.Draw.sprout(b, c + Vector2(0.0, u * 0.3), u * 0.62, ink)
			1:
				for k in 8:
					var a := TAU * k / 8.0
					var dir := Vector2(cos(a), sin(a))
					b.stroke(PackedVector2Array([c + dir * u * 0.25, c + dir * u * 0.34]), u * 0.06, ink)
				b.polygon(Icons.circle(c, u * 0.19), ink)
				b.polygon(Icons.circle(c + Vector2(-u * 0.04, -u * 0.05), u * 0.1), ink.lightened(0.25))
			2:
				var puffs := [
					[Vector2(-0.17, 0.05), 0.12], [Vector2(0.17, 0.05), 0.12],
					[Vector2(-0.03, -0.04), 0.16], [Vector2(0.11, -0.08), 0.12],
				]
				var body := Rect2(c + Vector2(-0.17, 0.0) * u, Vector2(0.34, 0.17) * u)
				for pass_ in 2:
					var grow := u * 0.035 if pass_ == 0 else 0.0
					var colour: Color = ink if pass_ == 0 else Pal.SURFACE
					for p in puffs:
						b.polygon(Icons.circle(c + p[0] * u, p[1] * u + grow), colour)
					var r := body.grow(grow)
					b.polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), colour)
			3:
				# A crescent: the lit disc with the night's own plaque bitten
				# out of it.
				b.polygon(Icons.circle(c + Vector2(-u * 0.02, 0.0), u * 0.24), ink)
				b.polygon(Icons.circle(c + Vector2(u * 0.1, -u * 0.08), u * 0.21), fill)
		_keep = b.mesh()
		draw_mesh(_keep, null)

## A three-by-three of dots: the board's size, before the numbers say it.
class GridDots extends Control:
	var ink := Color.BLACK

	func _init(ink_: Color) -> void:
		ink = ink_
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(26.0, 26.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var step := size.x / 3.0
		for y in 3:
			for x in 3:
				var r := Rect2(Vector2(x, y) * step + Vector2.ONE, Vector2.ONE * (step - 2.0))
				draw_rect(r, ink)

## The row's round go: paper with a chevron, or a check once today's board
## at that level is done; the night row's is the sun's.
class GoButton extends Control:
	var night := false
	var done := false

	func _init(night_: bool, done_: bool) -> void:
		night = night_
		done = done_
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var face: Color = Pal.SUN if night else Pal.SURFACE
		var sb := StyleBoxFlat.new()
		sb.bg_color = face
		sb.set_corner_radius_all(int(size.x * 0.5))
		sb.set_border_width_all(2)
		sb.border_color = face.darkened(0.1)
		sb.shadow_color = Color(0.2, 0.12, 0.05, 0.3 if night else 0.18)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0.0, 3.0)
		sb.anti_aliasing_size = 1.2
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var g := size * 0.44
		var r := Rect2((size - g) * 0.5, g)
		if done:
			Icons.paint(self, "check", r, Pal.TEXT if night else Pal.LEAF_DEEP)
		else:
			Icons.paint(self, "chevron_right", r.grow_individual(-2.0, 0.0, 2.0, 0.0), Pal.TEXT)
