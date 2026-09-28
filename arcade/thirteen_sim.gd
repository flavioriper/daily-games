extends RefCounted

## Lucky Thirteen as pure data (spec
## docs/superpowers/specs/2026-09-27-arcade-thirteen-design.md): a tray of
## numbered pebbles five across and six down. Drag a chain through three or
## more touching pebbles of one number (diagonals count, no pebble twice)
## and they merge into the last one, one number higher; the pebbles above
## fall into the gaps and new ones roll in at the top. The aim is 13. A
## tray with no three touching of a number is stuck: a tool may free it,
## else the game is over.
##
## The screen (arcade/thirteen_screen.gd) calls `begin()`, `extend()`,
## `commit()` and the tools and drains `events`; nothing here runs on a
## clock, because a move resolves at once and the screen animates after it.
##
## Merges and new numbers earn clovers, spent on five tools: undo the last
## move, swap two pebbles, pluck one out, shuffle the tray, lift one pebble
## a number.

enum Phase { PLAY, STUCK, OVER }
enum Tool { UNDO, SWAP, PLUCK, SHUFFLE, LIFT }

const COLS := 5
const ROWS := 6
const MIN_CHAIN := 3
const GOAL := 13
const COSTS := {Tool.UNDO: 25, Tool.SWAP: 40, Tool.PLUCK: 30, Tool.SHUFFLE: 50, Tool.LIFT: 80}
const TOOL_KEYS := {Tool.UNDO: "undo", Tool.SWAP: "swap", Tool.PLUCK: "pluck", Tool.SHUFFLE: "shuffle", Tool.LIFT: "lift"}
## The tools that need a pebble (or two) picked after they are pressed.
const TARGETED := [Tool.SWAP, Tool.PLUCK, Tool.LIFT]
## Clovers the game starts with, so every tool can be tried once early.
const START_CLOVERS := 20
## Points a merge is worth: the new number, times the pebbles in the chain,
## times this.
const POINTS := 10
const NEIGHBOURS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

var rng := RandomNumberGenerator.new()
var phase := Phase.PLAY
## grid[c][r], r 0 the top row: {id, v}.
var grid: Array = []
## The chain being drawn, first pebble first.
var path: Array[Vector2i] = []
var score := 0
var clovers := START_CLOVERS
var max_v := 0
var moves := 0
var merges := 0
var best_chain := 0
var tools_used := 0
## How often each tool was bought this game: its price climbs with each.
var bought := {}
var events: Array = []
var _ids := 0
## The tray as it stood before the last move, for Undo, or {} with none.
var _undo := {}

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for c in COLS:
		var col: Array = []
		for r in ROWS:
			col.append({})
		grid.append(col)
	# a fresh tray always has a move in it
	for attempt in 50:
		for c in COLS:
			for r in ROWS:
				grid[c][r] = {"id": _new_id(), "v": _start_value()}
		if has_move():
			break
	max_v = _biggest()
	events.append({"type": "deal"})

func is_over() -> bool:
	return phase == Phase.OVER

func at(p: Vector2i) -> Dictionary:
	if p.x < 0 or p.x >= COLS or p.y < 0 or p.y >= ROWS:
		return {}
	return grid[p.x][p.y]

func value(p: Vector2i) -> int:
	var cell := at(p)
	return int(cell.v) if not cell.is_empty() else 0

