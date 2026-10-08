extends SceneTree

## A game of Peapod played on the real screen by the bot of
## tests/_probe_peapod.gd (skill 1, shopper 0, keeper 0), to be watched:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_watch_peapod.gd -- [seed] [speed]
##
## It rolls under the weakest crate of the lowest row (a gift crate first) or
## the millipede's head at 240 field units a second, starts every gift the
## moment it has it, and in the shop buys the card that adds most to the gun
## for its price, one every third of a second so the buying can be seen.
## Prints the gun at the start of every wave and how the run ended. `speed`
## is the engine's time scale (1: as a person plays it). The end writes a
## score to user://arcade.cfg, so the file this machine had is put back on
## every way out.

const Sim = preload("res://arcade/peapod_sim.gd")
const PATH := "user://arcade.cfg"
const HAND := 240.0

var _menu: Node
var _s: Node
var _t := 0.0
var _step := 0
var _before := ""
var _had := false
var _hand := 150.0
var _seed := 100
var _seeded := 0
var _wave := 0
var _shop_t := 0.0
var _over_t := 0.0

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	# and the carts' card would stand before every run
	load("res://arcade/peapod_screen.gd").force_cart = 0
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_seed = int(args[0])
	if args.size() > 1:
		Engine.time_scale = clampf(float(args[1]), 0.25, 4.0)
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

## Play with no booster, and decline the Second chance.
func _skip_gold() -> void:
	var boost: Node = _s.get_node_or_null("BoostCard")
	if boost != null and not boost.is_queued_for_deletion():
		boost._on_play()
	var chance: Node = _s.get_node_or_null("SecondChance")
	if chance != null and not chance.is_queued_for_deletion():
		chance._on_no()

func _target(sim: RefCounted) -> float:
	if sim.wave_kind == Sim.Wave.WALL:
		# the lock first: nothing of its paint can be hurt while it stands
		if sim.ward >= 0:
			var lock: Vector2i = sim._find_kind(Sim.Kind.WARD)
			if lock.x >= 0:
				return (lock.y + 0.5) * Sim.CELL_W
		for r in sim.rows.size():
			var best := -1
			var low := 1 << 30
			for c in Sim.COLS:
				var cell = sim.rows[r][c]
				if cell == null:
					continue
				var w: int = int(cell.hp) - (1000 if Sim.holds_gift(int(cell.kind)) else 0)
				if w < low:
					low = w
					best = c
			if best >= 0:
				return (best + 0.5) * Sim.CELL_W
		return sim.x
	for sg: Dictionary in sim.segs:
		if float(sg.s) > 20.0:
			return Sim.path_at(float(sg.s) + 10.0).x
	return sim.x

func _luck(lv: int) -> float:
	return 1.0 + (Sim.crit_mult(lv) - 1) * Sim.crit_chance(lv)

func _gain(sim: RefCounted, card: int) -> float:
	match card:
		Sim.Card.DAMAGE:
			return 1.0 / sim.power
		Sim.Card.SPEED:
			return sim.rate_step() / sim.rate()
		Sim.Card.CRIT:
			return _luck(sim.crit_lv + 1) / _luck(sim.crit_lv) - 1.0
		Sim.Card.SHOTS:
			return 1.0 / sim.peas
	return 0.0

## The card worth most for its price that can be bought now, or -1.
func _pick(sim: RefCounted) -> int:
	var pick := -1
	var best := 0.0
	for card in [Sim.Card.DAMAGE, Sim.Card.SPEED, Sim.Card.CRIT, Sim.Card.SHOTS]:
		if sim.maxed(card):
			continue
		var worth: float = _gain(sim, card) / sim.price(card)
		if worth > best:
			best = worth
			pick = card
	return pick if pick >= 0 and sim.can_buy(pick) else -1

func _bot(delta: float) -> void:
	var sim: RefCounted = _s.sim
	if sim.phase == Sim.Phase.SHOP and _s._shop != null:
		_shop_t += delta
		if _shop_t < 0.35:
			return
		_shop_t = 0.0
		var pick := _pick(sim)
		if pick >= 0:
			_s._buy(pick)
		else:
			_s._close_shop()
		return
	_shop_t = 0.0
	if sim.phase != Sim.Phase.PLAY:
		return
	for kind in range(Sim.Kind.FAN, Sim.Kind.SHOVE + 1):
		if sim.can_use(kind):
			_s._press_gift(kind)
	_hand = move_toward(_hand, _target(sim), HAND * delta)
	sim.target_x = _hand

func _process(delta: float) -> bool:
	_t += delta
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.6:
				_menu._open_arcade("peapod")
				_s = _menu.get_node("Peapod")
				_step = 2
		2:
			_skip_gold()
			var sim: RefCounted = _s.sim
			if sim == null:
				return false
			# the window losing focus pauses the game; the bot plays on
			if _s._paused and _s._end == null:
				_s._pause(false)
			# the run's dice, set before anything is dealt
			if _seeded != sim.get_instance_id() and sim.phase == Sim.Phase.READY:
				_seeded = sim.get_instance_id()
				sim.rng.seed = _seed
				sim._luck.seed = sim.rng.randi()
				_hand = sim.x
				_wave = 0
				print("seed %d, sky %.0f, speed %.2f" % [_seed, sim.sky, Engine.time_scale])
			if sim.wave != _wave:
				_wave = sim.wave
				print("wave %2d at %3d s  pea %d  rate %.0f/s  crit %d  peas %d  energy card %d  held %d  score %d" % [sim.wave, int(sim.t),
					sim.power, sim.rate(), sim.crit_lv, sim.peas, sim.energy_lv, sim.energy / Sim.ORBS, sim.score])
			if sim.is_over():
				if _over_t == 0.0:
					print("over on wave %d after %d s, score %d, kills %d" % [sim.wave, int(sim.t), sim.score, sim.kills])
				_over_t += delta
				if _over_t > 4.0 * Engine.time_scale:
					_restore()
					return true
				return false
			_bot(delta)
	return false
