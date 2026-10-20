extends SceneTree

## Times Tally's board on a crowded paper, headless: a sheet with a full
## belt across every fourth row (about 40,000 belts on the 400 sheet), and
## the per-frame builders (chevrons, tokens, pieces, live), the sim's step,
## an edit's wire and rebuild and a save, at the default zoom and far out.
##   godot --headless --path . --script tests/_perf_tally.gd

const Sim = preload("res://arcade/tally_sim.gd")
const Board = preload("res://arcade/tally_board.gd")

func _initialize() -> void:
	Sim.path = ""
	var s = Sim.new(9)
	s.level = 40
	s.dep.fill(0)
	var belts := 0
	for y in range(0, Sim.H, 4):
		if y >= Sim.HUB_AT.y - 1 and y <= Sim.HUB_AT.y + Sim.HUB:
			continue
		var row := []
		for x in range(1, Sim.W):
			row.append(Vector2i(x, y))
		# a one-square dig written straight on: a three-wide one would not fit every other row
		s.dep[Sim._i(Vector2i(0, y))] = 1
		s.kind[Sim._i(Vector2i(0, y))] = Sim.DIG
		s.touch(Sim._i(Vector2i(0, y)))
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
	for k in [74.0, 22.0, 8.0]:
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
	b.relay()
	b._rebuild()
	print("rebuild of the still layers in view, from nothing %.2f ms" % ((Time.get_ticks_usec() - t3) / 1000.0))
	# an edit: a short run laid at the view's middle, wired, and the board's rebuild after it
	var mid := Vector2i(Sim.HUB_AT) + Vector2i(-8, Sim.HUB + 2)
	var t4 := Time.get_ticks_usec()
	var run := []
	for n in 6:
		run.append(mid + Vector2i(n, 0))
	s.lay_path(run, 0)
	var t5 := Time.get_ticks_usec()
	b._rebuild()
	var t6 := Time.get_ticks_usec()
	print("an edit: wire %.2f ms, rebuild %.2f ms" % [(t5 - t4) / 1000.0, (t6 - t5) / 1000.0])
	Sim.path = "user://_perf_tally.cfg"
	var t7 := Time.get_ticks_usec()
	s.save()
	print("save %.2f ms" % ((Time.get_ticks_usec() - t7) / 1000.0))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sim.path))
	Sim.path = ""
	return true
