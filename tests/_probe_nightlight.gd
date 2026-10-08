extends SceneTree

## Nightlight, headless: the physics first, then a bot at the real sim to say
## how fast the numbers are.
##
##     godot --headless --path . --script res://tests/_probe_nightlight.gd
##     godot --headless --path . --script res://tests/_probe_nightlight.gd -- pace [minutes] [seed] [first|second|random] [share of the time the finger is down] [gas|worlds] [stop=<Suns>] [novas=<n>] [perks=0] [powers=0]
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
## `pace` holds a finger on the ring, buys the cheapest tile it can, takes
## the first, the second or either of the two powers offered, buys a perk
## whenever the stardust reaches, and prints
## every milestone with what the sky held, a line a minute (the Suns, the
## light earned in that minute and where it came from, what was eaten, the
## system's counts, the tiles and the powers) and a sum for each life. Its
## two hands: `gas` is impatient (the fullest slice of the ring outside the
## disc, as often as the Flow tile lets it); `worlds` is patient (it presses
## the gas a quarter as often, so the ring stays full enough to make worlds,
## and presses every planet or giant on a closed path outside the disc until
## its path dips into the disc, counting each as sent once; it never presses
## a planetoid that is only passing, and says so). After
## the five: `stop=3` lifts the finger for good at three Suns, `novas=2`
## starts on a star with two supernovas behind it, `perks=0` buys no perk,
## `powers=0` takes each pick and puts the power out (two hands compared on
## the same star must not differ by the powers they drew).
## Everything runs on a throwaway file.

const Sim = preload("res://arcade/nightlight_sim.gd")

var _fails := 0
var _checks := 0

func _initialize() -> void:
	Sim.path = OS.get_user_data_dir() + "/_probe_nightlight.cfg"
	DirAccess.remove_absolute(Sim.path)
	var args := OS.get_cmdline_user_args()
	if args.has("pace"):
		# after the five: stop=<Suns> (the finger stops for good once the star weighs that),
		# novas=<n> (a star with that many supernovas behind it), perks=0 (no perk is bought),
		# powers=0 (each pick is taken and the power put out)
		var more := {}
		for k in range(6, args.size()):
			var pair := String(args[k]).split("=")
			if pair.size() == 2:
				more[pair[0]] = float(pair[1])
		_pace(float(args[1]) if args.size() > 1 else 60.0, int(args[2]) if args.size() > 2 else 1,
			String(args[3]) if args.size() > 3 else "random", float(args[4]) if args.size() > 4 else 1.0,
			String(args[5]) if args.size() > 5 else "gas", more)
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
		_check_pay()
		_check_worlds()
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

## `n` pairs of cooled puffs with `dust` of dust, evenly round a circle of
## `r`, the two of a pair 6 px apart along it and on the same circle, so they
## stay that near. Dust sticks STICK of the times a pair is looked at: one pair
## may wait minutes, forty of them do not.
func _pairs(sim: RefCounted, r: float, dust: float, n := 40) -> void:
	for k in n:
		for j in 2:
			var at := Vector2.from_angle(TAU * k / n + 6.0 * j / r) * r
			var b: Sim.Body = sim.add(Sim.Kind.GAS, Sim.PUFF, at, sim.circle_vel(at))
			b.dust = dust
			b.age = Sim.COOL

## Ticks until the sky holds a solid, `most` seconds at the longest: the
## first there is, in the tick it formed, or null.
func _first_solid(sim: RefCounted, most := 60.0) -> Sim.Body:
	for i in int(most / Sim.STEP):
		sim.tick()
		for b: Sim.Body in sim.bodies:
			if b.kind != Sim.Kind.GAS:
				return b
	return null

## Runs `seconds` and hands back what the far sky owed in them by its rule:
## `trickle_rate() * need()` summed over every tick, and the most the gas
## outside the disc came to on the way, counted here and not read from the
## sim's own running figure.
func _run_owed(sim: RefCounted, seconds: float) -> Vector2:
	var owed := 0.0
	var most := 0.0
	for i in int(seconds / Sim.STEP):
		owed += float(sim.trickle_rate()) * float(sim.need()) * Sim.STEP
		sim.tick()
		if i % 6 == 0:
			most = maxf(most, _gas_beyond(sim))
	return Vector2(owed, most)

## The gas outside the disc, counted body by body.
func _gas_beyond(sim: RefCounted) -> float:
	var rh: float = sim.haze_r()
	var out := 0.0
	for b: Sim.Body in sim.bodies:
		if b.kind == Sim.Kind.GAS and b.pos.length() >= rh:
			out += b.m
	return out

