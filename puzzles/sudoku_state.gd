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
const InsaneBank = preload("res://core/insane_bank.gd")

## Three a board, the mock's number, as every flat board gives -- on Easy and
## Medium. The polish (2026-09-30) gives Hard one and Insane none of its own;
## a video hint is still offered once they are spent.
const HINTS := 3
const HINTS_BY_BAND := [3, 3, 1, 0]
## Hard and Insane judge every number as it lands; a wrong one costs a heart
## (spec 2026-09-30-sudoku-polish-design.md, section 1). Nothing else does.
const HEARTS := [0, 0, 0, 2]

## Why a tap was turned down.
const OK := 0
const GIVEN := 1
const FILLED := 2
const EMPTY := 3
## A number a heart has already shown does not belong in that cell.
const RULED := 4
## A judged band's right number stays put: it is known right.
const KEPT := 5

var given := PackedByteArray()     # the puzzle's own digits, 0 where empty
var grid := PackedByteArray()      # what is on the board now, givens included
var notes := PackedInt32Array()    # an N-bit mask a cell
var sol := PackedByteArray()       # the answer
## Newest last. {"cell": int, "prev": int, "notes": int, "struck": PackedInt32Array, "bit": int}
var history: Array = []
var hints_left := HINTS
## Easy 0 to Insane 3.
var band := 0
## Insane's hills, one int a cell: -1 for none, else how many of the four
## cells beside it hold a smaller number (Gen's Hilltops). Empty elsewhere.
var hills := PackedInt32Array()
## cell -> an N-bit mask of the numbers a lost heart showed do not go there.
## Kept for good: the heart bought the knowledge. Try again clears it.
var ruled: Dictionary = {}

## Handed two arguments on purpose: real play always wants generate()'s own
## TIME_BUDGET_MS deadline, and passing a third here would be the state
## quietly overriding a generator decision it has no business overriding.
func setup(rng: RandomNumberGenerator, difficulty: int, bank_step := 0) -> void:
	band = clampi(difficulty, 0, 3)
	# generate() switches Gen to the band's size (six for easy and medium,
	# nine for hard), and everything below reads the size off Gen.
	var out: Dictionary = {}
	if band == 3:
		# Insane is Hilltops, mined on the Mac (tools/insane/sudoku_ladder.gd):
		# a live deal cannot prove what a banked grid asks of a player in
		# time on a phone. An empty bank or an entry that does not hold
		# together deals a live one, carved under a budget.
		out = Gen.from_bank(InsaneBank.pick("sudoku", bank_step))
		if out.is_empty():
			if InsaneBank.size("sudoku") > 0:
				push_warning("Sudoku: a banked grid did not hold together; dealing a live one")
			out = Gen.generate_hills(rng, Gen.HILL_BUDGET_MS)
		hills = out.hills
	else:
		# Hard is banked too (tools/insane/sudoku_hard_ladder.gd): a nine that
		# wants the pencil and never a guess is one dig in eight.
		if band == 2:
			out = Gen.from_bank(InsaneBank.pick("sudoku_hard", bank_step))
		if out.is_empty():
			out = Gen.generate(rng, difficulty)
		hills = PackedInt32Array()
	ruled = {}
	sol = out.solution
	given = out.puzzle
	grid = out.puzzle.duplicate()
	notes = PackedInt32Array()
	notes.resize(Gen.CELLS)
	history = []
	hints_left = int(HINTS_BY_BAND[band])

## Whether this band judges every number as it lands.
func judged() -> bool:
	return int(HEARTS[band]) > 0

func has_hill(i: int) -> bool:
	return not hills.is_empty() and hills[i] >= 0

func is_ruled(i: int, d: int) -> bool:
	return (int(ruled.get(i, 0)) & (1 << (d - 1))) != 0

## A hill's standing over what is on the board now: 1 when it and every cell
## beside it hold a number and the count comes true, -1 when what is there
## already cannot come true, 0 otherwise. Read off the player's own numbers,
## never the answer.
func hill_standing(i: int) -> int:
	if not has_hill(i):
		return 0
	if not Gen.hill_ok(grid, hills, i):
		return -1
	if grid[i] == 0:
		return 0
	for j in Gen.beside(i):
		if grid[j] == 0:
			return 0
	return 1

## Every cell of the grid holding `d` now.
func count_of(d: int) -> int:
	var n := 0
	for i in Gen.CELLS:
		if grid[i] == d:
			n += 1
	return n

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
	if judged() and grid[i] > 0 and grid[i] == sol[i]:
		return KEPT
	if is_ruled(i, d):
		return RULED
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
	if judged() and grid[i] > 0 and grid[i] == sol[i]:
		return KEPT
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

## A judged number was wrong: it comes back out of `i`, its move leaves the
## history (there is nothing to undo -- the heart is spent either way), and
## the number is ruled out of that cell for good.
func reject(i: int) -> void:
	var d := int(grid[i])
	if d == 0:
		return
	for k in range(history.size() - 1, -1, -1):
		if int(history[k].cell) == i:
			var e: Dictionary = history[k]
			history.remove_at(k)
			grid[i] = int(e.prev)
			notes[i] = int(e.notes)
			if int(e.bit) != 0:
				for j in e.struck:
					notes[j] |= int(e.bit)
			break
	if grid[i] == d:
		grid[i] = 0
	ruled[i] = int(ruled.get(i, 0)) | (1 << (d - 1))

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
