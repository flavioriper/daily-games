extends SceneTree

## The Arcade tab and a game of Stackwood, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_stackwood.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 the ready banner, 3 play with a bot, 4 a full shelf
## set by hand (a merge chain about to go), 5 a real drag through the
## viewport (printed: the column the block was steered to and landed in),
## 6 the chain mid-merge, 7 a zap, 8 a bomb, 9 the 2048 banner, 10 the
## topple, 11 the end card. Prints the draw calls at each shot. The end
## writes a score to user://arcade.cfg, so the file this machine had is put
## back.

const Sim = preload("res://arcade/stackwood_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _decided := -1
const PATH := "user://arcade.cfg"

func _initialize() -> void:
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.has("reduce"):
		load("res://core/motion.gd").reduce = true
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/sw_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d score=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_s.sim.score if _s != null else 0])

## Drops each block where it touches the most of its own number.
func _bot() -> void:
	var sim = _s.sim
	if sim.phase != Sim.Phase.FALL or sim.piece.is_empty() or sim.piece.dropping or int(sim.piece.id) == _decided:
		return
	if float(sim.piece.hold) > 0.0:
		return
	_decided = int(sim.piece.id)
	var best_c := 2
	var best_s := -INF
	for c in Sim.COLS:
		var h: int = sim.height(c)
		var s := -h * 1.2 + randf() * 0.1
		for n in [Vector2i(c - 1, h), Vector2i(c + 1, h), Vector2i(c, h - 1)]:
			var b: Dictionary = sim._at(n)
			if not b.is_empty() and int(b.v) == int(sim.piece.v):
				s += 10.0
		if h >= Sim.ROWS:
			s -= 100.0
		if s > best_s:
			best_s = s
			best_c = c
	_s.aim(best_c)
	_s.drop()

## Lays the shelf out by hand, bottom up, column by column.
func _lay(cols: Array) -> void:
	var sim = _s.sim
	for c in Sim.COLS:
		var col: Array = sim.cols[c]
		col.clear()
		for v in cols[c]:
			sim._ids += 1
			col.append({"id": sim._ids, "v": v})
	_s._vis.clear()

func _piece(v: int, col: int, y: float) -> void:
	var sim = _s.sim
	sim._ids += 1
	sim.piece = {"kind": Sim.Piece.BLOCK, "v": v, "col": col, "y": y, "dropping": false, "hold": 0.0, "id": sim._ids}
	sim._set_phase(Sim.Phase.FALL)

func _mouse(canvas_at: Vector2, kind: String) -> void:
	var at: Vector2 = root.get_final_transform() * canvas_at
	var ev: InputEvent
	if kind == "move":
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		ev = m
	else:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = kind == "press"
		ev = b
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)

func _canvas(col: float, row: float) -> Vector2:
	return _s.field.get_global_transform_with_canvas() * _s.px(col, row)

func _process(delta: float) -> bool:
	_t += delta
	if _s != null and _s._paused and _s._end == null:
		_s._pause(false)
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				# the settings load at start-up resets the flag, so set it again here
				if OS.get_cmdline_user_args().has("reduce"):
					load("res://core/motion.gd").reduce = true
				_menu._open_arcade("stackwood")
				_s = _menu.get_node("Stackwood")
				_step = 2
		2:
			if _t > 2.5:
				_shot("2_ready")
				_step = 3
		3:
			_bot()
			if _t > 16.0:
				_shot("3_play")
				_step = 4
		4:
			_s.sim.phase = Sim.Phase.RESOLVE
			_s.sim._round_t = 99.0
			_lay([[512, 64, 16, 4], [256, 64, 32, 2, 4], [128, 64, 16, 8], [2048, 32, 4], [1024, 16, 8, 2]])
			_piece(8, 2, 5.6)
			_s.sim.acorns = 999
			_at = _t
			_step = 5
		5:
			if _t > _at + 0.5:
				_shot("4_shelf")
				# press over column 0, drag across to column 2, let go
				_mouse(_canvas(0, 6), "press")
				_at = _t
				_step = 6
		6:
			if _t > _at + 0.1:
				_mouse(_canvas(4, 6), "move")
				_mouse(_canvas(2, 6), "move")
			if _t > _at + 0.2:
				print("steered to column ", _s.sim.piece.get("col", -1))
				_mouse(_canvas(2, 6), "release")
				_at = _t
				_step = 7
		7:
			if _s.sim.phase == Sim.Phase.RESOLVE and _t > _at + 0.25:
				_shot("5_chain")
				_at = _t
				_step = 8
		8:
			if _s.sim.phase == Sim.Phase.FALL and not _s.sim.piece.is_empty() and _t > _at + 0.6:
				print("landed; column heights ", [_s.sim.height(0), _s.sim.height(1), _s.sim.height(2), _s.sim.height(3), _s.sim.height(4)])
				_shot("6_after")
				_s.sim.acorns = 999
				_s._on_tool(Sim.Tool.ZAP)
				_at = _t
				_step = 9
		9:
			if _t > _at + 0.12:
				_shot("7_zap")
				_at = _t
				_step = 10
		10:
			if _s.sim.phase == Sim.Phase.FALL and _t > _at + 1.0:
				_s.sim.acorns = 999
				_s._on_tool(Sim.Tool.BOMB)
				_s.aim(1)
				_at = _t
				_step = 11
		11:
			if _t > _at + 0.5:
				_shot("8_bomb_armed")
				_s.drop()
				_at = _t
				_step = 12
		12:
			if _t > _at + 0.35:
				_shot("9_bomb")
				_at = _t
				_step = 13
		13:
			if _s.sim.phase == Sim.Phase.FALL and _t > _at + 1.0:
				_s.sim.phase = Sim.Phase.RESOLVE
				_s.sim._round_t = 99.0
				_lay([[2, 4], [1024, 8], [], [1024, 2], [4]])
				_s.sim.max_v = 1024
				_piece(1024, 2, 3.0)
				_s.sim.phase = Sim.Phase.FALL
				_s.drop()
				_at = _t
				_step = 14
		14:
			if _t > _at + 0.75:
				_shot("10_2048")
				_at = _t
				_step = 15
		15:
			if _s.sim.phase == Sim.Phase.FALL and _t > _at + 2.0:
				_s.sim.phase = Sim.Phase.RESOLVE
				_s.sim._round_t = 99.0
				_lay([[2, 4, 8, 16, 32, 64, 128], [4, 8], [16, 2], [8], [2]])
				_piece(4096, 0, 7.2)
				_s.drop()
				_at = _t
				_step = 16
		16:
			if _s.sim.is_over() and _t > _at + 0.5:
				_shot("11_topple")
				_at = _t
				_step = 17
		17:
			if _s._end != null and _t > _at + 2.0:
				_shot("12_end")
				_at = _t
				_step = 18
		18:
			if _t > _at + 0.5:
				if _had:
					var f := FileAccess.open(PATH, FileAccess.WRITE)
					f.store_string(_before)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
				return true
	return false
