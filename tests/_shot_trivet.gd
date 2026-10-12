extends SceneTree

## The Arcade tab and Trivet, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_trivet.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab, 2 the boost card and a new run, 3 a stack carried by a
## real touch over the place it would take, 4 set down (printed), 5 a tray
## laid for a chain and the stack that sets it off carried there by a real
## touch: mats in the air (5a), the first stack going (5b), the second
## (5c, "Double!") and the level it makes, a lid lifted (5d), 6 a tight
## tray, 7 the brush armed by a real touch and a stack taken off by another
## (printed), a fresh hand by a third (printed), 8 the tray full with a
## brush held, 9 full with none: the Second chance card, declined, and the
## end card. Prints the draw calls at each shot. With no display it shoots
## nothing and still drives every beat, so it serves as a smoke run.
## user://arcade.cfg is put back on every way out.

const Sim = preload("res://arcade/trivet_sim.gd")
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
	var sim = _s.sim if _s != null else null
	if not _blind:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/tv_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d score=%d level=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.score if sim != null else 0, sim.level if sim != null else 0])

## A point of the table as the window has it.
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

func _tap(at: Vector2) -> void:
	_touch(at, true)
	_touch(at, false)

## Where a finger holds the hand's stack so that its foot is on `cell`.
func _over_cell(cell: int) -> Vector2:
	return _s.board.place_px(cell) + Vector2(0, _s.board.CARRY_UP * _s.board._u)

func _cell(q: int, r: int) -> int:
	return int(_s.sim._index[Vector2i(q, r)])

