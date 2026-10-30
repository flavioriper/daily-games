extends RefCounted

## Penny Drop's rules, pure data: an upright rack seven slots wide and six
## high. Two sides take turns to drop one penny into a slot that has room; it
## falls to the lowest free place. Four of a side's pennies next to one
## another in a line -- across, up, or along either slant -- win at once. A
## rack filled with no such line is a draw.
##
## A cell is `col + row * W`, row 0 the bottom. A move is its column.
##
## Against the computer and across one phone each side also holds trick
## pennies for the rack, one use each (`tricks`, a mask of the kinds; empty
## online, where no rules version travels with a match and an old client plays
## the plain game):
##   HEAVY  dropped in any slot, even a full one, it crushes everything under
##          it, yours too, and lies on the bottom as a penny of yours
##   SPARK  no drop: one of the other side's pennies goes, and those above it
##          fall a place
##   TWIN   two drops in one turn
## Pennies that fall can make a line that nobody dropped: the side that played
## the trick wins on its own line first, and a line of only the other side's
## is an own goal. `crushed` and `fell` say what the last trick moved.

const W := 7
const H := 6
const CELLS := W * H
const NEED := 4
const EMPTY := 0
## The two sides; FIRST drops first. A cell holds the side plus one.
const FIRST := 0
const SECOND := 1
const PLAYING := 0
const WON := 1
const DRAW := 2
const HEAVY := 1
const SPARK := 2
const TWIN := 4
const ALL_TRICKS := HEAVY | SPARK | TWIN
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

var cells := PackedByteArray()
var heights := PackedInt32Array()
var turn := FIRST
var ply := 0
## Turns finished: a twin's two drops are one, as is a trick.
var turns := 0
## The columns played, in order; a trick is -1, and cannot be taken back.
var history := PackedInt32Array()
## Each side's tricks left this rack.
var tricks := [0, 0]
## A twin's drops still to make, by the side to move.
var drops := 0
## True from the twin being played to its second drop.
var twin_owed: bool:
	get:
		return drops > 0
## The ply a trick's turn ended on: nothing before it can be taken back.
var trick_ply := -99
## What the last trick took out, top first, each `cell + look * CELLS` being
## where it lay and whose it was (look 0 FIRST), and what fell: [from, to].
var crushed := PackedInt32Array()
var fell: Array[Vector2i] = []
## The side whose line ended the game, -1 while there is none.
var winner := -1
## Every cell of the winning line (more than four when a penny joins two
## runs, or completes two lines at once).
var line := PackedInt32Array()

func _init() -> void:
	cells.resize(CELLS)
	heights.resize(W)

static func cell(col: int, row: int) -> int:
	return col + row * W

func first_side() -> int:
	return FIRST

func at(col: int, row: int) -> int:
	return cells[col + row * W]

func can(col: int) -> bool:
	return winner < 0 and col >= 0 and col < W and heights[col] < H

## The columns with room, none once the game is over.
func legal_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in W:
		if can(c):
			out.append(c)
	return out

## Where a penny dropped into `col` comes to rest, -1 when the column is full.
func landing(col: int) -> int:
	return cell(col, heights[col]) if col >= 0 and col < W and heights[col] < H else -1

func status() -> int:
	if winner >= 0:
		return WON
	for c in W:
		if heights[c] < H:
			return PLAYING
	return DRAW

func has_trick(side: int, kind: int) -> bool:
	return tricks[side] & kind != 0

## Drops the side to move's penny into `col`. The cell it lands in, or -1 for
## a move that cannot be made.
func make(col: int) -> int:
	if not can(col):
		return -1
	var row := heights[col]
	var c := cell(col, row)
	cells[c] = turn + 1
	heights[col] = row + 1
	history.append(col)
	ply += 1
	line = _line_through(col, row)
	crushed = PackedInt32Array()
	fell.clear()
	if not line.is_empty():
		winner = turn
	elif drops > 0:
		drops -= 1
		if drops > 0 and status() == PLAYING:
			return c
	drops = 0
	_pass()
	return c

