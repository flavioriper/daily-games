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
## Its buttons sit packed from its first place in groups of a colour, in
## the order the colours came (the user, 2026-10-14: "when moving pieces to
## case box or after placing them, we need to reorder it to make sure
## colors stay in sequence. For example if green is first and yellow
## second, and I move in green, it should be added right after green and
## move yellow to the next available slot"): a button stowed goes in right
## after the last of its colour, the ones past it sliding along a place,
## and buttons sewn out of the tin leave no gap, the rest sliding back.
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
const HARD := 2
## The bank's band each band deals (Hard and Insane both the bank's 32s),
## and the side of the day's themed picture each asks for
## (core/themed_pictures.gd): Insane's 48 is drawn for Button Box alone.
const BANK_BAND := [0, 1, 3, 3]
const THEMED_KEY := [10, 12, 32, 128]
## Insane is one big picture played a quarter at a time (the user,
## 2026-10-27, with a shot of a mosaic game: "on jewel box, the insane
## should be a way bigger image and user fill each part of a 4 grid side
## at time"; they chose 96 a side, then "it should have at least 5x more
## pieces": 128, half of it filled at least). The night's 128 is cut in two each way
## and the quarters played in reading order, each a cloth with its own
## scramble and tin (`_deal_parts`). Insane asked for the night's 48 whole
## until then.
const PARTS_FROM := 3
## The night's picture Insane played whole before it came in parts.
const NIGHT_WHOLE := 48
## A quarter with fewer jewels than this, or of one colour, is no part of
## its own: a subject on bare board can leave a corner nearly empty, and a
## cloth of one colour cannot scramble. Its jewels open set.
const PART_MIN := 16
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
## (what the foot of a phone holds in places a finger can still tap).
## `places()`. CASE_CAP 48 since 2026-10-21 (the user: "let's keep cap at
## 48"): four rows, where 64 was six and every Hard and Insane day hit it.
##
## Every place is open from the start (the user, 2026-10-17: "remove the
## unlock of the bottom case, they are all available since beggining");
## half opened and each of the first four colours whole opened a quarter of
## the rest until then.
const CASE_MIN := 20
const CASE_PER := 5
const CASE_CAP := 48
const BANDS := 4
const HINTS_BY := [3, 3, 2, 2]
## Insane: Hard's two hints (none until 2026-10-13), and the seal for any day sewn. It counted its moves
## until 2026-10-12 (`moves_budget`).
const INSANE := 3
## A shared picture is at most this many marks across.
const SHARE_MAX := 16
## The bands of the big pictures, which zoom: Hard and Insane (the user,
## 2026-10-14: "the hard mode should have a zoom feature just like insane";
## Hard deals the bank's 32s since the same day). Insane alone from
## 2026-10-12 to then.
const BIG_FROM := 2
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
## are squares, or places in the tin on the side the kind names; a SLIDE is
## a button of the tin moved along to another place, both ends places.
enum { TO_PATCH, TO_TIN, FROM_TIN, SLIDE }

static var _bank: Dictionary = {}
static var _bank_read := false

var band := 0
## A cloth with a tin of its own size (the tutorial's); -1 is the band's.
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
## The tin: `places()` places, -1 empty.
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
## A picture played in parts (Insane): the whole, a letter a square
## (`legend` names them), the parts as {rows, at, start} in the order they
## are played, and the one on the cloth. `w`, `h`, `slot` and the rest
## are the part's; `part_at` is where its first square lies in the whole. A
## picture played whole has no parts.
var whole: Array = []
var legend: Dictionary = {}
var parts: Array = []
var part := 0
var part_at := Vector2i.ZERO
## The taps of the parts already sewn, which the part's own count adds to.
var taps_before := 0
## A picture a probe hands Insane in place of the night's.
static var handed: Dictionary = {}

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

static func hints_for(band_: int) -> int:
	return HINTS_BY[clampi(band_, 0, HINTS_BY.size() - 1)]

