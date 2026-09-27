extends SceneTree

## The Arcade tab and a game of Millstream, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_millstream.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 a fresh valley, 3 taps on an iron deposit through the
## viewport, the ore popping out onto the grass (printed: how many lie
## there), 4 taps on the grass picking it up, mid-flight into the bag
## (printed: the bag's ore), 5 the kiln tool's ghost and two kilns placed by
## tap, 6 the bag opened by a tap on its button, 7 a slot of ore dragged
## onto a kiln (printed: its hopper), 8 ingots popped out on the grass and
## picked by tap (printed), 9 a drag pans and a wheel zooms, 10 ingots
## dragged onto the Mill, the milestone and its banner. Prints the draw
## calls at each shot. user://millstream.cfg and user://arcade.cfg are put
## back.

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

func _hop(k: String, t: float) -> bool:
	if _t > _at + t and not has_meta(k):
		set_meta(k, true)
		return true
	return false

func _next() -> void:
	_at = _t
	_step += 1

func _bag_at() -> Vector2:
	return _s._bag_btn.position + _s._bag_btn.size * 0.5

func _slot_at(i: int) -> Vector2:
	return _s._strip.position + _s._strip.slot_rect(i).get_center()

func _process(delta: float) -> bool:
	_t += delta
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_next()
		1:
			if _t > _at + 1.0:
				_shot("1_tab")
				_menu._open_arcade("millstream")
				_s = _menu.get_node("Millstream")
				_next()
		2:
			if _t > _at + 1.2:
				_shot("2_valley")
				_next()
		3:
			# fourteen taps on the iron deposit at (7, 11), a tenth of a second apart
			var k := int((_t - _at) / 0.1)
			if k > int(get_meta("taps", -1)) and k < 14:
				set_meta("taps", k)
				_tap(_px(Vector2(8, 12)))
			if _hop("dug", 1.45):
				print("dug by tap: ", _s.sim.mined, " lying on the grass: ", _s.sim.loose.size())
				_shot("3_dug")
				_next()
		4:
			# a tap on each item lying there, one a frame
			if _s.sim.loose.size() > 0 and _t < _at + 1.5:
				_tap(_s.screen((_s.sim.loose[0].p as Vector2) * Art.TILE))
			elif not has_meta("empty"):
				set_meta("empty", _t)
			elif _t > float(get_meta("empty")) + 0.25 and _hop("picked", 0.0):
				print("picked by tap: bag ore ", _s.sim.stock.iron_ore, " still flying ", _s._inflight, " left on grass ", _s.sim.loose.size())
				_shot("4_picked")
				_next()
		5:
			if _hop("down", 0.6):
				_s.sim.stock.iron_ore = 60
				_s._on_tool("kiln")
				_mouse(_px(Vector2(11, 13)), "down")
			elif _hop("up", 0.9):
				_shot("5_ghost")
				_mouse(_px(Vector2(11, 13)), "up")
			elif _hop("second", 1.1):
				if _s._tool != "kiln":
					_s._on_tool("kiln")
				_tap(_px(Vector2(11, 9)))
			elif _hop("placed", 1.3):
				print("kilns placed by tap: ", _s.sim.buildings.size())
				_s._set_tool("")
				_tap(_bag_at())
				_next()
		6:
			if _hop("bag", 0.5):
				print("bag open by tap: ", _s._bag_open)
				_shot("6_bag")
				_mouse(_slot_at(0), "down")
			elif _hop("m1", 0.6):
				_mouse(_slot_at(0) + Vector2(0, -80), "move")
			elif _hop("m2", 0.7):
				_mouse(_px(Vector2(11, 13)) + Vector2(0, 64), "move")
			elif _hop("m3", 0.85):
				_shot("7_drag")
				_mouse(_px(Vector2(11, 13)) + Vector2(0, 64), "up")
			elif _hop("fed", 1.0):
				print("dragged onto a kiln: hoppers ", _s.sim.buildings.map(func(b: Dictionary) -> int: return b.hopper), " bag ore ", _s.sim.stock.iron_ore)
				# the second kiln from the bag too
				_mouse(_slot_at(0), "down")
			elif _hop("m4", 1.1):
				_mouse(_px(Vector2(11, 9)) + Vector2(0, 64), "move")
			elif _hop("m5", 1.2):
				_mouse(_px(Vector2(11, 9)) + Vector2(0, 64), "up")
				_next()
		7:
			if _hop("ingots", 5.0):
				print("second kiln fed: hoppers ", _s.sim.buildings.map(func(b: Dictionary) -> int: return b.hopper), " ingots lying: ", _s.sim.loose.size())
				_shot("8_ingots")
				_next()
		8:
			if _s.sim.loose.size() > 0 and _t < _at + 1.0:
				_tap(_s.screen((_s.sim.loose[0].p as Vector2) * Art.TILE))
			elif _hop("got", 0.0):
				print("ingots picked by tap: bag ", _s.sim.stock.iron_ingot)
				_next()
		9:
			if _hop("pan", 0.5):
				set_meta("cam", _s._cam)
				var from := _px(Vector2(10, 16))
				_mouse(from, "down")
				_mouse(from + Vector2(-60, -200), "move")
				_mouse(from + Vector2(-120, -400), "move")
				_mouse(from + Vector2(-120, -400), "up")
				for k in 2:
					_mouse(_s.field.size * 0.5, "down", MOUSE_BUTTON_WHEEL_DOWN)
					_mouse(_s.field.size * 0.5, "up", MOUSE_BUTTON_WHEEL_DOWN)
			elif _hop("panned", 0.9):
				print("panned: ", _s._cam != get_meta("cam"), " zoom=%.3f" % _s._zoom)
				_shot("9_panned")
				_s.sim.stock.iron_ingot = 25
				_next()
		10:
			var mill: Vector2 = _s.screen((Vector2(Sim.MILL.position) + Vector2(1.5, 1.5)) * Art.TILE) + Vector2(0, 64)
			if _hop("i0", 0.3):
				_mouse(_slot_at(1), "down")
			elif _hop("i1", 0.4):
				_mouse(_slot_at(1) + Vector2(0, -80), "move")
			elif _hop("i2", 0.5):
				_mouse(mill, "move")
			elif _hop("i3", 0.65):
				print("dragging: ", _s._drag, " strip at ", _s._strip.position, " visible ", _s._strip.visible)
				_shot("10_drag_mill")
				_mouse(mill, "up")
			elif _hop("i4", 1.6):
				print("handed in by dragging ingots onto the Mill: ", _s.sim.finished())
				_shot("11_milestone")
				_next()
		11:
			return true
	return false
