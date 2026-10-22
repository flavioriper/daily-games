extends RefCounted

## Picket Sums' generator: Sudoku's full grid (puzzles/sudoku_gen.gd, whose
## geometry and tables this shares), fenced into plots, each with a tag of
## what its numbers add up to. No number repeats inside a plot.
##
## **Every day is solved by reasoning, never by a guess**, Sudoku's rule
## (the user, 2026-10-04). `deduce` is a reasoner: Sudoku's singles, each
## plot's sums (a cell keeps only the numbers some way of filling its plot
## to the tag uses), and on every band but Easy Sudoku's pencil steps. A grid
## the reasoner finishes has one answer. When a fencing stalls it, a number
## of the answer is written in where the reasoner was least sure, until it
## goes through; the fencing that needed fewest of those is the day.
##
## **Insane is Lost Tags**: some plots have lost their tag. Their numbers
## still never repeat, but nothing says what they add up to. A tag is only
## taken off while the reasoner still finishes the grid without it.
## Spec: docs/superpowers/specs/2026-10-22-picket-design.md.

const Gen = preload("res://puzzles/sudoku_gen.gd")

## The side of the grid, per band: Sudoku's (the mini, then the nine).
const SIZE := [6, 6, 9, 9]
## The plot sizes a band deals, drawn with equal odds from the list.
const PLOT_SIZES := [[2, 2, 2, 3], [2, 2, 3, 3, 4], [2, 3, 3, 4], [2, 3, 3, 4, 4, 5]]
## What the reasoner may use: Easy singles and sums only.
const TIER := [Gen.SINGLES, Gen.PENCIL, Gen.PENCIL, Gen.PENCIL]
## How many fencings are tried for the fewest numbers written in.
const ATTEMPTS := [6, 6, 4, 4]
## A fencing needing this many numbers or fewer is kept at once.
const GIVENS_OK := [3, 1, 2, 1]
## Insane's tags taken off, at most.
const LOST := [0, 0, 0, 6]
## The whole call's ceiling at board open, as Sudoku's TIME_BUDGET_MS.
const TIME_BUDGET_MS := 300

## The orthogonal steps, for growing a plot.
const STEPS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## The day: {"puzzle", "solution", "cage_of" (a plot id a cell), "sums" (a
## tag a plot, -1 when lost), "plots" (the cells of each plot, an Array of
## PackedInt32Array), "graded"}. `budget_ms` -1 turns the clock off.
static func generate(rng: RandomNumberGenerator, difficulty: int, budget_ms: int = TIME_BUDGET_MS) -> Dictionary:
	var d := clampi(difficulty, 0, SIZE.size() - 1)
	Gen.use(int(SIZE[d]))
	var deadline := -1
	if budget_ms >= 0:
		deadline = Time.get_ticks_msec() + budget_ms
	var best := {}
	for attempt in int(ATTEMPTS[d]):
		var sol := Gen.full_grid(rng)
		var cage_of := fence(rng, sol, PLOT_SIZES[d])
		var plots := plots_of(cage_of)
		var sums := PackedInt32Array()
		for p in plots:
			var s := 0
			for i in p:
				s += sol[i]
			sums.append(s)
		var puz := PackedByteArray()
		puz.resize(Gen.CELLS)
		# Numbers written in until the reasoner goes through: each where it
		# stalled least sure, reasoned on from where it stalled (a number
		# written in only ever adds to what was known).
		var rules := with_sums_of_units(plots, sums, int(TIER[d]))
		var cand := PackedInt32Array()
		cand.resize(Gen.CELLS)
		cand.fill(Gen.FULL)
		Gen._tables()
		_propagate(cand, rules[0], rules[1], int(TIER[d]))
		while true:
			var widest := -1
			var most := 1
			for i in Gen.CELLS:
				var n := Gen.popcount(cand[i])
				if n > most:
					most = n
					widest = i
			if widest < 0:
				break
			puz[widest] = sol[widest]
			cand[widest] = 1 << (sol[widest] - 1)
			_propagate(cand, rules[0], rules[1], int(TIER[d]))
		var out := {"puzzle": puz, "solution": sol, "cage_of": cage_of, "sums": sums,
			"plots": plots, "graded": true}
		if best.is_empty() or Gen.givens_of(puz) < Gen.givens_of(best.puzzle):
			best = out
		if Gen.givens_of(puz) <= int(GIVENS_OK[d]):
			break
		if deadline >= 0 and Time.get_ticks_msec() >= deadline:
			best.graded = false
			break
	if int(LOST[d]) > 0:
		_lose_tags(rng, best, int(LOST[d]), int(TIER[d]), deadline)
	return best

