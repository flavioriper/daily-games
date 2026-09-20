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

# --- this board's own three numbers (spec section 9) ---
## The flip: how far apart the five tiles start turning, and how long one
## tile's turn takes.
const FLIP_STEP := 0.16
const FLIP_TIME := 0.42
## How long a refusal's toast holds before it pops out again. Task 7 raises
## the toast; the number is here with the other two because it is one of this
## board's signature three and nothing else on the screen sets it.
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
## The board's own effects node, as on every flat board: Task 7's hint rings
## and sparkles come through it and nowhere else.
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
## Column -> the second a hint revealed the answer's letter there. Task 7
## draws the ghost off it; it is here because the board owns its moments.
var _given_at: Dictionary = {}
## When the keyboard is due its repaint: the second the last tile of the row
## in hand lands. INF when nothing is waiting.
var _keys_at := INF

var _opened := 0.0
var _anim_until := 0.0
## The band, built once per layout, and the grid, rebuilt while it moves.
var _band_mesh: ArrayMesh
var _grid_mesh: ArrayMesh
## The meshes the last _draw actually handed to the canvas item. A canvas
## command holds a mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card).
var _shown: Array = []

func puzzle_id() -> String: return "hiddenword"
func title() -> String: return "Hidden Word"

func rules() -> String:
	return "Guess the five-letter word in six tries. A green tile is the right letter in the right place; an amber one is in the word somewhere else; a grey one is not in the word at all."

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
	_row_at = []
	_shiver_at = []
	for _r in State.ROWS:
		_row_at.append(-100.0)
		_shiver_at.append(-100.0)
	_clear_working()
	_given_at = {}
	_flip_at = -100.0
	_flip_row = -1
	_keys_at = INF
	_layout()
	_enter()

## The keyboard, handed over by the host once per spawn. The board paints it
## from the row it has just marked; nothing else writes to it.
func set_tray(t: Control) -> void:
	_tray = t

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

func _layout() -> void:
	_band_mesh = null
	_refresh()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	var now := _now()
	if now >= _keys_at:
		_keys_at = INF
		_paint_keys()
	if _laid_out() and _animating(now):
		queue_redraw()

## The engine runs _process and _draw from the moment the node enters the
## tree; the board only exists once build() has been through and the host's
## layout has given it a rect.
func _laid_out() -> bool:
	return _row_at.size() == State.ROWS and _cell() > 0.0

## True while **any** wave on this board is still running. The three moments
## that outlive a single recipe are named outright -- the entrance, the flip
## and the keyboard's repaint -- and everything else registers its own end
## through _busy_for, so a moment added later (Task 7's toast, hint, Reset,
## solve and reveal) extends this by saying how long it needs rather than by
## being remembered here. One Line froze two lines at four fifths of their
## fade by asking about the entrance alone; it showed on a rendered frame and
## in no test.
func _animating(t: float) -> bool:
	if t < _opened + Motion.ENTER_DELAY + Motion.ENTER_POP:
		return true
	if _flip_row >= 0 and t < _flip_at + _flip_length():
		return true
	# Guarded against the rest: _keys_at is INF while nothing is waiting, and
	# `t < INF + BUMP_TIME` is true for every t there will ever be -- which
	# would leave the board rebuilding its thirty tiles on every frame of a
	# screen that is standing perfectly still.
	if not is_inf(_keys_at) and t < _keys_at + Motion.BUMP_TIME:
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
	_shown = shown
	_draw_letters(now)

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
	Scenery._cloud(b, Vector2(x0 + CLOUD_LEFT.x, top + CLOUD_LEFT.y), CLOUD_LEFT.z, puff)
	Scenery._cloud(b, Vector2(x0 + w - CLOUD_RIGHT.x, top + CLOUD_RIGHT.y), CLOUD_RIGHT.z, puff)
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
		for c in State.LEN:
			var at := _tile_at(r, c) + Vector2(shake, 0.0)
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
			_tile_face(b, at, cell, fill, deep, grow)
	return b.mesh() if not b.verts.is_empty() else null

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
func _tile_face(b, at: Vector2, s: float, fill: Color, deep: Color, grow: Vector2) -> void:
	if grow.x <= 0.0 or grow.y <= 0.0:
		return
	var edge := maxf(EDGE_MIN, s * EDGE)
	var r := s * RADIUS
	var corner := -Vector2.ONE * (s * 0.5)
	var xf := Transform2D(0.0, grow, 0.0, at + Vector2.ONE * (s * 0.5))
	b.fan(xf * Face.Builder.round_rect(corner, Vector2(s, s), r), deep)
	b.fan(xf * Face.Builder.round_rect(corner, Vector2(s, s - edge), r), fill)

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
		for c in State.LEN:
			var seat := cell_to_local(r, c) + Vector2(shake, 0.0)
			seat = mid + (seat - mid) * pop
			if r < state.rows.size():
				var turn := _flip(r, c, t)
				if absf(turn.x) <= LETTER_EDGE:
					continue
				var ink: Color = Pal.PAPER if turn.y >= 1.0 else Pal.TEXT
				Mosaic.letter(self, seat, cell, state.rows[r][c],
					Vector2(pop, turn.x * pop), ink, font, seen)
			elif r == work:
				if c < state.typed.length():
					var grow := Motion.pop_in_scale(t - _typed_at[c], TYPE_POP)
					Mosaic.letter(self, seat, cell, state.typed[c], grow * pop,
						Pal.TEXT, font, seen)
				elif _gone_at[c] > 0.0:
					_letter_out(seat, cell, _gone_ch[c], t - _gone_at[c], pop, seen, font)

