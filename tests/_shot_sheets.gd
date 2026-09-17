extends SceneTree

## The two bottom sheets, open over the first board, after their slide has
## landed. Keyed on elapsed seconds, like _shot.gd.
##
##     godot --path . --resolution 540x960 --script res://tests/_shot_sheets.gd
##
## Saves /tmp/shot_rules.png and /tmp/shot_settings.png.

const OPEN_AT := 0.1
const RULES_AT := 1.6
const RULES_SHOT := 2.3
const SETTINGS_AT := 2.6
const SETTINGS_SHOT := 3.3

var _menu: Node
var _host: Node
var _t := 0.0
var _step := 0

func _initialize() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if _step == 0 and _t >= OPEN_AT:
		_menu._open(load("res://ui/registry.gd").PUZZLES[0])
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_step = 1
	elif _step == 1 and _t >= RULES_AT:
		_host.rules_sheet.open()
		_step = 2
	elif _step == 2 and _t >= RULES_SHOT:
		_shot("/tmp/shot_rules.png")
		_host.rules_sheet.close()
		_step = 3
	elif _step == 3 and _t >= SETTINGS_AT:
		_host.settings_sheet.open()
		_step = 4
	elif _step == 4 and _t >= SETTINGS_SHOT:
		_shot("/tmp/shot_settings.png")
		return true
	return false

func _shot(path: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
