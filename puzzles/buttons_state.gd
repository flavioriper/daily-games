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
## The tin starts small and gains two places every time a colour is whole.
##
## Nothing here can be lost up to Hard: the bare patches are always as many
## as the buttons in the tin, so while the tin holds anything some colour
## has a bare patch and a button off it, on the cloth or in the tin, and
## that button can be sewn (`tests/_probe_buttons.gd` plays that out).
## Insane counted its moves until 2026-10-12; no band does now.

const BANK := "res://content/pixel_garden.json"
## Hard's own pictures, 16 squares a side (the user, 2026-10-12: "the hard
## mode on button box is way too hard based on the progress on easy and
## medium"; Hard was the shared bank's 24-square band, 267 to 576 buttons
## after Medium's 50 to 100). Pixel Garden's Insane band as it was before
## the big pictures; the shared bank's palette names their letters.
const HARD_BANK := "res://content/buttons_hard.json"
const HARD := 2
## The places in the tin a band starts with, and the most it ever has.
## Ten places open of twenty, CASE_STEP more a colour whole (the user,
## 2026-10-11: "the case should be bigger, 20 slots, 10 free and 10 to
## unlock"; 6 of 12 before, 7 on Hard -- and, the same day, "each unlock
## must unlock 2 not 1", one a colour before).
##
## The tin is as big as the picture asks (the user, 2026-10-13: "the case
## buttons box size should change based on the quantity of pieces to avoid
## making it too small and harder images being annoying to fill, you can
## use more than 2 rows if needed. Always round to floor even number, and
## blocked ones should be all free after 4 color filled (1/4 each color)"):
## a place every CASE_PER buttons, rounded down to an even number, never
## under CASE_MIN (the twenty the small pictures had) nor over CASE_CAP
## (what the foot of a phone holds in places a finger can still tap). Half
## of them open, and each of the first CASE_WHOLE colours made whole opens
## a quarter of the rest. `places()`.
const CASE_MIN := 20
const CASE_PER := 5
const CASE_CAP := 64
const CASE_WHOLE := 4
## The tutorial's small tin (`tin_base`) has this many places past its own,
## and opens them both with its one colour whole.
const CASE_OWN := 2
const BANDS := 4
const HINTS_BY := [3, 3, 2, 0]
## Insane: no bulb, and the seal for any day sewn. It counted its moves
## until 2026-10-12 (`moves_budget`).
const INSANE := 3
## A shared picture is at most this many marks across.
const SHARE_MAX := 16
## The bands of the big pictures, which zoom: Insane alone since
## 2026-10-12, Hard too for a day before it.
const BIG_FROM := 3
## The pictures a day may draw before it keeps the one it has.
const DRAWS := 12
const NEAR := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NEAR_CORNERS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## The bands on which corners count as touching (the user, 2026-10-11:
## "lets remove the link diagonal after easy, make too easy").
## Every band again: "move back the diagonal link" (the user, later the same
## day), which took back "lets remove the link diagonal after easy".
const CORNERS_TO := 3
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
static var _hard: Array = []

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
## The tin: `places()` places, -1 empty. Only the first `capacity()` are open.
var tin := PackedInt32Array()
var _places := CASE_MIN
var taps := 0
var par := 0
## Every tap, for Undo: [cur, tin, taps].
var history: Array = []
## The pictures `setup` drew before it kept one (a probe reads it).
var draws := 0
## The patches of each colour not yet sewn, and the patches there are: kept
## by `sew`, counted again by anything else that changes `cur`.
var _off := PackedInt32Array()
var _count := 0
## The hand counting its own game keeps no history.
var _quiet := false

static func bank() -> Dictionary:
	if not _bank_read:
		_bank_read = true
		# PG_BANK, in a debug build, points a harness at another bank.
		var path := BANK
		if OS.is_debug_build() and OS.has_environment("PG_BANK"):
			path = OS.get_environment("PG_BANK")
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var doc = JSON.parse_string(f.get_as_text())
			if doc is Dictionary:
				_bank = doc
	return _bank

