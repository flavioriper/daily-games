extends RefCounted

## Quilt's generator (puzzles/quilt_gen.gd): what a grown quilt promises, and
## the uniqueness its patches are proved to have -- cross-checked against a
## counter written here rather than asserted from the generator's own. Then
## its rules (puzzles/quilt_state.gd): the two refusals, one gesture one
## undo, the hint that lifts what is in its way, reset, and the fact that a
## covered quilt is the only win condition there is.

const Gen = preload("res://puzzles/quilt_gen.gd")
const State = preload("res://puzzles/quilt_state.gd")

static func run(t) -> void:
	_test_bands(t)
	_test_grown_board_is_legal(t)
	_test_repeatable(t)
	_test_every_band_builds(t)
	_test_unique_cross_checked(t)
	_test_alike_patches_are_one_choice(t)
	_test_cap_and_ambiguity(t)
	_test_fits_refusals(t)
	_test_one_gesture_one_undo(t)
	_test_place_lift_undo(t)
	_test_hint_displaces_and_undo_restores(t)
	_test_hint_on_a_built_board(t)
	_test_reset(t)
	_test_solved_only_when_covered(t)
	_test_answer_solves_every_band(t)
	_test_share_glyphs(t)

static func _built(seed_value: int, difficulty: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Gen.generate(rng, difficulty)

static func _state(seed_value: int, difficulty: int) -> State:
	var st := State.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	st.setup(rng, difficulty)
	return st

# --------------------------------------------------------------- the bands

static func _test_bands(t) -> void:
	t.eq(int(Gen.band(0).box), 5, "band 0 grows in a 5x5")
	t.eq(int(Gen.band(1).box), 6, "band 1 grows in a 6x6")
	t.eq(int(Gen.band(2).box), 7, "band 2 grows in a 7x7")
	t.eq(int(Gen.band(0).patches), 5, "band 0 cuts 5 patches")
	t.eq(int(Gen.band(1).patches), 6, "band 1 cuts 6 patches")
	t.eq(int(Gen.band(2).patches), 8, "band 2 cuts 8 patches")
	t.eq(Gen.band(-3).box, Gen.band(0).box, "a difficulty below the ladder clamps to easy")
	t.eq(Gen.band(9).box, Gen.band(2).box, "a difficulty above it clamps to hard")

# ------------------------------------------------------- what a grow promises

## Everything a grown quilt promises, over enough seeds that a rare shape
## cannot hide: the region is connected and hole-free, it fills at least one
## dimension of its band's box, every patch is normalised and inside the
## rack's bay, and the answer covers the region exactly once.
static func _test_grown_board_is_legal(t) -> void:
	for difficulty in 3:
		var box: int = int(Gen.band(difficulty).box)
		var patches: int = int(Gen.band(difficulty).patches)
		for s in range(1, 21):
			var g := _built(s, difficulty)
			var tag := "band %d seed %d" % [difficulty, s]
			t.check(int(g.cols) > 0 and int(g.rows) > 0, "%s grew a quilt" % tag)
			t.eq(g.shapes.size(), patches, "%s cuts its band's patches" % tag)
			t.eq(g.answer.size(), patches, "%s answers for every patch" % tag)
			t.check(int(g.cols) <= box and int(g.rows) <= box,
				"%s stays inside its box" % tag)
			t.check(int(g.cols) == box or int(g.rows) == box,
				"%s fills its box in at least one dimension" % tag)
			t.check(bool(g.unique), "%s comes back proved unique" % tag)
			t.check(_connected(int(g.cols), int(g.rows), g.region), "%s is one region" % tag)
			t.check(not _has_hole(int(g.cols), int(g.rows), g.region), "%s encloses no hole" % tag)
			for p in g.shapes.size():
				var offs: Array = g.shapes[p]
				var lox := 999
				var loy := 999
				var hix := -999
				var hiy := -999
				for off in offs:
					lox = mini(lox, int(off.x))
					loy = mini(loy, int(off.y))
					hix = maxi(hix, int(off.x))
					hiy = maxi(hiy, int(off.y))
				t.eq(lox, 0, "%s patch %d is normalised in x" % [tag, p])
				t.eq(loy, 0, "%s patch %d is normalised in y" % [tag, p])
				t.check(hix < Gen.MAX_SPAN, "%s patch %d fits the bay across" % [tag, p])
				t.check(hiy < Gen.MAX_SPAN, "%s patch %d fits the bay down" % [tag, p])
				t.check(_is_connected_shape(offs), "%s patch %d is one polyomino" % [tag, p])
			# The answer covers every quilt cell exactly once and nothing else.
			var cover := PackedInt32Array()
			cover.resize(int(g.cols) * int(g.rows))
			cover.fill(-1)
			var laid := 0
			for p in g.shapes.size():
				var origin := int(g.answer[p])
				var oc := origin % int(g.cols)
				var orr := origin / int(g.cols)
				for off in g.shapes[p]:
					var c: int = oc + int(off.x)
					var r: int = orr + int(off.y)
					var inside: bool = c >= 0 and r >= 0 and c < int(g.cols) and r < int(g.rows)
					t.check(inside, "%s the answer keeps patch %d on the grid" % [tag, p])
					if not inside:
						continue
					var idx := r * int(g.cols) + c
					t.eq(int(g.region[idx]), 1, "%s the answer keeps patch %d on the quilt" % [tag, p])
					t.eq(int(cover[idx]), -1, "%s no two patches overlap at %d" % [tag, idx])
					cover[idx] = p
					laid += 1
			var cells := 0
			for idx in g.region.size():
				if int(g.region[idx]) == 1:
					cells += 1
			t.eq(laid, cells, "%s the patches' cells are the quilt's cells" % tag)

## A seed is a day: the same seed hands out the same quilt on every phone.
static func _test_repeatable(t) -> void:
	for difficulty in 3:
		for s in [7, 99, 1234]:
			var a := _built(s, difficulty)
			var b := _built(s, difficulty)
			var tag := "band %d seed %d" % [difficulty, s]
			t.eq(a.cols, b.cols, "%s grows the same width twice" % tag)
			t.eq(a.rows, b.rows, "%s grows the same height twice" % tag)
			t.eq(a.region, b.region, "%s grows the same outline twice" % tag)
			t.eq(a.shapes, b.shapes, "%s cuts the same patches twice" % tag)
			t.eq(a.answer, b.answer, "%s lays them the same way twice" % tag)
			t.eq(a.nodes, b.nodes, "%s costs the same proof twice" % tag)

## Every band builds over many seeds, and the grading actually bites: no easy
## board is above the node window and no hard board is below it.
static func _test_every_band_builds(t) -> void:
	for difficulty in 3:
		var missed := 0
		var ungraded := 0
		var unproved := 0
		for s in range(1, 81):
			var g := _built(s, difficulty)
			if int(g.cols) <= 0 or g.shapes.is_empty():
				missed += 1
				continue
			if not bool(g.unique):
				unproved += 1
			if difficulty == 0 and int(g.nodes) > Gen.EASY_NODES:
				ungraded += 1
			if difficulty == 2 and int(g.nodes) < Gen.HARD_NODES:
				ungraded += 1
		t.eq(missed, 0, "band %d builds a quilt for all 80 seeds" % difficulty)
		t.eq(unproved, 0, "band %d proves all 80 unique" % difficulty)
		t.eq(ungraded, 0, "band %d keeps all 80 inside its node window" % difficulty)

# ------------------------------------------------------------ the proof itself

## The generator says these boards have exactly one tiling. That is worth
## nothing if only the generator's own counter says so, so this counts again
## with a different search: one that branches over *patches* rather than over
## distinct shapes, and so counts every labelled tiling. A board with exactly
## one tiling has exactly `∏ (copies of a shape)!` labelled ones -- the ways
## the alike patches can trade places -- so the two counts agreeing is also a
## direct check of the grouping rule the generator's search rests on.
static func _test_unique_cross_checked(t) -> void:
	for difficulty in 3:
		for s in range(1, 13):
			var g := _built(s, difficulty)
			var tag := "band %d seed %d" % [difficulty, s]
			var proof: Dictionary = Gen.count_tilings(int(g.cols), int(g.rows), g.region,
				g.shapes, 2)
			t.eq(int(proof.count), 1, "%s has exactly one tiling" % tag)
			var want := _swaps(g.shapes)
			var got := _labelled(int(g.cols), int(g.rows), g.region, g.shapes, want * 4)
			t.eq(got, want, "%s: the brute force finds the same one tiling" % tag)
			# And the tiling the proof found is a real one.
			t.eq(proof.first.size(), g.shapes.size(), "%s names a patch per origin" % tag)
			t.check(_tiles_exactly(int(g.cols), int(g.rows), g.region, g.shapes, proof.first),
				"%s: the tiling the proof found covers the quilt" % tag)

## The case the grouping exists for, built by hand so it cannot drift: a 4x2
## quilt and two identical 2x2 patches. There is one quilt to be made, and
## two ways to label it. The proof must say one.
static func _test_alike_patches_are_one_choice(t) -> void:
	var region := PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1])
	var square: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var shapes: Array = [square, square]
	var proof: Dictionary = Gen.count_tilings(4, 2, region, shapes, 5)
	t.eq(int(proof.count), 1, "two alike patches on a 4x2 make one quilt, not two")
	t.eq(_labelled(4, 2, region, shapes, 20), 2, "and two labelled ones, which is the thing grouped away")
	t.check(int(proof.nodes) > 0, "the proof reports what it cost")

