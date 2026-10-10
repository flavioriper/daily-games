extends SceneTree

## Factory through the real menu, on throwaway files: the tab shown, Play
## pressed, a tree tapped with a finger, the screen left, the tab again.
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
	[3.3, "tap"], [3.4, "release"], [4.6, "shot", "m3_beaver"], [7.5, "shot", "m4_log"], [7.6, "leave"], [8.4, "shot", "m5_tab_after"], [8.5, "quit"]]

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

func _finish() -> void:
	for p: String in _tmp:
		DirAccess.remove_absolute(p)

func _touch(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = at
	e.pressed = down
	Input.parse_input_event(e)

var _tree_px := Vector2.ZERO
var _felled := 0

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
				_check(not _menu.factory_tab.is_processing(), "the tab stops stepping while lent")
			"tap":
				# the first standing tree, pressed where the screen draws its crown
				var Art = load("res://factory/art.gd")
				for id in _s.sim.trees:
					var tree: Dictionary = _s.sim.trees[id]
					if String(tree.state) == "standing":
						var world: Node2D = _s.world
						var view: Vector2 = Art.at(Vector2(tree.tile) + Vector2(0.5, 0.5))
						_tree_px = (world.get_global_transform_with_canvas() * view if world != null else view) + Vector2(0.0, -30.0)
						break
				# window coordinates: the canvas is stretched into the window
				_tree_px = root.get_final_transform() * _tree_px
				_touch(_tree_px, true)
			"release":
				_touch(_tree_px, false)
			"leave":
				var logs := 0
				for tile in _s.sim.items:
					logs += (_s.sim.items[tile] as Array).size()
				_check(logs > 0, "a finger's tap felled a tree and a log lies (%d)" % logs)
				_s._on_back()
				_check(_menu.factory_tab.is_processing(), "the tab steps again once the land is back")
			"quit":
				_check(_menu.get_node_or_null("Factory") == null or _menu.get_node("Factory").is_queued_for_deletion(), "the screen is gone")
				print("shot_factory_menu: %d failed" % _fails)
				_finish()
				quit(1 if _fails > 0 else 0)
				return true
	return false
