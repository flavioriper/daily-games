extends SceneTree

## Throwaway: what Fairy Lights' generator actually costs in GDScript on this
## Mac. The spec's section 4.3 carried a JavaScript reading scaled by
## Sudoku's port ratio, explicitly labelled an estimate; this replaces it with
## a real one. Two hundred seeds a band: mean and worst trees grown, mean and
## worst wall clock for the whole build(), and how many boards came back
## proved.
##
## The work runs from _process and not _initialize: headless, _ready is
## deferred, and a SceneTree script that measures during _initialize is
## measuring a tree that has not entered yet.
##
## Run: godot --headless --path . --script tests/_probe_fairy_gen.gd

const Gen = preload("res://puzzles/fairy_lights_gen.gd")
const SEEDS := 200

func _process(_delta: float) -> bool:
	print("Fairy Lights generator, %d seeds a band" % SEEDS)
	for band in 3:
		var n: int = Gen.SIZES[band]
		var cells := n * n
		var att_sum := 0
		var att_worst := 0
		var ms_sum := 0.0
		var ms_worst := 0.0
		var ms_worst_seed := -1
		var proved := 0
		var deal_ok := 0
		var lit_worst := 0
		for i in range(SEEDS):
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + band * 10000 + i
			var t0 := Time.get_ticks_usec()
			var out: Dictionary = Gen.build(rng, band)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			att_sum += out.attempts
			att_worst = maxi(att_worst, out.attempts)
			ms_sum += ms
			if ms > ms_worst:
				ms_worst = ms
				ms_worst_seed = int(rng.seed)
			if out.proved:
				proved += 1
			# Both of the deal's conditions, read back off what was handed
			# over rather than taken on trust from inside the generator.
			var turnable := 0
			var wrong := 0
			for c in range(cells):
				if Gen.rotations(out.sol[c]).size() > 1:
					turnable += 1
				if out.deal[c] != out.sol[c]:
					wrong += 1
			var lit := _live(n, out.post, out.deal)
			lit_worst = maxi(lit_worst, lit)
			if wrong >= int(ceil(turnable * Gen.WRONG_SHARE)) and lit <= int(cells * Gen.LIVE_SHARE):
				deal_ok += 1
		print("  band %d (%dx%d): attempts mean %.3f worst %d | build mean %.3f ms worst %.3f ms (seed %d) | proved %d/%d | deal met both %d/%d | worst lit %d of %d (cap %d)" % [
			band, n, n,
			float(att_sum) / SEEDS, att_worst,
			ms_sum / SEEDS, ms_worst, ms_worst_seed,
			proved, SEEDS, deal_ok, SEEDS,
			lit_worst, cells, int(cells * Gen.LIVE_SHARE)])
	quit(0)
	return true

static func _live(n: int, post: int, cur: PackedInt32Array) -> int:
	var seen := {post: true}
	var queue: Array[int] = [post]
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		for d in range(4):
			if cur[i] & (1 << d) == 0:
				continue
			var a: int = i / n + Gen.DR[d]
			var b: int = i % n + Gen.DC[d]
			if a < 0 or b < 0 or a >= n or b >= n:
				continue
			var j: int = a * n + b
			if seen.has(j) or cur[j] & (1 << ((d + 2) % 4)) == 0:
				continue
			seen[j] = true
			queue.append(j)
	return seen.size()
