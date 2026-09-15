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
## The shell's own cap at the mouth (r = TUBE_R) is the pipe's visible rim
## and stays exactly at ARM_LEN. The water tube's cap (r = CORE_R) and the
## mouth collar's outward cap (r = COLLAR_R) both land exactly on that same
## plane by construction (MOUTH_AT + COLLAR_W / 2 == ARM_LEN) -- three
## coplanar front-facing discs that z-fight over their shared inner radius.
## Both are pulled back by this much so only the shell's rim is left on the
## mouth plane; the committed .glb has no caps here at all, so this only
## shows on a fresh clone before the export is imported.
const CAP_CLEAR := 0.002
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

## Balance pieces (balance spec, section 1). A scale is three slots the board
## composes so the beam can actually turn: a stand whose fulcrum cap centre is
## the pivot, a beam hung under that pivot, and a pan hung under each beam end.
## Weights are set on a plinth: two stone pads, the far one carrying a stack of
## discs, the near one the carved numeral.
const SCALE_BASE_R := 0.34
const SCALE_BASE_H := 0.10
const SCALE_POST_R := 0.075
## Fulcrum height: the centre of Stand_Cap, and the height the board puts the
## beam pivot at. Tall enough that a fully tilted pan still clears the stone:
## the pan floor rests at SCALE_POST_H - PAN_DROP and a tilted end drops
## SCALE_ARM * sin(TILT_MAX) below that, which must stay above zero.
const SCALE_POST_H := 0.95
## The fulcrum collar, the ring the board turns green the moment its scale
## sits level. Wider than BEAM_HUB_R and set just under the pivot rather than
## on it: a ball at the fulcrum would sit concentric with the beam's hub and,
## being the smaller of the two, would never show a pixel of that green.
const SCALE_CAP_R := 0.17
const SCALE_CAP_H := 0.10
## Centre of the collar, a touch below the fulcrum so it rings the hub.
const SCALE_CAP_Y := 0.88
## Beam half-span; a pan hangs at each end.
const SCALE_ARM := 1.55
const BEAM_THICK := 0.075
const BEAM_WIDE := 0.10
const BEAM_HUB_R := 0.13
## How far the dish floor hangs below the hang point the beam end carries.
const PAN_DROP := 0.34
const PAN_R := 0.56
const PAN_LIP := 0.06
const CORD_R := 0.03
## Tokens are the shapes being weighed: one model per core/shapes.gd kind, so
## the silhouette carries the meaning and the colour only reinforces it.
const TOKEN_R := 0.17
const TOKEN_H := 0.30
## Spacing of the tokens sitting in a pan, up to three across.
const TOKEN_GAP := 0.37
## The plinth spans two cells: the far pad takes the stack, the near pad the
## numeral, so each tap half is a whole cell rather than half of one.
const PLINTH_PAD := 0.92
const PLINTH_HALF := 0.5
const PLINTH_H := 0.14
const DISC_R := 0.26
const DISC_H := 0.075
## Air between stacked discs. Wide enough that the outline draws a line
## between every pair, so a stack of six is countable rather than reading as
## one tall cylinder -- the stack is the weight, so it has to be countable.
const DISC_GAP := 0.02
const NUM_W := 0.34
const NUM_H := 0.5
const NUM_BAR := 0.055
const NUM_PROUD := 0.0015
## Which of the seven bars each digit lights, in the usual a-to-g naming:
## a top, b top-right, c bottom-right, d bottom, e bottom-left, f top-left,
## g middle, plus `i`, a centred full-height stroke used only by the one.
## Seven-segment puts the 1 on the right edge, where on a wide stone pad it
## reads as a stray bar rather than a numeral. Zero never appears -- a weight
## is at least one.
const NUM_SEGMENTS := {
	0: ["a", "b", "c", "d", "e", "f"],
	1: ["i"],
	2: ["a", "b", "g", "e", "d"],
	3: ["a", "b", "g", "c", "d"],
	4: ["f", "g", "b", "c"],
	5: ["a", "f", "g", "c", "d"],
	6: ["a", "f", "g", "e", "c", "d"],
	7: ["a", "b", "c"],
	8: ["a", "b", "c", "d", "e", "f", "g"],
	9: ["a", "b", "c", "d", "f", "g"],
}

## Untangle pieces. A node is a mooring post on the platform; an edge is a
## rope, which is NOT a model slot -- it is a tube the board rebuilds from its
## rope simulation every frame it moves, so it can sag and whip.
const POST_R := 0.16
const POST_H := 0.55
const POST_CAP_R := 0.21
const POST_CAP_H := 0.10
## Where a rope is made fast, just under the cap.
const ROPE_Y := POST_H - 0.05
const ROPE_R := 0.045

