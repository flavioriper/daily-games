extends SceneTree

## Factory through the real menu, on throwaway files: the Arcade tab shown,
## Play pressed (the screen mounted on the tab's own new floor, shot), the
## screen left, the tab again. tests/_shot_factory.gd builds the screen by
## hand and plays it; this one proves the menu's own wiring (ui/menu.gd
## `_open_factory`: the tab lends its one sim and takes it back).
##   caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top \
##     --script res://tests/_shot_factory_menu.gd -- <outdir> > log 2>&1

var _menu: Node
var _s: Node
var _t := 0.0
var _i := 0
var _out := "/tmp"
var _tmp: Array = []
var _fails := 0
const STEPS := [[1.5, "tab"], [1.6, "page"], [2.6, "sold"], [3.1, "shot", "m1_card"], [3.15, "unsell"], [3.2, "play"],
	[4.1, "shot", "m2_screen"], [4.2, "leave"], [5.0, "shot", "m3_tab_after"], [5.1, "quit"]]

func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1

## The Factory card's face on the Arcade page, or null.
func _factory_card() -> Control:
	var stack: Array[Node] = [_menu]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and n.get("entry") is Dictionary and n.get("entry").get("id", "") == "factory" and n.get("_line_said") != null:
			return n
		stack.append_array(n.get_children())
	return null

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var dir := OS.get_user_data_dir()
	var wallet: Node = root.get_node("Wallet")
	DirAccess.remove_absolute(dir + "/_shot_wallet.cfg")
	wallet.path = dir + "/_shot_wallet.cfg"
	wallet.reload()
	_tmp.append(dir + "/_shot_wallet.cfg")
	var sim_script = load("res://factory/sim.gd")
	sim_script.path = dir + "/_shot_factory_menu.cfg"
	DirAccess.remove_absolute(sim_script.path)
	_tmp.append(sim_script.path)
	var progress = load("res://core/progress.gd")
	progress.path = dir + "/_shot_progress.cfg"
	DirAccess.remove_absolute(progress.path)
	_tmp.append(progress.path)
	var main: Node = load("res://world/main.tscn").instantiate()
	main.set_script(load("res://tests/_offline_main.gd"))
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

## The throwaway files go. The tab keeps its land once more as the tree comes
## down (ui/menu/factory_tab.gd saves on leaving the tree unless the land is
## lent), which would write the land's file again after it was removed: the
## land is marked lent first, so nothing is left behind.
func _finish() -> void:
	if _menu != null and _menu.factory_tab != null:
		_menu.factory_tab.lent = true
	for p: String in _tmp:
		DirAccess.remove_absolute(p)

func _process(delta: float) -> bool:
	_t += delta
	while _i < STEPS.size() and _t >= float(STEPS[_i][0]):
		var step: Array = STEPS[_i]
		_i += 1
		match String(step[1]):
			"shot":
				root.get_texture().get_image().save_png("%s/%s.png" % [_out, step[2]])
				print("%s draw calls %d" % [step[2], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
			"tab":
				if _menu.gifts_sheet.is_open():
					_menu.gifts_sheet.close()
				# Factory is a card of the Arcade list since 2026-10-13; its tab
				# is the land's hidden owner.
				_menu._show_tab("arcade")
				_check(_menu.arcade_tab.GAMES.has("factory") and not _menu.factory_tab.is_visible_in_tree(),
					"Arcade lists Factory and its tab stays hidden")
			"page":
				# Factory is the fourteenth card: the Arcade list's second page
				_menu._turn_page(1)
			"sold":
				# a floor that sold two boxes, five seconds apart: the Arcade
				# line says the coins and the pace
				var sim: RefCounted = _menu.factory_tab.sim
				sim.coins = 7
				sim.sold_at.assign([100, 150])
				_menu.arcade_tab.refresh()
				_menu._refresh_cards()
				var want: String = tr("FACTORY_CARD_COINS") % "7" + " \u00b7 " + tr("FACTORY_PACE") % "5"
				_check(_menu.arcade_tab.line("factory") == want,
					"the Arcade line says the coins and the pace (%s)" % _menu.arcade_tab.line("factory"))
				var card: Control = _factory_card()
				_check(card != null and card.get("_line_said") == want, "the Factory card carries that line")
			"unsell":
				_menu.factory_tab.sim.coins = 0
				_menu.factory_tab.sim.sold_at.clear()
			"play":
				_menu.arcade_tab.play.emit("factory")
				_s = _menu.get_node_or_null("Factory")
				_check(_s != null, "Play mounts the screen")
				_check(_s != null and _s.sim == _menu.factory_tab.sim, "the screen holds the tab's own sim")
				_check(_s != null and _s.sim.robots.size() == 3 and _s.sim.coins == 0 and _s.sim.belts.is_empty() and _s.sim.milestone == 0,
					"which is a new floor: three robots, no coins, no belts, milestone 0")
				_check(not _menu.factory_tab.is_processing(), "the tab stops stepping while lent")
			"leave":
				_s._on_back()
				_check(not _menu.factory_tab.lent and not _menu.factory_tab.is_processing() and _menu._tab == "arcade",
					"the floor is back with its hidden owner, unstepped, and Arcade is up")
			"quit":
				_check(_menu.get_node_or_null("Factory") == null or _menu.get_node("Factory").is_queued_for_deletion(), "the screen is gone")
				print("shot_factory_menu: %d failed" % _fails)
				_finish()
				quit(1 if _fails > 0 else 0)
				return true
	return false
