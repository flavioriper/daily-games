extends Control

## Biscuit Tin's world: a kitchen table edge to edge under the board and the
## host's rows (CLAUDE.md: a game's world fills the screen). A cream cloth
## with a soft blue check, pale enough that the wordmark, the motto and the
## tools row read as ink over it with no scrim; a cup of tea and a sugar
## bowl at the foot, clear of the tin.
##
## The board says where the tin stands and where its count ends
## (`set_lines`). One mesh, built when the rect or a line changes and kept
## (`_shown`) until the next replaces it, drawn past the top of the rect for
## the win. The lid, the plate, the tin and the pieces are the board's.

const Face = preload("res://ui/faces/face.gd")
const Art = preload("res://ui/faces/biscuit_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const W := 1080.0
## How far past the top the cloth is drawn, as a share of the height.
const OVER := 0.6

var _tin := Rect2()
var _foot := 0.0
var _built := ""
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## The tin's outer rect, and the foot of what the board draws (0 on a
## tutorial page: no cup, no bowl).
func set_lines(tin: Rect2, foot: float) -> void:
	_tin = tin
	_foot = foot
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var key := "%d:%d:%s:%d" % [roundi(size.x), roundi(size.y), str(_tin), roundi(_foot)]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var b := Face.Builder.new()
	var top := -size.y * OVER
	var cloth := Face.Builder.new()
	Art.cloth(cloth, Vector2(size.x + 16.0, size.y * (1.0 + OVER) + 80.0), u)
	b.append(cloth.mesh(), Transform2D(0.0, Vector2(-8.0, top)))
	# the cup and the bowl at the foot, where there is room under the tin
	if _foot > 0.0:
		var r := 70.0 * u
		var y := clampf(_foot + r * 1.6, _tin.end.y + r * 1.1, size.y + r * 0.35)
		if y - r > _tin.end.y:
			Scenery.cup(b, Vector2(size.x * 0.12, y), r)
			Art.sugar(b, Vector2(size.x * 0.88, y + r * 0.15), r * 0.8)
	_shown = b.mesh()
	queue_redraw()