static func touching(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1

func _new_id() -> int:
	_ids += 1
	return _ids

## The opening tray: ones and twos with a few threes.
func _start_value() -> int:
	var roll := rng.randf()
	return 1 if roll < 0.45 else (2 if roll < 0.85 else 3)

## The number a pebble rolling in carries: from `max_v - 7` up to
## `max_v - 2` (never under 1 or over 3 at the start), the small ones
## likelier, so the tray keeps feeding the numbers the player is building
## toward without ever handing out the next big one.
func spawn_range() -> Vector2i:
	var hi := clampi(max_v - 2, 3, 10)
	var lo := clampi(max_v - 6, 1, hi)
	return Vector2i(lo, hi)

func _spawn_value() -> int:
	var r := spawn_range()
	var total := 0
	for v in range(r.x, r.y + 1):
		total += r.y - v + 2
	var roll := rng.randi_range(1, total)
	for v in range(r.x, r.y + 1):
		roll -= r.y - v + 2
		if roll <= 0:
			return v
	return r.x

func _biggest() -> int:
	var best := 0
	for c in COLS:
		for r in ROWS:
			best = maxi(best, value(Vector2i(c, r)))
	return best

# --- the chain ---

## Start a chain on a pebble. False when the tray will not take one.
func begin(p: Vector2i) -> bool:
	path.clear()
	if phase != Phase.PLAY or at(p).is_empty():
		return false
	path.append(p)
	events.append({"type": "select", "cell": p, "n": 1})
	return true

## Carry the chain onto `p`: a touching pebble of the same number not yet
## in it, or the pebble before the last, which takes the last one back off.
func extend(p: Vector2i) -> bool:
	if path.is_empty() or phase != Phase.PLAY:
		return false
	var last: Vector2i = path[-1]
	if p == last:
		return false
	if path.size() >= 2 and p == path[-2]:
		path.pop_back()
		events.append({"type": "unselect", "cell": last, "n": path.size()})
		return true
	if path.has(p) or not touching(last, p) or value(p) != value(last):
		return false
	path.append(p)
	events.append({"type": "select", "cell": p, "n": path.size()})
	return true

func cancel() -> void:
	path.clear()

## Let the chain go: three or more merge into the last pebble. Returns
## whether a merge happened; a short chain is refused.
func commit() -> bool:
	if path.is_empty():
		return false
	if path.size() < MIN_CHAIN or phase != Phase.PLAY:
		events.append({"type": "short", "n": path.size()})
		path.clear()
		return false
	_save_undo()
	var chain := path.duplicate()
	path.clear()
	_merge(chain)
	return true

func _merge(chain: Array) -> void:
	var into: Vector2i = chain[-1]
	var v := value(into)
	var nv := v + 1
	var gone: Array = []
	for k in chain.size() - 1:
		var p: Vector2i = chain[k]
		gone.append({"id": at(p).id, "cell": p})
		grid[p.x][p.y] = {}
	var keep: Dictionary = at(into)
	keep.v = nv
	moves += 1
	merges += 1
	best_chain = maxi(best_chain, chain.size())
	var points := nv * chain.size() * POINTS
	score += points
	# a clover a pebble past the fifth: a long chain is worth a little
	var earned := maxi(0, chain.size() - 5)
	var ev := {"type": "merge", "id": keep.id, "cell": into, "v": nv, "gone": gone, "n": chain.size(), "points": points}
	if nv > max_v:
		max_v = nv
		# a new number earns its own worth in clovers, a 13 a pot of them
		earned += nv if nv < GOAL else 50
		ev.new_max = true
	clovers += earned
	ev.clovers = earned
	events.append(ev)
	if nv == GOAL and bool(ev.get("new_max", false)):
		events.append({"type": "goal"})
	_settle()

## Everything above a gap falls into it, and new pebbles roll in over the top.
func _settle() -> void:
	var falls: Array = []
	var fresh: Array = []
	for c in COLS:
		var col: Array = grid[c]
		var stack: Array = []
		for r in range(ROWS - 1, -1, -1):
			if not (col[r] as Dictionary).is_empty():
				stack.append({"cell": col[r], "from": r})
		var r := ROWS - 1
		for s: Dictionary in stack:
			col[r] = s.cell
			if int(s.from) != r:
				falls.append({"id": s.cell.id, "col": c, "from": s.from, "to": r})
			r -= 1
		var above := 0
		while r >= 0:
			above += 1
			var cell := {"id": _new_id(), "v": _spawn_value()}
			col[r] = cell
			fresh.append({"id": cell.id, "col": c, "row": r, "v": cell.v, "from": -above})
			r -= 1
	events.append({"type": "settle", "falls": falls, "fresh": fresh})
	_check()

## After every move: a tray with a move plays on; one without is stuck while
## a tool could still help, and over when none can.
func _check() -> void:
	if has_move():
		phase = Phase.PLAY
		return
	if _can_rescue():
		if phase != Phase.STUCK:
			phase = Phase.STUCK
			events.append({"type": "stuck"})
		return
	phase = Phase.OVER
	events.append({"type": "over"})

## Whether any three touching pebbles share a number: a connected group of
## three or more always holds a chain of three.
func has_move() -> bool:
	return not first_move().is_empty()

## One group of three or more touching pebbles of a number, or [] with none.
func first_move() -> Array:
	var groups := groups_of(MIN_CHAIN)
	return groups[0] if not groups.is_empty() else []

## Every group of touching same-numbered pebbles at least `least` big.
func groups_of(least: int) -> Array:
	var seen := {}
	var out: Array = []
	for c in COLS:
		for r in ROWS:
			var p := Vector2i(c, r)
			if seen.has(p) or at(p).is_empty():
				continue
			var v := value(p)
			var group: Array = [p]
			seen[p] = true
			var i := 0
			while i < group.size():
				var q: Vector2i = group[i]
				i += 1
				for d: Vector2i in NEIGHBOURS:
					var n: Vector2i = q + d
					if not seen.has(n) and value(n) == v:
						seen[n] = true
						group.append(n)
			if group.size() >= least:
				out.append(group)
	return out

## The longest chain through `group` ending on `end` that a depth-first
## search finds in a bounded number of steps (the whole group when it can),
## the neighbour with the fewest ways on tried first. The walk goes out from
## the end and is reversed, so `end` is last. May be shorter than three: a
## pebble in the middle of a star ends no chain of three.
static func chain_through(group: Array, end: Vector2i, budget := 1500) -> Array:
	var inside := {}
	for p: Vector2i in group:
		inside[p] = true
	var state := {"best": [end], "left": budget}
	_walk([end], {end: true}, inside, state, group.size())
	var best: Array = (state.best as Array).duplicate()
	best.reverse()
	return best

static func _walk(walk: Array, used: Dictionary, inside: Dictionary, state: Dictionary, whole: int) -> void:
	state.left = int(state.left) - 1
	if walk.size() > (state.best as Array).size():
		state.best = walk.duplicate()
	if int(state.left) <= 0 or (state.best as Array).size() >= whole:
		return
	var here: Vector2i = walk[-1]
	var options: Array = []
	for d: Vector2i in NEIGHBOURS:
		var n: Vector2i = here + d
		if inside.has(n) and not used.has(n):
			options.append(n)
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _free_round(a, inside, used) < _free_round(b, inside, used))
	for n: Vector2i in options:
		walk.append(n)
		used[n] = true
		_walk(walk, used, inside, state, whole)
		used.erase(n)
		walk.pop_back()
		if int(state.left) <= 0 or (state.best as Array).size() >= whole:
			return

