class_name PeepletFur
extends RefCounted

## Applies the toon shell-fur material chain to the imported peeplet.glb
## mesh: base coat -> FUR_SHELL_COUNT shell passes -> outline hull, all chained
## via next_pass on the coat surfaces. Face surfaces keep their imported flat
## colors, converted to unshaded so they match the cel look.

const FUR_SHELL_COUNT := 4
const FUR_LENGTH := 0.055
# Surface indices follow the Blender material slot order of peeplet.glb:
# 0 body, 1-9 face features (eye outline/iris/shine/peach x2, then mouth),
# 10/11 legs, 12 tail, 13/14 arms.
const COAT_SURFACES := [0, 10, 11, 12, 13, 14]
const BODY_COAT_SURFACE := 0
# Iris surfaces get the glint shader instead of a flat face color; the white
# reflex spot used to be baked geometry and now tracks light_direction.
const IRIS_SURFACES := [2, 6]
# The lit crescent under each iris. Baked for brown, so an eye trait has to
# retint it alongside the iris or a blue eye keeps a brown underlight.
const LOWER_LIGHT_SURFACES := [3, 7]
# Cream belly oval ported from the rpg-adventure-2 lab peeplet, enabled only
# on the body coat. The lab aimed it front-down (0, -0.88, 0.48); here it is
# raised toward the front so the 46-degree game camera sees it, and shrunk so
# the soft edge stays below the mouth (direction ~(0, 0.24, 0.97)).
const BELLY_STRENGTH := 1.0
const BELLY_DIRECTION := Vector3(0.0, -0.5, 0.87)
const BELLY_SIZE := 0.84
# Lit band color from the Blender look-dev ramp; the shader's shadow_tint
# multiplier produces the dark band.
const FUR_COLOR := Color(1.0, 0.323, 0.258)
const OUTLINE_COLOR := Color(0.02, 0.01, 0.015)
const OUTLINE_WIDTH := 0.018
# Keyed top-front so the face stays fully lit; the shadow band wraps the
# lower back and sides instead of cutting across the eyes.
const LIGHT_DIRECTION := Vector3(0.3, 0.8, 0.75)
# daily: the fur cropped short, so the silhouette reads as a clean soft shape
# beside the house's drawn characters rather than a tufted render.
const SOFT_FUR_LENGTH := 0.018

## Returns every ShaderMaterial in the fur chain so callers can drive shared
## uniforms (wind, wetness, toon_strength) at runtime. The body coat carries
## the cream belly patch; limb coats stay plain — their vertices point at the
## belly direction (feet aim straight down) and would go cream too.
static func apply(
	mesh_instance: MeshInstance3D, fur_color := FUR_COLOR, premium_mode := 0,
	eye_trait := PeepletEyes.DEFAULT_TRAIT,
	markings := PeepletMarkings.DEFAULT_TRAIT
) -> Array[ShaderMaterial]:
	var body_chain := build_chain(
		fur_color, BELLY_STRENGTH, premium_mode, PeepletMarkings.mode(markings))
	var limb_chain := build_chain(fur_color, 0.0, premium_mode)
	var mesh := mesh_instance.mesh
	var eyes: Array[ShaderMaterial] = []
	for surface in mesh.get_surface_count():
		if surface == BODY_COAT_SURFACE:
			mesh_instance.set_surface_override_material(surface, body_chain[0])
		elif surface in COAT_SURFACES:
			mesh_instance.set_surface_override_material(surface, limb_chain[0])
		elif surface in IRIS_SURFACES:
			var eye := PeepletEyes.iris_material(eye_trait)
			mesh_instance.set_surface_override_material(surface, eye)
			eyes.append(eye)
		elif surface in LOWER_LIGHT_SURFACES:
			mesh_instance.set_surface_override_material(
				surface, flat_color_material(PeepletEyes.lower_light_color(eye_trait)))
		else:
			mesh_instance.set_surface_override_material(surface, _flat_face_material(mesh.surface_get_material(surface)))
	return body_chain + limb_chain + eyes

