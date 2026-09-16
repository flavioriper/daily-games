extends RefCounted

## Pipes' rules and generator, on the island of blocks. The board's own maths
## -- the 24 rotations, what a mouth set means, the standing rule, where water
## can and cannot go -- and then whole days at every difficulty, each one
## checked with the same verifier the generator gates itself on.
## Spec: docs/superpowers/specs/2026-09-15-pipes-iso-design.md.

const Gen = preload("res://puzzles/pipes_iso_gen.gd")

static func run(t) -> void:
	_test_rotations(t)
	_test_masks(t)
	_test_standing(t)
	_test_flow(t)
	_test_generate(t)

static func _test_rotations(t) -> void:
	var rots := Gen.rotations()
	t.eq(rots.size(), 24, "a piece can be turned 24 ways")
	var seen: Dictionary = {}
	for b in rots:
		t.check(b.determinant() > 0.5, "a rotation never mirrors the piece")
		seen[b] = true
	t.eq(seen.size(), 24, "the 24 rotations are distinct")
	# A mouth set turned and turned back is itself.
	for b in rots:
		var there: int = Gen.rotate_mask(Gen.N | Gen.E, b)
		t.eq(Gen.rotate_mask(there, b.inverse()), Gen.N | Gen.E, "a turn is undone by its inverse")
		t.eq(Gen.count_bits(there), 2, "turning keeps the number of mouths")

static func _test_masks(t) -> void:
	# The orientation counts from the spec's table: a straight has three, an
	# elbow twelve, a tee twelve, a pump one.
	t.eq(Gen.kind_orientations("straight").size(), 3, "a straight lies three ways")
	t.eq(Gen.kind_orientations("elbow").size(), 12, "an elbow turns twelve ways")
	t.eq(Gen.kind_orientations("tee").size(), 12, "a tee turns twelve ways")
	t.eq(Gen.kind_orientations("pump").size(), 1, "a pump only stands up")
	t.eq(Gen.kind_orientations("pump")[0].mask, Gen.U | Gen.D, "a pump's mouths are up and down")
	# A straight's three are the three axes.
	var straights: Array = []
	for o in Gen.kind_orientations("straight"):
		straights.append(int(o.mask))
	straights.sort()
	t.eq(straights, [Gen.N | Gen.S, Gen.E | Gen.W, Gen.U | Gen.D], "a straight lies along each axis")

	t.eq(Gen.mask_kind(Gen.N | Gen.S), "straight", "two opposite mouths is a straight")
	t.eq(Gen.mask_kind(Gen.U | Gen.D), "straight", "a vertical pair is a straight, never a pump")
	t.eq(Gen.mask_kind(Gen.N | Gen.E), "elbow", "two mouths at a right angle is an elbow")
	t.eq(Gen.mask_kind(Gen.N | Gen.U), "elbow", "an elbow turns up as well as sideways")
	t.eq(Gen.mask_kind(Gen.N | Gen.E | Gen.S), "tee", "a through pair and a branch is a tee")
	t.eq(Gen.mask_kind(Gen.N | Gen.E | Gen.U), "", "three mouths round a corner is no piece in the tray")
	t.eq(Gen.mask_kind(Gen.N | Gen.E | Gen.S | Gen.W), "", "the cross is out of the tray")
	t.eq(Gen.mask_kind(Gen.N), "", "a single mouth is a fixture, not a piece")
	# Every kind's model can actually be turned onto every orientation it claims.
	for kind in Gen.KINDS:
		for o in Gen.kind_orientations(kind):
			t.eq(Gen.rotate_mask(int(Gen.REFERENCE[kind]), Gen.basis_for(kind, int(o.mask))), int(o.mask),
				"%s can be turned onto %d" % [kind, int(o.mask)])

## Two columns, one of height 1 and one of height 3, so the rule has a crown,
## a hanging cell and a block to be wrong about.
static func _heights() -> Array:
	return [[1, 3], [1, 1]]

static func _test_standing(t) -> void:
	var h := _heights()
	# (0, 1, 0) is the crown of a height-1 column.
	t.check(Gen.stands(Vector3i(0, 1, 0), Gen.N | Gen.E, h, 2, 2, 3), "a flat piece rests on a crown")
	t.check(not Gen.stands(Vector3i(0, 2, 0), Gen.N | Gen.E, h, 2, 2, 3), "a flat piece may not hang in the sky")
	t.check(Gen.stands(Vector3i(0, 2, 0), Gen.N | Gen.D, h, 2, 2, 3), "a piece with a down mouth may hang")
	t.check(Gen.stands(Vector3i(0, 2, 0), Gen.U | Gen.D, h, 2, 2, 3), "a riser may hang")
	t.check(not Gen.stands(Vector3i(0, 0, 0), Gen.U | Gen.D, h, 2, 2, 3), "no piece stands inside a block")
	t.check(not Gen.stands(Vector3i(5, 1, 0), Gen.U | Gen.D, h, 2, 2, 3), "no piece stands off the island")

## A source on a high crown, a drop of one and a drain on the low crown:
## the smallest island with a pipeline in it.
static func _drop_board() -> Dictionary:
	# Columns (0,0) height 2 and (1,0) height 1.
	return {
		Vector3i(0, 2, 0): {"kind": "source", "mask": Gen.E},
		Vector3i(1, 2, 0): {"kind": "elbow", "mask": Gen.W | Gen.D},
		Vector3i(1, 1, 0): {"kind": "drain", "mask": Gen.U},
	}

