extends RefCounted

## The Grove, as pure data: a piece of land where trees come up at random
## spots over time, an axe that chops everything standing in a circle round
## a point, and a shop of three tiles and a tree of skills (a trunk of tree
## kinds, two boughs a kind, four roots) bought with the energy the felled
## trees leave.
## Slow and without an end on purpose (the user: "really slow, not something
## the user will nail in two hours", "infinite"): Axe and Seeds have no last
## level, and every richer tree asks 2.6 times the chops for twice the yield,
## so the axe always has something to catch up with.
## Spec docs/superpowers/specs/2026-10-05-valley-grove-design.md.
##
## Nothing here draws, reads the clock or touches the shared inventory. The
## screen (valley/grove_screen.gd) steps it, drains `events` and hands the
## wood of each felled tree to Stock; `tests/_probe_grove.gd` plays it with a
## bot. Positions are in land units, on the ground: x across, y away from
## the back of the land toward the front, LAND the box the land lies in, and
## a tree's position is where its trunk meets the grass.

## The land is seen in isometric since 2026-10-06 (the user: "redesign grove
## game to have a isometric view", then, on the first build's island of
## tiles in three steps, "make a single land piece, no need for aclive,
## declive"): one flat square of ground seen corner on, so a diamond on the
## screen. Here x runs across the screen and y away from the back corner
## toward the front one, so the square lies in these units as a diamond too:
## the points within HALF of the middle of LAND, across and deep added.
const HALF := 520.0
const LAND := Vector2(1040.0, 1040.0)
## A trunk keeps this far inside the land's edge, and TIP from its four
## corners, which are rounded off.
const EDGE := 44.0
const TIP := 120.0
## The ground is seen this deep for its width: a pixel up the screen is
## 1 / DEEP of the land going back.
const DEEP := 0.66
## A tree is chopped along the line it stands on as the land is seen, from
## its foot back to under its crown's middle (the crown is 1.7 of its radius
## up, drawn a quarter over): the finger goes to the tree, not to its foot.
const STAND := 1.7 * 1.25 / DEEP
## Trunks keep this far apart while the land has the room, then SPACE_TIGHT.
const SPACE := 96.0
const SPACE_TIGHT := 66.0

## The shop: three tiles on one row. Everything else is a node of the tree.
const SHOP := ["axe", "reach", "swing"]
## The tree's four roots, left to right, and each root's nodes in the order
## they open: a node is open once the one before it has a level.
const ROOT_ORDER := ["land", "jetty", "beavers", "fortune"]
const ROOTS := {
	"land": ["room", "sprout"],
	"jetty": ["jetty", "tying", "bundle", "raft", "load"],
	"beavers": ["beaver", "teeth"],
	"fortune": ["crit", "critsize", "luck", "crate", "cratesize"],
}
## A node's first price in energy, what each level multiplies it by, and its
## last level (0: it has none). The trunk (`kind:N`) and the boughs (`soft:N`,
## `rich:N`) are priced below, by the kind.
const NODE := {
	"axe": [10.0, 1.38, 0], "reach": [40.0, 2.1, 12], "swing": [30.0, 1.9, 15],
	"room": [12.0, 1.5, 27], "sprout": [15.0, 1.65, 20],
	"jetty": [20.0, 1.45, 20], "tying": [40.0, 1.7, 15], "bundle": [60.0, 2.2, 7],
	"raft": [50.0, 1.7, 15], "load": [300.0, 3.0, 5],
	"beaver": [250.0, 4.0, 5], "teeth": [500.0, 2.4, 5],
	"crit": [80.0, 1.8, 10], "critsize": [150.0, 2.0, 6], "luck": [100.0, 1.8, 10],
	"crate": [200.0, 1.9, 10], "cratesize": [250.0, 1.9, 10],
}
const KIND := [120.0, 7.0]        # kind:N costs 120 * 7^(N-1), N from 1
const SAPLING := 20.0             # the Sapling's own price, for its boughs
const SOFT_PRICE := [0.5, 1.5]    # of the kind's price, a level
const RICH_PRICE := [0.75, 2.25]  # the Sapling's one level: 1.5
const SOFT_STEP := 0.25           # of the kind's chops, a level
const RICH_STEP := 0.5            # of the kind's yield, a level (the Sapling: 1.0)
## No price reads past what an int holds.
const PRICE_CAP := 9.0e18

