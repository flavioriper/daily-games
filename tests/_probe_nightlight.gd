extends SceneTree

## Nightlight, headless: the physics first, then a bot at the real sim to say
## how fast the numbers are.
##
##     godot --headless --path . --script res://tests/_probe_nightlight.gd
##     godot --headless --path . --script res://tests/_probe_nightlight.gd -- pace [minutes] [seed] [first|second|random] [share of the time the finger is down] [gas|worlds]
##
## The checks: a puff of gas set on a circle in the disc winds in over a
## minute or so, goes round more than once, speeds up and pays its light; a
## planet beside it is still up when the puff is long gone; gas poured in
## makes grains, the grains outside the frost line are ice, nothing forms
## inside the Roche radius, and mass is kept through all of it; the tide
## tears a planet inside its distance and not outside; the star burns
## hydrogen into helium and light, the helium lights at its core mass, a
## carbon core waits for a star of eight Suns, an iron core ends the star as
## a supernova that pays stardust and leaves gas on closed paths, a star with
## nothing to burn goes dim, wakes when fed and lets go after its grace; a
## tile costs what the table says; picks come at the Suns the table says;
## a star saved and read back is the same star, and one kept before the gas
## comes back without its sky; a light star with a carbon core sheds a
## nebula and leaves a white dwarf, a supernova a neutron star (a black hole
## from twenty Suns), and the next star is born away from the relics, its
## gas dusty with what the last one made.
## `pace` holds a finger on the ring (braking as fast as the Flow tile lets
## it), buys the cheapest tile it can, takes the first, the second or either of the two
## powers offered, buys a perk whenever the stardust reaches, and prints
## every milestone with what the sky held. Everything runs on a throwaway
## file.

const Sim = preload("res://arcade/nightlight_sim.gd")

var _fails := 0
var _checks := 0

func _initialize() -> void:
	Sim.path = OS.get_user_data_dir() + "/_probe_nightlight.cfg"
	DirAccess.remove_absolute(Sim.path)
	var args := OS.get_cmdline_user_args()
	if args.has("pace"):
		_pace(float(args[1]) if args.size() > 1 else 60.0, int(args[2]) if args.size() > 2 else 1,
			String(args[3]) if args.size() > 3 else "random", float(args[4]) if args.size() > 4 else 1.0,
			String(args[5]) if args.size() > 5 else "gas")
	else:
		_check_disc()
		_check_condensing()
		_check_tide()
		_check_star()
		_check_rules()
		_check_relics()
		_check_ends()
		_check_giant()
		_check_ring()
		_check_frost()
		print("probe_nightlight: %d checks, %d failed" % [_checks, _fails])
	DirAccess.remove_absolute(Sim.path)
	quit(1 if _fails > 0 else 0)

