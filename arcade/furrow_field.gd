extends Control

## Furrow's land as it is drawn and touched (spec
## docs/superpowers/specs/2026-10-11-arcade-furrow-design.md). The game's
## screen (arcade/furrow_screen.gd) lays one over its whole rect and the
## tutorial's pages (ui/hud/furrow_tutorial_diagram.gd) a small one; both
## hand it a sim (arcade/furrow_sim.gd), step it with `tick` and show what
## the sim's events did with `play`.
##
## **The land is seen from a corner** (the user, 2026-10-11, over a picture
## of a farm drawn that way: "this is what i was thinking"). A plot is a
## lot: a diamond of turned earth planted with rows of one crop. The lots
## lie three and two a row, each row half a lot nearer, and a lot that is
## open has road round it; the rest is meadow. Behind them is the yard: a
## house, a barn and a mill with turning sails, and before those the two
## round pens, the coop's on the left and the pasture on the right. The
## plots open from the middle out, as the sim orders them.
##
## **The finger.** A touch or a drag over a ripe lot picks it, over a dead
## one clears it, and over a bare one sows the packet in hand (`armed`);
## with none in hand a bare lot says so (`bare`). A press on the next lot's
## signboard asks the owner to open it (`asked_plot`), and one on a lot
## still growing says so (`waited`) and changes nothing. In the coop a
## finger gathers the eggs it comes near; in the pasture it milks a full
## cow. A fox is shooed by a touch. A drag is sampled along its way, so a
## quick stroke misses nothing.
##
## **Looking at a thing.** The first touch of a real finger on a crop, a
## hen or a cow does nothing but ask for its card (`about`), and a finger
## held still HOLD seconds on one asks again (the user, 2026-10-12: "when
## user click on the plant for the first time it should display a dialog
## ... if user want to see again, must hold touch on it for a while"). The
## tutorial's script and a harness press through `poke`, which never asks.
##
## **Drawing.** The meadow, the roads and the buildings are one mesh built
## on resize and when a lot opens; every lot's earth one more. A lot's
## plants are one cached mesh under a transform (they lean in the wind, pop
## as they grow a stage, swell when ripe), a pen is two (its ground and far
## fence, then its near fence over the animals), an animal a cached mesh
## under a transform. The bars, the glints, the puffs, the smoke, the
## butterflies and the tutorial's finger are one live mesh.

## A press on the next plot's sign.
signal asked_plot
## A press on plot `i`, still growing.
signal waited(i: int)
## A press on plot `i`, bare, with no packet in hand.
signal bare(i: int)
## A picked crop, an egg or a bottle reached `fly_to`.
signal landed(gold: bool)
## A press on a pen not built yet ("coop" or "cow"), and one on a built
## pen's own ground.
signal asked_pen(kind: String)
signal opened_pen(kind: String)
## A hen touched with no egg by her, and cow `k` touched before she is full.
signal petted(at: Vector2)
signal cow_waited(k: int)
## A thing asked about: "crop" (`i` its plot), "hen" or "cow" (`i` the cow).
signal about(kind: String, i: int)

const Sim = preload("res://arcade/furrow_sim.gd")
const Art = preload("res://arcade/furrow_art.gd")
const Animals = preload("res://arcade/furrow_animals.gd")
const Face = preload("res://ui/faces/face.gd")
const Rewards = preload("res://arcade/rewards.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")

## A lot's plants popping in, a picked crop's flight, a puff's life.
const POP := 0.36
const FLY := 0.52
const PUFF := 0.45
## How many crops fly off a picked lot.
const FLIERS := 3
## What a golden lot is tinted.
const GILT := Color(1.0, 0.88, 0.5)
## How much of the way from one lot to the next is its earth; the rest is road.
const LOT := 0.82
## The most of the room the yard behind the lots takes, in pixels, and the
## least it is drawn in.
const YARD := 440.0
const YARD_MIN := 150.0
## The seconds a finger rests on a thing to ask about it, and how far an
## egg or an animal may be from the finger that takes it.
const HOLD := 0.5
const REACH := 46.0
## A ripe lot shows how long it still keeps once this much of it is gone.
const WARN := 0.6
## The fox's leaving, in seconds.
const FLEE := 0.7

var sim: RefCounted
## The crop the hand sows, -1 when it holds no packet.
var armed := -1
## Whether a finger plays it; a tutorial page's is played by its script.
var playable := true
## A page of the pens alone: no lots, no yard.
var only_pens := false
## The rect the land stands in, in this control's pixels: all of it when
## empty. The screen keeps its plates and its tray clear with this.
var area := Rect2()
## Where a picked crop flies, in this control's pixels.
var fly_to := Vector2.ZERO
var clock := 0.0
## The tutorial's finger: where it is and whether it is down (x < 0: none).
var finger := Vector2(-1, -1)
var finger_down := false

## A lot's half-width, each plot's middle, the plots far to near, and the
## plots as they are read (row by row, left to right).
var _a := 1.0
var _mid: Array = []
var _far: Array = []
var _read: Array = []
## The buildings' unit (0: no yard), the mill's hub and the chimney's top.
var _u := 0.0
var _hub := Vector2.ZERO
var _smoke := Vector2.ZERO
## The pens: {kind: {c, rx, ry}}; empty with no room for them.
var _pens := {}
var _ground: ArrayMesh
var _ground_for := -1
var _beds: ArrayMesh
var _beds_for := -1
var _live: ArrayMesh
## A plot as drawn: {stage, pop, pick, wait}, times on `clock`.
var _pl: Array = []
var _fliers: Array = []
var _puffs: Array = []
## The coop's birds as drawn: {kind ("hen", "rooster", "chick"), q (where,
## in the pen's own unit round), to, wait, face, hop}; the eggs: {q, born};
## the cows: {q, to, wait, face, hop}.
var _birds: Array = []
var _eggs: Array = []
var _cows: Array = []
## The fox leaving: where from, and since when (-1: not).
var _fox_from := Vector2.ZERO
var _fox_left := -10.0
var _touch := -1
var _mouse := false
var _last := -1
var _last_at := Vector2.ZERO
## What a resting finger is on: {kind, i, at, t0}; empty when on nothing.
var _hold := {}
var _font: Font
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if playable else Control.MOUSE_FILTER_IGNORE
	resized.connect(layout)
	_font = CozyTheme.make().get_font("font", "SheetTitle")
	_rng.seed = 2026
	layout()

