extends RefCounted

## The computer at Dominoes. **It is handed a view, never the rules**
## (`Rules.view(side)`): its own tiles, the line, how many tiles the other
## side and the boneyard hold, and what was done in the open. It does not
## know the other hand or what it will draw, at any level.
##
## The levels are how it chooses among the tiles that fit:
##   0  any of them, more often than not; else as level 1 with a shaky eye
##   1  the heavy tiles and the doubles first, keeping numbers it has more of
##   2  it deals the tiles it cannot see every way they could lie -- the
##      other side holds none of a number it drew or passed on -- plays each
##      of its moves out to the end of the hand many times, and takes the one
##      that scores best on average
##
## A draw or a pass is never a choice (the rules force both), so `plan` with
## one legal move answers it at once.
##
## `plan` is safe on a worker thread: it touches nothing but the view.

const Rules = preload("res://versus/dominoes_rules.gd")

## How often the easy level lays whatever comes to hand.
const LOOSE := 0.6
const BLUR := [5.0, 0.6, 0.0]
const BUDGET_MS := 320
const HINT_BUDGET_MS := 260
## Deals tried at the least, whatever the clock says, and at the most.
const DEALS_MIN := 10
const DEALS_MAX := 400

## The move to make for the side the view is of, -1 when it has none.
func plan(v: Dictionary, level: int, rng_seed: int, budget_ms := -1) -> int:
	var legal: PackedInt32Array = v.legal
	if legal.is_empty():
		return -1
	if legal.size() == 1:
		return legal[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	if level <= 0 and rng.randf() < LOOSE:
		return legal[rng.randi() % legal.size()]
	if level < 2:
		return _by_eye(v, legal, rng, BLUR[maxi(level, 0)])
	return _by_deals(v, legal, rng, BUDGET_MS if budget_ms < 0 else budget_ms)

## The two ends as `m` would leave them.
static func ends_after(ends: PackedInt32Array, m: int) -> PackedInt32Array:
	var tile := m >> 1
	if ends[0] < 0:
		return PackedInt32Array([Rules.LO[tile], Rules.HI[tile]])
	var out := ends.duplicate()
	var touch := ends[m & 1]
	out[m & 1] = Rules.HI[tile] if Rules.LO[tile] == touch else Rules.LO[tile]
	return out

## What a move looks worth with no reckoning: the pips it gets out of the
## hand, a double (it fits one number only, so it goes while it can), and the
## tiles left that would still fit afterwards.
static func worth(v: Dictionary, m: int) -> float:
	var tile := m >> 1
	var score := float(Rules.weight(tile))
	if Rules.is_double(tile):
		score += 3.0
	var after := ends_after(v.ends, m)
	for t: int in v.hand:
		if t == tile:
			continue
		if Rules.LO[t] == after[0] or Rules.HI[t] == after[0] or Rules.LO[t] == after[1] or Rules.HI[t] == after[1]:
			score += 2.0
	return score

func _by_eye(v: Dictionary, legal: PackedInt32Array, rng: RandomNumberGenerator, blur: float) -> int:
	var best := legal[0]
	var best_score := -INF
	for m in legal:
		var score := worth(v, m) + (rng.randf_range(-blur, blur) if blur > 0.0 else 0.0)
		if score > best_score:
			best_score = score
			best = m
	return best

## The numbers the other side is known to hold none of: the two ends of the
## line whenever it drew or passed. A tile drawn and kept may hold a number it
## lacked before, so a draw that was not the last of its turn forgets what
## was known until then.
static func lacks(v: Dictionary) -> Array[int]:
	var other: int = 1 - int(v.side)
	var out: Array[int] = []
	var said: Array = v.said
	for i in said.size():
		var e: Array = said[i]
		if e[0] != other or e[1] == Rules.LAID:
			continue
		if e[1] == Rules.DREW:
			# What the same side did next: laid the tile it drew, or kept it.
			var kept := true
			for j in range(i + 1, said.size()):
				if said[j][0] == other:
					kept = said[j][1] != Rules.LAID
					break
			if kept:
				out.clear()
		for n: int in [e[2], e[3]]:
			if n >= 0 and not out.has(n):
				out.append(n)
	return out

func _by_deals(v: Dictionary, legal: PackedInt32Array, rng: RandomNumberGenerator, budget: int) -> int:
	var side: int = v.side
	var gone := {}
	for t: int in v.hand:
		gone[t] = true
	for t: int in v.line:
		gone[t] = true
	var none := lacks(v)
	var free: Array[int] = []
	var barred: Array[int] = []
	for t in Rules.TILES:
		if gone.has(t):
			continue
		if none.has(Rules.LO[t]) or none.has(Rules.HI[t]):
			barred.append(t)
		else:
			free.append(t)
	var theirs: int = v.theirs
	var sums := PackedFloat32Array()
	sums.resize(legal.size())
	var stop_at := Time.get_ticks_msec() + budget
	var deals := 0
	while deals < DEALS_MAX and (deals < DEALS_MIN or Time.get_ticks_msec() < stop_at):
		deals += 1
		_mix(free, rng)
		_mix(barred, rng)
		# The other hand from the tiles it may hold, as far as they go; the
		# rest, mixed, is the boneyard.
		var all: Array[int] = free + barred
		var hand := PackedInt32Array(all.slice(0, theirs))
		var rest: Array[int] = all.slice(theirs)
		_mix(rest, rng)
		var base: RefCounted = Rules.new()
		base.quiet = true
		base.hands[side] = v.hand.duplicate()
		base.hands[1 - side] = hand
		base.stock = PackedInt32Array(rest)
		base.ends = v.ends.duplicate()
		if base.ends[0] >= 0:
			base.plays.append(Vector3i(0, -1, 0))
		base.turn = side
		base.passes = v.passes
		for i in legal.size():
			var game: RefCounted = base.copy()
			game.make(legal[i])
			_play_out(game)
			if game.hand_winner == side:
				sums[i] += game.hand_points
			elif game.hand_winner >= 0:
				sums[i] -= game.hand_points
	var best := legal[0]
	var best_score := -INF
	for i in legal.size():
		# The eye's score breaks what the deals leave even.
		var score := sums[i] / deals + 0.12 * worth(v, legal[i])
		if score > best_score:
			best_score = score
			best = legal[i]
	return best

## Both sides lay their heaviest tile that fits, doubles first, to the end of
## the hand.
static func _play_out(game: RefCounted) -> void:
	while not game.hand_over:
		var moves: PackedInt32Array = game.legal_moves()
		var pick := moves[0]
		if moves.size() > 1:
			var best := -1
			for m in moves:
				var w: int = Rules.weight(m >> 1) + (3 if Rules.is_double(m >> 1) else 0)
				if w > best:
					best = w
					pick = m
		game.make(pick)

static func _mix(list: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var keep := list[i]
		list[i] = list[j]
		list[j] = keep
