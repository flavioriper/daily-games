extends SceneTree

## Plays Peapod's sim headless with a bot and prints how far each run went.
## Run after touching arcade/peapod_sim.gd.
##   godot --headless --script tests/_probe_peapod.gd -- [seed] [skill 0-2] [games] [shopper 0-7] [keeper 0-1] [cart 0-5] [until]
##   godot --headless --script tests/_probe_peapod.gd -- far [wave] [seed]
## `until` stops a run on that wave (0: when it ends, an hour of play at
## most). `far` plays the good player on every cart to `wave` (500) and says
## when each passed 100, 250 and 500: every cart must get there.
## The cart is Sim.Cart. After the runs it prints what was taken off a second
## while each element ran (0: none), over all of them: an element is tuned
## when none is far ahead of the rest.
## Skill 0 wanders under whatever is lowest, slowly; 1 aims at the lowest
## thing, gift crates first; 2 does the same at a quick finger's pace.
## The shopper is how the bot spends its energy between waves: 0 the card
## that adds most to the gun for its price, 1 only the heavier pea, 2 only
## the quicker gun, 3 only the crit, 4 two Energy cards first and then as 0,
## 5 whatever it can afford, at random, 6 as 0 but never the pea more a
## volley, 7 the investor: an Energy card whenever it pays itself back in
## twelve waves (or half the waves so far) and the gun has had as much, else
## as 0. A price is tuned when 0 goes a
## little further than 1, 2 and 3, and 4 is ahead on a long run only.
## The keeper is what the bot does with a gift it holds: 0 starts it at
## once, 1 keeps a pod until it holds one that runs with it (a shape and an
## element) and starts both, a lone pod when nothing of its kind is running,
## and keeps the frost and the shove for when the line is near.

const Sim = preload("res://arcade/peapod_sim.gd")

## What shopper 7 has spent on the Energy card and on the gun.
var _on_energy := 0
var _on_gun := 0

func _target(sim: RefCounted, skill: int) -> float:
	if sim.wave_kind == Sim.Wave.WALL:
		for r in sim.rows.size():
			var best := -1
			var low := 1 << 30
			for c in Sim.COLS:
				var cell = sim.rows[r][c]
				if cell == null:
					continue
				# gifts first, then the weakest of the lowest row
				var w: int = int(cell.hp) - ((1 << 28) if Sim.holds_gift(int(cell.kind)) and skill >= 1 else 0)
				# the twins: where the other cart has something of this row too
				if sim.cart == Sim.Cart.TWINS and skill >= 1 and sim.rows[r][Sim.COLS - 1 - c] != null:
					w -= 1 << 26
				if w < low:
					low = w
					best = c
			if best >= 0:
				return (best + 0.5) * Sim.CELL_W
		return sim.x
	if sim.segs.is_empty():
		return sim.x
	# the plate furthest along that is on the field
	for sg: Dictionary in sim.segs:
		if float(sg.s) > 20.0:
			return Sim.path_at(float(sg.s) + (10.0 if skill >= 1 else 0.0)).x
	return sim.x

## The gun's worth: what it takes off a second.
func _dps(sim: RefCounted) -> float:
	return sim.power * sim.rate() * _volley(sim, sim.special) * _luck(sim.crit_lv)

## About what a volley lands, in peas, with `special` of the cart's own card.
func _volley(sim: RefCounted, special: int) -> float:
	var w: float = Sim.CART_WEIGHT[sim.cart]
	match sim.cart:
		Sim.Cart.CONKER:
			return w * (1.0 + Sim.HOP_KEEP * (special + 1))
		Sim.Cart.PUMPKIN:
			# the blast takes in about its area's worth of crates
			var reach: float = Sim.BLAST_R + Sim.BLAST_STEP * special
			return w * (1.0 + Sim.BLAST_SHARE * maxf(0.0, PI * reach * reach / (Sim.CELL_W * Sim.CELL_H) - 1.0) * 0.6)
		Sim.Cart.HOSE:
			return w * (1.0 + (Sim.JET_CAP + Sim.JET_CAP_STEP * special - 1.0) * 0.4 * (1.0 + Sim.JET_QUICK * special) / (1.0 + Sim.JET_QUICK * special * 0.5))
		Sim.Cart.DANDELION:
			return w * (Sim.SEEDS + Sim.SEED_STEP * special) * 0.8
		Sim.Cart.TWINS:
			return w * (1.0 + Sim.TWIN + 2.0 * Sim.TWIN_STEP * special)
	return w * (1 + special)

