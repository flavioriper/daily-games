extends RefCounted

## Light Up's rules, with no scene under them: the court's grid, what the
## player has set down on each stone, how far every lamp's light reaches, and
## every move that can change it. The flat board (puzzles/lightup2d.gd) draws
## this and nothing else, so what is on trial on the phone is the screen and
## not the game.
##
## It is `puzzles/lightup3d.gd`'s logic with two deliberate differences.
## **A gesture is a move, not a tap**: the flat board sweeps a run of chips in
## one drag, so the history records a list of stones rather than a single one,
## and a swept run comes back on one undo rather than one chip at a time.
## **And a tap is one state, not a cycle**: whatever is on the stone comes off
## and a bare stone gets a lamp, where the island cycles blank to lamp to chip
## and so costs two taps for every chip. Both are Tents' answers, carried
## across (see puzzles/tents_state.gd).
##
## The win test is the generator's own three conditions rather than a
## comparison with the stored answer -- clues exact, no two lamps in sight of
## each other, every stone lit -- exactly as the island tests it.
## Spec: docs/superpowers/specs/2026-09-18-lightup-flat-design.md, section 3.

const Gen = preload("res://puzzles/lightup_gen.gd")

## What is on an open stone. A bare stone is simply absent from `marks`.
const BLANK := 0
const LAMP := 1
const CHIP := 2
const HINTS := 3
## The four ways out of a cell, and the ladder: width, height and how much of
## the court is sown with blocks. The island's own numbers.
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SIZES := [[5, 5, 0.24], [6, 6, 0.22], [7, 7, 0.20]]

## What a numbered block wears.
const BLOCK_IDLE := 0
const BLOCK_OK := 1
const BLOCK_OVER := 2

var w: int = 5
var h: int = 5
## [y][x] -> Gen.WALL (a block with nothing on its crown), Gen.WHITE (an open
## stone) or 0..4 (a block carrying that number).
var grid: Array = []
var solution: Array = []          # [Vector2i], the answer's lamps
var marks: Dictionary = {}        # Vector2i -> LAMP or CHIP
var locked: Dictionary = {}       # Vector2i -> true, a lamp a hint lit
## Vector2i -> how many cells of beam the nearest lamp is away, 0 on the
## lamp's own stone. Absent means the stone is still in the dark. This is what
## the warming wave staggers on, so it is part of the rules and not the
## drawing.
var lit: Dictionary = {}
var clash: Dictionary = {}        # Vector2i -> true, a lamp that can see another
## One entry per gesture, newest last: [{"cell": Vector2i, "prev": int}].
var history: Array = []

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	var step: Array = SIZES[clampi(difficulty, 0, SIZES.size() - 1)]
	w = int(step[0])
	h = int(step[1])
	var out: Dictionary = Gen.generate(rng, w, h, float(step[2]))
	grid = out.grid
	solution = out.bulbs
	marks = {}
	locked = {}
	history = []
	recompute()

# --- reading the board ---

