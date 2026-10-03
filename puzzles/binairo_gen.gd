extends RefCounted

## Binairo / Takuzu generator and solver.
##
## Grid representation: Array of rows, each an Array of int, where -1 is empty.
## Rules enforced: no three of the same in a line, and each line balanced
## 50/50. Two lines may be alike: that rule was dropped on 2026-10-03, with
## the search it needed to be of any use to a player.
##
## Generation is the build-then-strip shape: make a full valid solution, then
## remove clues one at a time, keeping a removal only while `deduce` still
## finishes the board. `deduce` never searches and never guesses: it only
## takes steps a player takes (see "deduction" below), so a board that ships
## is solved by reasoning alone, and one answer is all it can have. The
## result is minimal by construction -- a clue fewer only ever lets `deduce`
## see less, so a clue proven load-bearing at any point stays load-bearing.
##
## Signs (2026-09-23): a board may also carry signs between side-by-side
## cells, Vector4i(r, c, dir, same) -- dir 0 joins (r, c) to the cell on its
## right and 1 to the cell below; same 1 is "=" (the two match) and 0 is "x"
## (they differ). They are read off the solution before the clues are
## stripped, so the strip leans on them as it does on a clue, and leaves far
## fewer clues than a board without.
##
## Liars (2026-09-29): Insane's board shows one sign that lies -- its kind is
## the opposite of the truth, and nothing marks which. `generate_liar` builds
## those (see its comment). Since 2026-10-03 the liar is caught by deduction
## too, which made the board cheap enough to build on the phone: the mined
## bank (content/insane/binairo.json) and its ladder went.
##
## `solve_count` is the old search. Nothing in the game calls it now; the
## suite does, to check from outside that a deduced board has one answer.

static func solve_count(grid: Array, limit: int, signs: Array = []) -> int:
	var n: int = grid.size()
	var g: Array = []
	for r in n:
		g.append((grid[r] as Array).duplicate())
	var by_cell := _signs_by_cell(signs, n)
	# Reject clue sets that already break a rule.
	for r in n:
		for c in n:
			if g[r][c] != -1 and not _partial_ok(g, r, c, n, by_cell):
				return 0
	return _search(g, n, limit, signs, by_cell)

## `sign_count` signs are laid on distinct edges picked at random, each
## reading the solution, before any clue is taken away. `tier` is how far the
## player is asked to reason (BASIC or LINES, see `deduce`).
static func generate(rng: RandomNumberGenerator, n: int, min_clues: int = 0, sign_count: int = 0, tier: int = LINES) -> Dictionary:
	assert(n % 2 == 0, "Binairo needs an even board size")
	var sol: Array = _random_solution(rng, n)
	var signs: Array = _pick_signs(rng, sol, n, sign_count)
	var lines := valid_lines(n)
	var puzzle: Array = []
	for r in n:
		puzzle.append((sol[r] as Array).duplicate())

	var cells: Array = []
	for r in n:
		for c in n:
			cells.append(r * n + c)
	_shuffle(cells, rng)

	var clues: int = n * n
	for idx in cells:
		if min_clues > 0 and clues <= min_clues:
			break
		var r: int = idx / n
		var c: int = idx % n
		var kept = puzzle[r][c]
		puzzle[r][c] = -1
		if deduce(puzzle, signs, tier, lines).solved:
			clues -= 1
		else:
			puzzle[r][c] = kept
	return {"solution": sol, "puzzle": puzzle, "clues": clues, "signs": signs, "liar": -1}