func _ok(what: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
		print("FAIL ", what)

func _quiet(rng_seed := 7) -> RefCounted:
	var sim: RefCounted = Sim.new(rng_seed)
	sim.passing = false
	sim.burning = false
	return sim

func _run(sim: RefCounted, seconds: float) -> void:
	for i in int(seconds / Sim.STEP):
		sim.tick()

func _sky_mass(sim: RefCounted) -> float:
	var m := 0.0
	for b: Sim.Body in sim.bodies:
		m += b.m
	return m

## A puff set on a circle just inside the disc's rim, as the old button did:
## the older checks' way of putting gas in.
func _puff(sim: RefCounted, m := Sim.PUFF) -> Sim.Body:
	var pos: Vector2 = Vector2.from_angle(sim._rng.randf() * TAU) * sim.haze_r() * sim._rng.randf_range(0.7, 0.97)
	var b: Sim.Body = sim.add(Sim.Kind.GAS, m, pos, sim.circle_vel(pos) * sim._rng.randf_range(0.97, 1.0))
	b.h = sim.puff_h()
	b.dust = Sim.DUSTY * Sim.PUFF / m
	return b

func _check_disc() -> void:
	var sim := _quiet()
	var at: Vector2 = Vector2(sim.haze_r() * 0.85, 0.0)
	var puff: Sim.Body = sim.add(Sim.Kind.GAS, Sim.PUFF, at, sim.circle_vel(at))
	puff.h = 0.7
	var v0 := puff.vel.length()
	var far: Vector2 = Vector2(0.0, sim.haze_r() * 0.85)
	var planet: Sim.Body = sim.add(Sim.Kind.PLANET, 0.01, far, sim.circle_vel(far))
	var turns := 0.0
	var fastest := 0.0
	var last := puff.pos.angle()
	var t := 0.0
	while sim.bodies.has(puff) and t < 600.0:
		sim.tick()
		t += Sim.STEP
		turns += absf(angle_difference(last, puff.pos.angle()))
		last = puff.pos.angle()
		fastest = maxf(fastest, puff.vel.length())
	print("  a puff from 0.85 of the disc: %.0f s, %.1f turns, %.0f to %.0f px/s, light %.3f (a perfect spiral %.3f); a round there %.0f s, at the Roche radius %.0f s" % [
		t, turns / TAU, v0, fastest, sim.light, sim.spiral_light() * Sim.PUFF, sim.turn_time(at.x), sim.turn_time(sim.roche_r())])
	_ok("a puff winds in within three minutes", t > 30.0 and t < 180.0)
	_ok("it goes round more than once", turns / TAU > 1.2)
	_ok("it speeds up on the way down", fastest > v0 * 1.3)
	_ok("it pays light", sim.light > 0.5 * sim.spiral_light() * Sim.PUFF)
	_ok("the star has its mass and its hydrogen", is_equal_approx(sim.mass, Sim.START + Sim.PUFF) and is_equal_approx(sim.fuel, Sim.START * Sim.STAR_H + Sim.PUFF * 0.7))
	_ok("the planet is still up", sim.bodies.has(planet) and planet.pos.length() > sim.haze_r() * 0.7)
	_ok("the disc has a tenth of its hold on the planet", planet.grip > 0.05 and planet.grip < 0.2)
	# a passer goes by and leaves
	var lone := _quiet()
	lone.passing = true
	_run(lone, 240.0)
	print("  a sky left alone four minutes: %d bodies, the star %.3f" % [lone.bodies.size(), lone.mass])
	_ok("a star left alone barely grows", lone.mass < Sim.START * 1.02)

func _check_condensing() -> void:
	var sim := _quiet(3)
	# the ring's frost line is the ring's middle; this check is about the old one, 2.2 radii
	sim.frost = sim.star_r() * 2.2
	var poured := 0.0
	for i in 400:
		if i % 4 == 0 and i < 240:
			_puff(sim)
			poured += Sim.PUFF
		_run(sim, 0.25)
	var grains := 0
	var icy := 0
	var inside := 0
	var biggest := 0.0
	for b: Sim.Body in sim.bodies:
		if b.kind == Sim.Kind.GAS:
			continue
		grains += 1
		biggest = maxf(biggest, b.m)
		if b.ice > 0.3:
			icy += 1
	print("  sixty puffs, a hundred seconds: %d gas, %d solids (%d icy), the biggest %.4f (%.1f px); the star ate %.3f" % [
		sim.gas_count(), grains, icy, biggest, Sim.body_r(biggest), sim.mass - Sim.START])
	_ok("gas condenses into solids", grains > 0)
	_ok("some are ice", icy > 0)
	_ok("mass is kept", absf(sim.mass - Sim.START + _sky_mass(sim) - poured) < 1e-4)
	# two puffs inside the Roche radius stay two puffs
	var near := _quiet()
	var at: Vector2 = Vector2(near.roche_r() * 0.9, 0.0)
	for k in 2:
		var b: Sim.Body = near.add(Sim.Kind.GAS, Sim.PUFF, at + Vector2(0.0, 6.0 * k), near.circle_vel(at))
		b.dust = Sim.DUSTY
		b.age = Sim.COOL
	_run(near, 1.0)
	for b: Sim.Body in near.bodies:
		if b.kind != Sim.Kind.GAS:
			inside += 1
	_ok("nothing forms inside the Roche radius", inside == 0)
	# and outside it they make a grain, rock inside the frost line
	var out := _quiet()
	at = Vector2((out.roche_r() + out.frost_r()) * 0.5, 0.0)
	for k in 2:
		var b: Sim.Body = out.add(Sim.Kind.GAS, Sim.PUFF, at + Vector2(0.0, 6.0 * k), out.circle_vel(at))
		b.dust = Sim.DUSTY
		b.age = Sim.COOL
	_run(out, 0.5)
	var made: Sim.Body = null
	for b: Sim.Body in out.bodies:
		if b.kind != Sim.Kind.GAS:
			made = b
	_ok("two puffs make a grain of their dust", made != null and is_equal_approx(made.m, 2.0 * Sim.PUFF * Sim.DUSTY) and made.ice == 0.0)
	# a giant keeps the gas
	var gas := _quiet()
	var core: Sim.Body = gas.add(Sim.Kind.PLANET, Sim.CORE_M * 1.1, at, gas.circle_vel(at))
	var puff: Sim.Body = gas.add(Sim.Kind.GAS, Sim.PUFF, at + Vector2(0.0, 4.0), gas.circle_vel(at))
	puff.h = 0.7
	_run(gas, 6.0)
	_ok("a heavy planet keeps the gas and is a giant", core.m > Sim.CORE_M * 1.5 and core.kind == Sim.Kind.GIANT)

func _check_tide() -> void:
	var sim := _quiet()
	var m := 0.01
	var hold: float = sim.tear_r(m)
	var out: Vector2 = Vector2(hold * 1.08, 0.0)
	sim.add(Sim.Kind.PLANET, m, out, sim.circle_vel(out))
	_run(sim, 5.0)
	_ok("a planet outside its distance holds", sim.bodies.size() == 1)
	sim = _quiet()
	var at: Vector2 = Vector2(hold * 0.97, 0.0)
	sim.add(Sim.Kind.PLANET, m, at, sim.circle_vel(at))
	_run(sim, 0.2)
	_ok("inside it the tide has it in pieces", sim.bodies.size() >= 2 and sim.bodies.size() <= Sim.PIECES)
	_ok("and they weigh what it did", is_equal_approx(_sky_mass(sim), m))
	_ok("a grain is too small to tear", sim.tear_r(Sim.CRUMB) == 0.0)
	print("  the Roche radius %.0f px, a planet of %.3f torn at %.0f, the frost line %.0f, the disc %.0f" % [sim.roche_r(), m, hold, sim.frost_r(), sim.haze_r()])

func _check_star() -> void:
	var sim: RefCounted = Sim.new(5)
	sim.passing = false
	_run(sim, 60.0)
	_ok("a minute burns hydrogen into helium", sim.fuel < Sim.START * Sim.STAR_H and is_equal_approx(sim.fuel + sim.made[0], Sim.START * Sim.STAR_H))
	_ok("and makes light", sim.light > 0.0)
	print("  a new star: %.0f K, the core %.0f MK, %.3f light/s of its own, hydrogen for %.0f min" % [sim.temp(), sim.core_temp(), sim.light / 60.0, sim.fuel_time() / 60.0])
	_ok("a Sun is 5,800 K", absf(sim.temp() - 5800.0) < 1.0)
	# the helium lights at its core mass
	sim.made[0] = Sim.FLASH * Sim.START - 0.0001
	sim.fuel -= sim.made[0]
	_run(sim, 5.0)
	_ok("helium lights at a core of 0.45 Suns", sim.ignited[1] and sim.made[1] > 0.0)
	# carbon waits for a heavy star
	sim.made[1] = Sim.CARBON * Sim.START + 1.0
	_run(sim, 1.0)
	_ok("a carbon core waits on a light star", not sim.ignited[2])
	sim.mass = Sim.START * 9.0
	sim.fuel = sim.mass * 0.5
	_run(sim, 1.0)
	_ok("and lights on one of eight Suns", sim.ignited[2])
	var t := 0.0
	while sim.ending() == "" and t < 3600.0:
		sim.tick()
		t += Sim.STEP
	print("  from carbon to an iron core on a star of nine Suns: %.0f s, a giant %.2f, %.0f K" % [t, sim.swell, sim.temp()])
	_ok("the chain ends in an iron core", sim.ending() == "nova" and sim.ignited[5])
	var shares: Array = sim.layers()
	var sum := 0.0
	for s: float in shares:
		sum += s
	_ok("its layers are the whole star", shares.size() == 8 and absf(sum - 1.0) < 1e-4)
	var clock: float = sim.clock
	sim.tick()
	_ok("nothing moves once it has ended", sim.clock == clock)
	sim.lv.rich = 3
	sim.power.wind = 1
	var paid: int = sim.end()
	_ok("the supernova pays stardust", paid == 3 and sim.dust == 3 and sim.novas == 1)
	_ok("and leaves a new star with nothing bought", sim.mass == Sim.START and int(sim.lv.rich) == 0 and int(sim.power.wind) == 0 and not sim.ignited[1])
	var closed: bool = sim.bodies.size() > 0
	for b: Sim.Body in sim.bodies:
		# bound: slower than escape where it is
		if b.kind != Sim.Kind.GAS or b.vel.length_squared() >= 2.0 * sim.gm() / b.pos.length():
			closed = false
	_ok("among gas on closed paths", closed)
	# starving
	var dim: RefCounted = Sim.new(5)
	dim.passing = false
	dim.fuel = 0.001
	_run(dim, 3.0)
	_ok("with nothing to burn the star is dim", not dim.awake and dim.lit < 0.01 and dim.on("wind") == 0)
	dim.fuel = dim.mass * Sim.WAKE * 1.5
	_run(dim, 3.0)
	_ok("fed, it lights again", dim.awake and dim.cold == 0.0)
	dim.fuel = 0.0
	_run(dim, Sim.GRACE + 3.0)
	_ok("left dim, it lets go", dim.ending() == "fade")
	_ok("for a little stardust", dim.end() == Sim.FADE_DUST and dim.fades == 1 and dim.novas == 0)

func _check_rules() -> void:
	var sim := _quiet()
	sim.light = 1000.0
	var first: int = sim.cost("rich")
	_ok("the first rich-sky tile costs twelve", first == 12 and sim.buy("rich") and is_equal_approx(sim.light, 988.0))
	_ok("the finger brakes as often as the Flow tile lets it", is_equal_approx(sim.flow_gap(), Sim.FLOW) and sim.stream_gap() == sim.flow_gap())
	sim.lv.flow = 3
	_ok("and a level of it brakes sooner", is_equal_approx(sim.flow_gap(), Sim.FLOW * pow(Sim.FLOW_STEP, 3.0)))
	sim.lv.pure = 6
	_ok("pure gas stops at six", sim.is_done("pure") and not sim.buy("pure"))
	# the trickle holds the sky to its most and loses none of what drifts in
	var full := _quiet(13)
	full.passing = true
	full._pass_gap = 1e9
	# a full sky of puffs on circles in the ring, which the star does not eat
	for k in Sim.MOST:
		var at: Vector2 = Vector2.from_angle(TAU * k / Sim.MOST) * full.ring.y
		full.add(Sim.Kind.GAS, Sim.PUFF, at, full.circle_vel(at)).h = full.puff_h()
	var held: float = _sky_mass(full)
	_run(full, 60.0)
	_ok("the sky holds no more than its most", full.gas_count() <= Sim.MOST)
	_ok("and loses none of what drifted in", absf(_sky_mass(full) - held + full._owed_gas - Sim.TRICKLE * 60.0) < 0.001 and is_equal_approx(full.mass, Sim.START))
	sim.mass = Sim.START * 4.5
	_ok("two picks by four Suns", sim.owed() == 2)
	var two: Array = sim.offering()
	_ok("two that go different ways", two.size() == 2 and Sim.WAY[two[0]] != Sim.WAY[two[1]])
	_ok("a pick is taken", sim.pick(0) == two[0] and sim.owed() == 1)
	# kept
	sim.bodies.clear()
	var at: Vector2 = Vector2(sim.haze_r() * 0.8, 0.0)
	var rock: Sim.Body = sim.add(Sim.Kind.ROCK, 0.004, at, sim.circle_vel(at))
	rock.ice = 0.5
	sim.made[0] = 2.0
	sim.ignited[1] = true
	sim.save()
	var back: RefCounted = Sim.load_saved(7)
	_ok("a star read back is the same star", is_equal_approx(back.mass, sim.mass) and back.picks == 1 and int(back.lv.flow) == 3
		and back.bodies.size() == 1 and is_equal_approx(back.bodies[0].ice, 0.5) and back.ignited[1] and is_equal_approx(back.made[0], 2.0))
	# a file from before the gas
	var cfg := ConfigFile.new()
	cfg.set_value("star", "mass", 420.0)
	cfg.set_value("star", "dust", 4)
	cfg.set_value("lv", "meteor", 5)
	cfg.set_value("star", "bodies", [[4, 8.0, 300.0, 0.0, 0.0, 90.0, 0.6]])
	cfg.save(Sim.path)
	var old: RefCounted = Sim.load_saved(7)
	_ok("a star kept before the gas comes back without its sky", is_equal_approx(old.mass, 420.0) and old.dust == 4 and int(old.lv.rich) == 5 and old.bodies.is_empty())

## A steady hand for `minutes`: a finger down `held` of every ten seconds,
## braking every `flow_gap()` where `_spot` says.
func _pace(minutes: float, rng_seed: int, takes: String, held: float, sends: String) -> void:
	var sim: RefCounted = Sim.new(rng_seed)
	sim.born()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var since := 0.0
	var next_mark := 2.0
	var born := 0.0
	var dim := 0.0
	var pressed := 0
	var last_hit := 0.0
	var spot := Vector2.ZERO
	var spot_t := -100.0
	var most_ticks := 0
	var report := 60.0
	var t0 := Time.get_ticks_usec()
	print("pace: %.0f min, seed %d, powers %s, a finger down %.0f%% of the time, sending %s" % [minutes, rng_seed, takes, held * 100.0, sends])
	for i in int(minutes * 60.0 / Sim.STEP):
		var t: float = i * Sim.STEP
		since += Sim.STEP
		# the spot is chosen every three seconds; the finger is down in spells of ten seconds
		if t - spot_t >= 3.0:
			spot_t = t
			spot = _spot(sim, sends == "worlds")
		if since >= sim.flow_gap() and fmod(t, 10.0) < 10.0 * held:
			since = 0.0
			if sim.brake(spot, sim.press_r()) > 0:
				pressed += 1
				last_hit = t
		sim.tick()
		if not sim.awake:
			dim += Sim.STEP
		for e: Dictionary in sim.events:
			if String(e.kind) == "ignite":
				print("  %5.1f min  %s lights at %.1f Suns" % [(t - born) / 60.0, Sim.CHAIN[int(e.stage)], sim.suns()])
		sim.events.clear()
		while sim.owed() > 0:
			sim.pick(0 if takes == "first" else (1 if takes == "second" else rng.randi() % 2))
		var cheapest := ""
		for tile: String in Sim.TILES:
			if not sim.is_done(tile) and (cheapest == "" or sim.cost(tile) < sim.cost(cheapest)):
				cheapest = tile
		if cheapest != "":
			sim.buy(cheapest)
		if sim.suns() >= next_mark:
			print("  %5.1f min  %3.0f Suns  %s  %s" % [(t - born) / 60.0, next_mark, _sky(sim), _outside(sim, t - last_hit)])
			next_mark *= 2.0
		if t >= report:
			report += 600.0
			print("  %5.1f min  %.2f Suns  light %.0f (%s)  %s  %s" % [(t - born) / 60.0, sim.suns(), sim.light, str(sim.lv), _sky(sim), _outside(sim, t - last_hit)])
		most_ticks = maxi(most_ticks, sim.bodies.size())
		var how: String = sim.ending()
		if how != "":
			var was: float = sim.suns()
			var left: String = ["wd", "ns", "bh"][sim.remnant()]
			var shares: Array = sim.layers()
			var paid: int = sim.end()
			print("  end: %s remnant: %s at %.1f min, %.1f Suns" % [how, left, (t - born) / 60.0, was])
			print("  %5.1f min  %s at %.1f Suns, +%d stardust, dim %.0f s, %d presses braked something; h %.0f%% he %.0f%% c %.0f%% fe %.0f%% rock %.0f%%; powers %s" % [
				(t - born) / 60.0, how, was, paid, dim, pressed, shares[0] * 100.0, shares[1] * 100.0, shares[2] * 100.0, shares[6] * 100.0, shares[7] * 100.0, str(sim.power)])
			while sim.buy_perk() != "":
				pass
			born = t
			dim = 0.0
			pressed = 0
			next_mark = 2.0
	print("pace: %d supernovas, %d let go, the sky held %d at most, %.0f us a tick" % [sim.novas, sim.fades, most_ticks, float(Time.get_ticks_usec() - t0) / (minutes * 60.0 / Sim.STEP)])
	# the dearest sky: 300 bodies and the most relics, in a ring
	var crowd: RefCounted = Sim.new(rng_seed)
	crowd.passing = false
	crowd.burning = false
	for k in Sim.RELICS_MOST:
		crowd.add_relic(k % 3, Sim.START * 2.0, Vector2.from_angle(TAU * k / Sim.RELICS_MOST) * 2000.0, crowd.layers())
	for k in Sim.FULL:
		var at: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(crowd.haze_r() * 1.2, 1500.0)
		crowd.add(Sim.Kind.ROCK, 0.003, at, crowd.circle_vel(at))
	var t1 := Time.get_ticks_usec()
	for k in 600:
		crowd.tick()
	print("pace: 300 bodies and %d relics, %d bodies left, %.0f us a tick" % [crowd.relics.size(), crowd.bodies.size(), float(Time.get_ticks_usec() - t1) / 600.0])

## Where the bot presses: the heaviest solid outside the disc if it sends
## worlds, else the middle of the fullest of 24 slices of the ring outside it.
func _spot(sim: RefCounted, worlds: bool) -> Vector2:
	var rh: float = sim.haze_r()
	var best: Sim.Body = null
	var slices := PackedFloat32Array()
	slices.resize(24)
	var sum: Array[Vector2] = []
	sum.resize(24)
	sum.fill(Vector2.ZERO)
	for b: Sim.Body in sim.bodies:
		if b.pos.length() <= rh:
			continue
		if b.kind != Sim.Kind.GAS and (best == null or b.m > best.m):
			best = b
		var k := int(fposmod(b.pos.angle(), TAU) / TAU * 24.0) % 24
		slices[k] += b.m
		sum[k] += b.pos * b.m
	if worlds and best != null and best.m >= Sim.GRAIN_M:
		return best.pos
	var top := 0
	for k in 24:
		if slices[k] > slices[top]:
			top = k
	return sum[top] / slices[top] if slices[top] > 0.0 else Vector2.ZERO

## The gas left outside the disc, in puffs and Suns, and how long since a press braked anything.
func _outside(sim: RefCounted, since_hit: float) -> String:
	var n := 0
	var m := 0.0
	var rh: float = sim.haze_r()
	for b: Sim.Body in sim.bodies:
		if b.kind == Sim.Kind.GAS and b.pos.length() > rh:
			n += 1
			m += b.m
	return "outside the disc: %d gas, %.2f Suns; last braked %.0f s ago" % [n, m / Sim.START, since_hit]

func _sky(sim: RefCounted) -> String:
	var gas := 0
	var counts := [0, 0, 0, 0, 0, 0]
	var biggest := 0.0
	var solid := 0.0
	for b: Sim.Body in sim.bodies:
		counts[b.kind] += 1
		if b.kind == Sim.Kind.GAS:
			gas += 1
		else:
			biggest = maxf(biggest, b.m)
			solid += b.m
	return "sky: %d gas, %d grains, %d rocks, %d comets, %d planets, %d giants, solids %.3f, biggest %.1f px" % [
		gas, counts[1], counts[2], counts[3], counts[4], counts[5], solid, Sim.body_r(biggest)]

func _check_ring() -> void:
	var sim := _quiet(11)
	sim.born()
	var rh: float = sim.haze_r()
	_ok("the ring is laid from 1.15 to 1.75 of the newborn disc", is_equal_approx(sim.ring.x, rh * Sim.RING_IN) and is_equal_approx(sim.ring.y, rh * Sim.RING_OUT))
	_ok("the frost line is the ring's middle", is_equal_approx(sim.frost_r(), (sim.ring.x + sim.ring.y) * 0.5))
	_ok("it is RING puffs", sim.bodies.size() == Sim.RING)
	var ids := {}
	var one_way := true
	var mass := 0.0
	for b: Sim.Body in sim.bodies:
		mass += b.m
		one_way = one_way and b.pos.cross(b.vel) * sim.bodies[0].pos.cross(sim.bodies[0].vel) > 0.0
		if b.pos.length() >= sim.ring.x * 0.999:
			ids[b.id] = true
	_ok("all turning one way", one_way)
	# the falling few start at their far point, which may be past the ring's inner edge
	_ok("all but the falling few are in the ring", ids.size() >= Sim.RING - Sim.RING_FALLING)
	_ok("it weighs RING_M", absf(mass - Sim.RING_M) < Sim.RING_M * 0.1)
	_run(sim, 300.0)
	var held := 0
	for b: Sim.Body in sim.bodies:
		if ids.has(b.id) and b.kind == Sim.Kind.GAS and b.pos.length() > rh:
			held += 1
	_ok("left alone, the ring does not come down", held >= Sim.RING - Sim.RING_FALLING)
	_ok("the view shows the ring's edge at FRAME", is_equal_approx(sim.zoom() * sim.ring.y, Sim.FRAME))
	sim.mass = Sim.START * 20.0
	var wide: float = sim.press_r() * sim.zoom()
	sim.mass = Sim.START
	_ok("the press is the same under the finger at 1 and 20 Suns", is_equal_approx(wide, sim.press_r() * sim.zoom()) and is_equal_approx(wide, Sim.PRESS_R))
	# the brake: a body at R slowed by f comes down to R f^2 / (2 - f^2)
	var one := _quiet(3)
	var at := Vector2(655.0, 0.0)
	var b: Sim.Body = one.add(Sim.Kind.GAS, 0.05, at, one.circle_vel(at))
	var v0: float = b.vel.length()
	_ok("a press brakes what is under it", one.brake(at + Vector2(75.0, 0.0), 100.0) == 1 and is_equal_approx(b.vel.length(), v0 * 0.95) and b.sink == 1.0)
	_ok("and nothing past its edge", one.brake(at + Vector2(0.0, 5000.0), 100.0) == 0)
	_ok("a press on the star itself throws nothing", one.brake(Vector2.ZERO, 100.0) == 0)
	var near := 655.0
	for i in int(200.0 / Sim.STEP):
		one.tick()
		near = minf(near, b.pos.length())
	_ok("its nearest point is R f^2 / (2 - f^2)", absf(near - 655.0 * 0.9025 / 1.0975) < 655.0 * 0.02)
	# once, it winds in and pays; three times, it drops in and pays little
	var paid := []
	for presses: int in [1, 3]:
		var s := _quiet(5)
		var g: Sim.Body = s.add(Sim.Kind.GAS, 0.05, at, s.circle_vel(at))
		g.dust = 0.0
		for k in presses:
			s.brake(at, 100.0)
		var t := 0.0
		while s.bodies.size() > 0 and t < 600.0:
			s.tick()
			t += Sim.STEP
		_ok("pressed %d times it is eaten" % presses, s.bodies.is_empty())
		paid.append(s.light)
	_ok("a gentle brake pays light", paid[0] > 0.0)
	_ok("a long hold pays under a third of it", paid[1] < paid[0] / 3.0)
	# the trickle
	var far := _quiet(9)
	far.passing = true
	far._pass_gap = 1e9
	var was: float = far.trickle_rate()
	far.mass = Sim.START * 4.0
	_ok("the trickle grows with the star", is_equal_approx(far.trickle_rate(), was * pow(4.0, Sim.TRICKLE_UP)))
	far.mass = Sim.START
	_run(far, 120.0)
	var got := _sky_mass(far)
	_ok("two minutes of it is two tenths of a Sun", absf(got - Sim.TRICKLE * 120.0) < Sim.RING_M / Sim.RING * 1.5)
	var outer := true
	for p: Sim.Body in far.bodies:
		outer = outer and p.pos.length() > far.ring.y * 0.85
	_ok("it arrives at the ring's outer edge", outer)
	# a sim whose ring was cleared (a tutorial page) still works
	var bare := _quiet(2)
	bare.ring = Vector2.ZERO
	bare.passing = true
	bare._pass_gap = 1e9
	_run(bare, 5.0)
	_ok("no ring: the old view, and no trickle", is_equal_approx(bare.zoom(), 1.0) and is_finite(bare.press_r()) and bare.bodies.is_empty())
	# a new star is born clear of its ring
	for case: Array in [[1.2, false], [25.0, true]]:
		var dead := _quiet(4)
		dead.mass = Sim.START * float(case[0])
		if case[1]:
			dead.made[5] = Sim.IRON * Sim.START
		else:
			dead.cold = Sim.GRACE
		dead.end()
		var rel: Dictionary = dead.relics[0]
		var d: float = (rel.pos as Vector2).length()
		var lobe: float = d * pow(dead.mass / (3.0 * float(rel.m)), 1.0 / 3.0)
		_ok("the ring is inside half the new star's lobe (%s Suns)" % case[0], dead.ring.y < lobe * 0.5 + 1.0)
		_ok("and the new star has a ring", dead.gas_count() == Sim.RING)
	# the file
	var keep := _quiet(6)
	keep.born()
	keep.lv.reach = 2
	keep.dusty = 0.2
	keep.save()
	var back: RefCounted = Sim.load_saved(1)
	_ok("a star saved and read back keeps its ring", back.ring.is_equal_approx(keep.ring) and is_equal_approx(back.frost, keep.frost) and is_equal_approx(back.dusty, 0.2) and int(back.lv.reach) == 2 and back.bodies.size() == keep.bodies.size())
	var old := ConfigFile.new()
	old.load(Sim.path)
	old.set_value("star", "kept", 3)
	for key in ["ring", "frost", "dusty"]:
		old.erase_section_key("star", key)
	old.erase_section("lv")
	old.set_value("lv", "puff", 3)
	old.set_value("lv", "volley", 9)
	old.set_value("lv", "stream", 4)
	old.set_value("lv", "pure", 2)
	old.set_value("star", "mass", Sim.START * 3.0)
	old.set_value("star", "bodies", [])
	old.save(Sim.path)
	var kept3: RefCounted = Sim.load_saved(1)
	_ok("a KEPT 3 star's tiles carry over", int(kept3.lv.rich) == 3 and int(kept3.lv.reach) == 6 and int(kept3.lv.flow) == 4 and int(kept3.lv.pure) == 2)
	_ok("and it is given a newborn's ring", is_equal_approx(kept3.ring.y, Sim.STAR_R * Sim.HAZE * Sim.RING_OUT) and kept3.gas_count() == Sim.RING)
	# a ring that is not two finite numbers in the file falls back to the newborn's
	for bad: Variant in [[1.0, INF], [[1.0], [2.0]], ["a", "b"]]:
		var odd := ConfigFile.new()
		odd.load(Sim.path)
		odd.set_value("star", "kept", 4)
		odd.set_value("star", "ring", bad)
		odd.save(Sim.path)
		var fell: RefCounted = Sim.load_saved(1)
		_ok("a bad ring in the file (%s) falls back to the newborn's" % str(bad), is_equal_approx(fell.ring.y, Sim.STAR_R * Sim.HAZE * Sim.RING_OUT) and is_finite(fell.zoom()) and fell.zoom() > 0.0)
	# a full kept sky is given no more ring than it has room for
	var crowd := ConfigFile.new()
	crowd.set_value("star", "kept", 3)
	crowd.set_value("star", "mass", Sim.START)
	var rows := []
	for k in Sim.FULL - 10:
		rows.append([Sim.Kind.GAS, 0.01, 600.0 + k, 10.0, 0.0, 40.0, 0.7, 0.01, 0.0, 0.0])
	crowd.set_value("star", "bodies", rows)
	crowd.save(Sim.path)
	var packed: RefCounted = Sim.load_saved(1)
	_ok("a kept sky holding FULL - 10 is given 10 puffs and no more", packed.bodies.size() == Sim.FULL)

## The frost line of a default sim is the ring's middle, not 2.2 radii: two
## dusty pairs a hair inside it make rock, two a hair outside make ice with it.
func _check_frost() -> void:
	var sim := _quiet(8)
	var fr: float = sim.frost_r()
	_ok("a default sim's frost line is well past 2.2 radii", fr > sim.star_r() * 2.2 * 1.5)
	for pair: Array in [[fr - 40.0, 0.0], [fr + 40.0, 1.0]]:
		for k in 2:
			var at := Vector2(float(pair[0]), 6.0 * k)
			var b: Sim.Body = sim.add(Sim.Kind.GAS, Sim.PUFF, at, sim.circle_vel(at))
			b.dust = Sim.DUSTY
			b.age = Sim.COOL
	_run(sim, 0.5)
	var inner: Sim.Body = null
	var outer: Sim.Body = null
	for b: Sim.Body in sim.bodies:
		if b.kind != Sim.Kind.GAS:
			if b.pos.length() < fr:
				inner = b
			else:
				outer = b
	_ok("inside the frost line a pair makes rock", inner != null and inner.ice == 0.0)
	_ok("outside it a pair makes ice as well", outer != null and outer.ice > 0.0)
	sim.swell = 1.0
	_ok("a giant thaws the line outward", is_equal_approx(sim.frost_r(), sim.frost * (1.0 + Sim.GIANT)))

func _check_relics() -> void:
	var sim := _quiet()
	# a body at rest between the star and a relic of twice its mass falls toward the relic
	var rel: Dictionary = sim.add_relic(Sim.Relic.BH, sim.mass * 2.0, Vector2(2000.0, 0.0), sim.layers())
	var b: Sim.Body = sim.add(Sim.Kind.ROCK, 0.003, Vector2(1000.0, 0.0), Vector2.ZERO)
	_run(sim, 2.0)
	_ok("relic pulls", b.pos.x > 1000.0)
	# inside a black hole it is lost and the hole weighs more
	var was: float = rel.m
	var c: Sim.Body = sim.add(Sim.Kind.ROCK, 0.003, Vector2(2000.0, 0.0), Vector2.ZERO)
	sim.tick()
	_ok("black hole eats", not sim.bodies.has(c) and rel.m > was)
	_ok("lost event", sim.events.any(func(e): return e.kind == "lost"))
	# a white dwarf does not grow, and d = 0 is eaten, not divided by
	var wd: Dictionary = sim.add_relic(Sim.Relic.WD, 6.0, Vector2(-1500.0, 0.0), sim.layers())
	var d: Sim.Body = sim.add(Sim.Kind.GAS, Sim.PUFF, Vector2(-1500.0, 0.0), Vector2.ZERO)
	sim.tick()
	_ok("dwarf eats and stays", not sim.bodies.has(d) and is_equal_approx(float(wd.m), 6.0))
	# past the cap the farthest goes
	for k in Sim.RELICS_MOST:
		sim.add_relic(Sim.Relic.WD, 6.0, Vector2(100.0 + k, 0.0), sim.layers())
	_ok("relic cap", sim.relics.size() == Sim.RELICS_MOST and not sim.relics.has(rel))
	# the file: relics, far, drift and metal round-trip; a KEPT 2 file loads clean
	sim.drift = Vector2(300.0, -40.0)
	var g: Sim.Body = sim.add(Sim.Kind.ROCK, 0.003, Vector2(500.0, 0.0), Vector2.ZERO)
	g.metal = 0.3
	sim.save()
	var back: RefCounted = Sim.load_saved()
	_ok("relics kept", back.relics.size() == Sim.RELICS_MOST and back.far.size() == Sim.NEIGHBOURS and back.drift == sim.drift)
	_ok("metal kept", back.bodies.any(func(x): return is_equal_approx(x.metal, 0.3)))
	_ok("kept counts relics", int(Sim.kept().relics) == Sim.RELICS_MOST)
	# a true KEPT 2 file: nine-column bodies, no relics, far or drift
	var cfg := ConfigFile.new()
	cfg.load(Sim.path)
	cfg.set_value("star", "kept", 2)
	for key in ["relics", "far", "drift"]:
		cfg.erase_section_key("star", key)
	cfg.set_value("star", "bodies", (cfg.get_value("star", "bodies") as Array).map(func(row): return (row as Array).slice(0, 9)))
	cfg.save(Sim.path)
	var older: RefCounted = Sim.load_saved()
	_ok("old file clean", older.relics.is_empty() and older.far.size() == Sim.NEIGHBOURS and older.drift == Vector2.ZERO and older.bodies.size() > 0 and older.bodies.all(func(x): return x.metal == 0.0))
	# a 6-Sun star kept with a 1.3-Sun carbon core before the nebula end comes back just under the line
	cfg.set_value("star", "mass", Sim.START * 6.0)
	cfg.set_value("star", "fuel", Sim.START * 6.0 * 0.3)
	cfg.set_value("star", "env", Sim.START * 6.0 * 0.2)
	cfg.set_value("star", "made", [Sim.START * 1.0, Sim.START * 1.3, 0.0, 0.0, 0.0, 0.0])
	cfg.set_value("star", "ignited", [true, true, false, false, false, false])
	cfg.save(Sim.path)
	var tester: RefCounted = Sim.load_saved()
	var sums: float = tester.fuel + tester.env + tester.made[0] + tester.made[1]
	_ok("a kept carbon core does not shed on load", tester.ending() == "" and tester.made[1] < Sim.CARBON * Sim.START and is_equal_approx(sums, Sim.START * 5.3))

func _check_ends() -> void:
	# a 4-Sun star whose helium core reaches 1.06 Suns sheds a nebula and leaves a white dwarf
	var sim := _quiet()
	sim.mass = Sim.START * 4.0
	sim.fuel = sim.mass * 0.1
	sim.ignited[1] = true
	sim.made[0] = Sim.CARBON * Sim.START
	sim.made[1] = Sim.CARBON * Sim.START
	# every kilo of the star is accounted for, so none of it counts as rock
	sim.env = sim.mass - sim.fuel - sim.made[0] - sim.made[1]
	_ok("nebula end", sim.ending() == "nebula" and sim.remnant() == Sim.Relic.WD)
	_ok("dwarf mass", is_equal_approx(sim.remnant_mass(), (Sim.WD_M + Sim.WD_M_PER * 3.0) * Sim.START))
	var dust_was: int = sim.dust
	var paid: int = sim.end()
	var thin := 0.0
	for b: Sim.Body in sim.bodies:
		thin = maxf(thin, b.dust)
	_ok("a nebula's gas is not dusty", sim.bodies.size() > 0 and thin < 0.08)
	_ok("nebula pays", paid == Sim.NEBULA_DUST and sim.dust == dust_was + Sim.NEBULA_DUST)
	_ok("one relic", sim.relics.size() == 1 and int(sim.relics[0].kind) == Sim.Relic.WD)
	var d: float = sim.last_birth.d
	var from: Vector2 = sim.last_birth.from
	_ok("lobe rule", is_equal_approx(d, Sim.LOBE * sim.ring.y * (1.0 + sqrt(float(sim.relics[0].m) / sim.mass))) and is_equal_approx(from.length(), d))
	_ok("disc inside lobe", d / (1.0 + sqrt(float(sim.relics[0].m) / sim.mass)) >= sim.ring.y * Sim.LOBE * 0.999)
	_ok("drift moved", is_equal_approx(sim.drift.length(), d) and sim.far.size() == Sim.NEIGHBOURS)
	_ok("first end has a direction", from.is_finite() and from.length() > 1.0)
	_ok("the relic is where the birth says", (sim.relics[0].pos as Vector2).is_equal_approx(from))
	# a heavy enough star is no nebula: carbon lights for it instead
	var heavy := _quiet()
	heavy.mass = Sim.START * 9.0
	heavy.ignited[1] = true
	heavy.made[1] = Sim.CARBON * Sim.START
	_ok("no nebula from a heavy star", heavy.ending() == "")
	# a 10-Sun supernova leaves a neutron star, a 25-Sun one a black hole of 5 Suns; the relics shift
	var big := _quiet(3)
	big.mass = Sim.START * 10.0
	big.made[5] = Sim.IRON * Sim.START
	_ok("neutron star", big.ending() == "nova" and big.remnant() == Sim.Relic.NS and is_equal_approx(big.remnant_mass(), Sim.IRON * Sim.START))
	big.end()
	var first: Vector2 = big.relics[0].pos
	big.mass = Sim.START * 25.0
	big.made[5] = Sim.IRON * Sim.START
	_ok("black hole", big.remnant() == Sim.Relic.BH and is_equal_approx(big.remnant_mass(), 5.0 * Sim.START))
	big.end()
	_ok("relics shift", big.relics.size() == 2 and big.relics[0].pos != first and (big.relics[1].pos as Vector2).length() > (big.relics[0].pos as Vector2).length() * 0.5)
	# a supernova's gas is dusty, and the grain it makes is iron-dark
	var dusty := 0.0
	for b: Sim.Body in big.bodies:
		dusty = maxf(dusty, b.dust)
	_ok("metal-rich ashes", dusty > 0.1)
	var grain := _quiet(5)
	var at := Vector2(grain.haze_r() * 0.9, 0.0)
	var p1: Sim.Body = grain.add(Sim.Kind.GAS, Sim.PUFF, at, grain.circle_vel(at))
	var p2: Sim.Body = grain.add(Sim.Kind.GAS, Sim.PUFF, at + Vector2(10.0, 0.0), grain.circle_vel(at))
	for p in [p1, p2]:
		p.dust = 0.15
		p.age = Sim.COOL + 1.0
	_run(grain, 1.0)
	_ok("iron grain", grain.bodies.any(func(x): return x.kind != Sim.Kind.GAS and x.metal > Sim.IRONY))
	# a young sky's grain is not
	var young := _quiet(5)
	for p in [young.add(Sim.Kind.GAS, Sim.PUFF, at, young.circle_vel(at)), young.add(Sim.Kind.GAS, Sim.PUFF, at + Vector2(10.0, 0.0), young.circle_vel(at))]:
		p.dust = Sim.DUSTY
		p.age = Sim.COOL + 1.0
	_run(young, 1.0)
	_ok("plain grain", young.bodies.any(func(x): return x.kind != Sim.Kind.GAS) and not young.bodies.any(func(x): return x.kind != Sim.Kind.GAS and x.metal > Sim.IRONY))
	# a first game is born in gas, and flags it; a file that is there is not
	var first_game := _quiet(9)
	first_game.born()
	_ok("first cloud", first_game.gas_count() == Sim.RING and first_game.relics.is_empty() and first_game.fresh)
	DirAccess.remove_absolute(Sim.path)
	var none: RefCounted = Sim.load_saved(9)
	_ok("no file is a first game", none.fresh and none.gas_count() == Sim.RING)
	none.save()
	var again: RefCounted = Sim.load_saved(9)
	_ok("a kept star is not born again", not again.fresh)

func _check_giant() -> void:
	var sim := _quiet()
	var plain: float = sim.haze_r()
	sim.swell = 1.0
	_ok("giant disc", is_equal_approx(sim.haze_r(), plain * (1.0 + Sim.GIANT)))
	# and a giant's puff pays light near a plain star's. Not within a quarter:
	# measured over twenty seeds (2026-10-07) a giant's pays 0.69 of a plain
	# star's and a supergiant's 0.88 (before the pour moved, 0.18 and 0).
	# DRAG is a rate, not a share of a turn, and a turn at a giant's rim is
	# three times as long, so its puff goes round half a turn (a plain one
	# 2.4) and falls in still carrying speed the drag never took.
	var paid: Array[float] = []
	for sw in [0.0, 1.0, Sim.SUPER]:
		var one := _quiet(11)
		one.swell = sw
		_puff(one)
		_run(one, 200.0)
		paid.append(float(one.light))
	print("  light from one puff: plain %.4f, giant %.4f, supergiant %.4f" % paid)
	_ok("a giant's puff pays", paid[0] > 0.0 and paid[1] >= 0.6 * paid[0] and paid[2] >= 0.6 * paid[0])
	_ok("giant on screen", sim.seen_r() > 200.0 and sim.zoom() < 0.7)
	# a circle at 1.5 of the plain disc, parked for good on a plain star, spirals in once the star is a giant
	var parked := _quiet(2)
	var at := Vector2(parked.haze_r() * 1.5, 0.0)
	var b: Sim.Body = parked.add(Sim.Kind.ROCK, 0.003, at, parked.circle_vel(at))
	_run(parked, 60.0)
	var still: float = b.pos.length()
	parked.swell = 1.0
	_run(parked, 60.0)
	_ok("giant engulfs", not parked.bodies.has(b) or b.pos.length() < still * 0.9)
	# the swell comes with the helium flash, and goes to SUPER with carbon
	var lit := _quiet(4)
	lit.burning = true
	lit.ignited[1] = true
	_run(lit, Sim.SWELL * 1.2)
	_ok("flash swells", lit.swell > 0.95 and lit.swell <= 1.0)
	lit.ignited[2] = true
	_run(lit, Sim.SWELL * 1.2)
	_ok("carbon supergiant", lit.swell > 1.95)
	_ok("colour clamps", is_equal_approx(lit.giant(), 1.0))
