extends RefCounted

## Hedgehogs' rules as the board plays them, scene-free, as every flat
## board's are. The board (puzzles/hedgehogs2d.gd) draws this and nothing
## else.
##
## Rake a covered cell: bare, it shows its number and a nought floods; a
## hedgehog **wakes** -- it becomes a known hedgehog for good, `woken` goes
## up, and the day goes on. A flag keeps the rake off. A raked number whose
## flags and woken hedgehogs match it rakes its other neighbours (a chord).
## Done when every bare cell is raked; flags are never needed.
##
## Hard and Insane can be failed: a wake costs the board a heart (the board
## keeps the hearts; HEARTS_BY says how many). Insane is **Sleepwalkers**:
## every Gen.WALK_EVERY rakes the bell rings and one sleeping hedgehog not
## under a flag steps to a covered pile beside it (`walk`). Only a step
## after which logic still plays the lawn out from what the player can see
## is taken, so the walks never leave a guess; the player is shown the two
## piles that rustled and never which way it went.
##
## Nothing here reads the answer to judge a flag except Check, which is
## paid for. A woken hedgehog and a hint's pinned flag are facts: Undo and
## Reset keep both.
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 6.

const Gen = preload("res://puzzles/hedgehogs_gen.gd")

## The two chips: what a tap on a covered cell does.
const RAKE := 0
const FLAG := 1

## The generated lawn (hedgehogs_gen.gd's dictionary).
var g: Dictionary = {}
var open := PackedByteArray()   # 1 = raked
var flag := PackedByteArray()   # 1 = the player's flag (or a hint's)
var woke := PackedByteArray()   # 1 = a hedgehog a rake woke
var pin := PackedByteArray()    # 1 = a hint's flag, not the player's to lift
## Flags Check found wrong; cleared by any move.
var wrong := PackedByteArray()
var woken := 0
var difficulty := 0
## Sleepwalkers: the lawn as dealt (Try again and Reset put it back), the
## seed of the walks' own order, rakes since the last bell, the last walk's
## two cells (-1 with none) and how many walks there have been.
var dealt_hog := PackedByteArray()
var walk_seed := 0
var walk_rng := RandomNumberGenerator.new()
var bell := 0
var last_walk := Vector2i(-1, -1)
var walks := 0

## Hints and hearts by level: Hard and Insane can be failed.
const HINTS_BY := [3, 3, 2, 0]
const HEARTS_BY := [0, 0, 0, 2]

static func hints_for(d: int) -> int: return HINTS_BY[clampi(d, 0, 3)]
static func hearts_for(d: int) -> int: return HEARTS_BY[clampi(d, 0, 3)]
## One entry per gesture, newest last:
## {"raked": PackedInt32Array, "flags": [[cell, was]]}.
var history: Array = []

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	self.difficulty = difficulty
	g = Gen.generate(rng, difficulty)
	dealt_hog = g.hog.duplicate()
	walk_seed = rng.randi()
	var n: int = g.n
	for a: PackedByteArray in [open, flag, woke, pin, wrong]:
		a.resize(n)
		a.fill(0)
	woken = 0
	restart()

## Whether the hedgehogs sleepwalk (Insane).
func walkers() -> bool:
	return difficulty >= 3

## The lawn back as it was dealt, at its opening: every hedgehog home, no
## rakes, no player's flags and nobody woken (a hint's flags stay: on Hard
## nothing moves, and Insane has none). `woken`, the day's tally, is kept.
## Returns the cells it re-covered.
func restart() -> PackedInt32Array:
	var covered := PackedInt32Array()
	if not dealt_hog.is_empty():
		g.hog = dealt_hog.duplicate()
		Gen.count(g)
	var was := open.duplicate()
	open.fill(0)
	woke.fill(0)
	wrong.fill(0)
	for c in size():
		if pin[c] == 0:
			flag[c] = 0
	Gen.flood(g, open, g.start)
	for c in size():
		if was[c] == 1 and open[c] == 0:
			covered.append(c)
	history = []
	bell = 0
	last_walk = Vector2i(-1, -1)
	walks = 0
	walk_rng.seed = walk_seed
	return covered

## A rake gesture done on Insane: the bell counts it, and on the
## WALK_EVERY-th rings and one hedgehog walks. The walk (from, to), or
## (-1, -1) with none.
func _tick() -> Vector2i:
	if not walkers() or is_solved():
		return Vector2i(-1, -1)
	bell += 1
	if bell < Gen.WALK_EVERY:
		return Vector2i(-1, -1)
	bell = 0
	return walk()

## Whether a step would show its direction: a raked number next to only one
## of the two piles would count one less (it left) or one more (it came).
## Such steps are never taken, so every number either touches both piles
## and stays as it was, or touches neither.
func _tells_way(s: Vector2i) -> bool:
	var from: PackedInt32Array = g.nb[s.x]
	var to: PackedInt32Array = g.nb[s.y]
	for r in from:
		if open[r] == 1 and r != s.y and not to.has(r):
			return true
	for r in to:
		if open[r] == 1 and r != s.x and not from.has(r):
			return true
	return false

