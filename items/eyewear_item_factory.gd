## Eyewear from the per-kind GLBs exported out of adventure-eyewear.blend.
## Ported API from rpg-adventure-2/items/eyewear_item_factory.gd so callers
## work verbatim; the difference is every prop converts to the world cel
## look on creation (crop_item_factory pattern).
class_name EyewearItemFactory
extends RefCounted

# Canon trait names from web/public/peeplet/src-v2/manifest.json (eyewear).
# Values are paths, not preloaded scenes: nobody wears eyewear at boot in the
# empty valley, so scene() loads on first use.
const EYEWEAR_SCENES := {
	"visor": "res://items/visor.glb",
	"roundglasses": "res://items/roundglasses.glb",
	"swimgoggles": "res://items/swimgoggles.glb",
	"heartglasses": "res://items/heartglasses.glb",
	"eyepatch": "res://items/eyepatch.glb",
	"shades": "res://items/shades.glb",
	"glasses": "res://items/glasses.glb",
	"techvisor": "res://items/techvisor.glb",
	"starglasses": "res://items/starglasses.glb",
	"3dglasses": "res://items/3dglasses.glb",
	"monocle": "res://items/monocle.glb",
	"pixelshades": "res://items/pixelshades.glb",
	"rainbowshades": "res://items/rainbowshades.glb",
}
const TOON_SHADER := preload("res://world/toon_prop.gdshader")
const TOON_VCOL_SHADER := preload("res://world/toon_prop_vcol.gdshader")
const GLASS_SHADER := preload("res://world/toon_prop_glass.gdshader")
const OUTLINE_SHADER := preload("res://world/toon_prop_outline.gdshader")
# World metres of ink. Eyewear sits on a 0.6 m peeplet face; the crop
# default 0.008 reads as a marker scribble at this size. Swept 0.004 /
# 0.008 / 0.012 / 0.018 / 0.026 against worn captures: these glbs carry
# split normals, so the hull shell cracks instead of thickening — past
# 0.004 the extra width only leaks hairlines across the brow and punches
# holes in the lenses, so the thinnest setting stays.
const OUTLINE_WIDTH := 0.004

# One toon material per fill color, shared across kinds and instances.
static var toon_materials := {}
static var vcol_materials := {}
static var glass_materials := {}
static var outline_material: ShaderMaterial
static var _scene_cache: Dictionary = {}

static func scene(canon: String) -> PackedScene:
	if not _scene_cache.has(canon):
		_scene_cache[canon] = load(EYEWEAR_SCENES[canon]) as PackedScene
	return _scene_cache[canon]

static func kinds() -> Array:
	return EYEWEAR_SCENES.keys()

## Accepts either the canon camelCase trait value ("roundGlasses") or the
## lowercase GLB stem ("roundglasses"), since the wallet writes the former and
## the item files are named the latter. Unknown kinds and the "none" trait
## return an empty string.
static func resolve(kind: String) -> String:
	if EYEWEAR_SCENES.has(kind):
		return kind
	var wanted := kind.to_lower()
	for canon in EYEWEAR_SCENES:
		if String(canon).to_lower() == wanted:
			return canon
	return ""

static func create_eyewear(kind: String) -> Node3D:
	var canon := resolve(kind)
	if canon == "":
		return null
	var model := scene(canon).instantiate() as Node3D
	model.name = "EyewearModel"
	apply_toon_look(model)
	# daily: one draw for the frame, one for the lenses (PeepletBatch); the
	# temple arms go, as PeepletWalker.attach_eyewear hides them when worn.
	PeepletBatch.merge_props(model, toon_material_for(Color.WHITE, true),
		glass_material_for(Color.WHITE), ["Arm"])
	var eyewear := Node3D.new()
	eyewear.name = "Eyewear" + canon.to_pascal_case()
	# Blender fronts face -Y which the glTF exporter maps to +Z, matching
	# the Peeplet's forward axis, so the model needs no reorientation.
	eyewear.add_child(model)
	return eyewear

static func apply_toon_look(node: Node3D) -> void:
	if outline_material == null:
		outline_material = ShaderMaterial.new()
		outline_material.shader = OUTLINE_SHADER
		outline_material.set_shader_parameter("outline_width", OUTLINE_WIDTH)
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		# daily: no ink overlay, as ToonPropLook.apply.
		for surface in range(instance.mesh.get_surface_count()):
			var base := instance.mesh.surface_get_material(surface)
			if base is not StandardMaterial3D:
				continue
			var std := base as StandardMaterial3D
			# Textured surfaces keep their import material; the flat toon
			# fill would erase what makes them read.
			if std.albedo_texture != null:
				continue
			# daily: a see-through lens takes the glass toon, its import
			# alpha kept, rather than the glossy import pane.
			if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				instance.set_surface_override_material(surface, glass_material_for(std.albedo_color))
				continue
			var painted: bool = (instance.mesh.surface_get_format(surface) \
				& Mesh.ARRAY_FORMAT_COLOR) != 0
			instance.set_surface_override_material(
				surface, toon_material_for(std.albedo_color, painted))

static func toon_material_for(fill: Color, painted: bool) -> ShaderMaterial:
	var pool := vcol_materials if painted else toon_materials
	var key := fill.to_html()
	if not pool.has(key):
		var toon := ShaderMaterial.new()
		toon.shader = TOON_VCOL_SHADER if painted else TOON_SHADER
		toon.set_shader_parameter("albedo_tint", fill)
		pool[key] = toon
	return pool[key]

static func glass_material_for(fill: Color) -> ShaderMaterial:
	var key := fill.to_html()
	if not glass_materials.has(key):
		var glass := ShaderMaterial.new()
		glass.shader = GLASS_SHADER
		glass.set_shader_parameter("albedo_tint", fill)
		glass_materials[key] = glass
	return glass_materials[key]
