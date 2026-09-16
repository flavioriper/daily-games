extends Node3D

## The painted landscape every board floats over: a rolling meadow whose grass
## leans in the wind, two tree clumps and a scatter of blossom. All of it is
## exported from art/landscape.blend, where the colour is
## painted into the textures rather than lit, so this loads the .glb files
## directly instead of going through core/models.gd -- Toon.apply_to() replaces
## an imported StandardMaterial3D with a flat toon colour and would throw every
## painted texture away.
##
## The stage builds one of these as "Backdrop" and re-centres it on each fit.

const Motion = preload("res://core/motion.gd")

const DIR := "res://assets/models/"
const GRASS_SHADER := preload("res://shaders/backdrop_grass.gdshader")

## The meadow is modelled 21.6 by 15.4 and has to cover what the camera sees
## past the board, so it is stretched across X and Z -- but not up. Scaling it
## evenly would grow the blades to several times a tile's height; keeping Y at
## one leaves the grass its own size and only flattens the roll of the ground,
## which is what a broad meadow wants anyway.
##
## The number is set by the ground texture, not by coverage. test_1.jpg is a
## whole painted top-down meadow -- vignetted, bordered with leaves, 498 px
## across -- rather than a tiling grass swatch, so it wants to be seen about
## once across the frame. Stretched much past this it stops reading as grass
## and starts reading as its own brushstrokes; the painted border then falls
## outside the view instead of framing the board.
const SPREAD := 2.4
## Height of the basin's water line in the meadow's own coordinates. The ground
## is modelled with a bowl in the middle (art/landscape.blend) and the meadow is
## sunk so that this height lands exactly on the stage's pond: the shoreline is
## then drawn by the terrain rising out of the water, not by the straight edges
## of the water plane, which at this camera pitch read as a blue card lying on
## the grass. Re-measure it if the basin is ever resculpted.
const WATER_LINE := 3.06

## The stage's own water depth. Set before this node enters the tree; the
## default only matters to a harness that builds a Backdrop on its own.
var water_depth := 4.0
## Y of the meadow's lowest point, from water_depth and WATER_LINE.
var _meadow_y := 0.0
const BLOSSOMS := 70

## art/landscape.blend also holds the painting's cloud, and cloud.glb is
## exported, but nothing here builds it. The board camera looks down at 68
## degrees with a 30 degree field, so the top of the frame still points 53
## degrees below the horizon and no sky is ever in view: measured on Binairo,
## all eight corners of the cloud project between y = -1926 and y = -6746 on a
## 1920-tall frame. A card that cannot show a single pixel is not worth its draw
## call or its 1462 x 1024 texture in the APK. Lowering the camera pitch far
## enough to raise a horizon is the only thing that would bring it back, and
## that reframes all twelve boards.

var meadow: Node3D
var clumps: Array[Node3D] = []
var blossoms: MultiMeshInstance3D
## Blade roots in meadow-local space, the cheapest ground sampler there is:
## every one of them was grown on the surface, so anything stood at one is
## standing on the ground without a raycast.
var _roots: PackedVector3Array = PackedVector3Array()

func _ready() -> void:
	_meadow_y = -water_depth - WATER_LINE
	meadow = _build_meadow()
	if meadow == null:
		return
	_build_clumps()
	blossoms = _build_blossoms()

## Nothing to do: every moving thing in the landscape is the grass, and the
## grass reads the motion_scale shader global that world/ambient.gd owns. Kept
## so the settings sheet can call it without knowing that, and so a later
## moving piece has somewhere to go.
func refresh() -> void:
	pass

## Slides the whole landscape under the board so a big board does not run off
## the edge of a meadow centred on the world origin. The stage calls this from
## fit_camera, next to Ambient.fit_to.
func fit_to(aabb: AABB) -> void:
	var c := aabb.get_center()
	position = Vector3(c.x, 0.0, c.z)

func _instance(slot: String) -> Node3D:
	var path := DIR + slot + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("Backdrop: %s is missing; run tools/build_models.sh" % path)
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var node: Node3D = scene.instantiate() as Node3D
	node.name = slot
	return node

## Every mesh under `root`, the way core/models.gd walks one. No outline shells
## to skip here: nothing in the backdrop is outlined.
static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_meshes(child))
	return out

