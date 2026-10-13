extends "res://ui/menu/cards/card_face.gd"

## Hidden Word's card: three guesses coming down the parchment like a flight
## of steps, each row set a little further left than the one over it. The
## first two have been turned over and wear the board's marks, judged against
## the word they lead to; the third is the row being typed, four letters on
## their paper pieces, and the tile its last letter goes on is the go button,
## in the card's colour, with a chevron where the letter would be. The name
## stands over the steps on the left, the top right corner is left to the
## seal, and the sprout waits on a tump of the board's turf at the foot.
##
## The ground, the turf and the fifteen tiles are one mesh, cut as the board
## cuts a piece (hidden_word2d.gd's `_tile_face`: a lip, a lit rim, a crown);
## the letters are draw commands over it, as they are there (Mosaic.letter).
## The sprout is the one thing alive.

const Board = preload("res://puzzles/hidden_word2d.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const SproutFace = preload("res://ui/faces/sprout_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the steps
## grow with a taller one.
const H := 246.0
## A tile at H, the gap between two, a row's drop and its step to the left,
## and the margins the flight keeps from the card's right side and its foot.
const CELL := 44.0
const GAP := 4.0
const DROP := 48.0
const STEP := 34.0
const SIDE := 24.0
const RIGHT := 20.0
const FOOT := 15.0
## A piece's bottom edge, in cells, and the least it may be: the board's EDGE
## has a floor of 5 on a cell of 130, which is a slab on one of 44.
const LIP := 0.07
const LIP_MIN := 3.0
## The word, and the guesses that led to it. The marks are worked out from
## these, never written down.
const WORD := "honey"
const GUESSES := ["bread", "lemon"]
const TYPED := "hone"
## The go tile, in cells, about the middle of the seat it stands on.
const GO_SIZE := 1.16
## The words' top, and the room a row keeps from them.
const WORDS_TOP := 14.0
const WORDS_GAP := 12.0
## The tump of turf in the bottom left corner: its middle from the corner,
## its two radii, and the sprout standing on it (its size, its middle).
const TUMP_AT := Vector2(78.0, -8.0)
const TUMP_R := Vector2(112.0, 46.0)
const SPROUT := 74.0
const SPROUT_AT := Vector2(74.0, 66.0)

const PAPER_TOP := Color("faf3e0")
const PAPER_LOW := Color("f0e2c2")

## The name's rect and the blurb's, measured in `_lay`, which runs before the
## mesh is built: the name is the wider and the blurb the lower, and a row
## may stand beside the blurb under the name's end.
var _said: Array[Rect2] = []

func _k() -> float:
	return size.y / H

## The flight's own scale: the card's, unless a row would then run into the
## words or off the card's left side.
func _ks() -> float:
	var ks := _k()
	while ks > 0.5 and not _fits(ks):
		ks -= 0.02
	return ks

func _fits(ks: float) -> bool:
	for r in GUESSES.size() + 1:
		var at := _row_at(r, ks)
		if at.x < SIDE:
			return false
		for said in _said:
			if at.y < said.end.y + 2.0 and at.x < said.end.x + WORDS_GAP:
				return false
	return true

## The top left corner of row `r` at scale `ks`: the last row stands on the
## card's foot, the first reaches the card's right side.
func _row_at(r: int, ks: float) -> Vector2:
	var rows := GUESSES.size() + 1
	var wide := (WORD.length() * (CELL + GAP) - GAP) * ks
	return Vector2(size.x - RIGHT - wide - r * STEP * ks,
		size.y - FOOT * _k() - (CELL + (rows - 1 - r) * DROP) * ks)

## The top left corner of tile `c` of row `r`.
func _tile_at(r: int, c: int) -> Vector2:
	var ks := _ks()
	return _row_at(r, ks) + Vector2(c * (CELL + GAP) * ks, 0.0)

## The marks of `guess` against WORD, as the board's state gives them: 0 in
## its place, 1 in the word but elsewhere, 2 not in it. A letter is spent
## once it has answered for a tile.
static func marks(guess: String) -> Array[int]:
	var out: Array[int] = []
	var left := {}
	for i in WORD.length():
		out.append(2)
		if guess[i] == WORD[i]:
			out[i] = 0
		else:
			left[WORD[i]] = int(left.get(WORD[i], 0)) + 1
	for i in WORD.length():
		if out[i] != 0 and int(left.get(guess[i], 0)) > 0:
			out[i] = 1
			left[guess[i]] -= 1
	return out

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := CELL * _ks()
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	# The tump: the board's turf and its lighter crown, washed toward the
	# parchment as the band is, with blades and a flower.
	var mid := Vector2(TUMP_AT.x * k, size.y - TUMP_AT.y * k)
	var turf: Color = Pal.LEAF.lerp(Pal.PARCHMENT, Board.TURF_WASH)
	var crown: Color = Pal.LEAF_LIGHT.lerp(Pal.PARCHMENT, Board.CROWN_WASH)
	for part in Geometry2D.intersect_polygons(paper, Face.Builder.ring(mid, TUMP_R.x * k, TUMP_R.y * k)):
		first = b.verts.size()
		b.polygon(part, Color.WHITE)
		shade(b, first, crown, turf, mid.y - TUMP_R.y * k, mid.y - TUMP_R.y * k * 0.45)
	var blade: Color = Pal.LEAF.lerp(Pal.PARCHMENT, Board.BLADE_WASH)
	for at: Vector3 in [Vector3(-0.42, 12.0, -3.0), Vector3(-0.3, 16.0, 2.0), Vector3(0.52, 15.0, 3.0),
			Vector3(0.64, 11.0, -2.0), Vector3(0.78, 13.0, 3.0)]:
		var x := mid.x + at.x * TUMP_R.x * k
		var y := mid.y - TUMP_R.y * k * sqrt(1.0 - at.x * at.x) + 2.0 * k
		var foot := Vector2(x - 4.0 * k, y)
		var tip := Vector2(x + 4.0 * k, y)
		var pts := Face.Builder.bezier2(foot, Vector2(x + at.z * k, y - at.y * k), tip, 8)
		pts.append(tip)
		b.polygon(pts, blade)
	_flower(b, mid + Vector2(0.62 * TUMP_R.x, -0.82 * TUMP_R.y) * k, 5.0 * k)
	# The flight: each row's shadow on the paper, then its pieces.
	var rows := GUESSES.size() + 1
	var round := s * Board.RADIUS
	for r in rows:
		var n := WORD.length() if r < GUESSES.size() or soon else TYPED.length()
		var from := _tile_at(r, 0)
		b.polygon(Face.Builder.round_rect(from + Vector2(-s * 0.03, s * 0.1),
			Vector2(_tile_at(r, n - 1).x + s - from.x + s * 0.06, s), round), Color(Pal.TEXT, 0.09))
	for r in GUESSES.size():
		var got := marks(GUESSES[r])
		for c in WORD.length():
			var fill: Color = Board.MARK[got[c]]
			var tone := (float((r * 5 + c) * 37 % 11) / 10.0) * 2.0 - 1.0
			fill = fill.lightened(tone * Board.TONE) if tone > 0.0 else fill.darkened(-tone * Board.TONE)
			_piece(b, _tile_at(r, c), s, fill, fill.lerp(Pal.TEXT, Board.EDGE_MIX),
				fill.lerp(Pal.SURFACE, Board.RIM_LIGHT))
	var last := rows - 1
	for c in WORD.length():
		var at := _tile_at(last, c)
		if c < TYPED.length():
			_piece(b, at, s, Pal.SURFACE.lerp(Pal.SURFACE_HI, Board.PAPER_CROWN),
				Pal.SURFACE_HI.lerp(Pal.LINE, Board.PAPER_LIP), Pal.SURFACE)
		elif soon:
			# No go tile on a card that cannot be opened: the bed the letter
			# would go into, sunk as the board sinks one.
			b.polygon(Face.Builder.round_rect(at, Vector2(s, s), round), Board.BED_SHADE)
			b.polygon(Face.Builder.round_rect(at + Vector2(0.0, s * Board.BED_LIP),
				Vector2(s, s * (1.0 - Board.BED_LIP)), round), Board.BED)
		else:
			_go(b, at + Vector2.ONE * (s * 0.5), s * GO_SIZE)

## One piece at `at`, `s` wide, as the board's `_tile_face` cuts it: the
## bottom edge in `deep`, the face in `rim`, and the crown in `fill` a bevel
## down and in from it.
func _piece(b: Face.Builder, at: Vector2, s: float, fill: Color, deep: Color, rim: Color) -> void:
	var r := s * Board.RADIUS
	var edge := maxf(LIP_MIN, s * LIP)
	var bev := s * Board.BEVEL
	b.polygon(Face.Builder.round_rect(at, Vector2(s, s), r), deep)
	b.polygon(Face.Builder.round_rect(at, Vector2(s, s - edge), r), rim)
	b.polygon(Face.Builder.round_rect(at + Vector2(bev * 0.7, bev), Vector2(s - bev * 1.4, s - edge - bev),
		maxf(r - bev * 0.5, 0.0)), fill)

## The go tile about `mid`: a piece in the card's colour over its own soft
## shadow, a chevron where its letter would be.
func _go(b: Face.Builder, mid: Vector2, s: float) -> void:
	var at := mid - Vector2.ONE * (s * 0.5)
	Scenery.soft_disc(b, mid + Vector2(0.0, s * 0.42), s * 0.58, s * 0.2, Color(Pal.TEXT, 0.2))
	_piece(b, at, s, colour, colour.darkened(0.26), colour.lerp(Pal.SURFACE, Board.RIM_LIGHT))
	var c := mid + Vector2(s * 0.02, -maxf(LIP_MIN, s * LIP) * 0.5)
	var h := s * 0.17
	b.stroke(PackedVector2Array([c + Vector2(-h * 0.55, -h), c + Vector2(h * 0.55, 0.0),
		c + Vector2(-h * 0.55, h)]), s * 0.1, Pal.SURFACE)

## A flower of `r`: five petals round a sun-yellow middle, as on the band.
func _flower(b: Face.Builder, at: Vector2, r: float) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(-PI * 0.5 + i * TAU / 5.0) * r, r * 0.78, Pal.FLOWER)
	b.disc(at, r * 0.58, Pal.SUN)

