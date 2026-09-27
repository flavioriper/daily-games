extends SceneTree

## Mines Super Slider's bank (content/slider.json's candidates). Walks random
## layouts -- the big block somewhere off the gate, the rest of the tray
## filled with bars and squares in reading order, exactly two cells empty --
## takes each one's whole graph of positions and every position's distance
## to the gate (slider_gen.gd's `distances`), and keeps positions whose
## distance falls in a band: a couple a band a graph, and for the last band
## only positions near the graph's farthest, a few a graph, so the hardest
## days come from many different graphs rather than one.
##
## A position is written canonical (the lesser of it and its mirror), so a
## tray and its mirror image are one entry. Run several at once with
## different seeds, then merge with tools/merge_slider.py:
##   godot --headless --script tools/mine_slider.gd -- <seed> <graphs> <out.json>

const Gen = preload("res://puzzles/slider_gen.gd")

const PER_BAND := 2
## Insane takes up to PER_DEEP positions a graph, all within DEEP_SLACK moves
## of its farthest.
const PER_DEEP := 4
const DEEP_SLACK := 6
## The largest graph kept: a hint runs `distances` over the whole of it on
## the phone on a worker thread from the moment the tray opens, and this
## many positions is about five seconds on this Mac.
const CAP := 120000

func _process(_d: float) -> bool:
	var args := OS.get_cmdline_user_args()
	var seed_ := int(args[0]) if args.size() > 0 else 1
	var graphs := int(args[1]) if args.size() > 1 else 50
	var out_path := String(args[2]) if args.size() > 2 else "/tmp/slider_mine.json"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var bands: Array = [{}, {}, {}, {}]
	var seen_graphs := {}
	var t0 := Time.get_ticks_msec()
	var done := 0
	while done < graphs:
		var k := _layout(rng)
		if k < 0:
			continue
		var r := Gen.distances(k, CAP)
		if r.is_empty():
			continue
		# the same graph again, found from another of its positions
		var smallest: int = r.keys[0]
		for x in r.keys:
			smallest = mini(smallest, x)
		if seen_graphs.has(smallest):
			continue
		seen_graphs[smallest] = true
		done += 1
		var by_band: Array = [[], [], [], []]
		var far := 0
		for i in r.keys.size():
			var d: int = r.dist[i]
			far = maxi(far, d)
			for b in 3:
				if d >= Gen.BANDS[b].x and d <= Gen.BANDS[b].y:
					by_band[b].append(i)
		for b in 3:
			var pool: Array = by_band[b]
			for n in mini(PER_BAND, pool.size()):
				var i: int = pool[rng.randi_range(0, pool.size() - 1)]
				_keep(bands[b], r.keys[i], r.dist[i], r.keys.size())
		if far >= Gen.BANDS[3].x:
			# the deepest few: the farthest position and others near it
			var deep: Array = []
			for i in r.keys.size():
				if r.dist[i] >= maxi(Gen.BANDS[3].x, far - DEEP_SLACK):
					deep.append(i)
			deep.shuffle()
			for i: int in deep.slice(0, PER_DEEP):
				_keep(bands[3], r.keys[i], r.dist[i], r.keys.size())
		if done % 10 == 0:
			_write(bands, out_path)
			print("%d graphs, %d s, kept %d/%d/%d/%d" % [done, (Time.get_ticks_msec() - t0) / 1000,
				bands[0].size(), bands[1].size(), bands[2].size(), bands[3].size()])
	_write(bands, out_path)
	print("wrote ", out_path)
	return true

func _write(bands: Array, out_path: String) -> void:
	var doc := {"bands": []}
	for b in 4:
		var list: Array = []
		for s in bands[b]:
			list.append({"b": s, "p": bands[b][s][0], "n": bands[b][s][1]})
		doc.bands.append(list)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc))
	f.close()

func _keep(band: Dictionary, k: int, d: int, n: int) -> void:
	band[Gen.encode(mini(k, Gen.mirror(k)))] = [d, n]

## A random tray, or -1 when the fill did not leave exactly two cells empty.
func _layout(rng: RandomNumberGenerator) -> int:
	var g := PackedByteArray()
	g.resize(Gen.N)
	var big := Gen.GOAL
	while big == Gen.GOAL:
		big = rng.randi_range(0, Gen.ROWS - 2) * Gen.COLS + rng.randi_range(0, Gen.COLS - 2)
	_stamp(g, Gen.B0, big)
	var empties := 0
	for i in Gen.N:
		if g[i] != Gen.E or _taken(g, i):
			continue
		var x := i % Gen.COLS
		var y := i / Gen.COLS
		var opts: Array = [[Gen.SQ, 0.3]]
		if y + 1 < Gen.ROWS and g[i + Gen.COLS] == Gen.E and not _taken(g, i + Gen.COLS):
			opts.append([Gen.V0, 0.4])
		if x + 1 < Gen.COLS and g[i + 1] == Gen.E and not _taken(g, i + 1):
			opts.append([Gen.H0, 0.22])
		if empties < 2:
			opts.append([-1, 0.12])
		var total := 0.0
		for o: Array in opts:
			total += float(o[1])
		var pick := rng.randf() * total
		var a: int = opts[0][0]
		for o: Array in opts:
			pick -= float(o[1])
			if pick <= 0.0:
				a = o[0]
				break
		if a < 0:
			empties += 1
			_empty[i] = true
		else:
			_stamp(g, a, i)
	_empty.clear()
	if empties != 2:
		return -1
	return Gen.key_of(g)

## Cells the fill chose to leave empty, so a later shape does not take them.
var _empty := {}

func _taken(_g: PackedByteArray, i: int) -> bool:
	return _empty.has(i)

func _stamp(g: PackedByteArray, a: int, i: int) -> void:
	for c in Gen.cells(a, i):
		g[c] = Gen._part(a, c - i)
