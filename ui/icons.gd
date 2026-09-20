extends RefCounted

## Vector icons for the HUD: polygons and polylines in the unit square, so
## they take any colour and any size and can be tested headless. paint()
## draws one into a CanvasItem during that item's draw call.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 4.

const NAMES := ["chevron_left", "chevron_right", "undo", "reset", "bulb", "gear", "check", "leaf", "island", "help",
	"pipe_straight", "pipe_elbow", "pipe_tee", "pipe_pump", "turn", "eye", "tree", "cross", "minus", "plus",
	"calendar", "home", "trophy", "bars", "heart", "heart_line", "pencil"]
const SEGMENTS := 24
## Stroke width of polylines as a fraction of the icon's width.
const STROKE := 0.12
## The two directions a pipe's tube runs in these icons.
const RIGHT := Vector2(1.0, 0.0)
const DOWN := Vector2(0.0, 1.0)

## The geometry of one icon: {"polys": [...], "lines": [...]} and, for the
## gear, "hole". Unknown names give an empty shape.
static func shape(name: String) -> Dictionary:
	match name:
		"chevron_left":
			return {"polys": [], "lines": [PackedVector2Array([Vector2(0.62, 0.18), Vector2(0.34, 0.5), Vector2(0.62, 0.82)])]}
		"chevron_right":
			return {"polys": [], "lines": [PackedVector2Array([Vector2(0.38, 0.18), Vector2(0.66, 0.5), Vector2(0.38, 0.82)])]}
		"undo":
			return _arrow_arc(false)
		"reset":
			return _arrow_arc(true)
		"bulb":
			return _bulb()
		"gear":
			return _gear()
		"check":
			return {"polys": [], "lines": [PackedVector2Array([Vector2(0.2, 0.52), Vector2(0.42, 0.74), Vector2(0.8, 0.28)])]}
		"leaf":
			return _leaf()
		"island":
			return _island()
		"help":
			return _help()
		"pipe_straight":
			return _pipe_straight()
		"pipe_elbow":
			return _pipe_elbow()
		"pipe_tee":
			return _pipe_tee()
		"pipe_pump":
			return _pipe_pump()
		"turn":
			return _turn()
		"eye":
			return _eye()
		"tree":
			return _tree()
		"pencil":
			return _pencil()
		"minus":
			return {"polys": [], "lines": [PackedVector2Array([Vector2(0.2, 0.5), Vector2(0.8, 0.5)])]}
		"plus":
			return {"polys": [], "lines": [
				PackedVector2Array([Vector2(0.2, 0.5), Vector2(0.8, 0.5)]),
				PackedVector2Array([Vector2(0.5, 0.2), Vector2(0.5, 0.8)])]}
		"cross":
			return {"polys": [], "lines": [
				PackedVector2Array([Vector2(0.28, 0.28), Vector2(0.72, 0.72)]),
				PackedVector2Array([Vector2(0.72, 0.28), Vector2(0.28, 0.72)])]}
		"calendar":
			return _calendar()
		"home":
			return _home()
		"trophy":
			return _trophy()
		"bars":
			return _bars()
		"heart":
			return {"polys": [_heart()], "lines": []}
		"heart_line":
			return {"polys": [], "lines": [_heart()]}
	return {"polys": [], "lines": []}

## Draws `name` into `rect` on `ci` in `colour`. Call only from `ci`'s draw
## callback. `hole`, when opaque, fills the shape's hole polygon on top (the
## gear's centre takes the button's fill).
static func paint(ci: CanvasItem, name: String, rect: Rect2, colour: Color, hole := Color.TRANSPARENT) -> void:
	var s := shape(name)
	var xf := Transform2D(0.0, rect.size, 0.0, rect.position)
	for poly in s.polys:
		ci.draw_colored_polygon(xf * poly, colour)
	# A mirrored rect (negative width) flips the icon through the transform;
	# the stroke itself still has to be a positive width.
	var width := STROKE * absf(rect.size.x)
	for line in s.lines:
		ci.draw_polyline(xf * line, colour, width, true)
	if hole.a > 0.0 and s.has("hole"):
		ci.draw_colored_polygon(xf * s.hole, hole)

static func circle(centre: Vector2, radius: float, segments := SEGMENTS) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	return pts

static func arc(centre: Vector2, radius: float, from: float, to: float, segments := SEGMENTS) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := lerpf(from, to, float(i) / segments)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	return pts

