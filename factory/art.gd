extends RefCounted

## Factory's drawings: the robot floor seen from straight above (spec
## docs/superpowers/specs/2026-10-20-factory-rewired-design.md, sections 3,
## 4 and 11), drawn in the house's paper tones after the prototype
## (docs/brainstorm/concepts.html, tab "Factory · rewired"). It was the
## isometric land of plates, trees and machines until 2026-10-20; git has
## that. Every drawing is built once into a mesh and kept in a static var,
## so a screen pays one draw_mesh a thing, or one a kind through a Batch
## (ui/hud/batch.gd; CLAUDE.md, the 855 budget). Nothing here knows the sim:
## a tile is a Vector2i, a kind a String.
##
## THE TILE GRID. A point of tile space `t` (a tile's middle is tile +
## (0.5, 0.5), +x right, +y down) is seen at `at(t)` = t * TILE, in view
## units. No turn, no depth: square tiles aligned with the screen.
##   TILE                130 view units a tile.
##   at(t), tile_at(v)   tile space to view units and back (floor it for the
##                       tile).
##   flat(tile, facing)  the transform that lays a unit-square mesh (belt,
##                       ghost) on `tile`, its +x turned to DIRS[facing].
##   DIRS                [+x, +y, -x, -y] as Vector2i; a facing is its index.
##
## THE FLOOR. Laid in view units; a holder bakes the fixed part (floor,
## fixed belts, pads) into one mesh (factory/life.gd).
##   floor_mesh(cols, rows)  the ground, its (0, 0) the floor's top left
##                       corner: paper with a dot at every inner tile corner,
##                       a rim round it and its shadow on what is under.
##   pad(kind)           a station's pad about its tile's middle: "intake",
##                       "stack" (the stack of empty boxes on it), "table",
##                       "deliver", "charger" (the bay: its bolt, and the
##                       cable to the wall, CABLE tiles long to its left).
##   fixed_belt(rows, up)  the intake (down) or the deliver (up) belt down a
##                       column, its (0, 0) the column's top left: the bed and
##                       its rails. Its chevrons are `chevron()`, a row of them
##                       laid by the holder at an offset that runs
##                       (FIXED_SPEED tiles a second, CHEVRON_GAP apart).
##   water(size, round), light(size)  the wash a field lies on, fixed to the
##                       screen, and the warm light and soft frame over it.
##
## WHAT IS CARRIED, about (0, 0), in view units.
##   square()            a grey square, SQUARE across.
##   box(n)              a cardboard box seen from above, BOX across, holding
##                       `n` squares (0..4), cached per n.
##
## A ROBOT, about its middle (where `Bots.pos` puts it), in view units.
##   robot()             body and treads, the body white for a tint.
##   face(stuck)         its eyes and mouth (ui/faces/face.gd's own
##                       `face_parts`) at FACE_AT: content, puzzled ("?"),
##                       asleep ("flat") or worried ("nocell").
##   bubble(kind)        over it, the tail's tip on (0, 0): "?", "!", "wait",
##                       "flat", "nocell", "charge". Drawn at BUBBLE_AT.
##   bar(), battery_bar(f), battery_tone(f)  the charge: one white bar
##                       BAR_W long, laid by battery_bar(f) at BAR_AT (its
##                       track at f 1), tinted by battery_tone(f).
##   HELD_AT             where what it holds is drawn, HELD_SCALE.
##
## BELTS. One mesh and one material for every belt the player lays.
##   belt()              a belt tile in tile space, 0..1, travelling to +x:
##                       draw under flat(tile, facing), or as a MultiMesh of
##                       such transforms. Its UV carries where along and
##                       across the belt a point is.
##   belt_bend(mirror)   a quarter bend, the same.
##   belt_under(), belt_under_bend(corner)  the soft shade a belt lays on the
##                       floor, about its tile's middle in view units.
##   belt_material(fast), belt_run(t)  the material that draws the slats and
##                       the chevron and runs them by `time`; its clock.
##   bridge(facing), bridge_lift(along)  a bridge's deck across its belt,
##                       about the tile's middle, and how far up (view units)
##                       what crosses it is drawn.
##   ghost(w, h, ok)     a footprint's highlight in tile space: draw under
##                       flat(tile).
##   icon(kind)          96 across about (0, 0): belt, fast, bridge, coin,
##                       square, box.
##
## FIGURES. comma(), decimal(text), amount(v, comma), short(n).

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const BELT := preload("res://shaders/belt_2d.gdshader")

## The field under the floor (`water`), and the light over it.
const WATER_FAR := Color("b9e8e0")
const WATER := Color("7fd0cc")
const WATER_DEEP := Color("4ba9b3")
const RIPPLE := Color(1.0, 1.0, 1.0, 0.42)
const CAST := Color(0.09, 0.27, 0.34, 0.24)

## The floor and its pads, the prototype's tones.
const FLOOR := Color("efe8d9")
const FLOOR_DOT := Color("d8ccb6")
const FLOOR_RIM := Color("d9ccb4")
const FLOOR_RIM_DEEP := Color("bcae95")
const PANEL := Color("fffaf1")
const PAD_LINE := Color("e3d8c6")
const INK := Color("2f2a25")
const MUTED := Color("6f655b")
const BAY := Color("fff1d6")
const LIVE := Color("c68a44")
## The fixed belts' bed: dark rubber between two wooden rails.
const RUBBER := Color("5f3c25")
const RUBBER_LIT := Color("74503a")
const CHEVRON := Color("efe8d9")
## A square, and a box of card.
const SQUARE_C := Color("8f969c")
const SQUARE_LIT := Color("b2b8bd")
const SQUARE_DEEP := Color("6f767c")
const CARD := Color("c68a44")
const CARD_LIT := Color("dba862")
const CARD_INSIDE := Color("a8722f")
const CARD_INK := Color("7a4e1c")
## The charge's three tones and the track it lies on.
const CHARGE_HI := Color("4e9e62")
const CHARGE_MID := Color("e2b23a")
const CHARGE_LOW := Color("d9574a")
const TRACK := Color("cdbfa6")
## Wood, for the rails, the table and a bridge's deck.
const PLANK := Color("cfa26d")
const PLANK_DEEP := Color("a57a48")
## The coin's gold.
const GOLD := Color("f2b632")
const GOLD_DEEP := Color("c98a16")
const GOLD_HI := Color("ffe39a")
## A price bar the coins do not reach (factory/tile.gd).
const PRICE_OFF := Color("ede4d3")

