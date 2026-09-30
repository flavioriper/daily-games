extends RefCounted

## Queens solved by hand, the way a player does it, so a court can be graded
## by what it asks of the player rather than by whether it is unique.
##
## Three rungs, each everything below it plus one idea:
##
## 1. **Singles.** A row or a column with one cell left takes its queen
##    there; a patch with as many cells left as queens to seat takes them
##    all. Seating a queen crosses her row, her column, her eight neighbours
##    and, once it is full, her patch. This is the chain the players who
##    wrote in complained about: a court that opens on a single and whose
##    every queen hands out the next one.
## 2. **Bands and reach.** Pigeonholes over a run of rows (or columns): when
##    the patches lying wholly inside the run want as many queens as the run
##    has rows to fill, every other patch is crossed out of it; and when the
##    patches that reach into the run can only just fill it, they are
##    crossed out everywhere else. Then reach: a cell whose queen would cross
##    out the last cell of some row, column or patch is crossed itself.
## 3. **Suppose.** Seat a queen on a cell in your head, follow rungs 1 and 2,
##    and if the court breaks the cell is crossed. The careful player's last
##    resort, never a guess: a court this finishes has exactly one answer.
##
## A patch usually takes one queen; Insane's misty patches take two
## (`quota`), and everything here counts with that. Spec:
## docs/superpowers/specs/2026-09-30-queens-polish-design.md, section 0.

const SINGLES := 1
const BANDS := 2
const SUPPOSE := 3

