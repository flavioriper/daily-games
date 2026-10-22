extends RefCounted

## Hosepipes' rules (spec docs/superpowers/specs/2026-10-22-hoses-design.md).
## Each colour has two ends on the bed, a tap and a flower; on Insane
## (Seedlings) some flowers are bare seeds, which any seed hose may water. A
## hose is drawn from either of its coloured ends, a square at a time;
## hoses never share a square. The bed is done when every hose joins its
## ends and every square is watered.
##
## A stroke is one finger's drag. It starts on an end (that hose starts
## again from it) or on a hose (cut back to that square and drawn on from
## it). Backing over the hose shortens it. Crossing another hose cuts it
## where it was crossed, and it grows back if the stroke backs off again:
## the other hoses are always the stroke's start, cut at the first square
## the live hose holds now.

const Gen = preload("res://puzzles/hoses_gen.gd")

## The bulb, by band.
const HINTS := [3, 2, 1, 1]

## How a step of a stroke was heard.
enum Step { NONE, GROW, BACK, CUT, JOIN, REFUSE }

var band := 0
var n := 5
## Per hose: [tap, flower], the flower -1 for a seed hose.
var ends: Array = []
## The seeds' squares (Insane).
var seeds: Array = []
## The answer: per hose, its squares tap..flower (a seed hose's to its seed).
var answer: Array = []
## Per hose, its squares from the end it was drawn from; [] when undrawn.
var hoses: Array = []
## [hoses before] per stroke or bulb, the latest last.
var history: Array = []
## The hose under the finger and the hoses as its stroke found them.
var live := -1
var _before: Array = []
## Strokes that changed the bed (the brain report has no score here).
var strokes := 0
var hinted := 0
## Square -> [hose, which end] for every tap and flower.
var _end_at := {}

func deal(rng: RandomNumberGenerator, the_band: int, bank_step := 0) -> void:
	band = clampi(the_band, 0, 3)
	var day: Dictionary = {}
	# Hard and Insane are mined on the Mac (tools/insane/hoses*_ladder.gd): a
	# bed proven to have one answer takes too long at board open on a phone.
	# An empty bank, or an entry that does not hold together, deals live.
	if band >= 2:
		var bank := "hoses" if band == 3 else "hoses_hard"
		day = Gen.from_bank(InsaneBank.pick(bank, bank_step))
		if day.is_empty() and InsaneBank.size(bank) > 0:
			push_warning("Hosepipes: a banked day did not hold together; dealing a live one")
	if day.is_empty():
		day = Gen.deal(rng, band)
	# never seen in 365 days a band; a day that stalls is dealt again from
	# seeds the day's own rng hands on, so every player still gets one bed
	var again := 0
	while day.is_empty() and again < 20:
		var next := RandomNumberGenerator.new()
		next.seed = rng.randi()
		day = Gen.deal(next, band)
		again += 1
	load_day(day)

func load_day(day: Dictionary) -> void:
	n = int(day.n)
	ends = day.ends
	seeds = day.get("seeds", [])
	answer = day.paths
	_end_at = {}
	for c in ends.size():
		var e: Array = ends[c]
		_end_at[int(e[0])] = [c, 0]
		if int(e[1]) >= 0:
			_end_at[int(e[1])] = [c, 1]
	restart()

func count() -> int:
	return ends.size()

## Every hose taken up.
func restart() -> void:
	hoses = []
	for c in ends.size():
		hoses.append([])
	history.clear()
	live = -1
	_before = []

## The hose on square `cell` (-1 for none) as the bed stands.
func owner(cell: int) -> int:
	for c in hoses.size():
		if (hoses[c] as Array).has(cell):
			return c
	return -1

## The hose whose tap or flower is on `cell`, -1 when it is neither.
func end_of(cell: int) -> int:
	return int((_end_at[cell] as Array)[0]) if _end_at.has(cell) else -1

func is_tap(cell: int) -> bool:
	return _end_at.has(cell) and int((_end_at[cell] as Array)[1]) == 0

func is_seed(cell: int) -> bool:
	return seeds.has(cell)

func seeded(c: int) -> bool:
	return int((ends[c] as Array)[1]) < 0

## The seed hose that waters seed `cell`, -1 while it is bare.
func seed_owner(cell: int) -> int:
	for c in hoses.size():
		var h: Array = hoses[c]
		if not h.is_empty() and int(h[h.size() - 1]) == cell:
			return c
	return -1

## Whether hose `c` joins its ends.
func joined(c: int) -> bool:
	var h: Array = hoses[c]
	if h.size() < 2:
		return false
	var e: Array = ends[c]
	var first := int(h[0])
	var last := int(h[h.size() - 1])
	if seeded(c):
		return first == int(e[0]) and seeds.has(last)
	return (first == int(e[0]) and last == int(e[1])) or (first == int(e[1]) and last == int(e[0]))

func joined_count() -> int:
	var k := 0
	for c in hoses.size():
		if joined(c):
			k += 1
	return k

## Squares under a hose.
func watered() -> int:
	var k := 0
	for h: Array in hoses:
		k += h.size()
	return k

func squares() -> int:
	return n * n