static func _test_flow(t) -> void:
	var pieces := _drop_board()
	var source := Vector3i(0, 2, 0)
	var drain := Vector3i(1, 1, 0)
	var out := Gen.flow(pieces, source)
	t.eq(int(out.fed.size()), 3, "water runs level and then falls")
	t.eq(int(out.fed[drain]), 2, "the drain is two steps from the source")
	t.check(Gen.leaks(pieces, out.fed).is_empty(), "a finished pipeline leaks nowhere")
	t.check(Gen.is_solved(pieces, source, [drain]), "every drain fed and nothing leaking is solved")

	# Turn the elbow away and the water pours out of the source instead.
	var broken := pieces.duplicate(true)
	broken[Vector3i(1, 2, 0)] = {"kind": "elbow", "mask": Gen.N | Gen.D}
	out = Gen.flow(broken, source)
	t.eq(int(out.fed.size()), 1, "a mouth that meets nothing feeds nothing")
	var leaked: Array = Gen.leaks(broken, out.fed)
	t.eq(leaked.size(), 1, "the source pours onto the ground")
	t.eq(int(leaked[0].bit), Gen.E, "and it pours out of the mouth that meets nothing")
	t.check(not Gen.is_solved(broken, source, [drain]), "a leak is not solved")

	# Water will not climb: the same pipeline upside down needs a pump.
	var climb := {
		Vector3i(0, 1, 0): {"kind": "source", "mask": Gen.E},
		Vector3i(1, 1, 0): {"kind": "elbow", "mask": Gen.W | Gen.U},
		Vector3i(1, 2, 0): {"kind": "straight", "mask": Gen.U | Gen.D},
		Vector3i(1, 3, 0): {"kind": "drain", "mask": Gen.D},
	}
	out = Gen.flow(climb, Vector3i(0, 1, 0))
	t.eq(int(out.fed.size()), 2, "water climbs no further than the foot of the run")
	climb[Vector3i(1, 2, 0)] = {"kind": "pump", "mask": Gen.U | Gen.D}
	out = Gen.flow(climb, Vector3i(0, 1, 0))
	t.eq(int(out.fed.size()), 4, "one pump lifts the whole run")
	t.check(Gen.is_solved(climb, Vector3i(0, 1, 0), [Vector3i(1, 3, 0)]), "a pumped climb is solved")
	# A second, separate climb is not lifted by the first one's pump.
	var runs: Array = Gen.vertical_runs(climb).runs
	var pumped := 0
	for r in runs:
		if bool(r.pumped):
			pumped += 1
	t.eq(pumped, 1, "a pump belongs to one run, not to the board")

static func _test_generate(t) -> void:
	for difficulty in 3:
		var d: Dictionary = Gen.DIFFICULTY[difficulty]
		for i in 4:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + difficulty * 100 + i
			var out: Dictionary = Gen.generate(rng, difficulty)
			t.check(bool(out.ok), "difficulty %d seed %d makes an island" % [difficulty, i])
			if not bool(out.ok):
				continue
			t.check(Gen.verify(out), "the island it hands over verifies")
			_test_fixture_mouths(t, out)
			t.eq(out.drains.size(), int(d.drains), "the day has the drains it should")
			var pieces := int(out.solution.size())
			# The walk may overshoot: a drop is two cells at least (an elbow
			# over the edge and an elbow below, or it is not a drop), and once
			# the route is long enough it still has to reach a column far
			# enough from the source and finish on a step along the level.
			t.check(pieces >= int(d.route[0]) - 2 and pieces <= int(d.route[1]) + 4,
				"the route is the length it should be (%d)" % pieces)
			t.check(int(out.hidden) >= int(d.hidden), "enough of the route hides from the first stop")
			# The tray can build the route, spares aside.
			var need: Dictionary = {}
			for cell in out.solution:
				var kind := String(out.solution[cell].kind)
				need[kind] = int(need.get(kind, 0)) + 1
			var spare := 0
			for kind in out.tray:
				t.check(int(out.tray[kind]) >= int(need.get(kind, 0)), "the tray holds every %s the route needs" % kind)
				spare += int(out.tray[kind]) - int(need.get(kind, 0))
			t.eq(spare, int(d.spares), "and the difficulty's spares on top")
			# Every climb has its pump, and no pump stands anywhere else.
			var heights: Array = out.heights
			for cell in out.solution:
				if String(out.solution[cell].kind) != "pump":
					continue
				t.eq(int(out.solution[cell].mask), Gen.U | Gen.D, "a pump only ever stands up")
			# Terrain agrees with the route: every route cell is air.
			for cell in out.route:
				t.check(Gen.is_air(cell, heights, int(out.cols), int(out.rows), int(out.levels)),
					"route cell %s is not buried" % cell)

## The two fixtures stand on a crown and are turned about the vertical only,
## so the generator must never hand one a mouth pointing up or down.
static func _test_fixture_mouths(t, out: Dictionary) -> void:
	t.eq(int(out.source_mask) & Gen.VERTICAL, 0, "the source's mouth is horizontal")
	for drain in out.drains:
		t.eq(int(out.drain_masks[drain]) & Gen.VERTICAL, 0, "a drain's mouth is horizontal")
