extends RefCounted

const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Pal = preload("res://core/palette.gd")
const Toon = preload("res://core/toon.gd")

## Height budgets from docs/art/blender-contract.md; anything else gets 0.6.
const HEIGHT_BUDGET := {"tile": 0.9, "rim_edge": 0.12, "rim_corner": 0.12,
	"socket": 0.15, "peg": 0.5, "pip": 0.2, "lid": 0.3,
	"pipe_pad": 0.15, "pipe_cap": 0.38, "pipe_straight": 0.38, "pipe_elbow": 0.38,
	"pipe_tee": 0.38, "pipe_cross": 0.38, "valve": 0.12,
	"scale_stand": 1.1, "scale_beam": 0.3, "scale_pan": 0.4, "plinth": 0.2,
	"weight_disc": 0.1, "token_ball": 0.35, "token_cube": 0.35, "token_prism": 0.35,
	"token_gem": 0.35, "token_cross": 0.35, "post": 0.7}

## Footprint budget (X by Z) for the slots that are not one cell. Balance's
## scale spans its whole band by design -- the beam reaches a pan each way and
## the pan is wider than a cell -- and its plinth covers the two cells whose
## taps add and remove a disc. Anything absent here is held to the 1 x 1 rule.
const FOOTPRINT := {"scale_beam": Vector2(3.2, 0.3), "scale_pan": Vector2(1.3, 1.3),
	"plinth": Vector2(1.0, 2.0)}

## Every layer (material name) each slot must carry, sorted, matching
## docs/art/blender-contract.md's table exactly. Where `_test_slots` used to
## only assert `size() >= 1` (a slot with a mesh at all), this instead checks
## the full set: a wholly missing layer, or a misnamed `_flat` layer, now
## fails here instead of only showing up later as a pipe that never turns
## blue or a valve with the wrong shadow. `platform` and `water` are plain,
## untinted primitives with no named layer of their own -- surface_names
## reports one surface with an empty resource name for both.
const LAYERS := {"tile": ["Moon", "Slate_flat", "Stone", "Sun"],
	"rim_edge": ["Grass_sway_flat", "Moss_flat", "Petal_sway_flat", "Pollen_sway_flat"],
	"rim_corner": ["Grass_sway_flat", "Moss_flat", "Petal_sway_flat", "Pollen_sway_flat"],
	"platform": [""], "water": [""],
	"socket": ["Stone", "Well_flat"], "peg": ["Mark_flat", "Shell"], "pip": ["Pip", "Well_flat"],
	"lid": ["Knob", "Lid"], "pipe_pad": ["Stone"],
	"scale_stand": ["Cap", "Stone"], "scale_beam": ["Metal", "Wood"],
	"scale_pan": ["Cord_flat", "Pan"],
	"plinth": ["Num_flat", "Stone", "Well_flat"], "weight_disc": ["Disc"],
	"token_ball": ["Token"], "token_cube": ["Token"], "token_prism": ["Token"],
	"token_gem": ["Token"], "token_cross": ["Token"], "post": ["Cap", "Wood"],
	"pipe_cap": ["Collar", "Flow_flat", "Steel"], "pipe_straight": ["Collar", "Flow_flat", "Steel"],
	"pipe_elbow": ["Collar", "Flow_flat", "Steel"], "pipe_tee": ["Collar", "Flow_flat", "Steel"],
	"pipe_cross": ["Collar", "Flow_flat", "Steel"], "valve": ["Bolt_flat", "Metal"]}

