extends RefCounted

## Stackwood as pure data (spec
## docs/superpowers/specs/2026-09-27-arcade-stackwood-design.md): numbered
## wooden blocks fall one at a time into a shelf five columns wide and seven
## high. Steer the falling block over a column and let it drop; on landing it
## merges with every touching block of its own number (left, right, below),
## doubling once for each, and the blocks above fall into the gap and may
## merge again, a chain. A column that overflows the shelf ends the game.
## The screen (arcade/stackwood_screen.gd) calls `aim()`, `drop()` and the
## tools, `step()` at the fixed DT, and drains `events`.
##
## Merges earn acorns, spent on three tools: a rainbow block that joins
## whatever it lands on, a bomb that clears the blocks round where it lands,
## and a zap that clears every block of the smallest number on the shelf.

enum Phase { READY, FALL, RESOLVE, OVER }
enum Piece { BLOCK, WILD, BOMB }
enum Tool { WILD, BOMB, ZAP }

const DT := 1.0 / 60.0
const COLS := 5
const ROWS := 7
const READY_TIME := 1.4
## A new block waits this long at the top before it starts to fall.
const HOLD := 0.35
## Cells a second: the fall speeds up with every drop, to a cap.
const FALL_V0 := 0.55
const FALL_DV := 0.012
const FALL_MAX := 2.4
const DROP_V := 34.0
## One round of a chain: every touching pair of the moved blocks merges, and
## the screen has this long to show it before the next round looks again.
const ROUND_T := 0.2
## The biggest number that can fall, as a power of two, before the shelf's
## best block lifts it (see `_spawn_value`).
const SPAWN_TOP := 6
const COSTS := {Tool.WILD: 140, Tool.BOMB: 120, Tool.ZAP: 160}
const TOOL_KEYS := {Tool.WILD: "wild", Tool.BOMB: "bomb", Tool.ZAP: "zap"}

var rng := RandomNumberGenerator.new()
var phase := Phase.READY
var phase_t := 0.0
## Column-major, bottom up: cols[c][i] is {id, v}, v a power of two.
var cols: Array = []
## The falling piece, or {} between pieces: {kind, v, col, y, dropping, hold}.
## y is the height of its bottom edge in cells from the shelf's floor.
var piece := {}
## What falls next, front first; a tool bought pushes the block it replaced
## back to the front.
var queue: Array = []
var score := 0
var acorns := 0
var drops := 0
var merges := 0
var chain := 0
var best_chain := 0
var max_v := 2
var tools_used := 0
var events: Array = []
## The shelf's size, in columns and rows: the game's is COLS by ROWS; a
## tutorial page stands a smaller one (ui/hud/stackwood_tutorial_diagram.gd).
var wide := COLS
var high := ROWS
## The smallest number still dealt; it rises as the shelf's best block grows.
var low_exp := 1
## Blocks still to deal small (Low start, arcade/boosters.gd): 2s and 4s.
var small_left := 0
var _ids := 0
## Blocks moved or changed this round, which may merge next round.
var _active: Array = []
var _round_t := 0.0
## Whether the resolve was started by a zap, so the piece keeps falling after.
var _resume := false

func _init(seed_value := -1, w := COLS, h := ROWS) -> void:
	wide = w
	high = h
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for c in wide:
		cols.append([])
	queue.append(_spawn_value())
	queue.append(_spawn_value())
	events.append({"type": "ready"})

func is_over() -> bool:
	return phase == Phase.OVER

func height(c: int) -> int:
	return (cols[c] as Array).size()

func fall_speed() -> float:
	return minf(FALL_MAX, FALL_V0 + FALL_DV * drops)

func next_value() -> int:
	return int(queue[0]) if not queue.is_empty() else 0

## The height a piece in column `c` would land at.
func landing(c: int) -> int:
	return height(c)

## Where a block is on the shelf, or (-1, -1).
func find(id: int) -> Vector2i:
	for c in wide:
		var col: Array = cols[c]
		for i in col.size():
			if int(col[i].id) == id:
				return Vector2i(c, i)
	return Vector2i(-1, -1)

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY:
			if phase_t >= READY_TIME:
				_set_phase(Phase.FALL)
				events.append({"type": "go"})
				_next_piece()
		Phase.FALL:
			_fall()
		Phase.RESOLVE:
			_round_t -= DT
			if _round_t <= 0.0:
				_resolve_round()

func _set_phase(p: int) -> void:
	phase = p
	phase_t = 0.0

# --- the falling piece ---

func _next_piece() -> void:
	var v: int = queue.pop_front()
	queue.append(_spawn_value())
	var col := wide / 2
	if not piece.is_empty():
		col = int(piece.col)
	piece = {"kind": Piece.BLOCK, "v": v, "col": col, "y": float(high), "dropping": false, "hold": HOLD, "id": _new_id()}
	events.append({"type": "spawn", "v": v})

