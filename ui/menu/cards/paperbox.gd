extends "res://ui/menu/cards/card_face.gd"

## Paper Box's card: a corner of the green cutting mat on cream paper, a
## cross-shaped net of the six papers lying on it, and two paper boxes on
## the paper beside it: the box the net folds into, ringed in leaf, and in
## front the go button, a box in the card's colour with a cream stamp on its
## top.
##
## Everything is one mesh. Nothing lives on the card.

const Art = preload("res://ui/faces/paperbox_art.gd")
const Fold = preload("res://puzzles/paperbox_fold.gd")
const World = preload("res://puzzles/paperbox_world.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A net square at H, the boxes' size, their room from the card's right
## side and foot.
const CELL := 32.0
const BOX := 40.0
const RIGHT := 60.0
const FOOT := 40.0
const PAPER_TOP := Color("fdf6ea")
const PAPER_LOW := Color("f3e6d2")
## The card's net: the first cross, its colours by square.
const COLOURS := [0, 1, 2, 3, 4, 5]

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	# the mat's corner, kept inside the paper
	var mat := Rect2(size.x - (RIGHT + 300.0) * k, 26.0 * k, 190.0 * k, size.y - 52.0 * k)
	b.fan(Face.Builder.round_rect(mat.position + Vector2(0.0, 4.0 * k), mat.size, 14.0 * k), World.MAT_RIM)
	b.fan(Face.Builder.round_rect(mat.position, mat.size, 14.0 * k), World.MAT)
	var step := 18.0 * k
	var x := mat.position.x + step
	while x < mat.end.x - 4.0 * k:
		b.polygon(_rect(x - 0.6 * k, mat.position.y + 8.0 * k, x + 0.6 * k, mat.end.y - 8.0 * k), Color(World.MAT_LINE, 0.45))
		x += step
	var y := mat.position.y + step
	while y < mat.end.y - 4.0 * k:
		b.polygon(_rect(mat.position.x + 8.0 * k, y - 0.6 * k, mat.end.x - 8.0 * k, y + 0.6 * k), Color(World.MAT_LINE, 0.45))
		y += step
	# the net, turned upright on the mat
	var net := Fold.placed(1, 1, false)
	var ext := Fold.extent(net)
	var cell := CELL * k
	var centre := mat.get_center()
	var half := Vector2(ext) * 0.5
	var proj := func(p: Vector3) -> Vector2: return centre + (Vector2(p.x, p.y) - half) * cell
	for p: Vector2i in net:
		var c := centre + (Vector2(p) + Vector2(0.5, 0.5) - half) * cell + Vector2(3.0, 4.0) * k
		b.fan(Face.Builder.round_rect(c - Vector2.ONE * cell * 0.5, Vector2.ONE * cell, cell * 0.08), Color(0.15, 0.25, 0.18, 0.2))
	Art.sheet(b, Fold.frames(net, 0, 0.0), COLOURS, [-1, -1, -1, -1, -1, -1], proj, Vector3(0, 0, 1), maxf(1.0, cell * 0.04))
	# the box it folds into, ringed in leaf
	var sides := Fold.folded(net, 0, COLOURS, [-1, -1, -1, -1, -1, -1])
	var pic: Array = Fold.picture(sides, Fold.turns()[5])
	var s := BOX * k
	var at := Vector2(size.x - (RIGHT + 40.0) * k, size.y * 0.36)
	Art.shadow(b, at, s)
	b.stroke(Face.Builder.ring(at + Vector2(0.0, s * 0.05), s * 1.3, s * 1.3), maxf(2.0, s * 0.08), Pal.GOOD, true)
	Art.box(b, at, s, pic, maxf(1.0, s * 0.04))
	# the go button: a box in the card's colour, a cream stamp on its top
	var go := Vector2(size.x - (RIGHT + 20.0) * k, size.y - FOOT * k - s * 0.9)
	Art.shadow(b, go, s * 0.9)
	if soon:
		Art.box(b, go, s * 0.9, pic, maxf(1.0, s * 0.04))
	else:
		_go_box(b, go, s * 0.9)

## The go box: its three faces in the card's colour, lit as a paper box is.
func _go_box(b: Face.Builder, at: Vector2, s: float) -> void:
	var proj := func(p: Vector3) -> Vector2: return at + Fold.project(p) * s
	for slot in [2, 1, 0]:
		var n := Vector3(Fold.SHOWN[slot] as Vector3i)
		var u := Vector3(0, 1, 0) if slot == 1 else Vector3(1, 0, 0)
		var v := n.cross(u)
		var c := n * 0.5
		var pts := PackedVector2Array()
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			pts.append(proj.call(c + u * (q.x * 0.5) + v * (q.y * 0.5)))
		var k := Art.lit(n)
		var fill := colour.lerp(Color.WHITE, (k - 1.0) * 2.0) if k >= 1.0 else colour.darkened((1.0 - k) * 1.1)
		Art.face(b, pts, fill, colour.darkened(0.25), maxf(1.0, s * 0.04))
	Art.stamp(b, proj, Vector3(0, 0, 0.5), Vector3(1, 0, 0), Vector3(0, 1, 0))

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0)
	words.position.y = roundf(14.0 * _k())

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
