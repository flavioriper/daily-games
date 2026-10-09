extends RefCounted

## Dominoes' rules, pure data: the Draw game for two with a double-six set,
## as pagat.com writes it down, and the calls it leaves open made once here.
##
## Twenty-eight tiles, every pair of 0 to 6. Seven each; the other fourteen
## are the boneyard. The leader lays any tile; after that a tile is laid at
## either end of the line with the half that matches the end's number
## touching it (a double lies across the line and counts once). A side with
## no tile that fits draws from the boneyard, one at a time, until one does:
## **only then** (pagat lets a player draw at will; here drawing is for a
## hand that cannot play). The boneyard's last two tiles are never drawn: a
## side that cannot play and cannot draw passes.
##
## A hand ends when a side lays its last tile, or when both pass one after
## the other (blocked). The side with fewer pips left wins the hand and
## scores the other's pips less its own; the same count is nobody's hand. The
## lead changes sides every hand. The first to TARGET wins the game (pagat's
## game for two is to 100; here it is 50, three or four hands).
##
## A tile is its index 0-27 (`LO`, `HI` its two numbers, low first). A move is
## `tile * 2 + end` (end 0 or 1 of the line), or DRAW, or PASS.
##
## Both hands and the boneyard's order are all in here, so the same seed
## deals the same game on every device (`_shuffle` is its own arithmetic, not
## the engine's). What one side may know of it is `view(side)`, and the
## computer is handed nothing else.

const TILES := 28
const HAND := 7
## The boneyard's tiles that are never drawn.
const KEEP := 2
const TARGET := 50
const LO := [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5, 5, 6]
const HI := [0, 1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6, 2, 3, 4, 5, 6, 3, 4, 5, 6, 4, 5, 6, 5, 6, 6]
const FIRST := 0
const SECOND := 1
const PLAYING := 0
const WON := 1
const DRAW := 56
const PASS := 57
## What `said` holds: [side, kind, a, b] -- a tile and its end for LAID, the
## line's two ends as they stood for DREW and PASSED.
enum { LAID, DREW, PASSED }

## Each side's tiles, in the order they came to hand.
var hands: Array = [PackedInt32Array(), PackedInt32Array()]
## The boneyard; a draw takes its last.
var stock := PackedInt32Array()
## The line as it was laid: Vector3i(tile, end, the number that touched the
## line), the leader's tile with end -1.
var plays: Array[Vector3i] = []
## The number open at each end, -1 before the first tile.
var ends := PackedInt32Array([-1, -1])
var turn := FIRST
## Who led this hand, and who led the first.
var leader := FIRST
var opener := FIRST
var hand_no := 0
var scores := PackedInt32Array([0, 0])
var deal_seed := 0
## Tiles laid and turns taken this game, for the counts on the end card.
var laid := 0
## Passes one after the other.
var passes := 0
## The hand is over; `next_hand` deals another unless the game is too.
var hand_over := false
## How it ended: who won it (-1 nobody), what it was worth, whether blocked.
var hand_winner := -1
var hand_points := 0
var hand_blocked := false
## The side whose move was the last made.
var last_mover := -1
var winner := -1
var said: Array = []
## A game inside the computer's head keeps none.
var quiet := false

static func id(a: int, b: int) -> int:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return lo * 7 - lo * (lo - 1) / 2 + hi - lo

static func is_double(tile: int) -> bool:
	return LO[tile] == HI[tile]

static func weight(tile: int) -> int:
	return LO[tile] + HI[tile]

## A new game from `the_seed`, `first` leading its first hand.
func deal(the_seed: int, first := FIRST) -> void:
	deal_seed = the_seed
	opener = first
	leader = first
	hand_no = 0
	scores = PackedInt32Array([0, 0])
	laid = 0
	winner = -1
	_deal_hand()

## The next hand of the game, once one is over and the game is not.
func next_hand() -> void:
	if not hand_over or winner >= 0:
		return
	hand_no += 1
	_deal_hand()

func _deal_hand() -> void:
	var deck := _shuffle(deal_seed, hand_no)
	hands = [deck.slice(0, HAND), deck.slice(HAND, HAND * 2)]
	stock = deck.slice(HAND * 2)
	_fresh()

func _fresh() -> void:
	plays = []
	ends = PackedInt32Array([-1, -1])
	turn = leader
	passes = 0
	hand_over = false
	hand_winner = -1
	hand_points = 0
	hand_blocked = false
	last_mover = -1
	said = []

## A hand set by hand (a tutorial page, a probe): the two hands, the boneyard
## and the tiles already laid, as moves from an empty line that are not
## checked against anybody's hand.
func lay(hand0: Array, hand1: Array, the_stock: Array, opening: Array = [], to_move := FIRST) -> void:
	hands = [PackedInt32Array(hand0), PackedInt32Array(hand1)]
	stock = PackedInt32Array(the_stock)
	leader = to_move
	_fresh()
	for m: int in opening:
		_place(m >> 1, m & 1)
	turn = to_move

## The twenty-eight tiles in the order `the_seed` and the hand's number give.
static func _shuffle(the_seed: int, hand: int) -> PackedInt32Array:
	var deck := PackedInt32Array()
	for t in TILES:
		deck.append(t)
	var s := (the_seed ^ (hand * 0x9E3779B1)) & 0x7fffffff
	for k in 8:
		s = (s * 1103515245 + 12345) & 0x7fffffff
	for i in range(TILES - 1, 0, -1):
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var j := (s >> 8) % (i + 1)
		var keep := deck[i]
		deck[i] = deck[j]
		deck[j] = keep
	return deck

