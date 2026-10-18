extends Control

## Bagatelle's board (spec docs/superpowers/specs/2026-10-15-arcade-
## bagatelle-design.md): the velvet fills the whole Control, and the board
## itself -- rails and head bar, the dropper, pins, fins and cups -- is laid
## inside `view` (the room between the screen's plates and its tray) at the
## scale that fits it.
##
## A press asks the dropper for a marble (it glides on its own and is
## never steered); held, it keeps asking every HOLD_EVERY. A press on a
## bonus pin picks it up instead: drawn after the finger, it is
## set on the pin nearest where it is let go (or goes back if that cannot
## take it); a press on one let go at once is a drop.
##
## What moves (2026-10-18, the user: "animations are terrible"): dust
## drifts in the lamplight; a marble casts a shadow on the velvet and
## leaves a short trail as it falls; a struck pin glows and throws two
## sparks; a landed marble is seen dropping into its cup, rolling to the
## middle and sinking into the felt, and a soft light rises out of the cup
## (the user: "a light coming from the box"; taller and brighter for a big
## pay or a level) while its plate hops; the coins float up out of the cup.
##
## The dropper and the tube (2026-10-18, the user: "it should look like
## it's coming from the dropper cannon"): a marble is let go inside the
## barrel and is seen falling out of its mouth, the barrel kicking up a
## touch; a marble in a cup drops through it into the glass tube along the
## foot bar, rides it under the cups, up the right rail and along the head
## bar to the queue waiting at the dropper's side, which
## steps up one as each is let go. The tube is drawn; the jar is the
## sim's, so the queue shows what the jar holds less what is still on its
## way, at most QUEUE.
##
## Draw calls: the velvet, the rails, the pins, the fins, the cups' backs,
## the tube's glass and the bonus pins are cached meshes; the motes, the halos, every marble
## in the air (shadows, trails, bodies, rings, the settling ones, the ones
## in the tube) are each
## laid into one mesh a frame (Face.FlatBuilder); the seven cup fronts are
## one mesh each under their squash. The words are strings.

signal touched(pitch: float)
signal jar_asked

