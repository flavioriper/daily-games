extends RefCounted

## Sudoku's generator: a seeded full grid, a symmetric dig that keeps the
## answer unique, and the grader that decides which band a dug puzzle is in.
## No state and no scene -- every entry point is static, and the cell tables
## are built once on first use.
##
## Two things are worth knowing before changing anything here. **Every grid
## is solved by reasoning, never by a guess** (the user, 2026-10-04: "fully
## solvable from deduction, no guess"): the dig keeps a cell out only while
## `deduce` still finishes the grid, and `deduce` is a reasoner, not a search
## -- singles on Easy, singles and the pencil's steps (`PENCIL`) on the rest,
## the hills' reckoning on Insane. A grid a reasoner finishes has one answer,
## so the dig asks nothing else. **And a band is a target AND a technique**:
## easy falls to singles alone, medium and hard should not, and ATTEMPTS tries
## is where that stops being free. A band is a tendency; a hung generator is
## worse than a medium day labelled hard.
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
## row is provisional, replaced by the bank in this board's own batch: its
## fallback of 24 bought no time over 22 (the same 3-in-40 seeds miss the
## shared TIME_BUDGET_MS on either, and on Hard's own 26, because the slow
## part is full_grid()'s backtracking rather than the dig target), and
## TIME_BUDGET_MS already degrades those seeds to graded:false rather than
## hanging, so the provisional row stands.
const TARGET := [14, 10, 26, 22]
## Tries before the band's technique test is given up on.
const ATTEMPTS := 10
## What `deduce` may use. SINGLES: a cell with one number left, a number with
## one cell left in a unit -- the moves made without writing anything down.
## PENCIL adds what the pencil marks show: a number held to one line of a
## region (or one region of a line) leaves the rest of it, two cells that
## share the same two numbers keep them from the rest of their unit, and two
## numbers with the same two cells left keep those cells to themselves.
## How far over its target a graded grid may stop, per band: reasoning gives
## out before a count of answers does.
const GIVENS_SLACK := [2, 2, 4, 4]
## Whether a graded grid must stall singles. Only the nine: measured
## 2026-10-04, 0 minis in 60 dug by reasoning wanted the pencil, and one nine
## in eight -- which is why Hard is banked (content/insane/sudoku_hard.json,
## tools/insane/sudoku_hard_ladder.gd) and this live deal is its fallback.
const NEEDS_PENCIL := [false, false, true, true]
const SINGLES := 0
const PENCIL := 1
## The band's tier: Easy never needs the pencil.
const TIER := [SINGLES, PENCIL, PENCIL, PENCIL]
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
static var _beside: Array = []

static func row_of(i: int) -> int:
	return i / N

static func col_of(i: int) -> int:
	return i % N

static func box_of(i: int) -> int:
	return (row_of(i) / BOX_R) * (N / BOX_C) + col_of(i) / BOX_C

## Switch the geometry to an `n` by `n` grid: 6 (regions two rows by three
## columns) or 9 (three by three). A no-op when it is already that size.
static func use(n: int) -> void:
	if n == N:
		# Never cleared when the size stands: the miner's threads all call
		# this at once, and _tables() builds aside and assigns whole.
		_tables()
		return
	N = n
	CELLS = n * n
	FULL = (1 << n) - 1
	BOX_R = 2 if n == 6 else 3
	BOX_C = 3
	_units = []
	_peers = []
	_beside = []
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
	var bs: Array = []
	for i in CELLS:
		bs.append(beside(i))
	# Assigned last and together, so a second thread or a re-entrant call
	# cannot see half-built tables through the `_units.is_empty()` guard.
	_peers = ps
	_units = us
	_beside = bs

