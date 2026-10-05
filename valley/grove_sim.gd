extends RefCounted

## The Grove, as pure data: a piece of land where trees come up at random
## spots over time, an axe that chops everything standing in a circle round
## a point, and six tiles bought with the energy the felled trees leave.
## Slow and without an end on purpose (the user: "really slow, not something
## the user will nail in two hours", "infinite"): Axe and Seeds have no last
## level, and every richer tree asks 2.6 times the chops for twice the yield,
## so the axe always has something to catch up with.
## Spec docs/superpowers/specs/2026-10-05-valley-grove-design.md.
##
## Nothing here draws, reads the clock or touches the shared inventory. The
## screen (valley/grove_screen.gd) steps it, drains `events` and hands the
## wood of each felled tree to Stock; `tests/_probe_grove.gd` plays it with a
## bot. Positions are in land units: (0, 0) is the land's top left corner,
## LAND its size, and a tree's position is where its trunk meets the grass.

## The land, and how far a trunk keeps from its sides: more at the top, where
## the crown would otherwise hang over the water.
const LAND := Vector2(810.0, 800.0)
const EDGE := 70.0
const EDGE_TOP := 150.0
const EDGE_BOTTOM := 40.0
## Trunks keep this far apart while the land has the room, then SPACE_TIGHT.
const SPACE := 96.0
const SPACE_TIGHT := 66.0

const TILES := ["axe", "reach", "swing", "sprout", "room", "seeds"]
## A tile's first price in energy, what each level multiplies it by, and its
## last level (0: it has none).
const TILE := {
	"axe": [10.0, 1.38, 0],
	"reach": [40.0, 2.1, 12],
	"swing": [30.0, 1.9, 15],
	"sprout": [15.0, 1.65, 20],
	"room": [12.0, 1.5, 27],
	"seeds": [120.0, 7.0, 0],
}

## A tree of tier 0: four chops for one wood and one energy (the user: "each
## tree start as 4hp"). Every tier after: HP_STEP times the chops, GIVE_STEP
## times the yield.
const HP := 4.0
const HP_STEP := 2.6
const GIVE_STEP := 2.0
## The circle's radius, the seconds between chops, the seconds between
## trees and the trees the land holds, before any tile.
const REACH := 90.0
const REACH_STEP := 1.08
const SWING := 0.5
const SWING_STEP := 0.93
const SPROUT := 6.0
const SPROUT_STEP := 0.93
const ROOM := 3
## The wait for the next tree is the sprout time times something in here.
const GAP_MIN := 0.6
const GAP_MAX := 1.4
## A new tree is the best tier opened this often, the one below it up to the
## second figure, the one below that for the rest.
const MIX := [0.55, 0.85]
## Five looks (sapling, birch, oak, pine, blossom); past the fifth tier they
## come round again from the birch, with a gold mark a lap.
const LOOKS := 5
## A crown's half width for each look, which is also how far a tree reaches
## into the circle.
const RADIUS := [24.0, 34.0, 44.0, 42.0, 52.0]
## Seconds a new tree takes to grow in. It can be chopped from the start.
const GROW := 1.6

## Where the grove is kept. A harness points this elsewhere.
static var path := "user://grove.cfg"

var lv := {"axe": 0, "reach": 0, "swing": 0, "sprout": 0, "room": 0, "seeds": 0}
var energy := 0
## Trees standing: {id, tier, pos, hp, born} with `born` on this sim's clock.
var trees: Array[Dictionary] = []
var clock := 0.0
## What happened since the screen last looked, oldest first:
## {kind: "spawn", tree}, {kind: "swing", at, hits},
## {kind: "hit", tree, amount}, {kind: "fell", tree, give}.
var events: Array[Dictionary] = []
## All the wood this grove has made and all the trees felled, for the record.
var wood_made := 0
var felled := 0

var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _wait := 0.0
var _gap := SPROUT
var _last_chop := -10.0

func _init(rng_seed := 0) -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_gap = spawn_time()
	_plant(true)

# --- what the tiles are worth ---

func power() -> int:
	return 1 + int(lv.axe)

func reach() -> float:
	return REACH * pow(REACH_STEP, int(lv.reach))

func swing_time() -> float:
	return SWING * pow(SWING_STEP, int(lv.swing))

func spawn_time() -> float:
	return SPROUT * pow(SPROUT_STEP, int(lv.sprout))

func room() -> int:
	return ROOM + int(lv.room)

static func hp_of(tier: int) -> int:
	return int(round(HP * pow(HP_STEP, tier)))

static func give_of(tier: int) -> int:
	return int(round(pow(GIVE_STEP, tier)))

static func look_of(tier: int) -> int:
	return tier if tier < LOOKS else 1 + (tier - LOOKS) % (LOOKS - 1)

## How many times the looks have come round: the gold marks under a tree.
static func lap_of(tier: int) -> int:
	@warning_ignore("integer_division")
	return 0 if tier < LOOKS else 1 + (tier - LOOKS) / (LOOKS - 1)

static func radius_of(tier: int) -> float:
	return RADIUS[look_of(tier)]

func last_level(tile: String) -> int:
	return int(TILE[tile][2])

func is_done(tile: String) -> bool:
	return last_level(tile) > 0 and int(lv[tile]) >= last_level(tile)

func cost(tile: String) -> int:
	return int(round(float(TILE[tile][0]) * pow(float(TILE[tile][1]), int(lv[tile]))))

