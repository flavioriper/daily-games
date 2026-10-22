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
