extends RefCounted
## Yarn Hoop's rules, scene-free (puzzles/hoop2d.gd draws them;
## docs/agents/boards/hoop.md).
##
## A picture lies hidden on the linen of an embroidery hoop, cut into
## panels: triangles and four-sided pieces, each one colour. Only their
## corners show, as pins, and a small mark in each panel says how many
## corners it has. The player drags a thread from pin to pin; a thread is
## taken only along a panel's side, and a panel whose every side is threaded
## fills with knitting in its colour. Every panel filled is the picture.
##
## The panels are cut from the day's bead picture (the bank Pixel Garden,
## Button Box and Toy Cannons deal from, or the day's themed one): a lattice
## of pins a stride apart, jittered off the rng, each cell of it cut on the
## diagonal that keeps its two halves the more one colour, each half the
## colour most of its beads are, and a half that is mostly bare linen left
## out. Two halves of one colour in a cell are sometimes one four-sided
## panel. So the same seed always cuts the same picture.

const ThemedPictures = preload("res://core/themed_pictures.gd")
const BANK := "res://content/pixel_garden.json"
## The bank's band a difficulty deals from, and the side the day's themed
## picture of that band has.
const BANDS := [0, 1, 2, 3]
const INSANE := 3
## About how many panels a band cuts its picture into.
const PANELS := [26, 50, 90, 140]
## How far a pin is pushed off the lattice, a share of the stride.
const JITTER := [0.16, 0.2, 0.22, 0.22]
## How often two halves of one colour are one four-sided panel.
const QUADS := [0.55, 0.45, 0.4, 0.35]
## A half is kept when bare linen is under this share of its beads.
const BARE_MAX := 0.5
## Beads read a side of a cell, to colour its halves.
const SAMPLES := 6
const HINTS_BY := [3, 3, 2, 2]

static var _bank := {}
static var _bank_read := false

var band := 0
var name_key := ""
## The bead picture the panels were cut from, a colour index a square.
var w := 0
var h := 0
var colours: Array[String] = []
var picture := PackedInt32Array()

## The pins, in the picture's squares.
var pins := PackedVector2Array()
## A panel: its corners, round its outline; its colour index; its sides.
var panels: Array = []
var colour := PackedInt32Array()
var panel_sides: Array = []
## A side: its two pins (the lower first) and the one or two panels it bounds.
var sides: Array[Vector2i] = []
var side_panels: Array = []
## A pin's sides.
var pin_sides: Array = []
var _side_of := {}

## What is threaded and filled.
var laid := PackedByteArray()
var filled := PackedByteArray()
## The sides of a panel not threaded yet, and of a pin.
var open_sides := PackedInt32Array()
var pin_open := PackedInt32Array()
var done := 0
var threads := 0
## Threads asked for that are no panel's side.
var refused := 0

static func bank() -> Dictionary:
	if not _bank_read:
		_bank_read = true
		var f := FileAccess.open(BANK, FileAccess.READ)
		if f != null:
			var doc = JSON.parse_string(f.get_as_text())
			if doc is Dictionary:
				_bank = doc
	return _bank

static func pictures(band_: int) -> Array:
	var doc := bank()
	var k: int = BANDS[clampi(band_, 0, BANDS.size() - 1)]
	if doc.get("bands") is Array and k < (doc.bands as Array).size():
		return doc.bands[k]
	return []

static func hints_for(band_: int) -> int:
	return HINTS_BY[clampi(band_, 0, HINTS_BY.size() - 1)]

## The day's picture out of the bank, cut. `daily_key` is
## PuzzleBase.daily_key: a daily takes the day's themed picture of its
## band's side when this phone holds one (core/themed_pictures.gd).
func setup(rng: RandomNumberGenerator, difficulty: int, daily_key := 0) -> void:
	band = clampi(difficulty, 0, PANELS.size() - 1)
	var doc := bank()
	var pics := pictures(band)
	if pics.is_empty():
		adopt({"name": "", "rows": ["..rr..", ".rrrr.", "rrggrr", "rggggr", ".gggg.", "..gg.."]},
			{"r": "red", "g": "green"}, rng)
		return
	# The bank's pick is drawn either way, so the cut that follows is the same
	# on a phone with the day and one without.
	var pic: Dictionary = pics[rng.randi_range(0, pics.size() - 1)]
	var themed := ThemedPictures.picture(daily_key, (pics[0].rows as Array).size())
	adopt(themed if not themed.is_empty() else pic, doc.get("palette", {}), rng)

## Cuts `pic` ({name, rows}, its letters read through `legend`).
func adopt(pic: Dictionary, legend: Dictionary, rng: RandomNumberGenerator) -> void:
	_read(pic, legend)
	_cut(rng, PANELS[band])
	reset()

