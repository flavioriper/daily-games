extends RefCounted

## Pixel Garden's rules, with no scene under them: the day's picture, the
## beads the player has seated on the pegboard, the kit's count of each
## colour, and every move that can change them. puzzles/pixel_garden2d.gd
## draws this and nothing else.
##
## **The kit holds exactly the beads the picture needs**, and that is the one
## rule beyond "copy it": a colour whose beads are all on the board can seat
## no more until one is lifted. So a bead in the wrong place is felt as a
## colour that runs out before its shape is finished -- a nudge the player
## finds on their own -- and never as a counter that answers each bead, which
## would give the picture away one peg at a time. The progress bar counts
## beads seated, right or wrong, for the same reason.
##
## A stroke is one move however many pegs it crossed (Nonogram's rule), so
## the history keeps a list of pegs a stroke. The pictures are hand-drawn and
## banked in content/pixel_garden.json, never generated.
## Spec: docs/superpowers/specs/2026-09-27-pixel-garden-flat-design.md.

const Pal = preload("res://core/palette.gd")

const BANK := "res://content/pixel_garden.json"
const EMPTY := -1
const HINTS := 3

## The bank, read once.
static var _bank: Dictionary = {}

var n: int = 0
var pic_id := ""
## The picture's name, a locale key (boards.csv's PG_PIC_*).
var pic_name := ""
## The day's colours, in the order the chips stand: their names in the
## palette (Pal.PG_BEADS) and their colours.
var names: Array[String] = []
var colours: Array[Color] = []
## Per peg, row-major: the colour index the picture wants (EMPTY for bare),
## the bead seated there (EMPTY for none), and whether a hint fused it.
var want := PackedInt32Array()
var beads := PackedInt32Array()
var locked := PackedByteArray()
## How many beads of each colour the picture takes, and how many are seated.
var need := PackedInt32Array()
var seated := PackedInt32Array()
var target := 0
## One entry per stroke, newest last: [[peg, prev], ...].
var history: Array = []
var _stroke: Array = []
var _in_stroke := false
var _rng := RandomNumberGenerator.new()

static func bank() -> Dictionary:
	if _bank.is_empty():
		# PG_BANK, in a debug build, points a harness at another bank.
		var path := BANK
		if OS.is_debug_build() and OS.has_environment("PG_BANK"):
			path = OS.get_environment("PG_BANK")
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_bank = parsed
	return _bank

static func band_pictures(difficulty: int) -> Array:
	var bands: Array = bank().get("bands", [])
	if bands.is_empty():
		return []
	return bands[clampi(difficulty, 0, bands.size() - 1)]

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	var pics := band_pictures(difficulty)
	if pics.is_empty():
		return
	load_picture(pics[rng.randi() % pics.size()])
	_rng.seed = rng.randi()

## Takes `pic` (one entry of the bank) as the day's picture, on a bare board.
func load_picture(pic: Dictionary) -> void:
	var legend: Dictionary = bank().get("palette", {})
	var rows: Array = pic.get("rows", [])
	n = rows.size()
	pic_id = String(pic.get("id", ""))
	pic_name = String(pic.get("name", ""))
	names = []
	colours = []
	want = PackedInt32Array()
	want.resize(n * n)
	want.fill(EMPTY)
	# The chips stand in the order the palette lists its colours, so a day's
	# reds sit beside its oranges whatever order the picture met them in.
	var used := {}
	for row: String in rows:
		for ch in row:
			if ch != ".":
				used[ch] = true
	var order: Array = Pal.PG_BEADS.keys()
	var index := {}
	for nm: String in order:
		for ch: String in used:
			if String(legend.get(ch, "")) == nm and not index.has(ch):
				index[ch] = names.size()
				names.append(nm)
				colours.append(Pal.PG_BEADS[nm])
	for y in n:
		var row: String = rows[y]
		for x in mini(n, row.length()):
			var ch := row[x]
			if index.has(ch):
				want[y * n + x] = int(index[ch])
	need = PackedInt32Array()
	need.resize(names.size())
	need.fill(0)
	target = 0
	for v in want:
		if v != EMPTY:
			need[v] += 1
			target += 1
	beads = PackedInt32Array()
	beads.resize(n * n)
	beads.fill(EMPTY)
	locked = PackedByteArray()
	locked.resize(n * n)
	seated = PackedInt32Array()
	seated.resize(names.size())
	seated.fill(0)
	history = []
	_stroke = []
	_in_stroke = false

# --- reading ---

func size() -> int:
	return n * n

func left(k: int) -> int:
	return need[k] - seated[k]

func placed() -> int:
	var total := 0
	for v in seated:
		total += v
	return total

func is_solved() -> bool:
	return n > 0 and beads == want

