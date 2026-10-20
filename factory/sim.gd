extends RefCounted

## Factory, as pure data: plates of land in a pond, a closed forest a tap
## takes a log from, logs that leave it by a gate on each side and ride belts
## to a market that sells them, and from the first plate bought a fire and a
## retort. Nothing here draws, reads the clock or
## touches a node: whoever holds it (the screen, the tab's card, the probe)
## steps it, drains `events` and draws from what it reads. It is deterministic
## from its seed and its save, and **nothing happens while it is not stepped**:
## the save keeps durations, never a time of day.
## Spec docs/superpowers/specs/2026-10-10-factory-board-and-hand-era-design.md;
## every rate is the ledger's, 2026-10-10-factory-physics-design.md.
##
## ---------------------------------------------------------------------------
## THE API, for the view
##
## Geometry. A tile is one global Vector2i. Plate P (a Vector2i on the plate
## lattice, the first is (0,0)) owns tiles P*8 .. P*8+7 on both axes; the
## lattice goes negative, so use `plate_of(tile)`. A new land's market is on
## the tile (6, 6) of the first plate, which is neutral ground, and it
## has a forest behind it, at `FOREST_AT`. A facing is an int 0..3 = +x, +y, -x, -y (`DIRS`); a
## quarter clockwise is (f + 1) % 4. Positions handed out as Vector2 are in
## tile units, a tile's middle at tile + (0.5, 0.5).
##
## Holding it.
##   Sim.new(seed)            a new land (the same as new_land(seed))
##   new_land(seed)           throws the land away for a new one
##   step(delta)              delta clamped to 0.25 s, whole 10 Hz ticks run
##   alpha: float             0..1, the part of a tick left over, for drawing
##   events: Array            Dictionaries with a `type`; the holder clears it
##   dirty: bool              something changed since the last save()
##   save()                   writes `Sim.path` (static, "user://factory.cfg")
##   load_saved() -> bool     reads it into this sim; false: no file or a bad
##                            one, and the sim is left as it was
##   picked: String           the drawer's picked tile, kept for the view
##
## Money and land.
##   coins, earned: int
##   plates: Dictionary       Vector2i -> "forest" | "mine" | "neutral"
##   free_edges() -> Array    lattice coords a plate may be bought on
##   plate_price() -> int     PLATE_PRICE: flat, however many are held
##   buy_plate(P, kind) -> bool
##   unlocked(kind) -> bool   belt and market always; firebox and retort from
##                            the first plate bought; the kiln with a mine;
##                            the rest by a goal (GOALS)
##   price(kind) -> int       PRICE: flat, however many of a kind stand
##   no_cost: bool             everything `price` knows costs nothing: the
##                            debug button's, never kept in the save
##
## A forest is closed (the user, 2026-10-11: "the forest must be a closed grid
## that only output the material, user should not be able to build inside of
## it, only upgrade"): no belt and no machine goes on any of its 64 tiles, a
## tap anywhere on it is one log into its stock, and the stock leaves by the
## gate in each side into whatever takes it beyond (a belt, the market, a
## hopper, a retort's back), the sides by turns.
## A mine (2026-10-12) is a forest's twin that gives stone: closed, tapped,
## the same gates, stock and levels. Both are rows of `sources`.
##   sources: Dictionary      plate -> {level (0: the hand alone), stock,
##                            t (0..1 toward the next log of its own), next
##                            (the side the next log tries first), paid}
##   is_forest(tile), is_mine(tile), is_source(tile) -> bool
##   gives(P) -> String                 "log", "stone", "" for open ground
##   gate(P, side) -> Vector2i          the forest tile a log leaves by
##   source_rate(P) -> float            things a second it makes by itself
##
## Reading, all cheap (these are the sim's own tables: read, never write).
##   trees: Dictionary        id -> {id, tile, look 0..3}: what a forest
##                            is seen by, never counted and never felled
##   belts: Dictionary        tile -> facing
##   kinds: Dictionary        tile -> "fast" | "splitter", for a belt that is
##                            not the plain one; belt_kind(tile) says any
##   over: Dictionary         tile -> {dir, items}: what rides over a bridge
##   outs(tile), feeds(from, to)        where a belt hands on to
##   sold: Dictionary         kind -> how many the market has sold
##   GOALS, goal_progress(g), goal_done(g), next_goal()
##   items: Dictionary        tile -> Array of {id, kind, at 0..1, from, was};
##                            index 0 is the front one. On a belt `at` runs
##                            along the tile and `from` is the facing it came
##                            in by (-1: it began here), so a side load is
##                            drawn round the corner. On bare ground it lies.
##   item_pos(tile, item) -> Vector2    where to draw it now (uses `alpha`)
##   modules: Dictionary      id -> {id, kind, root, facing, level, tiles,
##                            built, build 0..1, paid, and for a machine that
##                            makes (RECIPE: kiln, retort, saw, joiner): inp
##                            ("" or the kind it is working), got (how many it
##                            has gathered toward one that takes several), out
##                            ("" or the kind it is handing on) and left (how
##                            many of it), work 0..1, share 0..1; for a
##                            firebox: lit, fuel and fuel_max (kJ), fuel_kind,
##                            hopper (item kinds, the next to light first),
##                            draw and cap (kW), stoker; for an engine: share
##                            (of the heat it asks) and draw (kW of shaft);
##                            for a market: wait (item kinds: the one on its
##                            hatch) and t (seconds toward its next sale)}
##   SINGLE                   the kinds of one tile: firebox, engine, market
##   gives_power(kind), wants_power(kind)   "heat", "shaft" or ""
##   module_at(tile) -> Dictionary      {} if none
##   front_of(module) -> Vector2i       a 1x2's front (output) tile
##   out_tile(module) -> Vector2i       the tile its output leaves into
##   fuel_left(module) -> float         0..1 of the item burning
##   working(module) -> bool            holds an input and has room to finish
##   cycle_seconds(module) -> float     real seconds a cycle at the heat it
##                            would have working now; -1.0 with no fire lit
## A market is a module (the user, 2026-10-12: "I can have multiple markets,
## and they should have it own lvl and state"): one is given, built, and more
## are placed from the drawer. Each has its own level, hatch and clock.
##   market: Dictionary       the first market standing (the lowest id), for
##                            a holder that wants one: {} when none
##   market_interval(m) -> float        seconds a sale: 4, 3, 2, 1, then halved
##   market_progress(m) -> float        0..1 toward the next sale
##                            (both of `market` when no module is given)
##   is_market(tile), on_land(tile), plate_of(tile), tile_free(tile)
##
## Acting. Each returns whether it did anything; when it did not it pushes
## {type "refused", why, tile}.
##   tap(tile)                a forest: one log into its stock (refused "full"
##                            when it holds FOREST_ROOM); a firebox: lights
##                            the next fuel if the fire is out
##   can_lay(tile)            fits a belt (coins not looked at)
##   lay_belt(tile, facing, kind)       "belt" 1 coin, "fast", "splitter"; on
##                            a belt of that kind already there it only re-faces
##   turn(tile)               a belt or a 1x2 module a quarter clockwise
##   can_place(kind, tile, facing)      unlocked and fits (coins not looked at)
##   place(kind, tile, facing)          tile is the root: a 1x2's back (input)
##   sell(tile)               a belt or a module back for all that was paid
##                            (refused "market" for the last market standing)
##   sell_price(tile) -> int
##   fit_stoker(tile)         a fire box lights its own fuel from then on
##   upgrade(target)          a fire box's or a market's tile, a forest's
##                            tile, or "market" for the first market's
##   upgrade_price(target) -> int       -1: nothing to buy there
##   put(tile, kind) -> bool  drops an item, for harnesses
##
## Events (each has `type`; `tile` where there is one).
##   chop {tile, id, plate, auto}     a log into a forest's stock, off the
##                                    tree `id` at `tile`; `auto`: its own
##   log {tile, from, kind}           out of the gate `from` into `tile`
##   laid {tile, facing}  turned {tile, facing}
##   flipped {tile, tiles}            a line of belts turned round
##   placed {tile, id, kind}  built {tile, id, kind}
##   sold_back {tile, kind, amount, items}
##   sold_line {tile, tiles, amount}  belts sold back in one go
##   fed {tile, id, kind}             a fuel into a hopper
##   lit {tile, id, kind}  dim {tile, id}
##   made {tile, id, kind}            a kiln or a retort done with one
##   out {tile, id, kind}             its output left into `tile`
##   brought {tile, id, kind, from}   onto a market's hatch, travelling `from`
##   sale {tile, id, kind, amount, coins}
##   goal {id, gives}                 a goal reached: what it opens
##   level {target, level}            "source" (with `plate`) or a module's id
##   plate {plate, kind}
##   refused {why, tile}
## ---------------------------------------------------------------------------

