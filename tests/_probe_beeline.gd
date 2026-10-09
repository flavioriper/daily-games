extends SceneTree

## Flies Beeline's sim headless with a bot and prints how far each run went.
## Run after touching arcade/beeline_sim.gd.
##   godot --headless --script tests/_probe_beeline.gd -- [runs] [react ms] [aim error, units] [gates]
## The bot beats when she sinks under a line near the next gap's foot, no
## sooner than `react` after its last beat and off by up to `error` units.
## With no reaction time and no error it must never fall (every gap can be
## reached from the last by a player who plans nothing); with a person's it
## should end somewhere.
## Then the dewdrop, the wide gates and the Second chance are checked.

const Sim = preload("res://arcade/beeline_sim.gd")
const Boosters = preload("res://arcade/boosters.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 20
	var react := float(args[1]) / 1000.0 if args.size() > 1 else 0.0
	var err := float(args[2]) if args.size() > 2 else 0.0
	var limit := int(args[3]) if args.size() > 3 else 400
	var scores: Array = []
	for k in runs:
		scores.append(fly(Sim.new(k + 1), k + 101, react, err, limit))
	scores.sort()
	print("react %d ms, error %.0f: lowest %d  median %d  highest %d (of %d gates, %d runs)" % [
		int(react * 1000), err, scores[0], scores[scores.size() / 2], scores[-1], limit, runs])
	if react == 0.0 and err == 0.0:
		_check("the perfect bot never falls", int(scores[0]) >= limit)
	# the dewdrop: left to sink, she is lifted once and falls the second time
	var s = Sim.new(3)
	Boosters.apply("beeline", s, ["bl_dew"])
	s.flap()
	var tally := _run(s, 2000)
	_check("a dewdrop bursts once", int(tally.get("dew", 0)) == 1 and s.is_over())
	# wide gates: the first ones are wider by the sim's own number
	s = Sim.new(3)
	Boosters.apply("beeline", s, ["bl_wide"])
	_check("the first gates stand wide", is_equal_approx(float(s.gates[0].gap), Sim.gap_of(0) + Sim.WIDE_BY))
	# the Second chance: a run ended goes on, and scores again
	s = Sim.new(5)
	s.flap()
	_run(s, 2000)
	var was: int = s.score
	Boosters.revive("beeline", s)
	_check("a revived run waits for a beat", s.phase == Sim.Phase.READY)
	var got := fly(s, 9, 0.0, 0.0, was + 5)
	_check("a revived run scores again", got >= was + 5)
	_check("ribbons at 10, 20, 30 and 40", Sim.ribbons_of(9) == 0 and Sim.ribbons_of(10) == 1 and Sim.ribbons_of(40) == 4)
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

func _run(s: RefCounted, steps: int) -> Dictionary:
	var tally := {}
	for i in steps:
		s.step()
		for ev: Dictionary in s.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
		s.events.clear()
		if s.is_over():
			break
	return tally

func fly(s: RefCounted, seed_v: int, react: float, err: float, limit: int) -> int:
	var pick := RandomNumberGenerator.new()
	pick.seed = seed_v
	var wait := 0.0
	var off := 0.0
	s.flap()
	var guard := 0
	while not s.is_over() and s.score < limit and guard < 120 * 60 * 30:
		guard += 1
		var g: Dictionary = s.next_gate()
		# beat when the body's foot would sink under the line
		var line: float = g.cy + g.gap * 0.5 - Sim.R - 14.0 + off
		wait -= Sim.DT
		if s.y > line and s.v > 0.0 and wait <= 0.0:
			s.flap()
			wait = react * pick.randf_range(0.6, 1.4)
			off = pick.randf_range(-err, err)
		s.step()
		s.events.clear()
	return s.score