## An Insane board: a size-`n` board with `sign_count` signs, exactly one of
## which lies, stripped to minimal clues (a `min_clues` floor above 0 stops
## the strip early, as in generate). Same dict as generate(), with `signs` as
## shown (the liar's kind is the false one) and "liar" its index.
##
## The board is sound when the liar can be caught and the rest then solved,
## both by deduction (`liar_caught`). It starts sound on the full grid and
## every strip step keeps it so; minimal by construction as generate()'s is.
static func generate_liar(rng: RandomNumberGenerator, n: int = 10, sign_count: int = 12, min_clues: int = 0) -> Dictionary:
	assert(n % 2 == 0, "Binairo needs an even board size")
	assert(sign_count > 0, "a liar needs a sign to lie")
	var sol: Array = _random_solution(rng, n)
	var signs: Array = _pick_signs(rng, sol, n, sign_count)
	var liar: int = rng.randi_range(0, signs.size() - 1)
	signs[liar] = flip_sign(signs[liar])
	var lines := valid_lines(n)
	var puzzle: Array = []
	for r in n:
		puzzle.append((sol[r] as Array).duplicate())

	var cells: Array = []
	for r in n:
		for c in n:
			cells.append(r * n + c)
	_shuffle(cells, rng)

	var clues: int = n * n
	for idx in cells:
		if min_clues > 0 and clues <= min_clues:
			break
		var r: int = idx / n
		var c: int = idx % n
		var kept = puzzle[r][c]
		puzzle[r][c] = -1
		if liar_caught(puzzle, signs, liar, lines):
			clues -= 1
		else:
			puzzle[r][c] = kept
	return {"solution": sol, "puzzle": puzzle, "clues": clues, "signs": signs, "liar": liar}

## Whether `grid` with `signs` (as shown) is a sound liar board whose liar is
## sign `liar`, by deduction alone. The rules never lie, so the player works
## by the rules and trusts no sign until one is caught out: the rules alone
## must reach both ends of the liar (which then reads broken -- and only it
## can, every other sign being true), and from there the board must finish
## with every sign read the right way round.
static func liar_caught(grid: Array, signs: Array, liar: int, lines := PackedInt32Array()) -> bool:
	if liar < 0 or liar >= signs.size():
		return false
	var by_rules: Array = deduce(grid, [], LINES, lines).grid
	if not sign_broken(by_rules, signs[liar]):
		return false
	return deduce(by_rules, with_flipped(signs, liar), LINES, lines).solved

## The liar a board's signs imply, found without being told, the way the
## player finds it: -1 unless the rules alone break exactly one sign and the
## board then finishes by deduction, else that sign's index. For proving a
## board, not for play.
static func find_liar(grid: Array, signs: Array) -> int:
	var by_rules: Array = deduce(grid, [], LINES).grid
	var found := -1
	for i in signs.size():
		if sign_broken(by_rules, signs[i]):
			if found != -1:
				return -1
			found = i
	if found == -1 or not deduce(by_rules, with_flipped(signs, found), LINES).solved:
		return -1
	return found

## Sign `s` telling the other story: "=" becomes "x" and back.
static func flip_sign(s: Vector4i) -> Vector4i:
	return Vector4i(s.x, s.y, s.z, 0 if s.w == 1 else 1)

## A copy of `signs` with sign `i` flipped; `signs` itself is untouched.
static func with_flipped(signs: Array, i: int) -> Array:
	var out: Array = signs.duplicate()
	out[i] = flip_sign(out[i])
	return out

## `count` distinct edges, each signed from the solution. Every edge of the
## board is a candidate, shuffled with the board's own rng so a day's signs
## are as fixed as its clues.
static func _pick_signs(rng: RandomNumberGenerator, sol: Array, n: int, count: int) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var edges: Array = []
	for r in n:
		for c in n:
			if c + 1 < n:
				edges.append(Vector3i(r, c, 0))
			if r + 1 < n:
				edges.append(Vector3i(r, c, 1))
	_shuffle(edges, rng)
	for i in mini(count, edges.size()):
		var e: Vector3i = edges[i]
		var other: Vector2i = sign_other(Vector4i(e.x, e.y, e.z, 0))
		out.append(Vector4i(e.x, e.y, e.z, 1 if sol[e.x][e.y] == sol[other.x][other.y] else 0))
	return out

## The second cell a sign joins, as (r, c).
static func sign_other(s: Vector4i) -> Vector2i:
	return Vector2i(s.x, s.y + 1) if s.z == 0 else Vector2i(s.x + 1, s.y)

## Whether sign `s` is broken on `g`: both its cells filled and not agreeing
## with it. A sign with an empty end is never broken.
static func sign_broken(g: Array, s: Vector4i) -> bool:
	var o := sign_other(s)
	var a: int = g[s.x][s.y]
	var b: int = g[o.x][o.y]
	if a == -1 or b == -1:
		return false
	return (a == b) != (s.w == 1)

