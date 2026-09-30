extends RefCounted

## One-line drawing (Eulerian path). Trace every edge exactly once without
## lifting your finger.
##
## The cheapest correctness guarantee in the whole catalog: a connected graph
## has an Eulerian path exactly when it has zero or two odd-degree vertices.
## No search at all -- we count degrees and fix the parity directly.

static func generate(rng: RandomNumberGenerator, cols: int, rows: int, fill: float) -> Dictionary:
	for _attempt in 60:
		var edges: Array = _random_lattice_edges(rng, cols, rows, fill)
		if edges.size() < 5:
			continue
		edges = _largest_component(edges)
		if edges.size() < 5:
			continue
		edges = _fix_parity(edges, rng)
		var used: Array = _used_nodes(edges)
		if used.size() < 4 or not has_eulerian_path(edges, used):
			continue
		return {
			"edges": edges,
			"nodes": used,
			"pos": _positions(used, cols, rows),
			"starts": odd_nodes(edges, used),
			"ok": true,
		}
	return {"edges": [], "nodes": [], "pos": {}, "starts": [], "ok": false}

## Connected, and zero or two vertices of odd degree.
static func has_eulerian_path(edges: Array, nodes: Array) -> bool:
	if edges.is_empty():
		return false
	if not _connected(edges, nodes):
		return false
	return odd_nodes(edges, nodes).size() in [0, 2]

static func odd_nodes(edges: Array, nodes: Array) -> Array:
	var deg := degrees(edges)
	var odd: Array = []
	for n in nodes:
		if int(deg.get(n, 0)) % 2 == 1:
			odd.append(n)
	odd.sort()
	return odd

static func degrees(edges: Array) -> Dictionary:
	var deg: Dictionary = {}
	for e in edges:
		deg[e.x] = int(deg.get(e.x, 0)) + 1
		deg[e.y] = int(deg.get(e.y, 0)) + 1
	return deg