static func _free_round(p: Vector2i, inside: Dictionary, used: Dictionary) -> int:
	var n := 0
	for d: Vector2i in NEIGHBOURS:
		if inside.has(p + d) and not used.has(p + d):
			n += 1
	return n

## A move to show a player who has sat still: the longest chain of the
## smallest number, or [] on a tray with none.
func hint() -> Array:
	var best: Array = []
	var best_v := 999
	for g: Array in groups_of(MIN_CHAIN):
		var v := value(g[0])
		if v > best_v:
			continue
		for end: Vector2i in g:
			var chain := chain_through(g, end, 300)
			if chain.size() >= MIN_CHAIN and (v < best_v or chain.size() > best.size()):
				best = chain
				best_v = v
			if best.size() == g.size():
				break
	return best

# --- undo ---

func _save_undo() -> void:
	var cells: Array = []
	for c in COLS:
		var col: Array = []
		for r in ROWS:
			col.append((grid[c][r] as Dictionary).duplicate())
		cells.append(col)
	_undo = {"grid": cells, "score": score, "max_v": max_v, "moves": moves, "merges": merges, "rng": rng.state}

func can_undo() -> bool:
	return not _undo.is_empty()

# --- tools ---

## A tool's price: its base, and half as much again for every time it was
## bought this game, so rescues run dear and a tray cannot be kept alive
## for ever.
func cost(tool: int) -> int:
	var base := int(COSTS[tool])
	return base + base * int(bought.get(tool, 0)) / 2

func can_use(tool: int) -> bool:
	if phase == Phase.OVER or clovers < cost(tool):
		return false
	if tool == Tool.UNDO:
		return can_undo()
	return true

## Whether a tool could still get a stuck tray moving: any tool but Undo can
## (a shuffle always finds a move, and a swap or a pluck or a lift usually
## will), Undo only with a move to take back.
func _can_rescue() -> bool:
	for tool: int in COSTS:
		if can_use(tool):
			return true
	return false

