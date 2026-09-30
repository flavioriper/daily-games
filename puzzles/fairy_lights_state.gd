extends RefCounted

## Fairy Lights' rules, scene-free: what is on the board now, the moves that
## can change it, and everything derived from it. The board
## (puzzles/fairy_lights2d.gd) only draws this.
##
## **Live is derived, every time, and never stored.** `depths()` is a
## breadth-first walk from the post over edges where both sides carry a
## stub, rebuilt from `grid` on every call. Queens' rule, and it is what
## makes Undo free: there is no highlight to put back.
##
## **Solved is the rule, not the answer.** `is_solved()` checks that every
## stub meets a stub (`loose(i) == 0` everywhere) and that every cell has a
## depth (`depths()` has no -1 left). It never compares `grid` against
## `sol` -- the propagate-only solver already proved `sol` is the one
## arrangement that satisfies that rule, so the two claims agree, but only
## one of them is ever asked.
##
## **A hint is a given.** `hint()` settles the first unsolved cell in
## reading order to its answer, pins it so it can never be turned again,
## counts itself and empties the undo log (Shikaku's rule) -- what it
## settled is not a move to take back. `reset_board()` respects the pin.
##
## **Hard and Insane judge one thing: a turn of a piece that is already
## right** (`judged`, and only on a proved garden -- the rare unproved
## fallback plays safe). Every judged garden has one answer, so a deducing
## player never needs to touch a right piece. Such a tap changes nothing: the
## piece is clipped for good (`clipped`), nothing goes in the undo log, no
## turn is counted, and `turn()` says RIGHT so the board can blow a fuse and
## take a heart. The hearts are the board's to count, off `hearts_for`.
##
## **Insane is Wish Tags**: some lanterns wear a tag with their distance
## along the wire from the post (`tags`), dealt from the bank or, when it is
## empty or broken, a live 8x8 with every lantern tagged. Solved then also
## asks that every tag's lantern sits at its tag's depth.
## Spec: docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md,
## sections 3, 3.1 and 8; docs/superpowers/specs/2026-09-30-fairylights-
## polish-design.md, sections 1 and 2.

const Gen = preload("res://puzzles/fairy_lights_gen.gd")
const InsaneBank = preload("res://core/insane_bank.gd")

## Per band, Easy .. Insane: the hints a garden starts with, and its hearts
## (0 is a band that cannot be lost).
const HINTS := [3, 3, 1, 0]
const HEARTS := [0, 0, 3, 2]

## What a turn did, or why it was turned down.
const OK := 0
const CROSS := 1
const PINNED := 2
## A judged garden: the piece was already right. Nothing changed; it is
## clipped now, and the board blows a fuse.
const RIGHT := 3
## A fuse already showed this piece was right: refused for free.
const CLIPPED := 4

## What a tag reads off the wire as it stands (`tag_state`), never off the
## answer.
const TAG_NONE := 0   # this cell wears no tag
const TAG_UNLIT := 1  # its lantern is not joined to the post
const TAG_MATCH := 2  # lit, and its depth is the tag
const TAG_OFF := 3    # lit at some other depth

var n: int = 0
var post: int = 0
var grid: PackedInt32Array = PackedInt32Array()  # what is on the board now
var deal: PackedInt32Array = PackedInt32Array()  # the scramble, for Reset
var sol: PackedInt32Array = PackedInt32Array()   # the generator's answer
var pinned: PackedByteArray = PackedByteArray()  # 1 where a hint settled a cell
## 1 where a fuse showed the piece was already right. It holds its answer
## for good: no turn, undo or reset moves it. Try again lifts every clip
## (`clear_clips`).
var clipped: PackedByteArray = PackedByteArray()
## 0 Easy .. 3 Insane: which HINTS and HEARTS row this garden reads.
var band: int = 0
## Whether the garden's one answer is proved: the propagate-only solver's
## `proved`, or a banked Wish Tags garden (the miner's proof).
var proved: bool = false
## Whether a turn of a right piece is judged (RIGHT): Hard and Insane, on a
## proved garden only.
var judged: bool = false
## Whether this Insane garden came off the bank rather than the live fallback.
var banked: bool = false
## Wish Tags only: lantern cell -> the depth written on its tag. Empty on
## every other band.
var tags: Dictionary = {}
var turns: int = 0
var hints: int = 0
## Newest last: the cell a tap turned. One undo, one entry.
var history: PackedInt32Array = PackedInt32Array()

