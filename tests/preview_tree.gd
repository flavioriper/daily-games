@tool
extends Node3D

## The first screen's campsite, staged as a scene to look at: world/camp.gd
## itself, the very node the menu mounts, under a fixed camera that frames it
## the way the concept banner does. Nothing is composed here any more -- the
## camp owns its staging -- so what this shows is what the game draws, and a
## prop moved here is a prop moved on the first screen.
##
## The light rig is world/stage.gd's own: the sun from behind-right at 0.46
## over 0.115 ambient. A preview lit any other way is a picture of a scene the
## game cannot draw.
##
## @tool, so the editor shows the camp live. The camp stands at Camp.LIFT
## over its own origin; the pivot below cancels that so the camera constants
## stay in the camp's ground plane.
##
##     godot --path . --resolution 1280x720 --script res://tests/_shot_scene.gd \
##         -- res://tests/preview_tree.tscn

const Pal = preload("res://core/palette.gd")
const Camp = preload("res://world/camp.gd")

## Where the camera stands and what it holds in the middle of the frame, in
## the camp's ground plane: aimed at Camp.HERO_CENTRE, the spot the menu's
## shift lens aims at too, from 12 degrees up and far enough back that the
## frame is Camp.HERO_SIZE wide at that plane. 32 degrees vertical at 16:9 is
## 54 across, the menu's field.
const CAM_PITCH := 12.0
const CAM_FOV := 32.0
const CAM_LOOK := Camp.HERO_CENTRE
const CAM_AT := CAM_LOOK + Vector3(0.0, sin(deg_to_rad(CAM_PITCH)), cos(deg_to_rad(CAM_PITCH))) \
	* (Camp.HERO_SIZE.x * 0.5 / tan(deg_to_rad(27.0)))

@export var day := 2
@export var island := "Birch Haven"

var camp: Node3D

func _ready() -> void:
	for child in get_children():
		child.queue_free()
	_build_light()
	_build_camera()
	var pivot := Node3D.new()
	pivot.name = "Ground"
	pivot.position = Vector3(0.0, -Camp.LIFT, 0.0)
	add_child(pivot)
	camp = Camp.new()
	pivot.add_child(camp)
	camp.set_day(day, island)

# --- the rig ---

func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff1dc")
	sun.light_energy = 0.46
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	sun.look_at_from_position(Vector3(3.0, 8.0, -6.0), Vector3.ZERO, Vector3.UP)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Pal.SKY_TOP
	sky_mat.sky_horizon_color = Pal.SKY_HORIZON
	sky_mat.ground_horizon_color = Pal.SKY_HORIZON
	# The valley's far haze rather than the island's sea: below the horizon
	# this preview looks at distant bank, not open water.
	sky_mat.ground_bottom_color = Pal.SKY_HORIZON
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Pal.AMBIENT
	env.ambient_light_energy = 0.115
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	var world_env := WorldEnvironment.new()
	world_env.name = "Env"
	world_env.environment = env
	add_child(world_env)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = CAM_FOV
	cam.current = true
	add_child(cam)
	cam.look_at_from_position(CAM_AT, CAM_LOOK, Vector3.UP)
