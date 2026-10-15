extends SceneTree

## Tally's pace, played by a bot, headless:
##   godot --headless --path . --script tests/_pace_tally.gd -- [levels] [copies] [up]
## With `up`, before each level the bot also makes the numbers its upgrades
## ask for (each track in turn, while a rank's numbers all have chains) and
## buys them; the time spent on them counts.
## For each level the bot finds the shortest chain to the target from the
## numbers it may dig and the machines it has (each step the last result
## and a fresh dug number, either order; a divider only where it divides
## evenly, as a remainder left on its back stops it), clears the paper and
## builds `copies` of the chain, each a run into the box, and plays until
## the level is done. It buys any upgrade the box's tally covers. It writes
## its own printed numbers where it builds, so this measures the rules'
## pace, not the walk to a far number on the paper. Prints each level's
## target, chain, minutes and the running total.

const Sim = preload("res://arcade/tally_sim.gd")
const CAP := 3600.0
const DEPTH := 7

var _s
var _ups := 0

func _initialize() -> void:
	Sim.path = ""
	var args := OS.get_cmdline_user_args()
	var levels := int(args[0]) if args.size() > 0 else 30
	var copies := clampi(int(args[1]) if args.size() > 1 else 3, 1, 3)
	var up := args.has("up")
	_s = Sim.new(17)
	var total := 0.0
	var bought := 0
	while _s.level <= levels:
		if up:
			total += _upgrade(copies)
		var t: int = _s.target()
		var chain := _find(t)
		if chain.is_empty():
			print("level %d: %d has no chain of %d steps" % [_s.level, t, DEPTH])
			break
		_clear()
		for k in copies:
			_build(chain, k)
		var spent := 0.0
		var lvl: int = _s.level
		while _s.level == lvl and spent < CAP:
			_s.step(1.0)
			spent += 1.0
			for id: String in Sim.TRACKS:
				if _s.can_buy(id):
					_s.buy(id)
					bought += 1
		_s.events.clear()
		total += spent
		print("level %2d  %9d x%-5d %-34s %6.1f min  total %6.1f min  belt %d add %d mul %d" % [lvl, t, _s.count_of(lvl), _say(chain), spent / 60.0, total / 60.0, int(_s.lv.belt), int(_s.lv.add), int(_s.lv.mul)])
		if spent >= CAP:
			print("  gave up after %d min" % int(CAP / 60.0))
			break
	print("upgrades bought: %d" % (bought + _ups))
	quit()

## Makes what one rank of each open track asks and buys it, while that
## takes under UP_CAP seconds a number. Returns the seconds spent.
const UP_CAP := 600.0

func _upgrade(copies: int) -> float:
	var spent := 0.0
	for id: String in ["belt", "add", "mul", "sub", "pow", "dig"]:
		if not _s.track_open(id) or _s.at_top(id):
			continue
		var ok := true
		for a: Array in _s.asks(id):
			var v := int(a[0])
			var need := int(a[1])
			if _s.held(v) >= need:
				continue
			var chain := _find(v)
			if chain.is_empty():
				ok = false
				break
			_clear()
			for k in copies:
				_build(chain, k)
			var t := 0.0
			while _s.held(v) < need and t < UP_CAP:
				_s.step(1.0)
				t += 1.0
			spent += t
			_s.events.clear()
			if _s.held(v) < need:
				ok = false
				break
		if ok and _s.buy(id):
			_ups += 1
			print("  bought %s %d (%.1f min so far on upgrades this level)" % [id, int(_s.lv[id]), spent / 60.0])
		_s.events.clear()
	return spent

func _ops() -> Array:
	var o := []
	for k: int in Sim.OPS:
		if _s.has(k):
			o.append(k)
	return o

func _digs() -> Array:
	var d := []
	for v in range(1, Sim.MOST + 1):
		if _s.can_dig(v):
			d.append(v)
	return d

## The shortest chain to `t`: [start, [op, dug, last_is_a], ...].
func _find(t: int) -> Array:
	var digs := _digs()
	if digs.has(t):
		return [t]
	var ops := _ops()
	var seen := {}
	var front := []
	for d: int in digs:
		seen[d] = [d]
		front.append(d)
	var top := maxi(t * 4, 64)
	for depth in DEPTH:
		var next := []
		for v: int in front:
			for k: int in ops:
				for d: int in digs:
					for last_a in [true, false]:
						var a: int = v if last_a else d
						var b: int = d if last_a else v
						var r: int
						if k == Sim.DIV:
							if b == 0 or a % b != 0:
								continue
							@warning_ignore("integer_division")
							r = a / b
						else:
							r = Sim.apply(k, a, b)
						if r < 1 or r > top or seen.has(r):
							continue
						var path: Array = (seen[v] as Array).duplicate()
						path.append([k, d, last_a])
						seen[r] = path
						if r == t:
							return path
						next.append(r)
		front = next
	return []

