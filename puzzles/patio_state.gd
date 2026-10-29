extends RefCounted

## Domino Patio's rules, scene-free (spec
## docs/superpowers/specs/2026-10-22-domino-patio-design.md). A patio of
## squares parted into beds, each with a rule; a rack of the house's
## dominoes. Every tile but Insane's spare is laid on two squares side by
## side, and the day is done when the patio is covered and every bed keeps
## its rule. The answer (puzzles/patio_gen.gd) is only the bulb's: the beds
## alone judge the patio.
##
## A tile is where it lies (`at`, an anchor square or -1 on the rack) and
## which way it is turned (`dir`): its first number sits on the anchor and
## its second one step `dir` from it (right, down, left, up), on the patio
## and on the rack alike.

const Gen = preload("res://puzzles/patio_gen.gd")
const Rule = Gen.Rule
const DIRS := Gen.DIRS

enum Bed { OPEN, KEPT, BROKEN }

## Per band, Easy to Insane: the bulb's count (Insane holds Hard's).
const HINTS := [3, 2, 1, 1]

var band := 0
var cols := 0
var rows := 0
var bed_of := PackedInt32Array()
var beds: Array = []
var tiles: Array[Vector2i] = []
var answer: Array[Vector2i] = []
var unique := true
var at: Array[int] = []
var dir: Array[int] = []
## Per square, the tile over it, -1 for none (or off the patio).
var cover := PackedInt32Array()
## Each move's [at, dir] before it, for Undo.
var history: Array = []
## A reading's judged places (`lives`), kept only while it reads.
var _memo := {}
var _reading := false

func deal(rng: RandomNumberGenerator, the_band: int) -> void:
	band = clampi(the_band, 0, 3)
	var g = Gen.new()
	g.deal(rng, band)
	cols = g.cols
	rows = g.rows
	bed_of = g.bed_of
	beds = g.beds
	tiles = g.tiles
	answer = g.answer
	unique = g.unique
	restart()

## Every tile on the rack, turned across.
func restart() -> void:
	at.clear()
	dir.clear()
	for t in tiles.size():
		at.append(-1)
		dir.append(0)
	cover = PackedInt32Array()
	cover.resize(cols * rows)
	cover.fill(-1)
	history.clear()

func spare() -> bool:
	return tiles.size() > laid_count()

## How many tiles the patio holds.
func laid_count() -> int:
	var n := 0
	for i in bed_of.size():
		if bed_of[i] >= 0:
			n += 1
	return n / 2

