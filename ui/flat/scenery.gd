extends Control

## The soft scenery a flat board card may carry behind its pieces: a few
## clouds high in the card and tufts of grass at whatever stands on the
## ground, drawn as **one cached mesh in one draw call** under everything, so
## a board is dressed without paying per cloud (gl_compatibility pays per
## canvas command; see CLAUDE.md). Balance was the first to take it, from the
## user's re-render of 2026-09-18; a board that wants the same hands this its
## anchor points in its own pixels and calls rebuild() after a relayout.
## Decoration says so: nothing here counts anything, and a board never places
## a cloud where it could read as a piece.
##
## Also here is the ground shadow every board draws the same way: shadow()
## is one radial disc, white at the centre and clear at the rim, that a
## board draws with a Transform2D scaled to the ellipse it wants and a
## modulate of ink at a low alpha. A thing moving over its ground therefore
## costs one draw_mesh a frame and never a rebuild.
## Spec: docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 10.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

## A cloud is the card's parchment lifted most of the way to white -- opaque,
## so its overlapping puffs never double up along their seams the way a
## translucent white would.
const CLOUD_LIFT := 0.8
## The grass's two greens, and how tall a tuft's outer blades stand against
## its middle one.
const BLADE_SIDE := 0.72
const BLADE_OUTER := 0.42
const BLADE_W := 0.2
## The shadow disc's radius in its own mesh, so that a scaled copy's rim is
## smooth at any size a board asks for.
const SHADOW_UNIT := 64.0

## Each cloud: x and y of its centre and the radius of its largest puff.
var clouds: Array[Vector3] = []
## Each tuft: x and y of its root and its height.
var tufts: Array[Vector3] = []
## The parchment the clouds lift from; the board card's own colour.
var ground: Color = Pal.PARCHMENT

var _mesh: ArrayMesh
static var _shadow: ArrayMesh

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

## Rebuilds the mesh from the anchors on the next draw.
func rebuild() -> void:
	_mesh = null
	queue_redraw()

func _draw() -> void:
	if _mesh == null:
		_mesh = _build()
	if _mesh != null:
		draw_mesh(_mesh, null)

func _build() -> ArrayMesh:
	if clouds.is_empty() and tufts.is_empty():
		return null
	var b := Face.Builder.new()
	var cloud: Color = ground.lerp(Pal.SURFACE, CLOUD_LIFT)
	for c in clouds:
		_cloud(b, Vector2(c.x, c.y), c.z, cloud)
	for t in tufts:
		_tuft(b, Vector2(t.x, t.y), t.z)
	return b.mesh()

## A cloud: a flat base under three puffs, the middle one tallest, the way
## the concept page's sky draws them.
static func _cloud(b: Face.Builder, at: Vector2, r: float, colour: Color) -> void:
	b.ellipse(at + Vector2(0.0, r * 0.35), r * 1.75, r * 0.5, colour)
	b.disc(at + Vector2(-r * 0.75, r * 0.1), r * 0.62, colour)
	b.disc(at + Vector2(0.05 * r, -r * 0.2), r, colour)
	b.disc(at + Vector2(r * 0.9, r * 0.12), r * 0.56, colour)

## A tuft: five blades from one root, the middle one tallest and darkest, the
## outer pairs leaning out and shorter, each a slim triangle with a curved
## back so it reads as grass and not as a spike.
static func _tuft(b: Face.Builder, root: Vector2, h: float) -> void:
	var blades := [
		[Vector2(0.0, -1.0), Pal.LEAF_DEEP],
		[Vector2(-0.42, -BLADE_SIDE), Pal.LEAF],
		[Vector2(0.45, -BLADE_SIDE * 0.95), Pal.LEAF],
		[Vector2(-0.8, -BLADE_OUTER), Pal.LEAF],
		[Vector2(0.82, -BLADE_OUTER * 0.9), Pal.LEAF],
	]
	for blade in blades:
		var tip: Vector2 = root + (blade[0] as Vector2) * h
		var w := h * BLADE_W * 0.5
		var mid := root.lerp(tip, 0.5)
		var side := (tip - root).orthogonal().normalized()
		var bow := side * h * 0.15
		# Both flanks bow the same way, so the blade curves rather than
		# swells; bezier2 includes its start and drops its end, so the two
		# curves and the closing corner meet without a doubled vertex, which
		# would make triangulate_polygon hand back nothing.
		var pts := Face.Builder.bezier2(root - side * w, mid - bow - side * w, tip, 8)
		pts.append_array(Face.Builder.bezier2(tip, mid - bow + side * w, root + side * w, 8))
		pts.append(root + side * w)
		b.polygon(pts, blade[1])

## The ground shadow: one radial disc of SHADOW_UNIT radius, opaque white at
## the centre and clear at the rim. Draw it with
## `Transform2D(0, Vector2(rx, ry) / SHADOW_UNIT, 0, at)` and a modulate of
## `Color(Pal.TEXT, alpha)`; the gradient is what makes it soft, so it needs
## no feather and no blur.
static func shadow() -> ArrayMesh:
	if _shadow != null:
		return _shadow
	var b := Face.Builder.new()
	var centre := b.vertex(Vector2.ZERO, Color(1.0, 1.0, 1.0, 1.0))
	var rim := Face.Builder.ring(Vector2.ZERO, SHADOW_UNIT, SHADOW_UNIT)
	var first := b.verts.size()
	for p in rim:
		b.vertex(p, Color(1.0, 1.0, 1.0, 0.0))
	for i in rim.size():
		b.tri(centre, first + i, first + (i + 1) % rim.size())
	_shadow = b.mesh()
	return _shadow
