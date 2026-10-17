extends SceneTree

## The Arcade tab and Firefly in stages, shot at fixed beats:
##
##     godot --resolution 810x1440 --always-on-top --path . --script res://tests/_shot_firefly.gd -- <outdir> [pt|es] [reduce]
##
## 1 the Arcade tab, 2 the stage map (its clears drawn), 3 stage 6's
## banner (its name, its goal and what the goal gives), 4 the swarm flying
## in with the goal's plate, 5 the swarm in its rows and a moth's beam (the
## firefly slipped aside, no seed landing), 6 the goal met (forced through
## the sim: the plate gold, the buff lettered, the silk shield on), 6a a
## piercing spark and slow seeds live (forced), 6b the shield bursting,
## 6c Double fire's twin flying in (forced), 7 the end card of a stage
## cleared, 8 the end card of one failed. Prints the draw calls at each shot.
## The ends write to user://arcade.cfg, so the file this machine had is put
## back, on a timeout too.

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _reduce := false
var _lang := ""
var _seeded := false
const PATH := "user://arcade.cfg"

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and eat the taps.
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for a: String in args.slice(1):
		if a == "reduce":
			_reduce = true
		else:
			_lang = a
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/ff_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

## Keeps the firefly alive and shooting, under the lowest bug.
func _bot() -> void:
	var sim = _s.sim
	_s._mouse = true
	var aim: float = sim.px
	var best := -1.0
	for e: Dictionary in sim.enemies:
		if e.st != 0 and e.pos.y > best and e.pos.y < sim.PLAYER_Y - 30.0:
			best = e.pos.y
			aim = e.pos.x
	sim.target_x = aim

## A fresh wallet holds boosters, so the boost card stands before every run
## and Second chance before every end card: play with none, and decline.
func _skip_gold() -> void:
	if _s == null:
		return
	var boost: Node = _s.get_node_or_null("BoostCard")
	if boost != null and not boost.is_queued_for_deletion():
		boost._on_play()
	var chance: Node = _s.get_node_or_null("SecondChance")
	if chance != null and not chance.is_queued_for_deletion():
		chance._on_no()

func _done() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	quit()

func _process(delta: float) -> bool:
	_t += delta
	_skip_gold()
	# the window losing focus pauses the run (a person's click elsewhere):
	# the beats go on
	if _s != null and _s._paused:
		_s._pause(false)
	# up to the goal's moment no seed lands: the firefly is there to be seen
	if _step >= 3 and _step <= 8 and _s.sim != null:
		_s.sim.bullets.clear()
	if _t > 150.0:
		print("TIMEOUT at step ", _step)
		_done()
		return false
	var Sim = load("res://arcade/firefly_sim.gd")
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				# set here, not at the start: the menu's settings load puts
				# both back
				if _reduce:
					load("res://core/motion.gd").reduce = true
				if _lang != "":
					TranslationServer.set_locale(_lang)
				_menu._open_arcade("firefly")
				_s = _menu.get_node("Firefly")
				_step = 2
				_at = _t
		2:
			if _t > _at + 1.0:
				_shot("2_map")
				# stage 6 on Medium: moths, escorts, hot entrances, Break a
				# wave for a Silk shield (any stage plays, the map aside)
				_s._on_difficulty(1)
				_s._stage = 6
				_s._ask()
				_step = 3
				_at = _t
		3:
			if _t > _at + 0.9:
				_shot("3_banner")
				_step = 4
		4:
			if _t > _at + 5.0:
				_shot("4_entering")
				_s.sim.ships = 6
				_step = 5
		5:
			# no shooting: let the swarm settle into its rows, then a beam
			if _t > _at + 20.0:
				var moth := {}
				for e: Dictionary in _s.sim.enemies:
					if e.kind == Sim.Kind.MOTH and e.st == Sim.St.FORM:
						moth = e
				if not moth.is_empty():
					_s.sim._dive_beam(moth)
					# and the firefly slips off to the far side, out of its reach
					_s.sim.target_x = 30.0 if _s.sim.px > Sim.W * 0.5 else Sim.W - 30.0
				_step = 6
		6:
			var open := false
			for e: Dictionary in _s.sim.enemies:
				if e.st == Sim.St.BEAM and e.beam >= 1.0:
					open = true
			if open or _t > _at + 30.0:
				_shot("5_rows_beam" if open else "5_rows")
				# the beam's moth gone, so nothing hauls a firefly up later
				for e: Dictionary in _s.sim.enemies:
					if e.st == Sim.St.BEAM:
						e.st = Sim.St.DEAD
				_step = 7
				_at = _t
		7:
			# the goal met, forced: its Silk shield goes up
			if _t > _at + 1.5:
				_s.sim._goal_step(_s.sim.goal_need)
				_step = 8
				_at = _t
		8:
			if _t > _at + 0.7:
				_shot("6_goal_met")
				print("goal %d / %d done %s buff %d shield %s" % [_s.sim.goal_have, _s.sim.goal_need, _s.sim.goal_done, _s.sim.buff, _s.sim.shield])
				_step = 9
				_at = _t
		9:
			# piercing sparks fired and slow seeds falling, the shield still up
			_bot()
			_s.sim.buff = Sim.Buff.PIERCE
			if _t > _at + 0.8 and not _seeded:
				_seeded = true
				_s.sim.buff = Sim.Buff.SLOW
				var n := 0
				for e: Dictionary in _s.sim.enemies:
					if e.st == Sim.St.FORM and n < 5:
						_s.sim._seed(e)
						n += 1
				_s.sim.buff = Sim.Buff.PIERCE
			if _t > _at + 1.6:
				_shot("6a_pierce_slow")
				_step = 10
				_at = _t
		10:
			_bot()
			if _s.sim.shield:
				_s.sim._ship_hit(0)
			if _t > _at + 0.15:
				_shot("6b_shield_burst")
				_step = 11
				_at = _t
		11:
			# Double fire, forced: the twin sets off from the side
			_bot()
			if _t > _at + 1.0 and _step == 11:
				_s.sim.pair = false
				_s.sim.freed = {}
				_s.sim._give(Sim.Buff.DOUBLE)
				_step = 12
				_at = _t
		12:
			_bot()
			if _t > _at + 0.6:
				_shot("6c_twin")
				_step = 13
				_at = _t
		13:
			# the stage cleared: every bug gone at once
			_bot()
			if _t > _at + 2.0 and _s.sim.freed.is_empty():
				_s._mouse = false
				_s.sim.enemies.clear()
				_step = 14
				_at = _t
		14:
			if _t > _at + 4.2:
				_shot("7_end_cleared")
				print("cleared: score %d won %s goal %s" % [_s.sim.score, _s.sim.is_won(), _s.sim.goal_done])
				(_s._end.find_child("Again", true, false) as Button).pressed.emit()
				_step = 15
				_at = _t
		15:
			# the night wins: the last firefly popped
			if _t > _at + 3.0:
				_s.sim.ships = 1
				_s.sim.pair = false
				_s.sim.ship = Sim.Ship.ALIVE
				_s.sim._ship_hit(0)
				_step = 16
				_at = _t
		16:
			if _t > _at + 3.8:
				_shot("8_end_failed")
				print("failed: score %d over %s" % [_s.sim.score, _s.sim.is_over()])
				_done()
	return false
