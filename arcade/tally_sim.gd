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
##   reference's footprints) on a layer of their own over the paper (`op`,
##   the user, 2026-10-19: "Modules are literally just a visual
##   representation of the operation, it should not really exist on the
##   game grid ... convey should not even see it or interact with it in any
##   way"). The belts under a machine run as anywhere else; the machine
##   only takes the token waiting at the middle of the belt under its A
##   square and its B square (a token on one waits there, `intake`), and
##   sets what it makes down at the middle of the belt under an answer
##   square (the divider's remainder square too) when it is free, to ride
##   on the belt's way; 2 made wait to go out. A square with no belt under
##   it does nothing. Every square of one carries its kind and facing; `root`
##   names the square the machine is kept under (its first answer square)
##   and `role` what each square is;
## - a **crate** keeps up to CRATE_MAX of the first number it gets and lets
##   them out on every belt leading away;
## - the **box** takes everything from every side;
## - a **part** is a template the player saved from pieces picked on the
##   paper (the user, 2026-10-19: "submodule will be just a building
##   template saved that user can use to spawn ... no more share state"):
##   `w` by `h` squares of belts, crossings, operators and crates. Set down
##   (turned `rot` quarter turns) it is written onto the paper as plain
##   pieces (`stamp_template`), nothing tying them to the part afterwards;
##   a part is only placed or thrown away, never edited.
##
## A slot is where a token rides: `s` < N is a square's own (a belt, a
## bridge's across lane), `s` >= N a bridge's up-and-down lane. A slot's
## token is `val[s]`, `prog[s]` from 0 (the edge it came in by, `from_d`)
## to 1 (the edge it leaves by, the way of `outs[s][to_d[s]]`).
##
## An end (`_end_into`) is where a token can be handed: `(id << 2) | dir`,
## `id` a slot, or N2 + square * 4 + q for a crate (2) or the box (3)
## (0 and 1 were a machine's sides once); `dir` is the way the token is going.
##
## Actions return whether they did anything; `events` is for the holder to
## drain. `step(dt)` takes any `dt`.

## 2: the operators' footprints and the bigger paper; 3: the six-square
## box, the three-square dig and the numbers spread over a bigger sheet;
## 4: the 400 by 400 sheet, the box in its middle, the numbers printed by
## rings, small near the box and bigger towards the edge; 5: the 1000 by
## 1000 sheet with every number to 999 and the reference's counts. A sheet
## kept under VER keeps its level, tally and upgrades, and its pieces are
## not read.
const VER := 5
const W := 1000
const H := 1000
const N := W * H
const N2 := N * 2
## The sheet in chunks of CH by CH squares (`cells`): the board draws and
## culls by them, so nothing walks every square of the sheet.
const CH := 20
const CW := W / CH
const CHUNKS := CW * (H / CH)
const HUB := 6
const HUB_AT := Vector2i(497, 497)

## PRIO is no piece: it is the level 10 reward, priorities at junctions.
enum { EMPTY, BELT, BRIDGE, DIG, ADD, MUL, SUB, DIV, POW, CRATE, BOX, SPLIT, JOIN, PART, PRIO }
const OPS := [ADD, MUL, SUB, DIV, POW]
const KIND_IDS := {BELT: "belt", BRIDGE: "bridge", DIG: "dig", ADD: "add", MUL: "mul", SUB: "sub", DIV: "div", POW: "pow", CRATE: "crate", BOX: "box", PRIO: "prio"}
## The level whose end hands a piece over (it is had from the level after).
## SPLIT and JOIN were pieces once (a save's own may still hold them: read
## as belts). Crossings come at level 4's end and priorities at level 10's,
## as the reference hands them over.
const UNLOCK := {BELT: 0, DIG: 0, ADD: 1, BRIDGE: 4, MUL: 7, PRIO: 10, SUB: 13, DIV: 16, POW: 19, CRATE: 22}

## The kinds a picked piece may be copied or saved as a part with. A dig
## goes too (the user, 2026-10-19: "duplicate schema should also include
## extractor"): set down, it must stand on a printed number it can dig.
const TEMPLATE_KINDS := [BELT, BRIDGE, DIG, ADD, MUL, SUB, DIV, POW, CRATE]

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

## A machine's room for what waits to go out.
const OUT := 2
const CRATE_MAX := 10000
## The longest step taken in one go: a token at 20 squares a second moves
## two thirds of a square in it.
const STEP := 1.0 / 30.0
## A machine idle with one side fed and the other empty this long is
## starving on the empty side (`starving`).
const STARVE_AFTER := 3.0
## Non-target numbers into the box, with none of the target, before the
## box says they do not count.
const OFF_SAY := 20
## A dig's and a machine's `eff`, 0 to 1: how much of the last EFF_T
## seconds it spent producing (a dig: its budget spent, not held up by a
## full belt or no belt; a machine: busy), an exponential average the
## board's gauges show. Not saved. A crate is producing while it holds
## numbers and its last hand-out is fresh: within CRATE_FRESH of the
## interval its belts take one at (a crate hands out as its belts accept,
## so a put is a spike and a rate would jitter).
const EFF_T := 3.0
const CRATE_FRESH := 1.5
const LIMIT := 2147483647
const FLOOR := -2147483648

# --- the ladder ---

## Each level: the sample target, the count, the reward (a piece's kind, a
## number now dug, or 0). From level 6 the target is drawn round the sample.
const LADDER := [
	[1, 10, ADD], [2, 20, 0], [3, 35, -2], [5, 40, BRIDGE], [10, 50, -3],
	[19, 100, -4], [27, 150, MUL], [36, 300, -5], [47, 450, -6], [50, 500, PRIO],
	[82, 600, -7], [174, 800, -8], [248, 1000, SUB], [324, 2000, -9], [466, 3000, -11],
	[594, 4000, DIV], [631, 5000, -12], [727, 6000, -13], [891, 7000, POW], [928, 8000, -14],
	[1779, 9000, -15], [2805, 10000, CRATE], [3366, 10500, 0], [4860, 11000, 0], [5445, 11500, 0],
	[6667, 12000, 0], [7512, 12500, 0], [8133, 13000, 0], [9646, 13500, 0], [10904, 14000, 0],
	[12675, 14500, 0], [14772, 14500, 0], [18962, 14500, 0], [20158, 14500, 0], [23431, 14500, 0],
	[24755, 14500, 0], [27432, 14500, 0], [29296, 14500, 0], [32550, 14500, 0], [35541, 14500, 0],
]
## The band a target is drawn in round the sample, from level BAND_FROM.
const BAND := 0.12
const BAND_FROM := 6
## Past the table: each target the last times 1 + a draw from GROW (the
## reference's levels 31 to 40 grow 6% to 30%) times (40 / level)^2, so
## the climb slows as the reference's does: level 100 near a million, level
## 1000 near ten million (its players at 1000 were never asked nine
## digits). No level is the last; TOP is only the 32-bit edge.
const GROW := Vector2(0.05, 0.25)
const TOP := LIMIT
## Past the table every level asks the table's last count.
const COUNT_TOP := 14500
## From level 23 each level hands over the number level - DIG_FROM, to the
## last printed (999, at level 1006).
const DIG_FROM := 7
const MOST := 999

# --- the paper ---