## The day's puzzle. Whatever comes back is finished by the band's reasoning
## (TIER), deadline or no deadline. `graded` says whether the band's own
## test was also met within ATTEMPTS tries -- within GIVENS_SLACK of the
## target, and on Hard a grid singles alone do not finish -- the board plays
## either way and nothing reads it but the tests and the probe. `deadline`, shared with dig(), is what makes "give up on this
## attempt" and "give up on this whole call" the same clock rather than two
## budgets that can disagree. `budget_ms` defaults to TIME_BUDGET_MS for
## every real call; a test that wants generate()'s output to depend on
## nothing but the seed -- proving determinism, say -- passes -1 to turn the
## clock off entirely, the same sentinel dig() already uses for "no
## deadline".
static func generate(rng: RandomNumberGenerator, difficulty: int, budget_ms: int = TIME_BUDGET_MS) -> Dictionary:
	var d := clampi(difficulty, 0, TARGET.size() - 1)
	use(size_for(d))
	var out := {}
	var deadline := -1
	if budget_ms >= 0:
		deadline = Time.get_ticks_msec() + budget_ms
	var tier: int = TIER[d]
	for attempt in ATTEMPTS:
		var sol := full_grid(rng)
		var puz := dig(rng, sol, int(TARGET[d]), deadline, PackedInt32Array(), tier)
		var want := givens_of(puz) <= int(TARGET[d]) + int(GIVENS_SLACK[d])
		if want and NEEDS_PENCIL[d]:
			want = not deduce(puz, SINGLES)
		# The first grid stands unless a later one meets the band's test.
		if out.is_empty() or want:
			out = {"puzzle": puz, "solution": sol, "graded": want}
		if want:
			break
		if deadline >= 0 and Time.get_ticks_msec() >= deadline:
			break
	return out

static func givens_of(puz: PackedByteArray) -> int:
	var n := 0
	for v in puz:
		if v > 0:
			n += 1
	return n

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
static func count_solutions(puz: PackedByteArray, cap: int, hills := PackedInt32Array()) -> int:
	if not hills.is_empty():
		return _count_hills(puz, cap, hills)
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
	_count(g, rm, cm, bm, cap, found, hills)
	return int(found[0])

## Whether the hills touching `i` -- its own and those beside it -- can still
## come true once `i` holds a number. Always true on a grid with no hills.
static func _hills_hold(g: PackedByteArray, hills: PackedInt32Array, i: int) -> bool:
	if hills.is_empty():
		return true
	if not hill_ok(g, hills, i):
		return false
	for j in beside(i):
		if not hill_ok(g, hills, j):
			return false
	return true

static func _count(g: PackedByteArray, rm: PackedInt32Array, cm: PackedInt32Array,
		bm: PackedInt32Array, cap: int, found: Array, hills := PackedInt32Array()) -> bool:
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
		if not _hills_hold(g, hills, best):
			g[best] = 0
			continue
		rm[r] |= bit
		cm[c] |= bit
		bm[b] |= bit
		var stop := _count(g, rm, cm, bm, cap, found, hills)
		g[best] = 0
		rm[r] &= ~bit
		cm[c] &= ~bit
		bm[b] &= ~bit
		if stop:
			return true
	return false

## Take cells out of `sol` in a shuffled order, in 180-degree pairs so the
## givens read as a pattern and not as spilled salt, keeping a cell out only
## while `deduce` at `tier` (and with `hills`, when there are any) still
## finishes the grid -- so the puzzle handed back is always one reasoning
## solves, and has one answer for that reason. `deadline_ms` (an absolute
## Time.get_ticks_msec() reading, as generate() hands in) is checked before
## every pair: past it, the loop stops removing and returns the puzzle as it
## stands -- shallower than `target` wanted, but every removal already
## committed was already reasoned through, so the fallback is still a fair
## puzzle and not a hang. -1 (the default) means no deadline, for a caller
## with nothing to share one with.
static func dig(rng: RandomNumberGenerator, sol: PackedByteArray, target: int, deadline_ms: int = -1,
		hills := PackedInt32Array(), tier := PENCIL) -> PackedByteArray:
	var puz := sol.duplicate()
	var order: Array = []
	for i in CELLS:
		order.append(i)
	_shuffle(order, rng)
	# `order` shuffles every cell index, so every non-centre pair (i and its
	# mirror) comes up twice rather than `order` being a shuffle of the
	# distinct pairs. `seen` marks both indices the first time a pair is
	# handled and skips it outright on its second visit. That is always safe,
	# not just faster: if the pair succeeded, both its cells are already 0;
	# if it failed, it cannot succeed later, because whatever else got
	# removed in between only ever leaves fewer givens, and a reasoner that
	# stalls with a given in hand stalls without it too.
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
		if not deduce(puz, tier, hills):
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

