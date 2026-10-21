extends RefCounted

## What is seen of Factory's floor, for whoever shows it (the screen, the
## tab's card, the tutorial's pages): the land's view of it, corner on, as
## the land was drawn until 2026-10-20 and again since 2026-10-21 (the user:
## "factory redesign is wrong, it was suppose to use at most the elements
## factory already had on design"). One plate on the pond, the two belts of
## its own (the intake's down column 0, the deliver belt up column 9), the
## belts the player lays and what rides them, the stations as the land's own
## pieces (the bay is the engine, the deliver pad the market's hatch, the
## pack table the tray, the box stack a heap of empty boxes), and the robots
## among them with their faces, their charge and their bubbles. The rules
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
## Layers, back to front: the plate, the belts' legs and their beds (a
## MultiMesh a shape under the one belt material), the holder's ghosts, what
## lies and rides (a Batch a mesh), what stands, sorted by depth every frame
## and cut into runs by material (stations, robots and what they hold, a
## bridge's deck, and a belt right in front of something standing drawn
## again over it), the air (charge bars and bubbles, a Batch each).
##
## - **The view turns by quarters** (`turn`, 2026-10-10: "add a button to
##   rotate the view"). The sim's tiles never change; only where a tile is
##   seen does. **Everything that places or reads a position goes through
##   `seen(t)` and `tile_at(v)`** (and `seen_tile`, `seen_facing`, `depth`
##   on the same turn): never `Art.at` on a sim coordinate. The market and
##   the engine have one face and keep it toward the eye at every turn; the
##   plate's washes are its own and do not turn.
## - **A robot stands where `Bots.pos` has it** (`robot_pos`), sliding
##   between tiles by the sim's `alpha`, lifted onto a belt's bed when it
##   walks over one. Robots share tiles freely, so the ones on one tile
##   stand side by side, a little smaller, eased there and back (`robot_at`);
##   on a station's tile they stand at its front, the station's piece pushed
##   to the back of the tile.
## - **The intake's queue** waits on the intake belt, the front one at the
##   intake pad; **a sale** falls through the market's hatch and its coin
##   hops.
##
## Under reduce motion nothing slides in, the slats lie still, the flywheel
## stands, a robot's seat is taken at once, its bubbles do not pop and a
## sale is only its coin.

const Art = preload("res://factory/art.gd")
const Sim = preload("res://factory/sim.gd")
const Bots = preload("res://factory/bots.gd")
const Batch = preload("res://ui/hud/batch.gd")
const Motion = preload("res://core/motion.gd")

## Every layer's box: the floor and far round it. The engine culls a layer
## by this and not by what it draws.
const BOX := Rect2(-40000.0, -40000.0, 80000.0, 80000.0)
const MID := Vector2(0.5, 0.5)
## The floor's two belts of its own, [tile, sim facing, shape] (shape as
## `shape` says): the intake down column 0 and round the corner into the
## intake pad, the deliver belt fed from the market and up column 9. Drawn,
## never moved along by the sim.
const FIXED := [
	[Vector2i(0, 0), 1, 0], [Vector2i(0, 1), 1, 0], [Vector2i(0, 2), 1, 0], [Vector2i(0, 3), 1, 0], [Vector2i(0, 4), 1, 0],
	[Vector2i(0, 5), 0, 2],
	[Vector2i(9, 5), 3, 2],
	[Vector2i(9, 4), 3, 0], [Vector2i(9, 3), 3, 0], [Vector2i(9, 2), 3, 0], [Vector2i(9, 1), 3, 0], [Vector2i(9, 0), 3, 0],
]
## The squares queued at the intake lie this far apart along its belt
## (tiles) back from the pad, and one comes in or moves up over FEED_SLIDE
## seconds.
const QUEUE_GAP := 0.42
const QUEUE_FRONT := 0.12
const FEED_SLIDE := 0.3
## Things lying in a stack past the sim's two spots are drawn this much
## higher each (view units: a thing's height).
const PILE_UP := 20.0
## Robots on one tile: how far apart (tiles across the screen), how big by
## how many share it, and how fast they ease to their seats (a rate a
## second); on a station's tile they stand SEAT_FORE nearer the eye.
const SPREAD := 0.34
const SHARED := [1.0, 0.88, 0.76]
const SEAT_RATE := 12.0
const SEAT_FORE := Vector2(0.0, 12.0)
## A station's piece is drawn STATION_K as big and STATION_BACK toward the
## back of its tile, so a robot standing on the tile stands in front of it.
const STATION_K := 0.82
const STATION_BACK := Vector2(0.0, -16.0)
## A robot is drawn this much bigger than the art's own measures (its
## bubble and its bar with it), to read on a phone.
const ROBOT_SIZE := 1.15
## How high a walking robot bobs (view units), and a bubble's pop (seconds).
const BOB := 4.0
const POP := 0.2
## A robot's tint, by its place in the chips' order (pale, so the face and
## the bars stay the loudest; no state is said by them).
const TINTS := [Color("d9efeb"), Color("fbe3cf"), Color("e6def6"), Color("e4efd2")]
const FACES := ["", "?", "flat", "nocell"]
const BUBBLES := ["?", "!", "wait", "flat", "nocell", "charge"]
## The market's hatch (the land's, 2026-10-11): a sale is played over SALE
## seconds: the leaves swing down over OPEN of it, the thing falls from
## FALL_FROM to FALL_TO (FALL view units, into the dark), the coin comes up
## at COIN_AT and the leaves are shut again from SHUT_FROM to SHUT_TO. A
## coin hops COIN_UP and is gone in COIN seconds; DROPS sales are played at
## once.
const SALE := 0.62
const OPEN := 0.3
const FALL_FROM := 0.2
const FALL_TO := 0.7
const FALL := 38.0
const COIN_AT := 0.55
const SHUT_FROM := 0.7
const SHUT_TO := 0.95
const COIN := 0.75
const COIN_UP := 64.0
const DROPS := 4
## The engine's flywheel: turns a second while a robot charges on the bay.
const WHEEL_TURNS := 0.5

