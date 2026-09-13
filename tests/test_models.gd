extends RefCounted

const Models = preload("res://core/models.gd")

static func run(t) -> void:
	_test_slots(t)
	_test_fallback(t)
	_test_tint_and_height(t)

## World-space min/max of every face vertex under `root`, outline shells excluded.
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
	for slot in Models.SLOTS:
		var node = Models.instance(slot)
		t.check(node is Node3D, "%s yields a Node3D" % slot)
		var ms = Models.meshes(node)
		t.check(ms.size() >= 1, "%s has a mesh" % slot)
		var b := _bounds(node)
		var lo: Vector3 = b[0]
		var hi: Vector3 = b[1]
		t.check(absf(lo.y) < 0.001, "%s base sits at y=0 (min y %.3f)" % [slot, lo.y])
		if slot != "table":
			t.check(lo.x >= -0.5 and hi.x <= 0.5 and lo.z >= -0.5 and hi.z <= 0.5,
				"%s fits a 1x1 footprint (%s .. %s)" % [slot, lo, hi])
			t.check(hi.y <= 0.6, "%s is under 0.6 tall" % slot)
		for mi in ms:
			var has_outline := mi.get_node_or_null("Outline") != null
			t.check(has_outline == (slot != "table"), "%s outline present=%s" % [slot, has_outline])
		node.free()

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
	var tok = Models.instance("token_circle")
	Models.tint(tok, Color("d9605a"))
	var over = Models.meshes(tok)[0].get_surface_override_material(0)
	t.check(over != null and Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("d9605a")), "tint swaps the toon colour")
	tok.free()
	var tile = Models.instance("tile")
	t.check(is_equal_approx(Models.height(tile), 0.12), "tile placeholder is 0.12 tall, measured %.3f" % Models.height(tile))
	tile.free()
