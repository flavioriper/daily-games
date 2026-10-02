extends RefCounted

## Paper Planes' rules, scene-free, as every flat board's are: the board, the
## planes, their lanes, the clouds and the moves. The board
## (puzzles/planes2d.gd) only draws this.
## Spec: docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md,
## sections 3 and 4; docs/superpowers/specs/2026-09-30-paper-planes-polish-
## design.md, sections 1-3.
##
## On Easy, Medium and Hard the one fact the screen was built on still
## holds: **a launch only ever empties cells, so it can never block another
## plane.** A board that can be cleared at all can still be cleared after any
## legal tap, in any order, which is what makes `solve_order()` greedy and
## complete there.
##
## **Insane is Windy Day** (polish spec section 3), and it breaks that fact
## on purpose. The sky has a wind (`wind`, east or west along the rows) and a
## few clouds, one cell each (`clouds`, where they stand at count 0). Every
## launch is one tick of a clock (`count()`): after `k` ticks a cloud stands
## `k` cells downwind of its start, wrapping round the row. A lane is clear
## only when no plane **and no cloud at the current count** stands in it;
## clouds sit over the sky, so a plane's body may be under one. A launch now
## moves the clouds into other planes' lanes, so the order matters and the
## sky can get **stuck** (`stuck()`): nothing can fly and nothing will move
## until a `gust()` blows the clock on one tick without a launch.
##
## **Hard and Insane judge a tap** (`judged`): a tap on a blocked plane is a
## crash and costs a heart. A crash changes nothing here -- `launch()` simply
## refuses -- and the hearts are the board's to count, off `hearts_for`.
## `blocker(i)` / `blocker_cell(i)` say what the plane would bonk its nose on.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const InsaneBank = preload("res://core/insane_bank.gd")

## Per band, Easy .. Insane: the hints a sky starts with, and its hearts (0 is
## a band that cannot be lost). Polish spec section 1.
const HINTS := [3, 3, 1, 0]
const HEARTS := [0, 0, 3, 2]

## What `blocker()` returns when the first thing in a lane is a cloud (a
## plane is its index, a clear lane -1).
const CLOUD := -2

## The bands. **Easy, Medium and Hard are mazes** (2026-10-02, the user's
## second reference: a field packed nearly full of long, bent arrows, where
## the first 16 x 22 sky of short darts read as too easy and not a maze):
## 12 x 17, 16 x 23 and 21 x 30, carved by `_carve_maze` to 0.95-0.98 of the
## field, planes up to `max_len` long, a tail walking straight on with
## `straight` odds, lengths drawn toward the short end by `skew` and the
## gaps then filled by growing tails. The player is down to two launches or
## fewer on about two steps in five (one in five before), with about three
## free at a time. The weights (Insane's row) pick a windy plane's length.
##
## `picks` and `noise` are the tighter carve (polish spec section 2): each
## step draws `picks` legal placements and keeps the one whose body covers
## the most lanes of planes already placed, plus up to `noise` of random
## lift so the skies do not all come out the same. Easy draws fewest and
## shakes most -- it is where the rule is learnt.
##
## Insane is Windy Day: a small sky with `clouds` clouds, planes of three
## cells or more (a two-cell hop leaves the clouds nothing to time), and
## `wind_w` weighting a placement by how often the clouds cross its lane.
## This row is the live fallback's and the miner's (tools/insane/
## planes_ladder.gd); the phone deals Insane from content/insane/planes.json.
const BANDS: Array[Dictionary] = [
	{"cols": 12, "rows": 17, "min_len": 2, "max_len": 15, "maze": true, "skew": 1.3, "straight": 0.6,
		"floor": 0.93, "picks": 3, "noise": 1.5, "tries": 120},
	{"cols": 16, "rows": 23, "min_len": 2, "max_len": 22, "maze": true, "skew": 1.3, "straight": 0.65,
		"floor": 0.93, "picks": 6, "noise": 1.0, "tries": 120},
	{"cols": 21, "rows": 30, "min_len": 2, "max_len": 29, "maze": true, "skew": 1.3, "straight": 0.7,
		"floor": 0.93, "picks": 10, "noise": 0.6, "tries": 120},
	{"cols": 10, "rows": 14, "min_len": 3, "max_len": 7, "weights": [4, 5, 5, 4, 3], "floor": 0.70,
		"picks": 16, "noise": 0.3, "clouds": 8, "wind_w": 1.0},
]
## How many boards to make before keeping the fullest, and how many failed
## placements in a row end a board.
const CANDIDATES := 6
const TRIES := 400
## A carve step stops drawing after `picks * DRAWS_A_PICK` draws and lays the
## best it has: late in a carve most draws fail, and waiting for a full
## `picks` there costs time without tightening anything.
const DRAWS_A_PICK := 4
## A Windy Day sky's planes fit one 64-bit launched-set mask (the exact
## search in `analyse()` and `_search()`).
const MAX_WINDY_PLANES := 62

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

## The hints a band starts with.
static func hints_for(b: int) -> int:
	return int(HINTS[clampi(b, 0, HINTS.size() - 1)])

