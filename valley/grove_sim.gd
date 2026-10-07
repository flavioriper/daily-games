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
## A felled tree's wood is not wood in the valley yet (2026-10-07, spec
## docs/superpowers/specs/2026-10-07-grove-tree-and-jetty-design.md): it lies
## where the tree stood as a pile, the circle gathers piles to a jetty, the
## jetty ties them into bundles and a raft takes the bundles away. What the
## raft has landed is `owed`.
##
## Nothing here draws, reads the clock or touches the shared inventory. The
## screen (valley/grove_screen.gd) steps it, drains `events` and hands what
## the raft has landed (`take_owed`) to Stock; `tests/_probe_grove.gd` plays
## it with a bot. Positions are in land units, on the ground: x across, y
## away from the back of the land toward the front, LAND the box the land
## lies in, and a tree's position is where its trunk meets the grass.

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
	"jetty": ["raft", "jetty", "bundle", "tying", "load"],
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
const SOFT_STEP := 0.25           # of the kind's chops, a level
## A Rich bough: its price a level (of the kind's price), what a level adds to
## the kind's yield, and its last level. The Sapling's is its own, here and
## nowhere else: one level, which doubles it.
const RICH := {"price": [0.75, 2.25], "step": 0.5, "last": 2}
const RICH_SAPLING := {"price": [1.5], "step": 1.0, "last": 1}
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
## A tree with less than this left is down: a beaver's bite is a share of a
## chop (0.6 of 1.5), so what is left of a tree is not always a round figure.
const DOWN := 0.001
## Two things of the jetty due this near each other happen together.
const SOON := 0.000001

## The jetty. A felled tree's wood lies where it stood as a pile; the circle
## gathers piles to the jetty, where they are tied into bundles that a raft
## takes away. The chain counts piles, not wood: it is measured in the unit
## the axe is, trees a minute.
const MERGE := 70.0      # a pile that comes down this near another joins it
const LIES := 0.9        # seconds before a pile can be gathered (the fall)
const JETTY := 6         # piles the jetty holds, loose and bundled
const JETTY_STEP := 2
const TIE := 12.0        # seconds to tie a bundle
const TIE_STEP := 0.9
const BUNDLE := 3        # piles a bundle
const RAFT := 24.0       # seconds there and back; the wood lands half way
const RAFT_STEP := 0.92
## A beaver of the grove's own: a bite every BITE_EVERY seconds, for this
## share of the axe's chop and BITE_STEP more a level of Teeth.
const BITE_EVERY := 1.0
const BITE := 0.5
const BITE_STEP := 0.1
## A keen chop: the chance a level, how many chops it counts for, and what a
## level of Heavy blow adds to that.
const CRIT_STEP := 0.05
const CRIT_SIZE := 2.0
const CRIT_SIZE_STEP := 0.5
## The chance a level that a felled tree's pile is worth double.
const LUCK_STEP := 0.04
## A crate: the seconds between two, the felled trees of the best kind it is
## worth in energy, and the share of that a level of Full crates adds. It
## washes up within SHORE of one of the land's two front edges.
const CRATE := 180.0
const CRATE_STEP := 0.9
const CRATE_GIVE := 15
const CRATE_GIVE_STEP := 0.2
const SHORE := 140.0

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
## {kind: "hit", tree, amount, keen, by} (`by` "axe" or "beaver"; a bite is
## never keen), {kind: "fell", tree, give, lucky, by} (`give` the energy),
## {kind: "log", log} (the pile that fell's wood came down as, or the stack
## it joined), {kind: "gather", pos, tier, n, wood} (piles off the land to
## the jetty), {kind: "full", pos} (a swing over a pile the jetty had no room
## for), {kind: "tied", n, wood}, {kind: "sailed", n, wood, bundles},
## {kind: "landed", wood}, {kind: "crate", pos}, {kind: "opened", pos, give}.
var events: Array[Dictionary] = []
## All the wood this grove has made, counted as its tree comes down (a lucky
## pile's double with it), and all the trees felled, for the record.
var wood_made := 0
var felled := 0