## Where a value prints (the user, 2026-10-20: "more sparse numbers from
## each other, and smaller numbers near center, bigger and bigger numbers
## near edges"): `band(v)` the rings (squares from the box's edge) its
## copies lie in, a schedule that moves out with the value, the steps wide
## where the small numbers are (APART keeps them apart, and the rings near
## the box are short) and closer further out, where the rings are long;
## `copies(v)` how many of it. 1s at 8 to 16, 5s at 26 to 36, 9s at 42 to
## 52, 19s at 70 to 84, 39s at 114 to 130, 60s at 156 to 182; past 60 the
## rings go out by area (`FAR_FROM` to `FAR_TO`), so the big numbers lie
## as thick on the paper near 60 as near 999.
const NEAR := [[1, 8.0, 0.0, 8], [5, 14.0, 4.0, 10], [9, 30.0, 4.0, 10], [19, 46.0, 3.0, 14], [39, 72.0, 2.2, 16], [60, 114.0, 2.1, 26]]
const FAR_FROM := 186.0
const FAR_TO := 484.0
const FAR_BAND := 10
## No printed number to 60 has another within this many squares: two digs
## side by side leave APART - 3 squares between them, room for machines
## and their belts. Past 60, APART_FAR.
const APART := 12
const APART_FAR := 9
## A written square wires the slots this far round it again (a dig's belts
## leading away read two squares past its edge: three from its root).
const REWIRE := 3

## [near, far]: the rings the copies of `v` print on.
static func band(v: int) -> Vector2i:
	var first := 1
	for row: Array in NEAR:
		var last := int(row[0])
		if v <= last:
			var near := roundi(float(row[1]) + float(row[2]) * (v - first))
			return Vector2i(near, mini(near + int(row[3]), HUB_AT.x - 2))
		first = last + 1
	var u := float(v - first) / float(MOST - first)
	var near := roundi(sqrt(FAR_FROM * FAR_FROM + u * (FAR_TO * FAR_TO - FAR_FROM * FAR_FROM)))
	return Vector2i(near, mini(near + FAR_BAND, HUB_AT.x - 2))

static func copies(v: int) -> int:
	return 4 if v == 1 else (3 if v <= int(NEAR[-1][0]) else 2)

static func apart(v: int) -> int:
	return APART if v <= int(NEAR[-1][0]) else APART_FAR

# --- the upgrades ---

const TRACKS := ["belt", "dig", "add", "mul", "sub", "pow"]
const TRACK_KIND := {"belt": BELT, "dig": DIG, "add": ADD, "mul": MUL, "sub": SUB, "pow": POW}
## The dig's top is its twelve edge squares, a belt each; the others are
## the reference's.
const TRACK_TOP := {"belt": 128, "dig": 12, "add": 108, "mul": 108, "sub": 108, "pow": 108}
## What each track's ranks 1 to 8 ask, the reference's: [number, count] for
## one, two, then three numbers. Where its run left a gap (the belt's sixth
## numbers, the dig's eighth third, subtract's first three ranks) the
## numbers carry on its slide. Past the table a rank slides on: the oldest
## number goes, a new one comes (the last times SEQ_GROW), each count
## COUNT_UP more. A number past SEQ_KEEP is drawn within SEQ_BAND a save.
const RANKS := {
	"belt": [[[1, 200]], [[1, 1000], [16, 500]], [[1, 4000], [16, 3000], [22, 1500]],
		[[34, 9000], [121, 7000], [839, 6000]], [[94, 9000], [247, 7000], [562, 6000]],
		[[247, 11000], [562, 9000], [854, 8000]], [[854, 15000], [1526, 12000], [7891, 10000]],
		[[1526, 20000], [7891, 16000], [4294, 12000]]],
	"dig": [[[2, 300]], [[2, 2000], [18, 1000]], [[2, 5000], [18, 2000], [23, 1000]],
		[[16, 8000], [22, 3000], [438, 2000]], [[89, 10000], [378, 4000], [787, 3000]],
		[[291, 12000], [791, 8000], [2319, 4000]], [[791, 15000], [2319, 12000], [7774, 6000]],
		[[2319, 20000], [7774, 17000], [24879, 20000]]],
	"add": [[[3, 450]], [[3, 3000], [11, 1500]], [[3, 5000], [11, 4000], [75, 3000]],
		[[11, 7000], [91, 5000], [193, 4000]], [[91, 12000], [193, 10000], [625, 5000]],
		[[193, 15000], [625, 12000], [3447, 8000]], [[625, 20000], [3447, 17000], [9423, 10000]],
		[[3447, 30000], [9423, 20000], [44031, 16000]]],
	"mul": [[[15, 500]], [[15, 5000], [20, 2500]], [[15, 10000], [20, 7000], [257, 4000]],
		[[20, 11000], [257, 6000], [690, 5000]], [[257, 17000], [690, 13000], [3644, 6000]],
		[[690, 22000], [3644, 17000], [6433, 10000]], [[3644, 35000], [6433, 25000], [49514, 17000]],
		[[6433, 37000], [49514, 30000], [97001, 20000]]],
	"sub": [[[36, 600]], [[36, 6000], [147, 3000]], [[36, 12000], [147, 8000], [640, 5000]],
		[[147, 13000], [640, 8000], [3103, 6000]], [[640, 24000], [3103, 16000], [8118, 8000]],
		[[3103, 32000], [8118, 21000], [30870, 13000]], [[8118, 43000], [30870, 33000], [61589, 26000]],
		[[30870, 50000], [61589, 40000], [227887, 30000]]],
	"pow": [[[64, 800]], [[64, 7000], [187, 4000]], [[64, 10000], [187, 6000], [983, 4000]],
		[[187, 15000], [983, 9000], [4563, 7000]], [[983, 29000], [4563, 18000], [5684, 9000]],
		[[4563, 37000], [5684, 25000], [6605, 15000]], [[5684, 40000], [11067, 35000], [92927, 26000]],
		[[11067, 60000], [92927, 50000], [8312675, 40000]]],
}
const SEQ_GROW := 1.6
const SEQ_BAND := 0.1
const SEQ_KEEP := 30
const COUNT_UP := 500
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
## A junction's priority (from level 10, `set_prio`): 0 none, 1 + d the
## feeder coming in going way `d` goes first (the rest fill its gaps), 5 + d
## the way out `d` is filled first (the rest take what it cannot).
var prio := PackedByteArray()
var root := PackedInt32Array()
var role := PackedByteArray()
var dep := PackedInt32Array()
## The machines' layer: on each square an operator covers its kind, its
## facing, its root square and what the square is (R_A ...); 0 and -1
## elsewhere. Nothing on the paper's layer sees it.
var op := PackedByteArray()
var oface := PackedByteArray()
var oroot := PackedInt32Array()
var orole := PackedByteArray()
## For each slot, 1 + the side (0 A, 1 B) when it is on a machine's A or B
## square: a token there waits at the square's middle to be taken.
var intake := PackedByteArray()
## The parts: id -> {name, w, h, pieces: [[x, y, kind, face, face2, fork]]}
## from the template's corner (an operator by its root).
var defs := {}
var next_def := 1

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
var feeders := {}       # slot, crate or box end id -> PackedInt32Array of slots
var machines := {}      # square -> {a, b, out, rem, busy, t, x, y, last}
var digs := {}          # square -> {budget, rr, outs}
var crates := {}        # square -> {v, n, rr, outs}

var _targets: Array = []
var _trng := RandomNumberGenerator.new()
var _seqs := {}

## The sparse index: no edit, wire, save or draw walks the whole sheet.
## `used` is every square with a piece on the paper's layer (but the box)
## or a machine's root over it; `cells[c]` the belts and crossings of chunk
## `c`; `printed` the squares with a number printed. `_touched` is every
## square written since the last `_wire` (every write goes through
## `_record`, or `touch` from outside); `changed` the same, kept for the
## board until it clears it.
var used := {}
var cells: Array = []
var printed := PackedInt32Array()
var _touched := {}
var changed := PackedInt32Array()

