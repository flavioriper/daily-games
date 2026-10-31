extends SceneTree

## The power table, staged one token at a time so each can be seen:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_hockey_powers.gd -- <outdir>
##
## Shots `token_<name>` (the token lying) and `<name>` (taken) for twin, big,
## wide, slow and gold. Puts user://versus.cfg back.

const Sim = preload("res://versus/hockey_sim.gd")

var _screen: Control
var _out := "/tmp"
var _t := 0.0
var _step := 0
var _cfg := ""
var _had := false

func _initialize() -> void:
	_had = FileAccess.file_exists("user://versus.cfg")
	if _had:
		_cfg = FileAccess.get_file_as_string("user://versus.cfg")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_screen = load("res://versus/hockey_screen.gd").new(1)
	root.add_child(_screen)

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/hkp_%s.png" % [_out, name])
	print("%s draws=%d" % [name, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

func _process(delta: float) -> bool:
	_t += delta
	var sim: RefCounted = _screen.sim
	if _t < 0.5:
		return false
	_t = 0.0
	var kinds := [Sim.TWIN, Sim.BIG, Sim.WIDE, Sim.SLOW, Sim.GOLD]
	var names := ["twin", "big", "wide", "slow", "gold"]
	var at := _step / 3
	if at >= kinds.size():
		if _had:
			FileAccess.open("user://versus.cfg", FileAccess.WRITE).store_string(_cfg)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
		quit()
		return true
	match _step % 3:
		0:
			# The token lies, the puck well away from it.
			sim.pick_kind = kinds[at]
			sim.pick_at = Sim.SPOTS[1]
			sim.pick_t = 9.0
			sim.puck = Vector2(0.2, 1.2)
			sim.puck_vel = Vector2.ZERO
		1:
			_shot("token_%s" % names[at])
			sim.last_touch = 0
			sim.puck = sim.pick_at + Vector2(0.0, 0.02)
		2:
			_shot(names[at])
	_step += 1
	return false
