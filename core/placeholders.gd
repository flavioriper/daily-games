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
const EMBLEM_H := 0.05
const PLATFORM_H := 0.6
const RIM_H := 0.04
## The focus ring: a flat square frame around one cell (polish spec, section 6).
const FOCUS_OUTER := 0.46
const FOCUS_INNER := 0.38

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
			# One surface the game tints by the state that is up; the
			# per-face vertices mean the outline hull opens along the edges,
			# which the Blender export avoids. Base at y = 0.
			mi.mesh = _cube()
			root.add_child(mi)
			Toon.apply_to(root)
			return root
		"emblem_sun":
			mi.mesh = _cylinder(0.22, EMBLEM_H, 32)
			color = Pal.SUN
			height = EMBLEM_H
		"emblem_moon":
			mi.mesh = _cylinder(0.18, EMBLEM_H, 32)
			color = Pal.MOON
			height = EMBLEM_H
		"empty_mark":
			# A four-sided prism left unrotated reads as a small diamond.
			mi.mesh = _prism(0.07, 0.03)
			color = Pal.MARK
			height = 0.03
			outline = false
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
		"focus_ring":
			# Flat frame of four top-facing quads, one draw call, no thickness:
			# it is light on the stone, not a piece. Unshaded, translucent,
			# no outline, never tinted. Models._dress gives it its material.
			mi.mesh = _ring_mesh(FOCUS_OUTER, FOCUS_INNER)
			root.add_child(mi)
			return root
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

## Translucent unshaded material for the focus ring. A fresh instance each
## call, so a ring can tween its alpha without touching another ring.
static func focus_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(Pal.FOCUS, 0.9)
	return m

## Four bars of a square frame as top-facing quads on y = 0. Godot front
## faces wind clockwise seen from the front, so seen from above (x right,
## z down) each quad goes x0z0, x1z0, x1z1, x0z1.
static func _ring_mesh(outer: float, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bars := [
		[-outer, outer, -outer, -inner],   # far bar
		[-outer, outer, inner, outer],     # near bar
		[-outer, -inner, -inner, inner],   # left bar
		[inner, outer, -inner, inner],     # right bar
	]
	for b in bars:
		var p := [Vector3(b[0], 0.0, b[2]), Vector3(b[1], 0.0, b[2]), Vector3(b[1], 0.0, b[3]), Vector3(b[0], 0.0, b[3])]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for i in tri:
				st.set_normal(Vector3.UP)
				st.add_vertex(p[i])
	return st.commit()
