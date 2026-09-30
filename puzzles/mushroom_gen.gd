extends RefCounted

## Mushroom Patch's fields, generated backwards from a field that is entirely
## turned over.
##
## Scatter k mushrooms, count every bare cell's eight neighbours, then turn
## *every* bare cell over and walk them in a shuffled order trying to cover
## each one back up -- keeping the cover only while `solvable` still proves
## the whole field. What survives is a near-minimal set of givens, and the
## board is solvable by logic alone **by construction**: carving can only
## remove information from a field that started fully solved, so a board with
## a guess in it is never produced. `ok` is asserted rather than relied on.
##
## A minimal board is the hardest board, so easy and medium hand a share of
## the carved-away numbers back (GIVE_BACK), chosen at random so the givens
## stay scattered. That, the size and whether the solver may subtract subsets
## are the whole ladder: measured on the concept page over 200 seeds, 168 hard
## boards cannot be solved without subset subtraction and 0 medium ones need
## it.
##
## **Insane is Fairy Rings** (the polish of 2026-09-30,
## docs/superpowers/specs/2026-09-30-mushroom-polish-design.md, section 2).
## Mushrooms grow in rings, and on Insane some numbers are *fairy rings*: they
## count the sixteen cells two steps out (the ring round the eight touching
## cells) and say nothing at all about the eight that touch them. Which
## numbers are rings is part of the board (`rings`). The field is carved
## first with the subsets solver, then carved again with the **deep** one,
## which may suppose a cell, follow the rules to a contradiction and take the
## other answer -- so a banked Insane field needs at least one supposition
## a player has to hold in their head. That is mined on the Mac
## (tools/insane/mushroom_ladder.gd, content/insane/mushroom.json); an empty
## bank falls back to a live ring field carved without the deep pass.
##
## Seeded only by the `rng` handed in, so a day is the same patch on every
## phone. Spec: docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md,
## section 4.

## n and mushrooms per difficulty: easy, medium, hard, insane.
const SIZES := [[6, 6], [7, 9], [8, 12], [9, 14]]
## Whether the solver may subtract subsets while carving -- the 1-2-1 pattern.
## Hard and up, which is what makes hard a different kind of thinking and not
## just a bigger field.
const SUBSETS := [false, false, true, true]
## What share of the carved-away numbers is handed back.
const GIVE_BACK := [0.45, 0.20, 0.0, 0.0]
## What share of the turned-over cells are fairy rings, per band.
const RING_SHARE := [0.0, 0.0, 0.0, 0.5]
const DIRS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

