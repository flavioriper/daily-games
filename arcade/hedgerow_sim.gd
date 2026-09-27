extends RefCounted

## Hedgerow TD's whole game as pure data: the second game on the Arcade
## tab, a path tower defence after the element tower-defence genre and the
## balloon-popping one, re-dressed as a garden (spec docs/superpowers/specs/2026-09-27-arcade-hedgerow-design.md).
## The screen (arcade/hedgerow_screen.gd) steps it at a fixed DT, calls the
## player's moves (`build`, `upgrade`, `fuse`, `sell`, `pick`, `send_wave`)
## and draws what it holds; it reads `events` after every step for sounds
## and bursts.
##
## Cell units, not pixels: the garden is COLS by ROWS cells with y down.
## Pests come in at the gate in the top hedge and walk a fixed paved path
## (WAYPOINTS) that spirals into the raised bed in the middle; towers are
## planted on the grass beside it, never on it. Wasps fly a shorter line
## over the hedges (FLIGHT). Each tower aims by its own rule: the pest
## furthest along, the last, the strongest or the closest.
##
## Six elements in a ring, each strong against the next (double damage) and
## weak against the one before (half): Sun, Shade, Rain, Ember, Leaf, Stone,
## and back to Sun. Thorn and Acorn towers carry no element. Four picks of
## the six come at waves 1, 7, 14 and 21; a picked element builds its tower,
## and any element tower fuses with a second picked element into one of
## fifteen duals.

const COLS := 9
const ROWS := 12
const DT := 1.0 / 60.0

const START_GOLD := 110
const START_LIVES := 20
const WAVES := 40
const PICK_WAVES := [1, 7, 14, 21]
## Seconds between a cleared wave and the next one coming on its own.
const BREAK := 16.0
const FIRST_BREAK := 40.0
const SELL_BACK := 0.75
const INTEREST := 0.03
const INTEREST_CAP := 60
## A creep's reach for a tower's range: its body, roughly.
const BODY := 0.3

enum El { NONE, SUN, SHADE, RAIN, EMBER, LEAF, STONE }
enum Kind { APHID, ANT, GNAT, BEETLE, SLUG, WASP, BOSS }
enum Phase { BUILD, WAVE, OVER, WON }
## Which pest in range a tower shoots: the one furthest along the path, the
## one furthest back, the one with the most health, or the nearest.
enum Aim { FIRST, LAST, STRONG, CLOSE }

const ELEMENTS := [El.SUN, El.SHADE, El.RAIN, El.EMBER, El.LEAF, El.STONE]
const EL_KEY := {El.SUN: "sun", El.SHADE: "shade", El.RAIN: "rain", El.EMBER: "ember", El.LEAF: "leaf", El.STONE: "stone"}

## The waves' kinds, ten long and repeated; the tenth is always a boss.
const PATTERN := [Kind.APHID, Kind.ANT, Kind.GNAT, Kind.BEETLE, Kind.APHID,
	Kind.SLUG, Kind.WASP, Kind.ANT, Kind.GNAT, Kind.BOSS]
## Per kind: how many, health against the wave's base, speed in cells a
## second, the gap between them, and lives lost if one gets through.
const KINDS := {
	Kind.APHID: {"n": 12, "hp": 1.0, "speed": 1.0, "gap": 0.8, "lives": 1},
	Kind.ANT: {"n": 12, "hp": 0.7, "speed": 1.7, "gap": 0.6, "lives": 1},
	Kind.GNAT: {"n": 20, "hp": 0.45, "speed": 1.2, "gap": 0.4, "lives": 1},
	Kind.BEETLE: {"n": 8, "hp": 2.0, "speed": 0.75, "gap": 1.1, "lives": 1},
	Kind.SLUG: {"n": 10, "hp": 1.3, "speed": 0.85, "gap": 0.9, "lives": 1},
	Kind.WASP: {"n": 10, "hp": 0.9, "speed": 1.1, "gap": 0.8, "lives": 1},
	Kind.BOSS: {"n": 1, "hp": 16.0, "speed": 0.55, "gap": 1.0, "lives": 5},
}
## A beetle's shell halves what Thorn and Acorn do to it; a slug heals this
## share of its health a second. Thorn and Acorn carry no element, and a
## pest that does shrugs off part of a plain hit (PLAIN), which is what
## makes the elements worth their price from wave 3 on.
const SHELL := 0.5
const PLAIN := 0.6
const REGEN := 0.03
## A wave's health: HP_BASE at wave 1, HP_GROWTH more each wave. The path is
## long (about 43 cells of walk) and a tower planted between two lanes hits
## both, so the curve is steeper than a maze's would be.
const HP_BASE := 20.0
const HP_GROWTH := 1.165