const TILE := 130.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## A belt's drawing is FINE units a tile before it is scaled to one.
const FINE := 100.0
## Tiles a second the laid belts' slats run, and the fixed belts' chevrons,
## and how far apart those are (tiles).
const BELT_SPEED := 0.5
const FIXED_SPEED := 0.5
const CHEVRON_GAP := 0.5
## A pad's inset from its tile's edge, and its corner.
const PAD_IN := 7.0
const PAD_ROUND := 20.0
## How far left of the bay's middle its cable runs, in tiles: to the wall.
const CABLE := 1.5
## What is carried: a square's side, a box's.
const SQUARE := 40.0
const BOX := 70.0
## The robot's parts, about its middle.
const BODY := Vector2(68.0, 58.0)
const BODY_AT := Vector2(0.0, -8.0)
const FACE_AT := Vector2(0.0, -10.0)
const FACE_R := 26.0
const BAR_W := 56.0
const BAR_H := 10.0
const BAR_AT := Vector2(0.0, -56.0)
const BUBBLE_AT := Vector2(0.0, -64.0)
const HELD_AT := Vector2(30.0, -20.0)
const HELD_SCALE := 0.62
## How far over its belt a bridge carries what crosses it, view units.
const BRIDGE_UP := 14.0
const BRIDGE_FLAT := 0.2

static var _one := {}
static var _boxes := {}
static var _faces := {}
static var _bubbles := {}
static var _pads := {}
static var _icons := {}
static var _ghosts := {}
static var _floors := {}
static var _fixed := {}
static var _belt: ArrayMesh
static var _bends := {}
static var _under_bends := {}
static var _belt_mat: ShaderMaterial
static var _fast_mat: ShaderMaterial

# --- how the floor is seen ---

## A point of tile space, in view units.
static func at(t: Vector2) -> Vector2:
	return t * TILE

## The point of tile space under a point of the view.
static func tile_at(v: Vector2) -> Vector2:
	return v / TILE

## Lays a mesh drawn in tile space on the floor: its (0, 0)..(1, 1) on the
## tile at `tile`, turned about the tile's middle so its +x runs toward
## DIRS[facing]. A whole footprint (`ghost`) takes facing 0.
static func flat(tile: Vector2, facing := 0) -> Transform2D:
	var x := Vector2(DIRS[posmod(facing, 4)])
	var y := Vector2(DIRS[posmod(facing + 1, 4)])
	return Transform2D(x * TILE, y * TILE, (tile + Vector2(0.5, 0.5) - (x + y) * 0.5) * TILE)

# --- the floor ---

## The ground of a floor `cols` by `rows` tiles, its (0, 0) the floor's top
## left corner: the shade it throws on the field, a rim, the paper, and a
## dot at every corner where four tiles meet (the prototype's grid).
static func floor_mesh(cols: int, rows: int) -> ArrayMesh:
	var key := Vector2i(cols, rows)
	if not _floors.has(key):
		var b := Face.Builder.new()
		var size := Vector2(cols, rows) * TILE
		var rim := 12.0
		b.polygon(Face.Builder.round_rect(Vector2(-rim, -rim) + Vector2(0.0, 14.0), size + Vector2(rim, rim) * 2.0, 30.0), Color(CAST, 0.3))
		b.polygon(Face.Builder.round_rect(Vector2(-rim, -rim), size + Vector2(rim, rim) * 2.0, 30.0), FLOOR_RIM_DEEP)
		b.polygon(Face.Builder.round_rect(Vector2(-rim, -rim), size + Vector2(rim * 2.0, rim * 2.0 - 5.0), 30.0), FLOOR_RIM)
		b.polygon(Face.Builder.round_rect(Vector2.ZERO, size, 18.0), FLOOR)
		for x in range(1, cols):
			for y in range(1, rows):
				b.disc(Vector2(x, y) * TILE, 3.6, FLOOR_DOT)
		_floors[key] = b.mesh()
	return _floors[key]

## A station's pad about its tile's middle: a panel of paper with a rim,
## and what tells it apart. The bay ("charger") is warm, with its bolt, and
## its cable runs CABLE tiles left to the wall over whatever lies there.
static func pad(kind: String) -> ArrayMesh:
	if _pads.has(kind):
		return _pads[kind]
	var b := Face.Builder.new()
	var half := TILE * 0.5 - PAD_IN
	var rim := Face.Builder.round_rect(Vector2(-half, -half), Vector2(half, half) * 2.0, PAD_ROUND)
	if kind == "charger":
		# the cable first, so the pad lies over its end
		var y := 18.0
		b.stroke(PackedVector2Array([Vector2(-half + 10.0, y), Vector2(-TILE * CABLE + 8.0, y)]), 9.0, INK.lightened(0.15))
		b.stroke(PackedVector2Array([Vector2(-half + 10.0, y - 2.0), Vector2(-TILE * CABLE + 8.0, y - 2.0)]), 2.4, Color(1.0, 1.0, 1.0, 0.18), false, false)
		b.polygon(Face.Builder.round_rect(Vector2(-TILE * CABLE, y - 13.0), Vector2(16.0, 26.0), 5.0), MUTED)
	b.polygon(Face.Builder.round_rect(Vector2(-half, -half + 5.0), Vector2(half, half) * 2.0, PAD_ROUND), Color(CAST, 0.18))
	b.polygon(rim, BAY if kind == "charger" else PANEL)
	b.stroke(rim, 5.0, LIVE.lightened(0.35) if kind == "charger" else PAD_LINE, true)
	match kind:
		"charger":
			_bolt(b, Vector2(0.0, -2.0), 1.7, LIVE)
		"intake":
			# where the squares come in: a dashed square, and an arrow in from
			# the belt on the left
			var s := SQUARE * 0.5 + 6.0
			var corners: Array[Vector2] = [Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)]
			for i in 4:
				var p0: Vector2 = corners[i]
				var p1: Vector2 = corners[(i + 1) % 4]
				for k in 3:
					b.stroke(PackedVector2Array([p0.lerp(p1, 0.08 + 0.32 * k), p0.lerp(p1, 0.08 + 0.32 * k + 0.18)]), 3.0, FLOOR_DOT)
			_arrow(b, Vector2(-half + 8.0, 0.0), Vector2(-s - 8.0, 0.0), FLOOR_DOT)
		"stack":
			for i in 3:
				b.append(box(0), Transform2D(0.0, Vector2(0.0, 10.0 - 9.0 * i)))
		"table":
			var top := Face.Builder.round_rect(Vector2(-half + 8.0, -half + 8.0), Vector2(half - 8.0, half - 8.0) * 2.0, 14.0)
			b.polygon(top, PLANK)
			for k in range(1, 4):
				var y := -half + 8.0 + (half - 8.0) * 2.0 * k / 4.0
				b.stroke(PackedVector2Array([Vector2(-half + 12.0, y), Vector2(half - 12.0, y)]), 2.2, Color(PLANK_DEEP, 0.7), false, false)
			b.stroke(top, 3.0, PLANK_DEEP, true)
		"deliver":
			# out to the belt on the right, and the coin it pays
			_arrow(b, Vector2(half - 52.0, 0.0), Vector2(half - 8.0, 0.0), FLOOR_DOT)
			_coin_into(b, Vector2(-14.0, 0.0), 22.0)
	_pads[kind] = b.mesh()
	return _pads[kind]

