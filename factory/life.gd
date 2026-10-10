extends RefCounted

## What is seen of Factory's land, for whoever shows it (the screen, the
## tab's card, the tutorial's pages): the plates on the pond, the belts and
## what rides them, the trees and the shadow each throws, the beavers that
## bite them and the way one comes down, the rocks, the market and the
## machines. It began as the Grove's valley/grove_life.gd (the beaver, the
## bite, the four beats of a fall, the stump, the chips and the burst of
## leaves are that file's, tuned on 2026-10-06) with the jetty, the raft,
## the crate, the throws and the grove's own beavers cut, and it took the
## rest of the board in so that three holders draw one land by one path.
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
## only to be lively: a beaver is at every tree the table says is bitten.
##
## - **A tree comes down in four beats** (CREAK back, DROP over, SETTLE one
##   bounce with a burst of its leaves, GONE drawn in toward its crown):
##   0.9 s, the sim's own FALL, so the log is on its tile as the crown goes.
##   Its shadow does not turn with it: it runs out along the ground.
## - **A beaver** sits left of an even tree and right of an odd one, rears as
##   the sim's next bite comes due, has its teeth in on `hit`, and hops when
##   the tree is down, which falls away from it.
## - **What stands is sorted by `Art.depth`** across trees and buildings. Only
##   trees wear the wind, so the sorted list is cut into runs of one kind and
##   each run drawn on its own layer, windy and plain by turns.
## - **Belts are two MultiMeshes**, the legs and edges under (`Art.belt_under`)
##   and the beds over, lifted `Art.BELT_UP`, both filled back to front; they
##   stay flat layers under everything that stands. What lies or rides is one
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
##   face and keeps it toward the eye at every turn, its counter's stack
##   where the art puts it; the ground's washes, pebbles and tufts are a
##   plate's own and do not turn with the land.
##
## Under reduce motion a beaver is there or not and only changes its face, a
## felled tree fades where it stands, nothing bursts, a plate and a module
## are there at once and smoke stands still.

## A felled tree's crown has come down at `at` (view units): the holder's dust.
signal landed(at: Vector2)

const Art = preload("res://factory/art.gd")
const Sim = preload("res://factory/sim.gd")
const Beaver = preload("res://ui/faces/beaver.gd")
const Motion = preload("res://core/motion.gd")

## Seconds a hit tree's squash lasts, and the four beats of a fall.
const SQUASH := 0.16
const CREAK := 0.1
const DROP := 0.42
const SETTLE := 0.18
const GONE := 0.2
## How far over a lying tree is, in radians, and how far it leans back first.
const LIE := 1.5
const BACK := 0.07
## A beaver's seconds in and out, how long it stays by a tree no longer
## bitten, a bite's length and a cheer's.
const SHOW_IN := 0.16
const SHOW_OUT := 0.14
const LINGER := 0.15
const BITE := 0.26
const CHEER := 0.56
## Chips and burst leaves in the air at most, and how fast they come down.
const BITS := 48
const FALLS := 900.0
## Seconds a tree takes to come up, and a plate out of the pond; how far
## under it starts (view units) and the part of the rise its trees wait.
const GROW := 0.6
const RISE := 3.0
const SUNK := 90.0
const RISE_BARE := 0.7
## Every layer's box: a board of a dozen plates either way and the pond
## round it. The engine culls a layer by this and not by what it draws.
const BOX := Rect2(-40000.0, -40000.0, 80000.0, 80000.0)
const MID := Vector2(0.5, 0.5)
const ITEMS := ["log", "stone", "lime", "charcoal"]

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
var _belt_mm: MultiMesh
var _under_mm: MultiMesh
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
var _falls := {}      # tree id -> {id, tile, look, t, dir, down}
var _beavers := {}    # tree id -> {tile, look, side, show, rising, seen, bite, cheer, age, size, due}
var _bits: Array = []     # {pos, vel, t, life, turn, spin, col, size, weight}: view units
var _bit_mm: MultiMesh
var _rng := RandomNumberGenerator.new()

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
	_flat_l = layer(_draw_flat)
	_shade_l = layer(_draw_shade, _shade_mat)
	_item_l = layer(_draw_items)
	_stand = Node2D.new()
	_stand.name = "Stand"
	world.add_child(_stand)
	_air_l = layer(_draw_air)
	_belt_mm = MultiMesh.new()
	_belt_mm.transform_format = MultiMesh.TRANSFORM_2D
	_belt_mm.mesh = Art.belt()
	_under_mm = MultiMesh.new()
	_under_mm.transform_format = MultiMesh.TRANSFORM_2D
	_under_mm.mesh = Art.belt_under()
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
	_falls.clear()
	_beavers.clear()
	_bits.clear()
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
	if kind == "firebox":
		return [root, Vector2i.ONE]
	var front := root + Art.DIRS[facing]
	return [Vector2i(mini(root.x, front.x), mini(root.y, front.y)), Vector2i.ONE + (front - root).abs()]

