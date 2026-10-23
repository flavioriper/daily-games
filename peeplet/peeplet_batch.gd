class_name PeepletBatch
extends RefCounted

## daily: the Peeplet in as few draw calls as it can be (2026-10-23, the user:
## "make them way better optimized to render since it's a 2d now"). Measured
## before, one Peeplet alone in its view: 40 bare, 45 in a beanie, 78 in the
## viking helm, 81 in the flower crown. gl_compatibility pays per surface and
## per next_pass, and ~/dev/peeplet spends them freely:
##
## - every fur shell is a next_pass of its own, four a part over six parts;
##   stack_shells() lays the four copies into one mesh, the shell's ratio
##   carried in UV2.x (peeplet_fur_shell.gdshader's `stacked`), so a part's
##   fur is one draw. The shells are opaque (cut by discard), so their order
##   inside the one draw does not matter;
## - the face is nine surfaces of flat colour; merge_face() bakes them into
##   one with the colour in the vertices;
## - a hat or a pair of glasses is a node per colour patch (the viking helm
##   46, 44 of them one cream); merge_props() welds every piece into one
##   painted surface and one glass surface, colours in the vertices.

const SHELL_RATIO_IN := Mesh.ARRAY_TEX_UV2

## The coat surface of `mesh` laid `count` times into one mesh, copy k
## carrying k / count in UV2.x: one draw for what was `count` next_passes.
static func stack_shells(mesh: Mesh, count: int) -> ArrayMesh:
	var source := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var n := verts.size()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	for k in Mesh.ARRAY_MAX:
		if source[k] == null or k == Mesh.ARRAY_INDEX:
			continue
		var whole = source[k].duplicate()
		for shell in range(1, count):
			whole.append_array(source[k])
		arrays[k] = whole
	var ratios := PackedVector2Array()
	ratios.resize(n * count)
	for shell in count:
		var ratio := Vector2(float(shell + 1) / float(count), 0.0)
		for i in n:
			ratios[shell * n + i] = ratio
	arrays[SHELL_RATIO_IN] = ratios
	var index: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	if not index.is_empty():
		var stacked := PackedInt32Array()
		stacked.resize(index.size() * count)
		for shell in count:
			var offset := shell * n
			var at := shell * index.size()
			for i in index.size():
				stacked[at + i] = index[i] + offset
		arrays[Mesh.ARRAY_INDEX] = stacked
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

## The coat chain's shells drawn as one stacked pass: the first shell
## material draws them all and ends the chain. The others stay in the array
## so whoever pushes a uniform down the chain still finds them.
static func stack_chain(chain: Array[ShaderMaterial]) -> void:
	chain[1].set_shader_parameter("stacked", true)
	chain[1].next_pass = null

## `instance`'s surfaces from `first` on, each a flat colour (its override
## material's albedo), baked into one surface of vertex colours under one
## unshaded material. Surfaces before `first` (the coat) keep their own.
static func merge_face(instance: MeshInstance3D, first: int) -> void:
	var source := instance.mesh
	var out := ArrayMesh.new()
	var kept: Array[Material] = []
	for surface in first:
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface))
		kept.append(instance.get_surface_override_material(surface))
	var parts := []
	for surface in range(first, source.get_surface_count()):
		var flat := instance.get_active_material(surface) as BaseMaterial3D
		parts.append([source.surface_get_arrays(surface), Transform3D.IDENTITY,
			flat.albedo_color if flat != null else Color.WHITE])
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _weld(parts))
	instance.mesh = out
	for surface in kept.size():
		instance.set_surface_override_material(surface, kept[surface])
	instance.set_surface_override_material(kept.size(), _flat_vertex_material())