static func hard_pictures() -> Array:
	if _hard.is_empty():
		var f := FileAccess.open(HARD_BANK, FileAccess.READ)
		if f != null:
			var doc = JSON.parse_string(f.get_as_text())
			if doc is Dictionary and doc.get("pictures") is Array:
				_hard = doc.pictures
	return _hard

static func hints_for(band_: int) -> int:
	return HINTS_BY[clampi(band_, 0, HINTS_BY.size() - 1)]

## The day's picture out of the bank and its buttons, scrambled.
func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	band = clampi(difficulty, 0, BANDS - 1)
	var doc := bank()
	var pics: Array = []
	if doc.get("bands") is Array and band < (doc.bands as Array).size():
		pics = doc.bands[band]
	# (a harness's PG_BANK is played band for band, as it is given)
	if band == HARD and not (OS.is_debug_build() and OS.has_environment("PG_BANK")):
		pics = hard_pictures()
	var pic := {"name": "", "rows": ["rrgg", "rrgg", "bbyy", "bbyy"]}
	var legend := {"r": "red", "g": "green", "b": "blue", "y": "yellow"}
	if pics.is_empty():
		adopt(pic, legend, rng)
		return
	# A picture nearly all one colour cannot be scrambled off itself: it is
	# drawn again while more than a quarter of it opens already sewn. The
	# par is the hand's whole game, so it is counted once, for the picture
	# kept.
	draws = 0
	for attempt in DRAWS:
		draws += 1
		_lay(pics[rng.randi_range(0, pics.size() - 1)], doc.palette, rng)
		if homes() * 4 <= count():
			break
	par = _solve_taps()

## Plays `pic` ({name, rows}) with its letters read through `legend`.
func adopt(pic: Dictionary, legend: Dictionary, rng: RandomNumberGenerator) -> void:
	_lay(pic, legend, rng)
	par = _solve_taps()

func _lay(pic: Dictionary, legend: Dictionary, rng: RandomNumberGenerator) -> void:
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
	_count = 0
	for k in slot:
		if k >= 0:
			_count += 1
	_places = tin_base + CASE_OWN if tin_base >= 0 else places_for(_count)
	start = _scramble(rng)
	reset()

