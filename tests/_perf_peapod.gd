extends SceneTree

## Peapod under its heaviest loads, measured: a full wall and a long
## millipede under a full gun, then the millipede's head shot off, and the
## wall again under the two pods that land the most numbers (lightning's
## jumps, the flame's burns).
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_perf_peapod.gd -- [outdir]
##
## Prints the draw calls (the figure that counts) and the frame time for
## each, after the same at rest. Puts user://arcade.cfg back on every way out.

const Sim = preload("res://arcade/peapod_sim.gd")
const PATH := "user://arcade.cfg"
const LOADS := ["rest", "wall", "milli", "head", "zap", "flame"]

var _menu: Node
var _s: Node
var _t := 0.0
var _step := 0
var _at := 0.0
var _load := 0
var _before := ""
var _had := false
var _draws := 0
var _worst_draws := 0
var _frames := 0

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and eat the taps.
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

func _skip_gold() -> void:
	if _s == null:
		return
	var boost: Node = _s.get_node_or_null("BoostCard")
	if boost != null and not boost.is_queued_for_deletion():
		boost._on_play()
	var chance: Node = _s.get_node_or_null("SecondChance")
	if chance != null and not chance.is_queued_for_deletion():
		chance._on_no()

func _full_gun() -> void:
	var sim = _s.sim
	sim.rate_lv = Sim.MAX_RATE
	sim.crit_lv = 5
	sim.peas = 1 + Sim.MAX_SHOTS
	sim.power = 9
	sim.shape_t = [1000.0, 0.0, 0.0]
	sim.element = 0
	sim.element_t = 0.0

func _lay(load_name: String) -> void:
	var sim = _s.sim
	sim.rows.clear()
	sim.segs.clear()
	sim.gap_t = 0.0
	_full_gun()
	match load_name:
		"rest":
			sim.gap_t = 1000.0
		"wall", "zap", "flame":
			if load_name != "wall":
				# on top of the Fan: three peas a volley, each of them lightning or flame
				sim.element = Sim.Kind.ZAP if load_name == "zap" else Sim.Kind.FLAME
				sim.element_t = 1000.0
			sim.wave = 19
			sim._deal()
			sim.wall_y = 330.0
			sim.wall_speed = 0.0
		"milli", "head":
			sim.wave = 20
			sim._deal()
			sim.milli_speed = 0.0
			sim.segs[0].s = 1100.0
			for i in range(1, sim.segs.size()):
				sim.segs[i].s = 1100.0 - i * Sim.SPACING
	for row in sim.rows:
		for c in row:
			if c != null:
				c.hp = 900000
	for sg in sim.segs:
		sg.hp = 900000
	if load_name == "head":
		sim.segs[0].hp = 1

func _process(delta: float) -> bool:
	_t += delta
	if _t > 90.0:
		print("timed out at step ", _step)
		_restore()
		return true
	_skip_gold()
	if _s != null and _s._paused and _s._end == null:
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
				_lay(LOADS[_load])
				_at = _t
				_draws = 0
				_worst_draws = 0
				_frames = 0
				_step = 2
		2:
			var sim = _s.sim
			sim.target_x = 150.0 + 110.0 * sin(_t * 1.3)
			if _t > _at + 0.5:
				var d := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				_draws += d
				_worst_draws = maxi(_worst_draws, d)
				_frames += 1
			if _t > _at + 4.5:
				print("%s: draws %d (worst %d), %.2f ms a frame over %d frames" % [LOADS[_load], _draws / _frames, _worst_draws,
					4000.0 / _frames, _frames])
				RenderingServer.force_draw()
				if OS.get_cmdline_user_args().size() > 0:
					root.get_texture().get_image().save_png("%s/pp_perf_%s.png" % [OS.get_cmdline_user_args()[0], LOADS[_load]])
				_load += 1
				if _load >= LOADS.size():
					_restore()
					return true
				_step = 1
	return false