## The number the next block carries: a power of two from `low_exp` up to a
## top that grows with the shelf's best block, the small ones likelier.
func _spawn_value() -> int:
	if small_left > 0:
		small_left -= 1
		return 2 if rng.randf() < 0.6 else 4
	var best := _exp(max_v)
	var top := clampi(best - 3, 2, SPAWN_TOP)
	var low := mini(low_exp, top - 1)
	var total := 0
	for e in range(low, top + 1):
		total += top - e + 2
	var roll := rng.randi_range(1, total)
	for e in range(low, top + 1):
		roll -= top - e + 2
		if roll <= 0:
			return 1 << e
	return 1 << low

static func _exp(v: int) -> int:
	var e := 0
	while (1 << (e + 1)) <= v:
		e += 1
	return e

func _new_id() -> int:
	_ids += 1
	return _ids

## Steer the piece toward column `c`, one column at a time, stopping at a
## column whose stack already stands above the piece.
func aim(c: int) -> void:
	if phase != Phase.FALL or piece.is_empty() or piece.dropping:
		return
	c = clampi(c, 0, wide - 1)
	var at: int = piece.col
	while at != c:
		var nxt := at + signi(c - at)
		if height(nxt) > piece.y + 0.001:
			break
		at = nxt
	if at != int(piece.col):
		piece.col = at
		events.append({"type": "move", "col": at})

## Let the piece go: it falls fast to wherever it would land.
func drop() -> void:
	if phase != Phase.FALL or piece.is_empty() or piece.dropping:
		return
	piece.dropping = true
	piece.hold = 0.0
	events.append({"type": "drop"})

func _fall() -> void:
	if piece.is_empty():
		return
	if piece.hold > 0.0:
		piece.hold -= DT
		return
	var v := DROP_V if piece.dropping else fall_speed()
	var floor_y := float(height(piece.col))
	piece.y = maxf(floor_y, float(piece.y) - v * DT)
	if piece.y <= floor_y:
		_land()

func _land() -> void:
	var c: int = piece.col
	var kind: int = piece.kind
	var dropped: bool = piece.dropping
	drops += 1
	chain = 0
	var at := height(c)
	if kind == Piece.BOMB:
		events.append({"type": "bomb", "col": c, "row": at})
		var gone: Array = []
		for dc in [-1, 0, 1]:
			var cc: int = c + dc
			if cc < 0 or cc >= wide:
				continue
			var col: Array = cols[cc]
			for i in range(col.size() - 1, -1, -1):
				if i >= at - 1 and i <= at + 1:
					gone.append({"id": col[i].id, "v": col[i].v, "col": cc, "row": i})
					col.remove_at(i)
		events.append({"type": "blast", "blocks": gone})
		piece = {}
		_active = []
		_mark_fallen(c - 1, c + 1, at - 1)
		_start_resolve(false)
		return
	var v: int = piece.v
	if kind == Piece.WILD:
		v = 0
		for n in [Vector2i(c - 1, at), Vector2i(c + 1, at), Vector2i(c, at - 1)]:
			var b := _at(n)
			if not b.is_empty():
				v = maxi(v, int(b.v))
		if v == 0:
			v = 1 << low_exp
	var block := {"id": piece.id, "v": v}
	(cols[c] as Array).append(block)
	events.append({"type": "land", "id": block.id, "col": c, "row": at, "v": v, "wild": kind == Piece.WILD, "dropped": dropped})
	piece = {}
	_active = [block.id]
	_start_resolve(false)

func _at(p: Vector2i) -> Dictionary:
	if p.x < 0 or p.x >= wide or p.y < 0:
		return {}
	var col: Array = cols[p.x]
	return col[p.y] if p.y < col.size() else {}

func _start_resolve(resume: bool) -> void:
	_resume = resume
	_set_phase(Phase.RESOLVE)
	_round_t = ROUND_T * 0.5

## Every block at or above `row` in columns c0..c1 has fallen, and may merge.
func _mark_fallen(c0: int, c1: int, row: int) -> void:
	for c in range(maxi(0, c0), mini(wide - 1, c1) + 1):
		var col: Array = cols[c]
		for i in range(maxi(0, row), col.size()):
			if not _active.has(col[i].id):
				_active.append(col[i].id)

