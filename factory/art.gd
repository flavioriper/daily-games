extends RefCounted

## Factory's drawings: the Grove's painted land (valley/grove_art.gd, which
## this began as a copy of on 2026-10-10) cut into plates of 8 by 8 tiles,
## and what stands on them. Every drawing is built once into a mesh and
## kept, so a screen pays one draw_mesh a thing (CLAUDE.md, the 855 budget).
## Nothing here knows the sim: a tile is a Vector2i and a kind is a String.
##
## THE TILE GRID. Tiles are global Vector2i; plate P owns P*8 .. P*8+7. A
## point of tile space `t` (a tile's centre is tile + (0.5, 0.5)) is seen at
## `at(t)`, in view units: +x runs down and right, +y down and left, so a
## plate's back corner is its local (0, 0) and its front corner (8, 8).
##   K, DEEP, PLATE      65 view units to half a tile's width, 0.66 as deep,
##                       8 tiles a side. TILE is a tile's box, 130 by 85.8.
##   at(t)               tile space to view units.
##   tile_at(v)          and back, floats (floor it for the tile).
##   ISO                 at() as a Transform2D.
##   flat(tile, facing)  the transform that lays a unit-square mesh (belt,
##                       ghost) on `tile`, turned to DIRS[facing].
##   DIRS                [+x, +y, -x, -y] as Vector2i; a facing is its index.
##   depth(t)            what to sort by, back to front (t.x + t.y).
##   RISE                view units a tile's length stands tall.
##
## THE GROUND. Draw order: water (fixed to the screen), plates sorted by
## P.x + P.y, grass, flat things (belts, ghosts, plus), shadows, then what
## stands, sorted by depth(), then light. A layer that pans and zooms must
## be given a box of its own (RenderingServer.canvas_item_set_custom_rect):
## the engine culls a layer by its meshes' boxes without their transforms,
## and past the Grove's scale whole layers were not drawn (the harness,
## tests/_shot_factory_art.gd, 2026-10-10).
##   water(size, round)  the pond for a field of `size` pixels: calm, with
##                       nothing in it that belongs to a place, so the land
##                       may pan over it.
##   pads(n, bloom)      a group of lily pads in view units, for a screen
##                       that knows where open water is.
##   plate(kind, sides, variant)  one plate's land, its tile (0, 0) corner on
##                       the mesh's origin: draw it at at(P * 8). `kind` is
##                       forest or neutral. `sides` bit i is set when
##                       a plate lies beyond the side toward DIRS[i]: that
##                       side has no earth, a corner is rounded only where
##                       both its sides are free, and the plate in front
##                       lays a low bank of turf on the seam. `variant`
##                       lays the washes and pebbles differently.
##   grass(kind, variant)  [tufts, flowers] as MultiMeshes in the plate's
##                       own view units, for a layer wearing wind(true).
##   light(size)         warm light and a darker frame over everything.
##   DEPTH, ROUND        the earth showing over the water (view units), and
##                       how far along a side a free corner is rounded (tiles).
##
## TREES AND WIND. Only layers that draw trees, their shadows and the grass
## wear a wind material; everything else here (belts, items, piles,
## buildings) is drawn on plain layers, so nothing is hung under its origin
## to keep it still (the Grove's `_still` is gone).
##   tree(look)          0 sapling, 1 birch, 2 oak, 3 pine, 4 blossom,
##                       standing on (0, 0). Draw at TREE_SCALE on a tile's
##                       centre.
##   TREE_SCALE, RADIUS  the scale a tree is drawn at, and a look's radius.
##   height(look), girth(look)  how tall it stands and half its trunk, as
##                       drawn at TREE_SCALE.
##   shade(look), cast(at, scale, lean)  a tree's shadow and the transform
##                       that lays it on the ground.
##   stump(look)         what a felled tree leaves (null for a sapling).
##   wind(grass), shade_wind()  the materials; blow() every frame sets
##                       their clock and returns it; gust(x, t) is the same
##                       wave in script.
##   keep_to(m, centre, half, u), keep_off(m)  fades a shadow material at
##                       the edge of one diamond of land. Off unless called:
##                       a board of many plates leaves it off.
##   rock(look)          0 to 3, a mine's rock standing on (0, 0), its
##                       shade in it; ROCK_R and ROCK_TALL are its reach
##                       and height. No wind.
##   leaf(), tuft(), flower()  the small meshes, pale, for an instance's
##                       colour; LEAF is a loose leaf's colour by look.
##   rubble(n)           a mine's stock lying by a gate, as pile() is a
##                       forest's.
##   pile(n, lucky), heap_of(n), heap_tall(n)  cut logs lying where a tree
##                       fell, foot on (0, 0), shadow in it.
##
## BELTS. One mesh and one material for every belt on the land.
##   belt()              a belt tile in tile space, 0..1, travelling to +x:
##                       draw under flat(tile, facing), or as a MultiMesh of
##                       such transforms. Its UV carries where along and
##                       across the belt a point is.
##   belt_material()     the material that draws the slats and the chevron
##                       and runs them BELT_SPEED tiles a second by `time`.
##   belt_material(true) the fast belt's: the same shader, a dark bed
##                       twice as fast, two warm chevrons.
##   splitter(facing)    a splitter's housing over its bed, drawn among
##                       what stands.
##   belt_run(t)         sets `time` from seconds, wrapped; holds the slats
##                       still under reduce motion.
##
## THINGS, in view units, origin where they rest on the ground, a soft
## shadow in each.
##   item(kind)          log, stone, lime, charcoal, plank, chair: about 42
##                       across, two to a tile.
##   market()            the 1 by 1 hatch, origin its tile's centre: a low
##                       box with a hole in its top, a coin on its wall.
##                       MARKET_TOP is where a thing lies on it.
##                       market_door() is one leaf of the hatch, drawn
##                       twice by market_leaf(side, open); market_front()
##                       is the box's near side again, drawn over a thing
##                       falling in.
##   firebox(), fire()   the 1 by 1 fire box (origin its tile's centre) and
##                       the light in its mouth, drawn at FIREBOX_MOUTH.
##   kiln(facing), retort(facing)  1 by 2, origin the centre of the back
##                       tile (the way in), the front tile toward
##                       DIRS[facing] (the way out). A hopper is always the
##                       way in, a low tray the way out.
##   module(kind, facing)  any module's mesh by its kind.
##   engine()            1 by 1: a boiler on a brick foot; its flywheel is
##                       wheel() under on_wall(hub, r, angle, axis) at
##                       ENGINE_WHEEL, ENGINE_WHEEL_UP up.
##   saw(facing), joiner(facing)  1 by 2 like the kiln; the saw's blade is
##                       wheel(true) at saw_hub(facing); joiner_dust(facing)
##                       is where its sawdust rises.
##   stoker()            what a fire box with a stoker wears.
##   KILN_GLOW, RETORT_SMOKE  by facing: where glow() and smoke() go.
##   glow(), smoke()     soft round puffs, pale, for the caller to tint
##                       and scale.
##   plus()              the button lying on the water where a plate may
##                       be bought, about a tile and a half across.
##   frame(w, h)         timber scaffold over a footprint of w by h tiles,
##                       origin at(the footprint's lowest tile corner).
##   ghost(w, h, ok)     a footprint's highlight in tile space, 0..w by
##                       0..h: draw under flat(tile).
##   icon(kind)          96 across about (0, 0): belt, firebox, kiln,
##                       retort, market, forest, neutral, log, stone,
##                       lime, charcoal, coin.
##
## FIGURES. comma(), decimal(text), amount(v, comma), short(n).

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const WIND := preload("res://shaders/wind_2d.gdshader")
const BELT := preload("res://shaders/belt_2d.gdshader")

## The painted land (2026-10-06, the isometric pass): a pond pale far off
## and deep at the foot, grass in forest greens under a wash of warm light
## and cool shade, earth warm where it looks at the sun (upper left) and
## cool where it looks away, and a shadow that is a colour, never a grey.
const WATER_FAR := Color("b9e8e0")
const WATER := Color("7fd0cc")
const WATER_DEEP := Color("4ba9b3")
const RIPPLE := Color(1.0, 1.0, 1.0, 0.42)
const LILY := Color("4f9f63")
const LILY_HI := Color("74c07e")
const GRASS := Color("82b95b")
const GRASS_LIT := Color("a3cf66")
const GRASS_DEEP := Color("5f9c55")
const WASH_WARM := Color("deec8a")
const WASH_COOL := Color("4c8f58")
const LIP := Color("4d8748")
const LIP_LIT := Color("67a650")
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
## A tuft's greens: most deeper than the grass, one in four lit.
const TUFTS := [Color("4f8f4c"), Color("5a964a"), Color("63a04e"), Color("b9da74")]
## What a flower's petals are tinted (its stem with them, so all pale).
const PETALS := [Color("ffffff"), Color("ffe3e0"), Color("fff0b8"), Color("ffffff")]
## A crown's four tones by look, its shade first, and a trunk's two.
const CROWN := {
	1: [Color("6aa53e"), Color("7fb548"), Color("97ca5a"), Color("c6e888")],
	2: [Color("437b30"), Color("539036"), Color("66a544"), Color("90cc66")],
	4: [Color("d0749f"), Color("e58fb5"), Color("f1a8c8"), Color("fdd6e6")],
}
const TRUNK := {
	1: [Color("f3eee2"), Color("d8cfbc")],
	2: [Color("8a5c3a"), Color("6f482c")],
	4: [Color("8a5c3a"), Color("6f482c")],
}
## A loose leaf's colour by look: what the wind takes off a tree.
const LEAF := [Color("a6d96e"), Color("b5dd74"), Color("7fbb55"), Color("5fa377"), Color("fbd0e2")]
const BARK := Color("9c6b45")
const PITH := Color("f0d9ae")
const MARK := Color("ffd66b")
## The paper a price lies on while the energy does not reach it: the shop's
## bars, and the tree's bar and tags.
const PRICE_OFF := Color("ede4d3")
## What the tree's pictures are made of beside wood: rope, planks, a crate's
## boards, an axe's steel, a feather.
const ROPE := Color("ecd9a6")
const ROPE_DEEP := Color("c9a968")
const PLANK := Color("cfa26d")
const PLANK_DEEP := Color("a57a48")
## A shadow lying on planks or logs: warm, where one on the grass is cool.
const PLANK_SHADE := Color(0.3, 0.17, 0.1, 0.3)
const STEEL := Color("9ba5ad")
const STEEL_LIT := Color("d5dde3")
const STEEL_DEEP := Color("7d8890")
const CLOVER := Color("6fae4c")
const CLOVER_LIT := Color("93cc66")
## What the modules are built of. Brick, its lit and shaded sides and the
## mortar between; iron the same; the pale stone of the quarry; charcoal.
const BRICK := Color("cf8263")
const BRICK_LIT := Color("e6a27e")
const BRICK_SHADE := Color("a8604c")
const MORTAR := Color(0.42, 0.2, 0.15, 0.4)
const IRON := Color("6f7a84")
const IRON_LIT := Color("9ba5ad")
const IRON_SHADE := Color("4d5762")
const LIME := Color("d9cfb8")
const LIME_LIT := Color("f1ead8")
const LIME_SHADE := Color("ab9f8a")
const COAL := Color("3b3735")
const COAL_LIT := Color("67605b")
const HOLLOW := Color("3d2924")
const EMBER := Color("e8763a")
## The gold pill's coin (ui/menu/gold_pill.gd, GOLD, GOLD_DEEP, GOLD_HI). Its
## hexes are written again here: that script reads the Wallet autoload, so a
## harness run with --script could not load this one through it.
const GOLD := Color("f2b632")
const GOLD_DEEP := Color("c98a16")
const GOLD_HI := Color("ffe39a")
## A plate's ground by kind: its grass, the light and the deep of it, the
## washes toward and away from the sun, and the turf hanging over its edge.
const GROUND := {
	"forest": {"grass": GRASS, "lit": GRASS_LIT, "deep": GRASS_DEEP, "warm": WASH_WARM, "cool": WASH_COOL, "lip": LIP, "lip_lit": LIP_LIT},
	# a mine's worked ground: warm grit, paler where the sun lies on it
	"mine": {"grass": Color("cdbf9f"), "lit": Color("e6dcc0"), "deep": Color("a3957c"), "warm": Color("efe3c4"), "cool": Color("9c9a8c"),
		"lip": Color("9a8c74"), "lip_lit": Color("bdb096")},
	# white ground that is no kind of land (the user, 2026-10-11: "a white
	# ground with neutral texture"): chalk, a warm and a cool white over it
	"neutral": {"grass": Color("f1eee7"), "lit": Color("ffffff"), "deep": Color("cfcac0"), "warm": Color("fffaf0"), "cool": Color("dde0e2"),
		"lip": Color("c4bfb4"), "lip_lit": Color("e4e0d7")},
}
## A forest's hedge, which closes it, and the dark floor under its trees.
const HEDGE := Color("3f8a52")
const HEDGE_LIT := Color("63ab5c")
const HEDGE_DEEP := Color("2f6f49")
const FLOOR := Color(0.16, 0.42, 0.3, 0.3)
## A mine's wall of piled stones, which closes it, its dug floor, and the
## rocks it is seen by: body, lit face, shaded face, crack.
const WALL := Color("a59c8d")
const WALL_LIT := Color("cfc7b6")
const WALL_DEEP := Color("7b7468")
const PIT_FLOOR := Color(0.33, 0.27, 0.2, 0.26)
const ROCK := Color("b3aa9a")
const ROCK_LIT := Color("ddd5c3")
const ROCK_SHADE := Color("857d71")
const ROCK_CRACK := Color(0.3, 0.27, 0.24, 0.55)
## How far a rock of each look reaches from its middle, and how tall it is.
const ROCK_R := [34.0, 40.0, 30.0, 44.0]
const ROCK_TALL := [52.0, 66.0, 44.0, 58.0]
## The tile of a forest a log leaves by, toward each of DIRS: the sim's
## GATES. The same place at every quarter turn, so the mesh need not turn.
const GATES: Array[Vector2i] = [Vector2i(7, 4), Vector2i(3, 7), Vector2i(0, 3), Vector2i(4, 0)]
## How many tufts and how many drifts of flowers a plate of a kind grows.
const GROWS := {"forest": [44, 5], "mine": [0, 0], "neutral": [0, 0]}

## How the land is seen (the contract the sim shares): half a tile's width
## in view units, how deep the ground is seen for its width, and the tiles
## along a plate's side.
const K := 65.0
const DEEP := 0.66
const PLATE := 8
const TILE := Vector2(K * 2.0, K * 2.0 * DEEP)
const ISO := Transform2D(Vector2(K, K * DEEP), Vector2(-K, K * DEEP), Vector2.ZERO)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## A tile's length standing up, in view units: the eye is 41 degrees over
## the ground (asin DEEP), so what stands is seen cos of that as tall.
const RISE := 69.0
## The earth showing over the water, and how far along each side a corner
## of the land is rounded off, in tiles: a third of one, so a corner tile
## still stands on land (the Grove's 96 view units took nearly two).
const DEPTH := 116.0
const ROUND := 0.34
## Half a plate across, in view units.
const HALF := K * PLATE
## The side a walk round a plate leaves each corner by, clockwise from the
## back corner: back to right is the -y side, right to front the +x.
const SIDE_AFTER := [3, 0, 1, 2]
## A tree's radius by look, and the scale it is drawn at. The Grove drew
## them 1.25 over, on open ground; on a tile 130 wide that crown was 170
## and took the tiles beside it. At 1 the blossom stands 135 tall (1.6 of a
## tile's depth) and its crown is a tile wide, a sapling 55.
const RADIUS := [24.0, 34.0, 44.0, 42.0, 52.0]
const TREE_SCALE := 1.0

