extends RefCounted

const Gen = preload("res://puzzles/oneline_gen.gd")

static func run(t) -> void:
	# The classic result: a path exists iff connected with 0 or 2 odd vertices.
	# A triangle -- every vertex degree 2 -- has a circuit.
	var tri: Array = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 2)]
	t.check(Gen.has_eulerian_path(tri, [0, 1, 2]), "a triangle is traceable")
	t.eq(Gen.odd_nodes(tri, [0, 1, 2]).size(), 0, "a triangle has no odd vertices")

	# A path of two edges has exactly two odd ends.
	var path: Array = [Vector2i(0, 1), Vector2i(1, 2)]
	t.check(Gen.has_eulerian_path(path, [0, 1, 2]), "an open path is traceable")
	t.eq(Gen.odd_nodes(path, [0, 1, 2]), [0, 2], "the two ends are the odd vertices")

	# Four odd vertices means no single stroke can do it.
	var bowtie: Array = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 2),
		Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 4),
		Vector2i(0, 3), Vector2i(1, 4),
	]
	var odd_count: int = Gen.odd_nodes(bowtie, [0, 1, 2, 3, 4]).size()
	t.check(odd_count > 2, "the test figure really has more than two odd vertices")
	t.check(not Gen.has_eulerian_path(bowtie, [0, 1, 2, 3, 4]), "four odd vertices is not traceable")

	# Disconnected pieces are never traceable, whatever the degrees.
	var split: Array = [Vector2i(0, 1), Vector2i(2, 3)]
	t.check(not Gen.has_eulerian_path(split, [0, 1, 2, 3]), "a disconnected figure is not traceable")

	for dim in [[3, 3, 0.55], [4, 3, 0.5], [4, 4, 0.45]]:
		for i in range(5):
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + i
			var out: Dictionary = Gen.generate(rng, dim[0], dim[1], dim[2])
			var tag := "%dx%d seed=%d" % [dim[0], dim[1], i]
			t.check(out.ok, "%s generated a figure" % tag)
			if not out.ok:
				continue
			t.check(Gen.has_eulerian_path(out.edges, out.nodes), "%s is traceable" % tag)
			t.check(out.starts.size() in [0, 2], "%s has 0 or 2 valid starting points" % tag)
			# Every node must carry a position for drawing.
			var positioned := true
			for n in out.nodes:
				if not out.pos.has(n):
					positioned = false
			t.check(positioned, "%s every node has a position" % tag)
			# No duplicate edges: tracing each once must be well defined.
			var seen: Dictionary = {}
			var dupes := false
			for e in out.edges:
				if seen.has(e):
					dupes = true
				seen[e] = true
			t.check(not dupes, "%s no duplicate edges" % tag)

			# A real trail must exist and cover every edge exactly once.
			var trail: Array = Gen.find_path(out.edges, out.nodes)
			t.eq(trail.size(), out.edges.size() + 1, "%s trail visits every edge once" % tag)
			var walked: Dictionary = {}
			var legal := true
			for k in range(trail.size() - 1):
				var e := Vector2i(mini(trail[k], trail[k + 1]), maxi(trail[k], trail[k + 1]))
				if walked.has(e) or not out.edges.has(e):
					legal = false
				walked[e] = true
			t.check(legal, "%s every step of the trail is a fresh real edge" % tag)
			t.eq(walked.size(), out.edges.size(), "%s the trail covers all edges" % tag)
			if not out.starts.is_empty():
				t.check(out.starts.has(trail[0]), "%s the trail starts at an odd vertex" % tag)

	# No trail exists for a figure with four odd vertices.
	t.eq(Gen.find_path(bowtie, [0, 1, 2, 3, 4]), [], "no trail when four vertices are odd")
