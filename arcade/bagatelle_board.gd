extends Control

## Bagatelle's board (spec docs/superpowers/specs/2026-10-15-arcade-
## bagatelle-design.md): the velvet fills the whole Control, and the board
## itself -- rail and dropper, pins, cups -- is laid inside `view` (the room
## between the screen's plates and its tray) at the scale that fits it.
##
## A press drops a marble at the press's across; held, it keeps dropping
## every HOLD_EVERY. A press on a bonus pin picks it up instead: drawn after
## the finger, it is set on the pin nearest where it is let go (or goes back
## if that cannot take it); a press on one let go at once is a drop.
##
## Draw calls: the velvet, the rail, the pins, the cups and the bonus pins
## are cached meshes; the halos and every marble in the air are each laid
## into one mesh a frame (Face.FlatBuilder). The words are strings.

signal touched(pitch: float)
signal jar_asked

const Sim = preload("res://arcade/bagatelle_sim.gd")
const Art = preload("res://arcade/bagatelle_art.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

## How often a held finger drops another marble.
const HOLD_EVERY := 0.16
## How long a pin's glow lasts.
const GLOW := 0.32
## How far a press may be from a bonus pin to pick it up, in field units.
const GRAB := 30.0
## A press that moves less than this (pixels) and lets go is a tap.
const TAP := 14.0
## Coins floated over a cup: at most this often a cup, and at most FLOATS.
const FLOAT_GAP := 0.14
const FLOATS := 22
const FLOAT_LIFE := 1.0
## The jar's chips: the top-left of the view.
const CHIP_H := 50.0
const CHIP_W := 168.0
## The cups' level bars: where under the rim, how tall, how long held full.
const BAR_Y := 90.0
const BAR_H := 9.0
const BAR_HOLD := 0.35
const BAR_TRACK := Color(0.12, 0.08, 0.06, 0.4)

var sim: RefCounted
var font: Font
var interactive := true
var view := Rect2()
## The board's scale and where its (0, 0) lies.
var k := 1.0
var origin := Vector2.ZERO
var _clock := 0.0
var _finger := -99
var _start := Vector2.ZERO
var _at := Vector2.ZERO
var _moved := false
var _hold := 0.0
var _carry := -1
var _carry_at := Vector2.ZERO
var _cup_hit := PackedFloat32Array()
var _cup_up := PackedFloat32Array()
## How full each cup's bar is drawn, 0..1, easing after `cup_pts`.
var _fill := PackedFloat32Array()
var _floats: Array = []
var _pending := PackedFloat64Array()
var _pending_at := PackedFloat32Array()
var _flat_cache := {}
var _halos_live: ArrayMesh
var _balls_live: ArrayMesh
var _bonus_live: ArrayMesh
var _chips_live: ArrayMesh
var _bars_live: ArrayMesh
var _jar_hop := -10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_cup_hit.resize(Sim.CUPS)
	_cup_hit.fill(-10.0)
	_cup_up.resize(Sim.CUPS)
	_cup_up.fill(-10.0)
	_fill.resize(Sim.CUPS)
	_fill.fill(-1.0)
	_pending.resize(Sim.CUPS)
	_pending_at.resize(Sim.CUPS)
	_pending_at.fill(-10.0)
	resized.connect(_place)

func set_view(r: Rect2) -> void:
	view = r
	_place()

func _place() -> void:
	var r := view if view.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0:
		return
	# a little room round the board's own field
	var fit := minf((r.size.x - 8.0) / Sim.W, (r.size.y - 4.0) / Sim.H)
	k = maxf(0.1, fit)
	origin = r.position + (r.size - Vector2(Sim.W, Sim.H) * k) * 0.5
	queue_redraw()

func screen_of(p: Vector2) -> Vector2:
	return origin + p * k

func field_of(p: Vector2) -> Vector2:
	return (p - origin) / k

## A cup's middle at its rim, in pixels.
func cup_mid(c: int) -> Vector2:
	return screen_of(Vector2((c + 0.5) * Sim.CUP_W, Sim.CUP_TOP))

func _xf() -> Transform2D:
	return Transform2D(0.0, Vector2(k, k), 0.0, origin)

# --- the sim's moments, as the board shows them ---

func play(ev: Dictionary) -> void:
	match String(ev.type):
		"land":
			var c := int(ev.cup)
			_cup_hit[c] = _clock
			_pending[c] += float(ev.pay)
			if _clock - _pending_at[c] >= FLOAT_GAP:
				_float_cup(c)
		"cup":
			_cup_up[int(ev.cup)] = _clock
			_fill[int(ev.cup)] = 1.0
		"merge", "upgrade":
			_jar_hop = _clock

func _float_cup(c: int) -> void:
	if _pending[c] <= 0.0:
		return
	_pending_at[c] = _clock
	if _floats.size() >= FLOATS:
		_floats.pop_front()
	_floats.append({"text": "+" + Sim.short(_pending[c]), "c": c, "t": _clock, "dx": randf_range(-18.0, 18.0)})
	_pending[c] = 0.0

func tick(delta: float) -> void:
	_clock += delta
	if _finger != -99 and _carry < 0 and interactive:
		_hold += delta
		if _hold >= HOLD_EVERY:
			_hold -= HOLD_EVERY
			_drop_at(_at)
	for c in Sim.CUPS:
		if _pending[c] > 0.0 and _clock - _pending_at[c] >= FLOAT_GAP:
			_float_cup(c)
	while not _floats.is_empty() and _clock - float(_floats[0].t) > FLOAT_LIFE:
		_floats.pop_front()
	_ease_fills(delta)
	queue_redraw()

## A bar fills as marbles land; a level reached holds it full a moment,
## then it starts again from what is left over.
func _ease_fills(delta: float) -> void:
	if sim == null:
		return
	for c in Sim.CUPS:
		var want := clampf(float(sim.cup_pts[c]) / float(Sim.need(sim.cup_lv[c])), 0.0, 1.0)
		if _clock - _cup_up[c] < BAR_HOLD and not Motion.reduce:
			continue
		if _fill[c] < 0.0 or want < _fill[c] or Motion.reduce:
			_fill[c] = want
		else:
			_fill[c] = lerpf(_fill[c], want, 1.0 - exp(-12.0 * delta))

# --- drawing ---

func _draw() -> void:
	if sim == null:
		return
	draw_mesh(Art.velvet(size), null)
	var xf := _xf()
	draw_mesh(Art.rail(), null, xf)
	draw_mesh(Art.pins(), null, xf)
	# halos of the pins just touched
	var fb := Face.FlatBuilder.new(_flat_cache)
	var halo := Art.halo()
	var glow: PackedFloat32Array = sim.glow
	var now: float = sim.t
	if not Motion.reduce:
		for id in glow.size():
			var age := now - glow[id]
			if age >= 0.0 and age < GLOW:
				var a := 1.0 - age / GLOW
				fb.append(halo, xf * Transform2D(0.0, Vector2.ONE * (0.8 + 0.4 * a), 0.0, Sim.pin_pos(id)), Color(1, 1, 1, a))
	_halos_live = fb.mesh()
	if _halos_live != null:
		draw_mesh(_halos_live, null)
	# bonus pins: one mesh, breathing
	var bb := Face.FlatBuilder.new(_flat_cache)
	for id: int in sim.bonus:
		if id == _carry:
			continue
		var beat := 1.0 if Motion.reduce else 1.0 + 0.06 * sin(_clock * 3.0 + id)
		bb.append(Art.bonus_pin(String(sim.bonus[id])), xf * Transform2D(0.0, Vector2.ONE * beat, 0.0, Sim.pin_pos(id)))
	if _carry >= 0 and sim.bonus.has(_carry):
		var to := Sim.pin_near(field_of(_carry_at), Sim.DX)
		if to >= 0 and to != _carry and not sim.bonus.has(to):
			bb.append(Art.halo(), xf * Transform2D(0.0, Vector2.ONE * 1.3, 0.0, Sim.pin_pos(to)))
		bb.append(Art.bonus_pin(String(sim.bonus[_carry])), Transform2D(0.0, Vector2.ONE * k * 1.3, 0.0, _carry_at + Vector2(0, -40.0)))
	_bonus_live = bb.mesh()
	if _bonus_live != null:
		draw_mesh(_bonus_live, null)
	# the dropper, gliding
	var dx: float = Sim.dropper_x(sim.t)
	draw_mesh(Art.dropper(), null, xf * Transform2D(0.0, Vector2(dx, Sim.DROP_Y - 8.0)))
	# the marbles
	var mb := Face.FlatBuilder.new(_flat_cache)
	for b: Dictionary in sim.balls:
		var p: Vector2 = b.p
		var v: Vector2 = b.v
		var tier := int(b.tier)
		# a little stretch along the fall, never when still
		var st := 1.0 if Motion.reduce else clampf(1.0 + v.length() / 12000.0, 1.0, 1.07)
		var ang := v.angle() - PI * 0.5 if v.length() > 1.0 else 0.0
		var bx := xf * Transform2D(ang, Vector2(1.0 / sqrt(st), st), 0.0, p)
		mb.append(Art.marble(tier), bx)
		if float(b.boost) > 1.0:
			var kind := "times" if float(b.boost) >= Sim.TIMES else "plus"
			mb.append(Art.boost_ring(kind), xf * Transform2D(0.0, p))
	_balls_live = mb.mesh()
	if _balls_live != null:
		draw_mesh(_balls_live, null)
	_draw_worths()
	# the cups, each squashed as a marble lands in it
	for c in Sim.CUPS:
		var e := _clock - _cup_hit[c]
		var sq := 0.0 if Motion.reduce or e > 0.22 else sin(e / 0.22 * PI) * 0.07
		var at := Vector2((c + 0.5) * Sim.CUP_W, Sim.CUP_TOP)
		draw_mesh(Art.cup(c), null, xf * Transform2D(0.0, Vector2(1.0 + sq, 1.0 - sq), 0.0, at))
	_draw_bars(xf)
	_draw_words()
	_draw_jar()

## Each cup's way to its next level, a track and a fill, one mesh for the seven.
func _draw_bars(xf: Transform2D) -> void:
	var b := Face.Builder.new()
	var w := Sim.CUP_W - 10.0 - 44.0
	for c in Sim.CUPS:
		var at := xf * Vector2((c + 0.5) * Sim.CUP_W, Sim.CUP_TOP + BAR_Y)
		var bw := w * k
		var bh := BAR_H * k
		var left := at - Vector2(bw * 0.5, bh * 0.5)
		b.polygon(Face.Builder.round_rect(left, Vector2(bw, bh), bh * 0.45), BAR_TRACK)
		var f := maxf(0.0, _fill[c])
		if f > 0.0:
			var full := _clock - _cup_up[c] < BAR_HOLD
			var col := Art.CREAM if full else Art.PLUS
			b.polygon(Face.Builder.round_rect(left, Vector2(maxf(bh, bw * f), bh), bh * 0.45), col)
	_bars_live = b.mesh()
	draw_mesh(_bars_live, null)

func _write(text: String, at: Vector2, fs: int, col: Color, outline := 0, out_col := Color.BLACK) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := at + Vector2(-w * 0.5, fs * 0.36)
	if outline > 0:
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, out_col)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw_words() -> void:
	if font == null:
		return
	for c in Sim.CUPS:
		var at := screen_of(Vector2((c + 0.5) * Sim.CUP_W, Sim.CUP_TOP + 40.0))
		var hop := Motion.bump_scale(_clock - _cup_up[c], 0.3, 0.4)
		var fs := int(round(30.0 * k * hop))
		_write("×" + _mult_text(sim.cup_mult(c)), at, fs, Art.CREAM, int(6 * k), Color(Art.WOOD_DEEP, 0.9))
		_write(tr("BG_CUP_LV") % sim.cup_lv[c], at + Vector2(0, 27.0 * k), int(round(19.0 * k)), Color(Art.CREAM, 0.85))
	for f: Dictionary in _floats:
		var u := (_clock - float(f.t)) / FLOAT_LIFE
		var a := 1.0 - u * u
		var rise := 0.0 if Motion.reduce else 90.0 * k * (1.0 - pow(1.0 - u, 2.0))
		var at := cup_mid(int(f.c)) + Vector2(float(f.dx) * k, -30.0 * k - rise)
		_write(String(f.text), at, int(round(28.0 * k)), Color(Color("ffe08a"), a), int(6 * k), Color(Art.VELVET_LOW, 0.8 * a))