## What the crit makes of a pea on average, at level `lv`.
func _luck(lv: int) -> float:
	return 1.0 + (Sim.crit_mult(lv) - 1) * Sim.crit_chance(lv)

## How much more the gun would take off with one more of `card`, as a share.
func _gain(sim: RefCounted, card: int) -> float:
	match card:
		Sim.Card.DAMAGE:
			return 1.0 / sim.power
		Sim.Card.SPEED:
			return sim.rate_step() / sim.rate()
		Sim.Card.CRIT:
			return _luck(sim.crit_lv + 1) / _luck(sim.crit_lv) - 1.0
		Sim.Card.SHOTS:
			return _volley(sim, sim.special + 1) / _volley(sim, sim.special) - 1.0
	return 0.0

func _shop(sim: RefCounted, shopper: int, rng: RandomNumberGenerator) -> void:
	for guard in 40:
		var pick := -1
		match shopper:
			1, 2, 3:
				pick = shopper - 1
			5:
				var can: Array = []
				for card in Sim.Card.size():
					if sim.can_buy(card):
						can.append(card)
				if not can.is_empty():
					pick = can[rng.randi_range(0, can.size() - 1)]
			_:
				if shopper == 4 and int(sim.bought[Sim.Card.ENERGY]) < 2:
					pick = Sim.Card.ENERGY
				elif shopper == 7 and _on_energy <= _on_gun and sim.price(Sim.Card.ENERGY) < Sim.wave_crates(sim.wave) * Sim.ENERGY_STEP * Sim.ORBS * maxf(12.0, sim.wave * 0.5):
					# the investor: an Energy card that pays itself back in
					# twelve waves, as long as the gun has had as much
					pick = Sim.Card.ENERGY
				else:
					var best := 0.0
					for card in [Sim.Card.DAMAGE, Sim.Card.SPEED, Sim.Card.CRIT, Sim.Card.SHOTS]:
						if sim.maxed(card) or (shopper == 6 and card == Sim.Card.SHOTS):
							continue
						var worth: float = _gain(sim, card) / sim.price(card)
						if worth > best:
							best = worth
							pick = card
		var cost: int = sim.price(pick) if pick >= 0 else 0
		if pick < 0 or not sim.buy(pick):
			break
		if pick == Sim.Card.ENERGY:
			_on_energy += cost
		else:
			_on_gun += cost
	sim.leave_shop()

## Starts what the bot has, by its keeper: 0 starts every gift at once; 1
## keeps the frost and the shove for when the line is near, starts a shape
## that is not running, and an element only when none is.
func _use(sim: RefCounted, keeper: int) -> void:
	for kind in range(Sim.Kind.FAN, Sim.Kind.SHOVE + 1):
		if sim.has(kind) == 0:
			continue
		if keeper == 0:
			sim.use(kind)
		elif kind == Sim.Kind.FROST or kind == Sim.Kind.SHOVE:
			if sim.danger() > 0.45 and (kind == Sim.Kind.SHOVE or sim.frost_t <= 0.0):
				sim.use(kind)
		elif Sim.is_shape(kind):
			if not sim.has_shape(kind):
				sim.use(kind)
		elif sim.element == 0:
			sim.use(kind)

