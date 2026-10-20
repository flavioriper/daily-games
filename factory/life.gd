extends RefCounted

## What is seen of Factory's floor, for whoever shows it (the screen, the
## tab's card, the tutorial's pages): the floor from straight above with its
## pads, the bay and the two belts of its own, the belts the player lays and
## what rides them, the squares and the boxes, the robots with their faces,
## their charge and their bubbles. It drew the isometric land of plates,
## trees and machines until 2026-10-20 (git has that); the layers, the
## holder's contract and the belts' MultiMeshes are that file's. The rules
## stay the sim's (factory/sim.gd, factory/bots.gd), the drawings the art's
## (factory/art.gd).
##
## A holder calls `mount(parent, sim)` once and is handed `world`, a Node2D
## drawn in the art's view units: the holder pans and zooms the floor by
## that node's position and scale and nothing else (every layer under it has
## a box of its own, or the engine culls it by its meshes' untransformed
## boxes). Then, every frame after it stepped the sim: `event(e)` for each of
## the sim's events and `step(delta)`. A holder that did not see the events
## (the tab, while the screen had the floor) calls `stale()` and everything
## is read from the tables again; nothing here needs an event to be right,
## only to be lively.
##
## Layers, back to front: the ground (one mesh: the floor, the two fixed
## belts, the five pads), the fixed belts' chevrons (a Batch), the laid
## belts (a MultiMesh a shape under the belt material, their shade under
## them, a bridge's deck and what crosses it over them), what lies and rides
## (a Batch a mesh: squares, boxes by their count), the robots (a Batch for
## the bodies, one a face, one a mesh for what they hold), the charge bars
## and the bubbles (a Batch each), and the holder's ghosts. Draw calls: about
## twenty on a new floor.
##
## - **Everything placed goes through `seen(t)`** (tile space to view units,
##   `Art.at`) and back through `tile_at(v)`. No turn: the floor is square
##   and a Move's arrow on the sheet is the way a robot walks on screen.
## - **A robot is drawn where `Bots.pos` has it** (`robot_pos`), sliding
##   between tiles by the sim's `alpha`. Robots share tiles freely, so the
##   ones on one tile stand side by side, a little smaller, eased there and
##   back (`robot_at`).
## - **The intake's queue** lies up the intake belt from the intake pad, the
##   newest sliding in; **a sale** rides the deliver belt off the top.
##
## Under reduce motion nothing slides in or rides off, the chevrons and the
## slats lie still, a robot's seat is taken at once and its bubbles do not
## pop.