func _init(rng_seed := 0) -> void:
	seed_v = rng_seed if rng_seed != 0 else (randi() | 1)
	kind.resize(N)
	face.resize(N)
	face2.resize(N)
	fork.resize(N)
	prio.resize(N)
	root.resize(N)
	root.fill(-1)
	role.resize(N)
	dep.resize(N)
	op.resize(N)
	oface.resize(N)
	oroot.resize(N)
	oroot.fill(-1)
	orole.resize(N)
	intake.resize(N2)
	occ.resize(N2)
	val.resize(N2)
	prog.resize(N2)
	from_d.resize(N2)
	to_d.resize(N2)
	to_d.fill(NONE)
	rr_in.resize(N2)
	rr_out.resize(N2)
	dead.resize(N2)
	cells.resize(CHUNKS)
	for c in CHUNKS:
		cells[c] = PackedInt32Array()
	for id: String in TRACKS:
		lv[id] = 1
	_trng.seed = seed_v
	_draw_seqs()
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

## The chunk square `i` lies in.
static func chunk_of(i: int) -> int:
	return (i / W) / CH * CW + (i % W) / CH

## A square written past the sim's own actions (a test's, a harness's):
## the next `_wire` reads it again.
func touch(i: int) -> void:
	_touched[i] = true

## `printed` again from `dep`, after numbers were written straight on.
func reprint() -> void:
	printed = PackedInt32Array()
	for i in N:
		if dep[i] != 0:
			printed.append(i)

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

## What is seen on `t`: a machine over the paper, else the paper's piece.
func kind_at(t: Vector2i) -> int:
	if not inside(t):
		return -1
	var i := _i(t)
	return int(op[i]) if op[i] != 0 else int(kind[i])

## The paper's own piece on `t`, a machine over it or not.
func belt_at(t: Vector2i) -> int:
	return kind[_i(t)] if inside(t) else -1

func face_at(t: Vector2i) -> int:
	var i := _i(t)
	return int(oface[i]) if op[i] != 0 else int(face[i])

func dep_at(t: Vector2i) -> int:
	return dep[_i(t)] if inside(t) else 0

func box_rect() -> Rect2i:
	return Rect2i(HUB_AT, Vector2i(HUB, HUB))

## How many squares `t` is from the box's edge (0 on it).
static func ring(t: Vector2i) -> int:
	var dx := maxi(HUB_AT.x - t.x, t.x - (HUB_AT.x + HUB - 1))
	var dy := maxi(HUB_AT.y - t.y, t.y - (HUB_AT.y + HUB - 1))
	return maxi(maxi(dx, dy), 0)

## Prints the numbers on the paper: each value its copies on rings in its
## band, none within APART of another.
func _print_paper() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x5eed
	var placed := {}
	for v in range(1, MOST + 1):
		if v == 10:
			continue
		var b := band(v)
		var put := 0
		var tries := 0
		while put < copies(v) and tries < 600:
			tries += 1
			var t := _on_ring(rng.randi_range(b.x, b.y), rng.randf())
			if t.x < 1 or t.y < 1 or t.x > W - 2 or t.y > H - 2 or not _clear_round(t, placed, apart(v)):
				continue
			dep[_i(t)] = v
			printed.append(_i(t))
			var c := t / (APART + 1)
			if not placed.has(c):
				placed[c] = []
			placed[c].append(t)
			put += 1

## A square on the ring `d` squares from the box's edge, `u` (0 to 1) of
## the way round it.
static func _on_ring(d: int, u: float) -> Vector2i:
	var x0 := HUB_AT.x - d
	var y0 := HUB_AT.y - d
	var l := HUB + 2 * d - 1
	var p := int(u * 4.0 * l) % (4 * l)
	var side := p / l
	var o := p % l
	match side:
		0:
			return Vector2i(x0 + o, y0)
		1:
			return Vector2i(x0 + l, y0 + o)
		2:
			return Vector2i(x0 + l - o, y0 + l)
	return Vector2i(x0, y0 + l - o)

## Whether no placed number lies within `a` squares of `t`: `placed` is
## kept in cells of APART + 1, so the cells round `t`'s are all there is
## to look at.
static func _clear_round(t: Vector2i, placed: Dictionary, a := APART) -> bool:
	var c := t / (APART + 1)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for q: Vector2i in placed.get(c + Vector2i(dx, dy), []):
				if maxi(absi(q.x - t.x), absi(q.y - t.y)) <= a:
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
	var g := _trng.randf_range(GROW.x, GROW.y) * pow(float(LADDER.size()) / n, 2.0)
	return mini(maxi(int(round(last * (1.0 + g))), last + 1), TOP)

func count_of(n: int) -> int:
	if n <= LADDER.size():
		return int(LADDER[n - 1][1])
	return COUNT_TOP

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

## Each track's table numbers as this save has them: {number: drawn}, the
## same number drawn once however many ranks ask it.
func _draw_seqs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x7a11
	for id: String in TRACKS:
		_seqs[id] = {}
		for rank: Array in RANKS[id]:
			for a: Array in rank:
				var v := int(a[0])
				if not _seqs[id].has(v):
					_seqs[id][v] = v if v <= SEQ_KEEP else int(round(v * rng.randf_range(1.0 - SEQ_BAND, 1.0 + SEQ_BAND)))

## The number past the table's last rank `k` places on (0: its third).
static func _past(id: String, k: int) -> int:
	var v := int(RANKS[id][-1][-1][0])
	for j in k:
		v = mini(int(round(v * SEQ_GROW)) + 1, LIMIT)
	return v

func track_open(id: String) -> bool:
	return has(int(TRACK_KIND[id]))

func at_top(id: String) -> bool:
	return int(lv[id]) >= int(TRACK_TOP[id])

## What the next rank of `id` asks: [[number, count], ...] (one, two, then
## three sliding).
func asks(id: String) -> Array:
	return asks_at(id, int(lv[id]))

## What rank `r` of `id` asks (the upgrades' sheet shows the rank after).
func asks_at(id: String, r: int) -> Array:
	var table: Array = RANKS[id]
	var out := []
	if r <= table.size():
		for a: Array in table[r - 1]:
			out.append([int(_seqs[id][int(a[0])]), int(a[1])])
		return out
	# the last rank's three numbers then the new ones, rank 8 + p asking
	# the p-th to the p+2-th
	var past := r - table.size()
	var last: Array = table[-1]
	for j in 3:
		var k := past + j
		var v := int(_seqs[id][int(last[k][0])]) if k < 3 else _past(id, k - 2)
		out.append([v, int(last[j][1]) + COUNT_UP * past])
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
		if not inside(u):
			return "edge"
		var i := _i(u)
		var here := int(kind[i])
		if here == BOX:
			return "box"
		if is_op(k):
			# over belts and crossings, never a dig, a crate or another machine
			if here == DIG or here == CRATE or (op[i] != 0 and int(oroot[i]) != mine):
				return "taken"
			continue
		if here != EMPTY and here != BELT and here != BRIDGE:
			return "taken"
		if op[i] != 0 and k != BELT and k != BRIDGE:
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

## Piece `k` written on every square it covers, what stood there cleared;
## an operator on the machines' layer, the paper under it as it was.
func _stamp(k: int, t: Vector2i, f: int) -> void:
	if is_op(k):
		for c: Array in footprint(k, t, f):
			var j := _i(c[0])
			_record(j)
			op[j] = k
			oface[j] = f
			oroot[j] = _i(t)
			orole[j] = int(c[1])
		return
	var r := _i(t) if SHAPES.has(k) else -1
	for c: Array in footprint(k, t, f):
		var i := _i(c[0])
		_record(i)
		_clear(i)
		fork[i] = 0
		prio[i] = 0
		kind[i] = k
		face[i] = f
		root[i] = r
		role[i] = int(c[1])

