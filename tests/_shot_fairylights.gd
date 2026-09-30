extends SceneTree

## Shots and probes of Fairy Lights, played through the board's own input
## path (a press on a piece, a release). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_fairylights.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the entrance and the wash; the sway at rest), `press` (a
## finger held on a piece, then let go: the dip and the turn), `fuse` (Hard or
## Insane: a right piece tapped -- the start of the turn, the sparks, the
## brown-out, the heart splitting, the swing back and the clip -- then the
## clipped piece tapped again), `out` (fuses until the hearts run out: the
## dark pulled back to the post, the dusk, the card, Try again), `tags`
## (Insane: the tags at rest, then most of the garden wired to its answer so
## tags read gold, and one tag poked to read rose), `howto` (the first-play
## sheet's diagram) and `restore` (a solved day reopened with a clip and a
## heart gone). Frames go to <dir>/fl_<mode>_d<level>_<n>.png. Every mode
## prints the peak draw calls from 0.5 s on.

const SHOT_DIR := "/tmp"

var _t := 0.0
var _level := 0
var _mode := "rest"
var _reduce := false
var _dir := SHOT_DIR
var _menu: Node
var _host: Node
var _puzzle: Node
var _opened := false
var _plan: Array = []
var _n := 0
var _end := 4.0
var _ms_from := 0.5
var _ms_sum := 0.0
var _ms_n := 0
var _draws_max := 0

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_fl_progress.cfg"))
	progress.path = "user://_shot_fl_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		if _mode == "howto" and e.id == "fairylights":
			continue
		progress.mark_tutorial_seen(String(e.id))
	if _reduce:
		load("res://core/motion.gd").reduce = true
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
			if e.id == "fairylights":
				entry = e
		# Settings load after _initialize, so reduce motion is set here, right
		# before the board opens.
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _host.has_node("HowToPlay") and _mode != "howto":
			_host.get_node("HowToPlay").free()
		_script()
		return false
	while not _plan.is_empty() and float(_plan[0][0]) <= _t:
		var step: Array = _plan.pop_front()
		(step[1] as Callable).call()
	if _t >= _ms_from and _t < _end:
		_ms_sum += delta * 1000.0
		_ms_n += 1
		_draws_max = maxi(_draws_max, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= _end:
		if _ms_n > 0:
			print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		var st = _puzzle.state
		print("board: %dx%d band %d, cell %.1f, lanterns %d, tags %d, banked %s, judged %s, hearts %d/%d, out %s, done %s, hints %d, clips %d, turns %d" % [
			st.n, st.n, st.band, _puzzle._cell, st.lanterns().size(), st.tags.size(), st.banked,
			st.judged, _puzzle.hearts, _puzzle.max_hearts, _puzzle.out_of_hearts, _puzzle.is_done(),
			_puzzle.hints_left(), st.clips(), st.turns])
		print("tip: ", _puzzle.tip_line().text)
		quit()
		return true
	return false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/fl_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text)

# --- the hand ---

func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	_puzzle._gui_input(ev)

func _tap(i: int) -> void:
	var at: Vector2 = _puzzle.cell_centre(i)
	_mouse(at, true)
	_mouse(at, false)

## A piece that is already right and can be turned (not a cross, not pinned,
## not clipped), nearest the post first so its fuse shows a live run.
func _right_piece() -> int:
	var st = _puzzle.state
	var Gen = load("res://puzzles/fairy_lights_gen.gd")
	var best := -1
	var best_d := 1 << 30
	var depths: PackedInt32Array = st.depths()
	for i in st.n * st.n:
		if st.grid[i] != st.sol[i] or st.pinned[i] == 1 or st.clipped[i] == 1:
			continue
		if st.grid[i] == Gen.N | Gen.E | Gen.S | Gen.W or i == st.post:
			continue
		var d: int = depths[i] if depths[i] >= 0 else 1000
		# A wire piece on the live run reads the brown-out best.
		if st.lanterns().has(i):
			d += 500
		if d < best_d:
			best_d = d
			best = i
	return best

## A probe's shortcut: every cell within `depth` of the post along the
## answer's tree put on its answer, and the wash run over it, so a fuse has a
## live run to brown out.
func _prewire(depth: int) -> void:
	var st = _puzzle.state
	var before: PackedInt32Array = st.depths()
	var keep: PackedInt32Array = st.grid.duplicate()
	st.grid = st.sol.duplicate()
	var sol_d: PackedInt32Array = st.depths()
	st.grid = keep
	for i in st.n * st.n:
		if sol_d[i] >= 0 and sol_d[i] <= depth and st.pinned[i] == 0:
			st.grid[i] = st.sol[i]
	_puzzle._settle(before, _puzzle._now())
	_puzzle._refresh()

