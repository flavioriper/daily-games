extends RefCounted

## Factory for the soft painted cel look (docs/art/shading-direction.md).
## Every 3D thing in the game gets its materials from here, so the shading
## contract lives in one place: an eased three-band ramp, an eased sky-tinted
## rim, a slow painterly wash over the colour, and an outline shell in the
## layer's own colour deepened rather than a shared ink line. Materials are
## cached per colour; a board of a hundred same-coloured tiles costs one
## material.

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
## (toon_wind.gdshader). A painted one gets wind_textured_material and a line
## that leans with it (wind_line); the flat-coloured sway layers -- grass,
## petals, wheat -- carry FLAT_SUFFIX as well and wear no line at all.
const SWAY_MARK := "_sway"

## The palette's woods. A surface that arrives in one of these colours gets
## the grain shader instead of the flat one, and that is the whole hook-up:
## a placeholder and an exported .glb both reach here as a base colour, so
## neither the models nor the boards had to learn a new mark.
const WOODS: Array[Color] = [Pal.DECK, Pal.WOOD, Pal.BARK, Pal.TIMBER, Pal.PLAQUE]
## glTF round-trips a colour through linear floats, so an exported model's
## wood comes back near its palette value rather than exactly on it.
const WOOD_TOL := 0.012
## How much longer one side must be before it counts as the grain's
## direction. Barely more than a tie, so that a strip modelled one unit long
## and stretched by the board at runtime -- the deck's, whose modelled length
## only just beats its width -- still grains along its length. A piece with
## no winner at all falls back to standing rings.
const GRAIN_LEAD := 1.02

## The line every layer wears (docs/art/shading-direction.md: no harsh black
## outlines): its own colour, deepened and cooled a little, and thinner than
## the ink line the cel look started with (outline(), kept only as the
## fallback for a layer whose colour cannot be read).
const LINE_WIDTH := 0.014
const LINE_DEEPEN := 0.45
const LINE_COOL := 0.12
## The rim: eased rather than stepped, and tinted with the sky so the upper
## edges catch bounced light rather than a drawn highlight. Wood's is a
## little stronger, so a plank's edge catches the light the way a sawn edge
## does.
const RIM_SOFT := 0.12
const RIM_STRENGTH := 0.18
const WOOD_RIM_STRENGTH := 0.24

static var _ramp: GradientTexture1D
static var _outline: ShaderMaterial
static var _line_cache: Dictionary = {}
static var _cache: Dictionary = {}
static var _wind_cache: Dictionary = {}
static var _wood_cache: Dictionary = {}
static var _water: ShaderMaterial
static var _ink_cache: Dictionary = {}
static var _ghost_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _wind_tex_cache: Dictionary = {}
static var _wind_line_cache: Dictionary = {}
static var _mean_cache: Dictionary = {}

## Three bands -- tinted shadow, half light, full light -- with each edge
## eased over a short run instead of stepping: clear light and shadow, soft
## terminator. Every lit material samples it. Wide enough that the shader's
## nearest sampling never shows a stair inside the ease. (The hard three-step
## ramp the cel look started with went on 2026-09-17; the wood had this one
## first, docs/art/shading-direction.md.)
static func ramp() -> GradientTexture1D:
	if _ramp == null:
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
		g.offsets = PackedFloat32Array([0.0, 0.37, 0.47, 0.66, 0.74, 1.0])
		var dark := Color(0, 0, 0)
		var half := Color(0.55, 0.55, 0.55)
		var lit := Color(1, 1, 1)
		g.colors = PackedColorArray([dark, dark, half, half, lit, lit])
		_ramp = GradientTexture1D.new()
		_ramp.gradient = g
		_ramp.width = 256
	return _ramp

## The eased ramp, the shared shadow tint and the eased sky rim on `m`: the
## soft painted treatment every lit material starts from.
static func _soften(m: ShaderMaterial, rim_strength := RIM_STRENGTH) -> void:
	m.set_shader_parameter("ramp", ramp())
	m.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
	m.set_shader_parameter("rim_soft", RIM_SOFT)
	m.set_shader_parameter("rim_strength", rim_strength)
	m.set_shader_parameter("rim_color", Pal.SKY_TOP)

## The plain painted material in one colour. Cached per colour.
static func material(albedo: Color) -> ShaderMaterial:
	var key := albedo.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", albedo)
	_soften(m)
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

## How many logs the game cuts its wood from. A seed picks one of these, and
## there is a material per (colour, axis, log): the seed cannot ride on the
## mesh as an instance parameter, because gl_compatibility shaders declare the
## buffer those come out of as 256 items -- sixteen instances in the whole
## frame -- and a mobile driver returns garbage past that, which is what broke
## the deck's figure and the day card's edge on Android. Eight is enough that
## neighbouring strips of one deck differ and small enough that the cache
## stays in the dozens.
const GRAIN_LOGS := 8
## The meta a mesh carries to say which log it was cut from. It lives on the
## mesh rather than the material so that a later recolour through material_for
## keeps the figure the piece was given.
const GRAIN_SEED_META := "grain_seed"

