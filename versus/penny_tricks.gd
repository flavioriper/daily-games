extends HBoxContainer

## Penny Drop's trick pennies: a row of three over the rack, one use each. A
## touch takes one in hand and a second puts it back; a spent one stays,
## empty, so what was played can be read. The same drawings, small, stand on
## the other player's plate (`Mini`).

signal picked(kind: int)

const Rules = preload("res://versus/penny_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Motion = preload("res://core/motion.gd")

const KINDS := [Rules.HEAVY, Rules.SPARK, Rules.TWIN]
const NAMES := {Rules.HEAVY: "PNY_HEAVY", Rules.SPARK: "PNY_SPARK", Rules.TWIN: "PNY_TWIN"}
const HIGH := 104.0
const ICON := 76.0
const RADIUS := 30

var _buttons := {}
var _icons := {}

func _init() -> void:
	add_theme_constant_override("separation", 14)
	custom_minimum_size.y = HIGH
	for kind: int in KINDS:
		var b := Button.new()
		b.name = "Trick%d" % kind
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = HIGH
		b.pressed.connect(func() -> void: picked.emit(kind))
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := Icon.new(kind, paint)
		icon.custom_minimum_size = Vector2(ICON, ICON)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var label := Label.new()
		label.text = NAMES[kind]
		label.theme_type_variation = "CardBlurb"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		b.add_child(row)
		add_child(b)
		_buttons[kind] = b
		_icons[kind] = icon
	show_stock(0, 0, false)

## What is left (a mask), what is in hand and whether a touch does anything.
func show_stock(left: int, armed: int, live: bool) -> void:
	for kind: int in KINDS:
		var has := left & kind != 0
		var b: Button = _buttons[kind]
		var on: bool = armed == kind
		var fill: StyleBoxFlat = CozyTheme.lifted(Pal.SURFACE if has else Color("efe6d6"), RADIUS, 10 if has else 2)
		if on:
			fill.bg_color = Color("fff1c9")
			fill.border_color = Pal.ACCENT_2
			fill.set_border_width_all(5)
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, fill)
		b.disabled = not (has and live) and not on
		b.modulate.a = 1.0 if has and live or on else (0.8 if has else 0.5)
		(_icons[kind] as Control).modulate.a = 1.0 if has else 0.3

func button(kind: int) -> Button:
	return _buttons[kind]

## A trick's drawing, in a box of side 2.
static func paint(b: Face.Builder, kind: int, c: Vector2, r: float) -> void:
	if kind == Rules.HEAVY:
		# an iron weight with its ring
		b.stroke(Face.Builder.ring(c + Vector2(0.0, -r * 0.62), r * 0.3, r * 0.3), r * 0.15, Color("3a3e4a"), true)
		b.fan(Face.Builder.round_rect(c + Vector2(-r * 0.74, -r * 0.42), Vector2(r * 1.48, r * 1.22), r * 0.26), Color("3a3e4a"))
		b.fan(Face.Builder.round_rect(c + Vector2(-r * 0.74, -r * 0.46), Vector2(r * 1.48, r * 1.14), r * 0.26), Color("5a5f6e"))
		b.stroke(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.26), c + Vector2(r * 0.1, -r * 0.26)]), r * 0.1, Color("8b91a3"))
	elif kind == Rules.SPARK:
		# a squib with its fuse lit
		var body := Vector2(r * 0.42, r * 1.1)
		var at := c + Vector2(-r * 0.45, -r * 0.25)
		b.fan(Face.Builder.round_rect(at, body * Vector2(1.0, 1.0), r * 0.1), Color("c8695f"))
		b.fan(Face.Builder.round_rect(at + Vector2(0.0, r * 0.3), Vector2(body.x, r * 0.2), 2.0), Color("fbeedd"))
		var tip := c + Vector2(r * 0.34, -r * 0.62)
		b.stroke(Face.Builder.bezier2(at + Vector2(body.x * 0.5, 0.0), c + Vector2(-r * 0.1, -r * 0.9), tip, 8), r * 0.09, Color("7d5334"))
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0)
			b.stroke(PackedVector2Array([tip + d * r * 0.1, tip + d * r * (0.46 if k % 2 == 0 else 0.3)]), r * 0.09, Color("f9c04a"))
		b.disc(tip, r * 0.15, Color("fff6e0"))
	else:
		# two pennies, one on the other
		for k in 2:
			var at := c + Vector2((k * 2 - 1) * r * 0.34, 0.0)
			b.disc(at + Vector2(0.0, r * 0.05), r * 0.6, Color("c47f17").darkened(0.25))
			b.disc(at, r * 0.58, Color("c47f17"))
			b.disc(at + Vector2(0.0, -r * 0.03), r * 0.47, Color("f4b23a"))
			b.stroke(Face.Builder.ring(at, r * 0.32, r * 0.32), r * 0.05, Color("d18d1c"), true)

class Icon extends Control:
	var _kind := 0
	var _mesh: ArrayMesh
	var _at := Vector2.ZERO
	var _paint: Callable

	func _init(kind: int, painter: Callable) -> void:
		_kind = kind
		_paint = painter
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if _mesh == null or _at != size:
			var b := Face.Builder.new()
			_paint.call(b, _kind, size * 0.5, minf(size.x, size.y) * 0.5)
			_mesh = b.mesh()
			_at = size
		draw_mesh(_mesh, null)

## The other player's stock on its plate: what is left is drawn, nothing else.
class Mini extends Control:
	const SIDE := 36.0
	var _left := -1
	var _mesh: ArrayMesh
	var _paint: Callable

	func _init(painter: Callable) -> void:
		_paint = painter
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(SIDE * 3.0, SIDE)

	func show_stock(left: int) -> void:
		if left == _left:
			return
		_left = left
		var b := Face.Builder.new()
		var i := 0.0
		for kind: int in KINDS:
			if left & kind != 0:
				_paint.call(b, kind, Vector2(SIDE * (i + 0.5), SIDE * 0.5), SIDE * 0.48)
				i += 1.0
		custom_minimum_size.x = SIDE * i
		_mesh = null if i == 0.0 else b.mesh()
		queue_redraw()

	func _draw() -> void:
		if _mesh != null:
			draw_mesh(_mesh, null)
