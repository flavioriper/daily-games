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
## Four in a square leave a bee, which picks the four tiles round it and
## flies off to the tile that does the day most good. A special can also be
## tapped to set it off, for a move. From day three the bed grows weeds under
## its tiles, stones and creeping moss among them, and from day four its
## shape changes; a day can ask for them cleared. Out of moves short of the
## goals, once a game the player is offered five more (`keep_going()`).
##
## The screen (arcade/posy_screen.gd) calls `swap()`, `fire()` and `use()` and drains
## `events`; a move resolves at once, every cascade step an event of its
## own, and the screen plays them in order.

enum Phase { PLAY, OFFER, OVER }
## A tile's special: a breeze across its row or down its column, a seed bomb,
## a rainbow posy (which has no kind), a bee.
enum Sp { NONE, ROW, COL, BOMB, RAINBOW, BEE }
## What stands in a cell with no tile in it: nothing, a hole in the bed's
## shape, a stone, moss.
enum Block { NONE, HOLE, STONE, MOSS }
enum Tool { TROWEL, SWAP, BOMB, RAINBOW }

const COLS := 8
const ROWS := 8
const KIND_NAMES := ["flower", "leaf", "drop", "mushroom", "berry", "acorn"]
const TOOL_KEYS := {Tool.TROWEL: "trowel", Tool.SWAP: "swap", Tool.BOMB: "bomb", Tool.RAINBOW: "rainbow"}
## Tools that need a tile (Swap two) picked after they are pressed: all four.
const START_TOOLS := 3
## Points a tile picked is worth, times the cascade step it fell in.
const TILE_POINTS := 20
const MADE_POINTS := {Sp.ROW: 60, Sp.COL: 60, Sp.BOMB: 120, Sp.RAINBOW: 200, Sp.BEE: 80}
## Points for a weed pulled, a stone broken, moss cleared.
const BLOCK_POINTS := 40
## A goal's `k` for the obstacles: weeds pulled, stones broken, moss cleared.
const GOAL_WEED := 10
const GOAL_STONE := 11
const GOAL_MOSS := 12
## The moves the offer gives, and how many offers a game has.
const MORE_MOVES := 5
const OFFERS := 1
## The bed's shapes, from day four on even days: the cells cut out of it.
const SHAPES := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(7, 0), Vector2i(6, 0), Vector2i(7, 1),
		Vector2i(0, 7), Vector2i(1, 7), Vector2i(0, 6), Vector2i(7, 7), Vector2i(6, 7), Vector2i(7, 6)],
	[Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)],
	[Vector2i(0, 3), Vector2i(0, 4), Vector2i(7, 3), Vector2i(7, 4), Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 7), Vector2i(4, 7)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1),
		Vector2i(7, 0), Vector2i(7, 1), Vector2i(7, 2), Vector2i(6, 0), Vector2i(5, 0), Vector2i(6, 1)],
	[Vector2i(2, 2), Vector2i(5, 2), Vector2i(2, 5), Vector2i(5, 5)],
]
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
## block[c][r]: a Block; for a stone, hp[c][r] is the knocks it has left.
## weed[c][r]: the layers of weed under the cell's tile.
var block: Array = []
var hp: Array = []
var weed: Array = []
var offers := OFFERS
var bees := 0
## Whether this move touched the moss (it grows when it was left alone).
var _moss_hit := false
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
		block.append(_zeros())
		hp.append(_zeros())
		weed.append(_zeros())
	for t: int in TOOL_KEYS:
		tools[t] = START_TOOLS
	_start_day()

static func _zeros() -> Array:
	var a: Array = []
	a.resize(ROWS)
	a.fill(0)
	return a

func is_over() -> bool:
	return phase == Phase.OVER

## Out of moves short of the day, with more moves on offer.
func is_offered() -> bool:
	return phase == Phase.OFFER

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS

## Whether a tile may stand in `p`: inside the bed, no hole, stone or moss.
func live(p: Vector2i) -> bool:
	return inside(p) and int(block[p.x][p.y]) == Block.NONE

