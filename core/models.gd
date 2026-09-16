extends RefCounted

## The model library. Every 3D piece in the game comes through instance(): a
## Blender export at assets/models/<slot>.glb when one exists, otherwise the
## primitive placeholder. Drop a .glb with the right name and it appears.

const Toon = preload("res://core/toon.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Pal = preload("res://core/palette.gd")

const DIR := "res://assets/models/"
## The model names the game asks for. docs/art/blender-contract.md lists the
## same names with their footprint rules.
const SLOTS := ["tile", "rim_edge", "rim_corner", "platform", "water", "socket", "peg", "pip", "lid",
	"pipe_pad", "pipe_cap", "pipe_straight", "pipe_elbow", "pipe_tee", "pipe_cross", "valve",
	"block", "pump", "source_tank", "drain_pool",
	"scale_stand", "scale_beam", "scale_pan", "plinth", "weight_disc",
	"token_ball", "token_cube", "token_prism", "token_gem", "token_cross", "post",
	"plot_pad", "wall_edge", "wall_post", "clue_stone",
	"turf_pad", "camp_tree", "tent", "cairn",
	"wall_block", "lantern",
	"mosaic_tile", "plank",
	"horse", "fence", "apple", "bale", "channel", "stalk", "flower",
	"snake_head", "burrow",
	"deck", "pier_post", "boulder", "bush", "daisy", "tuft", "signpost"]
## The five pipe shapes. They all carry the same three layers, so anything
## that dresses or tints one dresses or tints all of them.
const PIPES := ["pipe_cap", "pipe_straight", "pipe_elbow", "pipe_tee", "pipe_cross"]
## Every slot with a water tube in it. The island's pump, tank and drain carry
## the pipe's own `Steel`, `Collar` and `Flow_flat` layers precisely so the
## flood wets them like any other piece, and this is the list that dresses
## them. They are not in PIPES and must not be: that is the set of *shapes* a
## piece can take, the five the tray cycles through, and a pump or a drain is
## not one of them.
const FLOWING := PIPES + ["pump", "source_tank", "drain_pool"]
## Balance's weight tokens, in core/shapes.gd's kind order: shape index 0 is a
## ball as Kind.CIRCLE is a circle. They all carry the same single layer, so
## anything that tints one tints all of them.
const TOKENS := ["token_ball", "token_cube", "token_prism", "token_gem", "token_cross"]
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

## Overrides every surface under `root` whose imported material is called
## `name` with `mat`. The glTF material name survives on the mesh surface and
## an override does not touch it, so this is repeatable.
static func set_material_named(root: Node, name: String, mat: Material) -> void:
	for mi in meshes(root):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null and src.resource_name == name:
				mi.set_surface_override_material(i, mat)

## The override applied to the first surface named `name`, or null when the
## name is absent or nothing has overridden it. Pipes reads back the flow
## material _dress gave its piece this way.
static func material_named(root: Node, name: String) -> Material:
	for mi in meshes(root):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null and src.resource_name == name:
				return mi.get_surface_override_material(i)
	return null

## Recolours only the surfaces whose imported material is called `name`
## (the glTF material name survives on the mesh surface; overrides do not
## touch it). Used for assemblies where only some layers are tinted: the
## tile's `Stone` body takes the state colour while its inlaid `Sun` and
## `Moon` keep the colours they were modelled with.
static func tint_named(root: Node, name: String, color: Color) -> void:
	set_material_named(root, name, Toon.material(color))

## Turns off shadow casting on the mesh instance whose imported material is
## called `name`. For a layer whose shadow cannot contribute a single visible
## pixel -- it sits wholly inside another layer's silhouette, or is too thin
## to throw anything -- this is a pure saving: one fewer shadow-pass draw
## call per instance, with nothing lost on screen. Applied at the layer's own
## mesh instance (one mesh per layer, per the Blender contract), so it never
## touches a sibling layer sharing the same node.
static func set_shadow_off_named(root: Node, name: String) -> void:
	for mi in meshes(root):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null and src.resource_name == name:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				break

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
	# GDScript's match cannot take FLOWING as a pattern, so the names live
	# here as a plain `in` check instead of a third listing alongside SLOTS
	# and FLOWING itself. No return: the five shapes have no case below, and
	# the drain has one, so this falls through to the match either way.
	if slot in FLOWING:
		# Each piece gets its own flow material: the board drives `wet` per
		# cell as the flood reaches it.
		set_material_named(node, "Flow_flat", Toon.pipe_flow())
		# The inner tube sits entirely inside the shell's own silhouette,
		# at the collar radius -- its shadow can never show past the
		# shell's, so casting one at all is pure waste (task 6 fix 1/3).
		set_shadow_off_named(node, "Flow_flat")
		# The flange ring's radius is close to the shell's, on the same
		# axis, so most of its shadow was already swallowed by the
		# shell's. Screenshotted both ways before keeping this one: the
		# ribbed relief reads the same, since it comes from the toon
		# ramp's own shading on the ring geometry, not from a cast shadow
		# (task 6 fix 3/3, the judgment call).
		set_shadow_off_named(node, "Collar")
	if slot.begins_with("mascot_"):
		# A mascot's flat layers -- the mouth, the tongue, the eyes, the
		# cheeks, the map POM holds -- are all laid on or inside its own
		# body, so every one of their shadows falls where the body's
		# silhouette already is. One rule for every mascot rather than a
		# case each: a new character gets this for nothing.
		for surface in surface_names(node):
			if surface.ends_with(Toon.FLAT_SUFFIX):
				set_shadow_off_named(node, surface)
	match slot:
		"water":
			for mi in meshes(node):
				for i in mi.mesh.get_surface_count():
					mi.set_surface_override_material(i, Toon.water())
		"valve":
			# The bolts are a 3 mm-tall disc lying flat on the pad -- too thin
			# to throw a shadow anyone would ever see (task 6 fix 2/3).
			set_shadow_off_named(node, "Bolt_flat")
		"turf_pad":
			# A field cell is a flat slab, flush with the cells around it and
			# 0.08 above the stone margin at the field's edge. Its own shadow
			# either falls on a neighbour at the same height, where nothing
			# can see it, or is a sub-pixel sliver in a 0.04 seam -- and the
			# pad's outline already draws the boundary that sliver would.
			# Off, then, for the same reason Pipes drops its water tube's:
			# one fewer shadow-pass draw call per cell, 64 of them on the
			# hard board, with nothing lost on screen. The pads still
			# *receive* the trees' and tents' shadows, which is the shadow
			# work that carries this board.
			set_shadow_off_named(node, "Turf")
		"plank":
			# A plank lies flat on the deck, so its shadow falls right at its
			# own edge and is all but swallowed by the plank itself. There are
			# 27 of them on the hardest board, which is 27 shadow-pass draw
			# calls for a sliver nobody can see; the posts still cast theirs,
			# and those are the shadows that give the jetty its depth. Same
			# reasoning as Untangle's ropes and Tents' turf.
			set_shadow_off_named(node, "Plank")
		"wall_block":
			# The carved numeral is a flat inlay lying on the block's crown,
			# the same waste as the clue stone's: a shadow pass per instance,
			# for a shadow no pixel of which could ever show.
			set_shadow_off_named(node, "Num_flat")
		"apple":
			# The leaf is a single thin sheet lying against the fruit and the
			# stem a twig on its crown; both shadows fall inside the fruit's
			# own, where no pixel of them can show.
			set_shadow_off_named(node, "Leaf_flat")
			set_shadow_off_named(node, "Stem_flat")
		"channel":
			# The cut is filled with the stage's own water, so a splash rings
			# it and it catches the same bands and sparkle as the sea around
			# the island. The surface is flat and lies below its own banks:
			# its shadow could not show a pixel, and the banks' shadows
			# falling into the water are what give the cut its depth.
			set_material_named(node, "Water_flat", Toon.water())
			set_shadow_off_named(node, "Water_flat")
		"drain_pool":
			# The basin is filled with the stage's own water, so a splash rings
			# it and it catches the same bands and sparkle as the sea the
			# island stands in -- the channel's arrangement exactly. The
			# surface lies well under its own rim: its shadow could not show a
			# pixel, and the rim's shadow falling into it is what gives the
			# basin its depth.
			set_material_named(node, "Water_flat", Toon.water())
			set_shadow_off_named(node, "Water_flat")
		"bale":
			# A strap stands 0.012 proud of the straw, lying along it: its
			# shadow falls inside the bale's own silhouette. The straw keeps
			# its shadow -- a bale having one is half the reason it replaced
			# the see-through fence.
			set_shadow_off_named(node, "Straps")
		"burrow":
			# The hole is a disc lying flat in the rim's own shadow.
			set_shadow_off_named(node, "Hole_flat")
		"clue_stone":
			# The carved numeral is a 3 mm-tall inlay lying flat on the
			# marker's crown, the same waste as the plinth's: a shadow pass
			# per instance, for a shadow no pixel of which could ever show.
			set_shadow_off_named(node, "Num_flat")
		"plinth":
			# The numeral bars and the stack's well are 3 mm-tall inlays lying
			# flat on the pad, the same waste as the valve's bolts: a shadow
			# pass each, for a shadow no pixel of which could ever show.
			set_shadow_off_named(node, "Num_flat")
			set_shadow_off_named(node, "Well_flat")
		"peg":
			# The shine is a patch half buried in the dome and the mark a
			# 0.012 inlay on its crown; neither can throw a shadow that
			# shows past the dome's own. The fullest board carries
			# thirty-two pegs, so that is sixty-four shadow-pass draw calls
			# for nothing -- the same argument as the valve's bolts and the
			# wall block's numeral.
			set_shadow_off_named(node, "Shine_flat")
			set_shadow_off_named(node, "Mark_flat")
		"lid":
			# From above the knob has to read as the dark hole in the concept's
			# lids, not a pale wooden stud; the model keeps its own colour.
			tint_named(node, "Knob", Pal.BARK)
		"deck":
			# A strip laid on the bank casts into a 0.1 gap nobody sees.
			set_shadow_off_named(node, "Deck")
		"boulder":
			set_shadow_off_named(node, "Moss_flat")
		"daisy":
			set_shadow_off_named(node, "Petal_flat")
			set_shadow_off_named(node, "Centre_flat")
			set_shadow_off_named(node, "Stem_flat")
		"signpost":
			set_shadow_off_named(node, "Paper_flat")
			set_shadow_off_named(node, "Ink_flat")
		"bush":
			# A leaf blob sits on the bank, where its shadow from the board's
			# steep camera is a sliver under its own silhouette; six of them
			# on Code Break's screen are six shadow-pass draw calls for
			# nothing anyone sees. Same reasoning as Tents' turf.
			set_shadow_off_named(node, "Leaf")