## Hands the field a sim; the plants stand as they are, nothing pops.
func lay(game: RefCounted) -> void:
	sim = game
	_pl.clear()
	for i in sim.plots.size():
		_pl.append({"stage": sim.stage(i), "pop": -10.0, "pick": -10.0, "wait": -10.0})
	_fliers.clear()
	_puffs.clear()
	_birds.clear()
	_eggs.clear()
	_cows.clear()
	_hold = {}
	layout()
	_sync(false)

func layout() -> void:
	if sim == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var room := area if area.has_area() else Rect2(Vector2.ZERO, size)
	var n: int = sim.plots.size()
	_pens = {}
	if only_pens:
		# the two pens side by side, and the lots nowhere
		var ry := minf(room.size.y * 0.3, room.size.x * 0.11)
		var rx := minf(room.size.x * 0.225, ry * 2.6)
		var y := room.position.y + room.size.y * 0.58
		_pens = {"coop": {"c": Vector2(room.position.x + room.size.x * 0.26, y), "rx": rx, "ry": ry},
			"cow": {"c": Vector2(room.position.x + room.size.x * 0.74, y), "rx": rx, "ry": ry}}
		_mid.resize(n)
		_mid.fill(Vector2(-9999, -9999))
		_far = []
		_read = range(n)
		_a = rx * 0.6
		_u = 0.0
		_ground = Art.land(size, [], [], _a, 0.0, {})
		_ground_for = sim.opened()
		_beds_for = -1
		queue_redraw()
		return
	# rows of three and two, each half a lot nearer than the last
	var spots: Array = []
	var row := 0
	while spots.size() < n:
		var across := 3 if row % 2 == 0 else 2
		for k in across:
			if spots.size() < n:
				spots.append(Vector2(k - (across - 1) * 0.5, row))
		row += 1
	var yard := YARD_MIN if room.size.y * 0.36 >= YARD_MIN else 0.0
	# the lots stand a road apart: `pitch` from one to the next, LOT of it earth
	var pitch := minf(room.size.x / 6.2, (room.size.y - yard) / ((row + 1.2) * Art.RATIO))
	_a = pitch * LOT
	var tall := (row + 1.2) * pitch * Art.RATIO
	# the yard takes the room the lots leave
	if yard > 0.0:
		yard = clampf(room.size.y - tall, YARD_MIN, YARD)
	var top := room.position.y + yard + maxf(0.0, room.size.y - yard - tall) * 0.5
	for k in spots.size():
		var s: Vector2 = spots[k]
		spots[k] = Vector2(room.get_center().x + s.x * 2.0 * pitch, top + pitch * Art.RATIO * (1.0 + s.y))
	# the plots open from the middle out: the sim's order, on these spots
	var heart := Vector2(room.get_center().x, top + tall * 0.42)
	var by_heart := spots.duplicate()
	by_heart.sort_custom(func(p: Vector2, q: Vector2) -> bool:
		var dp := ((p - heart) * Vector2(1.0, 1.0 / Art.RATIO)).length_squared()
		var dq := ((q - heart) * Vector2(1.0, 1.0 / Art.RATIO)).length_squared()
		return dp < dq if not is_equal_approx(dp, dq) else (p.y < q.y or (p.y == q.y and p.x < q.x)))
	_mid.resize(n)
	for rank in n:
		_mid[sim.order[rank]] = by_heart[rank]
	_far = range(n)
	_far.sort_custom(func(i: int, j: int) -> bool: return _mid[i].y < _mid[j].y or (_mid[i].y == _mid[j].y and _mid[i].x < _mid[j].x))
	_read = _far.duplicate()
	_u = 0.0 if yard <= 0.0 else clampf(yard / 300.0 * 0.8, 0.4, 1.1)
	var spots_yard := {}
	if _u > 0.0:
		# the pens before the buildings, their near rims at the lots' far corners
		var rx := minf(room.size.x * 0.225, yard * 0.56)
		var ry := minf(yard * 0.21, rx * 0.5)
		var y := top + pitch * Art.RATIO * (1.0 - LOT) - ry - 2.0
		_pens = {"coop": {"c": Vector2(room.position.x + room.size.x * 0.265, y), "rx": rx, "ry": ry},
			"cow": {"c": Vector2(room.position.x + room.size.x * 0.735, y), "rx": rx, "ry": ry}}
		var back := y - ry * 0.86
		var x0 := room.position.x
		var w := room.size.x
		spots_yard = {"house": Vector2(x0 + w * 0.2, back), "barn": Vector2(x0 + w * 0.8, back), "mill": Vector2(x0 + w * 0.5, back - 6.0 * _u),
			"trees": [[Vector2(x0 + w * 0.03, back - 8.0 * _u), 1.05], [Vector2(x0 + w * 0.375, back - 22.0 * _u), 0.8], [Vector2(x0 + w * 0.635, back - 20.0 * _u), 0.85, true],
				[Vector2(x0 + w * 0.975, back - 4.0 * _u), 1.0]]}
		_hub = Art.mill_hub(spots_yard.mill, _u)
		_smoke = Art.chimney(spots_yard.house, _u)
	var open: Array = []
	for i in n:
		open.append(bool(sim.plots[i].open))
	_ground = Art.land(size, _mid, open, pitch, _u, spots_yard)
	_ground_for = sim.opened()
	_beds_for = -1
	queue_redraw()

# --- where things are ---

## A plot's middle.
func bed_at(i: int) -> Vector2:
	return _mid[i]

func plant_at(i: int) -> Vector2:
	return _mid[i]

## Above a plot's plants, where a word about it is lettered.
func over(i: int) -> Vector2:
	return _mid[i] - Vector2(0, _a * (Art.RATIO + 0.2))

func unit() -> float:
	return _a * 0.3

## The plot `k`th as the land is read: row by row from the far one, left
## to right. A tutorial's script names plots this way.
func place(k: int) -> int:
	return _read[clampi(k, 0, _read.size() - 1)]

func plot_at(p: Vector2) -> int:
	var best := -1
	# a finger on the road takes the lot it is nearest
	var near := 1.0 / LOT
	for i in _mid.size():
		var d: Vector2 = p - _mid[i]
		var k := absf(d.x) / _a + absf(d.y) / (_a * Art.RATIO)
		if k < near:
			near = k
			best = i
	return best

