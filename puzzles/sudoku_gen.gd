extends RefCounted

## Sudoku's generator: a seeded full grid, a symmetric dig that keeps the
## answer unique, and the grader that decides which band a dug puzzle is in.
## No state and no scene -- every entry point is static, and the cell tables
## are built once on first use.
##
## Two things are worth knowing before changing anything here. **The dig is
## the expensive half**, because every cell taken out is a uniqueness count;
## the count is most-constrained-cell-first precisely so a second answer is
## found or ruled out in a few thousand steps instead of a few million.
## **And a band is a target AND a technique**: easy must fall to naked and
## hidden singles, medium and hard must not, and ATTEMPTS tries is where
## that stops being free. A band is a tendency; a hung generator is worse
## than a medium day labelled hard.
## Spec: docs/superpowers/specs/2026-09-20-sudoku-flat-design.md, section 8.

## The grid's size is the band's: easy and medium are the mini, six by six
## in six regions of two rows by three columns, and hard is the classic nine
## by nine. These are static vars and not consts because of that, and
## `use()` is the one thing that changes them; every table below is rebuilt
## when it does. One board is open at a time, so one geometry at a time is
## all the game ever needs.
static var N := 9
static var CELLS := 81
## N bits, digits 1..N.
static var FULL := 511
## A region's height and width in cells.
static var BOX_R := 3
static var BOX_C := 3
## The side of the grid, per band: easy, medium, hard, insane.
const SIZE := [6, 6, 9, 9]
## Givens aimed at, per band. The mini's are out of 36 cells, not 81. Insane's
## row is provisional, replaced by the bank in this board's own batch.
const TARGET := [14, 10, 26, 24]
## Tries before the band's technique test is given up on. Measured: six left
## one hard day in twelve solvable by singles, ten leaves none.
const ATTEMPTS := 10
## How far singles_solve will iterate before giving up. Eighty-one placements
## is the most any grid can need, so this cannot be hit by a real board and
## exists only so a bug here cannot hang a phone.
const PASSES := 200
## Wall-clock ceiling on one generate() call, in milliseconds, shared by two
## checks: generate()'s own attempt loop stops trying a fresh attempt once
## it is crossed, and dig() (handed the same deadline) stops removing cells
## mid-attempt and hands back the puzzle as it stands -- more givens than
## the band wanted, but still unique, because dig() only ever commits a
## removal once count_solutions has confirmed it. ATTEMPTS alone bounds the
## number of tries, not the time they take, and this runs inside build() at
## board open on a phone; a phone slower than this Mac could otherwise see a
## single dig() run far longer than any attempt measured here. Set above the
## slowest seed in the test suite (band 2, seed 9203, six failed attempts
## before its seventh grades), which two separate timing sessions put at
## 193&ndash;201.5 ms end to end -- one pass at 193-195 ms, a later one
## chasing an unrelated flake at 196.5-201.5 ms -- rather than at the
## flattering low end of that range or at the first round number that
## sounded safe: a tighter cap here silently turns a hard day into an
## ungraded one instead of only guarding the tail, the same failure mode this
## budget hit at 150 ms before the dig rewrite that stopped it re-checking
## the same pair twice.
const TIME_BUDGET_MS := 300

static var _peers: Array = []
static var _units: Array = []

static func row_of(i: int) -> int:
	return i / N

static func col_of(i: int) -> int:
	return i % N

static func box_of(i: int) -> int:
	return (row_of(i) / BOX_R) * (N / BOX_C) + col_of(i) / BOX_C

## Switch the geometry to an `n` by `n` grid: 6 (regions two rows by three
## columns) or 9 (three by three). A no-op when it is already that size.
static func use(n: int) -> void:
	if n == N and not _units.is_empty():
		return
	N = n
	CELLS = n * n
	FULL = (1 << n) - 1
	BOX_R = 2 if n == 6 else 3
	BOX_C = 3
	_units = []
	_peers = []
	_tables()

## The side of the grid band `difficulty` is played on.
static func size_for(difficulty: int) -> int:
	return int(SIZE[clampi(difficulty, 0, SIZE.size() - 1)])

## The cells (twenty on a nine, ten on a six) that share a row, a column or a region with `i`.
static func peers_of(i: int) -> PackedInt32Array:
	_tables()
	return _peers[i]

## Every unit: N rows, then N columns, then N regions.
static func units() -> Array:
	_tables()
	return _units

