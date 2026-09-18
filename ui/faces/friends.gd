extends RefCounted

## Code Break's friends, in palette order: sun, moon, leaf, berry, cloud,
## acorn, and the flower that joins on the hard difficulty. One shape per
## colour, so colour never stands alone and nobody has to learn a legend --
## the flat board's answer to the island's seven carved pip marks.
##
## Everything that draws a friend (the board's seats, the code under its
## lids, the palette chips and the win screen) asks here, so the seven are
## one list in one place. `make()` seats a face in a square of any size: the
## friend's own R-to-seat ratio is the mock's, so the six sit at comparable
## weights in the same seat rather than each filling it.
## Spec: docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 3.

const Pal = preload("res://core/palette.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const LeafFace = preload("res://ui/faces/leaf_face.gd")
const BerryFace = preload("res://ui/faces/berry_face.gd")
const CloudFace = preload("res://ui/faces/cloud_face.gd")
const AcornFace = preload("res://ui/faces/acorn_face.gd")
const FlowerFace = preload("res://ui/faces/flower_face.gd")

## The sun and the moon are Binairo's, sized there to their own rect; in a
## Code Break seat they take the mock's ratios like the rest.
const SUN_RATIO := 0.27
const MOON_RATIO := 0.34

const NAMES := ["sun", "moon", "leaf", "berry", "cloud", "acorn", "flower"]

static func count() -> int:
	return NAMES.size()

static func name_of(i: int) -> String:
	return NAMES[i % NAMES.size()]

## The friend's own colour, for a puff of particles or a rim.
static func colour(i: int) -> Color:
	match i % NAMES.size():
		0: return Pal.SUN
		1: return Pal.MOON_INK
		2: return Pal.LEAF
		3: return Pal.BERRY
		4: return Pal.CLOUD
		5: return Pal.ACORN
		_: return Pal.FLOWER

## The fill of the palette chip the friend stands on.
static func tile(i: int) -> Color:
	match i % NAMES.size():
		0: return Pal.SUN_TILE
		1: return Pal.MOON_TILE
		2: return Pal.LEAF_TILE
		3: return Pal.BERRY_TILE
		4: return Pal.CLOUD_TILE
		5: return Pal.ACORN_TILE
		_: return Pal.FLOWER_TILE

## A face for friend `i`, sized to a `seat`-square rect and centred on
## `centre` in its parent's space. `plain` leaves off eyes, mouth and cheeks
## (the compact history's silhouettes).
static func make(i: int, seat: float, centre: Vector2, plain := false) -> Control:
	var face: Control
	match i % NAMES.size():
		0:
			face = SunFace.new()
			face.radius_ratio = SUN_RATIO
		1:
			face = MoonFace.new()
			face.radius_ratio = MOON_RATIO
			face.rocks = true
		2: face = LeafFace.new()
		3: face = BerryFace.new()
		4: face = CloudFace.new()
		5: face = AcornFace.new()
		_: face = FlowerFace.new()
	face.plain = plain
	resize(face, seat, centre)
	return face

## Re-sizes and re-centres a face already made, for a seat that grew or
## shrank under it.
static func resize(face: Control, seat: float, centre: Vector2) -> void:
	face.size = Vector2(seat, seat)
	face.pivot_offset = face.size * 0.5
	face.position = centre - face.size * 0.5
