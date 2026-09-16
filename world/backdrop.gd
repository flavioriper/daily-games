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

## The painting's sky, in frame for the first time. At 68 degrees the top of
## the view still pointed 53 degrees below the horizon and all eight corners of
## a cloud card projected between y = -1926 and y = -6746 on a 1920-tall frame,
## so none of this was worth its draw call. The camera sits at 7 degrees now
## (world/stage.gd), the horizon is about a third of the way down the frame,
## and the hills, the bank behind them and three cloud cards are what fills it.
const SKY_SHADER := preload("res://shaders/backdrop_sky.gdshader")
const CLOUD_SHADER := preload("res://shaders/backdrop_cloud.gdshader")
## How far out the hills ring stands and how big it is drawn. hills.glb is a
## 200x200 patch (its own local space) with a hole of local radius ~29 cut
## through its middle for the meadow to sit in. The meadow's own SPREAD (2.4)
## has nothing to do with this number -- it sizes a painted texture to the
## frame -- and copying it here put the hole's world radius at 29 * 2.4 = 70,
## a 44-unit gap of nothing past the meadow's own ~26-unit reach. A first guess
## of 0.75 (hole at 29 * 0.75 = ~22, just inside the meadow) turned out to sit
## entirely under the water once world/stage.gd's POND grew to 90 in this same
## task: the pond is centred on the same point as the hills and now reaches a
## 45-unit radius, so a 22-unit-radius ring was fully submerged and never broke
## the surface. 1.6 puts the hole at 29 * 1.6 = ~46, a hair past the pond's own
## rim, so the ring's inner (and tallest) lip rises right at the water's edge
## instead of under it. Confirmed on a rendered frame with the hills painted a
## flag colour so the thin band at the horizon was actually visible (see
## _build_hills's own comment for the colour decision), checked against
## Binairo, Horse Pen and Code Break.
const HILLS_SPREAD := 1.6
## The cloud bank: one card, wide enough to fill the frame's width at the
## distance it stands, and stood beyond the hills.
const BANK_SIZE := Vector2(400.0, 120.0)
const BANK_AT := Vector3(0.0, 8.0, -150.0)
## Three cloud cards between the hills and the bank. cloud.glb's card is
## modelled 56.3 units tall with its origin at the *bottom* edge, not the
## middle, so the source painting's own spread (-60 to 75 on X, scale 0.9-1.3,
## the card's foot at y = 14-22) put almost the whole card above the top of
## the frame: a rendered Binairo frame showed the foot barely inside frame and
## the card's own middle already unprojecting to screen_y < 0. Narrowed on X
## to what actually projects inside the frame width on Binairo (the closest
## camera and so the tightest fit -- a farther board like Horse Pen only pulls
## them further toward the centre, never out), and scaled down and lowered so
## the whole 56.3-unit card -- foot to crown -- lands between the HUD's lower
## edge and the horizon rather than mostly above the top of frame. Checked on
## Binairo, Horse Pen and Code Break together.
const CLOUD_SPOTS := [
	Vector3(-15.0, 10.0, -90.0),
	Vector3(8.0, 11.0, -100.0),
	Vector3(22.0, 9.0, -85.0),
]
const CLOUD_SCALES := [0.2, 0.24, 0.18]

var meadow: Node3D
var hills: Node3D
var sky: MeshInstance3D
var clouds: Array[Node3D] = []
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
	hills = _build_hills()
	sky = _build_sky()
	_build_clouds()

## Nothing to do: every moving thing in the landscape -- the grass, the three
## cloud cards and the bank behind them -- reads the motion_scale shader global
## that world/ambient.gd owns. Kept so the settings sheet can call it without
## knowing that, and so a later moving piece has somewhere to go.
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

## The far roll of the source terrain, standing outside the meadow so the sky
## has a silhouette to sit behind rather than meeting flat ground. Washed
## toward the sky's own horizon colour with distance: depth through colour, not
## fog (docs/art/shading-direction.md).
##
## Wears a flat colour, not hills_test_1.jpg: that file is a byte-identical
## copy of meadow_test_1.jpg (Godot extracts a texture per .glb, so the same
## painted card came out twice), and on a rendered frame it looked wrong
## regardless -- multiplying the meadow's own green-and-brown paint by a pale
## tint still reads as more meadow at this distance, not a washed-out
## silhouette. hills.glb's own import (gltf/embedded_image_handling=0) no
## longer extracts that texture at all, so the duplicate is gone rather than
## merely unused.
func _build_hills() -> Node3D:
	var node := _instance("hills")
	if node == null:
		return null
	node.scale = Vector3(HILLS_SPREAD, 1.0, HILLS_SPREAD)
	# _meadow_y is the meadow's own lowest point; hills.glb was zeroed on its
	# own separate lowest point in art/landscape.blend, so the two are not
	# guaranteed to meet at the same height. They read as one continuous rise
	# at _meadow_y, checked on Binairo, Horse Pen and Code Break together, so
	# this is kept rather than given its own tuned constant.
	node.position = Vector3(0.0, _meadow_y, 0.0)
	for mi in _meshes(node):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := _flat(mi.mesh.surface_get_material(0), false)
		# No texture survives the import now, but _flat() would carry one
		# across if the source ever grew one back; null it explicitly so the
		# hills always read as colour, never as a second meadow.
		m.albedo_texture = null
		# Lighter and cooler than the near meadow, so distance reads as colour.
		m.albedo_color = Color(0.86, 0.92, 0.95)
		mi.set_surface_override_material(0, m)
	add_child(node)
	return node

## One wide card of procedural cloud bank behind the hills.
func _build_sky() -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = BANK_SIZE
	var mi := MeshInstance3D.new()
	mi.name = "CloudBank"
	mi.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = SKY_SHADER
	mi.set_surface_override_material(0, sm)
	mi.position = BANK_AT
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## The painting's three cloud cards, drifting on the motion_scale global.
func _build_clouds() -> void:
	for i in CLOUD_SPOTS.size():
		var node := _instance("cloud")
		if node == null:
			return
		node.position = CLOUD_SPOTS[i]
		node.scale = Vector3.ONE * float(CLOUD_SCALES[i])
		for mi in _meshes(node):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var src := mi.mesh.surface_get_material(0)
			var sm := ShaderMaterial.new()
			sm.shader = CLOUD_SHADER
			if src is StandardMaterial3D:
				sm.set_shader_parameter("albedo", (src as StandardMaterial3D).albedo_texture)
			sm.set_shader_parameter("drift_speed", 0.04 + 0.02 * float(i))
			mi.set_surface_override_material(0, sm)
		add_child(node)
		clouds.append(node)
