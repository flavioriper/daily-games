extends SceneTree

## The fair-ads flow through the real menu, with the desktop stand-in ad
## (ADS_FAKE_FULL) and pacing forced open: leaving a finished board for the
## list shows the interstitial; leaving an unfinished one, or taking the win
## screen's next level, does not. A solve is the board's own `solved` signal
## (the host's real _on_solved runs), not a played-out board. Throwaway ads,
## progress and wallet files; puts user://arcade.cfg back.
##   godot --resolution 810x1440 --always-on-top --script tests/_probe_ads_flow.gd

var _menu: Node
var _t := 0.0
var _step := 0
var _at := 0.0
var _fails := 0
var _host: Node
var _entry: Dictionary
var _files: Array = []
var _backup := {}

func _initialize() -> void:
	for n in ["arcade.cfg", "progress.cfg"]:
		var p: String = "user://" + n
		if FileAccess.file_exists(p):
			_backup[p] = FileAccess.get_file_as_bytes(p)
	var dir := OS.get_user_data_dir()
	var progress = load("res://core/progress.gd")
	progress.path = "user://_probe_ads_progress.cfg"
	var wallet: Node = root.get_node("Wallet")
	wallet.path = dir + "/_probe_ads_wallet.cfg"
	wallet.reload()
	var ads: Node = root.get_node("Ads")
	ads.state_path = dir + "/_probe_ads_state.cfg"
	_files = [dir + "/_probe_ads_progress.cfg", dir + "/_probe_ads_wallet.cfg", dir + "/_probe_ads_state.cfg"]
	for f in _files:
		DirAccess.remove_absolute(f)
	ads.reload_state()
	ads.post_play = true
	ads.pacing.merge({"grace_days": 0, "after_hearts": 0, "min_games_today": 1,
		"minutes_between": 0, "games_between": 1})
	var reg = load("res://ui/registry.gd")
	_entry = reg.PUZZLES[0]
	progress.mark_tutorial_seen(String(_entry.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print(("ok   " if ok else "FAIL ") + what)

func _ad_up() -> bool:
	for c in root.get_node("Ads").get_children():
		if c is CanvasLayer:
			for l in c.find_children("*", "Label", true, false):
				if (l as Label).text.begins_with("AD (interstitial"):
					return true
	return false

func _open_board() -> void:
	if bool(_entry.get("pick_difficulty", false)):
		_menu._open_at(_entry, 1)
	else:
		_menu._open(_entry)
	_host = _menu.get_child(_menu.get_child_count() - 1)
	if _host.has_node("HowToPlay"):
		_host.get_node("HowToPlay").free()

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

func _process(delta: float) -> bool:
	_t += delta
	if _t > 60.0:
		_check(false, "timed out")
		_finish(1)
		return true
	if _t < 1.5 or _t < _at:
		return false
	match _step:
		0:
			# after the autoload's own _ready has read the environment
			root.get_node("Ads")._fake_full = "1"
			_open_board()
			_host.closed.emit()   # left unfinished
			_step = 1
			_at = _t + 0.5
		1:
			_check(not _ad_up(), "unfinished board left: no ad")
			_open_board()
			_step = 2
			_at = _t + 0.5
		2:
			_host._puzzle.solved.emit()   # the host's real _on_solved
			_step = 3
			_at = _t + 0.5
		3:
			_check(not _ad_up(), "finished, still on the win screen: no ad")
			_host.closed.emit()
			_step = 4
			_at = _t + 0.5
		4:
			_check(_ad_up(), "finished board, back to the list: interstitial up")
			_step = 5
			_at = _t + 2.5
		5:
			_check(not _ad_up(), "stand-in gone after 1.5 s")
			_open_board()
			_host._puzzle.solved.emit()
			_step = 6
			_at = _t + 0.5
		6:
			# the win screen's next level: the same card reopens, no list stop
			_host.play_level.emit(1)
			_step = 7
			_at = _t + 0.5
		7:
			_check(not _ad_up(), "next level from the win screen: no ad")
			_host = _menu.get_child(_menu.get_child_count() - 1)
			_host.closed.emit()
			_step = 8
			_at = _t + 0.5
		8:
			_check(_ad_up(), "leaving that level for the list: interstitial up")
			_step = 9
			_at = _t + 2.5
		9:
			_finish(1 if _fails > 0 else 0)
			return true
	return false
