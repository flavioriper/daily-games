extends "res://core/puzzle_base.gd"

## Hidden Word as a flat board: six rows of five tiles on the host's
## parchment card, a scenery band at its foot, and a keyboard under it.
## Type five letters, press Enter, and the row turns over a tile at a time --
## green in the right place, amber in the word but elsewhere, grey not in it
## at all. The rules live in puzzles/hidden_word_state.gd, which this only
## draws; the keyboard is ui/flat/key_board.gd, which the host builds and
## hands over once through set_tray().
##
## How it is drawn. Two meshes and no Controls. The scenery band is built
## once per layout and never moves; the thirty tiles go into a second mesh
## rebuilt only while something is moving, because none of them has a face on
## it and a Control per tile would be thirty nodes for a field of rounded
## squares. The letters are draw commands over the top (Mosaic.letter, which
## is draw_set_transform then draw_string), as Nonogram draws its clue
## numbers: a glyph in a mesh cache key would multiply every state by
## twenty-six. Everything is drawn, so every moment reads the flat boards'
## vocabulary as curves off core/motion.gd (rule 8 of docs/art/flat-motion.md)
## rather than tweening a node.
##
## **Its signature is the flip**, and it is the one thing on this screen with
## numbers of its own: the row's five tiles turn on their X axis in sequence,
## FLIP_STEP apart, each a scale.y squash to zero and back over FLIP_TIME,
## and a tile takes its colour at the halfway point -- edge-on, so the answer
## arrives *with* the turn and never before it. The keyboard is repainted only
## when the last tile of the row has landed: a key that greened while the
## third tile was still face-down would give the row away.
##
## Spec: docs/superpowers/specs/2026-09-19-hidden-word-flat-design.md,
## sections 3, 5, 7 and 9. Ported number for number from the canvas mock at
## docs/brainstorm/concepts.html#hiddenword, which is the reference for every
## measure and every timing here.

