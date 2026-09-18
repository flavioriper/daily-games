extends RefCounted

## The three things the flat Nonogram draws on a cell, as builder shapes
## rather than as Controls: an empty socket, a laid tile and the pebble that
## rules a cell out. They are static because both users batch them -- the
## board puts eighty-one of them into one mesh, and the tray draws two into
## its own -- and a Control per cell would be eighty-one nodes for a drawing
## with no face on it.
##
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#nonogram: `tile` and `pebble`), so the game
## and the mock stay the same drawing. Every measure is a fraction of the
## cell `s`.
## Spec: docs/superpowers/specs/2026-09-18-nonogram-flat-design.md, section 5.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

## The socket: the cell's own square, inset a little so a grid of them reads
## as sockets in a floor rather than as one sheet of stone.
const SOCKET_INSET := 0.03
const SOCKET_SIZE := 0.94
const SOCKET_RADIUS := 0.1

## A tile's grout: the gap it leaves round itself and the radius of its
## corners, open while the board is being worked and closed on the win.
const GROUT_OPEN := 0.045
const GROUT_SHUT := 0.004
const RADIUS_OPEN := 0.13
const RADIUS_SHUT := 0.015
## Its bottom edge, the soft lip every card on these screens wears.
const EDGE_OPEN := 0.05
const EDGE_SHUT := 0.01
const HI_AT := Vector2(-0.3, -0.32)
const HI_SIZE := Vector2(0.28, 0.1)
const HI_RADIUS := 0.04
const HI_ALPHA := 0.5

const PEBBLE_Y := 0.02
const PEBBLE_R := 0.11
const PEBBLE_ALPHA := 0.95
const GLINT_AT := Vector2(-0.03, -0.02)
const GLINT_R := 0.045
const GLINT_ALPHA := 0.35

## An empty cell, or one ruled out (`out`). `at` is the cell's top-left.
static func socket(b, at: Vector2, s: float, out: bool, alpha: float) -> void:
	var col: Color = Pal.SOCKET_OUT if out else Pal.SOCKET
	b.fan(Face.Builder.round_rect(at + Vector2.ONE * (s * SOCKET_INSET),
		Vector2.ONE * (s * SOCKET_SIZE), s * SOCKET_RADIUS), Color(col, alpha))

## A laid tile, centred on `at` and drawn `grow` of its size. `grout` runs 0
## to 1 as the win closes the gaps up: closing the gap is not enough on its
## own, because four rounded corners meeting leave a star-shaped hole of
## parchment, so the radius comes down with the inset and the picture becomes
## one shape rather than a field of tiles. The highlight goes with it --
## eighty of them left on a finished picture read as noise across it rather
## than as relief.
static func tile(b, at: Vector2, s: float, grow: float, held: bool,
		grout: float, alpha: float) -> void:
	var side := s * grow
	if side <= 0.0:
		return
	var face: Color = Pal.MOSAIC_LOCK if held else Pal.MOSAIC
	var deep: Color = Pal.MOSAIC_LOCK_DEEP if held else Pal.MOSAIC_DEEP
	var inset := side * lerpf(GROUT_OPEN, GROUT_SHUT, grout)
	var radius := side * lerpf(RADIUS_OPEN, RADIUS_SHUT, grout)
	var edge := side * lerpf(EDGE_OPEN, EDGE_SHUT, grout)
	var corner := at - Vector2.ONE * (side * 0.5) + Vector2.ONE * inset
	var box := Vector2.ONE * (side - 2.0 * inset)
	b.fan(Face.Builder.round_rect(corner, box, radius), Color(deep, alpha))
	b.fan(Face.Builder.round_rect(corner, box - Vector2(0.0, edge), radius),
		Color(face, alpha))
	var glint := HI_ALPHA * (1.0 - grout) * alpha
	if glint > 0.0:
		b.fan(Face.Builder.round_rect(at + HI_AT * side, HI_SIZE * side,
			HI_RADIUS * side), Color(Pal.MOSAIC_HI, glint))

## The pebble on a ruled-out cell, centred on `at`. The socket under it has
## already gone a shade darker: the ruling-out reads twice, because on a hard
## board more than half the grid ends up like this and it has to stay
## distinct from ground nobody has looked at.
static func pebble(b, at: Vector2, s: float, grow: float, alpha: float) -> void:
	var side := s * grow
	if side <= 0.0:
		return
	b.disc(at + Vector2(0.0, PEBBLE_Y * side), PEBBLE_R * side,
		Color(Pal.SOCKET_PEBBLE, PEBBLE_ALPHA * alpha))
	b.disc(at + GLINT_AT * side, GLINT_R * side,
		Color(1.0, 1.0, 1.0, GLINT_ALPHA * alpha))