## The sim's tick, real seconds, and the game seconds in it (the ledger's 4x).
const TICK := 0.1
const GAME_S := 0.4
## The longest frame a holder steps by: a longer one is a hitch, not play.
const STEP_MOST := 0.25
const EPS := 0.000001
const VERSION := 4

const PLATE := 8
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const KINDS := ["forest", "mine", "neutral"]
## The closed kinds and what each gives (the ledger, sections 12 and 13).
const GIVES := {"forest": "log", "mine": "stone"}
## The forest a new land has, behind the market's plate.
const FOREST_AT := Vector2i(0, -1)
## Where a new land's market stands: one square, a hatch (2x2 until
## 2026-10-11). A module since 2026-10-12, one of as many as are bought.
const MARKET_AT := Vector2i(6, 6)
const NONE := Vector2i(-99999, -99999)

## A belt is a coin a tile and nothing sells without one, and a belt sold
## returns its coin, so twenty cannot be stranded.
const START_COINS := 20
const SELLS := {"log": 1, "stone": 2, "lime": 10, "charcoal": 4, "plank": 2, "chair": 12}
## What a thing costs, the first of its kind and every one after (the user,
## 2026-10-12: "it should not increase price of markets, neither other
## buildings, they stay flat").
const PRICE := {"belt": 1, "fast": 4, "splitter": 15, "bridge": 25, "firebox": 20, "kiln": 40, "retort": 40,
	"engine": 150, "saw": 80, "joiner": 120, "stoker": 100, "market": 100}
## What is laid like a belt and carries like one: the plain belt, the fast
## one (twice the speed, the same spacing: the ledger, section 8) and the
## splitter, a belt tile that sends what crosses it out ahead and by both
## sides in turn.
## And the bridge: a belt tile with a second belt over it, across it, so
## two lines cross. What comes along its facing goes under; what comes in by
## a side goes over and leaves by the other side.
const BELTS := ["belt", "fast", "splitter", "bridge"]
## A belt kind laid one tile at a time, where the finger is.
const ONE_TILE := ["splitter", "bridge"]
## The goals (the ledger, section 14): things sold at the market, counted
## from the land's first sale, each opening what it `gives` for good. They
## are all open at once and none is lost by doing another first.
const GOALS := [
	{"id": "splitter", "need": {"log": 30}, "gives": ["splitter"]},
	{"id": "fast", "need": {"charcoal": 10}, "gives": ["fast"]},
	{"id": "bridge", "need": {"lime": 5}, "gives": ["bridge"]},
	{"id": "steam", "need": {"charcoal": 25}, "gives": ["engine", "saw", "stoker"]},
	{"id": "joiner", "need": {"plank": 100}, "gives": ["joiner"]},
]
## What a plate costs, the first bought and every one after (the user,
## 2026-10-12, of a second plate at 150: "prices are flat not stacked on each
## buy for the same item").
const PLATE_PRICE := 50

## A forest: the trees it is seen by, the logs it holds before its gates
## take them, the logs a second it makes by itself at each level (the user,
## 2026-10-11: "the first upgrade is a wood / second automation"; the later
## levels are a log a second more each, up to what four gates can carry) and
## what each level costs.
const TREES := 14
const LOOKS := 4
## A mine is seen by its rocks, as a forest by its trees: fewer and squat.
const ROCKS := 9
const SOURCE_ROOM := 12
const SOURCE_RATE := [0.0, 1.0, 2.0, 3.0, 4.0]
const SOURCE_PRICE := [60, 180, 540, 1620]
## The tile of a forest plate a log leaves by, toward each of DIRS: a little
## off the middle of the side, and the same place at every quarter turn.
const GATES: Array[Vector2i] = [Vector2i(7, 4), Vector2i(3, 7), Vector2i(0, 3), Vector2i(4, 0)]

## A belt: a tile in two real seconds (0.25 m/s), two items a tile, never
## nearer than half a tile (the ledger, section 8).
const BELT_SECONDS := 2.0
const FAST_SECONDS := 1.0
const GAP := 0.5
const ROOM := 2
## Where the two items of a bare tile lie, off its middle.
const LIE: Array[Vector2] = [Vector2(-0.16, 0.1), Vector2(0.16, -0.1)]

## Seconds a sale by the market's level; past the table each level halves it.
const MARKET_EVERY := [4.0, 3.0, 2.0, 1.0]
## The price of levels 2, 3 and 4, then each MARKET_STEP times the last.
const MARKET_PRICE := [30, 80, 200]
const MARKET_STEP := 2.5
## What the hatch holds: the one thing lying on it. The next waits on its belt.
const MARKET_ROOM := 1

## Fuel, MJ an item (the ledger, section 3).
const FUEL := {"log": 320.0, "charcoal": 150.0, "plank": 64.0}
## A firebox's cap by level, kW, and what the next level costs. The spec lists
## three caps and three prices; the third price has no level to buy yet.
const FIRE_KW := [60.0, 90.0, 120.0]
const FIRE_PRICE := [60, 180, 540]
const FIRE_FLOOR := 12.0
const HOPPER := 5
## The machines that make (the ledger, sections 6 and 15): what one takes
## and how many of it a cycle, what it gives and how many, the energy a
## cycle is, its rated power, the part of that it draws idle, and the kind
## of power it wants: "heat" from a fire box that touches it, "shaft" from
## an engine that does.
const RECIPE := {
	"kiln": {"takes": "stone", "need": 1, "gives": "lime", "n": 1, "mj": 55.0, "kw": 60.0, "idle": 0.2, "wants": "heat"},
	"retort": {"takes": "log", "need": 1, "gives": "charcoal", "n": 1, "mj": 32.0, "kw": 60.0, "idle": 0.2, "wants": "heat"},
	"saw": {"takes": "log", "need": 1, "gives": "plank", "n": 4, "mj": 0.6, "kw": 7.5, "idle": 0.15, "wants": "shaft"},
	"joiner": {"takes": "plank", "need": 3, "gives": "chair", "n": 1, "mj": 0.3, "kw": 4.0, "idle": 0.15, "wants": "shaft"},
}
## The engine (a boiler and a single cylinder on one tile): the heat it asks
## of the fire that touches it when something it turns is working and when
## nothing is, and the shaft it gives at full heat. 8% of its heat.
const ENGINE_HEAT := 94.0
const ENGINE_BANKED := 20.0
const ENGINE_SHAFT := 7.5
## The modules of one tile, which have no facing.
const SINGLE := ["firebox", "engine", "market"]
const BUILD := {"firebox": 20.0, "kiln": 40.0, "retort": 40.0, "engine": 60.0, "saw": 40.0, "joiner": 40.0, "market": 20.0}

## A harness points this elsewhere before it makes a sim.
static var path := "user://factory.cfg"

var land_seed := 0
var coins := 0
var earned := 0
var plates := {}
var sources := {}
var trees := {}
var belts := {}
## A belt tile that is not a plain belt: tile -> "fast" | "splitter".
var kinds := {}
## What rides over a bridge: tile -> {dir (the facing it travels), items
## (as a belt's, the front one first)}.
var over := {}
## What the market has sold, by kind, since the land began.
var sold := {}
var items := {}
var modules := {}
## The first market standing: the given one until it is sold.
var market: Dictionary:
	get:
		var best := {}
		for id: int in modules:
			if modules[id].kind == "market" and (best.is_empty() or id < int(best.id)):
				best = modules[id]
		return best
