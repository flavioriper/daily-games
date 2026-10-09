extends RefCounted

## Toy Boats, as pure data: one player's pond. Ten by ten, five boats of 5, 4,
## 3, 3 and 2 squares lying along a row or a column, never on top of one
## another (side by side is allowed); a pebble a turn at a square not tried
## before, answered miss or hit, and a boat with every square hit is sunk and
## said so, with which boat it was. A fleet with all five sunk has lost.
##
## One class serves both sides of the water. A pond whose boats are all known
## is a player's own: `fire` answers a pebble. A pond whose boats are unknown
## (x < 0) is what a player has learned of the other's -- the slate: `note`
## writes an answer down and refuses one that cannot be true of what is
## already written, and `agrees` checks a whole fleet, shown at the end,
## against every answer that was given.
##
## Online nobody but its owner knows a fleet, so before the first pebble each
## end sends `seal(boats, salt)` and at the end the fleet and the salt
## themselves: a fleet moved in mid-game no longer has its seal.

const N := 10
const CELLS := N * N
## The boats' lengths, longest first; a boat is known by its index here.
const FLEET := [5, 4, 3, 3, 2]
enum { UNKNOWN, MISS, HIT }
## What a pebble did (HIT and MISS as above).
const SUNK := 3
## A pebble at a square already tried: no answer at all.
const NONE := -1
## A boat not known: where it lies has not been learned.
const HIDDEN := Vector3i(-1, -1, 0)

## A boat is Vector3i(x, y, dir): its first square and whether it runs east
## (0) or south (1) from there.
var boats: Array[Vector3i] = []
var sunk: Array[bool] = []
var marks := PackedByteArray()
## Pebbles thrown at this pond.
var shots := 0

func _init() -> void:
	marks.resize(CELLS)
	for i in FLEET.size():
		boats.append(HIDDEN)
		sunk.append(false)

func copy() -> RefCounted:
	var c: RefCounted = get_script().new()
	c.boats = boats.duplicate()
	c.sunk = sunk.duplicate()
	c.marks = marks.duplicate()
	c.shots = shots
	return c

static func cell(x: int, y: int) -> int:
	return y * N + x

