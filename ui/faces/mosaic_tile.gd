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
## The bevel (the second polish, 2026-09-25): the crown sits BEVEL of a cell
## down and in from the tile's rim, and the rim round it is the face lifted
## RIM_LIGHT toward MOSAIC_HI, so a tile is lit from above along its top and
## sides. It replaced a single highlight dash, which on a 9x9 read as eighty
## small marks rather than as eighty raised tiles.
const BEVEL := 0.06
const RIM_LIGHT := 0.5
## A hand-laid floor: `tone` runs -1 to 1 per tile, off a hash the board owns,
## and moves the face this far lighter or darker.
const TONE := 0.05
## How far a shining tile goes toward GLAZE_LIT at the top of a glint. Paper
## and sun were both tried and both read as the picture going grey -- a warm
## light over a cool glaze mixes to a dead midtone -- so the glint stays in the
## glaze's own hue, the way light on a glazed tile does.
const SHINE := 0.6
const GLAZE_LIT := Color("aebfe0")
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
## does. `tint` washes the socket toward its colour by its alpha: the row and
## the column under the finger.
static func socket(b, at: Vector2, s: float, out: bool, alpha: float, sink := 1.0,
		tint := Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var col: Color = Pal.SOCKET_OUT if out else Pal.SOCKET
	if tint.a > 0.0:
		col = col.lerp(Color(tint, 1.0), tint.a)
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
		grout: float, alpha: float, angle := 0.0, blush := 0.0, tone := 0.0, shine := 0.0) -> void:
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var face: Color = Pal.MOSAIC_LOCK if held else Pal.MOSAIC
	var deep: Color = Pal.MOSAIC_LOCK_DEEP if held else Pal.MOSAIC_DEEP
	if tone > 0.0:
		face = face.lightened(tone * TONE)
	elif tone < 0.0:
		face = face.darkened(-tone * TONE)
	if blush > 0.0:
		face = face.lerp(Pal.BAD_TILE, blush * BLUSH)
		deep = deep.lerp(Pal.BAD, blush * BLUSH * 0.6)
	var rim := face.lerp(Pal.MOSAIC_HI, RIM_LIGHT * (1.0 - grout))
	if shine > 0.0:
		face = face.lerp(GLAZE_LIT, shine * SHINE)
		rim = rim.lerp(GLAZE_LIT, shine * SHINE)
	var inset := s * lerpf(GROUT_OPEN, GROUT_SHUT, grout)
	var radius := s * lerpf(RADIUS_OPEN, RADIUS_SHUT, grout)
	var edge := s * lerpf(EDGE_OPEN, EDGE_SHUT, grout)
	var corner := -Vector2.ONE * (s * 0.5) + Vector2.ONE * inset
	var box := Vector2.ONE * (s - 2.0 * inset)
	var xf := Transform2D(angle, grow, 0.0, at)
	b.fan(xf * Face.Builder.round_rect(corner, box, radius), Color(deep, alpha))
	b.fan(xf * Face.Builder.round_rect(corner, box - Vector2(0.0, edge), radius),
		Color(rim, alpha))
	var bev := s * BEVEL * (1.0 - grout)
	if bev > 0.5:
		b.fan(xf * Face.Builder.round_rect(corner + Vector2(bev * 0.7, bev),
			box - Vector2(bev * 1.4, edge + bev), maxf(radius - bev * 0.5, 0.0)),
			Color(face, alpha))

## A letter centred in the cell, taking the piece's own `grow` so it squashes
## with the tile it is on. Hidden Word's only addition to this file. `at` is
## the cell's CENTRE here, like `tile` and `pebble` and unlike `socket`,
## which takes the top-left corner -- a letter is always drawn on a tile, so
## it has to share that tile's anchor or the two land half a cell apart. `b`
## is the board's own `CanvasItem`, not the `Face.Builder` its neighbours
## take: a letter is a draw command (`draw_set_transform` then
## `font.draw_string`) and is never baked into the floor mesh, so it has to
## be called from the board's own `_draw()`, the way Nonogram draws its clue
## numbers, rather than from inside the mesh builder.
const LETTER_SIZE := 0.56
static func letter(b, at: Vector2, s: float, ch: String, grow: Vector2,
		col: Color, font: Font, alpha := 1.0) -> void:
	if ch.is_empty() or alpha <= 0.0 or grow.x <= 0.0 or grow.y <= 0.0:
		return
	var size := int(s * LETTER_SIZE)
	var text := ch.to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var h := font.get_height(size)
	var where := Vector2(-w * 0.5, h * 0.5 - font.get_descent(size))
	b.draw_set_transform(at, 0.0, grow)
	font.draw_string(b.get_canvas_item(), where, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, alpha))
	b.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
