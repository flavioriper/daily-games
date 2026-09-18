extends SceneTree

## The first screen, after the entrance has landed, and again with the More
## sheet up.
##
##     godot --path . --resolution 540x960 --script res://tests/_shot_menu.gd
##
## Saves /tmp/shot_menu_1.png and /tmp/shot_menu_2.png, and prints the mean
## frame time and the peak draw-call count over the idle second before the
## first shot, so a change to the first screen can be measured as well as
## looked at.

const FIRST_AT := 1.8
const SECOND_AT := 2.8
const IDLE_FROM := 0.8

var _menu: Node
var _t := 0.0
var _phase := 0
var _idle: Array[float] = []
var _draws := 0

func _initialize() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if _phase == 0 and _t >= IDLE_FROM:
		_idle.append(delta * 1000.0)
		_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _phase == 0 and _t >= FIRST_AT:
		var mean := 0.0
		for ms in _idle:
			mean += ms
		mean /= maxf(_idle.size(), 1.0)
		print("idle frames=%d mean_ms=%.2f max_draw_calls=%d" % [_idle.size(), mean, _draws])
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/shot_menu_1.png")
		print("saved /tmp/shot_menu_1.png")
		_menu.legacy_sheet.open()
		_phase = 1
	elif _phase == 1 and _t >= SECOND_AT:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/shot_menu_2.png")
		print("saved /tmp/shot_menu_2.png")
		return true
	return false
