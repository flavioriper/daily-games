extends SceneTree

## The Arcade tab and a game of Lucky Thirteen, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_thirteen.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 the tray rolled in, 3 a chain drawn by a real drag
## through the viewport (printed: the chain the screen took), 4 the merge
## rolling in, 5 settled, 6 after a bot's play, 7 Swap armed with a first
## pick, 8 a tray laid by hand and a chain of twelves made into the 13, 9 a
## stuck tray, 10 the tumble, 11 the end card. Prints the draw calls at each
## shot. The end writes a score to user://arcade.cfg, so the file this
## machine had is put back.

const Sim = preload("res://arcade/thirteen_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _chain: Array = []
var _k := 0
const PATH := "user://arcade.cfg"

func _initialize() -> void:
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/lt_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d score=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_s.sim.score if _s != null else 0])

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

func _canvas(cell: Vector2i) -> Vector2:
	return _s.field.get_global_transform_with_canvas() * _s.px(cell.x, cell.y)

## Lays the tray out by hand, row by row from the top.
func _lay(rows: Array) -> void:
	var sim = _s.sim
	for r in Sim.ROWS:
		for c in Sim.COLS:
			sim._ids += 1
			sim.grid[c][r] = {"id": sim._ids, "v": rows[r][c]}
	sim.max_v = sim._biggest()
	sim.phase = Sim.Phase.PLAY
	_s._vis.clear()

## One move the probe's way: the smallest number's longest chain.
func _bot_move() -> void:
	var sim = _s.sim
	if sim.phase != Sim.Phase.PLAY or _s.busy():
		return
	var chain: Array = sim.hint()
	if chain.is_empty():
		return
	sim.begin(chain[0])
	for k in range(1, chain.size()):
		sim.extend(chain[k])
	sim.commit()
	_s._play_events()

## A fresh wallet holds boosters, so the boost card stands before every run
## and Second chance before every end card: play with none, and decline.
func _skip_gold() -> void:
	if _s == null:
		return
	var boost: Node = _s.get_node_or_null("BoostCard")
	if boost != null and not boost.is_queued_for_deletion():
		boost._on_play()
	var chance: Node = _s.get_node_or_null("SecondChance")
	if chance != null and not chance.is_queued_for_deletion():
		chance._on_no()

func _process(delta: float) -> bool:
	_t += delta
	_skip_gold()
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
				_menu._open_arcade("thirteen")
				_s = _menu.get_node("Thirteen")
				_step = 2
		2:
			if _t > 3.6:
				_shot("2_ready")
				_chain = _s.sim.hint()
				print("chain to draw ", _chain)
				_mouse(_canvas(_chain[0]), "press")
				_k = 1
				_at = _t
				_step = 3
		3:
			if _t > _at + 0.08:
				_at = _t
				if _k < _chain.size():
					_mouse(_canvas(_chain[_k]), "move")
					_k += 1
				else:
					print("the screen took ", _s.sim.path)
					_shot("3_chain")
					_mouse(_canvas(_chain[-1]), "release")
					_step = 4
		4:
			if _t > _at + 0.12:
				_shot("4_merge")
				_at = _t
				_step = 5
		5:
			if _t > _at + 1.0:
				_shot("5_settled")
				_at = _t
				_step = 6
		6:
			_bot_move()
			if _t > _at + 10.0:
				_shot("6_play")
				_s.sim.clovers = 999
				_at = _t
				_step = 7
		7:
			if _s._armed < 0 and not _s.busy():
				_s._on_tool(Sim.Tool.SWAP)
				_s._target(Vector2i(1, 2))
				_at = _t
			if _s._armed >= 0 and _t > _at + 0.4:
				_shot("7_swap_armed")
				_s._disarm()
				_lay([[1, 2, 3, 4, 5], [6, 7, 8, 9, 10], [11, 12, 3, 2, 1], [4, 12, 5, 6, 7], [12, 8, 9, 2, 3], [1, 2, 4, 5, 6]])
				_at = _t
				_step = 8
		8:
			if _t > _at + 0.6:
				_s.sim.max_v = 12
				_s.sim.begin(Vector2i(1, 2))
				_s.sim.extend(Vector2i(1, 3))
				_s.sim.extend(Vector2i(0, 4))
				_s._play_events()
				_s._chain_t = 1.0
				_at = _t
				_step = 9
		9:
			if _t > _at + 0.3:
				_shot("8_twelves")
				_s.sim.commit()
				_s._play_events()
				_at = _t
				_step = 10
		10:
			if _t > _at + 0.7:
				_shot("9_thirteen")
				_at = _t
				_step = 11
		11:
			if _t > _at + 1.6:
				_lay([[1, 2, 3, 4, 5], [6, 7, 8, 9, 10], [11, 1, 2, 3, 4], [5, 6, 7, 8, 9], [10, 11, 1, 2, 3], [4, 5, 6, 7, 8]])
				_s.sim.clovers = 60
				_s.sim._check()
				_s._play_events()
				_at = _t
				_step = 12
		12:
			if _t > _at + 1.0:
				print("phase ", _s.sim.phase, " (1 is stuck)")
				_shot("10_stuck")
				_s.sim.give_up()
				_s._play_events()
				_at = _t
				_step = 13
		13:
			if _t > _at + 0.35:
				_shot("11_tumble")
				_at = _t
				_step = 14
		14:
			if _s._end != null and _t > _at + 2.2:
				_shot("12_end")
				_at = _t
				_step = 15
		15:
			if _t > _at + 0.5:
				if _had:
					var f := FileAccess.open(PATH, FileAccess.WRITE)
					f.store_string(_before)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
				return true
	return false
