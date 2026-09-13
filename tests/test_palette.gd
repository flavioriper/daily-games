extends RefCounted

const Pal = preload("res://core/palette.gd")

static func run(t) -> void:
	_test_contrast_formula(t)
	_test_readability(t)
	_test_categorical(t)

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