func _solid_count(sim: RefCounted) -> int:
	return sim.bodies.size() - sim.gas_count()

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
	# a ring left three minutes: its dust has stuck into grains, ice past the
	# frost line, and nothing was lost on the way
	var sim := _quiet(3)
	sim.born()
	var laid := _sky_mass(sim)
	_run(sim, 180.0)
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
	print("  a first ring, three minutes: %d gas, %d solids (%d icy), the biggest %.4f (%.1f px); the star ate %.3f" % [
		sim.gas_count(), grains, icy, biggest, Sim.body_r(biggest), sim.mass - Sim.START])
	_ok("gas condenses into solids", grains > 0)
	_ok("some are ice", icy > 0)
	_ok("mass is kept", absf(sim.mass - Sim.START + _sky_mass(sim) - laid) < 1e-4)
	# the grains gather over minutes, not in the ring's first second: a first
	# ring and an iron-rich one, at ten seconds, one minute, three and ten
	for rich: bool in [false, true]:
		var slow := _quiet(5)
		if rich:
			_die(slow)
			_die(slow)
			slow.relics.clear()
		else:
			slow.born()
		var held: Array[int] = []
		var t := 0.0
		for mark: float in [10.0, 60.0, 180.0, 600.0]:
			_run(slow, mark - t)
			t = mark
			held.append(_solid_count(slow))
		var worlds: Dictionary = slow.system()
		print("  %s ring (dust %.3f) left alone: %d solids at 10 s, %d at 60 s, %d at 180 s, %d at 600 s (%d planets, %d giants)" % [
			"an iron-rich" if rich else "a first", slow.dusty, held[0], held[1], held[2], held[3], worlds.planets, worlds.giants])
		_ok("%s ring's grains do not pop in at once (%d at ten seconds)" % ["an iron-rich" if rich else "a first", held[0]], held[0] <= Sim.SOLIDS / 6)
		_ok("they are still gathering at a minute (%d) and many by three (%d)" % [held[1], held[2]], held[1] > held[0] and held[1] < Sim.SOLIDS * 3 / 4 and held[2] >= Sim.SOLIDS / 2)
	# forty pairs inside the Roche radius stay puffs: were they to stick as
	# they do outside it, half a minute would make seven grains of them
	var near := _quiet()
	_pairs(near, near.roche_r() * 0.9, Sim.DUSTY)
	_run(near, 30.0)
	for b: Sim.Body in near.bodies:
		if b.kind != Sim.Kind.GAS:
			inside += 1
	_ok("nothing forms inside the Roche radius", inside == 0)
	# and outside it they make a grain, rock inside the frost line
	var out := _quiet()
	_pairs(out, (out.haze_r() + out.frost_r()) * 0.5, Sim.DUSTY)
	var made: Sim.Body = _first_solid(out)
	_ok("two puffs make a grain of their dust", made != null and is_equal_approx(made.m, 2.0 * Sim.PUFF * Sim.DUSTY) and made.ice == 0.0)
	var at: Vector2 = Vector2((out.roche_r() + out.frost_r()) * 0.5, 0.0)
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
	_ok("the finger brakes as often as the Flow tile lets it", is_equal_approx(sim.flow_gap(), Sim.FLOW))
	sim.lv.flow = 3
	_ok("and a level of it brakes sooner", is_equal_approx(sim.flow_gap(), Sim.FLOW * pow(Sim.FLOW_STEP, 3.0)))
	sim.lv.pure = 6
	_ok("pure gas stops at six", sim.is_done("pure") and not sim.buy("pure"))
	# the trickle holds the sky to its most and loses none of what drifts in
	var full := _quiet(13)
	full.passing = true
	full._pass_gap = 1e9
	# a sky with as many puffs as it may hold, on circles in the ring, which
	# the star does not eat; they are light, so the ring is half empty and the
	# far sky still feeds it
	for k in Sim.MOST:
		var at: Vector2 = Vector2.from_angle(TAU * k / Sim.MOST) * full.ring.y
		full.add(Sim.Kind.GAS, full.ring_m * 0.5 / Sim.MOST, at, full.circle_vel(at)).h = full.puff_h()
	full._gas_out = full.gas_outside()
	var held: float = _sky_mass(full)
	var came := _run_owed(full, 60.0)
	_ok("the sky holds no more than its most", full.gas_count() <= Sim.MOST)
	_ok("and loses none of what drifted in (%.3f)" % came.x, came.x > 0.5 and absf(_sky_mass(full) - held + full._owed_gas - came.x) < 0.001 and is_equal_approx(full.mass, Sim.START))
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
func _pace(minutes: float, rng_seed: int, takes: String, held: float, sends: String, more := {}) -> void:
	var sim: RefCounted = Sim.new(rng_seed)
	var behind := int(more.get("novas", 0))
	var stop := float(more.get("stop", 0.0))
	var perks := float(more.get("perks", 1.0)) > 0.0
	var powers := float(more.get("powers", 1.0)) > 0.0
	if behind > 0:
		for k in behind:
			_die(sim)
	else:
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
	var t0 := Time.get_ticks_usec()
	# the patient hand: the gaps gone by, the worlds it is pressing down and
	# the ones it has already been counted for this life
	var patient := sends == "worlds"
	var gaps := 0
	var sending := {}
	var counted := {}
	# this life: the light it earned (spent or not), how much of that was the
	# star's own burning, what it ate as gas and as solids; and this minute's
	var life := {"n": 1, "light": 0.0, "shine": 0.0, "ten": 0.0, "gas": 0.0, "solid": 0.0, "lump": 0.0, "torn": 0.0, "sent": 0, "passers": 0, "suns": sim.suns()}
	var minute := {"at": 60.0, "light": 0.0, "suns": sim.suns(), "gas": 0.0, "solid": 0.0, "shine": 0.0, "lump": 0.0, "torn": 0.0}
	var stopped := false
	print("pace: %.0f min, seed %d, powers %s, a finger down %.0f%% of the time, sending %s%s%s%s" % [minutes, rng_seed, takes, held * 100.0, sends,
		", %d supernovas behind it" % behind if behind > 0 else "", ", the finger stops at %.1f Suns" % stop if stop > 0.0 else "", ("" if perks else ", no perks") + ("" if powers else ", every power picked and put out")])
	print("    min   Suns  +Suns  light/min  ate gas  solids | planets giants rocks comets (all on closed paths) grains, worlds | gas (outside the disc: n, Suns) | tiles | the light: its own burning, solids eaten, the Furnace, the disc's gas | powers")
	for i in int(minutes * 60.0 / Sim.STEP):
		var t: float = i * Sim.STEP
		since += Sim.STEP
		# the spot is chosen every three seconds; the finger is down in spells of ten seconds
		if t - spot_t >= 3.0:
			spot_t = t
			spot = _spot(sim)
		if stop > 0.0 and not stopped and sim.suns() >= stop:
			stopped = true
			print("  %5.1f min  the finger stops at %.2f Suns  %s" % [(t - born) / 60.0, sim.suns(), _outside(sim, t - last_hit)])
		if since >= sim.flow_gap() and fmod(t, 10.0) < 10.0 * held and not stopped:
			since = 0.0
			gaps += 1
			var hit := 0
			if patient:
				# a world it was pressing that has come down is sent, once
				life.sent += _sent(sim, sending, counted)
				var world := _world(sim)
				if world != null:
					sending[world.id] = true
					# never a passer: `_world` takes only what is on a closed path
					if is_inf(_nearest(sim, world)):
						life.passers += 1
					hit = sim.brake(world.pos, sim.press_r())
				elif gaps % 4 == 0:
					hit = sim.brake(spot, sim.press_r())
			else:
				hit = sim.brake(spot, sim.press_r())
			if hit > 0:
				pressed += 1
				last_hit = t
		var had: float = sim.light
		sim.tick()
		life.light += sim.light - had
		minute.light += sim.light - had
		if t - born < 600.0:
			life.ten += sim.light - had
		if not sim.awake:
			dim += Sim.STEP
		for k in sim.events.size():
			var e: Dictionary = sim.events[k]
			match String(e.kind):
				"ignite":
					print("  %5.1f min  %s lights at %.1f Suns" % [(t - born) / 60.0, Sim.CHAIN[int(e.stage)], sim.suns()])
				"shine":
					life.shine += float(e.e)
					minute.shine += float(e.e)
				"eat":
					var what := "gas" if bool(e.gas) else "solid"
					life[what] += float(e.m)
					minute[what] += float(e.m)
					# all a solid paid, from its first drag to its last, is counted
					# where it is eaten
					if not bool(e.gas):
						minute.lump += float(e.e)
						life.lump += float(e.e)
				"shed":
					# the Furnace's light comes just after a `tear`, where it was
					if k > 0 and String(sim.events[k - 1].kind) == "tear" and sim.events[k - 1].at == e.at:
						minute.torn += float(e.e)
						life.torn += float(e.e)
		sim.events.clear()
		if t - born >= float(minute.at):
			var n: Dictionary = sim.system()
			var grains := 0
			for b: Sim.Body in sim.bodies:
				if b.kind == Sim.Kind.GRAIN:
					grains += 1
			# `system()` counts what is on a closed path, so these are the worlds
			var bound: int = int(n.planets) + int(n.giants)
			var out := _outside(sim, t - last_hit)
			print("  %5.0f  %5.2f  %+5.2f  %9.1f  %7.3f  %6.4f | %2d %2d %2d %2d %2d %2d | %3d (%s) | %s | %.0f %.0f %.0f %.0f | %s" % [float(minute.at) / 60.0, sim.suns(), sim.suns() - float(minute.suns), minute.light,
				float(minute.gas) / Sim.START, float(minute.solid) / Sim.START, n.planets, n.giants, n.rocks, n.comets, grains, bound, sim.gas_count(),
				out.substr(18, out.find(";") - 18), "%d %d %d %d" % [sim.lv.reach, sim.lv.flow, sim.lv.rich, sim.lv.pure],
				minute.shine, minute.lump, minute.torn, float(minute.light) - float(minute.shine) - float(minute.lump) - float(minute.torn),
				" ".join(Sim.POWERS.filter(func(w: String) -> bool: return int(sim.power[w]) > 0).map(func(w: String) -> String: return "%s %d" % [w, sim.power[w]]))])
			minute = {"at": float(minute.at) + 60.0, "light": 0.0, "suns": sim.suns(), "gas": 0.0, "solid": 0.0, "shine": 0.0, "lump": 0.0, "torn": 0.0}
		while sim.owed() > 0:
			sim.pick(0 if takes == "first" else (1 if takes == "second" else rng.randi() % 2))
			if not powers:
				for which: String in Sim.POWERS:
					sim.power[which] = 0
		var cheapest := ""
		for tile: String in Sim.TILES:
			if not sim.is_done(tile) and (cheapest == "" or sim.cost(tile) < sim.cost(cheapest)):
				cheapest = tile
		if cheapest != "":
			sim.buy(cheapest)
		if sim.suns() >= next_mark:
			print("  %5.1f min  %3.0f Suns  %s  %s" % [(t - born) / 60.0, next_mark, _sky(sim), _outside(sim, t - last_hit)])
			next_mark *= 2.0
		most_ticks = maxi(most_ticks, sim.bodies.size())
		var how: String = sim.ending()
		if how != "":
			var was: float = sim.suns()
			var left: String = ["wd", "ns", "bh"][sim.remnant()]
			var shares: Array = sim.layers()
			var had_powers := str(sim.power)
			var paid: int = sim.end()
			print("  end: %s remnant: %s at %.1f min, %.1f Suns" % [how, left, (t - born) / 60.0, was])
			print("  %5.1f min  %s at %.1f Suns, +%d stardust, dim %.0f s, %d presses braked something; h %.0f%% he %.0f%% c %.0f%% fe %.0f%% rock %.0f%%; powers %s" % [
				(t - born) / 60.0, how, was, paid, dim, pressed, shares[0] * 100.0, shares[1] * 100.0, shares[2] * 100.0, shares[6] * 100.0, shares[7] * 100.0, had_powers])
			_life(life, (t - born) / 60.0, was)
			while perks and sim.buy_perk() != "":
				pass
			born = t
			dim = 0.0
			pressed = 0
			next_mark = 2.0
			stopped = false
			sending.clear()
			counted.clear()
			life = {"n": int(life.n) + 1, "light": 0.0, "shine": 0.0, "ten": 0.0, "gas": 0.0, "solid": 0.0, "lump": 0.0, "torn": 0.0, "sent": 0, "passers": 0, "suns": sim.suns()}
			minute = {"at": 60.0, "light": 0.0, "suns": sim.suns(), "gas": 0.0, "solid": 0.0, "shine": 0.0, "lump": 0.0, "torn": 0.0}
			print("  a new star: %.1f Suns, ring %.2f Suns at %.3f dust, perks %s" % [sim.suns(), _sky_mass(sim) / Sim.START, sim.dusty, str(sim.perk)])
	_life(life, minutes - born / 60.0, sim.suns())
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

