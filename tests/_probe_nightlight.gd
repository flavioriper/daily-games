extends SceneTree

## Nightlight, headless: the physics first, then a bot at the real sim to say
## how fast the numbers are.
##
##     godot --headless --path . --script res://tests/_probe_nightlight.gd
##     godot --headless --path . --script res://tests/_probe_nightlight.gd -- pace [minutes] [seed] [seconds between throws]
##
## The checks: a meteor on a circle in the haze goes round several times,
## gains speed all the way and pays far more light than one dropped straight
## in; a star left alone catches little; a tile costs what the table says
## and Haze stops; a throw is never refused; a supernova pays its stardust, leaves ashes on closed
## paths and takes the tiles; a star saved and read back is the same star;
## the tide tears a body inside its own distance and not outside it, keeps
## its mass and its momentum, draws the pieces out along the path and lets
## nothing gather inside the Roche radius.
## `pace` plays a steady hand that throws into the outer haze, buys the
## cheapest tile it can and goes supernova as soon as the stardust buys a
## perk, and prints each supernova. Everything runs on a throwaway file.

const Sim = preload("res://arcade/nightlight_sim.gd")

var _fails := 0
var _checks := 0

func _initialize() -> void:
	Sim.path = OS.get_user_data_dir() + "/_probe_nightlight.cfg"
	DirAccess.remove_absolute(Sim.path)
	var args := OS.get_cmdline_user_args()
	if args.has("pace"):
		_pace(float(args[1]) if args.size() > 1 else 30.0, int(args[2]) if args.size() > 2 else 1, float(args[3]) if args.size() > 3 else 0.45)
	else:
		_check_physics()
		_check_tide()
		_check_rules()
		print("probe_nightlight: %d checks, %d failed" % [_checks, _fails])
	DirAccess.remove_absolute(Sim.path)
	quit(1 if _fails > 0 else 0)

