extends RefCounted

## Lattice's drawings: the wooden slats, the socket a tile sits in, the paper
## tile and the green one it becomes at home, and the knot in a gap with its
## points. Builder shapes and not Controls, as Quilt's cloth and Pinwheel's
## wheel are: the board bakes forty tiles into a mesh, and the menu card and
## the tutorial draw the same pieces. The numerals are the caller's (a
## draw_string each, never baked).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## Sizes as a share of the cell.
const TILE := 0.86
const TILE_RADIUS := 0.16
const TILE_EDGE := 0.07
## How far a tile's face stands above the cell's centre: half its edge.
const FACE_RISE := 0.035
const SLAT := 0.6
const SLAT_EDGE := 0.05
const SOCKET := 0.92
const KNOT_R := 0.3
const POINT_HALF := 0.17
const POINT_TIP := 0.47
const WAY := {"L": Vector2.LEFT, "U": Vector2.UP, "R": Vector2.RIGHT, "D": Vector2.DOWN}

## The pieces drawn many times over, each once about the origin at `cell`:
## {free, home, ring, shade}.
static func units(cell: float) -> Dictionary:
	var out := {}
	var b := Face.Builder.new()
	tile(b, Vector2.ZERO, cell, false)
	out.free = b.mesh()
	b = Face.Builder.new()
	tile(b, Vector2.ZERO, cell, true)
	out.home = b.mesh()
	b = Face.Builder.new()
	var s := cell * (TILE + 0.1)
	b.fan(Face.Builder.round_rect(-Vector2.ONE * s * 0.5, Vector2.ONE * s, cell * (TILE_RADIUS + 0.04)), Pal.SUN)
	out.ring = b.mesh()
	b = Face.Builder.new()
	Scenery.soft_disc(b, Vector2(0.0, cell * 0.36), cell * 0.42, cell * 0.12, Color(Pal.TEXT, 0.2))
	out.shade = b.mesh()
	return out

## A tile centred on `at`: its deep edge and its face, paper or leaf.
static func tile(b, at: Vector2, cell: float, home: bool) -> void:
	var s := cell * TILE
	var edge := cell * TILE_EDGE
	var corner := at - Vector2.ONE * s * 0.5
	b.fan(Face.Builder.round_rect(corner, Vector2.ONE * s, cell * TILE_RADIUS), Pal.LEAF_DEEP if home else Pal.LINE)
	b.fan(Face.Builder.round_rect(corner, Vector2(s, s - edge), cell * TILE_RADIUS), Pal.LEAF if home else Pal.SURFACE)

## One slat of the lattice filling the strip at `at` of `size`, a cell wide.
static func slat(b, at: Vector2, size: Vector2, cell: float) -> void:
	var across := size.x > size.y
	var inset := cell * (1.0 - SLAT) * 0.5
	var corner := at + (Vector2(-cell * 0.08, inset) if across else Vector2(inset, -cell * 0.08))
	var box := Vector2(size.x + cell * 0.16, cell * SLAT) if across else Vector2(cell * SLAT, size.y + cell * 0.16)
	b.fan(Face.Builder.round_rect(corner, box, cell * 0.1), Pal.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(corner, box - Vector2(0.0, cell * SLAT_EDGE), cell * 0.1), Pal.WOOD)

## The recess a tile sits in.
static func socket(b, at: Vector2, cell: float) -> void:
	var s := cell * SOCKET
	b.fan(Face.Builder.round_rect(at - Vector2.ONE * s * 0.5, Vector2.ONE * s, cell * (TILE_RADIUS + 0.02)), Pal.WOOD_DEEP)

## A knot centred on `at` with a point each way in `dirs` (out of L U R D),
## in ink, or in leaf once the tiles it points at are home.
static func knot(b, at: Vector2, cell: float, dirs: String, done := false) -> void:
	var colour := Pal.LEAF_DEEP if done else Pal.TEXT
	for d in dirs:
		var way: Vector2 = WAY[d]
		var side := Vector2(-way.y, way.x)
		b.fan(PackedVector2Array([
			at + side * cell * POINT_HALF + way * cell * 0.12,
			at + way * cell * POINT_TIP,
			at - side * cell * POINT_HALF + way * cell * 0.12]), colour)
	b.disc(at, cell * KNOT_R, colour)