func block_at(p: Vector2i) -> int:
	return int(block[p.x][p.y]) if inside(p) else Block.HOLE

func weed_at(p: Vector2i) -> int:
	return int(weed[p.x][p.y]) if inside(p) else 0

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
## From day three one obstacle comes in, weeds, stones and moss in turn, and
## takes one of the three goals; from day four every other day's bed has a
## shape cut out of it.
static func day_plan(d: int) -> Dictionary:
	var n := 2 if d == 1 else 3
	var need := mini(12 + 4 * (d - 1), 60)
	var mv := 20 if d < 5 else 24
	var obstacle := ""
	var amount := 0
	if d >= 3:
		obstacle = ["weeds", "stones", "moss"][(d - 3) % 3]
		match obstacle:
			"weeds":
				amount = mini(10 + 2 * (d - 3), 24)
			"stones":
				amount = mini(6 + (d - 4) / 3, 12)
			"moss":
				amount = mini(3 + (d - 5) / 3, 6)
	return {"kinds": 5 if d < 5 else 6, "goals": n, "need": need, "moves": mv,
		"obstacle": obstacle, "amount": amount, "shape": d >= 4 and d % 2 == 0}

func _start_day() -> void:
	var plan := day_plan(day)
	kinds = plan.kinds
	moves_left = plan.moves
	goals.clear()
	_lay_bed(plan)
	var pool: Array = range(kinds)
	_shuffle(pool)
	var kind_goals := int(plan.goals) - (1 if String(plan.obstacle) != "" else 0)
	for i in kind_goals:
		goals.append({"k": pool[i], "need": plan.need, "got": 0})
	match String(plan.obstacle):
		"weeds":
			goals.append({"k": GOAL_WEED, "need": _count_weeds(), "got": 0})
		"stones":
			goals.append({"k": GOAL_STONE, "need": _count_blocks(Block.STONE), "got": 0})
		"moss":
			goals.append({"k": GOAL_MOSS, "need": _count_blocks(Block.MOSS), "got": 0})
	_deal()
	events.append({"type": "deal", "day": day, "tiles": _all_tiles(), "moves": moves_left, "goals": goals.duplicate(true),
		"cells": _all_cells()})

## The bed for a day: its shape, then its weeds, stones or moss, laid where
## the pattern and the dice say.
func _lay_bed(plan: Dictionary) -> void:
	for c in COLS:
		for r in ROWS:
			block[c][r] = Block.NONE
			hp[c][r] = 0
			weed[c][r] = 0
			grid[c][r] = {}
	if bool(plan.shape):
		for p: Vector2i in SHAPES[rng.randi_range(0, SHAPES.size() - 1)]:
			block[p.x][p.y] = Block.HOLE
	var cells: Array = []
	for c in COLS:
		for r in ROWS:
			if live(Vector2i(c, r)):
				cells.append(Vector2i(c, r))
	_shuffle(cells)
	var amount := int(plan.amount)
	match String(plan.obstacle):
		"weeds":
			# a patch rather than a scatter: grown out from a few roots
			var patch := {}
			var roots := cells.slice(0, 3)
			var frontier: Array = roots.duplicate()
			while patch.size() < amount and not frontier.is_empty():
				var i := rng.randi_range(0, frontier.size() - 1)
				var p: Vector2i = frontier[i]
				frontier.remove_at(i)
				if patch.has(p) or not live(p):
					continue
				patch[p] = true
				for d: Vector2i in DIRS:
					if live(p + d) and not patch.has(p + d):
						frontier.append(p + d)
			for p: Vector2i in patch:
				weed[p.x][p.y] = 2 if day >= 6 and rng.randf() < 0.4 else 1
		"stones":
			# in the lower half, where they sit in the way of the fall
			var n := 0
			for p: Vector2i in cells:
				if n >= amount:
					break
				if p.y < 3:
					continue
				block[p.x][p.y] = Block.STONE
				hp[p.x][p.y] = 2 if day >= 7 and rng.randf() < 0.5 else 1
				n += 1
		"moss":
			var n := 0
			for p: Vector2i in cells:
				if n >= amount:
					break
				if p.y < 2:
					continue
				block[p.x][p.y] = Block.MOSS
				n += 1

