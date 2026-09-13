extends RefCounted

const Models = preload("res://core/models.gd")

static func run(t) -> void:
	_test_slots(t)
	_test_rim(t)
	_test_fallback(t)
	_test_tint_and_height(t)

## Root-space min/max of every face vertex under `root`, outline shells excluded.
static func _bounds(root: Node3D) -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for mi in Models.meshes(root):
		for p in mi.mesh.get_faces():
			var w: Vector3 = mi.transform * p
			lo = lo.min(w)
			hi = hi.max(w)
	return [lo, hi]

static func _test_slots(t) -> void:
	t.eq(Models.SLOTS, ["tile", "emblem_sun", "emblem_moon", "empty_mark", "rim_edge", "rim_corner", "platform", "water"], "slot list matches amendment B")
	for slot in Models.SLOTS:
		var node = Models.instance(slot)
		t.check(node is Node3D, "%s yields a Node3D" % slot)
		var ms = Models.meshes(node)
		t.check(ms.size() >= 1, "%s has a mesh" % slot)
		var b := _bounds(node)
		var lo: Vector3 = b[0]
		var hi: Vector3 = b[1]
		t.check(absf(lo.y) < 0.001, "%s base sits at y=0 (min y %.3f)" % [slot, lo.y])
		if not slot in Models.UNBOUNDED:
			t.check(lo.x >= -0.5 and hi.x <= 0.5 and lo.z >= -0.5 and hi.z <= 0.5,
				"%s fits a 1x1 footprint (%s .. %s)" % [slot, lo, hi])
			t.check(hi.y <= 0.6, "%s is under 0.6 tall" % slot)
		var wants_outline: bool = slot in ["tile", "emblem_sun", "emblem_moon"]
		for mi in ms:
			var has_outline := mi.get_node_or_null("Outline") != null
			t.check(has_outline == wants_outline, "%s outline present=%s" % [slot, has_outline])
		node.free()
	var platform = Models.instance("platform")
	var pb := _bounds(platform)
	t.check(is_equal_approx(pb[1].x - pb[0].x, 1.0) and is_equal_approx(pb[1].z - pb[0].z, 1.0), "platform is a unit slab the board scales")
	platform.free()

## The moss rim sits on the platform lip, so an edge piece spans one cell along
## X and half a cell along Z, a corner half a cell each way, both low enough to
## stay clear of the tiles (amendment B).
static func _test_rim(t) -> void:
	var edge = Models.instance("rim_edge")
	var eb := _bounds(edge)
	t.check(eb[0].x >= -0.5 and eb[1].x <= 0.5 and eb[0].z >= -0.25 and eb[1].z <= 0.25,
		"rim_edge fits 1 x 0.5 (%s .. %s)" % [eb[0], eb[1]])
	t.check(eb[1].y <= 0.12 + 0.001, "rim_edge is under 0.12 tall (%.3f)" % eb[1].y)
	edge.free()
	var corner = Models.instance("rim_corner")
	var cb := _bounds(corner)
	t.check(cb[0].x >= -0.25 and cb[1].x <= 0.25 and cb[0].z >= -0.25 and cb[1].z <= 0.25,
		"rim_corner fits 0.5 x 0.5 (%s .. %s)" % [cb[0], cb[1]])
	t.check(cb[1].y <= 0.12 + 0.001, "rim_corner is under 0.12 tall (%.3f)" % cb[1].y)
	corner.free()

static func _test_fallback(t) -> void:
	t.check(not Models.has_model("no_such_thing"), "has_model is false for a missing file")
	var unknown = Models.instance("no_such_thing")
	t.check(unknown is Node3D and Models.meshes(unknown).size() == 1, "unknown slot falls back to a placeholder")
	unknown.free()
	var a = Models.instance("tile")
	var b = Models.instance("tile")
	t.check(a != b, "instances are distinct nodes")
	a.free()
	b.free()

static func _test_tint_and_height(t) -> void:
	var tok = Models.instance("emblem_sun")
	Models.tint(tok, Color("d9605a"))
	var over = Models.meshes(tok)[0].get_surface_override_material(0)
	t.check(over != null and Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("d9605a")), "tint swaps the toon colour")
	tok.free()
	var tile = Models.instance("tile")
	t.check(is_equal_approx(Models.height(tile), 0.14), "tile is 0.14 tall, measured %.3f" % Models.height(tile))
	# Tinting replaces every surface with one colour, so a tile with a second
	# material would go monochrome the moment it is tinted (contract rule 6).
	var surfaces := 0
	for mi in Models.meshes(tile):
		surfaces += mi.mesh.get_surface_count()
	t.eq(surfaces, 1, "tile has a single material surface")
	tile.free()
	var platform = Models.instance("platform")
	t.check(is_equal_approx(Models.height(platform), 0.6), "platform placeholder is 0.6 deep, measured %.3f" % Models.height(platform))
	platform.free()