func _read(pic: Dictionary, legend: Dictionary) -> void:
	var rows: Array = pic.rows
	h = rows.size()
	w = String(rows[0]).length()
	name_key = String(pic.get("name", ""))
	colours = []
	picture = PackedInt32Array()
	picture.resize(w * h)
	picture.fill(-1)
	for y in h:
		var row := String(rows[y])
		for x in mini(w, row.length()):
			var ch := row[x]
			if ch == ".":
				continue
			var named := String(legend.get(ch, "grey"))
			var k := colours.find(named)
			if k < 0:
				k = colours.size()
				colours.append(named)
			picture[y * w + x] = k

## The bead under a point of the picture, -1 bare or off it.
func bead(p: Vector2) -> int:
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return picture[y * w + x]

## The cut: a lattice over the beads at a stride that gives about `want`
## panels.
func _cut(rng: RandomNumberGenerator, want: int) -> void:
	var beads := 0
	for c in picture:
		if c >= 0:
			beads += 1
	# a cell is two halves, a quad now and then one: about 1.7 panels a cell
	var stride := sqrt(1.7 * maxf(1.0, beads) / float(want))
	stride = maxf(stride, 1.0)
	var nx := maxi(2, int(round(w / stride)))
	var ny := maxi(2, int(round(h / stride)))
	var sx := float(w) / nx
	var sy := float(h) / ny
	var jit: float = JITTER[band]
	var lattice := PackedVector2Array()
	for j in ny + 1:
		for i in nx + 1:
			var p := Vector2(i * sx, j * sy)
			if i > 0 and i < nx:
				p.x += rng.randf_range(-jit, jit) * sx
			if j > 0 and j < ny:
				p.y += rng.randf_range(-jit, jit) * sy
			lattice.append(p)
	var raw_panels: Array = []
	var raw_colour: Array = []
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 2
			var d := a + nx + 1
			# corners clockwise on screen: a top left, b top right, c bottom
			# right, d bottom left. Cut a-c or b-d, whichever keeps its halves
			# the more one colour.
			var cut_ac := [[a, b, c], [a, c, d]]
			var cut_bd := [[a, b, d], [b, c, d]]
			var ac := [_read_half(lattice, cut_ac[0]), _read_half(lattice, cut_ac[1])]
			var bd := [_read_half(lattice, cut_bd[0]), _read_half(lattice, cut_bd[1])]
			var score_ac: int = int(ac[0][1]) + int(ac[1][1])
			var score_bd: int = int(bd[0][1]) + int(bd[1][1])
			var use_ac := score_ac > score_bd or (score_ac == score_bd and rng.randf() < 0.5)
			var halves: Array = cut_ac if use_ac else cut_bd
			var read: Array = ac if use_ac else bd
			var kept: Array = []
			for k in 2:
				if int(read[k][0]) >= 0:
					kept.append(k)
			if kept.size() == 2 and int(read[0][0]) == int(read[1][0]) and rng.randf() < float(QUADS[band]):
				raw_panels.append([a, b, c, d])
				raw_colour.append(int(read[0][0]))
				continue
			for k: int in kept:
				raw_panels.append(halves[k])
				raw_colour.append(int(read[k][0]))
	_index(lattice, raw_panels, raw_colour)

## What a half's beads say: [its colour or -1, how many beads agree].
func _read_half(lattice: PackedVector2Array, tri: Array) -> Array:
	var p0: Vector2 = lattice[tri[0]]
	var p1: Vector2 = lattice[tri[1]]
	var p2: Vector2 = lattice[tri[2]]
	var count := {}
	var n := 0
	for u in SAMPLES:
		for v in SAMPLES - u:
			# barycentric points spread over the half, its corners left out
			var a := (u + 0.5) / (SAMPLES + 0.5)
			var b := (v + 0.5) / (SAMPLES + 0.5)
			if a + b >= 1.0:
				continue
			var p := p0 + (p1 - p0) * a + (p2 - p0) * b
			var c := bead(p)
			count[c] = int(count.get(c, 0)) + 1
			n += 1
	var best := -1
	var best_n := 0
	for c: int in count:
		if c >= 0 and int(count[c]) > best_n:
			best = c
			best_n = count[c]
	if n == 0 or float(count.get(-1, 0)) / n >= BARE_MAX:
		return [-1, int(count.get(-1, 0))]
	return [best, best_n]

