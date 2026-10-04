extends SceneTree

## The Arcade tab and a game of Peapod, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_peapod.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 the ready banner, 3 play with a bot, 4 the whole cast
## in a wall (forced: every paint, every gift and pod, the firecracker, the
## golden, iron and rotten crates, the helper, a pod held, gifts falling), 5 a real slide through the viewport
## (printed: whether the cart rolled), 6 the millipede, 7 the line neared,
## 8 the end card. Prints the draw calls at each shot. The end writes a
## score to user://arcade.cfg, so the file this machine had is put back on
## every way out.

const Sim = preload("res://arcade/peapod_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _hand := 150.0
var _x0 := 0.0
const PATH := "user://arcade.cfg"

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and eat the taps.
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.has("reduce"):
		load("res://core/motion.gd").reduce = true
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _restore() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/pp_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d score=%d wave=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_s.sim.score if _s != null and _s.sim != null else 0, _s.sim.wave if _s != null and _s.sim != null else 0])

## Rolls under a falling gift, else under the lowest crate or the plate
## furthest along.
func _bot(delta: float) -> void:
	var sim = _s.sim
	var want: float = sim.x
	if not sim.tokens.is_empty():
		want = sim.tokens[0].x
	elif sim.wave_kind == Sim.Wave.WALL:
		for r in sim.rows.size():
			var found := false
			for c in Sim.COLS:
				if sim.rows[r][c] != null:
					want = (c + 0.5) * Sim.CELL_W
					found = true
					break
			if found:
				break
	elif not sim.segs.is_empty():
		want = Sim.path_at(float(sim.segs[0].s) + 8.0).x
	_hand = move_toward(_hand, want, 300.0 * delta)
	sim.target_x = _hand

func _cell(kind: int, hp: int) -> Dictionary:
	return {"kind": kind, "hp": hp, "max": hp, "id": 9000 + randi() % 9000}

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

func _mouse(pressed: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)

func _process(delta: float) -> bool:
	_t += delta
	if _t > 120.0:
		print("timed out at step ", _step)
		_restore()
		return true
	_skip_gold()
	# the window losing focus pauses the game; the harness plays on
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
				_menu._open_arcade("peapod")
				_s = _menu.get_node("Peapod")
				_step = 2
		2:
			if _t > 2.6:
				_shot("2_ready")
				_step = 3
		3:
			_bot(delta)
			if _t > 12.0:
				_shot("3_play")
				_step = 4
		4:
			# the cast, forced: a wall of every paint and every kind
			var sim = _s.sim
			sim.wave_kind = Sim.Wave.WALL
			sim.gap_t = 0.0
			sim.segs.clear()
			sim.rows.clear()
			var hps := [[2, 5, 9, 14, 30], [45, 90, 150, 260, 500], [800, 1500, 2400, 5200, 12000]]
			for r in 3:
				var row: Array = []
				for c in Sim.COLS:
					row.append(_cell(Sim.Kind.CRATE, hps[r][c]))
				sim.rows.append(row)
			sim.rows.append([_cell(Sim.Kind.PEA, 3), _cell(Sim.Kind.RATE, 3), _cell(Sim.Kind.POWER, 3), _cell(Sim.Kind.TWIN, 3), _cell(Sim.Kind.BOMB, 9)])
			sim.rows.append([_cell(Sim.Kind.GOLD, 77), _cell(Sim.Kind.IRON, 38), _cell(Sim.Kind.CRATE, 1), _cell(Sim.Kind.ROT, 4), _cell(Sim.Kind.GOLD, 4)])
			sim.rows.append([_cell(Sim.Kind.FAN, 3), _cell(Sim.Kind.PIERCE, 3), _cell(Sim.Kind.BURST, 3), _cell(Sim.Kind.MAGNET, 3), _cell(Sim.Kind.FROST, 3)])
			sim.rows.append([_cell(Sim.Kind.SHOVE, 3), null, null, null, null])
			sim.wall_y = 290.0
			sim.wall_speed = 0.0
			sim.pod = Sim.Kind.PIERCE
			sim.pod_t = 8.0
			sim.magnet_t = 6.0
			sim.frost_t = 4.0
			sim.twin_t = 5.0
			sim.twin_x = 80.0
			sim.peas = 3
			sim.power = 1
			sim.shots.clear()
			sim.tokens = [{"kind": Sim.Kind.PEA, "x": 40.0, "y": 300.0, "vy": 0.0, "id": 1}, {"kind": Sim.Kind.RATE, "x": 100.0, "y": 330.0, "vy": 0.0, "id": 2},
				{"kind": Sim.Kind.ROT, "x": 200.0, "y": 310.0, "vy": 0.0, "id": 3}, {"kind": Sim.Kind.BURST, "x": 260.0, "y": 330.0, "vy": 0.0, "id": 4}]
			sim.target_x = 150.0
			_hand = 150.0
			_at = _t
			_step = 5
		5:
			for tk: Dictionary in _s.sim.tokens:
				tk.vy = 0.0
				tk.y = minf(float(tk.y), 340.0)
			_s.sim.magnet_t = 6.0
			_s.sim.frost_t = 4.0
			if _t > _at + 0.25:
				_shot("4_cast")
				# a real slide, through the viewport: press, drag right, let go
				var f: Control = _s.field
				var from: Vector2 = f.get_global_transform_with_canvas() * (f.size * Vector2(0.4, 0.8))
				var win: Vector2 = root.get_final_transform() * from
				_x0 = _s.sim.x
				_mouse(true, win)
				var mv := InputEventMouseMotion.new()
				mv.position = win + Vector2(90, 0)
				mv.global_position = mv.position
				mv.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(mv)
				set_meta("win", win + Vector2(90, 0))
				_at = _t
				_step = 6
		6:
			if _t > _at + 0.3:
				print("slide rolled the cart: %s (%.1f -> %.1f)" % [_s.sim.x > _x0 + 20.0, _x0, _s.sim.x])
				_shot("5_slide")
				_mouse(false, get_meta("win"))
				# on to a millipede
				var sim = _s.sim
				sim.rows.clear()
				sim.tokens.clear()
				sim.wave = 5
				sim.gap_t = 0.01
				_at = _t
				_step = 7
		7:
			_bot(delta)
			if _t > _at + 7.0:
				_shot("6_milli")
				# and its head near the end of the path
				_s.sim.segs[0].s = Sim.path_len() - 150.0 if not _s.sim.segs.is_empty() and _s.sim.segs[0].kind == Sim.Kind.HEAD else 0.0
				_at = _t
				_step = 8
		8:
			_s.sim.target_x = 30.0
			if _t > _at + 2.0:
				_shot("7_near")
				_step = 9
		9:
			_s.sim.target_x = 30.0
			if _s.sim.is_over() and _s._end != null and _t > _at + 3.0:
				_at = _t
				_step = 10
		10:
			if _t > _at + 2.6:
				_shot("8_end")
				_restore()
				return true
	return false