## The floor, in view units: the holder's to place and scale.
var world: Node2D
var sim: RefCounted
## Quarters the view is turned clockwise, 0 to 3: set by `set_turn`. A view
## preference of the holder's, never the sim's and never kept.
var turn := 0
## The holder's own flat things, over the belts and under what stands:
## [mesh, transform] each, and a tint if there is a third (the run of belts
## a swipe would lay).
var ghosts: Array = []

var _ground_l: Node2D
var _under_l: Node2D
var _belt_l: Node2D
var _fast_l: Node2D
var _flat_l: Node2D
var _item_l: Node2D
var _stand: Node2D
var _air_l: Node2D
var _pool: Array[Node2D] = []
## What a run of the standing list is drawn under, by its `wear`.
enum { PLAIN, BED, BED_FAST }
var _wears: Array = []
var _runs: Array = []
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
## Every belt as drawn, the floor's own with them, by sim tile: [bed mesh,
## fast, bed transform, under mesh, under transform], for one drawn again
## in front of something standing.
var _bed_of := {}
## What lies and rides: a Batch a mesh.
var _squares: Batch
var _boxes: Array[Batch] = []
var _track: Batch
var _charge: Batch
var _bubbles := {}
## Seconds since the queue grew, and since one was taken off it.
var _fed := 99.0
var _took := 99.0
## Sales being played: {kind, n, t}.
var _drops: Array = []
## Each robot's seat: {off (view units), size, bubble, popped, new}.
var _seats: Array = []
## How far the bay's flywheel has turned (radians).
var _spun := 0.4

func _init() -> void:
	_squares = Batch.new(Art.square())
	for n in Sim.BOX_FULL + 1:
		_boxes.append(Batch.new(Art.box(n)))
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
	_under_l = layer(_draw_under)
	_belt_l = layer(_draw_belts, Art.belt_material())
	_fast_l = layer(_draw_fast, Art.belt_material(true))
	_wears = [null, _belt_l.material, _fast_l.material]
	_flat_l = layer(_draw_flat)
	_item_l = layer(_draw_items)
	_stand = Node2D.new()
	_stand.name = "Stand"
	world.add_child(_stand)
	_air_l = layer(_draw_air)
	for mesh: ArrayMesh in [Art.belt(), Art.belt_bend(false), Art.belt_bend(true)]:
		_bed_mms.append(_many(mesh))
		_fast_mms.append(_many(mesh))
	stale()
	return world

## Another floor in the same layers (a tutorial page starting over).
func hold(with_sim: RefCounted) -> void:
	sim = with_sim
	_drops.clear()
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
	if _ground_l != null:
		_ground_l.queue_redraw()

