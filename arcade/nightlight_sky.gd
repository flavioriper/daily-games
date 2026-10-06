extends Control

## Nightlight's sky, drawn off a sim (arcade/nightlight_sim.gd): the night,
## the star's light on the dust round it, the bodies with their shadows,
## trails and warmth, and the star. The haze that drags them is not drawn:
## it had a ring at its edge and grains in orbit inside it until the user
## asked for them gone (2026-10-06: "remove this visual indicator of the
## orbit, keep only the star at center"). The
## screen's field is one of these, and so are the tutorial's pages and the
## Arcade card's picture, so the three cannot drift apart.
##
## The owner sets `sim`, calls `refresh` once a frame after stepping it, and
## tells it what the sim's events were (`ate`, `met`). Seven layers, about
## twelve draws and one more for each trail: the bodies are three
## MultiMeshes lit by one shader, their shadows one, every warm light one.
## Light is added and has no shape; a shadow is the only dark thing.

const Sim = preload("res://arcade/nightlight_sim.gd")
const Art = preload("res://arcade/nightlight_art.gd")
const Motion = preload("res://core/motion.gd")

## The most bodies drawn, and dots of a throw's path.
const MOST := 200
const DOTS := 64
## No body is drawn smaller than this, in the design's pixels: a thrown
## meteor is small, and still has a lit side.
const SMALL := 6.0
## The star's light reaches this many of its radii, a quarter of it left
## there.
const REACH := 9.0
## Seconds a puff lasts where two bodies met.
const PUFF := 0.4
## A trail is this much of its body's radius wide: a line behind it, not a
## band as wide as it is.
const TRAIL_WIDE := 0.5

var sim: RefCounted
## Pixels to one of the design's 1080 across; the star's place in this
## control.
var u := 1.0
var centre := Vector2.ZERO
## The corners are rounded off in this colour, `corner` pixels of the design.
var paper := Color.TRANSPARENT
var corner := 44.0
## A throw being aimed: {from, to} in this control's pixels, {pts, hit} from
## Sim.predict. Empty when none is.
var aim := {}
## The supernova: how far the star has swollen into a light that takes the
## sky, and how much of the sky that light still covers, both 0 to 1.
var swell := 0.0
var veil := 0.0

var _clock := 0.0
var _pulse := 0.0
var _sky: ArrayMesh
var _sky_for := Vector3.ZERO
var _corners: ArrayMesh
var _puffs: Array = []               # {at, t}: the sim's units
var _body_mat: ShaderMaterial
var _light_l: Control
var _shade_l: Control
var _warm_l: Control
var _body_l: Control
var _star_l: Control
var _top_l: Control
var _shades: Batch
var _warms: Batch
var _dots: Batch
var _lumps: Array[Batch] = []

## One MultiMesh and the buffer that fills it each frame.
class Batch:
	var mm := MultiMesh.new()
	var buf := PackedFloat32Array()
	var n := 0

	func _init(mesh: Mesh, most: int) -> void:
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = most
		mm.visible_instance_count = 0
		buf.resize(most * 12)

	## One more instance: the mesh turned by `turn`, `sx` by `sy` times its
	## size, at `at`, in `col`.
	func put(at: Vector2, turn: float, sx: float, sy: float, col: Color) -> void:
		if n >= mm.instance_count:
			return
		var c := cos(turn)
		var s := sin(turn)
		var i := n * 12
		buf[i] = c * sx
		buf[i + 1] = -s * sy
		buf[i + 3] = at.x
		buf[i + 4] = s * sx
		buf[i + 5] = c * sy
		buf[i + 7] = at.y
		buf[i + 8] = col.r
		buf[i + 9] = col.g
		buf[i + 10] = col.b
		buf[i + 11] = col.a
		n += 1

	func send() -> void:
		mm.visible_instance_count = n
		if n > 0:
			mm.buffer = buf

	func show(on: CanvasItem) -> void:
		if n > 0:
			on.draw_multimesh(mm, null)

## Built as it is made and not as it enters the tree, so what its owner adds
## to it (a pouch, a button) stands over the sky and not under it.
func _init() -> void:
	clip_contents = true
	resized.connect(_on_resized)
	_body_mat = Art.body_material()
	_light_l = _layer("Light", _draw_light, Art.adding())
	_shade_l = _layer("Shade", _draw_shade, null)
	_warm_l = _layer("Warm", _draw_warm, Art.adding())
	_body_l = _layer("Bodies", _draw_bodies, _body_mat)
	_star_l = _layer("Star", _draw_star, null)
	_top_l = _layer("Top", _draw_top, null)
	_shades = Batch.new(Art.shadow(), MOST)
	_warms = Batch.new(Art.glow(2.0), MOST * 2)
	_dots = Batch.new(Art.dot(), DOTS)
	for v in Art.LUMPS:
		_lumps.append(Batch.new(Art.lump(v), MOST))
	_on_resized()

