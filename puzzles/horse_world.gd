extends Control

## Horse Pen's world: a paddock on a clear morning, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## It is the menu card's picture (ui/menu/cards/horse.gd) at the size of the
## screen: a pale sky behind the wordmark, far hills going down behind the
## tools row, and pasture from there to the foot, lighter than the field so
## the field reads as the plot that is being penned.
##
## The foot is the yard: a stable with its half door at the left, a rail
## fence run out from it, a water trough, a stack of the board's own bales
## and a few windfall apples. The fields differ per level and Submit stands
## at the foot's right, so the board says where its field ends (`set_foot`)
## and the yard is sized to the band that is left, and kept to the left of
## the button.
##
## One mesh, built when the rect or the foot changes and kept (`_shown`)
## until the next replaces it; the pollen is a second, on a child whose
## alpha breathes (still under Motion.reduce). Nothing here has a face.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Parts = preload("res://ui/faces/horse_parts.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_TOP := Color("f3f8f4")
const SKY_LOW := Color("e9f4e6")
const FAR := Color("dcecca")
const FAR_NEAR := Color("d3e7bd")
const PASTURE_TOP := Color("e1f1d0")
const PASTURE_LOW := Color("c3dea4")
const MOWN := Color("b9d896")
const CLOUD := Color("fdfbf2")
const WOOD := Color("c9a474")
const WOOD_DEEP := Color("a98456")
const BARN := Color("dc9480")
const BARN_DEEP := Color("c57d6b")
const ROOF := Color("8d6152")
const TRIM := Color("f8efd8")
const DOOR := Color("7b5846")
const WATER := Color("a9d5ea")
const SHADE := Color("4f6b3a")
## Where the hills stand and the pasture begins, as shares of the height:
## behind the tools row, so the ink over the top has only sky under it.
const HORIZON := 0.262
## The low sun's rings behind the wordmark: [radius at W, alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[620.0, 0.10], [420.0, 0.12], [250.0, 0.16]]
## In the gap of the tools row, small: [x share, what]. They stand on the
## horizon.
const GAP_BALE := 0.385
const GAP_EAR := 0.470
const GAP_APPLE := 0.655
const GAP_CLOUD := Vector2(0.555, 0.222)
## The yard keeps to the left of Submit (the host's 260 button on its margin).
const YARD_RIGHT := 0.66
## The foot band the yard was drawn for; under YARD_MIN only grass is left.
const YARD_BAND := 190.0
const YARD_MIN := 96.0
## Pollen: [x, y as shares, radius at W].
const MOTES := [[0.33, 0.236, 5.0], [0.74, 0.228, 4.0], [0.045, 0.52, 4.5],
	[0.962, 0.61, 4.0], [0.52, 0.965, 4.5], [0.72, 0.985, 4.0]]
const BREATHE := 3.4
const BREATHE_LOW := 0.3

var _shown: ArrayMesh
var _motes: Control
var _motes_shown: ArrayMesh
var _breath: Tween
## Where the board's field ends, in this rect's pixels; under 0, unknown.
var _foot := -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes = Control.new()
	_motes.name = "Motes"
	_motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes.draw.connect(func() -> void:
		if _motes_shown != null:
			_motes.draw_mesh(_motes_shown, null))
	add_child(_motes)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_motes, "modulate:a", 1.0, BREATHE_LOW, BREATHE)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## The board's field ends at `y`: the yard is laid in what is left under it.