## Shikaku pieces (the design agreed 2026-09-15). A cell is a plot floor slab
## lying on the platform; a rectangle the player has drawn is ringed by
## dry-stone walls standing on those slabs, and the clue is a numbered marker
## stone in the middle of its cell. A wall stands where two different plots
## meet, so the board lays one `wall_edge` per run of seam -- scaled along its
## length, the way the platform slab is scaled -- and one `wall_post` wherever
## runs meet or end.
const PLOT_SIDE := 0.96
const PLOT_H := 0.10
## A wall is one piece long and sits across the seam, resting on the floor
## slabs either side; WALL_T is its thickness, so half of it laps each slab.
const WALL_T := 0.14
const WALL_H := 0.20
## The corner block, a little wider and taller than the walls it closes, so a
## corner reads as a corner rather than as two bars crossing.
const WALL_POST := 0.20
const WALL_POST_H := 0.24
## The clue: a low hexagonal marker stone with its numeral carved on top. Six
## sides so it is neither the square of a Binairo cube nor the circle of a
## pipe collar -- the board's pieces are told apart by silhouette first.
const CLUE_R := 0.31
const CLUE_H := 0.18
## The numeral lying on the marker's crown, smaller than the plinth's since
## the stone it sits on is a third of a plinth pad.
const CLUE_NUM_W := 0.24
const CLUE_NUM_H := 0.32
const CLUE_NUM_BAR := 0.045

## Tents pieces (the design agreed 2026-09-15). A field cell is a turf slab; a
## conifer stands on some of them; a ridge tent is pitched on a cell the player
## claims, and a pebble cairn marks one they have ruled out. The row and column
## counts reuse `clue_stone`, laid on the stone margin the board keeps around
## the field, which is why that slot carries a zero numeral as well.
const TURF_SIDE := 0.96
const TURF_H := 0.08
## The tent: a ridge of canvas with a shaded doorway on the near end. Wide
## enough to read beside a tree and low enough not to hide the cell behind it.
const TENT_W := 0.62
const TENT_L := 0.66
const TENT_H := 0.40
const TENT_DOOR_W := 0.22
const TENT_DOOR_H := 0.24
const TENT_DOOR_PROUD := 0.0015
## The conifer. Two layers, a trunk and a canopy of three stacked cones, the
## same split the island's scenery `tree` carries.
const PINE_R := 0.30
const PINE_H := 0.76
const PINE_TRUNK_R := 0.055
const PINE_TRUNK_H := 0.20
## The pebbles that rule a cell out. Sized up from a first look on the stage,
## where a smaller mark read as litter on the grass rather than as something
## the player had left: it is the piece the puzzle is actually solved with, so
## it has to carry as well as a tent does.
const CAIRN_R := 0.115
const CAIRN_H := 0.18

## Light Up pieces (the design agreed 2026-09-15). A court cell is Shikaku's
## own `plot_pad` flagstone -- the same island masonry, tinted cold where no
## lamp reaches it and warm where one does. A `wall_block` is the rough stone
## that stops the light, carrying its numeral on its crown the way a clue
## stone does. A `lantern` is what the player sets down to light a cell, and
## the chip that rules a cell out is Tents' own `cairn`, tinted slate.
##
## The block is deliberately shorter than a Binairo cube: it has to read as
## solid from the board's 68-degree pitch without hiding the cell behind it,
## and a tap meant for a block that lands on the cell beyond is only ever a
## refusal, so the parallax it costs (0.16 of a cell) buys nothing back.
const BLOCK_SIDE := 0.92
const BLOCK_H := 0.40
const BLOCK_NUM_W := 0.24
const BLOCK_NUM_H := 0.32
const BLOCK_NUM_BAR := 0.045
## The lantern: a glass globe sunk into a broad iron foot, and nothing on top
## of it. Two passes were spent learning that: the first capped the globe with
## a disc wider than it, the second with a narrow finial, and from the board's
## 68-degree pitch both covered the glass -- the lantern read as a dark blob
## with an amber rim, the same mistake the cairn's stacked pebbles made. What
## a piece means has to be in its silhouette from above, and what this one
## means is the light, so the light gets the whole silhouette. The foot is
## wider than the globe instead, which shows as a dark ring around it: that is
## what says the lamp is standing on the stone rather than resting loose on it.
## Sized up from a first look on the stage, where a globe 0.38 across read as
## a bead dropped on the cell: it is the piece the puzzle is solved with, so it
## carries about half the cell, the way a tent does on Tents' meadow.
const LANTERN_FOOT_R := 0.26
const LANTERN_FOOT_H := 0.05
const LANTERN_GLOBE_R := 0.24
const LANTERN_GLOBE_TALL := 1.05
## How far the globe sinks into the foot. The contract's assembly rule: parts
## overlap as closed solids rather than meeting at a tangent, which is all a
## sphere resting exactly on a disc does -- and a tangent point is where an
## outline hull opens.
const LANTERN_SINK := 0.03
const LANTERN_GLOBE_Y := LANTERN_FOOT_H + LANTERN_GLOBE_R * LANTERN_GLOBE_TALL - LANTERN_SINK
const LANTERN_H := LANTERN_GLOBE_Y + LANTERN_GLOBE_R * LANTERN_GLOBE_TALL

## Nonogram pieces (the design agreed 2026-09-15). A cell is Shikaku's own
## `plot_pad`, standing in as an empty socket; a filled cell carries a slate
## `mosaic_tile` laid in it, and a cell the player has ruled out carries
## Tents' `cairn`. The clues are `clue_stone` again, one stone per number on a
## margin of bare platform -- which is why the grid can be at most nine wide:
## a run of ten would need a numeral the stone does not carry.
const MOSAIC_SIDE := 0.80
const MOSAIC_H := 0.12

## One Line pieces (the design agreed 2026-09-15). The nodes are Untangle's
## own mooring posts. The line between two of them is a `plank`, modelled
## exactly one cell long and stretched to its span the way Shikaku's
## `wall_edge` is -- a board's lines run both orthogonally and diagonally, so
## there is no one length to model.
const PLANK_W := 0.34
const PLANK_H := 0.10

