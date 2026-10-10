extends SceneTree

## The Arcade tab and a run of Eddy, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_eddy.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab, 2 the hint before the pad is leaned, then a real touch
## held on the pad and dragged through the viewport (printed: whether the
## whirlpool set off and the knob followed), 3 a bot at play, 4 a level made (the growing is set one short of
## the level that takes ducks), 5 a grown whirlpool with toys going down,
## 6 the spin low, 7 the end card. Prints the draw calls at each shot. The
## end writes a score to user://arcade.cfg, so the file this machine had is
## put back.

const Sim = preload("res://arcade/eddy_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _play := false
var _from := Vector2.ZERO
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
		elif a in ["en", "pt", "es"]:
			# the language for this run only: Locale.set_current would write it
			# to this Mac's settings
			load("res://core/locale.gd")._current = a
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
	root.get_texture().get_image().save_png("%s/ed_%s.png" % [_out, name])
	var sim = _s.sim if _s != null else null
	print("shot %s at %.1f draws=%d score=%d level=%d things=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.score if sim != null else 0, sim.level if sim != null else 0, sim.things.size() if sim != null else 0])

## Leans the knob toward the nearest thing the mouth takes, less the nearer.
func _bot() -> void:
	var sim = _s.sim
	if sim == null or sim.phase != Sim.Phase.PLAY or not _play:
		return
	var best := {}
	var best_w := -INF
	for th: Dictionary in sim.things:
		if float(th.sink) >= 0.0 or Sim.grip_of(th.kind, sim.level) < 1.0:
			continue
		var w: float = float(Sim.KINDS[th.kind].value) * 6.0 - float(th.pos.distance_to(sim.pos))
		if w > best_w:
			best_w = w
			best = th
	_s._held = -3
	if best.is_empty():
		_s._knob = Vector2.ZERO
		return
	var d: Vector2 = best.pos - sim.pos
	_s._knob = d.normalized() * clampf(d.length() / 45.0, 0.0, 1.0) * _s.TRAVEL

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

func _touch(pressed: bool, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = at
	Input.parse_input_event(ev)

func _restore() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func _process(delta: float) -> bool:
	_t += delta
	_skip_gold()
	# the window losing focus pauses the game; the harness plays on
	if _s != null and _s._paused and _s._end == null:
		_s._pause(false)
	_bot() if _s != null else null
	if _t > 120.0:
		print("gave up at step %d" % _step)
		_restore()
		return true
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				_menu._open_arcade("eddy")
				_s = _menu.get_node("Eddy")
				_step = 2
		2:
			if _t > 2.6:
				_shot("2_ready")
				# a real touch held on the pad, through the viewport, right of its middle
				var p: Control = _s.pad
				_from = _s.sim.pos
				_touch(true, root.get_final_transform() * (p.get_global_transform_with_canvas() * (p.size * 0.5 + Vector2(60, 0))))
				_at = _t
				_step = 3
		3:
			if _t > _at + 0.5:
				print("touch set off: ", _s.sim.phase == Sim.Phase.PLAY, " moved ", _s.sim.pos - _from, " field ", _s.field.size, " tall ", _s.sim.h)
				var p: Control = _s.pad
				# and the finger dragged up, as a thumb does all run long
				var was: Vector2 = _s._knob
				var drag := InputEventScreenDrag.new()
				drag.index = 0
				drag.position = root.get_final_transform() * (p.get_global_transform_with_canvas() * (p.size * 0.5 + Vector2(0, -60)))
				drag.relative = Vector2(-60, -60)
				Input.parse_input_event(drag)
				Input.flush_buffered_events()
				print("drag moved the knob: ", was, " -> ", _s._knob)
				_touch(false, root.get_final_transform() * (p.get_global_transform_with_canvas() * (p.size * 0.5 + Vector2(60, 0))))
				_play = true
				_step = 4
		4:
			if _s.sim.score >= 5:
				# mid-swallow if it can be had
				for th: Dictionary in _s.sim.things:
					if float(th.sink) > 0.3:
						_shot("3_play")
						_s.sim.level = Sim.level_for(Sim.Kind.DUCK) - 1
						_s.sim.grown = _s.sim.need() - 1
						_step = 5
						break
		5:
			if _s.sim.level >= Sim.level_for(Sim.Kind.DUCK):
				_at = _t
				_step = 6
		6:
			if _t > _at + 0.4:
				_shot("4_level")
				_s.sim.level = 8
				_step = 7
		7:
			for th: Dictionary in _s.sim.things:
				if float(th.sink) > 0.5 and int(Sim.KINDS[th.kind].tier) == 2:
					_shot("5_grown")
					_s.sim.spin = _s.sim.spin_full * Sim.LOW + 0.3
					_at = _t
					_step = 8
					break
		8:
			if _t > _at + 0.8:
				_shot("6_low")
				_s.sim.spin = 0.6
				_step = 9
		9:
			if _s._end != null:
				_at = _t
				_step = 10
		10:
			if _t > _at + 2.4:
				_shot("7_end")
				_restore()
				return true
	return false
