extends RefCounted

## Factory, as pure data: a top-down floor of ten by eight tiles with five
## stations on it (an intake that queues grey squares, a stack of empty
## boxes, a pack table, a deliver pad that sells, a charging bay), the items
## that lie on it or ride its belts, and the belts the player lays. Nothing
## here draws, reads the clock or touches a node: whoever holds it (the
## screen, the tab's card, the probe) steps it, drains `events` and draws
## from what it reads. It is deterministic from its seed and its save, and
## **nothing happens while it is not stepped**: the save keeps durations
## (ticks), never a time of day.
## Spec docs/superpowers/specs/2026-10-20-factory-rewired-design.md.
##
## ---------------------------------------------------------------------------
## THE API, for the view
##
## Geometry. A tile is a Vector2i, (0, 0) the top left, +x right and +y down
## on screen; the floor is COLS x ROWS. A facing is an int 0..3 = +x, +y, -x,
## -y (`DIRS`); a quarter clockwise is (f + 1) % 4. Positions handed out as
## Vector2 are in tile units, a tile's middle at tile + (0.5, 0.5). Column 0
## is drawn as the intake belt and column 9 as the deliver belt: the view's,
## not belts the sim moves things along (the intake is a queue, the deliver
## pad a sale).
##
## Holding it.
##   Sim.new(seed)            a new floor (the same as new_floor(seed))
##   new_floor(seed)          throws the floor away for a new one
##   step(delta)              delta clamped to 0.25 s, whole 10 Hz ticks run
##   alpha: float             0..1, the part of a tick left over, for drawing
##   tick_n: int              ticks run since the floor began
##   events: Array            Dictionaries with a `type`; the holder clears it
##   dirty: bool              something changed since the last save()
##   save()                   writes `Sim.path` (static, "user://factory.cfg")
##   load_saved() -> bool     reads it into this sim; false: no file, a bad
##                            one or another VERSION, and the sim is left as
##                            it was (the holder starts new and overwrites)
##   picked: String           the drawer's picked belt, kept for the view
##
## Money.
##   coins, earned: int       earned: every coin a sale ever paid
##   bin: Dictionary          part -> spares (robots' parts, Task 3)
##   unlocked(kind) -> bool   a belt kind: open (milestone 1, Task 4)
##   price(kind) -> int       PRICE: flat, however many are laid
##   no_cost: bool            everything `price` knows costs nothing: the
##                            debug button's, never kept in the save
##
## The floor.
##   stations: Dictionary     tile -> "charger" | "intake" | "stack" |
##                            "table" | "deliver" (STATIONS turned round)
##   station_at(tile) -> String          "" on open floor
##   on_floor(tile) -> bool   inside COLS x ROWS
##   tile_free(tile) -> bool  open floor: on it, no station, no belt
##   queue: int               squares waiting at the intake pad, QUEUE_MOST
##                            at most, one more every FEED_TICKS
##   table: Dictionary        {} or the box on the pack table
##   robots: Array            (Task 3)
##
## An item is {id, kind "square" | "box", n (a box's squares, 0..BOX_FULL),
## at, from, was}. On a belt `at` (0..1) runs along the tile and `from` is
## the facing it came in by (-1: it began here), so a side load is drawn
## round the corner. Off a belt it lies, in a stack: index 0 the bottom.
##   items: Dictionary        tile -> Array of items; on a belt index 0 is
##                            the front one
##   belts: Dictionary        tile -> facing
##   kinds: Dictionary        tile -> "fast" | "bridge", for a belt that is
##                            not the plain one; belt_kind(tile) says any
##   over: Dictionary         tile -> {dir, items}: what rides over a bridge
##   outs(tile), feeds(from, to)        where a belt hands on to
##   item_pos(tile, item) -> Vector2    where to draw it now (uses `alpha`)
##   front_of_tile(tile) -> Dictionary  a belt's front item, {} for none
##
## A hand (a robot's Pick and Release, Task 3; a harness's).
##   gives(tile) -> Dictionary          what a Pick would take now, {} for
##                            nothing: the intake's next square while
##                            `queue` > 0, a new empty box at the stack, the
##                            table's box only full, a belt's front item, the
##                            top of a stack lying there
##   take(tile) -> Dictionary           does it
##   takes(tile, item) -> bool          would a Release land: the table an
##                            empty box when bare, a square while its box has
##                            room; the deliver pad anything; a belt with room
##                            at its back; anywhere else on the floor anything
##   put(tile, item) -> bool            does it: the table's rule, the
##                            deliver pad's sale, onto a belt, else it lies
##
## Acting. Each returns whether it did anything; when it did not it pushes
## {type "refused", why, tile}.
##   can_lay(tile)            fits a belt (coins not looked at): on the
##                            floor, never on a station nor in column 0 or 9
##   lay_belt(tile, facing, kind)       "belt" 1 coin, "fast" 4, "bridge" 25;
##                            on a belt of that kind already there it only
##                            re-faces
##   turn(tile)               a belt a quarter clockwise
##   flip_line(tile)          the line through it turned round
##   line_through(tile), line_tiles(tile, section)
##   sell(tile), sell_belts(tiles), sell_price(tile)
##
## Events (each has `type`; `tile` where there is one).
##   queued {tile, queue}             a square onto the intake's queue
##   took {tile, id, kind}            off a tile into a hand
##   set {tile, id}                   an empty box onto the table
##   packed {tile, id, n}             a square into the table's box
##   lay {tile, id, kind}             an item down on the floor
##   sale {tile, kind, n, amount, coins}
##   laid {tile, facing, kind}  turned {tile, facing}
##   flipped {tile, tiles}            a line of belts turned round
##   sold_back {tile, kind, amount, items}
##   sold_line {tile, tiles, amount}  belts sold back in one go
##   refused {why, tile}
## ---------------------------------------------------------------------------

