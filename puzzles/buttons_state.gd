extends RefCounted

## Button Box's rules as the board plays them, scene-free, as every flat
## board's are. The board (puzzles/buttons2d.gd) draws this and nothing else.
##
## A little picture of cloth patches, one a square, each dyed the colour of
## the button that belongs on it -- and a button on every patch, of some
## other colour. A move is two taps. The first picks: a button out of place
## with every button of its colour that touches it (a run; corners count
## on Easy only), or every button of one colour in the tin. The second says
## where they go: a bare patch of their colour, and they are sewn onto it
## and the bare patches of that colour joined to it, as many as there are;
## or, for a run off the cloth, the tin, as many as it has room for.
## Nothing goes anywhere by itself.
##
## The tin starts small and gains a place every time a colour is whole.
##
## Nothing here can be lost up to Hard: the bare patches are always as many
## as the buttons in the tin, so while the tin holds anything some colour
## has a bare patch and a button off it, on the cloth or in the tin, and
## that button can be sewn (`tests/_probe_buttons.gd` plays that out).
## Insane counts its moves: the moves this file's own hand takes (`par`)
## and a few more.

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
const NEAR_CORNERS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## The bands on which corners count as touching (the user, 2026-10-11:
## "lets remove the link diagonal after easy, make too easy").
const CORNERS_TO := 0
## The bands that ring where a pick may go ("hard and insane should never
## show where to place").
const GUIDES_TO := 1

## What a move came to.
enum { OK, REFUSED_HOME, REFUSED_FULL, REFUSED_BARE, REFUSED_WRONG }
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

## What touches what on this band: the four sides, and on Easy the corners.
func near() -> Array:
	return NEAR_CORNERS if band <= CORNERS_TO else NEAR

func guides() -> bool:
	return band <= GUIDES_TO

