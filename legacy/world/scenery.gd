extends RefCounted

## Pieces a board dresses its surroundings with: a slab of ground, a sheet
## of water, a run of deck strips, a placed prop and a scattered MultiMesh.
## Pure node building with no board knowledge, so it runs headless and any
## board can use it. Code Break composes these in
## puzzles/codebreak_scenery.gd.
## Spec: docs/superpowers/specs/2026-09-15-codebreak-screen-design.md, sections 2 and 7.

const Models = preload("res://legacy/core/models.gd")
const Placeholders = preload("res://legacy/core/placeholders.gd")
const Toon = preload("res://legacy/core/toon.gd")

## A box of ground in one toon colour, centred at `centre`. No outline: a
## forty-unit box's shell would draw a dark band along the horizon. Casts no
## shadow (nothing stands under the ground) but receives them.
static func ground(size: Vector3, centre: Vector3, colour: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = box
	mi.material_override = Toon.material(colour)
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A sheet of the stage's own water, so a splash rings it. `size` is x by z.
static func water(size: Vector2, centre: Vector3) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.material_override = Toon.water()
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A run of `deck` strips with their tops at y = 0, covering x from `x0` to
## `x1` and z from `z0` to `z1`: one strip per unit of z, each stretched
## along x. The strip is modelled exactly one unit long so the stretch is a
## plain scale, and its planks run along x so nothing about their
## cross-section changes. `z1 - z0` must be a whole number of strips, since
## that is what the run is counted in; a fraction would leave a gap or an
## overhang at the far end.
static func deck(x0: float, x1: float, z0: float, z1: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Deck"
	var strips := int(roundf(z1 - z0))
	for i in strips:
		var strip := Models.instance("deck")
		strip.name = "deck_%d" % i
		strip.position = Vector3((x0 + x1) * 0.5, -Placeholders.DECK_H, z0 + 0.5 + i)
		strip.scale.x = x1 - x0
		seed_grain(strip, float(i))
		root.add_child(strip)
	return root

## Which log a wooden piece was cut from. Shifts the grain shader's figure on
## every wood mesh under `node`, so ten strips of one deck mesh do not repeat.
## Seed it from something fixed at placement -- an index, the spot a prop was
## put -- never from a live transform an entrance might still be moving.
##
## Only the wood layers are touched: the seed swaps in the wood material cut
## from that log (core/toon.gd, GRAIN_LOGS), and a leaf has no grain to cut.
## It is a material swap and not an instance shader parameter on purpose --
## those are read out of the global shader buffer, which the gl_compatibility
## shaders declare as 256 items, sixteen instances in the whole frame, and a
## mobile driver returns garbage past that (measured 2026-09-17 on Android:
## twenty-five wood meshes on one screen, and the deck's figure came back as
## chopped dashes while the day card's edge chewed the card into blocks).
##
## The seed is remembered on each mesh, so a later recolour through
## Toon.material_for keeps the figure rather than reverting to log zero.
static func seed_grain(node: Node, seed: float) -> void:
	var log_seed := Toon.grain_log(seed)
	for mi in Models.meshes(node):
		if _is_wood(mi):
			mi.set_meta(Toon.GRAIN_SEED_META, log_seed)
			_recut(mi, log_seed)

## Every wood material on `mi`, swapped for the same wood cut from `seed`.
static func _recut(mi: MeshInstance3D, seed: float) -> void:
	if mi.material_override is ShaderMaterial \
			and (mi.material_override as ShaderMaterial).shader == Toon.WOOD_SHADER:
		mi.material_override = _same_wood(mi.material_override, seed)
		return
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m: Material = mi.get_active_material(i)
		if m is ShaderMaterial and (m as ShaderMaterial).shader == Toon.WOOD_SHADER:
			mi.set_surface_override_material(i, _same_wood(m, seed))

## `m`'s colour and grain axis, cut from `seed`.
static func _same_wood(m: ShaderMaterial, seed: float) -> ShaderMaterial:
	return Toon.wood_material(
		m.get_shader_parameter("albedo"), m.get_shader_parameter("grain_axis"), seed)

## Whether any surface of `mi` wears the wood shader.
static func _is_wood(mi: MeshInstance3D) -> bool:
	var mats: Array[Material] = []
	if mi.material_override != null:
		mats.append(mi.material_override)
	elif mi.mesh != null:
		for i in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			if m != null:
				mats.append(m)
	for m in mats:
		if m is ShaderMaterial and (m as ShaderMaterial).shader == Toon.WOOD_SHADER:
			return true
	return false

## One library model at `at`, turned `yaw` about Y and scaled, under a pivot.
## The pivot carries position and yaw and the model the scale, so an
## entrance can pop the pivot from nothing to one without disturbing a
## prop's own size.
static func prop(slot: String, at: Vector3, yaw := 0.0, scale := Vector3.ONE) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = slot
	pivot.position = at
	pivot.rotation.y = yaw
	var model := Models.instance(slot)
	model.scale = scale
	seed_grain(model, fposmod(at.x * 3.7 + at.z * 5.3 + yaw, 97.0))
	pivot.add_child(model)
	return pivot

## Every instance of `slot`'s first layer as one MultiMesh: one draw call for
## a whole meadow of tufts. The mesh and its toon (or wind) material come
## from a throwaway instance of the model, so the scatter matches a placed
## prop exactly, placeholder or export.
static func scatter(slot: String, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var sample := Models.instance(slot)
	var layers := Models.meshes(sample)
	if layers.size() > 1:
		push_warning("Scenery.scatter: %s has %d layers; only the first is scattered" % [slot, layers.size()])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mmi := MultiMeshInstance3D.new()
	mmi.name = slot + "_field"
	if not layers.is_empty():
		var mi: MeshInstance3D = layers[0]
		mm.mesh = mi.mesh
		var mat: Material = mi.get_surface_override_material(0)
		if mat != null:
			mmi.material_override = mat
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sample.free()
	return mmi
