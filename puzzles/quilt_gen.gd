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

## The four bands: the box the region is grown inside, how many patches, and
## the sizes a patch is drawn from. The sizes are deliberately tight against
## the box -- band 0's five patches want 20 to 25 cells of a 25-cell box --
## because a region that fills most of its box is a shape with a silhouette,
## and one that fills a third of it is a blot.
##
## Insane's row is **Scrap Basket** (the polish, 2026-09-30): nine patches
## grow the quilt as on every other band, and `scraps` more are drawn that do
## not belong to it at all -- see `generate_scraps`. It is dealt from the bank
## (content/insane/quilt.json) and grown live only when the bank is empty.
const BANDS := [
	{"box": 5, "patches": 5, "sizes": [4, 5]},
	{"box": 6, "patches": 6, "sizes": [4, 5, 6]},
	{"box": 7, "patches": 8, "sizes": [4, 5, 6]},
	{"box": 7, "patches": 9, "sizes": [3, 4, 5, 6], "scraps": 3},
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
## The share of a band's patches `readable` must sew from the bare quilt
## with no guess (the made-fun pass, 2026-10-28): all of them on Easy and
## Medium, so a careful player is never made to guess, and on Hard one
## patch: its eight keep their harder middle but always open with a move to
## be found. Reading half of Hard cost 78 ms a deal and 360 at worst, past
## the 194 ms gate. As shipped, 500 seeds a band on this Mac: 500, 500 and
## 499 of 500 readable, 7.3 / 13.6 / 28.6 ms a deal, worst 48.8 / 66.3 /
## 148.3. Insane's banked Scrap Basket is not read.
const READ_SHARE := [1.0, 1.0, 0.1]
## Times ATTEMPTS: a readable board is rarer than a unique one (17, 18 and
## 21 of 60 quilts each band handed out before -- read to the end on Easy
## and Medium, opened on Hard), so the loop runs longer before it falls
## back to the first board that passed every other test.
## Hard's is 2: at 4 its worst of 500 seeds dealt in 197.6 ms, past the
## gate. A clock cannot cut the loop instead -- a day has to be the same
## quilt on every phone, fast or slow.
const READ_ATTEMPTS := [4, 4, 2]
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
	if d == 3:
		return generate_scraps(rng)
	var b: Dictionary = BANDS[d]
	var last := {}
	var unique := {}
	var readable_board := {}
	for attempt in range(1, ATTEMPTS * int(READ_ATTEMPTS[d]) + 1):
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
		if d >= 2 and int(board.nodes) < HARD_NODES:
			continue
		if readable_board.is_empty():
			readable_board = board
		var shapes: Array = board.shapes
		var need := ceili(float(READ_SHARE[d]) * shapes.size())
		var read := readable(int(board.cols), int(board.rows), board.region, shapes,
			PackedByteArray(), need)
		board["read"] = read
		if read < need:
			continue
		return board
	if not readable_board.is_empty():
		return readable_board
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

# ------------------------------------------------------------- Scrap Basket

## How many quilts Scrap Basket grows live before handing back the best one
## seen. Only the fallback walks this -- the day is dealt from the bank -- so
## it is sized against the 194 ms gate rather than against a grade; see
## `generate_scraps` for what it measured.
const SCRAP_ATTEMPTS := 200
## How many shapes a scrap draw may throw away (a repeat of a quilt patch or
## of another scrap, or a shape that fits nowhere on the quilt) before the
## whole quilt is regrown instead.
const SCRAP_DRAWS := 60

## Insane: **three scraps too many.** Grow nine patches in the 7x7 box as the
## other bands do, then draw three scrap shapes -- sizes 3 to 6, no wider or
## taller than MAX_SPAN, none identical to a quilt patch or to another scrap,
## and every one able to lie somewhere on the quilt, because a scrap that
## fits nowhere announces itself -- and shuffle all twelve into one basket
## order. A scrap's `answer` is -1.
##
## The proof is `count_covers`: whether exactly one choice of patches tiles
## the quilt exactly once. Every other telling of the genre deals exactly the
## pieces the shape needs, so the sizes always add up and the first step is
## free; here the set is a question too, and a region that is rigid with the
## right nine must also refuse every other nine (or eight, or ten).
##
## `nodes` grades it as on every band. Live, the first unique board wins and
## the best of SCRAP_ATTEMPTS is not looked for -- the miner does that
## looking, off the phone. A board is `unique: false` only when every attempt
## found a second cover, and it is still a quilt the answer finishes.
##
## Measured on this Mac (2026-09-30): 88% of grows wedge or are refused, and
## about a third of the baskets that survive prove unique, so a live deal
## takes some twenty grows. Over 100 seeds every one came back unique, in
## 15.4 ms at the median and 82.4 at worst, against the 194 ms gate.
static func generate_scraps(rng: RandomNumberGenerator, attempts := SCRAP_ATTEMPTS) -> Dictionary:
	var b: Dictionary = BANDS[3]
	var last := {}
	for attempt in range(1, attempts + 1):
		var grown := _grow(rng, b)
		if grown.is_empty():
			continue
		var board := _with_scraps(rng, grown, int(b.get("scraps", 3)), attempt)
		if board.is_empty():
			continue
		last = board
		if bool(board.unique):
			return board
	if not last.is_empty():
		return last
	# Every grow wedged: the plain band 2 deal is still a quilt to play.
	return generate(rng, 2)

## The grown quilt with `count` scraps drawn beside it, shuffled and proved,
## or {} when the scraps could not be drawn.
static func _with_scraps(rng: RandomNumberGenerator, grown: Dictionary, count: int,
		attempt: int) -> Dictionary:
	var cols := int(grown.cols)
	var rows := int(grown.rows)
	var region: PackedByteArray = grown.region
	var taken := {}
	for offs in grown.shapes:
		taken[_shape_key(offs)] = true
	var sizes: Array = BANDS[3].sizes
	var scraps: Array = []
	var draws := 0
	while scraps.size() < count:
		draws += 1
		if draws > SCRAP_DRAWS:
			return {}
		var offs := _random_shape(rng, int(sizes[rng.randi_range(0, sizes.size() - 1)]))
		if offs.is_empty():
			continue
		var key := _shape_key(offs)
		if taken.has(key) or not _fits_somewhere(cols, rows, region, offs):
			continue
		taken[key] = true
		scraps.append(offs)
	# One basket, shuffled: the patches came out of the grow in the order they
	# were grown and the scraps last, and either order would give them away.
	var all_shapes: Array = []
	var all_answer: Array = []
	for p in grown.shapes.size():
		all_shapes.append(grown.shapes[p])
		all_answer.append(int(grown.answer[p]))
	for offs in scraps:
		all_shapes.append(offs)
		all_answer.append(-1)
	for i in range(all_shapes.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var ts = all_shapes[i]
		all_shapes[i] = all_shapes[j]
		all_shapes[j] = ts
		var ta = all_answer[i]
		all_answer[i] = all_answer[j]
		all_answer[j] = ta
	var proof := count_covers(cols, rows, region, all_shapes, 2)
	return {
		"cols": cols, "rows": rows, "region": region,
		"shapes": all_shapes, "answer": PackedInt32Array(all_answer),
		"unique": int(proof.count) == 1,
		"attempts": attempt, "nodes": int(proof.nodes),
	}

## One polyomino of `size` cells grown in a MAX_SPAN box, in the scan-order
## normal form `_grow` gives its patches -- so a scrap and a patch of the same
## shape key the same, which is what lets the draw refuse a repeat.
static func _random_shape(rng: RandomNumberGenerator, size: int) -> Array:
	var n := MAX_SPAN
	var owner := PackedInt32Array()
	owner.resize(n * n)
	owner.fill(-1)
	var cells := _grow_patch(rng, owner, n, 0, rng.randi_range(0, n * n - 1), size)
	if cells.is_empty():
		return []
	cells.sort()
	var px := n
	var py := n
	for idx in cells:
		px = mini(px, idx % n)
		py = mini(py, idx / n)
	var offs: Array[Vector2i] = []
	for idx in cells:
		offs.append(Vector2i(idx % n - px, idx / n - py))
	return offs

## Whether `offs` can lie anywhere wholly on the quilt.
static func _fits_somewhere(cols: int, rows: int, region: PackedByteArray, offs: Array) -> bool:
	for origin in cols * rows:
		var oc := origin % cols
		var orr := origin / cols
		var fits := true
		for off in offs:
			var c: int = oc + int(off.x)
			var r: int = orr + int(off.y)
			if c >= cols or r >= rows or region[r * cols + c] != 1:
				fits = false
				break
		if fits:
			return true
	return false

# ------------------------------------------------------------------ the bank

## A board in the bank's plain-JSON shape: the region as one string of 0s and
## 1s a row, each shape as [x, y] pairs, and the answer's origins (-1 for a
## scrap). `nodes` rides along for the note.
static func to_bank(board: Dictionary) -> Dictionary:
	if board.is_empty() or int(board.get("cols", 0)) <= 0:
		return {}
	var cols := int(board.cols)
	var rows := int(board.rows)
	var lines: Array = []
	for r in rows:
		var line := ""
		for c in cols:
			line += "1" if int(board.region[r * cols + c]) == 1 else "0"
		lines.append(line)
	var shapes: Array = []
	for offs in board.shapes:
		var pairs: Array = []
		for off in offs:
			pairs.append([int(off.x), int(off.y)])
		shapes.append(pairs)
	return {"cols": cols, "rows": rows, "region": lines, "shapes": shapes,
		"answer": Array(board.answer), "nodes": int(board.get("nodes", 0))}

## A banked board back in the generator's own shape, **checked the way the
## phone can afford**: every shape is a normalised polyomino inside MAX_SPAN,
## the answer lays every non-scrap patch wholly on the quilt with no two
## overlapping and every quilt cell covered, and a scrap is marked by -1
## alone, and no scrap has a quilt patch's shape. Uniqueness is the miner's proof and
## is trusted. {} when any of it fails (a value of the wrong type included), and the board
## deals a live one instead.
static func from_bank(entry: Dictionary) -> Dictionary:
	# Every value is type-checked before it is converted: a bank is data from
	# disk, and int(null) or String(7) is a script error, not a refusal.
	if entry.is_empty() or not (entry.get("region") is Array) \
			or not (entry.get("shapes") is Array) or not (entry.get("answer") is Array) \
			or not _is_num(entry.get("cols")) or not _is_num(entry.get("rows")):
		return {}
	var cols := int(entry.get("cols"))
	var rows := int(entry.get("rows"))
	if cols <= 0 or rows <= 0 or cols * rows > MASK_CELLS or entry.region.size() != rows:
		return {}
	var region := PackedByteArray()
	region.resize(cols * rows)
	var cells := 0
	for r in rows:
		if not (entry.region[r] is String):
			return {}
		var line: String = entry.region[r]
		if line.length() != cols:
			return {}
		for c in cols:
			if line[c] == "1":
				region[r * cols + c] = 1
				cells += 1
			elif line[c] != "0":
				return {}
	var shapes: Array = []
	for pairs in entry.shapes:
		if not (pairs is Array) or pairs.is_empty():
			return {}
		var offs: Array[Vector2i] = []
		var lox := 99
		var loy := 99
		for pair in pairs:
			if not (pair is Array) or pair.size() != 2 \
					or not _is_num(pair[0]) or not _is_num(pair[1]):
				return {}
			var off := Vector2i(int(pair[0]), int(pair[1]))
			if off.x < 0 or off.y < 0 or off.x >= MAX_SPAN or off.y >= MAX_SPAN or offs.has(off):
				return {}
			lox = mini(lox, off.x)
			loy = mini(loy, off.y)
			offs.append(off)
		if lox != 0 or loy != 0:
			return {}
		offs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x))
		shapes.append(offs)
	var answer := PackedInt32Array()
	for v in entry.answer:
		if not _is_num(v):
			return {}
		answer.append(int(v))
	if answer.size() != shapes.size():
		return {}
	# A scrap shaped like a quilt patch is not a scrap: the two swap, and the
	# quilt has a second tiling the proof never counted.
	var quilt_keys := {}
	for p in shapes.size():
		if int(answer[p]) >= 0:
			quilt_keys[_shape_key(shapes[p])] = true
	for p in shapes.size():
		if int(answer[p]) < 0 and quilt_keys.has(_shape_key(shapes[p])):
			return {}
	var cover := PackedByteArray()
	cover.resize(cols * rows)
	var laid := 0
	for p in shapes.size():
		var origin := int(answer[p])
		if origin < 0:
			continue
		if origin >= cols * rows:
			return {}
		for off in shapes[p]:
			var c: int = origin % cols + off.x
			var r: int = origin / cols + off.y
			if c >= cols or r >= rows:
				return {}
			var idx := r * cols + c
			if region[idx] != 1 or cover[idx] == 1:
				return {}
			cover[idx] = 1
			laid += 1
	if laid != cells:
		return {}
	return {"cols": cols, "rows": rows, "region": region, "shapes": shapes,
		"answer": answer, "unique": true, "attempts": 0,
		"nodes": int(entry.get("nodes", 0)) if _is_num(entry.get("nodes", 0)) else 0}