## Every sign held on a grid; for a complete grid this is the signs' rule.
static func signs_ok(g: Array, signs: Array) -> bool:
	for s in signs:
		if sign_broken(g, s):
			return false
	return true

static func is_valid_complete(g: Array) -> bool:
	var n: int = g.size()
	if n == 0 or n % 2 != 0:
		return false
	var half: int = n / 2
	for r in n:
		if (g[r] as Array).size() != n:
			return false
		for c in n:
			if g[r][c] != 0 and g[r][c] != 1:
				return false
	# Balance.
	for i in n:
		var rc := 0
		var cc := 0
		for j in n:
			rc += int(g[i][j])
			cc += int(g[j][i])
		if rc != half or cc != half:
			return false
	# No three in a line.
	for r in n:
		for c in n - 2:
			if g[r][c] == g[r][c + 1] and g[r][c + 1] == g[r][c + 2]:
				return false
	for c in n:
		for r in n - 2:
			if g[r][c] == g[r + 1][c] and g[r + 1][c] == g[r + 2][c]:
				return false
	return true

# --- deduction ---

## How far `deduce` reasons. BASIC is the four steps the tutorial teaches:
## two alike side by side close off both ends, a gap between two alike takes
## the other, a line with half of one symbol fills with the other, and a sign
## with one end known gives its other end. LINES adds reading one whole line
## at a time: whatever every way of finishing that line (never three alike,
## half and half, its own signs kept) agrees on. Nothing looks at two lines
## at once and nothing tries a value to see what happens further off.
const BASIC := 1
const LINES := 2

