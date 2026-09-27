extends RefCounted

## Posy as pure data (spec docs/superpowers/specs/2026-09-27-arcade-posy-design.md):
## a garden bed eight by eight of flowers, leaves, drops, mushrooms, berries
## (and acorns from day five). Swap two neighbours to line up three or more
## of a kind and they are picked; four in a line leave a breeze that sweeps
## a row or a column, an L or a T a seed bomb that goes off twice, five in a
## line a rainbow posy that picks every one of a kind. Each day asks for so
## many of three kinds in so many moves; the moves left over when the day is
## done burst as breezes for points, and the next day is dealt. Out of moves
## short of the day's goals, the game is over.
##
## The screen (arcade/posy_screen.gd) calls `swap()` and `use()` and drains
## `events`; a move resolves at once, every cascade step an event of its
## own, and the screen plays them in order.

enum Phase { PLAY, OVER }
## A tile's special: a breeze across its row or down its column, a seed bomb,
## a rainbow posy (which has no kind).
enum Sp { NONE, ROW, COL, BOMB, RAINBOW }
enum Tool { TROWEL, SWAP, BOMB, RAINBOW }

const COLS := 8
const ROWS := 8
const KIND_NAMES := ["flower", "leaf", "drop", "mushroom", "berry", "acorn"]
const TOOL_KEYS := {Tool.TROWEL: "trowel", Tool.SWAP: "swap", Tool.BOMB: "bomb", Tool.RAINBOW: "rainbow"}
## Tools that need a tile (Swap two) picked after they are pressed: all four.
const START_TOOLS := 3
## Points a tile picked is worth, times the cascade step it fell in.
const TILE_POINTS := 20
const MADE_POINTS := {Sp.ROW: 60, Sp.COL: 60, Sp.BOMB: 120, Sp.RAINBOW: 200}
## Points for each move left over when a day is done, before its breeze.
const MOVE_BONUS := 250
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var rng := RandomNumberGenerator.new()
var phase := Phase.PLAY
## grid[c][r], r 0 the top row: {id, k, sp, lit} or {} while empty. A rainbow
## posy's kind is -1; `lit` is a seed bomb that has gone off once.
var grid: Array = []
var day := 1
var kinds := 5
var moves_left := 0
## The day's goals: [{k, need, got}].
var goals: Array = []
var score := 0
var moves := 0
var tools := {}
var tools_used := 0
var made := 0
var best_cascade := 0
var picked := 0
var events: Array = []
var _ids := 0

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for c in COLS:
		var col: Array = []
		for r in ROWS:
			col.append({})
		grid.append(col)
	for t: int in TOOL_KEYS:
		tools[t] = START_TOOLS
	_start_day()

func is_over() -> bool:
	return phase == Phase.OVER

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS

func at(p: Vector2i) -> Dictionary:
	if not inside(p):
		return {}
	return grid[p.x][p.y]

## A tile's kind, -1 for a rainbow posy, -2 for nothing.
func kind(p: Vector2i) -> int:
	var t := at(p)
	return int(t.k) if not t.is_empty() else -2

func special(p: Vector2i) -> int:
	var t := at(p)
	return int(t.sp) if not t.is_empty() else Sp.NONE

static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

func _new_tile(k: int, sp := Sp.NONE) -> Dictionary:
	_ids += 1
	return {"id": _ids, "k": k, "sp": sp, "lit": false}

# --- days ---

## How a day is set: kinds in the bed, goals and moves. Day one asks for two
## kinds, every day after for three; the counts climb and the moves do not,
## and a sixth kind comes into the bed on day five.
static func day_plan(d: int) -> Dictionary:
	var n := 2 if d == 1 else 3
	var need := mini(12 + 4 * (d - 1), 60)
	var mv := 20 if d < 5 else 24
	return {"kinds": 5 if d < 5 else 6, "goals": n, "need": need, "moves": mv}

func _start_day() -> void:
	var plan := day_plan(day)
	kinds = plan.kinds
	moves_left = plan.moves
	goals.clear()
	var pool: Array = range(kinds)
	_shuffle(pool)
	for i in int(plan.goals):
		goals.append({"k": pool[i], "need": plan.need, "got": 0})
	_deal()
	events.append({"type": "deal", "day": day, "tiles": _all_tiles(), "moves": moves_left, "goals": goals.duplicate(true)})