const Sim = preload("res://arcade/bagatelle_sim.gd")
const Art = preload("res://arcade/bagatelle_art.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

## How often a held finger asks for another marble.
const HOLD_EVERY := 0.16
## How long a pin's glow lasts, and a spark's flight.
const GLOW := 0.32
const SPARK_LIFE := 0.34
const SPARKS := 40
## How far a press may be from a bonus pin to pick it up, in field units.
const GRAB := 30.0
## A press that moves less than this (pixels) and lets go is a tap.
const TAP := 14.0
## Coins floated over a cup: at most this often a cup, and at most FLOATS.
const FLOAT_GAP := 0.14
const FLOATS := 22
const FLOAT_LIFE := 1.1
## The light out of a cup: how long it lives, how much bigger for a big pay.
const LIGHT_LIFE := 0.6
const LIGHT_BIG := 1.4
## ... how much bigger when the cup goes up a level, and how deep in the cup
## its foot lies (the front wall starts Art.LIP under the rim).
const LIGHT_LEVEL := 1.7
const LIGHT_FOOT := 40.0
## A landed marble's settle: how long it is seen in the cup, where it rests.
const SETTLE := 0.55
const REST_Y := Sim.CUP_TOP + 52.0
const SETTLED := 40
## The trail: how far behind the marble (seconds of its speed) each ghost lies.
const TRAIL := [0.014, 0.028]
const TRAIL_A := [0.26, 0.12]
const TRAIL_FROM := 420.0
## The jar's chips: the top-left of the view.
const CHIP_H := 50.0
const CHIP_W := 168.0
## The cups' level bars: where under the rim, how tall, how long held full.
const BAR_Y := 92.0
const BAR_H := 8.0
const BAR_HOLD := 0.35
const BAR_TRACK := Color(0.1, 0.05, 0.03, 0.55)
## The motes of dust in the lamplight.
const MOTES := 14
## The tube: how fast a marble rides it, how long after landing it drops
## out of its cup into it, the most riding at once, a queue slot's length,
## the most queued, and how long the queue takes to step up.
const PIPE_SPEED := 1500.0
const PIPE_UNDER := 0.3
const RIDERS := 24
const SLOT := 2.0 * Sim.BALL_R * Art.PIPE_K + 2.0
const QUEUE := 9
const QUEUE_STEP := 0.09
## How long and how far the barrel kicks as a marble is let go.
const KICK := 0.12
const KICK_UP := 4.0

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
var _cup_big := PackedByteArray()
var _cup_up := PackedFloat32Array()
## How full each cup's bar is drawn, 0..1, easing after `cup_pts`.
var _fill := PackedFloat32Array()
var _floats: Array = []
var _pending := PackedFloat64Array()
var _pending_at := PackedFloat32Array()
## Marbles seen settling in their cups: {x, c, tier, t, vx}.
var _settled: Array = []
## Sparks off struck pins: {p, v, t}.
var _sparks: Array = []
var _seen_glow := PackedFloat32Array()
## The motes: {p, drift, phase} in field units.
var _motes: Array = []
## Where the dropper is drawn (eases after the sim's), and its lean into
## its glide.
var _drop_vis := Sim.W * 0.5
var _drop_lean := 0.0
var _flat_cache := {}
var _motes_live: ArrayMesh
var _halos_live: ArrayMesh
var _balls_live: ArrayMesh
var _lights_live: ArrayMesh
var _bonus_live: ArrayMesh
var _chips_live: ArrayMesh
var _bars_live: ArrayMesh
var _jar_hop := -10.0
## Marbles on their way back up the tube: {tier, t, s} (t: when it drops
## into the tube, s: where along it, under its cup), and the tube's length
## along its path.
var _riders: Array = []
var _pipe_len := PackedFloat32Array()
## How many slots the queue is still to step up, and when the barrel kicked.
var _q_shift := 0.0
var _fired := -10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_cup_hit.resize(Sim.CUPS)
	_cup_hit.fill(-10.0)
	_cup_big.resize(Sim.CUPS)
	_cup_up.resize(Sim.CUPS)
	_cup_up.fill(-10.0)
	_fill.resize(Sim.CUPS)
	_fill.fill(-1.0)
	_pending.resize(Sim.CUPS)
	_pending_at.resize(Sim.CUPS)
	_pending_at.fill(-10.0)
	_seen_glow.resize(Sim.ROWS * Sim.ACROSS)
	_seen_glow.fill(-10.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in MOTES:
		_motes.append({"p": Vector2(rng.randf_range(60.0, Sim.W - 60.0), rng.randf_range(Art.HEAD_Y, Sim.CUP_TOP - 40.0)), "drift": Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-9.0, -3.0)), "phase": rng.randf_range(0.0, TAU)})
	var path := Art.pipe_path()
	_pipe_len.resize(path.size())
	for i in range(1, path.size()):
		_pipe_len[i] = _pipe_len[i - 1] + path[i].distance_to(path[i - 1])
	resized.connect(_place)

func set_view(r: Rect2) -> void:
	view = r
	_place()