## The squares of what is seen on `t` (all of a machine's, or of a dig's).
func piece_squares(t: Vector2i) -> Array:
	var i := _i(t)
	if op[i] == 0:
		return _squares_b(t)
	var r := int(oroot[i])
	var out := []
	for c: Array in footprint(int(op[r]), tile_of(r), int(oface[r])):
		out.append(c[0])
	return out

## The squares of the paper's own piece on `t` (all of a dig's).
func _squares_b(t: Vector2i) -> Array:
	var r := int(root[_i(t)])
	if r < 0:
		return [t]
	var out := []
	for c: Array in footprint(int(kind[r]), tile_of(r), int(face[r])):
		out.append(c[0])
	return out

## The root square of what is seen on `t`: a machine's, a dig's, or `t`.
func root_of(t: Vector2i) -> Vector2i:
	if inside(t) and op[_i(t)] != 0:
		return tile_of(int(oroot[_i(t)]))
	return _root_b(t)

## The root square of the paper's own piece on `t`.
func _root_b(t: Vector2i) -> Vector2i:
	var r := int(root[_i(t)]) if inside(t) else -1
	return tile_of(r) if r >= 0 else t

## Whether a run of belt may go over `t` (a machine over it is not seen).
func can_lay(t: Vector2i) -> bool:
	if not inside(t):
		return false
	var k := int(kind[_i(t)])
	return k == EMPTY or k == BELT or k == BRIDGE

## The machine with its root on `r` lifted off its layer.
func _lift_op(r: int) -> void:
	for c: Array in footprint(int(op[r]), tile_of(r), int(oface[r])):
		var j := _i(c[0])
		_record(j)
		op[j] = 0
		oface[j] = 0
		oroot[j] = -1
		orole[j] = R_NONE
	if machines.has(r):
		_unmouth(r)
		machines.erase(r)

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
			var at := _root_b(ts[0])
			while ts.size() > 1 and inside(ts[0]) and (ts[0] == begun or (not can_lay(ts[0]) and (_root_b(ts[0]) == at or (k0 == BOX and belt_at(ts[0]) == BOX)))):
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
			if j > 0 and j < last and _fed_straight(i) and has(BRIDGE):
				continue
			# a line across the last square (or across its way before
			# crossings are had): the path runs into its side
			cut = j
			merge = j > 0 and (j == last or not has(BRIDGE))
			break
		if j > 0 and j == last and int(kind[i]) == BELT and int(face[i]) == opp(f) and belt_at(ts[j - 1]) != BELT:
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
		if begun != NOWHERE and (u == begun or _root_b(u) == _root_b(begun) or (k == BOX and belt_at(begun) == BOX)):
			return d
		if best < 0 and (k == BOX or k == CRATE):
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
		var k := int(kind[i])
		if k == DIG or k == CRATE:
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
				prio[i] = 0
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
	if belt_at(t) != BELT:
		return []
	var s0 := _i(t)
	var line := [s0]
	var seen := {s0: true}
	var s := s0
	while true:
		var fd: PackedInt32Array = feeders.get(s, PackedInt32Array())
		if fd.size() != 1 or seen.has(fd[0]):
			break
		var p := int(fd[0])
		var pk := int(kind[p % N])
		if pk != BELT and pk != BRIDGE or (feeders.get(p, PackedInt32Array()) as PackedInt32Array).size() > 1:
			break
		if bare and pk != BELT:
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
		if bare and int(kind[nx % N]) != BELT:
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
	if belt_at(head) == BELT:
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
		prio[i] = 0
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
	if op[i] != 0:
		var r := int(oroot[i])
		var ko := int(op[r])
		var f := (int(oface[r]) + 1) % 4
		var at := turned_root(ko, tile_of(r), int(oface[r]), f)
		var why := why_not(ko, at, f, r)
		if why != "":
			_emit("refused", {"why": "no_room", "tile": at, "v": 0})
			return false
		_lift_op(r)
		_stamp(ko, at, f)
		_wire()
		_emit("turn", {"kind": ko, "tile": at, "face": f})
		return true
	var k := int(kind[i])
	if k == EMPTY or k == BOX or k == DIG or k == CRATE or k == BRIDGE:
		return false
	_record(i)
	face[i] = (int(face[i]) + 1) % 4
	fork[i] = 0
	prio[i] = 0
	to_d[i] = NONE
	_wire()
	_emit("turn", {"kind": k, "tile": t, "face": int(face[i])})
	return true

## Lifts what is seen on `t`: all of a machine from any of its squares (the
## belts under it stay), else the paper's piece.
func remove(t: Vector2i) -> bool:
	if not inside(t):
		return false
	var i := _i(t)
	if op[i] != 0:
		var r := int(oroot[i])
		var ko := int(op[r])
		var fo := int(oface[r])
		_lift_op(r)
		_wire()
		_emit("lift", {"kind": ko, "tile": tile_of(r), "face": fo})
		return true
	var k := int(kind[i])
	if k == EMPTY or k == BOX:
		return false
	var at := _root_b(t)
	var f := int(face[_i(at)])
	for u: Vector2i in _squares_b(t):
		var j := _i(u)
		_record(j)
		_clear(j)
		kind[j] = EMPTY
		fork[j] = 0
		prio[j] = 0
		root[j] = -1
		role[j] = R_NONE
	_wire()
	_emit("lift", {"kind": k, "tile": at, "face": f})
	return true

# --- parts and picks ---

## Whether parts can be saved and set down: from the adder on.
func parts_open() -> bool:
	return has(ADD)

## A template's grid turned `rot` quarters clockwise, as squares across and down.
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

## The pieces standing on any of `tiles`, on either layer (all of a
## machine's or a dig's squares when one is among them), every square once;
## the box is never one.
func picked(tiles: Array) -> Array:
	var seen := {}
	var out := []
	for t: Vector2i in tiles:
		if not inside(t):
			continue
		var i := _i(t)
		var sq := []
		var k := int(kind[i])
		if k != EMPTY and k != BOX:
			sq.append_array(_squares_b(t))
		if op[i] != 0:
			sq.append_array(piece_squares(t))
		for u: Vector2i in sq:
			if not seen.has(u):
				seen[u] = true
				out.append(u)
	return out

## The picked squares as a template: {w, h, pieces} from their corner, the
## paper's pieces (digs too) and the machines over them; {} when nothing
## can be kept.
func template_of(tiles: Array) -> Dictionary:
	var lo := Vector2i(W, H)
	var hi := Vector2i(-1, -1)
	var keep := []
	for t: Vector2i in picked(tiles):
		var i := _i(t)
		if not TEMPLATE_KINDS.has(int(kind[i])) and not (op[i] != 0 and TEMPLATE_KINDS.has(int(op[i]))):
			continue
		keep.append(t)
		lo = lo.min(t)
		hi = hi.max(t)
	if keep.is_empty():
		return {}
	var pieces := []
	var rest := []
	for t: Vector2i in keep:
		var i := _i(t)
		var k := int(kind[i])
		var at := t - lo
		if k == BELT:
			pieces.append([at.x, at.y, k, int(face[i]), 0, int(fork[i])])
		elif k == BRIDGE:
			pieces.append([at.x, at.y, k, int(face[i]), int(face2[i]), 0])
		elif TEMPLATE_KINDS.has(k) and (int(root[i]) < 0 or int(root[i]) == i):
			rest.append([at.x, at.y, k, int(face[i]), 0, 0])
		if op[i] != 0 and int(oroot[i]) == i:
			rest.append([at.x, at.y, int(op[i]), int(oface[i]), 0, 0])
	pieces.append_array(rest)
	var sz := hi - lo + Vector2i.ONE
	return {"w": sz.x, "h": sz.y, "pieces": pieces}

