extends SceneTree
## Throwaway (2026-11-05): the swarm's demo pills and its draw, dots and
## tone tools on screen. Shots
## go to the folder in the first user arg. Touches no user:// save.

var _tab: Control
var _t := 0.0
var _out := "/tmp"
var _draws := 0
## The room waits idle; the Draw pill is pressed. Each "see" saves what the
## agent's see tool would hand it (snapshot, 384 wide).
var _plan := [
	[3.0, "see", "idle"],
	[3.2, "pill", 1],
	[7.2, "see", "sun"],
	[12.2, "see", "duck"],
	[17.0, "see", "heart"],
	[21.5, "see", "strawberry"],
	[26.0, "see", "tulip"],
	[30.5, "see", "snail"],
]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]

func _process(d: float) -> bool:
	_t += d
	if _tab == null:
		_tab = load("res://bot/swarm_face.gd").new()
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
			"see":
				var got: Dictionary = _tab.snapshot(384)
				if got.has("error"):
					print("see %s error %s" % [st[2], got.error])
				else:
					var f := FileAccess.open("%s/see_%s.jpg" % [_out, st[2]], FileAccess.WRITE)
					f.store_buffer(Marshalls.base64_to_raw(got.jpg))
					f.close()
					print("see %s %dx%d %d bytes draws=%d tone=#%s" % [st[2], got.w, got.h, got.bytes, _draws, _tab._tone.to_html(false)])
				_draws = 0
			"pill":
				# the face alone (bot/swarm_face.gd): its demo, as the pill plays it
				print("pill %s" % ["Intro", "Draw"][st[2]])
				_tab.play_demo(_tab.SHOWOFF if st[2] == 1 else _tab.INTRO)
			"see":
				var got: Dictionary = _tab.snapshot(384)
				if got.has("error"):
					print("see %s error %s" % [st[2], got.error])
				else:
					var f := FileAccess.open("%s/see_%s.jpg" % [_out, st[2]], FileAccess.WRITE)
					f.store_buffer(Marshalls.base64_to_raw(got.jpg))
					f.close()
					print("see %s %dx%d %d bytes draws=%d tone=#%s" % [st[2], got.w, got.h, got.bytes, _draws, _tab._tone.to_html(false)])
				_draws = 0
			"pill":
				# the face alone (bot/swarm_face.gd): its demo, as the pill plays it
				print("pill %s" % ["Intro", "Draw"][st[2]])
				_tab.play_demo(_tab.SHOWOFF if st[2] == 1 else _tab.INTRO)
			"shot":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("%s/swarm_%s.png" % [_out, st[2]])
				print("shot %s draws=%d live=%d hi=%d script=%d step=%d pic=%s idle=%s state=%s" % [st[2], _draws, _tab._live_count(), _tab._hi, _tab._script.size(), _tab._step_i, _tab._pic_on, _tab._idle, _tab._state])
				_draws = 0
	if _plan.is_empty():
		_tab.close()
		return true
	return false
