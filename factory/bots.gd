extends RefCounted

## Factory's robots, as rules over data: a robot is a Dictionary the sim
## keeps in `robots` (its fields are in the sim's header), and everything
## here is static, handed that Dictionary and, to act on the floor, the sim.
## Nothing here draws or keeps state of its own.
## Spec docs/superpowers/specs/2026-10-20-factory-rewired-design.md, sections
## 4 (parts, battery, bay), 5 (the program) and 6 (time).
##
## A program is a chain of nodes from the body: `next[id].out` is the node
## after `id` ("" for a loose wire, BODY to loop back), `next[BODY].out` the
## first. `pc` is the node running ("body" at rest), `t` the ticks into it
## (into the tile being stepped, for a Move) and `left` the tiles a Move has
## still to walk (-1 while it bumps). A Move walks the way the robot faces;
## a Turn turns it a quarter, right or left, in ACT_TICKS and a unit, and
## the facing is kept when the loop comes round again.
##
## The floor between ticks: a step begins the tick `tile` moves on, with
## `was` the tile it left, and lasts `step_ticks` ticks; while `was != tile`
## it is mid-step, and `pos(b, alpha)` is where to draw it. The tick a step's
## last tick is done `t` is back at 0 but `was` is kept, so the slide's last
## stretch is drawn too; the next tick lets it go (`tick`, first thing). A
## robot standing still has `was == tile`.

const Sim = preload("res://factory/sim.gd")

## The ticks a bubble is shown for; one not here is held until cleared.
const BUBBLE_TICKS := {"wait": 4, "!": 9}

## A new robot on the bay facing HOME_FACING with `parts` fitted, a full
## cell and `chain` as its program: rows of ["move", n], ["turn", way]
## (Sim.RIGHT or Sim.LEFT), ["pick"] or ["release"], given the ids "a", "b",
## ... in order and wired body -> a -> b -> ... -> body.
static func new_robot(name: String, parts: Array, chain: Array) -> Dictionary:
	var b := {
		"name": name, "dock": Sim.BAY, "tile": Sim.BAY, "was": Sim.BAY, "facing": Sim.HOME_FACING, "parts": parts.duplicate(),
		"nodes": {}, "order": [], "next": {Sim.BODY: {"out": Sim.BODY}}, "pc": Sim.BODY, "t": 0, "left": 0,
		"held": {}, "charge": 0, "charging": false, "stuck": "", "bubble": "", "bubble_t": 0, "counters": {},
	}
	var prev: String = Sim.BODY
	for k in chain.size():
		var row: Array = chain[k]
		var id := String.chr("a".unicode_at(0) + k)
		var kind := String(row[0])
		b.nodes[id] = {"kind": kind, "facing": int(row[1]) if kind == "turn" else 0, "n": int(row[1]) if kind == "move" else 1}
		b.order.append(id)
		b.next[prev].out = id
		b.next[id] = {"out": Sim.BODY}
		prev = id
	b.charge = cell(b)
	return b

## The wire out of `id` cut loose.
static func loose_after(b: Dictionary, id: String) -> void:
	if b.next.has(id):
		b.next[id].out = ""

## The chain as it runs: the ids from the body's out, until a loose wire,
## the body, an id that is no node or one already passed. `closed` only when
## it came back to the body.
static func walk(b: Dictionary) -> Dictionary:
	var ids: Array = []
	var seen := {}
	var at: String = b.next.get(Sim.BODY, {}).get("out", "")
	while at != "" and at != Sim.BODY and b.nodes.has(at) and not seen.has(at):
		seen[at] = true
		ids.append(at)
		at = b.next.get(at, {}).get("out", "")
	return {"ids": ids, "closed": at == Sim.BODY}

## Whether a part fitted gives the node `kind`.
static func can(b: Dictionary, kind: String) -> bool:
	for part: String in b.parts:
		if (Sim.PARTS.get(part, {}).get("gives", []) as Array).has(kind):
			return true
	return false

