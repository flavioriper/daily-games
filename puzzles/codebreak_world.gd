extends Control

## Code Break's world: the inside of the board's own box, edge to edge under
## the board and the host's rows (CLAUDE.md: a game's world fills the
## screen). It is the menu card's picture (ui/menu/cards/codebreak.gd) at
## the size of the screen: the card's parchment from the top down, lit from
## the corner the wordmark stands in, warming into the wood of the box where
## the friends wait at the foot, with the box's rail along the very bottom.
## The card's dark shelf is not here: it carries the lids, so it is the
## board's own plank and goes where the board goes (codebreak2d.gd's
## `_shelf`).
##
## The parchment keeps the top of the screen because of what lies over it:
## the wordmark, the motto and the win's "Well done!" are ink with no scrim.
## The wood at the foot is a wash, never the shelf's dark, since the tray's
## words are ink too.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it. A spare lid and a loose score lie in the gap of the tools
## row, a second mesh on a child (`_loose`) that the board hides on the win,
## when the cast stands there. Nothing here moves: the lids' peeks and the
## sparks are the board's.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const PAPER_TOP := Color("f8f0dc")
const PAPER_LOW := Color("eedfc0")
const WOOD_WASH := Color("b98a5a")
const RAIL_TOP := Color("7a5334")
const RAIL_LOW := Color("5f3f28")
## The light in the wordmark's corner: its middle as shares of the rect,
## and its rings, [radius at W, alpha].
const LIGHT_AT := Vector2(0.10, 0.02)
const LIGHT_RINGS := [[760.0, 0.16], [520.0, 0.16], [300.0, 0.20]]
## Where the parchment starts to warm into the box's wood, and how deep the
## wash is at the foot, as shares of the rect and an alpha.
const WASH_FROM := 0.74
const WASH_DEEP := 0.34
## The rail along the bottom, its height at W.
const RAIL := 44.0
## The grain in the wash: [y as a share, x from, x to, phase].
const GRAIN := [
	[0.800, 0.04, 0.44, 0.4], [0.828, 0.52, 0.97, 2.0], [0.866, 0.10, 0.62, 1.1],
	[0.900, 0.40, 0.96, 2.6], [0.936, 0.03, 0.50, 0.2], [0.956, 0.58, 0.98, 1.6],
]
## The spare lid in the gap of the tools row, between Clear and Hint: its
## middle as shares, its side at W and its tilt.
const LID_AT := Vector2(0.545, 0.2275)
const LID := 78.0
const LID_TILT := -0.16
const LID_ROUND := 0.22
const LID_EDGE := 0.055
## The loose score beside it: [x, y as shares, filled]. A count, laid
## loose, never a map.
const PIPS := [[0.640, 0.2215, true], [0.682, 0.2330, false], [0.432, 0.2330, false]]
const PIP_R := 13.0

var _shown: ArrayMesh
var _loose: Control
var _loose_shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loose = Control.new()
	_loose.name = "Loose"
	_loose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loose.draw.connect(func() -> void:
		if _loose_shown != null:
			_loose.draw_mesh(_loose_shown, null))
	add_child(_loose)
	resized.connect(_build)
	_build()

