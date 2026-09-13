extends RefCounted

## Pure geometry for boards laid out on the XZ plane, one cell per world unit,
## centred on the board anchor. Columns run along +X, rows along +Z, so with a
## camera on the +Z side looking toward -Z, row 0 is the far edge (top of the
## screen) and column 0 is on the left. Nothing here touches a camera or a
## node, so it runs headless and is covered by tests/test_board_math.gd.

const CELL := 1.0

## Where a ray from `origin` heading `dir` crosses the horizontal plane at
## height `y`. Null when the ray is parallel to the plane or moving away.
static func ray_plane(origin: Vector3, dir: Vector3, y: float) -> Variant:
	if absf(dir.y) < 1e-6:
		return null
	var t := (y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t

## Min corner of cell (row 0, col 0) for a `cols` by `rows` board centred on
## the origin.
static func cell_origin(cols: int, rows: int) -> Vector3:
	return Vector3(-cols * CELL * 0.5, 0.0, -rows * CELL * 0.5)

## Centre of cell (r, c) at height y.
static func cell_center(r: int, c: int, cols: int, rows: int, y: float = 0.0) -> Vector3:
	var o := cell_origin(cols, rows)
	return Vector3(o.x + (c + 0.5) * CELL, y, o.z + (r + 0.5) * CELL)

## Cell under a world point as Vector2i(col, row), or (-1, -1) outside.
static func world_to_cell(hit: Vector3, cols: int, rows: int) -> Vector2i:
	var o := cell_origin(cols, rows)
	var c := floori((hit.x - o.x) / CELL)
	var r := floori((hit.z - o.z) / CELL)
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

## Bounding box of the whole board, from the table surface up to `height`.
static func board_aabb(cols: int, rows: int, height: float) -> AABB:
	return AABB(cell_origin(cols, rows), Vector3(cols * CELL, height, rows * CELL))
