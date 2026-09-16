extends Node3D

## The island diorama every board floats in: camera rig, warm sun, blue sky,
## water far below, and the Ambient node that keeps the world moving. Boards
## find this through the "stage" group, mount their
## Node3D here, and bring their own stone platform.

const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Toon = preload("res://core/toon.gd")
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
## The pond's width in world units. It was 30 when the pond sat in a basin
## under a board seen from 68 degrees and only had to fill that basin. At 7
## degrees the water runs from the near bank toward the hills, so it grew --
## but not all the way to them. A first pass grew it to 90 (radius 45), which
## reached past world/backdrop.gd's HILLS_SPREAD-scaled ring entirely and
## drowned the ring's near edge, squeezing the whole visible hills band down
## to a measured 20px on a rendered frame. 48 (radius 24) sits just inside the
## ring's own near edge (HILLS_SPREAD 0.9 puts that at ~26) instead of past
## it, which is what actually let the hills band grow on a rendered frame.
## What the player reads as the near edge is still the meadow's basin rising
## out of it, not this plane's rim. The pond is also what keeps Ambient.splash
## alive -- the ring is drawn by the shared water material.
const POND := 48.0
## The placeholder water plane is modelled this big (core/placeholders.gd), so
## a pond is a fraction of it.
const WATER_PLANE := 60.0
## What stands behind a board once show_setting has taken the setting away:
## the HUD's own paper, so the screen in game is the board, its chrome and
## nothing else.
const FLAT_BG := Pal.PAPER

var rig: Node3D
var sun: DirectionalLight3D
var anchor: Node3D
var water: Node3D
var ambient: Node3D
var backdrop: Node3D
## The stage's own Environment, kept so show_setting can swap the sky behind a
## board for flat colour.
var env: Environment
## The face angle the last fit used, so a turn can re-lean where it lands.
var _face := DEFAULT_FACE
## The board-local box and rect the last fit used. Kept local rather than the
## world box that fit actually used: a turn changes the lean, and only the
## local box survives a change of lean -- the world box would still be the
## shape the old lean produced.
var _last_local_aabb := AABB()
var _last_rect := Rect2()

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
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Only in view when show_setting has taken the sky away; the sky material
	# is left in place so putting it back is one enum.
	env.background_color = FLAT_BG
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
	# So the depth gradient spans the new pond rather than a third of it.
	var wm := Toon.water()
	if wm != null:
		wm.set_shader_parameter("pond_radius", POND * 0.5)

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

## Shows or hides the whole setting a mounted thing stands in: the painted
## landscape (world/backdrop.gd), the pond, the sky behind them, and the motes
## in the air. On is the menu campsite; off is a board, which for now floats
## against FLAT_BG with nothing else on screen but itself and the HUD. Whoever
## mounts says which it wants.
##
## Nothing is torn down and nothing stops being fitted -- the backdrop is only
## hidden and is still re-centred on every fit -- so bringing the island back
## behind the boards is this one flag rather than a rebuild. The sun and the
## ambient light are untouched: they are a measured pair (see above) and the
## light never came from the sky anyway (AMBIENT_SOURCE_COLOR), so a board is
## lit identically with the setting gone.
func show_setting(on: bool) -> void:
	if backdrop != null:
		backdrop.visible = on
	if water != null:
		water.visible = on
	if env != null:
		env.background_mode = Environment.BG_SKY if on else Environment.BG_COLOR
	if ambient != null:
		ambient.show_pollen(on)

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
	anchor.transform.basis = Basis(right.normalized(), deg_to_rad(face - rig.pitch_deg))