## The day's picture out of the bank and its buttons, scrambled.
## `daily_key` is PuzzleBase.daily_key: a daily takes the day's themed
## picture of its band's size when this phone holds one
## (core/themed_pictures.gd) and it scrambles, and the bank's otherwise.
func setup(rng: RandomNumberGenerator, difficulty: int, daily_key := 0) -> void:
	band = clampi(difficulty, 0, BANDS - 1)
	var doc := bank()
	var pics: Array = []
	# Hard deals the bank's biggest band (the user, 2026-10-14: "hard should
	# be what is current insane"), and Insane the same when no day holds a
	# picture of its own: the bank has nothing bigger than 32.
	var from: int = BANK_BAND[band]
	if doc.get("bands") is Array and from < (doc.bands as Array).size():
		pics = doc.bands[from]
	var pic := {"name": "", "rows": ["rrgg", "rrgg", "bbyy", "bbyy"]}
	var plain := {"r": "red", "g": "green", "b": "blue", "y": "yellow"}
	if pics.is_empty():
		adopt(pic, plain, rng)
		return
	if band >= PARTS_FROM and _deal_parts(rng, daily_key, pics, doc.palette):
		return
	# A picture nearly all one colour cannot be scrambled off itself: it is
	# drawn again while more than a quarter of it opens already sewn. The
	# par is the hand's whole game, so it is counted once, for the picture
	# kept.
	draws = 0
	var themed := ThemedPictures.picture(daily_key, THEMED_KEY[band])
	# The same test as the bank's: scrambled again while too much of it opens
	# sewn, and a picture that never scrambles off itself is left to the bank.
	if not themed.is_empty():
		for attempt in DRAWS:
			draws += 1
			_lay(themed, doc.palette, rng)
			if homes() * 4 <= count():
				par = _solve_taps()
				return
		draws = 0
	for attempt in DRAWS:
		draws += 1
		_lay(pics[rng.randi_range(0, pics.size() - 1)], doc.palette, rng)
		if homes() * 4 <= count():
			break
	par = _solve_taps()

## Plays `pic` ({name, rows}) with its letters read through `legend`.
func adopt(pic: Dictionary, names: Dictionary, rng: RandomNumberGenerator) -> void:
	_lay(pic, names, rng)
	par = _solve_taps()

## Lays `pic` on the cloth and scrambles it, or opens it as `keep` when
## that is a part's opening already drawn.
func _lay(pic: Dictionary, names: Dictionary, rng: RandomNumberGenerator, keep := PackedInt32Array()) -> void:
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
			var named := String(names.get(ch, "grey"))
			var k := colours.find(named)
			if k < 0:
				k = colours.size()
				colours.append(named)
			slot[y * w + x] = k
	_count = 0
	for k in slot:
		if k >= 0:
			_count += 1
	_places = tin_base if tin_base >= 0 else places_for(_count)
	start = keep.duplicate() if not keep.is_empty() else _scramble(rng)
	reset()