## A belt the floor has of its own, down a column `rows` tiles long, its
## (0, 0) the column's top left: a dark bed between two wooden rails, pegs
## along them. `up` is the deliver belt, whose things go off the top; the
## end they leave by is shaded as they go under the wall. Its chevrons are
## laid over it by the holder (`chevron`).
static func fixed_belt(rows: int, up: bool) -> ArrayMesh:
	var key := Vector2i(rows, int(up))
	if not _fixed.has(key):
		var b := Face.Builder.new()
		var long := rows * TILE
		b.polygon(PackedVector2Array([Vector2(16.0, 0.0), Vector2(TILE - 16.0, 0.0), Vector2(TILE - 16.0, long), Vector2(16.0, long)]), RUBBER)
		b.polygon(PackedVector2Array([Vector2(TILE * 0.5 - 18.0, 0.0), Vector2(TILE * 0.5 + 18.0, 0.0), Vector2(TILE * 0.5 + 18.0, long), Vector2(TILE * 0.5 - 18.0, long)]), RUBBER_LIT)
		for x: float in [6.0, TILE - 18.0]:
			b.polygon(PackedVector2Array([Vector2(x, 0.0), Vector2(x + 12.0, 0.0), Vector2(x + 12.0, long), Vector2(x, long)]), PLANK_DEEP)
			b.stroke(PackedVector2Array([Vector2(x + 4.0, 0.0), Vector2(x + 4.0, long)]), 3.0, PLANK.lightened(0.16), false, false)
			for k in rows * 2:
				b.disc(Vector2(x + 6.0, (k + 0.5) * TILE * 0.5), 3.2, Color("7a5836"))
		# the way out, under the wall
		var out := 0.0 if up else long
		var into := 30.0 if up else long - 30.0
		var dark := Color(0.12, 0.07, 0.04, 0.55)
		var clear := Color(dark, 0.0)
		var v0 := b.vertex(Vector2(16.0, out), dark)
		var v1 := b.vertex(Vector2(TILE - 16.0, out), dark)
		var v2 := b.vertex(Vector2(TILE - 16.0, into), clear)
		var v3 := b.vertex(Vector2(16.0, into), clear)
		b.tri(v0, v1, v2)
		b.tri(v0, v2, v3)
		_fixed[key] = b.mesh()
	return _fixed[key]

## A fixed belt's chevron about (0, 0), pointing +y (down the screen): a
## pale V across the bed. Turned over for the deliver belt.
static func chevron() -> ArrayMesh:
	if not _one.has("chevron"):
		var b := Face.Builder.new()
		var w := TILE * 0.5 - 30.0
		b.stroke(PackedVector2Array([Vector2(-w, -9.0), Vector2(0.0, 9.0), Vector2(w, -9.0)]), 7.0, Color(CHEVRON, 0.8))
		_one["chevron"] = b.mesh()
	return _one["chevron"]

## A lightning bolt about `c`, `s` times 20 view units tall.
static func _bolt(b: Face.Builder, c: Vector2, s: float, colour: Color) -> void:
	var pts := PackedVector2Array([Vector2(3.0, -12.0), Vector2(-7.0, 2.0), Vector2(-0.5, 2.0), Vector2(-3.0, 12.0),
		Vector2(7.0, -2.0), Vector2(0.5, -2.0), Vector2(4.0, -12.0)])
	for i in pts.size():
		pts[i] = c + pts[i] * s
	b.polygon(pts, colour)

## An arrow from `a` to `b`, its head at `b`.
static func _arrow(b: Face.Builder, from: Vector2, to: Vector2, colour: Color) -> void:
	var d := (to - from).normalized()
	var side := Vector2(-d.y, d.x)
	b.stroke(PackedVector2Array([from, to]), 5.0, colour)
	b.stroke(PackedVector2Array([to - d * 12.0 + side * 11.0, to, to - d * 12.0 - side * 11.0]), 5.0, colour)

## The gold pill's coin, radius `r` about `c`.
static func _coin_into(b: Face.Builder, c: Vector2, r: float) -> void:
	b.disc(c + Vector2(0.0, r * 0.12), r, GOLD_DEEP)
	b.disc(c, r, GOLD)
	b.stroke(Face.Builder.ring(c, r * 0.72, r * 0.72), r * 0.1, GOLD_DEEP, true)
	b.stroke(PackedVector2Array([c + Vector2(0.0, -r * 0.34), c + Vector2(0.0, r * 0.34)]), r * 0.16, GOLD_DEEP)
	b.stroke(Face.Builder.arc_points(c, r * 0.86, PI * 1.1, PI * 1.45), r * 0.12, GOLD_HI)