## A tree of tier 0: four chops for one wood and one energy (the user: "each
## tree start as 4hp"). Every tier after: HP_STEP times the chops, GIVE_STEP
## times the yield.
const HP := 4.0
## What a level of the Axe adds to a chop. It was a whole one, so the first
## level halved the work at a stroke (the user, 2026-10-06: "it's too fast at
## start going from 1 -> 2, let's do 1 -> 1.5"). A tree's hp is a fraction
## from then on: a sapling takes three chops of 1.5, the last finding 1 left.
const AXE_STEP := 0.5
const HP_STEP := 2.6
const GIVE_STEP := 2.0
## The circle's radius, the seconds between chops, the seconds a felled
## tree's place takes to grow another and the trees the land holds, before
## any tile.
const REACH := 90.0
const REACH_STEP := 1.08
const SWING := 0.5
const SWING_STEP := 0.93
const SPROUT := 6.0
const SPROUT_STEP := 0.93
const ROOM := 3
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
## What a kept grove's positions are on: 3 is the one square of land. A
## grove kept on the rectangle or the stepped island before it has its trees
## planted again.
const KEPT_ON := 3

## Every node's level by id, and `seeds`, the trunk's: kind:N is bought when
## seeds has reached N. A kind's boughs are `soft` and `rich`, a level a tier.
var lv := {}
var soft: Array[int] = []
var rich: Array[int] = []
var energy := 0
## Trees standing: {id, tier, pos, hp, born} with `born` on this sim's clock;
## `hp` is whole on a new tree and may be a half after a chop.
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
## The seconds left until each empty place has its tree, one a place. Every
## place counts by itself from the moment its tree came down (the user,
## 2026-10-06: "the count down for each tree should start moment it's
## cutted, not one after another ... if I cut 5 tree same time, it takes 5s
## to respawn 5 trees, not 25 seconds"). There was one wait for the whole
## land before, so five felled at a stroke came back one sprout time apart.
var _due: Array[float] = []
var _last_chop := -10.0

func _init(rng_seed := 0) -> void:
	for id: String in NODE:
		lv[id] = 0
	lv["seeds"] = 0
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_plant(true)
	_owe()

# --- the land ---

## Whether a tree can stand at `p`: on the land, EDGE inside it and clear of
## its corners.
static func stands(p: Vector2) -> bool:
	var d := (p - LAND * 0.5).abs()
	return d.x + d.y <= HALF - EDGE * sqrt(2.0) and maxf(d.x, d.y) <= HALF - TIP

# --- what the tiles are worth ---

## What a chop takes off a tree: one, and AXE_STEP more a level of the Axe.
func power() -> float:
	return 1.0 + AXE_STEP * int(lv.axe)

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

## "kind" / "soft" / "rich" for "kind:3" and the rest; any other id is itself.
static func part_of(id: String) -> String:
	return id.get_slice(":", 0)

## 3 for "soft:3"; -1 for a plain id.
static func tier_of(id: String) -> int:
	return int(id.get_slice(":", 1)) if id.contains(":") else -1

## What a tier's kind costs on the trunk, and what its boughs are priced by.
static func kind_price(tier: int) -> float:
	return SAPLING if tier <= 0 else float(KIND[0]) * pow(float(KIND[1]), tier - 1)

static func _hp_at(tier: int, soft_level: int) -> float:
	return float(hp_of(tier)) * (1.0 - SOFT_STEP * soft_level)

static func _give_at(tier: int, rich_level: int) -> int:
	var step := RICH_STEP * 2.0 if tier == 0 else RICH_STEP
	return int(round(float(give_of(tier)) * (1.0 + step * rich_level)))

static func _int(price: float) -> int:
	return int(round(minf(price, PRICE_CAP)))

