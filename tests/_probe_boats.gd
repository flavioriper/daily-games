extends SceneTree

## Toy Boats' rules and computer, headless:
##     godot --headless --path . --script res://tests/_probe_boats.gd -- [games] [seed]
## The rules' own cases (a fleet's validity, the answers, the slate refusing
## what cannot be, a shown fleet agreeing or not, the wire), then every
## pairing of levels over `games` games (200), who throws first alternating:
## each level must beat the one under it, and it prints how many pebbles each
## needs alone to sink a fleet.

const Rules = preload("res://versus/boats_rules.gd")
const AI = preload("res://versus/boats_ai.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 200
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 7
	_rules(rng)
	_alone(games, rng)
	_pairs(games, rng)
	print("FAILS ", _fails)
	quit(1 if _fails > 0 else 0)

func _ok(what: String, yes: bool) -> void:
	if not yes:
		_fails += 1
	print("  ", "ok  " if yes else "FAIL", " ", what)

func _rules(rng: RandomNumberGenerator) -> void:
	print("rules")
	var fleet: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 2, 0), Vector3i(0, 3, 0), Vector3i(9, 8, 1)]
	_ok("a fleet side by side is valid", Rules.valid(fleet))
	var over := fleet.duplicate()
	over[1] = Vector3i(4, 0, 1)
	_ok("two boats on one square are not", not Rules.valid(over))
	var off := fleet.duplicate()
	off[0] = Vector3i(6, 0, 0)
	_ok("a boat off the pond is not", not Rules.valid(off))
	var all_ok := true
	var apart_ok := true
	for k in 300:
		var f := Rules.random_fleet(rng, k % 2 == 1)
		all_ok = all_ok and Rules.valid(f)
		if k % 2 == 1:
			for i in 5:
				for j in 5:
					if i == j:
						continue
					for a in Rules.cells_of(i, f[i]):
						for b in Rules.cells_of(j, f[j]):
							var d := Rules.xy(a) - Rules.xy(b)
							if absi(d.x) <= 1 and absi(d.y) <= 1:
								apart_ok = false
	_ok("300 fleets by chance are valid", all_ok)
	_ok("the ones laid apart do not touch", apart_ok)
	_ok("pack and unpack", Rules.unpack(Rules.pack(fleet)) == fleet)
	_ok("unpack refuses rubbish", Rules.unpack("000.010.020.030").is_empty() and Rules.unpack("000.010.020.030.99x").is_empty()
		and Rules.unpack("000.000.020.030.981").is_empty() and Rules.unpack("").is_empty())
	_ok("a seal is the fleet's and the salt's", Rules.seal(fleet, "a") == Rules.seal(fleet, "a") and Rules.seal(fleet, "a") != Rules.seal(fleet, "b")
		and Rules.seal(fleet, "a") != Rules.seal(over, "a") and Rules.seal(fleet, "a").length() == 64)
	var pond := Rules.new()
	pond.lay(fleet)
	var slate := Rules.new()
	_ok("a miss", pond.fire(Rules.cell(5, 5)).r == Rules.MISS and slate.note(Rules.cell(5, 5), Rules.MISS))
	_ok("the same square again answers nothing", pond.fire(Rules.cell(5, 5)).r == Rules.NONE and not slate.note(Rules.cell(5, 5), Rules.MISS))
	_ok("a hit", pond.fire(Rules.cell(9, 8)).r == Rules.HIT and slate.note(Rules.cell(9, 8), Rules.HIT))
	_ok("sunk said of a boat not all hit is refused", not slate.note(Rules.cell(4, 4), Rules.SUNK, 4, Vector3i(4, 4, 0))
		and not slate.note(Rules.cell(9, 9), Rules.SUNK, 3, Vector3i(9, 7, 1)))
	var a: Dictionary = pond.fire(Rules.cell(9, 9))
	_ok("the second square sinks the two", a.r == Rules.SUNK and a.boat == 4 and slate.note(Rules.cell(9, 9), Rules.SUNK, 4, Vector3i(9, 8, 1)))
	_ok("the slate so far agrees with the fleet", slate.agrees(fleet))
	var moved := fleet.duplicate()
	moved[0] = Vector3i(1, 5, 0)
	_ok("and not with one that has a boat where a miss was said", not slate.agrees(moved))
	var liar := Rules.new()
	liar.note(Rules.cell(0, 0), Rules.MISS)
	_ok("a miss said over a boat is found out", not liar.agrees(fleet))
	var quiet := Rules.new()
	quiet.note(Rules.cell(9, 8), Rules.HIT)
	quiet.note(Rules.cell(9, 9), Rules.HIT)
	_ok("a boat sunk and not said is found out", not quiet.agrees(fleet))
	var n := 0
	for c in Rules.CELLS:
		if pond.fire(c).r == Rules.SUNK:
			n += 1
	_ok("every square tried sinks all five", n == 4 and pond.all_sunk() and pond.afloat() == 0)

## One game's pebbles for `level` to sink a fleet by chance, alone.
func _solo(level: int, rng: RandomNumberGenerator) -> int:
	var pond := Rules.new()
	pond.lay(Rules.random_fleet(rng, rng.randf() < 0.5))
	var slate := Rules.new()
	while not pond.all_sunk():
		var c := AI.plan(slate, level, rng)
		var a: Dictionary = pond.fire(c)
		if a.r == Rules.NONE or not slate.note(c, a.r, a.boat, pond.boats[a.boat] if a.r == Rules.SUNK else Rules.HIDDEN):
			_fails += 1
			print("  FAIL the computer threw at ", c, " and the slate refused ", a)
			return 100
	if not slate.agrees(pond.boats):
		_fails += 1
		print("  FAIL an honest slate does not agree with its fleet")
	return pond.shots

func _alone(games: int, rng: RandomNumberGenerator) -> void:
	print("alone, pebbles to sink a fleet over ", games, " games")
	var means := []
	for level in 3:
		var sum := 0
		var worst := 0
		var best := 100
		var t := Time.get_ticks_usec()
		for g in games:
			var n := _solo(level, rng)
			sum += n
			worst = maxi(worst, n)
			best = mini(best, n)
		means.append(float(sum) / games)
		print("  level %d: mean %.1f, best %d, worst %d, %.2f ms a throw" % [level, means[level], best, worst,
			(Time.get_ticks_usec() - t) / 1000.0 / maxf(1.0, sum)])
	_ok("each level needs fewer than the one under", means[0] > means[1] and means[1] > means[2])

func _pairs(games: int, rng: RandomNumberGenerator) -> void:
	print("pairs, wins over ", games, " games")
	for a in 3:
		for b in range(a + 1, 3):
			var wins := [0, 0]
			for g in games:
				var levels := [a, b]
				var ponds := [Rules.new(), Rules.new()]
				var slates := [Rules.new(), Rules.new()]
				for p in 2:
					ponds[p].lay(AI.fleet(levels[p], rng))
				var turn := g % 2
				while true:
					var c := AI.plan(slates[turn], levels[turn], rng)
					var ans: Dictionary = ponds[1 - turn].fire(c)
					slates[turn].note(c, ans.r, ans.boat, ponds[1 - turn].boats[ans.boat] if ans.r == Rules.SUNK else Rules.HIDDEN)
					if ponds[1 - turn].all_sunk():
						wins[turn] += 1
						break
					turn = 1 - turn
			print("  level %d v level %d: %d - %d" % [a, b, wins[0], wins[1]])
			_ok("level %d beats level %d" % [b, a], wins[1] > wins[0] * 1.5)