func in_field(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < w and cell.y < h

## An open stone: somewhere a lamp or a chip may go.
func is_white(cell: Vector2i) -> bool:
	return in_field(cell) and int(grid[cell.y][cell.x]) == Gen.WHITE

func mark_at(cell: Vector2i) -> int:
	return int(marks.get(cell, BLANK))

## A stone nothing may be put on or taken off: a block's, or a lamp a hint lit.
func fixed(cell: Vector2i) -> bool:
	return not is_white(cell) or locked.has(cell)

func lamps() -> Array:
	var out: Array = []
	for cell in marks:
		if int(marks[cell]) == LAMP:
			out.append(cell)
	return out

func white_cells() -> Array:
	var out: Array = []
	for y in h:
		for x in w:
			if int(grid[y][x]) == Gen.WHITE:
				out.append(Vector2i(x, y))
	return out

## Fills `lit` and `clash` from the lamps that are down. The island's own
## `_recompute`: every lamp walks its four lines until a block stops it,
## keeping the shortest beam to each stone, and any lamp it meets on the way
## is a clash for both of them.
func recompute() -> void:
	lit = {}
	clash = {}
	if grid.is_empty():
		return
	var down: Array = lamps()
	var here: Dictionary = {}
	for b in down:
		here[b] = true
	for b in down:
		lit[b] = 0
		for d in DIRS:
			var p: Vector2i = b + d
			var n := 1
			while is_white(p):
				if not lit.has(p) or int(lit[p]) > n:
					lit[p] = n
				if here.has(p):
					clash[b] = true
					clash[p] = true
				p += d
				n += 1

## How many lamps touch a block, orthogonally: what its number counts.
func touching(cell: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if mark_at(cell + d) == LAMP:
			n += 1
	return n

## A block's state. A block with no number has nothing to be satisfied about,
## so it is never anything but idle.
func block_state(cell: Vector2i) -> int:
	if not in_field(cell):
		return BLOCK_IDLE
	var need := int(grid[cell.y][cell.x])
	if need < 0:
		return BLOCK_IDLE
	var have := touching(cell)
	if have == need:
		return BLOCK_OK
	return BLOCK_OVER if have > need else BLOCK_IDLE

## Stones no lamp reaches: the third rule, and the sprout's count.
func dark() -> int:
	var n := 0
	for cell in white_cells():
		if not lit.has(cell):
			n += 1
	return n

func over_blocks() -> int:
	var n := 0
	for y in h:
		for x in w:
			if block_state(Vector2i(x, y)) == BLOCK_OVER:
				n += 1
	return n

func chips() -> int:
	var n := 0
	for cell in marks:
		if int(marks[cell]) == CHIP:
			n += 1
	return n

func is_solved() -> bool:
	if grid.is_empty():
		return false
	var down: Array = lamps()
	if down.is_empty():
		return false
	if Gen.bulbs_see_each_other(grid, down, w, h):
		return false
	if not Gen._clues_exact(grid, down, w, h):
		return false
	return Gen._all_lit(grid, down, w, h)

func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			if int(grid[y][x]) != Gen.WHITE:
				out += "⬛"
			elif mark_at(cell) == LAMP:
				out += "💡"
			elif lit.has(cell):
				out += "🟨"
			else:
				out += "⬜"
		out += "\n"
	return out

# --- moves ---

## Puts `cells` -- [{"cell": Vector2i, "to": int}] -- on the court as **one**
## entry in the history, which is what makes a swept run one undo. Returns the
## stones that actually changed, so the board can pop just those.
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
	recompute()
	return changed

func _put(cell: Vector2i, to: int) -> void:
	if to == BLANK:
		marks.erase(cell)
	else:
		marks[cell] = to

## A tap: whatever is on the stone comes off, and a bare stone gets a lamp.
func tap(cell: Vector2i) -> Array:
	return apply([{"cell": cell, "to": LAMP if mark_at(cell) == BLANK else BLANK}])

## Takes back the last gesture, however many stones it touched. Returns them.
func undo() -> Array:
	if history.is_empty():
		return []
	var entry: Array = history.pop_back()
	var touched: Array = []
	for e in entry:
		_put(e.cell, int(e.prev))
		touched.append(e.cell)
	recompute()
	return touched

## Lights the first answer lamp the court does not already carry and pins it
## for good. What came before still describes this board, except for the one
## stone the hint has taken over.
func hint() -> Vector2i:
	var target := Vector2i(-1, -1)
	for b in solution:
		if mark_at(b) != LAMP:
			target = b
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
	marks[target] = LAMP
	locked[target] = true
	recompute()
	return target

## Every lamp the answer does not put there. Solving stays automatic; this
## only points.
func wrong_lamps() -> Array:
	var out: Array = []
	for cell in lamps():
		if not solution.has(cell):
			out.append(cell)
	return out

## Clears the court. Hints are unpinned but not refunded, as on the island.
func reset() -> Array:
	var cleared: Array = marks.keys()
	marks = {}
	locked = {}
	history = []
	recompute()
	return cleared