func _ok(what: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
		print("FAIL ", what)

## One meteor alone in the sky, from `pos` with `vel`, until the star has it
## and every piece the tide made of it: {seconds, turns, fastest, light}. The
## turns and the speed are the meteor's own, then its heaviest piece's (a
## torn body's first piece keeps its id).
func _one(pos: Vector2, vel: Vector2) -> Dictionary:
	var sim: RefCounted = Sim.new(7)
	sim.passing = false
	var id: int = sim.add(Sim.Kind.METEOR, 1.0, pos, vel).id
	var turns := 0.0
	var fastest := 0.0
	var was := pos.angle()
	while not sim.bodies.is_empty() and sim.clock < 300.0:
		for b: Sim.Body in sim.bodies:
			if b.id == id:
				turns += absf(angle_difference(was, b.pos.angle()))
				was = b.pos.angle()
				fastest = maxf(fastest, b.vel.length())
				break
		sim.tick()
	return {"seconds": sim.clock, "turns": turns / TAU, "fastest": fastest, "light": sim.light, "mass": sim.mass}

func _check_physics() -> void:
	var sim: RefCounted = Sim.new(7)
	var rh: float = sim.haze_r()
	_ok("a new star is %d px and its haze five times that" % Sim.STAR_R, is_equal_approx(sim.star_r(), Sim.STAR_R) and is_equal_approx(rh, Sim.STAR_R * Sim.HAZE))
	_ok("a turn at the haze's edge is slow and one at the surface quick", sim.turn_time(rh) > 6.0 and sim.turn_time(sim.star_r()) < 0.7)
	var drop := _one(Vector2(400.0, 0.0), Vector2.ZERO)
	print("dropped at rest from 400: eaten after %.1f s, %.1f turns, up to %.0f px/s, light %.2f" % [drop.seconds, drop.turns, drop.fastest, drop.light])
	var r := rh * 0.8
	var v0 := sqrt(sim.gm() / r)
	var ring := _one(Vector2(r, 0.0), Vector2(0.0, v0))
	print("a circle at 0.8 of the haze: eaten after %.1f s, %.1f turns, %.0f -> %.0f px/s, light %.2f" % [ring.seconds, ring.turns, v0, ring.fastest, ring.light])
	_ok("both are eaten", is_equal_approx(drop.mass, Sim.START + 1.0) and is_equal_approx(ring.mass, Sim.START + 1.0))
	_ok("a circle in the haze goes round at least four times", ring.turns >= 4.0)
	_ok("and ends at twice the speed it began", ring.fastest >= v0 * 1.9)
	_ok("a straight drop goes round not at all", drop.turns < 0.1)
	_ok("a spiral pays ten times the light of a drop", ring.light >= drop.light * 10.0 and ring.light > 1.0)
	var where: Dictionary = sim.predict(Vector2(r, 0.0), Vector2(0.0, v0), 3000)
	_ok("the dotted line ends at the star, as the meteor does", where.hit)
	# a body on a circle outside the haze never comes down
	var out := _one(Vector2(rh * 1.5, 0.0), Vector2(0.0, sqrt(sim.gm() / (rh * 1.5))))
	_ok("a circle outside the haze is still up after five minutes", out.seconds >= 300.0 and is_equal_approx(out.mass, Sim.START))
	# hands off: the sky alone
	var idle: RefCounted = Sim.new(3)
	for i in int(300.0 / Sim.STEP):
		idle.tick()
		idle.events.clear()
	print("left alone for five minutes: mass %.1f, light %.1f, %d bodies up" % [idle.mass, idle.light, idle.bodies.size()])
	_ok("a small star left alone catches something, and not much", idle.mass > Sim.START and idle.mass < 200.0)

func _sum(sim: RefCounted) -> Dictionary:
	var m := 0.0
	var mv := Vector2.ZERO
	for b: Sim.Body in sim.bodies:
		m += b.m
		mv += b.vel * b.m
	return {"m": m, "mv": mv}

func _check_tide() -> void:
	var sim: RefCounted = Sim.new(11)
	sim.passing = false
	var planet: float = sim.tear_r(8.0)
	var meteor: float = sim.tear_r(Sim.METEOR)
	print("the tide: Roche %.0f px (%.1f radii), a planetoid torn at %.0f, a rock at %.0f, a meteor at %.0f, the haze's edge %.0f" % [sim.roche_r(),
		sim.roche_r() / sim.star_r(), planet, sim.tear_r(1.5), meteor, sim.haze_r()])
	_ok("the big are torn further out than the small, all inside the Roche radius and outside the star", planet > meteor and planet < sim.roche_r() and meteor > sim.star_r())
	_ok("a crumb is never torn", sim.tear_r(sim.grain() * 1.9) == 0.0)
	# a meteor a little outside its distance holds, a little inside it is in three
	var r := meteor * 1.02
	sim.add(Sim.Kind.METEOR, Sim.METEOR, Vector2(r, 0.0), Vector2(0.0, sqrt(sim.gm() / r)))
	sim.tick()
	_ok("a meteor just outside its distance is whole", sim.bodies.size() == 1)
	sim.bodies.clear()
	sim.events.clear()
	r = meteor * 0.98
	var whole: Sim.Body = sim.add(Sim.Kind.METEOR, Sim.METEOR, Vector2(r, 0.0), Vector2(0.0, sqrt(sim.gm() / r)))
	whole.e = 0.03
	var before := _sum(sim)
	sim.tick()
	var after := _sum(sim)
	var e := 0.0
	var lightest := 1.0
	for b: Sim.Body in sim.bodies:
		e += b.e
		lightest = minf(lightest, b.m)
	_ok("just inside it, it is in three", sim.bodies.size() == 3 and sim.events.any(func(ev: Dictionary) -> bool: return ev.kind == "tear"))
	_ok("that weigh what it did and carry its light", is_equal_approx(after.m, before.m) and absf(e - 0.03) < 0.002)
	_ok("and its momentum, to a tick's worth of pull", (after.mv - before.mv).length() < before.mv.length() * 0.02)
	_ok("and none of them is torn again", lightest * 3.0 > sim.grain() and sim.bodies.all(func(b: Sim.Body) -> bool: return sim.tear_r(b.m) == 0.0))
	# a planetoid on a circle in the haze, a little outside its distance: the
	# drag brings it in, and the tide takes it a piece at a time
	var sky: RefCounted = Sim.new(11)
	sky.passing = false
	r = planet * 1.1
	sky.add(Sim.Kind.PLANET, 8.0, Vector2(r, 0.0), Vector2(0.0, sqrt(sky.gm() / r)))
	var first := -1.0
	var most := 1
	var merged := 0
	var inside := 0
	var drawn := Vector2.ZERO
	while not sky.bodies.is_empty() and sky.clock < 120.0:
		sky.tick()
		for ev: Dictionary in sky.events:
			if ev.kind == "merge":
				merged += 1
				if (ev.at as Vector2).length() < sky.roche_r() * 0.98:
					inside += 1
		sky.events.clear()
		most = maxi(most, sky.bodies.size())
		if first < 0.0 and sky.bodies.size() > 1:
			first = sky.clock
		if first > 0.0 and drawn == Vector2.ZERO and sky.clock >= first + 1.5 and sky.bodies.size() > 1:
			# how far the pieces have drawn apart: round the star (the angle
			# they span, at their middle distance), and toward it
			var mid := Vector2.ZERO
			for b: Sim.Body in sky.bodies:
				mid += b.pos / sky.bodies.size()
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for b: Sim.Body in sky.bodies:
				var d := Vector2(mid.angle_to(b.pos) * mid.length(), b.pos.length())
				lo = lo.min(d)
				hi = hi.max(d)
			drawn = hi - lo
	print("a planetoid of 8 on a circle at %.0f px: first torn after %.1f s, %.0f px along the path and %.0f across it 1.5 s on, %d bodies at most, %d met again outside the Roche radius, all eaten after %.1f s, light %.2f" % [r,
		first, drawn.x, drawn.y, most, merged, sky.clock, sky.light])
	_ok("a planetoid in the haze is torn, and its pieces again", first > 0.0 and most >= 12)
	_ok("the pieces draw out along the path, not across it", drawn.x > drawn.y * 2.0 and drawn.x > Sim.body_r(8.0) * 2.0)
	_ok("nothing gathers inside the Roche radius", inside == 0)
	_ok("and the star has all of it", sky.bodies.is_empty() and is_equal_approx(sky.mass, Sim.START + 8.0))

func _check_rules() -> void:
	var sim: RefCounted = Sim.new(5)
	sim.passing = false
	_ok("a first Meteor costs 10 light", sim.cost("meteor") == 10 and not sim.can_buy("meteor"))
	sim.light = 25.0
	_ok("a meteor weighs a fifth of a mass", is_equal_approx(sim.meteor_mass(), Sim.METEOR) and is_equal_approx(Sim.METEOR, 0.2))
	_ok("bought, the next is 15 and a meteor weighs twice that", sim.buy("meteor") and sim.cost("meteor") == 15 and is_equal_approx(sim.meteor_mass(), 0.4) and is_equal_approx(sim.light, 15.0))
	sim.lv.haze = Sim.TILE.haze[2]
	sim.light = 1e12
	_ok("Haze stops at its last level", sim.is_done("haze") and not sim.buy("haze"))
	# nothing limits a throw: three hundred on a circle outside the haze, all
	# let go at once, and the sky holds its most and no more
	var park: RefCounted = Sim.new(5)
	park.passing = false
	for i in 300:
		var at: Vector2 = Vector2.from_angle(i * 0.37) * (park.haze_r() * (1.3 + 0.004 * i))
		park.throw_at(at, at.orthogonal().normalized() * -sqrt(park.gm() / at.length()))
	_ok("a throw is never refused, and the sky holds %d at most" % Sim.MOST, park.bodies.size() == Sim.MOST)
	var began := Time.get_ticks_usec()
	for i in 240:
		park.tick()
	print("a full sky of %d: %.0f us a tick" % [park.bodies.size(), (Time.get_ticks_usec() - began) / 240.0])
	_ok("no supernova under the mark", not sim.can_nova() and sim.nova() == 0 and sim.dust_for() == 0)
	sim.mass = Sim.NOVA
	_ok("at the mark it pays three, at four times the mark six", sim.dust_for() == 3 and is_equal_approx(sim.next_dust_mass(), Sim.NOVA * 16.0 / 9.0))
	sim.mass = Sim.NOVA * 4.0
	_ok("six at four times the mark", sim.dust_for() == 6)
	var got: int = sim.nova()
	_ok("a supernova pays, and leaves a new star with no tiles and no light", got == 6 and sim.dust == 6 and sim.novas == 1 and is_equal_approx(sim.mass, Sim.START) and sim.light == 0.0 and int(sim.lv.meteor) == 0)
	var bound := true
	for b: Sim.Body in sim.bodies:
		# a closed path: less speed than it takes to leave
		if b.kind != Sim.Kind.ASH or b.vel.length_squared() >= 2.0 * sim.gm() / b.pos.length() or b.pos.cross(b.vel) <= 0.0:
			bound = false
	_ok("its ashes are on closed paths, all turning one way", sim.bodies.size() >= 20 and bound)
	_ok("the sky is half again as rich", is_equal_approx(sim.rich(), 1.5))
	var which: String = sim.buy_perk()
	_ok("the first perk costs two", which != "" and sim.dust == 4 and int(sim.perk[which]) == 1 and sim.perk_cost() == 3)
	sim.light = 12.5
	sim.save()
	var back: RefCounted = Sim.load_saved(9)
	_ok("a star saved and read back is the same star", is_equal_approx(back.mass, sim.mass) and back.dust == 4 and back.novas == 1 and int(back.perk[which]) == 1
		and is_equal_approx(back.light, 12.5) and back.bodies.size() == sim.bodies.size() and back.bodies[0].pos.is_equal_approx(sim.bodies[0].pos))
	var kept: Dictionary = Sim.kept()
	_ok("and the tab can read it", is_equal_approx(kept.mass, sim.mass) and kept.novas == 1)

func _pace(minutes: float, rng_seed: int, every: float) -> void:
	var sim: RefCounted = Sim.new(rng_seed)
	var since := 0.0
	var life := 0.0
	var thrown := 0
	var most_bodies := 0
	var began := Time.get_ticks_usec()
	for i in int(minutes * 60.0 / Sim.STEP):
		since += Sim.STEP
		life += Sim.STEP
		if since >= every:
			since = 0.0
			sim.bot_throw()
			thrown += 1
		sim.tick()
		sim.events.clear()
		most_bodies = maxi(most_bodies, sim.bodies.size())
		var best := ""
		for tile: String in Sim.TILES:
			if sim.can_buy(tile) and (best == "" or sim.cost(tile) < sim.cost(best)):
				best = tile
		if best != "":
			sim.buy(best)
		if sim.can_nova() and sim.dust + sim.dust_for() >= sim.perk_cost():
			print("  supernova %d at %.1f min, after a life of %.1f min: mass %d, +%d stardust, tiles %s" % [sim.novas + 1, sim.clock / 60.0, life / 60.0,
				int(sim.mass), sim.dust_for(), str(sim.lv)])
			sim.nova()
			life = 0.0
			while sim.buy_perk() != "":
				pass
	var per_tick := float(Time.get_ticks_usec() - began) / (minutes * 60.0 / Sim.STEP)
	print("end of %.0f min: mass %.0f, light %.0f, %d supernovas, perks %s, %d thrown, %d bodies at most, %.1f us a tick" % [minutes, sim.mass, sim.light,
		sim.novas, str(sim.perk), thrown, most_bodies, per_tick])