## A life's sum: the light it earned a minute, over its first ten minutes and
## over the whole of it, where that light came from, what the star ate, how
## fast it grew and how many worlds the patient hand sent.
func _life(life: Dictionary, mins: float, suns_now: float) -> void:
	if mins <= 0.0:
		return
	var gas_light: float = float(life.light) - float(life.shine) - float(life.lump) - float(life.torn)
	print("  life %d: %.1f min; light %.0f, %.1f a minute (the first ten minutes %.1f a minute; %.0f of it the star's own burning); ate %.2f Suns of gas and %.3f of solids; solids eaten paid %.0f, the Furnace %.0f, the disc's gas %.0f; %.2f Suns a minute; light a minute: its own %.1f, gas %.1f, solids %.1f, the Furnace %.1f; %d worlds sent, %d passers pressed" % [
		life.n, mins, life.light, float(life.light) / mins, float(life.ten) / minf(mins, 10.0), life.shine, float(life.gas) / Sim.START, float(life.solid) / Sim.START,
		life.lump, life.torn, gas_light, (suns_now - float(life.suns)) / mins,
		float(life.shine) / mins, gas_light / mins, float(life.lump) / mins, float(life.torn) / mins, life.sent, life.passers])

## The world the patient hand presses: the heaviest planet or giant on a
## CLOSED path (the rule `system()` counts by: a planetoid passing through is
## not the ring's) that is outside the disc and whose path does not yet dip
## into it. None if there is none.
func _world(sim: RefCounted) -> Sim.Body:
	var rh: float = sim.haze_r()
	var best: Sim.Body = null
	for b: Sim.Body in sim.bodies:
		if b.kind != Sim.Kind.PLANET and b.kind != Sim.Kind.GIANT:
			continue
		var near := _nearest(sim, b)
		if is_finite(near) and b.pos.length() > rh and near > rh * 0.95 and (best == null or b.m > best.m):
			best = b
	return best

## The nearest point of a body's path to the star; INF on an open path.
func _nearest(sim: RefCounted, b: Sim.Body) -> float:
	var mu: float = sim.gm()
	var r := b.pos.length()
	var energy := b.vel.length_squared() * 0.5 - mu / r
	if energy >= 0.0:
		return INF
	var turn := b.pos.cross(b.vel)
	var a := -mu / (2.0 * energy)
	return a * (1.0 - sqrt(maxf(0.0, 1.0 + 2.0 * energy * turn * turn / (mu * mu))))

## How many of the worlds being pressed have come down since the last look:
## still a solid on a closed path, and in the disc or on a path whose
## nearest point is inside 0.95 of it. Each is counted once in a life
## (`counted`) and taken off the list. One that is no longer there without
## having come down (gathered into another, flung out, taken by a relic) is
## taken off the list and not counted: between two looks, 0.6 s at most, a
## world cannot go from a path clear of the disc into the star.
func _sent(sim: RefCounted, sending: Dictionary, counted: Dictionary) -> int:
	if sending.is_empty():
		return 0
	var still := {}
	var went := 0
	var rh: float = sim.haze_r()
	for b: Sim.Body in sim.bodies:
		if not sending.has(b.id) or b.kind == Sim.Kind.GAS:
			continue
		var near := _nearest(sim, b)
		if is_inf(near):
			continue
		if b.pos.length() > rh and near > rh * 0.95:
			still[b.id] = true
		elif not counted.has(b.id):
			counted[b.id] = true
			went += 1
	sending.clear()
	sending.merge(still)
	return went

## The star dies as the bot's own do: a supernova at 19 Suns with an iron
## core, a quarter of a Sun of silicon over it and the rest hydrogen and
## helium, so the next ring's dust is what a played life leaves.
func _die(sim: RefCounted) -> void:
	sim.mass = Sim.START * 19.0
	sim.made.assign([0.0, 0.0, 0.0, 0.0, Sim.NEXT * Sim.START, Sim.IRON * Sim.START])
	sim.fuel = sim.mass * 0.4
	sim.env = sim.mass - sim.fuel - (Sim.NEXT + Sim.IRON) * Sim.START
	sim.end()