const State = preload("res://puzzles/hidden_word_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const SproutFace = preload("res://ui/faces/sprout_face.gd")

# --- this board's own three numbers (spec section 9) ---
## The flip: how far apart the five tiles start turning, and how long one
## tile's turn takes.
const FLIP_STEP := 0.16
const FLIP_TIME := 0.42
## How long a refusal's toast holds before it pops out again. `commit_row`
## raises it on a refused Enter; the number is here with the other two
## because it is one of this board's signature three and nothing else on
## the screen sets it.
const TOAST_HOLD := 1.2

# --- the grid, measured (spec section 5) ---
## Between tiles, and the card's own inset. Both are the mock's.
const GAP := 14.0
const INSET := 28.0
## The scenery band reserved at the card's foot. It is what buys the grid its
## cell: without it the tile is 169 and the six rows fill the card's inner
## height exactly, leaving a cloud nowhere to stand. At 1080x1920 the slot is
## 1140, so the cell is (1140 - 56 - 120 - 70) / 6 = **149**, the block is 801
## by 964 with 143 of side air, and the card comes back to exactly 1140.
const BAND := 120.0
## A tile's corner and the bottom edge under its face, in cells, and how far
## that edge goes toward the ink.
const RADIUS := 0.19
const EDGE := 0.05
const EDGE_MIN := 5.0
const EDGE_MIX := 0.26
## How far an empty tile's own edge goes toward the ink: less, because an
## empty tile is a bed and not a piece.
const EMPTY_MIX := 0.14
## A letter narrower than this fraction of its tile is a smudge rather than a
## letter, so an edge-on tile carries none.
const LETTER_EDGE := 0.12
## The pop a typed letter and its tile arrive with -- the family's recipe at
## its own time, not a constant copied off Motion (docs/art/flat-motion.md).
const TYPE_POP := 0.18
## How long the win screen waits after the solve, so the flip that won it can
## finish first.
const WIN_WAIT := 1.6

# --- the toast (spec section 8) ---
## The refusal pill over the top of the grid: its height, the paper either
## side of the line, the corner, how far above the card's own top it sits and
## the size and the ink of the line inside it. The corner is half the height,
## which is what makes it a pill rather than a card -- Face.Builder.round_rect
## clamps it there anyway, exactly as the mock's own `rr` does.
const TOAST_H := 76.0
const TOAST_PAD := 64.0
const TOAST_RADIUS := 38.0
const TOAST_RISE := 30.0
const TOAST_FONT := 34
const TOAST_INK := 0.92
## The three lines a refusal can say, indexed by the state's own code, and no
## others. OK is index 0 and never shows one.
## Translation keys (locale/ui.csv), read through tr() when drawn.
const TOAST_LINE := ["", "HW_TOAST_LENGTH", "HW_TOAST_NOT_WORD", "HW_TOAST_REPEAT"]

# --- the hint (spec section 10) ---
## A hint's letter is a given and not a guess, so it is drawn ghosted.
const GHOST := 0.55

# --- the solve and the reveal (spec section 9's table) ---
## How far the rows that did not win fade back while the winning row hops,
## and how far every row fades once the sixth has been spent. These and the
## four below are the ending's own numbers rather than the vocabulary's:
## core/motion.gd has no reveal, because no other board can run out.
const SOLVE_DIM := 0.3
const OVER_DIM := 0.4
const DIM_TIME := 0.3
## How long the keyboard takes to leave, and the sprout's own rise -- how long
## it waits after the last tile lands, how far below its seat it starts, how
## long it takes and how long it fades in over.
const KEYS_OUT := 0.25
const REVEAL_WAIT := 0.1
const REVEAL_RISE := 200.0
const REVEAL_TIME := 0.35
const REVEAL_FADE := 0.25
## The reveal, laid out on the scenery band: its top, the sprout's centre in
## from the card's left and R, then the word card's left, the paper it leaves
## at the right, its height, corner and edge, and the two lines inside it.
const REVEAL_TOP := -12.0
const SPROUT_AT := Vector2(118.0, 76.0)
const SPROUT_R := 66.0
const WORD_CARD_X := 206.0
const WORD_CARD_RIGHT := 40.0
const WORD_CARD_H := 140.0
const WORD_CARD_RADIUS := 28.0
const WORD_CARD_EDGE := 6.0
const WORD_TEXT_X := 36.0
const WORD_LABEL_Y := 50.0
const WORD_LABEL_FONT := 30
const WORD_Y := 96.0
const WORD_FONT := 48
const WORD_SPACING := 3

# --- the scenery band, ported from the mock's `scenery()` ---
## The turf's top edge, measured up from the foot of the band, and the band's
## corner and the lighter crown along its top.
const TURF_TOP := 44.0
const TURF_RADIUS := 24.0
const CROWN_H := 24.0
const CROWN_RADIUS := 14.0
## Two clouds in the side air the band bought, each x in from its own side of
## the card's inner width, y down from the card's top, and its radius.
const CLOUD_LEFT := Vector3(36.0, 176.0, 20.0)
const CLOUD_RIGHT := Vector3(36.0, 286.0, 17.0)
## Blades standing out of the turf: how many, how far in from each end they
## start, their half-width at the root, and the band their height falls in.
const BLADES := 20
const BLADE_EDGE := 26.0
const BLADE_W := 5.0
const BLADE_ROOT := 3.0
const BLADE_MIN := 9.0
const BLADE_SPREAD := 15.0
const BLADE_LEAN := 7.0
## Three bushes on the ground line: x (from the left, or negative from the
## right, or a fraction of the width when between 0 and 1) and the radius.
const BUSH_LEFT := Vector2(118.0, 36.0)
const BUSH_MID := Vector2(0.47, 25.0)
const BUSH_RIGHT := Vector2(-138.0, 31.0)
## And the mock's three flowers, each x the same way and y below the ground
## line.
const FLOWER_LEFT := Vector2(232.0, 18.0)
const FLOWER_MID := Vector2(0.67, 24.0)
const FLOWER_RIGHT := Vector2(-238.0, 16.0)
const FLOWER_PETALS := 5
const FLOWER_R := 7.0
const PETAL_R := 5.5
const FLOWER_EYE_R := 4.0
## How far each green is lifted toward the card's parchment, so the band
## recedes behind the grid rather than competing with it.
const TURF_WASH := 0.52
const CROWN_WASH := 0.3
const BLADE_WASH := 0.24
const BUSH_DEEP_WASH := 0.3
const BUSH_LIT_WASH := 0.12

## The three marks' faces, in the order HIT, NEAR, MISS.
const MARK := [Pal.GOOD, Pal.WORD_NEAR, Pal.WORD_MISS]

var state = State.new()
## The board's own effects node, as on every flat board: the hint's ring
## and sparkle (func hint(), below) come through it and nowhere else.
var fx: Node2D
## The keyboard, handed over once by the host after the board is spawned. A
## harness that builds this board without a tray leaves it null, so every use
## of it is guarded.
var _tray: Control = null

## Every drawn thing's moments, each the second it began, read off Motion's
## curve readers in _build_grid and _draw_letters.
## The second each committed row began its flip; -1 while the row is unplayed.
var _row_at: Array[float] = []
## The latest of those, and which row it belongs to -- the flip in hand.
var _flip_at := -100.0
var _flip_row := -1
## Per column of the working row: when its letter was typed, and when a
## letter was erased off it (with the letter that left, which the state has
## already forgotten).
var _typed_at: Array[float] = []
var _gone_at: Array[float] = []
var _gone_ch: Array[String] = []
## Per row: when a refused Enter shivered it.
var _shiver_at: Array[float] = []
## Column -> the second a hint revealed the answer's letter there.
## `_ghost_letter` draws the ghost off it; it is here because the board owns
## its moments.
var _given_at: Dictionary = {}
## The keyboard repaints still owed, in the order they were earned: each is
## `{"at", "marks", "letters"}` -- the second that row's last tile lands, and
## what that row taught, **snapshotted at the moment it was committed**.
##
## Two things about this are load-bearing, and both were bugs first. It is a
## queue and not one slot, because a second Enter inside the 1.06 s a row
## takes to turn used to overwrite the repaint waiting on the first row --
## and `KeyBoard.set_marks` is additive and never re-runs over an older row,
## so those letters stayed unpainted *for the rest of the game* and the
## keyboard silently lied about what had been guessed. And the payload is
## snapshotted rather than re-derived when it comes due, for the very rule
## the delay exists to keep: `state.key_mark` reads every committed row, so a
## repaint resolved late would carry a **newer** row's marks and give that
## row away while its own tiles were still face-down.
var _keys_due: Array = []
## The refusal in hand: an index into TOAST_LINE (0 for none) and the second
## it popped up. One at a time -- a second refusal replaces the first rather
## than stacking, because two pills over one grid is a pile of paper.
var _toast := 0
var _toast_at := -100.0
## The second the winning row landed, and the second the sixth row did. Both
## are in the future while that row is still turning, which is the whole
## point: the hop, the dim, the sprout and the word all wait for the tiles.
var _solved_at := -100.0
var _over_at := -100.0
## When the keyboard is due to leave. Whether it has gone is the tray's own
## `gone`, not a second copy here: the settings sheet's New puzzle spawns a
## fresh board against the same tray, and a board that had just learned the
## keyboard was still on screen would leave it slid out for good.
var _keys_out_at := INF
## Reset's wave: one {"r", "c", "ch", "m", "at"} per committed tile on its way
## out, drawn over the bed that is already underneath it.
var _ghosts: Array = []
## The sparkles still owed, each {"at", "r", "c"}: the solve's five arrive one
## SOLVE_STAGGER after another, so they cannot all be fired at the commit.
var _fx_due: Array = []
## Sounds waiting on a clock, oldest first: each tile's flip as it starts to
## turn, and the win or the loss once the row that decided it has landed.
var _cue_due: Array = []
## The sprout the reveal raises. Built on the first ending and kept, because
## Reset can put the board back into play and a second sixth row can come.
var _sprout: Control = null

var _opened := 0.0
var _anim_until := 0.0
## The band, built once per layout, and the grid, rebuilt while it moves.
var _band_mesh: ArrayMesh
var _grid_mesh: ArrayMesh
## The toast's pill and the reveal's word card, each built once -- when the
## line changes and when the reveal begins -- and drawn with a transform, so
## neither is rebuilt per frame while it moves.
var _toast_mesh: ArrayMesh
var _toast_mesh_for := -1
var _reveal_mesh: ArrayMesh
## The meshes the last _draw actually handed to the canvas item. A canvas
## command holds a mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: Array = []

func puzzle_id() -> String: return "hiddenword"
func title() -> String: return "Hidden Word"

func rules() -> String:
	return tr("HW_RULES")

## Hidden Word has no cycling tip, but it still uses the shared How to play
## card as the door to the rules sheet. Keep its resting line specific to this
## game instead of falling back to Binairo's default tip.
func tip_line() -> Dictionary:
	return {"text": tr("HW_TIP"), "mood": Face.Expr.HAPPY}

## Hint alone. Every Enter *is* the check, and taking a committed guess back
## is not this game, so there is no Check and no Undo -- the top bar hides
## what is not named here.
func capabilities() -> Array[String]:
	return ["hint"]

func _ready() -> void:
	# The keyboard takes every tap; nothing on the card is touched.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	resized.connect(_layout)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	state.setup(rng, difficulty)
	if _tray != null:
		_tray.match_locale()
	_row_at = []
	_shiver_at = []
	for _r in State.ROWS:
		_row_at.append(-100.0)
		_shiver_at.append(-100.0)
	_clear_working()
	_given_at = {}
	_flip_at = -100.0
	_flip_row = -1
	_keys_due = []
	_clear_endings()
	_layout()
	_enter()

## Everything a finished board leaves behind: the refusal in hand, the solve,
## the reveal and the waves either of them owns. Both build() (a new word) and
## reset_board() (the same word again) go through it, because a board that
## kept `_over_at` would raise the sprout over an empty grid.
func _clear_endings() -> void:
	_toast = 0
	_toast_at = -100.0
	_solved_at = -100.0
	_over_at = -100.0
	_ghosts = []
	_fx_due = []
	_cue_due = []
	if _sprout != null:
		_sprout.visible = false
	_bring_keys_back()

## Puts a keyboard that was sent away back on screen. `slide_out` is
## reversible: the same tray slides back from the same `enter_from`, fades in
## and re-enables every key, so nothing here has to be undone by hand.
func _bring_keys_back() -> void:
	_keys_out_at = INF
	if _tray != null and _tray.gone:
		_tray.enter(0.0)

## The keyboard, handed over by the host once per spawn. The board paints it
## from the row it has just marked; nothing else writes to it.
func set_tray(t: Control) -> void:
	_tray = t
	_tray.match_locale()
	# A handoff is once per board, and the same tray outlives the board that
	# had it: the settings sheet's New puzzle spawns a fresh one against it.
	# So the new word starts with the keys untouched, and with the keyboard
	# on screen even if the board before it ran out of rows and sent it away.
	_tray.clear_marks()
	_bring_keys_back()

# --- layout ---

## The largest tile six rows of five hold inside a card of `available`
## height, once the band at its foot has been paid for. Height binds on a
## 9:16 phone -- 149 against the 177.6 the width would allow -- which is why
## the band costs the grid its cell rather than its air.
func _cell_for(available: float) -> float:
	var w := size.x - INSET * 2.0
	var h := available - INSET * 2.0 - BAND
	return maxf(0.0, minf((w - GAP * float(State.LEN - 1)) / float(State.LEN),
		(h - GAP * float(State.ROWS - 1)) / float(State.ROWS)))

func _cell() -> float:
	return _cell_for(size.y)

## The grid block's own size: five tiles across, six down, with the gaps.
func _block() -> Vector2:
	var c := _cell()
	return Vector2(float(State.LEN) * c + GAP * float(State.LEN - 1),
		float(State.ROWS) * c + GAP * float(State.ROWS - 1))

## The card this board wants: the block, the band and the inset either side.
## At 1140 of slot that is 964 + 120 + 56 = 1140 again, so the card fills the
## slot exactly and the slack card_centred() would halve is zero.
func card_height(available: float) -> float:
	var c := _cell_for(available)
	if c <= 0.0:
		return available
	return minf(available, float(State.ROWS) * c + GAP * float(State.ROWS - 1)
		+ BAND + INSET * 2.0)

## True, and honestly so: the height binds in a 9:16 slot with the band or
## without it, so **the slack is zero at 1080x1920 and this call does nothing
## on the phone this game is built for**. It earns its keep on a squarer
## screen, where the width binds instead and the block wants centring.
func card_centred() -> bool:
	return true

## The card's top inside this Control's rect. The host centres the card in
## the slot when card_centred() is true, and the block has to be seated
## against the card and not against the slot, or the two drift apart on a
## screen where the slack is not zero.
func _card_top() -> float:
	return maxf(0.0, (size.y - card_height(size.y)) * 0.5)

## The grid block's top-left inside this Control's rect.
func _origin() -> Vector2:
	return Vector2((size.x - _block().x) * 0.5, _card_top() + INSET)

## The centre of the block: what the entrance pops about.
func _grid_centre() -> Vector2:
	return _origin() + _block() * 0.5

## The top-left of the tile at (row, column).
func _tile_at(r: int, c: int) -> Vector2:
	var cell := _cell()
	return _origin() + Vector2(float(c) * (cell + GAP), float(r) * (cell + GAP))

## Control-local point over the centre of the tile at (row, column), the name
## every flat board gives it.
func cell_to_local(r: int, c: int) -> Vector2:
	return _tile_at(r, c) + Vector2.ONE * (_cell() * 0.5)

## The band's top, which the reveal stands on.
func _reveal_top() -> float:
	return _origin().y + _block().y + REVEAL_TOP

func _layout() -> void:
	_band_mesh = null
	_reveal_mesh = null
	_toast_mesh = null
	_toast_mesh_for = -1
	_refresh()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	var now := _now()
	_deliver_keys(now)
	_deliver_fx(now)
	_deliver_cues(now)
	_expire(now)
	_send_keys_away(now)
	_ride_sprout(now)
	if _laid_out() and _animating(now):
		queue_redraw()

## Drops what has finished: the toast once its pop-out is spent, and Reset's
## tiles once theirs is. Both are drawn off their own moment, so leaving them
## in the list would only cost work -- but the toast must go, or _draw would
## keep asking pop_out_scale for a scale it has already answered zero to.
func _expire(now: float) -> void:
	var dropped := false
	if _toast > 0 and now - _toast_at >= TOAST_HOLD + Motion.POP_OUT:
		_toast = 0
		dropped = true
	for i in range(_ghosts.size() - 1, -1, -1):
		if now - float(_ghosts[i].at) >= Motion.POP_OUT:
			_ghosts.remove_at(i)
			dropped = true
	# The frame that drops the last of them may be the first frame
	# `_animating` has answered false on, and then nothing would ask for the
	# draw that takes it off the screen. Asking here costs one draw and does
	# not depend on `_busy_for` having been given a hair more than it needs.
	if dropped:
		_refresh()

## The keyboard leaves when the sixth row has landed and not a moment before:
## it slides out over KEYS_OUT and every key stops taking input.
func _send_keys_away(now: float) -> void:
	if now < _keys_out_at:
		return
	_keys_out_at = INF
	if _tray != null:
		_tray.slide_out(KEYS_OUT)

## The engine runs _process and _draw from the moment the node enters the
## tree; the board only exists once build() has been through and the host's
## layout has given it a rect.
func _laid_out() -> bool:
	return _row_at.size() == State.ROWS and _cell() > 0.0

## True while **any** wave on this board is still running. Two moments are
## named outright -- the entrance and the flip -- and every other one
## registers its own end through `_busy_for`, so a wave says how long it needs
## at the moment it starts rather than being remembered here. In full, what
## `_anim_until` is holding open for:
##
## - the typed letter's pop and the erased one's turn out (TYPE_POP, POP_OUT);
## - the refused row's shiver and **the toast** over it, which outlives the
##   shiver five times over (TOAST_HOLD + POP_OUT);
## - **the hint's** ghost letter dropping in and the key greening behind it
##   (DROP_TIME + BUMP_TIME; the ring and the sparkles are the Fx2D node's
##   own children and animate themselves);
## - the row's flip and the keyboard's repaint after it (the `landed` window
##   plus BUMP_TIME, which commit_row posts);
## - **the solve**, from the moment the row lands through the last tile's hop
##   (SOLVE_DELAY + four SOLVE_STAGGERs + SOLVE_TIME) -- longer than the dim
##   behind it, so the one figure covers both;
## - **the reveal**, from the same landing through the sprout's rise
##   (REVEAL_WAIT + REVEAL_TIME) -- longer than the rows' dim and the
##   keyboard's exit;
## - **Reset's** wave, the last tile's delay plus its turn out.
##
## There is deliberately no branch for the keyboard's pending repaint. The
## window before it lands is the flip's own, which the line below already
## covers, and the BUMP_TIME after it is covered by commit_row's `_busy_for`.
## A branch here read `_keys_due`'s due time a frame after _process had
## already delivered and dropped it, so it never saw the window it claimed to
## hold open. One Line froze two lines at four fifths of their fade by asking
## about the entrance alone; it showed on a rendered frame and in no test.
func _animating(t: float) -> bool:
	if t < _opened + Motion.ENTER_DELAY + Motion.ENTER_POP:
		return true
	if _flip_row >= 0 and t < _flip_at + _flip_length():
		return true
	return t < _anim_until

## Keeps the board redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the grid mesh so the next _draw rebuilds it, and asks for that draw.
## The mesh the last _draw handed over is still held by _shown, so the
## renderer is never left pointing at a freed RID.
func _refresh() -> void:
	_grid_mesh = null
	queue_redraw()

# --- the drawing ---

## The band under everything, still; then the grid, which pops in wide about
## its centre (rule 7: a wide thing comes from most of the way) while it
## fades, as one draw transform over the mesh; then the letters over that,
## one draw command each.
func _draw() -> void:
	if not _laid_out():
		return
	var now := _now()
	var shown: Array = []
	if _band_mesh == null:
		_band_mesh = _build_band()
	if _band_mesh != null:
		draw_mesh(_band_mesh, null)
		shown.append(_band_mesh)
	if _grid_mesh == null or _animating(now):
		_grid_mesh = _build_grid(now)
	if _grid_mesh != null:
		var since := now - _opened - Motion.ENTER_DELAY
		var seen := Motion.appear_level(since, Motion.ENTER_POP)
		if seen > 0.0:
			var grow := Motion.wide_pop_scale(since)
			var mid := _grid_centre()
			draw_mesh(_grid_mesh, null,
				Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow)),
				Color(1.0, 1.0, 1.0, seen))
			shown.append(_grid_mesh)
	_draw_letters(now)
	_draw_reveal(now, shown)
	_draw_toast(now, shown)
	_shown = shown