func _say(chain: Array) -> String:
	var s := str(chain[0])
	const SIGN := {Sim.ADD: "+", Sim.MUL: "*", Sim.SUB: "-", Sim.DIV: "/", Sim.POW: "^"}
	for j in range(1, chain.size()):
		var st: Array = chain[j]
		s = "(%s%s%d)" % [s, SIGN[int(st[0])], int(st[1])] if bool(st[2]) else "(%d%s%s)" % [int(st[1]), SIGN[int(st[0])], s]
	return s

func _clear() -> void:
	for i in Sim.N:
		var k: int = _s.kind[i]
		if k != Sim.EMPTY and k != Sim.BOX:
			_s.remove(Sim.tile_of(i))
	_s.dep.fill(0)
	_s.events.clear()

func _dig(t: Vector2i, v: int) -> void:
	_s.dep[Sim._i(t)] = v
	_s.place(Sim.DIG, t, 0)

func _run(a: Vector2i, b: Vector2i, f: int) -> void:
	var tiles := []
	var t := a
	while true:
		tiles.append(t)
		if t == b:
			break
		t += Sim.DIRS[f]
	_s.lay_run(tiles, f)

## One copy: the chain eastward from x 2 on row `base`, then a run into the
## box (copy 0 above it down column 20, copy 1 level with it by column 19,
## copy 2 below it up column 20).
func _build(chain: Array, copy: int) -> void:
	var y: int = [8, 22, 36][copy]
	var x := 2
	var out := Vector2i(x, y)
	if chain.size() == 1:
		_dig(Vector2i(x, y), int(chain[0]))
		out = Vector2i(x, y)
	else:
		for j in range(1, chain.size()):
			var st: Array = chain[j]
			var last_a: bool = st[2]
			# a sum or a product does not mind the order: zigzag, so a long
			# chain stays near its row
			if int(st[0]) == Sim.ADD or int(st[0]) == Sim.MUL:
				last_a = j % 2 == 0
			var m: Vector2i
			if j == 1:
				m = Vector2i(x, y)
				_s.place(int(st[0]), m, 0)
				# the start on the side the chain says, the dug number on the other
				var start_at := m + (Vector2i(0, -2) if last_a else Vector2i(0, 2))
				var dug_at := m + (Vector2i(0, 2) if last_a else Vector2i(0, -2))
				_dig(start_at, int(chain[0]))
				_s.lay_run([m + (Vector2i(0, -1) if last_a else Vector2i(0, 1))], 1 if last_a else 3)
				_dig(dug_at, int(st[1]))
				_s.lay_run([m + (Vector2i(0, 1) if last_a else Vector2i(0, -1))], 3 if last_a else 1)
			else:
				# the last result east, then up into B or down into A
				_s.lay_run([Vector2i(x + 1, y)], 0)
				x += 2
				if last_a:
					_s.lay_run([Vector2i(x, y)], 1)
					y += 1
					m = Vector2i(x, y)
					_s.place(int(st[0]), m, 0)
					_dig(m + Vector2i(0, 2), int(st[1]))
					_s.lay_run([m + Vector2i(0, 1)], 3)
				else:
					_s.lay_run([Vector2i(x, y)], 3)
					y -= 1
					m = Vector2i(x, y)
					_s.place(int(st[0]), m, 0)
					_dig(m + Vector2i(0, -2), int(st[1]))
					_s.lay_run([m + Vector2i(0, -1)], 1)
			out = m
	# to the box
	var row: int = Sim.HUB_AT.y + copy + (1 if copy == 2 else 0)
	var col := 20 if copy != 1 else 19
	_run(Vector2i(out.x + 1, out.y), Vector2i(col - 1, out.y), 0)
	if out.y < row:
		_run(Vector2i(col, out.y), Vector2i(col, row - 1), 1)
	elif out.y > row:
		_run(Vector2i(col, out.y), Vector2i(col, row + 1), 3)
	_run(Vector2i(col, row), Vector2i(20, row), 0)