## Pins kept are the panels' corners only, numbered afresh; sides are every
## panel's outline, shared where two panels meet.
func _index(lattice: PackedVector2Array, raw_panels: Array, raw_colour: Array) -> void:
	var renum := {}
	pins = PackedVector2Array()
	panels = []
	colour = PackedInt32Array()
	for k in raw_panels.size():
		var corners := PackedInt32Array()
		for v: int in raw_panels[k]:
			if not renum.has(v):
				renum[v] = pins.size()
				pins.append(lattice[v])
			corners.append(renum[v])
		panels.append(corners)
		colour.append(raw_colour[k])
	_link()

## The sides, from the panels.
func _link() -> void:
	sides = []
	side_panels = []
	panel_sides = []
	_side_of = {}
	pin_sides = []
	for p in pins.size():
		pin_sides.append(PackedInt32Array())
	for k in panels.size():
		var corners: PackedInt32Array = panels[k]
		var own := PackedInt32Array()
		for m in corners.size():
			var a := corners[m]
			var b := corners[(m + 1) % corners.size()]
			var key := _key(a, b)
			var s: int = _side_of.get(key, -1)
			if s < 0:
				s = sides.size()
				_side_of[key] = s
				sides.append(Vector2i(mini(a, b), maxi(a, b)))
				side_panels.append(PackedInt32Array())
				# packed arrays are values: written back, not appended in place
				var pa: PackedInt32Array = pin_sides[a]
				pa.append(s)
				pin_sides[a] = pa
				var pb: PackedInt32Array = pin_sides[b]
				pb.append(s)
				pin_sides[b] = pb
			var sp: PackedInt32Array = side_panels[s]
			sp.append(k)
			side_panels[s] = sp
			own.append(s)
		panel_sides.append(own)

func _key(a: int, b: int) -> int:
	return mini(a, b) * 65536 + maxi(a, b)

## A hand-made picture (the tutorial's): pins and panels as given, colours
## named.
func adopt_laid(pin_list: Array, panel_list: Array, named: Array) -> void:
	w = 1
	h = 1
	name_key = ""
	picture = PackedInt32Array()
	colours = []
	pins = PackedVector2Array(pin_list)
	panels = []
	colour = PackedInt32Array()
	for k in panel_list.size():
		panels.append(PackedInt32Array(panel_list[k]))
		var c := colours.find(String(named[k]))
		if c < 0:
			c = colours.size()
			colours.append(String(named[k]))
		colour.append(c)
	_link()
	reset()

## Everything unthreaded.
func reset() -> void:
	laid = PackedByteArray()
	laid.resize(sides.size())
	filled = PackedByteArray()
	filled.resize(panels.size())
	open_sides = PackedInt32Array()
	for k in panels.size():
		open_sides.append((panel_sides[k] as PackedInt32Array).size())
	pin_open = PackedInt32Array()
	for p in pins.size():
		pin_open.append((pin_sides[p] as PackedInt32Array).size())
	done = 0
	threads = 0
	refused = 0

## The side between pins `a` and `b`, -1 for none.
func side_between(a: int, b: int) -> int:
	return _side_of.get(_key(a, b), -1)

## A thread from `a` to `b`: -1 when it is no panel's side (it is refused
## and counted), else the panels it closed (none, one or two). A side
## already threaded closes nothing.
const REFUSED := -1
func lay(a: int, b: int) -> Variant:
	var s := side_between(a, b)
	if s < 0:
		refused += 1
		return REFUSED
	return lay_side(s)

func lay_side(s: int) -> PackedInt32Array:
	var closed := PackedInt32Array()
	if laid[s]:
		return closed
	laid[s] = 1
	threads += 1
	pin_open[sides[s].x] -= 1
	pin_open[sides[s].y] -= 1
	for k in side_panels[s]:
		open_sides[k] -= 1
		if open_sides[k] == 0 and not filled[k]:
			filled[k] = 1
			done += 1
			closed.append(k)
	return closed

## The side the bulb threads: one of the panel nearest done (fewest sides
## open, the first such panel), so the hint closes something soon.
func hint() -> int:
	var best := -1
	var best_open := 1 << 20
	for k in panels.size():
		if filled[k]:
			continue
		if open_sides[k] < best_open:
			best_open = open_sides[k]
			best = k
	if best < 0:
		return -1
	for s in panel_sides[best]:
		if not laid[s]:
			return s
	return -1

func is_solved() -> bool:
	return not panels.is_empty() and done >= panels.size()

## Every side threaded: a completed day put back.
func finish() -> void:
	reset()
	for s in sides.size():
		lay_side(s)

## A panel's middle, in the picture's squares.
func centre(k: int) -> Vector2:
	var c := Vector2.ZERO
	var corners: PackedInt32Array = panels[k]
	for v in corners:
		c += pins[v]
	return c / corners.size()

func outline(k: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in panels[k]:
		out.append(pins[v])
	return out

func share_glyphs() -> String:
	return "🧶 %d" % panels.size()
