extends SceneTree

## Shots of Yarn Hoop, played through the board's own input path (a touch
## pressed, dragged pin to pin and let go). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_hoop.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the entrance and the bare hoop); `play` (one long greedy
## drag that closes panel after panel, shot mid-knit and with the combo up);
## `howto` (the tutorial sheet as a first open shows it);
## `solve` (all but the last few sides threaded through the state, the rest
## dragged, the win and the seal). Frames go to <dir>/yh_<mode>_d<level>_<n>.png;
## every mode prints the peak draw calls and the mean frame from 0.5 s on.

var _t := 0.0
var _level := 0
var _mode := "rest"
var _reduce := false
var _dir := "/tmp"
var _menu: Node
var _host: Node
var _puzzle: Node
var _opened := false
var _plan: Array = []
var _n := 0
var _end := 4.0
var _ms_sum := 0.0
var _ms_n := 0
var _draws_max := 0
var _walk: Array = []
var _walk_at := 0.0

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_level = int(a.substr(2))
		elif a == "rm":
			_reduce = true
		elif a.begins_with("out="):
			_dir = a.substr(4)
		else:
			_mode = a
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_yh_progress.cfg"))
	progress.path = "user://_shot_yh_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		if not (_mode == "howto" and e.id == "hoop"):
			progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		_opened = true
		_t = 0.0
		var entry: Dictionary = {}
		for e in load("res://ui/registry.gd").PUZZLES:
			if e.id == "hoop":
				entry = e
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		_puzzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _host.has_node("HowToPlay") and _mode != "howto":
			_host.get_node("HowToPlay").free()
		_script()
		return false
	while not _plan.is_empty() and float(_plan[0][0]) <= _t:
		var step: Array = _plan.pop_front()
		(step[1] as Callable).call()
	_drive()
	if _t >= 0.5 and _t < _end:
		_ms_sum += delta * 1000.0
		_ms_n += 1
		_draws_max = maxi(_draws_max, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= _end:
		print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		var st = _puzzle.state
		print("board: band %d %s panels %d/%d pins %d sides %d refused %d best %d done %s pill '%s' hints %d" % [st.band, st.name_key,
			st.done, st.panels.size(), st.pins.size(), st.sides.size(), st.refused, _puzzle._best, _puzzle.is_done(), _puzzle.pill_text(), _puzzle.hints_left()])
		print("share:\n", _puzzle.share_glyphs())
		load("res://core/motion.gd").reduce = false
		quit()
		return true
	return false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/yh_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  t ", snappedf(_t, 0.01), " done ", _puzzle.state.done, " combo ", _puzzle._combo_n,
		" draws ", int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))

func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = at
	_puzzle._gui_input(ev)

func _move(at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = at
	_puzzle._gui_input(ev)

## A greedy walk from the pin of the panel nearest done: at each pin the
## open side whose panel has the fewest sides open, `steps` long.
func _greedy(steps: int) -> Array:
	var st = _puzzle.state
	var start := -1
	var best := 1 << 20
	for k in st.panels.size():
		if not st.filled[k] and st.open_sides[k] < best:
			best = st.open_sides[k]
			for v in st.panels[k]:
				if st.pin_open[v] > 0:
					start = v
	var path := [start]
	var laid := {}
	var cur := start
	for m in steps:
		var pick := -1
		var pick_open := 1 << 20
		for s in st.pin_sides[cur]:
			if st.laid[s] or laid.has(s):
				continue
			for k in st.side_panels[s]:
				if st.open_sides[k] < pick_open:
					pick_open = st.open_sides[k]
					pick = s
		if pick < 0:
			# nothing open here: along a threaded side to a pin that has
			for s in st.pin_sides[cur]:
				var sd0: Vector2i = st.sides[s]
				var nb: int = sd0.y if sd0.x == cur else sd0.x
				for s2 in st.pin_sides[nb]:
					if not st.laid[s2] and not laid.has(s2):
						pick = s
				if pick >= 0:
					break
			if pick < 0:
				break
		laid[pick] = true
		var sd: Vector2i = st.sides[pick]
		cur = sd.y if sd.x == cur else sd.x
		path.append(cur)
	return path

func _script() -> void:
	match _mode:
		"howto":
			_at(2.0, _shot)
			_at(4.5, _shot)
			_end = 5.0
		"rest":
			_at(0.6, _shot)
			_at(1.8, _shot)
			_end = 2.4
		"play":
			_at(1.4, func() -> void:
				_walk = _greedy(22)
				_walk_at = _t
				_touch(_puzzle.pin_screen(_walk[0]), true))
			for k in 4:
				_at(2.1 + k * 0.45, _shot)
			_end = 4.6
		"solve":
			_at(1.2, func() -> void:
				var st = _puzzle.state
				# every side threaded but those of the four panels nearest
				# the picture's middle
				var mid: Vector2 = st.centre(0)
				var near: Array = range(st.panels.size())
				var c := Vector2.ZERO
				for p in st.pins:
					c += p
				c /= st.pins.size()
				near.sort_custom(func(a: int, b: int) -> bool: return st.centre(a).distance_to(c) < st.centre(b).distance_to(c))
				var keep := {}
				for k in near.slice(0, 4):
					for s in st.panel_sides[k]:
						keep[s] = true
				for s in st.sides.size():
					if not keep.has(s):
						st.lay_side(s)
				_puzzle._deal()
				_walk = _greedy(12)
				_walk_at = _t
				_touch(_puzzle.pin_screen(_walk[0]), true))
			for t in [2.2, 2.9, 3.6, 5.5]:
				_at(t, _shot)
			_end = 6.0

## The finger along `_walk`, a pin every 0.12 s, a few drag events between.
func _drive() -> void:
	if _walk.is_empty():
		return
	var u := (_t - _walk_at) / 0.12
	var i := int(u)
	if i >= _walk.size() - 1:
		_move(_puzzle.pin_screen(_walk[-1]))
		_touch(_puzzle.pin_screen(_walk[-1]), false)
		_walk = []
		if _mode == "solve" and not _puzzle.is_done():
			_walk = _greedy(12)
			_walk_at = _t
			_touch(_puzzle.pin_screen(_walk[0]), true)
		return
	var a: Vector2 = _puzzle.pin_screen(_walk[i])
	var b: Vector2 = _puzzle.pin_screen(_walk[i + 1])
	_move(a.lerp(b, u - i))
