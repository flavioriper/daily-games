extends Control

## The base of a card that owns its whole face on the first screen: the
## ground, the picture, where its name is set and what its go button is. The
## shell (ui/menu/puzzle_card_2d.gd) keeps what every card does -- the tap,
## the squash, the done seal, the SOON pill, the row's height -- and hands the
## whole of its paper to one of these when the registry entry names one under
## `card`. A board without the key wears the shared template.
##
## A face draws everything that does not move as one mesh (`_paint`), built
## at the size the card was given and kept until the next resize, and seats
## whatever lives -- faces, labels -- as children in `_lay`, through `_keep`,
## so a resize takes them away with the rest and leaves the shell's seal.
## The paper's own rounded edge is the shell's stylebox; a face keeps its
## ground inside `ground()` so that line stays whole.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
const SunDot = preload("res://ui/sun_dot.gd")

## The shell's paper: its corner radius and the line round it.
const RADIUS := 36.0
const EDGE := 2.0
## The done seal's radius and how far it hangs toward the corner, as on a
## template card (puzzle_card_2d.gd's SEAL_R and SEAL_HANG).
const SEAL_R := 30.0
const SEAL_IN := 38.0

var entry: Dictionary
var colour: Color
var soon := false
## The mesh `_draw` last handed over, kept until the next replaces it.
var _mesh: ArrayMesh
var _dirty := true
var _made: Array[Node] = []

func _init(the_entry: Dictionary, the_colour: Color) -> void:
	entry = the_entry
	colour = the_colour
	soon = bool(the_entry.get("soon", false))
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(_relayout)
	_relayout()

func _relayout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Out of the tree before being queued, as card_art.gd does: two resizes
	# in one frame would otherwise draw both casts over each other.
	for node in _made:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_made.clear()
	_dirty = true
	_lay()
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if _dirty or _mesh == null:
		_dirty = false
		var b := Face.Builder.new()
		_paint(b)
		_mesh = b.mesh()
	draw_mesh(_mesh, null)

## Everything still, into `b`, in this Control's own pixels.
func _paint(_b: Face.Builder) -> void:
	pass

## Everything that lives: children, each through `_keep`.
func _lay() -> void:
	pass

## Where the done seal's centre goes. The top right corner, where a template
## card pins it; a face leaves that corner bare or says where else.
func seal_centre() -> Vector2:
	return Vector2(size.x - SEAL_IN, SEAL_IN)

func _keep(node: Node) -> Node:
	add_child(node)
	_made.append(node)
	return node

## The ground's outline: the paper inside the shell's line.
func ground() -> PackedVector2Array:
	return Face.Builder.round_rect(Vector2(EDGE, EDGE), size - Vector2(EDGE, EDGE) * 2.0, RADIUS - EDGE)

## Shades every vertex `b` has taken since `first` from `top` at `y0` to
## `bottom` at `y1`, keeping each one's alpha, so a feather stays a feather.
static func shade(b: Face.Builder, first: int, top: Color, bottom: Color, y0: float, y1: float) -> void:
	for i in range(first, b.verts.size()):
		var c := top.lerp(bottom, clampf(inverse_lerp(y0, y1, b.verts[i].y), 0.0, 1.0))
		b.cols[i] = Color(c.r, c.g, c.b, b.cols[i].a * c.a)

## The card's name in the shared title face, sun-dotted, and its two-line
## blurb under it, in a column `w` wide whose middle stands at `mid_y`.
func _words(title: String, at_x: float, mid_y: float, w: float, ink := Pal.TEXT, dim := Pal.TEXT_DIM) -> VBoxContainer:
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.theme_type_variation = "CardName"
	name_label.text = title
	name_label.add_theme_color_override("font_color", ink)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_label)
	name_label.add_child(SunDot.new(name_label))
	var blurb := Label.new()
	blurb.theme_type_variation = "CardBlurb"
	blurb.text = String(entry.get("short", entry.get("blurb", "")))
	blurb.add_theme_color_override("font_color", dim)
	blurb.add_theme_constant_override("line_spacing", -6)
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(blurb)
	_keep(words)
	words.size = Vector2(w, 0.0)
	var h := words.get_combined_minimum_size().y
	words.position = Vector2(at_x, roundf(mid_y - h * 0.5))
	words.size = Vector2(w, h)
	return words