# --- Insane: Hilltops (spec 2026-09-30-sudoku-polish-design.md, section 2) ---
#
# A **hill** sits in some cells and counts how many of the (up to) four cells
# beside it -- up, down, left, right -- hold a smaller number. Those four
# share a row or a column with it, so none can equal it: each is lower or
# higher, and a hill of 0 is the lowest thing around it, a hill of 4 the
# highest. The hills carry what the givens do not, and every banked grid is
# finished by reasoning -- singles, the pencil's steps and the hills' own
# reckoning (`deduce`) -- never by supposing a number and following it.
#
# `hills` is one int a cell everywhere below: -1 for no hill, else its count.

## How many hills a fresh grid is dealt before the dig, and the dig's floor.
## The dig goes as low as reasoning lets it; the prune after it then takes out
## every hill reasoning can do without.
const HILLS_DEALT := 34
const HILL_TARGET := 16
## Wall-clock ceiling on one live Hilltops deal (the fallback when the bank
## is empty or unreadable), in milliseconds.
const HILL_BUDGET_MS := 900

## The cells beside `i`, up, down, left and right, as far as the grid goes.
static func beside(i: int) -> PackedInt32Array:
	if _beside.size() == CELLS:
		return _beside[i]
	var out := PackedInt32Array()
	var r := row_of(i)
	var c := col_of(i)
	if r > 0:
		out.append(i - N)
	if r < N - 1:
		out.append(i + N)
	if c > 0:
		out.append(i - 1)
	if c < N - 1:
		out.append(i + 1)
	return out

## What a hill at `i` would say over the full grid `g`.
static func hill_count(g: PackedByteArray, i: int) -> int:
	var n := 0
	for j in beside(i):
		if g[j] < g[i]:
			n += 1
	return n

## Whether the hill at `h` can still come true over a part-filled grid: only
## asked once `h` itself holds a number. An empty cell beside it can still be
## lower only if the hill is above 1, and higher only if it is below N.
static func hill_ok(g: PackedByteArray, hills: PackedInt32Array, h: int) -> bool:
	var k := hills[h]
	var v := int(g[h])
	if k < 0 or v == 0:
		return true
	var lower := 0
	var higher := 0
	var open := 0
	var near := beside(h)
	for j in near:
		if g[j] == 0:
			open += 1
		elif g[j] < v:
			lower += 1
		else:
			higher += 1
	var up := near.size() - k
	return lower <= k and higher <= up \
		and lower + (open if v > 1 else 0) >= k \
		and higher + (open if v < N else 0) >= up

## The deal: a full grid, HILLS_DEALT hills read off it, the symmetric dig as
## low as reasoning with the hills goes, and then every hill reasoning can do
## without taken out. {"puzzle", "solution", "hills", "ok"}; `ok` false when
## the deadline cut it short (the grid is still reasoned out, only easier).
static func generate_hills(rng: RandomNumberGenerator, budget_ms: int = -1) -> Dictionary:
	use(9)
	var deadline := -1
	if budget_ms >= 0:
		deadline = Time.get_ticks_msec() + budget_ms
	var sol := full_grid(rng)
	var hills := PackedInt32Array()
	hills.resize(CELLS)
	hills.fill(-1)
	var order: Array = []
	for i in CELLS:
		order.append(i)
	_shuffle(order, rng)
	for k in mini(HILLS_DEALT, CELLS):
		var i: int = order[k]
		hills[i] = hill_count(sol, i)
	var puz := dig(rng, sol, HILL_TARGET, deadline, hills, PENCIL)
	var ok := deadline < 0 or Time.get_ticks_msec() < deadline
	# Every hill reasoning can do without comes out, in a shuffled order.
	_shuffle(order, rng)
	for i in order:
		if hills[i] < 0:
			continue
		if deadline >= 0 and Time.get_ticks_msec() >= deadline:
			ok = false
			break
		var k := hills[i]
		hills[i] = -1
		if not deduce(puz, PENCIL, hills):
			hills[i] = k
	return {"puzzle": puz, "solution": sol, "hills": hills, "ok": ok}

