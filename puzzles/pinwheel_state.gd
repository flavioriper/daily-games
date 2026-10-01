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

## Three a board, as every flat board gives -- on Easy and Medium. The
## polish (2026-10-01) gives Hard one and Insane none, and hearts to the two
## bands that judge a tap (`hints_for`, `hearts_for`).
const HINTS := 3
const HINTS_BY := [3, 3, 1, 0]
const HEARTS_BY := [0, 0, 3, 2]
## The share's squares, one per `Pal.CLOTH` index.
##
## A share is only ever taken from a **solved** frame, where by definition no
## cell is bare and none is stained -- so the nine square glyphs Unicode
## ships are not eight cloths plus two states, they are eight cloths with one
## to spare. Giving the eight a distinct glyph each is therefore free, and it
## is what the share is for; bare and stained then share the one left over,
## which costs nothing because a share carrying either cannot happen.
const SQUARES := ["🟨", "🟦", "🟥", "🟩", "🟪", "🟧", "🟫", "⬜"]
## Unfinished, in a share that cannot be taken.
const BARE := "⬛"
const STAINED := BARE

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
## Hints given on top of HINTS (a rewarded video's, core/ads.gd).
var hints_extra := 0
## The band this board was dealt on, and whether a tap is judged on it: on
## Hard and Insane, turning a piece that is **already home** snags it and
## costs a heart (the board spends it; the state only answers `would_snag`).
## Only on a proved board, Quilt's `ok` and Fairy Lights' rule: the stored
## answer is the only one, so a deducing player never has to touch a piece
## that is home -- and every movable piece opens off its answer, so a piece
## is only ever home because the player (or a ribbon) turned it there.
var difficulty := 1
var judged := false
## Insane's ribbons: [{"from": p, "to": q, "sign": 1 or -1}], a forest (a
## piece has at most one ribbon pulling it). Turning `from` tugs `to` one
## step round its own cycle the same way (sign 1) or the other way (a
## crossed ribbon, -1), and on down the ribbons tied to `to`. Empty on every
## other band.
var ribbons: Array = []
## Per piece: [[child, sign], ...], derived from `ribbons` in setup.
var _kids: Array = []
## Per piece: sewn down -- proved home by a snag (a heart's worth) or by a
## hint on a judged board. A sewn piece never moves again until Try again:
## a tap on it is refused for free, a ribbon cannot tug it (nor anything
## tied below it), Reset leaves it home.
var tacked := PackedByteArray()
## Whether the board offers Undo: every band but Insane, where a tug that
## moved four pieces would make it trial and error.
var undo_allowed := true
## Derived: cell index -> how many pieces sit on it. Rebuilt by `recompute()`
## after every change, never stored and never in history.
var cover := PackedInt32Array()
## Per piece: the pin as a cell, so the board does not divide by `cols` on
## every frame.
var _pin_of: Array = []
## Cell index -> the piece pinned there, -1 for none.
var _pinned_at := PackedInt32Array()

static func hints_for(d: int) -> int:
	return int(HINTS_BY[clampi(d, 0, HINTS_BY.size() - 1)])

static func hearts_for(d: int) -> int:
	return int(HEARTS_BY[clampi(d, 0, HEARTS_BY.size() - 1)])

func setup(rng: RandomNumberGenerator, d: int) -> void:
	difficulty = clampi(d, 0, Gen.BANDS.size() - 1)
	var out: Dictionary = Gen.generate(rng, difficulty)
	cols = int(out.cols)
	rows = int(out.rows)
	pins = out.pins
	shapes = out.shapes
	answer = out.answer
	start = out.start
	cloth = out.cloth
	ok = bool(out.unique)
	ribbons = (out.get("ribbons", []) as Array).duplicate(true)
	judged = difficulty >= 2 and ok
	undo_allowed = difficulty < 3
	if cols <= 0 or rows <= 0 or shapes.is_empty():
		push_warning("Pinwheel: no frame could be grown for this seed")
	turned = start.duplicate()
	history = []
	hints_used = 0
	hints_extra = 0
	_pin_of = []
	_pinned_at = PackedInt32Array()
	_pinned_at.resize(maxi(0, cols * rows))
	_pinned_at.fill(-1)
	for p in shapes.size():
		var at := int(pins[p])
		_pin_of.append(cell_of(at))
		if at >= 0 and at < _pinned_at.size():
			_pinned_at[at] = p
	tacked = PackedByteArray()
	tacked.resize(shapes.size())
	_kids = []
	for p in shapes.size():
		_kids.append([])
	for r: Dictionary in ribbons:
		var a := int(r["from"])
		var b := int(r["to"])
		if a >= 0 and a < shapes.size() and b >= 0 and b < shapes.size():
			(_kids[a] as Array).append([b, int(r.get("sign", 1))])
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
	return maxi(0, hints_for(difficulty) + hints_extra - hints_used)