func has_pens() -> bool:
	return not _pens.is_empty()

## A pen's middle, and the place above it for a word.
func pen_at(kind: String) -> Vector2:
	return _pens[kind].c if _pens.has(kind) else size * 0.5

func pen_over(kind: String) -> Vector2:
	return pen_at(kind) - Vector2(0, float(_pens[kind].ry) + 30.0) if _pens.has(kind) else size * 0.5

## Where `q` of a pen's own round is on the field.
func _in_pen(kind: String, q: Vector2) -> Vector2:
	var pen: Dictionary = _pens[kind]
	return (pen.c as Vector2) + Vector2(q.x * float(pen.rx), q.y * float(pen.ry))

## The middle of the hens' house, or of the pasture's trough: a press
## there opens the shed at that pen's page. Bare ground opens nothing, so a
## stroke for the eggs can begin anywhere.
func _house(kind: String) -> Vector2:
	var pen: Dictionary = _pens[kind]
	if kind == "coop":
		return (pen.c as Vector2) + Vector2(-float(pen.rx) * 0.5, -float(pen.ry) * 0.3 - float(pen.ry) * 0.36)
	return (pen.c as Vector2) + Vector2(float(pen.rx) * 0.48, -float(pen.ry) * 0.36 - float(pen.ry) * 0.14)

## The pen a point is in: "coop", "cow" or "".
func pen_of(p: Vector2) -> String:
	for kind: String in _pens:
		var pen: Dictionary = _pens[kind]
		var d: Vector2 = (p - (pen.c as Vector2)) / Vector2(float(pen.rx) + 12.0, float(pen.ry) + 14.0)
		if d.length() < 1.0:
			return kind
	return ""

func _bird_size() -> float:
	return float(_pens.coop.ry) * 0.5 if _pens.has("coop") else 30.0

func _cow_size() -> float:
	return float(_pens.cow.ry) * 1.25 if _pens.has("cow") else 70.0

## A point of a pen named in the pen's own round, for a script.
func pen_point(kind: String, q: Vector2) -> Vector2:
	return _in_pen(kind, q) if _pens.has(kind) else size * 0.5

## Lays the eggs and stands the cows where a page's script wants them.
func set_eggs(qs: Array) -> void:
	_eggs.clear()
	for q: Vector2 in qs:
		_eggs.append({"q": q, "born": clock - 10.0})

func set_cows(qs: Array) -> void:
	for k in mini(qs.size(), _cows.size()):
		_cows[k].q = qs[k]
		_cows[k].to = qs[k]
		_cows[k].wait = 1000.0

## A finger at `at`, pressed by a script: `first` on the press itself.
func press(at: Vector2, first: bool) -> void:
	_over(at, first)

## Where egg `k` lies and where cow `k` stands, for a script or a harness.
func egg_at(k: int) -> Vector2:
	return _in_pen("coop", _eggs[k].q) if k >= 0 and k < _eggs.size() else pen_at("coop")

func cow_at(k: int) -> Vector2:
	return _in_pen("cow", _cows[k].q) - Vector2(0, _cow_size() * 0.36) if k >= 0 and k < _cows.size() else pen_at("cow")

func hen_at(k: int) -> Vector2:
	return _in_pen("coop", _birds[k].q) - Vector2(0, _bird_size() * 0.4) if k >= 0 and k < _birds.size() else pen_at("coop")

func egg_count() -> int:
	return _eggs.size()

## Where the fox is on its way to the fence's gap; INF with none.
func fox_at() -> Vector2:
	if sim == null or float(sim.fox) <= 0.0 or not _pens.has("coop"):
		return Vector2.INF
	var k := 1.0 - float(sim.fox) / Sim.FOX_TIME
	return _fox_start().lerp(_fox_goal(), k * k * (3.0 - 2.0 * k))

func _fox_goal() -> Vector2:
	var pen: Dictionary = _pens.coop
	return (pen.c as Vector2) + Animals.rim(float(pen.rx) + 16.0, float(pen.ry) + 14.0, (Animals.GAP.x + Animals.GAP.y) * 0.5)

func _fox_start() -> Vector2:
	return Vector2(-80.0, _fox_goal().y + 40.0)

# --- time ---

## A place in a pen's round for an animal to walk to: clear of the hens'
## house in the coop and of the trough in the pasture.
func _spot(kind: String) -> Vector2:
	for tries in 12:
		var q := Vector2(_rng.randf_range(-0.78, 0.78), _rng.randf_range(-0.5, 0.72))
		if q.length() > 0.8:
			continue
		if kind == "coop" and q.x < -0.12 and q.y < 0.08:
			continue
		if kind == "cow" and (q.x > 0.14 and q.y < 0.0 or absf(q.x) > 0.62 or q.y < -0.3):
			continue
		return q
	return Vector2(0.2, 0.4) if kind == "coop" else Vector2(-0.2, 0.3)

func _bird(kind: String, at := Vector2.INF) -> Dictionary:
	var q := at if at != Vector2.INF else _spot("coop")
	return {"kind": kind, "q": q, "to": q, "wait": _rng.randf_range(0.2, 3.0), "face": 1.0 if _rng.randf() < 0.5 else -1.0, "hop": -10.0}

func _count(kind: String) -> int:
	var n := 0
	for b: Dictionary in _birds:
		if b.kind == kind:
			n += 1
	return n

func _drop(kind: String) -> Vector2:
	for k in range(_birds.size() - 1, -1, -1):
		if _birds[k].kind == kind:
			var q: Vector2 = _birds[k].q
			_birds.remove_at(k)
			return q
	return Vector2.ZERO

