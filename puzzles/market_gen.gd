extends RefCounted

## Market Sums' arithmetic (spec docs/superpowers/specs/2026-10-22-market-design.md):
## the one way two crates make a third, the solver and the day's deal. The
## state (puzzles/market_state.gd), the bulb and the deal all combine through
## `combine` here, so a move the board refuses is a move the solver never
## counted.
##
## The solver works by sets of crates: for every set of the crates on the
## stall, every number they can be made into (each crate used once, two at a
## time), with how. Six crates are 63 sets; the whole of it takes a few
## milliseconds, so the phone deals its own day.

enum Op { ADD, SUB, MUL, DIV }

## What a combine can answer besides a number.
const ZERO := -1
const UNEVEN := -2
const BIG := -3
## The largest number a crate can hold.
const CAP := 9999

## The bands: how the six numbers are drawn, how many steps the shortest way
## to the order takes, and where the order may fall. `smalls` numbers are
## drawn from 1..`small_top` and the rest from `bigs`, all different.
## Insane takes all six to the order: five steps, none fewer (2026-10-26:
## the same rule as every band, a longer way, not Every Crate's own rule).
const BANDS := [
	{"smalls": 6, "small_top": 9, "bigs": [], "steps": 2, "lo": 12, "hi": 60},
	{"smalls": 5, "small_top": 10, "bigs": [12, 15, 20, 25], "steps": 3, "lo": 40, "hi": 150},
	{"smalls": 4, "small_top": 10, "bigs": [11, 12, 13, 15, 16, 18, 20, 24, 25], "steps": 4, "lo": 100, "hi": 450},
	{"smalls": 4, "small_top": 10, "bigs": [11, 12, 13, 15, 16, 18, 20, 24, 25], "steps": 5, "lo": 100, "hi": 500},
]

## What `a` and `b` make under `op`, the larger always first: a number, or
## ZERO (a take-away of two equal crates), UNEVEN (a share that leaves a
## remainder) or BIG (past CAP).
static func combine(a: int, b: int, op: int) -> int:
	var hi := maxi(a, b)
	var lo := mini(a, b)
	match op:
		Op.ADD:
			return hi + lo if hi + lo <= CAP else BIG
		Op.SUB:
			return hi - lo if hi != lo else ZERO
		Op.MUL:
			return hi * lo if hi * lo <= CAP else BIG
		_:
			return hi / lo if hi % lo == 0 else UNEVEN

static func popcount(m: int) -> int:
	var n := 0
	while m:
		n += m & 1
		m >>= 1
	return n

## Every number each set of `nums` can be made into, by set (a bit a crate):
## out[mask] = {value: how}, `how` packing the half set, the two numbers
## and the sign (`_pack`), a leaf's -1. Sets of more than `most` crates are
## left empty.
static func reach(nums: Array, most := 6) -> Array:
	var n := nums.size()
	var sets := []
	sets.resize(1 << n)
	for m in range(1, 1 << n):
		var d := {}
		sets[m] = d
		var bits := popcount(m)
		if bits > most:
			continue
		if bits == 1:
			for i in n:
				if m == 1 << i:
					d[int(nums[i])] = -1
			continue
		var s := (m - 1) & m
		while s > 0:
			var t := m ^ s
			if s < t:
				var A: Dictionary = sets[s]
				var B: Dictionary = sets[t]
				# combine()'s four signs, written out: this loop is the
				# solver's whole cost
				for a: int in A:
					for b: int in B:
						var hi := maxi(a, b)
						var lo := mini(a, b)
						var tag := (a << 22) | (b << 8) | (s << 2)
						var v := hi + lo
						if v <= CAP and not d.has(v):
							d[v] = tag | Op.ADD
						v = hi - lo
						if v > 0 and not d.has(v):
							d[v] = tag | Op.SUB
						v = hi * lo
						if v <= CAP and not d.has(v):
							d[v] = tag | Op.MUL
						if hi % lo == 0:
							v = hi / lo
							if not d.has(v):
								d[v] = tag | Op.DIV
			s = (s - 1) & m
	return sets

## The fewest crates of `sets` that make `target`: the set's mask, or 0.
static func smallest(sets: Array, target: int) -> int:
	var best := 0
	var bits := 99
	for m in range(1, sets.size()):
		if (sets[m] as Dictionary).has(target):
			var c := popcount(m)
			if c < bits:
				bits = c
				best = m
	return best

## How `target` comes out of set `mask`, as steps in the order they can be
## made: [[a, b, op, result], ...], each a and b a number on the stall by
## then.
static func steps_of(sets: Array, mask: int, target: int) -> Array:
	var out := []
	_unfold(sets, mask, target, out)
	return out

static func _unfold(sets: Array, mask: int, value: int, out: Array) -> void:
	var how: int = (sets[mask] as Dictionary)[value]
	if how < 0:
		return
	var s := (how >> 2) & 63
	var a := how >> 22
	var b := (how >> 8) & 16383
	_unfold(sets, s, a, out)
	_unfold(sets, mask ^ s, b, out)
	out.append([a, b, how & 3, value])

## The day: {numbers (six, in stall order), target, par, answer}.
static func deal(rng: RandomNumberGenerator, band: int) -> Dictionary:
	var spec: Dictionary = BANDS[clampi(band, 0, 3)]
	var k := int(spec.steps)
	for attempt in 400:
		var nums := _draw(rng, spec)
		var sets := reach(nums, k + 1)
		var fewer := {}
		for m in range(1, sets.size()):
			if popcount(m) <= k:
				for v in sets[m]:
					fewer[v] = true
		var pool: Array[int] = []
		var masks := {}
		for m in range(1, sets.size()):
			if popcount(m) != k + 1:
				continue
			for v: int in sets[m]:
				if v >= int(spec.lo) and v <= int(spec.hi) and not fewer.has(v) and not masks.has(v):
					pool.append(v)
					masks[v] = m
		if pool.is_empty():
			continue
		pool.sort()
		var target: int = pool[rng.randi_range(0, pool.size() - 1)]
		return {"numbers": nums, "target": target, "par": k,
			"answer": steps_of(sets, int(masks[target]), target)}
	# never reached on any band's numbers; a plain sum keeps the day playable
	var nums := _draw(rng, spec)
	var t := int(nums[0]) + int(nums[1]) + int(nums[2])
	return {"numbers": nums, "target": t, "par": 2, "answer": []}

## Six different numbers for the band, smallest first.
static func _draw(rng: RandomNumberGenerator, spec: Dictionary) -> Array:
	var smalls: Array = []
	for v in range(1, int(spec.small_top) + 1):
		smalls.append(v)
	_shuffle(rng, smalls)
	var out: Array = smalls.slice(0, int(spec.smalls))
	var bigs: Array = (spec.bigs as Array).duplicate()
	_shuffle(rng, bigs)
	out.append_array(bigs.slice(0, 6 - out.size()))
	out.sort()
	return out

static func _shuffle(rng: RandomNumberGenerator, list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = list[i]
		list[i] = list[j]
		list[j] = x
