extends SceneTree

## Hedgehogs' generator, timed and checked: forty seeds a level, the mean and
## worst wall time in GDScript, the deals it took, the opening's range, and
## every lawn re-proved from scratch -- the opening clear, every number right,
## logic raking every bare cell, the subset quota met or the board marked
## ungraded. A harness, not a suite entry.
##     godot --headless --path . --script tests/_probe_hedgehogs_gen.gd
const G := preload("res://puzzles/hedgehogs_gen.gd")

func _initialize() -> void:
	var failures := 0
	for d in 4:
		var bd := G.band(d)
		var worst := 0.0
		var sum := 0.0
		var att_max := 0
		var att_sum := 0
		var lo := 999
		var hi := 0
		var ungraded := 0
		var sub_sum := 0
		var cnt := 40
		for s in cnt:
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 7919 + d
			var t0 := Time.get_ticks_usec()
			var g := G.generate(rng, d)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			worst = maxf(worst, ms)
			sum += ms
			if g.is_empty():
				print("FAIL d=%d seed=%d: no board at all" % [d, s])
				failures += 1
				continue
			att_max = maxi(att_max, int(g.attempts))
			att_sum += int(g.attempts)
			lo = mini(lo, int(g.opened))
			hi = maxi(hi, int(g.opened))
			if not g.graded:
				ungraded += 1
			sub_sum += int(g.proof.sub)
			failures += _check(g, bd, d, s)
		print("d=%d %dx%d k=%d: mean %.1f ms, worst %.1f ms; deals mean %.1f, worst %d; opening %d-%d; subset rounds mean %.2f; ungraded %d/%d" % [
			d, bd.cols, bd.rows, bd.k, sum / cnt, worst, float(att_sum) / cnt, att_max, lo, hi, float(sub_sum) / cnt, ungraded, cnt])
	print("PROBE %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit()

## Re-checks one lawn from its hedgehogs alone.
func _check(g: Dictionary, bd: Dictionary, d: int, s: int) -> int:
	var bad := 0
	var hog: PackedByteArray = g.hog
	var total := 0
	for c in int(g.n):
		total += hog[c]
	if total != int(bd.k):
		print("FAIL d=%d seed=%d: %d hedgehogs, not %d" % [d, s, total, bd.k])
		bad += 1
	var cols: int = g.cols
	var sx: int = int(g.start) % cols
	var sy: int = int(g.start) / cols
	for c in int(g.n):
		if hog[c] == 1 and absi(c % cols - sx) <= 1 and absi(c / cols - sy) <= 1:
			print("FAIL d=%d seed=%d: a hedgehog in the opening" % [d, s])
			bad += 1
		if hog[c] == 0:
			var want := 0
			for r in G.neighbours(cols, g.rows, c):
				want += hog[r]
			if int(g.num[c]) != want:
				print("FAIL d=%d seed=%d: cell %d says %d, not %d" % [d, s, c, g.num[c], want])
				bad += 1
	var p := G.prove(g, bd.subsets)
	if not p.ok:
		print("FAIL d=%d seed=%d: logic cannot play it out" % [d, s])
		bad += 1
	if not bool(bd.subsets) and int(p.sub) > 0:
		print("FAIL d=%d seed=%d: needs a subset on a level without them" % [d, s])
		bad += 1
	if g.graded and int(p.sub) < int(bd.need_sub):
		print("FAIL d=%d seed=%d: graded but short of the subset quota" % [d, s])
		bad += 1
	return bad
