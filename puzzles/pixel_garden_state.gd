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
## fused for good; wrong, and the beads astray hop back into the box.
##
## **Insane stopped counting moves on 2026-10-12** (`moves_budget` is 0 on
## every band); what follows is how it was.
## **No band has hearts since 2026-10-04**, and Insane counts moves instead
## (`moves_budget`, `move_cost`): there the board never calls the iron on a
## plate, so nothing says which bead is astray and nothing is taken off for
## the player. The iron still closes a picture that is right.
##
## **Big pictures (2026-10-11).** Hard's pictures are 24 pegs square and
## Insane's 32, filled scenes in up to twelve colours, and the pattern card
## always shows the true picture: Windblown (the card's four squares
## shuffled and turned on Insane) is gone, with `perm`, `turn`, `blow` and
## `card_peg`. Insane's spare moves grow with the picture.
## Spec: docs/superpowers/specs/2026-09-27-pixel-garden-flat-design.md and
## docs/superpowers/specs/2026-10-01-pixel-garden-polish-design.md.

const Pal = preload("res://core/palette.gd")

const BANK := "res://content/pixel_garden.json"
const EMPTY := -1
const HINTS := 3
## Hints and hearts by band: Hard trades a hint for hearts, Insane has
## neither hints nor Check -- only the iron judges.
const HINTS_BY := [3, 3, 2, 2]
const HEARTS_BY := [0, 0, 0, 0]
## The band with no Check (it counted moves until 2026-10-12, and had no
## hints until 2026-10-13).
const INSANE := 3
## share_glyphs draws no more squares a side than this: a bigger picture is
## shared a block of pegs a square.
const SHARE_SIDE := 16
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

## Which of a band's `count` pictures the day takes: one fixed shuffle of the
## band walked a day at a time (InsaneBank's rule), so no picture comes back
## until the whole band has passed. `step` is PuzzleBase.bank_step, how many
## times New has been pressed. New pictures go on the end of a band; the
## order is this shuffle's, never the file's.
static func day_pick(difficulty: int, count: int, step: int) -> int:
	if count <= 0:
		return 0
	var order: Array = range(count)
	var shuffle := RandomNumberGenerator.new()
	shuffle.seed = Daily.fnv1a("pixelgarden|%d" % difficulty)
	for i in range(count - 1, 0, -1):
		var j := shuffle.randi_range(0, i)
		var t = order[i]; order[i] = order[j]; order[j] = t
	return order[posmod(InsaneBank.day_ordinal() + step, count)]

## `daily_key` is PuzzleBase.daily_key: a daily not dealt again by New takes
## the day's themed picture of its band's size when this phone holds one
## (core/themed_pictures.gd), and the bank's otherwise.
func setup(rng: RandomNumberGenerator, difficulty: int, bank_step := 0, daily_key := 0) -> void:
	var pics := band_pictures(difficulty)
	if pics.is_empty():
		return
	band = clampi(difficulty, 0, 3)
	var themed := ThemedPictures.picture(daily_key, (pics[0].rows as Array).size()) if bank_step == 0 else {}
	load_picture(themed if not themed.is_empty() else pics[day_pick(band, pics.size(), bank_step)])
	_rng.seed = rng.randi()

## The letters' colour names: the bank's palette (Glimpse brings its own).
func _palette() -> Dictionary:
	return bank().get("palette", {})

func insane() -> bool:
	return band == INSANE

## Takes `pic` (one entry of the bank) as the day's picture, on a bare board.
func load_picture(pic: Dictionary) -> void:
	var legend: Dictionary = _palette()
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

## The iron's work once the whole board is full (as many beads seated on
## the plates not yet ironed as the picture puts there): every such plate
## that is right, or holds a bead astray. A plate that is only short, its
## beads sitting on another, is left alone. Empty until the board is full:
## a plate filled on its own is not judged (2026-10-04).
func plates_due() -> PackedInt32Array:
	var out := PackedInt32Array()
	var placed := 0
	var need := 0
	for q in 4:
		if ironed[q] == 0:
			placed += plate_placed(q)
			need += plate_need[q]
	if placed < need:
		return out
	for q in 4:
		if ironed[q] != 0:
			continue
		var due := plate_right(q)
		for c in plate_pegs(q):
			if beads[c] != EMPTY and beads[c] != want[c] and locked[c] == 0:
				due = true
		if due:
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

## Every bare peg the picture wants a bead on, reading order.
func missing() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in size():
		if want[c] != EMPTY and beads[c] != want[c]:
			out.append(c)
	return out

## Whether row `y` of the board is as the picture has it, with at least one
## bead in it: what a row's leaf says (pixel_garden2d.gd), and nothing about
## a row not yet finished.
func row_right(y: int) -> bool:
	var any := false
	for x in n:
		var c := y * n + x
		if beads[c] != want[c]:
			return false
		if want[c] != EMPTY:
			any = true
	return any

func can_undo() -> bool:
	return not history.is_empty()

## No band counts its moves (the user, 2026-10-12: "let's remove the
## limited moves on insane for drawing games like button box"; Insane had
## the picture's beads and a twentieth more). With no count Insane is the
## biggest picture with no hints and no Check: its plates are ironed as
## any band's are, and Undo is back. The board's counter is still there for
## a budget over 0, and unreached.
func moves_budget() -> int:
	return 0

## What `put(c, to)` would cost: one for a bead it would seat or lift,
## nothing for a put it would refuse (the same bead, a fixed peg, a peg
## holding another colour, a colour used up).
func move_cost(c: int, to: int) -> int:
	if beads[c] == to or locked[c] != 0:
		return 0
	if to != EMPTY and (beads[c] != EMPTY or left(to) <= 0):
		return 0
	return 1

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

## Drops the stroke in hand as if it had never begun (a second finger landed:
## the first was the start of a pinch). Every peg it changed is put back,
## last first, and nothing joins the history. Returns [[peg, the bead it
## held meanwhile], ...].
func cancel_stroke() -> Array:
	var out: Array = []
	if not _in_stroke:
		return out
	for i in range(_stroke.size() - 1, -1, -1):
		var c := int(_stroke[i][0])
		out.append([c, beads[c]])
		_seat(c, int(_stroke[i][1]))
	_stroke = []
	_in_stroke = false
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
func hint(at := -1) -> Dictionary:
	var pool := wrong()
	if pool.is_empty():
		pool = missing()
	if pool.is_empty():
		return {}
	# The bulb's second press fixes the peg its first press read.
	var c := at if at >= 0 and at < size() and beads[at] != want[at] and locked[at] == 0 else pool[_rng.randi() % pool.size()]
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
## has to each bead, on a white ground; a big picture a block of pegs a
## square (SHARE_SIDE).
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
	# A picture past SHARE_SIDE is shared a block a square, each the colour
	# most of its pegs have: 24 pegs as 12 squares, 32 as 16.
	var step := maxi(1, int(ceil(float(n) / float(SHARE_SIDE))))
	var out := ""
	for y in range(0, n, step):
		for x in range(0, n, step):
			var tally := {}
			var best := "▫️"
			var most := 0
			for dy in step:
				for dx in step:
					if y + dy >= n or x + dx >= n:
						continue
					var v := want[(y + dy) * n + x + dx]
					var g: String = "▫️" if v == EMPTY else glyph[v]
					tally[g] = int(tally.get(g, 0)) + 1
					if int(tally[g]) > most:
						most = int(tally[g])
						best = g
			out += best
		out += "\n"
	return out.strip_edges(false, true)
