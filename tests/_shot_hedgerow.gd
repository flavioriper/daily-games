extends SceneTree

## The Arcade tab and a game of Hedgerow TD, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_hedgerow.gd -- <outdir>
##
## 1 the Arcade tab, 2 the element pick, 3 a bare cell's build panel, 4 a
## wave walking the maze under fire, 5 a tower's panel, 6 a boss wave,
## 7 the end card. Prints the draw calls at each shot. The end writes a
## score to user://arcade.cfg, so the file this machine had is put back.

const Sim = preload("res://arcade/hedgerow_sim.gd")
const PATH := "user://arcade.cfg"

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _before := ""
var _had := false

func _initialize() -> void:
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/hr_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

## Towers on the grass round the path's bends, element towers mixed in.
func _maze(sim) -> void:
	var spots := [Vector2i(2, 2), Vector2i(2, 5), Vector2i(2, 8), Vector2i(4, 5), Vector2i(4, 6), Vector2i(6, 3),
		Vector2i(6, 6), Vector2i(6, 9), Vector2i(3, 9), Vector2i(5, 9), Vector2i(8, 4), Vector2i(0, 8)]
	var keys := ["thorn", "sun", "acorn", "rain", "thorn", "ember"]
	for i in spots.size():
		var key: String = keys[i % keys.size()]
		if not sim.can_build(key):
			key = "thorn"
		sim.build(spots[i], key)

func _process(delta: float) -> bool:
	_t += delta
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				_menu._open_arcade("hedgerow")
				_s = _menu.get_node("Hedgerow")
				_step = 2
		2:
			if _t > 3.2:
				_shot("2_pick")
				_s._on_pick(Sim.El.SUN)
				var sim = _s.sim
				sim.picked.append(Sim.El.RAIN)
				sim.picked.append(Sim.El.EMBER)
				sim.picked.append(Sim.El.LEAF)
				sim.gold = 6000
				_maze(sim)
				for tw: Dictionary in sim.towers.duplicate():
					if tw.key == "sun" and tw.cell.x % 2 == 0:
						sim.fuse(tw, "lightning")
					elif tw.key == "rain":
						sim.upgrade(tw)
				_s._play_events()
				# the panel's own chips: plant, upgrade, fuse and sell by pressing them
				_s._tap(Vector2i(0, 10))
				_press("Build_sun")
				print("check armed, not planted: ", not sim.at.has(Vector2i(0, 10)) and _s._armed == "sun")
				_press("Build_sun")
				print("check build: ", sim.at.has(Vector2i(0, 10)))
				_s._tap(Vector2i(2, 10))
				_s._tap(Vector2i(0, 10))
				_press("Aim")
				print("check aim: ", sim.at[Vector2i(0, 10)].aim == Sim.Aim.LAST)
				_press("Upgrade")
				print("check upgrade: ", sim.at[Vector2i(0, 10)].level == 1)
				_press("Fuse_frost")
				print("check fuse: ", sim.at[Vector2i(0, 10)].key == "frost")
				_press("Sell")
				print("check sell: ", not sim.at.has(Vector2i(0, 10)))
				_s._tap(Vector2i(1, 4))
				print("check path refused: ", _s._panel_box.find_child("Build_thorn", true, false) == null)
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = true
				ev.position = _s.px(Sim.centre(Vector2i(6, 10)))
				_s._on_field_input(ev)
				print("check tap maps to cell: ", _s._sel == Vector2i(6, 10))
				_s._select(Vector2i(8, 2))
				_press("Build_rain")
				_step = 3
		3:
			if _t > 4.2:
				_shot("3_cell")
				_s._select(Vector2i(-1, -1))
				_s.sim.wave = 5
				_s.sim.gold = 400
				_s._on_send()
				_s._speed = 2
				_step = 4
		4:
			if _t > 8.0:
				_shot("4_wave")
				for tw: Dictionary in _s.sim.towers:
					if tw.key == "lightning":
						_s._select(tw.cell)
						break
				_step = 5
		5:
			if _t > 8.8:
				_shot("5_tower")
				_s._select(Vector2i(-1, -1))
				_s.sim.creeps.clear()
				_s.sim._spawns.clear()
				_s.sim.phase = Sim.Phase.BUILD
				_s.sim.wave = 9
				_s.sim.pick_pending = false
				# only the plain towers stay, so the boss gets well along the path
				for tw: Dictionary in _s.sim.towers.duplicate():
					if not Sim.BASIC.has(tw.key):
						_s.sim.sell(tw)
				_s._play_events()
				_s._on_send()
				_step = 6
		6:
			if _t > 18.0:
				_shot("6_boss")
				_s.sim.lives = 0
				_s.sim.phase = Sim.Phase.OVER
				_s._finish(false)
				_step = 7
		7:
			if _t > 21.5:
				_shot("7_end")
				_restore()
				return true
	return false

func _press(nm: String) -> void:
	var b: Button = _s._panel_box.find_child(nm, true, false)
	if b == null:
		print("check: no ", nm)
		return
	b.pressed.emit()

func _restore() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