func _place() -> void:
	var r := view if view.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0:
		return
	# the rails stand outside the field: room for them, and a little more
	var wide := Sim.W + Art.RAIL + Art.RAIL_R
	var fit := minf((r.size.x - 8.0) / wide, (r.size.y - 4.0) / (Art.FOOT_Y + Art.FOOT_H - Art.HEAD_Y + 6.0))
	k = maxf(0.1, fit)
	origin = r.position + Vector2((r.size.x - wide * k) * 0.5 + Art.RAIL * k, (r.size.y - (Art.FOOT_Y + Art.FOOT_H - Art.HEAD_Y + 6.0) * k) * 0.5 - Art.HEAD_Y * k)
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
			_cup_big[c] = 1 if (int(ev.tier) >= 3 or float(ev.pay) >= 20.0 * float(sim.value()) * float(sim.polish())) else 0
			_pending[c] += float(ev.pay)
			if _clock - _pending_at[c] >= FLOAT_GAP:
				_float_cup(c)
			if _settled.size() >= SETTLED:
				_settled.pop_front()
			_settled.append({"x": float(ev.x), "c": c, "tier": int(ev.tier), "t": _clock, "vx": float(ev.get("vx", 0.0))})
			if not Motion.reduce and _riders.size() < RIDERS:
				_riders.append({"tier": int(ev.tier), "t": _clock + PIPE_UNDER, "s": (c + 0.5) * Sim.CUP_W - Art.PIPE_START})
		"drop":
			_fired = _clock
			if not Motion.reduce:
				_q_shift = minf(_q_shift + 1.0, 2.0)
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
	_floats.append({"text": "+" + Sim.short(_pending[c]), "c": c, "t": _clock, "dx": randf_range(-16.0, 16.0), "big": _pending[c] >= 20.0 * float(sim.value()) * float(sim.polish())})
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
	while not _settled.is_empty() and _clock - float(_settled[0].t) > SETTLE:
		_settled.pop_front()
	while not _sparks.is_empty() and _clock - float(_sparks[0].t) > SPARK_LIFE:
		_sparks.pop_front()
	_ease_fills(delta)
	_q_shift = maxf(0.0, _q_shift - delta / QUEUE_STEP)
	if sim != null:
		# the dropper drawn a touch behind the sim's, leaning a little the
		# way it glides
		var target: float = sim.drop_x
		var was := _drop_vis
		_drop_vis = target if Motion.reduce else lerpf(_drop_vis, target, 1.0 - exp(-26.0 * delta))
		var vx := (_drop_vis - was) / maxf(delta, 0.001)
		_drop_lean = 0.0 if Motion.reduce else lerpf(_drop_lean, clampf(vx / 2400.0, -0.08, 0.08), 1.0 - exp(-8.0 * delta))
		_new_sparks()
		if not Motion.reduce:
			for m: Dictionary in _motes:
				var p: Vector2 = m.p + (m.drift as Vector2) * delta + Vector2(sin(_clock * 0.7 + float(m.phase)) * 4.0 * delta, 0.0)
				if p.y < Art.HEAD_Y - 20.0:
					p.y = Sim.CUP_TOP - 60.0
					p.x = randf_range(60.0, Sim.W - 60.0)
				p.x = clampf(p.x, 20.0, Sim.W - 20.0)
				m.p = p
	queue_redraw()

## Pins struck since last frame each throw two sparks.
func _new_sparks() -> void:
	if Motion.reduce:
		return
	var glow: PackedFloat32Array = sim.glow
	for id in glow.size():
		if glow[id] > _seen_glow[id]:
			_seen_glow[id] = glow[id]
			if _sparks.size() >= SPARKS - 2:
				continue
			var at := Sim.pin_pos(id)
			for j in 2:
				var ang := randf_range(-PI * 0.9, -PI * 0.1)
				_sparks.append({"p": at + Vector2.from_angle(ang) * 10.0, "v": Vector2.from_angle(ang) * randf_range(90.0, 180.0), "t": _clock})

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
	_draw_motes(xf)
	draw_mesh(Art.rails(), null, xf)
	draw_mesh(Art.pins(), null, xf)
	draw_mesh(Art.fins(), null, xf)
	_draw_halos(xf)
	_draw_bonus(xf)
	draw_mesh(Art.cups_back(), null, xf)
	# the light out of the cups, its foot hidden by their fronts
	_draw_lights(xf)
	_draw_marbles(xf)
	draw_mesh(Art.pipe_front(), null, xf)
	# the dropper, over the marbles it lets go, kicking up as one goes
	var fe := _clock - _fired
	var kick := 0.0 if Motion.reduce or fe > KICK or fe < 0.0 else -KICK_UP * sin(fe / KICK * PI)
	draw_mesh(Art.dropper(), null, xf * Transform2D(_drop_lean, Vector2(_drop_vis, Sim.DROP_Y + kick)))
	_draw_worths()
	# the cups' fronts, each with a breath as a marble lands in it
	for c in Sim.CUPS:
		var e := _clock - _cup_hit[c]
		var sq := 0.0 if Motion.reduce or e > 0.24 else sin(e / 0.24 * PI) * 0.025
		var at := Vector2((c + 0.5) * Sim.CUP_W, Sim.CUP_TOP)
		draw_mesh(Art.cup(c), null, xf * Transform2D(0.0, Vector2(1.0 + sq, 1.0 - sq * 0.6), 0.0, at))
	_draw_bars(xf)
	_draw_words()
	_draw_jar()

