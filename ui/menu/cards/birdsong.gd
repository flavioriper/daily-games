extends "res://ui/menu/cards/drumbeat.gd"

## Birdsong's card: Drumbeat's drums on a spring morning, and the bird. The
## old tree's branch comes in from the card's right edge under the seal's
## corner, and the bird sits on it singing, beak open, two quavers of its
## drums' colours floating down to them. Under it stand the same three
## drums Drumbeat's card has -- the go button is the big drum in the card's
## colour (Drumbeat's own `_go`), the hand drum and the tongue drum beside
## it -- on a strip of lawn. The words stand top left, as Drumbeat's do.

const Bird = preload("res://ui/faces/songbird.gd")
const World = preload("res://puzzles/birdsong_world.gd")

## The branch at H: how far in from the right it ends, its line's height
## where it leaves the paper and at its tip; the bird on it, in from the
## right, its radius; the quavers [in from the right, down at H, drum kind].
const BRANCH_END := 236.0
const BRANCH_Y := 70.0
const BRANCH_TIP_Y := 58.0
const BIRD_IN := 120.0
const BIRD_R := 26.0
const QUAVERS := [[178.0, 112.0, 0], [72.0, 104.0, 3]]
const LAWN_Y := 196.0

const MORNING_TOP := Color("fdf6e8")
const MORNING_LOW := Color("dcedf6")

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, MORNING_TOP, MORNING_LOW, 0.0, size.y)
	# The lawn the drums stand on, inside the paper's round foot.
	var keep := PackedVector2Array()
	var cut := _at(0.0, LAWN_Y).y
	for p in ground():
		keep.append(Vector2(p.x, maxf(p.y, cut)))
	b.polygon(keep, World.LAWN)
	Scenery.soft_disc(b, _at(150.0, 70.0), 110.0 * k, 60.0 * k, Color(World.SUN, 0.45))
	_branch(b, k)
	var bird_at := _at(BIRD_IN, _branch_y(BIRD_IN))
	b.append(Bird.bird(BIRD_R * k, Bird.Mood.SING, 1.0, 0.5), Transform2D(0.0, Vector2(-1.0, 1.0), 0.0, bird_at))
	for q: Array in QUAVERS:
		b.append(Bird.quaver(6.5 * k, Parts.LANE_DEEP[int(q[2])]), Transform2D(0.0, _at(float(q[0]), float(q[1]))))
	for d: Array in DRUMS:
		_plain(b, int(d[0]), float(d[1]), float(d[2]), k)
	if soon:
		_plain(b, 0, GO_IN, GO_R * 0.86, k)
	else:
		_go(b, _at(GO_IN, H - FOOT - GO_LIFT), GO_R * k)

## The branch's line at `xr` in from the right, at H.
func _branch_y(xr: float) -> float:
	return lerpf(BRANCH_Y, BRANCH_TIP_Y, clampf(xr / BRANCH_END, 0.0, 1.0)) + 3.0

func _branch(b: Face.Builder, k: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var xr := BRANCH_END * (1.0 - i / 12.0)
		pts.append(_at(xr, _branch_y(xr) + sin(i / 12.0 * PI) * 4.0))
	pts.append(Vector2(size.x, pts[pts.size() - 1].y + 4.0 * k))
	b.stroke(pts, 10.0 * k, World.TRUNK_DEEP)
	b.stroke(pts, 7.0 * k, World.TRUNK)
	for leaf: Array in [[210.0, -1.0], [60.0, 1.0], [30.0, -1.0]]:
		var root := _at(float(leaf[0]), _branch_y(float(leaf[0])))
		var tip := root + Vector2(-10.0, 12.0 * float(leaf[1])) * k
		b.stroke(PackedVector2Array([root, tip]), 3.0 * k, World.TRUNK)
		var pts2 := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0 * TAU
			pts2.append(tip + Vector2(cos(t) * 8.0 * k, sin(t) * 3.6 * k).rotated(0.5 * float(leaf[1])))
		b.polygon(pts2, World.CROWN)