# --- what is carried ---

## A grey square about (0, 0), SQUARE across, lit along its top.
static func square() -> ArrayMesh:
	if not _one.has("square"):
		var b := Face.Builder.new()
		_square_into(b, Vector2.ZERO, SQUARE, true)
		_one["square"] = b.mesh()
	return _one["square"]

static func _square_into(b: Face.Builder, c: Vector2, side: float, shade: bool) -> void:
	var h := side * 0.5
	if shade:
		b.polygon(Face.Builder.round_rect(c + Vector2(-h + 2.0, -h + 5.0), Vector2(side, side), side * 0.18), Color(CAST, 0.3))
	b.polygon(Face.Builder.round_rect(c - Vector2(h, h), Vector2(side, side), side * 0.18), SQUARE_DEEP)
	b.polygon(Face.Builder.round_rect(c - Vector2(h, h), Vector2(side, side - side * 0.1), side * 0.18), SQUARE_C)
	b.polygon(Face.Builder.round_rect(c - Vector2(h, h) + Vector2(side * 0.16, side * 0.12), Vector2(side * 0.68, side * 0.16), side * 0.08), SQUARE_LIT)

## A box of card seen from above about (0, 0), BOX across, its top
## open and `n` squares (0..4) in it, two by two from the top left.
static func box(n: int) -> ArrayMesh:
	n = clampi(n, 0, 4)
	if not _boxes.has(n):
		var b := Face.Builder.new()
		var h := BOX * 0.5
		b.polygon(Face.Builder.round_rect(Vector2(-h + 3.0, -h + 7.0), Vector2(BOX, BOX), 9.0), Color(CAST, 0.32))
		b.polygon(Face.Builder.round_rect(Vector2(-h, -h), Vector2(BOX, BOX), 9.0), CARD_INK)
		b.polygon(Face.Builder.round_rect(Vector2(-h + 3.0, -h + 3.0), Vector2(BOX - 6.0, BOX - 7.0), 7.0), CARD)
		b.polygon(Face.Builder.round_rect(Vector2(-h + 10.0, -h + 10.0), Vector2(BOX - 20.0, BOX - 20.0), 4.0), CARD_INSIDE)
		# the rim's lit top edge
		b.stroke(PackedVector2Array([Vector2(-h + 8.0, -h + 5.5), Vector2(h - 8.0, -h + 5.5)]), 2.4, CARD_LIT, false, false)
		var cell := (BOX - 26.0) * 0.5
		for i in n:
			var c := Vector2(-h + 13.0, -h + 13.0) + Vector2(i % 2, floori(i / 2.0)) * cell + Vector2(cell, cell) * 0.5
			_square_into(b, c, cell - 3.0, false)
		_boxes[n] = b.mesh()
	return _boxes[n]

## The mesh for an item of the sim's: a square or a box of its `n`.
static func item(it: Dictionary) -> ArrayMesh:
	return box(int(it.get("n", 0))) if String(it.get("kind", "")) == "box" else square()

# --- a robot ---

## A robot about its middle: its shade, its treads, and its body, white for
## the holder's tint, with a lamp on a short stalk. The face is `face`.
static func robot() -> ArrayMesh:
	if not _one.has("robot"):
		var b := Face.Builder.new()
		b.ellipse(Vector2(0.0, 30.0), 44.0, 12.0, Color(CAST, 0.35))
		# the treads, under the body
		b.polygon(Face.Builder.round_rect(Vector2(-40.0, 10.0), Vector2(80.0, 26.0), 10.0), INK)
		for k in 5:
			b.disc(Vector2(-28.0 + 14.0 * k, 23.0), 4.2, INK.lightened(0.28))
		# the stalk and its lamp
		var top := BODY_AT.y - BODY.y * 0.5
		b.stroke(PackedVector2Array([Vector2(0.0, top + 2.0), Vector2(0.0, top - 12.0)]), 4.0, INK)
		b.disc(Vector2(0.0, top - 14.0), 6.0, LIVE)
		var shell := Face.Builder.round_rect(BODY_AT - BODY * 0.5, BODY, 20.0)
		b.polygon(shell, Color.WHITE)
		b.polygon(Face.Builder.round_rect(BODY_AT - BODY * 0.5 + Vector2(6.0, BODY.y - 14.0), Vector2(BODY.x - 12.0, 9.0), 4.0), Color(0.86, 0.86, 0.86))
		b.stroke(shell, 4.0, INK, true)
		_one["robot"] = b.mesh()
	return _one["robot"]

## Its eyes and mouth by `stuck` (the sim's: "", "?", "flat", "nocell"),
## from the house's face builder: content, puzzled, asleep, worried.
static func face(stuck: String) -> ArrayMesh:
	if not _faces.has(stuck):
		var b := Face.Builder.new()
		var expr := Face.Expr.HAPPY
		var eye := 1.0
		match stuck:
			"?":
				expr = Face.Expr.PUZZLED
			"flat":
				expr = Face.Expr.SLEEPY
				eye = 0.1
			"nocell":
				expr = Face.Expr.WORRIED
		Face.face_parts(b, FACE_R, FACE_AT, INK, eye, expr)
		_faces[stuck] = b.mesh()
	return _faces[stuck]