func _draw() -> void:
	super()
	var s := CELL * _ks()
	var font: Font = CozyTheme.display(700)
	var lift := Vector2(s * 0.5, (s - maxf(LIP_MIN, s * LIP)) * 0.5)
	for r in GUESSES.size():
		for c in WORD.length():
			Mosaic.letter(self, _tile_at(r, c) + lift, s, GUESSES[r][c], Vector2.ONE, Pal.PAPER, font)
	for c in TYPED.length():
		Mosaic.letter(self, _tile_at(GUESSES.size(), c) + lift, s, TYPED[c], Vector2.ONE, Pal.TEXT, font)

func _lay() -> void:
	var k := _k()
	# The words stand in the top left corner, clear of the seal's; the steps
	# are then fitted round where they ended.
	var room := size.x - SIDE - (SEAL_IN + SEAL_R + 10.0)
	var words := _words(String(entry.get("title", "")), SIDE, 0.0, room, Pal.TEXT, Color("7a6a50"))
	words.position.y = roundf(WORDS_TOP * k)
	_said.clear()
	# The column has not been sorted yet, so the lines are stacked by hand.
	var y := words.position.y
	for line in words.get_children():
		if line is Label:
			var took: Vector2 = line.get_combined_minimum_size()
			_said.append(Rect2(Vector2(words.position.x, y), took))
			y += took.y
	var px := SPROUT * k
	var sprout := SproutFace.new()
	sprout.size = Vector2(px, px)
	sprout.position = Vector2(SPROUT_AT.x * k, size.y - SPROUT_AT.y * k) - sprout.size * 0.5
	_keep(sprout)
	sprout.set_idle(true)