## A hand-made cloth (the tutorial's): `rows` the patches and `opening` the
## buttons on them, letter for letter.
func adopt_laid(rows: Array, opening: Array, legend: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_lay({"name": "", "rows": rows}, legend, rng)
	for y in h:
		for x in w:
			if slot[y * w + x] >= 0:
				start[y * w + x] = colours.find(String(legend.get(String(opening[y])[x], "grey")))
	reset()
	par = _solve_taps()

## The buttons as the day opens: whole colours trade places (the user,
## 2026-10-12, of a day that opened "too sparse and spreaded, making the
## player to select one by one": "pick for example all blues, and swap with
## red, if still blue we pick the next color, and do it to the end"). The
## patches are read colour by colour -- the biggest colour first, the others
## in the day's own order, each a region at a time -- and the buttons are
## that same line moved along by the biggest colour's count. So a stretch of
## the picture lies under one colour of button, a run lifted bares one
## stretch, and nothing opens sewn unless one colour is more than half the
## cloth. Until then Easy to Hard were cut into lengths of 3 to 7 read down
## the columns and laid along the rows, and Insane into strips trading round
## a ring; both are in history.
func _scramble(rng: RandomNumberGenerator) -> PackedInt32Array:
	var by_colour: Array = []
	for c in colours.size():
		by_colour.append(PackedInt32Array())
	var seen := PackedByteArray()
	seen.resize(w * h)
	for from in w * h:
		if slot[from] < 0 or seen[from] == 1:
			continue
		var region := PackedInt32Array([from])
		seen[from] = 1
		var head := 0
		while head < region.size():
			var p := xy(region[head])
			head += 1
			for d: Vector2i in near():
				var j := at_xy(p + d)
				if j >= 0 and seen[j] == 0 and slot[j] == slot[from]:
					seen[j] = 1
					region.append(j)
		var line: PackedInt32Array = by_colour[slot[from]]
		line.append_array(region)
		by_colour[slot[from]] = line
	var order: Array = range(colours.size())
	for k in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t = order[k]
		order[k] = order[j]
		order[j] = t
	var big := 0
	for k in order.size():
		if (by_colour[order[k]] as PackedInt32Array).size() > (by_colour[order[big]] as PackedInt32Array).size():
			big = k
	var first: int = order[big]
	order.remove_at(big)
	order.push_front(first)
	var cells := PackedInt32Array()
	for c: int in order:
		cells.append_array(by_colour[c])
	var n := cells.size()
	var shift: int = (by_colour[first] as PackedInt32Array).size()
	var out := PackedInt32Array()
	out.resize(w * h)
	out.fill(-1)
	for i in n:
		out[cells[i]] = slot[cells[(i + shift) % n]]
	return out

func count() -> int:
	return _count

## Counts again what `_off` keeps: the patches of each colour not yet sewn.
func _recount() -> void:
	_off = PackedInt32Array()
	_off.resize(colours.size())
	_off.fill(0)
	_count = 0
	for i in slot.size():
		if slot[i] >= 0:
			_count += 1
			if cur[i] != slot[i]:
				_off[slot[i]] += 1

func xy(i: int) -> Vector2i:
	return Vector2i(i % w, i / w)

func at_xy(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return -1
	return c.y * w + c.x if slot[c.y * w + c.x] >= 0 else -1

func is_home(i: int) -> bool:
	return slot[i] >= 0 and cur[i] == slot[i]

func homes() -> int:
	var out := _count
	for n in _off:
		out -= n
	return out

func colour_done(c: int) -> bool:
	return _off[c] == 0

func colours_done() -> int:
	var out := 0
	for n in _off:
		if n == 0:
			out += 1
	return out

## The places a tin has for a picture of `buttons`, open or not.
static func places_for(buttons: int) -> int:
	return clampi(buttons / CASE_PER / 2 * 2, CASE_MIN, CASE_CAP)

## The places this picture's tin has.
func places() -> int:
	return _places

## The places the tin starts with: half of them.
func base() -> int:
	return tin_base if tin_base >= 0 else _places / 2

## The places open in the tin now: the ones it starts with, and a quarter
## of the rest for each of the first CASE_WHOLE colours whole.
func capacity() -> int:
	if tin_base >= 0:
		return mini(_places, tin_base + CASE_OWN * colours_done())
	return base() + (_places - base()) * mini(colours_done(), CASE_WHOLE) / CASE_WHOLE

func in_tin() -> int:
	var out := 0
	for c in tin:
		if c >= 0:
			out += 1
	return out

func is_solved() -> bool:
	return cur == slot

## No band counts its moves (the user, 2026-10-12: "let's remove the
## limited moves on insane for drawing games like button box"; Insane had
## the par and a quarter more). The board's counter is still there for a
## budget over 0, and unreached.
func moves_budget() -> int:
	return 0

## What touches what on this band: the four sides and, up to CORNERS_TO
## (every band now), the corners.
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
	if not _quiet:
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
		_off[c] -= 1
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
	_recount()
	return true

## The cloth as the day opened it.
func reset() -> void:
	cur = start.duplicate()
	tin = PackedInt32Array()
	tin.resize(_places)
	tin.fill(-1)
	taps = 0
	history = []
	_recount()

## Every button sewn, for a finished daily reopened.
func finish(used := -1) -> void:
	cur = slot.duplicate()
	tin.fill(-1)
	history = []
	_recount()
	if used >= 0:
		taps = used

## The move this file's own hand would make, {cells, places, to}: the pick
## (a run off the cloth or the tin's own of one colour) and where it goes
## (a bare patch, or -1 for the tin). It sews the most it can at one tap,
## onto the biggest joined stretch of bare patches the pick's colour has,
## and of two as good the one that leaves patches of fewer colours bare
## behind it; with nothing to sew it puts into the tin the run that opens
## the most patches in the fewest colours. {} on a finished cloth.
func hint() -> Dictionary:
	var bare := PackedInt32Array()
	for i in slot.size():
		if slot[i] >= 0 and cur[i] < 0:
			bare.append(i)
	return _choose(_stretches(bare), _runs())

## The biggest stretch of bare patches a colour, {colour: [size, a patch of
## it]}, out of `bare`: every bare patch, lowest first.
func _stretches(bare: PackedInt32Array) -> Dictionary:
	var stretch := {}
	var mapped := {}
	for i in bare:
		if mapped.has(i):
			continue
		var run := bare_run(i)
		for g in run:
			mapped[g] = true
		if run.size() > int((stretch.get(slot[i], [0, -1]) as Array)[0]):
			stretch[slot[i]] = [run.size(), i]
	return stretch

## Every run on the cloth, each from its lowest square.
func _runs() -> Array:
	var out: Array = []
	var seen := PackedByteArray()
	seen.resize(slot.size())
	for i in slot.size():
		if slot[i] < 0 or cur[i] < 0 or cur[i] == slot[i] or seen[i] == 1:
			continue
		var run := run_of(i)
		for g in run:
			seen[g] = 1
		out.append(run)
	return out

## The colours of the patches under the first `n` buttons of `run`.
func _kinds(run: PackedInt32Array, n: int) -> int:
	var first := slot[run[0]]
	var more := {}
	for k in range(1, n):
		if slot[run[k]] != first:
			more[slot[run[k]]] = true
	return 1 + more.size()

## `hint`, given what it sees: `stretch` (`_stretches`) and `runs` (every
## run, each from its lowest square, in any order). `first` in what it
## returns is the lowest square of the run picked.
func _choose(stretch: Dictionary, runs: Array) -> Dictionary:
	var best := {}
	var best_gain := 0
	var best_kinds := 0
	var best_first := -1
	var best_size := 0
	for c in colours.size():
		if not stretch.has(c):
			continue
		var held := tin_of(c)
		var gain := mini(held.size(), int(stretch[c][0]))
		if gain > best_gain:
			best_gain = gain
			best = {"cells": PackedInt32Array(), "places": held, "to": int(stretch[c][1])}
	var room := capacity() - in_tin()
	var lift := PackedInt32Array()
	var lift_n := 0
	var lift_kinds := 1
	for run: PackedInt32Array in runs:
		var c := cur[run[0]]
		if stretch.has(c):
			var gain := mini(run.size(), int(stretch[c][0]))
			# of two that sew as many, the tin's own first, then the run that
			# leaves patches of fewer colours bare, then the shorter (a long
			# run is not nibbled while a short one will do), then the lowest
			if gain > best_gain or (gain == best_gain and best_first >= 0):
				var kinds := _kinds(run, gain)
				if gain > best_gain or kinds < best_kinds or (kinds == best_kinds and (run.size() < best_size
						or (run.size() == best_size and run[0] < best_first))):
					best_gain = gain
					best_kinds = kinds
					best_size = run.size()
					best_first = run[0]
					best = {"cells": run, "places": PackedInt32Array(), "to": int(stretch[c][1])}
		if best_gain > 0 or room <= 0:
			continue
		# for the tin: the most buttons a colour of patch they leave bare
		var n := mini(run.size(), room)
		var kinds := _kinds(run, n)
		var better := n * (1 + lift_kinds) - lift_n * (1 + kinds)
		if lift.is_empty() or better > 0 or (better == 0 and (n > lift_n or (n == lift_n and run[0] < lift[0]))):
			lift = run
			lift_n = n
			lift_kinds = kinds
	if not best.is_empty():
		if best_first >= 0:
			best["first"] = best_first
			best.cells = _tidy(best.cells, best_gain)
		return best
	if lift.is_empty():
		return {}
	return {"cells": _tidy(lift, lift_n), "places": PackedInt32Array(), "to": -1, "first": lift[0]}

## `run` in the order the hand takes it up when only `n` of it will go: the
## buttons standing on the biggest joined stretch of one colour of patch
## first, so what they leave bare is one stretch and the next sew a big one
## (a player does as much by choosing which button of the run to tap).
func _tidy(run: PackedInt32Array, n: int) -> PackedInt32Array:
	if n >= run.size():
		return run
	var inside := {}
	for g in run:
		inside[g] = true
	var seen := {}
	var top := PackedInt32Array()
	for g in run:
		if seen.has(g):
			continue
		var piece := PackedInt32Array([g])
		seen[g] = true
		var head := 0
		while head < piece.size():
			var p := xy(piece[head])
			head += 1
			for d: Vector2i in near():
				var j := at_xy(p + d)
				if j >= 0 and inside.has(j) and not seen.has(j) and slot[j] == slot[g]:
					seen[j] = true
					piece.append(j)
		if piece.size() > top.size():
			top = piece
			if top.size() >= n:
				break
	var out := top.duplicate()
	var taken := {}
	for g in top:
		taken[g] = true
	for g in run:
		if not taken.has(g):
			out.append(g)
	return out

## Makes `move` (a `hint`). The result of `sew` or `stow`.
func play(move: Dictionary) -> Dictionary:
	if move.is_empty():
		return {"why": REFUSED_BARE, "moves": []}
	if int(move.to) < 0:
		return stow(move.cells)
	return sew(move.cells, move.places, int(move.to))

## The moves `hint` takes from the opening, on a copy. What the hand sees is
## kept from move to move and not read off the cloth again: the bare patches
## are never more than the tin holds, and a run only ever loses buttons, so
## a move changes the one run it picked (a 32-square cloth is counted in a
## few dozen ms and not a second).
func _solve_taps() -> int:
	var probe = get_script().new()
	probe.band = band
	probe.tin_base = tin_base
	probe._places = _places
	probe.w = w
	probe.h = h
	probe.colours = colours
	probe.slot = slot
	probe.start = start
	probe._quiet = true
	probe.reset()
	var runs := {}
	for run: PackedInt32Array in probe._runs():
		runs[run[0]] = run
	var bare := {}
	var guard := 0
	while not probe.is_solved() and guard < 4000:
		guard += 1
		var open := PackedInt32Array(bare.keys())
		open.sort()
		var move: Dictionary = probe._choose(probe._stretches(open), runs.values())
		var res: Dictionary = probe.play(move)
		if int(res.why) != OK:
			return 0
		for m: Array in res.moves:
			if int(m[0]) != TO_TIN:
				bare.erase(int(m[2]))
			if int(m[0]) != FROM_TIN:
				bare[int(m[1])] = true
		var cells: PackedInt32Array = move.cells
		if cells.is_empty():
			continue
		# the run picked is what is left of it, which may be in pieces
		runs.erase(int(move.first))
		var kept: PackedInt32Array = (res.kept as PackedInt32Array).duplicate()
		kept.sort()
		var seen := {}
		for g in kept:
			if seen.has(g):
				continue
			var piece: PackedInt32Array = probe.run_of(g)
			for q in piece:
				seen[q] = true
			runs[g] = piece
	return probe.taps if probe.is_solved() else 0

## The cloth as it was sewn: a square a patch in its nearest emoji colour.
func share_glyphs() -> String:
	var marks := {"red": "🟥", "orange": "🟧", "yellow": "🟨", "cream": "⬜", "white": "⬜", "pink": "🟥",
		"rose": "🟥", "lilac": "🟪", "purple": "🟪", "sky": "🟦", "blue": "🟦", "teal": "🟩", "lime": "🟩",
		"green": "🟩", "forest": "🟩", "tan": "🟧", "brown": "🟫", "dark": "⬛", "grey": "⬜"}
	var out := ""
	# A big picture is shared small: a mark is two squares a side there, and
	# the colour most of its squares are (1,024 marks are not a share).
	var step := ceili(float(maxi(w, h)) / SHARE_MAX)
	for y in range(0, h, step):
		for x in range(0, w, step):
			var votes := {}
			var top := ""
			for yy in range(y, mini(h, y + step)):
				for xx in range(x, mini(w, x + step)):
					var s := slot[yy * w + xx]
					var mark := "▫️" if s < 0 else String(marks.get(colours[s], "⬜"))
					votes[mark] = int(votes.get(mark, 0)) + 1
					if top == "" or int(votes[mark]) > int(votes[top]):
						top = mark
			out += top
		out += "\n"
	return out.strip_edges()