var events: Array = []
var dirty := false
var alpha := 0.0
var picked := ""
## A debug switch (the user, 2026-10-12: "a button to make buildings price
## 0, so I can debug on phone"): belts, machines, markets and the stoker
## cost nothing while it is on. Levels and land keep their prices. It is the
## holder's to set and is not kept: a land read back has it off.
var no_cost := false

var _rng := RandomNumberGenerator.new()
var _acc := 0.0
var _next_id := 1
var _mod_at := {}        # tile -> module id
var _turn := {}          # fed tile -> the belt tile that fed it last
var _split := {}         # splitter tile -> the way out it tries first next (0 ahead, 1 and 2 its sides)
var _order: Array = []
var _order_stale := true

func _init(with_seed: int = 0) -> void:
	new_land(with_seed)

# --- the land ---

func new_land(with_seed: int) -> void:
	land_seed = with_seed
	_rng.seed = with_seed
	coins = START_COINS
	earned = 0
	plates = {}
	sources = {}
	trees = {}
	belts = {}
	kinds = {}
	over = {}
	sold = {}
	_split = {}
	items = {}
	modules = {}
	events = []
	picked = ""
	alpha = 0.0
	_acc = 0.0
	_next_id = 1
	_mod_at = {}
	_turn = {}
	_order_stale = true
	_add_plate(Vector2i.ZERO, "neutral")
	# the market a land is given stands built, and nothing was paid for it
	modules[_next_id] = _market_row(_next_id, MARKET_AT, true, 0)
	_mod_at[MARKET_AT] = _next_id
	_next_id += 1
	_add_plate(FOREST_AT, "forest")
	dirty = true

## The plate a tile is on, owned or not. The lattice goes negative, so this
## floors where an int division would round toward nothing.
static func plate_of(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(tile.x / float(PLATE)), floori(tile.y / float(PLATE)))

func on_land(tile: Vector2i) -> bool:
	return plates.has(plate_of(tile))

func is_market(tile: Vector2i) -> bool:
	return _mod_at.has(tile) and modules[_mod_at[tile]].kind == "market"

static func _market_row(id: int, tile: Vector2i, built: bool, paid: int) -> Dictionary:
	return {"id": id, "kind": "market", "root": tile, "facing": 0, "level": 1, "tiles": [tile],
		"built": built, "build": 1.0 if built else 0.0, "paid": paid, "wait": [], "t": 0.0}

func _markets() -> int:
	var n := 0
	for id: int in modules:
		if modules[id].kind == "market":
			n += 1
	return n

func is_forest(tile: Vector2i) -> bool:
	return plates.get(plate_of(tile), "") == "forest"

func is_mine(tile: Vector2i) -> bool:
	return plates.get(plate_of(tile), "") == "mine"

## A closed plate, forest or mine: tapped, never built on.
func is_source(tile: Vector2i) -> bool:
	return GIVES.has(plates.get(plate_of(tile), ""))

## What the closed plate `p` gives: "log", "stone", or "" for open ground.
func gives(p: Vector2i) -> String:
	return String(GIVES.get(plates.get(p, ""), ""))

## Bare ground: open land with no module or belt on it. No tile of a forest
## is.
func tile_free(tile: Vector2i) -> bool:
	return plates.get(plate_of(tile), "") == "neutral" and not _mod_at.has(tile) and not belts.has(tile)

func module_at(tile: Vector2i) -> Dictionary:
	return modules[_mod_at[tile]] if _mod_at.has(tile) else {}

func free_edges() -> Array:
	var seen := {}
	for p: Vector2i in plates:
		for d: Vector2i in DIRS:
			if not plates.has(p + d):
				seen[p + d] = true
	var out := seen.keys()
	out.sort()
	return out

func plate_price() -> int:
	return PLATE_PRICE

func buy_plate(p: Vector2i, kind: String) -> bool:
	if not KINDS.has(kind):
		return _no("kind", p * PLATE)
	if plates.has(p) or not free_edges().has(p):
		return _no("edge", p * PLATE)
	var cost := plate_price()
	if coins < cost:
		return _no("coins", p * PLATE)
	coins -= cost
	_add_plate(p, kind)
	events.append({"type": "plate", "plate": p, "kind": kind})
	dirty = true
	return true

## Era 2 opens with the first plate bought: the plate is the key. The kiln
## waits for a mine, since nothing else gives it stone.
func unlocked(kind: String) -> bool:
	if kind == "belt" or kind == "market":
		return true
	for g: Dictionary in GOALS:
		if (g.gives as Array).has(kind):
			return goal_done(g)
	if kind == "kiln" and not plates.values().has("mine"):
		return false
	return (BUILD.has(kind) or kind == "stoker") and plates.size() >= 3

## How far a goal is, 0 to 1: the least of its needs, each sold over wanted.
func goal_progress(g: Dictionary) -> float:
	var k := 1.0
	for kind: String in g.need:
		k = minf(k, float(sold.get(kind, 0)) / float(g.need[kind]))
	return clampf(k, 0.0, 1.0)

func goal_done(g: Dictionary) -> bool:
	for kind: String in g.need:
		if int(sold.get(kind, 0)) < int(g.need[kind]):
			return false
	return true

## The first goal not reached yet, {} when all are.
func next_goal() -> Dictionary:
	for g: Dictionary in GOALS:
		if not goal_done(g):
			return g
	return {}

func price(kind: String) -> int:
	return 0 if no_cost else int(PRICE.get(kind, 0))

func _add_plate(p: Vector2i, kind: String) -> void:
	plates[p] = kind
	if not GIVES.has(kind):
		return
	sources[p] = {"level": 0, "stock": 0, "t": 0.0, "next": 0, "paid": 0}
	# its trees (a mine's rocks) stand inside its rim, where no gate is, on
	# every other tile so that they fill it and none hides the one behind
	var can: Array[Vector2i] = []
	for y in range(1, PLATE - 1):
		for x in range(1, PLATE - 1):
			if (x + y) % 2 == 0:
				can.append(p * PLATE + Vector2i(x, y))
	for i in (TREES if kind == "forest" else ROCKS):
		var at: Vector2i = can.pop_at(_rng.randi_range(0, can.size() - 1))
		trees[_next_id] = {"id": _next_id, "tile": at, "look": _rng.randi_range(0, LOOKS - 1)}
		_next_id += 1

static func gate(p: Vector2i, side: int) -> Vector2i:
	return p * PLATE + GATES[side]

func source_rate(p: Vector2i) -> float:
	return float(SOURCE_RATE[int(sources[p].level)]) if sources.has(p) else 0.0

## The tree of forest `p` nearest `near`, the lower id of two as near.
func _tree_by(p: Vector2i, near: Vector2i) -> Dictionary:
	var best := {}
	var best_d := 0
	for id: int in trees:
		var tr: Dictionary = trees[id]
		if plate_of(tr.tile) != p:
			continue
		var d := ((tr.tile as Vector2i) - near).length_squared()
		if best.is_empty() or d < best_d or (d == best_d and id < int(best.id)):
			best = tr
			best_d = d
	return best

## One log into forest `p`'s stock, off the tree nearest `near`. False when
## the stock is full.
func _chop(p: Vector2i, near: Vector2i, auto: bool) -> bool:
	var f: Dictionary = sources[p]
	if int(f.stock) >= SOURCE_ROOM:
		return false
	f.stock = int(f.stock) + 1
	var tr := _tree_by(p, near)
	events.append({"type": "chop", "tile": tr.get("tile", near), "id": int(tr.get("id", 0)), "plate": p, "auto": auto})
	return true

