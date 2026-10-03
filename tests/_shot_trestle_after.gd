extends SceneTree

## Trestle's second pass, through the real menu and flat host, by touch:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_trestle_after.gd -- <outdir> [d=<level>]
##
## a1 the road alone collapses: the drawing board after it, loads tinted and
## the first to go ringed; a2 the proof solved, the win with the strip's
## pills; a3 the convoy (tapped) mid-run; a4 after it; a5 the free build
## (tapped) with a member added; a6 its test crossing; a7 Done; a8 the daily
## reopened, showing the player's own bridge. With `crowd` and the emulator
## suite up, the solve is sent and the strip reads the tally. Otherwise the backend is stopped and
## solves go to a throwaway progress file, never this Mac's save.

const Backend = preload("res://core/backend.gd")

var _menu: Node
var _host: Node
var _b: Node
var _out := "/tmp"
var _level := 0
var _t := 0.0
var _step := 0
var _at := 0.0
var _entry: Dictionary
var _crowd := false

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progress_trestle_after.cfg"))
	load("res://core/progress.gd").path = "user://progress_trestle_after.cfg"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for a: String in args:
		if a.begins_with("d="):
			_level = int(a.substr(2))
		elif a == "crowd":
			_crowd = true
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/tra_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d cost=%d/%d testing=%s done=%s free=%s peaks=%d first=%s broken=%d moves=%d toast=%s" % [name, _t,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_b.state.cost(), _b.state.budget, _b._testing, _b.is_done(), _b._free, _b._peak.size(), _b._first_key,
		_b._last_broken.size(), _b.moves, _b._toast])

## A tap at a point in the board's own coordinates, through the window.
func _tap(local: Vector2) -> void:
	var canvas: Vector2 = _b.get_global_transform_with_canvas() * local
	var win: Vector2 = root.get_final_transform() * canvas
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = win
		e.global_position = win
		root.push_input(e)

func _open() -> void:
	_menu._open_at(_entry, _level)
	_host = _menu.get_child(_menu.get_child_count() - 1)
	_b = _host._puzzle
	if _host.has_node("HowToPlay"):
		_host.get_node("HowToPlay").free()
		_host._hold_clock(false)

func _process(delta: float) -> bool:
	_t += delta
	match _step:
		0:
			if _t > 0.8:
				# `crowd` keeps the backend for the emulator suite
				# (FIREBASE_EMULATOR set; back user://player.cfg up first)
				if not (_crowd and OS.get_environment("FIREBASE_EMULATOR") != ""):
					Backend.stop()
				_entry = load("res://ui/registry.gd").find("trestle")
				_open()
				_step = 1
		1:
			if _t > 2.4:
				for p in _b.state.proof:
					if p.m == 0:
						_b._mat = p.m
						_b._lay(p.a, p.b)
				_host._on_check()
				_at = _t
				_step = 2
		2:
			if not _b._testing and _t > _at + 1.0:
				_at = _t
				_step = 3
			elif _t > _at + 25.0:
				_shot("timeout2")
				quit()
		3:
			if _t > _at + 0.6:
				_shot("a1_fail")
				# the proof, over what is there
				_b.state.design = []
				for p in _b.state.proof:
					_b._mat = p.m
					_b._lay(p.a, p.b)
				_host._on_check()
				_at = _t
				_step = 4
		4:
			if _b.is_done() and _t > _at + 1.0 and _host._won and _t > _at + 6.0:
				_shot("a2_win")
				_tap(_b._pill_rect(_b.Pill.CONVOY).get_center())
				_at = _t
				_step = 5
			elif _t > _at + 30.0:
				_shot("timeout4")
				quit()
		5:
			if _t > _at + 2.2:
				_shot("a3_convoy")
				_at = _t
				_step = 6
		6:
			if not _b._testing and _t > _at + 1.0:
				_shot("a4_convoy_end")
				_tap(_b._pill_rect(_b.Pill.DONE if _b._free else _b.Pill.FREE).get_center())
				_at = _t
				_step = 7
			elif _t > _at + 30.0:
				_shot("timeout6")
				quit()
		7:
			if _t > _at + 0.6:
				# a wood member from the first pin, by drag-free taps: pin, point
				var a: Vector2i = _b.state.anchors()[0]
				_tap(_b.point_to_local(a))
				_at = _t
				_step = 8
		8:
			if _t > _at + 0.3:
				var a: Vector2i = _b.state.anchors()[0]
				_tap(_b.point_to_local(a + Vector2i(1, -1)))
				_at = _t
				_step = 9
		9:
			if _t > _at + 0.6:
				_shot("a5_free")
				_tap(_b._pill_rect(_b.Pill.GO).get_center())
				_at = _t
				_step = 10
		10:
			if not _b._testing and _t > _at + 1.0:
				_shot("a6_free_after")
				_tap(_b._pill_rect(_b.Pill.DONE).get_center())
				_at = _t
				_step = 11
			elif _t > _at + 30.0:
				_shot("timeout10")
				quit()
		11:
			if _t > _at + 0.8:
				_shot("a7_done")
				_host._on_back()
				_at = _t
				_step = 12
		12:
			if _t > _at + 1.0:
				_open()
				_at = _t
				_step = 13
		13:
			if _t > _at + 2.5:
				_shot("a8_reopened")
				print("reopened design %d members, record %s" % [_b.state.design.size(), _b.completed_record.keys()])
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progress_trestle_after.cfg"))
				quit()
	return false