static func _fix_parity(edges: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = edges.duplicate()
	var guard := 0
	while guard < 50:
		guard += 1
		var used: Array = _used_nodes(out)
		var odd: Array = odd_nodes(out, used)
		if odd.size() <= 2:
			break
		# Joining two odd vertices makes both even, cutting the count by two.
		var a: int = odd[0]
		var b: int = odd[rng.randi_range(1, odd.size() - 1)]
		var e := Vector2i(mini(a, b), maxi(a, b))
		if _has_edge(out, e):
			out.erase(e)
		else:
			out.append(e)
	return out

static func _random_lattice_edges(rng: RandomNumberGenerator, cols: int, rows: int, fill: float) -> Array:
	var out: Array = []
	for y in rows:
		for x in cols:
			var a: int = y * cols + x
			# Orthogonal and diagonal neighbours; diagonals make the figures
			# read as shapes rather than as plain grids.
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
					continue
				if rng.randf() > fill:
					continue
				var b: int = ny * cols + nx
				out.append(Vector2i(mini(a, b), maxi(a, b)))
	return out

static func _largest_component(edges: Array) -> Array:
	var used: Array = _used_nodes(edges)
	var adj: Dictionary = _adjacency(edges)
	var seen: Dictionary = {}
	var best: Array = []
	for start in used:
		if seen.has(start):
			continue
		var comp: Dictionary = {start: true}
		var stack: Array = [start]
		seen[start] = true
		while not stack.is_empty():
			var cur = stack.pop_back()
			for n in adj.get(cur, []):
				if not comp.has(n):
					comp[n] = true
					seen[n] = true
					stack.append(n)
		var sub: Array = []
		for e in edges:
			if comp.has(e.x):
				sub.append(e)
		if sub.size() > best.size():
			best = sub
	return best

static func _used_nodes(edges: Array) -> Array:
	var set: Dictionary = {}
	for e in edges:
		set[e.x] = true
		set[e.y] = true
	var out: Array = set.keys()
	out.sort()
	return out

static func _adjacency(edges: Array) -> Dictionary:
	var adj: Dictionary = {}
	for e in edges:
		if not adj.has(e.x): adj[e.x] = []
		if not adj.has(e.y): adj[e.y] = []
		adj[e.x].append(e.y)
		adj[e.y].append(e.x)
	return adj

static func _connected(edges: Array, nodes: Array) -> bool:
	if nodes.is_empty():
		return false
	var adj: Dictionary = _adjacency(edges)
	var seen: Dictionary = {nodes[0]: true}
	var stack: Array = [nodes[0]]
	while not stack.is_empty():
		var cur = stack.pop_back()
		for n in adj.get(cur, []):
			if not seen.has(n):
				seen[n] = true
				stack.append(n)
	return seen.size() == nodes.size()

static func _has_edge(edges: Array, e: Vector2i) -> bool:
	for x in edges:
		if x == e:
			return true
	return false

static func _positions(nodes: Array, cols: int, rows: int) -> Dictionary:
	var out: Dictionary = {}
	for n in nodes:
		var x: int = n % cols
		var y: int = n / cols
		out[n] = Vector2(
			0.12 + 0.76 * (float(x) / maxf(1.0, float(cols - 1))),
			0.12 + 0.76 * (float(y) / maxf(1.0, float(rows - 1))))
	return out

## Hierholzer's algorithm: build an actual Eulerian trail. Used by the win
## test, and the basis for a hint that shows the next legal stroke.
static func find_path(edges: Array, nodes: Array) -> Array:
	if not has_eulerian_path(edges, nodes):
		return []
	var odd: Array = odd_nodes(edges, nodes)
	var start: int = odd[0] if odd.size() == 2 else nodes[0]

	var adj: Dictionary = {}
	for i in edges.size():
		var e: Vector2i = edges[i]
		if not adj.has(e.x): adj[e.x] = []
		if not adj.has(e.y): adj[e.y] = []
		adj[e.x].append([e.y, i])
		adj[e.y].append([e.x, i])

	var used: Dictionary = {}
	var stack: Array = [start]
	var path: Array = []
	while not stack.is_empty():
		var v = stack[-1]
		var step = null
		for pair in adj.get(v, []):
			if not used.has(pair[1]):
				step = pair
				break
		if step == null:
			path.append(stack.pop_back())
		else:
			used[step[1]] = true
			stack.append(step[0])
	path.reverse()
	return path

# --- Insane: Sunny Spells ---
#
# Some lines are sun-baked and the rest are dewy, and the snail may never
# cross two sunny lines in a row: after a sunny one she has to wet her foot on
# a dewy one. An Eulerian trail with a forbidden transition. Fleury's rule no
# longer carries the day (a step that keeps the figure in one piece can still
# leave it with nothing but sun in a row), so a figure has to be planned.
# Spec: docs/superpowers/specs/2026-09-30-oneline-polish-design.md, section 2.

## A random Eulerian trail as edge indices, from `start`: Hierholzer's with
## each post's lines shuffled, so a figure has many trails to plant the sun on.
static func random_trail(rng: RandomNumberGenerator, edges: Array, start: int) -> Array:
	var adj: Dictionary = {}
	for i in edges.size():
		var e: Vector2i = edges[i]
		for pair in [[e.x, e.y], [e.y, e.x]]:
			if not adj.has(pair[0]):
				adj[pair[0]] = []
			adj[pair[0]].append([pair[1], i])
	for n in adj:
		var list: Array = adj[n]
		for k in range(list.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp = list[k]; list[k] = list[j]; list[j] = tmp
	var used: Dictionary = {}
	var stack: Array = [[start, -1]]
	var out: Array = []
	while not stack.is_empty():
		var top: Array = stack[-1]
		var step = null
		for pair in adj.get(top[0], []):
			if not used.has(pair[1]):
				step = pair
				break
		if step == null:
			stack.pop_back()
			if int(top[1]) >= 0:
				out.append(int(top[1]))
		else:
			used[step[1]] = true
			stack.append([step[0], step[1]])
	out.reverse()
	return out

## Sunny flags along a trail: each line sunny at `odds` unless the one before
## it was, so the planted trail is always walkable.
static func plant_sun(rng: RandomNumberGenerator, edge_count: int, trail: Array, odds: float) -> Array:
	var sunny: Array = []
	sunny.resize(edge_count)
	sunny.fill(false)
	var dry := false
	for i in trail:
		var s := not dry and rng.randf() < odds
		sunny[i] = s
		dry = s
	return sunny

## The search behind every Sunny Spells question: from post `at` with the
## lines in `walked` behind her (a bitmask of edge indices) and `dry` when the
## last was sunny, a walk of every line left, or [] with none. It prunes on
## the figure staying in one piece (Fleury's question) and on every post
## having dew enough to pair its sun with: each pass through a post takes a
## line in and a line out, and two sunny ones may not be a pass.
## `budget` bounds the nodes; `out.nodes` says how many it took and
## `out.spent` whether it ran out (the answer is then unknown, not no).
class Sun:
	var edges: Array
	var sunny: Array
	var adj: Dictionary = {}
	var full := 0
	var dead: Dictionary = {}
	var nodes := 0
	var budget := 0
	var spent := false

	func _init(e: Array, s: Array) -> void:
		edges = e
		sunny = s
		for i in edges.size():
			var ed: Vector2i = edges[i]
			for pair in [[ed.x, ed.y], [ed.y, ed.x]]:
				if not adj.has(pair[0]):
					adj[pair[0]] = []
				adj[pair[0]].append([pair[1], i])
		full = (1 << edges.size()) - 1

	## A completion from `at` as edge indices, or [] (see `spent`).
	func finish(walked: int, at: int, dry: bool, cap := 400000) -> Array:
		nodes = 0
		budget = cap
		spent = false
		var path: Array = []
		if _go(walked, at, dry, path):
			return path
		return []

	## Whether a walk finishes from here. A search that runs out of budget
	## says yes: an unknown must never cost the player a heart.
	func can_finish(walked: int, at: int, dry: bool, cap := 400000) -> bool:
		if walked == full:
			return true
		return not finish(walked, at, dry, cap).is_empty() or spent

	func _go(walked: int, at: int, dry: bool, path: Array) -> bool:
		if walked == full:
			return true
		var slot := at * 2 + (1 if dry else 0)
		if not dead.has(slot):
			dead[slot] = {}
		var seen: Dictionary = dead[slot]
		if seen.has(walked):
			return false
		nodes += 1
		if nodes > budget:
			spent = true
			return false
		if not _plausible(walked, at, dry):
			seen[walked] = true
			return false
		for pair in adj.get(at, []):
			var i: int = pair[1]
			if walked & (1 << i):
				continue
			if dry and sunny[i]:
				continue
			path.append(i)
			if _go(walked | (1 << i), pair[0], sunny[i], path):
				return true
			path.pop_back()
			if spent:
				return false
		seen[walked] = true
		return false

	## Whether what is left could still be walked: in one piece with `at` on
	## it, zero or two odd posts with `at` one of them, and at every post no
	## more sunny lines than its passes can pair with dew.
	func _plausible(walked: int, at: int, dry: bool) -> bool:
		var deg: Dictionary = {}
		var sun: Dictionary = {}
		var dew: Dictionary = {}
		var a: Dictionary = {}
		var any := -1
		for i in edges.size():
			if walked & (1 << i):
				continue
			var e: Vector2i = edges[i]
			any = i
			for pair in [[e.x, e.y], [e.y, e.x]]:
				deg[pair[0]] = int(deg.get(pair[0], 0)) + 1
				if sunny[i]:
					sun[pair[0]] = int(sun.get(pair[0], 0)) + 1
				else:
					dew[pair[0]] = int(dew.get(pair[0], 0)) + 1
				if not a.has(pair[0]):
					a[pair[0]] = []
				a[pair[0]].append(pair[1])
		if any < 0:
			return true
		if not a.has(at):
			return false
		var odd: Array = []
		for n in deg:
			if int(deg[n]) % 2 == 1:
				odd.append(n)
		var end := at
		if not odd.is_empty():
			if odd.size() != 2 or not odd.has(at):
				return false
			end = odd[0] if odd[1] == at else odd[1]
		for n in deg:
			var s := int(sun.get(n, 0))
			var d := int(dew.get(n, 0))
			var free := 0
			if n == at:
				if dry:
					s += 1
				else:
					free += 1
			if n == end:
				free += 1
			if s > d + free:
				return false
		var seen: Dictionary = {at: true}
		var stack: Array = [at]
		while not stack.is_empty():
			var cur = stack.pop_back()
			for m in a[cur]:
				if not seen.has(m):
					seen[m] = true
					stack.append(m)
		return seen.size() == deg.size()

## A Sunny Spells figure on a `cols` x `rows` lattice: an ordinary figure,
## a random trail through it, and the sun planted along that trail at `odds`.
## {} when the lattice would not give one.
static func generate_sun(rng: RandomNumberGenerator, cols: int, rows: int, fill: float, odds: float) -> Dictionary:
	var out: Dictionary = generate(rng, cols, rows, fill)
	# The search keeps the walked lines in one 64-bit mask.
	if not out.ok or out.edges.size() > 60:
		return {}
	var starts: Array = out.starts
	var start: int = int(starts[rng.randi_range(0, 1)]) if not starts.is_empty() \
		else int(out.nodes[rng.randi_range(0, out.nodes.size() - 1)])
	var trail := random_trail(rng, out.edges, start)
	if trail.size() != out.edges.size():
		return {}
	out.sunny = plant_sun(rng, out.edges.size(), trail, odds)
	out.start = start
	out.trail = trail
	return out

## How often a player who knows the old rule and not the sun gets through:
## `tries` walks that never take a refused line and never strand the figure,
## choosing at random among what is left, from a random allowed start.
static func sun_blind_odds(rng: RandomNumberGenerator, edges: Array, nodes: Array, sunny: Array, tries: int) -> float:
	var starts: Array = odd_nodes(edges, nodes)
	var adj: Dictionary = {}
	for i in edges.size():
		var e: Vector2i = edges[i]
		for pair in [[e.x, e.y], [e.y, e.x]]:
			if not adj.has(pair[0]):
				adj[pair[0]] = []
			adj[pair[0]].append([pair[1], i])
	var wins := 0
	for _t in tries:
		var at: int = int(starts[rng.randi_range(0, starts.size() - 1)]) if not starts.is_empty() \
			else int(nodes[rng.randi_range(0, nodes.size() - 1)])
		var walked: Dictionary = {}
		var dry := false
		while walked.size() < edges.size():
			var options: Array = []
			for pair in adj.get(at, []):
				var i: int = pair[1]
				if walked.has(i) or (dry and sunny[i]):
					continue
				walked[i] = true
				if _rest_whole(edges, walked, pair[0]):
					options.append(pair)
				walked.erase(i)
			if options.is_empty():
				break
			var pick: Array = options[rng.randi_range(0, options.size() - 1)]
			walked[pick[1]] = true
			dry = sunny[pick[1]]
			at = pick[0]
		if walked.size() == edges.size():
			wins += 1
	return float(wins) / float(tries)

## Whether the lines not in `walked` all hang together with `at` on them (or
## there are none).
static func _rest_whole(edges: Array, walked: Dictionary, at: int) -> bool:
	var a: Dictionary = {}
	for i in edges.size():
		if walked.has(i):
			continue
		var e: Vector2i = edges[i]
		if not a.has(e.x): a[e.x] = []
		if not a.has(e.y): a[e.y] = []
		a[e.x].append(e.y)
		a[e.y].append(e.x)
	if a.is_empty():
		return true
	if not a.has(at):
		return false
	var seen: Dictionary = {at: true}
	var stack: Array = [at]
	while not stack.is_empty():
		var cur = stack.pop_back()
		for m in a[cur]:
			if not seen.has(m):
				seen[m] = true
				stack.append(m)
	return seen.size() == a.size()

## One bank row: the lattice, every line as "a-b", its sun, and the trail
## the figure was planted on (restore walks it).
static func to_bank(out: Dictionary, cols: int, rows: int) -> Dictionary:
	var lines: Array = []
	var sun := ""
	for i in out.edges.size():
		var e: Vector2i = out.edges[i]
		lines.append("%d-%d" % [e.x, e.y])
		sun += "1" if out.sunny[i] else "0"
	return {"cols": cols, "rows": rows, "lines": " ".join(lines), "sun": sun,
		"trail": " ".join(out.trail.map(func(i): return str(i))), "start": int(out.start)}

static func from_bank(row: Dictionary) -> Dictionary:
	if row.is_empty() or not row.has("lines"):
		return {}
	var edges: Array = []
	for pair in String(row.lines).split(" ", false):
		var ab := pair.split("-")
		edges.append(Vector2i(int(ab[0]), int(ab[1])))
	var sun := String(row.get("sun", ""))
	if sun.length() != edges.size():
		return {}
	var sunny: Array = []
	for k in sun.length():
		sunny.append(sun[k] == "1")
	var trail: Array = []
	for s in String(row.get("trail", "")).split(" ", false):
		trail.append(int(s))
	var nodes: Array = _used_nodes(edges)
	if edges.size() > 60 or not has_eulerian_path(edges, nodes):
		return {}
	return {"edges": edges, "nodes": nodes, "starts": odd_nodes(edges, nodes),
		"sunny": sunny, "trail": trail, "start": int(row.get("start", -1)),
		"cols": int(row.cols), "rows": int(row.rows), "ok": true}
