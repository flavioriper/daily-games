extends SceneTree

## Factory through the real menu, on throwaway files: the tab shown, Play
## pressed, the forest tapped with a finger on a crown (a log, which lies
## past its gate), its badge tapped with a finger (its card), the screen
## left, the tab again. Both taps are real ScreenTouch events parsed by the
## engine, so they reach the screen through its own field as a phone's would.
## tests/_shot_factory.gd builds the screen by hand; this one proves the
## menu's own wiring (ui/menu.gd `_open_factory`: the tab lends its one sim
## and takes it back).
##   caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top \
##     --script res://tests/_shot_factory_menu.gd -- <outdir> > log 2>&1

var _menu: Node
var _s: Node
var _t := 0.0
var _i := 0
var _out := "/tmp"
var _tmp: Array = []
var _fails := 0
const STEPS := [[1.5, "tab"], [2.2, "shot", "m1_tab"], [2.3, "play"], [3.2, "shot", "m2_screen"],
	[3.3, "tap"], [3.4, "release"], [3.9, "shot", "m3_tapped"], [5.0, "log"], [5.1, "shot", "m4_log"],
	[5.2, "badge"], [5.3, "release"], [6.0, "card"], [6.1, "shot", "m5_forest_card"], [6.2, "leave"], [7.0, "shot", "m6_tab_after"], [7.1, "quit"]]

func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1

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

func _touch(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = at
	e.pressed = down
	Input.parse_input_event(e)

var _px := Vector2.ZERO

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
				_menu._show_tab("factory")
				_check(_menu.factory_tab.is_visible_in_tree(), "the tab is shown")
			"play":
				_menu.factory_tab.play.emit("factory")
				_s = _menu.get_node_or_null("Factory")
				_check(_s != null, "Play mounts the screen")
				_check(_s != null and _s.sim == _menu.factory_tab.sim, "the screen holds the tab's own sim")
				_check(_s != null and _s.sim.plates.size() == 2 and _s.sim.sources.size() == 1 and _s.sim.items.is_empty(),
					"which is a new land: the market's plate, a forest behind it, nothing lying")
				_check(not _menu.factory_tab.is_processing(), "the tab stops stepping while lent")
			"tap":
				# the tree nearest the eye, pressed where the screen draws its crown
				var front := {}
				for id in _s.sim.trees:
					var tree: Dictionary = _s.sim.trees[id]
					if front.is_empty() or _s.life.depth(Vector2(tree.tile)) > _s.life.depth(Vector2(front.tile)):
						front = tree
				var world: Node2D = _s.world
				_px = world.get_global_transform_with_canvas() * (_s.life.mid(front.tile) as Vector2) + Vector2(0.0, -30.0)
				# window coordinates: the canvas is stretched into the window
				_px = root.get_final_transform() * _px
				_touch(_px, true)
			"release":
				_touch(_px, false)
			"log":
				var logs := 0
				for tile in _s.sim.items:
					logs += (_s.sim.items[tile] as Array).size()
				var gate: Vector2i = _s.sim.gate(Vector2i(0, -1), 1) + Vector2i(0, 1)
				_check(logs == 1 and _s.sim.items.has(gate) and int(_s.sim.sources[Vector2i(0, -1)].stock) == 0,
					"a finger's tap on the forest gave one log and it lies past the gate (%d)" % logs)
			"badge":
				var world: Node2D = _s.world
				_px = root.get_final_transform() * (world.get_global_transform_with_canvas() * (_s.badge_at(Vector2i(0, -1)) as Vector2))
				_touch(_px, true)
			"card":
				var logs := 0
				for tile in _s.sim.items:
					logs += (_s.sim.items[tile] as Array).size()
				_check(_s.card_open() and _s._card_for == "forest", "a finger's tap on the forest's badge opens its card")
				_check(logs == 1 and int(_s.sim.sources[Vector2i(0, -1)].stock) == 0, "and takes no log")
			"leave":
				_s.go_back()
				_check(not _s.card_open(), "back closes the card and stays on the screen")
				_s._on_back()
				_check(_menu.factory_tab.is_processing(), "the tab steps again once the land is back")
			"quit":
				_check(_menu.get_node_or_null("Factory") == null or _menu.get_node("Factory").is_queued_for_deletion(), "the screen is gone")
				print("shot_factory_menu: %d failed" % _fails)
				_finish()
				quit(1 if _fails > 0 else 0)
				return true
	return false
