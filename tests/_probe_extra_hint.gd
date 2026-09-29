extends SceneTree

## add_hint() on every board that offers a hint: spend the board's own hints,
## check none is left, add one, check exactly one is left and that it plays.
## A board that ends or refuses for its own reasons is skipped with the reason.
## Throwaway progress file; puts user://arcade.cfg and progress.cfg back.
##   godot --resolution 810x1440 --always-on-top --script tests/_probe_extra_hint.gd

var _menu: Node
var _t := 0.0
var _started := false
var _fails := 0
var _backup := {}
var _files: Array = []

func _initialize() -> void:
	for n in ["arcade.cfg", "progress.cfg"]:
		var p: String = "user://" + n
		if FileAccess.file_exists(p):
			_backup[p] = FileAccess.get_file_as_bytes(p)
	var dir := OS.get_user_data_dir()
	var progress = load("res://core/progress.gd")
	progress.path = "user://_probe_hint_progress.cfg"
	_files = [dir + "/_probe_hint_progress.cfg"]
	for f in _files:
		DirAccess.remove_absolute(f)
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if _t > 400.0:
		print("FAIL timed out")
		_finish(1)
		return true
	if _t > 1.5 and not _started:
		_started = true
		_run()
	return false

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	load("res://core/analytics.gd").stop()
	var reg = load("res://ui/registry.gd")
	var progress = load("res://core/progress.gd")
	for entry in reg.PUZZLES:
		var id := String(entry.id)
		var script: GDScript = load(String(entry.script))
		var probe_board: Node = script.new()
		var caps: Array = probe_board.capabilities()
		probe_board.free()
		if not caps.has("hint"):
			print("skip %s: no hint capability" % id)
			continue
		progress.mark_tutorial_seen(id)
		_menu._open_at(entry, 1)
		var host: Node = _menu.get_child(_menu.get_child_count() - 1)
		if host.has_node("HowToPlay"):
			host.get_node("HowToPlay").free()
		await _wait(0.6)
		var p: Node = host._puzzle
		var note := await _probe(p)
		if note.begins_with("skip"):
			print("%s %s" % [note, id])
		else:
			_check(note == "", "%s %s" % [id, note])
		host.closed.emit()
		await _wait(0.4)
	_finish(1 if _fails > 0 else 0)

## "" when the board passes, "skip: why" when it cannot be tested, else the failure.
func _probe(p: Node) -> String:
	var spent := 0
	for i in 20:
		var ok := false
		for retry in 6:
			if p.is_done():
				return "skip: board done after %d hints" % spent
			ok = p.hint()
			if ok or p.hints_left() <= 0:
				break
			await _wait(0.6)
		if not ok:
			break
		spent += 1
		await _wait(0.4)
	if p.is_done():
		return "skip: board done after %d hints" % spent
	if p.hints_left() != 0:
		return "skip: hint() refuses with %d left after %d hints" % [p.hints_left(), spent]
	p.add_hint()
	if p.hints_left() != 1:
		return "hints_left after add_hint is %d, wanted 1" % p.hints_left()
	var got := false
	for retry in 6:
		if p.is_done():
			return ""
		got = p.hint()
		if got:
			break
		await _wait(0.6)
	if not got and not p.is_done():
		return "hint() failed after add_hint"
	return ""

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print(("ok   " if ok else "FAIL ") + what)

func _finish(code: int) -> void:
	for p in ["user://arcade.cfg", "user://progress.cfg"]:
		if _backup.has(p):
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(_backup[p])
			f.close()
	for f in _files:
		DirAccess.remove_absolute(f)
	print("FAILS: %d" % _fails)
	quit(code)