## The scenery band at the card's foot: two clouds high in the side air the
## band bought, a washed turf with a lighter crown along its top, blades
## standing out of it, three bushes on the ground line and the mock's three
## flowers. It stands still -- only the grid takes the entrance -- so it is
## built once per layout and drawn with no transform.
##
## The clouds are the family's own (ui/flat/scenery.gd, the shape and the
## lift Balance's card wears); they go into this board's builder rather than
## into a Scenery node of their own so the whole band costs one draw call.
func _build_band() -> ArrayMesh:
	var cell := _cell()
	if cell <= 0.0:
		return null
	var b := Face.Builder.new()
	var x0 := INSET
	var w := size.x - INSET * 2.0
	var top := _card_top()
	var y0 := _origin().y + _block().y
	var ground := y0 + BAND - TURF_TOP
	var puff: Color = Pal.PARCHMENT.lerp(Pal.SURFACE, Scenery.CLOUD_LIFT)
	Scenery.cloud(b, Vector2(x0 + CLOUD_LEFT.x, top + CLOUD_LEFT.y), CLOUD_LEFT.z, puff)
	Scenery.cloud(b, Vector2(x0 + w - CLOUD_RIGHT.x, top + CLOUD_RIGHT.y), CLOUD_RIGHT.z, puff)
	var turf: Color = Pal.LEAF.lerp(Pal.PARCHMENT, TURF_WASH)
	var crown: Color = Pal.LEAF_LIGHT.lerp(Pal.PARCHMENT, CROWN_WASH)
	b.fan(Face.Builder.round_rect(Vector2(x0, ground), Vector2(w, BAND - TURF_TOP), TURF_RADIUS), turf)
	b.fan(Face.Builder.round_rect(Vector2(x0, ground), Vector2(w, CROWN_H), CROWN_RADIUS), crown)
	var blade: Color = Pal.LEAF.lerp(Pal.PARCHMENT, BLADE_WASH)
	var step := (w - BLADE_EDGE * 2.0) / float(BLADES - 1)
	for i in BLADES:
		var x := x0 + BLADE_EDGE + float(i) * step
		var h := BLADE_MIN + _hash(i, 5) * BLADE_SPREAD
		var lean := (_hash(i, 9) - 0.5) * BLADE_LEAN
		var foot := Vector2(x - BLADE_W, ground + BLADE_ROOT)
		var tip := Vector2(x + BLADE_W, ground + BLADE_ROOT)
		var pts := Face.Builder.bezier2(foot, Vector2(x + lean, ground - h), tip, 8)
		pts.append(tip)
		b.polygon(pts, blade)
	var deep: Color = Pal.LEAF_DEEP.lerp(Pal.PARCHMENT, BUSH_DEEP_WASH)
	var lit: Color = Pal.LEAF.lerp(Pal.PARCHMENT, BUSH_LIT_WASH)
	for bush: Vector2 in [BUSH_LEFT, BUSH_MID, BUSH_RIGHT]:
		_bush(b, _span(x0, w, bush.x), ground, bush.y, deep, lit)
	for flower: Vector2 in [FLOWER_LEFT, FLOWER_MID, FLOWER_RIGHT]:
		_flower(b, Vector2(_span(x0, w, flower.x), ground + flower.y))
	return b.mesh() if not b.verts.is_empty() else null