func _layer(called: String, draws: Callable, mat: Material) -> Control:
	var layer := Control.new()
	layer.name = called
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.material = mat
	layer.draw.connect(draws)
	add_child(layer)
	return layer

func _on_resized() -> void:
	queue_redraw()

## A point of the sim, in this control's pixels.
func px(p: Vector2) -> Vector2:
	return centre + p * (sim.zoom() * u)

## The point of the sim under a point of this control.
func unit(at: Vector2) -> Vector2:
	return (at - centre) / (sim.zoom() * u)

## The star as it is drawn, in pixels.
func star_px() -> float:
	return sim.seen_r() * u

# --- what the owner tells it ---

## The star ate something of `m`: it swells a little.
func ate(m: float) -> void:
	if not Motion.reduce:
		_pulse = minf(1.5, _pulse + 0.2 + 2.0 * m / sim.mass)

## Two bodies met at `at`.
func met(at: Vector2) -> void:
	if not Motion.reduce and _puffs.size() < 30:
		_puffs.append({"at": at, "t": 0.0})

## A frame: `delta` of the sim's time has passed (0 while it is held).
func refresh(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	_pulse *= exp(-delta * 3.0)
	for p: Dictionary in _puffs:
		p.t += delta
	_puffs = _puffs.filter(func(p: Dictionary) -> bool: return p.t < PUFF)
	_fill()
	var want := Vector3(size.x, size.y, sim.novas)
	if want != _sky_for and size.x > 0.0:
		_sky_for = want
		_sky = Art.sky(size, sim.novas)
		_corners = Art.corners(size, corner * u, paper) if paper.a > 0.0 else null
		queue_redraw()
	for layer: Control in [_light_l, _shade_l, _warm_l, _body_l, _star_l, _top_l]:
		layer.queue_redraw()

func _breath() -> float:
	return 1.0 if Motion.reduce else 1.0 + 0.03 * sin(_clock * 1.3)

## Every buffer for this frame, off where the bodies are now.
func _fill() -> void:
	var batches: Array[Batch] = [_shades, _warms, _dots]
	batches.append_array(_lumps)
	for batch in batches:
		batch.n = 0
	var z: float = sim.zoom() * u
	var col := Art.star_col(sim.mass)
	var rh: float = sim.haze_r()
	var reach := star_px() * REACH
	for b: Sim.Body in sim.bodies:
		var far := b.pos.length()
		if far < 1.0:
			continue
		var away := b.pos / far
		var at := centre + b.pos * z
		var r := maxf(SMALL * u, Sim.body_r(b.m) * z)
		var k := far * z / reach
		var lit := 1.0 / (1.0 + 3.0 * k * k)
		var s := r / Art.R
		if lit >= 0.1:
			_shades.put(at, away.angle(), s, s, Color(1, 1, 1, 0.5 * lit))
		# the haze warms what it drags; an ash is still warm from the star it left
		var warm := maxf(0.3, b.heat) if b.kind == Sim.Kind.ASH else b.heat
		if warm > 0.0:
			var w := s * (2.2 + b.heat * 1.8)
			_warms.put(at, 0.0, w, w, Color(Art.WARM, warm * 0.6))
		# a comet's tail lies away from the star, whichever way it flies
		if b.kind == Sim.Kind.COMET and lit > 0.12:
			var long := s * (3.0 + 10.0 * lit)
			_warms.put(at + away * long * Art.R * 0.5, away.angle(), long * 0.5, s * 0.9, Color(Art.TAIL, 0.4 * lit))
		_lumps[b.id % Art.LUMPS].put(at, b.spin, s, s, Art.PAINT[b.kind])
	for p: Dictionary in _puffs:
		var k: float = p.t / PUFF
		var s := (30.0 + 60.0 * k) * u / Art.R
		_warms.put(centre + (p.at as Vector2) * z, 0.0, s, s, Color(1.0, 0.89, 0.75, 0.5 * (1.0 - k)))
	if not aim.is_empty():
		var pts: PackedVector2Array = aim.pts
		var n := mini(pts.size(), DOTS)
		for i in n:
			var k := float(i) / n
			var s := (5.5 - 2.5 * k) * u / Art.R
			_dots.put(centre + pts[i] * z, 0.0, s, s, Color(1.0, 0.965, 0.9, 0.8 * (1.0 - k) + 0.08))
	for batch in batches:
		batch.send()
	var origin := get_global_transform()
	var sc := origin.get_scale().x
	_body_mat.set_shader_parameter("star", origin * centre)
	_body_mat.set_shader_parameter("reach", reach * sc)
	_body_mat.set_shader_parameter("haze", rh * z * sc)
	_body_mat.set_shader_parameter("star_col", Vector3(col.r, col.g, col.b))

# --- drawing ---

func _draw() -> void:
	if _sky != null:
		draw_mesh(_sky, null)

## The star's light, lying on the dust round it.
func _draw_light() -> void:
	if sim == null:
		return
	var col := Art.star_col(sim.mass)
	var r := star_px() * REACH * _breath() * (1.0 + _pulse * 0.25)
	_light_l.draw_mesh(Art.glow(3.2), null, Transform2D(0.0, Vector2(r, r) / Art.R, 0.0, centre), Color(col, 0.5))

## Shadows, thrown straight away from the star: seen where its light lies.
func _draw_shade() -> void:
	_shades.show(_shade_l)

## Where each body has been (the spiral is read off these), then its warmth.
func _draw_warm() -> void:
	if sim == null:
		return
	var z: float = sim.zoom() * u
	_warm_l.draw_set_transform(centre, 0.0, Vector2(z, z))
	var drawn := 0
	for b: Sim.Body in sim.bodies:
		var n := b.trail.size()
		if n < 2 or drawn >= MOST:
			continue
		drawn += 1
		_warm_l.draw_polyline_colors(b.trail, Art.ramp(n, b.heat), maxf(SMALL * u, Sim.body_r(b.m) * z) * TRAIL_WIDE / z)
	_warm_l.draw_set_transform(Vector2.ZERO)
	_warms.show(_warm_l)
	var sr := star_px() * _breath() * (1.0 + _pulse * 0.12)
	_warm_l.draw_mesh(Art.glow(2.0), null, Transform2D(0.0, Vector2(sr, sr) * 2.4 / Art.R, 0.0, centre), Color(Art.star_col(sim.mass), 0.4 + 0.2 * minf(1.0, _pulse)))
	if swell > 0.0:
		var big := sr + 1500.0 * u * pow(swell, 1.5)
		_warm_l.draw_mesh(Art.glow(1.2), null, Transform2D(0.0, Vector2(big, big) / Art.R, 0.0, centre), Art.VEIL)

func _draw_bodies() -> void:
	for batch in _lumps:
		batch.show(_body_l)

func _draw_star() -> void:
	if sim == null:
		return
	var sr := star_px() * _breath() * (1.0 + _pulse * 0.12) / Art.R
	var at := Transform2D(0.0, Vector2(sr, sr), 0.0, centre)
	_star_l.draw_mesh(Art.star(), null, at, Art.star_col(sim.mass))
	_star_l.draw_mesh(Art.core(), null, at)

## Over everything: a throw being aimed, the supernova's light, the corners.
func _draw_top() -> void:
	if sim == null:
		return
	if not aim.is_empty():
		var cream := Color(1.0, 0.965, 0.9)
		var from: Vector2 = aim.from
		var r := maxf(SMALL * u, Sim.body_r(sim.meteor_mass()) * sim.zoom() * u)
		_dots.show(_top_l)
		if aim.hit:
			_top_l.draw_arc(centre, star_px() * 1.35, 0.0, TAU, 64, Color(cream, 0.6), 5.0 * u, true)
		_top_l.draw_line(from, aim.to, Color(cream, 0.45), 6.0 * u, true)
		_top_l.draw_circle(aim.to, 9.0 * u, Color(cream, 0.7), true, -1.0, true)
		_top_l.draw_circle(from, r + 4.0 * u, Color(cream, 0.9), true, -1.0, true)
		_top_l.draw_circle(from, r, Art.PAINT[Sim.Kind.METEOR], true, -1.0, true)
	if veil > 0.0:
		_top_l.draw_rect(Rect2(Vector2.ZERO, size), Color(Art.VEIL, clampf(veil, 0.0, 1.0)))
	if _corners != null:
		_top_l.draw_mesh(_corners, null)
