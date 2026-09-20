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
## Bridges lays the answer's runs at one islet -- the one the answer asks
## least of, so the number is actually met -- one plank a drag through the
## board's own input path, so the strip shows the lit lane under the finger,
## the planks dropping in and that islet taking its GOOD ring. It gets an
## extra frame and a later idle window for that, because a run costs two
## steps and the islet is not satisfied until the last of them lands.
## Hidden Word has a five-letter guess typed on its keyboard and committed a
## beat later, so the strip shows the letters popping in, the row caught
## mid-flip and the row landed with the keys repainted behind it. The guess is
## never the day's word, so the board does not win in the middle of the strip.
## It takes four more words after the id, one per ending it has:
## `toast` refuses a guess that is not a word, `hint` presses the real hint
## button, `solve` types the day's own word, and `over` spends all six rows so
## the strip catches the keyboard leaving and the sprout bringing the word.
## Quilt drags the answer's first patch off the rack and onto the cell the
## answer wants it on, through the board's own input path, so the strip
## shows the patch grown to the quilt's cell and held above the finger, the
## ghost under it, and the seam stitches sewing themselves in a wave once it
## lands. It gets a later idle window for that, because the wave runs on
## past the drop.
## Mushroom Patch has the answer's first mushroom planted with the mushroom
## chip the tray arms by default, so the strip shows the pop, the ring, the
## puff and -- the point of the shot -- the count wash arriving on the givens
## around it as their numerals bump and turn green.
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
## Paper Planes taps a free plane picked for two things at once: its launch
## has to wake at least one other plane (`_wakes`, played and undone on the
## state before the real tap, never on the board), so the strip's single tap
## shows both signature moves rather than an isolated dart; and, among the
## planes that do, the shortest flight (`cells.size() - 1 + lane.size() +
## 1`, the same sum the board's own `_dur()` divides by `LAUNCH_SPEED`),
## rather than the first free plane the generator happens to list, whose
## lane could run the length of the board. That keeps the flight inside or
## close to `Motion.POP_IN`'s own floor most seeds, so the strip's unmoved
## default schedule still catches the launch at 1.65 and 1.8, the wake it
## opens up behind the departing plane, and the field settled again well
## before the idle window opens at 2.2 -- no shot times or idle window of its
## own, unlike Word Trail's and Sudoku's.
##
## `rm` anywhere after the id sets `Motion.reduce` **before the board opens**
## and adds a seventh shot 1.5 s after the sixth, so the pair can be compared
## pixel for pixel: under reduce motion nothing on a settled board may move.
##
## Saves /tmp/anim_<id>_<n>.png for n = 0..5 (0..6 under `rm`).

const MushroomGen = preload("res://puzzles/mushroom_gen.gd")

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
## Bridges' runs: one [from islet, to islet] a plank, since a run cycles
## 0-1-2-3 one drag at a time. Each takes two steps -- press and aim on the
## first, release on the second -- so the strip catches the lit lane under
## the finger before the plank lands.
const BRIDGE_STEP := 0.12
const BRIDGE_MAX := 4
var _bridge_drags: Array = []
var _bridge_to := Vector2.ZERO
var _bridge_at := INF
var _bridge_down := false

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
	if _id == "bridges" and not _empty:
		# Up to four planks at two steps each run from TAP_AT, and the last
		# islet's bump and ring land after them, so the settled frame and the
		# idle window both wait for the laying to be over.
		_shots = [0.35, 0.9, 1.65, 1.8, 2.2, 3.2, 4.2]
		_idle_from = 3.2
		_idle_to = 5.2
	if _id == "quilt" and _mode == "full":
		# Every patch but the last is sewn on at once, and the last is
		# dragged, so the strip catches a nearly full quilt, the last patch
		# in the hand over it, and the solve wave running the hem. The idle
		# window opens after the win screen has come up, which is the state
		# the fullest-board draw call belongs to.
		_shots = [0.35, 1.75, 1.95, 2.2, 2.6, 3.2, 4.4, 5.4]
		_idle_from = 3.4
		_idle_to = 5.4
	elif _id == "quilt" and _mode == "refuse":
		# The drag lands at TAP_AT + DRAG_TIME; these catch the patch held
		# over a place it will not go (halo and dashed footprint), then the
		# first two crests of the shiver on the way home, then settled.
		_shots = [0.35, 1.75, 1.90, 2.02, 2.08, 2.5, 3.2, 4.2]
		_idle_from = 3.0
		_idle_to = 5.0
	elif _id == "quilt" and not _empty:
		# The drag runs DRAG_TIME from TAP_AT, then the patch pops in and its
		# seam stitches sew themselves over about four tenths. These catch
		# the patch in the hand, the landing, the wave mid-sew and the seams
		# settled, and the idle window opens after all of it.
		_shots = [0.35, 0.9, 1.75, 1.95, 2.1, 2.3, 2.9, 3.9]
		_idle_from = 2.7
		_idle_to = 4.7
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
		elif _entry.id == "planes" and not _empty:
			_tap_planes()
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
		elif _entry.id == "bridges" and not _empty:
			_lay_bridges()
		elif _entry.id == "quilt" and not _empty:
			_drag_quilt()
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
	if _t >= _bridge_at:
		_bridge_step()
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

