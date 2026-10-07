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
## - **The universe round the star** (2026-10-07): each relic (sim.relics) is
##   a soft light, or a dark disc in a warm ring for a black hole, with its
##   nebula, a seeded ring of the dead star's layers' colours spreading and
##   thinning over its age, in the gas batch; the five neighbour stars are
##   two warm lights each; a far field of stars, one mesh, lies under
##   everything and slides a little with the camera. No rays, beams or
##   lensing arcs: cozy light has no shape. Every point of the sim goes
##   through `world()`, which honours the camera's `shift` and `view`.
## - **The camera moves only for an end** (the same day): from the swap it
##   holds the dead star's place under `centre`, pulls back until the
##   birthplace fits, pans to the new star and closes in on it as it
##   condenses out of its gas (`swapped`, `_camera`). A first star plays the
##   close alone (`begin_birth`). Under reduce motion it is a cut.

const Sim = preload("res://arcade/nightlight_sim.gd")
const Art = preload("res://arcade/nightlight_art.gd")
const Motion = preload("res://core/motion.gd")

## The most solids and the most puffs drawn: the sim's own most, and the
## shells of an end. The gas batch holds the sim's gas (FULL 300 at most),
## twelve relics' nebulae (RELICS_MOST x NEBULA_PUFFS, 576) and the worst
## end's shells (a fade's seven layers of 72, 504): 1380.
const MOST := 320
const GAS_MOST := 1400
## Every warm light: two for a body (its heat, its tail), the puffs, two for
## each relic and neighbour. Sized so the relics, filled last, are never the
## ones dropped.
const WARM_MOST := MOST * 2 + 64
## A relic's nebula: NEBULA_PUFFS soft lights in a ring NEBULA_R of the sim's
## pixels across, spreading from 1.5 to NEBULA_FAR of that and thinning over
## NEBULA_LIFE seconds of the relic's age.
const NEBULA_PUFFS := 48
const NEBULA_R := 500.0
const NEBULA_FAR := 3.5
const NEBULA_LIFE := 600.0
## The far field slides this share of what the camera and the sky's drift
## do, and repeats every FAR_WIDE of the sim's pixels.
const FAR_PARALLAX := 0.25
const FAR_WIDE := 6000.0
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
## leave, and at SWAP the sim is ended and the frame is the new star's; a
## star that lets go has no fall. A shell's puff lives LIFE seconds and gets
## FLY pixels of the design away, the outermost. From the swap the camera
## pulls back for PULL_BACK seconds until the dead star's place and the
## birthplace both fit, pans to the new star for PAN, and closes in for
## CLOSE while the new star condenses out of its gas. A first star (and a
## Start over) plays the close alone: "birth". `end_time()` adds them up.
const END := {"nova": {"fall": 1.1, "swap": 3.6, "life": 5.6, "fly": 1250.0, "veil": 0.3, "pull_back": 1.2, "pan": 3.0, "close": 4.0},
	"nebula": {"fall": 0.0, "swap": 4.2, "life": 6.5, "fly": 700.0, "veil": 0.0, "pull_back": 1.2, "pan": 3.0, "close": 4.0},
	"fade": {"fall": 0.5, "swap": 5.0, "life": 7.5, "fly": 620.0, "veil": 0.0, "pull_back": 1.2, "pan": 3.0, "close": 4.0},
	"birth": {"fall": 0.0, "swap": 0.0, "life": 0.0, "fly": 0.0, "veil": 0.0, "pull_back": 0.0, "pan": 0.0, "close": 4.0}}
