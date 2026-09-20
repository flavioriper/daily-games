extends "res://ui/faces/face.gd"

## The mushroom, one of Balance's five camp fruit: a MUSHROOM_STEM trunk
## under a MUSHROOM cap with three pale spots, and the face low on the stem
## where the cap leaves it room. The only one of the five whose face sits
## below its widest point, which is what makes it read as a mushroom and not
## a berry with a hat.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#balance, mushroomP).
## Spec: docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 3.
##
## `sprig` is Mushroom Patch's one addition (2026-09-20): a leaf tucked under
## the right of the cap on a mushroom a hint planted, which is that board's
## given look, the way the queen bee wears a leaf-green gem on her crown for
## the same reason (ui/faces/bee_face.gd's `pinned`). It is off by default and
## keyed into the mesh cache through _kind(), exactly as hers is, so Balance's
## fruit is unchanged.
## Spec: docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md,
## section 10.

## R as a fraction of the seat, the mock's `r`.
const RATIO := 0.40
## The hint's leaf: where it is rooted, how long it is and which way it points
## -- the mock's `leaf(R*0.74, -R*0.66, R*0.42, -0.9)`.
const SPRIG_AT := Vector2(0.74, -0.66)
const SPRIG_LEN := 0.42
const SPRIG_ANGLE := -0.9

## A mushroom a hint planted, which can never be pulled up again.
var sprig: bool = false:
	set(v):
		if sprig == v:
			return
		sprig = v
		queue_redraw()

func _kind() -> String:
	return "mushroom%d" % int(sprig)

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.8 * 0.15 * R), 1.05 * R, 0.8 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"body":
			# The stem: down one side, round the foot and up the other, then
			# closed straight across under the cap. Its end point is appended
			# because the closing edge runs from it back to the start.
			var stem := PackedVector2Array()
			stem.append_array(Builder.bezier3(Vector2(-0.38, -0.1) * R, Vector2(-0.44, 0.7) * R,
				Vector2(-0.3, 1.02) * R, Vector2(0.0, 1.02) * R))
			stem.append_array(Builder.bezier3(Vector2(0.0, 1.02) * R, Vector2(0.3, 1.02) * R,
				Vector2(0.44, 0.7) * R, Vector2(0.38, -0.1) * R))
			stem.append(Vector2(0.38, -0.1) * R)
			b.polygon(stem, Pal.MUSHROOM_STEM)
			# The cap: one curve across the top, closed by its own chord.
			var cap: PackedVector2Array = Builder.bezier3(Vector2(-1.04, -0.08) * R,
				Vector2(-1.0, -1.1) * R, Vector2(1.0, -1.1) * R, Vector2(1.04, -0.08) * R)
			cap.append(Vector2(1.04, -0.08) * R)
			b.polygon(cap, Pal.MUSHROOM)
			var pale := Color(1.0, 1.0, 1.0, 0.55)
			b.disc(Vector2(-0.42, -0.5) * R, 0.15 * R, pale)
			b.disc(Vector2(0.3, -0.62) * R, 0.12 * R, pale)
			b.disc(Vector2(0.62, -0.26) * R, 0.1 * R, pale)
			_face_parts(b, 0.56 * R, Vector2(0.0, 0.42 * R), Pal.TEXT, eye)
			if sprig:
				_leaf(b, SPRIG_AT * R, SPRIG_LEN * R, SPRIG_ANGLE, Pal.LEAF)

## One leaf from `at`, `length` long along `angle`: two quadratic curves
## bowed either side of the stalk, the canvas mock's `leaf`.
static func _leaf(b: Builder, at: Vector2, length: float, angle: float, colour: Color) -> void:
	var xf := Transform2D(angle, at)
	var pts := Builder.bezier2(Vector2.ZERO,
		Vector2(length * 0.55, -length * 0.42), Vector2(length, 0.0))
	pts.append_array(Builder.bezier2(Vector2(length, 0.0),
		Vector2(length * 0.55, length * 0.42), Vector2.ZERO))
	b.polygon(xf * pts, colour)
