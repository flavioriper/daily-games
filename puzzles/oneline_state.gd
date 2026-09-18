extends RefCounted

## One Line's rules, with no scene under them: the figure's posts and lines,
## which of them have been walked, where the stroke stands, and every move
## that can change any of it. The flat board (puzzles/oneline2d.gd) draws this
## and nothing else, so what is on trial on the phone is the screen and not
## the game.
##
## The generator is the island's own, untouched (puzzles/oneline_gen.gd), and
## so is the ladder, so a day hands the flat card and the island the identical
## figure. The rule is the cheapest correctness guarantee in the catalogue: a
## connected graph has an Eulerian path exactly when it has zero or two
## odd-degree posts, so there is no search anywhere in here -- only a degree
## count.
##
## Everything Hint and Check need is one question asked twice:
## `walkable_from()` -- whether the lines still unwalked can all be taken in
## one stroke from where the player stands -- and `stranded()`, the lines that
## can no longer be reached at all. Stranding is the only way to lose One
## Line, and the board says so *after* it happens and never before.
## Spec: docs/superpowers/specs/2026-09-18-oneline-flat-design.md, section 3.

const Gen = preload("res://puzzles/oneline_gen.gd")

const HINTS := 3
## The lattice and its fill per difficulty: the island's own ladder
## (puzzles/oneline3d.gd). Measured over 200 generated boards a step: easy is
## about 11.5 lines over 8.4 posts, 4.8 of them diagonal; medium 15.4 over
## 10.9; hard 20 over 13.8, 9.3 diagonal.
const DIMS := [[3, 3, 0.55], [4, 3, 0.5], [4, 4, 0.45]]

## What step() did, so the board knows whether to lay a plank, dip the post or
## say nothing at all.
enum { STEP_NONE, STEP_OK, STEP_WALKED }

var cols := 3
var rows := 3
var edges: Array = []          # [Vector2i], one line each
var nodes: Array = []          # the lattice indices the figure actually uses
## The odd-degree posts. Empty means the stroke may begin anywhere; otherwise
## it must begin at one of these two, which is what the green caps say.
var starts: Array = []
var adj: Dictionary = {}       # node -> [{"to": int, "i": int}]
## Edge index -> true once walked.
var walked: Dictionary = {}
## Edge index -> the post it was walked *from*. A line is an unordered pair,
## so without this a plank would grow from its lower-numbered end whichever
## way the walker actually crossed it, and half of all steps would lay their
## trail against the snail rather than behind it.
var lay_from: Dictionary = {}
## Where the stroke stands, -1 before it begins.
var current := -1
var walk: Array[int] = []      # the posts in the order they were stood on
var trail: Array[int] = []     # the edge indices in the order they were walked

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	var d: Array = DIMS[clampi(difficulty, 0, DIMS.size() - 1)]
	cols = d[0]
	rows = d[1]
	var out: Dictionary = Gen.generate(rng, cols, rows, d[2])
	edges = out.edges
	nodes = out.nodes
	starts = out.starts
	adj = {}
	for i in edges.size():
		var e: Vector2i = edges[i]
		for pair in [[e.x, e.y], [e.y, e.x]]:
			if not adj.has(pair[0]):
				adj[pair[0]] = []
			adj[pair[0]].append({"to": pair[1], "i": i})
	walked = {}
	lay_from = {}
	current = -1
	walk = []
	trail = []

# --- the rule ---

## Whether post `n` may begin the stroke. A figure with two odd-degree posts
## must be begun at one of them; one with none may be begun anywhere.
func may_start(n: int) -> bool:
	return starts.is_empty() or starts.has(n)

## The post a hint begins at: the first odd one, which is also where
## Gen.find_path starts its trail.
func start_post() -> int:
	if not starts.is_empty():
		return int(starts[0])
	return int(nodes[0]) if not nodes.is_empty() else -1

## The edge index joining `a` and `b`, or -1 when they are not joined.
func edge_between(a: int, b: int) -> int:
	for q in adj.get(a, []):
		if int(q.to) == b:
			return int(q.i)
	return -1

## Every edge index still unwalked.
func remaining() -> Array[int]:
	var out: Array[int] = []
	for i in edges.size():
		if not walked.has(i):
			out.append(i)
	return out

## Unwalked lines still touching post `n`. Zero means the post is finished
## with, which is what its pale cap says.
func open_at(n: int) -> int:
	var count := 0
	for q in adj.get(n, []):
		if not walked.has(int(q.i)):
			count += 1
	return count