## The trunk's next kind answers to its old name, `seeds`.
func _named(id: String) -> String:
	return "kind:%d" % (int(lv.seeds) + 1) if id == "seeds" else id

func level(id: String) -> int:
	var tier := tier_of(id)
	match part_of(id):
		"kind":
			return 1 if int(lv.seeds) >= tier else 0
		"soft":
			return soft[tier] if tier < soft.size() else 0
		"rich":
			return rich[tier] if tier < rich.size() else 0
	return int(lv[id])

## A node's last level (0: it has none): a kind is bought once, a kind's
## boughs twice, the Sapling's Rich bough once.
func last_level(id: String) -> int:
	match part_of(id):
		"kind":
			return 1
		"soft":
			return 2
		"rich":
			return 1 if tier_of(id) == 0 else 2
		"seeds":
			return 0
	return int(NODE[id][2])

func is_done(id: String) -> bool:
	id = _named(id)
	return last_level(id) > 0 and level(id) >= last_level(id)

func cost(id: String) -> int:
	id = _named(id)
	var tier := tier_of(id)
	match part_of(id):
		"kind":
			return _int(kind_price(tier))
		"soft":
			return _int(float(SOFT_PRICE[mini(level(id), 1)]) * kind_price(tier))
		"rich":
			var price: Array = [1.5, 1.5] if tier == 0 else RICH_PRICE
			return _int(float(price[mini(level(id), 1)]) * kind_price(tier))
	return _int(float(NODE[id][0]) * pow(float(NODE[id][1]), level(id)))

## The node that must have a level before this one opens ("" for none).
func before(id: String) -> String:
	id = _named(id)
	var tier := tier_of(id)
	match part_of(id):
		"kind":
			return "" if tier <= 0 else "kind:%d" % (tier - 1)
		"soft", "rich":
			return "" if tier <= 0 else "kind:%d" % tier
	for root: String in ROOT_ORDER:
		var at: int = (ROOTS[root] as Array).find(id)
		if at > 0:
			return ROOTS[root][at - 1]
	return ""

## Open once the node before it has a level, or it has one itself (a kept
## grove's Sprout stays bought whatever Room is).
func is_open(id: String) -> bool:
	id = _named(id)
	var b := before(id)
	return b == "" or level(b) > 0 or level(id) > 0

func can_buy(id: String) -> bool:
	id = _named(id)
	return is_open(id) and not is_done(id) and energy >= cost(id)

func buy(id: String) -> bool:
	id = _named(id)
	if not can_buy(id):
		return false
	var tier := tier_of(id)
	energy -= cost(id)
	match part_of(id):
		"kind":
			lv.seeds = tier
		"soft":
			while soft.size() <= tier:
				soft.append(0)
			soft[tier] += 1
			# a tree of that kind standing takes the new most
			for tree: Dictionary in trees:
				if int(tree.tier) == tier:
					tree.hp = minf(float(tree.hp), hp(tier))
		"rich":
			while rich.size() <= tier:
				rich.append(0)
			rich[tier] += 1
		_:
			lv[id] = int(lv[id]) + 1
	# a place Room has just opened starts to count now, and no place waits
	# longer than a quicker Sprout asks
	_owe()
	for i in _due.size():
		_due[i] = minf(_due[i], spawn_time())
	return true

## The tree's nodes to draw: every root node that has a level or is open, the
## trunk from the Sapling to the next kind, and each owned kind's two boughs.
## Never a shop tile.
func shown() -> Array[String]:
	var out: Array[String] = []
	for tier in int(lv.seeds) + 2:
		out.append("kind:%d" % tier)
	for tier in int(lv.seeds) + 1:
		out.append("soft:%d" % tier)
		out.append("rich:%d" % tier)
	for root: String in ROOT_ORDER:
		for id: String in ROOTS[root]:
			if level(id) > 0 or is_open(id):
				out.append(id)
	return out

## How many of the tree's nodes the energy reaches now.
func reachable() -> int:
	var n := 0
	for id in shown():
		if can_buy(id):
			n += 1
	return n

