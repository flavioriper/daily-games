extends RefCounted

## Tally's paper as pure data: no nodes, no clock of its own (spec
## docs/superpowers/specs/2026-10-15-arcade-tally-design.md). A sheet of
## W by H squares with the counting box (the hub, HUB by HUB) in the middle
## and numbers printed about it (`dep`, by the save's seed, the small ones
## close, the rest far apart). A piece is one square but the operators:
##
## - a **belt** carries one token a square at `belt_speed()` squares a
##   second, to the square in front and nowhere else (it never splits); it
##   takes from its back and its sides, never its front (a corner, a join:
##   a line drawn to end on another runs into its side); one that hands
##   nothing on holds its token at its middle, where its drawn bed ends;
## - a **bridge** (a crossing) is two belts crossing, each lane straight
##   on: made by drawing across a line, never set down;
## - a **dig** covers the three by three squares round a printed number
##   and puts it on every belt leading away from its edge (and on a line's
##   first belt running along it), `dig_belts()` belts' worth;
## - the five **operators** cover two to four squares (`SHAPES`, after the
##   reference's footprints): an A square and a B square that take from
##   any edge, and answer squares that hand out of any free edge (the
##   divider's remainder square too); 4 waiting a side and
##   2 to go out. Every square of one carries its kind and facing; `root`
##   names the square the machine is kept under (its first answer square)
##   and `role` what each square is;
## - a **crate** keeps up to CRATE_MAX of the first number it gets and lets
##   them out on every belt leading away;
## - the **box** takes everything from every side;
## - a **part** is the player's own piece (the user, 2026-10-19: "create a
##   submodule with operations inside it ... define input and output"): a
##   grid of `w` by `h` squares built on the bench (a blank sheet, `blank`,
##   whose `frame` is the grid) with belts and operators, its **ports** on
##   the grid's edge squares, each a way out of the grid and in or out. A
##   copy set down on the paper covers its grid's squares (turned by `rot`
##   quarter turns) and its inside is written onto them, tagged with the
##   copy's anchor in `part`, so it runs as any belts and machines do; a
##   token crosses a copy's edge only at a port, the way the port goes
##   (`gates`). A part's inside changed is written again into every copy.
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

## 2: the operators' footprints and the bigger paper; 3: the six-square
## box, the three-square dig and the numbers spread over a bigger sheet. A
## sheet kept under VER keeps its level, tally and upgrades, and its pieces
## are not read.
const VER := 3
const W := 120
const H := 120
const N := W * H
const N2 := N * 2
const HUB := 6
const HUB_AT := Vector2i(57, 57)

enum { EMPTY, BELT, BRIDGE, DIG, ADD, MUL, SUB, DIV, POW, CRATE, BOX, SPLIT, JOIN, PART }
const OPS := [ADD, MUL, SUB, DIV, POW]
const KIND_IDS := {BELT: "belt", BRIDGE: "bridge", DIG: "dig", ADD: "add", MUL: "mul", SUB: "sub", DIV: "div", POW: "pow", CRATE: "crate", BOX: "box"}
## The level whose end hands a piece over (it is had from the level after).
## SPLIT and JOIN were pieces once (a save's own may still hold them: read
## as belts); a crossing is had from the start.
const UNLOCK := {BELT: 0, DIG: 0, ADD: 1, MUL: 7, SUB: 13, DIV: 16, POW: 19, CRATE: 22}

## A port's way: tokens come in, or go out.
enum { P_IN, P_OUT }
## A part's grid, a side.
const PART_LEAST := 2
const PART_MOST := 12

## What an operator's square is.
enum { R_NONE, R_A, R_B, R_OUT, R_REM }
## Each operator's squares as [across, back, role] facing north: across +1
## is the right hand, back +1 the square behind; [0, 0] is the root, an
## answer square. A and B take from any edge, OUT and REM give from any
## free edge (facing north matters only to the shape).
const SHAPES := {
	ADD: [[0, 0, R_OUT], [1, 0, R_OUT], [0, 1, R_A], [1, 1, R_B]],
	MUL: [[-1, 0, R_A], [0, 0, R_OUT], [1, 0, R_B]],
	SUB: [[0, 0, R_OUT], [1, 0, R_A], [0, 1, R_B]],
	DIV: [[0, 0, R_OUT], [1, 0, R_REM], [0, 1, R_A], [1, 1, R_B]],
	POW: [[0, 0, R_OUT], [-1, 0, R_A], [0, 1, R_B]],
	# the dig, its root the printed number in the middle
	DIG: [[0, 0, R_NONE], [-1, -1, R_NONE], [0, -1, R_NONE], [1, -1, R_NONE], [-1, 0, R_NONE],
		[1, 0, R_NONE], [-1, 1, R_NONE], [0, 1, R_NONE], [1, 1, R_NONE]],
}

## East, south, west, north: clockwise, +y down.
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const NONE := 255
## No square: a path begun on nothing.
const NOWHERE := Vector2i(-1, -1)

## A machine's room a side and for what waits to go out.
const QUEUE := 4
const OUT := 2
const CRATE_MAX := 500
## The longest step taken in one go: a token at 20 squares a second moves
## two thirds of a square in it.
const STEP := 1.0 / 30.0
## A machine idle with one side fed and the other empty this long is
## starving on the empty side (`starving`).
const STARVE_AFTER := 3.0
## Non-target numbers into the box, with none of the target, before the
## box says they do not count.
const OFF_SAY := 20
const LIMIT := 2147483647
const FLOOR := -2147483648

# --- the ladder ---

## Each level: the sample target, the count, the reward (a piece's kind, a
## number now dug, or 0). From level 6 the target is drawn round the sample.
const LADDER := [
	[1, 10, ADD], [2, 15, 0], [3, 20, -2], [5, 25, 0], [10, 30, -3],
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
	[1, 6, 7, 15], [2, 5, 9, 19], [3, 4, 11, 22], [4, 4, 13, 25], [5, 4, 14, 27],
	[6, 3, 16, 30], [7, 3, 17, 32], [8, 3, 19, 34], [9, 3, 20, 35],
]
## Past 9: two of each from 11 to 39, one or two from 40 to MOST.
const FAR := [[11, 19, 2, 24, 40], [20, 39, 2, 31, 47], [40, 60, 1, 38, 53]]
## No printed number has another, or the box, within this many squares:
## two digs side by side leave APART - 3 squares between them, room for an
## operator and its belts.
const APART := 6

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
## The flow into the box is counted over this many seconds, a bucket a
## second (not saved: it fills again as the paper runs).
const FLOW_FOR := 30

var seed_v := 0
var level := 1
var got := 0
var made := 0
var lv := {}
var ledger := {}
var events: Array = []
var clock := 0.0
## What came into the box, a {value: count} bucket a second over the last
## FLOW_FOR seconds; `_flow_sec` the second the newest is for, `_flow_t0`
## when counting began.
var _flow: Array = []
var _flow_sec := -1
var _flow_t0 := 0.0
## Ranks that could be bought when last looked, so `ready` is said once.
var _could := {}
var _looked := 0.0
## What the last gesture changed: square -> [kind, face, face2, root, role,
## fork] before it.
var _undo := {}
## The belt tool keeps to straight lines (the hand's toggle, kept with the paper).
var straight := true
## Numbers into the box this level that were not the target, and the last
## such number; `off_target` is said once when OFF_SAY come with no hit.
var off := 0
var off_v := 0
var _off_said := false