func _draw_motes(xf: Transform2D) -> void:
	if Motion.reduce:
		return
	var fb := Face.FlatBuilder.new(_flat_cache)
	var mote := Art.mote()
	for m: Dictionary in _motes:
		var a := 0.55 + 0.45 * sin(_clock * 1.3 + float(m.phase))
		fb.append(mote, xf * Transform2D(0.0, Vector2.ONE * (0.8 + 0.3 * a), 0.0, m.p as Vector2), Color(1, 1, 1, a))
	_motes_live = fb.mesh()
	if _motes_live != null:
		draw_mesh(_motes_live, null)

## The halos of the pins just touched, and their sparks.
func _draw_halos(xf: Transform2D) -> void:
	if Motion.reduce:
		return
	var fb := Face.FlatBuilder.new(_flat_cache)
	var halo := Art.halo()
	var glow: PackedFloat32Array = sim.glow
	var now: float = sim.t
	for id in glow.size():
		var age := now - glow[id]
		if age >= 0.0 and age < GLOW:
			var a := 1.0 - age / GLOW
			fb.append(halo, xf * Transform2D(0.0, Vector2.ONE * (0.7 + 0.5 * a), 0.0, Sim.pin_pos(id)), Color(1, 1, 1, a))
	var spark := Art.spark()
	for s: Dictionary in _sparks:
		var u := (_clock - float(s.t)) / SPARK_LIFE
		var p: Vector2 = (s.p as Vector2) + (s.v as Vector2) * u * SPARK_LIFE + Vector2(0.0, 260.0 * u * u)
		fb.append(spark, xf * Transform2D(0.0, Vector2.ONE * (1.0 - 0.5 * u), 0.0, p), Color(1, 1, 1, 1.0 - u * u))
	_halos_live = fb.mesh()
	if _halos_live != null:
		draw_mesh(_halos_live, null)

## The bonus pins: one mesh, breathing; a carried one after the finger.
func _draw_bonus(xf: Transform2D) -> void:
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

## Every marble: shadows first, then trails, bodies and rings, then the
## ones settling in their cups and the ones in the tube.
func _draw_marbles(xf: Transform2D) -> void:
	var mb := Face.FlatBuilder.new(_flat_cache)
	var shadow := Art.marble_shadow()
	var still := Motion.reduce
	for b: Dictionary in sim.balls:
		var p := _seen_at(b)
		mb.append(shadow, xf * Transform2D(0.0, p + Vector2(4.0, 8.0)))
	if not still:
		for b: Dictionary in sim.balls:
			var p: Vector2 = b.p
			var v: Vector2 = b.v
			var speed := v.length()
			if speed < TRAIL_FROM:
				continue
			var tier := int(b.tier)
			var tr := Art.trail(tier)
			var fade := clampf((speed - TRAIL_FROM) / 500.0, 0.0, 1.0)
			for i in TRAIL.size():
				var q := p - v * float(TRAIL[i])
				if q.y < Sim.DROP_Y:
					continue
				mb.append(tr, xf * Transform2D(0.0, Vector2.ONE * (1.0 - 0.12 * (i + 1)), 0.0, q), Color(1, 1, 1, float(TRAIL_A[i]) * fade))
	for b: Dictionary in sim.balls:
		var p := _seen_at(b)
		var v: Vector2 = b.v
		var tier := int(b.tier)
		# a little stretch along the fall, never when still
		var st := 1.0 if still else clampf(1.0 + v.length() / 14000.0, 1.0, 1.06)
		var ang := v.angle() - PI * 0.5 if v.length() > 1.0 else 0.0
		var bx := xf * Transform2D(ang, Vector2(1.0 / sqrt(st), st), 0.0, p)
		mb.append(Art.marble(tier), bx)
		if float(b.boost) > 1.0:
			var kind := "times" if float(b.boost) >= Sim.TIMES else "plus"
			mb.append(Art.boost_ring(kind), xf * Transform2D(0.0, p))
	# the marbles settling: they drop past the rim, roll toward the middle
	# and sink into the felt
	for s: Dictionary in _settled:
		var u := clampf((_clock - float(s.t)) / SETTLE, 0.0, 1.0)
		if still:
			u = 1.0
		var c := int(s.c)
		var mid := (c + 0.5) * Sim.CUP_W
		var fall := minf(1.0, u * 2.4)
		var y := lerpf(Sim.LAND_Y, REST_Y, 1.0 - (1.0 - fall) * (1.0 - fall)) - 6.0 * sin(clampf((u - 0.4) / 0.3, 0.0, 1.0) * PI)
		var x := lerpf(float(s.x) + float(s.vx) * 0.05 * fall, mid, u * u)
		var a := 1.0 if u < 0.7 else 1.0 - (u - 0.7) / 0.3
		var sc := 1.0 - 0.15 * u
		mb.append(Art.marble(int(s.tier)), xf * Transform2D(0.0, Vector2.ONE * sc, 0.0, Vector2(x, y)), Color(1, 1, 1, a))
	_draw_tube(mb, xf)
	_balls_live = mb.mesh()
	if _balls_live != null:
		draw_mesh(_balls_live, null)

