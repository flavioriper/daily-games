extends RefCounted

## Queens' rules, with no scene under them: the court's regions, the queens,
## the crosses the player laid, the crosses the queens lay, and every move
## that can change them. The flat board (puzzles/queens2d.gd) draws this and
## nothing else.
##
## Two things decide the game's feel and are worth stating plainly. **A cell
## is crossed while any queen sees it**: `seen` counts, per cell, the queens
## whose row, column, region or eight neighbours it is in, rebuilt after
## every change and never stored, so lifting a queen takes her crosses with
## her and undo needs no bookkeeping for them. **And a crown on a seen cell is
## refused**: the cell is provably unavailable given the queens on the board,
## so the board says so rather than seating a queen that must be wrong. The
## consequence is that two queens can never conflict, and the n-th queen
## seated is the win.
##
## A gesture is a move: a sweep of crosses is one history entry and comes
## back on one undo. The win is checked against the rules (one per row,
## column and region, no two touching) and not against the stored answer;
## the generator proves the two agree.
## Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md, section 3.

const Gen = preload("res://puzzles/queens_gen.gd")

## What is on a cell. AUTO is a cross a queen laid: seen, and not the
## player's own.
const BLANK := 0
const QUEEN := 1
const CROSS := 2
const AUTO := 3
## Three a board, as every flat board gives.
const HINTS := 3
## The ladder: easy, medium, hard. The menu opens medium.
const SIZES := [7, 8, 9]
## Why a seat or a lift was turned down.
const OK := 0
const SEEN := 1
const PINNED := 2
## The share's squares, one per region index; a crown marks a queen.
const SQUARES := ["🟫", "🟪", "🟦", "🟩", "🟧", "⬜", "🟨", "🟥", "⬛"]

var n: int = 7
## Whether the generator proved the answer the only one; false is playable
## but not a puzzle.
var ok := true
var region: Array = []              # [r][c] -> region index
var solution := PackedInt32Array()  # row -> the answer's column
var queens: Dictionary = {}         # Vector2i -> true
var crosses: Dictionary = {}        # Vector2i -> true, the player's own
var locked: Dictionary = {}         # Vector2i -> true, a queen a hint seated
## Vector2i -> how many queens see it. Absent means none does. Derived.
var seen: Dictionary = {}
## One entry per gesture, newest last: [{"cell": Vector2i, "prev": int}].
var history: Array = []

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	n = int(SIZES[clampi(difficulty, 0, SIZES.size() - 1)])
	var out: Dictionary = Gen.generate(rng, n)
	region = out.region
	solution = out.solution
	ok = bool(out.ok)
	if region.is_empty():
		n = 0
		push_warning("Queens: no court could be built for this seed")
	queens = {}
	crosses = {}
	locked = {}
	history = []
	recompute()

# --- reading the court ---

