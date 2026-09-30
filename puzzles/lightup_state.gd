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
##
## Insane is Cat Naps (2026-09-30-lightup-polish-design.md, section 2): cats
## sit on open stones (`Gen.CAT + n` in the grid), light crosses them, no lamp
## or chip goes on them, they need no light, and each wants exactly n lamps
## shining on her. `is_white` is still "a lamp may go here"; `lets_light` is
## "a beam crosses here", which a cat's stone also does.

const Gen = preload("res://puzzles/lightup_gen.gd")
const InsaneBank = preload("res://core/insane_bank.gd")

## What is on an open stone. A bare stone is simply absent from `marks`.
const BLANK := 0
const LAMP := 1
const CHIP := 2
const HINTS := 3
## Hints per difficulty: Insane has one.
const HINTS_BY_BAND := [3, 3, 3, 1]
## Hearts per difficulty: none on Easy and Medium, three on Hard, one on
## Insane (Tents' and Shikaku's counts). A heart goes on a lamp the board
## cannot fault (`lamp_fair`) that is not the answer's.
const HEARTS := [0, 0, 3, 1]
## The four ways out of a cell, and the ladder: width, height and how much of
## the court is sown with blocks. The island's own numbers.
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Insane's row is only the fallback when the Cat Naps bank
## (content/insane/lightup.json) is empty: live 9x9 missed the 194 ms gate
## (worst 978 ms over 40 seeds on this Mac).
const SIZES := [[5, 5, 0.24], [6, 6, 0.22], [7, 7, 0.20], [8, 8, 0.18]]

## What a numbered block wears.
const BLOCK_IDLE := 0
const BLOCK_OK := 1
const BLOCK_OVER := 2
## A cat wears the same three: short of her number, met, or over it. A
## napping cat (0) is met while dark and over once lit.
const CAT_IDLE := BLOCK_IDLE
const CAT_OK := BLOCK_OK
const CAT_OVER := BLOCK_OVER

var w: int = 5
var h: int = 5
## [y][x] -> Gen.WALL (a block with nothing on its crown), Gen.WHITE (an open
## stone), 0..4 (a block carrying that number) or Gen.CAT + n (a cat wanting
## n lamps, Insane only).
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
## Vector2i (a cat's stone) -> how many lamps shine on her, 0 to 2. Every cat
## has an entry.
var cat_seen: Dictionary = {}
var cats: Array = []              # [Vector2i], every cat's stone
## The difficulty the board was built for, 0 to 3.
var band := 0
## One entry per gesture, newest last: [{"cell": Vector2i, "prev": int}].
var history: Array = []

## Insane reads the Cat Naps bank, stepped by `bank_step` (the host's New
## count), and falls back to its live band with no cats when the bank is empty.
func setup(rng: RandomNumberGenerator, difficulty: int, bank_step := 0) -> void:
	band = clampi(difficulty, 0, SIZES.size() - 1)
	var out: Dictionary = {}
	if band == 3:
		out = Gen.from_bank(InsaneBank.pick("lightup", bank_step))
	if out.is_empty():
		var step: Array = SIZES[band]
		out = Gen.generate(rng, int(step[0]), int(step[1]), float(step[2]))
	w = int(out.w)
	h = int(out.h)
	grid = out.grid
	solution = out.bulbs
	cats = []
	for y in h:
		for x in w:
			if Gen.is_cat(int(grid[y][x])):
				cats.append(Vector2i(x, y))
	marks = {}
	locked = {}
	history = []
	recompute()

# --- reading the board ---

func in_field(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < w and cell.y < h

## An open stone: somewhere a lamp or a chip may go. Never a cat's.
func is_white(cell: Vector2i) -> bool:
	return in_field(cell) and int(grid[cell.y][cell.x]) == Gen.WHITE

## A stone a beam crosses: an open one or a cat's.
func lets_light(cell: Vector2i) -> bool:
	return in_field(cell) and Gen.passes(int(grid[cell.y][cell.x]))

func is_cat(cell: Vector2i) -> bool:
	return in_field(cell) and Gen.is_cat(int(grid[cell.y][cell.x]))

## How many lamps the cat on `cell` wants, or -1 where there is no cat.
func cat_need(cell: Vector2i) -> int:
	return int(grid[cell.y][cell.x]) - Gen.CAT if is_cat(cell) else -1

func has_cats() -> bool:
	return not cats.is_empty()

func mark_at(cell: Vector2i) -> int:
	return int(marks.get(cell, BLANK))

## A stone nothing may be put on or taken off: a block's, a cat's, or a lamp
## a hint lit.
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

## Fills `lit`, `clash` and `cat_seen` from the lamps that are down. The
## island's own `_recompute`: every lamp walks its four lines until a block
## stops it (a cat does not), keeping the shortest beam to each stone, and any
## lamp it meets on the way is a clash for both of them. A cat's stone is in
## `lit` when a beam crosses it, and counts every lamp that does.
func recompute() -> void:
	lit = {}
	clash = {}
	cat_seen = {}
	for c in cats:
		cat_seen[c] = 0
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
			while lets_light(p):
				if not lit.has(p) or int(lit[p]) > n:
					lit[p] = n
				if cat_seen.has(p):
					cat_seen[p] = int(cat_seen[p]) + 1
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

## A cat's state: short of her number, met, or over it.
func cat_state(cell: Vector2i) -> int:
	if not cat_seen.has(cell):
		return CAT_IDLE
	var need := cat_need(cell)
	var have := int(cat_seen[cell])
	if have == need:
		return CAT_OK
	return CAT_OVER if have > need else CAT_IDLE

func over_cats() -> int:
	var n := 0
	for c in cats:
		if cat_state(c) == CAT_OVER:
			n += 1
	return n

## A lamp the board cannot fault: it sees no other lamp, pushes no numbered
## block beside it over its number, and pushes no cat it shines on over hers.
## On Hard and Insane such a lamp outside the answer costs a heart -- the
## answer is unique, so it is wrong by proof.
func lamp_fair(cell: Vector2i) -> bool:
	if mark_at(cell) != LAMP or clash.has(cell):
		return false
	for d in DIRS:
		if block_state(cell + d) == BLOCK_OVER:
			return false
		var p: Vector2i = cell + d
		while lets_light(p):
			if cat_state(p) == CAT_OVER:
				return false
			p += d
	return true

func is_answer(cell: Vector2i) -> bool:
	return solution.has(cell)

## Stones no lamp reaches: the third rule, and the sprout's count. A cat's
## stone never counts; her number is her whole rule.
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
	if not Gen._all_lit(grid, down, w, h):
		return false
	return not has_cats() or Gen.cats_exact(grid, down, w, h)

func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			if Gen.is_cat(int(grid[y][x])):
				out += "🐈"
			elif int(grid[y][x]) != Gen.WHITE:
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
