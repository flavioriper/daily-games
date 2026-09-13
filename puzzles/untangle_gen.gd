extends RefCounted

## Untangle / Tangle. Generate a planar graph by Delaunay-triangulating random
## points, then scatter the nodes. Solvable by construction: the original
## embedding has no crossings. The solution is NOT unique -- any planar
## embedding works -- which is a feature, since players find their own answer.

static func generate(rng: RandomNumberGenerator, nodes: int) -> Dictionary:
	var planar: PackedVector2Array = _spread_points(rng, nodes)
	var tri: PackedInt32Array = Geometry2D.triangulate_delaunay(planar)

	var edge_set := {}
	var i := 0
	while i + 2 < tri.size():
		for pair in [[tri[i], tri[i + 1]], [tri[i + 1], tri[i + 2]], [tri[i], tri[i + 2]]]:
			var a: int = mini(pair[0], pair[1])
			var b: int = maxi(pair[0], pair[1])
			edge_set["%d_%d" % [a, b]] = Vector2i(a, b)
		i += 3

	var edges: Array = []
	for k in edge_set:
		edges.append(edge_set[k])

	# Delaunay is maximally dense (~3 edges per node), which reads as spaghetti
	# on a phone. Thin it toward ~1.7 per node, keeping the graph connected and
	# every node at degree 2 or more so nothing dangles.
	edges = _thin(edges, nodes, rng, int(round(nodes * 1.7)))

	# Scatter with the same minimum separation used for the planar layout --
	# a node hidden underneath another one simply cannot be grabbed.
	# Re-roll if we accidentally hand the player an already-solved board.
	var scattered := PackedVector2Array()
	for attempt in 20:
		scattered = _spread_points(rng, nodes)
		if crossings(edges, scattered) > 0:
			break
	return {"edges": edges, "start": scattered, "planar": planar}

static func _thin(edges: Array, nodes: int, rng: RandomNumberGenerator, target: int) -> Array:
	var kept: Array = edges.duplicate()
	var order: Array = []
	for i in kept.size():
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	for oi in order:
		if kept.size() <= target:
			break
		var candidate = edges[oi]
		if not kept.has(candidate):
			continue
		var trial: Array = kept.duplicate()
		trial.erase(candidate)
		if _min_degree(trial, nodes) >= 2 and _connected(trial, nodes):
			kept = trial
	return kept

static func _min_degree(edges: Array, nodes: int) -> int:
	var deg: Array = []
	for i in nodes:
		deg.append(0)
	for e in edges:
		deg[e.x] += 1
		deg[e.y] += 1
	var lowest := 999
	for d in deg:
		lowest = mini(lowest, int(d))
	return lowest

static func _connected(edges: Array, nodes: int) -> bool:
	if nodes == 0:
		return true
	var adj: Dictionary = {}
	for e in edges:
		if not adj.has(e.x): adj[e.x] = []
		if not adj.has(e.y): adj[e.y] = []
		adj[e.x].append(e.y)
		adj[e.y].append(e.x)
	var seen := {0: true}
	var stack: Array = [0]
	while not stack.is_empty():
		var cur = stack.pop_back()
		for n in adj.get(cur, []):
			if not seen.has(n):
				seen[n] = true
				stack.append(n)
	return seen.size() == nodes

## Zero crossings alone is NOT a win: dragging every node into a single pile
## makes every edge zero-length and trivially crossing-free. Require the nodes
## to stay apart, which also kills that exploit.
const MIN_SEP := 0.05

static func is_untangled(edges: Array, pos: PackedVector2Array) -> bool:
	return crossings(edges, pos) == 0 and min_separation(pos) >= MIN_SEP

static func min_separation(pos: PackedVector2Array) -> float:
	var lowest := 9.9
	for a in pos.size():
		for b in range(a + 1, pos.size()):
			lowest = minf(lowest, pos[a].distance_to(pos[b]))
	return lowest

static func crossings(edges: Array, pos: PackedVector2Array) -> int:
	var total := 0
	for i in edges.size():
		for j in range(i + 1, edges.size()):
			var e: Vector2i = edges[i]
			var f: Vector2i = edges[j]
			# Edges sharing an endpoint always "touch"; that is not a crossing.
			if e.x == f.x or e.x == f.y or e.y == f.x or e.y == f.y:
				continue
			if Geometry2D.segment_intersects_segment(pos[e.x], pos[e.y], pos[f.x], pos[f.y]) != null:
				total += 1
	return total

static func _spread_points(rng: RandomNumberGenerator, nodes: int) -> PackedVector2Array:
	# Poisson-ish rejection sampling so Delaunay does not produce slivers.
	var pts := PackedVector2Array()
	var guard := 0
	while pts.size() < nodes and guard < 4000:
		guard += 1
		var p := Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9))
		var ok := true
		for q in pts:
			if p.distance_to(q) < 0.17:
				ok = false
				break
		if ok:
			pts.append(p)
	while pts.size() < nodes:
		pts.append(Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9)))
	return pts