## The board says when the win is up: the cast stands where the spare lid
## lies, so the lid and the loose score go.
func set_won(won: bool) -> void:
	if _loose != null:
		_loose.visible = not won

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The parchment under everything.
	var first := b.verts.size()
	b.polygon(_band(-8.0, size.y + 8.0), Color.WHITE)
	CardFace.shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y * WASH_FROM)
	# The light in the wordmark's corner.
	var light := LIGHT_AT * size
	for ring in LIGHT_RINGS:
		b.disc(light, ring[0] * u, Color(Pal.SURFACE, ring[1]))
	# The parchment warms into the wood of the box toward the foot.
	var from := size.y * WASH_FROM
	first = b.verts.size()
	b.polygon(_band(from, size.y + 8.0), Color.WHITE)
	CardFace.shade(b, first, Color(WOOD_WASH, 0.0), Color(WOOD_WASH, WASH_DEEP), from, size.y)
	for run: Array in GRAIN:
		var pts := PackedVector2Array()
		for i in 17:
			var x := lerpf(run[1], run[2], i / 16.0)
			pts.append(Vector2(x * size.x, (run[0] + 0.0022 * sin(x * 11.0 + run[3])) * size.y))
		b.stroke(pts, 3.0 * u, Color(Pal.WOOD, 0.10))
	# The box's rail along the bottom, with its lit lip.
	var rail := size.y - RAIL * u
	first = b.verts.size()
	b.polygon(_band(rail - 14.0 * u, rail), Color.WHITE)
	CardFace.shade(b, first, Color(Pal.PLAQUE_DEEP, 0.0), Color(Pal.PLAQUE_DEEP, 0.16), rail - 14.0 * u, rail)
	first = b.verts.size()
	b.polygon(_band(rail, size.y + 8.0), Color.WHITE)
	CardFace.shade(b, first, RAIL_TOP, RAIL_LOW, rail, size.y)
	b.polygon(_band(rail, rail + 7.0 * u), Pal.WOOD)
	b.polygon(_band(rail, rail + 2.5 * u), Color(Pal.WOOD.lightened(0.35), 0.75))
	_shown = b.mesh()
	queue_redraw()
	# The spare lid and the loose score.
	var lb := Face.Builder.new()
	for p in PIPS:
		var c := Vector2(p[0], p[1]) * size
		var r := PIP_R * u
		lb.disc(c + Vector2(0.0, 3.0 * u), r, Color(0.14, 0.08, 0.04, 0.12))
		if p[2]:
			lb.disc(c, r, Color(Pal.TEXT, 0.88))
		else:
			lb.disc(c, r, Pal.SURFACE)
			lb.stroke(Face.Builder.arc_points(c, r - 2.0 * u, 0.0, TAU), 4.0 * u, Color(Pal.TEXT_DIM, 0.9), true)
	var lid := Face.Builder.new()
	_lid(lid, LID * u)
	lb.append(lid.mesh(), Transform2D(LID_TILT, LID_AT * size))
	_loose_shown = lb.mesh()
	_loose.size = size
	_loose.queue_redraw()

## A band of the rect from `y0` to `y1`, wider than the screen.
func _band(y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-8.0, y0), Vector2(size.x + 8.0, y0),
		Vector2(size.x + 8.0, y1), Vector2(-8.0, y1)])

## A lid `px` square about the origin, as the board's are: its shadow, its
## edge and face, a little grain, a screw in each top corner and the
## question mark carved in it.
func _lid(b: Face.Builder, px: float) -> void:
	var at := Vector2(-px, -px) * 0.5
	var edge := px * LID_EDGE
	b.polygon(Face.Builder.round_rect(at + Vector2(0.0, px * 0.07), Vector2(px, px), px * LID_ROUND), Color(0.14, 0.08, 0.04, 0.22))
	b.polygon(Face.Builder.round_rect(at, Vector2(px, px), px * LID_ROUND), Pal.WOOD_DEEP)
	b.polygon(Face.Builder.round_rect(at + Vector2(edge, edge), Vector2(px - edge * 2.0, px - edge * 2.4),
		px * LID_ROUND - edge), Pal.WOOD)
	b.polygon(Face.Builder.round_rect(at + Vector2(px * 0.26, px * 0.075), Vector2(px * 0.48, px * 0.045), px * 0.0225),
		Color(1.0, 1.0, 1.0, 0.26))
	for run: Array in [[0.30, 0.12, 0.40], [0.72, 0.56, 0.88], [0.84, 0.14, 0.38]]:
		b.stroke(PackedVector2Array([at + Vector2(run[1], run[0]) * px, at + Vector2(run[2], run[0]) * px]),
			px * 0.022, Color(Pal.WOOD_DEEP, 0.28))
	for c: Vector2 in [Vector2(0.17, 0.2), Vector2(0.83, 0.2)]:
		b.disc(at + c * px, px * 0.036, Color(Pal.WOOD_DEEP, 0.7))
	# The mark: a hook, a stem and a dot.
	var ink := Color(Pal.WOOD_DEEP, 0.85)
	var hook := Face.Builder.arc_points(Vector2(0.0, -px * 0.085), px * 0.115, -PI, PI * 0.5)
	hook.append(Vector2(0.0, px * 0.115))
	b.stroke(hook, px * 0.075, ink)
	b.disc(Vector2(0.0, px * 0.245), px * 0.048, ink)
