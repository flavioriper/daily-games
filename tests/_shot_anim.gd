extends SceneTree

## Animation strip for Binairo: frames across the entrance, a tap, the roll
## and two seconds of idle, plus the draw-call count and mean frame time over
## the idle window. Vsync is off so the delta is the real cost of a frame.
## Judge the ambience by eye and the budget by the numbers
## (polish spec, section 7: idle mean under 8 ms at 1080 x 1920 on the Mac).
##
##     godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd [-- <puzzle id> [empty]]
##
## Code Break is filled to its fullest board before the idle window, since
## that is the state the budget is written against; `empty` after the id
## measures the bare board instead, so both numbers come from this one probe.
## Untangle is dragged once, and its springs settle into the idle window, so
## `empty` is the number to compare with a board that was left alone. Shikaku
## has its first plot drawn corner to corner, so the strip shows the wash, the
## count and the bed landing and the idle window has a bed and a fence in it.
## Tents is swept along its top row, so the strip shows the shade under the
## finger and the cairns arriving in a wave and the idle window has a row of
## cairns in it. Light Up has its first answer lamp set down, so the strip
## shows the pop, the light travelling and the beam, and the idle window has
## a lit lamp and its halo in it. One Line has its walker stood on the start
## post and walked one line, so the strip shows the pop, the walk and the
## landing hop, and the idle window has a plank and the walker in it.
## Nonogram is swept along its top row with the tile chip, so the strip shows
## the cells sinking under the finger and the tiles arriving in a wave, and
## the idle window has a row of tiles in it.
## Word Trail has the first word's trail traced cell by cell from TAP_AT and
## let go, so the strip shows the beam growing to the finger, the release and
## the lock wave running down the ribbon; it gets three extra frames and a
## later idle window for that, because the wave is over in a fifth of a
## second a tile.
## Queens has the answer's first queen seated, so the strip shows the crown
## pop and the wave of crosses running out of her, and the idle window has a
## queen and her crosses in it.
## Hidden Word has a five-letter guess typed on its keyboard and committed a
## beat later, so the strip shows the letters popping in, the row caught
## mid-flip and the row landed with the keys repainted behind it. The guess is
## never the day's word, so the board does not win in the middle of the strip.
## It takes four more words after the id, one per ending it has:
## `toast` refuses a guess that is not a word, `hint` presses the real hint
## button, `solve` types the day's own word, and `over` spends all six rows so
## the strip catches the keyboard leaving and the sprout bringing the word.
## Mushroom Patch has the answer's first mushroom planted with the mushroom
## chip the tray arms by default, so the strip shows the pop, the ring, the
## puff and -- the point of the shot -- the count wash arriving on the givens
## around it as their numerals bump and turn green.
##
## Rings lifts a ring, holds it a beat, then drops it on a peg engineered to
## lock, so the strip shows the held ring risen and breathing, a frame
## mid-flight and the gold wash landing. `stuck` raises the toast directly
## instead of engineering a real dead position; `win` engineers every colour
## but the last already home and drops the one ring that finishes it, so the
## strip runs on to the win screen.
##
## Sudoku has the emptiest row of its grid closed off a cell at a time, so the
## strip shows the selection's washes, a digit dropping in and the wave the
## finished row runs from the cell that closed it. It takes six more words
## after the id, one per moment a still frame has to be able to judge:
## `tap` writes one digit and closes nothing, which is the lone placement to
## compare the wave against; `refuse` taps a given and then a chip, so the
## strip catches the cell shivering and the tip card saying why; `check`
## writes two wrong digits and presses the real Check, so the strip catches
## both of them shivering out of the middle row under the rose wash; and
## `hint` presses the real hint button, so the strip catches the ring, the
## sparkle and the digit dropping in; `reset` fills the first eight rows and
## presses Reset a beat later, so the strip catches the wave carrying them
## out; and `solve` writes the whole
## answer, so the strip catches the diagonal wave, its three sparkles and the
## win screen behind them.
##
## `rm` anywhere after the id sets `Motion.reduce` **before the board opens**
## and adds a seventh shot 1.5 s after the sixth, so the pair can be compared
## pixel for pixel: under reduce motion nothing on a settled board may move.
##
## Saves /tmp/anim_<id>_<n>.png for n = 0..5 (0..6 under `rm`).

