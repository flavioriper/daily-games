extends SubViewportContainer

## A title sign as the model it is: assets/models/sign_board.glb standing in
## its own small world, the title and motto extruded from the display face by
## TextMesh, lit by one directional light. Real geometry, so it takes the toon
## shader, the grain on its plank, the cast shadow of its own lettering and
## the outline pass -- which is the whole reason the board is modelled in
## Blender rather than drawn.
##
## The board is modelled once (art/sign.blend, exported through
## tools/blender_export.py). The words are data: set_words() drives two
## TextMesh instances, so a new puzzle costs a registry line and nothing else.
## Nothing here is baked to an image.

const Models = preload("res://core/models.gd")
const Toon = preload("res://core/toon.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")

## The board's own measurements, read off assets/models/title_sign.glb: it
## spans x -1.137..1.137 and y 0..0.827 with its face at z 0.0104.
const BOARD_W := 2.274
const BOARD_H := 0.827
const FACE_Z := 0.0104
const ASPECT := BOARD_W / BOARD_H
## A little air around the board so the outline shell is never clipped, plus
## the width the tilt below costs.
const FRAME := 1.12
## The camera is turned a few degrees off dead-on. Straight down the board's
## own normal, an orthographic camera sees nothing but front faces: the
## lettering's extrusion and the plank's thickness are exactly edge-on and the
## whole sign reads as flat colour. Blender's render got away with it because
## its letters were bevelled and the rounded edge caught light; TextMesh has no
## bevel, so the depth has to be shown rather than implied.
const TILT_YAW := 9.0
const TILT_PITCH := 6.0

## Where the two lines sit on the board, from art/sign.blend.
const TITLE_Y := 0.516
const MOTTO_Y := 0.216
const TITLE_EM := 0.30
const MOTTO_EM := 0.095
const TITLE_DEPTH := 0.055
const MOTTO_DEPTH := 0.016
## World units per font pixel. Font size is an integer, so the em height is
## dialled with this instead and stays exact.
const PIXEL := 0.004
## The widest the words may run: the leaf sprigs are rooted at x = +-0.79 and
## a longer line would grow into them.
const MAX_TITLE_W := 1.44
const MAX_MOTTO_W := 1.40
## The outline shells' width, in world units. A sign is drawn far larger than a
## piece on the stage -- 2.27 units filling a whole card, where a tile's 0.84
## fills a thumbnail -- so Toon's own 0.014 reads several times too thick here.
const LINE_WIDTH := 0.005

var _view: SubViewport
var _cam: Camera3D
var _title: MeshInstance3D
var _motto: MeshInstance3D

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	custom_minimum_size = Vector2(0.0, 0.0)
	_view = SubViewport.new()
	# Its own world: the game's stage light and sky must not reach in here,
	# and this one's light must not reach out.
	_view.own_world_3d = true
	_view.world_3d = World3D.new()
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	# Drawn on demand, not every frame. Thirteen of these live at once (twelve
	# cards and the row above them) and a sign does not move: left on
	# UPDATE_WHEN_VISIBLE they cost 18.6 ms of process time on the menu against
	# this project's ~5 ms idle baseline, measured over 90 frames. Every change
	# calls redraw() -- new words, a new size -- so this is render caching, not
	# a baked asset: the geometry is still here and still lit, and anything that
	# moves it will show.
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_view)

	# Lit exactly as world/stage.gd lights the game: its 0.46 / 0.115 sun-to-
	# ambient pair is measured against a rendered frame, not derived, because
	# the gl_compatibility pipeline comes out brighter than the shader maths
	# predicts. At anything near the obvious values the plank blows out to pale
	# pine and the leaves go yellow.
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Pal.AMBIENT
	env.ambient_light_energy = 0.115
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	_view.world_3d.environment = env

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.size = BOARD_H * FRAME
	_cam.near = 0.01
	_cam.far = 10.0
	_view.add_child(_cam)
	var aim := Vector3(0.0, BOARD_H * 0.5, 0.0)
	var yaw := deg_to_rad(TILT_YAW)
	var pitch := deg_to_rad(TILT_PITCH)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	_cam.look_at_from_position(aim + dir * 3.0, aim, Vector3.UP)
	resized.connect(_refit)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.46
	sun.light_color = Color("fff1dc")
	sun.shadow_enabled = true
	# The lettering's shadow on the plank is what gives the carving its depth,
	# and it is a real shadow here rather than a painted one.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 6.0
	_view.add_child(sun)
	# From the front, upper left: the stage's sun sits behind the board, which
	# would leave a sign lit only by ambient. The lettering's shadow falls down
	# and to the right onto the plank, which is what reads as carving.
	sun.look_at_from_position(Vector3(-2.0, 3.0, 4.0), Vector3(0.0, BOARD_H * 0.45, 0.0), Vector3.UP)

	var board: Node3D = Models.instance("title_sign")
	_view.add_child(board)
	_soften_lines(board)

	_title = _line(TITLE_EM, TITLE_DEPTH, TITLE_Y, Pal.SURFACE)
	_motto = _line(MOTTO_EM, MOTTO_DEPTH, MOTTO_Y, Pal.SURFACE_HI)
	_view.add_child(_title)
	_view.add_child(_motto)