## What each marble in the air is worth before its cup, written on it:
## one string a marble, upright while the marble stretches.
func _draw_worths() -> void:
	if font == null:
		return
	var base: float = sim.value() * sim.polish()
	for b: Dictionary in sim.balls:
		var tier := int(b.tier)
		var text := Sim.short(base * Sim.worth(tier) * float(b.boost))
		var fs := int(round((20.0 if text.length() <= 2 else (17.0 if text.length() == 3 else 13.0)) * k))
		var c := Art.tier_colour(tier)
		var ink := Art.WOOD_DEEP.darkened(0.4) if c.get_luminance() > 0.5 else Color(Art.CREAM, 0.95)
		var at := screen_of(b.p as Vector2)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

static func _mult_text(m: float) -> String:
	if m >= 100.0:
		return Sim.short(m)
	if m >= 10.0:
		return String.num(m, 0) if is_equal_approx(m, round(m)) else String.num(m, 1)
	return String.num(m, 2).trim_suffix("0").trim_suffix(".0") if not is_equal_approx(m, round(m)) else str(int(m))

## The jar in the view's top-left: a chip a tier owned, its marble and
## "in the jar / owned".
func jar_rect() -> Rect2:
	var n := 0
	for t in Sim.TIERS:
		if sim.owned[t] > 0:
			n += 1
	n = mini(maxi(n, 1), 6)
	return Rect2(view.position + Vector2(14.0, 12.0), Vector2(CHIP_W, CHIP_H * n + 8.0 * (n - 1)))

