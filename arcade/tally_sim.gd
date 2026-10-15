extends RefCounted

## Tally's paper as pure data: no nodes, no clock of its own (spec
## docs/superpowers/specs/2026-10-15-arcade-tally-design.md). A sheet of
## W by H squares with the counting box (the hub, HUB by HUB) in the middle
## and numbers printed about it (`dep`, by the save's seed, the small ones
## close). Every piece is one square:
##
## - a **belt** carries one token a square at `belt_speed()` squares a
##   second, to the square in front, and every other token to a belt whose
##   back touches its side (a split); a belt takes from its back and its
##   sides, never its front (a merge, a corner);
## - a **bridge** is two belts crossing, each lane straight on;
## - a **dig** stands on a printed number and puts it on every belt leading
##   away from it, `dig_belts()` belts' worth;
## - the five **operators** take A on their left and B on their right and put
##   the answer out of their front (the divider its remainder out of its
##   back), 4 waiting a side and 2 to go out;
## - a **crate** keeps up to CRATE_MAX of the first number it gets and lets
##   them out on every belt leading away;
## - the **box** takes everything from every side.
##
## A slot is where a token rides: `s` < N is a square's own (a belt, a
## bridge's across lane), `s` >= N a bridge's up-and-down lane. A slot's
## token is `val[s]`, `prog[s]` from 0 (the edge it came in by, `from_d`)
## to 1 (the edge it leaves by, the way of `outs[s][to_d[s]]`).
##
## An end (`_end_into`) is where a token can be handed: `(id << 2) | dir`,
## `id` a slot, or N2 + square * 4 + q for a machine's A (0) or B (1) side, a
## crate (2) or the box (3); `dir` is the way the token is going.
##
## Actions return whether they did anything; `events` is for the holder to
## drain. `step(dt)` takes any `dt`.

const VER := 1
const W := 46
const H := 46
const N := W * H
const N2 := N * 2
const HUB := 4
const HUB_AT := Vector2i(21, 21)

enum { EMPTY, BELT, BRIDGE, DIG, ADD, MUL, SUB, DIV, POW, CRATE, BOX }
const OPS := [ADD, MUL, SUB, DIV, POW]
const KIND_IDS := {BELT: "belt", BRIDGE: "bridge", DIG: "dig", ADD: "add", MUL: "mul", SUB: "sub", DIV: "div", POW: "pow", CRATE: "crate", BOX: "box"}
## The level whose end hands a piece over (it is had from the level after).
const UNLOCK := {BELT: 0, DIG: 0, ADD: 1, BRIDGE: 4, MUL: 7, SUB: 13, DIV: 16, POW: 19, CRATE: 22}

## East, south, west, north: clockwise, +y down.
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const NONE := 255

## A machine's room a side and for what waits to go out.
const QUEUE := 4
const OUT := 2
const CRATE_MAX := 500
## The longest step taken in one go: a token at 20 squares a second moves
## two thirds of a square in it.
const STEP := 1.0 / 30.0
const LIMIT := 2147483647
const FLOOR := -2147483648

# --- the ladder ---

## Each level: the sample target, the count, the reward (a piece's kind, a
## number now dug, or 0). From level 6 the target is drawn round the sample.
const LADDER := [
	[1, 10, ADD], [2, 15, 0], [3, 20, -2], [5, 25, BRIDGE], [10, 30, -3],
	[19, 50, -4], [27, 75, MUL], [36, 120, -5], [47, 160, -6], [50, 200, 0],
	[82, 250, -7], [174, 300, -8], [248, 400, SUB], [324, 500, -9], [466, 650, -11],
	[594, 800, DIV], [631, 900, -12], [727, 1000, -13], [891, 1100, POW], [928, 1200, -14],
	[1779, 1300, -15], [2805, 1400, CRATE], [3366, 1500, 0], [4860, 1600, 0], [5445, 1700, 0],
	[6667, 1800, 0], [7512, 1900, 0], [8133, 2000, 0], [9646, 2100, 0], [10904, 2200, 0],
	[12675, 2300, 0], [14772, 2400, 0], [18962, 2500, 0], [20158, 2500, 0], [23431, 2500, 0],
	[24755, 2500, 0], [27432, 2500, 0], [29296, 2500, 0], [32550, 2500, 0], [35541, 2500, 0],
]
## The band a target is drawn in round the sample, from level BAND_FROM.
const BAND := 0.12
const BAND_FROM := 6
## Past the table: each target the last times 1 + a draw from GROW, the
## draw halved past SLOW_PAST, never past TOP.
const GROW := Vector2(0.03, 0.15)
const SLOW_PAST := 1000000
const TOP := 99999999
const COUNT_TOP := 2500
const COUNT_STEP := 100
## From level 23 each level hands over the number level - DIG_FROM, to the
## last printed.
const DIG_FROM := 7
const MOST := 60