const Art = preload("res://factory/art.gd")
const Sim = preload("res://factory/sim.gd")
const Bots = preload("res://factory/bots.gd")
const Batch = preload("res://ui/hud/batch.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

## Every layer's box: the floor and far round it. The engine culls a layer
## by this and not by what it draws.
const BOX := Rect2(-40000.0, -40000.0, 80000.0, 80000.0)
const MID := Vector2(0.5, 0.5)
## The squares queued at the intake lie this far apart up its belt (tiles),
## and one comes in or moves up over FEED_SLIDE seconds.
const QUEUE_GAP := 0.42
const FEED_SLIDE := 0.3
## A thing sold: seconds from the pad onto the deliver belt, then tiles a
## second up it, and how many ride at once at most.
const OFF_PAD := 0.25
const OFF_SPEED := 2.5
const GONE_MOST := 8
## Things lying in a stack past the sim's two spots are drawn this much
## higher each (view units).
const PILE_UP := 8.0
## Robots on one tile: how far apart (tiles), how big by how many share it,
## and how fast they ease to their seats (a rate a second).
const SPREAD := 0.34
const SHARED := [1.0, 0.88, 0.76]
const SEAT_RATE := 12.0
## A robot is drawn this much bigger than the art's own measures (its
## bubble and its bar with it), to read on a phone's tile of about 108 px.
const ROBOT_SIZE := 1.15
## How high a walking robot bobs (view units), and a bubble's pop (seconds).
const BOB := 4.0
const POP := 0.2
## A robot's tint, by its place in the chips' order (pale, so the face and
## the bars stay the loudest; no state is said by them).
const TINTS := [Color("d9efeb"), Color("fbe3cf"), Color("e6def6"), Color("e4efd2")]
const FACES := ["", "?", "flat", "nocell"]
const BUBBLES := ["?", "!", "wait", "flat", "nocell", "charge"]

## The floor, in view units: the holder's to place and scale.
var world: Node2D
var sim: RefCounted
## The holder's own flat things, over everything: [mesh, transform] each,
## and a tint if there is a third (a ghost under the finger, the run of
## belts a swipe would lay).
var ghosts: Array = []

var _ground_l: Node2D
var _chev_l: Node2D
var _under_l: Node2D
var _belt_l: Node2D
var _fast_l: Node2D
var _deck_l: Node2D
var _item_l: Node2D
var _robot_l: Node2D
var _air_l: Node2D
var _flat_l: Node2D
static var _ground: ArrayMesh
var _chevs: Batch
## The beds by shape (straight, a bend fed from the side toward its facing
## plus a quarter, one fed from the other side) and the shade under them by
## shape ("s", or a bend's corner), a MultiMesh each; a belt's shape, by
## tile, read off its feeders whenever belts change.
var _bed_mms: Array[MultiMesh] = []
var _fast_mms: Array[MultiMesh] = []
var _under_mms := {}
var _shapes := {}
var _belts_stale := true
var _belt_n := -1
## Bridges' decks, [mesh, transform] each, laid with the belts.
var _decks: Array = []
## What lies and rides, and what the robots hold: a Batch a mesh.
var _squares: Batch
var _boxes: Array[Batch] = []
var _held_squares: Batch
var _held_boxes: Array[Batch] = []
var _bodies: Batch
var _faces := {}
var _track: Batch
var _charge: Batch
var _bubbles := {}
## Seconds since the queue grew, and since one was taken off it.
var _fed := 99.0
var _took := 99.0
## Sold things riding off: {kind, n, t}.
var _gone: Array = []
## Each robot's seat: {off (view units), size, bubble, popped}.
var _seats: Array = []

func _init() -> void:
	_chevs = Batch.new(Art.chevron())
	_squares = Batch.new(Art.square())
	_held_squares = Batch.new(Art.square())
	for n in Sim.BOX_FULL + 1:
		_boxes.append(Batch.new(Art.box(n)))
		_held_boxes.append(Batch.new(Art.box(n)))
	_bodies = Batch.new(Art.robot())
	for stuck: String in FACES:
		_faces[stuck] = Batch.new(Art.face(stuck))
	_track = Batch.new(Art.bar())
	_charge = Batch.new(Art.bar())
	for kind: String in BUBBLES:
		_bubbles[kind] = Batch.new(Art.bubble(kind))

## Builds the floor's layers under `parent` and returns `world`.
func mount(parent: Node, with_sim: RefCounted) -> Node2D:
	sim = with_sim
	world = Node2D.new()
	world.name = "World"
	parent.add_child(world)
	_ground_l = layer(_draw_ground)
	_chev_l = layer(_draw_chevrons)
	_under_l = layer(_draw_under)
	_belt_l = layer(_draw_belts, Art.belt_material())
	_fast_l = layer(_draw_fast, Art.belt_material(true))
	_deck_l = layer(_draw_decks)
	_item_l = layer(_draw_items)
	_robot_l = layer(_draw_robots)
	_air_l = layer(_draw_air)
	_flat_l = layer(_draw_flat)
	for mesh: ArrayMesh in [Art.belt(), Art.belt_bend(false), Art.belt_bend(true)]:
		_bed_mms.append(_many(mesh))
		_fast_mms.append(_many(mesh))
	stale()
	return world

## Another floor in the same layers (a tutorial page starting over).
func hold(with_sim: RefCounted) -> void:
	sim = with_sim
	_gone.clear()
	_seats.clear()
	_fed = 99.0
	_took = 99.0
	stale()

## A layer of the floor over the ones there are, drawn by `draws(layer)`:
## the holder's own (a ring, the figures over a sale) go on top this way.
func layer(draws: Callable, material: Material = null, into: Node = null) -> Node2D:
	var c := Node2D.new()
	c.material = material
	c.draw.connect(draws.bind(c))
	RenderingServer.canvas_item_set_custom_rect(c.get_canvas_item(), true, BOX)
	(world if into == null else into).add_child(c)
	return c

## Everything is read from the sim's tables again at the next step.
func stale() -> void:
	_belts_stale = true

# --- where a tile is seen ---

## A point of the sim's tile space (a tile's middle is tile + (0.5, 0.5)),
## in view units. THE way from the sim to the eye.
func seen(t: Vector2) -> Vector2:
	return Art.at(t)

## The point of the sim's tile space under a point of the view: the way back.
func tile_at(v: Vector2) -> Vector2:
	return Art.tile_at(v)

## The floor's box in view units.
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(Sim.COLS, Sim.ROWS) * Art.TILE)