# --- the sim's events ---

func event(e: Dictionary) -> void:
	match String(e.type):
		"hit":
			_on_hit(int(e.id))
		"fell":
			_on_fell(int(e.id))
		"grew":
			_born[int(e.id)] = 0.0
		"cleared":
			_falls.erase(int(e.id))
			_beavers.erase(int(e.id))
		"chip":
			shake(e.tile)
		"laid", "turned", "sold_back":
			_belts_stale = true
		"plate":
			_plates_n = -1
			if not Motion.reduce:
				var p: Vector2i = e.plate
				_rise[p] = 0.0
				for id: int in sim.trees:
					if Sim.plate_of(sim.trees[id].tile) == p:
						_born[id] = -RISE * RISE_BARE

## What stands on `tile` shakes its head: a tap it did not take.
func shake(tile: Vector2i) -> void:
	if not Motion.reduce:
		_wob[tile] = 0.0

## The tree is squashed and its beaver's teeth are in, a chip or two flying.
func _on_hit(id: int) -> void:
	if not sim.trees.has(id):
		return
	var tr: Dictionary = sim.trees[id]
	_hit[id] = 0.0
	var b := _beaver(tr)
	b.bite = 0.0
	if Motion.reduce:
		return
	var side: float = b.side
	var at := mid(tr.tile) + Vector2(side * Art.girth(tr.look), -22.0 * float(b.size))
	for i in 2:
		_bit(at, Vector2(side * _rng.randf_range(40.0, 150.0), -_rng.randf_range(120.0, 260.0)), 0.42,
			Art.PITH if i == 0 else Art.BARK.lightened(0.25), _rng.randf_range(0.5, 0.8), 1.0)

## The third bite: the tree starts down, away from its beaver, which cheers.
func _on_fell(id: int) -> void:
	if not sim.trees.has(id):
		return
	var tr: Dictionary = sim.trees[id]
	var b := _beaver(tr)
	b.bite = 0.0
	b.cheer = 0.0
	var f := {"id": id, "tile": tr.tile, "look": int(tr.look), "t": 0.0, "dir": -float(b.side), "down": false}
	_falls[id] = f
	if Motion.reduce:
		f.down = true
		landed.emit(mid(tr.tile))

func _beaver(tr: Dictionary) -> Dictionary:
	var id: int = tr.id
	if not _beavers.has(id):
		_beavers[id] = {"tile": tr.tile, "look": int(tr.look), "side": -1.0 if id % 2 == 0 else 1.0, "show": 0.0,
			"rising": true, "seen": 0.0, "bite": 10.0, "cheer": -1.0, "age": 0.0,
			"size": 0.7 + 0.004 * float(Art.RADIUS[int(tr.look)]), "due": 0.0}
	return _beavers[id]

func _bit(at: Vector2, vel: Vector2, life: float, colour: Color, size: float, weight: float) -> void:
	if _bits.size() >= BITS:
		return
	_bits.append({"pos": at, "vel": vel, "t": 0.0, "life": life, "turn": _rng.randf() * TAU,
		"spin": _rng.randf_range(-9.0, 9.0), "col": colour, "size": size, "weight": weight})

