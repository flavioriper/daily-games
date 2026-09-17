@tool
extends Node3D

## The first screen's campsite: the diorama the menu's cards float over,
## staged the way the concept banner frames it. The scout stands on the dock
## reading his map with the river behind him, the day sign stands lettered on
## the grass at the left, the lantern at his feet, the path comes down from
## the tent and sweeps across the picture, the tree line and an oak close the
## back, and the little "A puzzle a brighter you" board hangs at the dock's
## far corner. Every prop is a library model (core/models.gd) placed here, so
## the camp is lit, shaded and outlined like a board. The fence-and-sign
## diorama that used to stand along the frame's bottom edge was dropped on
## 2026-09-17 (the user's call: it fought the page buttons and read as
## clutter); the lawn runs to the bottom now.
##
## The menu mounts one of these on the stage in place of a board and frames
## hero_box() in the top of the screen through the rig's shift lens
## (world/camera_rig.gd); tests/preview_tree.tscn stands the same camp under a
## fixed camera to look at. The lettering on both signs is data
## (core/lettering.gd), never part of a model.
##
## @tool so the preview scene shows the real camp in the editor; nothing here
## moves on its own, the scout blinks through world/mascot.gd.

const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Toon = preload("res://core/toon.gd")
const Scenery = preload("res://world/scenery.gd")
const Lettering = preload("res://core/lettering.gd")
const Mascot = preload("res://world/mascot.gd")

## The blossom and the foliage sheet are cards cut from the grass field, not
## library slots: they are painted planes with holes in them, so they wear an
## alpha billboard material instead of a toon one.
const BLOSSOM := preload("res://assets/models/blossom.glb")
const FOLIAGE := preload("res://assets/models/foliage.glb")
const CARD_FLOWERS := preload("res://assets/models/card_flowers.tres")
const CARD_FOLIAGE := preload("res://assets/models/card_foliage.tres")

## How high the camp stands over the stage's origin. The backdrop's hills
## ring is a plateau at about y 1.4 (hills.glb's flat, measured), and the menu
## camera stands out over that ring where a board's never does, so a camp at
## y 0 has its feet and its fence buried in sage. Above the plateau, the camp
## reads as a raised terrace with the ring's flat as the lower ground around
## it.
const LIFT := 2.0

## What the menu frames: the picture's middle plane, through the scout and the
## day sign, as wide as the banner shows and as tall as the hero strip is.
## Its centre is where the camera aims: just under the scout's chest, so the
## sign's plank and his feet fall in the lower half under the title and motto,
## and the tent and the tree line get the top. The frame is about ten units
## wide at their plane, the sign's plank a third of it, the scout two thirds
## of its height; the camera's pose over it is VIEW_* below.
const HERO_CENTRE := Vector3(1.0, 1.2, 4.9)
const HERO_SIZE := Vector3(10.0, 4.4, 0.6)
## How the camp is looked at, by the menu's shift lens and the preview's fixed
## camera alike: from a step to the left of it, a little over the scout's eye
## level, close and through a wide field. Taken off the editor's own
## three-quarter look at tests/preview_tree.tscn (2026-09-17): standing off
## to the left and close is what shows the scout's left side and lays the dock
## and the day sign at an angle rather than head on. The field is wide, not
## the editor's 104 degrees across, which bulges at a phone's edges.
const VIEW_PITCH := 13.7
const VIEW_YAW := -6.0
## Degrees across the frame the camp is fitted to.
const VIEW_FOV := 90.0

