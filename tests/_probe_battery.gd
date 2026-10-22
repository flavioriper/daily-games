extends SceneTree

## Throwaway battery probe (2026-10-22): the menu idle, then one board
## idle, then the same board with the tree paused (the rendering floor:
## what a frame costs when no script runs). Prints per window the mean and
## peak frame, the script share, the renderer's CPU share, draw calls, and
## at the end of each idle window every node still processing, grouped by
## script, with the live tweens and playing audio.
##
##     godot --path . --resolution 810x1440 --always-on-top \
##         --rendering-driver opengl3_angle \
##         --script res://tests/_probe_battery.gd -- <id> d=<0..3> [arcade]

const MENU_FROM := 1.5
const MENU_TO := 6.5
const OPEN_AT := 7.0
const BOARD_FROM := 9.0
const BOARD_TO := 14.0
const FROZEN_FROM := 14.5
const FROZEN_TO := 18.5
const END := 19.0

var _menu: Node
var _id := ""
var _level := 3
var _arcade := false
var _t := -0.3
var _opened := false
var _frozen := false
var _vp: RID
var _rows := {"menu": [], "board": [], "frozen": [], "rest": []}
var _drawn := 0
var _rest_drawn := [0, 0]
var _rest_wall := [0, 0]
var _listed := {"menu": false, "board": false}
## x=menu: after the menu window, hide each of the menu's direct children
## in turn for 1.2 s and print what the frame costs without it.
var _xmenu := false
var _xi := -1
var _xrows: Array = []
var _xnext := 0.0
var _xwas := true
var _xpath := "List"
## `rest`: no board; the menu left alone past core/power.gd's REST_AFTER,
## its state printed at 25 s, a window 24-29 s, a touch at 29 s and the
## state again at 29.5 s.
var _rest := false
var _rest_said := 0

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_level = int(a.substr(2))
		elif a == "arcade":
			_arcade = true
		elif a == "rest":
			_rest = true
		elif a.begins_with("x="):
			_xmenu = true
			_xpath = a.substr(2)
		else:
			_id = a
	var progress_path := "user://_probe_battery_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
	var progress = load("res://core/progress.gd")
	progress.path = progress_path
	for e in load("res://ui/registry.gd").all():
		progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")
	if _rest:
		load("res://core/power.gd").start(main, true)
	_vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn += 1)

