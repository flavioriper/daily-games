extends RefCounted

## Furrow, as pure data: a field of plots, a crop growing on each, and the
## seeds they pay (spec docs/superpowers/specs/2026-10-11-arcade-furrow-design.md).
## The screen (arcade/furrow_screen.gd) and the field it draws
## (arcade/furrow_field.gd) call in and play `events`; nothing here draws,
## sounds or reads a clock but `save` and `load_saved`.
##
## **A kept game.** There is no run: the field is saved (`path`) and grows
## on the wall clock while the game is shut. What ripens waits for the
## finger and never rots, and nothing is picked, sold or banked while away,
## so time away is worth one full field and no more.
##
## **A crop** takes `grow` seconds and pays `value` seeds. A slower crop
## pays more a second, so the slow ones are for going away and the quick
## ones for staying.
##
## **The chain.** Each crop picked within WINDOW seconds of the last is a
## link, and a link pays `chain_step()` more than the one before it, up to
## as many links as there are open plots (a chain kept going past that
## stays at its top). So a field left to ripen and picked in one stroke
## pays far more than the same crops picked one by one. The whole field in
## one chain is a clean sweep and pays SWEEP of the chain again.
##
## Seeds are Furrow's own: gold buys none of this. They open plots (one at
## a time, in ORDER), buy the next crop's packet, and three upgrades with no
## top, each level GROWTH times the last.
##
##   step(dt)        grows the field and runs the chain's clock
##   pick(i)         picks a ripe plot; false, and nothing, when it is not
##   sow(i, crop)    puts another crop on a plot (a ripe one is picked first)
##   buy_plot()      opens the next plot, sown with `crop`
##   buy_crop()      the next crop's packet
##   buy_up(id)      a level of an upgrade

const COLS := 4
const ROWS := 5
## The plots open on a new field.
const START := 4
## id, seconds to grow, seeds a crop, the packet's price.
const CROPS := [
	{"id": "radish", "grow": 10.0, "value": 1, "price": 0},
	{"id": "carrot", "grow": 30.0, "value": 4, "price": 60},
	{"id": "lettuce", "grow": 90.0, "value": 14, "price": 600},
	{"id": "tomato", "grow": 240.0, "value": 45, "price": 6000},
	{"id": "corn", "grow": 600.0, "value": 130, "price": 50000},
	{"id": "pumpkin", "grow": 1800.0, "value": 450, "price": 400000},
	{"id": "sunflower", "grow": 7200.0, "value": 2100, "price": 3000000},
	{"id": "melon", "grow": 28800.0, "value": 10000, "price": 25000000},
]
## The fifth plot's price, and how much dearer each one after it is.
const PLOT_FIRST := 15
const PLOT_GROWTH := 1.62
const UPS := ["compost", "basket", "knack"]
const FIRST := {"compost": 50, "basket": 80, "knack": 120}
const GROWTH := 1.45
## A level of Compost grows everything this much faster, of Basket pays
## this much more, of Knack adds this to what each link pays.
const COMPOST_UP := 0.04
const BASKET_UP := 0.08
const KNACK_UP := 0.005
## What a link pays more than the one before it, and the seconds a chain
## waits for its next link.
const CHAIN_STEP := 0.05
const WINDOW := 1.6
## The links that are a moment, and every EVERY after the last of them.
const BUNCHES := [5, 10, 15, 20]
const EVERY := 10
## The whole field in one chain: this much of the chain again, from MIN_SWEEP
## open plots.
const SWEEP := 0.25
const MIN_SWEEP := 6
## One ripening in so many is golden and pays GOLD_TIMES.
const GOLD_CHANCE := 0.04
const GOLD_TIMES := 5
## The stages a plant is drawn in: a mound, a sprout, a young plant, ripe.
const STAGES := 4
const SPROUT := 0.12
const YOUNG := 0.5

static var path := "user://furrow.cfg"

var cols := COLS
var rows := ROWS
## A plot: {open, crop, t (seconds grown), ripe, gold}.
var plots: Array = []
## The order the plots open in: from the middle out.
var order: Array = []
var seeds := 0
## Every seed ever paid, and every crop ever picked.
var earned := 0
var picked := 0
## How many of CROPS are held: the first `crops` of them.
var crops := 1
var lv := {"compost": 0, "basket": 0, "knack": 0}
## The chain: its links, the seconds it still waits, and what it has paid.
var chain := 0
var chain_t := 0.0
var chain_sum := 0
var _swept := false
var best_chain := 0
var best_sweep := 0
var sweeps := 0
## What the time away did, for the screen's welcome: the seconds, and the
## plots that ripened in them.
var away_secs := 0.0
var away_ripe := 0
## The wall clock at the last step, to measure a pause by.
var stamp := 0.0
var events: Array = []
var _rng := RandomNumberGenerator.new()