func solved() -> bool:
	return joined_count() == hoses.size() and watered() == n * n

## Every hose joined but squares still dry: the bed says so.
func all_joined_dry() -> bool:
	return joined_count() == hoses.size() and watered() < n * n

func adjacent(a: int, b: int) -> bool:
	var ax := a % n
	var bx := b % n
	return (a / n == b / n and absi(ax - bx) == 1) or (ax == bx and absi(a / n - b / n) == 1)

# --- strokes ---

## A finger down on `cell`: the hose it starts or picks up, -1 for none.
func begin(cell: int) -> int:
	live = -1
	var c := end_of(cell)
	if c >= 0:
		# an end starts its hose again from itself
		_before = _copy(hoses)
		hoses[c] = [cell]
		live = c
		return c
	c = owner(cell)
	if c < 0:
		return -1
	var h: Array = hoses[c]
	# a seed hose's last square is a seed: it is picked up from its tap side
	_before = _copy(hoses)
	hoses[c] = h.slice(0, h.find(cell) + 1)
	live = c
	return c

## The live hose steps onto `cell`, next to its head. What it was heard as.
func step(cell: int) -> int:
	if live < 0:
		return Step.NONE
	var c := live
	var h: Array = hoses[c]
	var head := int(h[h.size() - 1])
	if cell == head or not adjacent(cell, head):
		return Step.NONE
	var at := h.find(cell)
	if at >= 0:
		hoses[c] = h.slice(0, at + 1)
		_regrow()
		return Step.BACK
	# a joined hose goes no further
	if joined(c):
		return Step.REFUSE
	var e := end_of(cell)
	if e >= 0 and e != c:
		return Step.REFUSE
	if is_seed(cell) and not seeded(c):
		return Step.REFUSE
	var cut_before := _cut_count()
	h.append(cell)
	_regrow()
	if joined(c):
		return Step.JOIN
	return Step.CUT if _cut_count() > cut_before else Step.GROW

## The live hose cut back to `cell`, one of its own squares further back
## than the step before its head (a finger slid back along it).
func back_to(cell: int) -> bool:
	if live < 0:
		return false
	var h: Array = hoses[live]
	var at := h.find(cell)
	if at < 0 or at == h.size() - 1:
		return false
	hoses[live] = h.slice(0, at + 1)
	_regrow()
	return true

## The head of the live hose, -1 when none is in hand.
func head() -> int:
	if live < 0:
		return -1
	var h: Array = hoses[live]
	return int(h[h.size() - 1])

## The finger lifted: whether the stroke changed the bed (one Undo's worth).
func end_stroke() -> bool:
	if live < 0:
		return false
	# a hose of its end alone is no hose
	if (hoses[live] as Array).size() < 2:
		hoses[live] = []
	live = -1
	var changed := not _same(hoses, _before)
	if changed:
		history.append(_before)
		strokes += 1
	_before = []
	return changed

## The other hoses as the stroke found them, each cut at the first square
## the live hose holds now.
func _regrow() -> void:
	var mine := {}
	for v in hoses[live]:
		mine[int(v)] = true
	for d in hoses.size():
		if d == live:
			continue
		var was: Array = _before[d]
		var keep := was.size()
		for i in was.size():
			if mine.has(int(was[i])):
				keep = i
				break
		hoses[d] = was.slice(0, keep) if keep > 1 else []

## Squares the other hoses have lost to the stroke so far.
func _cut_count() -> int:
	var k := 0
	for d in hoses.size():
		if d != live:
			k += (_before[d] as Array).size() - (hoses[d] as Array).size()
	return k

## The hoses a stroke cut: [hose, square it was cut at] for the board's puff.
func cut_hoses() -> Array:
	var out := []
	if live < 0:
		return out
	for d in hoses.size():
		if d == live:
			continue
		var was: Array = _before[d]
		var now: Array = hoses[d]
		if now.size() < was.size():
			out.append([d, int(was[mini(now.size(), was.size() - 1)])])
	return out

func undo() -> bool:
	if history.is_empty():
		return false
	hoses = history.pop_back()
	live = -1
	return true

## The hose the bulb lays: the first whose drawn hose is not the answer's,
## or -1 when every one is.
func hint_hose() -> int:
	for c in hoses.size():
		if not _is_answer(c):
			return c
	return -1

## The bulb lays hose `c` as the answer has it, cutting what is in its way.
func lay_answer(c: int) -> void:
	history.append(_copy(hoses))
	_before = _copy(hoses)
	live = c
	hoses[c] = (answer[c] as Array).duplicate()
	_regrow()
	# a seed another seed hose ends on is let go
	live = -1
	_before = []
	hinted += 1

func _is_answer(c: int) -> bool:
	var h: Array = hoses[c]
	var a: Array = answer[c]
	if h.size() != a.size():
		return false
	if h == a:
		return true
	var r := a.duplicate()
	r.reverse()
	return h == r

func finish(record: Array) -> void:
	restart()
	for c in mini(record.size(), hoses.size()):
		hoses[c] = (record[c] as Array).duplicate()

func _copy(hs: Array) -> Array:
	var out := []
	for h: Array in hs:
		out.append(h.duplicate())
	return out

func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true