## Makes what is drawn in the pens what the sim holds; `live` puffs where
## something came or went.
func _sync(live := true) -> void:
	if sim == null or _pens.is_empty():
		return
	var want := {"hen": int(sim.hens) if sim.coop else 0, "chick": (sim.chicks as Array).size() if sim.coop else 0, "rooster": 1 if sim.coop and sim.rooster else 0}
	for kind: String in want:
		while _count(kind) < int(want[kind]):
			_birds.append(_bird(kind))
			if live:
				_puff(_in_pen("coop", _birds[-1].q), Art.CREAM, 1.2)
		while _count(kind) > int(want[kind]):
			_drop(kind)
	var eggs: int = sim.eggs if sim.coop else 0
	while _eggs.size() < eggs:
		_eggs.append({"q": _spot("coop"), "born": clock - 10.0})
	while _eggs.size() > eggs:
		_eggs.pop_back()
	var cows: int = (sim.cows as Array).size() if sim.pasture else 0
	while _cows.size() < cows:
		var q := _spot("cow")
		_cows.append({"q": q, "to": q, "wait": _rng.randf_range(1.0, 6.0), "face": 1.0 if _cows.size() % 2 == 0 else -1.0, "hop": -10.0})
		if live:
			_puff(_in_pen("cow", q), Art.CREAM, 2.0)
	while _cows.size() > cows:
		_cows.pop_back()

func _wander(list: Array, kind: String, delta: float) -> void:
	for b: Dictionary in list:
		var speed := 0.07 if kind == "cow" else 0.42 if b.get("kind", "") == "chick" else 0.26
		if float(b.wait) > 0.0:
			b.wait = float(b.wait) - delta
			if float(b.wait) <= 0.0:
				b.to = _spot(kind)
			continue
		var d: Vector2 = (b.to as Vector2) - (b.q as Vector2)
		if d.length() < speed * delta:
			b.q = b.to
			b.wait = _rng.randf_range(3.0, 9.0) if kind == "cow" else _rng.randf_range(0.8, 4.0)
		else:
			b.q = (b.q as Vector2) + d.normalized() * speed * delta
			if absf(d.x) > 0.02:
				b.face = signf(d.x)

## The field's own clock and what moves on it. The owner steps the sim.
func tick(delta: float) -> void:
	if sim == null:
		return
	clock += delta
	if _ground_for != sim.opened():
		layout()
	for i in sim.plots.size():
		var st: int = sim.stage(i)
		if st != int(_pl[i].stage):
			_pl[i].stage = st
			_pl[i].pop = clock
	_sync()
	if not Motion.reduce:
		_wander(_birds, "coop", delta)
		_wander(_cows, "cow", delta)
	for f: Dictionary in _fliers:
		f.t = float(f.t) + delta
		if float(f.t) >= FLY and not f.done:
			f.done = true
			if f.lead:
				landed.emit(bool(f.gold))
	_fliers = _fliers.filter(func(f: Dictionary) -> bool: return not f.done)
	for p: Dictionary in _puffs:
		p.t = float(p.t) + delta
	_puffs = _puffs.filter(func(p: Dictionary) -> bool: return float(p.t) < PUFF)
	# a finger resting on a thing asks about it
	if not _hold.is_empty() and clock - float(_hold.t0) >= HOLD:
		var h := _hold
		_hold = {}
		_touch = -1
		_mouse = false
		about.emit(String(h.kind), int(h.i))
	queue_redraw()

## What an event of the sim's looks like on the field.
func play(ev: Dictionary) -> void:
	match String(ev.type):
		"pick":
			var i := int(ev.i)
			_pl[i].pick = clock
			_puff(_mid[i], Art.SOIL_HI, 1.5)
			if Motion.reduce:
				landed.emit(bool(ev.gold))
				return
			for k in FLIERS:
				var from: Vector2 = _mid[i] + Art.row_at(_a, randi() % Art.ROWS, randi() % Art.ROWS) - Vector2(0, _a * 0.1)
				_fly(Art.produce(int(ev.crop), unit() * 0.8), from, -0.06 * k, bool(ev.gold), k == 0)
		"sow":
			_pl[int(ev.i)].pop = clock
			_puff(_mid[int(ev.i)], Art.SOIL_HI, 1.5)
		"clear", "dig":
			_puff(_mid[int(ev.i)], Art.DRY_HI, 1.6)
		"dead":
			_puff(_mid[int(ev.i)], Art.DRY, 1.2)
		"plot":
			_pl[int(ev.i)].pop = clock
			_beds_for = -1
			layout()
			_puff(_mid[int(ev.i)], Art.CREAM, 2.4)
		"egg":
			# under the hen that laid it, who hops
			if _pens.has("coop") and _eggs.size() < int(sim.eggs):
				var q := _spot("coop")
				var hens: Array = _birds.filter(func(b: Dictionary) -> bool: return b.kind == "hen")
				if not hens.is_empty():
					var hen: Dictionary = hens[_rng.randi() % hens.size()]
					hen.hop = clock
					q = ((hen.q as Vector2) + Vector2(-0.08 * float(hen.face), 0.06)).limit_length(0.82)
				_eggs.append({"q": q, "born": clock})
				_puff(_in_pen("coop", q), Art.CREAM, 0.45)
		"chick":
			if _pens.has("coop"):
				var q := _spot("coop")
				_birds.append(_bird("chick", q))
				_puff(_in_pen("coop", q), Animals.CHICK, 1.4)
		"grown":
			if _pens.has("coop") and _count("chick") > 0:
				var q := _drop("chick")
				_birds.append(_bird("hen", q))
				_birds[-1].hop = clock
				_puff(_in_pen("coop", q), Art.CREAM, 1.6)
		"milk":
			var k := int(ev.k)
			if k < _cows.size():
				_cows[k].hop = clock
				var from := cow_at(k)
				_puff(from, Color.WHITE, 1.4)
				if Motion.reduce:
					landed.emit(false)
				else:
					_fly(Animals.bottle(unit() * 1.5), from, 0.0, false, true)
		"full":
			if int(ev.k) < _cows.size():
				_cows[int(ev.k)].hop = clock
		"took":
			# the hen nearest the gap goes with it
			if _pens.has("coop"):
				var goal := _fox_goal()
				_fox_from = goal
				_fox_left = clock
				var best := -1
				for k in _birds.size():
					if _birds[k].kind == "hen" and (best < 0 or _in_pen("coop", _birds[k].q).distance_to(goal) < _in_pen("coop", _birds[best].q).distance_to(goal)):
						best = k
				if best >= 0:
					_puff(_in_pen("coop", _birds[best].q), Art.CREAM, 2.6)
					_birds.remove_at(best)
		"shoo":
			_fox_left = clock
		"bought":
			match String(ev.what):
				"coop", "pasture":
					var kind := "coop" if ev.what == "coop" else "cow"
					if _pens.has(kind):
						_puff(pen_at(kind), Art.CREAM, 4.0)
				"fence":
					if _pens.has("coop"):
						_puff(_fox_goal(), Art.WOOD_HI, 2.4)
		"fence_down":
			if _pens.has("coop"):
				_puff(_fox_goal(), Art.WOOD_DEEP, 2.0)