const MushroomGen = preload("res://puzzles/mushroom_gen.gd")
const RingsGen = preload("res://puzzles/rings_gen.gd")

const SHOTS := [0.35, 0.9, 1.65, 1.8, 2.8, 3.8]  # seconds after opening
## The reduce-motion pair: how long after the last shot the extra one is
## taken, and how much longer the run then has to last.
const RM_PAIR := 1.5
const TAP_AT := 1.6
const IDLE_FROM := 2.2
const IDLE_TO := 4.2

var _menu: Node
var _host: Node
var _puzzle: Node
var _t := -0.2   # the first frames carry the load; the board opens at 0
var _opened := false
var _tapped := false
var _shot := 0
var _idle: Array[float] = []
var _idle_from := IDLE_FROM
var _idle_to := IDLE_TO
var _filling := false
var _draws := 0
var _id := ""
var _empty := false   # skip the fill and measure the bare board
var _mode := ""       # a board with more than one thing to show picks here
var _reduce := false
var _shots: Array = SHOTS.duplicate()
var _entry: Dictionary = {}
## A drag: a real touch at `_drag_from`, dragged over DRAG_TIME by `_drag_by`
## and let go. Untangle's is the first free lantern toward the middle of the
## card, so the strip shows the lift, the slack and the drop; Shikaku's is its
## first solution plot corner to corner.
const DRAG_TIME := 0.35
const UNTANGLE_BY := Vector2(150.0, 110.0)
var _drag_from := Vector2.ZERO
var _drag_by := Vector2.ZERO
var _drag_until := INF
var _drag_done := true
## Hidden Word presses Enter a beat after the five letters, so the shot at
## 1.65 catches the row typed and the one at 1.8 catches its first tile a
## third of the way through its turn, still face-down.
const COMMIT_AFTER := 0.05
var _commit_at := INF
## Sudoku's `reset` mode: the grid is filled at TAP_AT and Reset pressed a
## beat later, so the strip catches the wave carrying the digits out.
const RESET_AFTER := 0.5
var _reset_at := INF
## `over` spends all six rows: one word typed and committed every WORD_EVERY
## seconds, so the rows turn one after another rather than all at once and
## the reveal comes off the sixth one's landing.
const WORD_EVERY := 0.28
var _words: Array[String] = []
var _word_at := INF
## Word Trail's trail: the first word's own cells, touched one at a time
## TRAIL_STEP apart and let go one step after the last, so the strip catches
## the beam growing to the finger, the release and the lock wave running down
## the ribbon. A straight _begin_drag would cut the corners a bent trail is
## made of.
const TRAIL_STEP := 0.12
var _trail_cells: Array[Vector2] = []
var _trail_last := Vector2.ZERO
var _trail_at := INF
## Rings: the drop lands DROP_AFTER after the lift, so the strip has time to
## catch the held ring risen and breathing before it flies.
const RINGS_DROP_AFTER := 0.4
var _rings_drop_to := 0
var _rings_drop_at := INF

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_id = args[0]
	for i in range(1, args.size()):
		if args[i] == "rm":
			_reduce = true
		else:
			_mode = args[i]
	_empty = _mode == "empty"
	if _id == "wordtrail" and not _empty:
		# The trail is traced from TAP_AT and the lock wave runs off its
		# release, so three frames go between the usual ones: the trail
		# nearly whole, the wave part-way down the ribbon, and the word
		# settled. The idle window opens after the wave rather than during it.
		_shots = [0.35, 0.9, 1.65, 1.9, 2.05, 2.25, 2.8, 3.8]
		_idle_from = 2.6
		_idle_to = 4.6
	if _id == "rings" and _mode == "win":
		# The drop lands about 0.74 s after the id opens (TAP_AT plus the
		# drop delay plus the flight), the wash runs another 0.18 s and the
		# solve hop another second past that -- so the win screen wants a
		# shot well past the usual last one.
		_shots.append_array([4.6, 5.6])
		_idle_from = 5.8
		_idle_to = 7.8
	if _mode == "over":
		# Six rows take WORD_EVERY each and the last of them another second
		# to turn over, so the reveal lands well past the usual last shot.
		_shots.append_array([4.6, 5.6])
		_idle_from = 5.8
		_idle_to = 7.8
	if _reduce:
		_shots.append(float(_shots[_shots.size() - 1]) + RM_PAIR)
		_idle_to = maxf(_idle_to, float(_shots[_shots.size() - 1]) + 0.2)
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		if _t >= 0.0:
			_opened = true
			_t = 0.0
			var entries: Array = load("res://ui/registry.gd").PUZZLES
			_entry = entries[0]
			for e in entries:
				if e.id == _id:
					_entry = e
			if _entry.get("soon", false):
				push_error("_shot_anim: %s has no flat board to shoot" % _id)
				quit(1)
				return true
			# Set before the board opens, so its entrance is the reduced one
			# and not a full entrance stilled halfway through.
			if _reduce:
				load("res://core/motion.gd").reduce = true
			_menu._open(_entry)
			_host = _menu.get_child(_menu.get_child_count() - 1)
			_puzzle = _host._puzzle
		return false
	if not _tapped and _t >= TAP_AT:
		_tapped = true
		if _entry.id == "mastermind" and not _empty:
			# The flat board plays a row over about a second (the score, then
			# the slide), so the fill is one press a frame until it is done and
			# the idle window opens after it.
			_filling = true
			_idle_from = INF
			_idle_to = INF
		elif _entry.id == "balance":
			# One press on the first free weight card, so the strip shows a
			# beam swing and the kind's hop.
			_step_balance()
		elif _entry.id == "untangle" and not _empty:
			_begin_untangle_drag()
		elif _entry.id == "shikaku" and not _empty:
			_begin_shikaku_drag()
		elif _entry.id == "tents" and not _empty:
			_begin_tents_sweep()
		elif _entry.id == "lightup" and not _empty:
			_tap_lightup()
		elif _entry.id == "oneline" and not _empty:
			_walk_oneline()
		elif _entry.id == "nonogram" and not _empty:
			_begin_nonogram_sweep()
		elif _entry.id == "queens" and not _empty:
			_tap_queens()
		elif _entry.id == "hiddenword" and not _empty:
			_type_hiddenword()
		elif _entry.id == "mushroom" and not _empty:
			_tap_mushroom()
		elif _entry.id == "wordtrail" and not _empty:
			_drag_wordtrail()
		elif _entry.id == "rings" and not _empty:
			_tap_rings()
		elif _entry.id == "sudoku" and not _empty:
			_tap_sudoku()
			if _mode == "hint":
				# The ring runs RING_TIME and the digit drops over
				# DROP_TIME, both off this frame rather than off TAP_AT: the
				# frame that pushes the touch is a long one and the texture
				# read in it is the frame before the press.
				_shots[2] = _t + 0.10
				_shots[3] = _t + 0.30
			if _mode == "refuse" or _mode == "check":
				# A shiver is two swings dying out over SHIVER_TIME, so it is
				# at rest again a fifth of a second after the tap and it
				# crosses zero four times on the way: the stock shots at 1.65
				# and 1.80 photograph a cell standing perfectly still. These
				# two land on the second and third crests -- and they are
				# measured off **this** frame rather than off TAP_AT, because
				# the frame that pushes the touches is a long one and the
				# texture read in it is the frame before the poke.
				_shots[2] = _t + 0.075
				_shots[3] = _t + 0.125
		elif _puzzle.get("_given") != null:
			# The tap walks Binairo's givens; a board without them idles instead.
			_tap_first_free()
	if _t >= _reset_at:
		_reset_at = INF
		_press(_host.action_bar.reset_button)
		# The wave from the far corner is RESET_STAGGER a step and a bump
		# long, so it is over in well under a second; these two catch it
		# a third and two thirds of the way down the board.
		_shots[4] = _t + 0.15
		_shots[5] = _t + 0.40
	if _t >= _trail_at:
		_trail_step()
	if _t >= _rings_drop_at:
		_rings_drop_at = INF
		_tap_rings_station(_rings_drop_to)
	if _t >= _commit_at:
		_commit_at = INF
		_tap_key("Key_Enter")
	if _t >= _word_at:
		if _words.is_empty():
			_word_at = INF
		else:
			var word: String = _words.pop_front()
			for i in word.length():
				_tap_key("Key_%s" % word[i].to_upper())
			_tap_key("Key_Enter")
			_word_at = _t + WORD_EVERY
	if _filling:
		_fill_mastermind_step()
	if not _drag_done:
		_drag_step()
	if _t >= _idle_from and _t <= _idle_to:
		_idle.append(delta * 1000.0)
		_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _shot < _shots.size() and _t >= float(_shots[_shot]):
		var path := "/tmp/anim_%s_%d.png" % [_entry.id, _shot]
		root.get_texture().get_image().save_png(path)
		print("saved %s at t=%.2f" % [path, _t])
		_shot += 1
	if _t > _idle_to:
		var mean := 0.0
		for ms in _idle:
			mean += ms
		mean /= maxf(_idle.size(), 1.0)
		print("idle frames=%d mean_ms=%.2f max_draw_calls=%d" % [_idle.size(), mean, _draws])
		return true
	return false

