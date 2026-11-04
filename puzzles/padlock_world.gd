extends Control

## Padlock's world: a garden shed door edge to edge under the board and the
## host's rows (CLAUDE.md: a game's world fills the screen). Pale painted
## boards, so the wordmark, the motto and the tools row read as ink over
## them with no scrim; an iron hasp bolted across where the lock hangs and
## the staple its shackle passes through; a nail under the lock for the key
## ring the found words' tags hang on; ivy up one edge and a watering can at
## the foot.
##
## The board says where the lock, the staple and the ring stand
## (`set_lines`). One mesh, built when the rect or a line changes and kept
## (`_shown`) until the next replaces it, drawn past the top of the rect for
## the win. The lock, its dials and the tags are the board's.

const Face = preload("res://ui/faces/face.gd")
const Art = preload("res://ui/faces/padlock_art.gd")

const W := 1080.0
## How far past the top the door is drawn, as a share of the height.
const OVER := 0.6

var _staple := Vector2.ZERO
var _staple_w := 0.0
var _nail := Vector2.ZERO
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

## Where the staple's middle is and how wide the hasp, where the key ring's
## nail is (none at Vector2.ZERO), and the foot of what the board draws
## (0 on a tutorial page: no can).
func set_lines(staple: Vector2, staple_w: float, nail: Vector2, foot: float) -> void:
	_staple = staple
	_staple_w = staple_w
	_nail = nail
	_foot = foot
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _staple_w <= 0.0:
		return
	var key := "%d:%d:%s:%d:%s:%d" % [roundi(size.x), roundi(size.y), str(Vector2i(_staple)), roundi(_staple_w), str(Vector2i(_nail)), roundi(_foot)]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var b := Face.Builder.new()
	var top := -size.y * OVER
	var door := Face.Builder.new()
	Art.door(door, Vector2(size.x + 16.0, size.y * (1.0 + OVER) + 80.0), u)
	b.append(door.mesh(), Transform2D(0.0, Vector2(-8.0, top)))
	Art.hasp(b, _staple + Vector2(0.0, _staple_w * 0.08), _staple_w)
	Art.staple(b, _staple, _staple_w)
	if _nail != Vector2.ZERO:
		b.disc(_nail, 9.0 * u, Art.IRON)
		b.disc(_nail - Vector2(2.0, 2.0) * u, 4.0 * u, Art.IRON_LIT)
	Art.ivy(b, 26.0 * u, size.y * 0.3, size.y + 20.0 * u, u, 1.0)
	# the can at the foot, clear of the board's lines (none on a tutorial page)
	if _foot > 0.0:
		var foot := clampf(_foot + 140.0 * u, size.y * 0.8, size.y - 16.0 * u)
		Art.can(b, Vector2(size.x - 150.0 * u, foot), 120.0 * u)
	_shown = b.mesh()
	queue_redraw()