func _init(rng_seed := 0, c := COLS, r := ROWS, start := START) -> void:
	cols = c
	rows = r
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	for i in cols * rows:
		plots.append({"open": false, "crop": 0, "t": 0.0, "ripe": false, "gold": false})
	order = range(cols * rows)
	var mid := Vector2((cols - 1) * 0.5, minf((rows - 1) * 0.5, 1.5))
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := Vector2(a % cols, a / cols).distance_squared_to(mid)
		var db := Vector2(b % cols, b / cols).distance_squared_to(mid)
		return da < db if not is_equal_approx(da, db) else a < b)
	for k in mini(start, order.size()):
		plots[order[k]].open = true
	stamp = Time.get_unix_time_from_system()

# --- what things are worth ---

func grow_time(crop: int) -> float:
	return float(CROPS[crop].grow) / (1.0 + COMPOST_UP * int(lv.compost))

## The seeds a crop pays before the chain.
func worth(crop: int) -> int:
	return maxi(1, int(round(float(CROPS[crop].value) * (1.0 + BASKET_UP * int(lv.basket)))))

func chain_step() -> float:
	return CHAIN_STEP + KNACK_UP * int(lv.knack)

func opened() -> int:
	var n := 0
	for p: Dictionary in plots:
		if p.open:
			n += 1
	return n

func ripe_count() -> int:
	var n := 0
	for p: Dictionary in plots:
		if p.open and p.ripe:
			n += 1
	return n

## What link `n` of a chain pays, as a multiple of the crop's worth.
func times(n: int) -> float:
	return 1.0 + chain_step() * (mini(n, opened()) - 1)

## How far along plot `i` is, 0 to 1.
func grown(i: int) -> float:
	var p: Dictionary = plots[i]
	return 1.0 if p.ripe else clampf(float(p.t) / grow_time(p.crop), 0.0, 1.0)

func left(i: int) -> float:
	var p: Dictionary = plots[i]
	return 0.0 if p.ripe else maxf(0.0, grow_time(p.crop) - float(p.t))

func stage(i: int) -> int:
	var k := grown(i)
	return 3 if plots[i].ripe else 2 if k >= YOUNG else 1 if k >= SPROUT else 0

## The plot the next purchase opens, -1 with the field whole.
func next_plot() -> int:
	for i: int in order:
		if not plots[i].open:
			return i
	return -1

static func _fives(v: float) -> int:
	return int(round(v / 5.0)) * 5

func plot_price() -> int:
	return _fives(PLOT_FIRST * pow(PLOT_GROWTH, opened() - START))

## The next packet's price, -1 with every crop held.
func crop_price() -> int:
	return int(CROPS[crops].price) if crops < CROPS.size() else -1

func up_price(id: String) -> int:
	return _fives(float(FIRST[id]) * pow(GROWTH, int(lv[id])))

## What level `n` of an upgrade is worth, as the shop letters it.
func up_worth(id: String, n: int) -> String:
	match id:
		"compost":
			return "+%d%%" % int(round(COMPOST_UP * n * 100.0))
		"basket":
			return "+%d%%" % int(round(BASKET_UP * n * 100.0))
		_:
			return "+%.1f%%" % ((CHAIN_STEP + KNACK_UP * n) * 100.0)

# --- time ---

func _grow(p: Dictionary, dt: float) -> bool:
	if not p.open or p.ripe:
		return false
	p.t = float(p.t) + dt
	if float(p.t) < grow_time(p.crop):
		return false
	p.ripe = true
	p.gold = _rng.randf() < GOLD_CHANCE
	return true

func step(dt: float) -> void:
	stamp = Time.get_unix_time_from_system()
	for i in plots.size():
		if _grow(plots[i], dt):
			events.append({"type": "ripe", "i": i, "gold": plots[i].gold})
	if chain > 0:
		chain_t -= dt
		if chain_t <= 0.0:
			_end_chain()

## Time gone by with the game shut or asleep: the field grows, in one go
## however long it was, and nothing else happens.
func away(seconds: float) -> int:
	var n := 0
	if seconds <= 0.0:
		return 0
	for p: Dictionary in plots:
		if _grow(p, seconds):
			n += 1
	if chain > 0:
		_end_chain()
		events.clear()
	return n

func _end_chain() -> void:
	events.append({"type": "chain_end", "n": chain, "sum": chain_sum, "swept": _swept})
	best_chain = maxi(best_chain, chain)
	best_sweep = maxi(best_sweep, chain_sum)
	chain = 0
	chain_sum = 0
	chain_t = 0.0
	_swept = false

# --- the hand ---

