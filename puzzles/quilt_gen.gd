extends RefCounted

## Quilt's generator: grow the answer, then prove nothing else covers the
## same shape. There is no search for a puzzle here -- the puzzle *is*
## whatever a grown region and its own patches turn out to imply, because the
## patches are the only clue and the region is the only constraint. So the
## two questions left after a grow are whether a second tiling exists, and
## whether the search that answered that was worth walking.
##
## The genre ships elsewhere as Blocos, and as Block Fit. **This comment and
## the spec's own opening are the only places either name may appear**, and
## both exist to forbid them rather than to record them:
## in this repo the board is Quilt, in code, in a comment and on screen, the
## way Mastermind is Code Break and Hashiwokakero is Bridges. Nothing else
## repeats them.
##
## **Patches never rotate**, and that is the whole of the difficulty. A
## rotating patch would make almost every region tileable a dozen ways and
## uniqueness would stop being worth proving; pinned to one orientation, a
## six-patch quilt is usually rigid and occasionally not, which is exactly
## the margin the proof below is for.
##
## **The grow.** Seed a cell anywhere in the band's box and accrete a
## polyomino of a drawn size from it; then, for each patch after the first,
## seed on an empty cell that already touches the region and accrete again.
## The region comes out connected by construction, which is why nothing here
## ever checks for it. Three rejections shape what survives:
##
## - a patch whose bounding box runs past MAX_SPAN in either direction,
##   because one rack cell serves every patch on the board and the rack's
##   two shelves are bounded in height, so one very tall patch would be paid
##   for by shrinking all of them (`quilt2d.gd`, `_rack_cell`);
## - a finished region enclosing an empty cell with no orthogonal way out of
##   the box, because a hole in the quilt reads as a mistake in the drawing
##   rather than as part of the shape (and, on a board where the only clue is
##   the outline, a mistake the player will spend time on);
## - a region whose own bounding box fills neither dimension of the band's
##   box, because a 7x7 band that comes back 4x4 is a smaller board drawn on
##   a bigger one.
##
## The region is then translated onto its own bounding box, and the answer's
## origins are translated with it, so `cols` and `rows` are the shape's own
## extent and never the band's.
##
## **The proof.** `count_tilings` is a plain exact cover: take the first
## uncovered cell in scan order and try every translation of every *distinct*
## remaining patch that covers it. Distinct is the load-bearing word. Two
## identical patches swapping places is the same quilt, so the multiset is
## grouped by shape and a group is spent rather than a patch. Without that
## grouping a board holding two alike tetrominoes would count two tilings for
## its one quilt, and every such board -- which is most of them, since the
## sizes are drawn from a set of two or three -- would be thrown away as
## ambiguous.
##
## **The grade is the proof's own cost.** `nodes`, the number of search nodes
## the count-to-two walked, is a free measure of how much backtracking the
## region forces on someone working it out, so it is the only grading signal
## here: band 0 refuses a board above EASY_NODES and band 2 refuses one below
## HARD_NODES. Both thresholds were read off a measured run rather than
## guessed; see their own lines.
##
## Seeded only by the `rng` handed in, so a day is the same quilt on every
## phone. Spec: docs/superpowers/specs/2026-09-20-quilt-flat-design.md,
## section 4.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## The three bands: the box the region is grown inside, how many patches, and
## the sizes a patch is drawn from. The sizes are deliberately tight against
## the box -- band 0's five patches want 20 to 25 cells of a 25-cell box --
## because a region that fills most of its box is a shape with a silhouette,
## and one that fills a third of it is a blot.
const BANDS := [
	{"box": 5, "patches": 5, "sizes": [4, 5]},
	{"box": 6, "patches": 6, "sizes": [4, 5, 6]},
	{"box": 7, "patches": 8, "sizes": [4, 5, 6]},
]
## A patch's bounding box may not run past this in either direction. Four
## is what the rack can hold at a legible size: its two shelves share the
## rack's height between them, so a four-tall patch already costs every
## patch on the board about a fifth of its cell, and five would be visible
## (see the spec's section 6, where a grid of equal bays measured 46.7 a
## cell on every band and had to be thrown out).
const MAX_SPAN := 4
## How many regions to grow before handing back the best one seen. The grow
## is cheap and the proof is not, so a board is regrown rather than repaired
## -- and the grow wedges *often*, which is the figure this number is really
## against: 77%, 81% and 92% of grows on the three bands run out of legal
## accretions before their patches are all grown (3,000 grows a band,
## 2026-09-20). Band 2 is the binding case, at roughly a 4% chance per
## attempt of a board that is both unique and inside its node window, so 200
## attempts miss about one day in 3,800 -- and the worst of 500 measured
## seeds spent 179 of them. A miss is not a failure: it falls back to a
## unique board that the node window would have refused, which is a real
## puzzle graded a little soft, the way Sudoku hands back `graded: false`.
const ATTEMPTS := 200
## Band 0 refuses a board whose count-to-two explores more nodes than this,
## and band 2 refuses one below HARD_NODES. Both are read off the measured
## distribution of `nodes` over uniquely-tileable grown boards, 3,000 grows a
## band on this Mac (2026-09-20), and not guessed:
##
##   band 0  n=704  mean 15.9  p50 15  p75 19  p90 25  max 42
##   band 1  n=472  mean 23.9  p50 20  p75 29  p90 41  max 88
##   band 2  n=244  mean 80.3  p50 58  p75 99  p90 151 max 748
##
## So 20 is band 0's own three-quarter mark -- the easy day keeps the boards
## that are nearly rigid and throws the tail away -- and 60 is band 2's own
## median, so the hard day keeps the more branching half of what it grows.
## Band 1 is ungraded on purpose: it is the band the menu opens, and its
## whole distribution already sits between the other two thresholds.
##
## What that buys, measured again over 500 seeds a band through `generate`
## itself: band 0 hands out boards walking 13.3 nodes on average against the
## 15.9 of what it grew, and band 2 hands out 114.2 against 80.3. The easy
## and the hard day are further apart than the grow alone makes them, and
## the middle band is untouched (23.1 against 23.9, which is the same
## distribution twice).
const EASY_NODES := 20
## See EASY_NODES for how both were measured.
const HARD_NODES := 60
## A covered-cell mask is one 64-bit int, so a region bigger than this cannot
## be counted. The largest band is a 7x7 box, so nothing the bands can grow
## comes near it; the guard is for a caller that hands in its own region.
const MASK_CELLS := 63
## One grow can wedge rather than fail -- it runs out of legal accretions
## long before its patches are all grown -- but every loop below is bounded
## by the cells it is filling, so this guards only the seed search.
const GROW_GUARD := 4000

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

