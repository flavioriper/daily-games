extends RefCounted

## Primitive stand-ins for every model slot, so the 3D boards render before a
## single Blender file exists. Each follows docs/art/blender-contract.md:
## one unit per cell, origin at the centre of the base, shared vertices so the
## outline hull closes. Square pieces are four-sided cylinder prisms turned
## 45 degrees, not BoxMesh: a BoxMesh has split flat normals and the hull
## would open at every corner.

const Toon = preload("res://core/toon.gd")
const Pal = preload("res://core/palette.gd")
const Shapes = preload("res://core/shapes.gd")

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

## Code Break pieces (codebreak spec, section 1). The socket is a slab with a
## well disc laid proud on top; the peg an ellipsoid dome with its pip mark on
## the crown; the pip a well disc with a ball in it; the lid a slab with a knob.
const SOCKET_SIDE := 0.94
const SOCKET_H := 0.12
const WELL_R := 0.3
const WELL_PROUD := 0.0015
const PEG_R := 0.3
const PEG_H := 0.44
const MARK_R := 0.035
## A pip is a disc rotated onto the dome's outward normal and centred on the
## surface, MARK_THICK thick, so half of it stands proud and half is buried:
## the tile's inlay treatment, which keeps an off-centre pip a full circle
## instead of the crescent a flat disc laid on a sloping crown becomes.
const MARK_THICK := 0.012
const MARK_SPREAD := 0.11
const PIP_WELL_R := 0.1
const PIP_R := 0.08
const LID_H := 0.16
const KNOB_R := 0.09
const KNOB_H := 0.08

## Pipes pieces (pipes spec, section 1). A pad is a bevelled slab; a pipe is a
## hub with an arm to each opening, each arm two shell segments with a real
## hole between two collars, and one water tube running the whole length that
## shows through that hole and at every open mouth; the valve is a bolted ring
## laid on the pad around the hub.
const PAD_SIDE := 0.94
const PAD_H := 0.12
const TUBE_R := 0.15
## The tube's axis, in the piece's own space. It sits at the collar radius,
## not the tube radius, so the flange rings rest exactly on y = 0 and the
## pipe is carried 0.025 clear of the pad on them. Putting the axis at
## TUBE_R instead would sink every collar 0.025 into the pad and break the
## contract's base-at-y=0 rule.
const TUBE_Y := 0.175
## Two thousandths short of the cell edge, so the contract's 1 x 1 footprint
## check has no float-rounding argument with a rotated cylinder's end cap. The
## 0.004 left between two facing mouths is well under a pixel on the board.
const ARM_LEN := 0.498
## The hub ball matches the tube, so the joint is a clean rounded corner and
## its lowest point is the tube's.
const HUB_R := TUBE_R
## The sight hole runs from GAP_IN to GAP_OUT along every arm.
const GAP_IN := 0.20
const GAP_OUT := 0.32
const COLLAR_R := 0.175
const COLLAR_W := 0.06
const MOUTH_AT := 0.468
const CORE_R := 0.115
const VALVE_IN := 0.20
const VALVE_OUT := 0.30
## A torus of that inner and outer radius stands (outer - inner) tall.
const VALVE_H := VALVE_OUT - VALVE_IN
const BOLT_R := 0.035
const BOLT_AT := 0.36    # bolt centres, on the pad diagonals, clear of the ring
const BOLT_PROUD := 0.0015
## Direction bits, the same 1=up 2=right 4=down 8=left as puzzles/pipes_gen.gd.
## Kept here so the placeholders need not preload a puzzle script.
const BIT_UP := 1
const BIT_RIGHT := 2
const BIT_DOWN := 4
const BIT_LEFT := 8
## The yaw that turns the reference arm (pointing at -Z, the UP bit) onto each
## direction. Same convention as the board's own rotation: clockwise on screen
## is negative about +Y.
const ARM_YAW := {BIT_UP: 0.0, BIT_RIGHT: -PI * 0.5, BIT_DOWN: PI, BIT_LEFT: PI * 0.5}

static func make(slot: String) -> Node3D:
	# The Code Break pieces are assemblies with a layer per material, built
	# before the single-mesh slots below allocate their node and mesh.
	match slot:
		"socket": return _socket()
		"peg": return _peg()
		"pip": return _pip()
		"lid": return _lid()
		"pipe_pad": return _pad()
		"pipe_cap": return _pipe("pipe_cap", BIT_UP)
		"pipe_straight": return _pipe("pipe_straight", BIT_UP | BIT_DOWN)
		"pipe_elbow": return _pipe("pipe_elbow", BIT_UP | BIT_RIGHT)
		"pipe_tee": return _pipe("pipe_tee", BIT_UP | BIT_RIGHT | BIT_DOWN)
		"pipe_cross": return _pipe("pipe_cross", BIT_UP | BIT_RIGHT | BIT_DOWN | BIT_LEFT)
		"valve": return _valve()
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

# --- Code Break pieces ---

