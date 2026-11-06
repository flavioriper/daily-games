extends RefCounted

## Nonogram's rules, with no scene under them: the picture, the clues down
## each line, what the player has put on each cell, and every move that can
## change it. The flat board (puzzles/nonogram2d.gd) draws this and nothing
## else, so what is on trial on the phone is the screen and not the game.
##
## It is `puzzles/nonogram3d.gd`'s logic with one deliberate difference: **a
## stroke is a move, not a tap**. The flat board paints a whole run in one
## drag, so the history records a list of cells rather than a single one, and
## a painted run comes back on one undo rather than six. The island only ever
## had single taps to record, and it cycled blank -> tile -> cross -> blank on
## them; here the tray says which of the two a stroke lays, and a stroke that
## begins on your own paint rubs it out.
##
## The win test is the picture and never the clues: a grid can have every line
## reading exactly as its numbers say and still be wrong, which is why the
## sprout says so in those words rather than pretending the board is finished.
## Crosses are the player's working-out and count for nothing.
## Spec: docs/superpowers/specs/2026-09-18-nonogram-flat-design.md, section 3.

const Gen = preload("res://puzzles/nonogram_gen.gd")
const Planes = preload("res://puzzles/planes_state.gd")

const BLANK := 0
const FILL := 1
const MARK := 2
const HINTS := 3
## Hints a board gets per band, and hearts: Hard and Insane can be failed
## (docs/superpowers/specs/2026-09-30-nonogram-polish-design.md, section 1).
const HINTS_BY_BAND := [3, 3, 3, 3]
## No band has hearts since 2026-10-04: nothing is judged as it lands, so
## `judged()` is false everywhere and the pebbles a wrong tile or a finished
## line used to lay are never laid. Insane counts moves instead.
const HEARTS := [0, 0, 0, 0]
## Insane's spare moves over the picture's own tiles (`moves_budget`): a
## tile laid or rubbed out costs one, a cross costs nothing. Three is one
## slip mended (off and on) with one to spare.
const MOVES_SLACK := [0, 0, 0, 0]
## The square each band falls back to when its drawn shape (Gen.SHAPES)
## will not line-solve. Insane no longer reads its bank of tumbled lines
## (content/insane/nonogram.json, left as history) since 2026-10-16: it is
## dealt big and slow by Gen.hardest, and 15 is its fallback (12 till the
## sizes widened, 2026-10-16).
const SIZES := [5, 7, 10, 15]

## A line's state, which is what its clue numbers wear.
const LINE_IDLE := 0
const LINE_OK := 1
const LINE_OVER := 2

var band := 0
## Leaf Fall (Insane): line index, rows then columns -> true when the wind
## has tumbled its numbers and they may come in any order. All false on the
## other bands.
var tumbled: Array = []
var w: int = 5
var h: int = 5
var bitmap: Array = []           # [y][x] -> 1 filled, 0 not: the picture
var row_clues: Array = []        # [y] -> Array[int]
var col_clues: Array = []        # [x] -> Array[int]
## The longest clue on each axis, in numbers. The bands are measured from the
## puzzle in hand -- as the island measures its margin of bare platform -- so
## a gentle picture gets a tight board.
var gw: int = 1
var gh: int = 1
## How many cells the picture wants filled, which is what the sprout counts
## down.
var target: int = 0
## Vector2i -> FILL or MARK. A blank cell is simply absent.
var marks: Dictionary = {}
var locked: Dictionary = {}      # Vector2i -> true, a tile a hint grouted in
## Vector2i -> true, an X the board laid itself (`shut_in`), not the
## player: it goes again when the tiles that shut its cell out go.
var auto: Dictionary = {}
## One entry per stroke, newest last: [{"cell": Vector2i, "prev": int,
## "auto": bool}], `auto` being whether the cell's old mark was the board's.
var history: Array = []

