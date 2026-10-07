extends Control

## Energy as motes of light, and their flight to the plate that counts them:
## Peapod's energy (docs/agents/arcade.md, the eighth pass), lifted out of
## arcade/peapod_screen.gd on 2026-10-06 so the Grove's is the same one (the
## user: "use the same energy as the peapod game (not shared energy but same
## pattern and animations)"). The mote's look is here for both; Peapod's
## screen still flies its own with the code this was copied from, and the
## numbers are the same.
##
## **Cozy light has no shape.** A mote is a round falloff from a bright heart
## to nothing, with no rim, no shine and no rays. Let go (`drop`), it drifts
## out every way and slows, lifts a little as warm light does, hangs a
## moment breathing, then goes round a bend of its own to the plate, slow
## and then quick, one after another, leaving a dust of smaller lights
## behind it and a soft glow on the plate as it lands. The light it throws
## is a second layer with BLEND_MODE_ADD off the same buffer (a blend is a
## canvas item's, not a draw's); the mote itself is ordinary alpha in a
## deeper blue, since added light alone is nothing on a pale ground.
##
## A layer over the whole screen, two draws at most (one MultiMesh each).
## The owner sets `target` (or `to`) and `u`, calls `drop`, shows its count
## less `due`, and hears `landed`. Under reduce motion nothing flies.

const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")

## Motes came down on the plate this frame: how many, and the note of the run
## they land on (the next one up while they keep landing), or -1 when the
## last was heard too short a while ago to play another.
signal landed(count: int, note: int)

## A mote's pale heart and the deeper blue its glow thins out through, so it
## reads on a pale sky or a paper plate.
const ORB := Color("3fc8ff")
const ORB_HI := Color("e6fbff")
const ORB_DEEP := Color("1f8fd0")
## The radius the mote's mesh is built at (big, so it is smooth; a draw
## scales it down).
const ORB_R := 64.0
const GLOW_RINGS := 5
const GLOW_SIDES := 28
## The most in the air at once, the seconds one drifts before it is drawn in
## (and as long again at most), the seconds in, and the beat between two of
## one drop.
const MOST := 150
const OUT := 0.34
const IN := 0.55
const GAP := 0.03
## Dust: the most specks, the seconds one lasts, and the units of a mote's
## way between two.
const MOST_DUST := 150
const DUST_T := 0.42
const DUST_STEP := 8.0
## A mote carrying more than its share is bigger, this many times at most.
const FAT := 1.6
const NOTE_GAP := 0.045

## The size of everything: Peapod's garden unit, 2.2 pixels at 810 wide.
var u := 2.2
## Where the motes land: the middle of `target` if there is one, else `to`,
## in this layer's own pixels.
var target: Control
var to := Vector2.ZERO
## What is in the air and not yet landed, in what `drop` was given.
var due := 0.0
## False on a layer something else steps (a tutorial's page, with `step`).
var auto := true
## True on a layer that plays whatever Motion.reduce says (a tutorial's page
## standing still at its telling moment).
var always := false
## What throws the motes; a page that must look the same twice seeds it.
var rng := RandomNumberGenerator.new()
## A mote and the light it throws, for an owner whose light is not the blue
## one (Nightlight's is gold, arcade/nightlight_art.gd): set before the first
## mote flies. Null is `orb()` and `orb_light()`.
var orb_mesh: ArrayMesh
var light_mesh: ArrayMesh

## {pos, vel, t, out, from, bend, val, size, seed, gone}
var _orbs: Array = []
## Four numbers a speck (x, y, when it was left, its size); `_dust_from` is
## the first that has not gone out.
var _dust := PackedFloat32Array()
var _dust_from := 0
var _clock := 0.0
var _pulse := -10.0
var _note := 0
var _heard := -10.0
var _mm: MultiMesh
var _light_mm: MultiMesh
var _buf := PackedFloat32Array()
var _count := 0
var _light: Control

static var _orb: ArrayMesh
static var _orb_light: ArrayMesh

func _ready() -> void:
	name = "Motes"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_light = Control.new()
	_light.name = "Light"
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = add
	_light.draw.connect(_draw_light)
	add_child(_light)

func _process(delta: float) -> void:
	if auto:
		step(delta)

# --- the look ---

## A soft light laid into a builder: `col` at `c`, thinning to nothing at
## `r` along a curve (`fall`: the higher, the smaller its bright heart), so
## it has no edge to see.
static func glow(b: Face.Builder, c: Vector2, r: float, col: Color, fall := 2.0) -> void:
	var mid := b.vertex(c, col)
	var first := b.verts.size()
	for ring in GLOW_RINGS:
		var t := float(ring + 1) / GLOW_RINGS
		var tint := Color(col, col.a * pow(1.0 - t, fall))
		for k in GLOW_SIDES:
			b.vertex(c + Vector2.from_angle(TAU * k / GLOW_SIDES) * r * t, tint)
	for k in GLOW_SIDES:
		var next := (k + 1) % GLOW_SIDES
		b.tri(mid, first + k, first + next)
		for ring in GLOW_RINGS - 1:
			var a := first + ring * GLOW_SIDES
			var o := a + GLOW_SIDES
			b.tri(a + k, o + k, o + next)
			b.tri(a + k, o + next, a + next)

