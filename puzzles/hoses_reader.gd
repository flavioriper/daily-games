extends RefCounted

## Hosepipes read the way a player reads a bed (2026-10-28, the made-fun
## pass): by what one square shows, never by trying a hose out. Each square
## needs its links: a tap, a flower or a seed one, any other square two (a
## hose comes in and goes out). Two rules, applied until neither moves:
##
## - **Ways**: a square whose free ways are exactly the links it still
##   needs takes them all (a tap with one free side, a square boxed in to two).
## - **Full**: a square with its links rules its other sides out.
##
## A side is free while the square past it still needs a link, the two are
## not already one hose (a ring), and their hoses may meet: two colours never
## join, a seed takes only a seed hose, and two seeds never share a hose.
##
## The board's bulb reads with it (what to show and why); the probe
## tests/_probe_hs_fun.gd measures how far it gets on a fresh bed.

## A rule the reader fired.
enum Rule { NONE, END, CORNER, LAST }

## How a side stands.
const UNKNOWN := 0
const YES := 1
const NO := 2

## A component's colour: none yet, or "some seed hose".
const FREE := -1
const SEEDY := -2

var n := 0
var N := 0
var nbs: Array = []
## Links a square needs (1 for an end, 2 otherwise).
var need := PackedInt32Array()
## Per square: the colour its end gives it (FREE for a plain square).
var colour := PackedInt32Array()
var _seeded := {}
## Side (a, b) with a < b -> UNKNOWN / YES / NO.
var side := {}
## Square -> its hose piece's id; piece id -> colour.
var comp := PackedInt32Array()
var comp_col := {}
## Links taken per square.
var deg := PackedInt32Array()

func _init(day: Dictionary) -> void:
	n = int(day.n)
	N = n * n
	need.resize(N)
	need.fill(2)
	colour.resize(N)
	colour.fill(FREE)
	comp.resize(N)
	deg.resize(N)
	for i in N:
		comp[i] = i
		comp_col[i] = FREE
		var a := []
		if i % n > 0: a.append(i - 1)
		if i % n < n - 1: a.append(i + 1)
		if i / n > 0: a.append(i - n)
		if i / n < n - 1: a.append(i + n)
		nbs.append(a)
	var ends: Array = day.ends
	for c in ends.size():
		var e: Array = ends[c]
		for k in 2:
			var v := int(e[k])
			if v < 0:
				_seeded[c] = true
				continue
			need[v] = 1
			colour[v] = c
			comp_col[v] = c
	for sc in day.get("seeds", []):
		need[int(sc)] = 1
		colour[int(sc)] = SEEDY
		comp_col[int(sc)] = SEEDY

static func key(a: int, b: int) -> int:
	return mini(a, b) * 4096 + maxi(a, b)

func is_yes(a: int, b: int) -> bool:
	return int(side.get(key(a, b), UNKNOWN)) == YES

## Lays side (a, b) as a link. False when it cannot be one.
func link(a: int, b: int) -> bool:
	if not _free(a, b):
		return false
	side[key(a, b)] = YES
	deg[a] += 1
	deg[b] += 1
	var ca := comp[a]
	var cb := comp[b]
	var col := _meet(int(comp_col[ca]), int(comp_col[cb]))
	for i in N:
		if comp[i] == cb:
			comp[i] = ca
	comp_col[ca] = col
	return true

## Whether side (a, b) could still be a link.
func _free(a: int, b: int) -> bool:
	if int(side.get(key(a, b), UNKNOWN)) != UNKNOWN:
		return false
	if deg[a] >= need[a] or deg[b] >= need[b]:
		return false
	if comp[a] == comp[b]:
		return false
	return _meet(int(comp_col[comp[a]]), int(comp_col[comp[b]])) != -99

## Two pieces' colours joined, -99 when they may not meet.
func _meet(x: int, y: int) -> int:
	if x == FREE:
		return y
	if y == FREE:
		return x
	if x == SEEDY and y == SEEDY:
		return -99
	if x == SEEDY:
		return y if _seeded.has(y) else -99
	if y == SEEDY:
		return x if _seeded.has(x) else -99
	return x if x == y else -99

func free_ways(v: int) -> Array:
	var out := []
	for u in nbs[v]:
		if _free(v, int(u)):
			out.append(int(u))
	return out

## One reading: the first square a rule fires on, in reading order (taps
## and flowers first, then the squares boxed in). {} when nothing fires.
## {cell, rule, ways: [squares it links to]}. Nothing is laid.
func next() -> Dictionary:
	var best := {}
	for v in N:
		var left := need[v] - deg[v]
		if left <= 0:
			continue
		var ways := free_ways(v)
		if ways.size() != left:
			continue
		var rule: int = Rule.END if need[v] == 1 else (Rule.CORNER if left == 2 else Rule.LAST)
		if best.is_empty() or rule < int(best.rule):
			best = {"cell": v, "rule": rule, "ways": ways}
			if rule == Rule.END:
				break
	return best

## Reads until stuck: how many links were found.
func run(most := 100000) -> int:
	var found := 0
	while found < most:
		var r := next()
		if r.is_empty():
			break
		for u in r.ways:
			if link(int(r.cell), int(u)):
				found += 1
	return found

## Links the reader has: every YES side.
func links() -> int:
	var k := 0
	for s in side.values():
		if int(s) == YES:
			k += 1
	return k
