extends RefCounted

## Quilt's rules, with no scene under them: the quilt's outline, the patches
## and where each one is sitting, and every gesture that can move one. The
## flat board (puzzles/quilt2d.gd) draws this and nothing else.
##
## Three things decide how the board feels and are worth stating plainly.
##
## **Nothing wrong can sit on the quilt.** A drop that falls off the outline
## or onto a patch already sewn on is refused outright, with a reason
## (`OFF`, `OVER`) the board can blush and name, rather than accepted and
## marked wrong later. That is why there is no Check on this screen: there
## would be nothing for it to find.
##
## **So the last patch is the win.** The patches' cells sum exactly to the
## region's cells (the generator grew the region *out of* the patches), and
## every placement on the board is inside the region and disjoint from the
## others, so "every cell of the quilt is covered" and "every patch is on the
## quilt" are the same statement. `is_solved()` asks the first one, because
## that is the rule as the player sees it -- a covered quilt -- and not the
## bookkeeping behind it.
##
## **Patches never rotate.** Nothing here turns a shape, and the board offers
## no gesture that would; a patch's `shapes` entry is its one orientation for
## the life of the board.
##
## A gesture is a move, and one gesture is one undo. A drag is two calls --
## `take` on the press, `drop` on the release -- because the board cannot
## know where a patch is going until the finger lets go, but only `drop`
## pushes history, and it pushes nothing at all when the patch came home to
## where it started. A hint sews one patch and sends every patch in its way
## back to the rack, and that too is one entry and one undo.
## Spec: docs/superpowers/specs/2026-09-20-quilt-flat-design.md, section 3.

const Gen = preload("res://puzzles/quilt_gen.gd")

## Three a board, as every flat board gives.
const HINTS := 3
## Why a drop or a lift was turned down.
const OK := 0
## A cell of the patch falls off the quilt.
const OFF := 1
## A cell of the patch lands on a patch already sewn on.
const OVER := 2
## That patch was sewn by a hint and may not be moved.
const PINNED := 3
## The share's squares, one per patch index. Eight, because band 2 lays
## eight patches and no band lays more.
const SQUARES := ["🟨", "🟦", "🟩", "🟥", "🟪", "🟧", "🟫", "⬜"]
## The share's ground: everything that is not the quilt.
const GROUND := "⬛"

var cols: int = 0
var rows: int = 0
## cols*rows, 1 where the quilt is.
var region := PackedByteArray()
## Per patch: its cells as offsets, normalised so the least x and y are 0.
var shapes: Array = []
## Per patch: the origin cell index the generator's own tiling puts it at.
var answer := PackedInt32Array()
## Whether the generator proved that tiling the only one. False is playable
## but is not a puzzle; see `hint()` for the one place it is read.
var ok := true
## Per patch: -1 in the rack, else the origin cell index it is sewn at.
var at := PackedInt32Array()
## Per patch: 1 when a hint sewed it, and it may not be moved again.
var locked := PackedByteArray()
## One entry per gesture, newest last:
## {"kind": String, "moved": [{"patch": int, "from": int, "to": int}], and on
## a hint "locked": int}.
var history: Array = []
var hints_used := 0
## Derived: cell index -> the patch covering it, -1 for none. Rebuilt after
## every change, never stored and never in history, so an undo that moves a
## patch takes its cover with it without any bookkeeping of its own.
var cover := PackedInt32Array()
## How many cells the quilt has. Cached because `is_solved()` asks on every
## move.
var quilt_cells: int = 0

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	var out: Dictionary = Gen.generate(rng, difficulty)
	cols = int(out.cols)
	rows = int(out.rows)
	region = out.region
	shapes = out.shapes
	answer = out.answer
	ok = bool(out.unique)
	if cols <= 0 or rows <= 0 or shapes.is_empty():
		push_warning("Quilt: no quilt could be grown for this seed")
	quilt_cells = 0
	for idx in region.size():
		if region[idx] == 1:
			quilt_cells += 1
	at = PackedInt32Array()
	at.resize(shapes.size())
	at.fill(-1)
	locked = PackedByteArray()
	locked.resize(shapes.size())
	history = []
	hints_used = 0
	recompute()

# ------------------------------------------------------------- reading it

## The cell index of (c, r), or -1 off the grid. The grid is the region's
## own bounding box, so `cols` and `rows` are the quilt's extent and not the
## band's box.
func idx(c: int, r: int) -> int:
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return -1
	return r * cols + c

## Whether (c, r) is a cell of the quilt. Off the grid is off the quilt.
func in_region(c: int, r: int) -> bool:
	var i := idx(c, r)
	return i >= 0 and region[i] == 1

