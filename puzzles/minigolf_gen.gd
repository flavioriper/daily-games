extends RefCounted

## Mini Golf's holes. A hole is grown here -- a lane walked over the grid,
## widened here and there, its corners cut, its furniture set down -- and
## then proved: `solve` plays it out and finds its par, the fewest putts a
## steady hand needs (a last putt that still drops when it is a little off).
## The phone never grows one: `tools/mine_minigolf.gd` grows and proves them
## on the Mac and writes the survivors to `content/minigolf.json`, a pool a
## band, and a day's course is `holes` of its band's pool.

const Sim = preload("res://puzzles/minigolf_sim.gd")

## Per band: the holes in a course; the lane's length in squares; how often
## a square of the lane is widened and a corner cut; how many of each piece
## of furniture a hole may have; the pars kept (and, with `short`, the most
## of a pool that may be its lowest par).
const BANDS := [
	{"holes": 3, "path": [3, 5], "fat": 0.4, "cut": 0.6, "blocks": [0, 1], "posts": [0, 0],
		"sand": [0, 0], "water": [0, 0], "slopes": [0, 0], "gates": [0, 0], "par": [2, 2]},
	{"holes": 4, "path": [4, 6], "fat": 0.35, "cut": 0.55, "blocks": [0, 1], "posts": [0, 2],
		"sand": [1, 2], "water": [0, 0], "slopes": [0, 0], "gates": [0, 0], "par": [2, 3]},
	{"holes": 5, "path": [5, 8], "fat": 0.3, "cut": 0.5, "blocks": [0, 2], "posts": [0, 2],
		"sand": [0, 2], "water": [1, 2], "slopes": [0, 2], "gates": [0, 0], "par": [2, 4], "short": 0.3},
	{"holes": 5, "path": [6, 9], "fat": 0.3, "cut": 0.5, "blocks": [0, 2], "posts": [0, 2],
		"sand": [0, 1], "water": [0, 2], "slopes": [0, 2], "gates": [1, 2], "par": [3, 4]},
]

## The search: every ANGLES-th of a turn at POWERS strengths from each lie,
## the BEAM best lies kept a putt, no hole past DEPTH putts. A putt that
## comes off more than BANKS kerbs is nobody's plan, so par never counts on
## one: a trick shot is how par is beaten.
const ANGLES := 120
const POWERS := 8
const BEAM := 10
const DEPTH := 6
const BANKS := 1

const BANK := "res://content/minigolf.json"
static var _bank: Array = []

## A straight lane with one block, for a bank that is missing or short a
## band: the board always opens.
const FALLBACK := {"cells": [5, 9, 13, 17, 21], "cuts": [], "tee": [32.0, 100.0], "cup": [32.0, 30.0],
	"blocks": [[32.0, 66.0, 2.8, 2.8, 0.7854]], "par": 2, "proof": [[-1.8326, 0.76]]}

static func bank() -> Array:
	if _bank.is_empty() and FileAccess.file_exists(BANK):
		var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK))
		if doc is Dictionary and doc.get("bands") is Array:
			_bank = doc.bands
	return _bank

static func holes_for(band: int) -> int:
	return int(BANDS[clampi(band, 0, BANDS.size() - 1)].holes)

## The day's course for band `difficulty`: that many holes of the pool, no
## hole twice, the shorter pars first.
static func deal(rng: RandomNumberGenerator, difficulty: int) -> Array:
	var band := clampi(difficulty, 0, BANDS.size() - 1)
	var want := holes_for(band)
	var bands := bank()
	var out: Array = []
	if band < bands.size() and bands[band] is Array and (bands[band] as Array).size() >= want:
		var pool: Array = bands[band]
		var order: Array = range(pool.size())
		for i in want:
			var j := rng.randi_range(i, order.size() - 1)
			var t = order[i]
			order[i] = order[j]
			order[j] = t
			out.append(pool[order[i]])
		out.sort_custom(func(a, b): return int(a.get("par", 0)) < int(b.get("par", 0)))
		return out
	for i in want:
		out.append(FALLBACK)
	return out

