extends RefCounted

## Rings' rules, scene-free, as every flat board's are: the dealt pegs, the
## log of moves played, and the one thing in the player's hand at a time. The
## board (puzzles/rings2d.gd) only draws this.
##
## **`pegs` is the one truth.** Which peg is locked, which colours are already
## home, whether anything can still move -- none of that is stored anywhere;
## every read walks `pegs` fresh (`locked()`, `home_count()`, `is_solved()`,
## `is_stuck()`). That is what keeps an undo honest: taking a move back can
## never leave a stale highlight behind, because there was never a highlight
## to begin with, only a wash the board recomputes every frame off the pegs
## as they now stand.
##
## **A lift plus its drop is one move, and a put-back is not a move at all.**
## The ring in the hand (`held`, `held_from`) is exactly like a tile lifted
## off a Sudoku cell before it is placed: nothing is logged, nothing is
## undoable, and nothing about `pegs` has changed yet. `log` only grows when
## a drop actually lands the ring on another peg -- which is also the only
## thing `undo()` ever has to walk back, one `Vector2i(from, to)` at a time,
## exactly as it was played.
##
## `hint()` never invents a move: it asks Gen.solve() for the same path a
## full solve would take and plays its first step through drop()'s own path,
## so a hinted move is logged and undoable exactly like a tapped one.
## **Hard and Insane judge** (2026-10-01 polish, `judged`): a drop that would
## leave the pegs unsortable is `would_doom()` -- Gen.verdict() proves it on a
## copy -- and the board takes a heart for it and hops the ring back, so the
## pegs never stand in a dead position on a judged band. Insane is **Tumble**:
## the bank deals six two-tone rings, and `lift()` turns a ring over (Gen.flip)
## so what is in the hand is what it will land as; `put_back()` and `undo()`
## turn it back. No undo and no hints there.
## **Since 2026-10-04 no band judges** (`HEARTS_BY` is all zero, `judged`
## false everywhere; `would_doom` and the worker are left in place, asleep).
## Insane counts moves instead: `moves_budget()` is the deal's shortest solve
## (`par`, the bank's `grade.par`) and a quarter more, and a dead end is the
## player's to notice (docs/agents/flat-screens.md, "Insane counts moves").
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md and
## docs/superpowers/specs/2026-10-01-rings-polish-design.md.
## Concept page: docs/brainstorm/concepts.html#rings.

const Gen = preload("res://puzzles/rings_gen.gd")
const InsaneBank = preload("res://core/insane_bank.gd")

## Hints and hearts by band (Easy, Medium, Hard, Insane).
const HINTS_BY := [3, 3, 1, 0]
const HEARTS_BY := [0, 0, 0, 0]
## Insane's spare moves over the shortest solve (`moves_budget`): a quarter of
## it, and never fewer than this. 0 on a band that does not count.
const MOVES_SLACK := [0, 0, 0, 3]
const MOVES_SHARE := 0.25
## Kept for the old suite's name: Easy's hints.
const HINTS := 3

var pegs: Array = []
var deal: Array = []
var log: Array[Vector2i] = []
var held := -1
var held_from := -1
var colours := 6
## The fewest moves the deal can be sorted in, from the bank (`grade.par`,
## breadth-first in tools/insane/rings_tumble_mine.py). Without one, the
## solver's own line: a way home, not the shortest. 0 on a hand-made deal.
var par := 0
var hints_used := 0
## Hints given on top of HINTS (a rewarded video's, core/ads.gd).
var hints_extra := 0
var difficulty := 0
## Hard and Insane: a dooming drop costs a heart (would_doom).
var judged := false
## Insane from the bank: two-tone rings that turn over when lifted.
var tumble := false
var undo_allowed := true
## The judge's answers for the ring in hand, worked out on a worker thread
## from the moment it is lifted (`prejudge`): peg -> whether a drop there
## dooms. A verdict is a search of 10-15 ms on Insane on this Mac, and it was
## paid inside the drop's tap (the 2026-10-02 checkup); a player takes longer
## than that between lifting a ring and dropping it.
var _judge_task := -1
var _judge_out: Dictionary = {}
var _judge_for := ""

static func hints_for(band: int) -> int:
	return HINTS_BY[clampi(band, 0, HINTS_BY.size() - 1)]

static func hearts_for(band: int) -> int:
	return HEARTS_BY[clampi(band, 0, HEARTS_BY.size() - 1)]