## Whether `tool` may be used on `a` (and `b`, for a swap).
func can_target(tool: int, a: Vector2i, b := Vector2i(-1, -1)) -> bool:
	if not can_use(tool) or at(a).is_empty():
		return false
	match tool:
		Tool.SWAP:
			return not at(b).is_empty() and a != b and value(a) != value(b)
		Tool.LIFT:
			# never the biggest number: a lift is a nudge, not a shortcut to 13
			return value(a) < max_v
	return true

## Spend clovers on a tool. Undo and Shuffle act at once; Swap, Pluck and
## Lift need their pebbles.
func use(tool: int, a := Vector2i(-1, -1), b := Vector2i(-1, -1)) -> bool:
	var ok := can_use(tool) if tool not in TARGETED else can_target(tool, a, b)
	if not ok:
		events.append({"type": "refused", "tool": TOOL_KEYS[tool]})
		return false
	path.clear()
	clovers -= cost(tool)
	bought[tool] = int(bought.get(tool, 0)) + 1
	tools_used += 1
	match tool:
		Tool.UNDO:
			var u := _undo
			_undo = {}
			var before := _ids_at()
			grid = u.grid
			score = u.score
			max_v = u.max_v
			moves = u.moves
			merges = u.merges
			rng.state = u.rng
			events.append({"type": "tool", "tool": "undo", "before": before})
			phase = Phase.PLAY
			_check()
		Tool.SWAP:
			_save_undo()
			var ca: Dictionary = at(a)
			grid[a.x][a.y] = at(b)
			grid[b.x][b.y] = ca
			events.append({"type": "tool", "tool": "swap", "a": a, "b": b})
			_check()
		Tool.PLUCK:
			_save_undo()
			var gone: Dictionary = at(a)
			grid[a.x][a.y] = {}
			events.append({"type": "tool", "tool": "pluck", "cell": a, "id": gone.id, "v": gone.v})
			_settle()
		Tool.LIFT:
			_save_undo()
			var cell: Dictionary = at(a)
			cell.v = int(cell.v) + 1
			events.append({"type": "tool", "tool": "lift", "cell": a, "id": cell.id, "v": cell.v})
			_check()
		Tool.SHUFFLE:
			_save_undo()
			var cells: Array = []
			for c in COLS:
				for r in ROWS:
					cells.append(grid[c][r])
			for attempt in 60:
				_shuffle(cells)
				var k := 0
				for c in COLS:
					for r in ROWS:
						grid[c][r] = cells[k]
						k += 1
				if has_move():
					break
			events.append({"type": "tool", "tool": "shuffle"})
			_check()
	return true

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## Where each pebble stands, id -> cell, before an undo moves them.
func _ids_at() -> Dictionary:
	var out := {}
	for c in COLS:
		for r in ROWS:
			var cell: Dictionary = grid[c][r]
			if not cell.is_empty():
				out[cell.id] = Vector2i(c, r)
	return out

## Head start (arcade/boosters.gd): every pebble of a fresh tray one
## number higher.
func head_start() -> void:
	for c in COLS:
		for r in ROWS:
			var cell: Dictionary = grid[c][r]
			if not cell.is_empty():
				cell.v = int(cell.v) + 1
	max_v = _biggest()

## The Second chance (arcade/boosters.gd): a free shuffle of a tray that
## ran out of moves, till it has one.
func revive() -> void:
	if phase != Phase.OVER:
		return
	path.clear()
	var cells: Array = []
	for c in COLS:
		for r in ROWS:
			cells.append(grid[c][r])
	for attempt in 60:
		_shuffle(cells)
		var k := 0
		for c in COLS:
			for r in ROWS:
				grid[c][r] = cells[k]
				k += 1
		if has_move():
			break
	phase = Phase.PLAY
	events.append({"type": "tool", "tool": "shuffle"})
	events.append({"type": "revive"})
	_check()

## Give up a stuck tray.
func give_up() -> void:
	if phase == Phase.OVER:
		return
	path.clear()
	phase = Phase.OVER
	events.append({"type": "over"})

## A copy to try a move on (the probe's bot).
func clone() -> RefCounted:
	var s = get_script().new(0)
	s.events.clear()
	s.rng.state = rng.state
	s.phase = phase
	s.grid = []
	for c in COLS:
		var col: Array = []
		for r in ROWS:
			col.append((grid[c][r] as Dictionary).duplicate())
		s.grid.append(col)
	s.score = score
	s.clovers = clovers
	s.bought = bought.duplicate()
	s.max_v = max_v
	s._ids = _ids
	return s
