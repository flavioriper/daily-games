extends RefCounted

## Binairo's rules with no scene in them: the grid, the clues, the solution,
## the undo history and which lines currently break a rule. The flat board
## and the island board each own one of these and draw whatever it says, so
## the two can never disagree about what a tap, a hint or a reset did. Cells
## are -1 empty, 0 sun, 1 moon. Rows and columns arrive as ints; a cell that
## is handed back is a Vector2i(c, r), x the column and y the row, the way
## the island's `_hint_cell` and `focus_cell` already speak. A history entry
## is Vector3i(r, c, previous value), as the island's `_history` has it.
## Nothing in here counts moves, hints or checks: those are the board's
## tallies on PuzzleBase, and they follow the board's own rules (a hint
## finishing the puzzle counts no move, reset refunds no hint).

const Gen = preload("res://puzzles/binairo_gen.gd")

var n: int = 0
var grid: Array = []       # [r][c] -> int
var given: Array = []      # [r][c] -> bool: a clue, or a cell a hint filled
var hinted: Array = []     # [r][c] -> bool: filled by a hint, so a reset gives it back
var solution: Array = []
var history: Array[Vector3i] = []
## The signs between side-by-side cells, as Gen hands them:
## Vector4i(r, c, dir, same), dir 0 rightward and 1 downward.
var signs: Array = []
## Gen.bad_lines(grid, signs): {"rows": {r: true}, "cols": {c: true},
## "cells": {(c, r): true}} -- the last for the ends of a broken sign. Kept in
## Gen's shape so a board asks `bad.rows.has(r)` exactly as the island does.
var bad: Dictionary = {"rows": {}, "cols": {}, "cells": {}}

## Takes a fresh puzzle from Gen.generate: the solution, the clues as givens,
## an empty history. Everything is copied out of the dictionary, so the
## generator's arrays are never shared with a board that mutates them.
func setup(out: Dictionary) -> void:
	var puzzle: Array = out.puzzle
	n = puzzle.size()
	signs = (out.get("signs", []) as Array).duplicate()
	solution = []
	grid = []
	given = []
	hinted = []
	for r in n:
		solution.append((out.solution[r] as Array).duplicate())
		var row: Array = []
		var given_row: Array = []
		var hinted_row: Array = []
		for c in n:
			var v: int = puzzle[r][c]
			row.append(v)
			given_row.append(v != -1)
			hinted_row.append(false)
		grid.append(row)
		given.append(given_row)
		hinted.append(hinted_row)
	history = []
	refresh_bad()

# --- moves ---

## The tap: empty -> sun -> moon -> empty. A given does not turn; false says
## nothing changed, so the board can answer with the locked cell's dip.
func cycle(r: int, c: int) -> bool:
	if given[r][c]:
		return false
	var v: int = grid[r][c]
	var next: int = 0 if v == -1 else (1 if v == 0 else -1)
	_change(r, c, v, next)
	return true

## The brush: paints v straight onto the cell. False on a given, and false
## when the cell already shows v, so a repeated tap with the brush armed
## costs no move and leaves no history entry to undo into nothing.
func place(r: int, c: int, v: int) -> bool:
	if given[r][c] or grid[r][c] == v:
		return false
	_change(r, c, grid[r][c], v)
	return true

## The one place a value changes by the player's hand: records what was
## there, writes the new value and re-reads the rules.
func _change(r: int, c: int, previous: int, v: int) -> void:
	history.append(Vector3i(r, c, previous))
	grid[r][c] = v
	refresh_bad()

## Reverts the last change and says which cell now shows what, as
## Vector3i(r, c, restored value); (-1, -1, -1) with nothing to undo. No
## state in the history was ever solved, or the game would have ended there.
func undo() -> Vector3i:
	if history.is_empty():
		return Vector3i(-1, -1, -1)
	var last: Vector3i = history.pop_back()
	grid[last.x][last.y] = last.z
	refresh_bad()
	return last

## Empties every free cell and hands hinted cells back to the player: a hint
## is not a clue, so after a reset the cell is free again and empty. Clears
## the history. Returns the (c, r) of every cell whose value changed, which
## is what a board has to redraw; a given that stays is not among them.
func reset() -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for r in n:
		for c in n:
			if hinted[r][c]:
				hinted[r][c] = false
				given[r][c] = false
			if given[r][c] or grid[r][c] == -1:
				continue
			grid[r][c] = -1
			changed.append(Vector2i(c, r))
	history = []
	refresh_bad()
	return changed

# --- help ---

## The cell a hint would fill, as (c, r): a wrong filled free cell first,
## since a hint that corrects a mistake teaches more than one that fills a
## blank; else the empty cell whose row and column together hold the most
## filled cells, the one the player is closest to deducing. Ties go to the
## first in row-major order. (-1, -1) when nothing qualifies.
func hint_cell() -> Vector2i:
	for r in n:
		for c in n:
			if not given[r][c] and grid[r][c] != -1 and grid[r][c] != solution[r][c]:
				return Vector2i(c, r)
	var best := Vector2i(-1, -1)
	var best_score := -1
	for r in n:
		for c in n:
			if grid[r][c] != -1:
				continue
			var score := 0
			for j in n:
				if grid[r][j] != -1:
					score += 1
				if grid[j][c] != -1:
					score += 1
			if score > best_score:
				best_score = score
				best = Vector2i(c, r)
	return best