# --- the turn: where a tile is seen ---

## A point of tile space turned `q` quarters about the origin: a quarter
## takes (x, y) to (-y, x), so +x (down the screen and right) becomes +y
## (down and left) and the floor goes round clockwise under the eye.
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

## The floor's box in the art's tile space as the view is turned: its back
## corner and its size (10 by 8, or 8 by 10 a quarter round).
func seen_rect() -> Rect2:
	var a := _spin(Vector2.ZERO, turn)
	var b := _spin(Vector2(Sim.COLS, Sim.ROWS), turn)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())

## The floor's box in view units: its diamond and the earth under it.
func bounds() -> Rect2:
	var r := seen_rect()
	var box := Rect2(Art.at(r.position), Vector2.ZERO)
	for c: Vector2 in [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		box = box.expand(Art.at(c))
	box.size.y += Art.DEPTH
	return box

## The floor's box in the sim's tile space.
func tile_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(Sim.COLS, Sim.ROWS))

## The middle of a tile, in view units.
func mid(tile: Vector2i) -> Vector2:
	return seen(Vector2(tile) + MID)

## Where a station's piece stands, in view units: toward the back of its
## tile (STATION_BACK), the front left for a robot.
func station_at(kind: String) -> Vector2:
	return mid(Sim.STATIONS[kind]) + STATION_BACK

## Where robot `i` is, in view units: between the tile it stepped from and
## the one it steps to, by the sim's `alpha`.
func robot_pos(i: int) -> Vector2:
	return seen(Bots.pos(sim.robots[i], float(sim.alpha)))

## Where robot `i`'s feet are drawn: `robot_pos`, its seat beside the
## others on its tile and a belt's bed under it. For a tap on it.
func robot_at(i: int) -> Vector2:
	var at := robot_pos(i)
	if i < _seats.size():
		at += _seats[i].off as Vector2
	return at + Vector2(0.0, -_robot_lift(Bots.pos(sim.robots[i], float(sim.alpha))))

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
			if not Motion.reduce and _drops.size() < DROPS:
				_drops.append({"kind": String(e.kind), "n": int(e.n), "t": 0.0})

## How far the leaves of the market's hatch hang, 0 to 1: the most any sale
## wants.
func _hatch() -> float:
	var open := 0.0
	for d: Dictionary in _drops:
		var k := float(d.t) / SALE
		open = maxf(open, smoothstep(0.0, OPEN, k) * (1.0 - smoothstep(SHUT_FROM, SHUT_TO, k)))
	return open

# --- time ---

## `delta` seconds pass, after the sim's own step and its events.
func step(delta: float) -> void:
	# one clock for every holder: the belts' material is shared
	Art.belt_run(Time.get_ticks_msec() / 1000.0)
	_fed += delta
	_took += delta
	for d: Dictionary in _drops:
		d.t = float(d.t) + delta
	_drops = _drops.filter(func(d: Dictionary) -> bool: return float(d.t) < maxf(SALE * SHUT_TO, SALE * COIN_AT + COIN))
	if not Motion.reduce:
		for b: Dictionary in sim.robots:
			if b.charging and b.tile == Sim.BAY:
				_spun = fposmod(_spun + delta * TAU * WHEEL_TURNS, TAU)
				break
	if _belts_stale or _belt_n != sim.belts.size() + sim.kinds.size() * 1000:
		_lay_belts()
	_fill_items()
	_fill_robots(delta)
	_fill_stand()
	_flat_l.queue_redraw()
	_item_l.queue_redraw()
	_air_l.queue_redraw()

