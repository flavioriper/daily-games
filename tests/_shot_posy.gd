extends SceneTree

## The Arcade tab and a game of Posy, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_posy.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 the first day dealt, 3 a swap dragged through the
## viewport (printed: the move and whether the screen took it), 4 the pick,
## 5 settled, 6 after a bot's play, 7 the Swap tool armed with a first pick,
## 8 a rainbow posy made by a line of five, 9 a breeze and a seed bomb
## swapped together, 10 a day done and its moves blooming, 11 the next day
## dealt, 14 day three's weeds, 15 a bee made by a square, 16 the bee tapped
## and flying, 17 day four's stones in a shaped bed, 18 stones knocked in
## play, 19 day five's moss, 20 the moss grown, 21 the offer of five more
## moves, 22 the moves given, 12 the last move spent and the bed wilting, 13
## the end card.
## Prints the draw calls at each shot. The end writes a score to
## user://arcade.cfg, so the file this machine had is put back.

const Sim = preload("res://arcade/posy_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _move: Array = []
var _extra := {}
const PATH := "user://arcade.cfg"

func _initialize() -> void:
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/ps_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d score=%d day=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_s.sim.score if _s != null else 0, _s.sim.day if _s != null else 0])

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

func _canvas(cell: Vector2) -> Vector2:
	return _s.field.get_global_transform_with_canvas() * _s.px(cell.x, cell.y)

## Puts the screen's picture of the bed back in step with the sim's, after
## the harness has laid tiles by hand.
func _sync() -> void:
	var sim = _s.sim
	_s._tiles.clear()
	for c in Sim.COLS:
		for r in Sim.ROWS:
			var t: Dictionary = sim.grid[c][r]
			if t.is_empty():
				continue
			_s._tiles[t.id] = _s._new_tile(Vector2(c, r), Vector2i(c, r), int(t.k), int(t.sp))

func _put(c: int, r: int, k: int, sp := Sim.Sp.NONE) -> void:
	var t: Dictionary = _s.sim.grid[c][r]
	if t.is_empty():
		print("harness: no tile to lay at ", Vector2i(c, r))
		return
	t.k = k if sp != Sim.Sp.RAINBOW else -1
	t.sp = sp

## Meets the day's goals with moves to spare, so the next day is dealt.
func _finish_day() -> void:
	for g: Dictionary in _s.sim.goals:
		g.got = int(g.need)
	_s._shown_goals = _s.sim.goals.duplicate(true)
	_s.sim.moves_left = 2
	_s._shown_moves = 2
	_s.sim._after_move()
	_s._take_events()

func _bot_move() -> void:
	if _s.busy() or _s.sim.is_over():
		return
	var m: Array = _s.sim.hint()
	if not m.is_empty():
		_s._try_swap(m[0], m[1])

