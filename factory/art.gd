extends RefCounted

## Factory's drawings: the land's painted pieces (the plate on the pond, its
## shore and washes, the belts, the market's hatch, the engine, the tray),
## (seen corner on until 2026-10-21, top-down since), and the robot floor's own few (the robot, its face, its
## bubbles and its charge, the grey square, the box, the heap of boxes). It
## began as the Grove's art (valley/grove_art.gd) on 2026-10-10 and drew the
## land of plates, trees and machines; on 2026-10-20 the floor of robots
## redrew everything top-down in new paper art, and on 2026-10-21 the user
## overturned that ("factory redesign is wrong, it was suppose to use at
## most the elements factory already had on design, not recreate them
## all"): the land's view came back and only the robot, the node sheet, the
## squares and the boxes are new. Every drawing is built once into a mesh
## and kept, so a screen pays one draw_mesh a thing (CLAUDE.md, the 855
## budget). Nothing here knows the sim: a tile is a Vector2i, a kind a
## String.
##
## THE TILE GRID (since the second pass of 2026-10-21: the user, on the
## corner-on build, "keep current visual elements, but make it topdown like
## the previous version"). A point of tile space `t` (a tile's centre is
## tile + (0.5, 0.5)) is seen at `at(t)`, in view units: square tiles, +x
## right, +y down, the floor's tile (0, 0) corner its top left. What stands
## rises up the screen a view unit for a view unit of height (`_p`), so a
## piece shows its top and its front and keeps the land's look.
##   K, DEEP             52 view units to half a tile's width; the ground
##                       not foreshortened (1). TILE is a tile, 104 square.
##   at(t), tile_at(v)   tile space to view units and back (floor it for the
##                       tile). PLANE is at() as a Transform2D.
##   flat(tile, facing)  the transform that lays a unit-square mesh (belt,
##                       ghost) on `tile`, turned to DIRS[facing].
##   DIRS                [+x, +y, -x, -y] as Vector2i; a facing is its index.
##   depth(t)            what to sort by, back to front (t.x + t.y).
##   RISE                view units a tile's length stands tall.
##
## THE GROUND. Draw order: water (fixed to the screen), the plate (its
## earth on its front edge only), flat
## things (belts, ghosts), what lies, then what stands, sorted by depth(),
## then the air (bars, bubbles), then light. A layer that pans and zooms must
## be given a box of its own (RenderingServer.canvas_item_set_custom_rect):
## the engine culls a layer by its meshes' boxes without their transforms.
##   water(size, round)  the pond for a field of `size` pixels, with nothing
##                       in it that belongs to a place, so the floor may pan
##                       over it.
##   plate(kind, sides, variant, w, h)  one plate's land, `w` by `h` tiles,
##                       its tile (0, 0) corner on the mesh's origin. `kind`
##                       is neutral (the market's white ground of the land,
##                       the tiles ruled on it). `sides` bit i is set when a
##                       plate lies beyond the side toward DIRS[i] (the floor
##                       is one plate: 0). `variant` lays the washes
##                       differently.
##   light(size)         warm light and a darker frame over everything.
##   DEPTH, ROUND        the earth showing over the water (view units), and
##                       how far along each side a corner is rounded (tiles).
##
## BELTS. One mesh and one material for every belt on the floor, the
## player's and the two of its own (the intake's and the deliver belt).
##   belt(), belt_bend(mirror)  a belt tile in tile space, 0..1, travelling
##                       to +x: draw under flat(tile, facing), lifted
##                       BELT_LIFT, or as a MultiMesh of such transforms.
##   belt_under(), belt_under_bend(corner)  its legs, edges and shade.
##   belt_material(fast), belt_run(t)  the material that draws the slats and
##                       the chevron and runs them; its clock.
##   bridge(facing), bridge_lift(along)  a bridge's deck across its bed,
##                       and how high what crosses it rides.
##
## THINGS, in view units, origin where they rest on the ground, a soft
## shadow in each.
##   square(shade), box(n, shade)  a grey square and a box of card seen
##                       in the land's item style, about 33 and 40 across, the box holding
##                       `n` squares (0..4); `shade` false for one in a hand.
##   item(it)            the mesh for a sim item: a square or a box of its n.
##   stack()             the box stack: empty boxes heaped as `HEAP` heaped
##                       the land's logs.
##   table()             the pack table: the land's tray, alone on its tile
##                       and bigger; TABLE_TOP is where its box rests.
##   market()            the 1 by 1 hatch of the land: the deliver pad.
##                       market_door() is one leaf, drawn twice by
##                       market_leaf(side, open); market_front() is the box's
##                       near side again, drawn over a thing falling in.
##                       MARKET_TOP is where a thing lies on it.
##   engine()            the land's engine: the charging bay. Its flywheel
##                       is wheel() under on_wall(hub, r, angle, axis) at
##                       ENGINE_WHEEL, ENGINE_WHEEL_UP up.
##   ghost(w, h, ok)     a footprint's highlight in tile space.
##   icon(kind)          96 across about (0, 0): belt, fast, bridge, coin,
##                       square, box, market, engine.
##
## A ROBOT, standing on (0, 0) as the land's buildings stood, in view units.
##   robot(quarter)      a round body on two treads, white for a tint, a
##                       lamp on a stalk; its shadow in it. The treads run
##                       the way it faces, `quarter` (0 +x, 1 +y, ...).
##   nose()              the arrow on its lid that points the way it faces,
##                       pointing +x from (0, 0): drawn turned about LID.
##   face(stuck)         its eyes and mouth (ui/faces/face.gd's own
##                       `face_parts`) on its front: content, puzzled ("?"),
##                       asleep ("flat") or worried ("nocell").
##   bubble(kind)        over it, the tail's tip on (0, 0): "?", "!", "wait",
##                       "flat", "nocell", "charge". Drawn at BUBBLE_AT.
##   bar(), battery_bar(f), battery_tone(f)  the charge: one white bar
##                       BAR_W long, laid by battery_bar(f) at BAR_AT (its
##                       track at f 1), tinted by battery_tone(f).
##   HELD_AT, HELD_SCALE  where what it holds is drawn, and how big.
##
## FIGURES. comma(), decimal(text), amount(v, comma), short(n),
## pace_text(sim), next_text(sim), milestone_name(id).

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const BELT := preload("res://shaders/belt_2d.gdshader")

## The painted land (2026-10-06, the isometric pass): a pond pale far off
## and deep at the foot, grass in forest greens under a wash of warm light
## and cool shade, earth warm where it looks at the sun (upper left) and
## cool where it looks away, and a shadow that is a colour, never a grey.
const WATER_FAR := Color("b9e8e0")
const WATER := Color("7fd0cc")
const WATER_DEEP := Color("4ba9b3")
const RIPPLE := Color(1.0, 1.0, 1.0, 0.42)
## The earth under the turf, top and foot, and the clay under that; each
## lit and in shade.
const EARTH := [Color("d8ad75"), Color("c2925e")]
const EARTH_SHADE := [Color("96694a"), Color("7f573f")]
const CLAY := [Color("b68253"), Color("966642")]
const CLAY_SHADE := [Color("76503b"), Color("5f4133")]
const SEAM := Color(0.34, 0.2, 0.13, 0.3)
const STONE := Color("e0cfae")
const STONE_SHADE := Color("a98f76")
const SHADE := Color(0.09, 0.27, 0.34, 0.26)
## The paper a price lies on while the energy does not reach it: the shop's
## bars, and the tree's bar and tags.
const PRICE_OFF := Color("ede4d3")
const PLANK := Color("cfa26d")
const PLANK_DEEP := Color("a57a48")
const STEEL := Color("9ba5ad")
const STEEL_LIT := Color("d5dde3")
const STEEL_DEEP := Color("7d8890")
## What the modules are built of. Brick, its lit and shaded sides and the
## mortar between; iron the same; the pale stone of the quarry; charcoal.
const BRICK := Color("cf8263")
const BRICK_LIT := Color("e6a27e")
const BRICK_SHADE := Color("a8604c")
const MORTAR := Color(0.42, 0.2, 0.15, 0.4)
const IRON := Color("6f7a84")
const IRON_LIT := Color("9ba5ad")
const IRON_SHADE := Color("4d5762")
const HOLLOW := Color("3d2924")
## The gold pill's coin (ui/menu/gold_pill.gd, GOLD, GOLD_DEEP, GOLD_HI). Its
## hexes are written again here: that script reads the Wallet autoload, so a
## harness run with --script could not load this one through it.
const GOLD := Color("f2b632")
const GOLD_DEEP := Color("c98a16")
const GOLD_HI := Color("ffe39a")
## The floor's ground: main's neutral plate (the market's plate of the land,
## the user, 2026-10-11: "a white ground with neutral texture"): chalk, a
## warm and a cool white over it, and the turf hanging over its edge.
const GROUND := {
	"neutral": {"grass": Color("f1eee7"), "lit": Color("ffffff"), "deep": Color("cfcac0"), "warm": Color("fffaf0"), "cool": Color("dde0e2"),
		"lip": Color("c4bfb4"), "lip_lit": Color("e4e0d7")},
}
## How the floor is seen (2026-10-21, the second pass): square tiles aligned
## with the screen, +x right and +y down, seen from straight above with what
## stands rising up the screen, a view unit up for a view unit of height
## (a mild three-quarter oblique: a thing shows its top and its front, the
## side looking down the screen, and nothing of its other sides). K is half
## a tile, 52 view units, so a tile is 104 across: the land's pieces keep
## the heights they were drawn with (a robot 58 up, a belt's bed 20) and
## stand about as tall against a tile as they did corner on. DEEP is how
## deep the ground is seen for its width: 1, the ground is not foreshortened
## (it was 0.66 corner on). PLANE is at() as a Transform2D.
const K := 52.0
const DEEP := 1.0
const TILE := Vector2(K * 2.0, K * 2.0)
const PLANE := Transform2D(Vector2(K * 2.0, 0.0), Vector2(0.0, K * 2.0), Vector2.ZERO)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## A tile's length standing up, in view units: as long as it lies.
const RISE := K * 2.0
## The earth showing over the water on the floor's front edge, and how far
## along each side a corner of the land is rounded off, in tiles.
const DEPTH := 80.0
const ROUND := 0.34
## The side a walk round a plate leaves each corner by, clockwise from the
## back corner: back to right is the -y side, right to front the +x.
const SIDE_AFTER := [3, 0, 1, 2]
## A shadow's tone, and how a standing drawing is laid on the ground to be
## one (`cast`): where a unit of its width goes, and a unit of its height.
const CAST := Color(0.09, 0.27, 0.34, 0.24)
const CAST_ALONG := Vector2(0.8, 0.14)

## The things in each row of a heap, from the ground up, for each of the
## five ways a stack is drawn (`heap_of`): the land's logs, the floor's
## empty boxes now.
const HEAP := [[1], [2], [2, 1], [3, 2, 1], [4, 3, 2, 1]]

## How fast a belt runs, in tiles a second, and its slats to a tile (the
## shader's own, shaders/belt_2d.gdshader).
const BELT_SPEED := 0.5
## A belt's bed stands this far over the turf (view units, between a quarter
## and a third of RISE), and is this thick at its edge. BELT_LIFT moves a
## thing drawn on the ground up onto the bed.
const BELT_UP := 20.0
const BELT_DEEP := 7.0
const BELT_LIFT := Vector2(0.0, -BELT_UP)
## The market's hatch: a box as tall as a belt's bed, so what a belt brings
## rolls straight onto it; half its side and half the hole's, in tiles; how
## far a leaf swings down (radians) and how deep the dark goes.
const MARKET_TALL := BELT_UP
const MARKET_HALF := 0.42
const HATCH_HALF := 0.3
const HATCH_SWING := 1.4
const HATCH_DEEP := 30.0
const MARKET_TOP := Vector2(0.0, -MARKET_TALL)
const PIT := Color("2f2420")
## A tile-space mesh is drawn at this many units a tile and shrunk after:
## the builder feathers every edge by a unit and a half of its own.
const FINE := 100.0

static var _icons := {}
static var _plates := {}
static var _boxes := {}
static var _faces := {}
static var _bubbles := {}
static var _ghosts := {}
static var _one := {}
static var _belt: ArrayMesh
static var _bends := {}
static var _under_bends := {}
static var _belt_mat: ShaderMaterial
static var _fast_mat: ShaderMaterial

# --- how the floor is seen ---

## A point of tile space, in view units.
static func at(t: Vector2) -> Vector2:
	return t * (K * 2.0)