## Whether a bank value is a number (JSON reads every number as a float).
static func _is_num(v: Variant) -> bool:
	return v is int or v is float

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
	return _packed(owner, n, cells_of, relaxed)

## The grown `owner` (a patch index a cell, -1 empty, -2 outside a themed
## shape) translated onto its own bounding box: {cols, rows, region, shapes,
## answer}, or {} when `relaxed` is false and the region fills neither of the
## box's dimensions.
static func _packed(owner: PackedInt32Array, n: int, cells_of: Array, relaxed: bool) -> Dictionary:
	var total := n * n
	var patches := cells_of.size()
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
				if owner[q] != -1 or seen.has(q):
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

# ------------------------------------------------------------ the reading

## **How far the quilt can be read** (the made-fun pass, 2026-10-28): the
## patches a careful player sews with no guess at all, walking from the bare
## quilt. A spot is *ruled out at a glance* when it would leave a bare pocket
## smaller than every patch still to sew (`pocket_cells`), and a move is
## *forced* when a patch has one spot left after that, or a bare square has
## one patch-and-spot that can cover it. Both are always the answer's own
## move on a unique quilt -- the answer never leaves a pocket it cannot fill,
## and the square's one cover is the cover -- so the walk never errs.
##
## Measured before the pass (`tests/_probe_ql_fun.gd`, 60 days a band): only
## 17, 18 and 4 of 60 Easy, Medium and Hard quilts could be read to the end
## this way, and 30, 22 and 39 of 60 had **no first move at all**: the first
## patch on was a guess. That, and not the size of the quilt, was why nobody
## liked it -- trial and error with the outline as the only clue.
##
## Returns how many patches the walk sews, stopping once it has `need` (scraps,
## answer -1, never count: pass `skip` with a 1 for each patch to leave out
## of the reading).
static func readable(cols: int, rows: int, region: PackedByteArray, shapes: Array,
		skip: PackedByteArray = PackedByteArray(), need: int = 1 << 20) -> int:
	var total := cols * rows
	var cover := PackedInt32Array()
	cover.resize(total)
	cover.fill(-1)
	var free: Array[int] = []
	for p in shapes.size():
		if skip.size() > p and skip[p] == 1:
			continue
		free.append(p)
	var sewn := 0
	while not free.is_empty() and sewn < need:
		var move := next_read(cols, rows, region, shapes, cover, free)
		if move.x < 0:
			break
		for k in _cells_at(cols, shapes[move.x], move.y):
			cover[k] = move.x
		free.erase(move.x)
		sewn += 1
	return sewn

