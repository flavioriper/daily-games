extends RefCounted
## Toy Cannons' rules, scene-free (puzzles/train2d.gd draws them;
## docs/agents/boards/train.md). Built as Toy Train and turned into a
## shooter a day later: the names here are the train's still. An engine is
## a cannon, its room the corks it has left, the siding the tray it waits
## in and the shed the toy box; "takes a block" is "shoots it".
##
## A picture of toy blocks lies on the rug with a loop of track round it.
## Little engines wait in the shed in columns, each painted one colour and
## each with a number: the blocks it still has room for. An engine sent out
## goes round the loop, and round again for as long as a lap takes anything
## (since 2026-10-13: it was once round). At every stop it looks straight
## across the rug at the nearest block in that line, and takes it if it is
## its own colour. An engine with no room left goes home for good. One
## that comes round from a lap that took nothing waits in the siding, five
## places, to be sent again.
##
## The loop moves by ticks (`tick`), a stop a tick, so the same taps on the
## same ticks always play the same game and a probe with no screen can prove
## a deal. The numbers of a colour's engines add up to exactly its blocks.

const Pal = preload("res://core/palette.gd")
const BANK := "res://content/pixel_garden.json"
## The bank's band a difficulty deals from: 10 squares a side on Easy, then
## small ones and a lot of them, 24 on Medium and 32 on Hard and Insane.
const BANDS := [0, 2, 3, 3]
const INSANE := 3
## Engines on the loop at once, waiting at its gate counted.
const ON_LOOP := 5
const SIDING := 5
## Stops between two engines as they enter.
const GAP := 2
## The same on a band: the squares are small past Easy, and a shooter is
## two or three of them long.
const GAPS := [2, 4, 5, 5]
## Columns in the shed, a band.
const SHEDS := [2, 3, 3, 4]
## The least and the most a new engine carries, a band.
const LOADS := [[3, 9], [10, 36], [16, 60], [20, 80]]
## How many engines the deal's own line lets wait in the siding at once: the
## rest of the five are the player's slack.
const REF_PARKED := [1, 2, 3, 4]
## How often the deal stands an engine in the shed before its colour is in
## sight: it has to come out and wait for the ones behind it to be reached.
const EARLY := [0.0, 0.15, 0.25, 0.7]
const HINTS_BY := [3, 3, 2, 2]

## The bold colours a picture is folded into: every bead the bank paints
## with, under the one that stands for its family on the rug.
const FAMILY := {
	"red": "red", "maroon": "red",
	"pink": "pink", "coral": "pink", "rose": "pink",
	"orange": "orange", "rust": "orange",
	"yellow": "yellow", "butter": "yellow",
	"white": "white", "cream": "white", "silver": "white",
	"lilac": "purple", "purple": "purple",
	"sky": "sky", "blue": "blue", "navy": "blue", "teal": "teal",
	"lime": "green", "green": "green", "forest": "green",
	"tan": "brown", "brown": "brown", "dark": "dark", "grey": "grey",
}
## The most colours a picture keeps, a band: a cannon has to be told from
## the next at a glance.
const BOLD := [4, 6, 7, 8]

## A picture is laid on a mat of blocks of one more colour, so the rug is
## full edge to edge: the first of these the picture does not use.
const MATS := ["sky", "cream", "lilac", "teal", "tan", "grey"]

enum { SHED, GATE, LOOP, PARKED, GONE }
enum { OK, REFUSED_BURIED, REFUSED_BUSY, REFUSED_FULL, REFUSED_OVER }
## What a tick says happened, [kind, engine, a, b]:
## ENTER (engine); PICK (engine, cell, run so far); RUN_END (engine, run);
## FULL (engine); PARK (engine, place); HOME (engine, column);
## JAM (engine); WHOLE (-1, colour).
enum { ENTER, PICK, RUN_END, FULL, PARK, HOME, JAM, WHOLE }

## A picture's colours folded into a few bold ones (2026-10-26, `_bolden`).
static var bold := true

static var _bank := {}
static var _bank_read := false

var band := 0
var w := 0
var h := 0
var name_key := ""
var colours: Array[String] = []
## The picture, a colour index a square, -1 bare rug.
var picture := PackedInt32Array()
## The colour index of the mat the picture lies on, -1 for none.
var mat := -1
## The blocks still on the rug.
var grid := PackedInt32Array()
var left := 0
var left_by := PackedInt32Array()

