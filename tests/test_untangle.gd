extends RefCounted

const Gen = preload("res://puzzles/untangle_gen.gd")

static func run(t) -> void:
	for nodes in [7, 10, 14]:
		for i in range(4):
			var rng := RandomNumberGenerator.new()
			rng.seed = 800 + i
			var out: Dictionary = Gen.generate(rng, nodes)
			# The planar embedding it was built from must be crossing-free.
			t.eq(Gen.crossings(out.edges, out.planar), 0,
				"n=%d seed=%d generated embedding is planar" % [nodes, i])
			t.check(out.edges.size() >= nodes - 1,
				"n=%d seed=%d enough edges to be interesting" % [nodes, i])
			# Dense graphs read as spaghetti on a phone; keep the density sane.
			t.check(float(out.edges.size()) / float(nodes) <= 2.0,
				"n=%d seed=%d edge density is playable (%d edges)" % [nodes, i, out.edges.size()])
			t.check(Gen._connected(out.edges, nodes), "n=%d seed=%d graph stays connected" % [nodes, i])
			t.check(Gen._min_degree(out.edges, nodes) >= 2, "n=%d seed=%d no dangling node" % [nodes, i])
			t.eq(out.start.size(), nodes, "n=%d seed=%d scattered every node" % [nodes, i])
			# No node may be hidden underneath another, or it cannot be grabbed.
			var min_sep := 9.9
			for a in nodes:
				for b in range(a + 1, nodes):
					min_sep = minf(min_sep, out.start[a].distance_to(out.start[b]))
			t.check(min_sep > 0.1, "n=%d seed=%d nodes are separated (%.3f)" % [nodes, i, min_sep])
			# The board handed to the player should actually be tangled.
			t.check(Gen.crossings(out.edges, out.start) > 0,
				"n=%d seed=%d starts tangled" % [nodes, i])

	# Regression: piling every node onto one point makes all edges zero-length
	# and therefore crossing-free. That must not count as a win.
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 4242
	var o: Dictionary = Gen.generate(rng2, 10)
	var piled := PackedVector2Array()
	for i in 10:
		piled.append(Vector2(0.5, 0.5))
	t.eq(Gen.crossings(o.edges, piled), 0, "a pile technically has no crossings")
	t.check(not Gen.is_untangled(o.edges, piled), "but a pile is not a win")
	t.check(Gen.is_untangled(o.edges, o.planar), "the planar layout is a win")
	t.check(not Gen.is_untangled(o.edges, o.start), "the scattered start is not a win")

	# Nudging two nodes almost together is also rejected.
	var nearly: PackedVector2Array = o.planar.duplicate()
	nearly[1] = nearly[0] + Vector2(0.01, 0.0)
	t.check(not Gen.is_untangled(o.edges, nearly), "two coincident nodes are not a win")

	# Edges that merely share an endpoint are not crossings.
	var shared: Array = [Vector2i(0, 1), Vector2i(1, 2)]
	var pos := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)])
	t.eq(Gen.crossings(shared, pos), 0, "shared endpoints do not count as a crossing")

	# A genuine X crossing is detected.
	var crossed: Array = [Vector2i(0, 1), Vector2i(2, 3)]
	var xpos := PackedVector2Array([Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1)])
	t.eq(Gen.crossings(crossed, xpos), 1, "an X is one crossing")