## `bank_step` is PuzzleBase.bank_step: how many times New has been pressed
## since the board opened, which walks Insane through its bank.
func start(rng: RandomNumberGenerator, difficulty: int, bank_step := 0) -> void:
	band = clampi(difficulty, 0, Gen.SIZES.size() - 1)
	var out: Dictionary = {}
	banked = false
	if band == 3:
		# Wish Tags is dealt from the bank: stripping tags down to the few
		# the proof needs runs the tag solver dozens of times a garden, and
		# the miner keeps the gardens that needed the most suppositions,
		# which a live deal cannot look for as the card opens. The phone
		# checks the entry holds together (Gen.from_bank, 0.3 ms on the Mac)
		# and trusts the miner's proof: re-running the tag solver costs 2-8
		# ms a banked garden on the Mac, a guessed 10-40 on a phone. An empty
		# bank or an entry that fails grows a live garden.
		out = Gen.from_bank(InsaneBank.pick("fairylights", bank_step))
		if out.is_empty() and InsaneBank.size("fairylights") > 0:
			push_warning("Fairy Lights: a banked garden did not hold together; growing a live one")
		banked = not out.is_empty()
	if out.is_empty():
		out = Gen.build(rng, band)
		# The live Insane fallback: a propagate-proved 8x8 with every lantern
		# wearing its tag.
		out["tags"] = Gen.all_tags(out.n, out.post, out.sol) if band == 3 else {}
	n = out.n
	post = out.post
	sol = out.sol
	deal = out.deal
	tags = out.tags
	proved = bool(out.proved)
	judged = hearts_for(band) > 0 and proved
	grid = deal.duplicate()
	pinned = PackedByteArray()
	pinned.resize(n * n)
	pinned.fill(0)
	clipped = PackedByteArray()
	clipped.resize(n * n)
	clipped.fill(0)
	history = PackedInt32Array()
	turns = 0
	hints = 0

## The hints a band starts with.
static func hints_for(b: int) -> int:
	return int(HINTS[clampi(b, 0, HINTS.size() - 1)])

## The hearts a band starts with; 0 is a band that cannot be lost.
static func hearts_for(b: int) -> int:
	return int(HEARTS[clampi(b, 0, HEARTS.size() - 1)])

# --- reading the board. None of this is cached. ---

## Whether the stub `i` has facing `side` (one of Gen.N/E/S/W) meets a stub
## coming back. False off the grid, and false when `i` has no stub there to
## begin with -- either way there is no live edge on that side. Symmetric by
## construction: `matched(i, side)` and `matched(j, opposite)` read the same
## two bits (`grid[i] & side` and `grid[j] & opposite`) and the same
## adjacency, whichever cell asks.
func matched(i: int, side: int) -> bool:
	if grid[i] & side == 0:
		return false
	var d := _dir(side)
	var r: int = i / n
	var c: int = i % n
	var a: int = r + Gen.DR[d]
	var b: int = c + Gen.DC[d]
	if a < 0 or b < 0 or a >= n or b >= n:
		return false
	var j: int = a * n + b
	var od := 1 << ((d + 2) % 4)
	return grid[j] & od != 0

## The mask of `i`'s own stubs that do not meet a stub back -- a wall, the
## grid's edge, or a closed neighbour. Zero means every stub of this cell is
## joined.
func loose(i: int) -> int:
	var m: int = grid[i]
	var out := 0
	for side in [Gen.N, Gen.E, Gen.S, Gen.W]:
		if m & side != 0 and not matched(i, side):
			out |= side
	return out

## A breadth-first walk from the post over edges where both sides carry a
## stub -- rebuilt from `grid` every call, never stored. -1 for a cell the
## walk never reaches.
func depths() -> PackedInt32Array:
	var cells := n * n
	var out := PackedInt32Array()
	out.resize(cells)
	out.fill(-1)
	if cells == 0:
		return out
	out[post] = 0
	var queue := PackedInt32Array([post])
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var r: int = i / n
		var c: int = i % n
		for d in range(4):
			var side := 1 << d
			if not matched(i, side):
				continue
			var a: int = r + Gen.DR[d]
			var b: int = c + Gen.DC[d]
			var j: int = a * n + b
			if out[j] != -1:
				continue
			out[j] = out[i] + 1
			queue.append(j)
	return out

