extends RefCounted

## Caterpillar's rules, scene-free, as every flat board's are. The board
## (puzzles/caterpillar2d.gd) draws this and nothing else.
##
## The garden is `cols * rows` squares; some carry a numbered leaf and some
## edges between two squares carry a hedge. The player's walk -- the
## caterpillar's body, tail first -- starts on leaf 1 and grows one square at
## a time, side to side or up and down. **Nothing wrong can sit on the board**:
## `why()` refuses a hedge, a leaf out of turn and the last leaf while any
## square is still empty, so the only way to be wrong is to be stuck, and the
## only thing the player needs back is Undo. That is why there is no Check.
##
## Solved when the body covers every square and its head is on the last leaf.
## The generator proves exactly one walk does that.
## Spec: docs/superpowers/specs/2026-09-25-caterpillar-flat-design.md, section 6.

const Gen = preload("res://puzzles/caterpillar_gen.gd")
const InsaneBank = preload("res://core/insane_bank.gd")

## Hints and hearts by band. Hard and Insane are judged: a step that strands
## a square (Hard) or leaves the garden unfinishable (Insane) costs a heart
## and is taken back. Spec: docs/superpowers/specs/2026-10-01-caterpillar-polish-design.md.
const HINTS_BY := [3, 3, 1, 0]
const HEARTS_BY := [0, 0, 0, 2]

## How far a hint grows the answer past the last square that agrees with it:
## to the next leaf, and never more than this many squares.
const HINT_REACH := 4

var cols := 0
var rows := 0
## The answer, cell = y * cols + x.
var path := PackedInt32Array()
## The cell of leaf 1, leaf 2, ...
var leaves := PackedInt32Array()
## Leaf number by cell, 0 for a bare square.
var clue := PackedInt32Array()
var hedges := {}
var unique := true
var difficulty := 0
## Peckish (Insane): the tummy's size in bare squares, 0 on every other band.
## The middle leaves are eaten in any order, and a bare square may only be
## stepped on while the tummy has room; every leaf fills it again.
var hunger := 0
## The masks the judge reads (Gen.context).
var _ctx := {}

## The walk, tail first. Empty before the first press.
var body := PackedInt32Array()
## Every body before a stroke that changed it, for Undo.
var history: Array[PackedInt32Array] = []
## The squares a hint grew. They stay washed gold while the body is on them.
var given := {}

static func hints_for(band: int) -> int:
	return HINTS_BY[clampi(band, 0, HINTS_BY.size() - 1)]

static func hearts_for(band: int) -> int:
	return HEARTS_BY[clampi(band, 0, HEARTS_BY.size() - 1)]

## Insane reads a mined Peckish garden from the bank; without one it deals
## Hard's garden live, plain.
func build(rng: RandomNumberGenerator, band: int, bank_step := 0) -> void:
	difficulty = band
	var g := {}
	if band >= 3:
		g = Gen.from_bank(InsaneBank.pick("caterpillar", bank_step))
	if g.is_empty():
		g = Gen.generate(rng, mini(band, 2) if band >= 3 else band)
	setup(g)

## Lays a generated (or banked) garden out, empty.
func setup(g: Dictionary) -> void:
	cols = g.cols
	rows = g.rows
	path = g.path
	leaves = g.leaves
	unique = g.unique
	hedges = {}
	for e in g.hedges:
		hedges[e] = true
	clue = PackedInt32Array()
	clue.resize(cols * rows)
	for k in leaves.size():
		clue[leaves[k]] = k + 1
	hunger = int(g.get("hunger", 0))
	_ctx = Gen.context(cols, rows, leaves, Array(g.hedges), hunger)
	given = {}
	reset_board()
	history.clear()

func peckish() -> bool:
	return hunger > 0

func judged() -> bool:
	return hearts_for(difficulty) > 0

func size() -> int:
	return cols * rows

func last_leaf() -> int:
	return leaves.size()

func head() -> int:
	return body[body.size() - 1] if not body.is_empty() else -1

## How many leaves the body has eaten; the next one due is this plus one.
func eaten() -> int:
	var k := 0
	for c in body:
		if clue[c] != 0:
			k += 1
	return k

func hedged(a: int, b: int) -> bool:
	return hedges.has(Gen.edge_key(a, b))

func adjacent(a: int, b: int) -> bool:
	return absi(a % cols - b % cols) + absi(a / cols - b / cols) == 1

## How many bare squares the tummy still has room for (Peckish only): its
## size less the bare squares walked since the last leaf.
func tummy() -> int:
	if hunger <= 0:
		return 0
	var k := 0
	for i in range(body.size() - 1, -1, -1):
		if clue[body[i]] != 0:
			break
		k += 1
	return hunger - k