func _many(mesh: ArrayMesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = mesh
	mm.instance_count = 16
	mm.visible_instance_count = 0
	return mm

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

## Whether `tile` has a belt's bed on it: the player's or the floor's own.
func on_bed(tile: Vector2i) -> bool:
	return _bed_of.has(tile)

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
	var rows: Array = []
	for tile: Vector2i in sim.belts:
		rows.append([tile, int(sim.belts[tile]), shape(tile), sim.kinds.get(tile, "") == "fast"])
	for fx: Array in FIXED:
		rows.append([fx[0], fx[1], fx[2], false])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return depth(Vector2(a[0])) < depth(Vector2(b[0])))
	var lift := Transform2D(0.0, Art.BELT_LIFT)
	var beds := [[], [], []]
	var fast := [[], [], []]
	var unders := {}
	_shapes.clear()
	_bed_of.clear()
	for row: Array in rows:
		var tile: Vector2i = row[0]
		var bend: int = row[2]
		var quick: bool = row[3]
		var vf := seen_facing(int(row[1]))
		var key: Variant = "s"
		if bend != 0:
			if sim.belts.has(tile):
				_shapes[tile] = bend
			key = Art.DIRS[vf] + Art.DIRS[(vf + (1 if bend == 1 else 3)) % 4]
		var bed := lift * Art.flat(Vector2(seen_tile(tile)), vf)
		((fast if quick else beds)[bend] as Array).append(bed)
		if not unders.has(key):
			unders[key] = []
		(unders[key] as Array).append(Transform2D(0.0, mid(tile)))
		_bed_of[tile] = [_bed_mms[bend].mesh, quick, bed, Art.belt_under() if key is String else Art.belt_under_bend(key), Transform2D(0.0, mid(tile))]
	for i in 3:
		_fill(_bed_mms[i], beds[i])
		_fill(_fast_mms[i], fast[i])
	for key: Variant in unders:
		if not _under_mms.has(key):
			_under_mms[key] = _many(Art.belt_under() if key is String else Art.belt_under_bend(key))
	for key: Variant in _under_mms:
		_fill(_under_mms[key], unders.get(key, []))
	_ground_l.queue_redraw()
	_under_l.queue_redraw()
	_belt_l.queue_redraw()
	_fast_l.queue_redraw()

func _fill(mm: MultiMesh, xfs: Array) -> void:
	if mm.instance_count < xfs.size():
		mm.instance_count = xfs.size() * 2
	for i in xfs.size():
		mm.set_instance_transform_2d(i, xfs[i])
	mm.visible_instance_count = xfs.size()

# --- what lies and rides ---

## How far up something at `pos` (sim tile space) is drawn: on a belt's
## bed, or on the ground.
func _lifted(pos: Vector2) -> float:
	return Art.BELT_UP if _bed_of.has(Vector2i(pos.floor())) else 0.0

## How far up a robot at `pos` stands: onto a bed over the half tile it
## walks onto it, never at a jump.
func _robot_lift(pos: Vector2) -> float:
	var t := Vector2i(pos.floor())
	if not _bed_of.has(t):
		return 0.0
	var inside := pos - Vector2(t)
	var edge := minf(minf(inside.x, 1.0 - inside.x), minf(inside.y, 1.0 - inside.y))
	return Art.BELT_UP * smoothstep(0.0, 0.3, edge)

## An item into the batches by its mesh: a square, or a box by its count.
func _put(it: Dictionary, at: Vector2, tint := Color.WHITE) -> void:
	var xf := Transform2D(0.0, at)
	if String(it.get("kind", "")) == "box":
		_boxes[clampi(int(it.get("n", 0)), 0, Sim.BOX_FULL)].put(xf, tint)
	else:
		_squares.put(xf, tint)

## Where the queue's square `s` tiles back from the front is, in the sim's
## tile space: round the intake belt's bend at (0, 5) from the pad's edge,
## then up column 0.
static func _intake_at(s: float) -> Vector2:
	var pad: Vector2i = Sim.STATIONS.intake
	var corner := Vector2(pad)
	var arc := PI * 0.25
	if s <= arc:
		var a := PI * 0.5 + s / 0.5
		return corner + Vector2(cos(a), sin(a)) * 0.5
	return Vector2(0.5, float(pad.y) - (s - arc))

## What lies on the floor and rides the belts, each where the sim has it
## between two ticks, the back first; the intake's queue on its belt.
func _fill_items() -> void:
	_squares.n = 0
	for bx: Batch in _boxes:
		bx.n = 0
	var list: Array = []
	for tile: Vector2i in sim.items:
		var arr: Array = sim.items[tile]
		var lying: bool = not sim.belts.has(tile)
		for i in arr.size():
			var it: Dictionary = arr[i]
			var at := seen(item_at(tile, it))
			if lying:
				if i >= Sim.LIE.size():
					at.y -= PILE_UP * (i - Sim.LIE.size() + 1)
			else:
				# onto the bed or off it over the tick it crosses, not at a jump
				at.y -= lerpf(_lifted((it.was as Vector2).lerp(Vector2(tile) + MID, 0.02)), Art.BELT_UP, float(sim.alpha))
			list.append([at, it])
	# the queue: the front square by the pad, the rest back along the belt
	var moved := 0.0 if Motion.reduce else 1.0 - smoothstep(0.0, FEED_SLIDE, _took)
	var came := 0.0 if Motion.reduce else 1.0 - smoothstep(0.0, FEED_SLIDE, _fed)
	for k in int(sim.queue):
		var back := float(k) + moved
		if k == int(sim.queue) - 1:
			back += came
		list.append([seen(_intake_at(QUEUE_FRONT + back * QUEUE_GAP)) + Art.BELT_LIFT, {"kind": "square"}])
	list.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
	for row: Array in list:
		_put(row[1], row[0])

