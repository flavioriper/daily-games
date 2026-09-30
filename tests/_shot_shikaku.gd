extends SceneTree

## Shots and probes of Shikaku, played through the board's own input path
## (press, motion, release in board coordinates). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_shikaku.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the board as dealt), `right` (the answer's beds drawn one a
## second: streak, sprouts, gags, butterflies), `wrong` (a bed that fits its
## sign but is not the answer, again until the hearts run out: Hard and
## Insane), `solve` (the answer to the win: planting, stamp, party), `perf`
## (half the answer, then a quiet window: draw calls and frame time).
## Frames go to <dir>/sk_<mode>_d<level>_<n>.png.

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/b3499ef5-297d-43f3-abe0-b6fa4d997aa6/scratchpad"
const Gen = preload("res://puzzles/shikaku_gen.gd")

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
var _end := 6.0
var _ms_from := 1e9
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_sk_progress.cfg"))
	progress.path = "user://_shot_sk_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
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
			if e.id == "shikaku":
				entry = e
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
		print("board: %dx%d, %d signs, %d plots, hearts %d/%d, out %s, done %s, streak %d, flies %d" % [
			_puzzle.w, _puzzle.h, _puzzle.state.clues.size(), _puzzle.state.rects.size(),
			_puzzle.hearts, _puzzle.max_hearts, _puzzle.out_of_hearts, _puzzle.is_done(),
			_puzzle._streak, _puzzle._flies.size()])
		print("share: ", _puzzle.share_glyphs())
		quit()
		return true
	return false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/sk_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _ev_press(local: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = local
	_puzzle._gui_input(ev)

func _ev_motion(local: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = local
	_puzzle._gui_input(ev)

## Draws `rect` corner to corner: press on one frame, move, release later.
func _draw_bed(t: float, rect: Rect2i) -> void:
	var a := func() -> Vector2: return _puzzle.cell_to_local(rect.position.y, rect.position.x)
	var b := func() -> Vector2: return _puzzle.cell_to_local(rect.end.y - 1, rect.end.x - 1)
	_at(t, func() -> void: _ev_press(a.call(), true))
	_at(t + 0.08, func() -> void: _ev_motion((a.call() as Vector2).lerp(b.call(), 0.5)))
	_at(t + 0.16, func() -> void: _ev_motion(b.call()))
	_at(t + 0.24, func() -> void: _ev_press(b.call(), false))

## The answer's beds, easiest first (the ones with a number).
func _answer() -> Array:
	var out: Array = _puzzle.state.solution.duplicate()
	return out

## A bed that fits some sign but is not the answer and overlaps nothing drawn.
func _wrong_bed() -> Rect2i:
	var st = _puzzle.state
	for i in st.clues.size():
		for r: Rect2i in Gen.candidates(st.clues, i, st.w, st.h):
			if st.solution.has(r):
				continue
			var free := true
			for have: Rect2i in st.rects:
				if have.intersects(r):
					free = false
			if free:
				return r
	return Rect2i()

func _script() -> void:
	match _mode:
		"rest":
			_at(2.5, _shot)
			_end = 2.7
		"right":
			var beds := _answer()
			var n := mini(beds.size() - 1, 7)
			for k in n:
				_draw_bed(1.5 + k * 0.9, beds[k])
				_at(1.5 + k * 0.9 + 0.6, _shot)
			_at(1.5 + n * 0.9 + 1.5, _shot)
			_at(1.5 + n * 0.9 + 3.0, _shot)
			_end = 1.5 + n * 0.9 + 3.2
		"wrong":
			for k in 3:
				var t0 := 1.5 + k * 1.6
				_at(t0, func() -> void:
					var r := _wrong_bed()
					print("wrong bed ", r)
					var a: Vector2 = _puzzle.cell_to_local(r.position.y, r.position.x)
					var b: Vector2 = _puzzle.cell_to_local(r.end.y - 1, r.end.x - 1)
					_ev_press(a, true)
					_ev_motion(b)
					_ev_press(b, false))
				_at(t0 + 0.45, _shot)
				_at(t0 + 1.2, _shot)
			_at(7.0, _shot)
			_end = 7.2
		"solve":
			var beds := _answer()
			for k in beds.size():
				_draw_bed(1.0 + k * 0.4, beds[k])
			var done := 1.0 + beds.size() * 0.4
			for k in 8:
				_at(done + 0.4 + k * 0.45, _shot)
			_ms_from = done
			_end = done + 4.2
		"perf":
			var beds := _answer()
			for k in beds.size() / 2:
				_draw_bed(1.0 + k * 0.4, beds[k])
			_ms_from = 1.0 + beds.size() * 0.2 + 2.0
			_end = _ms_from + 3.0
