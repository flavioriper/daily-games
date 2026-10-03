extends SceneTree

## Trestle through the real menu and flat host, shot at fixed moments:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_trestle.gd -- <outdir> [d=<level>] [fail] [reduce] [seed=<n>]
##
## 1 the empty gap, 2 the day's proof built (a member being dragged), 3 the
## cart halfway over, 4 the win. With `fail` only the road is built: 3 is the
## collapse and 4 the drawing board after it, the snapped members in red.
## Prints the draw calls and the mean frame time over the second before
## each shot. Solves go to a throwaway progress file, never this Mac's save.
## A solve adds 5, the party. `out` (Hard or Insane) builds only the road
## and presses Go until the hearts run out: 4 is the card.

var _menu: Node
var _host: Node
var _b: Node
var _out := "/tmp"
var _level := 0
var _fail := false
var _reduce := false
var _t := 0.0
var _step := 0
var _at := 0.0
var _frames: Array = []
var _done_at := -1.0
var _out_mode := false
var _spill := false

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progress_trestle_shot.cfg"))
	load("res://core/progress.gd").path = "user://progress_trestle_shot.cfg"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for a: String in args:
		if a.begins_with("d="):
			_level = int(a.substr(2))
		elif a == "fail":
			_fail = true
		elif a == "spill":
			_fail = true
			_spill = true
		elif a == "out":
			_fail = true
			_out_mode = true
		elif a == "reduce":
			_reduce = true
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/tr_%s.png" % [_out, name])
	var mean := 0.0
	for f: float in _frames:
		mean += f
	mean /= maxf(1.0, _frames.size())
	print("shot %s at %.1f draws=%d mean=%.2fms cost=%d/%d cart=%d t=%.2f broken=%d" % [name, _t,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), mean * 1000.0,
		_b.state.cost(), _b.state.budget, _b.sim.cart, _b.sim.t, _b.sim.broken.size()])

func _process(delta: float) -> bool:
	_t += delta
	_frames.append(delta)
	if _frames.size() > 120:
		_frames.pop_front()
	match _step:
		0:
			if _t > 0.8:
				if _reduce:
					load("res://core/motion.gd").reduce = true
				var entry: Dictionary = load("res://ui/registry.gd").find("trestle")
				_menu._open_at(entry, _level)
				_host = _menu.get_child(_menu.get_child_count() - 1)
				_b = _host._puzzle
				if _host.has_node("HowToPlay"):
					_host.get_node("HowToPlay").free()
					_host._hold_clock(false)
				_step = 1
		1:
			if _t > 2.4:
				_shot("1_empty")
				var lv: Dictionary = _b.state.level
				print("level w %d dy %d cart %.1f budget %d proof %d anchors %s rock %s" % [lv.w, lv.dy, lv.cart,
					lv.budget, lv.proof_cost, lv.anchors, lv.get("rock")])
				# `spill` (a Tea Party): a strong truss under the deck alone, laid
				# past the budget -- it holds, but it bends enough to spill
				var lay: Array = _b.state.proof
				if _spill:
					_b.state.free = true
					var G = load("res://puzzles/trestle_gen.gd")
					var S = load("res://puzzles/trestle_sim.gd")
					for shape in [[1, 0, 1], [1, 0, 2], [1, 0, 0], [2, 0, 1], [2, 0, 2], [0, 1, 0]]:
						var cand: Array = G.full(lv, shape[0], shape[1], shape[2])
						var sim = S.new()
						sim.setup(lv, cand)
						while not sim.done():
							sim.step()
						if sim.spilled and sim.broken.is_empty():
							lay = cand
							print("spill shape %s" % [shape])
							break
				for p in lay:
					if _fail and not _spill and p.m != 0:
						continue
					_b._mat = p.m
					_b._lay(p.a, p.b)
				# a member under the finger, for the ghost
				_b._mat = 1
				_b.state.free = false
				_b._from = Vector2i(0, 0)
				_b._to = Vector2i(1, 1)
				_b._dragging = true
				_b._pressing = true
				_at = _t
				_step = 2
		2:
			if _t > _at + 1.2:
				_shot("2_built")
				_b._dragging = false
				_b._pressing = false
				_b._from = _b.NONE
				_b._sel = _b.NONE
				_host._on_check()
				_at = _t
				_step = 3
		3:
			var mid: bool = _b.sim.cart == _b.Sim.CART_ROAD and _b.sim.cart_pos.x > float(_b.state.level.w) * 0.45
			if (not _fail and mid) or (_fail and _t > _at + 2.6):
				_shot("3_test")
				_at = _t
				_step = 4
			elif _t > _at + 20.0:
				_shot("3_timeout")
				quit()
		4:
			if _b.is_done() and _done_at < 0.0:
				_done_at = _t
			if _out_mode:
				if _b.out_of_hearts and _t > _at + 6.0:
					_shot("4_out")
					_b.try_again()
					_at = _t
					_step = 6
				elif not _b._testing and not _b.out_of_hearts and _t > _at + 3.2:
					_host._on_check()
					_at = _t
			elif (not _fail and _done_at >= 0.0 and _t > _done_at + 0.7) or (_fail and not _b._testing and _t > _at + 3.2):
				_shot("4_end")
				if _fail:
					quit()
				_step = 5
			elif _t > _at + 20.0:
				_shot("4_timeout")
				quit()
		6:
			if _t > _at + 1.5:
				_shot("5_try")
				print("after try again: hearts %d/%d out %s design %d sketch %d tests %d modulate %s" % [_b.hearts,
					_b.max_hearts, _b.out_of_hearts, _b.state.design.size(), _b._sketch.size(), _b._tests, _b.modulate])
				quit()
		5:
			if _t > _done_at + 3.1:
				_shot("5_party")
				quit()
	return false