## A mote of energy, centred, its glow ORB_R in radius: nothing but light. A
## wide blue glow thinning to nothing, a paler one in it and a white heart,
## each with no edge. No rim, no shine and no rays: a rim and a shine made it
## a ball, rays made it lightning.
static func orb() -> ArrayMesh:
	if _orb == null:
		var b := Face.Builder.new()
		var r := ORB_R
		glow(b, Vector2.ZERO, r, Color(ORB_DEEP, 0.62), 1.5)
		glow(b, Vector2.ZERO, 0.62 * r, Color(ORB, 0.95), 1.4)
		glow(b, Vector2.ZERO, 0.4 * r, Color(ORB_HI, 1.0), 1.2)
		glow(b, Vector2.ZERO, 0.26 * r, Color.WHITE, 0.9)
		_orb = b.mesh()
	return _orb

## The light a mote throws round itself, centred and ORB_R in radius: drawn
## over the motes and added to what is under it, so what is behind a mote is
## lit by it.
static func orb_light() -> ArrayMesh:
	if _orb_light == null:
		var b := Face.Builder.new()
		glow(b, Vector2.ZERO, ORB_R, Color(0.3, 0.62, 1.0, 0.42), 1.8)
		_orb_light = b.mesh()
	return _orb_light

## The scale that draws `orb()` as what a price is counted in, in a box
## `side` pixels square.
static func icon_scale(side: float) -> float:
	return side * 0.9 / ORB_R

## A mote of energy on a Control `side` pixels square: what a price is
## counted in, beside its figure (the Grove's shop and its tree of skills).
static func icon(side: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(side, side)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var sc := icon_scale(side)
		c.draw_mesh(orb(), null, Transform2D(0.0, Vector2(sc, sc), 0.0, c.size * 0.5)))
	return c

# --- the flight ---

## Something worth `n` is gone at `at` (the viewport's pixels): its energy
## drifts out of it every way as `shown` motes, each to hang a moment before
## it is drawn in.
func drop(at: Vector2, n: float, shown: int) -> void:
	if n <= 0.0 or (Motion.reduce and not always):
		return
	shown = mini(shown, MOST - _orbs.size())
	if shown <= 0:
		return
	var from := get_global_transform().affine_inverse() * at
	var each := n / shown
	var fat := minf(sqrt(each), FAT)
	for i in shown:
		var way := Vector2.from_angle(rng.randf() * TAU)
		var speed := rng.randf_range(110.0, 380.0) * u / 2.4 * (1.0 + 0.012 * shown)
		_orbs.append({"pos": from + way * 5.0 * u, "vel": way * speed, "t": -GAP * 0.4 * i,
			"out": OUT * rng.randf_range(1.0, 1.7) + GAP * i, "from": from, "bend": rng.randf_range(-1.0, 1.0), "val": each,
			"size": rng.randf_range(0.7, 1.2) * fat, "seed": rng.randf() * 100.0, "gone": 0.0})
	due += n

## Nothing is left in the air: the owner counts what there is.
func clear() -> void:
	_orbs.clear()
	due = 0.0
	_dust.clear()
	_dust_from = 0
	_pulse = -10.0
	queue_redraw()
	_light.queue_redraw()

func _to() -> Vector2:
	if target == null:
		return to
	return get_global_transform().affine_inverse() * (target.get_global_transform() * (target.size * 0.5))

## Each mote: let go and slowing, lifting a little, then round its bend to
## the plate, slow and then quick, a speck of dust left every DUST_STEP of
## the way. One that lands is counted and seen as a glow on the plate.
func step(delta: float) -> void:
	_clock += delta
	if _orbs.is_empty():
		due = 0.0
	else:
		_fly(delta)
	if not _orbs.is_empty() or _count > 0 or (_dust.size() >> 2) > _dust_from or _clock - _pulse < 0.3:
		queue_redraw()
		_light.queue_redraw()

func _fly(delta: float) -> void:
	var end := _to()
	var down := 0
	var slow := exp(-5.5 * delta)
	var lift := 26.0 * u / 2.4 * delta
	var stride := DUST_STEP * u
	for o: Dictionary in _orbs:
		o.t += delta
		var t: float = o.t
		if t < 0.0:
			continue
		var was: Vector2 = o.pos
		if t < float(o.out):
			var v: Vector2 = o.vel
			v *= slow
			o.vel = v
			o.pos = was + v * delta + Vector2(0, -lift)
			o.from = o.pos
		else:
			var k := clampf((t - float(o.out)) / IN, 0.0, 1.0)
			var e := k * k * (0.35 + 0.65 * k)
			var from: Vector2 = o.from
			var side := (end - from).orthogonal() * 0.28 * float(o.bend)
			var mid := from.lerp(end, 0.4) + side
			o.pos = from.lerp(mid, e).lerp(mid.lerp(end, e), e)
			o.gone = float(o.gone) + was.distance_to(o.pos)
			if float(o.gone) >= stride:
				o.gone = 0.0
				_leave_dust(was, float(o.size))
			if k >= 1.0:
				o.t = INF
				down += 1
				due -= float(o.val)
	if down == 0:
		return
	_orbs = _orbs.filter(func(o: Dictionary) -> bool: return o.t != INF)
	_pulse = _clock
	var note := -1
	if _clock - _heard >= NOTE_GAP:
		# a run of notes up the scale while they keep landing
		_note = _note + 1 if _clock - _heard < 0.3 else 0
		_heard = _clock
		note = _note
	landed.emit(down, note)

