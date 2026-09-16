extends RefCounted

## Factory for the cozy toon look. Every 3D thing in the game gets its
## materials from here, so the shading contract lives in one place.
## Materials are cached per colour; a board of a hundred same-coloured tiles
## costs one material.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const WIND_SHADER := preload("res://shaders/toon_wind.gdshader")
const WOOD_SHADER := preload("res://shaders/toon_wood.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const GHOST_SHADER := preload("res://shaders/toon_ghost.gdshader")
const PIPE_SHADER := preload("res://shaders/pipe_flow.gdshader")
const Pal = preload("res://core/palette.gd")

const OUTLINE_NODE := "Outline"
## A Blender material whose name ends in this gets toon shading but no
## outline shell (the table, ground, anything that should not read as a piece).
const FLAT_SUFFIX := "_flat"
## A Blender material whose name contains this bends in the wind
## (toon_wind.gdshader). It must also end in FLAT_SUFFIX, since the outline
## shell would not follow the sway.
const SWAY_MARK := "_sway"

## The palette's woods. A surface that arrives in one of these colours gets
## the grain shader instead of the flat one, and that is the whole hook-up:
## a placeholder and an exported .glb both reach here as a base colour, so
## neither the models nor the boards had to learn a new mark.
const WOODS: Array[Color] = [Pal.DECK, Pal.WOOD, Pal.BARK, Pal.TIMBER]
## glTF round-trips a colour through linear floats, so an exported model's
## wood comes back near its palette value rather than exactly on it.
const WOOD_TOL := 0.012
## How much longer one side must be before it counts as the grain's
## direction. Barely more than a tie, so that a strip modelled one unit long
## and stretched by the board at runtime -- the deck's, whose modelled length
## only just beats its width -- still grains along its length. A piece with
## no winner at all falls back to standing rings.
const GRAIN_LEAD := 1.02

## The line a soft painted layer wears instead of the shared dark outline
## (docs/art/shading-direction.md: no harsh black outlines). Wood is the
## first material on it: its line is its own colour, deepened and cooled a
## little, and thinner than the ink line.
const LINE_WIDTH := 0.014
const LINE_DEEPEN := 0.45
const LINE_COOL := 0.12
## Wood's rim: eased rather than stepped, and tinted with the sky so the
## upper edges catch bounced light rather than a drawn highlight.
const WOOD_RIM_SOFT := 0.12
const WOOD_RIM_STRENGTH := 0.24

static var _ramp: GradientTexture1D
static var _soft_ramp: GradientTexture1D
static var _outline: ShaderMaterial
static var _line_cache: Dictionary = {}
static var _cache: Dictionary = {}
static var _wind_cache: Dictionary = {}
static var _wood_cache: Dictionary = {}
static var _water: ShaderMaterial
static var _ghost_cache: Dictionary = {}

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

## The same three bands with each edge eased over a short run instead of
## stepping: clear light and shadow, soft terminator. The wood material
## samples it; every other material keeps ramp(). Wide enough that the
## shader's nearest sampling never shows a stair inside the ease.
static func soft_ramp() -> GradientTexture1D:
	if _soft_ramp == null:
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
		g.offsets = PackedFloat32Array([0.0, 0.37, 0.47, 0.66, 0.74, 1.0])
		var dark := Color(0, 0, 0)
		var half := Color(0.55, 0.55, 0.55)
		var lit := Color(1, 1, 1)
		g.colors = PackedColorArray([dark, dark, half, half, lit, lit])
		_soft_ramp = GradientTexture1D.new()
		_soft_ramp.gradient = g
		_soft_ramp.width = 256
	return _soft_ramp

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

## True when `c` is one of the palette's woods, within the tolerance a glTF
## round-trip costs.
static func is_wood(c: Color) -> bool:
	for w in WOODS:
		if absf(c.r - w.r) < WOOD_TOL and absf(c.g - w.g) < WOOD_TOL and absf(c.b - w.b) < WOOD_TOL:
			return true
	return false

## The axis a mesh of these local bounds grains along: a plank's length, a
## post's height. Read from the mesh rather than set per colour, because one
## wood serves both the mooring post standing up and the scale beam lying
## down, and the grain has to follow the piece, not the palette.
static func grain_axis(size: Vector3) -> Vector3:
	if size.x > size.y * GRAIN_LEAD and size.x > size.z * GRAIN_LEAD:
		return Vector3.RIGHT
	if size.z > size.x * GRAIN_LEAD and size.z > size.y * GRAIN_LEAD:
		return Vector3.BACK
	return Vector3.UP

## Toon material with wood grain running along `axis`, in the mesh's own
## space. Cached per colour and axis, like material().
static func wood_material(albedo: Color, axis := Vector3.UP) -> ShaderMaterial:
	var key := "%s@%s" % [albedo.to_html(), axis]
	if _wood_cache.has(key):
		return _wood_cache[key]
	var m := ShaderMaterial.new()
	m.shader = WOOD_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("ramp", soft_ramp())
	m.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
	m.set_shader_parameter("rim_soft", WOOD_RIM_SOFT)
	m.set_shader_parameter("rim_strength", WOOD_RIM_STRENGTH)
	m.set_shader_parameter("rim_color", Pal.SKY_TOP)
	m.set_shader_parameter("grain_axis", axis)
	_wood_cache[key] = m
	return m

## The material a surface of `mi` should wear: a wood colour gets the grain,
## with its axis read off the mesh's own bounds; everything else gets the
## flat toon material. Every recolouring path goes through here, so a tinted
## plank keeps its grain.
static func material_for(mi: MeshInstance3D, albedo: Color) -> ShaderMaterial:
	if mi == null or mi.mesh == null or not is_wood(albedo):
		return material(albedo)
	return wood_material(albedo, grain_axis(mi.mesh.get_aabb().size))

## Toon material that sways in the wind; same ramp and tint, its own cache.
static func wind_material(albedo: Color) -> ShaderMaterial:
	var key := albedo.to_html()
	if _wind_cache.has(key):
		return _wind_cache[key]
	var m := ShaderMaterial.new()
	m.shader = WIND_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("ramp", ramp())
	m.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
	_wind_cache[key] = m
	return m

## The same toon look, see-through: what Pipes' peek swaps the ground for
## while the button is held. Cached per colour and alpha like material(),
## since a board swaps a handful of them on every press.
static func ghost(albedo: Color, alpha := 0.35) -> ShaderMaterial:
	var key := "%s@%.2f" % [albedo.to_html(), alpha]
	if _ghost_cache.has(key):
		return _ghost_cache[key]
	var m := ShaderMaterial.new()
	m.shader = GHOST_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("ramp", ramp())
	m.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
	m.set_shader_parameter("alpha", alpha)
	_ghost_cache[key] = m
	return m

## The one water material. Shared so Ambient can drive its splash uniforms
## and every water surface shows the same ring.
static func water() -> ShaderMaterial:
	if _water == null:
		_water = ShaderMaterial.new()
		_water.shader = WATER_SHADER
		_water.set_shader_parameter("base_color", Pal.WATER)
		_water.set_shader_parameter("shallow_color", Pal.WATER_HI)
		# foam_color is left at the shader's own near-white default: Pal.MOON is
		# a warm cream tuned for the moon glyph and the pollen, and over the
		# water's blue it read as beige scum rather than foam. Foam on water is
		# near-white, which is what the shader already carries -- nothing here
		# needs to override it.
		_water.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
		_water.set_shader_parameter("splash_origin", Vector3.ZERO)
		_water.set_shader_parameter("splash_age", -1.0)
	return _water

## A fresh pipe-flow material, one per pipe instance. Deliberately not shared
## the way water() is: every cell drives its own `wet` as the flood reaches it,
## and the win drives its own `flow_speed`.
static func pipe_flow() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PIPE_SHADER
	m.set_shader_parameter("dry_color", Pal.FLOW_DRY)
	m.set_shader_parameter("base_color", Pal.WATER)
	m.set_shader_parameter("band_color", Pal.WATER_HI)
	m.set_shader_parameter("bubble_color", Pal.MOON)
	m.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
	m.set_shader_parameter("wet", 0.0)
	m.set_shader_parameter("flow_speed", 1.0)
	return m

static func sways(name: String) -> bool:
	return name.contains(SWAY_MARK)

static func outline() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
		_outline.set_shader_parameter("color", Pal.OUTLINE)
	return _outline

## The colour of a painted layer's line: the layer's own colour deepened,
## then pulled a little toward the shadow tint so it cools the way a painted
## shadow does instead of going to black.
static func line_color(albedo: Color) -> Color:
	return albedo.darkened(LINE_DEEPEN).lerp(Pal.SHADOW_TINT, LINE_COOL)

## The outline shell material for a layer of colour `albedo`, in its own
## line colour and at the thinner line width. Cached per colour.
static func line(albedo: Color) -> ShaderMaterial:
	var key := albedo.to_html()
	if _line_cache.has(key):
		return _line_cache[key]
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("color", line_color(albedo))
	m.set_shader_parameter("width", LINE_WIDTH)
	_line_cache[key] = m
	return m

## Adds the inverted-hull shell as a child of `mi`, sharing its mesh. Safe to
## call twice. The shell casts no shadow, otherwise every piece would throw a
## fattened silhouette onto the table. `shell_material` picks the line; the
## default is the shared dark outline.
static func add_outline(mi: MeshInstance3D, shell_material: ShaderMaterial = null) -> MeshInstance3D:
	var existing := mi.get_node_or_null(OUTLINE_NODE)
	if existing != null:
		return existing
	var shell := MeshInstance3D.new()
	shell.name = OUTLINE_NODE
	shell.mesh = mi.mesh
	shell.material_override = shell_material if shell_material != null else outline()
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

## A wood layer's shell wears the wood's own line (line()); anything else
## keeps the shared dark outline. One mesh is one layer (the Blender
## contract), so the first wood surface's colour speaks for the mesh.
static func _apply_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var wants_outline := false
	var shell: ShaderMaterial = null
	for i in mi.mesh.get_surface_count():
		var src: Material = mi.get_active_material(i)
		if src is StandardMaterial3D:
			var toon := wind_material(src.albedo_color) if sways(src.resource_name) else material_for(mi, src.albedo_color)
			mi.set_surface_override_material(i, toon)
			if shell == null and toon.shader == WOOD_SHADER:
				shell = line(src.albedo_color)
		if src == null or not src.resource_name.ends_with(FLAT_SUFFIX):
			wants_outline = true
	if wants_outline:
		add_outline(mi, shell)
