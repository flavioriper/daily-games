extends "res://ui/menu/cards/card_face.gd"

## Gumdrop's card: a pale candy-pink paper and the board's table things
## laid on it. On the right stands the board's dark tray with one jelly set
## on it, the cupcake of puzzles/gumdrop_mould.gd: its cup already blueberry
## and its cherry already cherry, the icing between them still clear. Left
## of the tray the board's card is taped up with the cupcake as it is
## wanted, the icing in the card's colour, so the one part that does not
## match is plain. Under that card stands the go button: the pot of the
## syrup the icing wants, a glass jar full of the card's colour, larger
## than the board's beside its tray, lifted over a shadow, a chevron on its
## belly. The name stands top left.
##
## The syrup on the board is a fluid under a shader; here a coloured part
## is one flat polygon between the board's own floor and skin, redrawn from
## puzzles/gumdrop_art.gd's builders (which hand back whole meshes).
## Everything is one mesh and nothing lives on the card.

const Mould = preload("res://puzzles/gumdrop_mould.gd")
const Art = preload("res://puzzles/gumdrop_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The jelly shown, and the flavour of its part still to be poured: that
## part is drawn in the card's colour wherever it is coloured.
const PICTURE := "cupcake"
const WANTED := Mould.Flavour.GRAPE
## The tray: its side at H, and its room from the card's right and foot.
const TRAY := 134.0
const RIGHT := 20.0
const FOOT := 18.0
## How much of the tray the jelly's 100 units take.
const JELLY := 0.9
## A poured part's tint over the clear jelly.
const TINT := 0.9
## The taped card: its size at H, the gap between it and the tray, how far
## down its top is, and how much of it the picture takes.
const NOTE := Vector2(72.0, 76.0)
const NOTE_GAP := 16.0
const NOTE_TOP := 82.0
const NOTE_PICTURE := 0.82
const TAPE := Vector2(34.0, 11.0)
## The go pot: its width at H (the board's jar is 96 by 112), where its
## foot's middle stands as [in from the tray's left side, up from the
## card's foot], how far it is lifted, its shadow, and the plain pot's
## width when the card is not open yet.
const POT_W := 58.0
const POT_AT := Vector2(52.0, 20.0)
const POT_LIFT := 5.0
const POT_SHADOW := 0.22
const POT_PLAIN := 40.0
## The words end here at H: the picture never starts left of it.
const WORDS_END := 238.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The paper: candy pink over a deeper one, a pale pool behind the tray,
## and the blurb's ink.
const PINK_TOP := Color("fdeff1")
const PINK_LOW := Color("f8dbe2")
const POOL := Color("fff8f9")
const BLURB := Color("86636e")

static var _mould: Dictionary = {}

static func _jelly() -> Dictionary:
	if _mould.is_empty():
		_mould = Mould.build(PICTURE)
	return _mould

## The picture's scale: the card's height sets it, the words cap it.
func _k() -> float:
	var reach := RIGHT + TRAY + NOTE_GAP + NOTE.x
	return minf(size.y / H, (size.x - WORDS_END) / reach)

## The tray's top left corner.
func _tray_at() -> Vector2:
	var k := _k()
	return Vector2(size.x - (RIGHT + TRAY) * k, size.y - (FOOT + TRAY) * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PINK_TOP, PINK_LOW, 0.0, size.y)
	var tray := _tray_at()
	var side := TRAY * k
	Scenery.soft_disc(b, tray + Vector2(side * 0.3, side * 0.5), side * 1.05, side * 0.62, Color(POOL, 0.55))
	_tray(b, tray, side)
	var u := side * JELLY / Mould.SIDE
	_jelly_on(b, tray + Vector2.ONE * side * (1.0 - JELLY) * 0.5, u)
	_note(b, Vector2(tray.x - (NOTE_GAP + NOTE.x) * k, NOTE_TOP * k), k)
	var foot := Vector2(tray.x - POT_AT.x * k, size.y - POT_AT.y * k)
	if soon:
		_pot(b, foot, POT_PLAIN * k / Art.JAR_W, false)
	else:
		Scenery.soft_disc(b, foot + Vector2(2.0, 3.0) * k, POT_W * 0.62 * k, 9.0 * k, Color(Pal.TEXT, POT_SHADOW))
		_pot(b, foot - Vector2(0.0, POT_LIFT * k), POT_W * k / Art.JAR_W, true)

## `p`, a mould's outline in its own units, laid at `at`, `u` pixels a unit.
static func _laid(p: PackedVector2Array, at: Vector2, u: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for i in p.size():
		out[i] = at + p[i] * u
	return out

## The board's tray (gumdrop_art.gd's `tray`), its corner at `at`.
func _tray(b: Face.Builder, at: Vector2, side: float) -> void:
	var r := side * 0.07
	var lip := side * 0.022
	b.fan(Face.Builder.round_rect(at + Vector2(-lip, lip * 1.2), Vector2(side + lip * 2.0, side + lip * 1.4), r + lip),
		Color(0.25, 0.14, 0.06, 0.22))
	b.fan(Face.Builder.round_rect(at + Vector2(-lip, -lip), Vector2(side + lip * 2.0, side + lip * 2.0), r + lip), Art.TRAY_LOW)
	b.fan(Face.Builder.round_rect(at + Vector2(-lip, -lip * 1.5), Vector2(side + lip * 2.0, side + lip * 1.6), r + lip), Art.TRAY_HI)
	b.fan(Face.Builder.round_rect(at, Vector2(side, side), r), Art.TRAY)
	b.fan(Face.Builder.round_rect(at + Vector2(side * 0.05, side * 0.03), Vector2(side * 0.5, side * 0.012), side * 0.006),
		Color(1, 1, 1, 0.07))

## The jelly set on the tray: the board's floor, each poured part one flat
## tint, the part still wanted left clear, and the board's skin over them.
func _jelly_on(b: Face.Builder, at: Vector2, u: float) -> void:
	var m := _jelly()
	if m.is_empty():
		return
	# the board's gel (gumdrop_art.gd's floor_of and gloss_of, 2026-10-14)
	var rim := _laid(m.rim, at, u)
	b.polygon(_laid(m.rim, at + Vector2(1.6, 2.6) * u, u), Color(Art.GEL_SHADOW, 0.28))
	b.polygon(_laid(m.rim, at + Vector2(0.7, 1.2) * u, u), Color(Art.GEL_SHADOW, 0.35))
	b.polygon(rim, Art.GEL_SIDE)
	var body := _laid(m.outline, at, u)
	b.stroke(_laid(m.outline, at + Vector2(-0.55, -0.75) * u, u), 0.9 * u, Color(Art.GEL_LIT, 0.55), true)
	b.polygon(body, Art.GEL)
	var want: Array = m.want
	for c in m.cells.size():
		if int(want[c]) != WANTED:
			b.polygon(_laid(m.cells[c], at, u), Color(Art.FLAVOURS[int(want[c])], TINT))
	for line: PackedVector2Array in m.seams:
		if line.size() >= 2:
			b.stroke(_laid(line, at, u), Art.SEAM * u, Color(Art.GEL, 0.9))
	for line: PackedVector2Array in m.seams:
		if line.size() >= 2:
			b.stroke(_laid(line, at + Vector2(-0.35, -0.45) * u, u), Art.SEAM * 0.3 * u, Color(Art.GEL_LIT, 0.28))
	b.stroke(body, 0.8 * u, Color(Art.GEL_SIDE, 0.95), true)
	# The light lying on the gel: two flat pale patches.
	var glint := at + Vector2(41.0, 33.0) * u
	b.ellipse(glint, 9.0 * u, 3.6 * u, Color(1, 1, 1, 0.18))
	b.ellipse(glint + Vector2(-2.6, -0.5) * u, 3.0 * u, 1.4 * u, Color(1, 1, 1, 0.3))

## The board's card with the jelly as it is wanted, its corner at `at`: the
## wanted part in the card's colour.
func _note(b: Face.Builder, at: Vector2, k: float) -> void:
	var m := _jelly()
	var sz := NOTE * k
	b.fan(Face.Builder.round_rect(at + Vector2(1.5, 3.5) * k, sz, 9.0 * k), Color(0.25, 0.14, 0.06, 0.18))
	b.fan(Face.Builder.round_rect(at, sz, 9.0 * k), Art.PAPER)
	b.fan(Face.Builder.round_rect(at + Vector2((NOTE.x - TAPE.x) * 0.5, -TAPE.y * 0.45) * k, TAPE * k, 2.0 * k),
		Color("f2d98a", 0.9))
	if m.is_empty():
		return
	var u := minf(sz.x, sz.y) * NOTE_PICTURE / Mould.SIDE
	var o := at + (sz - Vector2.ONE * Mould.SIDE * u) * 0.5 + Vector2(0.0, 2.0 * k)
	b.polygon(_laid(m.rim, o + Vector2(0.6, 1.0) * u, u), Color(Art.INK, 0.16))
	b.polygon(_laid(m.rim, o, u), Color("fffdf8"))
	var want: Array = m.want
	for c in m.cells.size():
		var f := int(want[c])
		b.polygon(_laid(m.cells[c], o, u), colour if f == WANTED else Art.FLAVOURS[f])

## A pot (gumdrop_art.gd's `jar` over its `syrup`), full of the card's
## colour, its foot's middle at `foot`, `s` of the board's size; the go pot
## carries a chevron.
func _pot(b: Face.Builder, foot: Vector2, s: float, go: bool) -> void:
	var w := Art.JAR_W * s
	var h := Art.JAR_H * s
	var sw := w * 0.8
	var sh := h * 0.72
	var top := foot + Vector2(-sw * 0.5, -6.0 * s - sh)
	b.fan(Face.Builder.round_rect(top, Vector2(sw, sh), 10.0 * s), colour.darkened(0.14))
	b.fan(Face.Builder.round_rect(top, Vector2(sw * 0.8, sh), 10.0 * s), colour)
	b.fan(Face.Builder.round_rect(top + Vector2(4.0 * s, 0.0), Vector2(sw - 8.0 * s, 7.0 * s), 3.5 * s), colour.lightened(0.3))
	var body := Face.Builder.round_rect(foot + Vector2(-w * 0.5, -h * 0.84), Vector2(w, h * 0.84), 18.0 * s)
	b.fan(body, Color(Art.GLASS, 0.24))
	b.stroke(body, 5.0 * s, Art.GLASS_LINE, true)
	b.fan(Face.Builder.round_rect(foot + Vector2(-w * 0.56, -h * 0.92), Vector2(w * 1.12, h * 0.13), 7.0 * s), Art.GLASS_LINE)
	b.fan(Face.Builder.round_rect(foot + Vector2(-w * 0.56, -h * 0.92), Vector2(w * 1.12, h * 0.07), 5.0 * s), Art.GLASS)
	b.fan(Face.Builder.round_rect(foot + Vector2(-w * 0.36, -h * 0.72), Vector2(w * 0.1, h * 0.5), 4.0 * s), Color(1, 1, 1, 0.5))
	if go:
		var c := foot + Vector2(w * 0.04, -h * 0.4)
		var a := h * 0.15
		b.stroke(PackedVector2Array([c + Vector2(-a * 0.55, -a), c + Vector2(a * 0.55, 0.0), c + Vector2(-a * 0.55, a)]),
			h * 0.085, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
