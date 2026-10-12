extends SceneTree

## The Arcade tab and Griddle, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_griddle.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab, 2 a new stand's counter, 3 a full pass and a long
## queue, then six real touches on the queue through the viewport (printed:
## the rush), 4 the clean counter, 5 the fields by a real touch on the tray:
## lots at every stage, one resting, one tired, one on tonic, then a real
## touch on a ripe lot (printed) and on a growing one: its card (5b), 6 the
## yard: cows filling, full, poorly and lying in, a real touch on the full
## one and the poorly one (printed), 7 the office with a mood near the top,
## a real touch on a notch and on a favour (printed), 8 a grown counter:
## three grills and tills, the crew worn, the hurry board on, 9 the shop,
## and a row bought, 10 a star, 11 a mood at the top. Prints the draw calls
## at each shot. With no display it shoots nothing and still drives every
## beat, so it serves as a smoke run. The stand is kept in a file of the
## harness's own (`Sim.path`), so this machine's stand is never touched.

const Sim = preload("res://arcade/griddle_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _blind := false

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	Sim.path = "user://_shot_griddle.cfg"
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

func _shot(name: String) -> void:
	var sim = _s.sim if _s != null else null
	if not _blind:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/gr_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d coins=%d served=%d rush=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.coins if sim != null else 0, sim.served if sim != null else 0, sim.rush if sim != null else 0])

## A point of the world, or of the tray, as the window has it.
func _win(c: Control, at: Vector2) -> Vector2:
	return root.get_final_transform() * (c.get_global_transform_with_canvas() * at)

func _tap(at: Vector2) -> void:
	for down in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = down
		ev.position = at
		Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _tap_world(at: Vector2) -> void:
	_tap(_win(_s.world, at))

func _tap_tray(slot: int) -> void:
	_tap(_win(_s.tray, _s._slot_mid(slot)))

func _close(node: String) -> void:
	var n: Node = _s.get_node_or_null(node)
	if n != null:
		n.closed.emit()
		n.queue_free()

func _done() -> bool:
	# the window closing is a focus lost, and that saves: not after this
	Sim.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_griddle.cfg"))
	return true

func _next() -> void:
	_at = _t
	_step += 1