## Paper Planes: one real touch on a free plane's head cell -- picked, among
## every free plane, for the shortest flight (`cells.size() - 1 +
## lane.size() + 1`, the same sum the board's own `_dur()` divides by
## `LAUNCH_SPEED`) **among those whose launch also wakes at least one other
## plane** (`_wakes`, played and undone on the state to find out, never on
## the board), so the strip's one tap shows both signature moves -- the
## launch and the wake -- rather than an isolated dart with nothing behind
## it. Falls back to the shortest flight of all if no free plane wakes
## another. Either way the flight stays short enough that the strip's
## ordinary shot schedule catches the launch, the wake and the settle without
## a board-specific timeline of its own.
func _tap_planes() -> void:
	var st = _puzzle._state
	var free: Array = st.free_planes()
	if free.is_empty():
		return
	var best: int = free[0]
	var best_key: Array = [true, INF]
	for i in free:
		var cells: Array = st.planes[i]["cells"]
		var s_end := float(cells.size() - 1 + st.lane(i).size() + 1)
		var key: Array = [_wakes(st, i).is_empty(), s_end]
		if key < best_key:
			best_key = key
			best = i
	var cells: Array = st.planes[best]["cells"]
	var head: Vector2i = cells[cells.size() - 1]
	_tap_global(_puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(head.y, head.x))

## Which planes would become free if `i` launched right now, found by playing
## the move on the state and undoing it -- the state is `RefCounted` and
## reversible (`launch`/`undo`), so this costs nothing the real tap does not
## already pay and leaves the board exactly as it was.
func _wakes(st, i: int) -> Array:
	var before := {}
	for f in st.free_planes():
		before[f] = true
	st.launch(i)
	var out := []
	for f in st.free_planes():
		if not before.has(f):
			out.append(f)
	st.undo()
	return out

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

## Bridges: lay **two** of the answer's runs, both at one islet, so the strip
## catches the lit lane, the planks dropping and -- because those two runs are
## the whole of that islet's number -- the GOOD ring and the bump as the
## second lands. The islet picked is the cheapest one the answer joins with
## two runs and no more than BRIDGE_MAX planks, so the laying is over before
## the settled frame; a board with no such islet falls back to the one the
## answer asks least of. A run cycles one plank a drag, so a run of two
## planks is two drags.
func _lay_bridges() -> void:
	var st = _puzzle.state
	var best := Vector2i(-1, -1)
	var best_cost := 99
	var spare := Vector2i(-1, -1)
	var spare_cost := 99
	for cell in st.islets:
		var runs := _bridge_runs_at(st, cell)
		var cost := 0
		for pair in runs:
			cost += int(pair[1])
		if cost > 0 and cost < spare_cost:
			spare_cost = cost
			spare = cell
		if runs.size() == 2 and cost <= BRIDGE_MAX and cost < best_cost:
			best_cost = cost
			best = cell
	if best.x < 0:
		best = spare
	if best.x < 0:
		return
	_bridge_drags = []
	for pair in _bridge_runs_at(st, best):
		for i in int(pair[1]):
			if _bridge_drags.size() >= BRIDGE_MAX:
				break
			_bridge_drags.append([best, pair[0]])
	_bridge_at = _t