## Re-lines every layer of the board in its own colour at this magnification.
## Each shell gets a fresh material: Toon.line() caches per colour and those
## materials are shared with every piece on the stage, so setting a width on
## one would thin the whole game's outlines. The colour comes from
## Toon.line_color -- the layer's own, deepened and cooled -- because a leaf
## wearing the shared ink line reads as a harsh black edge at this size, which
## docs/art/shading-direction.md rules out.
func _soften_lines(board: Node3D) -> void:
	for mi in Models.meshes(board):
		var shell := mi.get_node_or_null(Toon.OUTLINE_NODE) as MeshInstance3D
		if shell == null:
			continue
		var src := mi.mesh.surface_get_material(0)
		var albedo: Color = (src as StandardMaterial3D).albedo_color if src is StandardMaterial3D else Pal.PLAQUE
		shell.material_override = _line_material(Toon.line_color(albedo))

func _line_material(colour: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Toon.OUTLINE_SHADER
	m.set_shader_parameter("color", colour)
	m.set_shader_parameter("width", LINE_WIDTH)
	return m

## One line of carved lettering: real extruded geometry in the display face.
func _line(em: float, depth: float, y: float, colour: Color) -> MeshInstance3D:
	var mesh := TextMesh.new()
	mesh.font = CozyTheme.display(700)
	mesh.font_size = maxi(int(round(em / PIXEL)), 1)
	mesh.pixel_size = PIXEL
	mesh.depth = depth
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# Sat on the face and standing off it, so the extrusion is all in front of
	# the plank rather than half sunk into it.
	mi.position = Vector3(0.0, y, FACE_Z + depth * 0.5)
	mi.set_surface_override_material(0, Toon.material_for(mi, colour))
	var shell := Toon.add_outline(mi, _line_material(Toon.line_color(colour)))
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Widens the camera when the slot it was given is squarer than the board, so
## the whole sign is always framed and letterboxed rather than cropped. The
## camera keeps height, which alone would cut the board's ends off in a narrow
## slot.
func _refit() -> void:
	if _cam == null or size.y <= 0.0:
		return
	var slot := size.x / size.y
	_cam.size = BOARD_H * FRAME if slot >= ASPECT else BOARD_W * FRAME / slot
	redraw()

## Draws the sign once more. Call after anything that changes what it shows.
func redraw() -> void:
	if _view != null:
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE

## Sets the words and brings a long line down until it clears the leaf sprigs.
## The plank never stretches, so every sign keeps the same shape.
func set_words(title: String, motto: String) -> void:
	_fit(_title, title.to_upper(), TITLE_EM, MAX_TITLE_W)
	_fit(_motto, motto.to_upper(), MOTTO_EM, MAX_MOTTO_W)
	redraw()

func _fit(mi: MeshInstance3D, text: String, em: float, limit: float) -> void:
	var mesh: TextMesh = mi.mesh
	mesh.text = text
	mesh.pixel_size = PIXEL
	mesh.font_size = maxi(int(round(em / PIXEL)), 1)
	if text == "":
		return
	# Width is linear in pixel_size, so one step lands it.
	var w: float = mesh.get_aabb().size.x
	if w > limit and w > 0.0:
		mesh.pixel_size = PIXEL * limit / w
