extends RefCounted

## Shikaku's rules, with no scene under them: the clues, the plots the player
## has drawn, the owner map, the seams a fence stands on, and every move that
## can change them. The flat board (puzzles/shikaku2d.gd) draws this and
## nothing else, so what is on trial on the phone is the screen and not the
## game.
##
## It is `puzzles/shikaku3d.gd`'s logic, ported move for move. The island
## script still carries its own copy until the two screens are judged;
## whichever board survives, this is the one truth to keep.
## Spec: docs/superpowers/specs/2026-09-18-shikaku-flat-design.md, section 2.

const Gen = preload("res://puzzles/shikaku_gen.gd")

## The largest area a clue can carry, and the smallest rectangle worth
## drawing: a 1 or a 2 is forced on sight. The island's own numbers, so the
## two boards hand out the same puzzle.
const MAX_AREA := 9
## Insane's own area cap: an 8x10 field wants bigger plots than MAX_AREA
## leaves room for.
const MAX_AREA_INSANE := 12
const MIN_AREA := 3
const HINTS := 3
## Width, height and the generator's area cap, per difficulty.
# Insane's provisional band: Hard's own 7x9 frame with MAX_AREA_INSANE's
# bigger plots -- 8x10 (either area cap) missed the 194 ms gate (worst
# 235-431 ms), but the smaller field with the same bigger cap clears it
# (worst ~70 ms over 40 seeds on this Mac). Replaced by the bank in batch 2.
const SIZES := [[5, 6, 6], [6, 8, MAX_AREA], [7, 9, MAX_AREA], [7, 9, MAX_AREA_INSANE]]

var w: int = 6
var h: int = 8
var clues: Array = []            # [{pos: Vector2i, area: int}], the generator's
var solution: Array = []         # [Rect2i], the partition they came from
var rects: Array[Rect2i] = []    # the plots the player has drawn
var locked: Array[bool] = []     # in step with `rects`: a plot a hint pinned
## Plot index per cell, -1 where nothing is claimed. Rebuilt from `rects`.
var owner_map: PackedInt32Array = PackedInt32Array()
## One entry per move that can be taken back: the plot added (or null when
## the move only cleared one) and the plots it displaced.
var history: Array[Dictionary] = []

## Builds a board for `difficulty`, the island's ladder exactly.
func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	var step: Array = SIZES[clampi(difficulty, 0, SIZES.size() - 1)]
	w = step[0]
	h = step[1]
	var out: Dictionary = Gen.generate(rng, w, h, step[2], MIN_AREA)
	clues = out.clues
	solution = out.rects
	rects = []
	locked = []
	history = []
	reown()

# --- the partition ---

## Plot index at cell (r, c), -1 when nothing claims it. Anything off the
## field counts as unclaimed, so the field's edge closes a plot that reaches
## it without a special case being written for one.
func owner_at(r: int, c: int) -> int:
	if r < 0 or c < 0 or r >= h or c >= w:
		return -1
	return owner_map[r * w + c]

## Rebuilds the owner map from `rects`. The plots never overlap, so the last
## writer is the only writer.
func reown() -> void:
	owner_map = PackedInt32Array()
	owner_map.resize(w * h)
	owner_map.fill(-1)
	for i in rects.size():
		var rect: Rect2i = rects[i]
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				owner_map[y * w + x] = i

## The clues inside plot `i`.
func clues_in(i: int) -> Array:
	var out: Array = []
	var rect: Rect2i = rects[i]
	for c in clues:
		if rect.has_point(c.pos):
			out.append(c)
	return out

## A plot the board should point at: one holding two numbers or none. A plot
## holding one number of the wrong size is that number's own business.
func plot_blushes(i: int) -> bool:
	return clues_in(i).size() != 1

## Whether the plot around clue `i` satisfies it: exactly one number in the
## plot and the areas equal. False while the clue's cell is unclaimed.
func clue_ok(i: int) -> bool:
	var clue: Dictionary = clues[i]
	var who := owner_at(clue.pos.y, clue.pos.x)
	if who < 0:
		return false
	var rect: Rect2i = rects[who]
	return clues_in(who).size() == 1 and rect.size.x * rect.size.y == int(clue.area)

## The index of a clue inside plot `i`, or -1 when it holds none.
func clue_index_in(i: int) -> int:
	var rect: Rect2i = rects[i]
	for j in clues.size():
		if rect.has_point(clues[j].pos):
			return j
	return -1

## What a marker wears: 0 idle, 1 settled, 2 the wrong size, 3 lost (its
## plot holds two numbers or none).
func clue_state(i: int) -> int:
	var clue: Dictionary = clues[i]
	var who := owner_at(clue.pos.y, clue.pos.x)
	if who < 0:
		return 0
	if plot_blushes(who):
		return 3
	var rect: Rect2i = rects[who]
	return 1 if rect.size.x * rect.size.y == int(clue.area) else 2

## Cells no plot claims.
func bare_cells() -> int:
	var claimed := 0
	for r in rects:
		claimed += r.size.x * r.size.y
	return w * h - claimed

## Plots holding two numbers or none.
func blushing() -> int:
	var n := 0
	for i in rects.size():
		if plot_blushes(i):
			n += 1
	return n

## Checked against the rules, not against the stored answer.
func is_solved() -> bool:
	if clues.is_empty():
		return false
	var covered: Dictionary = {}
	for r in rects:
		var inside := 0
		for c in clues:
			if r.has_point(c.pos):
				inside += 1
				if int(c.area) != r.size.x * r.size.y:
					return false
		if inside != 1:
			return false
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
				if covered.has(Vector2i(x, y)):
					return false
				covered[Vector2i(x, y)] = true
	return covered.size() == w * h

