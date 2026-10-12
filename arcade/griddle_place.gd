extends Control

## Griddle's world: whichever of the four places is on the screen, edge to
## edge (spec docs/superpowers/specs/2026-10-12-arcade-griddle-design.md).
## Shared by the screen (arcade/griddle_screen.gd) and the tutorial's pages.
## It draws the place from the sim, takes the touch and calls the sim; the
## owner plays the sim's events back into it with `play`, and what a touch
## could not do it says through `refused`.
##
## A place's ground is one cached mesh; a lot's crop, a cow, a person, a
## toastie are cached meshes under a transform; the bars, bubbles, glints
## and what flies from one thing to another are one live mesh a frame.
## Nothing moves with `Motion.reduce` but what is told by position.

## A touch that could not be done: `why` is "short" (coins, `n` missing),
## "full" (the larder), "pass" or "queue" (nothing to sell), "wait" (not
## yet, `n` seconds), "ban", "hush"; `at` is where, in this control.
signal refused(why: String, at: Vector2, n: int)
## An open lot touched that was not ripe: its card is asked for.
signal lot_asked(i: int)
## A touch that did nothing the sim says: the interface's own click.
signal touched(pitch: float)
## A coin landed on the plate.
signal landed

const Sim = preload("res://arcade/griddle_sim.gd")
const Art = preload("res://arcade/griddle_art.gd")
const Animals = preload("res://arcade/furrow_animals.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Rewards = preload("res://arcade/rewards.gd")

const COLS := 3
const ROWS := 4
const YARD_COLS := 4
const FLY := 0.5

var sim: RefCounted
var place := "counter"
## The room the place has between the plates and the tray, in this control.
var area := Rect2()
var playable := true
var font: Font
var clock := 0.0
## Where the coins fly: the coins' plate, in this control's coordinates.
var fly_to := Vector2.ZERO
## The tutorial's finger: where it is, and whether it is down.
var finger := Vector2.INF
var finger_down := false

## The live meshes this frame's _draw handed over, kept until the next.
var _lives: Array = []
## What flies: {kind, from, to, t, life, s}.
var _bits: Array = []
## When a thing last did something, for its bump: "lot3", "cow1", "grill0",
## "till2", "pass", "kettle", "bell", "scraps", "notch1", "jarvet", "sign".
var _at := {}
var _no := {}
var _cart := Vector2.INF
var _cart_to := Vector2.INF
var _cart_until := 0.0
## The queue's faces, the front first: {coat, skin, born}.
var _looks: Array = []
## Those served and walking off: {coat, skin, from, t}.
var _gone: Array = []
var _touch := -1
var _mouse := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 7

## A big number in a signboard's width: 950, 6k, 50k, 3M.
static func short(n: int) -> String:
	if n < 1000:
		return str(n)
	if n < 1000000:
		return ("%dk" % (n / 1000)) if n % 1000 == 0 or n >= 10000 else Locale.number(n / 1000.0, 1) + "k"
	return ("%dM" % (n / 1000000)) if n % 1000000 == 0 or n >= 10000000 else Locale.number(n / 1000000.0, 1) + "M"

func show_place(p: String) -> void:
	place = p
	_bits.clear()
	_gone.clear()
	_cart = Vector2.INF
	_sync_looks()
	queue_redraw()

# --- where things are ---

func _p(u: float, v: float) -> Vector2:
	return area.position + Vector2(area.size.x * u, area.size.y * v)

func barn_h() -> float:
	return area.size.y * 0.15

func lot_rect(i: int) -> Rect2:
	var top := barn_h() + 26.0
	var cell := Vector2(area.size.x / COLS, (area.size.y - top - 10.0) / ROWS)
	var gap := Vector2(22.0, 26.0)
	return Rect2(area.position + Vector2(cell.x * (i % COLS), top + cell.y * (i / COLS)) + gap * 0.5, cell - gap)

func lot_mid(i: int) -> Vector2:
	return lot_rect(i).get_center()

func _next_lot() -> int:
	for i in Sim.LOTS:
		if not sim.lots[i].open:
			return i
	return -1

func barn_door() -> Vector2:
	return _p(0.5, 0.0) + Vector2(0, barn_h() * 0.8)

func stock_at(crop: int) -> Vector2:
	return _p(0.13 if crop == Sim.WHEAT else 0.87, 0.0) + Vector2(0, barn_h() * 0.74)

func wall_h() -> float:
	return area.size.y * 0.13

func slot_rect(k: int) -> Rect2:
	var top := wall_h() + 30.0
	var cell := Vector2(area.size.x / YARD_COLS, area.size.y * 0.27)
	return Rect2(area.position + Vector2(cell.x * (k % YARD_COLS), top + cell.y * (k / YARD_COLS)), cell)

func cow_size() -> float:
	return minf(slot_rect(0).size.x * 0.82, slot_rect(0).size.y * 0.7)

func cow_foot(k: int) -> Vector2:
	var r := slot_rect(k)
	return Vector2(r.get_center().x, r.position.y + r.size.y * 0.84)

func trough_at() -> Vector2:
	return _p(0.28, 0.79)

func shelf_at() -> Vector2:
	return _p(0.2, 0.93)

func scraps_at() -> Vector2:
	return _p(0.84, 0.8)

func stall_sign() -> Vector2:
	return _p(0.6, 0.86)

func cow_sign() -> Vector2:
	var k: int = sim.cows.size()
	if k < YARD_COLS * 2:
		return cow_foot(k)
	return _p(0.6, 0.97)

func back_y() -> float:
	return area.position.y + 190.0

func pass_y() -> float:
	return area.position.y + area.size.y * 0.36

func front_y() -> float:
	return area.position.y + area.size.y * 0.66

func lane_x(k: int) -> float:
	return area.position.x + area.size.x * (0.2 + 0.3 * k)

func grill_at(g: int) -> Vector2:
	return Vector2(lane_x(g), back_y())

func till_at(t: int) -> Vector2:
	return Vector2(lane_x(t) + 76.0, front_y() - 62.0)

func kettle_at() -> Vector2:
	return Vector2(area.position.x + 84.0, pass_y() + 104.0)

func bell_at() -> Vector2:
	return Vector2(area.end.x - 84.0, pass_y() + 104.0)

func pass_at(n: int) -> Vector2:
	var room: int = sim.pass_room()
	var w := area.size.x - 160.0
	return Vector2(area.position.x + 80.0 + w * (n + 0.5) / room, pass_y() - 14.0)

## Where the `k`th of the queue stands: in the till's lane, row by row.
func queue_at(k: int) -> Vector2:
	var lanes: int = sim.tills
	var first := front_y() + 136.0
	# five rows deep at the most: they close up when the square is short
	var gap := minf(100.0, (area.end.y - 16.0 - first) / (Sim.QUEUE - 1))
	return Vector2(lane_x(k % lanes) - 30.0, first + gap * (k / lanes))

func floor_y() -> float:
	return area.position.y + area.size.y * 0.9

func sheet_rect(n: int) -> Rect2:
	var tops := [0.02, 0.235, 0.685]
	var talls := [0.2, 0.435, 0.2]
	return Rect2(_p(0.03, tops[n]), Vector2(area.size.x * 0.94, area.size.y * talls[n]))

func notch_at(v: int) -> Vector2:
	var r := sheet_rect(0)
	return Vector2(r.position.x + r.size.x * (v + 0.5) / Sim.VOLUMES, r.position.y + r.size.y * 0.62)

func notch_size() -> float:
	return minf(sheet_rect(0).size.x / Sim.VOLUMES - 30.0, sheet_rect(0).size.y * 0.62)

func jar_at(k: int) -> Vector2:
	var r := sheet_rect(1)
	return Vector2(r.position.x + r.size.x * (k + 0.5) / Sim.MOODS.size(), r.position.y + r.size.y * 0.4)

func jar_size() -> float:
	return minf(sheet_rect(1).size.x / Sim.MOODS.size() - 70.0, sheet_rect(1).size.y * 0.3)

func favour_rect(k: int) -> Rect2:
	var r := sheet_rect(1)
	var w := r.size.x / Sim.MOODS.size() - 24.0
	return Rect2(jar_at(k).x - w * 0.5, r.end.y - 96.0, w, 76.0)

## A point over a thing, for the owner's letters: "lot", "cow", "grill",
## "till", "queue", "pass", "jar", "barn", "kettle", "bell".
func over(what: String, i := 0) -> Vector2:
	match what:
		"lot":
			return lot_mid(i) - Vector2(0, lot_rect(i).size.y * 0.3)
		"cow":
			return cow_foot(i) - Vector2(0, cow_size() * 0.9)
		"grill":
			return grill_at(i) - Vector2(0, 80.0)
		"till":
			return till_at(i) - Vector2(0, 120.0)
		"queue":
			return Vector2(area.get_center().x, front_y() + 60.0)
		"pass":
			return Vector2(area.get_center().x, pass_y() - 90.0)
		"jar":
			return jar_at(i) - Vector2(0, jar_size() * 0.9)
		"kettle":
			return kettle_at() - Vector2(0, 90.0)
		"bell":
			return bell_at() - Vector2(0, 90.0)
		"barn":
			return barn_door()
		"scraps":
			return scraps_at() - Vector2(0, 90.0)
		"sign":
			return notch_at(1) - Vector2(-notch_size() * 0.6, notch_size() * 0.6)
	return area.get_center()

# --- the touch ---

func _gui_input(event: InputEvent) -> void:
	if not playable or sim == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1 and not _mouse:
			_touch = t.index
			press(t.position)
		elif not t.pressed and t.index == _touch:
			_touch = -1
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		if m.pressed and _touch == -1:
			_mouse = true
			press(m.position)
		elif not m.pressed:
			_mouse = false

## A finger down at `at`. The tutorial's script and the harness press
## through this too.
func press(at: Vector2) -> void:
	match place:
		"fields":
			_press_fields(at)
		"yard":
			_press_yard(at)
		"counter":
			_press_counter(at)
		"office":
			_press_office(at)

func _buy(what: String, at: Vector2) -> void:
	var p: int = sim.buy_price(what)
	if p < 0:
		return
	if not sim.buy(what):
		_no[what + "sign"] = clock
		refused.emit("short", at, p - int(sim.coins))

func _press_fields(at: Vector2) -> void:
	for i in Sim.LOTS:
		if not lot_rect(i).grow(8.0).has_point(at):
			continue
		var l: Dictionary = sim.lots[i]
		if not l.open:
			if i == _next_lot():
				_buy("lot", lot_mid(i))
			return
		if l.ripe:
			if not sim.harvest(i):
				_no["lot%d" % i] = clock
			return
		lot_asked.emit(i)
		return

func _press_yard(at: Vector2) -> void:
	var cs := cow_size()
	for k in sim.cows.size():
		if at.distance_to(cow_foot(k) - Vector2(0, cs * 0.4)) > cs * 0.56:
			continue
		var c: Dictionary = sim.cows[k]
		if c.poorly:
			if sim.tuck(k):
				_at["cow%d" % k] = clock
			else:
				refused.emit("wait", over("cow", k), int(ceil(float(c.rest))))
		elif c.full:
			if not sim.milk(k):
				_no["cow%d" % k] = clock
		else:
			_at["cow%d" % k] = clock
			refused.emit("wait", over("cow", k), int(ceil((1.0 - float(c.milk)) * sim.milk_time())))
		return
	if at.distance_to(scraps_at()) < 86.0:
		_at["scraps"] = clock
		sim.set_scraps(not sim.scraps)
		return
	if sim.buy_price("cow") >= 0 and at.distance_to(cow_sign() - Vector2(0, 60.0)) < 90.0:
		_buy("cow", cow_sign() - Vector2(0, 60.0))
		return
	if sim.buy_price("stall") >= 0 and at.distance_to(stall_sign() - Vector2(0, 60.0)) < 90.0:
		_buy("stall", stall_sign() - Vector2(0, 60.0))

func _press_counter(at: Vector2) -> void:
	if at.distance_to(kettle_at()) < 84.0:
		_at["kettle"] = clock
		if not sim.take_tea():
			touched.emit(0.94)
		return
	if at.distance_to(bell_at()) < 84.0:
		_at["bell"] = clock
		if not sim.set_bell(not sim.bell):
			touched.emit(0.94)
		return
	if sim.grills < Sim.GRILLS_MAX and at.distance_to(grill_at(sim.grills)) < 100.0:
		_buy("grill", grill_at(sim.grills))
		return
	if sim.tills < Sim.TILLS_MAX and at.distance_to(Vector2(lane_x(sim.tills), front_y() - 70.0)) < 96.0:
		_buy("till", Vector2(lane_x(sim.tills), front_y() - 70.0))
		return
	if at.y > pass_y() - 90.0:
		if not sim.serve():
			_no["pass"] = clock

func _press_office(at: Vector2) -> void:
	for v in Sim.VOLUMES:
		if at.distance_to(notch_at(v)) < notch_size() * 0.6:
			if v == sim.volume:
				return
			if sim.set_volume(v):
				_at["notch%d" % v] = clock
			else:
				_no["notch%d" % v] = clock
				refused.emit("hush", notch_at(v) - Vector2(0, notch_size() * 0.5), int(ceil(float(sim.hush))))
			return
	for k in Sim.MOODS.size():
		var m: String = Sim.MOODS[k]
		if favour_rect(k).grow(10.0).has_point(at) or at.distance_to(jar_at(k)) < jar_size() * 0.8:
			if float(sim.mood[m]) < 1.0:
				touched.emit(1.0)
				_at["jar" + m] = clock
			elif float(sim.favour_t[m]) > 0.0:
				_no["jar" + m] = clock
				refused.emit("wait", over("jar", k), int(ceil(float(sim.favour_t[m]))))
			elif not sim.favour(m):
				_no["jar" + m] = clock
				refused.emit("short", over("jar", k), sim.favour_price(m) - int(sim.coins))
			return

# --- the sim's events, played back ---

func _fly(kind: String, from: Vector2, to: Vector2, s: float, delay := 0.0, life := FLY) -> void:
	if Motion.reduce:
		if kind == "coin":
			landed.emit()
		return
	_bits.append({"kind": kind, "from": from, "to": to, "t": -delay, "life": life, "s": s})

func _sync_looks() -> void:
	if sim == null:
		return
	while _looks.size() < sim.queue.size():
		_looks.append({"coat": _rng.randi() % Art.COATS.size(), "skin": _rng.randi() % Art.SKINS.size(), "born": clock - 10.0})
	while _looks.size() > sim.queue.size():
		_looks.pop_back()

func play(ev: Dictionary) -> void:
	var here := place
	match String(ev.type):
		"harvest":
			var i := int(ev.i)
			_at["lot%d" % i] = clock
			if here == "fields":
				var crop := int(ev.crop)
				for n in mini(int(ev.n), 4):
					_fly("loaf" if crop == Sim.WHEAT else "sack", lot_mid(i), stock_at(crop), 54.0, 0.06 * n)
				if not bool(ev.hand):
					_cart_to = lot_mid(i) + Vector2(0, lot_rect(i).size.y * 0.3)
					_cart_until = clock + 1.4
		"full":
			if ev.has("i"):
				_no["lot%d" % int(ev.i)] = clock
				if here == "fields":
					refused.emit("full", over("lot", int(ev.i)), 0)
			elif here == "yard":
				refused.emit("full", over("cow", int(ev.k)), 0)
		"plant":
			_at["lot%d" % int(ev.i)] = clock
		"milk":
			_at["cow%d" % int(ev.k)] = clock
			if here == "yard":
				_fly("cheese", over("cow", int(ev.k)), shelf_at(), 60.0)
		"filled", "poorly", "well", "tuck":
			_at["cow%d" % int(ev.k)] = clock
		"cook":
			_at["grill%d" % int(ev.g)] = clock
			if here == "counter":
				_fly("toastie", grill_at(int(ev.g)), pass_at(maxi(0, int(sim.ready) - 1)), 64.0, 0.0, 0.3)
		"arrive":
			_looks.append({"coat": _rng.randi() % Art.COATS.size(), "skin": _rng.randi() % Art.SKINS.size(), "born": clock})
		"left":
			var k := int(ev.k)
			if k < _looks.size():
				var gone: Dictionary = _looks[k]
				_looks.remove_at(k)
				if here == "counter":
					_gone.append({"coat": gone.coat, "skin": gone.skin, "from": queue_at(k), "t": 0.0, "cross": true})
		"serve":
			var lane := int(ev.till)
			_at["till%d" % lane] = clock
			_at["pass"] = clock
			if not _looks.is_empty():
				var front: Dictionary = _looks.pop_front()
				if here == "counter":
					_gone.append({"coat": front.coat, "skin": front.skin, "from": queue_at(0), "t": 0.0, "cross": false})
			if here == "counter":
				_fly("toastie", pass_at(0), queue_at(0) - Vector2(0, 70.0), 60.0, 0.0, 0.26)
				for n in clampi(1 + int(ev.n) / 4, 1, 4):
					_fly("coin", queue_at(0) - Vector2(0, 90.0), fly_to, 40.0, 0.2 + 0.07 * n, 0.6)
		"bought":
			_at[String(ev.what) + "sign"] = clock
			if String(ev.what) == "lot":
				_at["lot%d" % int(ev.i)] = clock
		"toggle":
			_at[String(ev.what)] = clock
		"favour":
			_at["jar" + String(ev.m)] = clock
		"boil":
			_no["jar" + String(ev.m)] = clock
		"tea":
			_at["kettle"] = clock
	_sync_looks()

func tick(delta: float) -> void:
	clock += delta
	var k := 0
	while k < _bits.size():
		var bit: Dictionary = _bits[k]
		bit.t = float(bit.t) + delta
		if float(bit.t) >= float(bit.life):
			if String(bit.kind) == "coin":
				landed.emit()
			_bits.remove_at(k)
		else:
			k += 1
	k = 0
	while k < _gone.size():
		_gone[k].t = float(_gone[k].t) + delta
		if float(_gone[k].t) > 1.2:
			_gone.remove_at(k)
		else:
			k += 1
	if place == "fields" and sim != null:
		var home := barn_door() + Vector2(0, 44.0)
		if _cart == Vector2.INF:
			_cart = home
		var to := _cart_to if clock < _cart_until else home
		_cart = to if Motion.reduce else _cart.lerp(to, 1.0 - exp(-delta * 5.0))
	queue_redraw()

# --- drawing ---

func _bump(key: String, amount := 0.16) -> float:
	return 1.0 if Motion.reduce else Motion.bump_scale(clock - float(_at.get(key, -10.0)), amount, 0.24)

func _shake(key: String, px := 7.0) -> float:
	return 0.0 if Motion.reduce else Motion.shiver_offset(clock - float(_no.get(key, -10.0)), px, 0.3)

func _bob(phase: float, px := 5.0, rate := 3.0) -> float:
	return 0.0 if Motion.reduce else sin(clock * rate + phase) * px

func _text(text: String, mid: Vector2, fs: int, col: Color, wide := 400.0) -> void:
	draw_string(font, Vector2(mid.x - wide * 0.5, mid.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, wide, fs, col)

func _left(text: String, at: Vector2, fs: int, col: Color) -> void:
	draw_string(font, Vector2(at.x, at.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## A coin and a short number, its middle at `mid`.
func _price(n: int, mid: Vector2, fs: int, can: bool) -> void:
	var text := short(n)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := mid.x - (tw + fs * 1.1) * 0.5
	draw_mesh(Art.coin(fs * 0.95), null, Transform2D(0.0, Vector2(x + fs * 0.45, mid.y)))
	draw_string(font, Vector2(x + fs * 1.1, mid.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK if can else Color(Art.INK, 0.55))

## A signboard at `foot` for the next `what`: its word and its price, a hop
## when it can be had.
func _sign(what: String, foot: Vector2, w := 150.0) -> void:
	var key := what
	var p: int = sim.buy_price(what)
	if p < 0:
		return
	var can: bool = sim.coins >= p
	var at := foot + Vector2(_shake(key + "sign"), -absf(_bob(foot.x, 5.0)) if can else 0.0)
	var sc := _bump(key + "sign")
	draw_mesh(Art.signboard(w), null, Transform2D(0.0, Vector2(sc, sc), 0.0, at), Color(1, 1, 1, 1.0 if can else 0.8))
	_text(tr("GR_BUY_" + what.to_upper()), at + Vector2(0, -w * 0.46 * 1.02), 20, Color(Art.INK, 0.7), w)
	_price(p, at + Vector2(0, -w * 0.46 * 0.66), 26, can)

func _bar(b: Face.Builder, mid: Vector2, w: float, part: float, col: Color, h := 12.0) -> void:
	b.fan(Face.Builder.round_rect(mid - Vector2(w * 0.5, h * 0.5), Vector2(w, h), h * 0.5), Color(Art.INK, 0.22))
	if part > 0.02:
		b.fan(Face.Builder.round_rect(mid - Vector2(w * 0.5, h * 0.5), Vector2(maxf(h, w * clampf(part, 0.0, 1.0)), h), h * 0.5), col)

## A white bubble over a thing, its point down at `at`.
func _bubble(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(0, -r * 1.2 + 4.0), r, Color(Art.INK, 0.14))
	b.polygon(PackedVector2Array([at, at + Vector2(-r * 0.4, -r * 0.5), at + Vector2(r * 0.4, -r * 0.5)]), Art.CREAM)
	b.disc(at + Vector2(0, -r * 1.2), r, Art.CREAM)

func _draw() -> void:
	if sim == null or area.size.x <= 0.0 or font == null:
		return
	_lives.clear()
	var b := Face.Builder.new()
	match place:
		"fields":
			_draw_fields(b)
		"yard":
			_draw_yard(b)
		"counter":
			_draw_counter(b)
		"office":
			_draw_office(b)

func _flush(b: Face.Builder) -> void:
	if not b.verts.is_empty():
		_lives.append(b.mesh())
		draw_mesh(_lives[-1], null)

func _draw_bits() -> void:
	for bit: Dictionary in _bits:
		if float(bit.t) < 0.0:
			continue
		var u := clampf(float(bit.t) / float(bit.life), 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		var from: Vector2 = bit.from
		var to: Vector2 = bit.to
		var at := from.lerp(to, e) + Vector2(0, -sin(u * PI) * 90.0)
		# one mesh a kind, grown by the transform: a size a frame would fill
		# the cache and empty it under meshes this frame has drawn
		var s := float(bit.s)
		var k := 1.0 + 0.2 * sin(u * PI)
		var mesh: ArrayMesh
		match String(bit.kind):
			"loaf":
				mesh = Art.loaf(s)
			"sack":
				mesh = Art.sack(s)
			"cheese":
				mesh = Art.cheese(s)
			"toastie":
				mesh = Art.toastie(s)
			_:
				mesh = Art.coin(s)
		draw_mesh(mesh, null, Transform2D(0.0, Vector2(k, k), 0.0, at), Color(1, 1, 1, 1.0 if u < 0.85 else (1.0 - u) / 0.15))
	if finger != Vector2.INF:
		var r := 30.0 if finger_down else 38.0
		draw_circle(finger + Vector2(0, 4.0), r, Color(Art.INK, 0.18), true, -1.0, true)
		draw_circle(finger, r, Color(1, 1, 1, 0.92), true, -1.0, true)
		draw_circle(finger, r * 0.62, Color(Pal.SUN, 0.9 if finger_down else 0.5), true, -1.0, true)

# --- the fields ---

func _draw_fields(live: Face.Builder) -> void:
	var bh := barn_h()
	draw_mesh(Art.fields_ground(size, area.position.y, bh), null)
	# what the larder holds, on the barn
	for crop in 2:
		var at := stock_at(crop)
		live.fan(Face.Builder.round_rect(at - Vector2(96, 36), Vector2(192, 72), 30.0), Color(Art.INK, 0.2))
		live.fan(Face.Builder.round_rect(at - Vector2(96, 40), Vector2(192, 72), 30.0), Art.CREAM)
	_flush(live)
	live = Face.Builder.new()
	for crop in 2:
		var at := stock_at(crop)
		var n: int = sim.loaves if crop == Sim.WHEAT else sim.feed
		draw_mesh(Art.loaf(56.0) if crop == Sim.WHEAT else Art.sack(52.0), null, Transform2D(0.0, at + Vector2(-54, -4)))
		_left("%d/%d" % [n, sim.larder()], at + Vector2(-18, -4), 28, Art.RED if n <= 0 else Art.INK)
	var next := _next_lot()
	for i in Sim.LOTS:
		var l: Dictionary = sim.lots[i]
		var r := lot_rect(i)
		var mid := r.get_center()
		var key := "lot%d" % i
		if not l.open:
			draw_mesh(Art.lot(r.size, 2), null, Transform2D(0.0, mid))
			if i == next:
				_sign("lot", mid + Vector2(0, r.size.y * 0.34), minf(170.0, r.size.x * 0.7))
			continue
		var sc := _bump(key, 0.08)
		var xf := Transform2D(0.0, Vector2(sc, sc), 0.0, mid + Vector2(_shake(key), 0))
		var crop := int(l.crop)
		draw_mesh(Art.lot(r.size, 1 if crop == Sim.FALLOW else 0), null, xf)
		var soil: float = l.soil
		if crop == Sim.FALLOW:
			_text(tr("GR_RESTING"), mid + Vector2(0, -r.size.y * 0.18), 24, Color(Art.CREAM, 0.95), r.size.x)
		else:
			var part: float = float(l.t) / float(sim.grow_time(crop))
			var stage := 3 if l.ripe else (0 if part < 0.25 else 1 if part < 0.6 else 2)
			var sway := Transform2D(0.0, mid)
			if not Motion.reduce:
				# the tops lean in the wind over their own feet
				sway = Transform2D(Vector2(1, 0), Vector2(sin(clock * 1.3 + i) * 0.05, 1), mid)
				if l.ripe:
					sway.origin.y += -absf(sin(clock * 2.4 + i)) * 5.0
			draw_mesh(Art.crop(crop, stage, r.size), null, sway)
			if l.ripe:
				Rewards.glint(live, mid + Vector2(r.size.x * 0.3, -r.size.y * 0.3), 16.0 + _bob(i, 3.0, 4.0), clock * 1.5 + i)
			else:
				_bar(live, mid + Vector2(0, r.size.y * 0.5 - 16.0), r.size.x * 0.56, part, Art.CLOVER_HI)
			if l.tonic:
				draw_mesh(Art.tonic(46.0), null, Transform2D(0.0, mid + Vector2(-r.size.x * 0.5 + 26.0, -r.size.y * 0.5 + 30.0 + _bob(i * 2.0, 2.0))))
		if soil < 60.0:
			var at := mid + Vector2(r.size.x * 0.5 - 22.0, 0)
			live.fan(Face.Builder.round_rect(at - Vector2(8, r.size.y * 0.3), Vector2(16, r.size.y * 0.6), 8.0), Color(Art.INK, 0.25))
			var tall := r.size.y * 0.6 * soil / Sim.SOIL_MAX
			live.fan(Face.Builder.round_rect(at + Vector2(-8, r.size.y * 0.3 - maxf(16.0, tall)), Vector2(16, maxf(16.0, tall)), 8.0), Art.RED if soil < Sim.TIRED else Art.AMBER)
	_flush(live)
	if _cart != Vector2.INF:
		draw_mesh(Art.cart(110.0), null, Transform2D(0.0, _cart + Vector2(0, -absf(_bob(0.0, 2.0, 9.0)))))
	if sim.ban > 0.0:
		_text(tr("GR_BAN") % int(ceil(sim.ban)), barn_door() + Vector2(0, 30.0), 24, Art.CREAM, 600.0)
	_draw_bits()

# --- the yard ---

func _draw_yard(live: Face.Builder) -> void:
	draw_mesh(Art.yard_ground(size, area.position.y + wall_h()), null)
	var cs := cow_size()
	for k in YARD_COLS * 2:
		if k < sim.cow_room():
			var r := slot_rect(k)
			draw_mesh(Art.stall(r.size, k < sim.stalls), null, Transform2D(0.0, r.get_center()))
	for k in sim.cows.size():
		var c: Dictionary = sim.cows[k]
		var key := "cow%d" % k
		var foot := cow_foot(k) + Vector2(_shake(key), 0)
		var sc := _bump(key, 0.1)
		var lying: bool = c.poorly and float(c.rest) > 0.0
		var breath := 1.0 if Motion.reduce else 1.0 + sin(clock * (1.2 if lying else 2.0) + k) * 0.015
		draw_mesh(Animals.cow(cs, c.full and not c.poorly), null, Transform2D(0.0, Vector2(sc, sc * breath * (0.9 if lying else 1.0)), 0.0, foot), Color(1, 1, 1, 1) if not c.poorly else Color(0.9, 0.92, 1.0))
		if c.poorly:
			draw_mesh(Art.blanket(cs), null, Transform2D(0.0, Vector2(sc, sc * (0.9 if lying else 1.0)), 0.0, foot))
		var top := foot - Vector2(0, cs * 0.78)
		if c.poorly and not lying:
			_bubble(live, top + Vector2(0, _bob(k, 4.0)), 34.0)
		elif c.full and not c.poorly:
			_bubble(live, top + Vector2(0, _bob(k, 5.0)), 36.0)
		elif not c.poorly:
			_bar(live, foot + Vector2(0, 20.0), cs * 0.6, float(c.milk), Art.CREAM)
		if lying:
			_bar(live, foot + Vector2(0, 20.0), cs * 0.6, 1.0 - float(c.rest) / Sim.TUCK, Art.BLANKET)
	# the trough's feed
	var tw := area.size.x * 0.44
	var tat := trough_at()
	_flush(live)
	live = Face.Builder.new()
	draw_mesh(Art.trough(tw), null, Transform2D(0.0, tat))
	var part := clampf(float(sim.feed) / sim.larder(), 0.0, 1.0)
	if part > 0.0:
		live.fan(Face.Builder.round_rect(tat + Vector2(-tw * 0.5 + 10.0, -tw * 0.13 + 6.0), Vector2((tw - 20.0) * maxf(0.08, part), tw * 0.26 - 24.0), 10.0), Art.CLOVER if not sim.scraps else Color("a89a5c"))
	# the scraps' switch
	var sat := scraps_at()
	var ssc := _bump("scraps", 0.14)
	_flush(live)
	live = Face.Builder.new()
	draw_mesh(Art.plate(66.0, Art.AMBER if sim.scraps else Color("e6dcc6")), null, Transform2D(0.0, Vector2(ssc, ssc), 0.0, sat))
	draw_mesh(Art.bucket(78.0), null, Transform2D(0.0, Vector2(ssc, ssc), 0.0, sat + Vector2(0, 4.0)))
	_text(tr("GR_SCRAPS_ON") if sim.scraps else tr("GR_SCRAPS_OFF"), sat + Vector2(0, 92.0), 22, Art.INK, 260.0)
	# bubbles' pictures over the live mesh's discs
	for k in sim.cows.size():
		var c: Dictionary = sim.cows[k]
		var top := cow_foot(k) - Vector2(0, cs * 0.78)
		if c.poorly and float(c.rest) <= 0.0:
			draw_mesh(Art.blanket(64.0), null, Transform2D(0.0, top + Vector2(4.0, -8.0 + _bob(k, 4.0))))
		elif c.full and not c.poorly:
			draw_mesh(Art.cheese(44.0), null, Transform2D(0.0, top + Vector2(0, -44.0 + _bob(k, 5.0))))
	# what the larder holds
	draw_mesh(Art.sack(50.0), null, Transform2D(0.0, tat + Vector2(-tw * 0.5 + 30.0, -74.0)))
	_left("%d/%d" % [sim.feed, sim.larder()], tat + Vector2(-tw * 0.5 + 64.0, -74.0), 28, Art.RED if sim.feed <= 0 else Art.INK)
	var sh := shelf_at()
	draw_mesh(Art.cheese(60.0), null, Transform2D(0.0, sh + Vector2(-40.0, 0)))
	_left("%d/%d" % [sim.cheese, sim.larder()], sh + Vector2(0, 0), 28, Art.INK)
	_left(tr("GR_STALLS") % [sim.cows.size(), sim.stalls], Vector2(area.position.x + 24.0, area.position.y + wall_h() * 0.5), 26, Art.CREAM)
	_sign("cow", cow_sign())
	_sign("stall", stall_sign())
	_draw_bits()

# --- the counter ---

func _draw_counter(live: Face.Builder) -> void:
	var o := area.position
	if o.y > 0.0:
		draw_rect(Rect2(0, 0, size.x, o.y + 4.0), Art.SKY)
	draw_mesh(Art.counter_ground(Vector2(size.x, size.y - o.y), back_y() - o.y + 70.0, pass_y() - o.y, front_y() - o.y), null, Transform2D(0.0, Vector2(0, o.y)))
	var away: bool = sim.walk > 0.0
	var at_tea: bool = sim.tea > 0.0
	var worn: bool = sim.pep < Sim.WORN
	# the grills and their cooks
	for g in Sim.GRILLS_MAX:
		var at := grill_at(g)
		if g >= sim.grills:
			if g == sim.grills:
				draw_mesh(Art.grill(190.0, false), null, Transform2D(0.0, at))
				_sign("grill", at + Vector2(0, 60.0))
			continue
		var sc := _bump("grill%d" % g, 0.08)
		draw_mesh(Art.grill(190.0, true), null, Transform2D(0.0, Vector2(sc, sc), 0.0, at))
		var done: float = sim.cooking[g]
		if done > 0.0:
			draw_mesh(Art.toastie(84.0, done), null, Transform2D(0.0, at + Vector2(0, -6.0)))
			_bar(live, at + Vector2(0, 54.0), 120.0, done, Art.AMBER)
			if not Motion.reduce:
				for n in 2:
					var u := fmod(clock * 0.6 + n * 0.5 + g * 0.3, 1.0)
					live.disc(at + Vector2(-20.0 + 40.0 * n + sin(clock * 2.0 + n) * 6.0, -30.0 - u * 50.0), 9.0 + u * 8.0, Color(1, 1, 1, 0.3 * (1.0 - u)))
		if not away:
			var cf := at + Vector2(-4.0, 196.0)
			var hop := 0.0 if Motion.reduce or at_tea else -absf(sin(clock * 5.0 * sim.pace() + g)) * 5.0 * (1.0 if done > 0.0 else 0.0)
			draw_mesh(Art.crew(132.0, g, worn or at_tea), null, Transform2D(0.0, cf + Vector2(0, hop)))
	# the pass
	var psh := _shake("pass", 5.0)
	for n in sim.ready:
		var p := pass_at(n) + Vector2(psh, 0)
		var sc := _bump("pass", 0.1) if n == 0 else 1.0
		draw_mesh(Art.toastie(64.0), null, Transform2D(0.0, Vector2(sc, sc), 0.0, p))
	_left("%d/%d" % [sim.ready, sim.pass_room()], Vector2(area.end.x - 150.0, pass_y() + 44.0), 22, Color(Art.INK, 0.7))
	# what the larder still holds for the grills
	draw_mesh(Art.loaf(44.0), null, Transform2D(0.0, Vector2(o.x + 190.0, pass_y() + 46.0)))
	_left(str(sim.loaves), Vector2(o.x + 218.0, pass_y() + 44.0), 24, Art.RED if sim.loaves <= 0 else Art.INK)
	draw_mesh(Art.cheese(40.0), null, Transform2D(0.0, Vector2(o.x + 300.0, pass_y() + 44.0)))
	_left(str(sim.cheese), Vector2(o.x + 326.0, pass_y() + 44.0), 24, Art.RED if sim.cheese <= 0 else Art.INK)
	# the kettle and the bell
	var ksc := _bump("kettle", 0.14)
	_flush(live)
	live = Face.Builder.new()
	draw_mesh(Art.plate(62.0, Art.TEAL_HI if at_tea else Color("e6dcc6")), null, Transform2D(0.0, Vector2(ksc, ksc), 0.0, kettle_at()))
	draw_mesh(Art.kettle(70.0), null, Transform2D(0.0, Vector2(ksc, ksc), 0.0, kettle_at() + Vector2(-2.0, 4.0)))
	var bsc := _bump("bell", 0.14)
	draw_mesh(Art.plate(62.0, Art.AMBER if sim.bell else Color("e6dcc6")), null, Transform2D(0.0, Vector2(bsc, bsc), 0.0, bell_at()))
	draw_mesh(Art.bell(76.0), null, Transform2D(bell_wag(), Vector2(bsc, bsc), 0.0, bell_at() + Vector2(0, 4.0)))
	# the crew's pep, between them
	var mid := Vector2(area.get_center().x, kettle_at().y)
	var pw := area.size.x - 420.0
	_bar(live, mid + Vector2(0, 18.0), pw, sim.pep / Sim.PEP_MAX, Art.RED if worn else (Art.AMBER if sim.pep < 50.0 else Art.OK), 20.0)
	var word := tr("GR_PEP")
	if away:
		word = tr("GR_WALK") % int(ceil(sim.walk))
	elif at_tea:
		word = tr("GR_AT_TEA") % int(ceil(sim.tea))
	elif worn:
		word = tr("GR_WORN")
	elif sim.bell:
		word = tr("GR_HURRY")
	_text(word, mid + Vector2(0, -22.0), 24, Art.INK, pw + 60.0)
	# the tills and who stands at them
	for t in Sim.TILLS_MAX:
		if t >= sim.tills:
			if t == sim.tills:
				_sign("till", Vector2(lane_x(t), front_y() - 40.0))
			continue
		if not away:
			draw_mesh(Art.crew(124.0, t + 1, worn or at_tea), null, Transform2D(0.0, Vector2(lane_x(t) - 40.0, front_y() - 92.0)))
		var sc := _bump("till%d" % t, 0.14)
		draw_mesh(Art.till(92.0, true), null, Transform2D(0.0, Vector2(sc, sc), 0.0, till_at(t)))
		if float(sim.serving[t]) > 0.0:
			_bar(live, till_at(t) + Vector2(0, 16.0), 84.0, float(sim.serving[t]), Art.TEAL_HI, 10.0)
	_flush(live)
	live = Face.Builder.new()
	# the queue, those nearest the counter first: the ones behind stand
	# lower on the square and over them
	for k in mini(_looks.size(), sim.queue.size()):
		var look: Dictionary = _looks[k]
		var waited: float = sim.queue[k]
		var cross := waited > Sim.PATIENCE * 0.65
		var at := queue_at(k)
		if not Motion.reduce:
			var age := clock - float(look.born)
			if age < 0.5:
				at.y += (1.0 - age / 0.5) * 260.0
			at.y += -absf(sin(clock * (5.0 if cross else 2.2) + k * 1.7)) * (5.0 if cross else 3.0)
		draw_mesh(Art.folk(124.0, look.coat, look.skin, cross), null, Transform2D(0.0, at))
		if cross:
			_bar(live, at + Vector2(0, 14.0), 80.0, 1.0 - (waited - Sim.PATIENCE * 0.65) / (Sim.PATIENCE * 0.35), Art.RED, 10.0)
	for g: Dictionary in _gone:
		var u := clampf(float(g.t) / 1.2, 0.0, 1.0)
		var from: Vector2 = g.from
		var at := from + Vector2((size.x * 0.6) * u * u + 40.0 * u, 60.0 * u + (0.0 if Motion.reduce else -absf(sin(u * 16.0)) * 14.0 * (1.0 - u)))
		draw_mesh(Art.folk(124.0, g.coat, g.skin, g.cross), null, Transform2D(0.0, at), Color(1, 1, 1, 1.0 - u * u))
	if sim.queue.is_empty() and not away:
		_text(tr("GR_NO_QUEUE"), Vector2(area.get_center().x, front_y() + 200.0), 26, Color(Art.INK, 0.5), 700.0)
	if sim.hush > 0.0:
		_text(tr("GR_HUSHED") % int(ceil(sim.hush)), Vector2(area.get_center().x, area.end.y - 30.0), 24, Color(Art.INK, 0.7), 800.0)
	_flush(live)
	_draw_bits()

func bell_wag() -> float:
	if Motion.reduce or not sim.bell:
		return 0.0
	return sin(clock * 9.0) * 0.12

# --- the office ---

func _draw_office(live: Face.Builder) -> void:
	draw_mesh(Art.office_ground(size, floor_y()), null)
	for n in 3:
		var r := sheet_rect(n)
		draw_mesh(Art.sheet(r.size), null, Transform2D(0.0, r.position))
	# the signboard
	var r0 := sheet_rect(0)
	_text(tr("GR_SIGN_TITLE"), Vector2(r0.get_center().x, r0.position.y + 36.0), 30, Art.INK, r0.size.x)
	var ns := notch_size()
	for v in Sim.VOLUMES:
		var at := notch_at(v) + Vector2(_shake("notch%d" % v), 0)
		var sc := _bump("notch%d" % v, 0.12)
		draw_mesh(Art.notch(ns, v, v == sim.volume), null, Transform2D(0.0, Vector2(sc, sc), 0.0, at), Color(1, 1, 1, 0.5 if sim.hush > 0.0 and v > 0 else 1.0))
	var line := tr("GR_NOTCH_%d" % sim.volume)
	if sim.hush > 0.0:
		line = tr("GR_HUSHED") % int(ceil(sim.hush))
	_text(line, Vector2(r0.get_center().x, r0.end.y - 20.0), 22, Color(Art.INK, 0.7), r0.size.x)
	# the town's moods
	var r1 := sheet_rect(1)
	_text(tr("GR_MOODS_TITLE"), Vector2(r1.get_center().x, r1.position.y + 36.0), 30, Art.INK, r1.size.x)
	var js := jar_size()
	for k in Sim.MOODS.size():
		var m: String = Sim.MOODS[k]
		var level: float = float(sim.mood[m]) / Sim.MOOD_MAX
		var hot: bool = float(sim.mood[m]) >= Sim.MOOD_WARN
		var at := jar_at(k) + Vector2(_shake("jar" + m, 10.0), 0)
		if hot and not Motion.reduce:
			at.x += sin(clock * 18.0 + k) * 2.0 * level
		var sc := _bump("jar" + m, 0.12)
		var xf := Transform2D(0.0, Vector2(sc, sc), 0.0, at)
		draw_mesh(Art.jar(js), null, xf)
		var h := js * 1.3 - js * 0.2
		var tall := maxf(0.0, h * level)
		if tall > 4.0:
			var col := Art.RED if hot else (Art.AMBER if level > 0.35 else Art.OK)
			live.fan(Face.Builder.round_rect(at + Vector2(-js * 0.4, js * 0.65 - js * 0.1 - tall), Vector2(js * 0.8, tall), minf(js * 0.16, tall * 0.5)), col)
	_flush(live)
	live = Face.Builder.new()
	for k in Sim.MOODS.size():
		var m: String = Sim.MOODS[k]
		var at := jar_at(k)
		var hot: bool = float(sim.mood[m]) >= Sim.MOOD_WARN
		draw_mesh(Art.jar_glass(js), null, Transform2D(0.0, at + Vector2(_shake("jar" + m, 10.0), 0)))
		_text(tr("GR_MOOD_" + m.to_upper()), at + Vector2(0, -js * 0.65 - 44.0), 24, Art.RED.darkened(0.2) if hot else Art.INK, r1.size.x / Sim.MOODS.size())
		var grief: float = sim.grief(m) - Sim.CALM
		var arrow := "▲" if grief > 0.05 else ("▼" if float(sim.mood[m]) > 0.5 else "")
		_text("%d%% %s" % [int(round(float(sim.mood[m]))), arrow], at + Vector2(0, js * 0.65 + 30.0), 24, Art.RED.darkened(0.2) if grief > 0.05 else Color(Art.INK, 0.7), 240.0)
		# the favour's button
		var fr := favour_rect(k)
		var waits: float = sim.favour_t[m]
		var p: int = sim.favour_price(m)
		var can: bool = sim.coins >= p and waits <= 0.0 and float(sim.mood[m]) >= 1.0
		live.fan(Face.Builder.round_rect(fr.position + Vector2(0, 5.0), fr.size, 26.0), Color(Art.INK, 0.16))
		live.fan(Face.Builder.round_rect(fr.position, fr.size, 26.0), Art.PLACE_TINT.office if can else Color("e6dcc6"))
	_flush(live)
	live = Face.Builder.new()
	for k in Sim.MOODS.size():
		var m: String = Sim.MOODS[k]
		var fr := favour_rect(k)
		var waits: float = sim.favour_t[m]
		var p: int = sim.favour_price(m)
		var can: bool = sim.coins >= p and waits <= 0.0 and float(sim.mood[m]) >= 1.0
		_text(tr("GR_FAVOUR_" + m.to_upper()), Vector2(fr.get_center().x, fr.position.y - 20.0), 20, Color(Art.INK, 0.7), fr.size.x + 20.0)
		if waits > 0.0:
			_text("%d s" % int(ceil(waits)), fr.get_center(), 26, Color(Art.INK, 0.6), fr.size.x)
		elif float(sim.mood[m]) < 1.0:
			_text(tr("GR_CALM"), fr.get_center(), 24, Color(Art.INK, 0.6), fr.size.x)
		else:
			_price_on(p, fr.get_center(), 26, can)
	# the ledger
	var r2 := sheet_rect(2)
	_text(tr("GR_LEDGER_TITLE"), Vector2(r2.get_center().x, r2.position.y + 36.0), 30, Art.INK, r2.size.x)
	var rows := [
		[tr("GR_TODAY"), Locale.number(sim.today)],
		[tr("GR_YESTERDAY"), Locale.number(sim.yesterday)],
		[tr("GR_SOLD"), Locale.number(sim.served)],
		[tr("GR_BEST_RUSH"), "×%d" % sim.best_rush],
		[tr("GR_CLEANS"), Locale.number(sim.cleans)],
		[tr("GR_WALKED"), Locale.number(sim.walked)],
	]
	for n in rows.size():
		var cx := r2.position.x + r2.size.x * (0.07 + 0.5 * (n % 2))
		var y := r2.position.y + 92.0 + (r2.size.y - 120.0) * (n / 2) / 3.0
		_left(rows[n][0], Vector2(cx, y), 24, Color(Art.INK, 0.7))
		draw_string(font, Vector2(cx, y + 9.0), rows[n][1], HORIZONTAL_ALIGNMENT_RIGHT, r2.size.x * 0.38, 26, Art.INK)
	_draw_bits()

## A price on a tinted button: white when it can be had.
func _price_on(n: int, mid: Vector2, fs: int, can: bool) -> void:
	var text := short(n)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := mid.x - (tw + fs * 1.1) * 0.5
	draw_mesh(Art.coin(fs * 0.95), null, Transform2D(0.0, Vector2(x + fs * 0.45, mid.y)))
	draw_string(font, Vector2(x + fs * 1.1, mid.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.CREAM if can else Color(Art.INK, 0.55))
