extends SceneTree

## The Valley tab and the Grove, shot at fixed beats through the real menu:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_grove.gd -- <outdir> [reduce]
##
## 1 the Valley tab, 2 a new grove, 3 the circle on its sapling mid-chop,
## 4 the tree down (4b its motes hanging and its pile lying, 4c the motes on
## their way in), 5 a grove some days in,
## 6 the circle over several trees, 6b the Skills card opened by its button
## with Room chosen and a level of it just bought, j1 stacks of every size
## lying (the last a lucky one), j2 the circle gathering three of them (logs
## in the air), j3 the jetty part full, a bundle waiting and the raft coming
## in, j4 the raft half its way out with a bundle, sw_0 and sw_1 the same
## still chain a second and a half apart (what the wind must not move), j5
## the jetty full and the circle refused (the plate warns), j6 the raft just
## landed off the screen (the wood plate says what it brought), 7w six
## frames of a grove far along, littered, with nothing but the wind on it, 7
## that grove (every look, a land of thirty) under the circle, 7j its jetty
## with a full raft on its way out, 8 the shop's card open and an Axe just
## bought, 9-11 and 13 the tutorial's four pages (10b the pile carried off,
## 13a the circle gathering, 13 a bundle tied and the raft in, 13b the raft
## out with it, 13c the plate when it lands), 12 the tab again. Prints at
## each shot the draw calls, the stacks lying and what the jetty holds, and
## the frames since the last shot with their mean and longest gap. The
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
	[7.9, "let_go"], [7.95, "skills"], [8.2, "skill"], [8.7, "shot", "6b_skills"], [8.75, "skills_x"],
	[8.8, "piles"], [9.3, "shot", "j1_piles"],
	[9.35, "hold_stacks"], [9.63, "shot", "j2_gather"], [9.7, "let_go"],
	[10.4, "part_full"], [10.45, "shot", "j3_part_full"],
	[10.5, "raft_out"], [10.55, "shot", "j4_raft_half"],
	[10.6, "stand_still"], [10.7, "shot", "sw_0"], [12.2, "shot", "sw_1"],
	[12.3, "full"], [12.35, "hold_stacks"], [12.6, "shot", "j5_full"], [12.65, "let_go"],
	[12.68, "landing"], [12.95, "shot", "j6_landed"],
	[13.0, "late"], [13.2, "shot", "7w_0"], [13.5, "shot", "7w_1"], [13.8, "shot", "7w_2"], [14.1, "shot", "7w_3"], [14.4, "shot", "7w_4"], [14.7, "shot", "7w_5"],
	[14.8, "hold_mid"], [15.5, "shot", "7_late"],
	[15.70, "let_go"], [15.72, "late_jetty"], [15.76, "shot", "7j_late_jetty"],
	[15.80, "shop"], [15.85, "buy"], [16.20, "shot", "8_bought"],
	[16.23, "shop_x"], [16.25, "tutor"], [17.75, "shot", "9_tut_chop"],
	[17.85, "page", 1], [20.10, "shot", "10_tut_gifts"], [21.35, "shot", "10b_tut_gifts_carried"],
	[21.40, "page", 2], [24.80, "shot", "11_tut_wait"],
	[24.90, "page", 3], [25.78, "shot", "13a_tut_send_gather"], [28.00, "shot", "13_tut_send"], [29.90, "shot", "13b_tut_send_out"], [31.80, "shot", "13c_tut_send_landed"],
	[31.90, "leave"], [32.80, "shot", "12_tab_after"],
	[32.90, "quit"],
]

## Where the jetty's beats lay their stacks, in land units, each with its
## piles: every way a stack is drawn, the last a lucky one.
const STACKS := [[Vector2(300, 560), 1], [Vector2(420, 640), 2], [Vector2(540, 700), 3], [Vector2(650, 600), 6],
	[Vector2(520, 860), 14], [Vector2(700, 760), 2500], [Vector2(380, 780), 2]]

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
## Frames since a beat last poked the game: a shot waits for two, since a
## shot's own saving can put a poke and the next shot in one frame, and a
## frame poked is drawn on the one after.
var _since_poke := 10

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

