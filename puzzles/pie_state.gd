extends RefCounted

## Who Ate the Pie?'s rules (spec docs/superpowers/specs/2026-10-22-pie-design.md).
## Bakers stand in a grid and some of them ate the pie. One baker is cleared
## at the start and says one true thing; mark a baker "ate pie" or "didn't"
## and they say theirs. A mark stands only when the clues showing prove it:
## a mark nothing proves yet is refused for free, a mark the clues prove
## wrong is a slip. Every baker marked is the solve. On Easy to Hard the
## dish says how many ate; on Insane (Empty Dish) nobody says.

const Gen = preload("res://puzzles/pie_gen.gd")

## The bulb, by band: a press rings the clues that prove someone, a second
## press marks them, a bulb each.
const HINTS := [4, 3, 2, 2]
## How a slip dents the score.
const SLIP_COST := 0.25

## How a mark was heard.
enum Marked { MARKED, SOLVED, UNPROVEN, WRONG, IGNORED }

var band := 0
var cols := 3
var rows := 3
## Who ate, a bit a baker.
var ate := 0
var names: Array = []
var faces: Array = []
var clues: Array = []
var start := 0
## Slices gone from the dish (how many ate), -1 on Insane.
var dish := -1
## Who is marked, a bit a baker, and the marks the bulb made.
var marked := 0
var hinted_mask := 0
## [baker, verdict, hinted] per mark, in order; a slip is [baker, verdict, -1].
var history: Array = []
var slips := 0
## What the clues showing prove, kept between marks: {"set", "ate"}.
var _proof := {}

func deal(rng: RandomNumberGenerator, the_band: int) -> void:
	band = clampi(the_band, 0, 3)
	var day: Dictionary = Gen.deal(rng, band)
	cols = int(day.cols)
	rows = int(day.rows)
	ate = int(day.ate)
	names = day.names
	faces = day.faces
	clues = day.clues
	start = int(day.start)
	dish = int(day.dish)
	restart()

func restart() -> void:
	marked = 1 << start
	hinted_mask = 0
	history.clear()
	slips = 0
	_proof = {}

func count() -> int:
	return cols * rows

func eaters() -> int:
	return Gen.popcount(ate)

func found() -> int:
	return Gen.popcount(ate & marked)

func empty_dish() -> bool:
	return dish < 0

func is_marked(i: int) -> bool:
	return marked & (1 << i) != 0

func did_eat(i: int) -> bool:
	return ate & (1 << i) != 0

func solved() -> bool:
	return marked == (1 << count()) - 1

## Who the clues showing prove, not yet marked.
func proof() -> Dictionary:
	if _proof.is_empty():
		var cons := Gen.constraints(clues, marked, cols, rows, dish)
		_proof = Gen.forced(cons, count(), marked, ate & marked)
	return _proof

func proven(i: int) -> bool:
	return int(proof().get("set", 0)) & (1 << i) != 0

## Mark baker `i` as having eaten (`eat`) or not.
func mark(i: int, eat: bool, by_hint := false) -> int:
	if i < 0 or i >= count() or is_marked(i):
		return Marked.IGNORED
	if not proven(i):
		return Marked.UNPROVEN
	if eat != did_eat(i):
		slips += 1
		history.append([i, 1 if eat else 0, -1])
		return Marked.WRONG
	marked |= 1 << i
	if by_hint:
		hinted_mask |= 1 << i
	history.append([i, 1 if eat else 0, 1 if by_hint else 0])
	_proof = {}
	return Marked.SOLVED if solved() else Marked.MARKED

## The baker the bulb would mark: `prefer` if the clues prove them, else
## the first proven in reading order; -1 when none (never, on a fair day).
func hint_baker(prefer := -1) -> int:
	var set := int(proof().get("set", 0))
	if prefer >= 0 and set & (1 << prefer):
		return prefer
	for i in count():
		if set & (1 << i):
			return i
	return -1

## The bulb's first press: the baker it would mark (`prefer` when proven)
## and the bakers whose clues prove them, the fewest of any proven baker:
## {"baker", "clues"}; {} when nobody is proven.
func nudge(prefer := -1) -> Dictionary:
	var set := int(proof().get("set", 0))
	var best := {}
	var fewest := 999
	for i in count():
		if not set & (1 << i):
			continue
		var m := Gen.reasons(clues, marked, cols, rows, dish, ate, i)
		var k := Gen.popcount(m) - (1 if i == prefer else 0)
		if k < fewest:
			fewest = k
			best = {"baker": i, "clues": m}
	return best

## The marked bakers whose clues speak of baker `i`.
func leads(i: int) -> int:
	var m := 0
	for j in count():
		if is_marked(j) and about(j) & (1 << i):
			m |= 1 << j
	return m

## The bakers the clue of `i` speaks of.
func about(i: int) -> int:
	if (clues[i] as Dictionary).is_empty():
		return 0
	return Gen.about(clues[i], cols, rows)

func quality() -> float:
	return clampf(1.0 - SLIP_COST * slips, 0.0, 1.0)

## A square per mark in order: green proven, yellow the bulb's, red a slip.
func share_glyphs() -> String:
	var out := ""
	for h: Array in history:
		out += "🟥" if int(h[2]) < 0 else ("🟨" if int(h[2]) == 1 else "🟩")
	return out

## A finished day: every baker marked, the slips as they were.
func finish(the_history: Array) -> void:
	restart()
	for h in the_history:
		var i := int(h[0])
		if int(h[2]) < 0:
			slips += 1
		else:
			marked |= 1 << i
			if int(h[2]) == 1:
				hinted_mask |= 1 << i
		history.append(h)
	marked = (1 << count()) - 1