func _run(col: int, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(col)
	return out

## The table laid again with the sim as the harness has set it.
func _lay() -> void:
	var sim = _s.sim
	sim.events.clear()
	sim.events.append({"type": "deal", "fresh": false, "hand": sim.hand.duplicate(true)})
	_s.board.lay(sim)

func _done() -> bool:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_buffer(_backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("%d failed" % _fails)
	return true

func _next() -> void:
	_at = _t
	_step += 1

func _process(delta: float) -> bool:
	_t += delta
	if _t > 120.0:
		print("gave up at step %d" % _step)
		_fails += 1
		return _done()
	if _menu.arcade_tab == null:
		print("the menu did not come up")
		_fails += 1
		return _done()
	var sim = _s.sim if _s != null else null
	var board: Control = _s.board if _s != null else null
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_next()
		1:
			if _t > _at + 1.0:
				_shot("1_tab")
				_menu.arcade_tab.turn(1)
				_at = _t
				_step = 100
		100:
			if _t > _at + 0.6:
				_check("the tab's second page holds the thirteenth card", _menu.arcade_tab._page == 1 and _menu.arcade_tab._shown().size() == 5)
				_shot("1b_tab")
				_step = 1
				_menu._open_arcade("trivet")
				_s = _menu.get_node("Trivet")
				_next()
		2:
			if _t > _at + 0.8:
				var card: Node = _s.get_node_or_null("BoostCard")
				_check("the boost card stands before the first run", card != null)
				_shot("2a_boosts")
				if card != null:
					card._on_play()
				_next()
		3:
			if _t > _at + 1.0:
				_check("a run is laid: three stacks in the hand, 13 places open", sim != null and sim.empties() == 13 and board.settled())
				_shot("2_new")
				_touch(board.slot_px(0) - Vector2(0, 30.0), true)
				_next()
		4:
			if _t > _at + 0.1:
				_drag(board.slot_px(0).lerp(_over_cell(_cell(0, 0)), 0.5))
				_next()
		5:
			if _t > _at + 0.1:
				_drag(_over_cell(_cell(0, 0)))
				_next()
		6:
			if _t > _at + 0.4:
				_shot("3_carry")
				_touch(_over_cell(_cell(0, 0)), false)
				_next()
		7:
			if _t > _at + 0.5:
				_check("a real touch carried a stack to the middle", not (sim.stacks[_cell(0, 0)] as Array).is_empty() and sim.placed == 1)
				_shot("4_down")
				# a chain: seven of colour 0 beside the middle, nine of colour 1
				# on its other side, and a stack of both in the hand
				for i in sim.cells.size():
					sim.stacks[i] = []
				sim.stacks[_cell(1, 0)] = _run(0, 7)
				sim.stacks[_cell(-1, 0)] = _run(1, 9)
				sim.stacks[_cell(0, 1)] = [2, 2, 1, 2]
				sim.stacks[_cell(1, -2)] = [1, 1, 2, 2, 0]
				sim.hand = [[1, 0, 0, 0], [2, 2], [0, 1, 1]]
				sim.score = Sim.goal(1) - 12
				_lay()
				_next()
		8:
			if _t > _at + 0.6:
				_touch(board.slot_px(0) - Vector2(0, 30.0), true)
				_drag(board.slot_px(0).lerp(_over_cell(_cell(0, 0)), 0.5))
				_drag(_over_cell(_cell(0, 0)))
				_touch(_over_cell(_cell(0, 0)), false)
				_next()
		9:
			if _t > _at + 0.3:
				_check("the chain was two stacks put away and a level", sim.best_chain == 2 and sim.level == 2 and sim.score == Sim.goal(1) - 12 + 30)
				_shot("5a_hop")
				_next()
		10:
			if _t > _at + 0.45:
				_shot("5b_clear")
				_next()
		11:
			if _t > _at + 0.75:
				_shot("5c_double")
				_next()
		12:
			if _t > _at + 0.6:
				_shot("5d_level")
				_next()
		13:
			if _t > _at + 1.6:
				_check("the table has shown it all: the plates read the score", board.settled() and board.shown_score == sim.score and board.shown_level == 2)
				# tight: every open place but two under a stack, no two tops alike
				for i in sim.cells.size():
					if not sim.closed[i]:
						sim.stacks[i] = [posmod(sim.cells[i].x - sim.cells[i].y, 3), 3 + posmod(sim.cells[i].x - sim.cells[i].y, 3)]
				sim.stacks[_cell(0, 0)] = []
				sim.stacks[_cell(1, 0)] = []
				sim.stacks[_cell(0, 1)] = [0, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4, 5]
				sim.hand = [[0, 0], [1, 2, 2], [3, 3, 3, 3]]
				sim.sweeps = 1
				sim.deals = 1
				_lay()
				_next()
		14:
			if _t > _at + 0.8:
				_shot("6_tight")
				_tap(board.tool_px("sweep"))
				_next()
		15:
			if _t > _at + 0.4:
				_check("a real touch armed the brush", board.armed == "sweep")
				_shot("7_armed")
				_tap(board.place_px(_cell(0, 1)) - Vector2(0, 40.0))
				_next()
		16:
			if _t > _at + 0.25:
				_check("a real touch took the tall stack off", (sim.stacks[_cell(0, 1)] as Array).is_empty() and sim.sweeps == 0)
				_shot("7b_swept")
				var before: Array = sim.hand.duplicate(true)
				_tap(board.tool_px("deal"))
				_check("a real touch dealt a fresh hand", sim.deals == 0 and sim.hand.size() == 3 and sim.hand != before)
				_next()
		17:
			if _t > _at + 0.7:
				_shot("7c_fresh")
				# full, a brush held
				for i in sim.cells.size():
					if not sim.closed[i] and (sim.stacks[i] as Array).is_empty():
						sim.stacks[i] = [posmod(sim.cells[i].x - sim.cells[i].y, 3)]
				sim.sweeps = 1
				sim._check()
				var keep: Array = sim.events.duplicate()
				_lay()
				sim.events = keep
				board.play()
				_next()
		18:
			if _t > _at + 0.8:
				_check("full with a brush held is not over", not sim.is_over() and sim.is_full())
				_shot("8_full")
				sim.sweeps = 0
				sim._check()
				board.play()
				_next()
		19:
			if _t > _at + 1.6:
				var chance: Node = _s.get_node_or_null("SecondChance")
				_check("the run is over and the Second chance is offered", sim.is_over() and chance != null)
				_shot("9a_chance")
				if chance != null:
					chance._on_no()
				_next()
		20:
			if _t > _at + 2.4:
				_check("the end card is up", _s._end != null)
				_shot("9_end")
				return _done()
	return false
