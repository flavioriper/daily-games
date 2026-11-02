extends SceneTree

## The Arcade tab and Brittle through the menu, with real touches:
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_brittle.gd -- <outdir> [reduce] [en|pt|es]
## Puts user://arcade.cfg back on every exit.

const Sim = preload("res://arcade/brittle_sim.gd")
const PATH := "user://arcade.cfg"

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _blind := false
var _had := false
var _backup := PackedByteArray()
var _fails := 0
var _draws_max := 0
var _ms_max := 0.0

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists(PATH)
	if _had:
		_backup = FileAccess.get_file_as_bytes(PATH)
	_blind = DisplayServer.get_name() == "headless"
	for a: String in OS.get_cmdline_user_args():
		if a == "reduce":
			load("res://core/motion.gd").reduce = true
		elif a in ["en", "pt", "es"]:
			load("res://core/locale.gd")._current = a
		else:
			_out = a
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print(("ok   " if ok else "FAIL ") + what)

func _shot(name: String) -> void:
	if not _blind:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/bt_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

func _win(at: Vector2) -> Vector2:
	var c: Control = _s.board
	return root.get_final_transform() * (c.get_global_transform_with_canvas() * at)

func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = _win(at)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _drag(at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = _win(at)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _rig(step_n: int, balls: int) -> void:
	var sim = _s.sim
	sim.step_n = step_n
	sim.balls = balls
	sim.kind.fill(Sim.Kind.NONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for r in 8:
		for c in 7:
			var i: int = Sim.index(r, c)
			var roll := rng.randf()
			if roll < 0.6:
				sim.kind[i] = Sim.Kind.SQUARE
			elif roll < 0.68:
				sim.kind[i] = Sim.Kind.TL + rng.randi_range(0, 3)
			elif roll < 0.72:
				sim.kind[i] = Sim.Kind.POP
			elif roll < 0.82:
				sim.kind[i] = [Sim.Kind.PLUS, Sim.Kind.ROW, Sim.Kind.COL, Sim.Kind.FIZZ][rng.randi_range(0, 3)]
			if Sim.solid(sim.kind[i]):
				sim.hp[i] = rng.randi_range(1, step_n * 2 + 40)
				sim.full[i] = int(sim.hp[i] * rng.randf_range(1.0, 2.5))
	_s.board.lay(sim)

func _next() -> void:
	_step += 1
	_at = _t

func _process(delta: float) -> bool:
	_t += delta
	var sim = _s.sim if _s != null else null
	var board = _s.board if _s != null else null
	if board != null and sim != null and sim.flying():
		_draws_max = maxi(_draws_max, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		_ms_max = maxf(_ms_max, delta * 1000.0)
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_next()
		1:
			if _t > _at + 1.0:
				_shot("1_tab")
				_menu._open_arcade("brittle")
				_s = _menu.get_node("Brittle")
				_next()
		2:
			if _t > _at + 0.8:
				var card: Node = _s.get_node_or_null("BoostCard")
				if card != null:
					_shot("2a_boosts")
					card._on_play()
				_next()
		3:
			if _t > _at + 1.0:
				_check("a run is laid: step 1, one ball", sim != null and sim.step_n == 1 and sim.balls == 1)
				_shot("2_new")
				var f: Rect2 = board.frame_rect()
				_touch(f.get_center(), true)
				_next()
		4:
			if _t > _at + 0.15:
				var f: Rect2 = board.frame_rect()
				_drag(f.position + f.size * Vector2(0.7, 0.3))
				_next()
		5:
			if _t > _at + 0.3:
				_check("the aim is up", board._aiming and board._aim_ok)
				_shot("3_aim")
				_touch(board.frame_rect().get_center(), false)
				_next()
		6:
			if _t > _at + 0.2:
				_check("a real touch fired", sim.flying() or sim.volleys == 1)
				_next()
		7:
			if not sim.flying() and board.settled():
				_check("the row came down, step 2", sim.step_n == 2)
				_rig(45, 180)
				_s.top_bar.hint.emit()
				_next()
		8:
			if _t > _at + 0.3:
				_check("the bulb is armed", board.long_sight)
				var f: Rect2 = board.frame_rect()
				_touch(f.get_center(), true)
				_drag(f.position + f.size * Vector2(0.28, 0.5))
				_next()
		9:
			if _t > _at + 0.3:
				_shot("4_sight")
				_touch(board.frame_rect().get_center(), false)
				_next()
		10:
			if _t > _at + 3.2:
				_check("the sight was spent", sim.sights == Sim.SIGHTS - 1 and not board.long_sight)
				_shot("5_stream")
				_next()
		11:
			if _t > _at + 2.0:
				_shot("6_stream_b")
				print("volley draws max %d, frame max %.1f ms, balls %d, score %d" % [_draws_max, _ms_max, sim.balls, sim.score])
				_check("under the budget mid volley", _draws_max < 855)
				_check("the arrow is live", not _s._recall.disabled)
				_s._recall.pressed.emit()
				_next()
		12:
			if not sim.flying() and board.settled():
				_check("called home, row down", sim.step_n == 46)
				_check("undo is open", _s.can_undo())
				var was: int = sim.step_n
				_s.top_bar.undo.emit()
				_check("undo took the step back", sim.step_n == was - 1 and sim.undos == Sim.UNDOS - 1)
				_next()
		13:
			if _t > _at + 0.6:
				_shot("7_undo")
				# a square one row from the end, and a fast aim straight up
				sim.balls = 1
				for r in Sim.ROWS:
					for c in 7:
						if Sim.solid(sim.kind[Sim.index(r, c)]):
							sim.hp[Sim.index(r, c)] = 999
							sim.full[Sim.index(r, c)] = 999
				sim.kind[Sim.index(Sim.ROWS - 1, 0)] = Sim.Kind.SQUARE
				sim.hp[Sim.index(Sim.ROWS - 1, 0)] = 900
				sim.full[Sim.index(Sim.ROWS - 1, 0)] = 900
				board.lay(sim)
				_shot("8_tight")
				var f: Rect2 = board.frame_rect()
				_touch(f.get_center(), true)
				_drag(f.position + f.size * Vector2(0.5, 0.82))
				_touch(f.get_center(), false)
				_next()
		14:
			if sim.is_over() and _s.get_node_or_null("SecondChance") == null and _s._end == null and _t > _at + 0.5:
				pass
			if _s.get_node_or_null("SecondChance") != null:
				_check("a Second chance is offered", true)
				_shot("9_chance")
				_s.get_node("SecondChance").emit_signal("taken")
				_s.get_node("SecondChance").queue_free()
				_next()
			elif _s._end != null:
				_step = 16
				_at = _t
		15:
			if _t > _at + 0.6:
				_check("the run goes on, the low rows gone", not sim.is_over())
				_shot("10_revived")
				sim.over = true
				sim.events.append({"kind": "over"})
				_s._chance_used = true
				_s._over_told = false
				_next()
		16:
			if _s._end != null and _t > _at + 2.6:
				_check("the end card stands and the best is kept", load("res://arcade/arcade_record.gd").best("brittle") > 0)
				_shot("11_end")
				_finish()
	if _t > 150.0:
		_check("timed out at step %d" % _step, false)
		_finish()
	return false

func _finish() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_buffer(_backup)
		f.close()
	else:
		DirAccess.remove_absolute(PATH)
	print("failed: %d" % _fails)
	quit(_fails)
