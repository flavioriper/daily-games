extends SceneTree

## Nightlight, shot at fixed beats through the real menu:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_nightlight.gd -- <outdir> [reduce] [en|pt|es] [fresh]
##
## 1 the Arcade tab with its card, 2 a new star, 3 the Gas button held by a
## finger (as a phone sends it) for five seconds, 4 the disc a steady hand
## has poured into for two minutes, with what the gas has made, 4b a planet
## the tide has torn, 4c a sky as full as it gets (the draw calls' worst),
## 5a the two powers offered at two Suns (the card comes up by itself), 5b
## one picked and on its disc, 5c the star with nothing to burn, dim, 6 a
## heavy star burning carbon, a giant, 6c three relics put by hand round
## it (a white dwarf, a neutron star, an old black hole, each with its
## nebula), 6b the powers it holds, 7 the shop
## with a tile just bought, 8a-8f the supernova (the core falling in, the
## layers leaving, the camera pulling back from the neutron star it leaves,
## panning to the new star, the new star condensing), 11 the perks, 12 one
## drawn, 13 the new star among the gas, 9a-9b a star of four Suns whose
## carbon core cannot light letting its layers go as a nebula (9c the camera
## between the white dwarf and the birthplace, 9b the new star after),
## 13b-13c a star letting go, 14-16 the tutorial's four pages (16b the END
## page's camera), 17 the tab again with the star and its relics on its card.
## Every run but `fresh` opens a kept star (a first cloud saved before the
## screen opens, so nothing is born on screen); `fresh` deletes the file, so
## the screen opens on a first star condensing out of its cloud (0 the birth,
## 0b after it) and stops there.
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
	[23.55, "relics"], [23.75, "shot", "6c_relics"],
	[23.85, "powers"], [24.2, "shot", "6b_powers"], [24.3, "powers_x"],
	[24.4, "shop"], [24.5, "buy"], [25.0, "shot", "7_shop"], [25.1, "shop_x"],
	# the supernova: swap at 28.8, the pull back to 30.0, the pan to 33.0,
	# the close to 37.0 and the perks (reduce motion: over at 32.8)
	[25.2, "iron"], [26.1, "shot", "8a_fall"], [26.9, "shot", "8b_leaving"], [27.8, "shot", "8c_shells"],
	[29.3, "shot", "8d_pull_back"], [29.31, "where"], [30.1, "where"], [31.0, "shot", "8e_pan"], [31.01, "where"], [34.0, "shot", "8f_rising"],
	[37.8, "shot", "11_perks"], [37.9, "perk"], [38.3, "shot", "12_perk"],
	[38.4, "perks_x"], [40.4, "shot", "13_new"],
	# the nebula: swap at 44.7, the pull back to 45.9, the pan to 48.9, the
	# close to 52.9 and the perks (reduce motion: over at 48.7)
	[40.5, "nebula"], [43.0, "shot", "9a_nebula_leaving"], [47.4, "shot", "9c_nebula_pan"],
	[53.1, "perks_x"], [53.4, "shot", "9b_after_nebula"],
	# the fade: swap at 58.5, over at 66.7 (reduce motion: 62.5)
	[53.5, "let_go_star"], [56.9, "shot", "13b_letting_go"], [59.9, "shot", "13c_gone"], [67.2, "perks_x"],
	[67.3, "tutor"], [69.3, "shot", "14_tut_gas"],
	[69.4, "page", 1], [71.4, "shot", "15_tut_worlds"],
	# BURN's star is a giant (swell 1, 20 Suns) from 12.0 to 13.8 s into the page
	[71.5, "page", 2], [77.5, "shot", "15b_tut_burn"], [84.6, "shot", "15c_tut_burn_giant"],
	[84.7, "page", 3], [87.8, "shot", "16_tut_end"], [92.3, "shot", "16b_tut_end_pan"],
	[92.4, "leave"], [93.6, "shot", "17_tab_after"],
	[93.7, "quit"],
]
## `fresh`: no file, so the screen opens on a first star being born.
const FRESH_STEPS := [
	[1.6, "tab"], [2.8, "fresh"],
	[2.9, "open"], [4.4, "shot", "0_birth"], [7.4, "shot", "0b_born"],
	[7.5, "quit"],
]

