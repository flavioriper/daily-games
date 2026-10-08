extends RefCounted

## Horse Pen's rules as the board plays them, scene-free, as every flat
## board's are. The board (puzzles/horse2d.gd) draws this and nothing else.
##
## One move: a hay bale dropped on a bare grass cell, or one lifted again.
## The horse walks up, down, left and right, never through a bale, a boulder
## or water, and a tunnel's two mouths are one step apart. The pen is closed
## when the horse can no longer reach an edge cell. Every cell it can still
## reach scores one, an apple three more, the golden apple ten more, a
## beehive five fewer. The day is done when a closed pen worth the target is
## submitted; until then the player may keep rebuilding for a bigger one.
##
## No band has hearts. Insane counts moves (docs/agents/flat-screens.md,
## "Insane counts moves"): a bale laid or lifted costs one, and the stock is
## the answer's bales and three more.

const Gen = preload("res://puzzles/horse_gen.gd")

const BANK := "res://content/horse.json"
const HINTS_BY := [3, 3, 2, 0]
## Insane's spare moves over the stock of bales (`moves_budget`).
const MOVES_SLACK := [0, 0, 0, 3]

## What a tap or Submit came to.
enum { OK, REFUSED_FIXED, REFUSED_STOCK, REFUSED_PINNED, OPEN, SMALL }

static var _bank: Array = []
static var _bank_read := false

var m := {}
var band := 0
var w := 0
var h := 0
var horse := -1
var budget := 0
var best := 0
var target := 0
## A byte a cell: 1 where a bale stands.
var walls := PackedByteArray()
## The bales a hint dropped, which stay: cell -> true.
var pinned: Dictionary = {}
## The order the bales standing were laid in, for the win's wave.
var laid: Array[int] = []
## Every move, for Undo: [cell, 1 laid / 0 lifted].
var history: Array = []
var submitted := false
var _reach := {}

## The band's pool of mined meadows, [] when the bank is missing.
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

## The day's meadow out of the bank; without one the phone lays its own.
func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	band = clampi(difficulty, 0, Gen.BANDS.size() - 1)
	m = {}
	var meadows := pool(band)
	if not meadows.is_empty():
		m = Gen.unpack(meadows[rng.randi_range(0, meadows.size() - 1)])
	if m.is_empty():
		m = Gen.generate(rng, band)
	adopt(m)

## Plays `meadow` (prepared, with its `budget`, `best` and `sol`).
func adopt(meadow: Dictionary) -> void:
	m = meadow
	w = int(m.w)
	h = int(m.h)
	horse = int(m.horse)
	budget = int(m.budget)
	best = int(m.best)
	target = Gen.target_for(best, band)
	reset()

## The field bare again. Returns the cells that had a bale.
func reset() -> Array:
	var had: Array = []
	for i in walls.size():
		if walls[i] == 1:
			had.append(i)
	walls = PackedByteArray()
	walls.resize(w * h)
	pinned = {}
	laid = []
	history = []
	submitted = false
	_reach = {}
	return had

func cells() -> int:
	return w * h

func xy(i: int) -> Vector2i:
	return Vector2i(i % w, i / w)

func at(c: Vector2i) -> int:
	return c.y * w + c.x if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h else -1

func is_water(i: int) -> bool: return m.block[i] == Gen.WATER
func is_stone(i: int) -> bool: return m.block[i] == Gen.STONE
func item(i: int) -> int: return m.item[i]
func twin(i: int) -> int: return m.twin[i]
func has_bale(i: int) -> bool: return walls[i] == 1
## Whether a bale may stand on `i` at all: bare grass only.
func bare(i: int) -> bool: return m.bare[i] == 1

func bales() -> int:
	return laid.size()

func bales_left() -> int:
	return budget - laid.size()

func has_items() -> bool:
	return (m.item as PackedByteArray).count(Gen.APPLE) > 0

func has_gold() -> bool:
	return (m.item as PackedByteArray).count(Gen.GOLD) > 0

func has_bees() -> bool:
	return (m.item as PackedByteArray).count(Gen.BEE) > 0