## Every square template `d` covers set down with its corner on `t`, turned
## `rot`: [square, piece row] for each (all of a machine's squares).
func template_squares(d: Dictionary, t: Vector2i, rot: int) -> Array:
	var out := []
	for pc: Array in d.pieces:
		var at := t + turned_at(int(pc[0]), int(pc[1]), int(d.w), int(d.h), rot)
		var k := int(pc[2])
		if SHAPES.has(k):
			for c: Array in footprint(k, at, (int(pc[3]) + rot) % 4):
				out.append([c[0], pc])
		else:
			out.append([at, pc])
	return out

## The squares of template `d` on `t` turned `rot` that cannot be had: off
## the paper, the box, a piece where only belt may be (as `why_not` says), a
## machine where one stands already, a dig off a number.
func template_blocked(d: Dictionary, t: Vector2i, rot: int) -> Dictionary:
	var bad := {}
	for row: Array in template_squares(d, t, rot):
		var u: Vector2i = row[0]
		var k := int((row[1] as Array)[2])
		if not inside(u):
			bad[u] = "edge"
			continue
		var i := _i(u)
		var here := int(kind[i])
		var bare := here == EMPTY or here == BELT or here == BRIDGE
		if here == BOX:
			bad[u] = "box"
		elif is_op(k):
			# a machine over belts, never a dig, a crate or another machine
			if not bare or op[i] != 0:
				bad[u] = "taken"
			elif not has(k):
				bad[u] = "locked"
		elif not bare or (op[i] != 0 and k != BELT and k != BRIDGE):
			bad[u] = "taken"
		elif k == BRIDGE and not has(BRIDGE):
			bad[u] = "locked"
	# a dig stands on a printed number it can dig
	for pc: Array in d.pieces:
		if int(pc[2]) != DIG:
			continue
		var at := t + turned_at(int(pc[0]), int(pc[1]), int(d.w), int(d.h), rot)
		if not inside(at):
			continue
		if dep[_i(at)] == 0:
			bad[at] = "no_number"
		elif not can_dig(dep[_i(at)]):
			bad[at] = "not_yet"
	return bad

## Why template `d` cannot be set down on `t` turned `rot`, or "".
func why_not_template(d: Dictionary, t: Vector2i, rot: int) -> String:
	if d.is_empty() or (d.pieces as Array).is_empty():
		return "taken"
	var bad := template_blocked(d, t, rot)
	for u: Vector2i in bad:
		return String(bad[u])
	return ""

func why_not_part(id: int, t: Vector2i, rot: int) -> String:
	if not defs.has(id):
		return "taken"
	return why_not_template(defs[id], t, rot)

## Template `d` written onto the paper from `t`, turned `rot`, as plain
## pieces: nothing ties them to where they came from. Returns the squares.
func stamp_template(d: Dictionary, t: Vector2i, rot: int) -> Array:
	var why := why_not_template(d, t, rot)
	if why != "":
		_emit("refused", {"why": why, "tile": t, "v": 0})
		return []
	var tiles := []
	for pc: Array in d.pieces:
		var at := t + turned_at(int(pc[0]), int(pc[1]), int(d.w), int(d.h), rot)
		var k := int(pc[2])
		var f := (int(pc[3]) + rot) % 4
		if SHAPES.has(k) or k == CRATE:
			_stamp(k, at, f)
			for c: Array in footprint(k, at, f):
				tiles.append(c[0])
		elif k == BELT or k == BRIDGE:
			var i := _i(at)
			_record(i)
			_clear(i)
			kind[i] = k
			face[i] = f
			face2[i] = (int(pc[4]) + rot) % 4
			if k == BRIDGE and f % 2 == 1:
				# a crossing keeps its across lane in face, its up-and-down
				# one in face2: a quarter turn swaps them
				face[i] = face2[i]
				face2[i] = f
			fork[i] = turned_bits(int(pc[5]), rot) if k == BELT else 0
			root[i] = -1
			role[i] = R_NONE
			tiles.append(at)
	_wire()
	_emit("lay", {"n": tiles.size(), "tiles": tiles, "tile": t})
	return tiles

## Every piece on `tiles` lifted in one go, a machine whole with the belts
## under the pick (the paper wired once). Returns how many squares.
func lift_all(tiles: Array) -> int:
	var sq := picked(tiles)
	for u: Vector2i in sq:
		var j := _i(u)
		_record(j)
		_clear(j)
		kind[j] = EMPTY
		fork[j] = 0
		prio[j] = 0
		root[j] = -1
		role[j] = R_NONE
		if machines.has(int(oroot[j])):
			_unmouth(int(oroot[j]))
			machines.erase(int(oroot[j]))
		op[j] = 0
		oface[j] = 0
		oroot[j] = -1
		orole[j] = R_NONE
	if sq.is_empty():
		return 0
	_wire()
	_emit("erase", {"n": sq.size(), "tiles": sq, "tile": sq[0]})
	return sq.size()

## The picked squares kept as a new part; its id, or -1 when nothing could be.
func save_part(tiles: Array) -> int:
	var d := template_of(tiles)
	if d.is_empty():
		return -1
	var id := next_def
	next_def += 1
	d["name"] = "%d" % id
	defs[id] = d
	_emit("part", {"id": id})
	return id

## Part `d`'s name as the player reads it: "Part n".
static func part_title(d: Dictionary) -> String:
	var nm := String(d.get("name", ""))
	if nm.is_valid_int():
		return TranslationServer.translate("TL_PART_NAME") % nm
	return nm

## Part `id` thrown away (what was set down from it stays).
func drop_part(id: int) -> void:
	defs.erase(id)
	_emit("part", {"id": id})

# --- one step back ---

## The holder calls `mark()` as a gesture begins; every square the gesture
## changes is written down once, and `undo()` puts them all back as they
## were (tokens riding there fall off, a crate's contents are not kept).
func mark() -> void:
	_undo = {}

func _record(i: int) -> void:
	_touched[i] = true
	if not _undo.has(i):
		_undo[i] = [int(kind[i]), int(face[i]), int(face2[i]), int(root[i]), int(role[i]), int(fork[i]), int(op[i]), int(oface[i]), int(oroot[i]), int(orole[i]), int(prio[i])]

func can_undo() -> bool:
	return not _undo.is_empty()

func undo() -> bool:
	if _undo.is_empty():
		return false
	var n := 0
	for i: int in _undo:
		var was: Array = _undo[i]
		_touched[i] = true
		_clear(i)
		kind[i] = int(was[0])
		face[i] = int(was[1])
		face2[i] = int(was[2])
		root[i] = int(was[3])
		role[i] = int(was[4])
		fork[i] = int(was[5])
		prio[i] = int(was[10]) if was.size() > 10 else 0
		op[i] = int(was[6])
		oface[i] = int(was[7])
		oroot[i] = int(was[8])
		orole[i] = int(was[9])
		n += 1
	_undo = {}
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
	var mine := _squares_b(t)
	for q: Vector2i in mine:
		for d in 4:
			var u: Vector2i = q + DIRS[d]
			if not inside(u) or mine.has(u):
				continue
			var i := _i(u)
			if int(kind[i]) != BELT:
				continue
			var f := int(face[i])
			if f == d or (f != opp(d) and belt_at(u - DIRS[f]) == EMPTY):
				o.append((i << 2) | d)
	return o

func _feed(id: int, s: int) -> void:
	if not feeders.has(id):
		feeders[id] = PackedInt32Array()
	feeders[id].append(s)

