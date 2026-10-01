extends SceneTree

## Shots and probes of Pixel Garden, played through the board's own input
## path (a press on a peg, a release). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_pixel_garden.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (half of plate 0 seated, the tweezers moved); `plate` (plate
## 0 finished right: the iron crosses it, the word, a gag); `astray` (Hard:
## plate 0 filled with one bead astray: the frown, the bead home, a heart);
## `out` (Hard: three plates astray: dusk, the card, Try again); `wind`
## (Insane: the blown pattern card, then held up over the board); `solve`
## (every peg but the last through the state, the last tapped: the win's
## iron, the party, the cat, the seal); `restore`. Frames go to
## <dir>/pg_<mode>_d<level>_<n>.png; every mode prints the peak draw calls
## and the mean frame from 0.5 s on.

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_pg_progress.cfg"))
	progress.path = "user://_shot_pg_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
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
			if e.id == "pixelgarden":
				entry = e
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _host.has_node("HowToPlay"):
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
		var st = _puzzle._state
		print("board: band ", st.band, " n ", st.n, " hearts ", _puzzle.hearts, "/", _puzzle.max_hearts,
			", out ", _puzzle.out_of_hearts, ", done ", _puzzle.is_done(), ", ironed ", st.ironed,
			", moves ", _puzzle.moves, ", hints ", _puzzle.hints_left(), ", flawless ", _puzzle._flawless,
			", perm ", st.perm, " turn ", st.turn, ", caps ", _puzzle.capabilities())
		print("share: ", _puzzle.share_glyphs())
		_cleanup()
		quit()
		return true
	return false

func _cleanup() -> void:
	for n in root.get_children():
		var card := n.find_child("OutOfHearts", true, false)
		if card != null:
			card.queue_free()
	load("res://core/motion.gd").reduce = false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/pg_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  hearts ", _puzzle.hearts, " streak ", _puzzle._streak, " words ", _puzzle._words.size(),
		" love ", _puzzle._love.size(), " flies ", _puzzle._flies.size(), " irons ", _puzzle._irons.size(),
		" toast ", _puzzle._toast, " gone ", _puzzle._pegs_gone(_puzzle._now()), " solved_at ", _puzzle._solved_at, " now ", _puzzle._now(), " gen ", _puzzle._gen)

func _mouse(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	_puzzle._gui_input(ev)

func _tap(c: int) -> void:
	var n: int = _puzzle._state.n
	var at: Vector2 = _puzzle.cell_to_local(c / n, c % n)
	_mouse(at, true)
	_mouse(at, false)

## Seats every wanted bead of plate q, but `skip` (and its bead goes onto
## `stray`, a bare peg of the plate, when one is given).
func _fill(q: int, skip := -1, stray := -1) -> void:
	var st = _puzzle._state
	for c in st.plate_pegs(q):
		if c != skip and int(st.want[c]) != -1 and int(st.beads[c]) != int(st.want[c]):
			_puzzle.set_brush(int(st.want[c]))
			_tap(c)
	if stray >= 0:
		_puzzle.set_brush(int(st.want[skip]))
		_tap(stray)

## A wanted peg and a bare one of plate q, for a bead astray.
func _astray_pair(q: int) -> Vector2i:
	var st = _puzzle._state
	var bare := -1
	var skip := -1
	for c in st.plate_pegs(q):
		if int(st.want[c]) == -1 and bare < 0:
			bare = c
		elif int(st.want[c]) != -1 and skip < 0:
			skip = c
	return Vector2i(skip, bare)

func _script() -> void:
	var st = _puzzle._state
	match _mode:
		"rest":
			_at(0.6, func() -> void:
				var pegs: PackedInt32Array = st.plate_pegs(0)
				var k := 0
				for c in pegs:
					if int(st.want[c]) != -1 and k < pegs.size() / 4:
						_puzzle.set_brush(int(st.want[c]))
						_tap(c)
						k += 1
				_puzzle.set_brush((_puzzle.brush + 1) % st.names.size()))
			for t in [0.4, 0.75, 0.82, 1.0, 1.6]:
				_at(t, _shot)
			_end = 3.0
		"plate":
			_at(0.6, func() -> void: _fill(0))
			for t in [0.7, 0.9, 1.1, 1.3, 1.5, 1.8, 2.2, 3.0]:
				_at(t, _shot)
			_end = 4.0
		"astray":
			_at(0.6, func() -> void:
				var p := _astray_pair(0)
				_fill(0, p.x, p.y))
			for t in [0.7, 1.1, 1.5, 1.75, 1.95, 2.3, 3.0]:
				_at(t, _shot)
			_end = 4.0
		"out":
			_at(0.6, func() -> void:
				var p := _astray_pair(0)
				_fill(0, p.x, p.y))
			_at(2.4, func() -> void:
				var p := _astray_pair(1)
				_fill(1, p.x, p.y))
			_at(4.2, func() -> void:
				var p := _astray_pair(2)
				_fill(2, p.x, p.y))
			for t in [3.0, 5.6, 6.6, 7.6]:
				_at(t, _shot)
			_at(8.0, func() -> void: _puzzle.try_again())
			_at(8.4, _shot)
			_at(9.6, _shot)
			_end = 10.0
		"wind":
			_at(0.8, _shot)
			_at(1.0, func() -> void: _mouse(_puzzle._thumb.get_center(), true))
			_at(1.5, _shot)
			_at(1.7, func() -> void: _mouse(_puzzle._thumb.get_center(), false))
			_at(3.2, _shot)
			_end = 3.5
		"solve":
			_at(0.6, func() -> void:
				var last := -1
				for c in st.size():
					if int(st.want[c]) != -1:
						last = c
				st.begin_stroke()
				for c in st.size():
					if c != last and int(st.want[c]) != -1:
						st.put(c, int(st.want[c]))
				st.end_stroke()
				_puzzle._bands = []
				_puzzle.set_brush(int(st.want[last]))
				_tap(last))
			for t in [0.9, 1.3, 1.7, 2.3, 3.0, 3.6, 4.3, 5.2]:
				_at(t, _shot)
			_end = 5.6
		"restore":
			_at(0.5, func() -> void:
				_puzzle.completed_record = {"hearts": 2, "flawless": true}
				_puzzle.restore_completed())
			_at(1.2, _shot)
			_end = 1.6