## Piles lying on the land: {id, pos, n, wood, tier, lucky, born}. A stack is
## `n` piles holding `wood` between them; `tier` is its richest kind, `lucky`
## that a double pile is in it, and `born` when its last pile came down.
var logs: Array[Dictionary] = []
## On the jetty: the piles not tied yet, and the bundles waiting for the
## raft, each {n, wood}.
var loose := {"n": 0, "wood": 0}
var bundles: Array[Dictionary] = []
## The raft: `t` seconds out since it left, `n` piles and `wood` aboard in
## `bundles` bundles until it lands them at half its time, `away` until it is
## home again.
var raft := {"n": 0, "wood": 0, "bundles": 0, "t": 0.0, "away": false}
## Seconds into the bundle being tied.
var tie_t := 0.0
## Wood the raft has landed that Stock has not been given: whoever holds the
## sim takes it (`take_owed`). `wood_sent` is all it ever landed.
var owed := 0
var wood_sent := 0
## The crate lying on the land, {pos}, or {} for none.
var crate := {}
## A beaver each: {tree, t}, the id of the tree it is at (0: resting) and the
## seconds since its last bite.
var gnawing: Array[Dictionary] = []

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
var _next_log := 1
## Seconds counted toward the next crate, while none lies.
var _crate_t := 0.0

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
	return _figure("sprout", int(lv.sprout))

func room() -> int:
	return int(_figure("room", int(lv.room)))

## A root node's figure at level `n`, in the unit its line on the Skills card
## is written in: a count, seconds, a percent (25.0 is 25%), chops. Every
## reader below and `value` answer from here, so the card and the land cannot
## say two things.
func _figure(id: String, n: int) -> float:
	match id:
		"room":
			return float(ROOM + n)
		"sprout":
			return SPROUT * pow(SPROUT_STEP, n)
		"jetty":
			return float(JETTY + JETTY_STEP * n)
		"tying":
			return TIE * pow(TIE_STEP, n)
		"bundle":
			return float(BUNDLE + n)
		"raft":
			return RAFT * pow(RAFT_STEP, n)
		"load":
			return float(1 + n)
		"beaver":
			return float(n)
		"teeth":
			return 100.0 * (BITE + BITE_STEP * n)
		"crit":
			return 100.0 * CRIT_STEP * n
		"critsize":
			return CRIT_SIZE + CRIT_SIZE_STEP * n
		"luck":
			return 100.0 * LUCK_STEP * n
		"crate":
			return 0.0 if n <= 0 else CRATE * pow(CRATE_STEP, n - 1)
		"cratesize":
			return float(CRATE_GIVE * give_of(int(lv.seeds))) * (1.0 + CRATE_GIVE_STEP * n)
	return 0.0

# --- the jetty, the beavers and fortune, as they are now ---

## Piles the jetty has room for, and holds: the loose ones and the ones in
## bundles waiting, not what is on the raft.
func jetty_room() -> int:
	return int(_figure("jetty", int(lv.jetty)))

func jetty_held() -> int:
	var n := int(loose.n)
	for b: Dictionary in bundles:
		n += int(b.n)
	return n

func tie_time() -> float:
	return _figure("tying", int(lv.tying))

func bundle_size() -> int:
	return int(_figure("bundle", int(lv.bundle)))

## Seconds the raft takes there and back, and the bundles it carries.
func raft_time() -> float:
	return _figure("raft", int(lv.raft))

func raft_load() -> int:
	return int(_figure("load", int(lv.load)))

## Where the raft is: 0 home, 1 at the far side, and back to 0.
func raft_at() -> float:
	if not raft.away:
		return 0.0
	return clampf(1.0 - absf(2.0 * float(raft.t) / raft_time() - 1.0), 0.0, 1.0)

## Piles lying on the land, stacks counted through.
func lying() -> int:
	var n := 0
	for pile: Dictionary in logs:
		n += int(pile.n)
	return n

func beavers() -> int:
	return int(lv.beaver)

## The share of `power()` a beaver's bite takes.
func bite() -> float:
	return _figure("teeth", int(lv.teeth)) / 100.0

## The chance a chop is keen, and how many chops a keen one counts for.
func crit_chance() -> float:
	return _figure("crit", int(lv.crit)) / 100.0

func crit_size() -> float:
	return _figure("critsize", int(lv.critsize))

