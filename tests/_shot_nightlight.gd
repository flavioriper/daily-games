extends SceneTree

## Nightlight, shot at fixed beats through the real menu:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_nightlight.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab with its card, 2 a new star, 3 a meteor just set going
## (a finger down, as a phone sends it) and two more from a second finger and
## the first again, 4 the three winding in,
## 4b a planetoid the tide has just torn and 4c its pieces drawn out round the
## star, 4d as full a sky as the tide makes (sixty rocks torn at once, up to
## Sim.FULL bodies: the draw calls' worst), 5a the two powers offered at two
## Suns (the card comes up by itself), 5b one picked and on its disc, 5c the
## star out of hydrogen and dim, 5 a sky a steady hand has been throwing into
## for a minute and a half, 5d a finger held down and moved with Stream and Volley,
## 6 a heavy star with every pick made, 6b the powers it holds, 7 the shop
## with a tile just bought, 8 the question before the supernova, 9 the star
## swelling, 10 the light thinning, 11 the perks, 12 one drawn, 13 the new
## star among its ashes, 14-16 the tutorial's four pages (15b and 15c the
## star's, dim and lit again), 17 the tab again with the star on its card. Prints the draw calls
## at each shot and the frames since the last with their mean and longest
## gap. The star and the wallet are throwaway files; the field's own mouse
## filter is set to ignore, so the real pointer over the window cannot throw.

const Sim = preload("res://arcade/nightlight_sim.gd")

