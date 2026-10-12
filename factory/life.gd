extends RefCounted

## What is seen of Factory's land, for whoever shows it (the screen, the
## tab's card, the tutorial's pages): the plates on the pond, the belts and
## what rides them, a forest's trees and the shadow each throws, the beaver
## that bites one for every log taken, the market and the machines. It began
## as the Grove's valley/grove_life.gd (the beaver, the bite and the chips
## are that file's, tuned on 2026-10-06; the fall, the stump and the burst
## of leaves went on 2026-10-11, when a forest became a closed plate whose
## trees are never felled) and it took the rest of the board in so that
## three holders draw one land by one path.
## The rules stay the sim's (factory/sim.gd), the drawings the art's
## (factory/art.gd, ui/faces/beaver.gd).
##
## A holder calls `mount(parent, sim)` once and is handed `world`, a Node2D
## drawn in the art's view units: the holder pans and zooms the land by that
## node's position and scale and nothing else (every layer under it has a
## box of its own, or the engine culls it by its meshes' untransformed
## boxes). Then, every frame after it stepped the sim: `event(e)` for each of
## the sim's events and `step(delta)`. A holder that did not see the events
## (the tab, while the screen had the land) calls `stale()` and everything
## is read from the tables again; nothing here needs an event to be right,
## only to be lively.
##
## - **A beaver** pops up left of an even tree and right of an odd one on
##   the sim's `chop` (a log into that forest's stock, by the hand or by the
##   forest itself), its teeth in and a chip or two flying, the tree
##   squashed; it stays `STAY` for the next and goes.
## - **A forest's stock is a pile at each gate that has land beyond it.**
## - **What stands is sorted by `Art.depth`** across trees and buildings. Only
##   trees wear the wind, so the sorted list is cut into runs of one kind and
##   each run drawn on its own layer, windy and plain by turns.
## - **Belts are a MultiMesh a shape**: the beds (straight, and a quarter
##   bend from either side for a belt fed by its side alone: `shape`), lifted
##   `Art.BELT_UP` under the one belt material, and under them the legs and
##   edges (`Art.belt_under`, `belt_under_bend`), all filled back to front.
##   They stay flat layers under everything that stands. An item on a bend
##   is drawn round its arc (`item_at`); the sim knows no bends. What lies or rides is one
##   MultiMesh a kind, an item on a belt lifted onto its bed.
##
## - **The view turns by quarters** (`turn`, 2026-10-10: "add a button to
##   rotate the view, so user can click to rotate and see something being
##   blocked"). The sim's tiles never change; only where a tile is seen
##   does. Tile space is turned about its origin before `Art.at`, so whole
##   tiles go to whole tiles and plates to plates. **Everything that places
##   or reads a position goes through one pair, `seen(t)` and `tile_at(v)`**
##   (and `seen_tile`, `seen_plate`, `seen_facing`, `depth` built on the same
##   turn): never `Art.at` on a sim coordinate. The market's art has one
##   face and keeps it toward the eye at every turn, the leaves of its
##   hatch with it; the ground's washes, pebbles and tufts are a
##   plate's own and do not turn with the land.
##
## Under reduce motion a beaver is there or not and only changes its face,
## no chip flies, a plate and a module are there at once and smoke stands
## still.

const Art = preload("res://factory/art.gd")
const Sim = preload("res://factory/sim.gd")
const Beaver = preload("res://ui/faces/beaver.gd")
const Motion = preload("res://core/motion.gd")

## Seconds a hit tree's squash lasts.
const SQUASH := 0.16
## A beaver's seconds in and out, how long it stays by its tree after a
## bite, and a bite's length.
const SHOW_IN := 0.16
const SHOW_OUT := 0.14
const STAY := 0.7
const BITE := 0.26
## Chips in the air at most, and how fast they come down.
const BITS := 48
const FALLS := 900.0
## Seconds a tree takes to come up, and a plate out of the pond; how far
## under it starts (view units) and the part of the rise its trees wait.
const GROW := 0.6
const RISE := 3.0
const SUNK := 90.0
const RISE_BARE := 0.7
## The market's hatch. A sale is played over SALE of the market's interval,
## SALE_MOST seconds at most, and of that: the leaves swing down over
## OPEN, the thing falls from FALL_FROM to FALL_TO (FALL view units, into
## the dark), the coin comes up at COIN_AT and the leaves are shut again
## from SHUT_FROM to SHUT_TO. What comes next rides in from the belt's edge
## over SLIDE of the interval, once the leaves are shut. A coin hops
## COIN_UP and is gone in COIN seconds; DROPS sales are played at once.
const SALE := 0.7
const SALE_MOST := 0.62
const OPEN := 0.3
const FALL_FROM := 0.2
const FALL_TO := 0.7
const FALL := 38.0
const COIN_AT := 0.55
const SHUT_FROM := 0.7
const SHUT_TO := 0.95
const SLIDE := 0.3
const SLIDE_MOST := 0.9
const COIN := 0.75
const COIN_UP := 64.0
const DROPS := 4
## Every layer's box: a board of a dozen plates either way and the pond
## round it. The engine culls a layer by this and not by what it draws.
const BOX := Rect2(-40000.0, -40000.0, 80000.0, 80000.0)
const MID := Vector2(0.5, 0.5)
const ITEMS := ["log", "stone", "lime", "charcoal", "plank", "chair"]
## Turns a second: an engine's flywheel at full shaft, and a saw's blade at
## full share.
const WHEEL_TURNS := 0.5
const BLADE_TURNS := 1.6

## The land, in view units: the holder's to place and scale.
var world: Node2D
var sim: RefCounted
## Quarters the view is turned clockwise, 0 to 3: set by `set_turn`. A view
## preference of the holder's, never the sim's and never kept.
var turn := 0
## Whether the plus of every free edge is drawn (not on the tab's card).
var plus := true
## The holder's own flat things, over the belts and under what stands:
## [mesh, transform] each, and a tint if there is a third (a ghost under
## the finger, the run of belts a swipe would lay).
var ghosts: Array = []

