extends Control

## A small native illustration shared by the tutorial cards. It is intentionally
## abstract: the copy teaches the exact rules, while the colored marks make the
## card feel like the game it introduces without shipping eighteen bitmaps.

const Pal = preload("res://core/palette.gd")

var puzzle_id := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var side := minf(size.x - 80.0, size.y - 28.0)
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	var cell := side / 6.0
	var accent := _accent()
	for r in 6:
		for c in 6:
			var rect := Rect2(origin + Vector2(c, r) * cell + Vector2(3, 3), Vector2(cell - 6, cell - 6))
			draw_style_box(_tile(Pal.SURFACE_HI), rect)
			if (r + c * 2 + puzzle_id.length()) % 3 != 0:
				var centre := rect.get_center()
				if (r + c) % 2 == 0:
					draw_circle(centre, cell * 0.18, accent)
				else:
					draw_line(centre - Vector2(cell * 0.2, 0), centre + Vector2(cell * 0.2, 0), accent, 8.0, true)

	# A quiet green guide marks the kind of relationship the player is looking
	# for, without pretending this is a playable board.
	var y := origin.y + cell * 2.5
	draw_line(Vector2(origin.x + cell * 0.8, y), Vector2(origin.x + cell * 4.1, y), Pal.GOOD, 8.0, true)
	for i in 3:
		draw_circle(Vector2(origin.x + cell * (1.1 + i * 1.05), y), 12.0, Pal.GOOD)

func _accent() -> Color:
	match puzzle_id:
		"hiddenword", "wordtrail": return Pal.MOON_INK
		"balance", "bridges", "planes": return Pal.ACCENT
		"lightup", "queens", "tents": return Pal.LEAF
		_: return Pal.SUN

func _tile(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(14)
	sb.border_width_bottom = 4
	sb.border_color = Pal.LINE
	return sb
