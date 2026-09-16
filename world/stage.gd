extends Node3D

## The island diorama every board floats in: camera rig, warm sun, blue sky,
## water far below, and the Ambient node that keeps the world moving. Boards
## find this through the "stage" group, mount their
## Node3D here, and bring their own stone platform.

const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const CameraRig = preload("res://world/camera_rig.gd")
const Ambient = preload("res://world/ambient.gd")
const Backdrop = preload("res://world/backdrop.gd")

const WATER_DEPTH := 4.0
## The camera's own pitch, in degrees above the horizontal, and the only one
## any board gets. The frame spans pitch - fov/2 to pitch + fov/2 below the
## horizontal, so the horizon sits about 0.5 - pitch/fov down it: at 7 against
## the rig's 40 degree field, a third of the way down. Distance cannot move it
## -- CameraRig.fit only slides along the view direction -- which is why Pipes
## at 35 degrees still showed nothing but meadow to every edge.
const CAMERA_PITCH := 7.0
## The angle a board's face is seen at unless it asks for another. The board
## leans to meet the camera rather than the camera moving to meet the board,
## which is what keeps every piece in core/placeholders.gd readable: the face
## angle here is the pitch the pieces were cut for.
const DEFAULT_FACE := 68.0
## The water was one 60 by 60 sheet filling the whole frame, which is what the
## camera saw behind every board. The landscape fills that now and the water is
## cut back to the pond in the middle of it. What the player sees as the pond's
## edge is the meadow's basin rising out of the water, not this plane's rim, so
## the plane only has to be wide enough to fill the basin and narrow enough that
## its corners stay under ground that is above the water line. It is a fixed
## size for that reason rather than sized off the board: it is the terrain's
## pond, not the board's. The pond is also what keeps Ambient.splash alive --
## the ring is drawn by the shared water material.
const POND := 30.0
## The placeholder water plane is modelled this big (core/placeholders.gd), so
## a pond is a fraction of it.
const WATER_PLANE := 60.0

var rig: Node3D
var sun: DirectionalLight3D
var anchor: Node3D
var water: Node3D
var ambient: Node3D
var backdrop: Node3D
## The face angle the last fit used, so a turn can re-lean where it lands.
var _face := DEFAULT_FACE

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

	# The landscape goes down before the water, so the pond draws over it.
	backdrop = Backdrop.new()
	backdrop.name = "Backdrop"
	# Before add_child: the meadow is sunk on _ready so its basin's water line
	# meets the pond, and it needs to know how deep the pond is to do that.
	backdrop.water_depth = WATER_DEPTH
	add_child(backdrop)

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

## Leans the board anchor toward the camera until the board's face is seen at
## `face` degrees above the horizontal. The axis is the camera's own right, so
## the board keeps facing the player at all four yaw stops rather than leaning
## off to one side at three of them; rotating that way raises the board's far
## edge, which is what brings its face around to the camera.
func _lean(face: float) -> void:
	_face = face
	var right := Vector3.UP.cross(rig.view_offset_dir())
	if right.length_squared() < 1e-6:
		right = Vector3.RIGHT
	anchor.transform.basis = Basis(right.normalized(), deg_to_rad(face - CAMERA_PITCH))

## Frames `aabb` -- the board's own, board-local box -- in `rect`. `face` is
## the angle the board's face wants to be seen at, in degrees above the
## horizontal; NAN means the island's own. The camera no longer moves to find
## that angle: it stays at CAMERA_PITCH so the landscape reads the same behind
## every board, and the board leans to meet it. A board whose pieces mean
## something by their height asks for a shallower face and leans less --
## Balance, whose beams tilt and whose discs stack. `projection` is the same
## story for perspective against parallel: Pipes wants its blocks parallel,
## every other board wants depth. `yaw` is the exception -- NAN leaves the
## rig's own yaw where it is, which is what a board that turns needs, or every
## re-fit would undo the turn.
func fit_camera(aabb: AABB, rect: Rect2, face := NAN, projection := Camera3D.PROJECTION_PERSPECTIVE, yaw := NAN) -> void:
	rig.orthographic = projection == Camera3D.PROJECTION_ORTHOGONAL
	rig.pitch_deg = CAMERA_PITCH
	if not is_nan(yaw):
		rig.yaw_deg = yaw
	# Before the box is measured: the lean is what puts the board where the
	# rig has to frame it.
	_lean(DEFAULT_FACE if is_nan(face) else face)
	var world := anchor.transform * aabb
	rig.fit(world, rect)
	ambient.fit_to(world)
	_fit_ground(world)

## Sits the pond and the landscape under the board being framed, so a board
## mounted off the origin still lands in the middle of the basin.
func _fit_ground(aabb: AABB) -> void:
	var c := aabb.get_center()
	water.position = Vector3(c.x, -WATER_DEPTH, c.z)
	water.scale = Vector3(POND / WATER_PLANE, 1.0, POND / WATER_PLANE)
	backdrop.fit_to(aabb)

## Swings the view a quarter turn per step, so a board asks the stage rather
## than reaching into the rig. The lean is measured from the camera's right,
## so it has to be re-taken where the turn lands. Returns the tween, or null
## off-tree.
func turn(steps: int) -> Tween:
	var tw: Tween = rig.turn(steps)
	if tw != null:
		tw.tween_callback(func() -> void: _lean(_face))
	return tw

## Rings the water under a board that has just landed.
func splash(origin: Vector3) -> void:
	ambient.splash(origin)
