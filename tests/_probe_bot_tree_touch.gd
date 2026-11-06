extends SceneTree
## Throwaway: the Swarm room inside the real menu tree, tapped with real
## touches through the root viewport. Which control takes each tap?

var _t := 0.0
var _step := 0
var _menu: Control
var _bs: Control
var _layer: CanvasLayer

func _touch(i: int, p: bool, at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = i; e.pressed = p; e.position = at
	return e

func _initialize() -> void:
	TranslationServer.set_locale("en")
	OS.set_environment("BOT_URL", "ws://127.0.0.1:9/ws/bot")
	_layer = CanvasLayer.new()
	root.add_child(_layer)
	_menu = load("res://ui/menu.tscn").instantiate()
	_layer.add_child(_menu)
	_layer.add_child(load("res://ui/ads/banner_host.tscn").instantiate())

func _who(at_canvas: Vector2) -> String:
	var hits := []
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(at_canvas):
			hits.append("%s(%s z%d)" % [c.get_path(), c.get_class(), c.z_index])
	return "\n    ".join(hits.slice(max(0, hits.size() - 6)))

func _tap(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	var w := root.get_final_transform() * p
	print("tap ", c.name, " at ", p, " window ", w, "\n  stack (last = topmost by tree):\n    ", _who(p))
	root.push_input(_touch(0, true, w))
	root.push_input(_touch(0, false, w))

func _process(d: float) -> bool:
	_t += d
	match _step:
		0:
			if _t > 1.0:
				_menu._on_tab("bot")
				_bs = _menu.bot_screen
				_step = 1; _t = 0
		1:
			if _t > 3.0:
				print("root size ", root.size, " bs rect ", _bs.get_global_rect(), " phase ", _bs._phase)
				var pill: Button = _bs._pills[0]
				print("pill visible ", pill.visible, " rect ", pill.get_global_rect())
				_tap(pill)
				_step = 2; _t = 0
		2:
			if _t > 0.5:
				print("after pill: demo ", _bs.face.demo().size())
				_bs._set_phase("live")
				_bs._process(0.016)
				print("mic visible ", _bs._mic_btn.visible, " rect ", _bs._mic_btn.get_global_rect(), " disabled ", _bs._mic_btn.disabled)
				var p: Vector2 = _bs._mic_btn.get_global_rect().get_center()
				print("mic stack:\n    ", _who(p))
				root.push_input(_touch(0, true, root.get_final_transform() * p))
				print("mic held after press: ", _bs._held)
				root.push_input(_touch(0, false, root.get_final_transform() * p))
				_bs._set_phase("offline")
				_step = 3; _t = 0
		3:
			if _t > 0.5:
				_tap(_bs._back)
				_step = 4; _t = 0
		4:
			if _t > 1.0:
				print("after back: room visible ", _bs.visible)
				return true
	return false