## The mock's own x convention for a thing on the band: a fraction of the
## width between 0 and 1, so many pixels in from the left above that, and so
## many in from the right when it is negative.
func _span(x0: float, w: float, x: float) -> float:
	if x > 0.0 and x < 1.0:
		return x0 + w * x
	return x0 + (x if x >= 0.0 else w + x)

## Three deep puffs with a lit one on the shoulder, seated on the ground line.
func _bush(b, x: float, ground: float, r: float, deep: Color, lit: Color) -> void:
	b.disc(Vector2(x, ground - r * 0.58), r, deep)
	b.disc(Vector2(x - r * 0.82, ground - r * 0.24), r * 0.64, deep)
	b.disc(Vector2(x + r * 0.84, ground - r * 0.26), r * 0.6, deep)
	b.disc(Vector2(x - r * 0.24, ground - r * 0.9), r * 0.4, lit)

## Five petals round a sun-coloured eye.
func _flower(b, at: Vector2) -> void:
	for k in FLOWER_PETALS:
		var a := float(k) / float(FLOWER_PETALS) * TAU
		b.disc(at + Vector2(cos(a), sin(a)) * FLOWER_R, PETAL_R, Pal.SURFACE)
	b.disc(at, FLOWER_EYE_R, Pal.SUN)