## The sim's tick, real seconds.
const TICK := 0.1
## The longest frame a holder steps by: a longer one is a hitch, not play.
const STEP_MOST := 0.25
const EPS := 0.000001
const VERSION := 5

const COLS := 10
const ROWS := 8
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const NONE := Vector2i(-99999, -99999)

## The floor's stations, each one tile.
const STATIONS := {"charger": Vector2i(1, 1), "intake": Vector2i(1, 5), "stack": Vector2i(4, 1),
	"table": Vector2i(4, 5), "deliver": Vector2i(8, 5)}
## The charging bay: the one place a robot charges.
const BAY := Vector2i(1, 1)
## The intake: squares it holds queued at most, and the ticks between two.
const QUEUE_MOST := 6
const FEED_TICKS := 10
## The squares a box holds, and what the deliver pad pays: a full box, and a
## loose square (a box short of full pays a coin a square in it).
const BOX_FULL := 4
const PAY_FULL := 6
const PAY_SQUARE := 1
const ITEM_KINDS := ["square", "box"]

## What a belt costs, the first and every one after (the user, 2026-10-12:
## "they stay flat").
const PRICE := {"belt": 1, "fast": 4, "bridge": 25}
## What is laid like a belt and carries like one: the plain belt, the fast
## one (twice the speed, the same spacing) and the bridge: a belt tile with a
## second belt over it, across it, so two lines cross. What comes along its
## facing goes under; what comes in by a side goes over and leaves by the
## other side.
const BELTS := ["belt", "fast", "bridge"]
## A belt kind laid one tile at a time, where the finger is.
const ONE_TILE := ["bridge"]

## A belt: a tile in two real seconds, two items a tile, never nearer than
## half a tile.
const BELT_SECONDS := 2.0
const FAST_SECONDS := 1.0
const GAP := 0.5
const ROOM := 2
## Where the items of a stack lie, off the tile's middle, the bottom first;
## past the last they lie on it.
const LIE: Array[Vector2] = [Vector2(-0.16, 0.1), Vector2(0.16, -0.1)]

## A harness points this elsewhere before it makes a sim.
static var path := "user://factory.cfg"

var floor_seed := 0
var coins := 0
var earned := 0
var queue := 0
var table := {}
var stations := {}
var belts := {}
## A belt tile that is not a plain belt: tile -> "fast" | "bridge".
var kinds := {}
## What rides over a bridge: tile -> {dir (the facing it travels), items
## (as a belt's, the front one first)}.
var over := {}
var items := {}
var robots: Array = []
var bin := {}
var tick_n := 0
var events: Array = []
var dirty := false
var alpha := 0.0
var picked := ""
## A debug switch (the user, 2026-10-12: "a button to make buildings price
## 0, so I can debug on phone"): belts cost nothing while it is on. It is the
## holder's to set and is not kept: a floor read back has it off.
var no_cost := false

var _rng := RandomNumberGenerator.new()
var _acc := 0.0
var _next_id := 1
var _turn := {}          # fed tile -> the belt tile that fed it last
var _order: Array = []
var _order_stale := true

func _init(with_seed: int = 0) -> void:
	new_floor(with_seed)

# --- the floor ---

func new_floor(with_seed: int) -> void:
	floor_seed = with_seed
	_rng.seed = with_seed
	coins = 0
	earned = 0
	queue = 0
	table = {}
	belts = {}
	kinds = {}
	over = {}
	items = {}
	robots = []
	bin = {"gripper": 1}
	tick_n = 0
	events = []
	picked = ""
	alpha = 0.0
	_acc = 0.0
	_next_id = 1
	_turn = {}
	_order_stale = true
	_stand_stations()
	dirty = true

func _stand_stations() -> void:
	stations = {}
	for kind: String in STATIONS:
		stations[STATIONS[kind]] = kind

func station_at(tile: Vector2i) -> String:
	return String(stations.get(tile, ""))