func _count_weeds() -> int:
	var n := 0
	for c in COLS:
		for r in ROWS:
			n += int(weed[c][r])
	return n

func _count_blocks(kind_of: int) -> int:
	var n := 0
	for c in COLS:
		for r in ROWS:
			if int(block[c][r]) == kind_of:
				n += 1
	return n

## Every cell's ground: [{cell, block, hp, weed}] for the ones with anything.
func _all_cells() -> Array:
	var out: Array = []
	for c in COLS:
		for r in ROWS:
			if int(block[c][r]) != Block.NONE or int(weed[c][r]) > 0:
				out.append({"cell": Vector2i(c, r), "block": block[c][r], "hp": hp[c][r], "weed": weed[c][r]})
	return out

## A fresh bed: no three in a line anywhere, and at least one move in it.
func _deal() -> void:
	for attempt in 100:
		for c in COLS:
			for r in ROWS:
				if not live(Vector2i(c, r)):
					grid[c][r] = {}
					continue
				var banned := {}
				if c >= 2 and kind(Vector2i(c - 1, r)) >= 0 and kind(Vector2i(c - 1, r)) == kind(Vector2i(c - 2, r)):
					banned[kind(Vector2i(c - 1, r))] = true
				if r >= 2 and kind(Vector2i(c, r - 1)) >= 0 and kind(Vector2i(c, r - 1)) == kind(Vector2i(c, r - 2)):
					banned[kind(Vector2i(c, r - 1))] = true
				var q := kind(Vector2i(c - 1, r - 1)) if c >= 1 and r >= 1 else -2
				if q >= 0 and kind(Vector2i(c - 1, r)) == q and kind(Vector2i(c, r - 1)) == q:
					banned[q] = true
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
	if not combo and not _takes(a) and not _takes(b):
		grid[a.x][a.y] = ta
		grid[b.x][b.y] = tb
		events.append({"type": "swap", "a": a, "b": b, "ida": ta.id, "idb": tb.id, "ok": false})
		return false
	events.append({"type": "swap", "a": a, "b": b, "ida": ta.id, "idb": tb.id, "ok": true})
	moves_left -= 1
	moves += 1
	_moss_hit = false
	if combo:
		_combo(b, a)
		_fall()
	_cascade([b, a])
	_after_move()
	return true