## The point of tile space under a point of the view.
static func tile_at(v: Vector2) -> Vector2:
	return v / (K * 2.0)

## What to sort by so the back (the top of the screen) is drawn first.
static func depth(t: Vector2) -> float:
	return t.y + t.x * 0.001

## Lays a mesh drawn in tile space on the ground: its (0, 0)..(1, 1) on the
## tile at `tile`, turned about the tile's middle so its +x runs toward
## DIRS[facing]. A whole footprint (`ghost`) takes facing 0.
static func flat(tile: Vector2, facing := 0) -> Transform2D:
	var x := Vector2(DIRS[posmod(facing, 4)])
	var y := Vector2(DIRS[posmod(facing + 1, 4)])
	return PLANE * Transform2D(x, y, tile + Vector2(0.5, 0.5) - (x + y) * 0.5)

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

## A band between two rows of points, each point with its own colours.
static func _band(b: Face.Builder, top: PackedVector2Array, foot: PackedVector2Array, top_c: PackedColorArray, foot_c: PackedColorArray) -> void:
	var first := b.verts.size()
	for i in top.size():
		b.vertex(top[i], top_c[i])
		b.vertex(foot[i], foot_c[i])
	for i in top.size() - 1:
		var k := first + i * 2
		b.tri(k, k + 2, k + 3)
		b.tri(k, k + 3, k + 1)

# --- the pond ---

## The pond for a field of `size` pixels, its corners rounded by `round`:
## pale at the top, deep at the foot, the clouds of a slow sky lying soft on
## it and the light on a ripple here and there. It is drawn fixed to the
## screen while the land pans and zooms over it, so nothing in it has a
## place: the lilies and the stone the Grove's pond had would slide under
## the land (`pads` is for a screen that anchors them itself).
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

## One plate's land, `w` by `h` tiles, in view units, the corner of its
## local tile (0, 0) (its back corner) on the mesh's origin: a screen draws
## it at at(that corner). It was the land's 8 by 8 plate; since 2026-10-21
## any size, so the robot floor of 10 by 8 is one plate (and 8 by 10 when
## the view is turned a quarter). `kind` is neutral (white ground, the tiles
## ruled on it).
##
## `sides` says where the land goes on: bit i is set when a plate lies
## beyond the side toward DIRS[i]. Such a side is cut straight and has no
## earth under it, no mirror and no rim of light. A corner is rounded only
## where both its sides are free. The seam itself is the work of the plate
## in front (its -x and -y sides, drawn last): its grass fades a third of a
## tile out over the plate behind and a low bank of turf lies along the
## line. The floor is one plate and has no sides.
##
## The corners of the tiles are marked on the ground with two short ticks,
## so a belt's way can be seen before it is laid.
static func plate(kind: String, sides := 0, variant := 0, w := 8, h := 8) -> ArrayMesh:
	sides &= 15
	var key := "%s|%d|%d|%d|%d" % [kind, sides, variant, w, h]
	if not _plates.has(key):
		var b := Face.Builder.new()
		_plate_into(b, kind, sides, variant, Vector2i(w, h))
		_plates[key] = b.mesh()
	return _plates[key]

## The plate's edge in view units, clockwise from its back corner, a point
## every half tile along a side: [points, the side each point's way to the
## next lies on (-1 round a corner), how far along that side it is (0..1)].
static func _rim(sides: int, size: Vector2i) -> Array:
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size), Vector2(0.0, size.y)]
	var round: Array[float] = []
	for i in 4:
		var into: int = SIDE_AFTER[(i + 3) % 4]
		var out: int = SIDE_AFTER[i]
		round.append(ROUND if (sides & (1 << into)) == 0 and (sides & (1 << out)) == 0 else 0.0)
	var pts := PackedVector2Array()
	var tags := PackedInt32Array()
	var along := PackedFloat32Array()
	for i in 4:
		var c := corners[i]
		var out: int = SIDE_AFTER[i]
		var long := float(size.x if i % 2 == 0 else size.y)
		var to_prev := (corners[(i + 3) % 4] - c).normalized()
		var to_next := (corners[(i + 1) % 4] - c).normalized()
		var r := round[i]
		if r > 0.0:
			var arc := Face.Builder.bezier2(c + to_prev * r, c, c + to_next * r, 8)
			arc.append(c + to_next * r)
			for p in arc:
				pts.append(at(p))
				tags.append(-1)
				along.append(0.0)
			tags[tags.size() - 1] = out
			along[along.size() - 1] = r / long
		else:
			pts.append(at(c))
			tags.append(out)
			along.append(0.0)
		var last := long - round[(i + 1) % 4]
		for k in range(1, int(long) * 2):
			var s := k * 0.5
			if s > r + 0.05 and s < last - 0.05:
				pts.append(at(c + to_next * s))
				tags.append(out)
				along.append(s / long)
	return [pts, tags, along]

## A point of a plate's ground at least `inside` view units from its edge.
static func _on_plate(rng: RandomNumberGenerator, inside: float, size: Vector2i) -> Vector2:
	var m := clampf(inside / (K * 2.0), 0.1, minf(size.x, size.y) * 0.45)
	return at(Vector2(rng.randf_range(m, size.x - m), rng.randf_range(m, size.y - m)))

static func _plate_into(b: Face.Builder, kind: String, sides: int, variant: int, size: Vector2i) -> void:
	var tone: Dictionary = GROUND.get(kind, GROUND["neutral"])
	var rim: Array = _rim(sides, size)
	var pts: PackedVector2Array = rim[0]
	var tags: PackedInt32Array = rim[1]
	var along: PackedFloat32Array = rim[2]
	var n := pts.size()
	var area := float(size.x * size.y) / 64.0
	var scale := Vector2(size) / 8.0
	# the shore's own dice: the ground's must fall the same whatever is joined
	var edge_rng := RandomNumberGenerator.new()
	edge_rng.seed = 20261005 + sides * 31 + variant * 977 + kind.length()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010 + variant * 7919 + kind.length() * 131
	# the front of the land, its foot seen from above: from its bottom right
	# corner along to its bottom left, in runs of free shore (where a plate is
	# joined there is no earth to show)
	var hi := 0
	var lo := 0
	for i in n:
		if pts[i].x + pts[i].y > pts[hi].x + pts[hi].y:
			hi = i
		if pts[i].y - pts[i].x > pts[lo].y - pts[lo].x:
			lo = i
	var runs: Array[PackedInt32Array] = []
	var cur := PackedInt32Array()
	var i := hi
	while i != lo:
		var tag := tags[i]
		if tag < 0 or (sides & (1 << tag)) == 0:
			if cur.is_empty():
				cur.append(i)
			cur.append((i + 1) % n)
		elif not cur.is_empty():
			runs.append(cur)
			cur = PackedInt32Array()
		i = (i + 1) % n
	if not cur.is_empty():
		runs.append(cur)
	var shores: Array = []
	for run in runs:
		var edge := PackedVector2Array()
		var shade := PackedFloat32Array()
		var f := PackedFloat32Array()
		for k in run.size():
			edge.append(pts[run[k]])
			f.append(along[run[k]])
			var d := (pts[run[mini(k + 1, run.size() - 1)]] - pts[run[maxi(k - 1, 0)]]).normalized()
			shade.append(smoothstep(0.0, 1.0, clampf(0.5 + d.y * 1.4, 0.0, 1.0)))
		_shore_into(b, edge, shade, f, edge_rng, tone, at(Vector2(size) * 0.5))
		shores.append([edge, shade])
	b.polygon(pts, tone["grass"])
	# the wash: warm toward the sun, cool away from it, and patches of both
	var warm: Color = tone["warm"]
	var cool: Color = tone["cool"]
	var lit: Color = tone["lit"]
	var deep: Color = tone["deep"]
	var reach := sqrt(area)
	_glow(b, at(Vector2(2.9, 4.5) * scale), 215.0 * reach, 215.0 * reach * DEEP, warm, 0.5)
	_glow(b, at(Vector2(5.2, 5.2) * scale) + Vector2(110.0, 0.0), 205.0 * reach, 205.0 * reach * DEEP, cool, 0.34)
	var middle := at(Vector2(size) * 0.5)
	var half := K * maxf(size.x, size.y)
	for k in roundi(16 * area):
		var r := rng.randf_range(90.0, 190.0)
		var p := _on_plate(rng, r * 1.06, size)
		var sunny := (-(p.x - middle.x) - (p.y - middle.y) / DEEP) / half
		if rng.randf() < 0.5 + 0.4 * sunny:
			_glow(b, p, r, r * DEEP, warm, rng.randf_range(0.3, 0.5))
		else:
			_glow(b, p, r, r * DEEP, cool, rng.randf_range(0.2, 0.34))
	# the sun on the near edge it looks at, and along the back where it is free
	for shore: Array in shores:
		var edge: PackedVector2Array = shore[0]
		var shade: PackedFloat32Array = shore[1]
		var line := PackedVector2Array()
		for k in edge.size():
			if shade[k] < 0.3:
				line.append(edge[k] + Vector2(0.0, -4.0))
		if line.size() > 1:
			b.stroke(line, 3.4, Color(0.94, 0.97, 0.7, 0.5), false, false)
	for side: int in [2, 3]:
		if (sides & (1 << side)) != 0:
			continue
		var from := Vector2(0.0, size.y - 0.5) if side == 2 else Vector2(0.5, 0.0)
		var to := Vector2(0.0, 0.5) if side == 2 else Vector2(size.x - 0.5, 0.0)
		b.stroke(PackedVector2Array([at(from) + Vector2(1.0, 2.5), at(to) + Vector2(-1.0 if side == 3 else 1.0, 2.5)]), 2.6,
			Color(0.9, 0.96, 0.66, 0.42 if side == 2 else 0.24), false, false)
	if kind == "neutral":
		_neutral_into(b, rng, size)
	else:
		for k in roundi(6 * area):
			_pebble(b, _on_plate(rng, 40.0, size), 1.0)
	# the tiles' corners, where no shore is
	var tick := Color(deep.darkened(0.12), 0.34 if kind == "neutral" else 0.0)
	for tx in size.x + 1:
		for ty in size.y + 1:
			if (tx == size.x and (sides & 1) == 0) or (ty == size.y and (sides & 2) == 0) or (tx == 0 and (sides & 4) == 0) or (ty == 0 and (sides & 8) == 0):
				continue
			var c := Vector2(tx, ty)
			b.stroke(PackedVector2Array([at(c - Vector2(0.09, 0.0)), at(c + Vector2(0.09, 0.0))]), 2.4, tick)
			b.stroke(PackedVector2Array([at(c - Vector2(0.0, 0.09)), at(c + Vector2(0.0, 0.09))]), 2.4, tick)
			b.ellipse(at(c) + Vector2(-0.6, -0.8), 1.6, 1.1, Color(lit, 0.5))
	# the seams with the plates behind, which were drawn first
	for side: int in [2, 3]:
		if (sides & (1 << side)) != 0:
			_seam_into(b, side, tone, edge_rng, size)

