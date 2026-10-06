extends SceneTree

## Nightlight, shot at fixed beats through the real menu:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_nightlight.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab with its card, 2 a new star, 3 a throw being aimed (the
## finger down and dragged, as a phone sends it), 4 the meteor winding in,
## 5 a sky a steady hand has been throwing into for a minute and a half,
## 6 a heavy star, 7 the shop with a tile just bought, 8 the question before
## the supernova, 9 the star swelling, 10 the light thinning, 11 the perks,
## 12 one drawn, 13 the new star among its ashes, 14-16 the tutorial's three
## pages, 17 the tab again with the star on its card. Prints the draw calls
## at each shot and the frames since the last with their mean and longest
## gap. The star and the wallet are throwaway files; the field's own mouse
## filter is set to ignore, so the real pointer over the window cannot aim.

const Sim = preload("res://arcade/nightlight_sim.gd")

const STEPS := [
	[1.6, "tab"], [2.8, "shot", "1_tab"],
	[2.9, "open"], [3.9, "shot", "2_start"],
	[4.0, "press", Vector2(250, 760)], [4.1, "drag", Vector2(290, 880)], [4.6, "shot", "3_aim"],
	[4.7, "let_go"], [8.2, "shot", "4_winding"],
	[8.3, "run", 90.0], [9.3, "shot", "5_busy"],
	[9.4, "heavy"], [9.5, "run", 20.0], [10.6, "shot", "6_heavy"],
	[10.7, "shop"], [10.8, "buy"], [11.3, "shot", "7_shop"],
	[11.4, "shop_x"], [11.5, "ask"], [12.0, "shot", "8_ask"],
	[12.1, "go"], [12.65, "shot", "9_swell"], [13.4, "shot", "10_thin"],
	[14.6, "shot", "11_perks"], [14.7, "perk"], [15.1, "shot", "12_perk"],
	[15.2, "perks_x"], [18.2, "shot", "13_ashes"],
	[18.3, "tutor"], [21.3, "shot", "14_tut_throw"],
	[21.4, "page", 1], [26.0, "shot", "15_tut_light"],
	[26.1, "page", 2], [28.5, "shot", "16_tut_nova"],
	[28.6, "leave"], [29.8, "shot", "17_tab_after"],
	[29.9, "quit"],
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
func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
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
	_s._refresh_tiles()
	print("ran %.0f s: mass %.1f light %.1f bodies %d lv %s" % [seconds, _s.sim.mass, _s.sim.light, _s.sim.bodies.size(), str(_s.sim.lv)])

func _process(delta: float) -> bool:
	_t += delta
	_frames += 1
	_gap_sum += delta
	_gap_max = maxf(_gap_max, delta)
	if _t > 60.0:
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
			"drag":
				_drag(step[2])
			"let_go":
				_touch(Vector2.ZERO, false)
				print("thrown: pouch %d, bodies %d, speed %.0f" % [_s.sim.pouch, _s.sim.bodies.size(), _s.sim.bodies[0].vel.length() if not _s.sim.bodies.is_empty() else -1.0])
			"run":
				_run(float(step[2]))
			"heavy":
				_s.sim.mass = 6000.0
				_s.sim.light = 5000.0
			"shop":
				_s._shop_b.pressed.emit()
				print("shop open: %s, badge %d" % [_s._shop.visible, _s._shop_b.badge])
			"buy":
				var before: int = _s.sim.lv.glow
				_s._on_tile("glow")
				print("bought glow: %d -> %d, light %.0f" % [before, _s.sim.lv.glow, _s.sim.light])
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
