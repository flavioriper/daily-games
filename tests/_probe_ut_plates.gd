extends SceneTree

## Untangle plates, headless: reversibility and parity on every plate, the
## plates' shape, and the dealer's time per band. `-- deal` adds timings,
## `-- deal=N` N seeds a plate. (On 2026-10-16 it also played the geometric
## rule against the old ring rule, from a copy of the old untangle_gen.gd,
## move for move: 7200 of 7200 equal on rings of 10, 13, 17 and 19.)

const Gen = preload("res://puzzles/untangle_gen.gd")
const Plate = preload("res://puzzles/untangle_plate.gd")

var fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_shapes()
	_reverse()
	for a in args:
		if a.begins_with("deal"):
			var n := 12
			if "=" in a:
				n = int(a.split("=")[1])
			_deals(n)
	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)

func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		if fails < 20:
			print("FAIL ", what)

func _plates() -> Array:
	var ids := []
	for band in Gen.BANDS:
		for opt in band.plates:
			ids.append(opt[0])
	return ids

func _shapes() -> void:
	for id in _plates():
		var pl: Plate = Plate.of(id)
		# How near any hole comes to the line through two others, in spacings.
		var near := INF
		for a in pl.n:
			for b in range(a + 1, pl.n):
				for c in pl.n:
					if c == a or c == b:
						continue
					var ab := pl.pts[b] - pl.pts[a]
					var dl := absf(ab.cross(pl.pts[c] - pl.pts[a])) / ab.length()
					near = minf(near, dl)
		var convex_ok := true
		if pl.convex:
			for a in pl.n:
				for b in range(a + 1, pl.n):
					for c in range(b + 1, pl.n):
						if pl.o[(a * pl.n + b) * pl.n + c] != 1:
							convex_ok = false
		_check(convex_ok, "%s holes in order round it" % id)
		print("%-10s n=%2d spacing=%.3f maxd=%.3f ext=%s nearest-to-a-line=%.4f (%.3f spacings)" % [id, pl.n, pl.spacing, pl.maxd, pl.ext, near, near / pl.spacing])

func _reverse() -> void:
	var rng := RandomNumberGenerator.new()
	var moves := 0
	for id in _plates():
		var pl: Plate = Plate.of(id)
		var ropes: int = (pl.n - 1) / 2
		for trial in 30:
			rng.seed = hash(id) + trial
			var order: Array = range(pl.n)
			order.shuffle()
			var at := PackedInt32Array()
			for p in 2 * ropes:
				at.append(order[p])
			var tw := Gen.plain_tangle(pl, at, ropes)
			for step in 40:
				var occ := Gen.occupancy(at, pl.n)
				var free := []
				for h in pl.n:
					if occ[h] < 0:
						free.append(h)
				var p := rng.randi_range(0, at.size() - 1)
				var h: int = free[rng.randi_range(0, free.size() - 1)]
				var a0 := at.duplicate()
				var t0 := tw.duplicate()
				var from := at[p]
				Gen.apply(pl, at, tw, ropes, p, h)
				# Parity is the straight lines' crossing.
				for r in ropes:
					for s in range(r + 1, ropes):
						var odd := (tw[Gen.pair_index(r, s, ropes)] >> 1) % 2 == 1
						_check(odd == pl.crosses(at[2 * r], at[2 * r + 1], at[2 * s], at[2 * s + 1]), "%s parity" % id)
				var a1 := at.duplicate()
				var t1 := tw.duplicate()
				Gen.apply(pl, a1, t1, ropes, p, from)
				_check(a1 == a0 and t1 == t0, "%s move made back" % id)
				moves += 1
	print("reversibility: %d moves" % moves)

func _deals(n: int) -> void:
	for band in Gen.BANDS.size():
		for opt in Gen.BANDS[band].plates:
			var ms := []
			var pars := []
			var cross := []
			var knots := []
			var idle := 0
			for s in n:
				var rng := RandomNumberGenerator.new()
				rng.seed = 7000 + s
				var t0 := Time.get_ticks_usec()
				var out := Gen.generate(rng, band, opt[0], opt[1])
				ms.append((Time.get_ticks_usec() - t0) / 1000.0)
				pars.append(out.par)
				cross.append(Gen.crossing_count(out.tw))
				knots.append(Gen.knots(out.tw))
				idle += opt[1] - Gen.ropes_left(out.start)
				var pl: Plate = Plate.of(out.plate)
				var won = Gen._replay(pl, out.start, out.tw, out.plan, out.ropes, out.reach)
				_check(won != null, "band %d %s seed %d answer wins" % [band, opt[0], s])
			ms.sort()
			print("band %d %-10s ms mean %.0f worst %.0f | par %s | cross %s | knots %s | idle ropes %d" % [band, opt[0],
				_mean(ms), ms.back(), _spread(pars), _spread(cross), _spread(knots), idle])

static func _mean(a: Array) -> float:
	var t := 0.0
	for v in a:
		t += float(v)
	return t / maxf(a.size(), 1)

static func _spread(a: Array) -> String:
	var b := a.duplicate()
	b.sort()
	return "%d..%d med %d" % [b[0], b.back(), b[b.size() / 2]]
