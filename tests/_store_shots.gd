extends SceneTree

## Store screenshots (2026-11-05): the game rendered into a SubViewport at a
## phone's own pixels (w x h, default 1080x2340), never the window, so the
## frames are sharp and laid out at the phone's aspect. The Swarm chip is
## taken off the row (store builds never show it). Walks `list`, a comma list
## of `menu`, `streak`, `stats` or `<board id>:<difficulty>`, saving
## <out>/<item>.png.
##
##   godot --path . --resolution 810x1440 --always-on-top --script res://tests/_store_shots.gd -- out=<dir> list=menu,rings:1

const OPEN_WAIT := 3.0
const CLOSE_WAIT := 1.2

var _sub: SubViewport
var _menu: Node
var _host: Node
var _items: PackedStringArray = []
var _out := "/tmp"
var _t := 0.0
var _i := 0
var _phase := -1
var _closed := false
var _hints := 0

func _initialize() -> void:
	var w := 1080
	var h := 2340
	var list := "menu"
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"w": w = int(kv[1])
			"h": h = int(kv[1])
			"out": _out = kv[1]
			"list": list = kv[1]
	_items = list.split(",", false)
	_seed()
	var holder := SubViewportContainer.new()
	holder.stretch = false
	holder.size = Vector2(w, h)
	root.add_child(holder)
	_sub = SubViewport.new()
	_sub.size = Vector2i(w, h)
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.transparent_bg = false
	holder.add_child(_sub)
	var main: Node = load("res://world/main.tscn").instantiate()
	main.get_node("UI/Menu").set_script(load("res://tests/_store_menu.gd"))
	_sub.add_child(main)
	_menu = main.get_node("UI/Menu")

## Every tutorial marked seen, and three weeks of solves in the log so the
## Streak tab has a garden to show. The caller restores the save dir.
func _seed() -> void:
	var ids := ["hiddenword", "sudoku", "rings", "quilt", "planes", "untangle", "pie", "nonogram", "buttons", "queens"]
	for e in load("res://ui/registry.gd").PUZZLES:
		Progress.mark_tutorial_seen(String(e.id))
	var today := Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system() + "T12:00:00")
	for back in range(1, 23):
		var dt := Time.get_date_dict_from_unix_time(today - back * 86400)
		var key := int("%04d%02d%02d" % [dt.year, dt.month, dt.day])
		for k in range(3 + back % 2):
			Progress.log_solve(ids[(back + k * 3) % ids.size()], k % 3, {"seconds": 90.0 + back * 7, "moves": 30, "hints": 0}, key)
	Progress.log_solve("rings", 0, {"seconds": 75.0, "moves": 20, "hints": 0})

func _drop_swarm() -> void:
	var bar: Node = _menu.bar
	if bar._tabs.has("bot"):
		var h: Node = bar._tabs["bot"].holder
		h.get_parent().remove_child(h)
		h.queue_free()
		bar._tabs.erase("bot")
		# as rebuild_tabs does: one category, no row
		bar.visible = bar._tabs.size() > 1

func _save(name: String) -> void:
	RenderingServer.force_draw()
	var p := "%s/%s.png" % [_out, name.replace(":", "_")]
	_sub.get_texture().get_image().save_png(p)
	print("saved " + p)

func _process(delta: float) -> bool:
	_t += delta
	if _phase == -1:
		if _t < 2.0:
			return false
		_drop_swarm()
		_phase = 0
		_t = 0.0
	if _i >= _items.size():
		return true
	var item := _items[_i]
	if _phase == 0:
		if item == "back":
			_menu.header.back_button.pressed.emit()
			print("back -> tab=%s arrow=%s row=%s" % [_menu._tab, _menu.header.back_button.visible, _menu.bar.visible])
			_i += 1
			_t = 0.0
			return false
		if item == "menu":
			_menu._show_tab("home")
		elif item == "streak" or item == "stats":
			_menu._show_tab(item)
		else:
			var parts := item.split(":")
			var entry: Dictionary = {}
			for e in load("res://ui/registry.gd").PUZZLES:
				if e.id == parts[0]:
					entry = e
			var d := int(parts[1]) if parts.size() > 1 else 1
			var host: Control = load("res://ui/flat/flat_host.gd").new()
			host.setup(entry, d, false)
			_menu._mount_host(host)
			_host = host
			_hints = int(parts[2]) if parts.size() > 2 else 0
		_phase = 1
		_t = 0.0
	elif _phase == 1 and _hints > 0 and _t >= 1.0 + 0.0:
		var b: Node = _host._puzzle if _host != null else null
		if b != null and b.has_method("hint"):
			if b.has_method("add_hint"):
				b.add_hint()
			b.hint()
		_hints -= 1
		_t = 0.6 if _hints > 0 else -1.0
	elif _phase == 1 and _t >= OPEN_WAIT:
		_save(item)
		print("%s tab=%s arrow=%s row=%s" % [item, _menu._tab, _menu.header.back_button.visible, _menu.bar.visible])
		_phase = 2
		_t = 0.0
	elif _phase == 2:
		if _t < 0.05:
			return false
		if not _closed:
			_closed = true
			if _host != null:
				_host.closed.emit()
				_host = null
		if _t >= CLOSE_WAIT:
			_closed = false
			_i += 1
			_phase = 0
			_t = 0.0
	return false
