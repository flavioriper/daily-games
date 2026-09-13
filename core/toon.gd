extends RefCounted

## Factory for the cozy toon look. Every 3D thing in the game gets its
## materials from here, so the shading contract lives in one place.
## Materials are cached per colour; a board of a hundred same-coloured tiles
## costs one material.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const Pal = preload("res://core/palette.gd")

const OUTLINE_NODE := "Outline"
## A Blender material whose name ends in this gets toon shading but no
## outline shell (the table, ground, anything that should not read as a piece).
const FLAT_SUFFIX := "_flat"

static var _ramp: GradientTexture1D
static var _outline: ShaderMaterial
static var _cache: Dictionary = {}

## Three hard bands: tinted shadow, half light, full light.
static func ramp() -> GradientTexture1D:
	if _ramp == null:
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		g.offsets = PackedFloat32Array([0.0, 0.42, 0.70])
		g.colors = PackedColorArray([Color(0, 0, 0), Color(0.55, 0.55, 0.55), Color(1, 1, 1)])
		_ramp = GradientTexture1D.new()
		_ramp.gradient = g
		_ramp.width = 64
	return _ramp

static func material(albedo: Color) -> ShaderMaterial:
	var key := albedo.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("ramp", ramp())
	m.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
	_cache[key] = m
	return m

static func outline() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
		_outline.set_shader_parameter("color", Pal.OUTLINE)
	return _outline

## Adds the inverted-hull shell as a child of `mi`, sharing its mesh. Safe to
## call twice. The shell casts no shadow, otherwise every piece would throw a
## fattened silhouette onto the table.
static func add_outline(mi: MeshInstance3D) -> MeshInstance3D:
	var existing := mi.get_node_or_null(OUTLINE_NODE)
	if existing != null:
		return existing
	var shell := MeshInstance3D.new()
	shell.name = OUTLINE_NODE
	shell.mesh = mi.mesh
	shell.material_override = outline()
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(shell)
	return shell

## Converts every StandardMaterial3D surface under `root` to the toon material
## with the same base colour and gives each mesh an outline shell, unless every
## surface name ends in FLAT_SUFFIX. ShaderMaterial surfaces are left as they
## are. This is the whole Blender-to-toon step, done at load time.
static func apply_to(root: Node) -> void:
	if root is MeshInstance3D:
		_apply_mesh(root)
	for child in root.get_children():
		if child.name == OUTLINE_NODE:
			continue
		apply_to(child)

static func _apply_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var wants_outline := false
	for i in mi.mesh.get_surface_count():
		var src: Material = mi.get_active_material(i)
		if src is StandardMaterial3D:
			mi.set_surface_override_material(i, material(src.albedo_color))
		if src == null or not src.resource_name.ends_with(FLAT_SUFFIX):
			wants_outline = true
	if wants_outline:
		add_outline(mi)
