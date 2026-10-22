extends Control

## Honeycomb's world: a summer meadow at the bottom of a garden, edge to
## edge under the board and the host's rows (CLAUDE.md: a game's world fills
## the screen). A warm sky across the top, where the wordmark, the motto and
## the win's "Well done!" are ink with no scrim, a soft sun and far hills;
## then the meadow from the horizon down, mown paler round where the comb
## lies, clover and daisies about it, lavender tufts at the sides, and a
## straw skep on a little stand at the foot on the left, its door dark.
##
## The board says where its lines stand (`set_lines`): the horizon and the
## foot of the keys. One mesh, built when the rect or a line changes and
## kept (`_shown`) until the next replaces it, drawn past the top of the rect
## for the win. The drifting bees are the board's.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Art = preload("res://ui/faces/honeycomb_art.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_HIGH := Color("f6e9c8")
const SKY_LOW := Color("fbf4e2")
const SUN := Color("fff1c8")
const HILL := Color("c9dca0")
const HILL_DEEP := Color("b2cd8a")
const MEADOW := Color("b9d488")
const MEADOW_LOW := Color("a4c574")
const MOWN := Color("c7de9a")
const CLOVER := Color("8fb860")
const DAISY := Color("fffdf6")
const DAISY_EYE := Color("f2b33d")
const LAVENDER := Color("a993cf")
const LAVENDER_DEEP := Color("8a74b4")
const STEM := Color("7fa84a")
const STRAW := Color("e1b866")
const STRAW_DEEP := Color("c39643")
const STRAW_LINE := Color("a97c32")
const STAND := Color("b4835a")
const STAND_DEEP := Color("926541")
## How far past the top the sky is drawn, as a share of the height.
const OVER := 0.6

var _horizon := 0.0
var _foot := 0.0
var _comb := Vector2.ZERO
var _comb_r := 0.0
var _built := ""
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the board's lines stand: the horizon, the comb's middle and reach,
## and the foot of the keys. The picture is built again only when one moved.
func set_lines(horizon: float, comb: Vector2, comb_r: float, foot: float) -> void:
	_horizon = horizon
	_comb = comb
	_comb_r = comb_r
	_foot = foot
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _horizon <= 0.0:
		return
	var key := "%d:%d:%d:%d:%d:%d" % [roundi(size.x), roundi(size.y), roundi(_horizon), roundi(_comb.y), roundi(_comb_r), roundi(_foot)]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, _horizon + 40.0 * u), Color.WHITE)
	CardFace.shade(b, first, SKY_HIGH, SKY_LOW, h * 0.04, _horizon)
	var sun := Vector2(w * 0.8, _horizon * 0.42)
	for ring: Array in [[240.0, 0.12], [160.0, 0.16], [100.0, 0.24]]:
		b.disc(sun, float(ring[0]) * u, Color(SUN, float(ring[1])))
	b.ellipse(Vector2(w * 0.18, _horizon + 10.0 * u), w * 0.5, 80.0 * u, HILL_DEEP)
	b.ellipse(Vector2(w * 0.85, _horizon + 20.0 * u), w * 0.55, 70.0 * u, HILL)
	# the meadow
	first = b.verts.size()
	b.polygon(_rect(-8.0, _horizon, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, MEADOW, MEADOW_LOW, _horizon, h)
	# the mown round where the comb lies
	if _comb_r > 0.0:
		Scenery.soft_disc(b, _comb + Vector2(0.0, _comb_r * 0.12), _comb_r * 1.28, _comb_r * 1.12, Color(MOWN, 0.85))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1022
	# clover and daisies, kept off the comb and the keys
	for i in 46:
		var p := Vector2(rng.randf_range(0.03, 0.97) * w, rng.randf_range(_horizon + 30.0 * u, h - 30.0 * u))
		if _comb_r > 0.0 and p.distance_to(_comb) < _comb_r * 1.35:
			continue
		if absf(p.y - (_foot - 70.0 * u)) < 90.0 * u and absf(p.x - w * 0.5) < 330.0 * u:
			continue
		if i % 3 == 0:
			_daisy(b, p, rng.randf_range(10.0, 15.0) * u)
		else:
			_clover(b, p, rng.randf_range(9.0, 13.0) * u)
	# lavender at the sides
	for side in [0.0, 1.0]:
		var x: float = lerpf(40.0, w / u - 40.0, side) * u
		_lavender(b, Vector2(x, _horizon + 110.0 * u), u * 0.8)
	_skep(b, Vector2(110.0 * u, maxf(_foot - 40.0 * u, _horizon + 260.0 * u)), u)
	_shown = b.mesh()
	queue_redraw()

func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	for k in 6:
		var a := TAU / 6.0 * k
		b.ellipse(at + Vector2(cos(a), sin(a)) * r * 0.6, r * 0.42, r * 0.42, DAISY)
	b.disc(at, r * 0.36, DAISY_EYE)

func _clover(b: Face.Builder, at: Vector2, r: float) -> void:
	for k in 3:
		var a := -PI * 0.5 + TAU / 3.0 * k
		b.disc(at + Vector2(cos(a), sin(a)) * r * 0.5, r * 0.5, CLOVER)

func _lavender(b: Face.Builder, root: Vector2, u: float) -> void:
	for k in 5:
		var x := root.x + (k - 2) * 16.0 * u
		var top := root.y - (90.0 + (k % 2) * 30.0) * u
		b.stroke(PackedVector2Array([Vector2(x, root.y), Vector2(x + (k - 2) * 4.0 * u, top)]), 4.0 * u, STEM)
		for j in 5:
			var y := top + j * 12.0 * u
			b.ellipse(Vector2(x + (k - 2) * 4.0 * u * (1.0 - j / 5.0), y), 7.0 * u, 8.0 * u, LAVENDER if j % 2 == 0 else LAVENDER_DEEP)

## A straw skep on a little wooden stand, its foot at `foot`.
func _skep(b: Face.Builder, foot: Vector2, u: float) -> void:
	Scenery.soft_disc(b, foot + Vector2(0.0, 6.0 * u), 110.0 * u, 18.0 * u, Color(STAND_DEEP, 0.3))
	b.polygon(_rect(foot.x - 70.0 * u, foot.y - 50.0 * u, foot.x - 56.0 * u, foot.y), STAND_DEEP)
	b.polygon(_rect(foot.x + 56.0 * u, foot.y - 50.0 * u, foot.x + 70.0 * u, foot.y), STAND_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(foot.x - 96.0 * u, foot.y - 66.0 * u), Vector2(192.0 * u, 22.0 * u), 8.0 * u), STAND)
	var base := foot.y - 66.0 * u
	# rings of straw, widest at the foot
	for k in 5:
		var rw := (90.0 - k * 13.0 - k * k * 1.6) * u
		var y := base - k * 30.0 * u
		b.ellipse(Vector2(foot.x, y - 14.0 * u), rw, 20.0 * u, STRAW_DEEP)
		b.ellipse(Vector2(foot.x, y - 17.0 * u), rw - 3.0 * u, 18.0 * u, STRAW)
		b.stroke(PackedVector2Array([Vector2(foot.x - rw * 0.7, y - 6.0 * u), Vector2(foot.x + rw * 0.7, y - 6.0 * u)]), 2.0 * u, Color(STRAW_LINE, 0.5))
	b.disc(Vector2(foot.x, base - 170.0 * u), 26.0 * u, STRAW)
	# the door
	b.fan(Face.Builder.round_rect(Vector2(foot.x - 20.0 * u, base - 30.0 * u), Vector2(40.0 * u, 28.0 * u), 14.0 * u), Color("5a3d22"))

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