## Every visible MeshInstance3D under `model` (already through the toon
## conversion) welded into one child: an opaque surface under the painted
## vertex-colour toon and a see-through one under the glass toon, each
## piece's fill in its vertices. Pieces whose name starts with one of `drop`
## go (the eyewear's temple arms, which the walker hides when worn).
static func merge_props(model: Node3D, painted: Material, glass: Material, drop := []) -> void:
	var opaque := []
	var clear := []
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		var instance := node as MeshInstance3D
		if instance.mesh == null or not instance.visible \
				or drop.any(func(p): return String(instance.name).begins_with(p)):
			continue
		var place := _transform_to(instance, model)
		for surface in instance.mesh.get_surface_count():
			if instance.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var material := instance.get_active_material(surface)
			var fill := Color.WHITE
			if material is ShaderMaterial:
				fill = (material as ShaderMaterial).get_shader_parameter("albedo_tint")
			elif material is BaseMaterial3D:
				fill = (material as BaseMaterial3D).albedo_color
			var arrays := instance.mesh.surface_get_arrays(surface)
			var see_through: bool = material is BaseMaterial3D \
				and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				or material is ShaderMaterial and (material as ShaderMaterial).shader == glass.shader
			(clear if see_through else opaque).append([arrays, place, fill])
	for node in meshes:
		node.get_parent().remove_child(node)
		node.queue_free()
	var batch := MeshInstance3D.new()
	batch.name = "Batch"
	batch.mesh = ArrayMesh.new()
	for group in [[opaque, painted], [clear, glass]]:
		if group[0].is_empty():
			continue
		batch.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _weld(group[0]))
		batch.set_surface_override_material(batch.mesh.get_surface_count() - 1, group[1])
	model.add_child(batch)
	# daily (2026-10-23, the cartoon pass): with PeepletFur.ink on, the
	# painted surface once more as an ink hull round the piece, one draw.
	if PeepletFur.ink and not opaque.is_empty():
		var ink := MeshInstance3D.new()
		ink.name = "Ink"
		ink.mesh = ArrayMesh.new()
		ink.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, batch.mesh.surface_get_arrays(0))
		ink.set_surface_override_material(0, _ink_material())
		ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(ink)

## Local units of ink round a worn piece (the glbs sit about 0.7 local
## across); the coat's own line is PeepletFur.OUTLINE_WIDTH.
const PROP_INK_WIDTH := 0.006
static var _ink: ShaderMaterial

static func _ink_material() -> ShaderMaterial:
	if _ink == null:
		_ink = ShaderMaterial.new()
		_ink.shader = load("res://world/toon_prop_outline.gdshader")
		_ink.set_shader_parameter("outline_width", PROP_INK_WIDTH)
		_ink.set_shader_parameter("outline_color", PeepletFur.OUTLINE_COLOR)
	return _ink

## [arrays, transform, colour] parts into one surface's arrays: positions
## and normals through the transform, the colour (times any painted vertex
## colour the part already had, the rainbow lenses) in COLOR as authored:
## the renderer reads vertex colour as sRGB and linearises it itself
## (stored linear, every hat came out a shade too deep).
static func _weld(parts: Array) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	for part in parts:
		var arrays: Array = part[0]
		var place: Transform3D = part[1]
		var fill: Color = part[2]
		var base := verts.size()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nn = arrays[Mesh.ARRAY_NORMAL]
		var cc = arrays[Mesh.ARRAY_COLOR]
		var turn := place.basis.inverse().transposed()
		for i in v.size():
			verts.append(place * v[i])
			normals.append((turn * nn[i]).normalized() if nn != null else Vector3.UP)
			colors.append(fill * cc[i] if cc != null else fill)
		var ii = arrays[Mesh.ARRAY_INDEX]
		if ii == null or ii.is_empty():
			for i in v.size():
				index.append(base + i)
		else:
			for i in ii:
				index.append(base + i)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = index
	return out

static func _transform_to(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != root and at is Node3D:
		t = (at as Node3D).transform * t
		at = at.get_parent()
	return t

static var _flat_vertex: StandardMaterial3D

static func _flat_vertex_material() -> StandardMaterial3D:
	if _flat_vertex == null:
		_flat_vertex = StandardMaterial3D.new()
		_flat_vertex.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flat_vertex.vertex_color_use_as_albedo = true
	return _flat_vertex
