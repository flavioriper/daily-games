extends SceneTree

## The Valley tab and the Grove, shot at fixed beats through the real menu:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_grove.gd -- <outdir> [reduce]
##
## 1 the Valley tab, 2 a new grove, 3 the circle on its sapling mid-chop,
## 4 the tree down and its log and motes in the air (4b the motes hanging,
## 4c on their way in), 5 a grove some days in,
## 6 the circle over several trees, 7w six frames of a grove far along with
## nothing but the wind on it, 7 that grove (every look, a land of thirty)
## under the circle, 8 the shop's card open and a tile just bought, 9-11 the tutorial's three pages, 12 the
## tab again. Prints at each shot the draw calls, and the frames since the
## last shot with their mean and longest gap. The
## inventory, the grove and the wallet are throwaway files; the field's own
## mouse filter is set to ignore, so the real pointer over the window cannot
## carry the circle off.

const Sim = preload("res://valley/grove_sim.gd")

const STEPS := [
	[1.6, "tab"], [2.6, "shot", "1_tab"],
	[2.7, "open"], [3.7, "shot", "2_start"],
	[3.8, "hold_tree"], [4.55, "shot", "3_chop"], [5.52, "shot", "4_fell"],
	[5.8, "shot", "4b_motes_hang"], [6.0, "let_go"], [6.08, "shot", "4c_motes_in"], [6.1, "mid"], [6.7, "shot", "5_mid"],
	[6.8, "hold_mid"], [7.5, "shot", "6_mid_chop"],
	[7.9, "let_go"], [8.0, "late"], [8.2, "shot", "7w_0"], [8.5, "shot", "7w_1"], [8.8, "shot", "7w_2"], [9.1, "shot", "7w_3"], [9.4, "shot", "7w_4"], [9.7, "shot", "7w_5"],
	[9.8, "hold_mid"], [10.5, "shot", "7_late"],
	[10.70, "let_go"], [10.75, "shop"], [10.80, "buy"], [11.15, "shot", "8_bought"],
	[11.18, "shop_x"], [11.20, "tutor"], [12.70, "shot", "9_tut_chop"],
	[12.80, "page", 1], [15.05, "shot", "10_tut_gifts"],
	[15.10, "page", 2], [18.50, "shot", "11_tut_wait"],
	[18.60, "leave"], [19.50, "shot", "12_tab_after"],
	[19.60, "quit"],
]

var _menu: Node
var _s: Node
var _t := 0.0
var _i := 0
var _out := "/tmp"
var _tmp: Array = []
var _reduce := false
## Frames since the last shot: how many, and their summed and longest gap.
## The longest is the shot before it being saved. Performance.TIME_PROCESS
## is not printed: under a --script run it read 100 ms and more on frames
## that came 9 ms apart.
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
	var dir := OS.get_user_data_dir()
	for pair: Array in [["Wallet", "/_shot_wallet.cfg"], ["Stock", "/_shot_stock.cfg"]]:
		var node: Node = root.get_node(pair[0])
		DirAccess.remove_absolute(dir + pair[1])
		node.path = dir + pair[1]
		node.reload()
		_tmp.append(dir + pair[1])
	Sim.path = dir + "/_shot_grove.cfg"
	DirAccess.remove_absolute(Sim.path)
	_tmp.append(Sim.path)
	var main: Node = load("res://world/main.tscn").instantiate()
	main.set_script(load("res://tests/_offline_main.gd"))
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _finish() -> void:
	root.get_node("Stock").flush()
	for p: String in _tmp:
		DirAccess.remove_absolute(p)
	print("throwaway files removed")

func _press(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	_s._on_field_input(ev)

func _preset(lv: Dictionary, energy: int) -> void:
	for tile: String in lv:
		_s.sim.lv[tile] = lv[tile]
	_s.sim.energy = energy
	_s.sim.catch_up(1e6)
	_s._refresh_tiles()

func _process(delta: float) -> bool:
	_t += delta
	_frames += 1
	_gap_sum += delta
	_gap_max = maxf(_gap_max, delta)
	if _t > 40.0:
		_finish()
		return true
	while _i < STEPS.size() and _t >= float(STEPS[_i][0]):
		var step: Array = STEPS[_i]
		_i += 1
		match String(step[1]):
			"shot":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("%s/grove_%s.png" % [_out, step[2]])
				print("shot %s draws=%d trees=%d | since the last shot: %d frames, %.2f ms a frame (longest %.1f)" % [step[2],
					int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
					_s.sim.trees.size() if is_instance_valid(_s) and _s.sim != null else -1,
					_frames, _gap_sum / maxi(1, _frames) * 1000.0, _gap_max * 1000.0])
				_frames = 0
				_gap_sum = 0.0
				_gap_max = 0.0
			"tab":
				# here and not in _initialize: the menu reads the saved switch
				# as it is built
				if _reduce:
					load("res://core/motion.gd").reduce = true
				if _menu.gifts_sheet.is_open():
					_menu.gifts_sheet.close()
				_menu._show_tab("valley")
			"open":
				_menu.valley_tab._on_play()
				_s = _menu.get_node("Grove")
				_s.field.mouse_filter = Control.MOUSE_FILTER_IGNORE
				print("grove open: trees=%d room=%d field=%s land scale=%.3f" % [_s.sim.trees.size(), _s.sim.room(), _s.field.size, _s._u])
			"hold_tree":
				var tree: Dictionary = _s.sim.trees[0]
				_press(_s.px(tree.pos + Vector2(0.0, -Sim.radius_of(tree.tier))), true)
			"hold_mid":
				_press(_s.px(Sim.LAND * Vector2(0.5, 0.55)), true)
			"let_go":
				_press(Vector2.ZERO, false)
				print("let go: energy=%d wood=%d felled=%d" % [_s.sim.energy, root.get_node("Stock").count("wood"), _s.sim.felled])
			"mid":
				_preset({"axe": 6, "reach": 3, "swing": 2, "sprout": 4, "room": 6, "seeds": 1}, 170)
			"late":
				_preset({"axe": 60, "reach": 10, "swing": 12, "sprout": 16, "room": 27, "seeds": 9}, 123456789)
			"shop":
				_s._shop_b.pressed.emit()
				print("shop open: %s, badge %d" % [_s._shop.visible, _s._shop_b.badge])
			"shop_x":
				_s._shop.get_node("Center/Card").find_child("Close", true, false).pressed.emit()
				print("shop closed: %s" % [not _s._shop.visible])
			"buy":
				var before: int = _s.sim.lv.sprout
				_s._on_tile("sprout")
				print("bought sprout: %d -> %d, energy %d" % [before, _s.sim.lv.sprout, _s.sim.energy])
			"tutor":
				_s.tutor.show()
			"page":
				_s.get_node("HowToPlay")._show_page(int(step[2]))
			"leave":
				_s.get_node("HowToPlay")._continue()
				_s.go_back()
			"quit":
				print("back on tab: %s, grove gone: %s" % [_menu._tab, _menu.get_node_or_null("Grove") == null or _menu.get_node("Grove").is_queued_for_deletion()])
				_finish()
				return true
	return false