## The day's deal, proved solvable. Keeps a duplicate of it in `deal` so
## reset_board() can go back to exactly what was dealt, not to one undo at a
## time. Insane (band 3) reads a Tumble deal from the bank
## (content/insane/rings.json, mined and proved by
## tools/insane/rings_tumble_mine.py); without one it deals Hard live, plain.
func build(rng: RandomNumberGenerator, band: int, bank_step := 0) -> void:
	difficulty = clampi(band, 0, Gen.BANDS.size() - 1)
	tumble = false
	par = 0
	var banked: Dictionary = InsaneBank.pick("rings", bank_step) if difficulty == 3 else {}
	if banked.get("pegs") is Array:
		var grade: Dictionary = banked.get("grade", {})
		par = int(grade.get("par", grade.get("line", 0)))
		pegs = []
		for s in banked["pegs"]:
			var peg: Array = []
			for c in s:
				peg.append(int(c))
				if int(c) >= 8:
					tumble = true
			pegs.append(peg)
	else:
		pegs = Gen.deal(rng, difficulty)
	if MOVES_SLACK[difficulty] > 0 and par <= 0:
		par = Gen.solve(pegs).size()
	deal = []
	for s in pegs:
		deal.append((s as Array).duplicate())
	colours = int(Gen.BANDS[difficulty]["colours"])
	judged = hearts_for(difficulty) > 0
	undo_allowed = difficulty < 3
	log = []
	held = -1
	held_from = -1
	hints_used = 0
	hints_extra = 0

## A hand-made deal (the tutorial's pages): `given` pegs, bottom ring first,
## `count` colours, judged, undone and hinted as band `band` is.
func take(given: Array, band: int, count: int) -> void:
	settle_judge()
	difficulty = clampi(band, 0, Gen.BANDS.size() - 1)
	tumble = false
	par = 0
	pegs = []
	deal = []
	for s in given:
		var peg: Array = []
		for c in s:
			peg.append(int(c))
			if int(c) >= 8:
				tumble = true
		pegs.append(peg)
		deal.append(peg.duplicate())
	colours = count
	judged = hearts_for(difficulty) > 0
	undo_allowed = difficulty < 3
	log = []
	held = -1
	held_from = -1
	hints_used = 0
	hints_extra = 0

## Insane's moves for this deal: the shortest solve and a quarter more (three
## at least), every drop on another peg costing one. 0 on a band that does
## not count, and on a deal with no known solve.
func moves_budget() -> int:
	var least: int = MOVES_SLACK[difficulty]
	if least <= 0 or par <= 0:
		return 0
	return par + maxi(least, int(ceil(par * MOVES_SHARE)))

## A peg nothing comes off again: full and all one colour.
func locked(i: int) -> bool:
	return Gen.locked(pegs[i])

## A ring may be lifted off a peg that has one, is not locked, and only when
## the hand is empty.
func can_lift(i: int) -> bool:
	return held == -1 and not (pegs[i] as Array).is_empty() and not locked(i)

## Takes the top ring off peg `i` into the hand, turned over (a Tumble ring
## shows its under colour now; a plain ring is itself). Refused (and `false`)
## on an empty peg, a locked peg, or with a ring already in hand.
func lift(i: int) -> bool:
	if not can_lift(i):
		return false
	held_from = i
	held = Gen.flip(int((pegs[i] as Array).pop_back()))
	return true

## Puts the ring in hand back where it came from. Not a move: the log never
## sees it.
func put_back() -> void:
	if held == -1:
		return
	(pegs[held_from] as Array).append(Gen.flip(held))
	held = -1
	held_from = -1

## A drop is legal onto an empty peg or onto its own colour top, and refused
## on a full peg of another colour. Dropping back onto `held_from` is not a
## drop at all -- the board calls put_back() for that.
func can_drop(j: int) -> bool:
	if held == -1:
		return false
	var dst: Array = pegs[j]
	if dst.size() >= Gen.CAP:
		return false
	return dst.is_empty() or Gen.top(int(dst.back())) == Gen.top(held)

## On a judged band: whether dropping the held ring on `j` would leave the
## pegs unsortable -- proved on a copy (Gen.verdict() == 0). A search that
## runs out of nodes is not a proof, and is let through.
func would_doom(j: int) -> bool:
	if not judged or not can_drop(j):
		return false
	if _judge_task >= 0 and _judge_for == _judge_sig():
		settle_judge()
		if _judge_out.has(j):
			return _judge_out[j]
	var copy: Array = []
	for s in pegs:
		copy.append((s as Array).duplicate())
	(copy[j] as Array).append(held)
	return not Gen.solved(copy) and Gen.verdict(copy, Gen.DOOM_BUDGET) == 0

