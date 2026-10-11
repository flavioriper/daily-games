extends SceneTree

## Proves Gumdrop's syrup headless and plays it with two bots. Run after
## touching arcade/gumdrop_sim.gd or arcade/gumdrop_mould.gd.
##   godot --headless --script tests/_probe_gumdrop.gd -- [runs] [levels]
## Every design is built and its cells counted. The syrup's promises: none
## is made or lost as it runs, a cell squeezed from its middle a little at
## a time fills without a drop over its walls, and the same cell squeezed
## beside a wall without a pause spills. Then a careful bot (each cell from
## its middle, in pulses, the right pots) plays `runs` runs of `levels`
## moulds and must serve every one over the mark, and a careless one (the
## first pot, held down by a wall) must not get far. Then the boosters and
## the Second chance.

const Sim = preload("res://arcade/gumdrop_sim.gd")
const Mould = preload("res://arcade/gumdrop_mould.gd")
const Boosters = preload("res://arcade/boosters.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 2
	var levels := int(args[1]) if args.size() > 1 else 16
	_designs()
	_syrup()
	_careful(runs, levels)
	_careless(runs)
	_kit()
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

func _designs() -> void:
	var least := 9999
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for row: Array in Mould.DESIGNS:
		var m := Mould.build(row[0], row[1], row[2])
		if m.is_empty():
			_check("design %s builds" % str(row), false)
			continue
		Mould.dress(m, 9, rng)
		var s = Sim.new(1)
		s.deal(m)
		var small := 9999
		var all := 0
		for c in s.count.size():
			small = mini(small, s.count[c])
			all += s.count[c]
		least = mini(least, small)
		print("     design %s: %d cells, %d squares, the smallest %d" % [str(row), s.count.size(), all, small])
	_check("every design's smallest cell has 12 squares or more (%d)" % least, least >= 12)

func _run(s: RefCounted, seconds: float) -> Dictionary:
	var tally := {}
	for i in int(seconds / Sim.DT):
		s.step()
		for ev: Dictionary in s.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
		s.events.clear()
	return tally

func _total(s: RefCounted) -> float:
	var sum := 0.0
	for i in s.depth.size():
		sum += s.depth[i]
	return sum

func _fill(s: RefCounted, c: int) -> float:
	var sum := 0.0
	for i in s.depth.size():
		if s.reg[i] == c:
			sum += minf(s.depth[i], 1.0)
	return sum / (s.count[c] * Sim.FULL)

## Squeezes cell `c` from `from` with pot `pot` until it is `upto` full, in
## pulses of `pulse` seconds with `rest` between (0: never lets go).
func _squeeze(s: RefCounted, c: int, pot: int, from: Vector2, upto: float, pulse: float, rest: float) -> Dictionary:
	var tally := {}
	s.pick(pot)
	s.aim(from)
	var guard := 0
	while _fill(s, c) < upto and float(s.pots[pot].left) > 0.0 and guard < 400 and s.phase <= Sim.Phase.PLAY:
		guard += 1
		s.squeeze(true)
		var a := _run(s, pulse)
		s.squeeze(false)
		var b := _run(s, rest) if rest > 0.0 else {}
		for k in a:
			tally[k] = int(tally.get(k, 0)) + int(a[k])
		for k in b:
			tally[k] = int(tally.get(k, 0)) + int(b[k])
	return tally

func _syrup() -> void:
	var s = Sim.new(3)
	var m := Mould.build(Mould.Shape.ROUND, Mould.Cut.SECTORS, 2)
	m.want = [0, 2]
	m.pots = [0, 2]
	s.deal(m)
	s.events.clear()
	var before := 0.0
	for p: Dictionary in s.pots:
		before += float(p.left)
	var tally := _squeeze(s, 0, 0, s.centre_of(0), 0.99, 0.2, 0.25)
	_run(s, 2.0)
	var left := 0.0
	for p: Dictionary in s.pots:
		left += float(p.left)
	_check("no syrup is made or lost as it runs (%.3f out of the pots, %.3f in the tray)" % [before - left, _total(s)], absf((before - left) - _total(s)) < 0.01)
	_check("a cell squeezed from its middle in pulses fills with nothing over a wall (%d spills)" % int(tally.get("spill", 0)), int(tally.get("spill", 0)) == 0 and _fill(s, 0) >= 0.97)
	_check("and nothing of it is in the next cell (%.3f)" % _fill(s, 1), _fill(s, 1) < 0.001)
	_check("it sets (%.2f)" % s.cell_match[0], s.cell_match[0] >= Sim.SET_AT)
	# the same cell, held down by its wall
	s = Sim.new(3)
	s.deal(m)
	s.events.clear()
	var by_wall: Vector2 = s.centre_of(0).lerp(s.centre_of(1), 0.38)
	if s.reg[Sim.square(by_wall)] != 0:
		by_wall = s.centre_of(0).lerp(s.centre_of(1), 0.25)
	tally = _squeeze(s, 0, 0, by_wall, 0.99, 0.5, 0.0)
	_check("held down beside a wall it spills before it is full (%d spills, the next cell %.2f)" % [int(tally.get("spill", 0)), _fill(s, 1)], int(tally.get("spill", 0)) > 0)
	# two pigments blend to the flavour between them
	s = Sim.new(3)
	m.want = [1, 2]
	m.pots = [0, 2]
	s.deal(m)
	_squeeze(s, 0, 0, s.centre_of(0), 0.49, 0.2, 0.25)
	_squeeze(s, 0, 1, s.centre_of(0), 0.99, 0.2, 0.25)
	_run(s, 1.0)
	s.measure()
	_check("cherry and lemon half and half are orange (match %.2f)" % s.cell_match[0], s.cell_match[0] >= 0.9)
	# how long a step takes with a mould full of syrup
	s = Sim.new(4)
	s.level = 12
	s.deal()
	for c in s.count.size():
		_squeeze(s, c, 0, s.centre_of(c), 0.6, 0.3, 0.0)
	s.squeeze(true)
	var from := Time.get_ticks_usec()
	for i in 600:
		s.step()
	s.events.clear()
	print("     a step with a wet mould: %.3f ms" % ((Time.get_ticks_usec() - from) / 600.0 / 1000.0))

## Plays one mould as a careful hand would. Returns the seconds it took.
func _play_carefully(s: RefCounted) -> float:
	var from: float = s.t
	for c in s.count.size():
		var recipe: Dictionary = Mould.recipe(int(s.mould.want[c]), s.mould.pots)
		var upto := 0.0
		for f: int in recipe:
			upto += float(recipe[f]) * 0.99
			_squeeze(s, c, s.mould.pots.find(f), s.centre_of(c), upto, 0.15, 0.3)
	_run(s, 0.5)
	s.serve()
	return s.t - from

func _careful(runs: int, levels: int) -> void:
	var worst := 100
	var lost := 0
	var secs := 0.0
	var moulds := 0
	var spills := 0
	for r in runs:
		var s = Sim.new(100 + r)
		s.events.clear()
		for lv in levels:
			secs += _play_carefully(s)
			moulds += 1
			var tally := _run(s, Sim.SETTLE_T + Sim.SHOW_T + 0.1)
			if int(s.verdict.pct) < 93:
				print("     level %d: %d%%" % [lv + 1, int(s.verdict.pct)])
			worst = mini(worst, int(s.verdict.pct))
			if s.is_over():
				lost += 1
				print("     careful bot lost at level %d with %d%% (%s)" % [s.level, int(s.verdict.pct), str([s.mould.shape, s.mould.cut, s.mould.n])])
				break
	print("     careful bot: %d moulds, %.1f s a mould, the worst %d%%" % [moulds, secs / maxf(1.0, moulds), worst])
	_check("the careful bot serves every mould of %d runs of %d (lost %d)" % [runs, levels, lost], lost == 0)
	_check("and never within five of the top mark (%d)" % worst, worst >= Sim.MARK_TOP + 5)

func _careless(runs: int) -> void:
	var far := 0
	for r in runs:
		var s = Sim.new(200 + r)
		s.events.clear()
		var guard := 0
		while not s.is_over() and guard < 30:
			guard += 1
			for c in s.count.size():
				var by: Vector2 = s.centre_of(c).lerp(s.centre_of((c + 1) % s.count.size()), 0.3)
				s.pick(0)
				s.aim(by)
				s.squeeze(true)
				_run(s, 3.0)
				s.squeeze(false)
			_run(s, 0.3)
			s.serve()
			_run(s, Sim.SETTLE_T + Sim.SHOW_T + 0.1)
		far = maxi(far, s.level)
	_check("the careless bot is over by level 3 (%d)" % far, far <= 3)

func _kit() -> void:
	var s = Sim.new(9)
	var plain: float = float(s.pots[0].full)
	Boosters.apply("gumdrop", s, ["gd_full", "gd_tall"])
	_check("fuller pots, taller walls", is_equal_approx(float(s.pots[0].full), plain * Sim.FULLER) and is_equal_approx(s.wall, Sim.TALLER))
	s.squeeze(true)
	_run(s, 0.3)
	s.squeeze(false)
	s.serve()
	_run(s, Sim.SETTLE_T + Sim.SHOW_T + 0.1)
	_check("a mould served nearly clear ends the run", s.is_over())
	var had: int = s.score
	Boosters.revive("gumdrop", s)
	_check("the Second chance clears the mould and fills the pots", not s.is_over() and _total(s) == 0.0 and s.score <= had and float(s.pots[0].left) == float(s.pots[0].full))
