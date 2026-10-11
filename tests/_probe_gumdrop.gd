extends SceneTree

## Proves Gumdrop's syrup headless and plays it with two bots. Run after
## touching arcade/gumdrop_sim.gd or arcade/gumdrop_mould.gd.
##   godot --headless --script tests/_probe_gumdrop.gd -- [runs] [levels]
## Every design is built and its cells counted. The syrup's promises: no
## pigment is made or lost as it soaks, nothing crosses a wall however hard
## a cell is squeezed beside it, a cell held from its middle blooms to its
## walls and evens out once let go, more makes it stronger and past the
## card's shade darker, and two pigments blend to the flavour between. Then
## a careful bot (each cell from its middle, held until it is the card's
## shade, a rest after) plays `runs` runs of `levels` moulds and must serve
## every one over the mark, and a careless one (the first pot, a second at
## every cell's edge) must not get far. Then the boosters and the Second
## chance.

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

## All the pigment in the mould, and all of it in one cell (-1 the tray).
func _total(s: RefCounted, c := -2) -> float:
	var sum := 0.0
	for i in s.red.size():
		if c == -2 or s.reg[i] == c:
			sum += s.red[i] + s.yel[i] + s.blu[i]
	return sum

## How far a cell is toward the card's shade, by its mean concentration.
func _fill(s: RefCounted, c: int) -> float:
	return float(s.fill_of(c).x) / Sim.C_FULL

## Holds the dropper on `from` with pot `pot` until cell `c` is `upto` of
## the way to the card's shade, then rests `rest` seconds.
func _hold(s: RefCounted, c: int, pot: int, from: Vector2, upto: float, rest: float) -> void:
	s.pick(pot)
	s.aim(from)
	var guard := 0
	s.squeeze(true)
	while _fill(s, c) < upto and guard < 1800 and s.phase <= Sim.Phase.PLAY:
		guard += 1
		s.step()
		s.events.clear()
	s.squeeze(false)
	if rest > 0.0:
		_run(s, rest)

func _syrup() -> void:
	var s = Sim.new(3)
	var m := Mould.build(Mould.Shape.ROUND, Mould.Cut.SECTORS, 2)
	m.want = [0, 2]
	m.pots = [0, 2]
	m.mixed = -1
	s.deal(m)
	s.events.clear()
	_hold(s, 0, 0, s.centre_of(0), 1.0, 4.0)
	s.measure()
	_check("no pigment is made or lost as it soaks (%.2f squeezed, %.2f in the jelly)" % [s.poured, _total(s)], absf(s.poured - _total(s)) < 0.05)
	var f: Vector2 = s.fill_of(0)
	_check("a cell held from its middle blooms to its walls and evens out (the least square %.2f of the mean %.2f, match %.2f)" % [f.y, f.x, s.cell_match[0]], f.y >= 0.6 * f.x and s.cell_match[0] >= 0.9)
	_check("and nothing of it is in the next cell or on the tray (%.4f, %.4f)" % [_total(s, 1), _total(s, -1)], _total(s, 1) == 0.0 and _total(s, -1) == 0.0)
	# the same cell, held down hard beside its wall
	s = Sim.new(3)
	s.deal(m)
	s.events.clear()
	var by_wall: Vector2 = s.centre_of(0).lerp(s.centre_of(1), 0.38)
	if s.reg[Sim.square(by_wall)] != 0:
		by_wall = s.centre_of(0).lerp(s.centre_of(1), 0.25)
	_hold(s, 0, 0, by_wall, 2.0, 2.0)
	_check("held hard beside a wall nothing crosses it (the next cell %.4f, the tray %.4f, the cell itself %.2f of the shade)" % [_total(s, 1), _total(s, -1), _fill(s, 0)], _total(s, 1) == 0.0 and _total(s, -1) == 0.0 and _fill(s, 0) >= 1.9)
	# more is stronger, and past the card's shade darker
	s = Sim.new(3)
	s.deal(m)
	var last := -1.0
	var climbs := true
	var at_shade := 0.0
	var dark := 0.0
	s.pick(0)
	s.aim(s.centre_of(0))
	for k in 20:
		s.squeeze(true)
		_run(s, 0.5)
		s.squeeze(false)
		_run(s, 0.5)
		s.measure()
		var fill := _fill(s, 0)
		climbs = climbs and fill > last
		last = fill
		if at_shade == 0.0 and fill >= 1.0:
			_run(s, 3.0)
			s.measure()
			at_shade = s.cell_match[0]
		if fill >= 2.0 and dark == 0.0:
			_run(s, 3.0)
			s.measure()
			dark = s.cell_match[0]
	_check("more syrup is more colour, with no limit (%.2f of the shade after %d holds)" % [last, 20], climbs and last >= 2.0)
	_check("at the card's shade the cell matches it (%.2f), twice over it is darker and matches less (%.2f)" % [at_shade, dark], at_shade >= 0.9 and dark > 0.0 and dark < at_shade - 0.04)
	# two pigments blend to the flavour between them
	s = Sim.new(3)
	m.want = [1, 2]
	m.pots = [0, 2]
	s.deal(m)
	_hold(s, 0, 0, s.centre_of(0), 0.5, 0.5)
	_hold(s, 0, 1, s.centre_of(0), 1.0, 4.0)
	s.measure()
	_check("cherry and lemon half and half are orange (match %.2f)" % s.cell_match[0], s.cell_match[0] >= 0.9)
	# a bloom comes to rest
	s = Sim.new(3)
	m.want = [0, 2]
	s.deal(m)
	_hold(s, 0, 0, s.centre_of(0), 1.0, 0.0)
	var rested := 0.0
	while s.moving and rested < 60.0:
		_run(s, 1.0)
		rested += 1.0
	_check("a bloom let go comes to rest (%.0f s)" % rested, not s.moving and rested <= 30.0)
	# how long a step takes with a mould full of syrup
	s = Sim.new(4)
	s.level = 12
	s.deal()
	for c in s.count.size():
		_hold(s, c, 0, s.centre_of(c), 0.6, 0.0)
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
			upto += float(recipe[f]) * 0.98
			_hold(s, c, s.mould.pots.find(f), s.centre_of(c), upto, 0.0)
	_run(s, 3.0)
	s.serve()
	return s.t - from

