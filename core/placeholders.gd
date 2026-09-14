extends RefCounted

## Primitive stand-ins for every model slot, so the 3D boards render before a
## single Blender file exists. Each follows docs/art/blender-contract.md:
## one unit per cell, origin at the centre of the base, shared vertices so the
## outline hull closes. Square pieces are four-sided cylinder prisms turned
## 45 degrees, not BoxMesh: a BoxMesh has split flat normals and the hull
## would open at every corner.

const Toon = preload("res://core/toon.gd")
const Pal = preload("res://core/palette.gd")

## The tile is a cube standing on the platform, one state per face and every
## state on two opposite faces, so a quarter roll always brings the next state
## up. TILE_SIDE is the cube's side (its footprint and its height), TILE_HALF
## the distance from its centre to any face, and TILE_RISE how far its top
## face stands above the platform -- a full side, since the cube sits on top
## rather than hanging inside the stone. The trilon it replaced showed only
## its horizontal top face at the board camera's 68-degree pitch, so a cell
## read as a flat card; a cube's side walls face the camera and land in a
## different band of the toon ramp, which is what makes it read as an object.
const TILE_SIDE := 0.84
## Centre to any face. Bevelling shaves the cube's bounds but never moves its
## faces, so the game places the centre from this constant, not from the mesh.
const TILE_HALF := TILE_SIDE * 0.5
const TILE_RISE := TILE_SIDE
## The sun and moon are sunk into the cube's walls: EMBLEM_H thick, of which
## only EMBLEM_PROUD stands out of the face. Cells are a unit apart and the
## cube is 0.84 wide, so two facing inlays spend 0.03 of the 0.16 gap.
const EMBLEM_H := 0.05
const EMBLEM_PROUD := 0.015
## The slate slab on each moon face: a cube is already black on the side it is
## about to bring up, so a roll changes no colour. It covers the flat part of
## the face, inside the body's 0.024 bevel, and sits a hair off the stone.
const PANEL_H := 0.03
const PANEL_PROUD := 0.0015
const PLATFORM_H := 0.6
const RIM_H := 0.04

static func make(slot: String) -> Node3D:
	var root := Node3D.new()
	root.name = slot
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var color := Color.MAGENTA
	var height := 0.4
	var outline := true
	match slot:
		"tile":
			# The cube body, one surface the game tints by the state that is
			# up, plus the sun and moon inlaid the way art/tile.blend carries
			# them. The per-face vertices mean the outline hull opens along
			# the edges, which the Blender export avoids. Base at y = 0.
			mi.mesh = _cube()
			root.add_child(mi)
			_add_inlays(root)
			Toon.apply_to(root)
			return root
		"rim_edge":
			# Moss strip along one cell of the platform lip: 1 along X, 0.5 along Z,
			# outward side at +Z. Flat, so a BoxMesh is fine here.
			var strip := BoxMesh.new()
			strip.size = Vector3(1.0, RIM_H, 0.5)
			mi.mesh = strip
			color = Pal.MOSS
			height = RIM_H
			outline = false
		"rim_corner":
			# Moss square on a platform corner, outward corner at +X +Z.
			var square := BoxMesh.new()
			square.size = Vector3(0.5, RIM_H, 0.5)
			mi.mesh = square
			color = Pal.MOSS
			height = RIM_H
			outline = false
		"platform":
			# Unit slab; the board scales it to (cols + 1, 1, rows + 1).
			var box := BoxMesh.new()
			box.size = Vector3(1.0, PLATFORM_H, 1.0)
			mi.mesh = box
			color = Pal.ROCK
			height = PLATFORM_H
			outline = false
		"water":
			var plane := PlaneMesh.new()
			plane.size = Vector2(60.0, 60.0)
			mi.mesh = plane
			color = Pal.WATER
			height = 0.0
			outline = false
		_:
			# Unknown slot: a small magenta block so the gap is obvious on screen.
			mi.mesh = _prism(0.2, 0.4)
	mi.position.y = height * 0.5
	mi.set_surface_override_material(0, Toon.material(color))
	if outline:
		Toon.add_outline(mi)
	root.add_child(mi)
	return root