## A bubble over a robot, the tip of its tail on (0, 0): white with a rim
## that says how bad it is, and in it `kind`'s mark: "?" (a loose wire), "!"
## (a node skipped), "wait" (a Release the tile will not take yet), "flat"
## (an empty cell), "nocell" (no Battery), "charge" (on the bay, filling).
static func bubble(kind: String) -> ArrayMesh:
	if _bubbles.has(kind):
		return _bubbles[kind]
	var b := Face.Builder.new()
	var wide := 74.0 if kind == "flat" or kind == "nocell" else 52.0
	var tall := 46.0
	var foot := -10.0
	var edge := PAD_LINE.darkened(0.15)
	match kind:
		"?", "flat", "nocell":
			edge = CHARGE_LOW
		"charge":
			edge = LIVE
		"!":
			edge = CHARGE_MID
	var rect := Face.Builder.round_rect(Vector2(-wide * 0.5, foot - tall), Vector2(wide, tall), 15.0)
	var tail := PackedVector2Array([Vector2(-9.0, foot - 1.0), Vector2(9.0, foot - 1.0), Vector2(0.0, 0.0)])
	b.polygon(Face.Builder.round_rect(Vector2(-wide * 0.5 - 3.5, foot - tall - 3.5), Vector2(wide + 7.0, tall + 7.0), 18.0), edge)
	b.polygon(PackedVector2Array([Vector2(-13.0, foot), Vector2(13.0, foot), Vector2(0.0, 5.0)]), edge)
	b.polygon(rect, Color.WHITE)
	b.polygon(tail, Color.WHITE)
	var c := Vector2(0.0, foot - tall * 0.5)
	match kind:
		"?":
			b.stroke(Face.Builder.arc_points(c + Vector2(0.0, -6.0), 8.0, PI, PI * 2.5), 5.0, edge)
			b.stroke(PackedVector2Array([c + Vector2(0.0, 2.0), c + Vector2(0.0, 6.0)]), 5.0, edge)
			b.disc(c + Vector2(0.0, 13.0), 3.4, edge)
		"!":
			b.stroke(PackedVector2Array([c + Vector2(0.0, -14.0), c + Vector2(0.0, 5.0)]), 6.0, INK)
			b.disc(c + Vector2(0.0, 13.0), 3.6, INK)
		"wait":
			for k in 3:
				b.disc(c + Vector2(-13.0 + 13.0 * k, 0.0), 4.4, INK)
		"charge":
			_bolt(b, c, 1.15, LIVE)
		"flat", "nocell":
			var cell := Face.Builder.round_rect(c + Vector2(-20.0, -10.0), Vector2(36.0, 20.0), 4.0)
			b.stroke(cell, 3.4, MUTED if kind == "nocell" else edge, true)
			b.polygon(Face.Builder.round_rect(c + Vector2(17.0, -5.0), Vector2(6.0, 10.0), 2.0), MUTED if kind == "nocell" else edge)
			if kind == "flat":
				b.polygon(Face.Builder.round_rect(c + Vector2(-16.0, -6.0), Vector2(5.0, 12.0), 1.5), edge)
			else:
				b.stroke(PackedVector2Array([c + Vector2(-24.0, 12.0), c + Vector2(22.0, -12.0)]), 4.0, edge)
	_bubbles[kind] = b.mesh()
	return _bubbles[kind]

## The charge bar's one mesh: white, BAR_W long from (0, 0) along +x, BAR_H
## tall about the line. Laid by `battery_bar`, tinted by `battery_tone`.
static func bar() -> ArrayMesh:
	if not _one.has("bar"):
		var b := Face.Builder.new()
		b.polygon(Face.Builder.round_rect(Vector2(0.0, -BAR_H * 0.5), Vector2(BAR_W, BAR_H), BAR_H * 0.5), Color.WHITE)
		_one["bar"] = b.mesh()
	return _one["bar"]

## Where `bar()` lies for a charge of `f` (0..1), about the bar's middle:
## its left end fixed, as long as the charge. f 1 is the track.
static func battery_bar(f: float) -> Transform2D:
	return Transform2D(0.0, Vector2(clampf(f, 0.0, 1.0), 1.0), 0.0, Vector2(-BAR_W * 0.5, 0.0))

## The tone of a charge of `f`: green over a half, yellow over a quarter,
## red under (the prototype's).
static func battery_tone(f: float) -> Color:
	return CHARGE_HI if f > 0.5 else (CHARGE_MID if f > 0.25 else CHARGE_LOW)

# --- the field ---

## The wash a field of `size` pixels lies on, its corners rounded by
## `round`: pale at the top, deep at the foot, the clouds of a slow sky lying
## soft on it and the light on a ripple here and there. It is drawn fixed to
## the screen while the floor pans and zooms over it, so nothing in it has a
## place.
static func water(size: Vector2, round := 36.0) -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, size, round), WATER_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, Vector2(size.x, minf(size.y, 90.0)), round), WATER_FAR)
	if size.y > 100.0:
		var rows := [[40.0, WATER_FAR], [lerpf(40.0, size.y - 40.0, 0.5), WATER], [size.y - 40.0, WATER_DEEP]]
		for i in 2:
			var v0 := b.vertex(Vector2(0.0, rows[i][0]), rows[i][1])
			var v1 := b.vertex(Vector2(size.x, rows[i][0]), rows[i][1])
			var v2 := b.vertex(Vector2(size.x, rows[i + 1][0]), rows[i + 1][1])
			var v3 := b.vertex(Vector2(0.0, rows[i + 1][0]), rows[i + 1][1])
			b.tri(v0, v1, v2)
			b.tri(v0, v2, v3)
	var u := size.x / 1040.0
	for i in 7:
		var c := Vector2(rng.randf_range(size.x * 0.1, size.x * 0.9), rng.randf_range(size.y * 0.06, size.y * 0.94))
		var s := rng.randf_range(0.7, 1.3) * u
		for o: Array in [[0, 0, 190, 44], [-120, 12, 130, 30], [130, 14, 140, 32], [30, -20, 110, 30]]:
			_glow(b, c + Vector2(o[0], o[1]) * s, float(o[2]) * s, float(o[3]) * s, Color.WHITE, 0.13)
	for i in 22:
		var c := Vector2(rng.randf_range(30.0, size.x - 90.0), rng.randf_range(24.0, size.y - 24.0))
		var long := rng.randf_range(18.0, 46.0)
		b.stroke(PackedVector2Array([c, c + Vector2(long, 0.0)]), 3.2, Color(RIPPLE, rng.randf_range(0.14, 0.34)))
	return b.mesh()