## The hearts a band starts with; 0 is a band that cannot be lost.
static func hearts_for(b: int) -> int:
	return int(HEARTS[clampi(b, 0, HEARTS.size() - 1)])

var rows := 0
var cols := 0
var planes: Array[Dictionary] = []
## The launch order the sky was built for (front first). On a Windy Day sky
## it is the one order the phone knows replays to an empty sky.
var order: Array[int] = []
## 0 Easy .. 3 Insane.
var difficulty := 0
## A tap on a blocked plane is a crash (Hard and Insane).
var judged := false
## Undo is offered (not on Insane: a plane in the wind never comes back).
var undo_allowed := true
## Windy Day: the wind along the rows, (1, 0) east or (-1, 0) west, and the
## clouds' cells at count 0. Vector2i.ZERO and [] on every other sky.
var wind := Vector2i.ZERO
var clouds: Array[Vector2i] = []
## Ticks blown by `gust()` since the deal (or the last reset).
var gusts := 0
## Whether this Insane sky came off the bank rather than the live fallback.
var banked := false
var _occupant: Dictionary = {}   # Vector2i -> plane index, planes still on the board
var _history: Array[int] = []
## The carve's book: cell -> the planes already placed whose lane crosses it.
var _lanes: Dictionary = {}
## The carve's clouds, where they stand when the last plane has flown (the
## carve places planes in reverse launch order, so it counts back from the
## end); `carve()` turns them into `clouds` once the plane count is known.
var _cloud_end: Array[Vector2i] = []
## The maze carve's launch keys, one a plane (highest launches first), and
## its book of lanes: cell index (y * cols + x) -> the planes whose lane
## crosses it.
var _keys: Array[float] = []
var _lane_book: Array = []

func clear_occupancy() -> void:
	_occupant = {}
	_history = []
	gusts = 0

## Lays one plane on the board. `cells` runs tail to head; the direction is
## the step into the head, so a plane's heading is a property of its shape
## and never a second field to keep in step. That derivation is why **a
## plane is never shorter than two cells**: a single cell has no last step
## and so no heading, which is also why every band's `min_len` is 2 or more.
## A shorter body is refused rather than given a zero direction, because a
## zero direction never advances -- `lane()` would loop on it forever.
func add_plane(cells: Array[Vector2i]) -> int:
	if cells.size() < 2:
		push_error("PlanesState.add_plane: a plane needs at least two cells to have a heading")
		return -1
	var head: Vector2i = cells[cells.size() - 1]
	var dir: Vector2i = head - cells[cells.size() - 2]
	var idx := planes.size()
	planes.append({"cells": cells, "dir": dir, "gone": false})
	for c in cells:
		_occupant[c] = idx
	return idx

