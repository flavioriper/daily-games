extends "res://puzzles/pixel_garden_state.gd"

## Glimpse's rules: Pixel Garden's pegboard, kit and plates as they are, on a
## small picture made for the day instead of one from the bank. The picture
## is shown for a few seconds and then hidden (puzzles/glimpse2d.gd), so the
## player copies it from memory; this file only makes the picture and counts
## how many of its beads went down right the first time.
##
## **The picture is a little sprite**: one blob grown cell by cell on the
## left half of the board and mirrored onto the right, so it reads as a thing
## (a bug, a lantern, a face) and is easier to hold in mind than noise. Its
## colours are patches, each grown from a seed over the blob, mirrored too.
## Each band is a size, a number of colours and of beads (`BANDS`); the
## day's rng picks the rest, so the four bands are four dailies.
##
## **First try** (`first`): the colour of the first bead ever seated on each
## peg, kept through undo, Try again and the iron sending a bead home. A peg
## the picture wants counts as right when that first bead was its colour.
## Spec: docs/superpowers/specs/2026-10-22-glimpse-design.md.

## Per band: the pegs a side, the colours, and the beads the picture holds
## (even: half of them are drawn and mirrored).
const BANDS := [
	{"n": 6, "colours": 2, "beads": 8},
	{"n": 6, "colours": 3, "beads": 12},
	{"n": 8, "colours": 3, "beads": 16},
	{"n": 8, "colours": 4, "beads": 22},
]
## The bead colours a day may use: far apart from each other, none pale
## enough to be lost on the plate.
const COLOURS := ["red", "yellow", "blue", "green", "purple", "orange", "pink", "teal", "brown", "sky"]

## The first bead seated on each peg, EMPTY until one is.
var first := PackedInt32Array()
## The day's picture's own palette, which stands in for the bank's.
var _legend := {}

func setup(rng: RandomNumberGenerator, difficulty: int, _bank_step := 0, _daily_key := 0) -> void:
	band = clampi(difficulty, 0, 3)
	var gen := RandomNumberGenerator.new()
	gen.seed = rng.randi()
	load_picture(make_picture(gen, band))
	_rng.seed = rng.randi()

## The day's picture as a bank entry ({"id", "name", "rows"}) for
## `load_picture`, with the colours named in its own "palette".
static func make_picture(gen: RandomNumberGenerator, b: int) -> Dictionary:
	var spec: Dictionary = BANDS[clampi(b, 0, 3)]
	var size: int = spec.n
	var w := size / 2
	var cells: int = int(spec.beads) / 2
	# The blob on the left half, grown from a cell beside the middle so the
	# mirror joins it into one shape.
	var shape := {}
	var start := Vector2i(w - 1, gen.randi_range(size / 2 - 1, size / 2))
	shape[start] = true
	var tries := 0
	while shape.size() < cells and tries < 4000:
		tries += 1
		var keys := shape.keys()
		var from: Vector2i = keys[gen.randi_range(0, keys.size() - 1)]
		var step: Vector2i = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][gen.randi_range(0, 3)]
		var to := from + step
		if to.x < 0 or to.x >= w or to.y < 0 or to.y >= size or shape.has(to):
			continue
		# A cell with three neighbours already in fills a hole: welcome. A
		# cell that would make a 2x2 block is taken half the time, so the
		# shape keeps some arms and gaps to remember it by.
		if _would_block(shape, to) and gen.randf() < 0.5:
			continue
		shape[to] = true
	# The blob stood in the middle of the board, top to foot.
	var top := size
	var foot := 0
	for c: Vector2i in shape:
		top = mini(top, c.y)
		foot = maxi(foot, c.y)
	var drop := (size - 1 - foot - top) / 2
	if drop != 0:
		var moved := {}
		for c: Vector2i in shape:
			moved[c + Vector2i(0, drop)] = true
		shape = moved
	# The patches: seeds spread over the blob, each cell taking the nearest.
	var list: Array = shape.keys()
	list.sort_custom(func(a: Vector2i, b2: Vector2i) -> bool: return a.y * 100 + a.x < b2.y * 100 + b2.x)
	var k: int = mini(int(spec.colours), list.size())
	var seeds: Array = []
	var pool := list.duplicate()
	for i in k:
		var pick: Vector2i = pool[gen.randi_range(0, pool.size() - 1)]
		if i > 0:
			# The farthest of three tries from the seeds so far.
			var best := -1.0
			for _t in 3:
				var c: Vector2i = pool[gen.randi_range(0, pool.size() - 1)]
				var near := INF
				for s: Vector2i in seeds:
					near = minf(near, Vector2(c - s).length())
				if near > best:
					best = near
					pick = c
		seeds.append(pick)
		pool.erase(pick)
	var names: Array = COLOURS.duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := gen.randi_range(0, i)
		var t = names[i]; names[i] = names[j]; names[j] = t
	var patch := {}
	for c: Vector2i in list:
		var best_i := 0
		var best_d := INF
		for i in seeds.size():
			var d := Vector2(c - seeds[i]).length() + gen.randf() * 0.6
			if d < best_d:
				best_d = d
				best_i = i
		patch[c] = best_i
	var letters := "abcdefghij"
	var palette := {}
	for i in k:
		palette[letters[i]] = names[i]
	var rows: Array = []
	for y in size:
		var row := ""
		for x in size:
			var mx := x if x < w else size - 1 - x
			var c := Vector2i(mx, y)
			row += letters[int(patch[c])] if shape.has(c) else "."
		rows.append(row)
	return {"id": "glimpse", "name": "GL_PIC", "rows": rows, "palette": palette}

static func _would_block(shape: Dictionary, c: Vector2i) -> bool:
	for d in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		var o: Vector2i = c + d
		var full := true
		for e in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var p: Vector2i = o + e
			if p != c and not shape.has(p):
				full = false
				break
		if full:
			return true
	return false

func load_picture(pic: Dictionary) -> void:
	_legend = pic.get("palette", {})
	super(pic)
	first = PackedInt32Array()
	first.resize(n * n)
	first.fill(EMPTY)

func _palette() -> Dictionary:
	return _legend

func _seat(c: int, to: int) -> void:
	if to != EMPTY and first.size() == size() and first[c] == EMPTY:
		first[c] = to
	super(c, to)

## A bead of colour `k` refused on peg `c` (glimpse2d.gd judges each one as
## it goes down): it was the peg's first try, so it is kept as one.
func miss(c: int, k: int) -> void:
	if first.size() == size() and first[c] == EMPTY:
		first[c] = k

## How many of the picture's beads went down right the first time.
func first_right() -> int:
	var k := 0
	for c in size():
		if want[c] != EMPTY and first[c] == want[c]:
			k += 1
	return k