var _ground_l: Node2D
var _grass_l: Node2D
var _under_l: Node2D
var _belt_l: Node2D
var _fast_l: Node2D
var _flat_l: Node2D
var _shade_l: Node2D
var _item_l: Node2D
var _stand: Node2D
var _air_l: Node2D
var _pool: Array[Node2D] = []
var _runs: Array = []
var _order: Array = []      # [plate as seen, kind, sides as seen, variant, plate], back to front
var _edges: Array = []
var _plates_n := -1
## The beds by shape (straight, a bend fed from the side toward its facing
## plus a quarter, one fed from the other side) and what is under them by
## shape as drawn ("s", or a bend's corner), a MultiMesh each; a belt's
## shape, by tile, read off its feeders whenever belts change.
var _bed_mms: Array[MultiMesh] = []
var _fast_mms: Array[MultiMesh] = []
var _under_mms := {}
var _shapes := {}
var _belts_stale := true
var _belt_n := -1
var _item_mm := {}          # kind -> MultiMesh
var _item_n := {}           # kind -> how many are seen
var _shade_mat: ShaderMaterial
var _t := 0.0
var _hit := {}        # tree id -> seconds since it was hit
var _born := {}       # tree id -> seconds since it came up (under 0: not yet)
var _wob := {}        # tile -> seconds since it was shaken
var _rise := {}       # plate -> seconds since it was bought
var _beavers := {}    # tree id -> {tile, look, side, show, rising, seen, bite, age, size}
var _bits: Array = []     # {pos, vel, t, life, turn, spin, col, size, weight}: view units
var _bit_mm: MultiMesh
var _spun := {}       # module id -> how far its wheel or blade has turned (radians)
var _lying := {}      # what lies on the hatch: {from (the way it came), t}
var _drops: Array = []    # sales being played: {kind, amount, t, len, off (tiles from the middle), paid}
var _rng := RandomNumberGenerator.new()

## A sale's coin is up: when the holder counts it, says "+N" and is heard.
## At once under reduce motion.
signal coined(amount: int)

func _init() -> void:
	_rng.seed = 20261010
	_shade_mat = Art.shade_wind()

## Builds the land's layers under `parent` and returns `world`.
func mount(parent: Node, with_sim: RefCounted) -> Node2D:
	sim = with_sim
	world = Node2D.new()
	world.name = "World"
	parent.add_child(world)
	_ground_l = layer(_draw_ground)
	_grass_l = layer(_draw_grass, Art.wind(true))
	_under_l = layer(_draw_under)
	_belt_l = layer(_draw_belts, Art.belt_material())
	_fast_l = layer(_draw_fast, Art.belt_material(true))
	_flat_l = layer(_draw_flat)
	_shade_l = layer(_draw_shade, _shade_mat)
	_item_l = layer(_draw_items)
	_stand = Node2D.new()
	_stand.name = "Stand"
	world.add_child(_stand)
	_air_l = layer(_draw_air)
	for mesh: ArrayMesh in [Art.belt(), Art.belt_bend(false), Art.belt_bend(true)]:
		_bed_mms.append(_many(mesh))
		_fast_mms.append(_many(mesh))
	for kind: String in ITEMS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.mesh = Art.item(kind)
		mm.instance_count = 16
		mm.visible_instance_count = 0
		_item_mm[kind] = mm
		_item_n[kind] = 0
	stale()
	return world

## Another land in the same layers (a tutorial page starting over).
func hold(with_sim: RefCounted) -> void:
	sim = with_sim
	_hit.clear()
	_born.clear()
	_wob.clear()
	_rise.clear()
	_beavers.clear()
	_bits.clear()
	_lying.clear()
	_drops.clear()
	stale()

## A layer of the land over the ones there are, drawn by `draws(layer)`: the
## holder's own (the figures over the market, a ring) go on top this way.
func layer(draws: Callable, material: Material = null, into: Node = null) -> Node2D:
	var c := Node2D.new()
	c.material = material
	c.draw.connect(draws.bind(c))
	RenderingServer.canvas_item_set_custom_rect(c.get_canvas_item(), true, BOX)
	(world if into == null else into).add_child(c)
	return c

## Everything is read from the sim's tables again at the next step.
func stale() -> void:
	_plates_n = -1
	_belts_stale = true

# --- the turn: where a tile is seen ---

## A point of tile space turned `q` quarters about the origin: a quarter
## takes (x, y) to (-y, x), so +x (down the screen and right) becomes +y
## (down and left) and the land goes round clockwise under the eye.
static func _spin(t: Vector2, q: int) -> Vector2:
	match posmod(q, 4):
		1:
			return Vector2(-t.y, t.x)
		2:
			return -t
		3:
			return Vector2(t.y, -t.x)
	return t

## A point of the sim's tile space (a tile's middle is tile + (0.5, 0.5)),
## in view units, as the view is turned now. THE way from the sim to the eye.
func seen(t: Vector2) -> Vector2:
	return Art.at(_spin(t, turn))

## The point of the sim's tile space under a point of the view: the way back.
func tile_at(v: Vector2) -> Vector2:
	return _spin(Art.tile_at(v), -turn)

## The tile of the art's grid a sim tile is drawn on (its lowest corner).
func seen_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(_spin(Vector2(tile) + MID, turn).floor())

## The same for a plate of the lattice.
func seen_plate(p: Vector2i) -> Vector2i:
	return Vector2i((_spin((Vector2(p) + MID) * Art.PLATE, turn) / Art.PLATE).floor())

## The facing a sim facing is drawn at.
func seen_facing(facing: int) -> int:
	return posmod(facing + turn, 4)