## The bare patches of one colour joined to the bare patch `at`, itself
## first and then outward: what one tap fills.
func bare_run(at: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if at < 0 or slot[at] < 0 or cur[at] >= 0:
		return out
	var c := slot[at]
	var seen := {at: true}
	out.append(at)
	var head := 0
	while head < out.size():
		var p := xy(out[head])
		head += 1
		for d: Vector2i in near():
			var j := at_xy(p + d)
			if j >= 0 and not seen.has(j) and slot[j] == c and cur[j] < 0:
				seen[j] = true
				out.append(j)
	return out

## The run a tap on `i` picks: `i` and every button of its colour out of
## place that touches it (`near`), nearest first. Empty for a bare
## patch or a sewn button.
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
		for d: Vector2i in near():
			var j := at_xy(at + d)
			if j >= 0 and not seen.has(j) and cur[j] == c and slot[j] != c:
				seen[j] = true
				out.append(j)
	return out

## The places of the tin that hold colour `c`.
func tin_of(c: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in tin.size():
		if tin[p] == c and c >= 0:
			out.append(p)
	return out

## What a first tap on `i` would be: OK for a button that can be picked.
func judge(i: int) -> int:
	if i < 0 or slot[i] < 0 or cur[i] < 0:
		return REFUSED_BARE
	if cur[i] == slot[i]:
		return REFUSED_HOME
	return OK

func bare_of(c: int) -> PackedInt32Array:
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

func _before() -> Array:
	history.append([cur.duplicate(), tin.duplicate(), taps])
	var whole: Array = []
	for c in colours.size():
		whole.append(colour_done(c))
	return whole

func _after(res: Dictionary, was: int, whole_was: Array) -> Dictionary:
	taps += 1
	var whole: Array = []
	for k in colours.size():
		if not whole_was[k] and colour_done(k):
			whole.append(k)
	res["why"] = OK
	res["was"] = was
	res["now"] = capacity()
	res["whole"] = whole
	return res

## Sews the picked buttons -- `cells` off the cloth, or `places` out of the
## tin -- onto `at`, a bare patch of their colour, and the bare patches of
## that colour joined to it (`bare_run`), nearest first; a bare patch of the
## colour somewhere else on the cloth is another tap. {why, moves, kept}:
## `kept` are the ones with no patch left for them, still where they were.
func sew(cells: PackedInt32Array, places: PackedInt32Array, at: int) -> Dictionary:
	var from_tin := cells.is_empty()
	if from_tin and places.is_empty():
		return {"why": REFUSED_BARE, "moves": []}
	var c := tin[places[0]] if from_tin else cur[cells[0]]
	if at < 0 or slot[at] < 0 or cur[at] >= 0:
		return {"why": REFUSED_BARE, "moves": []}
	if slot[at] != c:
		return {"why": REFUSED_WRONG, "moves": []}
	var was := capacity()
	var whole_was := _before()
	var order := bare_run(at)
	var moves: Array = []
	var kept := PackedInt32Array()
	var source := places if from_tin else cells
	for k in source.size():
		if k >= order.size():
			kept.append(source[k])
			continue
		var to: int = order[k]
		cur[to] = c
		if from_tin:
			tin[source[k]] = -1
			moves.append([FROM_TIN, source[k], to, c])
		else:
			cur[source[k]] = -1
			moves.append([TO_PATCH, source[k], to, c])
	return _after({"moves": moves, "kept": kept}, was, whole_was)

## Puts the picked run `cells` into the tin, as many as it has room for.
## {why, moves, kept}.
func stow(cells: PackedInt32Array) -> Dictionary:
	if cells.is_empty():
		return {"why": REFUSED_BARE, "moves": []}
	var was := capacity()
	var room := was - in_tin()
	if room <= 0:
		return {"why": REFUSED_FULL, "moves": []}
	var whole_was := _before()
	var c := cur[cells[0]]
	var moves: Array = []
	var kept := PackedInt32Array()
	for g in cells:
		if room <= 0:
			kept.append(g)
			continue
		var place := tin.find(-1)
		tin[place] = c
		cur[g] = -1
		room -= 1
		moves.append([TO_TIN, g, place, c])
	return _after({"moves": moves, "kept": kept}, was, whole_was)

## Takes the last move back. False with nothing to take back.
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

## The move this file's own hand would make, {cells, places, to}: the pick
## (a run off the cloth or the tin's own of one colour) and where it goes
## (a bare patch, or -1 for the tin). It sews the most it can at one tap,
## onto the biggest joined stretch of bare patches the pick's colour has;
## with nothing to sew it stows the biggest run the tin takes whole, the
## smallest of all when none fits. {} on a finished cloth.
func hint() -> Dictionary:
	# the biggest stretch of bare patches a colour: [size, a patch of it]
	var stretch := {}
	var mapped := {}
	for i in slot.size():
		if slot[i] < 0 or cur[i] >= 0 or mapped.has(i):
			continue
		var run := bare_run(i)
		for g in run:
			mapped[g] = true
		if run.size() > int((stretch.get(slot[i], [0, -1]) as Array)[0]):
			stretch[slot[i]] = [run.size(), i]
	var best := {}
	var best_gain := 0
	for c in colours.size():
		if not stretch.has(c):
			continue
		var held := tin_of(c)
		var gain := mini(held.size(), int(stretch[c][0]))
		if gain > best_gain:
			best_gain = gain
			best = {"cells": PackedInt32Array(), "places": held, "to": int(stretch[c][1])}
	var seen := {}
	var room := capacity() - in_tin()
	var lift := PackedInt32Array()
	var small := PackedInt32Array()
	for i in slot.size():
		if slot[i] < 0 or cur[i] < 0 or cur[i] == slot[i] or seen.has(i):
			continue
		var run := run_of(i)
		for g in run:
			seen[g] = true
		var c := cur[i]
		if stretch.has(c):
			var gain := mini(run.size(), int(stretch[c][0]))
			if gain > best_gain:
				best_gain = gain
				best = {"cells": run, "places": PackedInt32Array(), "to": int(stretch[c][1])}
		if run.size() <= room and run.size() > lift.size():
			lift = run
		if small.is_empty() or run.size() < small.size():
			small = run
	if not best.is_empty():
		return best
	if lift.is_empty():
		lift = small
	if lift.is_empty():
		return {}
	return {"cells": lift, "places": PackedInt32Array(), "to": -1}

## Makes `move` (a `hint`). The result of `sew` or `stow`.
func play(move: Dictionary) -> Dictionary:
	if move.is_empty():
		return {"why": REFUSED_BARE, "moves": []}
	if int(move.to) < 0:
		return stow(move.cells)
	return sew(move.cells, move.places, int(move.to))

## The moves `hint` takes from the opening, on a copy.
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
		if probe.play(probe.hint()).why != OK:
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
