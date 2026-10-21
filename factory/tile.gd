extends RefCounted

## A tile of Factory's belt drawer: the Grove's shop tile
## (valley/grove_screen.gd's `_tile` and `_draw_tile_icon`, 2026-10-06) cut
## loose from its shop. Top to bottom: a picture on a disc, the name, a line
## where there is one, and the price on a bar along the foot. **The bar
## alone says whether the coins reach** (the sun button's own colour when
## they do, paper when they do not); nothing on a tile is ever faded, and a
## tile that cannot be bought is still pressed, to shake its head.
## Held by factory/screen.gd. Statics only: a tile is a Dictionary of its
## parts, {button, icon, name, line, pill, cost, badge, level}.

const Art = preload("res://factory/art.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")

const FILL := Color("fcf7ef")
const PAD := 12.0
const PRICE_R := 18
## How much of the disc's width a picture may take.
const FIT := 0.8

## A tile showing `Art.icon(kind)`, `tall` high with a disc of radius `disc`
## and a price bar `bar` high; `line` is its one line (a locale key), or none.
## The holder gives it its width and its `pressed`.
static func make(kind: String, title: String, tall: float, disc: float, bar: float, line := "") -> Dictionary:
	var b := Button.new()
	b.name = kind.capitalize()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = tall
	CozyTheme.lift_button(b, FILL, 28, 8)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = PAD + 2.0
	col.offset_bottom = -PAD - 4.0
	col.offset_left = PAD
	col.offset_right = -PAD
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, disc * 2.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta("kind", kind)
	icon.set_meta("on", false)
	icon.draw.connect(func() -> void: picture(icon, String(icon.get_meta("kind")), disc, bool(icon.get_meta("on"))))
	col.add_child(icon)
	# the words take what is left between the picture and the price
	var words := VBoxContainer.new()
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(words)
	var name_l := Label.new()
	name_l.text = title
	name_l.theme_type_variation = "CardTitle"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	if line == "":
		name_l.add_theme_font_size_override("font_size", 30)
	words.add_child(name_l)
	var line_l := Label.new()
	line_l.text = line
	line_l.visible = line != ""
	line_l.theme_type_variation = "CardBlurb"
	line_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_l.add_theme_font_size_override("font_size", 24)
	words.add_child(line_l)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.custom_minimum_size.y = bar
	col.add_child(pill)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	row.add_child(coin(bar * 0.62))
	var cost := Label.new()
	cost.theme_type_variation = "CardTitle"
	cost.add_theme_font_size_override("font_size", int(bar * 0.6))
	row.add_child(cost)
	# the level, on the tile's corner where it has one
	var badge := PanelContainer.new()
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_top = 8.0
	badge.offset_right = -8.0
	var bb := StyleBoxFlat.new()
	bb.bg_color = Pal.ACCENT
	bb.set_corner_radius_all(16)
	bb.content_margin_left = 12.0
	bb.content_margin_right = 12.0
	bb.content_margin_top = 0.0
	bb.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", bb)
	var level := Label.new()
	level.theme_type_variation = "Badge"
	badge.add_child(level)
	b.add_child(badge)
	return {"button": b, "icon": icon, "name": name_l, "line": line_l, "pill": pill, "cost": cost, "badge": badge, "level": level}

## The price on a tile's bar, and whether the coins reach it.
static func price(t: Dictionary, text: String, can: bool) -> void:
	(t.cost as Label).text = text
	var box := StyleBoxFlat.new()
	box.bg_color = Pal.SUN if can else Art.PRICE_OFF
	box.set_corner_radius_all(PRICE_R)
	box.content_margin_left = 10.0
	box.content_margin_right = 14.0
	if can:
		box.border_width_bottom = 5
		box.border_color = Pal.SUN_DEEP
	(t.pill as Control).add_theme_stylebox_override("panel", box)
	(t.cost as Label).add_theme_color_override("font_color", Pal.TEXT if can else Pal.TEXT_DIM)

## The level on a tile's corner; none under 1.
static func level(t: Dictionary, n: int) -> void:
	(t.badge as Control).visible = n > 0
	(t.level as Label).text = str(n)

## Whether a tile is the one picked: its disc takes the leaf's colour.
static func mark(t: Dictionary, on: bool) -> void:
	var icon: Control = t.icon
	if bool(icon.get_meta("on")) != on:
		icon.set_meta("on", on)
		icon.queue_redraw()

## The art's picture of `kind`, fitted to a disc of radius `disc` in the
## middle of `ci`: each takes the same room.
static func picture(ci: Control, kind: String, disc: float, on := false) -> void:
	var c := ci.size * 0.5
	ci.draw_circle(c, disc, Pal.LEAF_TILE if on else Pal.PARCHMENT, true, -1.0, true)
	var mesh: ArrayMesh = Art.icon(kind)
	var box := mesh.get_aabb()
	var fit := disc * 2.0 * FIT / maxf(1.0, maxf(box.size.x, box.size.y))
	var mid := Vector2(box.get_center().x, box.get_center().y)
	ci.draw_mesh(mesh, null, Transform2D(0.0, Vector2(fit, fit), 0.0, c - mid * fit))

## The coin, `side` across, for a row.
static func coin(side: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(side, side)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var s := side / 92.0
		c.draw_mesh(Art.icon("coin"), null, Transform2D(0.0, Vector2(s, s), 0.0, c.size * 0.5)))
	return c
