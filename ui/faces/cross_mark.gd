extends RefCounted

## The mark that rules a cell out on Queens: a soft hand-drawn X in warm bark,
## its two strokes gently bowed and round-ended, over a faint copy of itself
## a little lower so it sits on the cell rather than floating. It replaced the
## pebble on 2026-09-25: on the region pastels a pebble read as the faint dot
## a bare cell carried, and the player could not see their own notes.
## Builder shapes, not a Control, the way mosaic_tile.gd is: a court bakes
## every mark into one mesh.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

## Half a stroke's length along its diagonal, its width and how far its middle
## bows off the straight line, all in cells.
const ARM := 0.15
const WIDTH := 0.075
const BOW := 0.018
## The shadow copy: how far below, and its ink.
const DROP := 0.022
const SHADOW_ALPHA := 0.16

## Draws the X about `at` on a cell `s` across, scaled by `grow` (a pop's
## squash), turned by `angle`, faded by `alpha`, in `ink`.
static func draw(b: Face.Builder, at: Vector2, s: float, grow: Vector2, alpha: float,
		angle := 0.0, ink: Color = Pal.BARK) -> void:
	if grow.x <= 0.0 or grow.y <= 0.0 or alpha <= 0.0:
		return
	var w := WIDTH * s * minf(grow.x, grow.y)
	_x(b, Transform2D(angle, grow, 0.0, at + Vector2(0.0, DROP * s * grow.y)), s, w,
		Color(Pal.TEXT, SHADOW_ALPHA * alpha))
	_x(b, Transform2D(angle, grow, 0.0, at), s, w, Color(ink, alpha))

static func _x(b: Face.Builder, xf: Transform2D, s: float, w: float, colour: Color) -> void:
	for d in [Vector2(1.0, 1.0), Vector2(1.0, -1.0)]:
		var along: Vector2 = d.normalized() * ARM * s * sqrt(2.0)
		var bow := Vector2(-along.y, along.x).normalized() * BOW * s
		b.stroke(PackedVector2Array([xf * -along, xf * bow, xf * along]), w, colour)