## Tap a special to set it off where it stands, for a move.
func fire(p: Vector2i) -> bool:
	if phase != Phase.PLAY or special(p) == Sp.NONE:
		return false
	moves_left -= 1
	moves += 1
	_moss_hit = false
	events.append({"type": "fire", "cell": p, "id": at(p).id})
	_resolve({p: true}, {}, [], [], 1)
	_fall()
	_cascade([])
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
					t.sp = osp if osp == Sp.BOMB or osp == Sp.BEE else rng.randi_range(Sp.ROW, Sp.COL)
					turned.append({"id": t.id, "cell": cell, "k": t.k, "sp": t.sp})
		if not turned.is_empty():
			events.append({"type": "convert", "tiles": turned})
		fired.erase(other)
		for cell: Vector2i in cells:
			clear[cell] = true
		blasts.append({"kind": "rainbow", "cell": bow, "k": k, "cells": cells})
	elif sp == Sp.BEE or sq == Sp.BEE:
		var other := sq if sp == Sp.BEE else sp
		fired.erase(q)
		fired.erase(p)
		_add_plus(clear, p)
		if other == Sp.BEE:
			# two bees: three bees go, each to its own mark
			for i in 3:
				var to := _bee_mark(clear)
				if to.x >= 0:
					clear[to] = true
					blasts.append({"kind": "bee", "cell": p, "to": to})
		else:
			# a bee carries the other special off and sets it off there
			var to := _bee_mark(clear, true)
			if to.x >= 0:
				blasts.append({"kind": "bee", "cell": p, "to": to, "carry": other})
				var tt := at(to)
				if not tt.is_empty():
					tt.sp = other
					tt.lit = false
				clear[to] = true
		# the two tiles themselves are gone, and neither goes off again
		for x: Vector2i in [p, q]:
			var t := at(x)
			if not t.is_empty():
				t.sp = Sp.NONE
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
			Sp.BEE:
				# the four round it, then off to the tile that helps most
				_add_plus(hit, p)
				var to := _bee_mark(clear)
				if to.x >= 0:
					hit[to] = true
				blasts.append({"kind": "bee", "cell": p, "to": to})
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
	# stones and moss: knocked by a blast over them or a match beside them
	var knocked := {}
	for p: Vector2i in clear:
		if inside(p) and (block_at(p) == Block.STONE or block_at(p) == Block.MOSS):
			knocked[p] = true
	for g: Dictionary in groups:
		for p: Vector2i in g.cells:
			for d: Vector2i in DIRS:
				var q: Vector2i = p + d
				if inside(q) and (block_at(q) == Block.STONE or block_at(q) == Block.MOSS):
					knocked[q] = true
	var blocks_hit: Array = []
	for p: Vector2i in knocked:
		var was := block_at(p)
		if was == Block.MOSS:
			_moss_hit = true
		if was == Block.STONE and int(hp[p.x][p.y]) > 1:
			hp[p.x][p.y] = int(hp[p.x][p.y]) - 1
			blocks_hit.append({"cell": p, "block": was, "hp": hp[p.x][p.y]})
			continue
		block[p.x][p.y] = Block.NONE
		hp[p.x][p.y] = 0
		blocks_hit.append({"cell": p, "block": was, "hp": 0})
		points += BLOCK_POINTS
		_goal_add(GOAL_STONE if was == Block.STONE else GOAL_MOSS)
	var weeds_pulled: Array = []
	for p: Vector2i in clear:
		var t := at(p)
		if t.is_empty():
			continue
		if weed_at(p) > 0:
			weed[p.x][p.y] = int(weed[p.x][p.y]) - 1
			weeds_pulled.append({"cell": p, "left": weed[p.x][p.y]})
			points += BLOCK_POINTS
			_goal_add(GOAL_WEED)
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
	_moss_need()
	events.append({"type": "clear", "tiles": gone, "made": born, "blasts": blasts, "lit": lit_ids,
		"step": step, "points": points, "groups": shapes, "goals": goals.duplicate(true),
		"blocks": blocks_hit, "weeds": weeds_pulled})

func _goal_add(k: int) -> void:
	for g: Dictionary in goals:
		if int(g.k) == k and int(g.got) < int(g.need):
			g.got = int(g.got) + 1
			if int(g.got) == int(g.need):
				events.append({"type": "goal_done", "k": k})

## A moss goal asks for all of it: what is cleared and what still stands.
func _moss_need() -> void:
	for g: Dictionary in goals:
		if int(g.k) == GOAL_MOSS:
			g.need = int(g.got) + _count_blocks(Block.MOSS)

## Where a bee flies: the stone, moss or weed a goal still wants, else a tile
## a goal still wants, else a special to set off, else anywhere. Never a cell
## already being picked. `tile_only` for a bee carrying a special.
func _bee_mark(taken: Dictionary, tile_only := false) -> Vector2i:
	var want := {}
	for g: Dictionary in goals:
		if int(g.got) < int(g.need):
			want[int(g.k)] = true
	var best := Vector2i(-1, -1)
	var best_v := -1.0
	for c in COLS:
		for r in ROWS:
			var p := Vector2i(c, r)
			if taken.has(p) or not inside(p):
				continue
			var v := -1.0
			var b := block_at(p)
			if b == Block.STONE and not tile_only:
				v = 8.0 if want.has(GOAL_STONE) else 1.5
			elif b == Block.MOSS and not tile_only:
				v = 9.0 if want.has(GOAL_MOSS) else 2.5
			elif b == Block.NONE and not at(p).is_empty():
				var t := at(p)
				if tile_only and int(t.sp) != Sp.NONE:
					continue
				v = 1.0
				if weed_at(p) > 0 and want.has(GOAL_WEED):
					v = 7.0 + weed_at(p)
				elif want.has(int(t.k)):
					v = 5.0
				elif int(t.sp) != Sp.NONE and not tile_only:
					v = 3.0
			if v < 0.0:
				continue
			v += rng.randf() * 0.9
			if v > best_v:
				best_v = v
				best = p
	return best

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

