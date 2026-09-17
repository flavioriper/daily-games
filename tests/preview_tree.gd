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
const Stage = preload("res://world/stage.gd")
const SoftFocus = preload("res://world/soft_focus.gd")
const Ambient = preload("res://world/ambient.gd")

## Where the camera stands and what it holds in the middle of the frame, in
## the camp's ground plane: aimed at Camp.HERO_CENTRE, the spot the menu's
## shift lens aims at too, from the camp's own pitch and yaw (Camp.VIEW_*)
## and far enough back that the frame holds Camp.HERO_SIZE at that plane the
## way the menu's fit does: the rig keeps 6 percent of the strip's short side
## clear on each side (CameraRig.margin), which at the strip's shape comes to
## about a tenth more width than the box itself. The vertical field is the
## menu's horizontal one taken across 16:9.
const FIT_SLACK := 1.1
const CAM_PITCH := Camp.VIEW_PITCH
const CAM_YAW := Camp.VIEW_YAW
const CAM_FOV := rad_to_deg(2.0 * atan(tan(deg_to_rad(Camp.VIEW_FOV * 0.5)) * 9.0 / 16.0))
const CAM_LOOK := Camp.HERO_CENTRE
const CAM_AT := CAM_LOOK + Vector3(
		sin(deg_to_rad(CAM_YAW)) * cos(deg_to_rad(CAM_PITCH)),
		sin(deg_to_rad(CAM_PITCH)),
		cos(deg_to_rad(CAM_YAW)) * cos(deg_to_rad(CAM_PITCH))) \
	* (Camp.HERO_SIZE.x * FIT_SLACK * 0.5 / tan(deg_to_rad(Camp.VIEW_FOV * 0.5)))

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
	# The campsite's grade over the board's pair, exactly as the menu sets it.
	Stage.grade_camp(sun, env)
	# And its weather: the menu turns this on through Stage.show_setting, which
	# this preview does not go through, so the editor would otherwise show a
	# still camp (world/ambient.gd, WIND_GLOBAL).
	Ambient.set_wind_global(true)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = CAM_FOV
	cam.current = true
	add_child(cam)
	cam.look_at_from_position(CAM_AT, CAM_LOOK, Vector3.UP)
	# The campsite's soft focus, focused where the menu focuses it: on the
	# scout's plane. In the editor it hangs off whichever camera is drawing,
	# so the blur there follows the editor camera's own distance.
	var focus := SoftFocus.new()
	cam.add_child(focus)
	focus.focus(CAM_AT.distance_to(CAM_LOOK))
	focus.visible = true
