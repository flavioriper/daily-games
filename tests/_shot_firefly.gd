extends SceneTree

## The Arcade tab and a game of Firefly, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_firefly.gd -- <outdir>
##
## 1 the Arcade tab, 2 the stage banner, 3 the swarm flying in, 4 the swarm
## in its rows, 5 a moth's beam, 6 a pair of fireflies, 7 the flyby,
## 8 the end card. Prints the draw calls at each shot. The end writes a
## score to user://arcade.cfg, so the file this machine had is put back.

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
const PATH := "user://arcade.cfg"

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
	root.get_texture().get_image().save_png("%s/ff_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

## Keeps the firefly alive and shooting, under the lowest bug.
func _bot() -> void:
	var sim = _s.sim
	_s._mouse = true
	var aim: float = sim.px
	var best := -1.0
	for e: Dictionary in sim.enemies:
		if e.st != 0 and e.pos.y > best and e.pos.y < sim.PLAYER_Y - 30.0:
			best = e.pos.y
			aim = e.pos.x
	sim.target_x = aim

func _process(delta: float) -> bool:
	_t += delta
	var Sim = load("res://arcade/firefly_sim.gd")
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				_menu._open_arcade("firefly")
				_s = _menu.get_node("Firefly")
				_step = 2
		2:
			if _t > 2.6:
				_shot("2_banner")
				_step = 3
		3:
			if _t > 6.5:
				_shot("3_entering")
				_step = 4
		4:
			# no shooting: let the swarm settle into its rows
			if _t > 22.0:
				_shot("4_rows")
				_s.sim.ships = 5
				var moth := {}
				for e: Dictionary in _s.sim.enemies:
					if e.kind == Sim.Kind.MOTH and e.st == Sim.St.FORM:
						moth = e
				if not moth.is_empty():
					_s.sim._dive_beam(moth)
				_step = 5
		5:
			for e: Dictionary in _s.sim.enemies:
				if e.st == Sim.St.BEAM and e.beam >= 1.0 and _step == 5:
					_shot("5_beam")
					_step = 6
					_at = _t
			if _t > 40.0:
				_shot("5_no_beam")
				_step = 6
				_at = _t
		6:
			if _t > _at + 3.0:
				# a pair, forced
				_s.sim.pair = true
				_s.sim.ship = Sim.Ship.ALIVE
				_bot()
				if _t > _at + 5.0:
					_shot("6_pair")
					_step = 7
		7:
			_bot()
			if _s.sim.challenge() and _s.sim.phase == Sim.Phase.PLAY and _s.sim.phase_t > 5.0:
				_shot("7_flyby")
				_step = 8
			elif _s.sim.stage < 3 and _t > _at + 60.0:
				_shot("7_timeout")
				print("stage ", _s.sim.stage, " enemies ", _s.sim.enemies.size())
				_step = 8
			elif _s.sim.stage < 3:
				# hurry: clear the stage
				for e: Dictionary in _s.sim.enemies:
					if e.st == Sim.St.FORM:
						e.hp = 1
		8:
			_s._mouse = false
			_s.sim.ships = 1
			_s.sim.ship = Sim.Ship.ALIVE
			_s.sim._ship_hit(0)
			_step = 9
			_at = _t
		9:
			if _t > _at + 3.0:
				_shot("8_end")
				print("score ", _s.sim.score, " stage ", _s.sim.stage)
				if _had:
					var f := FileAccess.open(PATH, FileAccess.WRITE)
					f.store_string(_before)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
				quit()
	return false
