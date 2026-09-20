extends RefCounted

## Pinwheel's rules, with no scene under them: the frame, the pieces and
## which way round each one is sitting, and every gesture that can turn one.
## The flat board (puzzles/pinwheel2d.gd) draws this and nothing else.
##
## Three things decide how this board feels, and each is worth saying plainly.
##
## **A tap skips, it never refuses.** A piece's orientations are the
## rotations about its pin that lie wholly inside the frame, and the tap
## steps one place round that cycle. The rotations that would leave the frame
## are not in the cycle at all, so they cannot be stepped onto and cannot be
## refused either -- which is the only reason every orientation is reachable
## from every other. A tap that refused an out-of-frame rotation would strand
## a bar pinned at its end two illegal steps from its answer, and neither the
## generator nor any test here would notice. The one real refusal is a piece
## with a single orientation: pinned fast, nowhere to go, `turn()` false.
##
## **Overlap is the working state.** Pieces may sit on top of each other, and
## the frame says so: `cover` counts how many pieces are on each cell, and a
## cell with two is stained. `cover` is **derived and never stored** --
## `recompute()` rebuilds it from where the pieces are after every change,
## exactly as Quilt's `cover` and Queens' `seen` are. That is what makes undo
## keep no book for the stain: turning a piece off a cell takes the stain
## with it because the stain was never a fact, only an arithmetic.
##
## **The pieces' cells sum to the frame's cells**, so "no cell is bare", "no
## cell is stained" and "every cell is under exactly one piece" are one
## sentence. `is_solved()` asks the last of them and never compares against
## the stored answer, because coverage is the rule as the player sees it.
##
## One tap is one history entry and one undo is one tap. A refused tap on a
## pinned-fast piece pushes nothing -- Quilt shipped the mirror image of that
## bug, a `take()` that pushed nothing with no matching `drop()` to follow,
## and it cost a held patch its undo entry. A hint walks a piece all the way
## home and pushes **one** entry carrying the whole journey, so it costs one
## press to take back however many quarters it spent, and `hints_used` is not
## refunded when it is: a hint that has been seen has been spent.
## Spec: docs/superpowers/specs/2026-09-20-pinwheel-flat-design.md, section 6.

const Gen = preload("res://puzzles/pinwheel_gen.gd")

## Three a board, as every flat board gives.
const HINTS := 3
## The share's squares, one per `Pal.CLOTH` index. Unicode ships seven
## coloured squares and this board needs two more for bare and stained, so
## cloths 4 and 7 knowingly share a glyph; a share is only ever offered from
## a solved frame, where the two never stand side by side as themselves.
const SQUARES := ["🟨", "🟦", "🟥", "🟩", "🟪", "🟧", "🟫", "🟪"]
## The share's bare cell, which a solved frame never has.
const BARE := "⬛"
## The share's stained cell, which a solved frame never has either.
const STAINED := "⬜"

var cols: int = 0
var rows: int = 0
## Per piece: the pin's cell index. Never changes for the life of the board.
var pins := PackedInt32Array()
## Per piece: Array[Array[Vector2i]], one entry an in-frame orientation in
## clockwise order, in absolute board cells. Index 0 is the grown one.
var shapes: Array = []
## Per piece: the orientation index that solves the frame.
var answer := PackedInt32Array()
## Per piece: the orientation it opened on.
var start := PackedInt32Array()
## Per piece: its `Pal.CLOTH` index.
var cloth := PackedInt32Array()
## Whether the generator proved the tiling the only one. False is playable;
## see `hint()` for the one place it is read.
var ok := true
## Per piece: the orientation it is on now.
var turned := PackedInt32Array()
## One entry a move, newest last: {"piece": int, "from": int, "to": int}.
var history: Array = []
var hints_used := 0
## Derived: cell index -> how many pieces sit on it. Rebuilt by `recompute()`
## after every change, never stored and never in history.
var cover := PackedInt32Array()
## Per piece: the pin as a cell, so the board does not divide by `cols` on
## every frame.
var _pin_of: Array = []
## Cell index -> the piece pinned there, -1 for none.
var _pinned_at := PackedInt32Array()

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	var out: Dictionary = Gen.generate(rng, difficulty)
	cols = int(out.cols)
	rows = int(out.rows)
	pins = out.pins
	shapes = out.shapes
	answer = out.answer
	start = out.start
	cloth = out.cloth
	ok = bool(out.unique)
	if cols <= 0 or rows <= 0 or shapes.is_empty():
		push_warning("Pinwheel: no frame could be grown for this seed")
	turned = start.duplicate()
	history = []
	hints_used = 0
	_pin_of = []
	_pinned_at = PackedInt32Array()
	_pinned_at.resize(maxi(0, cols * rows))
	_pinned_at.fill(-1)
	for p in shapes.size():
		var at := int(pins[p])
		_pin_of.append(cell_of(at))
		if at >= 0 and at < _pinned_at.size():
			_pinned_at[at] = p
	recompute()