func _fly(mesh: ArrayMesh, from: Vector2, delay: float, gold: bool, lead: bool) -> void:
	_fliers.append({"mesh": mesh, "from": from, "t": delay, "gold": gold, "done": false, "lead": lead, "spin": randf_range(-2.4, 2.4), "side": randf_range(-0.5, 0.5)})

func _puff(at: Vector2, col: Color, big := 1.0) -> void:
	if not Motion.reduce:
		_puffs.append({"at": at, "t": 0.0, "col": col, "big": big})

## A growing lot nodding at a touch that could not pick it.
func nod(i: int) -> void:
	_pl[i].wait = clock

# --- the finger ---

func _gui_input(event: InputEvent) -> void:
	if not playable or sim == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1 and not _mouse:
			_touch = t.index
			_down(t.position)
		elif not t.pressed and t.index == _touch:
			_touch = -1
			_hold = {}
	elif event is InputEventScreenDrag:
		if (event as InputEventScreenDrag).index == _touch:
			_drag((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		if m.pressed and _touch == -1:
			_mouse = true
			_down(m.position)
		elif not m.pressed:
			_mouse = false
			_hold = {}
	elif event is InputEventMouseMotion and _mouse:
		_drag((event as InputEventMouseMotion).position)

## What a point of the field holds that has a card: {kind, i}, or empty.
func _thing_at(at: Vector2) -> Dictionary:
	match pen_of(at):
		"coop":
			if sim.coop and _near(_birds, "coop", at, _bird_size() * 0.4) >= 0:
				return {"kind": "hen", "i": 0}
			return {}
		"cow":
			var k := _near(_cows, "cow", at, _cow_size() * 0.36) if sim.pasture else -1
			return {"kind": "cow", "i": k} if k >= 0 else {}
	var i := plot_at(at)
	if i >= 0 and sim.plots[i].open and int(sim.plots[i].crop) != Sim.BARE and not sim.plots[i].dead:
		return {"kind": "crop", "i": i}
	return {}

func _key(thing: Dictionary) -> String:
	return String(Sim.CROPS[int(sim.plots[int(thing.i)].crop)].id) if thing.kind == "crop" else String(thing.kind)

func _down(at: Vector2) -> void:
	_last = -1
	_last_at = at
	_hold = {}
	if fox_at().distance_to(at) < REACH * 1.6:
		sim.shoo()
		return
	var thing := _thing_at(at)
	# an egg by the finger is gathered before the hen beside it is looked at
	if not thing.is_empty() and not (thing.kind == "hen" and _egg_near(at) >= 0):
		if sim.see(_key(thing)):
			# the first touch on a thing only shows its card
			_last = int(thing.i) if thing.kind == "crop" else -1
			about.emit(String(thing.kind), int(thing.i))
			_touch = -1
			_mouse = false
			return
		_hold = {"kind": thing.kind, "i": int(thing.i), "at": at, "t0": clock}
	_over(at, true)
	# what the press picked or milked is no longer there to be asked about
	if not _hold.is_empty() and _thing_at(at).get("kind", "") != _hold.kind:
		_hold = {}

func _drag(at: Vector2) -> void:
	if not _hold.is_empty() and (_hold.at as Vector2).distance_to(at) > maxf(12.0, _a * 0.2):
		_hold = {}
	var far := _last_at.distance_to(at)
	var n := maxi(1, int(ceilf(far / (_a * 0.25))))
	for k in range(1, n + 1):
		_over(_last_at.lerp(at, float(k) / n), false)
	_last_at = at

## The nearest of `list` (a pen's animals) within `reach` of `at`, -1 with none.
func _near(list: Array, kind: String, at: Vector2, lift: float, reach := REACH) -> int:
	var best := -1
	var near := reach
	for k in list.size():
		var d := (_in_pen(kind, list[k].q) - Vector2(0, lift)).distance_to(at)
		if d < near:
			near = d
			best = k
	return best

func _egg_near(at: Vector2) -> int:
	return _near(_eggs, "coop", at, 4.0)

## The finger over a point of the field; `first` on the press itself.
func _over(at: Vector2, first: bool) -> void:
	var pen := pen_of(at)
	if pen != "":
		_last = -1
		_in(pen, at, first)
		return
	var i := plot_at(at)
	if i < 0 or (i == _last and not first):
		return
	_last = i
	poke(i, first)

## The finger in a pen.
func _in(pen: String, at: Vector2, first: bool) -> void:
	if pen == "coop":
		if not sim.coop:
			if first:
				asked_pen.emit("coop")
			return
		var e := _egg_near(at)
		if e >= 0:
			take_egg(e)
		elif first:
			var h := _near(_birds, "coop", at, _bird_size() * 0.4)
			if h >= 0:
				_birds[h].hop = clock
				petted.emit(hen_at(h))
			elif at.distance_to(_house("coop")) < REACH:
				opened_pen.emit("coop")
		return
	if not sim.pasture:
		if first:
			asked_pen.emit("cow")
		return
	var k := _near(_cows, "cow", at, _cow_size() * 0.36, REACH * 1.2)
	if k >= 0:
		poke_cow(k, first)
	elif first and at.distance_to(_house("cow")) < REACH:
		opened_pen.emit("cow")

## Egg `e` gathered: by a finger, the tutorial's script or a harness.
func take_egg(e: int) -> bool:
	if e < 0 or e >= _eggs.size():
		return false
	var from := egg_at(e)
	_eggs.remove_at(e)
	if not sim.gather():
		return false
	_puff(from, Art.CREAM, 0.45)
	if Motion.reduce:
		landed.emit(false)
	else:
		_fly(Animals.egg(unit() * 1.1), from - Vector2(0, 8.0), 0.0, false, true)
	return true

## The hand on cow `k`.
func poke_cow(k: int, first := true) -> void:
	if not sim.milk(k) and first:
		_cows[k].hop = clock
		cow_waited.emit(k)

## The hand on plot `i`: by a finger, the tutorial's script or a harness.
func poke(i: int, first := true) -> void:
	var p: Dictionary = sim.plots[i]
	if not p.open:
		if first and i == sim.next_plot():
			asked_plot.emit()
		return
	if p.dead:
		sim.clear(i)
	elif p.ripe:
		sim.pick(i)
	elif int(p.crop) == Sim.BARE:
		if armed >= 0:
			sim.sow(i, armed)
		elif first:
			bare.emit(i)
	elif first:
		nod(i)
		waited.emit(i)

# --- drawing ---

func _draw() -> void:
	if sim == null or _ground == null:
		return
	var still := Motion.reduce
	draw_mesh(_ground, null)
	if _u > 0.0:
		draw_mesh(Art.sails(_u), null, Transform2D(0.4 if still else clock * 0.5, _hub))
	if _beds_for != sim.opened():
		_beds_for = sim.opened()
		_beds = _build_beds()
	if _beds != null:
		draw_mesh(_beds, null)
	_draw_pens(still)
	for i: int in _far:
		var p: Dictionary = sim.plots[i]
		if not p.open or int(p.crop) == Sim.BARE:
			continue
		var d: Dictionary = _pl[i]
		var st := int(d.stage)
		var sc := Vector2.ONE
		var lean := 0.0
		if not still:
			# a stage popping in: up from most of its size, past it, and home
			var k := clampf((clock - float(d.pop)) / POP, 0.0, 1.0)
			var grow := 0.6 + 0.4 * Motion.back_out(k)
			sc = Vector2(grow, grow)
			if k < 1.0:
				sc *= Vector2(1.0 + 0.1 * sin(k * PI), 1.0 - 0.08 * sin(k * PI))
			if st != Sim.DEAD:
				# the wind leans every plant of the lot the same way
				lean = sin(clock * 1.3 + _mid[i].x * 0.01 + _mid[i].y * 0.02) * (0.03 + 0.015 * st)
			if st == 3:
				# ripe, the lot asks to be picked: a slow swell, quicker as it turns
				var bob := sin(clock * (2.6 if sim.fresh(i) > 0.25 else 5.0) + i * 0.9)
				sc *= Vector2(1.0, 1.0 + 0.045 * bob)
			var w := clock - float(d.wait)
			if w < Motion.WOBBLE_TIME:
				lean += Motion.wobble_angle(w) * 1.6
		draw_mesh(Art.rows(p.crop, st, _a), null, Transform2D(Vector2(sc.x, 0), Vector2(-lean * sc.y, sc.y), _mid[i]), GILT if p.gold and st == 3 else Color.WHITE)
	_draw_sign()
	_build_live()
	if _live != null:
		draw_mesh(_live, null)
	_draw_bubbles(still)
	for f: Dictionary in _fliers:
		if float(f.t) < 0.0:
			continue
		var k := clampf(float(f.t) / FLY, 0.0, 1.0)
		var from: Vector2 = f.from
		var top := from.lerp(fly_to, 0.3) + Vector2(float(f.side) * _a, -_a * 0.9)
		var e := k * k * (3.0 - 2.0 * k)
		var at := from.lerp(top, e).lerp(top.lerp(fly_to, e), e)
		# out of the earth with a pop, then smaller all the way to the plate
		var big := (0.6 + 0.6 * Motion.back_out(minf(k / 0.25, 1.0))) * (1.0 - 0.6 * maxf(0.0, (k - 0.25) / 0.75))
		draw_mesh(f.mesh, null, Transform2D(float(f.spin) * k, Vector2(big, big), 0.0, at), GILT if f.gold else Color.WHITE)

## The two pens: the ground and the far fence, the animals far to near,
## the near fence, and the fox outside it.
func _draw_pens(still: bool) -> void:
	if _pens.is_empty():
		return
	for kind: String in ["coop", "cow"]:
		var pen: Dictionary = _pens[kind]
		var built: bool = sim.coop if kind == "coop" else sim.pasture
		var c: Vector2 = pen.c
		draw_mesh(Animals.pen_back(kind, float(pen.rx), float(pen.ry), built), null, Transform2D(0.0, c))
		if not built:
			continue
		if kind == "coop":
			var s := _bird_size()
			for e: Dictionary in _eggs:
				var k := clampf((clock - float(e.born)) / 0.3, 0.0, 1.0)
				var big := 1.0 if still else Motion.back_out(k)
				var glint := 1.0 if still else 1.0 + 0.05 * sin(clock * 3.0 + (e.q as Vector2).x * 9.0)
				draw_mesh(Animals.egg(s * 0.42), null, Transform2D(0.0, Vector2(big, big * glint), 0.0, _in_pen("coop", e.q)))
			var order := _birds.duplicate()
			order.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return (p.q as Vector2).y < (q.q as Vector2).y)
			for b: Dictionary in order:
				var at := _in_pen("coop", b.q)
				var hop := 0.0
				var tilt := 0.0
				if not still:
					var h := clock - float(b.hop)
					if h < 0.4:
						hop = sin(h / 0.4 * PI) * s * 0.3
					if float(b.wait) <= 0.0:
						hop += absf(sin(clock * 11.0 + at.x)) * s * 0.06
					elif fmod(clock + at.x * 0.07, 3.4) < 0.5 and b.kind != "chick":
						# a peck at the ground
						tilt = sin(fmod(clock + at.x * 0.07, 3.4) / 0.5 * PI) * 0.5
				var mesh: ArrayMesh = Animals.chick(s * 0.5) if b.kind == "chick" else Animals.hen(s * (1.14 if b.kind == "rooster" else 1.0), b.kind == "rooster")
				draw_mesh(mesh, null, Transform2D(tilt * float(b.face), Vector2(float(b.face), 1.0), 0.0, at - Vector2(0, hop)))
		else:
			var s := _cow_size()
			var order: Array = range(_cows.size())
			order.sort_custom(func(p: int, q: int) -> bool: return (_cows[p].q as Vector2).y < (_cows[q].q as Vector2).y)
			for k: int in order:
				var cow: Dictionary = _cows[k]
				var at := _in_pen("cow", cow.q)
				var sc := Vector2(float(cow.face), 1.0)
				var hop := 0.0
				if not still:
					var h := clock - float(cow.hop)
					if h < 0.4:
						hop = sin(h / 0.4 * PI) * s * 0.08
						sc *= Vector2(1.0 + 0.05 * sin(h / 0.4 * PI), 1.0 - 0.05 * sin(h / 0.4 * PI))
					else:
						# she breathes
						sc.y *= 1.0 + 0.012 * sin(clock * 1.7 + k * 1.3)
				draw_mesh(Animals.cow(s, sim.cow_full(k)), null, Transform2D(0.0, sc, 0.0, at - Vector2(0, hop)))
		var whole: bool = kind == "cow" or float(sim.fence_t) > 0.0
		draw_mesh(Animals.pen_front(float(pen.rx), float(pen.ry), whole), null, Transform2D(0.0, c))
	# the fox, coming or going
	var fox := fox_at()
	var s := _bird_size() * 2.1
	if fox != Vector2.INF:
		var bob := 0.0 if still else absf(sin(clock * 9.0)) * 4.0
		draw_mesh(Animals.fox(s), null, Transform2D(0.0, fox - Vector2(0, bob)))
	elif clock - _fox_left < FLEE and not still:
		var k := (clock - _fox_left) / FLEE
		var from := _fox_from if _fox_from != Vector2.ZERO else _fox_goal()
		var at := from.lerp(_fox_start(), k * k)
		draw_mesh(Animals.fox(s), null, Transform2D(0.0, Vector2(-1.0, 1.0), 0.0, at - Vector2(0, absf(sin(clock * 16.0)) * 7.0)))

## A full cow's word for it, over her head.
func _draw_bubbles(still: bool) -> void:
	if not _pens.has("cow") or not sim.pasture:
		return
	var s := _cow_size()
	for k in _cows.size():
		if not sim.cow_full(k):
			continue
		var at := _in_pen("cow", _cows[k].q) + Vector2(float(_cows[k].face) * s * 0.3, -s * 0.8)
		var bob := 0.0 if still else sin(clock * 3.0 + k) * 3.0
		var big := 1.0 if still else 1.0 + 0.05 * sin(clock * 6.0 + k)
		draw_mesh(Animals.bubble(s * 0.34), null, Transform2D(0.0, Vector2(big, big), 0.0, at + Vector2(0, bob)))

## Every open lot's earth, and the pegged-out grass of the one that opens
## next: one mesh.
func _build_beds() -> ArrayMesh:
	var b := Face.Builder.new()
	var next: int = sim.next_plot()
	for i: int in _far:
		if sim.plots[i].open:
			b.append(Art.earth(_a), Transform2D(0.0, _mid[i]))
		elif i == next:
			b.append(Art.lot_empty(_a), Transform2D(0.0, _mid[i]))
	return b.mesh() if not b.verts.is_empty() else null

## A signboard with a price on it, its foot at `foot`.
func _board(foot: Vector2, w: float, price: int, wob: float) -> void:
	var can: bool = sim.seeds >= price
	var hop := 0.0
	if can and not Motion.reduce:
		hop = absf(sin(clock * 3.0)) * w * 0.055
	var xf := Transform2D(wob, foot - Vector2(0, hop))
	draw_mesh(Art.signboard(w), null, xf, Color.WHITE if can else Color(1, 1, 1, 0.88))
	var fs := int(w * 0.24)
	var text := Locale.number(price)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mid := Vector2(0, -w * 0.5 * 0.8 - 2.0)
	var icon := fs * 0.9
	draw_set_transform_matrix(xf)
	draw_mesh(Art.seed_icon(icon), null, Transform2D(0.0, mid + Vector2(-tw * 0.5 - 2.0, 0)))
	draw_string(_font, mid + Vector2(-tw * 0.5 + icon * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK if can else Color(Art.INK, 0.6))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## The signboards: on the next plot, and on a pen not built.
func _draw_sign() -> void:
	var w := _a * 0.9
	var i: int = sim.next_plot()
	if i >= 0 and not only_pens:
		var wob := 0.0
		var wt := clock - float(_pl[i].wait)
		if wt < Motion.WOBBLE_TIME and not Motion.reduce:
			wob = Motion.wobble_angle(wt)
		_board(_mid[i] + Vector2(0, _a * 0.22), w, sim.plot_price(), wob)
	if _pens.has("coop") and not sim.coop:
		_board(pen_at("coop") + Vector2(0, w * 0.3), w, sim.price("coop"), 0.0)
	if _pens.has("cow") and not sim.pasture:
		_board(pen_at("cow") + Vector2(0, w * 0.3), w, sim.price("pasture"), 0.0)

## A small rounded bar, `part` of it filled.
func _bar(b: Face.Builder, from: Vector2, w: float, tall: float, part: float, col: Color) -> void:
	b.fan(Face.Builder.round_rect(from - Vector2(2.5, 2.5), Vector2(w + 5.0, tall + 5.0), tall * 0.5 + 2.5), Color(Art.CREAM, 0.92))
	b.fan(Face.Builder.round_rect(from, Vector2(w, tall), tall * 0.5), Color(Art.SOIL_DARK, 0.45))
	if part > 0.02:
		b.fan(Face.Builder.round_rect(from, Vector2(maxf(tall, w * part), tall), tall * 0.5), col)

## The clouds' shade, the smoke, the bars under what grows, the glints on
## what is ripe, the butterflies, the puffs and the tutorial's finger: one
## mesh a frame.
func _build_live() -> void:
	var b := Face.Builder.new()
	var s := unit()
	var still := Motion.reduce
	if not still and not only_pens and size.y > 700.0:
		# two clouds' shade drifting over the land, and the chimney's smoke
		for k in 2:
			var x := fposmod(clock * (9.0 + 4.0 * k) + k * size.x * 0.7, size.x + 700.0) - 350.0
			Art.soft(b, Vector2(x, size.y * (0.42 + 0.3 * k)), 300.0, 120.0, Color(0.1, 0.2, 0.1, 0.07), 0.4, 20)
		if _u > 0.0:
			for k in 4:
				var t := fposmod(clock * 0.22 + k * 0.25, 1.0)
				var at := _smoke + Vector2(sin(t * 4.0 + k) * 6.0 * t + 14.0 * t, -64.0 * t) * _u
				Art.soft(b, at, (7.0 + 16.0 * t) * _u, (6.0 + 12.0 * t) * _u, Color(1, 1, 1, 0.55 * (1.0 - t) * minf(1.0, t * 6.0)), 0.5, 12)
	for i in sim.plots.size():
		var p: Dictionary = sim.plots[i]
		if not p.open or only_pens:
			continue
		var at: Vector2 = _mid[i]
		var w := _a * 0.5
		var tall := maxf(6.0, _a * 0.05)
		var from := at + Vector2(-w * 0.5, _a * Art.RATIO * 0.82)
		if int(p.crop) == Sim.BARE:
			# bare earth asks for a packet: a seed over it, and a ring when one is in hand
			var beat := 0.0 if still else sin(clock * 2.4 + i * 0.7)
			if armed >= 0:
				b.stroke(Art.rdiamond(at + Vector2(0, -_a * 0.012), _a, 0.8 + 0.03 * beat, _a * 0.1), maxf(2.0, _a * 0.024), Color(Art.CREAM, 0.55 + 0.25 * beat), true)
			var c := at - Vector2(0, _a * 0.16 + beat * 2.5)
			b.disc(c + Vector2(0, 2.5), s * 0.52, Color(Art.INK, 0.16))
			b.disc(c, s * 0.5, Color(Art.CREAM, 0.95))
			Art.seed_into(b, c, s * 0.62)
		elif p.dead:
			pass
		elif not p.ripe:
			_bar(b, from, w, tall, sim.grown(i), Art.LEAF)
		else:
			var fresh: float = sim.fresh(i)
			if fresh < WARN:
				# what it still keeps, amber and then red
				var hot := fresh < 0.25
				var col := Color("e2504a") if hot else Art.GOLD
				if hot and not still:
					col = col.lerp(Art.CREAM, 0.3 + 0.3 * sin(clock * 9.0))
				_bar(b, from, w, tall, fresh / WARN, col)
			if not still:
				for k in 2:
					var beat := 0.5 + 0.5 * sin(clock * 2.2 + i * 2.1 + k * 2.6)
					var top: Vector2 = at + Art.row_at(_a, (i + k * 2) % Art.ROWS, (i * 2 + k) % Art.ROWS) - Vector2(s * 0.3, s * 0.7)
					Rewards.glint(b, top, s * (0.16 + 0.16 * beat), clock * 0.8 + i + k, Color(1, 1, 0.92, 0.5 + 0.4 * beat))
				if p.gold:
					for k in 4:
						var a := clock * 1.4 + TAU * k / 4.0
						Rewards.glint(b, at + Vector2(cos(a) * _a * 0.7, -s * 0.5 + sin(a) * _a * 0.36), s * 0.26, -clock + k, Color(Art.GOLD, 0.95))
	# a cow filling: her bar under her
	if _pens.has("cow") and sim.pasture:
		for k in _cows.size():
			if not sim.cow_full(k):
				var at := _in_pen("cow", _cows[k].q)
				var w := _cow_size() * 0.5
				_bar(b, at + Vector2(-w * 0.5, 7.0), w, 6.0, 1.0 - sim.cow_left(k) / sim.milk_time(), Color("8fc7e8"))
	# the fence down: a mark over the gap
	if _pens.has("coop") and sim.coop and float(sim.fence_t) <= 0.0:
		var at := _fox_goal() + Vector2(0, -34.0 - (0.0 if still else absf(sin(clock * 3.0)) * 5.0))
		b.disc(at + Vector2(0, 3.0), 17.0, Color(Art.INK, 0.2))
		b.disc(at, 16.0, Color("e2504a"))
		b.stroke(PackedVector2Array([at + Vector2(0, -8.0), at + Vector2(0, 1.5)]), 4.5, Color.WHITE)
		b.disc(at + Vector2(0, 8.0), 2.6, Color.WHITE)
	if not still and not only_pens and size.y > 700.0:
		# three butterflies about their own corners of the meadow
		for k in 3:
			var home := Vector2(size.x * [0.16, 0.84, 0.5][k], size.y * [0.62, 0.5, 0.86][k])
			var at := home + Vector2(sin(clock * 0.31 + k * 2.0) * 120.0 + sin(clock * 0.9 + k) * 30.0, cos(clock * 0.23 + k) * 90.0 + sin(clock * 1.3 + k) * 16.0)
			var flap := absf(sin(clock * 13.0 + k))
			var col: Color = [Color("fff6e6"), Color("f6c7d3"), Color("cfd9f7")][k]
			for side in [-1.0, 1.0]:
				b.fan(PackedVector2Array([at, at + Vector2(side * 9.0 * flap, -8.0), at + Vector2(side * 10.0 * flap, 3.0)]), col)
				b.fan(PackedVector2Array([at, at + Vector2(side * 7.0 * flap, 7.0), at + Vector2(side * 2.0 * flap, 6.0)]), col.darkened(0.1))
			b.stroke(PackedVector2Array([at + Vector2(0, -4.0), at + Vector2(0, 5.0)]), 2.0, Color(Art.INK, 0.7))
	for puff: Dictionary in _puffs:
		var k := float(puff.t) / PUFF
		var at: Vector2 = puff.at
		var r := s * float(puff.big) * (0.3 + 0.7 * k)
		b.stroke(Face.Builder.ring(at, r * 1.6, r * 1.6 * Art.RATIO), maxf(1.5, s * 0.1 * (1.0 - k)), Color(puff.col, 0.8 * (1.0 - k)), true)
		for j in 5:
			var dir := Vector2.from_angle(-PI * (0.1 + 0.2 * j))
			b.disc(at + dir * r * 1.3 + Vector2(0, -s * 0.3 * k), s * 0.08 * (1.0 - k), Color(puff.col, 1.0 - k))
	# a finger resting: a ring closing round it
	if not _hold.is_empty():
		var k := clampf((clock - float(_hold.t0)) / HOLD, 0.0, 1.0)
		if k > 0.25:
			var at: Vector2 = _hold.at
			b.stroke(Face.Builder.arc_points(at, s * 1.5, -PI * 0.5, -PI * 0.5 + TAU * (k - 0.25) / 0.75), 6.0, Color(1, 1, 1, 0.9), false)
	if finger.x >= 0.0:
		var r := s * (0.36 if finger_down else 0.44)
		b.disc(finger, r, Color(1, 1, 1, 0.55 if finger_down else 0.35))
		b.stroke(Face.Builder.ring(finger, r, r), 4.0, Color(Art.INK, 0.5), true)
	_live = b.mesh()
