extends "res://ui/menu/cards/card_face.gd"

## Hedgehogs' card: a fresh lawn over the whole paper and no grid. On the
## right one big leaf pile, the board's own heap at near three cells wide,
## with the hedgehog asleep at its foot (the one live child) under two leaves
## that have slid onto its back, and the board's flag pushed in beside it.
## Left of it a loose run of the lawn: two raked patches stacked, each
## reading 1, and one pile still lying on its turf. The numbers are counted
## in code from where the hedgehog is, and the flag answers both, so the pile
## is proved empty. The go button is the rake poised over that pile: a wooden
## handle in from the bottom left and a broad head in the card's colour with
## a chevron, lifted over its shadow, its tines on the leaves.
##
## Everything still is one mesh in ui/faces/leaf_pile.gd's builders; the two
## numerals are `draw_string`s over it, as the board writes them.

const Board = preload("res://puzzles/hedgehogs2d.gd")
const LeafPile = preload("res://ui/faces/leaf_pile.gd")
const HedgehogFace = preload("res://ui/faces/hedgehog_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row and the width the card was drawn for (puzzle_card_2d.gd's CARD_H
## and the grid's column): the picture scales with the lesser of the two, so
## a taller card of the same width never pushes the rake's handle off the
## paper.
const H := 246.0
const W := 490.0
## The big pile: the cell it is drawn as, and its middle from the card's
## right side and foot.
const HERO := 168.0
const HERO_IN := Vector2(112.0, 92.0)
const HERO_ID := 7
## The hedgehog's seat and where it sits from the pile's middle; the two
## leaves on its back, from its own middle: [offset, length, angle, colour].
const SEAT := 96.0
const HOG_AT := Vector2(-40.0, 30.0)
const BACK_LEAVES := [[Vector2(17.0, -23.5), 34.0, 0.5, 0], [Vector2(30.0, -5.5), 29.0, -0.7, 2]]
## The flag: its size and where it is pushed in, from the pile's middle.
const FLAG_R := 35.0
const FLAG_AT := Vector2(53.0, -27.0)
## The loose run: a cell, the gap between two, the run's last column from
## the card's right side and its low row from the foot.
const CELL := 54.0
const PITCH := 57.0
const RUN_IN := 230.0
const FOOT := 7.0
## Where things are on the lawn's own grid: the sleeper, the raked cells and
## the pile the numbers clear.
const HOGS: Array[Vector2i] = [Vector2i(2, 1)]
const RAKED: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 0)]
const SAFE := Vector2i(0, 1)
## The safe pile, wider than its cell so it reads at card size.
const PILE := 1.18
## The rake, in cells: where its head stands from the safe pile's middle,
## how it leans, the head's length and breadth, its tines and its handle.
const RAKE_AT := Vector2(-0.78, -0.1)
const RAKE_LEAN := -0.16
const HEAD := Vector2(0.72, 1.2)
const HEAD_ROUND := 0.2
const TINES := 5
const TINE := 0.34
const HANDLE := 2.15
const GO_LIFT := 0.1
const GO_SHADOW := 0.22
## The words' margin and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0
## Fallen leaves on the bare lawn: [from the right, from the top, length,
## angle, colour, kind].
const LITTER := [[158.0, 30.0, 24.0, 0.5, 0, 1], [226.0, 100.0, 20.0, -0.9, 2, 0], [26.0, 122.0, 22.0, 2.2, 1, 2]]

## The lawn: a fresh leaf green over a deeper one, a pool of shade under the
## big pile, and the blurb's ink on it.
const LAWN_TOP := Color("eaf3d8")
const LAWN_LOW := Color("d3e5b5")
const POOL := Color("b9d596")
const BLADE := Color("b4d08f")
const BLURB := Color("5f6e4a")

## The two counts, kept for `_draw`: [middle, text, ink].
var _nums: Array = []

## A leaf or two laid over a child, since the mesh lies under every child.
class Over extends Control:
	var mesh: ArrayMesh
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, null)

func _k() -> float:
	return minf(size.y / H, size.x / W)

func _cell() -> float:
	return CELL * _k()

func _hero() -> Vector2:
	return size - HERO_IN * _k()

## The middle of a cell of the loose run.
func _mid(cell: Vector2i) -> Vector2:
	var k := _k()
	return Vector2(size.x - (RUN_IN + float(1 - cell.x) * PITCH) * k,
		size.y - (FOOT + CELL * 0.5 + float(1 - cell.y) * PITCH) * k)

static func _touches(a: Vector2i, z: Vector2i) -> bool:
	var d := (z - a).abs()
	return a != z and d.x <= 1 and d.y <= 1

## The board's count: the hedgehogs in the eight cells round `cell`.
static func _count(cell: Vector2i) -> int:
	var n := 0
	for hog: Vector2i in HOGS:
		if _touches(cell, hog):
			n += 1
	return n