# ------------------------------------------------------------- reading it

## The cell index of (c, r), or -1 off the frame.
func idx(c: int, r: int) -> int:
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return -1
	return r * cols + c

## The cell a cell index names. Never pack a cell as `row * cols + column`
## without bounds-checking the column first: Quilt shipped exactly that and a
## hold one cell off the left edge came back as a legal cell on the far
## right.
func cell_of(i: int) -> Vector2i:
	if cols <= 0 or i < 0:
		return Vector2i(-1, -1)
	return Vector2i(i % cols, i / cols)

## The piece pinned at (c, r), or -1 when no pin is there. This is the
## board's only tap target.
func piece_at_pin(c: int, r: int) -> int:
	var i := idx(c, r)
	if i < 0 or i >= _pinned_at.size():
		return -1
	return int(_pinned_at[i])

## Every piece whose current orientation covers (c, r), ascending. Usually
## none or one; two or more is a stain.
func pieces_over(c: int, r: int) -> Array:
	var out: Array[int] = []
	if idx(c, r) < 0:
		return out
	var want := Vector2i(c, r)
	for p in shapes.size():
		for cell: Vector2i in _orient(p, int(turned[p])):
			if cell == want:
				out.append(p)
				break
	return out

## The cells piece `p` covers in `orientation`, or in the one it is on now
## when that is left at -1. A fresh array each call, so a caller may keep it.
func cells_of(p: int, orientation := -1) -> Array:
	var o := int(turned[p]) if orientation < 0 and p >= 0 and p < turned.size() else orientation
	var cells: Array = _orient(p, o)
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		out.append(cell)
	return out

## The pin of piece `p` as a cell.
func pin_cell(p: int) -> Vector2i:
	if p < 0 or p >= _pin_of.size():
		return Vector2i(-1, -1)
	return _pin_of[p]

## How many pieces are on (c, r): 0 bare, 1 covered, 2 or more stained.
func depth(c: int, r: int) -> int:
	var i := idx(c, r)
	if i < 0 or i >= cover.size():
		return 0
	return int(cover[i])

## Whether piece `p` is pinned fast -- one in-frame orientation and nowhere
## to go. Tapping it is the board's only refusal.
func fixed(p: int) -> bool:
	if p < 0 or p >= shapes.size():
		return true
	return (shapes[p] as Array).size() <= 1

## How many taps piece `p` is from its answer. Zero when it is home.
func steps_home(p: int) -> int:
	if p < 0 or p >= shapes.size():
		return 0
	var m: int = (shapes[p] as Array).size()
	if m <= 0:
		return 0
	return posmod(int(answer[p]) - int(turned[p]), m)

## Every cell under exactly one piece. The rule as the player sees it, and
## never a comparison against the stored answer -- see the header for why the
## two are the same statement here.
func is_solved() -> bool:
	if cover.is_empty():
		return false
	for n: int in cover:
		if n != 1:
			return false
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Rebuilds `cover` from where the pieces are sitting. Called after every
## change, and the reason no gesture has to remember what it stained.
func recompute() -> void:
	cover = PackedInt32Array()
	cover.resize(maxi(0, cols * rows))
	cover.fill(0)
	for p in shapes.size():
		for cell: Vector2i in _orient(p, int(turned[p])):
			var i := idx(cell.x, cell.y)
			if i >= 0:
				cover[i] += 1