## The shore under a run of free edge: the land's mirror on the pond, the
## earth and the clay under it (each point of `edge` with how far it looks
## from the sun in `shade`, so the lit left goes over to the shaded right
## round a corner), a pale line and broken rings at the water, and the turf
## hanging over in scallops. A run that ends at a plate's cut side ends
## square: the next plate's shore begins there, the same line.
static func _shore_into(b: Face.Builder, edge: PackedVector2Array, shade: PackedFloat32Array, along: PackedFloat32Array,
		rng: RandomNumberGenerator, tone: Dictionary, middle: Vector2) -> void:
	var n := edge.size()
	var row := func(down: float, wave := 0.0) -> PackedVector2Array:
		var out := PackedVector2Array()
		out.resize(n)
		for i in n:
			# nothing at either end of a side, so two plates' waists meet
			out[i] = edge[i] + Vector2(0.0, down + wave * (sin(TAU * 3.0 * along[i]) + 0.6 * sin(TAU * 5.0 * along[i])))
		return out
	var tint := func(lit: Color, dark: Color, alpha := 1.0) -> PackedColorArray:
		var cs := PackedColorArray()
		cs.resize(n)
		for i in n:
			cs[i] = Color(lit.lerp(dark, shade[i]), alpha)
		return cs
	var lip: Color = tone["lip"]
	var lip_lit: Color = tone["lip_lit"]
	var dark := Color(0.07, 0.27, 0.33)
	_band(b, row.call(DEPTH - 2.0), row.call(DEPTH + 58.0), tint.call(dark, dark, 0.34), tint.call(dark, dark, 0.0))
	var waist: PackedVector2Array = row.call(DEPTH * 0.5, DEPTH * 0.05)
	_band(b, row.call(0.0), waist, tint.call(EARTH[0], EARTH_SHADE[0]), tint.call(EARTH[1], EARTH_SHADE[1]))
	_band(b, waist, row.call(DEPTH), tint.call(CLAY[0], CLAY_SHADE[0]), tint.call(CLAY[1], CLAY_SHADE[1]))
	b.stroke(waist, 3.0, SEAM, false, false)
	@warning_ignore("integer_division")
	for i in maxi(2, n / 3):
		var k := rng.randi_range(0, n - 2)
		var down := Vector2(0.0, DEPTH * rng.randf_range(0.16, 0.36))
		b.stroke(PackedVector2Array([edge[k] + down, edge[k + 1] + down]), 2.4, Color(SEAM, 0.2))
	@warning_ignore("integer_division")
	for i in maxi(1, n / 5):
		var k := rng.randi_range(1, n - 2)
		var c := edge[k] + Vector2(0.0, DEPTH * rng.randf_range(0.6, 0.8))
		var s := rng.randf_range(0.8, 1.3)
		b.ellipse(c, 11.0 * s, 7.0 * s, STONE.lerp(STONE_SHADE, shade[k]))
		if shade[k] < 0.5:
			b.ellipse(c + Vector2(-3.0, -2.0) * s, 5.0 * s, 3.0 * s, Color("f1e6cf"))
	_band(b, row.call(DEPTH - 20.0), row.call(DEPTH), tint.call(dark, dark, 0.0), tint.call(dark, dark, 0.3))
	b.stroke(row.call(DEPTH), 3.6, Color(1.0, 1.0, 1.0, 0.72), false, false)
	# rings going out from the foot, broken
	for ring in 2:
		var i := rng.randi_range(1, 4)
		while i < n - 3:
			var long := rng.randi_range(3, 6)
			var dash := PackedVector2Array()
			for k in range(i, mini(n - 1, i + long)):
				dash.append(middle + (edge[k] - middle) * (1.035 + 0.04 * ring) + Vector2(0.0, DEPTH + 5.0 + 3.0 * ring))
			if dash.size() > 1:
				b.stroke(dash, 2.6, Color(1.0, 1.0, 1.0, 0.3 - 0.13 * ring))
			i += long + rng.randi_range(4, 9)
	# the turf, hanging over the earth in scallops
	_band(b, row.call(-1.0), row.call(12.0), tint.call(lip_lit, lip), tint.call(lip_lit, lip))
	for i in n - 1:
		var steps := maxi(1, int(edge[i].distance_to(edge[i + 1]) / 13.0))
		for k in steps:
			var t := float(k) / steps
			b.disc(edge[i].lerp(edge[i + 1], t) + Vector2(0.0, 11.0), rng.randf_range(6.5, 11.0), lip_lit.lerp(lip, lerpf(shade[i], shade[i + 1], t)))

## The seam along a joined back side (2 the -x side, 3 the -y): this
## plate's grass fading out over the one behind, so two kinds of ground go
## over into each other, and a low bank of turf on the line, its shade on
## this side of it. The bank along the -x side shows the eye its shaded
## face, the one along -y its lit one, as the earth does.
static func _seam_into(b: Face.Builder, side: int, tone: Dictionary, rng: RandomNumberGenerator, size: Vector2i) -> void:
	var from := Vector2(0.0, size.y) if side == 2 else Vector2.ZERO
	var to := Vector2.ZERO if side == 2 else Vector2(size.x, 0.0)
	var out := Vector2(DIRS[side])
	var grass_c: Color = tone["grass"]
	var lip: Color = tone["lip"]
	var lip_lit: Color = tone["lip_lit"]
	_band(b, PackedVector2Array([at(from), at(to)]), PackedVector2Array([at(from + out * 0.36), at(to + out * 0.36)]),
		PackedColorArray([grass_c, grass_c]), PackedColorArray([Color(grass_c, 0.0), Color(grass_c, 0.0)]))
	var face := 0.8 if side == 2 else 0.2
	_band(b, PackedVector2Array([at(from) + Vector2(0.0, 1.0), at(to) + Vector2(0.0, 1.0)]),
		PackedVector2Array([at(from - out * 0.16) + Vector2(0.0, 1.0), at(to - out * 0.16) + Vector2(0.0, 1.0)]),
		PackedColorArray([Color(SHADE, 0.3 * face + 0.08), Color(SHADE, 0.3 * face + 0.08)]), PackedColorArray([Color(SHADE, 0.0), Color(SHADE, 0.0)]))
	var steps := int(at(to - from).length() / 15.0)
	var soft: Color = grass_c.lerp(lip_lit.lerp(lip, face), 0.6)
	for k in steps + 1:
		var c := at(from.lerp(to, float(k) / steps)) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.5, 0.5))
		var r := rng.randf_range(7.0, 11.0)
		b.ellipse(c, r, r * 0.5, soft)
		if k % 2 == 0:
			b.ellipse(c + Vector2(-1.6, -1.6), r * 0.55, r * 0.24, Color(lip_lit.lightened(0.16), 0.6))

## A pebble on the grass, its shade under it.
static func _pebble(b: Face.Builder, c: Vector2, s: float) -> void:
	b.ellipse(c + Vector2(2.0, 3.0) * s, 9.0 * s, 4.6 * s, SHADE)
	b.ellipse(c, 8.0 * s, 5.4 * s, Pal.ROCK)
	b.ellipse(c + Vector2(-2.0, -1.8) * s, 3.6 * s, 2.2 * s, Color("d8cdb6"))

## Neutral ground: every tile ruled on it with a thin line, a few of them a
## tone off, and a speckle, so that white is a floor and not a hole.
static func _neutral_into(b: Face.Builder, rng: RandomNumberGenerator, size: Vector2i) -> void:
	var tone: Dictionary = GROUND["neutral"]
	var deep: Color = tone["deep"]
	var area := float(size.x * size.y) / 64.0
	# every tile a slab, lighter in from its grout, a few of them a shade
	# warmer or cooler (the room, 2026-10-22: a floor of tiles rather than
	# a ruled sheet with dirt on it)
	for y in size.y:
		for x in size.x:
			var t := Vector2(x, y)
			var slab := Face.Builder.round_rect(at(t + Vector2(0.045, 0.045)), TILE * 0.91, 6.0)
			var roll := rng.randf()
			var wash := Color(1.0, 1.0, 1.0, 0.5)
			if roll < 0.12:
				wash = Color(tone["warm"], 0.7)
			elif roll < 0.22:
				wash = Color(tone["cool"], 0.35)
			b.polygon(slab, wash)
	for k in range(1, size.x):
		b.stroke(PackedVector2Array([at(Vector2(k, 0.0)), at(Vector2(k, size.y))]), 2.2, Color(deep, 0.5), false, false)
	for k in range(1, size.y):
		b.stroke(PackedVector2Array([at(Vector2(0.0, k)), at(Vector2(size.x, k))]), 2.2, Color(deep, 0.5), false, false)
	for k in roundi(24 * area):
		var p := _on_plate(rng, 26.0, size)
		var r := rng.randf_range(1.2, 2.2)
		b.ellipse(p, r, r * DEEP, Color(deep, rng.randf_range(0.2, 0.4)))

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

# --- heaps ---

## How a stack of `n` is drawn: one, two, three, a low heap, a big one (the
## land's log piles; the floor's box stack is `stack()`). A stack may hold
## thousands; its count says so, not its drawing.
static func heap_of(n: int) -> int:
	return clampi(n, 1, 3) - 1 if n < 4 else (3 if n < 10 else 4)

# --- the robot floor's own (2026-10-21) ---
# The only drawings that are not the land's: the grey square, the box, the
# robot with its face, bubbles and charge (the user, 2026-10-21: new art
# "only for the robot, the node sheet, the grey squares and the boxes").
# Squares and boxes are drawn in the style of the land's items:
# standing on (0, 0), about 42 across, a soft shadow in the mesh.

## A grey square and a box of card, their tones.
const SQUARE_C := Color("8f969c")
const SQUARE_LIT := Color("b2b8bd")
const SQUARE_DEEP := Color("6f767c")
const CARD := Color("c68a44")
const CARD_LIT := Color("dba862")
const CARD_INSIDE := Color("a8722f")
const CARD_INK := Color("7a4e1c")
## Ink, a muted ink, the line round a bubble, the bay's warm tone, and the
## charge's three tones and the track it lies on.
const INK := Color("2f2a25")
const MUTED := Color("6f655b")
const PAD_LINE := Color("e3d8c6")
const LIVE := Color("c68a44")
const CHARGE_HI := Color("4e9e62")
const CHARGE_MID := Color("e2b23a")
const CHARGE_LOW := Color("d9574a")
const TRACK := Color("cdbfa6")
## A square: half its side (tiles) and how tall it stands (view units). A
## box: half its side, its walls' height, how deep the dark inside goes, and
## the squares in it, half a side each, at their places, standing SEAT up.
const SQUARE_HALF := 0.16
const SQUARE_TALL := 22.0
const BOX_HALF := 0.19
const BOX_TALL := 24.0
const BOX_DEEP := 16.0
const IN_HALF := 0.072
const IN_AT: Array[Vector2] = [Vector2(-0.085, -0.085), Vector2(0.085, -0.085), Vector2(-0.085, 0.085), Vector2(0.085, 0.085)]
const IN_SEAT := 10.0
const IN_TALL := 20.0
## The box stack: how many empty boxes the heap shows (it never runs out:
## the sim's stack always gives one), and how big each is drawn in it.
const STACK_N := 6
const STACK_K := 0.85
## The pack table: the land's tray, its half (tiles) and height, and where
## the box on it rests.
const TABLE_ALONG := 0.3
const TABLE_ACROSS := 0.34
const TABLE_TALL := 14.0
const TABLE_TOP := Vector2(0.0, -TABLE_TALL)
## The robot, standing on (0, 0): its round body's radius (tiles) and from
## how high to how high it stands, the treads under it, its lamp, its face
## on the front of the body, and over it the charge bar and the bubble; what
## it holds at HELD_AT, HELD_SCALE as big.
const BODY_R := 0.26
const BODY_FOOT := 9.0
const BODY_TOP := 50.0
const LAMP_UP := 64.0
const FACE_AT := Vector2(0.0, -29.0)
const FACE_R := 13.0
const BAR_W := 56.0
const BAR_H := 10.0
const BAR_AT := Vector2(0.0, -90.0)
const BUBBLE_AT := Vector2(0.0, -100.0)
const HELD_AT := Vector2(30.0, -8.0)
## The middle of a robot's lid, and where its nose turns: on the floor
## about its feet, the chevron just past its treads the way it faces (the
## face is on the lid, so the lid carries no arrow; 2026-10-22).
const LID := Vector2(0.0, -BODY_TOP)
const NOSE_AT := Vector2.ZERO
const NOSE_OUT := 36.0
## The steps a quarter turn of the treads is cut into (each a mesh of its
## own, made the first time it is drawn).
const TREAD_STEPS := 8
const HELD_SCALE := 0.7
## Where the robot's soft shadow lies, from its feet.
const SHADOW_AT := Vector2(7.0, 5.0)
## A tread: a capsule TREAD_W across, its middle TREAD_H up, TREAD_HALF tiles
## long either way from its seat, TREAD_OUT tiles out from the body's middle.
const TREAD_W := 15.0
const TREAD_H := 7.0
const TREAD_HALF := 0.21
const TREAD_OUT := 0.2
const TREAD := Color("443f3b")
const TREAD_LIT := Color("625b55")
const TREAD_WHEEL := Color("8e867e")
const NUB := Color(0.62, 0.58, 0.54)
const PLATE := Color("fff8ea")
const PLATE_RIM := Color("e3d7c3")

# --- the room (2026-10-22) ---