## The answer's runs at `cell`, each as [the islet at the other end, planks].
func _bridge_runs_at(st, cell: Vector2i) -> Array:
	var out: Array = []
	for key in st.answer:
		var lane: Dictionary = st.lanes[key]
		if lane.a != cell and lane.b != cell:
			continue
		out.append([lane.b if lane.a == cell else lane.a, int(st.answer[key])])
	return out

## One step of the laying: press the islet and drag at the one facing it on
## the first, let go on the second.
func _bridge_step() -> void:
	if _bridge_down:
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.pressed = false
		up.position = _bridge_to
		root.push_input(up, true)
		_bridge_down = false
		_bridge_at = INF if _bridge_drags.is_empty() else _t + BRIDGE_STEP
		return
	if _bridge_drags.is_empty():
		_bridge_at = INF
		return
	var pair: Array = _bridge_drags.pop_front()
	var xf: Transform2D = _puzzle.get_global_transform_with_canvas()
	var from: Vector2 = xf * _puzzle.cell_to_local(pair[0].y, pair[0].x)
	_bridge_to = xf * _puzzle.cell_to_local(pair[1].y, pair[1].x)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = from
	root.push_input(down, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _bridge_to
	root.push_input(drag, true)
	_bridge_down = true
	_bridge_at = _t + BRIDGE_STEP

## Quilt: drag the answer's first patch off the rack and onto the place the
## answer wants it, so the strip shows the patch grown to the quilt's cell
## and held above the finger, the ghost under it, and the seam stitches
## sewing themselves in a wave once it lands. The patch is taken hold of by
## its own first cell, and the finger is aimed HOLD_LIFT below the cell the
## patch has to land on, because the board holds a dragged patch above the
## thumb.
func _drag_quilt() -> void:
	if _puzzle._state.shapes.is_empty():
		return
	var p := 0
	if _mode == "refuse":
		# One patch sewn on, and a second dragged straight onto it, so the
		# strip catches the two things a refusal is made of: the rose halo
		# round the cloth in the hand and the dashed footprint under it
		# while it is held, then the shiver and the flight home. The cloth
		# itself never changes colour -- eight cloths round the wheel have
		# no one rose to blush toward (spec section 5).
		_puzzle._state.drop(0, int(_puzzle._state.answer[0]), -1)
		_puzzle._landed[0] = Time.get_ticks_msec() / 1000.0
		_puzzle._refresh()
		p = 1
	if _mode == "full":
		# `full`: every patch but the last goes on through the state, and
		# the last is dragged, so the shot that matters -- a quilt with not
		# a gap in it -- is reached by playing rather than by writing to the
		# board's arrays, and the solve still runs off a real release.
		p = _puzzle._state.shapes.size() - 1
		for q in p:
			_puzzle._state.drop(q, int(_puzzle._state.answer[q]), -1)
			_puzzle._landed[q] = Time.get_ticks_msec() / 1000.0
		_puzzle._refresh()
	var first: Vector2i = (_puzzle._state.shapes[p] as Array)[0]
	var cell: float = _puzzle._cell()
	var rc: float = _puzzle._rack_cell()
	var xf: Transform2D = _puzzle.get_global_transform_with_canvas()
	var from: Vector2 = xf * (_puzzle._bay_home(p) + (Vector2(first) + Vector2(0.5, 0.5)) * rc)
	var origin := int(_puzzle._state.answer[p])
	if _mode == "refuse":
		origin = int(_puzzle._state.answer[0])
	var cols: int = _puzzle._state.cols
	var corner: Vector2 = _puzzle._origin() \
		+ Vector2(float(origin % cols), float(origin / cols)) * cell
	var to: Vector2 = xf * (corner + (Vector2(first) + Vector2(0.5, 0.5 + _puzzle.HOLD_LIFT)) * cell)
	_begin_drag(from, to - from)

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
