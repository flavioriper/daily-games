extends RefCounted

## Super Slider's rules, scene-free, as every flat board's are. The board
## (puzzles/slider2d.gd) draws this and nothing else.
##
## A four-by-five tray, a big block, bars and squares, and a gate in the
## middle of the bottom edge. The one move is sliding a block through the
## empty cells, any distance and round corners, never lifting it over
## another; the day is done when the big block stands in the gate.
## **Nothing wrong can sit in the tray**, so there is no Check -- only Undo,
## Reset and Hint.
##
## Each block keeps an index for the whole day, so the board can draw and
## animate it; the rules themselves only ever look at the key
## (slider_gen.gd), where two bars of a shape are the same bar.

const Gen = preload("res://puzzles/slider_gen.gd")

## [anchor code, anchor cell] per block, in the opening's cell order.
var blocks: Array = []
var start_blocks: Array = []
var key := 0
var start_key := 0
## The shortest way out of the opening, in moves.
var par := 0
var band := 0
## Every arrangement before a move, for Undo.
var history: Array = []

## The graph's distances, filled on a worker thread (see `solve_async`) into
## a box the task holds its own reference to, so a tray closed mid-run frees
## nothing the worker is still writing.
var _box := {}
var _task := -1
## Every task started and not yet waited for, across trays: WorkerThreadPool
## keeps a task's record until it is waited for, and a closed tray does not
## wait (its run is told to stop and is collected here once it has).
static var _pending: Array = []

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var d := Gen.deal(rng, difficulty)
	start_key = d.start
	par = d.par
	band = d.band
	blocks = Gen.blocks(start_key)
	start_blocks = blocks.duplicate(true)
	key = start_key
	history.clear()
	solve_async()

## Starts the one breadth-first run a day's hints read, on a worker thread so
## the tray opens at once. Moves reverse, so the opening's graph is every
## position the day can reach.
func solve_async() -> void:
	abandon()
	for id: int in _pending.duplicate():
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_pending.erase(id)
	# The solver's tables are built here, on this thread, so the worker and a
	# drag never race to build them.
	Gen._fast_tables()
	# Both keys exist before the worker starts, so neither side ever adds one
	# to a Dictionary the other is reading.
	_box = {"r": {}, "stop": false}
	_task = _start(start_key, _box)
	_pending.append(_task)

## The task, from a static function so the lambda holds no tray at all.
static func _start(from: int, box: Dictionary) -> int:
	return WorkerThreadPool.add_task(func(): box["r"] = Gen.distances(from, 0, box))

## Waits for the worker, if one is running.
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_pending.erase(_task)
		_task = -1

## Tells a running worker to give up and forgets it without waiting. The
## board calls it as it leaves, so closing a tray never waits on a search.
func abandon() -> void:
	if _task >= 0:
		_box["stop"] = true
		_task = -1

## The distances, waiting for the worker if it has not finished.
func dist_table() -> Dictionary:
	finish()
	return _box.get("r", {}) if not _box.get("stop", false) else {}

func solver_ready() -> bool:
	return _task < 0 or WorkerThreadPool.is_task_completed(_task)

## Puts the blocks as a key says, with no history: a reopened day's end.
func restore_key(k: int) -> void:
	history.clear()
	_restore(Gen.blocks(k))

func size_of(p: int) -> Vector2i:
	return Gen.SIZE[int(blocks[p][0])]

func kind(p: int) -> int:
	return int(blocks[p][0])

func at(p: int) -> int:
	return int(blocks[p][1])

func big() -> int:
	for p in blocks.size():
		if kind(p) == Gen.B0:
			return p
	return -1

## The block covering cell `c`, or -1.
func block_at(c: int) -> int:
	for p in blocks.size():
		if Gen.cells(kind(p), at(p)).has(c):
			return p
	return -1

## The tray with block `p` lifted out.
func _without(p: int) -> PackedByteArray:
	var g := Gen.grid(key)
	for c in Gen.cells(kind(p), at(p)):
		g[c] = Gen.E
	return g

## Every anchor block `p` can be slid to from where it stands, its own
## included.
func reach(p: int) -> PackedInt32Array:
	return Gen.reach(_without(p), kind(p), at(p))

## Whether block `p` fits with its anchor at `to` (every other block still).
func fits(p: int, to: int) -> bool:
	var sz := size_of(p)
	var x := to % Gen.COLS
	var y := to / Gen.COLS
	if to < 0 or x + sz.x > Gen.COLS or y + sz.y > Gen.ROWS:
		return false
	var g := _without(p)
	for c in Gen.cells(kind(p), to):
		if g[c] != Gen.E:
			return false
	return true

