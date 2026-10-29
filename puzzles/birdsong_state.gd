extends RefCounted

## Birdsong's rules, scene-free (spec
## docs/superpowers/specs/2026-10-22-birdsong-design.md, amended the same
## evening for the woodpecker). A woodpecker knocks a rhythm on the old
## tree's trunk, inside one bar of four beats; the player knocks the same
## rhythm back on one drum. The day is one rhythm: each round the woodpecker
## adds one knock somewhere in the bar, and the day's whole rhythm knocked
## back is the solve.
##
## A bar is `grid()` slots (eighths, or sixteenths on Hard and Insane); a
## knock sits on a slot. The rhythm is dealt from the host's rng: always the
## downbeat, the rest on eighths, and on sixteenths one or two quick knocks
## on the "and" of an eighth already knocked (a pair, or a triple with the
## eighth after). The order the knocks come in is dealt too, a quick knock
## never before the eighth it hangs on.
##
## The player's knocks are judged **between their own taps**, never against
## a clock the phone has to agree with: the first knock starts the bar, and
## each one after is held to where the rhythm puts it from there. A phone's
## sound delay is the same on every tap and cancels out. A knock nearer its
## place than `GOOD` is good, nearer than `OK` is fine; anything else -- a
## knock where there is none, or a place passed with no knock -- is a slip,
## which costs nothing but the round: the woodpecker knocks it again.
##
## Times are the board's seconds; nothing here knows the screen.

enum Heard { GOOD, OK, ROUND, SOLVED, SLIP, IGNORED }
## Why a slip was a slip (said on the board's toast): a knock before its
## place, after it, where no knock is, or a place passed with no knock.
enum Why { EARLY, LATE, EXTRA, MISSED }

## Per band, Easy to Insane: the tempo, the slots in a bar, the day's
## knocks, the first round's knocks, how long the holes stay on the card
## (2 through the player's turn, 1 while the woodpecker knocks, 0 never),
## the feints a bar (Insane: the woodpecker draws back without striking)
## and how many times the bulb has it knock the round again.
const BPM := [88, 96, 104, 100]
const GRID := [8, 8, 16, 16]
const KNOCKS := [5, 6, 7, 7]
const START := [2, 3, 3, 3]
const SHOW := [2, 1, 0, 0]
const FEINTS := [0, 0, 0, 2]
const HINTS := [3, 2, 1, 1]
## How near its place a knock must land, in seconds: good, and fine.
const GOOD := 0.09
const OK := 0.17
## A knock past OK but within this of its place is called late rather than
## the place called missed: a place is only given up this long after OK, so
## a late knock is told it was late. What is a slip is unchanged.
const LATE_GRACE := 0.16
## How far a knock may be from the nearest knock's place to be called early
## or late; past it, it is a knock where there is none. It reaches past
## OK + LATE_GRACE, so a knock just before a place is given up is late.
const NEAR := 0.34

var band := 0
## The day's knocks, in the order the rounds add them (slots in the bar).
var order: Array[int] = []
## Each round's feints (Insane), slots with no knock near them.
var feints: Array = []
## The round being played (0 based), its knocks sorted by slot, and the
## knocks the player has landed in it so far.
var round_ix := 0
var knocks: Array[int] = []
var landed := 0
## When the player's bar began (their first knock, less where it sits), or
## INF before it.
var anchor := INF
## This round's knocks, each one's grade (-1 not yet, 0 good, 1 fine).
var grades: Array[int] = []
## The last knock heard: where in the bar it landed (slots, a float) and
## its grade (0 good, 1 fine, 2 off), kept past the round it ended.
var last_slot := 0.0
var last_grade := 0
## Slips this round, slips in all, rounds knocked back with none, goods and
## fines in all.
var slips_round := 0
var slips := 0
var clean := 0
var goods := 0
var oks := 0
## Each round knocked back, the slips it took.
var history: Array[int] = []
## The last slip: why, and the slot of the knock it was about (the knock
## early, late or missed; where the extra one landed, rounded).
var why := Why.MISSED
var why_slot := 0
## Rounds knocked back clean in a row, the best run of the day, and whether
## the round just knocked back had every knock good.
var run := 0
var best_run := 0
var perfect := false

func deal(rng: RandomNumberGenerator, the_band: int) -> void:
	band = clampi(the_band, 0, BPM.size() - 1)
	var g := grid()
	var st := g / 8
	var n: int = int(KNOCKS[band])
	var eighths: Array[int] = []
	for i in range(1, 8):
		eighths.append(i * st)
	_shuffle(eighths, rng)
	var quick := 0
	if st > 1:
		quick = 1 if rng.randf() < 0.5 else 2
	var chosen: Array[int] = [0]
	for s in eighths:
		if chosen.size() >= n - quick:
			break
		chosen.append(s)
	var tries := 0
	while chosen.size() < n and tries < 200:
		tries += 1
		var s := 1 + 2 * rng.randi_range(0, g / 2 - 1)
		if not chosen.has(s) and chosen.has(s - 1):
			chosen.append(s)
	for s in eighths:
		if chosen.size() >= n:
			break
		if not chosen.has(s):
			chosen.append(s)
	var rest: Array[int] = []
	for s in chosen:
		if s != 0:
			rest.append(s)
	_shuffle(rest, rng)
	order = [0]
	order.append_array(rest)
	# a quick knock never comes before the eighth it hangs on
	for i in order.size():
		var s: int = order[i]
		if s % 2 == 1 and st > 1:
			var j := order.find(s - 1)
			if j > i:
				order[i] = s - 1
				order[j] = s
	feints.clear()
	for r in rounds():
		feints.append(_feints_for(_knocks_of(r), rng))
	restart()

