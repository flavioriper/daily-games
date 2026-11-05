extends SceneTree
## The swarm's end of tools/swarm_draw_loop.py (2026-11-05): opens the room,
## and whenever <folder>/cmd.json holds a new id, draws it (`draw`, with an
## optional `tone`), waits for the dots to land, and writes the snapshot the
## see tool would send as seen_<id>.jpg (then seen_<id>.jpg.done). `quit`
## ends it, as do two idle minutes. Touches no user:// save.

const SETTLE := 3.2

var _tab: Control
var _dir := "/tmp/swarm_eye"
var _last := -1
var _shoot_at := -1.0
var _shoot_id := -1
var _t := 0.0
var _heard := 0.0

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	for f in DirAccess.get_files_at(_dir):
		if f.begins_with("seen_") or f == "cmd.json":
			DirAccess.remove_absolute(_dir.path_join(f))

func _process(d: float) -> bool:
	_t += d
	if _tab == null:
		_tab = load("res://ui/menu/swarm_tab.gd").new()
		root.add_child(_tab)
		_tab.open()
		_heard = _t
		return false
	if not _tab._formed:
		return false
	if _shoot_id >= 0 and _t >= _shoot_at:
		var got: Dictionary = _tab.snapshot(384)
		var path := _dir.path_join("seen_%d.jpg" % _shoot_id)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(Marshalls.base64_to_raw(String(got.get("jpg", ""))))
		f.close()
		FileAccess.open(path + ".done", FileAccess.WRITE).close()
		print("seen %d %s" % [_shoot_id, got.get("error", "%d bytes" % int(got.get("bytes", 0)))])
		_shoot_id = -1
	var cmd_path := _dir.path_join("cmd.json")
	if FileAccess.file_exists(cmd_path):
		var cmd = JSON.parse_string(FileAccess.get_file_as_string(cmd_path))
		if cmd is Dictionary and int(cmd.get("id", -1)) != _last:
			_last = int(cmd.id)
			_heard = _t
			if cmd.get("quit", false):
				_tab.close()
				return true
			if cmd.has("tone"):
				_tab.apply_tone({"tone": cmd.tone})
			if cmd.has("draw"):
				print("draw %d %s" % [_last, _tab.apply_draw(cmd.draw)])
			_shoot_id = _last
			_shoot_at = _t + SETTLE
	if _t - _heard > 120.0:
		_tab.close()
		return true
	return false
