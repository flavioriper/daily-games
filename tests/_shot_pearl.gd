extends SceneTree

## Shots and probes of Pearl Dive, played through the board's own way in: the
## keys of the tray under the card, pressed as a thumb presses them, and its
## Enter. Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_pearl.gd -- [d=0..3] [mode] [rm] [fixed] [out=<dir>] [lang=pt]
##
## `fixed` deals the tutorial's prompt on every slot in place of the bank's.
## Modes: `rest` (the entrance, the card standing ready, the dive, a line
## half typed); `play` (every prompt answered, shallow to the Pearl by
## turns, with one the list does not hold on the way: each reveal, the win);
## `deep` (the Pearl every time: the seal); `hint` (the bulb's line); `dry`
## (the clock run out on the first prompt); `out` (One Breath: the air run
## out, the card, Try again); `doc` (a daily whose prompts are a published
## day's: a document is put in the backend's cache as the server would write
## it, and taken out again); `restore` (a day reopened already played, one
## dry); `bank` (headless-safe: prints three days of every band's prompts, no
## shots).
## Frames go to <dir>/pd_<mode>_d<level>_<n>.png; every mode prints the peak
## draw calls and the mean frame from 0.5 s on.

const SHOT_DIR := "/tmp"

var _t := 0.0
var _level := 0
var _mode := "rest"
var _reduce := false
var _fixed := false
var _dir := SHOT_DIR
var _menu: Node
var _host: Node
var _puzzle: Node
var _opened := false
var _plan: Array = []
var _n := 0
var _end := 4.0
var _ms_from := 0.5
var _ms_sum := 0.0
var _ms_n := 0
var _draws_max := 0

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_level = int(a.substr(2))
		elif a == "rm":
			_reduce = true
		elif a == "fixed":
			_fixed = true
		elif a.begins_with("out="):
			_dir = a.substr(4)
		elif a.begins_with("lang="):
			load("res://core/locale.gd").set_current(a.substr(5))
		else:
			_mode = a
	if _mode == "bank":
		return
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_pd_progress.cfg"))
	progress.path = "user://_shot_pd_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	if _mode == "bank":
		_bank()
		quit()
		return true
	_t += delta
	if not _opened:
		_opened = true
		_t = 0.0
		# A probe plays the bank: the day's own prompts stay on the server.
		load("res://core/backend.gd").stop()
		if _mode == "doc":
			_plant_doc()
		var entry: Dictionary = {}
		for e in load("res://ui/registry.gd").PUZZLES:
			if e.id == "pearl":
				entry = e
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		# The real pointer over the window must not play the board.
		_puzzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
		if _fixed:
			_at(0.05, _deal_fixed)
		_script()
		return false
	while not _plan.is_empty() and float(_plan[0][0]) <= _t:
		var step: Array = _plan.pop_front()
		(step[1] as Callable).call()
	if _t >= _ms_from and _t < _end:
		_ms_sum += delta * 1000.0
		_ms_n += 1
		_draws_max = maxi(_draws_max, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= _end:
		if _ms_n > 0:
			print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		var st = _puzzle.state
		print("board: band ", st.band, " source ", st.source, " prompt ", st.index + 1, "/", st.count(), " finished ", st.results.size(),
			" depth ", st.depth(), "/", st.floor_depth(), " pearls ", st.pearls(), " dry ", st.dry_count(),
			", clock ", snappedf(st.time_left, 0.1), ", out ", _puzzle.out_of_hearts, ", done ", _puzzle.is_done(),
			", solved ", _puzzle.is_solved(), ", hints ", _puzzle.hints_left(), ", checks ", _puzzle.checks)
		print("share:\n", _puzzle.share_glyphs())
		_cleanup()
		quit()
		return true
	return false

func _cleanup() -> void:
	for n in root.get_children():
		var card := n.find_child("OutOfHearts", true, false)
		if card != null:
			card.queue_free()
	load("res://core/motion.gd").reduce = false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/pd_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	var st = _puzzle.state
	print("saved ", path, "  prompt ", st.index + 1, " ", st.prompt().get("id", "?"), " \"", st.ask(), "\" depth ", st.depth())

## One of the tray's keys pressed: a letter, or "enter" / "erase".
func _key(what: String) -> void:
	var tray: Node = _host.tray
	var chip: Node = null
	if what == "enter":
		chip = tray.find_child("Key_Enter", true, false)
	elif what == "erase":
		chip = tray.find_child("Key_Erase", true, false)
	else:
		chip = tray.find_child("Key_%s" % what.to_upper(), true, false)
	if chip != null:
		(chip as BaseButton).pressed.emit()

func _type(text: String) -> void:
	for ch in text:
		_key(ch)

## The letters of an answer of tier `t` to the prompt on the card (the
## nearest tier it has), as the keys can type them.
func _answer_of(t: int) -> String:
	var S = load("res://puzzles/pearl_state.gd")
	var st = _puzzle.state
	var answers: Array = st.prompt().answers
	var best := -1
	for a in answers.size():
		if best < 0 or absi(int(answers[a].t) - t) < absi(int(answers[best].t) - t):
			best = a
	return S.norm(st.answer_name(st.index, best))

## From `t`: every prompt answered (`tier_for` says how deep; -1 offers a
## line the list does not hold first), a shot of each reveal. Returns when
## the last has been read.
func _answer_all(t: float, tier_for: Callable, shots := true) -> float:
	# (The deal follows the open by a frame: the count is the band's.)
	var n: int = load("res://puzzles/pearl_state.gd").ASKS[_level]
	_at(t, func() -> void: _key("enter"))
	t += 0.6
	for k in n:
		var tier: int = tier_for.call(k)
		if tier < 0:
			_at(t, func() -> void:
				_type("zzzqx")
				_key("enter"))
			if shots:
				_at(t + 0.25, _shot)
			t += 0.5
			tier = 1
		_at(t, func() -> void:
			if _puzzle.out_of_hearts or _puzzle.is_done():
				return
			_type(_answer_of(tier)))
		if shots and k == 0:
			_at(t + 0.15, _shot)
		_at(t + 0.3, func() -> void: _key("enter"))
		if shots:
			_at(t + 1.6, _shot)
		_at(t + 1.7, func() -> void: _key("enter"))
		t += 2.3
	return t

func _script() -> void:
	match _mode:
		"rest":
			_at(0.25, _shot)
			_at(1.4, _shot)
			_at(1.5, func() -> void: _key("enter"))
			_at(2.4, func() -> void: _type(_answer_of(1).substr(0, 3)))
			_at(2.6, _shot)
			_at(2.7, func() -> void: _key("erase"))
			_at(2.9, _shot)
			_end = 3.2
		"play":
			var t := _answer_all(1.6, func(k: int) -> int: return [0, 2, -1, 4, 3, 1, 2, 0][k % 8])
			_at(t + 1.2, _shot)
			_end = t + 1.6
		"deep":
			var t := _answer_all(1.6, func(_k: int) -> int: return 4, false)
			_at(t + 0.6, _shot)
			_at(t + 2.2, _shot)
			_end = t + 2.6
		"hint":
			_at(1.5, func() -> void: _key("enter"))
			_at(2.0, func() -> void: _host._on_hint())
			_at(2.6, _shot)
			_end = 3.0
		"dry":
			_at(1.5, func() -> void: _key("enter"))
			_at(2.0, func() -> void:
				_type("abc")
				_puzzle.state.time_left = 5.6)
			_at(5.0, _shot)
			_at(8.6, _shot)
			_end = 9.0
		"out":
			_at(1.5, func() -> void: _key("enter"))
			_at(2.0, func() -> void:
				_type(_answer_of(3))
				_key("enter"))
			_at(3.4, _shot)
			_at(3.5, func() -> void: _key("enter"))
			_at(4.2, func() -> void: _puzzle.state.time_left = 1.2)
			_at(6.0, _shot)
			_at(8.0, _shot)
			_at(8.2, func() -> void: _puzzle.try_again())
			_at(9.6, _shot)
			_end = 10.0
		"doc":
			_at(1.5, func() -> void: _key("enter"))
			_at(2.2, _shot)
			_at(2.3, _unplant_doc)
			_end = 2.6
		"restore":
			_at(0.6, func() -> void:
				var st = _puzzle.state
				var given := []
				var tiers := []
				for i in st.count():
					var a: int = -1 if i == 1 else (int(st.pearl_at(i)) if i == 0 else i)
					given.append(a)
					tiers.append(-1 if a < 0 else int(st.prompts[i].answers[a].t))
				_puzzle.completed_record = {"given": given, "tiers": tiers, "set": st.set_id()}
				_puzzle.restore_completed())
			_at(1.2, _shot)
			_end = 1.6
		_:
			_end = 2.0

## `fixed`: the tutorial's one prompt on every slot of the band, so the look
## can be checked whatever the bank holds.
func _deal_fixed() -> void:
	var S = load("res://puzzles/pearl_state.gd")
	var asked: Dictionary = load("res://ui/hud/pearl_tutorial_diagram.gd").ASKED[0]
	var list := []
	for k in int(S.ASKS[_level]):
		var p := asked.duplicate()
		p["id"] = "t%03d" % k
		list.append(p)
	_puzzle._gen += 1
	_puzzle.state.setup_fixed(_level, list)
	_puzzle._begin()

## Today's document as the server publishes it, built from another day's
## bank so it is plainly not what the bank would deal today.
func _doc_path() -> String:
	return "user://backend_cache/pearl-%d-content.json" % load("res://core/daily.gd").date_key()

func _plant_doc() -> void:
	var S = load("res://puzzles/pearl_state.gd")
	var bands := []
	for band in 4:
		bands.append(S.bank_band(19990101, band))
	DirAccess.make_dir_recursive_absolute("user://backend_cache")
	var f := FileAccess.open(_doc_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 1, "source": "model", "bands": bands}))
	f.close()

func _unplant_doc() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_doc_path()))

## Three days of every band from the bank, as the server and a phone both
## deal it (tools/pearl_day.sh prints the server's).
func _bank() -> void:
	var S = load("res://puzzles/pearl_state.gd")
	print("bank: ", S.levels().map(func(l: Array) -> int: return l.size()), " prompts a level")
	for day in range(20261009, 20261012):
		for band in 4:
			var line := "%d band %d:" % [day, band]
			for p: Dictionary in S.bank_band(day, band):
				line += " " + str(p.id)
			print(line)
