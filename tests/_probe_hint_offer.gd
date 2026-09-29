extends SceneTree

## The video hint through the real menu on Binairo, with the desktop stand-in
## ad (ADS_FAKE_FULL): spend the hints, the hint button shows the play badge,
## a tap asks, No thanks leaves the board as it was, Watch grants one hint and
## the offer comes back (no limit a board); a "skip" ad grants nothing. Shoots the
## prompt in en, pt and es to /tmp/shot_hint_offer_<lang>.png. Throwaway
## progress, wallet and ads files; puts user://arcade.cfg back.
##   godot --resolution 810x1440 --always-on-top --script tests/_probe_hint_offer.gd

var _menu: Node
var _t := 0.0
var _step := 0
var _at := 0.0
var _fails := 0
var _host: Node
var _entry: Dictionary
var _files: Array = []
var _backup := {}
var _langs := ["en", "pt", "es"]
var _li := 0
var _insane_ids := ["balance", "trestle", "hiddenword"]
var _ii := 0

func _initialize() -> void:
	for n in ["arcade.cfg", "progress.cfg"]:
		var p: String = "user://" + n
		if FileAccess.file_exists(p):
			_backup[p] = FileAccess.get_file_as_bytes(p)
	var dir := OS.get_user_data_dir()
	var progress = load("res://core/progress.gd")
	progress.path = "user://_probe_hint_progress.cfg"
	var wallet: Node = root.get_node("Wallet")
	wallet.path = dir + "/_probe_hint_wallet.cfg"
	wallet.reload()
	wallet.should_auto_open()   # the gifts sheet's once-a-day opening, spent
	var ads: Node = root.get_node("Ads")
	ads.state_path = dir + "/_probe_hint_state.cfg"
	_files = [dir + "/_probe_hint_progress.cfg", dir + "/_probe_hint_wallet.cfg", dir + "/_probe_hint_state.cfg"]
	for f in _files:
		DirAccess.remove_absolute(f)
	ads.reload_state()
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

func _open_board() -> void:
	if bool(_entry.get("pick_difficulty", false)):
		_menu._open_at(_entry, 1)
	else:
		_menu._open(_entry)
	_host = _menu.get_child(_menu.get_child_count() - 1)
	if _host.has_node("HowToPlay"):
		_host.get_node("HowToPlay").free()

func _spend() -> void:
	var p = _host._puzzle
	var guard := 0
	while p.hints_left() > 0 and guard < 20:
		p.hint()
		guard += 1
	_host._refresh()

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
	if _t > 90.0:
		_check(false, "timed out")
		_finish(1)
		return true
	if _t < 1.5 or _t < _at:
		return false
	var ads: Node = root.get_node("Ads")
	match _step:
		0:
			ads._fake_full = "skip"
			_open_board()
			_step = 1
			_at = _t + 0.5
		1:
			var bar = _host.top_bar
			_check(bar.hint_button.badge > 0 and bar.hint_button.badge_glyph == "", "hints left: number badge, no glyph")
			_spend()
			_step = 2
			_at = _t + 0.3
		2:
			var bar = _host.top_bar
			_check(bar.hint_button.badge_glyph == "play" and not bar.hint_button.disabled, "spent: play badge, button enabled")
			_host._on_hint()
			_step = 3
			_at = _t + 0.6
		3:
			_check(_host.has_node("RewardPrompt"), "tap: prompt up")
			_host.get_node("RewardPrompt").find_child("No", true, false).pressed.emit()
			_step = 4
			_at = _t + 0.3
		4:
			_check(not _host.has_node("RewardPrompt"), "No thanks: prompt gone")
			_check(_host._puzzle.hints_left() == 0, "No thanks: no hint granted")
			_host._on_hint()
			_step = 5
			_at = _t + 0.6
		5:
			var used: int = _host._puzzle.hints_used
			_host.set_meta("used0", used)
			_host.get_node("RewardPrompt").find_child("Watch", true, false).pressed.emit()
			_step = 6
			_at = _t + 2.5
		6:
			_check(_host._puzzle.hints_used == _host.get_meta("used0"), "skip ad: nothing granted")
			_check(_host._hint_offer(), "skip ad: offer still open")
			ads._fake_full = "1"
			_host._on_hint()
			_step = 7
			_at = _t + 0.6
		7:
			_host.set_meta("used0", _host._puzzle.hints_used)
			_host.set_meta("counted0", int(ads.pacing.state.rewarded_today))
			_host.get_node("RewardPrompt").find_child("Watch", true, false).pressed.emit()
			_step = 8
			_at = _t + 2.5
		8:
			_check(_host._puzzle.hints_used == _host.get_meta("used0") + 1, "watched: one hint landed")
			var bar = _host.top_bar
			_check(not bar.hint_button.disabled and bar.hint_button.badge_glyph == "play", "after: offer back, play badge")
			_host._on_hint()
			_check(_host.has_node("RewardPrompt"), "after: a second offer")
			_host.get_node("RewardPrompt").find_child("Watch", true, false).pressed.emit()
			_step = 80
			_at = _t + 2.5
		80:
			_check(_host._puzzle.hints_used == _host.get_meta("used0") + 2, "second video: a second hint landed")
			_check(int(ads.pacing.state.rewarded_today) == _host.get_meta("counted0"), "hint videos never count against the daily cap")
			# look at the prompt in each language on a fresh board
			_open_or_reset_for_shots()
			_step = 9
			_at = _t + 0.5
		9:
			TranslationServer.set_locale(_langs[_li])
			_host._on_hint()
			_step = 10
			_at = _t + 0.9
		10:
			root.get_texture().get_image().save_png("/tmp/shot_hint_offer_%s.png" % _langs[_li])
			var pr = _host.get_node("RewardPrompt")
			pr.find_child("No", true, false).pressed.emit()
			_li += 1
			_step = 9 if _li < _langs.size() else 11
			_at = _t + 0.4
		11:
			TranslationServer.set_locale("en")
			_host.closed.emit()
			_insane_at(_insane_ids[_ii])
			_step = 12
			_at = _t + 0.6
		12:
			# Insane on a board that has no hint gives no video offer either.
			var caps: Array = _host._puzzle.capabilities()
			_check(not caps.has("hint"), "%s Insane: no hint capability" % _insane_ids[_ii])
			_check(_host._puzzle.hints_left() == 0, "%s Insane: hints_left is 0" % _insane_ids[_ii])
			_check(not _host._hint_offer(), "%s Insane: no video offer" % _insane_ids[_ii])
			_ii += 1
			if _ii < _insane_ids.size():
				_host.closed.emit()
				_insane_at(_insane_ids[_ii])
				_at = _t + 0.6
			else:
				_finish(1 if _fails > 0 else 0)
				return true
	return false

func _insane_at(id: String) -> void:
	var reg = load("res://ui/registry.gd")
	var found := {}
	for e in reg.PUZZLES:
		if String(e.get("id", "")) == id:
			found = e
	_check(not found.is_empty(), "registry has %s" % id)
	load("res://core/progress.gd").mark_tutorial_seen(id)
	_menu._open_at(found, 3)
	_host = _menu.get_child(_menu.get_child_count() - 1)
	if _host.has_node("HowToPlay"):
		_host.get_node("HowToPlay").free()

func _open_or_reset_for_shots() -> void:
	_host.closed.emit()
	_open_board()
	_spend()
	root.get_node("Ads")._fake_full = "1"
