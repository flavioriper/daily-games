extends SceneTree

## Chess driven by input alone: a tap on the e-pawn and a tap on e4, then a
## drag of the g-knight to f3, all as mouse events pushed into the window.
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_tap_chess.gd

const Rules = preload("res://versus/chess_rules.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _step := 0
var _had := false
var _record := ""

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and hold the
	# computer's answer (docs/agents/versus.md, Tutorials).
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists("user://versus.cfg")
	if _had:
		_record = FileAccess.get_file_as_string("user://versus.cfg")
	var cfg := ConfigFile.new()
	cfg.load("user://versus.cfg")
	cfg.set_value("colour", "chess", 0)
	cfg.save("user://versus.cfg")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _at(name: String) -> Vector2:
	var sq := "abcdefgh".find(name[0]) + (int(name[1]) - 1) * 8
	var b: Control = _s.board
	var local: Vector2 = b.px(b.cell_of(sq))
	return b.get_global_transform() * local

func _mouse(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(e, true)

func _motion(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)

func _process(delta: float) -> bool:
	_t += delta
	match _step:
		0:
			if _t > 1.0:
				_menu._show_tab("versus")
				_step = 1
		1:
			if _t > 1.6:
				var play: Button = _menu.versus_tab.find_child("Play_chess", true, false)
				play.pressed.emit()
				_step = 2
		2:
			_s = _menu.get_node_or_null("Chess")
			if _s != null and _s._state == _s.State.YOURS:
				_mouse(_at("e2"), true)
				_mouse(_at("e2"), false)
				_step = 3
		3:
			_mouse(_at("e4"), true)
			_mouse(_at("e4"), false)
			_step = 4
		4:
			if _s._history.size() >= 2 and _s._state == _s.State.YOURS:
				print("tap move: ", "ok" if _s.rules.board[28] == Rules.PAWN else "FAILED")
				var a := _at("g1")
				var z := _at("f3")
				_mouse(a, true)
				for k in 6:
					_motion(a.lerp(z, (k + 1) / 6.0))
				_mouse(z, false)
				_step = 5
		5:
			if _s._history.size() >= 3:
				print("drag move: ", "ok" if _s.rules.board[21] == Rules.KNIGHT else "FAILED")
				_step = 6
	if _step == 6 or _t > 30.0:
		if _step != 6:
			print("timeout at step ", _step)
		if _had:
			var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
			f.store_string(_record)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
		quit()
	return false
