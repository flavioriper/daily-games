extends SceneTree

## Shots and probes of Binairo, played through the board's own input path
## (press and release in board coordinates). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_binairo.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the board as dealt), `right` (the answer's tiles tapped in
## one a beat: streak, lines, gags), `wrong` (a tile tapped that breaks a
## rule, then left: the blush and what the board says), `solve` (the answer
## to the win), `perf` (half the answer, then a quiet window: draw calls and
## frame time), `read` (a few right tiles, then the bulb's presses).
## Frames go to <dir>/bn_<mode>_d<level>_<n>.png.

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/2f351af2-8152-4448-8891-d30342f960c9/scratchpad"
const Gen = preload("res://puzzles/binairo_gen.gd")

var _t := 0.0
var _level := 1
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
		elif a == "whole":
			pass
		else:
			_mode = a
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_bn_progress.cfg"))
	progress.path = "user://_shot_bn_progress.cfg"
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
			if e.id == "binairo":
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
		print("board: %dx%d, done %s, streak %d, moves %d, hints %d" % [
			_puzzle.n, _puzzle.n, _puzzle.is_done(), _puzzle._streak, _puzzle.moves, _puzzle.hints_used])
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
	var path := "%s/bn_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _say() -> void:
	print("say: ", _puzzle._toast)

## A free cell whose wrong symbol breaks a rule at once (`breaks`), or
## breaks none but leaves some line with no legal finish (else any that
## breaks none), read on a copy of the grid.
func _breaker(breaks: bool) -> Vector2i:
	var Reader = load("res://puzzles/binairo_reader.gd")
	var calm := Vector2i(-1, -1)
	for cell in _free():
		var g: Array = []
		for row in _puzzle.state.grid:
			g.append((row as Array).duplicate())
		g[cell.y][cell.x] = 1 - int(_puzzle._solution[cell.y][cell.x])
		var bad: Dictionary = Gen.bad_lines(g, _puzzle.state.signs)
		var broken: bool = not (bad.rows.is_empty() and bad.cols.is_empty() and bad.get("cells", {}).is_empty())
		if breaks and broken:
			return cell
		if not breaks and not broken:
			if not Reader.stuck_lines(g, _puzzle.state.signs).is_empty():
				return cell
			if calm.x < 0:
				calm = cell
	return calm

# --- the hand ---

