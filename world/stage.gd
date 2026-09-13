extends Node3D

## The island diorama every board floats in: camera rig, warm sun, blue sky,
## water far below. Boards find this through the "stage" group, mount their
## Node3D here, and bring their own stone platform.

const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const CameraRig = preload("res://world/camera_rig.gd")

const WATER_DEPTH := 4.0

var rig: Node3D
var sun: DirectionalLight3D
var anchor: Node3D
var water: Node3D

func _ready() -> void:
	add_to_group("stage")

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	# From behind-right and above, so shadows fall toward the player and left.
	sun.look_at_from_position(Vector3(3.0, 8.0, -6.0), Vector3.ZERO, Vector3.UP)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Pal.SKY_TOP
	sky_mat.sky_horizon_color = Pal.SKY_HORIZON
	sky_mat.ground_horizon_color = Pal.SKY_HORIZON
	sky_mat.ground_bottom_color = Pal.WATER
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Pal.AMBIENT
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	var world_env := WorldEnvironment.new()
	world_env.name = "Env"
	world_env.environment = env
	add_child(world_env)

	water = Models.instance("water")
	water.name = "Water"
	water.position = Vector3(0.0, -WATER_DEPTH, 0.0)
	add_child(water)

	anchor = Node3D.new()
	anchor.name = "BoardAnchor"
	add_child(anchor)

func mount(board: Node3D) -> void:
	anchor.add_child(board)

func unmount(board: Node3D) -> void:
	if board.get_parent() == anchor:
		anchor.remove_child(board)

func fit_camera(aabb: AABB, rect: Rect2) -> void:
	rig.fit(aabb, rect)