## A quilt that really does have more than one answer is counted as such, and
## `cap` stops the count where it is asked to. A 4x2 with one 2x2 patch and
## two vertical dominoes can be made three ways -- the square at the left, in
## the middle or at the right.
static func _test_cap_and_ambiguity(t) -> void:
	var region := PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1])
	var square: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var domino: Array = [Vector2i(0, 0), Vector2i(0, 1)]
	var shapes: Array = [square, domino, domino]
	t.eq(int(Gen.count_tilings(4, 2, region, shapes, 10).count), 3, "three quilts, counted")
	t.eq(int(Gen.count_tilings(4, 2, region, shapes, 2).count), 2, "a cap of two stops at two")
	t.eq(_labelled(4, 2, region, shapes, 40), 6, "six labelled ones, two per quilt")
	# A region no set of patches can cover comes back zero rather than wrong.
	var holed := PackedByteArray([1, 1, 1, 1, 1, 1, 1, 0])
	t.eq(int(Gen.count_tilings(4, 2, holed, shapes, 10).count), 0, "a quilt that cannot be made counts zero")

# --------------------------------------------------- the rules, scene-free

## A 4x2 quilt and two 2x2 patches, built by hand: the smallest board on
## which every refusal, the hint's displacement and the win are exact rather
## than whatever a seed happened to grow.
static func _hand() -> State:
	var st := State.new()
	st.cols = 4
	st.rows = 2
	st.region = PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1])
	var square: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	st.shapes = [square, square]
	st.answer = PackedInt32Array([0, 2])
	st.ok = true
	st.quilt_cells = 8
	st.at = PackedInt32Array([-1, -1])
	st.locked = PackedByteArray([0, 0])
	st.history = []
	st.hints_used = 0
	st.recompute()
	return st

