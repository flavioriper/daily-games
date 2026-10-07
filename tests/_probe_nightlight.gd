extends SceneTree

## Nightlight, headless: the physics first, then a bot at the real sim to say
## how fast the numbers are.
##
##     godot --headless --path . --script res://tests/_probe_nightlight.gd
##     godot --headless --path . --script res://tests/_probe_nightlight.gd -- pace [minutes] [seed] [first|second|random] [share of the time the button is held]
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
## `pace` holds the button (as fast as the Stream tile lets it), buys the
## cheapest tile it can, takes the first, the second or either of the two
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
			String(args[3]) if args.size() > 3 else "random", float(args[4]) if args.size() > 4 else 1.0)
	else:
		_check_disc()
		_check_condensing()
		_check_tide()
		_check_star()
		_check_rules()
		_check_relics()
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
	var poured := 0.0
	for i in 400:
		if i % 4 == 0 and i < 240:
			sim.pour()
			poured += sim.puff_mass()
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
	sim.lv.puff = 3
	sim.power.wind = 1
	var paid: int = sim.end()
	_ok("the supernova pays stardust", paid == 3 and sim.dust == 3 and sim.novas == 1)
	_ok("and leaves a new star with nothing bought", sim.mass == Sim.START and int(sim.lv.puff) == 0 and int(sim.power.wind) == 0 and not sim.ignited[1])
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
	var first: int = sim.cost("puff")
	_ok("the first puff tile costs twelve", first == 12 and sim.buy("puff") and is_equal_approx(sim.light, 988.0))
	_ok("and makes a puff half as heavy again", is_equal_approx(sim.puff_mass(), Sim.PUFF * 1.5))
	_ok("the button pours without a tile", sim.stream_gap() == Sim.STREAM)
	sim.lv.pure = 6
	_ok("pure gas stops at six", sim.is_done("pure") and not sim.buy("pure"))
	sim.lv.volley = 2
	sim.pour()
	_ok("a volley is three puffs", sim.gas_count() == 3)
	for i in 400:
		sim.pour()
	_ok("the sky holds no more than its most", sim.gas_count() <= Sim.MOST)
	_ok("and loses none of it", is_equal_approx(_sky_mass(sim), 401.0 * 3.0 * sim.puff_mass()))
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
	_ok("a star read back is the same star", is_equal_approx(back.mass, sim.mass) and back.picks == 1 and int(back.lv.volley) == 2
		and back.bodies.size() == 1 and is_equal_approx(back.bodies[0].ice, 0.5) and back.ignited[1] and is_equal_approx(back.made[0], 2.0))
	# a file from before the gas
	var cfg := ConfigFile.new()
	cfg.set_value("star", "mass", 420.0)
	cfg.set_value("star", "dust", 4)
	cfg.set_value("lv", "meteor", 5)
	cfg.set_value("star", "bodies", [[4, 8.0, 300.0, 0.0, 0.0, 90.0, 0.6]])
	cfg.save(Sim.path)
	var old: RefCounted = Sim.load_saved(7)
	_ok("a star kept before the gas comes back without its sky", is_equal_approx(old.mass, 420.0) and old.dust == 4 and int(old.lv.puff) == 5 and old.bodies.is_empty())