## The log `seed` names. Any float lands on one of GRAIN_LOGS.
static func grain_log(seed: float) -> float:
	return float(posmod(int(floorf(seed)), GRAIN_LOGS))

## Toon material with wood grain running along `axis`, in the mesh's own
## space, cut from log `seed`. Cached per colour, axis and log, like
## material().
static func wood_material(albedo: Color, axis := Vector3.UP, seed := 0.0) -> ShaderMaterial:
	var key := "%s@%s@%s" % [albedo.to_html(), axis, seed]
	if _wood_cache.has(key):
		return _wood_cache[key]
	var m := ShaderMaterial.new()
	m.shader = WOOD_SHADER
	m.set_shader_parameter("albedo", albedo)
	_soften(m, WOOD_RIM_STRENGTH)
	m.set_shader_parameter("grain_axis", axis)
	m.set_shader_parameter("grain_seed", seed)
	_wood_cache[key] = m
	return m

## The material a surface of `mi` should wear: a wood colour gets the grain,
## with its axis read off the mesh's own bounds; everything else gets the
## plain painted material. Every recolouring path goes through here, so a
## tinted plank keeps its grain.
static func material_for(mi: MeshInstance3D, albedo: Color) -> ShaderMaterial:
	if mi == null or mi.mesh == null or not is_wood(albedo):
		return material(albedo)
	return wood_material(albedo, grain_axis(mi.mesh.get_aabb().size),
		float(mi.get_meta(GRAIN_SEED_META, 0.0)))

## The painted look over a painted texture: the same ramp, rim and shadow
## tint, the texture multiplied into a white albedo. For a prop that arrives
## already painted -- the menu's camper and its fence sign, both cut down from
## Meshy exports in Blender -- where flat palette layers would throw the paint
## away. Cached per texture.
static func textured_material(tex: Texture2D) -> ShaderMaterial:
	var key := tex.get_rid()
	if _tex_cache.has(key):
		return _tex_cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", Color.WHITE)
	m.set_shader_parameter("albedo_tex", tex)
	_soften(m)
	_tex_cache[key] = m
	return m

## The painted look over a painted texture that also bends in the wind: the
## same white albedo as textured_material, on the sway shader. The scout's
## map is the first of these -- every sway layer before it was a flat colour,
## because grass and petals carry no paint. Its own cache, since a texture
## can be wanted both still (the scout's body) and moving.
static func wind_textured_material(tex: Texture2D) -> ShaderMaterial:
	var key := tex.get_rid()
	if _wind_tex_cache.has(key):
		return _wind_tex_cache[key]
	var m := ShaderMaterial.new()
	m.shader = WIND_SHADER
	m.set_shader_parameter("albedo", Color.WHITE)
	m.set_shader_parameter("albedo_tex", tex)
	_soften(m)
	_wind_tex_cache[key] = m
	return m

## The mean colour of a texture, so a painted layer's outline can be its own
## colour deepened (line()) rather than the shared ink. Read once off an 8 by
## 8 shrink of the image; a texture the CPU cannot decode falls back to the
## palette's bark, which is what most of the painted props are anyway.
static func texture_mean(tex: Texture2D) -> Color:
	var key := tex.get_rid()
	if _mean_cache.has(key):
		return _mean_cache[key]
	var mean := Pal.BARK
	var img := tex.get_image()
	if img != null:
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		if not img.is_compressed() and img.get_width() > 0:
			img.resize(8, 8, Image.INTERPOLATE_BILINEAR)
			var sum := Color(0, 0, 0, 0)
			for y in 8:
				for x in 8:
					sum += img.get_pixel(x, y)
			mean = sum / 64.0
			mean.a = 1.0
	_mean_cache[key] = mean
	return mean

## The painted material that sways in the wind; same ramp, rim and tint,
## its own cache.
static func wind_material(albedo: Color) -> ShaderMaterial:
	var key := albedo.to_html()
	if _wind_cache.has(key):
		return _wind_cache[key]
	var m := ShaderMaterial.new()
	m.shader = WIND_SHADER
	m.set_shader_parameter("albedo", albedo)
	_soften(m)
	_wind_cache[key] = m
	return m

## The same painted look, see-through and without the wash: what Pipes' peek
## swaps the ground for while the button is held. Cached per colour and alpha
## like material(), since a board swaps a handful of them on every press.
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

