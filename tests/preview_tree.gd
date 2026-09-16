@tool
extends Node3D

## The first screen's composition, staged as a scene to look at: the scout on
## the dock with the river behind him, the day sign standing on the grass at
## the left, the lantern at his feet, the tent and the tree line closing the
## back, and the oak hanging into the top corner. The frame the concept
## banner draws, built out of the game's own pieces.
##
## Everything under the root is built here rather than saved in the .tscn.
## The props come through Models.instance and Scenery, so they wear the
## game's toon materials, wood grain, wind sway and outlines rather than a
## frozen copy of them, and the light rig is world/stage.gd's own: the sun
## from behind-right at 0.46 over 0.115 ambient. What the viewport shows is
## what the game draws.
##
## @tool, so the editor shows the staging live. To move the frame, move the
## constants below; nothing here is placed by hand in the scene file.
##
##     godot --path . --resolution 1280x720 --script res://tests/_shot_scene.gd \
##         -- res://tests/preview_tree.tscn

const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Toon = preload("res://core/toon.gd")
const Scenery = preload("res://world/scenery.gd")
const Lettering = preload("res://core/lettering.gd")

## The blossom and the foliage sheet are cards cut from the grass field, not
## library slots: they are painted planes with holes in them, so they wear
## the alpha billboard material beside this scene instead of a toon one.
const BLOSSOM := preload("res://assets/models/blossom.glb")
const FOLIAGE := preload("res://assets/models/foliage.glb")
const CARD_FLOWERS := preload("res://tests/preview/card_flowers.tres")
const CARD_FOLIAGE := preload("res://tests/preview/card_foliage.tres")

## Where the camera stands and what it holds in the middle of the frame. A
## long lens from well back rather than a wide one up close: that is what
## flattens the banner's depth, holding the scout and the day sign in one
## plane and pressing the tent and the tree line up behind them. The pitch is
## gentle, a little over his eye level rather than the boards' look-down.
const CAM_AT := Vector3(0.5, 2.35, 11.2)
const CAM_LOOK := Vector3(0.75, 0.95, 4.8)
const CAM_FOV := 32.0

## The bank runs from well left of the frame out to the water's edge, and the
## river takes everything to the right of it.
const LAND_EDGE := 1.6
const GROUND := Vector3(40.0, 0.6, 52.0)
const GROUND_AT := Vector3(LAND_EDGE - 20.0, -0.3, -1.0)
const RIVER_Y := -0.5
## The path comes down the bank from the tent and sweeps out of the frame to
## the left, so it crosses the picture instead of pointing at the camera --
## a path aimed at the lens is a slab of soil over half the foreground.
const PATH_W := 1.8
const PATH_AT := Vector3(-2.0, -0.29, -1.6)
const PATH_YAW := 0.34
## The dock: four strips out over the water, with the scout standing on them.
const DOCK := Rect2(0.6, 2.0, 4.2, 4.0)  # x, z, width, depth

const SCOUT_AT := Vector3(2.1, 0.0, 4.9)
const SCOUT_YAW := -0.14
## A scout 1.07 tall at 1.0 is a small round animal; 1.2 puts him at about
## 1.3 m, half the height of the tent behind him.
const SCOUT_SCALE := 1.2

## The day sign, the same two posts and lettered plank the camp stands on its
## grass, turned a little toward the camera so its face is readable.
const DAY_AT := Vector3(-2.2, 0.0, 3.6)
const DAY_YAW := 0.30
const DAY_PLANK := Vector3(3.4, 0.92, 0.12)
const DAY_PLANK_Y := 1.26
const DAY_EM := 0.34
const ISLAND_EM := 0.19
const DAY_TEXT_X := -0.6
const DAY_MAX_W := 2.1

const GRASS := 190
const GRASS_SEED := 20260916

@export var day := 2
@export var island := "Birch Haven"

var _day: MeshInstance3D
var _island: MeshInstance3D