func _process(delta: float) -> bool:
	_t += delta
	var window := ""
	if _t >= MENU_FROM and _t < MENU_TO:
		window = "menu"
	elif _t >= BOARD_FROM and _t < BOARD_TO:
		window = "board"
	elif _t >= FROZEN_FROM and _t < FROZEN_TO:
		window = "frozen"
	if window != "":
		_rows[window].append([delta * 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(_vp),
			RenderingServer.viewport_get_measured_render_time_gpu(_vp),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	if _t >= MENU_TO and not _listed.menu:
		_listed.menu = true
		_list("menu")
	if _rest:
		if _t >= 24.0 and _rest_wall[0] == 0:
			_rest_wall[0] = Time.get_ticks_msec()
			_rest_drawn[0] = _drawn
		if _t >= 29.0 and _rest_wall[1] == 0:
			_rest_wall[1] = Time.get_ticks_msec()
			_rest_drawn[1] = _drawn
			print("== rest window: %d ms of wall clock, %d frames drawn by the renderer" % [_rest_wall[1] - _rest_wall[0], _rest_drawn[1] - _rest_drawn[0]])
		if _t >= 24.0 and _t < 29.0:
			_rows["rest"].append([delta * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				RenderingServer.viewport_get_measured_render_time_cpu(_vp), RenderingServer.viewport_get_measured_render_time_gpu(_vp),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		var marks := [10.0, 25.0, 29.5]
		if _rest_said < marks.size() and _t >= marks[_rest_said]:
			var pw: Script = load("res://core/power.gd")
			var running := 0
			for tw in get_processed_tweens():
				if tw.is_valid() and tw.is_running():
					running += 1
			print("== rest t=%.1f resting=%s max_fps=%d low_processor=%s tweens running %d of %d stream_rested=%s" % [_t, pw.resting, Engine.max_fps, OS.low_processor_usage_mode, running, get_processed_tweens().size(), pw._stream_rested])
			if pw.resting:
				for tw in get_processed_tweens():
					if tw.is_valid() and tw.is_running():
						var bound := str(tw)
						var at := bound.find("bound to ")
						var who := bound.substr(at + 9).trim_suffix(")") if at >= 0 else ""
						var found := root.find_child(who, true, false)
						var owner := ""
						var up: Node = found
						while up != null and owner == "":
							if up.get_script() != null and up.get_script().resource_path != "":
								owner = "%s (%s)" % [up.get_script().resource_path, up.name]
							up = up.get_parent()
						print("   running %s loops_left=%d path=%s owner=%s" % [who, tw.get_loops_left(), found.get_path() if found else "?", owner])
				var stack: Array[Node] = [root]
				while not stack.is_empty():
					var n: Node = stack.pop_back()
					for c in n.get_children(true):
						stack.append(c)
					if n.is_processing() and n.get_script() != null and n.get_script().resource_path != "":
						print("   processing %s %s" % [n.name, n.get_script().resource_path])
			_rest_said += 1
		if _t >= 29.0 and _t < 29.05:
			var ev := InputEventScreenTouch.new()
			ev.position = Vector2(400, 1400)
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := InputEventScreenTouch.new()
			up.position = ev.position
			Input.parse_input_event(up)
		if _t >= 30.0:
			_report()
			quit()
			return true
		return false
	if _xmenu and _t >= OPEN_AT:
		_xrows.append([delta * 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(_vp), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		if _t >= _xnext:
			var list: Node = _menu.get_node(_xpath)
			if _xi >= 0 and _xi < list.get_child_count():
				var c: Node = list.get_child(_xi)
				var n := float(maxi(1, _xrows.size() - 6))
				var sum := [0.0, 0.0, 0.0]
				for r in _xrows.slice(6):
					for i in 3:
						sum[i] += r[i]
				print("   without %-28s %-32s frame %.2f ms render-cpu %.2f draws %d" % [c.name, c.get_script().resource_path.get_file() if c.get_script() else c.get_class(), sum[0] / n, sum[1] / n, int(sum[2] / n)])
				c.visible = _xwas
			_xi += 1
			_xrows = []
			_xnext = _t + 1.2
			if _xi >= list.get_child_count():
				_report()
				quit()
				return true
			var nc: Node = list.get_child(_xi)
			if nc is CanvasItem:
				_xwas = nc.visible
				nc.visible = false
		return false
	if _id != "" and _t >= OPEN_AT and not _opened:
		_opened = true
		_open()
	if _t >= BOARD_TO and not _listed.board:
		_listed.board = true
		var top: Node = _menu.get_child(_menu.get_child_count() - 1)
		print("== top of menu: %s (%s) script %s; menu children %d" % [top.name, top.get_class(), top.get_script().resource_path if top.get_script() else "-", _menu.get_child_count()])
		var pz = top.get("_puzzle")
		print("== host puzzle %s processing=%s visible=%s; host children %s" % [pz.get_script().resource_path if pz else "none", pz.is_processing() if pz else "-", pz.visible if pz else "-", top.get_children().map(func(c): return "%s%s" % [c.name, "" if c.visible else "(hidden)"])])
		root.get_viewport().get_texture().get_image().save_png("/tmp/probe_battery_%s.png" % _id)
		_list("board" if _id != "" else "menu again")
	if _t >= FROZEN_FROM and not _frozen:
		_frozen = true
		paused = true
	if _t >= END:
		paused = false
		_report()
		quit()
		return true
	return false

func _open() -> void:
	if _arcade:
		_menu._open_arcade(_id)
		return
	var entry: Dictionary = {}
	for e in load("res://ui/registry.gd").all():
		if e.id == _id:
			entry = e
	if bool(entry.get("pick_difficulty", false)):
		_menu._open_at(entry, _level)
	else:
		_menu._open(entry)
	var host: Node = _menu.get_child(_menu.get_child_count() - 1)
	if host.has_node("HowToPlay"):
		host.get_node("HowToPlay").free()
		if host.has_method("_hold_clock"):
			host._hold_clock(false)

func _list(label: String) -> void:
	var by: Dictionary = {}
	var total := 0
	var seen := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		seen += 1
		for c in n.get_children(true):
			stack.append(c)
		var how := ""
		if n.is_processing():
			how += "p"
		if n.is_physics_processing():
			how += "P"
		if n.is_processing_internal():
			how += "i"
		if how == "":
			continue
		total += 1
		var sp: String = n.get_script().resource_path if n.get_script() != null else ""
		var key := "%s [%s]" % [sp if sp != "" else "%s/%s" % [n.get_class(), n.name], how]
		if n.get_script() == null and (n is Control or n is Node2D):
			key = "%s(%s) [%s]" % [n.get_class(), n.name, how]
		by[key] = int(by.get(key, 0)) + 1
	var tweens := get_processed_tweens()
	var playing := 0
	stack = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(true):
			stack.append(c)
		if (n is AudioStreamPlayer and n.playing) or (n is AudioStreamPlayer2D and n.playing):
			playing += 1
	print("== %s: %d of %d nodes processing, %d tweens alive, %d audio playing" % [label, total, seen, tweens.size(), playing])
	var keys := by.keys()
	keys.sort_custom(func(a, b): return by[a] > by[b])
	for k in keys:
		print("   %3d  %s" % [by[k], k])
	for tw in tweens:
		print("   tween %s valid=%s running=%s" % [tw, tw.is_valid(), tw.is_running()])

func _report() -> void:
	for w in ["menu", "board", "frozen", "rest"]:
		var rows: Array = _rows[w]
		if rows.is_empty():
			continue
		var sum := [0.0, 0.0, 0.0, 0.0, 0.0]
		var peak := 0.0
		for r in rows:
			for i in 5:
				sum[i] += r[i]
			peak = maxf(peak, r[0])
		var n := float(rows.size())
		print("%-7s frames %4d | frame %.2f ms (peak %.1f) | process %.2f | render-cpu %.2f | render-gpu %.2f | draws %d | ~%d fps uncapped" % [
			w, rows.size(), sum[0] / n, peak, sum[1] / n, sum[2] / n, sum[3] / n, int(sum[4] / n), int(1000.0 / maxf(0.01, sum[0] / n))])