## The engines, an index each.
var colour := PackedInt32Array()
var load_ := PackedInt32Array()
var room := PackedInt32Array()
var where := PackedInt32Array()
## The stop an engine on the loop is at (-1 at the gate), or its place in
## the siding.
var at := PackedInt32Array()
## The column of the shed it stands in, or left.
var col := PackedInt32Array()
## Stops in a row it has taken a block at.
var run := PackedInt32Array()
## Blocks it has taken since it last passed the gate: an engine that comes
## round having taken any goes round again.
var got := PackedInt32Array()

## The shed's columns, the front engine first.
var sheds: Array = []
var _sheds0: Array = []
var siding := PackedInt32Array()
var loop := PackedInt32Array()
var gate := PackedInt32Array()
## The tick an engine at the gate may roll on from, by engine: the screen
## holds one there while it is still flying in from the box (`send`'s
## `wait`), so it never shoots from where it is not.
var _land := {}

var taps := 0
## The taps the deal's own line takes.
var par := 0
## The deal's own line: the engines in the order it sent them.
var line := PackedInt32Array()
## Insane: an engine came round with room and the siding was full.
var jammed := false
var ticks := 0

static func bank() -> Dictionary:
	if not _bank_read:
		_bank_read = true
		var f := FileAccess.open(BANK, FileAccess.READ)
		if f != null:
			var doc = JSON.parse_string(f.get_as_text())
			if doc is Dictionary:
				_bank = doc
	return _bank

## The pictures a difficulty deals from.
static func pictures(band_: int) -> Array:
	var doc := bank()
	var k: int = BANDS[clampi(band_, 0, BANDS.size() - 1)]
	if doc.get("bands") is Array and k < (doc.bands as Array).size():
		return doc.bands[k]
	return []

static func hints_for(band_: int) -> int:
	return HINTS_BY[clampi(band_, 0, HINTS_BY.size() - 1)]

## The day's picture out of the bank and its engines, dealt.
## `daily_key` is PuzzleBase.daily_key: a daily takes the day's themed
## picture of its band's size when this phone holds one
## (core/themed_pictures.gd), and the bank's otherwise. Hard and Insane read
## one band, so on a themed day they are the one picture.
func setup(rng: RandomNumberGenerator, difficulty: int, daily_key := 0) -> void:
	band = clampi(difficulty, 0, SHEDS.size() - 1)
	var doc := bank()
	var pics := pictures(band)
	if pics.is_empty():
		adopt({"name": "", "rows": ["rrgg", "rrgg", "bbyy", "bbyy"]},
			{"r": "red", "g": "green", "b": "blue", "y": "yellow"}, rng)
		return
	# The bank's pick is drawn either way, so the deal's own draws that
	# follow are the same ones on a phone with the day and one without.
	var pic: Dictionary = pics[rng.randi_range(0, pics.size() - 1)]
	var themed := ThemedPictures.picture(daily_key, (pics[0].rows as Array).size())
	adopt(themed if not themed.is_empty() else pic, doc.get("palette", {}), rng)

## Plays `pic` ({name, rows}) with its letters read through `legend`.
func adopt(pic: Dictionary, legend: Dictionary, rng: RandomNumberGenerator) -> void:
	_read(pic, legend)
	if bold:
		_bolden()
	_lay_mat()
	_deal(rng)
	reset()

## The mat under the picture: every bare square a block of the mat's colour.
func _lay_mat() -> void:
	var named := ""
	for m: String in MATS:
		# folded pictures name families: a cream mat by white blocks is the
		# shade problem `_bolden` is there to end
		var f := String(FAMILY.get(m, m)) if bold else m
		if not colours.has(f):
			named = f
			break
	if named == "" or not picture.has(-1):
		return
	mat = colours.size()
	colours.append(named)
	for i in picture.size():
		if picture[i] < 0:
			picture[i] = mat

## A hand-made table (the tutorial's): `engines` is [[colour letter, load,
## column], ...] in the order they stand, front first.
func adopt_laid(rows: Array, legend: Dictionary, engines: Array, columns: int) -> void:
	_read({"name": "", "rows": rows}, legend)
	_clear_engines()
	_sheds0 = []
	for k in columns:
		_sheds0.append(PackedInt32Array())
	for e: Array in engines:
		var c := colours.find(String(legend.get(String(e[0]), "grey")))
		var id := _new_engine(c, int(e[1]), int(e[2]))
		var column: PackedInt32Array = _sheds0[int(e[2])]
		column.append(id)
		_sheds0[int(e[2])] = column
	line = PackedInt32Array(range(colour.size()))
	par = line.size()
	reset()