## Whether Insane's ribbons are on this board.
func ribboned() -> bool:
	return not ribbons.is_empty()

## Whether piece `p` is sewn down.
func is_tacked(p: int) -> bool:
	return p >= 0 and p < tacked.size() and tacked[p] != 0

## Whether a tap on `p` would snag on a judged board: it is movable, not
## sewn down, and **already home**. Read off the stored answer, which on a
## proved board is the only one. The board answers it with a heart and a
## tack; `turn()` itself never judges.
func would_snag(p: int) -> bool:
	return judged and p >= 0 and p < shapes.size() and not fixed(p) \
		and not is_tacked(p) and steps_home(p) == 0

## Sews piece `p` down where it is. On the bands with an undo its own history
## entries go with it: what a heart (or a hint) proved home stays home, and
## an undo that turned it off again would sell the proof back.
func tack(p: int) -> void:
	if p < 0 or p >= tacked.size():
		return
	tacked[p] = 1
	var keep: Array = []
	for e: Dictionary in history:
		if int(e["piece"]) == p:
			continue
		# A tug that moved it inside another tap's entry no longer turns it
		# back either.
		if e.has("moves"):
			var moves: Array = []
			for mv: Array in (e["moves"] as Array):
				if int(mv[0]) != p:
					moves.append(mv)
			e["moves"] = moves
		keep.append(e)
	history = keep

## Every piece unpicked: Try again's.
func untack_all() -> void:
	tacked.fill(0)

## The pieces a tap on `p` turns, with how many steps each (1 for `p`
## itself, the ribbons' signs multiplied down for the rest) and how many
## ribbons down from `p` each hangs: [[piece, step, depth], ...], `p` first. A sewn piece is skipped and so is everything tied
## below it -- it does not move, so it tugs nothing.
func tugged(p: int) -> Array:
	var out: Array = [[p, 1, 0]]
	if p < 0 or p >= _kids.size():
		return out
	var stack: Array = [[p, 1, 0]]
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		for k: Array in (_kids[int(top[0])] as Array):
			var q := int(k[0])
			if is_tacked(q) or fixed(q):
				continue
			var step := int(top[1]) * int(k[1])
			out.append([q, step, int(top[2]) + 1])
			stack.append([q, step, int(top[2]) + 1])
	return out

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
##
## On Insane the tap tugs every piece tied below `p` too (`tugged`), and the
## one history entry carries every piece it moved in `moves`, [[piece, from,
## to, step], ...], so an undo (the state keeps one even where the board offers
## none: Reset is built on the same entries) turns them all back.
## A sewn-down piece is refused like a pinned-fast one.
func turn(p: int) -> bool:
	if p < 0 or p >= shapes.size() or fixed(p) or is_tacked(p):
		return false
	var moves: Array = []
	for pair: Array in tugged(p):
		var q := int(pair[0])
		var m: int = (shapes[q] as Array).size()
		var was := int(turned[q])
		turned[q] = posmod(was + int(pair[1]), m)
		moves.append([q, was, int(turned[q]), int(pair[1])])
	recompute()
	history.append({"piece": p, "from": int(moves[0][1]), "to": int(moves[0][2]), "moves": moves})
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
		if fixed(p) or is_tacked(p):
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
	if entry.has("moves"):
		var moves: Array = entry["moves"]
		for k in range(moves.size() - 1, -1, -1):
			var mv: Array = moves[k]
			turned[int(mv[0])] = int(mv[1])
	else:
		turned[p] = int(entry.from)
	recompute()
	return {"piece": p, "from": int(entry.to), "to": int(entry.from)}

## Puts every piece back the way the board opened and **clears the history**
## -- reset is not a gesture and cannot be undone, which is what Queens and
## Quilt both do. Returns one {"piece", "from", "to"} per piece that actually
## moved, for the board's wave.
##
## A sewn-down piece stays home: a heart bought that, and Reset is not Try
## again. (On Insane every piece left is still solvable from there: the
## ribbons are a forest and a sewn piece tugs nothing, so turning each piece
## home from the top of its ribbons down always works.)
func reset() -> Array:
	var moved: Array = []
	for p in shapes.size():
		var was := int(turned[p])
		var home := int(start[p])
		if is_tacked(p):
			continue
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
