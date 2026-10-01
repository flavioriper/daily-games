extends SceneTree

## Mines Marigold's Insane gardens, Sweethearts (spec
## docs/superpowers/specs/2026-10-01-marigold-polish-design.md, section 3).
##
## A garden's buds are dealt as on Insane, every one a bluebell but the
## clover. Then six shots are played from the opening: each sweeps the fan,
## takes one of the angles that blooms the most plain buds, and ties two
## pairs of sweethearts out of what that shot bloomed -- the two buds farthest
## apart, then the next two. Those twelve pairs are the garden's marigolds,
## so every pair can be bloomed together, and the six shots (`proof`) bloom
## them all. The entry is kept at full precision (a shot is chaotic: rounding
## the buds to a thousandth lost the proof), read back through
## State.from_bank and replayed; one that does not solve is dropped.
##
##     godot --headless --script res://tools/mine_marigold_sweethearts.gd -- <first seed> <count> <out.json>

const State = preload("res://puzzles/marigold_state.gd")
const SHOTS := 6
const PAIRS_A_SHOT := 2
## Sweethearts stand at least this far apart, in field units.
const APART := 22.0
const FAN := 96

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var count := int(args[1]) if args.size() > 1 else 10
	var out_path := String(args[2]) if args.size() > 2 else "/tmp/marigold_sweethearts.json"
	var boards: Array = []
	for n in count:
		var t0 := Time.get_ticks_msec()
		var d := _mine(first + n)
		if d.is_empty():
			print("seed %d: dropped (%d ms)" % [first + n, Time.get_ticks_msec() - t0])
			continue
		boards.append(d)
		print("seed %d: kept, openers %d, ms %d" % [first + n, int(d.openers), Time.get_ticks_msec() - t0])
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"boards": boards}, "", false, true))
		f.close()
	print("kept %d of %d" % [boards.size(), count])
	quit()

func _mine(seed_n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n * 7919 + 13
	var st = State.new()
	st.build(rng, 3)
	for i in st.kind0.size():
		if st.kind0[i] == State.ORANGE:
			st.kind0[i] = State.BLUE
	st.orange_total = 0
	st._begin()
	var pairs := {}
	var proof: Array = []
	for shot in SHOTS:
		var best: Array = []
		for k in FAN + 1:
			var a := lerpf(State.AIM_MIN + 0.02, PI - State.AIM_MIN - 0.02, float(k) / float(FAN))
			var order: PackedInt32Array = st.shot_order(a)
			var plain: Array = []
			for i in order:
				if st.kind[i] == State.BLUE and not pairs.has(i):
					plain.append(i)
			var tied := _tie(st, plain)
			if tied.size() == PAIRS_A_SHOT * 2:
				best.append({"a": a, "n": plain.size(), "tied": tied})
		if best.is_empty():
			print("  shot %d: no angle ties two pairs" % shot)
			return {}
		# one of the better shots, not always the best, so the gardens vary
		best.sort_custom(func(x, y): return int(x.n) > int(y.n))
		var pick: Dictionary = best[rng.randi_range(0, mini(best.size() - 1, maxi(2, best.size() / 4)))]
		var tied: Array = pick.tied
		for k in range(0, tied.size(), 2):
			pairs[tied[k]] = tied[k + 1]
			pairs[tied[k + 1]] = tied[k]
			for i in [tied[k], tied[k + 1]]:
				st.kind[i] = State.ORANGE
				st.kind0[i] = State.ORANGE
		proof.append(pick.a)
		st.fire(pick.a)
		var guard := 0
		while not st.balls.is_empty() and guard < 240 * 40:
			st.step([])
			guard += 1
		st.end_shot()
	var flat: Array = []
	var kinds: Array = []
	var pair_of: Array = []
	for i in st.pos.size():
		flat.append(st.pos[i].x)
		flat.append(st.pos[i].y)
		kinds.append(int(st.kind0[i]))
		pair_of.append(int(pairs.get(i, -1)))
	var d := {"pos": flat, "kind": kinds, "pair": pair_of, "proof": proof,
		"violet": rng.randi() % 100000}
	if not _replays(d):
		print("  the replay does not solve")
		return {}
	d.openers = _openers(d)
	return d

## Two pairs out of a shot's plain buds: the two farthest apart, then the
## next two, each at least APART.
func _tie(st, plain: Array) -> Array:
	var left := plain.duplicate()
	var out: Array = []
	for n in PAIRS_A_SHOT:
		var far := -1.0
		var bi := -1
		var bj := -1
		for x in left.size():
			for y in range(x + 1, left.size()):
				var dd: float = st.pos[left[x]].distance_to(st.pos[left[y]])
				if dd > far:
					far = dd
					bi = x
					bj = y
		if far < APART:
			return []
		out.append(left[bi])
		out.append(left[bj])
		left.remove_at(bj)
		left.remove_at(bi)
	return out

## The entry as it ships: read back and played with its proof, it must
## bloom every pair.
func _replays(d: Dictionary) -> bool:
	var st = State.new()
	if not st.from_bank(d):
		return false
	for a in st.proof:
		st.fire(float(a))
		var guard := 0
		while not st.balls.is_empty() and guard < 240 * 40:
			st.step([])
			guard += 1
		st.end_shot()
	return st.oranges_left == 0

## How many single shots from the opening bloom at least one pair: a feel
## for how hard the garden is to start.
func _openers(d: Dictionary) -> int:
	var st = State.new()
	st.from_bank(d)
	var n := 0
	for k in 65:
		var a := lerpf(State.AIM_MIN + 0.02, PI - State.AIM_MIN - 0.02, float(k) / 64.0)
		var order: PackedInt32Array = st.shot_order(a)
		var lit := {}
		for i in order:
			lit[i] = true
		for i in order:
			if st.kind[i] == State.ORANGE and lit.has(st.pair[i]):
				n += 1
				break
	return n
