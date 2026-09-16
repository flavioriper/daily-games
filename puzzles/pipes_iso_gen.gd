extends RefCounted

## Pipes' rules and its generator, on an island of blocks. Pure and headless:
## no nodes, no camera, nothing the board owns. The board asks this file what
## a mouth set means, where water can go and what today's island looks like.
## Spec: docs/superpowers/specs/2026-09-15-pipes-iso-design.md.
##
## Columns are indexed (x, z) -- x across, z toward the player -- and each has
## a height in 1 .. levels: blocks fill the levels 0 .. height - 1 and the air
## cell resting on the column's crown is at level `height`. A cell is a
## Vector3i(x, y, z) and one level is one world unit, because a block is a
## unit cube.

# --- directions ---
## The six mouths as bits. The four sides come first, so a loop over SIDES is
## a loop over the horizontal ones.
const N := 1    # -Z, away from the player
const E := 2    # +X
const S := 4    # +Z, toward the player
const W := 8    # -X
const U := 16   # +Y
const D := 32   # -Y
const DIRS := [N, E, S, W, U, D]
const SIDES := [N, E, S, W]
const STEP := {
	N: Vector3i(0, 0, -1), E: Vector3i(1, 0, 0), S: Vector3i(0, 0, 1),
	W: Vector3i(-1, 0, 0), U: Vector3i(0, 1, 0), D: Vector3i(0, -1, 0),
}
const OPPOSITE := {N: S, E: W, S: N, W: E, U: D, D: U}
const VERTICAL := U | D

# --- kinds ---
## What the tray can hold. The cross is deliberately absent: with one source
## and no loops it never appears in a solution, so a tray item you never need
## would be noise. Its model and its slot stay, for the day loops or a second
## source arrive.
const KINDS := ["straight", "elbow", "tee", "pump"]
## The mouth set each kind's model is modelled with. Must keep agreeing with
## core/placeholders.gd and art/pipes.blend.
const REFERENCE := {
	"straight": N | S,
	"elbow": N | E,
	"tee": N | E | S,
	"pump": U | D,
}
const SLOT := {
	"straight": "pipe_straight", "elbow": "pipe_elbow",
	"tee": "pipe_tee", "pump": "pump",
	"source": "source_tank", "drain": "drain_pool",
}
## The two fixtures carry one mouth, modelled toward N like every other piece,
## and they stand on a crown: the board turns them about the vertical only, so
## the generator must hand them a horizontal mouth (see `_walk`).
const FIXTURE_REFERENCE := N
## The fixtures the generator places and the player cannot move.
const FIXTURES := ["source", "drain"]

# --- the difficulty table (spec section 8) ---
const DIFFICULTY := [
	{"cols": 4, "rows": 4, "levels": 3, "drains": 1, "climbs": [0, 1], "route": [5, 8], "spares": 0, "hidden": 0},
	{"cols": 5, "rows": 5, "levels": 4, "drains": 1, "climbs": [1, 1], "route": [8, 12], "spares": 1, "hidden": 1},
	{"cols": 6, "rows": 6, "levels": 5, "drains": 2, "climbs": [1, 2], "route": [12, 18], "spares": 2, "hidden": 2},
]
## How many whole islands to try before giving up, and how many terrains to
## try per route before throwing the route away too.
const ATTEMPTS := 60
const TERRAIN_TRIES := 12
const ROUTE_TRIES := 200
## How many of a two-drain day's pieces the branch is allowed, taken out of
## the difficulty's route length rather than added to it.
const BRANCH_RESERVE := 4
## The direction from the board toward the camera at the first stop (pitch 35,
## yaw 45, the rig's own view_offset_dir). The occlusion check marches along
## it, so it has to be the same angle the player will be looking from.
const VIEW_PITCH := 35.0
const VIEW_YAW := 45.0

# --- rotations and mouth sets ---

static var _rotations: Array[Basis] = []