## Where the bot presses for gas: the middle of the fullest of 24 slices of
## the ring outside the disc.
func _spot(sim: RefCounted) -> Vector2:
	var rh: float = sim.haze_r()
	var slices := PackedFloat32Array()
	slices.resize(24)
	var sum: Array[Vector2] = []
	sum.resize(24)
	sum.fill(Vector2.ZERO)
	for b: Sim.Body in sim.bodies:
		if b.pos.length() <= rh:
			continue
		var k := int(fposmod(b.pos.angle(), TAU) / TAU * 24.0) % 24
		slices[k] += b.m
		sum[k] += b.pos * b.m
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
	var falling_m := 0.0
	for k in sim.bodies.size():
		var b: Sim.Body = sim.bodies[k]
		mass += b.m
		one_way = one_way and b.pos.cross(b.vel) * sim.bodies[0].pos.cross(sim.bodies[0].vel) > 0.0
		# the first RING_FALLING are laid falling in; the rest start in the ring
		if k < Sim.RING_FALLING:
			falling_m += b.m
		elif b.pos.length() >= sim.ring.x * 0.999:
			ids[b.id] = true
	_ok("all turning one way", one_way)
	# the falling few start at their far point, which may be past the ring's inner edge
	_ok("all but the falling few are in the ring", ids.size() >= Sim.RING - Sim.RING_FALLING)
	_ok("it weighs RING_M", absf(mass - Sim.RING_M) < Sim.RING_M * 0.1)
	_run(sim, 300.0)
	var came := 0
	for b: Sim.Body in sim.bodies:
		if ids.has(b.id) and b.pos.length() < sim.haze_r():
			came += 1
	_ok("left alone, nothing of the ring but the falling few is in the disc after five minutes", came == 0)
	_ok("and the star has eaten no more than the falling few weigh (%.3f of %.3f)" % [sim.eaten, falling_m], sim.eaten <= falling_m + 1e-6)
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
	# the star's growth brings some of the ring down, and not all of it
	var eats: Array[float] = []
	for grows: bool in [false, true]:
		var gro := _quiet(5)
		gro.born()
		var each := Sim.START * 0.15 / (120.0 / Sim.STEP)
		for i in int(720.0 / Sim.STEP):
			if grows and i < int(120.0 / Sim.STEP):
				gro.mass += each
				gro.fuel += each
			gro.tick()
		eats.append(float(gro.eaten))
	print("  a star that grows 15%% in two minutes eats %.2f of the ring's %.1f in ten more (%.0f%%); left alone, %.2f" % [eats[1], Sim.RING_M, eats[1] / Sim.RING_M * 100.0, eats[0]])
	_ok("the star's growth brings some of the ring down (%.0f%%), and not all of it" % (eats[1] / Sim.RING_M * 100.0), eats[1] > eats[0] + Sim.RING_M * 0.05 and eats[1] < Sim.RING_M * 0.5 and eats[0] < Sim.RING_M * 0.05)
	# and so does the ring a supernova leaves, however many came before it: it
	# is RING_M, held to RING_MOST of the newborn
	for behind: int in [1, 2, 4]:
		var later := _quiet(5)
		for k in behind:
			_die(later)
		later.relics.clear()
		later.eaten = 0.0
		var ring_m := _sky_mass(later)
		var newborn: float = later.mass
		var step: float = newborn * 0.15 / (120.0 / Sim.STEP)
		for i in int(720.0 / Sim.STEP):
			if i < int(120.0 / Sim.STEP):
				later.mass += step
				later.fuel += step
			later.tick()
		print("  after %d supernovas the ring is %.2f Suns, and a star that grows 15%% in two minutes eats %.0f%% of it in ten more" % [behind, ring_m / Sim.START, later.eaten / ring_m * 100.0])
		_ok("a ring after %d supernovas is no more than RING_MOST of the newborn (%.2f Suns)" % [behind, ring_m / Sim.START], ring_m <= Sim.RING_MOST * newborn * 1.1)
		_ok("and under half of it comes down by itself (%.0f%%)" % (later.eaten / ring_m * 100.0), later.eaten < ring_m * 0.5)
	# the richer sky is in what drifts in, not in a heavier ring
	var rich := _quiet(9)
	var plain: float = rich.trickle_rate()
	rich.novas = 2
	_ok("every supernova so far makes RICHER more gas drift in", is_equal_approx(rich.trickle_rate(), plain * (1.0 + Sim.RICHER * 2.0)))
	# the trickle, fed by need
	var far := _quiet(9)
	far.passing = true
	far._pass_gap = 1e9
	var was: float = far.trickle_rate()
	far.mass = Sim.START * 4.0
	_ok("the most the far sky gives goes by the star's Suns to the power TRICKLE_UP", is_equal_approx(far.trickle_rate(), was * pow(4.0, Sim.TRICKLE_UP)))
	far.mass = Sim.START
	_ok("an empty ring is fed in full and a ring at its birth weight not at all", is_equal_approx(far.need(), 1.0) and is_equal_approx(far.ring_m, minf(Sim.RING_M, Sim.RING_MOST * far.mass)))
	var into_empty := _run_owed(far, 120.0)
	var got := _sky_mass(far)
	_ok("what drifts into an empty ring is what the rule owes (%.2f, where the most in two minutes is %.2f)" % [into_empty.x, was * 120.0], absf(got + far._owed_gas - into_empty.x) < 1e-4 and into_empty.x < was * 120.0)
	_ok("and it makes the ring up to its birth weight and no further (%.2f of %.2f)" % [got, far.ring_m], got > far.ring_m * (1.0 - exp(-was * 120.0 / far.ring_m)) - 3.0 * Sim.RING_M / Sim.RING and got <= far.ring_m + Sim.RING_M / Sim.RING + 1e-6)
	var inner := 0
	var outer := 0
	var in_ring := true
	for p: Sim.Body in far.bodies:
		var pr := p.pos.length()
		in_ring = in_ring and pr > far.ring.x * 0.98 and pr < far.ring.y * 1.02
		if pr < far.frost:
			inner += 1
		else:
			outer += 1
	_ok("it arrives all over the ring (%d inside its middle, %d outside)" % [inner, outer], in_ring and inner > far.bodies.size() / 5 and outer > far.bodies.size() / 5)
	# with the gas outside at the ring's birth weight, two minutes add nothing
	var brim := _quiet(9)
	brim.passing = true
	brim._pass_gap = 1e9
	for k in Sim.RING:
		var at_k: Vector2 = Vector2.from_angle(TAU * k / Sim.RING) * lerpf(brim.ring.x, brim.ring.y, 0.2 + 0.6 * fmod(k * 0.381, 1.0))
		var g_k: Sim.Body = brim.add(Sim.Kind.GAS, brim.ring_m / Sim.RING, at_k, brim.circle_vel(at_k))
		g_k.dust = 0.0
	brim._gas_out = brim.gas_outside()
	var brim_m := _sky_mass(brim)
	_run(brim, 120.0)
	_ok("a ring at its birth weight is given nothing in two minutes", brim.bodies.size() == Sim.RING and absf(_sky_mass(brim) - brim_m) < 1e-6 and brim._owed_gas < 1e-6)
	# with none outside (a star whose disc is past the ring) they add the full
	# rate: it lands in the disc, is not the ring's, and is eaten with no hand
	var grown := _quiet(9)
	grown.passing = true
	grown._pass_gap = 1e9
	grown.mass = Sim.START * 6.0
	var grown_m: float = grown.mass
	var full_rate: float = grown.trickle_rate()
	var into_disc := _run_owed(grown, 120.0)
	var all_in: float = grown.mass - grown_m + _sky_mass(grown) + grown._owed_gas
	_ok("the disc of a 6-Sun star is past the ring, so none of its gas is outside", grown.haze_r() > grown.ring.y and into_disc.y == 0.0)
	_ok("and two minutes add trickle_rate() * 120 (%.2f Suns of %.2f)" % [all_in / Sim.START, full_rate * 120.0 / Sim.START], absf(all_in - into_disc.x) < 1e-4 and absf(all_in - full_rate * 120.0) < full_rate * 120.0 * 0.03)
	_ok("which the star eats with no hand", grown.mass - grown_m > all_in * 0.3)
	# an untouched first star, the trickle on: fifteen minutes eat no more than
	# the falling few, and the ring is never more than a puff over its weight
	var idle := _quiet(11)
	idle.passing = true
	idle._pass_gap = 1e9
	idle.born()
	var few := 0.0
	for k in Sim.RING_FALLING:
		few += idle.bodies[k].m
	var idle_most := _run_owed(idle, 900.0)
	print("  an untouched first star, fifteen minutes with the trickle on: ate %.3f (the falling few weigh %.3f), the far sky gave %.3f, the gas outside the disc at most %.3f of the ring's %.3f, %d solids" % [
		idle.eaten, few, idle_most.x, idle_most.y, idle.ring_m, _solid_count(idle)])
	_ok("an untouched star with the trickle on eats no more than the falling few in fifteen minutes (%.3f of %.3f)" % [idle.eaten, few], idle.eaten <= few + 1e-6)
	_ok("and the gas outside the disc is never more than a puff over the ring's birth weight (%.3f of %.3f)" % [idle_most.y, idle.ring_m], idle_most.y <= idle.ring_m + Sim.RING_M / Sim.RING + 1e-6)
	# why that star does not go on to dim: at one Sun the helium flash comes
	# before the hydrogen is out, and a giant's disc is past the whole ring it
	# was born with, so that ring falls in. (What the far sky then gives it is
	# set down where the envelope has carried the ring, 1,139 px and out, which
	# is outside a one-Sun giant's disc: see the checks on a giant below.)
	var lone := _quiet(11)
	var to_flash: float = Sim.FLASH * Sim.START / lone._plain_burn()
	print("  a star of one Sun left alone: the helium flash at %.0f min, the hydrogen out at %.0f; a giant's disc is %.0f px and the ring ends at %.0f" % [
		to_flash / 60.0, lone.fuel_time() / 60.0, lone.haze_r() * (1.0 + Sim.GIANT), lone.ring.y])
	_ok("at one Sun the helium flash (%.0f min) comes before the hydrogen is out (%.0f min)" % [to_flash / 60.0, lone.fuel_time() / 60.0], to_flash < lone.fuel_time() and to_flash > 3600.0)
	lone.swell = 1.0
	_ok("and a one-Sun giant's disc is past the whole ring", lone.haze_r() > lone.ring.y)
	# a giant does not swallow the sky: its mouth is past the middle of the
	# ring it was born with, and what drifts in is set down where its envelope
	# has carried that ring, outside the mouth and inside the disc; what it
	# gains (eaten and winding in) must stay a Sun or so a minute with the
	# tiles a steady hand has by then (it was 4.9 Suns a minute when the
	# trickle grew with the star's Suns)
	var big := _quiet(9)
	big.passing = true
	big._pass_gap = 1e9
	big.mass = Sim.START * 12.0
	big.swell = 1.0
	big.lv.rich = 6
	_ok("a 12-Sun giant's mouth is past the middle of the ring it was born with, and inside where the gas drifts in now", big.star_r() * Sim.EAT > (big.ring.x + big.ring.y) * 0.5 and big.star_r() * Sim.EAT < big.ring.x * big.envelope() and big.haze_r() > big.ring.y * big.envelope())
	var was_m: float = big.mass
	_run(big, 60.0)
	var gained: float = (big.mass - was_m + _sky_mass(big)) / Sim.START
	print("  a 12-Sun giant with six levels of Rich and no hand gains %.2f Suns in a minute (%.2f with no tile; at 4, 8 and 16 Suns %.2f, %.2f and %.2f)" % [
		gained, gained / (1.0 + Sim.RICH_STEP * 6.0), Sim.TRICKLE * pow(4.0, Sim.TRICKLE_UP) * 6.0, Sim.TRICKLE * pow(8.0, Sim.TRICKLE_UP) * 6.0, Sim.TRICKLE * pow(16.0, Sim.TRICKLE_UP) * 6.0])
	_ok("a giant does not swallow the sky: under a Sun and a half a minute (%.2f)" % gained, gained > 0.0 and gained < 1.5)
	# what drifts in round a giant lands where its envelope has carried the
	# ring: outside its mouth and inside its disc, so it is there to be seen
	# and pressed, winds in and pays. (Set down at the newborn's ring, as it
	# was, a giant's mouth is past it: at 13 Suns every puff was eaten in the
	# tick it landed, for no light.)
	for case: Array in [[8.0, 1.0], [13.0, Sim.SUPER]]:
		var g := _quiet(9)
		g.passing = true
		g._pass_gap = 1e9
		g.mass = Sim.START * float(case[0])
		g.swell = float(case[1])
		var g_m: float = g.mass
		var mouth: float = g.star_r() * Sim.EAT
		var first: Sim.Body = null
		var first_at := 0
		var up_at_ten := false
		var landed := 0
		var clear := true
		var land_in := INF
		var far_out := 0.0
		for i in int(20.0 / Sim.STEP):
			var had: int = g._next_id
			g.tick()
			for p: Sim.Body in g.bodies:
				if p.id < had or p.kind != Sim.Kind.GAS:
					continue
				landed += 1
				var pr := p.pos.length()
				land_in = minf(land_in, pr)
				far_out = maxf(far_out, pr)
				clear = clear and pr > mouth and pr < g.haze_r()
				if first == null:
					first = p
					first_at = i
			if first != null and i == first_at + int(10.0 / Sim.STEP):
				up_at_ten = g.bodies.has(first)
		_ok("at %s Suns, swell %s, what drifts in lands outside the mouth and inside the disc (%d puffs at %.0f to %.0f px, the mouth %.0f, the disc %.0f)" % [case[0], case[1], landed, land_in, far_out, mouth, g.haze_r()],
			landed > 10 and clear and is_equal_approx(g.mass, g_m))
		_ok("and a puff of it is still a body ten seconds on", first != null and up_at_ten)
		# no more of it: the first puff is followed down
		g.passing = false
		var took := 20.0 - first_at * Sim.STEP
		while g.bodies.has(first) and took < 1800.0:
			g.tick()
			took += Sim.STEP
		var gave: float = first.paid + first.e
		print("  round a giant of %s Suns (swell %s) the first puff to drift in was eaten %.0f s on and paid %.4f light, %.2f of a perfect spiral's" % [
			case[0], case[1], took, gave, gave / (first.m * g.spiral_light())])
		_ok("and it has paid light by the time it is eaten (%.4f)" % gave, not g.bodies.has(first) and g.mass > g_m and gave > 0.0)
	# with the sky full, what drifts in is shared out among the ring's puffs
	# and no one puff takes it: three Suns (the disc covers the ring's inner
	# part, so the need never closes), six levels of Rich (21 puffs a second
	# at the most), two minutes with no hand. One puff took all of it before:
	# 5.8 of mass, 350 puffs' worth, a minute in
	var brim_sky := _quiet(9)
	brim_sky.passing = true
	brim_sky._pass_gap = 1e9
	brim_sky.born()
	brim_sky.mass = Sim.START * 3.0
	brim_sky.lv.rich = 6
	brim_sky._gas_out = brim_sky.gas_outside()
	var fed_from: float = _sky_mass(brim_sky) + brim_sky.mass
	var fed := 0.0
	var full_for := 0
	var worst := 0.0
	var fattest := 0.0
	for i in int(120.0 / Sim.STEP):
		fed += float(brim_sky.trickle_rate()) * float(brim_sky.need()) * Sim.STEP
		if brim_sky.gas_count() >= Sim.MOST:
			full_for += 1
		brim_sky.tick()
		if i % 60 != 59:
			continue
		var top := 0.0
		var ring_sum := 0.0
		var ring_n := 0
		for p: Sim.Body in brim_sky.bodies:
			if p.kind != Sim.Kind.GAS:
				continue
			top = maxf(top, p.m)
			if p.pos.length() >= brim_sky.ring.x:
				ring_sum += p.m
				ring_n += 1
		fattest = maxf(fattest, top)
		if ring_n > 0:
			worst = maxf(worst, top * ring_n / ring_sum)
	print("  a full sky at three Suns, six levels of Rich, two minutes: at MOST for %.0f s of them, the heaviest puff ever %.4f (%.1f of a newborn ring's puff), at most %.1f times the mean puff out in the ring" % [
		full_for * Sim.STEP, fattest, fattest / (Sim.RING_M / Sim.RING), worst])
	_ok("with the sky full no puff takes all that drifts in: the heaviest is never over four times the mean puff of the ring (%.1f)" % worst, full_for > 600 and worst > 0.0 and worst <= 4.0)
	_ok("and none of it is lost (%.2f owed)" % fed, absf(_sky_mass(brim_sky) + brim_sky.mass + brim_sky._owed_gas - fed_from - fed) < 1e-4)
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
	keep.dusty = Sim.ASH_MOST * 0.5
	keep.save()
	var back: RefCounted = Sim.load_saved(1)
	_ok("a star saved and read back keeps its ring", back.ring.is_equal_approx(keep.ring) and is_equal_approx(back.frost, keep.frost) and is_equal_approx(back.dusty, Sim.ASH_MOST * 0.5) and int(back.lv.reach) == 2 and back.bodies.size() == keep.bodies.size())
	# what the ring weighed at birth comes back; a file's figure far off the
	# newborn's own is held to half of it and to half as much again
	_ok("a star read back keeps what its ring weighed", is_equal_approx(back.ring_m, keep.ring_m))
	var newborn_ring: float = minf(Sim.RING_M, Sim.RING_MOST * Sim.START)
	for odd_m: Array in [[1e-12, 0.5], [1e9, 1.5]]:
		var thin := ConfigFile.new()
		thin.load(Sim.path)
		thin.set_value("star", "ring_m", odd_m[0])
		thin.save(Sim.path)
		var held_m: RefCounted = Sim.load_saved(1)
		_ok("a file's ring of %s is held to %.1f of the newborn's" % [str(odd_m[0]), odd_m[1]], is_equal_approx(held_m.ring_m, newborn_ring * float(odd_m[1])))
	keep.save()
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
	# and so does one ten times too wide; a frost line or a dust share that is
	# not a finite number is the default, and nothing throws. `null` cannot be
	# set (it erases the key), so the file's own text is written
	keep.save()
	var text := FileAccess.get_file_as_string(Sim.path)
	for wrong: Array in [["dusty", "nan"], ["ring", "[1.0, 1e+12]"], ["frost", "[600.0]"], ["dusty", "null"]]:
		var lines := text.split("\n")
		var found := false
		for k in lines.size():
			if lines[k].begins_with(String(wrong[0]) + "="):
				lines[k] = "%s=%s" % wrong
				found = true
		var f := FileAccess.open(Sim.path, FileAccess.WRITE)
		f.store_string("\n".join(lines))
		f.close()
		var mended: RefCounted = Sim.load_saved(1)
		_ok("a file with %s=%s loads with a finite ring, frost line and dust (ring %s, frost %s, dusty %s)" % [wrong[0], wrong[1], str(mended.ring), str(mended.frost), str(mended.dusty)],
			found and mended.bodies.size() == keep.bodies.size() and mended.ring.is_equal_approx(keep.ring) and is_finite(mended.frost) and mended.frost >= mended.ring.x and mended.frost <= mended.ring.y
			and is_finite(mended.dusty) and mended.dusty >= 0.0 and mended.dusty <= Sim.ASH_MOST and is_finite(mended.zoom()) and is_equal_approx(mended.zoom(), keep.zoom()))
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
	_pairs(sim, fr - 40.0, Sim.DUSTY)
	_pairs(sim, fr + 40.0, Sim.DUSTY)
	# until a pair has stuck on each side of the line
	var inner := 0
	var outer := 0
	var rocky := true
	var icy := true
	for i in int(120.0 / Sim.STEP):
		sim.tick()
		if i % 60 != 0:
			continue
		inner = 0
		outer = 0
		for b: Sim.Body in sim.bodies:
			if b.kind == Sim.Kind.GAS:
				continue
			if b.pos.length() < fr:
				inner += 1
				rocky = rocky and b.ice == 0.0
			else:
				outer += 1
				icy = icy and b.ice > 0.0
		if inner > 0 and outer > 0:
			break
	_ok("inside the frost line a pair makes rock", inner > 0 and rocky)
	_ok("outside it a pair makes ice as well", outer > 0 and icy)
	sim.swell = 1.0
	_ok("a giant thaws the line outward", is_equal_approx(sim.frost_r(), sim.frost * (1.0 + Sim.GIANT)))

