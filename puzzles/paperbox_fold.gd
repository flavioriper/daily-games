extends RefCounted

## Paper Box's fold (spec docs/superpowers/specs/2026-10-22-paperbox-design.md):
## a net of six paper squares folded into a box, and what a box shows from
## its corner. Scene-free and static; the rules (puzzles/paperbox_state.gd),
## the drawing (ui/faces/paperbox_art.gd) and the fold the board plays all
## stand on these same frames, so a box drawn is a box folded.
##
## **The fold.** The net lies flat at z = 0, every square a unit square at
## its grid place, painted side up (+z). One square, the root, stays put; the
## others hinge down (-z) about the edge they share with the square they
## hang from, so the paint ends outside and the box sits under the root.
## `frames(net, root, angle)` gives each square's frame at a hinge angle:
## the flat net at 0, the box at PI / 2. A square's local point (u, v, w),
## u and v across it from its low corner and w out of its paint, lands at
## `frame * Vector3(u, v, w)`.
##
## **A view** is one of the box's 24 turns. The box is drawn from the
## corner between +x, +y and +z (`project`), so a picture is three faces:
## the top (+z), the right (+x) and the left (+y), each a colour and, on
## Insane, the way its stamp points (a world direction along the face).

## The eleven nets of a cube, squares at [x, y]. The first six are the
## crosses (a row of four, one square over it and one under), Easy's.
const NETS := [
	[[0, 1], [1, 1], [2, 1], [3, 1], [0, 0], [0, 2]],
	[[0, 1], [1, 1], [2, 1], [3, 1], [0, 0], [1, 2]],
	[[0, 1], [1, 1], [2, 1], [3, 1], [0, 0], [2, 2]],
	[[0, 1], [1, 1], [2, 1], [3, 1], [0, 0], [3, 2]],
	[[0, 1], [1, 1], [2, 1], [3, 1], [1, 0], [1, 2]],
	[[0, 1], [1, 1], [2, 1], [3, 1], [1, 0], [2, 2]],
	[[0, 0], [1, 0], [1, 1], [2, 1], [3, 1], [1, 2]],
	[[0, 0], [1, 0], [1, 1], [2, 1], [3, 1], [2, 2]],
	[[0, 0], [1, 0], [1, 1], [2, 1], [3, 1], [3, 2]],
	[[0, 0], [1, 0], [1, 1], [2, 1], [2, 2], [3, 2]],
	[[0, 0], [1, 0], [2, 0], [2, 1], [3, 1], [4, 1]],
]
## How many of NETS are crosses.
const CROSSES := 6

## The three faces a picture shows, in its order: top, right, left.
const SHOWN := [Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)]
## A stamp's way across its square, by its index: +u, +v, -u, -v.
const WAYS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## The iso projection's slopes: cos 30 and sin 30.
const C30 := 0.8660254
const S30 := 0.5

static var _turns: Array[Basis] = []

## A net turned a quarter `q` times and mirrored when `flip`, moved back to
## start at [0, 0]: Array of Vector2i.
static func placed(index: int, q: int, flip: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Array in NETS[index]:
		var p := Vector2i(int(c[0]), int(c[1]))
		if flip:
			p.x = -p.x
		for i in q % 4:
			p = Vector2i(-p.y, p.x)
		out.append(p)
	var lo := Vector2i(1 << 20, 1 << 20)
	for p in out:
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
	for i in out.size():
		out[i] -= lo
	return out

## The net's size in squares.
static func extent(net: Array[Vector2i]) -> Vector2i:
	var hi := Vector2i.ZERO
	for p in net:
		hi = Vector2i(maxi(hi.x, p.x + 1), maxi(hi.y, p.y + 1))
	return hi

## The squares' tree from `root`: per square, the square it hangs from (-1
## for the root), in the order they are reached (root first).
static func tree(net: Array[Vector2i], root: int) -> Dictionary:
	var parent: Array[int] = []
	for i in net.size():
		parent.append(-2)
	parent[root] = -1
	var order: Array[int] = [root]
	var head := 0
	while head < order.size():
		var a := order[head]
		head += 1
		for b in net.size():
			if parent[b] == -2 and absi(net[a].x - net[b].x) + absi(net[a].y - net[b].y) == 1:
				parent[b] = a
				order.append(b)
	return {"parent": parent, "order": order}

## Each square's frame with its hinge at `angles[i]` (radians, 0 flat, PI/2
## folded; the root's is unused). `angles` may be one float for every hinge.
static func frames(net: Array[Vector2i], root: int, angles) -> Array[Transform3D]:
	var t := tree(net, root)
	var parent: Array[int] = t.parent
	var out: Array[Transform3D] = []
	out.resize(net.size())
	for i: int in t.order:
		if parent[i] < 0:
			out[i] = Transform3D(Basis(), Vector3(net[i].x, net[i].y, 0.0))
			continue
		var a: float = float(angles[i]) if angles is Array else float(angles)
		var d := net[i] - net[parent[i]]
		var hinge: Transform3D
		if d == Vector2i(1, 0):
			hinge = Transform3D(Basis(Vector3.UP, a), Vector3(1, 0, 0))
		elif d == Vector2i(-1, 0):
			hinge = Transform3D(Basis(Vector3.UP, -a), Vector3.ZERO) * Transform3D(Basis(), Vector3(-1, 0, 0))
		elif d == Vector2i(0, 1):
			hinge = Transform3D(Basis(Vector3.RIGHT, -a), Vector3(0, 1, 0))
		else:
			hinge = Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, -1, 0))
		out[i] = out[parent[i]] * hinge
	return out

## The middle of the box the net folds into, in the net's own space.
static func box_centre(net: Array[Vector2i], root: int) -> Vector3:
	return Vector3(net[root].x + 0.5, net[root].y + 0.5, -0.5)

static func _round(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x), roundi(v.y), roundi(v.z))

## The folded box: per side (its outward normal), [colour, stamp way (a
## world direction along the side, ZERO when unstamped)].
static func folded(net: Array[Vector2i], root: int, colours: Array, ways: Array) -> Dictionary:
	var f := frames(net, root, PI * 0.5)
	var out := {}
	for i in net.size():
		var n := _round(f[i].basis * Vector3(0, 0, 1))
		var m := Vector3i.ZERO
		if int(ways[i]) >= 0:
			var w: Vector2i = WAYS[int(ways[i])]
			m = _round(f[i].basis * Vector3(w.x, w.y, 0))
		out[n] = [int(colours[i]), m]
	return out

## The box's 24 turns.
static func turns() -> Array[Basis]:
	if not _turns.is_empty():
		return _turns
	var axes := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	for a in 3:
		for b in 3:
			if b == a:
				continue
			for sa in [1.0, -1.0]:
				for sb in [1.0, -1.0]:
					var x: Vector3 = axes[a] * sa
					var y: Vector3 = axes[b] * sb
					_turns.append(Basis(x, y, x.cross(y)))
	return _turns

## What the box `sides` (folded()) shows turned by `turn`: [[colour, way]
## for the top, the right and the left].
static func picture(sides: Dictionary, turn: Basis) -> Array:
	var out := []
	for shown: Vector3i in SHOWN:
		for n: Vector3i in sides:
			if _round(turn * Vector3(n)) == shown:
				var m: Vector3i = sides[n][1]
				out.append([int(sides[n][0]), _round(turn * Vector3(m))])
				break
	return out

## Every picture the box can show, by key.
static func pictures(sides: Dictionary) -> Dictionary:
	var out := {}
	for turn in turns():
		out[key(picture(sides, turn))] = true
	return out

static func key(pic: Array) -> String:
	var parts := PackedStringArray()
	for f: Array in pic:
		var m: Vector3i = f[1]
		parts.append("%d:%d,%d,%d" % [int(f[0]), m.x, m.y, m.z])
	return "|".join(parts)

## The colour on the side opposite the shown face `slot`.
static func opposite(sides: Dictionary, turn: Basis, slot: int) -> Array:
	var away: Vector3i = -SHOWN[slot]
	for n: Vector3i in sides:
		if _round(turn * Vector3(n)) == away:
			return [int(sides[n][0]), _round(turn * Vector3(sides[n][1] as Vector3i))]
	return [0, Vector3i.ZERO]

## A world point on the iso view, before scale: x and y lean down to the
## right and left, z goes up.
static func project(p: Vector3) -> Vector2:
	return Vector2((p.x - p.y) * C30, (p.x + p.y) * S30 - p.z)