# ------------------------------------------------------------------ moves

## Turns piece `p` one quarter clockwise, to its next in-frame orientation.
## False, with nothing changed and **nothing pushed**, when the piece is
## pinned fast; the board answers that with a halo and a shiver, not a
## history entry.
func turn(p: int) -> bool:
	if p < 0 or p >= shapes.size() or fixed(p):
		return false
	var m: int = (shapes[p] as Array).size()
	var was := int(turned[p])
	turned[p] = (was + 1) % m
	recompute()
	history.append({"piece": p, "from": was, "to": int(turned[p])})
	return true

## Walks one wrong piece all the way home and pushes **one** entry for the
## whole journey. Which piece: the one furthest from its answer, because a
## hint that spends three quarter turns is worth more than one that spends a
## single tap the player was one press from making anyway.
##
## Returns {"piece": int, "from": int, "to": int}, or {} when nothing is
## wrong or no hints are left. The `to` is the answer, so the board reads the
## quarters it spent off `posmod(to - from, orientations)`.
##
## **Offered even when `ok` is false**, the way Quilt's is: the stored answer
## is a tiling whatever the proof said, so a hint from it can never leave the
## frame in a state a player could not finish.
func hint() -> Dictionary:
	if hints_left() <= 0 or shapes.is_empty():
		return {}
	var best := -1
	var furthest := 0
	for p in shapes.size():
		if fixed(p):
			continue
		var steps := steps_home(p)
		if steps > furthest:
			best = p
			furthest = steps
	if best < 0:
		return {}
	var was := int(turned[best])
	turned[best] = int(answer[best])
	hints_used += 1
	history.append({"piece": best, "from": was, "to": int(turned[best])})
	recompute()
	return {"piece": best, "from": was, "to": int(turned[best])}

## Takes back the last move, a hint's whole journey included, and returns it
## **inverted** -- {"piece", "from": where it was, "to": where it is now} --
## so the board can swing it back the way it came. {} when there is nothing
## to take back.
##
## `hints_used` deliberately does not come back with it: a hint that has been
## seen has been spent, and refunding it would make Hint free to anyone who
## presses Undo after it. Quilt records the same decision.
func undo() -> Dictionary:
	if history.is_empty():
		return {}
	var entry: Dictionary = history.pop_back()
	var p := int(entry.piece)
	turned[p] = int(entry.from)
	recompute()
	return {"piece": p, "from": int(entry.to), "to": int(entry.from)}

## Puts every piece back the way the board opened and **clears the history**
## -- reset is not a gesture and cannot be undone, which is what Queens and
## Quilt both do. Returns one {"piece", "from", "to"} per piece that actually
## moved, for the board's wave.
func reset() -> Array:
	var moved: Array = []
	for p in shapes.size():
		var was := int(turned[p])
		var home := int(start[p])
		if was == home:
			continue
		turned[p] = home
		moved.append({"piece": p, "from": was, "to": home})
	history = []
	recompute()
	return moved

# ------------------------------------------------------------------ share

## One line a row: a bare cell, a stained cell, or the covering piece's own
## cloth. A solved frame is every cell covered once, so a share taken from
## one is all cloth.
func share_glyphs() -> String:
	var out := ""
	for r in rows:
		for c in cols:
			var n := depth(c, r)
			if n <= 0:
				out += BARE
			elif n > 1:
				out += STAINED
			else:
				var over: Array = pieces_over(c, r)
				var p: int = int(over[0]) if not over.is_empty() else 0
				out += str(SQUARES[int(cloth[p]) % SQUARES.size()])
		out += "\n"
	return out

# ----------------------------------------------------------------- private

## Piece `p`'s cells in orientation `o`, the state's own array. Private
## because it is not a copy; `cells_of` is the one a caller may keep.
func _orient(p: int, o: int) -> Array:
	if p < 0 or p >= shapes.size():
		return []
	var list: Array = shapes[p]
	if list.is_empty():
		return []
	return list[posmod(o, list.size())]
