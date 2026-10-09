extends RefCounted

## Lattice's rules as the board plays them, scene-free, as every flat board's
## are. The board (puzzles/lattice2d.gd) draws this and nothing else.
##
## A lattice of number tiles: every other row and every other column is
## whole, and where two short lines would cross there is a hole. Each whole
## row and column of the answer holds 1 to n once. The tiles are all on the
## board, scrambled, and the one move is to swap two of them. A tile whose
## number is its cell's own is home: it says so, and it no longer moves. A
## knot in a hole points at one, two or more of the tiles beside it and
## carries what the answer's tiles there add up to.
##
## No band has hearts. Easy to Hard count the swaps and never run out;
## Insane has the fewest swaps the deal can be done in and five more
## (`moves_budget`), and no Undo and no hint.

const Gen = preload("res://puzzles/lattice_gen.gd")

const BANK := "res://content/lattice.json"
const HINTS_BY := [3, 3, 2, 0]
## Insane's spare swaps over the deal's par.
const MOVES_SLACK := [0, 0, 0, 5]

## What a swap came to.
enum { OK, REFUSED_HOME, REFUSED_SAME, REFUSED_SELF }

static var _bank: Array = []
static var _bank_read := false

var band := 0
var n := 0
var par := 0
## The lattice's cells as (column, row), and the way back: a slot a square of
## the n by n grid, -1 on a hole.
var cells: Array[Vector2i] = []
var grid := PackedInt32Array()
var sol := PackedByteArray()
var cur := PackedByteArray()
var start := PackedByteArray()
## [{at: Vector2i, dirs: String, cells: PackedInt32Array, sum: int}]
var knots: Array = []
## The whole rows, then the whole columns, each its cells in order.
var lines: Array = []
## Every swap, for Undo: [a, b].
var history: Array = []
var swaps := 0

## The band's pool of mined deals, [] when the bank is missing.
static func pool(band_: int) -> Array:
	if not _bank_read:
		_bank_read = true
		if FileAccess.file_exists(BANK):
			var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK))
			if doc is Dictionary and doc.get("bands") is Array:
				_bank = doc.bands
	return _bank[band_] if band_ < _bank.size() else []

static func hints_for(band_: int) -> int:
	return HINTS_BY[clampi(band_, 0, HINTS_BY.size() - 1)]

## The day's deal out of the bank; without one the phone deals its own.
func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	band = clampi(difficulty, 0, Gen.BANDS.size() - 1)
	var deal := {}
	var deals := pool(band)
	if not deals.is_empty():
		deal = Gen.unpack(deals[rng.randi_range(0, deals.size() - 1)])
	if deal.is_empty():
		deal = Gen.generate(rng, band)
	adopt(deal)

## Plays `deal` ({n, sol, cur, knots, par}) on this state's band.
func adopt(deal: Dictionary) -> void:
	n = int(deal.n)
	par = int(deal.par)
	cells = Gen.cells_of(n)
	grid = PackedInt32Array()
	grid.resize(n * n)
	grid.fill(-1)
	for i in cells.size():
		grid[cells[i].y * n + cells[i].x] = i
	sol = (deal.sol as PackedByteArray).duplicate()
	start = (deal.cur as PackedByteArray).duplicate()
	cur = start.duplicate()
	var holes := Gen.holes_of(n)
	knots = []
	for k: Dictionary in deal.knots:
		var at: Vector2i = holes[int(k.hole)]
		var pointed := PackedInt32Array()
		var total := 0
		for d in String(k.dirs):
			var i := at_xy(at + (Gen.STEP[d] as Vector2i))
			pointed.append(i)
			total += sol[i]
		knots.append({"at": at, "dirs": String(k.dirs), "cells": pointed, "sum": total})
	lines = []
	for across in [true, false]:
		for a in range(0, n, 2):
			var line := PackedInt32Array()
			for b in n:
				line.append(at_xy(Vector2i(b, a) if across else Vector2i(a, b)))
			lines.append(line)
	history = []
	swaps = 0

func count() -> int:
	return cells.size()

func xy(i: int) -> Vector2i:
	return cells[i]

## The cell on square `c`, -1 off the lattice or on a hole.
func at_xy(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= n or c.y >= n:
		return -1
	return grid[c.y * n + c.x]

func is_home(i: int) -> bool:
	return cur[i] == sol[i]

func homes() -> int:
	var out := 0
	for i in cur.size():
		if cur[i] == sol[i]:
			out += 1
	return out

## Whether every tile a knot points at is home.
func knot_done(k: int) -> bool:
	for i: int in knots[k].cells:
		if not is_home(i):
			return false
	return true

## What the tiles a knot points at add up to now.
func knot_now(k: int) -> int:
	var out := 0
	for i: int in knots[k].cells:
		out += cur[i]
	return out

func line_done(l: int) -> bool:
	for i: int in lines[l]:
		if not is_home(i):
			return false
	return true

## The lines `i` stands in: one for a cell between two crossings, two for a
## crossing.
func lines_of(i: int) -> Array:
	var out: Array = []
	for l in lines.size():
		if (lines[l] as PackedInt32Array).has(i):
			out.append(l)
	return out

## Insane's swaps: the deal's par and the slack. 0 on a band that never runs
## out.
func moves_budget() -> int:
	var slack: int = MOVES_SLACK[clampi(band, 0, MOVES_SLACK.size() - 1)]
	return par + slack if slack > 0 else 0

## Whether `a` and `b` may trade. A tile at home stays; two of one number
## would change nothing.
func judge(a: int, b: int) -> int:
	if a == b or a < 0 or b < 0:
		return REFUSED_SELF
	if is_home(a) or is_home(b):
		return REFUSED_HOME
	if cur[a] == cur[b]:
		return REFUSED_SAME
	return OK

## Swaps the tiles on `a` and `b`.
func swap(a: int, b: int) -> int:
	var why := judge(a, b)
	if why != OK:
		return why
	_trade(a, b)
	history.append([a, b])
	swaps += 1
	return OK

func _trade(a: int, b: int) -> void:
	var t := cur[a]
	cur[a] = cur[b]
	cur[b] = t

## Takes the last swap back. The pair, or [] with nothing to take back.
func undo() -> Array:
	if history.is_empty():
		return []
	var last: Array = history.pop_back()
	_trade(last[0], last[1])
	swaps -= 1
	return last

## The deal as it was dealt.
func reset() -> void:
	cur = start.duplicate()
	history = []
	swaps = 0

## A swap that sends a tile home, [a, b]: one that sends both when there is
## one, the earliest in reading order otherwise. [] on a finished board.
func hint() -> Array:
	var single: Array = []
	for a in cur.size():
		if is_home(a):
			continue
		for b in cur.size():
			if b == a or is_home(b) or cur[b] != sol[a]:
				continue
			if cur[a] == sol[b]:
				return [a, b]
			if single.is_empty():
				single = [a, b]
	return single

func is_solved() -> bool:
	return cur == sol

## Every tile home, for a finished daily reopened.
func finish(used := -1) -> void:
	cur = sol.duplicate()
	history = []
	if used >= 0:
		swaps = used

## The lattice as it was dealt: a leaf for a tile that began at home, a
## blank for one that did not, the holes left open.
func share_glyphs() -> String:
	var out := ""
	for r in n:
		for c in n:
			var i := at_xy(Vector2i(c, r))
			out += "▫️" if i < 0 else ("🟩" if start[i] == sol[i] else "⬜")
		out += "\n"
	return out.strip_edges()