## Every seated bead the picture does not want where it is.
func wrong() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in size():
		if beads[c] != EMPTY and beads[c] != want[c]:
			out.append(c)
	return out

func can_undo() -> bool:
	return not history.is_empty()

# --- moves ---

func begin_stroke() -> void:
	_stroke = []
	_in_stroke = true

## Seats bead `to` (EMPTY lifts) on peg `c`, as part of the stroke in hand.
## Returns "put", "same" (nothing to do), "locked" (a hint fused it) or
## "none_left" (the kit has no more of that colour).
func put(c: int, to: int) -> String:
	if beads[c] == to:
		return "same"
	if locked[c] == 1:
		return "locked"
	if to != EMPTY and left(to) <= 0:
		return "none_left"
	var prev := beads[c]
	_seat(c, to)
	if _in_stroke:
		_stroke.append([c, prev])
	else:
		history.append([[c, prev]])
	return "put"

## Closes the stroke in hand as one entry of the history. Returns the pegs it
## changed.
func end_stroke() -> PackedInt32Array:
	_in_stroke = false
	var out := PackedInt32Array()
	if _stroke.is_empty():
		return out
	history.append(_stroke)
	for e in _stroke:
		out.append(int(e[0]))
	_stroke = []
	return out

func _seat(c: int, to: int) -> void:
	var prev := beads[c]
	if prev != EMPTY:
		seated[prev] -= 1
	if to != EMPTY:
		seated[to] += 1
	beads[c] = to

## Takes back the last stroke. Returns the pegs, last changed first.
func undo() -> PackedInt32Array:
	var out := PackedInt32Array()
	if history.is_empty():
		return out
	var entry: Array = history.pop_back()
	for i in range(entry.size() - 1, -1, -1):
		var c := int(entry[i][0])
		# A hint may have fused this peg since; the hint wins.
		if locked[c] == 0:
			_seat(c, int(entry[i][1]))
			out.append(c)
	return out

## The hint: lifts a bead that is out of place if there is one, else seats a
## bead the picture wants, and fuses that peg for good. Either way the peg
## ends as the picture has it. Returns {"peg", "was"} or {} with nothing
## left to fix. What came before in the history still describes the board
## except the one peg the hint took over.
func hint() -> Dictionary:
	var pool := wrong()
	if pool.is_empty():
		for c in size():
			if want[c] != EMPTY and beads[c] != want[c]:
				pool.append(c)
	if pool.is_empty():
		return {}
	var c := pool[_rng.randi() % pool.size()]
	var was := beads[c]
	# A wrong bead whose right colour is bare (a bare peg) is lifted; else the
	# peg takes its colour. If the kit's last bead of that colour sits on a
	# wrong peg elsewhere, that one goes back to the kit to make room.
	var to := want[c]
	if to != EMPTY and left(to) <= 0 and beads[c] != to:
		for o in size():
			if o != c and locked[o] == 0 and beads[o] == to and want[o] != to:
				_seat(o, EMPTY)
				_forget(o)
				break
	if to != EMPTY and left(to) <= 0 and beads[c] != to:
		return {}
	_seat(c, to)
	locked[c] = 1
	_forget(c)
	return {"peg": c, "was": was}

func _forget(c: int) -> void:
	var kept: Array = []
	for entry: Array in history:
		var rest: Array = []
		for e in entry:
			if int(e[0]) != c:
				rest.append(e)
		if not rest.is_empty():
			kept.append(rest)
	history = kept

## Every bead off the board but the ones a hint fused. Returns the pegs
## cleared.
func reset() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in size():
		if beads[c] != EMPTY and locked[c] == 0:
			_seat(c, EMPTY)
			out.append(c)
	history = []
	return out

## Seats the whole picture, for a daily reopened after it was solved.
func fill() -> void:
	for c in size():
		_seat(c, want[c])
	history = []

## The finished picture in coloured squares, the nearest of the nine a phone
## has to each bead, on a white ground.
func share_glyphs() -> String:
	var squares := {"🟥": Color("e0503a"), "🟧": Color("f08a2c"), "🟨": Color("f4c640"),
		"🟩": Color("5fa845"), "🟦": Color("4a7fc1"), "🟪": Color("7e5aa6"),
		"🟫": Color("8a5a36"), "⬛": Color("3b3028"), "⬜": Color("f6f2ea")}
	var glyph: Array[String] = []
	for col in colours:
		var best := "⬜"
		var near := INF
		for s: String in squares:
			var o: Color = squares[s]
			var d := Vector3(col.r - o.r, col.g - o.g, col.b - o.b).length_squared()
			if d < near:
				near = d
				best = s
		glyph.append(best)
	var out := ""
	for y in n:
		for x in n:
			var v := want[y * n + x]
			out += "▫️" if v == EMPTY else glyph[v]
		out += "\n"
	return out.strip_edges(false, true)
