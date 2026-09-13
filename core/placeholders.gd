extends RefCounted

## Primitive stand-ins for every model slot, so the 3D boards render before a
## single Blender file exists. Each follows docs/art/blender-contract.md:
## one unit per cell, origin at the centre of the base, shared vertices so the
## outline hull closes. Square pieces are four-sided cylinder prisms turned
## 45 degrees, not BoxMesh: a BoxMesh has split flat normals and the hull
## would open at every corner.

const Toon = preload("res://core/toon.gd")
const Pal = preload("res://core/palette.gd")

const TILE_H := 0.12
const TOKEN_H := 0.18

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
			mi.mesh = _prism(0.46, TILE_H)
			mi.rotation.y = PI / 4.0
			color = Pal.SURFACE
			height = TILE_H
		"token_circle":
			mi.mesh = _cylinder(0.30, TOKEN_H, 32)
			color = Pal.ACCENT
			height = TOKEN_H
		"token_square":
			mi.mesh = _prism(0.25, TOKEN_H)
			mi.rotation.y = PI / 4.0
			color = Pal.ACCENT_2
			height = TOKEN_H
		"given_ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.38
			torus.outer_radius = 0.44
			torus.rings = 48
			torus.ring_segments = 12
			mi.mesh = torus
			color = Pal.TEXT_DIM
			height = torus.outer_radius - torus.inner_radius
		"table":
			var box := BoxMesh.new()
			box.size = Vector3(14.0, 0.4, 14.0)
			mi.mesh = box
			color = Pal.WOOD
			height = 0.4
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
