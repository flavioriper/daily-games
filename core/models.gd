extends RefCounted

## The model library. Every 3D piece in the game comes through instance(): a
## Blender export at assets/models/<slot>.glb when one exists, otherwise the
## primitive placeholder. Drop a .glb with the right name and it appears.

const Toon = preload("res://core/toon.gd")
const Placeholders = preload("res://core/placeholders.gd")

const DIR := "res://assets/models/"
## The model names the game asks for. docs/art/blender-contract.md lists the
## same names with their footprint rules.
const SLOTS := ["tile", "emblem_sun", "emblem_moon", "empty_mark", "rim_edge", "rim_corner", "platform", "water"]
## Slots exempt from the 1 x 1 footprint rule.
const UNBOUNDED := ["platform", "water"]

static var _scenes: Dictionary = {}

static func path_for(slot: String) -> String:
	return DIR + slot + ".glb"

static func has_model(slot: String) -> bool:
	return ResourceLoader.exists(path_for(slot))

static func instance(slot: String) -> Node3D:
	if has_model(slot):
		var scene: PackedScene = _scenes.get(slot)
		if scene == null:
			scene = load(path_for(slot))
			if scene == null:
				push_warning("Models: %s exists but did not load (not imported?); using placeholder" % path_for(slot))
				return Placeholders.make(slot)
			_scenes[slot] = scene
		var node := scene.instantiate() as Node3D
		node.name = slot
		Toon.apply_to(node)
		return node
	return Placeholders.make(slot)

## Every renderable mesh under `root`, outline shells excluded.
static func meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for child in root.get_children():
		if child.name == Toon.OUTLINE_NODE:
			continue
		out.append_array(meshes(child))
	return out

## Recolours every surface under `root` with the toon material for `color`.
static func tint(root: Node, color: Color) -> void:
	for mi in meshes(root):
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, Toon.material(color))

## Height of the model above its base, measured from the mesh bounds.
static func height(root: Node) -> float:
	var top := 0.0
	for mi in meshes(root):
		var box: AABB = mi.transform * mi.mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top