## What a point of the sim's tile space is sorted by, back to front.
func depth(t: Vector2) -> float:
	return Art.depth(_spin(t, turn))

## Turns the view to `quarters`; everything is laid out again.
func set_turn(quarters: int) -> void:
	turn = posmod(quarters, 4)
	stale()

## The land's box in view units: every plate's diamond and the earth under
## it, with nothing added for what stands.
func bounds() -> Rect2:
	var box := Rect2()
	var first := true
	for p: Vector2i in sim.plates:
		var back := Art.at(Vector2(seen_plate(p) * Art.PLATE))
		var r := Rect2(back.x - Art.HALF, back.y, Art.HALF * 2.0, Art.HALF * 2.0 * Art.DEEP)
		box = r if first else box.merge(r)
		first = false
	return box

## The board's box in tile space: from its first plate's first tile to past
## its last one's last.
func tile_bounds() -> Rect2:
	var box := Rect2()
	var first := true
	for p: Vector2i in sim.plates:
		var r := Rect2(Vector2(p * Art.PLATE), Vector2(Art.PLATE, Art.PLATE))
		box = r if first else box.merge(r)
		first = false
	return box

## The middle of a tile, in view units.
func mid(tile: Vector2i) -> Vector2:
	return seen(Vector2(tile) + MID)

## Where a plate's plus lies, in view units.
func plus_at(p: Vector2i) -> Vector2:
	return seen(Vector2(p * Art.PLATE) + Vector2(Art.PLATE, Art.PLATE) * 0.5)

## The lowest tile corner of a module's footprint and its size in tiles, in
## whatever grid `root` and `facing` are given in: the sim's, or the art's
## (`seen_tile`, `seen_facing`) for a thing drawn.
static func footprint(kind: String, root: Vector2i, facing: int) -> Array:
	if Sim.SINGLE.has(kind):
		return [root, Vector2i.ONE]
	var front := root + Art.DIRS[facing]
	return [Vector2i(mini(root.x, front.x), mini(root.y, front.y)), Vector2i.ONE + (front - root).abs()]

# --- the sim's events ---

func event(e: Dictionary) -> void:
	match String(e.type):
		"chop":
			_on_chop(int(e.id))
		"laid", "turned", "sold_back", "placed", "built":
			_belts_stale = true
		"brought":
			_lying = {"from": int(e.from), "t": 0.0}
		"sale":
			_on_sale(e)
		"plate":
			_plates_n = -1
			if not Motion.reduce:
				var p: Vector2i = e.plate
				_rise[p] = 0.0
				for id: int in sim.trees:
					if Sim.plate_of(sim.trees[id].tile) == p:
						_born[id] = -RISE * RISE_BARE

## The hatch opens under what was lying on it. Past DROPS at once, and
## under reduce motion, only the coin is told.
func _on_sale(e: Dictionary) -> void:
	var off := _lying_off()
	_lying.clear()
	if Motion.reduce or _drops.size() >= DROPS:
		coined.emit(int(e.amount))
		return
	_drops.append({"kind": String(e.kind), "amount": int(e.amount), "t": 0.0, "off": off, "paid": false,
		"len": clampf(float(sim.market_interval()) * SALE, 0.1, SALE_MOST)})

## How far from the hatch's middle the thing lying on it still is, in sim
## tiles: it rides in from the edge it came over.
func _lying_off() -> Vector2:
	if _lying.is_empty() or Motion.reduce:
		return Vector2.ZERO
	var time := clampf(float(sim.market_interval()) * SLIDE, 0.05, SLIDE_MOST)
	var k := clampf(float(_lying.t) / time, 0.0, 1.0)
	return -Vector2(Art.DIRS[int(_lying.from)]) * 0.5 * (1.0 - k) * (1.0 - k)

## How far the hatch's leaves hang, 0 to 1: the most any sale wants.
func _hatch() -> float:
	var open := 0.0
	for d: Dictionary in _drops:
		var k := float(d.t) / float(d.len)
		open = maxf(open, smoothstep(0.0, OPEN, k) * (1.0 - smoothstep(SHUT_FROM, SHUT_TO, k)))
	return open

## What stands on `tile` shakes its head: a tap it did not take.
func shake(tile: Vector2i) -> void:
	if not Motion.reduce:
		_wob[tile] = 0.0

## A log off the tree: it is squashed and a beaver's teeth are in, a chip or
## two flying.
func _on_chop(id: int) -> void:
	if not sim.trees.has(id):
		return
	var tr: Dictionary = sim.trees[id]
	_hit[id] = 0.0
	var b := _beaver(tr)
	b.bite = 0.0
	b.seen = 0.0
	if Motion.reduce:
		return
	var side: float = b.side
	var at := mid(tr.tile) + Vector2(side * girth(tr), -22.0 * float(b.size))
	var rock := is_rock(tr)
	for i in 2:
		var tone: Color = (Art.ROCK_LIT if i == 0 else Art.ROCK_SHADE) if rock else (Art.PITH if i == 0 else Art.BARK.lightened(0.25))
		_bit(at, Vector2(side * _rng.randf_range(40.0, 150.0), -_rng.randf_range(120.0, 260.0)), 0.42,
			tone, _rng.randf_range(0.5, 0.8), 1.3 if rock else 1.0)

func _beaver(tr: Dictionary) -> Dictionary:
	var id: int = tr.id
	if not _beavers.has(id):
		_beavers[id] = {"tile": tr.tile, "look": int(tr.look), "side": -1.0 if id % 2 == 0 else 1.0, "show": 0.0,
			"rising": true, "seen": 0.0, "bite": 10.0, "age": 0.0, "girth": girth(tr),
			"size": 0.82 if is_rock(tr) else 0.7 + 0.004 * float(Art.RADIUS[int(tr.look)])}
	return _beavers[id]

