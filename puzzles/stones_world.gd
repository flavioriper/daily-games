extends Control

## Stepping Stones' world: a brook edge to edge under the board and the
## host's rows (CLAUDE.md: a game's world fills the screen). The near bank's
## pale grass under the wordmark, the motto and the tools row, so they read
## as ink over it with no scrim; the water between the banks, reeds and
## pebbles at its edges; the far bank's grass at the foot, above the phone's
## keyboard while it is up.
##
## The board says where the banks' edges are (`set_lines`). One mesh, built
## when the rect or a line changes and kept (`_shown`) until the next
## replaces it, drawn past the top of the rect for the win. The stones, the
## slabs and the current's streaks are the board's.

const Face = preload("res://ui/faces/face.gd")
const Art = preload("res://ui/faces/stones_art.gd")

const W := 1080.0
## How far past the top the grass is drawn, as a share of the height.
const OVER := 0.6

var _near := 0.0
var _far := 0.0
var _built := ""
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## The near bank's edge and the far bank's, in the board's y.
func set_lines(near: float, far: float) -> void:
	_near = near
	_far = far
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _far <= _near:
		return
	var key := "%d:%d:%d:%d" % [roundi(size.x), roundi(size.y), roundi(_near), roundi(_far)]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var b := Face.Builder.new()
	# the grass runs on past the top for the win's lift and under the
	# keyboard at the foot
	b.polygon(PackedVector2Array([Vector2(-8.0, -size.y * OVER), Vector2(size.x + 8.0, -size.y * OVER), Vector2(size.x + 8.0, size.y + 40.0), Vector2(-8.0, size.y + 40.0)]), Art.GRASS)
	Art.brook(b, Vector2(size.x, size.y), _near, _far, u)
	_shown = b.mesh()
	queue_redraw()
