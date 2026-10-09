extends SceneTree

## The Arcade tab and a run of Beeline, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_beeline.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 the hint before the first beat, then a real touch
## through the viewport (printed: whether the sim took off), 3 a bot flying,
## 4 the tenth gap's ribbon (the score is set to nine), 5 a hedge met, 6 the
## end card, 7 a run with the dewdrop round her, 8 the drop burst on the
## lawn. Prints the draw calls at each shot. The end writes a score to
## user://arcade.cfg, so the file this machine had is put back.

const Sim = preload("res://arcade/beeline_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _fly := false
const PATH := "user://arcade.cfg"

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and eat the taps.
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	for a: String in OS.get_cmdline_user_args():
		if a == "reduce":
			load("res://core/motion.gd").reduce = true
		else:
			_out = a
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/bl_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d score=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_s.sim.score if _s != null and _s.sim != null else 0])

## Beats when she sinks under a line near the next gap's foot.
func _bot() -> void:
	var sim = _s.sim
	if sim == null or sim.phase != Sim.Phase.PLAY or not _fly:
		return
	var g: Dictionary = sim.next_gate()
	if sim.y > float(g.cy) + float(g.gap) * 0.5 - Sim.R - 14.0 and sim.v > 0.0:
		_s.beat()

## A fresh wallet holds boosters, so the boost card stands before every run
## and Second chance before every end card: play with none, and decline.
func _skip_gold() -> void:
	if _s == null:
		return
	var boost: Node = _s.get_node_or_null("BoostCard")
	if boost != null and not boost.is_queued_for_deletion():
		boost._on_play()
	var chance: Node = _s.get_node_or_null("SecondChance")
	if chance != null and not chance.is_queued_for_deletion():
		chance._on_no()

func _process(delta: float) -> bool:
	_t += delta
	_skip_gold()
	# the window losing focus pauses the game; the harness plays on
	if _s != null and _s._paused and _s._end == null:
		_s._pause(false)
	_bot() if _s != null else null
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				_menu._open_arcade("beeline")
				_s = _menu.get_node("Beeline")
				_step = 2
		2:
			if _t > 2.6:
				_shot("2_ready")
				# a real touch, through the viewport, in the middle of the garden
				var f: Control = _s.field
				var at: Vector2 = root.get_final_transform() * (f.get_global_transform_with_canvas() * (f.size * 0.5))
				for pressed in [true, false]:
					var ev := InputEventScreenTouch.new()
					ev.index = 0
					ev.pressed = pressed
					ev.position = at
					Input.parse_input_event(ev)
				_at = _t
				_step = 3
		3:
			if _t > _at + 0.1:
				print("touch took off: ", _s.sim.phase == Sim.Phase.PLAY, " flaps ", _s.sim.flaps)
				_fly = true
				_step = 4
		4:
			if _s.sim.score >= 3 and _t > _at + 0.4:
				_shot("3_play")
				_s.sim.score = Sim.RIBBONS[0] - 1
				_step = 5
		5:
			if _s.sim.ribbons >= 1:
				_at = _t
				_step = 6
		6:
			if _t > _at + 0.35:
				_shot("4_ribbon")
				_fly = false
				_step = 7
		7:
			if _s.sim.phase == Sim.Phase.FALL or _s.sim.phase == Sim.Phase.OVER:
				_at = _t
				_step = 8
		8:
			if _t > _at + 0.12:
				_shot("5_bump")
				_step = 9
		9:
			if _s._end != null:
				_at = _t
				_step = 10
		10:
			if _t > _at + 2.2:
				_shot("6_end")
				_s._end.queue_free()
				_s._end = null
				_s._boosts = ["bl_dew"]
				_s._new_game()
				_at = _t
				_step = 11
		11:
			if _t > _at + 0.5:
				_shot("7_dew")
				_s.beat()
				_step = 12
		12:
			if _s.sim.ghost > 0.0:
				_at = _t
				_step = 13
		13:
			if _t > _at + 0.15:
				_shot("8_burst")
				_step = 14
				_at = _t
		14:
			if _t > _at + 0.3:
				if _had:
					var f := FileAccess.open(PATH, FileAccess.WRITE)
					f.store_string(_before)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
				return true
	return false