func can_buy(tile: String) -> bool:
	return not is_done(tile) and energy >= cost(tile)

func buy(tile: String) -> bool:
	if not can_buy(tile):
		return false
	energy -= cost(tile)
	lv[tile] = int(lv[tile]) + 1
	return true

# --- time ---

## `dt` seconds pass; `holding` with the circle's centre `at` in land units.
func step(dt: float, holding := false, at := Vector2.ZERO) -> void:
	clock += dt
	if trees.size() < room():
		_wait += dt
		if _wait >= _gap:
			_wait = 0.0
			_gap = spawn_time() * _rng.randf_range(GAP_MIN, GAP_MAX)
			_plant(false)
	else:
		# a full land has its next tree ready for the moment there is room
		_wait = minf(_wait + dt, _gap)
	if holding and clock - _last_chop >= swing_time():
		_chop(at)

## Time passed with nobody here: trees came up at the sprout time until the
## land was full. Returns how many did.
func catch_up(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	var came := 0
	var left := seconds + _wait
	while trees.size() < room() and left >= spawn_time():
		left -= spawn_time()
		_plant(true)
		came += 1
	_wait = minf(left, _gap) if trees.size() < room() else _gap
	events.clear()
	return came

func _plant(grown: bool) -> void:
	var top := int(lv.seeds)
	var r := _rng.randf()
	var tier := maxi(0, top if r < MIX[0] else (top - 1 if r < MIX[1] else top - 2))
	var pos := Vector2.ZERO
	for attempt in 24:
		pos = Vector2(_rng.randf_range(EDGE, LAND.x - EDGE), _rng.randf_range(EDGE_TOP, LAND.y - EDGE_BOTTOM))
		var space := SPACE if attempt < 16 else SPACE_TIGHT
		var free := true
		for t in trees:
			if (t.pos as Vector2).distance_to(pos) < space:
				free = false
				break
		if free:
			break
	var tree := {"id": _next_id, "tier": tier, "pos": pos, "hp": hp_of(tier),
		"born": clock - GROW if grown else clock}
	_next_id += 1
	trees.append(tree)
	events.append({"kind": "spawn", "tree": tree})

## One chop: everything standing in the circle takes the axe.
func _chop(at: Vector2) -> void:
	_last_chop = clock
	var hits := 0
	for tree: Dictionary in trees.duplicate():
		var r := radius_of(tree.tier)
		if (tree.pos + Vector2(0.0, -r)).distance_to(at) > reach() + r * 0.6:
			continue
		hits += 1
		tree.hp = int(tree.hp) - power()
		events.append({"kind": "hit", "tree": tree, "amount": power()})
		if tree.hp <= 0:
			trees.erase(tree)
			var give := give_of(tree.tier)
			energy += give
			wood_made += give
			felled += 1
			events.append({"kind": "fell", "tree": tree, "give": give})
	events.append({"kind": "swing", "at": at, "hits": hits})

# --- keeping ---

## Writes the grove to `path`, stamped `now` (unix seconds).
func save(now: float) -> void:
	var cfg := ConfigFile.new()
	for tile: String in TILES:
		cfg.set_value("lv", tile, int(lv[tile]))
	cfg.set_value("grove", "energy", energy)
	cfg.set_value("grove", "wood_made", wood_made)
	cfg.set_value("grove", "felled", felled)
	cfg.set_value("grove", "seen", now)
	cfg.set_value("grove", "wait", _wait)
	var kept := []
	for t in trees:
		kept.append([int(t.tier), (t.pos as Vector2).x, (t.pos as Vector2).y, int(t.hp)])
	cfg.set_value("grove", "trees", kept)
	cfg.save(path)

## The grove as it was left, with the trees that came up since. A first
## visit, or a file that cannot be read, is a new grove: one sapling.
static func load_saved(now: float) -> RefCounted:
	var sim: RefCounted = (load("res://valley/grove_sim.gd") as GDScript).new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section_key("grove", "seen"):
		return sim
	for tile: String in TILES:
		var level := maxi(0, int(cfg.get_value("lv", tile, 0)))
		sim.lv[tile] = level if sim.last_level(tile) == 0 else mini(level, sim.last_level(tile))
	sim.energy = maxi(0, int(cfg.get_value("grove", "energy", 0)))
	sim.wood_made = maxi(0, int(cfg.get_value("grove", "wood_made", 0)))
	sim.felled = maxi(0, int(cfg.get_value("grove", "felled", 0)))
	sim.trees.clear()
	for row in cfg.get_value("grove", "trees", []):
		if not (row is Array) or (row as Array).size() < 4 or sim.trees.size() >= sim.room():
			continue
		var tier := maxi(0, int(row[0]))
		var pos := Vector2(clampf(float(row[1]), EDGE, LAND.x - EDGE), clampf(float(row[2]), EDGE_TOP, LAND.y - EDGE_BOTTOM))
		sim.trees.append({"id": sim._next_id, "tier": tier, "pos": pos,
			"hp": clampi(int(row[3]), 1, hp_of(tier)), "born": -GROW})
		sim._next_id += 1
	sim._gap = sim.spawn_time()
	sim._wait = clampf(float(cfg.get_value("grove", "wait", 0.0)), 0.0, sim._gap)
	sim.events.clear()
	# a clock set back pays nothing; one set forward fills the land, no more
	sim.catch_up(now - float(cfg.get_value("grove", "seen", now)))
	return sim