## The day's theme (wave 2 of the daily theme roadmap, 2026-11-06): on
## Medium and Hard the hidden picture is one of the night's things
## (core/themed_pictures.gd: its 10, 12, 24 and 32 are each a different thing
## of the theme, drawn with room round it), cut to the band's box with its
## own proportions. Easy's 5 to 7 a side cannot show a
## thing, and Insane stays on Gen.hardest: a themed silhouette line-solves in
## 3-4 sweeps where Insane's own take 6-16. The sizes are tried in order.
## Medium leads with the 10 and Hard with the 12, so the two bands mostly
## draw different things.
const THEMED_SIZES := [[], [10, 24, 32], [12, 32, 24, 10], []]
## The thing must line-solve (the no-guess rule), cover at least this share
## of the band's fallback square, at least MIN_SIDE a side, and leave some
## blanks: the night's things are outlined shapes, and a whole silhouette is
## a lump.
##
## Each cut is tried drawn first, as a picture-logic picture is drawn: its
## edge and details, the body's inside left blank (drawn_cells); then whole. A drawn cut keeps THEMED_DRAWN of the thing.
const THEMED_AREA := 0.75
const MIN_SIDE := 5
const THEMED_FULL := 0.75
const THEMED_DRAWN := 0.3
## {id, name, beads (Vector2i -> bead name, core/palette.gd PG_BEADS)} when
## the picture is the day's thing, {} otherwise. Never shown during play:
## the board paints the beads on only once the picture is solved.
var theme: Dictionary = {}

## `pictures` are the night's things for this band, in THEMED_SIZES' order
## ({id, name, rows}); [] deals as before, the same draws off `rng`.
func setup(rng: RandomNumberGenerator, difficulty: int, bank_step := 0, pictures: Array = []) -> void:
	band = clampi(difficulty, 0, SIZES.size() - 1)
	var out: Dictionary = {}
	var shape := Gen.shape_for(rng, band)
	theme = {}
	if not pictures.is_empty():
		out = themed(pictures, band, shape)
	if not out.is_empty():
		theme = out.theme
	elif band == 3:
		out = Gen.hardest(rng, shape.x, shape.y)
	else:
		out = Gen.generate(rng, shape.x, shape.y)
	if not bool(out.get("ok", false)):
		out = Gen.generate(rng, SIZES[band], SIZES[band])
	w = int(out.w)
	h = int(out.h)
	bitmap = out.bitmap
	row_clues = out.rows
	col_clues = out.cols
	target = 0
	for y in h:
		for x in w:
			target += int(bitmap[y][x])
	gw = 1
	gh = 1
	tumbled = out.get("tumbled", [])
	if tumbled.size() != w + h:
		tumbled = []
		for i in w + h:
			tumbled.append(false)
	for clue in row_clues:
		gw = maxi(gw, (clue as Array).size())
	for clue in col_clues:
		gh = maxi(gh, (clue as Array).size())
	marks = {}
	locked = {}
	auto = {}
	history = []

## The first of `pictures` that cuts, at the day's drawn box and then the
## band's others, to a picture line logic fills alone and THEMED_* allow:
## {bitmap, rows, cols, w, h, ok, theme}, or {}. No draw off any rng, so a
## themed day deals the same on every phone and on every reopening.
static func themed(pictures: Array, p_band: int, drawn: Vector2i) -> Dictionary:
	var boxes: Array = [drawn]
	for s in Gen.SHAPES[clampi(p_band, 0, Gen.SHAPES.size() - 1)]:
		var box := Vector2i(int(s[0]), int(s[1]))
		if not boxes.has(box):
			boxes.append(box)
	var least := float(SIZES[p_band] * SIZES[p_band]) * THEMED_AREA
	for pic in pictures:
		for box in boxes:
			var cut := Planes.cut_shape(pic.rows, box, false)
			if cut.is_empty():
				continue
			var w: int = cut.cols
			var h: int = cut.rows
			if w < MIN_SIDE or h < MIN_SIDE or float(w * h) < least:
				continue
			var whole: Dictionary = cut.cells
			for on: Dictionary in [drawn_cells(whole), whole]:
				if float(on.size()) < float(whole.size()) * THEMED_DRAWN \
						or float(on.size()) > float(w * h) * THEMED_FULL:
					continue
				var got := _solves(on, w, h)
				if not got.is_empty():
					got["theme"] = {"id": String(pic.id), "name": String(pic.get("name", "")),
						"beads": on}
					return got
	return {}