# --- the paper ---

## [value, how many, nearest, furthest]: squares from the box's edge.
const DEPOSITS := [
	[1, 6, 3, 6], [2, 5, 4, 8], [3, 4, 5, 9], [4, 4, 6, 10], [5, 4, 6, 11],
	[6, 3, 7, 12], [7, 3, 8, 13], [8, 3, 8, 13], [9, 3, 9, 14],
]
## Past 9: two of each from 11 to 39, one or two from 40 to MOST.
const FAR := [[11, 19, 2, 10, 16], [20, 39, 2, 13, 19], [40, 60, 1, 16, 21]]

# --- the upgrades ---

const TRACKS := ["belt", "dig", "add", "mul", "sub", "pow"]
const TRACK_KIND := {"belt": BELT, "dig": DIG, "add": ADD, "mul": MUL, "sub": SUB, "pow": POW}
const TRACK_TOP := {"belt": 128, "dig": 4, "add": 108, "mul": 108, "sub": 108, "pow": 108}
## Each track's numbers, near the reference's magnitudes; past the list each
## the last times SEQ_GROW. The first is kept, the rest drawn within SEQ_BAND.
const SEQ := {
	"belt": [1, 16, 22, 34, 121, 247, 562, 854, 1526, 4294, 7891, 9240],
	"dig": [2, 18, 23, 89, 291, 438],
	"add": [3, 11, 75, 91, 193, 625, 3447, 9423, 44031],
	"mul": [15, 20, 257, 690, 3644, 6433, 49514, 97001],
	"sub": [40, 147, 640, 3103, 8118, 30870, 61589, 227887],
	"pow": [64, 187, 983, 4563, 5684, 11067, 92927, 8312675],
}
const SEQ_GROW := 1.6
const SEQ_BAND := 0.1
## The counts a rank asks for, the belt's; a track's are these times its
## FIRST over the belt's. Past the table each count is COUNT_UP more a rank.
const RANK_COUNTS := [[40], [200, 100], [800, 600, 300], [1800, 1400, 1200], [1800, 1400, 1200],
	[2200, 1800, 1600], [3000, 2400, 2000], [4000, 3200, 2400]]
const FIRST := {"belt": 40, "dig": 60, "add": 90, "mul": 100, "sub": 120, "pow": 160}
const COUNT_UP := 100
const ADDER := [0.25, 0.3333, 0.4, 0.5, 0.6667, 1.0, 1.5, 2.0]

static var path := "user://tally.cfg"

var seed_v := 0
var level := 1
var got := 0
var made := 0
var lv := {}
var ledger := {}
var events: Array = []
var clock := 0.0
## Ranks that could be bought when last looked, so `ready` is said once.
var _could := {}
var _looked := 0.0

var kind := PackedByteArray()
var face := PackedByteArray()
## A bridge's up-and-down lane's way; the across lane's is `face`.
var face2 := PackedByteArray()
var dep := PackedInt32Array()

var occ := PackedByteArray()
var val := PackedInt64Array()
var prog := PackedFloat32Array()
var from_d := PackedByteArray()
var to_d := PackedByteArray()
var rr_in := PackedByteArray()
var rr_out := PackedByteArray()

## The slots tokens ride, and where each hands on.
var lanes := PackedInt32Array()
var outs := {}          # slot -> PackedInt32Array of ends
var feeders := {}       # slot or machine side id -> PackedInt32Array of slots
var machines := {}      # square -> {a, b, out, rem, busy, t, x, y, last}
var digs := {}          # square -> {budget, rr, outs}
var crates := {}        # square -> {v, n, rr, outs}

var _targets: Array = []
var _trng := RandomNumberGenerator.new()
var _seqs := {}

func _init(rng_seed := 0) -> void:
	seed_v = rng_seed if rng_seed != 0 else (randi() | 1)
	kind.resize(N)
	face.resize(N)
	face2.resize(N)
	dep.resize(N)
	occ.resize(N2)
	val.resize(N2)
	prog.resize(N2)
	from_d.resize(N2)
	to_d.resize(N2)
	to_d.fill(NONE)
	rr_in.resize(N2)
	rr_out.resize(N2)
	for id: String in TRACKS:
		lv[id] = 1
	for y in HUB:
		for x in HUB:
			kind[_i(HUB_AT + Vector2i(x, y))] = BOX
	_trng.seed = seed_v
	_print_paper()
	_draw_seqs()
	_wire()

func _emit(type: String, more := {}) -> void:
	var ev := {"type": type}
	ev.merge(more)
	events.append(ev)

