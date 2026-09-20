extends RefCounted

## Paper Planes' rules (puzzles/planes_state.gd): the lane, the launch, and
## the generator's one promise -- a board carved backwards out of an empty
## sky can always be cleared.

const State = preload("res://puzzles/planes_state.gd")

static func run(t) -> void:
	_test_lane(t)
	_test_launch(t)

static func _empty(rows: int, cols: int) -> State:
	var st := State.new()
	st.rows = rows
	st.cols = cols
	st.planes = []
	st.order = []
	st.clear_occupancy()
	return st

## A plane laid by hand: cells tail..head, direction taken from the last step.
static func _add(st: State, cells: Array) -> int:
	var typed: Array[Vector2i] = []
	for c in cells:
		typed.append(c)
	return st.add_plane(typed)

## The lane is every cell beyond the head, out to the edge -- and a plane is
## free exactly when nothing stands in it.
static func _test_lane(t) -> void:
	var st := _empty(5, 5)
	# A plane along row 2, heading right, head at (2, 2).
	var a := _add(st, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
	t.eq(st.planes[a]["dir"], Vector2i(1, 0), "the dart heads the way the last step went")
	t.eq(st.lane(a).size(), 2, "two cells between the head and the right edge")
	t.check(st.is_free(a), "an empty lane is a free plane")
	t.eq(st.blocker(a), -1, "nothing blocks it")
	# A second plane standing in that lane.
	var b := _add(st, [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	t.check(not st.is_free(a), "a plane in the lane blocks the launch")
	t.eq(st.blocker(a), b, "and it is named as the blocker")
	t.check(st.is_free(b), "the blocker itself heads down a clear lane")

## A launch empties the plane's cells and can never block anything; an undo
## puts it back exactly as it was.
static func _test_launch(t) -> void:
	var st := _empty(5, 5)
	var a := _add(st, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
	var b := _add(st, [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	t.check(not st.launch(a), "a blocked plane refuses to launch")
	t.eq(st.left(), 2, "and nothing left the board")
	t.check(st.launch(b), "the free one goes")
	t.eq(st.plane_at(Vector2i(4, 1)), -1, "its cells are empty behind it")
	t.check(st.is_free(a), "which frees the one it was blocking")
	t.check(st.launch(a), "and that one goes too")
	t.check(st.solved(), "an empty sky is a solved board")
	t.eq(st.undo(), a, "undo puts the last one back")
	t.check(not st.solved(), "so the board is not solved any more")
	t.eq(st.plane_at(Vector2i(1, 2)), a, "and it is back on its own cells")
