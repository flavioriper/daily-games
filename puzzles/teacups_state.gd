extends RefCounted

## Teacups' rules, scene-free (spec
## docs/superpowers/specs/2026-10-22-teacups-design.md). Cups stand upside
## down on their saucers across the tea table, a little friend hidden under
## each, every friend under two cups. Lift two cups a turn: the same friend
## under both is a pair found and the cups go away; two different ones go
## back under their cups. Every pair found is the solve.
##
## A cup is an id (0 .. 2 * pairs - 1) with a friend (`kind`) and a place on
## the table (`slot`). Insane (Waltz) swaps two hidden cups' places after
## every second miss, in sight of the player, so a cup's id follows it and
## what the player saw of it goes with it.
##
## A **lapse** is the memory measure: the second cup of a turn was not the
## first one's partner although that partner had been seen before the turn.
## A miss that could not have been known is luck, not a lapse.
##
## Nothing here knows time or the screen: the board asks `lift(slot)` and
## acts on what it answers.

enum Lifted { FIRST, PAIR, MISS, SOLVED, IGNORED }

## Per band, Easy to Insane: the table's columns and rows, how many times
## the bulb peeks, and whether hidden cups waltz (Insane's rule).
const COLS := [3, 4, 4, 4]
const ROWS := [4, 4, 5, 5]
const HINTS := [3, 2, 1, 1]
const WALTZ := [false, false, false, true]
## Insane: a waltz after this many misses.
const WALTZ_EVERY := 2
## How many friends there are to hide (ui/faces/teacup.gd's FRIENDS).
const KINDS := 10

var band := 0
## Per cup id: the friend under it, its place, whether it is found, and
## whether the player has seen what is under it.
var kind: Array[int] = []
var slot: Array[int] = []
var found: Array[bool] = []
var seen: Array[bool] = []
## The cup lifted first this turn, -1 none.
var first := -1
var lifts := 0
var misses := 0
var lapses := 0
var pairs_found := 0
## Each pair found, in order: the lapses since the one before it.
var history: Array[int] = []
var _lapses_since := 0
var _rng := RandomNumberGenerator.new()
var _seed := 0

func deal(rng: RandomNumberGenerator, the_band: int) -> void:
	band = clampi(the_band, 0, COLS.size() - 1)
	var n := pairs()
	# the day's friends: the band's count of the ten, in a dealt order
	var pool: Array[int] = []
	for k in KINDS:
		pool.append(k)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := pool[i]
		pool[i] = pool[j]
		pool[j] = t
	kind.clear()
	for p in n:
		kind.append(pool[p % pool.size()])
		kind.append(pool[p % pool.size()])
	# the places, shuffled
	var places: Array[int] = []
	for i in n * 2:
		places.append(i)
	for i in range(places.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := places[i]
		places[i] = places[j]
		places[j] = t
	slot = places
	# the waltzes are the day's too
	_seed = rng.randi()
	restart()

## Every cup down and nothing seen.
func restart() -> void:
	var n := kind.size()
	found.clear()
	seen.clear()
	for i in n:
		found.append(false)
		seen.append(false)
	first = -1
	lifts = 0
	misses = 0
	lapses = 0
	pairs_found = 0
	history.clear()
	_lapses_since = 0
	_rng.seed = _seed

func cols() -> int:
	return int(COLS[band])

func rows() -> int:
	return int(ROWS[band])

func pairs() -> int:
	return cols() * rows() / 2

func cups() -> int:
	return kind.size()

func waltzes() -> bool:
	return bool(WALTZ[band])

func solved() -> bool:
	return pairs_found >= pairs()

## The cup standing at place `s`, -1 none.
func cup_at(s: int) -> int:
	return slot.find(s)

func partner(c: int) -> int:
	for i in kind.size():
		if i != c and kind[i] == kind[c]:
			return i
	return -1

## The player lifted the cup at place `s`.
func lift(s: int) -> Lifted:
	var c := cup_at(s)
	if c < 0 or found[c] or c == first or solved():
		return Lifted.IGNORED
	lifts += 1
	if first < 0:
		first = c
		seen[c] = true
		return Lifted.FIRST
	var a := first
	first = -1
	var b := partner(a)
	# the partner had been seen before this turn and was not the one lifted
	if c != b and seen[b]:
		lapses += 1
		_lapses_since += 1
	seen[c] = true
	if kind[c] != kind[a]:
		misses += 1
		return Lifted.MISS
	found[a] = true
	found[c] = true
	pairs_found += 1
	history.append(_lapses_since)
	_lapses_since = 0
	return Lifted.SOLVED if solved() else Lifted.PAIR

## Whether the miss just counted brings a waltz (Insane).
func waltz_due() -> bool:
	return waltzes() and misses > 0 and misses % WALTZ_EVERY == 0 and hidden().size() >= 2

## The cups still down, by id.
func hidden() -> Array[int]:
	var out: Array[int] = []
	for i in kind.size():
		if not found[i]:
			out.append(i)
	return out

## Two hidden cups trade places: the day's own choice, ids [a, b]. Seen
## cups are chosen first, so the waltz moves something the player holds.
func waltz() -> Array[int]:
	var down := hidden()
	var known: Array[int] = []
	for c in down:
		if seen[c]:
			known.append(c)
	var a: int = known[_rng.randi_range(0, known.size() - 1)] if not known.is_empty() else down[_rng.randi_range(0, down.size() - 1)]
	down.erase(a)
	var b: int = down[_rng.randi_range(0, down.size() - 1)]
	var t := slot[a]
	slot[a] = slot[b]
	slot[b] = t
	return [a, b]

## The bulb: the cups it shows. With a cup up, its partner; with none, the
## first pair still down that the player has seen least of.
func peek() -> Array[int]:
	if first >= 0:
		var b := partner(first)
		seen[b] = true
		return [b]
	var best: Array[int] = []
	var least := 3
	for c in kind.size():
		var b := partner(c)
		if found[c] or b < c:
			continue
		var known := int(seen[c]) + int(seen[b])
		if known < least:
			least = known
			best = [c, b]
	for c in best:
		seen[c] = true
	return best

## The share of pairs found with no lapse (the brain report).
func quality() -> float:
	return clampf(1.0 - float(lapses) / float(maxi(1, pairs())), 0.0, 1.0)

## A finished day, put back from its record.
func finish(the_history: Array, the_lifts: int) -> void:
	for i in found.size():
		found[i] = true
		seen[i] = true
	first = -1
	pairs_found = pairs()
	lifts = the_lifts
	history.clear()
	lapses = 0
	for n in the_history:
		history.append(int(n))
		lapses += int(n)

## The day for the share line: a pair a square, green found with no lapse
## since the last, yellow after one.
func share_glyphs() -> String:
	var out := ""
	for n in history:
		out += "🟩" if n == 0 else "🟨"
	return out