# --- growing a hole ---

static func _pick(rng: RandomNumberGenerator, span: Array) -> int:
	return rng.randi_range(int(span[0]), int(span[1]))

static func _near4(i: int) -> Array:
	var out: Array = []
	var c := i % Sim.COLS
	var r := i / Sim.COLS
	if c > 0:
		out.append(i - 1)
	if c < Sim.COLS - 1:
		out.append(i + 1)
	if r > 0:
		out.append(i - Sim.COLS)
	if r < Sim.ROWS - 1:
		out.append(i + Sim.COLS)
	return out

## A lane of `want` squares that never runs beside itself, so every stretch
## has its own kerbs. [] when the walk boxed itself in.
static func _lane(rng: RandomNumberGenerator, want: int) -> Array:
	var at := rng.randi_range(0, Sim.COLS - 1) + rng.randi_range(Sim.ROWS - 3, Sim.ROWS - 1) * Sim.COLS
	var lane: Array = [at]
	var heading := -Sim.COLS
	while lane.size() < want:
		var ways: Array = []
		for n: int in _near4(at):
			if lane.has(n):
				continue
			var clear := true
			for m: int in _near4(n):
				if m != at and lane.has(m):
					clear = false
			if clear:
				ways.append(n)
				# straight on is likelier, and so is up the card
				if n - at == heading:
					ways.append(n)
				if n - at == -Sim.COLS:
					ways.append(n)
		if ways.is_empty():
			return []
		var to: int = ways[rng.randi_range(0, ways.size() - 1)]
		heading = to - at
		at = to
		lane.append(at)
	return lane

