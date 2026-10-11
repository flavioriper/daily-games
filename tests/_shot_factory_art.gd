extends SceneTree

## Factory's art library (factory/art.gd) laid out and shot, with no sim and
## no screen: a throwaway look at every mesh in one place.
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_factory_art.gd -- <outdir> > <log> 2>&1
##
## On the pond, four plates as the game joins them (neutral ground at (0, 0)
## with the market, a closed forest behind it at (0, -1), neutral ground at
## (1, 0) and at (0, 1)) with the `sides` each needs; on the forest fourteen
## trees on every other tile inside its rim, of every look (the fifth, the
## blossom, is in the library and no land grows it now) and their shadows,
## and the pile a forest's stock is drawn as at two of its gates, three logs
## and twelve; on the market's plate a ring of belts in all four facings
## with every item on it, a run of belts over the seam and the market on its
## tile with a log on its hatch; on the plate beside it a fire
## box burning and the kiln in its four facings with its glow (the kiln is
## kept in the library and locked in the game: nothing gives it stone); on
## the plate in front the retort in its four with its smoke, a frame of each
## size and both ghosts; a plus where each of four plates might be bought
## and lily pads on open water; and every icon on a strip of paper. Saves
## art_whole.png (the land fitted to the window), four crops at the Grove's
## scale and six at twice that (the belts twice, an eighth of a second
## apart: the slats must have run) into <outdir> (default /tmp), and prints
## the draw calls of each.

const VIEWS := [
	["whole", Vector2(6.0, 2.0), 0.4],
	["forest", Vector2(4.2, -3.4), 1.04],
	["neutral", Vector2(4.2, 4.6), 1.04],
	["kilns", Vector2(12.0, 4.0), 1.04],
	["retorts", Vector2(3.6, 12.0), 1.04],
	["gate_2x", Vector2(3.6, -0.8), 2.08],
	["market_2x", Vector2(6.4, 6.4), 2.08],
	["kilns_2x", Vector2(11.6, 3.2), 2.08],
	["retorts_2x", Vector2(3.6, 11.4), 2.08],
	["belts_2x", Vector2(3.8, 4.2), 2.08],
	["belts_2x_later", Vector2(3.8, 4.2), 2.08],
]
const PLATES := [[Vector2i(0, 0), "neutral"], [Vector2i(0, -1), "forest"], [Vector2i(1, 0), "neutral"], [Vector2i(0, 1), "neutral"]]
## [x, y, look], on the forest: every other tile inside its rim, as the sim
## stands them.
const TREES := [[1, -7, 4], [3, -7, 2], [5, -7, 3], [2, -6, 1], [6, -6, 0], [1, -5, 0], [3, -5, 4], [5, -5, 2], [4, -4, 3], [6, -4, 1],
	[1, -3, 2], [3, -3, 3], [2, -2, 1], [6, -2, 4]]
## The forest's gates toward the market's plate and toward +x, and what each
## is shown holding.
const GATES := [[3, -1, 3], [7, -4, 12]]
const BELTS := [[2, 3, 0], [3, 3, 0], [4, 3, 0], [5, 3, 1], [5, 4, 1], [5, 5, 2], [4, 5, 2], [3, 5, 2], [2, 5, 3], [2, 4, 3],
	[10, 7, 2], [9, 7, 2], [8, 7, 2]]
const KINDS := ["log", "stone", "lime", "charcoal"]
const ICONS := ["belt", "firebox", "kiln", "retort", "market", "forest", "neutral", "log", "stone", "lime", "charcoal", "coin"]
## The canvas this lays out on: the project stretches 1080 by 1920 into the
## window, so a --resolution of 810x1440 shows it at three quarters. A view's
## scale is in canvas units (1.04 is the Grove's: a plate as wide as the
## field), and the root reports other sizes for its first frames here.
const SIZE := Vector2(1080.0, 1920.0)
const CENTRE := Vector2(540.0, 790.0)

var Art: GDScript
var _out := "/tmp"
var _world: Node2D
var _layers: Array[CanvasItem] = []
var _belt_mm: MultiMesh
var _things: Array = []
var _frame := 0
var _view := -1
var _water: ArrayMesh
var _light: ArrayMesh
var _t := 0.0
var _calls := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	Art = load("res://factory/art.gd")