## The floor's box in tile space.
func tile_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(Sim.COLS, Sim.ROWS))

## The middle of a tile, in view units.
func mid(tile: Vector2i) -> Vector2:
	return seen(Vector2(tile) + MID)

## Where robot `i` is, in view units: between the tile it stepped from and
## the one it steps to, by the sim's `alpha`.
func robot_pos(i: int) -> Vector2:
	return seen(Bots.pos(sim.robots[i], float(sim.alpha)))

## Where robot `i` is drawn: `robot_pos` and its seat beside the others on
## its tile. For a tap on it.
func robot_at(i: int) -> Vector2:
	var at := robot_pos(i)
	if i < _seats.size():
		at += _seats[i].off as Vector2
	return at

# --- the sim's events ---

func event(e: Dictionary) -> void:
	match String(e.type):
		"laid", "turned", "flipped", "sold_back", "sold_line":
			_belts_stale = true
		"queued":
			_fed = 0.0
		"took":
			if e.tile == Sim.STATIONS.intake:
				_took = 0.0
		"sale":
			if not Motion.reduce and _gone.size() < GONE_MOST:
				_gone.append({"kind": String(e.kind), "n": int(e.n), "t": 0.0})

# --- time ---

## `delta` seconds pass, after the sim's own step and its events.
func step(delta: float) -> void:
	# one clock for every holder: the belts' material is shared
	Art.belt_run(Time.get_ticks_msec() / 1000.0)
	_fed += delta
	_took += delta
	for g: Dictionary in _gone:
		g.t = float(g.t) + delta
	_gone = _gone.filter(func(g: Dictionary) -> bool: return _gone_at(g).y > -0.7)
	if _belts_stale or _belt_n != sim.belts.size() + sim.kinds.size() * 1000:
		_lay_belts()
	_fill_chevrons()
	_fill_items()
	_fill_robots(delta)
	for l: Node2D in [_chev_l, _deck_l, _item_l, _robot_l, _air_l, _flat_l]:
		l.queue_redraw()

