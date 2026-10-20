extends SceneTree

## Times Tally's per-frame work on a paper like a player's tenth level
## (the user's phone, 2026-10-20): at the default-ish zoom (k 30) sixteen
## fed adders and their digs in view, belt rows of tokens across the view,
## and ~1,800 belts of tokens out of sight for the sim's step. Prints each
## layer's fill, the sim's step and the numerals' pass, and how many
## instances each layer sets down.
##   godot --headless --path . --script tests/_perf_tally_screen.gd

const Sim = preload("res://arcade/tally_sim.gd")
const Board = preload("res://arcade/tally_board.gd")
const E := 0
const Nd := 3

var _s
var _frames := 0

func _dig1(s, at: Vector2i, v: int) -> void:
	var i := Sim._i(at)
	s.dep[i] = v
	s.kind[i] = Sim.DIG
	s.face[i] = E
	s.touch(i)
	s._wire()

func _run(s, from: Vector2i, to: Vector2i, f: int) -> void:
	var tiles := []
	var t := from
	while true:
		tiles.append(t)
		if t == to:
			break
		t += Sim.DIRS[f]
	s.lay_run(tiles, f)

func _initialize() -> void:
	Sim.path = ""
	var s = Sim.new(11)
	s.dep.fill(0)
	s.level = 40
	s.lv.belt = 8
	# sixteen adders in view, each fed by two digs, answers led north
	for band in [178, 212]:
		for c in 8:
			var m := Vector2i(187 + 3 * c, band + 4)
			s.place(Sim.ADD, m, Nd)
			for side in 2:
				var u := m + Vector2i(side, 1)
				_dig1(s, Vector2i(u.x, band + 8), 1 + side)
				_run(s, Vector2i(u.x, band + 7), u, Nd)
			_run(s, m, Vector2i(m.x, band), Nd)
	# belt rows with tokens across the view
	for y in [191, 193, 204, 206]:
		_dig1(s, Vector2i(185, y), 3)
		_run(s, Vector2i(186, y), Vector2i(214, y), E)
	# the rest of the factory, out of sight
	for y in range(100, 160, 2):
		_dig1(s, Vector2i(49, y), 2)
		_run(s, Vector2i(50, y), Vector2i(110, y), E)
	s.step(60.0)
	s.events.clear()
	var full := 0
	for q: int in s.lanes:
		full += s.occ[q]
	print("sheet: %d lanes, %d tokens, %d machines, %d digs" % [s.lanes.size(), full, s.machines.size(), s.digs.size()])
	_s = s

func _time(label: String, f: Callable, n := 20) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		f.call()
	var ms := (Time.get_ticks_usec() - t0) / (1000.0 * n)
	print("  %-14s %6.2f ms" % [label, ms])
	return ms

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		var b0 = Board.new()
		b0.name = "B"
		b0.sim = _s
		b0.size = Vector2(810, 1440)
		root.add_child(b0)
		return false
	if _frames < 3:
		return false
	var b = root.get_node("B")
	var s = _s
	b.size = Vector2(810, 1440)
	b.set_view(Rect2(0, 370, 810, 760))
	for k in [30.0, 62.0]:
		b.k = k
		b.tick(0.016)
		var seen: PackedInt32Array = b._lanes_seen()
		var toks := 0
		for q in seen:
			toks += s.occ[q]
		print("k %d: %d lanes in view, %d tokens in view" % [k, seen.size(), toks])
		var total := 0.0
		total += _time("sim.step", func(): s.step(1.0 / 60.0))
		total += _time("tick", func(): b.tick(1.0 / 60.0))
		total += _time("chevrons", func(): b._fill_chevrons())
		total += _time("tokens", func(): b._fill_tokens(false))
		total += _time("under", func(): b._fill_tokens(true))
		total += _time("pieces", func(): b._fill_pieces())
		total += _time("live", func(): b._build_live())
		total += _time("words", func(): b._draw_words())
		print("  %-14s %6.2f ms a frame; instances: chevrons %d, tokens %d, pieces %d" % ["sum", total, b.batched("chev"), b.batched("tokens"), b.batched("pieces")])
	return true