## Every tick: a forest with a level makes its own logs, and what a forest
## holds leaves by its gates, one a gate a tick, the side after the last
## first, into whatever takes it there. Where nothing takes any, one lies on
## bare ground past a gate, so a new land's first taps are seen to give; once
## a belt, the market or a machine stands past any gate, nothing lies.
func _run_sources() -> void:
	for p: Vector2i in sources:
		var f: Dictionary = sources[p]
		var kind := gives(p)
		var rate := source_rate(p)
		if rate > 0.0:
			f.t = float(f.t) + TICK * rate
			while float(f.t) >= 1.0 - EPS:
				# a tree in its turn, by the dice the land was made with
				var near := p * PLATE + Vector2i(_rng.randi_range(1, PLATE - 2), _rng.randi_range(1, PLATE - 2))
				if not _chop(p, near, true):
					f.t = 1.0
					break
				f.t = maxf(float(f.t) - 1.0, 0.0)
		if int(f.stock) <= 0:
			continue
		var first: int = f.next
		var it := {}
		var gave := false
		for q in 4:
			if int(f.stock) <= 0:
				break
			var d := (first + q) % 4
			var g := gate(p, d)
			if it.is_empty():
				it = _item(kind, _mid(g))
			it.was = _mid(g)
			if not _enter(g + DIRS[d], it, d, 0.0):
				continue
			f.stock = int(f.stock) - 1
			f.next = (d + 1) % 4
			gave = true
			events.append({"type": "log", "tile": g + DIRS[d], "from": g, "kind": kind})
			it = {}
		if gave or int(f.stock) <= 0:
			continue
		# a gate that leads somewhere is only busy: nothing is spilt past another
		var led := false
		for d in 4:
			var to := gate(p, d) + DIRS[d]
			var m := module_at(to)
			# a hopper, a hatch, or a machine's back: its front takes nothing
			led = led or belts.has(to) or (not m.is_empty() and (m.kind == "firebox" or to == m.root))
		if led:
			continue
		for q in 4:
			var d := (first + q) % 4
			var g := gate(p, d)
			var to := g + DIRS[d]
			if not tile_free(to) or _count(to) >= ROOM:
				continue
			if it.is_empty():
				it = _item(kind, _mid(g))
			it.was = _mid(g)
			var arr: Array = items.get(to, [])
			arr.append(it)
			items[to] = arr
			f.stock = int(f.stock) - 1
			f.next = (d + 1) % 4
			events.append({"type": "log", "tile": to, "from": g, "kind": kind})
			break

# --- the hand ---

func tap(tile: Vector2i) -> bool:
	if is_source(tile):
		if not _chop(plate_of(tile), tile, false):
			# the tree that would have given it shakes its head
			return _no("full", _tree_by(plate_of(tile), tile).get("tile", tile))
		dirty = true
		return true
	var m := module_at(tile)
	if not m.is_empty() and m.kind == "firebox":
		return _light(m)
	return _no("nothing", tile)

func _light(m: Dictionary) -> bool:
	if not m.built:
		return _no("building", m.root)
	if m.lit:
		return _no("lit", m.root)
	if (m.hopper as Array).is_empty():
		return _no("empty", m.root)
	var kind: String = (m.hopper as Array).pop_front()
	m.lit = true
	m.fuel_kind = kind
	m.fuel_max = float(FUEL[kind]) * 1000.0
	m.fuel = m.fuel_max
	events.append({"type": "lit", "tile": m.root, "id": m.id, "kind": kind})
	dirty = true
	return true

# --- belts ---

func can_lay(tile: Vector2i) -> bool:
	return _lay_why(tile) == ""

func _lay_why(tile: Vector2i) -> String:
	if not on_land(tile):
		return "pond"
	if is_source(tile):
		return String(plates[plate_of(tile)])
	if is_market(tile):
		return "market"
	if _mod_at.has(tile):
		return "taken"
	return ""

## The kind of the belt on `tile`: "belt", "fast", "splitter"; "" for none.
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
	_split.erase(tile)
	if kind != "bridge":
		_drop_over(tile)
	if kind == "belt":
		kinds.erase(tile)
	else:
		kinds[tile] = kind

## What rode over a bridge that is one no more, or was turned: it lies on
## the nearest bare ground.
func _drop_over(tile: Vector2i) -> void:
	if not over.has(tile):
		return
	var lane: Dictionary = over[tile]
	over.erase(tile)
	for it: Dictionary in lane.items:
		_spill([tile], it.kind)

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
## the ground a belt or a module just left.
func _settle(tile: Vector2i) -> void:
	if not items.has(tile):
		return
	var arr: Array = items[tile]
	while arr.size() > ROOM:
		var extra: Dictionary = arr.pop_back()
		_spill([tile], extra.kind)
	for i in arr.size():
		var it: Dictionary = arr[i]
		it.at = 0.5 - GAP * i
		it.from = -1
		it.erase("to")
		it.was = _pos(tile, it)

func turn(tile: Vector2i) -> bool:
	if belts.has(tile):
		_face_belt(tile, (int(belts[tile]) + 1) % 4)
		return true
	var m := module_at(tile)
	if m.is_empty():
		return _no("nothing", tile)
	if SINGLE.has(m.kind):
		return _no("round", tile)
	# the next quarter its front tile fits, so one in a tight place still turns
	for q in range(1, 4):
		var f: int = (int(m.facing) + q) % 4
		if _place_why(m.kind, m.root, f, m.id) != "":
			continue
		for t: Vector2i in m.tiles:
			_mod_at.erase(t)
		m.facing = f
		m.tiles = [m.root, m.root + DIRS[f]]
		_stand_module(m)
		events.append({"type": "turned", "tile": m.root, "facing": f, "id": m.id})
		dirty = true
		return true
	return _no("room", tile)

## The tiles a belt hands on to: the one ahead, and for a splitter the ones
## at its sides too, ahead first.
func outs(tile: Vector2i) -> Array[Vector2i]:
	var f: int = belts[tile]
	match String(kinds.get(tile, "")):
		"splitter":
			return [tile + DIRS[f], tile + DIRS[(f + 1) % 4], tile + DIRS[(f + 3) % 4]]
		"bridge":
			# under it ahead, and over it the way its last thing went
			if over.has(tile):
				return [tile + DIRS[f], tile + DIRS[int(over[tile].dir)]]
	return [tile + DIRS[f]]

## Whether what is on `from` goes into `to` next: a belt pointing at it, a
## splitter beside it (not one it lies behind), a machine whose way out it is.
func feeds(from: Vector2i, to: Vector2i) -> bool:
	if belts.has(from):
		return outs(from).has(to)
	var m := module_at(from)
	return not m.is_empty() and RECIPE.has(m.kind) and out_tile(m) == to

## How many things hand on into `tile`: belts pointing at it, splitters
## beside it, a kiln or a retort whose way out it is.
func _feeders(tile: Vector2i) -> int:
	var n := 0
	for d in 4:
		if feeds(tile + DIRS[d], tile):
			n += 1
	return n

## Whether the belt on `tile` is a plain one a line runs through (a belt or
## a fast belt; a splitter and a bridge end a line).
func _plain(tile: Vector2i) -> bool:
	return belts.has(tile) and not ONE_TILE.has(belt_kind(tile))

## The belts of the line through the plain belt on `tile`, in the way
## things ride it, stopping at a join (a belt fed by two), a splitter, a
## bridge or anything not a belt (Tally's rule, the user, 2026-10-19: "stop
## on joins or cross to avoid issue"). [] when `tile` holds no plain belt.
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
## the market, a fire box or a kiln's or retort's way in beside it.
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

## Whether `tile` is somewhere a belt delivers into but a belt: the market,
## a fire box, the way in of a kiln or a retort.
func _takes_in(tile: Vector2i) -> bool:
	var m := module_at(tile)
	return not m.is_empty() and (m.kind == "firebox" or m.kind == "market" or (RECIPE.has(m.kind) and m.root == tile))

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
			_run_lane(b, arr, belts[b], kinds.get(b, "") == "splitter")
			if arr.is_empty():
				items.erase(b)
		if over.has(b):
			_run_lane(b, over[b].items, int(over[b].dir), false)

