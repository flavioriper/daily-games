extends RefCounted

## Nonogram's rules, with no scene under them: the picture, the clues down
## each line, what the player has put on each cell, and every move that can
## change it. The flat board (puzzles/nonogram2d.gd) draws this and nothing
## else, so what is on trial on the phone is the screen and not the game.
##
## It is `puzzles/nonogram3d.gd`'s logic with one deliberate difference: **a
## stroke is a move, not a tap**. The flat board paints a whole run in one
## drag, so the history records a list of cells rather than a single one, and
## a painted run comes back on one undo rather than six. The island only ever
## had single taps to record, and it cycled blank -> tile -> cross -> blank on
## them; here the tray says which of the two a stroke lays, and a stroke that
## begins on your own paint rubs it out.
##
## The win test is the picture and never the clues: a grid can have every line
## reading exactly as its numbers say and still be wrong, which is why the
## sprout says so in those words rather than pretending the board is finished.
## Crosses are the player's working-out and count for nothing.
## Spec: docs/superpowers/specs/2026-09-18-nonogram-flat-design.md, section 3.

const Gen = preload("res://puzzles/nonogram_gen.gd")

const BLANK := 0
const FILL := 1
const MARK := 2
const HINTS := 3
## The ladder, the island's exactly. Nine is the island's cap -- a run of ten
## has no stone face to sit on -- and this screen keeps it so the two boards
## play the same game; widening it is a decision for after the verdict.
const SIZES := [5, 7, 9]

## A line's state, which is what its clue numbers wear.
const LINE_IDLE := 0
const LINE_OK := 1
const LINE_OVER := 2

var w: int = 5
var h: int = 5
var bitmap: Array = []           # [y][x] -> 1 filled, 0 not: the picture
var row_clues: Array = []        # [y] -> Array[int]
var col_clues: Array = []        # [x] -> Array[int]
## The longest clue on each axis, in numbers. The bands are measured from the
## puzzle in hand -- as the island measures its margin of bare platform -- so
## a gentle picture gets a tight board.
var gw: int = 1
var gh: int = 1
## How many cells the picture wants filled, which is what the sprout counts
## down.
var target: int = 0
## Vector2i -> FILL or MARK. A blank cell is simply absent.
var marks: Dictionary = {}
var locked: Dictionary = {}      # Vector2i -> true, a tile a hint grouted in
## One entry per stroke, newest last: [{"cell": Vector2i, "prev": int}].
var history: Array = []

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	var n: int = SIZES[clampi(difficulty, 0, SIZES.size() - 1)]
	w = n
	h = n
	var out: Dictionary = Gen.generate(rng, w, h)
	bitmap = out.bitmap
	row_clues = out.rows
	col_clues = out.cols
	target = 0
	for y in h:
		for x in w:
			target += int(bitmap[y][x])
	gw = 1
	gh = 1
	for clue in row_clues:
		gw = maxi(gw, (clue as Array).size())
	for clue in col_clues:
		gh = maxi(gh, (clue as Array).size())
	marks = {}
	locked = {}
	history = []

# --- reading the board ---

func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < w and cell.y < h

func mark_at(cell: Vector2i) -> int:
	return int(marks.get(cell, BLANK))

## Row `y` as the player has it, ready for Gen.clue_for: 1 filled, 0 not. A
## cross reads as 0, because a cross is a note and not a claim.
func row_line(y: int) -> Array:
	var out: Array = []
	for x in w:
		out.append(1 if mark_at(Vector2i(x, y)) == FILL else 0)
	return out

func col_line(x: int) -> Array:
	var out: Array = []
	for y in h:
		out.append(1 if mark_at(Vector2i(x, y)) == FILL else 0)
	return out

## Green the moment a line's runs read exactly as its clue, rose once it holds
## more filled cells than the clue can account for. Nothing here ever points
## at one cell -- the lines do the talking, and that is the island's decision
## kept unchanged.
static func line_state(line: Array, clue: Array) -> int:
	if Gen.clue_for(line) == clue:
		return LINE_OK
	var have := 0
	for v in line:
		have += int(v)
	var want := 0
	for v in clue:
		want += int(v)
	return LINE_OVER if have > want else LINE_IDLE

func row_state(y: int) -> int:
	return line_state(row_line(y), row_clues[y])

func col_state(x: int) -> int:
	return line_state(col_line(x), col_clues[x])

func filled_count() -> int:
	var n := 0
	for cell in marks:
		if int(marks[cell]) == FILL:
			n += 1
	return n

func cross_count() -> int:
	var n := 0
	for cell in marks:
		if int(marks[cell]) == MARK:
			n += 1
	return n

func tiles_left() -> int:
	return target - filled_count()

func over_lines() -> int:
	var n := 0
	for y in h:
		if row_state(y) == LINE_OVER:
			n += 1
	for x in w:
		if col_state(x) == LINE_OVER:
			n += 1
	return n

func settled_lines() -> int:
	var n := 0
	for y in h:
		if row_state(y) == LINE_OK:
			n += 1
	for x in w:
		if col_state(x) == LINE_OK:
			n += 1
	return n

## The picture, not the clues: a grid matches when every cell agrees with the
## bitmap.
func is_solved() -> bool:
	if bitmap.is_empty():
		return false
	for y in h:
		for x in w:
			if (mark_at(Vector2i(x, y)) == FILL) != (int(bitmap[y][x]) == 1):
				return false
	return true

## The finished picture, not the player's grid: the share is the image.
func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			out += "⬛" if int(bitmap[y][x]) == 1 else "⬜"
		out += "\n"
	return out

# --- moves ---

## Puts `cells` -- [{"cell": Vector2i, "to": int}] -- on the floor as **one**
## entry in the history, which is what makes a painted run one undo. Returns
## the cells that actually changed, so the board can pop just those.
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

## Takes back the last stroke, however many cells it painted. Returns them.
func undo() -> Array:
	if history.is_empty():
		return []
	var entry: Array = history.pop_back()
	var touched: Array = []
	for e in entry:
		_put(e.cell, int(e.prev))
		touched.append(e.cell)
	return touched

## Lays the first tile the picture wants that the player has not, in reading
## order, and grouts it in for good. What came before still describes this
## board, except for the one cell the hint has taken over.
func hint() -> Vector2i:
	var target_cell := Vector2i(-1, -1)
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			if int(bitmap[y][x]) == 1 and mark_at(cell) != FILL:
				target_cell = cell
				break
		if target_cell.x >= 0:
			break
	if target_cell.x < 0:
		return target_cell
	var kept: Array = []
	for entry in history:
		var left: Array = []
		for e in entry:
			if e.cell != target_cell:
				left.append(e)
		if not left.is_empty():
			kept.append(left)
	history = kept
	marks[target_cell] = FILL
	locked[target_cell] = true
	return target_cell

## Every tile the picture does not want. Crosses are never checked: a cross is
## a note, so it is never marked wrong and never counted against the player.
func wrong_tiles() -> Array:
	var out: Array = []
	for cell in marks:
		if int(marks[cell]) != FILL:
			continue
		if int(bitmap[cell.y][cell.x]) == 1:
			continue
		out.append(cell)
	return out

## Clears the floor. Hints are unpinned but not refunded, as on the island.
func reset() -> Array:
	var cleared: Array = marks.keys()
	marks = {}
	locked = {}
	history = []
	return cleared
