extends "res://legacy/ui/hud/model_view.gd"

## A title sign as the model it is: assets/models/title_sign.glb standing in
## its own small world (ui/hud/model_view.gd), the title and motto extruded
## from the display face by TextMesh (core/lettering.gd), lit by one
## directional light. Real geometry, so it takes the toon shader, the grain on
## its plank, the cast shadow of its own lettering and the outline pass --
## which is the whole reason the board is modelled in Blender rather than
## drawn.
##
## The board is modelled once (art/sign.blend, exported through
## tools/blender_export.py). The words are data: set_words() drives two
## TextMesh instances, so a new puzzle costs a registry line and nothing else.
## Nothing here is baked to an image.

const Models = preload("res://legacy/core/models.gd")
const Toon = preload("res://legacy/core/toon.gd")
const Lettering = preload("res://legacy/core/lettering.gd")

## The board's own measurements, read off assets/models/title_sign.glb: it
## spans x -1.137..1.137 and y 0..0.827 with its face at z 0.0104.
const BOARD_W := 2.274
const BOARD_H := 0.827
const FACE_Z := 0.0104
const ASPECT := BOARD_W / BOARD_H
## A little air around the board so the outline shell is never clipped.
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
## The widest the words may run: the leaf sprigs are rooted at x = +-0.79 and
## a longer line would grow into them.
const MAX_TITLE_W := 1.44
const MAX_MOTTO_W := 1.40

var _title: MeshInstance3D
var _motto: MeshInstance3D

func _init() -> void:
	super()
	# The lettering's shadow falls down and to the right onto the plank,
	# which is what reads as carving.
	light_from(Vector3(-2.0, 3.0, 4.0), Vector3(0.0, BOARD_H * 0.45, 0.0))

	var board: Node3D = Models.instance("title_sign")
	view.add_child(board)
	_soften_lines(board)

	_title = _line(TITLE_EM, TITLE_DEPTH, TITLE_Y, Pal.SURFACE)
	_motto = _line(MOTTO_EM, MOTTO_DEPTH, MOTTO_Y, Pal.SURFACE_HI)
	view.add_child(_title)
	view.add_child(_motto)

	var yaw := deg_to_rad(TILT_YAW)
	var pitch := deg_to_rad(TILT_PITCH)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	frame(AABB(Vector3(-BOARD_W * 0.5, 0.0, -0.05), Vector3(BOARD_W, BOARD_H, FACE_Z + TITLE_DEPTH + 0.1)), dir, FRAME)

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
		shell.material_override = Lettering.outline(Toon.line_color(albedo))

## One line of carved lettering: real extruded geometry in the display face,
## sat on the face and standing off it, so the extrusion is all in front of
## the plank rather than half sunk into it.
func _line(em: float, depth: float, y: float, colour: Color) -> MeshInstance3D:
	var mi := Lettering.line("", em, depth, colour)
	mi.position = Vector3(0.0, y, FACE_Z + depth * 0.5)
	return mi

## Sets the words and brings a long line down until it clears the leaf sprigs.
## The plank never stretches, so every sign keeps the same shape.
func set_words(title: String, motto: String) -> void:
	Lettering.fit(_title, title.to_upper(), TITLE_EM, MAX_TITLE_W)
	Lettering.fit(_motto, motto.to_upper(), MOTTO_EM, MAX_MOTTO_W)
	redraw()
