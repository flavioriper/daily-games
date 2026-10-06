extends SceneTree

## The opening (ui/opening.gd), shot two ways.
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_opening.gd -- [rm] [out=<dir>]
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_opening.gd -- boot [rm] [tap] [out=<dir>]
##
## With nothing after `--` it is the opening alone over a sheet of the first
## screen's paper, its clock set by hand to each of STILLS and shot, then told
## to leave and shot through that: `opening_<n>_<ms>.png`. The clock is set
## on one frame and the frame drawn on the next.
##
## `boot` is world/boot.tscn as the game opens on it, with the real scene
## root offline (tests/_offline_main.gd): the threaded load, the first screen
## built under the opening, the handover. It shoots on the wall clock
## (`boot_<ms>.png`), then from the moment the opening starts to leave
## (`reveal_<ms>.png`), and prints when the game was put under the opening,
## the longest frame of the run and the most draw calls with the opening up.
## `tap` presses the opening at 0.3 s, the way a finger asks to be let in.
## `time` shoots nothing (a shot is a frame of 50 ms or more, and the opening
## waits out a long frame, so a run that shoots reads late) and prints the
## frames instead: how many, how many over 34 ms, the longest.
## `rm` is reduce motion, through a settings file of the harness's own.

const STILLS: Array[float] = [0.0, 0.2, 0.34, 0.48, 0.62, 0.76, 0.9, 1.04, 1.18, 1.32, 1.5, 1.7, 2.34, 2.5]
const LEAVING: Array[float] = [0.06, 0.12, 0.2, 0.3, 0.4]
const BOOT_AT: Array[float] = [0.02, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75]
const REVEAL_AT: Array[float] = [0.0, 0.1, 0.2, 0.3, 0.42, 0.7, 1.4]

var _out := "/tmp"
var _boot := false
var _tap := false
var _opening: Control
var _boot_node: Node
var _t := 0.0
var _i := 0
var _set := false
var _left_at := -1.0
var _under_at := -1.0
var _longest := 0.0
var _draws := 0
var _tapped := false
var _time := false
var _frames := 0
var _slow := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_boot = args.has("boot")
	_tap = args.has("tap")
	_time = args.has("time")
	for a in args:
		if a.begins_with("out="):
			_out = a.trim_prefix("out=")
	# The harness's own settings, so the player's file neither decides this
	# run nor is written by it.
	var motion: Script = load("res://core/motion.gd")
	motion.settings_path = "user://_shot_opening_settings.cfg"
	motion.reduce = args.has("rm")
	motion.save_settings()
	if _boot:
		_boot_node = load("res://world/boot.tscn").instantiate()
		_boot_node.main_script = load("res://tests/_offline_main.gd")
		root.add_child(_boot_node)
		return
	var paper := ColorRect.new()
	paper.color = load("res://core/palette.gd").PAPER
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(paper)
	_opening = load("res://ui/opening.gd").new()
	_opening.auto = false
	root.add_child(_opening)

func _process(delta: float) -> bool:
	return _run_boot(delta) if _boot else _run_stills()

func _run_stills() -> bool:
	var leaving := _i >= STILLS.size()
	if _i >= STILLS.size() + LEAVING.size():
		return true
	if not _set:
		if leaving:
			_opening.leave()
			_opening.clock = STILLS[-1] + LEAVING[_i - STILLS.size()]
		else:
			_opening.clock = STILLS[_i]
		_opening.step(0.0)
		_set = true
		return false
	var ms := int(roundf((LEAVING[_i - STILLS.size()] if leaving else STILLS[_i]) * 1000.0))
	_shoot("%s_%02d_%04d" % ["leave" if leaving else "opening", _i, ms])
	if _i == STILLS.size() - 1:
		print("draw calls settled: %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_i += 1
	_set = false
	return false

func _run_boot(delta: float) -> bool:
	_t += delta
	if _t > 0.2:
		_longest = maxf(_longest, delta)
		_frames += 1
		_slow += int(delta > 0.034)
	var up := is_instance_valid(_boot_node)
	if up and _tap and not _tapped and _t >= 0.3:
		_tapped = true
		var press := InputEventScreenTouch.new()
		press.pressed = true
		press.position = Vector2(400.0, 700.0)
		_boot_node.opening._gui_input(press)
	if up and _under_at < 0.0 and root.get_node_or_null("Main") != null:
		_under_at = _t
	if up and _left_at < 0.0:
		_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if _boot_node.opening.leaving():
			_left_at = _t
			_i = 0
	if _left_at < 0.0:
		if not _time and _i < BOOT_AT.size() and _t >= BOOT_AT[_i]:
			_shoot("boot_%04d" % int(_t * 1000.0))
			_i += 1
		return false
	if _i < REVEAL_AT.size() and _t - _left_at >= REVEAL_AT[_i]:
		if not _time:
			_shoot("reveal_%04d" % int((_t - _left_at) * 1000.0))
		_i += 1
	if _i >= REVEAL_AT.size():
		print("game under the opening at %.2f s, opening leaving at %.2f s, boot node %s, current scene %s" % [
			_under_at, _left_at, "still up" if up else "gone", current_scene.name if current_scene != null else "none"])
		print("%d frames after the first 0.2 s, %d over 34 ms, longest %.0f ms; most draw calls with the opening up %d" % [
			_frames, _slow, _longest * 1000.0, _draws])
		return true
	return false

func _shoot(name: String) -> void:
	RenderingServer.force_draw()
	var path := "%s/%s.png" % [_out, name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
