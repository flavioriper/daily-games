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

## The walk, tail first. Empty before the first press.
var body := PackedInt32Array()
## Every body before a stroke that changed it, for Undo.
var history: Array[PackedInt32Array] = []
## The squares a hint grew. They stay washed gold while the body is on them.
var given := {}

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var g := Gen.generate(rng, difficulty)
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
	reset_board()
	history.clear()

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

## Why the head may not step onto `n`: "" when it may, else "far", "hedge",
## "order" (a later leaf than the one due) or "last" (the last leaf, with a
## square still empty). The one gate every step goes through.
func why(n: int) -> String:
	var h := head()
	if h < 0 or not adjacent(h, n):
		return "far"
	if hedged(h, n):
		return "hedge"
	var k := clue[n]
	if k != 0 and k != eaten() + 1:
		return "order"
	if k == last_leaf() and body.size() + 1 < size():
		return "last"
	return ""

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