## The cells a patch would cover with its origin on `origin`, in grid
## coordinates. Cells that fall off the grid are still returned, so a caller
## drawing a refused drop can draw the part that is off it.
func patch_cells(p: int, origin: int) -> Array:
	var out: Array[Vector2i] = []
	if p < 0 or p >= shapes.size() or origin < 0 or cols <= 0:
		return out
	var oc := origin % cols
	var orr := origin / cols
	for off in shapes[p]:
		out.append(Vector2i(oc + int(off.x), orr + int(off.y)))
	return out

## The patch covering (c, r), or -1.
func patch_at_cell(c: int, r: int) -> int:
	var i := idx(c, r)
	return int(cover[i]) if i >= 0 else -1

## Why a drop would be refused, or OK. OFF is tested across every cell
## before OVER is tested at all: a patch hanging half off the quilt and half
## over a neighbour is off the quilt first, which is the more useful thing to
## say and the thing the player can see.
##
## A patch never collides with itself, so nudging a sewn patch one cell along
## is judged against the board without it.
func fits(p: int, origin: int) -> int:
	if p < 0 or p >= shapes.size() or origin < 0:
		return OFF
	var cells := patch_cells(p, origin)
	if cells.is_empty():
		return OFF
	for cell in cells:
		if not in_region(cell.x, cell.y):
			return OFF
	for cell in cells:
		var other := int(cover[cell.y * cols + cell.x])
		if other >= 0 and other != p:
			return OVER
	return OK

