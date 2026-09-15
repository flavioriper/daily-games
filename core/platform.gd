extends RefCounted

## The stone platform a 3D board floats on: one `platform` slab stretched to
## the board plus a lip, and a ring of `rim_edge` / `rim_corner` moss pieces
## resting on that lip at y = 0, so the tiles sit inside a mossy frame
## (docs/art/concept-binairo-island.png). The rim pieces are unit models, so
## the lip is exactly one rim piece deep and the ring tiles cleanly for any
## board size. Pure node building; covered by tests/test_platform.gd.

const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")

## Platform overhang beyond the tiles on every side, in cells. Equal to the
## depth of a rim piece.
const LIP := 0.5

## `slab` is the model stretched under the rim; "" lays the rim alone, for a
## board that brings its own floor (Code Break's plank deck).
static func build(cols: int, rows: int, slab := "platform") -> Node3D:
	var root := Node3D.new()
	root.name = "Platform"

	if slab != "":
		var slab_node := Models.instance(slab)
		slab_node.name = "Slab"
		slab_node.scale = Vector3(cols + 2.0 * LIP, 1.0, rows + 2.0 * LIP)
		slab_node.position = Vector3(0.0, -Placeholders.PLATFORM_H, 0.0)
		root.add_child(slab_node)

	var hx := cols * 0.5
	var hz := rows * 0.5
	var mid := LIP * 0.5
	# rim_edge runs 1 along X with its outward side at +Z; rotating about Y by
	# theta sends local +Z to world (sin theta, cos theta).
	for c in cols:
		var x := -hx + 0.5 + c
		_rim(root, "rim_edge", Vector3(x, 0.0, hz + mid), 0.0, c)
		_rim(root, "rim_edge", Vector3(x, 0.0, -hz - mid), PI, c)
	for r in rows:
		var z := -hz + 0.5 + r
		_rim(root, "rim_edge", Vector3(hx + mid, 0.0, z), PI * 0.5, r)
		_rim(root, "rim_edge", Vector3(-hx - mid, 0.0, z), -PI * 0.5, r)
	# rim_corner has its outward corner at +X +Z.
	_rim(root, "rim_corner", Vector3(hx + mid, 0.0, hz + mid), 0.0, 0)
	_rim(root, "rim_corner", Vector3(-hx - mid, 0.0, hz + mid), -PI * 0.5, 0)
	_rim(root, "rim_corner", Vector3(hx + mid, 0.0, -hz - mid), PI * 0.5, 0)
	_rim(root, "rim_corner", Vector3(-hx - mid, 0.0, -hz - mid), PI, 0)
	return root

## One rim piece. Every other edge piece along a side is mirrored along its
## length so a tuft pattern does not repeat every cell.
static func _rim(root: Node3D, slot: String, at: Vector3, yaw: float, index: int) -> void:
	var piece := Models.instance(slot)
	piece.name = "%s_%d" % [slot, root.get_child_count()]
	piece.position = at
	piece.rotation.y = yaw
	if slot == "rim_edge" and index % 2 == 1:
		piece.scale.x = -1.0
	root.add_child(piece)
