extends SceneTree

## Plays Firefly's stages headless with a simple bot and prints, per stage
## and difficulty, how often the bot cleared it and met its goal, and the
## median score and seconds of an attempt. Run after touching
## arcade/firefly_sim.gd.
##   godot --headless --script tests/_probe_firefly.gd -- [stage|all] [difficulty|all] [seeds] [skill]
## Difficulty 0 Easy .. 3 Insane. An attempt that runs past CAP game seconds
## is stopped and counted as not cleared (the "cap" column).
##
## The bot sits under the lowest bug and never stops firing, so its rates
## for catching in flight, breaking a wave, going untouched and winning a
## firefly back say more about the bot than the stage.

const Sim = preload("res://arcade/firefly_sim.gd")
const CAP := 300.0
const NAMES := ["E", "M", "H", "I"]

## 1 plays well; lower fires less and dodges less.
var skill := 1.0
var _rng := RandomNumberGenerator.new()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var stages: Array = range(1, Sim.STAGES.size() + 1)
	if args.size() > 0 and args[0] != "all":
		stages = [int(args[0])]
	var diffs: Array = range(Sim.DIFF.size())
	if args.size() > 1 and args[1] != "all":
		diffs = [int(args[1])]
	var seeds := int(args[2]) if args.size() > 2 else 8
	skill = float(args[3]) if args.size() > 3 else 1.0
	_rng.seed = 11
	var t0 := Time.get_ticks_usec()
	var game_s := 0.0
	print("skill %.2f, %d seeds a row, cap %d s" % [skill, seeds, int(CAP)])
	print("stage           diff  clear   goal   median score  median s  cap")
	for n: int in stages:
		for d: int in diffs:
			var clears := 0
			var goals := 0
			var capped := 0
			var scores: Array = []
			var secs: Array = []
			for k in seeds:
				var sim: RefCounted = Sim.new(1 + n * 1000 + d * 100 + k, n, d)
				while sim.phase != Sim.Phase.WON and sim.phase != Sim.Phase.OVER and sim.t < CAP:
					_bot(sim)
					sim.step()
					sim.events.clear()
				if sim.phase == Sim.Phase.WON:
					clears += 1
				elif sim.phase != Sim.Phase.OVER:
					capped += 1
				if sim.goal_done:
					goals += 1
				scores.append(sim.score)
				secs.append(sim.t)
				game_s += sim.t
			print("%2d %-13s  %s   %3d%%   %3d%%   %12d  %8.0f  %3d" % [n, String(Sim.STAGES[n - 1].name).left(13), NAMES[d],
				roundi(100.0 * clears / seeds), roundi(100.0 * goals / seeds), _median(scores), _median(secs), capped])
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("sim ms per game second: %.3f" % (ms / maxf(game_s, 0.001)))
	quit()

static func _median(a: Array) -> float:
	var s := a.duplicate()
	s.sort()
	if s.is_empty():
		return 0.0
	return float(s[s.size() / 2]) if s.size() % 2 == 1 else (float(s[s.size() / 2 - 1]) + float(s[s.size() / 2])) * 0.5

## Sits under the lowest bug still well above it (never a moth on its way
## to spin its beam), steps aside from a bug coming down on it and from a
## beam opening or open, sidesteps seeds coming down on it, fires.
func _bot(sim: RefCounted) -> void:
	sim.fire = _rng.randf() < skill
	var aim: float = sim.px
	var best := -1.0
	for e: Dictionary in sim.enemies:
		if e.st == Sim.St.WAIT or e.beam_run:
			continue
		if e.pos.y > best and e.pos.y < Sim.PLAYER_Y - 90.0:
			best = e.pos.y
			aim = e.pos.x
	for e: Dictionary in sim.enemies:
		if e.st != Sim.St.WAIT and e.st != Sim.St.FORM and e.pos.y > Sim.PLAYER_Y - 90.0 and e.pos.y < Sim.PLAYER_Y + 10.0 \
				and absf(e.pos.x - sim.px) < 22.0 and _rng.randf() < skill:
			aim = sim.px + (40.0 if e.pos.x < sim.px else -40.0)
	for e: Dictionary in sim.enemies:
		var beaming: bool = e.st == Sim.St.BEAM or (e.beam_run and e.pos.y > Sim.H * 0.4)
		if beaming and absf(e.pos.x - sim.px) < 26.0 and _rng.randf() < skill:
			aim = sim.px + (40.0 if e.pos.x < sim.px else -40.0)
	for b: Dictionary in sim.bullets:
		if b.pos.y > Sim.PLAYER_Y - 90.0 and absf(b.pos.x - sim.px) < 14.0 and _rng.randf() < skill:
			aim = sim.px + (30.0 if b.pos.x < sim.px else -30.0)
	sim.target_x = aim