# --- squares ---

static func _i(t: Vector2i) -> int:
	return t.y * W + t.x

static func tile_of(i: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(i % W, i / W)

static func inside(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H

static func opp(d: int) -> int:
	return (d + 2) % 4

static func left_of(d: int) -> int:
	return (d + 3) % 4

static func right_of(d: int) -> int:
	return (d + 1) % 4

static func is_op(k: int) -> bool:
	return k >= ADD and k <= POW

func kind_at(t: Vector2i) -> int:
	return kind[_i(t)] if inside(t) else -1

func face_at(t: Vector2i) -> int:
	return face[_i(t)]

func dep_at(t: Vector2i) -> int:
	return dep[_i(t)] if inside(t) else 0

func box_rect() -> Rect2i:
	return Rect2i(HUB_AT, Vector2i(HUB, HUB))

## How many squares `t` is from the box's edge (0 on it).
static func ring(t: Vector2i) -> int:
	var dx := maxi(HUB_AT.x - t.x, t.x - (HUB_AT.x + HUB - 1))
	var dy := maxi(HUB_AT.y - t.y, t.y - (HUB_AT.y + HUB - 1))
	return maxi(maxi(dx, dy), 0)

## Prints the numbers on the paper: each value its count of squares in its
## band of rings, none next to another or to the box.
func _print_paper() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x5eed
	var rows: Array = DEPOSITS.duplicate()
	for f: Array in FAR:
		for v in range(int(f[0]), int(f[1]) + 1):
			var many: int = f[2] if f[2] > 1 else (2 if rng.randf() < 0.4 else 1)
			rows.append([v, many, f[3], f[4]])
	for r: Array in rows:
		var placed := 0
		var tries := 0
		while placed < int(r[1]) and tries < 4000:
			tries += 1
			var t := Vector2i(rng.randi_range(0, W - 1), rng.randi_range(0, H - 1))
			var d := ring(t)
			if d < int(r[2]) or d > int(r[3]) or not _clear_round(t):
				continue
			dep[_i(t)] = int(r[0])
			placed += 1

func _clear_round(t: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var u := t + Vector2i(dx, dy)
			if inside(u) and (dep[_i(u)] != 0 or kind[_i(u)] == BOX):
				return false
	return true

# --- numbers ---

static func sat(x: int) -> int:
	return clampi(x, FLOOR, LIMIT)

## A^B by repeated multiplication with the clamp; A^0 is 1, a negative power
## is 0 unless the base is 1 or -1.
static func power(a: int, b: int) -> int:
	if b == 0:
		return 1
	if a == 1:
		return 1
	if a == -1:
		return -1 if b % 2 != 0 else 1
	if b < 0 or a == 0:
		return 0
	var r := 1
	for k in b:
		r *= a
		if r > LIMIT or r < FLOOR:
			return FLOOR if a < 0 and b % 2 != 0 else LIMIT
	return r

## [quotient, remainder]: truncating, A ÷ 0 = (0, A); the caller leaves a
## zero remainder out (but not a division by 0's).
static func divide(a: int, b: int) -> Array:
	if b == 0:
		return [0, a]
	@warning_ignore("integer_division")
	var q := a / b
	return [sat(q), a - b * q]

static func apply(k: int, a: int, b: int) -> int:
	match k:
		ADD:
			return sat(a + b)
		MUL:
			return sat(a * b)
		SUB:
			return sat(a - b)
		POW:
			return power(a, b)
	return 0

## A number as a token says it: four figures whole, then 12.4k, 3.1M, 2.1B.
static func short(v: int) -> String:
	var a := absi(v)
	var neg := "-" if v < 0 else ""
	if a < 10000:
		return str(v)
	for u: Array in [[1000000000, "B"], [1000000, "M"], [1000, "k"]]:
		if a >= int(u[0]):
			var x := float(a) / float(u[0])
			if x >= 100.0:
				return neg + str(int(x)) + String(u[1])
			return neg + String.num(floorf(x * 10.0) / 10.0, 1).trim_suffix(".0") + String(u[1])
	return str(v)

# --- the ladder ---

func target_of(n: int) -> int:
	while _targets.size() < n:
		_targets.append(_next_target(_targets.size() + 1))
	return int(_targets[n - 1])

func _next_target(n: int) -> int:
	var last: int = _targets[-1] if not _targets.is_empty() else 0
	if n <= LADDER.size():
		var base := int(LADDER[n - 1][0])
		if n < BAND_FROM:
			return base
		var t := int(round(base * _trng.randf_range(1.0 - BAND, 1.0 + BAND)))
		return maxi(t, last + 1)
	if last >= TOP:
		return TOP
	var g := _trng.randf_range(GROW.x, GROW.y)
	if last > SLOW_PAST:
		g *= 0.5
	return mini(maxi(int(round(last * (1.0 + g))), last + 1), TOP)

func count_of(n: int) -> int:
	if n <= LADDER.size():
		return int(LADDER[n - 1][1])
	return mini(COUNT_TOP, int(LADDER[-1][1]) + COUNT_STEP * (n - LADDER.size()))

func target() -> int:
	return target_of(level)

func count() -> int:
	return count_of(level)

## What level `n`'s end hands over: a kind (> 0), a number (< 0) or 0.
func reward_of(n: int) -> int:
	if n <= LADDER.size() and int(LADDER[n - 1][2]) != 0:
		return int(LADDER[n - 1][2])
	var v := n - DIG_FROM
	return -v if v <= MOST and v > 15 else 0

func has(k: int) -> bool:
	return level > int(UNLOCK.get(k, 0))

## The level whose end lets `v` be dug (0: from the start; -1: never).
static func dig_level(v: int) -> int:
	if v == 1:
		return 0
	for n in LADDER.size():
		if int(LADDER[n][2]) == -v:
			return n + 1
	if v >= 16 and v <= MOST:
		return v + DIG_FROM
	return -1

func can_dig(v: int) -> bool:
	var at := dig_level(v)
	return at >= 0 and level > at

# --- the upgrades ---

func _draw_seqs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x7a11
	for id: String in TRACKS:
		_seqs[id] = []
		for k in SEQ[id].size():
			var v := int(SEQ[id][k])
			if k > 0:
				v = int(round(v * rng.randf_range(1.0 - SEQ_BAND, 1.0 + SEQ_BAND)))
			_seqs[id].append(v)

func _seq(id: String, k: int) -> int:
	var s: Array = _seqs[id]
	while s.size() <= k:
		s.append(int(round(int(s[-1]) * SEQ_GROW)) + 1)
	return int(s[k])

func track_open(id: String) -> bool:
	return has(int(TRACK_KIND[id]))

func at_top(id: String) -> bool:
	return int(lv[id]) >= int(TRACK_TOP[id])

## What the next rank of `id` asks: [[number, count], ...] (one, two, then
## three sliding).
func asks(id: String) -> Array:
	var r := int(lv[id])
	var ks: Array = [0] if r == 1 else ([0, 1] if r == 2 else [r - 3, r - 2, r - 1])
	var counts: Array
	if r <= RANK_COUNTS.size():
		counts = RANK_COUNTS[r - 1]
	else:
		counts = []
		for c: int in RANK_COUNTS[-1]:
			counts.append(c + COUNT_UP * (r - RANK_COUNTS.size()))
	var f := float(FIRST[id]) / float(FIRST["belt"])
	var out := []
	for j in ks.size():
		out.append([_seq(id, int(ks[j])), int(round(int(counts[j]) * f / 10.0)) * 10])
	return out

func held(v: int) -> int:
	return int(ledger.get(v, 0))

func can_buy(id: String) -> bool:
	if not track_open(id) or at_top(id):
		return false
	for a: Array in asks(id):
		if held(int(a[0])) < int(a[1]):
			return false
	return true

func buy(id: String) -> bool:
	if not can_buy(id):
		_emit("refused", {"why": "short"})
		return false
	for a: Array in asks(id):
		ledger[int(a[0])] = held(int(a[0])) - int(a[1])
	lv[id] = int(lv[id]) + 1
	_could.erase(id)
	_emit("upgrade", {"id": id, "level": lv[id]})
	return true

func any_ready() -> bool:
	for id: String in TRACKS:
		if can_buy(id):
			return true
	return false

## Squares a second.
func belt_speed() -> float:
	var l := int(lv.belt)
	return float(l) if l <= 8 else 8.0 + 0.1 * (l - 8)

static func speed_for(id: String, l: int) -> float:
	match id:
		"belt":
			return float(l) if l <= 8 else 8.0 + 0.1 * (l - 8)
		"dig":
			return float(l)
		"add":
			return float(ADDER[l - 1]) if l <= 8 else 2.0 + 0.02 * (l - 8)
	if l <= 7:
		return 0.1 * (l + 1)
	return 1.0 + 0.02 * (l - 8)

func dig_belts() -> int:
	return int(lv.dig)

## Operations a second for an operator.
func op_speed(k: int) -> float:
	match k:
		ADD:
			return speed_for("add", int(lv.add))
		MUL:
			return speed_for("mul", int(lv.mul))
		SUB, DIV:
			return speed_for("sub", int(lv.sub))
		POW:
			return speed_for("pow", int(lv.pow))
	return 0.0

# --- building ---

## Why `k` cannot go on `t` facing anything, or "" when it can.
func why_not(k: int, t: Vector2i) -> String:
	if not inside(t):
		return "edge"
	var i := _i(t)
	if not has(k):
		return "locked"
	var here := int(kind[i])
	if here == BOX:
		return "box"
	if here != EMPTY and here != BELT and here != BRIDGE:
		return "taken"
	if k == DIG:
		if dep[i] == 0:
			return "no_number"
		if not can_dig(dep[i]):
			return "not_yet"
	return ""

func place(k: int, t: Vector2i, f: int) -> bool:
	var why := why_not(k, t)
	if why != "":
		_emit("refused", {"why": why, "tile": t, "v": dep_at(t)})
		return false
	var i := _i(t)
	_clear(i)
	kind[i] = k
	face[i] = f
	_wire()
	_emit("place", {"kind": k, "tile": t})
	return true

## Whether a run of belt may go over `t`.
func can_lay(t: Vector2i) -> bool:
	if not inside(t):
		return false
	var k := int(kind[_i(t)])
	return k == EMPTY or k == BELT or k == BRIDGE

## Lays belt over `tiles` (a straight run, in order) going `f`; stops at the
## first square it cannot. A belt across the run's way in its middle is
## bridged once bridges are had, and turned otherwise; at the run's ends it
## is turned. Returns the squares laid or changed.
func lay_run(tiles: Array, f: int) -> int:
	var n := 0
	var last := tiles.size() - 1
	var across := f % 2 == 0
	for j in tiles.size():
		var t: Vector2i = tiles[j]
		if not can_lay(t):
			break
		var i := _i(t)
		var k := int(kind[i])
		if k == EMPTY:
			kind[i] = BELT
			face[i] = f
			_drop(i)
		elif k == BELT:
			var same_axis := int(face[i]) % 2 == f % 2
			if same_axis or j == 0 or j == last or not has(BRIDGE):
				if int(face[i]) == f and tiles.size() > 1:
					continue
				face[i] = f
				to_d[i] = NONE
			else:
				var other := int(face[i])
				kind[i] = BRIDGE
				face[i] = f if across else other
				face2[i] = other if across else f
				_drop(i)
		elif k == BRIDGE:
			if across:
				face[i] = f
			else:
				face2[i] = f
			_drop(i)
		n += 1
	if n > 0:
		_wire()
		_emit("lay", {"n": n, "tiles": tiles.slice(0, n)})
	return n

## Turns what stands on `t` a quarter clockwise.
func turn(t: Vector2i) -> bool:
	if not inside(t):
		return false
	var i := _i(t)
	var k := int(kind[i])
	if k == EMPTY or k == BOX or k == DIG or k == CRATE or k == BRIDGE:
		return false
	face[i] = (int(face[i]) + 1) % 4
	if k == BELT:
		to_d[i] = NONE
	_wire()
	_emit("turn", {"kind": k, "tile": t, "face": int(face[i])})
	return true

func remove(t: Vector2i) -> bool:
	if not inside(t):
		return false
	var i := _i(t)
	var k := int(kind[i])
	if k == EMPTY or k == BOX:
		return false
	_clear(i)
	kind[i] = EMPTY
	_wire()
	_emit("lift", {"kind": k, "tile": t})
	return true

## A crate's number thrown out, so it takes the next that comes.
func empty_crate(t: Vector2i) -> bool:
	var i := _i(t)
	if not crates.has(i) or int(crates[i].n) == 0:
		return false
	crates[i].n = 0
	crates[i].v = 0
	_emit("emptied", {"tile": t})
	return true

## Every token on a square's lanes falls off.
func _drop(i: int) -> void:
	for s in [i, i + N]:
		occ[s] = 0
		to_d[s] = NONE

func _clear(i: int) -> void:
	_drop(i)
	machines.erase(i)
	digs.erase(i)
	crates.erase(i)

# --- the wiring ---

## Where a token going `d` into square `t2` would be handed, or -1.
func _end_into(t2: Vector2i, d: int) -> int:
	if not inside(t2):
		return -1
	var i := _i(t2)
	match int(kind[i]):
		BELT:
			if int(face[i]) == opp(d):
				return -1
			return (i << 2) | d
		BRIDGE:
			if d % 2 == 0:
				return (i << 2) | d if int(face[i]) == d else -1
			return ((i + N) << 2) | d if int(face2[i]) == d else -1
		ADD, MUL, SUB, DIV, POW:
			var f := int(face[i])
			var enter := opp(d)
			if enter == left_of(f):
				return ((N2 + i * 4) << 2) | d
			if enter == right_of(f):
				return ((N2 + i * 4 + 1) << 2) | d
			return -1
		CRATE:
			return ((N2 + i * 4 + 2) << 2) | d
		BOX:
			return ((N2 + i * 4 + 3) << 2) | d
	return -1

## The belts leading away from square `t` (a dig's, a crate's).
func _away_from(t: Vector2i) -> PackedInt32Array:
	var o := PackedInt32Array()
	for d in 4:
		var u: Vector2i = t + DIRS[d]
		if inside(u) and int(kind[_i(u)]) == BELT and int(face[_i(u)]) == d:
			o.append((_i(u) << 2) | d)
	return o

func _feed(id: int, s: int) -> void:
	if not feeders.has(id):
		feeders[id] = PackedInt32Array()
	feeders[id].append(s)

## Works out every slot's ends again after the paper changed.
func _wire() -> void:
	lanes = PackedInt32Array()
	outs = {}
	feeders = {}
	for i in N:
		var k := int(kind[i])
		var t := tile_of(i)
		if k == BELT:
			var f := int(face[i])
			var o := PackedInt32Array()
			var e := _end_into(t + DIRS[f], f)
			if e >= 0:
				o.append(e)
			for sd: int in [left_of(f), right_of(f)]:
				var u: Vector2i = t + DIRS[sd]
				if inside(u) and int(kind[_i(u)]) == BELT and int(face[_i(u)]) == sd:
					o.append((_i(u) << 2) | sd)
			lanes.append(i)
			outs[i] = o
		elif k == BRIDGE:
			for lane in 2:
				var s := i + lane * N
				var f := int(face[i]) if lane == 0 else int(face2[i])
				var o := PackedInt32Array()
				var e := _end_into(t + DIRS[f], f)
				if e >= 0:
					o.append(e)
				lanes.append(s)
				outs[s] = o
		else:
			occ[i] = 0
			occ[i + N] = 0
			if k == DIG:
				if not digs.has(i):
					digs[i] = {"budget": 0.0, "rr": 0}
				digs[i].outs = _away_from(t)
			elif k == CRATE:
				if not crates.has(i):
					crates[i] = {"v": 0, "n": 0, "rr": 0}
				crates[i].outs = _away_from(t)
			elif is_op(k):
				if not machines.has(i):
					machines[i] = {"a": [], "b": [], "out": [], "rem": [], "busy": false, "t": 0.0, "x": 0, "y": 0, "last": 0, "has_last": false}
				var f := int(face[i])
				machines[i].front = _end_into(t + DIRS[f], f)
				machines[i].back = _end_into(t + DIRS[opp(f)], opp(f)) if k == DIV else -1
		if k != BRIDGE:
			occ[i + N] = 0
	for s: int in lanes:
		for e: int in outs[s]:
			_feed(e >> 2, s)
		if to_d[s] != NONE and int(to_d[s]) >= (outs[s] as PackedInt32Array).size():
			to_d[s] = NONE

# --- tokens moving ---

func _accepts(e: int, v: int) -> bool:
	var id := e >> 2
	if id < N2:
		return occ[id] == 0
	var i := (id - N2) >> 2
	match (id - N2) & 3:
		0:
			return machines.has(i) and (machines[i].a as Array).size() < QUEUE
		1:
			return machines.has(i) and (machines[i].b as Array).size() < QUEUE
		2:
			if not crates.has(i):
				return false
			var c: Dictionary = crates[i]
			return int(c.n) < CRATE_MAX and (int(c.n) == 0 or int(c.v) == v)
	return true

func _put(e: int, v: int, over: float) -> void:
	var id := e >> 2
	if id < N2:
		occ[id] = 1
		val[id] = v
		prog[id] = clampf(over, 0.0, 0.95)
		from_d[id] = e & 3
		to_d[id] = NONE
		return
	var i := (id - N2) >> 2
	match (id - N2) & 3:
		0:
			machines[i].a.append(v)
		1:
			machines[i].b.append(v)
		2:
			var c: Dictionary = crates[i]
			if int(c.n) == 0:
				c.v = v
			c.n = int(c.n) + 1
		3:
			_deliver(v, i)

func _choose(s: int) -> void:
	var o: PackedInt32Array = outs[s]
	if o.is_empty():
		return
	if o.size() == 1:
		to_d[s] = 0
		return
	var start := int(rr_out[s]) % o.size()
	var pick := start
	for k in o.size():
		var j := (start + k) % o.size()
		if _accepts(o[j], val[s]):
			pick = j
			break
	to_d[s] = pick
	rr_out[s] = (pick + 1) % o.size()

## Tries to hand on the token at `s0`, and as each slot empties, the ones
## waiting to come into it.
func _try_move(s0: int) -> void:
	var stack := [s0]
	var guard := 0
	while not stack.is_empty() and guard < 4000:
		guard += 1
		var s: int = stack.pop_back()
		if occ[s] == 0 or prog[s] < 1.0:
			continue
		var o: PackedInt32Array = outs[s]
		if o.is_empty():
			continue
		if to_d[s] == NONE:
			_choose(s)
		var j := int(to_d[s])
		if not _accepts(o[j], val[s]):
			var found := -1
			for k in range(1, o.size()):
				var jj := (j + k) % o.size()
				if _accepts(o[jj], val[s]):
					found = jj
					break
			if found < 0:
				continue
			j = found
			to_d[s] = j
		var v := val[s]
		var over := prog[s] - 1.0
		occ[s] = 0
		to_d[s] = NONE
		_put(o[j], v, over)
		_wake(s, stack)

## The slots waiting to hand into `id` (a slot, or a machine side's id) go
## on the stack, from the one after the last let in.
func _wake(id: int, stack: Array) -> void:
	if not feeders.has(id):
		return
	var fs: PackedInt32Array = feeders[id]
	var key := id if id < N2 else 0
	var start := int(rr_in[key]) % fs.size() if id < N2 else 0
	for k in fs.size():
		var s := fs[(start + k) % fs.size()]
		if occ[s] == 1 and prog[s] >= 1.0:
			stack.append(s)
	if id < N2:
		rr_in[id] = (start + 1) % 256

func _deliver(v: int, _i_box: int) -> void:
	ledger[v] = held(v) + 1
	made += 1
	if v == target():
		got += 1
		_emit("hit", {"v": v})
		if got >= count():
			_level_up()

func _level_up() -> void:
	var done := level
	level += 1
	got = 0
	var r := reward_of(done)
	_emit("level", {"n": level, "reward": r})
	if r != 0:
		_emit("unlock", {"reward": r})

func step(dt: float) -> void:
	var left := dt
	while left > 0.0:
		var d := minf(left, STEP)
		left -= d
		_step_once(d)
	clock += dt
	if clock - _looked > 0.5:
		_looked = clock
		for id: String in TRACKS:
			var can := can_buy(id)
			if can and not _could.get(id, false):
				_emit("ready", {"id": id})
			_could[id] = can

func _step_once(d: float) -> void:
	var adv := belt_speed() * d
	var ready := PackedInt32Array()
	for s: int in lanes:
		if occ[s] == 0:
			continue
		var p := prog[s] + adv
		if p >= 0.5 and to_d[s] == NONE:
			_choose(s)
		if p >= 1.0:
			ready.append(s)
		prog[s] = p
	for s: int in ready:
		_try_move(s)
	# what still could not move waits at the edge, so it does not run on
	for s: int in ready:
		if occ[s] == 1 and prog[s] > 1.0:
			prog[s] = 1.0
	_step_machines(d)
	_step_digs(d)

func _step_machines(d: float) -> void:
	for i: int in machines:
		var m: Dictionary = machines[i]
		var k := int(kind[i])
		if bool(m.busy):
			m.t = float(m.t) + op_speed(k) * d
			if float(m.t) >= 1.0:
				m.busy = false
				var a := int(m.x)
				var b := int(m.y)
				var r: int
				if k == DIV:
					var qr := divide(a, b)
					r = int(qr[0])
					m.out.append(r)
					if int(qr[1]) != 0 or b == 0:
						m.rem.append(int(qr[1]))
				else:
					r = apply(k, a, b)
					m.out.append(r)
				m.last = r
				m.has_last = true
				_emit("op", {"i": i, "v": r})
		if not bool(m.busy) and not (m.a as Array).is_empty() and not (m.b as Array).is_empty() \
				and (m.out as Array).size() < OUT and (k != DIV or (m.rem as Array).size() < OUT):
			m.x = m.a.pop_front()
			m.y = m.b.pop_front()
			m.busy = true
			m.t = 0.0
			var stack := []
			_wake(N2 + i * 4, stack)
			_wake(N2 + i * 4 + 1, stack)
			for s: int in stack:
				_try_move(s)
		_push(m.out, int(m.front))
		_push(m.rem, int(m.back))

func _push(q: Array, e: int) -> void:
	while not q.is_empty() and e >= 0 and _accepts(e, int(q[0])):
		_put(e, int(q.pop_front()), 0.0)
		# a slot takes one at a time
		if (e >> 2) < N2:
			break

func _step_digs(d: float) -> void:
	var speed := belt_speed()
	for i: int in digs:
		var g: Dictionary = digs[i]
		var o: PackedInt32Array = g.outs
		var n := mini(o.size(), dig_belts())
		if n == 0:
			g.budget = 0.0
			continue
		g.budget = minf(float(g.budget) + n * speed * d, float(n))
		var v := int(dep[i])
		while float(g.budget) >= 1.0:
			var put := false
			for k in o.size():
				var j := (int(g.rr) + k) % o.size()
				if _accepts(o[j], v):
					_put(o[j], v, 0.0)
					g.rr = (j + 1) % o.size()
					put = true
					break
			if not put:
				break
			g.budget = float(g.budget) - 1.0
	for i: int in crates:
		var c: Dictionary = crates[i]
		var o: PackedInt32Array = c.outs
		for k in o.size():
			if int(c.n) <= 0:
				break
			var j := (int(c.rr) + k) % o.size()
			if _accepts(o[j], int(c.v)):
				_put(o[j], int(c.v), 0.0)
				c.n = int(c.n) - 1
				c.rr = (j + 1) % o.size()

## Which way the token in `s` leaves: its chosen end's, or the lane's own.
func exit_dir(s: int) -> int:
	var o: PackedInt32Array = outs.get(s, PackedInt32Array())
	if to_d[s] != NONE and int(to_d[s]) < o.size():
		return o[int(to_d[s])] & 3
	var i := s % N
	return int(face2[i]) if s >= N else int(face[i])

## The numbers the box has had, most first, with the current target first.
func tally_rows(most := 12) -> Array:
	var rows := []
	for v: int in ledger:
		if held(v) > 0:
			rows.append([v, held(v)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	return rows.slice(0, most)

# --- kept ---

func save() -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	var pieces := PackedInt32Array()
	for i in N:
		var k := int(kind[i])
		if k != EMPTY and k != BOX:
			pieces.append_array([i, k, int(face[i]), int(face2[i])])
	var keys := PackedInt64Array()
	var counts := PackedInt64Array()
	for v: int in ledger:
		if held(v) > 0:
			keys.append(v)
			counts.append(held(v))
	var crate_rows := PackedInt64Array()
	for i: int in crates:
		crate_rows.append_array([i, int(crates[i].v), int(crates[i].n)])
	cfg.set_value("paper", "ver", VER)
	cfg.set_value("paper", "seed", seed_v)
	cfg.set_value("paper", "level", level)
	cfg.set_value("paper", "got", got)
	cfg.set_value("paper", "made", made)
	cfg.set_value("paper", "lv", lv)
	cfg.set_value("paper", "pieces", pieces)
	cfg.set_value("paper", "keys", keys)
	cfg.set_value("paper", "counts", counts)
	cfg.set_value("paper", "crates", crate_rows)
	cfg.save(path)

static func load_saved(rng_seed := 0) -> RefCounted:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(path) != OK:
		return new(rng_seed)
	var s = new(int(cfg.get_value("paper", "seed", rng_seed)))
	s.level = maxi(1, int(cfg.get_value("paper", "level", 1)))
	s.got = maxi(0, int(cfg.get_value("paper", "got", 0)))
	s.made = maxi(0, int(cfg.get_value("paper", "made", 0)))
	var levels: Dictionary = cfg.get_value("paper", "lv", {})
	for id: String in TRACKS:
		s.lv[id] = clampi(int(levels.get(id, 1)), 1, int(TRACK_TOP[id]))
	var pieces: PackedInt32Array = cfg.get_value("paper", "pieces", PackedInt32Array())
	for j in range(0, pieces.size() - 3, 4):
		var i := pieces[j]
		var k := pieces[j + 1]
		if i < 0 or i >= N or s.kind[i] == BOX or k <= EMPTY or k >= BOX:
			continue
		s.kind[i] = k
		s.face[i] = clampi(pieces[j + 2], 0, 3)
		s.face2[i] = clampi(pieces[j + 3], 0, 3)
	var keys: PackedInt64Array = cfg.get_value("paper", "keys", PackedInt64Array())
	var counts: PackedInt64Array = cfg.get_value("paper", "counts", PackedInt64Array())
	for j in mini(keys.size(), counts.size()):
		s.ledger[int(keys[j])] = int(counts[j])
	s._wire()
	var crate_rows: PackedInt64Array = cfg.get_value("paper", "crates", PackedInt64Array())
	for j in range(0, crate_rows.size() - 2, 3):
		var i := int(crate_rows[j])
		if s.crates.has(i):
			s.crates[i].v = int(crate_rows[j + 1])
			s.crates[i].n = clampi(int(crate_rows[j + 2]), 0, CRATE_MAX)
	for id: String in TRACKS:
		s._could[id] = s.can_buy(id)
	return s

## The paper as the Arcade tab's card reads it, without running anything.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(path) != OK:
		return {"level": 0, "made": 0}
	return {"level": int(cfg.get_value("paper", "level", 1)), "made": int(cfg.get_value("paper", "made", 0))}