## A shadow's tone, and how a standing drawing is laid on the ground to be
## one (`cast`): where a unit of its width goes, and a unit of its height.
const CAST := Color(0.09, 0.27, 0.34, 0.24)
const CAST_ACROSS := Vector2(-0.16, 0.44)
const CAST_ALONG := Vector2(0.8, 0.14)

## A cut log in a pile: half its thickness, its length as it is drawn, and
## the way its length runs back from the sawn end that looks at us.
const LOG_R := 8.5
const LOG_LONG := 27.0
const LOG_BACK := Vector2(-0.835, -0.551)
## A row of a heap lies this much of a log's half thickness over the one
## under it, each log in the hollow between two.
const LOG_RISE := 1.72
## The logs in each row of a heap, from the ground up, for each of the five
## ways a stack is drawn (`heap_of`).
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
## The kiln's round, in tiles, and how high its port's light sits.
const KILN_R := 0.37
const KILN_PORT := 14.0
## Where the kiln's light goes, by facing: its port looks down and left
## when the kiln runs along x, down and right when it runs along y.
const KILN_GLOW: Array[Vector2] = [
	Vector2(-KILN_R * 0.97 * K, KILN_R * 0.97 * K * DEEP - KILN_PORT), Vector2(KILN_R * 0.97 * K, KILN_R * 0.97 * K * DEEP - KILN_PORT),
	Vector2(-KILN_R * 0.97 * K, KILN_R * 0.97 * K * DEEP - KILN_PORT), Vector2(KILN_R * 0.97 * K, KILN_R * 0.97 * K * DEEP - KILN_PORT)]
## The retort's stack: how far along the drum it stands, in tiles, and how
## high its smoke starts. RETORT_SMOKE by facing.
const RETORT_STACK := 0.2
const RETORT_TOP := 86.0
const RETORT_SMOKE: Array[Vector2] = [
	Vector2(RETORT_STACK * K, RETORT_STACK * K * DEEP - RETORT_TOP), Vector2(-RETORT_STACK * K, RETORT_STACK * K * DEEP - RETORT_TOP),
	Vector2(-RETORT_STACK * K, -RETORT_STACK * K * DEEP - RETORT_TOP), Vector2(RETORT_STACK * K, -RETORT_STACK * K * DEEP - RETORT_TOP)]
## The fire box's mouth is in its lit side, the one looking down and left.
const FIREBOX_HALF := 0.36
const FIREBOX_MOUTH := Vector2(-FIREBOX_HALF * K, FIREBOX_HALF * K * DEEP - 13.0)
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

static var _trees := {}
static var _shades := {}
static var _stumps := {}
static var _shade_winds: Array[WeakRef] = []
static var _icons := {}
static var _piles := {}
static var _plates := {}
static var _grass := {}
static var _pads := {}
static var _items := {}
static var _kilns := {}
static var _retorts := {}
static var _frames := {}
static var _ghosts := {}
static var _one := {}
static var _tuft: ArrayMesh
static var _flower: ArrayMesh
static var _leaf_mesh: ArrayMesh
static var _belt: ArrayMesh
static var _bends := {}
static var _under_bends := {}
static var _belt_mat: ShaderMaterial
static var _fast_mat: ShaderMaterial
static var _winds := {}

# --- how the land is seen ---

## A point of tile space, in view units.
static func at(t: Vector2) -> Vector2:
	return Vector2((t.x - t.y) * K, (t.x + t.y) * K * DEEP)

## The point of tile space under a point of the view.
static func tile_at(v: Vector2) -> Vector2:
	var across := v.x / K
	var deep := v.y / (K * DEEP)
	return Vector2((deep + across) * 0.5, (deep - across) * 0.5)

## What to sort by so the back is drawn first.
static func depth(t: Vector2) -> float:
	return t.x + t.y

## Lays a mesh drawn in tile space on the ground: its (0, 0)..(1, 1) on the
## tile at `tile`, turned about the tile's middle so its +x runs toward
## DIRS[facing]. A whole footprint (`ghost`) takes facing 0.
static func flat(tile: Vector2, facing := 0) -> Transform2D:
	var x := Vector2(DIRS[posmod(facing, 4)])
	var y := Vector2(DIRS[posmod(facing + 1, 4)])
	return ISO * Transform2D(x, y, tile + Vector2(0.5, 0.5) - (x + y) * 0.5)

## A tree of `look` (0 sapling, 1 birch, 2 oak, 3 pine, 4 blossom) standing
## on (0, 0), in land units. Redrawn on
## 2026-10-06 (the user: "polish design of trees, grass, add some wind
## movement"): lit from the upper left, so a crown is a shade under it, a
## body, a lit side and a few bright clumps, with loose leaves dabbed across
## the tones, and a trunk flares at its foot and is darker down its right.
## The shadow it throws is not in it (it was, an oval, and turned over with
## a falling tree): that is `shade`, laid on the ground by `cast`.
static func tree(look: int) -> ArrayMesh:
	if not _trees.has(look):
		var b := Face.Builder.new()
		_tree_into(b, look, RADIUS[look])
		_trees[look] = b.mesh()
	return _trees[look]

# --- the shadow a tree throws ---

## Collects what a drawing is made of as outlines, the colours dropped: a
## tree drawn into one gives the shape its shadow has.
class Outline extends Face.Builder:
	var shapes: Array[PackedVector2Array] = []

	func fan(points: PackedVector2Array, _colour: Color) -> void:
		shapes.append(points)

	func polygon(points: PackedVector2Array, _colour: Color) -> void:
		shapes.append(points)

	func stroke(points: PackedVector2Array, width: float, _colour: Color, _closed := false, _caps := true) -> void:
		for poly: PackedVector2Array in Geometry2D.offset_polyline(points, width * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			shapes.append(poly)

	## Every shape melted into the others it touches, so nothing lies over
	## anything: a shadow drawn of overlapping pieces is darker where they do.
	func melted() -> Array[PackedVector2Array]:
		var acc: Array[PackedVector2Array] = []
		for shape in shapes:
			var top := 0.0
			for p in shape:
				top = minf(top, p.y)
			if top > -1.0:
				continue   # what lies on the ground (a dropped petal) throws none
			var cur := shape
			if Geometry2D.is_polygon_clockwise(cur):
				cur = cur.duplicate()
				cur.reverse()
			var again := true
			while again:
				again = false
				var rest: Array[PackedVector2Array] = []
				for q in acc:
					var outer: Array[PackedVector2Array] = []
					for m: PackedVector2Array in Geometry2D.merge_polygons(cur, q):
						if not Geometry2D.is_polygon_clockwise(m):
							outer.append(m)
					if outer.size() == 1:
						cur = outer[0]
						again = true
					else:
						rest.append(q)
				acc = rest
			acc.append(cur)
		return acc

## The shadow of a tree of `look`: its own outline in one piece and one
## tone, still standing on (0, 0). `cast` lays it on the ground; drawn
## under `shade_wind` it moves as its tree does.
static func shade(look: int) -> ArrayMesh:
	if not _shades.has(look):
		var o := Outline.new()
		_tree_into(o, look, RADIUS[look])
		var b := Face.Builder.new()
		for shape in o.melted():
			b.polygon(shape, CAST)
		_shades[look] = b.mesh()
	return _shades[look]

## Lays a standing drawing on the ground as the shadow of what stands at
## `at`, the sun upper left and behind: a tree's width goes back into the
## land (CAST_ACROSS a unit) and its height off to the right (CAST_ALONG).
## `lean` is how far the tree has turned over, in radians, to the right when
## over 0: its shadow does not turn with it but runs out along the ground
## and ends lying under it.
static func cast(at: Vector2, scale: Vector2, lean := 0.0) -> Transform2D:
	var along := CAST_ALONG * cos(lean) + Vector2(sin(lean), 0.05 * absf(sin(lean)))
	return Transform2D(CAST_ACROSS * scale.x, -along * scale.y, at)

## A material for a Control that draws shadows: the trees' own wind, turned
## into the way a shadow goes when its crown leans. A new one each call;
## `blow` winds them all. It draws its shadows wherever they fall: the
## Grove kept them to its one diamond of land (`keep_to`), and a board of
## many plates does not call that.
static func shade_wind() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WIND
	m.set_shader_parameter("tall", 120.0)
	m.set_shader_parameter("reach", 9.0)
	m.set_shader_parameter("rustle", 0.5)
	m.set_shader_parameter("droop", 0.0)
	m.set_shader_parameter("along", Transform2D(CAST_ACROSS, -CAST_ALONG, Vector2.ZERO).affine_inverse().basis_xform(Vector2.RIGHT))
	_shade_winds.append(weakref(m))
	return m

## Keeps what `m` draws to one diamond of land: `centre` its middle on the
## screen, `half` half its width in view units, `u` pixels a unit. For a
## single plate shown alone (a card, a tutorial page). The shader's
## `land_half` is 0 until this is called, which is the fade switched off.
static func keep_to(m: ShaderMaterial, centre: Vector2, half: float, u: float) -> void:
	m.set_shader_parameter("land_half", half)
	m.set_shader_parameter("land_at", centre)
	m.set_shader_parameter("land_u", u)
	m.set_shader_parameter("land_deep", DEEP)

## Switches `keep_to` off again.
static func keep_off(m: ShaderMaterial) -> void:
	m.set_shader_parameter("land_half", 0.0)

## What a felled tree leaves standing a moment: its foot, gnawed to a point,
## the pale wood showing. A sapling leaves none.
static func stump(look: int) -> ArrayMesh:
	if look == 0:
		return null
	if not _stumps.has(look):
		var b := Face.Builder.new()
		var r: float = RADIUS[look]
		var tones: Array = [Color("7a5236"), Color("63412a")] if look == 3 else TRUNK[look]
		var w := r * (0.16 if look == 3 else 0.13 * (0.82 if look == 1 else (1.25 if look == 2 else 1.0)))
		var flare := 1.0 if look == 3 else 2.3
		var waist := -r * 0.2
		var tip := Vector2(w * 0.15, -r * 0.4)
		var left := Face.Builder.bezier2(Vector2(-w * flare, 0.0), Vector2(-w * 1.05, -r * 0.05), Vector2(-w, waist), 6)
		var right := Face.Builder.bezier2(Vector2(w, waist), Vector2(w * 1.05, -r * 0.05), Vector2(w * flare, 0.0), 6)
		var pts := left.duplicate()
		pts.append_array([Vector2(-w, waist), Vector2(w, waist)])
		pts.append_array(right)
		pts.append(Vector2(w * flare, 0.0))
		b.polygon(pts, tones[0])
		var dark := PackedVector2Array([Vector2(w * 0.25, waist)])
		dark.append_array(right)
		dark.append_array([Vector2(w * flare, 0.0), Vector2(w * 0.8, 0.0)])
		b.polygon(dark, tones[1])
		b.polygon(PackedVector2Array([Vector2(-w, waist), tip, Vector2(w, waist)]), PITH)
		b.polygon(PackedVector2Array([Vector2(w * 0.3, waist), tip, Vector2(w, waist)]), PITH.darkened(0.12))
		_stumps[look] = b.mesh()
	return _stumps[look]

## Half a trunk's width where a beaver bites it, as the tree is drawn.
static func girth(look: int) -> float:
	var r: float = RADIUS[look]
	match look:
		0:
			return 3.0 * TREE_SCALE
		3:
			return r * 0.16 * TREE_SCALE
	return r * 0.13 * (0.82 if look == 1 else (1.25 if look == 2 else 1.0)) * 1.2 * TREE_SCALE

static func _tree_into(b: Face.Builder, look: int, r: float) -> void:
	match look:
		0:
			var stem := Face.Builder.bezier2(Vector2.ZERO, Vector2(-r * 0.16, -r * 0.7), Vector2(r * 0.03, -r * 1.4), 8)
			stem.append(Vector2(r * 0.03, -r * 1.4))
			b.stroke(stem, 6.0, Color("6f9f3e"))
			for side: float in [-1.0, 1.0]:
				var at := Vector2(side * r * 0.5, -r * (1.2 if side < 0.0 else 1.4))
				_leaf(b, at, r * 0.55, r * 0.3, -side * 0.5, Color("83bf5a"))
				_leaf(b, at + Vector2(-r * 0.05, -r * 0.07), r * 0.42, r * 0.19, -side * 0.5, Color("a4d86f"))
				b.stroke(PackedVector2Array([at - Vector2(side * r * 0.36, -r * 0.2), at + Vector2(side * r * 0.3, -r * 0.16)]), 2.0, Color("6f9f3e"))
			b.disc(Vector2(r * 0.07, -r * 1.76), r * 0.5, Color("86c05a"))
			b.disc(Vector2(0.0, -r * 1.8), r * 0.47, Color("a6d96e"))
			b.disc(Vector2(-r * 0.14, -r * 1.94), r * 0.2, Color("cdf09a"))
		3:
			b.polygon(Face.Builder.round_rect(Vector2(-r * 0.16, -r * 0.7), Vector2(r * 0.32, r * 0.7), 4.0), Color("7a5236"))
			b.polygon(Face.Builder.round_rect(Vector2(r * 0.03, -r * 0.7), Vector2(r * 0.13, r * 0.7), 4.0), Color("63412a"))
			_tier(b, r, -r * 0.45, r * 1.0, r * 1.1, Color("3a785a"), Color("4b8f6b"))
			b.ellipse(Vector2(r * 0.05, -r * 1.1), r * 0.6, r * 0.13, Color("2f6a4c"))
			_tier(b, r, -r * 1.2, r * 0.8, r * 1.0, Color("44866a"), Color("569c79"))
			b.ellipse(Vector2(r * 0.04, -r * 1.78), r * 0.42, r * 0.1, Color("397758"))
			_tier(b, r, -r * 1.85, r * 0.58, r * 0.95, Color("4f9370"), Color("67ad88"))
		_:
			var stout := 0.82 if look == 1 else (1.25 if look == 2 else 1.0)
			_trunk(b, r, TRUNK[look], stout)
			if look == 1:
				for m: Array in [[-0.9, -0.34, 0.9], [0.2, -0.62, 0.8], [-0.7, -0.9, 0.7]]:
					var w := r * 0.13 * stout
					b.polygon(Face.Builder.round_rect(Vector2(w * float(m[0]), r * float(m[1])), Vector2(w * float(m[2]), 3.6), 1.8), Color("6e6057"))
			_crown(b, r, CROWN[look], 0.9 if look == 1 else (1.08 if look == 2 else 1.0), look)
			if look == 4:
				for o: Vector2 in [Vector2(-0.7, -1.25), Vector2(0.5, -1.62), Vector2(0.1, -2.12), Vector2(0.78, -1.14),
						Vector2(-0.34, -1.72), Vector2(0.28, -1.28), Vector2(-0.92, -1.56)]:
					b.disc(o * r, r * 0.075, Color("fff6e6"))
				# petals it has dropped
				for o: Vector2 in [Vector2(-0.86, 0.1), Vector2(0.72, 0.16), Vector2(0.34, 0.26), Vector2(-0.4, 0.24)]:
					b.ellipse(o * r, r * 0.07, r * 0.045, Color("f7b9d2"))

## A trunk up to where the crown hides it: flared at the foot, forked at the
## top, the side away from the light a tone darker.
static func _trunk(b: Face.Builder, r: float, tones: Array, stout: float) -> void:
	var w := r * 0.13 * stout
	var top := -r * 1.3
	var waist := -r * 0.5
	var right := Face.Builder.bezier2(Vector2(w, waist), Vector2(w * 1.05, -r * 0.06), Vector2(w * 2.3, 0.0), 8)
	var pts := Face.Builder.bezier2(Vector2(-w * 2.3, 0.0), Vector2(-w * 1.05, -r * 0.06), Vector2(-w, waist), 8)
	pts.append_array([Vector2(-w, waist), Vector2(-w * 0.8, top), Vector2(w * 0.8, top)])
	pts.append_array(right)
	pts.append(Vector2(w * 2.3, 0.0))
	b.polygon(pts, tones[0])
	var shade := PackedVector2Array([Vector2(w * 0.1, top), Vector2(w * 0.8, top)])
	shade.append_array(right)
	shade.append_array([Vector2(w * 2.3, 0.0), Vector2(w * 0.8, 0.0), Vector2(w * 0.25, waist)])
	b.polygon(shade, tones[1])
	b.stroke(PackedVector2Array([Vector2(0.0, -r * 1.0), Vector2(-r * 0.4, -r * 1.5)]), w * 1.1, tones[0])
	b.stroke(PackedVector2Array([Vector2(0.0, -r * 1.05), Vector2(r * 0.38, -r * 1.48)]), w * 1.1, tones[1])

## A crown about (0, -1.7 r), `wide` times as broad: its shade showing under
## it, its body, the side the light is on and the brightest clumps, then
## leaves of one tone dabbed over another so no edge between them is clean.
static func _crown(b: Face.Builder, r: float, tones: Array, wide: float, seed: int) -> void:
	var layers := [
		[[-0.56, -1.2, 0.54], [0.6, -1.18, 0.54], [0.03, -1.16, 0.54]],
		[[-0.68, -1.44, 0.6], [0.7, -1.42, 0.58], [-0.3, -1.95, 0.66], [0.38, -1.9, 0.64], [0.0, -1.5, 0.7]],
		[[-0.56, -1.58, 0.5], [0.3, -1.66, 0.5], [-0.16, -2.02, 0.56], [-0.08, -1.56, 0.52]],
		[[-0.44, -2.1, 0.25], [-0.76, -1.66, 0.19], [0.1, -2.26, 0.17], [0.3, -1.78, 0.16]],
	]
	for i in layers.size():
		for d: Array in layers[i]:
			b.disc(Vector2(float(d[0]) * wide, float(d[1])) * r, float(d[2]) * r, tones[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + seed
	var dabs := [
		[2, [[0.62, -1.5], [0.84, -1.34], [0.56, -2.0], [0.3, -1.28], [0.78, -1.78], [-0.24, -1.16], [0.08, -1.22]]],
		[1, [[-0.3, -1.7], [0.08, -1.86], [-0.56, -1.38], [0.02, -1.44], [0.36, -1.5]]],
		[3, [[-0.2, -1.78], [-0.64, -1.9], [0.22, -2.06], [-0.9, -1.46], [0.5, -1.72]]],
	]
	for group: Array in dabs:
		for d: Array in group[1]:
			_leaf(b, Vector2(float(d[0]) * wide, float(d[1])) * r, r * rng.randf_range(0.1, 0.15), r * rng.randf_range(0.055, 0.08),
				rng.randf_range(-0.9, 0.9), tones[int(group[0])])

## One skirt of the pine: a foot that hangs in three scallops, drawn up to a
## point, its left side `lit`.
static func _tier(b: Face.Builder, r: float, foot: float, half: float, high: float, colour: Color, lit: Color) -> void:
	var pts := PackedVector2Array()
	for i in 3:
		var x0 := lerpf(-half, half, i / 3.0)
		var x1 := lerpf(-half, half, (i + 1) / 3.0)
		pts.append_array(Face.Builder.bezier2(Vector2(x0, foot), Vector2((x0 + x1) * 0.5, foot + r * 0.24), Vector2(x1, foot), 6))
	pts.append(Vector2(half, foot))
	pts.append(Vector2(r * 0.1, foot - high))
	pts.append(Vector2(-r * 0.1, foot - high))
	b.polygon(pts, colour)
	b.polygon(PackedVector2Array([Vector2(-half, foot), Vector2(-half * 0.36, foot + r * 0.02),
		Vector2(-r * 0.01, foot - high * 0.94), Vector2(-r * 0.1, foot - high)]), lit)

static func _leaf(b: Face.Builder, centre: Vector2, rx: float, ry: float, turn: float, colour: Color) -> void:
	var xf := Transform2D(turn, centre)
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, rx, ry), colour)

# --- the wind ---

## The material that leans what a Control draws: trees, or (`grass`) what is
## a hand high. One of each, shared by every screen that shows the land.
static func wind(grass := false) -> ShaderMaterial:
	if not _winds.has(grass):
		var m := ShaderMaterial.new()
		m.shader = WIND
		m.set_shader_parameter("tall", 14.0 if grass else 120.0)
		m.set_shader_parameter("reach", 2.6 if grass else 9.0)
		m.set_shader_parameter("rustle", 0.0 if grass else 1.2)
		_winds[grass] = m
	return _winds[grass]

## Called every frame by whatever shows the land: the wind's clock, and none
## of it under reduce motion. Returns the clock, for `gust`.
static func blow() -> float:
	var t := Time.get_ticks_msec() / 1000.0
	var all: Array = [wind(false), wind(true)]
	var live: Array[WeakRef] = []
	for ref in _shade_winds:
		var m: ShaderMaterial = ref.get_ref()
		if m != null:
			all.append(m)
			live.append(ref)
	_shade_winds = live
	for m: ShaderMaterial in all:
		m.set_shader_parameter("clock", t)
		m.set_shader_parameter("amp", 0.0 if Motion.reduce else 1.0)
	return t

## How hard it blows (0 to 1) at `x` across the screen at `t`: the shader's
## own gust, for what the screen moves by hand.
static func gust(x: float, t: float) -> float:
	return 0.5 + 0.5 * sin(t * 0.55 - x * 0.0035 + 1.7 * sin(t * 0.19))

## A tuft of grass on (0, 0): four thin blades, each to its own lean, in
## greys the instance's colour tints.
static func tuft() -> ArrayMesh:
	if _tuft == null:
		var b := Face.Builder.new()
		for bl: Array in [[-4.5, -4.5, 9.0, 0.93], [-1.5, -1.0, 14.0, 1.0], [1.5, 3.0, 11.0, 0.9], [4.5, 6.5, 7.0, 0.96]]:
			var x: float = bl[0]
			var lean: float = bl[1]
			var high: float = bl[2]
			var g: float = bl[3]
			b.polygon(PackedVector2Array([Vector2(x - 1.7, 0.0), Vector2(x - 1.2 + lean * 0.35, -high * 0.55), Vector2(x + lean, -high),
				Vector2(x + 1.2 + lean * 0.45, -high * 0.5), Vector2(x + 1.7, 0.0)]), Color(g, g, g))
		_tuft = b.mesh()
	return _tuft

## A flower on (0, 0): a stem, a leaf and five petals round a yellow eye.
static func flower() -> ArrayMesh:
	if _flower == null:
		var b := Face.Builder.new()
		var head := Vector2(1.5, -15.0)
		b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(-0.6, -8.0), head]), 2.4, Color("7fae4a"))
		_leaf(b, Vector2(-3.4, -6.0), 3.6, 1.7, 0.5, Color("8cc152"))
		for i in 5:
			b.disc(head + Vector2.from_angle(TAU * i / 5.0 - 0.3) * 3.6, 3.1, Color("fffaf0"))
		b.disc(head, 2.6, Pal.SUN)
		_flower = b.mesh()
	return _flower

