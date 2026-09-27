extends RefCounted

## Pixel Garden's drawing: a pegboard's bare peg, a bead seated on it, the
## rose halo Check strokes round a bead that is not where the picture wants
## it, and the little pixel a thumbnail is drawn in. Builder shapes and not a
## Control, for the reason ui/faces/patch_cloth.gd gives: the board bakes up
## to 256 beads into one mesh and the menu card draws a picture of them into
## another, and a node per bead would be a node per piece of a thing with no
## face on it.
##
## A bead is seen from straight above, as the reference draws it: a fat ring
## in its colour, a dark hole where the peg goes through, a lit arc on its
## upper left and a deeper rim at its foot. `fused` (0..1) is the win's iron
## passing over it: the hole closes to a dimple and a gloss comes up, which is
## what an ironed bead picture looks like.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## A bead's radius and its hole's, as fractions of a cell. 0.47 leaves the
## hair of board between two beads the reference shows.
const R := 0.47
const HOLE := 0.22
## A fused bead's dimple.
const HOLE_FUSED := 0.07
## A bare peg's radius.
const PEG := 0.15

## A bare peg on the board at `at`, a cell `s` wide: a soft shade, the post's
## foot, its lit top. `alpha` fades it (the win clears the bare pegs away).
static func peg(b, at: Vector2, s: float, alpha := 1.0, lit := 0.0) -> void:
	if alpha <= 0.0:
		return
	var r := s * PEG
	b.disc(at + Vector2(0.0, r * 0.35), r * 1.05, Color(Pal.PG_PEG_DEEP, alpha))
	b.disc(at, r, Color(Pal.PG_PEG.lerp(Pal.SUN, lit * 0.5), alpha))
	b.disc(at - Vector2(r, r) * 0.25, r * 0.55, Color(Pal.PG_PEG_HI.lerp(Color.WHITE, lit * 0.4), alpha))

## A bead of `colour` seated at `at`. `grow` scales it about its centre (the
## pop and the press), `lift` raises it off the board (a hint's drop) with its
## shade left behind, `fused` closes its hole, `shine` (0..1) washes it toward
## white for a passing glint.
static func bead(b, at: Vector2, s: float, colour: Color, grow := Vector2.ONE, alpha := 1.0,
		lift := 0.0, fused := 0.0, shine := 0.0, ground := Pal.PG_BOARD, peg_in := true) -> void:
	if alpha <= 0.0 or grow.x <= 0.0 or grow.y <= 0.0:
		return
	var rx := s * R * grow.x
	var ry := s * R * grow.y
	var c := colour.lerp(Color.WHITE, shine * 0.28)
	var deep := c.darkened(0.22)
	# The shade on the board, which stays put while the bead lifts.
	Scenery.soft_disc(b, at + Vector2(s * 0.03, s * 0.08), rx * 1.12, ry * 1.02,
		Color(Pal.TEXT, 0.22 * alpha * clampf(1.0 - lift / (s * 0.8), 0.3, 1.0)))
	var top := at - Vector2(0.0, lift)
	b.ellipse(top + Vector2(0.0, ry * 0.1), rx, ry, Color(deep, alpha))
	b.ellipse(top, rx * 0.97, ry * 0.95, Color(c, alpha))
	# The lit arc on the upper left and the deeper one on the lower right.
	var hi := PackedVector2Array()
	var lo := PackedVector2Array()
	for k in 9:
		var a1 := lerpf(PI * 1.05, PI * 1.62, k / 8.0)
		hi.append(top + Vector2(cos(a1) * rx, sin(a1) * ry) * 0.7)
		var a2 := lerpf(PI * 0.05, PI * 0.62, k / 8.0)
		lo.append(top + Vector2(cos(a2) * rx, sin(a2) * ry) * 0.72)
	b.stroke(hi, rx * 0.2, Color(c.lerp(Color.WHITE, 0.55), 0.8 * alpha))
	b.stroke(lo, rx * 0.16, Color(deep, 0.5 * alpha))
	# The hole goes right through: a bead is a tube, and what shows down it
	# is the board it sits on and the peg it is seated over -- the peg's top
	# pokes up through the middle, lit on its upper left. The tube's far wall
	# shows as a dark crescent along the top of the hole, and the mouth has a
	# bevel of the bead's deeper colour. Fusing melts the tube shut round the
	# peg: the hole closes to a dimple and the board and peg go out of sight.
	var hole := lerpf(HOLE, HOLE_FUSED, clampf(fused, 0.0, 1.0)) / R
	var hr := Vector2(rx, ry) * hole
	var hc := top + Vector2(0.0, ry * 0.02)
	var open := alpha * (1.0 - clampf(fused * 1.5, 0.0, 1.0))
	b.ellipse(hc, hr.x * 1.2, hr.y * 1.2, Color(deep, alpha))
	b.ellipse(hc, hr.x, hr.y, Color(c.darkened(0.45), alpha))
	if open > 0.0:
		# The board down the tube, in the bead's shade, below the far wall.
		b.ellipse(hc + Vector2(0.0, hr.y * 0.28), hr.x * 0.8, hr.y * 0.72,
			Color(ground.darkened(0.28).lerp(c.darkened(0.3), 0.25), open))
		if peg_in and lift <= s * 0.05:
			var pr := hr * 0.44
			var pc := hc + Vector2(0.0, hr.y * 0.3)
			b.ellipse(pc + Vector2(0.0, pr.y * 0.3), pr.x, pr.y, Color(Pal.PG_PEG_DEEP, open))
			b.ellipse(pc, pr.x * 0.92, pr.y * 0.92, Color(Pal.PG_PEG, open))
			b.ellipse(pc - pr * 0.28, pr.x * 0.4, pr.y * 0.4, Color(Pal.PG_PEG_HI, open))
	if fused > 0.0:
		# The gloss an iron leaves: a soft white fleck on the upper left.
		b.ellipse(top + Vector2(-rx * 0.38, -ry * 0.4), rx * 0.22, ry * 0.14,
			Color(Color.WHITE, 0.55 * fused * alpha))

## The rose halo Check strokes round a bead the picture does not want there.
## The bead keeps its colour -- a bead is coloured by index, so no state may
## be a shade of it (CLAUDE.md, Pinwheel) -- and the halo carries the verdict.
static func halo(b, at: Vector2, s: float, alpha := 1.0) -> void:
	if alpha <= 0.0:
		return
	var r := s * (R + 0.06)
	b.stroke(Face.Builder.ring(at, r, r), s * 0.07, Color(Pal.BAD, alpha), true)

## One pixel of a thumbnail: a rounded square in `colour`, or for a bare peg
## a small dot, so the player can count pegs off the picture as they count
## them on the board.
static func pixel(b, at: Vector2, s: float, colour: Color, bare: bool) -> void:
	if bare:
		b.disc(at, s * 0.14, Color(Pal.PG_PEG_DEEP, 0.7))
		return
	b.fan(Face.Builder.round_rect(at - Vector2.ONE * s * 0.47, Vector2.ONE * s * 0.94, s * 0.22), colour)
	b.disc(at, s * 0.12, colour.darkened(0.35))
