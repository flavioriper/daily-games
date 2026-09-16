extends SceneTree

## The first screen, both pages of it, after the entrance has landed.
##
##     godot --path . --resolution 540x960 --script res://tests/_shot_menu.gd
##
## Saves /tmp/shot_menu_1.png and /tmp/shot_menu_2.png.

const FIRST_AT := 1.8
const SECOND_AT := 2.8

var _menu: Node
var _t := 0.0
var _phase := 0

func _initialize() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if _phase == 0 and _t >= FIRST_AT:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/shot_menu_1.png")
		print("saved /tmp/shot_menu_1.png")
		_menu.show_page(1)
		_phase = 1
	elif _phase == 1 and _t >= SECOND_AT:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/shot_menu_2.png")
		print("saved /tmp/shot_menu_2.png")
		return true
	return false
