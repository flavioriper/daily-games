extends RefCounted

const Gen = preload("res://puzzles/nonogram_gen.gd")

static func run(t) -> void:
	# Clue extraction.
	t.eq(Gen.clue_for([1, 1, 0, 1]), [2, 1], "runs are read in order")
	t.eq(Gen.clue_for([0, 0, 0]), [], "an empty line has no clue")
	t.eq(Gen.clue_for([1, 1, 1]), [3], "a solid line is one run")
	t.eq(Gen.clue_for([1, 0, 1, 0, 1]), [1, 1, 1], "gaps split runs")

	# Line refinement: a run of 4 in a line of 5 forces the middle three.
	t.eq(Gen.refine([4], [-1, -1, -1, -1, -1]), [-1, 1, 1, 1, -1], "overlap forces the middle")
	# A full-width run forces everything.
	t.eq(Gen.refine([5], [-1, -1, -1, -1, -1]), [1, 1, 1, 1, 1], "a full run forces the line")
	# An empty clue forces every cell blank.
	t.eq(Gen.refine([], [-1, -1, -1]), [0, 0, 0], "no clue means all blank")
	# Contradictions are reported rather than guessed around.
	# A known blank at the head leaves exactly one placement for the run.
	t.eq(Gen.refine([3], [0, -1, -1, -1]), [0, 1, 1, 1], "a known blank shifts the only placement")
	# A run of 3 cannot fit in a 3-cell line whose first cell is blank.
	t.eq(Gen.refine([3], [0, -1, -1]), [], "impossible clue yields a contradiction")

	for dim in [[5, 5], [8, 8], [10, 10]]:
		for i in range(4):
			var rng := RandomNumberGenerator.new()
			rng.seed = 9000 + i
			var out: Dictionary = Gen.generate(rng, dim[0], dim[1])
			var tag := "%dx%d seed=%d" % [dim[0], dim[1], i]
			t.check(out.ok, "%s generated a puzzle" % tag)
			if not out.ok:
				continue
			# Line logic alone must finish it -- that is both the fairness
			# guarantee and the uniqueness proof.
			var solved: Array = Gen.solve(out.rows, out.cols, dim[0], dim[1])
			t.check(not solved.is_empty(), "%s solves without contradiction" % tag)
			t.check(Gen.is_complete(solved), "%s completes by line logic alone" % tag)
			t.eq(solved, out.bitmap, "%s the solution is the original image" % tag)

			# The published clues must describe the image truthfully.
			var rows_ok := true
			for y in dim[1]:
				if Gen.clue_for(out.bitmap[y]) != out.rows[y]:
					rows_ok = false
			t.check(rows_ok, "%s row clues are truthful" % tag)
			var cols_ok := true
			for x in dim[0]:
				var col: Array = []
				for y in dim[1]:
					col.append(out.bitmap[y][x])
				if Gen.clue_for(col) != out.cols[x]:
					cols_ok = false
			t.check(cols_ok, "%s column clues are truthful" % tag)
