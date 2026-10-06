extends Control

## Nightlight's tutorial pages: the game's own sky (arcade/nightlight_sky.gd)
## over a sim of its own with nothing crossing it, so a page is the game and
## cannot drift from it. THROW aims a meteor across the star with the dotted
## line, lets it go and watches it wind in, on a loop. LIGHT lets one fall
## straight and sets one on a circle in the haze, side by side. NOVA is the
## sky a supernova leaves: a small star among its ashes.
##
## Under reduce motion a page stands still a few seconds in.

const Sim = preload("res://arcade/nightlight_sim.gd")
const NightSky = preload("res://arcade/nightlight_sky.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

enum Lesson { THROW, LIGHT, NOVA }

## Seconds of a page's loop, and how long THROW aims before it lets go.
const LOOP := 9.0
const AIM := 1.6
## THROW's meteor: where it waits, and its speed as a share of a circle's
## there. Slow enough that its path dips deep into the haze.
const FROM := Vector2(-330.0, 70.0)
const SLOW := 0.62
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
		for i in int(3.0 / Sim.STEP):
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
	if _t >= LOOP and lesson != Lesson.NOVA:
		_t = 0.0
		_thrown = false
		_sim.bodies.clear()
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
				var r: float = _sim.haze_r() * 0.8
				_sim.add(Sim.Kind.METEOR, 1.0, Vector2(-330.0, -150.0), Vector2.ZERO)
				_sim.add(Sim.Kind.METEOR, 1.0, Vector2(r, 0.0), Vector2(0.0, sqrt(_sim.gm() / r)))
	_sim.advance(delta)
	for e: Dictionary in _sim.events:
		if e.kind == "eat":
			_sky.ate(float(e.m))
		elif e.kind == "merge":
			_sky.met(e.at)
	_sim.events.clear()
	# a page's star stays the small one it began as
	if lesson != Lesson.NOVA:
		_sim.mass = Sim.START
	_sky.refresh(delta)