## Built on a later frame than _initialize: the window has its size by then.
func _build() -> void:
	var size := SIZE
	_water = Art.water(size, 0.0)
	_light = Art.light(size)
	_layer(root, func(c: CanvasItem) -> void: c.draw_mesh(_water, null))
	_world = Node2D.new()
	root.add_child(_world)
	var owned := {}
	for p: Array in PLATES:
		owned[p[0]] = p[1]
	var order := PLATES.duplicate()
	order.sort_custom(func(x: Array, y: Array) -> bool: return x[0].x + x[0].y < y[0].x + y[0].y)
	_layer(_world, func(c: CanvasItem) -> void:
		for p: Array in order:
			var sides := 0
			for i in 4:
				if owned.has(p[0] + Art.DIRS[i]):
					sides |= 1 << i
			c.draw_mesh(Art.plate(p[1], sides), null, Transform2D(0.0, Art.at(Vector2(p[0] * Art.PLATE))))
		c.draw_mesh(Art.pads(3, true), null, Transform2D(0.0, Art.at(Vector2(15.0, 10.5)))))
	var grass := _layer(_world, func(c: CanvasItem) -> void:
		for p: Array in order:
			c.draw_set_transform(Art.at(Vector2(p[0] * Art.PLATE)))
			for mm: MultiMesh in Art.grass(p[1]):
				c.draw_multimesh(mm, null))
	grass.material = Art.wind(true)
	_layer(_world, func(c: CanvasItem) -> void:
		for spot: Vector2 in [Vector2(20.0, 4.0), Vector2(-4.0, 4.0), Vector2(12.0, 12.0), Vector2(12.0, -4.0)]:
			c.draw_mesh(Art.plus(), null, Transform2D(0.0, Art.at(spot)))
		c.draw_mesh(Art.ghost(1, 2, true), null, Art.flat(Vector2(7.0, 9.0)))
		c.draw_mesh(Art.ghost(2, 2, false), null, Art.flat(Vector2(0.0, 10.0))))
	_belt_mm = MultiMesh.new()
	_belt_mm.transform_format = MultiMesh.TRANSFORM_2D
	_belt_mm.mesh = Art.belt()
	_belt_mm.instance_count = BELTS.size()
	for i in BELTS.size():
		_belt_mm.set_instance_transform_2d(i, Art.flat(Vector2(BELTS[i][0], BELTS[i][1]), BELTS[i][2]))
	var belts := _layer(_world, func(c: CanvasItem) -> void: c.draw_multimesh(_belt_mm, null))
	belts.material = Art.belt_material()
	var shade := _layer(_world, func(c: CanvasItem) -> void:
		for t: Array in TREES:
			c.draw_mesh(Art.shade(t[2]), null, Art.cast(_mid(t[0], t[1]), Vector2.ONE * Art.TREE_SCALE)))
	shade.material = Art.shade_wind()
	_lay_things()
	_layer(_world, func(c: CanvasItem) -> void:
		for th: Array in _things:
			c.draw_mesh(th[1], null, th[2], th[3]))
	var trees := _layer(_world, func(c: CanvasItem) -> void:
		var sorted := TREES.duplicate()
		sorted.sort_custom(func(x: Array, y: Array) -> bool: return x[0] + x[1] < y[0] + y[1])
		for t: Array in sorted:
			c.draw_mesh(Art.tree(t[2]), null, Transform2D(0.0, Vector2.ONE * Art.TREE_SCALE, 0.0, _mid(t[0], t[1]))))
	trees.material = Art.wind()
	_layer(root, func(c: CanvasItem) -> void:
		c.draw_mesh(_light, null)
		c.draw_rect(Rect2(0.0, size.y - 300.0, size.x, 300.0), Color("f6efe3"))
		for i in ICONS.size():
			var at := Vector2(96.0 + 148.0 * (i % 7) + (148.0 if i >= 7 else 0.0), size.y - 222.0 + 140.0 * (i / 7))
			c.draw_rect(Rect2(at - Vector2(62.0, 62.0), Vector2(124.0, 124.0)), Color("fffdf8"))
			c.draw_mesh(Art.icon(ICONS[i]), null, Transform2D(0.0, at)))

func _mid(tx: float, ty: float) -> Vector2:
	return Art.at(Vector2(tx + 0.5, ty + 0.5))

## A layer of the land (a Node2D under the world, which pans and zooms) or of
## the screen (a Control): whatever `draw` draws into it.
func _layer(parent: Node, draw: Callable) -> CanvasItem:
	var c: CanvasItem = Node2D.new() if parent == _world else Control.new()
	c.draw.connect(draw.bind(c))
	if parent == _world:
		# a layer is culled by a box that ignores its draws' transforms: at twice
		# the Grove's scale every mesh's own box was off the screen and the
		# layer was not drawn at all
		RenderingServer.canvas_item_set_custom_rect(c.get_canvas_item(), true, Rect2(-4000.0, -4000.0, 8000.0, 8000.0))
	parent.add_child(c)
	_layers.append(c)
	return c

