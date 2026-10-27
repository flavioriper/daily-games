extends SubViewportContainer

## The real Peeplet from ~/dev/peeplet on a 2D screen: its own walker
## (peeplet/peeplet_walker.gd), fur chain, eyes and glb, its twelve coats
## (PeepletPalette), its twenty hats and thirteen eyewear pieces (items/),
## copied from game/adventure at 401c5557, posed in a small 3D world of its
## own and shown here as a flat picture through a transparent SubViewport.
## This is the one place daily loads a model since 2026-09-24, on the user's
## word (2026-10-23: "get the peeplet gd and use it here as a 2d"), after a
## hand-drawn port was turned down. Daily's copies are restyled to the house's
## drawn characters: no ink line, a soft warm shade, cheeks, dot eyes
## (peeplet/soft_cel.gdshaderinc, world/toon_prop*.gdshader).
##
## Drive the walker straight through `walker`: walking, running, sitting,
## grieving, set_comfort(), trigger_laugh(), trigger_pick(), trigger_snack(),
## trigger_dig(), trigger_water(), trigger_chop(). A new coat, hat or eyewear
## builds a fresh walker, as the peeplet lab does.

## Degrees above the horizon. The peeplet lab opens at 18; the RPG camera's
## top down is 55.
@export var pitch := 18.0:
	set(v):
		pitch = v
		_aim()
## Turns the peeplet about its own up, in degrees; 0 faces the camera.
@export var turn := 0.0:
	set(v):
		turn = v
		if walker != null:
			walker.rotation.y = deg_to_rad(v)
		_since = INF
## Metres of the world the picture is tall; a peeplet stands 0.6.
@export var frame_height := 0.8:
	set(v):
		frame_height = v
		_aim()
## Metres above the peeplet's feet the camera looks at; the peeplet lab's
## 0.3 is its middle, higher leaves room above for a tall hat.
@export var aim_y := 0.3:
	set(v):
		aim_y = v
		_aim()
## One of PeepletPalette.BODY, by index: eight flat coats and four painted
## ones (candy, midnight, ocean, cloud).
@export var color_index := 0:
	set(v):
		color_index = v
		if not _dressing:
			_rebuild()
## A HeadgearItemFactory.kinds() name ("crown", "wizardHat"), or "" for none.
@export var headgear := "":
	set(v):
		headgear = v
		if not _dressing:
			_rebuild()
## An EyewearItemFactory.kinds() name ("roundGlasses", "visor"), or "".
@export var eyewear := "":
	set(v):
		eyewear = v
		if not _dressing:
			_rebuild()

## True while `dress` sets the three wear fields, so their setters hold off
## the rebuild and it happens once at the end.
var _dressing := false

## The coat, hat and eyewear in one go, rebuilding the walker once instead
## of once a setter (core/cast.gd dresses every seat this way; a re-dress in
## the tree would otherwise rebuild three times). Unchanged wear rebuilds
## nothing.
func dress(coat: int, hat: String, eyes: String) -> void:
	if color_index == coat and headgear == hat and eyewear == eyes:
		return
	_dressing = true
	color_index = coat
	headgear = hat
	eyewear = eyes
	_dressing = false
	_rebuild()

## Sat down, held: the walker sits and the pose is settled at once, so a
## portrait that never runs (idle_fps 0) still shows the sit, and a rebuilt
## walker (a new coat, hat or eyewear) sits again.
@export var seated := false:
	set(v):
		seated = v
		_pose()

## Frames a second the 3D picture is redrawn at while the peeplet acts
## (walks, picks, laughs) and while it only breathes. Between redraws the
## last frame stays up, a single 2D draw; off screen or hidden it is not
## drawn at all, and at the game's rest (core/power.gd) it holds still. An
## idle_fps of 0 holds the frame while it only breathes: a still portrait,
## redrawn when it acts, is rebuilt, re-aimed or shown again.
@export var busy_fps := 30.0
@export var idle_fps := 15.0

var walker: PeepletWalker
var _viewport: SubViewport
var _camera: Camera3D
## core/power.gd stops whatever has `_idle` true at rest, through set_idle().
var _idle := true
var _since := INF
var _was_busy := false

## The fur's toon band is cut against this uniform, not a light node: the
## peeplet lab's noon sun (world_lighting.sun_toward_direction() at LAB_HOUR
## 12, read off the running lab 2026-10-23). The hats and eyewear are lit
## materials, so a real light stands along it too.
const SUN := Vector3(-0.449114, 0.821149, 0.352151)
## peeplet.glb's face surfaces (PeepletFur): 1/5 the eye rims, 2/6 the
## irises, 3/7 their lower lights, 4/8 the glints.
const EYE_DARK_SURFACES := [1, 2, 3, 5, 6, 7]
const EYE_GLINT_SURFACES := [4, 8]
const EYE_INK := Color("2e211c")
## The peeplet lab's opening camera: perspective, 2.6 m out.
const DISTANCE := 2.6

func _init() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_IGNORE
	# The fur shells blend into a transparent target, which leaves its colour
	# premultiplied; laid over the page straight, every soft shell edge reads
	# grey.
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = blend
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	# The walker carries a bare capsule on layer 11 for the river's contact
	# camera; the game's own camera never sees that layer, and neither does
	# this one.
	_camera.cull_mask = 0xFFFFF & ~(1 << 10)
	_viewport.add_child(_camera)
	# One white sun of energy 1 and no ambient: the props' light() writes the
	# whole of their light from it (world/toon_prop.gdshader). The coat is
	# unshaded and takes neither.
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(-SUN, Vector3.UP), Vector3.ZERO)
	sun.light_energy = 1.0
	_viewport.add_child(sun)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

