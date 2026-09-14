extends RefCounted

const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Pal = preload("res://core/palette.gd")
const Toon = preload("res://core/toon.gd")

## Height budgets from docs/art/blender-contract.md; anything else gets 0.6.
const HEIGHT_BUDGET := {"tile": 0.9, "rim_edge": 0.12, "rim_corner": 0.12}

static func run(t) -> void:
	_test_slots(t)
	_test_rim(t)
	_test_cube(t)
	_test_fallback(t)
	_test_tint_and_height(t)
	_test_focus_ring(t)
	_test_rim_sways(t)
	_test_water_material(t)

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
	t.eq(Models.SLOTS, ["tile", "rim_edge", "rim_corner", "platform", "water", "focus_ring"], "slot list matches the polish spec")
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
		# Every layer of the tile assembly -- the stone body and both inlaid
		# symbols -- is a piece, so all of them carry an outline.
		var wants_outline: bool = slot == "tile"
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

## The tile is a cube standing on the platform, one state per face and each
## state on two opposite faces, so a tap is one quarter turn (amendment C). It
## is an assembly of three layers: a `Stone` body the game tints by the state
## that is up -- a rotating cube cannot hold a colour on one face -- and the
## `Sun` and `Moon` inlaid in its walls, which keep their modelled colours.
## The top and bottom faces are bare, which is how the empty state reads.
static func _test_cube(t) -> void:
	# The placeholder must keep the same contract as the export, since it is
	# what renders when the .glb is missing and what the headless tests see
	# on a fresh clone before the models are imported.
	var stand_in = Placeholders.make("tile")
	t.eq(Models.surface_names(stand_in), ["Stone", "Sun", "Moon"], "placeholder tile carries the same three layers")
	t.check(absf(Models.height(stand_in) - Placeholders.TILE_SIDE) < 0.001, "placeholder tile is exactly TILE_SIDE tall")
	t.check(Models.meshes(stand_in)[0].get_node_or_null("Outline") != null, "placeholder tile has an outline shell")
	stand_in.free()

	var tile = Models.instance("tile")
	t.eq(Models.surface_names(tile), ["Stone", "Sun", "Moon"], "tile is one mesh per layer: body, sun, moon")
	# Bevels shave a few hundredths off the sharp edges, hence the slack. The
	# inlaid symbols stand EMBLEM_PROUD out of the two wall pairs, so the
	# assembly is that much wider than the cube on X and Z; nothing sits on the
	# top or bottom face, so its height is the cube's side exactly.
	var b := _bounds(tile)
	var side := Placeholders.TILE_SIDE
	var wide := side + 2.0 * Placeholders.EMBLEM_PROUD
	for pair in [["X", b[1].x - b[0].x, wide], ["Y", b[1].y - b[0].y, side], ["Z", b[1].z - b[0].z, wide]]:
		t.check(absf((pair[1] as float) - (pair[2] as float)) < 0.02,
			"tile is about %.2f along %s (got %.3f)" % [pair[2], pair[0], pair[1]])
	t.check(b[0].y > -0.001 and absf(b[0].x + b[1].x) < 0.02 and absf(b[0].z + b[1].z) < 0.02,
		"tile stands on y = 0, centred on x and z (%s .. %s)" % [b[0], b[1]])
	# A cube is what makes a cell read as an object: at the board camera's
	# 68-degree pitch its walls face the camera, where the trilon showed only
	# its horizontal top face. So the widest extent in Z must reach the top
	# and the base alike, not taper to an apex.
	var top_w := 0.0
	var base_w := 0.0
	for mi in Models.meshes(tile):
		for poly in mi.mesh.get_faces():
			var w: Vector3 = mi.transform * poly
			if w.y > b[1].y - 0.01:
				top_w = maxf(top_w, absf(w.z))
			if w.y < b[0].y + 0.02:
				base_w = maxf(base_w, absf(w.z))
	t.check(top_w > 0.3 and base_w > 0.3,
		"walls run straight up: half-width %.2f at the top, %.2f at the base" % [top_w, base_w])
	Models.tint(tile, Color("3f4652"))
	var hits := 0
	for mi in Models.meshes(tile):
		for i in mi.mesh.get_surface_count():
			var over = mi.get_surface_override_material(i)
			if over != null and Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("3f4652")):
				hits += 1
	t.eq(hits, Models.meshes(tile).size(), "tint colours every layer of the tile at once")
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
	var tile = Models.instance("tile")
	t.check(absf(Models.height(tile) - Placeholders.TILE_SIDE) < 0.03,
		"tile is a cube about %.3f tall, measured %.3f" % [Placeholders.TILE_SIDE, Models.height(tile)])
	# tint_named touches one layer by material name; the inlaid sun and moon
	# keep the colours they were modelled with, which is why the tile can be a
	# multi-material assembly and still take a state colour.
	Models.tint_named(tile, "Stone", Color("d9605a"))
	var painted := 0
	for mi in Models.meshes(tile):
		var over = mi.get_surface_override_material(0)
		if over != null and Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("d9605a")):
			painted += 1
	t.eq(painted, 1, "tint_named swaps the toon colour on the stone body alone")
	Models.tint(tile, Color("d9605a"))
	var all_painted := true
	for mi in Models.meshes(tile):
		var over = mi.get_surface_override_material(0)
		if over == null or not Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("d9605a")):
			all_painted = false
	t.check(all_painted, "tint swaps the toon colour on every layer")
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

## The water slot always wears the water shader (polish spec, section 4),
## placeholder or export, so the stage never shows a plain toon plane.
static func _test_water_material(t) -> void:
	var water = Models.instance("water")
	var over = Models.meshes(water)[0].get_surface_override_material(0)
	t.check(over is ShaderMaterial and over.shader == Toon.WATER_SHADER, "water slot carries the water shader")
	t.check(over == Toon.water(), "the water material is the shared instance Ambient drives")
	water.free()