## A crown hits the ground: its leaves jump out of it.
func _burst(f: Dictionary) -> void:
	var look: int = f.look
	var r: float = float(Art.RADIUS[look]) * Art.TREE_SCALE
	var at := _crown_at(f)
	for i in 5 + look:
		_bit(at + Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.5, 0.2)) * r,
			Vector2(float(f.dir) * _rng.randf_range(10.0, 150.0) + _rng.randf_range(-70.0, 70.0), -_rng.randf_range(110.0, 300.0)),
			_rng.randf_range(0.7, 1.1), Art.LEAF[look], _rng.randf_range(0.9, 1.4), 0.5)

## Where the middle of a lying tree's crown is, in view units.
func _crown_at(f: Dictionary) -> Vector2:
	var r: float = float(Art.RADIUS[int(f.look)]) * Art.TREE_SCALE * 1.7
	return mid(f.tile) + Vector2(float(f.dir) * sin(LIE), -cos(LIE)) * r

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
	var rising := not _rise.is_empty()
	for p: Vector2i in _rise.keys():
		if _rise[p] > RISE:
			_rise.erase(p)
	var whole := Motion.REDUCED_TIME if Motion.reduce else CREAK + DROP + SETTLE + GONE
	for id: int in _falls.keys():
		var f: Dictionary = _falls[id]
		f.t += delta
		if not f.down and (Motion.reduce or f.t >= CREAK + DROP):
			f.down = true
			if not Motion.reduce:
				_burst(f)
			landed.emit(_crown_at(f))
		if f.t >= whole:
			_falls.erase(id)
	for id: int in _beavers.keys():
		var b: Dictionary = _beavers[id]
		b.seen += delta
		b.bite += delta
		b.age += delta
		if b.cheer >= 0.0:
			b.cheer += delta
	for id: int in sim.trees:
		var tr: Dictionary = sim.trees[id]
		if tr.state == "bitten":
			var b := _beaver(tr)
			b.seen = 0.0
			b.due = 1.0 - clampf(float(tr.t) / Sim.BITE_EVERY, 0.0, 1.0)
	for id: int in _beavers.keys():
		var b: Dictionary = _beavers[id]
		var want: bool = b.seen < LINGER or (b.cheer >= 0.0 and b.cheer < CHEER)
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
	if _plates_n != sim.plates.size():
		_lay_plates()
		rising = true
	if _belts_stale or _belt_n != sim.belts.size():
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

func _lay_belts() -> void:
	_belts_stale = false
	_belt_n = sim.belts.size()
	if _belt_mm.instance_count < _belt_n:
		_belt_mm.instance_count = maxi(32, _belt_n * 2)
		_under_mm.instance_count = _belt_mm.instance_count
	# the back first: a nearer belt's legs and edge are over a further one's
	var tiles: Array = sim.belts.keys()
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return depth(Vector2(a)) < depth(Vector2(b)))
	var lift := Transform2D(0.0, Art.BELT_LIFT)
	for i in tiles.size():
		var tile: Vector2i = tiles[i]
		_under_mm.set_instance_transform_2d(i, Transform2D(0.0, mid(tile)))
		_belt_mm.set_instance_transform_2d(i, lift * Art.flat(Vector2(seen_tile(tile)), seen_facing(int(sim.belts[tile]))))
	_belt_mm.visible_instance_count = _belt_n
	_under_mm.visible_instance_count = _belt_n
	_under_l.queue_redraw()
	_belt_l.queue_redraw()

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
				(lists[it.kind] as Array).append(seen(sim.item_pos(tile, it)) + Vector2(0.0, -up))
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