## The imported material's texture, unlit and never shadowed. The landscape's
## light is painted into it, so the stage's sun must not add a second one.
static func _flat(src: Material, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if src is StandardMaterial3D:
		var s := src as StandardMaterial3D
		m.albedo_texture = s.albedo_texture
		m.transparency = s.transparency
	if billboard:
		# A card stood upright is seen almost edge-on from the board camera's
		# 68 degrees; turning it to face the camera is the only way it reads as
		# a cloud or a tree at all. Keep scale, or the billboard normalises away
		# the size each card was placed at.
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	return m

func _build_meadow() -> Node3D:
	var node := _instance("meadow")
	if node == null:
		return null
	node.scale = Vector3(SPREAD, 1.0, SPREAD)
	node.position = Vector3(0.0, _meadow_y, 0.0)
	for mi in _meshes(node):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var src := mi.mesh.surface_get_material(0)
		var name := src.resource_name if src != null else ""
		if name == "Grass_Blades":
			var sm := ShaderMaterial.new()
			sm.shader = GRASS_SHADER
			if src is StandardMaterial3D:
				sm.set_shader_parameter("albedo", (src as StandardMaterial3D).albedo_texture)
			mi.set_surface_override_material(0, sm)
			_roots = _root_positions(mi.mesh)
		else:
			mi.set_surface_override_material(0, _flat(src, false))
	add_child(node)
	return node

## Every vertex sitting at the foot of a blade, which is every vertex whose
## UV2.x is zero -- that channel is how far up its blade a vertex sits, baked in
## Blender for the wind shader. Read from UV2 rather than from vertex order,
## because the blades that would have stood underwater are deleted from the
## mesh and nothing guarantees what the survivors are numbered.
static func _root_positions(mesh: Mesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2 = arrays[Mesh.ARRAY_TEX_UV2]
	if uv2 == null:
		push_warning("Backdrop: the meadow has no UV2; re-export art/landscape.blend")
		return out
	for i in verts.size():
		if uv2[i].x <= 0.001:
			out.append(verts[i])
	return out

## Where the meadow's surface is at a point in the landscape's own space, from
## the nearest blade root. Returns NAN when there are no blades to ask.
func _ground_at(x: float, z: float) -> float:
	if _roots.is_empty() or meadow == null:
		return NAN
	var best := INF
	var y := NAN
	var sx := x / SPREAD
	var sz := z / SPREAD
	for r in _roots:
		var d := (r.x - sx) * (r.x - sx) + (r.z - sz) * (r.z - sz)
		if d < best:
			best = d
			y = r.y
	return _meadow_y + y

## Two tree clumps out on the bank, the way the painting has them. Kept beside
## the board rather than behind it: at this pitch anything much past the far
## bank projects off the top of the frame -- the first pair of spots tried sat
## at screen y of -92 to -341 and were never seen.
func _build_clumps() -> void:
	const SPOTS := [Vector3(-6.9, 0.0, -1.0), Vector3(6.6, 0.0, 4.5)]
	for i in SPOTS.size():
		var node := _instance("foliage")
		if node == null:
			return
		var at: Vector3 = SPOTS[i]
		var y := _ground_at(at.x, at.z)
		node.position = Vector3(at.x, (_meadow_y if is_nan(y) else y), at.z)
		node.scale = Vector3.ONE * (0.5 if i == 0 else 0.4)
		for mi in _meshes(node):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_surface_override_material(0, _flat(mi.mesh.surface_get_material(0), true))
		add_child(node)
		clumps.append(node)

## The blossom card scattered over the meadow as one MultiMesh, so a field of
## them costs one draw call. Every one is stood at a blade root, which is how
## it meets the rolling ground without a raycast.
func _build_blossoms() -> MultiMeshInstance3D:
	var sample := _instance("blossom")
	if sample == null or _roots.is_empty():
		if sample != null:
			sample.free()
		return null
	var meshes := _meshes(sample)
	if meshes.is_empty():
		sample.free()
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = meshes[0].mesh
	mm.instance_count = BLOSSOMS
	var stride := maxi(1, _roots.size() / BLOSSOMS)
	for i in BLOSSOMS:
		var r := _roots[(i * stride) % _roots.size()]
		var at := Vector3(r.x * SPREAD, _meadow_y + r.y, r.z * SPREAD)
		var yaw := fposmod(r.x * 12.9898 + r.z * 78.233, TAU)
		var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 1.6), at)
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Blossoms"
	mmi.multimesh = mm
	mmi.material_override = _flat(meshes[0].mesh.surface_get_material(0), false)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sample.free()
	add_child(mmi)
	return mmi
