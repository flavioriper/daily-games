extends "res://ui/menu/cards/card_face.gd"

## Chess's card, on the Versus tab: the board's own top right corner on a
## pale lilac marble, files e to h and ranks 8 down to 6, its frame along
## the top and the right and the third rank running off the card's foot.
## On it stands a mate in one, the back rank: the rose king on g8 behind
## his own three pawns, a cream bishop on h6, and the rook on e6 with the
## e-file open above it. Rook to e8 is mate, and `_mates` asks the game's
## own rules (versus/chess_rules.gd) that it is.
##
## The go button is that rook: the set's rook in the card's colour, larger,
## lifted over its shadow, a chevron on the square it crosses pointing at
## e8, which is ringed. The name stands top left.
##
## Everything is one mesh, the pieces the garden set's own (the Versus
## tab's lineup drew the same); nothing lives on the card.

const Rules = preload("res://versus/chess_rules.gd")
const ChessSkin = preload("res://versus/chess_skin.gd")
const Board = preload("res://versus/chess_board.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A square at H, the frame's width, its room from the card's right side,
## and how far the eighth rank's top stands over the card's foot.
const CELL := 50.0
const FRAME := 9.0
const RIGHT := 12.0
const TOP := 146.0
## The files shown, from the e-file, and the ranks, from the eighth down.
const FILE0 := 4
const COLS := 4
const ROWS := 3
## The words end here: the board never starts left of it.
const WORDS_END := 244.0
## The position, as [file, rank, type, side]; side 0 is the player's cream.
const ROOK_FROM := Vector2i(4, 5)
const ROOK_TO := Vector2i(4, 7)
const PIECES: Array = [
	[6, 7, Rules.KING, 1], [5, 6, Rules.PAWN, 1], [6, 6, Rules.PAWN, 1], [7, 6, Rules.PAWN, 1],
	[7, 5, Rules.BISHOP, 0],
]
## The go rook: its size beside its siblings, how far it is lifted in
## squares, and its shadow.
const GO_SIZE := 1.16
const GO_LIFT := 0.2
const GO_SHADOW := 0.26
const SHADOW := 0.22
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The marble: a pale lilac over a deeper one, a pool behind the board, two
## faint veins, and the blurb's ink.
const MARBLE_TOP := Color("f1eef7")
const MARBLE_LOW := Color("e2ddef")
const POOL := Color("faf8fd")
const VEIN := Color("d3cce4")
const BLURB := Color("6d6883")

func _k() -> float:
	return minf(size.y / H, (size.x - WORDS_END) / (COLS * CELL + FRAME + RIGHT))

## The top left corner of the squares shown (the e8 square's).
func _origin() -> Vector2:
	var k := _k()
	return Vector2(size.x - (RIGHT + FRAME + COLS * CELL) * k, size.y - TOP * k)

## The middle of the square at `file`, `rank` (both from 0).
func _mid(file: int, rank: int) -> Vector2:
	return _origin() + Vector2(file - FILE0 + 0.5, 7 - rank + 0.5) * CELL * _k()

## Whether the rook's move mates, by the game's own rules.
static func _mates() -> bool:
	var g = Rules.new(true)
	g.board[0] = Rules.KING
	g.kings = PackedInt32Array([0, 62])
	for p: Array in PIECES:
		g.board[int(p[1]) * 8 + int(p[0])] = int(p[2]) * (1 if int(p[3]) == 0 else -1)
	g.board[ROOK_FROM.y * 8 + ROOK_FROM.x] = Rules.ROOK
	g.castling = 0
	g.turn = Rules.WHITE
	g.rehash()
	g.hashes.append(g.hash)
	var to := ROOK_TO.y * 8 + ROOK_TO.x
	for m: int in g.moves_from(ROOK_FROM.y * 8 + ROOK_FROM.x):
		if Rules.mv_to(m) == to:
			g.make(m)
			return g.status() == Rules.MATE
	return false

func _clipped(b: Face.Builder, paper: PackedVector2Array, at: Vector2, s: Vector2, col: Color) -> void:
	var rect := PackedVector2Array([at, at + Vector2(s.x, 0.0), at + s, at + Vector2(0.0, s.y)])
	for part in Geometry2D.intersect_polygons(paper, rect):
		b.polygon(part, col)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := CELL * k
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, MARBLE_TOP, MARBLE_LOW, 0.0, size.y)
	b.stroke(Face.Builder.bezier3(Vector2(size.x * 0.18, size.y * 0.74), Vector2(size.x * 0.3, size.y * 0.6),
		Vector2(size.x * 0.4, size.y * 0.86), Vector2(size.x * 0.52, size.y * 0.7)), 1.6 * k, Color(VEIN, 0.55))
	b.stroke(Face.Builder.bezier3(Vector2(size.x * 0.06, size.y * 0.9), Vector2(size.x * 0.12, size.y * 0.8),
		Vector2(size.x * 0.2, size.y * 0.92), Vector2(size.x * 0.27, size.y * 0.84)), 1.3 * k, Color(VEIN, 0.45))
	var o := _origin()
	Scenery.soft_disc(b, o + Vector2(COLS * 0.5, ROWS * 0.5) * s, s * 3.0, s * 2.1, Color(POOL, 0.6))
	# The frame along the top and down the right, then the squares.
	var f := FRAME * k
	_clipped(b, paper, o + Vector2(-f * 0.5, -f), Vector2(COLS * s + f * 1.5, f), Board.FRAME_COL)
	_clipped(b, paper, o + Vector2(COLS * s, -f), Vector2(f, size.y), Board.FRAME_COL)
	_clipped(b, paper, o + Vector2(-f * 0.5, -f), Vector2(COLS * s + f * 1.5, f * 0.32), Board.FRAME_LIP)
	_clipped(b, paper, o + Vector2(COLS * s + f * 0.68, -f), Vector2(f * 0.32, size.y), Board.FRAME_DEEP)
	for row in ROWS:
		for col in COLS:
			var dark := (FILE0 + col + 7 - row) % 2 == 0
			var at := o + Vector2(col, row) * s
			_clipped(b, paper, at, Vector2(s, s), Board.DARK if dark else Board.LIGHT)
			if dark:
				_clipped(b, paper, at + Vector2(0.0, s * 0.93), Vector2(s, s * 0.07), Board.DARK_DEEP)
	var go := not soon and _mates()
	if go:
		# The mating square, ringed, and the chevron on the square between.
		var home := _mid(ROOK_TO.x, ROOK_TO.y)
		Scenery.soft_disc(b, home, s * 0.5, s * 0.5, Color(Pal.SUN, 0.5))
		b.stroke(Face.Builder.ring(home, s * 0.34, s * 0.34), s * 0.075, Color(Pal.SUN, 0.95), true)
		var mid := _mid(ROOK_FROM.x, ROOK_FROM.y + 1) - Vector2(0.0, s * 0.12)
		var h := s * 0.17
		b.stroke(PackedVector2Array([mid + Vector2(-h, h * 0.55), mid + Vector2(0.0, -h * 0.55), mid + Vector2(h, h * 0.55)]),
			s * 0.11, colour)
	var skin: RefCounted = ChessSkin.named("garden")
	var drop := float(skin.foot_drop()) * s
	# From the back rank forward, so a piece stands over the one behind it.
	var order := PIECES.duplicate()
	order.sort_custom(func(a: Array, z: Array) -> bool: return int(a[1]) > int(z[1]))
	for p: Array in order:
		var foot := _mid(int(p[0]), int(p[1])) + Vector2(0.0, drop)
		Scenery.soft_disc(b, foot, s * 0.34, s * 0.1, Color(Pal.TEXT, SHADOW))
		var pb := Face.Builder.new()
		var type := int(p[2])
		skin.build(pb, type, int(p[3]), s, ChessSkin.F_WORRY if type == Rules.KING and go else ChessSkin.F_OPEN,
			-1.0 if int(p[3]) == 1 else 1.0)
		b.append(pb.mesh(), Transform2D(0.0, foot))
	# The rook: the go button, or a plain cream rook where it stands.
	var at := _mid(ROOK_FROM.x, ROOK_FROM.y) + Vector2(0.0, drop)
	var rb := Face.Builder.new()
	skin.build(rb, Rules.ROOK, 0, s, ChessSkin.F_JOY if go else ChessSkin.F_OPEN, 1.0)
	if not go:
		Scenery.soft_disc(b, at, s * 0.34, s * 0.1, Color(Pal.TEXT, SHADOW))
		b.append(rb.mesh(), Transform2D(0.0, at))
		return
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.04), s * 0.42, s * 0.13, Color(Pal.TEXT, GO_SHADOW))
	var cream: Color = Pal.KNIGHT_CREAM
	var tint := Color(colour.r / cream.r, colour.g / cream.g, colour.b / cream.b)
	b.append(rb.mesh(), Transform2D(0.0, Vector2.ONE * GO_SIZE, 0.0, at - Vector2(0.0, s * GO_LIFT)), tint)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
