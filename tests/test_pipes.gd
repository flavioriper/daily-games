extends RefCounted

const Gen = preload("res://puzzles/pipes_gen.gd")

static func run(t) -> void:
	# Rotation is a bit rotation; four steps is the identity.
	t.eq(Gen.rotate_mask(Gen.UP, 1), Gen.RIGHT, "up rotates to right")
	t.eq(Gen.rotate_mask(Gen.LEFT, 1), Gen.UP, "left wraps round to up")
	t.eq(Gen.rotate_mask(0b1011, 4), 0b1011, "four rotations is identity")
	t.eq(Gen.rotate_mask(Gen.UP | Gen.DOWN, 2), Gen.UP | Gen.DOWN, "straight pipe is 180-symmetric")

	for size in [[4, 4], [5, 7]]:
		for i in range(6):
			var rng := RandomNumberGenerator.new()
			rng.seed = 300 + i
			var out: Dictionary = Gen.generate(rng, size[0], size[1])
			var w: int = out.w
			var h: int = out.h

			# Zero rotation everywhere is the built solution, so it must verify.
			var zero: Array = []
			for y in h:
				var row: Array = []
				for x in w:
					row.append(0)
				zero.append(row)
			t.check(Gen.is_solved(out.mask, zero, w, h),
				"%dx%d seed=%d unrotated board is solved" % [w, h, i])

			# The tree must reach every cell -- no isolated pieces.
			var orphan := false
			for y in h:
				for x in w:
					if out.mask[y][x] == 0:
						orphan = true
			t.check(not orphan, "%dx%d seed=%d every cell is connected" % [w, h, i])

			# A spanning tree over w*h cells has exactly w*h-1 edges.
			var ends := 0
			for y in h:
				for x in w:
					for bit in [Gen.UP, Gen.RIGHT, Gen.DOWN, Gen.LEFT]:
						if out.mask[y][x] & bit != 0:
							ends += 1
			t.eq(ends / 2, w * h - 1, "%dx%d seed=%d edge count matches a spanning tree" % [w, h, i])