## How many hills a grid carries.
static func hill_total(hills: PackedInt32Array) -> int:
	var n := 0
	for k in hills:
		if k >= 0:
			n += 1
	return n

# --- the reasoner: what a grid asks of a player ---

## Whether reasoning at `tier` finishes `puz` (under `hills`, when there are
## any): singles, the pencil's steps from PENCIL up, and the hills' own
## reckoning (a hill's number must leave exactly its count lower beside it; a
## cell beside a hill keeps only the numbers some number of the hill agrees
## with). Never a supposition and never a search, so a grid this finishes has
## one answer and asks for no guess.
static func deduce(puz: PackedByteArray, tier: int, hills := PackedInt32Array()) -> bool:
	_tables()
	var cand := PackedInt32Array()
	cand.resize(CELLS)
	for i in CELLS:
		cand[i] = (1 << (puz[i] - 1)) if puz[i] > 0 else FULL
	return _propagate(cand, hills, tier) and _settled(cand)

static func _settled(cand: PackedInt32Array) -> bool:
	for m in cand:
		if m == 0 or (m & (m - 1)) != 0:
			return false
	return true

## Reasoning until nothing changes: singles and the hills first, and only
## when those stall (and `tier` allows) one step of the pencil. False when
## the grid breaks.
static func _propagate(cand: PackedInt32Array, hills: PackedInt32Array, tier := SINGLES) -> bool:
	# A settled cell crosses its number out of its peers once.
	var done := PackedByteArray()
	done.resize(CELLS)
	while true:
		var changed := false
		for i in CELLS:
			var m := cand[i]
			if m == 0:
				return false
			if done[i] or (m & (m - 1)) != 0:
				continue
			done[i] = 1
			for j in _peers[i]:
				if cand[j] & m:
					cand[j] &= ~m
					if cand[j] == 0:
						return false
					changed = true
		for u in _units:
			# `once` the numbers some cell of the unit can take, `twice` those
			# two or more can: a number in the first and not the second has
			# one cell left.
			var once := 0
			var twice := 0
			for i in u:
				var m := cand[i]
				twice |= once & m
				once |= m
			if once != FULL:
				return false
			var lone := once & ~twice
			if lone == 0:
				continue
			for i in u:
				var m := cand[i] & lone
				if m == 0 or m == cand[i]:
					continue
				if (m & (m - 1)) != 0:
					return false
				cand[i] = m
				changed = true
		if not hills.is_empty():
			for h in CELLS:
				if hills[h] < 0:
					continue
				var r := _hill_step(cand, hills[h], h)
				if r < 0:
					return false
				if r > 0:
					changed = true
		if changed:
			continue
		if tier < PENCIL or not _pencil(cand):
			return true
	return true

## One step of the pencil over the candidates; true when it crossed something
## out. Tried in the order a player meets them.
static func _pencil(cand: PackedInt32Array) -> bool:
	return _locked(cand) or _naked_pairs(cand) or _hidden_pairs(cand)

