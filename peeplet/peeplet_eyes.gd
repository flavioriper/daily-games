class_name PeepletEyes
extends RefCounted

## The collection's ten eye traits, ported from the rpg-adventure-2 lab's
## EYE_TRAITS table onto the baked peeplet.glb face. The lab built eyes out of
## spheres it could recolor part by part; here the same four features arrive as
## glb surfaces (outline / iris / lower light / glint per eye), so a trait is
## expressed as one iris material plus the derived lower-light tint.
##
## The six common tiers are flat cel fills through peeplet_eye.gdshader; the
## four premium ones swap in peeplet_eye_premium.gdshader, which keeps the same
## sun-tracking reflex and adds the lab's faceted gem pattern under it. Colors,
## shadows, accents and the per-kind facet profile are the lab's numbers
## verbatim — peeplet.glb bakes brown's #6f3518 iris and #9a725d lower light,
## which is exactly what the table below reproduces for "brown".

const DEFAULT_TRAIT := "brown"

## Canon trait values from web/src/lib/traitArt.ts (PALETTE.eyes). Premium
## kinds are the ones carrying an "accent": gold, violet, ruby and silver, the
## same four the web rarity table treats as rare.
const EYES := {
	"brown": {"color": Color("#6f3518"), "shadow": Color("#32160e")},
	"blue": {"color": Color("#174bd8"), "shadow": Color("#071b75")},
	"green": {"color": Color("#23852a"), "shadow": Color("#0a3d18")},
	"amber": {"color": Color("#e18716"), "shadow": Color("#713407")},
	"teal": {"color": Color("#168f8d"), "shadow": Color("#064746")},
	"pink": {"color": Color("#ed3b9b"), "shadow": Color("#86104e")},
	# facets: pattern_seed, facet_count, sparkle_strength.
	# Gold's iris is the one value that is not the lab's: #b97a00 there read as
	# olive at this iris size, because the lab's ramp reached it from the lit
	# end of a big sphere. #d99311 is the brightness that lit region averaged
	# to, and it sits between the lab's ochre and the web canon #ffd54a.
	"gold": {"color": Color("#d99311"), "shadow": Color("#4f3100"),
		"accent": Color("#ffd65a"), "facets": Vector3(2.0, 7.0, 0.48)},
	"violet": {"color": Color("#9638ee"), "shadow": Color("#38106e"),
		"accent": Color("#e69cff"), "facets": Vector3(5.0, 9.0, 0.82)},
	"ruby": {"color": Color("#e32645"), "shadow": Color("#670817"),
		"accent": Color("#ff9aaa"), "facets": Vector3(8.0, 6.0, 0.68)},
	"silver": {"color": Color("#cbd5e5"), "shadow": Color("#4a5366"),
		"accent": Color("#ffffff"), "facets": Vector3(11.0, 10.0, 0.92)},
}

static func names() -> Array:
	return EYES.keys()

## Case-insensitive, and anything unknown or empty falls back to brown — an eye
## trait is never absent the way headgear can be "none", so a bad value should
## still leave a face that reads.
static func resolve(trait_name: String) -> String:
	if EYES.has(trait_name):
		return trait_name
	var wanted := trait_name.to_lower()
	for canon in EYES:
		if String(canon).to_lower() == wanted:
			return canon
	return DEFAULT_TRAIT

static func is_premium(trait_name: String) -> bool:
	return EYES[resolve(trait_name)].has("accent")

static func iris_color(trait_name: String) -> Color:
	return EYES[resolve(trait_name)]["color"]

## The little lit crescent under the iris. The lab derived it rather than
## authoring one per kind: a common eye lifts its own iris color, a premium eye
## lifts its shadow so the gem pattern above it stays the brightest thing.
static func lower_light_color(trait_name: String) -> Color:
	var eye: Dictionary = EYES[resolve(trait_name)]
	if eye.has("accent"):
		return (eye["shadow"] as Color).lightened(0.08)
	return (eye["color"] as Color).lightened(0.30)

static func iris_material(
	trait_name: String, light_direction := PeepletFur.LIGHT_DIRECTION
) -> ShaderMaterial:
	var canon := resolve(trait_name)
	var eye: Dictionary = EYES[canon]
	var material := ShaderMaterial.new()
	if eye.has("accent"):
		material.shader = load("res://peeplet/peeplet_eye_premium.gdshader") as Shader
		material.set_shader_parameter("iris_color", eye["color"])
		material.set_shader_parameter("shadow_color", eye["shadow"])
		material.set_shader_parameter("accent_color", eye["accent"])
		var facets: Vector3 = eye["facets"]
		material.set_shader_parameter("pattern_seed", facets.x)
		material.set_shader_parameter("facet_count", facets.y)
		material.set_shader_parameter("sparkle_strength", facets.z)
	else:
		material.shader = load("res://peeplet/peeplet_eye.gdshader") as Shader
		material.set_shader_parameter("iris_color", eye["color"])
	material.set_shader_parameter("light_direction", light_direction)
	return material
