extends SceneTree

## The Versus tab and a frame of snooker, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_snooker.gd -- <outdir>
##
## 1 the Versus tab, 2 the table ready for your break (ball in hand),
## 3 the break rolling, 4 the computer lining up, 5 later in the frame.
## Prints the draw calls at each shot.

var _menu: Node
var _screen: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _beats := [1.6, 3.2, 3.9, 5.2, 0.0]
var _ai_seen := false

## The forced end card writes a won frame to the record; the record this
## machine had before the run is put back at the end.
var _record_before := ""
var _had_record := false

func _initialize() -> void:
	_had_record = FileAccess.file_exists("user://versus.cfg")
	if _had_record:
		_record_before = FileAccess.get_file_as_string("user://versus.cfg")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/snk_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

func _process(delta: float) -> bool:
	_t += delta
	if _step == 0 and _t > 0.8:
		_menu._show_tab("versus")
		_step = 1
	elif _step == 1 and _t > 1.6:
		_shot("1_tab")
		_menu._open_versus("snooker", 1)
		_screen = _menu.get_node("Snooker")
		_step = 2
	elif _step == 2 and _t > 3.2:
		_shot("2_ready")
		var s = _screen
		var red: Vector2 = s.sim.pos[15]
		var cue: Vector2 = s.sim.pos[0]
		s._shoot((red + Vector2(0.06, 0.03) - cue).normalized(), 4.5, Vector2(0.2, 0.0))
		_step = 3
	elif _step == 3 and _t > 3.75:
		_shot("3_break")
		_step = 4
	elif _step == 4 and _screen._state == _screen.State.AI_AIM and not _ai_seen:
		_ai_seen = true
		_step = 5
		_beats[4] = _t + 0.9
	elif _step == 5 and _t > _beats[4]:
		_shot("4_ai")
		_step = 6
	elif _step == 6 and _t > 40.0:
		_shot("5_later")
		print("scores ", _screen.rules.scores, " state ", _screen._state, " shots ", _screen._shots)
		# The end card, forced: a won frame.
		_screen.rules.scores = [72, 41]
		_screen.rules.high_break = [23, 12]
		_screen.rules.over = true
		_screen.rules.winner = 0
		_screen._finish()
		_step = 7
	elif _step == 7 and _t > 41.0:
		_shot("6_end")
		if _had_record:
			var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
			f.store_string(_record_before)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
		quit()
	elif _step == 4 and _t > 30.0:
		_shot("4_timeout")
		print("state ", _screen._state, " turn ", _screen.rules.turn)
		quit()
	return false