static func _tables() -> void:
	if not _units.is_empty():
		return
	var us: Array = []
	for r in N:
		var u := PackedInt32Array()
		for c in N:
			u.append(r * N + c)
		us.append(u)
	for c in N:
		var u := PackedInt32Array()
		for r in N:
			u.append(r * N + c)
		us.append(u)
	for b in N:
		var u := PackedInt32Array()
		for i in CELLS:
			if box_of(i) == b:
				u.append(i)
		us.append(u)
	var ps: Array = []
	for i in CELLS:
		var p := PackedInt32Array()
		for j in CELLS:
			if j == i:
				continue
			if row_of(j) == row_of(i) or col_of(j) == col_of(i) or box_of(j) == box_of(i):
				p.append(j)
		ps.append(p)
	# Assigned last and together, so a second thread or a re-entrant call
	# cannot see half-built tables through the `_units.is_empty()` guard.
	_peers = ps
	_units = us

## The day's puzzle. `graded` says whether the band's technique test was met
## within ATTEMPTS tries; the board plays either way and nothing reads it but
## the tests and the probe. `deadline`, shared with dig(), is what makes
## "give up on this attempt" and "give up on this whole call" the same
## clock rather than two budgets that can disagree. `budget_ms` defaults to
## TIME_BUDGET_MS for every real call; a test that wants generate()'s output
## to depend on nothing but the seed -- proving determinism, say -- passes
## -1 to turn the clock off entirely, the same sentinel dig() already uses
## for "no deadline".
static func generate(rng: RandomNumberGenerator, difficulty: int, budget_ms: int = TIME_BUDGET_MS) -> Dictionary:
	var d := clampi(difficulty, 0, TARGET.size() - 1)
	use(size_for(d))
	var out := {}
	var deadline := -1
	if budget_ms >= 0:
		deadline = Time.get_ticks_msec() + budget_ms
	for attempt in ATTEMPTS:
		var sol := full_grid(rng)
		var puz := dig(rng, sol, int(TARGET[d]), deadline)
		var singled := is_complete(singles_solve(puz))
		var want := singled if d == 0 else not singled
		out = {"puzzle": puz, "solution": sol, "graded": want}
		if want:
			break
		if deadline >= 0 and Time.get_ticks_msec() >= deadline:
			break
	return out

## A full legal grid, by randomised backtracking over row, column and region
## bitmasks. Packed arrays are passed by reference in GDScript, which is what
## lets the masks be undone after a failed branch.
static func full_grid(rng: RandomNumberGenerator) -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(CELLS)
	var rm := PackedInt32Array()
	rm.resize(N)
	var cm := PackedInt32Array()
	cm.resize(N)
	var bm := PackedInt32Array()
	bm.resize(N)
	_fill(rng, g, rm, cm, bm, 0)
	return g

static func _fill(rng: RandomNumberGenerator, g: PackedByteArray, rm: PackedInt32Array,
		cm: PackedInt32Array, bm: PackedInt32Array, i: int) -> bool:
	if i == CELLS:
		return true
	var r := row_of(i)
	var c := col_of(i)
	var b := box_of(i)
	var avail := FULL & ~(rm[r] | cm[c] | bm[b])
	var opts: Array = []
	for d in range(1, N + 1):
		if avail & (1 << (d - 1)):
			opts.append(d)
	_shuffle(opts, rng)
	for d in opts:
		var bit := 1 << (int(d) - 1)
		g[i] = d
		rm[r] |= bit
		cm[c] |= bit
		bm[b] |= bit
		if _fill(rng, g, rm, cm, bm, i + 1):
			return true
		g[i] = 0
		rm[r] &= ~bit
		cm[c] &= ~bit
		bm[b] &= ~bit
	return false

## How many solutions `puz` has, stopping at `cap`. Most-constrained cell
## first: a cell with no candidate kills the branch at once, and a cell with
## one is taken before any cell with two.
static func count_solutions(puz: PackedByteArray, cap: int) -> int:
	var g := puz.duplicate()
	var rm := PackedInt32Array()
	rm.resize(N)
	var cm := PackedInt32Array()
	cm.resize(N)
	var bm := PackedInt32Array()
	bm.resize(N)
	for i in CELLS:
		if g[i] > 0:
			var bit := 1 << (g[i] - 1)
			rm[row_of(i)] |= bit
			cm[col_of(i)] |= bit
			bm[box_of(i)] |= bit
	# An Array, not an int: GDScript has no out-parameters and an Array is
	# the cheapest box that survives the recursion.
	var found: Array = [0]
	_count(g, rm, cm, bm, cap, found)
	return int(found[0])

static func _count(g: PackedByteArray, rm: PackedInt32Array, cm: PackedInt32Array,
		bm: PackedInt32Array, cap: int, found: Array) -> bool:
	var best := -1
	var best_mask := 0
	var best_n := N + 1
	for i in CELLS:
		if g[i] > 0:
			continue
		var m := FULL & ~(rm[row_of(i)] | cm[col_of(i)] | bm[box_of(i)])
		var n := popcount(m)
		if n == 0:
			return false
		if n < best_n:
			best_n = n
			best = i
			best_mask = m
			if n == 1:
				break
	if best < 0:
		found[0] = int(found[0]) + 1
		return int(found[0]) >= cap
	var r := row_of(best)
	var c := col_of(best)
	var b := box_of(best)
	for d in range(1, N + 1):
		var bit := 1 << (d - 1)
		if not (best_mask & bit):
			continue
		g[best] = d
		rm[r] |= bit
		cm[c] |= bit
		bm[b] |= bit
		var stop := _count(g, rm, cm, bm, cap, found)
		g[best] = 0
		rm[r] &= ~bit
		cm[c] &= ~bit
		bm[b] &= ~bit
		if stop:
			return true
	return false