## Every tower. `cost` is the build and then each upgrade; `dmg` a hit at
## each level. The rest are what makes a tower itself:
##   splash r   -- everything within r of the target takes the hit
##   ramp k, ramp_max -- +k a hit on the same target, up to ramp_max
##   spill      -- a kill's leftover damage goes on to the nearest creep
##   second k   -- another creep near the target takes k of the hit
##   heat k     -- +k a second of steady firing, up to +1, gone after 2 s idle
##   fresh k    -- +k against a creep over half its health
##   pulse      -- hits everything in range at once, no target
##   mark k     -- the target takes +k from every tower for 3 s
##   stun s     -- the target stops for s (a boss for a third of it)
##   chain n    -- the hit jumps on to n more creeps, 15% less each time
##   dot d      -- the target takes d a second for 3 s
##   execute k  -- up to +k more the lower the target's health
##   slow_aura k -- creeps in range move k slower
##   line l     -- a jet l long through the target hits all it crosses
##   haste k    -- towers in range fire k faster (no attack of its own)
##   slow k     -- the target moves k slower for 2 s
##   burn d     -- everything splashed takes d a second for 3 s
##   might k    -- towers in range hit k harder (no attack of its own)
##   multi n    -- n targets at once
const TOWERS := {
	"thorn": {"els": [], "cost": [20, 40, 110], "dmg": [7, 16, 34], "range": 2.5, "rate": 0.55},
	"acorn": {"els": [], "cost": [30, 60, 150], "dmg": [9, 22, 48], "range": 2.2, "rate": 1.2, "splash": 0.9},
	"sun": {"els": [El.SUN], "cost": [100, 220, 520], "dmg": [50, 145, 390], "range": 3.6, "rate": 0.9, "ramp": 0.15, "ramp_max": 0.9},
	"shade": {"els": [El.SHADE], "cost": [100, 220, 520], "dmg": [180, 500, 1350], "range": 2.6, "rate": 1.8, "spill": true},
	"rain": {"els": [El.RAIN], "cost": [100, 220, 520], "dmg": [45, 128, 345], "range": 2.8, "rate": 0.7, "second": 0.4},
	"ember": {"els": [El.EMBER], "cost": [100, 220, 520], "dmg": [27, 75, 200], "range": 2.4, "rate": 0.45, "heat": 0.25},
	"leaf": {"els": [El.LEAF], "cost": [100, 220, 520], "dmg": [60, 165, 450], "range": 2.6, "rate": 0.8, "fresh": 0.5},
	"stone": {"els": [El.STONE], "cost": [100, 220, 520], "dmg": [40, 108, 300], "range": 1.7, "rate": 1.5, "pulse": true},
	"eclipse": {"els": [El.SUN, El.SHADE], "cost": [260, 700], "dmg": [145, 430], "range": 3.0, "rate": 1.0, "mark": 0.3},
	"frost": {"els": [El.SUN, El.RAIN], "cost": [260, 700], "dmg": [105, 310], "range": 2.8, "rate": 1.1, "stun": 0.6},
	"lightning": {"els": [El.SUN, El.EMBER], "cost": [260, 700], "dmg": [130, 390], "range": 2.8, "rate": 1.0, "chain": 4},
	"bloom": {"els": [El.SUN, El.LEAF], "cost": [260, 700], "dmg": [80, 235], "range": 3.3, "rate": 0.7, "ramp": 0.25, "ramp_max": 2.0},
	"atom": {"els": [El.SUN, El.STONE], "cost": [260, 700], "dmg": [118, 350], "range": 3.0, "rate": 1.2, "splash": 1.0, "ramp": 0.1, "ramp_max": 1.0},
	"poison": {"els": [El.SHADE, El.RAIN], "cost": [260, 700], "dmg": [52, 156], "range": 2.8, "rate": 0.9, "dot": [80, 235]},
	"cinder": {"els": [El.SHADE, El.EMBER], "cost": [260, 700], "dmg": [585, 1750], "range": 2.8, "rate": 2.4, "spill": true},
	"blight": {"els": [El.SHADE, El.LEAF], "cost": [260, 700], "dmg": [170, 505], "range": 2.8, "rate": 1.2, "execute": 2.0},
	"gravity": {"els": [El.SHADE, El.STONE], "cost": [260, 700], "dmg": [52, 156], "range": 1.9, "rate": 1.0, "pulse": true, "slow_aura": 0.35},
	"steam": {"els": [El.RAIN, El.EMBER], "cost": [260, 700], "dmg": [110, 330], "range": 3.0, "rate": 1.3, "line": 3.4},
	"well": {"els": [El.RAIN, El.LEAF], "cost": [260, 700], "dmg": [0, 0], "range": 1.6, "rate": 1.0, "haste": [0.3, 0.5]},
	"mud": {"els": [El.RAIN, El.STONE], "cost": [260, 700], "dmg": [78, 235], "range": 2.6, "rate": 1.3, "splash": 1.0, "slow": 0.4},
	"solar": {"els": [El.EMBER, El.LEAF], "cost": [260, 700], "dmg": [90, 275], "range": 2.6, "rate": 1.1, "splash": 0.8, "burn": [52, 156]},
	"forge": {"els": [El.EMBER, El.STONE], "cost": [260, 700], "dmg": [0, 0], "range": 1.6, "rate": 1.0, "might": [0.25, 0.45]},
	"bramble": {"els": [El.LEAF, El.STONE], "cost": [260, 700], "dmg": [90, 275], "range": 2.8, "rate": 0.9, "multi": 3},
}
const BASIC := ["thorn", "acorn"]