## A fresh bed: no three in a line anywhere, and at least one move in it.
func _deal() -> void:
	for attempt in 100:
		for c in COLS:
			for r in ROWS:
				var banned := {}
				if c >= 2 and kind(Vector2i(c - 1, r)) == kind(Vector2i(c - 2, r)):
					banned[kind(Vector2i(c - 1, r))] = true
				if r >= 2 and kind(Vector2i(c, r - 1)) == kind(Vector2i(c, r - 2)):
					banned[kind(Vector2i(c, r - 1))] = true
				var k := rng.randi_range(0, kinds - 1)
				while banned.has(k):
					k = rng.randi_range(0, kinds - 1)
				grid[c][r] = _new_tile(k)
		if has_move():
			return

func _all_tiles() -> Array:
	var out: Array = []
	for c in COLS:
		for r in ROWS:
			var t: Dictionary = grid[c][r]
			if not t.is_empty():
				out.append({"id": t.id, "cell": Vector2i(c, r), "k": t.k, "sp": t.sp})
	return out

func goals_met() -> bool:
	for g: Dictionary in goals:
		if int(g.got) < int(g.need):
			return false
	return true

# --- a move ---

## Swap two neighbours. A swap that lines nothing up is refused and swapped
## back (and costs nothing); two specials, or a rainbow posy with anything,
## always go. True when the move was taken.
func swap(a: Vector2i, b: Vector2i) -> bool:
	if phase != Phase.PLAY or not adjacent(a, b) or at(a).is_empty() or at(b).is_empty():
		return false
	var ta: Dictionary = at(a)
	var tb: Dictionary = at(b)
	var combo: bool = int(ta.sp) == Sp.RAINBOW or int(tb.sp) == Sp.RAINBOW or (int(ta.sp) != Sp.NONE and int(tb.sp) != Sp.NONE)
	grid[a.x][a.y] = tb
	grid[b.x][b.y] = ta
	if not combo and not _run_through(a) and not _run_through(b):
		grid[a.x][a.y] = ta
		grid[b.x][b.y] = tb
		events.append({"type": "swap", "a": a, "b": b, "ida": ta.id, "idb": tb.id, "ok": false})
		return false
	events.append({"type": "swap", "a": a, "b": b, "ida": ta.id, "idb": tb.id, "ok": true})
	moves_left -= 1
	moves += 1
	if combo:
		_combo(b, a)
		_fall()
	_cascade([b, a])
	_after_move()
	return true

## The two tiles swapped are specials, or one a rainbow posy: they go off
## together, where the dragged one landed (`p`; `q` is where it came from).
func _combo(p: Vector2i, q: Vector2i) -> void:
	var tp: Dictionary = at(p)
	var tq: Dictionary = at(q)
	var sp := int(tp.sp)
	var sq := int(tq.sp)
	var clear := {p: true, q: true}
	var fired := {p: true, q: true}
	var blasts: Array = []
	if sp == Sp.RAINBOW and sq == Sp.RAINBOW:
		# two rainbows pick the whole bed
		for c in COLS:
			for r in ROWS:
				clear[Vector2i(c, r)] = true
		blasts.append({"kind": "all", "cell": p})
	elif sp == Sp.RAINBOW or sq == Sp.RAINBOW:
		var bow := p if sp == Sp.RAINBOW else q
		var other := q if bow == p else p
		var to: Dictionary = at(other)
		var k := int(to.k)
		var osp := int(to.sp)
		var cells: Array = []
		var turned: Array = []
		for c in COLS:
			for r in ROWS:
				var cell := Vector2i(c, r)
				var t := at(cell)
				if t.is_empty() or int(t.k) != k:
					continue
				cells.append(cell)
				# a rainbow and a breeze or a bomb turns every one of the kind
				# into one, and they all go off
				if osp != Sp.NONE and int(t.sp) == Sp.NONE:
					t.sp = rng.randi_range(Sp.ROW, Sp.COL) if osp != Sp.BOMB else Sp.BOMB
					turned.append({"id": t.id, "cell": cell, "k": t.k, "sp": t.sp})
		if not turned.is_empty():
			events.append({"type": "convert", "tiles": turned})
		fired.erase(other)
		for cell: Vector2i in cells:
			clear[cell] = true
		blasts.append({"kind": "rainbow", "cell": bow, "k": k, "cells": cells})
	else:
		var lines := [Sp.ROW, Sp.COL]
		if sp in lines and sq in lines:
			blasts.append({"kind": "row", "cell": p})
			blasts.append({"kind": "col", "cell": p})
			_add_row(clear, p.y)
			_add_col(clear, p.x)
		elif sp == Sp.BOMB and sq == Sp.BOMB:
			blasts.append({"kind": "bomb", "cell": p, "r": 2})
			_add_square(clear, p, 2)
		else:
			# a breeze and a bomb: three rows and three columns
			for d in [-1, 0, 1]:
				if p.y + d >= 0 and p.y + d < ROWS:
					blasts.append({"kind": "row", "cell": Vector2i(p.x, p.y + d), "wide": true})
					_add_row(clear, p.y + d)
				if p.x + d >= 0 and p.x + d < COLS:
					blasts.append({"kind": "col", "cell": Vector2i(p.x + d, p.y), "wide": true})
					_add_col(clear, p.x + d)
	_resolve(clear, fired, blasts, [], 1)

