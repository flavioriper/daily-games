extends Control

## Nightlight's tutorial pages: the game's own sky (arcade/nightlight_sky.gd)
## over a sim of its own with nothing crossing it, so a page is the game and
## cannot drift from it. THROW taps three meteors onto their circles, one
## after another, and watches them wind in, on a loop. LIGHT sets two in the
## haze, a nearer and a farther, and both wind in. FUEL is a star
## out of hydrogen, dim, and a comet that winds in and lights it again. NOVA
## is the sky a supernova leaves: a small star among its ashes. Only FUEL's
## star burns anything, so no other page's goes dim while it is read.
##
## Under reduce motion a page stands still a few seconds in.

const Sim = preload("res://arcade/nightlight_sim.gd")
const NightSky = preload("res://arcade/nightlight_sky.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

enum Lesson { THROW, LIGHT, NOVA, FUEL }

## Seconds of each page's loop, by Lesson (NOVA has none): as long as its
## bodies take to reach the star, and a moment more. How far in a page
## stands under reduce motion.
const LOOP := [22.0, 14.0, 0.0, 12.0]
const STILL := 6.0
## THROW's taps: the second each comes, the way from the star, and how far
## as a share of the haze's radius. LIGHT's two circles and FUEL's comet, as
## shares of the same.
const TAPS := [[0.8, -2.9, 0.7], [1.9, -0.8, 0.62], [3.0, 1.4, 0.66]]
const RINGS := [0.6, 0.5]
const COMET := 0.5
## The design's pixels the page is tall: the haze with room round it, and
## for NOVA most of the ashes' paths.
const TALL := 760.0
const TALL_NOVA := 1150.0

var lesson := Lesson.THROW

var _sim: RefCounted
var _sky: Control
var _t := 0.0
var _thrown := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sim = Sim.new(21 + lesson)
	_sim.passing = false
	_sim.burning = lesson == Lesson.FUEL
	if lesson == Lesson.FUEL:
		_sim.fuel = 0.0
		_sim.awake = false
		_sim.lit = 0.0
	if lesson == Lesson.NOVA:
		_sim.mass = Sim.NOVA
		_sim.nova()
	_sky = NightSky.new()
	_sky.sim = _sim
	_sky.paper = Pal.PAPER
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sky)
	resized.connect(_fit)
	_fit()
	if Motion.reduce:
		for i in int(STILL / Sim.STEP):
			_step(Sim.STEP)
		set_process(false)

func _fit() -> void:
	_sky.u = size.y / (TALL_NOVA if lesson == Lesson.NOVA else TALL)
	_sky.centre = size * 0.5
	# a page standing still (reduce motion) is drawn here and nowhere else
	_sky.refresh(0.0)

func _process(delta: float) -> void:
	_step(delta)

func _step(delta: float) -> void:
	_t += delta
	if lesson != Lesson.NOVA and _t >= float(LOOP[lesson]):
		_t = 0.0
		_thrown = 0
		_sim.bodies.clear()
		if lesson == Lesson.FUEL:
			_sim.fuel = 0.0
	match lesson:
		Lesson.THROW:
			while _thrown < TAPS.size() and _t >= float(TAPS[_thrown][0]):
				_tap(Vector2.from_angle(float(TAPS[_thrown][1])) * (_sim.haze_r() * float(TAPS[_thrown][2])))
				_thrown += 1
		Lesson.LIGHT:
			if _thrown == 0 and _t >= 0.5:
				_thrown = 1
				_tap(Vector2(_sim.haze_r() * float(RINGS[0]), 0.0))
				_tap(Vector2(-_sim.haze_r() * float(RINGS[1]), 0.0))
		Lesson.FUEL:
			if _thrown == 0 and _t >= 0.8:
				_thrown = 1
				var at := Vector2(-_sim.haze_r() * COMET, 0.0)
				_sim.add(Sim.Kind.COMET, 3.0, at, _sim.circle_vel(at))
	_sim.advance(delta)
	for e: Dictionary in _sim.events:
		if e.kind == "eat":
			_sky.ate(float(e.m))
		elif e.kind == "merge":
			_sky.met(e.at)
		elif e.kind == "tear":
			_sky.tore(e.at, float(e.m))
	_sim.events.clear()
	# a page's star stays the small one it began as
	if lesson != Lesson.NOVA:
		_sim.mass = Sim.START
	_sky.refresh(delta)

## A meteor set going at `at`, as the game's own press does it.
func _tap(at: Vector2) -> void:
	_sim.add(Sim.Kind.METEOR, 1.0, at, _sim.throw_vel(at))
	_sky.set_down(at)