func _process(delta: float) -> bool:
	_t += delta
	if _t > 120.0:
		print("gave up at step %d" % _step)
		return _done()
	var sim = _s.sim if _s != null else null
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_next()
		1:
			if _t > _at + 1.0:
				_shot("1_tab")
				_menu._open_arcade("griddle")
				_s = _menu.get_node("Griddle")
				_next()
		2:
			if _t > _at + 1.2:
				_shot("2_new")
				sim.tills = 2
				sim.grills = 2
				sim.ready = 6
				sim.arrive = -1000.0
				sim.queue = [0.0, 0.0, 0.0, 0.0, 30.0, 0.0]
				sim.cooking = [0.5, 0.0, 0.0]
				_s.world._sync_looks()
				_next()
		3:
			if _t > _at + 0.7:
				_shot("3_queue")
				_next()
		4, 5, 6, 7, 8, 9:
			# six real touches, a fifth of a second apart
			if _t > _at + 0.2:
				_tap_world(_s.world.queue_at(0) + Vector2(0, -60.0))
				if _step == 6:
					_shot("3b_rush")
				if _step == 9:
					print("six real touches on the queue were a rush of six and a clean counter: ", sim.best_rush == 6 and sim.cleans == 1 and sim.served == 6)
				_next()
		10:
			if _t > _at + 0.5:
				_shot("4_clean")
				_next()
		11:
			if _t > _at + 3.6:
				_shot("4b_tally")
				_tap_tray(1)
				_next()
		12:
			if _t > _at + 0.6:
				print("a real touch on the tray showed the fields: ", _s.world.place == "fields")
				for i in 9:
					var l: Dictionary = sim.lots[i]
					l.open = true
					l.crop = Sim.WHEAT if i % 2 == 0 else Sim.CLOVER
					l.t = sim.grow_time(l.crop) * [0.1, 0.4, 0.8, 1.0][i % 4]
					l.ripe = i % 4 == 3
				sim.lots[4].crop = Sim.FALLOW
				sim.lots[4].soil = 46.0
				sim.lots[5].soil = 22.0
				sim.lots[6].tonic = true
				sim.lots[2].soil = 55.0
				sim.cart_t = -100.0
				sim.loaves = 9
				sim.feed = 3
				_next()
		13:
			if _t > _at + 0.6:
				_shot("5_fields")
				var had: int = sim.feed
				_tap_world(_s.world.lot_mid(3))
				print("a real touch cut the ripe lot: ", sim.feed > had and not sim.lots[3].ripe)
				_tap_world(_s.world.lot_mid(1))
				print("and one on a growing lot asked for its card: ", _s.get_node_or_null("Card") != null)
				_next()
		14:
			if _t > _at + 0.7:
				_shot("5b_card")
				var card: Node = _s.get_node_or_null("Card")
				if card != null:
					(card.find_child("tonic", true, false) as Button).pressed.emit()
				print("the card's tonic was put on the lot: ", sim.lots[1].tonic)
				_next()
		15:
			# the card is gone a frame after its choice: the tray is touched then
			if _t > _at + 0.4:
				_tap_tray(2)
				sim.stalls = 4
				sim.pail_t = -100.0
				sim.feed = 14
				sim.cheese = 5
				sim.cows.clear()
				for k in 6:
					var c: Dictionary = sim._cow()
					c.milk = [0.3, 1.0, 0.7, 0.0, 0.0, 0.5][k]
					c.full = k == 1
					c.poorly = k in [3, 4]
					c.rest = Sim.TUCK * 0.6 if k == 4 else 0.0
					sim.cows.append(c)
				sim.scraps = true
				_next()
		16:
			if _t > _at + 0.6:
				_shot("6_yard")
				var w: Control = _s.world
				_tap_world(w.cow_foot(1) - Vector2(0, w.cow_size() * 0.4))
				print("a real touch took the full cow's milk: ", sim.cheese == 6 and not sim.cows[1].full)
				_tap_world(w.cow_foot(3) - Vector2(0, w.cow_size() * 0.4))
				print("and one tucked the poorly cow up: ", float(sim.cows[3].rest) > 0.0)
				_tap_tray(4)
				_next()
		17:
			if _t > _at + 0.6:
				sim.coins = 900
				sim.mood.town = 86.0
				sim.mood.vet = 64.0
				sim.mood.garden = 22.0
				sim.mood.crew = 8.0
				sim.today = 412
				sim.yesterday = 1260
				_next()
		18:
			if _t > _at + 0.6:
				_shot("7_office")
				var w: Control = _s.world
				_tap_world(w.notch_at(2))
				print("a real touch turned the signboard to its third notch: ", sim.volume == 2)
				var was: float = sim.mood.town
				_tap_world(w.favour_rect(3).get_center())
				print("and one did the neighbours a favour: ", float(sim.mood.town) < was - 40.0 and sim.coins < 900)
				_next()
		19:
			if _t > _at + 0.8:
				_shot("7b_favour")
				_tap_tray(3)
				_next()
		20:
			if _t > _at + 0.6:
				sim.grills = 3
				sim.tills = 3
				sim.loaves = 20
				sim.cheese = 20
				sim.ready = 4
				sim.cooking = [0.3, 0.7, 0.1]
				sim.pep = 18.0
				sim.bell = true
				sim.queue = [2.0, 8.0, 31.0, 12.0, 4.0, 36.0, 1.0, 20.0, 9.0, 0.0, 3.0]
				_s.world._sync_looks()
				_next()
		21:
			if _t > _at + 0.7:
				_shot("8_grown")
				_tap_tray(0)
				_next()
		22:
			if _t > _at + 0.7:
				print("a real touch on the tray opened the shop: ", _s.get_node_or_null("Shop") != null)
				_shot("9_shop")
				var shop: Node = _s.get_node_or_null("Shop")
				if shop != null:
					sim.coins = 5000
					shop.refresh()
					shop.buy("heat")
					shop.show_page("fields")
					shop.buy("lot")
				print("a level and a lot were bought there: ", int(sim.lv.heat) == 1 and sim.opened() == 10)
				_next()
		23:
			if _t > _at + 0.6:
				_shot("9b_bought")
				_close("Shop")
				sim.served = sim.next_star() - 1
				sim.ready = 3
				_next()
		24:
			if _t > _at + 0.4:
				var stars: int = sim.stars
				_tap_world(_s.world.queue_at(0) + Vector2(0, -60.0))
				print("the sale that made the count was a star: ", sim.stars == stars + 1)
				_next()
		25:
			if _t > _at + 0.7:
				_shot("10_star")
				sim.volume = 3
				sim.mood.town = 99.95
				_next()
		26:
			if _t > _at + 3.2:
				print("the neighbours' mood at the top took the signboard down: ", sim.volume == 0 and sim.hush > 0.0)
				_shot("11_boil")
				return _done()
	return false