## One lane of the belt on `b` goes on a tick: `arr` its things, the front
## one first, travelling `f`.
func _run_lane(b: Vector2i, arr: Array, f: int, splits: bool) -> void:
	var v := TICK / belt_seconds(b)
	var ahead := INF
	var i := 0
	while i < arr.size():
		var it: Dictionary = arr[i]
		var nat: float = it.at + v
		if i == 0 and splits and not it.has("to") and nat >= 0.5 - EPS:
			# at its middle a thing is given its way out, or waits for one
			var way := _split_way(b, it)
			if way < 0:
				nat = 0.5
			else:
				it.to = way
		if i == 0 and nat >= 1.0 - EPS:
			var out: int = it.get("to", f)
			var front := b + DIRS[out]
			if not _yields(b, front) and _enter(front, it, out, maxf(nat - 1.0, 0.0)):
				arr.remove_at(0)
				_turn[front] = b
				continue
			# nothing ahead takes it: it waits at the belt's end
			nat = 1.0
		it.at = maxf(it.at, minf(nat, ahead - GAP))
		ahead = it.at
		i += 1

## The way out a splitter gives the thing at its middle: ahead and its two
## sides by turns, the first of them that would take the thing now. A side
## that takes nothing (bare ground, a belt pointing in, a full belt) is
## passed over, not waited on. -1 when none takes it.
func _split_way(b: Vector2i, it: Dictionary) -> int:
	var f: int = belts[b]
	var first: int = _split.get(b, 0)
	for q in 3:
		var k := (first + q) % 3
		var d: int = (f + [0, 1, 3][k]) % 4
		var to := b + DIRS[d]
		if belts.has(to) and outs(to).has(b):
			continue
		if _enter(to, it, d, 0.0, true):
			_split[b] = (k + 1) % 3
			return d
	return -1

## Two belts feeding one tile take turns when both have an item at the end:
## the one that fed it last lets the other go.
func _yields(b: Vector2i, fed: Vector2i) -> bool:
	if _turn.get(fed, NONE) != b:
		return false
	for d in 4:
		var other := fed - DIRS[d]
		if other == b or not belts.has(other) or not items.has(other):
			continue
		var first: Dictionary = (items[other] as Array)[0]
		if int(first.get("to", belts[other])) != d:
			continue
		if float(first.at) + TICK / belt_seconds(other) >= 1.0 - EPS:
			return true
	return false

## An item going into `tile` by facing `f`: a belt whose back half is clear,
## the market with nothing on its hatch, a kiln's or a retort's back tile if
## it holds nothing and the item is its kind, a firebox's hopper if it burns.
## `ask` only asks: nothing is moved.
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
	var m := module_at(tile)
	if m.is_empty() or not m.built:
		return false
	if m.kind == "market":
		if (m.wait as Array).size() >= MARKET_ROOM:
			return false
		if ask:
			return true
		(m.wait as Array).append(it.kind)
		events.append({"type": "brought", "tile": m.root, "id": m.id, "kind": it.kind, "from": f})
		return true
	if m.kind == "firebox":
		if not FUEL.has(it.kind) or (m.hopper as Array).size() >= HOPPER:
			return false
		if ask:
			return true
		(m.hopper as Array).append(it.kind)
		events.append({"type": "fed", "tile": m.root, "id": m.id, "kind": it.kind})
		return true
	if RECIPE.has(m.kind) and tile == m.root and m.inp == "" and RECIPE[m.kind].takes == it.kind:
		if not ask:
			# a machine that takes several gathers them, then has its work
			m.got = int(m.got) + 1
			if int(m.got) >= int(RECIPE[m.kind].need):
				m.got = 0
				m.inp = it.kind
		return true
	return false

# --- items ---

func _item(kind: String, was: Vector2) -> Dictionary:
	var it := {"id": _next_id, "kind": kind, "at": 0.5, "from": -1, "was": was}
	_next_id += 1
	return it

func _mid(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)

## Where an item is at the end of the tick, in tile units.
func _pos(tile: Vector2i, it: Dictionary) -> Vector2:
	var c := _mid(tile)
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
	# past a splitter's middle a thing goes the way it was given
	return c + Vector2(DIRS[int(it.get("to", f))]) * (at - 0.5)

## Where to draw an item now: between where the last tick left it and where
## this one did, by `alpha`.
func item_pos(tile: Vector2i, it: Dictionary) -> Vector2:
	return (it.was as Vector2).lerp(_pos(tile, it), alpha)

## Onto a belt from above (a harness's `put`): mid tile if the belt is empty
## there, else behind what rides it if that leaves the gap.
func _belt_drop(tile: Vector2i, kind: String, was: Vector2) -> bool:
	var arr: Array = items.get(tile, [])
	if arr.size() >= ROOM:
		return false
	var it := _item(kind, was)
	if not arr.is_empty():
		var rear: float = arr[arr.size() - 1].at
		if rear < GAP - EPS:
			return false
		it.at = maxf(minf(0.5, rear - GAP), 0.0)
	arr.append(it)
	items[tile] = arr
	return true

func _lay_down(tile: Vector2i, kind: String, was: Vector2) -> void:
	var arr: Array = items.get(tile, [])
	var it := _item(kind, was)
	arr.append(it)
	items[tile] = arr
	if was == Vector2.INF:
		it.was = _pos(tile, it)

func _count(tile: Vector2i) -> int:
	return (items.get(tile, []) as Array).size()

## Nothing is destroyed: an item with nowhere of its own lies on the first of
## `own` with room, else on the nearest bare tile with room.
func _spill(own: Array, kind: String) -> Vector2i:
	for t: Vector2i in own:
		if tile_free(t) and _count(t) < ROOM:
			_lay_down(t, kind, Vector2.INF)
			return t
	var from: Vector2i = own[0]
	var best := NONE
	var best_d := 0
	for p: Vector2i in plates:
		for y in PLATE:
			for x in PLATE:
				var t := p * PLATE + Vector2i(x, y)
				if not tile_free(t) or _count(t) >= ROOM:
					continue
				var d := (t - from).length_squared()
				if best == NONE or d < best_d or (d == best_d and t < best):
					best = t
					best_d = d
	if best == NONE:
		# a land with no bare tile left: over the two rather than gone
		best = from
	_lay_down(best, kind, Vector2.INF)
	return best

## Drops an item on a tile, for harnesses: on a belt if it takes it, on bare
## ground if there is room.
func put(tile: Vector2i, kind: String) -> bool:
	if not SELLS.has(kind):
		return false
	if belts.has(tile):
		return _belt_drop(tile, kind, _mid(tile))
	if not tile_free(tile) or _count(tile) >= ROOM:
		return false
	_lay_down(tile, kind, Vector2.INF)
	dirty = true
	return true

# --- modules ---

func front_of(m: Dictionary) -> Vector2i:
	return (m.root as Vector2i) + (DIRS[m.facing] if not SINGLE.has(m.kind) else Vector2i.ZERO)

func out_tile(m: Dictionary) -> Vector2i:
	return (m.root as Vector2i) + DIRS[m.facing] * 2

func can_place(kind: String, tile: Vector2i, facing: int) -> bool:
	return _place_why(kind, tile, facing, -1) == ""

func _place_why(kind: String, tile: Vector2i, facing: int, but: int) -> String:
	if not BUILD.has(kind) or facing < 0 or facing > 3:
		return "kind"
	if not unlocked(kind):
		return "locked"
	var on: Array = [tile] if SINGLE.has(kind) else [tile, tile + DIRS[facing]]
	for t: Vector2i in on:
		if _mod_at.has(t) and _mod_at[t] == but:
			continue
		var why := _lay_why(t)
		if why != "":
			return why
		if belts.has(t):
			return "belt"
	return ""