## A falling tree at its moment: how far over (to the right when over 0),
## how flat it is pressed along its length, how much of it is left (1 to 0
## as it goes), how seen it is and how much of its shadow.
func _pose(f: Dictionary) -> Array:
	var t: float = f.t
	if Motion.reduce:
		var left := 1.0 - t / Motion.REDUCED_TIME
		return [0.0, 0.0, 1.0, left, left]
	var dir: float = f.dir
	if t < CREAK:
		return [-dir * BACK * sin(t / CREAK * PI * 0.5), 0.0, 1.0, 1.0, 1.0]
	t -= CREAK
	if t < DROP:
		return [dir * lerpf(-BACK, LIE, pow(t / DROP, 2.4)), 0.0, 1.0, 1.0, 1.0]
	t -= DROP
	if t < SETTLE:
		var k := t / SETTLE
		return [dir * (LIE - 0.14 * sin(k * PI) * (1.0 - k)), 0.1 * sin(minf(1.0, k * 2.0) * PI), 1.0, 1.0, 1.0]
	t -= SETTLE
	var g := clampf(t / GONE, 0.0, 1.0)
	return [dir * LIE, 0.0, (1.0 + 0.3 * g) * (1.0 - g * g), 0.0 if g >= 1.0 else 1.0, 1.0 - g]

## A stump of `look`: a sapling's is the birch's, small.
static func _stump(look: int) -> Array:
	return [Art.stump(1), 0.55] if look == 0 else [Art.stump(look), 1.0]

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
		var d := depth(Vector2(tile) + MID)
		var at := mid(tile)
		if tr.state == "stump":
			if _falls.has(id):
				continue
			var s := _stump(tr.look)
			list.append([d, 1, s[0], Transform2D(0.0, Vector2(s[1], s[1]), 0.0, at), white])
		else:
			var size := _size(id)
			if size.x > 0.0:
				list.append([d, 1, Art.tree(tr.look), Transform2D(_turned(tile), size, 0.0, at), white])
	for id: int in _falls:
		_add_fall(list, _falls[id])
	for id: int in _beavers:
		_add_beaver(list, _beavers[id])
	for tile: Vector2i in sim.rocks:
		if _up(tile):
			list.append([depth(Vector2(tile) + MID), 0, Art.rock(sim.rocks[tile].ready),
				Transform2D(_turned(tile), mid(tile)), white])
	var stall := Vector2(Sim.MARKET_AT) + Vector2.ONE
	# the stall has one face and keeps it toward the eye at every turn
	var stall_d := depth(stall)
	list.append([stall_d, 0, Art.market(), Transform2D(_turned(Sim.MARKET_AT), seen(stall)), white])
	var wait: Array = sim.market.wait
	for i in mini(wait.size(), Art.MARKET_SPOTS.size()):
		list.append([stall_d + 0.01 * (i + 1), 0, Art.item(wait[i]),
			Transform2D(0.0, Vector2(0.7, 0.7), 0.0, seen(stall) + Art.MARKET_SPOTS[i]), white])
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

func _add_fall(list: Array, f: Dictionary) -> void:
	var look: int = f.look
	var tile: Vector2i = f.tile
	var at := mid(tile)
	var d := depth(Vector2(tile) + MID)
	var size := Art.TREE_SCALE
	var pose := _pose(f)
	var s := _stump(look)
	if Motion.reduce:
		list.append([d, 1, s[0], Transform2D(0.0, Vector2(s[1], s[1]), 0.0, at), Color.WHITE])
		list.append([d + 0.001, 1, Art.tree(look), Transform2D(0.0, Vector2(size, size), 0.0, at), Color(1.0, 1.0, 1.0, pose[3])])
		return
	if f.t > CREAK:
		list.append([d, 1, s[0], Transform2D(0.0, Vector2(s[1], s[1]), 0.0, at), Color.WHITE])
	var left: float = pose[2]
	if float(pose[3]) > 0.0 and left > 0.02:
		var flat: float = pose[1]
		var xf := Transform2D(float(pose[0]), Vector2(size * (1.0 + flat * 0.6), size * (1.0 - flat)), 0.0, at)
		if left != 1.0:
			# it goes into what it gives: drawn in toward its crown's middle
			var crown := xf * Vector2(0.0, -float(Art.RADIUS[look]) * 1.7)
			xf = Transform2D(0.0, Vector2(left, left), 0.0, crown * (1.0 - left)) * xf
		list.append([d + 0.001, 1, Art.tree(look), xf, Color.WHITE])