func _careful(runs: int, levels: int) -> void:
	var worst := 100
	var lost := 0
	var secs := 0.0
	var moulds := 0
	for r in runs:
		var s = Sim.new(100 + r)
		s.events.clear()
		for lv in levels:
			secs += _play_carefully(s)
			moulds += 1
			_run(s, Sim.SETTLE_T + Sim.SHOW_T + 0.1)
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
				_run(s, 1.0)
				s.squeeze(false)
			_run(s, 0.3)
			s.serve()
			_run(s, Sim.SETTLE_T + Sim.SHOW_T + 0.1)
		far = maxi(far, s.level)
	_check("the careless bot is over by level 3 (%d)" % far, far <= 3)

func _kit() -> void:
	var s = Sim.new(9)
	var plain: int = s.mark()
	Boosters.apply("gumdrop", s, ["gd_soft", "gd_kind"])
	_check("softer jelly, kinder marks", is_equal_approx(s.soak, Sim.SOAK * Sim.SOFTER) and s.mark() == plain - Sim.KINDER)
	# a softer jelly: the same hold reaches further
	var reach := []
	for soft in [false, true]:
		var q = Sim.new(9)
		if soft:
			q.softer()
		q.pick(0)
		q.aim(q.centre_of(0))
		q.squeeze(true)
		_run(q, 0.4)
		q.squeeze(false)
		_run(q, 2.0)
		var far := 0
		for i in Sim.N * Sim.N:
			if q.reg[i] == 0 and q.red[i] + q.yel[i] + q.blu[i] > 0.1:
				far += 1
		reach.append(far)
	_check("a softer jelly takes the same hold further (%d squares against %d)" % [reach[1], reach[0]], reach[1] > reach[0])
	s.squeeze(true)
	_run(s, 0.3)
	s.squeeze(false)
	s.serve()
	_run(s, Sim.SETTLE_T + Sim.SHOW_T + 0.1)
	_check("a mould served nearly clear ends the run", s.is_over())
	var had: int = s.score
	Boosters.revive("gumdrop", s)
	_check("the Second chance clears the mould", not s.is_over() and _total(s) == 0.0 and not s.wet() and s.score <= had)