## Whether a row of the sim's `trees` is a mine's rock: the plate says.
func is_rock(tr: Dictionary) -> bool:
	return sim.is_mine(tr.tile)

## Half the width of a tree's trunk or a rock's body, where a beaver's teeth go.
func girth(tr: Dictionary) -> float:
	return float(Art.ROCK_R[int(tr.look) % Art.ROCK_R.size()]) * 0.8 if is_rock(tr) else Art.girth(tr.look)

## How tall a tree or a rock stands and how far it reaches, for a tap on it.
func tall(tr: Dictionary) -> float:
	return float(Art.ROCK_TALL[int(tr.look) % Art.ROCK_TALL.size()]) if is_rock(tr) else Art.height(tr.look)

func reach(tr: Dictionary) -> float:
	return float(Art.ROCK_R[int(tr.look) % Art.ROCK_R.size()]) if is_rock(tr) else float(Art.RADIUS[int(tr.look)]) * Art.TREE_SCALE

func _bit(at: Vector2, vel: Vector2, life: float, colour: Color, size: float, weight: float) -> void:
	if _bits.size() >= BITS:
		return
	_bits.append({"pos": at, "vel": vel, "t": 0.0, "life": life, "turn": _rng.randf() * TAU,
		"spin": _rng.randf_range(-9.0, 9.0), "col": colour, "size": size, "weight": weight})

# --- time ---

## `delta` seconds pass, after the sim's own step and its events.
func step(delta: float) -> void:
	_t += delta
	Art.blow()
	# one clock for every holder: the belts' material is shared
	Art.belt_run(Time.get_ticks_msec() / 1000.0)
	for table: Dictionary in [_hit, _born, _wob, _rise]:
		for key: Variant in table.keys():
			table[key] += delta
	for id: int in _hit.keys():
		if _hit[id] > SQUASH:
			_hit.erase(id)
	for id: int in _born.keys():
		if _born[id] > GROW:
			_born.erase(id)
	for tile: Vector2i in _wob.keys():
		if _wob[tile] > Motion.WOBBLE_TIME:
			_wob.erase(tile)
	# wheels and blades turn as fast as they are driven
	if not Motion.reduce:
		for id: int in sim.modules:
			var m: Dictionary = sim.modules[id]
			if m.kind == "engine" and m.built and float(m.share) > 0.0:
				_spun[id] = fposmod(float(_spun.get(id, 0.0)) + delta * TAU * WHEEL_TURNS * (0.12 + float(m.draw) / Sim.ENGINE_SHAFT), TAU)
			elif m.kind == "saw" and sim.working(m) and float(m.share) > 0.0:
				_spun[id] = fposmod(float(_spun.get(id, 0.0)) + delta * TAU * BLADE_TURNS * (0.3 + float(m.share)), TAU)
	var rising := not _rise.is_empty()
	for p: Vector2i in _rise.keys():
		if _rise[p] > RISE:
			_rise.erase(p)
	for id: int in _beavers.keys():
		var b: Dictionary = _beavers[id]
		b.seen += delta
		b.bite += delta
		b.age += delta
		var want: bool = b.seen < STAY
		b.rising = want
		b.show = move_toward(float(b.show), 1.0 if want else 0.0, delta / (SHOW_IN if want else SHOW_OUT))
		if not want and float(b.show) <= 0.0:
			_beavers.erase(id)
	for bit: Dictionary in _bits:
		bit.t += delta
		var vel: Vector2 = bit.vel
		vel.y += FALLS * float(bit.weight) * delta
		vel.x *= 1.0 - minf(1.0, delta * 1.6)
		bit.vel = vel
		bit.pos = (bit.pos as Vector2) + vel * delta
		bit.turn = float(bit.turn) + float(bit.spin) * delta
	_bits = _bits.filter(func(bit: Dictionary) -> bool: return bit.t < bit.life)
	for d: Dictionary in _drops:
		d.t += delta
		if not d.paid and float(d.t) >= float(d.len) * COIN_AT:
			d.paid = true
			coined.emit(int(d.amount))
	_drops = _drops.filter(func(d: Dictionary) -> bool: return d.t < maxf(float(d.len) * SHUT_TO, float(d.len) * COIN_AT + COIN))
	# what comes next waits at the edge until the leaves are shut
	if not _lying.is_empty() and _hatch() <= 0.02:
		_lying.t += delta
	if _plates_n != sim.plates.size():
		_lay_plates()
		rising = true
	if _belts_stale or _belt_n != sim.belts.size() + sim.kinds.size() * 1000:
		_lay_belts()
	_fill_items()
	_fill_stand()
	if rising:
		_ground_l.queue_redraw()
		_grass_l.queue_redraw()
	_flat_l.queue_redraw()
	_shade_l.queue_redraw()
	_item_l.queue_redraw()
	_air_l.queue_redraw()

## How far out of the pond a plate is, 0 to 1.
func _risen(p: Vector2i) -> float:
	if not _rise.has(p):
		return 1.0
	return smoothstep(0.0, 1.0, clampf(float(_rise[p]) / RISE, 0.0, 1.0))

## Whether what stands on `tile` is seen yet: not on a plate still coming up.
func _up(tile: Vector2i) -> bool:
	if _rise.is_empty():
		return true
	var p: Vector2i = Sim.plate_of(tile)
	return not _rise.has(p) or float(_rise[p]) >= RISE * RISE_BARE