## A mesh instance carrying one layer: `mesh` with a material named
## `mat_name` set on the mesh itself, where Toon.apply_to, Models.tint_named
## and Models.surface_names read it, as they do on an export.
static func _layer(node_name: String, mesh: Mesh, mat_name: String, colour: Color, at: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = mat_name
	mat.albedo_color = colour
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	else:
		(mesh as ArrayMesh).surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = at
	return mi

## Stone slab with a well disc on top. The feedback slab is this with the
## well hidden.
static func _socket() -> Node3D:
	var root := Node3D.new()
	root.name = "socket"
	# A square piece is a four-sided cylinder prism turned 45 degrees, not a
	# BoxMesh: a BoxMesh's split flat normals would open the outline hull at
	# every corner (see the file header).
	var body := _layer("Socket_Body", _prism(SOCKET_SIDE * 0.5, SOCKET_H), "Stone", Pal.STONE,
		Vector3(0.0, SOCKET_H * 0.5, 0.0))
	body.rotation.y = PI * 0.25
	root.add_child(body)
	root.add_child(_layer("Socket_Well", _cylinder(WELL_R, WELL_PROUD * 2.0, 32), "Well_flat", Pal.MARK,
		Vector3(0.0, SOCKET_H, 0.0)))
	Toon.apply_to(root)
	return root

## Dome with seven mark layers on its crown; the game shows one.
static func _peg() -> Node3D:
	var root := Node3D.new()
	root.name = "peg"
	var dome := SphereMesh.new()
	dome.radius = PEG_R
	dome.height = PEG_H
	dome.radial_segments = 32
	dome.rings = 16
	root.add_child(_layer("Peg_Body", dome, "Shell", Pal.PEGS[0], Vector3(0.0, PEG_H * 0.5, 0.0)))
	for k in range(1, Shapes.PIPS.size() + 1):
		root.add_child(_layer("Peg_Mark_%d" % k, _pips_mesh(k), "Mark_flat", Pal.PEGS[0].darkened(0.35), Vector3.ZERO))
	Toon.apply_to(root)
	return root

## `count` pip discs merged into one mesh, each inlaid in the dome's crown:
## the dome is an ellipsoid of semi-axes PEG_R and PEG_H / 2, whose outward
## normal at (x, y, z) runs along (x / a^2, (y - b) / b^2, z / a^2), and each
## disc turns its up axis onto that normal with its mid-plane on the surface
## point, so MARK_THICK / 2 stands proud and the rest is buried. Laid flat
## instead, a disc at the pip spread would dip 0.015 into the crown and read
## as a crescent; Mark_flat carries no outline, so the buried half is unseen.
static func _pips_mesh(count: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var disc := _cylinder(MARK_R, MARK_THICK, 16)
	var a := PEG_R
	var b := PEG_H * 0.5
	for p in Shapes.PIPS[count - 1]:
		var off: Vector2 = (p as Vector2) * MARK_SPREAD
		var d := off.length()
		var y := b + b * sqrt(maxf(0.0, 1.0 - (d * d) / (a * a)))
		var n := Vector3(off.x / (a * a), (y - b) / (b * b), off.y / (a * a)).normalized()
		st.append_from(disc, 0, Transform3D(Basis(Quaternion(Vector3.UP, n)), Vector3(off.x, y, off.y)))
	return st.commit()

## Well disc with a ball resting in it; the ball hides until the row is scored.
static func _pip() -> Node3D:
	var root := Node3D.new()
	root.name = "pip"
	root.add_child(_layer("Pip_Well", _cylinder(PIP_WELL_R, WELL_PROUD * 2.0, 24), "Well_flat", Pal.MARK,
		Vector3(0.0, WELL_PROUD, 0.0)))
	var ball := SphereMesh.new()
	ball.radius = PIP_R
	ball.height = PIP_R * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	root.add_child(_layer("Pip_Ball", ball, "Pip", Pal.MOON, Vector3(0.0, PIP_R, 0.0)))
	Toon.apply_to(root)
	return root

## Stone lid with a wooden knob, covering one code slot.
static func _lid() -> Node3D:
	var root := Node3D.new()
	root.name = "lid"
	# Same square-prism reasoning as _socket(): a BoxMesh would open the
	# outline hull at every corner.
	var body := _layer("Lid_Body", _prism(SOCKET_SIDE * 0.5, LID_H), "Lid", Pal.STONE_GIVEN,
		Vector3(0.0, LID_H * 0.5, 0.0))
	body.rotation.y = PI * 0.25
	root.add_child(body)
	root.add_child(_layer("Lid_Knob", _cylinder(KNOB_R, KNOB_H, 24), "Knob", Pal.WOOD,
		Vector3(0.0, LID_H + KNOB_H * 0.5, 0.0)))
	Toon.apply_to(root)
	return root

# --- Pipes pieces ---

## One mesh from several primitives, each placed by its own transform:
## `parts` is an Array of {"mesh": Mesh, "xform": Transform3D}. A layer that
## is several lobes (a pipe's hub and its tube segments) must still be one
## mesh, as docs/art/blender-contract.md requires, so its outline is one
## shell. append_from transforms the normals it finds, so nothing here calls
## generate_normals: welding a cylinder's caps to its sides would ruin the
## shading.
static func _merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var m: Mesh = part["mesh"]
		for i in m.get_surface_count():
			st.append_from(m, i, part["xform"])
	return st.commit()

## A ball of `radius`, smooth enough to read as a rounded hub.
static func _ball(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s

## `mesh` (standing along +Y) turned to lie along -Z -- the reference arm --
## and slid `out` down it at the tube's axis height.
static func _along(mesh: Mesh, out: float) -> Dictionary:
	return {"mesh": mesh, "xform": Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
		Vector3(0.0, TUBE_Y, -out))}

## The same part turned from the reference arm onto the arm at `yaw`.
static func _yawed(part: Dictionary, yaw: float) -> Dictionary:
	return {"mesh": part["mesh"],
		"xform": Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * part["xform"]}

## Bevelled slab one cell wide, the surface a pipe rests on. A square piece is
## a four-sided prism turned 45 degrees, not a BoxMesh (see the file header).
static func _pad() -> Node3D:
	var root := Node3D.new()
	root.name = "pipe_pad"
	var body := _layer("Pad_Body", _prism(PAD_SIDE * 0.5, PAD_H), "Stone", Pal.STONE,
		Vector3(0.0, PAD_H * 0.5, 0.0))
	body.rotation.y = PI * 0.25
	root.add_child(body)
	Toon.apply_to(root)
	return root

## A pipe piece for `mask`, the set of direction bits it opens on, in the
## orientation the shape is modelled in. Three layers: the shell (hub plus two
## segments per arm, the sight hole between them), the collars (a ring each
## side of every hole plus one at the mouth) and the water tube (the full
## length of every arm plus a hub ball), which shows through the holes and at
## every open mouth. Models._dress swaps the tube's material for a fresh
## pipe_flow one, here and on the Blender export alike.
static func _pipe(slot: String, mask: int) -> Node3D:
	var root := Node3D.new()
	root.name = slot
	var at_hub := Transform3D(Basis(), Vector3(0.0, TUBE_Y, 0.0))
	var shell: Array = [{"mesh": _ball(HUB_R), "xform": at_hub}]
	var collar: Array = []
	var water: Array = [{"mesh": _ball(CORE_R), "xform": at_hub}]
	for bit in [BIT_UP, BIT_RIGHT, BIT_DOWN, BIT_LEFT]:
		if mask & bit == 0:
			continue
		var yaw: float = ARM_YAW[bit]
		shell.append(_yawed(_along(_cylinder(TUBE_R, GAP_IN, 16), GAP_IN * 0.5), yaw))
		shell.append(_yawed(_along(_cylinder(TUBE_R, ARM_LEN - GAP_OUT, 16),
			(GAP_OUT + ARM_LEN) * 0.5), yaw))
		for d in [GAP_IN, GAP_OUT, MOUTH_AT]:
			collar.append(_yawed(_along(_cylinder(COLLAR_R, COLLAR_W, 16), d), yaw))
		water.append(_yawed(_along(_cylinder(CORE_R, ARM_LEN, 16), ARM_LEN * 0.5), yaw))
	root.add_child(_layer("Pipe_Shell", _merge(shell), "Steel", Pal.STEEL, Vector3.ZERO))
	root.add_child(_layer("Pipe_Collar", _merge(collar), "Collar", Pal.STEEL_HI, Vector3.ZERO))
	root.add_child(_layer("Pipe_Water", _merge(water), "Flow_flat", Pal.FLOW_DRY, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## The bolted ring the source and the drain wear: a torus around the cell's
## hub, clear of it, with four bolts inlaid in the pad outside the ring.
static func _valve() -> Node3D:
	var root := Node3D.new()
	root.name = "valve"
	var ring := TorusMesh.new()
	ring.inner_radius = VALVE_IN
	ring.outer_radius = VALVE_OUT
	ring.rings = 24
	ring.ring_segments = 12
	root.add_child(_layer("Valve_Ring", ring, "Metal", Pal.STEEL_HI,
		Vector3(0.0, VALVE_H * 0.5, 0.0)))
	var bolts: Array = []
	var d := BOLT_AT / sqrt(2.0)
	# Centred at BOLT_PROUD, not at 0, so the bolt's own base lands on y = 0:
	# the valve is measured on its own here, with no pad body underneath it to
	# bury the other half of a centred disc into (contrast the tile's inlays,
	# which sink into the cube that carries them).
	for at in [Vector3(d, BOLT_PROUD, d), Vector3(-d, BOLT_PROUD, d),
			Vector3(d, BOLT_PROUD, -d), Vector3(-d, BOLT_PROUD, -d)]:
		bolts.append({"mesh": _cylinder(BOLT_R, BOLT_PROUD * 2.0, 16),
			"xform": Transform3D(Basis(), at)})
	root.add_child(_layer("Valve_Bolts", _merge(bolts), "Bolt_flat", Pal.MARK, Vector3.ZERO))
	Toon.apply_to(root)
	return root
