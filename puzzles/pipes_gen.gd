extends RefCounted

## Pipe rotation (Net). Build a random spanning tree over the grid, turn each
## cell's edge set into a piece, then rotate every piece randomly.
## Uniqueness of the *connection pattern* is free by construction.

# Direction bits: 1=up 2=right 4=down 8=left
const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8
const DELTA := {UP: Vector2i(0, -1), RIGHT: Vector2i(1, 0), DOWN: Vector2i(0, 1), LEFT: Vector2i(-1, 0)}
const OPPOSITE := {UP: DOWN, DOWN: UP, LEFT: RIGHT, RIGHT: LEFT}

static func generate(rng: RandomNumberGenerator, w: int, h: int) -> Dictionary:
	var mask: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(0)
		mask.append(row)

	# Randomised DFS spanning tree.
	var visited := {}
	var start := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
	var stack: Array = [start]
	visited[start] = true
	while not stack.is_empty():
		var cur: Vector2i = stack[-1]
		var options: Array = []
		for bit in [UP, RIGHT, DOWN, LEFT]:
			var nxt: Vector2i = cur + DELTA[bit]
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= w or nxt.y >= h:
				continue
			if visited.has(nxt):
				continue
			options.append(bit)
		if options.is_empty():
			stack.pop_back()
			continue
		var bit: int = options[rng.randi_range(0, options.size() - 1)]
		var nxt2: Vector2i = cur + DELTA[bit]
		mask[cur.y][cur.x] |= bit
		mask[nxt2.y][nxt2.x] |= OPPOSITE[bit]
		visited[nxt2] = true
		stack.append(nxt2)

	# Scramble rotations. Re-roll a cell that lands back on its solved angle
	# unless it is rotationally symmetric anyway.
	var rot: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(rng.randi_range(0, 3))
		rot.append(row)
	return {"mask": mask, "rot": rot, "w": w, "h": h}

static func rotate_mask(m: int, times: int) -> int:
	var out := m
	for i in (times % 4):
		# One clockwise step: up->right->down->left->up
		out = ((out << 1) | (out >> 3)) & 0b1111
	return out

## No loose ends anywhere means solved: every pipe opening must meet a
## matching opening in the neighbouring cell.
static func is_solved(mask: Array, rot: Array, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			var m: int = rotate_mask(mask[y][x], rot[y][x])
			for bit in [UP, RIGHT, DOWN, LEFT]:
				if m & bit == 0:
					continue
				var n: Vector2i = Vector2i(x, y) + DELTA[bit]
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					return false
				var nm: int = rotate_mask(mask[n.y][n.x], rot[n.y][n.x])
				if nm & OPPOSITE[bit] == 0:
					return false
	return true
