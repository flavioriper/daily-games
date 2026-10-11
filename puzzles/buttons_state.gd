extends RefCounted

## Button Box's rules as the board plays them, scene-free, as every flat
## board's are. The board (puzzles/buttons2d.gd) draws this and nothing else.
##
## A little picture of cloth patches, one a square, each dyed the colour of
## the button that belongs on it -- and a button on every patch, of some
## other colour. The one move is a tap on a button out of place: it lifts
## with every button of its colour that touches it, a run. Each one lifted
## goes straight onto a bare patch of its own colour while there is one (the
## nearest), and is sewn there for good; the rest go into the tin, as many
## as it has room for, and the others stay where they were. A patch left
## bare takes a button of its colour out of the tin at once.
##
## The tin starts small and gains a place every time a colour is whole.
##
## Nothing here can be lost up to Hard: while the tin holds anything there
## is a bare patch for each button in it, of a colour the tin has none of,
## so a button of that colour is still on the cloth and a tap on it goes
## home (`tests/_probe_buttons.gd` plays that out). Insane counts its taps:
## the taps this file's own hand takes (`par`) and a few more.

const BANK := "res://content/pixel_garden.json"
## The places in the tin a band starts with, and the most it ever has.
const CASE_BASE := [6, 6, 7, 6]
const CASE_MAX := 12
const HINTS_BY := [3, 3, 2, 0]
## Insane's spare taps over the par: a quarter of it, and never under this.
const SLACK_MIN := 3
const COUNTED_FROM := 3
## The lengths the scramble cuts the colours into.
const CHUNK := Vector2i(3, 7)
## The pictures a day may draw before it keeps the one it has.
const DRAWS := 12
const NEAR := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## What a tap came to.
enum { OK, REFUSED_HOME, REFUSED_FULL, REFUSED_BARE }
## What one button of a tap did: [kind, from, to, colour]. `from` and `to`
## are squares, or places in the tin on the side the kind names.
enum { TO_PATCH, TO_TIN, FROM_TIN }

static var _bank: Dictionary = {}
static var _bank_read := false

var band := 0
## A cloth with a tin of its own (the tutorial's); -1 is the band's.
var tin_base := -1
var w := 0
var h := 0
## The picture's name (a PG_PIC_* key) and the palette names its colours
## index (core/palette.gd's PG_BEADS).
var name_key := ""
var colours: Array[String] = []
## A square's patch (its colour, -1 off the picture) and the button on it
## (-1 bare).
var slot := PackedInt32Array()
var cur := PackedInt32Array()
var start := PackedInt32Array()
## The tin: CASE_MAX places, -1 empty. Only the first `capacity()` are open.
var tin := PackedInt32Array()
var taps := 0
var par := 0
## Every tap, for Undo: [cur, tin, taps].
var history: Array = []

static func bank() -> Dictionary:
	if not _bank_read:
		_bank_read = true
		if FileAccess.file_exists(BANK):
			var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK))
			if doc is Dictionary:
				_bank = doc
	return _bank

static func hints_for(band_: int) -> int:
	return HINTS_BY[clampi(band_, 0, HINTS_BY.size() - 1)]

## The day's picture out of the bank and its buttons, scrambled.
func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	band = clampi(difficulty, 0, CASE_BASE.size() - 1)
	var doc := bank()
	var pics: Array = []
	if doc.get("bands") is Array and band < (doc.bands as Array).size():
		pics = doc.bands[band]
	var pic := {"name": "", "rows": ["rrgg", "rrgg", "bbyy", "bbyy"]}
	var legend := {"r": "red", "g": "green", "b": "blue", "y": "yellow"}
	if pics.is_empty():
		adopt(pic, legend, rng)
		return
	# A picture nearly all one colour cannot be scrambled off itself: it is
	# drawn again while more than a quarter of it opens already sewn.
	for attempt in DRAWS:
		adopt(pics[rng.randi_range(0, pics.size() - 1)], doc.palette, rng)
		if homes() * 4 <= count():
			return

## Plays `pic` ({name, rows}) with its letters read through `legend`.
func adopt(pic: Dictionary, legend: Dictionary, rng: RandomNumberGenerator) -> void:
	var rows: Array = pic.rows
	h = rows.size()
	w = String(rows[0]).length()
	name_key = String(pic.get("name", ""))
	colours = []
	slot = PackedInt32Array()
	slot.resize(w * h)
	slot.fill(-1)
	for y in h:
		for x in w:
			var ch := String(rows[y])[x]
			if ch == ".":
				continue
			var named := String(legend.get(ch, "grey"))
			var k := colours.find(named)
			if k < 0:
				k = colours.size()
				colours.append(named)
			slot[y * w + x] = k
	start = _scramble(rng)
	reset()
	par = _solve_taps()

