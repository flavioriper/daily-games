extends SceneTree

## Nightlight, shot at fixed beats through the real menu:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_nightlight.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab with its card, 2 a new star, 3 the Gas button held by a
## finger (as a phone sends it) for five seconds, 4 the disc a steady hand
## has poured into for two minutes, with what the gas has made, 4b a planet
## the tide has torn, 4c a sky as full as it gets (the draw calls' worst),
## 5a the two powers offered at two Suns (the card comes up by itself), 5b
## one picked and on its disc, 5c the star with nothing to burn, dim, 6 a
## heavy star burning carbon, a giant, 6b the powers it holds, 7 the shop
## with a tile just bought, 8a-8e the supernova (the core falling in, the
## layers leaving, the new star coming up), 11 the perks, 12 one drawn, 13
## the new star among the gas, 13b-13c a star letting go, 14-16 the
## tutorial's four pages, 17 the tab again with the star on its card.
## Prints the draw calls at each shot and the frames since the last with
## their mean and longest gap. The star and the wallet are throwaway files.

const Sim = preload("res://arcade/nightlight_sim.gd")

const STEPS := [
	[1.6, "tab"], [2.8, "shot", "1_tab"],
	[2.9, "open"], [3.9, "shot", "2_start"],
	[4.0, "press"], [9.0, "shot", "3_pour"], [9.1, "let_go"],
	[9.2, "run", 120.0], [11.0, "shot", "4_disc"],
	[11.1, "planet"], [14.0, "shot", "4b_torn"],
	[14.1, "crowd"], [15.0, "shot", "4c_full"],
	[15.1, "grow", 2.2], [16.6, "shot", "5a_pick"], [16.7, "pick", 0], [17.3, "shot", "5b_picked"],
	[17.4, "starve"], [20.0, "shot", "5c_dim"], [20.1, "feed"],
	[20.2, "heavy"], [20.3, "run", 40.0], [23.5, "shot", "6_giant"],
	[23.6, "powers"], [24.2, "shot", "6b_powers"], [24.3, "powers_x"],
	[24.4, "shop"], [24.5, "buy"], [25.0, "shot", "7_shop"], [25.1, "shop_x"],
	[25.2, "iron"], [26.1, "shot", "8a_fall"], [26.9, "shot", "8b_leaving"], [27.8, "shot", "8c_shells"],
	[29.2, "shot", "8d_swap"], [31.2, "shot", "8e_rising"],
	[33.4, "shot", "11_perks"], [33.5, "perk"], [33.9, "shot", "12_perk"],
	[34.0, "perks_x"], [36.0, "shot", "13_new"],
	[36.1, "let_go_star"], [39.5, "shot", "13b_letting_go"], [42.5, "shot", "13c_gone"], [46.5, "perks_x"],
	[46.6, "tutor"], [48.6, "shot", "14_tut_gas"],
	[48.7, "page", 1], [50.7, "shot", "15_tut_worlds"],
	[50.8, "page", 2], [56.8, "shot", "15b_tut_burn"], [61.0, "shot", "15c_tut_burn_giant"],
	[61.1, "page", 3], [64.2, "shot", "16_tut_end"],
	[64.3, "leave"], [65.5, "shot", "17_tab_after"],
	[65.6, "quit"],
]

var _menu: Node
var _s: Node
var _t := 0.0
var _i := 0
var _out := "/tmp"
var _tmp: Array = []
var _reduce := false
var _frames := 0
var _gap_sum := 0.0
var _gap_max := 0.0

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_reduce = args.has("reduce")
	# the language for this run only: Locale.set_current would write it to
	# the player's own file
	for lang: String in ["en", "pt", "es"]:
		if args.has(lang):
			load("res://core/locale.gd")._current = lang
	var dir := OS.get_user_data_dir()
	var wallet: Node = root.get_node("Wallet")
	DirAccess.remove_absolute(dir + "/_shot_wallet.cfg")
	wallet.path = dir + "/_shot_wallet.cfg"
	wallet.reload()
	_tmp.append(wallet.path)
	Sim.path = dir + "/_shot_nightlight.cfg"
	DirAccess.remove_absolute(Sim.path)
	_tmp.append(Sim.path)
	var main: Node = load("res://world/main.tscn").instantiate()
	main.set_script(load("res://tests/_offline_main.gd"))
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _finish() -> void:
	for p: String in _tmp:
		DirAccess.remove_absolute(p)
	print("throwaway files removed")