## Stands a module with its root (a 1x2's back, input, tile) on `tile`.
func place(kind: String, tile: Vector2i, facing: int) -> bool:
	if SINGLE.has(kind):
		facing = 0
	var why := _place_why(kind, tile, facing, -1)
	if why != "":
		return _no(why, tile)
	if coins < price(kind):
		return _no("coins", tile)
	coins -= price(kind)
	var m := {"id": _next_id, "kind": kind, "root": tile, "facing": facing, "level": 1,
		"tiles": [tile] if SINGLE.has(kind) else [tile, tile + DIRS[facing]],
		"built": false, "build": 0.0, "paid": price(kind)}
	_next_id += 1
	if kind == "market":
		m = _market_row(int(m.id), tile, false, int(m.paid))
	elif kind == "firebox":
		m.merge({"lit": false, "fuel": 0.0, "fuel_max": 0.0, "fuel_kind": "", "hopper": [],
			"draw": 0.0, "cap": FIRE_KW[0], "stoker": false})
	elif kind == "engine":
		m.merge({"share": 0.0, "draw": 0.0})
	else:
		m.merge({"inp": "", "got": 0, "out": "", "left": 0, "work": 0.0, "share": 0.0})
	modules[m.id] = m
	_stand_module(m)
	events.append({"type": "placed", "tile": tile, "id": m.id, "kind": kind})
	dirty = true
	return true

## Takes a module's tiles: what lay there is moved to the nearest bare
## ground.
func _stand_module(m: Dictionary) -> void:
	for t: Vector2i in m.tiles:
		_mod_at[t] = m.id
	for t: Vector2i in m.tiles:
		if items.has(t):
			var arr: Array = items[t]
			items.erase(t)
			for it: Dictionary in arr:
				_spill([t], it.kind)

func sell_price(tile: Vector2i) -> int:
	if belts.has(tile):
		return price(belt_kind(tile))
	var m := module_at(tile)
	return 0 if m.is_empty() else int(m.paid)

## A belt or a module back for everything paid on it, levels too. What it
## held lies on its tiles, two a tile, the rest on the nearest bare ground.
## The one thing gone is the fuel already burning: a fire is not an item.
func sell(tile: Vector2i) -> bool:
	if is_market(tile) and _markets() <= 1:
		# a land with no market sells nothing: the last one stays
		return _no("market", tile)
	if belts.has(tile):
		var kind := belt_kind(tile)
		var back := _sell_belt(tile)
		events.append({"type": "sold_back", "tile": tile, "kind": kind, "amount": back, "items": _count(tile)})
		return true
	var m := module_at(tile)
	if m.is_empty():
		return _no("nothing", tile)
	var held: Array = []
	if m.kind == "firebox":
		held = (m.hopper as Array).duplicate()
	elif m.kind == "market":
		held = (m.wait as Array).duplicate()
	elif RECIPE.has(m.kind):
		var r: Dictionary = RECIPE[m.kind]
		for i in int(m.got) + (int(r.need) if m.inp != "" else 0):
			held.append(r.takes)
		for i in int(m.left):
			held.append(m.out)
	for t: Vector2i in m.tiles:
		_mod_at.erase(t)
		_turn.erase(t)
	modules.erase(m.id)
	coins += int(m.paid)
	for kind: String in held:
		_spill(m.tiles, kind)
	events.append({"type": "sold_back", "tile": m.root, "kind": m.kind, "amount": int(m.paid), "items": held.size(), "id": m.id})
	dirty = true
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

## The price of the next level of `target` (a fire box's or a market's
## tile, any tile of a forest, or "market" for the first market's); -1 where
## there is none to buy.
func upgrade_price(target: Variant) -> int:
	if target is String:
		if target != "market" or market.is_empty():
			return -1
		target = market.root
	if not (target is Vector2i):
		return -1
	if is_source(target):
		var lv: int = sources[plate_of(target)].level
		return SOURCE_PRICE[lv] if lv < SOURCE_PRICE.size() else -1
	var m := module_at(target)
	if m.is_empty():
		return -1
	if m.kind == "market":
		var lv: int = m.level
		if lv - 1 < MARKET_PRICE.size():
			return MARKET_PRICE[lv - 1]
		var p := float(MARKET_PRICE[MARKET_PRICE.size() - 1])
		for i in lv - MARKET_PRICE.size():
			p *= MARKET_STEP
		return int(minf(roundf(p), 9.0e18))
	if m.kind == "firebox" and int(m.level) < FIRE_KW.size():
		return FIRE_PRICE[int(m.level) - 1]
	return -1

func upgrade(target: Variant) -> bool:
	var at := NONE
	if target is Vector2i:
		at = target
	elif not market.is_empty():
		at = market.root
	var cost := upgrade_price(target)
	if cost < 0:
		return _no("top", at)
	if coins < cost:
		return _no("coins", at)
	coins -= cost
	if is_source(at):
		var f: Dictionary = sources[plate_of(at)]
		f.level = int(f.level) + 1
		f.paid = int(f.paid) + cost
		events.append({"type": "level", "target": "source", "level": f.level, "plate": plate_of(at), "tile": at})
	else:
		var m := module_at(at)
		m.level = int(m.level) + 1
		m.paid = int(m.paid) + cost
		if m.kind == "market":
			m.t = minf(float(m.t), market_interval(m))
		else:
			m.cap = FIRE_KW[int(m.level) - 1]
		events.append({"type": "level", "target": m.id, "level": m.level, "tile": m.root})
	dirty = true
	return true

## Seconds a sale at market `m`: the first market's when none is given.
func market_interval(m := {}) -> float:
	var lv: int = (market if m.is_empty() else m).level
	if lv - 1 < MARKET_EVERY.size():
		return MARKET_EVERY[lv - 1]
	return float(MARKET_EVERY[MARKET_EVERY.size() - 1]) / pow(2.0, lv - MARKET_EVERY.size())

func market_progress(m := {}) -> float:
	var of: Dictionary = market if m.is_empty() else m
	return clampf(float(of.t) / market_interval(of), 0.0, 1.0)

# --- heat and shaft ---

func working(m: Dictionary) -> bool:
	return m.built and RECIPE.has(m.kind) and m.inp != "" and m.out == ""

func fuel_left(m: Dictionary) -> float:
	if m.kind != "firebox" or not m.lit or float(m.fuel_max) <= 0.0:
		return 0.0
	return clampf(float(m.fuel) / float(m.fuel_max), 0.0, 1.0)

## What a module gives to what touches it: "heat" (a fire box), "shaft" (an
## engine), "" for the rest.
static func gives_power(kind: String) -> String:
	return "heat" if kind == "firebox" else ("shaft" if kind == "engine" else "")

## What a module wants of what touches it: an engine heat, a machine what
## its recipe says.
static func wants_power(kind: String) -> String:
	return "heat" if kind == "engine" else String(RECIPE.get(kind, {}).get("wants", ""))

## The built modules touching a source (a fire box, an engine) that want
## what it gives. Power reaches only a touching tile (either tile of a 1x2)
## and does not cross to another plate.
func _sinks_of(src: Dictionary) -> Array:
	var out: Array = []
	var root: Vector2i = src.root
	var p := plate_of(root)
	var power := gives_power(src.kind)
	for d: Vector2i in DIRS:
		var t := root + d
		if not _mod_at.has(t) or plate_of(t) != p:
			continue
		var s: Dictionary = modules[_mod_at[t]]
		if s.built and wants_power(s.kind) == power and not out.has(s):
			out.append(s)
	return out

## Whether a sink is asking its rated power: a machine at work, an engine
## with a machine at work on it. `as_if` is counted as working whatever it
## is doing, for its card.
func _busy(s: Dictionary, as_if: int) -> bool:
	if s.kind == "engine":
		for t: Dictionary in _sinks_of(s):
			if working(t) or t.id == as_if:
				return true
		return false
	return working(s) or s.id == as_if

## What a source's sinks ask of it, kW: rated working, a part of it idle.
func _demand(sinks: Array, as_if: int) -> float:
	var kw := 0.0
	for s: Dictionary in sinks:
		if s.kind == "engine":
			kw += ENGINE_HEAT if _busy(s, as_if) else ENGINE_BANKED
		else:
			var r: Dictionary = RECIPE[s.kind]
			kw += float(r.kw) if _busy(s, as_if) else float(r.kw) * float(r.idle)
	return kw

