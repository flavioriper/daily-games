extends Node3D

## The world's continuous motion and the one switch that stills it: the
## motion_scale global every ambient shader reads, the pollen drifting over
## the board, and the splash ring on the water. The stage creates one of
## these as "Ambient". Spec: docs/superpowers/specs/2026-09-13-binairo-polish-design.md,
## section 4.

const Motion = preload("res://core/motion.gd")
const Toon = preload("res://core/toon.gd")
const Pal = preload("res://core/palette.gd")

## Global shader parameter, declared in project.godot [shader_globals].
const GLOBAL := "motion_scale"
const SPLASH_TIME := 2.0
const SPLASH_SPEED := 3.0
const POLLEN_AMOUNT := 24
const POLLEN_LIFETIME := 6.0

var pollen: CPUParticles3D
## Whether the motes belong on this screen at all. A board turns them off
## (Stage.show_setting): in game it stands against flat colour with nothing in
## the air, while the menu campsite keeps them. Reduce-motion stills them
## independently, so refresh() honours both.
var pollen_wanted := true
var _splash_age := -1.0

func _ready() -> void:
	_ensure_global()
	pollen = _make_pollen()
	add_child(pollen)
	refresh()
	set_process(false)

## Declares the global if project.godot has not (a stripped test project),
## never twice: RenderingServer errors on a duplicate. The project settings
## are the source of truth; asking the RenderingServer for its list is an
## editor-only call that errors at runtime on the Compatibility renderer.
static func _ensure_global() -> void:
	if not ProjectSettings.has_setting("shader_globals/" + GLOBAL):
		RenderingServer.global_shader_parameter_add(GLOBAL, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)

## 1 when the world moves, 0 under reduce-motion.
static func motion_scale() -> float:
	return 0.0 if Motion.reduce else 1.0

## Re-reads Motion.reduce: sets the shader global and starts or stills the
## pollen. Call after the flag changes.
func refresh() -> void:
	RenderingServer.global_shader_parameter_set(GLOBAL, motion_scale())
	if pollen == null:
		return
	var on := pollen_wanted and not Motion.reduce
	if on and not pollen.emitting:
		pollen.restart()
	pollen.emitting = on
	pollen.visible = on

## Puts the motes on this screen or takes them off; see pollen_wanted.
func show_pollen(on: bool) -> void:
	pollen_wanted = on
	refresh()

## Sizes the pollen volume to a board: its footprint plus a one-cell margin,
## one cell above its top, 0.4 tall. The stage calls this from fit_camera.
func fit_to(aabb: AABB) -> void:
	var c := aabb.get_center()
	pollen.position = Vector3(c.x, aabb.end.y + 1.0, c.z)
	pollen.emission_box_extents = Vector3(aabb.size.x * 0.5 + 1.0, 0.2, aabb.size.z * 0.5 + 1.0)

## Rings the water around `origin` (only its x and z matter). Nothing under
## reduce-motion.
func splash(origin: Vector3) -> void:
	if Motion.reduce:
		return
	var mat := Toon.water()
	if mat == null:
		return
	mat.set_shader_parameter("splash_origin", origin)
	_splash_age = 0.0
	mat.set_shader_parameter("splash_age", _splash_age)
	set_process(true)

func splash_age() -> float:
	return _splash_age

func _process(delta: float) -> void:
	if _splash_age < 0.0:
		set_process(false)
		return
	var mat := Toon.water()
	if mat == null:
		return
	_splash_age += delta
	if _splash_age >= SPLASH_TIME:
		_splash_age = -1.0
		set_process(false)
	mat.set_shader_parameter("splash_age", _splash_age)

func _make_pollen() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Pollen"
	p.amount = POLLEN_AMOUNT
	p.lifetime = POLLEN_LIFETIME
	p.preprocess = POLLEN_LIFETIME
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(4.0, 0.2, 4.0)
	p.direction = Vector3(1.0, -0.15, 0.2)
	p.spread = 20.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.16
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.04
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	ramp.colors = PackedColorArray([Color(Pal.MOON, 0.0), Color(Pal.MOON, 0.85), Color(Pal.MOON, 0.85), Color(Pal.MOON, 0.0)])
	p.color_ramp = ramp
	p.mesh = speck_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## A unit billboard quad that takes the particle's colour, for pollen and
## for the one-shot effects in world/fx.gd.
static func speck_mesh(texture: Texture2D = null) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	if texture != null:
		m.albedo_texture = texture
	q.material = m
	return q
