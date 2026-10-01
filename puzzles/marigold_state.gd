extends RefCounted

## Marigold's rules and its physics, scene-free: a field of flower buds, a
## sun at the top that shoots a seed, and a flowerpot sliding along the foot.
## puzzles/marigold2d.gd draws this and nothing else decides anything.
##
## The field is W by H units, y down; the board scales it to the card. A seed
## falls under GRAVITY and bounces off buds, the side walls and the ceiling.
## A bud it touches **blooms** (lit) and stays on the field until the shot is
## over, when every bloom is picked (gone). Marigolds (ORANGE) are the goal:
## bloom every one of them. Bluebells (BLUE) are the plain buds, clovers
## (GREEN) split the seed in two, and one violet (PURPLE) is worth a lot and
## moves to another bluebell after every shot. A seed that drops into the pot
## comes back. Running out of seeds with a marigold left is not a loss of the
## day: the board grows the same garden back and the player tries again.
##
## Everything a shot does runs through step(), fixed at DT, so the hint can
## play a shot on a copy (clone()) and see where it goes.
##
## Spec: docs/superpowers/specs/2026-09-26-marigold-flat-design.md.

const W := 100.0
const H := 140.0
const PEG_R := 1.75
const BALL_R := 1.3
const GRAVITY := 92.0
const SPEED := 72.0
const MAX_SPEED := 150.0
## A bud gives back BOUNCE of the speed along the hit; the walls WALL.
const BOUNCE := 0.68
const WALL := 0.8
const DT := 1.0 / 240.0
## The sun's middle; a seed leaves MUZZLE out from it along the aim.
const SUN_C := Vector2(50.0, 5.5)
const MUZZLE := 4.9
const LAUNCH := SUN_C
## The aim is kept AIM_MIN off level either side.
const AIM_MIN := 0.1
## The buds stand between TOP and BOTTOM.
const TOP := 25.0
const BOTTOM := 124.0
## The pot's rim, how fast it slides and how thick its lip is.
const POT_Y := 134.0
const POT_SPEED := 19.0
const POT_RIM := 1.2
## The full bloom's five pots at the foot, left to right.
const FEVER_POTS := [10000, 50000, 100000, 50000, 10000]
## A seed that has not gone lower for STUCK_TIME clears the blooms round it;
## a shot past SHOT_CAP clears every bloom.
const STUCK_TIME := 2.2
const SHOT_CAP := 30.0
const MIN_GAP := 6.0

enum { BLUE, ORANGE, GREEN, PURPLE }
enum { UP, LIT, GONE }
const VALUE := [10, 100, 10, 500]
## The multiplier steps up as the share of marigolds bloomed passes each of
## STEPS -- the reference's x2 at 10 of 25, x3 at 15, x5 at 19, x10 at 22.
const STEPS := [0.0, 0.4, 0.6, 0.76, 0.88]
const MULTS := [1, 2, 3, 5, 10]
## A shot worth each of these gives a seed back.
const FREE_AT := [25000, 75000, 125000]
## Every seed left when the last marigold goes is worth LEFT_BONUS.
const LEFT_BONUS := 10000

## Hints and hearts by band: Hard and Insane can be lost.
const HINTS_BY := [3, 3, 2, 0]
const HEARTS_BY := [0, 0, 3, 2]

const BANDS := [
	{"pegs": 54, "orange": 12, "seeds": 10, "pot": 17.0, "green": 2},
	{"pegs": 72, "orange": 18, "seeds": 10, "pot": 15.0, "green": 2},
	{"pegs": 90, "orange": 25, "seeds": 10, "pot": 13.0, "green": 2},
	{"pegs": 100, "orange": 25, "seeds": 8, "pot": 11.0, "green": 1},
]

var band := 0
var pos := PackedVector2Array()
var kind := PackedInt32Array()
var st := PackedInt32Array()
## The opening kinds, so a new try grows the same garden.
var kind0 := PackedInt32Array()
var grid := {}
var orange_total := 0
var oranges_left := 0
var seeds := 0
var score := 0
var shots := 0
var tries := 1
var pot_x := 50.0
var pot_dir := 1.0
var pot_w := 15.0
## Full bloom: the last marigold is out and the foot is five pots.
var fever := false
var fever_bonus := 0
var left_bonus := 0

