extends RefCounted

## Millstream as pure data (spec
## docs/superpowers/specs/2026-09-27-arcade-millstream-design.md): a small
## factory in a painted valley, seen from above. A grid of tiles with a
## stream down its left side, the Mill on the bank, and deposits of ore.
## The screen (arcade/millstream_screen.gd) steps this at the fixed DT,
## hands it the finger's taps (dig, place, tend, remove, hand in) and
## drains `events`.
##
## Slice 1: ore is dug by hand from the iron deposits and smelted by kilns
## that run on their own; copper and stone stand locked. Everything the
## player owns is in `stock`, which pays for buildings and is handed in at
## the Mill for the milestones.

const DT := 1.0 / 30.0
const COLS := 20
const ROWS := 28
## The Mill, on the stream's bank.
const MILL := Rect2i(3, 12, 3, 3)
## Deposits are 2x2: resource, top-left cell, purity (0 poor, 1 normal,
## 2 rich). Hand-made, so the valley is the same for everyone.
const DEPOSITS := [
	["iron", Vector2i(7, 11), 1], ["iron", Vector2i(10, 16), 0], ["iron", Vector2i(14, 9), 2],
	["iron", Vector2i(15, 20), 1], ["iron", Vector2i(6, 22), 1], ["iron", Vector2i(4, 5), 0],
	["copper", Vector2i(12, 3), 1], ["copper", Vector2i(16, 14), 2], ["copper", Vector2i(9, 25), 0],
	["stone", Vector2i(8, 6), 1], ["stone", Vector2i(12, 23), 2], ["stone", Vector2i(17, 4), 1],
]
## What slice 1 lets the player dig.
const LIVE := ["iron"]
const COSTS := {"kiln": {"iron_ore": 10}}
const SIZES := {"kiln": Vector2i(2, 2)}
## A kiln: one ore to one ingot every SMELT seconds (30 a minute), a
## hopper of HOPPER ore and a shelf of SHELF ingots.
const SMELT := 2.0
const HOPPER := 20
const SHELF := 50
## The milestones, handed in at the Mill from the stock.
const MILESTONES := [
	{"key": "MS_M1", "need": {"iron_ingot": 20}},
]
const SAVE_VERSION := 1

## Seconds played (the factory pauses while the app is closed).
var t := 0.0
var stock := {"iron_ore": 0, "iron_ingot": 0}
## {id, kind, cell: Vector2i, hopper, shelf, prog}
var buildings: Array = []
var milestone := 0
## Seconds played when the last milestone was handed in; 0 until then.
var done_t := 0.0
var events: Array = []
var mined := 0
var smelted := 0
var _next_id := 1
## cell -> "mill", "dep:<i>" or "b:<id>"
var _grid := {}

func _init() -> void:
	_index()

# --- the valley ---

## The stream's first water column on a row: it meanders over columns 0-2.
static func stream_at(row: int) -> int:
	return int(round(0.5 + 0.5 * sin(row * 0.42 + 0.6)))

static func is_water(c: Vector2i) -> bool:
	var s := stream_at(c.y)
	return c.x >= s and c.x <= s + 1

static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS

static func deposit_rect(i: int) -> Rect2i:
	return Rect2i(DEPOSITS[i][1], Vector2i(2, 2))

static func is_live(i: int) -> bool:
	return String(DEPOSITS[i][0]) in LIVE

func _index() -> void:
	_grid.clear()
	for x in range(MILL.position.x, MILL.end.x):
		for y in range(MILL.position.y, MILL.end.y):
			_grid[Vector2i(x, y)] = "mill"
	for i in DEPOSITS.size():
		var r := deposit_rect(i)
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				_grid[Vector2i(x, y)] = "dep:%d" % i
	for b: Dictionary in buildings:
		_claim(b)

func _claim(b: Dictionary) -> void:
	var r := Rect2i(b.cell, SIZES[b.kind])
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			_grid[Vector2i(x, y)] = "b:%d" % b.id

func owner_at(c: Vector2i) -> String:
	return String(_grid.get(c, ""))

func deposit_at(c: Vector2i) -> int:
	var o := owner_at(c)
	return int(o.substr(4)) if o.begins_with("dep:") else -1

func building_at(c: Vector2i) -> Dictionary:
	var o := owner_at(c)
	if not o.begins_with("b:"):
		return {}
	return by_id(int(o.substr(2)))

func by_id(id: int) -> Dictionary:
	for b: Dictionary in buildings:
		if b.id == id:
			return b
	return {}

# --- the hands ---

## A tap on a deposit: one ore off it, into the stock.
func dig(c: Vector2i) -> bool:
	var i := deposit_at(c)
	if i < 0:
		return false
	var res := String(DEPOSITS[i][0])
	if not is_live(i):
		events.append({"type": "locked", "res": res, "dep": i})
		return false
	var item := res + "_ore"
	stock[item] = int(stock.get(item, 0)) + 1
	mined += 1
	events.append({"type": "dig", "res": res, "dep": i, "item": item})
	return true

func affordable(kind: String) -> bool:
	for item: String in COSTS[kind]:
		if int(stock.get(item, 0)) < int(COSTS[kind][item]):
			return false
	return true