func _lay_plates() -> void:
	_plates_n = sim.plates.size()
	_order.clear()
	for p: Vector2i in sim.plates:
		var sides := 0
		for i in 4:
			if sim.plates.has(p + Art.DIRS[i]):
				# the side it is joined on, as the view is turned
				sides |= 1 << seen_facing(i)
		_order.append([seen_plate(p), String(sim.plates[p]), sides, posmod(p.x * 3 + p.y * 5, 4), p])
	_order.sort_custom(func(a: Array, b: Array) -> bool:
		var da: int = a[0].x + a[0].y
		var db: int = b[0].x + b[0].y
		return da < db or (da == db and a[0].x < b[0].x))
	_edges = sim.free_edges()
	_ground_l.queue_redraw()
	_grass_l.queue_redraw()

func _many(mesh: ArrayMesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = mesh
	mm.instance_count = 16
	mm.visible_instance_count = 0
	return mm

## The shape of the belt on `tile`: 0 straight, 1 a quarter bend fed from
## the side its facing plus a quarter looks to, 2 from the other side. A
## belt is a bend only when its one feeder (a belt pointing into it, or the
## way out of a kiln or a retort) comes in by a side; fed from behind, from
## both sides or by nothing it is straight, and a side belt butts into it.
## Read off the sim's tables every time, never kept there.
func shape(tile: Vector2i) -> int:
	if not sim.belts.has(tile):
		return 0
	var f: int = sim.belts[tile]
	var fed := [false, false, false, false]   # by the quarter the feeder lies to, from the facing
	if sim.kinds.get(tile, "") == "splitter":
		return 0
	for q in range(1, 4):
		var d := (f + q) % 4
		fed[q] = sim.feeds(tile + Art.DIRS[d], tile)
	if fed[2] or fed[1] == fed[3]:
		return 0
	return 1 if fed[1] else 2

## Where an item is drawn, in the sim's tile space: where the sim has it
## between two ticks, but round the arc on a bend (the sim's own path there
## is a square corner: in to the middle, then out).
func item_at(tile: Vector2i, it: Dictionary) -> Vector2:
	var pos: Vector2 = sim.item_pos(tile, it)
	var bend: int = _shapes.get(tile, 0)
	if bend == 0:
		return pos
	var f: int = sim.belts[tile]
	var ahead := Vector2(Art.DIRS[f])
	var side := Vector2(Art.DIRS[(f + (1 if bend == 1 else 3)) % 4])
	var rel := pos - (Vector2(tile) + MID)
	var q := rel.dot(side)
	if q > 0.5:
		# still on the belt that feeds it, between two ticks
		return pos
	# how far along its way through the tile, 0 to 1
	var s := clampf(0.5 - q if q > 0.001 else 0.5 + rel.dot(ahead), 0.0, 1.0)
	return Vector2(tile) + MID + (ahead + side) * 0.5 - (ahead * cos(s * PI * 0.5) + side * sin(s * PI * 0.5)) * 0.5

func _lay_belts() -> void:
	_belts_stale = false
	_belt_n = sim.belts.size() + sim.kinds.size() * 1000
	# the back first: a nearer belt's legs and edge are over a further one's
	var tiles: Array = sim.belts.keys()
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return depth(Vector2(a)) < depth(Vector2(b)))
	var lift := Transform2D(0.0, Art.BELT_LIFT)
	var beds := [[], [], []]
	var fast := [[], [], []]
	var unders := {}
	_shapes.clear()
	for tile: Vector2i in tiles:
		var bend := shape(tile)
		var vf := seen_facing(int(sim.belts[tile]))
		var key: Variant = "s"
		if bend != 0:
			_shapes[tile] = bend
			key = Art.DIRS[vf] + Art.DIRS[(vf + (1 if bend == 1 else 3)) % 4]
		((fast if sim.kinds.get(tile, "") == "fast" else beds)[bend] as Array).append(lift * Art.flat(Vector2(seen_tile(tile)), vf))
		if not unders.has(key):
			unders[key] = []
		(unders[key] as Array).append(Transform2D(0.0, mid(tile)))
	for i in 3:
		_fill(_bed_mms[i], beds[i])
		_fill(_fast_mms[i], fast[i])
	_fast_l.queue_redraw()
	for key: Variant in unders:
		if not _under_mms.has(key):
			_under_mms[key] = _many(Art.belt_under() if key is String else Art.belt_under_bend(key))
	for key: Variant in _under_mms:
		_fill(_under_mms[key], unders.get(key, []))
	_under_l.queue_redraw()
	_belt_l.queue_redraw()

func _fill(mm: MultiMesh, xfs: Array) -> void:
	if mm.instance_count < xfs.size():
		mm.instance_count = xfs.size() * 2
	for i in xfs.size():
		mm.set_instance_transform_2d(i, xfs[i])
	mm.visible_instance_count = xfs.size()

## How far up an item at `pos` (sim tile space) is drawn: on a belt's bed,
## or on the ground.
func _lifted(pos: Vector2) -> float:
	return Art.BELT_UP if sim.belts.has(Vector2i(pos.floor())) else 0.0

## What lies and what rides, a MultiMesh a kind, each where the sim has it
## between two ticks.
func _fill_items() -> void:
	var lists := {}
	for kind: String in ITEMS:
		lists[kind] = []
	for tile: Vector2i in sim.items:
		for it: Dictionary in sim.items[tile]:
			if lists.has(it.kind):
				# onto the bed or off it over the tick it crosses, not at a jump
				var up := lerpf(_lifted((it.was as Vector2).lerp(Vector2(tile) + MID, 0.02)), Art.BELT_UP if sim.belts.has(tile) else 0.0, float(sim.alpha))
				(lists[it.kind] as Array).append(seen(item_at(tile, it)) + Vector2(0.0, -up))
	for kind: String in ITEMS:
		var at: Array = lists[kind]
		var mm: MultiMesh = _item_mm[kind]
		if mm.instance_count < at.size():
			mm.instance_count = at.size() * 2
		# the back first, so one riding in front of another is over it
		at.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
		for i in at.size():
			mm.set_instance_transform_2d(i, Transform2D(0.0, at[i]))
		mm.visible_instance_count = at.size()
		_item_n[kind] = at.size()

