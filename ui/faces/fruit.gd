extends RefCounted

## Balance's five camp fruit, in the order kinds are introduced: apple, pear,
## pumpkin, acorn, mushroom. One silhouette and one colour each, all with a
## face from the same parts the other two flat screens use, so colour never
## stands alone and nobody has to learn a legend -- the flat board's answer
## to the island's coloured tokens on plinths.
##
## Two of the five were already drawn. The apple is `berry_face.gd`: the
## Code Break mock's berryP and the Balance mock's appleP are the same
## drawing number for number -- a round fruit in BERRY under a bent bark
## stalk with one leaf -- so Balance names that fruit an apple and draws the
## class that exists rather than a second copy of it. The acorn is Code
## Break's own. That reuse is the point of having a cast; only the pear, the
## pumpkin and the mushroom are new.
##
## Everything that draws a fruit (the dishes on the scales, the weight cards
## and the win screen) asks here, so the five are one list in one place, and
## the singular and plural words are here too because the tip card reads a
## scale out loud in them. `friends.gd`'s twin.
## Spec: docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 3.

const Pal = preload("res://core/palette.gd")
const BerryFace = preload("res://ui/faces/berry_face.gd")
const PearFace = preload("res://ui/faces/pear_face.gd")
const PumpkinFace = preload("res://ui/faces/pumpkin_face.gd")
const AcornFace = preload("res://ui/faces/acorn_face.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")

const NAMES := ["apple", "pear", "pumpkin", "acorn", "mushroom"]
## What the tip card calls one of each, and more than one.
const ONE := ["apple", "pear", "pumpkin", "acorn", "mushroom"]
const MANY := ["apples", "pears", "pumpkins", "acorns", "mushrooms"]

static func count() -> int:
	return NAMES.size()

static func name_of(i: int) -> String:
	return NAMES[i % NAMES.size()]

## "one apple", "three pumpkins": the count in words, which is how the tip
## card says it. Ten and up fall back to the digit, which the generator's
## sides never reach (three a side is its most).
static func counted(i: int, n: int) -> String:
	var word: String = NUMBERS[n] if n < NUMBERS.size() else str(n)
	return "%s %s" % [word, ONE[i % NAMES.size()] if n == 1 else MANY[i % NAMES.size()]]

const NUMBERS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]

## The fruit's own colour, for a puff of particles or a card's rim.
static func colour(i: int) -> Color:
	match i % NAMES.size():
		0: return Pal.BERRY
		1: return Pal.PEAR
		2: return Pal.PUMPKIN
		3: return Pal.ACORN
		_: return Pal.MUSHROOM

## The fill of the weight card's chip behind the fruit.
static func tile(i: int) -> Color:
	match i % NAMES.size():
		0: return Pal.BERRY_TILE
		1: return Pal.PEAR_TILE
		2: return Pal.PUMPKIN_TILE
		3: return Pal.ACORN_TILE
		_: return Pal.MUSHROOM_TILE

## A face for fruit `i`, sized to a `seat`-square rect and centred on
## `centre` in its parent's space. Each keeps its own R-to-seat ratio -- the
## mock's `r` -- so the five sit at comparable weights in the same seat
## rather than each filling it.
static func make(i: int, seat: float, centre: Vector2) -> Control:
	var face: Control
	match i % NAMES.size():
		0: face = BerryFace.new()
		1: face = PearFace.new()
		2: face = PumpkinFace.new()
		3: face = AcornFace.new()
		_: face = MushroomFace.new()
	resize(face, seat, centre)
	return face

## Re-sizes and re-centres a face already made, for a seat that grew or
## shrank under it.
static func resize(face: Control, seat: float, centre: Vector2) -> void:
	face.size = Vector2(seat, seat)
	face.pivot_offset = face.size * 0.5
	face.position = centre - face.size * 0.5