## premium_mode picks a patterned coat (see PeepletPalette.BODY): the rare body
## colors paint a starfield or foam over the whole creature rather than tinting
## it flat. Limbs take the same mode as the body — the pattern is evaluated in
## glb object space, so body and limbs share one continuous field and a solid
## limb next to a starry body would read as a seam.
## body_mark_mode is PeepletMarkings' shader mode: the painted markings trait,
## drawn on the left flank in the coat's own vertex space. Pass it on the body
## chain only — the limb parts sit on their own pivots (see PeepletMarkings).
static func build_chain(
	fur_color: Color, belly_strength := 0.0, premium_mode := 0, body_mark_mode := 0
) -> Array[ShaderMaterial]:
	var chain: Array[ShaderMaterial] = []
	var base := ShaderMaterial.new()
	base.shader = load("res://peeplet/peeplet_fur.gdshader") as Shader
	base.set_shader_parameter("fur_color", fur_color)
	base.set_shader_parameter("premium_mode", premium_mode)
	base.set_shader_parameter("body_mark_mode", body_mark_mode)
	base.set_shader_parameter("toon_strength", 1.0)
	base.set_shader_parameter("light_direction", LIGHT_DIRECTION)
	base.set_shader_parameter("belly_strength", belly_strength)
	base.set_shader_parameter("belly_direction", BELLY_DIRECTION)
	base.set_shader_parameter("belly_size", BELLY_SIZE)
	chain.append(base)
	var previous := base
	for shell in range(1, FUR_SHELL_COUNT + 1):
		var layer := ShaderMaterial.new()
		layer.shader = load("res://peeplet/peeplet_fur_shell.gdshader") as Shader
		layer.set_shader_parameter("fur_color", fur_color)
		layer.set_shader_parameter("premium_mode", premium_mode)
		layer.set_shader_parameter("body_mark_mode", body_mark_mode)
		layer.set_shader_parameter("fur_length", SOFT_FUR_LENGTH)
		layer.set_shader_parameter("shell_ratio", float(shell) / float(FUR_SHELL_COUNT))
		layer.set_shader_parameter("toon_strength", 1.0)
		layer.set_shader_parameter("light_direction", LIGHT_DIRECTION)
		layer.set_shader_parameter("belly_strength", belly_strength)
		layer.set_shader_parameter("belly_direction", BELLY_DIRECTION)
		layer.set_shader_parameter("belly_size", BELLY_SIZE)
		# Shave body fur around the face shells so eyes and mustache stay
		# readable. Positions in glb object space (measured from surface bounds).
		layer.set_shader_parameter("face_mask_strength", 1.0)
		layer.set_shader_parameter("eye_left", Vector3(-0.245, 0.325, 0.5))
		layer.set_shader_parameter("eye_right", Vector3(0.245, 0.325, 0.5))
		layer.set_shader_parameter("mouth_center", Vector3(0.0, 0.16, 0.65))
		layer.set_shader_parameter("eye_mask_radius", 0.16)
		layer.set_shader_parameter("mouth_mask_radius", 0.13)
		chain.append(layer)
		previous.next_pass = layer
		previous = layer
	var outline := ShaderMaterial.new()
	outline.shader = load("res://peeplet/peeplet_fur_outline.gdshader") as Shader
	outline.set_shader_parameter("outline_width", OUTLINE_WIDTH)
	outline.set_shader_parameter("fur_length", FUR_LENGTH)
	outline.set_shader_parameter("outline_color", OUTLINE_COLOR)
	outline.set_shader_parameter("fur_reach", 1.0)
	chain.append(outline)
	# daily: no line at all. The house characters (the menu's sun and moon)
	# are clean fills with no ink round them, so the hull stays in the chain
	# for whoever drives its uniforms but is never drawn.
	return chain

## Breaks the base coat away from its own shell chain so a caller can put the
## base alone on a shadow casting instance and the shells plus outline
## (chain[1] onward, still linked via next_pass) on a separate instance with
## casting off. Without this every shell pass and the outline pass render
## into the shadow map too, since next_pass chains render wherever the
## surface that holds them casts a shadow. Mutates chain[0].next_pass; chain
## is otherwise unchanged; call once per chain, not once per surface it ends
## up applied to.
static func split_shadow_chain(chain: Array[ShaderMaterial]) -> void:
	chain[0].next_pass = null

static func set_chain_parameter(chain: Array[ShaderMaterial], parameter: String, value: Variant) -> void:
	for material in chain:
		if material.shader.get_shader_uniform_list().any(func(u): return u.name == parameter):
			material.set_shader_parameter(parameter, value)

## Imported glTF face materials arrive as lit StandardMaterial3D; the cel look
## wants them flat. Emission-only Blender materials import with black albedo,
## so prefer the emission color when it carries the actual tint.
static func _flat_face_material(imported: Material) -> StandardMaterial3D:
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var source := imported as BaseMaterial3D
	if source != null:
		flat.albedo_color = _imported_tint(imported)
		flat.transparency = source.transparency
	return flat

## Same flat cel face material, but for a color a trait chose rather than one
## the glb baked in.
static func flat_color_material(color: Color) -> StandardMaterial3D:
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.albedo_color = color
	return flat

static func _imported_tint(imported: Material) -> Color:
	var source := imported as BaseMaterial3D
	if source == null:
		return Color.WHITE
	var color := source.albedo_color
	if source.emission_enabled and color.get_luminance() < 0.02:
		color = source.emission
	return color
