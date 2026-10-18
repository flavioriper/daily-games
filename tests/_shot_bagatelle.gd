extends SceneTree

## The Arcade tab and Bagatelle, shot at fixed beats with real touches:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_bagatelle.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab (Bagatelle's card on its page), 2 a new board, three real
## taps on the board drop three marbles, 3 marbles falling, Drop held drops
## more, 4 the upgrades card by a real tap on the tray, a row bought by a
## real tap, 5 the jar card by a real tap on the jar's chips, Merge all
## pressed, 6 the stars card by a real tap on the stars plate, Cash out
## pressed twice, 7 a gold pin carried by a real press, drag and release,
## 8 a crowded board (three hundred marbles, auto drop at the top), then the
## tutorial's four pages. Prints the draw calls at each shot. With no
## display it shoots nothing and still drives every beat (a smoke run). The
## board is kept in a file of the harness's own (`Sim.path`).

const Sim = preload("res://arcade/bagatelle_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _blind := false
var _fails := 0
var _card: Control
var _pin := -1
var _to := -1

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	Sim.path = "user://_shot_bagatelle.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sim.path))
	_blind = DisplayServer.get_name() == "headless"
	for a: String in OS.get_cmdline_user_args():
		if a == "reduce":
			load("res://core/motion.gd").reduce = true
		elif a in ["en", "pt", "es"]:
			load("res://core/locale.gd")._current = a
		else:
			_out = a
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

func _shot(name: String) -> void:
	var sim = _s.sim if _s != null else null
	if not _blind:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/bg_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d balls=%d coins=%s" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.balls.size() if sim != null else 0, Sim.short(sim.coins) if sim != null else "-"])

func _win(c: Control, at: Vector2) -> Vector2:
	return root.get_final_transform() * (c.get_global_transform_with_canvas() * at)

func _touch(at: Vector2, down: bool, index := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = down
	ev.position = at
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _drag_ev(at: Vector2, index := 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = at
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _tap(at: Vector2) -> void:
	_touch(at, true)
	_touch(at, false)

func _field(p: Vector2) -> Vector2:
	return _win(_s.board, _s.board.screen_of(p))

## A real tap on the middle of a Control.
func _press(c: Control) -> void:
	_tap(_win(c, c.size * 0.5))

func _done() -> bool:
	Sim.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_bagatelle.cfg"))
	print("%d failed" % _fails)
	return true

func _next() -> void:
	_at = _t
	_step += 1

func _process(delta: float) -> bool:
	_t += delta
	if _t > 120.0:
		print("gave up at step %d" % _step)
		_fails += 1
		return _done()
	var sim = _s.sim if _s != null else null
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_next()
		1:
			if _t > _at + 1.0:
				_menu._turn_page(1)
				_next()
		2:
			if _t > _at + 0.8:
				_shot("1_tab")
				_menu._open_arcade("bagatelle")
				_s = _menu.get_node_or_null("Bagatelle")
				_check("the screen opens", _s != null)
				if _s == null:
					return _done()
				_next()
		3:
			if _t > _at + 1.2:
				_shot("2_new")
				_check("a new board holds one clay marble", sim.in_jar() == 1)
				sim.owned[0] = 3
				sim.jar[0] = 3
				for x in [420.0, 500.0, 580.0]:
					_tap(_field(Vector2(x, 300.0)))
				_check("three real taps ask the dropper for three marbles", sim.balls.size() + sim._want == 3)
				_next()
		4:
			if _t > _at + 0.6:
				_shot("3_falling")
				_check("the dropper let them go from its glide", sim.balls.size() == 3 and sim.in_jar() == 0 and sim.drop_x >= Sim.W * Sim.AIM_LO - 1.0 and sim.drop_x <= Sim.W * Sim.AIM_HI + 1.0)
				_tap(_field(Vector2(500.0, 300.0)))
				_check("a tap with the jar empty drops nothing", sim.balls.size() <= 3 and sim._want == 0)
				_next()
		5:
			if _t > _at + 7.0:
				_check("the marbles landed and paid", sim.balls.is_empty() and sim.coins > 0.0 and sim.landed == 3)
				# Drop held for a second
				var drop := _win(_s.tray, _s._slot_rect(0).get_center())
				sim.owned[0] = 12
				sim.jar[0] = 12
				_touch(drop, true)
				_next()
		6:
			if _t > _at + 1.0:
				var drop := _win(_s.tray, _s._slot_rect(0).get_center())
				_touch(drop, false)
				_check("Drop held drops a marble every %.2f s (%d)" % [_s.Board.HOLD_EVERY, sim.drops], sim.drops >= 3 + 5)
				_shot("3b_held")
				sim.coins = 5000.0
				_tap(_win(_s.tray, _s._slot_mid(1)))
				_card = _s.get_node_or_null("Shop")
				_check("the tray's Upgrades opens the upgrades", _card != null and _card.mode == "up")
				_next()
		7:
			if _t > _at + 0.5:
				_shot("4_upgrades")
				_press(_card._rows["value"])
				_check("a real tap on Value buys a rank", int(sim.up.value) == 1)
				_next()
		8:
			if _t > _at + 0.5:
				_shot("4b_bought")
				_s.go_back()
				_check("back closes the card", _s.get_node_or_null("Shop") == null or _s.get_node("Shop").is_queued_for_deletion())
				_next()
		9:
			if _t > _at + 0.5:
				sim.owned[0] += 25
				sim.jar[0] += 25
				_tap(_win(_s.board, _s.board.jar_rect().get_center()))
				_card = _s.get_node_or_null("Shop")
				_check("a real tap on the jar's chips opens the jar", _card != null and _card.mode == "jar")
				_next()
		10:
			if _t > _at + 0.5:
				_shot("5_jar")
				var had: int = sim.owned[1]
				_press(_card._merge_all)
				_check("Merge all merges clay into glass (%d)" % sim.owned[1], sim.owned[1] > had)
				_next()
		11:
			if _t > _at + 1.2:
				_shot("5b_merged")
				_s.go_back()
				_next()
		12:
			if _t > _at + 0.5:
				sim.earned = 2e6
				_tap(_win(_s.hud, _s._stars_rect().get_center()))
				_card = _s.get_node_or_null("Shop")
				_check("a real tap on the stars plate opens the stars", _card != null and _card.mode == "stars")
				_next()
		13:
			if _t > _at + 0.5:
				_shot("6_stars")
				var will: int = sim.stars_for()
				_press(_card._cash)
				_check("the first press on Cash out only asks", sim.stars == 0)
				_press(_card._cash)
				_check("the second cashes out %d stars" % will, sim.stars == will and will > 0 and sim.coins == 0.0)
				_next()
		14:
			if _t > _at + 1.4:
				_shot("6b_cashed")
				sim.stars += 10
				sim.shop_buy("plus")
				_pin = sim.bonus.keys()[0]
				_to = Sim.pin_id(5, 6)
				var from := _field(Sim.pin_pos(_pin))
				var to := _field(Sim.pin_pos(_to))
				# the board sets a carried pin where it is drawn, 40 px over the finger
				var lift := _win(_s.board, Vector2(0, 40.0)) - _win(_s.board, Vector2.ZERO)
				_touch(from, true)
				for i in range(1, 9):
					_drag_ev(from.lerp(to + lift, i / 8.0))
				_shot("7_carry")
				_touch(to + lift, false)
				_check("a gold pin carried by a real press, drag and release", sim.bonus.has(_to) and not sim.bonus.has(_pin))
				_next()
		15:
			if _t > _at + 0.6:
				sim.owned[0] = 300
				sim.jar[0] = 300
				sim.up.auto = 40
				sim.up.weight = 10
				_next()
		16:
			if _t > _at + 4.0:
				_shot("8_crowded")
				_s.tutor.show()
				_card = _s.get_node_or_null("HowToPlay")
				_check("the tutorial card opens", _card != null)
				if _card == null:
					return _done()
				_next()
		17:
			if _t > _at + 2.0:
				_shot("9_tut_drop")
				_check("the Drop page dropped marbles", _card._pages[0].diagram._sim.drops >= 2)
				_card._turn(1)
				_next()
		18:
			if _t > _at + 4.0:
				_shot("10_tut_cups")
				_check("the Cups page's cups went up", _card._pages[1].diagram._sim.landed > 0)
				_card._turn(1)
				_next()
		19:
			if _t > _at + 3.0:
				_shot("11_tut_jar")
				_check("the Jar page merged two glass", _card._pages[2].diagram._sim.owned[1] == 2)
				_card._turn(1)
				_next()
		20:
			if _t > _at + 3.0:
				var page: Control = _card._pages[3].diagram
				_shot("12_tut_stars")
				_check("the Stars page carried the gold pin to the middle", page._sim.bonus.has(Sim.pin_near(Vector2(500, 390), Sim.DX)))
				_card.free()
				return _done()
	return false
