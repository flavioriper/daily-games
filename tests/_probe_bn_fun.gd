extends SceneTree

## Made-fun probe (2026-10-28), headless: per band, 40 days walked by
## puzzles/binairo_reader.gd one step at a time from the deal. Counts the
## steps by rule, the deals whose opening has no one-sentence step (only a
## whole-line read), and whether every walk ends on the answer.
##
##     godot --headless --path . --script res://tests/_probe_bn_fun.gd

const Gen = preload("res://puzzles/binairo_gen.gd")
const Reader = preload("res://puzzles/binairo_reader.gd")
const Board = preload("res://puzzles/binairo2d.gd")

func _initialize() -> void:
	for band in 4:
		var level: Dictionary = Board.LEVELS[band]
		var rules := [0, 0, 0, 0, 0, 0]
		var cold := 0
		var wrong := 0
		var opening_lines := 0
		var worst := 0
		var empties := 0
		for seed in 40:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + seed
			var t0 := Time.get_ticks_msec()
			var d: Dictionary = Gen.generate(rng, level.size, level.min_clues, level.signs, level.tier)
			worst = maxi(worst, Time.get_ticks_msec() - t0)
			var g: Array = []
			for row in d.puzzle:
				g.append((row as Array).duplicate())
				for v in row:
					if v == -1:
						empties += 1
			var first := true
			var lines_in_first_third := 0
			var k := 0
			while true:
				var s := Reader.next(g, d.signs)
				if s.is_empty():
					break
				rules[int(s.rule)] += 1
				if first and int(s.rule) == Reader.Rule.LINE:
					cold += 1
				first = false
				var cell: Vector2i = s.cell
				g[cell.y][cell.x] = s.value
				k += 1
			if g != d.solution:
				wrong += 1
		var total := 0
		for x in rules:
			total += x
		print("band %d: %d steps; sign %d%% pair %d%% gap %d%% half %d%% line %d%%; cold openings %d/40; walks off the answer %d; empties/day %.1f; gen worst %d ms" % [
			band, total, 100 * rules[1] / total, 100 * rules[2] / total, 100 * rules[3] / total,
			100 * rules[4] / total, 100 * rules[5] / total, cold, wrong, empties / 40.0, worst])
	quit()
