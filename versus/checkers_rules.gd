extends RefCounted

## Checkers (draughts) as pure data: the board, every rule and make/unmake
## for the computer's search (versus/checkers_ai.gd). Nothing here draws;
## versus/checkers_board.gd does.
##
## Two rule sets, picked when the game is made:
##
## - BRAZILIAN (the default, the game as it is played in Brazil and the
##   international rules on an 8x8 board): light moves first, men step
##   forward but capture both ways, kings fly any distance along a diagonal,
##   capturing is compulsory and you must take the most pieces you can. A
##   man that crosses the far row in the middle of a capture and has to go
##   on stays a man.
## - AMERICAN (English draughts): dark moves first, men capture forward
##   only, kings step one square, compulsory capture but any sequence may be
##   chosen; a man reaching the far row by a jump is crowned and stops.
##
## Captured pieces are lifted only when the move ends, so a piece cannot be
## jumped twice and a taken piece still blocks the way (the "Turkish"
## rule); that is what the search below keeps in `taken`.
##
## A square is rank * 8 + file with a1 = 0; the dark squares, the only ones
## played on, are those where file + rank is even. A piece is MAN or KING
## signed by side: light positive, dark negative, 0 empty. A move is a
## PackedInt32Array: [from, n, landing 1 .. landing n, captured ...].

const EMPTY := 0
const MAN := 1
const KING := 2

const LIGHT := 0
const DARK := 1

enum Variant { BRAZILIAN, AMERICAN }

## How a game stands (status()). NO_MOVES: the side to move has none (all
## taken or all blocked) and has lost.
enum { PLAYING, NO_MOVES, QUIET, REPETITION }

## Plies with neither a capture nor a man moving before the game is drawn:
## twenty moves each of kings shuffling.
const QUIET_PLIES := 40

## RAYS[sq][d]: the squares out from sq along diagonal d, nearest first.
## d 0 and 1 run up the board (toward rank 8), 2 and 3 down.
static var RAYS: Array = []
## Zobrist keys: (piece + 2) * 64 + sq, and the side to move.
static var Z := PackedInt64Array()
static var Z_SIDE := 0

static func _static_init() -> void:
	var dirs := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	RAYS.resize(64)
	for sq in 64:
		var rays: Array = []
		for d: Vector2i in dirs:
			var ray := PackedInt32Array()
			var f := (sq & 7) + d.x
			var r := (sq >> 3) + d.y
			while f >= 0 and f < 8 and r >= 0 and r < 8:
				ray.append(r * 8 + f)
				f += d.x
				r += d.y
			rays.append(ray)
		RAYS[sq] = rays
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5eed_c4e5
	Z.resize(5 * 64)
	for i in Z.size():
		Z[i] = (rng.randi() << 32) ^ rng.randi()
	Z_SIDE = (rng.randi() << 32) ^ rng.randi()

var variant := Variant.BRAZILIAN
var flying := true
var men_back := true
var most := true
var board := PackedInt32Array()
var turn := LIGHT
## Plies since the last capture or man move.
var quiet := 0
var ply := 0
var hash := 0
var hashes := PackedInt64Array()
## Where in `hashes` the positions since the last irreversible move start.
var since := 0
var _undo: Array = []

func _init(v := Variant.BRAZILIAN, empty := false) -> void:
	variant = v
	flying = v == Variant.BRAZILIAN
	men_back = v == Variant.BRAZILIAN
	most = v == Variant.BRAZILIAN
	board.resize(64)
	if not empty:
		for sq in 64:
			var r := sq >> 3
			if ((sq & 7) + r) % 2 != 0:
				continue
			if r <= 2:
				board[sq] = MAN
			elif r >= 5:
				board[sq] = -MAN
	turn = first_side()
	rehash()
	hashes = PackedInt64Array([hash])

func first_side() -> int:
	return LIGHT if variant == Variant.BRAZILIAN else DARK

func copy() -> RefCounted:
	var g: RefCounted = get_script().new(variant, true)
	g.board = board.duplicate()
	g.turn = turn
	g.quiet = quiet
	g.ply = ply
	g.hash = hash
	g.hashes = hashes.duplicate()
	g.since = since
	return g

func rehash() -> void:
	hash = 0
	for sq in 64:
		if board[sq] != 0:
			hash ^= Z[(board[sq] + 2) * 64 + sq]
	if turn == DARK:
		hash ^= Z_SIDE

static func side_of(p: int) -> int:
	return LIGHT if p > 0 else DARK