## The good player (quick, the investor, gifts kept) on every cart, as far as
## `far`: the wave each got to and when it passed 100, 250 and 500.
func _far(far: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	for cart in Sim.Cart.size():
		rng.seed = seed_v
		_on_energy = 0
		_on_gun = 0
		var sim = Sim.new(seed_v, cart)
		var hand: float = sim.x
		var most := 0
		var at := {}
		while not sim.is_over() and sim.wave < far:
			if sim.phase == Sim.Phase.SHOP:
				_shop(sim, 7, rng)
			_use(sim, 1)
			hand = move_toward(hand, _target(sim, 2), 520.0 * Sim.DT)
			sim.target_x = hand
			sim.step()
			most = maxi(most, sim.shots.size())
			sim.events.clear()
			if sim.wave in [100, 250, 500] and not at.has(sim.wave):
				at[sim.wave] = int(sim.t / 60.0)
		var marks := ""
		for w in [100, 250, 500]:
			marks += "  %d: %s" % [w, ("%d min" % at[w]) if at.has(w) else "no"]
		print("cart %d (%s): wave %d%s  shots %d  %s" % [cart, Sim.Cart.keys()[cart], sim.wave, marks, most, "ok" if sim.wave >= far else "SHORT"])
	quit()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "far":
		_far(int(args[1]) if args.size() > 1 else 500, int(args[2]) if args.size() > 2 else 7)
		return
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var skill := int(args[1]) if args.size() > 1 else 1
	var games := int(args[2]) if args.size() > 2 else 5
	var shopper := int(args[3]) if args.size() > 3 else 0
	var keeper := int(args[4]) if args.size() > 4 else 0
	var cart := int(args[5]) if args.size() > 5 else 0
	var until := int(args[6]) if args.size() > 6 else 0
	var by_el := {}
	var speed: float = [110.0, 240.0, 520.0][clampi(skill, 0, 2)]
	var waves: Array = []
	var rng := RandomNumberGenerator.new()
	for g in games:
		rng.seed = seed_v + g
		var sim = Sim.new(seed_v + g, cart)
		var tally := {}
		var hand: float = sim.x
		var guard := 0
		var log := ""
		var most := 0
		var chain := 0
		var pairs := 0
		_on_energy = 0
		_on_gun = 0
		while not sim.is_over() and (guard < 60 * 60 * 60 or until > 0) and (until == 0 or sim.wave < until):
			guard += 1
			if sim.phase == Sim.Phase.SHOP:
				_shop(sim, shopper, rng)
			_use(sim, keeper)
			hand = move_toward(hand, _target(sim, skill), speed * Sim.DT)
			sim.target_x = hand
			var el: int = sim.element
			var live: bool = sim.phase == Sim.Phase.PLAY and sim.gap_t <= 0.0
			sim.step()
			most = maxi(most, sim.shots.size())
			if not by_el.has(el):
				by_el[el] = [0.0, 0.0, 0.0]
			if live:
				by_el[el][0] += Sim.DT
				by_el[el][2] += _dps(sim) * Sim.DT
			for ev: Dictionary in sim.events:
				tally[ev.type] = int(tally.get(ev.type, 0)) + 1
				if ev.type == "hit":
					by_el[el][1] += int(ev.dmg)
				if ev.type == "kill":
					chain += int(ev.streak)
					pairs += int(ev.pair)
				if ev.type == "wave":
					log += " %d@%ds(d%d r%d c%d p%d e%d|%d)" % [ev.wave, int(sim.t), sim.power, sim.rate_lv, sim.crit_lv, sim.special, sim.energy_lv, sim.energy / Sim.ORBS]
			sim.events.clear()
		waves.append(sim.wave)
		print("seed %d skill %d shopper %d keeper %d cart %d: wave %d  score %d  %.0f s  dmg %d rate %d crit %d own %d energy %d  dps %.0f  kills %d  gifts %d used %d waiting %d  earned %d  held %d  shots %d  streak %.1f best %d pods %.2f" % [
			seed_v + g, skill, shopper, keeper, cart, sim.wave, sim.score, sim.t, sim.power, sim.rate_lv, sim.crit_lv, sim.special, sim.energy_lv, _dps(sim),
			sim.kills, sim.caught, sim.used, sim.stock.reduce(func(a: int, b: int) -> int: return a + b, 0), sim.earned / Sim.ORBS, sim.energy / Sim.ORBS, most, chain / maxf(1.0, sim.kills), sim.best_streak, pairs / maxf(1.0, sim.kills)])
		if g == 0:
			print(log)
			print(tally)
	waves.sort()
	print("waves: ", waves)
	# what came off a second under each element, against what the gun alone is worth
	var names := {0: "none", Sim.Kind.ZAP: "zap", Sim.Kind.FLAME: "flame", Sim.Kind.NETTLE: "nettle", Sim.Kind.HAIL: "hail", Sim.Kind.GUST: "gust"}
	for el: int in names:
		if by_el.has(el) and float(by_el[el][0]) > 0.0:
			print("  %-6s %5.0f s  took %.2f of the gun's worth" % [names[el], by_el[el][0], float(by_el[el][1]) / maxf(1.0, float(by_el[el][2]))])
	quit()
