extends RefCounted

## Tents' rules, with no scene under them: the trees, the counts, what the
## player has put on each square, and every move that can change it. The flat
## board (puzzles/tents2d.gd) draws this and nothing else, so what is on trial
## on the phone is the screen and not the game.
##
## It is `puzzles/tents3d.gd`'s logic with one deliberate difference: **a
## gesture is a move, not a tap**. The flat board sweeps a whole row of cairns
## in one drag, so the history records a list of squares rather than a single
## one, and a swept row comes back on one undo rather than sixteen. The island
## only ever had single taps to record.
##
## The win test is the generator's own and is not a comparison with the stored
## answer: `Gen.is_valid_solution` runs a perfect matching between trees and
## adjacent tents, because a board can have a tent beside every tree and still
## be wrong -- two trees quarrelling over the same one. That is why this board
## never draws which tree a tent belongs to.
## Spec: docs/superpowers/specs/2026-09-18-tents-flat-design.md, section 2.

const Gen = preload("res://puzzles/tents_gen.gd")

const BLANK := 0
const TENT := 1
const GRASS := 2
const HINTS := 3
## Width, height and tents per difficulty: the island's ladder exactly.
## Insane's provisional band, replaced by the bank in batch 2.
const SIZES := [[6, 6, 5], [7, 7, 7], [8, 8, 9], [10, 10, 14]]

## A line's state, which is what its count chip wears.
const LINE_IDLE := 0
const LINE_OK := 1
const LINE_OVER := 2

var w: int = 6
var h: int = 6
var trees: Dictionary = {}       # Vector2i -> true
var tree_list: Array = []
var solution: Array = []         # [Vector2i], the answer's tents
var row_counts: Array = []
var col_counts: Array = []
## Vector2i -> TENT or GRASS. A blank square is simply absent.
var marks: Dictionary = {}
var locked: Dictionary = {}      # Vector2i -> true, a tent a hint pegged
## One entry per gesture, newest last: [{"cell": Vector2i, "prev": int}].
var history: Array = []

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	var step: Array = SIZES[clampi(difficulty, 0, SIZES.size() - 1)]
	w = step[0]
	h = step[1]
	var out: Dictionary = Gen.generate(rng, w, h, step[2])
	trees = {}
	tree_list = out.trees
	for t in tree_list:
		trees[t] = true
	solution = out.tents
	row_counts = out.row_counts
	col_counts = out.col_counts
	marks = {}
	locked = {}
	history = []

# --- reading the board ---

func in_field(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < w and cell.y < h

func mark_at(cell: Vector2i) -> int:
	return int(marks.get(cell, BLANK))

## A square nothing may be put on or taken off: a tree's, or a tent a hint
## pegged down.
func fixed(cell: Vector2i) -> bool:
	return trees.has(cell) or locked.has(cell)

func tents() -> Array:
	var out: Array = []
	for cell in marks:
		if int(marks[cell]) == TENT:
			out.append(cell)
	return out

func row_tents(r: int) -> int:
	var n := 0
	for cell in marks:
		if cell.y == r and int(marks[cell]) == TENT:
			n += 1
	return n

func col_tents(c: int) -> int:
	var n := 0
	for cell in marks:
		if cell.x == c and int(marks[cell]) == TENT:
			n += 1
	return n

static func line_state(have: int, want: int) -> int:
	if have == want:
		return LINE_OK
	return LINE_OVER if have > want else LINE_IDLE

## The two rules a tent can be seen breaking on its own: it touches another
## tent, diagonals included, or it stands beside no tree at all. A tree with
## no tent yet is not an error -- that is an unfinished puzzle.
func tent_bad(cell: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if mark_at(cell + Vector2i(dx, dy)) == TENT:
				return true
	for d in Gen.DIRS:
		if trees.has(cell + d):
			return false
	return true

func bad_tents() -> int:
	var n := 0
	for cell in tents():
		if tent_bad(cell):
			n += 1
	return n

## Lines holding more tents than their number allows.
func over_lines() -> int:
	var n := 0
	for r in h:
		if row_tents(r) > int(row_counts[r]):
			n += 1
	for c in w:
		if col_tents(c) > int(col_counts[c]):
			n += 1
	return n

func tents_left() -> int:
	return tree_list.size() - tents().size()

func cairns() -> int:
	var n := 0
	for cell in marks:
		if int(marks[cell]) == GRASS:
			n += 1
	return n

func is_solved() -> bool:
	if trees.is_empty():
		return false
	return Gen.is_valid_solution(tents(), tree_list, row_counts, col_counts, w, h)

func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			if trees.has(cell):
				out += "🌲"
			elif mark_at(cell) == TENT:
				out += "⛺"
			else:
				out += "🟩"
		out += "\n"
	return out

# --- moves ---

## Puts `cells` -- [{"cell": Vector2i, "to": int}] -- on the board as **one**
## entry in the history, which is what makes a swept row one undo. Returns the
## squares that actually changed, so the board can pop just those.
func apply(cells: Array) -> Array:
	var entry: Array = []
	var changed: Array = []
	for c in cells:
		var cell: Vector2i = c.cell
		var to: int = int(c.to)
		if mark_at(cell) == to:
			continue
		entry.append({"cell": cell, "prev": mark_at(cell)})
		_put(cell, to)
		changed.append(cell)
	if entry.is_empty():
		return changed
	history.append(entry)
	return changed

func _put(cell: Vector2i, to: int) -> void:
	if to == BLANK:
		marks.erase(cell)
	else:
		marks[cell] = to

## A tap: a tent goes up on bare ground, and whatever is already there comes
## off. The island cycles blank to tent to cairn, which costs two taps for
## every one of the fifty-five cairns a hard board wants.
func tap(cell: Vector2i) -> Array:
	return apply([{"cell": cell, "to": TENT if mark_at(cell) == BLANK else BLANK}])

## Takes back the last gesture, however many squares it touched. Returns them.
func undo() -> Array:
	if history.is_empty():
		return []
	var entry: Array = history.pop_back()
	var touched: Array = []
	for e in entry:
		_put(e.cell, int(e.prev))
		touched.append(e.cell)
	return touched

## Pitches the first answer tent the board does not already carry and pegs it
## down for good. What came before still describes this board, except for the
## one square the hint has taken over.
func hint() -> Vector2i:
	var target := Vector2i(-1, -1)
	for t in solution:
		if mark_at(t) != TENT:
			target = t
			break
	if target.x < 0:
		return target
	var kept: Array = []
	for entry in history:
		var left: Array = []
		for e in entry:
			if e.cell != target:
				left.append(e)
		if not left.is_empty():
			kept.append(left)
	history = kept
	marks[target] = TENT
	locked[target] = true
	return target

## Every tent the answer does not put there. Solving stays automatic; this
## only points.
func wrong_tents() -> Array:
	var out: Array = []
	for cell in tents():
		if not solution.has(cell):
			out.append(cell)
	return out

## Clears the meadow. Hints are unpinned but not refunded, as on the island.
func reset() -> Array:
	var cleared: Array = marks.keys()
	marks = {}
	locked = {}
	history = []
	return cleared