## A patch of soft colour: `alpha` at its middle, nothing at its edge.
static func _glow(b: Face.Builder, c: Vector2, rx: float, ry: float, colour: Color, alpha: float) -> void:
	var n := 28
	var mid := b.vertex(c, Color(colour, alpha))
	var first := b.verts.size()
	for ring: Array in [[0.55, alpha * 0.48], [1.0, 0.0]]:
		for i in n:
			var a := TAU * i / n
			b.vertex(c + Vector2(cos(a) * rx, sin(a) * ry) * float(ring[0]), Color(colour, ring[1]))
	for i in n:
		var j := (i + 1) % n
		b.tri(mid, first + i, first + j)
		b.tri(first + i, first + n + i, first + n + j)
		b.tri(first + i, first + n + j, first + j)

## What lies over the floor: warm light from where the sun is,
## and the frame falling away a little toward its edges. One mesh for a
## field of `size`.
static func light(size: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	_glow(b, Vector2(size.x * 0.14, size.y * 0.08), size.length() * 0.8, size.length() * 0.8, Color(1.0, 0.9, 0.64), 0.2)
	var rim := Face.Builder.round_rect(Vector2.ZERO, size, 36.0)
	var centre := size * 0.5
	var start := b.verts.size()
	for p: Vector2 in rim:
		b.vertex(p, Color(0.07, 0.26, 0.33, 0.15))
		b.vertex(centre + (p - centre) * 0.66, Color(0.07, 0.26, 0.33, 0.0))
	var m := rim.size()
	for i in m:
		var j := (i + 1) % m
		b.tri(start + i * 2, start + j * 2, start + j * 2 + 1)
		b.tri(start + i * 2, start + j * 2 + 1, start + i * 2 + 1)
	return b.mesh()

# --- belts ---

## A belt's drawing, FINE units a tile, travelling to +x, through `xf`: the
## bed, a rail down each side with its pegs. `painted` draws the slats and
## the chevron too, where no shader will (the drawer's picture). Returns how
## many of the builder's vertices are the bed's: they come first.
static func _belt_into(b: Face.Builder, xf: Transform2D, painted: bool) -> int:
	var bed := Color("d6ad78")
	b.polygon(xf * PackedVector2Array([Vector2(0.0, 13.0), Vector2(FINE, 13.0), Vector2(FINE, 87.0), Vector2(0.0, 87.0)]), bed)
	var count := b.verts.size()
	if painted:
		for k in 4:
			var x := 25.0 * k + 1.0
			b.stroke(xf * PackedVector2Array([Vector2(x, 17.0), Vector2(x, 83.0)]), 2.2, Color(bed.darkened(0.3), 0.9), false, false)
		for side: float in [-1.0, 1.0]:
			b.stroke(xf * PackedVector2Array([Vector2(44.0, 50.0 + side * 22.0), Vector2(62.0, 50.0)]), 3.4, Color(1.0, 0.96, 0.84, 0.75))
	for y: float in [5.0, 84.0]:
		b.polygon(xf * PackedVector2Array([Vector2(0.0, y), Vector2(FINE, y), Vector2(FINE, y + 11.0), Vector2(0.0, y + 11.0)]), PLANK_DEEP)
		b.stroke(xf * PackedVector2Array([Vector2(0.0, y + 4.0), Vector2(FINE, y + 4.0)]), 3.0, PLANK.lightened(0.16), false, false)
		for x: float in [25.0, 75.0]:
			b.fan(xf * Face.Builder.ring(Vector2(x, y + 5.5), 3.4, 3.4), Color("7a5836"))
	return count

## One belt tile in tile space, (0, 0) to (1, 1), travelling toward +x: a
## bed of wooden slats between two rails. Flat, and any turn of it is right;
## it lies over `belt_under`. Drawn under `flat(tile, facing)` with
## `belt_material()`, by draw_mesh or as the instances of one MultiMesh for
## the whole floor. Its UV says where on the belt a point is
## (x along the travel, y across; -1 across on the rails, which do not
## run): the material draws the slats and a chevron from it and scrolls
## them, so nothing is rebuilt and no instance needs a value of its own.
static func belt() -> ArrayMesh:
	if _belt == null:
		var b := Face.Builder.new()
		var bed := _belt_into(b, Transform2D.IDENTITY, false)
		var uvs := PackedVector2Array()
		uvs.resize(b.verts.size())
		for i in b.verts.size():
			b.verts[i] /= FINE
			uvs[i] = Vector2(b.verts[i].x, b.verts[i].y if i < bed else -1.0)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b.verts
		arrays[Mesh.ARRAY_COLOR] = b.cols
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = b.idx
		_belt = ArrayMesh.new()
		_belt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _belt

## A belt tile that turns a quarter, in tile space like `belt()` and leaving
## toward +x: fed from its side (the user, 2026-10-10: "make sure to
## properly add a curve when changing direction"). It comes in at the middle
## of its +y side and sweeps round the corner (1, 1) to the middle of its +x
## side; `mirror` comes in by the -y side instead, round (1, 0). Bed, rails
## and pegs follow the arc and meet a neighbour's at the tile's edges, where
## they are a straight belt's. Its UV runs ALONG THE ARC (x from 0 where it
## comes in to 1 where it leaves, y across as on a straight belt, -1 on the
## rails), so the one material runs the slats and the chevron round the bend.
static func belt_bend(mirror: bool) -> ArrayMesh:
	if not _bends.has(mirror):
		var b := Face.Builder.new()
		var bed := Color("d6ad78")
		var c := Vector2(FINE, FINE)
		var n := 16
		var uvs := PackedVector2Array()
		for i in n + 1:
			var a := PI + PI * 0.5 * i / n
			var dir := Vector2(cos(a), sin(a))
			b.vertex(c + dir * 13.0, bed)
			b.vertex(c + dir * 87.0, bed)
			uvs.append(Vector2(float(i) / n, 0.87))
			uvs.append(Vector2(float(i) / n, 0.13))
		for i in n:
			b.tri(i * 2, i * 2 + 1, i * 2 + 3)
			b.tri(i * 2, i * 2 + 3, i * 2 + 2)
		for r: float in [89.5, 10.5]:
			var arc := PackedVector2Array()
			var lit := PackedVector2Array()
			for i in n + 1:
				var a := PI + PI * 0.5 * i / n
				arc.append(c + Vector2(cos(a), sin(a)) * r)
				lit.append(c + Vector2(cos(a), sin(a)) * (r + 1.5))
			b.stroke(arc, 11.0, PLANK_DEEP, false, false)
			b.stroke(lit, 3.0, PLANK.lightened(0.16), false, false)
			for k: float in [0.25, 0.75]:
				var a := PI + PI * 0.5 * k
				b.fan(Face.Builder.ring(c + Vector2(cos(a), sin(a)) * r, 3.4, 3.4), Color("7a5836"))
		uvs.resize(b.verts.size())
		for i in b.verts.size():
			if i >= (n + 1) * 2:
				uvs[i] = Vector2(0.0, -1.0)
			if mirror:
				b.verts[i].y = FINE - b.verts[i].y
			b.verts[i] /= FINE
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b.verts
		arrays[Mesh.ARRAY_COLOR] = b.cols
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = b.idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_bends[mirror] = m
	return _bends[mirror]

## The soft shade a straight belt lays on the floor, in view units about the
## middle of its tile; the same at every facing, so one MultiMesh of it lies
## under all the belts.
static func belt_under() -> ArrayMesh:
	if not _one.has("belt_under"):
		var b := Face.Builder.new()
		var h := TILE * 0.5
		b.polygon(PackedVector2Array([Vector2(-h, -h + 6.0), Vector2(h, -h + 6.0), Vector2(h, h + 6.0), Vector2(-h, h + 6.0)]), Color(CAST, 0.22))
		_one["belt_under"] = b.mesh()
	return _one["belt_under"]

## `belt_under` for a bend: the shade follows the arc. `corner` is the corner
## of its tile the bend turns about, (1, 1), (-1, 1), (-1, -1) or (1, -1)
## from the tile's middle (for `flat(tile, f)`: DIRS[f] + DIRS[f + 1], or
## DIRS[f] + DIRS[f + 3] mirrored).
static func belt_under_bend(corner: Vector2i) -> ArrayMesh:
	if not _under_bends.has(corner):
		var b := Face.Builder.new()
		var c := Vector2(corner) * 0.5
		var from := atan2(-float(corner.y), -float(corner.x)) - PI * 0.25
		var n := 12
		var shade := PackedVector2Array()
		for i in n + 1:
			var a := from + PI * 0.5 * i / n
			shade.append((c + Vector2(cos(a), sin(a)) * 0.95) * TILE + Vector2(0.0, 6.0))
		for i in range(n, -1, -1):
			var a := from + PI * 0.5 * i / n
			shade.append((c + Vector2(cos(a), sin(a)) * 0.05) * TILE + Vector2(0.0, 6.0))
		b.polygon(shade, Color(CAST, 0.22))
		_under_bends[corner] = b.mesh()
	return _under_bends[corner]

## The belts' one material (shaders/belt_2d.gdshader). Its `time`, in
## seconds, runs the slats BELT_SPEED tiles a second toward each belt's own
## +x; `belt_run` sets it.
static func belt_material(fast := false) -> ShaderMaterial:
	if fast:
		# the fast belt: a dark rubber bed running twice as fast, two warm
		# chevrons a tile (the ledger, section 8: "a rubber belt")
		if _fast_mat == null:
			_fast_mat = ShaderMaterial.new()
			_fast_mat.shader = BELT
			_fast_mat.set_shader_parameter("speed", BELT_SPEED * 2.0)
			_fast_mat.set_shader_parameter("bed", Vector3(0.46, 0.5, 0.56))
			_fast_mat.set_shader_parameter("mark_tone", Vector3(1.0, 0.82, 0.36))
			_fast_mat.set_shader_parameter("marks", 2.0)
		return _fast_mat
	if _belt_mat == null:
		_belt_mat = ShaderMaterial.new()
		_belt_mat.shader = BELT
		_belt_mat.set_shader_parameter("speed", BELT_SPEED)
	return _belt_mat

## Called every frame by whatever shows belts, with the seconds the land has
## run: the belts' clock, wrapped to one tile's travel so a phone's shader
## never takes the fraction of a large number. Under reduce motion the slats
## lie still (the items on them still travel: that is the sim's).
static func belt_run(t: float) -> void:
	var time := 0.0 if Motion.reduce else fposmod(t, 1.0 / BELT_SPEED)
	belt_material().set_shader_parameter("time", time)
	belt_material(true).set_shader_parameter("time", time)

## How far up (view units, drawn as a lift up the screen) a thing crossing
## a bridge rides, `along` 0 to 1 from the side it came by to the side it
## leaves by: level over the middle, down to the belt at both ends.
static func bridge_lift(along: float) -> float:
	var off := absf(along - 0.5)
	return BRIDGE_UP * (1.0 - smoothstep(BRIDGE_FLAT, 0.5, off))

## A bridge's deck, in view units about the middle of its tile: planks
## across the belt that runs along `facing`, a rail down each edge and its
## shade on the belt under it. Drawn over what rides under it; what rides
## over it is drawn after it at `bridge_lift`. The same for a facing and the
## one opposite.
static func bridge(facing: int) -> ArrayMesh:
	var key := "bridge%d" % posmod(facing, 2)
	if _one.has(key):
		return _one[key]
	var b := Face.Builder.new()
	var a := Vector2(DIRS[posmod(facing, 2)])          # the belt under it
	var s := Vector2(DIRS[posmod(facing, 2) + 1])      # the way across
	var w := 0.3 * TILE
	var h := 0.5 * TILE
	var quad := func(p: Vector2, q: Vector2, r: Vector2, t: Vector2, colour: Color) -> void:
		b.polygon(PackedVector2Array([p, q, r, t]), colour)
	quad.call(-s * h - a * w + Vector2(0.0, 10.0), s * h - a * w + Vector2(0.0, 10.0), s * h + a * w + Vector2(0.0, 10.0), -s * h + a * w + Vector2(0.0, 10.0), Color(CAST, 0.3))
	quad.call(-s * h - a * w, s * h - a * w, s * h + a * w, -s * h + a * w, PLANK)
	quad.call(-s * h * 0.4 - a * w, s * h * 0.4 - a * w, s * h * 0.4 + a * w, -s * h * 0.4 + a * w, PLANK.lightened(0.12))
	for k in range(1, 8):
		var t := -h + 2.0 * h * k / 8.0
		b.stroke(PackedVector2Array([s * t - a * w, s * t + a * w]), 2.0, Color(PLANK_DEEP, 0.65), false, false)
	for j: float in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([-s * h + a * w * j, s * h + a * w * j]), 7.0, Color("8a5f38"), false, false)
		b.stroke(PackedVector2Array([-s * h + a * w * j, s * h + a * w * j]), 2.0, PLANK.lightened(0.2), false, false)
	_one[key] = b.mesh()
	return _one[key]