## Horse Pen pieces (the design agreed 2026-09-15). The meadow is Tents' turf
## and a pond is Shikaku's plot_pad sunk under the water material, so the new
## slots are the horse itself, standing in profile along X so the board camera
## sees its silhouette; one cell's length of timber fence, exactly a cell long
## so a run of fences reads as one rail; and an apple. The export cuts each
## down from a BlenderKit asset; these are the stand-ins.
const HORSE_L := 0.9
const HORSE_W := 0.28
const HORSE_H := 0.88
const FENCE_H := 0.42
const FENCE_T := 0.06
const FENCE_POST := 0.08
const FENCE_RAIL_H := 0.07
const APPLE_R := 0.17
const APPLE_STEM_H := 0.09

## Snake Apple pieces (the design agreed 2026-09-15). The head faces +X with
## the back of the skull at the origin, so the body tube the board builds
## along the snake's cells runs straight into it; SNAKE_HEAD_H frames the
## camera. The burrow is a ring of dug earth around a dark disc.
const SNAKE_HEAD_L := 0.5
const SNAKE_HEAD_W := 0.4
const SNAKE_HEAD_H := 0.4
const BURROW_R := 0.42
const BURROW_RIM_H := 0.1

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
		"scale_stand": return _scale_stand()
		"scale_beam": return _scale_beam()
		"scale_pan": return _scale_pan()
		"plinth": return _plinth()
		"weight_disc": return _weight_disc()
		"post": return _post()
		"plot_pad": return _plot_pad()
		"wall_edge": return _wall_edge()
		"wall_post": return _wall_post()
		"clue_stone": return _clue_stone()
		"turf_pad": return _turf_pad()
		"camp_tree": return _camp_tree()
		"tent": return _tent()
		"cairn": return _cairn()
		"wall_block": return _wall_block()
		"lantern": return _lantern()
		"mosaic_tile": return _mosaic_tile()
		"plank": return _plank()
		"horse": return _horse()
		"fence": return _fence()
		"apple": return _apple()
		"snake_head": return _snake_head()
		"burrow": return _burrow()
	if slot.begins_with("token_"):
		return _token(slot)
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
		for d in [GAP_IN, GAP_OUT, MOUTH_AT - CAP_CLEAR]:
			collar.append(_yawed(_along(_cylinder(COLLAR_R, COLLAR_W, 16), d), yaw))
		var water_len := ARM_LEN - CAP_CLEAR
		water.append(_yawed(_along(_cylinder(CORE_R, water_len, 16), water_len * 0.5), yaw))
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

# --- Balance pieces ---

## The stand: a stone foot and post as two lobes of one mesh (one layer, as
## the contract allows), and the metal fulcrum cap the beam turns on. The
## cap's centre is the pivot, so the board puts its beam node at SCALE_POST_H.
static func _scale_stand() -> Node3D:
	var root := Node3D.new()
	root.name = "scale_stand"
	var body: Array = [
		{"mesh": _cylinder(SCALE_BASE_R, SCALE_BASE_H, 24),
			"xform": Transform3D(Basis(), Vector3(0.0, SCALE_BASE_H * 0.5, 0.0))},
		{"mesh": _cylinder(SCALE_POST_R, SCALE_POST_H, 16),
			"xform": Transform3D(Basis(), Vector3(0.0, SCALE_POST_H * 0.5, 0.0))},
	]
	root.add_child(_layer("Stand_Body", _merge(body), "Stone", Pal.STONE, Vector3.ZERO))
	# Its own material name, not the beam hub's `Metal`: the board turns the
	# cap green the moment its scale sits level, and must not paint the hub.
	root.add_child(_layer("Stand_Cap", _cylinder(SCALE_CAP_R, SCALE_CAP_H, 24), "Cap",
		Pal.STEEL_HI, Vector3(0.0, SCALE_CAP_Y, 0.0)))
	Toon.apply_to(root)
	return root

## The beam: a wooden arm through a metal hub. Modelled base at Z = 0 like
## every other slot, rather than pivot-at-origin -- the board hangs it at
## -BEAM_HUB_R under its turning node, which lands the hub's centre exactly on
## the fulcrum. That keeps the contract's origin rule intact for a part whose
## true pivot is in its middle, with no exporter exception.
static func _scale_beam() -> Node3D:
	var root := Node3D.new()
	root.name = "scale_beam"
	var arm := BoxMesh.new()
	arm.size = Vector3(SCALE_ARM * 2.0, BEAM_THICK, BEAM_WIDE)
	root.add_child(_layer("Beam_Arm", arm, "Wood", Pal.WOOD, Vector3(0.0, BEAM_HUB_R, 0.0)))
	root.add_child(_layer("Beam_Hub", _ball(BEAM_HUB_R), "Metal", Pal.STEEL_HI,
		Vector3(0.0, BEAM_HUB_R, 0.0)))
	Toon.apply_to(root)
	return root

