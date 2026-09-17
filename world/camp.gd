@tool
extends Node3D

## The first screen's campsite: the diorama the menu's cards float over,
## staged the way the concept banner frames it. The scout stands on the dock
## reading his map with the river behind him, the day sign stands lettered on
## the grass at the left, the lantern at his feet, the path comes down from
## the tent and sweeps across the picture, the tree line and an oak close the
## back, and the little "A puzzle a brighter you" board hangs at the dock's
## far corner. Every prop is a library model (core/models.gd) placed here, so
## the camp is lit, shaded and outlined like a board, and the fence-and-sign
## diorama that closes the screen at the bottom is placed against the camera
## each fit so it always sits along the frame's bottom edge.
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
## Its centre is where the camera aims: the scout's chest, so the sign's plank
## and his feet fall in the lower half under the title and motto, and the tent
## and the tree line get the top. Measured off the banner: the frame is about
## ten units wide at their plane, the sign's plank a third of it, the scout
## two thirds of its height.
const HERO_CENTRE := Vector3(0.75, 1.5, 4.9)
const HERO_SIZE := Vector3(9.4, 4.1, 0.6)

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
## Where the near bank turns right to close the water off under the camera.
const FRONT_Z := 6.2

const SCOUT_AT := Vector3(2.3, 0.0, 4.9)
const SCOUT_YAW := -0.14
## A scout 1.07 tall at 1.0 is a small round animal; 2.6 makes him the
## banner's hero, as tall as the day sign beside him and two thirds of the
## frame, with the tent behind him still clearing his ears.
const SCOUT_SCALE := 2.6

## camp_sign.glb spans x -0.95..0.95 (docs/art/blender-contract.md).
const FOOTER_W := 1.9
## The diorama came with a lettered plank across two posts at x +-0.62; its
## baked lettering did not survive decimation, so the plank and the posts'
## tops were cut out of the mesh (art/camp_sign.blend) and a plank of the
## game's own wood is laid across the stubs here, lettered with TextMesh.
const FOOTER_PLANK := Vector3(1.5, 0.24, 0.1)
const FOOTER_PLANK_Y := 0.33
const FOOTER_EM := 0.08
const FOOTER_MAX_W := 1.34
const FOOTER_WORDS := "Pick one · Play · Come back tomorrow"
## Where in the footer slot the diorama's centre is aimed, and how much of
## the slot's height and width it may take: whichever binds sets its scale.
## The aim is where the diorama's *base* lands: it stands up from there, so
## the base goes near the slot's bottom edge and the fence rises into it.
const FOOTER_AIM := 0.92
const FOOTER_FILL_W := 0.72
const FOOTER_FILL_H := 0.7
const FOOTER_TALL := 0.45

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

const GRASS := 260
const GRASS_SEED := 20260916

var footer: Node3D
var day_sign: Node3D
var scout: Node3D
var _day: MeshInstance3D
var _island: MeshInstance3D
var _footer_words: MeshInstance3D

func _ready() -> void:
	name = "Camp"
	position = Vector3(0.0, LIFT, 0.0)
	_build_ground()
	_build_props()
	_build_day_sign()
	_build_grass()
	_build_footer()

## The box the menu frames in the top of the screen. In the stage anchor's
## space, so it carries the lift.
func hero_box() -> AABB:
	return AABB(HERO_CENTRE + Vector3(0.0, LIFT, 0.0) - HERO_SIZE * 0.5, HERO_SIZE)

func set_day(n: int, island: String) -> void:
	Lettering.fit(_day, ("Day %d" % n).to_upper(), DAY_EM, DAY_MAX_W)
	Lettering.fit(_island, island.to_upper(), ISLAND_EM, DAY_MAX_W)

# --- the ground ---

func _build_ground() -> void:
	add_child(Scenery.ground(GROUND, GROUND_AT, Pal.TURF))
	# The path, a hair proud of the turf so the two never fight for a pixel.
	var path := Scenery.ground(Vector3(PATH_W, 0.62, 24.0), PATH_AT, Pal.PLOT_SOIL)
	path.rotation.y = PATH_YAW
	add_child(path)
	# The river: the stage's own water, so a splash rings it, just under the
	# bank's top and running off to the right and toward the player.
	add_child(Scenery.water(Vector2(50.0, 70.0), Vector3(LAND_EDGE + 24.0, RIVER_Y, 2.0)))
	# The far bank, so the water reads as a river rather than an open sea:
	# a strip of turf out to the right with its own tree line on it.
	add_child(Scenery.ground(Vector3(24.0, 0.6, 46.0), Vector3(LAND_EDGE + 24.0, -0.3, -3.0), Pal.TURF))
	# The near bank turns right just past the dock's end, so the ground under
	# the camera -- what the shift lens shows below the cards, close and from
	# above -- is lawn rather than a hard bank edge and a river's foam lines.
	add_child(Scenery.ground(Vector3(14.0, 0.6, 20.0), Vector3(LAND_EDGE + 7.0, -0.3, FRONT_Z + 10.0), Pal.TURF))
	add_child(Scenery.deck(DOCK.position.x, DOCK.end.x, DOCK.position.y, DOCK.end.y))
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

	var lantern := Scenery.prop("lantern", Vector3(-0.1, 0.0, 5.6), 0.0, Vector3.ONE * 1.5)
	Models.tint_named(lantern, "Glass", Pal.LAMPLIGHT)
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
		add_child(Scenery.prop("camp_tree", Vector3(t[0], 0.0, t[1]), 0.7 * i, Vector3.ONE * float(t[2])))
	add_child(Scenery.prop("oak", Vector3(-10.4, 0.0, -9.0), 1.4, Vector3.ONE * 4.4))
	add_child(Scenery.prop("camp_tree", Vector3(-6.8, 0.0, -1.4), 1.1, Vector3.ONE * 4.4))
	# The far bank's own trees, small with the distance.
	for t in [[14.0, -2.0, 4.6], [17.5, -6.0, 5.2], [12.5, -8.5, 4.2], [21.0, 0.5, 4.8]]:
		add_child(Scenery.prop("camp_tree", Vector3(t[0], 0.0, t[1]), t[0], Vector3.ONE * float(t[2])))
	# The oak behind the day sign, whole and inside the frame: its crown is
	# leaf cards, and a card cut open by the top edge reads as shards rather
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