## The bank runs from well left of the frame out to the water's edge, and the
## river takes everything to the right of it.
const LAND_EDGE := 1.6
const GROUND := Vector3(40.0, 0.6, 52.0)
const GROUND_AT := Vector3(LAND_EDGE - 20.0, -0.3, -1.0)
const RIVER_Y := -0.5
## The path comes down the bank from the tent and sweeps across the frame to
## the right, so it crosses the picture instead of pointing at the camera --
## a path aimed at the lens is a slab of soil over half the foreground. Near
## the scout it threads the gap between the day sign's right post (about
## x -1.0) and the dock's left edge (x 0.6): at 1.8 wide from x -2.0 it ran
## into the dock's corner, and once the earth went the deck's own brown
## (Pal.CAMP_SOIL) the overlap read as broken planks under his feet.
const PATH_W := 1.4
const PATH_AT := Vector3(-2.5, -0.29, -1.6)
const PATH_YAW := 0.34
## The dock: four strips out over the water, with the scout standing on them.
const DOCK := Rect2(0.6, 2.0, 4.2, 4.0)  # x, z, width, depth
## The dock's first metre lies on the bank (LAND_EDGE is 1.6), and its
## planks' top and the turf's top both sat at y 0, so the turf fought through
## the planks as green patches under the scout's feet. The deck stands this
## much proud of the bank, the way the path stands proud of the turf, and
## whatever stands on the deck stands on that.
const DOCK_LIFT := 0.03
## Where the near bank turns right to close the water off under the camera.
const FRONT_Z := 6.2

const SCOUT_AT := Vector3(2.3, DOCK_LIFT, 4.9)
const SCOUT_YAW := -0.14
## A scout 1.07 tall at 1.0 is a small round animal; 2.6 makes him the
## banner's hero, as tall as the day sign beside him and two thirds of the
## frame, with the tent behind him still clearing his ears.
const SCOUT_SCALE := 2.6

## The day sign: two posts, a plank, the day and the island's name, and a
## conifer as its emblem, turned a little toward the camera so its face reads.
## In the scout's own plane, its plank at his chest, its right end a step
## from his backpack with the lantern between them on the path's edge.
const DAY_AT := Vector3(-2.2, 0.0, 4.9)
const DAY_YAW := 0.30
const DAY_PLANK := Vector3(3.4, 1.0, 0.12)
const DAY_PLANK_Y := 0.9
const DAY_POST_H := 1.5
const DAY_EM := 0.36
const ISLAND_EM := 0.21
const DAY_TEXT_X := -0.6
const DAY_MAX_W := 2.1

## The ground cover, dense enough that no bare turf shows in the frame the
## way none shows in the painted one: the grass field, the blossom cards
## and the low bushes are each one MultiMesh, so the count costs fill rate
## and never a draw call. Placed from one seeded generator so the field is
## the same every launch.
const GRASS := 620
const BLOSSOMS := 64
const BUSHES := 14
const GRASS_SEED := 20260916
## The canopy that frames the frame: an oak crown hanging into each top
## corner from a branch out of shot, between the camera and the camp, dark
## and soft in the soft focus's near band, the way the painted frame's
## foliage closes over its title. Crowns only -- the oak's trunk layer is
## hidden -- because a whole tree near enough to cut the corner stands its
## crown in front of the day sign and the little board: the menu camera
## stands about (0, 2.7, 10.7) in the camp's space looking at HERO_CENTRE,
## and both signs sit within a fifth of the frame's width of its edges. The
## positions were solved for the crown's centre to sit just outside the top
## corner (screen x 1.05 to 1.12 half-widths out, 0.62 up) about 2.3 units
## in front of the lens. [slot, x, y, z, yaw, scale]
const FRAME_CANOPY := [["oak", -1.89, 1.94, 7.92, 0.6, 1.73], ["oak", 3.07, 2.03, 8.58, 2.1, 1.71]]

var day_sign: Node3D
var scout: Node3D
var _day: MeshInstance3D
var _island: MeshInstance3D

func _ready() -> void:
	name = "Camp"
	position = Vector3(0.0, LIFT, 0.0)
	_build_ground()
	_build_props()
	_build_day_sign()
	_build_grass()

