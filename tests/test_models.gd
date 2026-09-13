extends RefCounted

const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")

static func run(t) -> void:
	_test_slots(t)
	_test_rim(t)
	_test_trilon(t)
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
			t.check(hi.y <= 0.75, "%s is under 0.75 tall" % slot)
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

## The tile is a three-sided prism lying along X: flat face up, one face per
## cell state, each its own named material so the game can colour them apart
## (amendment B). The caps are the two triangular ends.
static func _test_trilon(t) -> void:
	var tile = Models.instance("tile")
	var names := Models.surface_names(tile)
	names.sort()
	t.eq(names, ["Cap", "Face_Empty", "Face_Moon", "Face_Sun"], "tile surfaces are the three faces and the caps")
	# Bevels shave up to a few hundredths off the sharp edges, hence the slack.
	var b := _bounds(tile)
	t.check(absf((b[1].x - b[0].x) - Placeholders.TILE_LEN) < 0.01, "tile runs %.2f along X (got %.3f)" % [Placeholders.TILE_LEN, b[1].x - b[0].x])
	t.check(absf((b[1].z - b[0].z) - Placeholders.TILE_SIDE) < 0.05, "tile is about %.2f wide across Z (got %.3f)" % [Placeholders.TILE_SIDE, b[1].z - b[0].z])
	# The flat face is up: the widest extent in Z is at the top, the apex at the base.
	var top_w := 0.0
	var base_w := 0.0
	for mi in Models.meshes(tile):
		for p in mi.mesh.get_faces():
			var w: Vector3 = mi.transform * p
			if w.y > b[1].y - 0.01:
				top_w = maxf(top_w, absf(w.z))
			if w.y < b[0].y + 0.02:
				base_w = maxf(base_w, absf(w.z))
	t.check(top_w > 0.3 and base_w < 0.1, "flat face on top (half-width %.2f), apex at the base (half-width %.2f)" % [top_w, base_w])
	Models.tint_named(tile, "Face_Moon", Color("3f4652"))
	var moon_hits := 0
	var other_hits := 0
	for mi in Models.meshes(tile):
		for i in mi.mesh.get_surface_count():
			var over = mi.get_surface_override_material(i)
			var moon := Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("3f4652")) if over != null else false
			if mi.mesh.surface_get_material(i).resource_name == "Face_Moon":
				moon_hits += 1 if moon else 0
			else:
				other_hits += 1 if moon else 0
	t.check(moon_hits >= 1 and other_hits == 0, "tint_named colours only the named face (moon=%d, others=%d)" % [moon_hits, other_hits])
	tile.free()

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
	t.check(absf(Models.height(tile) - Placeholders.TILE_H) < 0.03,
		"tile is an equilateral prism about %.3f tall, measured %.3f" % [Placeholders.TILE_H, Models.height(tile)])
	tile.free()
	var platform = Models.instance("platform")
	t.check(is_equal_approx(Models.height(platform), 0.6), "platform placeholder is 0.6 deep, measured %.3f" % Models.height(platform))
	platform.free()