func pick(i: int) -> bool:
	var p: Dictionary = plots[i]
	if not p.open or not p.ripe:
		return false
	chain += 1
	chain_t = WINDOW
	var pay := maxi(1, int(round(worth(p.crop) * (GOLD_TIMES if p.gold else 1) * times(chain))))
	seeds += pay
	earned += pay
	picked += 1
	chain_sum += pay
	events.append({"type": "pick", "i": i, "crop": p.crop, "gold": p.gold, "n": chain, "pay": pay})
	p.t = 0.0
	p.ripe = false
	p.gold = false
	if chain in BUNCHES or (chain > BUNCHES[-1] and (chain - BUNCHES[-1]) % EVERY == 0):
		events.append({"type": "bunch", "n": chain, "tier": mini(BUNCHES.size(), (chain + 4) / 5) - 1})
	var open := opened()
	if not _swept and chain == open and open >= MIN_SWEEP:
		_swept = true
		sweeps += 1
		var bonus := maxi(1, int(round(chain_sum * SWEEP)))
		seeds += bonus
		earned += bonus
		chain_sum += bonus
		events.append({"type": "sweep", "n": chain, "bonus": bonus})
	return true

func sow(i: int, crop: int) -> bool:
	var p: Dictionary = plots[i]
	if not p.open or crop < 0 or crop >= crops:
		return false
	# a ripe bed is picked first, whatever is in hand: the same crop over it
	# is a pick and nothing more
	if p.ripe:
		pick(i)
	if int(p.crop) == crop:
		return not events.is_empty() and events[-1].type != "sow" and int(events[-1].get("i", -1)) == i
	p.crop = crop
	p.t = 0.0
	events.append({"type": "sow", "i": i, "crop": crop})
	return true

func buy_plot(crop := 0) -> int:
	var i := next_plot()
	var cost := plot_price()
	if i < 0 or seeds < cost:
		return -1
	seeds -= cost
	var p: Dictionary = plots[i]
	p.open = true
	p.crop = clampi(crop, 0, crops - 1)
	p.t = 0.0
	events.append({"type": "plot", "i": i, "paid": cost})
	return i

func buy_crop() -> bool:
	var cost := crop_price()
	if cost < 0 or seeds < cost:
		return false
	seeds -= cost
	crops += 1
	events.append({"type": "crop", "crop": crops - 1, "paid": cost})
	return true

func buy_up(id: String) -> bool:
	var cost := up_price(id)
	if seeds < cost:
		return false
	seeds -= cost
	lv[id] = int(lv[id]) + 1
	events.append({"type": "up", "id": id, "level": int(lv[id]), "paid": cost})
	return true

# --- kept ---

## Writes the field to `path`; a harness that must leave no file sets it to "".
func save() -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	var rows_out := []
	for p: Dictionary in plots:
		rows_out.append([p.open, int(p.crop), float(p.t), p.ripe, p.gold])
	cfg.set_value("field", "plots", rows_out)
	cfg.set_value("field", "seeds", seeds)
	cfg.set_value("field", "earned", earned)
	cfg.set_value("field", "picked", picked)
	cfg.set_value("field", "crops", crops)
	cfg.set_value("field", "lv", lv)
	cfg.set_value("field", "best_chain", best_chain)
	cfg.set_value("field", "best_sweep", best_sweep)
	cfg.set_value("field", "sweeps", sweeps)
	cfg.set_value("field", "stamp", Time.get_unix_time_from_system())
	cfg.save(path)

## The kept field, grown by the time away; a new one with nothing kept.
static func load_saved(rng_seed := 0) -> RefCounted:
	var s = new(rng_seed)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return s
	var kept: Array = cfg.get_value("field", "plots", [])
	for i in mini(kept.size(), s.plots.size()):
		var row: Array = kept[i]
		s.plots[i] = {"open": bool(row[0]), "crop": clampi(int(row[1]), 0, CROPS.size() - 1), "t": float(row[2]), "ripe": bool(row[3]), "gold": bool(row[4])}
	s.seeds = int(cfg.get_value("field", "seeds", 0))
	s.earned = int(cfg.get_value("field", "earned", 0))
	s.picked = int(cfg.get_value("field", "picked", 0))
	s.crops = clampi(int(cfg.get_value("field", "crops", 1)), 1, CROPS.size())
	var levels: Dictionary = cfg.get_value("field", "lv", {})
	for id: String in UPS:
		s.lv[id] = int(levels.get(id, 0))
	s.best_chain = int(cfg.get_value("field", "best_chain", 0))
	s.best_sweep = int(cfg.get_value("field", "best_sweep", 0))
	s.sweeps = int(cfg.get_value("field", "sweeps", 0))
	# a clock set back gives no time, and never takes any
	s.away_secs = maxf(0.0, Time.get_unix_time_from_system() - float(cfg.get_value("field", "stamp", Time.get_unix_time_from_system())))
	s.away_ripe = s.away(s.away_secs)
	return s

## The field as the Arcade tab's card reads it, without growing anything.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {"earned": 0, "seeds": 0, "plots": 0, "crops": 0}
	var n := 0
	for row: Array in cfg.get_value("field", "plots", []):
		if bool(row[0]):
			n += 1
	return {"earned": int(cfg.get_value("field", "earned", 0)), "seeds": int(cfg.get_value("field", "seeds", 0)), "plots": n,
		"crops": int(cfg.get_value("field", "crops", 1))}
