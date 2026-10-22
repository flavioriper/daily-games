extends RefCounted

## The house's domino, face up: builder shapes, not a Control, as
## ui/faces/patch_cloth.gd is, because a board bakes a dozen of them into
## its meshes. One drawing for Versus Dominoes (versus/dominoes_board.gd)
## and Domino Patio (puzzles/patio2d.gd) and both their menu cards; lifted
## out of the Versus board on 2026-10-22, unchanged.
##
## A tile is ivory over its own deeper side and a soft shadow, a line across
## its middle with a brass pin, and each half's spots in their number's
## colour (a three is found by its blue before it is counted; the count
## still says it). A double wears a brass rim. Everything is drawn about the
## origin in a space where half a tile is the square `H`.

const Face = preload("res://ui/faces/face.gd")

## Half a tile, a square, in the drawing's own space.
const H := 100.0
const IVORY := Color("f7f0df")
const IVORY_EDGE := Color("cbbb97")
const IVORY_LIT := Color("fffaf0")
const INK := Color("2c2a33")
const BRASS := Color("d9a441")
## A number's spots, 1 to 6: berry, leaf, dusk blue, pumpkin, plum, teal.
const SPOTS := [Color("2c2a33"), Color("bf4a44"), Color("4f8a31"), Color("5567b8"),
	Color("c86f22"), Color("8a5aa8"), Color("2f7f7a")]

## One tile face up about `at`: `first` on the half toward -x (or -y when
## `upright`), `second` on the other, a brass rim when `double`.
static func face(b: Face.Builder, first: int, second: int, upright: bool, double: bool, at := Vector2.ZERO) -> void:
	var sz := Vector2(H, 2.0 * H) if upright else Vector2(2.0 * H, H)
	var body := sz - Vector2(8.0, 8.0)
	var o := at - body * 0.5
	b.fan(Face.Builder.round_rect(o + Vector2(1.0, 9.0), body, 16.0), Color(0.1, 0.06, 0.02, 0.26))
	b.fan(Face.Builder.round_rect(o + Vector2(0.0, 5.0), body, 16.0), IVORY_EDGE)
	b.fan(Face.Builder.round_rect(o, body, 16.0), IVORY)
	var rim := Color(BRASS, 0.95) if double else Color(IVORY_LIT, 0.9)
	b.stroke(Face.Builder.round_rect(o + Vector2(5.0, 5.0), body - Vector2(10.0, 10.0), 12.0), 3.0, rim, true)
	var along := Vector2(0.0, 1.0) if upright else Vector2(1.0, 0.0)
	var cross := Vector2(along.y, along.x)
	b.stroke(PackedVector2Array([at + cross * -30.0, at + cross * 30.0]), 4.0, Color(INK, 0.75))
	b.disc(at + Vector2(0.0, 1.0), 8.0, BRASS.darkened(0.25))
	b.disc(at, 7.0, BRASS)
	b.disc(at + Vector2(-2.0, -2.0), 2.5, Color(1, 1, 1, 0.6))
	spots(b, at + along * -H * 0.5, first, upright)
	spots(b, at + along * H * 0.5, second, upright)

## A half's spots about `c`: the die's patterns, the six in two lines along
## the tile. `k` scales the pattern, `grow` the spots alone.
static func spots(b: Face.Builder, c: Vector2, n: int, upright: bool, k := 1.0, grow := 1.0) -> void:
	var g := 25.0 * k
	var r := k * grow
	var at: Array = []
	if n % 2 == 1:
		at.append(Vector2.ZERO)
	if n >= 2:
		at.append(Vector2(-g, -g))
		at.append(Vector2(g, g))
	if n >= 4:
		at.append(Vector2(g, -g))
		at.append(Vector2(-g, g))
	if n == 6:
		at.append(Vector2(-g, 0.0))
		at.append(Vector2(g, 0.0))
	for p: Vector2 in at:
		var q := p if upright else Vector2(p.y, -p.x)
		b.disc(c + q + Vector2(0.0, 1.5) * r, 10.0 * r, Color(1, 1, 1, 0.6))
		b.disc(c + q, 9.5 * r, SPOTS[n])
		b.disc(c + q + Vector2(-3.0, -3.0) * r, 2.6 * r, Color(1, 1, 1, 0.32))
