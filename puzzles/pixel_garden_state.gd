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
##
## **The board is four plates** (2026-10-01 polish), as a real big pegboard
## is four small ones clipped together. A plate whose beads are all on it --
## as many as the picture puts there -- is ironed at once: right, and it is
## fused for good; wrong, and the beads astray hop back into the box (and on
## Hard and Insane it costs a heart, which the board keeps). On Insane,
## Windblown, the pattern card's four squares have blown about: each shows
## somewhere else, turned (`perm`, `turn`), and the board must still be the
## true picture.
## Spec: docs/superpowers/specs/2026-09-27-pixel-garden-flat-design.md and
## docs/superpowers/specs/2026-10-01-pixel-garden-polish-design.md.

const Pal = preload("res://core/palette.gd")

const BANK := "res://content/pixel_garden.json"
const EMPTY := -1
const HINTS := 3
## Hints and hearts by band: Hard trades a hint for hearts, Insane has
## neither hints nor Check -- only the iron judges.
const HINTS_BY := [3, 3, 2, 0]
const HEARTS_BY := [0, 0, 3, 2]
const WINDBLOWN := 3
## `locked` holds HINTED for a peg a hint put right, FUSED for one an iron
## fused with its plate; Try again keeps a hint's and melts the rest.
const HINTED := 1
const FUSED := 2

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
var band := 0
## Half the board's side: a plate is half x half pegs. Plates are numbered
## row-major, 0 top left to 3 bottom right.
var half := 0
## How many beads the picture puts on each plate, and whether each is ironed.
var plate_need := PackedInt32Array([0, 0, 0, 0])
var ironed := PackedByteArray([0, 0, 0, 0])
## Windblown: the square the pattern card shows in place q is plate perm[q],
## turned turn[q] quarter turns clockwise. Identity elsewhere.
var perm := PackedInt32Array([0, 1, 2, 3])
var turn := PackedInt32Array([0, 0, 0, 0])

static func hints_for(difficulty: int) -> int:
	return HINTS_BY[clampi(difficulty, 0, 3)]

static func hearts_for(difficulty: int) -> int:
	return HEARTS_BY[clampi(difficulty, 0, 3)]

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
	band = clampi(difficulty, 0, 3)
	load_picture(pics[rng.randi() % pics.size()])
	_rng.seed = rng.randi()
	if band == WINDBLOWN:
		blow(rng)

## Windblown: shuffles where the pattern card shows each plate and turns
## each one, so that no square is left both in its own place and upright, and
## at least three are turned.
func blow(rng: RandomNumberGenerator) -> void:
	for _try in 64:
		var p := PackedInt32Array([0, 1, 2, 3])
		for i in range(3, 0, -1):
			var j := rng.randi() % (i + 1)
			var tmp := p[i]
			p[i] = p[j]
			p[j] = tmp
		var r := PackedInt32Array()
		var turned := 0
		var ok := true
		for q in 4:
			r.append(rng.randi() % 4)
			if r[q] != 0:
				turned += 1
			if p[q] == q and r[q] == 0:
				ok = false
		if ok and turned >= 3:
			perm = p
			turn = r
			return
	perm = PackedInt32Array([3, 2, 1, 0])
	turn = PackedInt32Array([1, 2, 3, 1])

func windblown() -> bool:
	return band == WINDBLOWN

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
	half = n / 2
	plate_need = PackedInt32Array([0, 0, 0, 0])
	for c in size():
		if want[c] != EMPTY:
			plate_need[plate_of(c)] += 1
	ironed = PackedByteArray([0, 0, 0, 0])
	perm = PackedInt32Array([0, 1, 2, 3])
	turn = PackedInt32Array([0, 0, 0, 0])
	# A plate the picture leaves bare has nothing to iron: it is done.
	for q in 4:
		if plate_need[q] == 0:
			_fuse_plate(q)

# --- the plates ---

func plate_of(c: int) -> int:
	return (2 if c / n >= half else 0) + (1 if c % n >= half else 0)

## Every peg of plate `q`, row-major.
func plate_pegs(q: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0 := (q % 2) * half
	var y0 := (q / 2) * half
	for y in half:
		for x in half:
			out.append((y0 + y) * n + x0 + x)
	return out

func plate_placed(q: int) -> int:
	var k := 0
	for c in plate_pegs(q):
		if beads[c] != EMPTY:
			k += 1
	return k

## Plates not yet ironed with as many beads on them as the picture puts
## there (or more): the iron's next work.
func plates_full() -> PackedInt32Array:
	var out := PackedInt32Array()
	for q in 4:
		if ironed[q] == 0 and plate_placed(q) >= plate_need[q]:
			out.append(q)
	return out

func plate_right(q: int) -> bool:
	for c in plate_pegs(q):
		if beads[c] != want[c]:
			return false
	return true

## Irons plate `q`: right, and every peg on it is fused for good; wrong, and
## every bead astray goes back to the kit. Returns {"ok", "astray": [[peg,
## colour], ...]}.
func iron_plate(q: int) -> Dictionary:
	if plate_right(q):
		_fuse_plate(q)
		return {"ok": true, "astray": []}
	var astray: Array = []
	for c in plate_pegs(q):
		if beads[c] != EMPTY and beads[c] != want[c] and locked[c] == 0:
			astray.append([c, beads[c]])
			_seat(c, EMPTY)
			_forget(c)
	return {"ok": false, "astray": astray}

func _fuse_plate(q: int) -> void:
	ironed[q] = 1
	for c in plate_pegs(q):
		if locked[c] == 0:
			locked[c] = FUSED
		_forget(c)

## The pattern card's square in place `q` at its own (u, v): which peg of the
## board it shows. Windblown turns square q by turn[q] quarter turns
## clockwise and shows plate perm[q] there.
func card_peg(q: int, u: int, v: int) -> int:
	var h := half
	var x := u
	var y := v
	match turn[q]:
		1:
			x = v
			y = h - 1 - u
		2:
			x = h - 1 - u
			y = h - 1 - v
		3:
			x = h - 1 - v
			y = u
	var p := perm[q]
	return ((p / 2) * h + y) * n + (p % 2) * h + x

## Try again: every bead back in the kit but what a hint fused; the plates
## un-ironed (a bare one stays done).
func restart() -> void:
	for c in size():
		if locked[c] == FUSED:
			locked[c] = 0
	for q in 4:
		ironed[q] = 0
	for c in size():
		if beads[c] != EMPTY and locked[c] == 0:
			_seat(c, EMPTY)
	history = []
	for q in 4:
		if plate_need[q] == 0:
			_fuse_plate(q)

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
## Returns "put", "same" (nothing to do), "locked" (a hint fused it),
## "taken" (another colour's bead is on it) or "none_left" (the kit has no
## more of that colour).
func put(c: int, to: int) -> String:
	if beads[c] == to:
		return "same"
	if locked[c] != 0:
		return "locked"
	# A peg holding another colour keeps it until that bead is lifted: a
	# finger sweeping a run never knocks off a bead it only brushed.
	if to != EMPTY and beads[c] != EMPTY:
		return "taken"
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
		# A hint or an iron may have fixed this peg since; it wins. And a bead
		# put back must still be in the kit: a later stroke the iron has
		# since taken over (forgotten) may hold it.
		var to := int(entry[i][1])
		if locked[c] == 0 and not (to != EMPTY and beads[c] != to and left(to) <= 0):
			_seat(c, to)
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
	for q in 4:
		_fuse_plate(q)
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