func in_board(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func plane_at(cell: Vector2i) -> int:
	return int(_occupant.get(cell, -1))

## Whether this is a Windy Day sky.
func windy() -> bool:
	return wind != Vector2i.ZERO

## The clock: launches plus gusts since the deal.
func count() -> int:
	return _history.size() + gusts

## Where the clouds stand at `at_count` (the current count when negative),
## in the order of `clouds`. After the next launch: `cloud_cells(count() + 1)`.
func cloud_cells(at_count := -1) -> Array[Vector2i]:
	var k := count() if at_count < 0 else at_count
	var out: Array[Vector2i] = []
	for c in clouds:
		out.append(Vector2i(posmod(c.x + wind.x * k, cols), c.y))
	return out

## Whether a cloud stands on `cell` at `at_count` (the current count when
## negative).
func cloud_at(cell: Vector2i, at_count := -1) -> bool:
	if clouds.is_empty():
		return false
	return cloud_cells(at_count).has(cell)

## Every cell beyond the head, in the dart's direction, out to the edge.
func lane(i: int) -> Array[Vector2i]:
	var p: Dictionary = planes[i]
	var cells: Array[Vector2i] = p["cells"]
	var dir: Vector2i = p["dir"]
	var out: Array[Vector2i] = []
	var at: Vector2i = cells[cells.size() - 1] + dir
	while in_board(at):
		out.append(at)
		at += dir
	return out

## The first thing standing in the lane: a plane's index, CLOUD when a cloud
## at the current count comes first, or -1 when the lane is clear.
func blocker(i: int) -> int:
	var here := _cloud_set(count())
	for c in lane(i):
		if here.has(c):
			return CLOUD
		var who := plane_at(c)
		if who != -1:
			return who
	return -1

## The cell of that first thing (where a crashing plane bonks its nose), or
## (-1, -1) when the lane is clear.
func blocker_cell(i: int) -> Vector2i:
	var here := _cloud_set(count())
	for c in lane(i):
		if here.has(c) or plane_at(c) != -1:
			return c
	return Vector2i(-1, -1)

## The planes left whose lane a cloud crosses at the current count (whether
## or not a plane stands nearer): what the clouds are holding up right now.
func cloud_blocked() -> Array[int]:
	var out: Array[int] = []
	if clouds.is_empty():
		return out
	var here := _cloud_set(count())
	for i in planes.size():
		if planes[i]["gone"]:
			continue
		for c in lane(i):
			if here.has(c):
				out.append(i)
				break
	return out

func is_free(i: int) -> bool:
	return not planes[i]["gone"] and blocker(i) == -1

func free_planes() -> Array[int]:
	var out: Array[int] = []
	for i in planes.size():
		if is_free(i):
			out.append(i)
	return out

## A tap on a blocked plane (a crash on a judged sky) changes nothing and
## answers false; the board spends the heart.
func launch(i: int) -> bool:
	if planes[i]["gone"] or not is_free(i):
		return false
	planes[i]["gone"] = true
	for c in planes[i]["cells"]:
		_occupant.erase(c)
	_history.append(i)
	return true

## Planes are left and none can fly. Only a Windy Day sky can get here.
func stuck() -> bool:
	return not solved() and free_planes().is_empty()

## Blows the wind on one tick without a launch -- only when the sky is stuck
## (a cloud tap does nothing otherwise). The board spends the heart.
func gust() -> bool:
	if not windy() or not stuck():
		return false
	gusts += 1
	return true

## Calls the last launch back. The clock goes back with it: a sky is its set
## of launched planes and its count, and undoing the last launch leaves
## exactly the set and count it was launched from, gusts or not. The board
## offers it only when `undo_allowed`; its Reset uses it on every band.
func undo() -> int:
	if _history.is_empty():
		return -1
	var i: int = _history.pop_back()
	planes[i]["gone"] = false
	for c in planes[i]["cells"]:
		_occupant[c] = i
	return i

## Every plane back, and the clock back to 0.
func reset() -> void:
	for i in planes.size():
		if planes[i]["gone"]:
			planes[i]["gone"] = false
			for c in planes[i]["cells"]:
				_occupant[c] = i
	_history = []
	gusts = 0

func left() -> int:
	var n := 0
	for p in planes:
		if not p["gone"]:
			n += 1
	return n

func solved() -> bool:
	return left() == 0

## An order that clears the planes left, from the sky as it stands, or []
## when there is none. Without clouds it is greedy and complete (a launch
## only empties cells). On a Windy Day sky it is the exact search, taking no
## gusts; from the deal it is the stored `order`, which is known to replay.
func solve_order() -> Array[int]:
	if windy():
		if _history.is_empty() and gusts == 0 and order.size() == planes.size():
			return order.duplicate()
		return _search(-1)
	var gone := {}
	var out: Array[int] = []
	var total := left()
	while out.size() < total:
		var moved := false
		for i in planes.size():
			if planes[i]["gone"] or gone.has(i):
				continue
			var clear := true
			for c in lane(i):
				var who := plane_at(c)
				if who != -1 and not gone.has(who):
					clear = false
					break
			if clear:
				gone[i] = true
				out.append(i)
				moved = true
		if not moved:
			return []
	return out

## The hint's pick: a plane that can go. Without clouds, the first plane of
## the generator's own order still here and free, else any free one. On a
## Windy Day sky, the first launch of an order the exact search finds from
## here (it gives up after a budget and names any free plane).
func hint_plane() -> int:
	if windy():
		var way := _search(200000)
		if not way.is_empty():
			return way[0]
	else:
		for i in order:
			if not planes[i]["gone"] and is_free(i):
				return i
	var free := free_planes()
	return -1 if free.is_empty() else free[0]

## Deals the sky for `difficulty`. Easy, Medium and Hard are carved live;
## Insane is a Windy Day sky off the bank (`bank_step` is PuzzleBase's, how
## many times New has been pressed since the board opened), or, when the bank
## is empty or its entry does not hold together, a live Windy Day sky built
## with its clock and replayed.
func build(rng: RandomNumberGenerator, p_difficulty: int, bank_step := 0) -> void:
	difficulty = clampi(p_difficulty, 0, BANDS.size() - 1)
	banked = false
	if difficulty == 3:
		if from_bank(InsaneBank.pick("planes", bank_step)):
			banked = true
		elif InsaneBank.size("planes") > 0:
			push_warning("Paper Planes: a banked Windy Day sky did not hold together; building a live one")
	if not banked:
		carve(rng, difficulty)
	judged = hearts_for(difficulty) > 0
	undo_allowed = difficulty < 3

## Carves a board backwards out of an empty sky (the flat spec's section 5).
## Up to CANDIDATES attempts are carved and thrown away except the winner:
## the first at or above the band's coverage floor, else the fullest one
## made. `order` is set to the reverse of the winner's placement order --
## planes placed later are launched earlier, so `hint_plane()` walks it front
## to back -- and the result is asserted to replay, which the construction
## guarantees: each plane's lane was clear of every plane placed before it
## (those launch after it) and, on a Windy Day sky, of every cloud at the
## count it launches on. There is deliberately no runtime fallback: the
## invariant cannot fail by construction. `knobs`, when given, overrides the
## band's row key by key (the miner's and the probes' way to try a size).
func carve(rng: RandomNumberGenerator, p_difficulty: int, knobs := {}) -> void:
	difficulty = clampi(p_difficulty, 0, BANDS.size() - 1)
	var b := band(difficulty).duplicate()
	b.merge(knobs, true)
	rows = int(b["rows"])
	cols = int(b["cols"])
	planes = []
	order = []
	wind = Vector2i.ZERO
	clouds = []
	clear_occupancy()
	var area := float(rows * cols)
	var floor_cov: float = float(b["floor"])
	var best_planes: Array[Dictionary] = []
	var best_occupant: Dictionary = {}
	var best_cov := -1.0
	var best_wind := Vector2i.ZERO
	var best_end: Array[Vector2i] = []
	var best_keys: Array = []
	var n_clouds := int(b.get("clouds", 0))
	for attempt in CANDIDATES:
		planes = []
		clear_occupancy()
		_cloud_end = []
		wind = Vector2i.ZERO
		if n_clouds > 0:
			wind = Vector2i(1, 0) if rng.randi_range(0, 1) == 0 else Vector2i(-1, 0)
			_cloud_end = _pick_clouds(rng, n_clouds)
		if bool(b.get("maze", false)):
			_carve_maze(rng, b)
		else:
			_carve(rng, b)
		var cov := float(_occupant.size()) / area
		if cov > best_cov:
			best_cov = cov
			best_planes = planes.duplicate(true)
			best_occupant = _occupant.duplicate()
			best_wind = wind
			best_end = _cloud_end.duplicate()
			best_keys = _keys.duplicate()
		if cov >= floor_cov:
			break
	planes = best_planes
	_occupant = best_occupant
	wind = best_wind
	clouds = []
	# The carve counted the clouds back from the end; the deal counts them
	# forward from 0, `planes.size()` launches before the end.
	for e in best_end:
		clouds.append(Vector2i(posmod(e.x - wind.x * planes.size(), cols), e.y))
	_cloud_end = []
	_lanes = {}
	if bool(b.get("maze", false)):
		# The maze's launch order is its keys', highest first.
		var by_key: Array = []
		for i in planes.size():
			by_key.append(i)
		var keys: Array = best_keys
		by_key.sort_custom(func(x, y): return float(keys[x]) > float(keys[y]))
		for i in by_key:
			order.append(int(i))
	else:
		for i in range(planes.size() - 1, -1, -1):
			order.append(i)
	# Called inside the assert itself so a release export strips the work.
	assert(replays(order), "PlanesState.carve: the generated sky must replay to empty")

## Whether launching `seq` from the deal clears the sky, every launch legal
## at its count. Puts every plane back afterwards (a reset), so it is for a
## sky being dealt, not one being played.
func replays(seq: Array) -> bool:
	reset()
	var ok := seq.size() == planes.size()
	if ok:
		for i in seq:
			if typeof(i) != TYPE_INT or i < 0 or i >= planes.size() or not launch(i):
				ok = false
				break
	ok = ok and solved()
	reset()
	return ok

## `n` distinct cloud cells, never more than two in a row of the sky so the
## clouds spread over it.
func _pick_clouds(rng: RandomNumberGenerator, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var per_row := {}
	var guard := 0
	while out.size() < n and guard < 1000:
		guard += 1
		var c := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if out.has(c) or int(per_row.get(c.y, 0)) >= 2:
			continue
		per_row[c.y] = int(per_row.get(c.y, 0)) + 1
		out.append(c)
	return out

## Where the carve's clouds stand when plane number `j` of the carve (0 the
## first placed, the last to launch) takes off: `j + 1` ticks before the end.
func _clouds_for(j: int) -> Dictionary:
	var out := {}
	for e in _cloud_end:
		out[Vector2i(posmod(e.x - wind.x * (j + 1), cols), e.y)] = true
	return out

## The clouds at count `k` as a set.
func _cloud_set(k: int) -> Dictionary:
	var out := {}
	for c in clouds:
		out[Vector2i(posmod(c.x + wind.x * k, cols), c.y)] = true
	return out

## One candidate, laid straight onto `self`. Loops while coverage is under
## 95% and no run of TRIES failed draws has ended it. Each step draws up to
## the band's `picks` legal placements (`_propose`) and lays the best by
## `_score` -- the tighter carve of the polish spec's section 2.
func _carve(rng: RandomNumberGenerator, b: Dictionary) -> void:
	var area := float(rows * cols)
	var picks := int(b.get("picks", 1))
	var noise := float(b.get("noise", 0.0))
	var wind_w := float(b.get("wind_w", 0.0))
	var fails := 0
	_lanes = {}
	while float(_occupant.size()) < 0.95 * area and fails < TRIES:
		var clouds_now := _clouds_for(planes.size())
		var best: Array[Vector2i] = []
		var best_score := -INF
		var got := 0
		var draws := 0
		while got < picks and fails < TRIES and draws < picks * DRAWS_A_PICK:
			draws += 1
			var body := _propose(rng, b, clouds_now)
			if body.is_empty():
				fails += 1
				continue
			got += 1
			var sc := _score(body, wind_w) + rng.randf() * noise
			if sc > best_score:
				best_score = sc
				best = body
		if best.is_empty():
			continue
		var idx := add_plane(best)
		for c in lane(idx):
			if not _lanes.has(c):
				_lanes[c] = []
			(_lanes[c] as Array).append(idx)
		fails = 0

## The maze carve (2026-10-02). The backward carve can only put a new plane
## at the front of the launch order, so once the sky fills every leftover
## cell sits in some lane and the field stalls at 0.7-0.8. Here a plane
## carries a **key** instead, highest first to fly, and a new plane may go
## anywhere in the order it fits: after every plane in its own lane (they
## must have flown, `hi`) and before every plane whose lane crosses its body
## (they wait for it, `lo`) -- it fits when `lo < hi`, and takes a key
## between. That is the whole proof the sky replays: launched by key, each
## plane finds its lane already emptied. The carve lays the band's best of
## `picks` draws until `tries` draws in a row fail, then offers every empty
## cell as a head, then grows tails into what is left.
func _carve_maze(rng: RandomNumberGenerator, b: Dictionary) -> void:
	_keys = []
	_lane_book = []
	_lane_book.resize(rows * cols)
	for k in rows * cols:
		_lane_book[k] = []
	var picks := int(b.get("picks", 1))
	var noise := float(b.get("noise", 0.0))
	var tries := int(b.get("tries", 120))
	var max_len := int(b["max_len"])
	var fails := 0
	while fails < tries:
		var best: Dictionary = {}
		var best_score := -INF
		var got := 0
		var draws := 0
		while got < picks and draws < picks * DRAWS_A_PICK:
			draws += 1
			var p := _propose_maze(rng, b, Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1)))
			if p.is_empty():
				continue
			got += 1
			var sc := _waits(p) + rng.randf() * noise + 0.05 * float((p["cells"] as Array).size())
			if sc > best_score:
				best_score = sc
				best = p
		if best.is_empty():
			fails += 1
			continue
		_lay_maze(best)
		fails = 0
	for pass_ in 3:
		for y in rows:
			for x in cols:
				if not _occupant.has(Vector2i(x, y)):
					var p := _propose_maze(rng, b, Vector2i(x, y))
					if not p.is_empty():
						_lay_maze(p)
	# The last of the gaps: a tail grows into an empty neighbour that no
	# lane of a plane flying after it crosses, and not into its own lane.
	var grew := true
	while grew:
		grew = false
		for i in planes.size():
			var cells: Array[Vector2i] = planes[i]["cells"]
			var mine := {}
			for c in lane(i):
				mine[c] = true
			while cells.size() < max_len:
				var tail: Vector2i = cells[0]
				var opts: Array[Vector2i] = []
				for e in DIRS:
					var q: Vector2i = tail + e
					if in_board(q) and not _occupant.has(q) and not mine.has(q) \
							and _lane_top(q) < _keys[i]:
						opts.append(q)
				if opts.is_empty():
					break
				var q: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
				cells.insert(0, q)
				_occupant[q] = i
				grew = true

