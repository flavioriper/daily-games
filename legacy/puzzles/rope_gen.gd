extends RefCounted

## The Rope (Zip). One rope laid over every square of the board exactly once,
## from peg 1 to the last peg, meeting the numbered pegs in order.
##
## Generation never searches for a cover -- it starts with one. A boustrophedon
## snake walks every square by construction, and the backbite move (take an end
## of the rope, join it to one of its grid neighbours, and drop the edge that
## neighbour no longer needs) shuffles it into a random cover while it stays a
## cover at every step. No backtracking, no failed attempts, and the shape it
## settles on wanders the way a hand-laid rope does. A board costs about three
## milliseconds to grow.
##
## There is no uniqueness pass, and that is a measured decision rather than a
## corner cut. Counted exhaustively over eight boards apiece: a 5 x 5 with four
## pegs has 38 covers, a 6 x 6 with five has 265, a 7 x 7 with six has more than
## 644 (the count ran out of budget). Planting further pegs barely moves it --
## a 6 x 6 is still at 59 covers with eight of them -- because on an open
## rectangle the pegs constrain the order of the walk and almost nothing about
## its shape. What does constrain it is walls between cells, which this board
## does not have. So the board is loose by construction, the difficulty is in
## the size and the number of stops to keep in order, and **winning is checked
## against the rule, never against the stored rope**. The stored rope is only
## ever the hint's and the check's starting point.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Backbite moves per square. Twenty-four leaves no trace of the snake it
## started as; far fewer and boards come out in long straight combs.
const MIX_MOVES := 24
## Nodes one search may expand. Hit it and the answer is "don't know", which
## the callers all read as "no" -- the honest reading for a hint or a check.
## Measured: finishing a half-drawn rope takes single-figure nodes, and the
## worst case here, a whole 7 x 7 from nothing, takes about a thousand.
const SEARCH_BUDGET := 20000

## A board of `w` x `h` with `count` numbered pegs: `pegs` in playing order,
## `path` the rope the generator laid.
static func generate(rng: RandomNumberGenerator, w: int, h: int, count: int) -> Dictionary:
	var path: Array = _random_path(rng, w, h)
	var pegs: Array = []
	for i in _spread(rng, path.size(), count):
		pegs.append(path[i])
	return {"w": w, "h": h, "pegs": pegs, "path": path, "ok": pegs.size() >= 2}

# --- the search ---

## Up to `want` ways of finishing `prefix` into a full cover. An empty prefix
## starts the rope at peg 1. `exhausted` is true when the search ran to the end
## inside its budget, which is what makes "fewer than `want` found" a proof
## rather than a guess.
static func complete(w: int, h: int, pegs: Array, prefix: Array, want := 1,
		budget := SEARCH_BUDGET) -> Dictionary:
	var n := w * h
	var none := {"paths": [], "exhausted": false}
	if pegs.is_empty():
		return none
	var peg_at := PackedInt32Array()
	peg_at.resize(n)
	peg_at.fill(-1)
	for i in pegs.size():
		peg_at[_key(pegs[i], w)] = i
	var visited := PackedByteArray()
	visited.resize(n)
	var path: Array = []
	var need := 0
	for cell in prefix:
		var k := _key(cell, w)
		if k < 0 or visited[k] == 1:
			return none
		if not path.is_empty() and not adjacent(path[path.size() - 1], cell):
			return none
		if peg_at[k] >= 0:
			if peg_at[k] != need:
				return none
			need += 1
		visited[k] = 1
		path.append(cell)
	if path.is_empty():
		var start: Vector2i = pegs[0]
		visited[_key(start, w)] = 1
		path.append(start)
		need = 1
	var mark := PackedInt32Array()
	mark.resize(n)
	var state := {"spent": 0, "budget": budget, "want": want, "found": [],
		"mark": mark, "stamp": 0, "stack": PackedInt32Array(),
		"target": pegs[pegs.size() - 1], "pegs": pegs}
	if path.size() == n:
		if need == pegs.size():
			state.found.append(path.duplicate())
	elif _region_ok(w, h, visited, path[path.size() - 1], n - path.size(), pegs[pegs.size() - 1], state) \
			and _next_peg_near(w, h, visited, path[path.size() - 1], need, pegs, peg_at, state):
		_walk(w, h, peg_at, visited, path, need, pegs.size(), state)
	return {"paths": state.found, "exhausted": state.spent < int(state.budget), "spent": state.spent}