## The chance a felled tree's pile is worth double.
func luck_chance() -> float:
	return _figure("luck", int(lv.luck)) / 100.0

## Seconds between two crates (0.0 without the node), and the energy in one.
func crate_time() -> float:
	return _figure("crate", int(lv.crate))

func crate_give() -> int:
	return int(round(_figure("cratesize", int(lv.cratesize))))

## What the raft has landed since this was last asked: the holder's, to hand
## to Stock.
func take_owed() -> int:
	var n := owed
	owed = 0
	return n

## Whether the land still grows a kind: the best opened and the two under it
## (MIX). A kind gone from the land keeps its boughs, which cannot be bought.
func grows(tier: int) -> bool:
	return tier >= int(lv.seeds) - 2

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

## What a kind's Rich bough is: RICH, but for the Sapling's.
static func rich_of(tier: int) -> Dictionary:
	return RICH_SAPLING if tier == 0 else RICH

static func _give_at(tier: int, rich_level: int) -> int:
	return int(round(float(give_of(tier)) * (1.0 + float(rich_of(tier).step) * rich_level)))

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
			return int(rich_of(tier_of(id)).last)
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
			var price: Array = rich_of(tier).price
			return _int(float(price[mini(level(id), price.size() - 1)]) * kind_price(tier))
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
	var part := part_of(id)
	if (part == "soft" or part == "rich") and not grows(tier_of(id)):
		return false
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

## The figure a node stands for at level `at` (-1: the level now), which the
## Skills card writes its line from: a Soft bough the chops and a Rich bough
## the yield of its kind; Room the trees, Sprout the seconds, Jetty the piles
## it holds, Tying the seconds a bundle, Bundle the piles in one, Raft the
## seconds there and back, Load the bundles aboard, Beavers how many, Teeth
## the percent of a chop a bite is, Keen edge and Lucky wood the percent of
## the time, Heavy blow the chops a keen one counts for, Crates the seconds
## between two (0.0 before the first level), Full crates the energy in one.
## 0.0 for a shop tile and a kind.
func value(id: String, at := -1) -> float:
	var n := level(id) if at < 0 else at
	var tier := tier_of(id)
	match part_of(id):
		"soft":
			return _hp_at(tier, n)
		"rich":
			return float(_give_at(tier, n))
		"kind":
			return 0.0
	return _figure(id, n)

# --- time ---

## `dt` seconds pass; `holding` with the circle's centre `at` in land units.
func step(dt: float, holding := false, at := Vector2.ZERO) -> void:
	clock += dt
	_grow(dt, false)
	_gnaw(dt)
	if holding and clock - _last_chop >= swing_time():
		_chop(at)
	_send(dt)
	_wash(dt)

