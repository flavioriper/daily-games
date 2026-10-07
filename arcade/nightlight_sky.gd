extends Control

## Nightlight's sky, drawn off a sim (arcade/nightlight_sim.gd): the night,
## the star's light on the dust round it, the gas, the bodies it has made,
## the star, and the star's end. The screen's field is one of these, and so
## are the tutorial's pages, so they cannot drift apart.
##
## The owner sets `sim`, calls `refresh` once a frame after stepping it, and
## tells it what the sim's events were (`ate`, `formed`, `met`, `tore`,
## `lit_up`). Five layers and about ten draws whatever the sky holds: the
## gas is one MultiMesh of soft lights, the solids three lit by one shader,
## every warm light one more, the star one square under its own shader.
##
## - **The disc is not drawn**, only the gas in it: it had a ring at its
##   edge until the user asked for it gone (2026-10-06: "remove this visual
##   indicator of the orbit, keep only the star at center").
## - **Nothing throws a shadow** (the same day: "they are on space it should
##   have no ground shadow"). A body's own far side is dark, in the shader.
## - **Nothing leaves a trail** (the same day: "remove the white dash behind
##   the bodies, create it only when body has ice and is closer to sun"): a
##   body that is ice, inside the frost line, has a tail that lies away from
##   the star, and that is all.
## - **The end is the star's layers leaving** (the same day: "supernova
##   animation should be more nice to see, not just a flash, but the layers
##   exploding and being ejected into gas to the space"): `begin_end` builds
##   a shell of gas for each thing the star is made of, in that thing's
##   colour, the outermost first and fastest; the owner calls `step_end`,
##   ends the sim at `end_swap()` and stops at `end_time()`.

const Sim = preload("res://arcade/nightlight_sim.gd")
const Art = preload("res://arcade/nightlight_art.gd")
const Motion = preload("res://core/motion.gd")

## The most solids and the most puffs drawn: the sim's own most, and the
## shells of an end.
const MOST := 320
const GAS_MOST := 480
## No solid is drawn smaller than this in the game, in the design's pixels.
const SMALL := 3.0
## A first puff's light is this wide, in the sim's pixels, and a heavier one
## wider by the cube root, GAS_WIDE of that at most; GAS_A is how much of it
## there is.
const GAS_R := 34.0
const GAS_WIDE := 2.2
const GAS_A := 0.2
## The tide pulls a body this much longer toward the star before it tears
## it, and as much thinner as keeps its size.
const PULLED := 0.4
## The star's light reaches this many of its radii, a quarter of it left
## there.
const REACH := 4.5
## Seconds a puff of light lasts where two bodies met.
const PUFF := 0.4
## A tail is this long at the frost line and TAIL_NEAR at the Roche radius,
## in the design's pixels.
const TAIL_FAR := 10.0
const TAIL_NEAR := 64.0

## The end, in seconds. A supernova: the core falls in for FALL, the layers
## leave, and at SWAP the new star starts to show; a star that lets go has no
## fall. A shell's puff lives LIFE seconds and gets FLY pixels of the design
## away, the outermost; RISE seconds for the new star and its gas to come up.
const END := {"nova": {"fall": 1.1, "swap": 3.6, "all": 7.4, "life": 5.6, "fly": 1250.0, "veil": 0.3},
	"fade": {"fall": 0.5, "swap": 5.0, "all": 9.0, "life": 7.5, "fly": 620.0, "veil": 0.0}}
const RISE := 2.0
## A shell has this many lobes: it leaves in fingers, not as a ring.
const LOBES := 9

var sim: RefCounted
## Pixels to one of the design's 1080 across; the star's place in this
## control.
var u := 1.0
var centre := Vector2.ZERO
## The corners are rounded off in this colour, `corner` pixels of the design.
var paper := Color.TRANSPARENT
var corner := 44.0
## No solid is drawn smaller than this, in the design's pixels: a tutorial's
## page, a third as big as the game, asks for more.
var small := SMALL