func on_floor(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < COLS and tile.y >= 0 and tile.y < ROWS

## Open floor: on it, no station, no belt.
func tile_free(tile: Vector2i) -> bool:
	return on_floor(tile) and not stations.has(tile) and not belts.has(tile)

## Belts open at milestone 1 (Task 4); until then every kind is.
func unlocked(kind: String) -> bool:
	return BELTS.has(kind)

func price(kind: String) -> int:
	return 0 if no_cost else int(PRICE.get(kind, 0))

# --- a hand: Pick and Release ---

## What a Pick on `tile` would take now; {} for nothing. A new square or
## box is handed with the id it would get.
func gives(tile: Vector2i) -> Dictionary:
	if not on_floor(tile):
		return {}
	match station_at(tile):
		"intake":
			if queue > 0:
				return _new_item("square", _mid(tile), false)
		"stack":
			return _new_item("box", _mid(tile), false)
		"table":
			return table if not table.is_empty() and int(table.n) >= BOX_FULL else {}
		"deliver":
			return {}
	if belts.has(tile):
		return front_of_tile(tile)
	var arr: Array = items.get(tile, [])
	return {} if arr.is_empty() else arr.back()

## Does the Pick: the item off `tile`, {} for nothing.
func take(tile: Vector2i) -> Dictionary:
	if gives(tile).is_empty():
		return {}
	var it := {}
	match station_at(tile):
		"intake":
			if queue > 0:
				queue -= 1
				it = _new_item("square", _mid(tile), true)
		"stack":
			it = _new_item("box", _mid(tile), true)
		"table":
			it = table
			it.was = item_pos(tile, it)
			table = {}
	if it.is_empty() and belts.has(tile):
		var lane: Array = items.get(tile, [])
		if lane.is_empty() and over.has(tile):
			lane = over[tile].items
		it = lane[0]
		# it leaves the hand's way from where it is drawn now
		it.was = item_pos(tile, it)
		lane.pop_front()
		if items.has(tile) and (items[tile] as Array).is_empty():
			items.erase(tile)
		it.erase("over")
		it.erase("to")
	elif it.is_empty():
		it = (items[tile] as Array).back()
		it.was = item_pos(tile, it)
		(items[tile] as Array).pop_back()
		if (items[tile] as Array).is_empty():
			items.erase(tile)
	events.append({"type": "took", "tile": tile, "id": it.id, "kind": it.kind})
	dirty = true
	return it

## Whether a Release of `it` on `tile` would land now.
func takes(tile: Vector2i, it: Dictionary) -> bool:
	if not on_floor(tile) or it.is_empty() or not ITEM_KINDS.has(it.get("kind", "")):
		return false
	match station_at(tile):
		"table":
			if table.is_empty():
				return it.kind == "box" and int(it.get("n", 0)) == 0
			return it.kind == "square" and int(table.n) < BOX_FULL
		"deliver":
			return true
	if belts.has(tile):
		return _belt_room(tile) >= 0.0
	return true

## Does the Release: the table sets an empty box down or packs a square into
## its box, the deliver pad sells, a belt carries it on, anywhere else it
## lies on the stack there. False, and nothing moved, when it would not land.
func put(tile: Vector2i, it: Dictionary) -> bool:
	if not takes(tile, it):
		return false
	match station_at(tile):
		"table":
			if table.is_empty():
				table = it
				table.n = 0
				_still(table, tile)
				events.append({"type": "set", "tile": tile, "id": it.id})
			else:
				table.n = int(table.n) + 1
				events.append({"type": "packed", "tile": tile, "id": table.id, "n": table.n})
		"deliver":
			_sell(it)
		_:
			if belts.has(tile):
				_belt_drop(tile, it)
			else:
				_lay_down(tile, it, it.get("was", Vector2.INF))
				events.append({"type": "lay", "tile": tile, "id": it.id, "kind": it.kind})
	dirty = true
	return true

## What the deliver pad pays for `it`, paid: a full box PAY_FULL, a box a
## coin a square in it, a loose square PAY_SQUARE.
func _sell(it: Dictionary) -> int:
	var n := int(it.get("n", 0))
	var amount := PAY_SQUARE
	if it.kind == "box":
		amount = PAY_FULL if n >= BOX_FULL else n
	coins += amount
	earned += amount
	events.append({"type": "sale", "tile": STATIONS.deliver, "kind": it.kind, "n": n, "amount": amount, "coins": coins})
	dirty = true
	return amount

## The intake's queue: one square every FEED_TICKS, QUEUE_MOST at most.
func _feed() -> void:
	if tick_n % FEED_TICKS != 0 or queue >= QUEUE_MOST:
		return
	queue += 1
	events.append({"type": "queued", "tile": STATIONS.intake, "queue": queue})

# --- belts ---

func can_lay(tile: Vector2i) -> bool:
	return _lay_why(tile) == ""

func _lay_why(tile: Vector2i) -> String:
	if not on_floor(tile):
		return "off"
	if stations.has(tile):
		return "station"
	# the drawn intake and deliver belts (robots still walk there)
	if tile.x == 0 or tile.x == COLS - 1:
		return "edge"
	return ""

## The kind of the belt on `tile`: "belt", "fast", "bridge"; "" for none.
func belt_kind(tile: Vector2i) -> String:
	return String(kinds.get(tile, "belt")) if belts.has(tile) else ""

## Real seconds the belt on `tile` takes to carry a thing across it.
func belt_seconds(tile: Vector2i) -> float:
	return FAST_SECONDS if kinds.get(tile, "") == "fast" else BELT_SECONDS

## A belt of `kind` on `tile` facing `facing`. On a belt of that kind already
## there it re-faces it for nothing, which is what a finger dragged across
## laid belts means; on one of another kind it becomes this kind for the
## difference in price (given back when it is the cheaper), faced as told.
func lay_belt(tile: Vector2i, facing: int, kind := "belt") -> bool:
	if facing < 0 or facing > 3:
		return _no("facing", tile)
	if not BELTS.has(kind):
		return _no("kind", tile)
	if not unlocked(kind):
		return _no("locked", tile)
	if belts.has(tile):
		var was := belt_kind(tile)
		if was != kind:
			var more := price(kind) - price(was)
			if coins < more:
				return _no("coins", tile)
			coins -= more
			_set_kind(tile, kind)
			belts[tile] = facing
			_order_stale = true
			for it: Dictionary in items.get(tile, []):
				it.from = -1
				it.erase("to")
				it.was = _pos(tile, it)
			events.append({"type": "laid", "tile": tile, "facing": facing, "kind": kind})
			dirty = true
			return true
		if belts[tile] == facing:
			return _no("same", tile)
		_face_belt(tile, facing)
		return true
	var why := _lay_why(tile)
	if why != "":
		return _no(why, tile)
	if coins < price(kind):
		return _no("coins", tile)
	coins -= price(kind)
	belts[tile] = facing
	_set_kind(tile, kind)
	_order_stale = true
	_settle(tile)
	events.append({"type": "laid", "tile": tile, "facing": facing, "kind": kind})
	dirty = true
	return true

func _set_kind(tile: Vector2i, kind: String) -> void:
	if kind != "bridge":
		_drop_over(tile)
	if kind == "belt":
		kinds.erase(tile)
	else:
		kinds[tile] = kind

## What rode over a bridge that is one no more, or was turned: it lies on
## the nearest open floor.
func _drop_over(tile: Vector2i) -> void:
	if not over.has(tile):
		return
	var lane: Dictionary = over[tile]
	over.erase(tile)
	for it: Dictionary in lane.items:
		it.erase("over")
		_spill([tile], it)

func _face_belt(tile: Vector2i, facing: int) -> void:
	_face_quiet(tile, facing)
	events.append({"type": "turned", "tile": tile, "facing": facing})

func _face_quiet(tile: Vector2i, facing: int) -> void:
	_drop_over(tile)
	belts[tile] = facing
	_order_stale = true
	for it: Dictionary in items.get(tile, []):
		it.from = -1
		it.erase("to")
		it.was = _pos(tile, it)
	dirty = true

## What lies on a tile takes its places on the belt just laid there, or on
## the floor a belt just left. More than a belt holds lies on the nearest
## open floor.
func _settle(tile: Vector2i) -> void:
	if not items.has(tile):
		return
	var arr: Array = items[tile]
	if belts.has(tile):
		while arr.size() > ROOM:
			_spill([tile], arr.pop_back())
	for i in arr.size():
		var it: Dictionary = arr[i]
		it.at = 0.5 - GAP * i if belts.has(tile) else 0.5
		it.from = -1
		it.erase("to")
		it.was = _pos(tile, it)

func turn(tile: Vector2i) -> bool:
	if not belts.has(tile):
		return _no("nothing", tile)
	_face_belt(tile, (int(belts[tile]) + 1) % 4)
	return true

## The tiles a belt hands on to: the one ahead, and for a bridge the way its
## last thing over it went too.
func outs(tile: Vector2i) -> Array[Vector2i]:
	var f: int = belts[tile]
	if kinds.get(tile, "") == "bridge" and over.has(tile):
		return [tile + DIRS[f], tile + DIRS[int(over[tile].dir)]]
	return [tile + DIRS[f]]

## Whether what is on `from` goes into `to` next: a belt pointing at it.
func feeds(from: Vector2i, to: Vector2i) -> bool:
	return belts.has(from) and outs(from).has(to)

## How many belts hand on into `tile`.
func _feeders(tile: Vector2i) -> int:
	var n := 0
	for d in 4:
		if feeds(tile + DIRS[d], tile):
			n += 1
	return n

## Whether the belt on `tile` is a plain one a line runs through (a belt or
## a fast belt; a bridge ends a line).
func _plain(tile: Vector2i) -> bool:
	return belts.has(tile) and not ONE_TILE.has(belt_kind(tile))

## The belts of the line through the plain belt on `tile`, in the way
## things ride it, stopping at a join (a belt fed by two), a bridge or
## anything not a belt (Tally's rule, the user, 2026-10-19: "stop on joins or
## cross to avoid issue"). [] when `tile` holds no plain belt.
func line_through(tile: Vector2i) -> Array:
	if not _plain(tile):
		return []
	var seen := {tile: true}
	var back: Array = []
	var cur := tile
	while _feeders(cur) == 1:
		var prev := NONE
		for d in 4:
			if feeds(cur + DIRS[d], cur):
				prev = cur + DIRS[d]
		if not _plain(prev) or seen.has(prev):
			break
		seen[prev] = true
		back.push_front(prev)
		cur = prev
	var line := back
	line.append(tile)
	cur = tile
	while true:
		var nxt: Vector2i = cur + DIRS[int(belts[cur])]
		if not _plain(nxt) or seen.has(nxt) or _feeders(nxt) != 1:
			break
		seen[nxt] = true
		line.append(nxt)
		cur = nxt
	return line

## The belts of the line through `tile`; with `section`, only its straight
## run about `tile`, to the turns either side (a corner belt is the run it
## turns into).
func line_tiles(tile: Vector2i, section := false) -> Array:
	var line := line_through(tile)
	if line.is_empty() or not section:
		return line
	var at := line.find(tile)
	var f: int = belts[tile]
	var lo := at
	var hi := at
	while lo > 0 and int(belts[line[lo - 1]]) == f:
		lo -= 1
	while hi < line.size() - 1 and int(belts[line[hi + 1]]) == f:
		hi += 1
	return line.slice(lo, hi + 1)

## The line through the belt on `tile` turned round: each belt runs back to
## the one that fed it; the first, now the last, the way it came, or into
## the table or the deliver pad beside it.
func flip_line(tile: Vector2i) -> bool:
	var line := line_through(tile)
	if line.is_empty():
		return _no("nothing", tile)
	var fs: Array = []
	for k in line.size():
		if k == 0:
			var t0: Vector2i = line[0]
			var f0 := (int(belts[t0]) + 2) % 4
			var after: Vector2i = line[1] if line.size() > 1 else NONE
			for d in 4:
				var to: Vector2i = t0 + DIRS[d]
				if to != after and _takes_in(to) and not _takes_in(t0 + DIRS[f0]):
					f0 = d
			fs.append(f0)
		else:
			fs.append(DIRS.find((line[k - 1] as Vector2i) - (line[k] as Vector2i)))
	for k in line.size():
		_face_quiet(line[k], int(fs[k]))
	events.append({"type": "flipped", "tile": tile, "tiles": line})
	return true

## Whether `tile` is somewhere a belt delivers into but a belt: the table,
## the deliver pad.
func _takes_in(tile: Vector2i) -> bool:
	var s := station_at(tile)
	return s == "table" or s == "deliver"

## The belts, front of each chain first: a belt comes after every belt it
## feeds, so one pass moves a chain as one and no item moves twice. A ring of
## belts has no front and is cut where the walk meets itself.
func _belt_order() -> Array:
	if not _order_stale:
		return _order
	_order = []
	var done := {}
	var keys := belts.keys()
	keys.sort()
	for k: Vector2i in keys:
		if done.has(k):
			continue
		# a walk down every way out, a belt written once all it feeds are
		var stack: Array = [[k, 0]]
		done[k] = true
		while not stack.is_empty():
			var top: Array = stack.back()
			var ways := outs(top[0])
			var went := false
			while int(top[1]) < ways.size():
				var n: Vector2i = ways[int(top[1])]
				top[1] = int(top[1]) + 1
				if belts.has(n) and not done.has(n):
					done[n] = true
					stack.append([n, 0])
					went = true
					break
			if not went:
				_order.append(top[0])
				stack.pop_back()
	_order_stale = false
	return _order

func _move_belts() -> void:
	for b: Vector2i in _belt_order():
		if items.has(b):
			var arr: Array = items[b]
			_run_lane(b, arr, belts[b])
			if arr.is_empty():
				items.erase(b)
		if over.has(b):
			_run_lane(b, over[b].items, int(over[b].dir))

## One lane of the belt on `b` goes on a tick: `arr` its things, the front
## one first, travelling `f`.
func _run_lane(b: Vector2i, arr: Array, f: int) -> void:
	var v := TICK / belt_seconds(b)
	var ahead := INF
	var i := 0
	while i < arr.size():
		var it: Dictionary = arr[i]
		var nat: float = it.at + v
		if i == 0 and nat >= 1.0 - EPS:
			var front := b + DIRS[f]
			if not _yields(b, front) and _enter(front, it, f, maxf(nat - 1.0, 0.0)):
				arr.remove_at(0)
				_turn[front] = b
				continue
			# nothing ahead takes it: it waits at the belt's end
			nat = 1.0
		it.at = maxf(it.at, minf(nat, ahead - GAP))
		ahead = it.at
		i += 1

## Two belts feeding one tile take turns when both have an item at the end:
## the one that fed it last lets the other go.
func _yields(b: Vector2i, fed: Vector2i) -> bool:
	if _turn.get(fed, NONE) != b:
		return false
	for d in 4:
		var other := fed - DIRS[d]
		if other == b or not belts.has(other) or not items.has(other):
			continue
		if int(belts[other]) != d:
			continue
		var first: Dictionary = (items[other] as Array)[0]
		if float(first.at) + TICK / belt_seconds(other) >= 1.0 - EPS:
			return true
	return false

## An item going into `tile` by facing `f`: a belt whose back half is clear,
## or a station as a Release there would (the table takes a square into a box
## with room, the deliver pad sells). The intake pad, the bay, the stack and
## open floor take nothing off a belt: it waits at the belt's end. `ask` only
## asks: nothing is moved.
func _enter(tile: Vector2i, it: Dictionary, f: int, carry: float, ask := false) -> bool:
	if belts.has(tile):
		var arr: Array = items.get(tile, [])
		var lane := {}
		if kinds.get(tile, "") == "bridge" and f != int(belts[tile]):
			# by a side: over it, the way it came, unless something is
			# crossing the other way; against its facing, nothing
			if f == (int(belts[tile]) + 2) % 4:
				return false
			lane = over.get(tile, {"dir": f, "items": []})
			arr = lane.items
			if not arr.is_empty() and int(lane.dir) != f:
				return false
		if arr.size() >= ROOM:
			return false
		var at := carry
		if not arr.is_empty():
			var rear: float = arr[arr.size() - 1].at
			if rear < GAP - EPS:
				return false
			at = minf(carry, rear - GAP)
		if ask:
			return true
		it.at = maxf(at, 0.0)
		it.from = f
		it.erase("to")
		arr.append(it)
		if lane.is_empty():
			it.erase("over")
			items[tile] = arr
		else:
			it.over = true
			if int(lane.dir) != f or not over.has(tile):
				_order_stale = true
			lane.dir = f
			over[tile] = lane
		return true
	if not _takes_in(tile) or not takes(tile, it):
		return false
	if ask:
		return true
	it.erase("over")
	return put(tile, it)

# --- items ---

## A new item of `kind`; `keep` false only says what it would be (its id is
## the next, not taken).
func _new_item(kind: String, was: Vector2, keep: bool) -> Dictionary:
	var it := {"id": _next_id, "kind": kind, "at": 0.5, "from": -1, "was": was}
	if kind == "box":
		it.n = 0
	if keep:
		_next_id += 1
	return it

func _mid(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)

## An item come to rest on `tile` off any belt: it is drawn there from now.
func _still(it: Dictionary, tile: Vector2i) -> void:
	it.at = 0.5
	it.from = -1
	it.erase("to")
	it.erase("over")
	if not (it.get("was") is Vector2) or it.was == Vector2.INF:
		it.was = _mid(tile)

## Where an item is at the end of the tick, in tile units.
func _pos(tile: Vector2i, it: Dictionary) -> Vector2:
	var c := _mid(tile)
	# the table's box sits in its middle (nothing else lies on the table)
	if station_at(tile) == "table":
		return c
	if not belts.has(tile):
		var i: int = (items.get(tile, []) as Array).find(it)
		return c + LIE[clampi(i, 0, LIE.size() - 1)]
	var f: int = belts[tile]
	var at: float = it.at
	var from: int = it.from
	if it.get("over", false) and over.has(tile):
		return c + Vector2(DIRS[int(over[tile].dir)]) * (at - 0.5)
	if at < 0.5 and from >= 0 and from != f:
		return c - Vector2(DIRS[from]) * (0.5 - at)
	return c + Vector2(DIRS[f]) * (at - 0.5)

## Where to draw an item now: between where the last tick left it and where
## this one did, by `alpha`.
func item_pos(tile: Vector2i, it: Dictionary) -> Vector2:
	return (it.was as Vector2).lerp(_pos(tile, it), alpha)

## The front item of the belt on `tile` (under a bridge first, then over
## it); {} for none.
func front_of_tile(tile: Vector2i) -> Dictionary:
	if not belts.has(tile):
		return {}
	var arr: Array = items.get(tile, [])
	if arr.is_empty() and over.has(tile):
		arr = over[tile].items
	return {} if arr.is_empty() else arr[0]

## How far along the belt on `tile` a thing dropped onto it from above
## lands: mid tile if the belt is empty there, else behind what rides it if
## that leaves the gap; -1.0 when it is full.
func _belt_room(tile: Vector2i) -> float:
	var arr: Array = items.get(tile, [])
	if arr.size() >= ROOM:
		return -1.0
	if arr.is_empty():
		return 0.5
	var rear: float = arr[arr.size() - 1].at
	if rear < GAP - EPS:
		return -1.0
	return maxf(minf(0.5, rear - GAP), 0.0)

## Onto a belt from above (a Release, a harness's `put`).
func _belt_drop(tile: Vector2i, it: Dictionary) -> bool:
	var at := _belt_room(tile)
	if at < 0.0:
		return false
	var arr: Array = items.get(tile, [])
	it.at = at
	it.from = -1
	it.erase("to")
	it.erase("over")
	if not (it.get("was") is Vector2) or it.was == Vector2.INF:
		it.was = _mid(tile)
	arr.append(it)
	items[tile] = arr
	return true

## `it` onto the stack lying on `tile`; drawn from `was` (INF: where it lies).
func _lay_down(tile: Vector2i, it: Dictionary, was: Variant) -> void:
	var arr: Array = items.get(tile, [])
	it.at = 0.5
	it.from = -1
	it.erase("to")
	it.erase("over")
	arr.append(it)
	items[tile] = arr
	it.was = _pos(tile, it) if not (was is Vector2) or was == Vector2.INF else was

## Nothing is destroyed: an item with nowhere of its own lies on the first of
## `own` that is open floor, else on the nearest open floor to the first of
## `own` (or the middle of the floor).
func _spill(own: Array, it: Dictionary) -> Vector2i:
	for t: Vector2i in own:
		if tile_free(t):
			_lay_down(t, it, Vector2.INF)
			return t
	var from: Vector2i = own[0] if not own.is_empty() else Vector2i(COLS, ROWS) / 2
	var best := NONE
	var best_d := 0
	for y in ROWS:
		for x in COLS:
			var t := Vector2i(x, y)
			if not tile_free(t):
				continue
			var d := (t - from).length_squared()
			if best == NONE or d < best_d:
				best = t
				best_d = d
	if best == NONE:
		# a floor with no open tile left: on the tile itself rather than gone
		best = from
	_lay_down(best, it, Vector2.INF)
	return best

func sell_price(tile: Vector2i) -> int:
	return price(belt_kind(tile)) if belts.has(tile) else 0

## A belt back for its price. What it carried lies there.
func sell(tile: Vector2i) -> bool:
	if not belts.has(tile):
		return _no("nothing", tile)
	var kind := belt_kind(tile)
	var back := _sell_belt(tile)
	events.append({"type": "sold_back", "tile": tile, "kind": kind, "amount": back, "items": (items.get(tile, []) as Array).size()})
	return true

## The belt on `tile` back for its price, with no event; what it carried
## lies there. Returns the coins given back.
func _sell_belt(tile: Vector2i) -> int:
	var back := price(belt_kind(tile))
	belts.erase(tile)
	_set_kind(tile, "belt")
	_order_stale = true
	_turn.erase(tile)
	coins += back
	_settle(tile)
	dirty = true
	return back

## The belts on `tiles` sold back in one go, one event for them all.
func sell_belts(tiles: Array) -> bool:
	var back := 0
	var sold: Array = []
	for t: Vector2i in tiles:
		if belts.has(t):
			back += _sell_belt(t)
			sold.append(t)
	if sold.is_empty():
		return _no("nothing", tiles[0] if not tiles.is_empty() else NONE)
	events.append({"type": "sold_line", "tile": sold[0], "tiles": sold, "amount": back})
	return true

# --- the tick ---

## Steps the floor by a frame. Whole ticks run; what is left over is `alpha`.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	_acc += minf(delta, STEP_MOST)
	while _acc >= TICK - EPS:
		_acc = maxf(_acc - TICK, 0.0)
		_tick()
	alpha = clampf(_acc / TICK, 0.0, 1.0)

func _tick() -> void:
	tick_n += 1
	for tile: Vector2i in items:
		for it: Dictionary in items[tile]:
			it.was = _pos(tile, it)
	for tile: Vector2i in over:
		for it: Dictionary in over[tile].items:
			it.was = _pos(tile, it)
	if not table.is_empty():
		table.was = _pos(STATIONS.table, table)
	_feed()
	_move_belts()
	_run_robots()
	_pace()
	dirty = true

## The robots walk their programs a tick (Task 3).
func _run_robots() -> void:
	pass

## The pace window and the milestones' hold (Task 4).
func _pace() -> void:
	pass

func _no(why: String, tile: Vector2i) -> bool:
	events.append({"type": "refused", "why": why, "tile": tile})
	return false

# --- keeping ---

## Everything the floor is, as one Dictionary: what the save holds and what
## a harness compares. Durations only, no time of day.
func pack() -> Dictionary:
	return {
		"version": VERSION, "seed": floor_seed, "rng": _rng.state, "coins": coins, "earned": earned,
		"acc": _acc, "next_id": _next_id, "picked": picked, "tick_n": tick_n, "queue": queue,
		"table": table.duplicate(true), "belts": belts.duplicate(true), "kinds": kinds.duplicate(true),
		"over": over.duplicate(true), "items": items.duplicate(true), "robots": robots.duplicate(true),
		"bin": bin.duplicate(true), "turn": _turn.duplicate(true),
	}

## The floor goes into the file as bytes (base64), not as text: a float
## written as text comes back a last digit off (101.00000000000449 read
## 101.00000000000448 on 2026-10-10), and a floor read back must play on
## exactly as the floor saved would.
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("factory", "version", VERSION)
	cfg.set_value("factory", "state", Marshalls.variant_to_base64(pack()))
	cfg.save(path)
	dirty = false

## Reads `path` into this sim. False, and the sim untouched, when there is no
## file or it is not a floor this version wrote: a land of version 4 (the
## forests and the market) is not read, and the holder starts a new floor
## that the next save writes over it (the user, 2026-10-20: wiped quietly).
func load_saved() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	if cfg.get_value("factory", "version", VERSION) != VERSION or not cfg.has_section_key("factory", "state"):
		return false
	var kept: Variant = cfg.get_value("factory", "state")
	if not (kept is String) or (kept as String).is_empty():
		return false
	var bytes := Marshalls.base64_to_raw(kept)
	# bytes that do not open as a Dictionary are not handed to the decoder
	if bytes.size() < 4 or (bytes.decode_u32(0) & 0xFF) != TYPE_DICTIONARY:
		return false
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary) or not _sound(d):
		return false
	_unpack(d)
	return true