## The two refusals of the spec's section 5, and the one thing that is not
## refused: a sewn patch never collides with itself.
static func _test_fits_refusals(t) -> void:
	var st := _hand()
	t.eq(st.fits(0, 0), State.OK, "a patch that lies on the quilt fits")
	t.eq(st.fits(0, 3), State.OFF, "a patch hanging off the right edge is OFF")
	t.eq(st.fits(0, 4), State.OFF, "a patch hanging off the bottom edge is OFF")
	t.eq(st.fits(0, -1), State.OFF, "an origin off the grid is OFF")
	t.eq(st.place(0, 0), State.OK, "the first patch goes on")
	t.eq(st.fits(1, 1), State.OVER, "a patch landing on a sewn one is OVER")
	t.eq(st.place(1, 1), State.OVER, "and the drop is refused")
	t.eq(int(st.at[1]), -1, "a refused drop leaves the patch where it was")
	t.eq(st.fits(0, 0), State.OK, "a sewn patch does not collide with itself")
	t.eq(st.fits(0, 1), State.OK, "nor with itself one cell along")
	# OFF is decided across every cell before OVER is looked at.
	t.eq(st.fits(1, 3), State.OFF, "half off the quilt and half on a patch is OFF")
	# A hole in the quilt is off the quilt.
	var holed := _hand()
	holed.region[7] = 0
	holed.quilt_cells = 7
	holed.recompute()
	t.eq(holed.fits(1, 2), State.OFF, "a cell that is not quilt is OFF")