## A hand-made cloth (the tutorial's): `rows` the patches and `opening` the
## buttons on them, letter for letter.
func adopt_laid(rows: Array, opening: Array, names: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_lay({"name": "", "rows": rows}, names, rng)
	for y in h:
		for x in w:
			if slot[y * w + x] >= 0:
				start[y * w + x] = colours.find(String(names.get(String(opening[y])[x], "grey")))
	reset()
	par = _solve_taps()

## Insane's picture in quarters: one picture cut in two each way (the
## user, 2026-10-27: "it should be a single picture, into 4 parts not 4
## different pictures"). The night's 128, else the night's 48 (published
## for Insane whole until then, so a phone holds it before a 128 is ever
## drawn), else one of the bank's 32s: both a stopgap, with fewer jewels
## than Insane had whole. Each part is drawn as a whole day is (scrambled
## again while a quarter of it opens set). The par is every part's added
## up, each counted as its part comes on: four of a 128 counted at once
## took 1.8 s on a desk. False with nothing to play in parts.
func _deal_parts(rng: RandomNumberGenerator, daily_key: int, pics: Array, names: Dictionary) -> bool:
	var pic := ThemedPictures.picture(daily_key, THEMED_KEY[band])
	if pic.is_empty():
		pic = ThemedPictures.picture(daily_key, NIGHT_WHOLE)
	if not handed.is_empty():
		pic = handed
	if pic.is_empty():
		pic = pics[rng.randi_range(0, pics.size() - 1)]
	whole = pic.rows
	name_key = String(pic.get("name", ""))
	var cut := quarters(whole)
	legend = names
	parts = []
	par = 0
	draws = 0
	for piece: Dictionary in cut:
		for attempt in DRAWS:
			draws += 1
			_lay({"name": name_key, "rows": piece.rows}, names, rng)
			if homes() * 4 <= count() or _count < PART_MIN or colours.size() < 2:
				break
		if _count < PART_MIN or colours.size() < 2:
			continue
		piece.start = start.duplicate()
		parts.append(piece)
	if parts.is_empty():
		whole = []
		return false
	taps_before = 0
	_enter_part(0)
	return true

## A picture's rows cut in two each way, in reading order, as
## {rows, at}.
static func quarters(rows_: Array) -> Array:
	var out: Array = []
	var side: int = rows_.size()
	var half_x := ceili(String(rows_[0]).length() / 2.0)
	var half_y := ceili(side / 2.0)
	for q in 4:
		var x0 := (q % 2) * half_x
		var y0 := (q / 2) * half_y
		var rows: Array = []
		for y in range(y0, mini(side, y0 + half_y)):
			rows.append(String(rows_[y]).substr(x0, half_x))
		out.append({"rows": rows, "at": Vector2i(x0, y0)})
	return out

## Puts part `k` on the cloth as it opened.
func _enter_part(k: int) -> void:
	part = k
	var piece: Dictionary = parts[k]
	part_at = piece.at
	_lay({"name": name_key, "rows": piece.rows}, legend, null, piece.start)
	if not piece.has("par"):
		piece.par = _solve_taps()
		par += int(piece.par)

## Whether the picture is played in parts.
func in_parts() -> bool:
	return parts.size() > 1

func parts_left() -> int:
	return parts.size() - 1 - part if in_parts() else 0

## This part is sewn and another waits.
func part_done() -> bool:
	return cur == slot and parts_left() > 0

## The next part on the cloth, its taps added on to the ones before. Only
## once `part_done`.
func next_part() -> void:
	if not part_done():
		return
	taps_before = taps
	_enter_part(part + 1)

## Square (x, y) of the whole, as {colour name, whether it is set}, for
## every square off this part: the parts before it are sewn, the ones after
## it wait, and a quarter too small to be a part opens set. Read off the
## letters, so a colour keeps its name across parts.
func around() -> Array:
	var out: Array = []
	if not in_parts():
		return out
	var waiting := {}
	for k in range(part + 1, parts.size()):
		var piece: Dictionary = parts[k]
		waiting[piece.at] = (piece.rows as Array)
	for y in whole.size():
		var line := String(whole[y])
		for x in line.length():
			var ch := line[x]
			if ch == ".":
				continue
			var p := Vector2i(x, y)
			var mine := p - part_at
			if mine.x >= 0 and mine.y >= 0 and mine.x < w and mine.y < h:
				continue
			var sewn_ := true
			for o: Vector2i in waiting:
				var rows: Array = waiting[o]
				var q := p - o
				if q.x >= 0 and q.y >= 0 and q.y < rows.size() and q.x < String(rows[0]).length():
					sewn_ = false
					break
			out.append([p, String(legend.get(ch, "grey")), sewn_])
	return out

func whole_size() -> Vector2i:
	if not in_parts():
		return Vector2i(w, h)
	return Vector2i(String(whole[0]).length(), whole.size())

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

## The places open in the tin: all of them.
func capacity() -> int:
	return _places

func in_tin() -> int:
	var out := 0
	for c in tin:
		if c >= 0:
			out += 1
	return out

## Every part sewn: a picture in parts is solved on its last.
func is_solved() -> bool:
	return cur == slot and parts_left() == 0

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
## place that touches it (`near`), taken a patch at a time: first the ones
## standing on the same colour of slot as `i` and joined to it through that
## colour (the user, 2026-10-19: "if user click on the red in the blue slot,
## even tho all red appears linked, when moving it should prioritize first
## all the red on the blue slot before going to red on green"), then,
## nearest the ones taken, the next patch beside them, and so on -- never a
## patch of the same slot colour elsewhere in the run before the ones
## between (the user, 2026-10-26: "it should only trigger near ones. If
## there is no color left to jump to, it should select another one").
## `sew` and `stow` take the run in this order, so a move that takes only
## part of it takes those first, and what they bare is one colour and
## joined. Empty for a bare patch or a sewn button.
func run_of(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if i < 0 or slot[i] < 0 or cur[i] < 0 or cur[i] == slot[i]:
		return out
	var c := cur[i]
	var taken := {}
	# a queue of the run's buttons touching the ones taken, nearest first
	var edge := PackedInt32Array([i])
	var queued := {i: true}
	var head := 0
	while head < edge.size():
		var g := edge[head]
		head += 1
		if taken.has(g):
			continue
		# the whole patch of g's slot colour joined to g, flooded at once
		var under := slot[g]
		var patch := PackedInt32Array([g])
		taken[g] = true
		var ph := 0
		while ph < patch.size():
			var p := xy(patch[ph])
			ph += 1
			for d: Vector2i in near():
				var j := at_xy(p + d)
				if j < 0 or taken.has(j) or cur[j] != c or slot[j] == c:
					continue
				if slot[j] == under:
					taken[j] = true
					patch.append(j)
				elif not queued.has(j):
					queued[j] = true
					edge.append(j)
		out.append_array(patch)
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

func _after(res: Dictionary, whole_was: Array) -> Dictionary:
	taps += 1
	var whole: Array = []
	for k in colours.size():
		if not whole_was[k] and colour_done(k):
			whole.append(k)
	res["why"] = OK
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
	if from_tin:
		_pack(moves)
	return _after({"moves": moves, "kept": kept}, whole_was)

## Closes the tin's gaps: every button slides back to the first free place
## before it, in order, so the groups of a colour stay together. The
## slides go on `moves`; the count of buttons in the tin is answered.
func _pack(moves: Array) -> int:
	var n := 0
	for p in tin.size():
		var c := tin[p]
		if c < 0:
			continue
		if n < p:
			tin[n] = c
			tin[p] = -1
			moves.append([SLIDE, p, n, c])
		n += 1
	return n

## Puts the picked run `cells` into the tin, as many as it has room for.
## {why, moves, kept}.
func stow(cells: PackedInt32Array) -> Dictionary:
	if cells.is_empty():
		return {"why": REFUSED_BARE, "moves": []}
	var room := capacity() - in_tin()
	if room <= 0:
		return {"why": REFUSED_FULL, "moves": []}
	var whole_was := _before()
	var c := cur[cells[0]]
	var moves: Array = []
	var kept := PackedInt32Array()
	# packed, the new ones go in right after the last of their colour (at
	# the end with none), and the buttons past that slide along to make
	# room for them
	var held := _pack(moves)
	var n := mini(room, cells.size())
	var at := held
	for p in held:
		if tin[p] == c:
			at = p + 1
	for p in range(held - 1, at - 1, -1):
		tin[p + n] = tin[p]
		tin[p] = -1
		moves.append([SLIDE, p, p + n, tin[p + n]])
	for g in cells:
		if room <= 0:
			kept.append(g)
			continue
		tin[at] = c
		cur[g] = -1
		room -= 1
		moves.append([TO_TIN, g, at, c])
		at += 1
	return _after({"moves": moves, "kept": kept}, whole_was)

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
	taps = taps_before
	history = []
	_recount()

## Every button sewn, for a finished daily reopened.
func finish(used := -1) -> void:
	if in_parts() and part < parts.size() - 1:
		_enter_part(parts.size() - 1)
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
			if int(m[0]) == SLIDE:
				continue
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
	# a picture in parts is shared whole, read off its letters
	var size := whole_size()
	var names: Array = []
	for y in size.y:
		for x in size.x:
			if in_parts():
				var ch := String(whole[y])[x] if x < String(whole[y]).length() else "."
				names.append("" if ch == "." else String(legend.get(ch, "grey")))
			else:
				var s := slot[y * w + x]
				names.append("" if s < 0 else colours[s])
	# A big picture is shared small: a mark is two squares a side there, and
	# the colour most of its squares are (1,024 marks are not a share).
	var step := ceili(float(maxi(size.x, size.y)) / SHARE_MAX)
	for y in range(0, size.y, step):
		for x in range(0, size.x, step):
			var votes := {}
			var top := ""
			for yy in range(y, mini(size.y, y + step)):
				for xx in range(x, mini(size.x, x + step)):
					var named: String = names[yy * size.x + xx]
					var mark := "▫️" if named == "" else String(marks.get(named, "⬜"))
					votes[mark] = int(votes.get(mark, 0)) + 1
					if top == "" or int(votes[mark]) > int(votes[top]):
						top = mark
			out += top
		out += "\n"
	return out.strip_edges()