## The 24 ways a piece can be turned: every basis whose columns are signed
## unit axes and whose determinant is +1 (the other 24 are mirrors, which a
## solid piece cannot be turned into). Built once; a piece's orientation is
## one of these rather than a quarter turn, because a vertical run needs the
## model laid on its side.
static func rotations() -> Array[Basis]:
	if not _rotations.is_empty():
		return _rotations
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for perm in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		for signs in 8:
			var cols: Array[Vector3] = []
			for i in 3:
				cols.append(axes[perm[i]] * (-1.0 if signs & (1 << i) else 1.0))
			var basis := Basis(cols[0], cols[1], cols[2])
			if basis.determinant() > 0.5:
				_rotations.append(basis)
	return _rotations

## The bit whose step is `step`, or 0.
static func bit_for(step: Vector3i) -> int:
	for bit in DIRS:
		if STEP[bit] == step:
			return bit
	return 0

## `mask` turned by `basis`: every mouth's step goes through the basis and the
## bit is read back off the result. One function for every kind and every
## axis, which is why orientations are never tabulated here.
static func rotate_mask(mask: int, basis: Basis) -> int:
	var out := 0
	for bit in DIRS:
		if mask & bit == 0:
			continue
		var v: Vector3 = basis * Vector3(STEP[bit])
		out |= bit_for(Vector3i(roundi(v.x), roundi(v.y), roundi(v.z)))
	return out

