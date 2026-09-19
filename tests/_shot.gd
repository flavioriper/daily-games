extends SceneTree

## Walks every registered prototype, screenshots it, and moves on. Keyed on
## elapsed seconds rather than frames, so the shot lands after the board's
## entrance at any frame rate.

const OPEN_AT := 0.1
const SHOT_AT := 2.0
const CLOSE_AT := 2.2
## After the last close the menu replays its entrance; the menu shot waits it out.
const MENU_AT := 1.5

var _menu: Node
var _host: Node
var _t := 0.0
var _phase := 0  # 0 about to open, 1 open, 2 shot taken
var _idx := 0
var _entries: Array = []

func _initialize() -> void:
	# The two `soon` cards name a board that has no flat version, so they
	# have no script to open; the harness walks the ones that do.
	_entries = []
	for e in load("res://ui/registry.gd").PUZZLES:
		if not e.get("soon", false):
			_entries.append(e)
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if _idx >= _entries.size():
		if _t < MENU_AT:
			return false
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/shot_menu.png")
		print("saved /tmp/shot_menu.png")
		return true
	if _phase == 0 and _t >= OPEN_AT:
		_menu._open(_entries[_idx])
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_phase = 1
	elif _phase == 1 and _t >= SHOT_AT:
		var path := "/tmp/shot_%s.png" % _entries[_idx].id
		# The viewport texture is whatever was last drawn, and a windowed run
		# that loses focus stops drawing: without this, late entries in the
		# walk were saved carrying an earlier board's frame.
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(path)
		print("saved " + path)
		_phase = 2
	elif _phase == 2 and _t >= CLOSE_AT:
		_host.closed.emit()
		_idx += 1
		_phase = 0
		_t = 0.0
	return false