func _process(delta: float) -> bool:
	_t += delta
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				if OS.get_cmdline_user_args().has("reduce"):
					load("res://core/motion.gd").reduce = true
				_menu._open_arcade("posy")
				_s = _menu.get_node("Posy")
				_step = 2
		2:
			if _t > 4.4 and not _s.busy():
				_shot("2_dealt")
				_move = _s.sim.hint()
				print("move to drag ", _move)
				var a: Vector2 = Vector2(_move[0])
				var b: Vector2 = Vector2(_move[1])
				_mouse(_canvas(a), "press")
				_mouse(_canvas(a.lerp(b, 0.25)), "move")
				_mouse(_canvas(a.lerp(b, 0.5)), "move")
				_mouse(_canvas(a.lerp(b, 0.5)), "release")
				_at = _t
				_step = 3
		3:
			if _t > _at + 0.1:
				print("taken: moves %d, queue %d" % [_s.sim.moves, _s._queue.size()])
				_shot("3_swap")
				_at = _t
				_step = 4
		4:
			if _t > _at + 0.16:
				_shot("4_pick")
				_at = _t
				_step = 5
		5:
			if _t > _at + 1.2:
				_shot("5_settled")
				_at = _t
				_step = 6
		6:
			if _t < _at + 7.0:
				_bot_move()
			elif not _s.busy():
				_shot("6_play")
				_s.sim.moves_left = 30
				_s._shown_moves = 30
				_s._on_tool(Sim.Tool.SWAP)
				_s._target(Vector2i(3, 3))
				_at = _t
				_step = 7
		7:
			if _t > _at + 0.5:
				_shot("7_swap_armed")
				_s._disarm()
				# a line of five waiting on one swap
				var k: int = (_s.sim.kind(Vector2i(4, 2)) + 1) % _s.sim.kinds
				for c in [2, 3, 5, 6]:
					_put(c, 2, k)
				_put(4, 3, k)
				_sync()
				_at = _t
				_step = 8
		8:
			if _t > _at + 0.4:
				_s._try_swap(Vector2i(4, 3), Vector2i(4, 2))
				_at = _t
				_step = 9
		9:
			if _t > _at + 0.35:
				_shot("8_rainbow_made")
				_at = _t
				_step = 10
		10:
			if not _s.busy() and _t > _at + 0.5:
				_put(3, 5, 0, Sim.Sp.ROW)
				_put(4, 5, 1, Sim.Sp.BOMB)
				_sync()
				_s._try_swap(Vector2i(3, 5), Vector2i(4, 5))
				_at = _t
				_step = 11
		11:
			if _t > _at + 0.3:
				_shot("9_combo")
				_at = _t
				_step = 12
		12:
			if not _s.busy() and _t > _at + 0.5:
				# one move from the day's goals, with moves to spare
				for g: Dictionary in _s.sim.goals:
					g.got = int(g.need)
				_s._shown_goals = _s.sim.goals.duplicate(true)
				_s.sim.moves_left = 6
				_s._shown_moves = 6
				_s.sim._after_move()
				_s._take_events()
				_at = _t
				_step = 13
		13:
			if _t > _at + 1.0:
				print("goals met: ", _s.sim.goals_met(), " day ", _s.sim.day)
				_shot("10_day_done")
				_at = _t
				_step = 14
		14:
			if not _extra.has("b") and _t > _at + 0.9:
				_extra["b"] = true
				_shot("10b_bloom_stars")
			if not _extra.has("c") and _s._flights.any(func(f: Dictionary) -> bool: return String(f.get("kind", "")) == "tool" and f.t > 0.35):
				_extra["c"] = true
				_shot("10c_gift")
			if not _s.busy() and _t > _at + 0.5:
				_shot("11_next_day")
				_at = _t
				_step = 20
		20:
			if not _s.busy() and _t > _at + 0.5 and _s.sim.day < 3:
				_finish_day()
				_at = _t
			elif not _s.busy() and _t > _at + 0.5:
				_shot("14_day3_weeds")
				# a square of four waiting on one swap, where the bed has room
				var o := Vector2i(2, 5)
				for r in range(Sim.ROWS - 2, -1, -1):
					for c in Sim.COLS - 2:
						var ok := true
						for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]:
							ok = ok and _s.sim.live(Vector2i(c, r) + d)
						if ok:
							o = Vector2i(c, r)
				var k: int = (_s.sim.kind(o + Vector2i(1, 1)) + 1) % _s.sim.kinds
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1)]:
					_put(o.x + d.x, o.y + d.y, k)
				_sync()
				_s._try_swap(o + Vector2i(2, 1), o + Vector2i(1, 1))
				_at = _t
				_step = 21
		21:
			if _t > _at + 0.3:
				_shot("15_bee_made")
				_at = _t
				_step = 22
		22:
			if not _s.busy() and _t > _at + 0.4:
				var bee := Vector2i(-1, -1)
				for c in Sim.COLS:
					for r in Sim.ROWS:
						if _s.sim.special(Vector2i(c, r)) == Sim.Sp.BEE:
							bee = Vector2i(c, r)
				print("bee at ", bee)
				if bee.x >= 0:
					_mouse(_canvas(Vector2(bee)), "press")
					_mouse(_canvas(Vector2(bee)), "release")
				_at = _t
				_step = 23
		23:
			if _t > _at + 0.2:
				print("fired: moves %d" % _s.sim.moves)
				_shot("16_bee_flying")
				_at = _t
				_step = 24
		24:
			if not _s.busy() and _t > _at + 0.5:
				_at = _t
				_step = 25
		25:
			if not _s.busy() and _t > _at + 0.5 and _s.sim.day < 4:
				_finish_day()
				_at = _t
			elif not _s.busy() and _t > _at + 0.5:
				_shot("17_day4_stones")
				_at = _t
				_step = 26
		26:
			if _t < _at + 6.0:
				_bot_move()
			elif not _s.busy():
				_shot("18_stones_play")
				_at = _t
				_step = 27
		27:
			if not _s.busy() and _t > _at + 0.5 and _s.sim.day < 5:
				_finish_day()
				_at = _t
			elif not _s.busy() and _t > _at + 0.5:
				_shot("19_day5_moss")
				_at = _t
				_step = 28
		28:
			if _t < _at + 5.0:
				_bot_move()
			elif not _s.busy():
				_shot("20_moss_grown")
				_s.sim.moves_left = 1
				_s._shown_moves = 1
				for g: Dictionary in _s.sim.goals:
					g.need = 99
				_s._shown_goals = _s.sim.goals.duplicate(true)
				_bot_move()
				_at = _t
				_step = 29
		29:
			if _s._offer != null and not _extra.has("offer"):
				_extra["offer"] = _t
			if _extra.has("offer") and _t > float(_extra["offer"]) + 0.6:
				_shot("21_offer")
				_s._take_offer()
				_at = _t
				_step = 30
		30:
			if _t > _at + 0.5:
				_shot("22_more_moves")
				_s.sim.moves_left = 1
				_s._shown_moves = 1
				for g: Dictionary in _s.sim.goals:
					g.need = 99
				_s._shown_goals = _s.sim.goals.duplicate(true)
				_bot_move()
				_at = _t
				_step = 15
		15:
			if _s.sim.is_over() and _s._over_said and _t > _at + 0.3:
				_shot("12_wilt")
				_at = _t
				_step = 16
		16:
			if _s._end != null and _t > _at + 2.4:
				_shot("13_end")
				_at = _t
				_step = 17
		17:
			if _t > _at + 0.5:
				_restore()
				return true
	if _t > 150.0:
		print("timed out at step ", _step)
		_restore()
		return true
	return false

func _restore() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
