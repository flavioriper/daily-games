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
## bookkeeping behind it. On Scrap Basket (Insane) the two part ways: three
## patches are scraps that belong nowhere, so a covered quilt leaves them in
## the basket, and the covered quilt is still the whole of the rule.
##
## **Hard and Insane judge every drop** (the polish, 2026-09-30). The tiling
## is proved unique, so a patch sewn anywhere but an answer place is wrong by
## proof: `drop` refuses it with `WRONG` and rules that spot for that shape
## for good (`ruled`), and a right patch stays where it went (`STAYS`). The
## hearts that a wrong drop costs are the board's to keep, as Bridges' are;
## this class only says right or wrong. Only a board whose proof said unique
## is judged (`ok`) -- a fallback board plays safe.
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
const InsaneBank = preload("res://core/insane_bank.gd")

## Hints and hearts by band (the polish): Easy and Medium get three hints and
## cannot be lost; Hard gets one hint and three hearts, Insane none and two.
## The hearts are the board's to count -- see `judged()`.
const HINTS := [3, 3, 1, 0]
const HEARTS := [0, 0, 0, 2]
## Why a drop or a lift was turned down.
const OK := 0
## A cell of the patch falls off the quilt.
const OFF := 1
## A cell of the patch lands on a patch already sewn on.
const OVER := 2
## That patch was sewn by a hint and may not be moved.
const PINNED := 3
## A judged board: this patch was already tried on this spot and was wrong.
## Refused for free -- the heart was spent the first time.
const RULED := 4
## A judged board: the patch is sewn on right, and a right patch stays.
const STAYS := 5
## A judged board: the drop fitted but is not where the answer has any patch
## of this shape. Nothing is sewn, and the spot is ruled for good.
const WRONG := 6
## The share's squares, one per cloth (`cloth_of`), in `Pal.CLOTH`'s order.
## Eight for eight cloths: every band up to Hard lays eight patches or fewer
## and wears them one a cloth, and Scrap Basket's twelve share them (see
## `_assign_cloths`).
const SQUARES := ["🟨", "🟦", "🟩", "🟥", "🟪", "🟧", "🟫", "⬜"]
## How many cloths there are: `Pal.CLOTH`, and SQUARES one for one.
const CLOTHS := 8
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
## Hints given on top of HINTS (a rewarded video's, core/ads.gd).
var hints_extra := 0
## Derived: cell index -> the patch covering it, -1 for none. Rebuilt after
## every change, never stored and never in history, so an undo that moves a
## patch takes its cover with it without any bookkeeping of its own.
var cover := PackedInt32Array()
## How many cells the quilt has. Cached because `is_solved()` asks on every
## move.
var quilt_cells: int = 0
## 0 Easy .. 3 Insane: which HINTS and HEARTS row this board reads.
var band := 0
## How many patches make the quilt: every patch but the scraps.
var quilt_patches: int = 0
## Judged boards only: patch -> Array of origins a heart proved wrong for it.
## A spot is ruled for every patch of the same shape at once, because two
## alike patches are one choice.
var ruled: Dictionary = {}
## Per patch: its shape key (Gen._shape_key), so alike patches can be found
## without comparing offsets on every question.
var _keys: Array = []
## Per patch: which of the CLOTHS it is cut from -- its colour, print, stitch
## and thread on the board and its square in the share. The patch's own index
## on every band of eight patches or fewer, so those days look as they always
## did; Scrap Basket's twelve are coloured by `_assign_cloths`.
var cloth_of := PackedInt32Array()

## `bank_step` is PuzzleBase.bank_step: how many times New has been pressed
## since the board opened, which walks Insane through its bank.
func setup(rng: RandomNumberGenerator, difficulty: int, bank_step := 0) -> void:
	band = clampi(difficulty, 0, Gen.BANDS.size() - 1)
	var out: Dictionary = {}
	if band == 3:
		# Scrap Basket is dealt from the bank: the miner keeps the boards whose
		# proof walked furthest, which a live deal cannot look for in time. An
		# empty bank or an entry that does not hold together grows a live one.
		out = Gen.from_bank(InsaneBank.pick("quilt", bank_step))
		if out.is_empty() and InsaneBank.size("quilt") > 0:
			push_warning("Quilt: a banked board did not hold together; growing a live one")
	if out.is_empty():
		out = Gen.generate(rng, difficulty)
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
	hints_extra = 0
	ruled = {}
	_keys = []
	recompute()
	_assign_cloths()

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
	return maxi(0, hints_for(band) + hints_extra - hints_used)

## The hints a band starts with.
static func hints_for(b: int) -> int:
	return int(HINTS[clampi(b, 0, HINTS.size() - 1)])