## The box the menu frames in the top of the screen. In the stage anchor's
## space, so it carries the lift.
func hero_box() -> AABB:
	return AABB(HERO_CENTRE + Vector3(0.0, LIFT, 0.0) - HERO_SIZE * 0.5, HERO_SIZE)

func set_day(n: int, island: String) -> void:
	Lettering.fit(_day, ("Day %d" % n).to_upper(), DAY_EM, DAY_MAX_W)
	Lettering.fit(_island, island.to_upper(), ISLAND_EM, DAY_MAX_W)

# --- the ground ---

func _build_ground() -> void:
	add_child(Scenery.ground(GROUND, GROUND_AT, Pal.CAMP_TURF))
	# The path, a hair proud of the turf so the two never fight for a pixel.
	var path := Scenery.ground(Vector3(PATH_W, 0.62, 24.0), PATH_AT, Pal.CAMP_SOIL)
	path.rotation.y = PATH_YAW
	add_child(path)
	# The river: the stage's own water, so a splash rings it, just under the
	# bank's top and running off to the right and toward the player.
	add_child(Scenery.water(Vector2(50.0, 70.0), Vector3(LAND_EDGE + 24.0, RIVER_Y, 2.0)))
	# The far bank, so the water reads as a river rather than an open sea:
	# a strip of turf out to the right with its own tree line on it.
	add_child(Scenery.ground(Vector3(24.0, 0.6, 46.0), Vector3(LAND_EDGE + 24.0, -0.3, -3.0), Pal.CAMP_TURF))
	# The near bank turns right just past the dock's end, so the ground under
	# the camera -- what the shift lens shows below the cards, close and from
	# above -- is lawn rather than a hard bank edge and a river's foam lines.
	add_child(Scenery.ground(Vector3(14.0, 0.6, 20.0), Vector3(LAND_EDGE + 7.0, -0.3, FRONT_Z + 10.0), Pal.CAMP_TURF))
	var dock := Scenery.deck(DOCK.position.x, DOCK.end.x, DOCK.position.y, DOCK.end.y)
	dock.position.y = DOCK_LIFT
	add_child(dock)
	for z in [DOCK.position.y + 0.4, DOCK.end.y - 0.4]:
		add_child(Scenery.prop("pier_post", Vector3(DOCK.end.x - 0.3, RIVER_Y - 0.1, z), 0.0, Vector3(1.0, 0.55, 1.0)))

# --- the props ---