static func sign_of(side: int) -> int:
	return 1 if side == LIGHT else -1

static func last_rank(side: int) -> int:
	return 7 if side == LIGHT else 0

static func is_dark(sq: int) -> bool:
	return ((sq & 7) + (sq >> 3)) % 2 == 0

# --- moves ---

static func mv_from(m: PackedInt32Array) -> int:
	return m[0]

static func mv_to(m: PackedInt32Array) -> int:
	return m[1 + m[1]]

static func mv_path(m: PackedInt32Array) -> PackedInt32Array:
	return m.slice(2, 2 + m[1])

static func mv_caps(m: PackedInt32Array) -> PackedInt32Array:
	return m.slice(2 + m[1])

static func mv_ncaps(m: PackedInt32Array) -> int:
	return m.size() - 2 - m[1]

## One int that tells two moves apart well enough to order them (the
## computer's best-move memory): from, to, the first landing and the count.
static func mv_key(m: PackedInt32Array) -> int:
	return m[0] | (mv_to(m) << 6) | (m[2] << 12) | (mv_ncaps(m) << 18)

static func _encode(from: int, path: PackedInt32Array, caps: PackedInt32Array) -> PackedInt32Array:
	var m := PackedInt32Array([from, path.size()])
	m.append_array(path)
	m.append_array(caps)
	return m

## Every legal move for the side to move. Captures, when there are any,
## are the only moves; under BRAZILIAN only those taking the most.
func legal_moves() -> Array:
	var caps: Array = []
	var s := sign_of(turn)
	for sq in 64:
		if board[sq] * s > 0:
			_captures(sq, caps)
	if not caps.is_empty():
		if most:
			var best := 0
			for m: PackedInt32Array in caps:
				best = maxi(best, mv_ncaps(m))
			caps = caps.filter(func(m: PackedInt32Array) -> bool: return mv_ncaps(m) == best)
		return _dedupe(caps)
	var out: Array = []
	for sq in 64:
		var p := board[sq]
		if p * s <= 0:
			continue
		var king := absi(p) == KING
		for d in 4:
			if not king and not _forward(turn, d):
				continue
			for t in RAYS[sq][d]:
				if board[t] != 0:
					break
				out.append(PackedInt32Array([sq, 1, t]))
				if not king or not flying:
					break
	return out

func moves_from(sq: int) -> Array:
	return legal_moves().filter(func(m: PackedInt32Array) -> bool: return m[0] == sq)

## Whether the side to move is bound to capture.
func must_capture() -> bool:
	var moves := legal_moves()
	return not moves.is_empty() and mv_ncaps(moves[0]) > 0

static func _forward(side: int, d: int) -> bool:
	return d < 2 if side == LIGHT else d >= 2

## Two sequences that end on the same square having taken the same pieces
## are one move.
static func _dedupe(moves: Array) -> Array:
	var seen := {}
	var out: Array = []
	for m: PackedInt32Array in moves:
		var caps := mv_caps(m)
		caps.sort()
		var key := "%d>%d:%s" % [m[0], mv_to(m), caps]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(m)
	return out

## The capture search's scratch, kept rather than made a node: `taken`
## is back to all zeros whenever a search returns.
var _taken := PackedByteArray()
var _path := PackedInt32Array()
var _capd := PackedInt32Array()

func _captures(sq: int, out: Array) -> void:
	var p := board[sq]
	if _taken.is_empty():
		_taken.resize(64)
	# a quick look first: most pieces most of the time have nothing to take
	if not _can_take(sq, p):
		return
	board[sq] = 0
	_jump(sq, sq, p, _path, _capd, _taken, out)
	board[sq] = p

func _can_take(sq: int, p: int) -> bool:
	var side := side_of(p)
	var s := sign_of(side)
	var king := absi(p) == KING
	for d in 4:
		if not king and not men_back and not _forward(side, d):
			continue
		var ray: PackedInt32Array = RAYS[sq][d]
		var i := 0
		if king and flying:
			while i < ray.size() and board[ray[i]] == 0:
				i += 1
		if i + 1 < ray.size() and board[ray[i]] * s < 0 and board[ray[i + 1]] == 0:
			return true
	return false

