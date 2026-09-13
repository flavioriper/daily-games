extends RefCounted

const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Pal = preload("res://core/palette.gd")
const Toon = preload("res://core/toon.gd")

## Height budgets from docs/art/blender-contract.md; anything else gets 0.6.
const HEIGHT_BUDGET := {"tile": 0.75, "emblem_sun": 0.08, "emblem_moon": 0.08, "empty_mark": 0.04, "rim_edge": 0.12, "rim_corner": 0.12}

static func run(t) -> void:
	_test_slots(t)
	_test_rim(t)
	_test_trilon(t)
	_test_fallback(t)
	_test_tint_and_height(t)
	_test_focus_ring(t)
	_test_rim_sways(t)

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
	t.eq(Models.SLOTS, ["tile", "emblem_sun", "emblem_moon", "empty_mark", "rim_edge", "rim_corner", "platform", "water", "focus_ring"], "slot list matches the polish spec")
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
			var budget: float = HEIGHT_BUDGET.get(slot, 0.6)
			t.check(hi.y <= budget + 0.001, "%s is under %.2f tall (got %.3f)" % [slot, budget, hi.y])
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
	# The placeholder must keep the same contract as the export, since it is
	# what renders when the .glb is missing and what the headless tests see
	# on a fresh clone before the models are imported.
	var stand_in = Placeholders.make("tile")
	var stand_names := Models.surface_names(stand_in)
	stand_names.sort()
	t.eq(stand_names, ["Cap", "Face_Empty", "Face_Moon", "Face_Sun"], "placeholder tile has the four named faces")
	t.check(absf(Models.height(stand_in) - Placeholders.TILE_H) < 0.001, "placeholder tile is exactly TILE_H tall")
	t.check(Models.meshes(stand_in)[0].get_node_or_null("Outline") != null, "placeholder tile has an outline shell")
	stand_in.free()

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

## The focus ring is a flat translucent frame around one cell (polish spec,
## section 6): it sits on y = 0, fits the cell, gets no outline and carries
## its own material instance so one ring's alpha tween never touches another.
static func _test_focus_ring(t) -> void:
	var a = Models.instance("focus_ring")
	var b = Models.instance("focus_ring")
	var ms := Models.meshes(a)
	t.eq(ms.size(), 1, "focus ring is one mesh")
	var bounds := _bounds(a)
	t.check(is_zero_approx(bounds[0].y) and bounds[1].y <= 0.02, "focus ring is flat on y=0 (%.3f .. %.3f)" % [bounds[0].y, bounds[1].y])
	t.check(bounds[1].x <= Placeholders.FOCUS_OUTER + 0.001 and bounds[0].x >= -Placeholders.FOCUS_OUTER - 0.001, "focus ring spans the cell (%.3f)" % bounds[1].x)
	var mat = ms[0].material_override
	t.check(mat is StandardMaterial3D, "focus ring carries a StandardMaterial3D override")
	if mat is StandardMaterial3D:
		t.check(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "focus ring is unshaded")
		t.check(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "focus ring is alpha blended")
		t.check(Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b).is_equal_approx(Pal.FOCUS), "focus ring is FOCUS blue")
	t.check(Models.meshes(b)[0].material_override != mat, "each ring has its own material instance")
	t.check(ms[0].get_node_or_null("Outline") == null, "focus ring has no outline")
	a.free()
	b.free()

## The rim's tufts, petals and pollen sway (polish spec, section 4); the moss
## slab stays still. Checked on the export, since that is what the game shows.
static func _test_rim_sways(t) -> void:
	if not Models.has_model("rim_edge"):
		return
	for slot in ["rim_edge", "rim_corner"]:
		var piece = Models.instance(slot)
		var names := Models.surface_names(piece)
		t.check(names.has("Moss_flat"), "%s keeps a still Moss_flat surface" % slot)
		for mat in ["Grass_sway_flat", "Petal_sway_flat", "Pollen_sway_flat"]:
			t.check(names.has(mat), "%s carries %s" % [slot, mat])
		var wind := 0
		for mi in Models.meshes(piece):
			for i in mi.mesh.get_surface_count():
				var over = mi.get_surface_override_material(i)
				if over != null and over.shader == Toon.WIND_SHADER:
					wind += 1
		t.eq(wind, 3, "%s has three swaying surfaces" % slot)
		piece.free()