# ------------------------------------------------------------- the generator

## Grow a region, prove its tiling unique, grade it by what the proof cost.
## A board that degrades is better than a board that fails to open, so the
## fallbacks run in this order of preference: a unique board inside the
## band's node window, then any unique board, then the last region grown (and
## that one comes back `unique: false`, because the proof said so and the
## state has to be able to say so too). The very last resort regrows with the
## bounding-box reach rule dropped, so a seed whose 200 grows all wedged
## still opens a board rather than nothing.
##
## Measured over 500 seeds a band on this Mac (2026-09-20): **every seed came
## back unique and inside its band's node window** -- so none of the three
## fallbacks was walked -- taking 5.4, 5.7 and 25.9 attempts on average
## (worst 32, 33 and 179) and 0.83, 1.28 and 8.07 ms (worst 3.9, 4.9 and
## 51.8), against the repo's 194 ms gate. The fallbacks are robustness and
## not a live path, but the flag has to be honest whether or not the path is
## ever walked.
static func generate(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var d := clampi(difficulty, 0, BANDS.size() - 1)
	var b: Dictionary = BANDS[d]
	var last := {}
	var unique := {}
	for attempt in range(1, ATTEMPTS + 1):
		var grown := _grow(rng, b)
		if grown.is_empty():
			continue
		var board := _proved(grown, attempt)
		last = board
		if not bool(board.unique):
			continue
		if unique.is_empty():
			unique = board
		if d == 0 and int(board.nodes) > EASY_NODES:
			continue
		if d == 2 and int(board.nodes) < HARD_NODES:
			continue
		return board
	if not unique.is_empty():
		return unique
	if not last.is_empty():
		return last
	for attempt in range(1, ATTEMPTS + 1):
		var grown := _grow(rng, b, true)
		if grown.is_empty():
			continue
		return _proved(grown, ATTEMPTS + attempt)
	return {
		"cols": 0, "rows": 0, "region": PackedByteArray(), "shapes": [],
		"answer": PackedInt32Array(), "unique": false,
		"attempts": ATTEMPTS, "nodes": 0,
	}

static func _proved(grown: Dictionary, attempt: int) -> Dictionary:
	var proof := count_tilings(int(grown.cols), int(grown.rows), grown.region, grown.shapes, 2)
	return {
		"cols": int(grown.cols),
		"rows": int(grown.rows),
		"region": grown.region,
		"shapes": grown.shapes,
		"answer": grown.answer,
		"unique": int(proof.count) == 1,
		"attempts": attempt,
		"nodes": int(proof.nodes),
	}

# ------------------------------------------------------------------ the grow

## One region, or {} when the walk wedged or a rejection caught it. `relaxed`
## drops the bounding-box reach rule only -- a hole is still refused, because
## a holed quilt is a drawing bug rather than a small board.
static func _grow(rng: RandomNumberGenerator, b: Dictionary, relaxed: bool = false) -> Dictionary:
	var n: int = int(b.box)
	var total := n * n
	var owner := PackedInt32Array()
	owner.resize(total)
	owner.fill(-1)
	var sizes: Array = b.sizes
	var patches: int = int(b.patches)
	var cells_of: Array = []
	for p in patches:
		var want: int = int(sizes[rng.randi_range(0, sizes.size() - 1)])
		var seeds := _seeds(owner, n, p == 0)
		if seeds.is_empty():
			return {}
		var start: int = int(seeds[rng.randi_range(0, seeds.size() - 1)])
		var got := _grow_patch(rng, owner, n, p, start, want)
		if got.is_empty():
			return {}
		cells_of.append(got)
	if _has_hole(owner, n):
		return {}
	var lox := n
	var loy := n
	var hix := -1
	var hiy := -1
	for idx in total:
		if owner[idx] < 0:
			continue
		var c := idx % n
		var r := idx / n
		lox = mini(lox, c)
		hix = maxi(hix, c)
		loy = mini(loy, r)
		hiy = maxi(hiy, r)
	var cols := hix - lox + 1
	var rows := hiy - loy + 1
	if not relaxed and cols != n and rows != n:
		return {}
	var region := PackedByteArray()
	region.resize(cols * rows)
	var shapes: Array = []
	var answer := PackedInt32Array()
	answer.resize(patches)
	for p in patches:
		var list: PackedInt32Array = cells_of[p]
		# Scan order in the box stays scan order after a translation, so
		# sorting the raw indices is what makes a shape's offsets canonical
		# -- which is what lets two alike patches key the same in the proof.
		list.sort()
		var px := n
		var py := n
		for idx in list:
			px = mini(px, idx % n)
			py = mini(py, idx / n)
		var offs: Array[Vector2i] = []
		for idx in list:
			var c := idx % n
			var r := idx / n
			offs.append(Vector2i(c - px, r - py))
			region[(r - loy) * cols + (c - lox)] = 1
		shapes.append(offs)
		answer[p] = (py - loy) * cols + (px - lox)
	return {"cols": cols, "rows": rows, "region": region, "shapes": shapes, "answer": answer}

## Where the next patch may start: anywhere for the first, and otherwise an
## empty cell already touching the region, which is what makes the finished
## region connected without anything ever testing for it.
static func _seeds(owner: PackedInt32Array, n: int, first: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	var total := n * n
	var guard := 0
	for idx in total:
		guard += 1
		if guard > GROW_GUARD:
			break
		if owner[idx] >= 0:
			continue
		if first:
			out.append(idx)
			continue
		var c := idx % n
		var r := idx / n
		for dir in DIRS:
			var qc: int = c + dir.x
			var qr: int = r + dir.y
			if qc < 0 or qr < 0 or qc >= n or qr >= n:
				continue
			if owner[qr * n + qc] >= 0:
				out.append(idx)
				break
	return out

## Accretes `want` cells from `start`, writing `p` into `owner` as it goes.
## Every candidate is checked against MAX_SPAN before it is taken, so a patch
## can never grow past the rack's bay and then have to be unpicked. Returns
## the cells, or an empty array with `owner` put back as it was found.
static func _grow_patch(rng: RandomNumberGenerator, owner: PackedInt32Array, n: int,
		p: int, start: int, want: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.append(start)
	owner[start] = p
	var lox := start % n
	var hix := lox
	var loy := start / n
	var hiy := loy
	while cells.size() < want:
		var cand := PackedInt32Array()
		var seen := {}
		for idx in cells:
			var c := idx % n
			var r := idx / n
			for dir in DIRS:
				var qc: int = c + dir.x
				var qr: int = r + dir.y
				if qc < 0 or qr < 0 or qc >= n or qr >= n:
					continue
				var q := qr * n + qc
				if owner[q] >= 0 or seen.has(q):
					continue
				seen[q] = true
				if maxi(hix, qc) - mini(lox, qc) >= MAX_SPAN:
					continue
				if maxi(hiy, qr) - mini(loy, qr) >= MAX_SPAN:
					continue
				cand.append(q)
		if cand.is_empty():
			for idx in cells:
				owner[idx] = -1
			return PackedInt32Array()
		var pick: int = int(cand[rng.randi_range(0, cand.size() - 1)])
		owner[pick] = p
		cells.append(pick)
		lox = mini(lox, pick % n)
		hix = maxi(hix, pick % n)
		loy = mini(loy, pick / n)
		hiy = maxi(hiy, pick / n)
	return cells

## Whether any empty cell of the box is walled in. Flooding the empties from
## the box's own border and looking for what it misses is the same test as
## flooding from outside the *region's* bounding box, because no region cell
## can stand outside that box: a path that leaves the region's box is already
## free.
static func _has_hole(owner: PackedInt32Array, n: int) -> bool:
	var total := n * n
	var seen := PackedByteArray()
	seen.resize(total)
	var stack: Array[int] = []
	for idx in total:
		if owner[idx] >= 0 or seen[idx] == 1:
			continue
		var c := idx % n
		var r := idx / n
		if c != 0 and r != 0 and c != n - 1 and r != n - 1:
			continue
		seen[idx] = 1
		stack.append(idx)
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		var c := idx % n
		var r := idx / n
		for dir in DIRS:
			var qc: int = c + dir.x
			var qr: int = r + dir.y
			if qc < 0 or qr < 0 or qc >= n or qr >= n:
				continue
			var q := qr * n + qc
			if owner[q] >= 0 or seen[q] == 1:
				continue
			seen[q] = 1
			stack.append(q)
	for idx in total:
		if owner[idx] < 0 and seen[idx] == 0:
			return true
	return false

# ----------------------------------------------------------------- the proof

## How many ways `shapes` tiles `region` exactly, counted up to `cap`, and
## what the count cost. Returns {"count": int, "nodes": int, "first":
## PackedInt32Array}, where `first` is the first tiling found as one origin
## cell index per patch (empty when there is none).
##
## The search is exact cover with the cheapest useful branching rule: the
## first uncovered cell in scan order must be covered by *something*, so only
## the placements that cover it are ever tried, and a cell no remaining patch
## can cover kills the branch without a test of its own.
##
## **Identical patches are one choice, not two.** The shapes are grouped by
## their canonical offsets and the search spends a group, so two alike
## patches trading places never counts as a second tiling. A group's
## placements are handed to its patches in index order, which is why `first`
## can name a patch at all.
static func count_tilings(cols: int, rows: int, region: PackedByteArray, shapes: Array,
		cap: int) -> Dictionary:
	var total := cols * rows
	var empty := {"count": 0, "nodes": 0, "first": PackedInt32Array()}
	if cols <= 0 or rows <= 0 or shapes.is_empty():
		return empty
	if total > MASK_CELLS:
		push_warning("Quilt: a %dx%d region is past the %d-cell mask" % [cols, rows, MASK_CELLS])
		return empty
	var full := 0
	var order := PackedInt32Array()
	for idx in total:
		if region[idx] == 1:
			full |= 1 << idx
			order.append(idx)
	# Grouped by shape: `group_of` is only built to fill `group_patches`.
	var group_id := {}
	var group_patches: Array = []
	var group_offs: Array = []
	for p in shapes.size():
		var key := _shape_key(shapes[p])
		if not group_id.has(key):
			group_id[key] = group_patches.size()
			group_patches.append([])
			group_offs.append(shapes[p])
		group_patches[int(group_id[key])].append(p)
	var groups := group_patches.size()
	# Per group, per cell: the masks and origins of the placements covering
	# that cell. Built once, read on every node.
	var masks: Array = []
	var origins: Array = []
	for g in groups:
		# Plain Arrays while they are being filled, packed once they are done:
		# the search reads these on every node and never writes them.
		var raw_m: Array = []
		var raw_o: Array = []
		for _i in total:
			raw_m.append([])
			raw_o.append([])
		var offs: Array = group_offs[g]
		for origin in total:
			var oc := origin % cols
			var orr := origin / cols
			var mask := 0
			var fits := true
			for off in offs:
				var c: int = oc + int(off.x)
				var r: int = orr + int(off.y)
				if c < 0 or r < 0 or c >= cols or r >= rows:
					fits = false
					break
				var idx := r * cols + c
				if region[idx] != 1:
					fits = false
					break
				mask |= 1 << idx
			if not fits:
				continue
			for off in offs:
				var idx: int = (orr + int(off.y)) * cols + oc + int(off.x)
				raw_m[idx].append(mask)
				raw_o[idx].append(origin)
		var packed_m: Array = []
		var packed_o: Array = []
		for idx in total:
			packed_m.append(PackedInt64Array(raw_m[idx]))
			packed_o.append(PackedInt32Array(raw_o[idx]))
		masks.append(packed_m)
		origins.append(packed_o)
	var left: Array = []
	var used: Array = []
	for g in groups:
		left.append(group_patches[g].size())
		used.append(0)
	var assign: Array = []
	assign.resize(shapes.size())
	assign.fill(-1)
	var ctx := {
		"full": full, "order": order, "groups": groups,
		"masks": masks, "origins": origins, "patches": group_patches,
	}
	var state := {"count": 0, "nodes": 0, "first": PackedInt32Array()}
	_tile(ctx, 0, left, used, assign, cap, state)
	return state

## The canonical key of a shape: its offsets in scan order, which `_grow`
## already put them in.
static func _shape_key(offs: Array) -> String:
	var out := ""
	for off in offs:
		out += "%d,%d;" % [int(off.x), int(off.y)]
	return out

static func _tile(ctx: Dictionary, covered: int, left: Array, used: Array, assign: Array,
		cap: int, state: Dictionary) -> void:
	state.nodes = int(state.nodes) + 1
	if covered == int(ctx.full):
		state.count = int(state.count) + 1
		if int(state.count) == 1:
			state.first = PackedInt32Array(assign)
		return
	var cell := -1
	var order: PackedInt32Array = ctx.order
	for i in order.size():
		var idx := int(order[i])
		if (covered >> idx) & 1 == 0:
			cell = idx
			break
	if cell < 0:
		return
	for g in int(ctx.groups):
		if int(left[g]) <= 0:
			continue
		var ms: PackedInt64Array = ctx.masks[g][cell]
		var os: PackedInt32Array = ctx.origins[g][cell]
		for k in ms.size():
			var mask: int = int(ms[k])
			if covered & mask != 0:
				continue
			var p: int = int(ctx.patches[g][int(used[g])])
			assign[p] = int(os[k])
			left[g] = int(left[g]) - 1
			used[g] = int(used[g]) + 1
			_tile(ctx, covered | mask, left, used, assign, cap, state)
			left[g] = int(left[g]) + 1
			used[g] = int(used[g]) - 1
			assign[p] = -1
			if int(state.count) >= cap:
				return
