extends Control

## Nightlight's tutorial pages: the game's own sky (arcade/nightlight_sky.gd)
## over a sim of its own with nothing crossing it, so a page is the game and
## cannot drift from it. THROW aims a meteor across the star with the dotted
## line, lets it go and watches it wind in, on a loop. LIGHT lets one fall
## straight and sets one on a circle in the haze, side by side. FUEL is a star
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
## bodies take to reach the star, and a moment more. How long THROW aims
## before it lets go, and how far in a page stands under reduce motion.
const LOOP := [22.0, 14.0, 0.0, 12.0]
const AIM := 1.6
const STILL := 6.0
## THROW's meteor: where it waits, and its speed as a share of a circle's
## there. Slow enough that its path dips deep into the haze, and not so slow
## that it meets the star the first time round. LIGHT's circle and FUEL's
## comet, as shares of the haze's radius.
const FROM := Vector2(-270.0, 60.0)
const SLOW := 0.78
const RING := 0.6
const COMET := 0.5
## The design's pixels the page is tall: the haze with room round it, and
## for NOVA most of the ashes' paths.
const TALL := 760.0
const TALL_NOVA := 1150.0

var lesson := Lesson.THROW

var _sim: RefCounted
var _sky: Control
var _t := 0.0
var _thrown := false

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
		_t = AIM
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
		_thrown = false
		_sim.bodies.clear()
		if lesson == Lesson.FUEL:
			_sim.fuel = 0.0
	_sky.aim = {}
	var vel := FROM.orthogonal().normalized() * -sqrt(_sim.gm() / FROM.length()) * SLOW
	match lesson:
		Lesson.THROW:
			if _t < AIM:
				# the drag grows out of the waiting meteor, the dots with it
				var k := clampf(_t / (AIM * 0.7), 0.0, 1.0)
				var where: Dictionary = _sim.predict(FROM, vel * k)
				var from: Vector2 = _sky.px(FROM)
				_sky.aim = {"from": from, "to": from + vel.normalized() * 150.0 * _sky.u * k, "pts": where.pts, "hit": where.hit}
			elif not _thrown:
				_thrown = true
				_sim.add(Sim.Kind.METEOR, 1.0, FROM, vel)
		Lesson.LIGHT:
			if not _thrown and _t >= 0.5:
				_thrown = true
				var r: float = _sim.haze_r() * RING
				_sim.add(Sim.Kind.METEOR, 1.0, Vector2(-330.0, -150.0), Vector2.ZERO)
				_sim.add(Sim.Kind.METEOR, 1.0, Vector2(r, 0.0), Vector2(0.0, sqrt(_sim.gm() / r)))
		Lesson.FUEL:
			if not _thrown and _t >= 0.8:
				_thrown = true
				var r: float = _sim.haze_r() * COMET
				_sim.add(Sim.Kind.COMET, 3.0, Vector2(-r, 0.0), Vector2(0.0, -sqrt(_sim.gm() / r)))
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