## Under reduce motion there is no camera: a cut at the swap, and the new
## star fades in over REDUCED_RISE seconds; the end is over at swap + CLOSE
## (a birth at REDUCED_RISE), the shells left to come and go.
const REDUCED_RISE := 2.0
## The pull back shows the birthplace D away in this share of the sky's
## height, and never zooms out past VIEW_LEAST. It starts from the old
## star's own scale, so it may close in rather than out.
const FIT := 0.7
const VIEW_LEAST := 0.3
## A shell has this many lobes: it leaves in fingers, not as a ring. A
## nebula's has LOBES_NEBULA soft ones, a round shell more than fingers.
const LOBES := 9
const LOBES_NEBULA := 3
## Puffs of the new star's gas inside this share of its disc drift in to it
## as it condenses, from BIRTH_IN times as far.
const BIRTH_NEAR := 0.8
const BIRTH_IN := 0.5
## The new star is a dim seed this much there while the camera finds it,
## so the pan has somewhere to go.
const SEED := 0.3

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
## The camera: how far the world is slid, in this control's pixels, and how
## much it is zoomed (1 the sim's own). At rest unless an end moves it.
var shift := Vector2.ZERO
var view := 1.0

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
var _holes: Batch
var _far: ArrayMesh
var _lumps: Array[Batch] = []
## The end being played, or empty: {how, t, col, r, zoom, shells, swapped,
## remnant, birth, view0, fit}. `r` is the old star's size in pixels and
## `zoom` the sim's zoom as it began, so its shells keep their scale when
## the sim becomes the new star.
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
	_warms = Batch.new(Art.glow(2.0), WARM_MOST)
	_gas = Batch.new(Art.glow(1.6), GAS_MOST)
	_holes = Batch.new(Art.disc(), 16)
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

## A point of the sim, in this control's pixels, as the camera has it.
func world(p: Vector2) -> Vector2:
	return centre + shift + p * (sim.zoom() * view * u)

func px(p: Vector2) -> Vector2:
	return world(p)

## The star as it is drawn, in pixels.
func star_px() -> float:
	return sim.seen_r() * view * u

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