## The world box a fit or a re-fit should use for `local` -- the board's own
## box -- under whichever lean is currently in effect. Perspective needs only
## the box the current lean produces, so this is exactly `anchor.transform *
## local`. Orthographic needs more: `_fit_ortho` takes the size that fits the
## worst of the four quarter stops so the board reads as one constant size
## across a turn, and that guarantee only holds if the box it measures is the
## same at every stop. A leaning board's box is not -- each stop leans about a
## different horizontal axis -- so this unions the box across all four
## instead of handing over just the one the board happens to be standing on.
## The union is identical no matter which stop it is taken from, since
## stepping by 90 degrees four times maps the set of stops onto itself; the
## cost is a fit a little looser than the tightest possible one, which is the
## trade worth making so the board does not swell and shrink as it turns.
func _fit_box(local: AABB) -> AABB:
	if not rig.orthographic:
		return anchor.transform * local
	var tilt := deg_to_rad(_face - rig.pitch_deg)
	var box := AABB()
	for k in 4:
		var right: Vector3 = rig.right_at(rig.yaw_deg + 90.0 * k)
		var world := Transform3D(Basis(right, tilt), anchor.transform.origin) * local
		box = world if k == 0 else box.merge(world)
	return box

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
## `pitch` is the camera's own, CAMERA_PITCH for every board. The menu is the
## one caller that asks for another: it frames the campsite in the top of the
## screen, and at 7 degrees the only way to hold a box that high in the frame
## is to aim under it, which puts the camera below the ground. Its camp does
## not lean either way -- it passes the same pitch as its face.
func fit_camera(aabb: AABB, rect: Rect2, face := NAN, projection := Camera3D.PROJECTION_PERSPECTIVE, yaw := NAN, pitch := CAMERA_PITCH) -> void:
	rig.orthographic = projection == Camera3D.PROJECTION_ORTHOGONAL
	rig.pitch_deg = pitch
	if not is_nan(yaw):
		rig.yaw_deg = yaw
	# Before the box is measured: the lean is what puts the board where the
	# rig has to frame it.
	_lean(DEFAULT_FACE if is_nan(face) else face)
	# Kept board-local so a later turn can re-derive the world box under
	# whatever lean it re-takes; see _last_local_aabb.
	_last_local_aabb = aabb
	_last_rect = rect
	var world := _fit_box(aabb)
	rig.fit(world, rect)
	ambient.fit_to(world)
	_fit_ground(world)

## Sits the pond and the landscape under the board being framed, so a board
## mounted off the origin still lands in the middle of the basin.
func _fit_ground(aabb: AABB) -> void:
	var c := aabb.get_center()
	water.position = Vector3(c.x, -WATER_DEPTH, c.z)
	water.scale = Vector3(POND / WATER_PLANE, 1.0, POND / WATER_PLANE)
	# The depth gradient is centred on pond_center, not the world origin, so it
	# has to follow the pond every time a board's fit re-centres it.
	var wm := Toon.water()
	if wm != null:
		wm.set_shader_parameter("pond_center", water.position)
	backdrop.fit_to(aabb, rig.yaw_deg)

## Swings the view a quarter turn per step, so a board asks the stage rather
## than reaching into the rig. CameraRig.turn only swings the yaw and re-
## places the camera; it does not re-fit, because a turn changes the lean and
## only Stage knows the lean and the board-local box it acts on. So this
## re-leans first, at the yaw the turn landed on, and only then re-fits from
## a world box freshly taken through that lean -- re-fitting from the box the
## old lean produced (or before re-leaning at all) would frame a shape the
## board is no longer showing. A turn also changes rig.yaw_deg, which
## backdrop.fit_to reads to keep the hills ring's rolling wedge facing the
## camera, so this re-runs that too rather than leaving the ring at whatever
## way it faced before the turn. Returns the tween, or null off-tree.
func turn(steps: int) -> Tween:
	var tw: Tween = rig.turn(steps)
	if tw != null:
		tw.tween_callback(func() -> void:
			_lean(_face)
			var world := _fit_box(_last_local_aabb)
			rig.fit(world, _last_rect)
			backdrop.fit_to(world, rig.yaw_deg))
	return tw

## Rings the water under a board that has just landed.
func splash(origin: Vector3) -> void:
	ambient.splash(origin)
