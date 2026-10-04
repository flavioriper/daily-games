extends RefCounted

## Sunbeam's rules, scene-free, as every flat board's are. The board
## (puzzles/sunbeam2d.gd) draws this and nothing else.
##
## A greenhouse floor with a lamp on one edge, a bud, a few dewdrops and a few
## pots, and brass mirrors and copper cups each riding its own rail of pegs.
## The one move is sliding a piece to another peg of its rail; a peg another
## piece covers is taken by no one. **Nothing wrong can sit on the floor**:
## the beam is traced after every move and *is* the check, so there is no
## Check -- only Undo, Reset and Hint.
##
## Solved when the beam lights every dewdrop and ends in the bud. What is
## judged is the light, never where the pieces stand; the generator proves
## exactly one arrangement does it.
##
## Hard and Insane can be lost (2026-10-01, the polish). **Sleepers**: on
## Hard a few snails nap on the floor, and a move let go with the light on
## one wakes it; on Insane (Shy Dew) the dewdrops themselves are shy, and a
## move let go with the light on any drop dries it -- unless that move is the
## solve, every drop at once. Either costs a heart and the move is taken
## back (`judge`, `take_back`). The generator proves a way home that never
## wakes a sleeper. Spec: docs/superpowers/specs/2026-10-01-sunbeam-polish-design.md.
## Spec: docs/superpowers/specs/2026-09-26-sunbeam-flat-design.md, section 6.

const Gen = preload("res://puzzles/sunbeam_gen.gd")
const InsaneBank = preload("res://core/insane_bank.gd")

const HINTS_BY := [3, 3, 2, 0]
const HEARTS_BY := [0, 0, 0, 2]

var difficulty := 0

## The generated floor (sunbeam_gen.gd's dictionary), read by the board.
var g := {}
var cols := 0
var rows := 0
var unique := true
## Each piece's peg now, and at the opening.
var pos := PackedInt32Array()
var start := PackedInt32Array()
## Every arrangement before a move that changed it, for Undo.
var history: Array[PackedInt32Array] = []
## Pieces a hint slid home: they stay there, and no drag moves them.
var pinned := {}
## The beam for `pos`, traced after every change.
var beam := {}

static func hints_for(band: int) -> int:
	return HINTS_BY[clampi(band, 0, HINTS_BY.size() - 1)]

static func hearts_for(band: int) -> int:
	return HEARTS_BY[clampi(band, 0, HEARTS_BY.size() - 1)]

## Insane reads a mined Shy Dew floor from the bank; without one it deals
## Hard's floor live, snails and all.
func build(rng: RandomNumberGenerator, band: int, bank_step := 0) -> void:
	difficulty = band
	g = {}
	if band >= 3:
		g = Gen.from_bank(InsaneBank.pick("sunbeam", bank_step))
	if g.is_empty():
		g = Gen.generate(rng, mini(band, 2))
	setup()

## Lays the floor `g` out at its opening.
func setup() -> void:
	cols = g.cols
	rows = g.rows
	unique = g.unique
	start = g.start.duplicate()
	pos = start.duplicate()
	history.clear()
	pinned = {}
	retrace()

func shy() -> bool:
	return bool(g.get("shy", false))

func snails() -> PackedInt32Array:
	return g.get("snails", PackedInt32Array())

## The cells a let-go move must never leave the light on: the snails, or on
## Shy Dew the drops.
func sleepers() -> PackedInt32Array:
	return drops() if shy() else snails()

## The sleepers the light is on now.
func woken() -> PackedInt32Array:
	var out := PackedInt32Array()
	var lit: Dictionary = beam.get("lit", {})
	for c in sleepers():
		if lit.has(c):
			out.append(c)
	return out

## Prices the arrangement a move was let go in: "" when it is fine (the solve
## always is), "snail" when the light rests on a snail, "dry" when on Shy Dew
## it rests on a drop.
func judge() -> String:
	if is_solved() or woken().is_empty():
		return ""
	return "dry" if shy() else "snail"

## A judged move taken back: the pieces as they were, no history entry.
func take_back(before: PackedInt32Array) -> void:
	pos = before.duplicate()
	retrace()

func size() -> int:
	return cols * rows

func pieces() -> Array:
	return g.get("pieces", [])

func home(p: int) -> int:
	return int(g.pieces[p].home)

func home_pos() -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in pieces().size():
		out.append(home(p))
	return out

func cells_of(p: int, q: int) -> PackedInt32Array:
	return Gen.cells_of(g, p, q)