## The invariant the take/drop pair exists for: one gesture is one undo, and
## a gesture that changed nothing is no undo at all.
static func _test_one_gesture_one_undo(t) -> void:
	var st := _hand()
	t.eq(st.place(0, 0), State.OK, "a patch goes on")
	t.eq(st.history.size(), 1, "and that is one entry")
	# Picked up and put back exactly where it was: nothing happened.
	var from := int(st.at[0])
	t.eq(st.take(0), State.OK, "the press takes it off")
	t.eq(int(st.at[0]), -1, "and it is off the quilt while it is held")
	t.eq(st.history.size(), 1, "the press alone pushes nothing")
	t.eq(st.drop(0, from, from), State.OK, "the release puts it back")
	t.eq(st.history.size(), 1, "and back where it was is not a move")
	t.eq(int(st.at[0]), 0, "it is sitting where it started")
	# Picked up and moved: exactly one entry for the whole drag.
	t.eq(st.take(0), State.OK, "taken again")
	t.eq(st.drop(0, 2, 0), State.OK, "and dropped somewhere else")
	t.eq(st.history.size(), 2, "a drag that moved it is one entry")
	t.eq(int(st.at[0]), 2, "and it moved")
	# Dragged out of the rack and back to the rack: nothing happened.
	var rack := _hand()
	t.eq(rack.take(0), State.OK, "taking a patch out of the rack is free")
	t.eq(rack.drop(0, -1, -1), State.OK, "and dropping it back in changes nothing")
	t.eq(rack.history.size(), 0, "rack to rack is no move at all")
	# A refused drop pushes nothing and moves nothing.
	var bad := _hand()
	bad.place(0, 0)
	bad.take(1)
	t.eq(bad.drop(1, 1, -1), State.OVER, "a drop onto a sewn patch is refused")
	t.eq(bad.history.size(), 1, "a refused drop is not an entry")
	t.eq(int(bad.at[1]), -1, "and leaves the patch where it was")

static func _test_place_lift_undo(t) -> void:
	var st := _hand()
	t.eq(st.place(0, 0), State.OK, "patch 0 goes on at the left")
	t.eq(st.place(1, 2), State.OK, "patch 1 goes on at the right")
	t.eq(st.covered(), 8, "the quilt is covered")
	t.eq(st.patch_at_cell(0, 0), 0, "the left cells belong to patch 0")
	t.eq(st.patch_at_cell(3, 1), 1, "the right cells belong to patch 1")
	t.eq(st.patch_at_cell(9, 9), -1, "a cell off the grid belongs to nobody")
	t.eq(st.lift(1), State.OK, "patch 1 comes off")
	t.eq(int(st.at[1]), -1, "and goes home to the rack")
	t.eq(st.lift(1), State.OK, "lifting it again is nothing to do")
	t.eq(st.history.size(), 3, "and pushes nothing")
	var back: Dictionary = st.undo()
	t.eq(String(back.kind), "lift", "undo names the gesture it took back")
	t.eq(int(st.at[1]), 2, "undo puts the lifted patch back")
	t.eq(back.moved.size(), 1, "and reports one patch moved")
	t.eq(int(back.moved[0].patch), 1, "the one that moved")
	t.eq(int(back.moved[0].to), 2, "and where it ended up")
	st.undo()
	st.undo()
	t.eq(int(st.at[0]), -1, "undone to the start, patch 0 is in the rack")
	t.eq(int(st.at[1]), -1, "and so is patch 1")
	t.eq(st.undo(), {}, "undo on an empty history reports nothing")