## A loose leaf about (0, 0), pale, for the instance's colour to tint.
static func leaf() -> ArrayMesh:
	if _leaf_mesh == null:
		var b := Face.Builder.new()
		_leaf(b, Vector2.ZERO, 6.0, 3.2, 0.0, Color.WHITE)
		b.stroke(PackedVector2Array([Vector2(-4.5, 0.0), Vector2(4.5, 0.0)]), 1.0, Color(0.82, 0.82, 0.82))
		_leaf_mesh = b.mesh()
	return _leaf_mesh

## The grass that stands on a plate of `kind`: its tufts, and its flowers in
## a few drifts, a MultiMesh each in the plate's own view units (draw them
## where the plate is drawn), for a layer wearing `wind(true)`. Neutral
## ground grows none. Kept: plates of a kind share them.
static func grass(kind: String, variant := 0) -> Array[MultiMesh]:
	var key := "%s|%d" % [kind, variant]
	if _grass.has(key):
		return _grass[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006 + kind.length() * 131 + variant * 7919
	var grows: Array = GROWS.get(kind, GROWS["forest"])
	var spots := [[], []]
	for i in int(grows[0]):
		spots[0].append(_on_plate(rng, 34.0))
	for drift in int(grows[1]):
		var c := _on_plate(rng, 90.0)
		for i in rng.randi_range(3, 5):
			spots[1].append(c + Vector2(rng.randf_range(-52.0, 52.0), rng.randf_range(-52.0, 52.0) * DEEP))
	var out: Array[MultiMesh] = []
	for which in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = tuft() if which == 0 else flower()
		mm.instance_count = spots[which].size()
		var tints: Array = TUFTS if which == 0 else PETALS
		for i in spots[which].size():
			var s := rng.randf_range(0.8, 1.25)
			var flip := -1.0 if rng.randf() < 0.5 else 1.0
			mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(s * flip, s), 0.0, spots[which][i]))
			mm.set_instance_color(i, tints[rng.randi() % tints.size()])
		out.append(mm)
	_grass[key] = out
	return out

## How tall a tree of `look` stands above its foot as it is drawn, for what
## is drawn over it.
static func height(look: int) -> float:
	var r: float = RADIUS[look]
	return r * (2.3 if look == 0 else (2.8 if look == 3 else 2.6)) * TREE_SCALE

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

## Lily pads about (0, 0), in view units: `n` of them, the first in flower
## when `bloom`. For a screen to lay on water it knows to be open, in the
## land's own space so they pan with it.
static func pads(n := 3, bloom := false) -> ArrayMesh:
	var key := n * 2 + int(bloom)
	if not _pads.has(key):
		var b := Face.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 311 + key
		for i in n:
			var c := Vector2.from_angle(TAU * i / maxi(1, n) + rng.randf()) * Vector2(58.0, 34.0) * (0.0 if i == 0 else 1.0)
			var r := rng.randf_range(28.0, 38.0) * (1.0 if i == 0 else 0.74)
			_lily(b, c, r, rng.randf_range(0.0, TAU))
			if i == 0 and bloom:
				for k in 6:
					b.ellipse(c + Vector2(cos(TAU * k / 6.0) * 6.0, sin(TAU * k / 6.0) * 3.4 - 4.0), 5.4, 3.6, Color("fbd0e2"))
				b.ellipse(c + Vector2(0.0, -4.5), 3.6, 2.6, Color("fff0b8"))
		_pads[key] = b.mesh()
	return _pads[key]

## A lily pad lying flat on the pond, its shade on the water under it.
static func _lily(b: Face.Builder, c: Vector2, r: float, turn: float) -> void:
	var lie := Transform2D(0.0, Vector2(1.0, DEEP), 0.0, c)
	var pts := Face.Builder.arc_points(Vector2.ZERO, r, turn + 0.35, turn + 6.0)
	pts.append(Vector2.ZERO)
	b.polygon(Transform2D(0.0, Vector2(1.0, DEEP), 0.0, c + Vector2(1.0, 4.0)) * pts, Color(SHADE, 0.2))
	b.polygon(lie * pts, LILY)
	b.stroke(lie * Face.Builder.arc_points(Vector2.ZERO, r * 0.6, turn + 0.9, turn + 5.2), maxf(1.6, r * 0.09), LILY_HI)

# --- a plate of land ---

## One plate's land, in view units, the corner of its local tile (0, 0) (its
## back corner) on the mesh's origin: a screen draws it at at(P * 8), the
## plates sorted by P.x + P.y so the one in front is drawn last. `kind` is
## forest (the Grove's grass under a dark floor, closed by a hedge with a
## gate in each side) or neutral (white ground, the tiles ruled on it).
##
## `sides` says where the land goes on: bit i is set when a plate lies
## beyond the side toward DIRS[i]. Such a side is cut straight and has no
## earth under it, no mirror and no rim of light. A corner is rounded only
## where both its sides are free: where one of them is joined the shore of
## the plate beyond runs straight on from this one's, and a rounded corner
## there left a cleft of water in a shore that should be one line. The seam
## itself is the work of the plate in front (its -x and -y sides, drawn
## last): its grass fades a third of a tile out over the plate behind and a
## low bank of turf lies along the line.
##
## The corners of the tiles are marked on the grass with two short ticks,
## so a belt's way can be seen before it is laid.
static func plate(kind: String, sides := 0, variant := 0) -> ArrayMesh:
	sides &= 15
	var key := "%s|%d|%d" % [kind, sides, variant]
	if not _plates.has(key):
		var b := Face.Builder.new()
		_plate_into(b, kind, sides, variant)
		_plates[key] = b.mesh()
	return _plates[key]

## The plate's edge in view units, clockwise from its back corner, a point
## every half tile along a side: [points, the side each point's way to the
## next lies on (-1 round a corner), how far along that side it is (0..1)].
static func _rim(sides: int) -> Array:
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(PLATE, 0.0), Vector2(PLATE, PLATE), Vector2(0.0, PLATE)]
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
			along[along.size() - 1] = r / PLATE
		else:
			pts.append(at(c))
			tags.append(out)
			along.append(0.0)
		var last := PLATE - round[(i + 1) % 4]
		for k in range(1, PLATE * 2):
			var s := k * 0.5
			if s > r + 0.05 and s < last - 0.05:
				pts.append(at(c + to_next * s))
				tags.append(out)
				along.append(s / PLATE)
	return [pts, tags, along]

## A point of a plate's ground at least `inside` view units from its edge.
static func _on_plate(rng: RandomNumberGenerator, inside: float) -> Vector2:
	var m := clampf(inside / (K * sqrt(2.0)), 0.1, PLATE * 0.45)
	return at(Vector2(rng.randf_range(m, PLATE - m), rng.randf_range(m, PLATE - m)))

