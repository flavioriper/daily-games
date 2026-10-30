extends RefCounted

## What a chess player reads: a move in standard notation and the name of the
## opening on the board. Standard letters in every language, as a score sheet
## is, and the openings keep their English names. Pure data, no scene tree.
##
## The book is also what the computer opens from (`book_move`), so a game no
## longer starts from a shuffle of equal scores.

const Rules = preload("res://versus/chess_rules.gd")

const LETTER := ["", "", "N", "B", "R", "Q", "K"]

## [name, moves as from-to squares]. A line's name holds from its last move on
## until a longer line takes over.
const BOOK: Array = [
	["King's Pawn Opening", "e2e4"],
	["Queen's Pawn Opening", "d2d4"],
	["English Opening", "c2c4"],
	["Réti Opening", "g1f3"],
	["Open Game", "e2e4 e7e5"],
	["King's Knight Opening", "e2e4 e7e5 g1f3"],
	["Scotch Game", "e2e4 e7e5 g1f3 b8c6 d2d4"],
	["Scotch Game", "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4"],
	["Italian Game", "e2e4 e7e5 g1f3 b8c6 f1c4"],
	["Giuoco Piano", "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5"],
	["Giuoco Pianissimo", "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 d2d3"],
	["Italian Game: Main Line", "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6"],
	["Evans Gambit", "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 b2b4"],
	["Two Knights Defence", "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6"],
	["Ruy Lopez", "e2e4 e7e5 g1f3 b8c6 f1b5"],
	["Ruy Lopez: Morphy Defence", "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6"],
	["Ruy Lopez: Closed", "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7"],
	["Ruy Lopez: Berlin Defence", "e2e4 e7e5 g1f3 b8c6 f1b5 g8f6"],
	["Four Knights Game", "e2e4 e7e5 g1f3 b8c6 b1c3 g8f6"],
	["Petrov's Defence", "e2e4 e7e5 g1f3 g8f6"],
	["Philidor Defence", "e2e4 e7e5 g1f3 d7d6"],
	["Vienna Game", "e2e4 e7e5 b1c3"],
	["King's Gambit", "e2e4 e7e5 f2f4"],
	["King's Gambit Accepted", "e2e4 e7e5 f2f4 e5f4"],
	["Sicilian Defence", "e2e4 c7c5"],
	["Sicilian: Open", "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4"],
	["Sicilian: Najdorf", "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6"],
	["Sicilian: Dragon", "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 g7g6"],
	["Sicilian: Alapin", "e2e4 c7c5 c2c3"],
	["Sicilian: Closed", "e2e4 c7c5 b1c3"],
	["French Defence", "e2e4 e7e6"],
	["French: Advance", "e2e4 e7e6 d2d4 d7d5 e4e5"],
	["French: Exchange", "e2e4 e7e6 d2d4 d7d5 e4d5 e6d5"],
	["Caro-Kann Defence", "e2e4 c7c6"],
	["Caro-Kann: Advance", "e2e4 c7c6 d2d4 d7d5 e4e5"],
	["Caro-Kann: Classical", "e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 c8f5"],
	["Pirc Defence", "e2e4 d7d6 d2d4 g8f6 b1c3 g7g6"],
	["Scandinavian Defence", "e2e4 d7d5"],
	["Scandinavian: Main Line", "e2e4 d7d5 e4d5 d8d5 b1c3 d5a5"],
	["Alekhine's Defence", "e2e4 g8f6"],
	["Modern Defence", "e2e4 g7g6"],
	["Queen's Gambit", "d2d4 d7d5 c2c4"],
	["Queen's Gambit Declined", "d2d4 d7d5 c2c4 e7e6"],
	["Queen's Gambit Accepted", "d2d4 d7d5 c2c4 d5c4"],
	["Slav Defence", "d2d4 d7d5 c2c4 c7c6"],
	["London System", "d2d4 d7d5 g1f3 g8f6 c1f4"],
	["London System", "d2d4 g8f6 g1f3 e7e6 c1f4"],
	["Indian Defence", "d2d4 g8f6"],
	["Nimzo-Indian Defence", "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4"],
	["Queen's Indian Defence", "d2d4 g8f6 c2c4 e7e6 g1f3 b7b6"],
	["King's Indian Defence", "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6"],
	["Grünfeld Defence", "d2d4 g8f6 c2c4 g7g6 b1c3 d7d5"],
	["Benoni Defence", "d2d4 g8f6 c2c4 c7c5 d4d5"],
	["Dutch Defence", "d2d4 f7f5"],
	["English: Symmetrical", "c2c4 c7c5"],
	["English: Reversed Sicilian", "c2c4 e7e5"],
	["King's Indian Attack", "g1f3 d7d5 g2g3 g8f6 f1g2"],
]