## Why `kind` cannot stand with its top-left at `c`: "" when it can.
func place_refusal(kind: String, c: Vector2i) -> String:
	var r := Rect2i(c, SIZES[kind])
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var cell := Vector2i(x, y)
			if not in_bounds(cell):
				return "edge"
			if is_water(cell):
				return "water"
			if owner_at(cell) != "":
				return "taken"
	if not affordable(kind):
		return "cost"
	return ""

func place(kind: String, c: Vector2i) -> bool:
	var why := place_refusal(kind, c)
	if why != "":
		events.append({"type": "refused", "why": why, "kind": kind, "cell": c})
		return false
	for item: String in COSTS[kind]:
		stock[item] = int(stock[item]) - int(COSTS[kind][item])
	var b := {"id": _next_id, "kind": kind, "cell": c, "hopper": 0, "shelf": 0, "prog": 0.0}
	_next_id += 1
	buildings.append(b)
	_claim(b)
	events.append({"type": "placed", "kind": kind, "id": b.id, "cell": c})
	return true

## A tap on a kiln: its ingots into the stock, and its hopper topped up
## from the stock's ore.
func tend(id: int) -> void:
	var b := by_id(id)
	if b.is_empty():
		return
	var got := int(b.shelf)
	if got > 0:
		b.shelf = 0
		stock["iron_ingot"] = int(stock.get("iron_ingot", 0)) + got
		events.append({"type": "collect", "id": id, "n": got, "item": "iron_ingot"})
	var room := HOPPER - int(b.hopper)
	var put := mini(room, int(stock.get("iron_ore", 0)))
	if put > 0:
		b.hopper += put
		stock["iron_ore"] -= put
		events.append({"type": "load", "id": id, "n": put})
	if got == 0 and put == 0:
		events.append({"type": "idle", "id": id, "why": "full" if room == 0 else "no_ore"})

## The eraser: the building goes and everything it cost or held comes back.
func remove(id: int) -> void:
	var b := by_id(id)
	if b.is_empty():
		return
	for item: String in COSTS[b.kind]:
		stock[item] = int(stock.get(item, 0)) + int(COSTS[b.kind][item])
	stock["iron_ore"] += int(b.hopper)
	stock["iron_ingot"] += int(b.shelf)
	buildings.erase(b)
	_index()
	events.append({"type": "removed", "kind": b.kind, "id": id, "cell": b.cell})

func milestone_need() -> Dictionary:
	return MILESTONES[milestone].need if milestone < MILESTONES.size() else {}

func can_hand_in() -> bool:
	var need := milestone_need()
	if need.is_empty():
		return false
	for item: String in need:
		if int(stock.get(item, 0)) < int(need[item]):
			return false
	return true

func hand_in() -> bool:
	if not can_hand_in():
		events.append({"type": "refused", "why": "milestone"})
		return false
	var need := milestone_need()
	for item: String in need:
		stock[item] -= int(need[item])
	milestone += 1
	if milestone >= MILESTONES.size() and done_t == 0.0:
		done_t = t
	events.append({"type": "milestone", "index": milestone - 1, "done": milestone >= MILESTONES.size()})
	return true

func finished() -> bool:
	return milestone >= MILESTONES.size()

# --- time ---

func step() -> void:
	t += DT
	for b: Dictionary in buildings:
		if b.kind != "kiln":
			continue
		if int(b.hopper) <= 0 or int(b.shelf) >= SHELF:
			continue
		b.prog += DT
		if b.prog >= SMELT:
			b.prog -= SMELT
			b.hopper -= 1
			b.shelf += 1
			smelted += 1
			events.append({"type": "smelt", "id": b.id})

## What a kiln is doing: "work", "no_ore" or "full".
static func kiln_state(b: Dictionary) -> String:
	if int(b.shelf) >= SHELF:
		return "full"
	if int(b.hopper) <= 0:
		return "no_ore"
	return "work"

# --- the save ---

func to_dict() -> Dictionary:
	var bs := []
	for b: Dictionary in buildings:
		bs.append({"id": b.id, "kind": b.kind, "x": b.cell.x, "y": b.cell.y, "hopper": b.hopper, "shelf": b.shelf, "prog": b.prog})
	return {"v": SAVE_VERSION, "t": t, "stock": stock.duplicate(), "buildings": bs, "milestone": milestone,
		"done_t": done_t, "mined": mined, "smelted": smelted, "next_id": _next_id}

static func from_dict(d: Dictionary) -> RefCounted:
	var s = load("res://arcade/millstream_sim.gd").new()
	if int(d.get("v", 0)) != SAVE_VERSION:
		return s
	s.t = float(d.get("t", 0.0))
	for item: String in (d.get("stock", {}) as Dictionary):
		s.stock[item] = int(d.stock[item])
	for e: Dictionary in d.get("buildings", []):
		s.buildings.append({"id": int(e.id), "kind": String(e.kind), "cell": Vector2i(int(e.x), int(e.y)),
			"hopper": int(e.hopper), "shelf": int(e.shelf), "prog": float(e.prog)})
	s.milestone = int(d.get("milestone", 0))
	s.done_t = float(d.get("done_t", 0.0))
	s.mined = int(d.get("mined", 0))
	s.smelted = int(d.get("smelted", 0))
	s._next_id = int(d.get("next_id", 1))
	s._index()
	return s
