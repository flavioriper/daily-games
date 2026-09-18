extends SubViewportContainer

## A model in the HUD as the model it is: a SubViewport with its own World3D,
## the stage's calibrated sun and ambient, and an orthographic camera framed
## on a box. The title sign, the menu's title letters and the puzzle cards'
## dioramas all stand in one of these, so nothing in the chrome is ever a
## picture of a model (CLAUDE.md: a model ships as a model).
##
## Drawn on demand, not every frame. Over a dozen of these live at once on the
## menu and nothing in them moves: left on UPDATE_WHEN_VISIBLE, thirteen signs
## cost 18.6 ms of process time against this project's ~5 ms idle baseline.
## Every change calls redraw() -- new words, a new size -- so this is render
## caching, not a baked asset: the geometry is still here and still lit.

const Pal = preload("res://core/palette.gd")

## Lit exactly as world/stage.gd lights the game: its 0.46 / 0.115 sun-to-
## ambient pair is measured against a rendered frame, not derived, because the
## gl_compatibility pipeline comes out brighter than the shader maths predicts.
## At anything near the obvious values a plank blows out to pale pine and the
## leaves go yellow.
const SUN_ENERGY := 0.46
const AMBIENT_ENERGY := 0.115

var view: SubViewport
var cam: Camera3D
var sun: DirectionalLight3D
var _box := AABB()
var _dir := Vector3(0.0, 0.0, 1.0)
var _margin := 1.1
var _framed := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	custom_minimum_size = Vector2.ZERO
	view = SubViewport.new()
	# Its own world: the game's stage light and sky must not reach in here,
	# and this one's light must not reach out.
	view.own_world_3d = true
	view.world_3d = World3D.new()
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(view)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Pal.AMBIENT
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	view.world_3d.environment = env

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.01
	cam.far = 60.0
	view.add_child(cam)

	sun = DirectionalLight3D.new()
	sun.light_energy = SUN_ENERGY
	sun.light_color = Color("fff1dc")
	sun.shadow_enabled = true
	# The lettering's shadow on a plank is what gives carving its depth, and it
	# is a real shadow here rather than a painted one.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	view.add_child(sun)
	# From the front, upper left, as the signs have always been lit: the
	# stage's own sun sits behind a board and would leave it lit only by
	# ambient. Subclasses may re-aim it.
	light_from(Vector3(-2.0, 3.0, 4.0), Vector3.ZERO)
	resized.connect(_refit)

## Points the sun from `from` toward `at`. Only the direction matters.
func light_from(from: Vector3, at: Vector3) -> void:
	sun.look_at_from_position(from, at, Vector3.UP)

## Frames `box` (in the view's world) as seen from `dir` (unit vector from the
## box toward the camera), with `margin` of air around it, and keeps framing it
## as the slot resizes. The box is always whole and letterboxed rather than
## cropped, whatever shape the slot is.
func frame(box: AABB, dir: Vector3, margin := 1.1) -> void:
	_box = box
	_dir = dir.normalized()
	_margin = margin
	_framed = true
	_refit()

func _refit() -> void:
	if not _framed or cam == null:
		return
	var aim := _box.get_center()
	var reach := _box.size.length() + 2.0
	cam.look_at_from_position(aim + _dir * reach, aim, Vector3.UP)
	cam.far = reach * 2.0 + _box.size.length()
	# The box's extent in camera space is its size on screen under an
	# orthographic projection, so one measurement is exact.
	var to_cam := cam.transform.basis.transposed()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for i in 8:
		var p := to_cam * (_box.get_endpoint(i) - aim)
		lo = lo.min(p)
		hi = hi.max(p)
	var span := hi - lo
	var aspect := size.x / size.y if size.y > 0.0 else 1.0
	# The height the box needs: its own, or the height the slot has when the
	# box's width just fills the slot's width.
	cam.size = maxf(span.y, span.x / aspect) * _margin
	redraw()

## Draws the view once more. Call after anything that changes what it shows.
func redraw() -> void:
	if view != null:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