## The highest key among the planes whose lane crosses `c` (-INF for none).
func _lane_top(c: Vector2i) -> float:
	var top := -INF
	for o in _lane_book[c.y * cols + c.x]:
		top = maxf(top, _keys[o])
	return top

## One maze placement with its head at `head`, or {}: {"cells" tail to
## head, "dir", "lane", "lo", "hi"}. The four directions in a random order;
## for the first whose lane and body fit (`lo < hi`), a tail walked
## backwards that goes straight on with the band's odds, never into the lane,
## itself or a cell whose lanes' planes would have to fly after it.
func _propose_maze(rng: RandomNumberGenerator, b: Dictionary, head: Vector2i) -> Dictionary:
	if _occupant.has(head):
		return {}
	var min_len := int(b["min_len"])
	var straight := float(b.get("straight", 0.5))
	var dirs: Array[Vector2i] = DIRS.duplicate()
	_shuffle_dirs(dirs, rng)
	for d in dirs:
		var lane_cells: Array[Vector2i] = []
		var lane_set := {}
		var hi := INF
		var at: Vector2i = head + d
		while in_board(at):
			lane_cells.append(at)
			lane_set[at] = true
			if _occupant.has(at):
				hi = minf(hi, _keys[int(_occupant[at])])
			at += d
		var lo := _lane_top(head)
		if lo >= hi:
			continue
		var prev: Vector2i = head - d
		if not in_board(prev) or _occupant.has(prev) or lane_set.has(prev):
			continue
		lo = maxf(lo, _lane_top(prev))
		if lo >= hi:
			continue
		var want := min_len + int(floorf(pow(rng.randf(), float(b.get("skew", 1.0)))
			* float(int(b["max_len"]) - min_len + 1)))
		var body: Array[Vector2i] = [head, prev]
		var used := {head: true, prev: true}
		var way: Vector2i = -d
		while body.size() < want:
			var last: Vector2i = body[body.size() - 1]
			var cand: Array[Vector2i] = []
			var ahead := false
			for e in DIRS:
				var q: Vector2i = last + e
				if not in_board(q) or _occupant.has(q) or used.has(q) or lane_set.has(q):
					continue
				if _lane_top(q) >= hi:
					continue
				cand.append(e)
				if e == way:
					ahead = true
			if cand.is_empty():
				break
			var e: Vector2i = way
			if not ahead or rng.randf() > straight:
				e = cand[rng.randi_range(0, cand.size() - 1)]
			way = e
			var q: Vector2i = last + e
			body.append(q)
			used[q] = true
			lo = maxf(lo, _lane_top(q))
		if body.size() < min_len:
			continue
		body.reverse()
		return {"cells": body, "dir": d, "lane": lane_cells, "lo": lo, "hi": hi}
	return {}