## Why the head may not step onto `n`: "" when it may, else "far", "hedge",
## "order" (a later leaf than the one due), "last" (the last leaf, with a
## square still empty) or, on Peckish, "hungry" (a bare square on an empty
## tummy). The one gate every step goes through.
func why(n: int) -> String:
	var h := head()
	if h < 0 or not adjacent(h, n):
		return "far"
	if hedged(h, n):
		return "hedge"
	var k := clue[n]
	if k == last_leaf() and body.size() + 1 < size():
		return "last"
	if hunger > 0:
		if k == 0 and tummy() <= 0:
			return "hungry"
		return ""
	if k != 0 and k != eaten() + 1:
		return "order"
	return ""

## On a judged band, what a legal step onto `n` would cost: "" nothing,
## "strand" (Hard and Insane: an empty square can no longer be reached, or is
## a dead end that is not the last leaf, or on Peckish no leaf is left within
## the tummy's reach) or "doom" (Insane: any step off the answer -- the
## garden has exactly one walk, so no walk finishes from there).
func judge(n: int) -> String:
	if not judged() or why(n) != "":
		return ""
	if not stranded(n).is_empty() or _starved(n):
		return "strand"
	# Off the answer is fatal only where the walk is proved the only one.
	if difficulty >= 3 and unique and (agreed() < body.size() or path[body.size()] != n):
		return "doom"
	return ""

## The empty squares a step onto `n` would strand: those the head could no
## longer reach, and those left with a single way in that are not the last
## leaf. Empty when it strands nothing.
func stranded(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var free := _free_after(n)
	if free == 0:
		return out
	var c := _ctx
	var w := cols
	var reach := 1 << n
	while true:
		var grown: int = reach | (free & (((reach & int(c.r)) << 1) | (((reach & int(c.l)) >> 1) & int(c.m1)) \
			| ((reach & int(c.d)) << w) | (((reach & int(c.u)) >> w) & int(c.mw))))
		if grown == reach:
			break
		reach = grown
	var g := free | (1 << n)
	for q in size():
		var qb := 1 << q
		if not (free & qb):
			continue
		if not (reach & qb):
			out.append(q)
			continue
		var ways := 0
		for s in [[c.r, 1], [c.l, -1], [c.d, w], [c.u, -w]]:
			if int(s[0]) & qb and g & (1 << (q + int(s[1]))):
				ways += 1
		if ways < 2 and qb != int(c.end_bit):
			out.append(q)
	return out

## Peckish: a step onto `n` after which no leaf is in the tummy's reach.
func _starved(n: int) -> bool:
	if hunger <= 0:
		return false
	var free := _free_after(n)
	if free == 0:
		return false
	var left := hunger if clue[n] != 0 else tummy() - 1
	return not Gen._fed(_ctx, n, free, left)

## The squares still empty once the head has stepped onto `n`.
func _free_after(n: int) -> int:
	var free := 0
	for q in size():
		free |= 1 << q
	for q in body:
		free &= ~(1 << q)
	return free & ~(1 << n)

## The body may start only on leaf 1.
func can_start(c: int) -> bool:
	return body.is_empty() and clue[c] == 1

func start(c: int) -> bool:
	if not can_start(c):
		return false
	body = PackedInt32Array([c])
	return true

func grow(n: int) -> bool:
	if why(n) != "":
		return false
	body.append(n)
	return true

## Cuts the body back so `c` is its head. False when `c` is not on it.
func cut_to(c: int) -> bool:
	var at := body.find(c)
	if at < 0:
		return false
	body.resize(at + 1)
	return true

## Remembers the body a stroke started from, if the stroke changed it.
func commit(before: PackedInt32Array) -> bool:
	if before == body:
		return false
	history.append(before)
	return true

## Puts back one square a judged step laid and the board took back again:
## the body as it was, with nothing in the history.
func take_back() -> void:
	if body.size() > 0:
		body.resize(body.size() - 1)

func can_undo() -> bool:
	return not history.is_empty()

func undo() -> bool:
	if history.is_empty():
		return false
	body = history.pop_back()
	return true

## How many squares from the tail agree with the answer.
func agreed() -> int:
	var i := 0
	while i < body.size() and body[i] == path[i]:
		i += 1
	return i

## Cuts back to the last square that agrees with the answer, then grows the
## answer on to the next leaf, HINT_REACH squares at most. Returns the squares
## it grew, in order; empty when it could do nothing.
func hint() -> PackedInt32Array:
	var grown := PackedInt32Array()
	if is_solved():
		return grown
	history.append(body.duplicate())
	var i := agreed()
	if i == 0:
		body = PackedInt32Array([path[0]])
		grown.append(path[0])
		given[path[0]] = true
	else:
		body.resize(i)
	while body.size() < size() and grown.size() < HINT_REACH:
		var n := path[body.size()]
		body.append(n)
		grown.append(n)
		given[n] = true
		if clue[n] != 0:
			break
	return grown

func reset_board() -> void:
	if not body.is_empty():
		history.append(body.duplicate())
	body = PackedInt32Array()

func is_solved() -> bool:
	return body.size() == size() and size() > 0 and head() == leaves[leaves.size() - 1]
