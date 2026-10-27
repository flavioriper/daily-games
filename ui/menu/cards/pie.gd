extends "res://ui/menu/cards/card_face.gd"

## Who Ate the Pie?'s card: warm paper with the pie in its dish against the
## card's right side, two of its slices eaten down to crumbs, and two
## bakers' name cards leaning in front of it: Wren on leaf paper with a tick
## (cleared) and Olga on crust paper with a slice (caught). The go button is
## a round badge in the card's colour with a cream slice, at the cards' foot.
##
## Everything but the bakers is one mesh; the bakers are two live Peeplets
## (ui/peeplet_view.gd, from peeplet/peeplet_personas.gd) seated in `_lay`,
## holding a still frame.

const Art = preload("res://ui/faces/pie_art.gd")
const PeepletView = preload("res://ui/peeplet_view.gd")
const Personas = preload("res://peeplet/peeplet_personas.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The pie's dish radius, the cards' size, and their room from the card's
## right side and foot.
const DISH := 64.0
const CARD := Vector2(84.0, 96.0)
const RIGHT := 50.0
const FOOT := 34.0
const PAPER_TOP := Color("fdf5ea")
const PAPER_LOW := Color("f5e3d6")
const BLURB := Color("7a6650")
## The two cards: their room from the right side, their lean, their persona
## (Wren, Olga) and their paper.
const SPECS := [[230.0, -0.08, 42, 1], [140.0, 0.07, 29, 2]]

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	# the pie at the back, high on the right
	var pie_at := Vector2(size.x - (RIGHT + 70.0) * k, size.y * 0.36)
	b.append(Art.pie(DISH * k, 6, 2), Transform2D(0.0, pie_at))
	# two bakers' cards leaning in front of it
	var cs := CARD * k
	for spec: Array in SPECS:
		var xf := _card_xf(spec)
		b.append(Art.card(cs, int(spec[3])), xf)
		var br := cs.x * 0.16
		var badge: ArrayMesh = Art.slice(br) if int(spec[3]) == Art.Paper.ATE else Art.tick(br)
		b.append(badge, xf * Transform2D(0.0, Vector2(cs.x - br * 0.6, br * 0.6)))
	# the go badge, in the card's colour
	var r := 27.0 * k
	var go := Vector2(size.x - (RIGHT + 30.0) * k, size.y - FOOT * k - r)
	if soon:
		b.append(Art.tick(r), Transform2D(0.0, go))
		return
	b.disc(go + Vector2(0.0, r * 0.1), r, colour.darkened(0.25))
	b.disc(go, r, colour)
	b.stroke(PackedVector2Array([go + Vector2(-r * 0.42, r * 0.02), go + Vector2(-r * 0.12, r * 0.32), go + Vector2(r * 0.44, -r * 0.3)]),
		r * 0.22, Pal.SURFACE)

func _card_xf(spec: Array) -> Transform2D:
	var k := _k()
	var cs := CARD * k
	var at := Vector2(size.x - (RIGHT + float(spec[0])) * k, size.y - FOOT * k - cs.y)
	return Transform2D(float(spec[1]), at + cs * 0.5) * Transform2D(0.0, -cs * 0.5)

func _lay() -> void:
	var cs := CARD * _k()
	for spec: Array in SPECS:
		var p: Dictionary = Personas.get_persona(int(spec[2]))
		var v: Control = PeepletView.new()
		v.color_index = int(p.coat)
		v.headgear = String(p.hat)
		v.eyewear = String(p.eyes)
		v.frame_height = 1.0
		v.aim_y = 0.46
		v.idle_fps = 0.0
		var side := cs.x * 0.95
		v.size = Vector2.ONE * side
		var xf := _card_xf(spec) * Transform2D(0.0, Vector2(cs.x * 0.5, cs.y * 0.5) - Vector2.ONE * side * 0.5)
		v.position = xf.origin
		v.rotation = float(spec[1])
		_keep(v)
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0, Pal.TEXT, BLURB)
	words.position.y = roundf(14.0 * _k())
