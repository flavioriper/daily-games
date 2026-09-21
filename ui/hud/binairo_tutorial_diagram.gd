extends Control

## A small, native illustration for the first-play card. Drawing it here keeps
## the tutorial crisp on every phone size and lets the symbols match Binairo's
## actual sun/moon palette without shipping a separate bitmap.

const Pal = preload("res://core/palette.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var side := minf(size.x - 80.0, size.y - 28.0)
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	var cell := side / 6.0
	var grid := [
		[0, 1, 0, 1, 1, 0],
		[1, 0, 1, 0, 0, 1],
		[0, 0, 1, 1, 0, 1],
		[1, 1, 0, 0, 1, 0],
		[0, 1, 0, 1, 0, 1],
		[1, 0, 1, 0, 1, 0],
	]
	for r in 6:
		for c in 6:
			var rect := Rect2(origin + Vector2(c, r) * cell + Vector2(3, 3), Vector2(cell - 6, cell - 6))
			draw_style_box(_tile(Pal.SURFACE_HI), rect)
			var centre := rect.get_center()
			if (r + c) % 3 != 0:
				if grid[r][c] == 0:
					draw_circle(centre, cell * 0.22, Pal.SUN_RAY)
					draw_circle(centre, cell * 0.13, Pal.SUN)
				else:
					draw_circle(centre, cell * 0.20, Pal.MOON_INK)
					draw_circle(centre + Vector2(5, -3), cell * 0.20, Pal.SURFACE_HI)

	# A gentle highlight row makes the rule visible without turning the card into
	# a worksheet: the two matching moons are the move the player should notice.
	var y := origin.y + cell * 2.5
	draw_line(Vector2(origin.x + cell * 0.75, y), Vector2(origin.x + cell * 3.3, y), Pal.GOOD, 8.0, true)
	for i in 3:
		draw_circle(Vector2(origin.x + cell * (1.1 + i * 0.72), y), 12.0, Pal.GOOD)

func _tile(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(14)
	sb.border_width_bottom = 4
	sb.border_color = Pal.LINE
	return sb
