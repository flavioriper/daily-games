extends RefCounted

const Gen = preload("res://puzzles/lightup_gen.gd")

static func run(t) -> void:
	for i in range(5):
		var rng := RandomNumberGenerator.new()
		rng.seed = 6000 + i
		var out: Dictionary = Gen.generate(rng, 6, 6, 0.22)
		var tag := "6x6 seed=%d" % i
		t.check(out.ok, "%s generated a puzzle" % tag)
		if not out.ok:
			continue
		t.eq(Gen.solve_count(out.grid, 6, 6, 3), 1, "%s is uniquely solvable" % tag)
		# The recorded solution must itself be legal.
		t.check(not Gen.bulbs_see_each_other(out.grid, out.bulbs, 6, 6),
			"%s no bulb lights another bulb" % tag)
		t.check(Gen._all_lit(out.grid, out.bulbs, 6, 6), "%s every white cell is lit" % tag)
		t.check(Gen._clues_exact(out.grid, out.bulbs, 6, 6), "%s wall numbers are truthful" % tag)
		# No bulb may sit on a wall.
		var on_wall := false
		for b in out.bulbs:
			if out.grid[b.y][b.x] != Gen.WHITE:
				on_wall = true
		t.check(not on_wall, "%s no bulb sits on a wall" % tag)

	# Two bulbs in the same open row see each other.
	var open_row := [[Gen.WHITE, Gen.WHITE, Gen.WHITE]]
	t.check(Gen.bulbs_see_each_other(open_row, [Vector2i(0, 0), Vector2i(2, 0)], 3, 1),
		"bulbs down an open row see each other")
	# A wall between them blocks the line of sight.
	var walled := [[Gen.WHITE, Gen.WALL, Gen.WHITE]]
	t.check(not Gen.bulbs_see_each_other(walled, [Vector2i(0, 0), Vector2i(2, 0)], 3, 1),
		"a wall blocks line of sight")