static func _plate_into(b: Face.Builder, kind: String, sides: int, variant: int) -> void:
	var tone: Dictionary = GROUND.get(kind, GROUND["forest"])
	var rim: Array = _rim(sides)
	var pts: PackedVector2Array = rim[0]
	var tags: PackedInt32Array = rim[1]
	var along: PackedFloat32Array = rim[2]
	var n := pts.size()
	# the shore's own dice: the ground's must fall the same whatever is joined
	var edge_rng := RandomNumberGenerator.new()
	edge_rng.seed = 20261005 + sides * 31 + variant * 977 + kind.length()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010 + variant * 7919 + kind.length() * 131
	# the front of the land, from its right corner round to its left, in runs
	# of free shore: where a plate is joined there is no earth to show
	var hi := 0
	var lo := 0
	for i in n:
		if pts[i].x > pts[hi].x:
			hi = i
		if pts[i].x < pts[lo].x:
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
		_shore_into(b, edge, shade, f, edge_rng, tone)
		shores.append([edge, shade])
	b.polygon(pts, tone["grass"])
	# the wash: warm toward the sun, cool away from it, and patches of both
	var warm: Color = tone["warm"]
	var cool: Color = tone["cool"]
	var lit: Color = tone["lit"]
	var deep: Color = tone["deep"]
	_glow(b, at(Vector2(2.9, 4.5)), 215.0, 215.0 * DEEP, warm, 0.5)
	_glow(b, at(Vector2(5.2, 5.2)) + Vector2(110.0, 0.0), 205.0, 205.0 * DEEP, cool, 0.34)
	for k in 16:
		var r := rng.randf_range(90.0, 190.0)
		var p := _on_plate(rng, r * 1.06)
		var sunny := (-p.x - (p.y / DEEP - HALF)) / HALF
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
		var from := Vector2(0.0, PLATE - 0.5) if side == 2 else Vector2(0.5, 0.0)
		var to := Vector2(0.0, 0.5) if side == 2 else Vector2(PLATE - 0.5, 0.0)
		b.stroke(PackedVector2Array([at(from) + Vector2(1.0, 2.5), at(to) + Vector2(-1.0 if side == 3 else 1.0, 2.5)]), 2.6,
			Color(0.9, 0.96, 0.66, 0.42 if side == 2 else 0.24), false, false)
	if kind == "neutral":
		_neutral_into(b, rng)
	else:
		for k in 80:
			var p := _on_plate(rng, 30.0)
			var long := rng.randf_range(8.0, 17.0)
			b.stroke(PackedVector2Array([p, p + Vector2(long, -long * 0.2)]), 2.6, Color(lit, 0.6) if k % 2 else Color(deep, 0.5))
		for k in 18:
			var r := rng.randf_range(22.0, 46.0)
			_glow(b, _on_plate(rng, r + 20.0), r, r * DEEP, warm.lerp(lit, rng.randf()), 0.42)
		for k in 6:
			_pebble(b, _on_plate(rng, 40.0), 1.0)
	if kind == "forest" or kind == "mine":
		_forest_into(b, kind == "mine")
	# the tiles' corners, where no shore is
	var tick := Color(deep.darkened(0.12), 0.34 if kind == "neutral" else 0.0)
	for tx in PLATE + 1:
		for ty in PLATE + 1:
			if (tx == PLATE and (sides & 1) == 0) or (ty == PLATE and (sides & 2) == 0) or (tx == 0 and (sides & 4) == 0) or (ty == 0 and (sides & 8) == 0):
				continue
			var c := Vector2(tx, ty)
			b.stroke(PackedVector2Array([at(c - Vector2(0.09, 0.0)), at(c + Vector2(0.09, 0.0))]), 2.4, tick)
			b.stroke(PackedVector2Array([at(c - Vector2(0.0, 0.09)), at(c + Vector2(0.0, 0.09))]), 2.4, tick)
			b.ellipse(at(c) + Vector2(-0.6, -0.8), 1.6, 1.1, Color(lit, 0.5))
	# the seams with the plates behind, which were drawn first
	for side: int in [2, 3]:
		if (sides & (1 << side)) != 0:
			_seam_into(b, side, tone, edge_rng)

## The shore under a run of free edge: the land's mirror on the pond, the
## earth and the clay under it (each point of `edge` with how far it looks
## from the sun in `shade`, so the lit left goes over to the shaded right
## round a corner), a pale line and broken rings at the water, and the turf
## hanging over in scallops. A run that ends at a plate's cut side ends
## square: the next plate's shore begins there, the same line.
static func _shore_into(b: Face.Builder, edge: PackedVector2Array, shade: PackedFloat32Array, along: PackedFloat32Array,
		rng: RandomNumberGenerator, tone: Dictionary) -> void:
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
	var middle := at(Vector2(PLATE, PLATE) * 0.5)
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
static func _seam_into(b: Face.Builder, side: int, tone: Dictionary, rng: RandomNumberGenerator) -> void:
	var from := Vector2(0.0, PLATE) if side == 2 else Vector2.ZERO
	var to := Vector2.ZERO if side == 2 else Vector2(PLATE, 0.0)
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

## A rock of a mine, standing on (0, 0), its shade under it: `look` 0 to 3,
## a boulder of two or three faces with a smaller one against it. A mine is
## seen by these as a forest by its trees; they are never used up.
static func rock(look: int) -> ArrayMesh:
	look = posmod(look, ROCK_R.size())
	var key := "rock%d" % look
	if _one.has(key):
		return _one[key]
	var b := Face.Builder.new()
	var r: float = ROCK_R[look]
	var tall: float = ROCK_TALL[look]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4100 + look
	b.ellipse(Vector2(r * 0.22, 4.0), r * 1.18, r * 0.42, SHADE)
	# the small one behind and to the right, then the big one
	for part: Array in [[Vector2(r * 0.56, -2.0), 0.52], [Vector2(-r * 0.12, 0.0), 1.0]]:
		var c: Vector2 = part[0]
		var k: float = part[1]
		var w := r * k * 0.86
		var h := tall * k
		var lean := rng.randf_range(-0.12, 0.12) * w
		var body := PackedVector2Array([c + Vector2(-w, 0.0), c + Vector2(-w * 0.92, -h * 0.5), c + Vector2(-w * 0.5 + lean, -h * 0.9),
			c + Vector2(w * 0.1 + lean, -h), c + Vector2(w * 0.7 + lean, -h * 0.78), c + Vector2(w, -h * 0.3), c + Vector2(w * 0.86, 4.0), c + Vector2(-w * 0.6, 6.0)])
		b.polygon(body, ROCK)
		# the face away from the sun
		b.polygon(PackedVector2Array([c + Vector2(w * 0.1 + lean, -h), c + Vector2(w * 0.7 + lean, -h * 0.78), c + Vector2(w, -h * 0.3), c + Vector2(w * 0.86, 4.0),
			c + Vector2(w * 0.3, 5.0), c + Vector2(w * 0.22, -h * 0.5)]), ROCK_SHADE)
		# the top, where the light lies
		b.polygon(PackedVector2Array([c + Vector2(-w * 0.92, -h * 0.5), c + Vector2(-w * 0.5 + lean, -h * 0.9), c + Vector2(w * 0.1 + lean, -h),
			c + Vector2(w * 0.22, -h * 0.5), c + Vector2(-w * 0.34, -h * 0.4)]), ROCK_LIT)
		b.stroke(PackedVector2Array([c + Vector2(-w * 0.34, -h * 0.4), c + Vector2(-w * 0.2, -h * 0.14), c + Vector2(-w * 0.4, 3.0)]), 1.8 * k, ROCK_CRACK)
		if look % 2 == 0:
			b.stroke(PackedVector2Array([c + Vector2(w * 0.22, -h * 0.5), c + Vector2(w * 0.5, -h * 0.3)]), 1.6 * k, ROCK_CRACK)
	# what has been knocked off it
	for i in 3:
		var p := Vector2(rng.randf_range(-r, r * 0.9), rng.randf_range(5.0, 11.0))
		b.ellipse(p, 5.0, 3.2, ROCK_SHADE)
		b.ellipse(p + Vector2(-1.0, -1.0), 3.4, 2.0, ROCK_LIT)
	_one[key] = b.mesh()
	return _one[key]

## What a mine holds, lying by its gate with the middle of its foot on
## (0, 0): one chunk, two, three, a low heap, a big one, by `heap_of(n)`.
static func rubble(n: int) -> ArrayMesh:
	var step := heap_of(n)
	var key := "rubble%d" % step
	if _one.has(key):
		return _one[key]
	var b := Face.Builder.new()
	var at_: Array = [[Vector2.ZERO], [Vector2(-13.0, 0.0), Vector2(13.0, 2.0)], [Vector2(-14.0, 0.0), Vector2(14.0, 2.0), Vector2(0.0, -15.0)],
		[Vector2(-26.0, -2.0), Vector2(0.0, 0.0), Vector2(26.0, 2.0), Vector2(-13.0, -17.0), Vector2(13.0, -15.0)],
		[Vector2(-28.0, -3.0), Vector2(-2.0, -1.0), Vector2(26.0, 2.0), Vector2(-15.0, -18.0), Vector2(12.0, -16.0), Vector2(-2.0, -33.0), Vector2(0.0, 6.0)]][step]
	var wide := 24.0 if step < 3 else 46.0
	b.ellipse(Vector2(5.0, 2.0), wide + 6.0, 9.0 if step < 3 else 13.0, CAST)
	var order := at_.duplicate()
	order.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y if absf(p.y - q.y) > 8.0 else p.x < q.x)
	# the foot row last so a chunk in front lies over the one behind it
	for c: Vector2 in at_.slice(0, 3):
		_chunk(b, c, 0.72)
	for c: Vector2 in at_.slice(3):
		_chunk(b, c, 0.72)
	_one[key] = b.mesh()
	return _one[key]

## A pebble on the grass, its shade under it.
static func _pebble(b: Face.Builder, c: Vector2, s: float) -> void:
	b.ellipse(c + Vector2(2.0, 3.0) * s, 9.0 * s, 4.6 * s, SHADE)
	b.ellipse(c, 8.0 * s, 5.4 * s, Pal.ROCK)
	b.ellipse(c + Vector2(-2.0, -1.8) * s, 3.6 * s, 2.2 * s, Color("d8cdb6"))

## Neutral ground: every tile ruled on it with a thin line, a few of them a
## tone off, and a speckle, so that white is a floor and not a hole.
static func _neutral_into(b: Face.Builder, rng: RandomNumberGenerator) -> void:
	var tone: Dictionary = GROUND["neutral"]
	var deep: Color = tone["deep"]
	for k in 12:
		var t := Vector2(rng.randi_range(0, PLATE - 1), rng.randi_range(0, PLATE - 1))
		b.polygon(PackedVector2Array([at(t + Vector2(0.06, 0.06)), at(t + Vector2(0.94, 0.06)), at(t + Vector2(0.94, 0.94)), at(t + Vector2(0.06, 0.94))]),
			Color(deep, 0.1) if k % 3 else Color(1.0, 1.0, 1.0, 0.5))
	for k in range(1, PLATE):
		b.stroke(PackedVector2Array([at(Vector2(k, 0.12)), at(Vector2(k, PLATE - 0.12))]), 1.8, Color(deep, 0.42), false, false)
		b.stroke(PackedVector2Array([at(Vector2(0.12, k)), at(Vector2(PLATE - 0.12, k))]), 1.8, Color(deep, 0.42), false, false)
	for k in 90:
		var p := _on_plate(rng, 26.0)
		var r := rng.randf_range(1.4, 2.8)
		b.ellipse(p, r, r * DEEP, Color(deep, rng.randf_range(0.3, 0.6)))

## What closes a forest: the dark floor under its trees, a hedge along the
## middle of its rim tiles on all four sides, the back two first, and in each
## side a gate, the hedge open on a plank chute between two posts that runs
## out to the edge. The hedge is in the ground's mesh, half a tile in from
## the edge, so the seam of the plate in front does not lie over it.
## A mine (`stony`) is closed the same way by a wall of piled stones over a
## dug floor with rubble on it.
static func _forest_into(b: Face.Builder, stony := false) -> void:
	var inner := PackedVector2Array([at(Vector2(0.9, 0.9)), at(Vector2(PLATE - 0.9, 0.9)), at(Vector2(PLATE - 0.9, PLATE - 0.9)), at(Vector2(0.9, PLATE - 0.9))])
	b.polygon(inner, PIT_FLOOR if stony else FLOOR)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261011
	if stony:
		for k in 46:
			var t := Vector2(rng.randf_range(1.1, PLATE - 1.1), rng.randf_range(1.1, PLATE - 1.1))
			var r := rng.randf_range(3.0, 7.5)
			b.ellipse(at(t) + Vector2(1.5, 2.0), r * 1.1, r * 0.62, SHADE)
			b.ellipse(at(t), r, r * 0.66, WALL if k % 3 else WALL_DEEP)
			b.ellipse(at(t) + Vector2(-r * 0.25, -r * 0.2), r * 0.45, r * 0.28, WALL_LIT)
	for side: int in [3, 2, 0, 1]:
		var out := Vector2(DIRS[side])
		var along := Vector2(-out.y, out.x).abs()
		var mid := Vector2(PLATE, PLATE) * 0.5 + out * (PLATE * 0.5 - 0.5)
		var g := Vector2(GATES[side]) + Vector2(0.5, 0.5)
		var gate_s := (g - mid).dot(along)
		# the chute: planks from the gate tile's middle out to the plate's edge
		var a := g - along * 0.3
		var c := g + along * 0.3
		b.polygon(PackedVector2Array([at(a) + Vector2(3.0, 5.0), at(c) + Vector2(3.0, 5.0), at(c + out * 0.5) + Vector2(3.0, 5.0), at(a + out * 0.5) + Vector2(3.0, 5.0)]), SHADE)
		b.polygon(PackedVector2Array([at(a), at(c), at(c + out * 0.5), at(a + out * 0.5)]), PLANK)
		for k in 4:
			var t := 0.06 + k * 0.125
			b.stroke(PackedVector2Array([at(a + out * t), at(c + out * t)]), 2.0, PLANK_DEEP, false, false)
		var bushes: Array = []
		var s := -PLATE * 0.5 + 0.5
		while s <= PLATE * 0.5 - 0.5 + 0.01:
			if absf(s - gate_s) > 0.52:
				bushes.append(at(mid + along * s) + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0)))
			s += 0.25
		bushes.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
		for p: Vector2 in bushes:
			b.ellipse(p + Vector2(7.0, 5.0), 21.0, 9.0, SHADE)
		for p: Vector2 in bushes:
			var r := rng.randf_range(15.0, 19.0)
			if stony:
				# a stone of the wall: squat, a lit top and a dark foot
				var w := r * rng.randf_range(0.95, 1.2)
				var h := r * rng.randf_range(0.62, 0.84)
				b.ellipse(p + Vector2(0.0, -h * 0.55), w, h, WALL_DEEP)
				b.ellipse(p + Vector2(-1.5, -h * 0.72), w * 0.9, h * 0.8, WALL)
				b.ellipse(p + Vector2(-w * 0.26, -h * 1.02), w * 0.5, h * 0.36, WALL_LIT)
				continue
			b.disc(p + Vector2(0.0, -r * 0.55), r, HEDGE_DEEP)
			b.disc(p + Vector2(-1.5, -r * 0.7), r * 0.86, HEDGE)
			b.disc(p + Vector2(-r * 0.3, -r * 0.95), r * 0.46, HEDGE_LIT)
		for e: float in [-0.42, 0.42]:
			var foot := at(g + along * e)
			b.ellipse(foot + Vector2(5.0, 3.0), 9.0, 4.0, SHADE)
			b.polygon(PackedVector2Array([foot + Vector2(-5.0, 2.0), foot + Vector2(5.0, 2.0), foot + Vector2(5.0, -34.0), foot + Vector2(-5.0, -34.0)]), PLANK)
			b.polygon(PackedVector2Array([foot + Vector2(1.0, 2.0), foot + Vector2(5.0, 2.0), foot + Vector2(5.0, -34.0), foot + Vector2(1.0, -34.0)]), PLANK_DEEP)
			b.ellipse(foot + Vector2(0.0, -34.0), 6.0, 3.2, ROPE)

## What lies over the land and its trees: warm light from where the sun is,
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

# --- what a tree leaves ---

## How a stack of `n` piles is drawn: one log, two, three, a low heap, a big
## one. A stack may hold thousands; its count says so, not its drawing.
static func heap_of(n: int) -> int:
	return clampi(n, 1, 3) - 1 if n < 4 else (3 if n < 10 else 4)

