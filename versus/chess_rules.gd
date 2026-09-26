extends RefCounted

## Chess as pure data: the board, every rule (castling, en passant,
## promotion, check, mate, stalemate, the fifty-move rule, threefold
## repetition, insufficient material) and make/unmake for the computer's
## search (versus/chess_ai.gd). Nothing here draws; versus/chess_board.gd
## does.
##
## A square is rank * 8 + file with a1 = 0 and h8 = 63, so white's back rank
## is 0-7. A piece is its type signed by side: white positive, black
## negative, 0 empty. A move is one int (mv()): from, to, the promotion type
## and flags. White always moves first; which side the player takes is the
## screen's business.

const EMPTY := 0
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6

const WHITE := 0
const BLACK := 1

const F_CAPTURE := 1
const F_EP := 2
const F_CASTLE := 4
const F_DOUBLE := 8
const F_PROMO := 16

## Castling rights, one bit each.
const WK := 1
const WQ := 2
const BK := 4
const BQ := 8

## How a game stands (status()).
enum { PLAYING, MATE, STALEMATE, FIFTY, REPETITION, MATERIAL }

const START := [ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK]

# --- tables, built once when the class loads (before any worker thread) ---

static var KNIGHT_T: Array = []
static var KING_T: Array = []
## RAYS[d][sq]: the squares out from sq in direction d, nearest first.
## 0-3 are the rook's lines, 4-7 the bishop's.
static var RAYS: Array = []
## Zobrist keys: piece (index (piece + 6) * 64 + sq), side, rights, ep file.
static var Z_PIECE := PackedInt64Array()
static var Z_SIDE := 0
static var Z_CASTLE := PackedInt64Array()
static var Z_EP := PackedInt64Array()
## A move from or to one of these squares takes these rights away.
static var CASTLE_KEEP := PackedInt32Array()

static func _static_init() -> void:
	var dirs := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var jumps := [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
		Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)]
	for d in 8:
		RAYS.append([])
	for sq in 64:
		var f := sq & 7
		var r := sq >> 3
		var kn := PackedInt32Array()
		for j: Vector2i in jumps:
			if _on(f + j.x, r + j.y):
				kn.append((r + j.y) * 8 + f + j.x)
		KNIGHT_T.append(kn)
		var kg := PackedInt32Array()
		for d: Vector2i in dirs:
			if _on(f + d.x, r + d.y):
				kg.append((r + d.y) * 8 + f + d.x)
		KING_T.append(kg)
		for i in 8:
			var ray := PackedInt32Array()
			var ff: int = f + dirs[i].x
			var rr: int = r + dirs[i].y
			while _on(ff, rr):
				ray.append(rr * 8 + ff)
				ff += dirs[i].x
				rr += dirs[i].y
			RAYS[i].append(ray)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926
	Z_PIECE.resize(13 * 64)
	for i in 13 * 64:
		Z_PIECE[i] = _rand64(rng)
	Z_SIDE = _rand64(rng)
	Z_CASTLE.resize(16)
	for i in 16:
		Z_CASTLE[i] = _rand64(rng)
	Z_EP.resize(8)
	for i in 8:
		Z_EP[i] = _rand64(rng)
	CASTLE_KEEP.resize(64)
	for sq in 64:
		CASTLE_KEEP[sq] = 15
	CASTLE_KEEP[0] = 15 & ~WQ
	CASTLE_KEEP[7] = 15 & ~WK
	CASTLE_KEEP[4] = 15 & ~(WK | WQ)
	CASTLE_KEEP[56] = 15 & ~BQ
	CASTLE_KEEP[63] = 15 & ~BK
	CASTLE_KEEP[60] = 15 & ~(BK | BQ)

static func _on(f: int, r: int) -> bool:
	return f >= 0 and f < 8 and r >= 0 and r < 8

static func _rand64(rng: RandomNumberGenerator) -> int:
	return (int(rng.randi()) << 32) ^ int(rng.randi())

# --- moves as ints ---

static func mv(from: int, to: int, promo := 0, flags := 0) -> int:
	return from | (to << 6) | (promo << 12) | (flags << 16)

static func mv_from(m: int) -> int:
	return m & 63

static func mv_to(m: int) -> int:
	return (m >> 6) & 63