var rng := RandomNumberGenerator.new()
var t := 0.0
var phase := Phase.BUILD
## The wave on the lawn or the next to come (1-based); 0 before the first.
var wave := 0
var next_in := FIRST_BREAK
var gold := START_GOLD
var lives := START_LIVES
var score := 0
var picked: Array = []
## A pick is owed before the next wave can come.
var pick_pending := true
var towers: Array = []    # {id, cell, key, level, cd, target, streak, heat, idle, spent, kills, haste, might, aim, face}
var creeps: Array = []    # see _spawn
var events: Array = []
var kills := 0
var leaks := 0
## A tower by its cell, for placing and taps.
var at := {}
var _spawns: Array = []   # {kind, el, t}
var _ids := 0

func _init(seed_value := 0) -> void:
	rng.seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())

# --- the rules of the ring ---

static func beats(a: int) -> int:
	return a % 6 + 1

## What an element's hit is worth against a creep's: double against the one
## it beats, half against the one that beats it.
static func mult_el(a: int, c: int) -> float:
	if a == El.NONE or c == El.NONE:
		return 1.0
	if beats(a) == c:
		return 2.0
	if beats(c) == a:
		return 0.5
	return 1.0

## A tower's worth against an element: a dual takes the mean of its two.
static func mult(key: String, c: int) -> float:
	var els: Array = TOWERS[key].els
	if els.is_empty():
		return 1.0
	var sum := 0.0
	for e: int in els:
		sum += mult_el(e, c)
	return sum / els.size()

## The dual two elements make, or "".
static func dual(a: int, b: int) -> String:
	for key: String in TOWERS:
		var els: Array = TOWERS[key].els
		if els.size() == 2 and ((els[0] == a and els[1] == b) or (els[0] == b and els[1] == a)):
			return key
	return ""

static func is_single(key: String) -> bool:
	return (TOWERS[key].els as Array).size() == 1

static func wave_kind(n: int) -> int:
	return PATTERN[(n - 1) % PATTERN.size()]

static func wave_el(n: int) -> int:
	if n <= 2:
		return El.NONE
	return ELEMENTS[(n - 3) % 6]

static func wave_hp(n: int) -> float:
	return HP_BASE * pow(HP_GROWTH, n - 1) + n * 4.0