## The seeds in flight: {"p", "v"}.
var balls: Array = []
var shot_points := 0
var shot_hits := 0
var shot_time := 0.0
var shot_max_y := 0.0
var quiet := 0.0
var caught := 0
var _rng := RandomNumberGenerator.new()
var _purple_seed := 0
## Sweethearts (Insane): each marigold's sweetheart, -1 for any other bud;
## the bank's own shots that bloom every pair from the opening.
var sweethearts := false
var pair := PackedInt32Array()
var proof: Array = []
## The buds bloomed this shot, in order (an unstuck one is gone already).
var shot_bloomed := PackedInt32Array()

static func hints_for(b: int) -> int:
	return HINTS_BY[clampi(b, 0, HINTS_BY.size() - 1)]

static func hearts_for(b: int) -> int:
	return HEARTS_BY[clampi(b, 0, HEARTS_BY.size() - 1)]

# --- the garden ---

func build(rng: RandomNumberGenerator, difficulty: int, bank_step := -1) -> void:
	band = clampi(difficulty, 0, BANDS.size() - 1)
	sweethearts = false
	proof = []
	if band == 3 and bank_step >= 0:
		var d: Dictionary = InsaneBank.pick("marigold", bank_step)
		if not d.is_empty() and from_bank(d):
			return
	var b: Dictionary = BANDS[band]
	var pts := _garden(rng, int(b.pegs))
	pos = pts
	kind = PackedInt32Array()
	kind.resize(pts.size())
	kind.fill(BLUE)
	var order: Array = range(pts.size())
	_shuffle(order, rng)
	var k := 0
	for i in mini(int(b.orange), order.size()):
		kind[order[k]] = ORANGE
		k += 1
	for i in int(b.green):
		if k < order.size():
			kind[order[k]] = GREEN
			k += 1
	kind0 = kind.duplicate()
	pair = PackedInt32Array()
	pair.resize(pts.size())
	pair.fill(-1)
	pot_w = float(b.pot)
	_purple_seed = rng.randi()
	tries = 1
	_grid()
	_begin()

## A mined Sweethearts garden: {"pos": [x, y, ...], "kind": [...], "pair":
## [...], "proof": [angles], "violet": seed}. Never mirrored: a shot's
## path is chaotic, and the mirror's float rounding loses the proof. False
## when the entry does not read.
func from_bank(d: Dictionary) -> bool:
	var flat: Array = d.get("pos", [])
	var kinds: Array = d.get("kind", [])
	var pairs: Array = d.get("pair", [])
	if flat.size() < 2 or flat.size() != kinds.size() * 2 or pairs.size() != kinds.size():
		return false
	pos = PackedVector2Array()
	kind0 = PackedInt32Array()
	pair = PackedInt32Array()
	for k in kinds.size():
		var x := float(flat[2 * k])
		pos.append(Vector2(x, float(flat[2 * k + 1])))
		kind0.append(int(kinds[k]))
		pair.append(int(pairs[k]))
	proof = []
	for a in d.get("proof", []):
		proof.append(float(a))
	band = 3
	sweethearts = true
	pot_w = float(BANDS[3].pot)
	_purple_seed = int(d.get("violet", 1))
	tries = 1
	_grid()
	_begin()
	return true

## A new try: the same buds, every one back up, the seeds and score anew.
func regrow() -> void:
	tries += 1
	_begin()

## Try again after the hearts ran out: the garden as dealt, the tries anew.
func restart() -> void:
	tries = 1
	_begin()

func _begin() -> void:
	kind = kind0.duplicate()
	st = PackedInt32Array()
	st.resize(pos.size())
	st.fill(UP)
	orange_total = 0
	for k in kind:
		if k == ORANGE:
			orange_total += 1
	oranges_left = orange_total
	seeds = int(BANDS[band].seeds)
	score = 0
	shots = 0
	fever = false
	fever_bonus = 0
	left_bonus = 0
	balls = []
	pot_x = W * 0.5
	pot_dir = 1.0
	_rng.seed = _purple_seed + tries * 7919
	_move_purple()