## The star's life ends as `how` ("nova", "nebula" or "fade"): `shares` is
## what it is made of (Sim.layers), each of which leaves as a shell of gas in
## its own colour, and `remnant` (Sim.Relic) what is left. Iron does not
## leave a supernova: it is the core that fell in. A nebula is only the
## star's hydrogen and helium going, a round shell in two or three soft
## lobes, the hydrogen first and furthest.
func begin_end(how: String, shares: Array, remnant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + sim.novas * 13 + sim.fades
	var shells := []
	if how == "nebula":
		_nebula_shells(rng, shares, shells)
	var last := 0 if how == "nebula" else shares.size() - (2 if how == "nova" else 1)
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
	_end = {"how": how, "t": 0.0, "col": Art.burning_col(sim), "r": star_px(), "zoom": sim.zoom(), "shells": shells, "swapped": false, "remnant": remnant}
	_puffs.clear()

func _nebula_shells(rng: RandomNumberGenerator, shares: Array, shells: Array) -> void:
	var turn := rng.randf() * TAU
	var lobes := PackedFloat32Array()
	for k in LOBES_NEBULA:
		lobes.append(rng.randf_range(0.75, 1.0))
	for i in 2:
		var share := float(shares[i])
		if share < 0.004:
			continue
		for k in int(24.0 + 48.0 * sqrt(share)):
			var lobe := rng.randi() % LOBES_NEBULA
			shells.append({"a": turn + TAU * lobe / LOBES_NEBULA + rng.randfn(0.0, 0.6), "v": (1.0 if i == 0 else 0.6) * lobes[lobe] * rng.randf_range(0.85, 1.05),
				"s": rng.randf_range(0.9, 1.4), "wait": 0.4 * i + rng.randf() * 0.3, "col": Art.MADE[i]})

## A first star, or a Start over: the close of an end alone, the star
## condensing out of the cloud the sim laid round it (`Sim.born`). Nothing
## to end and no camera to move; the owner holds the sim while it plays and
## calls `finish_end` at `end_time()`.
func begin_birth() -> void:
	_end = {"how": "birth", "t": 0.0, "col": Art.burning_col(sim), "r": star_px(), "zoom": sim.zoom(), "shells": [], "swapped": true,
		"remnant": -1, "birth": {"from": Vector2.ZERO, "d": 0.0}, "view0": 1.0, "fit": 1.0}
	shift = Vector2.ZERO
	view = 1.0
	_rise = 0.0
	_pulse = 0.0
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
	if _end.is_empty():
		return 0.0
	var at: Dictionary = END[_end.how]
	if Motion.reduce:
		return float(at.swap) + (REDUCED_RISE if _end.how == "birth" else float(at.close))
	return float(at.swap) + float(at.pull_back) + float(at.pan) + float(at.close)

## The sim has been ended: what is drawn from here on is the new star, and
## `birth` (Sim.last_birth) is where the old one was in its frame and how far.
## The camera holds the old star's place under `centre` at the scale it had
## (`view` makes up for the new star's zoom), then pulls back, pans and
## closes in; under reduce motion it cuts to the new star.
func swapped(birth: Dictionary) -> void:
	if _end.is_empty():
		return
	_end.swapped = true
	_end.birth = birth if birth.has("from") else {"from": Vector2.ZERO, "d": 0.0}
	var d := float(_end.birth.d)
	var view0 := clampf(float(_end.zoom) / sim.zoom(), VIEW_LEAST, 1.0)
	var fit := 1.0
	if d > 0.0 and size.y > 0.0:
		fit = clampf(FIT * size.y / (d * sim.zoom() * u), VIEW_LEAST, 1.0)
	_end.view0 = view0
	_end.fit = fit
	_rise = 0.0
	_pulse = 0.0
	_camera()

func finish_end() -> void:
	_end = {}
	_rise = 1.0
	shift = Vector2.ZERO
	view = 1.0

## Seconds since the swap, and the camera and the new star's rise for them.
func _since_swap() -> float:
	return float(_end.t) - float(END[_end.how].swap)

func _camera() -> void:
	if _end.is_empty() or not _end.swapped:
		return
	var at: Dictionary = END[_end.how]
	var s := _since_swap()
	var from: Vector2 = _end.birth.from
	if Motion.reduce:
		shift = Vector2.ZERO
		view = 1.0
		_rise = clampf(s / REDUCED_RISE, 0.0, 1.0)
		return
	var pb: float = at.pull_back
	var pan: float = at.pan
	var fit: float = _end.fit
	if s < pb:
		view = lerpf(float(_end.view0), fit, ease(s / pb, -1.8))
		shift = -from * (sim.zoom() * view * u)
		_rise = 0.0
	elif s < pb + pan:
		view = fit
		shift = -from * (sim.zoom() * view * u) * (1.0 - ease((s - pb) / pan, -1.8))
		_rise = 0.0
	else:
		var c := clampf((s - pb - pan) / float(at.close), 0.0, 1.0)
		view = lerpf(fit, 1.0, ease(c, -1.8))
		shift = Vector2.ZERO
		_rise = c

## How much of the way to the new star the camera has come: 1 for a birth,
## which has no way to come, and under reduce motion.
func _found() -> float:
	var at: Dictionary = END[_end.how]
	var travel := float(at.pull_back) + float(at.pan)
	return 1.0 if Motion.reduce or travel <= 0.0 else clampf(_since_swap() / travel, 0.0, 1.0)

## How far the camera has zoomed since the end began, the sim's change of
## star included: what the old star's shells are scaled by.
func _cam_k() -> float:
	return sim.zoom() * view / float(_end.zoom) if float(_end.zoom) > 0.0 else view

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
	_camera()
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
	var batches: Array[Batch] = [_warms, _gas, _holes]
	batches.append_array(_lumps)
	for batch in batches:
		batch.n = 0
	var born: bool = not _end.is_empty() and _end.swapped
	var seen := _rise if born else _old()
	# the new star's gas shows dimly as the camera finds it, and comes up
	# with the star; its nearest puffs drift in to it as it condenses
	var gas_seen := seen
	var drawn_in := 0.0
	if born:
		gas_seen = maxf(_rise, 0.5 * _found())
		drawn_in = 0.0 if Motion.reduce else BIRTH_IN * (1.0 - _rise)
	var z: float = sim.zoom() * view * u
	var col := Art.burning_col(sim)
	var rh: float = sim.haze_r()
	var roche: float = sim.roche_r()
	var frost: float = sim.frost_r()
	var reach := star_px() * REACH
	if gas_seen > 0.0:
		for b: Sim.Body in sim.bodies:
			var far := b.pos.length()
			if far < 1.0:
				continue
			var away := b.pos / far
			var at := world(b.pos)
			if b.kind == Sim.Kind.GAS:
				if drawn_in > 0.0 and far < rh * BIRTH_NEAR:
					at = world(b.pos * (1.0 + drawn_in))
				# cool far out, warm as the disc drags it in; thinner once its
				# dust has fallen out
				var wide := GAS_R * minf(GAS_WIDE, pow(b.m / Sim.PUFF, 1.0 / 3.0)) * z / Art.R
				var a := GAS_A * (1.0 if b.dust > 0.0 else 0.75) * minf(1.0, b.age * 2.0 + 0.2) * gas_seen
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
			var paint := Color(Art.paint_of(b.kind, b.ice, b.metal), seen)
			# the tide draws a body out toward the star before it has it in pieces
			var strain: float = sim.tear_r(b.m) / far if far < roche else 0.0
			if strain > 0.5 and not Motion.reduce:
				_lumps[b.id % Art.LUMPS].put_pulled(at, b.spin, s, away, 1.0 + PULLED * smoothstep(0.5, 1.0, strain), paint)
			else:
				_lumps[b.id % Art.LUMPS].put(at, b.spin, s, s, paint)
	# the dead stars and the neighbours are the sky, not the star: they stay
	# through an end (the dead star it leaves is drawn from the swap on)
	_fill_relics(z, 1.0)
	for p: Dictionary in _puffs:
		var k: float = p.t / PUFF
		var s := (30.0 + 60.0 * k) * float(p.s) * view * u / Art.R
		_warms.put(world(p.at as Vector2), 0.0, s, s, Color(1.0, 0.89, 0.75, 0.5 * (1.0 - k)))
	_fill_end()
	for batch in batches:
		batch.send()
	var origin := get_global_transform()
	var sc := origin.get_scale().x
	_body_mat.set_shader_parameter("star", origin * world(Vector2.ZERO))
	_body_mat.set_shader_parameter("reach", reach * sc)
	_body_mat.set_shader_parameter("haze", rh * z * sc)
	_body_mat.set_shader_parameter("star_col", Vector3(col.r, col.g, col.b))

## The dead stars (sim.relics) and the neighbour stars (sim.far). A relic's
## nebula is a seeded ring of soft lights in its layers' colours, spreading
## and thinning over its age, in the gas; a white dwarf and a neutron star
## are a light and a white heart (the neutron star's light pulses, still
## under reduce motion); a black hole is a dark disc (drawn on top, unlit)
## in a warm ring.
func _fill_relics(z: float, seen: float) -> void:
	for i in sim.relics.size():
		var rel: Dictionary = sim.relics[i]
		var at := world(rel.pos as Vector2)
		if not Rect2(Vector2.ZERO, size).grow(NEBULA_R * NEBULA_FAR * z).has_point(at):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + int(rel.novas) * 7 + int(rel.kind)
		var age := minf(1.0, float(rel.age) / NEBULA_LIFE)
		var spread := lerpf(1.5, NEBULA_FAR, 1.0 - pow(1.0 - age, 2.0)) * NEBULA_R * z * 0.3
		var a := lerpf(0.22, 0.06, age) * seen
		var layers: Array = rel.layers
		for k in NEBULA_PUFFS:
			# every puff draws its numbers whether it is shown or not, so a
			# layer that is spent does not move the others
			var way := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.55, 1.0)
			var wide := rng.randf_range(0.5, 1.1) * (40.0 + 60.0 * age) * view * u / Art.R
			var li := k % maxi(1, layers.size() - 1)
			if li >= layers.size() or float(layers[li]) < 0.01:
				continue
			_gas.put(at + way * spread * (1.0 + 0.6 * li / 7.0), 0.0, wide, wide, Color(Art.MADE[li], a))
		var rr: float = sim.relic_r(rel) * z
		match int(rel.kind):
			Sim.Relic.WD:
				var r := maxf(4.0 * u, rr)
				_warms.put(at, 0.0, r * 5.0 / Art.R, r * 5.0 / Art.R, Color(Art.WD, 0.35 * seen))
				_warms.put(at, 0.0, r / Art.R, r / Art.R, Color(Color.WHITE, 0.95 * seen))
			Sim.Relic.NS:
				var r := maxf(3.0 * u, rr)
				var pulse := 1.0 if Motion.reduce else 1.0 + 0.12 * sin(_clock * 2.6)
				_warms.put(at, 0.0, r * 4.0 * pulse / Art.R, r * 4.0 * pulse / Art.R, Color(Art.NS, 0.4 * seen))
				_warms.put(at, 0.0, r / Art.R, r / Art.R, Color(Color.WHITE, 0.95 * seen))
			_:
				# a warm ring round the dark disc: a wide soft light and a
				# brighter one hugging its edge, both cut by the disc
				var r := maxf(10.0 * u, rr)
				_warms.put(at, 0.0, r * 2.6 / Art.R, r * 2.6 / Art.R, Color(Art.WARM, 0.5 * seen))
				_warms.put(at, 0.0, r * 1.9 / Art.R, r * 1.9 / Art.R, Color(Art.WARM, 0.5 * seen))
				_holes.put(at, 0.0, r / Art.R, r / Art.R, Color(Art.SHADE, seen))
	for p: Vector2 in sim.far:
		var at := world(p)
		if Rect2(Vector2.ZERO, size).grow(40.0).has_point(at):
			var r := 4.0 * u
			_warms.put(at, 0.0, r * 6.0 / Art.R, r * 6.0 / Art.R, Color(Art.COOL, 0.3 * seen))
			_warms.put(at, 0.0, r / Art.R, r / Art.R, Color(Color.WHITE, 0.9 * seen))

