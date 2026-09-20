extends SceneTree

## What a **moving** frame of Fairy Lights costs, per band: the board rebuilds
## its whole mesh on every frame while anything is animating (the spin, the
## wash, a lantern waking -- see the board's header), so this times that
## rebuild directly rather than inferring it from a frame time.
##
##     godot --path . --resolution 810x1440 --script tests/_probe_fairy_frame.gd
##
## **Run it windowed and at that resolution**, like every other harness here:
## the cell is 188/157/134 only in the design space that flag produces, and
## `_build`'s arcs are tessellated off the cell, so a bigger cell costs more
## (the first reading of this probe, headless on a 297 cell, came back at
## 21 ms against the 9 the real 157 costs).
##
## It deals one board a band off a fixed seed and times `_build` and `_dress`
## over sixty calls each. The day's own board is not the seed's: how much of
## the garden is live moves the figure, because a live run draws two halo
## passes and a sheen the dark wire does not.

var _t := -0.2
var _menu: Node
var _p: Node
var _opened := false

func _initialize() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		if _t < 0.0:
			return false
		_opened = true
		for e in load("res://ui/registry.gd").PUZZLES:
			if e.id == "fairylights":
				_menu._open(e)
		var host = _menu.get_child(_menu.get_child_count() - 1)
		_p = host._puzzle
		return false
	# The chrome has to have slid in and the board been laid out before the
	# cell is the cell.
	if _t < 0.6:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	var reps := 60
	for band in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		_p.build(rng, band)
		_p._refresh()
		var t0 := Time.get_ticks_usec()
		for i in reps:
			_p._build(now)
		var build_us := float(Time.get_ticks_usec() - t0) / reps
		t0 = Time.get_ticks_usec()
		for i in reps:
			_p._dress(now)
		var dress_us := float(Time.get_ticks_usec() - t0) / reps
		print("band=%d n=%d cell=%.0f  _build=%.2f ms  _dress=%.2f ms"
			% [band, _p.state.n, _p._cell, build_us / 1000.0, dress_us / 1000.0])
	return true
