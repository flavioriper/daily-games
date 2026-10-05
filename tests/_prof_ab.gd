extends SceneTree

## Frame times of Peapod played by a bot from wave 1, whichever pass of the
## game is on disk (it reads nothing a pass added): for an A/B across commits.
##     godot --path . --always-on-top --script res://tests/_prof_ab.gd -- [seconds]

const PATH := "user://arcade.cfg"
var _menu: Node
var _s: Node
var _t := 0.0
var _step := 0
var _before := ""
var _had := false
var _hand := 150.0
var _frames := 0
var _slow := 0
var _very := 0
var _worst := 0.0
var _at := 0.0
var _secs := 40.0
var _proc := 0

func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_secs = float(OS.get_cmdline_user_args()[0])
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _restore() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func _process(delta: float) -> bool:
	_t += delta
	if _t > 150.0:
		_restore()
		return true
	if _s != null:
		var boost: Node = _s.get_node_or_null("BoostCard")
		if boost != null and not boost.is_queued_for_deletion():
			boost._on_play()
		var chance: Node = _s.get_node_or_null("SecondChance")
		if chance != null and not chance.is_queued_for_deletion():
			chance._on_no()
		if _s._paused and _s._end == null:
			_s._pause(false)
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_menu._open_arcade("peapod")
				_s = _menu.get_node("Peapod")
				_step = 1
		1:
			if _t > 3.6:
				_s.set_process(false)
				_at = _t
				_step = 2
		2:
			var sim = _s.sim
			var Sim: GDScript = _s.Sim
			if "_shop" in _s and _s._shop != null:
				for card in 4:
					while sim.can_buy(card):
						_s._buy(card)
				_s._close_shop()
			var want: float = sim.x
			if "tokens" in sim and not sim.tokens.is_empty():
				want = sim.tokens[0].x
			elif sim.wave_kind == Sim.Wave.WALL:
				for r in sim.rows.size():
					var found := false
					for c in Sim.COLS:
						if sim.rows[r][c] != null:
							want = (c + 0.5) * Sim.CELL_W
							found = true
							break
					if found:
						break
			elif not sim.segs.is_empty():
				want = Sim.path_at(float(sim.segs[0].s) + 8.0).x
			_hand = move_toward(_hand, want, 300.0 * delta)
			sim.target_x = _hand
			var t0 := Time.get_ticks_usec()
			_s._process(delta)
			_proc += Time.get_ticks_usec() - t0
			_frames += 1
			_worst = maxf(_worst, delta)
			if delta > 0.0185:
				_slow += 1
			if delta > 0.03:
				_very += 1
			if _t > _at + _secs or sim.is_over():
				var span := _t - _at
				print("AB: %.1f s to wave %d, kills %d: %.2f ms a frame, process %.2f ms, worst %.1f, over 18.5 ms %d (%.1f%%), over 30 ms %d" % [span, sim.wave,
					sim.kills, span * 1000.0 / _frames, _proc / 1000.0 / _frames, _worst * 1000.0, _slow, 100.0 * _slow / _frames, _very])
				_restore()
				return true
	return false