## Match, pick, fall and refill until the bed is still. `focus` is where the
## player moved: a special made by the move is left there.
func _cascade(focus: Array) -> void:
	var step := 1
	while true:
		var groups := _groups()
		var lit: Array = []
		for c in COLS:
			for r in ROWS:
				var t: Dictionary = grid[c][r]
				if not t.is_empty() and bool(t.lit):
					lit.append(Vector2i(c, r))
		if groups.is_empty() and lit.is_empty():
			break
		var clear := {}
		var new_sp: Array = []
		var made_at := {}
		for g: Dictionary in groups:
			for p: Vector2i in g.cells:
				clear[p] = true
			if int(g.sp) == Sp.NONE:
				continue
			var spot := _spot(g, focus, made_at)
			if spot.x >= 0:
				made_at[spot] = true
				new_sp.append({"cell": spot, "k": g.k, "sp": g.sp, "from": g.cells})
		for p: Vector2i in lit:
			clear[p] = true
		_resolve(clear, {}, [], new_sp, step, groups)
		best_cascade = maxi(best_cascade, step)
		step += 1
		_fall()
		focus = []
	if phase == Phase.PLAY and not has_move():
		_reshuffle()

## Where a special made by a group is left: the cell the player moved into
## if it is in the group, else where its lines cross, else its middle --
## never on a tile that is already special.
func _spot(g: Dictionary, focus: Array, taken: Dictionary) -> Vector2i:
	var order: Array = []
	for f: Vector2i in focus:
		if (g.cells as Array).has(f):
			order.append(f)
	if g.has("cross"):
		order.append(g.cross)
	order.append(g.mid)
	order.append_array(g.cells)
	for p: Vector2i in order:
		if not taken.has(p) and special(p) == Sp.NONE:
			return p
	return Vector2i(-1, -1)