static func bounty(n: int, kind: int) -> int:
	var base := 1.0 + n * 0.25
	match kind:
		Kind.GNAT:
			base *= 0.5
		Kind.BEETLE:
			base *= 1.6
		Kind.BOSS:
			base *= 20.0
	return maxi(1, int(round(base)))

# --- the garden path ---

static func idx(c: Vector2i) -> int:
	return c.y * COLS + c.x

static func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS

static func centre(c: Vector2i) -> Vector2:
	return Vector2(c.x + 0.5, c.y + 0.5)

## The paved path, corner to corner through cell centres: in at the gate in
## the top hedge, down the west side, across the foot, up the east side,
## back along the top and round an inner hook to the raised bed, a spiral
## into the middle of the garden. It never changes; towers stand beside it.
const WAYPOINTS := [Vector2(1.5, -0.9), Vector2(1.5, 10.5), Vector2(7.5, 10.5), Vector2(7.5, 1.5),
	Vector2(3.5, 1.5), Vector2(3.5, 8.5), Vector2(5.5, 8.5), Vector2(5.5, 4.2)]
## The wasps' flight: over the hedges, cutting the spiral's corners, so a
## flying wave reaches the bed in a little over half the walk.
const FLIGHT := [Vector2(1.5, -0.9), Vector2(2.4, 9.6), Vector2(6.6, 9.6), Vector2(6.6, 2.6), Vector2(5.0, 3.4)]
## The raised bed the pests are after, two by two in the spiral's heart.
const BED := Rect2i(4, 2, 2, 2)
## Grass that holds scenery and cannot be planted: a stump, rocks, a pond.
const SCENERY := {Vector2i(8, 0): "stump", Vector2i(0, 5): "rock", Vector2i(8, 7): "rock",
	Vector2i(0, 11): "pond", Vector2i(8, 11): "bush"}
## How far round a corner a walker cuts, in cells.
const CORNER := 0.42

static var _road := {}
static var _walk := PackedVector2Array()
static var _walk_at := PackedFloat32Array()
static var _fly := PackedVector2Array()
static var _fly_at := PackedFloat32Array()

## Every cell the path covers.
static func road() -> Dictionary:
	if _road.is_empty():
		for i in range(1, WAYPOINTS.size()):
			var a: Vector2 = WAYPOINTS[i - 1]
			var z: Vector2 = WAYPOINTS[i]
			var n := int(ceil(a.distance_to(z) * 4.0))
			for k in n + 1:
				var p := a.lerp(z, float(k) / n)
				var c := Vector2i(floori(p.x), floori(p.y))
				if inside(c):
					_road[c] = true
	return _road

## The walk as a dense polyline with rounded corners, and the distance
## along it at each point.
static func walk_line() -> PackedVector2Array:
	if _walk.is_empty():
		_walk = _rounded(WAYPOINTS, CORNER)
		_walk_at = _lengths(_walk)
	return _walk

static func flight_line() -> PackedVector2Array:
	if _fly.is_empty():
		_fly = _rounded(FLIGHT, 1.2)
		_fly_at = _lengths(_fly)
	return _fly

static func walk_length() -> float:
	walk_line()
	return _walk_at[_walk_at.size() - 1]

static func flight_length() -> float:
	flight_line()
	return _fly_at[_fly_at.size() - 1]