## One hole of `band`, unproved: {} when the walk failed.
static func grow(rng: RandomNumberGenerator, band: int) -> Dictionary:
	var b: Dictionary = BANDS[band]
	var lane := _lane(rng, _pick(rng, b.path))
	if lane.is_empty():
		return {}
	var cells: Array = lane.duplicate()
	# widen: a square beside the lane that touches only its own stretch of it
	for k in range(1, lane.size() - 1):
		if rng.randf() >= float(b.fat):
			continue
		var sides: Array = []
		for n: int in _near4(lane[k]):
			if cells.has(n):
				continue
			var ok := true
			for m: int in _near4(n):
				if cells.has(m) and not (lane.has(m) and absi(lane.find(m) - k) <= 1):
					ok = false
			if ok:
				sides.append(n)
		if not sides.is_empty():
			cells.append(sides[rng.randi_range(0, sides.size() - 1)])
	var first: int = lane[0]
	var last: int = lane[lane.size() - 1]
	var tee := Sim.cell_mid(first) - (Sim.cell_mid(lane[1]) - Sim.cell_mid(first)).normalized() * 3.0
	var cup := Sim.cell_mid(last) + (Sim.cell_mid(last) - Sim.cell_mid(lane[lane.size() - 2])).normalized() * rng.randf_range(0.0, 3.5) \
		+ Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
	var hole := {"cells": cells, "tee": [snappedf(tee.x, 0.1), snappedf(tee.y, 0.1)],
		"cup": [snappedf(cup.x, 0.1), snappedf(cup.y, 0.1)]}
	# cut corners: where the green turns outward, never by the tee or the cup
	var cuts: Array = []
	for i: int in cells:
		if i == first or i == last:
			continue
		var c := i % Sim.COLS
		var r := i / Sim.COLS
		var has := func(dc: int, dr: int) -> bool:
			var cc := c + dc
			var rr := r + dr
			return cc >= 0 and rr >= 0 and cc < Sim.COLS and rr < Sim.ROWS and cells.has(cc + rr * Sim.COLS)
		var out := [not has.call(-1, 0) and not has.call(0, -1), not has.call(1, 0) and not has.call(0, -1),
			not has.call(1, 0) and not has.call(0, 1), not has.call(-1, 0) and not has.call(0, 1)]
		# a square cut on two corners of one side would be a funnel, not a lane
		var took := 0
		for k in 4:
			if out[k] and took < 2 and rng.randf() < float(b.cut):
				cuts.append(i * 4 + k)
				took += 1
	hole["cuts"] = cuts
	# the furniture, a piece a square, off the tee's and the cup's
	var free: Array = []
	for i: int in cells:
		if i != first and i != last:
			free.append(i)
	for i in range(free.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = free[i]
		free[i] = free[j]
		free[j] = t
	var blocks: Array = []
	var posts: Array = []
	var sand: Array = []
	var water: Array = []
	var slopes: Array = []
	var gates: Array = []
	# gates first: they stand on the line between two squares of the lane
	var want_gates := _pick(rng, b.gates)
	var doors: Array = range(1, lane.size() - 1)
	for i in range(doors.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = doors[i]
		doors[i] = doors[j]
		doors[j] = t
	for k: int in doors:
		if gates.size() >= want_gates:
			break
		var a := Sim.cell_mid(lane[k])
		var z := Sim.cell_mid(lane[k + 1])
		var mid := (a + z) * 0.5
		var along := (z - a).normalized()
		var across := Vector2(-along.y, along.x) * (Sim.CELL * 0.5)
		var near := false
		for g: Array in gates:
			if Vector2(float(g[0]) + float(g[2]), float(g[1]) + float(g[3])).distance_to(mid * 2.0) < Sim.CELL * 3.0:
				near = true
		if near or mid.distance_to(tee) < 14.0 or mid.distance_to(cup) < 14.0:
			continue
		gates.append([mid.x - across.x, mid.y - across.y, mid.x + across.x, mid.y + across.y, rng.randi_range(0, 1)])
	var plan: Array = []
	for kind: String in ["water", "sand", "slopes", "posts", "blocks"]:
		for n in _pick(rng, b[kind]):
			plan.append(kind)
	for kind: String in plan:
		if free.is_empty():
			break
		var i: int = free.pop_back()
		var mid := Sim.cell_mid(i)
		var k := lane.find(i)
		var along := Vector2(0.0, -1.0)
		if k >= 0 and k < lane.size() - 1:
			along = (Sim.cell_mid(lane[k + 1]) - mid).normalized()
		var across := Vector2(-along.y, along.x)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		match kind:
			"water":
				var at := mid + across * side * rng.randf_range(2.5, 4.0)
				var r_along := rng.randf_range(4.5, 6.5)
				var r_across := rng.randf_range(3.8, 4.8)
				water.append([_r(at.x), _r(at.y), _r(absf(along.x) * r_along + absf(across.x) * r_across),
					_r(absf(along.y) * r_along + absf(across.y) * r_across)])
			"sand":
				var at := mid + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
				sand.append([_r(at.x), _r(at.y), _r(rng.randf_range(4.8, 6.4)), _r(rng.randf_range(4.2, 5.8))])
			"slopes":
				# along the lane, against it or across it
				var way: Vector2 = [along, -along, across * side][rng.randi_range(0, 2)]
				var dir := 0
				for d in 4:
					if (Sim.DIRS[d] as Vector2).dot(way) > 0.9:
						dir = d
				slopes.append([i, dir])
			"posts":
				var at := mid + Vector2(rng.randf_range(-3.2, 3.2), rng.randf_range(-3.2, 3.2))
				posts.append([_r(at.x), _r(at.y), 2.4])
			"blocks":
				var cut_here := false
				for id: int in cuts:
					if id / 4 == i:
						cut_here = true
				if cut_here or rng.randf() < 0.5:
					# a diamond in the middle of the lane (always, in a square
					# with a cut corner: a baffle would stand in the wedge)
					blocks.append([_r(mid.x), _r(mid.y), 2.8, 2.8, 0.7854])
				else:
					# a baffle out from one kerb, a gap left at the other
					var at := mid + across * side * 4.4
					var turn := 0.0 if absf(across.x) > 0.5 else 1.5708
					blocks.append([_r(at.x), _r(at.y), 4.6, 1.3, turn])
	for row: Array in [["blocks", blocks], ["posts", posts], ["sand", sand], ["water", water], ["slopes", slopes], ["gates", gates]]:
		if not (row[1] as Array).is_empty():
			hole[row[0]] = row[1]
	return hole

static func _r(x: float) -> float:
	return snappedf(x, 0.1)

# --- proving one ---

## Plays `hole` out: {"best", "proof": [[angle, power], ...], "sims"} for
## the fewest putts whose last still drops a little off, {} when DEPTH putts do
## not get there (or the tee has no way to the cup).
static func solve(hole: Dictionary, angles := ANGLES, powers := POWERS, beam := BEAM) -> Dictionary:
	var sim := Sim.new()
	sim.setup(hole)
	if sim.way(sim.tee) >= Sim.FAR or not sim.open_at(sim.tee) or not sim.open_at(sim.cup, 0.5):
		return {}
	var sims := 0
	var nodes: Array = [{"sim": sim, "path": []}]
	for depth in range(1, DEPTH + 1):
		var next: Array = []
		var drops: Array = []
		for node: Dictionary in nodes:
			var from = node.sim
			# the tee's fan is twice as fine: a long straight putt is a narrow one
			var fan := angles * 2 if depth == 1 else angles
			for ai in fan:
				var a := TAU * float(ai) / float(fan)
				for ui in powers:
					var u := 0.16 + 0.84 * float(ui) / float(powers - 1)
					var c = from.clone()
					c.putt(a, u)
					c.run()
					sims += 1
					if c.hits > BANKS:
						continue
					if c.sunk:
						drops.append([from, node.path, a, u])
					elif not c.wet:
						next.append({"sim": c, "path": node.path + [[a, u]], "way": c.way(c.p)})
		for d: Array in drops:
			sims += 4
			if d[0].steady(d[2], d[3]) >= 3:
				var proof: Array = (d[1] as Array).duplicate()
				proof.append([d[2], d[3]])
				for row: Array in proof:
					row[0] = snappedf(wrapf(row[0], -PI, PI), 0.0001)
					row[1] = snappedf(row[1], 0.001)
				return {"best": depth, "proof": proof, "sims": sims}
		next.sort_custom(func(x, y): return x.way < y.way)
		nodes = []
		var seen := {}
		for n: Dictionary in next:
			var key := Vector3i(int(n.sim.p.x / 5.0), int(n.sim.p.y / 5.0), n.sim.parity)
			if seen.has(key):
				continue
			seen[key] = true
			nodes.append(n)
			if nodes.size() >= beam:
				break
		if nodes.is_empty():
			return {}
	return {}

## What a decent hand takes on `hole`: the mean putts over `runs` rounds of
## the steady putt (Sim.best_shot) struck a little off each time. Par is
## this, rounded: the score to expect, where the proof is the score to dream
## of.
static func rate(hole: Dictionary, rng: RandomNumberGenerator, runs := 12) -> float:
	var base := Sim.new()
	base.setup(hole)
	var total := 0
	for k in runs:
		var sim = base.clone()
		var n := 0
		while not sim.sunk and n < 9:
			var shot: Dictionary = sim.best_shot(48, 5, BANKS)
			sim.putt(float(shot.a) + rng.randfn(0.0, 0.03), clampf(float(shot.u) * (1.0 + rng.randfn(0.0, 0.07)), 0.03, 1.0))
			sim.run()
			n += 1
		total += n
	return float(total) / float(runs)

## Whether `hole`'s own proof still gets the ball down in its par.
static func proves(hole: Dictionary) -> bool:
	var sim := Sim.new()
	sim.setup(hole)
	for row in hole.get("proof", []):
		if not sim.putt(float(row[0]), float(row[1])):
			return false
		sim.run()
	return sim.sunk