## A number whose cells left in a region all lie on one line leaves the rest
## of that line; one whose cells left on a line all lie in one region leaves
## the rest of that region.
static func _locked(cand: PackedInt32Array) -> bool:
	var did := false
	for ui in _units.size():
		var u: PackedInt32Array = _units[ui]
		for d in N:
			var bit := 1 << d
			var first := -1
			var n := 0
			var one_row := true
			var one_col := true
			var one_box := true
			for i in u:
				if (cand[i] & bit) == 0:
					continue
				if n == 0:
					first = i
				else:
					one_row = one_row and row_of(i) == row_of(first)
					one_col = one_col and col_of(i) == col_of(first)
					one_box = one_box and box_of(i) == box_of(first)
				n += 1
			if n < 2:
				continue
			if ui >= 2 * N:
				if one_row:
					did = _strike(cand, _units[row_of(first)], bit, u) or did
				elif one_col:
					did = _strike(cand, _units[N + col_of(first)], bit, u) or did
			elif one_box:
				did = _strike(cand, _units[2 * N + box_of(first)], bit, u) or did
		if did:
			return true
	return false

## Crosses `bits` out of every cell of `unit` that is not also in `keep`.
static func _strike(cand: PackedInt32Array, unit: PackedInt32Array, bits: int, keep: PackedInt32Array) -> bool:
	var did := false
	for i in unit:
		if (cand[i] & bits) != 0 and not keep.has(i):
			cand[i] &= ~bits
			did = true
	return did

## Two cells of a unit left with the same two numbers: those two numbers go
## nowhere else in it.
static func _naked_pairs(cand: PackedInt32Array) -> bool:
	for u in _units:
		for a in u.size():
			var m := cand[u[a]]
			if popcount(m) != 2:
				continue
			for b in range(a + 1, u.size()):
				if cand[u[b]] != m:
					continue
				if _strike(cand, u, m, PackedInt32Array([u[a], u[b]])):
					return true
	return false

## Two numbers of a unit left with the same two cells: those two cells take
## nothing else.
static func _hidden_pairs(cand: PackedInt32Array) -> bool:
	var seats := PackedInt32Array()
	seats.resize(N)
	for u in _units:
		seats.fill(0)
		for k in u.size():
			var m := cand[u[k]]
			for d in N:
				if m & (1 << d):
					seats[d] |= 1 << k
		for d1 in N:
			if popcount(seats[d1]) != 2:
				continue
			for d2 in range(d1 + 1, N):
				if seats[d2] != seats[d1]:
					continue
				var pair := (1 << d1) | (1 << d2)
				var did := false
				for k in u.size():
					if (seats[d1] & (1 << k)) != 0 and cand[u[k]] != pair:
						cand[u[k]] &= pair
						did = true
				if did:
					return true
	return false

## One hill's reckoning over the candidates: keeps only the hill's numbers
## that can leave exactly `k` lower beside it, and only the neighbours'
## numbers some kept hill number agrees with. 1 when something was crossed
## out, 0 when nothing, -1 when the hill cannot come true.
static func _hill_step(cand: PackedInt32Array, k: int, h: int) -> int:
	var near := beside(h)
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	for j in near:
		lo.append(_low_digit(cand[j]))
		hi.append(_high_digit(cand[j]))
	var did := 0
	var keep := 0
	for v in range(1, N + 1):
		var bit := 1 << (v - 1)
		if (cand[h] & bit) == 0:
			continue
		var must := 0
		var may := 0
		for x in near.size():
			if hi[x] < v:
				must += 1
			if lo[x] < v:
				may += 1
		if must <= k and k <= may:
			keep |= bit
	if keep == 0:
		return -1
	if keep != cand[h]:
		cand[h] = keep
		did = 1
	# A neighbour's number w stays only if some hill number v leaves room for
	# the other neighbours to make up the count with w's own part in it.
	for x in near.size():
		var j: int = near[x]
		var mask := 0
		for w in range(1, N + 1):
			var wb := 1 << (w - 1)
			if (cand[j] & wb) == 0:
				continue
			for v in range(1, N + 1):
				if v == w or (keep & (1 << (v - 1))) == 0:
					continue
				var need := k - (1 if w < v else 0)
				var must := 0
				var may := 0
				for y in near.size():
					if y == x:
						continue
					if hi[y] < v:
						must += 1
					if lo[y] < v:
						may += 1
				if must <= need and need <= may:
					mask |= wb
					break
		if mask == 0:
			return -1
		if mask != cand[j]:
			cand[j] = mask
			did = 1
	return did