## A hand-made cloth (the tutorial's): `rows` the patches and `opening` the
## buttons on them, letter for letter.
func adopt_laid(rows: Array, opening: Array, legend: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	adopt({"name": "", "rows": rows}, legend, rng)
	for y in h:
		for x in w:
			if slot[y * w + x] >= 0:
				start[y * w + x] = colours.find(String(legend.get(String(opening[y])[x], "grey")))
	reset()
	par = _solve_taps()

## The buttons as the day opens: the picture's own colours read down its
## columns, cut into short lengths, the lengths shuffled and laid along the
## rows -- so the colours come in runs of a few and nearly every button is
## off its patch; the few that are not trade places with one that can.
func _scramble(rng: RandomNumberGenerator) -> PackedInt32Array:
	var by_row := PackedInt32Array()
	var by_col := PackedInt32Array()
	for y in h:
		for i in w:
			var x := i if y % 2 == 0 else w - 1 - i
			if slot[y * w + x] >= 0:
				by_row.append(y * w + x)
	for x in w:
		for i in h:
			var y := i if x % 2 == 0 else h - 1 - i
			if slot[y * w + x] >= 0:
				by_col.append(y * w + x)
	var n := by_row.size()
	var lengths: Array = []
	var at := 0
	while at < n:
		var cut := mini(n - at, rng.randi_range(CHUNK.x, CHUNK.y))
		lengths.append([at, cut])
		at += cut
	for k in range(lengths.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t = lengths[k]
		lengths[k] = lengths[j]
		lengths[j] = t
	var best := PackedInt32Array()
	best.resize(w * h)
	best.fill(-1)
	var put := 0
	for piece: Array in lengths:
		for k in int(piece[1]):
			best[by_row[put]] = slot[by_col[int(piece[0]) + k]]
			put += 1
	for i in best.size():
		if slot[i] < 0 or best[i] != slot[i]:
			continue
		var from := rng.randi_range(0, best.size() - 1)
		for k in best.size():
			var j := (from + k) % best.size()
			if slot[j] < 0 or best[j] == slot[j] or best[j] == slot[i] or best[i] == slot[j]:
				continue
			var t := best[i]
			best[i] = best[j]
			best[j] = t
			break
	return best

func count() -> int:
	var out := 0
	for s in slot:
		if s >= 0:
			out += 1
	return out

func xy(i: int) -> Vector2i:
	return Vector2i(i % w, i / w)

func at_xy(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return -1
	return c.y * w + c.x if slot[c.y * w + c.x] >= 0 else -1

func is_home(i: int) -> bool:
	return slot[i] >= 0 and cur[i] == slot[i]

func homes() -> int:
	var out := 0
	for i in slot.size():
		if slot[i] >= 0 and cur[i] == slot[i]:
			out += 1
	return out

func colour_done(c: int) -> bool:
	for i in slot.size():
		if slot[i] == c and cur[i] != c:
			return false
	return true

func colours_done() -> int:
	var out := 0
	for c in colours.size():
		if colour_done(c):
			out += 1
	return out

## The places open in the tin now: the band's own and one a colour whole.
func capacity() -> int:
	return mini(CASE_MAX, (tin_base if tin_base >= 0 else int(CASE_BASE[band])) + colours_done())

func in_tin() -> int:
	var out := 0
	for c in tin:
		if c >= 0:
			out += 1
	return out

func is_solved() -> bool:
	return cur == slot

## Insane's taps: the par and its slack. 0 on a band that does not count.
func moves_budget() -> int:
	if band < COUNTED_FROM:
		return 0
	return par + maxi(SLACK_MIN, par / 4)

## The run a tap on `i` lifts: `i` and every button of its colour out of
## place that touches it, nearest first.
func run_of(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if i < 0 or slot[i] < 0 or cur[i] < 0 or cur[i] == slot[i]:
		return out
	var c := cur[i]
	var seen := {i: true}
	out.append(i)
	var head := 0
	while head < out.size():
		var at := xy(out[head])
		head += 1
		for d: Vector2i in NEAR:
			var j := at_xy(at + d)
			if j >= 0 and not seen.has(j) and cur[j] == c and slot[j] != c:
				seen[j] = true
				out.append(j)
	return out

## Whether a tap on `i` would move anything.
func judge(i: int) -> int:
	if i < 0 or slot[i] < 0 or cur[i] < 0:
		return REFUSED_BARE
	if cur[i] == slot[i]:
		return REFUSED_HOME
	if in_tin() >= capacity() and _bare(cur[i]).is_empty():
		return REFUSED_FULL
	return OK

func _bare(c: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in slot.size():
		if slot[k] == c and cur[k] < 0:
			out.append(k)
	return out

func _nearest(pool: PackedInt32Array, to: int) -> int:
	var at := xy(to)
	var best := -1
	var best_d := 1 << 30
	for n in pool.size():
		var p := xy(pool[n]) - at
		var d := p.x * p.x + p.y * p.y
		if d < best_d:
			best_d = d
			best = n
	return best

## Taps the button on `i`. {why, moves, kept, was, now, whole}: what each
## button did in order, how many of the run stayed, the tin's places before
## and after and the colours this tap made whole.
func tap(i: int) -> Dictionary:
	var why := judge(i)
	if why != OK:
		return {"why": why, "moves": []}
	history.append([cur.duplicate(), tin.duplicate(), taps])
	var was := capacity()
	var whole_was: Array = []
	for c in colours.size():
		whole_was.append(colour_done(c))
	var c := cur[i]
	var run := run_of(i)
	var bare := _bare(c)
	var room := was - in_tin()
	var moves: Array = []
	var left: Array = []
	var kept := 0
	for g in run:
		if not bare.is_empty():
			var n := _nearest(bare, g)
			var k := bare[n]
			bare.remove_at(n)
			cur[k] = c
			cur[g] = -1
			moves.append([TO_PATCH, g, k, c])
			left.append(g)
		elif room > 0:
			var place := tin.find(-1)
			tin[place] = c
			cur[g] = -1
			room -= 1
			moves.append([TO_TIN, g, place, c])
			left.append(g)
		else:
			kept += 1
	# a patch left bare takes its button out of the tin
	for g: int in left:
		var place := tin.find(slot[g])
		if place >= 0:
			tin[place] = -1
			cur[g] = slot[g]
			moves.append([FROM_TIN, place, g, slot[g]])
	taps += 1
	var whole: Array = []
	for k in colours.size():
		if not whole_was[k] and colour_done(k):
			whole.append(k)
	return {"why": OK, "moves": moves, "kept": kept, "was": was, "now": capacity(), "whole": whole}

## Takes the last tap back. False with nothing to take back.
func undo() -> bool:
	if history.is_empty():
		return false
	var last: Array = history.pop_back()
	cur = last[0]
	tin = last[1]
	taps = last[2]
	return true

## The cloth as the day opened it.
func reset() -> void:
	cur = start.duplicate()
	tin = PackedInt32Array()
	tin.resize(CASE_MAX)
	tin.fill(-1)
	taps = 0
	history = []

## Every button sewn, for a finished daily reopened.
func finish(used := -1) -> void:
	cur = slot.duplicate()
	tin.fill(-1)
	history = []
	if used >= 0:
		taps = used

## The tap this file's own hand would make: the run that sews the most at
## once, and with nothing bare to sew onto, the biggest run the tin takes
## whole (the smallest of all when none fits). -1 on a finished cloth.
func hint() -> int:
	var seen := {}
	var room := capacity() - in_tin()
	var bare_of := {}
	var tin_of := {}
	for c in tin:
		if c >= 0:
			tin_of[c] = int(tin_of.get(c, 0)) + 1
	var best := -1
	var best_gain := 0
	var lift := -1
	var lift_size := 0
	var small := -1
	var small_size := 1 << 30
	for i in slot.size():
		if slot[i] < 0 or cur[i] < 0 or cur[i] == slot[i] or seen.has(i):
			continue
		var run := run_of(i)
		for g in run:
			seen[g] = true
		var c := cur[i]
		if not bare_of.has(c):
			bare_of[c] = _bare(c).size()
		var sewn := mini(run.size(), int(bare_of[c]))
		var gone := mini(run.size(), sewn + room)
		# what the tin gives back onto the patches this run leaves
		var back := {}
		var gain := sewn
		for n in gone:
			var d := slot[run[n]]
			var have := int(tin_of.get(d, 0)) - int(back.get(d, 0))
			if have > 0:
				back[d] = int(back.get(d, 0)) + 1
				gain += 1
		if gain > best_gain:
			best_gain = gain
			best = i
		if run.size() <= room and run.size() > lift_size:
			lift_size = run.size()
			lift = i
		if run.size() < small_size:
			small_size = run.size()
			small = i
	if best >= 0:
		return best
	return lift if lift >= 0 else small

## The taps `hint` takes from the opening, on a copy.
func _solve_taps() -> int:
	var probe = get_script().new()
	probe.band = band
	probe.tin_base = tin_base
	probe.w = w
	probe.h = h
	probe.colours = colours
	probe.slot = slot
	probe.start = start
	probe.reset()
	var guard := 0
	while not probe.is_solved() and guard < 4000:
		guard += 1
		var i: int = probe.hint()
		if i < 0 or probe.tap(i).why != OK:
			return 0
		probe.history = []
	return probe.taps if probe.is_solved() else 0

## The cloth as it was sewn: a square a patch in its nearest emoji colour.
func share_glyphs() -> String:
	var marks := {"red": "🟥", "orange": "🟧", "yellow": "🟨", "cream": "⬜", "white": "⬜", "pink": "🟥",
		"rose": "🟥", "lilac": "🟪", "purple": "🟪", "sky": "🟦", "blue": "🟦", "teal": "🟩", "lime": "🟩",
		"green": "🟩", "forest": "🟩", "tan": "🟧", "brown": "🟫", "dark": "⬛", "grey": "⬜"}
	var out := ""
	for y in h:
		for x in w:
			var s := slot[y * w + x]
			out += "▫️" if s < 0 else String(marks.get(colours[s], "⬜"))
		out += "\n"
	return out.strip_edges()