func _add_plus(into: Dictionary, p: Vector2i) -> void:
	into[p] = true
	for d: Vector2i in DIRS:
		if inside(p + d):
			into[p + d] = true

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
		# the cells a tile may stand in, bottom up; tiles fall past holes,
		# stones and moss
		var slots: Array = []
		for r in range(ROWS - 1, -1, -1):
			if live(Vector2i(c, r)):
				slots.append(r)
		var stack: Array = []
		for r: int in slots:
			if not (col[r] as Dictionary).is_empty():
				stack.append({"t": col[r], "from": r})
				col[r] = {}
		var i := 0
		for s: Dictionary in stack:
			var r: int = slots[i]
			col[r] = s.t
			if int(s.from) != r:
				falls.append({"id": s.t.id, "col": c, "from": s.from, "to": r})
			i += 1
		var above := 0
		while i < slots.size():
			above += 1
			var r: int = slots[i]
			var t := _new_tile(rng.randi_range(0, kinds - 1))
			col[r] = t
			fresh.append({"id": t.id, "col": c, "row": r, "k": t.k, "sp": t.sp, "from": -above})
			i += 1
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
	# four in a square are a run of their own, which leaves a bee
	for c in COLS - 1:
		for r in ROWS - 1:
			var k := kind(Vector2i(c, r))
			if k >= 0 and kind(Vector2i(c + 1, r)) == k and kind(Vector2i(c, r + 1)) == k and kind(Vector2i(c + 1, r + 1)) == k:
				runs.append({"cells": [Vector2i(c, r), Vector2i(c + 1, r), Vector2i(c, r + 1), Vector2i(c + 1, r + 1)], "k": k, "sq": true})
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
		var longest: Dictionary = {}
		var has_h := false
		var has_v := false
		var square: Dictionary = {}
		for run: Dictionary in g.runs:
			for p: Vector2i in run.cells:
				cells[p] = true
			if run.get("sq", false):
				square = run
				continue
			if longest.is_empty() or run.cells.size() > longest.cells.size():
				longest = run
			if run.h:
				has_h = true
			else:
				has_v = true
		var sp := Sp.NONE
		var n: int = 0 if longest.is_empty() else longest.cells.size()
		if n >= 5:
			sp = Sp.RAINBOW
		elif has_h and has_v:
			sp = Sp.BOMB
		elif n == 4:
			# four across leave a breeze down the column, four down one
			# across the row
			sp = Sp.COL if longest.h else Sp.ROW
		elif not square.is_empty():
			sp = Sp.BEE
		var lead: Dictionary = longest if not longest.is_empty() else square
		var grp := {"cells": cells.keys(), "k": lead.k, "sp": sp, "mid": lead.cells[(lead.cells.size() - 1) / 2]}
		if has_h and has_v:
			for run: Dictionary in g.runs:
				for p: Vector2i in run.cells:
					var hv := 0
					for other: Dictionary in g.runs:
						if not other.get("sq", false) and (other.cells as Array).has(p):
							hv += 1
					if hv >= 2:
						grp.cross = p
		out.append(grp)
	return out

## Whether a swap into `p` is taken: a line of three through it, or a square
## of four with it in one corner.
func _takes(p: Vector2i) -> bool:
	return _run_through(p) or _square_at(p)

