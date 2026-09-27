extends SceneTree

## The Arcade tab and a game of Millstream, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_millstream.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 a fresh valley, 3 taps on an iron deposit through the
## viewport (printed: ore dug), 4 the kiln tool with its ghost held over
## grass, then a tap placing it (printed), 5 two kilns at work after a tend
## by tap, 6 a drag pans and a wheel zooms (printed: the camera moved),
## 7 the milestone handed in with the banner. Prints the draw calls at each
## shot. user://millstream.cfg and user://arcade.cfg are put back.

const Sim = preload("res://arcade/millstream_sim.gd")
const Art = preload("res://arcade/millstream_art.gd")
const FILES := ["user://millstream.cfg", "user://arcade.cfg"]

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := {}

func _initialize() -> void:
	for f: String in FILES:
		_before[f] = FileAccess.get_file_as_string(f) if FileAccess.file_exists(f) else null
		if FileAccess.file_exists(f) and f.ends_with("millstream.cfg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.has("reduce"):
		load("res://core/motion.gd").reduce = true
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _finalize() -> void:
	for f: String in FILES:
		var path := ProjectSettings.globalize_path(f)
		if _before[f] == null:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(path)
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_string(_before[f])

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/ms_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d ore=%d ingots=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(_s.sim.stock.iron_ore) if _s != null else 0, int(_s.sim.stock.iron_ingot) if _s != null else 0])

## A mouse event at a point of the field (field px), through the window.
func _mouse(local: Vector2, kind: String, button := MOUSE_BUTTON_LEFT) -> void:
	var f: Control = _s.field
	var at: Vector2 = root.get_final_transform() * (f.get_global_transform_with_canvas() * local)
	if kind == "move":
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.global_position = at
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mv)
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = kind == "down"
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)

func _tap(p: Vector2) -> void:
	_mouse(p, "down")
	_mouse(p, "up")

## A world point (tiles) on the field.
func _px(tiles: Vector2) -> Vector2:
	return _s.screen(tiles * Art.TILE)

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
				_menu._open_arcade("millstream")
				_s = _menu.get_node("Millstream")
				_step = 2
		2:
			if _t > 3.0:
				_shot("2_valley")
				_at = _t
				_step = 3
		3:
			# fourteen taps on the iron deposit at (7, 11), a tenth of a second apart
			var k := int((_t - _at) / 0.1)
			if k > int(get_meta("taps", -1)) and k < 14:
				set_meta("taps", k)
				_tap(_px(Vector2(8, 12)))
			if _t > _at + 1.6:
				print("dug by tap: ", _s.sim.mined)
				_shot("3_dug")
				_s.sim.stock.iron_ore = 60
				_s._on_tool("kiln")
				_at = _t
				_step = 4
		4:
			# the kiln tool chosen: press on grass (the ghost), shoot, let go
			if not has_meta("down"):
				set_meta("down", true)
				_mouse(_px(Vector2(11, 13)), "down")
			elif _t > _at + 0.3 and not has_meta("up"):
				set_meta("up", true)
				_shot("4_ghost")
				_mouse(_px(Vector2(11, 13)), "up")
			elif _t > _at + 0.5 and not has_meta("second"):
				set_meta("second", true)
				print("placed by tap: ", _s.sim.buildings.size(), " tool now: '", _s._tool, "'")
				if _s._tool != "kiln":
					_s._on_tool("kiln")
				_tap(_px(Vector2(11, 10)))
			elif _t > _at + 0.7:
				print("second placed by tap: ", _s.sim.buildings.size())
				_s._set_tool("")
				for b: Dictionary in _s.sim.buildings:
					_tap(_px(Vector2(b.cell) + Vector2(1, 1)))
				_at = _t
				_step = 5
		5:
			if _t > _at + 0.2:
				print("kilns loaded by tap: ", _s.sim.buildings.map(func(b: Dictionary) -> int: return b.hopper), " ore left ", _s.sim.stock.iron_ore)
				_at = _t
				_step = 6
		6:
			if _t > _at + 3.0:
				_shot("5_kilns")
				set_meta("cam", _s._cam)
				var from := _px(Vector2(10, 16))
				_mouse(from, "down")
				_mouse(from + Vector2(-60, -200), "move")
				_mouse(from + Vector2(-120, -400), "move")
				_mouse(from + Vector2(-120, -400), "up")
				_mouse(_s.field.size * 0.5, "down", MOUSE_BUTTON_WHEEL_DOWN)
				_mouse(_s.field.size * 0.5, "down", MOUSE_BUTTON_WHEEL_DOWN)
				_at = _t
				_step = 7
		7:
			if _t > _at + 0.4:
				print("panned: ", _s._cam != get_meta("cam"), " zoom=%.3f" % _s._zoom)
				_shot("6_panned")
				_s.sim.stock.iron_ingot = 25
				_tap(_s.screen((Vector2(Sim.MILL.position) + Vector2(1.5, 1.5)) * Art.TILE))
				_at = _t
				_step = 8
		8:
			if _t > _at + 0.9:
				print("handed in by tap on the Mill: ", _s.sim.finished())
				_shot("7_milestone")
				_step = 9
		9:
			return true
	return false