## The hint takes the patch with the fewest homes left, sends what is in its
## way back to the rack, and pins itself. The hand-built board makes all
## three exact: with patch 1 sitting across the middle, patch 0 has *no*
## legal home at all and patch 1 has three, so the hint must choose patch 0,
## and patch 1 must be the one it displaces.
static func _test_hint_displaces_and_undo_restores(t) -> void:
	var st := _hand()
	t.eq(st.place(1, 1), State.OK, "patch 1 is laid across the middle")
	t.eq(st.legal_origins(0).size(), 0, "patch 0 has nowhere to go")
	t.eq(st.legal_origins(1).size(), 3, "patch 1 could go three places")
	var h: Dictionary = st.hint()
	t.eq(int(h.patch), 0, "the hint takes the patch with nowhere to go")
	t.eq(int(h.origin), 0, "and sews it where the answer has it")
	t.eq(h.displaced, [1], "sending the patch in its way home")
	t.eq(int(st.at[0]), 0, "the hinted patch is sewn on")
	t.eq(int(st.at[1]), -1, "and the displaced one is in the rack")
	t.eq(int(st.locked[0]), 1, "the hinted patch is pinned")
	t.eq(st.hints_left(), State.HINTS - 1, "and the hint is spent")
	t.eq(st.lift(0), State.PINNED, "a pinned patch will not come off")
	t.eq(st.place(0, 2), State.PINNED, "nor move")
	t.eq(st.take(0), State.PINNED, "nor be picked up")
	t.eq(int(st.at[0]), 0, "and a refused lift leaves it exactly where it was")
	t.eq(st.history.size(), 2, "the whole hint is one entry")
	var back: Dictionary = st.undo()
	t.eq(String(back.kind), "hint", "undo names the hint")
	t.eq(back.moved.size(), 2, "and reports both patches")
	t.eq(int(st.at[0]), -1, "undo takes the hinted patch back off")
	t.eq(int(st.at[1]), 1, "and brings the displaced one home to where it was")
	t.eq(int(st.locked[0]), 0, "the pin goes with it")
	t.eq(st.hints_left(), State.HINTS - 1, "but the hint stays spent")

## The same on a real board, over a few seeds: a hint always sews a patch
## where the answer has it, and a board hinted to the end is solved.
static func _test_hint_on_a_built_board(t) -> void:
	for s in [3, 41, 500]:
		var st := _state(s, 0)
		var h: Dictionary = st.hint()
		t.check(not h.is_empty(), "seed %d: a hint on an empty quilt sews something" % s)
		t.eq(int(st.at[int(h.patch)]), int(st.answer[int(h.patch)]),
			"seed %d: the hint sews the answer's patch" % s)
		t.eq(h.displaced, [], "seed %d: an empty quilt displaces nothing" % s)
		t.eq(st.hints_left(), State.HINTS - 1, "seed %d: one hint spent" % s)
		# Spend the rest, then finish by hand; a hinted board still solves.
		while st.hints_left() > 0:
			st.hint()
		for p in st.shapes.size():
			if int(st.at[p]) == int(st.answer[p]):
				continue
			t.eq(st.place(p, int(st.answer[p])), State.OK,
				"seed %d: patch %d still goes where the answer has it" % [s, p])
		t.check(st.is_solved(), "seed %d: a part-hinted quilt still solves" % s)
	# Nothing left to sew, nothing to hand back.
	var done := _hand()
	done.place(0, 0)
	done.place(1, 2)
	t.eq(done.hint(), {}, "a finished quilt has no hint to give")

static func _test_reset(t) -> void:
	var st := _hand()
	st.place(0, 0)
	st.place(1, 2)
	t.eq(st.reset(), [0, 1], "reset sends both patches home")
	t.eq(st.covered(), 0, "and the quilt is bare")
	t.eq(st.history.size(), 0, "reset clears the history rather than joining it")
	t.eq(st.undo(), {}, "so it cannot be undone")
	# A hint's patch stays through a reset, the way Queens' hinted queens do.
	var pinned := _hand()
	pinned.place(1, 1)
	pinned.hint()
	t.eq(pinned.reset(), [], "reset leaves a pinned patch alone")
	t.eq(int(pinned.at[0]), 0, "the hinted patch is still sewn on")

