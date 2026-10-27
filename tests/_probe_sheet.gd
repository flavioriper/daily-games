extends SceneTree

## Throwaway probe (2026-10-27): a puzzle card asks on the difficulty sheet
## again. Through the real menu, offline (tests/_offline_main.gd), on
## Sudoku: `_open` raises the sheet and mounts no board; the row last played
## carries the ring; a second `_open` while it is up mounts nothing; two fast
## taps on one row mount exactly one board, at that row's level, and save it
## as the last level; `chose.emit(entry, 3)` (the path the Try Hard invite
## and the sheet share) mounts one at 3. Progress, wallet and ads state sit in
## throwaway files, and the player's own progress.cfg is read back byte for
## byte on every exit path.
##   godot --path . --resolution 810x1440 --rendering-driver opengl3_angle --always-on-top --script tests/_probe_sheet.gd

## Loaded at run time: a preload here compiles before the autoloads exist.
var _flat_host: GDScript
var _menu: Node
var _t := 0.0
var _at := 0.0
var _step := 0
var _fails := 0
var _entry: Dictionary
var _files: Array = []
var _real_bytes := PackedByteArray()
var _real_existed := false
var _real_last := -2

func _initialize() -> void:
	_flat_host = load("res://ui/flat/flat_host.gd")
	var real := "user://progress.cfg"
	_real_existed = FileAccess.file_exists(real)
	if _real_existed:
		_real_bytes = FileAccess.get_file_as_bytes(real)
	var progress = load("res://core/progress.gd")
	_real_last = progress.last_level("sudoku")
	var dir := OS.get_user_data_dir()
	progress.path = "user://_probe_sheet_progress.cfg"
	var wallet: Node = root.get_node("Wallet")
	wallet.path = dir + "/_probe_sheet_wallet.cfg"
	wallet.reload()
	wallet.should_auto_open()
	var ads: Node = root.get_node("Ads")
	ads.state_path = dir + "/_probe_sheet_state.cfg"
	_files = [dir + "/_probe_sheet_progress.cfg", dir + "/_probe_sheet_wallet.cfg", dir + "/_probe_sheet_state.cfg"]
	for f in _files:
		DirAccess.remove_absolute(f)
	ads.reload_state()
	_entry = load("res://ui/registry.gd").find("sudoku")
	progress.mark_tutorial_seen("sudoku")
	progress.set_last_level("sudoku", 1)
	var main: Node = load("res://world/main.tscn").instantiate()
	main.set_script(load("res://tests/_offline_main.gd"))
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print(("ok   " if ok else "FAIL ") + what)

func _hosts() -> Array:
	var out: Array = []
	for c in _menu.get_children():
		if c.get_script() == _flat_host and not c.is_queued_for_deletion():
			out.append(c)
	return out

func _ringed() -> Array:
	var out: Array = []
	for row in _menu.difficulty_sheet._list.get_children():
		for c in row.get_children():
			if "last" in c:
				out.append(bool(c.last))
	return out

func _finish() -> void:
	for f in _files:
		DirAccess.remove_absolute(f)
	DirAccess.remove_absolute(OS.get_user_data_dir() + "/_probe_sheet_progress.cfg")
	# The player's own progress, as it was.
	var real := "user://progress.cfg"
	if _real_existed:
		var f := FileAccess.open(real, FileAccess.WRITE)
		f.store_buffer(_real_bytes)
		f.close()
	elif FileAccess.file_exists(real):
		DirAccess.remove_absolute(real)
	var progress = load("res://core/progress.gd")
	progress.path = real
	_check(progress.last_level("sudoku") == _real_last, "the player's last sudoku level is back at %d" % _real_last)
	print("RESULT: %s (%d fails)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)

func _process(delta: float) -> bool:
	_t += delta
	if _t > 40.0:
		_check(false, "timed out at step %d" % _step)
		_finish()
		return true
	if _t < 1.5 or _t < _at:
		return false
	var sheet: Control = _menu.difficulty_sheet
	match _step:
		0:
			_menu._open(_entry)
			_step = 1
			_at = _t + 0.8
		1:
			_check(sheet.visible, "_open raises the difficulty sheet")
			_check(_hosts().is_empty(), "no board is mounted behind it")
			_check(_ringed() == [false, true, false, false], "the row last played (Medium) alone is ringed: %s" % [_ringed()])
			_menu._open(_entry)
			_step = 2
			_at = _t + 0.3
		2:
			_check(sheet.visible and _hosts().is_empty(), "a second _open while it is up mounts nothing")
			# Two fast taps on the Hard row, the second on top of the first.
			var rows: Array = sheet._list.get_children()
			rows[2].pressed.emit()
			rows[2].pressed.emit()
			_step = 3
			_at = _t + 1.5
		3:
			var hosts := _hosts()
			_check(hosts.size() == 1, "two fast taps mount exactly one board (%d)" % hosts.size())
			if hosts.size() == 1:
				_check(int(hosts[0]._difficulty) == 2, "at difficulty 2 (Hard)")
			var progress = load("res://core/progress.gd")
			_check(progress.last_level("sudoku") == 2, "last_level is 2 (%d)" % progress.last_level("sudoku"))
			for h in hosts:
				h.queue_free()
			_step = 4
			_at = _t + 0.5
		4:
			sheet.chose.emit(_entry, 3)
			_step = 5
			_at = _t + 0.8
		5:
			var hosts := _hosts()
			_check(hosts.size() == 1, "chose.emit mounts one board (%d)" % hosts.size())
			if hosts.size() == 1:
				_check(int(hosts[0]._difficulty) == 3, "at difficulty 3 (Insane)")
			var progress = load("res://core/progress.gd")
			_check(progress.last_level("sudoku") == 3, "last_level is 3 (%d)" % progress.last_level("sudoku"))
			_finish()
			return true
	return false