## How tall the heap of `n` piles stands, in view units: a log and LOG_RISE
## of one for each row over it.
static func heap_tall(n: int) -> float:
	return (2.0 + LOG_RISE * ((HEAP[heap_of(n)] as Array).size() - 1)) * LOG_R

## A stack of `n` piles lying with the middle of its foot on (0, 0), its
## shadow with it: cut logs seen from their sawn ends, their lengths running
## back to the upper left. `lucky`: a second small pile beside it.
static func pile(n: int, lucky := false) -> ArrayMesh:
	var step := heap_of(n)
	var key := step * 2 + int(lucky)
	if not _piles.has(key):
		var b := Face.Builder.new()
		if lucky:
			var twin := mini(step, 2)
			_pile_into(b, Vector2(LOG_R * (float(HEAP[step][0]) + float(HEAP[twin][0]) + 0.5), -7.0), twin, CAST)
		_pile_into(b, Vector2.ZERO, step, CAST)
		_piles[key] = b.mesh()
	return _piles[key]

## A heap of HEAP[step] with the middle of its foot at `at`, its shadow `tone`.
static func _pile_into(b: Face.Builder, at: Vector2, step: int, tone: Color) -> void:
	var rows: Array = HEAP[step]
	var r := LOG_R
	var back := LOG_BACK * LOG_LONG
	_lie_shade(b, at, float(rows[0]) * r, back, (2.0 + LOG_RISE * (rows.size() - 1)) * r, tone)
	# the lengths first, each row over the one under it and each log over the
	# one to its right, then every sawn end over them
	var ends: Array[Vector2] = []
	for j in rows.size():
		var m: int = rows[j]
		for i in range(m - 1, -1, -1):
			var c := at + Vector2((2.0 * i - (m - 1)) * r, -r - LOG_RISE * r * j)
			_log_body(b, c, r, back * (0.9 + 0.1 * ((i + j) % 2)))
			ends.append(c)
	for k in ends.size():
		_log_face(b, ends[k], r, k)

## The shadow of something lying with the middle of its front at `at`, `half`
## across and `back` deep, `high` tall: on the ground under it and out to the
## right, as the trees throw theirs, in `tone`.
static func _lie_shade(b: Face.Builder, at: Vector2, half: float, back: Vector2, high: float, tone: Color) -> void:
	var reach := high * 0.5
	var xf := Transform2D(Vector2(half + reach * 0.5 + 3.0, reach * 0.07) * 0.1, back * 0.066,
		at + back * 0.5 + Vector2(reach * 0.5, reach * 0.07 + 1.5))
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, 10.0, 10.0), tone)

## A log's length from its sawn end at `c` back along `back`: bark, lit along
## its top and dark under it.
static func _log_body(b: Face.Builder, c: Vector2, r: float, back: Vector2) -> void:
	var up := Vector2(-back.y, back.x).normalized()
	b.stroke(PackedVector2Array([c, c + back]), r * 2.0, BARK)
	b.stroke(PackedVector2Array([c + up * r * 0.46 + back * 0.12, c + up * r * 0.46 + back * 0.96]), r * 0.5, BARK.lightened(0.17))
	b.stroke(PackedVector2Array([c - up * r * 0.6 + back * 0.1, c - up * r * 0.6 + back * 0.9]), r * 0.5, BARK.darkened(0.14))

## A log's sawn end at `c`: pale wood inside a rim of bark, a ring in it.
static func _log_face(b: Face.Builder, c: Vector2, r: float, k: int) -> void:
	b.ellipse(c, r * 0.9, r * 0.97, BARK.darkened(0.22))
	b.ellipse(c, r * 0.7, r * 0.78, PITH if k % 2 == 0 else PITH.darkened(0.06))
	b.stroke(Face.Builder.ring(c, r * 0.36, r * 0.41), r * 0.12, Color(BARK, 0.55), true)
	b.disc(c, r * 0.1, Color(BARK, 0.6))

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
			if mid.x + mid.y <= 0.02:
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
			if out.x + out.y > 0.0:
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

## A splitter's housing, in view units about the middle of its tile, facing
## `facing` as seen: a low wooden box standing over the belt's bed, open to
## the eye by nothing (what crosses it is hidden inside), a brass plate on
## its top with an arrow to each of its three ways out. Drawn among what
## stands, so it lies over the things riding into it.
static func splitter(facing: int) -> ArrayMesh:
	var key := "splitter%d" % posmod(facing, 4)
	if _one.has(key):
		return _one[key]
	var b := Face.Builder.new()
	var z0 := BELT_UP - 2.0
	var z1 := BELT_UP + 24.0
	var half := Vector2(0.4, 0.4)
	_block(b, Vector2.ZERO, half, z0, z1, [PLANK.lightened(0.12), PLANK, PLANK_DEEP])
	# planks on the two walls the eye sees
	for k in range(1, 4):
		var u := -half.x + half.x * 2.0 * k / 4.0
		b.stroke(PackedVector2Array([_p(Vector2(u, half.y), z0 + 1.0), _p(Vector2(u, half.y), z1 - 1.0)]), 1.6, Color(PLANK_DEEP, 0.7), false, false)
		b.stroke(PackedVector2Array([_p(Vector2(half.x, -u), z0 + 1.0), _p(Vector2(half.x, -u), z1 - 1.0)]), 1.6, Color(PLANK_DEEP.darkened(0.25), 0.7), false, false)
	# the dark mouths where the bed goes in and out, on the walls that are seen
	var f := posmod(facing, 4)
	for d in 4:
		if d == (f + 2) % 4 and d != 1 and d != 0:
			continue
		var out := Vector2(DIRS[d])
		if d == 1:
			b.polygon(PackedVector2Array([_p(Vector2(-0.2, half.y), z0), _p(Vector2(0.2, half.y), z0), _p(Vector2(0.2, half.y), z0 + 15.0), _p(Vector2(-0.2, half.y), z0 + 15.0)]), HOLLOW)
		elif d == 0:
			b.polygon(PackedVector2Array([_p(Vector2(half.x, 0.2), z0), _p(Vector2(half.x, -0.2), z0), _p(Vector2(half.x, -0.2), z0 + 15.0), _p(Vector2(half.x, 0.2), z0 + 15.0)]), HOLLOW.darkened(0.2))
	# the brass plate and its arrows: ahead and to both sides
	var plate := PackedVector2Array()
	for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		plate.append(_p(o * 0.3, z1))
	b.polygon(plate, GOLD_DEEP)
	var inner := PackedVector2Array()
	for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		inner.append(_p(o * 0.26, z1))
	b.polygon(inner, GOLD)
	var ink := Color(0.32, 0.2, 0.08, 0.9)
	for q: int in [0, 1, 3]:
		var d := Vector2(DIRS[(f + q) % 4])
		var side := Vector2(-d.y, d.x)
		var tip := d * 0.22
		b.stroke(PackedVector2Array([_p(Vector2.ZERO, z1), _p(tip, z1)]), 3.0, ink)
		b.stroke(PackedVector2Array([_p(tip - d * 0.09 + side * 0.08, z1), _p(tip, z1), _p(tip - d * 0.09 - side * 0.08, z1)]), 3.0, ink)
	_one[key] = b.mesh()
	return _one[key]

# --- what is carried ---

## What a belt carries, resting on (0, 0), in view units and about 42
## across, so two lie along one tile: `log` (the Grove's, seen from its sawn
## end), `stone` (a pale chunk of limestone), `lime` (a white sack, tied)
## and `charcoal` (dark lumps in a small basket). Each has a little shade
## under it, so it sits on a belt and does not float.
static func item(kind: String) -> ArrayMesh:
	if not _items.has(kind):
		var b := Face.Builder.new()
		match kind:
			"stone":
				b.ellipse(Vector2(4.0, 1.0), 24.0, 7.0, CAST)
				_chunk(b, Vector2.ZERO, 1.0)
			"lime":
				b.ellipse(Vector2(4.0, 1.0), 22.0, 6.5, CAST)
				_sack(b, Vector2.ZERO, 1.0)
			"charcoal":
				b.ellipse(Vector2(4.0, 2.0), 21.0, 6.5, CAST)
				_basket(b, Vector2.ZERO, 1.0)
			"plank":
				b.ellipse(Vector2(3.0, 1.0), 22.0, 6.5, CAST)
				_planks(b, Vector2.ZERO)
			"chair":
				b.ellipse(Vector2(4.0, 1.0), 20.0, 7.0, CAST)
				_chair(b, Vector2.ZERO)
			_:
				var back := LOG_BACK * LOG_LONG
				var c := Vector2(-back.x * 0.5, -LOG_R)
				_lie_shade(b, Vector2(c.x, 0.0), LOG_R, back, LOG_R * 2.0, CAST)
				_log_body(b, c, LOG_R, back)
				_log_face(b, c, LOG_R, 0)
		_items[kind] = b.mesh()
	return _items[kind]

## A body's outline cut by itself moved over: the rim it shows on the side
## away from `shift`. How a round thing gets a lit edge and a shaded one.
static func _crescent(b: Face.Builder, outline: PackedVector2Array, shift: Vector2, colour: Color) -> void:
	for piece: PackedVector2Array in Geometry2D.clip_polygons(outline, Transform2D(0.0, shift) * outline):
		if piece.size() >= 3 and not Geometry2D.is_polygon_clockwise(piece):
			b.polygon(piece, colour)

## A chunk of limestone resting on `c`.
static func _chunk(b: Face.Builder, c: Vector2, s: float) -> void:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	b.polygon(xf * PackedVector2Array([Vector2(-20, -2), Vector2(-18, -16), Vector2(-7, -27), Vector2(9, -25), Vector2(19, -15), Vector2(21, -3), Vector2(10, 3), Vector2(-9, 4)]), LIME)
	b.polygon(xf * PackedVector2Array([Vector2(-18, -16), Vector2(-7, -27), Vector2(9, -25), Vector2(2, -15), Vector2(-9, -11)]), LIME_LIT)
	b.polygon(xf * PackedVector2Array([Vector2(9, -25), Vector2(19, -15), Vector2(21, -3), Vector2(10, 3), Vector2(5, -7), Vector2(2, -15)]), LIME_SHADE)
	b.stroke(xf * PackedVector2Array([Vector2(-9, -11), Vector2(-4, -2), Vector2(-9, 4)]), 1.4 * s, Color(LIME_SHADE, 0.7))

## A sack of lime standing on `c`: white cloth, tied at the neck, the house's
## teal dabbed on it so it is never taken for a stone.
static func _sack(b: Face.Builder, c: Vector2, s: float) -> void:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	var body := xf * PackedVector2Array([Vector2(-16, -1), Vector2(-19, -12), Vector2(-15, -24), Vector2(-6, -29), Vector2(6, -29), Vector2(15, -24),
		Vector2(19, -12), Vector2(16, -1), Vector2(8, 2), Vector2(-8, 2)])
	b.polygon(xf * PackedVector2Array([Vector2(-6, -28), Vector2(-10, -38), Vector2(0, -34), Vector2(10, -38), Vector2(6, -28)]), Color("e6dfcd"))
	b.polygon(body, Color("f6f1e6"))
	_crescent(b, body, Vector2(-7.0, -3.0) * s, Color("d3cbb8"))
	_crescent(b, body, Vector2(9.0, 5.0) * s, Color.WHITE)
	b.stroke(xf * PackedVector2Array([Vector2(-6.5, -28.5), Vector2(6.5, -28.5)]), 3.2 * s, ROPE_DEEP)
	b.disc(xf * Vector2(-1.0, -13.0), 5.0 * s, Color(Pal.ACCENT, 0.8))

## A small basket of charcoal standing on `c`.
static func _basket(b: Face.Builder, c: Vector2, s: float) -> void:
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	b.polygon(xf * PackedVector2Array([Vector2(-18, -15), Vector2(18, -15), Vector2(14, -1), Vector2(9, 3), Vector2(-9, 3), Vector2(-14, -1)]), ROPE_DEEP)
	b.polygon(xf * PackedVector2Array([Vector2(4, -15), Vector2(18, -15), Vector2(14, -1), Vector2(9, 3), Vector2(3, 3)]), ROPE_DEEP.darkened(0.16))
	for y: float in [-9.5, -3.5]:
		b.stroke(xf * PackedVector2Array([Vector2(-14.5, y), Vector2(14.5, y)]), 2.2 * s, Color(ROPE, 0.8))
	b.fan(xf * Face.Builder.ring(Vector2(0, -15), 19.0, 6.6), ROPE)
	b.fan(xf * Face.Builder.ring(Vector2(0, -15), 15.5, 4.8), Color("4b3a2e"))
	for lump: Array in [[-8.0, -18.0, 7.0], [6.0, -19.0, 8.0], [-1.0, -25.0, 7.5], [11.0, -16.0, 5.0], [-13.0, -16.0, 4.5]]:
		var p := xf * Vector2(lump[0], lump[1])
		var r: float = float(lump[2]) * s
		b.polygon(Transform2D(float(lump[0]) * 0.3, p) * PackedVector2Array([Vector2(-r, 0.2 * r), Vector2(-0.6 * r, -0.8 * r), Vector2(0.4 * r, -r),
			Vector2(r, -0.2 * r), Vector2(0.7 * r, 0.8 * r), Vector2(-0.4 * r, 0.9 * r)]), COAL)
		b.polygon(Transform2D(float(lump[0]) * 0.3, p) * PackedVector2Array([Vector2(-0.6 * r, -0.8 * r), Vector2(0.4 * r, -r), Vector2(0.1 * r, -0.3 * r),
			Vector2(-0.6 * r, -0.1 * r)]), COAL_LIT)

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
## `z0` up to `z1`: the two sides the eye sees, the one looking down and left
## in the sun and the one looking down and right in shade, and its top.
## `tones`: [top, lit, shaded].
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
	_courses(b, c + half, c + Vector2(half.x, -half.y), z0, z1, rows, Color(joint, joint.a * 1.3), brick)

## An arched opening in the wall from `a0` to `a1` (tiles): from `u0` to
## `u1` along it, straight from `z0` up to `zs`, round to `zt`.
static func _arch(a0: Vector2, a1: Vector2, u0: float, u1: float, z0: float, zs: float, zt: float) -> PackedVector2Array:
	var pts := PackedVector2Array([_p(a0.lerp(a1, u0), z0)])
	for i in 11:
		var a := PI - PI * i / 10.0
		pts.append(_p(a0.lerp(a1, (u0 + u1) * 0.5 + cos(a) * (u1 - u0) * 0.5), zs + sin(a) * (zt - zs)))
	pts.append(_p(a0.lerp(a1, u1), z0))
	return pts

## Points of a circle of `r` tiles lying `z` up about `c`, by the angle on
## the screen: 0 its right, a quarter turn its front.
static func _round(c: Vector2, r: float, z: float, from := 0.0, to := TAU, n := 22) -> PackedVector2Array:
	var rx := r * K * sqrt(2.0)
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

## The way in, the same on every module: a wooden hopper about `c`, `tall`
## high, open at the top and wider there.
static func _hopper(b: Face.Builder, c: Vector2, tall: float) -> void:
	var wood := [PLANK.lightened(0.1), PLANK.lightened(0.06), PLANK_DEEP]
	_block(b, c, Vector2(0.1, 0.1), 0.0, tall - 12.0, wood)
	_block(b, c, Vector2(0.15, 0.15), tall - 12.0, tall, [Color("59402f"), PLANK.lightened(0.14), PLANK_DEEP.lightened(0.04)])
	var lip := PackedVector2Array()
	for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		lip.append(_p(c + o * 0.15, tall))
	b.stroke(lip, 2.4, PLANK.lightened(0.26), true)
	b.stroke(PackedVector2Array([_p(c + Vector2(-0.15, 0.15), tall - 6.0), _p(c + Vector2(0.15, 0.15), tall - 6.0), _p(c + Vector2(0.15, -0.15), tall - 6.0)]),
		1.6, Color(PLANK_DEEP.darkened(0.2), 0.6), false, false)

