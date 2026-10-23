## Headgear from the per-kind GLBs exported out of blender/headgears.blend.
## Same shape as EyewearItemFactory so callers read alike; the cel conversion
## goes through ToonPropLook because these hats are flat-shaded (every corner
## carries split normals) and a material_overlay hull tears open on them.
class_name HeadgearItemFactory
extends RefCounted

# Canon trait names from web/public/peeplet/src-v2 (headgear-*.png); the GLB
# filenames are the same names lowercased. Values are paths, not preloaded
# scenes: nobody wears headgear at boot in the empty valley, so scene() loads
# on first use.
const HEADGEAR_SCENES := {
	"bandana": "res://items/bandana.glb",
	"beanie": "res://items/beanie.glb",
	"bow": "res://items/bow.glb",
	"cap": "res://items/cap.glb",
	"chefHat": "res://items/chefhat.glb",
	"crown": "res://items/crown.glb",
	"earmuffs": "res://items/earmuffs.glb",
	"flowerCrown": "res://items/flowercrown.glb",
	"graduationCap": "res://items/graduationcap.glb",
	"halo": "res://items/halo.glb",
	"leafAntlers": "res://items/leafantlers.glb",
	"mushroomCap": "res://items/mushroomcap.glb",
	"partyHat": "res://items/partyhat.glb",
	"pirateHat": "res://items/piratehat.glb",
	"propellerCap": "res://items/propellercap.glb",
	"starHeadband": "res://items/starheadband.glb",
	"sunhat": "res://items/sunhat.glb",
	"topHat": "res://items/tophat.glb",
	"vikingHelm": "res://items/vikinghelm.glb",
	"wizardHat": "res://items/wizardhat.glb",
}

static var _scene_cache: Dictionary = {}

static func scene(canon: String) -> PackedScene:
	if not _scene_cache.has(canon):
		_scene_cache[canon] = load(HEADGEAR_SCENES[canon]) as PackedScene
	return _scene_cache[canon]
# World metres of ink. Between the held-prop 0.006 and the crop 0.008: a worn
# hat spans ~0.29 m, and it shares a silhouette with the 0.004 eyewear right
# below it, so the lighter of the two prop weights keeps the head consistent.
const OUTLINE_WIDTH := 0.006
# Model-space to world for a worn hat: PeepletWalker's HEADGEAR_WORN_SCALE 2.30
# times WALKER_SCALE 0.375. ToonPropLook needs it to tell which parts are too
# thin to take a hull without going solid black.
const WORN_SCALE := 0.8625

static func kinds() -> Array:
	return HEADGEAR_SCENES.keys()

## Accepts either the canon camelCase trait value ("mushroomCap") or the
## lowercase GLB stem ("mushroomcap"), since the wallet writes the former and
## the item files are named the latter. Unknown kinds and the "none" trait
## return an empty string.
static func resolve(kind: String) -> String:
	if HEADGEAR_SCENES.has(kind):
		return kind
	var wanted := kind.to_lower()
	for canon in HEADGEAR_SCENES:
		if String(canon).to_lower() == wanted:
			return canon
	return ""

static func create_headgear(kind: String) -> Node3D:
	var canon := resolve(kind)
	if canon == "":
		return null
	var model := scene(canon).instantiate() as Node3D
	model.name = "HeadgearModel"
	ToonPropLook.apply(model, OUTLINE_WIDTH, WORN_SCALE)
	# daily: one draw for the whole hat (PeepletBatch.merge_props).
	PeepletBatch.merge_props(model, ToonPropLook.toon_material_for(Color.WHITE, true),
		EyewearItemFactory.glass_material_for(Color.WHITE))
	var headgear := Node3D.new()
	headgear.name = "Headgear" + canon.to_pascal_case()
	# Blender fronts face -Y, which the glTF exporter maps to +Z — the
	# Peeplet's forward axis — so the model needs no reorientation.
	headgear.add_child(model)
	return headgear