## One step: every cell in `clear` is picked, and every special among them
## goes off, adding its own cells, until nothing new is caught. New specials
## are left in `new_sp`'s cells; a seed bomb going off the first time stays,
## lit, to go off again after the fall.
func _resolve(clear: Dictionary, fired: Dictionary, blasts: Array, new_sp: Array, step: int, groups: Array = []) -> void:
	for m: Dictionary in new_sp:
		clear.erase(m.cell)
	var queue: Array = clear.keys()
	var stay := {}
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		var t := at(p)
		if t.is_empty() or fired.has(p) or int(t.sp) == Sp.NONE:
			continue
		fired[p] = true
		var hit := {}
		match int(t.sp):
			Sp.ROW:
				_add_row(hit, p.y)
				blasts.append({"kind": "row", "cell": p})
			Sp.COL:
				_add_col(hit, p.x)
				blasts.append({"kind": "col", "cell": p})
			Sp.BOMB:
				_add_square(hit, p, 1)
				blasts.append({"kind": "bomb", "cell": p, "r": 1, "second": bool(t.lit)})
				if not bool(t.lit):
					stay[p] = true
			Sp.RAINBOW:
				# caught by a blast, a rainbow picks the commonest kind
				var k := _commonest()
				var cells: Array = []
				for c in COLS:
					for r in ROWS:
						if kind(Vector2i(c, r)) == k:
							cells.append(Vector2i(c, r))
							hit[Vector2i(c, r)] = true
				blasts.append({"kind": "rainbow", "cell": p, "k": k, "cells": cells})
		for h: Vector2i in hit:
			if not clear.has(h) and not _is_new(new_sp, h):
				clear[h] = true
				queue.append(h)
	for p: Vector2i in stay:
		clear.erase(p)
		(at(p) as Dictionary).lit = true
	var gone: Array = []
	var points := 0
	for p: Vector2i in clear:
		var t := at(p)
		if t.is_empty():
			continue
		gone.append({"id": t.id, "cell": p, "k": t.k, "sp": t.sp})
		grid[p.x][p.y] = {}
		points += TILE_POINTS * step
		picked += 1
		for g: Dictionary in goals:
			if int(g.k) == int(t.k) and int(g.got) < int(g.need):
				g.got = int(g.got) + 1
				if int(g.got) == int(g.need):
					events.append({"type": "goal_done", "k": g.k})
	var born: Array = []
	for m: Dictionary in new_sp:
		var t := at(m.cell)
		if t.is_empty():
			continue
		t.sp = m.sp
		if int(m.sp) == Sp.RAINBOW:
			t.k = -1
		made += 1
		points += int(MADE_POINTS[int(m.sp)])
		born.append({"id": t.id, "cell": m.cell, "k": t.k, "sp": t.sp, "from": m.from})
	var lit_ids: Array = []
	for p: Vector2i in stay:
		lit_ids.append(at(p).id)
	score += points
	var shapes: Array = []
	for g: Dictionary in groups:
		shapes.append(g.cells)
	events.append({"type": "clear", "tiles": gone, "made": born, "blasts": blasts, "lit": lit_ids,
		"step": step, "points": points, "groups": shapes, "goals": goals.duplicate(true)})

func _is_new(new_sp: Array, p: Vector2i) -> bool:
	for m: Dictionary in new_sp:
		if m.cell == p:
			return true
	return false

func _add_row(into: Dictionary, r: int) -> void:
	for c in COLS:
		into[Vector2i(c, r)] = true

func _add_col(into: Dictionary, c: int) -> void:
	for r in ROWS:
		into[Vector2i(c, r)] = true

func _add_square(into: Dictionary, p: Vector2i, rad: int) -> void:
	for dc in range(-rad, rad + 1):
		for dr in range(-rad, rad + 1):
			var q := p + Vector2i(dc, dr)
			if inside(q):
				into[q] = true

func _commonest() -> int:
	var count := {}
	for c in COLS:
		for r in ROWS:
			var k := kind(Vector2i(c, r))
			if k >= 0:
				count[k] = int(count.get(k, 0)) + 1
	var best := 0
	var n := -1
	for k: int in count:
		if int(count[k]) > n:
			n = count[k]
			best = k
	return best

## Everything above a gap falls into it, and new tiles drop in over the top.
func _fall() -> void:
	var falls: Array = []
	var fresh: Array = []
	for c in COLS:
		var col: Array = grid[c]
		var stack: Array = []
		for r in range(ROWS - 1, -1, -1):
			if not (col[r] as Dictionary).is_empty():
				stack.append({"t": col[r], "from": r})
		var r := ROWS - 1
		for s: Dictionary in stack:
			col[r] = s.t
			if int(s.from) != r:
				falls.append({"id": s.t.id, "col": c, "from": s.from, "to": r})
			r -= 1
		var above := 0
		while r >= 0:
			above += 1
			var t := _new_tile(rng.randi_range(0, kinds - 1))
			col[r] = t
			fresh.append({"id": t.id, "col": c, "row": r, "k": t.k, "sp": t.sp, "from": -above})
			r -= 1
	if not falls.is_empty() or not fresh.is_empty():
		events.append({"type": "fall", "falls": falls, "fresh": fresh})