## One sleepwalker's step: from a sleeping hedgehog not under a flag to a
## covered, unflagged, empty cell beside it, the first in the walk's own
## shuffled order after which `Gen.prove_from` still plays the lawn out from
## what the player can see (the raked numbers, woken hedgehogs, a hint's
## flags). The numbers are counted again. Returns (from, to), or (-1, -1)
## when no step keeps the lawn provable.
func walk() -> Vector2i:
	var hog: PackedByteArray = g.hog
	var steps: Array[Vector2i] = []
	for c in size():
		if hog[c] == 0 or woke[c] == 1 or flag[c] == 1:
			continue
		for r: int in g.nb[c]:
			if open[r] == 0 and hog[r] == 0 and flag[r] == 0 and woke[r] == 0:
				steps.append(Vector2i(c, r))
	for i in range(steps.size() - 1, 0, -1):
		var j := walk_rng.randi_range(0, i)
		var t := steps[i]
		steps[i] = steps[j]
		steps[j] = t
	var known := PackedByteArray()
	known.resize(size())
	for c in size():
		if woke[c] == 1 or pin[c] == 1:
			known[c] = 1
	var tried := 0
	for s in steps:
		if tried >= Gen.WALK_TRIES:
			break
		if _tells_way(s):
			continue
		tried += 1
		hog[s.x] = 0
		hog[s.y] = 1
		Gen.count(g)
		if Gen.prove_from(g, true, open, known).ok:
			last_walk = s
			walks += 1
			return s
		hog[s.x] = 1
		hog[s.y] = 0
	Gen.count(g)
	return Vector2i(-1, -1)

func cols() -> int: return int(g.get("cols", 0))
func rows() -> int: return int(g.get("rows", 0))
func size() -> int: return int(g.get("n", 0))
func is_hog(c: int) -> bool: return g.hog[c] == 1
func number(c: int) -> int: return int(g.num[c])

## Every bare cell raked.
func is_solved() -> bool:
	if g.is_empty():
		return false
	var hog: PackedByteArray = g.hog
	for c in size():
		if hog[c] == 0 and open[c] == 0:
			return false
	return true

## Flags and woken hedgehogs around `c`.
func marked_around(c: int) -> int:
	var s := 0
	for r: int in g.nb[c]:
		if flag[r] == 1 or woke[r] == 1:
			s += 1
	return s

## The tally: hedgehogs less flags less woken. Negative means too many flags.
func flags_left() -> int:
	var s: int = g.k
	for c in size():
		if flag[c] == 1 or woke[c] == 1:
			s -= 1
	return s

func can_undo() -> bool:
	return not history.is_empty()

## Floods from `c` (already known bare and covered), lifting any flag the
## flood crosses, and returns the flood with rings offset by `ring0`.
func _rake_from(c: int, ring0: int, out_cells: PackedInt32Array, out_rings: PackedInt32Array) -> void:
	for p: Vector2i in Gen.flood(g, open, c):
		if flag[p.x] == 1 and pin[p.x] == 0:
			flag[p.x] = 0
		out_cells.append(p.x)
		out_rings.append(p.y + ring0)

## A tap with the rake on `c`. {"kind", "cells", "rings", "from"}, `kind`
## one of "raked", "woke", "refused_flag", "refused_pin", "none"; a raked
## number forwards to chord().
func rake(c: int) -> Dictionary:
	var res := {"kind": "none", "cells": PackedInt32Array(), "rings": PackedInt32Array(), "from": c}
	if is_solved():
		return res
	if open[c] == 1:
		return chord(c)
	if woke[c] == 1:
		return res
	if flag[c] == 1:
		res.kind = "refused_pin" if pin[c] == 1 else "refused_flag"
		return res
	wrong.fill(0)
	if is_hog(c):
		woke[c] = 1
		woken += 1
		res.kind = "woke"
		res.cells.append(c)
		res.rings.append(0)
		res["walk"] = _tick()
		return res
	var cells := PackedInt32Array()
	var rings := PackedInt32Array()
	_rake_from(c, 0, cells, rings)
	history.append({"raked": cells, "flags": []})
	res.kind = "raked"
	res.cells = cells
	res.rings = rings
	res["walk"] = _tick()
	return res

## A tap on a raked number: if its flags and woken hedgehogs match it, every
## other covered neighbour is raked (a wrong flag among them can wake one).
## {"kind" ("chord", "too_few", "too_many", "none"), "cells", "rings",
## "woke" (PackedInt32Array), "from"}; rings count from the number, so its
## neighbours are ring 1.
func chord(c: int) -> Dictionary:
	var res := {"kind": "none", "cells": PackedInt32Array(), "rings": PackedInt32Array(),
		"woke": PackedInt32Array(), "from": c}
	if open[c] == 0 or is_solved():
		return res
	var v := number(c)
	var covered := PackedInt32Array()
	for r: int in g.nb[c]:
		if open[r] == 0 and flag[r] == 0 and woke[r] == 0:
			covered.append(r)
	# A nought with covered neighbours (a flood ran before they were bare)
	# rakes them like any chord.
	if v < 0 or covered.is_empty():
		return res
	var m := marked_around(c)
	if m != v:
		res.kind = "too_few" if m < v else "too_many"
		return res
	wrong.fill(0)
	var cells := PackedInt32Array()
	var rings := PackedInt32Array()
	for r in covered:
		if open[r] == 1:
			continue
		if is_hog(r):
			woke[r] = 1
			woken += 1
			res.woke.append(r)
			continue
		_rake_from(r, 1, cells, rings)
	if not cells.is_empty():
		history.append({"raked": cells, "flags": []})
	res.kind = "chord"
	res.cells = cells
	res.rings = rings
	res["walk"] = _tick()
	return res

