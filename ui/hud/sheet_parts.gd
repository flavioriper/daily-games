extends RefCounted

## What every sheet and dialog shares since the HUD mock of 2026-09-28: the
## faint leaf sprigs drawn on the card (one cached mesh a card, so they cost
## one draw call), the title's badge (the sheet's icon in ink with a sprout
## growing from it), and the sprout divider. Drawings, never images.

const Pal = preload("res://core/palette.gd")
const Icons = preload("res://ui/icons.gd")
const Face = preload("res://ui/faces/face.gd")

## The sprigs' ink: the bottom pair a soft olive, the one behind the title
## barely there, the way the mock lets them sit in the paper.
const SPRIG := Color(0.62, 0.70, 0.36, 0.42)
const SPRIG_FAINT := Color(0.74, 0.66, 0.48, 0.24)
const BADGE := 76.0

## The shapes, as statics of their own so the drawings below can reach them.
class Draw:
	## One lens-shaped leaf from `base` to `tip`, `width` at its widest.
	static func leaf(b: Face.Builder, base: Vector2, tip: Vector2, width: float, colour: Color) -> void:
		var axis := tip - base
		var perp := Vector2(-axis.y, axis.x).normalized()
		var pts := PackedVector2Array()
		var n := 10
		for i in n + 1:
			var t := float(i) / n
			pts.append(base + axis * t + perp * sin(t * PI) * width * 0.5)
		for i in range(n - 1, 0, -1):
			var t := float(i) / n
			pts.append(base + axis * t - perp * sin(t * PI) * width * 0.5)
		b.polygon(pts, colour)

	## A sprig: a bending stem of `length` from `root` along `angle`, with leaves
	## paired up it and one at the tip. `bend` curls it (radians over its length).
	static func sprig(b: Face.Builder, root: Vector2, angle: float, length: float, bend: float, colour: Color, pairs := 3) -> void:
		var stem := PackedVector2Array()
		var steps := 16
		var p := root
		var heading := angle
		stem.append(p)
		for i in steps:
			heading += bend / steps
			p += Vector2(cos(heading), sin(heading)) * length / steps
			stem.append(p)
		b.stroke(stem, maxf(length * 0.025, 2.5), colour)
		var leaf_len := length * 0.36
		for k in pairs:
			var at := int(float(steps) * (0.3 + 0.55 * float(k) / maxf(pairs, 1)))
			var here: Vector2 = stem[at]
			var dir: Vector2 = (stem[mini(at + 1, steps)] - stem[at - 1]).normalized()
			for side in [-1.0, 1.0]:
				var out := dir.rotated(side * 0.95)
				var size := leaf_len * (1.0 - 0.18 * k)
				Draw.leaf(b, here, here + out * size, size * 0.56, colour)
		var tip_dir: Vector2 = (stem[steps] - stem[steps - 1]).normalized()
		Draw.leaf(b, stem[steps], stem[steps] + tip_dir * leaf_len * 0.95, leaf_len * 0.5, colour)

	## A sprout of two leaves on a short stem, its foot at `foot`, `h` tall.
	static func sprout(b: Face.Builder, foot: Vector2, h: float, colour: Color) -> void:
		var top := foot + Vector2(0.0, -h * 0.55)
		b.stroke(PackedVector2Array([foot, top]), maxf(h * 0.1, 2.5), colour)
		Draw.leaf(b, top, top + Vector2(-h * 0.5, -h * 0.34), h * 0.3, colour)
		Draw.leaf(b, top, top + Vector2(h * 0.55, -h * 0.46), h * 0.32, colour)

## The card's sprigs for a card of `size`: one rising out of each bottom
## corner and a faint one behind the title's right end.
static func decor_mesh(size: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := clampf(size.x / 1000.0, 0.6, 1.2)
	Draw.sprig(b, Vector2(34.0, size.y - 18.0) , -PI * 0.36, 150.0 * s, 0.35, SPRIG)
	Draw.sprig(b, Vector2(96.0, size.y - 14.0), -PI * 0.22, 92.0 * s, 0.3, SPRIG, 2)
	Draw.sprig(b, Vector2(size.x - 34.0, size.y - 18.0), -PI * 0.64, 150.0 * s, -0.35, SPRIG)
	Draw.sprig(b, Vector2(size.x - 96.0, size.y - 14.0), -PI * 0.78, 92.0 * s, -0.3, SPRIG, 2)
	Draw.sprig(b, Vector2(size.x - 250.0 * s, 150.0), -PI * 0.2, 130.0 * s, -0.5, SPRIG_FAINT)
	return b.mesh()

## The sheet's icon in ink with a sprout growing from its top right: the
## title's badge, after the mock's gear.
class Badge extends Control:
	var icon := ""
	var _keep: ArrayMesh

	func _init(icon_: String) -> void:
		icon = icon_
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(BADGE, BADGE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var glyph := size * 0.86
		Icons.paint(self, icon, Rect2(Vector2(0.0, size.y - glyph.y), glyph), Pal.TEXT.lightened(0.08), Pal.PAPER)
		var b := Face.Builder.new()
		Draw.sprout(b, Vector2(size.x * 0.62, size.y * 0.38), size.y * 0.5, Pal.LEAF)
		_keep = b.mesh()
		draw_mesh(_keep, null)

## A hairline either side of a small sprout: the mock's break between the
## settings and the buttons under them.
class Divider extends Control:
	var _keep: ArrayMesh

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 44.0

	func _draw() -> void:
		var y := size.y * 0.62
		var mid := size.x * 0.5
		var line := Color(Pal.LINE, 0.4)
		draw_line(Vector2(size.x * 0.08, y), Vector2(mid - 44.0, y), line, 2.0, true)
		draw_line(Vector2(mid + 44.0, y), Vector2(size.x * 0.92, y), line, 2.0, true)
		var b := Face.Builder.new()
		Draw.sprout(b, Vector2(mid, y + 8.0), 40.0, Color(Pal.LEAF, 0.55))
		_keep = b.mesh()
		draw_mesh(_keep, null)

## A settings row's icon on a tinted rounded plaque.
class Plaque extends Control:
	var icon := ""
	var tint := Color.WHITE

	func _init(icon_: String, tint_: Color, side := 80.0) -> void:
		icon = icon_
		tint = tint_
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(side, side)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = tint
		sb.set_corner_radius_all(int(size.x * 0.28))
		sb.set_border_width_all(2)
		sb.border_color = tint.darkened(0.1)
		sb.anti_aliasing_size = 1.0
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var g := size * 0.62
		Icons.paint(self, icon, Rect2((size - g) * 0.5, g), Pal.TEXT, tint)