## The floor is a room (the user, 2026-10-22: "move it [the charger] to the
## wall somewhere, with some marked area with a lightning"). Its back wall
## stands along the floor's top edge, WALL_TALL up, its top WALL_TOP deep
## seen from above; the two belts of the floor come in through a doorway
## each, hung with a strip curtain. The side walls show their tops only
## (WALL_TOP wide) and the front a low kerb. A station's tile is a painted
## pad; the bay's is the charging pad, yellow with a bolt, and its charger
## hangs on the wall over it, a cable down to the pad's socket.
##   wall_behind(x0, x1, doors)  what lies under the belts: the wall's
##                       shadow on the floor and the dark of each doorway.
##   wall(x0, x1, doors, clock)  the wall over the belts: its face from tile
##                       x `x0` to `x1`, cut at each doorway (a steel frame,
##                       the curtain's strips over the belt), its top, and a
##                       clock at tile x `clock`.
##   wall_sides(cols, rows)  the side walls' tops and the front kerb.
##   pad(kind)           a station's painted pad on its tile (origin the
##                       tile's corner): "bay" or "plain".
##   charger(), charger_lamp()  the wall unit over the bay, origin at the
##                       wall's foot under the bay's middle: the box, its
##                       cable down to the socket on the pad; the lamp is a
##                       white disc at LAMP_AT, tinted by the holder.
const WALL_TALL := 64.0
const WALL_TOP := 12.0
const KERB := 10.0
const WALL_FACE := Color("f5ecdc")
const WALL_LOW := Color("eadec8")
const WALL_SKIRT := Color("cdbfa7")
const WALL_TOPC := Color("ddd1ba")
const DOOR_FRAME := Color("8c969e")
const DOOR_DARK := Color("4a3d36")
const CURTAIN := Color(0.88, 0.86, 0.82, 0.8)
const PAD_IN := 0.08
const PAD_BAY := Color("fbeec3")
const PAD_BAY_LINE := Color("e9b63f")
const PAD_PLAIN_LINE := Color("d6cebf")
const BOLT := Color("e6a325")
const BOLT_DEEP := Color("b57b14")
const CHARGER_W := 46.0
const CHARGER_UP := 16.0
const CHARGER_TALL := 34.0
const LAMP_AT := Vector2(13.0, -(CHARGER_UP + CHARGER_TALL * 0.5))
const SOCKET_DOWN := 24.0
const CHARGE_LIT := Color("7ed47a")
const CHARGE_OFF := Color("6d7680")
## Past the walls: the outside, flat (the view shows it only past the side
## walls on an overscroll and under the pills over the back wall).
const OUTSIDE := Color("ded7cb")
const PANE := Color("d6e9ee")
const PANE_LIT := Color("eef7f8")
const SILL := Color("e8dfcc")

static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

static func _door_cuts(doors: Array) -> Array:
	var cuts: Array = []
	for d: float in doors:
		cuts.append([(d + 0.06) * K * 2.0, (d + 0.94) * K * 2.0])
	cuts.sort_custom(func(a: Array, c: Array) -> bool: return a[0] < c[0])
	return cuts

static func wall_behind(x0: float, x1: float, doors: Array) -> ArrayMesh:
	var key := "wallb%s|%s|%s" % [x0, x1, doors]
	if not _one.has(key):
		var b := Face.Builder.new()
		var l := x0 * K * 2.0
		var r := x1 * K * 2.0
		for strip: Array in [[0.0, 6.0, 0.11], [6.0, 14.0, 0.06], [14.0, 26.0, 0.025]]:
			b.polygon(_rect(l, strip[0], r, strip[1]), Color(SHADE, strip[2]))
		for c: Array in _door_cuts(doors):
			b.polygon(_rect(c[0], -WALL_TALL + 4.0, c[1], 0.0), DOOR_DARK)
		_one[key] = b.mesh()
	return _one[key]

static func wall(x0: float, x1: float, doors: Array, clock := -1.0, windows: Array = []) -> ArrayMesh:
	var key := "wall%s|%s|%s|%s|%s" % [x0, x1, doors, clock, windows]
	if not _one.has(key):
		var b := Face.Builder.new()
		var l := x0 * K * 2.0
		var r := x1 * K * 2.0
		var top := -WALL_TALL
		var cuts := _door_cuts(doors)
		var x := l
		for c: Array in cuts + [[r, r]]:
			if c[0] > x:
				b.polygon(_rect(x, top, c[0], 0.0), WALL_FACE)
				b.polygon(_rect(x, top * 0.46, c[0], 0.0), WALL_LOW)
				b.stroke(PackedVector2Array([Vector2(x, top * 0.46), Vector2(c[0], top * 0.46)]), 1.6, Color(WALL_SKIRT, 0.45), false, false)
				b.polygon(_rect(x, -8.0, c[0], 0.0), WALL_SKIRT)
			x = c[1]
		for c: Array in cuts:
			# the curtain's strips over the belt, then the frame round them
			var n := 7
			var w: float = (c[1] - c[0]) / n
			for i in n:
				var sx: float = c[0] + w * i + w * 0.15
				var drop := -7.0 if i % 2 == 0 else -4.0
				b.polygon(_rect(sx, top + 8.0, sx + w * 0.7, drop), CURTAIN)
			var frame := PackedVector2Array([Vector2(c[0], 0.0), Vector2(c[0], top + 4.0), Vector2(c[1], top + 4.0), Vector2(c[1], 0.0)])
			b.stroke(frame, 5.0, DOOR_FRAME, false, false)
			b.stroke(PackedVector2Array([Vector2(c[0] + 2.0, top + 2.0), Vector2(c[1] - 2.0, top + 2.0)]), 2.0, STEEL_LIT, false, false)
		for wx: float in windows:
			# a window: its frame, two panes with the sky in them, a sill
			var wl := wx * K * 2.0 - 30.0
			var frame := Face.Builder.round_rect(Vector2(wl, top + 9.0), Vector2(60.0, 30.0), 4.0)
			b.polygon(frame, WALL_SKIRT)
			b.polygon(_rect(wl + 3.0, top + 12.0, wl + 57.0, top + 36.0), PANE)
			b.polygon(_rect(wl + 3.0, top + 12.0, wl + 57.0, top + 20.0), PANE_LIT)
			b.stroke(PackedVector2Array([Vector2(wl + 30.0, top + 12.0), Vector2(wl + 30.0, top + 36.0)]), 3.0, WALL_SKIRT, false, false)
			b.polygon(_rect(wl - 2.0, top + 36.0, wl + 62.0, top + 40.0), SILL)
			b.polygon(_rect(wl - 2.0, top + 40.0, wl + 62.0, top + 43.0), Color(SHADE, 0.12))
		b.polygon(_rect(l, top - WALL_TOP, r, top), WALL_TOPC)
		b.stroke(PackedVector2Array([Vector2(l, top), Vector2(r, top)]), 2.0, Color(WALL_SKIRT, 0.7), false, false)
		if clock >= 0.0:
			var cc := Vector2(clock * K * 2.0, top * 0.66)
			b.disc(cc + Vector2(1.5, 2.0), 15.0, Color(SHADE, 0.3))
			b.disc(cc, 15.0, WALL_SKIRT.darkened(0.25))
			b.disc(cc, 12.5, Color.WHITE)
			b.stroke(PackedVector2Array([cc, cc + Vector2(0.0, -8.0)]), 2.2, INK)
			b.stroke(PackedVector2Array([cc, cc + Vector2(5.5, 3.0)]), 2.2, INK)
			b.disc(cc, 1.6, INK)
		_one[key] = b.mesh()
	return _one[key]

static func wall_sides(cols: int, rows: int) -> ArrayMesh:
	var key := "sides%d|%d" % [cols, rows]
	if not _one.has(key):
		var b := Face.Builder.new()
		var w := cols * K * 2.0
		var h := rows * K * 2.0
		var top := -WALL_TALL - WALL_TOP
		for side: Array in [[-WALL_TOP, 0.0, 0.0, 7.0], [w, w + WALL_TOP, w - 7.0, w]]:
			b.polygon(_rect(side[0], top, side[1], h + KERB), WALL_TOPC)
			b.polygon(_rect(side[2], 0.0, side[3], h), Color(SHADE, 0.07))
		b.polygon(_rect(-WALL_TOP, h, w + WALL_TOP, h + KERB), GROUND["neutral"]["lip"])
		b.polygon(_rect(-WALL_TOP, h, w + WALL_TOP, h + 3.0), GROUND["neutral"]["lip_lit"])
		_one[key] = b.mesh()
	return _one[key]

static func pad(kind: String) -> ArrayMesh:
	var key := "pad_" + kind
	if not _one.has(key):
		var b := Face.Builder.new()
		var side := K * 2.0
		var rr := Face.Builder.round_rect(Vector2(PAD_IN, PAD_IN) * side, Vector2(1.0 - 2.0 * PAD_IN, 1.0 - 2.0 * PAD_IN) * side, 14.0)
		if kind == "bay":
			b.polygon(rr, PAD_BAY)
			b.stroke(rr, 7.0, PAD_BAY_LINE, true, false)
			# the hazard dashes along the line
			var run := 0.0
			var n := rr.size()
			for i in n:
				var p0 := rr[i]
				var p1 := rr[(i + 1) % n]
				var seg := p0.distance_to(p1)
				var t := 0.0
				while t < seg:
					var period := fmod(run + t, 34.0)
					if period < 17.0:
						var t1 := minf(seg, t + 17.0 - period)
						b.stroke(PackedVector2Array([p0.lerp(p1, t / seg), p0.lerp(p1, t1 / seg)]), 7.0, Color("6b655c"), false, false)
						t = t1
					else:
						t = minf(seg, t + 34.0 - period)
				run += seg
			var c := Vector2(side * 0.5, side * 0.5)
			_bolt(b, c + Vector2(2.0, 2.5), 2.4, Color(BOLT_DEEP, 0.55))
			_bolt(b, c, 2.4, BOLT)
		else:
			b.polygon(rr, Color(1.0, 1.0, 1.0, 0.4))
			b.stroke(rr, 4.0, PAD_PLAIN_LINE, true, false)
		_one[key] = b.mesh()
	return _one[key]

static func charger() -> ArrayMesh:
	if not _one.has("charger"):
		var b := Face.Builder.new()
		var top := -(CHARGER_UP + CHARGER_TALL)
		var box := Face.Builder.round_rect(Vector2(-CHARGER_W * 0.5, top), Vector2(CHARGER_W, CHARGER_TALL), 7.0)
		b.polygon(Face.Builder.round_rect(Vector2(-CHARGER_W * 0.5 + 2.0, top + 3.0), Vector2(CHARGER_W, CHARGER_TALL), 7.0), Color(SHADE, 0.22))
		b.polygon(box, STEEL)
		b.polygon(Face.Builder.round_rect(Vector2(-CHARGER_W * 0.5, top), Vector2(CHARGER_W, 7.0), 4.0), STEEL_LIT)
		b.polygon(_rect(-CHARGER_W * 0.5 + 4.0, -CHARGER_UP - 4.0, CHARGER_W * 0.5 - 4.0, -CHARGER_UP), STEEL_DEEP)
		# a window with a small bolt in it, and the lamp's rim
		var win := Face.Builder.round_rect(Vector2(-CHARGER_W * 0.5 + 6.0, top + 11.0), Vector2(20.0, 15.0), 3.0)
		b.polygon(win, Color("3a3f44"))
		_bolt(b, Vector2(-CHARGER_W * 0.5 + 16.0, top + 18.5), 0.5, BOLT)
		b.disc(LAMP_AT, 6.5, STEEL_DEEP)
		# the cable down the wall and over the floor to the socket
		var cable := PackedVector2Array([Vector2(0.0, -CHARGER_UP), Vector2(0.0, -4.0), Vector2(-3.0, 8.0), Vector2(0.0, SOCKET_DOWN - 4.0)])
		b.stroke(cable, 5.0, Color("4a4542"), false, true)
		b.stroke(cable, 1.6, Color("6d6762"), false, false)
		var socket := Face.Builder.round_rect(Vector2(-9.0, SOCKET_DOWN - 6.0), Vector2(18.0, 12.0), 3.0)
		b.polygon(socket, Color("3a3f44"))
		b.polygon(_rect(-4.0, SOCKET_DOWN - 2.0, 4.0, SOCKET_DOWN + 1.0), Color("6d7680"))
		_one["charger"] = b.mesh()
	return _one["charger"]

static func charger_lamp() -> ArrayMesh:
	if not _one.has("charger_lamp"):
		var b := Face.Builder.new()
		b.disc(LAMP_AT, 4.6, Color.WHITE)
		b.disc(LAMP_AT + Vector2(-1.4, -1.4), 1.6, Color(1.0, 1.0, 1.0, 0.7))
		_one["charger_lamp"] = b.mesh()
	return _one["charger_lamp"]