func has_tunnels() -> bool:
	return not (m.tunnels as Array).is_empty()

## Where the horse can get to now (horse_gen.gd's `reach`), kept until a bale
## moves.
func reach() -> Dictionary:
	if _reach.is_empty():
		_reach = Gen.reach(m, walls)
	return _reach

func closed() -> bool:
	return (reach().gaps as PackedInt32Array).is_empty()

## What the pen is worth, 0 while it is open.
func score() -> int:
	return int(reach().score) if closed() else 0

## The cells the horse can reach, whether or not the pen is closed.
func roam() -> int:
	return (reach().order as PackedInt32Array).size()

func moves_budget() -> int:
	return budget + MOVES_SLACK[band] if MOVES_SLACK[band] > 0 else 0

## Lays a bale on `i` or lifts the one there. OK, or why not.
func tap(i: int) -> int:
	if submitted or i < 0:
		return REFUSED_FIXED
	if walls[i] == 1:
		if pinned.has(i):
			return REFUSED_PINNED
		_put(i, false)
		history.append([i, 0])
		return OK
	if not bare(i):
		return REFUSED_FIXED
	if bales_left() <= 0:
		return REFUSED_STOCK
	_put(i, true)
	history.append([i, 1])
	return OK

func _put(i: int, on: bool) -> void:
	walls[i] = 1 if on else 0
	if on:
		laid.append(i)
	else:
		laid.erase(i)
	_reach = {}

## Takes the last move back. The cell it changed, or -1.
func undo() -> int:
	while not history.is_empty():
		var last: Array = history.pop_back()
		var i: int = last[0]
		# A bale a hint has since pinned stays where it is.
		if pinned.has(i):
			continue
		if (last[1] == 1) != (walls[i] == 1):
			continue
		_put(i, last[1] == 0)
		return i
	return -1

## One bale of the answer, pinned: {"cell": the bale, "lifted": a bale of the
## player's own taken up to pay for it, or -1}. {} when the answer already
## stands.
func hint() -> Dictionary:
	var want := -1
	var sol: Array = m.sol
	# The answer's bale nearest the horse's reach first: the one that closes
	# a gap the player can see.
	var seen: PackedByteArray = reach().seen
	for i: int in sol:
		if walls[i] == 1:
			continue
		if want < 0:
			want = i
		if _touches(i, seen):
			want = i
			break
	if want < 0:
		return {}
	var lifted := -1
	if bales_left() <= 0:
		for i in laid:
			if not pinned.has(i) and not sol.has(i):
				lifted = i
				break
		if lifted < 0:
			return {}
		_put(lifted, false)
	_put(want, true)
	pinned[want] = true
	return {"cell": want, "lifted": lifted}

func _touches(i: int, seen: PackedByteArray) -> bool:
	for k: int in m.nb[i]:
		if seen[k] == 1:
			return true
	return false

## Submit: OPEN while the horse can still get out, SMALL when the pen is
## closed under the target, OK when the day is done.
func submit() -> int:
	if not closed():
		return OPEN
	if score() < target:
		return SMALL
	submitted = true
	return OK

func is_solved() -> bool:
	return submitted

## The answer's bales laid and submitted, for a day reopened already played
## when its own bales were not kept.
func finish(with: Array = []) -> void:
	reset()
	for i in (with if not with.is_empty() else m.sol):
		if int(i) >= 0 and int(i) < walls.size() and bare(int(i)) and walls[int(i)] == 0:
			_put(int(i), true)
	submitted = true

## The field as emoji, a row a line.
func share_glyphs() -> String:
	var seen: PackedByteArray = reach().seen
	var out := ""
	for i in cells():
		var ch := "🟩"
		if i == horse: ch = "🐴"
		elif walls[i] == 1: ch = "🟫"
		elif is_water(i): ch = "🟦"
		elif is_stone(i): ch = "⬜"
		elif seen[i] == 1: ch = "🟨"
		out += ch
		if i % w == w - 1 and i < cells() - 1:
			out += "\n"
	return out