func _check_pay() -> void:
	_ok("gas pays PAY_GAS, a grain PAY_GRAIN, a rock PAY_ROCK, a world PAY_WORLD, each more than the last", Sim.PAY_GAS < Sim.PAY_GRAIN and Sim.PAY_GRAIN < Sim.PAY_ROCK and Sim.PAY_ROCK < Sim.PAY_WORLD and Sim.pay(0.0) == Sim.PAY_GAS and Sim.pay(Sim.GRAIN_M * 0.5) == Sim.PAY_GRAIN and Sim.pay(Sim.PLANET_M * 0.5) == Sim.PAY_ROCK and Sim.pay(Sim.PLANET_M) == Sim.PAY_WORLD)
	# a solid pays in full when eaten, whatever its path
	for way: Array in [["dropped straight in", 0.0], ["on a grazing path", 0.55]]:
		var sim := _quiet(12)
		var at := Vector2(300.0, 0.0)
		var p: Sim.Body = sim.add(Sim.Kind.ROCK, 0.01, at, sim.circle_vel(at) * float(way[1]))
		sim._sort(p)
		var owed: float = p.m * sim.spiral_light() * Sim.PAY_WORLD
		_ok("a planet's rank is its mass", is_equal_approx(p.rank, 0.01))
		var t := 0.0
		while sim.mass < Sim.START + 0.0099 and t < 900.0:
			sim.tick()
			t += Sim.STEP
		var got: float = sim.light
		for b: Sim.Body in sim.bodies:
			got += b.e
		_ok("a planet %s is eaten" % way[0], sim.mass >= Sim.START + 0.0099)
		_ok("and pays PAY_WORLD times its mass of spiral light (%s)" % way[0], absf(got - owed) < owed * 0.05)
	# gas dropped straight in still pays almost nothing
	var gas := _quiet(12)
	var g: Sim.Body = gas.add(Sim.Kind.GAS, 0.05, Vector2(300.0, 0.0), Vector2.ZERO)
	g.dust = 0.0
	_run(gas, 60.0)
	_ok("gas dropped straight in pays under a tenth of a spiral", gas.bodies.is_empty() and gas.light < 0.05 * gas.spiral_light() * 0.1)
	# torn pieces keep the whole body's rank, and what it had paid is shared out
	var torn := _quiet(13)
	var q: Sim.Body = torn.add(Sim.Kind.ROCK, 0.02, Vector2(torn.roche_r() * 0.9, 0.0), Vector2.ZERO)
	torn._sort(q)
	q.paid = 0.3
	torn._tear(0)
	var ranks := true
	var shared := 0.0
	for piece: Sim.Body in torn.bodies:
		ranks = ranks and is_equal_approx(piece.rank, 0.02)
		shared += piece.paid
	_ok("a torn planet's pieces keep its rank", ranks and torn.bodies.size() >= 2)
	_ok("and share what it had paid", is_equal_approx(shared, 0.3))
	_ok("with no Furnace a tear pays nothing", torn.light == 0.0)
	# the Furnace pays a share of a body's own worth, a level, once: on its
	# first tear, however often its pieces are torn again on the way down, and
	# over and above the worth the star pays for it. A world of 0.02 and one of
	# 0.04 on a grazing path, at one Sun and at four, with no Furnace, one
	# level and two, each followed through `tick` until the star has it all.
	for star_suns: float in [1.0, 4.0]:
		for world_m: float in [0.02, 0.04]:
			var forged: Array[float] = []
			var in_all: Array[float] = []
			var tears: Array[int] = []
			var worth := 0.0
			for level: int in [0, 1, 2]:
				var forge := _quiet(13)
				forge.mass = Sim.START * star_suns
				forge.power.furnace = level
				var from := Vector2(forge.main_r() * 2.0, 0.0)
				var falls: Sim.Body = forge.add(Sim.Kind.ROCK, world_m, from, forge.circle_vel(from) * 0.55)
				forge._sort(falls)
				worth = world_m * forge.spiral_light() * Sim.pay(falls.rank)
				var got := 0.0
				var torn_n := 0
				var t := 0.0
				while forge.bodies.size() > 0 and t < 900.0:
					forge.tick()
					t += Sim.STEP
					for k in forge.events.size():
						var e: Dictionary = forge.events[k]
						if String(e.kind) == "tear":
							torn_n += 1
						elif String(e.kind) == "shed" and k > 0 and String(forge.events[k - 1].kind) == "tear" and forge.events[k - 1].at == e.at:
							got += float(e.e)
					forge.events.clear()
				forged.append(got)
				in_all.append(float(forge.light) if forge.bodies.is_empty() else -1.0)
				tears.append(torn_n)
			print("  the Furnace, a world of %.2f at %.0f Sun(s), worth %.2f: torn %d times on the way down; no Furnace %.3f, one level %.3f (%.2f of its worth), two %.3f (%.2f)" % [
				world_m, star_suns, worth, tears[1], forged[0], forged[1], forged[1] / worth, forged[2], forged[2] / worth])
			_ok("with no Furnace a world of %.2f at %.0f Sun(s) pays none" % [world_m, star_suns], forged[0] == 0.0 and tears[0] > 1)
			_ok("one level pays FURNACE_SHARE of its worth, once, however often its pieces are torn (%.2f of %.2f)" % [forged[1], Sim.FURNACE_SHARE * worth], tears[1] > 1 and absf(forged[1] - Sim.FURNACE_SHARE * worth) < Sim.FURNACE_SHARE * worth * 0.05)
			_ok("two levels pay twice that (%.2f)" % forged[2], absf(forged[2] - 2.0 * Sim.FURNACE_SHARE * worth) < 2.0 * Sim.FURNACE_SHARE * worth * 0.05)
			_ok("and it is over and above the worth the star pays for the body, not part of it", in_all[0] > 0.0 and absf(in_all[0] - worth) < worth * 0.05 and absf(in_all[2] - worth - forged[2]) < worth * 0.05)
	# a dim star's Furnace pays nothing
	var forge_dim := _quiet(13)
	forge_dim.power.furnace = 2
	forge_dim.awake = false
	var fd: Sim.Body = forge_dim.add(Sim.Kind.ROCK, 0.02, Vector2(forge_dim.roche_r() * 0.9, 0.0), Vector2.ZERO)
	forge_dim._sort(fd)
	forge_dim._tear(0)
	_ok("a dim star's Furnace pays nothing", forge_dim.light == 0.0)
	_ok("the pieces of a torn body carry that it was torn", forge_dim.bodies.all(func(x): return x.torn) and not fd.torn)
	# two solids that gather are torn only if both were: one that has taken in
	# fresh mass may pay the Furnace once more
	for both: bool in [true, false]:
		var heap := _quiet(13)
		var spot := Vector2(heap.haze_r() * 1.3, 0.0)
		var one_p: Sim.Body = heap.add(Sim.Kind.ROCK, 0.003, spot, heap.circle_vel(spot))
		var two_p: Sim.Body = heap.add(Sim.Kind.ROCK, 0.003, spot + Vector2(2.0, 0.0), heap.circle_vel(spot))
		one_p.torn = true
		two_p.torn = both
		_run(heap, 1.0)
		_ok("two gathered solids are torn only if both were (%s)" % ("both" if both else "one"), heap.bodies.size() == 1 and heap.bodies[0].torn == both)
	# the file keeps it, and a row from before it has not been torn
	var torn_keep := _quiet(15)
	var tk: Sim.Body = torn_keep.add(Sim.Kind.ROCK, 0.004, Vector2(700.0, 0.0), torn_keep.circle_vel(Vector2(700.0, 0.0)))
	tk.torn = true
	torn_keep.save()
	var torn_back: RefCounted = Sim.load_saved(1)
	_ok("a torn body read back is still torn", torn_back.bodies.size() == 1 and torn_back.bodies[0].torn)
	var torn_cfg := ConfigFile.new()
	torn_cfg.load(Sim.path)
	var torn_rows: Array = torn_cfg.get_value("star", "bodies", [])
	torn_rows[0] = (torn_rows[0] as Array).slice(0, 12)
	torn_cfg.set_value("star", "bodies", torn_rows)
	torn_cfg.save(Sim.path)
	var torn_old: RefCounted = Sim.load_saved(1)
	_ok("a twelve-column row has not been torn", torn_old.bodies.size() == 1 and not torn_old.bodies[0].torn)
	# nothing pays a negative amount: a body that has already paid more than it owes
	var over := _quiet(14)
	var o: Sim.Body = over.add(Sim.Kind.ROCK, 0.001, Vector2(145.0, 0.0), Vector2.ZERO)
	over._sort(o)
	o.paid = 99.0
	_run(over, 5.0)
	_ok("a body that has paid its worth pays no more", over.bodies.is_empty() and over.light >= 0.0 and over.light < 0.001)
	# the file keeps rank and paid; an old row is its own mass
	var keep := _quiet(15)
	var k: Sim.Body = keep.add(Sim.Kind.ROCK, 0.004, Vector2(700.0, 0.0), keep.circle_vel(Vector2(700.0, 0.0)))
	keep._sort(k)
	k.rank = 0.02
	k.paid = 0.11
	keep.save()
	var back: RefCounted = Sim.load_saved(1)
	_ok("a body read back keeps its rank and what it paid", back.bodies.size() == 1 and is_equal_approx(back.bodies[0].rank, 0.02) and is_equal_approx(back.bodies[0].paid, 0.11))
	var cfg := ConfigFile.new()
	cfg.load(Sim.path)
	var rows: Array = cfg.get_value("star", "bodies", [])
	rows[0] = (rows[0] as Array).slice(0, 10)
	cfg.set_value("star", "bodies", rows)
	cfg.save(Sim.path)
	var old: RefCounted = Sim.load_saved(1)
	_ok("a ten-column row's rank is its mass", is_equal_approx(old.bodies[0].rank, 0.004) and old.bodies[0].paid == 0.0)