## A cut drawn as a line picture: its edge (a cell beside the void or the
## board's border) and its details kept, the inside cells of the body's bead
## (the one most inside cells wear) left blank.
static func drawn_cells(cells: Dictionary) -> Dictionary:
	var inside := {}
	var count := {}
	for c: Vector2i in cells:
		if [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].all(
				func(d: Vector2i) -> bool: return cells.has(c + d)):
			inside[c] = true
			count[cells[c]] = int(count.get(cells[c], 0)) + 1
	var body := ""
	for bead in count:
		if body == "" or int(count[bead]) > int(count[body]):
			body = bead
	var out := {}
	for c in cells:
		if not (inside.has(c) and cells[c] == body):
			out[c] = cells[c]
	return out

## `on` (cell -> bead) as a board when line logic fills it alone:
## {bitmap, rows, cols, w, h, ok}, else {}.
static func _solves(on: Dictionary, w: int, h: int) -> Dictionary:
	var bmp: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(1 if on.has(Vector2i(x, y)) else 0)
		bmp.append(row)
	var c := Gen.clues_of(bmp, w, h)
	var straight: Array = []
	for i in w + h:
		straight.append(false)
	var lines := Gen.Lines.new(c.rows, c.cols, straight)
	if not lines.matches(lines.line_solve(), bmp):
		return {}
	return {"bitmap": bmp, "rows": c.rows, "cols": c.cols, "w": w, "h": h, "ok": true}

# --- reading the board ---

func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < w and cell.y < h

func mark_at(cell: Vector2i) -> int:
	return int(marks.get(cell, BLANK))

## Row `y` as the player has it, ready for Gen.clue_for: 1 filled, 0 not. A
## cross reads as 0, because a cross is a note and not a claim.
func row_line(y: int) -> Array:
	var out: Array = []
	for x in w:
		out.append(1 if mark_at(Vector2i(x, y)) == FILL else 0)
	return out

func col_line(x: int) -> Array:
	var out: Array = []
	for y in h:
		out.append(1 if mark_at(Vector2i(x, y)) == FILL else 0)
	return out

## Green the moment a line's runs read exactly as its clue, rose once it holds
## more filled cells than the clue can account for. Nothing here ever points
## at one cell -- the lines do the talking, and that is the island's decision
## kept unchanged.
static func line_state(line: Array, clue: Array, tumble := false) -> int:
	if Gen.reads(line, clue, tumble):
		return LINE_OK
	var have := 0
	for v in line:
		have += int(v)
	var want := 0
	for v in clue:
		want += int(v)
	return LINE_OVER if have > want else LINE_IDLE

func row_state(y: int) -> int:
	return line_state(row_line(y), row_clues[y], row_tumbled(y))

func col_state(x: int) -> int:
	return line_state(col_line(x), col_clues[x], col_tumbled(x))

func row_tumbled(y: int) -> bool:
	return y >= 0 and y < tumbled.size() and bool(tumbled[y])

func col_tumbled(x: int) -> bool:
	return h + x < tumbled.size() and bool(tumbled[h + x])

func has_leaves() -> bool:
	return tumbled.has(true)

func leaf_count() -> int:
	return tumbled.count(true)

## Hard and Insane judge every tile as it is laid.
func judged() -> bool:
	return HEARTS[band] > 0

## Whether the picture wants a tile on `cell`.
func wants(cell: Vector2i) -> bool:
	return in_grid(cell) and int(bitmap[cell.y][cell.x]) == 1

func filled_count() -> int:
	var n := 0
	for cell in marks:
		if int(marks[cell]) == FILL:
			n += 1
	return n

func cross_count() -> int:
	var n := 0
	for cell in marks:
		if int(marks[cell]) == MARK:
			n += 1
	return n

