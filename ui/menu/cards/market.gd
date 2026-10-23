extends "res://ui/menu/cards/card_face.gd"

## Market Sums' card: a corner of the stall on warm paper, the game read in
## one look. The chalk order board hangs from the card's top reading 12;
## under it on a shelf along the card's foot stand two crates, 5 and 7, and
## between them the go button, a sign token in the card's colour with its
## plus mark: 5 and 7 make the order (a circled times read as a close
## button). The first card, 2026-10-22, had three small crates and a small
## board, and the user found it "hard to read ... due to numbers and
## letters".
##
## Everything still is one mesh; the numbers are draw_string calls over it.

const Art = preload("res://ui/faces/market_art.gd")
const Gen = preload("res://puzzles/market_gen.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A crate's width at H; the middle of the scene from the card's right
## side; the crates' and the token's places from that middle; the shelf's
## height over the card's foot.
const CRATE := 100.0
const MID := 200.0
const APART := 112.0
const FOOT := 34.0
const CRATES := [[-1.0, 5], [1.0, 7]]
const ORDER := 12
const BOARD := Vector2(196.0, 92.0)
const PAPER_TOP := Color("fdf5e8")
const PAPER_LOW := Color("f4e2cc")
const BLURB := Color("7a6650")

var _numbers: Array = []

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	_numbers = []
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var cw := CRATE * k
	var shelf_y := size.y - FOOT * k
	var mx := size.x - MID * k
	# the shelf
	var sw := APART * 2.0 * k + cw + 40.0 * k
	b.fan(Face.Builder.round_rect(Vector2(mx - sw * 0.5, shelf_y), Vector2(sw, 12.0 * k), 5.0 * k), Art.CRATE_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(mx - sw * 0.5, shelf_y), Vector2(sw, 8.0 * k), 5.0 * k), Art.CRATE)
	for spec: Array in CRATES:
		var at := Vector2(mx + float(spec[0]) * APART * k, shelf_y - cw * Art.H * 0.5)
		Scenery.soft_disc(b, at + Vector2(0.0, cw * Art.H * 0.5), cw * 0.5, cw * 0.08, Color(Pal.TEXT, 0.16))
		Art.crate(b, at, cw, false)
		var text := str(spec[1])
		_numbers.append([at + Art.label_centre(cw), text, Art.numeral_size(text, cw), Pal.TEXT])
	# the order board over them, hung from the card's top
	var bs := BOARD * k
	var bc := Vector2(mx, EDGE + 18.0 * k + bs.y * 0.5)
	Art.board(b, bc, bs, EDGE, k * 0.5)
	_numbers.append([bc + Vector2(0.0, 1.0 * k), str(ORDER), roundi(48.0 * k), Art.CHALK_INK])
	# the go token between the crates, in the card's colour
	var tr_ := 30.0 * k
	var go := Vector2(mx, shelf_y - cw * Art.H * 0.5 - Art.label_centre(cw).y * -1.0)
	if soon:
		Art.token(b, go, tr_, Gen.Op.ADD, false)
	else:
		b.disc(go + Vector2(0.0, tr_ * 0.12), tr_, colour.darkened(0.25))
		b.disc(go, tr_, colour)
		Art.mark(b, go, tr_ * 0.5, Gen.Op.ADD, Art.LABEL)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(800)
	for n: Array in _numbers:
		var fs: int = n[2]
		var tw := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, (n[0] as Vector2) + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), n[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, n[3])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0, Pal.TEXT, BLURB)
	words.position.y = roundf(14.0 * _k())
