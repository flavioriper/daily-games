extends SceneTree

## Proves Eddy's water headless and plays it with two bots. Run after
## touching arcade/eddy_sim.gd.
##   godot --headless --script tests/_probe_eddy.gd -- [runs]
## The water's three promises: a whirlpool held by a leaf takes it, one
## hurried past the same leaf does not, and a duck beside a small whirlpool
## stays where it is until the whirlpool has grown. Then a patient bot (it
## slows as it nears what it is after) and a hasty one (always flat out) each
## play `runs` runs: the patient one must do far better. Then the boosters
## and the Second chance.

const Sim = preload("res://arcade/eddy_sim.gd")
const Boosters = preload("res://arcade/boosters.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 20
	_water()
	var slow := _many(runs, false)
	var fast := _many(runs, true)
	_many(runs, false, 0.6)
	# grown, the whirlpool is stronger, and hurry must still not pay
	var slow_big := _many(runs, false, 1.0, 8)
	var fast_big := _many(runs, true, 1.0, 8)
	_check("grown to level 8, the patient bot still scores at least three times the hasty one", slow_big >= fast_big * 3.0)
	_check("the patient bot scores at least three times the hasty one", slow >= fast * 3.0)
	_kit()
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

## An empty pond with the whirlpool at its middle and the spin running.
func _bare(lv := 1) -> RefCounted:
	var s = Sim.new(1)
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
	# hurried straight over the same leaf
	for lv: int in [1, 5, 10]:
		s = _bare(lv)
		s.pos = Vector2(40.0, s.h * 0.5)
		leaf = s.put(Sim.Kind.LEAF, Vector2(150.0, s.h * 0.5 + s.core() * 0.3))
		leaf.drift = Vector2.ZERO
		var from: Vector2 = leaf.pos
		s.steer(Vector2.RIGHT)
		tally = _steps(s, 1.6)
		s.steer(Vector2.ZERO)
		var moved := from.distance_to(leaf.pos) if s.things.size() > 0 else -1.0
		_check("level %d, flat out over a leaf: not taken (moved %.1f)" % [lv, moved], int(tally.get("catch", 0)) == 0 and s.things.size() == 1)
	# at a walk over it, it is taken
	s = _bare()
	s.pos = Vector2(110.0, s.h * 0.5)
	leaf = s.put(Sim.Kind.LEAF, Vector2(150.0, s.h * 0.5 + 3.0))
	leaf.drift = Vector2.ZERO
	s.steer(Vector2.RIGHT * 0.12)
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
	print("mouths: duck from level %d, boat %d, ball %d" % [open, Sim.level_for(Sim.Kind.BOAT), Sim.level_for(Sim.Kind.BALL)])

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
		("hasty" if hasty else ("patient" if skill >= 1.0 else "slower")) + ("" if from == 1 else " from level %d" % from), scores[0], scores[runs / 2], scores[-1], levels[0], levels[runs / 2], levels[-1],
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
			if float(th.sink) >= 0.0 or Sim.grip_of(th.kind, s.level) < 1.0:
				continue
			var w: float = float(Sim.KINDS[th.kind].value) * 6.0 - float(th.pos.distance_to(s.pos))
			if w > best_w:
				best_w = w
				best = th
		if look <= 0:
			look = 1 if skill >= 1.0 else 30
		if hasty:
			# never slowing: up and down the pond flat out, a lane at a time
			var lane: int = int(float(s.t) * Sim.SPEED / (float(s.h) - 40.0))
			var x: float = 30.0 + fposmod(lane * 37.0, Sim.W - 60.0)
			var y: float = 20.0 if lane % 2 == 0 else float(s.h) - 20.0
			s.steer((Vector2(x, y) - s.pos).normalized())
		elif best.is_empty():
			s.steer(Vector2.ZERO)
		else:
			var d: Vector2 = best.pos - s.pos
			s.steer(d.normalized() * clampf(d.length() / 45.0, 0.0, 1.0) * skill)
		s.step()
		s.events.clear()

func _kit() -> void:
	var s = Sim.new(3)
	Boosters.apply("eddy", s, ["ed_long", "ed_head"])
	_check("long spin and a head start", is_equal_approx(s.spin, Sim.SPIN + Sim.LONG_BY) and s.level == 1 + Sim.HEAD_LEVELS)
	s = Sim.new(3)
	s.steer(Vector2.RIGHT)
	s.steer(Vector2.ZERO)
	_steps(s, Sim.SPIN + Sim.DRAIN_T + 1.0)
	_check("a whirlpool left alone unwinds when its spin is out", s.is_over())
	Boosters.revive("eddy", s)
	_check("a revived run waits for the pad with half its spin", s.phase == Sim.Phase.READY and is_equal_approx(s.spin, s.spin_full * Sim.REVIVE))
	var was: int = s.score
	_play(s, false)
	_check("a revived run scores again (%d more)" % (s.score - was), s.score > was)