## The thirty tiles, in one mesh: an empty bed in SURFACE_HI, a typed tile
## arriving with the pop, and a committed tile mid-turn or landed in its
## mark's colour. A refused row shivers as one, so the offset is read per row
## and not per tile.
##
## There is no `Mosaic.socket` under the tile, and the mock has none either:
## every cell here is the *same* rounded card in one of four colours, so an
## empty tile already is its own bed and a socket laid under it would be
## covered by the thing it was meant to seat. What Nonogram needs a socket
## for -- a floor that shows through where no tile has been laid -- this
## board never has, because all thirty cells are always there.
func _build_grid(t: float) -> ArrayMesh:
	var cell := _cell()
	var b := Face.Builder.new()
	var work := _working_row()
	for r in State.ROWS:
		var shake := Motion.shiver_offset(t - _shiver_at[r])
		var fade := _row_alpha(r, t)
		for c in State.LEN:
			var at := _tile_at(r, c) + Vector2(shake, _solve_lift(r, c, t))
			var grow := Vector2.ONE
			var fill: Color = Pal.SURFACE_HI
			var deep: Color = Pal.SURFACE_HI.lerp(Pal.TEXT, EMPTY_MIX)
			if r < state.rows.size():
				var turn := _flip(r, c, t)
				grow.y = turn.x
				if turn.y >= 1.0:
					var m := int(state.marks[r][c])
					fill = MARK[m]
					deep = fill.lerp(Pal.TEXT, EDGE_MIX)
			elif r == work and c < state.typed.length():
				grow = Motion.pop_in_scale(t - _typed_at[c], TYPE_POP)
			_tile_face(b, at, cell, fill, deep, grow, fade)
	# Reset's wave, over the beds the tiles have just gone back to being: a
	# committed tile keeps its mark's colour and turns out where it stood.
	for g in _ghosts:
		var elapsed: float = t - float(g.at)
		var m := int(g.m)
		var fill: Color = MARK[m]
		var deep: Color = fill.lerp(Pal.TEXT, EDGE_MIX)
		var at := _tile_at(int(g.r), int(g.c))
		if elapsed < 0.0:
			_tile_face(b, at, cell, fill, deep, Vector2.ONE)
			continue
		var out := Motion.pop_out_scale(elapsed)
		if out <= 0.0:
			continue
		_tile_face(b, at, cell, fill, deep, Vector2.ONE * out, 1.0, _turn_out(elapsed))
	return b.mesh() if not b.verts.is_empty() else null

## The quarter turn a thing leaving takes with it, `elapsed` into its pop out.
func _turn_out(elapsed: float) -> float:
	return PI * 0.5 * clampf(elapsed / Motion.POP_OUT, 0.0, 1.0)

## How lit row `r` is. The solve leaves the winning row alone and takes the
## rows that came before it back to SOLVE_DIM, so the answer is the only
## thing burning; the reveal takes the whole grid to OVER_DIM, because there
## is no winning row to spare. An empty bed keeps its own light either way,
## which is the mock's own reading: a bed is not a guess.
func _row_alpha(r: int, t: float) -> float:
	var a := 1.0
	if _over_at > -50.0:
		a = lerpf(1.0, OVER_DIM, Motion.appear_level(t - _over_at, DIM_TIME))
	if _solved_at > -50.0 and r < state.rows.size() and r != state.rows.size() - 1:
		a *= lerpf(1.0, SOLVE_DIM, Motion.appear_level(t - _solved_at, Motion.SOLVE_TIME))
	return a

## The solve's hop: the winning row's tiles lift SOLVE_HOP letter by letter,
## SOLVE_STAGGER apart after SOLVE_DELAY, from the moment the row **landed**
## and not from the Enter that won it.
func _solve_lift(r: int, c: int, t: float) -> float:
	if _solved_at <= -50.0 or r != state.rows.size() - 1:
		return 0.0
	return Motion.hop_lift(t - (_solved_at + Motion.SOLVE_DELAY + float(c) * Motion.SOLVE_STAGGER),
		Motion.SOLVE_HOP, Motion.SOLVE_TIME)

## A tile's turn at `t`: x is its scale.y, y is 1 once it has taken its
## colour. `abs(cos(PI * u))` squashes it to nothing and back over FLIP_TIME,
## and the colour arrives at the halfway point -- edge-on, so the answer comes
## *with* the turn. Under reduce motion the row is coloured in one frame and
## never turns.
func _flip(r: int, c: int, t: float) -> Vector2:
	if Motion.reduce:
		return Vector2(1.0, 1.0)
	var since := t - (_row_at[r] + float(c) * FLIP_STEP)
	if since >= FLIP_TIME:
		return Vector2(1.0, 1.0)
	if since <= 0.0:
		return Vector2(1.0, 0.0)
	var u := since / FLIP_TIME
	return Vector2(absf(cos(PI * u)), 1.0 if u >= 0.5 else 0.0)

## One tile: its face over a bottom edge in a darker shade of itself, the
## soft lip every card on these screens wears, drawn at `grow` of its size
## about its own centre so the flip's squash reads.
func _tile_face(b, at: Vector2, s: float, fill: Color, deep: Color, grow: Vector2,
		alpha := 1.0, angle := 0.0) -> void:
	if grow.x <= 0.0 or grow.y <= 0.0 or alpha <= 0.0:
		return
	var edge := maxf(EDGE_MIN, s * EDGE)
	var r := s * RADIUS
	var corner := -Vector2.ONE * (s * 0.5)
	var xf := Transform2D(angle, grow, 0.0, at + Vector2.ONE * (s * 0.5))
	b.fan(xf * Face.Builder.round_rect(corner, Vector2(s, s), r), Color(deep, deep.a * alpha))
	b.fan(xf * Face.Builder.round_rect(corner, Vector2(s, s - edge), r), Color(fill, fill.a * alpha))

## The letters, over the grid's mesh and inside the same entrance: the
## working row's in ink, a committed row's in paper once its tile has turned
## far enough to carry one, and the letter an erase took away turning out
## where it stood. Thirty draw commands at the very most, and only when
## something has changed -- the grid does not redraw per frame.
func _draw_letters(t: float) -> void:
	var cell := _cell()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var pop := Motion.wide_pop_scale(since)
	var mid := _grid_centre()
	var font: Font = CozyTheme.display(700)
	var work := _working_row()
	for r in State.ROWS:
		var shake := Motion.shiver_offset(t - _shiver_at[r])
		var fade := _row_alpha(r, t) * seen
		for c in State.LEN:
			var seat := cell_to_local(r, c) + Vector2(shake, _solve_lift(r, c, t))
			seat = mid + (seat - mid) * pop
			if r < state.rows.size():
				var turn := _flip(r, c, t)
				if absf(turn.x) <= LETTER_EDGE:
					continue
				var ink: Color = Pal.PAPER if turn.y >= 1.0 else Pal.TEXT
				Mosaic.letter(self, seat, cell, state.rows[r][c],
					Vector2(pop, turn.x * pop), ink, font, fade)
			elif r == work:
				if c < state.typed.length():
					var grow := Motion.pop_in_scale(t - _typed_at[c], TYPE_POP)
					Mosaic.letter(self, seat, cell, state.typed[c], grow * pop,
						Pal.TEXT, font, fade)
				elif _gone_at[c] > 0.0 and t - _gone_at[c] < Motion.POP_OUT and not Motion.reduce:
					_letter_out(seat, cell, _gone_ch[c], t - _gone_at[c], pop, fade, font)
				elif state.given.has(c):
					# What a hint gave: the answer's own letter, dropping into
					# the column it belongs to and standing there ghosted
					# until the player types over it.
					_ghost_letter(seat, cell, state.answer[c],
						t - float(_given_at.get(c, -100.0)), pop, fade, font)
	# Reset's wave carries the letters out with the tiles.
	for g in _ghosts:
		var elapsed: float = t - float(g.at)
		var seat := cell_to_local(int(g.r), int(g.c))
		seat = mid + (seat - mid) * pop
		if elapsed < 0.0:
			Mosaic.letter(self, seat, cell, String(g.ch), Vector2.ONE * pop, Pal.PAPER, font, seen)
			continue
		_letter_out(seat, cell, String(g.ch), elapsed, pop, seen, font, Pal.PAPER)