var kind := PackedByteArray()
var face := PackedByteArray()
## A bridge's up-and-down lane's way; the across lane's is `face`.
var face2 := PackedByteArray()
## A belt's forks: a bit for each side way it also hands on to, by turns
## with its own way (a path begun on a line across it branches it there).
var fork := PackedByteArray()
var root := PackedInt32Array()
var role := PackedByteArray()
var dep := PackedInt32Array()
## The anchor square of the copy of a part covering each square, or -1.
var part := PackedInt32Array()
## The parts: id -> {name, w, h, pieces: [[x, y, kind, face, face2, fork]],
## ports: [[x, y, way, io]]} on the grid as built (an operator by its root).
var defs := {}
var next_def := 1
## The copies set down: anchor square -> [id, rot].
var copies := {}
## Every copy's ports: (square << 2) | way out of the copy -> P_IN or P_OUT.
var gates := {}
## The copies as they were before the gesture since `mark()`, or null.
var _undo_copies = null
## A bench: a blank sheet (no box, no numbers) for building one part's
## inside within `frame`, its ports as Vector3i(x, y, way) -> io.
var blank := false
var frame := Rect2i()
var bench_ports := {}

var occ := PackedByteArray()
var val := PackedInt64Array()
var prog := PackedFloat32Array()
var from_d := PackedByteArray()
var to_d := PackedByteArray()
var rr_in := PackedByteArray()
var rr_out := PackedByteArray()
## 1 for a slot that hands nothing on.
var dead := PackedByteArray()

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

func _init(rng_seed := 0, blank_sheet := false) -> void:
	seed_v = rng_seed if rng_seed != 0 else (randi() | 1)
	blank = blank_sheet
	kind.resize(N)
	face.resize(N)
	face2.resize(N)
	fork.resize(N)
	root.resize(N)
	root.fill(-1)
	role.resize(N)
	dep.resize(N)
	part.resize(N)
	part.fill(-1)
	occ.resize(N2)
	val.resize(N2)
	prog.resize(N2)
	from_d.resize(N2)
	to_d.resize(N2)
	to_d.fill(NONE)
	rr_in.resize(N2)
	rr_out.resize(N2)
	dead.resize(N2)
	for id: String in TRACKS:
		lv[id] = 1
	_trng.seed = seed_v
	_draw_seqs()
	if not blank:
		for y in HUB:
			for x in HUB:
				kind[_i(HUB_AT + Vector2i(x, y))] = BOX
		_print_paper()
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
		while placed < int(r[1]) and tries < 8000:
			tries += 1
			var t := Vector2i(rng.randi_range(0, W - 1), rng.randi_range(0, H - 1))
			var d := ring(t)
			if d < int(r[2]) or d > int(r[3]) or not _clear_round(t):
				continue
			dep[_i(t)] = int(r[0])
			placed += 1

func _clear_round(t: Vector2i) -> bool:
	for dy in range(-APART, APART + 1):
		for dx in range(-APART, APART + 1):
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

## The squares piece `k` covers set down on `t` facing `f`, each as
## [square, role]: one for every piece but an operator and the dig.
static func footprint(k: int, t: Vector2i, f: int) -> Array:
	if not SHAPES.has(k):
		return [[t, R_NONE]]
	var across: Vector2i = DIRS[right_of(f)]
	var back: Vector2i = DIRS[opp(f)]
	var out := []
	for c: Array in SHAPES[k]:
		out.append([t + across * int(c[0]) + back * int(c[1]), int(c[2])])
	return out

## Where the root of `k` on `t` facing `f` goes when it is turned to face
## `nf`: the squares it covers keep their middle, so a square machine (the
## adder, the divider) turns in place on the squares it stood on.
static func turned_root(k: int, t: Vector2i, f: int, nf: int) -> Vector2i:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	var lo2 := lo
	var hi2 := hi
	for c: Array in footprint(k, t, f):
		lo = lo.min(c[0])
		hi = hi.max(c[0])
	for c: Array in footprint(k, t, nf):
		lo2 = lo2.min(c[0])
		hi2 = hi2.max(c[0])
	var d := (lo + hi) - (lo2 + hi2)
	return t + Vector2i(floori(d.x / 2.0), floori(d.y / 2.0))

## Why `k` cannot go on `t` facing `f`, or "" when it can. Every square it
## would cover must be on the paper and hold nothing but belt (`mine` the
## root of a machine whose own squares do not count, for a turn).
func why_not(k: int, t: Vector2i, f := 0, mine := -1) -> String:
	if not inside(t):
		return "edge"
	if not has(k):
		return "locked"
	for c: Array in footprint(k, t, f):
		var u: Vector2i = c[0]
		if not inside(u) or (blank and not frame.has_point(u)):
			return "edge"
		var i := _i(u)
		var here := int(kind[i])
		if here == BOX:
			return "box"
		if int(part[i]) >= 0:
			return "taken"
		if mine >= 0:
			# a turn takes no belt: only its own squares and empty ones
			if int(root[i]) != mine and here != EMPTY:
				return "taken"
			continue
		if here != EMPTY and here != BELT and here != BRIDGE:
			return "taken"
	if k == DIG:
		var i := _i(t)
		if dep[i] == 0:
			return "no_number"
		if not can_dig(dep[i]):
			return "not_yet"
	return ""

func place(k: int, t: Vector2i, f: int) -> bool:
	var why := why_not(k, t, f)
	if why != "":
		_emit("refused", {"why": why, "tile": t, "v": dep_at(t)})
		return false
	_stamp(k, t, f)
	_wire()
	_emit("place", {"kind": k, "tile": t})
	return true

## Piece `k` written on every square it covers, what stood there cleared.
func _stamp(k: int, t: Vector2i, f: int) -> void:
	var r := _i(t) if SHAPES.has(k) else -1
	for c: Array in footprint(k, t, f):
		var i := _i(c[0])
		_record(i)
		_clear(i)
		kind[i] = k
		face[i] = f
		root[i] = r
		role[i] = int(c[1])

## The squares of the piece standing on `t` (all of a machine's).
func piece_squares(t: Vector2i) -> Array:
	var i := _i(t)
	if int(part[i]) >= 0:
		return copy_squares(int(part[i]))
	var r := int(root[i])
	if r < 0:
		return [t]
	var out := []
	for c: Array in footprint(int(kind[r]), tile_of(r), int(face[r])):
		out.append(c[0])
	return out

## The root square of the piece on `t`: a machine's, or `t`.
func root_of(t: Vector2i) -> Vector2i:
	if inside(t) and int(part[_i(t)]) >= 0:
		return tile_of(int(part[_i(t)]))
	var r := int(root[_i(t)]) if inside(t) else -1
	return tile_of(r) if r >= 0 else t

## Whether a run of belt may go over `t`.
func can_lay(t: Vector2i) -> bool:
	if not inside(t) or (blank and not frame.has_point(t)) or int(part[_i(t)]) >= 0:
		return false
	var k := int(kind[_i(t)])
	return k == EMPTY or k == BELT or k == BRIDGE

## Lays belt over `tiles` (a straight run, in order) going `f`: a path whose
## every square faces `f`. Returns the squares laid or changed.
func lay_run(tiles: Array, f: int) -> int:
	return lay_path(tiles, f)

