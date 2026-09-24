extends RefCounted

## Rings' Insane ladder (tools/insane/README.md's contract). Rings has no
## technique ladder to climb -- it is not a deduction board -- so its Insane is
## a rule, not a harder deal: Hard's six colours on eight pegs, sorted inside
## a move budget of the **shortest** solve plus PAR_SLACK (rings_state.gd).
## The screen caps the deal at 8 pegs and 6 colours, and less slack only makes
## deals dead (85-93%) and the survivors shorter, measured 2026-09-24.
##
## So the "rung" here is that shortest solve's length, found by breadth-first
## search over canonical positions, and the miner keeps the longest. That
## search costs 90-600 ms a deal on this Mac, which is why it runs here and
## the phone only reads the answer. Hard's own play is the game's depth-first
## solver, whose lines run 35-63 moves on the same deals; optima run 16-24.
##
## `unique` is true for any deal the search finishes inside STATE_CAP: a
## ring sort has many answers and uniqueness means nothing here, but a deal
## the search gave up on has no trustworthy par and is thrown away.

const Gen = preload("res://puzzles/rings_gen.gd")

## Deals whose optimum is this or shorter are not kept.
const HARD_RUNG := 19
## Canonical positions the search may visit before giving up on a deal.
const STATE_CAP := 400000

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	return {"pegs": Gen.deal(rng, 3)}

static func grade(board: Dictionary) -> Dictionary:
	var r := shortest(board["pegs"])
	return {"rung": r[0], "work": r[1], "unique": r[0] > 0}

## [length of the shortest solve, positions visited], or [-1, visited] when
## the search ran past STATE_CAP. Moves come from Gen.moves_from, whose two
## prunings (no ring off a locked peg, no uniform peg split onto an empty
## one) can only ever lengthen the answer, never shorten it -- so a par read
## off this is never tighter than the real optimum.
static func shortest(start: Array) -> Array:
	var frontier: Array = [start]
	var seen := {Gen.key(start): true}
	var depth := 0
	while not frontier.is_empty():
		var next: Array = []
		for p in frontier:
			if Gen.solved(p):
				return [depth, seen.size()]
			for m: Vector2i in Gen.moves_from(p):
				var w: Array = []
				for s in p:
					w.append((s as Array).duplicate())
				w[m.y].append(w[m.x].pop_back())
				var k := Gen.key(w)
				if seen.has(k):
					continue
				seen[k] = true
				next.append(w)
			if seen.size() > STATE_CAP:
				return [-1, seen.size()]
		frontier = next
		depth += 1
	return [-1, seen.size()]