## A hint's letter: it drops in from DROP above its column with the fade and
## then stands at GHOST in LEAF_DEEP, a given rather than a guess. Drawn
## whether or not the board is moving, because the ghost outlives its drop --
## it is there until the player types over that column, and under reduce
## motion it is simply there from the first frame.
func _ghost_letter(seat: Vector2, cell: float, ch: String, elapsed: float,
		pop: float, seen: float, font: Font) -> void:
	var a := Motion.appear_level(elapsed, Motion.DROP_FADE) * GHOST * seen
	if a <= 0.0:
		return
	var lift := Motion.drop_in_lift(elapsed)
	Mosaic.letter(self, seat - Vector2(0.0, lift * pop), cell, ch,
		Vector2.ONE * pop, Pal.LEAF_DEEP, font, a)

## The letter an erase took away: it shrinks out with the quarter turn where
## it stood, the family's own way out for a drawn thing. Mosaic.letter takes
## no angle -- nothing else in the game turns a glyph -- so this seats the
## same string itself, with Mosaic's own measure, rather than growing that
## call an argument its two other callers would never pass.
func _letter_out(seat: Vector2, cell: float, ch: String, elapsed: float,
		pop: float, seen: float, font: Font, ink: Color = Pal.TEXT) -> void:
	if ch.is_empty():
		return
	var grow := Motion.pop_out_scale(elapsed)
	if grow <= 0.0:
		return
	var angle := _turn_out(elapsed)
	var px := int(cell * Mosaic.LETTER_SIZE)
	var text := ch.to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var where := Vector2(-w * 0.5, font.get_height(px) * 0.5 - font.get_descent(px))
	draw_set_transform(seat, angle, Vector2.ONE * (grow * pop))
	font.draw_string(get_canvas_item(), where, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		px, Color(ink, seen))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- the toast (spec section 8) ---

## The refusal's pill, over the top of the grid and over the card's own edge:
## TEXT at TOAST_INK with the line in PAPER, popping in about its centre,
## holding TOAST_HOLD and popping out. Both scales are the family's readers
## at their own lengths, so the pill arrives and leaves like every other
## small thing on these screens and this board adds no number for it.
##
## Refusals do not get a card and they never get a colour: nothing here goes
## red, because a word this board does not know is not the player's mistake.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast <= 0:
		return
	var since := t - _toast_at
	if since < 0.0:
		return
	var grow: Vector2
	if since < TOAST_HOLD:
		grow = Motion.pop_in_scale(since)
	else:
		var out := Motion.pop_out_scale(since - TOAST_HOLD)
		if out <= 0.0:
			return
		grow = Vector2.ONE * out
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var font: Font = CozyTheme.body(700)
	var line: String = tr(TOAST_LINE[_toast])
	var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x + TOAST_PAD
	if _toast_mesh == null or _toast_mesh_for != _toast:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -TOAST_H) * 0.5, Vector2(w, TOAST_H), TOAST_RADIUS),
			Color(Pal.TEXT, TOAST_INK))
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = _toast
	if _toast_mesh == null:
		return
	var mid := Vector2(size.x * 0.5, _card_top() - TOAST_RISE + TOAST_H * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, grow, 0.0, mid))
	shown.append(_toast_mesh)
	var where := Vector2(-w * 0.5 + TOAST_PAD * 0.5,
		font.get_height(TOAST_FONT) * 0.5 - font.get_descent(TOAST_FONT))
	draw_set_transform(mid, 0.0, grow)
	font.draw_string(get_canvas_item(), where, line, HORIZONTAL_ALIGNMENT_LEFT, -1,
		TOAST_FONT, Color(Pal.PAPER, TOAST_INK))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- the reveal (spec section 8) ---

## The word on its own small card at the foot of the board, beside the sprout
## the board raises with it. It rises with the sprout and fades in with it,
## off the same two readers, because one is a node and the other is drawn and
## they have to arrive as one thing.
func _draw_reveal(t: float, shown: Array) -> void:
	if _over_at <= -50.0:
		return
	var since := t - _over_at - REVEAL_WAIT
	var a := Motion.appear_level(since, REVEAL_FADE)
	if a <= 0.0:
		return
	if _reveal_mesh == null:
		var b := Face.Builder.new()
		var w := size.x - WORD_CARD_X - WORD_CARD_RIGHT
		b.fan(Face.Builder.round_rect(Vector2(WORD_CARD_X, 0.0), Vector2(w, WORD_CARD_H),
			WORD_CARD_RADIUS), Pal.LINE)
		b.fan(Face.Builder.round_rect(Vector2(WORD_CARD_X, 0.0),
			Vector2(w, WORD_CARD_H - WORD_CARD_EDGE), WORD_CARD_RADIUS), Pal.SURFACE)
		_reveal_mesh = b.mesh() if not b.verts.is_empty() else null
	if _reveal_mesh == null:
		return
	var top := _reveal_top() + _reveal_rise(since)
	draw_mesh(_reveal_mesh, null, Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0.0, top)),
		Color(1.0, 1.0, 1.0, a))
	shown.append(_reveal_mesh)
	var x := WORD_CARD_X + WORD_TEXT_X
	_line(CozyTheme.body(500), WORD_LABEL_FONT, Vector2(x, top + WORD_LABEL_Y),
		tr("HW_WORD_WAS"), Color(Pal.TEXT_DIM, a))
	_line(CozyTheme.display(700, WORD_SPACING), WORD_FONT, Vector2(x, top + WORD_Y),
		state.written.to_upper(), Color(Pal.GOOD, a))

## How far below its seat the reveal still is, `since` seconds in: REVEAL_RISE
## taken home by the back ease, the curve `Motion.slide` would have used on a
## node. Nothing under reduce motion -- the sprout and the card are simply
## there.
func _reveal_rise(since: float) -> float:
	if Motion.reduce:
		return 0.0
	return REVEAL_RISE * (1.0 - Motion.back_out(clampf(since / REVEAL_TIME, 0.0, 1.0)))

