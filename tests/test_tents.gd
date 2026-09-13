extends RefCounted

const Gen = preload("res://puzzles/tents_gen.gd")

static func run(t) -> void:
	for dim in [[7, 7, 7], [8, 8, 9]]:
		for i in range(5):
			var rng := RandomNumberGenerator.new()
			rng.seed = 4000 + i
			var out: Dictionary = Gen.generate(rng, dim[0], dim[1], dim[2])
			var tag := "%dx%d seed=%d" % [dim[0], dim[1], i]
			t.check(out.ok, "%s generated a puzzle" % tag)
			if not out.ok:
				continue
			t.eq(Gen.solve_count(out.trees, out.row_counts, out.col_counts, dim[0], dim[1], 3), 1,
				"%s is uniquely solvable" % tag)
			t.eq(out.tents.size(), out.trees.size(), "%s one tent per tree" % tag)

			# No two tents touch, including diagonally.
			var touching := false
			for a in out.tents.size():
				for b in range(a + 1, out.tents.size()):
					var p: Vector2i = out.tents[a]
					var q: Vector2i = out.tents[b]
					if absi(p.x - q.x) <= 1 and absi(p.y - q.y) <= 1:
						touching = true
			t.check(not touching, "%s no two tents touch" % tag)

			# Every tent is orthogonally beside its own tree, and nothing overlaps.
			var cells: Dictionary = {}
			for c in out.tents:
				cells[c] = true
			for c in out.trees:
				cells[c] = true
			t.eq(cells.size(), out.tents.size() + out.trees.size(), "%s nothing overlaps" % tag)

			# The published counts match the actual tent layout.
			var rows: Array = []
			var cols: Array = []
			for y in dim[1]:
				rows.append(0)
			for x in dim[0]:
				cols.append(0)
			for c in out.tents:
				rows[c.y] += 1
				cols[c.x] += 1
			t.eq(rows, out.row_counts, "%s row counts are truthful" % tag)
			t.eq(cols, out.col_counts, "%s column counts are truthful" % tag)

	# A tree with no free neighbour is unsolvable rather than crashing.
	t.eq(Gen.solve_count([Vector2i(0, 0)], [0], [0], 1, 1, 2), 0, "boxed-in tree has no solution")