func in_field(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < n and cell.y < n

func region_at(cell: Vector2i) -> int:
	return int(region[cell.y][cell.x]) if in_field(cell) else -1

func mark_at(cell: Vector2i) -> int:
	if queens.has(cell):
		return QUEEN
	if crosses.has(cell):
		return CROSS
	if int(seen.get(cell, 0)) > 0:
		return AUTO
	return BLANK

func is_seen(cell: Vector2i) -> bool:
	return int(seen.get(cell, 0)) > 0

## Every cell a queen at `q` rules out: her row, her column, her region and
## her eight neighbours, without herself.
func sees(q: Vector2i) -> Array:
	var out: Array = []
	if not in_field(q):
		return out
	var g := region_at(q)
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if cell == q:
				continue
			if cell.y == q.y or cell.x == q.x or int(region[y][x]) == g \
					or (absi(cell.x - q.x) <= 1 and absi(cell.y - q.y) <= 1):
				out.append(cell)
	return out

## The king's move between two cells: the ring of the wave a cell is on.
static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func queens_left() -> int:
	return n - queens.size()

## Rebuilds `seen` from the queens on the court.
func recompute() -> void:
	seen = {}
	for q in queens:
		for cell in sees(q):
			seen[cell] = int(seen.get(cell, 0)) + 1

# --- private helpers ---

## Lays a cross on a bare cell in field. True and mutates when it did; does
## not touch history.
func _lay_cross(cell: Vector2i) -> bool:
	if not in_field(cell) or mark_at(cell) != BLANK:
		return false
	crosses[cell] = true
	return true

## Takes a cross off a player-owned cell. True and mutates when it did; does
## not touch history.
func _take_cross(cell: Vector2i) -> bool:
	if not crosses.has(cell):
		return false
	crosses.erase(cell)
	return true

# --- moves ---

## Seats a queen on `cell`. Refused on a seen cell (SEEN); a queen already
## there is nothing to do (OK, not ok). The player's own cross there is
## replaced.
func seat(cell: Vector2i) -> Dictionary:
	if not in_field(cell) or queens.has(cell):
		return {"ok": false, "why": OK}
	if is_seen(cell):
		return {"ok": false, "why": SEEN}
	history.append([{"cell": cell, "prev": mark_at(cell)}])
	crosses.erase(cell)
	queens[cell] = true
	recompute()
	return {"ok": true, "why": OK}

## Takes a queen off `cell`. A hint's queen stays (PINNED).
func lift(cell: Vector2i) -> Dictionary:
	if not queens.has(cell):
		return {"ok": false, "why": OK}
	if locked.has(cell):
		return {"ok": false, "why": PINNED}
	history.append([{"cell": cell, "prev": QUEEN}])
	queens.erase(cell)
	recompute()
	return {"ok": true, "why": OK}

## Lays the player's cross on a bare cell. True when it did.
func cross(cell: Vector2i) -> bool:
	if not _lay_cross(cell):
		return false
	history.append([{"cell": cell, "prev": BLANK}])
	return true

## Takes the player's own cross off. True when it did.
func uncross(cell: Vector2i) -> bool:
	if not _take_cross(cell):
		return false
	history.append([{"cell": cell, "prev": CROSS}])
	return true

## A sweep: lays the player's crosses on every bare cell of `cells` (`on`),
## or takes the player's crosses off every cell of `cells` that has one.
## One history entry for the lot, so one undo. Returns the cells that changed.
func sweep(cells: Array, on: bool) -> Array:
	var entry: Array = []
	var changed: Array = []
	for cell in cells:
		if on:
			if not _lay_cross(cell):
				continue
			entry.append({"cell": cell, "prev": BLANK})
		else:
			if not _take_cross(cell):
				continue
			entry.append({"cell": cell, "prev": CROSS})
		changed.append(cell)
	if not entry.is_empty():
		history.append(entry)
	return changed

## Takes back the last gesture. Returns the cells it touched.
func undo() -> Array:
	if history.is_empty():
		return []
	var entry: Array = history.pop_back()
	var touched: Array = []
	for e in entry:
		var cell: Vector2i = e.cell
		queens.erase(cell)
		crosses.erase(cell)
		match int(e.prev):
			QUEEN: queens[cell] = true
			CROSS: crosses[cell] = true
		touched.append(cell)
	recompute()
	return touched

## Seats the answer's queen in the first row that lacks her and pins her. A
## seated queen who sees that cell is wrong, and is lifted first. Clears the
## history: what came before no longer describes a board that can be gone
## back to. Returns {"cell": the seat, or (-1, -1) when every row has its
## queen, "lifted": the queens taken off}.
## On an unproved court (`ok` false) the stored answer is only one of several
## seatings, not the one, so it cannot be handed out as a hint: this seats
## nothing and returns the empty result at once.
func hint() -> Dictionary:
	if not ok:
		return {"cell": Vector2i(-1, -1), "lifted": []}
	for r in n:
		var target := Vector2i(int(solution[r]), r)
		if queens.has(target):
			continue
		var lifted: Array = []
		for q in queens.keys():
			if sees(q).has(target):
				lifted.append(q)
		for q in lifted:
			queens.erase(q)
		crosses.erase(target)
		queens[target] = true
		locked[target] = true
		history = []
		recompute()
		return {"cell": target, "lifted": lifted}
	return {"cell": Vector2i(-1, -1), "lifted": []}

## Every seated queen the answer does not seat there. Check counts these.
## On an unproved court (`ok` false) the stored answer is only one of several
## seatings, so it cannot be the measure of a wrong seat: nothing is ever
## wrong there, and this returns the empty array at once.
func wrong_queens() -> Array:
	if not ok:
		return []
	var out: Array = []
	for q in queens:
		if int(solution[q.y]) != q.x:
			out.append(q)
	return out

## Clears the player's queens and crosses; a hint's queens stay, and the
## history goes. Returns the cells cleared.
func reset() -> Array:
	var cleared: Array = []
	for q in queens.keys():
		if not locked.has(q):
			queens.erase(q)
			cleared.append(q)
	cleared.append_array(crosses.keys())
	crosses = {}
	history = []
	recompute()
	return cleared

## n queens seated and the rules hold. Checked against the rules, not the
## stored answer.
func is_solved() -> bool:
	if region.is_empty() or queens.size() != n:
		return false
	var cols := PackedInt32Array()
	cols.resize(n)
	cols.fill(-1)
	for q in queens:
		if int(cols[q.y]) >= 0:
			return false
		cols[q.y] = q.x
	return Gen.legal(region, n, cols)

## One row per line: a bee for a queen and a coloured square for every
## other cell, by region, so a shared court carries its regions.
func share_glyphs() -> String:
	var out := ""
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if queens.has(cell):
				out += "🐝"
			else:
				out += str(SQUARES[int(region[y][x]) % SQUARES.size()])
		out += "\n"
	return out