## Every group of three or more in a line, runs that share a tile joined:
## {cells, k, sp (what it makes), mid, cross?}.
func _groups() -> Array:
	var runs: Array = []
	for r in ROWS:
		var c := 0
		while c < COLS:
			var k := kind(Vector2i(c, r))
			var e := c + 1
			while e < COLS and k >= 0 and kind(Vector2i(e, r)) == k:
				e += 1
			if k >= 0 and e - c >= 3:
				var cells: Array = []
				for x in range(c, e):
					cells.append(Vector2i(x, r))
				runs.append({"cells": cells, "k": k, "h": true})
			c = e
	for c in COLS:
		var r := 0
		while r < ROWS:
			var k := kind(Vector2i(c, r))
			var e := r + 1
			while e < ROWS and k >= 0 and kind(Vector2i(c, e)) == k:
				e += 1
			if k >= 0 and e - r >= 3:
				var cells: Array = []
				for y in range(r, e):
					cells.append(Vector2i(c, y))
				runs.append({"cells": cells, "k": k, "h": false})
			r = e
	# join runs that share a tile
	var owner := {}
	var groups: Array = []
	for run: Dictionary in runs:
		var into := -1
		for p: Vector2i in run.cells:
			if owner.has(p):
				into = owner[p]
				break
		if into < 0:
			groups.append({"runs": [run]})
			into = groups.size() - 1
		else:
			groups[into].runs.append(run)
		for p: Vector2i in run.cells:
			owner[p] = into
	var out: Array = []
	for g: Dictionary in groups:
		var cells := {}
		var longest: Dictionary = g.runs[0]
		var has_h := false
		var has_v := false
		for run: Dictionary in g.runs:
			for p: Vector2i in run.cells:
				cells[p] = true
			if run.cells.size() > longest.cells.size():
				longest = run
			if run.h:
				has_h = true
			else:
				has_v = true
		var sp := Sp.NONE
		var n: int = longest.cells.size()
		if n >= 5:
			sp = Sp.RAINBOW
		elif has_h and has_v:
			sp = Sp.BOMB
		elif n == 4:
			# four across leave a breeze down the column, four down one
			# across the row
			sp = Sp.COL if longest.h else Sp.ROW
		var grp := {"cells": cells.keys(), "k": longest.k, "sp": sp, "mid": longest.cells[(n - 1) / 2]}
		if has_h and has_v:
			for run: Dictionary in g.runs:
				for p: Vector2i in run.cells:
					var hv := 0
					for other: Dictionary in g.runs:
						if (other.cells as Array).has(p):
							hv += 1
					if hv >= 2:
						grp.cross = p
		out.append(grp)
	return out

## Whether a line of three or more runs through `p`.
func _run_through(p: Vector2i) -> bool:
	var k := kind(p)
	if k < 0:
		return false
	var n := 1
	var x := p.x - 1
	while x >= 0 and kind(Vector2i(x, p.y)) == k:
		n += 1
		x -= 1
	x = p.x + 1
	while x < COLS and kind(Vector2i(x, p.y)) == k:
		n += 1
		x += 1
	if n >= 3:
		return true
	n = 1
	var y := p.y - 1
	while y >= 0 and kind(Vector2i(p.x, y)) == k:
		n += 1
		y -= 1
	y = p.y + 1
	while y < ROWS and kind(Vector2i(p.x, y)) == k:
		n += 1
		y += 1
	return n >= 3

## Every swap that would be taken: [[a, b], ...].
func all_moves() -> Array:
	var out: Array = []
	for c in COLS:
		for r in ROWS:
			var a := Vector2i(c, r)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b := a + d
				if inside(b) and _would_take(a, b):
					out.append([a, b])
	return out

func has_move() -> bool:
	for c in COLS:
		for r in ROWS:
			var a := Vector2i(c, r)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b := a + d
				if inside(b) and _would_take(a, b):
					return true
	return false