## Take cells out of `sol` in a shuffled order, in 180-degree pairs so the
## givens read as a pattern and not as spilled salt, keeping a cell out only
## while exactly one solution survives. `deadline_ms` (an absolute
## Time.get_ticks_msec() reading, as generate() hands in) is checked before
## every pair: past it, the loop stops removing and returns the puzzle as it
## stands -- shallower than `target` wanted, but every removal already
## committed was already proved unique, so the fallback is still a real,
## still-unique puzzle and not a hang. -1 (the default) means no deadline,
## for a caller with nothing to share one with.
static func dig(rng: RandomNumberGenerator, sol: PackedByteArray, target: int, deadline_ms: int = -1) -> PackedByteArray:
	var puz := sol.duplicate()
	var order: Array = []
	for i in CELLS:
		order.append(i)
	_shuffle(order, rng)
	# `order` shuffles all 81 cell indices, so every non-centre pair (i,
	# 80-i) comes up twice -- once as i, once as its mirror -- rather than
	# `order` being a shuffle of the forty-one distinct pairs. `seen` marks
	# both indices the first time a pair is handled and skips it outright on
	# its second visit, rather than re-running count_solutions on it. That is
	# always safe, not just faster: if the pair succeeded, both its cells are
	# already 0 and the second visit is a no-op anyway (the a==0 and b==0
	# guard below would have caught it regardless); if it failed, it cannot
	# succeed later, because whatever else got removed from the grid in
	# between only ever has fewer givens than when this pair was first
	# tried, and removing a given can only add solutions, never take one
	# away -- a pair that leaves two answers at a higher given count leaves
	# at least that many at every lower one too.
	var seen := PackedByteArray()
	seen.resize(CELLS)
	var givens := CELLS
	for i in order:
		if givens <= target:
			break
		if deadline_ms >= 0 and Time.get_ticks_msec() >= deadline_ms:
			break
		if seen[i]:
			continue
		var j: int = CELLS - 1 - int(i)
		seen[i] = 1
		seen[j] = 1
		var a := puz[i]
		var b := puz[j]
		if a == 0 and b == 0:
			continue
		var removing := 0
		if a > 0:
			removing += 1
		if j != int(i) and b > 0:
			removing += 1
		puz[i] = 0
		puz[j] = 0
		if count_solutions(puz, 2) != 1:
			puz[i] = a
			puz[j] = b
		else:
			givens -= removing
	return puz

## As far as naked singles (a cell with one candidate) and hidden singles (a
## unit where one cell alone can take a digit) get. Those two are the moves a
## player makes without writing anything down, so a grid this finishes is
## easy by definition and one it stalls on wants a pencil.
static func singles_solve(puz: PackedByteArray) -> PackedByteArray:
	_tables()
	var g := puz.duplicate()
	for _pass in PASSES:
		var placed := false
		var cand := PackedInt32Array()
		cand.resize(CELLS)
		for i in CELLS:
			if g[i] > 0:
				continue
			var m := FULL
			for j in _peers[i]:
				if g[j] > 0:
					m &= ~(1 << (g[j] - 1))
			cand[i] = m
			if m == 0:
				return g
			if popcount(m) == 1:
				g[i] = _digit_of(m)
				placed = true
		if not placed:
			for u in _units:
				for d in range(1, N + 1):
					var bit := 1 << (d - 1)
					var seat := -1
					var n := 0
					var has := false
					for i in u:
						if g[i] == d:
							has = true
							break
						if g[i] == 0 and (cand[i] & bit) != 0:
							seat = i
							n += 1
					if not has and n == 1:
						g[seat] = d
						placed = true
						break
				if placed:
					break
		if not placed:
			return g
	return g

static func is_complete(g: PackedByteArray) -> bool:
	for i in CELLS:
		if g[i] == 0:
			return false
	return true

static func _digit_of(mask: int) -> int:
	for d in range(1, N + 1):
		if mask == (1 << (d - 1)):
			return d
	return 0

## How many bits are set. Public because both this file's uniqueness count
## and singles_solve's candidate check call it -- a function two classes call
## was never really private.
static func popcount(m: int) -> int:
	var n := 0
	while m != 0:
		m &= m - 1
		n += 1
	return n

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for k in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = arr[k]
		arr[k] = arr[j]
		arr[j] = tmp