func _read(pic: Dictionary, legend: Dictionary) -> void:
	var rows: Array = pic.rows
	h = rows.size()
	w = String(rows[0]).length()
	name_key = String(pic.get("name", ""))
	colours = []
	mat = -1
	picture = PackedInt32Array()
	picture.resize(w * h)
	picture.fill(-1)
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
			picture[y * w + x] = k

## Folds the picture's colours into their families, then the nearest two
## families into one until no more than BOLD are left.
func _bolden() -> void:
	var names: Array[String] = []
	var to := PackedInt32Array()
	for named in colours:
		var f := String(FAMILY.get(named, named))
		if not names.has(f):
			names.append(f)
		to.append(names.find(f))
	var count := PackedInt32Array()
	count.resize(names.size())
	count.fill(0)
	for i in picture.size():
		if picture[i] >= 0:
			picture[i] = to[picture[i]]
			count[picture[i]] += 1
	var cap: int = BOLD[clampi(band, 0, BOLD.size() - 1)]
	while names.size() > cap:
		# the two nearest colours, the smaller into the bigger: an eye or a
		# beak keeps its colour while two greens become one
		var least := 0
		var near := 1
		var best := INF
		for i in names.size():
			for j in range(i + 1, names.size()):
				var d := _apart(names[i], names[j])
				if d < best:
					best = d
					least = i if count[i] < count[j] else j
					near = j if least == i else i
		var into := near - 1 if near > least else near
		for i in picture.size():
			if picture[i] == least:
				picture[i] = into
			elif picture[i] > least:
				picture[i] -= 1
		count[near] += count[least]
		count.remove_at(least)
		names.remove_at(least)
	colours = names

## How far apart two named colours look ("redmean" weighted RGB).
static func _apart(a: String, b: String) -> float:
	var x := Pal.PG_BEADS.get(a, Color.GRAY) as Color
	var y := Pal.PG_BEADS.get(b, Color.GRAY) as Color
	var r := (x.r + y.r) * 0.5
	var d := Vector3(x.r - y.r, x.g - y.g, x.b - y.b)
	return sqrt((2.0 + r) * d.x * d.x + 4.0 * d.y * d.y + (3.0 - r) * d.z * d.z)

func _clear_engines() -> void:
	colour = PackedInt32Array()
	load_ = PackedInt32Array()
	room = PackedInt32Array()
	where = PackedInt32Array()
	at = PackedInt32Array()
	col = PackedInt32Array()
	run = PackedInt32Array()
	got = PackedInt32Array()

func _new_engine(c: int, n: int, column: int) -> int:
	colour.append(c)
	load_.append(n)
	room.append(n)
	where.append(SHED)
	at.append(-1)
	col.append(column)
	run.append(0)
	got.append(0)
	return colour.size() - 1

# --- the loop ---

## Stops round the picture: along the foot left to right, up the right
## side, back along the top, down the left side.
func stops() -> int:
	return 2 * (w + h)

## The squares a stop looks along, nearest first, as (first, step, count).
func _sight(s: int) -> Vector3i:
	if s < w:
		return Vector3i((h - 1) * w + s, -w, h)
	s -= w
	if s < h:
		return Vector3i((h - 1 - s) * w + w - 1, -1, w)
	s -= h
	if s < w:
		return Vector3i(w - 1 - s, w, h)
	s -= w
	return Vector3i(s * w, 1, w)

## The nearest block a stop sees on `g`, -1 for none.
func first_seen(g: PackedInt32Array, s: int) -> int:
	var v := _sight(s)
	var i := v.x
	for n in v.z:
		if g[i] >= 0:
			return i
		i += v.y
	return -1

## The same, from where stop `s` last found one: `near` keeps how deep each
## stop has looked on a rug that only loses blocks (the deal's, 1,024 blocks
## and a lap a colour for every engine it makes).
func _seen_from(g: PackedInt32Array, s: int, near: PackedInt32Array) -> int:
	var v := _sight(s)
	var d := near[s]
	var i := v.x + v.y * d
	while d < v.z:
		if g[i] >= 0:
			near[s] = d
			return i
		d += 1
		i += v.y
	near[s] = d
	return -1