## The way out, the same on every module: a low wooden tray about `c`, lying
## along `d`, a rim round it.
static func _tray(b: Face.Builder, c: Vector2, d: Vector2) -> void:
	var half := _half(d, 0.15, 0.2)
	_block(b, c, half, 0.0, 8.0, [PLANK.lightened(0.2), PLANK, PLANK_DEEP])
	var rim := PackedVector2Array()
	for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		rim.append(_p(c + half * o * 0.82, 8.0))
	b.polygon(rim, PLANK_DEEP.lightened(0.1))
	b.stroke(rim, 1.6, PLANK.lightened(0.3), true)

## Draws a module's parts from the back of the land to the front: each is
## [how far toward the eye its middle is, what draws it].
static func _back_to_front(parts: Array) -> void:
	parts.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for part: Array in parts:
		(part[1] as Callable).call()

## The kiln, 1 by 2 tiles: the origin is the middle of its back tile on the
## ground, where the stone goes in, and its front tile lies toward
## DIRS[facing], where the lime comes out. A squat beehive of brick on the
## back tile with a hopper behind it, a low brick tunnel out over the front
## tile to a tray, its arch showing when it looks at the eye. The port its
## fire is seen through is in the beehive's near side, clear of both
## (KILN_GLOW[facing] is its middle: draw `glow()` there). One mesh a facing:
## what is seen corner on cannot be turned by a transform.
static func kiln(facing: int) -> ArrayMesh:
	facing = posmod(facing, 4)
	if not _kilns.has(facing):
		var b := Face.Builder.new()
		var d := Vector2(DIRS[facing])
		var near := d.x + d.y
		var bricks := [BRICK_LIT.lightened(0.08), BRICK_LIT, BRICK_SHADE]
		_ground_shade(b, [[Vector2.ZERO, Vector2(0.4, 0.4), 50.0], [d * 0.8, _half(d, 0.42, 0.24), 28.0], [d * -0.38, Vector2(0.12, 0.12), 30.0]])
		_back_to_front([
			[-near * 0.4, func() -> void: _hopper(b, d * -0.38, 38.0)],
			[0.0, func() -> void: _beehive(b, facing)],
			[near * 0.74, func() -> void:
				var c := d * 0.74
				var half := _half(d, 0.4, 0.22)
				_wall(b, c, half, 0.0, 27.0, bricks, 3, MORTAR)
				if near > 0.0:
					var a0 := c + (Vector2(half.x, half.y) if d.x > 0.0 else Vector2(-half.x, half.y))
					var a1 := c + (Vector2(half.x, -half.y) if d.x > 0.0 else Vector2(half.x, half.y))
					b.polygon(_arch(a0, a1, 0.14, 0.86, 0.0, 10.0, 23.0), IRON_SHADE)
					b.polygon(_arch(a0, a1, 0.22, 0.78, 0.0, 9.0, 19.0), HOLLOW)],
			[near * 1.3, func() -> void: _tray(b, d * 1.3, d)],
		])
		_kilns[facing] = b.mesh()
	return _kilns[facing]

## The kiln's beehive about its origin: a round wall and a dome over it,
## courses of brick round it, the eye at its top and the port in its side.
static func _beehive(b: Face.Builder, facing: int) -> void:
	var rx := KILN_R * K * sqrt(2.0)
	var wall := 22.0
	var top := 58.0
	var body := _round(Vector2.ZERO, KILN_R, 0.0, 0.0, PI)
	for i in 21:
		var a := PI - PI * i / 20.0
		body.append(Vector2(cos(a) * rx, -wall - sin(a) * (top - wall)))
	b.polygon(body, BRICK)
	_crescent(b, body, Vector2(-rx * 0.46, -2.0), BRICK_SHADE)
	_crescent(b, body, Vector2(rx * 0.5, 5.0), BRICK_LIT)
	for z: float in [7.0, 14.0, 21.0, 29.0, 37.0, 45.0, 52.0]:
		var k := 1.0 if z <= wall else sqrt(maxf(0.0, 1.0 - pow((z - wall) / (top - wall), 2.0)))
		b.stroke(_round(Vector2.ZERO, KILN_R * k, z, 0.12, PI - 0.12, 14), 1.4, MORTAR, false, false)
	b.ellipse(Vector2(0.0, -top + 3.0), 9.0, 4.6, IRON_SHADE)
	b.ellipse(Vector2(0.0, -top + 3.6), 6.0, 2.8, HOLLOW)
	# the port: in the near side the tunnel and the hopper leave clear
	var q := Vector2(0.0, 1.0) if DIRS[facing].x != 0 else Vector2(1.0, 0.0)
	var s := Vector2(q.y, q.x)
	var g := q * KILN_R * 0.97
	b.polygon(_arch(g - s * 0.15, g + s * 0.15, 0.0, 1.0, 3.0, KILN_PORT + 4.0, KILN_PORT + 14.0), IRON_SHADE)
	b.polygon(_arch(g - s * 0.15, g + s * 0.15, 0.14, 0.86, 5.0, KILN_PORT + 3.0, KILN_PORT + 10.5), HOLLOW)
	b.ellipse(_p(g, 7.5), 6.0, 2.6, Color(Pal.KNOT_DEEP, 0.7))

## The retort, 1 by 2 tiles, placed as the kiln is: the origin is the middle
## of its back tile, where the logs go in, its front tile toward
## DIRS[facing], where the charcoal comes out. An iron drum lying along its
## two tiles on a bed of brick, hooped, a hopper at its back end and a tray
## at its front, the end that looks at the eye shut with a round door. A
## small stack stands on it (RETORT_SMOKE[facing] is over its top: draw
## `smoke()` there).
static func retort(facing: int) -> ArrayMesh:
	facing = posmod(facing, 4)
	if not _retorts.has(facing):
		var b := Face.Builder.new()
		var d := Vector2(DIRS[facing])
		var near := d.x + d.y
		_ground_shade(b, [[d * 0.5, _half(d, 0.72, 0.3), 54.0], [d * -0.37, Vector2(0.12, 0.12), 30.0]])
		_back_to_front([
			[-near * 0.4, func() -> void: _hopper(b, d * -0.37, 46.0)],
			[0.0, func() -> void:
				_wall(b, d * 0.51, _half(d, 0.71, 0.3), 0.0, 14.0, [BRICK_LIT.lightened(0.08), BRICK_LIT, BRICK_SHADE], 2, MORTAR)
				_barrel(b, d * -0.14, d * 1.16, d)
				_drum(b, d * RETORT_STACK, 0.065, 52.0, RETORT_TOP - 4.0, [HOLLOW, IRON_LIT, IRON, IRON_SHADE])
				b.stroke(_round(d * RETORT_STACK, 0.085, RETORT_TOP - 8.0, 0.0, PI, 10), 3.0, IRON_SHADE, false, false)],
			[near * 1.36, func() -> void: _tray(b, d * 1.36, d)],
		])
		_retorts[facing] = b.mesh()
	return _retorts[facing]