func status() -> int:
	return WON if winner >= 0 else PLAYING

## Whether `tile` may be laid at `end` of the line as it stands.
func fits(tile: int, end: int) -> bool:
	if plays.is_empty():
		return true
	return LO[tile] == ends[end] or HI[tile] == ends[end]

## Whether the side to move holds a tile that can be laid.
func can_play() -> bool:
	for t in hands[turn]:
		if fits(t, 0) or fits(t, 1):
			return true
	return false

func can_draw() -> bool:
	return stock.size() > KEEP

func can(m: int) -> bool:
	if hand_over:
		return false
	if m == DRAW:
		return not can_play() and can_draw()
	if m == PASS:
		return not can_play() and not can_draw()
	if m < 0 or m >= TILES * 2:
		return false
	return hands[turn].has(m >> 1) and fits(m >> 1, m & 1)

## Every move the side to move has: its tiles that fit, each end once (one
## end only where the two ask for the same number), or DRAW alone, or PASS
## alone. None once the hand is over.
func legal_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	if hand_over:
		return out
	var same: bool = plays.is_empty() or ends[0] == ends[1]
	for t in hands[turn]:
		if fits(t, 0):
			out.append(t * 2)
		if not same and fits(t, 1):
			out.append(t * 2 + 1)
	if out.is_empty():
		out.append(DRAW if can_draw() else PASS)
	return out

## Makes the side to move's move. False for one that cannot be made.
func make(m: int) -> bool:
	if not can(m):
		return false
	var side := turn
	last_mover = side
	if m == DRAW:
		if not quiet:
			said.append([side, DREW, ends[0], ends[1]])
		hands[side].append(stock[stock.size() - 1])
		stock.remove_at(stock.size() - 1)
		return true
	if m == PASS:
		if not quiet:
			said.append([side, PASSED, ends[0], ends[1]])
		passes += 1
		turn = 1 - side
		if passes >= 2:
			_end_hand(-1)
		return true
	var tile := m >> 1
	var at: int = hands[side].find(tile)
	hands[side].remove_at(at)
	if not quiet:
		said.append([side, LAID, tile, m & 1])
	_place(tile, m & 1)
	passes = 0
	laid += 1
	turn = 1 - side
	if hands[side].is_empty():
		_end_hand(side)
	return true

func _place(tile: int, end: int) -> void:
	if plays.is_empty():
		plays.append(Vector3i(tile, -1, LO[tile]))
		ends[0] = LO[tile]
		ends[1] = HI[tile]
		return
	var touch := ends[end]
	plays.append(Vector3i(tile, end, touch))
	ends[end] = HI[tile] if LO[tile] == touch else LO[tile]

func pips(side: int) -> int:
	var n := 0
	for t in hands[side]:
		n += LO[t] + HI[t]
	return n

## The hand is over: `out` laid its last tile, or -1 for a blocked line.
func _end_hand(out: int) -> void:
	hand_over = true
	hand_blocked = out < 0
	var p := [pips(0), pips(1)]
	if p[0] == p[1]:
		hand_winner = -1
		hand_points = 0
	else:
		hand_winner = 0 if p[0] < p[1] else 1
		hand_points = absi(p[0] - p[1])
		scores[hand_winner] += hand_points
		if scores[hand_winner] >= TARGET:
			winner = hand_winner
	# The lead changes sides, and the side to lead is the side to move.
	leader = 1 - leader
	turn = leader

func copy() -> RefCounted:
	var r: RefCounted = get_script().new()
	r.hands = [hands[0].duplicate(), hands[1].duplicate()]
	r.stock = stock.duplicate()
	r.plays = plays.duplicate()
	r.ends = ends.duplicate()
	r.turn = turn
	r.leader = leader
	r.opener = opener
	r.hand_no = hand_no
	r.scores = scores.duplicate()
	r.deal_seed = deal_seed
	r.laid = laid
	r.passes = passes
	r.hand_over = hand_over
	r.hand_winner = hand_winner
	r.hand_points = hand_points
	r.hand_blocked = hand_blocked
	r.last_mover = last_mover
	r.winner = winner
	r.said = said.duplicate()
	r.quiet = quiet
	return r

## What `side` can see across the table: its own tiles, the line, how many
## tiles the other side and the boneyard hold, the scores, and everything
## that was done in the open. Not the other hand and not the boneyard.
func view(side: int) -> Dictionary:
	var on_line := PackedInt32Array()
	for p in plays:
		on_line.append(p.x)
	return {"side": side, "hand": hands[side].duplicate(), "line": on_line, "ends": ends.duplicate(),
		"theirs": hands[1 - side].size(), "stock": stock.size(), "scores": scores.duplicate(),
		"passes": passes, "said": said.duplicate(true), "legal": legal_moves() if turn == side else PackedInt32Array()}

## Everything that makes two games the same game, for a probe to compare.
func digest() -> String:
	return "%s|%s|%s|%s|%s|%d|%d|%s|%d|%d" % [hands[0], hands[1], stock, plays, ends, turn, hand_no, scores, int(hand_over), winner]