func _would_take(a: Vector2i, b: Vector2i) -> bool:
	var ta := at(a)
	var tb := at(b)
	if ta.is_empty() or tb.is_empty():
		return false
	if int(ta.sp) == Sp.RAINBOW or int(tb.sp) == Sp.RAINBOW or (int(ta.sp) != Sp.NONE and int(tb.sp) != Sp.NONE):
		return true
	if int(ta.k) == int(tb.k):
		return false
	grid[a.x][a.y] = tb
	grid[b.x][b.y] = ta
	var ok := _run_through(a) or _run_through(b)
	grid[a.x][a.y] = ta
	grid[b.x][b.y] = tb
	return ok

## A move worth showing a player who has sat still: a special pair first,
## then the swap that lines up the most.
func hint() -> Array:
	var best: Array = []
	var best_n := -1
	for m: Array in all_moves():
		var a: Vector2i = m[0]
		var b: Vector2i = m[1]
		var n := 0
		if (special(a) != Sp.NONE and special(b) != Sp.NONE) or special(a) == Sp.RAINBOW or special(b) == Sp.RAINBOW:
			n = 20
		else:
			var ta := at(a)
			var tb := at(b)
			grid[a.x][a.y] = tb
			grid[b.x][b.y] = ta
			n = _line_len(a) + _line_len(b)
			grid[a.x][a.y] = ta
			grid[b.x][b.y] = tb
		if n > best_n:
			best_n = n
			best = [a, b]
	return best

func _line_len(p: Vector2i) -> int:
	var k := kind(p)
	if k < 0:
		return 0
	var h := 1
	var x := p.x - 1
	while x >= 0 and kind(Vector2i(x, p.y)) == k:
		h += 1
		x -= 1
	x = p.x + 1
	while x < COLS and kind(Vector2i(x, p.y)) == k:
		h += 1
		x += 1
	var v := 1
	var y := p.y - 1
	while y >= 0 and kind(Vector2i(p.x, y)) == k:
		v += 1
		y -= 1
	y = p.y + 1
	while y < ROWS and kind(Vector2i(p.x, y)) == k:
		v += 1
		y += 1
	return (h if h >= 3 else 0) + (v if v >= 3 else 0)

## A bed with no move left is shaken up where it lies until it has one and
## nothing lines up by itself.
func _reshuffle() -> void:
	var tiles: Array = []
	for c in COLS:
		for r in ROWS:
			tiles.append(grid[c][r])
	for attempt in 200:
		_shuffle(tiles)
		var i := 0
		for c in COLS:
			for r in ROWS:
				grid[c][r] = tiles[i]
				i += 1
		if _groups().is_empty() and has_move():
			break
	var to: Array = []
	for c in COLS:
		for r in ROWS:
			to.append({"id": grid[c][r].id, "cell": Vector2i(c, r)})
	events.append({"type": "shuffle", "tiles": to})

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## After every move and tool: a day whose goals are met blooms and the next is
## dealt; a day out of moves short of them ends the game.
func _after_move() -> void:
	if phase != Phase.PLAY:
		return
	if goals_met():
		_bloom()
		return
	if moves_left <= 0:
		phase = Phase.OVER
		events.append({"type": "over", "day": day})

