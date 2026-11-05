extends SceneTree
## Throwaway (2026-11-05): the swarm's demo pills and its draw, dots and
## tone tools on screen. Shots
## go to the folder in the first user arg. Touches no user:// save.

var _tab: Control
var _t := 0.0
var _out := "/tmp"
var _draws := 0
## The room waits idle; the Draw pill is pressed, then the Intro pill
## (stopping the drawing).
var _plan := [
	[3.0, "shot", "idle"],
	[3.2, "pill", 1],
	[9.0, "shot", "cat_gold"],
	[13.5, "shot", "heart_pink"],
	[18.0, "shot", "strawberry_red"],
	[22.5, "shot", "frog_mint"],
	[23.0, "pill", 0],
	[25.0, "shot", "intro_started"],
]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]

func _process(d: float) -> bool:
	_t += d
	if _tab == null:
		_tab = load("res://ui/menu/swarm_tab.gd").new()
		root.add_child(_tab)
		_tab.open()
		return false
	_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	while not _plan.is_empty() and _t >= _plan[0][0]:
		var st: Array = _plan.pop_front()
		match st[1]:
			"dots": print("dots ", _tab.apply_dots(st[2]))
			"draw": print("draw ", _tab.apply_draw(st[2]))
			"move": _tab.apply_move(st[2])
			"pill":
				print("pill %s" % _tab._pills[st[2]].text)
				_tab._pills[st[2]].pressed.emit()
			"pill":
				print("pill %s" % _tab._pills[st[2]].text)
				_tab._pills[st[2]].pressed.emit()
			"shot":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("%s/swarm_%s.png" % [_out, st[2]])
				print("shot %s draws=%d live=%d hi=%d script=%d step=%d pic=%s idle=%s state=%s" % [st[2], _draws, _tab._live_count(), _tab._hi, _tab._script.size(), _tab._step_i, _tab._pic_on, _tab._idle, _tab._state])
				_draws = 0
	if _plan.is_empty():
		_tab.close()
		return true
	return false