## A grey square standing on (0, 0): a small block, lit on its top and on
## the side that looks down the screen. `shade` lays its shadow under it (not
## for one in a hand).
static func square(shade := true) -> ArrayMesh:
	var key := "square%d" % int(shade)
	if not _one.has(key):
		var b := Face.Builder.new()
		if shade:
			_ground_shade(b, [[Vector2.ZERO, Vector2(SQUARE_HALF, SQUARE_HALF), SQUARE_TALL]])
		_square_into(b, Vector2.ZERO, SQUARE_HALF, 0.0, SQUARE_TALL)
		_one[key] = b.mesh()
	return _one[key]

## A square about `c` (tiles), `half` its side, from `z0` up to `z1`.
static func _square_into(b: Face.Builder, c: Vector2, half: float, z0: float, z1: float) -> void:
	_block(b, c, Vector2(half, half), z0, z1, [SQUARE_LIT, SQUARE_C, SQUARE_DEEP])
	b.stroke(PackedVector2Array([_p(c + Vector2(-half, half), z1), _p(c + Vector2(half, half), z1), _p(c + Vector2(half, -half), z1)]),
		1.6, SQUARE_LIT.lightened(0.3), false, false)

## A box of card standing on (0, 0), open at the top, `n` squares (0..4) in
## it poking over its rim, the dark of its inside and its two far walls seen
## down the opening (as the market's hatch is seen). `shade`: its shadow.
static func box(n: int, shade := true) -> ArrayMesh:
	n = clampi(n, 0, 4)
	var key := n * 2 + int(shade)
	if not _boxes.has(key):
		var b := Face.Builder.new()
		var h := BOX_HALF
		if shade:
			_ground_shade(b, [[Vector2.ZERO, Vector2(h, h), BOX_TALL]])
		var hole := PackedVector2Array()
		for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			hole.append(_p(o * h * 0.9, BOX_TALL))
		# the rim's top, then the dark inside and the two far walls in it
		var top := PackedVector2Array()
		for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			top.append(_p(o * h, BOX_TALL))
		b.polygon(top, CARD_LIT)
		b.polygon(hole, CARD_INK)
		for wall: Array in [[Vector2(-1, -1), Vector2(1, -1), CARD_INSIDE], [Vector2(-1, -1), Vector2(-1, 1), CARD_INSIDE.darkened(0.18)]]:
			var from: Vector2 = wall[0] * h * 0.9
			var to: Vector2 = wall[1] * h * 0.9
			var face := PackedVector2Array([_p(from, BOX_TALL), _p(to, BOX_TALL), _p(to, BOX_TALL - BOX_DEEP), _p(from, BOX_TALL - BOX_DEEP)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(face, hole):
				b.polygon(part, wall[2])
		# the squares in it, the far ones first
		var seats: Array[Vector2] = []
		for i in n:
			seats.append(IN_AT[i])
		seats.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
		for c: Vector2 in seats:
			_square_into(b, c, IN_HALF, IN_SEAT, IN_SEAT + IN_TALL)
		# its two near walls over them, a fold down each corner and the lit rim
		b.polygon(PackedVector2Array([_p(Vector2(-h, h)), _p(Vector2(h, h)), _p(Vector2(h, h), BOX_TALL), _p(Vector2(-h, h), BOX_TALL)]), CARD_LIT.darkened(0.04))
		b.polygon(PackedVector2Array([_p(Vector2(h, h)), _p(Vector2(h, -h)), _p(Vector2(h, -h), BOX_TALL), _p(Vector2(h, h), BOX_TALL)]), CARD)
		b.stroke(PackedVector2Array([_p(Vector2(h, h), 1.0), _p(Vector2(h, h), BOX_TALL)]), 1.6, Color(CARD_INK, 0.5), false, false)
		b.stroke(PackedVector2Array([_p(Vector2(-h * 0.3, h), BOX_TALL - 2.0), _p(Vector2(h * 0.3, h), BOX_TALL - 2.0)]), 3.0, Color(CARD_INK, 0.35), false, false)
		b.stroke(PackedVector2Array([_p(Vector2(-h, h), BOX_TALL), _p(Vector2(h, h), BOX_TALL), _p(Vector2(h, -h), BOX_TALL)]), 2.0, CARD_LIT.lightened(0.2), false, false)
		_boxes[key] = b.mesh()
	return _boxes[key]

## The mesh for an item of the sim's: a square or a box of its `n`.
static func item(it: Dictionary, shade := true) -> ArrayMesh:
	return box(int(it.get("n", 0)), shade) if String(it.get("kind", "")) == "box" else square(shade)

## The box stack, standing on (0, 0): STACK_N empty boxes heaped as the
## land heaped its logs (`HEAP[heap_of(n)]`, rows from the ground up, each
## row in the hollows of the one under it), one shadow under them all.
static func stack() -> ArrayMesh:
	if not _one.has("stack"):
		var b := Face.Builder.new()
		var rows: Array = HEAP[heap_of(STACK_N)]
		var w := BOX_HALF * 4.0 * K * STACK_K
		var half := float(rows[0]) * BOX_HALF * STACK_K
		_ground_shade(b, [[Vector2.ZERO, Vector2(half, half) * 0.75, BOX_TALL * rows.size() * STACK_K]])
		for j in rows.size():
			var m: int = rows[j]
			for i in m:
				var at_ := Vector2((i - (m - 1) * 0.5) * w, -BOX_TALL * STACK_K * j)
				b.append(box(0, false), Transform2D(0.0, Vector2(STACK_K, STACK_K), 0.0, at_))
		_one["stack"] = b.mesh()
	return _one["stack"]

## The pack table, standing on (0, 0): the land's tray (the joiner's way
## out), alone on its tile and made big enough for a box to rest on it at
## TABLE_TOP.
static func table() -> ArrayMesh:
	if not _one.has("table"):
		var b := Face.Builder.new()
		_ground_shade(b, [[Vector2.ZERO, Vector2(TABLE_ALONG, TABLE_ACROSS), TABLE_TALL]])
		_tray(b, Vector2.ZERO, Vector2(1.0, 0.0), TABLE_ALONG, TABLE_ACROSS, TABLE_TALL)
		_one["table"] = b.mesh()
	return _one["table"]

## A robot standing on (0, 0) facing `quarter` (0 +x, 1 +y, ...; a Turn
## swings it between): its shadow, two capsule treads along the way it
## faces, a chunky round body white for the holder's tint (a bumper round
## its foot, a lid with a soft ring), and a short nub with a gold bulb on
## top. The body is round and its face is always toward the viewer (a "?"
## or a sleeping face is a signal to read at any facing), so the treads and
## the nose (`nose`) are what turn. The face is `face` (2026-10-22, the
## room: redrawn cozy, the user: "polish bots way more").
static func robot(quarter := 0.0) -> ArrayMesh:
	var step := posmod(roundi(quarter * TREAD_STEPS), 4 * TREAD_STEPS)
	var key := "robot%d" % step
	if not _one.has(key):
		var a := float(step) / TREAD_STEPS * PI * 0.5
		var u := Vector2(cos(a), sin(a))
		var v := Vector2(-u.y, u.x)
		var b := Face.Builder.new()
		var r := BODY_R
		# a soft round shadow about its footprint, thrown a little right and
		# down as the land's shadows fall
		var reach := r * K * 2.0 * 1.3
		_glow(b, SHADOW_AT, reach, reach * 0.8, Color(CAST.r, CAST.g, CAST.b), 0.55)
		# the far tread (or both, side by side), the body, then the near one
		# over its foot with its wheels
		var sides := [-v * TREAD_OUT, v * TREAD_OUT]
		sides.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
		var near: Array = sides.filter(func(p: Vector2) -> bool: return p.y > 0.05)
		for c: Vector2 in sides:
			if not near.has(c):
				_tread(b, c, u, false)
		var white := [Color.WHITE, Color.WHITE, Color(0.94, 0.94, 0.94), Color(0.83, 0.83, 0.83)]
		_drum(b, Vector2.ZERO, r, BODY_FOOT, BODY_TOP, white)
		# a bumper round the foot of its front half
		b.stroke(_round(Vector2.ZERO, r * 1.02, BODY_FOOT + 3.0, 0.08, PI - 0.08, 16), 6.0, Color(0.8, 0.8, 0.8), false, true)
		# the lid, a soft ring in from its rim
		b.polygon(_round(Vector2.ZERO, r, BODY_TOP, 0.0, TAU, 24), Color.WHITE)
		b.stroke(_round(Vector2.ZERO, r * 0.8, BODY_TOP, 0.0, TAU, 24), 2.4, Color(0.87, 0.87, 0.87), true, false)
		for c: Vector2 in near:
			_tread(b, c, u, true)
		# the nub and its bulb
		b.stroke(PackedVector2Array([_p(Vector2.ZERO, BODY_TOP - 1.0), _p(Vector2.ZERO, LAMP_UP - 6.0)]), 6.0, NUB)
		b.disc(_p(Vector2.ZERO, LAMP_UP), 7.5, GOLD_DEEP)
		b.disc(_p(Vector2.ZERO, LAMP_UP) + Vector2(-0.8, -0.8), 6.2, GOLD)
		b.disc(_p(Vector2.ZERO, LAMP_UP) + Vector2(-2.6, -2.6), 2.2, GOLD_HI)
		_one[key] = b.mesh()
	return _one[key]

## One tread seated at `c` (tiles) along `u`: a dark capsule, a lighter
## stripe along its top, and on a near one its wheels.
static func _tread(b: Face.Builder, c: Vector2, u: Vector2, wheels: bool) -> void:
	var ends := PackedVector2Array([_p(c - u * TREAD_HALF, TREAD_H), _p(c + u * TREAD_HALF, TREAD_H)])
	b.stroke(ends, TREAD_W, TREAD, false, true)
	var lit := PackedVector2Array([_p(c - u * TREAD_HALF * 0.9, TREAD_H + 3.5), _p(c + u * TREAD_HALF * 0.9, TREAD_H + 3.5)])
	b.stroke(lit, TREAD_W * 0.4, TREAD_LIT, false, true)
	if wheels:
		for k in 3:
			b.disc(_p(c + u * (-TREAD_HALF * 0.62 + TREAD_HALF * 0.62 * k), TREAD_H - 1.0), 2.8, TREAD_WHEEL)

## The chevron on the floor just past a robot's treads, pointing +x from
## (0, 0), NOSE_OUT out: drawn at NOSE_AT turned to the way it faces.
static func nose() -> ArrayMesh:
	if not _one.has("nose"):
		var b := Face.Builder.new()
		var head := PackedVector2Array([Vector2(NOSE_OUT - 7.0, -7.0), Vector2(NOSE_OUT, 0.0), Vector2(NOSE_OUT - 7.0, 7.0)])
		b.stroke(head, 6.0, Color(NUB, 0.9))
		b.stroke(head, 2.6, GOLD)
		_one["nose"] = b.mesh()
	return _one["nose"]

## Its face plate and on it its eyes and mouth by `stuck` (the sim's: "",
## "?", "flat", "nocell"), from the house's face builder: content, puzzled,
## asleep, worried. On the front of its body, about FACE_AT; the plate is
## cream and not tinted with the body (it is its own mesh).
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
		var plate := Face.Builder.round_rect(FACE_AT + Vector2(-21.0, -15.0), Vector2(42.0, 31.0), 11.0)
		b.polygon(plate, PLATE)
		b.stroke(plate, 2.0, PLATE_RIM, true, false)
		Face.face_parts(b, FACE_R, FACE_AT + Vector2(0.0, 1.0), INK, eye, expr)
		_faces[stuck] = b.mesh()
	return _faces[stuck]

## The dot a robot wears on its shoulder while its program has a fault the
## player can see (the screen's `robot_fault`): the red of the old chip's
## dot in a white ring, its middle on (0, 0).
static func fault_dot() -> ArrayMesh:
	var b := Face.Builder.new()
	b.disc(Vector2(0.0, 1.5), 10.0, Color(INK, 0.16))
	b.disc(Vector2.ZERO, 10.0, Color.WHITE)
	b.disc(Vector2.ZERO, 6.8, Pal.BAD)
	return b.mesh()

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
## red under.
static func battery_tone(f: float) -> Color:
	return CHARGE_HI if f > 0.5 else (CHARGE_MID if f > 0.25 else CHARGE_LOW)

## A lightning bolt about `c`, `s` times 20 view units tall.
static func _bolt(b: Face.Builder, c: Vector2, s: float, colour: Color) -> void:
	var pts := PackedVector2Array([Vector2(3.0, -12.0), Vector2(-7.0, 2.0), Vector2(-0.5, 2.0), Vector2(-3.0, 12.0),
		Vector2(7.0, -2.0), Vector2(0.5, -2.0), Vector2(4.0, -12.0)])
	for i in pts.size():
		pts[i] = c + pts[i] * s
	b.polygon(pts, colour)

## The gold pill's coin, radius `r` about `c`.
static func _coin_into(b: Face.Builder, c: Vector2, r: float) -> void:
	b.disc(c + Vector2(0.0, r * 0.12), r, GOLD_DEEP)
	b.disc(c, r, GOLD)
	b.stroke(Face.Builder.ring(c, r * 0.72, r * 0.72), r * 0.1, GOLD_DEEP, true)
	b.stroke(PackedVector2Array([c + Vector2(0.0, -r * 0.34), c + Vector2(0.0, r * 0.34)]), r * 0.16, GOLD_DEEP)
	b.stroke(Face.Builder.arc_points(c, r * 0.86, PI * 1.1, PI * 1.45), r * 0.12, GOLD_HI)

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

## What carries a belt's bed off the ground, in view units about the middle
## of its tile: the shade it lays on the turf, a short post under each
## corner, and the two edges of the bed the eye sees, BELT_DEEP thick (the
## one looking down and left lit, the one looking down and right in shade).
## The same at every facing and every turn of the view, so one MultiMesh of
## it lies under all the belts; a belt next to it covers the edge they
## share. The user, 2026-10-10: the belt "should be like the convey from"
## a factory game they named, "not directly on the ground".
static func belt_under() -> ArrayMesh:
	if not _one.has("belt_under"):
		var b := Face.Builder.new()
		var shade := PackedVector2Array()
		for o: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
			shade.append(at(o * 0.94) + Vector2(5.0, 2.0))
		b.polygon(shade, Color(CAST, 0.3))
		var wood := [PLANK, PLANK.lightened(0.08), PLANK_DEEP.darkened(0.12)]
		for o: Vector2 in [Vector2(-0.36, -0.36), Vector2(0.36, -0.36), Vector2(-0.36, 0.36), Vector2(0.36, 0.36)]:
			_block(b, o, Vector2(0.055, 0.055), 0.0, BELT_UP - BELT_DEEP, wood)
		_block(b, Vector2.ZERO, Vector2(0.5, 0.45), BELT_UP - BELT_DEEP, BELT_UP, [PLANK_DEEP, PLANK.darkened(0.06), PLANK_DEEP.darkened(0.18)])
		_one["belt_under"] = b.mesh()
	return _one["belt_under"]

## One belt tile in tile space, (0, 0) to (1, 1), travelling toward +x: a
## bed of wooden slats between two rails. Flat, and any turn of it is right;
## it is drawn BELT_UP above the ground (`flat` then `BELT_LIFT`), over
## `belt_under`, and what rides it is lifted as much. Drawn under `flat(tile,
## facing)` with `belt_material()`, by draw_mesh or as the instances of one
## MultiMesh for the whole land. Its UV says where on the belt a point is
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

## `belt_under` for a bend: the shade, the posts and the bed's seen edge
## following the arc. `corner` is the corner of its tile the bend turns
## about, (1, 1), (-1, 1), (-1, -1) or (1, -1) from the tile's middle on the
## grid as it is drawn (for `flat(tile, f)`: DIRS[f] + DIRS[f + 1], or
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
			shade.append(at(c + Vector2(cos(a), sin(a)) * 0.92) + Vector2(5.0, 2.0))
		for i in range(n, -1, -1):
			var a := from + PI * 0.5 * i / n
			shade.append(at(c + Vector2(cos(a), sin(a)) * 0.08) + Vector2(5.0, 2.0))
		b.polygon(shade, Color(CAST, 0.3))
		var wood := [PLANK, PLANK.lightened(0.08), PLANK_DEEP.darkened(0.12)]
		for o: Vector2 in [Vector2(-0.36, -0.36), Vector2(0.36, -0.36), Vector2(-0.36, 0.36), Vector2(0.36, 0.36)]:
			# no post out in the open corner the bed does not cover
			if o.sign() != -Vector2(corner):
				_block(b, o, Vector2(0.055, 0.055), 0.0, BELT_UP - BELT_DEEP, wood)
		var lit := PLANK.darkened(0.06)
		var dark := PLANK_DEEP.darkened(0.18)
		var top := BELT_UP
		var foot := BELT_UP - BELT_DEEP
		# the outer edge, where it looks at the eye
		for i in n:
			var a0 := from + PI * 0.5 * i / n
			var a1 := from + PI * 0.5 * (i + 1) / n
			var mid := Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5))
			if mid.y <= 0.02:
				continue
			var p0 := c + Vector2(cos(a0), sin(a0)) * 0.95
			var p1 := c + Vector2(cos(a1), sin(a1)) * 0.95
			b.polygon(PackedVector2Array([_p(p0, top), _p(p1, top), _p(p1, foot), _p(p0, foot)]),
				lit.lerp(dark, clampf(mid.x / (absf(mid.x) + absf(mid.y)), 0.0, 1.0)))
		# its two ends, on the tile's sides: seen where no neighbour stands in front
		for k in 2:
			var a := from + PI * 0.5 * k
			var d := Vector2(cos(a), sin(a))
			var out := (Vector2(corner) - d * Vector2(corner).dot(d)).sign()
			if out.y > 0.0:
				b.polygon(PackedVector2Array([_p(c + d * 0.05, top), _p(c + d * 0.95, top), _p(c + d * 0.95, foot), _p(c + d * 0.05, foot)]),
					lit if out.y > 0.0 else dark)
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

