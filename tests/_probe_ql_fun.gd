extends SceneTree
## Throwaway: how Quilt plays, 60 days a band. Counted: the spots a patch
## can lie on the bare quilt (and how many patches have only one); whether
## a player who only ever makes a forced move -- a patch with one spot left,
## or a bare square only one patch-and-spot can cover -- finishes with no
## choice made at all; and how often a player who drops any patch on any
## spot it fits ends stuck short of the solve.
const State = preload("res://puzzles/quilt_state.gd")

func _initialize() -> void:
	var days := int(OS.get_environment("QL_DAYS")) if OS.get_environment("QL_DAYS") != "" else 60
	var bands: Array = [0, 1, 2, 3] if OS.get_environment("QL_BAND") == "" else [int(OS.get_environment("QL_BAND"))]
	for band in bands:
		var spots := 0
		var patches := 0
		var single := 0
		var forced_solves := 0
		var pruned_solves := 0
		var openings := 0
		var random_stuck := 0
		var ms := 0.0
		var worst := 0.0
		var nodes := 0
		for s in days:
			var rng := RandomNumberGenerator.new()
			rng.seed = 4242 + s * 97 + band
			var st = State.new()
			var t0 := Time.get_ticks_usec()
			st.setup(rng, band, s)
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			ms += dt
			worst = maxf(worst, dt)
			for p in st.shapes.size():
				var n: int = st.legal_origins(p).size()
				spots += n
				patches += 1
				if n == 1:
					single += 1
			if _forced(st, false):
				forced_solves += 1
			if _forced(st, true):
				pruned_solves += 1
			st.reset()
			if _opening(st):
				openings += 1
			st.reset()
			var play := RandomNumberGenerator.new()
			play.seed = s * 13 + 5
			while not st.is_solved():
				var moves: Array = []
				for p in st.shapes.size():
					if int(st.at[p]) >= 0:
						continue
					for o in st.legal_origins(p):
						moves.append(Vector2i(p, o))
				if moves.is_empty():
					break
				var m: Vector2i = moves[play.randi() % moves.size()]
				st.drop(m.x, m.y, -1)
			if not st.is_solved():
				random_stuck += 1
		print("band %d: spots/patch %.1f, one-spot patches %d%%, forced alone %d/%d, pruned-forced %d/%d, opening %d/%d, random dropper stuck %d/%d, deal %.1f ms (worst %.1f)" % [
			band, float(spots) / patches, 100 * single / patches, forced_solves, days, pruned_solves, days, openings, days, random_stuck, days, ms / days, worst])
	quit()

## Plays only forced moves; true when that alone finishes the quilt.
func _forced(st, prune: bool) -> bool:
	st.reset()
	while not st.is_solved():
		var moved := false
		# a patch with one spot (scraps excluded: a scrap is never forced in)
		var free: Array = []
		for p in st.shapes.size():
			if int(st.at[p]) < 0 and int(st.answer[p]) >= 0:
				free.append(p)
		for p in free:
			var o: PackedInt32Array = _spots(st, p, prune)
			if o.size() == 1:
				st.drop(p, o[0], -1)
				moved = true
				break
		if moved:
			continue
		# a bare square only one patch-and-spot covers
		var by_cell := {}
		for p in free:
			for o in _spots(st, p, prune):
				for c in st.patch_cells(p, o):
					var k: int = c.y * st.cols + c.x
					by_cell[k] = by_cell.get(k, []) + [Vector2i(p, o)]
		for k in st.cols * st.rows:
			if st.region[k] == 1 and int(st.cover[k]) < 0:
				var opts: Array = by_cell.get(k, [])
				if opts.size() == 1:
					st.drop(opts[0].x, opts[0].y, -1)
					moved = true
					break
		if not moved:
			return false
	return true

## A patch's spots; pruned, those a player would not rule out at a glance:
## a spot that leaves a bare pocket too small for every patch left.
func _spots(st, p: int, prune: bool) -> PackedInt32Array:
	var all: PackedInt32Array = st.legal_origins(p)
	if not prune:
		return all
	var smallest := 99
	for q in st.shapes.size():
		if q != p and int(st.at[q]) < 0 and int(st.answer[q]) >= 0:
			smallest = mini(smallest, st.shapes[q].size())
	var out := PackedInt32Array()
	for o in all:
		var bare := {}
		for k in st.cols * st.rows:
			if st.region[k] == 1 and int(st.cover[k]) < 0:
				bare[k] = true
		for c in st.patch_cells(p, o):
			bare.erase(c.y * st.cols + c.x)
		if smallest == 99 or _pockets_ok(st, bare, smallest):
			out.append(o)
	return out

func _pockets_ok(st, bare: Dictionary, smallest: int) -> bool:
	var seen := {}
	for k in bare:
		if seen.has(k):
			continue
		var stack := [k]
		seen[k] = true
		var n := 0
		while not stack.is_empty():
			var c: int = stack.pop_back()
			n += 1
			var x: int = c % st.cols
			var y: int = c / st.cols
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= st.cols or ny >= st.rows:
					continue
				var nk: int = ny * st.cols + nx
				if bare.has(nk) and not seen.has(nk):
					seen[nk] = true
					stack.append(nk)
		if n < smallest:
			return false
	return true

## Whether the bare quilt has a forced first move (pruned).
func _opening(st) -> bool:
	for p in st.shapes.size():
		if int(st.answer[p]) >= 0 and _spots(st, p, true).size() == 1:
			return true
	var by_cell := {}
	for p in st.shapes.size():
		if int(st.answer[p]) < 0:
			continue
		for o in _spots(st, p, true):
			for c in st.patch_cells(p, o):
				var k: int = c.y * st.cols + c.x
				by_cell[k] = by_cell.get(k, 0) + 1
	for k in st.cols * st.rows:
		if st.region[k] == 1 and int(by_cell.get(k, 0)) == 1:
			return true
	return false
