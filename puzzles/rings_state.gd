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
## **Since 2026-10-04 no band judges** (`HEARTS_BY` is all zero).
##
## **The hand holds a run** (2026-10-16, the user's reference): `lift` takes
## every face-up ring of the top colour lying together (`Gen.run`), and `drop`
## lands as many of them as the peg has room for -- the rest go back where
## they came from. A move in the log is (from, to, rings carried). Insane
## deals the rings under each top face down (`Gen.HIDDEN`); a ring turns face
## up for good once it is a peg's top, or once its peg locks, and neither an
## undo nor a reset turns it back down. Tumble and its bank went the same day.
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md and
## docs/superpowers/specs/2026-10-01-rings-polish-design.md.
## Concept page: docs/brainstorm/concepts.html#rings.

const Gen = preload("res://puzzles/rings_gen.gd")

## Hints and hearts by band (Easy, Medium, Hard, Insane).
const HINTS_BY := [3, 3, 1, 1]
const HEARTS_BY := [0, 0, 0, 0]
## Insane's spare moves over the shortest solve (`moves_budget`): a quarter of
## it, and never fewer than this. 0 on a band that does not count.
const MOVES_SLACK := [0, 0, 0, 0]
const MOVES_SHARE := 0.25
## Kept for the old suite's name: Easy's hints.
const HINTS := 3

var pegs: Array = []
var deal: Array = []
var log: Array[Vector3i] = []
## The run in hand, bottom ring first ([] when the hand is empty), and the
## peg it came off.
var held: Array = []
var held_from := -1
var colours := 6
## The fewest moves the deal is known to sort in: the solver's own line, a
## way home and not the shortest. Read only by a band that counts moves.
var par := 0
var hints_used := 0
## Hints given on top of HINTS (a rewarded video's, core/ads.gd).
var hints_extra := 0
var difficulty := 0
## Kept for the board's dormant hearts: no band judges.
var judged := false
var undo_allowed := true

static func hints_for(band: int) -> int:
	return HINTS_BY[clampi(band, 0, HINTS_BY.size() - 1)]

static func hearts_for(band: int) -> int:
	return HEARTS_BY[clampi(band, 0, HEARTS_BY.size() - 1)]

## The day's deal, proved solvable (Insane's face down). Keeps a duplicate
## of it in `deal` so reset_board() can go back to exactly what was dealt,
## not to one undo at a time.
func build(rng: RandomNumberGenerator, band: int, _bank_step := 0) -> void:
	difficulty = clampi(band, 0, Gen.BANDS.size() - 1)
	take(Gen.deal(rng, difficulty), difficulty, int(Gen.BANDS[difficulty]["colours"]))
	par = 0
	if MOVES_SLACK[difficulty] > 0:
		par = Gen.solve(pegs).size()

## A hand-made deal (the tutorial's pages): `given` pegs, bottom ring first,
## `count` colours, undone and hinted as band `band` is.
func take(given: Array, band: int, count: int) -> void:
	difficulty = clampi(band, 0, Gen.BANDS.size() - 1)
	par = 0
	pegs = []
	deal = []
	for s in given:
		var peg: Array = []
		for c in s:
			peg.append(int(c))
		pegs.append(peg)
		deal.append(peg.duplicate())
	colours = count
	judged = false
	undo_allowed = true
	log = []
	held = []
	held_from = -1
	hints_used = 0
	hints_extra = 0

## Whether a run is in the hand.
func holding() -> bool:
	return not held.is_empty()

## The colour in hand, or -1.
func held_colour() -> int:
	return Gen.top(int(held[0])) if holding() else -1

## Insane's moves for this deal, on a band that counts (none does now): the
## known solve and a quarter more (three at least).
func moves_budget() -> int:
	var least: int = MOVES_SLACK[difficulty]
	if least <= 0 or par <= 0:
		return 0
	return par + maxi(least, int(ceil(par * MOVES_SHARE)))

## A peg nothing comes off again: full and all one colour.
func locked(i: int) -> bool:
	return Gen.locked(pegs[i])

## A run may be lifted off a peg that has one, is not locked, and only when
## the hand is empty.
func can_lift(i: int) -> bool:
	return not holding() and not (pegs[i] as Array).is_empty() and not locked(i)

