extends RefCounted

## Pearl Dive's own shapes, as builder calls rather than a Control: the board
## bakes them into its meshes and the menu card into its own
## (puzzles/pearl2d.gd, ui/menu/card_art.gd). Marks, not characters: a diving
## bell on its rope, the shell that holds the pearl, a bubble.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

## The water, from the light under the surface to the dark over the sand.
const SEA := [Color("8fd0f0"), Color("5fb0e8"), Color("2f8fd6"), Color("236fb4"), Color("1b4f8c"), Color("163a69")]
const SAND := Color("e8d3a2")
const SAND_DEEP := Color("cdb37c")
const BRASS := Color("e0b04e")
const BRASS_DEEP := Color("b98728")
const SHELL := Color("f3c9c4")
const SHELL_DEEP := Color("d99a98")
const NACRE := Color("fffaf0")
const NACRE_SHADE := Color("e6dccb")

## What an answer of each tier is painted in: common, known, rare, deep, and
## the Pearl. Hues apart, not shades of one, and a mark each on the pips.
const TIER := [Color("a8977f"), Color("4f8a31"), Color("2f8fd6"), Color("6273c0"), Color("d88a12")]
const TIER_TILE := [Color("f1e6d2"), Color("e6f0da"), Color("dcedf9"), Color("e9ecfa"), Color("fff1d6")]

static func tier(t: int) -> Color:
	return Pal.BERRY_DEEP if t < 0 else TIER[clampi(t, 0, 4)]

static func tier_tile(t: int) -> Color:
	return Pal.BERRY_TILE if t < 0 else TIER_TILE[clampi(t, 0, 4)]

## A diving bell of radius `r` about `at`: a brass dome with a round window,
## a band at its foot and the ring its rope ties to.
static func bell(b: Face.Builder, at: Vector2, r: float, alpha := 1.0) -> void:
	var brass := Color(BRASS, alpha)
	var deep := Color(BRASS_DEEP, alpha)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, -1.0) * r, 0.2 * r, 0.0, TAU), 0.1 * r, deep, true)
	var dome := PackedVector2Array([at + Vector2(-0.82, 0.62) * r])
	dome.append_array(Face.Builder.bezier3(at + Vector2(-0.82, 0.62) * r, at + Vector2(-0.86, -0.5) * r,
		at + Vector2(-0.5, -0.9) * r, at + Vector2(0.0, -0.9) * r))
	dome.append_array(Face.Builder.bezier3(at + Vector2(0.0, -0.9) * r, at + Vector2(0.5, -0.9) * r,
		at + Vector2(0.86, -0.5) * r, at + Vector2(0.82, 0.62) * r))
	b.polygon(dome, brass)
	b.fan(Face.Builder.round_rect(at + Vector2(-0.96, 0.52) * r, Vector2(1.92, 0.34) * r, 0.14 * r), deep)
	b.disc(at + Vector2(0.0, -0.08) * r, 0.4 * r, deep)
	b.disc(at + Vector2(0.0, -0.08) * r, 0.29 * r, Color(SEA[0], alpha))
	b.disc(at + Vector2(-0.1, -0.18) * r, 0.09 * r, Color(NACRE, alpha))

## The pearl in its open shell, `r` the pearl's own radius.
static func shell(b: Face.Builder, at: Vector2, r: float, alpha := 1.0) -> void:
	var lip := PackedVector2Array()
	lip.append_array(Face.Builder.arc_points(at + Vector2(0.0, 0.5) * r, 1.7 * r, PI, TAU))
	b.polygon(lip, Color(SHELL_DEEP, alpha))
	var bowl := PackedVector2Array()
	bowl.append_array(Face.Builder.arc_points(at + Vector2(0.0, 0.5) * r, 1.7 * r, 0.0, PI))
	b.polygon(bowl, Color(SHELL, alpha))
	for k in 3:
		var x := (k - 1) * 0.75 * r
		b.stroke(PackedVector2Array([at + Vector2(x * 0.5, 0.75 * r), at + Vector2(x, 1.75 * r)]),
			0.1 * r, Color(SHELL_DEEP, alpha * 0.8))
	pearl(b, at, r, alpha)

## The pearl alone.
static func pearl(b: Face.Builder, at: Vector2, r: float, alpha := 1.0) -> void:
	b.disc(at, r, Color(NACRE_SHADE, alpha))
	b.disc(at + Vector2(-0.08, -0.08) * r, 0.86 * r, Color(NACRE, alpha))
	b.disc(at + Vector2(-0.34, -0.36) * r, 0.2 * r, Color(Color.WHITE, alpha))

## A bubble: a ring with a glint.
static func bubble(b: Face.Builder, at: Vector2, r: float, alpha := 1.0) -> void:
	b.stroke(Face.Builder.arc_points(at, r, 0.0, TAU), maxf(1.5, 0.22 * r), Color(Color.WHITE, alpha * 0.7), true)
	b.disc(at + Vector2(-0.35, -0.35) * r, 0.2 * r, Color(Color.WHITE, alpha * 0.9))

static func tick(b: Face.Builder, at: Vector2, r: float, colour: Color) -> void:
	b.stroke(PackedVector2Array([at + Vector2(-0.5, 0.02) * r, at + Vector2(-0.12, 0.4) * r,
		at + Vector2(0.52, -0.38) * r]), 0.24 * r, colour)

static func cross(b: Face.Builder, at: Vector2, r: float, colour: Color) -> void:
	for s: float in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([at + Vector2(-0.4, -0.4 * s) * r, at + Vector2(0.4, 0.4 * s) * r]),
			0.24 * r, colour)

## A prompt's pip by what it came to, so a tier is told by its mark as well
## as its colour: a cross for dry, a dot that grows with the depth, and the
## pearl itself.
static func pip(b: Face.Builder, at: Vector2, r: float, t: int) -> void:
	if t < 0:
		cross(b, at, r, Pal.BERRY_DEEP)
	elif t >= 4:
		b.disc(at, r, TIER[4])
		pearl(b, at, r * 0.62)
	else:
		b.disc(at, r, TIER[t])
		if t >= 1:
			b.disc(at, r * (0.62 - 0.14 * t), NACRE)
