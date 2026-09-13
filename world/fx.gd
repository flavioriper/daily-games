extends Node3D

## One-shot particle effects a board fires at a point: a dust puff when a
## prism lands, a sparkle for a hint. Emitters are pooled and picked
## round-robin, so taps in quick succession never steal each other's puff.
## Board-local: the board adds this as its own child. cue() is the audio
## hook; it only records the name until sounds exist. Spec:
## docs/superpowers/specs/2026-09-13-binairo-polish-design.md, section 3.

const Motion = preload("res://core/motion.gd")
const Ambient = preload("res://world/ambient.gd")
const Pal = preload("res://core/palette.gd")

const PUFF_POOL := 4
const SPARKLE_POOL := 2
const STAR_SIZE := 32

var puffs: Array[CPUParticles3D] = []
var sparkles: Array[CPUParticles3D] = []
## The most recent audio cue name. A later audio layer plays these.
var last_cue := ""
var _next_puff := 0
var _next_sparkle := 0
static var _star: ImageTexture

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

## Stone dust rising from `at` and shrinking away.
func puff(at: Vector3, colour: Color = Pal.STONE) -> void:
	if Motion.reduce:
		return
	_fire(puffs[_next_puff], at, colour)
	_next_puff = (_next_puff + 1) % PUFF_POOL

## Small stars floating up from `at`.
func sparkle(at: Vector3, colour: Color = Pal.SUN) -> void:
	if Motion.reduce:
		return
	_fire(sparkles[_next_sparkle], at, colour)
	_next_sparkle = (_next_sparkle + 1) % SPARKLE_POOL

## Audio hook. Effects name their sound here; nothing plays yet.
func cue(cue_name: String) -> void:
	last_cue = cue_name

func _fire(p: CPUParticles3D, at: Vector3, colour: Color) -> void:
	p.position = at
	p.color = colour
	p.restart()

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
