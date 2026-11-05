extends SceneTree
## Throwaway (2026-11-05): the swarm's draw and dots tools on screen. Shots
## go to the folder in the first user arg. Touches no user:// save.

var _tab: Control
var _t := 0.0
var _out := "/tmp"
var _draws := 0
var _plan := [
	[3.0, "dots", {"add": 800, "from": "face"}],
	[3.6, "shot", "dots_burst"],
	[6.0, "draw", {"name": "bank:cat_in_box"}],
	[7.0, "shot", "cat_flying"],
	[10.0, "shot", "cat_landed"],
	[10.5, "draw", {"rows": ["..rr.rr..", ".rprrrrr.", "rpwprrrrr", "rprrrrrrr", "rrrrrrrrr", ".rrrrrrr.", "..rrrrr..", "...rrr...", "....r...."], "palette": {"r": "red", "p": "pink", "w": "white"}, "size": 0.5}],
	[14.0, "shot", "heart"],
	[14.5, "draw", {"name": "bank:strawberry", "size": 0.6}],
	[15.0, "move", {"to": "top-right"}],
	[18.5, "shot", "strawberry_moved"],
	[19.0, "draw", {"clear": true}],
	[19.1, "dots", {"remove": 900, "to": "edges"}],
	[20.0, "shot", "dots_leaving"],
	[23.5, "shot", "face_back"],
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
			"shot":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("%s/swarm_%s.png" % [_out, st[2]])
				print("shot %s draws=%d live=%d hi=%d" % [st[2], _draws, _tab._live_count(), _tab._hi])
				_draws = 0
	if _plan.is_empty():
		_tab.close()
		return true
	return false