func _jump(origin: int, at: int, p: int, path: PackedInt32Array, capd: PackedInt32Array,
		taken: PackedByteArray, out: Array) -> void:
	var side := side_of(p)
	var s := sign_of(side)
	var king := absi(p) == KING
	var any := false
	for d in 4:
		if not king and not men_back and not _forward(side, d):
			continue
		var ray: PackedInt32Array = RAYS[at][d]
		if king and flying:
			var i := 0
			while i < ray.size() and board[ray[i]] == 0:
				i += 1
			if i + 1 >= ray.size():
				continue
			var over := ray[i]
			if taken[over] != 0 or board[over] * s > 0 or board[ray[i + 1]] != 0:
				continue
			any = true
			taken[over] = 1
			capd.append(over)
			var j := i + 1
			while j < ray.size() and board[ray[j]] == 0:
				path.append(ray[j])
				_jump(origin, ray[j], p, path, capd, taken, out)
				path.remove_at(path.size() - 1)
				j += 1
			capd.remove_at(capd.size() - 1)
			taken[over] = 0
		else:
			if ray.size() < 2:
				continue
			var over := ray[0]
			var land := ray[1]
			if board[over] * s >= 0 or taken[over] != 0 or board[land] != 0:
				continue
			any = true
			taken[over] = 1
			capd.append(over)
			path.append(land)
			if not king and variant == Variant.AMERICAN and (land >> 3) == last_rank(side):
				# crowned by the jump: the move ends here
				out.append(_encode(origin, path, capd))
			else:
				_jump(origin, land, p, path, capd, taken, out)
			path.remove_at(path.size() - 1)
			capd.remove_at(capd.size() - 1)
			taken[over] = 0
	if not any and not capd.is_empty():
		out.append(_encode(origin, path, capd))

## Everything the board needs to play `m` as a scene, taken before make().
func describe(m: PackedInt32Array) -> Dictionary:
	var from := m[0]
	var to := mv_to(m)
	var p := board[from]
	var caps := mv_caps(m)
	var capvals: Array = []
	for c in caps:
		capvals.append(board[c])
	return {
		"from": from, "to": to, "path": Array(mv_path(m)), "caps": Array(caps), "capvals": capvals,
		"piece": p, "side": side_of(p),
		"crown": absi(p) == MAN and (to >> 3) == last_rank(side_of(p)),
	}

func make(m: PackedInt32Array) -> void:
	var from := m[0]
	var to := mv_to(m)
	var p := board[from]
	var caps := mv_caps(m)
	var capvals := PackedInt32Array()
	board[from] = 0
	hash ^= Z[(p + 2) * 64 + from]
	for c in caps:
		capvals.append(board[c])
		hash ^= Z[(board[c] + 2) * 64 + c]
		board[c] = 0
	var np := p
	if absi(p) == MAN and (to >> 3) == last_rank(side_of(p)):
		np = KING * sign_of(side_of(p))
	board[to] = np
	hash ^= Z[(np + 2) * 64 + to]
	turn = 1 - turn
	hash ^= Z_SIDE
	_undo.append([m, p, capvals, quiet, since])
	if not caps.is_empty() or absi(p) == MAN:
		quiet = 0
		since = hashes.size()
	else:
		quiet += 1
	hashes.append(hash)
	ply += 1

func unmake() -> void:
	var rec: Array = _undo.pop_back()
	var m: PackedInt32Array = rec[0]
	var p: int = rec[1]
	var capvals: PackedInt32Array = rec[2]
	var caps := mv_caps(m)
	board[mv_to(m)] = 0
	board[m[0]] = p
	for i in caps.size():
		board[caps[i]] = capvals[i]
	quiet = rec[3]
	since = rec[4]
	turn = 1 - turn
	hashes.resize(hashes.size() - 1)
	hash = hashes[hashes.size() - 1]
	ply -= 1

## Can a move be taken back (the screen's undo walks these).
func can_unmake() -> bool:
	return not _undo.is_empty()

func repeats() -> int:
	var n := 0
	for i in range(since, hashes.size()):
		if hashes[i] == hash:
			n += 1
	return n

func status() -> int:
	if legal_moves().is_empty():
		return NO_MOVES
	if quiet >= QUIET_PLIES:
		return QUIET
	if repeats() >= 3:
		return REPETITION
	return PLAYING

## Men and kings a side has on the board.
func count(side: int) -> Vector2i:
	var s := sign_of(side)
	var n := Vector2i.ZERO
	for p in board:
		if p * s > 0:
			if absi(p) == MAN:
				n.x += 1
			else:
				n.y += 1
	return n

## Pieces a side has lost: 12 less what it has left.
func lost(side: int) -> int:
	var n := count(side)
	return 12 - n.x - n.y