func _ready() -> void:
	_rebuild()
	_aim()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if walker != null:
		walker.queue_free()
	walker = PeepletWalker.create(PeepletPalette.color(color_index),
		PeepletPalette.premium_mode(color_index))
	walker.rotation.y = deg_to_rad(turn)
	_viewport.add_child(walker)
	PeepletFur.set_chain_parameter(walker.chains, "light_direction", SUN)
	# The glb's own small eyes go ink-dark; the cartoon eyes sit over them.
	for surface in EYE_DARK_SURFACES:
		walker.body_mesh.set_surface_override_material(surface, PeepletFur.flat_color_material(EYE_INK))
	for surface in EYE_GLINT_SURFACES:
		walker.body_mesh.set_surface_override_material(surface, PeepletFur.flat_color_material(Color.WHITE))
	if headgear != "":
		walker.attach_headgear(HeadgearItemFactory.create_headgear(headgear))
	if eyewear != "":
		walker.attach_eyewear(EyewearItemFactory.create_eyewear(eyewear))
	# The nine face surfaces, flat colours now, as one (PeepletBatch).
	PeepletBatch.merge_face(walker.body_mesh, 1)
	walker.body_mesh.add_child(cartoon_eyes())
	walker.process_mode = PROCESS_MODE_INHERIT if _idle else PROCESS_MODE_DISABLED
	# posed once now: a held portrait's walker may never run, and an unposed
	# walker stands in its rig's rest, arms straight out
	walker.advance(1.0 / 60.0)
	_pose()
	_since = INF

## The sit, eased in by hand: a held portrait's walker is not processed, so
## the pose is walked to its end here, a tenth of a second at a time, and the
## picture is redrawn. A walker already acting is left to ease itself.
func _pose() -> void:
	if walker == null:
		return
	walker.set_sitting(seated)
	if _busy():
		return
	var steps := 0
	while steps < 24 and absf(walker.sit_amount - (1.0 if seated else 0.0)) > 0.002:
		walker.advance(0.1)
		steps += 1
	_since = INF

## daily (2026-10-23, the cartoon pass, after Duolingo's owl): the eyes a
## drawn mascot has, two white ovals with a big dark pupil and one glint,
## over the glb's own small eyes (ink-dark under them). Six balls welded
## into one mesh with the colour in its vertices: one draw for both eyes.
## Positions in glb object space (the glb eyes sit at x 0.245, y 0.325).
const EYE_AT := Vector3(0.245, 0.335, 0.47)
const EYE_SCALE := 1.3
const EYE_WHITE_R := 0.135
const EYE_PUPIL_R := 0.095
const EYE_GLINT_R := 0.028

static func cartoon_eyes() -> MeshInstance3D:
	var parts := []
	for side in [-1.0, 1.0]:
		var at := Vector3(EYE_AT.x * side, EYE_AT.y, EYE_AT.z)
		parts.append(_ball(EYE_WHITE_R * EYE_SCALE, at, Vector3(1.0, 1.15, 0.55), Color.WHITE))
		var pupil_at := at + Vector3(0.012 * side, -0.012, 0.07 * EYE_SCALE)
		parts.append(_ball(EYE_PUPIL_R * EYE_SCALE, pupil_at, Vector3(1.0, 1.2, 0.5), EYE_INK))
		parts.append(_ball(EYE_GLINT_R * EYE_SCALE,
			pupil_at + Vector3(-0.03, 0.035, 0.045) * EYE_SCALE, Vector3.ONE, Color.WHITE))
	var eyes := MeshInstance3D.new()
	eyes.name = "CartoonEyes"
	eyes.mesh = ArrayMesh.new()
	eyes.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, PeepletBatch._weld(parts))
	eyes.set_surface_override_material(0, PeepletBatch._flat_vertex_material())
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return eyes

static func _ball(radius: float, at: Vector3, stretch: Vector3, color: Color) -> Array:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	return [sphere.get_mesh_arrays(), Transform3D(Basis.from_scale(stretch), at), color]

func _aim() -> void:
	if _camera == null:
		return
	var p := deg_to_rad(pitch)
	_camera.fov = rad_to_deg(2.0 * atan(frame_height * 0.5 / DISTANCE))
	var target := Vector3(0.0, aim_y, 0.0)
	var eye := target + Vector3(0.0, sin(p), cos(p)) * DISTANCE
	_camera.transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	_since = INF

func _process(delta: float) -> void:
	if walker == null or not _idle:
		return
	_since += delta
	var busy := _busy()
	# a held portrait's walker sleeps too; a trigger wakes it through _busy()
	walker.set_process(busy or idle_fps > 0.0)
	if not is_visible_in_tree() or not get_viewport_rect().intersects(get_global_rect()):
		return
	var fps := busy_fps if busy else idle_fps
	# an action's last pose is drawn too, or a held portrait keeps it
	var due := _since >= (1.0 / fps if fps > 0.0 else INF) or (_was_busy and not busy)
	_was_busy = busy
	if due:
		_since = 0.0
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## Shown again: the container hands its viewport back to always-update, so
## take it back to one frame now.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_since = INF

func _busy() -> bool:
	return walker.walking or walker.pick_time >= 0.0 or walker.snack_time >= 0.0 \
		or walker.laugh_time >= 0.0 or walker.chop_time >= 0.0 or walker.grab_time >= 0.0

## At the game's rest the peeplet holds where it is: the walker stops and the
## picture keeps its last frame.
func set_idle(on: bool) -> void:
	_idle = on
	if walker != null:
		walker.process_mode = PROCESS_MODE_INHERIT if on else PROCESS_MODE_DISABLED
	_since = INF