## A three-quarter arc from 12 o'clock with an arrowhead at its end. Undo runs
## anticlockwise and ends at 3 o'clock; reset runs clockwise and ends at 9
## o'clock. At both ends the arc is travelling upward, so the head points up.
static func _arrow_arc(clockwise: bool) -> Dictionary:
	var c := Vector2(0.5, 0.54)
	var r := 0.3
	var start := -PI * 0.5
	var end := start + (PI * 1.5 if clockwise else -PI * 1.5)
	var a := arc(c, r, start, end)
	var tip: Vector2 = a[a.size() - 1]
	var head := PackedVector2Array([tip + Vector2(0.0, -0.2), tip + Vector2(-0.13, 0.02), tip + Vector2(0.13, 0.02)])
	return {"polys": [head], "lines": [a]}

static func _bulb() -> Dictionary:
	var glass := circle(Vector2(0.5, 0.4), 0.24)
	var neck := PackedVector2Array([Vector2(0.38, 0.6), Vector2(0.62, 0.6), Vector2(0.6, 0.78), Vector2(0.4, 0.78)])
	var base := PackedVector2Array([Vector2(0.4, 0.8), Vector2(0.6, 0.8), Vector2(0.58, 0.9), Vector2(0.42, 0.9)])
	var rays := [
		PackedVector2Array([Vector2(0.1, 0.4), Vector2(0.2, 0.4)]),
		PackedVector2Array([Vector2(0.8, 0.4), Vector2(0.9, 0.4)]),
	]
	return {"polys": [glass, neck, base], "lines": rays}

## Eight teeth on a ring: two steps out, two steps in, round the circle.
static func _gear() -> Dictionary:
	var c := Vector2(0.5, 0.5)
	var steps := 32
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		var r := 0.42 if (i % 4) < 2 else 0.32
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return {"polys": [pts], "lines": [], "hole": circle(c, 0.13)}

## Two arcs from the stem (bottom-left) to the tip (top-right) closed into one
## polygon, plus a midrib.
static func _leaf() -> Dictionary:
	var a := Vector2(0.15, 0.85)
	var b := Vector2(0.85, 0.15)
	var perp := Vector2(0.7071, 0.7071)
	var pts := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		pts.append(a.lerp(b, t) - perp * sin(t * PI) * 0.22)
	for i in SEGMENTS + 1:
		var t := 1.0 - float(i) / SEGMENTS
		pts.append(a.lerp(b, t) + perp * sin(t * PI) * 0.22)
	return {"polys": [pts], "lines": [PackedVector2Array([a, a.lerp(b, 0.85)])]}

## A low island: a mound with a round tree on it and a wave beneath.
static func _island() -> Dictionary:
	var mound := PackedVector2Array([Vector2(0.06, 0.8), Vector2(0.2, 0.64), Vector2(0.4, 0.58), Vector2(0.6, 0.58), Vector2(0.8, 0.64), Vector2(0.94, 0.8)])
	var trunk := PackedVector2Array([Vector2(0.5, 0.6), Vector2(0.5, 0.44)])
	var canopy_big := circle(Vector2(0.5, 0.3), 0.15)
	var canopy_left := circle(Vector2(0.37, 0.37), 0.11)
	var canopy_right := circle(Vector2(0.63, 0.37), 0.11)
	var wave := PackedVector2Array([Vector2(0.06, 0.9), Vector2(0.2, 0.86), Vector2(0.34, 0.9), Vector2(0.48, 0.86), Vector2(0.62, 0.9), Vector2(0.76, 0.86), Vector2(0.9, 0.9)])
	return {"polys": [mound, canopy_big, canopy_left, canopy_right], "lines": [trunk, wave]}

## A round tree on its own, for the flat day card: three lobes of crown over a
## short trunk, the island icon's tree without the island.
static func _tree() -> Dictionary:
	var trunk := PackedVector2Array([Vector2(0.44, 0.58), Vector2(0.56, 0.58), Vector2(0.56, 0.92), Vector2(0.44, 0.92)])
	var top := circle(Vector2(0.5, 0.32), 0.24)
	var left := circle(Vector2(0.32, 0.46), 0.17)
	var right := circle(Vector2(0.68, 0.46), 0.17)
	return {"polys": [trunk, top, left, right], "lines": []}

