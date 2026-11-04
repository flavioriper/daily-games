extends Control

## Cross Stitch's world: a sewing table edge to edge under the board and
## the host's rows (CLAUDE.md: a game's world fills the screen). A
## papered wall behind it, where the wordmark, the motto and the tools
## row stand as ink with no scrim, the table's front edge just above the
## frame, the table's planks (Scenery.planks) with a linen runner across them, the
## sampler's wooden stretcher frame on it, the linen inside with its weave,
## a little cross-stitched flower in each of the sampler's four holes, and
## on the table at the foot two spools of thread and a tomato pincushion.
##
## The board says where the linen and the holes stand (`set_lines`). One
## mesh, built when the rect or a line changes and kept (`_shown`) until
## the next replaces it, drawn past the top of the rect for the win. The
## letter patches are the board's.

const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Art = preload("res://ui/faces/crossstitch_art.gd")

const W := 1080.0
const RUNNER := Color("efe4cc")
const WALL_HIGH := Color("f6ead2")
const WALL_LOW := Color("efdcbd")
const WALL_STRIPE := Color("ead2b0")
const RUNNER_EDGE := Color("d9c6a0")
## How far past the top the table is drawn, as a share of the height.
const OVER := 0.6

var _linen := Rect2()
var _holes: Array[Vector2] = []
var _tile := 0.0
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

## Where the linen lies, where its holes are, a patch's side, and the foot
## of what the board draws under it.
func set_lines(linen: Rect2, holes: Array[Vector2], tile: float, foot: float) -> void:
	_linen = linen
	_holes = holes
	_tile = tile
	_foot = foot
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _linen.size.x <= 0.0:
		return
	var key := "%d:%d:%s:%d:%d" % [roundi(size.x), roundi(size.y), str(Rect2i(_linen)), roundi(_tile), roundi(_foot)]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var b := Face.Builder.new()
	# the table, past the top for the win's slide
	var top := -size.y * OVER
	b.append(_planks(Vector2(size.x + 16.0, size.y * (1.0 + OVER) + 80.0)), Transform2D(0.0, Vector2(-8.0, top)))
	# the wall behind the table, papered in a soft stripe, so the title and
	# its motto read as ink over it; the table's edge just above the frame
	var edge := _linen.position.y - _tile * 0.85
	var first := b.verts.size()
	b.polygon(_box(Vector2(-8.0, top), Vector2(size.x + 16.0, edge - top)), Color.WHITE)
	Art._shade(b, first, WALL_HIGH, WALL_LOW, 0.0, edge)
	var x := 30.0 * u
	while x < size.x:
		b.polygon(_box(Vector2(x, top), Vector2(16.0 * u, edge - top)), Color(WALL_STRIPE, 0.5))
		x += 72.0 * u
	# the table's front edge
	b.polygon(_box(Vector2(-8.0, edge - 6.0 * u), Vector2(size.x + 16.0, 22.0 * u)), Color("8d5f3b"))
	b.polygon(_box(Vector2(-8.0, edge - 6.0 * u), Vector2(size.x + 16.0, 5.0 * u)), Color(1, 1, 1, 0.18))
	b.polygon(_box(Vector2(-8.0, edge + 16.0 * u), Vector2(size.x + 16.0, 10.0 * u)), Color(0.2, 0.1, 0.04, 0.22))
	# a linen runner across the table, under the frame
	var mid := _linen.get_center().y
	var rh := _linen.size.y * 0.78
	b.polygon(_box(Vector2(-8.0, mid - rh * 0.5 + 8.0 * u), Vector2(size.x + 16.0, rh)), Color(0.3, 0.18, 0.08, 0.18))
	b.polygon(_box(Vector2(-8.0, mid - rh * 0.5), Vector2(size.x + 16.0, rh)), RUNNER)
	for seam in [mid - rh * 0.5 + 14.0 * u, mid + rh * 0.5 - 14.0 * u]:
		var sx := 6.0 * u
		while sx < size.x:
			b.stroke(PackedVector2Array([Vector2(sx, seam), Vector2(sx + 14.0 * u, seam)]), 3.0 * u, RUNNER_EDGE)
			sx += 26.0 * u
	Art.frame(b, _linen, _tile * 0.24)
	Art.linen(b, _linen, maxf(8.0, _tile * 0.13))
	for h in _holes:
		Art.flower(b, h, _tile * 0.7)
	# the foot: spools and the pincushion, clear of the board's lines
	var foot := clampf(maxf(_foot + 150.0 * u, _linen.end.y + 230.0 * u), _linen.end.y + 150.0 * u, size.y - 20.0 * u)
	if foot < size.y + 60.0 * u:
		Art.cushion(b, Vector2(size.x - 140.0 * u, foot - 40.0 * u), 52.0 * u)
		Art.spool(b, Vector2(120.0 * u, foot), 120.0 * u, Art.ROSE)
		Art.spool(b, Vector2(215.0 * u, foot + 14.0 * u), 96.0 * u, Color("7d8fd9"))
	_shown = b.mesh()
	queue_redraw()

var _planks_mesh: ArrayMesh
var _planks_size := Vector2.ZERO

func _planks(sz: Vector2) -> ArrayMesh:
	if _planks_mesh == null or not _planks_size.is_equal_approx(sz):
		var pb := Face.Builder.new()
		Scenery.planks(pb, sz, 11)
		_planks_mesh = pb.mesh()
		_planks_size = sz
	return _planks_mesh

func _box(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])