## The little hanging sign at the dock's far corner, re-lettered: its
## modelled words are Code Break's, so that layer is hidden and three lines
## of TextMesh stand on its paper instead. The paper is the model's
## `Sign_Paper` layer, measured off signpost.glb at x -0.23..0.63 and
## y 1.03..1.59 with its face at z 0.04, and the words sit a hair in front.
func _signpost() -> Node3D:
	var pivot := Scenery.prop("signpost", Vector3(4.5, 0.0, 5.7), -0.45, Vector3.ONE * 1.7)
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
		var x := rng.randf_range(-9.0, 7.0)
		var z := rng.randf_range(-8.0, 13.0)
		# Off the water: the bank's edge up to the dock's end, the turn past it.
		if x > LAND_EDGE - 0.3 and z < FRONT_Z + 0.3:
			continue
		# The path is turned, so the keep-off test turns with it.
		var along := Vector2(x, z) - Vector2(PATH_AT.x, PATH_AT.z)
		if absf(along.rotated(-PATH_YAW).x) < PATH_W * 0.5 + 0.25:
			continue
		if Rect2(DOCK.position - Vector2(0.4, 0.4), DOCK.size + Vector2(0.8, 0.8)).has_point(Vector2(x, z)):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.55, 1.0))
		transforms.append(Transform3D(basis, Vector3(x, 0.0, z)))
	add_child(Scenery.scatter("grass_patch", transforms))

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

func _build_footer() -> void:
	footer = Node3D.new()
	footer.name = "Footer"
	footer.visible = false
	add_child(footer)
	var diorama := Models.instance("camp_sign")
	footer.add_child(diorama)
	var plank := _plank(FOOTER_PLANK)
	plank.position = Vector3(0.0, FOOTER_PLANK_Y, 0.0)
	footer.add_child(plank)
	_footer_words = Lettering.line("", FOOTER_EM, 0.02, Pal.SURFACE, 700, HORIZONTAL_ALIGNMENT_CENTER, 0.004)
	_footer_words.position = Vector3(0.0, FOOTER_PLANK_Y, FOOTER_PLANK.z * 0.5 + 0.01)
	Lettering.fit(_footer_words, FOOTER_WORDS.to_upper(), FOOTER_EM, FOOTER_MAX_W)
	footer.add_child(_footer_words)

## Stands the fence diorama on the ground where `rect` (viewport pixels) looks,
## scaled to fit the rect, facing the camera. `rig` is the stage's camera rig:
## its rays and pixel sizes are asked for rather than Camera3D's, which are
## wrong under the shift lens the menu looks through. Call after every fit:
## the camera has moved and the ground under the frame's bottom edge with it.
func place_footer(rig: Node3D, rect: Rect2) -> void:
	if rig == null or rig.camera == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		footer.visible = false
		return
	var cam: Camera3D = rig.camera
	var ground := Plane(Vector3.UP, global_position.y)
	var aim := Vector2(rect.get_center().x, rect.position.y + rect.size.y * FOOTER_AIM)
	var hit_c = ground.intersects_ray(rig.ray_origin(aim), rig.ray_normal(aim))
	var left := Vector2(rect.position.x, aim.y)
	var right := Vector2(rect.end.x, aim.y)
	var hit_l = ground.intersects_ray(rig.ray_origin(left), rig.ray_normal(left))
	var hit_r = ground.intersects_ray(rig.ray_origin(right), rig.ray_normal(right))
	if hit_c == null or hit_l == null or hit_r == null:
		footer.visible = false
		return
	var centre := hit_c as Vector3
	var width: float = (hit_r as Vector3).distance_to(hit_l as Vector3)
	# The diorama squares up to the camera, tilting back as well as turning:
	# at the bottom of the shift lens's frame the ground is seen steeply and
	# close, and a diorama standing upright there shows the camera its grass
	# mounds from above and hides its fence. Seen square, it reads as the card
	# it is meant to be. Its size is measured along the camera's own up, since
	# that is the way its height now runs.
	var per_px: float = 1.0 / rig.pixels_per_unit_at(centre, cam.global_transform.basis.y)
	var by_width := width * FOOTER_FILL_W / FOOTER_W
	var by_height := rect.size.y * FOOTER_FILL_H * per_px / FOOTER_TALL
	footer.visible = true
	footer.global_position = centre
	footer.scale = Vector3.ONE * minf(by_width, by_height)
	# look_at points -Z at its target and the diorama's face is +Z.
	footer.look_at(centre - (cam.global_position - centre), Vector3.UP)