## How high over a belt's bed a bridge carries what crosses it, and how far
## from the tile's middle (tiles) its deck is level before it slopes down
## to the beds at its two ends.
const BRIDGE_UP := 36.0
const BRIDGE_FLAT := 0.2

## How high over the ground a thing crossing a bridge rides, `along` 0 to 1
## from the side it came by to the side it leaves by.
static func bridge_lift(along: float) -> float:
	var off := absf(along - 0.5)
	return BELT_UP + BRIDGE_UP * (1.0 - smoothstep(BRIDGE_FLAT, 0.5, off))

## A bridge's deck, in view units about the middle of its tile: a short
## span of planks across the belt that lies along `facing` as seen, up from
## the bed at one side, level over the middle and down to the bed at the
## other, on four posts that stand clear of the belt under it. Drawn among
## what stands, over what rides under it; what rides over it is drawn after
## it at `bridge_lift`. The same for a facing and the one opposite.
static func bridge(facing: int) -> ArrayMesh:
	var key := "bridge%d" % posmod(facing, 2)
	if _one.has(key):
		return _one[key]
	var b := Face.Builder.new()
	var a := Vector2(DIRS[posmod(facing, 2)])          # the belt under it
	var s := Vector2(DIRS[posmod(facing, 2) + 1])      # the way across
	var w := 0.3
	var top := BELT_UP + BRIDGE_UP
	var wood := [PLANK.lightened(0.1), PLANK, PLANK_DEEP]
	# the posts first: the further pair, then the deck, then the nearer pair
	var posts: Array[Vector2] = []
	for i: float in [-1.0, 1.0]:
		for j: float in [-1.0, 1.0]:
			posts.append(s * 0.2 * i + a * 0.44 * j)
	posts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
	for p: Vector2 in posts.slice(0, 2):
		_block(b, p, Vector2(0.045, 0.045), 0.0, top - 4.0, wood)
	# the deck in five stretches, each a quad, lit where it is level
	var stops := [-0.5, -0.36, -BRIDGE_FLAT, BRIDGE_FLAT, 0.36, 0.5]
	for k in 5:
		var t0: float = stops[k]
		var t1: float = stops[k + 1]
		var h0 := bridge_lift(t0 + 0.5)
		var h1 := bridge_lift(t1 + 0.5)
		var tone := Color("f3deb4") if k == 2 else (Color("d9bb86") if (s.x + s.y) * (k - 2) < 0 else Color("e8cf9e"))
		b.polygon(PackedVector2Array([_p(s * t0 - a * w, h0), _p(s * t1 - a * w, h1), _p(s * t1 + a * w, h1), _p(s * t0 + a * w, h0)]), tone)
		# its edge toward the eye, a board thick
		var e := a * w * (1.0 if a.y >= 0.0 else -1.0)
		b.polygon(PackedVector2Array([_p(s * t0 + e, h0), _p(s * t1 + e, h1), _p(s * t1 + e, h1 - 9.0), _p(s * t0 + e, h0 - 9.0)]), PLANK_DEEP.darkened(0.08))
	for k in 9:
		var t := -0.44 + 0.11 * k
		var h := bridge_lift(t + 0.5)
		b.stroke(PackedVector2Array([_p(s * t - a * w, h), _p(s * t + a * w, h)]), 1.8, Color(PLANK_DEEP, 0.6), false, false)
	# a rail along each edge
	for j: float in [-1.0, 1.0]:
		var rail := PackedVector2Array()
		for k in 11:
			var t := -0.5 + 0.1 * k
			rail.append(_p(s * t + a * w * j, bridge_lift(t + 0.5) + 3.0))
		b.stroke(rail, 5.0, Color("8a5f38"), false, false)
		b.stroke(rail, 1.4, PLANK.lightened(0.2), false, false)
	for p: Vector2 in posts.slice(2):
		_block(b, p, Vector2(0.045, 0.045), 0.0, top - 4.0, wood)
	_one[key] = b.mesh()
	return _one[key]

# --- what is built ---

## A point of a building: `t` tiles from its origin along the ground, `h`
## view units up.
static func _p(t: Vector2, h := 0.0) -> Vector2:
	return at(t) + Vector2(0.0, -h)

## The shadow of a building on the ground, for its mesh's first shape: one
## piece under all its `blocks` ([middle, half its size] in tiles, then how
## tall), thrown right as the trees throw theirs, half as far.
static func _ground_shade(b: Face.Builder, blocks: Array) -> void:
	var pts := PackedVector2Array()
	for blk: Array in blocks:
		var c: Vector2 = blk[0]
		var half: Vector2 = blk[1]
		var throw: Vector2 = CAST_ALONG * float(blk[2]) * 0.6
		for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p := at(c + half * o)
			pts.append(p)
			pts.append(p + throw)
	var hull := Geometry2D.convex_hull(pts)
	hull.remove_at(hull.size() - 1)
	b.polygon(hull, CAST)

## A block standing on the ground about `c`, `half` its size (tiles), from
## `z0` up to `z1`: its front (the side looking down the screen, in the
## sun), its +x side (in shade; seen edge on from above, so nothing of it
## shows top-down) and its top.
## `tones`: [top, lit, shaded].
## `_block` laid along `u` (a unit floor vector) instead of +x: its sides
## that face the viewer (+y on the floor), then its top.
static func _turned_block(b: Face.Builder, c: Vector2, u: Vector2, half: Vector2, z0: float, z1: float, tones: Array) -> void:
	var v := Vector2(-u.y, u.x)
	var q := [c - u * half.x - v * half.y, c + u * half.x - v * half.y, c + u * half.x + v * half.y, c - u * half.x + v * half.y]
	for k in 4:
		var p0: Vector2 = q[k]
		var p1: Vector2 = q[(k + 1) % 4]
		var n := (p0 + p1) * 0.5 - c
		if n.y <= 0.001:
			continue
		b.polygon(PackedVector2Array([_p(p0, z0), _p(p1, z0), _p(p1, z1), _p(p0, z1)]), tones[2] if n.normalized().x > 0.5 else tones[1])
	b.polygon(PackedVector2Array([_p(q[0], z1), _p(q[1], z1), _p(q[2], z1), _p(q[3], z1)]), tones[0])

static func _block(b: Face.Builder, c: Vector2, half: Vector2, z0: float, z1: float, tones: Array) -> void:
	var x0 := c.x - half.x
	var x1 := c.x + half.x
	var y0 := c.y - half.y
	var y1 := c.y + half.y
	b.polygon(PackedVector2Array([_p(Vector2(x0, y1), z0), _p(Vector2(x1, y1), z0), _p(Vector2(x1, y1), z1), _p(Vector2(x0, y1), z1)]), tones[1])
	b.polygon(PackedVector2Array([_p(Vector2(x1, y1), z0), _p(Vector2(x1, y0), z0), _p(Vector2(x1, y0), z1), _p(Vector2(x1, y1), z1)]), tones[2])
	b.polygon(PackedVector2Array([_p(Vector2(x0, y0), z1), _p(Vector2(x1, y0), z1), _p(Vector2(x1, y1), z1), _p(Vector2(x0, y1), z1)]), tones[0])
	b.stroke(PackedVector2Array([_p(Vector2(x1, y1), z0 + 1.0), _p(Vector2(x1, y1), z1)]), 1.6, Color(tones[2], 0.6), false, false)