## The retort's drum: iron, lying from `a0` to `a1` (tiles) along `d`, its
## middle 35 up; lit along its top and dark under, three hoops round it, the
## end toward the eye closed with a door.
static func _barrel(b: Face.Builder, a0: Vector2, a1: Vector2, d: Vector2) -> void:
	var zc := 35.0
	var rz := 21.0
	var side := at(Vector2(absf(d.y), absf(d.x))) * 0.25
	var up := Vector2(0.0, -rz)
	var cap := func(c: Vector2, k := 1.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(_p(c, zc) + (side * cos(a) + up * sin(a)) * k)
		return pts
	var both: PackedVector2Array = cap.call(a0)
	both.append_array(cap.call(a1))
	var hull := Geometry2D.convex_hull(both)
	hull.remove_at(hull.size() - 1)
	b.polygon(hull, IRON)
	var o0 := _p(a0.lerp(a1, 0.05), zc)
	var o1 := _p(a0.lerp(a1, 0.95), zc)
	var hi := side * cos(1.9) + up * sin(1.9)
	var lo := side * cos(-0.5) + up * sin(-0.5)
	b.stroke(PackedVector2Array([o0 + hi * 0.8, o1 + hi * 0.8]), rz * 0.5, IRON_LIT)
	b.stroke(PackedVector2Array([o0 + lo * 0.82, o1 + lo * 0.82]), rz * 0.46, IRON_SHADE)
	for f: float in [0.14, 0.5, 0.86]:
		var hoop := PackedVector2Array()
		for i in 13:
			var a := lerpf(-PI * 0.5, PI * 0.62, i / 12.0)
			hoop.append(_p(a0.lerp(a1, f), zc) + (side * cos(a) + up * sin(a)) * 1.02)
		b.stroke(hoop, 3.4, IRON_SHADE.darkened(0.12), false, false)
		b.stroke(hoop.slice(8, 13), 1.4, IRON_LIT.lightened(0.1), false, false)
	var front := a1 if d.x + d.y > 0.0 else a0
	# an end looking down and left is in the sun, one looking down and right not
	var sunny := (d.y if d.x + d.y > 0.0 else -d.y) != 0.0
	b.fan(cap.call(front), IRON_LIT if sunny else IRON_SHADE.lightened(0.08))
	b.stroke(cap.call(front), 2.2, IRON_SHADE.darkened(0.1), true)
	b.fan(cap.call(front, 0.6), IRON if sunny else IRON_SHADE)
	b.stroke(cap.call(front, 0.6), 1.8, IRON_SHADE.darkened(0.16), true)
	b.disc(_p(front, zc) + side * 0.26, 3.0, PLANK.lightened(0.1))

# --- the steam things (2026-10-12) ---

## Any module's mesh by its kind, at the facing it is seen at (a module of
## one tile has no facing).
static func module(kind: String, facing := 0) -> ArrayMesh:
	match kind:
		"firebox":
			return firebox()
		"engine":
			return engine()
		"kiln":
			return kiln(facing)
		"saw":
			return saw(facing)
		"joiner":
			return joiner(facing)
	return retort(facing)

## The engine, 1 by 1, the origin the middle of its tile on the ground: a
## vertical boiler of riveted iron on a brick foot, a short stack on it, and
## on the side that looks down and left the bearing its flywheel turns on
## (ENGINE_WHEEL is the hub: draw `wheel()` there under `on_wall`). It has
## no facing: it takes heat from a fire box on any side and turns whatever
## touches it.
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
		b.ellipse(_p(Vector2(-0.05, -0.05), 76.0), 0.2 * K * sqrt(2.0), 0.2 * K * sqrt(2.0) * DEEP * 0.9, IRON_LIT.lightened(0.1))
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
## 1: +y, down and left).
static func on_wall(hub: Vector2, r: float, angle: float, axis: int) -> Transform2D:
	var along := Vector2(K, K * DEEP) if axis % 2 == 0 else Vector2(-K, K * DEEP)
	return Transform2D(along * r / WHEEL, Vector2(0.0, -RISE * r / WHEEL), hub) * Transform2D(angle, Vector2.ZERO)

## The saw, 1 by 2 tiles, placed as the kiln is: the origin the middle of
## its back tile, where the logs go in, its front tile toward DIRS[facing],
## where the planks come out. A long bench of timber with a log on its
## carriage, a hopper at its back and a tray at its front, and over the
## middle of it an iron arm that carries the blade (SAW_UP over the bench at
## `saw_hub(facing)`: draw `wheel(true)` there under `on_wall`, in the plane
## that runs along the bench).
static func saw(facing: int) -> ArrayMesh:
	facing = posmod(facing, 4)
	var key := "saw%d" % facing
	if not _one.has(key):
		var b := Face.Builder.new()
		var d := Vector2(DIRS[facing])
		var near := d.x + d.y
		var across := Vector2(absf(d.y), absf(d.x))
		var wood := [PLANK.lightened(0.14), PLANK.lightened(0.04), PLANK_DEEP]
		_ground_shade(b, [[d * 0.5, _half(d, 0.72, 0.3), 40.0], [d * -0.37, Vector2(0.12, 0.12), 30.0]])
		_back_to_front([
			[-near * 0.4, func() -> void: _hopper(b, d * -0.37, 40.0)],
			[-0.05, func() -> void:
				# the arm the blade hangs from stands behind the bench's middle
				var foot := d * 0.5 - across * 0.24
				_block(b, foot, Vector2(0.05, 0.05), 0.0, 58.0, [IRON_LIT, IRON, IRON_SHADE])],
			[0.0, func() -> void:
				# four stout legs, the bed on them, a rail along each side
				for o: Vector2 in [Vector2(-0.12, -0.2), Vector2(1.08, -0.2), Vector2(-0.12, 0.2), Vector2(1.08, 0.2)]:
					_block(b, d * o.x + across * o.y, Vector2(0.05, 0.05), 0.0, 14.0, [PLANK_DEEP, PLANK_DEEP.lightened(0.06), PLANK_DEEP.darkened(0.2)])
				_block(b, d * 0.48, _half(d, 0.68, 0.27), 12.0, 20.0, wood)
				for k in range(1, 6):
					var u := -0.2 + 1.36 * k / 6.0
					b.stroke(PackedVector2Array([_p(d * u - across * 0.25, 20.0), _p(d * u + across * 0.25, 20.0)]), 1.5, Color(PLANK_DEEP, 0.55), false, false)
				# a log on the carriage, waiting for the blade
				var c := _p(d * 0.14, 20.0)
				var back := (at(d) / K).normalized() * 30.0
				if near > 0.0:
					c += back
					back = -back
				b.stroke(PackedVector2Array([c, c + back]), 15.0, BARK)
				b.stroke(PackedVector2Array([c + Vector2(-1.0, -3.0), c + back + Vector2(-1.0, -3.0)]), 5.0, BARK.lightened(0.16))
				b.ellipse(c + Vector2(0.0, -0.5), 6.4, 7.6, PITH)
				b.stroke(Face.Builder.ring(c + Vector2(0.0, -0.5), 3.4, 4.2), 1.2, Color(BARK, 0.6), true)],
			[0.06, func() -> void:
				# the arm reaches over the bench to the blade's hub
				var foot := d * 0.5 - across * 0.24
				b.stroke(PackedVector2Array([_p(foot, 56.0), _p(d * 0.5, SAW_UP + 20.0)]), 5.0, IRON)
				b.stroke(PackedVector2Array([_p(foot, 57.0), _p(d * 0.5, SAW_UP + 21.0)]), 1.6, IRON_LIT)],
			[near * 1.36, func() -> void: _tray(b, d * 1.36, d)],
		])
		_one[key] = b.mesh()
	return _one[key]

## How high over the ground the saw's blade turns, its size in tiles, and
## where its hub is from the saw's origin at a facing.
const SAW_UP := 20.0
const SAW_R := 0.26
static func saw_hub(facing: int) -> Vector2:
	return _p(Vector2(DIRS[posmod(facing, 4)]) * 0.5, SAW_UP + 20.0)

## The joiner, 1 by 2 tiles, placed as the kiln is: planks in at its back,
## a chair out at its front. A workbench of pale timber under a small
## shingled roof on four posts, a vice on its corner, a board of tools at
## its back and a chair half made on it. JOINER_DUST[facing] is over the
## bench: sawdust is drawn there while it works.
static func joiner(facing: int) -> ArrayMesh:
	facing = posmod(facing, 4)
	var key := "joiner%d" % facing
	if not _one.has(key):
		var b := Face.Builder.new()
		var d := Vector2(DIRS[facing])
		var near := d.x + d.y
		var across := Vector2(absf(d.y), absf(d.x))
		var wood := [PITH, PLANK.lightened(0.16), PLANK]
		var posts := [PLANK_DEEP.lightened(0.1), PLANK_DEEP.lightened(0.08), PLANK_DEEP.darkened(0.18)]
		_ground_shade(b, [[d * 0.5, _half(d, 0.74, 0.34), 66.0], [d * -0.37, Vector2(0.12, 0.12), 30.0]])
		var corners: Array[Vector2] = [Vector2(-0.14, -0.3), Vector2(1.1, -0.3), Vector2(-0.14, 0.3), Vector2(1.1, 0.3)]
		_back_to_front([
			[-near * 0.4, func() -> void: _hopper(b, d * -0.37, 40.0)],
			[-0.3, func() -> void:
				# the two posts behind, and the board of tools between them
				for o: Vector2 in corners:
					var c := d * o.x + across * o.y
					if c.x + c.y < (d * 0.48).x + (d * 0.48).y:
						_block(b, c, Vector2(0.04, 0.04), 0.0, 62.0, posts)],
			[0.0, func() -> void:
				for o: Vector2 in [Vector2(0.0, -0.18), Vector2(0.96, -0.18), Vector2(0.0, 0.18), Vector2(0.96, 0.18)]:
					_block(b, d * o.x + across * o.y, Vector2(0.045, 0.045), 0.0, 18.0, posts)
				_block(b, d * 0.48, _half(d, 0.58, 0.24), 16.0, 24.0, wood)
				# a vice on the near corner
				_block(b, d * (0.9 if near > 0.0 else 0.06) + across * 0.2, Vector2(0.07, 0.05), 24.0, 31.0, [STEEL_LIT, STEEL, STEEL_DEEP])
				# a chair half made: its seat and two legs up
				var s := _p(d * 0.42, 24.0)
				b.polygon(PackedVector2Array([s + Vector2(-13.0, -9.0), s + Vector2(0.0, -15.0), s + Vector2(13.0, -9.0), s + Vector2(0.0, -3.0)]), PLANK.lightened(0.1))
				for x: float in [-11.0, 11.0]:
					b.stroke(PackedVector2Array([s + Vector2(x, -9.0), s + Vector2(x, 0.0)]), 3.0, PLANK_DEEP, false, false)
				b.stroke(PackedVector2Array([s + Vector2(0.0, -4.0), s + Vector2(0.0, 5.0)]), 3.0, PLANK_DEEP.darkened(0.1), false, false)
				b.stroke(PackedVector2Array([s + Vector2(-11.0, -10.0), s + Vector2(-11.0, -30.0), s + Vector2(0.0, -36.0), s + Vector2(0.0, -16.0)]), 3.0, PLANK_DEEP, false, false)
				# a mallet lying on the bench
				var mlt := _p(d * 0.84, 25.0)
				b.stroke(PackedVector2Array([mlt + Vector2(-9.0, 2.0), mlt + Vector2(7.0, -5.0)]), 2.6, PLANK_DEEP)
				b.stroke(PackedVector2Array([mlt + Vector2(5.0, -9.0), mlt + Vector2(10.0, -1.0)]), 7.0, BARK)],
			[0.3, func() -> void:
				for o: Vector2 in corners:
					var c := d * o.x + across * o.y
					if c.x + c.y >= (d * 0.48).x + (d * 0.48).y:
						_block(b, c, Vector2(0.04, 0.04), 0.0, 62.0, posts)
				# the roof: one slope of shingles, lit, and its dark edge
				var r0 := d * -0.22
				var r1 := d * 1.18
				var hi := 84.0
				var lo := 60.0
				var top := PackedVector2Array([_p(r0 - across * 0.38, hi), _p(r1 - across * 0.38, hi), _p(r1 + across * 0.38, lo), _p(r0 + across * 0.38, lo)])
				b.polygon(top, BRICK_LIT.lerp(PLANK, 0.35))
				for k in range(1, 4):
					var t := k / 4.0
					b.stroke(PackedVector2Array([_p(r0 + across * lerpf(-0.38, 0.38, t), lerpf(hi, lo, t)), _p(r1 + across * lerpf(-0.38, 0.38, t), lerpf(hi, lo, t))]),
						1.8, Color(BRICK_SHADE, 0.7), false, false)
				b.stroke(PackedVector2Array([top[3], top[2]]), 3.4, BRICK_SHADE, false, false)
				b.stroke(PackedVector2Array([top[0], top[1]]), 2.6, BRICK_LIT.lightened(0.2), false, false)],
			[near * 1.36, func() -> void: _tray(b, d * 1.36, d)],
		])
		_one[key] = b.mesh()
	return _one[key]

## Where the joiner's sawdust rises, from its origin, by facing.
static func joiner_dust(facing: int) -> Vector2:
	return _p(Vector2(DIRS[posmod(facing, 4)]) * 0.48, 34.0)

## A stoker fitted to a fire box, about the fire box's origin: a small iron
## chute with a brass wheel on the side that looks down and right.
static func stoker() -> ArrayMesh:
	if not _one.has("stoker"):
		var b := Face.Builder.new()
		var h := FIREBOX_HALF
		_block(b, Vector2(h + 0.06, 0.02), Vector2(0.07, 0.14), 6.0, 34.0, [IRON_LIT, IRON, IRON_SHADE])
		_block(b, Vector2(h + 0.07, 0.02), Vector2(0.1, 0.18), 34.0, 40.0, [HOLLOW, IRON_LIT, IRON_SHADE])
		var hub := _p(Vector2(h + 0.14, 0.02), 20.0)
		b.disc(hub, 7.0, GOLD_DEEP)
		b.disc(hub, 4.6, GOLD)
		b.disc(hub, 1.8, GOLD_DEEP)
		_one["stoker"] = b.mesh()
	return _one["stoker"]

## A bundle of sawn planks resting on `c`: three boards tied with a cord,
## their sawn ends to the eye, running back to the upper left as a log does.
static func _planks(b: Face.Builder, c: Vector2) -> void:
	var back := LOG_BACK * 30.0
	var top := Color("e9c58f")
	var end := Color("f6dfb4")
	var side := Color("b98a55")
	var w := 12.0
	var thick := 4.4
	for i in 3:
		var o := c + Vector2(-back.x * 0.5 + (2.0 if i == 1 else 0.0), -1.0 - i * thick)
		b.polygon(PackedVector2Array([o + Vector2(w, -thick), o + Vector2(w, 0.0), o + Vector2(w, 0.0) + back, o + Vector2(w, -thick) + back]), side)
		b.polygon(PackedVector2Array([o + Vector2(-w, -thick), o + Vector2(w, -thick), o + Vector2(w, -thick) + back, o + Vector2(-w, -thick) + back]), top if i == 2 else top.darkened(0.08))
		b.polygon(PackedVector2Array([o + Vector2(-w, -thick), o + Vector2(w, -thick), o + Vector2(w, 0.0), o + Vector2(-w, 0.0)]), end)
		b.stroke(PackedVector2Array([o + Vector2(-w, 0.0), o + Vector2(w, 0.0)]), 1.3, Color(side.darkened(0.2), 0.9), false, false)
	# the cord round the bundle, over its top and down its end
	var o2 := c + Vector2(-back.x * 0.5, -1.0 - 3.0 * thick)
	var m := back * 0.45
	b.stroke(PackedVector2Array([o2 + Vector2(-w, 0.0) + m, o2 + Vector2(w, 0.0) + m, o2 + Vector2(w, 3.0 * thick) + m]), 2.2, Color("7a5836"), false, false)

## A small wooden chair standing on `c`, seen corner on.
static func _chair(b: Face.Builder, c: Vector2) -> void:
	var seat := 17.0
	var tone := PLANK.lightened(0.08)
	var dark := PLANK_DEEP
	var L := c + Vector2(-13.0, -2.0)
	var F := c + Vector2(0.0, 4.0)
	var R := c + Vector2(13.0, -2.0)
	var B := c + Vector2(0.0, -8.0)
	# the back legs run up into the back of the chair
	b.stroke(PackedVector2Array([B, B + Vector2(0.0, -seat - 24.0)]), 3.4, dark, false, false)
	b.stroke(PackedVector2Array([R, R + Vector2(0.0, -seat - 24.0)]), 3.4, dark, false, false)
	for y: float in [-seat - 21.0, -seat - 12.0]:
		b.stroke(PackedVector2Array([B + Vector2(0.0, y), R + Vector2(0.0, y)]), 4.2, tone, false, false)
	b.stroke(PackedVector2Array([L, L + Vector2(0.0, -seat)]), 3.4, tone, false, false)
	b.stroke(PackedVector2Array([F, F + Vector2(0.0, -seat)]), 3.6, tone, false, false)
	b.polygon(PackedVector2Array([L + Vector2(0.0, -seat), F + Vector2(0.0, -seat), R + Vector2(0.0, -seat), B + Vector2(0.0, -seat)]), PITH)
	b.polygon(PackedVector2Array([L + Vector2(0.0, -seat), F + Vector2(0.0, -seat), F + Vector2(0.0, -seat + 3.4), L + Vector2(0.0, -seat + 3.4)]), tone)
	b.polygon(PackedVector2Array([F + Vector2(0.0, -seat), R + Vector2(0.0, -seat), R + Vector2(0.0, -seat + 3.4), F + Vector2(0.0, -seat + 3.4)]), dark)

## The fire box, 1 by 1, the origin the middle of its tile on the ground: a
## block of pale stone strapped with iron under an iron lid with a short
## flue, its open mouth in the side that looks down and left
## (FIREBOX_MOUTH is the mouth's middle: draw `fire()` there).
static func firebox() -> ArrayMesh:
	if not _one.has("firebox"):
		var b := Face.Builder.new()
		var h := FIREBOX_HALF
		_ground_shade(b, [[Vector2.ZERO, Vector2(h, h), 46.0]])
		_wall(b, Vector2.ZERO, Vector2(h, h), 0.0, 38.0, [STONE.lightened(0.1), STONE.lightened(0.04), STONE_SHADE], 3, Color(0.36, 0.26, 0.2, 0.34), 22.0)
		var a0 := Vector2(-h, h)
		var a1 := Vector2(h, h)
		b.stroke(PackedVector2Array([_p(a0, 31.0), _p(a1, 31.0), _p(Vector2(h, -h), 31.0)]), 4.0, IRON, false, false)
		b.polygon(_arch(a0, a1, 0.2, 0.8, 0.0, 15.0, 28.0), IRON_SHADE)
		b.polygon(_arch(a0, a1, 0.27, 0.73, 0.0, 14.0, 24.0), HOLLOW)
		for u: float in [0.36, 0.5, 0.64]:
			b.stroke(PackedVector2Array([_p(a0.lerp(a1, u), 1.0), _p(a0.lerp(a1, u), 7.0)]), 2.0, IRON_SHADE, false, false)
		b.ellipse(_p(a0.lerp(a1, 0.5), 4.0) + Vector2(1.0, 0.0), 9.0, 3.0, Color(Pal.KNOT_DEEP, 0.7))
		_block(b, Vector2.ZERO, Vector2(h + 0.03, h + 0.03), 38.0, 44.0, [IRON_LIT, IRON, IRON_SHADE])
		_drum(b, Vector2(-0.12, -0.12), 0.09, 44.0, 62.0, [HOLLOW, IRON_LIT, IRON, IRON_SHADE])
		_one["firebox"] = b.mesh()
	return _one["firebox"]

## A patch of round light about `c`, `r` across its half: bright in its
## middle and gone at its edge, with no shape to it.
static func _halo(b: Face.Builder, c: Vector2, r: float, colour: Color, alpha: float) -> void:
	_glow(b, c, r, r, colour, alpha)

## The fire in a mouth, about (0, 0): warm round light, brighter in its
## middle, and a low bed of embers, each a soft round of its own. No flame
## has an edge and nothing flies off it; the caller scales it and tints it
## by how hard the fire draws.
static func fire() -> ArrayMesh:
	if not _one.has("fire"):
		var b := Face.Builder.new()
		_halo(b, Vector2(0.0, -2.0), 40.0, Color(1.0, 0.66, 0.3), 0.5)
		_halo(b, Vector2(0.0, -1.0), 21.0, Color(1.0, 0.8, 0.42), 0.85)
		_halo(b, Vector2(0.0, 0.0), 10.0, Color(1.0, 0.95, 0.76), 0.95)
		for e: Array in [[-8.0, 6.0, 5.5], [1.0, 7.5, 6.5], [9.0, 6.0, 5.0]]:
			_glow(b, Vector2(e[0], e[1]), float(e[2]) * 1.5, float(e[2]), EMBER, 0.9)
		_one["fire"] = b.mesh()
	return _one["fire"]

## A soft round of pale warm light about (0, 0), 30 across its half: the
## kiln's port when it burns. Tint and scale it by the draw.
static func glow() -> ArrayMesh:
	if not _one.has("glow"):
		var b := Face.Builder.new()
		_halo(b, Vector2.ZERO, 30.0, Color(1.0, 0.9, 0.7), 0.6)
		_halo(b, Vector2.ZERO, 13.0, Color(1.0, 0.97, 0.88), 0.95)
		_one["glow"] = b.mesh()
	return _one["glow"]

## A soft round puff about (0, 0), 26 across its half, white: the retort's
## smoke. The caller tints it, grows it and lets it go as it rises.
static func smoke() -> ArrayMesh:
	if not _one.has("smoke"):
		var b := Face.Builder.new()
		for puff: Array in [[0.0, 0.0, 24.0, 0.5], [-9.0, 4.0, 15.0, 0.42], [10.0, 3.0, 16.0, 0.42], [2.0, -9.0, 14.0, 0.4]]:
			_halo(b, Vector2(puff[0], puff[1]), puff[2], Color.WHITE, puff[3])
		_one["smoke"] = b.mesh()
	return _one["smoke"]

## The market, one tile, the origin its middle on the ground (the user,
## 2026-10-11: "the market tile should be a single square, the item stay
## above it and them it opens a hatch and the item falls"; it was a stall of
## 2 by 2). A low box of planks with a square hole in its top, dark inside,
## and a coin painted on its sunny wall to say what it is (a coin on a post
## stood behind it for an hour: the sale's coin hopped up right over it).
## The hole's two leaves are not in it (`market_door`, `market_leaf`): they
## swing.
static func market() -> ArrayMesh:
	if not _one.has("market"):
		var b := Face.Builder.new()
		var wood := _market_wood()
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
		_market_near(b)
		_one["market"] = b.mesh()
	return _one["market"]

## The market's near side by itself: its two seen walls and the top's two
## near planks. Drawn over a thing falling through the hatch, which is then
## behind them as it should be.
static func market_front() -> ArrayMesh:
	if not _one.has("market_front"):
		var b := Face.Builder.new()
		var big := Vector2(MARKET_HALF, MARKET_HALF)
		var wood := _market_wood()
		# `_block` with no top: the hole would be covered
		b.polygon(PackedVector2Array([_p(Vector2(-big.x, big.y)), _p(big), _p(big, MARKET_TALL), _p(Vector2(-big.x, big.y), MARKET_TALL)]), wood[1])
		b.polygon(PackedVector2Array([_p(big), _p(Vector2(big.x, -big.y)), _p(Vector2(big.x, -big.y), MARKET_TALL), _p(big, MARKET_TALL)]), wood[2])
		_market_near(b)
		_one["market_front"] = b.mesh()
	return _one["market_front"]

static func _market_wood() -> Array:
	return [PLANK.lightened(0.22), PLANK.lightened(0.06), PLANK_DEEP]

## What both of the market's meshes end with: the top's two near planks,
## the joints of the two walls, the coin painted on the sunny one and the
## pale line round the hole and the rim.
static func _market_near(b: Face.Builder) -> void:
	var o := MARKET_HALF
	var i := HATCH_HALF
	var top: Color = _market_wood()[0]
	b.polygon(PackedVector2Array([_p(Vector2(o, -o), MARKET_TALL), _p(Vector2(o, o), MARKET_TALL), _p(Vector2(i, i), MARKET_TALL), _p(Vector2(i, -i), MARKET_TALL)]), top)
	b.polygon(PackedVector2Array([_p(Vector2(-o, o), MARKET_TALL), _p(Vector2(-i, i), MARKET_TALL), _p(Vector2(i, i), MARKET_TALL), _p(Vector2(o, o), MARKET_TALL)]), top)
	for f: float in [0.25, 0.5, 0.75]:
		var u := lerpf(-o, o, f)
		b.stroke(PackedVector2Array([_p(Vector2(u, o), 2.0), _p(Vector2(u, o), MARKET_TALL - 3.0)]), 1.6, Color(PLANK_DEEP, 0.6), false, false)
		b.stroke(PackedVector2Array([_p(Vector2(o, u), 2.0), _p(Vector2(o, u), MARKET_TALL - 3.0)]), 1.6, Color(PLANK_DEEP.darkened(0.2), 0.6), false, false)
	# the coin on the wall in the sun, lying in the wall's own plane
	var along := at(Vector2(1.0, 0.0)).normalized()
	b.append(icon("coin"), Transform2D(along * 0.17, Vector2(0.0, 0.17), _p(Vector2(0.0, o), MARKET_TALL * 0.5)))
	b.stroke(PackedVector2Array([_p(Vector2(-o, o), MARKET_TALL), _p(Vector2(o, o), MARKET_TALL), _p(Vector2(o, -o), MARKET_TALL)]), 2.4, PLANK.lightened(0.34), false, false)
	b.stroke(PackedVector2Array([_p(Vector2(-i, i), MARKET_TALL), _p(Vector2(i, i), MARKET_TALL), _p(Vector2(i, -i), MARKET_TALL)]), 1.8, PLANK_DEEP.darkened(0.25), false, false)

## One leaf of the market's hatch, in a space of its own at FINE units a
## tile: x from its hinge (0) to its free edge, y along the hinge about its
## middle. `market_leaf` lays it; nothing is rebuilt as it swings.
static func market_door() -> ArrayMesh:
	if not _one.has("market_door"):
		var b := Face.Builder.new()
		var w := HATCH_HALF * FINE
		b.polygon(PackedVector2Array([Vector2(0.0, -w), Vector2(w, -w), Vector2(w, w), Vector2(0.0, w)]), PLANK.lightened(0.1))
		for k in 3:
			var y := lerpf(-w, w, (k + 0.5) / 3.0)
			b.polygon(PackedVector2Array([Vector2(1.0, y - w / 3.0 + 1.2), Vector2(w - 1.0, y - w / 3.0 + 1.2), Vector2(w - 1.0, y + w / 3.0 - 1.2), Vector2(1.0, y + w / 3.0 - 1.2)]),
				PLANK.lightened(0.16) if k % 2 == 0 else PLANK.lightened(0.04))
		# its two iron straps from the hinge
		for y: float in [-w * 0.55, w * 0.55]:
			b.stroke(PackedVector2Array([Vector2(1.5, y), Vector2(w * 0.7, y)]), 3.2, IRON, false, true)
		_one["market_door"] = b.mesh()
	return _one["market_door"]

## Where leaf `side` (0 hinged on the hole's -x edge, 1 on its +x) lies
## when the hatch is `open` (0 shut, 1 hanging down), about the market's
## own origin: draw `market_door()` under it.
static func market_leaf(side: int, open: float) -> Transform2D:
	var s := -1.0 if side == 0 else 1.0
	var a := clampf(open, 0.0, 1.0) * HATCH_SWING
	var across := ISO.x * -s * cos(a) + Vector2(0.0, RISE * sin(a))
	return Transform2D(across / FINE, ISO.y / FINE, at(Vector2(s * HATCH_HALF, 0.0)) + MARKET_TOP)

## The round button that lies on the pond where a plate may be bought, about
## (0, 0), a tile and a half across: a pale disc flat on the water with a
## plus on it and a soft ring of light round it.
static func plus() -> ArrayMesh:
	if not _one.has("plus"):
		var b := Face.Builder.new()
		_glow(b, Vector2.ZERO, 122.0, 122.0 * DEEP, Color.WHITE, 0.42)
		b.stroke(Face.Builder.ring(Vector2.ZERO, 94.0, 94.0 * DEEP), 2.6, Color(1.0, 1.0, 1.0, 0.5), true)
		b.ellipse(Vector2(0.0, 5.0), 78.0, 78.0 * DEEP, Color(0.07, 0.27, 0.33, 0.26))
		b.ellipse(Vector2.ZERO, 78.0, 78.0 * DEEP, Pal.PAPER)
		b.stroke(Face.Builder.ring(Vector2.ZERO, 66.0, 66.0 * DEEP), 2.4, Pal.SURFACE_HI, true)
		b.polygon(Face.Builder.round_rect(Vector2(-32.0, -5.0), Vector2(64.0, 10.0), 5.0), Pal.ACCENT)
		b.polygon(Face.Builder.round_rect(Vector2(-7.5, -21.0), Vector2(15.0, 42.0), 5.0), Pal.ACCENT)
		_one["plus"] = b.mesh()
	return _one["plus"]

## A timber scaffold over a footprint of `w` by `h` tiles, the origin the
## footprint's lowest tile corner (draw it at at(Vector2(tile))): a post at
## each corner, beams round the top, a rail and a brace across each side the
## eye sees. What stands while a module is being built.
static func frame(w: int, h: int) -> ArrayMesh:
	var key := Vector2i(w, h)
	if not _frames.has(key):
		var b := Face.Builder.new()
		var tall := 60.0
		var m := 0.1
		var c00 := Vector2(m, m)
		var c10 := Vector2(w - m, m)
		var c11 := Vector2(w - m, h - m)
		var c01 := Vector2(m, h - m)
		_ground_shade(b, [[Vector2(w, h) * 0.5, Vector2(w, h) * 0.5 - Vector2(m, m), tall * 0.4]])
		var beam := func(p0: Vector2, p1: Vector2, thick := 5.0) -> void:
			b.stroke(PackedVector2Array([p0, p1]), thick + 2.6, PLANK_DEEP)
			b.stroke(PackedVector2Array([p0 + Vector2(-0.7, -0.9), p1 + Vector2(-0.7, -0.9)]), thick - 1.0, PLANK.lightened(0.1))
		beam.call(_p(c00), _p(c00, tall), 6.0)
		beam.call(_p(c00, tall), _p(c10, tall))
		beam.call(_p(c00, tall), _p(c01, tall))
		beam.call(_p(c10), _p(c10, tall), 6.0)
		beam.call(_p(c01), _p(c01, tall), 6.0)
		beam.call(_p(c01, tall * 0.5), _p(c11, tall * 0.5), 4.0)
		beam.call(_p(c11, tall * 0.5), _p(c10, tall * 0.5), 4.0)
		beam.call(_p(c01, 4.0), _p(c01.lerp(c11, 0.5), tall * 0.5), 4.0)
		beam.call(_p(c10, 4.0), _p(c10.lerp(c11, 0.5), tall * 0.5), 4.0)
		beam.call(_p(c01, tall), _p(c11, tall))
		beam.call(_p(c11, tall), _p(c10, tall))
		beam.call(_p(c11), _p(c11, tall), 6.0)
		_frames[key] = b.mesh()
	return _frames[key]

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
## the modules (`firebox`, `kiln`, `retort`, `market`), the kinds of plate
## (`forest`, `neutral`), what is carried (`log`, `stone`, `lime`,
## `charcoal`) and `coin` (the gold pill's coin, ui/menu/gold_pill.gd, as a
## mesh). The modules and the carried are their own meshes, fitted.
static func icon(kind: String) -> ArrayMesh:
	if _icons.has(kind):
		return _icons[kind]
	var b := Face.Builder.new()
	match kind:
		"belt":
			var s := 0.56 / FINE
			var xf := Transform2D(ISO.x * s, ISO.y * s, BELT_LIFT * 0.56)
			# two tiles of it, on their legs, the bed over them
			for i in 2:
				b.append(belt_under(), Transform2D(0.0, Vector2(0.56, 0.56), 0.0, at(Vector2(i - 0.5, 0.0)) * 0.56))
			for i in 2:
				_belt_into(b, xf * Transform2D(0.0, Vector2(FINE * (i - 1.0), -FINE * 0.5)), true)
			var mid := Vector2.ZERO
			for v in b.verts:
				mid += v
			mid /= b.verts.size()
			for i in b.verts.size():
				b.verts[i] -= mid
		"fast":
			# a belt's picture with the fast one's dark bed and two warm chevrons
			var s := 0.56 / FINE
			var xf := Transform2D(ISO.x * s, ISO.y * s, BELT_LIFT * 0.56)
			for i in 2:
				b.append(belt_under(), Transform2D(0.0, Vector2(0.56, 0.56), 0.0, at(Vector2(i - 0.5, 0.0)) * 0.56))
			for i in 2:
				var t := xf * Transform2D(0.0, Vector2(FINE * (i - 1.0), -FINE * 0.5))
				_belt_into(b, t, false)
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
		"splitter":
			var whole := Face.Builder.new()
			whole.append(belt_under(), Transform2D.IDENTITY)
			whole.append(splitter(0), Transform2D.IDENTITY)
			_fit_into(b, whole.mesh(), 92.0)
		"firebox":
			_fit_into(b, firebox(), 90.0)
			b.append(fire(), Transform2D(0.0, Vector2(0.5, 0.5), 0.0, _fitted(firebox(), 90.0) * FIREBOX_MOUTH))
		"kiln":
			_fit_into(b, kiln(0), 94.0)
			b.append(glow(), Transform2D(0.0, Vector2(0.3, 0.3), 0.0, _fitted(kiln(0), 94.0) * KILN_GLOW[0]))
		"retort":
			_fit_into(b, retort(0), 94.0)
		"engine":
			var whole := Face.Builder.new()
			whole.append(engine(), Transform2D.IDENTITY)
			whole.append(wheel(), on_wall(_p(ENGINE_WHEEL, ENGINE_WHEEL_UP), ENGINE_WHEEL_R, 0.4, 0))
			_fit_into(b, whole.mesh(), 94.0)
		"saw":
			var whole := Face.Builder.new()
			whole.append(saw(0), Transform2D.IDENTITY)
			whole.append(wheel(true), on_wall(saw_hub(0), SAW_R, 0.0, 0))
			_fit_into(b, whole.mesh(), 94.0)
		"joiner":
			_fit_into(b, joiner(0), 94.0)
		"stoker":
			var whole := Face.Builder.new()
			whole.append(firebox(), Transform2D.IDENTITY)
			whole.append(stoker(), Transform2D.IDENTITY)
			_fit_into(b, whole.mesh(), 90.0)
		"market":
			var whole := Face.Builder.new()
			whole.append(market(), Transform2D.IDENTITY)
			for side in 2:
				whole.append(market_door(), market_leaf(side, 0.0))
			_fit_into(b, whole.mesh(), 96.0)
		"forest":
			_plot_into(b, "forest")
			b.append(tree(3), Transform2D(0.0, Vector2(0.36, 0.36), 0.0, Vector2(-17.0, 8.0)))
			b.append(tree(2), Transform2D(0.0, Vector2(0.4, 0.4), 0.0, Vector2(12.0, 16.0)))
		"mine":
			_plot_into(b, "mine")
			b.append(rock(1), Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2(-14.0, 14.0)))
			b.append(rock(2), Transform2D(0.0, Vector2(0.44, 0.44), 0.0, Vector2(16.0, 22.0)))
		"neutral":
			_plot_into(b, "neutral")
		"coin":
			var r := 42.0
			b.disc(Vector2(0.0, r * 0.12), r, GOLD_DEEP)
			b.disc(Vector2.ZERO, r, GOLD)
			b.stroke(Face.Builder.ring(Vector2.ZERO, r * 0.72, r * 0.72), r * 0.1, GOLD_DEEP, true)
			b.stroke(PackedVector2Array([Vector2(0.0, -r * 0.34), Vector2(0.0, r * 0.34)]), r * 0.16, GOLD_DEEP)
			b.stroke(Face.Builder.arc_points(Vector2.ZERO, r * 0.86, PI * 1.1, PI * 1.45), r * 0.12, GOLD_HI)
		_:
			_fit_into(b, item(kind), 84.0)
	_icons[kind] = b.mesh()
	return _icons[kind]

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