func retrace() -> void:
	beam = Gen.trace(g, pos)

## Whether piece `p` standing on peg `q` would overlap another piece.
func taken(p: int, q: int) -> bool:
	var mine := cells_of(p, q)
	for o in pos.size():
		if o == p:
			continue
		for c in cells_of(o, pos[o]):
			if mine.has(c):
				return true
	return false

## The free peg nearest a float index along `p`'s rail: a piece hops a peg
## another piece stands on rather than stopping short of it.
func snap(p: int, s: float) -> int:
	var n: int = g.pieces[p].rail.size()
	var order: Array = range(n)
	order.sort_custom(func(a, b): return absf(float(a) - s) < absf(float(b) - s))
	for q in order:
		if not taken(p, q):
			return q
	return pos[p]

## Moves piece `p` to peg `q` without a history entry (a drag's live step).
func place(p: int, q: int) -> bool:
	if pos[p] == q or pinned.has(p) or taken(p, q):
		return false
	pos[p] = q
	retrace()
	return true

## Remembers the arrangement a move started from, if the move changed it.
func commit(before: PackedInt32Array) -> bool:
	if before == pos:
		return false
	history.append(before)
	return true

func can_undo() -> bool:
	return not history.is_empty()

func undo() -> bool:
	if history.is_empty():
		return false
	pos = history.pop_back()
	retrace()
	return true

## The pieces in the order the answer's beam meets them.
func answer_order() -> Array:
	var out: Array = []
	for st: Dictionary in Gen.trace(g, home_pos()).steps:
		if st.has("p") and not out.has(st.p):
			out.append(st.p)
	return out

## Slides the first piece along the answer's beam that is not home onto its
## peg and pins it. Whoever stands in the way steps to the nearest free peg
## of its own rail. Returns {piece, moved: {piece: from peg}} or {} when
## there was nothing to do.
func hint() -> Dictionary:
	if is_solved():
		return {}
	var p := -1
	for o: int in answer_order():
		if pos[o] != home(o) and not pinned.has(o):
			if p < 0:
				p = o
			# On a floor with sleepers, the first one that wakes none.
			if sleepers().is_empty() or _quiet_home(o):
				p = o
				break
	if p < 0:
		return {}
	var before := pos.duplicate()
	var target := home(p)
	var mine := cells_of(p, target)
	var moved := {p: pos[p]}
	for o in pos.size():
		if o == p:
			continue
		var hit := false
		for c in cells_of(o, pos[o]):
			if mine.has(c):
				hit = true
		if hit:
			pos[p] = target
			var q := snap(o, float(pos[o]))
			pos[p] = before[p]
			moved[o] = pos[o]
			pos[o] = q
	pos[p] = target
	pinned[p] = true
	history.append(before)
	retrace()
	return {"piece": p, "moved": moved}

## Whether sliding `o` home (whoever is in the way stepping aside) leaves
## the light off every sleeper.
func _quiet_home(o: int) -> bool:
	var keep := pos.duplicate()
	var mine := cells_of(o, home(o))
	for q in pos.size():
		if q == o:
			continue
		for c in cells_of(q, pos[q]):
			if mine.has(c):
				pos[o] = home(o)
				var s := snap(q, float(pos[q]))
				pos[o] = keep[o]
				pos[q] = s
	pos[o] = home(o)
	var tr_ := Gen.trace(g, pos)
	pos = keep
	for c in sleepers():
		if tr_.lit.has(c):
			return false
	return true

## Every piece back to its opening peg, except a pinned one, which keeps its
## answer; anything the opening put under it steps aside.
##
## On a floor with sleepers the pins are dropped and every piece goes back to
## its opening: the opening is the one arrangement proved to have a dark way
## home, and a pinned piece left home can leave the light on a sleeper -- or,
## rarely, cut every dark way off (the review's probe found such a Hard
## floor, which Try again then dealt again and again).
func reset_board() -> void:
	var before := pos.duplicate()
	if not sleepers().is_empty():
		pinned = {}
	for p in pos.size():
		if not pinned.has(p):
			pos[p] = start[p]
	for p in pos.size():
		if not pinned.has(p) and taken(p, pos[p]):
			pos[p] = snap(p, float(pos[p]))
	if before != pos:
		history.append(before)
	retrace()

func lit_drops() -> int:
	return int(beam.get("lit_drops", 0))

func drops() -> PackedInt32Array:
	return g.get("drops", PackedInt32Array())

func is_solved() -> bool:
	return bool(beam.get("won", false))