## Before the machines, every tick. Each lit fire box draws what touches it
## asks, never under the floor nor over its cap, and over the cap every sink
## on it gets cap over demand (the ledger, section 4: supply over demand). A
## sink touching two sources is given the sum of the two shares, held to
## one, while each source still gives as if it alone fed it: simple, and a
## little dear for the player who doubles up. Then each engine turns the
## heat it got into shaft, 7.5 kW at full heat, and shares that among the
## machines touching it the same way.
func _heat(as_if := -1) -> void:
	for id: int in modules:
		var m: Dictionary = modules[id]
		if m.has("share"):
			m.share = 0.0
	for id: int in modules:
		var m: Dictionary = modules[id]
		if m.kind != "firebox":
			continue
		m.draw = 0.0
		if not m.built or not m.lit:
			continue
		var sinks := _sinks_of(m)
		var ask := _demand(sinks, as_if)
		var cap: float = m.cap
		m.draw = minf(maxf(ask, FIRE_FLOOR), cap)
		var share := 1.0 if ask <= cap else cap / ask
		for s: Dictionary in sinks:
			s.share = minf(1.0, float(s.share) + share)
	for id: int in modules:
		var m: Dictionary = modules[id]
		if m.kind != "engine":
			continue
		m.draw = 0.0
		if not m.built or float(m.share) <= 0.0:
			continue
		var sinks := _sinks_of(m)
		var ask := _demand(sinks, as_if)
		var supply := ENGINE_SHAFT * float(m.share)
		m.draw = minf(ask, supply)
		var share := 0.0 if ask <= 0.0 else minf(1.0, supply / ask)
		for s: Dictionary in sinks:
			s.share = minf(1.0, float(s.share) + share)

## Real seconds a machine takes a cycle at the power it would have if it
## were working now; -1.0 when no lit fire reaches it. The shares are worked
## out as if it worked and then put back as they were.
func cycle_seconds(m: Dictionary) -> float:
	if not RECIPE.has(m.kind) or not m.built:
		return -1.0
	var kept := {}
	for id: int in modules:
		var o: Dictionary = modules[id]
		kept[id] = [o.get("share", 0.0), o.get("draw", 0.0)]
	_heat(m.id)
	var share: float = m.share
	for id: int in modules:
		var o: Dictionary = modules[id]
		if o.has("share"):
			o.share = kept[id][0]
		if o.has("draw"):
			o.draw = kept[id][1]
	if share <= 0.0:
		return -1.0
	var r: Dictionary = RECIPE[m.kind]
	return float(r.mj) * 1000.0 / (float(r.kw) * share * GAME_S) * TICK

func _run_modules() -> void:
	for id: int in modules:
		var m: Dictionary = modules[id]
		if not m.built:
			m.build = float(m.build) + TICK / float(BUILD[m.kind])
			if float(m.build) >= 1.0 - EPS:
				m.build = 1.0
				m.built = true
				events.append({"type": "built", "tile": m.root, "id": m.id, "kind": m.kind})
			continue
		if not RECIPE.has(m.kind):
			continue
		if working(m) and float(m.share) > 0.0:
			# the ledger, section 2: kilojoules over kilojoules
			var r: Dictionary = RECIPE[m.kind]
			m.work = float(m.work) + float(r.kw) * float(m.share) * GAME_S / (float(r.mj) * 1000.0)
			if float(m.work) >= 1.0 - EPS:
				m.work = 0.0
				m.inp = ""
				m.out = r.gives
				m.left = int(r.n)
				events.append({"type": "made", "tile": m.root, "id": m.id, "kind": m.out})
		if m.out != "":
			_emit(m)

## A machine's output leaves into the tile past its front, one thing a tick:
## a belt, the market, another machine's back, a hopper, or bare ground with
## room. Else it is held and the machine waits.
func _emit(m: Dictionary) -> void:
	var to := out_tile(m)
	var it := _item(m.out, _mid(front_of(m)))
	if not _enter(to, it, m.facing, 0.0):
		if not tile_free(to) or _count(to) >= ROOM:
			return
		var arr: Array = items.get(to, [])
		arr.append(it)
		items[to] = arr
	events.append({"type": "out", "tile": to, "id": m.id, "kind": m.out})
	m.left = int(m.left) - 1
	if int(m.left) <= 0:
		m.left = 0
		m.out = ""

## A fuel burns down at its fire's draw. Spent, the fire dims to embers and
## waits for a tap; a fire with a stoker lights the next fuel in its hopper
## by itself, and one that is out with fuel waiting too.
func _burn() -> void:
	for id: int in modules:
		var m: Dictionary = modules[id]
		if m.kind != "firebox":
			continue
		if m.lit:
			m.fuel = float(m.fuel) - float(m.draw) * GAME_S
			if float(m.fuel) <= EPS:
				m.fuel = 0.0
				m.lit = false
				m.draw = 0.0
				# embers: it waits for the next tap, and what it fed only pauses
				events.append({"type": "dim", "tile": m.root, "id": m.id})
		if not m.lit and m.built and m.get("stoker", false) and not (m.hopper as Array).is_empty():
			_light(m)

## A stoker on the fire box at `tile`: bought once, it lights the next fuel
## by itself for good.
func fit_stoker(tile: Vector2i) -> bool:
	var m := module_at(tile)
	if m.is_empty() or m.kind != "firebox":
		return _no("nothing", tile)
	if not unlocked("stoker"):
		return _no("locked", tile)
	if m.get("stoker", false):
		return _no("top", tile)
	if coins < price("stoker"):
		return _no("coins", tile)
	coins -= price("stoker")
	m.stoker = true
	m.paid = int(m.paid) + price("stoker")
	events.append({"type": "level", "target": m.id, "level": m.level, "tile": m.root, "stoker": true})
	dirty = true
	return true

# --- the tick ---

## Steps the land by a frame. Whole ticks run; what is left over is `alpha`.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	_acc += minf(delta, STEP_MOST)
	while _acc >= TICK - EPS:
		_acc = maxf(_acc - TICK, 0.0)
		_tick()
	alpha = clampf(_acc / TICK, 0.0, 1.0)

func _tick() -> void:
	for tile: Vector2i in items:
		for it: Dictionary in items[tile]:
			it.was = _pos(tile, it)
	for tile: Vector2i in over:
		for it: Dictionary in over[tile].items:
			it.was = _pos(tile, it)
	_run_sources()
	_move_belts()
	_heat()
	_run_modules()
	_burn()
	_sell()
	dirty = true

## One sale an interval and no faster, each market by its own clock. A
## hatch's clock stands at nothing while nothing lies on it, so whatever
## comes lies there its whole interval before the hatch opens under it
## (until 2026-10-11 the first to reach an idle market was sold as it landed).
func _sell() -> void:
	for id: int in modules:
		var m: Dictionary = modules[id]
		if m.kind != "market" or not m.built:
			continue
		var every := market_interval(m)
		var wait: Array = m.wait
		m.t = float(m.t) + TICK
		while not wait.is_empty() and float(m.t) >= every - EPS:
			m.t = maxf(float(m.t) - every, 0.0)
			var kind: String = wait.pop_front()
			var amount: int = SELLS[kind]
			coins += amount
			earned += amount
			sold[kind] = int(sold.get(kind, 0)) + 1
			events.append({"type": "sale", "tile": m.root, "id": id, "kind": kind, "amount": amount, "coins": coins})
			for g: Dictionary in GOALS:
				if (g.need as Dictionary).has(kind) and int(sold[kind]) == int(g.need[kind]) and goal_done(g):
					events.append({"type": "goal", "id": g.id, "gives": g.gives})
		if wait.is_empty():
			m.t = 0.0

func _no(why: String, tile: Vector2i) -> bool:
	events.append({"type": "refused", "why": why, "tile": tile})
	return false

# --- keeping ---