func _build_props() -> void:
	scout = Mascot.new()
	scout.name = "Scout"
	scout.position = SCOUT_AT
	scout.rotation.y = SCOUT_YAW
	scout.scale = Vector3.ONE * SCOUT_SCALE
	add_child(scout)

	# The lantern is lit: its glass is a flat unlit cream rather than a shaded
	# layer, so it reads as light from inside whichever side the sun is on,
	# and it is bright enough to catch the camp grade's bloom.
	var lantern := Scenery.prop("lantern", Vector3(-0.1, 0.0, 5.6), 0.0, Vector3.ONE * 1.5)
	Models.set_material_named(lantern, "Glass", Toon.ink(Pal.LAMPLIGHT))
	add_child(lantern)
	add_child(_signpost())

	# The tent up the path, and behind it the tree line that hides the bank's
	# far edge: conifers with a round crown among them, so the line is not one
	# repeated shape.
	add_child(Scenery.prop("tent", Vector3(0.2, 0.0, -4.2), 0.38, Vector3.ONE * 7.0))
	var back := [[-12.0, -10.5, 5.4], [-8.6, -11.2, 6.0], [-5.4, -10.2, 5.0], [-2.2, -11.6, 5.6],
		[1.0, -10.4, 4.8], [4.2, -11.0, 5.2], [-15.0, -9.4, 4.6]]
	for i in back.size():
		var t: Array = back[i]
		add_child(_tree("camp_tree", Vector3(t[0], 0.0, t[1]), 0.7 * i, float(t[2])))
	add_child(_tree("oak", Vector3(-10.4, 0.0, -9.0), 1.4, 4.4))
	add_child(_tree("camp_tree", Vector3(-6.8, 0.0, -1.4), 1.1, 4.4))
	# The far bank's own trees, small with the distance.
	for t in [[14.0, -2.0, 4.6], [17.5, -6.0, 5.2], [12.5, -8.5, 4.2], [21.0, 0.5, 4.8]]:
		add_child(_tree("camp_tree", Vector3(t[0], 0.0, t[1]), t[0], float(t[2])))
	# The oak behind the day sign, whole and inside the frame: its crown is
	# leaf cards, and a card cut open by the top edge reads as shards rather
	# than as foliage, so it is sized to clear the edge instead of filling it.
	add_child(_tree("oak", Vector3(-5.8, 0.0, -3.0), 0.9, 3.4))
	# The canopy framing the frame (FRAME_CANOPY): in shade, a step deeper
	# still, trunkless, and casting nothing -- a shadow from in front of the
	# camp is one no light in the picture explains.
	for t in FRAME_CANOPY:
		var tree := _tree(t[0], Vector3(t[1], t[2], t[3]), t[4], t[5], Pal.CAMP_LEAF_DEEP)
		Models.set_layer_visible(tree, "Oak_Trunk", false)
		for mi in Models.meshes(tree):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tree)

	for b in [[1.2, 0.2, 0.4, 1.1], [-2.0, -1.8, 1.3, 0.9], [-4.6, 1.4, 2.1, 1.0], [-3.6, 8.2, 0.6, 0.9],
			[6.4, 5.6, 0.9, 1.3], [7.6, 1.8, 2.0, 0.9], [5.4, 8.8, 0.9, 1.1], [-7.6, 6.4, 0.2, 1.2],
			[3.2, 11.6, 1.7, 0.9]]:
		add_child(Scenery.prop("boulder", Vector3(b[0], 0.0, b[1]), b[2], Vector3.ONE * float(b[3])))
	for b in [[-4.2, 2.4, 0.4, 1.8], [-1.8, -2.6, 1.1, 1.6], [-5.6, 0.4, 2.2, 1.4], [0.8, -0.8, 0.6, 1.3]]:
		add_child(_tree("bush", Vector3(b[0], 0.0, b[1]), b[2], float(b[3])))
	for d in [[-1.6, 6.2], [-4.0, 5.0], [-0.9, 1.2], [-4.6, 3.0], [-3.0, 6.6], [-1.4, -1.0],
			[-2.4, 8.6], [-4.8, 7.8]]:
		add_child(Scenery.prop("daisy", Vector3(d[0], 0.0, d[1]), d[0] * 1.3, Vector3.ONE * 1.2))

	# The field's own painted cards: leaf sheets filling the gaps in the tree
	# line, as one scatter. Big enough (the sheet is 7 by 6 at 1.0) to close
	# the sky between one conifer and the next, so the back of the frame is a
	# dark wood rather than a row of trees against pale hills.
	var sheets: Array[Transform3D] = []
	for f in [[-11.2, -9.8, 0.62], [-9.0, -9.6, 0.56], [-6.6, -9.2, 0.5], [-4.4, -9.0, 0.48],
			[-1.6, -9.6, 0.54], [1.2, -9.4, 0.52], [3.6, -9.8, 0.5], [6.2, -10.2, 0.56]]:
		sheets.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * float(f[2])), Vector3(f[0], 0.0, f[1])))
	add_child(_cards(FOLIAGE, CARD_FOLIAGE, sheets, "foliage_field"))