static func mv_promo(m: int) -> int:
	return (m >> 12) & 7

static func mv_flags(m: int) -> int:
	return m >> 16

static func side_of(piece: int) -> int:
	return WHITE if piece > 0 else BLACK

static func square_name(sq: int) -> String:
	return "abcdefgh"[sq & 7] + str((sq >> 3) + 1)

# --- the position ---

var board := PackedInt32Array()
var turn := WHITE
var castling := 15
var ep := -1
var halfmove := 0
var fullmove := 1
var kings := PackedInt32Array([4, 60])
var hash := 0
## One entry a ply for unmake: [move, captured piece, castling, ep, halfmove, hash].
var undo_stack: Array = []
## The position's hash after every ply, the start included, for repetition.
var hashes := PackedInt64Array()

func _init(empty := false) -> void:
	board.resize(64)
	if empty:
		return
	for f in 8:
		board[f] = START[f]
		board[8 + f] = PAWN
		board[48 + f] = -PAWN
		board[56 + f] = -START[f]
	rehash()
	hashes.append(hash)

func copy() -> RefCounted:
	var c: RefCounted = get_script().new(true)
	c.board = board.duplicate()
	c.turn = turn
	c.castling = castling
	c.ep = ep
	c.halfmove = halfmove
	c.fullmove = fullmove
	c.kings = kings.duplicate()
	c.hash = hash
	c.hashes = hashes.duplicate()
	# The search never unmakes past the copy, so the stack starts empty.
	return c

func rehash() -> void:
	hash = 0
	for sq in 64:
		var p := board[sq]
		if p != 0:
			hash ^= Z_PIECE[(p + 6) * 64 + sq]
			if absi(p) == KING:
				kings[side_of(p)] = sq
	if turn == BLACK:
		hash ^= Z_SIDE
	hash ^= Z_CASTLE[castling]
	if ep != -1:
		hash ^= Z_EP[ep & 7]

# --- attacks ---

## Whether side `by` attacks `sq`.
func attacked(sq: int, by: int) -> bool:
	var s := 1 if by == WHITE else -1
	var f := sq & 7
	var pr := (sq >> 3) - s
	if pr >= 0 and pr < 8:
		if f > 0 and board[pr * 8 + f - 1] == PAWN * s:
			return true
		if f < 7 and board[pr * 8 + f + 1] == PAWN * s:
			return true
	for t: int in KNIGHT_T[sq]:
		if board[t] == KNIGHT * s:
			return true
	for t: int in KING_T[sq]:
		if board[t] == KING * s:
			return true
	for d in 8:
		for t: int in RAYS[d][sq]:
			var p := board[t]
			if p == 0:
				continue
			if p * s > 0:
				var ty := absi(p)
				if ty == QUEEN or (d < 4 and ty == ROOK) or (d >= 4 and ty == BISHOP):
					return true
			break
	return false

func in_check(side := -1) -> bool:
	var sd := turn if side == -1 else side
	return attacked(kings[sd], 1 - sd)