# --- the robots ---

## Every robot's seat beside the others on its tile, and the air over it:
## its charge and its bubble.
func _fill_robots(delta: float) -> void:
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
	for i in robots.size():
		var key := Vector2i(Bots.pos(robots[i], float(sim.alpha)).floor())
		if not by_tile.has(key):
			by_tile[key] = []
		(by_tile[key] as Array).append(i)
	var ease := 1.0 if Motion.reduce else 1.0 - exp(-SEAT_RATE * delta)
	for key: Vector2i in by_tile:
		var them: Array = by_tile[key]
		var k := them.size()
		var fore := SEAT_FORE if sim.station_at(key) != "" else Vector2.ZERO
		for j in k:
			var seat: Dictionary = _seats[them[j]]
			var want_off := Vector2((j - (k - 1) * 0.5) * SPREAD * Art.TILE.x, 0.0) + fore
			var want_size: float = SHARED[mini(k, SHARED.size()) - 1]
			var e := 1.0 if seat.new else ease
			seat.off = (seat.off as Vector2).lerp(want_off, e)
			seat.size = lerpf(float(seat.size), want_size, e)
			seat.new = false
	for i in robots.size():
		var b: Dictionary = robots[i]
		var seat: Dictionary = _seats[i]
		var xf := _robot_xf(i)
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

## Where robot `i` is drawn: its feet at `robot_at`, bobbing as it walks,
## its seat's size.
func _robot_xf(i: int) -> Transform2D:
	var b: Dictionary = sim.robots[i]
	var at := robot_at(i)
	if b.was != b.tile and not Motion.reduce:
		var along := Bots.pos(b, float(sim.alpha)).distance_to(Vector2(b.was) + MID)
		at.y -= BOB * absf(sin(along * PI))
	var s: float = (float(_seats[i].size) if i < _seats.size() else 1.0) * ROBOT_SIZE
	return Transform2D(0.0, Vector2(s, s), 0.0, at)

# --- what stands ---

## Everything that stands, [depth, wear, mesh, transform, tint] each, sorted
## from the back and cut into runs for the layers. `wear` is the material a
## run is drawn under: PLAIN, BED and BED_FAST (a belt's bed).
##
## A belt on the tile right in front of something standing (a station or a
## robot) is in the list too, over the flat one: the flat layers lie under
## everything that stands, and a thing behind a belt drew its body over the
## bed and what rode it (the user, 2026-10-12, of the market: "the market
## showed above convey even tho it was after it"). Its legs, its bed and
## its riders, a hair behind its tile's own depth.
func _fill_stand() -> void:
	var list: Array = []
	var white := Color.WHITE
	var stood := {}
	_add_stations(list, stood)
	for i in sim.robots.size():
		_add_robot(list, i, stood)
	for tile: Vector2i in sim.kinds:
		if sim.kinds[tile] != "bridge":
			continue
		# its deck over what rides under it, and on the deck what crosses
		var d := depth(Vector2(tile) + MID)
		list.append([d, PLAIN, Art.bridge(seen_facing(int(sim.belts[tile]))), Transform2D(0.0, mid(tile)), white])
		if sim.over.has(tile):
			var lane: Dictionary = sim.over[tile]
			var riders: Array = (lane.items as Array).duplicate()
			riders.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return depth(sim.item_pos(tile, x)) < depth(sim.item_pos(tile, y)))
			for i in riders.size():
				var it: Dictionary = riders[i]
				var pos: Vector2 = sim.item_pos(tile, it)
				var along := 0.5 + (pos - (Vector2(tile) + MID)).dot(Vector2(Art.DIRS[int(lane.dir)]))
				list.append([d + 0.01 + 0.001 * i, PLAIN, Art.item(it), Transform2D(0.0, seen(pos) + Vector2(0.0, -Art.bridge_lift(along))), white])
	_add_fronts(list, stood)
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var run := -1
	var wear := -1
	for e: Array in list:
		if int(e[1]) != wear:
			wear = e[1]
			run += 1
			if _pool.size() <= run:
				_runs.append([])
				_pool.append(layer(_draw_run.bind(run), null, _stand))
			(_runs[run] as Array).clear()
			if _pool[run].material != _wears[wear]:
				_pool[run].material = _wears[wear]
		(_runs[run] as Array).append(e)
	for i in range(run + 1, _pool.size()):
		(_runs[i] as Array).clear()
	for c in _pool:
		c.queue_redraw()

