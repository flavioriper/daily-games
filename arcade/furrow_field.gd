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
## lie three and two a row, each row half a lot nearer, so the earth
## between them is road; a house, a barn and a mill with turning sails
## stand in the yard behind, trees and hay where a row of two leaves room.
## The plots open from the middle out, as the sim orders them.
##
## **The finger.** A touch or a drag over a ripe lot picks it; with a
## packet in hand (`armed`) it sows that crop instead. A press on the next
## lot's signboard asks the owner to open it (`asked_plot`), and one on a
## lot still growing says so (`waited`) and changes nothing. A drag is
## sampled along its way, so a quick stroke misses no lot.
##
## **Drawing.** The grass, the roads and the buildings are one mesh built
## on resize; every lot's earth, and the pegged-out grass of those not
## open, one more, built when a lot opens. A lot's plants are one cached
## mesh under a transform (they lean in the wind, pop as they grow a stage,
## swell when ripe), and what is picked flies to `fly_to` as its produce's
## mesh, three from a lot. The bars under what is growing, the glints on
## what is ripe, the puffs and the tutorial's finger are one live mesh.

## A press on the next plot's sign.
signal asked_plot
## A press on plot `i`, still growing.
signal waited(i: int)
## A picked crop reached `fly_to`.
signal landed(gold: bool)

const Sim = preload("res://arcade/furrow_sim.gd")
const Art = preload("res://arcade/furrow_art.gd")
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
## The most of the room the yard behind the lots takes, in pixels.
const YARD := 230.0

var sim: RefCounted
## The crop the hand sows, -1 when it picks.
var armed := -1
## Whether a finger plays it; a tutorial page's is played by its script.
var playable := true
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
## The buildings' unit (0: no yard) and the mill's hub.
var _u := 0.0
var _hub := Vector2.ZERO
var _ground: ArrayMesh
var _beds: ArrayMesh
var _beds_for := -1
var _live: ArrayMesh
## A plot as drawn: {stage, pop, pick, wait}, times on `clock`.
var _pl: Array = []
var _fliers: Array = []
var _puffs: Array = []
var _touch := -1
var _mouse := false
var _last := -1
var _last_at := Vector2.ZERO
var _font: Font

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if playable else Control.MOUSE_FILTER_IGNORE
	resized.connect(layout)
	_font = CozyTheme.make().get_font("font", "SheetTitle")
	layout()

## Hands the field a sim; the plants stand as they are, nothing pops.
func lay(game: RefCounted) -> void:
	sim = game
	_pl.clear()
	for i in sim.plots.size():
		_pl.append({"stage": sim.stage(i), "pop": -10.0, "pick": -10.0, "wait": -10.0})
	_fliers.clear()
	_puffs.clear()
	layout()

func layout() -> void:
	if sim == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var room := area if area.has_area() else Rect2(Vector2.ZERO, size)
	var n: int = sim.plots.size()
	# rows of three and two, each half a lot nearer than the last
	var spots: Array = []
	var row := 0
	while spots.size() < n:
		var across := 3 if row % 2 == 0 else 2
		for k in across:
			if spots.size() < n:
				spots.append(Vector2(k - (across - 1) * 0.5, row))
		row += 1
	var yard := minf(YARD, room.size.y * 0.24)
	if yard < 70.0:
		yard = 0.0
	# the lots stand a road apart: `pitch` from one to the next, LOT of it earth
	var pitch := minf(room.size.x / 6.2, (room.size.y - yard) / ((row + 1.2) * Art.RATIO))
	_a = pitch * LOT
	var tall := (row + 1.2) * pitch * Art.RATIO
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
	_u = 0.0 if yard <= 0.0 else clampf(yard / 200.0, 0.4, 1.15)
	var back := top - pitch * 0.02
	var mill := Vector2(room.position.x + room.size.x * 0.85, back - 18.0 * _u)
	_hub = Art.mill_hub(mill, _u)
	_ground = Art.land(size, _mid, pitch, back, _u, mill)
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

# --- time ---