## The win is the covered quilt and nothing else -- not a count of patches,
## not the stored answer.
static func _test_solved_only_when_covered(t) -> void:
	var st := _hand()
	t.check(not st.is_solved(), "a bare quilt is not solved")
	st.place(0, 0)
	t.check(not st.is_solved(), "half a quilt is not solved")
	t.eq(st.covered(), 4, "and four of its eight cells are covered")
	st.place(1, 2)
	t.check(st.is_solved(), "a covered quilt is solved")
	st.lift(1)
	t.check(not st.is_solved(), "and stops being solved when a patch comes off")
	# The patches laid the other way round cover it too, and that also wins:
	# the answer is not the measure.
	var other := _hand()
	other.place(1, 0)
	other.place(0, 2)
	t.check(other.is_solved(), "the patches swapped still cover the quilt, and still win")
	t.check(int(other.at[0]) != int(other.answer[0]), "though neither is where the answer has it")

## The answer, played through `place()`, solves every band -- which is the
## one end-to-end statement that ties the generator to the rules.
static func _test_answer_solves_every_band(t) -> void:
	for difficulty in 3:
		for s in range(1, 9):
			var st := _state(s, difficulty)
			var tag := "band %d seed %d" % [difficulty, s]
			t.check(not st.is_solved(), "%s does not open solved" % tag)
			var refused := 0
			for p in st.shapes.size():
				if st.place(p, int(st.answer[p])) != State.OK:
					refused += 1
			t.eq(refused, 0, "%s: every patch of the answer goes on" % tag)
			t.check(st.is_solved(), "%s: the answer solves the quilt" % tag)
			t.eq(st.covered(), st.quilt_cells, "%s: and covers every cell of it" % tag)

static func _test_share_glyphs(t) -> void:
	var st := _hand()
	st.place(0, 0)
	st.place(1, 2)
	t.eq(st.share_glyphs(), "%s%s%s%s\n%s%s%s%s\n" % [
		State.SQUARES[0], State.SQUARES[0], State.SQUARES[1], State.SQUARES[1],
		State.SQUARES[0], State.SQUARES[0], State.SQUARES[1], State.SQUARES[1]],
		"the share is a row a line, a colour a patch")
	var bare := _hand()
	bare.region[7] = 0
	bare.quilt_cells = 7
	bare.recompute()
	t.check(bare.share_glyphs().contains(State.GROUND), "what is not quilt is ground")
	# A real board's share is one line a row, and every line the same width.
	var real := _state(12, 1)
	var lines: PackedStringArray = real.share_glyphs().strip_edges().split("\n")
	t.eq(lines.size(), real.rows, "a real quilt shares one line a row")

# ------------------------------------------------------------------ helpers

## Every quilt cell reachable from the first one, orthogonally.
static func _connected(cols: int, rows: int, region: PackedByteArray) -> bool:
	var start := -1
	var total := 0
	for idx in region.size():
		if region[idx] == 1:
			total += 1
			if start < 0:
				start = idx
	if start < 0:
		return false
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	seen[start] = 1
	var reached := 1
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		for q in _around(idx, cols, rows):
			if region[q] != 1 or seen[q] == 1:
				continue
			seen[q] = 1
			reached += 1
			stack.append(q)
	return reached == total

## An empty cell with no orthogonal way off the grid.
static func _has_hole(cols: int, rows: int, region: PackedByteArray) -> bool:
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	var stack: Array[int] = []
	for idx in cols * rows:
		if region[idx] == 1:
			continue
		var c := idx % cols
		var r := idx / cols
		if c == 0 or r == 0 or c == cols - 1 or r == rows - 1:
			seen[idx] = 1
			stack.append(idx)
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		for q in _around(idx, cols, rows):
			if region[q] == 1 or seen[q] == 1:
				continue
			seen[q] = 1
			stack.append(q)
	for idx in cols * rows:
		if region[idx] == 0 and seen[idx] == 0:
			return true
	return false