## Every distinct mouth set `reference` can be turned into, as
## [{"mask": int, "basis": Basis}], in the stable order of rotations(). The
## board cycles a piece through these, and the generator asks the same
## question when it needs a piece that connects.
static func orientations(reference: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for basis in rotations():
		var mask := rotate_mask(reference, basis)
		if seen.has(mask):
			continue
		seen[mask] = true
		out.append({"mask": mask, "basis": basis})
	return out

## Every orientation of `kind`, cached per kind. The pump is the exception:
## geometrically it is a straight and turns three ways, but it is only ever
## legal standing up -- it is the piece that lifts water -- so it is offered
## the one way it means anything.
static var _by_kind: Dictionary = {}
static func kind_orientations(kind: String) -> Array[Dictionary]:
	if not _by_kind.has(kind):
		var all := orientations(int(REFERENCE.get(kind, 0)))
		if kind == "pump":
			var upright: Array[Dictionary] = []
			for o in all:
				if int(o.mask) == VERTICAL:
					upright.append(o)
			all = upright
		_by_kind[kind] = all
	return _by_kind[kind]

## The basis that turns `kind`'s model onto `mask`, or the identity when the
## kind cannot make that mouth set.
static func basis_for(kind: String, mask: int) -> Basis:
	for o in kind_orientations(kind):
		if int(o.mask) == mask:
			return o.basis
	return Basis()

static func bits(mask: int) -> Array:
	var out: Array = []
	for bit in DIRS:
		if mask & bit != 0:
			out.append(bit)
	return out

static func count_bits(mask: int) -> int:
	return bits(mask).size()

## The kind a mouth set needs, or "" when no piece in the tray can make it.
## A vertical pair comes back as a straight, never as a pump: a pump is a
## choice the generator or the player makes, not something a mouth set can
## imply, and the two are otherwise the same shape.
static func mask_kind(mask: int) -> String:
	var n := count_bits(mask)
	if n == 2:
		for bit in bits(mask):
			if mask & OPPOSITE[bit] != 0:
				return "straight"
		return "elbow"
	if n == 3:
		# A tee is a through pair plus a branch; three mouths with no opposite
		# pair is a corner of three, which no piece in the tray makes.
		for bit in bits(mask):
			if mask & OPPOSITE[bit] != 0:
				return "tee"
		return ""
	return ""

# --- terrain ---

static func in_bounds(x: int, z: int, cols: int, rows: int) -> bool:
	return x >= 0 and z >= 0 and x < cols and z < rows

static func height_at(heights: Array, x: int, z: int) -> int:
	return int(heights[z][x])

## The air cell resting on the crown of column (x, z).
static func crown(heights: Array, x: int, z: int) -> Vector3i:
	return Vector3i(x, height_at(heights, x, z), z)

## Air means inside the columns and at or above that column's crown. The
## ceiling is one level above the tallest column, which is as high as any
## route ever reaches.
static func is_air(cell: Vector3i, heights: Array, cols: int, rows: int, levels: int) -> bool:
	if not in_bounds(cell.x, cell.z, cols, rows):
		return false
	if cell.y > levels:
		return false
	return cell.y >= height_at(heights, cell.x, cell.z)

## The standing rule: a piece rests on the ground -- the cell under it is a
## block -- unless it has an up or a down mouth, in which case it may hang in
## a vertical run. So a drop and a climb are possible and a bridge through the
## sky is not.
static func stands(cell: Vector3i, mask: int, heights: Array, cols: int, rows: int, levels: int) -> bool:
	if not is_air(cell, heights, cols, rows, levels):
		return false
	if mask & VERTICAL != 0:
		return true
	return cell.y == height_at(heights, cell.x, cell.z)

# --- the water ---

## The vertical runs over `pieces`: each maximal stack joined by up/down
## mouths, with whether any piece in it is a pump. Water climbs a whole run
## or none of it, so this is what an upward step has to ask.
static func vertical_runs(pieces: Dictionary) -> Dictionary:
	var run_of: Dictionary = {}
	var runs: Array = []
	for cell in pieces:
		if run_of.has(cell):
			continue
		var index := runs.size()
		var stack: Array = [cell]
		var cells: Array = []
		run_of[cell] = index
		var pumped := false
		while not stack.is_empty():
			var cur: Vector3i = stack.pop_back()
			cells.append(cur)
			if String(pieces[cur].get("kind", "")) == "pump":
				pumped = true
			for bit in [U, D]:
				var m: int = int(pieces[cur].mask)
				if m & bit == 0:
					continue
				var n: Vector3i = cur + STEP[bit]
				if not pieces.has(n) or run_of.has(n):
					continue
				if int(pieces[n].mask) & OPPOSITE[bit] == 0:
					continue
				run_of[n] = index
				stack.append(n)
		runs.append({"cells": cells, "pumped": pumped})
	return {"run_of": run_of, "runs": runs}

## Where the water gets to, as {cell: depth} from `source`. A step along the
## level or downward is free; an upward step is taken only inside a run that
## holds a pump. Depth is the breadth-first distance, which is what makes the
## board's wetting wave race outward from the source.
static func flow(pieces: Dictionary, source: Vector3i) -> Dictionary:
	var fed: Dictionary = {}
	if not pieces.has(source):
		return {"fed": fed, "runs": [], "run_of": {}}
	var grouped := vertical_runs(pieces)
	var run_of: Dictionary = grouped.run_of
	var runs: Array = grouped.runs
	fed[source] = 0
	var queue: Array[Vector3i] = [source]
	var head := 0
	while head < queue.size():
		var cur: Vector3i = queue[head]
		head += 1
		var depth: int = int(fed[cur]) + 1
		var mask: int = int(pieces[cur].mask)
		for bit in bits(mask):
			var n: Vector3i = cur + STEP[bit]
			if fed.has(n) or not pieces.has(n):
				continue
			if int(pieces[n].mask) & OPPOSITE[bit] == 0:
				continue
			if bit == U and not bool(runs[int(run_of[cur])].pumped):
				continue
			fed[n] = depth
			queue.append(n)
	return {"fed": fed, "runs": runs, "run_of": run_of}

## Whether a mouth meets a matching mouth next door.
static func meets(pieces: Dictionary, cell: Vector3i, bit: int) -> bool:
	var n: Vector3i = cell + STEP[bit]
	if not pieces.has(n):
		return false
	return int(pieces[n].mask) & OPPOSITE[bit] != 0

## Every fed mouth that meets nothing, as [{"cell":, "bit":, "depth":}],
## nearest the source first. Water pouring out of one is how the board shows
## where the pipeline is still broken; the board draws only the first few.
static func leaks(pieces: Dictionary, fed: Dictionary) -> Array:
	var out: Array = []
	for cell in fed:
		for bit in bits(int(pieces[cell].mask)):
			if meets(pieces, cell, bit):
				continue
			out.append({"cell": cell, "bit": bit, "depth": int(fed[cell])})
	out.sort_custom(func(a, b) -> bool:
		if int(a.depth) != int(b.depth):
			return int(a.depth) < int(b.depth)
		var ca: Vector3i = a.cell
		var cb: Vector3i = b.cell
		if ca != cb:
			return [ca.y, ca.z, ca.x] < [cb.y, cb.z, cb.x]
		return int(a.bit) < int(b.bit))
	return out

## Solved: every drain fed and no fed mouth leaking. Pieces left in the tray
## are fine, and so are dry ones standing about -- they just do not count.
static func is_solved(pieces: Dictionary, source: Vector3i, drains: Array) -> bool:
	var out := flow(pieces, source)
	var fed: Dictionary = out.fed
	for drain in drains:
		if not fed.has(drain):
			return false
	return leaks(pieces, fed).is_empty()

# --- the generator ---

## Today's island: terrain, fixtures, the route that solves it and the tray
## that can build the route. `ok` is false when nothing worth playing turned
## up, the way horse_gen gives up.
static func generate(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var d: Dictionary = DIFFICULTY[clampi(difficulty, 0, DIFFICULTY.size() - 1)]
	# A two-drain day spends part of its route budget on the branch, so the
	# walk is asked for a shorter main line rather than the table's length
	# plus a branch on top.
	var reserve := BRANCH_RESERVE if int(d.drains) > 1 else 0
	for _attempt in ATTEMPTS:
		var walk := _walk(rng, d, reserve)
		if walk.is_empty():
			continue
		var out := _dress(rng, d, walk)
		if out.is_empty():
			continue
		if verify(out):
			return out
	return {"ok": false, "cols": int(d.cols), "rows": int(d.rows), "levels": int(d.levels),
		"heights": _flat_heights(int(d.cols), int(d.rows)), "source": Vector3i.ZERO,
		"source_mask": N, "drains": [], "solution": {}, "route": [], "tray": {}, "hidden": 0}

static func _flat_heights(cols: int, rows: int) -> Array:
	var heights: Array = []
	for _z in rows:
		var row: Array = []
		for _x in cols:
			row.append(1)
		heights.append(row)
	return heights

## The route, as a list of cells from the source's own cell to the drain's,
## plus the columns it fixed and where the climbs are. Every move ends on a
## column's crown, so the first cell and the last one always rest on ground.
## A column is used at most once, which makes the route self-avoiding in
## three dimensions for free.
static func _walk(rng: RandomNumberGenerator, d: Dictionary, reserve := 0) -> Dictionary:
	var cols := int(d.cols)
	var rows := int(d.rows)
	var levels := int(d.levels)
	var want_pieces := maxi(rng.randi_range(int(d.route[0]), int(d.route[1])) - reserve, 3)
	var want_climbs := rng.randi_range(int(d.climbs[0]), int(d.climbs[1]))
	var far := int((cols + rows) / 3.0)
	for _try in ROUTE_TRIES:
		var start := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		# The tank stands high: the first drop is what the player sees first.
		var y := levels if levels < 3 else rng.randi_range(levels - 1, levels)
		var fixed: Dictionary = {start: y}
		var route: Array[Vector3i] = [Vector3i(start.x, y, start.y)]
		var climbs: Array = []          # one array of cells per climbing run
		var at := start
		var level_last := false
		var guard := 0
		while guard < 400:
			guard += 1
			# The route holds the source, then the pieces, and its last cell
			# will be the drain: two of its cells are never tray pieces.
			var pieces := route.size() - 2
			var done := pieces >= want_pieces and climbs.size() == want_climbs
			# ... and the last move was a step along the level, so the mouth
			# the drain offers is horizontal. A drain at the foot of a drop
			# would want its arm pointing at the sky, and the pool is modelled
			# standing on a crown.
			# The source and the drain want to be far apart, but not at the
			# cost of a route much longer than the difficulty asked for: past
			# a couple of spare pieces the walk takes what it has.
			var far_enough := _column_gap(start, at) >= far or pieces >= want_pieces + 2
			if done and level_last and far_enough:
				return {"route": route, "fixed": fixed, "climbs": climbs,
					"cols": cols, "rows": rows, "levels": levels}
			# Once the route is as long as it was asked to be and every climb
			# is in, only steps along the level are offered: the walk has to
			# end on one (the drain's mouth is horizontal), and a drop taken
			# now would just make the route longer than the difficulty says.
			var enough := pieces >= want_pieces and climbs.size() == want_climbs
			var moves := _moves(rng, at, y, fixed, cols, rows, levels,
				climbs.size() < want_climbs, pieces, want_pieces, enough)
			if moves.is_empty():
				break
			var move: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
			var col: Vector2i = move.col
			fixed[col] = int(move.floor_y)
			for cell in move.cells:
				route.append(cell)
			if String(move.kind) == "climb":
				climbs.append(move.cells)
			level_last = String(move.kind) == "level"
			at = col
			y = int(move.top_y)
	return {}

static func _column_gap(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## Every move available from the crown of column `at` at level `y`: a step
## along the level, a drop of one or more, or a climb of two or more (a climb
## needs a vertical straight between its elbows for the pump to go in). Only
## columns the route has not used already, so nothing can contradict a height
## it has already fixed.
static func _moves(rng: RandomNumberGenerator, at: Vector2i, y: int, fixed: Dictionary,
		cols: int, rows: int, levels: int, want_climb: bool, pieces: int, want_pieces: int,
		only_level := false) -> Array:
	var out: Array = []
	var room := want_pieces - pieces          # how many pieces are still wanted
	for bit in SIDES:
		var step: Vector3i = STEP[bit]
		var col := at + Vector2i(step.x, step.z)
		if not in_bounds(col.x, col.y, cols, rows) or fixed.has(col):
			continue
		out.append({"kind": "level", "col": col, "floor_y": y, "top_y": y,
			"cells": [Vector3i(col.x, y, col.y)] as Array[Vector3i]})
		if only_level:
			continue
		for j in range(1, y):
			# A drop of j: the cell over the lower column hangs with a down
			# mouth, j - 1 straights hang under it, and the elbow at the
			# bottom rests on that column's crown. It has to fit in what is
			# left of the route's length -- when nothing is left there are
			# still steps along the level to take, so a drop is simply not
			# offered rather than allowed to overshoot.
			if j + 1 > room:
				break
			var cells: Array[Vector3i] = []
			for k in range(0, j + 1):
				cells.append(Vector3i(col.x, y - k, col.y))
			out.append({"kind": "drop", "col": col, "floor_y": y - j, "top_y": y - j, "cells": cells})
		if not want_climb:
			continue
		for j in range(2, levels - y + 1):
			# A climb is owed, so the shortest one -- two elbows and the pump
			# between them -- is offered even when the route has no room left.
			# Anything longer has to fit.
			if j + 1 > maxi(room, 3):
				break
			var up: Array[Vector3i] = []
			for k in range(0, j + 1):
				up.append(Vector3i(col.x, y + k, col.y))
			out.append({"kind": "climb", "col": col, "floor_y": y, "top_y": y + j, "cells": up})
	return out

## The route's pieces, the terrain around it, the tray and the occlusion
## check: everything that turns a walk into a day. Empty when the terrain
## could not be made to hide enough of the route.
static func _dress(rng: RandomNumberGenerator, d: Dictionary, walk: Dictionary) -> Dictionary:
	var cols := int(walk.cols)
	var rows := int(walk.rows)
	var levels := int(walk.levels)
	var route: Array = walk.route
	var fixed: Dictionary = walk.fixed
	var solution: Dictionary = {}
	var steps: Array = []
	for i in range(0, route.size() - 1):
		steps.append(bit_for(route[i + 1] - route[i]))
	for i in range(1, route.size() - 1):
		var mask: int = OPPOSITE[steps[i - 1]] | int(steps[i])
		var kind := mask_kind(mask)
		if kind == "":
			return {}
		solution[route[i]] = {"kind": kind, "mask": mask}
	# One piece of every climb becomes the pump: whichever of its vertical
	# straights the day picks. A climb without one is a climb the water will
	# not take, which is the whole point of the piece.
	for climb in walk.climbs:
		var risers: Array = []
		for cell in climb:
			if solution.has(cell) and int(solution[cell].mask) == VERTICAL:
				risers.append(cell)
		if risers.is_empty():
			return {}
		var pick: Vector3i = risers[rng.randi_range(0, risers.size() - 1)]
		solution[pick] = {"kind": "pump", "mask": VERTICAL}

	var source: Vector3i = route[0]
	var source_mask: int = int(steps[0])
	var drains: Array = [route[route.size() - 1]]
	var drain_masks: Dictionary = {drains[0]: OPPOSITE[steps[steps.size() - 1]]}

	if int(d.drains) > 1:
		# A day that asks for two drains and cannot grow the second one is
		# thrown away rather than shipped a drain short: the tee is the only
		# thing that gives that piece a job.
		var branch := _branch(rng, route, solution, fixed, cols, rows, levels, BRANCH_RESERVE)
		if branch.is_empty():
			return {}
		solution[branch.at] = {"kind": "tee", "mask": int(branch.mask)}
		for cell in branch.solution:
			solution[cell] = branch.solution[cell]
		for col in branch.fixed:
			fixed[col] = int(branch.fixed[col])
		drains.append(branch.drain)
		drain_masks[branch.drain] = int(branch.drain_mask)
		# The branch's cells join the route after the main line, so a hint
		# walks the whole pipeline in an order that always grows out of
		# something already standing -- the tee first, then its branch.
		for cell in branch.cells:
			route.append(cell)

	var heights: Array = []
	var hidden := 0
	for _t in TERRAIN_TRIES:
		heights = _terrain(rng, fixed, cols, rows, levels)
		hidden = hidden_cells(route, heights, cols, rows)
		if hidden >= int(d.hidden):
			break
		heights = _raise_cover(rng, route, heights, fixed, cols, rows, levels)
		hidden = hidden_cells(route, heights, cols, rows)
		if hidden >= int(d.hidden):
			break
	if hidden < int(d.hidden):
		return {}

	var tray: Dictionary = {}
	for cell in solution:
		var kind := String(solution[cell].kind)
		tray[kind] = int(tray.get(kind, 0)) + 1
	# Spares are decoys drawn from the kinds the route already needs, so the
	# tray's counts cannot be read as the answer.
	var kinds: Array = tray.keys()
	for _s in int(d.spares):
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		tray[kind] = int(tray[kind]) + 1

	return {"ok": true, "cols": cols, "rows": rows, "levels": levels, "heights": heights,
		"source": source, "source_mask": source_mask, "drains": drains,
		"drain_masks": drain_masks, "route": route, "solution": solution,
		"tray": tray, "hidden": hidden}

## A second drain, grown off a route cell that becomes a tee. The branch runs
## level and downhill only: with no pump in it, that is the whole of what
## water will do, so it needs no climb to be solvable.
static func _branch(rng: RandomNumberGenerator, route: Array, solution: Dictionary,
		fixed: Dictionary, cols: int, rows: int, levels: int, budget: int) -> Dictionary:
	var spots: Array = []
	for i in range(1, route.size() - 1):
		var cell: Vector3i = route[i]
		if not solution.has(cell):
			continue
		var mask: int = int(solution[cell].mask)
		# Only a cell whose mouths are both horizontal and which stands on its
		# own crown: a hanging tee would need a third mouth up or down, and
		# that is a shape the branch has no use for.
		if mask & VERTICAL != 0 or cell.y != int(fixed.get(Vector2i(cell.x, cell.z), -1)):
			continue
		for bit in SIDES:
			if mask & bit != 0:
				continue
			var step: Vector3i = STEP[bit]
			var col := Vector2i(cell.x + step.x, cell.z + step.z)
			if not in_bounds(col.x, col.y, cols, rows) or fixed.has(col):
				continue
			spots.append({"cell": cell, "mask": mask | bit, "bit": bit})
	if spots.is_empty():
		return {}
	var spot: Dictionary = spots[rng.randi_range(0, spots.size() - 1)]
	var at: Vector3i = spot.cell
	var taken: Dictionary = fixed.duplicate()
	var branch_fixed: Dictionary = {}
	var cells: Array[Vector3i] = [at]
	var y := at.y
	var col := Vector2i(at.x, at.z)
	var bit: int = spot.bit
	var length := rng.randi_range(2, 4)
	for _i in length:
		if cells.size() - 1 >= budget:
			break
		var options: Array = []
		for side in SIDES:
			if cells.size() == 1 and side != bit:
				continue
			var side_step: Vector3i = STEP[side]
			var next := Vector2i(col.x + side_step.x, col.y + side_step.z)
			if not in_bounds(next.x, next.y, cols, rows) or taken.has(next):
				continue
			var room: int = budget - (cells.size() - 1)
			options.append({"col": next, "side": side, "drop": 0})
			for j in range(1, y):
				if j + 1 > maxi(room, 2):
					break
				options.append({"col": next, "side": side, "drop": j})
		if options.is_empty():
			break
		var move: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		var next_col: Vector2i = move.col
		var side: int = move.side
		var drop := int(move.drop)
		for k in range(0, drop + 1):
			cells.append(Vector3i(next_col.x, y - k, next_col.y))
		taken[next_col] = y - drop
		branch_fixed[next_col] = y - drop
		col = next_col
		y -= drop
		bit = side
	# The branch's own drain wants a horizontal mouth as well, so a branch
	# that ended by dropping is thrown back.
	if cells.size() < 3 or bit_for(cells[cells.size() - 1] - cells[cells.size() - 2]) & VERTICAL != 0:
		return {}
	var out: Dictionary = {}
	var steps: Array = []
	for i in range(0, cells.size() - 1):
		steps.append(bit_for(cells[i + 1] - cells[i]))
	for i in range(1, cells.size() - 1):
		var mask: int = OPPOSITE[steps[i - 1]] | int(steps[i])
		var kind := mask_kind(mask)
		if kind == "":
			return {}
		out[cells[i]] = {"kind": kind, "mask": mask}
	return {"at": at, "mask": int(spot.mask), "solution": out, "fixed": branch_fixed,
		"cells": cells.slice(1), "drain": cells[cells.size() - 1],
		"drain_mask": OPPOSITE[steps[steps.size() - 1]]}

## Heights for every column: the route's own columns take the level of the
## lowest route cell over them -- which is the floor of a horizontal cell and
## the foot of a drop or a climb alike -- and the rest are rolled at random
## and then relaxed toward their neighbours, so the ground reads as ground
## rather than as noise.
static func _terrain(rng: RandomNumberGenerator, fixed: Dictionary, cols: int, rows: int, levels: int) -> Array:
	var heights: Array = []
	for z in rows:
		var row: Array = []
		for x in cols:
			var col := Vector2i(x, z)
			row.append(int(fixed[col]) if fixed.has(col) else rng.randi_range(1, levels))
		heights.append(row)
	for _pass in 2:
		for z in rows:
			for x in cols:
				if fixed.has(Vector2i(x, z)):
					continue
				var sum := 0
				var n := 0
				for bit in SIDES:
					var step: Vector3i = STEP[bit]
					var nx: int = x + step.x
					var nz: int = z + step.z
					if not in_bounds(nx, nz, cols, rows):
						continue
					sum += int(heights[nz][nx])
					n += 1
				if n == 0:
					continue
				var mean := float(sum) / float(n)
				var jitter := rng.randi_range(-1, 1) if rng.randf() < 0.35 else 0
				heights[z][x] = clampi(int(roundf(mean)) + jitter, 1, levels)
	return heights

## Raises one column that stands between the camera and a route cell, so a
## board that showed the whole route from the first stop stops doing so.
## Turning the island is only a puzzle if something is hidden.
static func _raise_cover(rng: RandomNumberGenerator, route: Array, heights: Array,
		fixed: Dictionary, cols: int, rows: int, levels: int) -> Array:
	var dir := view_dir()
	var candidates: Array = []
	for entry in route:
		var cell: Vector3i = entry
		for t in [0.8, 1.4, 2.0, 2.6]:
			var p: Vector3 = Vector3(cell.x + 0.5, float(cell.y) + 0.25, cell.z + 0.5) + dir * float(t)
			var col := Vector2i(floori(p.x), floori(p.z))
			if not in_bounds(col.x, col.y, cols, rows) or fixed.has(col):
				continue
			if p.y <= float(heights[col.y][col.x]):
				continue   # already covered from here
			candidates.append({"col": col, "to": int(ceili(p.y))})
	if candidates.is_empty():
		return heights
	var pick: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var col: Vector2i = pick.col
	heights[col.y][col.x] = clampi(int(pick.to), 1, levels)
	return heights

## The direction from the board toward the camera at the first stop.
static func view_dir() -> Vector3:
	var pitch := deg_to_rad(VIEW_PITCH)
	var yaw := deg_to_rad(VIEW_YAW)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()

## How many route cells the ground hides from the first camera stop: march
## from the cell toward the camera and ask whether the ray passes under a
## column's crown. Exact enough for a heightfield, and it runs headless,
## which a real occlusion test would not.
static func hidden_cells(route: Array, heights: Array, cols: int, rows: int) -> int:
	var dir := view_dir()
	var count := 0
	for entry in route:
		var cell: Vector3i = entry
		var at := Vector3(cell.x + 0.5, float(cell.y) + 0.25, cell.z + 0.5)
		var t := 0.3
		while t < 14.0:
			var p: Vector3 = at + dir * t
			t += 0.2
			var col := Vector2i(floori(p.x), floori(p.z))
			if not in_bounds(col.x, col.y, cols, rows):
				continue
			if p.y < float(heights[col.y][col.x]):
				count += 1
				break
	return count

## The pieces an island's own solution puts on the board, fixtures included:
## what the verifier floods and what a hint reads.
static func solution_pieces(out: Dictionary) -> Dictionary:
	var pieces: Dictionary = {}
	for cell in out.solution:
		pieces[cell] = {"kind": String(out.solution[cell].kind), "mask": int(out.solution[cell].mask)}
	pieces[out.source] = {"kind": "source", "mask": int(out.source_mask)}
	for drain in out.drains:
		pieces[drain] = {"kind": "drain", "mask": int(out.drain_masks[drain])}
	return pieces

## The generator checking its own work with the board's rules: every drain
## fed, nothing leaking, every piece standing legally and every climb pumped.
## A day that fails this is thrown away rather than shipped.
static func verify(out: Dictionary) -> bool:
	if not bool(out.get("ok", false)):
		return false
	var pieces := solution_pieces(out)
	var cols := int(out.cols)
	var rows := int(out.rows)
	var levels := int(out.levels)
	for cell in pieces:
		if not stands(cell, int(pieces[cell].mask), out.heights, cols, rows, levels):
			return false
	var flowed := flow(pieces, out.source)
	var fed: Dictionary = flowed.fed
	for drain in out.drains:
		if not fed.has(drain):
			return false
	if not leaks(pieces, fed).is_empty():
		return false
	if fed.size() != pieces.size():
		return false
	return true