func _draw_jar() -> void:
	var r := jar_rect()
	var b := Face.Builder.new()
	var y := r.position.y
	var rows := []
	for t in range(Sim.TIERS - 1, -1, -1):
		if sim.owned[t] <= 0:
			continue
		if rows.size() >= 6:
			break
		rows.append(t)
	var hop := Motion.bump_scale(_clock - _jar_hop, 0.08, 0.2)
	for t: int in rows:
		var cr := Rect2(Vector2(r.position.x, y), Vector2(CHIP_W, CHIP_H))
		b.polygon(Face.Builder.round_rect(cr.position, cr.size, CHIP_H * 0.5), Color(0.1, 0.06, 0.14, 0.45))
		y += CHIP_H + 8.0
	_chips_live = b.mesh()
	draw_mesh(_chips_live, null)
	y = r.position.y
	for t: int in rows:
		var mid := Vector2(r.position.x + CHIP_H * 0.5, y + CHIP_H * 0.5)
		draw_mesh(Art.marble(t), null, Transform2D(0.0, Vector2.ONE * 1.25 * hop, 0.0, mid))
		var txt := "%s/%s" % [Sim.short(float(sim.jar[t])), Sim.short(float(sim.owned[t]))]
		var empty: bool = sim.jar[t] == 0
		draw_string(font, Vector2(r.position.x + CHIP_H + 4.0, y + CHIP_H * 0.5 + 9.0), txt, HORIZONTAL_ALIGNMENT_LEFT, CHIP_W - CHIP_H - 10.0, 25, Color("ffd9a0") if empty else Art.CREAM)
		y += CHIP_H + 8.0