## The from-to of a move, as the book writes it.
static func uci(m: int) -> String:
	return Rules.square_name(Rules.mv_from(m)) + Rules.square_name(Rules.mv_to(m))

## The moves played, one string, as the book's lines are.
static func line_of(moves: Array) -> String:
	var parts := PackedStringArray()
	for m: int in moves:
		parts.append(uci(m))
	return " ".join(parts)

## `m` in standard notation, in the position `g` before it is made. `g` comes
## back as it was.
static func san(g: RefCounted, m: int) -> String:
	var flags := Rules.mv_flags(m)
	var from := Rules.mv_from(m)
	var to := Rules.mv_to(m)
	var type := absi(int(g.board[from]))
	var text := ""
	if flags & Rules.F_CASTLE:
		text = "O-O" if to > from else "O-O-O"
	else:
		var takes: bool = g.board[to] != 0 or bool(flags & Rules.F_EP)
		if type == Rules.PAWN:
			text = ("abcdefgh"[from & 7] + "x" if takes else "") + Rules.square_name(to)
			if Rules.mv_promo(m) != 0:
				text += "=" + LETTER[Rules.mv_promo(m)]
		else:
			text = LETTER[type] + _ambiguity(g, m, type) + ("x" if takes else "") + Rules.square_name(to)
	g.make(m)
	if g.in_check():
		text += "#" if g.status() == Rules.MATE else "+"
	g.unmake()
	return text

## The file or rank (or both) that tells this piece from a twin going to the
## same square.
static func _ambiguity(g: RefCounted, m: int, type: int) -> String:
	var from := Rules.mv_from(m)
	var to := Rules.mv_to(m)
	var twins := PackedInt32Array()
	for other: int in g.legal_moves():
		var at := Rules.mv_from(other)
		if at != from and Rules.mv_to(other) == to and absi(int(g.board[at])) == type:
			twins.append(at)
	if twins.is_empty():
		return ""
	var same_file := false
	var same_rank := false
	for at in twins:
		same_file = same_file or (at & 7) == (from & 7)
		same_rank = same_rank or (at >> 3) == (from >> 3)
	var square := Rules.square_name(from)
	if not same_file:
		return square[0]
	return square[1] if not same_rank else square

## The name of the opening on the board after `moves`, "" when none is known.
## Past the book the last name stands, as a score sheet's heading does.
static func opening_of(moves: Array) -> String:
	var line := line_of(moves)
	var best := ""
	var length := -1
	for row: Array in BOOK:
		var known: String = row[1]
		if known.length() > length and (line == known or line.begins_with(known + " ")):
			best = row[0]
			length = known.length()
	return best

## A book reply to `moves`, or -1 once the game has left the book. Only a
## line at most `depth` plies long is followed, so a weak level leaves it
## early. `legal` is the position's moves: a book move must be one of them.
static func book_move(moves: Array, legal: PackedInt32Array, depth: int, rng: RandomNumberGenerator) -> int:
	if moves.size() >= depth:
		return -1
	var line := line_of(moves)
	var next := []
	for row: Array in BOOK:
		var known: String = row[1]
		var head := "" if line == "" else line + " "
		if known.begins_with(head) and known.length() > head.length():
			var step := known.substr(head.length(), 4)
			if not next.has(step):
				next.append(step)
	while not next.is_empty():
		var step: String = next.pop_at(rng.randi() % next.size())
		for m in legal:
			if uci(m) == step:
				return m
	return -1