## Every origin this patch could legally be sewn at, given the board as it
## stands. A sewn patch's own origin is one of them, because `fits` judges
## the board without it.
func legal_origins(p: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if p < 0 or p >= shapes.size():
		return out
	for origin in cols * rows:
		if fits(p, origin) == OK:
			out.append(origin)
	return out

## How many cells of the quilt are covered.
func covered() -> int:
	var count := 0
	for i in cover.size():
		if int(cover[i]) >= 0:
			count += 1
	return count

## Every cell of the quilt covered. The rule, not the stored answer -- see
## the header for why that is also "every patch sewn on".
func is_solved() -> bool:
	return quilt_cells > 0 and covered() == quilt_cells

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Rebuilds `cover` from where the patches are sitting.
func recompute() -> void:
	cover = PackedInt32Array()
	cover.resize(maxi(0, cols * rows))
	cover.fill(-1)
	for p in shapes.size():
		var origin := int(at[p])
		if origin < 0:
			continue
		for cell in patch_cells(p, origin):
			var i := idx(cell.x, cell.y)
			if i >= 0:
				cover[i] = p

# ------------------------------------------------------------------ moves

## Takes patch `p` off the quilt and pushes **nothing**. This is the press
## half of a drag: the board lifts the patch under the finger before it can
## know where the finger will let go, and the gesture is not a move until it
## does. OK when it came off or was already in the rack, PINNED (and nothing
## changed) when a hint sewed it.
##
## `take` and `drop` are the pair, and the reason the pair exists: with
## `lift` and `place` both pushing, picking a patch up and putting it down
## again cost two undos, and putting it back exactly where it came from cost
## two undos for nothing at all.
func take(p: int) -> int:
	if p < 0 or p >= shapes.size():
		return OK
	if int(locked[p]) == 1:
		return PINNED
	if int(at[p]) < 0:
		return OK
	at[p] = -1
	recompute()
	return OK

## Puts patch `p` down and pushes **exactly one** history entry for the whole
## gesture. `origin` below zero sends it to the rack; `from` is the origin it
## was taken off, or -1 when it came out of the rack. OK when it went down,
## else the refusal code (`OFF`, `OVER`, `PINNED`) with nothing changed.
##
## Two gestures push nothing and still answer OK, because nothing happened:
## rack to rack, and back to exactly where it was taken from.
func drop(p: int, origin: int, from: int) -> int:
	if p < 0 or p >= shapes.size():
		return OFF
	if int(locked[p]) == 1:
		return PINNED
	if origin >= 0:
		var why := fits(p, origin)
		if why != OK:
			return why
	var to := origin if origin >= 0 else -1
	at[p] = to
	recompute()
	if from < 0 and to < 0:
		return OK
	if from == to:
		return OK
	history.append({
		"kind": "place" if to >= 0 else "lift",
		"moved": [{"patch": p, "from": from, "to": to}],
	})
	return OK

## Sews patch `p` with its origin on `origin`: the whole gesture at once, for
## a caller that is not dragging. OK when it went on, else the refusal code,
## and a refusal leaves the patch exactly where it was.
func place(p: int, origin: int) -> int:
	if p < 0 or p >= shapes.size():
		return OFF
	var from := int(at[p])
	var why := take(p)
	if why != OK:
		return why
	why = drop(p, origin, from)
	if why != OK:
		at[p] = from
		recompute()
	return why

## Sends patch `p` back to the rack. OK when it went home or was already
## there; PINNED when a hint sewed it. Only a real lift pushes history.
func lift(p: int) -> int:
	if p < 0 or p >= shapes.size():
		return OK
	var from := int(at[p])
	var why := take(p)
	if why != OK:
		return why
	return drop(p, -1, from)

## Sews the answer's patch the board has not got, and pins it. Which patch:
## the one with the fewest legal placements left, so the hint is spent on the
## patch that is hardest to find a home for rather than on whichever one
## happens to be first in the rack. Every patch in its way is sent back to
## the rack first, so what the hint leaves behind is always a legal board.
##
## Returns {"patch": int, "origin": int, "displaced": Array[int]}, or {} when
## there is nothing to sew or no hints left. A hint is an ordinary move: undo
## takes it back and brings the displaced patches home to where they were,
## and it does not give the hint back.
##
## A hint's own patch can never be displaced by a later hint: it is sitting
## at its answer origin, and the answer is a tiling, so no other patch's
## answer origin overlaps it.
##
## **Unlike Queens, this is offered even when `ok` is false.** There the
## stored answer is one seating of several and a hint from it can contradict
## a queen the player had right. Here the stored answer is a tiling whatever
## the proof said, and the hint lifts everything in its way, so the board it
## leaves is legal and finishable either way -- at worst it has undone work
## that belonged to a different valid tiling, which is a cost the player
## chose by pressing Hint.
func hint() -> Dictionary:
	if hints_left() <= 0 or shapes.is_empty():
		return {}
	var best := -1
	var fewest := 0
	for p in shapes.size():
		if int(locked[p]) == 1 or int(at[p]) == int(answer[p]):
			continue
		var count := legal_origins(p).size()
		if best < 0 or count < fewest:
			best = p
			fewest = count
	if best < 0:
		return {}
	var target := int(answer[best])
	var want := {}
	for cell in patch_cells(best, target):
		want[idx(cell.x, cell.y)] = true
	var displaced: Array[int] = []
	for q in shapes.size():
		if q == best or int(at[q]) < 0:
			continue
		for cell in patch_cells(q, int(at[q])):
			if want.has(idx(cell.x, cell.y)):
				displaced.append(q)
				break
	var moved: Array = [{"patch": best, "from": int(at[best]), "to": target}]
	for q in displaced:
		moved.append({"patch": q, "from": int(at[q]), "to": -1})
		at[q] = -1
	at[best] = target
	locked[best] = 1
	hints_used += 1
	history.append({"kind": "hint", "moved": moved, "locked": best})
	recompute()
	return {"patch": best, "origin": target, "displaced": displaced}

## Takes back the last gesture, a hint's displacement included. Returns what
## changed, for the board to animate -- {"kind": the gesture undone, "moved":
## [{"patch", "from" (where it was), "to" (where it is now)}]} -- or {} when
## the history is empty.
func undo() -> Dictionary:
	if history.is_empty():
		return {}
	var entry: Dictionary = history.pop_back()
	var moved: Array = []
	for m in entry.moved:
		at[int(m.patch)] = int(m.from)
		moved.append({"patch": int(m.patch), "from": int(m.to), "to": int(m.from)})
	# The pin goes with the patch, but `hints_used` deliberately does not:
	# a hint that has been seen has been spent, and undoing it back into the
	# budget would make Hint free to anyone who presses Undo after it.
	if entry.has("locked"):
		locked[int(entry.locked)] = 0
	recompute()
	return {"kind": String(entry.kind), "moved": moved}

## Sends every patch the player sewed back to the rack; a hint's patches
## stay, and the history goes with it -- reset is not a gesture and cannot be
## undone, which is what Queens does. Returns the patches that went home, for
## the board's wave.
func reset() -> Array:
	var home: Array[int] = []
	for p in shapes.size():
		if int(locked[p]) == 1 or int(at[p]) < 0:
			continue
		at[p] = -1
		home.append(p)
	history = []
	recompute()
	return home

## One line per row: the ground off the quilt, and the patch's own colour on
## a covered cell. A bare quilt cell reads as ground, which cannot happen on
## a solved board -- the only board a share is ever offered from.
func share_glyphs() -> String:
	var out := ""
	for r in rows:
		for c in cols:
			var i := r * cols + c
			var p := int(cover[i]) if i < cover.size() else -1
			if region[i] != 1 or p < 0:
				out += GROUND
			else:
				out += str(SQUARES[p % SQUARES.size()])
		out += "\n"
	return out