## How many planes this placement would be tied to: those whose lane its
## body crosses and those standing in its own lane. The carve keeps the
## best tied of its draws, which is what makes the maze a maze.
func _waits(p: Dictionary) -> float:
	var tied := {}
	for c in p["cells"]:
		for o in _lane_book[c.y * cols + c.x]:
			tied[o] = true
	for c in p["lane"]:
		if _occupant.has(c):
			tied[_occupant[c]] = true
	return float(tied.size())

## Lays a maze placement with a key between its bounds, then renumbers the
## keys to their ranks so the gaps never run out of halves.
func _lay_maze(p: Dictionary) -> void:
	var lo: float = p["lo"]
	var hi: float = p["hi"]
	var key := 0.0
	if lo == -INF and hi == INF:
		key = 0.0
	elif lo == -INF:
		key = hi - 1.0
	elif hi == INF:
		key = lo + 1.0
	else:
		key = (lo + hi) * 0.5
	var idx := add_plane(p["cells"])
	_keys.append(key)
	for c in p["lane"]:
		(_lane_book[c.y * cols + c.x] as Array).append(idx)
	var by: Array = range(_keys.size())
	by.sort_custom(func(x, y): return _keys[x] < _keys[y])
	for r in by.size():
		_keys[by[r]] = float(r)