class Court:
	var n := 0
	var region := PackedInt32Array()   # cell -> patch
	var quota := PackedInt32Array()    # patch -> queens it takes
	var cand := PackedByteArray()      # cell -> 1 while a queen may still sit there
	var queen := PackedByteArray()     # cell -> 1 when a queen sits there
	var row_has := PackedByteArray()
	var col_has := PackedByteArray()
	var left := PackedInt32Array()     # patch -> queens still to seat
	var broken := false
	var seated := 0
	## Suppositions tried, for the grade's work.
	var probes := 0
	## How many times the player had to think: bands or reach found a cross
	## because no single was on offer; and of those, how many needed a band
	## over several lines at once, the one players find hard.
	var thinks := 0
	var wide := 0

	func dup() -> Court:
		var c := Court.new()
		c.n = n
		c.region = region
		c.quota = quota
		c.cand = cand.duplicate()
		c.queen = queen.duplicate()
		c.row_has = row_has.duplicate()
		c.col_has = col_has.duplicate()
		c.left = left.duplicate()
		c.broken = broken
		c.seated = seated
		return c

	func total() -> int:
		var t := 0
		for q in quota:
			t += q
		return t

	## Cells neither seated nor crossed: what is still undecided.
	func open_cells() -> int:
		var k := 0
		for i in n * n:
			if cand[i]:
				k += 1
		return k

	func solved() -> bool:
		return not broken and seated == n

	func seat(i: int) -> void:
		if not cand[i]:
			broken = true
			return
		var r := i / n
		var c := i % n
		var g := region[i]
		queen[i] = 1
		cand[i] = 0
		seated += 1
		row_has[r] = 1
		col_has[c] = 1
		left[g] -= 1
		if left[g] < 0:
			broken = true
			return
		for k in n:
			cand[r * n + k] = 0
			cand[k * n + c] = 0
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var y: int = r + dy
				var x: int = c + dx
				if x >= 0 and y >= 0 and x < n and y < n:
					cand[y * n + x] = 0
		if left[g] == 0:
			for k in n * n:
				if region[k] == g:
					cand[k] = 0

	## Whether the court can still be finished, by counting: every open row and
	## column has a cell, every patch has cells enough, spread over rows and
	## columns enough, for the queens it still wants.
	func check() -> bool:
		if broken:
			return false
		var m := quota.size()
		var cnt := PackedInt32Array()
		cnt.resize(m)
		var rows := PackedInt32Array()
		rows.resize(m)
		var cols := PackedInt32Array()
		cols.resize(m)
		var row_any := PackedByteArray()
		row_any.resize(n)
		var col_any := PackedByteArray()
		col_any.resize(n)
		for i in n * n:
			if not cand[i]:
				continue
			var g := region[i]
			cnt[g] += 1
			rows[g] |= 1 << (i / n)
			cols[g] |= 1 << (i % n)
			row_any[i / n] = 1
			col_any[i % n] = 1
		for k in n:
			if (not row_has[k] and not row_any[k]) or (not col_has[k] and not col_any[k]):
				broken = true
				return false
		for g in m:
			if left[g] <= 0:
				continue
			if cnt[g] < left[g] or _bits(rows[g]) < left[g] or _bits(cols[g]) < left[g]:
				broken = true
				return false
		return true

	static func _bits(v: int) -> int:
		var k := 0
		while v:
			v &= v - 1
			k += 1
		return k

	## Rung 1: seats every single it finds. True when it seated one.
	func singles() -> bool:
		var moved := false
		for r in n:
			if row_has[r]:
				continue
			var only := -1
			var k := 0
			for c in n:
				if cand[r * n + c]:
					k += 1
					only = r * n + c
			if k == 1:
				seat(only)
				moved = true
				if broken:
					return true
		for c in n:
			if col_has[c]:
				continue
			var only := -1
			var k := 0
			for r in n:
				if cand[r * n + c]:
					k += 1
					only = r * n + c
			if k == 1:
				seat(only)
				moved = true
				if broken:
					return true
		for g in quota.size():
			if left[g] <= 0:
				continue
			var cells: Array = []
			for i in n * n:
				if cand[i] and region[i] == g:
					cells.append(i)
			if cells.size() == left[g]:
				for i in cells:
					seat(i)
					if broken:
						return true
				moved = true
		return moved

	## Rung 2, the bands `w0` to `w1` lines wide, rows then columns. True
	## when it crossed a cell.
	func bands(w0 := 1, w1 := 99) -> bool:
		return _bands(true, w0, w1) or _bands(false, w0, w1)

	func _bands(by_row: bool, w0: int, w1: int) -> bool:
		var m := quota.size()
		var lo := PackedInt32Array()
		lo.resize(m)
		lo.fill(n)
		var hi := PackedInt32Array()
		hi.resize(m)
		hi.fill(-1)
		for i in n * n:
			if not cand[i]:
				continue
			var g := region[i]
			var line := i / n if by_row else i % n
			lo[g] = mini(lo[g], line)
			hi[g] = maxi(hi[g], line)
		var has := row_has if by_row else col_has
		var moved := false
		for a in n:
			var need := 0
			for b in range(a, n):
				if not has[b]:
					need += 1
				if need == 0 or need < w0:
					continue
				if need > w1:
					break
				var inside := 0
				var reach := 0
				for g in m:
					if left[g] <= 0 or hi[g] < 0:
						continue
					if lo[g] >= a and hi[g] <= b:
						inside += left[g]
					if hi[g] >= a and lo[g] <= b:
						reach += left[g]
				if inside > need or reach < need:
					broken = true
					return true
				if inside == need:
					for i in n * n:
						if not cand[i]:
							continue
						var line := i / n if by_row else i % n
						var g := region[i]
						if line >= a and line <= b and not (lo[g] >= a and hi[g] <= b):
							cand[i] = 0
							moved = true
				if reach == need:
					for i in n * n:
						if not cand[i]:
							continue
						var line := i / n if by_row else i % n
						var g := region[i]
						if (line < a or line > b) and hi[g] >= a and lo[g] <= b:
							cand[i] = 0
							moved = true
				if moved:
					return true
		return false

	## Rung 2, reach: a cell whose queen would leave some open row, column or
	## patch without room is crossed. True when it crossed one.
	func reach() -> bool:
		var m := quota.size()
		var row_n := PackedInt32Array()
		row_n.resize(n)
		var col_n := PackedInt32Array()
		col_n.resize(n)
		var reg_n := PackedInt32Array()
		reg_n.resize(m)
		for i in n * n:
			if cand[i]:
				row_n[i / n] += 1
				col_n[i % n] += 1
				reg_n[region[i]] += 1
		var moved := false
		for i in n * n:
			if not cand[i]:
				continue
			var r := i / n
			var c := i % n
			var g := region[i]
			var kill := PackedByteArray()
			kill.resize(n * n)
			for k in n:
				kill[r * n + k] = 1
				kill[k * n + c] = 1
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var y: int = r + dy
					var x: int = c + dx
					if x >= 0 and y >= 0 and x < n and y < n:
						kill[y * n + x] = 1
			if left[g] == 1:
				for k in n * n:
					if region[k] == g:
						kill[k] = 1
			var rn := row_n.duplicate()
			var cn := col_n.duplicate()
			var gn := reg_n.duplicate()
			for k in n * n:
				if kill[k] and cand[k]:
					rn[k / n] -= 1
					cn[k % n] -= 1
					gn[region[k]] -= 1
			var bad := false
			for k in n:
				if (k != r and not row_has[k] and rn[k] <= 0) or (k != c and not col_has[k] and cn[k] <= 0):
					bad = true
					break
			if not bad:
				for h in m:
					var want := left[h] - (1 if h == g else 0)
					if want > 0 and gn[h] < want:
						bad = true
						break
			if bad:
				cand[i] = 0
				moved = true
				row_n[r] -= 1
				col_n[c] -= 1
				reg_n[g] -= 1
		return moved

	## Runs rungs up to `rung` (SINGLES or BANDS) until nothing moves.
	func settle(rung: int) -> void:
		while not broken:
			if not check():
				return
			if singles():
				continue
			if rung < BANDS:
				return
			if bands(1, 1) or reach():
				thinks += 1
				continue
			if bands(2):
				thinks += 1
				wide += 1
				continue
			return

	## Rung 3: one supposition that breaks the court. True when it crossed a
	## cell.
	func suppose() -> bool:
		for i in n * n:
			if not cand[i]:
				continue
			probes += 1
			var t := dup()
			t.seat(i)
			t.settle(BANDS)
			if t.broken:
				cand[i] = 0
				return true
			if t.solved():
				# The only way forward was this queen: seat her.
				pass
		return false

	## Everything up to `rung`.
	func solve(rung: int) -> void:
		settle(mini(rung, BANDS))
		if rung < SUPPOSE:
			return
		while not broken and seated < n:
			if not suppose():
				return
			settle(BANDS)