func share_glyphs() -> String:
	return "▦ %dx%d · %d plots" % [w, h, rects.size()]

# --- the fence ---

## Whether a fence stands on one unit of seam. Vertical seams run down
## lattice line `line` (0 to w) and separate the cells either side of it in
## x; horizontal ones run across line `line` (0 to h) and separate in y.
## `index` is the segment along that line. A fence stands exactly where the
## two sides belong to different plots and at least one is claimed, which is
## Shikaku's rule as a line: two neighbouring plots are divided by one fence
## and never two.
func is_seam(vertical: bool, line: int, index: int) -> bool:
	var a: int
	var b: int
	if vertical:
		a = owner_at(index, line - 1)
		b = owner_at(index, line)
	else:
		a = owner_at(line - 1, index)
		b = owner_at(line, index)
	return a != b and (a >= 0 or b >= 0)

## Every maximal run of seam carrying a fence, as [vertical, line, start, length].
func fence_runs() -> Array:
	var runs: Array = []
	for pair in [[false, h, w], [true, w, h]]:
		var vertical: bool = pair[0]
		for line in range(pair[1] + 1):
			var start := -1
			for index in range(int(pair[2]) + 1):
				var on: bool = index < int(pair[2]) and is_seam(vertical, line, index)
				if on and start < 0:
					start = index
				elif not on and start >= 0:
					runs.append([vertical, line, start, index - start])
					start = -1
	return runs

## The lattice points where fences meet, turn or cross, and so need a post.
## A point two collinear segments pass straight through needs none: the run
## covering it is one unbroken rail.
func fence_posts() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(w + 1):
		for j in range(h + 1):
			var up := j > 0 and is_seam(true, i, j - 1)
			var down := j < h and is_seam(true, i, j)
			var left := i > 0 and is_seam(false, j, i - 1)
			var right := i < w and is_seam(false, j, i)
			var count := int(up) + int(down) + int(left) + int(right)
			if count < 2:
				continue
			if count == 2 and ((up and down) or (left and right)):
				continue
			out.append(Vector2i(i, j))
	return out

# --- moves ---

## Turns `rect` into a plot, and says what happened so the board can answer
## it: {"kind": "plot"|"clear"|"locked"|"none"} with "rect" on the first two
## and "clue" on a refusal. Drawing over existing plots replaces them, which
## is far more forgiving than refusing the drag; a single tap inside a plot
## clears it; a plot a hint pinned blocks both.
func commit(rect: Rect2i) -> Dictionary:
	if rect.size == Vector2i(1, 1):
		var who := owner_at(rect.position.y, rect.position.x)
		if who >= 0:
			if locked[who]:
				return {"kind": "locked", "clue": clue_index_in(who)}
			return take(who)
	var displaced: Array[Rect2i] = []
	var keep: Array[Rect2i] = []
	var keep_locked: Array[bool] = []
	for i in rects.size():
		if not rects[i].intersects(rect):
			keep.append(rects[i])
			keep_locked.append(locked[i])
			continue
		if locked[i]:
			# Hitting a pinned plot: nothing moves, and its number says why.
			return {"kind": "locked", "clue": clue_index_in(i)}
		displaced.append(rects[i])
	rects = keep
	locked = keep_locked
	rects.append(rect)
	locked.append(false)
	history.append({"added": rect, "displaced": displaced})
	reown()
	return {"kind": "plot", "rect": rect}

## Clears plot `i`, the single tap inside it.
func take(i: int) -> Dictionary:
	var gone: Array[Rect2i] = [rects[i]]
	rects.remove_at(i)
	locked.remove_at(i)
	history.append({"added": null, "displaced": gone})
	reown()
	return {"kind": "clear", "rect": gone[0]}

## Takes back the last plot drawn or cleared, putting back whatever it
## displaced. The plots it restores come back unpinned, because a hint
## clears the history rather than leaving one in it.
func undo() -> Array[Rect2i]:
	var back: Array[Rect2i] = []
	if history.is_empty():
		return back
	var last: Dictionary = history.pop_back()
	if last.added != null:
		var added: Rect2i = last.added
		for i in rects.size():
			if rects[i] == added:
				rects.remove_at(i)
				locked.remove_at(i)
				break
	for rect in last.displaced:
		rects.append(rect)
		locked.append(false)
		back.append(rect)
	reown()
	return back

## Every plot goes. The hints a player spent are not refunded, only unpinned.
func reset() -> void:
	rects = []
	locked = []
	history = []
	reown()

## Draws one plot from the answer and pins it: the first solution rectangle
## the board does not already have. Returns it, or a zero rect when there is
## none left to give.
func apply_hint() -> Rect2i:
	var target := Rect2i(0, 0, 0, 0)
	for rect in solution:
		if not rects.has(rect):
			target = rect
			break
	if target.size == Vector2i(0, 0):
		return target
	var keep: Array[Rect2i] = []
	var keep_locked: Array[bool] = []
	for i in rects.size():
		if rects[i].intersects(target):
			continue
		keep.append(rects[i])
		keep_locked.append(locked[i])
	rects = keep
	locked = keep_locked
	rects.append(target)
	locked.append(true)
	# A hint may displace a pinned plot's neighbours, so what came before it
	# no longer describes a board that can be gone back to.
	history = []
	reown()
	return target

## Every number the board does not yet satisfy. Check points at these.
func wrong_clues() -> Array[int]:
	var out: Array[int] = []
	for i in clues.size():
		if not clue_ok(i):
			out.append(i)
	return out