## The stations, each the land's own piece toward the back of its tile:
## the bay's engine with its flywheel, the heap of boxes, the tray with the
## box on it, and the market's hatch with what falls through it and the
## coin. Their seen tiles go into `stood`.
func _add_stations(list: Array, stood: Dictionary) -> void:
	var white := Color.WHITE
	var size := Vector2(STATION_K, STATION_K)
	for kind: String in Sim.STATIONS:
		stood[seen_tile(Sim.STATIONS[kind])] = true
	# the bay: the engine, its wheel turning while a robot charges on it
	var bay := Sim.STATIONS.charger as Vector2i
	var d := depth(Vector2(bay) + MID) - 0.3
	var xf := Transform2D(0.0, size, 0.0, station_at("charger"))
	list.append([d, PLAIN, Art.engine(), xf, white])
	list.append([d + 0.001, PLAIN, Art.wheel(), xf * Art.on_wall(Art._p(Art.ENGINE_WHEEL, Art.ENGINE_WHEEL_UP), Art.ENGINE_WHEEL_R, _spun, 0), white])
	# the box stack
	var stack := Sim.STATIONS.stack as Vector2i
	list.append([depth(Vector2(stack) + MID) - 0.3, PLAIN, Art.stack(), Transform2D(0.0, size, 0.0, station_at("stack")), white])
	# the pack table and the box on it
	var table := Sim.STATIONS.table as Vector2i
	d = depth(Vector2(table) + MID) - 0.3
	list.append([d, PLAIN, Art.table(), Transform2D(0.0, size, 0.0, station_at("table")), white])
	if not (sim.table as Dictionary).is_empty():
		list.append([d + 0.001, PLAIN, Art.item(sim.table, false), Transform2D(0.0, size, 0.0, station_at("table") + Art.TABLE_TOP * STATION_K), white])
	_add_market(list)

## The market on the deliver pad: its box, the two leaves of its hatch,
## what is falling through it behind the box's near side, and the coins.
func _add_market(list: Array) -> void:
	var tile := Vector2(Sim.STATIONS.deliver) + MID
	var d := depth(tile) - 0.3
	var at := station_at("deliver")
	var k := STATION_K
	var box := Transform2D(0.0, Vector2(k, k), 0.0, at)
	var white := Color.WHITE
	list.append([d, PLAIN, Art.market(), box, white])
	var open := _hatch()
	var shade := 1.0 - 0.34 * open
	for side in 2:
		list.append([d + 0.001 * (side + 1), PLAIN, Art.market_door(), box * Art.market_leaf(side, open), Color(shade, shade, shade)])
	var falling := false
	var top := at + Art.MARKET_TOP * k
	for drop: Dictionary in _drops:
		var t := float(drop.t) / SALE
		if t < FALL_TO:
			# down into the dark as the leaves give
			var fall := smoothstep(FALL_FROM, FALL_TO, t)
			fall *= fall
			var size := (1.0 - 0.2 * fall) * k
			var dark := 1.0 - 0.55 * fall
			list.append([d + 0.003, PLAIN, Art.item(drop, false),
				Transform2D(0.0, Vector2(size, size), 0.0, top + Vector2(0.0, FALL * k * fall)),
				Color(dark, dark, dark, 1.0 - smoothstep(0.6, 1.0, fall))])
			falling = true
	if falling:
		list.append([d + 0.004, PLAIN, Art.market_front(), box, white])
	for drop: Dictionary in _drops:
		var t := float(drop.t) - SALE * COIN_AT
		if t < 0.0 or t >= COIN:
			continue
		# a hop: up, a little way back down, and gone
		var c := t / COIN
		var u := c * 0.72
		var size := 0.34 * (0.5 + 0.5 * Motion.back_out(clampf(c / 0.25, 0.0, 1.0)))
		list.append([d + 0.006, PLAIN, Art.icon("coin"),
			Transform2D(0.0, Vector2(size * cos(c * TAU), size), 0.0, top + Vector2(0.0, -10.0 - COIN_UP * 4.0 * u * (1.0 - u))),
			Color(1.0, 1.0, 1.0, 1.0 - smoothstep(0.55, 1.0, c))])