static func court(region: PackedInt32Array, n: int, quota: PackedInt32Array) -> Court:
	var c := Court.new()
	c.n = n
	c.region = region
	c.quota = quota
	c.cand.resize(n * n)
	c.cand.fill(1)
	c.queen.resize(n * n)
	c.row_has.resize(n)
	c.col_has.resize(n)
	c.left = quota.duplicate()
	return c

## How many queens the opening court hands out by singles alone, before a
## single cross is laid: the first link of the chain.
static func opening_singles(region: PackedInt32Array, n: int, quota: PackedInt32Array) -> int:
	var c := court(region, n, quota)
	var k := 0
	for r in n:
		var cnt := 0
		for x in n:
			cnt += c.cand[r * n + x]
		if cnt == 1:
			k += 1
	var sizes := PackedInt32Array()
	sizes.resize(quota.size())
	for i in n * n:
		sizes[region[i]] += 1
	for g in quota.size():
		if sizes[g] == quota[g]:
			k += quota[g]
	return k

## The grade of a court, every rung measured from a fresh court:
## `open1` / `open2` the cells singles alone, and bands and reach, leave
## undecided; `solved` whether suppositions finish it (so it is unique and
## fair); `probes` the suppositions that took; `first` the singles on offer
## at the start after one pass of bands and reach -- what a player finds
## before any real thinking.
static func grade(region: PackedInt32Array, n: int, quota: PackedInt32Array, deep := true) -> Dictionary:
	var c1 := court(region, n, quota)
	c1.solve(SINGLES)
	var c2 := court(region, n, quota)
	c2.solve(BANDS)
	var out := {"open1": c1.open_cells() if not c1.solved() else 0,
		"open2": c2.open_cells() if not c2.solved() else 0,
		"solved1": c1.solved(), "solved2": c2.solved(), "solved": c2.solved(), "probes": 0,
		"opening": opening_singles(region, n, quota), "thinks": c2.thinks, "wide": c2.wide}
	if deep and not c2.solved() and not c2.broken:
		var c3 := court(region, n, quota)
		c3.solve(SUPPOSE)
		out.solved = c3.solved()
		out.probes = c3.probes
	return out

## The queens a finished court seats, row -> column, or empty.
static func answer(region: PackedInt32Array, n: int, quota: PackedInt32Array) -> PackedInt32Array:
	var c := court(region, n, quota)
	c.solve(SUPPOSE)
	var out := PackedInt32Array()
	if not c.solved():
		return out
	out.resize(n)
	for i in n * n:
		if c.queen[i]:
			out[i / n] = i % n
	return out