## A speck of light left where a mote just was, a little off its line.
func _leave_dust(at: Vector2, size: float) -> void:
	if (_dust.size() >> 2) - _dust_from >= MOST_DUST:
		return
	if _dust_from > 256:
		_dust = _dust.slice(_dust_from * 4)
		_dust_from = 0
	_dust.append(at.x + rng.randf_range(-2.0, 2.0) * u)
	_dust.append(at.y + rng.randf_range(-2.0, 2.0) * u)
	_dust.append(_clock)
	_dust.append(size * rng.randf_range(0.26, 0.46))

# --- drawing ---

## The motes, their dust under them and the glow on the plate as one lands,
## all one mesh: a mote swells out of what let it go, breathes where it hangs
## (each to its own time) and stays round on its way in, dimming a little as
## it nears the plate; a speck of dust shrinks and goes out.
func _draw() -> void:
	var lit := clampf(1.0 - (_clock - _pulse) / 0.3, 0.0, 1.0)
	if _orbs.is_empty() and (_dust.size() >> 2) <= _dust_from and lit <= 0.0:
		_count = 0
		return
	var most := MOST + MOST_DUST + 1
	if _mm == null:
		_mm = MultiMesh.new()
		_mm.transform_format = MultiMesh.TRANSFORM_2D
		_mm.use_colors = true
		_mm.mesh = orb_mesh if orb_mesh != null else orb()
		_mm.instance_count = most
		_light_mm = MultiMesh.new()
		_light_mm.transform_format = MultiMesh.TRANSFORM_2D
		_light_mm.use_colors = true
		_light_mm.mesh = light_mesh if light_mesh != null else orb_light()
		_light_mm.instance_count = most
		_buf.resize(most * 12)
	var n := 0
	var base := 11.5 * u / ORB_R
	# the dust first, under the motes; what has gone out is passed over for good
	var specks := _dust.size() >> 2
	while _dust_from < specks and _clock - _dust[_dust_from * 4 + 2] >= DUST_T:
		_dust_from += 1
	for d in range(_dust_from, specks):
		var age := (_clock - _dust[d * 4 + 2]) / DUST_T
		n = _put(n, Vector2(_dust[d * 4], _dust[d * 4 + 1] - 7.0 * u * age), base * _dust[d * 4 + 3] * (1.0 - 0.5 * age), 1.0 - age * age)
	if lit > 0.0:
		n = _put(n, _to(), base * (2.2 + 1.6 * (1.0 - lit)), 0.55 * lit * lit)
	for o: Dictionary in _orbs:
		var t: float = o.t
		if t < 0.0 or n >= most:
			continue
		var seed: float = o.seed
		var swell := 1.0 - pow(1.0 - minf(1.0, t / 0.22), 3.0)
		var breath := 1.0 + 0.13 * sin(_clock * 4.6 + seed)
		var near := clampf((t - float(o.out)) / IN, 0.0, 1.0)
		var s: float = base * float(o.size) * swell * breath * (1.0 - 0.3 * near * near)
		var at: Vector2 = o.pos
		# hanging, it wanders a little on the air
		at += Vector2(sin(_clock * 2.3 + seed), cos(_clock * 1.9 + seed * 1.7)) * 1.6 * u * (1.0 - near)
		n = _put(n, at, s, 0.84 + 0.16 * sin(_clock * 6.1 + seed * 3.0))
	_count = n
	if n == 0:
		return
	_mm.visible_instance_count = n
	_mm.buffer = _buf
	draw_multimesh(_mm, null)

## One more light this frame: at `at`, `s` times the mesh, `a` of its glow.
func _put(n: int, at: Vector2, s: float, a: float) -> int:
	var i := n * 12
	_buf[i] = s
	_buf[i + 1] = 0.0
	_buf[i + 3] = at.x
	_buf[i + 4] = 0.0
	_buf[i + 5] = s
	_buf[i + 7] = at.y
	_buf[i + 8] = 1.0
	_buf[i + 9] = 1.0
	_buf[i + 10] = 1.0
	_buf[i + 11] = a
	return n + 1

## The light the motes throw: the same lights again, added to what is under
## them. Drawn after `_draw` (it is this layer's child), off the buffer that
## filled.
func _draw_light() -> void:
	if _count == 0 or _light_mm == null:
		return
	_light_mm.visible_instance_count = _count
	_light_mm.buffer = _buf
	_light.draw_multimesh(_light_mm, null)
