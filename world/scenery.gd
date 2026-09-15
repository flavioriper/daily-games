extends RefCounted

## Pieces a board dresses its surroundings with: a slab of ground, a sheet
## of water, a run of deck strips, a placed prop and a scattered MultiMesh.
## Pure node building with no board knowledge, so it runs headless and any
## board can use it. Code Break composes these in
## puzzles/codebreak_scenery.gd.
## Spec: docs/superpowers/specs/2026-09-15-codebreak-screen-design.md, sections 2 and 7.

const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Toon = preload("res://core/toon.gd")

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
## cross-section changes.
static func deck(x0: float, x1: float, z0: float, z1: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Deck"
	var strips := int(roundf(z1 - z0))
	for i in strips:
		var strip := Models.instance("deck")
		strip.name = "deck_%d" % i
		strip.position = Vector3((x0 + x1) * 0.5, -Placeholders.PLATFORM_H, z0 + 0.5 + i)
		strip.scale.x = x1 - x0
		root.add_child(strip)
	return root

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
	pivot.add_child(model)
	return pivot

## Every instance of `slot`'s first layer as one MultiMesh: one draw call for
## a whole meadow of tufts. The mesh and its toon (or wind) material come
## from a throwaway instance of the model, so the scatter matches a placed
## prop exactly, placeholder or export.
static func scatter(slot: String, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var sample := Models.instance(slot)
	var layers := Models.meshes(sample)
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