## The shells of an end, each puff where its own speed has taken it: quick
## at first and slowing, wider and thinner as it goes. Under reduce motion
## they stand where they would be two seconds out and only come and go.
func _fill_end() -> void:
	if _end.is_empty():
		return
	var at: Dictionary = END[_end.how]
	var t: float = _end.t
	var life: float = at.life
	# the old star's place and scale: where it stood, followed by the camera
	# once the frame is the new star's
	var k := _cam_k()
	var r0: float = float(_end.r) * k
	var mid := world(_end.birth.from as Vector2) if _end.swapped else world(Vector2.ZERO)
	for p: Dictionary in _end.shells:
		var age := t - float(at.fall) - float(p.wait)
		if age <= 0.0 or age >= life:
			continue
		var lived := age / life
		var shown := 2.0 / life if Motion.reduce else lived
		# 1 - (1 - k)^3: most of the way in the first third
		var gone := 1.0 - pow(1.0 - shown, 3.0)
		var way := Vector2.from_angle(float(p.a) + (0.0 if Motion.reduce else 0.25 * lived * float(p.v)))
		var far := r0 * 0.6 + float(at.fly) * k * u * float(p.v) * gone
		var wide := (30.0 + 78.0 * gone) * float(p.s) * k * u / Art.R
		var a := minf(1.0, age / 0.35) * (1.0 - smoothstep(0.45, 1.0, lived)) * 0.36
		_gas.put(mid + way * far, 0.0, wide, wide, Color(p.col as Color, a))

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
		return Vector2(lerpf(0.3, 1.0, ease(_rise, 0.4)), maxf(_rise, SEED * minf(1.0, 2.0 * _found())))
	var at: Dictionary = END[_end.how]
	var t: float = _end.t
	if _end.how == "nova":
		var fall := clampf(t / float(at.fall), 0.0, 1.0)
		var after := clampf((t - float(at.fall)) / 0.5, 0.0, 1.0)
		return Vector2(lerpf(1.0, 0.7, fall * fall) * (1.0 + 0.5 * after), 1.0 - after)
	var thin := clampf(t / (float(at.swap) * 0.7), 0.0, 1.0)
	return Vector2(1.0 + 0.35 * thin, 1.0 - thin * thin)