func _many(mesh: ArrayMesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = mesh
	mm.instance_count = 16
	mm.visible_instance_count = 0
	return mm

## The floor's own: its ground, the two belts down its first and last
## columns and the five pads, one mesh for every holder.
static func _ground_mesh() -> ArrayMesh:
	if _ground == null:
		var b := Face.Builder.new()
		b.append(Art.floor_mesh(Sim.COLS, Sim.ROWS), Transform2D.IDENTITY)
		b.append(Art.fixed_belt(Sim.ROWS, false), Transform2D.IDENTITY)
		b.append(Art.fixed_belt(Sim.ROWS, true), Transform2D(0.0, Vector2((Sim.COLS - 1) * Art.TILE, 0.0)))
		for kind: String in Sim.STATIONS:
			b.append(Art.pad(kind), Transform2D(0.0, Art.at(Vector2(Sim.STATIONS[kind]) + MID)))
		_ground = b.mesh()
	return _ground

# --- belts ---

## The shape of the belt on `tile`: 0 straight, 1 a quarter bend fed from
## the side its facing plus a quarter looks to, 2 from the other side. A
## belt is a bend only when its one feeder comes in by a side; fed from
## behind, from both sides or by nothing it is straight, and a side belt
## butts into it. Read off the sim's tables every time, never kept there.
func shape(tile: Vector2i) -> int:
	if not sim.belts.has(tile):
		return 0
	var f: int = sim.belts[tile]
	var fed := [false, false, false, false]   # by the quarter the feeder lies to, from the facing
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
	var beds := [[], [], []]
	var fast := [[], [], []]
	var unders := {}
	_shapes.clear()
	_decks.clear()
	for tile: Vector2i in sim.belts:
		var bend := shape(tile)
		var f: int = int(sim.belts[tile])
		var key: Variant = "s"
		if bend != 0:
			_shapes[tile] = bend
			key = Art.DIRS[f] + Art.DIRS[(f + (1 if bend == 1 else 3)) % 4]
		var kind: String = sim.kinds.get(tile, "")
		((fast if kind == "fast" else beds)[bend] as Array).append(Art.flat(Vector2(tile), f))
		if not unders.has(key):
			unders[key] = []
		(unders[key] as Array).append(Transform2D(0.0, mid(tile)))
		if kind == "bridge":
			_decks.append([Art.bridge(f), Transform2D(0.0, mid(tile))])
	for i in 3:
		_fill(_bed_mms[i], beds[i])
		_fill(_fast_mms[i], fast[i])
	for key: Variant in unders:
		if not _under_mms.has(key):
			_under_mms[key] = _many(Art.belt_under() if key is String else Art.belt_under_bend(key))
	for key: Variant in _under_mms:
		_fill(_under_mms[key], unders.get(key, []))
	_under_l.queue_redraw()
	_belt_l.queue_redraw()
	_fast_l.queue_redraw()

func _fill(mm: MultiMesh, xfs: Array) -> void:
	if mm.instance_count < xfs.size():
		mm.instance_count = xfs.size() * 2
	for i in xfs.size():
		mm.set_instance_transform_2d(i, xfs[i])
	mm.visible_instance_count = xfs.size()

## The fixed belts' chevrons, a row down each, run by the clock: the intake
## down its column, the deliver belt up its own. They fade in and out at
## the floor's top and foot.
func _fill_chevrons() -> void:
	_chevs.n = 0
	var run := 0.0 if Motion.reduce else fposmod(Time.get_ticks_msec() / 1000.0 * Art.FIXED_SPEED, Art.CHEVRON_GAP)
	var long := float(Sim.ROWS)
	var k := 0
	while k * Art.CHEVRON_GAP <= long:
		for up: bool in [false, true]:
			var y := k * Art.CHEVRON_GAP + (long - run if up else run)
			y = fposmod(y, long + Art.CHEVRON_GAP)
			var fade := clampf(minf(y, long - y) / 0.3, 0.0, 1.0)
			if fade <= 0.0:
				continue
			var x := (float(Sim.COLS) - 0.5) if up else 0.5
			_chevs.put(Transform2D(0.0, Vector2(1.0, -1.0 if up else 1.0), 0.0, seen(Vector2(x, y))), Color(1.0, 1.0, 1.0, fade))
		k += 1

# --- what lies and rides ---

## An item into the batches by its mesh: a square, or a box by its count.
func _put(it: Dictionary, xf: Transform2D, held := false, tint := Color.WHITE) -> void:
	if String(it.get("kind", "")) == "box":
		(_held_boxes if held else _boxes)[clampi(int(it.get("n", 0)), 0, Sim.BOX_FULL)].put(xf, tint)
	else:
		(_held_squares if held else _squares).put(xf, tint)

## What lies on the floor and rides the belts, each where the sim has it
## between two ticks; the box on the table; the intake's queue up its belt;
## what was sold, riding off.
func _fill_items() -> void:
	_squares.n = 0
	for bx: Batch in _boxes:
		bx.n = 0
	for tile: Vector2i in sim.items:
		var arr: Array = sim.items[tile]
		var lying: bool = not sim.belts.has(tile)
		for i in arr.size():
			var at := seen(item_at(tile, arr[i]))
			if lying and i >= Sim.LIE.size():
				at.y -= PILE_UP * (i - Sim.LIE.size() + 1)
			_put(arr[i], Transform2D(0.0, at))
	if not sim.table.is_empty():
		_put(sim.table, Transform2D(0.0, seen(sim.item_pos(Sim.STATIONS.table, sim.table))))
	# the queue: the front square by the pad, the rest up the belt behind it
	var pad: Vector2 = Vector2(0.5, float(Sim.STATIONS.intake.y) + 0.5)
	var moved := 0.0 if Motion.reduce else 1.0 - smoothstep(0.0, FEED_SLIDE, _took)
	var came := 0.0 if Motion.reduce else 1.0 - smoothstep(0.0, FEED_SLIDE, _fed)
	for k in int(sim.queue):
		var up := float(k) + moved
		if k == int(sim.queue) - 1:
			up += came
		_put({"kind": "square"}, Transform2D(0.0, seen(pad - Vector2(0.0, up * QUEUE_GAP))))
	for g: Dictionary in _gone:
		var at := _gone_at(g)
		_put(g, Transform2D(0.0, seen(at)), false, Color(1.0, 1.0, 1.0, clampf((at.y + 0.6) / 0.6, 0.0, 1.0)))

## Where a thing sold is now, in tile space: off the deliver pad onto the
## belt to its right, then up it and off the top.
func _gone_at(g: Dictionary) -> Vector2:
	var from := Vector2(Sim.STATIONS.deliver) + MID
	var belt := Vector2(float(Sim.COLS) - 0.5, from.y)
	var t: float = g.t
	if t < OFF_PAD:
		return from.lerp(belt, smoothstep(0.0, 1.0, t / OFF_PAD))
	return belt - Vector2(0.0, (t - OFF_PAD) * OFF_SPEED)

# --- the robots ---

## Every robot: its body tinted by its place, its face by `stuck`, what it
## holds, its charge and its bubble. The ones on one tile sit side by side.
func _fill_robots(delta: float) -> void:
	_bodies.n = 0
	_held_squares.n = 0
	for bx: Batch in _held_boxes:
		bx.n = 0
	for kind: String in _faces:
		(_faces[kind] as Batch).n = 0
	_track.n = 0
	_charge.n = 0
	for kind: String in _bubbles:
		(_bubbles[kind] as Batch).n = 0
	var robots: Array = sim.robots
	while _seats.size() < robots.size():
		_seats.append({"off": Vector2.ZERO, "size": 1.0, "bubble": "", "popped": POP, "new": true})
	_seats.resize(robots.size())
	# who shares a tile, by where each is drawn now
	var by_tile := {}
	var pos: Array[Vector2] = []
	for i in robots.size():
		var p := Bots.pos(robots[i], float(sim.alpha))
		pos.append(p)
		var key := Vector2i(p.floor())
		if not by_tile.has(key):
			by_tile[key] = []
		(by_tile[key] as Array).append(i)
	var ease := 1.0 if Motion.reduce else 1.0 - exp(-SEAT_RATE * delta)
	for key: Vector2i in by_tile:
		var them: Array = by_tile[key]
		var k := them.size()
		for j in k:
			var seat: Dictionary = _seats[them[j]]
			var want_off := Vector2((j - (k - 1) * 0.5) * SPREAD * Art.TILE, 0.0)
			var want_size: float = SHARED[mini(k, SHARED.size()) - 1]
			var e := 1.0 if seat.new else ease
			seat.off = (seat.off as Vector2).lerp(want_off, e)
			seat.size = lerpf(float(seat.size), want_size, e)
			seat.new = false
	# the ones further up the screen first, so a nearer one is over them
	var order: Array = range(robots.size())
	order.sort_custom(func(a: int, b: int) -> bool: return pos[a].y < pos[b].y or (pos[a].y == pos[b].y and a < b))
	for i: int in order:
		var b: Dictionary = robots[i]
		var seat: Dictionary = _seats[i]
		var at := seen(pos[i]) + (seat.off as Vector2)
		if b.was != b.tile and not Motion.reduce:
			var along := pos[i].distance_to(Vector2(b.was) + MID)
			at.y -= BOB * absf(sin(along * PI))
		var s: float = float(seat.size) * ROBOT_SIZE
		var xf := Transform2D(0.0, Vector2(s, s), 0.0, at)
		_bodies.put(xf, TINTS[i % TINTS.size()])
		var stuck := String(b.stuck)
		(_faces[stuck if _faces.has(stuck) else ""] as Batch).put(xf)
		if not (b.held as Dictionary).is_empty():
			_put(b.held, xf * Transform2D(0.0, Vector2(Art.HELD_SCALE, Art.HELD_SCALE), 0.0, Art.HELD_AT), true)
		var bar := xf * Transform2D(0.0, Art.BAR_AT)
		_track.put(bar * Art.battery_bar(1.0), Art.TRACK)
		var full := Bots.cell(b)
		var f := float(b.charge) / float(full) if full > 0 else 0.0
		if f > 0.0:
			_charge.put(bar * Art.battery_bar(f), Art.battery_tone(f))
		var said := String(b.bubble)
		if said == "" and b.charging:
			said = "charge"
		if said != String(seat.bubble):
			seat.bubble = said
			seat.popped = 0.0
		seat.popped = float(seat.popped) + delta
		if _bubbles.has(said):
			var pop := 1.0 if Motion.reduce else 0.5 + 0.5 * Motion.back_out(clampf(float(seat.popped) / POP, 0.0, 1.0))
			(_bubbles[said] as Batch).put(xf * Transform2D(0.0, Vector2(pop, pop), 0.0, Art.BUBBLE_AT))

# --- drawing ---

func _draw_ground(ci: Node2D) -> void:
	ci.draw_mesh(_ground_mesh(), null)

func _draw_chevrons(ci: Node2D) -> void:
	_chevs.draw(ci)

func _draw_under(ci: Node2D) -> void:
	for key: Variant in _under_mms:
		if (_under_mms[key] as MultiMesh).visible_instance_count > 0:
			ci.draw_multimesh(_under_mms[key], null)

func _draw_belts(ci: Node2D) -> void:
	for mm in _bed_mms:
		if mm.visible_instance_count > 0:
			ci.draw_multimesh(mm, null)

func _draw_fast(ci: Node2D) -> void:
	for mm in _fast_mms:
		if mm.visible_instance_count > 0:
			ci.draw_multimesh(mm, null)

## A bridge's deck over its belt, and what crosses it over the deck.
func _draw_decks(ci: Node2D) -> void:
	for d: Array in _decks:
		ci.draw_mesh(d[0], null, d[1])
	for tile: Vector2i in sim.over:
		var lane: Dictionary = sim.over[tile]
		for it: Dictionary in lane.items:
			var pos: Vector2 = sim.item_pos(tile, it)
			var along := 0.5 + (pos - (Vector2(tile) + MID)).dot(Vector2(Art.DIRS[int(lane.dir)]))
			ci.draw_mesh(Art.item(it), null, Transform2D(0.0, seen(pos) - Vector2(0.0, Art.bridge_lift(along))))

func _draw_items(ci: Node2D) -> void:
	_squares.draw(ci)
	for bx: Batch in _boxes:
		bx.draw(ci)

func _draw_robots(ci: Node2D) -> void:
	_bodies.draw(ci)
	for kind: String in _faces:
		(_faces[kind] as Batch).draw(ci)
	_held_squares.draw(ci)
	for bx: Batch in _held_boxes:
		bx.draw(ci)

func _draw_air(ci: Node2D) -> void:
	_track.draw(ci)
	_charge.draw(ci)
	for kind: String in _bubbles:
		(_bubbles[kind] as Batch).draw(ci)

func _draw_flat(ci: Node2D) -> void:
	for g: Array in ghosts:
		ci.draw_mesh(g[0], null, g[1], g[2] if g.size() > 2 else Color.WHITE)