## The moves a band hands out: the picture's tiles and its slack, or 0 on a
## band that does not count them.
func moves_budget() -> int:
	return target + MOVES_SLACK[band] if MOVES_SLACK[band] > 0 else 0

## What putting `to` on `cell` costs: one for a tile laid or a tile taken
## off, nothing for a cross or a blank over a cross.
func move_cost(cell: Vector2i, to: int) -> int:
	var was := mark_at(cell)
	return 1 if was != to and (was == FILL or to == FILL) else 0

func tiles_left() -> int:
	return target - filled_count()

func over_lines() -> int:
	var n := 0
	for y in h:
		if row_state(y) == LINE_OVER:
			n += 1
	for x in w:
		if col_state(x) == LINE_OVER:
			n += 1
	return n

func settled_lines() -> int:
	var n := 0
	for y in h:
		if row_state(y) == LINE_OK:
			n += 1
	for x in w:
		if col_state(x) == LINE_OK:
			n += 1
	return n

## The picture, not the clues: a grid matches when every cell agrees with the
## bitmap.
func is_solved() -> bool:
	if bitmap.is_empty():
		return false
	for y in h:
		for x in w:
			if (mark_at(Vector2i(x, y)) == FILL) != (int(bitmap[y][x]) == 1):
				return false
	return true

## The finished picture, not the player's grid: the share is the image.
func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			out += "⬛" if int(bitmap[y][x]) == 1 else "⬜"
		out += "\n"
	return out

# --- moves ---

## Puts `cells` -- [{"cell": Vector2i, "to": int}] -- on the floor as **one**
## entry in the history, which is what makes a painted run one undo. Returns
## the cells that actually changed, so the board can pop just those.
func apply(cells: Array, as_auto := false) -> Array:
	var entry: Array = []
	var changed: Array = []
	for c in cells:
		var cell: Vector2i = c.cell
		var to: int = int(c.to)
		if mark_at(cell) == to:
			continue
		entry.append({"cell": cell, "prev": mark_at(cell), "auto": auto.has(cell)})
		_put(cell, to, as_auto)
		changed.append(cell)
	if entry.is_empty():
		return changed
	history.append(entry)
	return changed

func _put(cell: Vector2i, to: int, as_auto := false) -> void:
	if to == BLANK:
		marks.erase(cell)
	else:
		marks[cell] = to
	if as_auto and to == MARK:
		auto[cell] = true
	else:
		auto.erase(cell)

## Adds `cells` -- [{"cell", "to"}] -- to the last stroke's entry, so one
## undo takes them back with it: the pebbles a finished line lays in its
## empty cells on Hard and Insane. Returns the cells that changed.
func apply_more(cells: Array, as_auto := false) -> Array:
	if history.is_empty():
		return apply(cells, as_auto)
	var entry: Array = history[-1]
	var changed: Array = []
	for c in cells:
		var cell: Vector2i = c.cell
		var to: int = int(c.to)
		if mark_at(cell) == to or locked.has(cell):
			continue
		entry.append({"cell": cell, "prev": mark_at(cell), "auto": auto.has(cell)})
		_put(cell, to, as_auto)
		changed.append(cell)
	return changed

## A wrong tile on Hard or Insane was taken back: the cell is shown empty
## for good, a pebble no stroke moves, and nothing in the history may put
## anything else there again.
func reveal(cell: Vector2i) -> void:
	_forget(cell)
	marks[cell] = MARK
	auto.erase(cell)
	locked[cell] = true

## Drops `cell` from every stroke in the history.
func _forget(cell: Vector2i) -> void:
	var kept: Array = []
	for entry in history:
		var left: Array = []
		for e in entry:
			if e.cell != cell:
				left.append(e)
		if not left.is_empty():
			kept.append(left)
	history = kept

## The cells of row `y` (or column `x` when `y` is negative) still blank.
func blanks_in(y: int, x: int) -> Array:
	var out: Array = []
	if y >= 0:
		for i in w:
			if mark_at(Vector2i(i, y)) == BLANK:
				out.append(Vector2i(i, y))
	else:
		for i in h:
			if mark_at(Vector2i(x, i)) == BLANK:
				out.append(Vector2i(x, i))
	return out