## A footprint's highlight under the finger: `w` by `h` tiles in tile
## space, (0, 0) to (w, h), a soft fill inside a rim. Pale green paper when
## it fits (`ok`), the house's warning red when it does not. Drawn under
## `flat(tile)`.
static func ghost(w: int, h: int, ok: bool) -> ArrayMesh:
	var key := Vector3i(w, h, int(ok))
	if not _ghosts.has(key):
		var b := Face.Builder.new()
		var box := Face.Builder.round_rect(Vector2(5.0, 5.0), Vector2(w, h) * FINE - Vector2(10.0, 10.0), 13.0)
		b.polygon(box, Color(Pal.LEAF_TILE if ok else Pal.BAD_TILE, 0.5))
		b.stroke(box, 5.0, Color(Color("f6fde8") if ok else Pal.BAD, 0.95), true)
		if ok:
			b.stroke(Face.Builder.round_rect(Vector2(10.5, 10.5), Vector2(w, h) * FINE - Vector2(21.0, 21.0), 9.0), 2.2, Color(Pal.GOOD, 0.8), true)
		for i in b.verts.size():
			b.verts[i] /= FINE
		_ghosts[key] = b.mesh()
	return _ghosts[key]

# --- pictures ---

## A picture about (0, 0), 96 across, for a drawer's tile or a card: `belt`,
## `fast`, `bridge`, `coin` (the gold pill's coin, ui/menu/gold_pill.gd, as
## a mesh), `square` and `box`.
static func icon(named: String) -> ArrayMesh:
	if _icons.has(named):
		return _icons[named]
	var b := Face.Builder.new()
	match named:
		"belt", "fast":
			# two tiles of it end to end, the slats and the chevron painted
			for i in 2:
				var xf := Transform2D(0.0, Vector2(0.46, 0.46), 0.0, Vector2(-46.0 + 46.0 * i, -23.0))
				_belt_into(b, xf, named == "belt")
				if named == "fast":
					# the fast one's dark bed and two warm chevrons
					b.polygon(xf * PackedVector2Array([Vector2(0.0, 16.0), Vector2(FINE, 16.0), Vector2(FINE, 84.0), Vector2(0.0, 84.0)]), Color("6b7078"))
					for x: float in [20.0, 52.0]:
						for side: float in [-1.0, 1.0]:
							b.stroke(xf * PackedVector2Array([Vector2(x, 50.0 + side * 22.0), Vector2(x + 18.0, 50.0)]), 3.4, Color(1.0, 0.82, 0.36, 0.9))
		"bridge":
			var whole := Face.Builder.new()
			_belt_into(whole, Transform2D(0.0, Vector2(TILE / FINE, TILE / FINE), 0.0, Vector2(-TILE, -TILE) * 0.5), true)
			whole.append(bridge(1), Transform2D.IDENTITY)
			_fit_into(b, whole.mesh(), 92.0)
		"coin":
			_coin_into(b, Vector2.ZERO, 42.0)
		"box":
			_fit_into(b, box(4), 84.0)
		_:
			_fit_into(b, square(), 70.0)
	_icons[named] = b.mesh()
	return _icons[named]