## Fills hint_cell() from the solution and locks it as a given, remembering
## it was a hint so reset can unlock it. The cell's own entries leave the
## history: an undo must never turn a locked cell back, and there is nothing
## honest to restore it to. Returns the (c, r) filled, or (-1, -1).
func apply_hint() -> Vector2i:
	var cell := hint_cell()
	if cell.x < 0:
		return cell
	var r := cell.y
	var c := cell.x
	var kept: Array[Vector3i] = []
	for h in history:
		if h.x != r or h.y != c:
			kept.append(h)
	history = kept
	grid[r][c] = solution[r][c]
	given[r][c] = true
	hinted[r][c] = true
	refresh_bad()
	return cell

## Every filled free cell that differs from the solution, as (c, r). Check
## points at these; solving stays automatic.
func wrong_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in n:
		for c in n:
			if given[r][c] or grid[r][c] == -1 or grid[r][c] == solution[r][c]:
				continue
			out.append(Vector2i(c, r))
	return out

# --- rules ---

func refresh_bad() -> void:
	bad = Gen.bad_lines(grid, signs)

## Whether the cell sits in a row or a column that breaks a rule right now,
## or at either end of a broken sign.
func is_bad(r: int, c: int) -> bool:
	return bad.rows.has(r) or bad.cols.has(c) or bad.cells.has(Vector2i(c, r))

## Whether sign `i` of `signs` disagrees with the grid right now.
func sign_broken(i: int) -> bool:
	return Gen.sign_broken(grid, signs[i])

## Which rule the board breaks, for the tip card: 0 none, 1 three alike side
## by side, 2 more than half a line of one symbol, 3 two identical complete
## lines, 4 a sign between two cells that is not kept. The lowest id among
## every broken line; a line breaking both 1 and 2
## reads as 1, since the run of three is what the eye finds first. Gen's
## bad_lines only says which lines are wrong, so the rule is worked out here.
func broken_rule() -> int:
	var half: int = n / 2
	var worst := 0
	for i in n:
		worst = _lowest(worst, _line_rule(grid[i], half))
		worst = _lowest(worst, _line_rule(_column(i), half))
	if worst == 1:
		return 1
	for a in n:
		for b in range(a + 1, n):
			if not (grid[a] as Array).has(-1) and grid[a] == grid[b]:
				worst = _lowest(worst, 3)
			var ca := _column(a)
			if not ca.has(-1) and ca == _column(b):
				worst = _lowest(worst, 3)
	if worst == 0 and not bad.cells.is_empty():
		return 4
	return worst

## 1 for three equal filled cells in a row, else 2 for more than half of one
## symbol, else 0. Mirrors Gen._line_bad, which only answers yes or no.
static func _line_rule(line: Array, half: int) -> int:
	for i in range(line.size() - 2):
		if line[i] != -1 and line[i] == line[i + 1] and line[i + 1] == line[i + 2]:
			return 1
	var suns := 0
	var moons := 0
	for v in line:
		if v == 0:
			suns += 1
		elif v == 1:
			moons += 1
	return 2 if suns > half or moons > half else 0

static func _lowest(a: int, b: int) -> int:
	if a == 0:
		return b
	if b == 0:
		return a
	return mini(a, b)

func _column(c: int) -> Array:
	var col := []
	for i in n:
		col.append(grid[i][c])
	return col

## The cells of row r if it is full and breaks nothing, plus those of column
## c on the same terms, as (c, r); the cell where the two cross is listed
## once. Empty otherwise. A board celebrates these after the tap that filled
## the last of them. Reads `bad` as it stands, so call it after the change.
func line_just_completed(r: int, c: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (grid[r] as Array).has(-1) and not bad.rows.has(r) and not _signs_bad_in(r, -1):
		for j in n:
			out.append(Vector2i(j, r))
	if not _column(c).has(-1) and not bad.cols.has(c) and not _signs_bad_in(-1, c):
		for i in n:
			var cell := Vector2i(c, i)
			if not out.has(cell):
				out.append(cell)
	return out

## Whether a broken sign's end lies in row r (or column c, with r -1): a
## line with a broken sign in it is not celebrated.
func _signs_bad_in(r: int, c: int) -> bool:
	for cell in bad.cells:
		if (r >= 0 and cell.y == r) or (c >= 0 and cell.x == c):
			return true
	return false

func is_full() -> bool:
	for r in n:
		if (grid[r] as Array).has(-1):
			return false
	return true

func is_solved() -> bool:
	return Gen.is_valid_complete(grid) and Gen.signs_ok(grid, signs)

# --- for the HUD ---

## The solved board as a share text, one glyph a cell; only meaningful once
## solved, when no cell is empty.
func share_glyphs() -> String:
	var out := ""
	for r in n:
		for c in n:
			out += "🌞" if grid[r][c] == 0 else "🌙"
		out += "\n"
	return out

## The focused row and column for the working-line card, with focus as
## (c, r); {} without a focus. Cells are copies, so the card cannot reach in.
func line_state(focus: Vector2i) -> Dictionary:
	if focus.x < 0:
		return {}
	var r := focus.y
	var c := focus.x
	return {
		"row": {"index": r, "cells": (grid[r] as Array).duplicate()},
		"col": {"index": c, "cells": _column(c)},
	}
