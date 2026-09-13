extends RefCounted

## Card flip for a board cell: the pivot turns edge-on, the face swaps at the
## midpoint, then it turns back to flat showing the new face. Driven here with
## Tween.custom_step so it runs headless without frames.

const Flip = preload("res://core/flip.gd")

static func run(t) -> void:
	_test_flip(t)

static func _test_flip(t) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var pivot := Node3D.new()
	var start := Vector3(1.0, 0.125, -2.0)
	pivot.position = start
	var calls := [0]
	var tw: Tween = Flip.build(tree.create_tween(), pivot, func(): calls[0] += 1, 0.4)
	t.check(tw != null and tw.is_running(), "build returns a running tween")
	t.check(is_zero_approx(pivot.rotation.x) and calls[0] == 0, "nothing moves before the first step")

	tw.custom_step(0.1)
	t.check(pivot.rotation.x > 0.0 and pivot.rotation.x < PI * 0.5, "first half turns the pivot toward edge-on (%.3f)" % pivot.rotation.x)
	t.check(calls[0] == 0, "face is untouched before the midpoint")
	t.check(pivot.position.y > start.y + 0.02, "the piece lifts while it turns (y=%.3f)" % pivot.position.y)

	tw.custom_step(0.15)
	t.check(calls[0] == 1, "face swaps exactly once at the midpoint (calls=%d)" % calls[0])
	t.check(pivot.rotation.x < 0.0 and pivot.rotation.x > -PI * 0.5, "second half comes back from the other side (%.3f)" % pivot.rotation.x)

	tw.custom_step(1.0)
	t.check(is_zero_approx(pivot.rotation.x), "flip ends flat (%.3f)" % pivot.rotation.x)
	t.check(pivot.position.is_equal_approx(start), "flip ends where it started (%s)" % pivot.position)
	t.check(not tw.is_running(), "tween finishes")
	t.check(calls[0] == 1, "midpoint callback ran once in total")
	pivot.free()
