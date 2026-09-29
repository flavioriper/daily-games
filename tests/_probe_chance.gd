extends SceneTree

## Every Arcade screen through the real menu: the boost card up, Play, the
## run forced over, the Second chance taken, and the run going again -- then
## over once more with no second offer. Throwaway wallet; puts
## user://arcade.cfg back.
##   godot --headless --script tests/_probe_chance.gd
## The video path (no gold, no chance held; the grey stand-in earns or not):
##   ADS_FAKE_FULL=1 godot --headless --script tests/_probe_chance.gd
##   ADS_FAKE_FULL=skip godot --headless --script tests/_probe_chance.gd

const GAMES := ["firefly", "molehill", "stackwood", "thirteen", "posy"]
const NODE := {"firefly": "Firefly", "molehill": "Molehill", "stackwood": "Stackwood", "thirteen": "Thirteen", "posy": "Posy"}

var _menu: Node
var _t := 0.0
var _gi := 0
var _step := 0
var _at := 0.0
var _fails := 0
var _backup := PackedByteArray()
var _had := false
var _tmp := ""
var _video := ""
var _ads_had := false
var _ads_backup := PackedByteArray()

func _initialize() -> void:
	_had = FileAccess.file_exists("user://arcade.cfg")
	if _had:
		_backup = FileAccess.get_file_as_bytes("user://arcade.cfg")
	_ads_had = FileAccess.file_exists("user://ads.cfg")   # pacing counts finished runs
	if _ads_had:
		_ads_backup = FileAccess.get_file_as_bytes("user://ads.cfg")
	var wallet: Node = root.get_node("Wallet")
	_tmp = OS.get_user_data_dir() + "/_probe_chance_wallet.cfg"
	DirAccess.remove_absolute(_tmp)
	wallet.path = _tmp
	wallet.reload()
	_video = OS.get_environment("ADS_FAKE_FULL")
	if _video == "":
		wallet.add_gold(5000, "probe")
	else:
		# the welcome gift is gold and a chance of each: spend it all
		wallet.spend(wallet.gold(), "probe")
		for id: String in wallet.Boosters.ITEMS:
			while wallet.count(id) > 0:
				wallet.use(id, "probe")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print(("ok   " if ok else "FAIL ") + what)

func _force_over(g: String, s: Node) -> void:
	var sim = s.sim
	match g:
		"firefly":
			sim.ships = 1
			sim._lose_ship()
		"molehill":
			sim.t += 1000.0
		"stackwood":
			for c in 5:
				for i in 8:
					(sim.cols[c] as Array).append({"id": 5000 + c * 10 + i, "v": 1 << (1 + (i + c) % 7)})
			sim.piece = {}
			sim._finish_resolve()
		"thirteen":
			sim.give_up()
			s._play_events()
		"posy":
			sim.give_up()

func _finish(code: int) -> void:
	if _had:
		var f := FileAccess.open("user://arcade.cfg", FileAccess.WRITE)
		f.store_buffer(_backup)
		f.close()
	else:
		DirAccess.remove_absolute(OS.get_user_data_dir() + "/arcade.cfg")
	if _ads_had:
		var a := FileAccess.open("user://ads.cfg", FileAccess.WRITE)
		a.store_buffer(_ads_backup)
		a.close()
	else:
		DirAccess.remove_absolute(OS.get_user_data_dir() + "/ads.cfg")
	DirAccess.remove_absolute(_tmp)
	print("FAILS: %d" % _fails)
	quit(code)

func _process(delta: float) -> bool:
	_t += delta
	if OS.get_environment("PROBE_T") != "" and int(_t * 10) != int((_t - delta) * 10):
		printerr("t=%.1f" % _t)
	if _t > 90.0:
		_check(false, "timed out")
		_finish(1)
		return true
	if _t < 1.5 or _t < _at:
		return false
	if _gi >= GAMES.size():
		_finish(1 if _fails > 0 else 0)
		return true
	var g: String = GAMES[_gi]
	var s: Node = _menu.get_node_or_null(NODE[g])
	printerr("-- %s step %d" % [g, _step])
	match _step:
		0:
			_menu._open_arcade(g)
			_step = 1
			_at = _t + 0.5
		1:
			var card: Node = s.get_node_or_null("BoostCard")
			if _video == "":
				_check(card != null, g + ": boost card up")
			if card != null:
				for id in card._toggles:
					card._toggles[id].button_pressed = true
				card._on_play()
			_step = 2
			_at = _t + 2.5
		2:
			_check(s.sim != null and not s.sim.is_over(), g + ": playing with " + ",".join(s._boosts))
			_force_over(g, s)
			_step = 3
			_at = _t + 1.0
		3:
			var chance: Node = s.get_node_or_null("SecondChance")
			_check(chance != null, g + ": second chance offered")
			if chance != null:
				if _video != "":
					_check(chance.get_node_or_null("**/Use") == null and chance.find_child("Watch", true, false) != null, g + ": video button only")
					var w: Button = chance.find_child("Watch", true, false)
					w.pressed.emit()
					w.pressed.emit()   # a double tap while the video is up
					if _video == "skip":
						_step = 6
						_at = _t + 3.0
						return false
					_at = _t + 3.0
				else:
					chance._on_use()
			_step = 4
			_at = maxf(_at, _t + 1.5)
		6:
			var c2: Node = s.get_node_or_null("SecondChance")
			_check(c2 != null and s.sim.is_over(), g + ": skipped video leaves the card up")
			var w2: Button = c2.find_child("Watch", true, false) if c2 != null else null
			_check(w2 != null and not w2.disabled, g + ": Watch still usable")
			if c2 != null:
				c2._on_no()
			_step = 5
			_at = _t + 4.0
		4:
			_check(not s.sim.is_over() and s._boosted, g + ": going again")
			_force_over(g, s)
			_step = 5
			_at = _t + 4.0
		5:
			_check(s.get_node_or_null("SecondChance") == null, g + ": no second offer")
			_check(s._end != null, g + ": end card up")
			s.closed.emit()
			_gi += 1
			_step = 0
			_at = _t + 1.0
	return false