## The day is done: every move left over earns its bonus and turns a tile
## into a breeze, and they all go off; then the next day is dealt, with a
## tool as a gift.
func _bloom() -> void:
	var left := moves_left
	var bonus := left * MOVE_BONUS
	score += bonus
	events.append({"type": "day_done", "day": day, "left": left, "bonus": bonus})
	var cells: Array = []
	for c in COLS:
		for r in ROWS:
			var t: Dictionary = grid[c][r]
			if not t.is_empty() and int(t.sp) == Sp.NONE:
				cells.append(Vector2i(c, r))
	_shuffle(cells)
	var turned: Array = []
	var clear := {}
	for i in mini(left, cells.size()):
		var p: Vector2i = cells[i]
		var t := at(p)
		t.sp = rng.randi_range(Sp.ROW, Sp.COL)
		turned.append({"id": t.id, "cell": p, "k": t.k, "sp": t.sp})
		clear[p] = true
	moves_left = 0
	# the specials still standing go off too
	for c in COLS:
		for r in ROWS:
			if special(Vector2i(c, r)) != Sp.NONE:
				clear[Vector2i(c, r)] = true
	if not turned.is_empty():
		events.append({"type": "convert", "tiles": turned, "bloom": true})
	if not clear.is_empty():
		_resolve(clear, {}, [], [], 1)
		_fall()
		# whatever the fall lines up is picked too, but leaves no specials
		var guard := 0
		while guard < 20:
			guard += 1
			var groups := _groups()
			var lit := {}
			for c in COLS:
				for r in ROWS:
					var t: Dictionary = grid[c][r]
					if not t.is_empty() and (bool(t.lit) or int(t.sp) != Sp.NONE):
						lit[Vector2i(c, r)] = true
			if groups.is_empty() and lit.is_empty():
				break
			for g: Dictionary in groups:
				for p: Vector2i in g.cells:
					lit[p] = true
			_resolve(lit, {}, [], [], guard + 1, groups)
			_fall()
	var gift: int = [Tool.TROWEL, Tool.SWAP, Tool.BOMB, Tool.RAINBOW][(day - 1) % 4]
	tools[gift] = int(tools[gift]) + 1
	day += 1
	events.append({"type": "gift", "tool": TOOL_KEYS[gift]})
	_start_day()

# --- tools ---

func can_use(tool: int) -> bool:
	return phase == Phase.PLAY and int(tools.get(tool, 0)) > 0

## Whether `tool` may be used on `a` (and `b`, for a swap).
func can_target(tool: int, a: Vector2i, b := Vector2i(-1, -1)) -> bool:
	if not can_use(tool) or at(a).is_empty():
		return false
	match tool:
		Tool.SWAP:
			return adjacent(a, b) and not at(b).is_empty()
		Tool.RAINBOW:
			return special(a) != Sp.RAINBOW
	return true

## Use a tool, free of a move: the trowel digs one tile up, the swap trades
## two neighbours whether or not they line up, the bomb picks a three by
## three, the rainbow seed turns a tile into a rainbow posy.
func use(tool: int, a: Vector2i, b := Vector2i(-1, -1)) -> bool:
	if not can_target(tool, a, b):
		events.append({"type": "refused", "tool": TOOL_KEYS.get(tool, "")})
		return false
	tools[tool] = int(tools[tool]) - 1
	tools_used += 1
	events.append({"type": "tool", "tool": TOOL_KEYS[tool], "cell": a, "b": b})
	match tool:
		Tool.TROWEL:
			_resolve({a: true}, {}, [{"kind": "dig", "cell": a}], [], 1)
			_fall()
			_cascade([])
		Tool.BOMB:
			var clear := {}
			_add_square(clear, a, 1)
			_resolve(clear, {}, [{"kind": "bomb", "cell": a, "r": 1, "tool": true}], [], 1)
			_fall()
			_cascade([])
		Tool.SWAP:
			var ta: Dictionary = at(a)
			var tb: Dictionary = at(b)
			grid[a.x][a.y] = tb
			grid[b.x][b.y] = ta
			events.append({"type": "swap", "a": a, "b": b, "ida": ta.id, "idb": tb.id, "ok": true, "free": true})
			_cascade([b, a])
		Tool.RAINBOW:
			var t := at(a)
			t.sp = Sp.RAINBOW
			t.k = -1
			t.lit = false
			events.append({"type": "convert", "tiles": [{"id": t.id, "cell": a, "k": -1, "sp": Sp.RAINBOW}]})
	_after_move()
	return true

## Give up the day (the end card's way out of a game left running).
func give_up() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	events.append({"type": "over", "day": day})

## A copy to try a move on (the probe's bot).
func clone() -> RefCounted:
	var s = get_script().new(0)
	s.events.clear()
	s.rng.state = rng.state
	s.phase = phase
	s.day = day
	s.kinds = kinds
	s.moves_left = moves_left
	s.goals = goals.duplicate(true)
	s.score = score
	s.tools = tools.duplicate()
	s._ids = _ids
	s.grid = []
	for c in COLS:
		var col: Array = []
		for r in ROWS:
			col.append((grid[c][r] as Dictionary).duplicate())
		s.grid.append(col)
	return s
