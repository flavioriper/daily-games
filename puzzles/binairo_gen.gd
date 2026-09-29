extends RefCounted

## Binairo / Takuzu generator and solver.
##
## Grid representation: Array of rows, each an Array of int, where -1 is empty.
## Rules enforced: no three of the same in a line, each line balanced 50/50,
## and no two rows (or two columns) identical.
##
## Generation is the build-then-strip shape: make a full valid solution, then
## remove clues one at a time, keeping a removal only while the solver still
## reports exactly one solution. The result is minimal by construction --
## removing clues only ever loosens constraints, so a clue proven load-bearing
## at any point stays load-bearing.
##
## Signs (2026-09-23): a board may also carry signs between side-by-side
## cells, Vector4i(r, c, dir, same) -- dir 0 joins (r, c) to the cell on its
## right and 1 to the cell below; same 1 is "=" (the two match) and 0 is "x"
## (they differ). They are read off the solution before the clues are
## stripped, so every sign is load-bearing for uniqueness in the same way a
## clue is, and the strip then leaves far fewer clues than a board without.
##
## Liars (2026-09-29): Insane's board shows one sign that lies -- its kind is
## the opposite of the truth, and nothing marks which. `generate_liar` builds
## those (see its comment), and `insane_board` reads the mined ones out of
## the bank (content/insane/binairo.json, tools/insane/binairo_ladder.gd).

const InsaneBank = preload("res://core/insane_bank.gd")

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
## reading the solution, before any clue is taken away.
static func generate(rng: RandomNumberGenerator, n: int, min_clues: int = 0, sign_count: int = 0) -> Dictionary:
	assert(n % 2 == 0, "Binairo needs an even board size")
	var sol: Array = _random_solution(rng, n)
	var signs: Array = _pick_signs(rng, sol, n, sign_count)
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
		if solve_count(puzzle, 2, signs) == 1:
			clues -= 1
		else:
			puzzle[r][c] = kept
	return {"solution": sol, "puzzle": puzzle, "clues": clues, "signs": signs, "liar": -1}

## An Insane board: a size-`n` board with `sign_count` signs, exactly one of
## which lies, stripped to minimal clues (a `min_clues` floor above 0 stops
## the strip early, as in generate). Same dict as generate(), with `signs` as
## shown (the liar's kind is the false one) and "liar" its index.
##
## The board is sound when believing every sign leaves no solution, and
## flipping one sign at a time leaves exactly one solution over all the
## flips together -- so the player can find the liar by reasoning, and the
## grid is unique once it is found (`liar_valid`). It starts sound on the
## full grid (only the liar's own flip keeps the solution) and every strip
## step keeps it so. Removing a clue only ever adds solutions, so the strip
## is minimal by construction exactly as generate()'s is. Too slow for the
## phone at 10x10: it is mined off the phone (tools/mine_insane.gd).
static func generate_liar(rng: RandomNumberGenerator, n: int = 10, sign_count: int = 12, min_clues: int = 0) -> Dictionary:
	assert(n % 2 == 0, "Binairo needs an even board size")
	assert(sign_count > 0, "a liar needs a sign to lie")
	var sol: Array = _random_solution(rng, n)
	var signs: Array = _pick_signs(rng, sol, n, sign_count)
	var liar: int = rng.randi_range(0, signs.size() - 1)
	signs[liar] = flip_sign(signs[liar])
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
		if liar_valid(puzzle, signs, liar):
			clues -= 1
		else:
			puzzle[r][c] = kept
	return {"solution": sol, "puzzle": puzzle, "clues": clues, "signs": signs, "liar": liar}

## Whether `grid` with `signs` (as shown) is a sound liar board whose liar is
## sign `liar`: every sign believed gives 0 solutions, and the solutions over
## each single flip sum to exactly 1, all of them from flipping `liar`.
## Checked cheapest-refusal first: the liar's own flip must be unique, then
## every other reading must be dead.
static func liar_valid(grid: Array, signs: Array, liar: int) -> bool:
	if liar < 0 or liar >= signs.size():
		return false
	if solve_count(grid, 2, with_flipped(signs, liar)) != 1:
		return false
	if solve_count(grid, 1, signs) != 0:
		return false
	for i in signs.size():
		if i != liar and solve_count(grid, 1, with_flipped(signs, i)) != 0:
			return false
	return true