# --- fingers ---

func _gui_input(event: InputEvent) -> void:
	if not interactive or sim == null:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if _finger == -99:
				press(e.position, e.index)
		elif e.index == _finger:
			release(e.position)
		accept_event()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _finger:
			drag(e.position)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var e := event as InputEventMouseButton
		if e.pressed:
			if _finger == -99:
				press(e.position, -1)
		elif _finger == -1:
			release(e.position)
		accept_event()
	elif event is InputEventMouseMotion and _finger == -1:
		drag((event as InputEventMouseMotion).position)
		accept_event()

## A finger down at `p` (pixels). The jar's chips open the jar; a bonus pin
## is picked up; anywhere else a marble drops at once.
func press(p: Vector2, id := -1) -> void:
	_finger = id
	_start = p
	_at = p
	_moved = false
	_hold = 0.0
	_carry = -1
	if jar_rect().grow(6.0).has_point(p):
		_finger = -99
		jar_asked.emit()
		return
	var f := field_of(p)
	for pin: int in sim.bonus:
		if Sim.pin_pos(pin).distance_to(f) <= GRAB:
			_carry = pin
			_carry_at = p
			touched.emit(1.1)
			return
	_drop_at(p)

func drag(p: Vector2) -> void:
	_at = p
	if p.distance_to(_start) > TAP:
		_moved = true
	if _carry >= 0:
		_carry_at = p

func release(p: Vector2) -> void:
	_at = p
	if _carry >= 0:
		var from := _carry
		_carry = -1
		if not _moved:
			_drop_at(p)
		else:
			var to := Sim.pin_near(field_of(p + Vector2(0, -40.0)), Sim.DX)
			if not sim.move_bonus(from, to):
				touched.emit(0.86)
	_finger = -99

func _drop_at(p: Vector2) -> void:
	sim.drop(field_of(p).x)

## Lets go of any finger (a card opened over the board).
func let_go() -> void:
	_finger = -99
	_carry = -1