static func xy(c: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(c % N, c / N)

static func step(dir: int) -> Vector2i:
	return Vector2i(1, 0) if dir == 0 else Vector2i(0, 1)

## Whether boat `i` laid as `b` is on the pond whole.
static func fits(i: int, b: Vector3i) -> bool:
	if b.z != 0 and b.z != 1:
		return false
	var end := Vector2i(b.x, b.y) + step(b.z) * (int(FLEET[i]) - 1)
	return b.x >= 0 and b.y >= 0 and end.x < N and end.y < N

## The squares boat `i` covers laid as `b`, bow first.
static func cells_of(i: int, b: Vector3i) -> PackedInt32Array:
	var out := PackedInt32Array()
	var d := step(b.z)
	for k in int(FLEET[i]):
		out.append(cell(b.x + d.x * k, b.y + d.y * k))
	return out

## Whether `fleet` is five boats on the pond, none over another.
static func valid(fleet: Array) -> bool:
	if fleet.size() != FLEET.size():
		return false
	var taken := {}
	for i in fleet.size():
		if typeof(fleet[i]) != TYPE_VECTOR3I or not fits(i, fleet[i]):
			return false
		for c in cells_of(i, fleet[i]):
			if taken.has(c):
				return false
			taken[c] = true
	return true

## Whether boat `i` could lie as `b` beside the rest of `fleet` (its own old
## place does not count).
static func free_for(fleet: Array, i: int, b: Vector3i) -> bool:
	if not fits(i, b):
		return false
	var mine := cells_of(i, b)
	for j in fleet.size():
		if j == i or (fleet[j] as Vector3i).x < 0:
			continue
		for c in cells_of(j, fleet[j]):
			if mine.has(c):
				return false
	return true

## A fleet laid by chance. `apart` keeps the boats from touching, sides and
## corners both, which is how a careful player lays them.
static func random_fleet(rng: RandomNumberGenerator, apart := false) -> Array[Vector3i]:
	while true:
		var fleet: Array[Vector3i] = []
		var taken := {}
		var ok := true
		for i in FLEET.size():
			var placed := false
			for attempt in 200:
				var b := Vector3i(rng.randi_range(0, N - 1), rng.randi_range(0, N - 1), rng.randi_range(0, 1))
				if not fits(i, b):
					continue
				var clear := true
				for c in cells_of(i, b):
					if taken.has(c):
						clear = false
						break
				if not clear:
					continue
				fleet.append(b)
				for c in cells_of(i, b):
					var at := xy(c)
					for dy: int in (range(-1, 2) if apart else [0]):
						for dx: int in (range(-1, 2) if apart else [0]):
							var q := at + Vector2i(dx, dy)
							if q.x >= 0 and q.y >= 0 and q.x < N and q.y < N:
								taken[cell(q.x, q.y)] = true
				placed = true
				break
			if not placed:
				ok = false
				break
		if ok:
			return fleet
	return []

## Lays `fleet` on this pond (a player's own).
func lay(fleet: Array) -> void:
	for i in FLEET.size():
		boats[i] = fleet[i]

## The boat on square `c`, -1 for open water (or a boat not known).
func boat_at(c: int) -> int:
	for i in boats.size():
		if boats[i].x >= 0 and cells_of(i, boats[i]).has(c):
			return i
	return -1

## A pebble at `c` on a pond whose boats are known: {r, boat}. r is MISS, HIT
## or SUNK (NONE for a square already tried); boat is the one struck, -1 for a
## miss.
func fire(c: int) -> Dictionary:
	if c < 0 or c >= CELLS or marks[c] != UNKNOWN:
		return {"r": NONE, "boat": -1}
	shots += 1
	var i := boat_at(c)
	if i < 0:
		marks[c] = MISS
		return {"r": MISS, "boat": -1}
	marks[c] = HIT
	for q in cells_of(i, boats[i]):
		if marks[q] != HIT:
			return {"r": HIT, "boat": i}
	sunk[i] = true
	return {"r": SUNK, "boat": i}

## Writes down the answer to a pebble at `c` on a pond not known: `r`, and
## for SUNK which boat and how it lay. False, and nothing written, for an
## answer that cannot be: a square tried before, a boat already sunk or off
## the pond, one that does not pass through `c`, or one with a square that
## was not a hit (or was another sunk boat's).
func note(c: int, r: int, i := -1, b := HIDDEN) -> bool:
	if c < 0 or c >= CELLS or marks[c] != UNKNOWN:
		return false
	if r == MISS or r == HIT:
		marks[c] = r
		shots += 1
		return true
	if r != SUNK or i < 0 or i >= FLEET.size() or sunk[i] or not fits(i, b):
		return false
	var cells := cells_of(i, b)
	if not cells.has(c):
		return false
	for q in cells:
		if q != c and (marks[q] != HIT or boat_at(q) >= 0):
			return false
	marks[c] = HIT
	shots += 1
	boats[i] = b
	sunk[i] = true
	return true

func all_sunk() -> bool:
	return not sunk.has(false)

## Boats still afloat.
func afloat() -> int:
	return sunk.count(false)

## Hits on boats not yet sunk: where a boat is known to be and is not done.
func open_hits() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in CELLS:
		if marks[c] == HIT and boat_at(c) < 0:
			out.append(c)
	return out

## Whether `fleet`, shown at the end, is the one every answer written on this
## slate was given for: a miss where it has open water, a hit where it has a
## boat, each boat said sunk lying where it was said to and no boat with
## every square hit left unsaid.
func agrees(fleet: Array) -> bool:
	if not valid(fleet):
		return false
	var on := {}
	for i in fleet.size():
		var whole := true
		for c in cells_of(i, fleet[i]):
			on[c] = true
			if marks[c] != HIT:
				whole = false
		if whole != sunk[i] or (sunk[i] and boats[i] != fleet[i]):
			return false
	for c in CELLS:
		if marks[c] != UNKNOWN and (marks[c] == HIT) != on.has(c):
			return false
	return true

# --- the wire ---

## A fleet as text, the same on every device: "x y d" a boat, in the fleet's
## order.
static func pack(fleet: Array) -> String:
	var parts := PackedStringArray()
	for b: Vector3i in fleet:
		parts.append("%d%d%d" % [b.x, b.y, b.z])
	return ".".join(parts)

## The fleet `text` packs, empty for text that is not a fleet on the pond.
static func unpack(text: String) -> Array[Vector3i]:
	var fleet: Array[Vector3i] = []
	var parts := text.split(".")
	if parts.size() != FLEET.size():
		return []
	for p in parts:
		if p.length() != 3 or not p.is_valid_int() or p.begins_with("-") or p.begins_with("+"):
			return []
		fleet.append(Vector3i(int(p[0]), int(p[1]), int(p[2])))
	return fleet if valid(fleet) else ([] as Array[Vector3i])

## What is sent before the first pebble in place of the fleet itself.
static func seal(fleet: Array, salt: String) -> String:
	return (salt + "|" + pack(fleet)).sha256_text()