# --- what stands ---

## How big a standing tree is drawn: grown in, and squashed if just hit.
## Nothing while its plate is still coming up.
func _size(id: int) -> Vector2:
	var size := Art.TREE_SCALE
	if _born.has(id) and not Motion.reduce:
		var age: float = _born[id]
		if age < 0.0:
			return Vector2.ZERO
		size *= 0.15 + 0.85 * Motion.back_out(clampf(age / GROW, 0.0, 1.0))
	var squash := 0.0
	if _hit.has(id) and not Motion.reduce:
		squash = sin(float(_hit[id]) / SQUASH * PI) * 0.16
	return Vector2(size * (1.0 + squash), size * (1.0 - squash))

func _turned(tile: Vector2i) -> float:
	return Motion.wobble_angle(float(_wob[tile])) if _wob.has(tile) else 0.0

## Everything that stands, [depth, windy, mesh, transform, tint] each, sorted
## from the back and cut into runs for the layers.
func _fill_stand() -> void:
	var list: Array = []
	var white := Color.WHITE
	for id: int in sim.trees:
		var tr: Dictionary = sim.trees[id]
		var tile: Vector2i = tr.tile
		if not _up(tile):
			continue
		var size := _size(id)
		if size.x > 0.0:
			var rock := is_rock(tr)
			list.append([depth(Vector2(tile) + MID), 0 if rock else 1, Art.rock(tr.look) if rock else Art.tree(tr.look), Transform2D(_turned(tile), size, 0.0, mid(tile)), white])
	for id: int in _beavers:
		_add_beaver(list, _beavers[id])
	for p: Vector2i in sim.sources:
		var held: int = sim.sources[p].stock
		if held <= 0 or not _up(p * Art.PLATE):
			continue
		# what it holds, lying by every gate that leads on to land
		for side in 4:
			if sim.plates.has(p + Art.DIRS[side]):
				var g: Vector2i = Sim.gate(p, side)
				list.append([depth(Vector2(g) + MID), 0, Art.rubble(held) if sim.is_mine(g) else Art.pile(held), Transform2D(0.0, mid(g)), white])
	_add_market(list)
	for tile: Vector2i in sim.kinds:
		if sim.kinds[tile] == "splitter" and _up(tile):
			list.append([depth(Vector2(tile) + MID), 0, Art.splitter(seen_facing(int(sim.belts[tile]))), Transform2D(_turned(tile), mid(tile)), white])
	for id: int in sim.modules:
		_add_module(list, sim.modules[id])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var used := 0
	var run := -1
	for e: Array in list:
		var windy: int = e[1]
		if run < 0 or run % 2 != windy:
			run = run + 1 if (run + 1) % 2 == windy else run + 2
			while _pool.size() <= run:
				var i := _pool.size()
				_runs.append([])
				_pool.append(layer(_draw_run.bind(i), Art.wind() if i % 2 == 1 else null, _stand))
			for i in range(used, run + 1):
				(_runs[i] as Array).clear()
			used = run + 1
		(_runs[run] as Array).append(e)
	for i in range(used, _pool.size()):
		(_runs[i] as Array).clear()
	for c in _pool:
		c.queue_redraw()

## The market: its box, the two leaves of its hatch, what lies on it, what
## is falling through it behind the box's near side, and the coins. The box
## has one face and keeps it toward the eye at every turn; what lies on it
## rides in from the side it came by as the view has it.
func _add_market(list: Array) -> void:
	var tile := Vector2(Sim.MARKET_AT) + MID
	var d := depth(tile)
	var box := Transform2D(_turned(Sim.MARKET_AT), seen(tile))
	var white := Color.WHITE
	list.append([d, 0, Art.market(), box, white])
	var open := _hatch()
	var shade := 1.0 - 0.34 * open
	for side in 2:
		list.append([d + 0.001 * (side + 1), 0, Art.market_door(), box * Art.market_leaf(side, open), Color(shade, shade, shade)])
	var falling := false
	for drop: Dictionary in _drops:
		var k := float(drop.t) / float(drop.len)
		if k < FALL_TO:
			# to the middle as the leaves give, then down into the dark
			var fall := smoothstep(FALL_FROM, FALL_TO, k)
			fall *= fall
			var off: Vector2 = (drop.off as Vector2) * (1.0 - smoothstep(0.0, OPEN, k))
			var size := 1.0 - 0.2 * fall
			var dark := 1.0 - 0.55 * fall
			list.append([d + 0.003, 0, Art.item(drop.kind),
				Transform2D(0.0, Vector2(size, size), 0.0, seen(tile + off) + Art.MARKET_TOP + Vector2(0.0, FALL * fall)),
				Color(dark, dark, dark, 1.0 - smoothstep(0.6, 1.0, fall))])
			falling = true
	if falling:
		list.append([d + 0.004, 0, Art.market_front(), box, white])
	var wait: Array = sim.market.wait
	if not wait.is_empty():
		list.append([d + 0.005, 0, Art.item(wait[0]), Transform2D(0.0, seen(tile + _lying_off()) + Art.MARKET_TOP), white])
	for drop: Dictionary in _drops:
		var t := float(drop.t) - float(drop.len) * COIN_AT
		if t < 0.0 or t >= COIN:
			continue
		# a hop: up, a little way back down, and gone
		var k := t / COIN
		var u := k * 0.72
		var size := 0.34 * (0.5 + 0.5 * Motion.back_out(clampf(k / 0.25, 0.0, 1.0)))
		list.append([d + 0.006, 0, Art.icon("coin"),
			Transform2D(0.0, Vector2(size * cos(k * TAU), size), 0.0, seen(tile) + Art.MARKET_TOP + Vector2(0.0, -10.0 - COIN_UP * 4.0 * u * (1.0 - u))),
			Color(1.0, 1.0, 1.0, 1.0 - smoothstep(0.55, 1.0, k))])