## One engine of colour `c` with room for `most` goes once round `g` alone:
## the blocks it takes (and takes off `g`). `near` is `_seen_from`'s, for `g`.
func _lap(g: PackedInt32Array, c: int, most: int, near = null) -> int:
	var deep: PackedInt32Array
	if near == null:
		deep = PackedInt32Array()
		deep.resize(stops())
	else:
		deep = near
	var got := 0
	for s in stops():
		if got >= most:
			break
		var i := _seen_from(g, s, deep)
		if i >= 0 and g[i] == c:
			g[i] = -1
			got += 1
	return got

## The same engine left on the loop: lap after lap until one takes nothing
## or it is full, as `tick` has it.
func _laps(g: PackedInt32Array, c: int, most: int, near = null) -> int:
	var deep: PackedInt32Array
	if near == null:
		deep = PackedInt32Array()
		deep.resize(stops())
	else:
		deep = near
	var total := 0
	while total < most:
		var n := _lap(g, c, most - total, deep)
		if n <= 0:
			break
		total += n
	return total

# --- the deal ---

## Builds the engines by playing the picture away one engine at a time: an
## engine of a colour the loop can see, with a load out of the band's range
## (never more than its colour has left unspoken for). One that cannot fill
## before a lap takes nothing waits in the line's own siding, and goes again as soon as it
## can take something. The line that results is a way to win that never
## holds more than REF_PARKED engines in the siding; the engines are then
## stood in the shed's columns in the order the line sends them.
func _deal(rng: RandomNumberGenerator) -> void:
	_clear_engines()
	var g := picture.duplicate()
	var by := PackedInt32Array()
	by.resize(colours.size())
	by.fill(0)
	var cells := 0
	for v in g:
		if v >= 0:
			by[v] += 1
			cells += 1
	var lo: int = LOADS[band][0]
	var hi: int = LOADS[band][1]
	var allow: int = REF_PARKED[band]
	var parked: Array[int] = []
	var near := PackedInt32Array()
	near.resize(stops())
	var left_room := PackedInt32Array()
	var order := PackedInt32Array()
	line = PackedInt32Array()
	while cells > 0:
		# a waiting engine that can take something goes first
		var best := -1
		var best_n := 0
		for e in parked:
			var n := _laps(g.duplicate(), colour[e], left_room[e], near.duplicate())
			if n > best_n:
				best_n = n
				best = e
		if best >= 0:
			var n := _laps(g, colour[best], left_room[best], near)
			left_room[best] -= n
			by[colour[best]] -= n
			cells -= n
			line.append(best)
			if left_room[best] == 0:
				parked.erase(best)
			continue
		# a new engine: a colour in sight, the more of it in reach the likelier
		var free := by.duplicate()
		for e in parked:
			free[colour[e]] -= left_room[e]
		var reach := PackedInt32Array()
		reach.resize(colours.size())
		var total := 0
		for c in colours.size():
			reach[c] = _laps(g.duplicate(), c, free[c], near.duplicate()) if free[c] > 0 else 0
			total += reach[c]
		if total <= 0:
			break
		var c := 0
		if parked.size() >= allow:
			# the siding is spoken for: the colour with the most in reach
			for k in colours.size():
				if reach[k] > reach[c]:
					c = k
		elif rng.randf() < float(EARLY[band]):
			# an early engine: any colour with blocks unspoken for, in sight
			# or not
			var pool: Array[int] = []
			for k in colours.size():
				if free[k] > 0:
					pool.append(k)
			c = pool[rng.randi_range(0, pool.size() - 1)]
		else:
			var roll := rng.randi_range(0, total - 1)
			for k in colours.size():
				if roll < reach[k]:
					c = k
					break
				roll -= reach[k]
		var n := mini(rng.randi_range(lo, hi), free[c])
		# no crumb of a last engine: a little left over rides on this one
		if free[c] - n < lo and free[c] <= hi + lo:
			n = free[c]
		if n > reach[c] and parked.size() >= allow:
			n = reach[c]
		var id := _new_engine(c, n, 0)
		left_room.append(n)
		order.append(id)
		line.append(id)
		var got := _laps(g, c, n, near)
		left_room[id] -= got
		by[c] -= got
		cells -= got
		if left_room[id] > 0:
			parked.append(id)
	par = line.size()
	# into the columns, in the line's order, the columns kept even
	var k: int = SHEDS[band]
	_sheds0 = []
	for i in k:
		_sheds0.append(PackedInt32Array())
	var most := ceili(float(order.size()) / k)
	for id in order:
		var open: Array[int] = []
		for i in k:
			if (_sheds0[i] as PackedInt32Array).size() < most:
				open.append(i)
		var pick: int = open[rng.randi_range(0, open.size() - 1)]
		var column: PackedInt32Array = _sheds0[pick]
		column.append(id)
		_sheds0[pick] = column
		col[id] = pick