## Takes the run on top of peg `i` into the hand and turns the ring it
## leaves on top face up. Refused (and `false`) on an empty peg, a locked
## peg, or with a run already in hand.
func lift(i: int) -> bool:
	if not can_lift(i):
		return false
	var src: Array = pegs[i]
	var n := Gen.run(src)
	held_from = i
	held = src.slice(src.size() - n)
	src.resize(src.size() - n)
	_turn_up(i)
	return true

## Puts the run in hand back where it came from. Not a move: the log never
## sees it. The ring it uncovered stays face up.
func put_back() -> void:
	if not holding():
		return
	(pegs[held_from] as Array).append_array(held)
	held = []
	held_from = -1

## How many of the run in hand a drop on `j` would land: as many as `j` has
## room for, onto an empty peg or onto its own colour. 0 when refused.
## Dropping back onto `held_from` is not a drop -- the board calls put_back().
func lands(j: int) -> int:
	if not holding() or j == held_from:
		return 0
	var dst: Array = pegs[j]
	var room := Gen.CAP - dst.size()
	if room <= 0:
		return 0
	if not dst.is_empty() and Gen.top(int(dst.back())) != held_colour():
		return 0
	return mini(held.size(), room)

func can_drop(j: int) -> bool:
	return lands(j) > 0

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

## Lands what fits of the run in hand on peg `j` and puts the rest back on
## the peg it came from. Refused (returns -1) when nothing would land. On
## success, logs the move, clears the hand, and returns the slot the lowest
## landed ring sits in (`log.back().z` is how many landed).
func drop(j: int) -> int:
	var k := lands(j)
	if k == 0:
		return -1
	var dst: Array = pegs[j]
	var slot := dst.size()
	dst.append_array(held.slice(held.size() - k))
	held.resize(held.size() - k)
	var from := held_from
	put_back()
	log.append(Vector3i(from, j, k))
	if locked(j):
		_turn_up_all(j)
	return slot

## Walks the last move back exactly, including one that finished a peg. No
## legality check: it was legal on the way out. Face-up rings stay face up.
func undo() -> Vector3i:
	put_back()
	if log.is_empty():
		return Vector3i(-1, -1, 0)
	var m: Vector3i = log.pop_back()
	var dst: Array = pegs[m.y]
	(pegs[m.x] as Array).append_array(dst.slice(dst.size() - m.z))
	dst.resize(dst.size() - m.z)
	return m

## Turns peg `i`'s top ring face up.
func _turn_up(i: int) -> void:
	var peg: Array = pegs[i]
	if not peg.is_empty():
		peg[peg.size() - 1] = Gen.top(int(peg.back()))

func _turn_up_all(i: int) -> void:
	var peg: Array = pegs[i]
	for k in peg.size():
		peg[k] = Gen.top(int(peg[k]))

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

## Back to the dealt position in one step, not one undo at a time. A ring
## seen face up stays face up: a face-down ring has never moved, so the
## face-down rings at the foot of each peg now are the same rings at the foot
## of the same peg as dealt.
func reset_board() -> void:
	put_back()
	var down: Array = []
	for s: Array in pegs:
		var n := 0
		while n < s.size() and Gen.hidden(int(s[n])):
			n += 1
		down.append(n)
	pegs = []
	for i in deal.size():
		var peg: Array = (deal[i] as Array).duplicate()
		for k in range(int(down[i]), peg.size()):
			peg[k] = Gen.top(int(peg[k]))
		pegs.append(peg)
	log = []

## Plays the solver's own next move, spending one hint. Returns (-1, -1, 0)
## when hints are spent, the board is already solved, or Gen.solve() finds
## nothing (a stuck board, or one past the search budget). Otherwise the move
## goes through lift()/drop() so it is logged and undoable exactly like a tap,
## and is credited only once both have actually succeeded.
func hint() -> Vector3i:
	put_back()
	if hints_used >= hints_for(difficulty) + hints_extra or is_solved():
		return Vector3i(-1, -1, 0)
	var path: Array = Gen.solve(pegs)
	if path.is_empty():
		return Vector3i(-1, -1, 0)
	var m: Vector2i = path[0]
	if not lift(m.x):
		return Vector3i(-1, -1, 0)
	if drop(m.y) == -1:
		put_back()
		return Vector3i(-1, -1, 0)
	hints_used += 1
	return log.back()
