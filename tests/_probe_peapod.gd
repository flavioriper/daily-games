extends SceneTree

## Plays Peapod's sim headless with a bot and prints how far each run went.
## Run after touching arcade/peapod_sim.gd.
##   godot --headless --script tests/_probe_peapod.gd -- [seed] [skill 0-2] [games] [shopper 0-5]
## Skill 0 wanders under whatever is lowest, slowly; 1 aims at the lowest
## thing, gift crates first; 2 does the same at a quick finger's pace.
## The shopper is how the bot spends its energy between waves: 0 the card
## that adds most to the gun for its price, 1 only the heavier pea, 2 only
## the quicker gun, 3 only the crit, 4 two Energy cards first and then as 0,
## 5 whatever it can afford, at random. A price is tuned when 0 goes a
## little further than 1, 2 and 3, and 4 is ahead on a long run only.

const Sim = preload("res://arcade/peapod_sim.gd")

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
				var w: int = int(cell.hp) - (1000 if Sim.holds_gift(int(cell.kind)) and skill >= 1 else 0)
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
	return sim.power * sim.rate() * (1.0 + (Sim.CRIT_MULT - 1) * sim.crit())

## How much more the gun would take off with one more of `card`, as a share.
func _gain(sim: RefCounted, card: int) -> float:
	match card:
		Sim.Card.DAMAGE:
			return 1.0 / sim.power
		Sim.Card.SPEED:
			return Sim.RATE_STEP / sim.rate()
		Sim.Card.CRIT:
			return (Sim.CRIT_MULT - 1) * Sim.CRIT_STEP / (1.0 + (Sim.CRIT_MULT - 1) * sim.crit())
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
				else:
					var best := 0.0
					for card in [Sim.Card.DAMAGE, Sim.Card.SPEED, Sim.Card.CRIT]:
						if sim.maxed(card):
							continue
						var worth: float = _gain(sim, card) / sim.price(card)
						if worth > best:
							best = worth
							pick = card
		if pick < 0 or not sim.buy(pick):
			break
	sim.leave_shop()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var skill := int(args[1]) if args.size() > 1 else 1
	var games := int(args[2]) if args.size() > 2 else 5
	var shopper := int(args[3]) if args.size() > 3 else 0
	var speed: float = [110.0, 240.0, 520.0][clampi(skill, 0, 2)]
	var waves: Array = []
	var rng := RandomNumberGenerator.new()
	for g in games:
		rng.seed = seed_v + g
		var sim = Sim.new(seed_v + g)
		var tally := {}
		var hand: float = sim.x
		var guard := 0
		var log := ""
		var most := 0
		while not sim.is_over() and guard < 60 * 60 * 30:
			guard += 1
			if sim.phase == Sim.Phase.SHOP:
				_shop(sim, shopper, rng)
			hand = move_toward(hand, _target(sim, skill), speed * Sim.DT)
			sim.target_x = hand
			sim.step()
			most = maxi(most, sim.shots.size())
			for ev: Dictionary in sim.events:
				tally[ev.type] = int(tally.get(ev.type, 0)) + 1
				if ev.type == "wave":
					log += " %d@%ds(d%d r%d c%d e%d|%d)" % [ev.wave, int(sim.t), sim.power, sim.rate_lv, sim.crit_lv, sim.energy_lv, sim.energy]
			sim.events.clear()
		waves.append(sim.wave)
		print("seed %d skill %d shopper %d: wave %d  score %d  %.0f s  dmg %d rate %d crit %d energy %d  dps %.0f  kills %d  gifts %d  earned %d  held %d  shots %d" % [
			seed_v + g, skill, shopper, sim.wave, sim.score, sim.t, sim.power, sim.rate_lv, sim.crit_lv, sim.energy_lv, _dps(sim),
			sim.kills, sim.caught, sim.earned, sim.energy, most])
		if g == 0:
			print(log)
			print(tally)
	waves.sort()
	print("waves: ", waves)
	quit()