## The table as the day opened it.
func reset() -> void:
	_land = {}
	grid = picture.duplicate()
	left_by = PackedInt32Array()
	left_by.resize(colours.size())
	left_by.fill(0)
	left = 0
	for v in grid:
		if v >= 0:
			left_by[v] += 1
			left += 1
	sheds = []
	for k in _sheds0.size():
		var column: PackedInt32Array = (_sheds0[k] as PackedInt32Array).duplicate()
		sheds.append(column)
		for e in column:
			col[e] = k
	for e in colour.size():
		room[e] = load_[e]
		where[e] = SHED
		at[e] = -1
		run[e] = 0
		got[e] = 0
	siding = PackedInt32Array()
	siding.resize(SIDING)
	siding.fill(-1)
	loop = PackedInt32Array()
	gate = PackedInt32Array()
	taps = 0
	ticks = 0
	jammed = false

## Every block taken, for a finished daily reopened.
func finish(used := -1) -> void:
	reset()
	grid.fill(-1)
	left_by.fill(0)
	left = 0
	for e in colour.size():
		room[e] = 0
		where[e] = GONE
	for k in sheds.size():
		sheds[k] = PackedInt32Array()
	if used >= 0:
		taps = used

func count() -> int:
	var n := 0
	for v in picture:
		if v >= 0:
			n += 1
	return n

func is_solved() -> bool:
	return left == 0 and w > 0

func xy(i: int) -> Vector2i:
	return Vector2i(i % w, i / w)

## Nothing on the loop or at its gate.
func idle() -> bool:
	return loop.is_empty() and gate.is_empty()

func parked() -> int:
	var n := 0
	for e in siding:
		if e >= 0:
			n += 1
	return n

## Whether a tap on engine `e` would send it.
func judge(e: int) -> int:
	if e < 0 or e >= colour.size() or jammed:
		return REFUSED_OVER
	match where[e]:
		SHED:
			var column: PackedInt32Array = sheds[col[e]]
			if column.is_empty() or column[0] != e:
				return REFUSED_BURIED
		PARKED:
			pass
		_:
			return REFUSED_BUSY
	if loop.size() + gate.size() >= ON_LOOP:
		return REFUSED_FULL
	return OK

## Sends engine `e` to the loop's gate: the front of a column, or one out of
## the siding. It rolls on no sooner than `wait` ticks from now.
func send(e: int, wait := 0) -> int:
	var why := judge(e)
	if why != OK:
		return why
	if where[e] == SHED:
		var column: PackedInt32Array = sheds[col[e]]
		column.remove_at(0)
		sheds[col[e]] = column
	else:
		siding[at[e]] = -1
	where[e] = GATE
	at[e] = -1
	run[e] = 0
	got[e] = 0
	gate.append(e)
	if wait > 0:
		_land[e] = ticks + wait
	else:
		_land.erase(e)
	taps += 1
	return OK

## The engines a tap can send now.
func ready_engines() -> PackedInt32Array:
	var out := PackedInt32Array()
	for e in siding:
		if e >= 0:
			out.append(e)
	for column: PackedInt32Array in sheds:
		if not column.is_empty():
			out.append(column[0])
	return out

## One stop on for every engine on the loop, and one in at the gate if the
## way is clear. What happened, in order.
func tick() -> Array:
	var out: Array = []
	if jammed:
		return out
	ticks += 1
	var still := PackedInt32Array()
	for e in loop:
		at[e] += 1
		if at[e] >= stops():
			if got[e] <= 0:
				_run_end(e, out)
				_come_round(e, out)
				continue
			# a lap that took something: round again, the run unbroken
			at[e] = 0
			got[e] = 0
		if _stop(e, out):
			still.append(e)
	loop = still
	if not gate.is_empty() and not jammed:
		var clear := true
		for e in loop:
			if at[e] < GAP:
				clear = false
		if clear and ticks >= int(_land.get(gate[0], 0)):
			var e := gate[0]
			gate.remove_at(0)
			where[e] = LOOP
			at[e] = 0
			out.append([ENTER, e, 0, 0])
			if _stop(e, out):
				loop.append(e)
	return out