## A traced path's facings: each square faces the next, the last as the one
## before it; a path of one square faces `f_last`.
static func path_faces(tiles: Array, f_last: int) -> PackedByteArray:
	var faces := PackedByteArray()
	faces.resize(tiles.size())
	for j in tiles.size():
		var f := f_last
		if j + 1 < tiles.size():
			var d: Vector2i = (tiles[j + 1] as Vector2i) - (tiles[j] as Vector2i)
			var at := DIRS.find(d)
			if at >= 0:
				f = at
		elif j > 0:
			f = faces[j - 1]
		faces[j] = f
	return faces

## What a traced path would do: {tiles, faces, cut, merge}. It always runs
## the way the finger went. A path begun on a piece starts past its edge
## (its squares dropped: a dig is three wide, the box six); one begun on a
## belt across its way forks the line there (`fork`: the square keeps its
## way and hands to the path by turns; the user, 2026-10-18: "this should
## join convey"), but for a line's loose end, which turns to go on with
## the path (the corner); one begun along a line turns it its way. Its last square faces into the box, a machine or a crate beside it
## when nothing takes ahead of it; a square laid alone faces into the box
## beside it, or away from a dig. `cut` is where it
## stops: a square that cannot take belt, a belt it would cross that more
## than its back feeds (a crossing there would cut those off), or a belt
## across its last square, which it then runs into the side of (`merge`, a
## join). A belt crossed in the middle becomes a crossing (a bridge).
func trim_path(tiles: Array, f_last: int) -> Dictionary:
	var ts := tiles.duplicate()
	var fs := Array(path_faces(ts, f_last))
	var extend := false
	var forks := false
	var begun := NOWHERE
	if not ts.is_empty() and inside(ts[0]):
		var i0 := _i(ts[0])
		var k0 := int(kind[i0])
		var f0 := int(fs[0])
		if ts.size() > 1 and k0 == BELT and int(face[i0]) != f0 and int(face[i0]) != opp(f0) and _dangles(i0):
			# begun on a line's loose end: the path goes on from it, its end the corner
			extend = true
		elif ts.size() > 1 and k0 == BELT and int(face[i0]) % 2 != f0 % 2:
			# begun on a line across its way: the line forks there
			forks = true
		elif ts.size() > 1 and (not can_lay(ts[0]) or k0 == BRIDGE or (k0 == BELT and int(face[i0]) % 2 != f0 % 2)):
			begun = ts[0]
			var at := root_of(ts[0])
			while ts.size() > 1 and inside(ts[0]) and (ts[0] == begun or (not can_lay(ts[0]) and (root_of(ts[0]) == at or (k0 == BOX and kind_at(ts[0]) == BOX)))):
				ts.pop_front()
				fs.pop_front()
	# ended on a piece: the square before faces into it
	while ts.size() > 1 and not can_lay(ts[-1]):
		ts.pop_back()
		fs.pop_back()
	if forks and ts.size() < 2:
		# nothing past the line to fork to
		return {"tiles": ts, "faces": fs, "cut": 0, "extend": false, "fork": false, "merge": false}
	if ts.size() == 1 and inside(ts[0]):
		# a square set alone faces into the box beside it, or away from a dig
		var into := _taker_beside(ts[0], NOWHERE, begun)
		var away := _giver_beside(ts[0], NOWHERE)
		if away >= 0 and _takes(ts[0] + DIRS[opp(away)], opp(away)):
			# straight on from what gives into what takes
			fs[0] = opp(away)
		elif into >= 0:
			fs[0] = into
		elif away >= 0:
			fs[0] = opp(away)
	if ts.size() > 1 and not _takes(ts[-1] + DIRS[int(fs[-1])], int(fs[-1])):
		var into := _taker_beside(ts[-1], ts[-2], NOWHERE)
		if into >= 0:
			fs[-1] = into
	var cut := ts.size()
	var merge := false
	var last := ts.size() - 1
	for j in ts.size():
		var t: Vector2i = ts[j]
		if not can_lay(t):
			cut = j
			break
		var i := _i(t)
		var f := int(fs[j])
		if int(kind[i]) == BELT and int(face[i]) % 2 != f % 2 and not (j == 0 and (extend or forks)):
			if j > 0 and j < last and _fed_straight(i):
				continue
			# a line across the last square: the path runs into its side
			cut = j
			merge = j > 0 and j == last
			break
		if j > 0 and j == last and int(kind[i]) == BELT and int(face[i]) == opp(f) and kind_at(ts[j - 1]) != BELT:
			# head on into a line's front (not a line drawn back along itself)
			cut = j
			break
	return {"tiles": ts, "faces": fs, "cut": cut, "extend": extend, "fork": forks, "merge": merge}

## Whether a token going `d` into `t` would be taken there.
func _takes(t: Vector2i, d: int) -> bool:
	return _end_into(t, d) >= 0

## The way from `t` into the box, a machine's A or B square or a crate
## beside it (not `prev`), or -1; the piece the path was begun on
## (`begun`) first, which may be a belt.
func _taker_beside(t: Vector2i, prev: Vector2i, begun: Vector2i) -> int:
	var best := -1
	for d in 4:
		var u: Vector2i = t + DIRS[d]
		if u == prev or not inside(u) or not _takes(u, d):
			continue
		var k := int(kind[_i(u)])
		if begun != NOWHERE and (u == begun or root_of(u) == root_of(begun) or (k == BOX and kind_at(begun) == BOX)):
			return d
		if best < 0 and (k == BOX or k == CRATE or is_op(k) or int(part[_i(u)]) >= 0):
			best = d
	return best

## The way from `t` to a dig, a crate, a machine's answer square facing it
## or a belt handing into it beside it (not `prev`), or -1.
func _giver_beside(t: Vector2i, prev: Vector2i) -> int:
	for d in 4:
		var u: Vector2i = t + DIRS[d]
		if u == prev or not inside(u):
			continue
		var i := _i(u)
		if int(part[i]) >= 0:
			# a copy's out port facing `t`
			if int(gates.get((i << 2) | opp(d), -1)) == P_OUT:
				return d
			continue
		var k := int(kind[i])
		if k == DIG or k == CRATE:
			return d
		if is_op(k) and (int(role[i]) == R_OUT or int(role[i]) == R_REM):
			return d
		if k == BELT and int(face[i]) == opp(d):
			return d
		if k == BRIDGE and (int(face[i]) == opp(d) or int(face2[i]) == opp(d)):
			return d
	return -1

## Whether every belt handing into square `i` comes in at its back (or none
## does): a crossing there keeps what the belt took.
func _fed_straight(i: int) -> bool:
	var f := int(face[i])
	for s: int in feeders.get(i, PackedInt32Array()):
		for e: int in outs[s]:
			if (e >> 2) == i and (e & 3) != f:
				return false
	return true

## Whether the belt on square `i` is a line's loose end: it hands nothing on.
func _dangles(i: int) -> bool:
	return (outs.get(i, PackedInt32Array()) as PackedInt32Array).is_empty()