## A kind's most, with its Soft bough: a tree to fell takes this many points
## of chop. `hp_of` is the same before the boughs.
func hp(tier: int) -> float:
	return _hp_at(tier, level("soft:%d" % tier))

## What a felled tree of a kind gives, with its Rich bough.
func give(tier: int) -> int:
	return _give_at(tier, level("rich:%d" % tier))

## The figure a node stands for at level `at` (-1: the level now): Room the
## trees, Sprout the seconds, a Soft bough the chops and a Rich bough the
## yield of its kind. 0.0 where a node has none (yet).
func value(id: String, at := -1) -> float:
	var n := level(id) if at < 0 else at
	var tier := tier_of(id)
	match part_of(id):
		"soft":
			return _hp_at(tier, n)
		"rich":
			return float(_give_at(tier, n))
	match id:
		"room":
			return float(ROOM + n)
		"sprout":
			return SPROUT * pow(SPROUT_STEP, n)
	return 0.0

# --- time ---

## `dt` seconds pass; `holding` with the circle's centre `at` in land units.
func step(dt: float, holding := false, at := Vector2.ZERO) -> void:
	clock += dt
	_grow(dt, false)
	if holding and clock - _last_chop >= swing_time():
		_chop(at)

## Time passed with nobody here: every empty place went on counting, and
## the ones that got there have their tree. Returns how many did.
func catch_up(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	var came := _grow(seconds, true)
	events.clear()
	return came

## Every empty place is owed a tree: one that has no count yet (a place Room
## opened, a tree taken off the land by hand) starts one now.
func _owe() -> void:
	while trees.size() + _due.size() < room():
		_due.append(spawn_time())
	if trees.size() + _due.size() > room():
		_due.resize(maxi(0, room() - trees.size()))

## `dt` off every empty place's count; a tree where one has run out.
func _grow(dt: float, grown: bool) -> int:
	_owe()
	var came := 0
	var i := 0
	while i < _due.size():
		_due[i] -= dt
		if _due[i] <= 0.0:
			_due.remove_at(i)
			_plant(grown)
			came += 1
		else:
			i += 1
	return came

func _plant(grown: bool) -> void:
	var top := int(lv.seeds)
	var r := _rng.randf()
	var tier := maxi(0, top if r < MIX[0] else (top - 1 if r < MIX[1] else top - 2))
	var pos := _spot()
	var tree := {"id": _next_id, "tier": tier, "pos": pos, "hp": hp(tier),
		"born": clock - GROW if grown else clock}
	_next_id += 1
	trees.append(tree)
	events.append({"kind": "spawn", "tree": tree})

## A free place for a trunk: somewhere a tree can stand, SPACE from every
## other while the land has the room, then SPACE_TIGHT, then anywhere.
func _spot() -> Vector2:
	var pos := LAND * 0.5
	for attempt in 80:
		var at := Vector2(_rng.randf_range(0.0, LAND.x), _rng.randf_range(0.0, LAND.y))
		if not stands(at):
			continue
		pos = at
		var space := SPACE if attempt < 50 else SPACE_TIGHT
		var free := true
		for t in trees:
			if (t.pos as Vector2).distance_to(at) < space:
				free = false
				break
		if free:
			break
	return pos

## The wood this grove makes in a minute with nobody holding the land.
## Nothing chops by itself yet, so there is none: the Valley tab shows a rate
## of zero as "--". Automation, when it is built, answers here.
func wood_per_min() -> float:
	return 0.0

## Whether the circle about `at` takes `tree`: it is chopped along the line
## it stands on, from its foot back to under its crown's middle.
func reaches(tree: Dictionary, at: Vector2) -> bool:
	var r := radius_of(tree.tier)
	var foot: Vector2 = tree.pos
	var near := Geometry2D.get_closest_point_to_segment(at, foot, foot + Vector2(0.0, -r * STAND))
	return near.distance_to(at) <= reach() + r * 0.6

## One chop: everything standing in the circle takes the axe.
func _chop(at: Vector2) -> void:
	_last_chop = clock
	var hits := 0
	for tree: Dictionary in trees.duplicate():
		if not reaches(tree, at):
			continue
		hits += 1
		tree.hp = float(tree.hp) - power()
		events.append({"kind": "hit", "tree": tree, "amount": power()})
		if tree.hp <= 0:
			trees.erase(tree)
			_due.append(spawn_time())
			var gave := give(tree.tier)
			energy += gave
			wood_made += gave
			felled += 1
			events.append({"kind": "fell", "tree": tree, "give": gave})
	events.append({"kind": "swing", "at": at, "hits": hits})

# --- keeping ---

## Writes the grove to `path`, stamped `now` (unix seconds).
func save(now: float) -> void:
	var cfg := ConfigFile.new()
	for id: String in lv:
		cfg.set_value("lv", id, int(lv[id]))
	cfg.set_value("tree", "soft", Array(soft))
	cfg.set_value("tree", "rich", Array(rich))
	cfg.set_value("grove", "energy", energy)
	cfg.set_value("grove", "wood_made", wood_made)
	cfg.set_value("grove", "felled", felled)
	cfg.set_value("grove", "seen", now)
	_owe()
	cfg.set_value("grove", "due", Array(_due))
	cfg.set_value("grove", "land", KEPT_ON)
	var kept := []
	for t in trees:
		kept.append([int(t.tier), (t.pos as Vector2).x, (t.pos as Vector2).y, float(t.hp)])
	cfg.set_value("grove", "trees", kept)
	cfg.save(path)

## The grove as it was left, with the trees that came up since. A first
## visit, or a file that cannot be read, is a new grove: one sapling.
static func load_saved(now: float) -> RefCounted:
	var sim: RefCounted = (load("res://valley/grove_sim.gd") as GDScript).new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section_key("grove", "seen"):
		return sim
	for id: String in sim.lv:
		var kept := maxi(0, int(cfg.get_value("lv", id, 0)))
		sim.lv[id] = kept if sim.last_level(id) == 0 else mini(kept, sim.last_level(id))
	# a kind's boughs: a level a tier, never past the kinds the trunk has
	for part: String in ["soft", "rich"]:
		var rows: Array = cfg.get_value("tree", part, [])
		var into: Array[int] = sim.soft if part == "soft" else sim.rich
		for tier in mini(rows.size(), int(sim.lv.seeds) + 1):
			into.append(clampi(int(rows[tier]), 0, sim.last_level("%s:%d" % [part, tier])))
	sim.energy = maxi(0, int(cfg.get_value("grove", "energy", 0)))
	sim.wood_made = maxi(0, int(cfg.get_value("grove", "wood_made", 0)))
	sim.felled = maxi(0, int(cfg.get_value("grove", "felled", 0)))
	sim.trees.clear()
	var same_land := int(cfg.get_value("grove", "land", 1)) == KEPT_ON
	for row in cfg.get_value("grove", "trees", []):
		if not (row is Array) or (row as Array).size() < 4 or sim.trees.size() >= sim.room():
			continue
		var tier := maxi(0, int(row[0]))
		var pos := Vector2(float(row[1]), float(row[2]))
		if not same_land or not stands(pos):
			pos = sim._spot()
		sim.trees.append({"id": sim._next_id, "tier": tier, "pos": pos,
			"hp": clampf(float(row[3]), 0.5, sim.hp(tier)), "born": -GROW})
		sim._next_id += 1
	sim._due.clear()
	var every: float = sim.spawn_time()
	for left in cfg.get_value("grove", "due", []):
		if sim.trees.size() + sim._due.size() < sim.room():
			sim._due.append(clampf(float(left), 0.0, every))
	# a grove kept before 2026-10-06 had one wait for the whole land: the
	# first empty place takes what was left of it, the rest start now
	if not cfg.has_section_key("grove", "due") and sim.trees.size() < sim.room():
		sim._due.append(clampf(every - float(cfg.get_value("grove", "wait", 0.0)), 0.0, every))
	sim._owe()
	sim.events.clear()
	# a clock set back pays nothing; one set forward fills the land, no more
	sim.catch_up(now - float(cfg.get_value("grove", "seen", now)))
	return sim
