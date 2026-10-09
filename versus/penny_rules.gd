extends RefCounted

## Penny Drop's rules, pure data: an upright rack seven slots wide and six
## high. Two sides take turns to drop one penny into a slot that has room; it
## falls to the lowest free place. Four of a side's pennies next to one
## another in a line -- across, up, or along either slant -- win at once. A
## rack filled with no such line is a draw.
##
## A cell is `col + row * W`, row 0 the bottom. A move is its column.

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
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

var cells := PackedByteArray()
var heights := PackedInt32Array()
var turn := FIRST
var ply := 0
## The columns played, in order.
var history := PackedInt32Array()
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
	return DRAW if ply == CELLS else PLAYING

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
	if not line.is_empty():
		winner = turn
	turn = 1 - turn
	return c

## Takes the last penny back out.
func unmake() -> void:
	if history.is_empty():
		return
	var col := history[history.size() - 1]
	history.remove_at(history.size() - 1)
	heights[col] -= 1
	cells[cell(col, heights[col])] = EMPTY
	ply -= 1
	turn = 1 - turn
	winner = -1
	line = PackedInt32Array()

func copy() -> RefCounted:
	var r: RefCounted = get_script().new()
	r.cells = cells.duplicate()
	r.heights = heights.duplicate()
	r.turn = turn
	r.ply = ply
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
