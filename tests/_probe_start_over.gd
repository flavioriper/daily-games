extends SceneTree

## Start over on the Arcade games (ui/hud/start_over_sheet.gd, ui/menu.gd's
## `_start_over`): a scored game (Firefly), a kept one (Bagatelle) and the
## Factory are opened through the menu with progress in them, Start over is
## pressed on the settings sheet, Keep first and then the yes, and the game
## must come back open and empty. The Mac's own arcade.cfg is put back on
## every exit path.
##
##     godot --headless --path . --script res://tests/_probe_start_over.gd [-- reduce]

const ArcadeRecord = preload("res://arcade/arcade_record.gd")
const BagSim = preload("res://arcade/bagatelle_sim.gd")
const FactorySim = preload("res://factory/sim.gd")

var _menu: Node
var _fails := 0
var _t := 0.0
var _step := 0
var _at := 0.0
var _backup := ""

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	# `reduce`: the sheets close at once, so the yes runs the whole way
	# inside its press and only the deferred connection keeps the free out
	if "reduce" in OS.get_cmdline_user_args():
		load("res://core/motion.gd").reduce = true
	_backup = OS.get_user_data_dir() + "/_probe_start_over_arcade.bak"
	var real := ProjectSettings.globalize_path(ArcadeRecord.PATH)
	if FileAccess.file_exists(real):
		DirAccess.copy_absolute(real, _backup)
	BagSim.path = "user://_probe_start_over_bag.cfg"
	FactorySim.path = "user://_probe_start_over_factory.cfg"
	for p: String in [BagSim.path, FactorySim.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_probe_start_over_wallet.cfg"
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

func _screen(name_: String) -> Control:
	return _menu.get_node_or_null(name_)

func _press(b: Button) -> void:
	b.pressed.emit()

func _finish() -> void:
	var real := ProjectSettings.globalize_path(ArcadeRecord.PATH)
	DirAccess.remove_absolute(real)
	if FileAccess.file_exists(_backup):
		DirAccess.copy_absolute(_backup, real)
		DirAccess.remove_absolute(_backup)
	for p: String in [BagSim.path, FactorySim.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("start over probe: %d failed" % _fails)
	quit(1 if _fails > 0 else 0)

## Opens `game` with progress put in by `fill`, asks, keeps, asks again and
## says yes; `empty` then judges the screen that came back.
func _beat(game: String, node: String) -> void:
	match _step % 4:
		0:
			_menu._open_arcade(game)
		1:
			var s := _screen(node)
			_check("%s opens" % game, s != null)
			if s == null:
				_step += 3
				return
			_fill(game, s)
			var sheet: Control = s.settings_sheet
			_check("%s: Start over on the sheet" % game, sheet.with_reset and sheet.reset_asks != "")
			sheet.open()
			_press(sheet.reset_button)
			_check("%s: asked first" % game, sheet.start_over_sheet.is_open() and sheet.is_open())
			_press(sheet.start_over_sheet.keep_button)
		2:
			var s := _screen(node)
			var sheet: Control = s.settings_sheet
			_check("%s: Keep leaves it as it was" % game, s.is_inside_tree() and not _empty(game, s))
			_press(sheet.reset_button)
			_press(sheet.start_over_sheet.yes_button)
		3:
			var s := _screen(node)
			_check("%s: open again after the yes" % game, s != null and s.is_inside_tree())
			if s != null:
				_check("%s: progress gone" % game, _empty(game, s))
				s.settings_sheet.open()
				_check("%s: the new screen asks too" % game, s.settings_sheet.reset_button.visible)
				s.settings_sheet.close()

func _fill(game: String, s: Control) -> void:
	match game:
		"firefly":
			ArcadeRecord.add("firefly", 4321, 7)
		"bagatelle":
			s.sim.coins = 123456.0
			s.sim.save()
		"factory":
			s.sim.coins = 98765.0
			s.sim.save()

func _empty(game: String, s: Control) -> bool:
	match game:
		"firefly":
			return ArcadeRecord.best("firefly") == 0 and ArcadeRecord.plays("firefly") == 0
		"bagatelle":
			return s.sim.coins < 1000.0
		"factory":
			return s.sim.coins < 1000.0 and _menu.factory_tab.sim == s.sim
	return false

func _process(delta: float) -> bool:
	_t += delta
	if _t - _at < 1.5:
		return false
	_at = _t
	if _step == 4:
		# back to the list: Firefly's card no longer says the wiped best
		_screen("Firefly").go_back()
		_step = 100
		return false
	if _step == 100:
		var line: String = _menu.arcade_tab.line("firefly")
		_check("firefly: the card forgets the best (%s)" % line.replace("\n", " / "), not ("4,321" in line or "4321" in line))
		_step = 4
	if _step < 4:
		_beat("firefly", "Firefly")
	elif _step < 8:
		if _step == 4 and _screen("Firefly") != null:
			return false
		_beat("bagatelle", "Bagatelle")
	elif _step < 12:
		_beat("factory", "Factory")
	else:
		_finish()
		return false
	_step += 1
	return false
