extends SceneTree

## A match of air hockey, shot at fixed beats, the screen built by hand so
## nothing of the menu (or the network) is started:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_hockey.gd -- <outdir> [level] [rm] [lang=pt|es]
##
## `level` 0-2 is the computer's, 4 two players. The bottom mallet is played
## by a second computer (level 2) writing where it wants the mallet, as a
## finger would. 1 the serve, 2-4 play, 5 a goal as it goes in, 6 the end
## card (forced: a match won 7-4). Prints the draw calls at each shot and
## puts user://versus.cfg back.

const AI = preload("res://versus/hockey_ai.gd")

var _screen: Control
var _hand: RefCounted
var _hand2: RefCounted
var _t := 0.0
var _out := "/tmp"
var _level := 1
var _step := 0
var _goal_at := -1.0
var _record_before := ""
var _had_record := false

func _initialize() -> void:
	_had_record = FileAccess.file_exists("user://versus.cfg")
	if _had_record:
		_record_before = FileAccess.get_file_as_string("user://versus.cfg")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_level = int(args[1])
	for a in args:
		if a == "rm":
			load("res://core/motion.gd").reduce = true
		elif a.begins_with("lang="):
			TranslationServer.set_locale(a.trim_prefix("lang="))
	_screen = load("res://versus/hockey_screen.gd").new(_level)
	root.add_child(_screen)
	_hand = AI.new(0, 2, 5)
	_hand2 = AI.new(1, 1, 6)

func _restore() -> void:
	if _had_record:
		var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
		f.store_string(_record_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/hky_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d score %s" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), str(_screen.sim.scores)])

func _process(delta: float) -> bool:
	_t += delta
	# The real pointer over the window must not lead the mallet.
	_screen.table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _screen._state != _screen.State.OVER:
		_hand.drive(_screen.sim, delta)
		if _screen.two_players():
			_hand2.drive(_screen.sim, delta)
	if _screen._state == _screen.State.GOAL and _goal_at < 0.0 and _step >= 2:
		_goal_at = _t
	if _step == 0 and _t > 1.0:
		_shot("1_serve")
		_step = 1
	elif _step == 1 and _t > 2.6:
		_shot("2_play")
		_step = 2
	elif _step == 2 and _t > 4.0:
		_shot("3_play")
		_step = 3
	elif _step == 3 and _t > 6.0:
		_shot("4_play")
		_step = 4
	elif _step == 4 and ((_goal_at > 0.0 and _t > _goal_at + 0.25) or _t > 60.0):
		_shot("5_goal")
		_step = 5
	elif _step == 5 and _t > maxf(_goal_at, 0.0) + 2.5:
		_screen.sim.scores = [7, 4]
		_screen.sim.over = true
		_screen.sim.winner = 0
		_screen._refresh_board()
		_screen._finish()
		_step = 6
	elif _step == 6 and _screen._state == _screen.State.OVER and _t > maxf(_goal_at, 0.0) + 3.9:
		_shot("6_end")
		_restore()
		quit()
	return false
