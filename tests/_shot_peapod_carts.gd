extends SceneTree

## Peapod's carts and elements, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_peapod_carts.gd -- <outdir> [pt|es] [reduce]
##
## p1 the carts' card as a player who has reached wave 11 sees it (four
## open, two not), p2 another tile chosen; then a run on each cart in turn
## over a hand-laid wall, each under an element and a shape (c<cart>_a and
## _b, a second apart; printed: the shots in the air, the crates alight,
## stung and brittle, the draw calls); s the shop of the pumpkin's cart, with
## its own card; e the end card and what it says of the next cart. Writes
## user://arcade.cfg for the furthest wave, so the file this machine had is
## put back on every way out.

const Sim = preload("res://arcade/peapod_sim.gd")
const PATH := "user://arcade.cfg"
## What each cart runs under: [element, shape (0: none)].
const DRESS := [[Sim.Kind.NETTLE, 0], [Sim.Kind.FLAME, 0], [Sim.Kind.HAIL, 0], [0, Sim.Kind.FAN],
	[Sim.Kind.ZAP, Sim.Kind.FAN], [Sim.Kind.GUST, Sim.Kind.PIERCE]]

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _hand := 150.0
var _cart := 0
var _laid := false
var _shots := 0
## The screen's script, loaded once the autoloads it names are up.
var Screen: GDScript

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var cfg := ConfigFile.new()
	cfg.set_value("peapod", "best_stage", 11)
	cfg.set_value("peapod", "best", 5000)
	cfg.set_value("peapod", "pick", Sim.Cart.PUMPKIN)
	cfg.save(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for lang in ["pt", "es"]:
		if args.has(lang):
			TranslationServer.set_locale(lang)
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	Screen = load("res://arcade/peapod_screen.gd")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _restore() -> void:
	# the file first: a screen that did not parse has no `force_cart` to set,
	# and an error here once left this machine's record unrestored
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if Screen != null and Screen.can_instantiate():
		Screen.force_cart = -1

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/ppc_%s.png" % [_out, name])
	var sim = _s.sim if _s != null else null
	var lit := 0
	var stung := 0
	var rimed := 0
	if sim != null:
		for row: Array in sim.rows:
			for cell in row:
				if cell != null:
					lit += int(float(cell.burn_t) > 0.0)
					stung += int(float(cell.sting_t) > 0.0)
					rimed += int(float(cell.brittle) > sim.t)
	print("shot %s at %.1f draws=%d shots=%d alight=%d stung=%d brittle=%d" % [name, _t,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), sim.shots.size() if sim != null else 0, lit, stung, rimed])

## Rolls under the lowest crate.
func _bot(delta: float) -> void:
	var sim = _s.sim
	var want: float = sim.x
	for r in sim.rows.size():
		var found := false
		for c in Sim.COLS:
			if sim.rows[r][c] != null:
				want = (c + 0.5) * Sim.CELL_W
				found = true
				break
		if found:
			break
	_hand = move_toward(_hand, want, 200.0 * delta)
	sim.target_x = _hand

func _skip_gold() -> void:
	if _s == null:
		return
	var boost: Node = _s.get_node_or_null("BoostCard")
	if boost != null and not boost.is_queued_for_deletion():
		boost._on_play()
	var chance: Node = _s.get_node_or_null("SecondChance")
	if chance != null and not chance.is_queued_for_deletion():
		chance._on_no()

## A wall worth shooting at: light crates low, heavy ones up, some gold and
## iron, standing still a little way up the garden.
func _lay() -> void:
	var sim = _s.sim
	sim.wave_kind = Sim.Wave.WALL
	sim.gap_t = 0.0
	sim.segs.clear()
	sim.rows.clear()
	var hps := [[9, 14, 7, 12, 10], [130, 240, 400, 180, 360], [800, 600, 1200, 700, 900], [2000, 2600, 1800, 2400, 3000], [7000, 5000, 9000, 6000, 8000]]
	for r in hps.size():
		var row: Array = []
		for c in Sim.COLS:
			row.append(sim._cell(Sim.Kind.CRATE, hps[r][c]))
		sim.rows.append(row)
	sim.rows[2][1] = sim._cell(Sim.Kind.IRON, 30)
	sim.rows[3][3] = sim._cell(Sim.Kind.GOLD, 150)
	sim.wall_y = 250.0
	sim.wall_speed = 3.0
	sim.power = 5
	sim.rate_lv = 3
	sim.crit_lv = 2
	sim.special = 2
	if sim.cart == Sim.Cart.PEA:
		sim.peas = 3
	var dress: Array = DRESS[sim.cart]
	if int(dress[0]) != 0:
		sim.element = dress[0]
		sim.element_t = 30.0
		_s._pod_el = dress[0]
	if int(dress[1]) != 0:
		sim.shape_t[int(dress[1]) - Sim.Kind.FAN] = 30.0

func _process(delta: float) -> bool:
	_t += delta
	if _t > 150.0:
		print("timed out at step ", _step)
		_restore()
		return true
	if _step >= 3:
		_skip_gold()
	if _s != null and _s._paused and _s._end == null:
		_s._pause(false)
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				if OS.get_cmdline_user_args().has("reduce"):
					load("res://core/motion.gd").reduce = true
				_menu._open_arcade("peapod")
				_s = _menu.get_node("Peapod")
				_at = _t
				_step = 2
		2:
			if _t > _at + 0.9 and not has_meta("p1"):
				set_meta("p1", true)
				print("the carts' card is up=%s, the cart it opens on=%d, open=%s" % [_s._cart_card != null, _s._cart,
					range(Sim.Cart.size()).map(func(c: int) -> bool: return Screen.cart_open(c))])
				_shot("p1_pick")
				_s._pick_cart(Sim.Cart.HOSE)
			if _t > _at + 1.5:
				_shot("p2_pick_hose")
				_s._carts_done()
				print("kept: pick=%d" % load("res://arcade/arcade_record.gd").pick("peapod"))
				_cart = 0
				_at = _t
				_step = 3
		3:
			# a run on each cart in turn, never asked (the run the card began
			# first, once its boosters are passed)
			if _s.sim == null or _s.get_node_or_null("BoostCard") != null:
				return false
			Screen.force_cart = _cart
			_s._ask()
			_laid = false
			_shots = 0
			_at = _t
			_step = 4
		4:
			if _s.sim == null:
				return false
			if not _laid and _s.sim.phase == Sim.Phase.PLAY:
				_laid = true
				_lay()
				_at = _t
			if _laid:
				_bot(delta)
				if _shots == 0 and _t > _at + 1.6:
					_shots = 1
					_shot("c%d_a" % _cart)
				elif _shots == 1 and _t > _at + 2.6:
					_shots = 2
					_shot("c%d_b" % _cart)
					print("cart %d: jet x%.2f, kills %d, score %d" % [_cart, _s.sim.jet(), _s.sim.kills, _s.sim.score])
					if _cart == Sim.Cart.PUMPKIN:
						_s.sim.energy = 300 * Sim.ORBS
						_s._open_shop()
						_at = _t
						_step = 5
					elif _cart + 1 < Sim.Cart.size():
						_cart += 1
						_step = 3
					else:
						_s.sim.wall_y = 1000.0
						_at = _t
						_step = 6
		5:
			if _t > _at + 0.7:
				_shot("s_shop")
				_s._close_shop()
				_cart += 1
				_step = 3
		6:
			if _s._end != null and _t > _at + 4.2:
				_shot("e_end")
				var news: Node = _s._end.find_child("CartNews", true, false)
				print("the end card says: %s" % (news.text if news != null else "(nothing)"))
				_restore()
				return true
	return false