## One real touch on the first free cell, through the viewport like a thumb.
func _tap_first_free() -> void:
	for r in _puzzle.n:
		for c in _puzzle.n:
			if _puzzle._given[r][c]:
				continue
			var at: Vector2 = _puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(r, c)
			for pressed in [true, false]:
				var ev := InputEventScreenTouch.new()
				ev.index = 0
				ev.pressed = pressed
				ev.position = at
				root.push_input(ev, true)
			return

## Light Up: one real touch on the first lamp of the answer.
func _tap_lightup() -> void:
	if _puzzle._solution_bulbs.is_empty():
		return
	var b: Vector2i = _puzzle._solution_bulbs[0]
	_tap_global(_puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(b.y, b.x))

## One Line: stand the walker on the trail's first post and walk its first
## line, two real touches.
func _walk_oneline() -> void:
	var Gen = load("res://puzzles/oneline_gen.gd")
	var trail: Array = Gen.find_path(_puzzle._edges, _puzzle._nodes)
	if trail.size() < 2:
		return
	var xf: Transform2D = _puzzle.get_global_transform_with_canvas()
	_tap_global(xf * _puzzle.node_to_local(trail[0]))
	_tap_global(xf * _puzzle.node_to_local(trail[1]))

## Nonogram: sweep the top row from its first cell to its last with the tile
## chip, laying a tile on every cell.
func _begin_nonogram_sweep() -> void:
	var xf: Transform2D = _puzzle.get_global_transform_with_canvas()
	var from: Vector2 = xf * _puzzle.cell_to_local(0, 0)
	var to: Vector2 = xf * _puzzle.cell_to_local(0, _puzzle.w - 1)
	_begin_drag(from, to - from)

