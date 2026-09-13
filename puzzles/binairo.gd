extends "res://core/puzzle_base.gd"

## Binairo board. Tap a cell to cycle empty -> circle -> square -> empty.
## Lines that already break a rule are tinted, so the player learns the rules
## by touching rather than by reading them.

const Gen = preload("res://puzzles/binairo_gen.gd")
const Pal = preload("res://core/palette.gd")

var n: int = 6
var _grid: Array = []
var _given: Array = []
var _solution: Array = []
var _bad_rows: Dictionary = {}
var _bad_cols: Dictionary = {}

var _cell: float = 0.0
var _origin: Vector2 = Vector2.ZERO

func puzzle_id() -> String: return "binairo"
func title() -> String: return "Binairo"

func rules() -> String:
	return "Fill every cell. Never three alike in a line, an equal count of each per line, and no two lines identical."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var min_clues := 0
	match difficulty:
		0: n = 6; min_clues = 16
		1: n = 6; min_clues = 0
		_: n = 8; min_clues = 0

	var out: Dictionary = Gen.generate(rng, n, min_clues)
	_solution = out.solution
	_given = []
	_grid = []
	for r in n:
		var grow: Array = []
		var grow_given: Array = []
		for c in n:
			var v = out.puzzle[r][c]
			grow.append(v)
			grow_given.append(v != -1)
		_grid.append(grow)
		_given.append(grow_given)
	_recheck()
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	for r in n:
		for c in n:
			if not _given[r][c]:
				_grid[r][c] = -1
	moves = 0
	_recheck()
	queue_redraw()

func is_solved() -> bool:
	return Gen.is_valid_complete(_grid)

func share_glyphs() -> String:
	var out := ""
	for r in n:
		for c in n:
			out += "🟦" if _grid[r][c] == 0 else "🟧"
		out += "\n"
	return out

# --- input ---

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF or _cell <= 0.0 or is_done():
		return

	var local := pos - _origin
	var c := int(local.x / _cell)
	var r := int(local.y / _cell)
	if r < 0 or c < 0 or r >= n or c >= n:
		return
	if _given[r][c]:
		return

	# empty -> 0 -> 1 -> empty
	var v: int = _grid[r][c]
	_grid[r][c] = 0 if v == -1 else (1 if v == 0 else -1)
	_recheck()
	queue_redraw()
	note_move()

# --- rendering ---

func _draw() -> void:
	if n == 0:
		return
	var board := minf(size.x, size.y)
	_cell = board / float(n)
	_origin = Vector2((size.x - board) * 0.5, (size.y - board) * 0.5)

	var pad := _cell * 0.06
	for r in n:
		for c in n:
			var at := _origin + Vector2(c, r) * _cell
			var rect := Rect2(at + Vector2(pad, pad), Vector2(_cell - pad * 2, _cell - pad * 2))

			var base := Pal.SURFACE_HI if _given[r][c] else Pal.SURFACE
			if _bad_rows.has(r) or _bad_cols.has(c):
				base = base.lerp(Pal.BAD, 0.28)
			draw_rect(rect, base, true)

			var v: int = _grid[r][c]
			if v == -1:
				continue
			# Shape as well as colour, so the board still reads without hue.
			var centre := rect.get_center()
			var rad := _cell * 0.29
			if v == 0:
				draw_circle(centre, rad, Pal.ACCENT)
			else:
				draw_rect(Rect2(centre - Vector2(rad, rad), Vector2(rad * 2, rad * 2)), Pal.ACCENT_2, true)
			if _given[r][c]:
				# Givens carry a ring so locked cells are obvious.
				draw_arc(centre, rad * 1.5, 0, TAU, 32, Pal.TEXT_DIM, 3.0)

# --- rule feedback ---

func _recheck() -> void:
	_bad_rows.clear()
	_bad_cols.clear()
	var half: int = n / 2
	for i in n:
		var row := []
		var col := []
		for j in n:
			row.append(_grid[i][j])
			col.append(_grid[j][i])
		if _line_bad(row, half):
			_bad_rows[i] = true
		if _line_bad(col, half):
			_bad_cols[i] = true
	# Identical completed lines.
	for a in n:
		for b in range(a + 1, n):
			if not (_grid[a] as Array).has(-1) and _grid[a] == _grid[b]:
				_bad_rows[a] = true
				_bad_rows[b] = true
			var ca := []
			var cb := []
			for i in n:
				ca.append(_grid[i][a])
				cb.append(_grid[i][b])
			if not ca.has(-1) and ca == cb:
				_bad_cols[a] = true
				_bad_cols[b] = true

func _line_bad(line: Array, half: int) -> bool:
	var zeros := 0
	var ones := 0
	for v in line:
		if v == 0: zeros += 1
		elif v == 1: ones += 1
	if zeros > half or ones > half:
		return true
	for i in range(line.size() - 2):
		if line[i] != -1 and line[i] == line[i + 1] and line[i + 1] == line[i + 2]:
			return true
	return false