## One line of text seated by its left edge and its middle, the way the mock
## lays every line out; draw_string wants a baseline instead.
func _line(font: Font, px: int, at: Vector2, text: String, colour: Color) -> void:
	font.draw_string(get_canvas_item(),
		at + Vector2(0.0, font.get_height(px) * 0.5 - font.get_descent(px)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour)

## The sprout rides the board's clock, as One Line's walker does: it is a
## node (ui/faces/sprout_face.gd draws itself), but the card beside it is
## drawn, and a tween on one of them and a reader on the other would arrive a
## frame apart. Both read `_over_at` every frame instead.
func _ride_sprout(t: float) -> void:
	if _sprout == null or not _sprout.visible:
		return
	var since := t - _over_at - REVEAL_WAIT
	var seat := Vector2(SPROUT_AT.x, _reveal_top() + SPROUT_AT.y + _reveal_rise(since))
	_sprout.position = seat - _sprout.size * 0.5
	_sprout.modulate.a = Motion.appear_level(since, REVEAL_FADE)

## The sprout the reveal brings, built on the first ending and kept after it.
## It is sized so R comes out at SPROUT_R once the face's own REACH -- the
## room its leaves need above the blob -- has been paid for.
func _raise_sprout() -> void:
	if _sprout == null:
		_sprout = SproutFace.new()
		_sprout.name = "Sprout"
		_sprout.z_index = 1
		add_child(_sprout)
	var px := SPROUT_R * 2.0 * SproutFace.REACH
	_sprout.size = Vector2(px, px)
	_sprout.expression = Face.Expr.HAPPY
	_sprout.visible = true
	_sprout.modulate.a = 0.0
	_ride_sprout(_now())
	_sprout.set_idle(true)

# --- the three moves ---

## The row being typed, or -1 once all six are committed.
func _working_row() -> int:
	return state.rows.size() if state.rows.size() < State.ROWS else -1

## A letter off the keyboard. The tile takes it with the pop.
func type_letter(letter: String) -> void:
	if not state.type_letter(letter):
		return
	var i: int = state.typed.length() - 1
	_typed_at[i] = _now()
	_gone_at[i] = -100.0
	_gone_ch[i] = ""
	_busy_for(TYPE_POP)
	fx.cue("type")
	_refresh()

## Backspace. The letter shrinks out with the quarter turn; the tile it was
## on stays where it is and goes back to being a bed.
func erase_letter() -> void:
	var i: int = state.typed.length() - 1
	if i < 0:
		return
	var ch: String = state.typed[i]
	if not state.erase():
		return
	_typed_at[i] = -100.0
	_gone_at[i] = _now()
	_gone_ch[i] = ch
	_busy_for(Motion.POP_OUT)
	fx.cue("erase")
	_refresh()

## Enter. On OK the row turns over, a tile at a time; on any of the three
## refusals nothing commits, nothing counts, and the row shivers where it is
## (`_draw_toast` raises the toast that names the rule).
func commit_row() -> void:
	if is_done():
		return
	# The row that shivers is the one being typed. The is_done() guard above
	# is why this can be read without a clamp: a commit that fills the sixth
	# row always ends the board before commit_row returns (state.is_solved()
	# or state.is_over(), below, one or the other always holds once
	# rows.size() reaches State.ROWS), so a call that gets this far always
	# finds rows.size() < State.ROWS.
	var row: int = state.rows.size()
	var code := state.commit()
	if code != State.OK:
		_shiver_at[row] = _now()
		_toast = code
		_toast_at = _now()
		_busy_for(maxf(Motion.SHIVER_TIME, TOAST_HOLD + Motion.POP_OUT))
		fx.cue("refused")
		_refresh()
		return
	_flip_row = state.rows.size() - 1
	_flip_at = _now()
	_row_at[_flip_row] = _flip_at
	_clear_working()
	# The keyboard learns what the row learned only when the **last** tile of
	# it has landed. Painted a beat early, the keys would give the row away
	# while three of its tiles were still face-down. What it will be told is
	# settled now, while the state still ends at this row; when it is told is
	# `landed`, and a row committed on top of a row still turning queues
	# behind it rather than replacing it.
	var landed := _flip_at + _flip_length()
	# One flip a tile as it starts to turn, a touch higher each, so the row
	# is heard going over the way it is seen; under reduce motion, one.
	for c in (1 if Motion.reduce else State.LEN):
		_cue_due.append({"at": _flip_at + float(c) * FLIP_STEP, "cue": "flip",
			"pitch": 1.0 + 0.04 * float(c)})
	var due := _keys_payload(_flip_row)
	due["at"] = landed
	_keys_due.append(due)
	if Motion.reduce:
		_deliver_keys(landed)
	_busy_for(landed - _flip_at + Motion.BUMP_TIME)
	# The row that ends the game does it when it has **landed**, not when
	# Enter was pressed: a sprout that named the word while the sixth row was
	# still face-down would answer the board before it had finished asking.
	# The solve is the one exception, and only for the signal -- `solved`
	# fires now, because the host's own win_delay() is measured from here.
	if state.is_solved():
		_solved_at = landed
		_cue_due.append({"at": landed, "cue": "solved"})
		if not Motion.reduce:
			for c in State.LEN:
				_fx_due.append({
					"at": landed + Motion.SOLVE_DELAY + float(c) * Motion.SOLVE_STAGGER,
					"r": _flip_row, "c": c, "colour": Pal.SUN,
				})
		_busy_for(landed - _now() + Motion.SOLVE_DELAY
			+ float(State.LEN - 1) * Motion.SOLVE_STAGGER + Motion.SOLVE_TIME)
	elif state.is_over():
		_over_at = landed
		_keys_out_at = landed
		_cue_due.append({"at": landed, "cue": "lost"})
		_raise_sprout()
		_busy_for(landed - _now() + REVEAL_WAIT + REVEAL_TIME)
		finish_unsolved()
	_refresh()
	note_move()

## How long a whole row takes to turn over: the last tile starts four steps
## after the first and turns for FLIP_TIME. Nothing under reduce motion.
func _flip_length() -> float:
	if Motion.reduce:
		return 0.0
	return float(State.LEN - 1) * FLIP_STEP + FLIP_TIME

## What the keys `row` touched should say, and which of them bump. The marks
## are read back off the state (`key_mark`, which resolves best-mark-wins
## across every committed row), so a letter amber on row one and green on row
## three stays green. Called the moment `row` is committed, so `key_mark`
## sees exactly the rows up to and including it.
func _keys_payload(row: int) -> Dictionary:
	var marks: Dictionary = {}
	var letters: Array = []
	if row < 0 or row >= state.rows.size():
		return {"marks": marks, "letters": letters}
	var word: String = state.rows[row]
	for i in State.LEN:
		var ch := word[i]
		if not marks.has(ch):
			letters.append(ch)
		marks[ch] = state.key_mark(ch)
	return {"marks": marks, "letters": letters}

## Hands the keyboard every repaint that has come due, oldest first.
func _deliver_keys(now: float) -> void:
	while not _keys_due.is_empty() and now >= float(_keys_due[0].at):
		var due: Dictionary = _keys_due.pop_front()
		if _tray == null:
			continue
		_tray.set_marks(due.marks)
		_tray.bump(due.letters)

## Fires the sparkles that have come due. The solve's five are staggered
## across the winning row, so they cannot all be fired at the Enter that won
## it; Fx2D is the only place a spark comes from on this board.
func _deliver_fx(now: float) -> void:
	while not _fx_due.is_empty() and now >= float(_fx_due[0].at):
		var due: Dictionary = _fx_due.pop_front()
		fx.sparkle(cell_to_local(int(due.r), int(due.c)), due.get("colour", Pal.SUN))

## Plays the sounds that have come due (see `_cue_due`).
func _deliver_cues(now: float) -> void:
	while not _cue_due.is_empty() and now >= float(_cue_due[0].at):
		var due: Dictionary = _cue_due.pop_front()
		fx.cue(due.cue, due.get("pitch", 1.0))

func _clear_working() -> void:
	_typed_at = []
	_gone_at = []
	_gone_ch = []
	for _c in State.LEN:
		_typed_at.append(-100.0)
		_gone_at.append(-100.0)
		_gone_ch.append("")

# --- the moments the chrome asks for ---

## The chrome is the host's; here the grid pops in wide after the family's
## delay (in _draw), and the keyboard's own rows slide up under it.
func _enter() -> void:
	_opened = _now()
	_anim_until = _opened
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP)
	fx.cue("enter")

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