var _clock := 0.0
var _pulse := 0.0
var _bloom := 0.0
var _sky: ArrayMesh
var _sky_for := Vector3.ZERO
var _corners: ArrayMesh
var _puffs: Array = []               # {at, t, s}: the sim's units
var _body_mat: ShaderMaterial
var _star_mat: ShaderMaterial
var _light_l: Control
var _warm_l: Control
var _body_l: Control
var _star_l: Control
var _top_l: Control
var _warms: Batch
var _gas: Batch
var _lumps: Array[Batch] = []
## The end being played, or empty: {how, t, col, r, shells, swapped}.
var _end := {}
var _rise := 1.0

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

	## The same, drawn out `k` times as long along `along` (a unit vector)
	## and as much thinner across it, whichever way the mesh is turned.
	func put_pulled(at: Vector2, turn: float, s: float, along: Vector2, k: float, col: Color) -> void:
		if n >= mm.instance_count:
			return
		var x := Vector2(cos(turn), sin(turn)) * s
		var y := Vector2(-x.y, x.x)
		var across := Vector2(-along.y, along.x)
		var q := 1.0 / sqrt(k)
		x = along * (k * along.dot(x)) + across * (q * across.dot(x))
		y = along * (k * along.dot(y)) + across * (q * across.dot(y))
		var i := n * 12
		buf[i] = x.x
		buf[i + 1] = y.x
		buf[i + 3] = at.x
		buf[i + 4] = x.y
		buf[i + 5] = y.y
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
## to it stands over the sky and not under it.
func _init() -> void:
	clip_contents = true
	resized.connect(_on_resized)
	_body_mat = Art.body_material()
	_star_mat = Art.star_material()
	_light_l = _layer("Light", _draw_light, Art.adding())
	_warm_l = _layer("Warm", _draw_warm, Art.adding())
	_body_l = _layer("Bodies", _draw_bodies, _body_mat)
	_star_l = _layer("Star", _draw_star, _star_mat)
	_top_l = _layer("Top", _draw_top, null)
	_warms = Batch.new(Art.glow(2.0), MOST)
	_gas = Batch.new(Art.glow(1.6), GAS_MOST)
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

## The star as it is drawn, in pixels.
func star_px() -> float:
	return sim.seen_r() * u

# --- what the owner tells it ---

## The star ate something of `m`: it swells a little, and hardly at all for
## a puff of gas, which it eats all the time.
func ate(m: float, gas := false) -> void:
	if not Motion.reduce:
		_pulse = minf(1.5, _pulse + (0.01 if gas else 0.2) + 2.0 * m / sim.mass)

## A grain fell out of the gas at `at`.
func formed(at: Vector2) -> void:
	_puff(at, 0.3)

## Two bodies met at `at`.
func met(at: Vector2) -> void:
	_puff(at, 0.4)

## The tide tore a body of `m` at `at`: its dust catches the light.
func tore(at: Vector2, m: float) -> void:
	_puff(at, clampf(Sim.body_r(m) / 12.0, 0.3, 1.5))

## Something new lit in the star's core: it swells, and its light with it.
func lit_up() -> void:
	if not Motion.reduce:
		_pulse = 1.5
	_bloom = 1.0

func _puff(at: Vector2, s: float) -> void:
	if not Motion.reduce and _puffs.size() < 30:
		_puffs.append({"at": at, "t": 0.0, "s": s})

# --- the end ---

