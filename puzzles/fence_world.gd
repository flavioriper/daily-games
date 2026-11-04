extends Control

## Garden Fence's world: a mown lawn edge to edge under the board and the
## host's rows (CLAUDE.md: a game's world fills the screen), pale enough
## that the wordmark, the motto and the tools row read as ink over it with
## no scrim; daisies and tufts about it, kept off the fenced bed.
##
## The board says where the bed stands (`set_keep`). One mesh, built when
## the rect or the bed changes and kept (`_shown`) until the next replaces
## it, drawn past the top of the rect for the win. The bed, its rail, the
## posts and the twine are the board's.

const Face = preload("res://ui/faces/face.gd")
const Art = preload("res://ui/faces/fence_art.gd")

const W := 1080.0
## How far past the top the lawn is drawn, as a share of the height.
const OVER := 0.6

var _keep := Rect2()
var _built := ""
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## The bed's outer rect, in the world's own coordinates.
func set_keep(keep: Rect2) -> void:
	_keep = keep
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var key := "%d:%d:%s" % [roundi(size.x), roundi(size.y), str(_keep)]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var top := -size.y * OVER
	var b := Face.Builder.new()
	var lawn := Face.Builder.new()
	var keep := _keep
	keep.position.y -= top
	Art.lawn(lawn, Vector2(size.x + 16.0, size.y * (1.0 + OVER) + 80.0), u, keep)
	b.append(lawn.mesh(), Transform2D(0.0, Vector2(-8.0, top)))
	_shown = b.mesh()
	queue_redraw()
