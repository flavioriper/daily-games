extends SceneTree

## Mines Super Slider's Insane bank, Homesick (content/insane/slider.json):
## the big block never steps back up, so a tray can be lost. Walks random
## layouts like tools/mine_slider.gd, takes each one's whole (two-way) graph,
## then walks every position's Homesick moves -- a subset, since only the
## big block's upward steps are gone -- and runs one pass backwards from the
## goals over them, so every position's Homesick distance is known at once.
## Keeps a few positions a graph within DEEP_SLACK of its deepest, at least
## MIN_PAR deep, each re-proved by the phone's own `distances(..., true)`
## from the position itself.
##
## A graph is kept only if a fair share of the big block's moves in it lead
## nowhere (DOOM_MIN): that is what makes the band losable.
##   godot --headless --script tools/mine_slider_homesick.gd -- <seed> <seconds> <out.json>
## then python3 tools/merge_slider_homesick.py <out.json> ...

const Gen = preload("res://puzzles/slider_gen.gd")
const Mine = preload("res://tools/mine_slider.gd")

const MIN_PAR := 60
const DEEP_SLACK := 8
const PER_GRAPH := 4
const DOOM_MIN := 0.08
const CAP := 120000

func _process(_d: float) -> bool:
	var args := OS.get_cmdline_user_args()
	var seed_ := int(args[0]) if args.size() > 0 else 1
	var seconds := int(args[1]) if args.size() > 1 else 600
	var out_path := String(args[2]) if args.size() > 2 else "/tmp/slider_home.json"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var miner = Mine.new()
	var kept := {}
	var seen_graphs := {}
	var t0 := Time.get_ticks_msec()
	var graphs := 0
	while Time.get_ticks_msec() - t0 < seconds * 1000:
		var k: int = miner._layout(rng)
		if k < 0:
			continue
		var r := Gen.distances(k, CAP)
		if r.is_empty():
			continue
		var smallest: int = r.keys[0]
		for x in r.keys:
			smallest = mini(smallest, x)
		if seen_graphs.has(smallest):
			continue
		seen_graphs[smallest] = true
		graphs += 1
		var h := _homesick(r)
		var dist: PackedInt32Array = h.dist
		var far := 0
		for d in dist:
			far = maxi(far, d)
		if far < MIN_PAR or float(h.doom) < DOOM_MIN:
			continue
		var deep: Array = []
		for i in dist.size():
			if dist[i] >= maxi(MIN_PAR, far - DEEP_SLACK):
				deep.append(i)
		deep.shuffle()
		for i: int in deep.slice(0, PER_GRAPH):
			var start: int = r.keys[i]
			var proof := Gen.distances(start, CAP, {}, true)
			if proof.is_empty() or int(proof.dist[0]) != dist[i]:
				print("  proof disagrees: %d vs %s" % [dist[i], "cap" if proof.is_empty() else str(proof.dist[0])])
				continue
			kept[Gen.encode(mini(start, Gen.mirror(start)))] = {"p": dist[i], "n": proof.keys.size(), "doom": snappedf(float(h.doom), 0.001)}
		_write(kept, out_path)
		print("%d graphs, %d s, kept %d (far %d, doom %.2f)" % [graphs, (Time.get_ticks_msec() - t0) / 1000, kept.size(), far, h.doom])
	_write(kept, out_path)
	print("wrote ", out_path)
	return true

## Every position's Homesick distance in a two-way graph, and the share of
## the big block's moves from a live position that lead to a dead one.
static func _homesick(r: Dictionary) -> Dictionary:
	var keys: PackedInt64Array = r.keys
	var index: Dictionary = r.index
	var n := keys.size()
	var at := PackedInt32Array()
	var to := PackedInt32Array()
	var nbr := PackedInt64Array()
	var queue := PackedInt32Array()
	queue.resize(Gen.N)
	for i in n:
		at.append(to.size())
		nbr.clear()
		Gen._next_keys(keys[i], nbr, queue, true)
		for nk in nbr:
			to.append(index[nk])
	at.append(to.size())
	var back := Gen._reversed(at, to)
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var q := PackedInt32Array()
	for i in n:
		if Gen.is_goal(keys[i]):
			dist[i] = 0
			q.append(i)
	var hd := 0
	while hd < q.size():
		var u: int = q[hd]
		hd += 1
		for e in range(back[0][u], back[0][u + 1]):
			var v: int = back[1][e]
			if dist[v] < 0:
				dist[v] = dist[u] + 1
				q.append(v)
	var red_moves := 0
	var red_doom := 0
	for u in n:
		if dist[u] <= 0:
			continue
		var ru := _big(keys[u])
		for e in range(at[u], at[u + 1]):
			var v: int = to[e]
			if _big(keys[v]) != ru:
				red_moves += 1
				if dist[v] < 0:
					red_doom += 1
	return {"dist": dist, "doom": float(red_doom) / maxf(1.0, float(red_moves))}

static func _big(k: int) -> int:
	for i in Gen.N:
		if (k >> (3 * i)) & 7 == Gen.B0:
			return i
	return -1

func _write(kept: Dictionary, out_path: String) -> void:
	var list: Array = []
	for b in kept:
		var e: Dictionary = kept[b]
		list.append({"b": b, "p": e.p, "n": e.n, "doom": e.doom})
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"boards": list}))
	f.close()