func on_patio(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows and bed_of[idx(c)] >= 0

func idx(c: Vector2i) -> int:
	return c.y * cols + c.x

func cell(i: int) -> Vector2i:
	return Vector2i(i % cols, i / cols)

## The square tile `t`'s second number lies on, laid at `a` turned `d`.
func other(a: int, d: int) -> int:
	var c := cell(a) + (DIRS[d] as Vector2i)
	return idx(c) if on_patio(c) else -1

## Whether tile `t` may lie at `a` turned `d`: both squares on the patio and
## free of any tile but itself.
func fits(t: int, a: int, d: int) -> bool:
	if a < 0 or a >= cover.size() or bed_of[a] < 0:
		return false
	var b := other(a, d)
	if b < 0:
		return false
	return (cover[a] == -1 or cover[a] == t) and (cover[b] == -1 or cover[b] == t)

func remember() -> void:
	history.append([at.duplicate(), dir.duplicate()])

func undo() -> bool:
	if history.is_empty():
		return false
	var last: Array = history.pop_back()
	var was := dir.duplicate()
	var on_rack := at.duplicate()
	at.assign(last[0])
	dir.assign(last[1])
	# a turn on the rack is no move: a tile on the rack before and after
	# keeps the way the player turned it
	for t in tiles.size():
		if at[t] < 0 and on_rack[t] < 0:
			dir[t] = was[t]
	_cover_all()
	return true

func place(t: int, a: int, d: int) -> void:
	lift(t)
	at[t] = a
	dir[t] = d
	cover[a] = t
	cover[other(a, d)] = t

## Tile `t` back to the rack, keeping its turn.
func lift(t: int) -> void:
	if at[t] < 0:
		return
	cover[at[t]] = -1
	var b := other(at[t], dir[t])
	if b >= 0 and cover[b] == t:
		cover[b] = -1
	at[t] = -1

func _cover_all() -> void:
	cover.fill(-1)
	for t in tiles.size():
		if at[t] >= 0:
			cover[at[t]] = t
			cover[other(at[t], dir[t])] = t

## The two squares tile `t` covers, [] on the rack.
func squares(t: int) -> Array[int]:
	if at[t] < 0:
		return []
	return [at[t], other(at[t], dir[t])]

## The number on square `i`, -1 when nothing covers it.
func spot(i: int) -> int:
	var t := cover[i]
	if t < 0:
		return -1
	return tiles[t].x if at[t] == i else tiles[t].y

## What bed `b` says now: KEPT when it is full and keeps its rule (or has
## none), BROKEN when what lies in it already breaks its rule whatever
## comes, OPEN otherwise. Read off the rule alone, never the answer.
func bed(b: int) -> Bed:
	var info: Dictionary = beds[b]
	var cells: Array = info.cells
	var n := int(info.n)
	var cnt := 0
	var sum := 0
	var first := -1
	var seen := {}
	var broken := false
	for c: int in cells:
		var v := spot(c)
		if v < 0:
			continue
		cnt += 1
		sum += v
		match int(info.rule):
			Rule.SAME:
				if first >= 0 and v != first:
					broken = true
			Rule.APART:
				if seen.has(v):
					broken = true
		if first < 0:
			first = v
		seen[v] = true
	var rem := cells.size() - cnt
	match int(info.rule):
		Rule.SUM:
			broken = broken or sum > n or sum + 6 * rem < n
		Rule.LESS:
			broken = broken or sum >= n
		Rule.MORE:
			broken = broken or sum + 6 * rem <= n
	if broken:
		return Bed.BROKEN
	return Bed.KEPT if rem == 0 else Bed.OPEN

## What lies in bed `b` so far: [the sum, how many squares are covered].
func so_far(b: int) -> Vector2i:
	var sum := 0
	var cnt := 0
	for c: int in beds[b].cells:
		var v := spot(c)
		if v >= 0:
			sum += v
			cnt += 1
	return Vector2i(sum, cnt)

## Why bed `b` is broken, read off its rule: {why, a, b} where `why` is
## "over" (sum past n: a the sum), "short" (sum cannot reach n: a the most
## it can), "less" (a the sum, not under n), "more" (a the most it can, not
## over n), "same" (a and b two numbers that differ), "apart" (a a number
## twice); {} when it is not broken.
func bed_why(b: int) -> Dictionary:
	if bed(b) != Bed.BROKEN:
		return {}
	var info: Dictionary = beds[b]
	var n := int(info.n)
	var got := so_far(b)
	var most := got.x + 6 * ((info.cells as Array).size() - got.y)
	match int(info.rule):
		Rule.SUM:
			return {"why": "over", "a": got.x, "b": n} if got.x > n else {"why": "short", "a": most, "b": n}
		Rule.LESS:
			return {"why": "less", "a": got.x, "b": n}
		Rule.MORE:
			return {"why": "more", "a": most, "b": n}
		Rule.SAME:
			var first := -1
			for c: int in info.cells:
				var v := spot(c)
				if v < 0:
					continue
				if first >= 0 and v != first:
					return {"why": "same", "a": first, "b": v}
				if first < 0:
					first = v
		Rule.APART:
			var seen := {}
			for c: int in info.cells:
				var v := spot(c)
				if v < 0:
					continue
				if seen.has(v):
					return {"why": "apart", "a": v, "b": v}
				seen[v] = true
	return {}

## What laying tile `t` at `a` turned `d` would do, the patio put back
## after: -1 it breaks a bed, 1 it keeps one (fills it to its rule), 0
## neither.
func try_drop(t: int, a: int, d: int) -> int:
	if not fits(t, a, d):
		return 0
	var was_at: int = at[t]
	var was_dir: int = dir[t]
	var mine: Array[int] = []
	for s in [a, other(a, d)]:
		if not mine.has(bed_of[s]):
			mine.append(bed_of[s])
	var before := {}
	for bb in mine:
		before[bb] = bed(bb)
	place(t, a, d)
	var out := 0
	for bb in mine:
		var now := bed(bb)
		if now == Bed.BROKEN and before[bb] != Bed.BROKEN:
			out = -1
			break
		if now == Bed.KEPT and before[bb] != Bed.KEPT and int(beds[bb].rule) != Rule.NONE:
			out = 1
	lift(t)
	if was_at >= 0:
		place(t, was_at, was_dir)
	dir[t] = was_dir
	return out

func covered() -> bool:
	for i in bed_of.size():
		if bed_of[i] >= 0 and cover[i] < 0:
			return false
	return true

func solved() -> bool:
	if not covered():
		return false
	for b in beds.size():
		if bed(b) != Bed.KEPT:
			return false
	return true

## Whether tile `t` lies as the answer has it: on its two squares, turned
## its way, or end for end when both lie in one bed (the bed holds the same).
func right(t: int) -> bool:
	var want: Vector2i = answer[t]
	if want.x < 0 or at[t] < 0:
		return false
	if at[t] == want.x and dir[t] == want.y:
		return true
	var b := other(want.x, want.y)
	if bed_of[want.x] != bed_of[b] and tiles[t].x != tiles[t].y:
		return false
	return at[t] == b and dir[t] == (want.y + 2) % 4

## The bulb's move: the first tile of the answer not lying right, laid where
## the answer has it; whatever lies on those squares goes back to the rack.
## {} when nothing is left to show.
func hint_move() -> Dictionary:
	for t in tiles.size():
		if answer[t].x < 0 or right(t):
			continue
		var a: int = answer[t].x
		var d: int = answer[t].y
		var off: Array[int] = []
		for s in [a, other(a, d)]:
			var o := cover[s]
			if o >= 0 and o != t and not off.has(o):
				off.append(o)
		return {"tile": t, "at": a, "dir": d, "off": off}
	# every answer tile right: only a spare can be out of place, and it
	# cannot be on the patio
	return {}

## Whether tile `t` (lifted) laid at `a` turned `d` breaks neither of its
## beds and leaves every free square beside it a way to be covered (one
## step ahead, so a tile that strands a square is no place for it).
func lives(t: int, a: int, d: int) -> bool:
	if not fits(t, a, d):
		return false
	var key := (t * cover.size() + a) * 4 + d
	if _memo.has(key):
		return _memo[key]
	place(t, a, d)
	var b := other(a, d)
	var ok := bed(bed_of[a]) != Bed.BROKEN and bed(bed_of[b]) != Bed.BROKEN
	if ok:
		for s in [a, b]:
			for dd: Vector2i in DIRS:
				var c := cell(s) + dd
				if on_patio(c) and cover[idx(c)] < 0 and int(_ways(idx(c), false)[0]) == 0:
					ok = false
					break
			if not ok:
				break
	lift(t)
	if _reading:
		_memo[key] = ok
	return ok

## How many places tile `t` could lie (`lives`), the tile itself lifted
## first; a double counts a pair of squares once. [count, anchor, dir] of
## the last place found.
func places(t: int) -> Array:
	var was_at: int = at[t]
	var was_dir: int = dir[t]
	lift(t)
	var n := 0
	var where := Vector2i(-1, 0)
	var turns := 2 if tiles[t].x == tiles[t].y else 4
	for a in bed_of.size():
		if bed_of[a] < 0:
			continue
		for d in turns:
			if lives(t, a, d):
				n += 1
				where = Vector2i(a, d)
	if was_at >= 0:
		place(t, was_at, was_dir)
	else:
		dir[t] = was_dir
	return [n, where.x, where.y]

## How many ways square `s` could be covered now: each tile not on the
## patio, each pair of free squares through `s`, each way round (`lives`).
## [count, tile, anchor, dir] of the last way found.
func ways(s: int) -> Array:
	return _ways(s, true)

func _ways(s: int, ahead: bool) -> Array:
	var n := 0
	var who := [-1, -1, 0]
	if bed_of[s] < 0 or cover[s] >= 0:
		return [0, -1, -1, 0]
	for t in tiles.size():
		if at[t] >= 0:
			continue
		var was_dir: int = dir[t]
		var turns := 2 if tiles[t].x == tiles[t].y else 4
		for k in 4:
			# the pair through s: s first turned k, or s second
			for first in [true, false]:
				var a: int = s if first else other(s, k)
				var d: int = k if first else (k + 2) % 4
				if a < 0 or (turns == 2 and d >= 2):
					continue
				var ok := false
				if ahead:
					ok = lives(t, a, d)
				elif fits(t, a, d):
					place(t, a, d)
					ok = bed(bed_of[a]) != Bed.BROKEN and bed(bed_of[other(a, d)]) != Bed.BROKEN
					lift(t)
				if ok:
					n += 1
					who = [t, a, d]
					if not ahead:
						# one is enough to say the square is not stranded
						dir[t] = was_dir
						return [n, t, a, d]
		dir[t] = was_dir
	return [n, who[0], who[1], who[2]]

## What the bulb's first press reads, as the guides teach the genre, in
## order: a bed already broken (the tile in it lying wrong goes where the
## answer has it); a free square only one tile can cover (`ways`); a tile
## with only one place (`places`); else the answer's tile with the fewest
## places. A reading claims "only one" only when that one way is the
## answer's. hint_move's dictionary with `kind` ("broken", "square",
## "tile", "fewest"), `bed` or `square` and `places` added; {} for none.
func read_hint() -> Dictionary:
	# the board stands still through a reading: each place is judged once
	_memo.clear()
	_reading = true
	var out := _read()
	_reading = false
	_memo.clear()
	return out

func _read() -> Dictionary:
	for b in beds.size():
		if bed(b) != Bed.BROKEN:
			continue
		for c: int in beds[b].cells:
			var t := cover[c]
			if t >= 0 and answer[t].x < 0:
				# the Spare, laid: it goes back to the rack
				return {"tile": t, "at": -1, "dir": dir[t], "off": [] as Array[int], "kind": "broken", "bed": b}
			if t >= 0 and not right(t):
				return _move(t, {"kind": "broken", "bed": b})
	for sq in bed_of.size():
		var w := ways(sq)
		if int(w[0]) == 1 and _answers(int(w[1]), int(w[2]), int(w[3])):
			return _move(int(w[1]), {"kind": "square", "square": sq, "places": 1})
	var fewest := 1 << 20
	var pick := -1
	for t in tiles.size():
		if answer[t].x < 0 or right(t):
			continue
		var p := places(t)
		var n := int(p[0])
		if n == 1 and _answers(t, int(p[1]), int(p[2])):
			return _move(t, {"kind": "tile", "places": 1})
		if n > 0 and n < fewest:
			fewest = n
			pick = t
	if pick < 0:
		var m := hint_move()
		if not m.is_empty():
			m["kind"] = "fewest"
			m["places"] = 0
		return m
	return _move(pick, {"kind": "fewest", "places": fewest})

## Whether tile `t` laid at `a` turned `d` lies as the answer has it.
func _answers(t: int, a: int, d: int) -> bool:
	if t < 0 or answer[t].x < 0:
		return false
	var want: Vector2i = answer[t]
	if a == want.x and d == want.y:
		return true
	var b := other(want.x, want.y)
	return a == b and d == (want.y + 2) % 4 and (bed_of[want.x] == bed_of[b] or tiles[t].x == tiles[t].y)

## Tile `t` to where the answer has it, what lies there off: `extra` added.
func _move(t: int, extra: Dictionary) -> Dictionary:
	var a: int = answer[t].x
	var d: int = answer[t].y
	var off: Array[int] = []
	for sq in [a, other(a, d)]:
		var o := cover[sq]
		if o >= 0 and o != t and not off.has(o):
			off.append(o)
	var out := {"tile": t, "at": a, "dir": d, "off": off}
	out.merge(extra)
	return out

## A finished day, put back: every tile where the answer has it.
func finish() -> void:
	restart()
	for t in tiles.size():
		if answer[t].x >= 0:
			place(t, answer[t].x, answer[t].y)
	history.clear()

## The day put back from a record of where each tile lay.
func finish_from(the_at: Array, the_dir: Array) -> bool:
	if the_at.size() != tiles.size() or the_dir.size() != tiles.size():
		return false
	restart()
	for t in tiles.size():
		var a := int(the_at[t])
		if a >= 0:
			if not fits(t, a, int(the_dir[t])):
				restart()
				return false
			place(t, a, int(the_dir[t]))
		else:
			dir[t] = int(the_dir[t])
	history.clear()
	return solved()

## The rule's words on a bed's tag: "7", "<4", ">9", "=", "≠", "" for none.
static func tag(info: Dictionary) -> String:
	match int(info.rule):
		Rule.SUM:
			return str(int(info.n))
		Rule.LESS:
			return "<" + str(int(info.n))
		Rule.MORE:
			return ">" + str(int(info.n))
		Rule.SAME:
			return "="
		Rule.APART:
			return "≠"
	return ""

## The day for the share line: a square a bed, green kept.
func share_glyphs() -> String:
	var out := ""
	for b in beds.size():
		if int(beds[b].rule) != Rule.NONE:
			out += "🟩"
	return out
