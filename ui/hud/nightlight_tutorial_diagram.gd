extends Control

## Nightlight's tutorial pages: the game's own sky (arcade/nightlight_sky.gd)
## over a sim of its own with nothing crossing it, so a page is the game and
## cannot drift from it. GAS pours gas in at the disc's rim, as the button
## does, and it winds in. WORLDS is the same disc with what the gas has made
## already in it: grains, a rock, a comet with its tail inside the frost
## line, a planet, a giant. BURN is the star alone, close, through a life:
## a Sun, heavier and whiter, heavier and blue, then swollen and red. END is
## a heavy star's layers leaving and the small star they leave. No page's
## star burns or grows by itself, so none changes while it is read.
##
## A page opens some way in (the gas takes a minute to reach the star), and
## under reduce motion it stands still there.

const Sim = preload("res://arcade/nightlight_sim.gd")
const NightSky = preload("res://arcade/nightlight_sky.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

enum Lesson { GAS, WORLDS, BURN, END }

## Seconds between a page's puffs, and how long it has run as it opens.
const POUR := 0.5
const WARM := 30.0
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
## The design's pixels each page is tall, by Lesson.
const TALL := [1060.0, 1060.0, 520.0, 1200.0]
## No body on a page is drawn smaller than this, in the design's pixels.
const SMALL := 11.0

var lesson := Lesson.GAS

var _sim: RefCounted
var _sky: Control
var _t := 0.0
var _since := 0.0
var _swapped := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sim = Sim.new(21 + lesson)
	_sim.passing = false
	_sim.burning = false
	_sky = NightSky.new()
	_sky.sim = _sim
	_sky.paper = Pal.PAPER
	_sky.small = SMALL
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sky)
	resized.connect(_fit)
	_set_up()
	if lesson == Lesson.GAS or lesson == Lesson.WORLDS:
		for i in int(WARM / Sim.STEP):
			_feed(Sim.STEP)
	elif lesson == Lesson.END and Motion.reduce:
		for i in int((END_AT + END_STILL) * 30.0):
			_step(1.0 / 30.0)
	_fit()
	if Motion.reduce:
		set_process(false)

## The page's sim as it starts, and as it starts again.
func _set_up() -> void:
	_sim.bodies.clear()
	_sim.events.clear()
	match lesson:
		Lesson.WORLDS:
			for row: Array in BODIES:
				var at: Vector2 = Vector2.from_angle(float(row[3])) * (_sim.haze_r() * float(row[2]))
				var b: Sim.Body = _sim.add(row[0], row[1], at, _sim.circle_vel(at))
				b.ice = row[4]
				b.h = 0.6 if row[0] == Sim.Kind.GIANT else b.ice * Sim.ICE_H
				_sim._sort(b)
		Lesson.END:
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
		Lesson.GAS, Lesson.WORLDS:
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
					_sky.begin_end("nova", _sim.layers())
				elif _swapped and _t >= END_REST:
					_swapped = false
					_t = 0.0
					_set_up()
				return
			_sky.step_end(delta)
			if not _swapped and _sky.end_t() >= _sky.end_swap():
				_swapped = true
				_sim.end()
				_sky.swapped()
			elif _swapped:
				_sim.advance(delta)
				_sim.mass = Sim.START
				if _sky.end_t() >= _sky.end_time():
					_sky.finish_end()
					_t = 0.0

## Gas as the button pours it, the sim stepped, and the star kept the small
## one it began as.
func _feed(delta: float) -> void:
	_since += delta
	if _since >= POUR:
		_since = 0.0
		_sim.pour()
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
