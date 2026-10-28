extends RefCounted

## The field read the way a player reads it (2026-10-28, the made-fun pass):
## by what a sign can still reach, never by trying a bed out. Every sign
## keeps the beds it could still be (its own sign and no other inside, the
## size and shape it asks for, clear of the beds already known). Three rules,
## applied until none moves:
##
## - **One way**: a sign with a single bed left takes it.
## - **Only sign**: a bare square that one sign alone can still reach is that
##   sign's, so its beds that miss the square go.
## - **Crowded**: a square every bed of one sign covers is that sign's, so
##   every other sign's beds over it go.
##
## Sound on any board with one answer, scarecrows included (a scarecrow's
## count is not read, so its beds are only ever too many). The board's bulb
## reads with it, from the beds the player has right (what to show and why);
## the probe tests/_probe_sk_fun.gd measures how far it gets on a new field.

const Gen = preload("res://puzzles/shikaku_gen.gd")

## A rule the reader fired.
enum Rule { NONE, ONE_WAY, ONLY, CROWD }

var w := 0
var h := 0
var clues: Array = []
## [i] -> the beds sign i could still be, or [] once it is placed.
var cands: Array = []
## [i] -> the bed sign i is known to have, or a zero Rect2i.
var placed: Array = []
## [i] -> {rule, cell}: what last cut sign i's beds down.
var why: Array = []
## [i] -> every square sign i could reach before anything was read.
var reach: Array = []
## Square (y * w + x) -> the sign it is known to belong to, or -1.
var owner := PackedInt32Array()

## `fixed`: beds known for good (the answer's, as the player has them).
func _init(day_w: int, day_h: int, day_clues: Array, fixed: Array = []) -> void:
	w = day_w
	h = day_h
	clues = day_clues
	owner.resize(w * h)
	owner.fill(-1)
	for i in clues.size():
		placed.append(Rect2i())
		why.append({"rule": Rule.ONE_WAY, "cell": Vector2i(-1, -1)})
		cands.append(Gen.candidates(clues, i, w, h))
	for rect: Rect2i in fixed:
		for i in clues.size():
			if rect.has_point(clues[i].pos):
				_place(i, rect)
				break
	_prune()
	for i in clues.size():
		var cells := {}
		for r: Rect2i in cands[i]:
			for x in range(r.position.x, r.end.x):
				for y in range(r.position.y, r.end.y):
					cells[Vector2i(x, y)] = true
		reach.append(cells.keys())

func _place(i: int, rect: Rect2i) -> void:
	placed[i] = rect
	cands[i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			owner[y * w + x] = i

## Every bed laid over a square owned by another sign goes.
func _prune() -> void:
	for i in clues.size():
		var keep: Array = []
		for r: Rect2i in cands[i]:
			if _clear_for(r, i):
				keep.append(r)
		cands[i] = keep

func _clear_for(r: Rect2i, i: int) -> bool:
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var o := owner[y * w + x]
			if o >= 0 and o != i:
				return false
	return true

func is_placed(i: int) -> bool:
	return placed[i].size != Vector2i.ZERO

## The next bed the reading decides: {clue, rect, rule, cell, by}, the cell
## the rule turned on ((-1, -1) for one way) and, for crowded, the sign whose
## every bed takes it (else -1); {} when the reading is stuck or the field is
## done.
func next() -> Dictionary:
	while true:
		for i in clues.size():
			if not is_placed(i) and cands[i].size() == 1:
				return {"clue": i, "rect": cands[i][0], "rule": int(why[i].rule), "cell": why[i].cell,
					"by": int(why[i].get("by", -1))}
		if not _step():
			return {}
	return {}

## One pass of the square rules; whether anything was cut.
func _step() -> bool:
	var moved := false
	# Only sign.
	for y in h:
		for x in w:
			if owner[y * w + x] >= 0:
				continue
			var at := Vector2i(x, y)
			var who := -1
			var many := false
			for i in clues.size():
				if is_placed(i):
					continue
				for r: Rect2i in cands[i]:
					if r.has_point(at):
						if who >= 0 and who != i:
							many = true
						who = i
						break
				if many:
					break
			if many or who < 0:
				continue
			var keep: Array = []
			for r: Rect2i in cands[who]:
				if r.has_point(at):
					keep.append(r)
			if keep.size() < cands[who].size():
				cands[who] = keep
				why[who] = {"rule": Rule.ONLY, "cell": at}
				moved = true
				if keep.size() == 1:
					return true
	# Crowded.
	for i in clues.size():
		if is_placed(i) or cands[i].is_empty():
			continue
		var core: Rect2i = cands[i][0]
		for r: Rect2i in cands[i]:
			core = core.intersection(r)
		if core.size == Vector2i.ZERO:
			continue
		for j in clues.size():
			if j == i or is_placed(j):
				continue
			var keep: Array = []
			for r: Rect2i in cands[j]:
				if not r.intersects(core):
					keep.append(r)
			if keep.size() < cands[j].size():
				var cut: Rect2i = cands[j][0]
				for r: Rect2i in cands[j]:
					if r.intersects(core):
						cut = r
						break
				cands[j] = keep
				why[j] = {"rule": Rule.CROWD, "cell": cut.intersection(core).position, "by": i}
				moved = true
				if keep.size() == 1:
					return true
	return moved

## The reading to the end: each bed it decides is laid as known, and the
## reading goes on from there. Returns how many beds it laid.
func run() -> int:
	var n := 0
	while true:
		var got := next()
		if got.is_empty():
			return n
		_place(int(got.clue), got.rect)
		_prune()
		n += 1
	return n