func _check_worlds() -> void:
	var sim := _quiet(16)
	var at := Vector2(655.0, 0.0)
	var w: Sim.Body = sim.add(Sim.Kind.ROCK, 0.02, at, sim.circle_vel(at))
	sim._sort(w)
	var hill: float = sim.hill_r(w)
	_ok("a world of 0.02 at 655 px has a Hill radius of about 57 px", absf(hill - 655.0 * pow(0.02 / 30.0, 1.0 / 3.0)) < 0.5)
	# a grain beside it is turned by it; one past the reach is not
	var near_at := at + Vector2(0.0, hill * 0.5)
	var far_at := Vector2(-655.0, 0.0)
	var a: Sim.Body = sim.add(Sim.Kind.GRAIN, 0.0005, near_at, sim.circle_vel(near_at))
	var b: Sim.Body = sim.add(Sim.Kind.GRAIN, 0.0005, far_at, sim.circle_vel(far_at))
	var alone := _quiet(16)
	var a0: Sim.Body = alone.add(Sim.Kind.GRAIN, 0.0005, near_at, alone.circle_vel(near_at))
	var b0: Sim.Body = alone.add(Sim.Kind.GRAIN, 0.0005, far_at, alone.circle_vel(far_at))
	_run(sim, 20.0)
	_run(alone, 20.0)
	_ok("a world turns what is near it", a.pos.distance_to(a0.pos) > 1.0)
	_ok("and not what is past its reach", b.pos.distance_to(b0.pos) < 0.01)
	# a grain exactly on the world, and gas exactly on a core
	var on_w: Sim.Body = sim.add(Sim.Kind.GRAIN, 0.0005, w.pos, w.vel)
	var on_core := _quiet(16)
	var cw: Sim.Body = on_core.add(Sim.Kind.ROCK, Sim.CORE_M * 1.5, at, on_core.circle_vel(at))
	cw.h = 0.5
	on_core._sort(cw)
	var on_gas: Sim.Body = on_core.add(Sim.Kind.GAS, 0.02, cw.pos, cw.vel)
	on_gas.dust = 0.0
	var all_finite := true
	for sky: RefCounted in [sim, on_core]:
		_run(sky, 10.0)
		for q: Sim.Body in sky.bodies:
			all_finite = all_finite and q.pos.is_finite() and q.vel.is_finite()
	_ok("a world on top of a body divides by nothing", is_finite(w.pos.x) and is_finite(a.pos.x) and on_w != null and all_finite)
	# only the heaviest WORLDS pull, and a planet under PLANET_M does not
	var small := _quiet(17)
	var s: Sim.Body = small.add(Sim.Kind.ROCK, Sim.PLANET_M * 0.5, at, small.circle_vel(at))
	small._sort(s)
	var c: Sim.Body = small.add(Sim.Kind.GRAIN, 0.0005, near_at, small.circle_vel(near_at))
	_run(small, 20.0)
	_ok("a rock pulls nothing", c.pos.distance_to(a0.pos) < 0.01)
	# gas inside half a Hill radius of a core stays with it or is gulped by it
	var held := _quiet(18)
	var core: Sim.Body = held.add(Sim.Kind.ROCK, Sim.CORE_M * 1.5, at, held.circle_vel(at))
	core.h = 0.5
	held._sort(core)
	var puff_at := at + Vector2(held.hill_r(core) * 0.3, 0.0)
	var puff: Sim.Body = held.add(Sim.Kind.GAS, 0.02, puff_at, held.circle_vel(puff_at))
	puff.dust = 0.0
	puff.age = 0.0
	_run(held, held.turn_time(655.0) * 2.0)
	_ok("gas inside half a Hill radius stays with a core", puff.m <= 0.0 or not held.bodies.has(puff) or puff.pos.distance_to(core.pos) < held.hill_r(core))
	# who holds gas is who can gulp it: a core, not a small planet and not a full giant
	var tiers := _quiet(18)
	var lo: Sim.Body = tiers.add(Sim.Kind.ROCK, Sim.PLANET_M * 1.1, at, Vector2.ZERO)
	var mid: Sim.Body = tiers.add(Sim.Kind.ROCK, Sim.CORE_M * 1.5, at, Vector2.ZERO)
	var top: Sim.Body = tiers.add(Sim.Kind.ROCK, Sim.GIANT_MOST, at, Vector2.ZERO)
	_ok("a world holds gas from CORE_M up to GIANT_MOST and no other", not Sim.holds(lo) and Sim.holds(mid) and not Sim.holds(top))
	# a relic pulls a body by its tide in the star's frame: a circle at the
	# ring's middle with a relic of 6 at its birth distance is still a circle
	var tide := _quiet(22)
	var ring_mid: float = (tide.ring.x + tide.ring.y) * 0.5
	var mid_at := Vector2(ring_mid, 0.0)
	var circ: Sim.Body = tide.add(Sim.Kind.GAS, 0.05, mid_at, tide.circle_vel(mid_at))
	circ.dust = 0.0
	tide.add_relic(Sim.Relic.WD, 6.0, Vector2(Sim.LOBE * tide.ring.y * (1.0 + sqrt(6.0 / tide.mass)), 0.0), tide.layers())
	var swing_lo := INF
	var swing_hi := 0.0
	for i in int(tide.turn_time(ring_mid) * 5.0 / Sim.STEP):
		tide.tick()
		swing_lo = minf(swing_lo, circ.pos.length())
		swing_hi = maxf(swing_hi, circ.pos.length())
	print("  a circle at %.0f px beside a relic at its birth distance, five turns: %.0f to %.0f px (%.2f to %.2f)" % [ring_mid, swing_lo, swing_hi, swing_lo / ring_mid, swing_hi / ring_mid])
	_ok("beside a relic at its birth distance a circle in the ring stays a circle the whole way", tide.bodies.has(circ) and swing_lo > ring_mid * 0.9 and swing_hi < ring_mid * 1.1)
	# gas feels a world only if the world holds it, and inside its Hill radius;
	# a solid feels it out to six
	var skip := _quiet(23)
	var twin := _quiet(23)
	var rock_w: Sim.Body = skip.add(Sim.Kind.ROCK, Sim.PLANET_M * 1.1, at, skip.circle_vel(at))
	var apart := Vector2(0.0, skip.hill_r(rock_w) * 3.0)
	var g1: Sim.Body = skip.add(Sim.Kind.GAS, 0.02, at + apart, skip.circle_vel(at + apart))
	var g0: Sim.Body = twin.add(Sim.Kind.GAS, 0.02, at + apart, twin.circle_vel(at + apart))
	var s1: Sim.Body = skip.add(Sim.Kind.GRAIN, 0.0005, at - apart, skip.circle_vel(at - apart))
	var s0: Sim.Body = twin.add(Sim.Kind.GRAIN, 0.0005, at - apart, twin.circle_vel(at - apart))
	g1.dust = 0.0
	g0.dust = 0.0
	_run(skip, 20.0)
	_run(twin, 20.0)
	_ok("gas three Hill radii from a planet that holds nothing moves as it does without the planet", g1.pos.distance_to(g0.pos) < 0.001)
	_ok("while a grain in the same place is turned by it", s1.pos.distance_to(s0.pos) > 1.0)
	# a ring beside a relic at its birth distance keeps its puffs: measured
	# against the same ring with no relic, so what its own cores gulp is not
	# charged to the relic
	for case: Array in [[1.2, false, "a dwarf"], [25.0, true, "a hole"]]:
		var kept_gas: Array[int] = []
		var before := 0
		for with_relic: bool in [true, false]:
			var dead := _quiet(19)
			dead.mass = Sim.START * float(case[0])
			if case[1]:
				dead.made[5] = Sim.IRON * Sim.START
			else:
				dead.cold = Sim.GRACE
			dead.end()
			if not with_relic:
				dead.relics.clear()
			before = dead.gas_count()
			_run(dead, 600.0)
			var left := 0
			for p: Sim.Body in dead.bodies:
				if p.kind == Sim.Kind.GAS and p.pos.length() > dead.haze_r():
					left += 1
			kept_gas.append(left)
		var floor_n := int(float(before - Sim.RING_FALLING) * 0.8)
		print("  a ring beside %s: %d gas puffs at the start, %d outside the disc after ten minutes with the relic, %d without (floor %d)" % [case[2], before, kept_gas[0], kept_gas[1], floor_n])
		_ok("a ring beside %s keeps 0.95 of what the same ring keeps with no relic (%d of %d)" % [case[2], kept_gas[0], kept_gas[1]], float(kept_gas[0]) >= 0.95 * float(kept_gas[1]))
		_ok("and at least 0.8 of its gas outside the disc (%d of %d)" % [kept_gas[0], before], kept_gas[0] >= floor_n)
	# Wind leans the ring in; it does not empty it
	var wind := _quiet(20)
	wind.power.wind = 1
	var wp: Sim.Body = wind.add(Sim.Kind.GAS, 0.05, at, wind.circle_vel(at))
	wp.dust = 0.0
	_run(wind, 300.0)
	_ok("with Wind a ring circle is still 0.8 of its radius after five minutes", wp.pos.length() > 655.0 * 0.8 and wp.pos.length() < 655.0)
	# the count
	var sys := _quiet(21)
	for row: Array in [[0.02, 0.0, 0.0], [0.02, 0.0, 0.6], [0.004, 0.0, 0.0], [0.004, 0.5, 0.0], [0.0005, 0.0, 0.0]]:
		var body: Sim.Body = sys.add(Sim.Kind.ROCK, row[0], Vector2(700.0, 0.0), Vector2.ZERO)
		body.ice = row[1]
		body.h = row[2]
		sys._sort(body)
	var count: Dictionary = sys.system()
	_ok("the system counts planets, giants, rocks and comets, not grains", int(count.planets) == 1 and int(count.giants) == 1 and int(count.rocks) == 1 and int(count.comets) == 1)
	sys.save()
	_ok("the file keeps the worlds, and the card reads them", int(Sim.kept().worlds) == 2)
	# only what is on a closed path is counted: a planet passing through is
	# not the star's, the same planet on a circle is
	var pass_by := _quiet(21)
	var where := Vector2(700.0, 0.0)
	var open_v: float = sqrt(2.0 * pass_by.gm() / 700.0)
	var roamer: Sim.Body = pass_by.add(Sim.Kind.ROCK, 0.02, where, Vector2(0.0, -open_v * 1.05))
	pass_by._sort(roamer)
	_ok("a planet on an open path is not counted", roamer.kind == Sim.Kind.PLANET and int(pass_by.system().planets) == 0)
	pass_by.save()
	_ok("nor kept as a world", int(Sim.kept().worlds) == 0)
	roamer.vel = pass_by.circle_vel(where)
	_ok("the same planet on a circle is", int(pass_by.system().planets) == 1)
	roamer.vel = Vector2(0.0, -open_v * 0.99)
	_ok("and on a long closed path", int(pass_by.system().planets) == 1)
	pass_by.save()
	_ok("and is kept", int(Sim.kept().worlds) == 1)

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
	_ok("a nebula's gas is not dusty", sim.bodies.size() > 0 and thin < Sim.ASH_DUST * 2.0)
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
	print("  a supernova's ash: dust %.3f of a puff (a first cloud %.3f, a nebula's under %.3f)" % [dusty, Sim.FIRST_DUST, Sim.ASH_DUST * 2.0])
	_ok("metal-rich ashes", dusty > Sim.ASH_DUST * 2.0 and dusty <= Sim.ASH_MOST)
	var grain := _quiet(5)
	_pairs(grain, grain.haze_r() * 1.2, Sim.ASH_MOST)
	var dark: Sim.Body = _first_solid(grain)
	_ok("iron grain", dark != null and dark.metal > 0.5)
	# a young sky's grain is not
	var young := _quiet(5)
	_pairs(young, young.haze_r() * 1.2, Sim.FIRST_DUST)
	var pale: Sim.Body = _first_solid(young)
	_ok("plain grain", pale != null and pale.metal <= 0.5)
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
