extends Control

## Marigold's world: the garden's evening, edge to edge under the arbor and
## the host's rows (CLAUDE.md: a game's world fills the screen). It is the
## menu card's picture (ui/menu/cards/marigold.gd) at the size of the
## screen: a pale lilac sky falling to a peach horizon behind one soft
## range, the pond from there down, and the green bank along the foot,
## where the spare pots stand, one tipped over with its seeds spilled, a
## seed packet, clover and daisies. The arbor (the board) stands in the
## middle of it; the sky and the pond show down its sides, with a cloud
## and a lily pad either side, and three small things of the garden lie in
## the gap of the tools row.
##
## The sky is light all the way down: the wordmark, the motto and the win's
## "Well done!" are ink. The foot is measured up from the bottom edge, so a
## taller screen keeps the bank under the arbor.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the fireflies are a second, on a child whose alpha breathes
## (still under Motion.reduce). Nothing here has a face. The colours are
## written here: this file does not load the board, which loads it.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Parts = preload("res://ui/faces/marigold_parts.gd")
const State = preload("res://puzzles/marigold_state.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## The card's dusk, a touch lighter still at the top.
const SKY_TOP := Color("eeebf9")
const SKY_LOW := Color("fbe8dc")
const RANGE := Color("dcd2ec")
const POND_TOP := Color("d3e3f5")
const POND_LOW := Color("b6cfec")
const SHINE := Color("e8f0fb")
const BANK := Color("a5c692")
const BANK_DEEP := Color("8fb77a")
const BANK_LIP := Color("c4dfae")
const REED := Color("7da36b")
const CLOUD := Color("f8f4fc")
const PACKET := Color("fbf3e2")
const PACKET_EDGE := Color("e4d3b4")
## The horizon and the bank's top, at W, up from the bottom edge.
const HORIZON_UP := 330.0
const BANK_UP := 104.0
## The sun's glow behind the wordmark: its middle as shares of the rect,
## and its rings as [radius at W, alpha].
const SUN_AT := Vector2(0.08, 0.02)
const SUN_RINGS := [[640.0, 0.08], [440.0, 0.09], [270.0, 0.12]]
## A cloud down each side of the arbor: [x, y as shares, radius at W].
const CLOUDS := [[0.018, 0.405, 44.0], [0.985, 0.560, 40.0]]
## The gap of the tools row, between the bin and Hint: a shut marigold, an
## open violet and a seed, small, since the win's "Well done!" stands under
## them.
const GAP_BUD := Vector2(0.400, 0.237)
const GAP_BLOOM := Vector2(0.585, 0.232)
const GAP_SEED := Vector2(0.675, 0.237)
## The pond's glints down the sides: [x as a share, y up from the bottom at
## W, length at W].
const GLINTS := [
	[0.012, 292.0, 36.0], [0.030, 236.0, 28.0], [0.008, 178.0, 30.0],
	[0.945, 300.0, 34.0], [0.958, 250.0, 26.0], [0.940, 150.0, 32.0],
]
## A lily pad either side: [x as a share, y up from the bottom at W, radius].
const PADS := [[0.040, 206.0, 26.0], [0.962, 196.0, 22.0]]
## The fireflies: [x, y as shares, radius at W]. Two keep the tools row's
## gap, two the arbor's sides and two the bank.
const FLIES := [
	[0.330, 0.226, 5.0], [0.760, 0.240, 4.5], [0.040, 0.640, 5.5],
	[0.962, 0.455, 5.0], [0.345, 0.962, 5.0], [0.660, 0.957, 4.5],
]
const BREATH := 3.2
const BREATH_LOW := 0.35

var _shown: ArrayMesh
var _flies: Control
var _flies_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flies = Control.new()
	_flies.name = "Fireflies"
	_flies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flies.draw.connect(func() -> void:
		if _flies_shown != null:
			_flies.draw_mesh(_flies_shown, null))
	add_child(_flies)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_flies, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var horizon := size.y - HORIZON_UP * u
	var bank := size.y - BANK_UP * u
	var b := Face.Builder.new()
	# The sky under everything, light to the horizon.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, horizon + 2.0), Vector2(-8.0, horizon + 2.0)]), Color.WHITE)
	CardFace.shade(b, first, SKY_TOP, SKY_LOW, size.y * 0.22, horizon)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, float(ring[0]) * u, Color(Pal.SUN_RAY, float(ring[1])))
	for c in CLOUDS:
		Scenery.cloud(b, Vector2(float(c[0]), float(c[1])) * size, float(c[2]) * u, CLOUD)
	# The far range standing on the horizon.
	var hills := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var x := size.x * float(i) / float(steps)
		var at := x / u
		var rise := 34.0 + 46.0 * absf(sin(at * 0.0062 + 1.3)) + 16.0 * sin(at * 0.0143 + 2.6)
		hills.append(Vector2(x, horizon - rise * u))
	hills.append(Vector2(size.x + 8.0, horizon + 2.0))
	hills.append(Vector2(-8.0, horizon + 2.0))
	b.polygon(hills, RANGE)
	# The pond, the far shore's pale band and its glints.
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, horizon), Vector2(size.x + 8.0, horizon),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, POND_TOP, POND_LOW, horizon, bank)
	b.fan(PackedVector2Array([Vector2(-8.0, horizon), Vector2(size.x + 8.0, horizon),
		Vector2(size.x + 8.0, horizon + 9.0 * u), Vector2(-8.0, horizon + 9.0 * u)]), Color(SHINE, 0.6))
	for g in GLINTS:
		var at := Vector2(size.x * float(g[0]), size.y - float(g[1]) * u)
		var length := float(g[2]) * u
		b.stroke(PackedVector2Array([at, at + Vector2(length, 0.0)]), 4.0 * u, Color(SHINE, 0.8))
		b.stroke(PackedVector2Array([at + Vector2(length * 0.35, 11.0 * u), at + Vector2(length * 0.9, 11.0 * u)]),
			3.2 * u, Color(SHINE, 0.55))
	for p in PADS:
		var c := Vector2(size.x * float(p[0]), size.y - float(p[1]) * u)
		var r := float(p[2]) * u
		b.ellipse(c + Vector2(0.0, r * 0.08), r, r * 0.42, Color(POND_LOW.darkened(0.12), 0.6))
		b.ellipse(c, r, r * 0.4, Color(BANK_DEEP, 0.75))
		b.fan(PackedVector2Array([c, c + Vector2(r * 0.9, -r * 0.12), c + Vector2(r * 0.9, r * 0.2)]), POND_LOW)
	# Reeds at either edge, rising out of the bank.
	for side: float in [0.0, 1.0]:
		for k in 4:
			var x := (10.0 + float(k) * 13.0) * u if side == 0.0 else size.x - (10.0 + float(k) * 13.0) * u
			var top := bank - (96.0 - 17.0 * float(k % 3)) * u
			var tip := Vector2(x + (7.0 if side == 0.0 else -7.0) * u, top)
			b.stroke(PackedVector2Array([Vector2(x, bank + 6.0 * u), tip]), 4.0 * u, REED)
			if k % 2 == 0:
				b.ellipse(tip + Vector2(0.0, 14.0 * u), 4.5 * u, 13.0 * u, Pal.MG_ARBOR_DEEP)
	# The bank along the foot, its top a slow swell, and its lit lip.
	var crown := PackedVector2Array()
	steps = 36
	for i in steps + 1:
		var x := -8.0 + (size.x + 16.0) * float(i) / float(steps)
		crown.append(Vector2(x, bank + 5.0 * u * sin(x / u * 0.012 + 0.6)))
	var turf := crown.duplicate()
	turf.append(Vector2(size.x + 8.0, size.y + 8.0))
	turf.append(Vector2(-8.0, size.y + 8.0))
	first = b.verts.size()
	b.polygon(turf, Color.WHITE)
	CardFace.shade(b, first, BANK, BANK_DEEP, bank, size.y)
	b.stroke(crown, 4.0 * u, Color(BANK_LIP, 0.8), false, false)
	# Clover along the lip, a daisy on every other.
	for k in 15:
		var x := (38.0 + float(k) * 72.0 + 14.0 * sin(float(k) * 2.1)) * u
		var foot := Vector2(x, bank + (10.0 + 6.0 * absf(sin(float(k) * 1.7))) * u)
		for j in 3:
			var d := Vector2.from_angle(-PI * 0.5 + (float(j) - 1.0) * 0.6)
			Parts.leaf(b, foot, d, 12.0 * u, 4.4 * u, Pal.MG_GREEN_DEEP if j != 1 else Pal.MG_VINE)
		if k % 2 == 0:
			var head := foot + Vector2(4.0, -14.0) * u
			for j in 6:
				b.disc(head + Vector2.from_angle(TAU * float(j) / 6.0) * 4.6 * u, 3.3 * u, Color("fbf7ee"))
			b.disc(head, 2.9 * u, Pal.SUN_RAY)
	# A spare pot standing, a marigold grown in it, and one tipped over with
	# its seeds spilled.
	var stood := Vector2(size.x * 0.105, size.y - 66.0 * u)
	Scenery.soft_disc(b, stood + Vector2(0.0, 42.0 * u), 40.0 * u, 7.0 * u, Color(Pal.TEXT, 0.16))
	b.stroke(PackedVector2Array([stood + Vector2(0.0, 2.0 * u), stood + Vector2(2.0, -30.0) * u]), 3.6 * u, Pal.MG_VINE)
	Parts.leaf(b, stood + Vector2(1.0, -12.0) * u, Vector2(0.86, -0.5), 15.0 * u, 5.2 * u, Pal.MG_VINE_HI)
	Parts.leaf(b, stood + Vector2(1.0, -8.0) * u, Vector2(-0.86, -0.5), 14.0 * u, 5.0 * u, Pal.MG_VINE)
	Parts.bloom(b, stood + Vector2(2.0, -38.0) * u, 12.0 * u, State.ORANGE, 1.0)
	_pot(b, stood, 66.0 * u, 0.0)
	var tipped := Vector2(size.x * 0.235, size.y - 30.0 * u)
	Scenery.soft_disc(b, tipped + Vector2(-26.0, 20.0) * u, 38.0 * u, 6.0 * u, Color(Pal.TEXT, 0.14))
	_pot(b, tipped, 52.0 * u, -1.36)
	for k in 4:
		Parts.kernel(b, tipped + Vector2(20.0 + float(k) * 17.0, 8.0 + 9.0 * sin(float(k) * 2.3)) * u, 5.0 * u, 0.4 + float(k) * 1.1)
	# A seed packet leant on the bank at the right, a shut marigold beside it.
	var packet := Vector2(size.x * 0.845, size.y - 50.0 * u)
	var lean := Transform2D(0.2, packet)
	var paper := Face.Builder.new()
	paper.fan(Face.Builder.round_rect(Vector2(-27.0, -36.0) * u + Vector2(0.0, 3.0 * u), Vector2(54.0, 72.0) * u, 7.0 * u),
		Color(Pal.TEXT, 0.14))
	paper.fan(Face.Builder.round_rect(Vector2(-27.0, -36.0) * u, Vector2(54.0, 72.0) * u, 7.0 * u), PACKET_EDGE)
	paper.fan(Face.Builder.round_rect(Vector2(-23.0, -32.0) * u, Vector2(46.0, 64.0) * u, 5.0 * u), PACKET)
	paper.fan(Face.Builder.round_rect(Vector2(-23.0, -32.0) * u, Vector2(46.0, 12.0) * u, 5.0 * u), Color(Pal.MG_ORANGE_HI, 0.75))
	Parts.bloom(paper, Vector2(0.0, 6.0) * u, 9.5 * u, State.ORANGE, 1.0)
	b.append(paper.mesh(), lean)
	Parts.bud(b, Vector2(size.x * 0.925, size.y - 60.0 * u), 15.0 * u, State.ORANGE)
	for k in 2:
		Parts.kernel(b, Vector2(size.x * (0.765 + 0.028 * float(k)), size.y - (28.0 + 9.0 * float(k)) * u), 5.0 * u, 1.9 + float(k))
	for k in 7:
		Scenery.tuft(b, Vector2((84.0 + float(k) * 152.0 + 30.0 * sin(float(k) * 1.3)) * u, size.y - 6.0 * u), 20.0 * u)
	# The gap of the tools row.
	Parts.bud(b, GAP_BUD * size, 13.0 * u, State.ORANGE)
	Parts.bloom(b, GAP_BLOOM * size, 9.5 * u, State.PURPLE, 1.0)
	Parts.kernel(b, GAP_SEED * size, 5.5 * u, 0.5)
	_shown = b.mesh()
	queue_redraw()
	var fb := Face.Builder.new()
	for f in FLIES:
		var at := Vector2(float(f[0]), float(f[1])) * size
		var r := float(f[2]) * u
		fb.disc(at, r * 3.4, Color(Pal.SUN_RAY, 0.14))
		fb.disc(at, r * 2.0, Color(Pal.SUN_RAY, 0.26))
		fb.disc(at, r, Color("fff3b8"))
	_flies_shown = fb.mesh()
	_flies.size = size
	_flies.queue_redraw()

## The board's pot `w` wide, its rim's middle at `rim`, turned by `turn`.
func _pot(b: Face.Builder, rim: Vector2, w: float, turn: float) -> void:
	var part := Face.Builder.new()
	Parts.pot(part, w)
	b.append(part.mesh(), Transform2D(turn, rim))
