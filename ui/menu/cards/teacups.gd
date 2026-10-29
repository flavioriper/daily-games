extends "res://ui/menu/cards/card_face.gd"

## Teacups' card: the tea table's gingham cloth on cream paper, five cups on
## their saucers against the card's right side and foot, two at the back
## and three in front. The middle front cup is lifted and tipped off the
## Peeplet under it; its twin sits uncovered at the back, its cup gone and
## its saucer ringed in gold, a pair about to be found. The go button is
## the front right cup, in the card's colour, its band in cream.
##
## Everything but the twins is one mesh; the twins are two live Peeplets
## (ui/peeplet_view.gd, Bea from peeplet/peeplet_personas.gd) seated in
## `_lay` holding a still frame, as the board's friends are (2026-10-29),
## and the lifted cup is drawn over the front one by a layer of its own.

const Cup = preload("res://ui/faces/teacup.gd")
const World = preload("res://puzzles/teacups_world.gd")
const PeepletView = preload("res://ui/peeplet_view.gd")
const Personas = preload("res://peeplet/peeplet_personas.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cup's mouth's half width at H, the cups' room from the card's right
## side and foot, and the column the words keep.
const R := 30.0
const RIGHT := 82.0
const FOOT := 40.0
const WORDS_END := 270.0
## The cups: [in from the right, up from the foot, what it is]. 0 down,
## 1 lifted off a Peeplet, 2 gone off its twin, 3 the go cup.
const CUPS := [[150.0, 92.0, 2], [40.0, 92.0, 0], [205.0, 0.0, 0], [95.0, 0.0, 1], [-15.0, 0.0, 3]]
const PAPER_TOP := Color("fdf6ec")
const PAPER_LOW := Color("f6e6da")
const BLURB := Color("7a6650")
## The twins' persona (Bea).
const TWIN := 2

func _k() -> float:
	return size.y / H

func _at(xr: float, yu: float) -> Vector2:
	var k := _k()
	return Vector2(size.x - (RIGHT + xr) * k, size.y - (FOOT + yu) * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	# the gingham's bands under the cups, kept inside the paper
	var x0 := size.x - (RIGHT + 260.0) * k
	var band := 34.0 * k
	var y := size.y * 0.42
	var row := 0
	while y < size.y:
		if row % 2 == 0:
			_cloth(b, Rect2(x0, y, size.x - x0, band))
		y += band
		row += 1
	var x := x0
	var col := 0
	while x < size.x:
		if col % 2 == 0:
			_cloth(b, Rect2(x, size.y * 0.42, band, size.y))
		x += band
		col += 1
	var r := R * k
	for spec: Array in CUPS:
		var at := _at(float(spec[0]), float(spec[1]))
		Cup.saucer(b, at, r)
		var what := int(spec[2])
		if what == 2:
			b.append(Cup.found_ring(r), Transform2D(0.0, at))
		match what:
			0:
				b.append(Cup.shadow(r), Transform2D(0.0, at))
				b.append(Cup.cup(r), Transform2D(0.0, at))
			1:
				# its cup is the lid's, over the Peeplet
				b.append(Cup.shadow(r), Transform2D(0.0, Vector2.ONE * 0.6, 0.0, at), Color(1, 1, 1, 0.6))
			3:
				b.append(Cup.shadow(r), Transform2D(0.0, at))
				if soon:
					b.append(Cup.cup(r), Transform2D(0.0, at))
					continue
				var go := Face.Builder.new()
				_go_cup(go, r)
				b.append(go.mesh(), Transform2D(0.0, at))

## The go button: the cup in the card's colour, its band cream.
func _go_cup(b: Face.Builder, r: float) -> void:
	var first := b.verts.size()
	b.append(Cup.cup(r), Transform2D.IDENTITY)
	for i in range(first, b.verts.size()):
		var c: Color = b.cols[i]
		# the china takes the card's colour, the band the china's cream
		var to := c
		if _same(c, Cup.CHINA):
			to = colour
		elif _same(c, Cup.CHINA_SHADE) or _same(c, Cup.CHINA_DEEP):
			to = colour.darkened(0.2)
		elif _same(c, Cup.BAND) or _same(c, Cup.BAND_DEEP):
			to = Cup.CHINA
		b.cols[i] = Color(to.r, to.g, to.b, c.a)

static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.01

## A band of the gingham, cut to the paper's inside.
func _cloth(b: Face.Builder, rect: Rect2) -> void:
	var pts := _clip(rect)
	if pts.size() >= 3:
		b.polygon(pts, Color(World.CHECK, 0.45))

## A rect cut to the paper's inside, as a polygon.
func _clip(rect: Rect2) -> PackedVector2Array:
	var inside := Rect2(Vector2(EDGE, EDGE), size - Vector2(EDGE, EDGE) * 2.0).grow(-RADIUS * 0.3)
	var r := rect.intersection(inside)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return PackedVector2Array()
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

func _lay() -> void:
	var r := R * _k()
	var p: Dictionary = Personas.get_persona(TWIN)
	var lifted := Vector2.ZERO
	for spec: Array in CUPS:
		var what := int(spec[2])
		if what != 1 and what != 2:
			continue
		var at := _at(float(spec[0]), float(spec[1]))
		if what == 1:
			lifted = at
		var v: Control = PeepletView.new()
		v.color_index = int(p.coat)
		v.headgear = String(p.hat)
		v.eyewear = String(p.eyes)
		v.frame_height = Cup.CAST_FRAME
		v.aim_y = Cup.CAST_AIM
		v.idle_fps = 0.0
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side := ceilf(r * Cup.PIC)
		v.size = Vector2.ONE * side
		v.position = at + Vector2(0.0, r * 0.1) - Vector2(side * 0.5, side * Cup.FEET)
		_keep(v)
	var lid := Control.new()
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lid.draw.connect(func() -> void:
		lid.draw_mesh(Cup.cup(r), null, Transform2D(0.3, lifted + Vector2(r * 0.3, -r * 1.2))))
	_keep(lid)
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0, Pal.TEXT, BLURB)
	words.position.y = roundf(14.0 * _k())