## Queens: one real touch on the answer's first queen, with the crown chip the
## tray arms by default.
func _tap_queens() -> void:
	var c: int = int(_puzzle.state.solution[0])
	_tap_global(_puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(0, c))

## Mushroom Patch: one real touch on the answer's first mushroom (reading
## order, sorted by y then x), with the mushroom chip the tray arms by
## default. That cell is the point of the shot only if planting it turns a
## given neighbour's numeral green; if the first mushroom in reading order
## touches none, the one whose plant changes the most numbers is tapped
## instead, so the strip always catches the wash landing.
func _tap_mushroom() -> void:
	var st = _puzzle.state
	var cells: Array = st.mushrooms.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	var best: Vector2i = cells[0]
	if _mushroom_wash_count(cells[0]) == 0:
		var best_score := 0
		for cell in cells:
			var score := _mushroom_wash_count(cell)
			if score > best_score:
				best_score = score
				best = cell
	_tap_global(_puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(best.y, best.x))

## How many of `cell`'s given neighbours would turn green the instant it is
## planted: on a fresh board every given starts short, so a neighbour whose
## own number is exactly one goes straight to settled.
func _mushroom_wash_count(cell: Vector2i) -> int:
	var st = _puzzle.state
	var c := 0
	for p in MushroomGen.neighbours(cell, st.n):
		if st.given.has(p) and int(st.given[p]) == 1:
			c += 1
	return c

