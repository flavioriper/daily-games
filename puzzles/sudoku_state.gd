extends RefCounted

## Sudoku's rules, with no scene under them: the givens, what is on the board
## now, the pencil marks, the answer, and every move that can change them.
## The flat board (puzzles/sudoku2d.gd) draws this and nothing else.
##
## **Everything the screen washes is derived on every read and never stored**
## -- the peers, the twins, the clashes, which units are finished, how many
## of a digit are left. That is Queens' rule, and it is the reason undo
## cannot leave a stale highlight behind: there is no highlight to leave.
##
## **A wrong digit is allowed to stand.** Nothing here refuses a move that
## clashes; spotting your own mistake is the game, and `wrong()` is what
## Check spends its count on. The only refusals are a digit at a given and a
## pencil mark at a cell that is not empty.
##
## The one piece of real bookkeeping is that **placing a digit strikes it off
## every peer's pencil marks and undo puts every one of them back**, which is
## what `struck` in a history entry is for.
## Spec: docs/superpowers/specs/2026-09-20-sudoku-flat-design.md, section 7.

const Gen = preload("res://puzzles/sudoku_gen.gd")

## Three a board, the mock's number, as every flat board gives.
const HINTS := 3

## Why a tap was turned down.
const OK := 0
const GIVEN := 1
const FILLED := 2
const EMPTY := 3

var given := PackedByteArray()     # the puzzle's own digits, 0 where empty
var grid := PackedByteArray()      # what is on the board now, givens included
var notes := PackedInt32Array()    # an N-bit mask a cell
var sol := PackedByteArray()       # the answer
## Newest last. {"cell": int, "prev": int, "notes": int, "struck": PackedInt32Array, "bit": int}
var history: Array = []
var hints_left := HINTS

## Handed two arguments on purpose: real play always wants generate()'s own
## TIME_BUDGET_MS deadline, and passing a third here would be the state
## quietly overriding a generator decision it has no business overriding.
func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	# generate() switches Gen to the band's size (six for easy and medium,
	# nine for hard), and everything below reads the size off Gen.
	var out: Dictionary = Gen.generate(rng, difficulty)
	sol = out.solution
	given = out.puzzle
	grid = out.puzzle.duplicate()
	notes = PackedInt32Array()
	notes.resize(Gen.CELLS)
	history = []
	hints_left = HINTS

# --- reading the board. None of this is cached. ---

func is_given(i: int) -> bool:
	return given[i] > 0

func has_note(i: int, d: int) -> bool:
	return (notes[i] & (1 << (d - 1))) != 0

## N minus how many of `d` are on the board.
func remaining(d: int) -> int:
	var n := Gen.N
	for i in Gen.CELLS:
		if grid[i] == d:
			n -= 1
	return n

## Every other cell holding the same digit as `i`. Empty when `i` is empty.
func twins(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var d := grid[i]
	if d == 0:
		return out
	for j in Gen.CELLS:
		if j != i and grid[j] == d:
			out.append(j)
	return out

## Every cell whose digit is repeated somewhere it can see. A set, because
## the board asks it per cell while drawing.
func clashes() -> Dictionary:
	var out: Dictionary = {}
	for i in Gen.CELLS:
		if grid[i] == 0:
			continue
		for j in Gen.peers_of(i):
			if grid[j] == grid[i]:
				out[i] = true
				out[j] = true
	return out

func unit_done(u: PackedInt32Array) -> bool:
	var mask := 0
	for i in u:
		if grid[i] == 0:
			return false
		mask |= 1 << (grid[i] - 1)
	return mask == Gen.FULL

## One bool per unit, in `Gen.units()` order. The board takes this before a
## move and diffs it after, which is how the wave knows what has just come
## right without any move having to say so.
func finished_units() -> Array:
	var out: Array = []
	for u in Gen.units():
		out.append(unit_done(u))
	return out

## Every non-given cell whose digit differs from the answer. What Check names.
func wrong() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in Gen.CELLS:
		if given[i] == 0 and grid[i] > 0 and grid[i] != sol[i]:
			out.append(i)
	return out

func is_solved() -> bool:
	for i in Gen.CELLS:
		if grid[i] != sol[i]:
			return false
	return true

# --- the three moves, and nothing else writes ---

## A digit into a cell. The same digit already there takes it out again,
## which is why there is no eraser chip in the tray.
func place(i: int, d: int) -> int:
	if given[i] > 0:
		return GIVEN
	var entry := {"cell": i, "prev": int(grid[i]), "notes": int(notes[i]),
		"struck": PackedInt32Array(), "bit": 0}
	if grid[i] == d:
		grid[i] = 0
	else:
		_write(i, d, entry)
	history.append(entry)
	return OK

func mark(i: int, d: int) -> int:
	if given[i] > 0:
		return GIVEN
	if grid[i] > 0:
		return FILLED
	history.append({"cell": i, "prev": int(grid[i]), "notes": int(notes[i]),
		"struck": PackedInt32Array(), "bit": 0})
	notes[i] ^= 1 << (d - 1)
	return OK

## Take out whatever the player put in `i`, digit or pencil marks: the pad's
## remove chip. Refused at a given and at a cell with nothing to take.
func erase(i: int) -> int:
	if given[i] > 0:
		return GIVEN
	if grid[i] == 0 and notes[i] == 0:
		return EMPTY
	history.append({"cell": i, "prev": int(grid[i]), "notes": int(notes[i]),
		"struck": PackedInt32Array(), "bit": 0})
	grid[i] = 0
	notes[i] = 0
	return OK

## The cell put back, or -1 when there was nothing to undo.
func undo() -> int:
	if history.is_empty():
		return -1
	var e: Dictionary = history.pop_back()
	var i := int(e.cell)
	grid[i] = int(e.prev)
	notes[i] = int(e.notes)
	var bit := int(e.bit)
	if bit != 0:
		for j in e.struck:
			notes[j] |= bit
	return i

## One cell from the answer: whichever open cell has the fewest candidates,
## so a hint lands where the player was closest rather than at random. The
## cell filled, or -1 when there is nothing left to fill or no hints left.
func hint() -> int:
	if hints_left <= 0:
		return -1
	var best := -1
	var best_n := Gen.N + 1
	for i in Gen.CELLS:
		if grid[i] == sol[i]:
			continue
		var m := Gen.FULL
		for j in Gen.peers_of(i):
			if grid[j] > 0:
				m &= ~(1 << (grid[j] - 1))
		var n: int = Gen.popcount(m)
		if n < best_n:
			best_n = n
			best = i
	if best < 0:
		return -1
	var entry := {"cell": best, "prev": int(grid[best]), "notes": int(notes[best]),
		"struck": PackedInt32Array(), "bit": 0}
	_write(best, int(sol[best]), entry)
	history.append(entry)
	hints_left -= 1
	return best

## Back to the givens: no digits, no marks, no history. Reset, not undo.
func clear_board() -> void:
	for i in Gen.CELLS:
		if given[i] == 0:
			grid[i] = 0
			notes[i] = 0
	history = []

## Put `d` in `i`, drop the cell's own marks, and strike `d` off every peer
## that had it pencilled -- recording each strike in `entry` so undo can put
## them back. The shared half of `place` and `hint`.
func _write(i: int, d: int, entry: Dictionary) -> void:
	var bit := 1 << (d - 1)
	grid[i] = d
	notes[i] = 0
	var struck := PackedInt32Array()
	for j in Gen.peers_of(i):
		if (notes[j] & bit) != 0:
			notes[j] &= ~bit
			struck.append(j)
	entry.struck = struck
	entry.bit = bit
