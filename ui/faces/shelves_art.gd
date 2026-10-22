extends RefCounted

## Four Shelves' pieces (spec docs/superpowers/specs/2026-10-22-shelves-design.md):
## a jam jar with a paper label for its word and a gingham lid, the sun halo
## of a jar picked, the dresser's empty plank, a shelf up in its colour, and
## the hearts. Everything but the hearts goes into a Face.Builder, so the
## board draws each as one cached mesh.
##
## The jars are all the same cream: a picked jar rises inside a halo, never a
## shade of its own. A shelf up takes its colour by its place in the day's
## order (most obvious first), the way the share line's squares do.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

## A shelf's colour by its place in the day, most obvious first.
const SHELF := [Color("f6d77a"), Color("a9d58f"), Color("9cc7ec"), Color("c3a9e6"), Color("f2a39b")]
const SHELF_DEEP := [Color("dcb54c"), Color("84b86a"), Color("72a5d2"), Color("9f83c9"), Color("d97c74")]
const SHELF_INK := Color("3b3028")
const GLASS := Color("fbf6ec")
const GLASS_LINE := Color("d8c8ad")
const GLASS_SHINE := Color(1, 1, 1, 0.7)
const LABEL := Color("fffdf8")
const LABEL_LINE := Color("e3d5bd")
const LID := Color("e98a86")
const LID_DEEP := Color("c86a66")
const LID_CHECK := Color(1, 1, 1, 0.45)
const PLANK := Color("c99863")
const PLANK_DEEP := Color("9f7148")

## A jar about `at`, `sz` its whole size: the lid over a glass body and a
## paper label across it, where the word goes.
static func jar(b: Face.Builder, at: Vector2, sz: Vector2) -> void:
	var w := sz.x
	var h := sz.y
	var body := Rect2(at.x - w * 0.5, at.y - h * 0.32, w, h * 0.8)
	b.fan(Face.Builder.round_rect(body.position + Vector2(0.0, h * 0.03), body.size, w * 0.16), Color(0.3, 0.2, 0.1, 0.12))
	b.fan(Face.Builder.round_rect(body.position, body.size, w * 0.16), GLASS_LINE)
	b.fan(Face.Builder.round_rect(body.position + Vector2(2.5, 2.5), body.size - Vector2(5.0, 5.0), w * 0.15), GLASS)
	# the shine down the glass's left side
	b.stroke(PackedVector2Array([Vector2(body.position.x + w * 0.1, body.position.y + h * 0.12),
		Vector2(body.position.x + w * 0.1, body.end.y - h * 0.16)]), maxf(2.0, w * 0.035), GLASS_SHINE)
	# the label
	var lab := Rect2(at.x - w * 0.44, at.y - h * 0.12, w * 0.88, h * 0.44)
	b.fan(Face.Builder.round_rect(lab.position, lab.size, h * 0.06), LABEL_LINE)
	b.fan(Face.Builder.round_rect(lab.position + Vector2(1.5, 1.5), lab.size - Vector2(3.0, 3.0), h * 0.055), LABEL)
	# the lid, gingham
	var lid := Rect2(at.x - w * 0.36, at.y - h * 0.5, w * 0.72, h * 0.2)
	b.fan(Face.Builder.round_rect(lid.position + Vector2(0.0, h * 0.02), lid.size, h * 0.05), LID_DEEP)
	b.fan(Face.Builder.round_rect(lid.position, lid.size, h * 0.05), LID)
	var step := lid.size.x / 6.0
	for i in range(1, 6, 2):
		b.polygon(_rect(lid.position.x + i * step, lid.position.y + 2.0, lid.position.x + (i + 1) * step, lid.end.y - 2.0), LID_CHECK)
	b.polygon(_rect(lid.position.x + 3.0, lid.position.y + lid.size.y * 0.38, lid.end.x - 3.0, lid.position.y + lid.size.y * 0.62), LID_CHECK)

## The sun halo behind a picked jar.
static func halo(b: Face.Builder, at: Vector2, sz: Vector2) -> void:
	var r := Rect2(at - sz * 0.5 - Vector2(10.0, 8.0), sz + Vector2(20.0, 16.0))
	b.fan(Face.Builder.round_rect(r.position, r.size, sz.x * 0.22), Color(Pal.SUN_RAY, 0.45))
	b.stroke(Face.Builder.round_rect(r.position, r.size, sz.x * 0.22), 4.0, Pal.SUN, true)

## The dresser's empty plank under a row of jars, `at` the middle of its top.
static func plank(b: Face.Builder, at: Vector2, width: float, h: float) -> void:
	var r := Rect2(at.x - width * 0.5, at.y - h * 0.3, width, h)
	b.fan(Face.Builder.round_rect(r.position + Vector2(0.0, h * 0.4), r.size, h * 0.3), PLANK_DEEP)
	b.fan(Face.Builder.round_rect(r.position, r.size, h * 0.3), PLANK)

## A shelf up: a board in shelf `g`'s colour about `at`, `sz` its size.
static func shelf(b: Face.Builder, at: Vector2, sz: Vector2, g: int) -> void:
	var c: Color = SHELF[g % SHELF.size()]
	var d: Color = SHELF_DEEP[g % SHELF_DEEP.size()]
	var r := Rect2(at - sz * 0.5, sz)
	b.fan(Face.Builder.round_rect(r.position + Vector2(0.0, sz.y * 0.06), r.size, sz.y * 0.2), d)
	b.fan(Face.Builder.round_rect(r.position, r.size, sz.y * 0.2), c)
	b.fan(Face.Builder.round_rect(r.position + Vector2(6.0, 6.0), Vector2(r.size.x - 12.0, r.size.y * 0.4), sz.y * 0.16), Color(1, 1, 1, 0.22))

## A heart drawn straight on `ci`: full, or its outline when spent.
static func draw_heart(ci: CanvasItem, at: Vector2, r: float, full: bool) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(at + Vector2(x, y) * r / 16.0)
	if full:
		ci.draw_colored_polygon(pts, Pal.HEART)
	else:
		ci.draw_polyline(pts, Color(Pal.HEART, 0.45), maxf(2.0, r * 0.14), true)

static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
