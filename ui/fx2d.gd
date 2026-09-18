extends Node2D

## The flat board's particle effects, fired at a point in its parent's pixels:
## a burst of small stars when a tile is set (puff) and a gentler rise of
## stars for a hint (sparkle). This is world/fx.gd for a 2D board: one-shot
## CPUParticles2D pooled and picked round-robin, so taps in quick succession
## never steal each other's burst, and cue() records an audio name until
## sounds exist. The board adds it as a child of its grid Control, so a
## position handed in is a position in that Control's local pixels; the
## design space is 1080 px wide and a tile about 147 px, which is what the
## sizes below are measured against. Nothing here is an instance shader
## parameter (see CLAUDE.md): CPUParticles2D tints through its own `color`.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 9.5.

const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Fx = preload("res://world/fx.gd")

const PUFF_POOL := 4
const SPARKLE_POOL := 3
## Fx.star_texture() is a 32 px white four-point star; a particle's scale
## multiplies that, so 0.44 to 0.52 draws a star 14 to 17 px across. That is
## the top of the 12 to 16 px asked for, because the star's four tips are
## needle-thin and its solid body is only about seven tenths of the box:
## measured on a rendered frame, the body of a 14 px star covers 10 to 12 px.
## On a 147 px tile that is a tenth of the tile: visible as a star, and
## small enough that six of them read as a burst rather than a cloud.
const STAR_SCALE_MIN := 0.44
const STAR_SCALE_MAX := 0.52

var puffs: Array[CPUParticles2D] = []
var sparkles: Array[CPUParticles2D] = []
## The most recent audio cue name. A later audio layer plays these.
var last_cue := ""
var _next_puff := 0
var _next_sparkle := 0

## Build the two pools and name the node.
func _ready() -> void:
	name = "Fx2D"
	for i in PUFF_POOL:
		# A burst: fast out of the point in a 120 degree fan around straight
		# up, then a light pull downward so the stars arc and hang at the top
		# of their rise while they shrink away. 480 px/s^2 against 170 to 290
		# px/s puts that peak right about where the half-second ends, and the
		# whole burst stays within about a tile and a quarter of its point.
		var p := _emitter("Puff_%d" % i, 6, 0.5, 60.0, 170.0, 290.0, Vector2(0.0, 480.0))
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 6.0
		add_child(p)
		puffs.append(p)
	for i in SPARKLE_POOL:
		# A hint's sparkle: stars drift up out of a small disc, slowly and
		# nearly straight, and a slight upward gravity keeps them rising
		# rather than stalling, so they read as floating off, not falling.
		var s := _emitter("Sparkle_%d" % i, 6, 0.7, 25.0, 60.0, 120.0, Vector2(0.0, -90.0))
		s.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		s.emission_sphere_radius = 18.0
		add_child(s)
		sparkles.append(s)

## Five to seven small stars burst from `at` in `colour`, mostly upward,
## drift, and shrink and fade to nothing over about half a second.
func puff(at: Vector2, colour: Color, count := 5) -> void:
	if Motion.reduce:
		return
	if puffs.is_empty():
		return
	_fire(puffs[_next_puff], at, colour, clampi(count, 1, 12))
	_next_puff = (_next_puff + 1) % PUFF_POOL

## A few stars rise gently from `at` and fade over about 0.7 s.
func sparkle(at: Vector2, colour: Color = Pal.SUN) -> void:
	if Motion.reduce:
		return
	if sparkles.is_empty():
		return
	_fire(sparkles[_next_sparkle], at, colour, 6)
	_next_sparkle = (_next_sparkle + 1) % SPARKLE_POOL

## Audio hook. Effects name their sound here; nothing plays yet.
func cue(cue_name: String) -> void:
	last_cue = cue_name

func _fire(p: CPUParticles2D, at: Vector2, colour: Color, count: int) -> void:
	p.position = at
	p.color = colour
	if p.amount != count:
		p.amount = count
	p.restart()

## Build a one-shot emitter that bursts all at once and never pops out:
## every star holds most of its size through the first half of its life and
## then shrinks to nothing, and its alpha fades over the last two fifths, so
## it is a star for as long as it can be seen and invisible on its last
## frame; a curve straight from one to zero had the burst read as dust by
## its midpoint (measured at 0.35 s of a 0.5 s life, it was gone). The
## node's `color` multiplies a white ramp, so the colour asked for is the
## colour drawn. Stars spawn at a random quarter turn and spin a little,
## which keeps a burst from reading as six copies of one sprite.
## nm: emitter name; amount: particle count; life: lifetime in seconds;
## spread: half-angle of the fan in degrees; v0/v1: initial speed in px/s;
## gravity: px/s^2, positive y is down.
static func _emitter(nm: String, amount: int, life: float, spread: float, v0: float, v1: float, gravity: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = nm
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = gravity
	p.angle_min = 0.0
	p.angle_max = 90.0
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.texture = Fx.star_texture()
	p.scale_amount_min = STAR_SCALE_MIN
	p.scale_amount_max = STAR_SCALE_MAX
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.5, 0.9))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.6, Color(1.0, 1.0, 1.0, 1.0))
	p.color_ramp = fade
	return p