## Wires the paper again where it changed: every slot written since the
## last wire and the ones beside it get their ends worked out again
## (`outs`, the `feeders` handing into them, `dead`), a dig or a crate
## within reach its belts leading away, a machine over a written square
## its sides; the rest of the sheet is left as it was, so an edit costs
## what it touched and not the factory. `_wire_all` does the whole sheet
## from the index, the same answer, for checks.
func _wire() -> void:
	var touched := _touched.keys()
	_touched = {}
	# the index: in or out of it, and a square no longer a belt forgets its
	# token and its fork
	for i: int in touched:
		var k := int(kind[i])
		var on_paper := k != EMPTY and k != BOX
		var is_root := op[i] != 0 and int(oroot[i]) == i
		if on_paper or is_root:
			used[i] = true
		else:
			used.erase(i)
		var c := chunk_of(i)
		var cell: PackedInt32Array = cells[c]
		var at := cell.find(i)
		var laned := k == BELT or k == BRIDGE
		if laned and at < 0:
			cell.append(i)
		elif not laned and at >= 0:
			cell.remove_at(at)
		if not laned:
			occ[i] = 0
			occ[i + N] = 0
			fork[i] = 0
			prio[i] = 0
		elif k != BRIDGE:
			occ[i + N] = 0
		changed.append(i)
	# the slots whose ends may have changed: the written squares' and their
	# neighbours' (a belt's end is the square in front of it)
	var slots := {}
	var pieces := {}
	var roots := {}
	for i: int in touched:
		var t := tile_of(i)
		for dy in range(-REWIRE, REWIRE + 1):
			for dx in range(-REWIRE, REWIRE + 1):
				var u := t + Vector2i(dx, dy)
				if not inside(u):
					continue
				var j := _i(u)
				var kj := int(kind[j])
				if maxi(absi(dx), absi(dy)) <= 1 and (kj == BELT or kj == BRIDGE or j == i):
					slots[j] = true
				if kj == DIG:
					pieces[j if int(root[j]) < 0 else int(root[j])] = true
				elif kj == CRATE:
					pieces[j] = true
		if op[i] != 0:
			roots[int(oroot[i])] = true
	for sq: int in slots:
		for s0: int in [sq, sq + N]:
			_unfeed(s0)
			var e: Variant = _lane_outs(s0)
			if e == null:
				outs.erase(s0)
				_lanes_drop(s0)
				continue
			outs[s0] = e
			_lanes_add(s0)
			dead[s0] = 1 if (e as PackedInt32Array).is_empty() else 0
			for end: int in e:
				_feed(end >> 2, s0)
			if to_d[s0] != NONE and int(to_d[s0]) >= (e as PackedInt32Array).size():
				to_d[s0] = NONE
	for r: int in pieces:
		var kr := int(kind[r])
		if kr == DIG and (int(root[r]) < 0 or int(root[r]) == r):
			if not digs.has(r):
				digs[r] = {"budget": 0.0, "rr": 0, "eff": 0.0, "at": -10.0, "e": -1}
			digs[r].outs = _away_from(tile_of(r))
		elif kr == CRATE:
			if not crates.has(r):
				crates[r] = {"v": 0, "n": 0, "rr": 0, "eff": 0.0, "at": -10.0}
			crates[r].outs = _away_from(tile_of(r))
		else:
			digs.erase(r)
			crates.erase(r)
	# the machines over the written squares: lifted ones go, the rest take
	# the belts under their squares again
	for r: int in machines.keys():
		if op[r] == 0 or int(oroot[r]) != r:
			_unmouth(r)
			machines.erase(r)
	for r: int in roots:
		if op[r] == 0 or int(oroot[r]) != r:
			continue
		if machines.has(r):
			_unmouth(r)
		else:
			machines[r] = _machine()
		_mouth(r)

## The whole sheet wired from nothing, as `_wire` leaves it piece by piece.
func _wire_all() -> void:
	_wire()
	lanes = PackedInt32Array()
	outs = {}
	feeders = {}
	var roots := []
	var walk := PackedInt32Array(used.keys())
	walk.sort()
	for i: int in walk:
		var k := int(kind[i])
		var t := tile_of(i)
		if op[i] != 0 and int(oroot[i]) == i:
			roots.append(i)
		if k == BELT or k == BRIDGE:
			for s0: int in [i, i + N]:
				var e: Variant = _lane_outs(s0)
				if e != null:
					lanes.append(s0)
					outs[s0] = e
		else:
			if k == DIG and (int(root[i]) < 0 or int(root[i]) == i):
				if not digs.has(i):
					digs[i] = {"budget": 0.0, "rr": 0, "eff": 0.0, "at": -10.0, "e": -1}
				digs[i].outs = _away_from(t)
			elif k == CRATE:
				if not crates.has(i):
					crates[i] = {"v": 0, "n": 0, "rr": 0, "eff": 0.0, "at": -10.0}
				crates[i].outs = _away_from(t)
	lanes.sort()
	dead.fill(0)
	for s0: int in lanes:
		if (outs[s0] as PackedInt32Array).is_empty():
			dead[s0] = 1
		for e: int in outs[s0]:
			_feed(e >> 2, s0)
		if to_d[s0] != NONE and int(to_d[s0]) >= (outs[s0] as PackedInt32Array).size():
			to_d[s0] = NONE
	intake.fill(0)
	for r: int in machines.keys():
		if op[r] == 0 or int(oroot[r]) != r:
			machines.erase(r)
	for r: int in roots:
		if not machines.has(r):
			machines[r] = _machine()
		_mouth(r)

## Slot `s0`'s ends, or null when its square carries no such lane.
func _lane_outs(s0: int):
	var i := s0 % N
	var k := int(kind[i])
	var t := tile_of(i)
	if k == BELT:
		if s0 >= N:
			return null
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
		return o
	if k == BRIDGE:
		fork[i] = 0
		prio[i] = 0
		var f := int(face[i]) if s0 < N else int(face2[i])
		var o := PackedInt32Array()
		var e := _end_into(t + DIRS[f], f)
		if e >= 0:
			o.append(e)
		return o
	return null

## Slot `s0` taken off the feeders of what it handed into.
func _unfeed(s0: int) -> void:
	if not outs.has(s0):
		return
	for e: int in outs[s0]:
		var id := e >> 2
		if not feeders.has(id):
			continue
		var fs: PackedInt32Array = feeders[id]
		var at := fs.find(s0)
		if at >= 0:
			fs.remove_at(at)
		if fs.is_empty():
			feeders.erase(id)

func _lanes_add(s0: int) -> void:
	var at := lanes.bsearch(s0)
	if at >= lanes.size() or lanes[at] != s0:
		lanes.insert(at, s0)

func _lanes_drop(s0: int) -> void:
	var at := lanes.bsearch(s0)
	if at < lanes.size() and lanes[at] == s0:
		lanes.remove_at(at)
	dead[s0] = 0

## Machine `r` takes the slots of the belts under its squares.
func _mouth(r: int) -> void:
	var m: Dictionary = machines[r]
	m.ins = [PackedInt32Array(), PackedInt32Array()]
	m.fronts = PackedInt32Array()
	m.rems = PackedInt32Array()
	var held := PackedInt32Array()
	for c: Array in footprint(int(op[r]), tile_of(r), int(oface[r])):
		var q := _i(c[0])
		var slots: Array = [q] if int(kind[q]) == BELT else ([q, q + N] if int(kind[q]) == BRIDGE else [])
		for s0: int in slots:
			match int(c[1]):
				R_A, R_B:
					var side := 0 if int(c[1]) == R_A else 1
					intake[s0] = 1 + side
					held.append(s0)
					m.ins[side].append(s0)
				R_OUT:
					m.fronts.append(s0)
				R_REM:
					m.rems.append(s0)
	m.held = held

## Machine `r` lets go of the slots it held.
func _unmouth(r: int) -> void:
	var m: Dictionary = machines[r]
	for s0: int in m.get("held", PackedInt32Array()):
		intake[s0] = 0

