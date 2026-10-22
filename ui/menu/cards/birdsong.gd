extends "res://ui/menu/cards/drumbeat.gd"

## Birdsong's card: a spring morning, the old tree's trunk standing at the
## card's right edge under the seal's corner, and the woodpecker clinging to
## its left side mid-peck, chips off the bark and its holes above it. The go
## button is the big drum in the card's colour (Drumbeat's own `_go`), on a
## strip of lawn, the one drum the board has. The words stand top left, as
## Drumbeat's do.

const Bird = preload("res://ui/faces/woodpecker.gd")
const World = preload("res://puzzles/birdsong_world.gd")

## The trunk at H: its left side in from the right, how far it flares at
## the lawn; the woodpecker's feet on it, its size; the holes it left.
const TRUNK_IN := 46.0
const BIRD_Y := 128.0
const BIRD_R := 30.0
const HOLES := [[47.0, 40.0], [47.0, 54.0]]
const CHIPS := [[66.0, 60.0, 0.4], [80.0, 50.0, 1.6], [74.0, 74.0, 2.4]]
const LAWN_Y := 196.0

const MORNING_TOP := Color("fdf6e8")
const MORNING_LOW := Color("dcedf6")

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, MORNING_TOP, MORNING_LOW, 0.0, size.y)
	# The lawn the drum stands on, inside the paper's round foot.
	var keep := PackedVector2Array()
	var cut := _at(0.0, LAWN_Y).y
	for p in ground():
		keep.append(Vector2(p.x, maxf(p.y, cut)))
	b.polygon(keep, World.LAWN)
	Scenery.soft_disc(b, _at(160.0, 70.0), 110.0 * k, 60.0 * k, Color(World.SUN, 0.45))
	_trunk(b, k)
	for h: Array in HOLES:
		b.ellipse(_at(float(h[0]) + 2.0, float(h[1])), 2.6 * k, 3.4 * k, Color("3e2818"))
	for c: Array in CHIPS:
		var at := _at(float(c[0]), float(c[1]))
		var s := 3.2 * k
		var t := float(c[2])
		b.polygon(PackedVector2Array([at + Vector2(-s, -s * 0.5).rotated(t), at + Vector2(s * 1.1, -s * 0.2).rotated(t),
			at + Vector2(-s * 0.2, s * 0.8).rotated(t)]), Color("d9b48a") if t > 1.0 else World.BARK)
	# the woodpecker on the trunk's left side, facing it, its beak at the bark
	var feet := _at(TRUNK_IN, BIRD_Y)
	var r := BIRD_R * k
	var flip := Transform2D(0.0, Vector2(-1.0, 1.0), 0.0, feet)
	b.append(Bird.body(r), flip)
	var head := Bird.head_at(r) + Bird.strike(r) * 0.8
	b.append(Bird.head(r, Bird.Mood.REST), Transform2D(0.0, Vector2(-1.0, 1.0), 0.0, feet + Vector2(-head.x, head.y)))
	if soon:
		_plain(b, 0, GO_IN, GO_R * 0.86, k)
	else:
		_go(b, _at(GO_IN, H - FOOT - GO_LIFT), GO_R * k)

## The trunk from above the card's top to the lawn at its right edge, its
## grain and its roots.
func _trunk(b: Face.Builder, k: float) -> void:
	var top := _at(TRUNK_IN, -20.0)
	var foot := _at(TRUNK_IN, LAWN_Y + 6.0)
	var right := size.x + 8.0
	b.polygon(PackedVector2Array([Vector2(top.x, top.y), Vector2(right, top.y), Vector2(right, foot.y + 6.0 * k),
		Vector2(top.x - 14.0 * k, foot.y + 6.0 * k), Vector2(top.x, foot.y - 14.0 * k)]), World.TRUNK_DEEP)
	b.polygon(PackedVector2Array([Vector2(top.x + 3.0 * k, top.y), Vector2(right, top.y), Vector2(right, foot.y),
		Vector2(top.x + 3.0 * k, foot.y - 14.0 * k)]), World.TRUNK)
	for i in 3:
		var x := top.x + (12.0 + 12.0 * i) * k
		b.stroke(PackedVector2Array([Vector2(x, top.y), Vector2(x + 2.0 * k, (top.y + foot.y) * 0.5), Vector2(x - 1.0 * k, foot.y - 12.0 * k)]),
			2.0 * k, Color(World.BARK, 0.8))
