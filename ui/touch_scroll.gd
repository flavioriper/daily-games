extends Node

## A finger drags a ScrollContainer. Godot's own drag reads only mouse
## events, and this project turns emulate_mouse_from_touch off, so on a
## phone a list never scrolled (the age screen stopped at 1999). Fingers
## are read raw here, as ui/flat/pan_zoom.gd reads them; nothing is
## consumed, so a tap still reaches the button under it, and a button
## asks dragged() to tell a tap from the end of a drag.

const SLOP := 16.0

var _scroll: ScrollContainer
var _finger := -1
var _moved := 0.0

static func attach(scroll: ScrollContainer) -> Node:
	var t: Node = load("res://ui/touch_scroll.gd").new()
	t._scroll = scroll
	scroll.add_child(t, false, Node.INTERNAL_MODE_FRONT)
	return t

## True while the touch now ending moved the list, so its release is no tap.
func dragged() -> bool:
	return _moved > SLOP

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_moved = 0.0
			if _finger < 0 and _scroll.is_visible_in_tree() \
					and _scroll.get_global_rect().has_point(event.position):
				_finger = event.index
		elif event.index == _finger:
			_finger = -1
	elif event is InputEventScreenDrag and event.index == _finger:
		_moved += absf(event.relative.y)
		if dragged():
			_scroll.get_v_scroll_bar().value -= event.relative.y
