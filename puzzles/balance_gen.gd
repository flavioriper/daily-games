extends RefCounted

## Balance scales: visual simultaneous equations.
##
## Weights are integers in [1, max_w] (MAX_W by default, 12 on Insane -- see
## `generate`'s `max_w` param). Each scale is a homogeneous linear
## equation over the shapes -- which means the solution set is closed under
## scaling, so scales alone can NEVER pin down a unique answer. One shape's
## weight is therefore revealed as an anchor. With the anchor fixed, brute
## force over the remaining domain makes uniqueness exact and instant.

const MAX_W := 9

## `max_w` is the top of a weight's range: 9 by default, 12 on Insane
## (registry difficulty 3), threaded through to every place a weight is
## drawn or bounded.
static func generate(rng: RandomNumberGenerator, shapes: int, max_w: int = MAX_W) -> Dictionary:
	# Build the secret so every shape after the first is the sum of shapes
	# already introduced. That guarantees a relating scale actually exists --
	# with sides capped at three, a secret like (1, 9) has no expressible
	# relation at all and could never be pinned down.
	var built := _build_secret(rng, shapes, max_w)
	var secret: Array = built.secret
	var defs: Array = built.defs

	var scales: Array = []
	for i in range(1, shapes):
		if not (defs[i] as Array).is_empty():
			scales.append({"left": [i], "right": (defs[i] as Array).duplicate()})

	# A couple of extra true statements so the board is not just one
	# definition per shape. Trimming keeps whichever subset stays minimal.
	for _k in 2:
		var extra := _random_balanced(rng, secret, shapes)
		if not extra.is_empty() and not _duplicate(scales, extra):
			scales.append(extra)

	# Anchoring shape 0 always works because the construction is triangular.
	# Prefer a less predictable anchor when one still yields uniqueness.
	var anchor := {"shape": 0, "value": secret[0]}
	var order: Array = []
	for i in shapes:
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	for cand in order:
		var a := {"shape": cand, "value": secret[cand]}
		if count_solutions(scales, shapes, 2, a, max_w) == 1:
			anchor = a
			break

	# Drop any scale the others already imply.
	var trimmed: Array = scales.duplicate()
	for sc in scales:
		var trial: Array = trimmed.duplicate()
		trial.erase(sc)
		if count_solutions(trial, shapes, 2, anchor, max_w) == 1:
			trimmed = trial
	return {
		"secret": secret,
		"scales": trimmed,
		"anchor": anchor,
		"unique": count_solutions(trimmed, shapes, 2, anchor, max_w) == 1,
		"max_w": max_w,
	}

static func _build_secret(rng: RandomNumberGenerator, shapes: int, max_w: int = MAX_W) -> Dictionary:
	var secret: Array = [rng.randi_range(1, 4)]
	var defs: Array = [[]]
	for i in range(1, shapes):
		var placed := false
		for _attempt in 40:
			var side: Array = []
			for _k in rng.randi_range(1, 3):
				side.append(rng.randi_range(0, i - 1))
			side.sort()
			var total := _sum(side, secret)
			if total >= 1 and total <= max_w:
				secret.append(total)
				defs.append(side)
				placed = true
				break
		if not placed:
			# Fall back to copying an existing shape, which is always expressible.
			var src: int = rng.randi_range(0, i - 1)
			secret.append(secret[src])
			defs.append([src])
	return {"secret": secret, "defs": defs}

## A scale is {left: Array[shape_index], right: Array[shape_index]}.
static func balances(sc: Dictionary, weights: Array) -> bool:
	return _sum(sc.left, weights) == _sum(sc.right, weights)

static func count_solutions(scales: Array, shapes: int, limit: int, anchor: Dictionary, max_w: int = MAX_W) -> int:
	var w: Array = []
	for i in shapes:
		w.append(1)
	return _enumerate(scales, shapes, w, 0, limit, anchor, max_w)

static func _enumerate(scales: Array, shapes: int, w: Array, idx: int, limit: int, anchor: Dictionary, max_w: int = MAX_W) -> int:
	if idx == shapes:
		for sc in scales:
			if not balances(sc, w):
				return 0
		return 1
	var lo := 1
	var hi := max_w
	if int(anchor.shape) == idx:
		lo = int(anchor.value)
		hi = int(anchor.value)
	var found := 0
	for v in range(lo, hi + 1):
		w[idx] = v
		found += _enumerate(scales, shapes, w, idx + 1, limit - found, anchor, max_w)
		if found >= limit:
			return found
	return found

static func _random_balanced(rng: RandomNumberGenerator, secret: Array, shapes: int) -> Dictionary:
	for _attempt in 60:
		var left: Array = _random_side(rng, shapes)
		var right: Array = _random_side(rng, shapes)
		if _sum(left, secret) != _sum(right, secret):
			continue
		var ls: Array = left.duplicate(); ls.sort()
		var rs: Array = right.duplicate(); rs.sort()
		if ls == rs:
			continue  # vacuously true, teaches nothing
		return {"left": left, "right": right}
	return {}

static func _random_side(rng: RandomNumberGenerator, shapes: int) -> Array:
	var side: Array = []
	for i in rng.randi_range(1, 3):
		side.append(rng.randi_range(0, shapes - 1))
	side.sort()
	return side

static func _sum(side: Array, weights: Array) -> int:
	var t := 0
	for s in side:
		t += int(weights[s])
	return t

static func _duplicate(scales: Array, sc: Dictionary) -> bool:
	for existing in scales:
		if existing.left == sc.left and existing.right == sc.right:
			return true
		if existing.left == sc.right and existing.right == sc.left:
			return true
	return false