## Everything the land is, as one Dictionary: what the save holds and what a
## harness compares. Durations only, no time of day.
func pack() -> Dictionary:
	return {
		"version": VERSION, "seed": land_seed, "rng": _rng.state, "coins": coins, "earned": earned,
		"acc": _acc, "next_id": _next_id, "picked": picked,
		"plates": plates.duplicate(true), "sources": sources.duplicate(true), "trees": trees.duplicate(true),
		"belts": belts.duplicate(true), "kinds": kinds.duplicate(true), "over": over.duplicate(true), "split": _split.duplicate(true), "sold": sold.duplicate(true), "items": items.duplicate(true), "modules": modules.duplicate(true),
		"turn": _turn.duplicate(true),
	}

## The land goes into the file as bytes (base64), not as text: a float
## written as text comes back a last digit off (101.00000000000449 read
## 101.00000000000448 on 2026-10-10), and a land read back must play on
## exactly as the land saved would.
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("factory", "version", VERSION)
	cfg.set_value("factory", "state", Marshalls.variant_to_base64(pack()))
	cfg.save(path)
	dirty = false

## Reads `path` into this sim. False, and the sim untouched, when there is no
## file or it is not a land this version wrote.
func load_saved() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	if not cfg.has_section_key("factory", "state"):
		return false
	var kept: Variant = cfg.get_value("factory", "state")
	if not (kept is String) or (kept as String).is_empty():
		return false
	var bytes := Marshalls.base64_to_raw(kept)
	# bytes that do not open as a Dictionary are not handed to the decoder
	if bytes.size() < 4 or (bytes.decode_u32(0) & 0xFF) != TYPE_DICTIONARY:
		return false
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary):
		return false
	_lift(d)
	if not _sound(d):
		return false
	_unpack(d)
	return true

# What a kept file says is trusted only as far as its shapes: every table is
# the kind of thing it should be and every row has its keys, so no file
# raises an error on load. Whether figures that pass are true is not asked.
const _SHAPES := {
	"version": TYPE_INT, "seed": TYPE_INT, "rng": TYPE_INT, "coins": TYPE_INT, "earned": TYPE_INT,
	"acc": TYPE_FLOAT, "next_id": TYPE_INT, "picked": TYPE_STRING,
	"plates": TYPE_DICTIONARY, "sources": TYPE_DICTIONARY, "trees": TYPE_DICTIONARY, "belts": TYPE_DICTIONARY,
	"kinds": TYPE_DICTIONARY, "over": TYPE_DICTIONARY, "split": TYPE_DICTIONARY, "sold": TYPE_DICTIONARY, "items": TYPE_DICTIONARY, "modules": TYPE_DICTIONARY, "turn": TYPE_DICTIONARY,
}
const _TREE_KEYS := ["id", "tile", "look"]
const _SOURCE_KEYS := ["level", "stock", "t", "next", "paid"]
const _MODULE_KEYS := ["id", "kind", "root", "facing", "level", "tiles", "built", "build", "paid"]
const _FIRE_KEYS := ["lit", "fuel", "fuel_max", "fuel_kind", "hopper", "draw", "cap", "stoker"]
const _SINK_KEYS := ["inp", "got", "out", "left", "work", "share"]
const _ENGINE_KEYS := ["share", "draw"]
const _MARKET_KEYS := ["wait", "t"]

## A land of version 3 had one market, a table of its own on (6, 6): it is
## made the module it would be now, so a kept land is read and plays on.
static func _lift(d: Dictionary) -> void:
	if d.get("version") != 3 or not (d.get("market") is Dictionary) or not (d.get("modules") is Dictionary) \
			or not (d.get("next_id") is int):
		return
	var mk: Dictionary = d.market
	if not mk.has_all(["level", "wait", "t"]) or not (mk.level is int) or not (mk.wait is Array):
		return
	var m := _market_row(d.next_id, MARKET_AT, true, 0)
	m.level = mk.level
	m.wait = (mk.wait as Array).duplicate()
	m.t = float(mk.t)
	d.modules[d.next_id] = m
	d.next_id += 1
	d.erase("market")
	d.version = VERSION

static func _sound(d: Dictionary) -> bool:
	for key: String in _SHAPES:
		if not d.has(key) or typeof(d[key]) != _SHAPES[key]:
			return false
	# a land of the first version (trees felled one by one, a quarry, a
	# meadow) is not read: its forest had belts and machines in it
	if d.version != VERSION or d.coins < 0 or d.plates.get(Vector2i.ZERO, "") != "neutral":
		return false
	for p: Variant in d.plates:
		if not (p is Vector2i) or not KINDS.has(d.plates[p]):
			return false
		if GIVES.has(d.plates[p]):
			var f: Variant = d.sources.get(p)
			if not (f is Dictionary) or not f.has_all(_SOURCE_KEYS) or not (f.level is int) or f.level < 0 \
					or f.level > SOURCE_PRICE.size() or not (f.stock is int) or not (f.next is int) or f.next < 0 or f.next > 3:
				return false
	for id: Variant in d.trees:
		var tr: Variant = d.trees[id]
		if not (id is int) or not (tr is Dictionary) or not tr.has_all(_TREE_KEYS) or not (tr.tile is Vector2i):
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
			if not (it is Dictionary) or not it.has_all(["id", "kind", "at", "from", "was"]) or not SELLS.has(it.kind) or not (it.was is Vector2):
				return false
	for t: Variant in d.split:
		if not (t is Vector2i) or not (d.split[t] is int):
			return false
	for kind: Variant in d.sold:
		if not SELLS.has(kind) or not (d.sold[kind] is int):
			return false
	for t: Variant in d.items:
		if not (t is Vector2i) or not (d.items[t] is Array):
			return false
		for it: Variant in d.items[t]:
			if not (it is Dictionary) or not it.has_all(["id", "kind", "at", "from", "was"]) or not SELLS.has(it.kind) \
					or not (it.was is Vector2) or not (it.from is int) or it.from > 3:
				return false
	for id: Variant in d.modules:
		var m: Variant = d.modules[id]
		if not (id is int) or not (m is Dictionary) or not m.has_all(_MODULE_KEYS) or not BUILD.has(m.kind) \
				or not (m.root is Vector2i) or not (m.tiles is Array) or not (m.facing is int) or m.facing < 0 or m.facing > 3 \
				or not (m.level is int) or m.level < 1:
			return false
		if m.kind == "firebox":
			if not m.has_all(_FIRE_KEYS) or not (m.hopper is Array) or m.level > FIRE_KW.size():
				return false
		elif m.kind == "engine":
			if not m.has_all(_ENGINE_KEYS):
				return false
		elif m.kind == "market":
			if not m.has_all(_MARKET_KEYS) or not (m.wait is Array) or not (m.t is float):
				return false
			for kind: Variant in m.wait:
				if not SELLS.has(kind):
					return false
		elif not m.has_all(_SINK_KEYS) or not (m.got is int) or not (m.left is int):
			return false
		for t: Variant in m.tiles:
			if not (t is Vector2i):
				return false
	return true

func _unpack(d: Dictionary) -> void:
	land_seed = d.seed
	_rng.seed = d.seed
	_rng.state = d.rng
	coins = d.coins
	earned = d.earned
	_acc = clampf(d.acc, 0.0, TICK)
	alpha = clampf(_acc / TICK, 0.0, 1.0)
	_next_id = d.next_id
	picked = d.picked
	plates = (d.plates as Dictionary).duplicate(true)
	sources = (d.sources as Dictionary).duplicate(true)
	trees = (d.trees as Dictionary).duplicate(true)
	belts = (d.belts as Dictionary).duplicate(true)
	kinds = (d.kinds as Dictionary).duplicate(true)
	over = (d.over as Dictionary).duplicate(true)
	_split = (d.split as Dictionary).duplicate(true)
	sold = (d.sold as Dictionary).duplicate(true)
	items = (d.items as Dictionary).duplicate(true)
	modules = (d.modules as Dictionary).duplicate(true)
	_turn = (d.turn as Dictionary).duplicate(true)
	_mod_at = {}
	for id: int in modules:
		for t: Vector2i in modules[id].tiles:
			_mod_at[t] = id
	events = []
	_order_stale = true
	dirty = false