## A beaver by its tree, looking at it: popped in, reared back as the next
## bite comes due, its teeth in the wood on a hit, hopping when the tree is
## down.
func _add_beaver(list: Array, b: Dictionary) -> void:
	var show: float = b.show
	if show <= 0.0:
		return
	var tile: Vector2i = b.tile
	var side: float = b.side
	var s: float = b.size
	var grow := 1.0
	var snap := 0.0
	var rear := 0.0
	var hop := 0.0
	var cheering: bool = float(b.cheer) >= 0.0 and float(b.cheer) < CHEER
	if not Motion.reduce:
		grow = Motion.back_out(show) if b.rising else show
		snap = pow(1.0 - clampf(float(b.bite) / BITE, 0.0, 1.0), 2.0)
		if cheering:
			hop = Motion.hop_lift(fmod(float(b.cheer), CHEER * 0.5), -11.0, CHEER * 0.5)
		elif float(b.seen) < 0.1:
			rear = smoothstep(0.5, 1.0, float(b.due))
	var reach: float = Art.girth(b.look) + (Beaver.NECK.x + Beaver.TEETH.x - 2.0) * s
	var at := mid(tile) + Vector2(side * (reach - 3.0 * snap * s), 3.0 + hop)
	# it looks at the trunk: right when it sits on the left
	var xf := Transform2D(0.0, Vector2(-side * s * grow * (1.0 + 0.06 * snap), s * grow * (1.0 - 0.06 * snap)), 0.0, at)
	var wag := 0.5 * rear - 0.12 * snap + (0.3 * absf(sin(float(b.cheer) * 22.0)) if cheering else 0.04 * sin(float(b.age) * 3.0))
	var d := depth(Vector2(tile) + MID) + 0.01
	var nod := 0.22 * snap - 0.3 * rear - (0.28 if cheering else 0.0)
	var neck := Beaver.NECK + Vector2(3.0 * snap - 4.0 * rear, -2.0 * rear)
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
	if kind != "firebox":
		d += 0.5 * maxf(0.0, Art.depth(Vector2(Art.DIRS[f])))
	var mesh: ArrayMesh = Art.firebox() if kind == "firebox" else (Art.kiln(f) if kind == "kiln" else Art.retort(f))
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
		"firebox":
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
			ci.draw_multimesh(mm, null)

func _draw_under(ci: CanvasItem) -> void:
	if _belt_n > 0:
		ci.draw_multimesh(_under_mm, null)

func _draw_belts(ci: CanvasItem) -> void:
	if _belt_n > 0:
		ci.draw_multimesh(_belt_mm, null)

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
		if tr.state == "stump" or not _up(tr.tile):
			continue
		var size := _size(id)
		if size.x > 0.0:
			ci.draw_mesh(Art.shade(tr.look), null, Art.cast(mid(tr.tile), size))
	for id: int in _falls:
		var f: Dictionary = _falls[id]
		var pose := _pose(f)
		if float(pose[4]) > 0.0:
			ci.draw_mesh(Art.shade(f.look), null, Art.cast(mid(f.tile), Vector2(Art.TREE_SCALE, Art.TREE_SCALE), pose[0]),
				Color(1.0, 1.0, 1.0, pose[4]))

func _draw_items(ci: CanvasItem) -> void:
	for kind: String in ITEMS:
		if int(_item_n[kind]) > 0:
			ci.draw_multimesh(_item_mm[kind], null)

func _draw_run(ci: CanvasItem, i: int) -> void:
	for e: Array in _runs[i]:
		ci.draw_mesh(e[2], null, e[3], e[4])

## Chips and burst leaves, one MultiMesh.
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
