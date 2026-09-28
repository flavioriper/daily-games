extends RefCounted

## Trestle's rules in whole numbers: the day's level, the player's design (a
## list of members between grid points) and what it costs. The physics is
## puzzles/trestle_sim.gd; this only says what may be built.
##
## A member joins two grid points no further apart than a knight's step,
## both buildable (inside the gap and the build rows, off the rock, or an
## anchor). Two members never share both ends. Road climbs no steeper than
## one in one. The design's cost may not pass the budget: a member that would
## is refused, which is the puzzle.
## Spec: docs/superpowers/specs/2026-09-28-trestle-flat-design.md.

const Sim = preload("res://puzzles/trestle_sim.gd")
const Gen = preload("res://puzzles/trestle_gen.gd")

enum Refusal { OK, TOO_LONG, OFF_ZONE, STEEP, BUDGET, SAME, NO_MAT }

var level: Dictionary = {}
var budget := 0
var mats: Array = []
## [{"a": Vector2i, "b": Vector2i, "m": int, "hint": bool}]
var design: Array = []
var proof: Array = []
var _undo: Array = []

func setup(lv: Dictionary) -> void:
	level = lv.duplicate(true)
	budget = int(level.budget)
	mats = []
	for m in level.mats:
		mats.append(int(m))
	proof = []
	for r in level.proof:
		proof.append({"a": Vector2i(int(r[0]), int(r[1])), "b": Vector2i(int(r[2]), int(r[3])), "m": int(r[4])})
	design = []
	_undo = []

func cost() -> int:
	return Sim.cost_of(design)

func left() -> int:
	return budget - cost()

func anchors() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for a in level.anchors:
		out.append(Vector2i(int(a[0]), int(a[1])))
	return out

func is_anchor(p: Vector2i) -> bool:
	return anchors().has(p)

## Every grid point a member ends on, anchors included.
func joints() -> Array[Vector2i]:
	var seen := {}
	var out: Array[Vector2i] = []
	for a in anchors():
		seen[a] = true
		out.append(a)
	for d in design:
		for p in [d.a, d.b]:
			if not seen.has(p):
				seen[p] = true
				out.append(p)
	return out

func find(a: Vector2i, b: Vector2i) -> int:
	for i in design.size():
		var d: Dictionary = design[i]
		if (d.a == a and d.b == b) or (d.a == b and d.b == a):
			return i
	return -1

func why_not(a: Vector2i, b: Vector2i, m: int) -> int:
	if not mats.has(m):
		return Refusal.NO_MAT
	if a == b or find(a, b) >= 0:
		return Refusal.SAME
	if not Gen.fits(a, b):
		return Refusal.TOO_LONG
	if not Gen.buildable(level, a) or not Gen.buildable(level, b):
		return Refusal.OFF_ZONE
	if m == Sim.ROAD and not Gen.road_ok(a, b):
		return Refusal.STEEP
	if Sim.member_cost(a, b, m) > left():
		return Refusal.BUDGET
	return Refusal.OK

func add(a: Vector2i, b: Vector2i, m: int, hint := false) -> bool:
	if why_not(a, b, m) != Refusal.OK:
		return false
	_undo.append({"op": "add", "i": design.size()})
	design.append({"a": a, "b": b, "m": m, "hint": hint})
	return true

func remove(i: int) -> Dictionary:
	if i < 0 or i >= design.size():
		return {}
	var d: Dictionary = design[i]
	if d.get("hint", false):
		return {}
	design.remove_at(i)
	_undo.append({"op": "remove", "i": i, "d": d})
	return d

func can_undo() -> bool:
	return not _undo.is_empty()

## Takes the last edit back; returns {"op": ..., "d": the member} or {}.
func undo() -> Dictionary:
	if _undo.is_empty():
		return {}
	var u: Dictionary = _undo.pop_back()
	if u.op == "add":
		var d: Dictionary = design[u.i]
		design.remove_at(u.i)
		return {"op": "add", "d": d}
	design.insert(u.i, u.d)
	return {"op": "remove", "d": u.d}

## Clears everything but the hinted members.
func reset() -> Array:
	var gone: Array = []
	var kept: Array = []
	for d in design:
		if d.get("hint", false):
			kept.append(d)
		else:
			gone.append(d)
	design = kept
	_undo = []
	return gone

## The next member of the proof not yet built. It replaces whatever the
## player built on the same two points; when the budget will not stretch,
## the player's own members furthest from it are taken down until it does.
## Returns {"d": member, "removed": [members]} or {}.
func apply_hint() -> Dictionary:
	for p in proof:
		var i := find(p.a, p.b)
		if i >= 0 and design[i].m == p.m:
			if not design[i].get("hint", false):
				design[i]["hint"] = true
				# the stack's own add of this member would take the hint back
				_undo = []
				return {"d": design[i], "removed": []}
			continue
		var removed: Array = []
		if i >= 0:
			removed.append(design[i])
			design.remove_at(i)
		var need := Sim.member_cost(p.a, p.b, p.m)
		var mid := Vector2(p.a + p.b) * 0.5
		while need > left():
			var far := -1
			var far_d := -1.0
			for k in design.size():
				if design[k].get("hint", false) or _in_proof(design[k]):
					continue
				var dd := (Vector2(design[k].a + design[k].b) * 0.5).distance_to(mid)
				if dd > far_d:
					far_d = dd
					far = k
			if far < 0:
				break
			removed.append(design[far])
			design.remove_at(far)
		var d := {"a": p.a, "b": p.b, "m": p.m, "hint": true}
		design.append(d)
		_undo = []
		return {"d": d, "removed": removed}
	return {}

func _in_proof(d: Dictionary) -> bool:
	for p in proof:
		if p.m == d.m and ((p.a == d.a and p.b == d.b) or (p.a == d.b and p.b == d.a)):
			return true
	return false

func hints_placed() -> int:
	var n := 0
	for d in design:
		if d.get("hint", false):
			n += 1
	return n

## The design as the sim takes it.
func for_sim() -> Array:
	var out: Array = []
	for d in design:
		out.append({"a": d.a, "b": d.b, "m": d.m})
	return out
