extends RefCounted

## Colour is never the only channel. Every token carries a shape too, so the
## boards stay readable for colour-blind players and on bad screens.

enum Kind { CIRCLE, SQUARE, TRIANGLE, DIAMOND, PLUS, HEX, STAR, BAR }

static func draw_shape(ci: CanvasItem, kind: int, centre: Vector2, r: float, col: Color) -> void:
	match kind:
		Kind.CIRCLE:
			ci.draw_circle(centre, r, col)
		Kind.SQUARE:
			ci.draw_rect(Rect2(centre - Vector2(r, r) * 0.88, Vector2(r, r) * 1.76), col, true)
		Kind.TRIANGLE:
			ci.draw_colored_polygon(PackedVector2Array([
				centre + Vector2(0, -r), centre + Vector2(r * 0.92, r * 0.72),
				centre + Vector2(-r * 0.92, r * 0.72)]), col)
		Kind.DIAMOND:
			ci.draw_colored_polygon(PackedVector2Array([
				centre + Vector2(0, -r), centre + Vector2(r, 0),
				centre + Vector2(0, r), centre + Vector2(-r, 0)]), col)
		Kind.PLUS:
			var t := r * 0.38
			ci.draw_rect(Rect2(centre - Vector2(t, r), Vector2(t * 2, r * 2)), col, true)
			ci.draw_rect(Rect2(centre - Vector2(r, t), Vector2(r * 2, t * 2)), col, true)
		Kind.HEX:
			var pts := PackedVector2Array()
			for i in 6:
				var a := TAU * (float(i) / 6.0) - PI / 2.0
				pts.append(centre + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, col)
		Kind.STAR:
			var sp := PackedVector2Array()
			for i in 10:
				var a := TAU * (float(i) / 10.0) - PI / 2.0
				var rr := r if i % 2 == 0 else r * 0.46
				sp.append(centre + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(sp, col)
		Kind.BAR:
			ci.draw_rect(Rect2(centre - Vector2(r, r * 0.34), Vector2(r * 2, r * 0.68)), col, true)