## A beaver by its tree, looking at it: popped in, its teeth in the wood on
## a chop.
func _add_beaver(list: Array, b: Dictionary) -> void:
	var show: float = b.show
	if show <= 0.0:
		return
	var tile: Vector2i = b.tile
	var side: float = b.side
	var s: float = b.size
	var grow := 1.0
	var snap := 0.0
	if not Motion.reduce:
		grow = Motion.back_out(show) if b.rising else show
		snap = pow(1.0 - clampf(float(b.bite) / BITE, 0.0, 1.0), 2.0)
	var reach: float = float(b.girth) + (Beaver.NECK.x + Beaver.TEETH.x - 2.0) * s
	var at := mid(tile) + Vector2(side * (reach - 3.0 * snap * s), 3.0)
	# it looks at the trunk: right when it sits on the left
	var xf := Transform2D(0.0, Vector2(-side * s * grow * (1.0 + 0.06 * snap), s * grow * (1.0 - 0.06 * snap)), 0.0, at)
	var wag := 0.04 * sin(float(b.age) * 3.0) - 0.12 * snap
	var d := depth(Vector2(tile) + MID) + 0.01
	var nod := 0.22 * snap
	var neck := Beaver.NECK + Vector2(3.0 * snap, 0.0)
	list.append([d, 1, Beaver.tail(), xf * Transform2D(wag, Beaver.TAIL_AT), Color.WHITE])
	list.append([d + 0.001, 1, Beaver.body(), xf, Color.WHITE])
	list.append([d + 0.002, 1, Beaver.head(float(b.bite) < BITE * 0.6), xf * Transform2D(nod, neck), Color.WHITE])

## A machine: its frame while it is built (rising, the machine coming in
## under it), then itself and the part of it that says its draw: the fire
## in the box's mouth, the kiln's port, the retort's smoke.
func _add_module(list: Array, m: Dictionary) -> void:
	var root: Vector2i = m.root
	if not _up(root):
		return
	var kind: String = m.kind
	# the facing it is drawn at: its ways in and out turn with the view
	var f: int = seen_facing(m.facing)
	var at := mid(root)
	var d := depth(Vector2(root) + MID)
	if not Sim.SINGLE.has(kind):
		d += 0.5 * maxf(0.0, Art.depth(Vector2(Art.DIRS[f])))
	var mesh: ArrayMesh = Art.module(kind, f)
	var xf := Transform2D(_turned(root), at)
	if not m.built:
		var k := clampf(float(m.build), 0.0, 1.0)
		var foot := footprint(kind, seen_tile(root), f)
		var corner := Art.at(Vector2(foot[0] as Vector2i))
		var middle := Art.at(Vector2(foot[0] as Vector2i) + Vector2(foot[1] as Vector2i) * 0.5)
		if Motion.reduce:
			list.append([d, 0, Art.frame(foot[1].x, foot[1].y), Transform2D(0.0, corner), Color.WHITE])
			return
		list.append([d, 0, mesh, xf, Color(1.0, 1.0, 1.0, smoothstep(0.35, 1.0, k))])
		# the frame grows up from the footprint's middle on the ground
		var tall := 0.3 + 0.7 * minf(1.0, k * 1.6)
		list.append([d + 0.004, 0, Art.frame(foot[1].x, foot[1].y),
			Transform2D(0.0, Vector2(1.0, tall), 0.0, Vector2(corner.x, middle.y + (corner.y - middle.y) * tall)), Color.WHITE])
		return
	list.append([d, 0, mesh, xf, Color.WHITE])
	var still := Motion.reduce
	match kind:
		"engine":
			list.append([d + 0.005, 0, Art.wheel(), Art.on_wall(at + Art._p(Art.ENGINE_WHEEL, Art.ENGINE_WHEEL_UP), Art.ENGINE_WHEEL_R, float(_spun.get(m.id, 0.4)), 0), Color.WHITE])
			if float(m.share) > 0.0:
				# steam off the stack, more the harder it works
				var hard := clampf(float(m.draw) / Sim.ENGINE_SHAFT, 0.0, 1.0)
				for i in 2:
					var k := 0.25 + 0.5 * i if still else fposmod(_t * 0.4 + 0.5 * i + root.y * 0.31, 1.0)
					var s := 0.5 + 0.7 * k
					list.append([d + 0.006 + 0.001 * i, 0, Art.smoke(),
						Transform2D(0.0, Vector2(s, s), 0.0, at + Art._p(Vector2(-0.1, -0.1), 100.0) + Vector2(4.0 + 10.0 * k, -6.0 - 40.0 * k)),
						Color(1.0, 1.0, 1.0, (0.25 + 0.55 * hard) * sin(k * PI))])
		"saw":
			list.append([d + 0.005, 0, Art.wheel(true), Art.on_wall(at + Art.saw_hub(f), Art.SAW_R, float(_spun.get(m.id, 0.0)), f), Color.WHITE])
		"joiner":
			if sim.working(m) and float(m.share) > 0.0:
				for i in 2:
					var k := 0.3 + 0.4 * i if still else fposmod(_t * 0.9 + 0.5 * i + root.x * 0.37, 1.0)
					var s := 0.22 + 0.3 * k
					list.append([d + 0.005 + 0.001 * i, 0, Art.smoke(),
						Transform2D(0.0, Vector2(s, s), 0.0, at + Art.joiner_dust(f) + Vector2((6.0 if i == 0 else -8.0) * k, -18.0 * k)),
						Color(0.96, 0.87, 0.68, 0.7 * sin(k * PI))])
		"firebox":
			if m.get("stoker", false):
				list.append([d + 0.004, 0, Art.stoker(), xf, Color.WHITE])
			var mouth := at + Art.FIREBOX_MOUTH
			if m.lit:
				var roar := clampf(float(m.draw) / maxf(1.0, float(m.cap)), 0.0, 1.0)
				var s := 0.6 + 0.6 * roar + (0.0 if still else 0.05 * sin(_t * 9.0 + root.x))
				list.append([d + 0.005, 0, Art.fire(), Transform2D(0.0, Vector2(s, s), 0.0, mouth),
					Color(1.0, 1.0, 1.0, 0.55 + 0.45 * sim.fuel_left(m))])
			elif not (m.hopper as Array).is_empty():
				# fuel waits and the fire is out: an ember asks for the tap
				var a := 0.5 if still else 0.38 + 0.22 * sin(_t * 3.0)
				list.append([d + 0.005, 0, Art.glow(), Transform2D(0.0, Vector2(0.55, 0.55), 0.0, mouth), Color(1.0, 0.56, 0.3, a)])
		"kiln":
			if sim.working(m) and float(m.share) > 0.0 and f != 3:
				var a := 0.45 + 0.55 * float(m.share) + (0.0 if still else 0.06 * sin(_t * 5.0 + root.y))
				list.append([d + 0.005, 0, Art.glow(), Transform2D(0.0, Vector2(0.8, 0.8), 0.0, at + Art.KILN_GLOW[f]), Color(1.0, 0.72, 0.4, a)])
		"retort":
			if sim.working(m) and float(m.share) > 0.0:
				for i in 2:
					var k := 0.25 + 0.5 * i if still else fposmod(_t * 0.35 + 0.5 * i + root.x * 0.37, 1.0)
					var s := 0.6 + 0.8 * k
					list.append([d + 0.005 + 0.001 * i, 0, Art.smoke(),
						Transform2D(0.0, Vector2(s, s), 0.0, at + Art.RETORT_SMOKE[f] + Vector2(4.0 + 12.0 * k, -8.0 - 46.0 * k)),
						Color(0.93, 0.93, 0.9, (0.3 + 0.6 * float(m.share)) * sin(k * PI))])