## A finger, as a phone sends it: the project has mouse-from-touch off, and
## this harness pressing with a mouse button is how the Grove shipped unable
## to be chopped on a phone (2026-10-06).
func _press(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = at
	_s._on_field_input(ev)

func _preset(lv: Dictionary, energy: int) -> void:
	for tile: String in lv:
		_s.sim.lv[tile] = lv[tile]
	_s.sim.energy = energy
	_s.sim.catch_up(1e6)
	_s._refresh_tiles()

## The jetty's beats set the chain by hand (a harness's preset: no number of
## the game's is changed). STACKS lying, the last of them lucky, all ripe.
func _stacks() -> void:
	var sim: RefCounted = _s.sim
	sim.logs.clear()
	for i in STACKS.size():
		var n: int = STACKS[i][1]
		sim._drop(STACKS[i][0], int(sim.lv.seeds), n * sim.give(int(sim.lv.seeds)), i == STACKS.size() - 1, n).born = sim.clock - Sim.LIES

## `loose` piles and `waiting` whole bundles on the jetty; the raft home
## (`out` under 0), or `out` of its way out with `aboard` bundles, or as far
## from home on its way back with none (`back`).
func _jetty(loose: int, waiting: int, out := -1.0, aboard := 0, back := false) -> void:
	var sim: RefCounted = _s.sim
	var size: int = sim.bundle_size()
	var worth: int = sim.give(int(sim.lv.seeds))
	sim.loose = {"n": loose, "wood": loose * worth}
	sim.bundles.clear()
	for i in waiting:
		sim.bundles.append({"n": size, "wood": size * worth})
	sim.tie_t = 0.0
	sim.raft = {"n": 0, "wood": 0, "bundles": 0, "t": 0.0, "away": false}
	if out >= 0.0:
		var t: float = sim.raft_time() * 0.5 * out
		sim.raft = {"n": 0 if back else aboard * size, "wood": 0 if back else aboard * size * worth, "bundles": 0 if back else aboard,
			"t": sim.raft_time() - t if back else t, "away": true}
	print("jetty set: %d of %d held, %d lying in %d stacks, raft at %.2f" % [sim.jetty_held(), sim.jetty_room(), sim.lying(), sim.logs.size(), sim.raft_at()])

func _process(delta: float) -> bool:
	_t += delta
	_frames += 1
	_gap_sum += delta
	_gap_max = maxf(_gap_max, delta)
	if _t > 60.0:
		_finish()
		return true
	_since_poke += 1
	while _i < STEPS.size() and _t >= float(STEPS[_i][0]):
		var step: Array = STEPS[_i]
		if String(step[1]) == "shot" and _since_poke < 2:
			break
		if String(step[1]) != "shot":
			_since_poke = 0
		_i += 1
		match String(step[1]):
			"shot":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("%s/grove_%s.png" % [_out, step[2]])
				var live: bool = is_instance_valid(_s) and _s.sim != null
				print("shot %s draws=%d trees=%d stacks=%d jetty=%s | since the last shot: %d frames, %.2f ms a frame (longest %.1f)" % [step[2],
					int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
					_s.sim.trees.size() if live else -1, _s.sim.logs.size() if live else -1,
					("%d/%d" % [_s.sim.jetty_held(), _s.sim.jetty_room()]) if live else "-",
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
				# the chain bought out too, and the land littered as a land
				# chopped faster than its raft carries is: a stack wherever one
				# fits, most of them hundreds of piles
				_preset({"axe": 60, "reach": 10, "swing": 12, "sprout": 16, "room": 27, "seeds": 9,
					"raft": 15, "jetty": 20, "bundle": 7, "tying": 15, "load": 3}, 9876543210)
				var sim: RefCounted = _s.sim
				sim.logs.clear()
				var rng := RandomNumberGenerator.new()
				rng.seed = 7
				for i in 400:
					var at := Vector2(rng.randf_range(0.0, Sim.LAND.x), rng.randf_range(0.0, Sim.LAND.y))
					if Sim.stands(at):
						var n := rng.randi_range(1, 6) if i % 3 == 0 else rng.randi_range(40, 4000)
						sim._drop(at, 9, n * sim.give(9), i % 4 == 0, n).born = sim.clock - Sim.LIES
				_jetty(0, 0)
			"late_jetty":
				# more bundles than are drawn, a full raft on its way out
				_jetty(9, 5, 0.5, 4)
			"piles":
				_preset({"jetty": 2}, 37)
				_stacks()
				_jetty(0, 0)
			"hold_stacks":
				_press(_s.px(Vector2(460, 700)), true)
			"part_full":
				# a bundle waiting and the raft a moment from home to take it
				_stacks()
				_jetty(3, 1, 0.18, 0, true)
			"raft_out":
				_jetty(3, 1, 0.5, 1)
			"stand_still":
				# nothing of the chain moves for the next five seconds: the
				# raft is out, the loose piles are short of a bundle; and no
				# mote is left in the air to cross the jetty
				_jetty(3, 1, 0.95, 1)
				_s._motes.clear()
			"landing":
				# the raft a twentieth of a second from the far side
				var sim: RefCounted = _s.sim
				sim.raft.t = sim.raft_time() * 0.5 - 0.05
			"full":
				# a bigger jetty, so more bundles wait than are drawn
				_preset({"jetty": 12}, 37)
				_stacks()
				_jetty(12, 8, 0.4, 1)
			"shop":
				_s._shop_b.pressed.emit()
				print("shop open: %s, badge %d" % [_s._shop.visible, _s._shop_b.badge])
			"shop_x":
				_s._shop.get_node("Center/Card").find_child("Close", true, false).pressed.emit()
				print("shop closed: %s" % [not _s._shop.visible])
			"buy":
				var before: int = _s.sim.lv.axe
				_s._on_tile("axe")
				print("bought axe: %d -> %d, energy %d" % [before, _s.sim.lv.axe, _s.sim.energy])
			"skills":
				_s._skills_b.pressed.emit()
				print("skills open: %s, badge %d" % [_s._tree.is_open(), _s._skills_b.badge])
			"skill":
				var before: int = _s.sim.lv.room
				_s._tree.select("room")
				_s._tree.buy_selected()
				print("bought room on the tree: %d -> %d, energy %d, badge %d" % [before, _s.sim.lv.room, _s.sim.energy, _s._skills_b.badge])
			"skills_x":
				_s._tree.find_child("Close", true, false).pressed.emit()
				print("skills closed: %s" % [not _s._tree.is_open()])
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
