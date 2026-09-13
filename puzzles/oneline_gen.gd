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
