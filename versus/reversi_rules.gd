extends RefCounted

## Reversi's rules, pure data: a board of eight by eight and discs with two
## faces. The four middle squares start filled, two of each side on the
## slants. A turn is one disc set on an empty square so that, along a row, a
## column or a slant, it shuts a straight run of the other side's discs
## between itself and another of the mover's own; every run it shuts, in all
## eight directions at once, is turned over. A square that shuts nothing may
## not be played. A side with no square to play passes -- it is never a
## choice -- and the game ends when neither side has one. The side showing
## more discs wins; the same count is a draw.
##
## A cell is `x + y * W`, y 0 the top row. A move is its cell. The pass is
## made by `make` itself: after a move `turn` is the side that moves next,
## which is the same side again when the other has no square (`passed`).

const W := 8
const CELLS := W * W
const EMPTY := 0
## The two sides; FIRST moves first. A cell holds the side plus one.
const FIRST := 0
const SECOND := 1
const PLAYING := 0
const WON := 1
const DRAW := 2
const DIRS := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

## For each cell, its eight rays: the cells out to the edge, nearest first.
static var _rays: Array = []

var cells := PackedByteArray()
var turn := FIRST
var ply := 0
## True when the last move left the other side with no square, so the mover
## moves again (or the game ended there).
var passed := false
## The side that made the last move, -1 before any.
var last_side := -1
var over := false
## Each move made: [cell, the cells it turned, the turn before, `passed`
## before, `last_side` before].
var history: Array = []

func _init() -> void:
	cells.resize(CELLS)
	cells[cell(3, 3)] = SECOND + 1
	cells[cell(4, 4)] = SECOND + 1
	cells[cell(4, 3)] = FIRST + 1
	cells[cell(3, 4)] = FIRST + 1

static func cell(x: int, y: int) -> int:
	return x + y * W

static func rays() -> Array:
	if _rays.is_empty():
		var all := []
		for c in CELLS:
			var mine := []
			for d: Vector2i in DIRS:
				var ray := PackedInt32Array()
				var x := c % W + d.x
				var y := c / W + d.y
				while x >= 0 and x < W and y >= 0 and y < W:
					ray.append(x + y * W)
					x += d.x
					y += d.y
				mine.append(ray)
			all.append(mine)
		_rays = all
	return _rays

func at(x: int, y: int) -> int:
	return cells[x + y * W]

## How many discs show the side's face.
func count(side: int) -> int:
	return cells.count(side + 1)

## The cells a disc of `side` set on `c` would turn over, nearest first along
## each line; empty when the square is taken or shuts nothing.
func flips(c: int, side: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if c < 0 or c >= CELLS or cells[c] != EMPTY:
		return out
	var mine := side + 1
	var theirs := 2 - side
	for ray: PackedInt32Array in rays()[c]:
		var n := 0
		for q in ray:
			var v := cells[q]
			if v == theirs:
				n += 1
				continue
			if v == mine:
				for i in n:
					out.append(ray[i])
			break
	return out

func can(c: int) -> bool:
	return not over and not flips(c, turn).is_empty()

func has_move(side: int) -> bool:
	for c in CELLS:
		if cells[c] == EMPTY and not flips(c, side).is_empty():
			return true
	return false

## The squares the side to move may play, none once the game is over.
func legal_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	if over:
		return out
	for c in CELLS:
		if cells[c] == EMPTY and not flips(c, turn).is_empty():
			out.append(c)
	return out

func status() -> int:
	if not over:
		return PLAYING
	return DRAW if count(FIRST) == count(SECOND) else WON

## The side showing more discs once the game is over, -1 for none.
func winner() -> int:
	if not over:
		return -1
	var a := count(FIRST)
	var b := count(SECOND)
	return -1 if a == b else (FIRST if a > b else SECOND)

## Sets the side to move's disc on `c`. The cells it turned over, empty for a
## move that cannot be made.
func make(c: int) -> PackedInt32Array:
	if over:
		return PackedInt32Array()
	var turned := flips(c, turn)
	if turned.is_empty():
		return turned
	history.append([c, turned, turn, passed, last_side])
	cells[c] = turn + 1
	for q in turned:
		cells[q] = turn + 1
	ply += 1
	last_side = turn
	var other := 1 - turn
	passed = false
	if has_move(other):
		turn = other
	else:
		passed = true
		if not has_move(turn):
			over = true
	return turned

## Takes the last disc back off and turns back what it turned.
func unmake() -> void:
	if history.is_empty():
		return
	var h: Array = history.pop_back()
	var side: int = h[2]
	cells[h[0]] = EMPTY
	for q: int in h[1]:
		cells[q] = 2 - side
	turn = side
	passed = h[3]
	last_side = h[4]
	ply -= 1
	over = false

## A position set by hand, for a tutorial page or a probe: `rows` is eight
## strings of eight, `x` the first side's disc, `o` the second's, anything
## else empty. The side to move passes at once if it has no square.
func lay(rows: Array, side := FIRST) -> void:
	cells.fill(EMPTY)
	for y in mini(rows.size(), W):
		var row: String = rows[y]
		for x in mini(row.length(), W):
			if row[x] == "x":
				cells[x + y * W] = FIRST + 1
			elif row[x] == "o":
				cells[x + y * W] = SECOND + 1
	history.clear()
	ply = 0
	last_side = -1
	passed = false
	over = false
	turn = side
	if not has_move(turn):
		passed = true
		if has_move(1 - turn):
			turn = 1 - turn
		else:
			over = true

func copy() -> RefCounted:
	var r: RefCounted = get_script().new()
	r.cells = cells.duplicate()
	r.turn = turn
	r.ply = ply
	r.passed = passed
	r.last_side = last_side
	r.over = over
	r.history = history.duplicate()
	return r
