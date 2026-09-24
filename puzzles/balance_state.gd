extends RefCounted

## Balance's rules with no scene in them: the shapes, the scales, the given
## anchor, the player's guess, which weights are fixed and the undo history.
## The flat board owns one of these and draws whatever it says, the way
## puzzles/binairo_state.gd and puzzles/codebreak_state.gd do for their
## screens, so the screen on trial and the game cannot disagree about what a
## tap, a hint or a reset did. The island board (puzzles/balance3d.gd) still
## carries its own copy of all of this until the 2D-or-3D verdict; whichever
## board survives, this is the one truth to keep.
##
## Nothing in here counts moves or hints: those are the board's tallies on
## PuzzleBase, and they follow the board's own rules (a hint that finishes
## the puzzle counts no move, a reset refunds no hint).
##
## A scale is {"left": [shape index...], "right": [...]} exactly as the
## generator hands it over, and a history entry is {"shape": i, "from": w},
## as the island's `_history` has it.
## Spec: docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 2.

const Gen = preload("res://puzzles/balance_gen.gd")

var shapes: int = 0
var secret: Array = []
var scales: Array = []
var anchor: Dictionary = {}
## The player's answer, one weight per shape, always in [1, max_w].
var guess: Array = []
## The top of a weight's range for this puzzle: Gen.MAX_W by default, 12 on
## Insane. Comes from the generator's own output, so the guess never runs
## ahead of the range the secret was actually drawn from.
var max_w := Gen.MAX_W
## Per shape: the weight is fixed and its card takes no presses. The anchor
## from the start, plus anything a hint has revealed.
var locked: Array = []
## One entry per weight change, newest last. Undo pops one.
var history: Array[Dictionary] = []

## Takes a fresh puzzle from Gen.generate: the secret, its scales and the
## anchor, every unlocked shape starting at one, an empty history. The
## generator's own arrays are copied, so nothing here is shared with a board
## that mutates them.
func setup(out: Dictionary) -> void:
	secret = (out.secret as Array).duplicate()
	scales = []
	for sc in out.scales:
		scales.append({"left": (sc.left as Array).duplicate(), "right": (sc.right as Array).duplicate()})
	anchor = (out.anchor as Dictionary).duplicate()
	max_w = int(out.get("max_w", Gen.MAX_W))
	shapes = secret.size()
	guess = []
	locked = []
	for i in shapes:
		var anchored := i == int(anchor.shape)
		guess.append(int(anchor.value) if anchored else 1)
		locked.append(anchored)
	history = []

# --- moves ---

## Whether shape `i` can take a step of `delta` right now: an unlocked shape
## whose weight would stay inside [1, max_w]. The weight cards grey a button
## out by this, and a refused press is what makes a card shiver.
func can_step(i: int, delta: int) -> bool:
	if locked[i]:
		return false
	var next: int = int(guess[i]) + delta
	return next >= 1 and next <= max_w

## The move: one unit onto or off shape `i`'s weight. False when the shape is
## given or the range runs out, so the board can answer with a shiver and the
## sprout's reason -- the island's `_add` and `_remove` in one method, since
## the flat card's minus and plus are one gesture with two signs.
func step(i: int, delta: int) -> bool:
	if not can_step(i, delta):
		return false
	history.append({"shape": i, "from": int(guess[i])})
	guess[i] = int(guess[i]) + delta
	return true

## Reverts the last change and says which shape now shows what, as
## {"shape": i, "to": w}; {} with nothing to undo. No state in the history
## was ever solved, or the game would have ended there.
func undo() -> Dictionary:
	if history.is_empty():
		return {}
	var last: Dictionary = history.pop_back()
	var i := int(last.shape)
	guess[i] = int(last.from)
	return {"shape": i, "to": int(guess[i])}

## Every unlocked shape falls back to one; hints already spent stay spent and
## the weights they revealed stay locked, as on the island. Clears the
## history. Returns the shapes whose weight changed, which is what a board
## has to redraw -- a given, or one already at one, is not among them.
func reset() -> Array[int]:
	var changed: Array[int] = []
	for i in shapes:
		if locked[i] or int(guess[i]) == 1:
			continue
		guess[i] = 1
		changed.append(i)
	history = []
	return changed

# --- help ---

## The shape a hint would reveal: one the player currently has wrong, since
## revealing a weight already right would teach nothing; else any shape still
## unlocked. Ties go to the lowest index, so a hint is reproducible. -1 when
## every shape is locked or already correct.
func hint_shape() -> int:
	for i in shapes:
		if not locked[i] and int(guess[i]) != int(secret[i]):
			return i
	for i in shapes:
		if not locked[i]:
			return i
	return -1

## Reveals hint_shape()'s true weight and locks it, so the rest of the board
## has one more fixed point to reason from. That shape's own entries leave
## the history: an undo must never turn a locked weight back, and there is
## nothing honest to restore it to. Returns the shape revealed, or -1.
func apply_hint() -> int:
	var i := hint_shape()
	if i < 0:
		return -1
	locked[i] = true
	guess[i] = int(secret[i])
	var kept: Array[Dictionary] = []
	for h in history:
		if int(h.shape) != i:
			kept.append(h)
	history = kept
	return i

# --- reading the scales ---

func side_total(side: Array) -> int:
	var t := 0
	for s in side:
		t += int(guess[int(s)])
	return t

## What scale `i` reads under the current guess: its left total less its
## right, so a positive number means the left dish is the heavy one and dips.
## (The island's private `_diff` is the other way round; only the sign
## convention differs, and the flat board's is the mock's, which is the
## drawing these numbers have to match.)
func lean(i: int) -> int:
	var sc: Dictionary = scales[i]
	return side_total(sc.left) - side_total(sc.right)

func is_level(i: int) -> bool:
	return lean(i) == 0

## How many scales are still tipping.
func tipping() -> int:
	var n := 0
	for i in scales.size():
		if not is_level(i):
			n += 1
	return n

## Every beam level at once, which on this board is the same as every weight
## being right: the anchor plus `shapes - 1` independent scales pin down
## exactly one answer, which is what the generator proves before it ships a
## board. Asked of the guess rather than the beams so a board with no scales
## at all could never read as solved.
func is_solved() -> bool:
	return guess == secret
