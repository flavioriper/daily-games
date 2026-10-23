extends SceneTree

## The Peeplet (ui/peeplet_view.gd) standing over the real game, to judge it
## beside the house's own art: the menu, or a board opened from it. Windowed:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_peeplet_scene.gd -- <menu|board id> out=<png> [ink]
##
## The shot is taken a few seconds in, once the screen's entrance is over.

const PeepletView = preload("res://ui/peeplet_view.gd")
const SHOT_AT := 3.5

var _id := "menu"
var _out := "/tmp/peeplet_scene.png"
var _t := 0.0
var _opened := false
var _menu: Node

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a == "ink":
			PeepletFur.ink = true
		else:
			_id = a
	var progress_path := "user://_shot_peeplet_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
	var progress = load("res://core/progress.gd")
	progress.path = progress_path
	for e in load("res://ui/registry.gd").all():
		progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var view := PeepletView.new()
	view.position = Vector2(60.0, 1380.0)
	view.size = Vector2(320.0, 360.0)
	view.frame_height = 0.8 * 360.0 / 320.0
	layer.add_child(view)

func _process(delta: float) -> bool:
	_t += delta
	if not _opened and _id != "menu" and _t >= 0.5:
		_opened = true
		for e in load("res://ui/registry.gd").all():
			if e.id == _id:
				if bool(e.get("pick_difficulty", false)):
					_menu._open_at(e, 1)
				else:
					_menu._open(e)
		var host: Node = _menu.get_child(_menu.get_child_count() - 1)
		if host.has_node("HowToPlay"):
			host.get_node("HowToPlay").free()
	if _t >= SHOT_AT + (0.5 if _id != "menu" else 0.0):
		root.get_texture().get_image().save_png(_out)
		return true
	return false