## Depth-first from the rope's live end. True means stop: either `want`
## covers are in hand or the budget is gone.
##
## The squares ahead are tried in Warnsdorff's order -- the one with the
## fewest ways on is taken first -- because the corner the rope would strand
## is exactly the square it should be filling now. On a 6 x 6 that is the
## difference between sixty milliseconds and one.
static func _walk(w: int, h: int, peg_at: PackedInt32Array, visited: PackedByteArray,
		path: Array, need: int, peg_count: int, state: Dictionary) -> bool:
	state.spent += 1
	if int(state.spent) >= int(state.budget):
		return true
	var n := w * h
	var last_peg: Vector2i = state.target
	var at: Vector2i = path[path.size() - 1]
	var moves: Array = []
	for d: Vector2i in DIRS:
		var c: Vector2i = at + d
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			continue
		var k := c.y * w + c.x
		if visited[k] == 1:
			continue
		var peg := peg_at[k]
		if peg >= 0:
			if peg != need:
				continue
			# The rope ends on the last peg, so it is entered on the last
			# square of all and never a moment sooner.
			if peg == peg_count - 1 and path.size() + 1 < n:
				continue
		var onward := _free_around(w, h, visited, c)
		# A square with nothing beyond it can only be the rope's last, and
		# the rope's last is the last peg.
		if onward == 1 and path.size() + 1 < n:
			return false
		moves.append([onward, k, c, peg])
	moves.sort_custom(func(a, b): return a[0] < b[0])
	for m in moves:
		var k: int = m[1]
		var c: Vector2i = m[2]
		var peg: int = m[3]
		visited[k] = 1
		path.append(c)
		var next_need := need + (1 if peg >= 0 else 0)
		if path.size() == n:
			if next_need == peg_count:
				state.found.append(path.duplicate())
				if state.found.size() >= int(state.want):
					path.pop_back()
					visited[k] = 0
					return true
		elif _region_ok(w, h, visited, c, n - path.size(), last_peg, state) \
				and _next_peg_near(w, h, visited, c, next_need, state.pegs, peg_at, state):
			if _walk(w, h, peg_at, visited, path, next_need, peg_count, state):
				path.pop_back()
				visited[k] = 0
				return true
		path.pop_back()
		visited[k] = 0
	return false

## How many ways out of `c` there are once the rope is standing on it: its
## unvisited neighbours, plus the square itself as the way in.
static func _free_around(w: int, h: int, visited: PackedByteArray, c: Vector2i) -> int:
	var out := 1
	for d: Vector2i in DIRS:
		var u: Vector2i = c + d
		if u.x < 0 or u.y < 0 or u.x >= w or u.y >= h:
			continue
		if visited[u.y * w + u.x] == 0:
			out += 1
	return out

## Whether the squares still to be covered can take the rest of the rope.
## Two things are asked of them in the one pass, and between them they are
## the whole of the pruning:
##
## * they must all be reachable from the rope's end -- a square walled off is
##   a square that will never be covered;
## * inside what is left, a square with only one way in and out has to be
##   where the rope stops, so there may be at most one of them and it has to
##   be the last peg.
##
## The scratch buffer is stamped rather than cleared, so a node costs no
## allocation.
static func _region_ok(w: int, h: int, visited: PackedByteArray, at: Vector2i,
		remaining: int, target: Vector2i, state: Dictionary) -> bool:
	if remaining <= 0:
		return true
	state.stamp += 1
	var stamp: int = state.stamp
	var mark: PackedInt32Array = state.mark
	var stack: PackedInt32Array = state.stack
	stack.clear()
	var at_k := at.y * w + at.x
	for d: Vector2i in DIRS:
		var c: Vector2i = at + d
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			continue
		var k := c.y * w + c.x
		if visited[k] == 1 or mark[k] == stamp:
			continue
		mark[k] = stamp
		stack.append(k)
	var seen := 0
	var ends := 0
	var target_k := target.y * w + target.x
	while stack.size() > 0:
		var k: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		seen += 1
		var x := k % w
		var y := k / w
		var degree := 0
		for d: Vector2i in DIRS:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nk := ny * w + nx
			if nk == at_k:
				# The rope's own end is a way in, and the only visited square
				# that is.
				degree += 1
				continue
			if visited[nk] == 1:
				continue
			degree += 1
			if mark[nk] == stamp:
				continue
			mark[nk] = stamp
			stack.append(nk)
		if degree <= 1:
			if k != target_k:
				return false
			ends += 1
			if ends > 1:
				return false
	return seen == remaining

