extends RefCounted

## The centred dialogs -- the Arcade's boost card and Second chance, Posy's
## offer, Lucky Thirteen's stuck card and every Arcade and Versus end card --
## dressed like the sheets (ui/hud/sheet.gd) since 2026-09-28: the sheets'
## warm scrim, their paper (a hairline and a deep soft shadow, the leaf
## sprigs drawn on the card), the badge title, tiles on white paper, and the
## sheets' buttons -- the sun button and a white pill under it, one width, after
## the sprout divider. Statics only; each dialog keeps its own layout.

const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Pal = preload("res://core/palette.gd")
const SheetParts = preload("res://ui/hud/sheet_parts.gd")
const Motes = preload("res://ui/motes.gd")

## The sheets' scrim (sheet.gd's _ready).
const SCRIM := Color(0.22, 0.14, 0.08, 0.42)
const RADIUS := 44
const INSET := 40
## The sheets' wide primary (sheet.gd's WIDE and ROW), and the pill under it.
const WIDE := 460.0
const PRIMARY_H := 128.0
const SECONDARY_H := 104.0
const TILE_R := 28
## The round X at a head's right (sheet.gd's own size).
const X_SIZE := 84.0

## A full-rect scrim in the sheets' warm dim.
static func scrim() -> ColorRect:
	var s := ColorRect.new()
	s.color = SCRIM
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return s

## The sheets' paper: opaque, with the sprigs drawn on it. Named "Card", as
## every screen's celebrate() looks it up by that name.
static func card(width: float, inset := INSET) -> PanelContainer:
	var c := PanelContainer.new()
	c.name = "Card"
	c.custom_minimum_size.x = width
	dress(c, inset)
	return c

## Puts the sheets' paper and sprigs on a panel of the caller's own (the
## sprigs are one cached mesh, rebuilt only when the panel changes size).
static func dress(c: PanelContainer, inset := INSET) -> void:
	c.add_theme_stylebox_override("panel", CozyTheme.sheet_card(Pal.PAPER, RADIUS, inset))
	c.draw.connect(func() -> void:
		if c.get_meta("decor_size", Vector2.ZERO) != c.size:
			c.set_meta("decor_size", c.size)
			c.set_meta("decor", SheetParts.decor_mesh(c.size))
		c.draw_mesh(c.get_meta("decor"), null))

## The sheets' head: the icon badge and the title, and `trailing` (the gold
## pill) at its right when given.
static func head(key: String, icon: String, trailing: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.add_child(SheetParts.Badge.new(icon))
	var title := Label.new()
	title.theme_type_variation = "SheetTitle"
	title.text = key
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	if trailing != null:
		trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(trailing)
	return row

## The head of a card that sells for energy (the Grove's shop and its tree
## of skills): the badge and the title, the energy held on a white pill (a
## mote and a count), and a round X that calls `on_close`. Returns the head
## and the count's Label, `{head, energy}`, for the owner to write.
static func energy_head(key: String, icon: String, on_close: Callable) -> Dictionary:
	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 16)
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", tile(Pal.SURFACE, 14))
	var held := HBoxContainer.new()
	held.add_theme_constant_override("separation", 10)
	pill.add_child(held)
	held.add_child(Motes.icon(46.0))
	var energy := Label.new()
	energy.name = "Energy"
	energy.theme_type_variation = "SheetTitle"
	held.add_child(energy)
	trailing.add_child(pill)
	var x := IconButton.new("cross", "", "IconButton")
	x.name = "Close"
	x.custom_minimum_size = Vector2(X_SIZE, X_SIZE)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(X_SIZE * 0.5)
	var up := CozyTheme.soft_button(Pal.SURFACE, r, false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, r, true, 0)
	for st in ["normal", "hover", "disabled"]:
		x.add_theme_stylebox_override(st, up)
	x.add_theme_stylebox_override("pressed", down)
	x.pressed.connect(on_close)
	trailing.add_child(x)
	return {"head": head(key, icon, trailing), "energy": energy}

## A tile on the card: white paper, lifted, the gifts' and shop's rows.
static func tile(fill := Pal.SURFACE, margin := 12) -> StyleBoxFlat:
	return CozyTheme.lifted(fill, TILE_R, margin)

## The sun button a dialog ends on.
static func primary(icon: String, text: String) -> Button:
	var b := IconButton.new(icon, text, "PrimaryButton")
	b.custom_minimum_size = Vector2(WIDE, PRIMARY_H)
	return b

## The quieter way out, a white pill.
static func secondary(icon: String, text: String) -> Button:
	var b := IconButton.new(icon, text, "IconButton")
	b.custom_minimum_size = Vector2(WIDE, SECONDARY_H)
	var up := CozyTheme.soft_button(Pal.SURFACE, IconButton.SLAB_R, false, 20)
	var down := CozyTheme.soft_button(Pal.SURFACE, IconButton.SLAB_R, true, 20)
	for st in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)
	return b

## The sprout divider, then the buttons stacked and centred at one width --
## the widest one's -- so a long label in either language never leaves the
## pair ragged. `extra` goes between the divider and the buttons (a gold line).
static func buttons(col: VBoxContainer, first: Button, second: Button = null, extra: Control = null) -> VBoxContainer:
	col.add_child(SheetParts.Divider.new())
	if extra != null:
		col.add_child(extra)
	var stack := VBoxContainer.new()
	stack.name = "Buttons"
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_theme_constant_override("separation", 16)
	col.add_child(stack)
	for b: Button in [first, second]:
		if b != null:
			b.size_flags_horizontal = Control.SIZE_FILL
			stack.add_child(b)
	return stack