func _ready() -> void:
	for child in get_children():
		child.queue_free()
	_build_light()
	_build_camera()
	_build_ground()
	_build_props()
	_build_day_sign()
	_build_grass()

# --- the rig ---

## world/stage.gd's light, to the number: a preview lit any other way is a
## picture of a scene the game cannot draw.
func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff1dc")
	sun.light_energy = 0.46
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	sun.look_at_from_position(Vector3(3.0, 8.0, -6.0), Vector3.ZERO, Vector3.UP)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Pal.SKY_TOP
	sky_mat.sky_horizon_color = Pal.SKY_HORIZON
	sky_mat.ground_horizon_color = Pal.SKY_HORIZON
	# The valley's far haze rather than the island's sea: below the horizon
	# this preview looks at distant bank, not open water.
	sky_mat.ground_bottom_color = Pal.SKY_HORIZON
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Pal.AMBIENT
	env.ambient_light_energy = 0.115
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	var world_env := WorldEnvironment.new()
	world_env.name = "Env"
	world_env.environment = env
	add_child(world_env)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = CAM_FOV
	cam.current = true
	add_child(cam)
	cam.look_at_from_position(CAM_AT, CAM_LOOK, Vector3.UP)

# --- the ground ---

func _build_ground() -> void:
	add_child(Scenery.ground(GROUND, GROUND_AT, Pal.TURF))
	# The path, a hair proud of the turf so the two never fight for a pixel.
	var path := Scenery.ground(Vector3(PATH_W, 0.62, 24.0), PATH_AT, Pal.PLOT_SOIL)
	path.rotation.y = PATH_YAW
	add_child(path)
	# The river: the stage's own water, so it takes the same bands as the sea
	# round the island, running off to the right and toward the player.
	add_child(Scenery.water(Vector2(50.0, 70.0), Vector3(LAND_EDGE + 24.0, RIVER_Y, 2.0)))
	# The far bank, so the water reads as a river rather than an open sea:
	# a strip of turf out to the right with its own tree line on it.
	add_child(Scenery.ground(Vector3(24.0, 0.6, 46.0), Vector3(LAND_EDGE + 24.0, -0.3, -3.0), Pal.TURF))
	add_child(Scenery.deck(DOCK.position.x, DOCK.end.x, DOCK.position.y, DOCK.end.y))
	for z in [DOCK.position.y + 0.4, DOCK.end.y - 0.4]:
		add_child(Scenery.prop("pier_post", Vector3(DOCK.end.x - 0.3, RIVER_Y - 0.1, z), 0.0, Vector3(1.0, 0.55, 1.0)))

# --- the props ---

