extends SceneTree

## The Versus tab and a game of checkers, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_checkers.gd -- <outdir> [reduce]
##
## 01 the tab, 02 the set being dealt, 03 ready, 04 a man picked up, 05
## mid-hop, 06 the computer's reply, 07 a forced capture's rings, 08 its
## routes, 09 the first jump's flip, 10 the taken piece squashed, 11 the
## second jump and its "x2", 12 the tray, 13 a crown falling, 14 crowned,
## 15 a king's glide, 16 the last piece taken and the petals, 17 the end
## card, 18 the losers turning over. Prints the draw calls at each shot. The
## record this machine had is put back at the end.

const Rules = preload("res://versus/checkers_rules.gd")
const Motion = preload("res://core/motion.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _wait := 0.0
var _record_before := ""
var _had_record := false

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and eat the taps.
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
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
	root.get_texture().get_image().save_png("%s/ckr_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

func sq(n: String) -> int:
	return "abcdefgh".find(n[0]) + (int(n[1]) - 1) * 8

func find(a: String, b: String) -> PackedInt32Array:
	for m: PackedInt32Array in _s.rules.legal_moves():
		if m[0] == sq(a) and Rules.mv_to(m) == sq(b):
			return m
	return PackedInt32Array()

## A position from "sq:piece" items (M/K light, m/k dark), set on the
## screen's rules and the board re-laid without the deal.
func setup(spec: String, turn := Rules.LIGHT) -> void:
	var g: RefCounted = Rules.new(Rules.Variant.BRAZILIAN, true)
	for item in spec.split(" ", false):
		var ch := item[3]
		var v := Rules.MAN if ch.to_lower() == "m" else Rules.KING
		g.board[sq(item.substr(0, 2))] = v if ch == ch.to_upper() else -v
	g.turn = turn
	g.rehash()
	g.hashes = PackedInt64Array([g.hash])
	_s._game += 1
	_s.rules = g
	_s._history.clear()
	_s.board.setup(g, _s.player, false)
	_s._start_turn()

func _process(delta: float) -> bool:
	_t += delta
	if _t < _wait:
		return false
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("versus")
				_step = 1
				_wait = _t + 0.8
		1:
			# after main has read the settings, which would put it back
			var args := OS.get_cmdline_user_args()
			if args.size() > 1 and args[1] == "reduce":
				Motion.reduce = true
			_shot("01_tab")
			var cfg := ConfigFile.new()
			cfg.load("user://versus.cfg")
			cfg.set_value("colour", "checkers", 0)
			cfg.save("user://versus.cfg")
			_menu._open_versus("checkers", 1)
			_s = _menu.get_node("Checkers")
			_step = 2
			_wait = _t + 0.9
		2:
			_shot("02_deal")
			_step = 3
		3:
			if _s._state == _s.State.YOURS:
				_wait = _t + 0.6
				_step = 4
		4:
			_shot("03_ready")
			_s.board._select(sq("c3"))
			_step = 5
			_wait = _t + 0.5
		5:
			_shot("04_picked")
			_s._on_chosen(find("c3", "d4"))
			_step = 6
			_wait = _t + 0.16
		6:
			_shot("05_hop")
			_step = 7
		7:
			if _s._state == _s.State.ANIM and _s.rules.turn == Rules.LIGHT:
				_wait = _t + 0.25
				_step = 8
		8:
			_shot("06_reply")
			_step = 9
		9:
			if _s._state == _s.State.YOURS:
				# a double jump is forced: c3 over d4 and f6
				setup("a1:M c3:M e1:M g1:M b2:M d4:m f6:m h8:m b8:m d8:m a7:m")
				_wait = _t + 0.5
				_step = 10
		10:
			_shot("07_must")
			_s.board._select(sq("c3"))
			_step = 11
			_wait = _t + 0.5
		11:
			_shot("08_routes")
			_s._on_chosen(find("c3", "g7"))
			_step = 12
			_wait = _t + 0.3
		12:
			_shot("09_flip")
			_step = 13
			_wait = _t + 0.14
		13:
			_shot("10_squash")
			_step = 14
			_wait = _t + 0.45
		14:
			_shot("11_second")
			_step = 15
			_wait = _t + 1.2
		15:
			_shot("12_tray")
			# a man one step from the far row
			setup("c7:M a1:M h8:m f8:m a5:m")
			_wait = _t + 0.4
			_step = 16
		16:
			_s._on_chosen(find("c7", "d8"))
			_step = 17
			_wait = _t + 0.72
		17:
			_shot("13_crowning")
			_step = 18
			_wait = _t + 0.5
		18:
			_shot("14_crowned")
			_step = 19
			_wait = _t + 1.2
		19:
			setup("a1:K h6:m a7:m")
			_wait = _t + 0.4
			_step = 20
		20:
			_s._on_chosen(find("a1", "f6"))
			_step = 21
			_wait = _t + 0.35
		21:
			_shot("15_glide")
			_step = 22
			_wait = _t + 1.5
		22:
			# the last piece: taking it wins
			_s.level = 0
			setup("c3:M e3:M d4:m")
			_wait = _t + 0.4
			_step = 23
		23:
			_s._on_chosen(find("c3", "e5") if not find("c3", "e5").is_empty() else find("e3", "c5"))
			_step = 24
			_wait = _t + 2.3
		24:
			_shot("16_won")
			_step = 25
			_wait = _t + 1.8
		25:
			_shot("17_end")
			_s._end.queue_free()
			_s._end = null
			setup("a1:M c1:M e1:M g1:M b2:M d2:M h4:m f6:m d6:m b6:m")
			_wait = _t + 0.4
			_step = 26
		26:
			_s.board.finish("lost")
			_step = 27
			_wait = _t + 1.2
		27:
			_shot("18_yield")
			if _had_record:
				var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
				f.store_string(_record_before)
			else:
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
			quit()
	if _t > 90.0:
		print("timeout at step ", _step, " state ", _s._state if _s != null else -1)
		quit()
	return false