## The next move `readable` would make with `cover` as it stands and `free`
## the patches still to sew: Vector2i(patch, origin), or (-1, -1) when
## nothing is forced. The hint asks it too, so a bulb sews the patch the
## player could have worked out next rather than an arbitrary one.
static func next_read(cols: int, rows: int, region: PackedByteArray, shapes: Array,
		cover: PackedInt32Array, free: Array) -> Vector2i:
	var total := cols * rows
	var spots := {}
	for p in free:
		spots[p] = _glance_spots(cols, rows, region, cover, shapes, free, p)
	for p in free:
		var list: PackedInt32Array = spots[p]
		if list.size() == 1:
			return Vector2i(p, list[0])
	var by_cell := {}
	for p in free:
		for o in spots[p]:
			for k in _cells_at(cols, shapes[p], o):
				if by_cell.has(k):
					by_cell[k] = Vector2i(-2, -2)
				else:
					by_cell[k] = Vector2i(p, o)
	for k in total:
		if region[k] == 1 and cover[k] < 0:
			var v: Vector2i = by_cell.get(k, Vector2i(-2, -2))
			if v.x >= 0:
				return v
	return Vector2i(-1, -1)

## The spots `p` may lie on with `cover` as it is, less those a glance rules
## out (see `readable`). `free` is every patch still to sew, `p` among them.
static func _glance_spots(cols: int, rows: int, region: PackedByteArray,
		cover: PackedInt32Array, shapes: Array, free: Array, p: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var smallest := 0
	for q in free:
		if q != p:
			var n: int = shapes[q].size()
			smallest = n if smallest == 0 else mini(smallest, n)
	for origin in cols * rows:
		var cells := _fit_cells(cols, rows, region, cover, shapes[p], origin)
		if cells.is_empty():
			continue
		if smallest > 0 and not pocket_cells(cols, rows, region, cover, cells, smallest).is_empty():
			continue
		out.append(origin)
	return out

## The cell indices `offs` covers with its origin on `origin`, or an empty
## array when any of them is off the quilt or already covered.
static func _fit_cells(cols: int, rows: int, region: PackedByteArray,
		cover: PackedInt32Array, offs: Array, origin: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var oc := origin % cols
	var orr := origin / cols
	for off in offs:
		var c: int = oc + int(off.x)
		var r: int = orr + int(off.y)
		if c >= cols or r >= rows:
			return PackedInt32Array()
		var k := r * cols + c
		if region[k] != 1 or cover[k] >= 0:
			return PackedInt32Array()
		out.append(k)
	return out

static func _cells_at(cols: int, offs: Array, origin: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for off in offs:
		out.append((origin / cols + int(off.y)) * cols + origin % cols + int(off.x))
	return out

## The bare cells that `taking` would shut in a pocket smaller than
## `smallest` -- the gap a player sees nothing left can fill. Empty when
## every pocket it touches is big enough. Only pockets beside `taking` are
## walked, and each only until it reaches `smallest`, so it is cheap enough
## to ask of every spot: a pocket that was already shut before is the
## board's dead end to name, not this drop's.
##
## The board asks it of a held patch to show the gap before the drop;
## `readable` asks it to rule a spot out.
static func pocket_cells(cols: int, rows: int, region: PackedByteArray,
		cover: PackedInt32Array, taking: PackedInt32Array, smallest: int) -> PackedInt32Array:
	# Marks in flat arrays, not dictionaries (2026-11-06: the themed deal
	# asks this thousands of times a board): 1 in `mark` is the patch's own
	# cell, 2 a cell already shut, and `seen` holds the start that last
	# walked a cell, so each pocket still floods on its own.
	var out := PackedInt32Array()
	var total := cols * rows
	var mark := PackedByteArray()
	mark.resize(total)
	var seen := PackedInt32Array()
	seen.resize(total)
	seen.fill(-1)
	for k in taking:
		mark[k] = 1
	var pocket := PackedInt32Array()
	for t in taking:
		var tc := t % cols
		var tr := t / cols
		for d0 in DIRS:
			var sc: int = tc + d0.x
			var sr: int = tr + d0.y
			if sc < 0 or sr < 0 or sc >= cols or sr >= rows:
				continue
			var start := sr * cols + sc
			if mark[start] != 0 or region[start] != 1 or cover[start] >= 0:
				continue
			# Each pocket floods on its own: a walk cut short at `smallest`
			# must not leave marks that make a later start see a fragment.
			var walk := t * 4 + DIRS.find(d0)
			seen[start] = walk
			pocket.clear()
			pocket.append(start)
			var i := 0
			var open := false
			while i < pocket.size():
				if pocket.size() >= smallest:
					open = true
					break
				var k: int = pocket[i]
				i += 1
				var c := k % cols
				var r := k / cols
				for dir in DIRS:
					var qc: int = c + dir.x
					var qr: int = r + dir.y
					if qc < 0 or qr < 0 or qc >= cols or qr >= rows:
						continue
					var q := qr * cols + qc
					if seen[q] == walk or mark[q] == 1 or region[q] != 1 or cover[q] >= 0:
						continue
					seen[q] = walk
					pocket.append(q)
			if not open:
				for k in pocket:
					mark[k] = 2
				out.append_array(pocket)
	return out

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

## How many ways *some* of `shapes` cover `region` exactly, up to `cap`: an
## exact cover in which a patch may be left out. It is `count_tilings` under
## the name that says so -- that search already stops the moment the region
## is covered, whatever is left over, and on a board whose patches' cells sum
## to the region's the two questions are the same. Scrap Basket's proof and
## the state's `finishable` ask this one, because for them a patch left over
## is the point. `first` holds -1 for every patch the cover left out.
static func count_covers(cols: int, rows: int, region: PackedByteArray, shapes: Array,
		cap: int) -> Dictionary:
	return count_tilings(cols, rows, region, shapes, cap)

## Whether *some* of `shapes` cover `region` exactly -- `count_covers` asked
## only for yes or no, and asked fast, because the board asks it after every
## drop (the state's `finishable`). The proof's search is kept as it is,
## since its node count is the grade every band and the bank are cut by; this
## one is free to be clever:
##
## - it branches on the uncovered cell with the **fewest** placements left
##   rather than the first in scan order, so a pocket nothing fits is found
##   at the node it becomes one instead of after the search has walked to it;
## - it remembers every (covered cells, patches left) it has seen fail, so a
##   dead end reached by two orders of the same patches is walked once.
##
## See the state's `finishable` for what it measured.
static func can_cover(cols: int, rows: int, region: PackedByteArray, shapes: Array) -> bool:
	var total := cols * rows
	if cols <= 0 or rows <= 0 or total > MASK_CELLS:
		return false
	var full := 0
	var cells := PackedInt32Array()
	for idx in total:
		if region[idx] == 1:
			full |= 1 << idx
			cells.append(idx)
	if full == 0:
		return true
	var group_id := {}
	var counts := PackedInt32Array()
	var offs_of: Array = []
	for offs in shapes:
		var key := _shape_key(offs)
		if not group_id.has(key):
			group_id[key] = counts.size()
			counts.append(0)
			offs_of.append(offs)
		counts[int(group_id[key])] += 1
	# Per cell: every placement covering it, as a group and a mask side by
	# side. Plain Arrays while they fill, packed once they are done, as in
	# `count_tilings`.
	if counts.size() > 15:
		# Past what the memo's code can pack: the proof's own search answers.
		return int(count_covers(cols, rows, region, shapes, 1).count) >= 1
	var opt_g: Array = []
	var opt_m: Array = []
	for _i in total:
		opt_g.append(PackedInt32Array())
		opt_m.append(PackedInt64Array())
	var raw_g: Array = []
	var raw_m: Array = []
	for _i in total:
		raw_g.append([])
		raw_m.append([])
	for g in offs_of.size():
		var offs: Array = offs_of[g]
		for origin in total:
			var oc := origin % cols
			var orr := origin / cols
			var mask := 0
			var fits := true
			for off in offs:
				var c: int = oc + int(off.x)
				var r: int = orr + int(off.y)
				if c >= cols or r >= rows or region[r * cols + c] != 1:
					fits = false
					break
				mask |= 1 << (r * cols + c)
			if not fits:
				continue
			for off in offs:
				var idx: int = (orr + int(off.y)) * cols + oc + int(off.x)
				raw_g[idx].append(g)
				raw_m[idx].append(mask)
	for idx in total:
		opt_g[idx] = PackedInt32Array(raw_g[idx])
		opt_m[idx] = PackedInt64Array(raw_m[idx])
	# A group's count is at most the twelve patches of a basket, so four bits
	# a group packs "which patches are left" into one int for the memo.
	var code := 0
	for g in counts.size():
		code |= counts[g] << (4 * g)
	var ctx := {"full": full, "cells": cells, "g": opt_g, "m": opt_m, "dead": {}}
	return _cover(ctx, 0, counts, code)

static func _cover(ctx: Dictionary, covered: int, counts: PackedInt32Array, code: int) -> bool:
	var full: int = ctx.full
	if covered == full:
		return true
	var dead: Dictionary = ctx.dead
	var seen: Dictionary = dead.get(covered, {})
	if seen.has(code):
		return false
	var cells: PackedInt32Array = ctx.cells
	var best := -1
	var fewest := 1 << 30
	for idx in cells:
		if (covered >> idx) & 1 == 1:
			continue
		var gs: PackedInt32Array = ctx.g[idx]
		var ms: PackedInt64Array = ctx.m[idx]
		var live := 0
		for k in gs.size():
			if counts[gs[k]] > 0 and covered & ms[k] == 0:
				live += 1
		if live < fewest:
			fewest = live
			best = idx
			if live <= 1:
				break
	if fewest > 0:
		var gs: PackedInt32Array = ctx.g[best]
		var ms: PackedInt64Array = ctx.m[best]
		for k in gs.size():
			var g := gs[k]
			if counts[g] <= 0 or covered & ms[k] != 0:
				continue
			counts[g] -= 1
			var found := _cover(ctx, covered | ms[k], counts, code - (1 << (4 * g)))
			counts[g] += 1
			if found:
				return true
	seen[code] = true
	dead[covered] = seen
	return false

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

# --- the day's theme (wave 2 of the daily theme roadmap, 2026-11-06) ---
#
# The other boards grow their field and lay things on it; Quilt has no
# field, its region is whatever the patches grew into. So a themed quilt is
# the reverse problem: the outline is one of the night's things, cut down to
# a box a little bigger than the band's, and the patches are grown *inside*
# it until it is covered -- each new patch from the first bare cell in scan
# order, which fills it as an exact cover would and wedges far less than a
# seed anywhere. Then the same proof (one tiling) and the same reading
# (Easy and Medium read to the end, Hard a first move) as a plain day.
# Insane stays on its bank.

const Planes = preload("res://puzzles/planes_state.gd")
const HHGen = preload("res://puzzles/hedgehogs_gen.gd")

## The night's sides each band tries first, so the bands mostly lay
## different things. Easy and Medium only: Hard keeps its plain quilt, graded
## by the proof's nodes (a cut outline tiles more rigidly -- themed Hard
## cuts read through 2 of 10 times and took 10 of 24 days at all, so a
## themed Hard was a Medium), and Insane is Scrap Basket's bank.
const THEMED_SIZES := [[10, 12, 24, 32], [12, 10, 24, 32]]
## The boxes a band's cut is tried in, biggest first: a thing reads better a
## cell bigger than the band's own box. Never past 7 (MASK_CELLS).
const THEME_BOXES := [[6, 5], [7, 6]]
## The most patches a themed quilt may take: the band's own count and one
## more on Easy and Medium, and never past the eight cloths (the rack's
## shelves shrink a patch, and `cloth_of` stays each patch's own index).
const THEME_PATCHES := [6, 7]
## A cut is kept when it covers at least SHAPE_MIN of the band's own box (a
## smaller quilt is a shorter day) and at most SHAPE_MAX of its own bounding
## box (or it is the box with a corner off).
const SHAPE_MIN := 0.7
const SHAPE_MAX := 0.9
## And at most this many cells: about 4.4 and 5 a patch, so the sizes the
## band draws have room to vary (a cut near THEME_PATCHES times the biggest
## patch has to be all big patches, and grows wedge for thousands of tries).
const THEME_CELLS := [26, 35]
## Grows tried on one cut before the next thing is, and how many things are
## tried before the plain quilt is dealt: a grow and its proof cost about a
## millisecond on this Mac, and the gate is 194 ms. Measured over the 24
## cached nights (2026-11-06), half the cuts need 11-15 grows and nine in
## ten 75-115; a few want hundreds, which is why a second thing is tried.
const THEME_TRIES := [80, 30]
const THEME_PICTURES := 2

## `pic_rows` (a night picture's rows) cut for band `band`: {n (the square's
## side), owner (-1 a quilt cell, -2 outside), beads (Vector2i -> bead name,
## in the bounding box's own cells), cells}, or {} when no box keeps the
## rules. Hedgehogs' smoothing, its largest piece, every hole filled (a hole
## in a quilt reads as a drawing bug), and a 2x2 somewhere for the cat.
static func shape_fit(pic_rows: Array, band: int) -> Dictionary:
	var d := clampi(band, 0, THEME_BOXES.size() - 1)
	var b: Dictionary = BANDS[d]
	var n0 := int(b.box)
	var most := int(THEME_CELLS[d])
	for m: int in THEME_BOXES[d]:
		var box := Vector2i(m, m)
		var cut := Planes.cut_shape(pic_rows, box, false)
		if cut.is_empty():
			continue
		var off := Vector2i((m - int(cut.cols)) / 2, (m - int(cut.rows)) / 2)
		var on := {}
		for c: Vector2i in cut.cells:
			on[c + off] = cut.cells[c]
		on = HHGen._smooth(on, box)
		if on.is_empty():
			continue
		_fill_holes(on, m)
		var count := on.size()
		var lo := Vector2i(m, m)
		var hi := Vector2i(-1, -1)
		for c: Vector2i in on:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var ext := hi - lo + Vector2i.ONE
		if float(count) < SHAPE_MIN * float(n0 * n0) or count > most:
			continue
		if float(count) > SHAPE_MAX * float(ext.x * ext.y):
			continue
		if not _has_square(on):
			continue
		var owner := PackedInt32Array()
		owner.resize(m * m)
		owner.fill(-2)
		var beads := {}
		for c: Vector2i in on:
			owner[c.y * m + c.x] = -1
			beads[c - lo] = on[c]
		return {"n": m, "owner": owner, "beads": beads, "cells": count}
	return {}

## Every cell of the m box no orthogonal path from the box's border reaches
## is put into the shape, taking a neighbour's bead.
static func _fill_holes(on: Dictionary, m: int) -> void:
	var seen := {}
	var stack: Array = []
	for i in m * m:
		var c := Vector2i(i % m, i / m)
		if on.has(c) or (c.x != 0 and c.y != 0 and c.x != m - 1 and c.y != m - 1):
			continue
		seen[c] = true
		stack.append(c)
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dv: Vector2i in DIRS:
			var q: Vector2i = c + dv
			if q.x < 0 or q.y < 0 or q.x >= m or q.y >= m or on.has(q) or seen.has(q):
				continue
			seen[q] = true
			stack.append(q)
	var holes: Array = []
	for i in m * m:
		var c := Vector2i(i % m, i / m)
		if not on.has(c) and not seen.has(c):
			holes.append(c)
	# a hole's cells take their beads from the shape round them, outside in
	while not holes.is_empty():
		var left: Array = []
		for c: Vector2i in holes:
			var bead := ""
			for dv: Vector2i in DIRS:
				if on.has(c + dv):
					bead = String(on[c + dv])
					break
			if bead == "":
				left.append(c)
			else:
				on[c] = bead
		if left.size() == holes.size():
			break
		holes = left

static func _has_square(on: Dictionary) -> bool:
	for c: Vector2i in on:
		if on.has(c + Vector2i(1, 0)) and on.has(c + Vector2i(0, 1)) and on.has(c + Vector2i(1, 1)):
			return true
	return false

## A quilt grown inside `shape` (shape_fit's) for band `band`: generate's
## board, or {} when THEME_TRIES grows found none with one tiling that a
## careful player reads (Easy and Medium to the end, Hard a first move).
static func generate_shaped(rng: RandomNumberGenerator, band: int, shape: Dictionary) -> Dictionary:
	var d := clampi(band, 0, THEME_BOXES.size() - 1)
	var b: Dictionary = BANDS[d]
	for attempt in range(1, int(THEME_TRIES[d]) + 1):
		var grown := _grow_in(rng, shape, b, int(THEME_PATCHES[d]))
		if grown.is_empty():
			continue
		var board := _proved(grown, attempt)
		if not bool(board.unique):
			continue
		var shapes: Array = board.shapes
		var need := ceili(float(READ_SHARE[d]) * shapes.size())
		var read := readable(int(board.cols), int(board.rows), board.region, shapes,
			PackedByteArray(), need)
		if read < need:
			continue
		board["read"] = read
		return board
	return {}

## The patches grown inside the shape until it is covered: each from the
## first bare cell in scan order, a size the band draws (never one that
## leaves fewer cells than its smallest patch), refused when a bare pocket
## smaller than the smallest patch is shut in or the patches run past `most`.
static func _grow_in(rng: RandomNumberGenerator, shape: Dictionary, b: Dictionary, most: int) -> Dictionary:
	var n := int(shape.n)
	var owner: PackedInt32Array = (shape.owner as PackedInt32Array).duplicate()
	var sizes: Array = b.sizes
	var least: int = int(sizes.min())
	var left := int(shape.cells)
	var cells_of: Array = []
	while left > 0:
		if cells_of.size() >= most:
			return {}
		var start := owner.find(-1)
		var can: Array = []
		for s in sizes:
			if int(s) == left or (int(s) < left and left - int(s) >= least):
				can.append(int(s))
		if can.is_empty():
			return {}
		# a patch that wedges or shuts in a pocket too small for any patch is
		# grown again, a few times, before the whole quilt is given up
		var got := PackedInt32Array()
		var want := 0
		for again in PATCH_RETRIES:
			want = can[rng.randi_range(0, can.size() - 1)]
			got = _grow_hugging(rng, owner, n, cells_of.size(), start, want)
			if got.is_empty():
				continue
			if left - want > 0 and _pocket_under(owner, n, least):
				for k in got:
					owner[k] = -1
				got = PackedInt32Array()
				continue
			break
		if got.is_empty():
			return {}
		cells_of.append(got)
		left -= want
	return _packed(owner, n, cells_of, true)

## Times one patch of a themed grow is grown again before the quilt is.
const PATCH_RETRIES := 6

## `_grow_patch` for a themed outline: each cell taken is drawn with a lean
## toward the bare cells with the fewest bare neighbours, so a patch hugs the
## outline and fills its nooks rather than leaving them to wedge the next.
## Its own draws, so a plain day's grow is untouched.
static func _grow_hugging(rng: RandomNumberGenerator, owner: PackedInt32Array, n: int,
		p: int, start: int, want: int) -> PackedInt32Array:
	var cells := PackedInt32Array([start])
	owner[start] = p
	var lo := Vector2i(start % n, start / n)
	var hi := lo
	while cells.size() < want:
		var cand := PackedInt32Array()
		var weight := PackedFloat32Array()
		var total := 0.0
		for idx in cells:
			for dv: Vector2i in DIRS:
				var q := Vector2i(idx % n, idx / n) + dv
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
					continue
				var k := q.y * n + q.x
				if owner[k] != -1 or cand.has(k):
					continue
				if maxi(hi.x, q.x) - mini(lo.x, q.x) >= MAX_SPAN or maxi(hi.y, q.y) - mini(lo.y, q.y) >= MAX_SPAN:
					continue
				var free := 0
				for dw: Vector2i in DIRS:
					var r: Vector2i = q + dw
					if r.x >= 0 and r.y >= 0 and r.x < n and r.y < n and owner[r.y * n + r.x] == -1:
						free += 1
				var w := 1.0 / float(1 + free * free)
				cand.append(k)
				weight.append(w)
				total += w
		if cand.is_empty():
			for idx in cells:
				owner[idx] = -1
			return PackedInt32Array()
		var roll := rng.randf() * total
		var pick := cand[cand.size() - 1]
		for i in cand.size():
			roll -= weight[i]
			if roll <= 0.0:
				pick = cand[i]
				break
		owner[pick] = p
		cells.append(pick)
		lo = Vector2i(mini(lo.x, pick % n), mini(lo.y, pick / n))
		hi = Vector2i(maxi(hi.x, pick % n), maxi(hi.y, pick / n))
	return cells

## Whether any bare (-1) pocket of `owner` is smaller than `least` cells.
static func _pocket_under(owner: PackedInt32Array, n: int, least: int) -> bool:
	var seen := PackedByteArray()
	seen.resize(n * n)
	for i in n * n:
		if owner[i] != -1 or seen[i] == 1:
			continue
		var size := 0
		var stack: Array[int] = [i]
		seen[i] = 1
		while not stack.is_empty():
			var k: int = stack.pop_back()
			size += 1
			for dv: Vector2i in DIRS:
				var qc: int = k % n + dv.x
				var qr: int = k / n + dv.y
				if qc < 0 or qr < 0 or qc >= n or qr >= n:
					continue
				var q := qr * n + qc
				if owner[q] == -1 and seen[q] == 0:
					seen[q] = 1
					stack.append(q)
		if size < least:
			return true
	return false