static func neighbours(cell: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var p: Vector2i = cell + d
		if p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
			out.append(p)
	return out

## The sixteen cells two steps out from `cell` (fewer at an edge): a fairy
## ring's reach.
static func ring(cell: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if maxi(absi(dx), absi(dy)) != 2:
				continue
			var p := cell + Vector2i(dx, dy)
			if p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
				out.append(p)
	return out

## What a given on `cell` counts: its ring when it is one, else its eight.
static func reach(cell: Vector2i, n: int, is_ring: bool) -> Array[Vector2i]:
	return ring(cell, n) if is_ring else neighbours(cell, n)

## Whether `given` decides every covered cell by logic alone. Two rule
## families, the global count, and -- when `subsets` -- subtraction between
## overlapping numbers; with `deep`, suppositions too. It never guesses and
## never backtracks past one supposition: a field it cannot finish is a field
## with a guess in it.
static func solvable(given: Dictionary, n: int, k: int, subsets: bool,
		rings: Dictionary = {}, deep := false) -> bool:
	return bool(solve(given, n, k, subsets, rings, deep).ok)

## The solve itself: {"ok", "supposed": how many cells needed a supposition,
## "probes": how many suppositions were tried}.
static func solve(given: Dictionary, n: int, k: int, subsets: bool,
		rings: Dictionary = {}, deep := false) -> Dictionary:
	var cons: Array = []               # [{"cells": covered cells it counts, "v": its number}]
	for g in given:
		var open: Array[Vector2i] = []
		for p in reach(g, n, rings.has(g)):
			if not given.has(p):
				open.append(p)
		cons.append({"cells": open, "v": int(given[g])})
	var unknown: Array[Vector2i] = []
	var framed := {}                   # covered cells some number counts
	for c in cons:
		for p in c.cells:
			framed[p] = true
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			if not given.has(c):
				unknown.append(c)
	var st := {}                       # covered cell -> true mushroom, false bare
	var out := {"ok": false, "supposed": 0, "probes": 0}
	if not _propagate(cons, unknown, st, k, subsets):
		return out
	while deep and st.size() < unknown.size():
		# Framed cells first: a supposition on a cell no number counts can
		# only ever break the global count.
		var order: Array[Vector2i] = []
		for p in unknown:
			if not st.has(p) and framed.has(p):
				order.append(p)
		for p in unknown:
			if not st.has(p) and not framed.has(p):
				order.append(p)
		var found := false
		for p in order:
			for v in [true, false]:
				var trial := st.duplicate()
				trial[p] = v
				out.probes += 1
				if _propagate(cons, unknown, trial, k, subsets):
					continue
				st[p] = not v
				out.supposed += 1
				if not _propagate(cons, unknown, st, k, subsets):
					return out
				found = true
				break
			if found:
				break
		if not found:
			break
	out.ok = st.size() == unknown.size()
	return out

## The plain rules (and subsets) run on `st` until they stop deciding
## anything. False when `st` breaks a number or the global count.
static func _propagate(cons: Array, unknown: Array[Vector2i], st: Dictionary, k: int,
		subsets: bool) -> bool:
	var moved := true
	while moved:
		moved = false
		var mines := 0
		var left := 0
		for p in unknown:
			if st.has(p):
				mines += 1 if st[p] else 0
			else:
				left += 1
		if mines > k or mines + left < k:
			return false
		if left == 0:
			break
		var live: Array = []            # [{"open": Array[Vector2i], "need": int}]
		for c in cons:
			var open: Array[Vector2i] = []
			var have := 0
			for p in c.cells:
				if st.has(p):
					have += 1 if st[p] else 0
				else:
					open.append(p)
			var need: int = int(c.v) - have
			if need < 0 or need > open.size():
				return false
			if open.is_empty():
				continue
			if need == 0 or need == open.size():
				for p in open:
					st[p] = need > 0
				moved = true
				continue
			live.append({"open": open, "need": need})
		if moved:
			continue
		# The global count. This is why the tally strip is on the screen: it
		# is a clue the carve leans on, not decoration.
		if mines == k or mines + left == k:
			var v := mines + left == k
			for p in unknown:
				if not st.has(p):
					st[p] = v
			moved = true
			continue
		if not subsets:
			break
		for pair in _subtract(live):
			var cell: Vector2i = pair[0]
			if st.has(cell):
				if bool(st[cell]) != bool(pair[1]):
					return false
				continue
			st[cell] = bool(pair[1])
			moved = true
	return true

## Where one number's covered cells sit inside another's, the cells outside
## carry the difference of their counts. The 1-2-1 every player of this game
## knows by feel; hard boards only.
static func _subtract(cons: Array) -> Array:
	var done: Array = []                # [[cell, is_mushroom], ...]
	for a in cons:
		for b in cons:
			if a == b or a.open.size() >= b.open.size():
				continue
			var inside := true
			for p in a.open:
				if not b.open.has(p):
					inside = false
					break
			if not inside:
				continue
			var rest: Array[Vector2i] = []
			for p in b.open:
				if not a.open.has(p):
					rest.append(p)
			var dv: int = int(b.need) - int(a.need)
			if dv <= 0:
				for p in rest:
					done.append([p, false])
			elif dv >= rest.size():
				for p in rest:
					done.append([p, true])
			if not done.is_empty():
				return done
	return done

## `ring_share` of the turned-over cells count their fairy ring instead of
## their eight; `deep` carves a second time with suppositions allowed.
static func generate(rng: RandomNumberGenerator, n: int, k: int,
		subsets: bool, give_back: float, ring_share := 0.0, deep := false) -> Dictionary:
	var cells: Array[Vector2i] = []
	for y in n:
		for x in n:
			cells.append(Vector2i(x, y))
	_shuffle(cells, rng)
	var mushrooms := {}
	for i in k:
		mushrooms[cells[i]] = true
	var rings := {}
	var num := {}
	for c in cells:
		if mushrooms.has(c):
			continue
		# Rolled only on a band with rings, so the plain bands deal the very
		# fields they dealt before rings existed.
		var is_ring := ring_share > 0.0 and rng.randf() < ring_share
		if is_ring:
			rings[c] = true
		var m := 0
		for p in reach(c, n, is_ring):
			if mushrooms.has(p):
				m += 1
		num[c] = m
	var bare: Array[Vector2i] = []
	bare.assign(num.keys())
	_shuffle(bare, rng)
	var given := num.duplicate()
	var dropped: Array[Vector2i] = []
	for g in bare:
		var v: int = given[g]
		given.erase(g)
		if solvable(given, n, k, subsets, rings):
			dropped.append(g)
		else:
			given[g] = v
	if deep:
		# The second carve: what the subsets solver needed, tried again with
		# suppositions allowed.
		var left: Array[Vector2i] = []
		left.assign(given.keys())
		_shuffle(left, rng)
		for g in left:
			var v: int = given[g]
			given.erase(g)
			if solvable(given, n, k, subsets, rings, true):
				dropped.append(g)
			else:
				given[g] = v
	_shuffle(dropped, rng)
	for i in int(round(dropped.size() * give_back)):
		given[dropped[i]] = num[dropped[i]]
	var kept_rings := {}
	for g in rings:
		if given.has(g):
			kept_rings[g] = true
	return {"n": n, "k": k, "mushrooms": mushrooms, "given": given, "rings": kept_rings,
		"ok": solvable(given, n, k, subsets, kept_rings, deep)}

# --- the bank (content/insane/mushroom.json) ---

## A field as the bank keeps it: `field` one character a cell in reading
## order -- "*" a mushroom, "." a covered bare cell, "0".."8" a number that
## counts its eight, "a".."q" a fairy ring counting 0..16.
static func to_bank(out: Dictionary) -> Dictionary:
	var n: int = int(out.n)
	var s := ""
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			if out.mushrooms.has(c):
				s += "*"
			elif out.given.has(c):
				var v: int = int(out.given[c])
				s += String.chr(97 + v) if out.rings.has(c) else str(v)
			else:
				s += "."
	return {"n": n, "k": int(out.k), "field": s}

## The bank's field back as generate() hands one over; {} for an entry that
## is not a field. `ok` checks every number is its field's own count; with
## `prove` the deep solver re-proves the whole field too. The game does not
## prove: a deep solve is 72 ms on the Mac (138 worst over twenty), close to
## a second on a phone as the card opens, and every banked field was proved
## by the miner and is re-proved by the ladder's grade (Queens' precedent).
static func from_bank(board: Dictionary, prove := false) -> Dictionary:
	if board.is_empty() or not board.has("field") or not board.has("n"):
		return {}
	var n: int = int(board.n)
	var s: String = str(board.field)
	if s.length() != n * n:
		return {}
	var mushrooms := {}
	var given := {}
	var rings := {}
	for i in s.length():
		var c := Vector2i(i % n, i / n)
		var ch := s[i]
		if ch == "*":
			mushrooms[c] = true
		elif ch >= "0" and ch <= "8":
			given[c] = int(ch)
		elif ch >= "a" and ch <= "q":
			given[c] = ch.unicode_at(0) - 97
			rings[c] = true
	var k: int = mushrooms.size()
	# The numbers must be the field's own counts, or the bank is lying.
	for g in given:
		var m := 0
		for p in reach(g, n, rings.has(g)):
			if mushrooms.has(p):
				m += 1
		if m != int(given[g]):
			return {"n": n, "k": k, "mushrooms": mushrooms, "given": given, "rings": rings, "ok": false}
	return {"n": n, "k": k, "mushrooms": mushrooms, "given": given, "rings": rings,
		"ok": solvable(given, n, k, true, rings, true) if prove else k > 0}

## Fisher-Yates, seeded only by `rng`.
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