## The field's own clock and what moves on it. The owner steps the sim.
func tick(delta: float) -> void:
	if sim == null:
		return
	clock += delta
	for i in sim.plots.size():
		var st: int = sim.stage(i)
		if st != int(_pl[i].stage):
			_pl[i].stage = st
			_pl[i].pop = clock
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
				_fliers.append({"crop": int(ev.crop), "from": from, "t": -0.06 * k, "gold": bool(ev.gold), "done": false, "lead": k == 0,
					"spin": randf_range(-2.4, 2.4), "side": randf_range(-0.5, 0.5)})
		"sow":
			_pl[int(ev.i)].pop = clock
			_puff(_mid[int(ev.i)], Art.SOIL_HI, 1.5)
		"plot":
			_pl[int(ev.i)].pop = clock
			_beds_for = -1
			_puff(_mid[int(ev.i)], Art.CREAM, 2.4)

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
	elif event is InputEventMouseMotion and _mouse:
		_drag((event as InputEventMouseMotion).position)

func _down(at: Vector2) -> void:
	_last = -1
	_last_at = at
	_over(at, true)

func _drag(at: Vector2) -> void:
	var far := _last_at.distance_to(at)
	var n := maxi(1, int(ceilf(far / (_a * 0.25))))
	for k in range(1, n + 1):
		_over(_last_at.lerp(at, float(k) / n), false)
	_last_at = at

## The finger over a point of the field; `first` on the press itself.
func _over(at: Vector2, first: bool) -> void:
	var i := plot_at(at)
	if i < 0 or (i == _last and not first):
		return
	_last = i
	poke(i, first)

## The hand on plot `i`: by a finger, the tutorial's script or a harness.
func poke(i: int, first := true) -> void:
	var p: Dictionary = sim.plots[i]
	if not p.open:
		if first and i == sim.next_plot():
			asked_plot.emit()
		return
	if armed >= 0:
		sim.sow(i, armed)
	elif not sim.pick(i) and first:
		nod(i)
		waited.emit(i)

# --- drawing ---

func _draw() -> void:
	if sim == null or _ground == null:
		return
	draw_mesh(_ground, null)
	if _u > 0.0:
		draw_mesh(Art.sails(_u), null, Transform2D(0.4 if Motion.reduce else clock * 0.5, _hub))
	if _beds_for != sim.opened():
		_beds_for = sim.opened()
		_beds = _build_beds()
	draw_mesh(_beds, null)
	var still := Motion.reduce
	for i: int in _far:
		var p: Dictionary = sim.plots[i]
		if not p.open:
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
			# the wind leans every plant of the lot the same way
			lean = sin(clock * 1.3 + _mid[i].x * 0.01 + _mid[i].y * 0.02) * (0.03 + 0.015 * st)
			if st >= 3:
				# ripe, the lot asks to be picked: a slow swell
				var bob := sin(clock * 2.6 + i * 0.9)
				sc *= Vector2(1.0, 1.0 + 0.045 * bob)
			var w := clock - float(d.wait)
			if w < Motion.WOBBLE_TIME:
				lean += Motion.wobble_angle(w) * 1.6
		draw_mesh(Art.rows(p.crop, st, _a), null, Transform2D(Vector2(sc.x, 0), Vector2(-lean * sc.y, sc.y), _mid[i]), GILT if p.gold and st >= 3 else Color.WHITE)
	_draw_sign()
	_build_live()
	if _live != null:
		draw_mesh(_live, null)
	var s := unit()
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
		draw_mesh(Art.produce(int(f.crop), s * 0.8), null, Transform2D(float(f.spin) * k, Vector2(big, big), 0.0, at), GILT if f.gold else Color.WHITE)

## Every lot's earth, and the pegged-out grass of those not open: one mesh.
func _build_beds() -> ArrayMesh:
	var b := Face.Builder.new()
	for i: int in _far:
		b.append(Art.earth(_a) if sim.plots[i].open else Art.lot_empty(_a), Transform2D(0.0, _mid[i]))
	return b.mesh()