## Lays a traced path (4-connected squares in order; `f_last` the way the
## finger went last, for a path of one square) after `trim_path`. Belts
## along the way take the path's facing; a belt across it in the middle
## becomes a crossing. Returns the squares laid or changed.
func lay_path(tiles: Array, f_last: int) -> int:
	var p := trim_path(tiles, f_last)
	var ts: Array = p.tiles
	var fs: Array = p.faces
	var n := 0
	var laid := []
	for j in int(p.cut):
		var t: Vector2i = ts[j]
		var f := int(fs[j])
		var i := _i(t)
		var k := int(kind[i])
		var across := f % 2 == 0
		if j == 0 and bool(p.fork):
			if int(fork[i]) & (1 << f):
				continue
			_record(i)
			fork[i] = int(fork[i]) | (1 << f)
			to_d[i] = NONE
		elif k == EMPTY:
			_record(i)
			kind[i] = BELT
			face[i] = f
			_drop(i)
		elif k == BELT:
			if int(face[i]) == f:
				continue
			_record(i)
			if int(face[i]) % 2 == f % 2 or (j == 0 and bool(p.extend)):
				face[i] = f
				fork[i] = 0
				to_d[i] = NONE
			else:
				var other := int(face[i])
				kind[i] = BRIDGE
				face[i] = f if across else other
				face2[i] = other if across else f
				_drop(i)
		elif k == BRIDGE:
			if (int(face[i]) if across else int(face2[i])) == f:
				continue
			_record(i)
			if across:
				face[i] = f
			else:
				face2[i] = f
			_drop(i)
		laid.append(t)
		n += 1
	if n > 0:
		_wire()
		_emit("lay", {"n": n, "tiles": laid})
	return n

## The slots of the line through the belt on `t`, in the way it runs: back
## while a slot has one feeder and forward while the next is fed by it alone
## (through a crossing's lane, never past a join; `bare`: not into a
## crossing either).
func line_through(t: Vector2i, bare := false) -> Array:
	if kind_at(t) != BELT:
		return []
	var s0 := _i(t)
	var line := [s0]
	var seen := {s0: true}
	var room := int(part[s0])
	var s := s0
	while true:
		var fd: PackedInt32Array = feeders.get(s, PackedInt32Array())
		if fd.size() != 1 or seen.has(fd[0]):
			break
		var p := int(fd[0])
		var pk := int(kind[p % N])
		if pk != BELT and pk != BRIDGE or (feeders.get(p, PackedInt32Array()) as PackedInt32Array).size() > 1:
			break
		if bare and pk != BELT or int(part[p % N]) != room:
			break
		if (outs.get(p, PackedInt32Array()) as PackedInt32Array).size() != 1:
			# a fork: the line is the branch begun there, not the one it forks
			break
		s = p
		seen[s] = true
		line.push_front(s)
	s = s0
	while true:
		var o: PackedInt32Array = outs.get(s, PackedInt32Array())
		if o.size() != 1:
			break
		var nx := o[0] >> 2
		if nx >= N2 or seen.has(nx) or (feeders.get(nx, PackedInt32Array()) as PackedInt32Array).size() != 1:
			break
		if bare and int(kind[nx % N]) != BELT or int(part[nx % N]) != room:
			break
		s = nx
		seen[s] = true
		line.append(s)
	return line

## The way slot `s` runs: a belt's or a crossing's lane's.
func _slot_face(s: int) -> int:
	return int(face2[s - N]) if s >= N else int(face[s])

func _set_slot_face(s: int, f: int) -> void:
	if s >= N:
		face2[s - N] = f
	else:
		face[s] = f

## The line through the belt on `t` turned round: each square runs back to
## the one that fed it, the first the way it came, then faced into the box,
## a machine or a crate beside it if it ends there.
func flip_line(t: Vector2i) -> bool:
	var line := line_through(t)
	if line.is_empty():
		return false
	var fs := []
	for k in line.size():
		var s := int(line[k])
		if k == 0:
			fs.append(opp(_slot_face(s)))
		else:
			fs.append(DIRS.find(tile_of(int(line[k - 1]) % N) - tile_of(s % N)))
	var head: Vector2i = tile_of(int(line[0]) % N)
	if kind_at(head) == BELT:
		var prev: Vector2i = tile_of(int(line[1]) % N) if line.size() > 1 else NOWHERE
		var into := _taker_beside(head, prev, NOWHERE)
		if into >= 0 and not _takes(head + DIRS[int(fs[0])], int(fs[0])):
			fs[0] = into
	var tiles := []
	for k in line.size():
		var s := int(line[k])
		_record(s % N)
		_set_slot_face(s, int(fs[k]))
		_drop(s % N)
		tiles.append(tile_of(s % N))
	_wire()
	_emit("flip", {"tiles": tiles, "tile": t})
	return true

## The squares of the line through the belt on `t`, stopping at a join, a
## fork or a crossing (the user, 2026-10-19: "stop on joins or cross to
## avoid issue"); with `section`, only its straight run about `t`, to the
## turns either side (a corner square is the run it turns into).
func line_squares(t: Vector2i, section := false) -> Array:
	var line := line_through(t, true)
	if line.is_empty():
		return []
	var at := line.find(_i(t))
	var lo := 0
	var hi := line.size() - 1
	if section:
		var f := int(face[_i(t)])
		lo = at
		hi = at
		while lo > 0 and int(face[int(line[lo - 1])]) == f:
			lo -= 1
		while hi < line.size() - 1 and int(face[int(line[hi + 1])]) == f:
			hi += 1
	var out := []
	for j in range(lo, hi + 1):
		out.append(tile_of(int(line[j])))
	return out

## Lifts the belts on `tiles` in one go (the paper wired once).
func erase(tiles: Array) -> bool:
	var n := 0
	for t: Vector2i in tiles:
		var i := _i(t)
		if int(kind[i]) != BELT:
			continue
		_record(i)
		_clear(i)
		kind[i] = EMPTY
		fork[i] = 0
		root[i] = -1
		role[i] = R_NONE
		n += 1
	if n == 0:
		return false
	_wire()
	_emit("erase", {"n": n, "tiles": tiles, "tile": tiles[0]})
	return true

## Turns what stands on `t` a quarter clockwise: a machine about its root,
## when every square it would cover then is free.
func turn(t: Vector2i) -> bool:
	if not inside(t):
		return false
	var i := _i(t)
	if int(part[i]) >= 0:
		return _turn_copy(int(part[i]))
	var k := int(kind[i])
	if k == EMPTY or k == BOX or k == DIG or k == CRATE or k == BRIDGE:
		return false
	if is_op(k):
		var r := int(root[i])
		var f := (int(face[r]) + 1) % 4
		var at := turned_root(k, tile_of(r), int(face[r]), f)
		var why := why_not(k, at, f, r)
		if why != "":
			_emit("refused", {"why": "no_room", "tile": at, "v": 0})
			return false
		for u: Vector2i in piece_squares(at):
			var j := _i(u)
			_record(j)
			_clear(j)
			kind[j] = EMPTY
			root[j] = -1
			role[j] = R_NONE
		_stamp(k, at, f)
		_wire()
		_emit("turn", {"kind": k, "tile": at, "face": f})
		return true
	_record(i)
	face[i] = (int(face[i]) + 1) % 4
	fork[i] = 0
	to_d[i] = NONE
	_wire()
	_emit("turn", {"kind": k, "tile": t, "face": int(face[i])})
	return true