## Hidden Word: type a five-letter guess on the real keyboard, one key tapped
## like a thumb, and press Enter a beat later. The guess is picked off the
## accept list the board itself answers with, and never the day's word: a
## board that won here would spend the rest of the strip on the win screen.
## The four other things this board has to show, each driven through the real
## keyboard or the real top bar: the refusal's toast, the hint's ghost letter
## and greened key, the solve, and the six rows that run out.
func _type_hiddenword() -> void:
	match _mode:
		"toast":
			# Five letters that are not a word: the refusal the toast names
			# most often, and the one the accept list decides.
			for i in "qwrtz".length():
				_tap_key("Key_%s" % "qwrtz"[i].to_upper())
			_commit_at = _t + COMMIT_AFTER
			return
		"hint":
			_press(_host.top_bar.hint_button)
			return
		"solve":
			_type_word(_puzzle.state.answer)
			_commit_at = _t + COMMIT_AFTER
			return
		"over":
			_words = _six_wrong()
			_word_at = _t
			return
	_type_word(_wrong_word())
	_commit_at = _t + COMMIT_AFTER

func _type_word(word: String) -> void:
	for i in word.length():
		_tap_key("Key_%s" % word[i].to_upper())

## A guess off the accept list the board itself answers with, and never the
## day's word: a board that won here would spend the rest of the strip on the
## win screen.
func _wrong_word() -> String:
	for candidate in ["slate", "crane", "roast", "plant"]:
		if candidate != _puzzle.state.answer and _puzzle.state.accepts(candidate):
			return candidate
	return ""

## Six accepted words, none of them the day's: enough to spend every row.
func _six_wrong() -> Array[String]:
	var out: Array[String] = []
	for candidate in ["slate", "crane", "roast", "plant", "bugle", "windy", "mirth", "pluck"]:
		if out.size() >= 6:
			break
		if candidate != _puzzle.state.answer and _puzzle.state.accepts(candidate):
			out.append(candidate)
	return out

## Rings: lift a ring, hold a beat, then drop it on a peg engineered to lock
## -- two real touches, so the strip shows the held ring risen and breathing,
## a frame mid-flight and the gold wash landing. The drop is forced to finish
## a peg because a fresh deal is not reliably one move from doing that: peg 0
## becomes three rings of one colour and the source peg's top ring is set to
## match, so the move the strip watches always locks a peg. `stuck` skips all
## of that and simply raises the toast directly, since engineering an actual
## position with no legal move is not worth it just to look at the pill.
func _tap_rings() -> void:
	var p = _puzzle
	if _mode == "stuck":
		p._toast = p.STUCK_MSG
		p._toast_at = _t
		p._refresh()
		return
	if _mode == "win":
		# Every colour but the last already locked on a peg of its own; the
		# last is split 3 and 1 across the two spare pegs every band deals
		# (BANDS always leaves two), so the one drop the strip watches wins.
		var colours: int = p._state.colours
		var win_pegs: Array = p._state.pegs
		for c in range(colours - 1):
			win_pegs[c] = [c, c, c, c]
		win_pegs[colours - 1] = [colours - 1, colours - 1, colours - 1]
		win_pegs[colours] = [colours - 1]
		for i in range(colours + 1, win_pegs.size()):
			win_pegs[i] = []
		_rings_drop_to = colours - 1
		_tap_rings_station(colours)
		_rings_drop_at = _t + RINGS_DROP_AFTER
		return
	var pegs: Array = p._state.pegs
	if pegs.size() < 2:
		return
	pegs[0] = [0, 0, 0]
	var src := 1
	for i in range(1, pegs.size()):
		var peg: Array = pegs[i]
		if not peg.is_empty() and not RingsGen.locked(peg):
			src = i
			break
	var peg: Array = pegs[src]
	peg[peg.size() - 1] = 0
	_rings_drop_to = 0
	_tap_rings_station(src)
	_rings_drop_at = _t + RINGS_DROP_AFTER
	_shots[4] = _rings_drop_at + 0.15   # mid-flight: ARC_TIME is 0.34
	_shots[5] = _rings_drop_at + 0.6    # landed, the wash still bright