## Every square side `by` attacks a piece of the other side on: the pieces
## that would look worried.
func attackers_of(sq: int, by: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for m in _pseudo_for(by, true):
		if mv_to(m) == sq:
			out.append(mv_from(m))
	return out

# --- move generation ---

## Every pseudo-legal move for the side to move (legality is make and look).
func pseudo(captures_only := false) -> PackedInt32Array:
	return _pseudo_for(turn, captures_only)

func _pseudo_for(side: int, captures_only: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	var s := 1 if side == WHITE else -1
	for sq in 64:
		var p := board[sq]
		if p == 0 or (p > 0) != (s > 0):
			continue
		var ty := absi(p)
		match ty:
			PAWN:
				_pawn_moves(out, sq, s, captures_only)
			KNIGHT:
				for t: int in KNIGHT_T[sq]:
					var q := board[t]
					if q == 0:
						if not captures_only:
							out.append(mv(sq, t))
					elif q * s < 0:
						out.append(mv(sq, t, 0, F_CAPTURE))
			KING:
				for t: int in KING_T[sq]:
					var q := board[t]
					if q == 0:
						if not captures_only:
							out.append(mv(sq, t))
					elif q * s < 0:
						out.append(mv(sq, t, 0, F_CAPTURE))
				if not captures_only:
					_castles(out, side)
			_:
				var from_d := 4 if ty == BISHOP else 0
				var to_d := 4 if ty == ROOK else 8
				for d in range(from_d, to_d):
					for t: int in RAYS[d][sq]:
						var q := board[t]
						if q == 0:
							if not captures_only:
								out.append(mv(sq, t))
							continue
						if q * s < 0:
							out.append(mv(sq, t, 0, F_CAPTURE))
						break
	return out

func _pawn_moves(out: PackedInt32Array, sq: int, s: int, captures_only: bool) -> void:
	var f := sq & 7
	var r := sq >> 3
	var one := sq + 8 * s
	var last := 7 if s > 0 else 0
	var start := 1 if s > 0 else 6
	var promoting := (one >> 3) == last
	if board[one] == 0 and (not captures_only or promoting):
		if promoting:
			for pt in [QUEEN, KNIGHT, ROOK, BISHOP]:
				out.append(mv(sq, one, pt, F_PROMO))
		else:
			out.append(mv(sq, one))
			if r == start and board[one + 8 * s] == 0 and not captures_only:
				out.append(mv(sq, one + 8 * s, 0, F_DOUBLE))
	for df in [-1, 1]:
		var ff: int = f + df
		if ff < 0 or ff > 7:
			continue
		var t: int = one + df
		var q := board[t]
		if q * s < 0:
			if promoting:
				for pt in [QUEEN, KNIGHT, ROOK, BISHOP]:
					out.append(mv(sq, t, pt, F_PROMO | F_CAPTURE))
			else:
				out.append(mv(sq, t, 0, F_CAPTURE))
		elif t == ep and q == 0:
			out.append(mv(sq, t, 0, F_EP | F_CAPTURE))

func _castles(out: PackedInt32Array, side: int) -> void:
	var k := 4 if side == WHITE else 60
	var s := 1 if side == WHITE else -1
	if kings[side] != k or board[k] != KING * s:
		return
	var foe := 1 - side
	var short_right := WK if side == WHITE else BK
	var long_right := WQ if side == WHITE else BQ
	if castling & short_right and board[k + 1] == 0 and board[k + 2] == 0 and board[k + 3] == ROOK * s:
		if not attacked(k, foe) and not attacked(k + 1, foe) and not attacked(k + 2, foe):
			out.append(mv(k, k + 2, 0, F_CASTLE))
	if castling & long_right and board[k - 1] == 0 and board[k - 2] == 0 and board[k - 3] == 0 and board[k - 4] == ROOK * s:
		if not attacked(k, foe) and not attacked(k - 1, foe) and not attacked(k - 2, foe):
			out.append(mv(k, k - 2, 0, F_CASTLE))

## The legal moves of the side to move.
func legal_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	var mover := turn
	for m in pseudo():
		make(m)
		if not attacked(kings[mover], turn):
			out.append(m)
		unmake()
	return out

func moves_from(sq: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for m in legal_moves():
		if mv_from(m) == sq:
			out.append(m)
	return out

# --- make and unmake ---

func make(m: int) -> void:
	var from := m & 63
	var to := (m >> 6) & 63
	var promo := (m >> 12) & 7
	var flags := m >> 16
	var piece := board[from]
	var s := 1 if piece > 0 else -1
	var captured := board[to]
	undo_stack.append([m, captured, castling, ep, halfmove, hash])
	hash ^= Z_PIECE[(piece + 6) * 64 + from]
	if captured != 0:
		hash ^= Z_PIECE[(captured + 6) * 64 + to]
	if flags & F_EP:
		var cap_sq := to - 8 * s
		captured = board[cap_sq]
		hash ^= Z_PIECE[(captured + 6) * 64 + cap_sq]
		board[cap_sq] = 0
		undo_stack[-1][1] = captured
	var placed := promo * s if promo != 0 else piece
	board[to] = placed
	board[from] = 0
	hash ^= Z_PIECE[(placed + 6) * 64 + to]
	if absi(piece) == KING:
		kings[0 if s > 0 else 1] = to
		if flags & F_CASTLE:
			var rf := from + 3 if to > from else from - 4
			var rt := from + 1 if to > from else from - 1
			var rook := board[rf]
			board[rt] = rook
			board[rf] = 0
			hash ^= Z_PIECE[(rook + 6) * 64 + rf] ^ Z_PIECE[(rook + 6) * 64 + rt]
	hash ^= Z_CASTLE[castling]
	castling &= CASTLE_KEEP[from] & CASTLE_KEEP[to]
	hash ^= Z_CASTLE[castling]
	if ep != -1:
		hash ^= Z_EP[ep & 7]
	ep = (from + to) >> 1 if flags & F_DOUBLE else -1
	if ep != -1:
		hash ^= Z_EP[ep & 7]
	halfmove = 0 if absi(piece) == PAWN or captured != 0 else halfmove + 1
	if s < 0:
		fullmove += 1
	turn = 1 - turn
	hash ^= Z_SIDE
	hashes.append(hash)

func unmake() -> void:
	var u: Array = undo_stack.pop_back()
	hashes.resize(hashes.size() - 1)
	var m: int = u[0]
	var from := m & 63
	var to := (m >> 6) & 63
	var promo := (m >> 12) & 7
	var flags := m >> 16
	turn = 1 - turn
	var s := 1 if turn == WHITE else -1
	var piece := board[to]
	if promo != 0:
		piece = PAWN * s
	board[from] = piece
	board[to] = 0
	var captured: int = u[1]
	if flags & F_EP:
		board[to - 8 * s] = captured
	else:
		board[to] = captured
	if absi(piece) == KING:
		kings[turn] = from
		if flags & F_CASTLE:
			var rf := from + 3 if to > from else from - 4
			var rt := from + 1 if to > from else from - 1
			board[rf] = board[rt]
			board[rt] = 0
	castling = u[2]
	ep = u[3]
	halfmove = u[4]
	hash = u[5]
	if s < 0:
		fullmove -= 1

# --- how the game stands ---

## The position has stood here before in this game (twice more for a draw
## by the rule, once more is enough for the search).
func repeats(times := 3) -> bool:
	var n := hashes.size()
	var count := 1
	var i := n - 3
	var floor_i := maxi(0, n - 1 - halfmove)
	while i >= floor_i:
		if hashes[i] == hash:
			count += 1
			if count >= times:
				return true
		i -= 2
	return false

func insufficient() -> bool:
	var minors: Array = []
	for sq in 64:
		var ty := absi(board[sq])
		if ty == PAWN or ty == ROOK or ty == QUEEN:
			return false
		if ty == KNIGHT or ty == BISHOP:
			minors.append([ty, sq])
	if minors.size() <= 1:
		return true
	# Bishops only, all on one colour of square.
	var colour := -1
	for m: Array in minors:
		if m[0] != BISHOP:
			return false
		var c: int = ((m[1] & 7) + (m[1] >> 3)) & 1
		if colour == -1:
			colour = c
		elif c != colour:
			return false
	return true

func status() -> int:
	if legal_moves().is_empty():
		return MATE if in_check() else STALEMATE
	if halfmove >= 100:
		return FIFTY
	if repeats(3):
		return REPETITION
	if insufficient():
		return MATERIAL
	return PLAYING

# --- what a move does, for the drawing ---

## Everything the board needs to animate `m` before it is made: the piece,
## where it goes, what it takes and from where, the rook's hop in a castle,
## the promotion.
func describe(m: int) -> Dictionary:
	var from := mv_from(m)
	var to := mv_to(m)
	var flags := mv_flags(m)
	var piece := board[from]
	var s := 1 if piece > 0 else -1
	var d := {"move": m, "from": from, "to": to, "piece": piece, "side": side_of(piece),
		"captured": 0, "captured_at": -1, "rook_from": -1, "rook_to": -1, "promo": mv_promo(m) * s}
	if flags & F_EP:
		d.captured = board[to - 8 * s]
		d.captured_at = to - 8 * s
	elif board[to] != 0:
		d.captured = board[to]
		d.captured_at = to
	if flags & F_CASTLE:
		d.rook_from = from + 3 if to > from else from - 4
		d.rook_to = from + 1 if to > from else from - 1
	return d

## Material still on the board per side, in pawns, for the scoreboard.
func material(side: int) -> int:
	var worth := [0, 1, 3, 3, 5, 9, 0]
	var total := 0
	for sq in 64:
		var p := board[sq]
		if p != 0 and side_of(p) == side:
			total += worth[absi(p)]
	return total
