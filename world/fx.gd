extends Node3D

## Particle effects a board fires at a point: one-shot bursts (a dust puff
## when a prism lands, a sparkle for a hint) and continuous jets (water that
## keeps falling until told to stop). Emitters are pooled and picked
## round-robin, so taps in quick succession never steal each other's puff.
## Board-local: the board adds this as its own child. cue() is the audio
## hook; it only records the name until sounds exist. Spec:
## docs/superpowers/specs/2026-09-13-binairo-polish-design.md, section 3.

const Motion = preload("res://core/motion.gd")
const Ambient = preload("res://world/ambient.gd")
const Pal = preload("res://core/palette.gd")

const PUFF_POOL := 4
const SPARKLE_POOL := 2
## Water that keeps pouring, unlike the one-shot puffs: two permanent
## emitters (a source and a drain) plus four transient ones (leaking mouths).
const JET_POOL := 6
const STAR_SIZE := 32

var puffs: Array[CPUParticles3D] = []
var sparkles: Array[CPUParticles3D] = []
var jets: Array[CPUParticles3D] = []
## The most recent audio cue name. A later audio layer plays these.
var last_cue := ""
var _next_puff := 0
var _next_sparkle := 0
static var _star: ImageTexture
static var _droplet: ImageTexture

## Build the three emitter pools (puffs, sparkles and the continuous jets)
## and name the node.
func _ready() -> void:
	name = "Fx"
	for i in PUFF_POOL:
		var p := _emitter("Puff_%d" % i, 8, 0.4, 60.0, 0.5, 0.9, Vector3(0.0, -1.5, 0.0), 0.05)
		p.mesh = Ambient.speck_mesh()
		add_child(p)
		puffs.append(p)
	for i in SPARKLE_POOL:
		var s := _emitter("Sparkle_%d" % i, 10, 0.6, 40.0, 0.3, 0.6, Vector3.ZERO, 0.04)
		s.mesh = Ambient.speck_mesh(star_texture())
		add_child(s)
		sparkles.append(s)
	for i in JET_POOL:
		# _emitter builds a one-shot burst; a jet is the same emitter left
		# running, aimed down, so it reads as water falling rather than dust.
		# Task 4 fix round 2 tried fixing invisibility with size alone (up to
		# 0.6) on the plain untextured quad _emitter gives every pool -- that
		# just becomes a big flat square, since an untextured quad has no
		# soft edge at any size. Round 3 fixes it properly: droplet_texture()
		# gives the quad a soft round falloff so it reads as a drop rather
		# than a block of colour, size comes back down under a cell (0.16,
		# against a 0.15 pipe radius), amount goes up for density, and spread
		# widens from a narrow dribble so the drops scatter outward instead
		# of stacking into one column. The spawn point itself was also moved
		# clear of the pipe's own geometry (puzzles/pipes_iso.gd's JET_OUT/
		# JET_LIFT), which is what actually let a small droplet be seen at
		# the steep board camera in the first place.
		var j := _emitter("Jet_%d" % i, 40, 0.45, 55.0, 0.5, 1.0, Vector3(0.0, -4.0, 0.0), 0.16)
		j.one_shot = false
		j.explosiveness = 0.0
		j.direction = Vector3.DOWN
		j.mesh = Ambient.speck_mesh(droplet_texture())
		add_child(j)
		jets.append(j)

## Stone dust rising from `at` and shrinking away.
func puff(at: Vector3, colour: Color = Pal.STONE) -> void:
	if Motion.reduce:
		return
	if puffs.is_empty():
		return
	_fire(puffs[_next_puff], at, colour)
	_next_puff = (_next_puff + 1) % PUFF_POOL

## Small stars floating up from `at`.
func sparkle(at: Vector3, colour: Color = Pal.SUN) -> void:
	if Motion.reduce:
		return
	if sparkles.is_empty():
		return
	_fire(sparkles[_next_sparkle], at, colour)
	_next_sparkle = (_next_sparkle + 1) % SPARKLE_POOL

## Water falling from `at` until stop_jet releases it. Returns a handle into
## the pool, or -1 when reduce-motion is on or every emitter is already busy;
## a caller that gets -1 simply shows no jet, which is why the tints carry the
## state on their own.
func jet(at: Vector3, colour: Color = Pal.WATER_HI) -> int:
	if Motion.reduce:
		return -1
	for i in jets.size():
		if not jets[i].emitting:
			jets[i].position = at
			jets[i].color = colour
			jets[i].emitting = true
			return i
	return -1

## Releases the emitter `handle` took. Safe with -1 and with a stale handle.
func stop_jet(handle: int) -> void:
	if handle >= 0 and handle < jets.size():
		jets[handle].emitting = false

## Audio hook. Effects name their sound here; nothing plays yet.
func cue(cue_name: String) -> void:
	last_cue = cue_name

func _fire(p: CPUParticles3D, at: Vector3, colour: Color) -> void:
	p.position = at
	p.color = colour
	p.restart()

## Build a one-shot emitter with the given parameters.
## nm: emitter name; amount: particle count; life: lifetime in seconds;
## spread: cone spread in degrees; v0/v1: min and max initial velocity;
## gravity: gravity vector; size: particle size in world units.
## Every emitter bursts all at once, shrinks its particles to nothing over
## their lifetime, and casts no shadow.
static func _emitter(nm: String, amount: int, life: float, spread: float, v0: float, v1: float, gravity: Vector3, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nm
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = gravity
	p.scale_amount_min = size
	p.scale_amount_max = size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## A four-point star drawn in code: alpha 1 inside the astroid
## |x|^0.5 + |y|^0.5 < 1, with a soft edge. White, so the particle colour tints it.
static func star_texture() -> ImageTexture:
	if _star != null:
		return _star
	var img := Image.create(STAR_SIZE, STAR_SIZE, false, Image.FORMAT_RGBA8)
	for y in STAR_SIZE:
		for x in STAR_SIZE:
			var u := (x + 0.5) / STAR_SIZE * 2.0 - 1.0
			var v := (y + 0.5) / STAR_SIZE * 2.0 - 1.0
			var d := sqrt(absf(u)) + sqrt(absf(v))
			var a := clampf((1.05 - d) / 0.1, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_star = ImageTexture.create_from_image(img)
	return _star

## A soft round droplet, drawn the same way as star_texture(): white so the
## particle colour tints it, alpha falling off toward the edge. The jet pool
## uses this instead of a plain untextured quad (task 4 fix round 3): a flat
## quad with a hard edge reads as a solid coloured square once it is drawn
## large enough to see at all; a soft circular falloff reads as a drop.
static func droplet_texture() -> ImageTexture:
	if _droplet != null:
		return _droplet
	var img := Image.create(STAR_SIZE, STAR_SIZE, false, Image.FORMAT_RGBA8)
	for y in STAR_SIZE:
		for x in STAR_SIZE:
			var u := (x + 0.5) / STAR_SIZE * 2.0 - 1.0
			var v := (y + 0.5) / STAR_SIZE * 2.0 - 1.0
			var d := sqrt(u * u + v * v)
			var a := clampf((1.0 - d) / 0.3, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_droplet = ImageTexture.create_from_image(img)
	return _droplet
