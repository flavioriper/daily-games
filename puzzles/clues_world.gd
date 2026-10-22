extends Control

## Five Clues' world: the garden shed's wall, edge to edge under the board,
## the host's rows and the keyboard (CLAUDE.md: a game's world fills the
## screen). Pale painted planks with the morning light on them, across the
## top where the wordmark, the motto and the win's "Well done!" are ink with
## no scrim; a cork board in a wooden frame where the clue cards are pinned;
## a chalk slate under it, where the line is typed and the idea chalked; a
## trailing ivy at the board's corner.
##
## The board says where its lines stand (`set_lines`): the cork board and
## the slate. One mesh, built when the rect or a line changes and kept
## (`_shown`) until the next replaces it, drawn past the top for the win.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const W := 1080.0
const PLANK_HIGH := Color("e7efe8")
const PLANK_LOW := Color("d4e2d7")
const SEAM := Color("bcd0c1")
const SUN := Color("fff6d8")
const CORK := Color("d2a36e")
const CORK_DOT := Color("b98a57")
const FRAME := Color("a7774c")
const FRAME_DEEP := Color("845a36")
const SLATE := Color("3f4a46")
const SLATE_HI := Color("4a5752")
const IVY := Color("6f9e57")
const IVY_DEEP := Color("557f42")
const OVER := 0.6

var _cork := Rect2()
var _slate := Rect2()
var _built := ""
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func set_lines(cork: Rect2, slate: Rect2) -> void:
	_cork = cork
	_slate = slate
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _cork.size.x <= 0.0:
		return
	var key := "%s:%s:%s" % [size, _cork, _slate]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, PLANK_HIGH, PLANK_LOW, 0.0, h)
	var x := 0.0
	while x < w + 10.0:
		b.polygon(_rect(x, -h * OVER, x + 3.0 * u, h + 240.0 * u), SEAM)
		x += 120.0 * u
	for ring: Array in [[320.0, 0.16], [210.0, 0.2], [130.0, 0.26]]:
		b.disc(Vector2(w * 0.15, _cork.position.y * 0.6), float(ring[0]) * u, Color(SUN, float(ring[1])))
	# the cork board in its frame
	var c := _cork
	Scenery.soft_disc(b, Vector2(c.get_center().x, c.end.y + 10.0 * u), c.size.x * 0.55, 18.0 * u, Color(0.2, 0.15, 0.1, 0.14))
	b.fan(Face.Builder.round_rect(c.position - Vector2(14.0, 14.0) * u + Vector2(0.0, 5.0 * u), c.size + Vector2(28.0, 28.0) * u, 14.0 * u), FRAME_DEEP)
	b.fan(Face.Builder.round_rect(c.position - Vector2(14.0, 14.0) * u, c.size + Vector2(28.0, 28.0) * u, 14.0 * u), FRAME)
	b.fan(Face.Builder.round_rect(c.position, c.size, 6.0 * u), CORK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1022
	for i in int(c.size.x * c.size.y / (900.0 * u * u)):
		b.disc(c.position + Vector2(rng.randf() * c.size.x, rng.randf() * c.size.y), rng.randf_range(1.0, 2.6) * u, Color(CORK_DOT, 0.55))
	# the slate
	var s := _slate
	if s.size.x > 0.0:
		b.fan(Face.Builder.round_rect(s.position - Vector2(12.0, 12.0) * u + Vector2(0.0, 5.0 * u), s.size + Vector2(24.0, 24.0) * u, 14.0 * u), FRAME_DEEP)
		b.fan(Face.Builder.round_rect(s.position - Vector2(12.0, 12.0) * u, s.size + Vector2(24.0, 24.0) * u, 14.0 * u), FRAME)
		first = b.verts.size()
		b.fan(Face.Builder.round_rect(s.position, s.size, 8.0 * u), Color.WHITE)
		CardFace.shade(b, first, SLATE_HI, SLATE, s.position.y, s.end.y)
		b.stroke(PackedVector2Array([s.position + Vector2(30.0, s.size.y * 0.7) * Vector2(1, 1), s.position + Vector2(s.size.x * 0.3, s.size.y * 0.78)]), 3.0 * u, Color(1, 1, 1, 0.06))
	# ivy trailing from the board's top right corner
	var at := Vector2(c.end.x + 6.0 * u, c.position.y - 8.0 * u)
	var stem := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		stem.append(at + Vector2(sin(t * 3.0) * 26.0 * u, t * 260.0 * u))
	b.stroke(stem, 3.0 * u, IVY_DEEP)
	for i in range(1, 9):
		var p := stem[i]
		var side := 1.0 if i % 2 == 0 else -1.0
		b.ellipse(p + Vector2(side * 16.0 * u, 0.0), 15.0 * u, 10.0 * u, IVY if i % 3 else IVY_DEEP)
	_shown = b.mesh()
	queue_redraw()

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