## Where a marble in the air is drawn: still in the barrel (or just out of
## it) it rides the drawn dropper, which eases a touch behind the sim's.
func _seen_at(b: Dictionary) -> Vector2:
	var p: Vector2 = b.p
	var inside := clampf((Sim.DROP_Y + Sim.BALL_R * 2.0 - p.y) / (Sim.BALL_R * 2.0), 0.0, 1.0)
	return p + Vector2((_drop_vis - float(sim.drop_x)) * inside, 0.0)

## A point along the tube, `s` from its mouth.
func _pipe_at(s: float) -> Vector2:
	var path := Art.pipe_path()
	if s <= 0.0:
		return path[0]
	for i in range(1, path.size()):
		if s <= _pipe_len[i]:
			var seg := _pipe_len[i] - _pipe_len[i - 1]
			return path[i - 1].lerp(path[i], (s - _pipe_len[i - 1]) / maxf(seg, 0.001))
	return path[path.size() - 1]

## The queue at the dropper's side (the jar's best first, as it lets them
## go) and the marbles riding up to it.
func _draw_tube(mb: Face.FlatBuilder, xf: Transform2D) -> void:
	# the riders that have reached the queue's tail join it
	var total := _pipe_len[_pipe_len.size() - 1]
	var at_drop := total - (_drop_vis - Art.PIPE_CAP)
	var front := at_drop - Art.HOUSING - SLOT * 0.5
	var shown := clampi(int(sim.in_jar()) - _riders.size(), 0, QUEUE)
	var ri := 0
	while ri < _riders.size():
		if _rider_s(_riders[ri]) >= front - SLOT * shown:
			_riders.remove_at(ri)
			shown = clampi(int(sim.in_jar()) - _riders.size(), 0, QUEUE)
		else:
			ri += 1
	var sc := Vector2.ONE * Art.PIPE_K
	var jar: PackedInt64Array = sim.jar
	var k := jar.size() - 1
	var left := jar[k] if k >= 0 else 0
	for i in shown:
		while k > 0 and left <= 0:
			k -= 1
			left = jar[k]
		left -= 1
		mb.append(Art.marble(k), xf * Transform2D(0.0, sc, 0.0, _pipe_at(front - SLOT * (i + _q_shift))))
	for r: Dictionary in _riders:
		if _clock >= float(r.t):
			mb.append(Art.marble(int(r.tier)), xf * Transform2D(0.0, sc, 0.0, _pipe_at(_rider_s(r))))

## How far along the tube a rider is: eased in from rest under its cup,
## then riding at full speed.
func _rider_s(r: Dictionary) -> float:
	var e := maxf(0.0, _clock - float(r.t))
	return float(r.s) + e * PIPE_SPEED - PIPE_SPEED * 0.08 * (1.0 - exp(-e / 0.08))