## The far field under everything, then the star's light, lying on the dust
## round it.
func _draw_light() -> void:
	if sim == null:
		return
	_draw_far()
	# a star with nothing to burn lights half as far, and dully
	var now := _star_now()
	var col := Art.burning_col(sim)
	var r := star_px() * REACH * _breath() * (1.0 + _pulse * 0.1 + _bloom * 0.3) * lerpf(0.45, 1.0, sim.lit)
	_light_l.draw_mesh(Art.glow(3.2), null, Transform2D(0.0, Vector2(r, r) / Art.R, 0.0, world(Vector2.ZERO)), Color(col, lerpf(0.3, 0.5, sim.lit) * now.y))

## The stars far behind everything: one mesh, as wide as the field at the
## smallest it is drawn, sliding FAR_PARALLAX of the camera's shift and of
## the sky's drift. The drift is wrapped about 0 by FAR_WIDE, so the field
## never runs out.
func _draw_far() -> void:
	if _far == null:
		_far = Art.far_field(77, FAR_WIDE)
	var s: float = u * maxf(0.6, sim.zoom() * view)
	var half := Vector2(FAR_WIDE, FAR_WIDE) * 0.5
	var slid: Vector2 = ((sim.drift as Vector2) + half).posmod(FAR_WIDE) - half
	_light_l.draw_mesh(_far, null, Transform2D(0.0, Vector2(s, s), 0.0, centre + shift * FAR_PARALLAX - slid * FAR_PARALLAX * s))

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
	var star := world(Vector2.ZERO)
	_warm_l.draw_mesh(Art.glow(2.0), null, Transform2D(0.0, Vector2(sr, sr) * 2.1 / Art.R, 0.0, star), Color(col, (0.34 + 0.2 * _bloom) * lerpf(0.4, 1.0, sim.lit) * now.y))
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
		_warm_l.draw_mesh(Art.glow(1.6), null, Transform2D(0.0, Vector2(wide, wide) / Art.R, 0.0, star), Color(Art.VEIL, 0.85 * burst))
	if since > 0.0:
		var left := 14.0 * view * u * (1.0 + 0.15 * sin(t * 9.0) * (0.0 if Motion.reduce else 1.0))
		_warm_l.draw_mesh(Art.glow(1.2), null, Transform2D(0.0, Vector2(left, left) / Art.R, 0.0, star), Color(1.0, 1.0, 1.0, minf(1.0, since * 2.0)))

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
	_star_l.draw_mesh(Art.star_quad(), null, Transform2D(0.0, Vector2(sr, sr), 0.0, world(Vector2.ZERO)))

## Over everything: a black hole's dark disc (here and not with the bodies,
## whose shader would light it; over its warm ring, which it leaves a ring),
## a breath of light as a supernova's layers leave, and the corners.
func _draw_top() -> void:
	if sim == null:
		return
	_holes.show(_top_l)
	if not _end.is_empty() and not _end.swapped:
		var at: Dictionary = END[_end.how]
		var since := float(_end.t) - float(at.fall)
		if since > 0.0 and float(at.veil) > 0.0:
			_top_l.draw_rect(Rect2(Vector2.ZERO, size), Color(Art.VEIL, float(at.veil) * exp(-since * 2.2)))
	if _corners != null:
		_top_l.draw_mesh(_corners, null)