const STEPS := [
	[1.6, "tab"], [2.8, "shot", "1_tab"],
	[2.9, "open"], [3.9, "shot", "2_start"],
	[4.0, "press", Vector2(250, 760)], [4.1, "shot", "3_set"],
	[4.3, "second", Vector2(640, 420)], [4.5, "let_go"], [4.6, "press", Vector2(420, 780)], [4.7, "let_go"],
	[9.2, "shot", "4_winding"],
	[12.8, "planet"], [19.8, "shot", "4b_torn"], [24.8, "shot", "4c_stream"],
	[24.9, "crowd"], [25.6, "shot", "4d_full"],
	[29.5, "grow", 2.2], [30.9, "shot", "5a_pick"], [31.0, "pick", 0], [31.6, "shot", "5b_picked"],
	[31.7, "starve"], [33.9, "shot", "5c_dim"], [34.0, "feed"],
	[34.1, "run", 90.0], [35.1, "shot", "5_busy"],
	[35.2, "hold", Vector2(250, 760), Vector2(290, 880)], [36.9, "shot", "5d_stream"], [37.0, "let_go"],
	[38.4, "heavy"], [38.5, "run", 20.0], [39.6, "shot", "6_heavy"],
	[39.7, "powers"], [40.3, "shot", "6b_powers"], [40.4, "powers_x"],
	[40.5, "shop"], [40.6, "buy"], [41.1, "shot", "7_shop"],
	[41.2, "shop_x"], [41.3, "ask"], [41.8, "shot", "8_ask"],
	[41.9, "go"], [42.45, "shot", "9_swell"], [43.2, "shot", "10_thin"],
	[44.4, "shot", "11_perks"], [44.5, "perk"], [44.9, "shot", "12_perk"],
	[45.0, "perks_x"], [50.0, "shot", "13_ashes"],
	[50.1, "tutor"], [59.1, "shot", "14_tut_throw"],
	[59.2, "page", 1], [66.2, "shot", "15_tut_light"],
	[66.3, "page", 2], [68.2, "shot", "15b_tut_star_dim"], [74.3, "shot", "15c_tut_star_lit"],
	[74.4, "page", 3], [76.8, "shot", "16_tut_nova"],
	[76.9, "leave"], [78.1, "shot", "17_tab_after"],
	[78.2, "quit"],
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

## A finger, as a phone sends it (the project has mouse-from-touch off).
func _touch(at: Vector2, down: bool, finger := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.pressed = down
	ev.position = at
	_s._on_field_input(ev)

func _drag(at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = at
	_s._on_field_input(ev)

## `seconds` of the sim at once, a steady hand throwing and buying the
## cheapest tile it can.
func _run(seconds: float) -> void:
	var since := 0.0
	for i in int(seconds / Sim.STEP):
		since += Sim.STEP
		if since >= 0.45:
			since = 0.0
			_s.sim.bot_throw()
		_s.sim.tick()
		_s.sim.events.clear()
		for tile: String in Sim.TILES:
			if _s.sim.can_buy(tile):
				_s.sim.buy(tile)
		while _s.sim.owed() > 0:
			_s.sim.pick(0)
	_s._refresh_tiles()
	print("ran %.0f s: mass %.1f light %.1f bodies %d lv %s" % [seconds, _s.sim.mass, _s.sim.light, _s.sim.bodies.size(), str(_s.sim.lv)])

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
				_s.sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
			"press":
				print("star open: mass %.1f, field %s, u %.3f, the star at %s, %d px" % [_s.sim.mass, _s.sky.size, _s.sky.u, _s.sky.centre, _s.sky.star_px()])
				_touch(step[2], true)
				print("pressed: bodies %d, the last of them %.2f mass at %.0f px/s, %.0f px from the star (a circle there is %.0f px/s)" % [_s.sim.bodies.size(), _s.sim.bodies[-1].m,
					_s.sim.bodies[-1].vel.length(), _s.sim.bodies[-1].pos.length(), sqrt(_s.sim.gm() / _s.sim.bodies[-1].pos.length())])
			"second":
				# another finger while the first is down throws too
				_touch(step[2], true, 1)
				_touch(step[2], false, 1)
				print("a second finger: bodies %d" % _s.sim.bodies.size())
			"let_go":
				_touch(Vector2.ZERO, false)
				print("let go: bodies %d, holding %s" % [_s.sim.bodies.size(), _s._holding])
			"planet":
				# on a circle in the haze, a little outside where the tide tears it
				var far: float = _s.sim.tear_r(8.0) * 1.1
				_s.sim.add(Sim.Kind.PLANET, 8.0, Vector2(0.0, -far), Vector2(sqrt(_s.sim.gm() / far), 0.0))
			"crowd":
				for k in 60:
					var far: float = _s.sim.tear_r(1.5) * (1.02 + 0.003 * k)
					var way := Vector2.from_angle(TAU * k / 60.0)
					_s.sim.add(Sim.Kind.ROCK, 1.5, way * far, way.orthogonal() * -sqrt(_s.sim.gm() / far))
				# The star is held at its mass while the tide works, or it grows
				# over the ring before the pieces are many: this beat is the
				# draw calls' worst, a sky at Sim.FULL.
				var held: float = _s.sim.mass
				for i in int(20.0 / Sim.STEP):
					if _s.sim.bodies.size() >= Sim.FULL:
						break
					_s.sim.tick()
					_s.sim.events.clear()
					_s.sim.mass = held
				print("crowd: %d bodies up" % _s.sim.bodies.size())
			"run":
				_run(float(step[2]))
			"grow":
				# past the first pick: the card comes up by itself
				_s.sim.bodies.clear()
				_s.sim.mass = Sim.START * float(step[2])
				_s.sim.fuel = _s.sim.mass * 0.5
				_s.sim.spent = _s.sim.mass * 0.3
			"pick":
				print("pick open: %s, on offer %s, owed %d" % [_s._pick.visible, str(_s.sim.offer), _s.sim.owed()])
				_s._on_pick(int(step[2]))
				print("picked: %s, card open %s" % [str(_s.sim.power), _s._pick.visible])
			"starve":
				_s.sim.bodies.clear()
				_s.sim.passing = false
				_s.sim.fuel = 0.0
			"feed":
				print("dim: awake %s, lit %.2f, %d K" % [_s.sim.awake, _s.sim.lit, int(_s.sim.temp())])
				_s.sim.fuel = _s.sim.mass * 0.5
				_s.sim.passing = true
			"hold":
				# a finger down, moved and kept there: with Stream it goes on throwing from where it is
				_s.sim.lv.stream = maxi(4, int(_s.sim.lv.stream))
				_s.sim.lv.volley = maxi(2, int(_s.sim.lv.volley))
				var before: int = _s.sim.bodies.size()
				_touch(step[2], true)
				_drag(step[3])
				print("held with stream %d, volley %d: a throw every %.2f s, %d bodies up" % [_s.sim.lv.stream, _s.sim.lv.volley, _s.sim.stream_gap(), before])
			"heavy":
				_s.sim.mass = 6000.0
				_s.sim.fuel = 2400.0
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
				var before: int = mini(int(_s.sim.lv.ice), 3)
				_s.sim.lv.ice = before
				_s._on_tile("ice")
				print("bought ice: %d -> %d, light %.0f" % [before, _s.sim.lv.ice, _s.sim.light])
			"shop_x":
				_s._shop.find_child("Close", true, false).pressed.emit()
			"ask":
				_s._nova_b.pressed.emit()
				print("asked: %s, would pay %d" % [_s._ask.visible, _s.sim.dust_for()])
			"go":
				_s._ask.find_child("Go", true, false).pressed.emit()
			"perk":
				print("after the supernova: mass %.1f dust %d novas %d ashes %d, perks open %s" % [_s.sim.mass, _s.sim.dust, _s.sim.novas, _s.sim.bodies.size(), _s._perks.visible])
				_s._perk_buy.pressed.emit()
				print("perk drawn: %s, dust %d" % [str(_s.sim.perk), _s.sim.dust])
			"perks_x":
				_s._perks.find_child("Back", true, false).pressed.emit()
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