## Moves block `p` one cell by (`dx`, `dy`) without a history entry (a
## drag's live step): one cell at a time, so it never passes through another
## block.
func step(p: int, dx: int, dy: int) -> bool:
	var x := at(p) % Gen.COLS + dx
	var y := at(p) / Gen.COLS + dy
	var sz := size_of(p)
	if x < 0 or y < 0 or x + sz.x > Gen.COLS or y + sz.y > Gen.ROWS:
		return false
	var to := y * Gen.COLS + x
	if not fits(p, to):
		return false
	var a := kind(p)
	key = key - Gen.contrib(a, at(p)) + Gen.contrib(a, to)
	blocks[p][1] = to
	return true

## Remembers the arrangement a move started from, if the move changed it.
func commit(before: Array) -> bool:
	if _same(before, blocks):
		return false
	history.append(before)
	return true

static func _same(a: Array, b: Array) -> bool:
	for i in a.size():
		if int(a[i][1]) != int(b[i][1]):
			return false
	return true

func snapshot() -> Array:
	return blocks.duplicate(true)

func _restore(s: Array) -> void:
	blocks = s.duplicate(true)
	key = 0
	for b: Array in blocks:
		key += Gen.contrib(int(b[0]), int(b[1]))

func can_undo() -> bool:
	return not history.is_empty()

func undo() -> bool:
	if history.is_empty():
		return false
	_restore(history.pop_back())
	return true

func reset_board() -> bool:
	if key == start_key and _same(blocks, start_blocks):
		return false
	history.append(snapshot())
	_restore(start_blocks)
	return true

## How far the tray stands from the gate now, or -1 before the worker is done
## (or off the graph, which a legal move cannot reach).
func distance() -> int:
	var r := dist_table()
	var i: int = r.get("index", {}).get(key, -1)
	return -1 if i < 0 else int(r.dist[i])

## The next move of a shortest way out: {"p", "to", "path"} or {}. Among the
## moves that bring the gate one nearer, the first found; `path` is the cells
## the anchor passes through, for the board to slide it along.
func hint_move() -> Dictionary:
	if is_solved():
		return {}
	var r := dist_table()
	if r.is_empty():
		return {}
	var here: int = r.index.get(key, -1)
	if here < 0 or r.dist[here] <= 0:
		return {}
	var want: int = r.dist[here] - 1
	for p in blocks.size():
		var a := kind(p)
		var base := key - Gen.contrib(a, at(p))
		for to in reach(p):
			if to == at(p):
				continue
			var j: int = r.index.get(base + Gen.contrib(a, to), -1)
			if j >= 0 and r.dist[j] == want:
				return {"p": p, "to": to, "path": path(p, to)}
	return {}

## The anchors block `p` passes through on the shortest slide to `to`, both
## ends included, or [] when it cannot get there.
func path(p: int, to: int) -> PackedInt32Array:
	var g := _without(p)
	var a := kind(p)
	var sz := size_of(p)
	var from := at(p)
	var prev := {from: -1}
	var q := PackedInt32Array([from])
	var h := 0
	while h < q.size():
		var u: int = q[h]
		h += 1
		if u == to:
			break
		var x := u % Gen.COLS
		var y := u / Gen.COLS
		for d in 4:
			var nx: int = x + Gen.DX[d]
			var ny: int = y + Gen.DY[d]
			if nx < 0 or ny < 0 or nx + sz.x > Gen.COLS or ny + sz.y > Gen.ROWS:
				continue
			var v := ny * Gen.COLS + nx
			if prev.has(v):
				continue
			var free := true
			for c in Gen.cells(a, v):
				if g[c] != Gen.E:
					free = false
			if free:
				prev[v] = u
				q.append(v)
	if not prev.has(to):
		return PackedInt32Array()
	var out := PackedInt32Array()
	var c := to
	while c >= 0:
		out.insert(0, c)
		c = prev[c]
	return out

## Plays the hint: slides its block home in one move, with a history entry.
func play(p: int, to: int) -> bool:
	var before := snapshot()
	if to == at(p) or not reach(p).has(to):
		return false
	var a := kind(p)
	key = key - Gen.contrib(a, at(p)) + Gen.contrib(a, to)
	blocks[p][1] = to
	history.append(before)
	return true

func is_solved() -> bool:
	return Gen.is_goal(key)

## The winning arrangement a reopened, already-solved day shows: the opening
## played down its shortest way.
func play_out() -> void:
	for i in 400:
		var m := hint_move()
		if m.is_empty():
			break
		play(m.p, m.to)
	history.clear()