## One round: each moved block in turn takes every touching block of its own
## number into itself, doubling once for each. A round that merges nothing
## ends the chain.
func _resolve_round() -> void:
	var next: Array = []
	var any := false
	var round_merges: Array = []
	for id: int in _active:
		var p := find(id)
		if p.x < 0:
			continue
		var me: Dictionary = cols[p.x][p.y]
		var mates: Array = []
		for n in [Vector2i(p.x, p.y - 1), Vector2i(p.x - 1, p.y), Vector2i(p.x + 1, p.y), Vector2i(p.x, p.y + 1)]:
			var b := _at(n)
			if not b.is_empty() and int(b.v) == int(me.v):
				mates.append({"id": b.id, "col": n.x, "row": n.y})
		if mates.is_empty():
			continue
		any = true
		var nv: int = int(me.v) << mates.size()
		# the neighbours go, highest first so the lower indices stay put
		mates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.row) > int(b.row))
		for m: Dictionary in mates:
			(cols[m.col] as Array).remove_at(int(m.row))
			_mark_after(m.col, m.row, next)
		me.v = nv
		if not next.has(me.id):
			next.append(me.id)
		merges += mates.size()
		round_merges.append({"id": me.id, "col": p.x, "row": p.y, "v": nv, "from": mates})
	if not any:
		_finish_resolve()
		return
	chain += 1
	best_chain = maxi(best_chain, chain)
	var gained := 0
	var nuts := 0
	for m: Dictionary in round_merges:
		gained += int(m.v) * chain
		nuts += (m.from as Array).size() * chain
		if int(m.v) > max_v:
			max_v = int(m.v)
			events.append({"type": "new_max", "v": max_v})
			_lift_low()
	score += gained
	acorns += nuts
	events.append({"type": "merge", "merges": round_merges, "chain": chain, "points": gained, "acorns": nuts})
	_active = next
	_round_t = ROUND_T

## A block left column `c` at `row`: everything above it has fallen.
func _mark_after(c: int, row: int, into: Array) -> void:
	var col: Array = cols[c]
	for i in range(row, col.size()):
		if not into.has(col[i].id):
			into.append(col[i].id)

## The smallest block stops falling once the best block is big enough:
## 2 goes at 1024, 4 at 4096, 8 at 16384.
func _lift_low() -> void:
	var want := 1 + maxi(0, (_exp(max_v) - 8) / 2)
	if want > low_exp:
		low_exp = want
		events.append({"type": "retired", "v": 1 << (want - 1)})
		for i in queue.size():
			if int(queue[i]) < (1 << low_exp):
				queue[i] = 1 << low_exp

func _finish_resolve() -> void:
	_active.clear()
	if chain >= 2:
		events.append({"type": "chain_end", "chain": chain})
	for c in wide:
		if height(c) > high:
			_set_phase(Phase.OVER)
			events.append({"type": "over", "col": c})
			return
	_set_phase(Phase.FALL)
	if _resume and not piece.is_empty():
		return
	_next_piece()

## Low start: the next `n` blocks dealt are small, the two already queued
## included.
func start_small(n: int) -> void:
	small_left = n
	for i in queue.size():
		queue[i] = _spawn_value()

## The Second chance (arcade/boosters.gd): the top two rows of the shelf
## are cleared, and the next block falls.
func revive() -> void:
	if phase != Phase.OVER:
		return
	var gone: Array = []
	for c in wide:
		var col: Array = cols[c]
		for i in range(col.size() - 1, -1, -1):
			if i >= high - 2:
				gone.append({"id": col[i].id, "v": col[i].v, "col": c, "row": i})
				col.remove_at(i)
	events.append({"type": "blast", "blocks": gone})
	events.append({"type": "revive"})
	piece = {}
	_set_phase(Phase.FALL)
	_next_piece()

# --- tools ---

func can_use(tool: int) -> bool:
	if phase != Phase.FALL or piece.is_empty() or piece.dropping:
		return false
	if acorns < int(COSTS[tool]):
		return false
	if tool == Tool.ZAP:
		return _smallest() > 0
	return piece.kind == Piece.BLOCK

## Spend acorns on a tool: a rainbow block or a bomb takes the falling
## block's place (the block goes back to the front of the queue); a zap
## clears every block of the smallest number on the shelf at once.
func use(tool: int) -> bool:
	if not can_use(tool):
		events.append({"type": "refused", "tool": TOOL_KEYS[tool]})
		return false
	acorns -= int(COSTS[tool])
	tools_used += 1
	match tool:
		Tool.WILD, Tool.BOMB:
			queue.push_front(int(piece.v))
			piece.kind = Piece.WILD if tool == Tool.WILD else Piece.BOMB
			piece.v = 0
			piece.hold = maxf(float(piece.hold), 0.2)
			events.append({"type": "tool", "tool": TOOL_KEYS[tool]})
		Tool.ZAP:
			var low := _smallest()
			var gone: Array = []
			for c in wide:
				var col: Array = cols[c]
				for i in range(col.size() - 1, -1, -1):
					if int(col[i].v) == low:
						gone.append({"id": col[i].id, "v": low, "col": c, "row": i})
						col.remove_at(i)
						_mark_after(c, i, _active)
			events.append({"type": "tool", "tool": "zap"})
			events.append({"type": "zap", "v": low, "blocks": gone})
			_start_resolve(true)
	return true

func _smallest() -> int:
	var low := 0
	for col: Array in cols:
		for b: Dictionary in col:
			if low == 0 or int(b.v) < low:
				low = int(b.v)
	return low

func block_count() -> int:
	var n := 0
	for col: Array in cols:
		n += col.size()
	return n