## The lines of laid brick or stone on the wall from `a0` to `a1` (tiles),
## `z0` up to `z1`: `rows` courses, the joints of each half a brick along
## from the last.
static func _courses(b: Face.Builder, a0: Vector2, a1: Vector2, z0: float, z1: float, rows: int, colour: Color, brick := 15.0) -> void:
	var cols := maxi(2, int(at(a1 - a0).length() / brick))
	for r in range(1, rows):
		var z := lerpf(z0, z1, float(r) / rows)
		b.stroke(PackedVector2Array([_p(a0, z), _p(a1, z)]), 1.4, colour, false, false)
	for r in rows:
		var za := lerpf(z0, z1, float(r) / rows)
		var zb := lerpf(z0, z1, float(r + 1) / rows)
		for k in range(1, cols + 1):
			var u := (float(k) - (0.5 if r % 2 == 0 else 0.0)) / cols
			if u < 0.97:
				var q := a0.lerp(a1, u)
				b.stroke(PackedVector2Array([_p(q, za), _p(q, zb)]), 1.4, colour, false, false)

## A block of brick or stone: `_block` with its courses on both sides.
static func _wall(b: Face.Builder, c: Vector2, half: Vector2, z0: float, z1: float, tones: Array, rows: int, joint: Color, brick := 15.0) -> void:
	_block(b, c, half, z0, z1, tones)
	_courses(b, c + Vector2(-half.x, half.y), c + half, z0, z1, rows, joint, brick)

## Points of a circle of `r` tiles lying `z` up about `c`, by the angle on
## the screen: 0 its right, a quarter turn its front.
static func _round(c: Vector2, r: float, z: float, from := 0.0, to := TAU, n := 22) -> PackedVector2Array:
	var rx := r * K * 2.0
	var o := _p(c, z)
	var pts := PackedVector2Array()
	pts.resize(n + 1)
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		pts[i] = o + Vector2(cos(a) * rx, sin(a) * rx * DEEP)
	return pts

## A round thing standing about `c`, `r` tiles across its half, from `z0` up
## to `z1`: a post, a flue, a stack. `tones`: [top, lit, body, shaded].
static func _drum(b: Face.Builder, c: Vector2, r: float, z0: float, z1: float, tones: Array) -> void:
	var body := _round(c, r, z0, 0.0, PI)
	body.append_array(_round(c, r, z1, PI, TAU))
	b.polygon(body, tones[2])
	for strip: Array in [[PI * 0.62, PI, tones[1]], [0.0, PI * 0.36, tones[3]]]:
		var pts := _round(c, r, z0, strip[0], strip[1], 8)
		var top := _round(c, r, z1, strip[0], strip[1], 8)
		top.reverse()
		pts.append_array(top)
		b.polygon(pts, strip[2])
	var lid := _round(c, r, z1)
	lid.remove_at(lid.size() - 1)
	b.fan(lid, tones[0])

## Half a size for a block lying along `d`: `along` it and `across`.
static func _half(d: Vector2, along: float, across: float) -> Vector2:
	return Vector2(along, across) if d.x != 0.0 else Vector2(across, along)

## The way out, the same on every module of the land: a low wooden tray
## about `c`, lying along `d`, a rim round it; `along`, `across` its half in
## tiles and `tall` its height (the land's was 0.15 by 0.2 and 8 high).
static func _tray(b: Face.Builder, c: Vector2, d: Vector2, along := 0.15, across := 0.2, tall := 8.0) -> void:
	var half := _half(d, along, across)
	_block(b, c, half, 0.0, tall, [PLANK.lightened(0.2), PLANK, PLANK_DEEP])
	var rim := PackedVector2Array()
	for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		rim.append(_p(c + half * o * 0.82, tall))
	b.polygon(rim, PLANK_DEEP.lightened(0.1))
	b.stroke(rim, 1.6, PLANK.lightened(0.3), true)

## The engine, 1 by 1, the origin the middle of its tile on the ground: a
## vertical boiler of riveted iron on a brick foot, a short stack on it, and
## on its front the bearing its flywheel turns on
## (ENGINE_WHEEL is the hub: draw `wheel()` there under `on_wall`). It has
## no facing. The land's engine; the floor's charging bay since 2026-10-21,
## its wheel turning while a robot charges.
static func engine() -> ArrayMesh:
	if not _one.has("engine"):
		var b := Face.Builder.new()
		var h := 0.36
		_ground_shade(b, [[Vector2.ZERO, Vector2(h, h), 78.0]])
		_wall(b, Vector2.ZERO, Vector2(h, h), 0.0, 14.0, [BRICK_LIT.lightened(0.08), BRICK_LIT, BRICK_SHADE], 2, MORTAR)
		var iron := [IRON_LIT.lightened(0.06), IRON_LIT, IRON, IRON_SHADE]
		_drum(b, Vector2(-0.05, -0.05), 0.25, 14.0, 72.0, iron)
		# two brass bands and a row of rivets round the boiler
		for z: float in [26.0, 58.0]:
			b.stroke(_round(Vector2(-0.05, -0.05), 0.252, z, 0.06, PI - 0.06, 14), 3.4, GOLD_DEEP, false, false)
			b.stroke(_round(Vector2(-0.05, -0.05), 0.252, z + 1.2, PI * 0.6, PI - 0.1, 6), 1.4, GOLD_HI, false, false)
		for i in 7:
			var a := 0.25 + (PI - 0.5) * i / 6.0
			var p := _round(Vector2(-0.05, -0.05), 0.252, 42.0, a, a, 1)[0]
			b.disc(p, 1.7, IRON_SHADE.darkened(0.1))
		# the dome and the stack
		var lid := _round(Vector2(-0.05, -0.05), 0.25, 72.0)
		lid.remove_at(lid.size() - 1)
		b.fan(lid, IRON_LIT)
		b.ellipse(_p(Vector2(-0.05, -0.05), 76.0), 0.4 * K, 0.4 * K * 0.9, IRON_LIT.lightened(0.1))
		_drum(b, Vector2(-0.1, -0.1), 0.07, 74.0, 100.0, [HOLLOW, IRON_LIT, IRON, IRON_SHADE])
		b.stroke(_round(Vector2(-0.1, -0.1), 0.09, 97.0, 0.0, PI, 10), 3.0, IRON_SHADE, false, false)
		# a gauge on its lit side
		var g := _round(Vector2(-0.05, -0.05), 0.252, 46.0, PI * 0.78, PI * 0.78, 1)[0]
		b.disc(g, 6.0, GOLD_DEEP)
		b.disc(g, 4.4, Color("f6f0df"))
		b.stroke(PackedVector2Array([g, g + Vector2(2.4, -2.6)]), 1.2, Color("7a2f22"))
		# the cylinder along the lit wall, and the bearing the wheel hangs on
		_block(b, Vector2(-0.12, h - 0.02), Vector2(0.16, 0.06), 20.0, 32.0, [IRON_LIT, IRON, IRON_SHADE])
		b.stroke(PackedVector2Array([_p(Vector2(0.02, h + 0.04), 26.0), _p(Vector2(0.16, h + 0.04), 26.0)]), 3.0, STEEL_LIT)
		_block(b, Vector2(0.18, h + 0.02), Vector2(0.05, 0.04), 0.0, 30.0, [IRON_LIT, IRON, IRON_SHADE])
		_one["engine"] = b.mesh()
	return _one["engine"]

## Where the engine's flywheel turns, from its origin, and its size in tiles.
const ENGINE_WHEEL := Vector2(0.18, 0.44)
const ENGINE_WHEEL_UP := 30.0
const ENGINE_WHEEL_R := 0.3

## A wheel of radius WHEEL about (0, 0): a rim, four spokes, a hub. Drawn
## under `on_wall`, which stands it on a wall of the land and turns it.
## `toothed` is the saw's blade: a steel disc with teeth and no spokes.
## (Built large and drawn small: a mesh's soft edge is a unit wide.)
const WHEEL := 100.0
static func wheel(toothed := false) -> ArrayMesh:
	var key := "blade" if toothed else "wheel"
	if _one.has(key):
		return _one[key]
	var b := Face.Builder.new()
	var r := WHEEL
	if toothed:
		var rim := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			rim.append(Vector2(cos(a), sin(a)) * r * (1.0 if i % 2 == 0 else 0.84))
		b.polygon(rim, STEEL)
		b.disc(Vector2.ZERO, r * 0.78, STEEL_LIT)
		b.disc(Vector2.ZERO, r * 0.6, STEEL)
		# marks that show it turning
		for i in 3:
			var a := TAU * i / 3.0
			b.stroke(PackedVector2Array([Vector2(cos(a), sin(a)) * r * 0.28, Vector2(cos(a + 0.5), sin(a + 0.5)) * r * 0.66]), r * 0.07, STEEL_DEEP)
		b.disc(Vector2.ZERO, r * 0.2, IRON_SHADE)
		b.disc(Vector2.ZERO, r * 0.09, STEEL_LIT)
	else:
		b.stroke(Face.Builder.ring(Vector2.ZERO, r * 0.9, r * 0.9), r * 0.2, IRON_SHADE, true)
		b.stroke(Face.Builder.ring(Vector2.ZERO, r * 0.95, r * 0.95), r * 0.06, IRON_LIT, true)
		for i in 4:
			var a := TAU * i / 4.0
			b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * r * 0.84]), r * 0.13, IRON)
		b.disc(Vector2.ZERO, r * 0.24, IRON_SHADE)
		b.disc(Vector2.ZERO, r * 0.12, GOLD)
	_one[key] = b.mesh()
	return _one[key]

## The transform that stands `wheel()` on the land: its hub at `hub` (view
## units), `r` tiles across its half, turned by `angle`, in the upright plane
## that runs along the tile axis `axis` (0: +x, down the screen and right;
## 1: +y, seen edge on top-down).
static func on_wall(hub: Vector2, r: float, angle: float, axis: int) -> Transform2D:
	var along := PLANE.x if axis % 2 == 0 else PLANE.y
	return Transform2D(along * r / WHEEL, Vector2(0.0, -RISE * r / WHEEL), hub) * Transform2D(angle, Vector2.ZERO)

## How many looks a thing that has levels has, and the look of a level: a
## thing looks better at every level it is raised to (the user, 2026-10-12:
## "every building must change as it lvl up, becoming more better
## looking"), up to its last look, which every level past it wears.
const LOOKS_OF := {"market": 5}

static func look(kind: String, level: int) -> int:
	return clampi(level, 1, int(LOOKS_OF.get(kind, 1)))