func _machine() -> Dictionary:
	return {"a": [], "b": [], "out": [], "rem": [], "busy": false, "t": 0.0, "x": 0, "y": 0, "last": 0, "has_last": false, "a_since": -1.0, "b_since": -1.0, "rr": 0, "rr_rem": 0, "ins": [PackedInt32Array(), PackedInt32Array()], "fronts": PackedInt32Array(), "rems": PackedInt32Array(), "eff": 0.0}

# --- tokens moving ---

func _accepts(e: int, v: int) -> bool:
	var id := e >> 2
	if id < N2:
		return occ[id] == 0
	var i := (id - N2) >> 2
	if (id - N2) & 3 == 2:
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
	var pj := _prio_out(s, o)
	if pj >= 0 and _accepts(o[pj], val[s]):
		to_d[s] = pj
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
		var pj := _prio_out(s, o)
		if pj >= 0 and to_d[s] != pj and _accepts(o[pj], val[s]):
			# the way out with priority takes it the moment it has room
			to_d[s] = pj
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
		if _yields(s, o[j]):
			continue
		var v := val[s]
		var over := prog[s] - 1.0
		occ[s] = 0
		to_d[s] = NONE
		_put(o[j], v, over)
		if (o[j] >> 2) >= N2 and ((o[j] >> 2) - N2) & 3 == 3:
			# into the box, from slot `s`: the board flies it in
			_emit("in", {"v": v, "s": s})
		_wake(s, stack)

## Which of `o` (slot `s`'s ends) is its priority way out, or -1.
func _prio_out(s: int, o: PackedInt32Array) -> int:
	if s >= N or int(prio[s]) < 5:
		return -1
	var d := int(prio[s]) - 5
	for j in o.size():
		if (o[j] & 3) == d:
			return j
	return -1

## Whether slot `s`, about to hand into end `e`, gives way: `e`'s square has
## priority for a feeder coming in another way, and that one has a token
## at its edge or about to be: the marked line passes all it carries, the
## other fills the gaps between its tokens.
func _yields(s: int, e: int) -> bool:
	var id := e >> 2
	if id >= N or int(prio[id]) == 0 or int(prio[id]) > 4:
		return false
	var d := int(prio[id]) - 1
	if (e & 3) == d:
		return false
	for f: int in feeders.get(id, PackedInt32Array()):
		if f == s or occ[f] == 0 or prog[f] < 0.9:
			continue
		var fo: PackedInt32Array = outs[f]
		for j in fo.size():
			if fo[j] >> 2 == id and (fo[j] & 3) == d and (to_d[f] == NONE or int(to_d[f]) == j):
				return true
	return false

## The ways into and out of the belt on square `i`: [ins, outs], each the
## ways tokens go (a feeder coming in going `d`, a way out `d`).
func junction(i: int) -> Array:
	var ins := []
	var outs_d := []
	if i < 0 or i >= N or int(kind[i]) != BELT:
		return [ins, outs_d]
	for f: int in feeders.get(i, PackedInt32Array()):
		for e: int in outs.get(f, PackedInt32Array()):
			if e >> 2 == i and not ins.has(e & 3):
				ins.append(e & 3)
	for e: int in outs.get(i, PackedInt32Array()):
		if not outs_d.has(e & 3):
			outs_d.append(e & 3)
	return [ins, outs_d]

## Whether the belt on `t` is a junction a priority can be set on.
func can_prio(t: Vector2i) -> bool:
	if not inside(t):
		return false
	var jn := junction(_i(t))
	return (jn[0] as Array).size() > 1 or (jn[1] as Array).size() > 1

## Sets or clears the priority on `t`'s junction by its edge `side` (0 E, 1
## S, 2 W, 3 N): a feeder coming in by that edge, else the way out by it.
## The same again clears it; one a junction. Returns whether it did
## anything.
func set_prio(t: Vector2i, side: int) -> bool:
	if not has(PRIO) or not can_prio(t):
		return false
	var i := _i(t)
	var jn := junction(i)
	var code := 0
	if (jn[0] as Array).size() > 1 and (jn[0] as Array).has(opp(side)):
		code = 1 + opp(side)
	elif (jn[1] as Array).size() > 1 and (jn[1] as Array).has(side):
		code = 5 + side
	if code == 0:
		return false
	_record(i)
	prio[i] = 0 if int(prio[i]) == code else code
	_emit("prio", {"tile": t, "prio": int(prio[i])})
	return true

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
		if dead[s] == 1 or intake[s] != 0:
			# a line's loose end, or a machine's A or B: the token waits at its middle
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
		var k := int(op[i])
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
		# what waits at the middle of the belts under its A and B squares
		var sa := _waiting(m.ins[0])
		var sb := _waiting(m.ins[1])
		if not bool(m.busy) and sa >= 0 and sb >= 0 and (m.out as Array).size() < OUT \
				and (k != DIV or (m.rem as Array).size() < OUT):
			m.x = val[sa]
			m.y = val[sb]
			m.busy = true
			m.t = 0.0
			var stack := []
			for s: int in [sa, sb]:
				occ[s] = 0
				to_d[s] = NONE
				_wake(s, stack)
			for s: int in stack:
				_try_move(s)
			sa = -1
			sb = -1
		m.a = [] if sa < 0 else [int(val[sa])]
		m.b = [] if sb < 0 else [int(val[sb])]
		m.rr = _set_out(m.out, m.fronts, int(m.rr))
		m.rr_rem = _set_out(m.rem, m.rems, int(m.rr_rem))
		# a side empty while the other waits: since when
		var a_empty := sa < 0 and sb >= 0 and not bool(m.busy)
		var b_empty := sb < 0 and sa >= 0 and not bool(m.busy)
		m.a_since = (float(m.a_since) if float(m.a_since) >= 0.0 else clock) if a_empty else -1.0
		m.b_since = (float(m.b_since) if float(m.b_since) >= 0.0 else clock) if b_empty else -1.0
		m.eff = lerpf(float(m.eff), 1.0 if bool(m.busy) else 0.0, minf(1.0, d / EFF_T))

## Machine `r`'s notches and spouts as [ins, outs], bits `cell * 4 + way`
## (its footprint's order): an A or B square the way tokens ride in on the
## belt under it, an answer square the way its belt leaves.
func ports(r: int) -> Array:
	var bits := [0, 0]
	if not machines.has(r):
		return bits
	var fp := footprint(int(op[r]), tile_of(r), int(oface[r]))
	for ci in fp.size():
		var qi := _i(fp[ci][0])
		var k := int(kind[qi])
		if k != BELT and k != BRIDGE:
			continue
		var rl := int(fp[ci][1])
		if rl == R_A or rl == R_B:
			var ways := 0
			for sl in ([qi] if k == BELT else [qi, qi + N]):
				for s0: int in feeders.get(sl, PackedInt32Array()):
					for e: int in outs[s0]:
						if (e >> 2) == sl:
							ways |= 1 << (e & 3)
			if ways == 0:
				ways = 1 << int(face[qi])
			for w in 4:
				if ways & (1 << w):
					bits[0] = int(bits[0]) | (1 << (ci * 4 + w))
		else:
			bits[1] = int(bits[1]) | (1 << (ci * 4 + int(face[qi])))
	return bits

## The first of `slots` whose token has come to the square's middle, or -1.
func _waiting(slots: PackedInt32Array) -> int:
	for s: int in slots:
		if occ[s] == 1 and prog[s] >= 0.5:
			return s
	return -1

## What waits in `q` set down at the middle of the free ones of `slots`, in
## turn from `rr`, to ride on the belt's way; returns where the turn goes on.
func _set_out(q: Array, slots: PackedInt32Array, rr: int) -> int:
	var n := slots.size()
	if n == 0:
		return 0
	for k in n:
		if q.is_empty():
			break
		var s := slots[rr % n]
		rr = (rr + 1) % n
		if occ[s] == 0:
			occ[s] = 1
			val[s] = int(q.pop_front())
			prog[s] = 0.5
			from_d[s] = _slot_face(s)
			to_d[s] = NONE
	return rr

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