## The hearts a band starts with; 0 is a band that cannot be lost.
static func hearts_for(b: int) -> int:
	return int(HEARTS[clampi(b, 0, HEARTS.size() - 1)])

## The scraps: the patches the answer leaves out (answer -1). Empty on every
## band but Scrap Basket.
func scraps() -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in answer.size():
		if int(answer[p]) < 0:
			out.append(p)
	return out

# ---------------------------------------------------------------- judging

## Whether this board judges every drop: Hard and Insane, and only when the
## generator proved its tiling unique -- without the proof a drop off the
## stored answer might be a different right quilt.
func judged() -> bool:
	return hearts_for(band) > 0 and ok

## Whether patch `p` with its origin on `origin` is where the answer has a
## patch of the same shape. Alike patches are interchangeable, so it is the
## shape that is asked about and not the patch; a scrap is never right. Pure:
## it reads the answer and nothing on the board.
func is_right(p: int, origin: int) -> bool:
	if p < 0 or p >= shapes.size() or origin < 0 or int(answer[p]) < 0:
		return false
	var key := _key(p)
	for q in shapes.size():
		if int(answer[q]) == origin and _key(q) == key:
			return true
	return false

## Rules `origin` wrong for `p` and for every patch of its shape.
func rule(p: int, origin: int) -> void:
	if p < 0 or p >= shapes.size() or origin < 0:
		return
	var key := _key(p)
	for q in shapes.size():
		if _key(q) != key:
			continue
		var list: Array = ruled.get(q, [])
		if not list.has(origin):
			list.append(origin)
		ruled[q] = list

func is_ruled(p: int, origin: int) -> bool:
	return (ruled.get(p, []) as Array).has(origin)

## Try again's half of it: every ruled spot forgotten.
func clear_ruled() -> void:
	ruled = {}

func _key(p: int) -> String:
	if _keys.size() != shapes.size():
		_keys = []
		for q in shapes.size():
			_keys.append(Gen._shape_key(shapes[q]))
	return String(_keys[p])

## The cloth patch `p` is cut from (see `cloth_of`); its own index on a
## board that was never set up through `setup`.
func cloth(p: int) -> int:
	return int(cloth_of[p]) if p >= 0 and p < cloth_of.size() else p

## Hands every patch a cloth. Eight patches or fewer: its own index. More
## (Scrap Basket's nine and three) must repeat, and a repeat is chosen, not
## left to `p % 8` -- which put patch p and p + 8 in one cloth and, in 103 of
## the 150 banked boards, sewed two of them side by side, one patch to the
## eye. So, seeded from the quilt itself so a day always looks the same:
##
## - two quilt patches that touch in the answer never share a cloth (a greedy
##   colouring, backtracked; the quilt's own graph is small);
## - the quilt wears every cloth, so its one repeat is the only one in it;
## - two look-alike patches (one shape) never share one while that can hold;
## - each scrap takes a cloth a quilt patch wears once, so the repeats are
##   spread and a cloth seen twice never singles out a scrap.
##
## That leaves one tiny clue -- a same-cloth pair on Scrap Basket never
## touches in the answer -- accepted, since twelve patches over eight cloths
## must repeat somewhere (spec 2026-09-30-quilt-polish-design.md, section 3).
func _assign_cloths() -> void:
	var n := shapes.size()
	cloth_of = PackedInt32Array()
	cloth_of.resize(n)
	for p in n:
		cloth_of[p] = p
	if n <= CLOTHS or answer.size() != n or cols <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(region) + str(answer) + str(cols))
	# Who touches whom on the finished quilt.
	var owner := PackedInt32Array()
	owner.resize(cols * rows)
	owner.fill(-1)
	var quilt: Array[int] = []
	var scraps_list: Array[int] = []
	for p in n:
		if int(answer[p]) < 0:
			scraps_list.append(p)
			continue
		quilt.append(p)
		for cell in patch_cells(p, int(answer[p])):
			var i := idx(cell.x, cell.y)
			if i >= 0:
				owner[i] = p
	var touch: Array = []
	for p in n:
		touch.append({})
	for r in rows:
		for c in cols:
			var a := int(owner[r * cols + c])
			if a < 0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var j := idx(c + d.x, r + d.y)
				if j < 0:
					continue
				var z := int(owner[j])
				if z >= 0 and z != a:
					(touch[a] as Dictionary)[z] = true
					(touch[z] as Dictionary)[a] = true
	# The most-touching first, ties in the day's own order; each patch tries
	# the cloths in its own shuffled order.
	var rank := {}
	var shuffled := quilt.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	for i in shuffled.size():
		rank[shuffled[i]] = i
	quilt.sort_custom(func(a: int, z: int) -> bool:
		var da := (touch[a] as Dictionary).size()
		var dz := (touch[z] as Dictionary).size()
		return da > dz if da != dz else int(rank[a]) < int(rank[z]))
	var prefs: Array = []
	for p in n:
		var order: Array[int] = []
		for c in CLOTHS:
			order.append(c)
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: int = order[i]
			order[i] = order[j]
			order[j] = tmp
		prefs.append(order)
	var cap := int(ceil(float(n) / float(CLOTHS)))
	var got := PackedInt32Array()
	got.resize(n)
	got.fill(-1)
	var solved := false
	for strict in [true, false]:
		got.fill(-1)
		var used := PackedInt32Array()
		used.resize(CLOTHS)
		if _colour_quilt(quilt, 0, got, used, touch, prefs, cap, strict):
			solved = true
			break
	if not solved:
		return      # identity: a quilt no colouring fits keeps p's own cloth
	# The scraps: cloths the quilt wears once, never two scraps alike.
	var count := PackedInt32Array()
	count.resize(CLOTHS)
	for p in quilt:
		count[got[p]] += 1
	for s in scraps_list:
		var best := -1
		for want in [1, 0, cap - 1]:
			for c: int in prefs[s]:
				if int(count[c]) == want and int(count[c]) < cap:
					best = c
					break
			if best >= 0:
				break
		if best < 0:
			for c: int in prefs[s]:
				if int(count[c]) < cap:
					best = c
					break
		if best < 0:
			best = int(prefs[s][0])
		got[s] = best
		count[best] += 1
	cloth_of = got