## A tree or a bush placed as a prop, its leaf layer taken a step deeper than
## the library's LEAF: the painted frame's greens are forest, not lime. The
## oak's crown is the `Leaf_flat` layer, the conifer's and the bush's `Leaf`;
## tint_named re-lines whichever shell there is.
static func _tree(slot: String, at: Vector3, yaw: float, s: float, leaf := Pal.CAMP_LEAF) -> Node3D:
	var pivot := Scenery.prop(slot, at, yaw, Vector3.ONE * s)
	Models.tint_named(pivot, "Leaf", leaf)
	Models.tint_named(pivot, "Leaf_flat", leaf)
	return pivot

## The little hanging sign at the dock's far corner, re-lettered: its
## modelled words are Code Break's, so that layer is hidden and three lines
## of TextMesh stand on its paper instead. The paper is the model's
## `Sign_Paper` layer, measured off signpost.glb at x -0.23..0.63 and
## y 1.03..1.59 with its face at z 0.04, and the words sit a hair in front.
func _signpost() -> Node3D:
	var pivot := Scenery.prop("signpost", Vector3(4.5, DOCK_LIFT, 5.7), -0.45, Vector3.ONE * 1.7)
	var model: Node3D = pivot.get_child(0)
	Models.set_layer_visible(model, "Sign_Words", false)
	var lines := ["A puzzle", "a brighter", "you"]
	for i in lines.size():
		var mi := Lettering.line(lines[i].to_upper(), 0.115, 0.012, Pal.TEXT, 700, HORIZONTAL_ALIGNMENT_CENTER, 0.002)
		mi.position = Vector3(0.2, 1.46 - 0.15 * i, 0.05)
		model.add_child(mi)
	return pivot

## A field of one painted card as a single MultiMesh: the card's mesh under
## its alpha billboard material, one draw call for every blossom or leaf
## sheet in the camp. The billboard turns each instance to the camera on its
## own, so the scatter reads exactly as the placed cards did.
static func _cards(scene: PackedScene, mat: Material, transforms: Array[Transform3D], name: String) -> MultiMeshInstance3D:
	var sample := scene.instantiate() as Node3D
	var layers := Models.meshes(sample)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if not layers.is_empty():
		mm.mesh = layers[0].mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sample.free()
	return mmi

## The ground cover, three MultiMeshes over the turf: the grass field of
## baked strands, the blossom cards among it, and a line of low bushes along
## the bank and the path. Dense, the way the painted frame leaves no bare
## ground, and kept off the water, the path, the dock and the scout's feet.
func _build_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRASS_SEED
	var grass: Array[Transform3D] = []
	var guard := 0
	while grass.size() < GRASS and guard < GRASS * 40:
		guard += 1
		var x := rng.randf_range(-9.0, 7.5)
		var z := rng.randf_range(-8.0, 13.0)
		if not _on_turf(x, z, 0.25):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.35))
		grass.append(Transform3D(basis, Vector3(x, 0.0, z)))
	# The patch arrives in the library's LEAF lime; here it sways in the
	# camp's own deeper green, on the same wind shader.
	var lawn := Scenery.scatter("grass_patch", grass)
	lawn.material_override = Toon.wind_material(Pal.CAMP_GRASS)
	add_child(lawn)

	# The blossom card is half a unit tall, the grass patch up to 0.55 at its
	# largest, so a blossom stands at least as tall as the grass around it or
	# it is buried. Two in three go in the strip between the scout's plane
	# and the cards, where the frame shows the most turf.
	var blossoms: Array[Transform3D] = []
	guard = 0
	while blossoms.size() < BLOSSOMS and guard < BLOSSOMS * 40:
		guard += 1
		var front := blossoms.size() % 3 != 0
		var x := rng.randf_range(-8.0, 7.5) if front else rng.randf_range(-9.0, 1.2)
		var z := rng.randf_range(5.4, 10.0) if front else rng.randf_range(-6.0, 5.4)
		if not _on_turf(x, z, 0.5):
			continue
		blossoms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(1.0, 1.45)), Vector3(x, 0.0, z)))
	add_child(_cards(BLOSSOM, CARD_FLOWERS, blossoms, "blossom_field"))

	# The bushes hug the edges: the bank above the water, both sides of the
	# path, the foot of the tree line.
	var bushes: Array[Transform3D] = []
	var spots := [[0.9, -6.4], [1.0, -4.0], [0.8, -1.6], [1.1, 0.8], [-3.6, -6.2], [-4.8, -4.6],
		[-0.6, -7.4], [-7.6, -7.8], [-2.8, 10.2], [-6.2, 8.6], [4.2, 9.8], [6.6, 8.2], [-8.4, 4.4],
		[-8.0, -0.8]]
	for i in mini(BUSHES, spots.size()):
		var at := Vector3(spots[i][0] + rng.randf_range(-0.3, 0.3), 0.0, spots[i][1] + rng.randf_range(-0.3, 0.3))
		if not _on_turf(at.x, at.z, 0.1):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.7))
		bushes.append(Transform3D(basis, at))
	var field := Scenery.scatter("bush", bushes)
	field.material_override = Toon.material(Pal.CAMP_LEAF)
	add_child(field)