func _step_digs(d: float) -> void:
	var speed := belt_speed()
	for i: int in digs:
		var g: Dictionary = digs[i]
		var o: PackedInt32Array = g.outs
		var n := mini(o.size(), dig_belts())
		var ease := minf(1.0, d / EFF_T)
		if n == 0:
			g.budget = 0.0
			g.eff = lerpf(float(g.eff), 0.0, ease)
			continue
		g.budget = minf(float(g.budget) + n * speed * d, float(n))
		var v := int(dep[i])
		var held := false
		while float(g.budget) >= 1.0:
			var put := false
			for k in o.size():
				var j := (int(g.rr) + k) % o.size()
				if _accepts(o[j], v):
					_put(o[j], v, 0.0)
					g.rr = (j + 1) % o.size()
					g.at = clock
					g.e = o[j]
					put = true
					break
			if not put:
				held = true
				break
			g.budget = float(g.budget) - 1.0
		g.eff = lerpf(float(g.eff), 0.0 if held else 1.0, ease)
	for i: int in crates:
		var c: Dictionary = crates[i]
		var o: PackedInt32Array = c.outs
		var puts := 0
		for k in o.size():
			if int(c.n) <= 0:
				break
			var j := (int(c.rr) + k) % o.size()
			if _accepts(o[j], int(c.v)):
				_put(o[j], int(c.v), 0.0)
				c.n = int(c.n) - 1
				c.rr = (j + 1) % o.size()
				puts += 1
				c.at = clock
		var fresh := o.size() > 0 and int(c.n) > 0 and (puts > 0 or clock - float(c.get("at", -10.0)) <= CRATE_FRESH / (speed * o.size()))
		c.eff = lerpf(float(c.get("eff", 0.0)), 1.0 if fresh else 0.0, minf(1.0, d / EFF_T))

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
	if path == "":
		return
	var cfg := ConfigFile.new()
	var pieces := PackedInt32Array()
	var walk := PackedInt32Array(used.keys())
	walk.sort()
	for i: int in walk:
		var k := int(kind[i])
		if k != EMPTY and k != BOX and (int(root[i]) < 0 or int(root[i]) == i):
			pieces.append_array([i, k, int(face[i]), int(face2[i])])
		if op[i] != 0 and int(oroot[i]) == i:
			# a machine, read after the paper's pieces
			pieces.append_array([i, int(op[i]), int(oface[i]), 0])
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
	cfg.set_value("paper", "layers", true)
	var forks := PackedInt32Array()
	for i: int in walk:
		if int(kind[i]) == BELT and int(fork[i]) != 0:
			forks.append_array([i, int(fork[i])])
	cfg.set_value("paper", "forks", forks)
	var prios := PackedInt32Array()
	for i: int in walk:
		if int(kind[i]) == BELT and int(prio[i]) != 0:
			prios.append_array([i, int(prio[i])])
	cfg.set_value("paper", "prios", prios)
	cfg.set_value("paper", "keys", keys)
	cfg.set_value("paper", "counts", counts)
	cfg.set_value("paper", "crates", crate_rows)
	cfg.set_value("hand", "straight", straight)
	cfg.set_value("parts", "defs", defs)
	cfg.set_value("parts", "next", next_def)
	cfg.save(path)

## A paper kept from when machines were pieces belts ended at: each
## machine's bare A or B square gets a belt the way the belt running into it
## went, and each bare answer square one out to what it handed to (a belt
## leading away, the box, a crate, another machine's A or B, given one too),
## so a kept factory runs on over the machines' layer.
func _adopt() -> void:
	var roots := []
	for i: int in _touched.keys():
		if op[i] != 0 and int(oroot[i]) == i:
			roots.append(i)
	for r: int in roots:
		for c: Array in footprint(int(op[r]), tile_of(r), int(oface[r])):
			var q: Vector2i = c[0]
			if int(kind[_i(q)]) != EMPTY:
				continue
			var intake_sq := int(c[1]) == R_A or int(c[1]) == R_B
			for d in 4:
				var u: Vector2i = q + DIRS[d]
				if not inside(u) or int(oroot[_i(u)]) == r:
					continue
				var ui := _i(u)
				var uk := int(kind[ui])
				if intake_sq:
					if uk == BELT and int(face[ui]) == opp(d):
						_lay_bare(_i(q), opp(d))
						break
					continue
				var f := int(face[ui])
				var leads := uk == BELT and (f == d or (f != opp(d) and belt_at(u - DIRS[f]) == EMPTY))
				var other := op[ui] != 0 and (int(orole[ui]) == R_A or int(orole[ui]) == R_B)
				if leads or uk == BOX or uk == CRATE or other:
					_lay_bare(_i(q), d)
					if other and uk == EMPTY:
						_lay_bare(ui, d)
					break

func _lay_bare(i: int, f: int) -> void:
	_touched[i] = true
	kind[i] = BELT
	face[i] = f
	fork[i] = 0
	prio[i] = 0
	root[i] = -1
	role[i] = R_NONE

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
	# the paper's pieces first, then the machines over them
	var order := []
	var rest := []
	for j in range(0, pieces.size() - 3, 4):
		var k := pieces[j + 1]
		(rest if is_op(k) else order).append(j)
	order.append_array(rest)
	for j: int in order:
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
		if not is_op(k):
			s.face2[i] = clampi(pieces[j + 3], 0, 3)
	var forks: PackedInt32Array = cfg.get_value("paper", "forks", PackedInt32Array()) if fresh else PackedInt32Array()
	for j in range(0, forks.size() - 1, 2):
		var i := forks[j]
		if i >= 0 and i < N and int(s.kind[i]) == BELT:
			s.fork[i] = forks[j + 1] & 15
	var prios: PackedInt32Array = cfg.get_value("paper", "prios", PackedInt32Array()) if fresh else PackedInt32Array()
	for j in range(0, prios.size() - 1, 2):
		var i := prios[j]
		if i >= 0 and i < N and int(s.kind[i]) == BELT:
			s.prio[i] = clampi(prios[j + 1], 0, 8)
	var kept_defs: Dictionary = cfg.get_value("parts", "defs", {})
	for id in kept_defs:
		var d: Dictionary = kept_defs[id]
		if d.has("w") and d.has("h") and d.has("pieces"):
			# a part kept from when parts had ports and copies: its ports go
			s.defs[int(id)] = {"name": String(d.get("name", "%d" % int(id))), "w": int(d.w), "h": int(d.h), "pieces": d.pieces}
	s.next_def = maxi(int(cfg.get_value("parts", "next", 1)), 1)
	for id: int in s.defs:
		s.next_def = maxi(s.next_def, id + 1)
	# copies kept from when they shared their part's inside stay on the
	# paper as plain pieces
	var placed: PackedInt32Array = cfg.get_value("parts", "copies", PackedInt32Array()) if fresh else PackedInt32Array()
	for j in range(0, placed.size() - 2, 3):
		var a := placed[j]
		var id := placed[j + 1]
		var rot := placed[j + 2] & 3
		if a >= 0 and a < N and s.defs.has(id) and s.why_not_part(id, tile_of(a), rot) == "":
			s.stamp_template(s.defs[id], tile_of(a), rot)
	var keys: PackedInt64Array = cfg.get_value("paper", "keys", PackedInt64Array())
	var counts: PackedInt64Array = cfg.get_value("paper", "counts", PackedInt64Array())
	for j in mini(keys.size(), counts.size()):
		s.ledger[int(keys[j])] = int(counts[j])
	if fresh and not bool(cfg.get_value("paper", "layers", false)):
		s._adopt()
	s._wire()
	s._undo = {}
	s.events.clear()
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