## Lifts what stands on `t`: all of a machine from any of its squares.
func remove(t: Vector2i) -> bool:
	if not inside(t):
		return false
	var i := _i(t)
	if int(part[i]) >= 0:
		var a := int(part[i])
		var rot := int(copies[a][1])
		_keep_copies()
		_unstamp_copy(a)
		_wire()
		_emit("lift", {"kind": PART, "tile": tile_of(a), "face": rot})
		return true
	var k := int(kind[i])
	if k == EMPTY or k == BOX:
		return false
	var at := root_of(t)
	var f := int(face[_i(at)])
	for u: Vector2i in piece_squares(t):
		var j := _i(u)
		_record(j)
		_clear(j)
		kind[j] = EMPTY
		root[j] = -1
		role[j] = R_NONE
	_wire()
	_emit("lift", {"kind": k, "tile": at, "face": f})
	return true

# --- parts ---

## Whether parts can be built: from the adder on.
func parts_open() -> bool:
	return has(ADD)

## A part's grid turned `rot` quarters clockwise, as squares across and down.
static func turned_size(w: int, h: int, rot: int) -> Vector2i:
	return Vector2i(w, h) if rot % 2 == 0 else Vector2i(h, w)

## Square (x, y) of a `w` by `h` grid, the grid turned `rot` quarters
## clockwise: where it lands from the turned grid's corner.
static func turned_at(x: int, y: int, w: int, h: int, rot: int) -> Vector2i:
	match rot % 4:
		1:
			return Vector2i(h - 1 - y, x)
		2:
			return Vector2i(w - 1 - x, h - 1 - y)
		3:
			return Vector2i(y, w - 1 - x)
	return Vector2i(x, y)

## A fork's bits turned with the square.
static func turned_bits(bits: int, rot: int) -> int:
	rot %= 4
	return ((bits << rot) | (bits >> (4 - rot))) & 15

## The size of part `id` turned `rot`.
func part_size(id: int, rot: int) -> Vector2i:
	var d: Dictionary = defs[id]
	return turned_size(int(d.w), int(d.h), rot)

## Its ports turned `rot`, as [x, y, way, io] from the turned grid's corner.
func part_ports(id: int, rot: int) -> Array:
	var d: Dictionary = defs[id]
	var out := []
	for q: Array in d.ports:
		var at := turned_at(int(q[0]), int(q[1]), int(d.w), int(d.h), rot)
		out.append([at.x, at.y, (int(q[2]) + rot) % 4, int(q[3])])
	return out

## A part's ports named as they read left to right, then top to bottom, by
## where each meets the paper outside the grid: the ins A, B, C..., the
## outs = (or =1, =2... when there are more).
static func port_names(ports: Array, _w: int, _h: int) -> Array:
	var order := []
	for j in ports.size():
		var q: Array = ports[j]
		var at: Vector2i = Vector2i(int(q[0]), int(q[1])) + DIRS[int(q[2])]
		order.append([at.x, at.y, j])
	order.sort()
	var names := []
	names.resize(ports.size())
	var outs := 0
	for q: Array in ports:
		if int(q[3]) == P_OUT:
			outs += 1
	var ni := 0
	var no := 0
	for o: Array in order:
		var j := int(o[2])
		if int(ports[j][3]) == P_IN:
			names[j] = String.chr(65 + ni % 26)
			ni += 1
		else:
			no += 1
			names[j] = "=" if outs == 1 else "=%d" % no
	return names

## Where the copy anchored on `t` goes when turned to `nr`: the squares it
## covers keep their middle.
func part_turned_anchor(id: int, t: Vector2i, rot: int, nr: int) -> Vector2i:
	var a := part_size(id, rot)
	var b := part_size(id, nr)
	var d := (a - b)
	return t + Vector2i(floori(d.x / 2.0), floori(d.y / 2.0))

## Why a copy of `id` cannot go on `t` turned `rot` (`mine` the anchor of a
## copy whose own squares do not count, for a turn), or "".
func part_why_not(id: int, t: Vector2i, rot: int, mine := -1) -> String:
	if not defs.has(id):
		return "taken"
	if not parts_open():
		return "locked"
	var sz := part_size(id, rot)
	for y in sz.y:
		for x in sz.x:
			var u := t + Vector2i(x, y)
			if not inside(u):
				return "edge"
			var i := _i(u)
			var here := int(kind[i])
			if here == BOX:
				return "box"
			if mine >= 0 and int(part[i]) == mine:
				continue
			if int(part[i]) >= 0 or (here != EMPTY and here != BELT and here != BRIDGE):
				return "taken"
	return ""

## A copy of part `id` set down on `t` turned `rot`.
func place_part(id: int, t: Vector2i, rot: int) -> bool:
	var why := part_why_not(id, t, rot)
	if why != "":
		_emit("refused", {"why": why, "tile": t, "v": 0})
		return false
	_keep_copies()
	_stamp_copy(_i(t), id, rot)
	_wire()
	_emit("place", {"kind": PART, "tile": t})
	return true

## The squares of the copy anchored on `a`.
func copy_squares(a: int) -> Array:
	var out := []
	if not copies.has(a):
		return [tile_of(a)]
	var c: Array = copies[a]
	var sz := part_size(int(c[0]), int(c[1]))
	for y in sz.y:
		for x in sz.x:
			out.append(tile_of(a) + Vector2i(x, y))
	return out

## Part `id`'s inside written onto the squares from `a`, turned `rot`, each
## tagged with `a`; what stood there cleared.
func _stamp_copy(a: int, id: int, rot: int) -> void:
	var d: Dictionary = defs[id]
	var w := int(d.w)
	var h := int(d.h)
	var t0 := tile_of(a)
	var sz := turned_size(w, h, rot)
	for y in sz.y:
		for x in sz.x:
			var i := _i(t0 + Vector2i(x, y))
			_record(i)
			_clear(i)
			kind[i] = EMPTY
			root[i] = -1
			role[i] = R_NONE
			fork[i] = 0
			part[i] = a
	for pc: Array in d.pieces:
		var at := t0 + turned_at(int(pc[0]), int(pc[1]), w, h, rot)
		var k := int(pc[2])
		var f := (int(pc[3]) + rot) % 4
		if is_op(k):
			_stamp(k, at, f)
		elif k == BELT or k == BRIDGE:
			var i := _i(at)
			kind[i] = k
			face[i] = f
			face2[i] = (int(pc[4]) + rot) % 4
			fork[i] = turned_bits(int(pc[5]), rot) if k == BELT else 0
	copies[a] = [id, rot]

## The copy anchored on `a` lifted off its squares.
func _unstamp_copy(a: int) -> void:
	for t: Vector2i in copy_squares(a):
		var i := _i(t)
		if int(part[i]) != a:
			continue
		_record(i)
		_clear(i)
		kind[i] = EMPTY
		root[i] = -1
		role[i] = R_NONE
		fork[i] = 0
		part[i] = -1
	copies.erase(a)

func _turn_copy(a: int) -> bool:
	var c: Array = copies[a]
	var id := int(c[0])
	var rot := int(c[1])
	var nr := (rot + 1) % 4
	var at := part_turned_anchor(id, tile_of(a), rot, nr)
	if part_why_not(id, at, nr, a) != "":
		_emit("refused", {"why": "no_room", "tile": at, "v": 0})
		return false
	_keep_copies()
	_unstamp_copy(a)
	_stamp_copy(_i(at), id, nr)
	_wire()
	_emit("turn", {"kind": PART, "tile": at, "face": nr})
	return true