## Time passed with nobody here: every empty place went on counting, and
## the ones that got there have their tree (returns how many did); the
## beavers felled their share, whose piles lie; what was on the jetty was
## tied and rafted (`owed` holds what landed); a crate may have washed up.
## All of it worked out, none of it run: a month costs what a minute does.
func catch_up(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	var came := _grow(seconds, true)
	_gnaw_away(seconds)
	_send(seconds)
	_wash(seconds)
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

## The kind a new tree is: the best opened, or one of the two under it.
func _kind() -> int:
	var top := int(lv.seeds)
	var r := _rng.randf()
	return maxi(0, top if r < MIX[0] else (top - 1 if r < MIX[1] else top - 2))

func _plant(grown: bool) -> void:
	var tier := _kind()
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

## The most wood the jetty can send in a minute at its levels: the slower of
## tying and rafting, in piles, times what a pile of the land's mix is worth
## (a lucky one double). It is what the Valley tab's chip shows; the land
## may fell more than this or less.
func wood_per_min() -> float:
	var size := float(bundle_size())
	var piles := minf(size / tie_time(), size * raft_load() / raft_time()) * 60.0
	var top := int(lv.seeds)
	var worth: float = MIX[0] * give(top) + (MIX[1] - MIX[0]) * give(maxi(0, top - 1)) + (1.0 - MIX[1]) * give(maxi(0, top - 2))
	return piles * worth * (1.0 + luck_chance())

## Whether the circle about `at` takes `tree`: it is chopped along the line
## it stands on, from its foot back to under its crown's middle.
func reaches(tree: Dictionary, at: Vector2) -> bool:
	var r := radius_of(tree.tier)
	var foot: Vector2 = tree.pos
	var near := Geometry2D.get_closest_point_to_segment(at, foot, foot + Vector2(0.0, -r * STAND))
	return near.distance_to(at) <= reach() + r * 0.6

## One chop: everything standing in the circle takes the axe, each tree with
## its own chance of a keen chop. Then the circle gathers the piles under it
## and opens a crate.
func _chop(at: Vector2) -> void:
	_last_chop = clock
	var hits := 0
	var keen_at := crit_chance()
	for tree: Dictionary in trees.duplicate():
		if not reaches(tree, at):
			continue
		hits += 1
		var keen := keen_at > 0.0 and _rng.randf() < keen_at
		_hurt(tree, power() * crit_size() if keen else power(), keen, "axe")
	events.append({"kind": "swing", "at": at, "hits": hits})
	_gather(at)
	if not crate.is_empty() and (crate.pos as Vector2).distance_to(at) <= reach():
		var got := crate_give()
		energy += got
		events.append({"kind": "opened", "pos": crate.pos, "give": got})
		crate = {}
		_crate_t = 0.0

## `amount` off a tree, by the axe or by a beaver. With nothing left it falls.
func _hurt(tree: Dictionary, amount: float, keen: bool, by: String) -> void:
	tree.hp = float(tree.hp) - amount
	events.append({"kind": "hit", "tree": tree, "amount": amount, "keen": keen, "by": by})
	if float(tree.hp) < DOWN:
		_fell(tree, by)

## A tree comes down: its place starts to count, its energy is given at once
## and its wood lies where it stood. A beaver that was at it rests.
func _fell(tree: Dictionary, by: String) -> void:
	trees.erase(tree)
	_due.append(spawn_time())
	for b: Dictionary in gnawing:
		if int(b.tree) == int(tree.id):
			b.tree = 0
			b.t = 0.0
	var left := _leave(int(tree.tier), tree.pos)
	events.append({"kind": "fell", "tree": tree, "give": left.give, "lucky": left.lucky, "by": by})
	events.append({"kind": "log", "log": left.pile})

## What a felled tree of a kind leaves at `pos`: its energy, and its wood as
## a pile, worth double when luck has it (the energy is never doubled: luck
## is wood through the same raft). Returns {give, lucky, pile}.
func _leave(tier: int, pos: Vector2) -> Dictionary:
	var gave := give(tier)
	var chance := luck_chance()
	var lucky := chance > 0.0 and _rng.randf() < chance
	var wood := gave * 2 if lucky else gave
	energy += gave
	wood_made += wood
	felled += 1
	return {"give": gave, "lucky": lucky, "pile": _drop(pos, tier, wood, lucky)}

# --- the jetty ---

## A pile of `wood` comes down at `pos`, or on the nearest stack within MERGE
## of it, so a land chopped for an hour is not a thousand piles. A stack has
## lain since its last pile came down.
func _drop(pos: Vector2, tier: int, wood: int, lucky: bool) -> Dictionary:
	var onto := {}
	var near := MERGE
	for pile: Dictionary in logs:
		var d := (pile.pos as Vector2).distance_to(pos)
		if d < near:
			near = d
			onto = pile
	if onto.is_empty():
		onto = {"id": _next_log, "pos": pos, "n": 0, "wood": 0, "tier": tier, "lucky": false, "born": clock}
		_next_log += 1
		logs.append(onto)
	onto.n = int(onto.n) + 1
	onto.wood = int(onto.wood) + wood
	onto.tier = maxi(int(onto.tier), tier)
	onto.lucky = bool(onto.lucky) or lucky
	onto.born = clock
	return onto

## The wood of `take` piles out of `n` holding `wood`: the whole when all are
## taken, and never a fraction, so what is taken and what is left are always
## exactly what was there. Each pile is at least one wood on both sides.
static func _share(wood: int, take: int, n: int) -> int:
	if take >= n:
		return wood
	@warning_ignore("integer_division")
	return (wood / n) * take + (wood % n) * take / n

## The circle about `at` gathers: every pile under it that has lain LIES goes
## to the jetty, oldest first, as many of a stack as the jetty has room for.
## A full jetty takes none: piles lie, and never rot.
func _gather(at: Vector2) -> void:
	if logs.is_empty():
		return
	var free := jetty_room() - jetty_held()
	var far := reach()
	var refused := false
	var i := 0
	while i < logs.size():
		var pile: Dictionary = logs[i]
		i += 1
		if clock - float(pile.born) < LIES or (pile.pos as Vector2).distance_to(at) > far:
			continue
		if free <= 0:
			if not refused:
				refused = true
				events.append({"kind": "full", "pos": pile.pos})
			continue
		var take := mini(int(pile.n), free)
		var wood := _share(int(pile.wood), take, int(pile.n))
		pile.n = int(pile.n) - take
		pile.wood = int(pile.wood) - wood
		loose.n = int(loose.n) + take
		loose.wood = int(loose.wood) + wood
		free -= take
		if int(pile.n) <= 0:
			i -= 1
			logs.remove_at(i)
		events.append({"kind": "gather", "pos": pile.pos, "tier": pile.tier, "n": take, "wood": wood})

## The jetty's chain over `dt` seconds, by what happens next and not by the
## second, so any `dt` costs the same: a frame, or three days away.
## - Tying runs while a whole bundle's worth of loose piles is there, or
##   while any are with the raft home and no bundle waiting: a short bundle
##   is tied only when the chain would otherwise stand still, so it never
##   takes a place on the raft that a whole one wanted, and no pile is ever
##   stranded. It takes its piles when its time is up.
## - The raft, home with a bundle waiting, takes as many as it carries and
##   goes; half its time out its wood is landed (`owed`, `wood_sent`), and at
##   the whole it is home.
func _send(dt: float) -> void:
	if int(loose.n) <= 0 and bundles.is_empty() and not raft.away:
		tie_t = 0.0
		return
	var left := dt
	# every turn ties, lands or brings the raft home, and the jetty holds a
	# few dozen piles: the bound is never met
	for _turn in 4096:
		if not raft.away and not bundles.is_empty():
			_sail()
		var tying: bool = int(loose.n) >= bundle_size() or (int(loose.n) > 0 and not raft.away and bundles.is_empty())
		if not tying:
			tie_t = 0.0
		if left <= 0.0 or not (tying or raft.away):
			return
		var loaded: bool = int(raft.n) > 0
		var next := left
		if tying:
			next = minf(next, tie_time() - tie_t)
		if raft.away:
			next = minf(next, raft_time() * (0.5 if loaded else 1.0) - float(raft.t))
		next = maxf(next, 0.0)
		left -= next
		if tying:
			tie_t += next
			if tie_t >= tie_time() - SOON:
				_tie()
		if raft.away:
			raft.t = float(raft.t) + next
			if loaded and float(raft.t) >= raft_time() * 0.5 - SOON:
				_land()
			if float(raft.t) >= raft_time() - SOON:
				raft.away = false
				raft.t = 0.0

## Up to a bundle's worth of the loose piles become a bundle.
func _tie() -> void:
	var take := mini(int(loose.n), bundle_size())
	var wood := _share(int(loose.wood), take, int(loose.n))
	loose.n = int(loose.n) - take
	loose.wood = int(loose.wood) - wood
	tie_t = 0.0
	bundles.append({"n": take, "wood": wood})
	events.append({"kind": "tied", "n": take, "wood": wood})

## The raft takes the bundles that waited longest, as many as it carries.
func _sail() -> void:
	var aboard := mini(bundles.size(), raft_load())
	raft.n = 0
	raft.wood = 0
	for i in aboard:
		var b: Dictionary = bundles.pop_front()
		raft.n = int(raft.n) + int(b.n)
		raft.wood = int(raft.wood) + int(b.wood)
	raft.bundles = aboard
	raft.t = 0.0
	raft.away = true
	events.append({"kind": "sailed", "n": raft.n, "wood": raft.wood, "bundles": aboard})

## The raft is at the far side: its wood is wood in the valley, once the
## holder has taken it.
func _land() -> void:
	var wood := int(raft.wood)
	owed += wood
	wood_sent += wood
	raft.n = 0
	raft.wood = 0
	raft.bundles = 0
	events.append({"kind": "landed", "wood": wood})

# --- the beavers ---

## The grove's own beavers. Each takes the oldest standing tree no other has
## and bites it every BITE_EVERY for its share of a chop. With someone here
## one rests only while it has no tree to go to, however many piles lie.
func _gnaw(dt: float) -> void:
	var team := beavers()
	if gnawing.size() != team:
		while gnawing.size() < team:
			gnawing.append({"tree": 0, "t": 0.0})
		gnawing.resize(team)
	for b: Dictionary in gnawing:
		var tree := _standing(int(b.tree))
		if tree.is_empty():
			tree = _untaken()
			b.t = 0.0
			b.tree = 0 if tree.is_empty() else int(tree.id)
			if tree.is_empty():
				continue
		b.t = float(b.t) + dt
		if float(b.t) >= BITE_EVERY:
			b.t = fmod(float(b.t), BITE_EVERY)
			_hurt(tree, power() * bite(), false, "beaver")

## The tree standing with this id, or {}.
func _standing(id: int) -> Dictionary:
	if id > 0:
		for tree: Dictionary in trees:
			if int(tree.id) == id:
				return tree
	return {}

## The oldest tree standing that no beaver is at, or {}.
func _untaken() -> Dictionary:
	for tree: Dictionary in trees:
		var taken := false
		for b: Dictionary in gnawing:
			if int(b.tree) == int(tree.id):
				taken = true
				break
		if not taken:
			return tree
	return {}

## The beavers' share of `seconds` with nobody here: the land once over for
## each beaver at most (trees away fill the land once and no further, and a
## beaver's share is the same size), fewer when the seconds do not cover
## them. Each tree is of a kind the land grows, takes the seconds all the
## beavers together need to bite through it, gives its energy and leaves its
## pile somewhere a tree could stand. A beaver gathers nothing: the piles
## are lying there on the return.
func _gnaw_away(seconds: float) -> void:
	var team := beavers()
	if team <= 0:
		return
	var a_second := team * power() * bite() / BITE_EVERY
	var left := seconds
	for i in team * room():
		var tier := _kind()
		var takes := hp(tier) / a_second
		if takes > left:
			break
		left -= takes
		var pile: Dictionary = _leave(tier, _spot()).pile
		pile.born = clock - LIES

# --- crates ---

## With the Crates node, the seconds count while no crate lies, and one
## washes up when they are up. However long `dt` is, one at most.
func _wash(dt: float) -> void:
	if int(lv.crate) <= 0 or not crate.is_empty():
		return
	_crate_t += dt
	if _crate_t >= crate_time():
		_crate_t = 0.0
		crate = {"pos": _shore()}
		events.append({"kind": "crate", "pos": crate.pos})

## Where a crate washes up: on the land, within SHORE of one of the two
## edges that meet at its front corner.
func _shore() -> Vector2:
	var mid := LAND * 0.5
	for attempt in 40:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var deep := _rng.randf_range(EDGE, SHORE)
		# along the edge from the front corner to the side one, then inland
		var at := mid + Vector2(0.0, HALF) + Vector2(side * HALF, -HALF) * _rng.randf() + Vector2(-side, -1.0) * (deep / sqrt(2.0))
		if stands(at):
			return at
	return mid + Vector2(0.0, HALF - TIP)

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
	# the jetty: what lies, what is held, where the raft is, what it landed
	var lain := []
	for pile: Dictionary in logs:
		lain.append([(pile.pos as Vector2).x, (pile.pos as Vector2).y, int(pile.n), int(pile.wood), int(pile.tier), bool(pile.lucky)])
	cfg.set_value("jetty", "logs", lain)
	cfg.set_value("jetty", "loose", [int(loose.n), int(loose.wood)])
	var tied := []
	for b: Dictionary in bundles:
		tied.append([int(b.n), int(b.wood)])
	cfg.set_value("jetty", "bundles", tied)
	cfg.set_value("jetty", "raft", [int(raft.n), int(raft.wood), int(raft.bundles), float(raft.t), bool(raft.away)])
	cfg.set_value("jetty", "tie", tie_t)
	cfg.set_value("jetty", "owed", owed)
	cfg.set_value("jetty", "sent", wood_sent)
	cfg.set_value("jetty", "crate", [] if crate.is_empty() else [(crate.pos as Vector2).x, (crate.pos as Vector2).y])
	cfg.set_value("jetty", "crate_t", _crate_t)
	cfg.save(path)

# What a kept file says is not trusted: a key that is missing (a grove kept
# before the jetty), of the wrong kind or less than nothing reads as none, so
# no file can raise an error or make wood.

## A count: a whole number, never less than none.
static func _count(v: Variant) -> int:
	if v is int:
		return maxi(0, v)
	if v is float and is_finite(v):
		return maxi(0, int(v))
	return 0

## Seconds, from none to `most`.
static func _secs(v: Variant, most: float) -> float:
	if (v is int or v is float) and is_finite(v):
		return clampf(float(v), 0.0, most)
	return 0.0

static func _rows(v: Variant) -> Array:
	return v if v is Array else []

## Piles and their wood, from two places of a row: {n, wood}, or none of
## either unless every pile has its one wood at least.
static func _piles(v: Variant, at := 0) -> Dictionary:
	var row := _rows(v)
	var n := _count(row[at]) if row.size() > at + 1 else 0
	var wood := _count(row[at + 1]) if row.size() > at + 1 else 0
	return {"n": n, "wood": wood} if n > 0 and wood >= n else {"n": 0, "wood": 0}

## A point from the first two places of a row, or Vector2.INF where they
## hold none.
static func _point(v: Variant) -> Vector2:
	var row := _rows(v)
	if row.size() >= 2 and (row[0] is int or row[0] is float) and (row[1] is int or row[1] is float):
		var pos := Vector2(float(row[0]), float(row[1]))
		if pos.is_finite():
			return pos
	return Vector2.INF

## The jetty as it was kept.
func _read_jetty(cfg: ConfigFile) -> void:
	logs.clear()
	for row: Variant in _rows(cfg.get_value("jetty", "logs", [])):
		var held := _piles(row, 2)
		var pos := _point(row)
		if int(held.n) <= 0 or not pos.is_finite():
			continue
		var given: Array = row
		logs.append({"id": _next_log, "pos": pos if stands(pos) else _spot(), "n": held.n, "wood": held.wood,
			"tier": mini(_count(given[4]), int(lv.seeds)) if given.size() > 4 else 0, "lucky": given.size() > 5 and given[5] is bool and given[5],
			"born": clock - LIES})
		_next_log += 1
	loose = _piles(cfg.get_value("jetty", "loose", []))
	bundles.clear()
	for row: Variant in _rows(cfg.get_value("jetty", "bundles", [])):
		var b := _piles(row)
		if int(b.n) > 0:
			bundles.append(b)
	# a raft that is home carries nothing; one that is out is no further
	# than its whole time
	var kept := _rows(cfg.get_value("jetty", "raft", []))
	var away: bool = kept.size() > 4 and kept[4] is bool and kept[4]
	var aboard := _piles(kept) if away else {"n": 0, "wood": 0}
	raft = {"n": aboard.n, "wood": aboard.wood, "bundles": 0, "t": 0.0, "away": away}
	if away:
		raft.t = _secs(kept[3], raft_time())
		raft.bundles = clampi(_count(kept[2]), mini(1, int(aboard.n)), int(aboard.n))
	tie_t = _secs(cfg.get_value("jetty", "tie", 0.0), tie_time())
	owed = _count(cfg.get_value("jetty", "owed", 0))
	wood_sent = _count(cfg.get_value("jetty", "sent", 0))
	crate = {}
	_crate_t = 0.0
	if int(lv.crate) > 0:
		_crate_t = _secs(cfg.get_value("jetty", "crate_t", 0.0), crate_time())
		var pos := _point(cfg.get_value("jetty", "crate", []))
		if pos.is_finite():
			crate = {"pos": pos if stands(pos) else _shore()}

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
	sim._read_jetty(cfg)
	sim.events.clear()
	# a clock set back pays nothing; one set forward fills the land, no more
	sim.catch_up(now - float(cfg.get_value("grove", "seen", now)))
	return sim