static func _rounded(pts: Array, r: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var p: Vector2 = pts[i]
		var a: Vector2 = (pts[i - 1] - p)
		var z: Vector2 = (pts[i + 1] - p)
		var rr := minf(r, minf(a.length(), z.length()) * 0.5)
		var from := p + a.normalized() * rr
		var to := p + z.normalized() * rr
		for k in 9:
			var t := k / 8.0
			out.append(from.lerp(p, t).lerp(p.lerp(to, t), t))
	out.append(pts[pts.size() - 1])
	return out

static func _lengths(line: PackedVector2Array) -> PackedFloat32Array:
	var at := PackedFloat32Array([0.0])
	for i in range(1, line.size()):
		at.append(at[i - 1] + line[i - 1].distance_to(line[i]))
	return at

## A point `d` along a line, and the segment it is on (a hint for the next
## call, which is always further along).
static func _along(line: PackedVector2Array, at: PackedFloat32Array, d: float, seg: int) -> Array:
	var i := clampi(seg, 1, line.size() - 1)
	while i < line.size() - 1 and at[i] < d:
		i += 1
	var span := at[i] - at[i - 1]
	var k := 0.0 if span <= 0.0 else clampf((d - at[i - 1]) / span, 0.0, 1.0)
	return [line[i - 1].lerp(line[i], k), i]

static func in_bed(c: Vector2i) -> bool:
	return BED.has_point(c)

## Why a tower may not go on `c`, or "" if it may: off the lawn, the path,
## the bed, scenery, or a tower already there.
func build_block(c: Vector2i) -> String:
	if not inside(c):
		return "edge"
	if road().has(c):
		return "road"
	if in_bed(c):
		return "bed"
	if SCENERY.has(c):
		return "scenery"
	if at.has(c):
		return "taken"
	return ""

# --- the player's moves ---

func can_build(key: String) -> bool:
	var els: Array = TOWERS[key].els
	if els.size() > 1:
		return false
	for e: int in els:
		if not picked.has(e):
			return false
	return true

func build(c: Vector2i, key: String) -> bool:
	var cost: int = TOWERS[key].cost[0]
	var why := build_block(c)
	if why == "" and not can_build(key):
		why = "locked"
	if why == "" and gold < cost:
		why = "gold"
	if why != "":
		events.append({"type": "refuse", "why": why, "cell": c})
		return false
	gold -= cost
	_ids += 1
	var tw := {"id": _ids, "cell": c, "key": key, "level": 0, "cd": 0.0, "target": -1, "streak": 0,
		"heat": 0.0, "idle": 0.0, "spent": cost, "kills": 0, "haste": 1.0, "might": 1.0,
		"aim": Aim.FIRST, "face": PI * 0.5}
	towers.append(tw)
	at[c] = tw
	_auras()
	events.append({"type": "build", "cell": c, "key": key})
	return true

func upgrade_cost(tw: Dictionary) -> int:
	var costs: Array = TOWERS[tw.key].cost
	return costs[tw.level + 1] if tw.level + 1 < costs.size() else -1

func upgrade(tw: Dictionary) -> bool:
	var cost := upgrade_cost(tw)
	if cost < 0 or gold < cost:
		events.append({"type": "refuse", "why": "gold" if cost >= 0 else "max", "cell": tw.cell})
		return false
	gold -= cost
	tw.level += 1
	tw.spent += cost
	_auras()
	events.append({"type": "upgrade", "cell": tw.cell, "key": tw.key, "level": tw.level})
	return true

## The duals a single element tower can become, with what each costs.
func fusions(tw: Dictionary) -> Array:
	var out := []
	if not is_single(tw.key):
		return out
	var own: int = TOWERS[tw.key].els[0]
	for e: int in picked:
		if e != own:
			out.append(dual(own, e))
	return out

func fuse(tw: Dictionary, key: String) -> bool:
	var cost: int = TOWERS[key].cost[0]
	if not fusions(tw).has(key) or gold < cost:
		events.append({"type": "refuse", "why": "gold", "cell": tw.cell})
		return false
	gold -= cost
	tw.key = key
	tw.level = 0
	tw.spent += cost
	tw.cd = 0.0
	tw.streak = 0
	tw.heat = 0.0
	_auras()
	events.append({"type": "fuse", "cell": tw.cell, "key": key})
	return true

func sell_value(tw: Dictionary) -> int:
	return int(tw.spent * SELL_BACK)

func sell(tw: Dictionary) -> void:
	gold += sell_value(tw)
	towers.erase(tw)
	at.erase(tw.cell)
	_auras()
	events.append({"type": "sell", "cell": tw.cell, "key": tw.key})

func pick(e: int) -> bool:
	if not pick_pending or picked.has(e) or not ELEMENTS.has(e):
		return false
	picked.append(e)
	pick_pending = false
	events.append({"type": "pick", "el": e})
	return true

## Whether a pick is owed before `wave + 1` can come.
static func pick_due(next_wave: int) -> bool:
	return PICK_WAVES.has(next_wave)

func can_send() -> bool:
	return phase == Phase.BUILD and not pick_pending and wave < WAVES

## Calls the next wave now; the seconds left on the break come as gold.
func send_wave() -> bool:
	if not can_send():
		return false
	var early := int(next_in * 0.5) if wave > 0 else 0
	if early > 0:
		gold += early
		score += early * 5
	wave += 1
	phase = Phase.WAVE
	var kind := wave_kind(wave)
	var k: Dictionary = KINDS[kind]
	_spawns.clear()
	var n: int = k.n
	if wave == WAVES:
		n = 3
	for i in n:
		_spawns.append({"kind": kind, "el": wave_el(wave), "t": i * float(k.gap)})
	events.append({"type": "wave", "wave": wave, "kind": kind, "el": wave_el(wave), "early": early})
	return true

func is_over() -> bool:
	return phase == Phase.OVER or phase == Phase.WON

# --- the step ---

func step() -> void:
	if is_over():
		return
	t += DT
	if phase == Phase.BUILD:
		if not pick_pending and wave < WAVES:
			next_in -= DT
			if next_in <= 0.0:
				next_in = 0.0
				send_wave()
		return
	_spawn_step()
	_auras_step()
	_creeps_step()
	_towers_step()
	creeps = creeps.filter(func(c: Dictionary) -> bool: return c.alive)
	if _spawns.is_empty() and creeps.is_empty() and phase == Phase.WAVE:
		_wave_clear()

func _spawn_step() -> void:
	var gone := []
	for s: Dictionary in _spawns:
		s.t -= DT
		if s.t <= 0.0:
			_spawn(s.kind, s.el)
			gone.append(s)
	for s in gone:
		_spawns.erase(s)

func _spawn(kind: int, el: int) -> void:
	var k: Dictionary = KINDS[kind]
	var hp := wave_hp(wave) * float(k.hp)
	if wave == WAVES:
		hp *= 1.6
	_ids += 1
	var air := kind == Kind.WASP
	creeps.append({"id": _ids, "kind": kind, "el": el, "hp": hp, "max": hp, "pos": WAYPOINTS[0],
		"d": 0.0, "seg": 1, "len": flight_length() if air else walk_length(), "speed": float(k.speed),
		"lives": int(k.lives), "bounty": bounty(wave, kind), "air": air,
		"slow": 0.0, "slow_t": 0.0, "stun_t": 0.0, "dot": 0.0, "dot_t": 0.0, "burn": 0.0, "burn_t": 0.0,
		"mark_t": 0.0, "left": 99.0, "alive": true, "phase": rng.randf() * TAU})
	if kind == Kind.BOSS:
		events.append({"type": "boss", "el": el})

func _creeps_step() -> void:
	for c: Dictionary in creeps:
		if not c.alive:
			continue
		# damage over time, healing and the timers
		if c.dot_t > 0.0:
			c.dot_t -= DT
			_hurt(c, c.dot * DT, null, true)
		if c.burn_t > 0.0 and c.alive:
			c.burn_t -= DT
			_hurt(c, c.burn * DT, null, true)
		if not c.alive:
			continue
		if c.kind == Kind.SLUG:
			c.hp = minf(c.max, c.hp + c.max * REGEN * DT)
		c.mark_t = maxf(0.0, c.mark_t - DT)
		c.slow_t = maxf(0.0, c.slow_t - DT)
		if c.slow_t <= 0.0:
			c.slow = 0.0
		if c.stun_t > 0.0:
			c.stun_t -= DT
			continue
		var go: float = c.speed * (1.0 - c.slow) * DT
		c.d += go
		var line := flight_line() if c.air else walk_line()
		var got := _along(line, _fly_at if c.air else _walk_at, c.d, c.seg)
		c.pos = got[0]
		c.seg = got[1]
		c.left = maxf(0.0, c.len - c.d)
		if c.d >= c.len:
			c.alive = false
			lives -= c.lives
			leaks += 1
			events.append({"type": "leak", "pos": c.pos, "kind": c.kind, "el": c.el, "lives": c.lives})
			if lives <= 0:
				lives = 0
				phase = Phase.OVER
				events.append({"type": "game_over"})
				return

# --- the towers ---

func _auras() -> void:
	for tw: Dictionary in towers:
		tw.haste = 1.0
		tw.might = 1.0
	for aura: Dictionary in towers:
		var d: Dictionary = TOWERS[aura.key]
		if not (d.has("haste") or d.has("might")):
			continue
		var from := centre(aura.cell)
		for tw: Dictionary in towers:
			if tw == aura or centre(tw.cell).distance_to(from) > float(d.range) + 0.01:
				continue
			if d.has("haste"):
				tw.haste = maxf(tw.haste, 1.0 + float(d.haste[aura.level]))
			if d.has("might"):
				tw.might = maxf(tw.might, 1.0 + float(d.might[aura.level]))

func _auras_step() -> void:
	for tw: Dictionary in towers:
		var d: Dictionary = TOWERS[tw.key]
		if not d.has("slow_aura"):
			continue
		var from := centre(tw.cell)
		for c: Dictionary in creeps:
			if c.alive and from.distance_to(c.pos) <= float(d.range) + BODY:
				c.slow = maxf(c.slow, float(d.slow_aura))
				c.slow_t = maxf(c.slow_t, 0.1)

func _in_range(from: Vector2, r: float) -> Array:
	var out := []
	for c: Dictionary in creeps:
		if c.alive and c.d > 0.4 and from.distance_to(c.pos) <= r + BODY:
			out.append(c)
	return out

## The creeps in range in the order a tower's aim wants them.
static func _aimed(near: Array, aim: int, from: Vector2) -> void:
	match aim:
		Aim.LAST:
			near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.left > b.left)
		Aim.STRONG:
			near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.hp > b.hp or (a.hp == b.hp and a.left < b.left))
		Aim.CLOSE:
			near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return from.distance_squared_to(a.pos) < from.distance_squared_to(b.pos))
		_:
			near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.left < b.left)