## Whether the peg the rope owes next can still be met. It may not cross a
## later peg to get there -- that is what "in order" means -- so the walk
## stops at every peg above `need`, and a next peg walled off behind one of
## them is a rope that has already lost. Cheap, and it is what keeps the
## search out of the corner it would otherwise spend thousands of nodes in.
static func _next_peg_near(w: int, h: int, visited: PackedByteArray, at: Vector2i,
		need: int, pegs: Array, peg_at: PackedInt32Array, state: Dictionary) -> bool:
	if need >= pegs.size():
		return true
	var want_k: int = _key(pegs[need], w)
	state.stamp += 1
	var stamp: int = state.stamp
	var mark: PackedInt32Array = state.mark
	var stack: PackedInt32Array = state.stack
	stack.clear()
	stack.append(at.y * w + at.x)
	mark[at.y * w + at.x] = stamp
	while stack.size() > 0:
		var k: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var x := k % w
		var y := k / w
		for d: Vector2i in DIRS:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nk := ny * w + nx
			if visited[nk] == 1 or mark[nk] == stamp:
				continue
			if nk == want_k:
				return true
			# A peg still to come is a wall until its own turn.
			if peg_at[nk] > need:
				continue
			mark[nk] = stamp
			stack.append(nk)
	return false

## The longest head of `prefix` the rope can still be finished from. A prefix
## that can be finished can be finished from any of its own heads, so the
## answer only ever falls away as the rope grows and a binary search finds it
## in a handful of solves rather than one per cell.
static func longest_playable(w: int, h: int, pegs: Array, prefix: Array) -> int:
	if prefix.is_empty():
		return 0
	var lo := 0
	var hi := prefix.size()
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		var out: Dictionary = complete(w, h, pegs, prefix.slice(0, mid), 1)
		if out.paths.is_empty():
			hi = mid - 1
		else:
			lo = mid
	return lo

static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

# --- the first cover ---

## A random cover of the grid, grown out of the snake by backbite moves.
static func _random_path(rng: RandomNumberGenerator, w: int, h: int) -> Array:
	var path: Array = _boustrophedon(w, h)
	var n := path.size()
	var where := PackedInt32Array()
	where.resize(w * h)
	for i in n:
		where[_key(path[i], w)] = i
	for _m in n * MIX_MOVES:
		var head := rng.randi() % 2 == 0
		var end: Vector2i = path[0] if head else path[n - 1]
		var d: Vector2i = DIRS[rng.randi_range(0, 3)]
		var c: Vector2i = end + d
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			continue
		var j: int = where[_key(c, w)]
		if head:
			# The end is joined to path[j], so the edge into path[j] goes and
			# everything before it turns around: path[j - 1] is the new end.
			if j <= 1:
				continue
			var flipped: Array = path.slice(0, j)
			flipped.reverse()
			for i in j:
				path[i] = flipped[i]
				where[_key(path[i], w)] = i
		else:
			if j >= n - 2:
				continue
			var tail: Array = path.slice(j + 1, n)
			tail.reverse()
			for i in tail.size():
				path[j + 1 + i] = tail[i]
				where[_key(tail[i], w)] = j + 1 + i
	return path

## The snake every board starts as: along the first row, back along the next.
static func _boustrophedon(w: int, h: int) -> Array:
	var out: Array = []
	for y in h:
		for x in w:
			out.append(Vector2i(w - 1 - x if y % 2 == 1 else x, y))
	return out

## Path indices for `count` pegs: both ends, and the rest spread along the
## rope with a little jitter so the numbers do not fall on a metronome.
static func _spread(rng: RandomNumberGenerator, n: int, count: int) -> Array:
	var out: Array = [0, n - 1]
	var span := float(n - 1) / float(maxi(count - 1, 1))
	for i in range(1, count - 1):
		var base := int(round(i * span))
		var jitter := int(span * 0.3)
		var pick := clampi(base + rng.randi_range(-jitter, jitter), 1, n - 2)
		while out.has(pick) and pick < n - 2:
			pick += 1
		while out.has(pick) and pick > 1:
			pick -= 1
		if not out.has(pick):
			out.append(pick)
	out.sort()
	return out

static func _key(c: Vector2i, w: int) -> int:
	return c.y * w + c.x
