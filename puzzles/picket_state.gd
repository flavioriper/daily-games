extends "res://puzzles/sudoku_state.gd"

## Picket Sums' rules: Sudoku's (puzzles/sudoku_state.gd), with the grid
## fenced into plots. A plot's numbers never repeat and add up to its tag;
## on Insane some tags are lost, and those plots only never repeat.
##
## Everything else -- the pencil, undo, the hint, what is wrong -- is
## Sudoku's own. What this adds is read off the board on every ask, never
## stored: which plot a cell is in, what a plot adds up to now, and whether
## it is standing (full and right), over (it cannot come true any more) or
## open.
## Spec: docs/superpowers/specs/2026-10-22-picket-design.md.

const PG = preload("res://puzzles/picket_gen.gd")

## Three bulbs on the mini, Sudoku's one on the nine.
const PICKET_HINTS := [3, 3, 1, 1]

## Each cell's plot.
var cage_of := PackedInt32Array()
## Each plot's cells in reading order: the first is where the tag hangs.
var plots: Array = []
## Each plot's tag, -1 for a lost one (Insane).
var sums := PackedInt32Array()

func setup(rng: RandomNumberGenerator, difficulty: int, bank_step := 0) -> void:
	band = clampi(difficulty, 0, 3)
	var out: Dictionary = {}
	# Hard and Insane are mined on the Mac (tools/insane/picket*_ladder.gd):
	# a nine fenced and reasoned through takes too long at board open on a
	# phone. An empty bank, or an entry that does not hold together, deals a
	# live one under the generator's budget.
	if band >= 2:
		var bank := "picket" if band == 3 else "picket_hard"
		out = PG.from_bank(InsaneBank.pick(bank, bank_step))
		if out.is_empty() and InsaneBank.size(bank) > 0:
			push_warning("Picket Sums: a banked day did not hold together; dealing a live one")
	if out.is_empty():
		out = PG.generate(rng, band)
	hills = PackedInt32Array()
	ruled = {}
	sol = out.solution
	given = out.puzzle
	grid = given.duplicate()
	target = given.count(0)
	cage_of = out.cage_of
	plots = out.plots
	sums = out.sums
	notes = PackedInt32Array()
	notes.resize(Gen.CELLS)
	history = []
	hints_left = int(PICKET_HINTS[band])

func plot_of(i: int) -> int:
	return cage_of[i]

## Whether a plot has lost its tag.
func lost(p: int) -> bool:
	return sums[p] < 0

func lost_count() -> int:
	return Array(sums).count(-1)

## What a plot's numbers add up to now.
func sum_now(p: int) -> int:
	var got := 0
	for i in plots[p]:
		got += grid[i]
	return got

func plot_full(p: int) -> bool:
	for i in plots[p]:
		if grid[i] == 0:
			return false
	return true

## 1 when every cell of the plot holds a number, none twice, adding up to
## the tag (any total, on a lost one); -1 when what is there cannot come
## true (a number twice, over the tag, or full and short of it); else 0.
## Read off the player's own numbers, never the answer.
func plot_standing(p: int) -> int:
	var mask := 0
	for i in plots[p]:
		var d := grid[i]
		if d == 0:
			continue
		var bit := 1 << (d - 1)
		if mask & bit:
			return -1
		mask |= bit
	var got := sum_now(p)
	if sums[p] >= 0 and got > sums[p]:
		return -1
	if not plot_full(p):
		return 0
	return 1 if sums[p] < 0 or got == sums[p] else -1

## Every set of `k` different numbers 1..`top` adding up to `total`, each
## smallest first, the sets in order: what a plot of `k` cells tagged
## `total` can hold (the plot card's sets, the killer player's table).
static func sets_for(k: int, total: int, top: int) -> Array:
	var out: Array = []
	_sets(k, total, 1, top, PackedInt32Array(), out)
	return out

static func _sets(k: int, total: int, lo: int, top: int, got: PackedInt32Array, out: Array) -> void:
	if k == 0:
		if total == 0:
			out.append(got.duplicate())
		return
	for d in range(lo, top + 1):
		# the rest are bigger than d, so the smallest they can add is known
		if d * k + k * (k - 1) / 2 > total:
			break
		got.append(d)
		_sets(k - 1, total - d, d + 1, top, got, out)
		got.remove_at(got.size() - 1)

## The sets plot `p` can still hold: those with every number already in
## it. [] for a lost tag, or a plot holding a number twice.
func sets_left(p: int) -> Array:
	if sums[p] < 0:
		return []
	var have := 0
	for i in plots[p]:
		var d := grid[i]
		if d == 0:
			continue
		if have & (1 << d):
			return []
		have |= 1 << d
	var out: Array = []
	for set: PackedInt32Array in sets_for(plots[p].size(), sums[p], Gen.N):
		var bits := 0
		for d in set:
			bits |= 1 << d
		if bits & have == have:
			out.append(set)
	return out

## One standing a plot, for the board to diff before and after a move.
func standings() -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in plots.size():
		out.append(plot_standing(p))
	return out

## Sudoku's clashes, and a number twice in one plot.
func clashes() -> Dictionary:
	var out: Dictionary = super()
	for cells in plots:
		for a in cells.size():
			var i: int = cells[a]
			if grid[i] == 0:
				continue
			for b in range(a + 1, cells.size()):
				var j: int = cells[b]
				if grid[j] == grid[i]:
					out[i] = true
					out[j] = true
	return out

## Sudoku's hint, but a cell's candidates also leave out what its plot holds.
func hint() -> int:
	if hints_left <= 0:
		return -1
	var best := -1
	var best_n := Gen.N + 1
	for i in Gen.CELLS:
		if grid[i] == sol[i]:
			continue
		var m := Gen.FULL
		for j in Gen.peers_of(i):
			if grid[j] > 0:
				m &= ~(1 << (grid[j] - 1))
		for j in plots[cage_of[i]]:
			if j != i and grid[j] > 0:
				m &= ~(1 << (grid[j] - 1))
		var n: int = Gen.popcount(m)
		if n < best_n:
			best_n = n
			best = i
	if best < 0:
		return -1
	var entry := {"cell": best, "prev": int(grid[best]), "notes": int(notes[best]),
		"struck": PackedInt32Array(), "bit": 0}
	_write(best, int(sol[best]), entry)
	history.append(entry)
	hints_left -= 1
	return best

## Sudoku's write, and the number struck off its plot's pencil marks too.
func _write(i: int, d: int, entry: Dictionary) -> void:
	super(i, d, entry)
	var bit := 1 << (d - 1)
	var struck: PackedInt32Array = entry.struck
	for j in plots[cage_of[i]]:
		if j != i and (notes[j] & bit) != 0 and not struck.has(j):
			notes[j] &= ~bit
			struck.append(j)
	entry.struck = struck