func _grid() -> void:
	grid = {}
	for i in pos.size():
		var key := _cell_key(pos[i])
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		var a: PackedInt32Array = grid[key]
		a.append(i)
		grid[key] = a

static func _cell_key(p: Vector2) -> int:
	return int(floorf(p.x / 6.0)) + int(floorf(p.y / 6.0)) * 64

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## The day's buds: the field split into two or three bands down its height,
## each filled with one figure (staggered rows, smiles, rings, waves,
## chevrons, pillars, a lattice), mirrored about the middle so the garden is
## symmetric like the reference's levels, then thinned in mirrored pairs to
## the band's count.
func _garden(rng: RandomNumberGenerator, want: int) -> PackedVector2Array:
	var best := PackedVector2Array()
	for attempt in 12:
		var zones := rng.randi_range(2, 3)
		var cuts: Array = [TOP]
		for z in range(1, zones):
			cuts.append(lerpf(TOP, BOTTOM, float(z) / float(zones)) + rng.randf_range(-5.0, 5.0))
		cuts.append(BOTTOM)
		var raw: Array = []
		var last := -1
		for z in zones:
			var fig := rng.randi_range(0, 6)
			if fig == last:
				fig = (fig + 1) % 7
			last = fig
			raw.append_array(_figure(fig, float(cuts[z]), float(cuts[z + 1]), rng))
		var pts := _mirror_spaced(raw)
		pts = _thin(pts, want, rng)
		if absi(pts.size() - want) < absi(best.size() - want) or best.is_empty():
			best = pts
		if pts.size() >= int(want * 0.9):
			break
	return best