## Whether a spot is open turf: off the water, `pad` clear of the path's edge,
## outside the dock and off the scout's feet.
static func _on_turf(x: float, z: float, pad: float) -> bool:
	# Off the water: the bank's edge up to the dock's end, the turn past it.
	if x > LAND_EDGE - 0.3 and z < FRONT_Z + 0.3:
		return false
	# The path is turned, so the keep-off test turns with it.
	var along := Vector2(x, z) - Vector2(PATH_AT.x, PATH_AT.z)
	if absf(along.rotated(-PATH_YAW).x) < PATH_W * 0.5 + pad:
		return false
	if Rect2(DOCK.position - Vector2(0.4, 0.4), DOCK.size + Vector2(0.8, 0.8)).has_point(Vector2(x, z)):
		return false
	if Vector2(x, z).distance_to(Vector2(SCOUT_AT.x, SCOUT_AT.z)) < 1.4:
		return false
	return true

# --- the two lettered boards ---

## A plank of the game's own wood, grained along its length.
static func _plank(size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.wood_material(Pal.PLAQUE, Vector3.RIGHT)
	Toon.add_outline(mi, Lettering.outline(Toon.line_color(Pal.PLAQUE), 0.008))
	return mi

func _build_day_sign() -> void:
	day_sign = Node3D.new()
	day_sign.name = "DaySign"
	day_sign.position = DAY_AT
	day_sign.rotation.y = DAY_YAW
	add_child(day_sign)
	for x in [-1.25, 1.25]:
		day_sign.add_child(Scenery.prop("post", Vector3(x, 0.0, 0.0), 0.0, Vector3(0.7, DAY_POST_H, 0.7)))
	var plank := _plank(DAY_PLANK)
	plank.position = Vector3(0.0, DAY_PLANK_Y, 0.0)
	day_sign.add_child(plank)
	var face := DAY_PLANK.z * 0.5
	_day = Lettering.line("", DAY_EM, 0.03, Pal.SURFACE, 700, HORIZONTAL_ALIGNMENT_LEFT, 0.006)
	_day.position = Vector3(DAY_TEXT_X, DAY_PLANK_Y + 0.18, face + 0.015)
	day_sign.add_child(_day)
	_island = Lettering.line("", ISLAND_EM, 0.02, Pal.SURFACE_HI, 700, HORIZONTAL_ALIGNMENT_LEFT, 0.006)
	_island.position = Vector3(DAY_TEXT_X, DAY_PLANK_Y - 0.2, face + 0.01)
	day_sign.add_child(_island)
	# The emblem: a conifer standing on the plank's lower edge.
	day_sign.add_child(Scenery.prop("camp_tree", Vector3(-1.15, DAY_PLANK_Y - DAY_PLANK.y * 0.5 + 0.03, face + 0.02), 0.0, Vector3.ONE * 1.0))
	set_day(1, "")