func set_foot(y: float) -> void:
	if absf(y - _foot) < 1.0:
		return
	_foot = y
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	var horizon := size.y * HORIZON
	# The sky under everything, and the low sun behind the wordmark.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, horizon + 8.0), Vector2(-8.0, horizon + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, SKY_TOP, SKY_LOW, 0.0, horizon)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	Scenery.cloud(b, GAP_CLOUD * size, 26.0 * u, CLOUD)
	# Two far hills going down behind the tools row.
	b.ellipse(Vector2(size.x * 0.22, horizon + 60.0 * u), size.x * 0.46, 104.0 * u, FAR)
	b.ellipse(Vector2(size.x * 0.80, horizon + 70.0 * u), size.x * 0.50, 108.0 * u, FAR_NEAR)
	# The pasture, to the foot.
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, horizon), Vector2(size.x + 8.0, horizon),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, PASTURE_TOP, PASTURE_LOW, horizon, size.y)
	# The things in the tools row's gap, on the horizon.
	Parts.shade(b, Vector2(size.x * GAP_BALE, horizon - 14.0 * u), 46.0 * u, 0.4, 0.12)
	Parts.bale(b, Vector2(size.x * GAP_BALE, horizon - 14.0 * u), 46.0 * u)
	Parts.wheat_ear(b, Vector2(size.x * GAP_EAR, horizon - 12.0 * u), 42.0 * u, Pal.WHEAT.darkened(0.12))
	Parts.apple(b, Vector2(size.x * GAP_APPLE, horizon - 8.0 * u), 44.0 * u)
	_yard(b, u)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		mb.disc(Vector2(m[0], m[1]) * size, m[2] * u, Color(Pal.SUN_RAY, 0.75))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## The foot: mown strips, tufts, and the yard where there is room for it.
func _yard(b: Face.Builder, u: float) -> void:
	var foot := _foot if _foot > 0.0 else size.y * 0.90
	var band := size.y - foot
	# Two soft mown rises along the very foot, under everything.
	b.ellipse(Vector2(size.x * 0.28, size.y + 70.0 * u), size.x * 0.60, 120.0 * u, Color(MOWN, 0.55))
	b.ellipse(Vector2(size.x * 0.84, size.y + 86.0 * u), size.x * 0.50, 120.0 * u, Color(MOWN, 0.45))
	for t in [[0.035, 0.30], [0.955, 0.42], [0.70, 0.92], [0.80, 0.96], [0.93, 0.93]]:
		Scenery.tuft(b, Vector2(size.x * float(t[0]), foot + band * float(t[1])), 20.0 * u)
	if band < YARD_MIN * u:
		return
	var k := clampf(band / (YARD_BAND * u), 0.5, 1.25) * 0.9 * u
	# The ground line the yard stands on: the stable's roof clears the field.
	var ground := foot + band * 0.86
	# The rail fence, run out from the stable to where Submit begins.
	var rail_from := size.x * 0.20
	var rail_to := size.x * YARD_RIGHT
	for rail in [0.42, 0.74]:
		var y: float = ground - 70.0 * k * float(rail)
		b.stroke(PackedVector2Array([Vector2(rail_from, y), Vector2(rail_to, y)]), 9.0 * k, WOOD, false, false)
		b.stroke(PackedVector2Array([Vector2(rail_from, y + 3.5 * k), Vector2(rail_to, y + 3.5 * k)]),
			2.0 * k, WOOD_DEEP, false, false)
	var posts := 5
	for i in posts:
		var x := lerpf(rail_from + 60.0 * k, rail_to, float(i) / float(posts - 1))
		b.fan(Face.Builder.round_rect(Vector2(x - 7.0 * k, ground - 70.0 * k), Vector2(14.0 * k, 72.0 * k), 5.0 * k), WOOD_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(x - 7.0 * k, ground - 70.0 * k), Vector2(10.0 * k, 72.0 * k), 5.0 * k), WOOD)
	_stable(b, Vector2(size.x * 0.105, ground), k)
	_trough(b, Vector2(size.x * 0.315, ground + 8.0 * k), k)
	# The stack: two of the board's bales and one on them.
	var s := 66.0 * k
	var stack := Vector2(size.x * 0.50, ground - s * 0.20)
	Parts.shade(b, stack + Vector2(0.0, s * 0.10), s * 2.0, 0.40, 0.14)
	Parts.bale(b, stack + Vector2(-s * 0.40, 0.0), s)
	Parts.bale(b, stack + Vector2(s * 0.40, 0.0), s)
	Parts.bale(b, stack + Vector2(0.0, -s * 0.62), s)
	# Windfalls by the last post.
	Parts.apple(b, Vector2(size.x * 0.60, ground + 6.0 * k), 40.0 * k)
	Parts.apple(b, Vector2(size.x * 0.632, ground + 14.0 * k), 34.0 * k)
	Scenery.tuft(b, Vector2(size.x * 0.225, ground + 12.0 * k), 22.0 * k)
	Scenery.tuft(b, Vector2(size.x * 0.415, ground + 14.0 * k), 20.0 * k)
	Scenery.tuft(b, Vector2(size.x * 0.565, ground + 16.0 * k), 18.0 * k)