## The transform that fits a mesh's own box into a square of `side` about
## (0, 0).
static func _fitted(m: ArrayMesh, side: float) -> Transform2D:
	var box := Rect2()
	var first := true
	for v: Vector2 in m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		box = Rect2(v, Vector2.ZERO) if first else box.expand(v)
		first = false
	var s := side / maxf(box.size.x, box.size.y)
	return Transform2D(0.0, Vector2(s, s), 0.0, -box.get_center() * s)

static func _fit_into(b: Face.Builder, m: ArrayMesh, side: float) -> void:
	b.append(m, _fitted(m, side))

## Whether the language writes 0,47 for 0.47 (pt, es), and a line of figures
## as it does.
static func comma() -> bool:
	return not TranslationServer.get_locale().begins_with("en")

static func decimal(text: String) -> String:
	return text.replace(".", ",") if comma() else text

## What the pace pill and the Arcade card say of `sim`'s pace: a full box
## every so many seconds, or that none has been sold often enough to say (the
## sim reads nothing under two).
static func pace_text(sim: RefCounted) -> String:
	if sim.pace_ticks() <= 0:
		return TranslationServer.translate("FACTORY_PACE_NONE")
	return TranslationServer.translate("FACTORY_PACE") % amount(snappedf(sim.pace_s(), 0.1), comma())

## A figure that may have a tenth: 1, 1.5, 2, 31.5 (a pace, a pause on the
## bay), and past a thousand as `short` writes it. `comma` for a language
## that writes 1,5.
static func amount(v: float, comma := false) -> String:
	if v >= 1000.0 or is_equal_approx(v, roundf(v)):
		return short(roundi(v))
	var text := "%.1f" % v
	return text.replace(".", ",") if comma else text

## A count in a few characters: 999, 1.23K, 45.6K, 789K, 1.2M, and on
## through B, T and Q. Coins have no last level, so every count on the
## screen goes through here.
static func short(n: int) -> String:
	if n < 1000:
		return str(n)
	var v := float(n)
	var i := 0
	while v >= 1000.0 and i < 5:
		v /= 1000.0
		i += 1
	var text := ("%.2f" % v) if v < 10.0 else (("%.1f" % v) if v < 100.0 else ("%d" % int(v)))
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text + " KMBTQ"[i]
