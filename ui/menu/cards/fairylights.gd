extends "res://ui/menu/cards/card_face.gd"

## Fairy Lights' card: a garden at night under one string of lights. The wire
## comes in from the left edge and is strung across the top of the card in
## shallow swags, a garden lantern hanging lit from the low point of each;
## short of the seal's corner it drops down the right side to a stone low
## right, and that stone is the go button: a paving stone in the card's
## colour whose elbow sits a quarter turn off, west and south where the wire
## wants north and west. One tap turns a piece a quarter turn clockwise, so
## one tap joins it. Past it the wire is cold, and the lantern at its end,
## beside the stone, is dark. The name stands under the swags in cream; a
## hedge runs the foot.
##
## Everything is one mesh: the lanterns are the board's own (LanternFace in
## its `iron` style), baked at rest, the lit ones with their own halo. The
## wire is the board's cable in small -- the glow under the live run in the
## board's three passes, a shade, a face and a back, a bead at every hook --
## hung rather than laid, because here it is seen from the lawn and not from
## above. No rays: halos, beads and a few motes.

const Board = preload("res://puzzles/fairy_lights2d.gd")
const LanternFace = preload("res://ui/faces/lantern_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
const SIDE := 22.0
## The go stone's cell at H, and where its middle stands from the bottom
## right corner.
const CELL := 66.0
const GO_IN := Vector2(58.0, 60.0)
## The stone inside its cell, its corner and its lip, in cells.
const STONE_SIDE := 0.94
const STONE_ROUND := 0.17
const STONE_LIP := 0.07
## The hooks the wire hangs from: how far down, how far each swag sags, how
## long a swag may be before the string takes another lantern, and how far
## from the right edge the last hook is (clear of the seal's corner).
const HOOK_Y := 24.0
const SAG := 12.0
const SWAG := 170.0
const LAST_IN := 102.0
const LANTERNS_MIN := 3
## A lantern's R at H, the thread it hangs by, and how far its ring's top
## is above its middle, in R.
const LANTERN_R := 20.0
const THREAD := 3.0
const RING_TOP := 1.37
## How far left of the go stone's edge the dark lantern stands.
const DARK_OUT := 44.0
## The wire's shade under its face, in wire widths.
const SHADE := 0.4
## The words: where they start, and the gap they keep from the dark lantern.
const WORDS_TOP := 92.0
const WORDS_GAP := 14.0

## The night: sky over lawn, the hedge's two rows, the inks.
const SKY := Color("1c3540")
const LAWN := Color("2c5854")
const HEDGE_FAR := Color("244a49")
const HEDGE := Color("1a3639")
const INK := Color("fbf1dc")
const INK_DIM := Color("b4cbc4")
## A wire the light has not reached, pale enough to be read on the night and
## on the go stone; its shade.
const COLD := Color("c3ced2")
const COLD_DEEP := Color("73828a")
## What the dark lantern is tinted by: the night on its glass.
const DARK_TINT := Color(0.74, 0.8, 0.88)
## The motes round a lit lantern, [offset in R, radius at H].
const MOTES := [
	[Vector2(1.7, 0.7), 2.2], [Vector2(-1.6, -0.5), 1.6],
	[Vector2(-1.8, 0.9), 2.0], [Vector2(1.5, -0.7), 1.5],
]

func _k() -> float:
	return size.y / H

func _cell() -> float:
	return CELL * _k()

func _go_mid() -> Vector2:
	return size - GO_IN * _k()

func _wire() -> float:
	return _cell() * Board.WIRE * 0.82

## The dark lantern's middle: on the cold wire, west of the go stone.
func _dark_mid() -> Vector2:
	var g := _go_mid()
	return Vector2(g.x - _cell() * 0.5 - DARK_OUT * _k(), g.y)

## The hooks, left to right: the first on the card's left edge, under the
## corner's curve, the last where the wire lets go and drops.
func _hooks() -> PackedVector2Array:
	var k := _k()
	var first := Vector2(EDGE + 2.0, maxf(HOOK_Y * k + 8.0, RADIUS + 4.0))
	var last := Vector2(size.x - LAST_IN * k, HOOK_Y * k)
	var n := maxi(LANTERNS_MIN, int(floor((last.x - first.x) / (SWAG * k))))
	var hooks := PackedVector2Array([first])
	for i in range(1, n + 1):
		hooks.append(Vector2(lerpf(first.x, last.x, float(i) / float(n)), last.y))
	return hooks

## Where each lit lantern hangs from: the low point of its swag.
func _hangs(hooks: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in hooks.size() - 1:
		out.append((hooks[i] + hooks[i + 1]) * 0.5 + Vector2(0.0, SAG * _k()))
	return out

## The live run: every swag, then the drop to the go stone's top edge.
func _live(hooks: PackedVector2Array) -> PackedVector2Array:
	var k := _k()
	var pts := PackedVector2Array()
	for i in hooks.size() - 1:
		var swag := Face.Builder.bezier2(hooks[i], (hooks[i] + hooks[i + 1]) * 0.5 + Vector2(0.0, SAG * 2.0 * k),
			hooks[i + 1], 12)
		if i > 0:
			swag.remove_at(0)
		pts.append_array(swag)
		if pts[pts.size() - 1] != hooks[i + 1]:
			pts.append(hooks[i + 1])
	var from := hooks[hooks.size() - 1]
	var to := _go_mid() - Vector2(0.0, _cell() * 0.5 + _wire() * 0.2)
	var drop := Face.Builder.bezier2(from, Vector2(from.x + 2.0 * k, lerpf(from.y, to.y, 0.72)), to, 16)
	drop.remove_at(0)
	pts.append_array(drop)
	if pts[pts.size() - 1] != to:
		pts.append(to)
	return pts

## `pts` in `colour`, as much of it as lies on the paper.
func _on_paper(b: Face.Builder, paper: PackedVector2Array, pts: PackedVector2Array, colour: Color) -> void:
	for part in Geometry2D.intersect_polygons(paper, pts):
		b.polygon(part, colour)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var c := _cell()
	var w := _wire()
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, SKY, LAWN, 0.0, size.y)
	# The hedge along the foot, a far row and a near one.
	var step := 74.0 * k
	var x := -step * 0.3
	while x < size.x + step:
		_on_paper(b, paper, Face.Builder.ring(Vector2(x + step * 0.5, size.y + 4.0 * k), 50.0 * k, 34.0 * k), HEDGE_FAR)
		x += step
	x = -step * 0.7
	while x < size.x + step:
		_on_paper(b, paper, Face.Builder.ring(Vector2(x, size.y + 8.0 * k), 46.0 * k, 28.0 * k), HEDGE)
		x += step * 0.86
	var hooks := _hooks()
	var hangs := _hangs(hooks)
	var live := _live(hooks)
	var go := _go_mid()
	var dark := _dark_mid()
	var drop := Vector2(0.0, w * SHADE)
	# The live run as the board lays one: the glow under it, widest first,
	# then its shade, its face and the lit back.
	for g in Board.GLOWS:
		b.stroke(live, w * g.x, Color(Pal.SUN_RAY, g.y), false, false)
	# Flat at the card's edge, so nothing of it stands off the paper, and a
	# round end where it stops short of the stone.
	var end := live[live.size() - 1]
	b.stroke(_moved(live, drop), w, Pal.SUN_DEEP, false, false)
	Board._dot(b, end + drop, w * 0.5, Pal.SUN_DEEP)
	b.stroke(live, w, Pal.SUN, false, false)
	Board._dot(b, end, w * 0.5, Pal.SUN)
	b.stroke(live, w * Board.SHEEN, Color(Pal.LANTERN_LIT, Board.SHEEN_ALPHA), false, false)
	# A bead at every hook past the edge, and one where the run stops short.
	for i in range(1, hooks.size()):
		_bead(b, hooks[i], w * Board.BEAD * 0.7)
	_bead(b, end, w * Board.BEAD * 0.7)
	# The lit lanterns, each on its thread, and their motes.
	var R := LANTERN_R * k
	for i in hangs.size():
		var mid := hangs[i] + Vector2(0.0, THREAD * k + RING_TOP * R)
		b.stroke(PackedVector2Array([hangs[i], mid - Vector2(0.0, RING_TOP * R)]), maxf(1.5, 1.6 * k), Pal.LANTERN)
		_lantern(b, mid, R, i, true)
		for j in 2:
			var mote: Array = MOTES[(i * 2 + j) % MOTES.size()]
			var at: Vector2 = mid + mote[0] * R
			Scenery.soft_disc(b, at, mote[1] * k * 2.4, mote[1] * k * 2.4, Color(Pal.SUN_RAY, 0.3))
			Board._dot(b, at, mote[1] * k * 0.6, Color(Pal.SUN_SPARK, 0.9))
	# The cold wire from the go stone's west edge to the dark lantern.
	var cold := PackedVector2Array([Vector2(go.x - c * 0.5, go.y), dark])
	b.stroke(_moved(cold, drop), w, COLD_DEEP)
	b.stroke(cold, w, COLD)
	b.stroke(_moved(cold, Vector2(0.0, -w * Board.TOP_RISE)), w * Board.TOP, Color(Pal.SURFACE, Board.TOP_ALPHA))
	_go(b, go, c, w)
	_lantern(b, dark, R, hangs.size() + 1, false)

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	return Transform2D(0.0, by) * pts

## The board's bead: a bright point in its own small halo.
func _bead(b: Face.Builder, at: Vector2, r: float) -> void:
	Scenery.soft_disc(b, at, r * Board.BEAD_GLOW, r * Board.BEAD_GLOW, Color(Pal.LANTERN_LIT, Board.BEAD_GLOW_ALPHA))
	Board._dot(b, at, r, Pal.LANTERN_LIT.lerp(Color.WHITE, 0.5))

## The board's garden lantern about `mid`, baked at rest: lit with its halo
## and its face, or dark, plain and washed as the board keeps an unlit one.
func _lantern(b: Face.Builder, mid: Vector2, R: float, hue: int, lit: bool) -> void:
	var lantern := LanternFace.new()
	lantern.iron = true
	lantern.casts = false
	lantern.hue = hue
	lantern.lit = 1.0 if lit else 0.0
	lantern.dims = not lit
	lantern.plain = not lit
	if lit:
		lantern.expression = Face.Expr.JOY
	lantern.size = Vector2.ONE * (R * LanternFace.SEAT)
	lantern.bake_into(b, Transform2D(0.0, mid - lantern.size * 0.5), Color.WHITE if lit else DARK_TINT, true)
	lantern.free()

## The go stone about `at`: a paving stone in the card's colour over its own
## shadow, its elbow a quarter turn off -- west, where it meets the cold
## wire, and south, a loose end -- and a turn mark in the quarter the elbow
## leaves bare. A card not yet open keeps the stone, cold, and no mark.
func _go(b: Face.Builder, at: Vector2, c: float, w: float) -> void:
	var side := c * STONE_SIDE
	var corner := at - Vector2.ONE * (side * 0.5)
	var lip := c * STONE_LIP
	var face := colour.lerp(Pal.FLAGSTONE, 0.7) if soon else colour
	Scenery.soft_disc(b, at + Vector2(0.0, side * 0.46), side * 0.62, side * 0.2, Color(0.0, 0.0, 0.0, 0.28))
	b.polygon(Face.Builder.round_rect(corner, Vector2.ONE * side, c * STONE_ROUND), face.darkened(0.3))
	b.polygon(Face.Builder.round_rect(corner, Vector2(side, side - lip), c * STONE_ROUND), face)
	b.polygon(Face.Builder.round_rect(corner + Vector2.ONE * (c * 0.05), Vector2(side - c * 0.1, c * 0.16), c * 0.08),
		Color(1.0, 1.0, 1.0, 0.1))
	# The elbow: one stroke west to the stone's edge, round the middle, and
	# south to a loose end, as the board draws an end that meets nothing.
	var half := c * 0.5
	var elbow := PackedVector2Array([at + Vector2(-side * 0.5, 0.0), at, at + Vector2(0.0, half * Board.LOOSE)])
	var drop := Vector2(0.0, w * SHADE)
	b.stroke(_moved(elbow, drop), w, COLD_DEEP)
	b.stroke(elbow, w, COLD)
	b.stroke(_moved(elbow, Vector2(0.0, -w * Board.TOP_RISE)), w * Board.TOP, Color(Pal.SURFACE, Board.TOP_ALPHA))
	if soon:
		return
	# The turn: a quarter arc clockwise through the bare north-east quarter,
	# from where the wire arrives to where the elbow would go, and its head.
	var r := c * 0.25
	var arc := Face.Builder.arc_points(at, r, -PI * 0.5 + 0.25, -0.32)
	b.stroke(arc, c * 0.075, Pal.SURFACE)
	var tip := at + Vector2.from_angle(-0.02) * r
	var h := c * 0.1
	b.polygon(PackedVector2Array([tip + Vector2(-h, -h * 0.9), tip + Vector2(h, -h * 0.9), tip + Vector2(0.0, h * 0.7)]),
		Pal.SURFACE)

func _lay() -> void:
	var k := _k()
	var room := _dark_mid().x - LANTERN_R * k - WORDS_GAP * k - SIDE
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, room, INK, INK_DIM)
	words.position.y = roundf(WORDS_TOP * k)
