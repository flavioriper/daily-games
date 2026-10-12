extends SceneTree

## Proves Eddy's water headless and plays it with two bots. Run after
## touching arcade/eddy_sim.gd.
##   godot --headless --script tests/_probe_eddy.gd -- [runs]
## The water's promises: a whirlpool held by a leaf takes it; one that goes
## over a leaf takes it as it goes, at a walk or flat out, at any level and
## any speed bought (the user, 2026-10-12: "it should absorv items while move
## not only when it's stopped"); one that goes by out of reach leaves it
## where it lay; and a duck beside a small whirlpool stays where it is until
## the whirlpool has grown. Then a patient bot (it slows as it nears what it
## is after) and a sweeping one (flat out at it and on over it, never
## slowing) each play `runs` runs: the sweeping one must do nearly as well. Then the climb: a bot plays run after run, banks what
## each scores and buys the cheapest upgrade it can, until a rowing boat goes
## down; the runs that takes is the game's pace (`ladder`: 60 to 90 were asked of a
## person, and the patient bot is far better than one, so 30 to 60 of it).
##   godot --headless --script tests/_probe_eddy.gd -- [runs] [ladder|only]

const Sim = preload("res://arcade/eddy_sim.gd")
const Upgrades = preload("res://arcade/eddy_upgrades.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 20
	if args.size() > 1 and args[1] == "only":
		# tuning: one climb at a price growth and a skill of its own
		_ladder(float(args[3]) if args.size() > 3 else 1.0, float(args[2]) if args.size() > 2 else Upgrades.GROWTH)
		quit(0)
		return
	_water()
	var slow := _many(runs, false)
	var fast := _many(runs, true)
	_many(runs, false, 0.6)
	var slow_big := _many(runs, false, 1.0, 8)
	var fast_big := _many(runs, true, 1.0, 8)
	# what it goes over it takes: a whirlpool that never slows does as well
	_check("the sweeping bot scores at least two thirds of what the patient one does (%d of %d)" % [int(fast), int(slow)], fast * 3.0 >= slow * 2.0)
	_check("grown to level 8 it still does (%d of %d)" % [int(fast_big), int(slow_big)], fast_big * 3.0 >= slow_big * 2.0)
	_kit()
	if args.size() > 1 and args[1] == "ladder":
		var n := _ladder(1.0)
		_check("the patient bot takes a rowing boat in 30 to 60 runs (%d)" % n, n >= 30 and n <= 60)
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

## An empty pond with the whirlpool at its middle and the spin running.
func _bare(lv := 1, ups := {}) -> RefCounted:
	var s = Sim.new(1)
	s.fit(ups)
	s.things.clear()
	s.stocks = false
	s.level = lv
	s.steer(Vector2.RIGHT)
	s.steer(Vector2.ZERO)
	s.events.clear()
	return s

func _steps(s: RefCounted, seconds: float) -> Dictionary:
	var tally := {}
	for i in int(seconds / Sim.DT):
		s.step()
		for ev: Dictionary in s.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
		s.events.clear()
	return tally

func _water() -> void:
	# held beside a leaf, three cores off
	var s := _bare()
	var leaf: Dictionary = s.put(Sim.Kind.LEAF, s.pos + Vector2(s.core() * 3.0, 0))
	leaf.drift = Vector2.ZERO
	var tally := _steps(s, 4.0)
	_check("a still whirlpool takes a leaf three cores off (%d swallowed)" % int(tally.get("swallow", 0)), int(tally.get("swallow", 0)) == 1)
	# flat out straight over the same leaf: taken as it goes, whatever the
	# level and with twelve of every upgrade, the speed among them
	for at: int in [1, 5, 10, 20, -1, -10]:
		var ups := {} if at > 0 else {"spin": 12, "pull": 12, "mouth": 12, "reach": 12, "speed": 12}
		var lv := absi(at)
		for off: float in [0.3, 4.0 + (0.0 if at > 0 else Sim.REACH_UP * 12)]:
			s = _bare(lv, ups)
			s.pos = Vector2(60.0, s.h * 0.5)
			s.vel = Vector2.RIGHT * s.speed
			# on the way, or a little past where the water is felt
			leaf = s.put(Sim.Kind.LEAF, Vector2(150.0, s.h * 0.5 + minf(s.reach() + 6.0, s.h * 0.5 - 20.0) * (1.0 if off > 1.0 else 0.0) + s.core() * (off if off < 1.0 else 0.0)))
			leaf.drift = Vector2.ZERO
			var from: Vector2 = leaf.pos
			s.steer(Vector2.RIGHT)
			tally = _steps(s, 180.0 / s.speed)
			s.steer(Vector2.ZERO)
			if off < 1.0:
				_check("level %d%s, flat out over a leaf: taken" % [lv, "" if at > 0 else " with twelve of each"], int(tally.get("catch", 0)) == 1)
			elif s.reach() + 6.0 < s.h * 0.5 - 20.0:
				var moved := from.distance_to(leaf.pos) if s.things.size() > 0 else -1.0
				_check("level %d%s, flat out past a leaf out of reach: left where it lay (moved %.1f)" % [lv, "" if at > 0 else " with twelve of each", moved], int(tally.get("catch", 0)) == 0 and moved >= 0.0 and moved < 1.0)
	# every kind is taken on the move by the first mouth that takes it
	for kind in Sim.KINDS.size():
		s = _bare(Sim.level_for(kind))
		s.pos = Vector2(60.0, s.h * 0.5)
		s.vel = Vector2.RIGHT * s.speed
		var thing: Dictionary = s.put(kind, Vector2(200.0, s.h * 0.5 + s.core() * 0.3))
		thing.drift = Vector2.ZERO
		s.steer(Vector2.RIGHT)
		tally = _steps(s, 280.0 / s.speed)
		_check("kind %d, flat out over it at level %d: taken" % [kind, s.level], int(tally.get("catch", 0)) == 1)
	# at a walk over it, it is taken
	s = _bare()
	s.pos = Vector2(110.0, s.h * 0.5)
	leaf = s.put(Sim.Kind.LEAF, Vector2(150.0, s.h * 0.5 + 3.0))
	leaf.drift = Vector2.ZERO
	s.steer(Vector2.RIGHT * 0.3)
	tally = _steps(s, 6.0)
	_check("level 1, at a walk over a leaf: taken", int(tally.get("swallow", 0)) == 1)
	# a duck beside a small whirlpool, and beside a grown one
	var open := Sim.level_for(Sim.Kind.DUCK)
	for lv: int in [1, 2, open - 1, open]:
		s = _bare(lv)
		var duck: Dictionary = s.put(Sim.Kind.DUCK, s.pos + Vector2(s.core() * 2.0, 0))
		duck.drift = Vector2.ZERO
		var from: Vector2 = duck.pos
		tally = _steps(s, 5.0)
		var gone := int(tally.get("swallow", 0)) == 1
		var moved := -1.0 if gone else from.distance_to(duck.pos)
		if lv < open:
			_check("level %d: a duck two cores off stays afloat (moved %.1f, grip %.2f)" % [lv, moved, Sim.grip_of(Sim.Kind.DUCK, lv)], not gone)
		else:
			_check("level %d: the duck goes down" % lv, gone)
	s = _bare(1)
	var d1: Dictionary = s.put(Sim.Kind.DUCK, s.pos + Vector2(14.0, 0))
	d1.drift = Vector2.ZERO
	var at: Vector2 = d1.pos
	_steps(s, 3.0)
	_check("level 1: a duck beside it has hardly moved in three seconds (%.1f)" % at.distance_to(d1.pos), at.distance_to(d1.pos) < 12.0)
	# the two tiers above the toys, and the upgrades
	for kind: int in [Sim.Kind.BUCKET, Sim.Kind.ROWBOAT]:
		var at_lv := Sim.level_for(kind)
		for lv: int in [at_lv - 1, at_lv]:
			s = _bare(lv)
			var big: Dictionary = s.put(kind, s.pos + Vector2(s.core() * 1.6, 0))
			big.drift = Vector2.ZERO
			tally = _steps(s, 14.0)
			_check("level %d: %s" % [lv, "kind %d stays afloat" % kind if lv < at_lv else "kind %d goes down" % kind], (int(tally.get("swallow", 0)) == 1) == (lv == at_lv))
	for n: int in [6, 12, 24]:
		s = _bare(1, {"pull": n, "reach": n})
		leaf = s.put(Sim.Kind.LEAF, s.pos + Vector2(s.core() * 3.0, 0))
		leaf.drift = Vector2.ZERO
		tally = _steps(s, 4.0)
		_check("pull and reach %d: a still whirlpool takes a leaf three cores off" % n, int(tally.get("swallow", 0)) == 1)
	s = _bare(1, {"mouth": 14})
	_check("mouth 14: a duck goes down at level 1 (opens at %d)" % s.opens_at(Sim.Kind.DUCK), s.opens_at(Sim.Kind.DUCK) == 1)
	var names := []
	for kind in Sim.KINDS.size():
		names.append("%d:%d" % [kind, Sim.level_for(kind)])
	print("mouths (kind:level): " + " ".join(names))

## Plays `runs` runs and prints what they came to; gives back the median score.
func _many(runs: int, hasty: bool, skill := 1.0, from := 1) -> float:
	var scores: Array = []
	var levels: Array = []
	var secs: Array = []
	for k in runs:
		var s = Sim.new(k + 1)
		s.level = from
		_play(s, hasty, skill)
		scores.append(s.score)
		levels.append(s.level)
		secs.append(int(s.t))
	scores.sort()
	levels.sort()
	secs.sort()
	print("%s bot: score %d / %d / %d   level %d / %d / %d   seconds %d / %d / %d (lowest, median, highest of %d)" % [
		("sweeping" if hasty else ("patient" if skill >= 1.0 else "slower")) + ("" if from == 1 else " from level %d" % from), scores[0], scores[runs / 2], scores[-1], levels[0], levels[runs / 2], levels[-1],
		secs[0], secs[runs / 2], secs[-1], runs])
	return float(scores[runs / 2])

func _play(s: RefCounted, hasty: bool, skill := 1.0) -> void:
	var guard := 0
	var look := 0
	var best := {}
	while not s.is_over() and guard < 60 * 60 * 20:
		guard += 1
		# the nearest thing its mouth takes, worth weighed against the way
		look -= 1
		if not best.is_empty() and (float(best.sink) >= 0.0 or not s.things.has(best)):
			best = {}
		var best_w := -INF
		# a person looks again a few times a second, not sixty
		for th: Dictionary in (s.things if look <= 0 else []):
			if float(th.sink) >= 0.0 or s.grip(th.kind) < 1.0:
				continue
			var w: float = float(Sim.KINDS[th.kind].value) * 6.0 - float(th.pos.distance_to(s.pos))
			if w > best_w:
				best_w = w
				best = th
		if look <= 0:
			look = 1 if skill >= 1.0 else 30
		if best.is_empty():
			s.steer(Vector2.ZERO)
		elif hasty:
			# never slowing: flat out at it and on over it
			s.steer((best.pos - s.pos).normalized())
		else:
			var d: Vector2 = best.pos - s.pos
			s.steer(d.normalized() * clampf(d.length() / 18.0, 0.0, 1.0) * skill)
		s.step()
		s.events.clear()

func _kit() -> void:
	var s = Sim.new(3)
	s.fit({"spin": 2, "pull": 1, "mouth": 3, "reach": 4, "speed": 5})
	_check("a fitted run has its upgrades", is_equal_approx(s.spin, Sim.SPIN + 2 * Sim.SPIN_UP) and is_equal_approx(s.core(), Sim.CORE + 3 * Sim.MOUTH_UP)
		and is_equal_approx(s.reach(), s.core() * (Sim.REACH + 4 * Sim.REACH_UP)) and is_equal_approx(s.speed, Sim.SPEED + 5 * Sim.SPEED_UP) and s.level == 1)
	s.steer(Vector2.RIGHT)
	_steps(s, 3.0)
	_check("it travels as fast as it was fitted for and no faster (%.1f)" % s.vel.length(), s.vel.length() > s.speed * 0.98 and s.vel.length() <= s.speed + 0.001)
	_check("prices rise and none is free", Upgrades.price("spin", 0) > 0 and Upgrades.price("spin", 5) > Upgrades.price("spin", 4))
	s = Sim.new(3)
	s.steer(Vector2.RIGHT)
	s.steer(Vector2.ZERO)
	_steps(s, Sim.SPIN + Sim.DRAIN_T + 1.0)
	_check("a whirlpool left alone unwinds when its spin is out", s.is_over())

## The climb: runs played one after another, each banked and spent on the
## cheapest upgrade the bank covers, until a rowing boat goes down. The runs
## it took (200 when it never did).
func _ladder(skill: float, growth := Upgrades.GROWTH) -> int:
	var ups := {"spin": 0, "pull": 0, "mouth": 0, "reach": 0, "speed": 0}
	var bank := 0
	var minutes := 0.0
	var first := {}
	for run in range(1, 201):
		var s = Sim.new(1000 + run)
		s.fit(ups)
		_play(s, false, skill)
		bank += s.score
		minutes += float(s.t) / 60.0
		for tier in range(2, Sim.TIERS + 1):
			if int(s.taken[tier]) > 0 and not first.has(tier):
				first[tier] = run
		if run <= 3 or run % 10 == 0 or s.biggest == Sim.Kind.ROWBOAT:
			print("  run %d: score %d, level %d, %d s, biggest kind %d, bank %d, upgrades %s" % [run, s.score, s.level, int(s.t), s.biggest, bank, str(ups)])
		if s.biggest == Sim.Kind.ROWBOAT:
			print("ladder at skill %.1f, growth %.2f: a rowing boat in %d runs and %d minutes; tiers first taken on runs %s" % [skill, growth, run, int(minutes), str(first)])
			return run
		while true:
			var pick := ""
			for id: String in Upgrades.IDS:
				if pick == "" or Upgrades.price(id, ups[id], growth) < Upgrades.price(pick, ups[pick], growth):
					pick = id
			if Upgrades.price(pick, ups[pick], growth) > bank:
				break
			bank -= Upgrades.price(pick, ups[pick], growth)
			ups[pick] += 1
	print("ladder at skill %.1f: no rowing boat in 200 runs (%d minutes)" % [skill, int(minutes)])
	return 200