static func run(t) -> void:
	_test_slots(t)
	_test_rim(t)
	_test_cube(t)
	_test_fallback(t)
	_test_tint_and_height(t)
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
	t.eq(Models.SLOTS, ["tile", "rim_edge", "rim_corner", "platform", "water", "socket", "peg", "pip", "lid",
		"pipe_pad", "pipe_cap", "pipe_straight", "pipe_elbow", "pipe_tee", "pipe_cross", "valve",
		"scale_stand", "scale_beam", "scale_pan", "plinth", "weight_disc",
		"token_ball", "token_cube", "token_prism", "token_gem", "token_cross", "post"],
		"slot list matches the polish, codebreak, pipes, balance and untangle specs")
	for slot in Models.SLOTS:
		var node = Models.instance(slot)
		t.check(node is Node3D, "%s yields a Node3D" % slot)
		var ms = Models.meshes(node)
		t.check(ms.size() >= 1, "%s has a mesh" % slot)
		var got_layers := Models.surface_names(node)
		got_layers.sort()
		t.eq(got_layers, LAYERS[slot], "%s carries exactly its modelled layers" % slot)
		var b := _bounds(node)
		var lo: Vector3 = b[0]
		var hi: Vector3 = b[1]
		t.check(absf(lo.y) < 0.001, "%s base sits at y=0 (min y %.3f)" % [slot, lo.y])
		if not slot in Models.UNBOUNDED:
			var foot: Vector2 = FOOTPRINT.get(slot, Vector2.ONE)
			t.check(lo.x >= -foot.x * 0.5 - 0.001 and hi.x <= foot.x * 0.5 + 0.001
					and lo.z >= -foot.y * 0.5 - 0.001 and hi.z <= foot.y * 0.5 + 0.001,
				"%s fits a %.1fx%.1f footprint (%s .. %s)" % [slot, foot.x, foot.y, lo, hi])
			var budget: float = HEIGHT_BUDGET.get(slot, 0.6)
			t.check(hi.y <= budget + 0.001, "%s is under %.2f tall (got %.3f)" % [slot, budget, hi.y])
		# Which layers are pieces and so carry an outline shell. The tile's
		# slate moon faces are not one: the body already draws the cell's
		# silhouette, and a second shell inside it would read as a seam.
		var outlined: Array = {"tile": ["Stone", "Sun", "Moon"], "socket": ["Stone"], "peg": ["Shell"],
			"pip": ["Pip"], "lid": ["Lid", "Knob"], "pipe_pad": ["Stone"],
			"pipe_cap": ["Steel", "Collar"], "pipe_straight": ["Steel", "Collar"],
			"pipe_elbow": ["Steel", "Collar"], "pipe_tee": ["Steel", "Collar"],
			"pipe_cross": ["Steel", "Collar"], "valve": ["Metal"],
			"scale_stand": ["Stone", "Cap"], "scale_beam": ["Wood", "Metal"],
			"scale_pan": ["Pan"], "plinth": ["Stone"], "weight_disc": ["Disc"],
			"token_ball": ["Token"], "token_cube": ["Token"], "token_prism": ["Token"],
			"token_gem": ["Token"], "token_cross": ["Token"],
			"post": ["Wood", "Cap"]}.get(slot, [])
		# Held past node.free() below: a pipe's Flow_flat override is a fresh
		# ShaderMaterial with no other owner (Models._dress, one per instance so
		# each cell drives its own `wet`). Under the headless dummy renderer only,
		# freeing the node while that override's refcount is its sole reference
		# races the engine's own teardown and logs a spurious
		# "Parameter material is null" (material_get_instance_shader_parameters);
		# it never happens under the real GL renderer. Keeping a script-side
		# reference alive until after free() returns avoids the race without
		# touching Models._dress or sharing the per-cell material it hands out.
		var overrides: Array = []
		for mi in ms:
			var src: Material = mi.mesh.surface_get_material(0)
			var mat_name: String = src.resource_name if src != null else ""
			var has_outline := mi.get_node_or_null("Outline") != null
			t.check(has_outline == (mat_name in outlined),
				"%s/%s outline present=%s" % [slot, mat_name, has_outline])
			for i in mi.mesh.get_surface_count():
				var ov := mi.get_surface_override_material(i)
				if ov != null:
					overrides.append(ov)
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
	var stand_in_layers := Models.surface_names(stand_in)
	stand_in_layers.sort()
	t.eq(stand_in_layers, ["Moon", "Slate_flat", "Stone", "Sun"], "placeholder tile carries the same four layers")
	t.check(absf(Models.height(stand_in) - Placeholders.TILE_SIDE) < 0.001, "placeholder tile is exactly TILE_SIDE tall")
	t.check(Models.meshes(stand_in)[0].get_node_or_null("Outline") != null, "placeholder tile has an outline shell")
	stand_in.free()

	var tile = Models.instance("tile")
	var layers := Models.surface_names(tile)
	layers.sort()
	t.eq(layers, ["Moon", "Slate_flat", "Stone", "Sun"], "tile is one mesh per layer: body, slate moon faces, sun, moon")
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
	t.eq(painted, 1, "tint_named swaps the toon colour on the named layer alone")
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