## A hanging pan: a shallow dish with three cords meeting PAN_DROP above its
## floor. Modelled base at Z = 0 for the same reason as the beam; the board
## hangs it at -PAN_DROP so the cords' meeting point sits on the beam's end.
static func _scale_pan() -> Node3D:
	var root := Node3D.new()
	root.name = "scale_pan"
	root.add_child(_layer("Pan_Dish", _cylinder(PAN_R, PAN_LIP, 28), "Pan", Pal.STEEL,
		Vector3(0.0, PAN_LIP * 0.5, 0.0)))
	var cords: Array = []
	var apex := Vector3(0.0, PAN_DROP, 0.0)
	for k in 3:
		var a := TAU * float(k) / 3.0
		var foot := Vector3(cos(a) * (PAN_R - CORD_R * 3.0), PAN_LIP,
			sin(a) * (PAN_R - CORD_R * 3.0))
		var run := apex - foot
		cords.append({"mesh": _cylinder(CORD_R, run.length(), 8),
			"xform": Transform3D(Basis(Quaternion(Vector3.UP, run.normalized())),
				foot + run * 0.5)})
	# `_flat`, so no outline shell: a cord is 0.018 across and the shell, which
	# pushes a second copy out along the normals, would close over it entirely.
	root.add_child(_layer("Pan_Cords", _merge(cords), "Cord_flat", Pal.STEEL_HI, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## The plinth: two stone pads as one mesh, a cell apart -- the far one the
## disc stack rises from, the near one carrying the numeral -- so the board's
## two tap halves are visibly two pads rather than an invisible split down the
## middle of one slab. Nine numeral layers lie on the near pad and the board
## shows the one matching the weight, the way a peg shows one of its marks.
static func _plinth() -> Node3D:
	var root := Node3D.new()
	root.name = "plinth"
	var pads: Array = []
	for z in [-PLINTH_HALF, PLINTH_HALF]:
		# A square pad is a four-sided prism turned 45 degrees, not a BoxMesh
		# (see the file header): the two pads are lobes of one layer.
		pads.append({"mesh": _prism(PLINTH_PAD * 0.5, PLINTH_H),
			"xform": Transform3D(Basis(Vector3.UP, PI * 0.25),
				Vector3(0.0, PLINTH_H * 0.5, z))})
	root.add_child(_layer("Plinth_Body", _merge(pads), "Stone", Pal.STONE, Vector3.ZERO))
	root.add_child(_layer("Plinth_Well", _cylinder(DISC_R + 0.03, WELL_PROUD * 2.0, 28),
		"Well_flat", Pal.MARK, Vector3(0.0, PLINTH_H, -PLINTH_HALF)))
	for d in range(1, 10):
		root.add_child(_layer("Plinth_Num_%d" % d, _digit_mesh(d), "Num_flat", Pal.SLATE,
			Vector3(0.0, PLINTH_H, PLINTH_HALF)))
	Toon.apply_to(root)
	return root

## One digit lying flat on the near pad, as seven-segment bars: the
## placeholder's stand-in for the carved numerals the .blend will hold. The
## board camera looks from +Z, so -Z is up the screen and segment `a` goes
## there. Num_flat carries no outline, so the bars' split normals cost
## nothing.
static func _digit_mesh(d: int, w := NUM_W, h := NUM_H, bar := NUM_BAR) -> ArrayMesh:
	var thin := NUM_PROUD * 2.0
	var y := NUM_PROUD
	var half_h := h * 0.5
	var quarter := h * 0.25
	var across := Vector3(w, thin, bar)
	var down := Vector3(bar, thin, half_h)
	var bars := {
		"a": [across, Vector3(0.0, y, -half_h)],
		"g": [across, Vector3(0.0, y, 0.0)],
		"d": [across, Vector3(0.0, y, half_h)],
		"f": [down, Vector3(-w * 0.5, y, -quarter)],
		"b": [down, Vector3(w * 0.5, y, -quarter)],
		"e": [down, Vector3(-w * 0.5, y, quarter)],
		"c": [down, Vector3(w * 0.5, y, quarter)],
		"i": [Vector3(bar, thin, h), Vector3(0.0, y, 0.0)],
	}
	var parts: Array = []
	for seg in NUM_SEGMENTS[clampi(d, 0, 9)]:
		var spec: Array = bars[seg]
		var box := BoxMesh.new()
		box.size = spec[0]
		parts.append({"mesh": box, "xform": Transform3D(Basis(), spec[1])})
	return _merge(parts)

## One unit of weight: a stone disc the board tints by its shape's colour and
## stacks on the plinth's far pad.
static func _weight_disc() -> Node3D:
	var root := Node3D.new()
	root.name = "weight_disc"
	root.add_child(_layer("Disc_Body", _cylinder(DISC_R, DISC_H, 24), "Disc", Pal.CAT[0],
		Vector3(0.0, DISC_H * 0.5, 0.0)))
	Toon.apply_to(root)
	return root

## A weight token, one per core/shapes.gd kind in the same index order, so
## shape index 0 is a ball as Kind.CIRCLE is a circle. Each is a single layer
## the board tints; the silhouette is what a colour-blind player reads, so the
## five shapes are told apart from above at the board's pitch, not by hue.
static func _token(slot: String) -> Node3D:
	var root := Node3D.new()
	root.name = slot
	var mesh: Mesh
	match slot:
		"token_ball":
			var s := SphereMesh.new()
			s.radius = TOKEN_R
			s.height = TOKEN_H
			s.radial_segments = 24
			s.rings = 12
			# Merged rather than used raw, only to lift it onto its base: a
			# SphereMesh is centred on its origin and would hang half below.
			mesh = _merge([{"mesh": s,
				"xform": Transform3D(Basis(), Vector3(0.0, TOKEN_H * 0.5, 0.0))}])
		"token_cube":
			# Turned 45 degrees so its flat faces are axis-aligned: a square
			# from above, where token_gem's four sides read point-on.
			mesh = _merge([{"mesh": _prism(TOKEN_R * 0.86, TOKEN_H),
				"xform": Transform3D(Basis(Vector3.UP, PI * 0.25),
					Vector3(0.0, TOKEN_H * 0.5, 0.0))}])
		"token_prism":
			mesh = _merge([{"mesh": _cylinder(TOKEN_R * 1.15, TOKEN_H, 3),
				"xform": Transform3D(Basis(), Vector3(0.0, TOKEN_H * 0.5, 0.0))}])
		"token_gem":
			# A four-sided bipyramid: shapes.gd's diamond in the round, and
			# the only token whose silhouette narrows toward the top.
			var lower := CylinderMesh.new()
			lower.top_radius = TOKEN_R
			lower.bottom_radius = 0.0
			lower.height = TOKEN_H * 0.4
			lower.radial_segments = 4
			lower.rings = 0
			var upper := CylinderMesh.new()
			upper.top_radius = 0.0
			upper.bottom_radius = TOKEN_R
			upper.height = TOKEN_H * 0.6
			upper.radial_segments = 4
			upper.rings = 0
			mesh = _merge([
				{"mesh": lower, "xform": Transform3D(Basis(), Vector3(0.0, TOKEN_H * 0.2, 0.0))},
				{"mesh": upper, "xform": Transform3D(Basis(), Vector3(0.0, TOKEN_H * 0.7, 0.0))},
			])
		_:
			# token_cross: two bars crossing, shapes.gd's plus in the round.
			var long_arm := BoxMesh.new()
			long_arm.size = Vector3(TOKEN_R * 2.0, TOKEN_H, TOKEN_R * 0.76)
			var short_arm := BoxMesh.new()
			short_arm.size = Vector3(TOKEN_R * 0.76, TOKEN_H, TOKEN_R * 2.0)
			var at := Transform3D(Basis(), Vector3(0.0, TOKEN_H * 0.5, 0.0))
			mesh = _merge([{"mesh": long_arm, "xform": at}, {"mesh": short_arm, "xform": at}])
	root.add_child(_layer("Token_Body", mesh, "Token", Pal.CAT[0], Vector3.ZERO))
	Toon.apply_to(root)
	return root

# --- Untangle pieces ---

## A mooring post: a wooden shaft with a wider cap the rope is made fast
## under. The cap is its own layer so the board can colour it -- held, or too
## close to its neighbour -- without touching the shaft.
static func _post() -> Node3D:
	var root := Node3D.new()
	root.name = "post"
	root.add_child(_layer("Post_Body", _cylinder(POST_R, POST_H, 20), "Wood", Pal.WOOD,
		Vector3(0.0, POST_H * 0.5, 0.0)))
	root.add_child(_layer("Post_Cap", _cylinder(POST_CAP_R, POST_CAP_H, 20), "Cap", Pal.ACCENT,
		Vector3(0.0, POST_H, 0.0)))
	Toon.apply_to(root)
	return root

# --- Shikaku pieces ---

## A rectangular bar with shared smooth vertices, base at y = 0 and centred
## on the origin: a four-sided prism turned 45 degrees and then stretched,
## never a BoxMesh (see the file header), so the outline hull closes at its
## corners. `length` runs along X, `width` along Z.
static func _bar(length: float, width: float, height: float) -> ArrayMesh:
	var basis := Basis(Vector3.UP, PI * 0.25).scaled(Vector3(length, height, width))
	return _merge([{"mesh": _prism(0.5, 1.0),
		"xform": Transform3D(basis, Vector3(0.0, height * 0.5, 0.0))}])

## One cell's floor. Tinted by whether a rectangle has claimed the cell, so
## its single layer carries the `Stone` name every tinted slab uses.
static func _plot_pad() -> Node3D:
	var root := Node3D.new()
	root.name = "plot_pad"
	root.add_child(_layer("Pad_Body", _bar(PLOT_SIDE, PLOT_SIDE, PLOT_H),
		"Stone", Pal.PLOT_BARE, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## One cell's length of dry-stone wall, running along X. The board scales it
## along its length to cover a whole run of seam, so the placeholder is a
## plain bar: nothing about it changes shape when it is stretched.
static func _wall_edge() -> Node3D:
	var root := Node3D.new()
	root.name = "wall_edge"
	root.add_child(_layer("Wall_Body", _bar(1.0, WALL_T, WALL_H),
		"Wall", Pal.WALL_STONE, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## The block that closes a corner, a junction or the end of a wall run. Its
## own layer name matches the walls' so tinting one tints both.
static func _wall_post() -> Node3D:
	var root := Node3D.new()
	root.name = "wall_post"
	root.add_child(_layer("Post_Block", _bar(WALL_POST, WALL_POST, WALL_POST_H),
		"Wall", Pal.WALL_STONE, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## The clue: a hexagonal marker stone carrying nine carved numerals, of which
## the board shows the one matching its area, the way a plinth shows a weight.
static func _clue_stone() -> Node3D:
	var root := Node3D.new()
	root.name = "clue_stone"
	root.add_child(_layer("Clue_Body", _cylinder(CLUE_R, CLUE_H, 6), "Stone", Pal.STONE_GIVEN,
		Vector3(0.0, CLUE_H * 0.5, 0.0)))
	# Zero included: a Shikaku clue is never 0, but a Tents row count often is
	# and both read their number off this stone.
	for d in range(0, 10):
		root.add_child(_layer("Clue_Num_%d" % d,
			_digit_mesh(d, CLUE_NUM_W, CLUE_NUM_H, CLUE_NUM_BAR), "Num_flat", Pal.SLATE,
			Vector3(0.0, CLUE_H, 0.0)))
	Toon.apply_to(root)
	return root

# --- Tents pieces ---

## One field cell's turf.
static func _turf_pad() -> Node3D:
	var root := Node3D.new()
	root.name = "turf_pad"
	root.add_child(_layer("Turf_Body", _bar(TURF_SIDE, TURF_SIDE, TURF_H),
		"Turf", Pal.TURF, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## The conifer a tent is pitched beside: a trunk and a canopy of three cones,
## each starting a little inside the one below so the tiers read as steps from
## the board's own pitch, where a single smooth cone is just a green circle.
static func _camp_tree() -> Node3D:
	var root := Node3D.new()
	root.name = "camp_tree"
	root.add_child(_layer("Tree_Trunk", _cylinder(PINE_TRUNK_R, PINE_TRUNK_H, 12), "Bark", Pal.BARK,
		Vector3(0.0, PINE_TRUNK_H * 0.5, 0.0)))
	var cones: Array = []
	var tiers := 3
	var span := PINE_H - PINE_TRUNK_H * 0.5
	for i in tiers:
		var t := float(i) / float(tiers)
		# Each tier overhangs the one above it, so the silhouette from above is
		# three rings rather than one disc.
		var radius: float = PINE_R * (1.0 - t * 0.5)
		var base: float = PINE_TRUNK_H * 0.5 + span * t * 0.78
		var tall: float = span * (0.48 if i < tiers - 1 else 1.0 - t * 0.78)
		var cone := CylinderMesh.new()
		cone.top_radius = radius * 0.22
		cone.bottom_radius = radius
		cone.height = tall
		cone.radial_segments = 12
		cone.rings = 0
		cones.append({"mesh": cone,
			"xform": Transform3D(Basis(), Vector3(0.0, base + tall * 0.5, 0.0))})
	root.add_child(_layer("Tree_Canopy", _merge(cones), "Leaf", Pal.LEAF, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## A triangular prism: a ridge `length` long along Z, `width` across and
## `height` tall, resting on its flat base with the ridge line over the
## centre. Built from explicit vertices rather than from a cylinder, because
## Godot clamps CylinderMesh.radial_segments to four -- a three-segment
## "prism" comes out square, which is what first laid this tent on a corner.
##
## Per-face vertices, not shared ones: six shared vertices would average the
## base's downward normal into the slopes and the canvas would shade black.
## The cost is that the outline hull opens along the ridge, the same
## concession the tile placeholder makes -- the Blender export models it
## properly, smooth with a bevel.
static func _wedge(length: float, width: float, height: float) -> ArrayMesh:
	var hx := width * 0.5
	var hz := length * 0.5
	# The base, near-left round to far-left, then the near and far ridge ends.
	var at := [Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz), Vector3(hx, 0.0, -hz),
		Vector3(-hx, 0.0, -hz), Vector3(0.0, height, hz), Vector3(0.0, height, -hz)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The base, the two gables, then the two slopes. Wound clockwise seen from
	# outside, which is Godot's front face: counter-clockwise points every
	# normal inward instead, and the outline shell then closes over the piece
	# and the tent renders as a black blob.
	for tri in [[0, 3, 2], [0, 2, 1], [0, 1, 4], [3, 5, 2],
			[1, 2, 5], [1, 5, 4], [0, 4, 5], [0, 5, 3]]:
		for i in [tri[0], tri[2], tri[1]]:
			st.add_vertex(at[i])
	st.generate_normals()
	return st.commit()

## A ridge tent: a wedge of canvas with a shaded doorway inlaid in the gable
## facing the player, so the board camera looks into the tent rather than at
## a blank wall.
static func _tent() -> Node3D:
	var root := Node3D.new()
	root.name = "tent"
	root.add_child(_layer("Tent_Canvas", _wedge(TENT_L, TENT_W, TENT_H),
		"Canvas", Pal.CANVAS, Vector3.ZERO))
	# Centred on the gable plane, so half of it stands proud and half is
	# buried: the inlay treatment the tile's emblems use.
	root.add_child(_layer("Tent_Door", _bar(TENT_DOOR_W, TENT_DOOR_PROUD * 2.0, TENT_DOOR_H),
		"Door_flat", Pal.TENT_DOOR, Vector3(0.0, 0.0, TENT_L * 0.5)))
	Toon.apply_to(root)
	return root

## Three pebbles: the mark for a cell the player has ruled out. Laid in a
## triangle on the turf rather than stacked into a cairn -- at the board's
## 68-degree pitch a stack hides its own top pebble behind the two under it
## and the whole mark reads as one grey smudge, where three pebbles side by
## side read as three.
static func _cairn() -> Node3D:
	var root := Node3D.new()
	root.name = "cairn"
	var squat := Basis().scaled(Vector3(1.0, 0.7, 1.0))
	var pebbles: Array = []
	var spread := CAIRN_R * 1.15
	for i in 3:
		# One pebble toward the player, two behind it, so the mark has a
		# direction and does not read as a circle of stones.
		var a := TAU * (float(i) / 3.0 + 0.25)
		var radius: float = CAIRN_R * (1.0 if i == 0 else 0.86)
		pebbles.append({"mesh": _ball(radius),
			"xform": Transform3D(squat, Vector3(cos(a) * spread, radius * 0.7, sin(a) * spread))})
	root.add_child(_layer("Cairn_Body", _merge(pebbles), "Pebble", Pal.PEBBLE, Vector3.ZERO))
	Toon.apply_to(root)
	return root

# --- Light Up pieces ---

## A wall block: the rough stone that stops the light, carrying five carved
## numerals of which the board shows the one its clue stands for. Numbered
## zero through four, because a wall touches at most four cells. An unnumbered
## wall shows none of them and is just stone.
static func _wall_block() -> Node3D:
	var root := Node3D.new()
	root.name = "wall_block"
	root.add_child(_layer("Block_Body", _bar(BLOCK_SIDE, BLOCK_SIDE, BLOCK_H),
		"Block", Pal.BLOCK_STONE, Vector3.ZERO))
	for d in range(0, 5):
		root.add_child(_layer("Block_Num_%d" % d,
			_digit_mesh(d, BLOCK_NUM_W, BLOCK_NUM_H, BLOCK_NUM_BAR), "Num_flat",
			Pal.BLOCK_NUM, Vector3(0.0, BLOCK_H, 0.0)))
	Toon.apply_to(root)
	return root

## A lantern: a glass globe in an iron foot, the glass its own layer so the
## board can warm or blush it without touching the ironwork.
static func _lantern() -> Node3D:
	var root := Node3D.new()
	root.name = "lantern"
	root.add_child(_layer("Lantern_Iron",
		_cylinder(LANTERN_FOOT_R, LANTERN_FOOT_H, 20), "Iron", Pal.LANTERN,
		Vector3(0.0, LANTERN_FOOT_H * 0.5, 0.0)))
	var globe := Basis().scaled(Vector3(1.0, LANTERN_GLOBE_TALL, 1.0))
	root.add_child(_layer("Lantern_Glass", _merge([{"mesh": _ball(LANTERN_GLOBE_R),
		"xform": Transform3D(globe, Vector3(0.0, LANTERN_GLOBE_Y, 0.0))}]),
		"Glass", Pal.SUN, Vector3.ZERO))
	Toon.apply_to(root)
	return root

# --- Nonogram and One Line pieces ---

## One tile of the mosaic: the slate square a filled cell carries, and so the
## thing the finished picture is actually made of. Smaller than its socket, so
## the pale stone shows as a grout line around every tile and the picture reads
## as laid rather than painted.
static func _mosaic_tile() -> Node3D:
	var root := Node3D.new()
	root.name = "mosaic_tile"
	root.add_child(_layer("Mosaic_Body", _bar(MOSAIC_SIDE, MOSAIC_SIDE, MOSAIC_H),
		"Mosaic", Pal.MOSAIC, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## One cell's length of plank, running along X. The board stretches it along
## its length to span two posts, so the placeholder is a plain bar: nothing
## about it changes shape when it is stretched.
static func _plank() -> Node3D:
	var root := Node3D.new()
	root.name = "plank"
	root.add_child(_layer("Plank_Body", _bar(1.0, PLANK_W, PLANK_H),
		"Plank", Pal.PLANK_BARE, Vector3.ZERO))
	Toon.apply_to(root)
	return root

# --- Horse Pen pieces ---

## A blocky horse in profile, facing +X: body, neck, head and four legs as one
## `Hide` layer; mane and tail as one `Mane` layer; two eyes as a flat layer.
## Only the silhouette matters -- the export is a real horse.
static func _horse() -> Node3D:
	var root := Node3D.new()
	root.name = "horse"
	var leg_h := HORSE_H * 0.42
	var body_h := HORSE_H * 0.34
	var hide: Array = [
		{"mesh": _bar(0.62, HORSE_W, body_h),
			"xform": Transform3D(Basis(), Vector3(-0.08, leg_h, 0.0))},
		{"mesh": _bar(0.2, HORSE_W * 0.7, HORSE_H * 0.36),
			"xform": Transform3D(Basis(Vector3.BACK, -0.5), Vector3(0.26, leg_h + body_h * 0.5, 0.0))},
		{"mesh": _bar(0.26, HORSE_W * 0.72, 0.16),
			"xform": Transform3D(Basis(), Vector3(0.32, HORSE_H - 0.16, 0.0))},
	]
	for x in [-0.32, -0.16, 0.06, 0.2]:
		for z in [-HORSE_W * 0.3, HORSE_W * 0.3]:
			hide.append({"mesh": _bar(0.09, 0.09, leg_h + 0.02),
				"xform": Transform3D(Basis(), Vector3(x, 0.0, z))})
	root.add_child(_layer("Horse_Body", _merge(hide), "Hide", Pal.HIDE, Vector3.ZERO))
	var mane: Array = [
		{"mesh": _bar(0.22, 0.06, 0.08),
			"xform": Transform3D(Basis(Vector3.BACK, -0.5), Vector3(0.2, HORSE_H - 0.1, 0.0))},
		{"mesh": _bar(0.06, 0.06, 0.34),
			"xform": Transform3D(Basis(), Vector3(-0.42, leg_h - 0.1, 0.0))},
	]
	root.add_child(_layer("Horse_Mane", _merge(mane), "Mane", Pal.MANE, Vector3.ZERO))
	var eyes: Array = []
	for z in [-HORSE_W * 0.36, HORSE_W * 0.36]:
		eyes.append({"mesh": _bar(0.04, 0.006, 0.04),
			"xform": Transform3D(Basis(), Vector3(0.38, HORSE_H - 0.1, z))})
	root.add_child(_layer("Horse_Eye", _merge(eyes), "Eye_flat", Pal.HORSE_EYE, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## One cell of timber fence along X: two rails between a post at each end, one
## `Timber` layer. Exactly a cell long, posts included, so a run of fences
## meets post to post.
static func _fence() -> Node3D:
	var root := Node3D.new()
	root.name = "fence"
	var parts: Array = []
	for x in [-0.5 + FENCE_POST * 0.5, 0.5 - FENCE_POST * 0.5]:
		parts.append({"mesh": _bar(FENCE_POST, FENCE_POST, FENCE_H),
			"xform": Transform3D(Basis(), Vector3(x, 0.0, 0.0))})
	for y in [FENCE_H * 0.36, FENCE_H * 0.72]:
		parts.append({"mesh": _bar(1.0, FENCE_T, FENCE_RAIL_H),
			"xform": Transform3D(Basis(), Vector3(0.0, y, 0.0))})
	root.add_child(_layer("Fence_Timber", _merge(parts), "Timber", Pal.TIMBER, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## An apple: a squat ball, a stem and one flat leaf. Stem and leaf are `_flat`:
## both are thinner than the outline shell, which would swallow them whole.
static func _apple() -> Node3D:
	var root := Node3D.new()
	root.name = "apple"
	var squat := Basis().scaled(Vector3(1.0, 0.92, 1.0))
	var top := APPLE_R * 0.92 * 2.0
	root.add_child(_layer("Apple_Fruit", _merge([{"mesh": _ball(APPLE_R),
		"xform": Transform3D(squat, Vector3(0.0, APPLE_R * 0.92, 0.0))}]),
		"Fruit", Pal.FRUIT, Vector3.ZERO))
	root.add_child(_layer("Apple_Stem", _cylinder(0.018, APPLE_STEM_H, 8), "Stem_flat", Pal.STEM,
		Vector3(0.0, top - 0.02 + APPLE_STEM_H * 0.5, 0.0)))
	root.add_child(_layer("Apple_Leaf", _bar(0.13, 0.06, 0.006), "Leaf_flat", Pal.APPLE_LEAF,
		Vector3(0.08, top + 0.02, 0.0)))
	Toon.apply_to(root)
	return root

# --- Snake Apple pieces ---

## The snake's head: a squashed ball reaching forward along +X from the
## origin, with two flat eyes on top. The board's tube meets it at the back.
static func _snake_head() -> Node3D:
	var root := Node3D.new()
	root.name = "snake_head"
	var squash := Basis().scaled(Vector3(SNAKE_HEAD_L / SNAKE_HEAD_W, SNAKE_HEAD_H / SNAKE_HEAD_W, 1.0))
	root.add_child(_layer("Snake_Head", _merge([{"mesh": _ball(SNAKE_HEAD_W * 0.5),
		"xform": Transform3D(squash, Vector3(SNAKE_HEAD_L * 0.4, SNAKE_HEAD_H * 0.5, 0.0))}]),
		"Scale", Pal.SCALE, Vector3.ZERO))
	var eyes: Array = []
	for z in [-SNAKE_HEAD_W * 0.28, SNAKE_HEAD_W * 0.28]:
		eyes.append({"mesh": _bar(0.07, 0.07, 0.004),
			"xform": Transform3D(Basis(), Vector3(SNAKE_HEAD_L * 0.5, SNAKE_HEAD_H - 0.01, z))})
	root.add_child(_layer("Snake_Eye", _merge(eyes), "Eye_flat", Pal.HORSE_EYE, Vector3.ZERO))
	Toon.apply_to(root)
	return root

## The burrow: a ring of dug earth around the dark of the hole.
static func _burrow() -> Node3D:
	var root := Node3D.new()
	root.name = "burrow"
	var ring := TorusMesh.new()
	ring.inner_radius = BURROW_R * 0.6
	ring.outer_radius = BURROW_R
	ring.rings = 24
	ring.ring_segments = 10
	root.add_child(_layer("Burrow_Rim", _merge([{"mesh": ring,
		"xform": Transform3D(Basis().scaled(Vector3(1.0, BURROW_RIM_H / (BURROW_R * 0.4), 1.0)),
			Vector3(0.0, BURROW_RIM_H * 0.5, 0.0))}]), "Earth", Pal.EARTH, Vector3.ZERO))
	root.add_child(_layer("Burrow_Hole", _cylinder(BURROW_R * 0.62, 0.004, 24), "Hole_flat", Pal.HOLE,
		Vector3(0.0, 0.002, 0.0)))
	Toon.apply_to(root)
	return root