# --- drawing ---

func _draw_ground(ci: CanvasItem) -> void:
	for o: Array in _order:
		var k := _risen(o[4])
		ci.draw_mesh(Art.plate(o[1], o[2], o[3]), null,
			Transform2D(0.0, Art.at(Vector2((o[0] as Vector2i) * Art.PLATE)) + Vector2(0.0, (1.0 - k) * SUNK)),
			Color(1.0, 1.0, 1.0, minf(1.0, k * 3.0)))

## The grass, plate by plate, on the ones that are up.
func _draw_grass(ci: CanvasItem) -> void:
	for o: Array in _order:
		if _risen(o[4]) < 1.0:
			continue
		ci.draw_set_transform(Art.at(Vector2((o[0] as Vector2i) * Art.PLATE)))
		for mm: MultiMesh in Art.grass(o[1], o[3]):
			if mm.instance_count > 0:
				ci.draw_multimesh(mm, null)

func _draw_under(ci: CanvasItem) -> void:
	for key: Variant in _under_mms:
		if (_under_mms[key] as MultiMesh).visible_instance_count > 0:
			ci.draw_multimesh(_under_mms[key], null)

func _draw_belts(ci: CanvasItem) -> void:
	for mm in _bed_mms:
		if mm.visible_instance_count > 0:
			ci.draw_multimesh(mm, null)

func _draw_fast(ci: CanvasItem) -> void:
	for mm in _fast_mms:
		if mm.visible_instance_count > 0:
			ci.draw_multimesh(mm, null)

func _draw_flat(ci: CanvasItem) -> void:
	if plus:
		for p: Vector2i in _edges:
			ci.draw_mesh(Art.plus(), null, Transform2D(0.0, plus_at(p)))
	for g: Array in ghosts:
		ci.draw_mesh(g[0], null, g[1], g[2] if g.size() > 2 else Color.WHITE)

## The shadows, each under its own tree's lean and no other.
func _draw_shade(ci: CanvasItem) -> void:
	for id: int in sim.trees:
		var tr: Dictionary = sim.trees[id]
		if not _up(tr.tile) or is_rock(tr):
			continue
		var size := _size(id)
		if size.x > 0.0:
			ci.draw_mesh(Art.shade(tr.look), null, Art.cast(mid(tr.tile), size))

func _draw_items(ci: CanvasItem) -> void:
	for kind: String in ITEMS:
		if int(_item_n[kind]) > 0:
			ci.draw_multimesh(_item_mm[kind], null)

func _draw_run(ci: CanvasItem, i: int) -> void:
	for e: Array in _runs[i]:
		ci.draw_mesh(e[2], null, e[3], e[4])

## Chips, one MultiMesh.
func _draw_air(ci: CanvasItem) -> void:
	if _bits.is_empty():
		return
	if _bit_mm == null:
		_bit_mm = MultiMesh.new()
		_bit_mm.transform_format = MultiMesh.TRANSFORM_2D
		_bit_mm.use_colors = true
		_bit_mm.mesh = Art.leaf()
		_bit_mm.instance_count = BITS
	var n := 0
	for bit: Dictionary in _bits:
		var t: float = bit.t
		var a := clampf((float(bit.life) - t) / 0.2, 0.0, 1.0)
		var flat := 0.35 + 0.65 * absf(cos(t * 9.0 + float(bit.turn)))
		var s: float = bit.size
		_bit_mm.set_instance_transform_2d(n, Transform2D(float(bit.turn), Vector2(s, s * flat), 0.0, bit.pos))
		_bit_mm.set_instance_color(n, Color(bit.col as Color, a))
		n += 1
	_bit_mm.visible_instance_count = n
	ci.draw_multimesh(_bit_mm, null)