## The quilt's colouring, one patch at a time from `k`: touching patches
## differ, no cloth past `cap`, every cloth worn while there are patches
## enough to wear them, and under `strict` two alike shapes differ too.
func _colour_quilt(quilt: Array[int], k: int, got: PackedInt32Array, used: PackedInt32Array,
		touch: Array, prefs: Array, cap: int, strict: bool) -> bool:
	if k >= quilt.size():
		return true
	var p: int = quilt[k]
	var unused := 0
	for c in CLOTHS:
		if int(used[c]) == 0:
			unused += 1
	var left := quilt.size() - k
	# Unworn cloths first, so the quilt wears all eight before any repeats.
	for pass_unused in [true, false]:
		for c: int in prefs[p]:
			if (int(used[c]) == 0) != pass_unused or int(used[c]) >= cap:
				continue
			# A repeat now must still leave enough patches to wear the rest.
			if int(used[c]) > 0 and unused > left - 1:
				continue
			var clash := false
			for q in touch[p]:
				if int(got[q]) == c:
					clash = true
					break
			if not clash and strict:
				for q in quilt:
					if q != p and int(got[q]) == c and _key(q) == _key(p):
						clash = true
						break
			if clash:
				continue
			got[p] = c
			used[c] += 1
			if _colour_quilt(quilt, k + 1, got, used, touch, prefs, cap, strict):
				return true
			got[p] = -1
			used[c] -= 1
	return false

# ------------------------------------------------------------ dead ends

## The quilt's cells nothing covers yet, as a region mask.
func _bare() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(maxi(0, cols * rows))
	for i in out.size():
		if region[i] == 1 and int(cover[i]) < 0:
			out[i] = 1
	return out

## Whether the patches still in the rack can cover the bare cells exactly --
## some of them, so that a scrap left over does not count against it. An
## exact cover counted to one on the bare cells alone, so it answers for the
## board as it stands and not for the answer: a quilt the player is
## finishing another way is finishable. Two cheap refusals go first, the
## rack's cells falling short and a bare cell nothing can reach, because a
## dead end is usually one of those and the search would walk to find it.
##
## Measured on this Mac (2026-09-30) over 1,293 positions of random legal
## drops on all four bands, 1,240 of them dead ends: worst 3.9 ms, and
## `dead_cells` worst 0.9 ms. The proof's own search took 39 ms on an empty
## banked Scrap Basket, which is why this asks `Gen.can_cover` instead.
func finishable() -> bool:
	var bare := _bare()
	var need := 0
	for i in bare.size():
		need += int(bare[i])
	if need == 0:
		return true
	var rack: Array = []
	var have := 0
	for p in shapes.size():
		if int(at[p]) < 0:
			rack.append(shapes[p])
			have += (shapes[p] as Array).size()
	if have < need or not _dead(bare).is_empty():
		return false
	# Every sewn patch on an answer place of its shape: the answer's own
	# remaining patches finish it, and no search is needed. That is every
	# judged board, and most of an easy one that is going well.
	var on_answer := true
	for p in shapes.size():
		if int(at[p]) >= 0 and not is_right(p, int(at[p])):
			on_answer = false
			break
	if on_answer:
		return true
	return Gen.can_cover(cols, rows, bare, rack)

