extends SceneTree

## Plays Firefly's sim headless with a simple bot for a few minutes of game
## time and prints what happened: stages reached, score, and a tally of
## events. Run after touching arcade/firefly_sim.gd.
##   godot --headless --script tests/_probe_firefly.gd -- [seed] [minutes] [skill] [shopper]
## The shopper is how the bot spends its energy between stages: 0 the card
## worth most for its price, 1 to 5 one card only (damage, speed, crit,
## energy, shots), 6 two of Energy first and then as 0, 7 at random, 8
## nothing at all.

const Sim = preload("res://arcade/firefly_sim.gd")

## 1 plays well; lower fires less and dodges less.
var skill := 1.0
var _rng := RandomNumberGenerator.new()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var minutes := float(args[1]) if args.size() > 1 else 4.0
	skill = float(args[2]) if args.size() > 2 else 1.0
	var shopper := int(args[3]) if args.size() > 3 else 0
	var sim: RefCounted = Sim.new(seed_v)
	var tally := {}
	var steps := int(minutes * 60.0 / Sim.DT)
	var t0 := Time.get_ticks_usec()
	var stages := []
	for i in steps:
		_bot(sim)
		sim.step()
		for ev: Dictionary in sim.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
			if ev.type == "stage_start" or ev.type == "challenge_start":
				stages.append(ev.stage)
			if ev.type == "challenge_result":
				print("flyby: %d/%d bonus %d" % [ev.hits, ev.total, ev.bonus])
		sim.events.clear()
		if sim.phase == Sim.Phase.SHOP:
			_shop(sim, shopper)
			print("  after stage %d (%.0f s): dmg %d rate %.1f crit %d shots %d energy+%d  held %d  next gnat %d beetle %d moth %d" % [
				sim.stage - 1, sim.t, sim.power, sim.rate(), sim.crit_lv, sim.volley, sim.energy_lv, int(sim.energy / Sim.ORBS),
				sim.hp_of(Sim.Kind.GNAT), sim.hp_of(Sim.Kind.BEETLE), sim.hp_of(Sim.Kind.MOTH)])
		if sim.is_over():
			print("game over at %.1f s" % sim.t)
			break
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("stage %d score %d ships %d fired %d hits %d kills %d" % [sim.stage, sim.score, sim.ships, sim.fired, sim.hits, sim.kills])
	print("gun: dmg %d rate %.1f crit %d shots %d energy+%d  earned %d" % [sim.power, sim.rate(), sim.crit_lv, sim.volley,
		sim.energy_lv, int(sim.earned / Sim.ORBS)])
	print("stages: ", stages)
	print("events: ", tally)
	print("sim ms per game second: %.2f" % (ms / sim.t))
	quit()

## Sits under the lowest bug, sidesteps bullets coming down on it, fires.
func _bot(sim: RefCounted) -> void:
	sim.fire = _rng.randf() < skill
	var aim: float = sim.px
	var best := -1.0
	for e: Dictionary in sim.enemies:
		if e.st == Sim.St.WAIT:
			continue
		if e.pos.y > best and e.pos.y < Sim.PLAYER_Y - 30.0:
			best = e.pos.y
			aim = e.pos.x
	for b: Dictionary in sim.bullets:
		if b.pos.y > Sim.PLAYER_Y - 90.0 and absf(b.pos.x - sim.px) < 14.0 and _rng.randf() < skill:
			aim = sim.px + (30.0 if b.pos.x < sim.px else -30.0)
	sim.target_x = aim

## What the crit makes of a shot on average, at level `lv`.
func _lucky(lv: int) -> float:
	return 1.0 + (Sim.crit_mult(lv) - 1) * Sim.crit_chance(lv)

## How much more the gun would take off with one more of `card`, as a share.
func _gain(sim: RefCounted, card: int) -> float:
	match card:
		Sim.Card.DAMAGE:
			return 1.0 / sim.power
		Sim.Card.SPEED:
			return Sim.RATE_STEP / sim.rate()
		Sim.Card.CRIT:
			return _lucky(sim.crit_lv + 1) / _lucky(sim.crit_lv) - 1.0
		Sim.Card.SHOTS:
			return 1.0 / sim.volley
	return 0.0

func _shop(sim: RefCounted, shopper: int) -> void:
	for guard in 40:
		var pick := -1
		match shopper:
			1, 2, 3, 4, 5:
				pick = shopper - 1
			7:
				var can: Array = []
				for card in Sim.Card.size():
					if sim.can_buy(card):
						can.append(card)
				if not can.is_empty():
					pick = can[_rng.randi_range(0, can.size() - 1)]
			8:
				pass
			_:
				if shopper == 6 and int(sim.bought[Sim.Card.ENERGY]) < 2:
					pick = Sim.Card.ENERGY
				else:
					var best := 0.0
					for card in [Sim.Card.DAMAGE, Sim.Card.SPEED, Sim.Card.CRIT, Sim.Card.SHOTS]:
						var worth: float = _gain(sim, card) / sim.price(card)
						if worth > best:
							best = worth
							pick = card
		if pick < 0 or not sim.buy(pick):
			break
	sim.leave_shop()