## A flat, unlit colour: a cut-out, with no ramp and no line. How Big? draws
## the thing to be sized this way, so the player sizes a shape rather than a
## painting and the reveal has something to show. Under 1.0 alpha it is
## see-through with a depth pre-pass, so a shape's own overlapping layers do
## not darken where they stack. Cached per colour and alpha like ghost().
static func ink(colour: Color, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s@%.2f" % [colour.to_html(), alpha]
	if _ink_cache.has(key):
		return _ink_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(colour, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	_ink_cache[key] = m
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

## The shared ink line the cel look started with. Only the fallback now, for
## a shell on a layer whose colour cannot be read (line_for); every layer
## with a colour wears line() in that colour instead.
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

## The line for a layer that sways: line()'s colour and width on a hull that
## leans by the same maths as the layer (outline.gdshader). Its own cache, so
## setting the sway on one of these never reaches a still layer that happens
## to share the colour -- the scout's map and his body take their mean colour
## from the same paint.
static func wind_line(albedo: Color) -> ShaderMaterial:
	var key := albedo.to_html()
	if _wind_line_cache.has(key):
		return _wind_line_cache[key]
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("color", line_color(albedo))
	m.set_shader_parameter("width", LINE_WIDTH)
	m.set_shader_parameter("sway_amount", 0.02)
	_wind_line_cache[key] = m
	return m

## The line `mi` asks for: its first surface's own colour, deepened and
## cooled (line_color), on a hull that leans if the layer sways. A painted
## layer's colour is its texture's mean. Read off the material the mesh wears
## now, so it is called after the material is set -- and again, through
## reline(), whenever the colour changes. A surface whose material carries no
## colour this can read (an authored ShaderMaterial of some other kind) falls
## back to the shared ink line.
static func line_for(mi: MeshInstance3D) -> ShaderMaterial:
	var m: Material = mi.material_override
	if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		m = mi.get_active_material(0)
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		if sm.shader == TOON_SHADER or sm.shader == WOOD_SHADER \
				or sm.shader == WIND_SHADER or sm.shader == GHOST_SHADER:
			var tex = sm.get_shader_parameter("albedo_tex")
			var colour: Color = texture_mean(tex) if tex is Texture2D \
				else Color(sm.get_shader_parameter("albedo"))
			return wind_line(colour) if sm.shader == WIND_SHADER else line(colour)
	elif m is StandardMaterial3D:
		var std := m as StandardMaterial3D
		return line(texture_mean(std.albedo_texture) if std.albedo_texture != null else std.albedo_color)
	return outline()

## Adds the inverted-hull shell as a child of `mi`, sharing its mesh. Safe to
## call twice. The shell casts no shadow, otherwise every piece would throw a
## fattened silhouette onto the table. `shell_material` picks the line; the
## default is the line of the colour `mi` wears now (line_for), so set the
## material first.
static func add_outline(mi: MeshInstance3D, shell_material: ShaderMaterial = null) -> MeshInstance3D:
	var existing := mi.get_node_or_null(OUTLINE_NODE)
	if existing != null:
		return existing
	var shell := MeshInstance3D.new()
	shell.name = OUTLINE_NODE
	shell.mesh = mi.mesh
	shell.material_override = shell_material if shell_material != null else line_for(mi)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(shell)
	return shell

## Re-lines `mi`'s shell, if it has one, for the colour it wears now. Every
## recolouring path calls this after the material change, since the line is
## the layer's own colour: a stone tile turned slate would otherwise keep a
## pale line. A shell given a line of its own width (Lettering.outline) is
## its owner's to keep; nothing recolours those.
static func reline(mi: MeshInstance3D) -> void:
	var shell := mi.get_node_or_null(OUTLINE_NODE)
	if shell is MeshInstance3D:
		(shell as MeshInstance3D).material_override = line_for(mi)

## Converts every StandardMaterial3D surface under `root` to the painted
## material with the same base colour and gives each mesh an outline shell in
## its own line, unless every surface name ends in FLAT_SUFFIX. ShaderMaterial
## surfaces are left as they are. This is the whole Blender-to-toon step, done
## at load time.
static func apply_to(root: Node) -> void:
	if root is MeshInstance3D:
		_apply_mesh(root)
	for child in root.get_children():
		if child.name == OUTLINE_NODE:
			continue
		apply_to(child)

## Each surface gets the material its colour and name ask for: the grain for
## a wood, the sway shader for a `_sway` layer, its paint kept for a textured
## one, the plain painted material otherwise. The shell then wears the line
## of the first surface's colour (line_for). One mesh is one layer (the
## Blender contract), so the first surface speaks for the mesh.
static func _apply_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var wants_outline := false
	for i in mi.mesh.get_surface_count():
		var src: Material = mi.get_active_material(i)
		if src is StandardMaterial3D:
			var sm := src as StandardMaterial3D
			var swaying := sways(sm.resource_name)
			var toon: ShaderMaterial
			if sm.albedo_texture != null:
				toon = wind_textured_material(sm.albedo_texture) if swaying \
					else textured_material(sm.albedo_texture)
			elif swaying:
				toon = wind_material(sm.albedo_color)
			else:
				toon = material_for(mi, sm.albedo_color)
			mi.set_surface_override_material(i, toon)
		if src == null or not src.resource_name.ends_with(FLAT_SUFFIX):
			wants_outline = true
	if wants_outline:
		add_outline(mi)