## What stands, each [depth, mesh, transform, tint], sorted back to front.
func _lay_things() -> void:
	var put := func(tile: Vector2, mesh: ArrayMesh, off := Vector2.ZERO, scale := 1.0, tint := Color.WHITE, nudge := 0.0) -> void:
		_things.append([Art.depth(tile) + nudge, mesh, Transform2D(0.0, Vector2(scale, scale), 0.0, Art.at(tile) + off), tint])
	for i in BELTS.size():
		var tile := Vector2(BELTS[i][0] + 0.5, BELTS[i][1] + 0.5)
		var d := Vector2(Art.DIRS[BELTS[i][2]])
		for k in 2:
			put.call(tile + d * (k * 0.5 - 0.25), Art.item(KINDS[(i + k) % 4]))
	put.call(Vector2(6.5, 6.5), Art.market())
	for side in 2:
		_things.append([Art.depth(Vector2(6.5, 6.5)) + 0.001 * (side + 1), Art.market_door(),
			Transform2D(0.0, Art.at(Vector2(6.5, 6.5))) * Art.market_leaf(side, 0.0), Color.WHITE])
	put.call(Vector2(6.5, 6.5), Art.item(KINDS[0]), Art.MARKET_TOP, 1.0, Color.WHITE, 0.01)
	for g: Array in GATES:
		put.call(Vector2(g[0] + 0.5, g[1] + 0.5), Art.pile(g[2]))
	put.call(Vector2(11.5, 6.5), Art.firebox())
	put.call(Vector2(11.5, 6.5), Art.fire(), Art.FIREBOX_MOUTH, 1.0, Color.WHITE, 0.01)
	var kilns := [[9, 1], [13, 1], [10, 4], [13, 5]]
	var retorts := [[1, 9], [5, 9], [2, 12], [5, 13]]
	for f in 4:
		var kt := Vector2(kilns[f][0] + 0.5, kilns[f][1] + 0.5)
		put.call(kt, Art.kiln(f), Vector2.ZERO, 1.0, Color.WHITE, 0.5 * maxf(0.0, Art.depth(Vector2(Art.DIRS[f]))))
		if f % 2 == 0 or f == 1:
			put.call(kt, Art.glow(), Art.KILN_GLOW[f], 0.8, Color(1.0, 0.72, 0.4), 1.2)
		var rt := Vector2(retorts[f][0] + 0.5, retorts[f][1] + 0.5)
		put.call(rt, Art.retort(f), Vector2.ZERO, 1.0, Color.WHITE, 0.5 * maxf(0.0, Art.depth(Vector2(Art.DIRS[f]))))
		put.call(rt, Art.smoke(), Art.RETORT_SMOKE[f] + Vector2(4.0, -12.0), 0.8, Color(0.93, 0.93, 0.9, 0.9), 1.2)
		put.call(rt, Art.smoke(), Art.RETORT_SMOKE[f] + Vector2(14.0, -40.0), 1.2, Color(0.93, 0.93, 0.9, 0.5), 1.3)
	put.call(Vector2(6.0, 13.0), Art.frame(2, 2), Vector2.ZERO, 1.0, Color.WHITE, 2.0)
	put.call(Vector2(3.0, 14.0), Art.frame(1, 2), Vector2.ZERO, 1.0, Color.WHITE, 1.5)
	_things.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])

func _process(delta: float) -> bool:
	_frame += 1
	_t += delta
	if _frame < 6:
		return false
	if _world == null:
		_build()
	Art.blow()
	Art.belt_run(_t)
	if _frame < 30:
		return false
	var beat := (_frame - 30) % 8
	@warning_ignore("integer_division")
	var which := (_frame - 30) / 8
	if beat == 0:
		if which >= VIEWS.size():
			return true
		_view = which
		var view: Array = VIEWS[which]
		_world.scale = Vector2.ONE * float(view[2])
		_world.position = CENTRE - Art.at(view[1]) * float(view[2])
		for c in _layers:
			c.queue_redraw()
	elif beat == 4:
		var path := "%s/art_%s.png" % [_out, VIEWS[_view][0]]
		root.get_texture().get_image().save_png(path)
		print("%s  draw calls %d (the frame before %d)" % [path, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), _calls])
	_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return false