func hints_left() -> int:
	return state.hints_left

## A hint gives the leftmost letter the player has not greened: a ring over
## its column, the letter dropping into the working row ghosted at GHOST,
## sparkles in leaf, and that key greening with a bump.
##
## **It is a given and not a guess.** It never commits a row, it never counts
## as a move (`hints_used` rises; `moves` does not, so nothing here calls
## `note_move`), and the player still has to type the letter for it to be
## part of a guess. The key's own green goes through `_keys_due` like every
## other repaint on this board, so a hint taken while a row is still turning
## waits its turn behind that row rather than painting over it.
func hint() -> bool:
	var at := state.hint()
	if at < 0:
		return false
	# state.hint() answers -1 on a solved or a spent board, so there is always
	# a working row under the column it chose.
	var work: int = state.rows.size()
	if not Motion.reduce:
		fx.ring(cell_to_local(work, at), _cell() * 0.6, Pal.LEAF)
		_fx_due.append({"at": _now() + Motion.DROP_TIME * 0.5,
			"r": work, "c": at, "colour": Pal.LEAF})
	# Outside the reduce guard on purpose: the ghost is not decoration, it is
	# the letter the hint gave, and under reduce motion it has to be on the
	# board from the next frame rather than not at all.
	_given_at[at] = _now()
	var ch: String = state.answer[at]
	_keys_due.append({
		"at": _now() + (0.0 if Motion.reduce else Motion.DROP_TIME),
		"marks": {ch: State.HIT}, "letters": [ch],
	})
	hints_used += 1
	fx.cue("hint")
	_busy_for(Motion.DROP_TIME + Motion.BUMP_TIME)
	_refresh()
	check_solved()
	return true

## Replays the same day from the first row: every committed row's tiles turn
## out in a wave from the last row up, RESET_STAGGER a tile, and the keys go
## back to their untouched face together.
##
## **What a hint gave stays given.** `state.reset()` clears `rows`, `marks`
## and `typed` and leaves `hints_left` and `given` exactly where they were --
## Queens' own rule, and here it is load-bearing rather than tidy: Reset
## replays the *same word*, so refunding a hint would make the limit of two
## meaningless (hint, Reset, hint, Reset would spell the answer out a letter
## at a time) and discarding `given` would charge the player twice for the
## same letter. `_given_at` therefore survives too, and the ghost is back on
## the first row the moment the wave has passed.
##
## It also has to put a **finished** board back into play. Nothing else on
## this screen can be over without being solved, so nothing else has ever had
## to clear `_done`; a Reset that left it set would hand the player a board
## that took no keys and never ticked again.
func reset_board() -> void:
	var wave: Array = []
	if not Motion.reduce:
		for r in state.rows.size():
			for c in State.LEN:
				wave.append({
					"r": r, "c": c, "ch": state.rows[r][c], "m": int(state.marks[r][c]),
					"at": _now() + Motion.stagger(
						(state.rows.size() - 1 - r) * State.LEN + c, Motion.RESET_STAGGER),
				})
	state.reset()
	for r in State.ROWS:
		_row_at[r] = -100.0
		_shiver_at[r] = -100.0
	_clear_working()
	_flip_at = -100.0
	_flip_row = -1
	_keys_due = []
	# After _clear_endings, which empties the wave list along with the rest
	# of what the last ending left behind.
	_clear_endings()
	_ghosts = wave
	if _tray != null:
		_tray.clear_marks()
	moves = 0
	_done = false
	_running = true
	_busy_for(Motion.stagger(State.ROWS * State.LEN - 1, Motion.RESET_STAGGER) + Motion.POP_OUT)
	fx.cue("reset")
	_refresh()

## The rows the player committed, oldest first, so a reopened daily can lay
## the same ending back down. Plain strings, because it goes through a
## ConfigFile.
func completion_record() -> Dictionary:
	var out: Array = []
	for word in state.rows:
		out.append(String(word))
	return {"guesses": out}

## A reopened daily that was already solved: the rows go back down already
## committed and turned, in their marks' colours, the keyboard painted from
## them, and nothing moving -- no entrance, no flip, no hop, no sparkle. A
## save from before `completion_record()` existed has no rows to replay, so
## the answer alone stands on row one. Never check_solved(): the day was
## solved once and `solved` must not fire a second time.
func restore_completed_board() -> void:
	var guesses: Array[String] = _recorded_guesses()
	state.rows.clear()
	state.marks.clear()
	state.typed = ""
	for word in guesses:
		state.rows.append(word)
		state.marks.append(State.mark_guess(word, state.answer))
	var now := _now()
	for r in State.ROWS:
		_row_at[r] = -100.0
		_shiver_at[r] = -100.0
	_clear_working()
	_given_at = {}
	_flip_at = -100.0
	_flip_row = -1
	_keys_due = []
	_clear_endings()
	# Settled rather than unset: the rows before the winning one stand at
	# SOLVE_DIM and its hop has long since landed, which is how a live solve
	# leaves the card under the win screen. Ten seconds back and not a
	# hundred: anything under -50 reads as "never solved" (`_row_alpha`).
	_solved_at = now - 10.0
	# The entrance has already played.
	_opened = now - 10.0
	_anim_until = 0.0
	if _tray != null:
		_tray.clear_marks()
		var marks: Dictionary = {}
		for word in state.rows:
			for i in State.LEN:
				marks[word[i]] = state.key_mark(word[i])
		_tray.set_marks(marks)
	_refresh()

## The record's rows if they are a real ending for today's word -- at most six
## five-letter words, none repeated, the last one the answer -- and the answer
## alone otherwise.
func _recorded_guesses() -> Array[String]:
	var out: Array[String] = []
	var raw = completed_record.get("guesses", [])
	if raw is Array and not raw.is_empty() and raw.size() <= State.ROWS:
		for w in raw:
			var word := String(w).to_lower()
			if word.length() != State.LEN or out.has(word):
				out = []
				break
			out.append(word)
	if out.is_empty() or out[out.size() - 1] != state.answer:
		out = [state.answer]
	return out

## The win screen shows no cast: five green tiles spelling the word are what
## stays on the card under it, the way Nonogram leaves its picture.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("HW_WIN")}

## WIN_WAIT after the winning row has **landed**, not from the Enter that won
## it: `solved` fires the moment Enter is pressed, so a flat WIN_WAIT would
## raise the win screen 0.54 s after the last tile turned -- on top of the
## solve's own hop (`_solve_lift`, above), which starts a quarter of a
## second after the landing and runs for 0.4.
func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else _flip_length() + WIN_WAIT

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A fixed pseudo-random number per blade, so the band's grass is uneven in
## the same way on every launch.
static func _hash(a: int, b: int) -> float:
	return float(posmod(hash(Vector2i(a, b)), 1000)) / 1000.0
