extends SceneTree

## Walks every registered prototype, screenshots it, and moves on.
## Reusable as puzzles get added.
## The slot is long enough for a board's entrance to finish before the shot.

const SLOT := 120

var _menu: Node
var _host: Node
var _frames := 0
var _idx := 0
var _entries: Array = []

func _initialize() -> void:
	_entries = load("res://ui/registry.gd").PUZZLES
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(_delta: float) -> bool:
	_frames += 1
	var local := _frames % SLOT
	if _idx >= _entries.size():
		var img := root.get_texture().get_image()
		img.save_png("/tmp/shot_menu.png")
		print("saved /tmp/shot_menu.png")
		return true
	if local == 5:
		_menu._open(_entries[_idx])
		_host = _menu.get_child(_menu.get_child_count() - 1)
	elif local == 100:
		var img := root.get_texture().get_image()
		img.save_png("/tmp/shot_%s.png" % _entries[_idx].id)
		print("saved /tmp/shot_%s.png" % _entries[_idx].id)
	elif local == 110:
		_host.closed.emit()
		_idx += 1
	return false
