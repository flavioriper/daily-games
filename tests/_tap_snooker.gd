extends SceneTree

## Drives a frame of snooker by input alone: open it from the Versus tab's
## Play button, drag the cue ball in the D, tap the table to aim, pull the
## power slot down and let go; then Back returns to the Versus tab.
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_tap_snooker.gd -- <outdir>

var _menu: Node
var _screen: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _mouse(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	e.global_position = at
	if pressed:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)

func _move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)

func _tap(c: Control) -> void:
	var at := c.get_global_rect().get_center()
	_mouse(at, true)
	_mouse(at, false)

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/tap_%s.png" % [_out, name])
	print("shot ", name, " t=", snappedf(_t, 0.1))

func _process(delta: float) -> bool:
	_t += delta
	match _step:
		0:
			if _t > 1.0:
				_tap(_menu.bar._tabs["versus"].icon)
				_step = 1
		1:
			if _t > 1.8:
				print("tab now ", _menu._tab)
				var play: Control = _menu.versus_tab.find_children("*", "Button", true, false).back()
				_tap(play)
				_step = 2
		2:
			if _t > 3.0:
				_screen = _menu.get_node_or_null("Snooker")
				print("screen open: ", _screen != null, " state ", _screen._state if _screen else -1)
				var table: Control = _screen.table
				# carry the cue ball to the right of the D
				var from: Vector2 = table.get_global_transform() * table.px(_screen.sim.pos[0])
				var to: Vector2 = table.get_global_transform() * table.px(_screen.sim.pos[0] + Vector2(0.2, 0.05))
				_mouse(from, true)
				_move(from.lerp(to, 0.5))
				_move(to)
				_mouse(to, false)
				print("cue ball now ", _screen.sim.pos[0])
				# aim at the pack's right edge
				var aim: Vector2 = table.get_global_transform() * table.px(_screen.sim.pos[15] + Vector2(0.05, 0.0))
				_mouse(aim, true)
				_mouse(aim, false)
				print("aim ", _screen.table.aim_dir)
				_step = 3
		3:
			if _t > 3.4:
				var bar: Control = _screen.power_bar
				var r := bar.get_global_rect()
				var top := r.position + Vector2(r.size.x * 0.5, 40.0)
				_mouse(top, true)
				_move(top + Vector2(0, r.size.y * 0.35))
				_move(top + Vector2(0, r.size.y * 0.6))
				_shot("pull")
				_step = 4
		4:
			if _t > 3.7:
				var bar: Control = _screen.power_bar
				var r := bar.get_global_rect()
				_mouse(r.position + Vector2(r.size.x * 0.5, 40.0 + r.size.y * 0.6), false)
				_step = 5
		5:
			if _t > 4.2:
				print("after release state ", _screen._state, " moving ", _screen.sim.moving())
				_shot("rolling")
				_step = 6
		6:
			if _t > 6.0:
				_screen._on_back()
				_step = 7
		7:
			if _t > 7.0:
				print("back on tab ", _menu._tab, " list visible ", _menu._list_root.visible, " pager visible ", _menu._pager.visible)
				_shot("back")
				quit()
	return false
