extends RefCounted

## The stone platform under a 3D board: a stretched slab plus a ring of moss
## rim pieces on its lip (amendment B). Pure node building, so it runs headless.

const Platform = preload("res://legacy/core/platform.gd")
const Models = preload("res://legacy/core/models.gd")
const Placeholders = preload("res://legacy/core/placeholders.gd")

const EPS := 0.001

static func run(t) -> void:
	_test_shape(t, 6, 6)
	_test_shape(t, 8, 8)
	_test_shape(t, 4, 6)
	_test_lip_matches_rim_depth(t)

## Root-space min/max of every face vertex under `node`, outline shells excluded.
static func _bounds(node: Node3D, xform: Transform3D = Transform3D.IDENTITY) -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var here := xform * node.transform
	if node is MeshInstance3D:
		for p in node.mesh.get_faces():
			var w: Vector3 = here * p
			lo = lo.min(w)
			hi = hi.max(w)
	for child in node.get_children():
		if child.name == "Outline" or not child is Node3D:
			continue
		var b := _bounds(child, here)
		lo = lo.min(b[0])
		hi = hi.max(b[1])
	return [lo, hi]

static func _test_shape(t, cols: int, rows: int) -> void:
	var tag := "%dx%d" % [cols, rows]
	var root: Node3D = Platform.build(cols, rows)
	t.check(root is Node3D, "%s build returns a Node3D" % tag)
	var half_x := cols * 0.5
	var half_z := rows * 0.5
	var out_x := half_x + Platform.LIP
	var out_z := half_z + Platform.LIP

	var slab: Node3D = root.get_node_or_null("Slab")
	t.check(slab != null, "%s has a Slab child" % tag)
	if slab != null:
		var sb := _bounds(slab)
		t.check(is_equal_approx(sb[0].x, -out_x) and is_equal_approx(sb[1].x, out_x)
			and is_equal_approx(sb[0].z, -out_z) and is_equal_approx(sb[1].z, out_z),
			"%s slab spans the board plus the lip (%s .. %s)" % [tag, sb[0], sb[1]])
		t.check(is_equal_approx(sb[1].y, 0.0) and is_equal_approx(sb[0].y, -Placeholders.PLATFORM_H),
			"%s slab top at y=0, %.2f deep" % [tag, Placeholders.PLATFORM_H])

	var rim: Array = []
	for child in root.get_children():
		if child != slab:
			rim.append(child)
	t.eq(rim.size(), 2 * cols + 2 * rows + 4, "%s rim has one edge per cell per side plus four corners" % tag)

	var reach := {"-x": false, "+x": false, "-z": false, "+z": false}
	var all_on_lip := true
	var all_grounded := true
	for piece in rim:
		var b := _bounds(piece)
		var lo: Vector3 = b[0]
		var hi: Vector3 = b[1]
		if absf(lo.y) > EPS:
			all_grounded = false
		var inside := lo.x >= -out_x - EPS and hi.x <= out_x + EPS and lo.z >= -out_z - EPS and hi.z <= out_z + EPS
		var clear_of_tiles := hi.x <= -half_x + EPS or lo.x >= half_x - EPS or hi.z <= -half_z + EPS or lo.z >= half_z - EPS
		if not (inside and clear_of_tiles):
			all_on_lip = false
		if is_equal_approx(lo.x, -out_x): reach["-x"] = true
		if is_equal_approx(hi.x, out_x): reach["+x"] = true
		if is_equal_approx(lo.z, -out_z): reach["-z"] = true
		if is_equal_approx(hi.z, out_z): reach["+z"] = true
	t.check(all_grounded, "%s every rim piece rests on the platform top" % tag)
	t.check(all_on_lip, "%s every rim piece lies on the lip, clear of the tiles" % tag)
	t.check(reach.values().all(func(v): return v), "%s rim reaches all four outer edges %s" % [tag, reach])
	root.free()

static func _test_lip_matches_rim_depth(t) -> void:
	var edge = Models.instance("rim_edge")
	var b := _bounds(edge)
	t.check(is_equal_approx(b[1].z - b[0].z, Platform.LIP), "the lip is exactly one rim piece deep")
	edge.free()