## Every stub meets a stub, every cell has a depth, and on Wish Tags every
## tag's lantern sits at its tag's depth. Never a comparison against `sol` --
## see the file header.
func is_solved() -> bool:
	var cells := n * n
	for i in cells:
		if loose(i) != 0:
			return false
	var d := depths()
	for i in cells:
		if d[i] == -1:
			return false
	for i in tags:
		if d[i] != int(tags[i]):
			return false
	return true

## What the tag on cell `i` reads off the wire as it stands: TAG_NONE for a
## cell with no tag, TAG_UNLIT when its lantern is not joined to the post,
## TAG_MATCH when it is and its depth is the tag, TAG_OFF at another depth.
## Pass `d` (a `depths()` taken this frame) to read many tags off one walk.
func tag_state(i: int, d := PackedInt32Array()) -> int:
	if not tags.has(i):
		return TAG_NONE
	if d.size() != n * n:
		d = depths()
	if d[i] < 0:
		return TAG_UNLIT
	return TAG_MATCH if d[i] == int(tags[i]) else TAG_OFF

## Whether this garden is Wish Tags (tags to draw and to read).
func wish_tags() -> bool:
	return not tags.is_empty()

## The degree-1 cells -- a paper lantern on a stub -- in reading order. A
## cell's degree does not change under rotation, so this reads `sol` rather
## than `grid`: it is where a lantern stands, not which way it faces.
func lanterns() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in n * n:
		if Gen.degree(sol[i]) == 1:
			out.append(i)
	return out

# --- the moves ---

## One quarter turn clockwise. A cross has nowhere else to go (CROSS, no
## change); a pinned cell is a given (PINNED, no change); a clipped cell was
## shown right by a fuse (CLIPPED, no change). On a judged garden a piece
## that is already right is not turned at all: it is clipped for good, every
## earlier turn of it leaves the undo log (so no undo can take it off its
## answer), no turn is counted, and the answer is RIGHT -- the board's fuse.
func turn(i: int) -> int:
	if pinned[i] == 1:
		return PINNED
	var m: int = grid[i]
	if m == Gen.N | Gen.E | Gen.S | Gen.W:
		return CROSS
	if i < clipped.size() and clipped[i] == 1:
		return CLIPPED
	if judged and m == sol[i]:
		clipped[i] = 1
		var kept := PackedInt32Array()
		for h in history:
			if h != i:
				kept.append(h)
		history = kept
		return RIGHT
	grid[i] = Gen.cw(m)
	history.append(i)
	turns += 1
	return OK

## Turns the last tapped cell back a quarter turn. The cell, or -1 on an
## empty log.
func undo() -> int:
	if history.is_empty():
		return -1
	var i: int = history[history.size() - 1]
	history.resize(history.size() - 1)
	grid[i] = Gen.ccw(grid[i])
	return i

## The first unsolved cell in reading order, settled to its answer and
## pinned. A clipped cell is always on its answer, so it is never the one. Empties the undo log: what a hint gives is not a move to take
## back. The cell, or -1 when the board is already solved.
func hint() -> int:
	for i in n * n:
		if grid[i] == sol[i]:
			continue
		grid[i] = sol[i]
		pinned[i] = 1
		hints += 1
		history = PackedInt32Array()
		return i
	return -1

## Every unpinned, unclipped cell back to the scramble it was dealt. A
## pinned cell is a given and stays exactly where the hint left it; a
## clipped one keeps its answer, since it can no longer be turned.
func reset_board() -> void:
	for i in n * n:
		if pinned[i] == 0 and clipped[i] == 0:
			grid[i] = deal[i]
	history = PackedInt32Array()

## Lifts every clip, for Try again. Moves nothing: call it **before**
## `reset_board()` so the once-clipped pieces go back to the deal too.
func clear_clips() -> void:
	clipped.fill(0)

## How many pieces a fuse has clipped.
func clips() -> int:
	return clipped.count(1)

## The bit position (0..3) of a side mask (Gen.N/E/S/W), matching Gen.DR/DC.
static func _dir(side: int) -> int:
	match side:
		Gen.N: return 0
		Gen.E: return 1
		Gen.S: return 2
		Gen.W: return 3
	return -1
