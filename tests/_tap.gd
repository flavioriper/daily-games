extends SceneTree

var _frames := 0
var _menu: Node
var _puzzle: Node

func _initialize() -> void:
	_menu = load("res://ui/menu.tscn").instantiate()
	root.add_child(_menu)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20:
		_menu._open(load("res://ui/registry.gd").PUZZLES[0])
	if _frames == 40:
		var host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = host._puzzle
		print("grid n=", _puzzle.n, " cell=", _puzzle._cell, " origin=", _puzzle._origin)
		# Tap every empty cell in row 0 three times: empty -> 0 -> 1 -> empty.
		# Then leave row 1 tapped once so we can see both glyph states.
		for c in _puzzle.n:
			if not _puzzle._given[0][c]:
				_tap(0, c)
		for c in _puzzle.n:
			if not _puzzle._given[1][c]:
				_tap(1, c); _tap(1, c)
		print("after taps, moves=", _puzzle.moves)
		print("row0=", _puzzle._grid[0])
		print("row1=", _puzzle._grid[1])
		print("bad_rows=", _puzzle._bad_rows.keys())
	if _frames == 60:
		var img := root.get_texture().get_image()
		img.save_png("/tmp/shot_tapped.png")
		print("saved /tmp/shot_tapped.png")
		return true
	return false

func _tap(r: int, c: int) -> void:
	var local: Vector2 = _puzzle._origin + Vector2(c + 0.5, r + 0.5) * _puzzle._cell
	var at: Vector2 = _puzzle.get_global_transform_with_canvas() * local
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = pressed
		ev.position = at
		root.push_input(ev, true)