## The letter an erase took away: it shrinks out with the quarter turn where
## it stood, the family's own way out for a drawn thing. Mosaic.letter takes
## no angle -- nothing else in the game turns a glyph -- so this seats the
## same string itself, with Mosaic's own measure, rather than growing that
## call an argument its two other callers would never pass.
func _letter_out(seat: Vector2, cell: float, ch: String, elapsed: float,
		pop: float, seen: float, font: Font) -> void:
	if ch.is_empty():
		return
	var grow := Motion.pop_out_scale(elapsed)
	if grow <= 0.0:
		return
	var angle := PI * 0.5 * clampf(elapsed / Motion.POP_OUT, 0.0, 1.0)
	var px := int(cell * Mosaic.LETTER_SIZE)
	var text := ch.to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var where := Vector2(-w * 0.5, font.get_height(px) * 0.5 - font.get_descent(px))
	draw_set_transform(seat, angle, Vector2.ONE * (grow * pop))
	font.draw_string(get_canvas_item(), where, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		px, Color(Pal.TEXT, seen))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
	_refresh()

## Enter. On OK the row turns over, a tile at a time; on any of the three
## refusals nothing commits, nothing counts, and the row shivers where it is
## (Task 7 raises the toast that names the rule).
func commit_row() -> void:
	if is_done():
		return
	# The row that shivers is the one being typed -- or, once all six are
	# committed and the board is only waiting for Task 7 to end it, the last
	# one, which is the row the finger is still over.
	var row: int = mini(state.rows.size(), State.ROWS - 1)
	var code := state.commit()
	if code != State.OK:
		_shiver_at[row] = _now()
		_busy_for(Motion.SHIVER_TIME)
		_refresh()
		return
	_flip_row = state.rows.size() - 1
	_flip_at = _now()
	_row_at[_flip_row] = _flip_at
	_clear_working()
	# The keyboard learns what the row learned only when the **last** tile of
	# it has landed. Painted a beat early, the keys would give the row away
	# while three of its tiles were still face-down.
	var landed := _flip_at + _flip_length()
	if Motion.reduce:
		_paint_keys()
	else:
		_keys_at = landed
	_busy_for(landed - _flip_at + Motion.BUMP_TIME)
	_refresh()
	note_move()

## How long a whole row takes to turn over: the last tile starts four steps
## after the first and turns for FLIP_TIME. Nothing under reduce motion.
func _flip_length() -> float:
	if Motion.reduce:
		return 0.0
	return float(State.LEN - 1) * FLIP_STEP + FLIP_TIME

## Repaints and bumps the keys the row in hand touched. The marks are read
## back off the state (`key_mark`, which resolves best-mark-wins across every
## committed row), so a letter amber on row one and green on row three stays
## green.
func _paint_keys() -> void:
	if _tray == null or _flip_row < 0 or _flip_row >= state.rows.size():
		return
	var marks: Dictionary = {}
	var letters: Array = []
	var word: String = state.rows[_flip_row]
	for i in State.LEN:
		var ch := word[i]
		if not marks.has(ch):
			letters.append(ch)
		marks[ch] = state.key_mark(ch)
	_tray.set_marks(marks)
	_tray.bump(letters)

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

## Task 7 builds the hint: the ring over the chosen column, the letter
## dropping in ghosted at 0.55, the sparkles in leaf and that key greening
## with a bump. It is a given and not a guess, so it never spends a row --
## which is why the state already has `given` and `_given_at` is already
## here. Until then the board has none to give.
func hint() -> bool:
	return false

## Replays the same day from the first row. Task 7 gives it its wave -- every
## committed row shrinking out from the last row up -- and brings the
## keyboard's colours back with it; this is the state and the moments the
## drawing reads, so a Reset already empties the board.
func reset_board() -> void:
	state.reset()
	for r in State.ROWS:
		_row_at[r] = -100.0
		_shiver_at[r] = -100.0
	_clear_working()
	_flip_at = -100.0
	_flip_row = -1
	_keys_at = INF
	moves = 0
	_running = true
	fx.cue("reset")
	_refresh()

## The win screen shows no cast: five green tiles spelling the word are what
## stays on the card under it, the way Nonogram leaves its picture.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "Found it."}

## WIN_WAIT after the winning row has **landed**, which is what the mock
## waits and not what the plan's snippet said: `solved` fires the moment
## Enter is pressed, so a flat WIN_WAIT would raise the win screen 0.54 s
## after the last tile turned -- on top of the solve's own hop, which Task 7
## starts a quarter of a second after the landing and runs for 0.4.
func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else _flip_length() + WIN_WAIT

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A fixed pseudo-random number per blade, so the band's grass is uneven in
## the same way on every launch.
static func _hash(a: int, b: int) -> float:
	return float(posmod(hash(Vector2i(a, b)), 1000)) / 1000.0