static func _around(idx: int, cols: int, rows: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c := idx % cols
	var r := idx / cols
	if c > 0:
		out.append(idx - 1)
	if c < cols - 1:
		out.append(idx + 1)
	if r > 0:
		out.append(idx - cols)
	if r < rows - 1:
		out.append(idx + cols)
	return out

## A shape's own cells, orthogonally connected.
static func _is_connected_shape(offs: Array) -> bool:
	if offs.is_empty():
		return false
	var at := {}
	for off in offs:
		at[Vector2i(int(off.x), int(off.y))] = true
	var seen := {offs[0]: true}
	var stack: Array = [offs[0]]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if at.has(q) and not seen.has(q):
				seen[q] = true
				stack.append(q)
	return seen.size() == offs.size()

## How many ways alike patches can trade places: the product of the
## factorials of the multiplicities of the shapes.
static func _swaps(shapes: Array) -> int:
	var counts := {}
	for offs in shapes:
		var key := ""
		for off in offs:
			key += "%d,%d;" % [int(off.x), int(off.y)]
		counts[key] = int(counts.get(key, 0)) + 1
	var out := 1
	for key in counts:
		for i in range(2, int(counts[key]) + 1):
			out *= i
	return out

## The independent counter: every *labelled* tiling, branching over patches
## rather than over distinct shapes, so it knows nothing of the generator's
## grouping. Counted up to `cap`.
static func _labelled(cols: int, rows: int, region: PackedByteArray, shapes: Array,
		cap: int) -> int:
	var full := 0
	for idx in region.size():
		if region[idx] == 1:
			full |= 1 << idx
	# Per patch, every placement that lies on the quilt, as a mask.
	var places: Array = []
	for offs in shapes:
		var row: Array = []
		for origin in cols * rows:
			var oc := origin % cols
			var orr := origin / cols
			var mask := 0
			var fits := true
			for off in offs:
				var c: int = oc + int(off.x)
				var r: int = orr + int(off.y)
				if c < 0 or r < 0 or c >= cols or r >= rows or region[r * cols + c] != 1:
					fits = false
					break
				mask |= 1 << (r * cols + c)
			if fits:
				row.append([mask, origin])
		places.append(row)
	var state := {"count": 0}
	var used: Array = []
	used.resize(shapes.size())
	used.fill(false)
	_labelled_step(places, full, 0, used, cap, state)
	return int(state.count)

static func _labelled_step(places: Array, full: int, covered: int, used: Array,
		cap: int, state: Dictionary) -> void:
	if int(state.count) >= cap:
		return
	if covered == full:
		state.count = int(state.count) + 1
		return
	# The lowest uncovered cell has to be covered by some patch.
	var cell := 0
	while (full >> cell) & 1 == 0 or (covered >> cell) & 1 == 1:
		cell += 1
	for p in places.size():
		if bool(used[p]):
			continue
		for pair in places[p]:
			var mask: int = int(pair[0])
			if (mask >> cell) & 1 == 0 or covered & mask != 0:
				continue
			used[p] = true
			_labelled_step(places, full, covered | mask, used, cap, state)
			used[p] = false
			if int(state.count) >= cap:
				return

## Whether `origins` (one per patch) covers every quilt cell exactly once.
static func _tiles_exactly(cols: int, rows: int, region: PackedByteArray, shapes: Array,
		origins: PackedInt32Array) -> bool:
	if origins.size() != shapes.size():
		return false
	var cover := PackedByteArray()
	cover.resize(cols * rows)
	for p in shapes.size():
		var origin := int(origins[p])
		if origin < 0:
			return false
		var oc := origin % cols
		var orr := origin / cols
		for off in shapes[p]:
			var c: int = oc + int(off.x)
			var r: int = orr + int(off.y)
			if c < 0 or r < 0 or c >= cols or r >= rows:
				return false
			var idx := r * cols + c
			if region[idx] != 1 or cover[idx] == 1:
				return false
			cover[idx] = 1
	for idx in cols * rows:
		if region[idx] != cover[idx]:
			return false
	return true
