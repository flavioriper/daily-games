extends "res://ui/menu/cards/card_face.gd"

## Factory's card: a morning over the floor's land (main's card's sky, its
## green and its far rise), drawn with the floor's own pieces as the floor
## projects them (factory/art.gd's meshes): the back wall's charger at the back, one of the
## game's robots in the Picker's tint with its content face carrying a full
## box, and a run of belt with two grey squares riding it toward the go
## button, which stands where the belt ends, as the market does on the
## floor: a disc in the card's colour with a chevron. The name stands top
## left, with the coins and the pace (set from outside) under it.
##
## The land of logs and trees it showed until 2026-10-20 went with the land;
## the robots took its place: in new top-down paper art on 2026-10-20, in
## the land's pieces corner on and then on the top-down grid on 2026-10-21
## (the user: "use at most the elements factory already had", then "keep
## current visual elements, but make it topdown"). Factory had a tab of its own until the bottom bar left on
## 2026-10-13; this card took its place on the Arcade list. Everything is
## one mesh and nothing lives on it.

const Art = preload("res://factory/art.gd")
const Life = preload("res://factory/life.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The words end here and the picture needs this much to their right: the
## card's width caps the scale so the robot never starts under them.
const WORDS_END := 205.0
const REACH := 250.0
## A piece of the back wall at the back with the charger on it (the room,
## 2026-10-22): its left end in from the right and its foot up from the
## foot, its scale, how many tiles of wall, and the charger's tile along it.
const WALL_AT := Vector2(250.0, 96.0)
const WALL_K := 0.78
const WALL_TILES := 2.4
const CHARGER_X := 0.55
## The robot at H: where its feet are, in from the right and up from the
## foot, and how big; the box it carries is Art's HELD_AT, one with four
## squares in it.
const ROBOT_AT := Vector2(132.0, 62.0)
const ROBOT_K := 1.0
const CARRIED := 4
## The belt: from the left of the picture to the go button, its width and
## its slats, and the two squares riding it (in from the right, and how big).
const BELT_FROM := Vector2(244.0, 40.0)
const BELT_TO := Vector2(96.0, 40.0)
const BELT_W := 26.0
const SLATS := 6
const RIDERS: Array[float] = [228.0, 194.0]
const RIDER_K := 0.62
const BED := Color("5b5450")
const RAIL := Color("8a7f76")
const SLAT := Color("746b65")
## The go button: its radius and where its middle is, in from the right and
## up from the foot.
const GO := 30.0
const GO_AT := Vector2(52.0, 46.0)
const GO_SHADOW := 0.22
## The far rise's crest and foot at H.
const RISE_TOP := 120.0
const RISE_FOOT := 172.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The morning: sky over the land's green, the far rise and the blurb's ink.
const SKY := Color("eef6f0")
const LAND := Color("dcecc4")
const RISE := Color("cfe3b4")
const BLURB := Color("5f6b4a")

func _k() -> float:
	return minf(size.y / H, maxf(size.x - WORDS_END, 1.0) / REACH)

## A point given in from the right and up from the foot, at H.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - p.y * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY, LAND, 0.0, size.y)
	_rise(b)
	var e := WALL_K * k
	var wall := Transform2D(0.0, Vector2(e, e), 0.0, _at(WALL_AT))
	b.append(Art.wall(0.0, WALL_TILES, []), wall)
	var charger := wall * Transform2D(0.0, Vector2(CHARGER_X * Art.K * 2.0, 0.0))
	b.append(Art.charger(), charger)
	b.append(Art.charger_lamp(), charger, Art.CHARGE_LIT)
	_belt(b, k)
	for x in RIDERS:
		b.append(Art.square(), Transform2D(0.0, Vector2(RIDER_K, RIDER_K) * k, 0.0, _at(Vector2(x, BELT_FROM.y - 4.0))))
	var s := ROBOT_K * k
	var bot := Transform2D(0.0, Vector2(s, s), 0.0, _at(ROBOT_AT))
	b.append(Art.robot(), bot, Life.TINTS[0])
	b.append(Art.face(""), bot)
	b.append(Art.box(CARRIED, false), bot * Transform2D(0.0, Vector2(Art.HELD_SCALE, Art.HELD_SCALE), 0.0, Art.HELD_AT))
	if not soon:
		_go(b, _at(GO_AT), GO * k)

## One soft far rise, sunk under the words and highest behind the wall.
func _rise(b: Face.Builder) -> void:
	var k := size.y / H
	var pts := PackedVector2Array()
	var steps := 28
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(Vector2(lerpf(EDGE, size.x - EDGE, t),
			lerpf(RISE_FOOT, RISE_TOP, pow(sin(t * PI * 0.64), 2.0)) * k))
	var first := b.verts.size()
	var low := RISE_FOOT * k + 14.0 * k
	pts.append(Vector2(size.x - EDGE, low))
	pts.append(Vector2(EDGE, low))
	b.polygon(pts, Color.WHITE)
	# Clear at its foot, so it melts into the land.
	for i in range(first, b.verts.size()):
		var a := clampf(inverse_lerp(low, RISE_TOP * k, b.verts[i].y), 0.0, 1.0)
		b.cols[i] = Color(RISE, a * 0.9)

## The belt: a bed between two rails, slats across it.
func _belt(b: Face.Builder, k: float) -> void:
	var from := _at(BELT_FROM)
	var to := _at(BELT_TO)
	var w := BELT_W * k
	b.ellipse((from + to) * 0.5 + Vector2(0.0, w * 0.5), (to.x - from.x) * 0.54, w * 0.42, Art.CAST)
	b.stroke(PackedVector2Array([from, to]), w, RAIL)
	b.stroke(PackedVector2Array([from, to]), w * 0.72, BED)
	for i in SLATS:
		var x := lerpf(from.x, to.x, (float(i) + 0.5) / SLATS)
		b.stroke(PackedVector2Array([Vector2(x, from.y - w * 0.26), Vector2(x, from.y + w * 0.26)]),
			maxf(1.5, w * 0.1), SLAT, false, false)

## The go button about `at`: a disc in the card's colour over its shadow,
## a chevron on it.
func _go(b: Face.Builder, at: Vector2, r: float) -> void:
	b.ellipse(at + Vector2(0.0, r * 0.5), r * 1.08, r * 0.7, Color(Pal.TEXT, GO_SHADOW))
	b.disc(at + Vector2(0.0, r * 0.16), r, colour.darkened(0.26))
	b.disc(at, r, colour)
	b.ellipse(at - Vector2(0.0, r * 0.42), r * 0.62, r * 0.3, Color(Pal.SURFACE, 0.16))
	var h := r * 0.38
	b.stroke(PackedVector2Array([at + Vector2(-h * 0.55, -h), at + Vector2(h * 0.55, 0.0), at + Vector2(-h * 0.55, h)]),
		r * 0.24, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