static func _shuffle(a: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := a[i]
		a[i] = a[j]
		a[j] = t

func _feints_for(k: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	var want: int = int(FEINTS[band])
	if want <= 0:
		return out
	var st := grid() / 8
	var free: Array[int] = []
	for i in range(1, 8):
		var e := i * st
		if not k.has(e) and (st == 1 or not k.has(e - 1) and not k.has(e + 1)):
			free.append(e)
	_shuffle(free, rng)
	for i in mini(want, free.size()):
		out.append(free[i])
	out.sort()
	return out

## Round `r`'s knocks, sorted by slot.
func _knocks_of(r: int) -> Array[int]:
	var out: Array[int] = []
	for i in mini(int(START[band]) + r, order.size()):
		out.append(order[i])
	out.sort()
	return out

## The day from the top: the first round, nothing knocked back.
func restart() -> void:
	round_ix = 0
	slips = 0
	clean = 0
	goods = 0
	oks = 0
	slips_round = 0
	run = 0
	best_run = 0
	perfect = false
	history.clear()
	_begin_round()

func _begin_round() -> void:
	knocks = _knocks_of(mini(round_ix, rounds() - 1))
	begin_turn()

## The player's bar from its start: nothing landed, no anchor.
func begin_turn() -> void:
	landed = 0
	anchor = INF
	grades.clear()
	for k in knocks:
		grades.append(-1)

func grid() -> int:
	return int(GRID[band])

func bpm() -> int:
	return int(BPM[band])

## A beat, a bar and a slot, in seconds.
func beat() -> float:
	return 60.0 / float(BPM[band])

func bar() -> float:
	return beat() * 4.0

func slot_time() -> float:
	return bar() / float(grid())

func rounds() -> int:
	return int(KNOCKS[band]) - int(START[band]) + 1

## The round being played, from 1.
func round_no() -> int:
	return mini(round_ix, rounds() - 1) + 1

func round_feints() -> Array[int]:
	var out: Array[int] = []
	if round_ix < feints.size():
		for s in feints[round_ix]:
			out.append(int(s))
	return out

## The knock this round adds (its slot), or -1 on the first round.
func new_slot() -> int:
	var r := mini(round_ix, rounds() - 1)
	if r <= 0:
		return -1
	return order[mini(int(START[band]) + r - 1, order.size() - 1)]

## How long the holes stay on the card: 2, 1 or 0 (SHOW).
func show() -> int:
	return int(SHOW[band])

func solved() -> bool:
	return round_ix >= rounds()

func started() -> bool:
	return anchor != INF

## Where knock `i` of the round is due, once the bar has begun.
func due(i: int) -> float:
	return anchor + knocks[i] * slot_time()

## Where in the bar (in slots, a float) a knock at `t` landed.
func slot_at(t: float) -> float:
	return (t - anchor) / slot_time() if started() else 0.0

## The player knocked at `t`. The first knock starts the bar.
func heard(t: float) -> Heard:
	if solved() or knocks.is_empty():
		return Heard.IGNORED
	if not started():
		anchor = t - knocks[0] * slot_time()
	last_slot = slot_at(t)
	var best := -1
	var far := INF
	for i in knocks.size():
		if grades[i] >= 0:
			continue
		var d := absf(t - due(i))
		if d < far:
			far = d
			best = i
	if best < 0 or far > OK:
		last_grade = 2
		if best >= 0 and far <= NEAR:
			why = Why.EARLY if t < due(best) else Why.LATE
			why_slot = knocks[best]
		else:
			why = Why.EXTRA
			why_slot = clampi(roundi(last_slot), 0, grid() - 1)
		_slip()
		return Heard.SLIP
	grades[best] = 0 if far <= GOOD else 1
	last_grade = grades[best]
	if far <= GOOD:
		goods += 1
	else:
		oks += 1
	landed += 1
	if landed < knocks.size():
		return Heard.GOOD if far <= GOOD else Heard.OK
	perfect = not grades.has(1)
	if slips_round == 0:
		clean += 1
		run += 1
		best_run = maxi(best_run, run)
	else:
		run = 0
	history.append(slips_round)
	slips_round = 0
	round_ix += 1
	if solved():
		return Heard.SOLVED
	_begin_round()
	return Heard.ROUND

## The board's clock reached `t`: a knock's place passed with no knock is a
## slip. Returns the knock missed, or -1.
func missed(t: float) -> int:
	if not started() or solved():
		return -1
	for i in knocks.size():
		if grades[i] < 0 and t > due(i) + OK + LATE_GRACE:
			why = Why.MISSED
			why_slot = knocks[i]
			_slip()
			return i
	return -1

func _slip() -> void:
	slips += 1
	slips_round += 1
	run = 0

## The share of rounds knocked back without a slip (the brain report).
func quality() -> float:
	return clampf(float(clean) / float(maxi(1, rounds())), 0.0, 1.0)

## A finished day, put back from its record.
func finish(the_history: Array) -> void:
	round_ix = rounds()
	knocks = _knocks_of(rounds() - 1)
	history.clear()
	clean = 0
	slips = 0
	for n in the_history:
		history.append(int(n))
		slips += int(n)
		if int(n) == 0:
			clean += 1

## The day for the share line: a round a square, green knocked back clean,
## yellow after a slip.
func share_glyphs() -> String:
	var out := ""
	for n in history:
		out += "🟩" if n == 0 else "🟨"
	return out