## Every way to fill a line of `n`, as bit masks (bit i set: cell i a moon).
static func valid_lines(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var half: int = n / 2
	for m in 1 << n:
		var ones := 0
		var ok := true
		for i in n:
			var b: int = (m >> i) & 1
			ones += b
			if i >= 2 and b == ((m >> (i - 1)) & 1) and b == ((m >> (i - 2)) & 1):
				ok = false
				break
		if ok and ones == half:
			out.append(m)
	return out

## Fills `grid` as far as reasoning at `tier` goes: {"grid": the grid it
## reached, "solved": whether that is the finished board}. Every step is
## sound, so a solved grid is the only answer the clues and signs allow.
## `lines` is valid_lines(n), passed by a caller that asks many times.
static func deduce(grid: Array, signs: Array, tier: int = LINES, lines := PackedInt32Array()) -> Dictionary:
	var n: int = grid.size()
	var g := _flat(grid)
	var in_line: Array = []
	if tier >= LINES:
		if lines.is_empty():
			lines = valid_lines(n)
		in_line = _signs_in_lines(signs, n)
	while true:
		var k := _sweep_basic(g, g, n, signs)
		if k == 0 and tier >= LINES:
			k = _sweep_lines(g, g, n, lines, in_line)
		if k == 0:
			break
	var out: Array = []
	for r in n:
		var row: Array = []
		for c in n:
			row.append(g[r * n + c])
		out.append(row)
	return {"grid": out, "solved": not g.has(-1) and is_valid_complete(out) and signs_ok(out, signs)}

## The empty cells one step of reasoning fills on `grid` as it stands, as
## Vector3i(r, c, value): the BASIC steps when any applies, else one line
## read whole. Each reads the grid given and nothing another step found, so
## every cell listed can be explained from what is on the board. For a hint.
static func deducible(grid: Array, signs: Array) -> Array[Vector3i]:
	var n: int = grid.size()
	var src := _flat(grid)
	var dst := src.duplicate()
	if _sweep_basic(src, dst, n, signs) == 0:
		_sweep_lines(src, dst, n, valid_lines(n), _signs_in_lines(signs, n))
	var out: Array[Vector3i] = []
	for i in n * n:
		if src[i] == -1 and dst[i] != -1:
			out.append(Vector3i(i / n, i % n, dst[i]))
	return out

static func _flat(grid: Array) -> PackedInt32Array:
	var n: int = grid.size()
	var g := PackedInt32Array()
	g.resize(n * n)
	for r in n:
		for c in n:
			g[r * n + c] = grid[r][c]
	return g

## Each line's own signs -- the ones between two of its cells -- as a flat
## run of (i, same) pairs joining cell i of the line to cell i + 1. Rows
## first, then columns, as the sweeps number them.
static func _signs_in_lines(signs: Array, n: int) -> Array:
	var out: Array = []
	for i in 2 * n:
		out.append(PackedInt32Array())
	for s: Vector4i in signs:
		var line: PackedInt32Array = out[s.x] if s.z == 0 else out[n + s.y]
		line.append(s.y if s.z == 0 else s.x)
		line.append(s.w)
		out[s.x if s.z == 0 else n + s.y] = line
	return out

## One pass of the BASIC steps over every sign and line, reading `src` and
## writing `dst` (the same array when the caller wants each step to see the
## last). Returns how many cells it filled.
static func _sweep_basic(src: PackedInt32Array, dst: PackedInt32Array, n: int, signs: Array) -> int:
	var changed := 0
	var half: int = n / 2
	for s: Vector4i in signs:
		var a: int = s.x * n + s.y
		var b: int = a + (1 if s.z == 0 else n)
		var va := src[a]
		var vb := src[b]
		if va == -1 and vb != -1 and dst[a] == -1:
			dst[a] = vb if s.w == 1 else 1 - vb
			changed += 1
		elif vb == -1 and va != -1 and dst[b] == -1:
			dst[b] = va if s.w == 1 else 1 - va
			changed += 1
	for line in 2 * n:
		var start: int = line * n if line < n else line - n
		var step: int = 1 if line < n else n
		var c0 := 0
		var c1 := 0
		for i in n:
			var v := src[start + i * step]
			if v == 0:
				c0 += 1
			elif v == 1:
				c1 += 1
		if c0 + c1 == n:
			continue
		var fill := 1 if c0 == half else (0 if c1 == half else -1)
		for i in n:
			var at: int = start + i * step
			var v := src[at]
			if v == -1:
				var to := fill
				if to == -1 and i >= 1 and i + 1 < n and src[at - step] != -1 and src[at - step] == src[at + step]:
					to = 1 - src[at - step]
				if to != -1 and dst[at] == -1:
					dst[at] = to
					changed += 1
			elif i + 1 < n and src[at + step] == v:
				if i >= 1 and src[at - step] == -1 and dst[at - step] == -1:
					dst[at - step] = 1 - v
					changed += 1
				if i + 2 < n and src[at + 2 * step] == -1 and dst[at + 2 * step] == -1:
					dst[at + 2 * step] = 1 - v
					changed += 1
	return changed

## One pass of the LINES step: each unfinished line takes whatever all of
## its possible fillings agree on. Same `src`/`dst` and return as above.
static func _sweep_lines(src: PackedInt32Array, dst: PackedInt32Array, n: int, lines: PackedInt32Array, in_line: Array) -> int:
	var changed := 0
	var all: int = (1 << n) - 1
	for line in 2 * n:
		var start: int = line * n if line < n else line - n
		var step: int = 1 if line < n else n
		var known := 0
		var value := 0
		for i in n:
			var v := src[start + i * step]
			if v != -1:
				known |= 1 << i
				value |= v << i
		if known == all:
			continue
		var pairs: PackedInt32Array = in_line[line]
		var ones := all
		var zeros := all
		for m in lines:
			if (m & known) != value:
				continue
			var kept := true
			for p in range(0, pairs.size(), 2):
				# Differing ends under "=", or matching ends under "x".
				if (((m >> pairs[p]) ^ (m >> (pairs[p] + 1))) & 1) == pairs[p + 1]:
					kept = false
					break
			if kept:
				ones &= m
				zeros &= ~m
		for i in n:
			var bit: int = 1 << i
			var at: int = start + i * step
			if (known & bit) != 0 or dst[at] != -1 or (ones & zeros & bit) != 0:
				continue
			if (ones & bit) != 0:
				dst[at] = 1
				changed += 1
			elif (zeros & bit) != 0:
				dst[at] = 0
				changed += 1
	return changed

# --- internals ---

## Each cell's signs, indexed r * n + c, so the solver's check at a cell
## reads only the signs that touch it. Empty when the board has none.
static func _signs_by_cell(signs: Array, n: int) -> Array:
	if signs.is_empty():
		return []
	var out: Array = []
	out.resize(n * n)
	for i in n * n:
		out[i] = []
	for s in signs:
		var o := sign_other(s)
		out[s.x * n + s.y].append(s)
		out[o.x * n + o.y].append(s)
	return out

static func _search(g: Array, n: int, limit: int, signs: Array = [], by_cell: Array = []) -> int:
	var br := -1
	var bc := -1
	for r in n:
		for c in n:
			if g[r][c] == -1:
				br = r
				bc = c
				break
		if br != -1:
			break
	if br == -1:
		return 1 if is_valid_complete(g) and signs_ok(g, signs) else 0
	var found := 0
	for v in [0, 1]:
		g[br][bc] = v
		if _partial_ok(g, br, bc, n, by_cell):
			found += _search(g, n, limit - found, signs, by_cell)
			if found >= limit:
				g[br][bc] = -1
				return found
		g[br][bc] = -1
	return found

static func _partial_ok(g: Array, r: int, c: int, n: int, by_cell: Array = []) -> bool:
	var half: int = n / 2
	# Signs touching (r, c).
	if not by_cell.is_empty():
		for s in by_cell[r * n + c]:
			if sign_broken(g, s):
				return false
	# Three-in-a-line, only windows touching (r, c).
	for s in range(maxi(0, c - 2), mini(c, n - 3) + 1):
		if g[r][s] != -1 and g[r][s] == g[r][s + 1] and g[r][s + 1] == g[r][s + 2]:
			return false
	for s in range(maxi(0, r - 2), mini(r, n - 3) + 1):
		if g[s][c] != -1 and g[s][c] == g[s + 1][c] and g[s + 1][c] == g[s + 2][c]:
			return false
	# Balance cannot already be exceeded.
	var r0 := 0
	var r1 := 0
	var c0 := 0
	var c1 := 0
	for j in n:
		if g[r][j] == 0: r0 += 1
		elif g[r][j] == 1: r1 += 1
		if g[j][c] == 0: c0 += 1
		elif g[j][c] == 1: c1 += 1
	if r0 > half or r1 > half or c0 > half or c1 > half:
		return false
	return true

static func _random_solution(rng: RandomNumberGenerator, n: int) -> Array:
	var g: Array = []
	for r in n:
		var row: Array = []
		for c in n:
			row.append(-1)
		g.append(row)
	_fill(g, 0, n, rng)
	return g

static func _fill(g: Array, idx: int, n: int, rng: RandomNumberGenerator) -> bool:
	if idx == n * n:
		return is_valid_complete(g)
	var r: int = idx / n
	var c: int = idx % n
	var vals := [0, 1] if rng.randf() < 0.5 else [1, 0]
	for v in vals:
		g[r][c] = v
		if _partial_ok(g, r, c, n) and _fill(g, idx + 1, n, rng):
			return true
	g[r][c] = -1
	return false

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

## Rule feedback for a partial grid: which rows and columns already break a
## rule (three alike in a row, or more than half of one symbol). Boards tint
## these so players learn the rules by touch.
## A broken sign marks its two cells (as (c, r) keys in "cells"), not
## their whole lines: the sign is the thing that is wrong.
static func bad_lines(grid: Array, signs: Array = []) -> Dictionary:
	var n: int = grid.size()
	var rows := {}
	var cols := {}
	var half: int = n / 2
	for i in n:
		var row := []
		var col := []
		for j in n:
			row.append(grid[i][j])
			col.append(grid[j][i])
		if _line_bad(row, half):
			rows[i] = true
		if _line_bad(col, half):
			cols[i] = true
	var cells := {}
	for s in signs:
		if sign_broken(grid, s):
			var o := sign_other(s)
			cells[Vector2i(s.y, s.x)] = true
			cells[Vector2i(o.y, o.x)] = true
	return {"rows": rows, "cols": cols, "cells": cells}

static func _line_bad(line: Array, half: int) -> bool:
	var zeros := 0
	var ones := 0
	for v in line:
		if v == 0:
			zeros += 1
		elif v == 1:
			ones += 1
	if zeros > half or ones > half:
		return true
	for i in range(line.size() - 2):
		if line[i] != -1 and line[i] == line[i + 1] and line[i + 1] == line[i + 2]:
			return true
	return false
