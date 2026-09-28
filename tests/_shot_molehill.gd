extends SceneTree

## The Arcade tab and a game of Molehill, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_molehill.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 the ready banner, 3 play with a bot whacking, 4 the
## whole cast up at once (forced), 5 a real click through the viewport on a
## mole (printed: whether the sim counted it), 6 the frenzy, 7 the end
## card. Prints the draw calls at each shot. The end writes a score to
## user://arcade.cfg, so the file this machine had is put back.

const Sim = preload("res://arcade/molehill_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _busy := 0.0
const PATH := "user://arcade.cfg"

func _initialize() -> void:
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.has("reduce"):
		load("res://core/motion.gd").reduce = true
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
	root.get_texture().get_image().save_png("%s/mh_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d score=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_s.sim.score if _s != null else 0])

## Whacks the oldest mole up, never the rabbit, a finger's pace.
func _bot(delta: float) -> void:
	_busy -= delta
	if _busy > 0.0:
		return
	var sim = _s.sim
	for i in Sim.HILLS:
		var h: Dictionary = sim.hills[i]
		if (h.st == Sim.St.UP) and not h.done and h.kind != Sim.Kind.BUNNY and h.t > 0.25:
			_s.tap(Sim.hill_pos(i) + Vector2(0, -30))
			_busy = 0.2
			return

func _force(i: int, kind: int, st: int, hp := 1, done := false) -> void:
	var h: Dictionary = _s.sim.hills[i]
	h.kind = kind
	h.st = st
	h.t = 0.2
	h.up = 99.0
	h.hp = hp
	h.done = done

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
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				_menu._open_arcade("molehill")
				_s = _menu.get_node("Molehill")
				_step = 2
		2:
			if _t > 2.4:
				_shot("2_ready")
				_step = 3
		3:
			_bot(delta)
			if _t > 14.0:
				_shot("3_play")
				_step = 4
		4:
			# the cast, forced up and held
			for i in Sim.HILLS:
				_s.sim.hills[i].st = Sim.St.EMPTY
				_s.sim.hills[i].rest = 99.0
			_force(0, Sim.Kind.MOLE, Sim.St.UP)
			_force(1, Sim.Kind.GOLD, Sim.St.UP)
			_force(2, Sim.Kind.POT, Sim.St.UP, 2)
			_force(4, Sim.Kind.POT, Sim.St.UP, 1)
			_force(5, Sim.Kind.BUNNY, Sim.St.UP)
			_force(6, Sim.Kind.MOLE, Sim.St.BONKED, 1, true)
			_force(8, Sim.Kind.BUNNY, Sim.St.BONKED, 1, true)
			_force(9, Sim.Kind.MOLE, Sim.St.RISE)
			_s.sim.hills[9].t = 0.07
			_force(10, Sim.Kind.MOLE, Sim.St.UP)
			_s.sim.hills[10].t = 50.0
			_force(11, Sim.Kind.GOLD, Sim.St.BONKED, 1, true)
			_s.sim.streak = 14
			_at = _t
			_step = 5
		5:
			for i in Sim.HILLS:
				var h: Dictionary = _s.sim.hills[i]
				h.t = minf(h.t, 60.0)
				if h.st == Sim.St.BONKED:
					h.t = 0.2
			if _t > _at + 0.3:
				_shot("4_cast")
				# a real click, through the viewport, on hill 0's mole
				var f: Control = _s.field
				var local: Vector2 = _s.px(Sim.hill_pos(0) + Vector2(0, -30))
				var at: Vector2 = f.get_global_transform_with_canvas() * local
				var before: int = _s.sim.whacked
				for pressed in [true, false]:
					var ev := InputEventMouseButton.new()
					ev.button_index = MOUSE_BUTTON_LEFT
					ev.pressed = pressed
					ev.position = at
					ev.global_position = at
					Input.parse_input_event(ev)
				_at = _t
				_step = 6
				set_meta("before", before)
		6:
			if _t > _at + 0.06:
				print("click whacked: ", _s.sim.whacked > int(get_meta("before")))
				_shot("5_click")
				for i in Sim.HILLS:
					_s.sim.hills[i].rest = 0.0
					if _s.sim.hills[i].st == Sim.St.UP:
						_s.sim.hills[i].up = 0.6
				# jump to the frenzy
				_s.sim.t = Sim.ROUND - Sim.FRENZY - 0.5
				_at = _t
				_step = 7
		7:
			_bot(delta)
			if _t > _at + 3.0:
				_shot("6_frenzy")
				_step = 8
		8:
			_bot(delta)
			if _s.sim.is_over() and _s._end != null and _t > _at + 14.5:
				_shot("7_end")
				_step = 9
				_at = _t
		9:
			if _t > _at + 0.5:
				if _had:
					var f := FileAccess.open(PATH, FileAccess.WRITE)
					f.store_string(_before)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
				return true
	return false