## A pencil at -45 degrees, tip to the lower left: a rounded barrel, its wood
## nib drawn as a bare outline so it reads paler than the solid barrel beside
## it (this repo's icons are one colour, so "pale" has to come from leaving a
## shape unfilled rather than a second tint), and a small filled sliver right
## at the point for the ink it lays down. The pencil is Sudoku's one new
## icon, for the pad's pencil chip -- the only mode on that screen.
static func _pencil() -> Dictionary:
	var tip := Vector2(0.13, 0.87)
	var cap := Vector2(0.82, 0.18)
	var dir := (cap - tip).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var half := 0.085
	# Where the barrel ends and the wood nib begins, and how far back from
	# the very point the last inked sliver reaches.
	var nib_base: Vector2 = tip.lerp(cap, 0.34)
	var ink_back: Vector2 = tip.lerp(cap, 0.1)
	var body := PackedVector2Array([
		nib_base + perp * half, cap + perp * half, cap - perp * half, nib_base - perp * half,
	])
	var nib := PackedVector2Array([nib_base + perp * half, tip, nib_base - perp * half, nib_base + perp * half])
	var ink_tip := PackedVector2Array([tip, ink_back + perp * half * 0.4, ink_back - perp * half * 0.4])
	return {"polys": [body, circle(cap, half, 16), ink_tip], "lines": [nib]}

## A question mark: the hook runs from 9 o'clock over the top and down into a
## short stem, with a dot beneath.
static func _help() -> Dictionary:
	var hook := arc(Vector2(0.5, 0.36), 0.18, PI, PI * 2.5, 16)
	hook.append(Vector2(0.5, 0.66))
	return {"polys": [circle(Vector2(0.5, 0.86), 0.07, 12)], "lines": [hook]}

## A pipe's open end: a short flange across the tube at `at`, so a bar reads
## as a pipe rather than a line. `dir` is the tube's own direction there.
static func _collar(at: Vector2, dir: Vector2) -> PackedVector2Array:
	var across := Vector2(-dir.y, dir.x) * 0.17
	var along := dir * 0.05
	return PackedVector2Array([at + across - along, at + across + along, at - across + along, at - across - along])

## A disc the width of the stroke, dropped on a corner or a branch: a
## polyline's segments meet in a notch there, and this fills it.
static func _joint(at: Vector2) -> PackedVector2Array:
	return circle(at, STROKE * 0.5, 12)

## A tube straight across, collared at both ends.
static func _pipe_straight() -> Dictionary:
	var a := Vector2(0.1, 0.5)
	var b := Vector2(0.9, 0.5)
	return {"polys": [_collar(a, RIGHT), _collar(b, RIGHT)], "lines": [PackedVector2Array([a, b])]}

## A tube that turns a right angle: in from the left, out at the bottom.
static func _pipe_elbow() -> Dictionary:
	var a := Vector2(0.12, 0.26)
	var corner := Vector2(0.78, 0.26)
	var b := Vector2(0.78, 0.86)
	return {
		"polys": [_collar(a, RIGHT), _collar(b, DOWN), _joint(corner)],
		"lines": [PackedVector2Array([a, corner, b])],
	}

## A tube across with a stub down from its middle.
static func _pipe_tee() -> Dictionary:
	var a := Vector2(0.1, 0.32)
	var b := Vector2(0.9, 0.32)
	var stem := Vector2(0.5, 0.32)
	var c := Vector2(0.5, 0.88)
	return {
		"polys": [_collar(a, RIGHT), _collar(b, RIGHT), _collar(c, DOWN), _joint(stem)],
		"lines": [PackedVector2Array([a, b]), PackedVector2Array([stem, c])],
	}

## A tube standing up with a barrel in the middle: the pump that pushes water
## uphill.
static func _pipe_pump() -> Dictionary:
	var a := Vector2(0.5, 0.08)
	var b := Vector2(0.5, 0.92)
	var barrel := PackedVector2Array([
		Vector2(0.3, 0.28), Vector2(0.7, 0.28), Vector2(0.82, 0.5),
		Vector2(0.7, 0.72), Vector2(0.3, 0.72), Vector2(0.18, 0.5),
	])
	return {"polys": [_collar(a, DOWN), _collar(b, DOWN), barrel], "lines": [PackedVector2Array([a, b])]}

