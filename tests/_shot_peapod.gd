extends SceneTree

## The Arcade tab and a game of Peapod, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_peapod.gd -- <outdir> [reduce]
##
## 1 the Arcade tab, 2 the ready banner, 3 play with a bot (3a the energy
## out of a crate, and three more frames of it a tenth of a second apart), 3b a wave
## cleared (printed: its stars, the flowers up, whether the pod is crowned
## for the best passed), 3c the shop open on what the wave paid, 3d a card
## bought, 3e a gift crate broken and its gift flying to its button on the
## rack, 3f the rack with more had (printed: how many of each), 3g its
## button pressed through the viewport and the gift on its way to the pod
## (printed: whether it was kept, and whether the press started it and left
## the cart alone), 3h the pod wearing it, 4 the whole cast in a wall
## (forced: every paint, every gift and pod, the firecracker, the golden and
## iron crates, three peas a volley in a fan of lightning under the frost,
## crates alight and crates broken to each stage, a crit's number), 4b four peas a volley under all three
## shapes and the flame, 5 a real slide through the viewport
## (printed: whether the cart rolled), 6 the millipede, 7 the line neared,
## 8 the end card. Prints the draw calls at each shot. The end writes a
## score to user://arcade.cfg, so the file this machine had is put back on
## every way out.

const Sim = preload("res://arcade/peapod_sim.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _hand := 150.0
var _x0 := 0.0
var _reduce := false
const PATH := "user://arcade.cfg"

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and eat the taps.
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	# and the carts' card would stand before every run
	load("res://arcade/peapod_screen.gd").force_cart = 0
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_reduce = args.has("reduce")
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _restore() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/pp_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d score=%d wave=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_s.sim.score if _s != null and _s.sim != null else 0, _s.sim.wave if _s != null and _s.sim != null else 0])

## Rolls under the lowest crate or the plate furthest along; a shop that
## opens when no shot is wanted of it is shut.
func _bot(delta: float) -> void:
	var sim = _s.sim
	if sim.phase == Sim.Phase.SHOP and _s._shop != null:
		_s._close_shop()
	var want: float = sim.x
	if sim.wave_kind == Sim.Wave.WALL:
		for r in sim.rows.size():
			var found := false
			for c in Sim.COLS:
				if sim.rows[r][c] != null:
					want = (c + 0.5) * Sim.CELL_W
					found = true
					break
			if found:
				break
	elif not sim.segs.is_empty():
		want = Sim.path_at(float(sim.segs[0].s) + 8.0).x
	_hand = move_toward(_hand, want, 300.0 * delta)
	sim.target_x = _hand

func _cell(kind: int, hp: int) -> Dictionary:
	return {"kind": kind, "hp": hp, "max": hp, "id": 9000 + randi() % 9000, "burn_t": 0.0, "burn_c": 0.0, "burn": 0.0, "burn_part": 0.0,
		"sting": 0.0, "sting_t": 0.0, "sting_c": 0.0, "sting_part": 0.0, "brittle": 0.0, "plus": 0, "by": 1, "owed": 0, "gives": 40}

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

func _mouse(pressed: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)

