extends RefCounted

## The model library. Every 3D piece in the game comes through instance(): a
## Blender export at assets/models/<slot>.glb when one exists, otherwise the
## primitive placeholder. Drop a .glb with the right name and it appears.

const Toon = preload("res://core/toon.gd")
const Placeholders = preload("res://core/placeholders.gd")

const DIR := "res://assets/models/"
## The model names the game asks for. docs/art/blender-contract.md lists the
## same names with their footprint rules.
const SLOTS := ["tile", "rim_edge", "rim_corner", "platform", "water", "socket", "peg", "pip", "lid"]
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
## touch it). Used for assemblies where only some layers are tinted: the
## tile's `Stone` body takes the state colour while its inlaid `Sun` and
## `Moon` keep the colours they were modelled with.
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

## Shows or hides the mesh node called `node_name` under `root`. The outline
## shell is a child of its mesh, so it follows. No-op when the name is absent.
## Code Break uses it for the peg marks (one of seven shown), the feedback
## slab's well and the pip balls.
static func set_layer_visible(root: Node, node_name: String, on: bool) -> void:
	var node := root.find_child(node_name, true, false)
	if node is Node3D:
		(node as Node3D).visible = on

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
		"water":
			for mi in meshes(node):
				for i in mi.mesh.get_surface_count():
					mi.set_surface_override_material(i, Toon.water())