## The tile cube, base at y = 0, centred on X and Z. One surface named
## `Stone`, like the export: the game tints the whole cube by the state that
## is up, because a cube that rotates cannot keep a colour on one face -- a
## moon face lands on the front wall while an empty face is up.
static func _cube() -> ArrayMesh:
	var s := TILE_HALF
	var h := TILE_SIDE
	# Corners, named bottom/top then left/right and far/near.
	var bfl := Vector3(-s, 0.0, -s)
	var bfr := Vector3(s, 0.0, -s)
	var bnr := Vector3(s, 0.0, s)
	var bnl := Vector3(-s, 0.0, s)
	var tfl := Vector3(-s, h, -s)
	var tfr := Vector3(s, h, -s)
	var tnr := Vector3(s, h, s)
	var tnl := Vector3(-s, h, s)
	var mesh := ArrayMesh.new()
	_surface(mesh, "Stone", Pal.STONE, [
		[[tfl, tfr, tnr, tnl], Vector3.UP],        # empty, up
		[[bfl, bfr, bnr, bnl], Vector3.DOWN],      # empty, down
		[[bnl, bnr, tnr, tnl], Vector3.BACK],      # sun, toward the player
		[[bfl, bfr, tfr, tfl], Vector3.FORWARD],   # sun, away
		[[bfr, bnr, tnr, tfr], Vector3.RIGHT],     # moon, right
		[[bfl, bnl, tnl, tfl], Vector3.LEFT],      # moon, left
	])
	return mesh


## The sun and moon sunk into the cube's walls, each state on an opposite
## pair: the sun on the near and far faces, the moon on the left and right,
## the top and bottom left bare for the empty state. Plain discs stand in for
## the modelled emblems -- the placeholder only has to say which state is up.
static func _add_inlays(root: Node3D) -> void:
	var centre := Vector3(0.0, TILE_HALF, 0.0)
	var depth := TILE_HALF + EMBLEM_PROUD - EMBLEM_H * 0.5
	# A cylinder stands on +Y, so each inlay turns that axis onto its face.
	var inlays := [
		["Sun", Pal.SUN, 0.22, Vector3.BACK, Basis(Vector3.RIGHT, PI * 0.5)],
		["Sun", Pal.SUN, 0.22, Vector3.FORWARD, Basis(Vector3.RIGHT, -PI * 0.5)],
		["Moon", Pal.MOON, 0.18, Vector3.RIGHT, Basis(Vector3.BACK, -PI * 0.5)],
		["Moon", Pal.MOON, 0.18, Vector3.LEFT, Basis(Vector3.BACK, PI * 0.5)],
	]
	# The slate slab under each crescent goes on first, so the crescent that
	# shares its face is drawn over it rather than buried in it.
	# Covers the flat part of the face, inside the export's 0.024 bevel. A
	# BoxMesh is fine here where it is not for the cube: the slab carries no
	# outline, so its split flat normals open no hull. Axis-aligned, so it
	# needs no turn and its AABB stays tight for Models.height.
	var panel := (TILE_HALF - 0.024) * 2.0
	for n in [Vector3.RIGHT, Vector3.LEFT]:
		var slab := BoxMesh.new()
		slab.size = Vector3(PANEL_H, panel, panel)
		var slab_mat := StandardMaterial3D.new()
		slab_mat.resource_name = "Slate_flat"
		slab_mat.albedo_color = Pal.SLATE
		slab.material = slab_mat
		var slab_mi := MeshInstance3D.new()
		slab_mi.name = "Slate_%s" % ("right" if n == Vector3.RIGHT else "left")
		slab_mi.mesh = slab
		slab_mi.position = centre + n * (TILE_HALF + PANEL_PROUD - PANEL_H * 0.5)
		root.add_child(slab_mi)
	for i in inlays.size():
		var inlay: Array = inlays[i]
		var mesh := _cylinder(inlay[2], EMBLEM_H, 24)
		# On the mesh, not as an override: Toon.apply_to and Models.tint_named
		# both read the surface material's name, as they do on the export.
		var mat := StandardMaterial3D.new()
		mat.resource_name = inlay[0]
		mat.albedo_color = inlay[1]
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.name = "%s_%d" % [inlay[0], i]
		mi.mesh = mesh
		mi.basis = inlay[4]
		mi.position = centre + (inlay[3] as Vector3) * depth
		root.add_child(mi)

## One surface holding the given faces, each a [points, normal] pair wound so
## its normal faces the front.
static func _surface(mesh: ArrayMesh, name: String, color: Color, faces: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var pts: Array = face[0]
		var nrm: Vector3 = face[1]
		# Godot's front faces wind clockwise seen from outside, so the
		# cross product of a front-facing triangle points against the normal.
		var cross: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0])
		if cross.dot(nrm) > 0.0:
			pts = pts.duplicate()
			pts.reverse()
		for i in range(1, pts.size() - 1):
			for v in [pts[0], pts[i], pts[i + 1]]:
				st.set_normal(nrm)
				st.add_vertex(v)
	st.commit(mesh)
	var mat := StandardMaterial3D.new()
	mat.resource_name = name
	mat.albedo_color = color
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)

## Square prism of half-width `half` and height `h`, built as a four-sided
## cylinder so the side vertices are shared. Rotate 45 degrees to align faces.
static func _prism(half: float, h: float) -> CylinderMesh:
	return _cylinder(half * sqrt(2.0), h, 4)

static func _cylinder(radius: float, h: float, segments: int) -> CylinderMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = h
	cyl.radial_segments = segments
	cyl.rings = 0
	return cyl