## Ticks a tile: the quickest of the parts that give Move (0 with none).
static func step_ticks(b: Dictionary) -> int:
	var best := 0
	for part: String in b.parts:
		var row: Dictionary = Sim.PARTS.get(part, {})
		if (row.get("gives", []) as Array).has("move") and row.has("step"):
			best = int(row.step) if best == 0 else mini(best, int(row.step))
	return best

## Units a tick on the bay: the largest rate fitted, 0 with no Battery (a
## plug does nothing without one).
static func rate(b: Dictionary) -> int:
	if not b.parts.has("battery"):
		return 0
	var best := 0
	for part: String in b.parts:
		best = maxi(best, int(Sim.PARTS.get(part, {}).get("rate", 0)))
	return best

## Units a full cell holds, 0 with no Battery.
static func cell(b: Dictionary) -> int:
	return int(Sim.PARTS.battery.cell) if b.parts.has("battery") else 0

## Units one loop of the chain as it runs spends: a Move its count, any other
## node 1.
static func cost(b: Dictionary) -> int:
	var units := 0
	for id: String in walk(b).ids:
		var node: Dictionary = b.nodes[id]
		units += int(node.n) if node.kind == "move" else 1
	return units

## The way the robot faces at each node of the chain as it runs, setting
## off facing `from` (HOME_FACING, as after an edit): a Move's is the way it
## walks, a Turn's the way it faces once turned. {ways: {id: facing}, end:
## the facing it comes back to the body with}.
static func ways(b: Dictionary, from := Sim.HOME_FACING) -> Dictionary:
	var f := from
	var out := {}
	for id: String in walk(b).ids:
		var node: Dictionary = b.nodes[id]
		if node.kind == "turn":
			f = (f + int(node.facing)) % 4
		out[id] = f
	return {"ways": out, "end": f}

## Where the chain as it runs ends up from where it starts (bumps aside),
## setting off facing `from`.
static func net(b: Dictionary, from := Sim.HOME_FACING) -> Vector2i:
	var to := Vector2i.ZERO
	var w: Dictionary = ways(b, from).ways
	for id: String in walk(b).ids:
		var node: Dictionary = b.nodes[id]
		if node.kind == "move":
			to += Sim.DIRS[int(w[id])] * int(node.n)
	return to

## Whether the chain as it runs comes back to the body facing the way it
## set off, so the next loop walks the same ring.
static func faces_home(b: Dictionary) -> bool:
	return int(ways(b).end) == Sim.HOME_FACING

## On the bay at the body: what an edit and a tow do. What it holds and the
## charge it has are kept (an edit never refills a cell).
static func home(b: Dictionary) -> void:
	b.tile = b.dock
	b.was = b.dock
	b.facing = Sim.HOME_FACING
	b.pc = Sim.BODY
	b.t = 0
	b.left = 0
	b.stuck = ""
	b.bubble = ""
	b.bubble_t = 0
	b.charging = false
	b.counters = {}

## Where to draw it, in tile units (a tile's middle at tile + (0.5, 0.5)):
## between `was` and `tile` through a step, by the ticks into it and `alpha`.
## A step of `step_ticks` ticks is drawn over as many frames' worth of ticks,
## the frame after its first tick at `was` and the frame before the next
## step's first at `tile`, so a walk of many tiles slides on without a stop
## at each (it stood a tick a tile until 2026-10-20).
static func pos(b: Dictionary, alpha: float) -> Vector2:
	var to := Vector2(b.tile) + Vector2(0.5, 0.5)
	if b.was == b.tile:
		return to
	var span := maxi(step_ticks(b), 1)
	# t is 1..span - 1 through the step, and back at 0 once its last tick ran
	var done := int(b.t) - 1 if int(b.t) > 0 else span - 1
	var f := clampf((float(done) + alpha) / float(span), 0.0, 1.0)
	return (Vector2(b.was) + Vector2(0.5, 0.5)).lerp(to, f)