## A small diamond of a kind's ground on its earth, for a plate's picture.
static func _plot_into(b: Face.Builder, kind: String) -> void:
	var tone: Dictionary = GROUND[kind]
	var half := 46.0
	var deep := half * DEEP
	var y := 16.0
	var down := Vector2(0.0, 13.0)
	var left := Vector2(-half, y)
	var front := Vector2(0.0, y + deep)
	var right := Vector2(half, y)
	b.polygon(PackedVector2Array([left, front, front + down, left + down * 0.6]), EARTH[0])
	b.polygon(PackedVector2Array([front, right, right + down * 0.6, front + down]), EARTH_SHADE[0])
	var top := PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(0.0, y - deep), right, front, left]
	for i in 4:
		var c := corners[i]
		var from := c + (corners[(i + 3) % 4] - c).normalized() * 9.0
		var to := c + (corners[(i + 1) % 4] - c).normalized() * 9.0
		top.append_array(Face.Builder.bezier2(from, c, to, 6))
		top.append(to)
	b.polygon(top, tone["grass"])
	_glow(b, Vector2(-12.0, y - 6.0), 30.0, 18.0, tone["warm"], 0.6)
	if kind == "neutral":
		var rule := Color(tone["deep"] as Color, 0.7)
		b.stroke(PackedVector2Array([Vector2(half * 0.5, y - deep * 0.5), Vector2(-half * 0.5, y + deep * 0.5)]), 1.8, rule, false, false)
		b.stroke(PackedVector2Array([Vector2(-half * 0.5, y - deep * 0.5), Vector2(half * 0.5, y + deep * 0.5)]), 1.8, rule, false, false)

## Whether the language writes 0,47 for 0.47 (pt, es), and a line of figures
## as it does.
static func comma() -> bool:
	return not TranslationServer.get_locale().begins_with("en")

static func decimal(text: String) -> String:
	return text.replace(".", ",") if comma() else text

## What a chop takes, which may be a half: 1, 1.5, 2, 31.5, and past a
## thousand as `short` writes it. `comma` for a language that writes 1,5.
static func amount(v: float, comma := false) -> String:
	if v >= 1000.0 or is_equal_approx(v, roundf(v)):
		return short(roundi(v))
	var text := "%.1f" % v
	return text.replace(".", ",") if comma else text

## A count in a few characters: 999, 1.23K, 45.6K, 789K, 1.2M, and on
## through B, T and Q. Trees and tiles have no last level, so every number
## on the screen goes through here.
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
