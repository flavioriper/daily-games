extends RefCounted

## Market Sums' rules (spec docs/superpowers/specs/2026-10-22-market-design.md).
## Six crates stand on the stall, a number on each, and the order board
## names a number. Pick a crate, a sign and another crate: the two become
## one crate holding what they make, where the second stood. Add, take away
## (the smaller from the larger), times and share (only when it shares
## evenly). A crate holding the order fills it, on every band; Insane is a
## longer way, all six crates (2026-10-26: Every Crate, its own rule, gone).

const Gen = preload("res://puzzles/market_gen.gd")
const Op = Gen.Op

## The bulb, by band.
const HINTS := [3, 2, 1, 1]
const SLOTS := 6

## How a combine was heard.
enum Made { MADE, SOLVED, ZERO, UNEVEN, BIG, SAME }

var band := 0
var target := 0
var par := 2
var numbers: Array = []
var answer: Array = []
## The crate in each place, 0 when the place is empty.
var slots: Array[int] = []
## [slots before, from, into, op] per combine, the latest last.
var history: Array = []
## The combines on the stall's way so far, the bulb's too: an undone one is
## taken off (2026-10-26: trying a step and taking it back costs nothing),
## the brain score's count.
var steps := 0
## Combines the bulb made.
var hinted := 0

func deal(rng: RandomNumberGenerator, the_band: int) -> void:
	band = clampi(the_band, 0, 3)
	var day: Dictionary = Gen.deal(rng, band)
	numbers = day.numbers
	target = int(day.target)
	par = int(day.par)
	answer = day.answer
	restart()

## The stall as dealt.
func restart() -> void:
	slots.clear()
	for v in numbers:
		slots.append(int(v))
	history.clear()
	steps = 0

func on_stall() -> int:
	var n := 0
	for v in slots:
		if v > 0:
			n += 1
	return n

## What crate `from` and crate `into` would make under `op`: a number, or
## one of Gen's refusals.
func would(from: int, into: int, op: int) -> int:
	return Gen.combine(slots[from], slots[into], op)

## Crate `from` goes into crate `into` under `op`. What it was heard as.
func make(from: int, into: int, op: int, by_hint := false) -> int:
	if from == into or slots[from] <= 0 or slots[into] <= 0:
		return Made.SAME
	var v := would(from, into, op)
	match v:
		Gen.ZERO: return Made.ZERO
		Gen.UNEVEN: return Made.UNEVEN
		Gen.BIG: return Made.BIG
	history.append([slots.duplicate(), from, into, op])
	slots[into] = v
	slots[from] = 0
	if by_hint:
		hinted += 1
	steps += 1
	return Made.SOLVED if solved() else Made.MADE

## The last combine taken back: [from, into] it was, or [] when none.
func undo() -> Array:
	if history.is_empty():
		return []
	var last: Array = history.pop_back()
	slots.assign(last[0] as Array)
	steps = maxi(0, steps - 1)
	return [int(last[1]), int(last[2])]

func solved() -> bool:
	return slots.has(target)

## Where the crate holding the order stands, or -1.
func filled_at() -> int:
	return slots.find(target) if solved() else -1

## The places on the stall and their numbers, for the solver.
func _live() -> Array:
	var places: Array[int] = []
	var nums: Array = []
	for i in SLOTS:
		if slots[i] > 0:
			places.append(i)
			nums.append(slots[i])
	return [places, nums]

## The fewest steps from the stall as it stands, -1 when the order can no
## longer be made from it.
func steps_left() -> int:
	if solved():
		return 0
	var live := _live()
	var sets := Gen.reach(live[1])
	var m := Gen.smallest(sets, target)
	return Gen.popcount(m) - 1 if m > 0 else -1

## The bulb's step from the stall as it stands: [from, into, op] of a
## shortest way on, or [] when there is none from here.
func hint_step() -> Array:
	if solved():
		return []
	var live := _live()
	var places: Array[int] = live[0]
	var nums: Array = live[1]
	var sets := Gen.reach(nums)
	var m := Gen.smallest(sets, target)
	if m <= 0 or not (sets[m] as Dictionary).has(target):
		return []
	var first: Array = Gen.steps_of(sets, m, target)[0]
	# the step's two numbers, found on the stall among the set's places
	var a := -1
	var b := -1
	for bit in places.size():
		if m & (1 << bit) == 0:
			continue
		var v := int(nums[bit])
		if a < 0 and v == int(first[0]):
			a = places[bit]
		elif b < 0 and v == int(first[1]):
			b = places[bit]
	if a < 0 or b < 0:
		return []
	return [a, b, int(first[2])]

## The stars the stall stands at: 3 while the order can still be made in
## the fewest steps, 2 in one more, 1 past that, 0 once these crates cannot
## make it. Filled, it is the way taken against the fewest.
func stars() -> int:
	var left := steps_left()
	if left < 0:
		return 0
	return stars_for(steps + left)

func stars_for(taken: int) -> int:
	if taken <= par:
		return 3
	return 2 if taken == par + 1 else 1

## The crate nearest the order: [place, how far], [-1, 0] on an empty stall.
func nearest() -> Array:
	var best := -1
	var far := 0
	for i in SLOTS:
		if slots[i] <= 0:
			continue
		var d := absi(slots[i] - target)
		if best < 0 or d < far:
			best = i
			far = d
	return [best, far]

## The brain score: the fewest steps over the steps of the way taken.
func quality() -> float:
	return clampf(float(par) / float(maxi(steps, par)), 0.0, 1.0)

## A square a step: green within the fewest, yellow past them.
func share_glyphs() -> String:
	var out := ""
	for i in maxi(steps, 1):
		out += "🟩" if i < par else "🟨"
	return out

## A finished day reopened: the stall as it was left, or the answer played.
func finish(left: Array, taken: int) -> void:
	if left.size() == SLOTS:
		slots.assign(left)
		if solved():
			steps = taken
			history.clear()
			return
	restart()
	for s: Array in answer:
		var from := slots.find(int(s[0]))
		var into := -1
		for i in SLOTS:
			if i != from and slots[i] == int(s[1]):
				into = i
				break
		if from >= 0 and into >= 0:
			make(from, into, int(s[2]))
	steps = taken if taken > 0 else par
	history.clear()
