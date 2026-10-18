extends SceneTree

## Times Tally's board on a crowded paper, headless: a sheet with belts in
## most rows, every one full, and the per-frame builders (chevrons, tokens,
## pieces, live) and the sim's step, at the default zoom and far out.
##   godot --headless --path . --script tests/_perf_tally.gd

const Sim = preload("res://arcade/tally_sim.gd")
const Board = preload("res://arcade/tally_board.gd")

func _initialize() -> void:
	Sim.path = ""
	var s = Sim.new(9)
	s.level = 40
	s.dep.fill(0)
	var belts := 0
	for y in range(0, Sim.H, 2):
		if y >= Sim.HUB_AT.y - 1 and y <= Sim.HUB_AT.y + Sim.HUB:
			continue
		var row := []
		for x in range(1, Sim.W):
			row.append(Vector2i(x, y))
		# a one-square dig written straight on: a three-wide one would not fit every other row
		s.dep[Sim._i(Vector2i(0, y))] = 1
		s.kind[Sim._i(Vector2i(0, y))] = Sim.DIG
		belts += s.lay_run(row, 0)
	for x in range(3, Sim.W - 3, 6):
		s.place(Sim.ADD, Vector2i(x, 1), 0)
	s.step(60.0)
	var full := 0
	for q: int in s.lanes:
		full += s.occ[q]
	_s = s
	_belts = belts
	_full = full

var _s
var _belts := 0
var _full := 0
var _frames := 0

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
	var belts := _belts
	var full := _full
	b.size = Vector2(810, 1440)
	b.set_view(Rect2(0, 370, 810, 760))
	for k in [74.0, 22.0]:
		b.k = k
		b.tick(0.016)
		var t0 := Time.get_ticks_usec()
		for n in 20:
			b._build_chevrons()
			b._build_tokens(false)
			b._build_pieces()
			b._build_live()
		var t1 := Time.get_ticks_usec()
		print("k %d: %d belts, %d tokens: builders %.2f ms a frame" % [k, belts, full, (t1 - t0) / 20000.0])
	var t2 := Time.get_ticks_usec()
	for n in 30:
		s.step(1.0 / 60.0)
	print("sim step %.2f ms a frame" % ((Time.get_ticks_usec() - t2) / 30000.0))
	var t3 := Time.get_ticks_usec()
	b._dirty = true
	b._rebuild()
	print("rebuild of the still layers %.2f ms" % ((Time.get_ticks_usec() - t3) / 1000.0))
	return true
