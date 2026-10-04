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
## Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md, section 3;
## the polish (hearts, Morning Mist, graded courts):
## docs/superpowers/specs/2026-09-30-queens-polish-design.md.
##
## Morning Mist (Insane): a misty patch takes two queens (`quota`). A queen
## there does not cross her patch until its second queen sits; then the rest
## of it is crossed at once.

const Gen = preload("res://puzzles/queens_gen.gd")
const InsaneBank = preload("res://core/insane_bank.gd")

## What is on a cell. AUTO is a cross a queen laid: seen, and not the
## player's own.
const BLANK := 0
const QUEEN := 1
const CROSS := 2
const AUTO := 3
## Three a board, as every flat board gives; Insane one.
const HINTS := 3
const HINTS_BY_BAND := [3, 3, 3, 1]
## Hard and Insane can be failed: a queen seated where the answer has none
## costs one.
const HEARTS := [0, 0, 0, 1]
## The ladder: easy, medium, hard, insane. The menu opens medium. Hard and
## Insane are read from banks mined on the Mac (content/insane/queens_hard.json
## and queens.json); these sizes are what an empty bank falls back to.
const SIZES := [7, 8, 9, 10]
## Why a seat or a lift was turned down.
const OK := 0
const SEEN := 1
const PINNED := 2
## A cross a heart showed: that seat is empty for sure.
const SHOWN := 3
## The share's squares, one per region index; a crown marks a queen.
const SQUARES := ["🟫", "🟪", "🟦", "🟩", "🟧", "⬜", "🟨", "🟥", "⬛"]

var n: int = 7
var band := 0
## Patch -> how many queens it takes: one, or two for a misty patch.
var quota := PackedInt32Array()
## The misty patches.
var mist: Array = []
## Whether the generator proved the answer the only one; false is playable
## but not a puzzle.
var ok := true
var region: Array = []              # [r][c] -> region index
var solution := PackedInt32Array()  # row -> the answer's column
var queens: Dictionary = {}         # Vector2i -> true
var crosses: Dictionary = {}        # Vector2i -> true, the player's own
var locked: Dictionary = {}         # Vector2i -> true, a queen a hint seated
## Vector2i -> true: a cross a lost heart laid, where a wrong queen sat. It
## stays for good: the heart bought the knowledge.
var shown: Dictionary = {}
## Vector2i -> how many queens see it. Absent means none does. Derived.
var seen: Dictionary = {}
## One entry per gesture, newest last: [{"cell": Vector2i, "prev": int}].
var history: Array = []

func setup(rng: RandomNumberGenerator, difficulty: int, bank_step := 0) -> void:
	band = clampi(difficulty, 0, SIZES.size() - 1)
	n = int(SIZES[band])
	var out: Dictionary = {}
	if band >= 2:
		out = Gen.from_bank(InsaneBank.pick("queens" if band == 3 else "queens_hard", bank_step))
		if not out.is_empty() and not out.ok:
			push_warning("Queens: a banked court did not re-prove; dealing a live one")
			out = {}
	if out.is_empty():
		out = Gen.graded(rng, mini(band, 2), n)
	n = int(out.n)
	region = out.region
	solution = out.solution
	ok = bool(out.ok)
	quota = out.get("quota", PackedInt32Array())
	if quota.is_empty():
		quota.resize(n)
		quota.fill(1)
	mist = out.get("mist", [])
	if region.is_empty():
		n = 0
		push_warning("Queens: no court could be built for this seed")
	queens = {}
	crosses = {}
	locked = {}
	shown = {}
	history = []
	recompute()

## Hearts on this band: Hard and Insane judge every seat.
func judged() -> bool:
	return HEARTS[band] > 0

func has_mist() -> bool:
	return not mist.is_empty()

func is_misty(g: int) -> bool:
	return mist.has(g)

func quota_of(g: int) -> int:
	return int(quota[g]) if g >= 0 and g < quota.size() else 1

## How many queens sit in patch `g`.
func queens_in(g: int) -> int:
	var k := 0
	for q in queens:
		if region_at(q) == g:
			k += 1
	return k

## Whether patch `g` has every queen it takes.
func patch_full(g: int) -> bool:
	return queens_in(g) >= quota_of(g)

