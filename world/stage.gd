extends Node3D

## The island diorama every board floats in: camera rig, warm sun, blue sky,
## water far below, and the Ambient node that keeps the world moving. Boards
## find this through the "stage" group, mount their
## Node3D here, and bring their own stone platform.

const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const CameraRig = preload("res://world/camera_rig.gd")
const Ambient = preload("res://world/ambient.gd")

const WATER_DEPTH := 4.0
## The island's own camera pitch, the one a board gets unless it asks for
## another. Matches world/camera_rig.gd's export default.
const DEFAULT_PITCH := 68.0

var rig: Node3D
var sun: DirectionalLight3D
var anchor: Node3D
var water: Node3D
var ambient: Node3D

func _ready() -> void:
	add_to_group("stage")

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff1dc")
	# Calibrated against a lit STONE tile face in /tmp/shot_binairo.png: at 0.46
	# / 0.115 (4:1) it renders #fbe0b8 against the #ede2cc albedo, every channel
	# inside 12 percent and none clipping. The gl_compatibility pipeline is
	# brighter than the shader maths alone predicts, so these are measured, not
	# derived; re-measure if the sun colour or the ambient colour changes.
	sun.light_energy = 0.46
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
	env.ambient_light_energy = 0.115  # calibrated with sun.light_energy; see above
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

	ambient = Ambient.new()
	ambient.name = "Ambient"
	add_child(ambient)

func mount(board: Node3D) -> void:
	anchor.add_child(board)

func unmount(board: Node3D) -> void:
	if board.get_parent() == anchor:
		anchor.remove_child(board)

## Frames `aabb` in `rect`. `pitch` is the angle the board wants the camera
## held at, in degrees above the horizontal; NAN means the island's own. Most
## boards lie flat and read best from the default steep pitch, but a board
## whose pieces carry their meaning in their height -- Balance, whose beams
## tilt and whose discs stack -- needs the camera lower or that meaning
## projects to nothing. The rig keeps what it is given, so every board passes
## its own on every fit rather than relying on the last one to have put it
## back. `projection` is the same story for perspective against parallel:
## Pipes wants its blocks parallel, every other board wants depth. `yaw` is
## the exception -- NAN leaves the rig's own yaw where it is, which is what a
## board that turns needs, or every re-fit would undo the turn.
func fit_camera(aabb: AABB, rect: Rect2, pitch := NAN, projection := Camera3D.PROJECTION_PERSPECTIVE, yaw := NAN) -> void:
	rig.orthographic = projection == Camera3D.PROJECTION_ORTHOGONAL
	rig.pitch_deg = DEFAULT_PITCH if is_nan(pitch) else pitch
	if not is_nan(yaw):
		rig.yaw_deg = yaw
	rig.fit(aabb, rect)
	ambient.fit_to(aabb)

## Swings the view a quarter turn per step, so a board asks the stage rather
## than reaching into the rig. Returns the tween, or null off-tree.
func turn(steps: int) -> Tween:
	return rig.turn(steps)

## Rings the water under a board that has just landed.
func splash(origin: Vector3) -> void:
	ambient.splash(origin)