## How many planes already placed would wait on this body (their lanes cross
## it), plus, on a Windy Day sky, `wind_w` times the share of the clouds'
## cycle during which a cloud stands in this plane's own lane -- a plane the
## clouds cross often is one whose moment has to be picked.
func _score(body: Array[Vector2i], wind_w: float) -> float:
	var owners := {}
	for c in body:
		if _lanes.has(c):
			for o in _lanes[c]:
				owners[o] = true
	var sc := float(owners.size())
	if wind_w > 0.0 and not _cloud_end.is_empty():
		var head: Vector2i = body[body.size() - 1]
		var dir: Vector2i = head - body[body.size() - 2]
		var lane_set := {}
		var at := head + dir
		while in_board(at):
			lane_set[at] = true
			at += dir
		var hit := 0
		for k in cols:
			for e in _cloud_end:
				if lane_set.has(Vector2i(posmod(e.x + k, cols), e.y)):
					hit += 1
					break
		sc += wind_w * float(hit) / float(cols)
	return sc

## One legal placement, tail to head, or [] when this draw failed: a random
## empty cell as the head, the four directions shuffled, and for the first
## whose lane runs clear to the edge (of planes, and of the clouds at this
## plane's launch count) a self-avoiding tail grown backwards to a length
## drawn from the band's weights, never crossing the lane or itself. A body
## short of the band's min_len is a failed draw.
func _propose(rng: RandomNumberGenerator, b: Dictionary, clouds_now: Dictionary) -> Array[Vector2i]:
	var min_len: int = int(b["min_len"])
	var none: Array[Vector2i] = []
	var cell := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
	if _occupant.has(cell):
		return none
	var dirs: Array[Vector2i] = DIRS.duplicate()
	_shuffle_dirs(dirs, rng)
	for d in dirs:
		var lane_set := {}
		var at: Vector2i = cell + d
		var clear := true
		while in_board(at):
			if _occupant.has(at) or clouds_now.has(at):
				clear = false
				break
			lane_set[at] = true
			at += d
		if not clear:
			continue
		var body: Array[Vector2i] = [cell]
		var used := {cell: true}
		var want := _pick_length(rng, b)
		var prev: Vector2i = cell - d
		if not in_board(prev) or _occupant.has(prev) or lane_set.has(prev):
			continue
		body.append(prev)
		used[prev] = true
		while body.size() < want:
			var last: Vector2i = body[body.size() - 1]
			var cand: Array[Vector2i] = []
			for e in DIRS:
				var q: Vector2i = last + e
				if not in_board(q):
					continue
				if _occupant.has(q) or used.has(q) or lane_set.has(q):
					continue
				cand.append(q)
			if cand.is_empty():
				break
			var pick: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]
			body.append(pick)
			used[pick] = true
		if body.size() < min_len:
			continue
		body.reverse()
		return body
	return none

## Weighted by `b["weights"]`, index `len - min_len` -- the middle lengths
## are the common ones (see BANDS above).
static func _pick_length(rng: RandomNumberGenerator, b: Dictionary) -> int:
	var weights: Array = b["weights"]
	var min_len: int = int(b["min_len"])
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if r < acc:
			return min_len + i
	return min_len + weights.size() - 1