## A raked cell touching `cell` whose count its flagged neighbours already
## meet: the board's proof that `cell` hides nothing. Every hedgehog on the
## card is flagged.
static func _proved(cell: Vector2i) -> bool:
	if HOGS.has(cell):
		return false
	for r: Vector2i in RAKED:
		if _touches(r, cell) and _count(r) > 0:
			return true
	return false

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var c := _cell()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, LAWN_TOP, LAWN_LOW, 0.0, size.y)
	var hero := _hero()
	Scenery.soft_disc(b, hero + Vector2(-6.0, 26.0) * k, HERO * 0.66 * k, HERO * 0.3 * k, Color(POOL, 0.55))
	# A few blades, and the leaves the wind left.
	for i in 5:
		var at := Vector2(size.x - (40.0 + float(i) * 97.0 + LeafPile.h01(i, 3) * 30.0) * k,
			size.y - (14.0 + LeafPile.h01(i, 8) * 12.0) * k)
		if at.x < SIDE:
			continue
		b.stroke(PackedVector2Array([at, at + Vector2(-2.5, -8.0) * k]), 2.4 * k, BLADE, false, false)
		b.stroke(PackedVector2Array([at, at + Vector2(2.5, -9.0) * k]), 2.4 * k, BLADE, false, false)
	for l: Array in LITTER:
		var at := Vector2(size.x - float(l[0]) * k, float(l[1]) * k)
		LeafPile.leaf(b, at, float(l[2]) * k, float(l[3]), Pal.AUTUMN_LEAVES[int(l[4])], int(l[5]))
	# The loose run: the raked patches, then the pile still on its turf.
	_nums.clear()
	for cell: Vector2i in RAKED:
		var at := _mid(cell)
		b.fan(Face.Builder.round_rect(at - Vector2.ONE * c * 0.47 + Vector2(0.0, c * 0.07), Vector2.ONE * c * 0.94,
			c * LeafPile.RADIUS), Color(Pal.LAWN_DEEP, 0.4))
		LeafPile.ground(b, at, c, cell.y * 4 + cell.x, true, false)
		var v := _count(cell)
		if v > 0:
			_nums.append([at, str(v), Pal.NUM_INK[mini(v, Pal.NUM_INK.size() - 1)]])
	var safe := _mid(SAFE)
	LeafPile.ground(b, safe, c, 4, false, false)
	LeafPile.pile(b, safe, c * PILE, 4)
	# The big pile and its flag.
	LeafPile.pile(b, hero, HERO * k, HERO_ID)
	LeafPile.flag(b, hero + FLAG_AT * k, FLAG_R * k)
	if not soon and _proved(SAFE):
		_go(b, safe + RAKE_AT * c, c)

## The rake, its head's middle at `at`: the handle away to the low left, the
## head in the card's colour across it, the tines on past it.
func _go(b: Face.Builder, at: Vector2, c: float) -> void:
	var up := Vector2(0.0, -c * GO_LIFT)
	var xf := Transform2D(RAKE_LEAN, at + up)
	var half := HEAD * c * 0.5
	Scenery.soft_disc(b, at + Vector2(0.0, c * 0.14), half.x * 1.5, half.y * 0.62, Color(Pal.TEXT, GO_SHADOW))
	Scenery.soft_disc(b, at + Vector2(-c * HANDLE * 0.5, c * 0.3), c * HANDLE * 0.5, c * 0.1, Color(Pal.TEXT, GO_SHADOW * 0.6))
	# The handle, with a lit line along it.
	var handle := xf * PackedVector2Array([Vector2(-c * HANDLE, 0.0), Vector2(0.0, 0.0)])
	b.stroke(handle, c * 0.2, Pal.BARK.darkened(0.18))
	b.stroke(handle, c * 0.13, Pal.BARK.lightened(0.12))
	# The tines, under the head.
	var deep := colour.darkened(0.3)
	for i in TINES:
		var y := lerpf(-half.y * 0.76, half.y * 0.76, float(i) / float(TINES - 1))
		b.stroke(xf * PackedVector2Array([Vector2(half.x * 0.5, y), Vector2(half.x + c * TINE, y)]), c * 0.11, deep)
	var plate := Face.Builder.round_rect(-half, half * 2.0, c * HEAD_ROUND)
	b.polygon(Transform2D(RAKE_LEAN, at + up + Vector2(0.0, c * 0.08)) * plate, colour.darkened(0.26))
	b.polygon(xf * plate, colour)
	b.polygon(xf * Face.Builder.round_rect(-half * 0.74, Vector2(half.x * 0.6, half.y * 1.48), c * 0.1),
		Color(Pal.SURFACE, 0.16))
	var h := c * 0.2
	b.stroke(xf * PackedVector2Array([Vector2(-h * 0.5, -h), Vector2(h * 0.6, 0.0), Vector2(-h * 0.5, h)]),
		c * 0.12, Pal.SURFACE)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell() * Board.NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	for n in _nums:
		var wide := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, n[0] + Vector2(-wide * 0.5, rise), n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, n[2])

func _lay() -> void:
	var k := _k()
	var seat := SEAT * k
	var at := _hero() + HOG_AT * k
	var hog := HedgehogFace.new()
	hog.expression = Face.Expr.SLEEPY
	hog.size = Vector2(seat, seat)
	hog.position = at - hog.size * 0.5
	_keep(hog)
	hog.set_idle(true)
	# The leaves that slid onto its back.
	var over := Over.new()
	var b := Face.Builder.new()
	for l: Array in BACK_LEAVES:
		LeafPile.leaf(b, at + (l[0] as Vector2) * k, float(l[1]) * k, float(l[2]), Pal.AUTUMN_LEAVES[int(l[3])],
			LeafPile.Kind.MAPLE if int(l[3]) == 0 else LeafPile.Kind.OAK)
	over.mesh = b.mesh()
	over.size = size
	_keep(over)
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * k)