func _build_props() -> void:
	var scout := load("res://world/mascot.gd").new() as Node3D
	scout.name = "Scout"
	scout.position = SCOUT_AT
	scout.rotation.y = SCOUT_YAW
	scout.scale = Vector3.ONE * SCOUT_SCALE
	add_child(scout)

	var lantern := Scenery.prop("lantern", Vector3(-0.25, 0.0, 2.2), 0.0, Vector3.ONE * 0.85)
	Models.tint_named(lantern, "Glass", Pal.LAMPLIGHT)
	add_child(lantern)

	# The little hanging sign at the dock's far corner, re-lettered: its
	# modelled words are Code Break's, so that layer is hidden and three
	# lines of TextMesh stand on its paper instead (world/camp.gd's arrangement).
	add_child(_signpost())

	# The tent up the path, and behind it the tree line that hides the bank's
	# far edge.
	add_child(Scenery.prop("tent", Vector3(-1.4, 0.0, -4.6), 0.38, Vector3.ONE * 6.0))
	# Conifers with a round crown among them, so the line behind the camp is
	# not one repeated shape.
	var back := [[-12.0, -10.5, 5.4], [-8.6, -11.2, 6.0], [-5.4, -10.2, 5.0], [-2.2, -11.6, 5.6],
		[1.0, -10.4, 4.8], [4.2, -11.0, 5.2], [-15.0, -9.4, 4.6]]
	for i in back.size():
		var t: Array = back[i]
		add_child(Scenery.prop("camp_tree", Vector3(t[0], 0.0, t[1]), 0.7 * i, Vector3.ONE * float(t[2])))
	add_child(Scenery.prop("oak", Vector3(-10.4, 0.0, -9.0), 1.4, Vector3.ONE * 4.4))
	add_child(Scenery.prop("camp_tree", Vector3(-6.8, 0.0, -1.4), 1.1, Vector3.ONE * 4.4))
	# The far bank's own trees, small with the distance.
	for t in [[14.0, -2.0, 4.6], [17.5, -6.0, 5.2], [12.5, -8.5, 4.2], [21.0, 0.5, 4.8]]:
		add_child(Scenery.prop("camp_tree", Vector3(t[0], 0.0, t[1]), t[0], Vector3.ONE * float(t[2])))

	# The oak stands behind the day sign, whole and inside the frame: its crown
	# is leaf cards, and a card cut open by the top edge reads as shards rather
	# than as foliage, so it is sized to clear the edge instead of filling it.
	add_child(Scenery.prop("oak", Vector3(-5.8, 0.0, -3.0), 0.9, Vector3.ONE * 3.4))

	for b in [[1.2, 0.2, 0.4, 1.1], [-2.0, -1.8, 1.3, 0.9], [-4.6, 1.4, 2.1, 1.0], [-3.6, 8.2, 0.6, 0.9],
			[6.4, 5.6, 0.9, 1.3], [7.6, 1.8, 2.0, 0.9]]:
		add_child(Scenery.prop("boulder", Vector3(b[0], 0.0, b[1]), b[2], Vector3.ONE * float(b[3])))
	for b in [[-4.2, 2.4, 0.4, 1.8], [-1.8, -2.6, 1.1, 1.6], [-5.6, 0.4, 2.2, 1.4], [0.8, -0.8, 0.6, 1.3]]:
		add_child(Scenery.prop("bush", Vector3(b[0], 0.0, b[1]), b[2], Vector3.ONE * float(b[3])))
	for d in [[-1.6, 6.2], [-4.0, 5.0], [-0.9, 1.2], [-4.6, 3.0], [-3.0, 6.6], [-1.4, -1.0],
			[-2.4, 8.6], [-4.8, 7.8]]:
		add_child(Scenery.prop("daisy", Vector3(d[0], 0.0, d[1]), d[0] * 1.3, Vector3.ONE * 1.2))

	# The field's own painted cards: leaf sheets filling the gaps in the tree
	# line, blossoms over the grass in the front corners.
	for f in [[-9.0, -9.6, 0.34], [-4.4, -9.0, 0.30], [1.2, -9.4, 0.32]]:
		add_child(_card(FOLIAGE, CARD_FOLIAGE, Vector3(f[0], 0.0, f[1]), float(f[2])))
	var blossoms := [[-2.6, 5.4], [-3.4, 6.6], [-1.8, 7.2], [-5.0, 4.6], [-4.4, 6.4], [-2.2, 3.2],
		[-6.2, 5.4], [-1.9, 8.0], [-3.2, 2.0], [-6.6, 2.4], [-5.4, 7.4], [-4.0, 1.0]]
	for b in blossoms:
		add_child(_card(BLOSSOM, CARD_FLOWERS, Vector3(b[0], 0.0, b[1]), 0.6))