## Starts judging every drop the ring in hand could make, off the main
## thread; `would_doom` reads the answers (waiting for them if it must).
## Nothing on a band that is not judged or with an empty hand.
func prejudge() -> void:
	settle_judge()
	_judge_out = {}
	if not judged or held == -1:
		return
	var base: Array = []
	for s in pegs:
		base.append((s as Array).duplicate())
	_judge_for = _judge_sig()
	_judge_task = WorkerThreadPool.add_task(_judge_all.bind(base, held, held_from, _judge_out))

## Waits for a judge still at work (a deal or a board going away must not
## leave one running).
func settle_judge() -> void:
	if _judge_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_judge_task)
		_judge_task = -1

## What the answers are for: the pegs and the ring in hand.
func _judge_sig() -> String:
	return "%d|%d|%s" % [held, held_from, Gen.key(pegs)]

## The worker: `would_doom` for every peg `ring` may land on, on copies.
static func _judge_all(base: Array, ring: int, from: int, out: Dictionary) -> void:
	for j in base.size():
		var dst: Array = base[j]
		if j == from or dst.size() >= Gen.CAP or not (dst.is_empty() or Gen.top(int(dst.back())) == Gen.top(ring)):
			continue
		var copy: Array = []
		for s in base:
			copy.append((s as Array).duplicate())
		(copy[j] as Array).append(ring)
		out[j] = not Gen.solved(copy) and Gen.verdict(copy, Gen.DOOM_BUDGET) == 0

## Why a drop on `j` would be refused right now, or "" when it would not be.
## Exactly these two keys (RG_FULL, RG_WRONG_COLOUR); the board puts them
## on the tip card through tr().
func refusal(j: int) -> String:
	if can_drop(j):
		return ""
	var dst: Array = pegs[j]
	if dst.size() >= Gen.CAP:
		return "RG_FULL"
	return "RG_WRONG_COLOUR"

## Lands the held ring on peg `j`. Refused (returns -1) when nothing is held
## or can_drop(j) is false. On success, logs the move, clears the hand, and
## returns the slot index the ring landed in.
func drop(j: int) -> int:
	if not can_drop(j):
		return -1
	var dst: Array = pegs[j]
	var slot := dst.size()
	dst.append(held)
	log.append(Vector2i(held_from, j))
	held = -1
	held_from = -1
	return slot

## Walks the last move back exactly, including one that finished a peg. No
## legality check: it was legal on the way out.
func undo() -> Vector2i:
	put_back()
	if log.is_empty():
		return Vector2i(-1, -1)
	var m: Vector2i = log.pop_back()
	var ring := int((pegs[m.y] as Array).pop_back())
	(pegs[m.x] as Array).append(Gen.flip(ring))
	return m

## Locked pegs, counted fresh every time -- the colours already home.
func home_count() -> int:
	var n := 0
	for s in pegs:
		if Gen.locked(s):
			n += 1
	return n

func is_solved() -> bool:
	return Gen.solved(pegs)

## Not solved, and nothing legal to play. Two loops (is_solved, moves_from)
## and no solver -- that is the point: a stuck board is cheap to notice, a
## solvable one is not free to prove.
func is_stuck() -> bool:
	return not is_solved() and Gen.moves_from(pegs).is_empty()

## Back to the dealt position in one step, not one undo at a time.
func reset_board() -> void:
	pegs = []
	for s in deal:
		pegs.append((s as Array).duplicate())
	log = []
	held = -1
	held_from = -1

## Plays the solver's own next move, spending one of HINTS. Returns (-1, -1)
## when hints are spent, the board is already solved, or Gen.solve() finds
## nothing (a stuck board, or one past the search budget). Otherwise the move
## goes through lift()/drop() so it is logged and undoable exactly like a tap.
##
## Self-guards the way undo() does: put_back() first, so a ring already in
## hand when hint() is called cannot leave lift() silently refusing (held
## already set) while drop() tests can_drop against the *stale* held colour
## instead of the solver's. And a hint is only ever credited once lift() and
## drop() have both actually succeeded -- the board must never be told a move
## happened when it did not, nor lose a count for one that never played.
func hint() -> Vector2i:
	put_back()
	if hints_used >= hints_for(difficulty) + hints_extra or is_solved():
		return Vector2i(-1, -1)
	var path: Array = Gen.solve(pegs)
	if path.is_empty():
		return Vector2i(-1, -1)
	var m: Vector2i = path[0]
	if not lift(m.x):
		return Vector2i(-1, -1)
	if drop(m.y) == -1:
		put_back()
		return Vector2i(-1, -1)
	hints_used += 1
	return m