## The signboard on the next plot, with its price.
func _draw_sign() -> void:
	var i: int = sim.next_plot()
	if i < 0:
		return
	var w := _a * 0.9
	var foot: Vector2 = _mid[i] + Vector2(0, _a * 0.22)
	var can: bool = sim.seeds >= sim.plot_price()
	var hop := 0.0
	if can and not Motion.reduce:
		hop = absf(sin(clock * 3.0)) * _a * 0.05
	var wob := 0.0
	var wt := clock - float(_pl[i].wait)
	if wt < Motion.WOBBLE_TIME and not Motion.reduce:
		wob = Motion.wobble_angle(wt)
	var xf := Transform2D(wob, foot - Vector2(0, hop))
	draw_mesh(Art.signboard(w), null, xf, Color.WHITE if can else Color(1, 1, 1, 0.85))
	var fs := int(w * 0.24)
	var text := Locale.number(sim.plot_price())
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mid := Vector2(0, -w * 0.5 * 0.8 - 2.0)
	var icon := fs * 0.9
	draw_set_transform_matrix(xf)
	draw_mesh(Art.seed_icon(icon), null, Transform2D(0.0, mid + Vector2(-tw * 0.5 - 2.0, 0)))
	draw_string(_font, mid + Vector2(-tw * 0.5 + icon * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK if can else Color(Art.INK, 0.6))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## The bars under what grows, the glints on what is ripe, the puffs and the
## tutorial's finger: one mesh a frame.
func _build_live() -> void:
	var b := Face.Builder.new()
	var s := unit()
	for i in sim.plots.size():
		var p: Dictionary = sim.plots[i]
		if not p.open:
			continue
		var at: Vector2 = _mid[i]
		if not p.ripe:
			# at the lot's near corner
			var w := _a * 0.56
			var tall := maxf(7.0, _a * 0.055)
			var from := at + Vector2(-w * 0.5, _a * Art.RATIO * 0.8)
			b.fan(Face.Builder.round_rect(from - Vector2(3, 3), Vector2(w + 6.0, tall + 6.0), tall * 0.5 + 3.0), Color(Art.CREAM, 0.9))
			b.fan(Face.Builder.round_rect(from, Vector2(w, tall), tall * 0.5), Color(Art.SOIL_DARK, 0.5))
			var part: float = sim.grown(i)
			if part > 0.02:
				b.fan(Face.Builder.round_rect(from, Vector2(maxf(tall, w * part), tall), tall * 0.5), Art.LEAF)
		elif not Motion.reduce:
			for k in 2:
				var beat := 0.5 + 0.5 * sin(clock * 2.2 + i * 2.1 + k * 2.6)
				var top: Vector2 = at + Art.row_at(_a, (i + k * 2) % Art.ROWS, (i * 2 + k) % Art.ROWS) - Vector2(s * 0.3, s * 0.7)
				Rewards.glint(b, top, s * (0.16 + 0.16 * beat), clock * 0.8 + i + k, Color(1, 1, 0.92, 0.5 + 0.4 * beat))
			if p.gold:
				for k in 4:
					var a := clock * 1.4 + TAU * k / 4.0
					Rewards.glint(b, at + Vector2(cos(a) * _a * 0.7, -s * 0.5 + sin(a) * _a * 0.36), s * 0.26, -clock + k, Color(Art.GOLD, 0.95))
	for puff: Dictionary in _puffs:
		var k := float(puff.t) / PUFF
		var at: Vector2 = puff.at
		var r := s * float(puff.big) * (0.3 + 0.7 * k)
		b.stroke(Face.Builder.ring(at, r * 1.6, r * 1.6 * Art.RATIO), maxf(1.5, s * 0.1 * (1.0 - k)), Color(puff.col, 0.8 * (1.0 - k)), true)
		for j in 5:
			var dir := Vector2.from_angle(-PI * (0.1 + 0.2 * j))
			b.disc(at + dir * r * 1.3 + Vector2(0, -s * 0.3 * k), s * 0.08 * (1.0 - k), Color(puff.col, 1.0 - k))
	if finger.x >= 0.0:
		var r := s * (0.36 if finger_down else 0.44)
		b.disc(finger, r, Color(1, 1, 1, 0.55 if finger_down else 0.35))
		b.stroke(Face.Builder.ring(finger, r, r), 4.0, Color(Art.INK, 0.5), true)
	_live = b.mesh()