func _pass() -> void:
	turn = 1 - turn
	turns += 1

## Spends the side to move's twin: this drop and the next are both its own.
func twin() -> bool:
	if winner >= 0 or twin_owed or not has_trick(turn, TWIN) or status() != PLAYING:
		return false
	tricks[turn] &= ~TWIN
	drops = 2
	trick_ply = ply + 2
	return true

## The side to move's heavy penny goes down `col`, crushing what is in it. The
## cell it lands in, -1 for a move that cannot be made.
func heavy(col: int) -> int:
	if winner >= 0 or twin_owed or col < 0 or col >= W or not has_trick(turn, HEAVY):
		return -1
	tricks[turn] &= ~HEAVY
	crushed = PackedInt32Array()
	fell.clear()
	for r in range(heights[col] - 1, -1, -1):
		crushed.append(cell(col, r) + (cells[cell(col, r)] - 1) * CELLS)
		cells[cell(col, r)] = EMPTY
	cells[cell(col, 0)] = turn + 1
	heights[col] = 1
	_after_trick()
	return cell(col, 0)

## The side to move takes out the other's penny at `c`. False for a cell that
## holds no such penny.
func spark(c: int) -> bool:
	if winner >= 0 or twin_owed or c < 0 or c >= CELLS or not has_trick(turn, SPARK) or cells[c] != (1 - turn) + 1:
		return false
	tricks[turn] &= ~SPARK
	crushed = PackedInt32Array([c + (1 - turn) * CELLS])
	fell.clear()
	var col := c % W
	var row := c / W
	for r in range(row, heights[col] - 1):
		cells[cell(col, r)] = cells[cell(col, r + 1)]
		fell.append(Vector2i(cell(col, r + 1), cell(col, r)))
	heights[col] -= 1
	cells[cell(col, heights[col])] = EMPTY
	_after_trick()
	return true

## Pennies have moved with no drop to look at, so every line is looked for:
## the side that played the trick first, then the other.
func _after_trick() -> void:
	history.append(-1)
	ply += 1
	trick_ply = ply
	for side: int in [turn, 1 - turn]:
		line = _lines_of(side)
		if not line.is_empty():
			winner = side
			break
	_pass()

## Every cell in a run of four or more of `side`.
func _lines_of(side: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in CELLS:
		if cells[c] != side + 1:
			continue
		for x in _line_through(c % W, c / W):
			if not out.has(x):
				out.append(x)
	return out

## Takes the last penny back out. Never past a trick: see `trick_ply`.
func unmake() -> void:
	if history.is_empty():
		return
	var col := history[history.size() - 1]
	history.remove_at(history.size() - 1)
	heights[col] -= 1
	cells[cell(col, heights[col])] = EMPTY
	ply -= 1
	turn = 1 - turn
	turns -= 1
	winner = -1
	line = PackedInt32Array()

func copy() -> RefCounted:
	var r: RefCounted = get_script().new()
	r.cells = cells.duplicate()
	r.heights = heights.duplicate()
	r.turn = turn
	r.ply = ply
	r.turns = turns
	r.tricks = tricks.duplicate()
	r.drops = drops
	r.trick_ply = trick_ply
	r.history = history.duplicate()
	r.winner = winner
	r.line = line.duplicate()
	return r

## The cells of every run of four or more through the penny at (col, row).
func _line_through(col: int, row: int) -> PackedInt32Array:
	var who := cells[cell(col, row)]
	var out := PackedInt32Array()
	for d: Vector2i in DIRS:
		var run := PackedInt32Array([cell(col, row)])
		for way: int in [1, -1]:
			var x := col + d.x * way
			var y := row + d.y * way
			while x >= 0 and x < W and y >= 0 and y < H and cells[cell(x, y)] == who:
				run.append(cell(x, y))
				x += d.x * way
				y += d.y * way
		if run.size() >= NEED:
			for c in run:
				if not out.has(c):
					out.append(c)
	return out
