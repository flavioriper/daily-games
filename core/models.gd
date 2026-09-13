extends RefCounted

## The model library. Every 3D piece in the game comes through instance(): a
## Blender export at assets/models/<slot>.glb when one exists, otherwise the
## primitive placeholder. Drop a .glb with the right name and it appears.

const Toon = preload("res://core/toon.gd")
const Placeholders = preload("res://core/placeholders.gd")

const DIR := "res://assets/models/"
## The model names the game asks for. docs/art/blender-contract.md lists the
## same names with their footprint rules.
const SLOTS := ["tile", "emblem_sun", "emblem_moon", "empty_mark", "rim_edge", "rim_corner", "platform", "water", "focus_ring"]
## Slots exempt from the 1 x 1 footprint rule.
const UNBOUNDED := ["platform", "water"]

static var _scenes: Dictionary = {}

static func path_for(slot: String) -> String:
	return DIR + slot + ".glb"

static func has_model(slot: String) -> bool:
	return ResourceLoader.exists(path_for(slot))

static func instance(slot: String) -> Node3D:
	var node: Node3D
	if has_model(slot):
		var scene: PackedScene = _scenes.get(slot)
		if scene == null:
			scene = load(path_for(slot))
			if scene == null:
				push_warning("Models: %s exists but did not load (not imported?); using placeholder" % path_for(slot))
		if scene != null:
			_scenes[slot] = scene
			node = scene.instantiate() as Node3D
			node.name = slot
			Toon.apply_to(node)
	if node == null:
		node = Placeholders.make(slot)
	_dress(slot, node)
	return node

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

## Recolours only the surfaces whose imported material is called `name`
## (the glTF material name survives on the mesh surface; overrides do not
## touch it). Used for slots with one material per face, like the tile.
static func tint_named(root: Node, name: String, color: Color) -> void:
	for mi in meshes(root):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null and src.resource_name == name:
				mi.set_surface_override_material(i, Toon.material(color))

## Distinct imported material names under `root`, in first-seen order.
static func surface_names(root: Node) -> Array[String]:
	var out: Array[String] = []
	for mi in meshes(root):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var nm := src.resource_name if src != null else ""
			if not out.has(nm):
				out.append(nm)
	return out

## Height of the model above its base, measured from the mesh bounds.
static func height(root: Node) -> float:
	var top := 0.0
	for mi in meshes(root):
		var box: AABB = mi.transform * mi.mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top

## Slot-specific materials the toon step cannot infer from a colour, applied
## to the export and the placeholder alike so the two never look different.
static func _dress(slot: String, node: Node3D) -> void:
	match slot:
		"focus_ring":
			for mi in meshes(node):
				mi.material_override = Placeholders.focus_material()