func _ev_press(local: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = local
	_puzzle._gui_input(ev)

## One tap on (r, c): press on one frame, release on a later one.
func _tap(t: float, r: int, c: int) -> void:
	_at(t, func() -> void: _ev_press(_puzzle.cell_to_local(r, c), true))
	_at(t + 0.05, func() -> void: _ev_press(_puzzle.cell_to_local(r, c), false))

## Taps (r, c) round to `v` (0 sun: one tap, 1 moon: two).
func _put(t: float, r: int, c: int, v: int) -> float:
	_tap(t, r, c)
	if v == 1:
		_tap(t + 0.12, r, c)
		return t + 0.24
	return t + 0.12

## The free cells, in reading order.
func _free() -> Array:
	var out := []
	for r in _puzzle.n:
		for c in _puzzle.n:
			if not _puzzle.state.given[r][c] and _puzzle.state.grid[r][c] == -1:
				out.append(Vector2i(c, r))
	return out

func _script() -> void:
	match _mode:
		"rest":
			_at(2.5, _shot)
			_end = 2.7
		"right":
			var t := 1.5
			var free := _free()
			for k in mini(free.size() - 1, 9):
				var cell: Vector2i = free[k]
				t = _put(t, cell.y, cell.x, _puzzle._solution[cell.y][cell.x]) + 0.25
				if k % 3 == 2:
					_at(t, _shot)
			_at(t + 1.2, _shot)
			_end = t + 1.4
		"wrong":
			_at(1.5, func() -> void:
				var cell := _breaker(true)
				if cell.x < 0:
					print("no tile breaks a rule at once")
					return
				var wrong := 1 - int(_puzzle._solution[cell.y][cell.x])
				print("wrong at ", cell, " as ", wrong)
				_put(_t, cell.y, cell.x, wrong))
			_at(2.0, _shot)
			_at(3.3, func() -> void:
				_say()
				_shot())
			_at(4.5, _shot)
			_end = 4.7
		"stuck":
			# Wrong tiles that break no rule, one a beat, until a line has no
			# legal finish left.
			for k in 8:
				_at(1.0 + k * 1.4, func() -> void:
					if not _puzzle._stuck.is_empty():
						return
					var cell := _breaker(false)
					if cell.x < 0:
						return
					_put(_t, cell.y, cell.x, 1 - int(_puzzle._solution[cell.y][cell.x])))
			_at(12.5, func() -> void:
				print("stuck ", _puzzle._stuck, " fixes ", _puzzle._fixes, " stars ", _puzzle._stars.stars)
				_say()
				_shot())
			_end = 12.7
		"read":
			var t := 1.0
			var free := _free()
			for k in mini(free.size() - 1, 3):
				var cell: Vector2i = free[k]
				t = _put(t, cell.y, cell.x, _puzzle._solution[cell.y][cell.x]) + 0.2
			_at(t + 1.2, func() -> void:
				print("hint 1: ", _puzzle.hint(), " left ", _puzzle.hints_left())
				_say())
			_at(t + 1.7, _shot)
			_at(t + 2.5, func() -> void:
				print("hint 2: ", _puzzle.hint(), " left ", _puzzle.hints_left())
				_say())
			_at(t + 3.2, _shot)
			_end = t + 3.4
		"fix":
			# Three tiles set wrong, left, then put right (three changes of
			# mind), a shot of the stars, then the rest of the answer to the win.
			var t := 1.0
			var free := _free()
			for k in 3:
				var cell: Vector2i = free[k]
				var want: int = _puzzle._solution[cell.y][cell.x]
				t = _put(t, cell.y, cell.x, 1 - want) + 1.4
				if want == 0:
					# moon -> clear -> sun
					_tap(t, cell.y, cell.x)
					_tap(t + 0.12, cell.y, cell.x)
					t += 0.24
				else:
					_tap(t, cell.y, cell.x)
					t += 0.12
				t += 1.4
			_at(t, func() -> void:
				print("fixes ", _puzzle._fixes, " stars ", _puzzle._stars.stars)
				_shot())
			for k in range(3, free.size()):
				var cell: Vector2i = free[k]
				t = _put(t + 0.1, cell.y, cell.x, _puzzle._solution[cell.y][cell.x])
			for k in 3:
				_at(t + 3.5 + k * 1.0, _shot)
			_at(t + 6.0, func() -> void: print("win: ", _puzzle.flat_win().subtitle, " flawless ", _puzzle._flawless))
			_end = t + 6.2
		"line":
			# The reader's own steps laid as hints until the next one is a
			# half-full line (`line` after the mode: a whole line read), then
			# the bulb's first press.
			var Reader = load("res://puzzles/binairo_reader.gd")
			var want: int = Reader.Rule.LINE if OS.get_cmdline_user_args().has("whole") else Reader.Rule.HALF
			_at(1.0, func() -> void:
				for k in 200:
					var got: Dictionary = _puzzle._read()
					if got.is_empty() or int(got.rule) == want:
						break
					_puzzle._lay_hint(got.cell)
				print("hint: ", _puzzle.hint())
				_say())
			_at(2.0, _shot)
			_end = 2.2
		"solve":
			var t := 1.0
			for cell in _free():
				t = _put(t, cell.y, cell.x, _puzzle._solution[cell.y][cell.x]) + 0.02
			for k in 8:
				_at(t + 0.4 + k * 0.5, _shot)
			_ms_from = t
			_end = t + 4.5
		"perf":
			var t := 1.0
			var free := _free()
			for k in free.size() / 2:
				var cell: Vector2i = free[k]
				t = _put(t, cell.y, cell.x, _puzzle._solution[cell.y][cell.x]) + 0.02
			_ms_from = t + 2.0
			_end = _ms_from + 3.0
