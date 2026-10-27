extends SceneTree

## Throwaway probe: WordTiles' layout and its one mesh. Prints PASS or the
## failing lines.
##   godot --headless --path . --script tests/_probe_word_tiles.gd

var bad := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		bad += 1
		print("FAIL: ", what)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

func _initialize() -> void:
	var w := WordTiles.new()
	w.tile = 60.0
	check(w.tile_rect(0).position == Vector2.ZERO, "tile 0 at origin")
	check(near(w.tile_rect(1).position.x, 60.0 * 1.12), "tile 1 x")
	check(near(w.tile_rect(5).position.y, 60.0 * 1.12), "tile 5 on row two")
	check(near(w.tile_rect(5).position.x, 60.0 * 0.45), "the indent")
	var want := Vector2(60.0 * (7 * 1.12 - 0.12 + 0.45), 60.0 * (2 * 1.12 - 0.12))
	check(w.total_size().is_equal_approx(want), "total size %s vs %s" % [w.total_size(), want])
	check(w.custom_minimum_size.is_equal_approx(want), "minimum size follows")
	check(WordTiles.ROWS.size() == 2, "two rows")
	check(WordTiles.COLOURS["PUZZLES"].size() == 7 and WordTiles.COLOURS["DAILY"].size() == 5, "colours match words")
	check(WordTiles.TILT.size() == 12 and WordTiles.count() == 12, "twelve tilts and tiles")
	check(WordTiles.letter_at(0) == "D" and WordTiles.letter_at(5) == "P" and WordTiles.letter_at(11) == "S", "letters")
	check(WordTiles.ink_at(0) == WordTiles.Pal.TEXT and WordTiles.ink_at(3) == WordTiles.Pal.SURFACE, "ink")
	w.tile = 120.0
	check(near(w.tile_rect(1).position.x, 120.0 * 1.12), "tile change re-lays")
	w._build()
	check(w._tiles.size() == 12 and w._all != null, "mesh built")
	var one: int = w._tiles[0].surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	var all: int = w._all.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	check(all > one * 10, "the whole carries every tile (%d vs %d each)" % [all, one])
	var box := Rect2()
	for p in w._all.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		box = box.expand(p)
	check(box.size.x >= w.total_size().x - 2.0 and box.size.x < w.total_size().x + 24.0, "mesh spans the control: %s vs %s" % [box.size, w.total_size()])
	w.shown = 99
	check(w.shown == 12, "shown clamps")
	w.free()
	print("PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