## The bare cells no patch left in the rack can reach: no legal placement of
## any of them covers the cell. What the board pulses at a dead end.
func dead_cells() -> PackedInt32Array:
	return _dead(_bare())

func _dead(bare: PackedByteArray) -> PackedInt32Array:
	var reach := PackedByteArray()
	reach.resize(bare.size())
	var seen := {}
	for p in shapes.size():
		if int(at[p]) >= 0:
			continue
		# Alike patches reach the same cells: one pass a shape.
		var key := _key(p)
		if seen.has(key):
			continue
		seen[key] = true
		var offs: Array = shapes[p]
		for origin in bare.size():
			var oc := origin % cols
			var orr := origin / cols
			var fits := true
			for off in offs:
				var c: int = oc + off.x
				var r: int = orr + off.y
				if c >= cols or r >= rows or bare[r * cols + c] != 1:
					fits = false
					break
			if not fits:
				continue
			for off in offs:
				reach[(orr + off.y) * cols + oc + off.x] = 1
	var out := PackedInt32Array()
	for i in bare.size():
		if bare[i] == 1 and reach[i] == 0:
			out.append(i)
	return out

## Rebuilds `cover` from where the patches are sitting.
func recompute() -> void:
	quilt_patches = 0
	for p in answer.size():
		if int(answer[p]) >= 0:
			quilt_patches += 1
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
## changed) when a hint sewed it, STAYS (nothing changed) when a judged board
## has it sewn on -- every patch on a judged quilt is right, and stays.
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
	if judged():
		return STAYS
	at[p] = -1
	recompute()
	return OK

## Puts patch `p` down and pushes **exactly one** history entry for the whole
## gesture. `origin` below zero sends it to the rack; `from` is the origin it
## was taken off, or -1 when it came out of the rack. OK when it went down,
## else the refusal code (`OFF`, `OVER`, `PINNED`) with nothing changed.
##
## On a judged board a drop that fits is then held against the answer: RULED
## (free) on a spot already proved wrong for this shape, and WRONG on any
## other spot the answer does not have -- the patch stays in the rack and the
## spot is ruled, and the heart is the board's to take. Geometry is asked
## first, so a spot a patch now covers is OVER and not RULED.
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
		if judged():
			if is_ruled(p, origin):
				return RULED
			if not is_right(p, origin):
				rule(p, origin)
				return WRONG
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
## there; PINNED when a hint sewed it; STAYS on a judged board. Only a real
## lift pushes history.
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
		# A scrap has no place to be hinted to, and a patch already on an
		# answer place of its shape is done whichever alike patch's place it
		# took.
		if int(locked[p]) == 1 or int(answer[p]) < 0:
			continue
		if int(at[p]) >= 0 and is_right(p, int(at[p])):
			continue
		var count := legal_origins(p).size()
		if best < 0 or count < fewest:
			best = p
			fewest = count
	if best < 0:
		return {}
	var target := _free_spot(best)
	if target < 0:
		return {}
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

## The answer place of `p`'s shape no alike patch is sitting on right now:
## its own answer when that is free, else the first free one of its shape's
## in index order. -1 when they are all taken, which a quilt patch cannot
## meet, since its shape has as many answer places as it has patches. Picking
## a free place is what keeps a hint from displacing an alike patch that is
## already right -- on a judged board, a patch that has to stay.
func _free_spot(p: int) -> int:
	var key := _key(p)
	var held := {}
	var spots: Array[int] = []
	for q in shapes.size():
		if _key(q) != key:
			continue
		if int(answer[q]) >= 0:
			spots.append(int(answer[q]))
		if q != p and int(at[q]) >= 0:
			held[int(at[q])] = true
	if not held.has(int(answer[p])):
		return int(answer[p])
	for s in spots:
		if not held.has(s):
			return s
	return -1

## Whether Undo has anything to take back. A judged board has nothing: every
## patch on it is right and stays, so its history is never unwound.
func can_undo() -> bool:
	return not judged() and not history.is_empty()

## Takes back the last gesture, a hint's displacement included. Returns what
## changed, for the board to animate -- {"kind": the gesture undone, "moved":
## [{"patch", "from" (where it was), "to" (where it is now)}]} -- or {} when
## the history is empty.
func undo() -> Dictionary:
	if not can_undo():
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
## the board's wave. On a judged board this is Try again's wave too -- the
## right patches go home with the rest -- and `clear_ruled()` is its other
## half.
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
				out += str(SQUARES[cloth(p) % SQUARES.size()])
		out += "\n"
	return out
