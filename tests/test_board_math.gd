extends RefCounted

const BM = preload("res://legacy/core/board_math.gd")

static func run(t) -> void:
	_test_ray_plane(t)
	_test_cells(t)
	_test_aabb(t)

static func _test_ray_plane(t) -> void:
	var hit = BM.ray_plane(Vector3(0, 5, 0), Vector3(0, -1, 0), 0.0)
	t.check(hit != null and hit.is_equal_approx(Vector3.ZERO), "straight down hits the origin")
	hit = BM.ray_plane(Vector3(0, 5, 5), Vector3(0, -1, -1).normalized(), 0.0)
	t.check(hit != null and hit.is_equal_approx(Vector3.ZERO), "45 degree ray lands where expected")
	hit = BM.ray_plane(Vector3(0, 5, 0), Vector3(0, 0, -1), 0.0)
	t.check(hit == null, "parallel ray misses")
	hit = BM.ray_plane(Vector3(0, 5, 0), Vector3(0, 1, 0), 0.0)
	t.check(hit == null, "ray pointing away misses")
	hit = BM.ray_plane(Vector3(0, 5, 0), Vector3(0, -1, 0), 0.12)
	t.check(hit != null and is_equal_approx(hit.y, 0.12), "plane height respected")

static func _test_cells(t) -> void:
	var n := 6
	t.check(BM.cell_origin(n, n).is_equal_approx(Vector3(-3, 0, -3)), "6x6 board is centred on the origin")
	for r in n:
		for c in n:
			var centre: Vector3 = BM.cell_center(r, c, n, n, 0.0)
			t.eq(BM.world_to_cell(centre, n, n), Vector2i(c, r), "centre of (r%d,c%d) maps back" % [r, c])
	t.eq(BM.world_to_cell(Vector3(-3.01, 0, 0), n, n), Vector2i(-1, -1), "just left of the board is outside")
	t.eq(BM.world_to_cell(Vector3(3.0, 0, 0), n, n), Vector2i(-1, -1), "right edge is exclusive")
	t.eq(BM.world_to_cell(Vector3(0, 0, 3.0), n, n), Vector2i(-1, -1), "bottom edge is exclusive")
	t.eq(BM.world_to_cell(Vector3(-2.999, 0, -2.999), n, n), Vector2i(0, 0), "min corner is cell (0,0)")
	t.eq(BM.world_to_cell(Vector3(2.999, 0, 2.999), n, n), Vector2i(5, 5), "max corner is the last cell")
	t.check(is_equal_approx(BM.cell_center(0, 0, n, n, 0.4).y, 0.4), "cell_center carries the height")
	# Rectangular board: columns along X, rows along Z.
	t.eq(BM.world_to_cell(BM.cell_center(1, 3, 4, 2), 4, 2), Vector2i(3, 1), "4 cols x 2 rows maps (r1,c3)")
	t.check(BM.cell_center(0, 0, 4, 2).z < BM.cell_center(1, 0, 4, 2).z, "row index grows along +Z")
	t.check(BM.cell_center(0, 0, 4, 2).x < BM.cell_center(0, 1, 4, 2).x, "column index grows along +X")

static func _test_aabb(t) -> void:
	var box: AABB = BM.board_aabb(6, 6, 0.5)
	t.check(box.position.is_equal_approx(Vector3(-3, 0, -3)), "aabb starts at the min corner")
	t.check(box.size.is_equal_approx(Vector3(6, 0.5, 6)), "aabb spans the board and its height")
	for r in 6:
		for c in 6:
			t.check(box.has_point(BM.cell_center(r, c, 6, 6, 0.25)), "aabb contains cell (r%d,c%d)" % [r, c])