## The market, one tile, the origin its middle on the ground (the user,
## 2026-10-11: "the market tile should be a single square, the item stay
## above it and them it opens a hatch and the item falls"; it was a stall of
## 2 by 2). A low box of planks with a square hole in its top, dark inside,
## and a coin painted on its sunny wall to say what it is (a coin on a post
## stood behind it for an hour: the sale's coin hopped up right over it).
## The hole's two leaves are not in it (`market_door`, `market_leaf`): they
## swing.
## It has five looks by its level, each the last and something more: bare
## planks; its top's corners capped in iron; walls of laid stone under the
## plank top; the caps, the rim and the hatch's straps in brass; a line of
## brass let into the top and round the foot, and the coin on a brass plate. Nothing ever stands on it or beside it: a belt comes in by any
## side and the sale's coin hops over its middle.
static func market(level := 1) -> ArrayMesh:
	var tier := look("market", level)
	var key := "market%d" % tier
	if not _one.has(key):
		var b := Face.Builder.new()
		var wood := _market_wood(tier)
		var big := Vector2(MARKET_HALF, MARKET_HALF)
		_ground_shade(b, [[Vector2.ZERO, big, MARKET_TALL]])
		_block(b, Vector2.ZERO, big, 0.0, MARKET_TALL, wood)
		# the hole, and the two inner walls the eye sees down it
		var hole := PackedVector2Array()
		for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			hole.append(_p(o * HATCH_HALF, MARKET_TALL))
		b.polygon(hole, PIT)
		for wall: Array in [[Vector2(-1, -1), Vector2(1, -1), PLANK_DEEP.darkened(0.45)], [Vector2(-1, -1), Vector2(-1, 1), PLANK_DEEP.darkened(0.6)]]:
			var from: Vector2 = wall[0] * HATCH_HALF
			var to: Vector2 = wall[1] * HATCH_HALF
			var face := PackedVector2Array([_p(from, MARKET_TALL), _p(to, MARKET_TALL), _p(to, MARKET_TALL - HATCH_DEEP), _p(from, MARKET_TALL - HATCH_DEEP)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(face, hole):
				b.polygon(part, wall[2])
		_market_near(b, tier)
		_one[key] = b.mesh()
	return _one[key]

## A market with its hatch shut, as one mesh: what is seen of one while it
## is built, and under the finger that places it.
static func market_shut(level := 1) -> ArrayMesh:
	var tier := look("market", level)
	var key := "market_shut%d" % tier
	if not _one.has(key):
		var b := Face.Builder.new()
		b.append(market(tier), Transform2D.IDENTITY)
		for side in 2:
			b.append(market_door(tier), market_leaf(side, 0.0))
		_one[key] = b.mesh()
	return _one[key]

## The market's near side by itself: its two seen walls and the top's two
## near planks. Drawn over a thing falling through the hatch, which is then
## behind them as it should be.
static func market_front(level := 1) -> ArrayMesh:
	var tier := look("market", level)
	var key := "market_front%d" % tier
	if not _one.has(key):
		var b := Face.Builder.new()
		var big := Vector2(MARKET_HALF, MARKET_HALF)
		var wood := _market_wood(tier)
		# `_block` with no top: the hole would be covered
		b.polygon(PackedVector2Array([_p(Vector2(-big.x, big.y)), _p(big), _p(big, MARKET_TALL), _p(Vector2(-big.x, big.y), MARKET_TALL)]), wood[1])
		b.polygon(PackedVector2Array([_p(big), _p(Vector2(big.x, -big.y)), _p(Vector2(big.x, -big.y), MARKET_TALL), _p(big, MARKET_TALL)]), wood[2])
		_market_near(b, tier)
		_one[key] = b.mesh()
	return _one[key]

## Its top, its sunny wall and its shaded one: planks, and from the third
## look walls of stone under the plank top.
static func _market_wood(tier := 1) -> Array:
	if tier >= 3:
		return [PLANK.lightened(0.22), STONE.lightened(0.06), STONE_SHADE]
	return [PLANK.lightened(0.22), PLANK.lightened(0.06), PLANK_DEEP]

## What both of the market's meshes end with: the top's two near planks,
## the joints of the two walls, what its look binds or trims them with, the
## coin on the sunny one and the line round the hole and the rim.
static func _market_near(b: Face.Builder, tier := 1) -> void:
	var o := MARKET_HALF
	var i := HATCH_HALF
	var top: Color = _market_wood(tier)[0]
	var left := Vector2(-o, o)
	var near := Vector2(o, o)
	var right := Vector2(o, -o)
	b.polygon(PackedVector2Array([_p(Vector2(o, -o), MARKET_TALL), _p(Vector2(o, o), MARKET_TALL), _p(Vector2(i, i), MARKET_TALL), _p(Vector2(i, -i), MARKET_TALL)]), top)
	b.polygon(PackedVector2Array([_p(Vector2(-o, o), MARKET_TALL), _p(Vector2(-i, i), MARKET_TALL), _p(Vector2(i, i), MARKET_TALL), _p(Vector2(o, o), MARKET_TALL)]), top)
	if tier >= 3:
		var joint := Color(0.36, 0.26, 0.2, 0.34)
		_courses(b, left, near, 0.0, MARKET_TALL, 2, joint, 20.0)
		_courses(b, near, right, 0.0, MARKET_TALL, 2, Color(joint, joint.a * 1.3), 20.0)
	else:
		for f: float in [0.25, 0.5, 0.75]:
			var u := lerpf(-o, o, f)
			b.stroke(PackedVector2Array([_p(Vector2(u, o), 2.0), _p(Vector2(u, o), MARKET_TALL - 3.0)]), 1.6, Color(PLANK_DEEP, 0.6), false, false)
	# the coin on the wall in the sun, lying in the wall's own plane; at the
	# last look on a plate of brass
	var along := at(Vector2(1.0, 0.0)).normalized()
	var mid := _p(Vector2(0.0, o), MARKET_TALL * 0.5)
	if tier >= 5:
		var plate := PackedVector2Array()
		for k in 20:
			var a := TAU * k / 20.0
			plate.append(mid + along * cos(a) * 11.0 + Vector2(0.0, sin(a) * 11.0))
		b.polygon(plate, GOLD_DEEP)
	b.append(icon("coin"), Transform2D(along * 0.17, Vector2(0.0, 0.17), mid))
	b.stroke(PackedVector2Array([_p(left, MARKET_TALL), _p(near, MARKET_TALL), _p(right, MARKET_TALL)]), 2.4, GOLD_HI if tier >= 4 else PLANK.lightened(0.34), false, false)
	if tier >= 2:
		# its top's four corners capped: iron, and brass from the fourth look
		var cap: Color = GOLD if tier >= 4 else IRON
		var lit: Color = GOLD_HI if tier >= 4 else IRON_LIT
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var corner := c * o
			var tri := PackedVector2Array([_p(corner, MARKET_TALL), _p(corner - Vector2(c.x * 0.17, 0.0), MARKET_TALL), _p(corner - Vector2(0.0, c.y * 0.17), MARKET_TALL)])
			b.polygon(tri, cap)
			b.disc(_p(corner - c * 0.05, MARKET_TALL), 1.5, lit)
	if tier >= 4:
		# brass down the corner the eye sees, and a line of it let into the top
		b.stroke(PackedVector2Array([_p(near, 1.0), _p(near, MARKET_TALL)]), 3.0, GOLD, false, false)
	if tier >= 5:
		var inlay := PackedVector2Array()
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			inlay.append(_p(c * (i + o) * 0.5, MARKET_TALL))
		b.stroke(inlay, 1.6, GOLD, true)
		b.stroke(PackedVector2Array([_p(left, 2.0), _p(near, 2.0), _p(right, 2.0)]), 2.4, GOLD_DEEP, false, false)
	b.stroke(PackedVector2Array([_p(Vector2(-i, i), MARKET_TALL), _p(Vector2(i, i), MARKET_TALL), _p(Vector2(i, -i), MARKET_TALL)]), 1.8, GOLD_DEEP if tier >= 4 else PLANK_DEEP.darkened(0.25), false, false)

## One leaf of the market's hatch, in a space of its own at FINE units a
## tile: x from its hinge (0) to its free edge, y along the hinge about its
## middle. `market_leaf` lays it; nothing is rebuilt as it swings. Its
## straps are iron, and brass from the market's fourth look.
static func market_door(level := 1) -> ArrayMesh:
	var tier := look("market", level)
	var key := "market_door%d" % (4 if tier >= 4 else 1)
	if not _one.has(key):
		var b := Face.Builder.new()
		var w := HATCH_HALF * FINE
		b.polygon(PackedVector2Array([Vector2(0.0, -w), Vector2(w, -w), Vector2(w, w), Vector2(0.0, w)]), PLANK.lightened(0.1))
		for k in 3:
			var y := lerpf(-w, w, (k + 0.5) / 3.0)
			b.polygon(PackedVector2Array([Vector2(1.0, y - w / 3.0 + 1.2), Vector2(w - 1.0, y - w / 3.0 + 1.2), Vector2(w - 1.0, y + w / 3.0 - 1.2), Vector2(1.0, y + w / 3.0 - 1.2)]),
				PLANK.lightened(0.16) if k % 2 == 0 else PLANK.lightened(0.04))
		# its two straps from the hinge
		for y: float in [-w * 0.55, w * 0.55]:
			b.stroke(PackedVector2Array([Vector2(1.5, y), Vector2(w * 0.7, y)]), 3.2, GOLD if tier >= 4 else IRON, false, true)
		_one[key] = b.mesh()
	return _one[key]

## Where leaf `side` (0 hinged on the hole's -x edge, 1 on its +x) lies
## when the hatch is `open` (0 shut, 1 hanging down), about the market's
## own origin: draw `market_door()` under it.
static func market_leaf(side: int, open: float) -> Transform2D:
	var s := -1.0 if side == 0 else 1.0
	var a := clampf(open, 0.0, 1.0) * HATCH_SWING
	var across := PLANE.x * -s * cos(a) + Vector2(0.0, RISE * sin(a))
	return Transform2D(across / FINE, PLANE.y / FINE, at(Vector2(s * HATCH_HALF, 0.0)) + MARKET_TOP)

## A footprint's highlight while a module is held over the land: `w` by `h`
## tiles in tile space, (0, 0) to (w, h), a soft fill inside a rim. Pale
## green paper when it fits (`ok`), the house's warning red when it does
## not. Drawn under `flat(tile)`, on the ground before what stands.
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
## a mesh), `square`, `box` (a full one), `market` and `engine`. The things
## are their own meshes, fitted.
static func icon(named: String) -> ArrayMesh:
	if _icons.has(named):
		return _icons[named]
	var b := Face.Builder.new()
	match named:
		"belt", "fast":
			# two tiles of it, on their legs, the bed over them; the fast one
			# with its dark bed and two warm chevrons
			var s := 0.56 / FINE
			var xf := Transform2D(PLANE.x * s, PLANE.y * s, BELT_LIFT * 0.56)
			for i in 2:
				b.append(belt_under(), Transform2D(0.0, Vector2(0.56, 0.56), 0.0, at(Vector2(i - 0.5, 0.0)) * 0.56))
			for i in 2:
				var t := xf * Transform2D(0.0, Vector2(FINE * (i - 1.0), -FINE * 0.5))
				_belt_into(b, t, named == "belt")
				if named == "fast":
					b.polygon(t * PackedVector2Array([Vector2(0.0, 16.0), Vector2(FINE, 16.0), Vector2(FINE, 84.0), Vector2(0.0, 84.0)]), Color("6b7078"))
					for x: float in [20.0, 52.0]:
						for side: float in [-1.0, 1.0]:
							b.stroke(t * PackedVector2Array([Vector2(x, 50.0 + side * 22.0), Vector2(x + 18.0, 50.0)]), 3.4, Color(1.0, 0.82, 0.36, 0.9))
			var mid := Vector2.ZERO
			for v in b.verts:
				mid += v
			mid /= b.verts.size()
			for i in b.verts.size():
				b.verts[i] -= mid
		"bridge":
			var whole := Face.Builder.new()
			whole.append(belt_under(), Transform2D.IDENTITY)
			whole.append(bridge(0), Transform2D.IDENTITY)
			_fit_into(b, whole.mesh(), 92.0)
		"coin":
			_coin_into(b, Vector2.ZERO, 42.0)
		"box":
			_fit_into(b, box(4), 84.0)
		"market":
			_fit_into(b, market_shut(), 96.0)
		"engine":
			var whole := Face.Builder.new()
			whole.append(engine(), Transform2D.IDENTITY)
			whole.append(wheel(), on_wall(_p(ENGINE_WHEEL, ENGINE_WHEEL_UP), ENGINE_WHEEL_R, 0.4, 0))
			_fit_into(b, whole.mesh(), 94.0)
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
## every so many seconds, or that one or none has been sold (the sim reads
## nothing under two).
static func pace_text(sim: RefCounted) -> String:
	if sim.pace_ticks() <= 0:
		return TranslationServer.translate("FACTORY_PACE_ONE" if sim.sold_at.size() == 1 else "FACTORY_PACE_NONE")
	return TranslationServer.translate("FACTORY_PACE") % amount(snappedf(sim.pace_s(), 0.1), comma())

## What the next milestone asks ("next: a box every 51 s"), "" when the
## next is past what this build fills (Sim.BUILT).
static func next_text(sim: RefCounted) -> String:
	var next: int = sim.milestone + 1
	if next > sim.BUILT or next >= sim.MILESTONES.size():
		return ""
	var every: float = float(sim.MILESTONES[next].every) * sim.TICK
	return TranslationServer.translate("FACTORY_PACE_NEXT") % amount(snappedf(every, 0.1), comma())

## A milestone's name by its id (Sim.MILESTONES): "Walk less".
static func milestone_name(id: String) -> String:
	return TranslationServer.translate("FACTORY_MILESTONE_" + id.to_upper())

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