## A real touch inside station `i`'s column, near its base -- the whole
## column is one target (_peg_at), so any point inside it taps the peg.
func _tap_rings_station(i: int) -> void:
	var p = _puzzle
	var st: Dictionary = p._station(i)
	var at: Vector2 = p.get_global_transform_with_canvas() * Vector2(float(st["cx"]), float(st["ground"]) - 10.0)
	_tap_global(at)

## Sudoku: the emptiest row closed off, a cell selected and a digit written
## through the real pad, so the strip shows the washes under the selection,
## the digit dropping in and **the wave** -- the row lighting up in gold from
## the cell that finished it outwards, which is this board's signature and
## the one thing a still frame of it has to catch. `empty` measures the bare
## board instead, and `tap` writes one digit without closing anything, which
## is the frame to compare a lone placement against.
func _tap_sudoku() -> void:
	var p = _puzzle
	if _mode == "tap":
		for i in 81:
			if p.state.grid[i] == 0:
				_write_sudoku(i)
				return
		return
	if _mode == "refuse":
		# A given, then a chip: the one refusal the grid can hand out, and
		# the frame that shows the cell shivering rather than its digit.
		for i in 81:
			if p.state.given[i] != 0:
				_tap_global(p.get_global_transform_with_canvas() * p.cell_to_local(i / 9, i % 9))
				_tap_key("Digit0")
				return
		return
	if _mode == "check":
		# Two digits that are not the answer, then the real Check button.
		var written := 0
		for i in 81:
			if p.state.grid[i] != 0:
				continue
			_tap_global(p.get_global_transform_with_canvas() * p.cell_to_local(i / 9, i % 9))
			_tap_key("Digit%d" % (int(p.state.sol[i]) % 9))
			written += 1
			if written == 2:
				break
		_press(_host.action_bar.check_button)
		return
	if _mode == "hint":
		# The real hint button: a ring, a sparkle, the digit dropping in,
		# and the wave if that cell happened to finish something.
		_press(_host.top_bar.hint_button)
		return
	if _mode == "reset":
		# Eight rows written, so the wave from the far corner has the whole
		# board to cross, and Reset a beat later so the strip catches the
		# digits going out.
		for i in 72:
			if p.state.grid[i] == 0:
				_write_sudoku(i)
		_reset_at = _t + RESET_AFTER
		return
	if _mode == "solve":
		# The whole answer through the real pad, the way tests/_win.gd writes
		# it, so the strip catches the diagonal wave off the last digit.
		for i in 81:
			if p.is_done():
				return
			var d: int = p.state.sol[i]
			if p.state.grid[i] == d:
				continue
			_write_sudoku(i)
		return
	# The row with the fewest holes: filling it is one wave and few taps.
	var row := 0
	var fewest := 99
	for r in 9:
		var holes := 0
		for c in 9:
			if p.state.grid[r * 9 + c] == 0:
				holes += 1
		if holes > 0 and holes < fewest:
			fewest = holes
			row = r
	for c in 9:
		var i: int = row * 9 + c
		if p.state.grid[i] != 0:
			continue
		_write_sudoku(i)

## One cell selected and its answer written, both through real touches: the
## pair of taps is the only way anything gets into this grid.
func _write_sudoku(i: int) -> void:
	_tap_global(_puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(i / 9, i % 9))
	_tap_key("Digit%d" % (int(_puzzle.state.sol[i]) - 1))

## One tap on a key of the keyboard tray or a chip of the digit pad, found by
## the name that tray gives it.
func _tap_key(name: String) -> void:
	if _host.tray == null:
		return
	var chip = _host.tray.find_child(name, true, false)
	if chip is Button:
		_press(chip)

## Balance: plus on the first card the player owns, through the real button.
func _step_balance() -> void:
	for i in _puzzle.state.shapes:
		if not _puzzle.state.locked[i]:
			_press(_host.tray.plus_button(i))
			return

## Untangle: touch the first free lantern's ring and start dragging it.
func _begin_untangle_drag() -> void:
	for i in _puzzle.nodes:
		if _puzzle._locked[i]:
			continue
		_begin_drag(_puzzle.get_global_transform_with_canvas() * _puzzle.node_to_local(i), UNTANGLE_BY)
		return