func _square_at(p: Vector2i) -> bool:
	var k := kind(p)
	if k < 0:
		return false
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if kind(p + Vector2i(d.x, 0)) == k and kind(p + Vector2i(0, d.y)) == k and kind(p + d) == k:
			return true
	return false

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
	var ok := _takes(a) or _takes(b)
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
			if _square_at(a) or _square_at(b):
				n = maxi(n, 4)
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
	var cells: Array = []
	for c in COLS:
		for r in ROWS:
			if not (grid[c][r] as Dictionary).is_empty():
				tiles.append(grid[c][r])
				cells.append(Vector2i(c, r))
	for attempt in 200:
		_shuffle(tiles)
		for i in cells.size():
			grid[cells[i].x][cells[i].y] = tiles[i]
		if _groups().is_empty() and has_move():
			break
	var to: Array = []
	for p: Vector2i in cells:
		to.append({"id": grid[p.x][p.y].id, "cell": p})
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
	if not _moss_hit:
		_grow_moss()
	_moss_hit = false
	if moves_left <= 0:
		if offers > 0:
			phase = Phase.OFFER
			events.append({"type": "offer", "day": day, "moves": MORE_MOVES, "short": _short()})
		else:
			phase = Phase.OVER
			events.append({"type": "over", "day": day})

## How many things the day still wants, over all its goals.
func _short() -> int:
	var n := 0
	for g: Dictionary in goals:
		n += maxi(0, int(g.need) - int(g.got))
	return n

## Take the offer: five more moves, and the day goes on.
func keep_going() -> bool:
	if phase != Phase.OFFER:
		return false
	offers -= 1
	moves_left += MORE_MOVES
	phase = Phase.PLAY
	events.append({"type": "more_moves", "moves": MORE_MOVES})
	return true

## Turn the offer down: the game is over.
func decline() -> void:
	if phase != Phase.OFFER:
		return
	phase = Phase.OVER
	events.append({"type": "over", "day": day})

## Moss left alone for a move creeps into a plain tile beside it.
func _grow_moss() -> void:
	var spots: Array = []
	for c in COLS:
		for r in ROWS:
			if int(block[c][r]) != Block.MOSS:
				continue
			for d: Vector2i in DIRS:
				var q := Vector2i(c, r) + d
				if live(q) and not at(q).is_empty() and special(q) == Sp.NONE:
					spots.append([Vector2i(c, r), q])
	if spots.is_empty():
		return
	var s: Array = spots[rng.randi_range(0, spots.size() - 1)]
	var q: Vector2i = s[1]
	var t := at(q)
	grid[q.x][q.y] = {}
	block[q.x][q.y] = Block.MOSS
	_moss_need()
	events.append({"type": "moss", "from": s[0], "cell": q, "id": t.id, "k": t.k, "goals": goals.duplicate(true)})
	if not has_move():
		_reshuffle()

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
	if not can_use(tool):
		return false
	# the trowel and the bomb reach stones and moss as well as tiles
	if at(a).is_empty():
		var bl := block_at(a)
		return (tool == Tool.TROWEL or tool == Tool.BOMB) and (bl == Block.STONE or bl == Block.MOSS)
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
	_moss_hit = true
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

## Opening bloom (arcade/boosters.gd): a breeze and a seed bomb laid in a
## fresh bed, before the screen reads the deal.
func opening_bloom() -> void:
	var spots: Array = []
	for c in COLS:
		for r in ROWS:
			if not at(Vector2i(c, r)).is_empty() and special(Vector2i(c, r)) == Sp.NONE:
				spots.append(Vector2i(c, r))
	_shuffle(spots)
	var sps := [Sp.ROW if rng.randf() < 0.5 else Sp.COL, Sp.BOMB]
	for i in mini(sps.size(), spots.size()):
		var p: Vector2i = spots[i]
		(grid[p.x][p.y] as Dictionary).sp = sps[i]
	for ev: Dictionary in events:
		if String(ev.type) == "deal":
			ev.tiles = _all_tiles()

## The Second chance (arcade/boosters.gd): more moves on a day that ran out.
func revive(more: int) -> void:
	if phase != Phase.OVER:
		return
	moves_left += more
	phase = Phase.PLAY
	events.append({"type": "more_moves", "moves": more})

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
	s.offers = offers
	s.block = block.duplicate(true)
	s.hp = hp.duplicate(true)
	s.weed = weed.duplicate(true)
	s.grid = []
	for c in COLS:
		var col: Array = []
		for r in ROWS:
			col.append((grid[c][r] as Dictionary).duplicate())
		s.grid.append(col)
	return s