## Fisher-Yates, seeded only by `rng` -- same shape as mushroom_gen.gd's.
static func _shuffle_dirs(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# --- the bank ---

## This sky as a bank entry: {"cols", "rows", "wind" (1 east, -1 west),
## "clouds" (cell indices y * cols + x at count 0), "planes" (each an array
## of cell indices, tail to head), "order" (the launch order that replays)}.
func to_bank() -> Dictionary:
	var ps: Array = []
	for p in planes:
		var cells: Array = []
		for c in p["cells"]:
			cells.append(c.y * cols + c.x)
		ps.append(cells)
	var cs: Array = []
	for c in clouds:
		cs.append(c.y * cols + c.x)
	return {"cols": cols, "rows": rows, "wind": wind.x, "clouds": cs, "planes": ps, "order": order.duplicate()}

## Deals a banked Windy Day sky onto `self`, or answers false and leaves an
## empty sky. The phone checks the entry holds together -- planes in bounds,
## each a walk of at least two cells one step at a time, not standing in its
## own lane, no two sharing a cell, clouds in bounds and distinct, the wind
## east or west, and the stored order replaying to an empty sky -- and trusts
## the miner for the rest (the gate is not re-run on the phone).
func from_bank(entry: Dictionary) -> bool:
	planes = []
	order = []
	clouds = []
	wind = Vector2i.ZERO
	rows = 0
	cols = 0
	clear_occupancy()
	if entry.is_empty() or not _is_num(entry.get("cols")) or not _is_num(entry.get("rows")) \
			or not _is_num(entry.get("wind")) or not (entry.get("clouds") is Array) \
			or not (entry.get("planes") is Array) or not (entry.get("order") is Array):
		return false
	var c := int(entry.cols)
	var r := int(entry.rows)
	var w := int(entry.wind)
	var ps: Array = entry.planes
	var ok := c >= 3 and r >= 3 and c <= 32 and r <= 32 and (w == 1 or w == -1) \
		and not ps.is_empty() and ps.size() <= MAX_WINDY_PLANES
	if ok:
		cols = c
		rows = r
	for raw in ps:
		if not ok:
			break
		if not (raw is Array) or raw.size() < 2:
			ok = false
			break
		var cells: Array[Vector2i] = []
		for v in raw:
			if not _is_num(v) or int(v) < 0 or int(v) >= c * r:
				ok = false
				break
			var cell := Vector2i(int(v) % c, int(v) / c)
			if _occupant.has(cell) or cells.has(cell):
				ok = false
				break
			if not cells.is_empty():
				var step: Vector2i = cell - cells[cells.size() - 1]
				if absi(step.x) + absi(step.y) != 1:
					ok = false
					break
			cells.append(cell)
		if not ok:
			break
		var idx := add_plane(cells)
		for q in lane(idx):
			if cells.has(q):
				ok = false
				break
	if ok:
		for v in entry.clouds:
			if not _is_num(v) or int(v) < 0 or int(v) >= c * r:
				ok = false
				break
			var cell := Vector2i(int(v) % c, int(v) / c)
			if clouds.has(cell):
				ok = false
				break
			clouds.append(cell)
		ok = ok and not clouds.is_empty()
	if ok:
		wind = Vector2i(w, 0)
		for v in entry.order:
			if not _is_num(v):
				ok = false
				break
			order.append(int(v))
		var seen := {}
		for i in order:
			seen[i] = true
		ok = ok and seen.size() == planes.size() and replays(order)
	if not ok:
		planes = []
		order = []
		clouds = []
		wind = Vector2i.ZERO
		rows = 0
		cols = 0
		clear_occupancy()
	return ok

static func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

# --- the exact search (Windy Day) ---
#
# A Windy Day sky is its launched set and its count, and with no gusts the
# count is the set's size -- so the skies reachable from the deal are sets of
# launched planes, one bit a plane in a 64-bit int. Planes' bodies never
# move, so which planes stand in a lane is one mask a plane (`lane_mask`);
# the clouds come back every `cols` ticks, so whether a cloud crosses a lane
# is one byte a plane per tick of that cycle (`cloud_block`).

## The search's tables for this sky: {"n", "lane_mask": PackedInt64Array,
## "cloud_block": Array of PackedByteArray (one a plane, `cols` long, 1 when
## a cloud stands in the lane at a count of that residue)}. They describe
## the deal, whatever has flown since.
func tables() -> Dictionary:
	var n := planes.size()
	var owner := {}
	for j in n:
		for c in planes[j]["cells"]:
			owner[c] = j
	var phases: Array = []
	for k in cols:
		phases.append(_cloud_set(k))
	var lane_mask := PackedInt64Array()
	lane_mask.resize(n)
	var cloud_block: Array = []
	for i in n:
		var m := 0
		var cb := PackedByteArray()
		cb.resize(cols)
		cb.fill(0)
		for c in lane(i):
			if owner.has(c):
				m |= 1 << int(owner[c])
			for k in cols:
				if (phases[k] as Dictionary).has(c):
					cb[k] = 1
		lane_mask[i] = m
		cloud_block.append(cb)
	return {"n": n, "lane_mask": lane_mask, "cloud_block": cloud_block}

## The launched set as a mask.
func launched_mask() -> int:
	var m := 0
	for i in planes.size():
		if planes[i]["gone"]:
			m |= 1 << i
	return m

## An order clearing the planes left from the sky as it stands (no gusts),
## by depth-first search remembering the sets that dead-end; [] when there is
## none, or when `budget` sets (>= 0) have been met without finding one.
func _search(budget: int) -> Array[int]:
	var out: Array[int] = []
	if planes.size() > MAX_WINDY_PLANES or solved():
		return out
	var ctx := {"t": tables(), "dead": {}, "budget": budget, "met": 0, "phase0": gusts}
	var path: Array[int] = []
	if _dfs(ctx, launched_mask(), path):
		out = path
	return out

func _dfs(ctx: Dictionary, mask: int, path: Array[int]) -> bool:
	var t: Dictionary = ctx.t
	var n: int = t.n
	if mask == (1 << n) - 1:
		return true
	if (ctx.dead as Dictionary).has(mask):
		return false
	ctx.met = int(ctx.met) + 1
	if int(ctx.budget) >= 0 and int(ctx.met) > int(ctx.budget):
		return false
	var k := (_popcount(mask) + int(ctx.phase0)) % cols
	var lm: PackedInt64Array = t.lane_mask
	var cb: Array = t.cloud_block
	for i in n:
		var bit := 1 << i
		if mask & bit != 0 or lm[i] & ~mask != 0 or (cb[i] as PackedByteArray)[k] != 0:
			continue
		path.append(i)
		if _dfs(ctx, mask | bit, path):
			return true
		path.pop_back()
	(ctx.dead as Dictionary)[mask] = true
	return false

static func _popcount(m: int) -> int:
	var c := 0
	while m != 0:
		m &= m - 1
		c += 1
	return c

## The miner's reading of a Windy Day sky from the deal, over every set of
## launched planes reachable without a gust: {"ok" (false when more than
## `budget` sets were reachable), "states" (sets reached), "dead" (sets with
## planes left and no launch: stuck), "doomed" (sets from which the sky
## cannot be cleared), "p" (the exact chance a random legal playout -- each
## launch picked evenly among the free planes -- clears the sky without
## getting stuck), "ways" (how many launch orders clear it)}.
func analyse(budget: int) -> Dictionary:
	if planes.size() > MAX_WINDY_PLANES:
		return {"ok": false}
	var ctx := {"t": tables(), "p": {}, "w": {}, "budget": budget, "over": false, "dead": 0, "doomed": 0}
	var p := _analyse(ctx, 0, 0)
	var w: float = (ctx.w as Dictionary).get(0, 0.0)
	return {"ok": not bool(ctx.over), "states": (ctx.p as Dictionary).size(), "dead": int(ctx.dead),
		"doomed": int(ctx.doomed), "p": p, "ways": w}

func _analyse(ctx: Dictionary, mask: int, k: int) -> float:
	var memo: Dictionary = ctx.p
	if memo.has(mask):
		return memo[mask]
	var t: Dictionary = ctx.t
	var n: int = t.n
	if k == n:
		memo[mask] = 1.0
		(ctx.w as Dictionary)[mask] = 1.0
		return 1.0
	if bool(ctx.over) or memo.size() >= int(ctx.budget):
		ctx.over = true
		return 0.0
	var lm: PackedInt64Array = t.lane_mask
	var cb: Array = t.cloud_block
	var ph := k % cols
	var moves := 0
	var sum := 0.0
	var ways := 0.0
	for i in n:
		var bit := 1 << i
		if mask & bit != 0 or lm[i] & ~mask != 0 or (cb[i] as PackedByteArray)[ph] != 0:
			continue
		moves += 1
		sum += _analyse(ctx, mask | bit, k + 1)
		ways += float((ctx.w as Dictionary).get(mask | bit, 0.0))
	var p := sum / float(moves) if moves > 0 else 0.0
	if moves == 0:
		ctx.dead = int(ctx.dead) + 1
	if p == 0.0:
		ctx.doomed = int(ctx.doomed) + 1
	memo[mask] = p
	(ctx.w as Dictionary)[mask] = ways
	return p

## Whether launching the first free plane in reading order of the heads
## (top row first), again and again, gets the sky stuck. Puts every plane
## back afterwards.
func greedy_stuck() -> bool:
	reset()
	var by_head: Array = range(planes.size())
	by_head.sort_custom(func(a: int, b: int) -> bool:
		var ha: Vector2i = (planes[a]["cells"] as Array).back()
		var hb: Vector2i = (planes[b]["cells"] as Array).back()
		return ha.y < hb.y or (ha.y == hb.y and ha.x < hb.x))
	var stuck_out := false
	while not solved():
		var moved := false
		for i in by_head:
			if is_free(i):
				launch(i)
				moved = true
				break
		if not moved:
			stuck_out = true
			break
	reset()
	return stuck_out
