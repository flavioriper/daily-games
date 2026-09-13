extends RefCounted

const Pal = preload("res://core/palette.gd")

static func run(t) -> void:
	_test_contrast_formula(t)
	_test_readability(t)
	_test_categorical(t)
	_test_island_colours(t)

static func _test_contrast_formula(t) -> void:
	var bw: float = Pal.contrast(Color.BLACK, Color.WHITE)
	t.check(bw > 20.9 and bw < 21.1, "black on white is 21:1, got %.2f" % bw)
	t.check(is_equal_approx(Pal.contrast(Color.WHITE, Color.WHITE), 1.0), "same colour is 1:1")
	t.check(is_equal_approx(Pal.contrast(Pal.TEXT, Pal.PAPER), Pal.contrast(Pal.PAPER, Pal.TEXT)), "contrast is symmetric")

static func _test_readability(t) -> void:
	var body: float = Pal.contrast(Pal.TEXT, Pal.PAPER)
	t.check(body >= 4.5, "TEXT on PAPER meets 4.5:1, got %.2f" % body)
	var dim: float = Pal.contrast(Pal.TEXT_DIM, Pal.PAPER)
	t.check(dim >= 3.0, "TEXT_DIM on PAPER meets 3:1, got %.2f" % dim)
	var on_tile: float = Pal.contrast(Pal.TEXT, Pal.SURFACE)
	t.check(on_tile >= 4.5, "TEXT on SURFACE meets 4.5:1, got %.2f" % on_tile)
	t.check(Pal.contrast(Pal.OUTLINE, Pal.SURFACE) >= 7.0, "outline ink is clearly darker than a tile")
	t.check(Pal.BG == Pal.PAPER, "BG stays an alias of PAPER for the 2D boards")

static func _test_categorical(t) -> void:
	t.eq(Pal.CAT.size(), 8, "CAT keeps eight entries")
	for i in Pal.CAT.size():
		for j in range(i + 1, Pal.CAT.size()):
			t.check(Pal.CAT[i] != Pal.CAT[j], "CAT %d and %d differ" % [i, j])

static func _test_island_colours(t) -> void:
	var pal_script: Script = load("res://core/palette.gd")
	var constants: Dictionary = pal_script.get_script_constant_map()
	for name in ["STONE", "STONE_GIVEN", "SLATE", "SLATE_GIVEN", "SUN", "MOON", "MARK", "MOSS", "ROCK", "WATER"]:
		t.check(constants.has(name), "palette defines %s" % name)
	# Orange on cream is a hue contrast, not a luminance one; 1.4 keeps it from drifting to beige.
	t.check(Pal.contrast(Pal.SUN, Pal.STONE) >= 1.4, "sun emblem reads on a stone tile, got %.2f" % Pal.contrast(Pal.SUN, Pal.STONE))
	t.check(Pal.contrast(Pal.MOON, Pal.SLATE) >= 7.0, "crescent reads on a slate tile, got %.2f" % Pal.contrast(Pal.MOON, Pal.SLATE))
	t.check(Pal.contrast(Pal.STONE, Pal.SLATE) >= 5.0, "sun and moon tiles are far apart, got %.2f" % Pal.contrast(Pal.STONE, Pal.SLATE))
	t.check(Pal.STONE_GIVEN != Pal.STONE and Pal.SLATE_GIVEN != Pal.SLATE, "locked tiles differ from placed tiles")