## Shikaku: draw the first solution plot, from the centre of its top-left
## cell to the centre of its bottom-right one.
func _begin_shikaku_drag() -> void:
	if _puzzle._solution.is_empty():
		return
	var rect: Rect2i = _puzzle._solution[0]
	var xf: Transform2D = _puzzle.get_global_transform_with_canvas()
	var from: Vector2 = xf * _puzzle.cell_to_local(rect.position.y, rect.position.x)
	var to: Vector2 = xf * _puzzle.cell_to_local(rect.end.y - 1, rect.end.x - 1)
	_begin_drag(from, to - from)

## Tents: sweep the top row from its first cell to its last, laying cairns
## on every square the sweep may change.
func _begin_tents_sweep() -> void:
	var xf: Transform2D = _puzzle.get_global_transform_with_canvas()
	var from: Vector2 = xf * _puzzle.cell_to_local(0, 0)
	var to: Vector2 = xf * _puzzle.cell_to_local(0, _puzzle.w - 1)
	_begin_drag(from, to - from)

## Word Trail: trace the first word -- the shortest, since the board sorts
## them that way -- cell by cell through the board's own input path. The
## trail bends, so it is a list of waypoints and not a straight drag, and one
## step passes between the last cell and the release so the strip can catch
## the beam whole before the wave takes over.
func _drag_wordtrail() -> void:
	var cells: Array = _puzzle._state.words[0]["path"]
	if cells.size() < 2:
		return
	var xf: Transform2D = _puzzle.get_global_transform_with_canvas()
	_trail_cells = []
	for cell: Vector2i in cells:
		_trail_cells.append(xf * _puzzle.cell_to_local(cell.y, cell.x))
	_trail_last = _trail_cells.pop_front()
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _trail_last
	root.push_input(down, true)
	_trail_at = _t + TRAIL_STEP

## One cell a step, then the release on the one after the last.
func _trail_step() -> void:
	if _trail_cells.is_empty():
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.pressed = false
		up.position = _trail_last
		root.push_input(up, true)
		_trail_at = INF
		return
	_trail_last = _trail_cells.pop_front()
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _trail_last
	root.push_input(drag, true)
	_trail_at = _t + TRAIL_STEP

## The touch that starts a drag, at `from`, to travel `by` over DRAG_TIME.
func _begin_drag(from: Vector2, by: Vector2) -> void:
	_drag_from = from
	_drag_by = by
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _drag_from
	root.push_input(down, true)
	_drag_until = _t + DRAG_TIME
	_drag_done = false

## One drag event a frame along the way, eased, and the release at the end.
func _drag_step() -> void:
	var u := clampf(1.0 - (_drag_until - _t) / DRAG_TIME, 0.0, 1.0)
	var at := _drag_from + _drag_by * (1.0 - pow(1.0 - u, 2.0))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = at
	root.push_input(drag, true)
	if u >= 1.0:
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.pressed = false
		up.position = at
		root.push_input(up, true)
		_drag_done = true

## Code Break's fullest board: seven rows guessed and scored, the eighth
## filled and waiting on Check. Every row is one colour, and at difficulty 0
## the day's code has no repeats, so no monochrome row can win and the eighth
## row is still there to fill. Driven through the HUD the way tests/_win.gd
## drives it, so the board reaches the state by playing rather than by having
## its arrays written: one press a frame, and nothing while a score plays.
func _fill_mastermind_step() -> void:
	if _puzzle._busy:
		return
	var tray = _host.tray
	var played: int = _puzzle._guesses.size()
	if played >= 7:
		if not _puzzle.state.full():
			_press(tray.chips[0])
			return
		_filling = false
		_idle_from = _t + 0.6
		_idle_to = _idle_from + 2.0
		print("filled at t=%.2f" % _t)
		return
	if _puzzle.state.full():
		_press(_host.action_bar.check_button)
	else:
		_press(tray.chips[played % tray.chips.size()])

## Presses a HUD button through a touch at its centre, like a player would.
func _press(btn: Button) -> void:
	_tap_global(btn.get_global_transform_with_canvas() * (btn.size * 0.5))

func _tap_global(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = pressed
		ev.position = at
		root.push_input(ev, true)