## A steady hand for `minutes`.
func _pace(minutes: float, rng_seed: int, takes: String, held: float) -> void:
	var sim: RefCounted = Sim.new(rng_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var since := 0.0
	var next_mark := 2.0
	var born := 0.0
	var dim := 0.0
	var poured := 0.0
	var most_ticks := 0
	var report := 60.0
	var t0 := Time.get_ticks_usec()
	print("pace: %.0f min, seed %d, powers %s, the button held %.0f%% of the time" % [minutes, rng_seed, takes, held * 100.0])
	for i in int(minutes * 60.0 / Sim.STEP):
		var t: float = i * Sim.STEP
		since += Sim.STEP
		# held in spells of ten seconds
		if since >= sim.stream_gap() and fmod(t, 10.0) < 10.0 * held:
			since = 0.0
			sim.pour()
			poured += sim.puff_mass() * sim.volley()
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
			print("  %5.1f min  %3.0f Suns  %s" % [(t - born) / 60.0, next_mark, _sky(sim)])
			next_mark *= 2.0
		if t >= report:
			report += 600.0
			print("  %5.1f min  %.2f Suns  light %.0f (%s)  %s" % [(t - born) / 60.0, sim.suns(), sim.light, str(sim.lv), _sky(sim)])
		most_ticks = maxi(most_ticks, sim.bodies.size())
		var how: String = sim.ending()
		if how != "":
			var was: float = sim.suns()
			var left: String = ["wd", "ns", "bh"][sim.remnant()]
			var shares: Array = sim.layers()
			var paid: int = sim.end()
			print("  end: %s remnant: %s at %.1f min, %.1f Suns" % [how, left, (t - born) / 60.0, was])
			print("  %5.1f min  %s at %.1f Suns, +%d stardust, dim %.0f s, poured %.1f; h %.0f%% he %.0f%% c %.0f%% fe %.0f%% rock %.0f%%; powers %s" % [
				(t - born) / 60.0, how, was, paid, dim, poured, shares[0] * 100.0, shares[1] * 100.0, shares[2] * 100.0, shares[6] * 100.0, shares[7] * 100.0, str(sim.power)])
			while sim.buy_perk() != "":
				pass
			born = t
			dim = 0.0
			poured = 0.0
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
	var cfg := ConfigFile.new()
	cfg.load(Sim.path)
	cfg.set_value("star", "kept", 2)
	cfg.erase_section_key("star", "relics")
	cfg.save(Sim.path)
	var older: RefCounted = Sim.load_saved()
	_ok("old file clean", older.relics.is_empty() and older.far.size() == Sim.NEIGHBOURS and older.drift == Vector2.ZERO and older.bodies.size() > 0)

func _check_ends() -> void:
	# a 4-Sun star whose helium core reaches 1.06 Suns sheds a nebula and leaves a white dwarf
	var sim := _quiet()
	sim.mass = Sim.START * 4.0
	sim.fuel = sim.mass * 0.5
	sim.ignited[1] = true
	sim.made[0] = Sim.CARBON * Sim.START
	sim.made[1] = Sim.CARBON * Sim.START
	_ok("nebula end", sim.ending() == "nebula" and sim.remnant() == Sim.Relic.WD)
	_ok("dwarf mass", is_equal_approx(sim.remnant_mass(), (Sim.WD_M + Sim.WD_M_PER * 3.0) * Sim.START))
	var dust_was: int = sim.dust
	var paid: int = sim.end()
	_ok("nebula pays", paid == Sim.NEBULA_DUST and sim.dust == dust_was + Sim.NEBULA_DUST)
	_ok("one relic", sim.relics.size() == 1 and int(sim.relics[0].kind) == Sim.Relic.WD)
	var d: float = sim.last_birth.d
	var from: Vector2 = sim.last_birth.from
	_ok("lobe rule", is_equal_approx(d, Sim.LOBE * sim.haze_r() * (1.0 + sqrt(float(sim.relics[0].m) / sim.mass))) and is_equal_approx(from.length(), d))
	_ok("disc inside lobe", d / (1.0 + sqrt(float(sim.relics[0].m) / sim.mass)) >= sim.haze_r() * Sim.LOBE * 0.999)
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
	_ok("first cloud", first_game.gas_count() == Sim.FIRST_CLOUD and first_game.relics.is_empty() and first_game.fresh)
	DirAccess.remove_absolute(Sim.path)
	var none: RefCounted = Sim.load_saved(9)
	_ok("no file is a first game", none.fresh and none.gas_count() == Sim.FIRST_CLOUD)
	none.save()
	var again: RefCounted = Sim.load_saved(9)
	_ok("a kept star is not born again", not again.fresh)
