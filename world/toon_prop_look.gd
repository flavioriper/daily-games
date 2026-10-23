## Shared cel conversion for the props a peeplet carries: the imported
## StandardMaterial3D fills become toon_prop shader materials and each mesh
## gains a welded ink hull child. Same contract the crop and eyewear factories
## implement inline — those two keep their own copies because they diverge
## (crop skips ink on ground fixtures, eyewear sends emissive lenses through
## the toon fill on purpose), while every held tool and gadget wants exactly
## this.
class_name ToonPropLook
extends RefCounted

const TOON_SHADER := preload("res://world/toon_prop.gdshader")
const TOON_VCOL_SHADER := preload("res://world/toon_prop_vcol.gdshader")
const OUTLINE_SHADER := preload("res://world/toon_prop_outline.gdshader")

# World metres of ink for a held prop. Between the crop default 0.008
# (0.3 m props) and the face-sized eyewear 0.004, so tools and gadgets in
# the same pair of hands carry one ink weight.
const HELD_OUTLINE_WIDTH := 0.006
# The walker mounts a held prop at PeepletWalker.LAB_TO_WORLD, so a part's
# world thickness is its local extent times this. The hull pushes in world
# metres, so the comparison below has to happen in world units too.
const HELD_SCALE := 0.625
# A hull thinner than this many ink widths meets itself: the shell from
# each face lands past the opposite surface and the part renders as a solid
# black slab. The axe and shovel handle plugs (flat discs, 0.016 and
# 0.00001 local) and the wateringcan's rose holes and blush dots all fall
# here, so they go without ink and keep their fill.
const MIN_INK_THICKNESS := 3.0
# Name of the hull child, so a second apply() pass skips what it already made.
const INK_CHILD_NAME := "Ink"
# Local units two vertices have to be within to count as the same corner.
# The tool GLBs sit around 0.7 local across, so this only ever welds the
# duplicates a hard edge split apart.
const WELD_TOLERANCE := 0.0001

# One toon material per fill color, shared across kinds and instances.
static var toon_materials := {}
static var vcol_materials := {}
static var outline_materials := {}

static func apply(
		node: Node3D,
		_outline_width := HELD_OUTLINE_WIDTH,
		_prop_scale := HELD_SCALE) -> void:
	# daily: no ink hull (attach_ink_hull is never called). The house draws
	# its characters and what they wear with no line round them, so
	# the width and scale go unread.
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance.mesh == null or instance.name == INK_CHILD_NAME:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var base := instance.mesh.surface_get_material(surface)
			if base is not StandardMaterial3D:
				continue
			var std := base as StandardMaterial3D
			# Textured and transparent surfaces keep their import
			# material; toon_prop has no texture or alpha path, so
			# converting them would erase what makes them read.
			if std.albedo_texture != null:
				continue
			if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			# daily: an emissive surface (the halo) is painted like the rest;
			# its import material lit it as a glossy gold ring.
			var painted: bool = (instance.mesh.surface_get_format(surface) \
				& Mesh.ARRAY_FORMAT_COLOR) != 0
			instance.set_surface_override_material(
				surface, toon_material_for(std.albedo_color, painted))

## The ink hull rides as its own child rather than a material_overlay, because
## an overlay redraws the source mesh and the tool GLBs are hard-shaded: the
## axe head alone carries 118 vertices over 26 corners. Pushing each of those
## along its own face normal tears the shell open at every edge and no
## silhouette survives. The child gets the same geometry welded by position
## with the normals averaged, so the shell closes; the source mesh keeps its
## split normals and its faceted cel read.
static func attach_ink_hull(instance: MeshInstance3D, ink: ShaderMaterial) -> void:
	if instance.has_node(INK_CHILD_NAME):
		return
	var hull := welded_hull_mesh(instance.mesh)
	if hull == null:
		return
	var shell := MeshInstance3D.new()
	shell.name = INK_CHILD_NAME
	shell.mesh = hull
	shell.material_override = ink
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_child(shell)

## Every surface welded into one, positions merged within WELD_TOLERANCE and
## the normals of each merged corner averaged. Returns null when the source has
## nothing the outline shader can push (no triangles, or no normals to push
## along).
static func welded_hull_mesh(source: Mesh) -> ArrayMesh:
	var slots := {}
	var positions := PackedVector3Array()
	var summed := PackedVector3Array()
	var indices := PackedInt32Array()
	for surface in range(source.get_surface_count()):
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := source.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if verts.is_empty() or normals.size() != verts.size():
			continue
		var remap := PackedInt32Array()
		remap.resize(verts.size())
		for i in verts.size():
			var key := verts[i].snappedf(WELD_TOLERANCE)
			if slots.has(key):
				var slot: int = slots[key]
				remap[i] = slot
				summed[slot] += normals[i]
			else:
				slots[key] = positions.size()
				remap[i] = positions.size()
				positions.append(verts[i])
				summed.append(normals[i])
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if source_indices.is_empty():
			for i in verts.size():
				indices.append(remap[i])
		else:
			for i in source_indices.size():
				indices.append(remap[source_indices[i]])
	if indices.is_empty():
		return null
	# A corner whose faces point opposite ways — the rim of a flat disc — sums
	# to nothing. Those fall back to pointing away from the mesh centre, which
	# is the direction the ink wanted anyway on a convex prop.
	var centre := source.get_aabb().get_center()
	var hull_normals := PackedVector3Array()
	hull_normals.resize(positions.size())
	for i in positions.size():
		var averaged := summed[i]
		if averaged.length() < 0.001:
			averaged = positions[i] - centre
		hull_normals[i] = (
			averaged.normalized() if not averaged.is_zero_approx() else Vector3.UP
		)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = hull_normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var hull := ArrayMesh.new()
	hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return hull

## Shortest side of the mesh in the prop's own units, its own node scale
## folded in — how far the ink hull has to travel before it meets itself.
static func thinnest_extent(instance: MeshInstance3D) -> float:
	var size := instance.mesh.get_aabb().size * instance.transform.basis.get_scale()
	return minf(size.x, minf(size.y, size.z))

static func toon_material_for(fill: Color, painted: bool) -> ShaderMaterial:
	var pool := vcol_materials if painted else toon_materials
	var key := fill.to_html()
	if not pool.has(key):
		var toon := ShaderMaterial.new()
		toon.shader = TOON_VCOL_SHADER if painted else TOON_SHADER
		toon.set_shader_parameter("albedo_tint", fill)
		pool[key] = toon
	return pool[key]

static func outline_material_for(width: float) -> ShaderMaterial:
	if not outline_materials.has(width):
		var ink := ShaderMaterial.new()
		ink.shader = OUTLINE_SHADER
		ink.set_shader_parameter("outline_width", width)
		outline_materials[width] = ink
	return outline_materials[width]
