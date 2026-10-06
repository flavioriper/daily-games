extends SceneTree

## The Arcade tab and a game of Firefly, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_firefly.gd -- <outdir> [pt|es] [reduce]
##
## 1 the Arcade tab, 2 the stage banner, 3 the swarm flying in, 4 the swarm
## in its rows, 5 a moth's beam, 6 a pair of fireflies, 6a hits landing
## (numbers, bars, motes on their way to the plate), 6b the shop as it
## opens, 6c the shop with all it could buy bought (bought through the
## card's own buttons, left by its Go), 7 the flyby, 7b a gun grown far past
## what a run buys, 8 the end card. Prints the draw calls at each shot. The
## end writes a score to user://arcade.cfg, so the file this machine had is
## put back, on a timeout too.

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
## The shop: when it was first seen up, and which of its shots are taken.
var _shop_at := -1.0
var _shop_shot := 0
var _hits_shot := false
var _primed := false
var _big_at := -1.0
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

## The shop's card, when it is up: shot as it opened, everything it can buy
## bought through its own buttons one a beat, shot again, and left by Go.
func _shop() -> bool:
	if _s._shop == null:
		_shop_at = -1.0
		return false
	if _shop_at < 0.0:
		_shop_at = _t
		print("shop after stage %d: energy %d" % [_s.sim.stage, int(_s.sim.energy / 4.0)])
	if _t < _shop_at + 0.6:
		return true
	if _shop_shot == 0:
		_shop_shot = 1
		_shot("6b_shop")
		return true
	for r: Dictionary in _s._shop_rows:
		if not (r.button as Button).disabled:
			(r.button as Button).pressed.emit()
			return true
	if _shop_shot == 1:
		_shop_shot = 2
		_shot("6c_bought")
		print("gun: dmg %d rate %.1f crit %d shots %d energy+%d" % [_s.sim.power, _s.sim.rate(), _s.sim.crit_lv, _s.sim.volley, _s.sim.energy_lv])
		return true
	(_s._shop.get_node("Center/Card").find_child("Go", true, false) as Button).pressed.emit()
	return true

func _process(delta: float) -> bool:
	_t += delta
	_skip_gold()
	if _t > 240.0:
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
		2:
			if _t > 2.6:
				_shot("2_banner")
				_step = 3
		3:
			if _t > 6.5:
				_shot("3_entering")
				_step = 4
		4:
			# no shooting: let the swarm settle into its rows
			if _t > 22.0:
				_shot("4_rows")
				_s.sim.ships = 5
				var moth := {}
				for e: Dictionary in _s.sim.enemies:
					if e.kind == Sim.Kind.MOTH and e.st == Sim.St.FORM:
						moth = e
				if not moth.is_empty():
					_s.sim._dive_beam(moth)
				_step = 5
		5:
			for e: Dictionary in _s.sim.enemies:
				if e.st == Sim.St.BEAM and e.beam >= 1.0 and _step == 5:
					_shot("5_beam")
					_step = 6
					_at = _t
			if _t > 40.0:
				_shot("5_no_beam")
				_step = 6
				_at = _t
		6:
			if _t > _at + 3.0:
				# a pair, forced
				_s.sim.pair = true
				_s.sim.ship = Sim.Ship.ALIVE
				_bot()
				if _t > _at + 5.0:
					_shot("6_pair")
					_step = 7
		7:
			if _shop():
				return false
			_bot()
			if not _hits_shot:
				# hits landing: numbers afloat, a wounded bug's bar, motes flying.
				# Stage 1's ladybirds go in one shot, so they are given three.
				if not _primed:
					_primed = true
					for e: Dictionary in _s.sim.enemies:
						if e.kind == Sim.Kind.BEETLE and int(e.max) < 3:
							e.hp = 3
							e.max = 3
				var wounded := 0
				for e: Dictionary in _s.sim.enemies:
					if int(e.hp) < int(e.max):
						wounded += 1
				if (wounded >= 2 and _s._nums.size() >= 1 and (_reduce or _s._motes._orbs.size() >= 4)) or _t > _at + 14.0:
					_hits_shot = true
					print("hits: wounded %d numbers %d motes %d" % [wounded, _s._nums.size(), _s._motes._orbs.size()])
					_shot("6a_hits")
				return false
			if _s.sim.challenge() and _s.sim.phase == Sim.Phase.PLAY and _s.sim.phase_t > 5.0:
				_shot("7_flyby")
				_step = 10
				_at = _t
			elif _s.sim.stage < 3 and _t > _at + 90.0:
				_shot("7_timeout")
				print("stage ", _s.sim.stage, " enemies ", _s.sim.enemies.size())
				_step = 8
			elif _s.sim.stage < 3:
				# hurry: clear the stage
				for e: Dictionary in _s.sim.enemies:
					if e.st == Sim.St.FORM:
						e.hp = mini(int(e.hp), _s.sim.power)
		10:
			# a gun far past what a run buys, for the draw calls and the frame
			if _big_at < 0.0:
				_big_at = _t
				_s.sim.volley = 6
				_s.sim.rate_lv = 14
				_s.sim.crit_lv = 4
				_s.sim.power = 9
				_s.sim.pair = true
				for e: Dictionary in _s.sim.enemies:
					e.hp = 400
					e.max = 400
			_bot()
			if _t > _big_at + 2.5:
				print("big gun: shots %d numbers %d fps %d" % [_s.sim.shots.size(), _s._nums.size(), int(Performance.get_monitor(Performance.TIME_FPS))])
				_shot("7b_big_gun")
				for e: Dictionary in _s.sim.enemies:
					e.hp = 1
				_step = 8
		8:
			_s._mouse = false
			_s.sim.ships = 1
			_s.sim.ship = Sim.Ship.ALIVE
			# a pair would only lose its twin
			_s.sim.pair = false
			_s.sim._ship_hit(0)
			_step = 9
			_at = _t
		9:
			if _t > _at + 3.0:
				_shot("8_end")
				print("score ", _s.sim.score, " stage ", _s.sim.stage)
				_done()
	return false
