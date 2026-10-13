extends SceneTree

## A change of level on a board with a level card (docs/agents/flat-screens.md,
## "The level card"): opens each id at Medium, asks the host for another
## level the way the card does, and shoots the slide's middle and its rest
## to /tmp/slide_<id>_mid.png and /tmp/slide_<id>_rest.png. Prints how many
## boards the host holds afterwards (one) and the level it is at.
##
##     godot --path . --resolution 810x1440 --always-on-top \
##         --rendering-driver opengl3_angle \
##         --script res://tests/_probe_level_slide.gd -- <id> [<id> ...] [to=<0..3>]

const SLOT := 150

var _menu: Node
var _host: Node
var _entries: Array = []
var _idx := 0
var _frames := 0
var _to := 2

func _initialize() -> void:
	var progress_path := "user://progress_harness.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
	var progress = load("res://core/progress.gd")
	progress.path = progress_path
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("to="):
			_to = int(a.substr(3))
		else:
			only.append(a)
	for e in load("res://ui/registry.gd").PUZZLES:
		if only.has(String(e.id)):
			_entries.append(e)
			progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(_delta: float) -> bool:
	_frames += 1
	if _idx >= _entries.size():
		return true
	var id := String(_entries[_idx].id)
	var slot := _frames % SLOT
	if slot == 5:
		_menu._open_at(_entries[_idx], 1)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
	elif slot == 70:
		_host._on_level(_to)
	elif slot == 82:
		root.get_texture().get_image().save_png("/tmp/slide_%s_mid.png" % id)
	elif slot == 140:
		root.get_texture().get_image().save_png("/tmp/slide_%s_rest.png" % id)
		var boards := 0
		for n in _host._board_holder.get_children():
			if n.has_method("capabilities"):
				boards += 1
		print("slide %s: boards=%d difficulty=%d" % [id, boards, _host._difficulty])
	elif slot == 148:
		_host.closed.emit()
		_idx += 1
	return false
