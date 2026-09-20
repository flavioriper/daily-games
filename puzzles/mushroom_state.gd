extends RefCounted

## Mushroom Patch's rules, with no scene under them: the field, the answer,
## the numbers a cell was turned over to show, and every mark the player laid
## on top. The flat board (puzzles/mushroom2d.gd) draws this and nothing
## else. Modelled on puzzles/queens_state.gd -- same shape, a simpler board.
##
## **A wrong mark is never refused.** This class knows `mushrooms`, the
## answer, and it would be easy to use it to turn a bad guess down the way
## Queens turns down a seen cell -- and it must not: refusing a wrong
## mushroom would let a player tap every cell in turn and read the answer off
## which ones stuck. The only refusals this file ever hands back are
## structural, never a judgement of right or wrong: a given cell (`GIVEN`,
## there is nothing there to decide), a pinned mushroom being disturbed
## (`PINNED`, a hint's plant is not the player's to take back) and a pebble
## aimed at a planted mushroom (`COVERED`, Queens' rule again -- a pebble must
## never be the thing that lifts a mushroom, so a fat finger cannot undo a
## deduction by accident).
##
## Spec: docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md,
## sections 3 and 9.

const Gen = preload("res://puzzles/mushroom_gen.gd")

## What the player has said about a covered cell.
const BLANK := 0
const FOUND := 1   # the player says: a mushroom is here
const CLEAR := 2   # the player says: nothing is here

## standing()'s answer for a given, read off the player's own marks.
const SHORT := 0    # fewer neighbours planted than the number calls for
const SETTLED := 1  # exactly as many planted as the number calls for
const OVER := 2     # more planted than the number calls for

## Why place() turned a move down. OK covers both success and the harmless
## no-op of tapping an already-pinned mushroom again.
const OK := 0
const GIVEN := 1
const PINNED := 2
const COVERED := 3

