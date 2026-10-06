extends SceneTree

## Peapod in real play, timed by its parts: the screen's _process (the sim's
## steps, its events, the motion), its two draws, and the frame as a whole.
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_prof_peapod.gd -- [wave] [seconds]
##
## The gun is set to what a balanced run holds on that wave, the bot aims at
## the lowest crate and shops for nothing. Puts user://arcade.cfg back.

const Sim = preload("res://arcade/peapod_sim.gd")
const PATH := "user://arcade.cfg"

var _menu: Node
var _s: Node
var _t := 0.0
var _step := 0
var _before := ""
var _had := false
var _wave := 10
var _secs := 14.0
var _hand := 150.0
var _acc := {}
var _worst := {}
var _frames := 0
var _slow := 0
var _worst_frame := 0.0
var _draws := 0
var _most := {"orbs": 0, "nums": 0, "bits": 0, "shots": 0}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_wave = int(args[0])
	if args.size() > 1:
		_secs = float(args[1])
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	# and the carts' card would stand before every run
	load("res://arcade/peapod_screen.gd").force_cart = 0
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

func _timed(name: String, call: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	call.call()
	var d := Time.get_ticks_usec() - t0
	_acc[name] = int(_acc.get(name, 0)) + d
	_worst[name] = maxi(int(_worst.get(name, 0)), d)

func _bot(delta: float) -> void:
	var sim = _s.sim
	if sim.phase == Sim.Phase.SHOP and _s._shop != null:
		_s._close_shop()
	var want: float = sim.x
	if sim.wave_kind == Sim.Wave.WALL:
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

func _process(delta: float) -> bool:
	_t += delta
	if _t > 120.0:
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
			if _t > 3.6 and _s.sim != null and _s.sim.phase == Sim.Phase.PLAY:
				var sim = _s.sim
				# the gun a balanced run holds on this wave, and the wave itself
				sim.power = 1 + int(_wave * 0.55)
				sim.rate_lv = mini(8, int(_wave * 0.5))
				sim.crit_lv = mini(5, int(_wave * 0.45))
				sim.rows.clear()
				sim.segs.clear()
				sim.wave = _wave - 1
				sim._shopped = true
				sim.gap_t = 0.01
				# the screen is driven from here, each part of it timed
				_s.set_process(false)
				_s._over.draw.disconnect(_s._draw_over)
				_s._over.draw.connect(func() -> void: _timed("draw_over", _s._draw_over))
				_s._orb_layer.draw.disconnect(_s._draw_orbs)
				_s._orb_layer.draw.connect(func() -> void: _timed("draw_orbs", _s._draw_orbs))
				_acc.clear()
				_worst.clear()
				_frames = 0
				_at = _t
				_step = 2
		2:
			_bot(delta)
			var k0: int = _s.sim.kills
			var g0: int = _s.sim.caught
			var p0 := int(_acc.get("process", 0))
			var d0 := int(_acc.get("draw_over", 0))
			_timed("process", func() -> void: _s._process(delta))
			_timed("rewards", func() -> void: pass)
			# a frame that ran long, and what was in it (the draw's time is the
			# frame before's: it is drawn after this is over)
			if delta > 0.019 or int(_acc.process) - p0 > 2500:
				print("  long: frame %.1f ms, process %.2f, draw before %.2f, kills %d, gifts %d, orbs %d, bits %d, nums %d, wave %d phase %d t %.1f" % [
					delta * 1000.0, (int(_acc.process) - p0) / 1000.0, (d0 - _d_prev) / 1000.0, _s.sim.kills - k0, _s.sim.caught - g0,
					_s._orbs.size(), _s._rw.bits.size(), _s._nums.size(), _s.sim.wave, _s.sim.phase, _t - _at])
			_d_prev = d0
			_frames += 1
			_worst_frame = maxf(_worst_frame, delta)
			if delta > 0.0205:
				_slow += 1
			_draws += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_most.orbs = maxi(_most.orbs, _s._orbs.size())
			_most.nums = maxi(_most.nums, _s._nums.size())
			_most.bits = maxi(_most.bits, _s._rw.bits.size())
			_most.shots = maxi(_most.shots, _s.sim.shots.size())
			if _t > _at + _secs or _s.sim.is_over():
				var span := _t - _at
				print("wave %d..%d, %.1f s, %d frames: %.2f ms a frame, worst %.1f ms, %d frames over 20 ms, draws %d" % [_wave, _s.sim.wave, span,
					_frames, span * 1000.0 / _frames, _worst_frame * 1000.0, _slow, _draws / _frames])
				for k: String in _acc:
					print("  %-10s %6.2f ms a frame, worst %6.2f" % [k, int(_acc[k]) / 1000.0 / _frames, int(_worst[k]) / 1000.0])
				print("  most at once: ", _most)
				_restore()
				return true
	return false

var _at := 0.0
var _d_prev := 0