## Lays or lifts a flag on a covered cell. {"kind"}: "laid", "lifted",
## "refused_pin" or "none".
func toggle_flag(c: int) -> Dictionary:
	if is_solved() or open[c] == 1 or woke[c] == 1:
		return {"kind": "none"}
	if pin[c] == 1:
		return {"kind": "refused_pin"}
	wrong.fill(0)
	history.append({"raked": PackedInt32Array(), "flags": [[c, int(flag[c])]]})
	flag[c] = 1 - flag[c]
	return {"kind": "laid" if flag[c] == 1 else "lifted"}

## Takes back the last gesture: {"raked" (re-covered, in flood order),
## "flags" ([[cell, restored value]])}, or {} with nothing to undo. A woken
## hedgehog stays awake, and a pinned or woken cell keeps its flag as it is.
func undo() -> Dictionary:
	if history.is_empty():
		return {}
	wrong.fill(0)
	var h: Dictionary = history.pop_back()
	var raked: PackedInt32Array = h.raked
	for c in raked:
		open[c] = 0
	var flags: Array = []
	for f: Array in h.flags:
		var c := int(f[0])
		# A cell a hint pinned or a rake woke since is a fact now: the
		# flag it had before stays where the fact put it.
		if pin[c] == 1 or woke[c] == 1:
			continue
		flag[c] = int(f[1])
		flags.append([c, int(f[1])])
	# A flood lifts the unpinned flags it crosses; they are not put back,
	# since logic had proved those cells bare.
	return {"raked": raked, "flags": flags}

## Back to the opening. Woken hedgehogs and a hint's flags stay; on
## Sleepwalkers the whole night starts over (`restart`). Returns the cells
## re-covered.
func reset_board() -> PackedInt32Array:
	if walkers():
		return restart()
	var keep := PackedByteArray()
	keep.resize(size())
	Gen.flood(g, keep, g.start)
	var covered := PackedInt32Array()
	for c in size():
		if open[c] == 1 and keep[c] == 0:
			open[c] = 0
			covered.append(c)
		if flag[c] == 1 and pin[c] == 0:
			flag[c] = 0
	wrong.fill(0)
	history = []
	return covered

## The next thing logic can prove from what the player can see (raked
## numbers, woken hedgehogs, a hint's flags -- never the player's flags):
## {"kind": "rake", "cell"} for a cell that must be bare, else {"kind":
## "flag", "cell"} for one that must be a hedgehog and is not yet flagged;
## {} when solved. A hedgehog the player already flagged counts as known once
## logic proves it, and the search moves on.
func hint_step() -> Dictionary:
	if is_solved():
		return {}
	var known := PackedByteArray()
	known.resize(size())
	for c in size():
		if woke[c] == 1 or pin[c] == 1:
			known[c] = 1
	for guard in size():
		var d := Gen.deduce(g, open, known, true)
		if d.is_empty():
			return {}
		for c: int in d.safe:
			if open[c] == 0:
				return {"kind": "rake", "cell": c}
		for c: int in d.hogs:
			if flag[c] == 0:
				return {"kind": "flag", "cell": c}
		for c: int in d.hogs:
			known[c] = 1
	return {}

## Plays a hint_step: a rake (lifting a flag on the cell first) returns
## rake()'s result; a flag is laid and pinned and returns {"kind": "pinned",
## "cell"}.
func apply_hint(step: Dictionary) -> Dictionary:
	var c: int = step.cell
	if step.kind == "rake":
		if flag[c] == 1 and pin[c] == 0:
			flag[c] = 0
		return rake(c)
	wrong.fill(0)
	flag[c] = 1
	pin[c] = 1
	return {"kind": "pinned", "cell": c}

## The flags with no hedgehog under them, marked in `wrong` until the next
## move.
func check() -> PackedInt32Array:
	var out := PackedInt32Array()
	wrong.fill(0)
	for c in size():
		if flag[c] == 1 and not is_hog(c):
			wrong[c] = 1
			out.append(c)
	return out

## A row per lawn row -- a leaf for a covered pile, green for a raked cell, a
## hedgehog for a woken one -- then how many woke. The shape of the day and
## never its answer: a hedgehog left asleep is a leaf like any other pile.
func share_glyphs() -> String:
	var lines := PackedStringArray()
	for y in rows():
		var s := ""
		for x in cols():
			var c := y * cols() + x
			s += "🦔" if woke[c] == 1 else ("🟩" if open[c] == 1 else "🍂")
		lines.append(s)
	return "\n".join(lines)