## The light out of each cup a marble just dropped into: it rises fast
## and fades, one mesh for all, drawn before the cups' fronts so it is
## seen coming up from inside.
func _draw_lights(xf: Transform2D) -> void:
	if Motion.reduce:
		return
	var fb := Face.FlatBuilder.new(_flat_cache)
	var light := Art.cup_light()
	for c in Sim.CUPS:
		var e := _clock - _cup_hit[c]
		if e < 0.0 or e > LIGHT_LIFE:
			continue
		var u := e / LIGHT_LIFE
		var grow := 1.0 - pow(1.0 - u, 3.0)
		var level := _clock - _cup_up[c] < LIGHT_LIFE
		var big := LIGHT_LEVEL if level else (LIGHT_BIG if _cup_big[c] == 1 else 1.0)
		var a := (1.0 - u) * (1.0 if _cup_big[c] == 1 or level else 0.8)
		var at := Vector2((c + 0.5) * Sim.CUP_W, Sim.CUP_TOP + LIGHT_FOOT)
		fb.append(light, xf * Transform2D(0.0, Vector2(big * (0.9 + 0.1 * grow), big * (0.35 + 0.65 * grow)), 0.0, at), Color(1, 1, 1, a))
	_lights_live = fb.mesh()
	if _lights_live != null:
		draw_mesh(_lights_live, null)

## Each cup's way to its next level, a track and a fill, one mesh for the seven.
func _draw_bars(xf: Transform2D) -> void:
	var b := Face.Builder.new()
	var w := Sim.CUP_W - 10.0 - 46.0
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
		var at := screen_of(Vector2((c + 0.5) * Sim.CUP_W, Sim.CUP_TOP + Art.PLATE_Y))
		var hop := Motion.bump_scale(_clock - _cup_up[c], 0.3, 0.4) * (1.0 if Motion.reduce else Motion.bump_scale(_clock - _cup_hit[c], 0.08, 0.2))
		var fs := int(round(24.0 * k * hop))
		# engraved: a dark shadow a hair under the ink
		var txt := "×" + _mult_text(sim.cup_mult(c))
		_write(txt, at + Vector2(0, 1.5 * k), fs, Color(Art.WALNUT_DEEP, 0.55))
		_write(txt, at, fs, Art.WALNUT_DEEP.darkened(0.3))
		_write(tr("BG_CUP_LV") % sim.cup_lv[c], at + Vector2(0, 29.0 * k), int(round(17.0 * k)), Color(Art.CREAM, 0.8))
	for f: Dictionary in _floats:
		var u := (_clock - float(f.t)) / FLOAT_LIFE
		var a := 1.0 - u * u
		var rise := 0.0 if Motion.reduce else 110.0 * k * (1.0 - pow(1.0 - u, 2.2))
		var at := cup_mid(int(f.c)) + Vector2(float(f.dx) * k, -24.0 * k - rise)
		var big := bool(f.get("big", false))
		var pop := 1.0 if Motion.reduce else Motion.bump_scale(u * FLOAT_LIFE, 0.1, 0.25)
		var fs := int(round((34.0 if big else 27.0) * k * pop))
		_write(String(f.text), at, fs, Color(Color("ffe8a6") if big else Color("ffe08a"), a), int(6 * k), Color(Art.VELVET_LOW, 0.85 * a))

## What each marble in the air is worth before its cup, written on it:
## one string a marble, upright while the marble stretches.
func _draw_worths() -> void:
	if font == null:
		return
	var base: float = sim.value() * sim.polish()
	for b: Dictionary in sim.balls:
		if (b.p as Vector2).y < Sim.DROP_Y + Sim.BALL_R:
			continue
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
		b.polygon(Face.Builder.round_rect(cr.position + Vector2(0, 3), cr.size, CHIP_H * 0.5), Color(0, 0, 0, 0.25))
		b.polygon(Face.Builder.round_rect(cr.position, cr.size, CHIP_H * 0.5), Color(0.1, 0.06, 0.14, 0.55))
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
## is picked up; anywhere else a marble is asked for at once.
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

func _drop_at(_p: Vector2) -> void:
	sim.drop_here()

## Lets go of any finger (a card opened over the board).
func let_go() -> void:
	_finger = -99
	_carry = -1