## share_glyphs()'s alphabet: a mushroom for a planted cell, a pale square
## for a covered one, and the numeral's own keycap square for a given --
## literally a numeral drawn inside its own square.
const MUSHROOM_GLYPH := "🍄"
const COVERED_GLYPH := "⬜"
const NUMBER_SQUARES := ["0️⃣", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣"]

var n: int = 0
var k: int = 0
var mushrooms: Dictionary = {}  # Vector2i -> true, the answer
var given: Dictionary = {}      # Vector2i -> int, the turned-over numbers
var marks: Dictionary = {}      # Vector2i -> FOUND | CLEAR
var pinned: Dictionary = {}     # Vector2i -> true, what a hint gave
## One entry per gesture, newest last: [{"cell": Vector2i, "prev": int}].
var history: Array = []

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	var idx := clampi(difficulty, 0, Gen.SIZES.size() - 1)
	var size: Array = Gen.SIZES[idx]
	n = int(size[0])
	k = int(size[1])
	var out: Dictionary = Gen.generate(rng, n, k, bool(Gen.SUBSETS[idx]), float(Gen.GIVE_BACK[idx]))
	mushrooms = out.mushrooms
	given = out.given
	# The generator carves a full, solved field down to a minimal set of
	# givens and only keeps a cut while `solvable` still proves the whole
	# field -- a board with a guess in it is never produced. Assert rather
	# than rely on it: this is the one place that contract could be checked.
	assert(bool(out.ok), "Mushroom: generator produced an unsolvable board")
	marks = {}
	pinned = {}
	history = []

# --- reading the field ---

## How many mushrooms neighbour `cell` in the answer -- the number a given
## cell shows.
func count(cell: Vector2i) -> int:
	var c := 0
	for p in Gen.neighbours(cell, n):
		if mushrooms.has(p):
			c += 1
	return c

## How many mushrooms the *player* has planted around `cell`, given or not.
func around(cell: Vector2i) -> int:
	var c := 0
	for p in Gen.neighbours(cell, n):
		if int(marks.get(p, BLANK)) == FOUND:
			c += 1
	return c

## Short, settled or over, read off the player's own marks against the
## given's number. Derived and never stored -- the Queens rule. Meaningless
## for a cell that is not a given, which returns SHORT rather than erroring.
## A given of nought is SETTLED with nothing planted beside it yet and OVER
## the moment one is; the board is what decides not to draw its numeral (a
## drawing decision), never this file.
func standing(cell: Vector2i) -> int:
	if not given.has(cell):
		return SHORT
	var need: int = int(given[cell])
	var have := around(cell)
	if have > need:
		return OVER
	if have == need:
		return SETTLED
	return SHORT

## `mushrooms.size()` minus every FOUND mark on the board, right or wrong.
## Not clamped: an over-planted board hands back a negative number on
## purpose, so the board can say "two too many planted".
func left() -> int:
	var found := 0
	for v in marks.values():
		if int(v) == FOUND:
			found += 1
	return mushrooms.size() - found

## An exact set match between the FOUND marks and the answer -- not a count.
## Planting the right number of mushrooms in the wrong places does not win.
func is_solved() -> bool:
	var found := 0
	for cell in marks:
		if int(marks[cell]) == FOUND:
			if not mushrooms.has(cell):
				return false
			found += 1
	return found == mushrooms.size()

## Every FOUND on a bare cell and every CLEAR on a mushroom -- checked both
## ways, since a wrong pebble is exactly as wrong as a wrong mushroom.
func wrong_marks() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in marks:
		var v: int = int(marks[cell])
		if v == FOUND and not mushrooms.has(cell):
			out.append(cell)
		elif v == CLEAR and mushrooms.has(cell):
			out.append(cell)
	return out

# --- private helpers, no history ---

## Lays a pebble on a bare, unmarked, uncovered cell. True and mutates when
## it did.
func _lay_pebble(cell: Vector2i) -> bool:
	if given.has(cell) or pinned.has(cell):
		return false
	if int(marks.get(cell, BLANK)) != BLANK:
		return false
	marks[cell] = CLEAR
	return true

## Takes the player's own pebble off. True and mutates when it did.
func _take_pebble(cell: Vector2i) -> bool:
	if int(marks.get(cell, BLANK)) != CLEAR:
		return false
	marks.erase(cell)
	return true

# --- moves ---

## Plants or pebbles `cell`. The only refusals are structural (see the file
## comment): GIVEN, PINNED and COVERED. Never a judgement on `v` itself --
## the state does not know or care whether the move is right.
##
## Two toggles fall out of one rule -- placing the mark already there always
## takes it back off: place(cell, FOUND) on a FOUND cell pulls the mushroom
## up, and place(cell, CLEAR) on a CLEAR cell rubs the pebble out. Placing
## the *other* mark simply replaces what was there, the way Queens replaces
## a player's own cross with a queen.
func place(cell: Vector2i, v: int) -> int:
	if given.has(cell):
		return GIVEN
	if pinned.has(cell):
		# A hint's mushroom is always FOUND already. A pebble aimed at it is
		# a disturb attempt and is refused; a mushroom tap on it is simply
		# nothing new to do -- not a refusal, and not a move either, so no
		# history entry.
		if v != FOUND:
			return PINNED
		return OK
	var cur: int = int(marks.get(cell, BLANK))
	if v == CLEAR and cur == FOUND:
		# A pebble never lifts a mushroom -- Queens' rule again, and it keeps
		# a fat finger from undoing a deduction by accident.
		return COVERED
	if cur == v:
		marks.erase(cell)
	else:
		marks[cell] = v
	history.append([{"cell": cell, "prev": cur}])
	return OK

## A sweep of pebbles: lays one on every bare, uncovered cell of `cells`
## (`on`), or takes the player's own pebble off every cell of `cells` that
## has one. One history entry for the lot, so one undo. Returns the cells
## that actually changed -- a given, a pinned mushroom, a planted mushroom
## and an already-bare cell are all silently skipped rather than refused,
## the way a stroke runs past a wall without stopping.
func sweep(cells: Array[Vector2i], on: bool) -> Array[Vector2i]:
	var entry: Array = []
	var changed: Array[Vector2i] = []
	for cell in cells:
		if on:
			if not _lay_pebble(cell):
				continue
			entry.append({"cell": cell, "prev": BLANK})
		else:
			if not _take_pebble(cell):
				continue
			entry.append({"cell": cell, "prev": CLEAR})
		changed.append(cell)
	if not entry.is_empty():
		history.append(entry)
	return changed

## Takes back the last gesture, however many cells it touched. Returns the
## cells it touched.
func undo() -> Array[Vector2i]:
	if history.is_empty():
		return []
	var entry: Array = history.pop_back()
	var touched: Array[Vector2i] = []
	for e in entry:
		var cell: Vector2i = e.cell
		var prev: int = int(e.prev)
		if prev == BLANK:
			marks.erase(cell)
		else:
			marks[cell] = prev
		touched.append(cell)
	return touched

## Lifts every mark the player laid; a hint's plant stays. Clears the
## history along with it. Returns the cells cleared.
func reset_board() -> Array[Vector2i]:
	var cleared: Array[Vector2i] = []
	for cell in marks.keys():
		if not pinned.has(cell):
			cleared.append(cell)
	for cell in cleared:
		marks.erase(cell)
	history = []
	return cleared

## Plants the next unfound mushroom in reading order (sorted by y then x),
## rubbing out a pebble there first, and pins it so it cannot be disturbed.
## Clears the history -- Shikaku's rule: what came before no longer
## describes a board that can be gone back to, so an undo right after a hint
## does nothing. Returns the cell planted, or (-1, -1) when every mushroom
## is already found.
func hint() -> Vector2i:
	var cells: Array = mushrooms.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell in cells:
		if int(marks.get(cell, BLANK)) == FOUND:
			continue
		marks[cell] = FOUND
		pinned[cell] = true
		history = []
		return cell
	return Vector2i(-1, -1)

## One row per line: a mushroom for a planted cell, a pale square for a
## covered one, and the numeral's own keycap square for a given.
func share_glyphs() -> String:
	var out := ""
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if int(marks.get(cell, BLANK)) == FOUND:
				out += MUSHROOM_GLYPH
			elif given.has(cell):
				out += NUMBER_SQUARES[int(given[cell])]
			else:
				out += COVERED_GLYPH
		out += "\n"
	return out