## Robot `i`: its body in its tint, its face by `stuck`, what it holds in
## front of it. Its tile and the one it leaves go into `stood`.
func _add_robot(list: Array, i: int, stood: Dictionary) -> void:
	var b: Dictionary = sim.robots[i]
	var pos := Bots.pos(b, float(sim.alpha))
	var d := depth(pos) + 0.1 + 0.001 * i
	var xf := _robot_xf(i)
	list.append([d, PLAIN, Art.robot(), xf, TINTS[i % TINTS.size()]])
	var stuck := String(b.stuck)
	list.append([d + 0.0002, PLAIN, Art.face(stuck if FACES.has(stuck) else ""), xf, Color.WHITE])
	if not (b.held as Dictionary).is_empty():
		list.append([d + 0.0004, PLAIN, Art.item(b.held, false), xf * Transform2D(0.0, Vector2(Art.HELD_SCALE, Art.HELD_SCALE), 0.0, Art.HELD_AT), Color.WHITE])
	stood[seen_tile(b.tile)] = true
	stood[seen_tile(b.was)] = true

## The belts right in front of anything in `stood` (on the art's grid: the
## tile to its +x, its +y or both), drawn again among what stands with what
## rides them; each once.
func _add_fronts(list: Array, stood: Dictionary) -> void:
	var white := Color.WHITE
	var again := {}
	for tile: Vector2i in _bed_of:
		var st := seen_tile(tile)
		if not (stood.has(st + Vector2i(-1, 0)) or stood.has(st + Vector2i(0, -1)) or stood.has(st + Vector2i(-1, -1))):
			continue
		var fr: Array = _bed_of[tile]
		var d := depth(Vector2(tile) + MID)
		list.append([d - 0.304, PLAIN, fr[3], fr[4], white])
		list.append([d - 0.303, BED_FAST if fr[1] else BED, fr[0], fr[2], white])
		# a rider is its tile's from the tick it sets out for it, so the ones
		# on the belts either side are drawn again too, each once
		for near: Vector2i in [tile, tile + Art.DIRS[0], tile + Art.DIRS[1], tile + Art.DIRS[2], tile + Art.DIRS[3]]:
			if again.has(near) or not sim.items.has(near) or not sim.belts.has(near):
				continue
			again[near] = true
			for it: Dictionary in sim.items[near]:
				var up := lerpf(_lifted((it.was as Vector2).lerp(Vector2(near) + MID, 0.02)), Art.BELT_UP, float(sim.alpha))
				var at := seen(item_at(near, it))
				list.append([d - 0.302 + 0.000001 * at.y, PLAIN, Art.item(it), Transform2D(0.0, at + Vector2(0.0, -up)), white])

# --- drawing ---

## The one plate, on the floor's box as the view is turned.
func _draw_ground(ci: CanvasItem) -> void:
	var r := seen_rect()
	ci.draw_mesh(Art.plate("neutral", 0, 0, int(r.size.x), int(r.size.y)), null, Transform2D(0.0, Art.at(r.position)))

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
	for g: Array in ghosts:
		ci.draw_mesh(g[0], null, g[1], g[2] if g.size() > 2 else Color.WHITE)

func _draw_items(ci: Node2D) -> void:
	_squares.draw(ci)
	for bx: Batch in _boxes:
		bx.draw(ci)

func _draw_run(ci: CanvasItem, i: int) -> void:
	for e: Array in _runs[i]:
		ci.draw_mesh(e[2], null, e[3], e[4])

func _draw_air(ci: Node2D) -> void:
	_track.draw(ci)
	_charge.draw(ci)
	for kind: String in _bubbles:
		(_bubbles[kind] as Batch).draw(ci)