## The way to draw it facing, in quarters (0 +x, 1 +y, ...; not wrapped):
## through a Turn it swings from the facing it had to the one it turns to,
## by the ticks into it and `alpha`, the way `pos` slides a step.
static func heading(b: Dictionary, alpha: float) -> float:
	var f := float(b.facing)
	if b.pc == Sim.BODY or b.stuck != "" or not b.nodes.has(b.pc) or b.nodes[b.pc].kind != "turn" or int(b.t) == 0:
		return f
	var way := 1.0 if int(b.nodes[b.pc].facing) == Sim.RIGHT else -1.0
	# t is 1..ACT_TICKS - 1 between the tick it began and the one it is done
	return f + way * clampf((float(int(b.t) - 1) + alpha) / float(Sim.ACT_TICKS - 1), 0.0, 1.0)

# --- the tick ---

## A tick of its program (spec 5 and 6).
static func tick(sim: RefCounted, b: Dictionary) -> void:
	# a step whose last tick ran the tick before is over
	if int(b.t) == 0 and b.was != b.tile:
		b.was = b.tile
	if int(b.bubble_t) > 0:
		b.bubble_t = int(b.bubble_t) - 1
		if b.bubble_t == 0:
			b.bubble = ""
	if not b.parts.has("battery"):
		if b.stuck != "nocell":
			_stop(sim, b, "nocell")
		return
	if b.stuck == "nocell":
		b.stuck = ""
		b.bubble = ""
	if b.stuck != "":
		return
	if b.pc == Sim.BODY:
		_body(sim, b)
		return
	if not b.nodes.has(b.pc):
		_stop(sim, b, "?")
		return
	var node: Dictionary = b.nodes[b.pc]
	if not can(b, node.kind):
		_skip(sim, b)
	elif node.kind == "move":
		_move(sim, b)
	elif node.kind == "turn":
		_turn(sim, b, node)
	else:
		_hand(sim, b, node.kind)

## At the body: on the bay and short of a full cell it charges, `rate` a
## tick; else the body's BODY_TICKS and on.
static func _body(sim: RefCounted, b: Dictionary) -> void:
	var full := cell(b)
	if b.tile == Sim.BAY and int(b.charge) < full and b.t == 0:
		if not b.charging:
			b.charging = true
			sim.events.append({"type": "charging", "robot": _index(sim, b), "units": full - int(b.charge)})
		b.charge = mini(int(b.charge) + rate(b), full)
		if b.charge >= full:
			b.charging = false
			sim.events.append({"type": "charged", "robot": _index(sim, b)})
		return
	b.charging = false
	b.t = int(b.t) + 1
	if b.t >= Sim.BODY_TICKS:
		_advance(sim, b)

## A Move: a tile every `step_ticks`, a unit a tile; a step off the floor is
## a bump, ACT_TICKS and a unit, and the rest of the Move is dropped.
static func _move(sim: RefCounted, b: Dictionary) -> void:
	if b.t == 0:
		if int(b.left) == 0:
			_advance(sim, b)
			return
		if not _spend(sim, b):
			return
		var to: Vector2i = b.tile + Sim.DIRS[int(b.facing)]
		var i := _index(sim, b)
		if not sim.on_floor(to):
			b.left = -1
			sim.events.append({"type": "bump", "robot": i, "tile": b.tile})
		else:
			b.was = b.tile
			b.tile = to
			sim.events.append({"type": "step", "robot": i, "from": b.was, "to": to})
	b.t = int(b.t) + 1
	if b.t < (Sim.ACT_TICKS if b.left == -1 else step_ticks(b)):
		return
	# `was` is kept a tick more, for the slide's last stretch (`pos`)
	b.t = 0
	if b.left == -1:
		_advance(sim, b)
		return
	b.left = int(b.left) - 1
	if b.left == 0:
		_advance(sim, b)

## A Turn: a unit as it begins, ACT_TICKS, then it faces a quarter round
## (`heading` swings it there in between).
static func _turn(sim: RefCounted, b: Dictionary, node: Dictionary) -> void:
	if b.t == 0 and not _spend(sim, b):
		return
	b.t = int(b.t) + 1
	if b.t < Sim.ACT_TICKS:
		return
	b.facing = (int(b.facing) + int(node.facing)) % 4
	sim.events.append({"type": "pivot", "robot": _index(sim, b), "facing": b.facing})
	_advance(sim, b)

