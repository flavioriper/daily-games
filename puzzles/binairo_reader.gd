extends RefCounted

## Reads a Binairo board the way a player does, one step at a time, and says
## which rule took the step and which tiles it read: the bulb's "why"
## (made fun, 2026-10-28). The steps are Gen.deduce's own (BASIC: a pair
## closes its ends, a gap between two alike takes the other, a line with
## half of one symbol fills with the other, a sign with one end known gives
## the other; LINES: every legal way to finish one line agrees), so a board
## Gen built is read to its end by this from its clues, and from any grid
## that holds only right tiles over them.
##
## Cells are Vector2i(c, r), as the board's own; a line is 0..n-1 for the
## rows and n..2n-1 for the columns.

const Gen = preload("res://puzzles/binairo_gen.gd")

enum Rule { NONE, SIGN, PAIR, GAP, HALF, LINE }

## The first step a player would take on `grid` with `signs`:
## {cell, value, rule, by (the tiles it read), line (-1 for a sign), sign
## (its index, or -1)}. Steps that read the fewest tiles come first; among
## one rule, the cell whose row and column hold the most tiles. {} when no
## step is left (a full board, or one a wrong tile has stuck).
static func next(grid: Array, signs: Array, basic_only := false) -> Dictionary:
	var all := steps(grid, signs, basic_only)
	if all.is_empty():
		return {}
	var n: int = grid.size()
	var best: Dictionary = {}
	var best_key := -INF
	for s: Dictionary in all:
		var cell: Vector2i = s.cell
		var filled := 0
		for j in n:
			if grid[cell.y][j] != -1:
				filled += 1
			if grid[j][cell.x] != -1:
				filled += 1
		var key: float = -int(s.rule) * 100.0 + filled
		if key > best_key:
			best_key = key
			best = s
	return best

## Every step one reading of `grid` takes, BASIC ones only when any exists
## (as Gen.deducible), each with its reason. A cell may come more than once.
static func steps(grid: Array, signs: Array, basic_only := false) -> Array:
	var n: int = grid.size()
	var half: int = n / 2
	var out: Array = []
	for i in signs.size():
		var s: Vector4i = signs[i]
		var o := Gen.sign_other(s)
		var a: int = grid[s.x][s.y]
		var b: int = grid[o.x][o.y]
		if a == -1 and b != -1:
			out.append(_step(Vector2i(s.y, s.x), b if s.w == 1 else 1 - b, Rule.SIGN, [Vector2i(o.y, o.x)], -1, i))
		elif b == -1 and a != -1:
			out.append(_step(Vector2i(o.y, o.x), a if s.w == 1 else 1 - a, Rule.SIGN, [Vector2i(s.y, s.x)], -1, i))
	for line in 2 * n:
		var cells := line_cells(line, n)
		var vals: Array = []
		var count := [0, 0]
		for at: Vector2i in cells:
			var v: int = grid[at.y][at.x]
			vals.append(v)
			if v != -1:
				count[v] += 1
		if count[0] + count[1] == n:
			continue
		for i in n:
			var v: int = vals[i]
			if v != -1:
				# Two alike side by side: both ends take the other.
				if i + 1 < n and vals[i + 1] == v:
					if i >= 1 and vals[i - 1] == -1:
						out.append(_step(cells[i - 1], 1 - v, Rule.PAIR, [cells[i], cells[i + 1]], line, -1))
					if i + 2 < n and vals[i + 2] == -1:
						out.append(_step(cells[i + 2], 1 - v, Rule.PAIR, [cells[i], cells[i + 1]], line, -1))
				continue
			# A gap between two alike takes the other.
			if i >= 1 and i + 1 < n and vals[i - 1] != -1 and vals[i - 1] == vals[i + 1]:
				out.append(_step(cells[i], 1 - int(vals[i - 1]), Rule.GAP, [cells[i - 1], cells[i + 1]], line, -1))
		for v in 2:
			if count[v] == half:
				var by: Array = []
				for i in n:
					if vals[i] == v:
						by.append(cells[i])
				for i in n:
					if vals[i] == -1:
						out.append(_step(cells[i], 1 - v, Rule.HALF, by, line, -1))
	if not out.is_empty() or basic_only:
		return out
	var lines := Gen.valid_lines(n)
	var in_line := Gen._signs_in_lines(signs, n)
	for line in 2 * n:
		var got := _read_line(grid, line, lines, in_line[line])
		var cells := line_cells(line, n)
		var by: Array = []
		for at: Vector2i in cells:
			if grid[at.y][at.x] != -1:
				by.append(at)
		for i in n:
			if got[i] != -1 and grid[cells[i].y][cells[i].x] == -1:
				out.append(_step(cells[i], got[i], Rule.LINE, by, line, -1))
	return out

## Lines no legal filling can finish any more, from the tiles as they stand
## and each line's own signs: a tile in each is not the answer. Only lines
## that break no rule yet (a broken one already blushes).
static func stuck_lines(grid: Array, signs: Array) -> Array[int]:
	var n: int = grid.size()
	var lines := Gen.valid_lines(n)
	var in_line := Gen._signs_in_lines(signs, n)
	var out: Array[int] = []
	for line in 2 * n:
		var cells := line_cells(line, n)
		var vals: Array = []
		var full := true
		for at: Vector2i in cells:
			vals.append(grid[at.y][at.x])
			if grid[at.y][at.x] == -1:
				full = false
		if full or Gen._line_bad(vals, n / 2) or _signs_broken(vals, in_line[line]):
			continue
		if _read_line(grid, line, lines, in_line[line]).is_empty():
			out.append(line)
	return out

## Whether one of a line's own signs is already broken on `vals`.
static func _signs_broken(vals: Array, pairs: PackedInt32Array) -> bool:
	for p in range(0, pairs.size(), 2):
		var a: int = vals[pairs[p]]
		var b: int = vals[pairs[p] + 1]
		if a != -1 and b != -1 and (a == b) != (pairs[p + 1] == 1):
			return true
	return false

## What every legal finish of `line` agrees on, per cell (-1 where they
## differ); [] when no legal finish is left.
static func _read_line(grid: Array, line: int, lines: PackedInt32Array, pairs: PackedInt32Array) -> Array:
	var n: int = grid.size()
	var cells := line_cells(line, n)
	var known := 0
	var value := 0
	for i in n:
		var v: int = grid[cells[i].y][cells[i].x]
		if v != -1:
			known |= 1 << i
			value |= v << i
	var all: int = (1 << n) - 1
	var ones := all
	var zeros := all
	var any := false
	for m in lines:
		if (m & known) != value:
			continue
		var kept := true
		for p in range(0, pairs.size(), 2):
			if (((m >> pairs[p]) ^ (m >> (pairs[p] + 1))) & 1) == pairs[p + 1]:
				kept = false
				break
		if kept:
			any = true
			ones &= m
			zeros &= ~m
	if not any:
		return []
	var out: Array = []
	for i in n:
		var bit: int = 1 << i
		out.append(1 if (ones & bit) != 0 else (0 if (zeros & bit) != 0 else -1))
	return out

## A line's cells in order, as Vector2i(c, r).
static func line_cells(line: int, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(Vector2i(i, line) if line < n else Vector2i(line - n, i))
	return out

static func _step(cell: Vector2i, value: int, rule: int, by: Array, line: int, sign: int) -> Dictionary:
	return {"cell": cell, "value": value, "rule": rule, "by": by, "line": line, "sign": sign}
