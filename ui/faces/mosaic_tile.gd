extends RefCounted

## The three things the flat Nonogram draws on a cell, as builder shapes
## rather than as Controls: an empty socket, a laid tile and the pebble that
## rules a cell out. They are static because both users batch them -- the
## board puts eighty-one of them into one mesh, and the tray draws two into
## its own -- and a Control per cell would be eighty-one nodes for a drawing
## with no face on it.
##
## Each takes its scale as a Vector2 and, for the pieces, a turn about the
## centre, so a drawn tile can pop in with the family's squash, sink under the
## finger, wobble under Check and shrink out with the quarter turn -- the
## motion vocabulary read as curves (docs/art/flat-motion.md, rule 8) -- and
## a blush level, so it can flash toward the family's rose where a node would
## take `Motion.flash`.
##
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#nonogram: `tile` and `pebble`), so the game
## and the mock stay the same drawing. Every measure is a fraction of the
## cell `s`.
## Spec: docs/superpowers/specs/2026-09-18-nonogram-flat-design.md, section 5.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The socket: the cell's own square, inset a little so a grid of them reads
## as sockets in a floor rather than as one sheet of stone.
const SOCKET_INSET := 0.03
const SOCKET_SIZE := 0.94
const SOCKET_RADIUS := 0.1
## How far a socket sunk under the finger goes toward the floor's line
## colour at the bottom of its press, so the sink reads on pale stone.
const SINK_SHADE := 0.35

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
## How far a blushing tile goes toward BAD_TILE at the top of its flash: slate
## to full pale rose is a flashbulb, and seven tenths reads as a blush.
const BLUSH := 0.7

const PEBBLE_Y := 0.02
const PEBBLE_R := 0.11
const PEBBLE_ALPHA := 0.95
const GLINT_AT := Vector2(-0.03, -0.02)
const GLINT_R := 0.045
const GLINT_ALPHA := 0.35
## The pebble's soft shadow on the socket: the family's disc, a little below
## and wider than the pebble.
const PEBBLE_SHADOW_Y := 0.06
const PEBBLE_SHADOW := Vector2(1.5, 0.9)
const PEBBLE_SHADOW_A := 0.2

## An empty cell, or one ruled out (`out`). `at` is the cell's top-left.
## `sink` is press_scale's value: below one the socket shrinks about its
## centre and darkens toward the floor's line, the way a stone under a finger
## does.
static func socket(b, at: Vector2, s: float, out: bool, alpha: float, sink := 1.0) -> void:
	var col: Color = Pal.SOCKET_OUT if out else Pal.SOCKET
	var box := Vector2.ONE * (s * SOCKET_SIZE)
	var corner := at + Vector2.ONE * (s * SOCKET_INSET)
	if sink < 1.0:
		var depth := clampf((1.0 - sink) / 0.06, 0.0, 1.0)
		col = col.lerp(Pal.LINE, SINK_SHADE * depth)
		corner += box * (1.0 - sink) * 0.5
		box *= sink
	b.fan(Face.Builder.round_rect(corner, box, s * SOCKET_RADIUS * sink), Color(col, alpha))

## A laid tile, centred on `at`, drawn at `grow` of its size (x across, y
## down, so the pop's squash reads) and turned `angle` about its centre.
## `grout` runs 0 to 1 as the win closes the gaps up: closing the gap is not
## enough on its own, because four rounded corners meeting leave a
## star-shaped hole of parchment, so the radius comes down with the inset
## and the picture becomes one shape rather than a field of tiles. The
## highlight goes with it -- eighty of them left on a finished picture read
## as noise across it rather than as relief. `blush` is flash_level's value,
## toward the family's rose.
static func tile(b, at: Vector2, s: float, grow: Vector2, held: bool,
		grout: float, alpha: float, angle := 0.0, blush := 0.0) -> void:
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var face: Color = Pal.MOSAIC_LOCK if held else Pal.MOSAIC
	var deep: Color = Pal.MOSAIC_LOCK_DEEP if held else Pal.MOSAIC_DEEP
	if blush > 0.0:
		face = face.lerp(Pal.BAD_TILE, blush * BLUSH)
		deep = deep.lerp(Pal.BAD, blush * BLUSH * 0.6)
	var inset := s * lerpf(GROUT_OPEN, GROUT_SHUT, grout)
	var radius := s * lerpf(RADIUS_OPEN, RADIUS_SHUT, grout)
	var edge := s * lerpf(EDGE_OPEN, EDGE_SHUT, grout)
	var corner := -Vector2.ONE * (s * 0.5) + Vector2.ONE * inset
	var box := Vector2.ONE * (s - 2.0 * inset)
	var xf := Transform2D(angle, grow, 0.0, at)
	b.fan(xf * Face.Builder.round_rect(corner, box, radius), Color(deep, alpha))
	b.fan(xf * Face.Builder.round_rect(corner, box - Vector2(0.0, edge), radius),
		Color(face, alpha))
	var glint := HI_ALPHA * (1.0 - grout) * alpha
	if glint > 0.0:
		b.fan(xf * Face.Builder.round_rect(HI_AT * s, HI_SIZE * s, HI_RADIUS * s),
			Color(Pal.MOSAIC_HI, glint))

## The pebble on a ruled-out cell, centred on `at`, over its own soft shadow.
## The socket under it has already gone a shade darker: the ruling-out reads
## twice, because on a hard board more than half the grid ends up like this
## and it has to stay distinct from ground nobody has looked at. `grow` and
## `angle` as the tile's; a pebble is round, so the turn only carries its
## glint round with it.
static func pebble(b, at: Vector2, s: float, grow: Vector2, alpha: float, angle := 0.0) -> void:
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var xf := Transform2D(angle, grow, 0.0, at)
	var r := PEBBLE_R * s
	Scenery.soft_disc(b, at + Vector2(0.0, PEBBLE_Y * s + PEBBLE_SHADOW_Y * s) * grow.y,
		r * PEBBLE_SHADOW.x * grow.x, r * PEBBLE_SHADOW.y * grow.y,
		Color(Pal.TEXT, PEBBLE_SHADOW_A * alpha))
	b.fan(xf * Face.Builder.ring(Vector2(0.0, PEBBLE_Y * s), r, r),
		Color(Pal.SOCKET_PEBBLE, PEBBLE_ALPHA * alpha))
	b.fan(xf * Face.Builder.ring(GLINT_AT * s, GLINT_R * s, GLINT_R * s),
		Color(1.0, 1.0, 1.0, GLINT_ALPHA * alpha))