## One figure's points in the left half and on the middle line, inside the
## band from y0 to y1.
func _figure(fig: int, y0: float, y1: float, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var h := y1 - y0
	match fig:
		0:  # staggered rows, the reference's own field
			var dx := rng.randf_range(7.5, 9.0)
			var dy := rng.randf_range(7.0, 8.5)
			var r := 0
			var y := y0 + 2.5
			while y < y1 - 2.0:
				var x := W * 0.5 - (dx * 0.5 if r % 2 == 1 else 0.0)
				while x > 5.0:
					out.append(Vector2(x, y))
					x -= dx
				y += dy
				r += 1
		1:  # smiles: concentric arcs about a point above the band
			var cy := y0 - rng.randf_range(10.0, 30.0)
			var rr := y0 - cy + 3.0
			while cy + rr < y1 - 1.0:
				var n := int(PI * 0.5 * rr * 1.12 / 6.3)
				for i in n + 1:
					var a := PI * 0.5 + PI * 0.5 * float(i) / float(maxi(n, 1)) * 1.0
					var p := Vector2(W * 0.5 + cos(a) * rr * 1.25, cy + sin(a) * rr)
					if p.y >= y0 + 1.0 and p.x > 4.5:
						out.append(p)
				rr += rng.randf_range(7.0, 9.0)
		2:  # rings, a pair mirrored and one on the middle
			var rr := clampf(h * 0.3, 6.5, 11.0)
			var cy := (y0 + y1) * 0.5
			for c: Vector2 in [Vector2(W * 0.5 - rng.randf_range(22.0, 28.0), cy), Vector2(W * 0.5, cy)]:
				var n := int(TAU * rr / 6.3)
				for i in n:
					var a := TAU * float(i) / float(n) + (PI * 0.5 if c.x == W * 0.5 else 0.0)
					var p := c + Vector2(cos(a), sin(a)) * rr
					if p.x <= W * 0.5 + 0.01:
						out.append(p)
		3:  # waves: rows bent on a sine
			var amp := rng.randf_range(3.0, 6.0)
			var k := rng.randf_range(0.08, 0.14)
			var dy := rng.randf_range(9.0, 11.0)
			var y := y0 + amp + 1.0
			while y < y1 - amp:
				var x := W * 0.5
				while x > 5.0:
					out.append(Vector2(x, y + amp * cos((x - W * 0.5) * k)))
					x -= 6.4
				y += dy
		4:  # chevrons pointing down
			var slope := rng.randf_range(0.35, 0.6)
			var y := y0 + 2.0
			while y < y1 - 2.0:
				var x := W * 0.5
				while x > 5.0:
					var p := Vector2(x, y + (W * 0.5 - x) * -slope + 20.0 * slope)
					if p.y >= y0 + 1.0 and p.y <= y1 - 1.0:
						out.append(p)
					x -= 6.2
				y += rng.randf_range(8.0, 10.0)
		5:  # pillars
			var cols := [W * 0.5, W * 0.5 - 16.0, W * 0.5 - 32.0, W * 0.5 - 44.0]
			var dy := rng.randf_range(6.3, 7.5)
			for c: float in cols:
				var y := y0 + 2.0 + (dy * 0.5 if int(c) % 2 == 0 else 0.0)
				while y < y1 - 2.0:
					out.append(Vector2(c, y))
					y += dy
		6:  # a diamond lattice
			var d := rng.randf_range(7.0, 8.5)
			var cy := (y0 + y1) * 0.5
			var half := h * 0.5 - 1.5
			var y := cy - half
			var r := 0
			while y <= cy + half:
				var reach := (half - absf(y - cy)) * 1.6 + 8.0
				var x := W * 0.5 - (d * 0.5 if r % 2 == 1 else 0.0)
				while x > W * 0.5 - reach and x > 5.0:
					out.append(Vector2(x, y))
					x -= d
				y += d * 0.8
				r += 1
	return out

## Mirrors the left half across the middle and drops any bud nearer than
## MIN_GAP to one already kept.
func _mirror_spaced(raw: Array) -> PackedVector2Array:
	var kept := PackedVector2Array()
	for p: Vector2 in raw:
		if p.x > W * 0.5 + 0.01 or p.x < 4.0 or p.y < TOP - 1.0 or p.y > BOTTOM + 1.0:
			continue
		var mid := absf(p.x - W * 0.5) < 1.2
		if mid:
			p.x = W * 0.5
		if not _clear(kept, p):
			continue
		if not mid and absf(p.x - W * 0.5) * 2.0 < MIN_GAP:
			continue
		kept.append(p)
		if not mid:
			kept.append(Vector2(W - p.x, p.y))
	return kept

static func _clear(kept: PackedVector2Array, p: Vector2) -> bool:
	for q in kept:
		if q.distance_squared_to(p) < MIN_GAP * MIN_GAP:
			return false
	return true

## Takes buds away, a mirrored pair at a time, until at most `want` are left.
func _thin(pts: PackedVector2Array, want: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := pts
	var guard := 0
	while out.size() > want and guard < 400:
		guard += 1
		var i := rng.randi_range(0, out.size() - 1)
		var p := out[i]
		var twin := -1
		for j in out.size():
			if j != i and absf(out[j].x - (W - p.x)) < 0.01 and absf(out[j].y - p.y) < 0.01:
				twin = j
				break
		if twin >= 0 and out.size() - 2 >= want - 1:
			var a := maxi(i, twin)
			var b := mini(i, twin)
			out.remove_at(a)
			out.remove_at(b)
		elif twin < 0:
			out.remove_at(i)
	return out

# --- a shot ---

func idle() -> bool:
	return balls.is_empty()

func mult() -> int:
	if orange_total <= 0:
		return 1
	var f := float(orange_total - oranges_left) / float(orange_total)
	var m := 1
	for k in STEPS.size():
		if f >= float(STEPS[k]) - 1e-6:
			m = MULTS[k]
	return m

static func aim_dir(angle: float) -> Vector2:
	var a := clampf(angle, AIM_MIN, PI - AIM_MIN)
	return Vector2(cos(a), sin(a))

## Shoots a seed from the sun at `angle` (radians, y down: PI/2 is straight
## down). False when a seed is already out or none is left.
func fire(angle: float) -> bool:
	if not balls.is_empty() or seeds <= 0 or is_solved():
		return false
	seeds -= 1
	balls = [{"p": SUN_C + aim_dir(angle) * MUZZLE, "v": aim_dir(angle) * SPEED}]
	shot_points = 0
	shot_hits = 0
	shot_bloomed = PackedInt32Array()
	shot_time = 0.0
	shot_max_y = LAUNCH.y
	quiet = 0.0
	caught = 0
	return true

## The pot slides back and forth along the foot, the whole time.
func step_pot(dt: float) -> void:
	if fever:
		return
	var lo := pot_w * 0.5 + 1.0
	var hi := W - pot_w * 0.5 - 1.0
	pot_x += pot_dir * POT_SPEED * dt
	if pot_x > hi:
		pot_x = hi - (pot_x - hi)
		pot_dir = -1.0
	elif pot_x < lo:
		pot_x = lo + (lo - pot_x)
		pot_dir = 1.0

## One DT of the shot. Returns what happened, for the board to show:
## {"t": "hit", "i", "at"}, {"t": "wall", "at"}, {"t": "split", "at"},
## {"t": "pot", "at"}, {"t": "fever", "i"}, {"t": "fever_pot", "k", "at"},
## {"t": "drain", "at"}, {"t": "unstick", "list"}.
func step(events: Array = []) -> Array:
	if balls.is_empty():
		return events
	shot_time += DT
	step_pot(DT)
	var spawned: Array = []
	var keep: Array = []
	for ball: Dictionary in balls:
		var gone := _step_ball(ball, events, spawned)
		if not gone:
			keep.append(ball)
			if ball.p.y > shot_max_y + 0.5:
				shot_max_y = ball.p.y
				quiet = 0.0
	keep.append_array(spawned)
	balls = keep
	quiet += DT
	if not balls.is_empty() and (quiet > STUCK_TIME or shot_time > SHOT_CAP):
		_unstick(events, shot_time > SHOT_CAP)
	return events

func _step_ball(ball: Dictionary, events: Array, spawned: Array) -> bool:
	var p: Vector2 = ball.p
	var v: Vector2 = ball.v
	v.y += GRAVITY * DT
	p += v * DT
	# the walls and the ceiling
	if p.x < BALL_R:
		p.x = BALL_R
		v.x = absf(v.x) * WALL
		events.append({"t": "wall", "at": p, "speed": absf(v.x)})
	elif p.x > W - BALL_R:
		p.x = W - BALL_R
		v.x = -absf(v.x) * WALL
		events.append({"t": "wall", "at": p, "speed": absf(v.x)})
	if p.y < BALL_R:
		p.y = BALL_R
		v.y = absf(v.y) * WALL
	# the buds round it
	var reach := PEG_R + BALL_R
	var cx := int(floorf(p.x / 6.0))
	var cy := int(floorf(p.y / 6.0))
	for gy in range(cy - 1, cy + 2):
		for gx in range(cx - 1, cx + 2):
			var key := gx + gy * 64
			if not grid.has(key):
				continue
			for i: int in grid[key]:
				if st[i] == GONE:
					continue
				var d := p - pos[i]
				var dd := d.length_squared()
				if dd >= reach * reach:
					continue
				var len := sqrt(dd)
				var n := d / len if len > 1e-5 else Vector2.UP
				p = pos[i] + n * reach
				var vn := v.dot(n)
				if vn < 0.0:
					v -= (1.0 + BOUNCE) * vn * n
				# a seed balanced on a bud's crown rolls off, one way or the other
				if absf(n.x) < 0.05 and n.y < 0.0 and absf(v.x) < 3.0:
					v.x += 4.0 if i % 2 == 0 else -4.0
				if st[i] == UP:
					_hit(i, p, v, events, spawned)
	# the pot, or the full bloom's pots
	if fever:
		for k in range(1, FEVER_POTS.size()):
			var rim := Vector2(W * float(k) / float(FEVER_POTS.size()), POT_Y)
			_bounce_off(rim, POT_RIM + 0.6, p, v)
			p = _last_p
			v = _last_v
		if p.y > POT_Y + 2.5:
			var k := clampi(int(p.x / (W / float(FEVER_POTS.size()))), 0, FEVER_POTS.size() - 1)
			fever_bonus = int(FEVER_POTS[k])
			events.append({"t": "fever_pot", "k": k, "at": p})
			return true
	else:
		var half := pot_w * 0.5
		for side in [-1.0, 1.0]:
			_bounce_off(Vector2(pot_x + half * side, POT_Y), POT_RIM, p, v)
			p = _last_p
			v = _last_v
		if p.y > POT_Y and ball.p.y <= POT_Y and absf(p.x - pot_x) < half - POT_RIM * 0.5:
			seeds += 1
			caught += 1
			events.append({"t": "pot", "at": Vector2(pot_x, POT_Y)})
			return true
		# the pot's sides, below the rim
		if p.y > POT_Y and absf(p.x - pot_x) < half + BALL_R:
			if ball.p.x < pot_x:
				p.x = pot_x - half - BALL_R
				v.x = -absf(v.x) * WALL
			else:
				p.x = pot_x + half + BALL_R
				v.x = absf(v.x) * WALL
	if p.y > H + BALL_R * 2.0:
		events.append({"t": "drain", "at": p})
		return true
	if v.length() > MAX_SPEED:
		v = v.normalized() * MAX_SPEED
	ball.p = p
	ball.v = v
	return false

var _last_p := Vector2.ZERO
var _last_v := Vector2.ZERO

## A bounce off a round lip at `c` of radius `r`; the result in _last_p/_last_v.
func _bounce_off(c: Vector2, r: float, p: Vector2, v: Vector2) -> void:
	var d := p - c
	var reach := r + BALL_R
	if d.length_squared() < reach * reach:
		var n := d.normalized() if d.length() > 1e-5 else Vector2.UP
		p = c + n * reach
		var vn := v.dot(n)
		if vn < 0.0:
			v -= (1.0 + WALL) * vn * n
	_last_p = p
	_last_v = v

func _hit(i: int, p: Vector2, v: Vector2, events: Array, spawned: Array) -> void:
	st[i] = LIT
	shot_hits += 1
	shot_bloomed.append(i)
	if kind[i] == ORANGE:
		oranges_left -= 1
	shot_points += int(VALUE[kind[i]]) * mult()
	events.append({"t": "hit", "i": i, "at": pos[i], "n": shot_hits})
	if kind[i] == GREEN:
		var sv := Vector2(-v.x, v.y)
		if absf(sv.x) < 12.0:
			sv.x = 18.0 if i % 2 == 0 else -18.0
		spawned.append({"p": p, "v": sv})
		events.append({"t": "split", "at": p})
	if kind[i] == ORANGE and oranges_left == 0 and not fever:
		fever = true
		events.append({"t": "fever", "i": i, "at": pos[i]})

## A seed that has stopped going down clears the blooms round it (all of
## them once the shot has run past SHOT_CAP), so it can fall.
func _unstick(events: Array, all: bool) -> void:
	var list := PackedInt32Array()
	for i in pos.size():
		if st[i] != LIT:
			continue
		var near := all
		for ball: Dictionary in balls:
			if Vector2(ball.p).distance_to(pos[i]) < 8.0:
				near = true
		if near:
			st[i] = GONE
			list.append(i)
	quiet = STUCK_TIME - 0.8
	if not list.is_empty():
		events.append({"t": "unstick", "list": list})

## After the last seed of a shot is gone: every bloom picked, the shot's
## points banked, seeds back for a big shot, the violet moved. Returns
## {"cleared" (bud indices, in the order they bloomed), "points", "free"}.
func end_shot(order: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	# Sweethearts: a marigold whose sweetheart did not bloom this shot folds
	# back into a bud (its points stay; the share and the multiplier go back)
	var folded := PackedInt32Array()
	if sweethearts:
		for i in shot_bloomed:
			if kind[i] == ORANGE and pair[i] >= 0 and st[pair[i]] == UP:
				folded.append(i)
		for i in folded:
			st[i] = UP
			oranges_left += 1
	var cleared := PackedInt32Array()
	for i in order:
		if st[i] == LIT:
			cleared.append(i)
	for i in pos.size():
		if st[i] == LIT and not cleared.has(i):
			cleared.append(i)
	for i in cleared:
		st[i] = GONE
	var free := 0
	for f: int in FREE_AT:
		if shot_points >= f:
			free += 1
	seeds += free
	score += shot_points + fever_bonus
	shots += 1
	if fever:
		left_bonus = seeds * LEFT_BONUS
		score += left_bonus
	else:
		_move_purple()
	return {"cleared": cleared, "points": shot_points, "free": free, "folded": folded}

func _move_purple() -> void:
	var blues: Array = []
	for i in pos.size():
		if kind[i] == PURPLE:
			kind[i] = BLUE
		if kind[i] == BLUE and st[i] == UP:
			blues.append(i)
	if not blues.is_empty():
		kind[blues[_rng.randi_range(0, blues.size() - 1)]] = PURPLE

func is_solved() -> bool:
	return orange_total > 0 and oranges_left <= 0 and balls.is_empty()

## Out of seeds, the last shot over, and a marigold still up.
func is_out() -> bool:
	return balls.is_empty() and seeds <= 0 and oranges_left > 0

# --- the hint ---

func clone():
	var c = get_script().new()
	c.band = band
	c.pos = pos
	c.kind = kind
	c.st = st.duplicate()
	c.grid = grid
	c.orange_total = orange_total
	c.oranges_left = oranges_left
	c.seeds = seeds
	c.pot_x = pot_x
	c.pot_dir = pot_dir
	c.pot_w = pot_w
	c.fever = fever
	c.sweethearts = sweethearts
	c.pair = pair
	return c

## Every bud a seed shot at `angle` from here blooms, in order, played out on
## a copy to the end of the shot (the miner's and the probe's).
func shot_order(angle: float) -> PackedInt32Array:
	var c = clone()
	c.seeds = maxi(c.seeds, 1)
	c.fire(angle)
	var out := PackedInt32Array()
	var steps := int(SHOT_CAP / DT) + 10
	for s in steps:
		for e: Dictionary in c.step([]):
			if String(e.t) == "hit":
				out.append(int(e.i))
		if c.balls.is_empty():
			break
	return out

## Where a seed shot at `angle` goes: the path (every `every` steps) up to
## `hits` new blooms or `seconds`, and what it bloomed.
func trace(angle: float, hits: int, seconds: float, every := 6) -> Dictionary:
	var c = clone()
	c.seeds = maxi(c.seeds, 1)
	c.fire(angle)
	var path := PackedVector2Array([SUN_C + aim_dir(angle) * MUZZLE])
	var oranges := 0
	var got := 0
	var points := 0
	var pot := false
	var steps := int(seconds / DT)
	for s in steps:
		var ev: Array = c.step([])
		for e: Dictionary in ev:
			match String(e.t):
				"hit":
					got += 1
					if c.kind[e.i] == ORANGE and (not sweethearts or c.st[c.pair[e.i]] == LIT):
						oranges += 2 if sweethearts else 1
				"pot":
					pot = true
		if c.balls.is_empty():
			break
		if s % every == 0:
			path.append(Vector2(c.balls[0].p))
		if hits > 0 and got >= hits:
			path.append(Vector2(c.balls[0].p))
			break
	points = c.shot_points
	return {"path": path, "oranges": oranges, "hits": got, "points": points, "pot": pot}

## The best line the sun can find from here: every angle across the fan
## played out on a copy, scored by marigolds first, then points, then a
## seed in the pot.
func best_angle() -> float:
	var best := PI * 0.5
	var best_score := -1.0
	var n := 64
	for k in n + 1:
		var a := lerpf(AIM_MIN + 0.02, PI - AIM_MIN - 0.02, float(k) / float(n))
		var r := trace(a, 0, 8.0, 1000)
		var sc := float(r.oranges) * 1000.0 + float(r.points) * 0.01 + (400.0 if r.pot else 0.0)
		if sc > best_score:
			best_score = sc
			best = a
	return best