## Turns a tower's aim to the next rule.
func cycle_aim(tw: Dictionary) -> void:
	tw.aim = (int(tw.aim) + 1) % 4
	events.append({"type": "aim", "cell": tw.cell, "aim": tw.aim})

func _towers_step() -> void:
	for tw: Dictionary in towers:
		var d: Dictionary = TOWERS[tw.key]
		var dmg: float = d.dmg[tw.level]
		if dmg <= 0.0:
			continue
		tw.cd -= DT * tw.haste
		if d.has("heat"):
			tw.idle += DT
			if tw.idle > 2.0:
				tw.heat = 0.0
		if tw.cd > 0.0:
			continue
		var from := centre(tw.cell)
		var near := _in_range(from, float(d.range))
		if near.is_empty():
			tw.cd = 0.0
			continue
		tw.cd = float(d.rate)
		if d.get("pulse", false):
			for c: Dictionary in near:
				_hit(tw, c, dmg)
			events.append({"type": "pulse", "cell": tw.cell, "key": tw.key, "r": float(d.range)})
			continue
		_aimed(near, int(tw.aim), from)
		var first: Dictionary = near[0]
		tw.face = (first.pos - from).angle()
		if d.has("heat"):
			tw.idle = 0.0
			tw.heat = minf(1.0, tw.heat + float(d.heat) * float(d.rate))
		if d.has("ramp"):
			tw.streak = tw.streak + 1 if tw.target == first.id else 0
			tw.target = first.id
		var hits: Array = [first.pos]
		if d.has("multi"):
			for i in mini(int(d.multi), near.size()):
				_hit(tw, near[i], dmg)
				if i > 0:
					hits.append(near[i].pos)
		elif d.has("chain"):
			var struck := {first.id: true}
			var cur := first
			var amount := dmg
			_hit(tw, cur, amount)
			for j in int(d.chain):
				var nxt: Dictionary = {}
				var best := 1.6
				for c: Dictionary in creeps:
					if c.alive and not struck.has(c.id) and c.pos.distance_to(cur.pos) < best:
						best = c.pos.distance_to(cur.pos)
						nxt = c
				if nxt.is_empty():
					break
				amount *= 0.85
				struck[nxt.id] = true
				hits.append(nxt.pos)
				_hit(tw, nxt, amount)
				cur = nxt
		elif d.has("line"):
			var dir: Vector2 = (first.pos - from).normalized()
			var end: Vector2 = from + dir * float(d.line)
			hits = [end]
			for c: Dictionary in creeps.duplicate():
				if not c.alive:
					continue
				var p := Geometry2D.get_closest_point_to_segment(c.pos, from, end)
				if p.distance_to(c.pos) <= 0.4:
					_hit(tw, c, dmg)
		elif d.has("splash"):
			var spot: Vector2 = first.pos
			for c: Dictionary in creeps.duplicate():
				if c.alive and c.pos.distance_to(spot) <= float(d.splash):
					_hit(tw, c, dmg, c == first)
					if d.has("burn") and c.alive:
						c.burn = maxf(c.burn, float(d.burn[tw.level]) * mult(tw.key, c.el) * tw.might)
						c.burn_t = 3.0
		else:
			var spot: Vector2 = first.pos
			_hit(tw, first, dmg)
			if d.has("second"):
				for c: Dictionary in creeps:
					if c.alive and c.id != first.id and c.pos.distance_to(spot) <= 1.2:
						_hit(tw, c, dmg * float(d.second))
						hits.append(c.pos)
						break
		events.append({"type": "shot", "cell": tw.cell, "key": tw.key, "to": hits, "level": tw.level})

