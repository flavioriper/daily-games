extends "res://legacy/ui/hud/model_view.gd"

## The first screen's name as standing letters: two TextMesh extrusions of the
## same word, a cream face on a deeper wood block, seen a little from above
## and the right so the block's top and side show as grain. Real geometry in
## its own small world (ui/hud/model_view.gd), so it takes the toon shader,
## the wood grain and the outline pass like every sign in the game.

const Lettering = preload("res://legacy/core/lettering.gd")

const EM := 0.5
const FACE_DEPTH := 0.05
## A thin edge of wood behind the face, not a block: the concept banner's name
## is white with a dark rim a tenth of its height, and a deep block seen from
## above turned the whole word caramel.
const BLOCK_DEPTH := 0.1
## From the front, a little right and above: the letters' tops and left sides
## show as wood.
const DIR := Vector3(0.14, 0.24, 1.0)
const FRAME := 1.14
const LINE_WIDTH := 0.007

var _face: MeshInstance3D
var _block: MeshInstance3D

func _init() -> void:
	super()
	light_from(Vector3(-3.0, 4.0, 5.0), Vector3.ZERO)
	_block = Lettering.line("", EM, BLOCK_DEPTH, Pal.PLAQUE_DEEP, 700, HORIZONTAL_ALIGNMENT_LEFT, LINE_WIDTH)
	_face = Lettering.line("", EM, FACE_DEPTH, Pal.SURFACE, 700, HORIZONTAL_ALIGNMENT_LEFT, LINE_WIDTH)
	# The face sits on the block's front, sunk a hair so the two never seam.
	_face.position.z = BLOCK_DEPTH * 0.5 + FACE_DEPTH * 0.5 - 0.004
	view.add_child(_block)
	view.add_child(_face)

func set_title(text: String) -> void:
	for mi in [_block, _face]:
		(mi.mesh as TextMesh).text = text.to_upper()
	var box: AABB = _block.transform * _block.mesh.get_aabb()
	box = box.merge(_face.transform * _face.mesh.get_aabb())
	frame(box, DIR, FRAME)