## Every copy's ports as gates on their squares.
func _gate_copies() -> void:
	gates = {}
	for a: int in copies:
		var c: Array = copies[a]
		if not defs.has(int(c[0])):
			continue
		var t0 := tile_of(a)
		for q: Array in part_ports(int(c[0]), int(c[1])):
			gates[(_i(t0 + Vector2i(int(q[0]), int(q[1]))) << 2) | int(q[2])] = int(q[3])

## A new, empty part `w` by `h`; its id.
func new_part(w: int, h: int) -> int:
	var id := next_def
	next_def += 1
	defs[id] = {"name": "%d" % id, "w": clampi(w, PART_LEAST, PART_MOST), "h": clampi(h, PART_LEAST, PART_MOST), "pieces": [], "ports": []}
	return id

## Part `id`'s inside and ports as built on a bench (and its grid's size
## when `sz` is given), written again into every copy of it from the same
## corner (tokens riding in them fall off; nothing to undo). A copy the new
## size has no room for is lifted. Returns how many were.
func set_part(id: int, pieces: Array, ports: Array, sz := Vector2i.ZERO) -> int:
	if not defs.has(id):
		return 0
	defs[id].pieces = pieces
	defs[id].ports = ports
	if sz != Vector2i.ZERO:
		defs[id].w = clampi(sz.x, PART_LEAST, PART_MOST)
		defs[id].h = clampi(sz.y, PART_LEAST, PART_MOST)
	var mine := []
	for a: int in copies.keys():
		if int(copies[a][0]) == id:
			mine.append([a, int(copies[a][1])])
			_unstamp_copy(a)
	var lifted := 0
	for c: Array in mine:
		if part_why_not(id, tile_of(int(c[0])), int(c[1])) == "":
			_stamp_copy(int(c[0]), id, int(c[1]))
		else:
			lifted += 1
	mark()
	_wire()
	_emit("part", {"id": id})
	return lifted

## Part `d`'s name as the player reads it: one they gave it, or "Part n".
static func part_title(d: Dictionary) -> String:
	var nm := String(d.get("name", ""))
	if nm.is_valid_int():
		return TranslationServer.translate("TL_PART_NAME") % nm
	return nm

## Part `id` thrown away with every copy of it.
func drop_part(id: int) -> void:
	for a: int in copies.keys():
		if int(copies[a][0]) == id:
			_unstamp_copy(a)
	defs.erase(id)
	mark()
	_wire()
	_emit("part", {"id": id})

## How many copies of part `id` are set down.
func copies_of(id: int) -> int:
	var n := 0
	for a: int in copies:
		if int(copies[a][0]) == id:
			n += 1
	return n

# --- the bench ---

## A bench for part `d`'s inside: a blank sheet, its grid in the middle, the
## pieces written in; `lvl` says which operators may go in.
static func bench_for(d: Dictionary, lvl: int) -> RefCounted:
	var s = new(1, true)
	s.level = lvl
	var w := int(d.w)
	var h := int(d.h)
	@warning_ignore("integer_division")
	s.frame = Rect2i(Vector2i((W - w) / 2, (H - h) / 2), Vector2i(w, h))
	var t0: Vector2i = s.frame.position
	for pc: Array in d.pieces:
		var at := t0 + Vector2i(int(pc[0]), int(pc[1]))
		var k := int(pc[2])
		if is_op(k):
			if s.why_not(k, at, int(pc[3])) == "":
				s._stamp(k, at, int(pc[3]))
		elif (k == BELT or k == BRIDGE) and s.can_lay(at):
			var i := _i(at)
			s.kind[i] = k
			s.face[i] = int(pc[3])
			s.face2[i] = int(pc[4])
			s.fork[i] = int(pc[5]) if k == BELT else 0
	for q: Array in d.ports:
		s.bench_ports[Vector3i(int(q[0]), int(q[1]), int(q[2]))] = int(q[3])
	s._wire()
	s._undo = {}
	return s

## The bench's grid made `w` by `h` from the same corner: a piece left
## outside it is lifted, a port on the right or bottom edge goes with that
## edge, and one with no edge left under it goes.
func bench_resize(w: int, h: int) -> void:
	var nf := Rect2i(frame.position, Vector2i(clampi(w, PART_LEAST, PART_MOST), clampi(h, PART_LEAST, PART_MOST)))
	var all := frame.merge(nf)
	for y in range(all.position.y, all.end.y):
		for x in range(all.position.x, all.end.x):
			var t := Vector2i(x, y)
			if kind_at(t) == EMPTY:
				continue
			for u: Vector2i in piece_squares(t):
				if not nf.has_point(u):
					remove(t)
					break
	var kept := {}
	for key: Vector3i in bench_ports:
		var at := Vector2i(key.x, key.y)
		match key.z:
			0:
				at.x = nf.size.x - 1
			1:
				at.y = nf.size.y - 1
		if at.x < nf.size.x and at.y < nf.size.y:
			kept[Vector3i(at.x, at.y, key.z)] = bench_ports[key]
	bench_ports = kept
	frame = nf
	mark()
	_wire()
	_emit("port", {"tile": frame.position, "way": 0, "io": -1})

## The bench's grid read back: [pieces, ports] as `defs` keeps them.
func bench_read() -> Array:
	var pieces := []
	for y in frame.size.y:
		for x in frame.size.x:
			var i := _i(frame.position + Vector2i(x, y))
			var k := int(kind[i])
			if k == BELT:
				pieces.append([x, y, k, int(face[i]), 0, int(fork[i])])
			elif k == BRIDGE:
				pieces.append([x, y, k, int(face[i]), int(face2[i]), 0])
			elif is_op(k) and int(root[i]) == i:
				pieces.append([x, y, k, int(face[i]), 0, 0])
	var ports := []
	for key: Vector3i in bench_ports:
		ports.append([key.x, key.y, key.z, int(bench_ports[key])])
	return [pieces, ports]

## The port nearest `q` (squares, fractional) on the bench grid's edge
## turned on to in, then out, then off. Returns whether it changed.
func toggle_port_at(q: Vector2) -> bool:
	if not blank:
		return false
	var f := Rect2(frame)
	var c := Vector2(clampf(q.x, f.position.x + 0.01, f.end.x - 0.01), clampf(q.y, f.position.y + 0.01, f.end.y - 0.01))
	var u := Vector2i(c.floor())
	var best := -1
	var near := INF
	# the grid's sides the square stands on, the nearest to the touch
	var sides := [[0, u.x == frame.end.x - 1, absf(q.x - f.end.x)], [1, u.y == frame.end.y - 1, absf(q.y - f.end.y)],
		[2, u.x == frame.position.x, absf(q.x - f.position.x)], [3, u.y == frame.position.y, absf(q.y - f.position.y)]]
	for sd: Array in sides:
		if bool(sd[1]) and float(sd[2]) < near:
			near = float(sd[2])
			best = int(sd[0])
	if best < 0 or near > 1.5:
		return false
	var key := Vector3i(u.x - frame.position.x, u.y - frame.position.y, best)
	var was := int(bench_ports.get(key, -1))
	if was == P_IN:
		bench_ports[key] = P_OUT
	elif was == P_OUT:
		bench_ports.erase(key)
	else:
		bench_ports[key] = P_IN
	_emit("port", {"tile": u, "way": best, "io": int(bench_ports.get(key, -1))})
	return true

