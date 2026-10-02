extends SceneTree

## How much a frame of Caterpillar costs on the CPU as the body grows: the
## live and top meshes rebuilt while it walks. Headless:
##     godot --headless --path . --script res://tests/_probe_cat_perf.gd -- [d=3]

var _b: Control
var _frames := 0
var _d := 3

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_d = int(a.substr(2))
	_b = load("res://puzzles/caterpillar2d.gd").new()
	_b.size = Vector2(760, 900)
	root.add_child(_b)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		_b.build(rng, _d)
		_b._opened -= 100.0
		var st = _b._state
		for n in [1, 8, 16, 32, st.size() - 2]:
			st.body = st.path.slice(0, n)
			_b._seg_at.clear()
			for i in n:
				_b._seg_at.append(-100.0)
			var reps := 20
			var t0 := Time.get_ticks_usec()
			for r in reps:
				_b._walked_at = _b._now()
				_b._ripples.append(_b._now())
				_b._refresh()
				if _b._under == null:
					_b._under = _b._build_under(_b._now())
					_b._over = _b._build_over(_b._now())
				_b._build_body(_b._now())
				_b._build_top(_b._now())
			var us := float(Time.get_ticks_usec() - t0) / reps
			print("d=%d len=%d frame_cpu=%.2f ms" % [_d, n, us / 1000.0])
		return true
	return false
