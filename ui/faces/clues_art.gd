extends RefCounted

## Five Clues' pieces (spec docs/superpowers/specs/2026-10-22-clues-design.md):
## a clue card face up (cream paper, a red pin at its top), its back (kraft
## with a dotted border, where the card's number goes), and a round's pill.
## Cards go into a Face.Builder, so the board draws each as one cached mesh;
## the pills are drawn straight, a few a screen.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

const PAPER := Color("fffaf0")
const PAPER_LINE := Color("e2d3b8")
const KRAFT := Color("d8bd92")
const KRAFT_LINE := Color("b49a72")
const DOTS := Color("f3e6c8")
const PIN := Color("e0675e")
const PIN_DEEP := Color("b84a43")
const INK := Color("3b3028")
const BACK_INK := Color("8c6f4a")
## Chalk on the slate: plain, found (leaf) and lost (dim).
const CHALK := Color("f4f1e8")
const CHALK_LEAF := Color("b8e0a0")
const CHALK_DIM := Color("c9c2b4")
## A pill: still to play, found, lost.
const PILL := Color("e9dcc4")
const PILL_FOUND := Color("7cb06b")
const PILL_LOST := Color("d0857e")

static func card(b: Face.Builder, at: Vector2, sz: Vector2) -> void:
	var r := Rect2(at - sz * 0.5, sz)
	b.fan(Face.Builder.round_rect(r.position + Vector2(3.0, 5.0), r.size, sz.y * 0.16), Color(0.25, 0.15, 0.05, 0.16))
	b.fan(Face.Builder.round_rect(r.position, r.size, sz.y * 0.16), PAPER_LINE)
	b.fan(Face.Builder.round_rect(r.position + Vector2(2.0, 2.0), r.size - Vector2(4.0, 4.0), sz.y * 0.15), PAPER)
	_pin(b, Vector2(at.x, r.position.y + sz.y * 0.08), sz.y * 0.11)

static func back(b: Face.Builder, at: Vector2, sz: Vector2) -> void:
	var r := Rect2(at - sz * 0.5, sz)
	b.fan(Face.Builder.round_rect(r.position + Vector2(3.0, 5.0), r.size, sz.y * 0.16), Color(0.25, 0.15, 0.05, 0.16))
	b.fan(Face.Builder.round_rect(r.position, r.size, sz.y * 0.16), KRAFT_LINE)
	b.fan(Face.Builder.round_rect(r.position + Vector2(2.0, 2.0), r.size - Vector2(4.0, 4.0), sz.y * 0.15), KRAFT)
	# a dotted border inside the edge
	var inner := r.grow(-sz.y * 0.14)
	var step := sz.y * 0.16
	var x := inner.position.x
	while x <= inner.end.x:
		b.disc(Vector2(x, inner.position.y), sz.y * 0.03, DOTS)
		b.disc(Vector2(x, inner.end.y), sz.y * 0.03, DOTS)
		x += step
	_pin(b, Vector2(at.x, r.position.y + sz.y * 0.08), sz.y * 0.11)

static func _pin(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(0.0, r * 0.25), r, PIN_DEEP)
	b.disc(at, r, PIN)
	b.disc(at - Vector2(r * 0.3, r * 0.3), r * 0.32, Color(1, 1, 1, 0.55))

## A round's pill: `res` -1 still to play, 0 lost, else the cards it needed;
## the round in hand ringed in sun.
static func draw_pill(ci: CanvasItem, at: Vector2, r: float, res: int, current: bool) -> void:
	var fill := PILL if res < 0 else (PILL_LOST if res == 0 else PILL_FOUND)
	ci.draw_circle(at + Vector2(0.0, r * 0.12), r, fill.darkened(0.2))
	ci.draw_circle(at, r, fill)
	if current:
		ci.draw_arc(at, r * 1.3, 0.0, TAU, 40, Pal.SUN, maxf(2.0, r * 0.16), true)