func _process(delta: float) -> bool:
	_t += delta
	if _t > 120.0:
		print("timed out at step ", _step)
		_restore()
		return true
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
				# set right before the screen opens: the menu loads the settings
				# file on its way up and would put it back
				if _reduce:
					load("res://core/motion.gd").reduce = true
				_menu._open_arcade("peapod")
				_s = _menu.get_node("Peapod")
				_step = 2
		2:
			if _t > 2.6:
				_shot("2_ready")
				_step = 3
		3:
			_bot(delta)
			# the energy orbs, some just out of a crate and some on their way in
			if not has_meta("orbs") and _s._orbs.size() >= 7 and _t > 5.0:
				set_meta("orbs", _t)
				_shot("3a_orbs")
				print("orbs in the air=%d, the plate shows %s of %d" % [_s._orbs.size(), _s._energy_l.text, _s.sim.energy / Sim.ORBS])
			# and the same motes three more times, a tenth of a second apart
			for k in [1, 2, 3]:
				if has_meta("orbs") and not has_meta("orbs%d" % k) and _t > float(get_meta("orbs")) + 0.1 * k:
					set_meta("orbs%d" % k, true)
					_shot("3a_orbs_%d" % k)
			if _t > 12.0:
				_shot("3_play")
				# a wave about to be cleared, well off the line, and the best
				# about to be passed by its bonus
				var sim = _s.sim
				sim.wave_kind = Sim.Wave.WALL
				sim.gap_t = 0.0
				sim.segs.clear()
				sim.rows = [[_cell(Sim.Kind.CRATE, 1), null, _cell(Sim.Kind.CRATE, 1), null, null]]
				sim.wall_y = 200.0
				sim.wall_speed = 0.0
				_s._wave_peak = 0.0
				_s._best = sim.score + 3
				_s._beat_best = false
				_at = _t
				_step = 30
		30:
			_bot(delta)
			if not _s._clear.is_empty() and _s._clock - float(_s._clear.at) > 1.05:
				_shot("3b_clear")
				print("stars=%d blooms=%d crowned=%s" % [int(_s._clear.stars), _s._blooms.size(), _s._crown_at >= 0.0])
				# energy for two of the shop's cards and not the rest
				_s.sim.energy = 23 * Sim.ORBS
				_at = _t
				_step = 31
			elif _t > _at + 8.0:
				print("the wave was never cleared")
				_step = 4
		31:
			if _s._shop != null and _t > _at + 1.2:
				_shot("3c_shop")
				var sim = _s.sim
				var before: int = sim.energy
				_s._buy(Sim.Card.DAMAGE)
				print("shop: damage bought=%s energy %d -> %d, next costs %d, speed can be bought=%s" % [sim.power == 2, before / Sim.ORBS, sim.energy / Sim.ORBS,
					sim.price(Sim.Card.DAMAGE) / Sim.ORBS, sim.can_buy(Sim.Card.SPEED)])
				_at = _t
				_step = 32
			elif _t > _at + 6.0:
				print("the shop never opened")
				_step = 4
		32:
			if _t > _at + 0.4:
				_shot("3d_bought")
				_s._close_shop()
				print("shop shut: phase is play=%s" % (_s.sim.phase == Sim.Phase.PLAY))
				# a gift crate over the cart, a pea from breaking
				var sim = _s.sim
				sim.wave_kind = Sim.Wave.WALL
				sim.gap_t = 0.0
				sim._shopped = false
				# and a crate that outlasts it, so the wave stays on for the gift
				sim.rows = [[null, null, null, null, null]]
				var col := clampi(int(sim.x / Sim.CELL_W), 0, Sim.COLS - 1)
				sim.rows[0][col] = _cell(Sim.Kind.FLAME, 1)
				sim.rows[0][(col + 2) % Sim.COLS] = _cell(Sim.Kind.CRATE, 90000)
				sim.stock = [0, 0, 0, 0, 0, 0, 0, 0, 1, 0]
				sim.wall_y = 250.0
				sim.wall_speed = 0.0
				sim.target_x = sim.x
				_at = _t
				_step = 33
		33:
			if _s.sim.has(Sim.Kind.FLAME) > 0 and (_reduce or (not _s._flights.is_empty() and float(_s._flights[0].t) > 0.2)):
				# nothing flies when motion is reduced: the gift is on its button at once
				_shot("3e_gift")
				print("gift kept as its crate broke: stock=%s element=%d caught=%d" % [_s.sim.stock, _s.sim.element, _s.sim.caught])
				_at = _t
				_step = 34
			elif _t > _at + 3.0:
				print("no gift was had")
				_step = 4
		34:
			if _t > _at + 0.8:
				# more had: two Fans and a shove
				_s.sim.stock[Sim.Kind.FAN - Sim.Kind.FAN] = 2
				_s.sim.stock[Sim.Kind.SHOVE - Sim.Kind.FAN] = 1
				_at = _t
				_step = 341
		341:
			if _t > _at + 0.9:
				_shot("3f_held")
				print("the rack counts them: stock=%s" % [_s.sim.stock])
				# a real press on its button, through the viewport
				var f: Control = _s.field
				var from: Vector2 = f.get_global_transform_with_canvas() * _s._rack_px(Sim.Kind.FLAME)
				var win: Vector2 = root.get_final_transform() * from
				_x0 = _s.sim.x
				set_meta("win", win)
				_mouse(true, win)
				_at = _t
				_step = 35
		35:
			if _t > _at + 0.17:
				_mouse(false, get_meta("win"))
				_shot("3g_used")
				print("the press started it: %s (element=%d stock=%s), cart left alone: %s" % [_s.sim.element == Sim.Kind.FLAME, _s.sim.element,
					_s.sim.stock, is_equal_approx(_s.sim.x, _x0) and not _s._mouse])
				_at = _t
				_step = 351
		351:
			if _t > _at + 0.55:
				_shot("3h_worn")
				print("the pod wears it: painted=%d flights=%d" % [_s._pod_el, _s._flights.size()])
				_step = 4
		4:
			# the cast, forced: a wall of every paint and every kind
			var sim = _s.sim
			sim.wave_kind = Sim.Wave.WALL
			sim.gap_t = 0.0
			sim.segs.clear()
			sim.rows.clear()
			var hps := [[2, 5, 9, 14, 30], [45, 90, 150, 260, 500], [800, 1500, 2400, 5200, 12000]]
			for r in 3:
				var row: Array = []
				for c in Sim.COLS:
					row.append(_cell(Sim.Kind.CRATE, hps[r][c]))
				sim.rows.append(row)
			sim.rows.append([_cell(Sim.Kind.GOLD, 77), _cell(Sim.Kind.IRON, 38), _cell(Sim.Kind.CRATE, 1), _cell(Sim.Kind.BOMB, 9), _cell(Sim.Kind.GOLD, 4)])
			sim.rows.append([_cell(Sim.Kind.FAN, 3), _cell(Sim.Kind.PIERCE, 3), _cell(Sim.Kind.BURST, 3), _cell(Sim.Kind.ZAP, 3), _cell(Sim.Kind.FLAME, 3)])
			sim.rows.append([_cell(Sim.Kind.FROST, 3), _cell(Sim.Kind.SHOVE, 3), _cell(Sim.Kind.NETTLE, 3), _cell(Sim.Kind.HAIL, 3), _cell(Sim.Kind.GUST, 3)])
			# the crates that look after others, and a plain one for them to
			sim.rows.append([_cell(Sim.Kind.PLUS, 30), _cell(Sim.Kind.CRATE, 300), _cell(Sim.Kind.TIMES, 30), _cell(Sim.Kind.MEND, 30), _cell(Sim.Kind.WARD, 30)])
			sim.ward = Sim.tier_of(500)
			sim._buffs = true
			sim._aura(true)
			# most of them worn down, to every stage of the break: what each began as
			var began := [[2, 20, 12, 60, 34], [200, 110, 800, 300, 2500], [1100, 7000, 5000, 9000, 14000], [400, 60, 1, 9, 5]]
			for r in began.size():
				for c in Sim.COLS:
					sim.rows[r][c].max = began[r][c]
			for c in [0, 3]:
				sim.rows[1][c].burn_t = 30.0
				sim.rows[1][c].burn_c = 0.3
				sim.rows[1][c].burn = 3
			sim._burning = 30.0
			sim.wall_y = 290.0
			sim.wall_speed = 0.0
			sim.gap_t = 0.0
			sim.shape_t = [6.0, 0.0, 9.0]
			sim.element = Sim.Kind.ZAP
			sim.element_t = 8.0
			sim.frost_t = 4.0
			sim.stock = [2, 0, 1, 3, 1, 2, 1, 4, 12, 0]
			sim.peas = 3
			sim.power = 3
			sim.rate_lv = 4
			sim.crit_lv = 5
			sim.shots.clear()
			sim.target_x = 150.0
			_hand = 150.0
			_at = _t
			_step = 5
		5:
			_s.sim.frost_t = 4.0
			if _t > _at + 0.7:
				_shot("4_cast")
				print("cast: numbers=%d bolts=%d crumbs=%d" % [_s._nums.size(), _s._bolts.size(), _s._crumbs.size()])
				# every dressing at once: four peas a volley, the three shapes, the flame
				_s.sim.peas = 4
				_s.sim.shape_t = [9.0, 9.0, 9.0]
				_s.sim.element = Sim.Kind.FLAME
				_s.sim.element_t = 9.0
				_at = _t
				_step = 51
		51:
			_s.sim.frost_t = 4.0
			if _t > _at + 0.7:
				_shot("4b_dressed")
				# a real slide, through the viewport: press, drag right, let go
				var f: Control = _s.field
				var from: Vector2 = f.get_global_transform_with_canvas() * (f.size * Vector2(0.4, 0.8))
				var win: Vector2 = root.get_final_transform() * from
				_x0 = _s.sim.x
				_mouse(true, win)
				var mv := InputEventMouseMotion.new()
				mv.position = win + Vector2(90, 0)
				mv.global_position = mv.position
				mv.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(mv)
				set_meta("win", win + Vector2(90, 0))
				_at = _t
				_step = 6
		6:
			if _t > _at + 0.3:
				print("slide rolled the cart: %s (%.1f -> %.1f)" % [_s.sim.x > _x0 + 20.0, _x0, _s.sim.x])
				_shot("5_slide")
				_mouse(false, get_meta("win"))
				# on to a millipede
				var sim = _s.sim
				sim.rows.clear()
				sim._shopped = true
				# the gun it began with, or the millipede is gone before its shot
				sim.power = 2
				sim.rate_lv = 0
				sim.crit_lv = 0
				sim.peas = 1
				sim.shape_t = [0.0, 0.0, 0.0]
				sim.element = 0
				sim.element_t = 0.0
				sim.wave = 5
				sim.gap_t = 0.01
				_at = _t
				_step = 7
		7:
			_bot(delta)
			if _t > _at + 7.0 and _s.sim.wave_kind == Sim.Wave.MILLI and not _s.sim.segs.is_empty():
				_shot("6_milli")
				# and its head near the end of the path
				_s.sim.segs[0].s = Sim.path_len() - 150.0 if not _s.sim.segs.is_empty() and _s.sim.segs[0].kind == Sim.Kind.HEAD else 0.0
				_at = _t
				_step = 8
		8:
			_s.sim.target_x = 30.0
			if _t > _at + 2.0:
				_shot("7_near")
				_step = 9
		9:
			_s.sim.target_x = 30.0
			if _s.sim.is_over() and _s._end != null and _t > _at + 3.0:
				_at = _t
				_step = 10
		10:
			if _t > _at + 2.6:
				_shot("8_end")
				_restore()
				return true
	return false