var _menu: Node
var _s: Node
var _t := 0.0
var _i := 0
var _out := "/tmp"
var _tmp: Array = []
var _reduce := false
var _fresh := false
var _steps: Array = STEPS
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
	_fresh = args.has("fresh")
	if _fresh:
		_steps = FRESH_STEPS
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
	while _i < _steps.size() and _t >= float(_steps[_i][0]):
		var step: Array = _steps[_i]
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
			"fresh":
				DirAccess.remove_absolute(Sim.path)
				print("fresh: the star's file is gone: %s" % (not FileAccess.file_exists(Sim.path)))
			"open":
				if not _fresh:
					# a kept star: its first cloud, saved, so the screen opens on it as it stands
					var first: RefCounted = Sim.new()
					first.born()
					first.save()
				_menu._open_arcade("nightlight")
				_s = _menu.get_node("Nightlight")
				# the real pointer over the window cannot press the button
				_s._gas_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
				print("opened: fresh %s, a birth playing %s, %d puffs, sky ending %s, ends in %.1f s" % [_s.sim.fresh, _s._birth, _s.sim.bodies.size(), _s.sky.ending(), _s.sky.end_time()])
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
			"relics":
				_s.sim.add_relic(Sim.Relic.WD, 6.0, Vector2(-900, -700), _s.sim.layers())
				_s.sim.add_relic(Sim.Relic.NS, 14.0, Vector2(1100, 300), _s.sim.layers())
				_s.sim.add_relic(Sim.Relic.BH, 50.0, Vector2(200, 1300), _s.sim.layers())
				_s.sim.relics[2].age = 300.0
				var spots := []
				for rel: Dictionary in _s.sim.relics:
					spots.append(_s.sky.world(rel.pos as Vector2))
				print("relics: %d, zoom %.3f, on screen at %s, field %s" % [_s.sim.relics.size(), _s.sim.zoom(), str(spots), _s.sky.size])
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
				print("camera after the end: shift %s, view %.3f, sky ending %s, relics %d (kind of the last %d)" % [_s.sky.shift, _s.sky.view, _s.sky.ending(), _s.sim.relics.size(), int(_s.sim.relics[-1].kind) if not _s.sim.relics.is_empty() else -1])
				print("after the end: %.1f Suns, dust %d, novas %d, fades %d, %d puffs left, perks open %s" % [_s.sim.suns(), _s.sim.dust, _s.sim.novas, _s.sim.fades, _s.sim.bodies.size(), _s._perks.visible])
				_s._perk_buy.pressed.emit()
				print("perk drawn: %s, dust %d" % [str(_s.sim.perk), _s.sim.dust])
			"perks_x":
				if _s._perks.visible:
					_s._perks.find_child("Back", true, false).pressed.emit()
			"where":
				# where the camera has the dead star and the new one, in the field's pixels
				var rel: Dictionary = _s.sim.relics[-1]
				var dead: Vector2 = _s.sky.world(rel.pos as Vector2)
				var star: Vector2 = _s.sky.world(Vector2.ZERO)
				var field := Rect2(Vector2.ZERO, _s.sky.size)
				print("camera at %.2f s: view %.3f, shift %s, the dead star at %s (in frame %s), the new star at %s (in frame %s), field %s" % [_s.sky.end_t(), _s.sky.view, _s.sky.shift, dead, field.has_point(dead), star, field.has_point(star), _s.sky.size])
			"nebula":
				# four Suns, helium lit, a carbon core of CARBON Suns it cannot light
				_s.sim.mass = Sim.START * 4.0
				_s.sim.ignited[1] = true
				_s.sim.made[1] = Sim.CARBON * Sim.START
				print("a nebula due: the sim says %s, remnant %d, %s" % [_s.sim.ending(), _s.sim.remnant(), _s.sim.goal()])
			"let_go_star":
				_s.sim.fuel = 0.0
				_s.sim.h_on = false
				_s.sim.awake = false
				_s.sim.cold = Sim.GRACE
				print("before the fade: shift %s, view %.3f, relics %d, kinds %s" % [_s.sky.shift, _s.sky.view, _s.sim.relics.size(), str(_s.sim.relics.map(func(r: Dictionary) -> int: return int(r.kind)))])
				print("left dim: the sim says %s" % _s.sim.ending())
			"tutor":
				_s.tutor.show()
			"page":
				_s.get_node("HowToPlay")._show_page(int(step[2]))
			"leave":
				_s.get_node("HowToPlay")._continue()
				_s.go_back()
			"quit":
				if _fresh:
					print("after the birth: sky ending %s, a birth %s, shift %s, view %.3f" % [_s.sky.ending(), _s._birth, _s.sky.shift, _s.sky.view])
				else:
					print("back on tab: %s, screen gone: %s, the card says %s" % [_menu._tab, _menu.get_node_or_null("Nightlight") == null or _menu.get_node("Nightlight").is_queued_for_deletion(), Sim.kept()])
				_finish()
				return true
	return false