func _signpost() -> Node3D:
	var pivot := Scenery.prop("signpost", Vector3(5.4, 0.0, 3.4), -0.7, Vector3.ONE * 1.0)
	var model: Node3D = pivot.get_child(0)
	Models.set_layer_visible(model, "Sign_Words", false)
	var lines := ["A puzzle", "a brighter", "you"]
	for i in lines.size():
		var mi := Lettering.line(lines[i].to_upper(), 0.115, 0.012, Pal.TEXT, 700, HORIZONTAL_ALIGNMENT_CENTER, 0.002)
		mi.position = Vector3(0.2, 1.46 - 0.15 * i, 0.05)
		model.add_child(mi)
	return pivot

## One painted card, standing on the ground and turning to face the camera.
func _card(scene: PackedScene, mat: Material, at: Vector3, s: float) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.position = at
	node.scale = Vector3.ONE * s
	for mi in Models.meshes(node):
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

# --- the day sign ---

## A plank of the game's own wood, grained along its length (world/camp.gd).
static func _plank(size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.wood_material(Pal.PLAQUE, Vector3.RIGHT)
	Toon.add_outline(mi, Lettering.outline(Toon.line_color(Pal.PLAQUE), 0.008))
	return mi

func _build_day_sign() -> void:
	var sign_root := Node3D.new()
	sign_root.name = "DaySign"
	sign_root.position = DAY_AT
	sign_root.rotation.y = DAY_YAW
	add_child(sign_root)
	for x in [-1.25, 1.25]:
		sign_root.add_child(Scenery.prop("post", Vector3(x, 0.0, 0.0), 0.0, Vector3(0.7, 2.0, 0.7)))
	var plank := _plank(DAY_PLANK)
	plank.position = Vector3(0.0, DAY_PLANK_Y, 0.0)
	sign_root.add_child(plank)
	var face := DAY_PLANK.z * 0.5
	_day = Lettering.line("", DAY_EM, 0.03, Pal.SURFACE, 700, HORIZONTAL_ALIGNMENT_LEFT, 0.006)
	_day.position = Vector3(DAY_TEXT_X, DAY_PLANK_Y + 0.16, face + 0.015)
	sign_root.add_child(_day)
	_island = Lettering.line("", ISLAND_EM, 0.02, Pal.SURFACE_HI, 700, HORIZONTAL_ALIGNMENT_LEFT, 0.006)
	_island.position = Vector3(DAY_TEXT_X, DAY_PLANK_Y - 0.19, face + 0.01)
	sign_root.add_child(_island)
	# The emblem: a conifer standing on the plank's lower edge.
	sign_root.add_child(Scenery.prop("camp_tree", Vector3(-1.15, DAY_PLANK_Y - DAY_PLANK.y * 0.5 + 0.03, face + 0.02), 0.0, Vector3.ONE * 0.9))
	Lettering.fit(_day, ("Day %d" % day).to_upper(), DAY_EM, DAY_MAX_W)
	Lettering.fit(_island, island.to_upper(), ISLAND_EM, DAY_MAX_W)

# --- the grass ---

## The field as one MultiMesh: tufts of baked strands scattered over the turf,
## kept off the path and off the dock. Sparse on purpose -- the bank reads as
## a lawn with grass standing up through it, not as a meadow gone to seed.
func _build_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRASS_SEED
	var transforms: Array[Transform3D] = []
	var guard := 0
	while transforms.size() < GRASS and guard < GRASS * 40:
		guard += 1
		var x := rng.randf_range(-9.0, LAND_EDGE - 0.3)
		var z := rng.randf_range(-8.0, 9.4)
		# The path is turned, so the keep-off test turns with it.
		var along := Vector2(x, z) - Vector2(PATH_AT.x, PATH_AT.z)
		if absf(along.rotated(-PATH_YAW).x) < PATH_W * 0.5 + 0.25:
			continue
		if Rect2(DOCK.position - Vector2(0.4, 0.4), DOCK.size + Vector2(0.8, 0.8)).has_point(Vector2(x, z)):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.55, 1.0))
		transforms.append(Transform3D(basis, Vector3(x, 0.0, z)))
	add_child(Scenery.scatter("grass_patch", transforms))