## Whether every edge in `rest` can still be walked in one stroke from `v`:
## the Eulerian condition applied to what is left. The unwalked lines must all
## hang together in one piece that `v` is part of, and the odd-degree posts
## among them must be none, or exactly two with `v` one of them. It is the
## only thing that can go wrong in One Line and the only thing Hint needs to
## know.
func walkable_from(rest: Array[int], v: int) -> bool:
	if rest.is_empty():
		return true
	var a: Dictionary = {}
	var deg: Dictionary = {}
	for i in rest:
		var e: Vector2i = edges[i]
		for pair in [[e.x, e.y], [e.y, e.x]]:
			if not a.has(pair[0]):
				a[pair[0]] = []
			a[pair[0]].append(pair[1])
			deg[pair[0]] = int(deg.get(pair[0], 0)) + 1
	if not a.has(v):
		return false
	var seen: Dictionary = {v: true}
	var stack: Array = [v]
	while not stack.is_empty():
		var cur = stack.pop_back()
		for n in a[cur]:
			if not seen.has(n):
				seen[n] = true
				stack.append(n)
	for i in rest:
		var e: Vector2i = edges[i]
		if not seen.has(e.x) or not seen.has(e.y):
			return false
	var odd: Array = []
	for n in deg:
		if int(deg[n]) % 2 == 1:
			odd.append(n)
	if odd.is_empty():
		return true
	return odd.size() == 2 and odd.has(v)

## Unwalked lines that can no longer be reached from where the stroke stands.
## Before it begins nothing is stranded -- the figure is still whole and every
## post is still a possible opening.
func stranded() -> Array[int]:
	var out: Array[int] = []
	if current < 0:
		return out
	var rest := remaining()
	var a: Dictionary = {}
	for i in rest:
		var e: Vector2i = edges[i]
		for pair in [[e.x, e.y], [e.y, e.x]]:
			if not a.has(pair[0]):
				a[pair[0]] = []
			a[pair[0]].append(pair[1])
	var seen: Dictionary = {current: true}
	var stack: Array = [current]
	while not stack.is_empty():
		var cur = stack.pop_back()
		for n in a.get(cur, []):
			if not seen.has(n):
				seen[n] = true
				stack.append(n)
	for i in rest:
		if not seen.has(edges[i].x):
			out.append(i)
	return out

## The far post of one line whose walking still leaves every other line
## reachable in one stroke, or -1 when every step from here strands something.
## A hint can therefore never be the move that loses the puzzle, and when
## there is no safe step it has nothing honest to offer.
func safe_step() -> int:
	if current < 0:
		return -1
	for q in adj.get(current, []):
		var i := int(q.i)
		if walked.has(i):
			continue
		var rest := remaining()
		rest.erase(i)
		if walkable_from(rest, int(q.to)):
			return int(q.to)
	return -1

func lines_left() -> int:
	return edges.size() - walked.size()

func is_solved() -> bool:
	return not edges.is_empty() and walked.size() == edges.size()

func share_glyphs() -> String:
	return "✏️ %d lines in one stroke" % edges.size()

# --- moves ---

## Stands the walker on post `n` to open the stroke. False when the figure
## forbids it, which the board answers with a dip and a word.
func begin(n: int) -> bool:
	if not may_start(n):
		return false
	current = n
	walk = [n]
	return true

## Walks the line from the current post to `n`. STEP_NONE when the two are not
## joined (a drag that strays past a post it cannot reach), STEP_WALKED when
## that line has had its one crossing already.
func step(n: int) -> int:
	if n == current or current < 0:
		return STEP_NONE
	var e := edge_between(current, n)
	if e < 0:
		return STEP_NONE
	if walked.has(e):
		return STEP_WALKED
	walked[e] = true
	lay_from[e] = current
	trail.append(e)
	current = n
	walk.append(n)
	return STEP_OK

## Takes back the last line walked and steps back onto the post it was walked
## from: {"edge": int, "from": the post left, "to": the post stood on again}.
## {} when there is nothing to take back. The opening post is not a move and
## cannot be undone -- Reset is what takes that back, as on the island.
func undo() -> Dictionary:
	if trail.is_empty():
		return {}
	var e: int = trail.pop_back()
	var left: int = current
	walked.erase(e)
	lay_from.erase(e)
	walk.pop_back()
	current = walk[-1]
	return {"edge": e, "from": left, "to": current}

## The jetty is taken up again: every plank back to stone and the walker off
## the figure. The hints spent are not refunded.
func reset() -> void:
	walked = {}
	lay_from = {}
	current = -1
	walk = []
	trail = []
