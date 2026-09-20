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
## Seeded only by the `rng` handed in, so a day is the same patch on every
## phone. Spec: docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md,
## section 4.

## n and mushrooms per difficulty: easy, medium, hard.
const SIZES := [[6, 6], [7, 9], [8, 12]]
## Whether the solver may subtract subsets while carving -- the 1-2-1 pattern.
## Hard only, which is what makes hard a different kind of thinking and not
## just a bigger field.
const SUBSETS := [false, false, true]
## What share of the carved-away numbers is handed back.
const GIVE_BACK := [0.45, 0.20, 0.0]
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

## Whether `given` decides every covered cell by logic alone. Two rule
## families, the global count, and -- when `subsets` -- subtraction between
## overlapping numbers. It never guesses and never backtracks: a field it
## cannot finish is a field with a guess in it.
static func solvable(given: Dictionary, n: int, k: int, subsets: bool) -> bool:
	var nb := {}                       # given cell -> its covered neighbours
	for g in given:
		var open: Array[Vector2i] = []
		for p in neighbours(g, n):
			if not given.has(p):
				open.append(p)
		nb[g] = open
	var unknown: Array[Vector2i] = []
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			if not given.has(c):
				unknown.append(c)
	var st := {}                       # covered cell -> true mushroom, false bare
	var mines := 0
	var left := unknown.size()
	var moved := true
	while moved and left > 0:
		moved = false
		var cons: Array = []            # [{"open": Array[Vector2i], "need": int}]
		for g in given:
			var open: Array[Vector2i] = []
			var have := 0
			for p in nb[g]:
				if st.has(p):
					have += 1 if st[p] else 0
				else:
					open.append(p)
			if open.is_empty():
				continue
			var need: int = int(given[g]) - have
			if need <= 0:
				for p in open:
					st[p] = false
					left -= 1
					moved = true
				continue
			if need >= open.size():
				for p in open:
					st[p] = true
					mines += 1
					left -= 1
					moved = true
				continue
			cons.append({"open": open, "need": need})
		if moved:
			continue
		# The global count. This is why the tally strip is on the screen: it
		# is a clue the carve leans on, not decoration.
		if mines == k or mines + left == k:
			var v := mines + left == k
			for p in unknown:
				if not st.has(p):
					st[p] = v
					if v:
						mines += 1
					left -= 1
					moved = true
			if moved:
				continue
		if not subsets:
			break
		for pair in _subtract(cons):
			var cell: Vector2i = pair[0]
			if st.has(cell):
				continue
			st[cell] = bool(pair[1])
			if pair[1]:
				mines += 1
			left -= 1
			moved = true
	return left == 0

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

static func generate(rng: RandomNumberGenerator, n: int, k: int,
		subsets: bool, give_back: float) -> Dictionary:
	var cells: Array[Vector2i] = []
	for y in n:
		for x in n:
			cells.append(Vector2i(x, y))
	_shuffle(cells, rng)
	var mushrooms := {}
	for i in k:
		mushrooms[cells[i]] = true
	var num := {}
	for c in cells:
		if mushrooms.has(c):
			continue
		var m := 0
		for p in neighbours(c, n):
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
		if solvable(given, n, k, subsets):
			dropped.append(g)
		else:
			given[g] = v
	_shuffle(dropped, rng)
	for i in int(round(dropped.size() * give_back)):
		given[dropped[i]] = num[dropped[i]]
	return {"n": n, "k": k, "mushrooms": mushrooms, "given": given,
		"ok": solvable(given, n, k, subsets)}

## Fisher-Yates, seeded only by `rng`.
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
