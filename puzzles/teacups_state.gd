extends RefCounted

## Teacups' rules, scene-free (spec
## docs/superpowers/specs/2026-10-22-teacups-design.md). Cups stand upside
## down on their saucers across the tea table, a little friend hidden under
## each, every friend under two cups. Lift two cups a turn: the same friend
## under both is a pair found and the cups go away; two different ones go
## back under their cups. Every pair found is the solve.
##
## The friends are Peeplets (peeplet/peeplet_personas.gd, the user,
## 2026-10-29: "include the peeplet chars rather than fruits, like it's done
## on who ate the pie"): `persona` holds the day's ten, one a kind, no two in
## one coat, so two friends never read alike at a cup's size.
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

const Personas = preload("res://peeplet/peeplet_personas.gd")

enum Lifted { FIRST, PAIR, MISS, SOLVED, IGNORED }

## Per band, Easy to Insane: the table's columns and rows, how many times
## the bulb peeks, and whether hidden cups waltz (Insane's rule).
const COLS := [3, 4, 4, 4]
const ROWS := [4, 4, 5, 5]
const HINTS := [3, 2, 1, 1]
const WALTZ := [false, false, false, true]
## Insane: a waltz after this many misses.
const WALTZ_EVERY := 2
## How many friends there are to hide, the most a band needs.
const KINDS := 10
## Live stars (ui/flat/star_line.gd) by lapses and bulbs: three up to the
## first, two up to the second, one past. Measured with
## tests/_probe_tc_fun.gd: a casual player's lapses p50/p90 are 0/1, 1/3,
## 1/3 and 3/5 by band.
const STARS_CUT := [[0, 2], [1, 3], [1, 3], [3, 5]]

var band := 0
## Per cup id: the friend under it, its place, whether it is found, and
## whether the player has seen what is under it.
var kind: Array[int] = []
var slot: Array[int] = []
## Per kind: the friend's persona (an index into PeepletPersonas.ALL).
var persona: Array[int] = []
var found: Array[bool] = []
var seen: Array[bool] = []
## The cup lifted first this turn, -1 none.
var first := -1
var lifts := 0
var misses := 0
var lapses := 0
var pairs_found := 0
## Pairs found one after another with no miss between, and the day's best.
var run := 0
var best_run := 0
## The turn just ended: whether its pair was found by memory (the twin seen
## before the turn), and the twin a lapse passed over (-1 none).
var remembered := false
var lapse_twin := -1
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
	# the cast last, so the cups and their places are what they always were
	_cast(rng)
	restart()

## The day's ten Peeplets: the fifty shuffled, taken in order, one a coat.
func _cast(rng: RandomNumberGenerator) -> void:
	var all: Array[int] = []
	for i in Personas.count():
		all.append(i)
	for i in range(all.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := all[i]
		all[i] = all[j]
		all[j] = t
	persona.clear()
	var coats := {}
	for i in all:
		var coat := int(Personas.get_persona(i).coat)
		if coats.has(coat):
			continue
		coats[coat] = true
		persona.append(i)
		if persona.size() >= KINDS:
			break

## The persona under cup `c`.
func persona_of(c: int) -> int:
	return persona[kind[c] % persona.size()]

## The friend under cup `c`'s name.
func name_of(c: int) -> String:
	return String(Personas.get_persona(persona_of(c)).name)

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
	run = 0
	best_run = 0
	remembered = false
	lapse_twin = -1
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
	remembered = c == b and seen[b]
	lapse_twin = -1
	# the partner had been seen before this turn and was not the one lifted
	if c != b and seen[b]:
		lapses += 1
		_lapses_since += 1
		lapse_twin = b
	seen[c] = true
	if kind[c] != kind[a]:
		misses += 1
		run = 0
		return Lifted.MISS
	found[a] = true
	found[c] = true
	pairs_found += 1
	run += 1
	best_run = maxi(best_run, run)
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

## The stars the day stands at with `bulbs` used.
func stars(bulbs: int) -> int:
	var n := lapses + bulbs
	var cut: Array = STARS_CUT[band]
	return 3 if n <= int(cut[0]) else (2 if n <= int(cut[1]) else 1)

## A finished day, put back from its record.
func finish(the_history: Array, the_lifts: int, the_best := 0) -> void:
	best_run = the_best
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