## A quarter turn: a block with an arrow sweeping over it, coming down on the
## right the way the island swings round. The sweep stops well above the
## block -- brought any lower, the two fuse into a blob at button size.
static func _turn() -> Dictionary:
	var c := Vector2(0.5, 0.54)
	var block := PackedVector2Array([Vector2(0.3, 0.58), Vector2(0.7, 0.58), Vector2(0.7, 0.92), Vector2(0.3, 0.92)])
	var to := PI * 1.8
	var sweep := arc(c, 0.34, PI * 1.2, to)
	var end: Vector2 = sweep[sweep.size() - 1]
	# The head follows the arc's tangent where it stops, so the arrow reads as
	# still travelling rather than stuck on.
	var along := Vector2(-sin(to), cos(to))
	var across := Vector2(-along.y, along.x)
	var head := PackedVector2Array([
		end + along * 0.15, end + across * 0.11 - along * 0.02, end - across * 0.11 - along * 0.02,
	])
	return {"polys": [block, head], "lines": [sweep]}

## An almond outline with a filled pupil: hold to see through the scenery.
static func _eye() -> Dictionary:
	var a := Vector2(0.08, 0.5)
	var b := Vector2(0.92, 0.5)
	var lid := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		lid.append(a.lerp(b, t) - Vector2(0.0, sin(t * PI) * 0.27))
	for i in SEGMENTS + 1:
		var t := 1.0 - float(i) / SEGMENTS
		lid.append(a.lerp(b, t) + Vector2(0.0, sin(t * PI) * 0.27))
	return {"polys": [circle(Vector2(0.5, 0.5), 0.15)], "lines": [lid]}


# --- the first screen (ui/menu.gd) ---

## A page with two rings over it and a row of day squares: the calendar
## button beside the gear.
static func _calendar() -> Dictionary:
	var page := PackedVector2Array([Vector2(0.12, 0.22), Vector2(0.88, 0.22), Vector2(0.88, 0.9), Vector2(0.12, 0.9)])
	var rings := [
		PackedVector2Array([Vector2(0.32, 0.08), Vector2(0.32, 0.3)]),
		PackedVector2Array([Vector2(0.68, 0.08), Vector2(0.68, 0.3)]),
	]
	var band := PackedVector2Array([Vector2(0.12, 0.38), Vector2(0.88, 0.38), Vector2(0.88, 0.42), Vector2(0.12, 0.42)])
	return {"polys": [page, band], "lines": rings}

## A gable over a body: the bar's first tab.
static func _home() -> Dictionary:
	var roof := PackedVector2Array([Vector2(0.5, 0.1), Vector2(0.95, 0.52), Vector2(0.05, 0.52)])
	var body := PackedVector2Array([Vector2(0.18, 0.5), Vector2(0.82, 0.5), Vector2(0.82, 0.9), Vector2(0.18, 0.9)])
	return {"polys": [roof, body], "lines": []}

## A cup on a stem and a foot, with a handle cut out either side. Drawn as
## three filled shapes rather than a bowl with two stroked arcs: at 56 px
## the arcs came out as blobs stuck to the rim.
static func _trophy() -> Dictionary:
	var bowl := PackedVector2Array([
		Vector2(0.26, 0.1), Vector2(0.74, 0.1), Vector2(0.71, 0.4),
		Vector2(0.5, 0.58), Vector2(0.29, 0.4),
	])
	var left := PackedVector2Array([
		Vector2(0.26, 0.16), Vector2(0.12, 0.16), Vector2(0.08, 0.3),
		Vector2(0.18, 0.42), Vector2(0.3, 0.44), Vector2(0.28, 0.34),
		Vector2(0.19, 0.32), Vector2(0.18, 0.26), Vector2(0.26, 0.26),
	])
	var right := PackedVector2Array()
	for p in left:
		right.append(Vector2(1.0 - p.x, p.y))
	var stem := PackedVector2Array([Vector2(0.43, 0.56), Vector2(0.57, 0.56), Vector2(0.57, 0.76), Vector2(0.43, 0.76)])
	var foot := PackedVector2Array([Vector2(0.26, 0.76), Vector2(0.74, 0.76), Vector2(0.74, 0.9), Vector2(0.26, 0.9)])
	return {"polys": [bowl, left, right, stem, foot], "lines": []}

## Three bars rising to the right.
static func _bars() -> Dictionary:
	var out: Array = []
	for i in 3:
		var x := 0.16 + i * 0.27
		var top := 0.62 - i * 0.24
		out.append(PackedVector2Array([Vector2(x, top), Vector2(x + 0.2, top), Vector2(x + 0.2, 0.9), Vector2(x, 0.9)]))
	return {"polys": out, "lines": []}

## Two lobes over a point. Used filled on the day row and as a line for an
## empty one.
static func _heart() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var t := TAU * i / steps
		# The classic heart curve, scaled into the unit square.
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(0.5 + x / 38.0, 0.46 - y / 38.0))
	return pts
