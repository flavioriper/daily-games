extends SceneTree

## The Arcade tab and Furrow, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_furrow.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab, 2 a new field with its first radishes ripe, then a real
## touch on one through the viewport (printed: whether it was picked),
## 3 a grown field of mixed crops at every stage with a golden one, 4 the
## whole field ripe and a real finger dragged along its first row (printed:
## the chain), 5 the rest picked: the clean sweep, 6 the chain's end, 7 a
## packet in hand and a row sown, 8 a signboard pressed without the seeds,
## 9 the shed, 10 a level of each upgrade bought. Prints the draw calls at
## each shot. The field is kept in a file of the harness's own
## (`Sim.path`), so this machine's field is never touched.

const Sim = preload("res://arcade/furrow_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	Sim.path = "user://_shot_furrow.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sim.path))
	for a: String in OS.get_cmdline_user_args():
		if a == "reduce":
			load("res://core/motion.gd").reduce = true
		elif a in ["en", "pt", "es"]:
			load("res://core/locale.gd")._current = a
		else:
			_out = a
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
	root.get_texture().get_image().save_png("%s/fw_%s.png" % [_out, name])
	var sim = _s.sim if _s != null else null
	print("shot %s at %.1f draws=%d seeds=%d chain=%d ripe=%d/%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.seeds if sim != null else 0, sim.chain if sim != null else 0, sim.ripe_count() if sim != null else 0, sim.opened() if sim != null else 0])

func _point(i: int) -> Vector2:
	var f: Control = _s.field
	return root.get_final_transform() * (f.get_global_transform_with_canvas() * f.plant_at(i))

func _touch(pressed: bool, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = at
	Input.parse_input_event(ev)

func _drag(from: Vector2, to: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = to
	ev.relative = to - from
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _ripen(gold := -1) -> void:
	for i in _s.sim.plots.size():
		var p: Dictionary = _s.sim.plots[i]
		if p.open:
			p.t = _s.sim.grow_time(p.crop)
			p.ripe = true
			p.gold = i == gold

func _done() -> bool:
	# the window closing is a focus lost, and that saves: not after this
	Sim.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_furrow.cfg"))
	return true

func _process(delta: float) -> bool:
	_t += delta
	if _t > 120.0:
		print("gave up at step %d" % _step)
		return _done()
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				_menu._open_arcade("furrow")
				_s = _menu.get_node("Furrow")
				_step = 2
		2:
			if _t > 2.8:
				_ripen()
				_at = _t
				_step = 3
		3:
			if _t > _at + 0.6:
				_shot("2_new")
				var i: int = _s.sim.order[0]
				_touch(true, _point(i))
				_touch(false, _point(i))
				Input.flush_buffered_events()
				print("a real touch picked a radish: ", _s.sim.seeds == 1)
				# a grown field: twelve plots, five crops, every stage
				var sim = _s.sim
				sim.crops = 5
				sim.seeds = 340
				for k in 12:
					var p: Dictionary = sim.plots[sim.order[k]]
					p.open = true
					p.crop = k % 5
					p.t = sim.grow_time(p.crop) * [0.05, 0.3, 0.7, 1.0][k % 4]
					p.ripe = k % 4 == 3
					p.gold = k == 7
				_s.field.lay(sim)
				_at = _t
				_step = 4
		4:
			if _t > _at + 0.8:
				_shot("3_grown")
				var sim = _s.sim
				sim.crops = Sim.CROPS.size()
				for k in sim.plots.size():
					var p: Dictionary = sim.plots[k]
					p.open = true
					p.crop = k % Sim.CROPS.size()
				_ripen(9)
				_s.field.lay(sim)
				_at = _t
				_step = 5
		5:
			if _t > _at + 0.6:
				_shot("4_ripe")
				var f: Control = _s.field
				_touch(true, _point(f.place(0)))
				_drag(_point(f.place(0)), _point(f.place(2)))
				print("a real drag picked the first row: chain ", _s.sim.chain)
				_at = _t
				_step = 6
		6:
			if _t > _at + 0.25:
				_shot("4b_chain")
				var f: Control = _s.field
				_drag(_point(f.place(2)), _point(f.place(4)))
				_drag(_point(f.place(4)), _point(f.place(3)))
				_at = _t
				_step = 7
		7:
			if _t > _at + 0.2:
				for i in 20:
					_s.field.poke(i, false)
				_touch(false, _point(19))
				_at = _t
				_step = 8
		8:
			if _t > _at + 0.45:
				_shot("5_sweep")
				_step = 9
		9:
			if _s.sim.chain == 0 and _t > _at + Sim.WINDOW + 0.5:
				_shot("6_tally")
				_s.press_slot(4)
				_at = _t
				_step = 10
		10:
			if _t > _at + 0.2:
				for i in 4:
					_s.field.poke(i, i == 0)
				_at = _t
				_step = 11
		11:
			if _t > _at + 0.5:
				_shot("7_sow")
				_s.press_slot(4)
				_s.sim.plots[19].open = false
				_s.sim.seeds = 12
				_s.field.lay(_s.sim)
				_at = _t
				_step = 12
		12:
			if _t > _at + 0.3:
				_s.field.poke(19, true)
				_at = _t
				_step = 13
		13:
			if _t > _at + 0.3:
				_shot("8_short")
				_s.sim.seeds = 5000
				_s.press_slot(0)
				_at = _t
				_step = 14
		14:
			if _t > _at + 0.8:
				_shot("9_shed")
				for id: String in Sim.UPS:
					_s.get_node("Shop").buy(id)
				_at = _t
				_step = 15
		15:
			if _t > _at + 0.6:
				_shot("10_bought")
				print("levels: ", _s.sim.lv, " seeds ", _s.sim.seeds)
				return _done()
	return false