## The blank cells (and the board's own X's) of row `y` (or column `x` when
## `y` is negative) once the line reads right, and none before: the board
## crosses out a finished line and nothing else (the user, 2026-10-28:
## "players are complaining it's too easy, maybe we should fill X only when
## row or column is filled"). From 2026-10-16 till then it laid every X a
## line's tiles shut out, which did the line logic for the player.
func shut_in(y: int, x: int) -> Array:
	var clue: Array = row_clues[y] if y >= 0 else col_clues[x]
	var tumble := row_tumbled(y) if y >= 0 else col_tumbled(x)
	var line: Array = row_line(y) if y >= 0 else col_line(x)
	var open: Array = []
	if not Gen.reads(line, clue, tumble):
		return open
	for i in (w if y >= 0 else h):
		var c := Vector2i(i, y) if y >= 0 else Vector2i(x, i)
		if mark_at(c) == BLANK or auto.has(c):
			open.append(c)
	return open

## Which numbers of row `y` (or column `x` when `y` is negative) are surely
## done on the board as the player has it, tiles and crosses both read
## (Gen.pinned_runs). A tumbled line has no order to pin, so all or none.
func runs_done(y: int, x: int) -> Array:
	var clue: Array = row_clues[y] if y >= 0 else col_clues[x]
	var tumble := row_tumbled(y) if y >= 0 else col_tumbled(x)
	var n := w if y >= 0 else h
	var known: Array = []
	for i in n:
		var c := Vector2i(i, y) if y >= 0 else Vector2i(x, i)
		match mark_at(c):
			FILL: known.append(1)
			MARK: known.append(0)
			_: known.append(-1)
	if tumble:
		var out: Array = []
		var right := Gen.reads(row_line(y) if y >= 0 else col_line(x), clue, true)
		for _i in clue.size():
			out.append(right)
		return out
	return Gen.pinned_runs(clue, known)

## Every pebble on a cell the picture wants: what Check points at on Hard
## and Insane, where no wrong tile ever stays down.
func wrong_pebbles() -> Array:
	var out: Array = []
	for cell in marks:
		if int(marks[cell]) == MARK and not locked.has(cell) and wants(cell):
			out.append(cell)
	return out

## Takes back the last stroke, however many cells it painted. Returns them.
func undo() -> Array:
	if history.is_empty():
		return []
	var entry: Array = history.pop_back()
	var touched: Array = []
	# Newest first, so a cell an entry touched twice ends as it began.
	for i in range(entry.size() - 1, -1, -1):
		var e: Dictionary = entry[i]
		_put(e.cell, int(e.prev), bool(e.get("auto", false)))
		if not touched.has(e.cell):
			touched.append(e.cell)
	return touched

## Lays the first tile the picture wants that the player has not, in reading
## order, and grouts it in for good. What came before still describes this
## board, except for the one cell the hint has taken over.
func hint() -> Vector2i:
	var target_cell := Vector2i(-1, -1)
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			if int(bitmap[y][x]) == 1 and mark_at(cell) != FILL:
				target_cell = cell
				break
		if target_cell.x >= 0:
			break
	if target_cell.x < 0:
		return target_cell
	_forget(target_cell)
	marks[target_cell] = FILL
	auto.erase(target_cell)
	locked[target_cell] = true
	return target_cell

## Every tile the picture does not want. Crosses are never checked: a cross is
## a note, so it is never marked wrong and never counted against the player.
func wrong_tiles() -> Array:
	var out: Array = []
	for cell in marks:
		if int(marks[cell]) != FILL:
			continue
		if int(bitmap[cell.y][cell.x]) == 1:
			continue
		out.append(cell)
	return out

## Clears the floor. Hints are unpinned but not refunded, as on the island.
func reset() -> Array:
	var cleared: Array = marks.keys()
	marks = {}
	locked = {}
	auto = {}
	history = []
	return cleared