## Engine `e` at its stop: takes the block it sees if it is its colour, one
## block a stop (the user, 2026-10-26: "it must shot only 1 box at time";
## a cork that went on through a row was tried that day and taken out).
## False when that filled it and it has gone.
func _stop(e: int, out: Array) -> bool:
	var i := first_seen(grid, at[e])
	if i < 0 or grid[i] != colour[e]:
		_run_end(e, out)
		return true
	var c := grid[i]
	grid[i] = -1
	left -= 1
	left_by[c] -= 1
	room[e] -= 1
	run[e] += 1
	got[e] += 1
	out.append([PICK, e, i, run[e]])
	if room[e] == 0:
		out.append([RUN_END, e, run[e], 0])
		run[e] = 0
		where[e] = GONE
		out.append([FULL, e, 0, 0])
	if left_by[c] == 0:
		out.append([WHOLE, -1, c, 0])
	return room[e] > 0

func _run_end(e: int, out: Array) -> void:
	if run[e] > 0:
		out.append([RUN_END, e, run[e], 0])
	run[e] = 0

## An engine back at the gate from a lap that took nothing: into the siding. With the
## siding full it rolls to the back of its column in the shed, and on Insane
## the day is lost.
func _come_round(e: int, out: Array) -> void:
	for p in SIDING:
		if siding[p] < 0:
			siding[p] = e
			where[e] = PARKED
			at[e] = p
			out.append([PARK, e, p, 0])
			return
	if band >= INSANE:
		jammed = true
		where[e] = GATE
		at[e] = -1
		out.append([JAM, e, 0, 0])
		return
	_to_shed(e)
	out.append([HOME, e, col[e], 0])

func _to_shed(e: int) -> void:
	var column: PackedInt32Array = sheds[col[e]]
	column.append(e)
	sheds[col[e]] = column
	where[e] = SHED
	at[e] = -1

## Insane's way out of a jam (the card's video): the engine at the gate and
## every one in the siding go to the back of their columns.
func rescue() -> void:
	for e in colour.size():
		if where[e] == GATE and not gate.has(e):
			_to_shed(e)
	for p in SIDING:
		if siding[p] >= 0:
			_to_shed(siding[p])
			siding[p] = -1
	jammed = false

## The engine this file's own hand would send now, -1 for none: of those a
## tap can send, the one that takes the most alone on the rug as it lies (one
## that would fill first, and one out of the siding before the shed's). With
## nothing to take, the front of the column whose wanted engine is nearest
## its front.
func hint() -> int:
	var best := -1
	var best_score := 0
	for e in ready_engines():
		var n := _laps(grid.duplicate(), colour[e], room[e])
		if n <= 0:
			continue
		# one that fills frees a place for good; one out of the siding costs
		# no place; a new one that will come back wants a place to come back to
		var score := n * 4 + (1 if where[e] == PARKED else 0)
		if n == room[e]:
			score += 4000
		elif where[e] == PARKED:
			score += 2000
		elif parked() >= SIDING - 1:
			score = 1
		if score > best_score:
			best_score = score
			best = e
	if best >= 0:
		return best
	var depth := 1 << 20
	for column: PackedInt32Array in sheds:
		for d in column.size():
			if d >= depth:
				break
			if _laps(grid.duplicate(), colour[column[d]], room[column[d]]) > 0:
				depth = d
				best = column[0]
				break
	return best

## The picture as it was, a square a block in its nearest emoji colour.
func share_glyphs() -> String:
	var marks := {"red": "🟥", "orange": "🟧", "yellow": "🟨", "cream": "⬜", "white": "⬜", "pink": "🟥",
		"rose": "🟥", "lilac": "🟪", "purple": "🟪", "sky": "🟦", "blue": "🟦", "teal": "🟩", "lime": "🟩",
		"green": "🟩", "forest": "🟩", "tan": "🟧", "brown": "🟫", "dark": "⬛", "grey": "⬜"}
	var out := ""
	for y in h:
		for x in w:
			var s := picture[y * w + x]
			out += "▫️" if s < 0 else String(marks.get(colours[s], "⬜"))
		out += "\n"
	return out.strip_edges()