## Whether a queen on `cell` is the answer's. On an unproved court nothing
## can be said, and every seat passes.
func right_seat(cell: Vector2i) -> bool:
	return not ok or int(solution[cell.y]) == cell.x

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

## Every cell a queen at `q` rules out on her own: her row, her column,
## her eight neighbours and her patch -- unless the patch is misty, which a
## queen crosses only once its second queen sits (`reach_of`).
func sees(q: Vector2i) -> Array:
	var out: Array = []
	if not in_field(q):
		return out
	var g := region_at(q)
	var whole := quota_of(g) <= 1
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if cell == q:
				continue
			if cell.y == q.y or cell.x == q.x or (whole and int(region[y][x]) == g) \
					or (absi(cell.x - q.x) <= 1 and absi(cell.y - q.y) <= 1):
				out.append(cell)
	return out

## What the court crosses because `q` sits, as it stands now: her own sight,
## and her whole misty patch when she was its second queen. The wave's reach.
func reach_of(q: Vector2i) -> Array:
	var out := sees(q)
	var g := region_at(q)
	if quota_of(g) > 1 and queens.has(q) and patch_full(g):
		for y in n:
			for x in n:
				var cell := Vector2i(x, y)
				if int(region[y][x]) == g and not queens.has(cell) and not out.has(cell):
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
	# A misty patch with every queen it takes crosses the rest of itself.
	for g in mist:
		if not patch_full(g):
			continue
		for y in n:
			for x in n:
				var cell := Vector2i(x, y)
				if int(region[y][x]) == g and not queens.has(cell):
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
	if not crosses.has(cell) or shown.has(cell):
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
	if shown.has(cell):
		return {"ok": false, "why": SHOWN}
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

## One cell of a sweep still under the finger: lays the player's cross on a
## bare `cell` (`on`) or takes the player's cross off it, at once, so the
## court answers the finger as it moves. A stroke is still one move: the
## first cell it changes opens a history entry (`fresh`) and every later one
## joins it. True when the cell changed.
func sweep_step(cell: Vector2i, on: bool, fresh: bool) -> bool:
	var prev := BLANK if on else CROSS
	if on:
		if not _lay_cross(cell):
			return false
	elif not _take_cross(cell):
		return false
	if fresh or history.is_empty():
		history.append([])
	(history[history.size() - 1] as Array).append({"cell": cell, "prev": prev})
	return true

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
		# A full misty patch: its wrong queen makes room.
		var g := region_at(target)
		if quota_of(g) > 1:
			var inside: Array = []
			for q in queens.keys():
				if region_at(q) == g and not lifted.has(q):
					inside.append(q)
			if inside.size() >= quota_of(g):
				for q in inside:
					if not right_seat(q):
						lifted.append(q)
						break
		for q in lifted:
			queens.erase(q)
		crosses.erase(target)
		shown.erase(target)
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

## Every cross the player laid where the answer seats a queen. Check points
## at these on Hard and Insane, where no wrong queen ever stays to be found.
func wrong_crosses() -> Array:
	if not ok:
		return []
	var out: Array = []
	for cell in crosses:
		if not shown.has(cell) and int(solution[cell.y]) == cell.x:
			out.append(cell)
	return out

## A wrong queen on `cell` goes, on Hard and Insane, and a cross takes her
## place for good: the heart has shown the cell empty. Her seat leaves the
## history (it was the newest entry), and so does every entry that touched
## the cell, so no undo can take the cross back.
func reveal(cell: Vector2i) -> void:
	queens.erase(cell)
	crosses[cell] = true
	shown[cell] = true
	var kept: Array = []
	for entry in history:
		var left: Array = []
		for e in entry:
			if e.cell != cell:
				left.append(e)
		if not left.is_empty():
			kept.append(left)
	history = kept
	recompute()

## Clears the player's queens and crosses; a hint's queens and the crosses a
## heart showed stay, and the history goes. `all` (Try again, after the
## hearts ran out) takes the shown crosses too. Returns the cells cleared.
func reset(all := false) -> Array:
	var cleared: Array = []
	for q in queens.keys():
		if not locked.has(q):
			queens.erase(q)
			cleared.append(q)
	for cell in crosses.keys():
		if all or not shown.has(cell):
			crosses.erase(cell)
			cleared.append(cell)
	if all:
		shown = {}
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
	return Gen.legal(region, n, cols, quota)

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