## Takes up to `most` tags off, each only while the grid still reasons
## through; the plots of two never lose theirs (a lost pair says too little
## to be any fun), and neither does a plot of one.
static func _lose_tags(rng: RandomNumberGenerator, out: Dictionary, most: int, tier: int, deadline: int) -> void:
	var order: Array = []
	for p in out.plots.size():
		if out.plots[p].size() >= 3:
			order.append(p)
	Gen._shuffle(order, rng)
	var lost := 0
	for p in order:
		if lost >= most:
			break
		if deadline >= 0 and Time.get_ticks_msec() >= deadline:
			break
		var keep: int = out.sums[p]
		out.sums[p] = -1
		if deduce(out.puzzle, out.plots, out.sums, tier):
			lost += 1
		else:
			out.sums[p] = keep

## The grid fenced into plots: each grown from a cell by orthogonal steps to
## a size drawn from `sizes`, never taking a cell whose number the plot holds
## already. A plot left at one cell joins a neighbour that can take it.
static func fence(rng: RandomNumberGenerator, sol: PackedByteArray, sizes: Array) -> PackedInt32Array:
	var cage_of := PackedInt32Array()
	cage_of.resize(Gen.CELLS)
	cage_of.fill(-1)
	var order: Array = []
	for i in Gen.CELLS:
		order.append(i)
	Gen._shuffle(order, rng)
	var masks: Array = []
	var sizes_now: Array = []
	for start in order:
		if cage_of[start] >= 0:
			continue
		var id := masks.size()
		var want: int = sizes[rng.randi_range(0, sizes.size() - 1)]
		var cells: Array = [start]
		var mask := 1 << (sol[start] - 1)
		cage_of[start] = id
		while cells.size() < want:
			var frontier: Array = []
			for c in cells:
				for j in _beside(c):
					if cage_of[j] < 0 and (mask & (1 << (sol[j] - 1))) == 0 and not frontier.has(j):
						frontier.append(j)
			if frontier.is_empty():
				break
			var j: int = frontier[rng.randi_range(0, frontier.size() - 1)]
			cage_of[j] = id
			cells.append(j)
			mask |= 1 << (sol[j] - 1)
		masks.append(mask)
		sizes_now.append(cells.size())
	# Ones join a neighbour that does not hold their number, the smallest.
	for i in Gen.CELLS:
		var id := cage_of[i]
		if sizes_now[id] != 1:
			continue
		var bit := 1 << (sol[i] - 1)
		var into := -1
		for j in _beside(i):
			var other := cage_of[j]
			if (masks[other] & bit) != 0 or sizes_now[other] >= 5:
				continue
			if into < 0 or sizes_now[other] < sizes_now[into]:
				into = other
		if into < 0:
			continue
		cage_of[i] = into
		masks[into] |= bit
		sizes_now[into] += 1
		sizes_now[id] = 0
	# Ids packed down to 0..plots-1, in reading order of each plot's first cell.
	var remap := {}
	for i in Gen.CELLS:
		if not remap.has(cage_of[i]):
			remap[cage_of[i]] = remap.size()
		cage_of[i] = remap[cage_of[i]]
	return cage_of

## Each plot's cells, in reading order (the first is where its tag hangs).
static func plots_of(cage_of: PackedInt32Array) -> Array:
	var plots: Array = []
	for i in cage_of.size():
		var id := cage_of[i]
		while plots.size() <= id:
			plots.append(PackedInt32Array())
		plots[id].append(i)
	return plots

