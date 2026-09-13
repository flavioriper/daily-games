extends RefCounted

const Gen = preload("res://puzzles/binairo_gen.gd")

static func run(t) -> void:
	_test_complete_validity(t)
	_test_rules_isolated(t)
	_test_solve_count(t)
	_test_generate_is_unique(t)
	_test_determinism(t)
	_test_minimality(t)
	_test_min_clues(t)
	_test_bad_lines(t)

static func _grid(rows: Array) -> Array:
	# Rows given as strings of 0/1/. for readability.
	var g := []
	for r in rows:
		var row := []
		for ch in str(r):
			row.append(-1 if ch == "." else int(ch))
		g.append(row)
	return g

# A verified-valid 6x6 solution: every row and column holds three of each,
# no line has three in a row, and all twelve lines are distinct.
const GOOD := ["010011", "101100", "101001", "010110", "110100", "001011"]

static func _test_complete_validity(t) -> void:
	t.check(Gen.is_valid_complete(_grid(GOOD)), "known-good grid accepted")
	t.check(not Gen.is_valid_complete(_grid(["01001.", "101100", "101001", "010110", "110100", "001011"])),
		"incomplete grid rejected")
	# Swapping two cells in one row keeps that row balanced but breaks columns.
	t.check(not Gen.is_valid_complete(_grid(["100011", "101100", "101001", "010110", "110100", "001011"])),
		"perturbed grid rejected")

static func _test_rules_isolated(t) -> void:
	# Each of these partial grids violates exactly one rule, so a zero count
	# pins the blame on that rule rather than on an incidental second break.

	# Three 0s in a row. Row balance is not yet exceeded (three of six).
	t.eq(Gen.solve_count(_grid(["000...", "......", "......", "......", "......", "......"]), 2), 0,
		"three-in-a-row rejected in isolation")

	# Four 1s in a row, no triple anywhere.
	t.eq(Gen.solve_count(_grid(["110110", "......", "......", "......", "......", "......"]), 2), 0,
		"row balance rejected in isolation")

	# Two identical complete rows, each individually legal.
	t.eq(Gen.solve_count(_grid(["010011", "010011", "......", "......", "......", "......"]), 2), 0,
		"duplicate rows rejected in isolation")

	# Three 0s in a column.
	t.eq(Gen.solve_count(_grid(["0.....", "0.....", "0.....", "......", "......", "......"]), 2), 0,
		"three-in-a-column rejected in isolation")

static func _test_solve_count(t) -> void:
	t.eq(Gen.solve_count(_grid(GOOD), 2), 1, "complete valid grid counts as one solution")
	t.check(Gen.solve_count(_grid(["......", "......", "......", "......", "......", "......"]), 2) >= 2,
		"empty 6x6 has many solutions")

static func _test_generate_is_unique(t) -> void:
	for n in [6, 8]:
		for i in range(6):
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + i
			var out: Dictionary = Gen.generate(rng, n)
			t.check(Gen.is_valid_complete(out.solution), "n=%d seed=%d solution is valid" % [n, i])
			t.eq(Gen.solve_count(out.puzzle, 3), 1, "n=%d seed=%d puzzle is uniquely solvable" % [n, i])
			var agrees := true
			for r in n:
				for c in n:
					if out.puzzle[r][c] != -1 and out.puzzle[r][c] != out.solution[r][c]:
						agrees = false
			t.check(agrees, "n=%d seed=%d clues agree with solution" % [n, i])

static func _test_determinism(t) -> void:
	var a := RandomNumberGenerator.new(); a.seed = 42
	var b := RandomNumberGenerator.new(); b.seed = 42
	t.eq(Gen.generate(a, 6).puzzle, Gen.generate(b, 6).puzzle, "same seed produces the same puzzle")
	var c := RandomNumberGenerator.new(); c.seed = 43
	var d := RandomNumberGenerator.new(); d.seed = 42
	t.check(Gen.generate(c, 6).puzzle != Gen.generate(d, 6).puzzle, "different seeds differ")

static func _test_minimality(t) -> void:
	# Removal only loosens constraints, so a clue proven load-bearing during
	# generation stays load-bearing. Verify that invariant actually holds.
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var out: Dictionary = Gen.generate(rng, 6)
	var n := 6
	var all_needed := true
	for r in n:
		for c in n:
			if out.puzzle[r][c] == -1:
				continue
			var trial := []
			for rr in n:
				trial.append((out.puzzle[rr] as Array).duplicate())
			trial[r][c] = -1
			if Gen.solve_count(trial, 3) == 1:
				all_needed = false
	t.check(all_needed, "every remaining clue is load-bearing")

static func _test_min_clues(t) -> void:
	# The easy-difficulty path: stop stripping early and keep more clues.
	var rng := RandomNumberGenerator.new(); rng.seed = 99
	var out: Dictionary = Gen.generate(rng, 6, 20)
	t.check(out.clues >= 20, "min_clues floor respected -- got %d" % out.clues)
	t.eq(Gen.solve_count(out.puzzle, 3), 1, "easier puzzle is still uniquely solvable")

static func _test_bad_lines(t) -> void:
	var clean: Dictionary = Gen.bad_lines(_grid(GOOD))
	t.check(clean.rows.is_empty() and clean.cols.is_empty(), "a valid grid has no bad lines")

	var empty: Dictionary = Gen.bad_lines(_grid(["......", "......", "......", "......", "......", "......"]))
	t.check(empty.rows.is_empty() and empty.cols.is_empty(), "an empty grid has no bad lines")

	var triple: Dictionary = Gen.bad_lines(_grid(["000...", "......", "......", "......", "......", "......"]))
	t.check(triple.rows.has(0) and triple.rows.size() == 1, "three in a row flags only that row")
	t.check(triple.cols.is_empty(), "three in a row flags no column")

	var too_many: Dictionary = Gen.bad_lines(_grid(["1.1.11", "1.....", "......", "1.....", "1.....", "......"]))
	t.check(too_many.rows.has(0), "four ones in a six-row is over half")
	t.check(too_many.cols.has(0), "four ones in a six-column is over half")

	var twin_rows: Dictionary = Gen.bad_lines(_grid(["010011", "010011", "......", "......", "......", "......"]))
	t.check(twin_rows.rows.has(0) and twin_rows.rows.has(1), "identical complete rows flag both rows")

	var partial_twins: Dictionary = Gen.bad_lines(_grid(["01001.", "01001.", "......", "......", "......", "......"]))
	t.check(not partial_twins.rows.has(0), "incomplete rows are never compared")
