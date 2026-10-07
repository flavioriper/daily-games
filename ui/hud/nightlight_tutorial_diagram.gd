extends Control

## Nightlight's tutorial pages: the game's own sky (arcade/nightlight_sky.gd)
## over a sim of its own with nothing crossing it, so a page is the game and
## cannot drift from it. GAS is a ring of gas just outside the disc's rim, as
## a star is born with, pressed twice where a finger would press it: what
## was under the press slows, drops into the disc and winds in. WORLDS is
## the disc with gas in it and what the gas has made: grains, a rock, a
## comet with its tail inside the frost line, a planet, a giant. BURN is the star alone, close, through a life:
## a Sun, heavier and whiter, heavier and blue, then swollen and red. END is
## a heavy star's layers leaving, the camera finding the small star born
## away from the neutron star it leaves, and that star condensing. No page's
## star burns or grows by itself, so none changes while it is read.
##
## GAS opens on the press and starts again once the gas it sent has been
## eaten; under reduce motion it stands still with that gas half way in.
## WORLDS opens some way in, and under reduce motion stands still there.
## No page has a ring of the game's own (`ring` is none): it keeps the star
## as big as it was drawn before there was one, the frost line near the
## star, and nothing drifts in.

const Sim = preload("res://arcade/nightlight_sim.gd")
const NightSky = preload("res://arcade/nightlight_sky.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

enum Lesson { GAS, WORLDS, BURN, END }

## How long WORLDS has run as it opens.
const WARM := 30.0
## A page's gas: PUFFS puffs of PUFF_M each. GAS lays them as a ring, on
## circles from the first to the second of GAS_RING in the disc's radii,
## the same ring every time (GAS_SEED: one whose braked gas is eaten inside
## the loop); WORLDS lays them inside the disc (IN_DISC) and makes them up
## to PUFFS again every TOP_UP seconds.
const PUFFS := 28
const PUFF_M := 0.05
const GAS_RING := [1.02, 1.25]
const GAS_SEED := 7
const IN_DISC := [0.7, 0.97]
const TOP_UP := 4.0
## GAS's finger: where it presses (the way from the star, up and to the
## right, and how far in the disc's radii), how wide in the disc's radii,
## and when in the loop. The loop is GAS_LOOP seconds, and under reduce
## motion the page stands GAS_STILL seconds into it.
const GAS_WAY := -PI * 0.25
const GAS_FAR := 1.13
const GAS_PRESS := 0.45
const GAS_AT := [0.8, 1.6]
const GAS_LOOP := 30.0
const GAS_STILL := 19.0
## WORLDS' bodies: the Kind, the mass, how far as a share of the disc's
## radius, the way from the star, and how much of it is ice.
const BODIES := [[Sim.Kind.GRAIN, 0.0008, 0.62, 0.4, 0.0], [Sim.Kind.GRAIN, 0.001, 0.8, 2.2, 0.7], [Sim.Kind.ROCK, 0.004, 0.57, 3.6, 0.0],
	[Sim.Kind.COMET, 0.002, 0.64, 5.1, 0.8], [Sim.Kind.PLANET, 0.01, 0.74, 1.3, 0.2], [Sim.Kind.GIANT, 0.03, 0.9, 4.3, 0.0]]
## BURN's star, a step every LIFE_STEP seconds: its Suns and how much of a
## giant it is.
const LIFE := [[1.0, 0.0], [4.0, 0.0], [20.0, 0.0], [20.0, 1.0]]
const LIFE_STEP := 4.0
## END's star, when its layers leave, and how long the page waits on the
## new star before it starts again; where it stands under reduce motion.
const END_SUNS := 9.0
const END_AT := 1.5
const END_REST := 3.0
const END_STILL := 3.0
## The design's pixels each page is tall, by Lesson. GAS's is tall enough
## for its ring, 1,125 across with the puffs' own width past that.
## BURN's is tall enough for its last step, a 20-Sun giant 550 across.
const TALL := [1300.0, 1060.0, 660.0, 1200.0]
## No body on a page is drawn smaller than this, in the design's pixels.
const SMALL := 11.0

var lesson := Lesson.GAS

var _sim: RefCounted
var _sky: Control
var _t := 0.0
var _since := 0.0
var _warming := false
var _swapped := false
## END's neighbour stars as the page opened: every end moves them, and the
## page puts them back with its star.
var _far0: Array[Vector2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sim = Sim.new(21 + lesson)
	_sim.passing = false
	_sim.burning = false
	_far0 = _sim.far.duplicate()
	_sky = NightSky.new()
	_sky.sim = _sim
	_sky.paper = Pal.PAPER
	_sky.small = SMALL
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sky)
	resized.connect(_fit)
	_set_up()
	_warming = true
	if lesson == Lesson.WORLDS:
		for i in int(WARM / Sim.STEP):
			_step(Sim.STEP)
	elif lesson == Lesson.GAS and Motion.reduce:
		for i in int(GAS_STILL / Sim.STEP):
			_step(Sim.STEP)
	elif lesson == Lesson.END and Motion.reduce:
		for i in int((END_AT + END_STILL) * 30.0):
			_step(1.0 / 30.0)
	_warming = false
	_fit()
	if Motion.reduce:
		set_process(false)

## The page's sim as it starts, and as it starts again.
func _set_up() -> void:
	_sim.bodies.clear()
	_sim.events.clear()
	_sim.ring = Vector2.ZERO
	_sim.frost = 0.0
	match lesson:
		Lesson.GAS:
			var rng := RandomNumberGenerator.new()
			rng.seed = GAS_SEED
			for i in PUFFS:
				_lay(rng, TAU * (i + rng.randf()) / PUFFS, GAS_RING, 0.0)
		Lesson.WORLDS:
			for i in PUFFS:
				_lay(_sim._rng, _sim._rng.randf() * TAU, IN_DISC, Sim.FIRST_DUST)
			for row: Array in BODIES:
				var at: Vector2 = Vector2.from_angle(float(row[3])) * (_sim.haze_r() * float(row[2]))
				var b: Sim.Body = _sim.add(row[0], row[1], at, _sim.circle_vel(at))
				b.ice = row[4]
				b.h = 0.6 if row[0] == Sim.Kind.GIANT else b.ice * Sim.ICE_H
				_sim._sort(b)
		Lesson.END:
			# the dead star the last pass left, and the sky it carried, are put back
			_sim.relics.clear()
			_sim.far.assign(_far0)
			_sim.drift = Vector2.ZERO
			_sim.mass = Sim.START * END_SUNS
			_sim.fuel = _sim.mass * 0.6
			_sim.env = _sim.mass * 0.2
			_sim.made.assign([0.02 * _sim.mass, 0.03 * _sim.mass, 0.01 * _sim.mass, 0.01 * _sim.mass, 0.02 * _sim.mass, Sim.IRON * Sim.START])
			_sim.ignited.assign([true, true, true, true, true, true])
			_sim.swell = 1.0

func _fit() -> void:
	_sky.u = size.y / float(TALL[lesson])
	_sky.centre = size * 0.5
	# a page standing still (reduce motion) is drawn here and nowhere else
	_sky.refresh(0.0)

func _process(delta: float) -> void:
	_step(delta)
	_sky.refresh(delta)

func _step(delta: float) -> void:
	_t += delta
	match lesson:
		Lesson.GAS:
			_press(delta)
			_feed(delta)
		Lesson.WORLDS:
			_top_up(delta)
			_feed(delta)
		Lesson.BURN:
			var at := fposmod(_t / LIFE_STEP, float(LIFE.size()))
			var from: Array = LIFE[int(at)]
			var to: Array = LIFE[(int(at) + 1) % LIFE.size()]
			var k := smoothstep(0.45, 1.0, at - floorf(at))
			_sim.mass = Sim.START * exp(lerpf(log(float(from[0])), log(float(to[0])), k))
			_sim.swell = lerpf(from[1], to[1], k)
		Lesson.END:
			if not _sky.ending():
				if not _swapped and _t >= END_AT:
					_sky.begin_end("nova", _sim.layers(), _sim.remnant())
				elif _swapped and _t >= END_REST:
					_swapped = false
					_t = 0.0
					_set_up()
				return
			_sky.step_end(delta)
			if not _swapped and _sky.end_t() >= _sky.end_swap():
				_swapped = true
				_sim.end()
				_sky.swapped(_sim.last_birth)
			elif _swapped:
				_sim.advance(delta)
				_sim.mass = Sim.START
				if _sky.end_t() >= _sky.end_time():
					_sky.finish_end()
					_t = 0.0

## One of a page's puffs, cooled, on a circle `turn` round the star between
## the two of `band`, in the disc's radii, with `dust` of it dust.
func _lay(rng: RandomNumberGenerator, turn: float, band: Array, dust: float) -> Sim.Body:
	var pos: Vector2 = Vector2.from_angle(turn) * _sim.haze_r() * rng.randf_range(band[0], band[1])
	var b: Sim.Body = _sim.add(Sim.Kind.GAS, PUFF_M, pos, _sim.circle_vel(pos))
	b.h = _sim.puff_h()
	b.dust = dust
	b.age = Sim.COOL
	return b

## GAS's finger: it comes down twice on the ring, on the same place, and the
## sky shows it as it shows the player's. The ring is laid again as the
## loop ends.
func _press(delta: float) -> void:
	var before := _since
	_since += delta
	var r: float = _sim.haze_r() * GAS_PRESS
	var spot: Vector2 = Vector2.from_angle(GAS_WAY) * _sim.haze_r() * GAS_FAR
	for at: float in GAS_AT:
		if before < at and _since >= at:
			_sim.brake(spot, r)
			if not _warming:
				_sky.set_down(spot, r)
	if _since >= GAS_LOOP:
		_since = 0.0
		_set_up()

## WORLDS' gas, made up to what it began with as the star eats it and the
## solids sweep it up. A new puff comes up out of nothing, as gas that
## drifts in does.
func _top_up(delta: float) -> void:
	_since += delta
	if _since < TOP_UP:
		return
	_since = 0.0
	for i in PUFFS - _sim.gas_count():
		_lay(_sim._rng, _sim._rng.randf() * TAU, IN_DISC, Sim.FIRST_DUST).age = 0.0

## The sim stepped, the sky told what happened in it, and the star kept the
## small one it began as.
func _feed(delta: float) -> void:
	_sim.advance(delta)
	for e: Dictionary in _sim.events:
		if e.kind == "form":
			_sky.formed(e.at)
		elif e.kind == "merge":
			_sky.met(e.at)
		elif e.kind == "tear":
			_sky.tore(e.at, float(e.m))
	_sim.events.clear()
	_sim.mass = Sim.START
	_sim.fuel = Sim.START * Sim.STAR_H
	_sim.env = Sim.START * Sim.STAR_HE
