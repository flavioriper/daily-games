extends SceneTree

## How much of a careful Fairy Lights game says nothing back. A reading
## player homes each piece in the order the propagate-only solver settles it
## (sweep by sweep, reading order inside a sweep), taking the quarter turns
## clockwise from the deal. For every piece homed it counts what changed on
## the board: a cell lit (joined to the post), a join with no light (two
## stubs meeting off the post), or nothing at all. Also the quarter turns a
## piece needs at the deal, the turns a solve takes, and how many single
## taps along the way close a loop. Headless, not in the suite:
##
##     godot --headless --path . --script res://tests/_probe_fl_fun.gd -- [seeds=30]

const Gen = preload("res://puzzles/fairy_lights_gen.gd")
const State = preload("res://puzzles/fairy_lights_state.gd")

func _initialize() -> void:
	var seeds := 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
	for band in 3:
		var homes := 0
		var lit := 0
		var joined := 0
		var dark := 0
		var quarter := [0, 0, 0, 0]
		var taps := 0
		var loops := 0
		var strand_homes := 0
		for s in seeds:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 * band + s
			var st = State.new()
			st.start(rng, band)
			for i in st.n * st.n:
				quarter[_quarters(st.deal[i], st.sol[i])] += 1
			for i in _order(st.n, st.sol):
				var q := _quarters(st.grid[i], st.sol[i])
				if q == 0:
					continue
				var before_lit := _count_lit(st)
				var before_joins := _joins(st)
				for k in q:
					st.turn(i)
					taps += 1
					if _has_loop(st):
						loops += 1
				homes += 1
				var gained_lit := _count_lit(st) - before_lit
				var gained_joins := _joins(st) - before_joins
				if gained_lit > 0:
					lit += 1
				elif gained_joins > 0:
					joined += 1
					strand_homes += 1
				else:
					dark += 1
			assert(st.is_solved())
		print("band %d: %d pieces homed over %d seeds, %.1f taps a garden" % [band, homes, seeds, float(taps) / seeds])
		print("  lit something  %5.1f%%" % (100.0 * lit / homes))
		print("  joined, unlit  %5.1f%%   (a strand's tint since 2026-10-26; silent before)" % (100.0 * joined / homes))
		print("  nothing new    %5.1f%%" % (100.0 * dark / homes))
		print("  silent before  %5.1f%%   (joined + nothing)" % (100.0 * (joined + dark) / homes))
		print("  silent now     %5.1f%%   (nothing)" % (100.0 * dark / homes))
		print("  deal quarters 0/1/2/3: %s" % [quarter])
		print("  taps that left a closed loop: %d (%.1f a garden)" % [loops, float(loops) / seeds])
	quit()

## The cells in the order the propagate-only solver settles them.
func _order(n: int, sol: PackedInt32Array) -> PackedInt32Array:
	var cells := n * n
	var cand: Array = []
	for i in cells:
		cand.append(Gen.rotations(sol[i]))
	var out := PackedInt32Array()
	var done := PackedByteArray()
	done.resize(cells)
	for sweep in 400:
		for i in cells:
			if done[i] == 0 and (cand[i] as Array).size() == 1:
				done[i] = 1
				out.append(i)
		var changed := false
		for i in cells:
			var r: int = i / n
			var c: int = i % n
			for d in 4:
				var a: int = r + Gen.DR[d]
				var b: int = c + Gen.DC[d]
				var ci: Array = cand[i]
				if a < 0 or b < 0 or a >= n or b >= n:
					var keep: Array = []
					for m in ci:
						if m & (1 << d) == 0:
							keep.append(m)
					if keep.size() != ci.size():
						cand[i] = keep
						changed = true
					continue
				var all_open := true
				var none_open := true
				for m in ci:
					if m & (1 << d) != 0:
						none_open = false
					else:
						all_open = false
				if not (all_open or none_open):
					continue
				var j: int = a * n + b
				var od: int = (d + 2) % 4
				var keep_j: Array = []
				for m in cand[j]:
					if (m & (1 << od) != 0) == all_open:
						keep_j.append(m)
				if keep_j.size() != (cand[j] as Array).size():
					cand[j] = keep_j
					changed = true
		if not changed:
			break
	for i in cells:
		if done[i] == 0 and (cand[i] as Array).size() == 1:
			out.append(i)
	return out

func _quarters(from: int, to: int) -> int:
	var m := from
	for q in 4:
		if m == to:
			return q
		m = Gen.cw(m)
	return 0

func _count_lit(st) -> int:
	var d: PackedInt32Array = st.depths()
	var out := 0
	for x in d:
		if x >= 0:
			out += 1
	return out

func _joins(st) -> int:
	var out := 0
	for i in st.n * st.n:
		if st.matched(i, Gen.E):
			out += 1
		if st.matched(i, Gen.S):
			out += 1
	return out

## A closed loop: more joins than a forest over the same cells allows.
func _has_loop(st) -> bool:
	var cells: int = st.n * st.n
	var parent := PackedInt32Array()
	parent.resize(cells)
	for i in cells:
		parent[i] = i
	for i in cells:
		for side in [Gen.E, Gen.S]:
			if not st.matched(i, side):
				continue
			var j: int = i + 1 if side == Gen.E else i + st.n
			var a := _find(parent, i)
			var b := _find(parent, j)
			if a == b:
				return true
			parent[a] = b
	return false

func _find(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x
