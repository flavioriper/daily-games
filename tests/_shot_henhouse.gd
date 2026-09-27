extends SceneTree

## The Arcade tab and a game of Henhouse, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_henhouse.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 the ready banner, 3 a real drag through the viewport
## from an egg to the crate (printed: whether it sold), 4 a grown farm
## (forced: every machine, squirrels, the rooster, chicks, eggs on the
## belt), 5 eggs held over the belt with the troughs low, 6 the Barn tab,
## 7 the end card after retiring. Prints the draw calls at each shot. The
## end writes a time to user://arcade.cfg, so the file this machine had is
## put back.

const Sim = preload("res://arcade/henhouse_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
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
	root.get_texture().get_image().save_png("%s/hh_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d money=%d flock=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(_s.sim.money) if _s != null else 0, _s.sim.flock() if _s != null else 0])

func _mouse(local: Vector2, kind: String) -> void:
	var f: Control = _s.field
	# canvas to window: the event is read back through the stretch
	var at: Vector2 = root.get_final_transform() * (f.get_global_transform_with_canvas() * local)
	if kind == "move":
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.global_position = at
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mv)
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = kind == "down"
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)

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
				_menu._open_arcade("henhouse")
				_s = _menu.get_node("Henhouse")
				_step = 2
		2:
			if _t > 2.5:
				_shot("2_ready")
				_step = 3
		3:
			# wait for the first egg, then drag it to the crate for real
			var eggs: Array = _s.sim.eggs
			if not eggs.is_empty() and _s.sim.phase == Sim.Phase.PLAY:
				set_meta("sold", _s.sim.sold)
				_mouse(_s.px(eggs[0].pos + Vector2(0, -4)), "down")
				_at = _t
				_step = 4
		4:
			if not has_meta("held"):
				set_meta("held", true)
				print("held after press: ", _s._held, " pressed ", _s._pressed)
			var k := clampf((_t - _at) / 0.5, 0.0, 1.0)
			var from: Vector2 = _s.px(Sim.PEN.get_center())
			_mouse(from.lerp(_s.px(Sim.CRATE.get_center()), k), "move")
			if _t > _at + 0.35 and not has_meta("mid"):
				set_meta("mid", true)
				_shot("3_drag")
			if k >= 1.0:
				_mouse(_s.px(Sim.CRATE.get_center()), "up")
				_at = _t
				_step = 5
		5:
			if _t > _at + 0.1:
				print("drag sold: ", _s.sim.sold > int(get_meta("sold")))
				var sim = _s.sim
				sim.money = 60000.0
				for item in ["belt", "washer", "stamp", "packer", "radio", "rooster", "basket", "auto_feed", "auto_water", "squirrel", "squirrel", "squirrel", "feed", "feed"]:
					sim.buy(item)
				for i in 14:
					sim.buy("hen")
				for i in 3:
					var c: Dictionary = sim._add_hen(Sim.Kind.CHICK, Sim.PEN.get_center() + Vector2(i * 30 - 30, 40))
					c.grow = 0.3 * i
					c.asleep = i == 1
				sim.money = 4321.0
				_s._play_events()
				_at = _t
				_step = 6
		6:
			if _t > _at + 7.0:
				_shot("4_farm")
				var sim = _s.sim
				sim.feed = sim.cap() * 0.15
				sim.water = sim.cap() * 0.4
				# lay a little heap to scoop
				for i in 5:
					sim.eggs.append({"id": 9000 + i, "st": Sim.Egg.GROUND, "pos": Vector2(170 + i * 5, 200 + (i % 2) * 5), "gold": i == 2,
						"fertile": i == 4, "washed": false, "stamped": false, "boxed": false, "age": 1.0})
				_s.press(Vector2(178, 200))
				_s.move(Vector2(120, Sim.BELT_Y - 30))
				_at = _t
				_step = 7
		7:
			_s.move(Vector2(120, Sim.BELT_Y - 30))
			if _t > _at + 0.4:
				_shot("5_hold")
				_s.lift(Vector2(120, Sim.BELT_Y))
				_s._set_tab("factory")
				_at = _t
				_step = 8
		8:
			if _t > _at + 0.6:
				_shot("6_barn")
				_s.sim.money = float(Sim.RETIRE) + 5.0
				_at = _t
				_step = 9
		9:
			if _t > _at + 0.4:
				_s._retire_btn.pressed.emit()
				_at = _t
				_step = 10
		10:
			if _s._end != null and _t > _at + 3.0:
				_shot("7_end")
				_at = _t
				_step = 11
		11:
			if _t > _at + 0.5:
				if _had:
					var f := FileAccess.open(PATH, FileAccess.WRITE)
					f.store_string(_before)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
				quit()
	return false