## A Pick or a Release: ACT_TICKS, then the hand. A Pick costs its unit as it
## begins and takes nothing into a full hand; a Release costs its unit only
## when it lands, and one the tile will not take waits (`...`, no cost) and
## is tried again every tick. With nothing held a Release does nothing, for
## its unit.
static func _hand(sim: RefCounted, b: Dictionary, kind: String) -> void:
	if b.t == 0:
		if kind == "pick" and not _spend(sim, b):
			return
		if kind == "release" and int(b.charge) <= 0:
			_flat(sim, b)
			return
	if b.t < Sim.ACT_TICKS:
		b.t = int(b.t) + 1
		if b.t < Sim.ACT_TICKS:
			return
	var i := _index(sim, b)
	if kind == "pick":
		var it: Dictionary = {} if not b.held.is_empty() else sim.take(b.tile)
		if not it.is_empty():
			b.held = it
		sim.events.append({"type": "pick", "robot": i, "tile": b.tile, "kind": String(it.get("kind", ""))})
		_advance(sim, b)
		return
	var held: Dictionary = b.held
	if not held.is_empty():
		if not sim.takes(b.tile, held):
			if b.bubble != "wait":
				sim.events.append({"type": "wait", "robot": i})
			_say(b, "wait")
			return
		held.was = Vector2(b.tile) + Vector2(0.5, 0.5)
		sim.put(b.tile, held)
		b.held = {}
	b.charge = int(b.charge) - 1
	if b.bubble == "wait":
		b.bubble = ""
		b.bubble_t = 0
	sim.events.append({"type": "release", "robot": i, "tile": b.tile, "kind": String(held.get("kind", ""))})
	_advance(sim, b)

## A node whose part is not fitted: skipped with a `!`, ACT_TICKS, a unit.
static func _skip(sim: RefCounted, b: Dictionary) -> void:
	if b.t == 0:
		if not _spend(sim, b):
			return
		_say(b, "!")
		sim.events.append({"type": "skip", "robot": _index(sim, b), "id": b.pc})
	b.t = int(b.t) + 1
	if b.t >= Sim.ACT_TICKS:
		_advance(sim, b)

## The wire out of the node done: on to the next, back to the body, or a `?`
## where it is loose.
static func _advance(sim: RefCounted, b: Dictionary) -> void:
	var to: String = b.next.get(b.pc, {}).get("out", "")
	b.t = 0
	b.left = 0
	if to == Sim.BODY:
		b.pc = Sim.BODY
		b.counters = {}
		return
	if to == "" or not b.nodes.has(to):
		_stop(sim, b, "?")
		return
	b.pc = to
	var node: Dictionary = b.nodes[to]
	if node.kind == "move":
		b.left = int(node.n)

## A unit off the cell; with none left it goes flat where it stands and
## false. (At the body on the bay it charges instead and never asks.)
static func _spend(sim: RefCounted, b: Dictionary) -> bool:
	if int(b.charge) <= 0:
		_flat(sim, b)
		return false
	b.charge = int(b.charge) - 1
	return true

static func _flat(sim: RefCounted, b: Dictionary) -> void:
	b.stuck = "flat"
	b.charging = false
	_say(b, "flat")
	sim.events.append({"type": "flat", "robot": _index(sim, b), "tile": b.tile})

## Stopped with `why` ("?" or "nocell") over it until an edit sends it home.
static func _stop(sim: RefCounted, b: Dictionary, why: String) -> void:
	b.stuck = why
	b.charging = false
	_say(b, why)
	sim.events.append({"type": "stuck", "robot": _index(sim, b), "why": why})

static func _say(b: Dictionary, bubble: String) -> void:
	b.bubble = bubble
	b.bubble_t = int(BUBBLE_TICKS.get(bubble, 0))

static func _index(sim: RefCounted, b: Dictionary) -> int:
	for i in sim.robots.size():
		if is_same(sim.robots[i], b):
			return i
	return -1
