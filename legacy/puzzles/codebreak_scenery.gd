extends RefCounted

## Code Break's surroundings: the plank dock the board is laid on, and the
## bank, river and props around it. Pure node building from world/scenery.gd
## and the model library; the board animates what this returns.
## Spec: docs/superpowers/specs/2026-09-15-codebreak-screen-design.md, sections 0 to 3.

const Pal = preload("res://core/palette.gd")
const Models = preload("res://legacy/core/models.gd")
const Platform = preload("res://legacy/core/platform.gd")
const Placeholders = preload("res://legacy/core/placeholders.gd")
const Scenery = preload("res://legacy/world/scenery.gd")

## How far the deck runs past the moss rim: one cell each side, one at the
## far end for the pier posts, two at the near end under the tray.
const DECK_APRON := 1.0
const DECK_FAR := 1.0
const DECK_NEAR := 2.0

## The rim and the deck as one node: the dock the entrance raises.
static func dock(cols: int, rows: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Dock"
	root.add_child(Platform.build(cols, rows, ""))
	var hx := cols * 0.5 + Platform.LIP + DECK_APRON
	var hz := rows * 0.5 + Platform.LIP
	root.add_child(Scenery.deck(-hx, hx, -hz - DECK_FAR, hz + DECK_NEAR))
	return root

# --- the bank, the river and the props (spec section 2) ---

## The turf bank the dock is laid on, 0.1 below the deck's underside, and the
## river beyond its far edge.
const BANK_TOP := -0.7
const BANK_BOTTOM := -1.8
const BANK_WIDTH := 40.0
const BANK_NEAR_END := 16.0
const BANK_FAR_END := -30.0
const RIVER_Y := -1.4
const RIVER_NEAR := -5.8   # the near bank ends here, 0.2 short of the deck's far edge
const RIVER_FAR := -10.0   # the far bank starts here
const RIVER_SIZE := 40.0
## Pier posts stand in the river under the deck's far edge, clear of every
## lid's slide path at both board widths.
const POST_Z := -5.7
const POST_Y := -1.6
const POSTS_X := [-3.8, -2.7, 2.7, 3.8]
## The prop tables are laid for a five-column board; wider boards push every
## x outward by half a unit per extra column.
const REF_COLS := 5
## [x, z, yaw, scale] per boulder; two of them are seats.
const BOULDERS := [
	[-4.4, -4.6, 0.3, 1.3], [-5.3, -3.4, 1.2, 0.9], [-4.6, 0.5, 2.0, 1.0],
	[-4.5, 2.8, 0.7, 1.5], [-5.4, 4.6, 2.6, 1.1],
	[4.9, -3.2, -0.4, 1.4], [5.5, -4.6, 1.7, 1.0], [4.4, -0.6, 0.9, 1.2],
	[4.5, 1.8, 2.3, 1.6], [5.3, 4.2, 0.2, 0.9],
]
const SEAT_LANTERN := 2   # index into BOULDERS
const SEAT_POM := 5       # index into BOULDERS; flattened to 0.7 of its height
const SEAT_POM_FLAT := 0.7
const BUSHES := [
	[-5.6, -5.4, 0.4, 1.2], [5.8, -5.3, 1.1, 1.1], [-5.6, -1.4, 2.2, 1.0],
	[5.9, 0.6, 0.6, 1.3], [-5.2, 6.2, 1.5, 1.4], [5.4, 6.4, 2.8, 1.3],
]
const DAISIES := [
	[-4.3, -2.0, 0.0, 1.0], [-4.3, 1.6, 0.8, 1.2], [-5.0, 3.6, 1.6, 1.0],
	[4.3, -1.9, 0.4, 1.1], [4.2, 0.7, 1.2, 1.0], [4.9, 3.2, 2.0, 1.2],
]
const SIGN := [-4.7, -2.5, 0.44, 1.0]
const LANTERN_SCALE := 1.5
const POM_SCALE := 1.2
const POM_YAW := -0.52   # about 30 degrees, face toward the board on its left
const TUFT_COUNT := 200
const TUFT_SEED := 20260915

## Everything around the dock: the banks and river, the props in entrance
## order, and POM. `cols` widens the prop tables for the five-slot board.
## `pom_rest_y` comes back with the rest because only this table knows how
## high POM's seat stands: the lantern's boulder is read the same way.
static func build(cols: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Scenery"
	var props: Array[Node3D] = []
	var dx := (cols - REF_COLS) * 0.5

	var bank_h := BANK_TOP - BANK_BOTTOM
	var bank_y := (BANK_TOP + BANK_BOTTOM) * 0.5
	root.add_child(Scenery.ground(Vector3(BANK_WIDTH, bank_h, BANK_NEAR_END - RIVER_NEAR),
		Vector3(0.0, bank_y, (BANK_NEAR_END + RIVER_NEAR) * 0.5), Pal.BANK))
	var far := Scenery.ground(Vector3(BANK_WIDTH, bank_h, RIVER_FAR - BANK_FAR_END),
		Vector3(0.0, bank_y, (RIVER_FAR + BANK_FAR_END) * 0.5), Pal.BANK)
	far.name = "FarBank"
	root.add_child(far)
	root.add_child(Scenery.water(Vector2(RIVER_SIZE, RIVER_SIZE), Vector3(0.0, RIVER_Y, 0.0)))
	root.add_child(Scenery.scatter("tuft", _tuft_transforms(cols)))

	for x in POSTS_X:
		props.append(_prop(root, "pier_post", Vector3(_spread(x, dx), POST_Y, POST_Z), 0.0, 1.0))
	for i in BOULDERS.size():
		var b: Array = BOULDERS[i]
		var scale := Vector3.ONE * float(b[3])
		if i == SEAT_POM:
			scale.y *= SEAT_POM_FLAT
		props.append(_prop(root, "boulder", Vector3(_spread(b[0], dx), BANK_TOP, b[1]), b[2], 1.0, scale))
	for b in BUSHES:
		props.append(_prop(root, "bush", Vector3(_spread(b[0], dx), BANK_TOP, b[1]), b[2], b[3]))
	for d in DAISIES:
		props.append(_prop(root, "daisy", Vector3(_spread(d[0], dx), BANK_TOP, d[1]), d[2], d[3]))
	var lantern_seat: Array = BOULDERS[SEAT_LANTERN]
	var lantern := _prop(root, "lantern",
		Vector3(_spread(lantern_seat[0], dx), BANK_TOP + Placeholders.BOULDER_H * float(lantern_seat[3]), lantern_seat[1]),
		0.6, LANTERN_SCALE)
	Models.tint_named(lantern.get_child(0), "Glass", Pal.SUN)
	props.append(lantern)
	props.append(_prop(root, "signpost", Vector3(_spread(SIGN[0], dx), BANK_TOP, SIGN[1]), SIGN[2], SIGN[3]))

	# A boulder's top at scale s is BANK_TOP + BOULDER_H * s, and POM's seat is
	# flattened as well as scaled, so both factors have to be read off the
	# table -- with the scale alone POM sank 0.168 into the rock.
	var seat: Array = BOULDERS[SEAT_POM]
	var pom_rest_y := BANK_TOP + Placeholders.BOULDER_H * float(seat[3]) * SEAT_POM_FLAT
	var pom: Node3D = null
	if Models.has_model("mascot_pom"):
		pom = _prop(root, "mascot_pom", Vector3(_spread(seat[0], dx), pom_rest_y, seat[1]), POM_YAW, POM_SCALE)
	return {"root": root, "props": props, "pom": pom, "pom_rest_y": pom_rest_y}

## Pushes an x outward for a wider board: props keep their distance from the
## deck's edge, not from the origin.
static func _spread(x: float, dx: float) -> float:
	return x + signf(x) * dx

static func _prop(root: Node3D, slot: String, at: Vector3, yaw: float, scale: float, scale3 := Vector3.ZERO) -> Node3D:
	var s := scale3 if scale3 != Vector3.ZERO else Vector3.ONE * scale
	var pivot := Scenery.prop(slot, at, yaw, s)
	root.add_child(pivot)
	return pivot

## Where the tufts stand: a seeded scatter over both banks, never under the
## deck or its shadow line, varied in yaw and size. The seed is fixed so the
## meadow is the same every day.
static func _tuft_transforms(cols: int) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = TUFT_SEED
	var hx := cols * 0.5 + Platform.LIP + DECK_APRON + 0.25
	var out: Array[Transform3D] = []
	while out.size() < TUFT_COUNT:
		var far_bank := rng.randf() < 0.15
		var x := rng.randf_range(-7.0, 7.0)
		var z := rng.randf_range(RIVER_FAR - 1.6, RIVER_FAR - 0.2) if far_bank else rng.randf_range(RIVER_NEAR + 0.2, 9.0)
		if not far_bank and absf(x) < hx and z < 7.4:
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3))
		out.append(Transform3D(basis, Vector3(x, BANK_TOP, z)))
	return out