## The stable's front, its foot on `at`: boards, a roof, a half door.
func _stable(b: Face.Builder, at: Vector2, k: float) -> void:
	var half := 84.0 * k
	var wall := 96.0 * k
	var rise := 50.0 * k
	Scenery.soft_disc(b, at + Vector2(0.0, 4.0 * k), half * 1.25, 14.0 * k, Color(SHADE, 0.22))
	b.polygon(PackedVector2Array([at + Vector2(-half, 0.0), at + Vector2(-half, -wall),
		at + Vector2(0.0, -wall - rise), at + Vector2(half, -wall), at + Vector2(half, 0.0)]), BARN)
	for x in [-0.5, 0.5]:
		b.stroke(PackedVector2Array([at + Vector2(half * float(x), -4.0 * k),
			at + Vector2(half * float(x), -wall - rise * 0.5)]), 2.0 * k, BARN_DEEP, false, false)
	# The roof, proud of the walls.
	b.stroke(PackedVector2Array([at + Vector2(-half - 12.0 * k, -wall + 6.0 * k),
		at + Vector2(0.0, -wall - rise - 4.0 * k), at + Vector2(half + 12.0 * k, -wall + 6.0 * k)]),
		15.0 * k, ROOF)
	# The hay loft's round window.
	b.disc(at + Vector2(0.0, -wall - 6.0 * k), 13.0 * k, TRIM)
	b.disc(at + Vector2(0.0, -wall - 6.0 * k), 8.5 * k, DOOR)
	# The half door: dark above, planks below, cream trim round it.
	var door := Vector2(66.0 * k, 78.0 * k)
	var corner := at + Vector2(-door.x * 0.5, -door.y)
	b.fan(Face.Builder.round_rect(corner - Vector2(5.0, 5.0) * k, door + Vector2(10.0, 5.0) * k, 8.0 * k), TRIM)
	b.fan(Face.Builder.round_rect(corner, door, 5.0 * k), DOOR)
	var low := Vector2(door.x, door.y * 0.52)
	b.fan(Face.Builder.round_rect(at + Vector2(-door.x * 0.5, -low.y), low, 4.0 * k), WOOD)
	b.stroke(PackedVector2Array([at + Vector2(-door.x * 0.5 + 5.0 * k, -low.y + 5.0 * k),
		at + Vector2(door.x * 0.5 - 5.0 * k, -5.0 * k)]), 4.0 * k, WOOD_DEEP)
	b.stroke(PackedVector2Array([at + Vector2(door.x * 0.5 - 5.0 * k, -low.y + 5.0 * k),
		at + Vector2(-door.x * 0.5 + 5.0 * k, -5.0 * k)]), 4.0 * k, WOOD_DEEP)

## A water trough, its foot on `at`.
func _trough(b: Face.Builder, at: Vector2, k: float) -> void:
	var half := 58.0 * k
	var tall := 34.0 * k
	Scenery.soft_disc(b, at + Vector2(0.0, 3.0 * k), half * 1.2, 9.0 * k, Color(SHADE, 0.2))
	for x in [-0.72, 0.72]:
		b.fan(Face.Builder.round_rect(at + Vector2(half * float(x) - 6.0 * k, -12.0 * k), Vector2(12.0, 14.0) * k, 3.0 * k), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-half, -tall - 6.0 * k), Vector2(half * 2.0, tall), 9.0 * k), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-half, -tall - 8.0 * k), Vector2(half * 2.0, tall * 0.62), 9.0 * k), WOOD)
	b.ellipse(at + Vector2(0.0, -tall - 2.0 * k), half - 9.0 * k, 7.0 * k, WATER)
	b.ellipse(at + Vector2(-half * 0.3, -tall - 3.0 * k), half * 0.22, 2.2 * k, Color(Color.WHITE, 0.7))