## The star's life ends as `how` ("nova" or "fade"): `shares` is what it is
## made of (Sim.layers), each of which leaves as a shell of gas in its own
## colour. Iron does not leave a supernova: it is the core that fell in.
func begin_end(how: String, shares: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + sim.novas * 13 + sim.fades
	var shells := []
	var last := shares.size() - (2 if how == "nova" else 1)
	for i in last:
		var share := float(shares[i])
		if share < 0.004:
			continue
		var turn := rng.randf() * TAU
		var lobes := PackedFloat32Array()
		for k in LOBES:
			lobes.append(rng.randf_range(0.6, 1.0))
		# the outermost layer leaves first and gets furthest
		var depth := float(i) / maxf(1.0, last - 1.0)
		for k in clampi(int(10.0 + 72.0 * sqrt(share)), 10, 72):
			var lobe := rng.randi() % LOBES
			shells.append({"a": turn + TAU * lobe / LOBES + rng.randfn(0.0, 0.17), "v": lerpf(1.0, 0.34, depth) * lobes[lobe] * rng.randf_range(0.82, 1.1),
				"s": rng.randf_range(0.7, 1.3), "wait": depth * 0.9 + rng.randf() * 0.3, "col": Art.MADE[i]})
	_end = {"how": how, "t": 0.0, "col": Art.burning_col(sim), "r": star_px(), "shells": shells, "swapped": false}
	_puffs.clear()

func ending() -> bool:
	return not _end.is_empty()

func step_end(delta: float) -> void:
	if not _end.is_empty():
		_end.t += delta

func end_t() -> float:
	return float(_end.t) if not _end.is_empty() else 0.0

## When the owner ends the sim, and when the whole of it is over.
func end_swap() -> float:
	return END[_end.how].swap if not _end.is_empty() else 0.0

func end_time() -> float:
	return END[_end.how].all if not _end.is_empty() else 0.0

## The sim has been ended: what is drawn from here on is the new star.
func swapped() -> void:
	if not _end.is_empty():
		_end.swapped = true
		_rise = 0.0
		_pulse = 0.0

func finish_end() -> void:
	_end = {}
	_rise = 1.0

## The owner has put another star in `sim` (the screen's Start over):
## nothing of the old one's swelling, light or puffs is left on it.
func started() -> void:
	_pulse = 0.0
	_bloom = 0.0
	_puffs.clear()

# --- a frame ---

## A frame: `delta` of the sim's time has passed (0 while it is held).
func refresh(delta: float) -> void:
	if sim == null:
		return
	if not Motion.reduce:
		_clock += delta
	_pulse *= exp(-delta * 3.0)
	_bloom *= exp(-delta * 1.4)
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
	for layer: Control in [_light_l, _warm_l, _body_l, _star_l, _top_l]:
		layer.queue_redraw()

func _breath() -> float:
	return 1.0 if Motion.reduce else 1.0 + 0.012 * sin(_clock * 0.9)

## How much of the old sky is still there as an end plays: all of it until
## the layers leave, none by the time the new star shows.
func _old() -> float:
	if _end.is_empty():
		return 1.0
	if _end.swapped:
		return 0.0
	var at: Dictionary = END[_end.how]
	return 1.0 - smoothstep(at.fall, at.fall + 1.2, float(_end.t))

## Every buffer for this frame, off where the bodies are now.
func _fill() -> void:
	var batches: Array[Batch] = [_warms, _gas]
	batches.append_array(_lumps)
	for batch in batches:
		batch.n = 0
	if not _end.is_empty() and _end.swapped:
		_rise = minf(1.0, _rise + get_process_delta_time() / RISE)
	var seen := _rise if not _end.is_empty() and _end.swapped else _old()
	var z: float = sim.zoom() * u
	var col := Art.burning_col(sim)
	var rh: float = sim.haze_r()
	var roche: float = sim.roche_r()
	var frost: float = sim.frost_r()
	var reach := star_px() * REACH
	if seen > 0.0:
		for b: Sim.Body in sim.bodies:
			var far := b.pos.length()
			if far < 1.0:
				continue
			var away := b.pos / far
			var at := centre + b.pos * z
			if b.kind == Sim.Kind.GAS:
				# cool far out, warm as the disc drags it in; thinner once its
				# dust has fallen out
				var wide := GAS_R * minf(GAS_WIDE, pow(b.m / Sim.PUFF, 1.0 / 3.0)) * z / Art.R
				var a := GAS_A * (1.0 if b.dust > 0.0 else 0.75) * minf(1.0, b.age * 2.0 + 0.2) * seen
				_gas.put(at, 0.0, wide, wide, Color(Art.GAS.lerp(Art.WARM, sqrt(b.heat)), a * (1.0 + 0.6 * b.heat)))
				continue
			var rb := Sim.body_r(b.m)
			var r := maxf(small * u, rb * z)
			var s := r / Art.R
			if b.heat > 0.0:
				var w := s * (2.2 + b.heat * 1.8)
				_warms.put(at, 0.0, w, w, Color(Art.WARM, b.heat * 0.5 * seen))
			# ice boils off inside the frost line, and what leaves it lies away
			# from the star, whichever way the body flies. Not inside the
			# Roche radius: a torn comet is a ring of pieces, and a tail on
			# each was a burst of rays round the star
			if b.ice >= Sim.ICE_LOOK and far < frost and far >= roche:
				var near := 1.0 - (far - roche) / maxf(1.0, frost - roche)
				var long := lerpf(TAIL_FAR, TAIL_NEAR, near) * u * minf(1.5, 0.6 + r / (8.0 * u))
				_warms.put(at + away * long * 0.5, away.angle(), long * 0.5 / Art.R, r * 2.4 / Art.R, Color(Art.TAIL, (0.16 + 0.2 * near) * b.ice * seen))
			var paint := Color(Art.paint_of(b.kind, b.ice), seen)
			# the tide draws a body out toward the star before it has it in pieces
			var strain: float = sim.tear_r(b.m) / far if far < roche else 0.0
			if strain > 0.5 and not Motion.reduce:
				_lumps[b.id % Art.LUMPS].put_pulled(at, b.spin, s, away, 1.0 + PULLED * smoothstep(0.5, 1.0, strain), paint)
			else:
				_lumps[b.id % Art.LUMPS].put(at, b.spin, s, s, paint)
	for p: Dictionary in _puffs:
		var k: float = p.t / PUFF
		var s := (30.0 + 60.0 * k) * float(p.s) * u / Art.R
		_warms.put(centre + (p.at as Vector2) * z, 0.0, s, s, Color(1.0, 0.89, 0.75, 0.5 * (1.0 - k)))
	_fill_end()
	for batch in batches:
		batch.send()
	var origin := get_global_transform()
	var sc := origin.get_scale().x
	_body_mat.set_shader_parameter("star", origin * centre)
	_body_mat.set_shader_parameter("reach", reach * sc)
	_body_mat.set_shader_parameter("haze", rh * z * sc)
	_body_mat.set_shader_parameter("star_col", Vector3(col.r, col.g, col.b))

## The shells of an end, each puff where its own speed has taken it: quick
## at first and slowing, wider and thinner as it goes. Under reduce motion
## they stand where they would be two seconds out and only come and go.
func _fill_end() -> void:
	if _end.is_empty():
		return
	var at: Dictionary = END[_end.how]
	var t: float = _end.t
	var life: float = at.life
	var r0: float = _end.r
	for p: Dictionary in _end.shells:
		var age := t - float(at.fall) - float(p.wait)
		if age <= 0.0 or age >= life:
			continue
		var k := age / life
		var shown := 2.0 / life if Motion.reduce else k
		# 1 - (1 - k)^3: most of the way in the first third
		var gone := 1.0 - pow(1.0 - shown, 3.0)
		var way := Vector2.from_angle(float(p.a) + (0.0 if Motion.reduce else 0.25 * k * float(p.v)))
		var far := r0 * 0.6 + float(at.fly) * u * float(p.v) * gone
		var wide := (30.0 + 78.0 * gone) * float(p.s) * u / Art.R
		var a := minf(1.0, age / 0.35) * (1.0 - smoothstep(0.45, 1.0, k)) * 0.36
		_gas.put(centre + way * far, 0.0, wide, wide, Color(p.col as Color, a))

# --- drawing ---

func _draw() -> void:
	if _sky != null:
		draw_mesh(_sky, null)

## How big and how much there the star is: itself, unless an end is playing.
## A supernova's core falls in, then the star is gone with its layers; a
## star that lets go only thins; the new one comes up small.
func _star_now() -> Vector2:
	if _end.is_empty():
		return Vector2(1.0, 1.0)
	if _end.swapped:
		return Vector2(lerpf(0.3, 1.0, ease(_rise, 0.4)), _rise)
	var at: Dictionary = END[_end.how]
	var t: float = _end.t
	if _end.how == "nova":
		var fall := clampf(t / float(at.fall), 0.0, 1.0)
		var after := clampf((t - float(at.fall)) / 0.5, 0.0, 1.0)
		return Vector2(lerpf(1.0, 0.7, fall * fall) * (1.0 + 0.5 * after), 1.0 - after)
	var thin := clampf(t / (float(at.swap) * 0.7), 0.0, 1.0)
	return Vector2(1.0 + 0.35 * thin, 1.0 - thin * thin)

## The star's light, lying on the dust round it.
func _draw_light() -> void:
	if sim == null:
		return
	# a star with nothing to burn lights half as far, and dully
	var now := _star_now()
	var col := Art.burning_col(sim)
	var r := star_px() * REACH * _breath() * (1.0 + _pulse * 0.1 + _bloom * 0.3) * lerpf(0.45, 1.0, sim.lit)
	_light_l.draw_mesh(Art.glow(3.2), null, Transform2D(0.0, Vector2(r, r) / Art.R, 0.0, centre), Color(col, lerpf(0.3, 0.5, sim.lit) * now.y))

## The gas and every warm light, then the star's own glow and what an end
## adds to it.
func _draw_warm() -> void:
	if sim == null:
		return
	_gas.show(_warm_l)
	_warms.show(_warm_l)
	var now := _star_now()
	var col := Art.burning_col(sim)
	var sr := star_px() * _breath() * (1.0 + _pulse * 0.04) * now.x
	_warm_l.draw_mesh(Art.glow(2.0), null, Transform2D(0.0, Vector2(sr, sr) * 2.1 / Art.R, 0.0, centre), Color(col, (0.34 + 0.2 * _bloom) * lerpf(0.4, 1.0, sim.lit) * now.y))
	if _end.is_empty() or _end.swapped:
		return
	var at: Dictionary = END[_end.how]
	var t: float = _end.t
	var since := t - float(at.fall)
	if _end.how == "nova":
		# the core falling in burns white, and what it leaves is a point of
		# light where the star was
		var fall := clampf(t / float(at.fall), 0.0, 1.0)
		var burst := exp(-maxf(0.0, since) * 1.6) if since > 0.0 else fall * fall
		var wide := sr * (1.6 + (2.6 * minf(1.0, since * 2.0) if since > 0.0 else 0.0))
		_warm_l.draw_mesh(Art.glow(1.6), null, Transform2D(0.0, Vector2(wide, wide) / Art.R, 0.0, centre), Color(Art.VEIL, 0.85 * burst))
	if since > 0.0:
		var left := 14.0 * u * (1.0 + 0.15 * sin(t * 9.0) * (0.0 if Motion.reduce else 1.0))
		_warm_l.draw_mesh(Art.glow(1.2), null, Transform2D(0.0, Vector2(left, left) / Art.R, 0.0, centre), Color(1.0, 1.0, 1.0, minf(1.0, since * 2.0)))

func _draw_bodies() -> void:
	for batch in _lumps:
		batch.show(_body_l)

func _draw_star() -> void:
	if sim == null:
		return
	var now := _star_now()
	if now.y <= 0.0:
		return
	var col := Art.burning_col(sim)
	if not _end.is_empty() and not _end.swapped and _end.how == "nova":
		col = col.lerp(Color.WHITE, clampf(float(_end.t) / float(END.nova.fall), 0.0, 1.0) * 0.7)
	_star_mat.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
	_star_mat.set_shader_parameter("lit", sim.lit)
	_star_mat.set_shader_parameter("clock", _clock)
	_star_mat.set_shader_parameter("fade", now.y)
	var sr := star_px() * _breath() * (1.0 + _pulse * 0.04) * now.x / Art.R
	_star_l.draw_mesh(Art.star_quad(), null, Transform2D(0.0, Vector2(sr, sr), 0.0, centre))

## Over everything: a breath of light as a supernova's layers leave, and the
## corners.
func _draw_top() -> void:
	if sim == null:
		return
	if not _end.is_empty() and not _end.swapped:
		var at: Dictionary = END[_end.how]
		var since := float(_end.t) - float(at.fall)
		if since > 0.0 and float(at.veil) > 0.0:
			_top_l.draw_rect(Rect2(Vector2.ZERO, size), Color(Art.VEIL, float(at.veil) * exp(-since * 2.2)))
	if _corners != null:
		_top_l.draw_mesh(_corners, null)