# --- one step back ---

## The holder calls `mark()` as a gesture begins; every square the gesture
## changes is written down once, and `undo()` puts them all back as they
## were (tokens riding there fall off, a crate's contents are not kept).
func mark() -> void:
	_undo = {}
	_undo_copies = null

func _record(i: int) -> void:
	if not _undo.has(i):
		_undo[i] = [int(kind[i]), int(face[i]), int(face2[i]), int(root[i]), int(role[i]), int(fork[i]), int(part[i])]

## The copies written down once a gesture, before it changes them.
func _keep_copies() -> void:
	if _undo_copies == null:
		_undo_copies = copies.duplicate(true)

func can_undo() -> bool:
	return not _undo.is_empty()

func undo() -> bool:
	if _undo.is_empty():
		return false
	var n := 0
	for i: int in _undo:
		var was: Array = _undo[i]
		_clear(i)
		kind[i] = int(was[0])
		face[i] = int(was[1])
		face2[i] = int(was[2])
		root[i] = int(was[3])
		role[i] = int(was[4])
		fork[i] = int(was[5])
		part[i] = int(was[6])
		n += 1
	_undo = {}
	if _undo_copies != null:
		copies = _undo_copies
		_undo_copies = null
	_wire()
	_emit("undo", {"n": n})
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
	var from: Vector2i = t2 - DIRS[d]
	var fi := _i(from) if inside(from) else -1
	var pf := int(part[fi]) if fi >= 0 else -1
	if pf != int(part[i]):
		# a copy's edge is crossed at its ports alone, the way each goes
		if int(part[i]) >= 0 and int(gates.get((i << 2) | opp(d), -1)) != P_IN:
			return -1
		if pf >= 0 and int(gates.get((fi << 2) | d, -1)) != P_OUT:
			return -1
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
			# A and B take from any edge (the user, 2026-10-19: "the multiplier
			# can accept in at any face of the A and B"), never from their own
			# machine's squares
			var r := int(root[i])
			if fi >= 0 and int(root[fi]) == r:
				return -1
			if int(role[i]) == R_A:
				return ((N2 + r * 4) << 2) | d
			if int(role[i]) == R_B:
				return ((N2 + r * 4 + 1) << 2) | d
			return -1
		CRATE:
			return ((N2 + i * 4 + 2) << 2) | d
		BOX:
			return ((N2 + i * 4 + 3) << 2) | d
	return -1

## The belts leading away from the piece on `t` (a dig's, a crate's): a
## belt beside any of its squares facing away, or running along its edge
## with nothing behind it (a line's first belt, drawn from beside it).
func _away_from(t: Vector2i) -> PackedInt32Array:
	var o := PackedInt32Array()
	var mine := piece_squares(t)
	for q: Vector2i in mine:
		for d in 4:
			var u: Vector2i = q + DIRS[d]
			if not inside(u) or mine.has(u):
				continue
			var i := _i(u)
			if int(kind[i]) != BELT:
				continue
			if int(part[i]) >= 0 and int(gates.get((i << 2) | opp(d), -1)) != P_IN:
				continue
			var f := int(face[i])
			if f == d or (f != opp(d) and kind_at(u - DIRS[f]) == EMPTY):
				o.append((i << 2) | d)
	return o

## The ends a machine's squares of `want` hand out to, from any free edge
## (the user, 2026-10-19: "out in any free face on result center"): into a
## machine's A or B beside it, a crate, the box, or a belt leading away as a
## dig's do (facing away, or a line's first belt along the edge), so a line
## only passing by is not fed.
func _mouths(r: int, want: int) -> PackedInt32Array:
	var o := PackedInt32Array()
	for c: Array in footprint(int(kind[r]), tile_of(r), int(face[r])):
		if int(c[1]) != want:
			continue
		var q: Vector2i = c[0]
		for d in 4:
			var u: Vector2i = q + DIRS[d]
			if not inside(u) or int(root[_i(u)]) == r:
				continue
			var k := int(kind[_i(u)])
			if k == BELT:
				var f := int(face[_i(u)])
				if not (f == d or (f != opp(d) and kind_at(u - DIRS[f]) == EMPTY)):
					continue
			elif k == BRIDGE:
				continue
			var e := _end_into(u, d)
			if e >= 0:
				o.append(e)
	return o

func _feed(id: int, s: int) -> void:
	if not feeders.has(id):
		feeders[id] = PackedInt32Array()
	feeders[id].append(s)

## Works out every slot's ends again after the paper changed.
func _wire() -> void:
	_gate_copies()
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
			for d in 4:
				if int(fork[i]) & (1 << d) and d != f:
					var e2 := _end_into(t + DIRS[d], d)
					if e2 >= 0:
						o.append(e2)
			lanes.append(i)
			outs[i] = o
		elif k == BRIDGE:
			fork[i] = 0
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
			fork[i] = 0
			if k == DIG and (int(root[i]) < 0 or int(root[i]) == i):
				if not digs.has(i):
					digs[i] = {"budget": 0.0, "rr": 0}
				digs[i].outs = _away_from(t)
			elif k == CRATE:
				if not crates.has(i):
					crates[i] = {"v": 0, "n": 0, "rr": 0}
				crates[i].outs = _away_from(t)
			elif is_op(k) and int(root[i]) == i:
				if not machines.has(i):
					machines[i] = {"a": [], "b": [], "out": [], "rem": [], "busy": false, "t": 0.0, "x": 0, "y": 0, "last": 0, "has_last": false, "a_since": -1.0, "b_since": -1.0, "rr": 0, "rr_rem": 0}
				machines[i].fronts = _mouths(i, R_OUT)
				machines[i].rems = _mouths(i, R_REM)
		if k != BRIDGE:
			occ[i + N] = 0
	dead.fill(0)
	for s: int in lanes:
		if (outs[s] as PackedInt32Array).is_empty():
			dead[s] = 1
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
	_flow_roll()
	var bk: Dictionary = _flow[_flow_sec % FLOW_FOR]
	bk[v] = int(bk.get(v, 0)) + 1
	if v == target():
		got += 1
		_emit("hit", {"v": v})
		if got >= count():
			_level_up()
	else:
		off += 1
		off_v = v
		if off >= OFF_SAY and got == 0 and not _off_said:
			_off_said = true
			_emit("off_target", {"v": target(), "came": v})

func _level_up() -> void:
	var done := level
	level += 1
	got = 0
	off = 0
	_off_said = false
	var r := reward_of(done)
	_emit("level", {"n": level, "reward": r})
	if r != 0:
		_emit("unlock", {"reward": r})

func step(dt: float) -> void:
	# the flow counts from the paper's first tick, quiet seconds too
	_flow_roll()
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
		if dead[s] == 1:
			# a line's loose end: the token waits at its middle
			prog[s] = minf(p, 0.5)
			continue
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
		m.rr = _push(m.out, m.fronts, int(m.rr))
		m.rr_rem = _push(m.rem, m.rems, int(m.rr_rem))
		# a side empty while the other waits: since when
		var a_empty := (m.a as Array).is_empty() and not (m.b as Array).is_empty() and not bool(m.busy)
		var b_empty := (m.b as Array).is_empty() and not (m.a as Array).is_empty() and not bool(m.busy)
		m.a_since = (float(m.a_since) if float(m.a_since) >= 0.0 else clock) if a_empty else -1.0
		m.b_since = (float(m.b_since) if float(m.b_since) >= 0.0 else clock) if b_empty else -1.0

