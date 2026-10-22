extends Control

## Four Shelves' world: a pantry, edge to edge under the board and the
## host's rows (CLAUDE.md: a game's world fills the screen). Cream striped
## wallpaper across the top, where the wordmark, the motto and the win's
## "Well done!" are ink with no scrim, the window's light on it; an old
## painted dresser standing on the counter, its sage back panel behind the
## jars, its wooden posts and crown; and the counter's warm top from the
## dresser's foot to past the bottom of the screen.
##
## The board says where its lines stand (`set_lines`): the dresser's rect
## and the counter. One mesh, built when the rect or a line changes and kept
## (`_shown`) until the next replaces it, drawn past the top for the win.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const W := 1080.0
const WALL_HIGH := Color("fbf3e3")
const WALL_LOW := Color("f2e4cd")
const STRIPE := Color("efdcc0")
const SUN := Color("fff1c8")
const PANEL := Color("cfe0d4")
const PANEL_LOW := Color("bcd2c3")
const FRAME := Color("8fae9a")
const FRAME_DEEP := Color("74937f")
const CROWN := Color("a3c1ad")
const COUNTER := Color("dcb07c")
const COUNTER_TOP := Color("e8c393")
const COUNTER_LOW := Color("c99863")
const OVER := 0.6

var _dresser := Rect2()
var _counter := 0.0
var _built := ""
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func set_lines(dresser: Rect2, counter: float) -> void:
	_dresser = dresser
	_counter = counter
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _counter <= 0.0:
		return
	var key := "%s:%s:%s" % [size, _dresser, _counter]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, _counter + 4.0), Color.WHITE)
	CardFace.shade(b, first, WALL_HIGH, WALL_LOW, 0.0, _counter)
	# the wallpaper's soft stripes
	var x := 0.0
	while x < w:
		b.polygon(_rect(x, -h * OVER, x + 22.0 * u, _counter), Color(STRIPE, 0.45))
		x += 70.0 * u
	var sun := Vector2(w * 0.85, _dresser.position.y * 0.5)
	for ring: Array in [[300.0, 0.10], [190.0, 0.14], [120.0, 0.2]]:
		b.disc(sun, float(ring[0]) * u, Color(SUN, float(ring[1])))
	# the dresser: its shadow, posts, back panel and crown
	var d := _dresser
	Scenery.soft_disc(b, Vector2(d.get_center().x, d.end.y), d.size.x * 0.55, 24.0 * u, Color(0.3, 0.2, 0.1, 0.14))
	var post := 22.0 * u
	b.fan(Face.Builder.round_rect(d.position - Vector2(post, 0.0), d.size + Vector2(post * 2.0, 0.0), 10.0 * u), FRAME_DEEP)
	b.fan(Face.Builder.round_rect(d.position - Vector2(post - 4.0 * u, 0.0), d.size + Vector2(post * 2.0 - 8.0 * u, -6.0 * u), 10.0 * u), FRAME)
	first = b.verts.size()
	b.fan(Face.Builder.round_rect(d.position + Vector2(4.0 * u, 6.0 * u), d.size - Vector2(8.0 * u, 12.0 * u), 6.0 * u), Color.WHITE)
	CardFace.shade(b, first, PANEL, PANEL_LOW, d.position.y, d.end.y)
	# the panel's boards
	var bx := d.position.x + 70.0 * u
	while bx < d.end.x - 20.0 * u:
		b.polygon(_rect(bx, d.position.y + 8.0 * u, bx + 2.0 * u, d.end.y - 8.0 * u), Color(PANEL_LOW, 0.8))
		bx += 90.0 * u
	var crown := Rect2(d.position.x - post - 18.0 * u, d.position.y - 30.0 * u, d.size.x + post * 2.0 + 36.0 * u, 34.0 * u)
	b.fan(Face.Builder.round_rect(crown.position + Vector2(0.0, 6.0 * u), crown.size, 8.0 * u), FRAME_DEEP)
	b.fan(Face.Builder.round_rect(crown.position, crown.size, 8.0 * u), CROWN)
	# the counter the dresser stands on, to past the foot
	b.polygon(_rect(-8.0, _counter - 6.0 * u, w + 8.0, _counter + 18.0 * u), COUNTER_TOP)
	first = b.verts.size()
	b.polygon(_rect(-8.0, _counter + 16.0 * u, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, COUNTER, COUNTER_LOW, _counter, h)
	var y := _counter + 120.0 * u
	while y < h + 60.0 * u:
		b.polygon(_rect(-8.0, y, w + 8.0, y + 3.0 * u), Color(COUNTER_LOW, 0.7))
		y += 140.0 * u
	_shown = b.mesh()
	queue_redraw()

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
