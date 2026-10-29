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
## (`moves_budget`, 0 since 2026-10-12), no Undo, and Hard's hints since
## 2026-10-13.

const Gen = preload("res://puzzles/lattice_gen.gd")

const BANK := "res://content/lattice.json"
const HINTS_BY := [3, 3, 2, 2]
## Insane's spare swaps over the deal's par.
const MOVES_SLACK := [0, 0, 0, 0]

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

# --- reading the lattice, as a player can (2026-10-29) ---

## Why a reading names its square: the line's last free square, a knot with
## its other tiles home, a square only one number fits, a number only one
## square of a line can take, or (none of those) a swap the answer makes.
enum { WHY_LAST, WHY_KNOT, WHY_ONLY, WHY_HIDDEN, WHY_PAIR }

## The numbers the square `i` could still take, from the rules alone: none
## already home in a whole line it stands in, one of the tiles still out,
## and what its knots leave. Never the answer.
func candidates(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if is_home(i):
		out.append(cur[i])
		return out
	var free := {}
	for j in cur.size():
		if not is_home(j):
			free[int(cur[j])] = true
	var used := {}
	for l: int in lines_of(i):
		for j: int in lines[l]:
			if is_home(j):
				used[int(cur[j])] = true
	for v in range(1, n + 1):
		if used.has(v) or not free.has(v):
			continue
		if _knot_allows(i, v):
			out.append(v)
	return out

## Whether `v` on `i` can meet every knot pointing at it, the knot's other
## tiles home at what they are and the rest anything from 1 to n.
func _knot_allows(i: int, v: int) -> bool:
	for k in knots:
		var cells_: PackedInt32Array = k.cells
		if not cells_.has(i):
			continue
		var lo := v
		var hi := v
		for j: int in cells_:
			if j == i:
				continue
			if is_home(j):
				lo += cur[j]
				hi += cur[j]
			else:
				lo += 1
				hi += n
		if int(k.sum) < lo or int(k.sum) > hi:
			return false
	return true

## The knot that alone fixes `i` (its other tiles all home), or -1.
func _fixing_knot(i: int) -> int:
	for k in knots.size():
		var cells_: PackedInt32Array = knots[k].cells
		if not cells_.has(i):
			continue
		var all_home := true
		for j: int in cells_:
			if j != i and not is_home(j):
				all_home = false
		if all_home:
			return k
	return -1

## The bulb's first press: a square the rules decide and why, and a tile to
## bring there. {cell, value, why, tile, line, knot}; {} on a finished board.
## `cell` is -1 on WHY_PAIR (no square decided): `tile` and `pair` are then
## the answer's swap that sends the most home.
func read() -> Dictionary:
	if is_solved():
		return {}
	var cands := {}
	for i in cur.size():
		if not is_home(i):
			cands[i] = candidates(i)
	# a line with one square left
	for l in lines.size():
		var out: Array = []
		for j: int in lines[l]:
			if not is_home(j):
				out.append(j)
		if out.size() == 1 and (cands[out[0]] as PackedInt32Array).size() == 1:
			return _reading(out[0], WHY_LAST, l, -1)
	# a knot with its other tiles home
	for i: int in cands:
		var k := _fixing_knot(i)
		if k >= 0 and (cands[i] as PackedInt32Array).size() == 1:
			return _reading(i, WHY_KNOT, -1, k)
	# a square one number fits
	for i: int in cands:
		if (cands[i] as PackedInt32Array).size() == 1:
			return _reading(i, WHY_ONLY, -1, -1)
	# a number one square of a line can take
	for l in lines.size():
		var have := {}
		for j: int in lines[l]:
			if is_home(j):
				have[int(cur[j])] = true
		for v in range(1, n + 1):
			if have.has(v):
				continue
			var only := -1
			var count := 0
			for j: int in lines[l]:
				if not is_home(j) and (cands[j] as PackedInt32Array).has(v):
					only = j
					count += 1
			if count == 1:
				return _reading(only, WHY_HIDDEN, l, -1, v)
	var pair := hint()
	if pair.is_empty():
		return {}
	return {"cell": -1, "value": int(sol[pair[0]]), "why": WHY_PAIR, "tile": pair[1], "pair": pair,
		"line": -1, "knot": -1}

## A reading of square `i` (its number is the answer's: the rules decided
## it), and the tile to bring: one whose own square wants what `i` holds now
## when there is one, so both go home.
func _reading(i: int, why: int, line: int, knot: int, v := -1) -> Dictionary:
	if v < 0:
		v = int(sol[i])
	var tile := -1
	for j in cur.size():
		if j == i or is_home(j) or cur[j] != v:
			continue
		if sol[j] == cur[i]:
			tile = j
			break
		if tile < 0:
			tile = j
	return {"cell": i, "value": v, "why": why, "tile": tile, "pair": [tile, i], "line": line, "knot": knot}

## The fewest swaps the deal could still be done in, at the least: a swap
## sends two tiles home at the most.
func swaps_floor() -> int:
	return swaps + int(ceil((count() - homes()) / 2.0))