## A piece that is wrong, so a tap turns it.
func _wrong_piece() -> int:
	var st = _puzzle.state
	for i in st.n * st.n:
		if st.grid[i] != st.sol[i] and st.pinned[i] == 0 and st.clipped[i] == 0:
			return i
	return -1

func _script() -> void:
	var st = _puzzle.state
	match _mode:
		"rest":
			_at(0.3, _shot.bind("_enter"))
			_at(0.9, _shot.bind("_wash"))
			_at(2.4, _shot)
			_at(3.3, _shot.bind("_sway"))
			_end = 3.5
		"press":
			var i := _wrong_piece()
			_at(1.5, func() -> void: _mouse(_puzzle.cell_centre(i), true))
			_at(1.7, _shot.bind("_down"))
			_at(1.75, func() -> void: _mouse(_puzzle.cell_centre(i), false))
			_at(1.85, _shot.bind("_turn"))
			_at(2.4, _shot.bind("_after"))
			_end = 2.6
		"fuse":
			_prewire(4)
			var i := _right_piece()
			print("right piece %d of %d, hearts %d" % [i, st.n * st.n, _puzzle.hearts])
			_at(1.8, _tap.bind(i))
			for dt in [0.08, 0.2, 0.25, 0.37, 0.5, 0.72, 0.86, 1.0, 1.6]:
				_at(1.8 + dt, _shot.bind("_%03d" % int(dt * 100)))
			_at(3.6, func() -> void:
				print("fuse over: hearts %d clips %d busy %s" % [_puzzle.hearts, st.clips(), _puzzle.busy()])
				_tap(i))
			_at(3.68, _shot.bind("_clipped"))
			_end = 3.9
		"out":
			_prewire(5)
			var hearts: int = _puzzle.hearts
			for k in hearts:
				_at(1.5 + k * 1.5, func() -> void:
					var i := _right_piece()
					print("fuse %d at %d" % [k, i])
					_tap(i))
			var t_out := 1.5 + (hearts - 1) * 1.5 + 1.15
			_at(t_out + 0.25, _shot.bind("_dark"))
			_at(t_out + 0.6, _shot.bind("_dark2"))
			_at(t_out + 1.6, _shot.bind("_card"))
			_at(t_out + 1.8, func() -> void:
				if _puzzle.out_of_hearts:
					_puzzle.try_again()
				print("after try again: hearts %d out %s clips %d moves %d" % [
					_puzzle.hearts, _puzzle.out_of_hearts, st.clips(), _puzzle.moves]))
			_at(t_out + 2.0, _shot.bind("_wave"))
			_at(t_out + 3.2, _shot)
			_end = t_out + 3.4
		"tags":
			_at(2.0, _shot)
			_at(2.3, func() -> void:
				# Most of the garden wired to its answer, so the tags light and
				# read; one tag poked two off so it reads rose.
				var keep: int = -1
				for i in st.n * st.n:
					if st.grid[i] != st.sol[i] and st.pinned[i] == 0:
						keep = i
				st.grid = st.sol.duplicate()
				if keep >= 0 and not st.tags.has(keep):
					st.grid[keep] = st.deal[keep]
				var keys: Array = st.tags.keys()
				if keys.size() > 1:
					st.tags[keys[1]] = int(st.tags[keys[1]]) + 2
				_puzzle._live_at.fill(-1.0e9)
				_puzzle._wake_at.fill(-1.0e9)
				_puzzle._dress(_puzzle._now())
				_puzzle._refresh()
				print("tags: ", st.tags, " states ", keys.map(func(k): return st.tag_state(int(k)))))
			_at(3.0, _shot.bind("_lit"))
			_end = 3.2
		"howto":
			_ms_from = 9.0
			# The loop restarts from the diagram's own tween; shots across one.
			for k in 10:
				_at(4.2 + k * 0.2, _shot)
			_end = 6.4
		"restore":
			_at(1.5, func() -> void:
				var i := _right_piece()
				_puzzle.completed_record = {"hearts": maxi(0, _puzzle.max_hearts - 1), "clips": [i] if i >= 0 else []}
				_puzzle.restore_completed())
			_at(2.0, _shot)
			_end = 2.2
