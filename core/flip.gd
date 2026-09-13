extends RefCounted

## Card flip for a board cell. The pivot sits at the centre of the piece; the
## first half turns it about X until it is edge-on while lifting it clear of
## the platform, `at_midpoint` swaps what it shows, and the second half turns
## it back to flat from the other side and sets it down, so the new face
## appears to have been on the back all along. Returns the tween so a caller
## can kill it when the cell is tapped again mid-flip (and then restore the
## pivot's rotation and position itself).
## build() takes the tween so tests/test_flip.gd can drive an unbound one with
## Tween.custom_step; the game goes through start(), which binds to the pivot.

## How far the piece rises at the midpoint, in world units. Half a tile's
## width keeps the trailing edge out of the platform while edge-on.
const LIFT := 0.3

static func start(pivot: Node3D, at_midpoint: Callable, duration: float) -> Tween:
	return build(pivot.create_tween(), pivot, at_midpoint, duration)

static func build(tw: Tween, pivot: Node3D, at_midpoint: Callable, duration: float) -> Tween:
	var half := duration * 0.5
	var rest_y := pivot.position.y
	tw.tween_property(pivot, "rotation:x", PI * 0.5, half) \
		.from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(pivot, "position:y", rest_y + LIFT, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(at_midpoint)
	tw.tween_property(pivot, "rotation:x", 0.0, half) \
		.from(-PI * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pivot, "position:y", rest_y, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw
