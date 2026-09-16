extends Node3D

## The first screen's campsite: the diorama the menu's cards float over. A
## turf bank with a dirt path down it, the river on the right with a plank
## dock into it, the camper standing at the path's end with its lantern, a
## tent under the trees behind, and the day sign standing on the grass. Every
## prop is a library model (core/models.gd) placed here, so the camp is lit,
## shaded and outlined like a board, and the fence-and-sign diorama that
## closes the screen at the bottom is placed against the camera each fit so
## it always sits along the frame's bottom edge.
##
## The menu mounts one of these on the stage in place of a board and frames
## hero_box() in the top of the screen; the lettering on both signs is data
## (core/lettering.gd), never part of a model.

const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Toon = preload("res://core/toon.gd")
const Scenery = preload("res://world/scenery.gd")
const Lettering = preload("res://core/lettering.gd")

## How high the camp stands over the stage's origin. The backdrop's hills
## ring is a plateau at about y 1.4 (hills.glb's flat, measured), and the menu
## camera stands out over that ring where a board's never does, so a camp at
## y 0 has its feet and its fence buried in sage. Above the plateau, the camp
## reads as a raised terrace with the ring's flat as the lower ground around
## it.
const LIFT := 2.0
## The bank: from well left of the frame to just past the path, and from
## behind the tree line to under the camera, so the fence has turf to stand on.
const GROUND := Vector3(34.0, 0.6, 62.0)
const GROUND_AT := Vector3(-13.5, -0.3, 17.0)
const RIVER_Y := -0.5
const PATH_W := 2.6
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
const FOOTER_AIM := 0.55
const FOOTER_FILL_W := 0.72
const FOOTER_FILL_H := 0.8
const FOOTER_TALL := 0.45
## The day sign: two posts, a plank, the day and the island's name, and a
## conifer as its emblem.
const DAY_AT := Vector3(-4.7, 0.0, 4.8)
const DAY_PLANK := Vector3(3.6, 0.9, 0.1)
const DAY_PLANK_Y := 1.25
const DAY_EM := 0.36
const ISLAND_EM := 0.2
const DAY_TEXT_X := -0.75
const DAY_MAX_W := 2.4
const TUFTS := 160
const TUFT_SEED := 20260916

var footer: Node3D
var day_sign: Node3D
var _day: MeshInstance3D
var _island: MeshInstance3D
var _footer_words: MeshInstance3D

func _ready() -> void:
	name = "Camp"
	position = Vector3(0.0, LIFT, 0.0)
	_build_ground()
	_build_props()
	_build_day_sign()
	_build_footer()

## The box the menu frames in the top of the screen: the camp proper, from
## the tent to the dock, and as tall as the trees behind the tent. In the
## stage anchor's space, so it carries the lift.
func hero_box() -> AABB:
	return AABB(Vector3(-8.0, LIFT, -4.8), Vector3(12.4, 3.4, 10.6))

func set_day(n: int, island: String) -> void:
	Lettering.fit(_day, ("Day %d" % n).to_upper(), DAY_EM, DAY_MAX_W)
	Lettering.fit(_island, island.to_upper(), ISLAND_EM, DAY_MAX_W)

# --- the ground ---

func _build_ground() -> void:
	add_child(Scenery.ground(GROUND, GROUND_AT, Pal.TURF))
	# The path, a hair proud of the turf so the two never fight for a pixel.
	add_child(Scenery.ground(Vector3(PATH_W, 0.62, 56.0), Vector3(0.4, -0.29, 18.0), Pal.PLOT_SOIL))
	# The river: the stage's own water, so a splash rings it, just under the
	# bank's top and running off to the right and toward the player.
	add_child(Scenery.water(Vector2(40.0, 76.0), Vector3(23.0, RIVER_Y, 10.0)))
	# The dock into it, two strips wide, with its posts standing in the water.
	add_child(Scenery.deck(2.5, 6.5, -0.5, 1.5))
	for z in [-0.4, 1.4]:
		add_child(Scenery.prop("pier_post", Vector3(6.3, RIVER_Y - 0.1, z), 0.0, Vector3(1.0, 0.5, 1.0)))

# --- the props ---

func _build_props() -> void:
	add_child(Scenery.prop("mascot_camper", Vector3(1.7, 0.0, 3.8), 0.12, Vector3.ONE * 2.3))
	var lantern := Scenery.prop("lantern", Vector3(0.0, 0.0, 4.8), 0.0, Vector3.ONE * 1.25)
	Models.tint_named(lantern, "Glass", Pal.LAMPLIGHT)
	add_child(lantern)
	add_child(Scenery.prop("tent", Vector3(-4.4, 0.0, -3.0), 0.45, Vector3.ONE * 4.2))
	# The tree line behind the camp hides the bank's far edge.
	var back := [[-14.0, -9.2, 4.6], [-11.2, -10.0, 5.4], [-8.4, -9.4, 4.2], [-5.6, -10.2, 5.0],
		[-2.6, -9.6, 4.4], [0.4, -10.4, 5.2], [3.0, -9.0, 4.0]]
	for i in back.size():
		var t: Array = back[i]
		add_child(Scenery.prop("camp_tree", Vector3(t[0], 0.0, t[1]), 0.7 * i, Vector3.ONE * float(t[2])))
	add_child(Scenery.prop("camp_tree", Vector3(-7.6, 0.0, 0.8), 1.1, Vector3.ONE * 4.2))
	add_child(Scenery.prop("camp_tree", Vector3(-9.6, 0.0, 4.6), 2.3, Vector3.ONE * 3.6))
	for b in [[-2.6, -1.4, 0.4, 1.9], [2.9, -2.6, 1.3, 1.5], [-6.8, 5.0, 2.1, 1.3], [3.2, 4.6, 0.6, 1.1]]:
		add_child(Scenery.prop("boulder", Vector3(b[0], 0.0, b[1]), b[2], Vector3.ONE * float(b[3])))
	for b in [[-5.9, -0.6, 0.4, 2.2], [2.4, 4.0, 1.1, 1.7], [-3.4, 3.6, 2.2, 1.6], [-1.2, -4.0, 0.6, 2.0]]:
		add_child(Scenery.prop("bush", Vector3(b[0], 0.0, b[1]), b[2], Vector3.ONE * float(b[3])))
	for d in [[-2.0, 4.4], [-5.2, 2.2], [2.0, -0.9], [-7.4, 3.3], [0.9, 5.6], [-3.0, 0.6]]:
		add_child(Scenery.prop("daisy", Vector3(d[0], 0.0, d[1]), d[0] * 1.3, Vector3.ONE * 2.4))
	add_child(_signpost())
	add_child(_tufts())

## The little hanging sign by the water, re-lettered: its modelled words are
## Code Break's, so that layer is hidden and three lines of TextMesh stand on
## its paper instead. The paper is the model's `Sign_Paper` layer, measured
## off signpost.glb at x -0.23..0.63 and y 1.03..1.59 with its face at z 0.04,
## and the words sit a hair in front of it.
func _signpost() -> Node3D:
	var pivot := Scenery.prop("signpost", Vector3(3.4, 0.0, 5.0), -0.3, Vector3.ONE * 1.2)
	var model: Node3D = pivot.get_child(0)
	Models.set_layer_visible(model, "Sign_Words", false)
	var lines := ["A puzzle", "a brighter", "you"]
	for i in lines.size():
		var mi := Lettering.line(lines[i].to_upper(), 0.115, 0.012, Pal.TEXT, 700, HORIZONTAL_ALIGNMENT_CENTER, 0.002)
		mi.position = Vector3(0.2, 1.46 - 0.15 * i, 0.05)
		model.add_child(mi)
	return pivot

## Grass tufts over the bank as one MultiMesh, kept off the path.
func _tufts() -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = TUFT_SEED
	var transforms: Array[Transform3D] = []
	while transforms.size() < TUFTS:
		var x := rng.randf_range(-15.0, 3.2)
		var z := rng.randf_range(-8.0, 16.0)
		if absf(x - 0.4) < PATH_W * 0.5 + 0.3:
			continue
		var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.1, 1.7)), Vector3(x, 0.0, z))
		transforms.append(t)
	return Scenery.scatter("tuft", transforms)

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
	add_child(day_sign)
	for x in [-1.4, 1.4]:
		day_sign.add_child(Scenery.prop("post", Vector3(x, 0.0, 0.0), 0.0, Vector3(0.7, 2.1, 0.7)))
	var plank := _plank(DAY_PLANK)
	plank.position = Vector3(0.0, DAY_PLANK_Y, 0.0)
	day_sign.add_child(plank)
	var face := DAY_PLANK.z * 0.5
	_day = Lettering.line("", DAY_EM, 0.03, Pal.SURFACE, 700, HORIZONTAL_ALIGNMENT_LEFT, 0.006)
	_day.position = Vector3(DAY_TEXT_X, DAY_PLANK_Y + 0.17, face + 0.015)
	day_sign.add_child(_day)
	_island = Lettering.line("", ISLAND_EM, 0.02, Pal.SURFACE_HI, 700, HORIZONTAL_ALIGNMENT_LEFT, 0.006)
	_island.position = Vector3(DAY_TEXT_X, DAY_PLANK_Y - 0.2, face + 0.01)
	day_sign.add_child(_island)
	# The emblem: a conifer standing on the plank's lower edge.
	day_sign.add_child(Scenery.prop("camp_tree", Vector3(-1.3, DAY_PLANK_Y - DAY_PLANK.y * 0.5 + 0.03, face + 0.02), 0.0, Vector3.ONE * 0.95))
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
## scaled to fit the rect, facing `cam`. Call after every fit: the
## camera has moved and the ground under the frame's bottom edge with it.
func place_footer(cam: Camera3D, rect: Rect2) -> void:
	if cam == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		footer.visible = false
		return
	var ground := Plane(Vector3.UP, global_position.y)
	var aim := Vector2(rect.get_center().x, rect.position.y + rect.size.y * FOOTER_AIM)
	var hit_c = ground.intersects_ray(cam.project_ray_origin(aim), cam.project_ray_normal(aim))
	var left := Vector2(rect.position.x, aim.y)
	var right := Vector2(rect.end.x, aim.y)
	var hit_l = ground.intersects_ray(cam.project_ray_origin(left), cam.project_ray_normal(left))
	var hit_r = ground.intersects_ray(cam.project_ray_origin(right), cam.project_ray_normal(right))
	if hit_c == null or hit_l == null or hit_r == null:
		footer.visible = false
		return
	var centre := hit_c as Vector3
	var width: float = (hit_r as Vector3).distance_to(hit_l as Vector3)
	# World units per pixel where the diorama stands, so its height can be
	# held inside the slot as well as its width.
	var dist := cam.global_position.distance_to(centre)
	var vh := cam.get_viewport().get_visible_rect().size.y
	var per_px := 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) / maxf(vh, 1.0)
	var by_width := width * FOOTER_FILL_W / FOOTER_W
	var by_height := rect.size.y * FOOTER_FILL_H * per_px / FOOTER_TALL
	footer.visible = true
	footer.global_position = centre
	footer.scale = Vector3.ONE * minf(by_width, by_height)
	var to_cam: Vector3 = cam.global_position - centre
	footer.rotation.y = atan2(to_cam.x, to_cam.z)