## One tower's hit on one creep, with everything the tower adds to it.
func _hit(tw: Dictionary, c: Dictionary, dmg: float, primary := true) -> void:
	if not c.alive:
		return
	var d: Dictionary = TOWERS[tw.key]
	var amount: float = dmg * tw.might * mult(tw.key, c.el)
	if d.has("ramp") and primary:
		amount *= 1.0 + minf(float(d.ramp) * tw.streak, float(d.ramp_max))
	if d.has("heat"):
		amount *= 1.0 + tw.heat
	if d.has("fresh") and c.hp > c.max * 0.5:
		amount *= 1.0 + float(d.fresh)
	if d.has("execute"):
		amount *= 1.0 + float(d.execute) * (1.0 - c.hp / c.max)
	if BASIC.has(tw.key):
		if c.kind == Kind.BEETLE:
			amount *= SHELL
		if c.el != El.NONE:
			amount *= PLAIN
	if d.has("mark"):
		c.mark_t = 3.0
	if d.has("stun"):
		c.stun_t = maxf(c.stun_t, float(d.stun) * (0.33 if c.kind == Kind.BOSS else 1.0))
		events.append({"type": "stun", "pos": c.pos})
	if d.has("slow"):
		c.slow = maxf(c.slow, float(d.slow))
		c.slow_t = 2.0
	if d.has("dot"):
		c.dot = maxf(c.dot, float(d.dot[tw.level]) * mult(tw.key, c.el) * tw.might)
		c.dot_t = 3.0
	var over := _hurt(c, amount, tw)
	if over > 0.0 and d.get("spill", false):
		var nxt: Dictionary = {}
		var best := 1.6
		for o: Dictionary in creeps:
			if o.alive and o.pos.distance_to(c.pos) < best:
				best = o.pos.distance_to(c.pos)
				nxt = o
		if not nxt.is_empty():
			_hurt(nxt, over, tw)
			events.append({"type": "spill", "from": c.pos, "to": nxt.pos})

## Takes health off; returns the damage left over after a kill.
func _hurt(c: Dictionary, amount: float, tw, quiet := false) -> float:
	if not c.alive:
		return 0.0
	if c.mark_t > 0.0:
		amount *= 1.3
	c.hp -= amount
	if c.hp > 0.0:
		if not quiet:
			events.append({"type": "hit", "id": c.id})
		return 0.0
	c.alive = false
	kills += 1
	gold += c.bounty
	score += c.bounty * 10
	if tw != null:
		tw.kills += 1
	events.append({"type": "kill", "pos": c.pos, "kind": c.kind, "el": c.el, "gold": c.bounty})
	return -c.hp

func _wave_clear() -> void:
	var interest := mini(INTEREST_CAP, int(gold * INTEREST))
	var bonus := 10 + wave * 2
	gold += interest + bonus
	score += wave * 100
	events.append({"type": "clear", "wave": wave, "interest": interest, "bonus": bonus})
	if wave >= WAVES:
		phase = Phase.WON
		score += lives * 500 + 5000
		events.append({"type": "won"})
		return
	phase = Phase.BUILD
	next_in = BREAK
	if pick_due(wave + 1) and picked.size() < PICK_WAVES.size():
		pick_pending = true
		events.append({"type": "pick_due"})