static func _beside(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r := Gen.row_of(i)
	var c := Gen.col_of(i)
	for s in STEPS:
		var rr: int = r + s.y
		var cc: int = c + s.x
		if rr >= 0 and rr < Gen.N and cc >= 0 and cc < Gen.N:
			out.append(rr * Gen.N + cc)
	return out

## Whether the reasoner finishes the grid.
static func deduce(puz: PackedByteArray, plots: Array, sums: PackedInt32Array, tier: int) -> bool:
	return Gen._settled(candidates(puz, plots, sums, tier))

## The candidates the reasoner leaves: a mask a cell, 0 where it broke.
static func candidates(puz: PackedByteArray, plots: Array, sums: PackedInt32Array, tier: int) -> PackedInt32Array:
	Gen._tables()
	var cand := PackedInt32Array()
	cand.resize(Gen.CELLS)
	for i in Gen.CELLS:
		cand[i] = (1 << (puz[i] - 1)) if puz[i] > 0 else Gen.FULL
	var rules := with_sums_of_units(plots, sums, tier)
	_propagate(cand, rules[0], rules[1], tier)
	return cand

## The plots, and past Easy the unit's own sum as a player reckons it: a
## row, column or region adds up to 1 + 2 + ... + N, so the cells of it no
## tagged plot inside it covers add up to what is left, and no number comes
## twice among them. Those cells are one more plot for the reasoner, when
## there are four or fewer. [plots, sums].
static func with_sums_of_units(plots: Array, sums: PackedInt32Array, tier: int) -> Array:
	if tier < Gen.PENCIL:
		return [plots, sums]
	var all := plots.duplicate()
	var all_sums := sums.duplicate()
	var cage_of := PackedInt32Array()
	cage_of.resize(Gen.CELLS)
	for p in plots.size():
		for i in plots[p]:
			cage_of[i] = p
	var whole := Gen.N * (Gen.N + 1) / 2
	for u in Gen.units():
		var inside := {}
		for i in u:
			inside[cage_of[i]] = true
		var left := PackedInt32Array()
		var got := 0
		for p in inside:
			var cells: PackedInt32Array = plots[p]
			var within := true
			for i in cells:
				if not u.has(i):
					within = false
					break
			if within and sums[p] >= 0:
				got += sums[p]
			else:
				for i in cells:
					if u.has(i):
						left.append(i)
		if left.size() >= 1 and left.size() <= 4:
			all.append(left)
			all_sums.append(whole - got)
	return [all, all_sums]

## Sudoku's singles, the plots' sums and (tier allowing) one pencil step at
## a time, until nothing changes. False when the grid breaks.
static func _propagate(cand: PackedInt32Array, plots: Array, sums: PackedInt32Array, tier: int) -> bool:
	while true:
		if not Gen._propagate(cand, PackedInt32Array(), Gen.SINGLES):
			return false
		var changed := false
		for p in plots.size():
			var r := _plot_step(cand, plots[p], sums[p])
			if r < 0:
				return false
			if r > 0:
				changed = true
		if changed:
			continue
		if tier < Gen.PENCIL or not Gen._pencil(cand):
			return true
	return true

## One plot's reckoning: each cell keeps only the numbers some way of filling
## the plot (no number twice, adding up to `sum` when it has a tag) gives it.
## 1 when something was crossed out, 0 when nothing, -1 when nothing fits.
static func _plot_step(cand: PackedInt32Array, cells: PackedInt32Array, sum: int) -> int:
	var n := cells.size()
	if sum < 0:
		# A lost tag: only that no number comes twice, which a settled cell
		# says to the rest of its plot.
		var did_lost := 0
		for i in cells:
			var m := cand[i]
			if m == 0:
				return -1
			if (m & (m - 1)) != 0:
				continue
			for j in cells:
				if j != i and (cand[j] & m) != 0:
					cand[j] &= ~m
					if cand[j] == 0:
						return -1
					did_lost = 1
		return did_lost
	var keep := PackedInt32Array()
	keep.resize(n)
	if not _fill(cand, cells, sum, 0, 0, 0, keep):
		return -1
	var did := 0
	for k in n:
		var i := cells[k]
		if keep[k] != cand[i]:
			cand[i] = keep[k]
			did = 1
	return did

## Every filling of `cells` from `k` on, with `used` the numbers taken and
## `got` their total, marked into `keep`. True when there was one.
static func _fill(cand: PackedInt32Array, cells: PackedInt32Array, sum: int, k: int, used: int,
		got: int, keep: PackedInt32Array) -> bool:
	var n := cells.size()
	if k == n:
		return sum < 0 or got == sum
	var left := n - k - 1
	var m := cand[cells[k]] & ~used
	var any := false
	for d in range(1, Gen.N + 1):
		var bit := 1 << (d - 1)
		if (m & bit) == 0:
			continue
		if sum >= 0:
			# What the cells after this one can still add, at the least and
			# the most: never under the smallest numbers left, never over the
			# largest.
			var rest := sum - got - d
			if rest < left * (left + 1) / 2 or rest > left * (2 * Gen.N - left + 1) / 2:
				continue
		if _fill(cand, cells, sum, k + 1, used | bit, got + d, keep):
			keep[k] |= bit
			any = true
	return any

# --- the banks (content/insane/picket.json, picket_hard.json) ---

## A day as the banks keep it: `puzzle` and `solution` one digit a cell in
## reading order ('.' empty), `plots` each cell's plot id, `sums` each
## plot's tag (-1 lost).
static func to_bank(out: Dictionary) -> Dictionary:
	var p := ""
	var s := ""
	for i in Gen.CELLS:
		p += "." if out.puzzle[i] == 0 else str(out.puzzle[i])
		s += str(out.solution[i])
	return {"puzzle": p, "solution": s, "plots": Array(out.cage_of), "sums": Array(out.sums)}

## The bank's day back as generate hands one over; {} for an entry that does
## not hold together. The phone checks what is cheap -- a legal answer,
## givens and tags that agree with it, plots that never hold a number twice
## -- and trusts the miner's proof that reasoning finishes it.
static func from_bank(board: Dictionary) -> Dictionary:
	var p := String(board.get("puzzle", ""))
	var s := String(board.get("solution", ""))
	var cages: Array = board.get("plots", [])
	var tags: Array = board.get("sums", [])
	if p.length() != 81 or s.length() != 81 or cages.size() != 81:
		return {}
	Gen.use(9)
	var puz := PackedByteArray()
	var sol := PackedByteArray()
	var cage_of := PackedInt32Array()
	puz.resize(81)
	sol.resize(81)
	cage_of.resize(81)
	for i in 81:
		puz[i] = 0 if p[i] == "." else int(p[i])
		sol[i] = int(s[i])
		cage_of[i] = int(cages[i])
		if sol[i] < 1 or sol[i] > 9 or (puz[i] != 0 and puz[i] != sol[i]):
			return {}
		if cage_of[i] < 0 or cage_of[i] >= tags.size():
			return {}
	for u in Gen.units():
		var mask := 0
		for i in u:
			mask |= 1 << (sol[i] - 1)
		if mask != Gen.FULL:
			return {}
	var plots := plots_of(cage_of)
	if plots.size() != tags.size():
		return {}
	var sums := PackedInt32Array()
	for k in plots.size():
		var cells: PackedInt32Array = plots[k]
		var mask := 0
		var got := 0
		for i in cells:
			var bit := 1 << (sol[i] - 1)
			if cells.is_empty() or (mask & bit) != 0:
				return {}
			mask |= bit
			got += sol[i]
		var tag := int(tags[k])
		if tag >= 0 and tag != got:
			return {}
		sums.append(tag)
	return {"puzzle": puz, "solution": sol, "cage_of": cage_of, "sums": sums, "plots": plots,
		"graded": true}