static func _low_digit(m: int) -> int:
	for d in range(1, N + 1):
		if m & (1 << (d - 1)):
			return d
	return N + 1

static func _high_digit(m: int) -> int:
	for d in range(N, 0, -1):
		if m & (1 << (d - 1)):
			return d
	return 0

## The count on a grid with hills: every node runs the logic solver's
## propagation (singles and the hills' reckoning) before it branches on the
## cell with fewest numbers left, which cuts the tree down far more than the
## plain count's masks can when there are only a dozen givens.
static func _count_hills(puz: PackedByteArray, cap: int, hills: PackedInt32Array) -> int:
	_tables()
	var cand := PackedInt32Array()
	cand.resize(CELLS)
	for i in CELLS:
		cand[i] = (1 << (puz[i] - 1)) if puz[i] > 0 else FULL
	var found: Array = [0]
	_count_cand(cand, cap, hills, found)
	return int(found[0])

static func _count_cand(cand: PackedInt32Array, cap: int, hills: PackedInt32Array, found: Array) -> bool:
	if not _propagate(cand, hills):
		return false
	var best := -1
	var best_n := N + 1
	for i in CELLS:
		var n := popcount(cand[i])
		if n > 1 and n < best_n:
			best_n = n
			best = i
			if n == 2:
				break
	if best < 0:
		found[0] = int(found[0]) + 1
		return int(found[0]) >= cap
	for d in range(1, N + 1):
		var bit := 1 << (d - 1)
		if (cand[best] & bit) == 0:
			continue
		var trial := cand.duplicate()
		trial[best] = bit
		if _count_cand(trial, cap, hills, found):
			return true
	return false

# --- the bank (content/insane/sudoku.json) ---

## A grid as the banks keep it (Hilltops in content/insane/sudoku.json, Hard's
## plain nine in sudoku_hard.json, its `hills` all '.'): `puzzle` and `solution` one digit a
## cell in reading order ('.' empty), `hills` one character a cell ('.' none,
## else the count).
static func to_bank(out: Dictionary) -> Dictionary:
	var p := ""
	var s := ""
	var h := ""
	for i in 81:
		p += "." if out.puzzle[i] == 0 else str(out.puzzle[i])
		s += str(out.solution[i])
		h += "." if out.hills.is_empty() or out.hills[i] < 0 else str(out.hills[i])
	return {"puzzle": p, "solution": s, "hills": h}

## The bank's grid back as generate_hills hands one over; {} for an entry that
## does not hold together. The phone checks what is cheap -- a legal answer,
## givens that agree with it, hills that are its own counts -- and trusts the
## miner's proof that reasoning finishes it, which the ladder's grade re-runs
## on the Mac.
static func from_bank(board: Dictionary) -> Dictionary:
	var p := String(board.get("puzzle", ""))
	var s := String(board.get("solution", ""))
	var h := String(board.get("hills", ""))
	if p.length() != 81 or s.length() != 81 or h.length() != 81:
		return {}
	use(9)
	var puz := PackedByteArray()
	var sol := PackedByteArray()
	var hills := PackedInt32Array()
	puz.resize(81)
	sol.resize(81)
	hills.resize(81)
	for i in 81:
		puz[i] = 0 if p[i] == "." else int(p[i])
		sol[i] = int(s[i])
		hills[i] = -1 if h[i] == "." else int(h[i])
		if sol[i] < 1 or sol[i] > 9 or (puz[i] != 0 and puz[i] != sol[i]):
			return {}
	for u in units():
		var mask := 0
		for i in u:
			mask |= 1 << (sol[i] - 1)
		if mask != FULL:
			return {}
	for i in 81:
		if hills[i] >= 0 and hills[i] != hill_count(sol, i):
			return {}
	return {"puzzle": puz, "solution": sol, "hills": hills, "ok": true}
