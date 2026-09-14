extends RefCounted

## Primitive stand-ins for every model slot, so the 3D boards render before a
## single Blender file exists. Each follows docs/art/blender-contract.md:
## one unit per cell, origin at the centre of the base, shared vertices so the
## outline hull closes. Square pieces are four-sided cylinder prisms turned
## 45 degrees, not BoxMesh: a BoxMesh has split flat normals and the hull
## would open at every corner.

const Toon = preload("res://core/toon.gd")
const Pal = preload("res://core/palette.gd")

## The tile is a trilon: an equilateral three-sided prism lying along X with
## one face up. TILE_SIDE is the width of each face across the axis, TILE_LEN
## its length along the axis, TILE_H the prism's height (side * sqrt(3) / 2),
## and TILE_RISE how far the flat face stands above the platform at rest. The
## rest of the prism hangs inside the platform, hidden by its top surface.
const TILE_SIDE := 0.84
const TILE_LEN := 0.94
const TILE_H := TILE_SIDE * 0.8660254037844386
## Axis to any face. Bevelling shaves the prism's bounds but never moves its
## faces, so the game places the axis from this constant, not from the mesh.
const TILE_APOTHEM := TILE_H / 3.0
## At 0.12 the sun's ray tips on the near slope sit about 5 mm under the
## platform top, hidden only because that slope faces away from a camera
## pitched steeper than 60 degrees. A bigger sun, a lower camera or a smaller
## rise would show ray tips through the stone.
const TILE_RISE := 0.12
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
			# Named surfaces so the game can colour each face apart; the
			# per-face vertices mean the outline hull opens along the edges,
			# which the Blender export avoids. Base (the apex edge) at y = 0.
			mi.mesh = _trilon()
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

## Three-sided prism along X, flat face up, apex edge at y = 0, one surface
## per face: Face_Empty on top, Face_Sun sloping down toward +Z (the player),
## Face_Moon toward -Z, Cap for both triangular ends.
static func _trilon() -> ArrayMesh:
	var hl := TILE_LEN * 0.5
	var hs := TILE_SIDE * 0.5
	var a0 := Vector3(-hl, 0.0, 0.0)
	var a1 := Vector3(hl, 0.0, 0.0)
	var n0 := Vector3(-hl, TILE_H, hs)
	var n1 := Vector3(hl, TILE_H, hs)
	var f0 := Vector3(-hl, TILE_H, -hs)
	var f1 := Vector3(hl, TILE_H, -hs)
	var slope := Vector3(0.0, -0.5, 0.8660254037844386)
	var mesh := ArrayMesh.new()
	_surface(mesh, "Face_Empty", Pal.STONE, [[f0, f1, n1, n0]], Vector3.UP)
	_surface(mesh, "Face_Sun", Pal.STONE, [[a0, a1, n1, n0]], slope)
	_surface(mesh, "Face_Moon", Pal.SLATE, [[a0, a1, f1, f0]], Vector3(0.0, slope.y, -slope.z))
	_surface(mesh, "Cap", Pal.STONE, [[a1, n1, f1], [a0, n0, f0]], Vector3.ZERO)
	return mesh

## One surface holding the given polygons, each wound so `normal` (or, for
## ZERO, the polygon's own outward direction along X) faces the front.
static func _surface(mesh: ArrayMesh, name: String, color: Color, polys: Array, normal: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in polys:
		var pts: Array = poly
		var nrm := normal
		if nrm == Vector3.ZERO:
			nrm = Vector3.RIGHT if pts[0].x > 0.0 else Vector3.LEFT
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