## The side the machine on square `i` has waited on for STARVE_AFTER: 0 for
## A, 1 for B, or -1.
func starving(i: int) -> int:
	if not machines.has(i):
		return -1
	var m: Dictionary = machines[i]
	if float(m.a_since) >= 0.0 and clock - float(m.a_since) >= STARVE_AFTER:
		return 0
	if float(m.b_since) >= 0.0 and clock - float(m.b_since) >= STARVE_AFTER:
		return 1
	return -1

## What waits in `q` handed out over `ends` in turn from `rr`, a slot one
## at a time; returns where the turn goes on from.
func _push(q: Array, ends: PackedInt32Array, rr: int) -> int:
	var n := ends.size()
	if n == 0:
		return 0
	var tried := 0
	while not q.is_empty() and tried < n:
		var e := ends[rr % n]
		rr = (rr + 1) % n
		if _accepts(e, int(q[0])):
			_put(e, int(q.pop_front()), 0.0)
			tried = 0 if (e >> 2) >= N2 else tried + 1
		else:
			tried += 1
	return rr

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
## The flow's buckets brought up to this second: the seconds gone by since
## the last are emptied.
func _flow_roll() -> void:
	var sec := int(floorf(clock))
	if _flow.is_empty():
		_flow.resize(FLOW_FOR)
		for j in FLOW_FOR:
			_flow[j] = {}
		_flow_sec = sec
		_flow_t0 = clock
		return
	if sec - _flow_sec >= FLOW_FOR:
		for j in FLOW_FOR:
			_flow[j] = {}
		_flow_sec = sec
		return
	while _flow_sec < sec:
		_flow_sec += 1
		_flow[_flow_sec % FLOW_FOR] = {}

## The numbers coming into the box a second, over the last FLOW_FOR seconds
## (or since counting began, when that is less): [[value, per second], ...],
## the quickest first.
func flow() -> Array:
	_flow_roll()
	var sum := {}
	for bk: Dictionary in _flow:
		for v: int in bk:
			sum[v] = int(sum.get(v, 0)) + int(bk[v])
	var span := clampf(minf(clock - _flow_t0, FLOW_FOR - 1.0 + fposmod(clock, 1.0)), 1.0, float(FLOW_FOR))
	var rows := []
	for v: int in sum:
		rows.append([v, float(sum[v]) / span])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]) or (float(a[1]) == float(b[1]) and int(a[0]) < int(b[0])))
	return rows

func tally_rows(most := 12) -> Array:
	var rows := []
	for v: int in ledger:
		if held(v) > 0:
			rows.append([v, held(v)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	return rows.slice(0, most)

# --- kept ---

func save() -> void:
	if path == "" or blank:
		return
	var cfg := ConfigFile.new()
	var pieces := PackedInt32Array()
	for i in N:
		var k := int(kind[i])
		if k != EMPTY and k != BOX and int(part[i]) < 0 and (int(root[i]) < 0 or int(root[i]) == i):
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
	var forks := PackedInt32Array()
	for i in N:
		if int(kind[i]) == BELT and int(fork[i]) != 0 and int(part[i]) < 0:
			forks.append_array([i, int(fork[i])])
	cfg.set_value("paper", "forks", forks)
	cfg.set_value("paper", "keys", keys)
	cfg.set_value("paper", "counts", counts)
	cfg.set_value("paper", "crates", crate_rows)
	cfg.set_value("hand", "straight", straight)
	var placed := PackedInt32Array()
	for a: int in copies:
		placed.append_array([a, int(copies[a][0]), int(copies[a][1])])
	cfg.set_value("parts", "defs", defs)
	cfg.set_value("parts", "next", next_def)
	cfg.set_value("parts", "copies", placed)
	cfg.save(path)

static func load_saved(rng_seed := 0) -> RefCounted:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(path) != OK:
		return new(rng_seed)
	var s = new(int(cfg.get_value("paper", "seed", rng_seed)))
	s.level = maxi(1, int(cfg.get_value("paper", "level", 1)))
	s.got = maxi(0, int(cfg.get_value("paper", "got", 0)))
	s.made = maxi(0, int(cfg.get_value("paper", "made", 0)))
	s.straight = bool(cfg.get_value("hand", "straight", true))
	var levels: Dictionary = cfg.get_value("paper", "lv", {})
	for id: String in TRACKS:
		s.lv[id] = clampi(int(levels.get(id, 1)), 1, int(TRACK_TOP[id]))
	# a sheet kept before VER was laid on other paper: its pieces and
	# crates are not read
	var fresh := int(cfg.get_value("paper", "ver", 1)) >= VER
	var pieces: PackedInt32Array = cfg.get_value("paper", "pieces", PackedInt32Array()) if fresh else PackedInt32Array()
	for j in range(0, pieces.size() - 3, 4):
		var i := pieces[j]
		var k := pieces[j + 1]
		if i < 0 or i >= N or k <= EMPTY or k == BOX or k > JOIN:
			continue
		if k == SPLIT or k == JOIN:
			# a splitter's or a combiner's square, kept from before: a belt
			k = BELT
		var f := clampi(pieces[j + 2], 0, 3)
		var why: String = s.why_not(k, tile_of(i), f)
		if why != "" and not (k == DIG and why == "not_yet"):
			continue
		s._stamp(k, tile_of(i), f)
		s.face2[i] = clampi(pieces[j + 3], 0, 3)
	var forks: PackedInt32Array = cfg.get_value("paper", "forks", PackedInt32Array()) if fresh else PackedInt32Array()
	for j in range(0, forks.size() - 1, 2):
		var i := forks[j]
		if i >= 0 and i < N and int(s.kind[i]) == BELT:
			s.fork[i] = forks[j + 1] & 15
	var kept_defs: Dictionary = cfg.get_value("parts", "defs", {})
	for id in kept_defs:
		var d: Dictionary = kept_defs[id]
		if d.has("w") and d.has("h") and d.has("pieces") and d.has("ports"):
			s.defs[int(id)] = d
	s.next_def = maxi(int(cfg.get_value("parts", "next", 1)), 1)
	for id: int in s.defs:
		s.next_def = maxi(s.next_def, id + 1)
	var placed: PackedInt32Array = cfg.get_value("parts", "copies", PackedInt32Array()) if fresh else PackedInt32Array()
	for j in range(0, placed.size() - 2, 3):
		var a := placed[j]
		var id := placed[j + 1]
		var rot := placed[j + 2] & 3
		if a >= 0 and a < N and s.part_why_not(id, tile_of(a), rot) == "":
			s._stamp_copy(a, id, rot)
	var keys: PackedInt64Array = cfg.get_value("paper", "keys", PackedInt64Array())
	var counts: PackedInt64Array = cfg.get_value("paper", "counts", PackedInt64Array())
	for j in mini(keys.size(), counts.size()):
		s.ledger[int(keys[j])] = int(counts[j])
	s._wire()
	s._undo = {}
	var crate_rows: PackedInt64Array = cfg.get_value("paper", "crates", PackedInt64Array()) if fresh else PackedInt64Array()
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