# What a kept file says is trusted only as far as its shapes: every table is
# the kind of thing it should be and every row has its keys, so no file
# raises an error on load. Whether figures that pass are true is not asked.
const _SHAPES := {
	"version": TYPE_INT, "seed": TYPE_INT, "rng": TYPE_INT, "coins": TYPE_INT, "earned": TYPE_INT,
	"acc": TYPE_FLOAT, "next_id": TYPE_INT, "picked": TYPE_STRING, "tick_n": TYPE_INT, "queue": TYPE_INT,
	"table": TYPE_DICTIONARY, "belts": TYPE_DICTIONARY, "kinds": TYPE_DICTIONARY, "over": TYPE_DICTIONARY,
	"items": TYPE_DICTIONARY, "robots": TYPE_ARRAY, "bin": TYPE_DICTIONARY, "turn": TYPE_DICTIONARY,
}
const _ITEM_KEYS := ["id", "kind", "at", "from", "was"]

static func _sound_item(it: Variant) -> bool:
	if not (it is Dictionary) or not it.has_all(_ITEM_KEYS) or not ITEM_KINDS.has(it.kind) or not (it.id is int) \
			or not (it.was is Vector2) or not (it.from is int) or it.from < -1 or it.from > 3:
		return false
	return it.kind != "box" or (it.get("n") is int and it.n >= 0 and it.n <= BOX_FULL)