## The liar a board's signs imply, found without being told: -1 unless every
## sign believed gives no solution and the single flips' solutions sum to
## exactly 1, else the index of the flip that gave it. Stops as soon as the
## running sum passes 1. For proving a mined board, not for play.
static func find_liar(grid: Array, signs: Array) -> int:
	if solve_count(grid, 1, signs) != 0:
		return -1
	var total := 0
	var found := -1
	for i in signs.size():
		var k := solve_count(grid, 2 - total, with_flipped(signs, i))
		if k > 0:
			total += k
			found = i
			if total > 1:
				return -1
	return found if total == 1 else -1

## Sign `s` telling the other story: "=" becomes "x" and back.
static func flip_sign(s: Vector4i) -> Vector4i:
	return Vector4i(s.x, s.y, s.z, 0 if s.w == 1 else 1)

## A copy of `signs` with sign `i` flipped; `signs` itself is untouched.
static func with_flipped(signs: Array, i: int) -> Array:
	var out: Array = signs.duplicate()
	out[i] = flip_sign(out[i])
	return out

## Today's banked Insane board (core/insane_bank.gd), in generate()'s dict
## shape with "liar"; {} when the bank is empty or unreadable, and the board
## falls back to its live row. `step` is PuzzleBase.bank_step (how many times
## New was pressed since the card opened): the pick is by day and step, like
## Rings', so `rng` is not drawn from -- it is taken so a board can swap this
## in where it already holds one for generate().
static func insane_board(_rng: RandomNumberGenerator = null, step: int = 0) -> Dictionary:
	var b: Dictionary = InsaneBank.pick("binairo", step)
	if not (b.get("puzzle") is Array and b.get("solution") is Array and b.get("signs") is Array):
		return {}
	return from_bank(b)

## A bank entry (JSON: numbers arrive as floats, signs as [r, c, dir, same])
## as generate()'s dict.
static func from_bank(b: Dictionary) -> Dictionary:
	var puzzle: Array = []
	var solution: Array = []
	var clues := 0
	for r in (b["puzzle"] as Array).size():
		var row: Array = []
		var sol_row: Array = []
		for c in (b["puzzle"][r] as Array).size():
			var v := int(b["puzzle"][r][c])
			row.append(v)
			sol_row.append(int(b["solution"][r][c]))
			if v != -1:
				clues += 1
		puzzle.append(row)
		solution.append(sol_row)
	var signs: Array = []
	for s in b["signs"]:
		signs.append(Vector4i(int(s[0]), int(s[1]), int(s[2]), int(s[3])))
	return {"solution": solution, "puzzle": puzzle, "clues": clues, "signs": signs, "liar": int(b.get("liar", -1))}

## A generate_liar() dict in the bank's JSON encoding: signs as arrays.
static func to_bank(out: Dictionary) -> Dictionary:
	var signs: Array = []
	for s: Vector4i in out["signs"]:
		signs.append([s.x, s.y, s.z, s.w])
	return {"puzzle": out["puzzle"], "solution": out["solution"], "signs": signs, "liar": out["liar"], "clues": out["clues"]}

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
	# Distinct lines.
	for a in n:
		for b in range(a + 1, n):
			if g[a] == g[b]:
				return false
			var ca := []
			var cb := []
			for i in n:
				ca.append(g[i][a])
				cb.append(g[i][b])
			if ca == cb:
				return false
	return true

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
	# A completed line must not duplicate another completed line.
	if r0 + r1 == n:
		for i in n:
			if i != r and not (g[i] as Array).has(-1) and g[i] == g[r]:
				return false
	if c0 + c1 == n:
		var col := []
		for i in n:
			col.append(g[i][c])
		for j in n:
			if j == c:
				continue
			var other := []
			var full := true
			for i in n:
				if g[i][j] == -1:
					full = false
					break
				other.append(g[i][j])
			if full and other == col:
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
## rule (three alike in a row, more than half of one symbol, or two identical
## complete lines). Boards tint these so players learn the rules by touch.
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
	for a in n:
		for b in range(a + 1, n):
			if not (grid[a] as Array).has(-1) and grid[a] == grid[b]:
				rows[a] = true
				rows[b] = true
			var ca := []
			var cb := []
			for i in n:
				ca.append(grid[i][a])
				cb.append(grid[i][b])
			if not ca.has(-1) and ca == cb:
				cols[a] = true
				cols[b] = true
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