## A finger on the Gas button, as a phone sends it (the project has
## mouse-from-touch off).
func _touch(down: bool, finger := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.pressed = down
	ev.position = _s._gas_b.size * 0.5
	_s._on_gas_input(ev)

## `seconds` of the sim at once, a steady hand on the button, buying the
## cheapest tile it can.
func _run(seconds: float) -> void:
	var since := 0.0
	for i in int(seconds / Sim.STEP):
		since += Sim.STEP
		if since >= _s.sim.stream_gap():
			since = 0.0
			_s.sim.pour()
		_s.sim.tick()
		_s.sim.events.clear()
		for tile: String in Sim.TILES:
			if _s.sim.can_buy(tile):
				_s.sim.buy(tile)
		while _s.sim.owed() > 0:
			_s.sim.pick(0)
	_s._refresh_tiles()
	var solids := 0
	for b: Sim.Body in _s.sim.bodies:
		if b.kind != Sim.Kind.GAS:
			solids += 1
	print("ran %.0f s: %.2f Suns, light %.1f, %d gas and %d solids, lv %s" % [seconds, _s.sim.suns(), _s.sim.light, _s.sim.bodies.size() - solids, solids, str(_s.sim.lv)])

func _process(delta: float) -> bool:
	_t += delta
	_frames += 1
	_gap_sum += delta
	_gap_max = maxf(_gap_max, delta)
	if _t > 120.0:
		_finish()
		return true
	while _i < STEPS.size() and _t >= float(STEPS[_i][0]):
		var step: Array = STEPS[_i]
		_i += 1
		match String(step[1]):
			"shot":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("%s/nightlight_%s.png" % [_out, step[2]])
				print("shot %s draws=%d bodies=%d | since the last shot: %d frames, %.2f ms a frame (longest %.1f)" % [step[2],
					int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
					_s.sim.bodies.size() if is_instance_valid(_s) and _s.sim != null else -1,
					_frames, _gap_sum / maxi(1, _frames) * 1000.0, _gap_max * 1000.0])
				_frames = 0
				_gap_sum = 0.0
				_gap_max = 0.0
			"tab":
				if _reduce:
					load("res://core/motion.gd").reduce = true
				if _menu.gifts_sheet.is_open():
					_menu.gifts_sheet.close()
				_menu._show_tab("arcade")
			"open":
				_menu._open_arcade("nightlight")
				_s = _menu.get_node("Nightlight")
				# the real pointer over the window cannot press the button
				_s._gas_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			"press":
				print("star open: %.2f Suns, field %s, u %.3f, the star at %s, %d px" % [_s.sim.suns(), _s.sky.size, _s.sky.u, _s.sky.centre, _s.sky.star_px()])
				_touch(true)
				print("pressed: %d puffs, holding %s, one every %.2f s" % [_s.sim.gas_count(), _s._holding, _s.sim.stream_gap()])
			"let_go":
				var up: int = _s.sim.gas_count()
				_touch(false)
				print("let go: %d puffs after five seconds, holding %s" % [up, _s._holding])
			"planet":
				# on a circle a little outside where the tide tears it, and the disc brings it in
				var far: float = _s.sim.tear_r(0.03) * 1.004
				var b: Sim.Body = _s.sim.add(Sim.Kind.PLANET, 0.03, Vector2(0.0, -far), Vector2(sqrt(_s.sim.gm() / far), 0.0))
				b.ice = 0.6
				_s.sim._sort(b)
			"crowd":
				# as full a sky as the sim lets there be
				while _s.sim.gas_count() < Sim.MOST:
					_s.sim.pour()
				for k in 140:
					var far: float = _s.sim.haze_r() * (0.55 + 0.004 * k)
					var way := Vector2.from_angle(TAU * k * 0.381)
					var b: Sim.Body = _s.sim.add(Sim.Kind.ROCK, 0.001 + 0.0002 * (k % 9), way * far, way.orthogonal() * -sqrt(_s.sim.gm() / far))
					b.ice = 0.8 if k % 3 == 0 else 0.0
					_s.sim._sort(b)
				print("crowd: %d bodies up" % _s.sim.bodies.size())
			"run":
				_run(float(step[2]))
			"grow":
				# past the first pick: the card comes up by itself
				_s.sim.bodies.clear()
				_s.sim.mass = Sim.START * float(step[2])
				_s.sim.fuel = _s.sim.mass * 0.6
				_s.sim.env = _s.sim.mass * 0.25
			"pick":
				print("pick open: %s, on offer %s, owed %d" % [_s._pick.visible, str(_s.sim.offer), _s.sim.owed()])
				_s._on_pick(int(step[2]))
				print("picked: %s, card open %s" % [str(_s.sim.power), _s._pick.visible])
			"starve":
				_s.sim.bodies.clear()
				_s.sim.passing = false
				_s.sim.fuel = 0.0
			"feed":
				print("dim: awake %s, lit %.2f, %d K, cold %.1f s, %s" % [_s.sim.awake, _s.sim.lit, int(_s.sim.temp()), _s.sim.cold, _s._nova_l.text])
				_s.sim.fuel = _s.sim.mass * 0.5
				_s.sim.passing = true
			"heavy":
				# twelve Suns, most of the way up the chain
				_s.sim.mass = Sim.START * 12.0
				_s.sim.fuel = _s.sim.mass * 0.55
				_s.sim.env = _s.sim.mass * 0.2
				_s.sim.made.assign([0.05 * _s.sim.mass, 0.1 * _s.sim.mass, 0.02 * _s.sim.mass, 0.01 * _s.sim.mass, 0.01 * _s.sim.mass, 0.02 * _s.sim.mass])
				_s.sim.ignited.assign([true, true, true, true, true, true])
				_s.sim.light = 5000.0
				while _s.sim.owed() > 0:
					_s.sim.pick(_s.sim.owed() % 2)
			"powers":
				_s._chips.pressed.emit()
				print("powers held: %s, card open %s" % [str(_s.sim.power), _s._powers.visible])
			"powers_x":
				_s._powers.find_child("Back", true, false).pressed.emit()
			"shop":
				_s._shop_b.pressed.emit()
				print("shop open: %s, badge %d" % [_s._shop.visible, _s._shop_b.badge])
			"buy":
				var before: int = mini(int(_s.sim.lv.pure), 3)
				_s.sim.lv.pure = before
				_s._on_tile("pure")
				print("bought pure gas: %d -> %d, light %.0f" % [before, _s.sim.lv.pure, _s.sim.light])
			"shop_x":
				_s._shop.find_child("Close", true, false).pressed.emit()
			"iron":
				print("a giant: swell %.2f, %d K, %s" % [_s.sim.swell, int(_s.sim.temp()), _s._nova_l.text])
				_s.sim.made[5] = Sim.IRON * Sim.START
				print("an iron core: the sim says %s, would pay %d" % [_s.sim.ending(), _s.sim.dust_for()])
			"perk":
				print("after the end: %.1f Suns, dust %d, novas %d, fades %d, %d puffs left, perks open %s" % [_s.sim.suns(), _s.sim.dust, _s.sim.novas, _s.sim.fades, _s.sim.bodies.size(), _s._perks.visible])
				_s._perk_buy.pressed.emit()
				print("perk drawn: %s, dust %d" % [str(_s.sim.perk), _s.sim.dust])
			"perks_x":
				if _s._perks.visible:
					_s._perks.find_child("Back", true, false).pressed.emit()
			"let_go_star":
				_s.sim.fuel = 0.0
				_s.sim.h_on = false
				_s.sim.awake = false
				_s.sim.cold = Sim.GRACE
				print("left dim: the sim says %s" % _s.sim.ending())
			"tutor":
				_s.tutor.show()
			"page":
				_s.get_node("HowToPlay")._show_page(int(step[2]))
			"leave":
				_s.get_node("HowToPlay")._continue()
				_s.go_back()
			"quit":
				print("back on tab: %s, screen gone: %s" % [_menu._tab, _menu.get_node_or_null("Nightlight") == null or _menu.get_node("Nightlight").is_queued_for_deletion()])
				_finish()
				return true
	return false