static func _sound(d: Dictionary) -> bool:
	for key: String in _SHAPES:
		if not d.has(key) or typeof(d[key]) != _SHAPES[key]:
			return false
	if d.version != VERSION or d.coins < 0 or d.queue < 0 or d.queue > QUEUE_MOST or d.tick_n < 0:
		return false
	if not d.table.is_empty() and (not _sound_item(d.table) or d.table.kind != "box"):
		return false
	for t: Variant in d.belts:
		if not (t is Vector2i) or not (d.belts[t] is int) or d.belts[t] < 0 or d.belts[t] > 3:
			return false
	for t: Variant in d.kinds:
		if not (t is Vector2i) or not d.belts.has(t) or not BELTS.has(d.kinds[t]):
			return false
	for t: Variant in d.over:
		var lane: Variant = d.over[t]
		if not (t is Vector2i) or d.kinds.get(t, "") != "bridge" or not (lane is Dictionary) or not lane.has_all(["dir", "items"]) \
				or not (lane.dir is int) or lane.dir < 0 or lane.dir > 3 or not (lane.items is Array):
			return false
		for it: Variant in lane.items:
			if not _sound_item(it):
				return false
	for t: Variant in d.items:
		if not (t is Vector2i) or not (d.items[t] is Array):
			return false
		for it: Variant in d.items[t]:
			if not _sound_item(it):
				return false
	for part: Variant in d.bin:
		if not (part is String) or not (d.bin[part] is int):
			return false
	for t: Variant in d.turn:
		if not (t is Vector2i) or not (d.turn[t] is Vector2i):
			return false
	return true

func _unpack(d: Dictionary) -> void:
	floor_seed = d.seed
	_rng.seed = d.seed
	_rng.state = d.rng
	coins = d.coins
	earned = d.earned
	_acc = clampf(d.acc, 0.0, TICK)
	alpha = clampf(_acc / TICK, 0.0, 1.0)
	_next_id = d.next_id
	picked = d.picked
	tick_n = d.tick_n
	queue = d.queue
	table = (d.table as Dictionary).duplicate(true)
	belts = (d.belts as Dictionary).duplicate(true)
	kinds = (d.kinds as Dictionary).duplicate(true)
	over = (d.over as Dictionary).duplicate(true)
	items = (d.items as Dictionary).duplicate(true)
	robots = (d.robots as Array).duplicate(true)
	bin = (d.bin as Dictionary).duplicate(true)
	_turn = (d.turn as Dictionary).duplicate(true)
	_stand_stations()
	events = []
	_order_stale = true
	dirty = false
