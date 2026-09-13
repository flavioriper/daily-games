extends RefCounted

## Card flip for a board cell. The pivot sits at the centre of the piece; the
## first half turns it about X until it is edge-on, `at_midpoint` swaps what
## it shows, and the second half turns it back to flat from the other side, so
## the new face appears to have been on the back all along. Returns the tween
## so a caller can kill it when the cell is tapped again mid-flip.
## build() takes the tween so tests/test_flip.gd can drive an unbound one with
## Tween.custom_step; the game goes through start(), which binds to the pivot.

static func start(pivot: Node3D, at_midpoint: Callable, duration: float) -> Tween:
	return build(pivot.create_tween(), pivot, at_midpoint, duration)

static func build(tw: Tween, pivot: Node3D, at_midpoint: Callable, duration: float) -> Tween:
	var half := duration * 0.5
	tw.tween_property(pivot, "rotation:x", PI * 0.5, half) \
		.from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(at_midpoint)
	tw.tween_property(pivot, "rotation:x", 0.0, half) \
		.from(-PI * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw
