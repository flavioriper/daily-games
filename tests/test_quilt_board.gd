extends RefCounted

## Quilt's board (puzzles/quilt2d.gd) rather than its rules: the two things
## that live on the drag and cannot be reached from the state class at all.
## Both are regressions -- they are here because they shipped broken once.
##
## This suite needs a live tree (the board builds a Timer and an Fx2D in
## `_ready`), so everything is in `run_in_tree`.

const State = preload("res://puzzles/quilt_state.gd")

static func run_in_tree(t) -> void:
	_test_no_origin_wraps_off_the_edge(t)
	_test_one_hand_at_a_time(t)

static func _board(seed_value: int, difficulty: int) -> Control:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var board: Control = load("res://puzzles/quilt2d.gd").new()
	board.size = Vector2(1000.0, 1340.0)
	root.add_child(board)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	board.start(rng, difficulty)
	board._layout()
	return board

## Puts the board's hand over the cell (`col`, `row`) with the patch's own
## (0, 0) there, the way a finger holding it HOLD_LIFT above would.
static func _hold(board: Control, p: int, col: int, row: int) -> void:
	var cell: float = board._cell()
	var corner: Vector2 = board._origin() + Vector2(float(col), float(row)) * cell
	board._drag = {
		"patch": p, "grab": Vector2i.ZERO, "from": -1,
		"point": corner + Vector2(0.5, 0.5 + board.HOLD_LIFT) * cell,
		"since": 0.0,
	}

## A point over a cell patch `p` really covers, which is **not** its origin:
## the origin is the top-left of the bounding box, and an L-shaped patch has
## no cell there at all.
static func _on(board: Control, p: int) -> Vector2:
	var st = board._state
	var origin: int = int(st.at[p])
	var first: Vector2i = (st.shapes[p] as Array)[0]
	var cell := Vector2i(origin % st.cols, origin / st.cols) + first
	return board.cell_to_local(cell.y, cell.x)

## A patch held off the side of the quilt must never come back as a legal
## placement. The origin is packed as `row * cols + column`, so a column of
## -1 on row 2 encodes as a cell on row 1 at the far right: before this was
## fixed, dragging a patch off one edge could sew it onto the other, and
## 2,386 of the holds the old guard admitted came back `fits() == OK`.
static func _test_no_origin_wraps_off_the_edge(t) -> void:
	for difficulty in 3:
		var board := _board(700000 + difficulty, difficulty)
		var st = board._state
		var sewn := 0
		var held := 0
		for p in st.shapes.size():
			for r in st.rows:
				for off in [-2, -1, st.cols, st.cols + 1]:
					_hold(board, p, int(off), r)
					held += 1
					var origin: int = board._held_origin()
					if origin >= 0 and st.fits(p, origin) == State.OK:
						sewn += 1
					board._drag = {}
		t.check(held > 0, "quilt band %d: the off-edge probe held nothing" % difficulty)
		t.eq(sewn, 0, "quilt band %d: a hold off the side of the quilt would be sewn on"
			% difficulty)
		board.queue_free()

## A second press while a patch is held must be ignored. `_grab` takes a
## patch off the quilt with `take()`, which pushes no history because the
## matching `drop()` is meant to; overwriting `_drag` therefore used to
## strand the first patch in the rack with no undo entry at all and no move
## counted, and only the second patch was ever resolved.
static func _test_one_hand_at_a_time(t) -> void:
	var board := _board(4242, 1)
	var st = board._state
	for p in 2:
		st.drop(p, int(st.answer[p]), -1)
	var before: int = st.history.size()
	board._grab(_on(board, 0))
	t.check(not board._drag.is_empty(), "quilt: the first patch was not picked up")
	t.eq(int(board._drag["patch"]), 0, "quilt: picked up the wrong patch")
	board._grab(_on(board, 1))
	t.eq(int(board._drag["patch"]), 0, "quilt: a second press stole the hand")
	t.check(int(st.at[1]) >= 0,
		"quilt: a second press took a patch off with no undo entry for it")
	t.eq(st.history.size(), before, "quilt: a second press pushed history of its own")
	board.queue_free()
