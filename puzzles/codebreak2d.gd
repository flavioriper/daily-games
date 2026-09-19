extends "res://core/puzzle_base.gd"

## Code Break as a flat board, on trial beside the island version
## (puzzles/codebreak3d.gd) the way the flat Binairo is: the whole column on
## one parchment card, THE CODE under four wooden lids at the top, then the
## eight guess rows as one column of constant height -- the row you are
## filling at 190 tall with faces on its friends, every other row a compact
## 82-tall line of silhouettes with its score in a pouch at the right.
## Committing a row does not scroll: the played row shrinks while the next
## grows by the same amount over the same ease, so the sum never changes and
## the big row simply walks down the board. Every row wears its card from the
## first frame -- white at full size, a dimmed cream in the history -- with
## its sockets and an empty pouch waiting at its right, so the column reads
## finished before a single guess (the user's re-render of 2026-09-18).
##
## Its motion is the flat vocabulary's (core/motion.gd, "the flat boards'
## vocabulary"; docs/art/flat-motion.md is the table): the press, the pop in
## and out, the drop, the nudge, the ring and the solve wave are Binairo's
## own recipes, and only the flight from the palette, the dip under a score
## and the lids are this board's alone.
##
## The rules are puzzles/codebreak_state.gd, which this only draws. The one
## rule the drawing itself has to keep is that **the score is a count and
## never a map**: nothing on the screen -- not the pips' arrangement, not
## their colour, not a face, not the order things animate in -- may suggest
## which seat a pip came from.
##
## Drawn in the game's own design space: the column is 1000 units wide (the
## screen's 1080 less the host's two 40 margins) and `_column` carries one
## uniform scale, so every number below is the mock's own number
## (docs/brainstorm/concepts.html#codebreak). A seat is one Control at the
## full piece size carrying the socket, its dotted ring and the friend, and
## the row's growth is that Control's scale -- so a friend's mesh is built
## once and never rebuilt as its row grows.
## Spec: docs/superpowers/specs/2026-09-18-codebreak-flat-design.md.

const State = preload("res://puzzles/codebreak_state.gd")
const Friends = preload("res://ui/faces/friends.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")

# --- the column, in design units (spec section 4) ---
const COL_W := 1000.0
## Breathing room between the column and the card's edge.
const PAD := 28.0
## The row card, and the number at its left.
const CARD_X := 28.0
const CARD_W := 944.0
const NUM_X := 64.0
## The seats share one span in every row, so the eye reads four columns.
const SEAT_L := 120.0
const SEAT_R := 810.0
## The pouch's centre, clear of the seats.
const PIP_X := 897.0
const RH_SMALL := 82.0
const RH_BIG := 190.0
## A piece is at most 150 across, and always 22 short of the seat pitch.
const PIECE_MAX := 150.0
const PIECE_SLACK := 22.0
const PIECE_SMALL := 0.41
## The code row: the label, the lids' top, and the dotted rule under them.
const LABEL_Y := 16.0
const CODE_TOP := 36.0
const RULE_AFTER := 13.0
const ROWS_AFTER := 26.0
## The pouch and its pips.
const POUCH := Vector2(118.0, 74.0)
const PIP_R := 13.0
const PIP_STEP := 34.0
const PIP_JITTER := 5.0
## A row wears faces only once it is more than this big; below it the
## friends are silhouettes, because 62 units is 22 pixels on a phone.
const FACES_ABOVE := 0.35
## The history's dressing, as a blend toward the active row's: its card is
## parchment warmed this far toward white, and its sockets, rings, numbers
## and unscored pouch sit at these alphas. A scored pouch is the record and
## never dims.
const ROW_DIM := 0.45
const SOCKET_DIM := 0.72
const RING_DIM := 0.55
const POUCH_DIM := 0.6
## The two amber sparks flanking the lids: this far outside the outer lids,
## and this long. Decoration; they flash when the code stirs.
const SPARK_GAP := 44.0
const SPARK_LEN := 26.0

# --- motion (spec section 5), the mock's numbers where the flat vocabulary
# has none of its own ---
const ENTER_ROW := 0.2
const ENTER_ROW_FADE := 0.2
const ENTER_LID := 0.55
const ENTER_LID_STAGGER := 0.06
const ENTER_LID_TIME := 0.3
const ENTER_SPARKS := 0.9
const FLY_TIME := 0.34
const FLY_ARC := 110.0
const FLY_FROM := 0.78
const LAND_SQUASH := 0.12
## The seats either side lean 7 rather than the vocabulary's 3, after the
## flight has all but landed.
const NUDGE_AFTER := 0.24
const NUDGE := 7.0
const FULL_HOP := -7.0
const OUT_LIFT := 24.0
const SHIVER := 4.0
const SHIVER_TIME := 0.24
const DIP := 8.0
const DIP_TIME := 0.4
const PIP_AT := 0.35
const PIP_STAGGER := 0.09
const PIP_POP := 0.26
const SAY_AT := 0.45
const SLIDE_AT := 0.78
const SLIDE_TIME := 0.35
const PEEK_AT := 0.5
const PEEK_LIFT := 10.0
const PEEK_TIME := 0.5
const PEEK_STAGGER := 0.05
const REVEAL_WIN := 1.05
const REVEAL_LOST := 1.1
const LID_STAGGER := 0.12
const LID_TIME := 0.55
const LID_SLIDE := 170.0
const LID_FALL := 520.0
const CODE_POP_TIME := 0.4
const CODE_POP_WIN := 0.3
const CODE_POP_LOST := 0.25
const CODE_POP_STAGGER := 0.1
const RESET_STAGGER := 0.05
## How long the host waits before the win screen: the lids, the code's pop
## and its sparkles all land first.
const WIN_DELAY := 1.9
const WIN_DELAY_STILL := 0.3

var state = State.new()
var fx: Node2D

var length: int:
	get: return state.length
var palette_size: int:
	get: return state.palette_size
var max_guesses: int:
	get: return State.TRIES
## The win harness reads the code and the rows played off the board, exactly
## as it does on the island.
var _code: Array:
	get: return state.code
var _guesses: Array:
	get: return state.guesses

var _column: Control
var _code_label: Label
var _rule: Control
var _lid_seat: Array = []     # [s] -> Control at a code seat: the lid and the friend
var _lid: Array = []          # [s] -> the wooden lid
var _code_face: Array = []    # [s] -> the friend under it, hidden until revealed
var _rows: Array = []         # [g] -> the row's Control
var _row_card: Array = []
var _row_sb: Array = []       # [g] -> the card's StyleBoxFlat, blended by bigness
var _row_num: Array = []
var _row_ask: Array = []      # [g] -> the dim "?" a full unscored row shows
var _seat: Array = []         # [g][s] -> Control, scaled between compact and full
var _socket: Array = []       # [g][s] -> Panel
var _socket_sb: Array = []    # [g][s] -> its StyleBoxFlat
var _ring: Array = []         # [g][s] -> the dotted socket ring
var _face: Array = []         # [g][s] -> Face or null
var _pouch: Array = []        # [g] -> Pouch
var _big: Array = []          # [g] -> 0 compact, 1 full size
var _seat_tw: Array = []      # [g][s]
var _row_tw: Array = []       # [g]
var _flash_tw: Dictionary = {}  # g * 16 + s -> a socket's flash
var _press_tw: Tween
var _touch_seat := -1
var _sparks: Control
var _slide_tw: Tween
var _entrance: Array = []
## Bumped by every rebuild, so a callback waiting on a timer from the board
## before it quietly does nothing.
var _gen := 0

var _piece_big := PIECE_MAX
var _piece_small := PIECE_MAX * PIECE_SMALL
var _need := 0.0
var _scale := 1.0
var _tip := ""
var _tip_mood := Face.Expr.HAPPY
## Set while a check is playing out, so a tap cannot land mid-score.
var _busy := false

## Every mesh of dashes built so far, keyed by its shape. A dotted ring is
## a dozen draw commands and the rule under the code is fifty, and
## gl_compatibility pays per command (see CLAUDE.md).
static var _dash_cache: Dictionary = {}

func puzzle_id() -> String: return "mastermind"
func title() -> String: return "Code Break"

func rules() -> String:
	var count := "five" if length == 5 else "four"
	return "Crack the hidden row of %s friends. Tap a friend to seat them, and Check scores the row: a filled pip is a friend in the right seat, a hollow ring a right friend in the wrong seat. Neither says which seat. Eight rows, three hints." % count

func capabilities() -> Array[String]:
	return ["undo", "hint", "check", "palette"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_column = Control.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	fx = Fx2D.new()
	fx.z_index = 2
	add_child(fx)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	state.setup(rng, difficulty)
	_busy = false
	_tip = ""
	_say("Tap a friend to seat them. Check scores the row.", Face.Expr.HAPPY)
	_build_column()
	_layout()
	_refresh_seats()
	_enter()

# --- the column ---

func _build_column() -> void:
	_stop_all()
	for child in _column.get_children():
		child.queue_free()
	_lid_seat = []
	_lid = []
	_code_face = []
	_rows = []
	_row_card = []
	_row_sb = []
	_row_num = []
	_row_ask = []
	_seat = []
	_socket = []
	_socket_sb = []
	_ring = []
	_face = []
	_pouch = []
	_big = []
	_seat_tw = []
	_row_tw = []

	_code_label = Label.new()
	_code_label.text = "THE CODE"
	_code_label.theme_type_variation = "FlatMotto"
	_code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_code_label)
	_rule = Dashed.new()
	_column.add_child(_rule)
	_sparks = Sparks.new()
	_column.add_child(_sparks)

	for s in length:
		var seat := Control.new()
		seat.name = "CodeSeat_%d" % s
		seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_column.add_child(seat)
		_lid_seat.append(seat)
		var friend := Friends.make(s, PIECE_MAX, Vector2.ZERO)
		friend.visible = false
		seat.add_child(friend)
		_code_face.append(friend)
		var lid := Lid.new()
		seat.add_child(lid)
		_lid.append(lid)

	for g in State.TRIES:
		var row := Control.new()
		row.name = "Row_%d" % g
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_column.add_child(row)
		_rows.append(row)
		var card := Panel.new()
		var card_sb := CozyTheme.card(Pal.SURFACE, 28, Pal.LINE, 6, 0)
		card.add_theme_stylebox_override("panel", card_sb)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(card)
		_row_sb.append(card_sb)
		# The paper wash CozyTheme.dress() hands every Panel as it enters the
		# tree reads as a stain across a column of eight, exactly as it does
		# on the Binairo tiles. It has to be dropped after the add, which is
		# when dress() puts it on.
		card.material = null
		_row_card.append(card)
		var num := Label.new()
		num.text = str(g + 1)
		num.add_theme_font_override("font", CozyTheme.display(700))
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(num)
		_row_num.append(num)
		var seats := []
		var sockets := []
		var sbs := []
		var rings := []
		var faces := []
		var tws := []
		for s in length:
			var seat := Control.new()
			seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(seat)
			seats.append(seat)
			var sb := StyleBoxFlat.new()
			sb.border_width_bottom = 5
			var socket := Panel.new()
			socket.add_theme_stylebox_override("panel", sb)
			socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
			seat.add_child(socket)
			socket.material = null
			sockets.append(socket)
			sbs.append(sb)
			var ring := Dashed.new()
			seat.add_child(ring)
			rings.append(ring)
			faces.append(null)
			tws.append(null)
		_seat.append(seats)
		_socket.append(sockets)
		_socket_sb.append(sbs)
		_ring.append(rings)
		_face.append(faces)
		_seat_tw.append(tws)
		var pouch := Pouch.new()
		row.add_child(pouch)
		_pouch.append(pouch)
		# The dim "?" a full unscored row shows sits in its own pouch, where
		# the score is about to land.
		var ask := Label.new()
		ask.text = "?"
		ask.add_theme_font_override("font", CozyTheme.display(700))
		ask.add_theme_font_size_override("font_size", 46)
		ask.add_theme_color_override("font_color", Color(Pal.TEXT_DIM, 0.5))
		ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ask.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ask.visible = false
		ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pouch.add_child(ask)
		_row_ask.append(ask)
		_big.append(1.0 if g == 0 else 0.0)
		_row_tw.append(null)

## The column's own size, then one uniform scale to fit it in the card.
func _layout() -> void:
	if _rows.is_empty():
		return
	var pitch := (SEAT_R - SEAT_L) / length
	_piece_big = minf(PIECE_MAX, pitch - PIECE_SLACK)
	_piece_small = _piece_big * PIECE_SMALL
	_need = CODE_TOP + _piece_big + ROWS_AFTER + RH_SMALL * (State.TRIES - 1) + RH_BIG
	_scale = minf(size.x / COL_W, maxf(0.05, (size.y - 2.0 * PAD) / _need))
	_column.size = Vector2(COL_W, _need)
	_column.scale = Vector2.ONE * _scale
	_column.position = (size - Vector2(COL_W, _need) * _scale) * 0.5

	_code_label.position = Vector2(CARD_X, LABEL_Y - 20.0)
	_code_label.size = Vector2(400.0, 40.0)
	_rule.mesh = _dash_line(CARD_W, 6.0, 14.0, 4.0, Color(Pal.LINE, 0.7))
	_rule.position = Vector2(CARD_X, CODE_TOP + _piece_big + RULE_AFTER)
	_rule.size = Vector2(CARD_W, 1.0)
	_sparks.position = Vector2(0.0, CODE_TOP)
	_sparks.size = Vector2(COL_W, _piece_big)
	_sparks.left_x = _seat_x(0) - _piece_big * 0.5 - SPARK_GAP
	_sparks.right_x = _seat_x(length - 1) + _piece_big * 0.5 + SPARK_GAP
	_sparks.cy = _piece_big * 0.5
	_sparks.length = SPARK_LEN
	_sparks.queue_redraw()
	for s in length:
		var seat: Control = _lid_seat[s]
		seat.size = Vector2(_piece_big, _piece_big)
		seat.pivot_offset = seat.size * 0.5
		seat.position = _code_rest(s)
		_lid[s].fit(_piece_big)
		Friends.resize(_code_face[s], _piece_big, seat.size * 0.5)
	_place_rows()

func _code_rest(s: int) -> Vector2:
	return Vector2(_seat_x(s) - _piece_big * 0.5, CODE_TOP)

## Every row's y, from the running sum of the heights their bigness gives.
func _place_rows() -> void:
	var y := CODE_TOP + _piece_big + ROWS_AFTER
	for g in State.TRIES:
		var h := _row_h(g)
		var row: Control = _rows[g]
		row.position = Vector2(0.0, y)
		row.size = Vector2(COL_W, h)
		row.pivot_offset = row.size * 0.5
		_fit_row(g, h)
		y += h

func _row_h(g: int) -> float:
	return lerpf(RH_SMALL, RH_BIG, _big[g])

func _seat_x(s: int) -> float:
	return SEAT_L + (SEAT_R - SEAT_L) / length * (s + 0.5)

func _seat_rest(g: int, s: int) -> Vector2:
	return Vector2(_seat_x(s) - _piece_big * 0.5, _row_h(g) * 0.5 - _piece_big * 0.5)

## Lays out one row at its current height. Everything about it is a blend
## on its bigness, so a row sliding between the two sizes is dressed
## continuously: the card warms from the history's cream to white, the
## number darkens, the sockets and rings come up to full ink, and each seat
## -- socket, dotted ring and friend together -- scales between the compact
## size and the full one about its own centre.
func _fit_row(g: int, h: float) -> void:
	var b: float = _big[g]
	var cy := h * 0.5
	var card: Panel = _row_card[g]
	card.position = Vector2(CARD_X, 5.0)
	card.size = Vector2(CARD_W, maxf(1.0, h - 10.0))
	var card_sb: StyleBoxFlat = _row_sb[g]
	card_sb.bg_color = Pal.PARCHMENT.lerp(Pal.SURFACE, ROW_DIM).lerp(Pal.SURFACE, b)
	card_sb.border_color = Color(Pal.LINE, lerpf(0.45, 1.0, b))
	var num: Label = _row_num[g]
	num.add_theme_font_size_override("font_size", int(roundf(lerpf(30.0, 40.0, b))))
	num.add_theme_color_override("font_color", Color(Pal.TEXT_DIM, 0.75).lerp(Pal.TEXT, b))
	num.size = Vector2(80.0, 48.0)
	num.position = Vector2(NUM_X - 40.0, cy - 24.0)
	var k: float = lerpf(_piece_small, _piece_big, b) / _piece_big
	for s in length:
		var seat: Control = _seat[g][s]
		seat.size = Vector2(_piece_big, _piece_big)
		seat.pivot_offset = seat.size * 0.5
		# A flight, a drop or a nudge owns the seat's place and size while it
		# runs; the layout takes them back when it lands.
		if not Motion.running(_seat_tw[g][s]):
			seat.position = _seat_rest(g, s)
			seat.scale = Vector2.ONE * k
		var sb: StyleBoxFlat = _socket_sb[g][s]
		sb.set_corner_radius_all(int(_piece_big * 0.22))
		var socket: Panel = _socket[g][s]
		socket.position = Vector2.ZERO
		socket.size = seat.size
		socket.modulate.a = lerpf(SOCKET_DIM, 1.0, b)
		var ring: Control = _ring[g][s]
		ring.position = seat.size * 0.5
		ring.modulate.a = lerpf(RING_DIM, 1.0, b)
		ring.mesh = _dash_ring(_piece_big * 0.28, 10.0, 12.0, 5.0, Color(Pal.LINE, 0.8))
	_fit_faces(g)
	var pouch: Pouch = _pouch[g]
	pouch.size = POUCH
	pouch.pivot_offset = POUCH * 0.5
	pouch.position = Vector2(PIP_X - POUCH.x * 0.5, cy - POUCH.y * 0.5)
	pouch.modulate.a = 1.0 if pouch.scored else lerpf(POUCH_DIM, 1.0, b)

## A friend keeps the mesh it was built with -- its seat carries the row's
## scale -- so all a growing row changes is whether the faces are drawn, and
## whether they are alive.
func _fit_faces(g: int) -> void:
	var plain: bool = _big[g] <= FACES_ABOVE
	for s in length:
		var face: Control = _face[g][s]
		if face == null or face.plain == plain:
			continue
		face.plain = plain
		face.set_idle(not plain)

# --- what the state says is on the board ---

## Rebuilds every seat from the state. Cheap enough to call after any move:
## a seat whose friend has not changed keeps its node, so an idling face is
## never restarted under the player.
func _refresh_seats() -> void:
	for g in State.TRIES:
		for s in length:
			var want := -1
			if g < state.guesses.size():
				want = int(state.guesses[g][s])
			elif g == state.active() and state.open():
				# A finished game keeps its last row in `state.row`; only a
				# live board has a row in hand to draw.
				want = int(state.row[s])
			_set_friend(g, s, want)
		_paint_sockets(g)
		var pouch: Pouch = _pouch[g]
		if g < state.marks.size():
			var m: Dictionary = state.marks[g]
			pouch.set_score(int(m.exact), int(m.colour))
		_row_ask[g].visible = g == state.active() and state.open() and state.full()

## Seats friend `v` at (g, s), or clears the seat, with no motion of its
## own: the movers below make theirs and then call this.
func _set_friend(g: int, s: int, v: int) -> void:
	var face: Control = _face[g][s]
	var have: int = int(face.get_meta("friend")) if face != null else -1
	if have == v:
		return
	if face != null:
		face.queue_free()
		_face[g][s] = null
	if v < 0:
		return
	var plain: bool = _big[g] <= FACES_ABOVE
	face = Friends.make(v, _piece_big, Vector2(_piece_big, _piece_big) * 0.5, plain)
	face.set_meta("friend", v)
	_seat[g][s].add_child(face)
	_face[g][s] = face
	# Only a friend big enough to have a face has one to blink with.
	if not plain:
		face.set_idle(true)

## The socket's fill and rim: a seated friend reads warmer than an empty
## seat, a hinted seat takes a sun rim, and the dotted ring shows only where
## a seat is empty -- and pops back when a friend leaves.
func _paint_sockets(g: int) -> void:
	var active := g == state.active() and state.open()
	for s in length:
		var filled: bool = _face[g][s] != null
		var sb: StyleBoxFlat = _socket_sb[g][s]
		sb.bg_color = _socket_fill(filled)
		sb.border_color = Pal.SUN if active and state.locked[s] else Pal.LINE
		var ring: Control = _ring[g][s]
		if not filled and not ring.visible:
			ring.visible = true
			Motion.pop_in(ring, 0.18)
		elif filled:
			ring.visible = false

func _socket_fill(filled: bool) -> Color:
	return Pal.SURFACE_HI if filled else Pal.SURFACE_HI.lerp(Pal.PARCHMENT, 0.6)

# --- the moves ---

## A palette chip: the friend runs from it into the first free seat along a
## low arc. With the row full the seated friends nudge and nothing is placed.
func pick(i: int) -> bool:
	if _busy or not state.open():
		return false
	var g := state.active()
	var slot := state.place(i)
	if slot < 0:
		for s in length:
			if _face[g][s] != null and not Motion.running(_seat_tw[g][s]):
				Motion.hop(_seat[g][s], FULL_HOP, Motion.HOP_TIME, 0.0, _seat_rest(g, s).y)
		fx.cue("full")
		return false
	_refresh_seats()
	_fly(g, slot, i)
	_nudge_neighbours(g, slot)
	_say("Check when you are ready." if state.full() else "Tap a friend to seat them. Check scores the row.",
		Face.Expr.HAPPY)
	fx.cue("place")
	moved.emit()
	return true

## Where a friend runs in from. The chips span the same column the board
## does, so chip `i` stands at about this fraction across it: the run keeps
## the mock's sideways sweep without the board reaching into the host's tray
## for a rect.
func _chip_at(i: int) -> Vector2:
	return Vector2(COL_W * (i + 0.5) / palette_size, _need + 90.0)

## The friend runs in along a low arc, growing as they come, and lands with
## the vocabulary's squash and a puff of stars in their own colour.
func _fly(g: int, s: int, friend: int) -> void:
	var seat: Control = _seat[g][s]
	var rest := _seat_rest(g, s)
	var k: float = lerpf(_piece_small, _piece_big, _big[g]) / _piece_big
	Motion.stop(_seat_tw[g][s])
	Motion.stop(_press_tw)
	if Motion.reduce:
		seat.position = rest
		seat.scale = Vector2.ONE * k
		return
	var row: Control = _rows[g]
	var from: Vector2 = _chip_at(friend) - row.position - Vector2(_piece_big, _piece_big) * 0.5
	var step := func(u: float) -> void:
		var e := _back_out(u)
		seat.position = from.lerp(rest, e) - Vector2(0.0, FLY_ARC * sin(PI * u))
		seat.scale = Vector2.ONE * k * lerpf(FLY_FROM, 1.0, e)
	var land := func() -> void:
		seat.position = rest
		seat.scale = Vector2.ONE * k
		fx.puff(cell_to_local(g, s), Friends.colour(friend), 5)
		_seat_tw[g][s] = Motion.squash(seat, LAND_SQUASH)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, FLY_TIME)
	tw.tween_callback(land)
	_seat_tw[g][s] = tw

## The seats either side lean away from the landing and come back.
func _nudge_neighbours(g: int, s: int) -> void:
	if Motion.reduce:
		return
	for d: int in [-1, 1]:
		var j := s + d
		if j < 0 or j >= length or Motion.running(_seat_tw[g][j]):
			continue
		_seat_tw[g][j] = Motion.nudge(_seat[g][j], Vector2(d, 0.0), _seat_rest(g, j), NUDGE, Motion.NUDGE_TIME, NUDGE_AFTER)

## A tap on a seated friend sends them back: they hop, turn a quarter and
## shrink out, and the socket's dotted ring comes back under them. A hinted
## friend only shivers; the hint owns that seat.
func _send_back(s: int) -> void:
	var g := state.active()
	if state.locked[s] and state.row[s] != -1:
		_shiver(g, s)
		_say("A hinted friend stays where the hint put them.", Face.Expr.WORRIED)
		fx.cue("locked")
		return
	if state.pop(s) < 0:
		return
	_leave(g, s)
	_refresh_seats()
	_say("Tap a friend to seat them. Check scores the row.", Face.Expr.HAPPY)
	fx.cue("clear")
	moved.emit()

func _shiver(g: int, s: int) -> void:
	if Motion.reduce:
		return
	var seat: Control = _seat[g][s]
	var rest := _seat_rest(g, s)
	Motion.stop(_seat_tw[g][s])
	var step := func(u: float) -> void:
		seat.position = rest + Vector2(SHIVER * sin(5.0 * PI * u) * (1.0 - u), 0.0)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, SHIVER_TIME)
	tw.tween_callback(func() -> void: seat.position = rest)
	_seat_tw[g][s] = tw

## The friend that just left seat (g, s) plays out its exit as an orphan over
## the row, so the seat below is free at once and a place that follows never
## fights it.
func _leave(g: int, s: int) -> void:
	var face: Control = _face[g][s]
	if face == null:
		return
	_face[g][s] = null
	var seat: Control = _seat[g][s]
	var k: float = seat.scale.x
	face.set_idle(false)
	seat.remove_child(face)
	_rows[g].add_child(face)
	face.position = seat.position + face.position * k
	face.scale = Vector2.ONE * k
	var out: Tween = Motion.pop_out(face, Motion.POP_OUT, 0.0, OUT_LIFT * k)
	if out == null:
		face.queue_free()
	else:
		out.finished.connect(face.queue_free)

# --- the HUD's actions ---

func can_undo() -> bool:
	return not _busy and state.can_undo()

func undo() -> bool:
	if _busy:
		return false
	var got: Dictionary = state.undo()
	if got.is_empty():
		return false
	var g := state.active()
	var s: int = int(got.slot)
	if int(got.colour) == -1:
		_leave(g, s)
		_refresh_seats()
	else:
		_refresh_seats()
		_fly(g, s, int(got.colour))
	_say("Tap a friend to seat them. Check scores the row.", Face.Expr.HAPPY)
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return state.hints_left()

## The code's own friend drops into the leftmost seat no hint has claimed, a
## ring pulses out of it and sparkles rise; the seat takes the sun rim and a
## tap will not send them back. Costs no move.
func hint() -> bool:
	if _busy:
		return false
	var g := state.active()
	var slot := state.hint()
	if slot < 0:
		return false
	hints_used = state.hints_used
	_leave(g, slot)
	_refresh_seats()
	var face: Control = _face[g][slot]
	if face != null:
		Motion.drop_in(face)
	var at := cell_to_local(g, slot)
	fx.ring(at, _piece_big * 0.55 * _scale)
	for k in 4:
		fx.sparkle(at + Vector2((randf() - 0.5) * 90.0 * _scale, 0.0), Pal.SUN)
	_say("Check when you are ready." if state.full() else "This one sits here. That seat is settled.",
		Face.Expr.HAPPY)
	fx.cue("hint")
	moved.emit()
	return true

## Check plays the row. An incomplete row only wobbles its empty seats and
## scores nothing; a full one is scored, the pips drop into the pouch, and
## the board either ends or slides the next row up to full size.
func check() -> int:
	if _busy or not state.open():
		return -1
	var g := state.active()
	checks += 1
	if not state.full():
		for s in length:
			if state.row[s] == -1:
				Motion.wobble2d(_seat[g][s])
				_flash_socket(g, s)
		_say("Every seat needs a friend before a Check can score.", Face.Expr.WORRIED)
		fx.cue("check")
		return -1
	var m: Dictionary = state.commit()
	if m.is_empty():
		return -1
	_busy = true
	_refresh_seats()
	_dip(g)
	_pouch[g].reveal_from(PIP_AT)
	var exact := int(m.exact)
	var colour := int(m.colour)
	var cracked := exact == length
	var over: bool = cracked or state.lost
	if exact >= 2 and not over:
		_peek()
	_after(_beat(SAY_AT), func() -> void:
		_say(_sentence(exact, colour), Face.Expr.WORRIED if exact + colour == 0 else Face.Expr.HAPPY))
	if over:
		_after(_beat(REVEAL_WIN if cracked else REVEAL_LOST), _reveal.bind(cracked))
	else:
		_after(_beat(SLIDE_AT), func() -> void:
			_busy = false
			_slide(g))
	fx.cue("score")
	# note_move ends the game when the code was cracked; _on_solved and
	# _reveal do the rest.
	note_move()
	return length - exact

## An empty seat asked to score blushes toward the bad tile and back, the
## way a Binairo cell that fails a check does.
func _flash_socket(g: int, s: int) -> void:
	var sb: StyleBoxFlat = _socket_sb[g][s]
	var base := _socket_fill(false)
	var setter := func(v: float) -> void: sb.bg_color = base.lerp(Pal.BAD_TILE, v)
	var key := g * 16 + s
	Motion.stop(_flash_tw.get(key))
	var tw: Tween = Motion.flash(self, setter, 0.0, 1.0, 0.0)
	if tw != null:
		_flash_tw[key] = tw

## A check's beats are paced to the pips dropping in; under reduce-motion
## the pips are simply there, so every beat shortens to one short one, and
## the code is on the table before the host's win screen (WIN_DELAY_STILL).
func _beat(t: float) -> float:
	return minf(t, Motion.REDUCED_TIME) if Motion.reduce else t

## The row dips under the weight of its own score and comes back.
func _dip(g: int) -> void:
	if Motion.reduce:
		return
	var row: Control = _rows[g]
	var rest := row.position.y
	Motion.stop(_row_tw[g])
	var step := func(u: float) -> void:
		row.position.y = rest + DIP * sin(PI * u)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, DIP_TIME)
	_row_tw[g] = tw

## Two or more in place and the code stirs under its lids, and the sparks
## beside it flash.
func _peek() -> void:
	if Motion.reduce:
		return
	_sparks.flash(PEEK_AT)
	for s in length:
		var seat: Control = _lid_seat[s]
		var rest := _code_rest(s)
		var step := func(u: float) -> void:
			seat.position = rest - Vector2(0.0, PEEK_LIFT * sin(PI * u))
		var tw := create_tween()
		tw.tween_interval(PEEK_AT + s * PEEK_STAGGER)
		tw.tween_method(step, 0.0, 1.0, PEEK_TIME)
		tw.tween_callback(func() -> void: seat.position = rest)

## The played row shrinks while the next grows by exactly as much over the
## same ease, so the column's height never changes and the rows between them
## simply slide. This walk down the board is the progress bar.
func _slide(g: int) -> void:
	Motion.stop(_slide_tw)
	var from_a: float = _big[g]
	var from_b: float = _big[g + 1] if g + 1 < State.TRIES else 0.0
	var apply := func(u: float) -> void:
		_big[g] = lerpf(from_a, 0.0, u)
		if g + 1 < State.TRIES:
			_big[g + 1] = lerpf(from_b, 1.0, u)
		_place_rows()
	if Motion.reduce:
		apply.call(1.0)
		_refresh_seats()
		focus_changed.emit()
		return
	_slide_tw = create_tween()
	_slide_tw.tween_method(apply, 0.0, 1.0, SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slide_tw.tween_callback(func() -> void:
		_refresh_seats()
		focus_changed.emit())

## The lids slide off to the right and fall away, and the code stands up
## underneath: beaming with sparkles when a row cracked it, plainly and
## without the pop when the eight rows ran out.
func _reveal(won: bool) -> void:
	_busy = false
	_sparks.flash(0.0, 1.6 if won else 1.0)
	for s in length:
		_lid_away(s, s * LID_STAGGER)
		var seat: Control = _lid_seat[s]
		_code_face[s].queue_free()
		var friend := Friends.make(state.code[s], _piece_big, seat.size * 0.5)
		friend.expression = Face.Expr.JOY if won else Face.Expr.HAPPY
		friend.visible = false
		seat.add_child(friend)
		_code_face[s] = friend
		_pop_code(s, (CODE_POP_WIN if won else CODE_POP_LOST) + s * CODE_POP_STAGGER)
	if won:
		for s in length:
			var at := _column.position + (_code_rest(s) + Vector2(_piece_big, _piece_big) * 0.5) * _scale
			for q in 3:
				_after(0.25 + s * 0.1 + q * 0.07, func() -> void:
					fx.sparkle(at + Vector2((randf() - 0.5) * 100.0 * _scale, 0.0), Pal.SUN))
		_say("Cracked it. Lovely reading of the pips.", Face.Expr.JOY)
	else:
		# Out of tries ends the day: the board goes quiet under the answer,
		# and the HUD reads it as done, so nothing stays live to press.
		_done = true
		_running = false
		_refresh_seats()
		_say("Here it was. Come back tomorrow.", Face.Expr.WORRIED)
	focus_changed.emit()
	fx.cue("reveal")

func _lid_away(s: int, delay: float) -> void:
	var lid: Control = _lid[s]
	if Motion.reduce:
		lid.visible = false
		return
	var from := lid.position
	var step := func(u: float) -> void:
		if not is_instance_valid(lid):
			return
		var fall: float = maxf(0.0, u - 0.3) / 0.7
		lid.position = from + Vector2(LID_SLIDE * _sine_io(minf(1.0, u / 0.45)), LID_FALL * fall * fall)
		lid.rotation = 1.6 * fall
		lid.modulate.a = 1.0 - clampf((u - 0.7) / 0.3, 0.0, 1.0)
	var tw := lid.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(step, 0.0, 1.0, LID_TIME)
	tw.tween_callback(func() -> void: lid.visible = false)

func _pop_code(s: int, delay: float) -> void:
	var face: Control = _code_face[s]
	if Motion.reduce:
		face.visible = true
		face.set_idle(true)
		return
	face.scale = Vector2.ZERO
	var step := func(u: float) -> void:
		if not is_instance_valid(face):
			return
		face.visible = true
		var e := _back_out(u)
		face.scale = Vector2(e * (1.0 + 0.12 * (1.0 - u)), e * (1.0 - 0.12 * (1.0 - u)))
	var tw := face.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(step, 0.0, 1.0, CODE_POP_TIME)
	tw.tween_callback(func() -> void:
		face.scale = Vector2.ONE
		face.set_idle(true))

## Reset clears the whole board, as the island's does and every other
## board's: the friends shrink out in a wave from the last row back, the
## pouches empty and the lids drop home. Hints already spent stay spent.
func reset_board() -> void:
	_stop_all()
	_busy = false
	state.reset()
	_done = false
	_running = true
	moves = 0
	var k := 0
	for g in range(State.TRIES - 1, -1, -1):
		for s in range(length - 1, -1, -1):
			if _face[g][s] == null:
				continue
			_leave_after(g, s, Motion.stagger(k, RESET_STAGGER))
			k += 1
	for s in length:
		var lid: Control = _lid[s]
		lid.visible = true
		lid.rotation = 0.0
		lid.modulate.a = 1.0
		lid.position = Vector2.ZERO
		_code_face[s].visible = false
		_code_face[s].set_idle(false)
		_lid_seat[s].position = _code_rest(s)
	for g in State.TRIES:
		_big[g] = 1.0 if g == 0 else 0.0
		_pouch[g].clear()
	_place_rows()
	_refresh_seats()
	_say("Cleared. Back to row one.", Face.Expr.HAPPY)
	fx.cue("reset")

func _leave_after(g: int, s: int, delay: float) -> void:
	if delay <= 0.0 or Motion.reduce:
		_leave(g, s)
		return
	_after(delay, func() -> void:
		if _face[g][s] != null:
			_leave(g, s))

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

## The Check pill keeps its word: a lost day stays lost, and a fresh code
## comes from the settings sheet's New puzzle, as on every other board.
func check_label() -> String:
	return "Check"

# --- what the flat chrome reads ---

## The palette's chips. `friend` is the index every drawing goes through;
## `colour` and `mark` keep the island tray's contract for anything that
## still reads it.
func palette() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var live: bool = state.open() and not _busy and not state.full()
	for i in palette_size:
		out.append({"friend": i, "colour": Friends.colour(i), "mark": i + 1, "enabled": live})
	return out

## The sprout's one line, and how it should look saying it.
func tip_line() -> Dictionary:
	return {"text": _tip, "mood": _tip_mood}

## The win screen's cast: the friends of the cracked code at illustration
## size, so the answer walks up out of the board. It is both the celebration
## and the answer, which is why Code Break shows four where Binairo shows two.
func flat_win() -> Dictionary:
	var faces: Array[Control] = []
	for s in length:
		faces.append(Friends.make(state.code[s], PIECE_MAX, Vector2.ZERO))
	return {"faces": faces, "subtitle": "Cracked it!"}

## How long the host waits before the win screen: the lids, the code's pop
## and its sparkles all have to land first.
func win_delay() -> float:
	return WIN_DELAY_STILL if Motion.reduce else WIN_DELAY

## Control-local point over the centre of seat (g, s). The win harness checks
## with this that the whole column lands inside the card.
func cell_to_local(g: int, s: int) -> Vector2:
	if g >= _rows.size() or s >= length:
		return Vector2.ZERO
	return _column.position + (_rows[g].position + _seat_rest(g, s) + Vector2(_piece_big, _piece_big) * 0.5) * _scale

func _say(text: String, mood: int) -> void:
	if _tip == text and _tip_mood == mood:
		return
	_tip = text
	_tip_mood = mood
	focus_changed.emit()

const WORD := ["none", "One", "Two", "Three", "Four", "Five"]

## The score read out in words. The pips are the record and this is the
## teaching -- and like the pips it never names a seat.
func _sentence(exact: int, colour: int) -> String:
	if exact == length:
		return "Cracked it!"
	var count := "five" if length == 5 else "four"
	if exact == 0 and colour == 0:
		return "Not one of those %s is in the code." % count
	if exact == 0:
		if colour == 1:
			return "One right friend, in the wrong seat."
		return "%s right friends, every one in the wrong seat." % WORD[colour]
	var said: String = "%s sat in the right seat" % WORD[exact]
	if colour == 0:
		return said + ". The rest are not in the code."
	return "%s, and %s more %s somewhere else." % [said, WORD[colour].to_lower(), "belongs" if colour == 1 else "belong"]

# --- entrance and housekeeping ---

## The board arrives the way a Binairo grid does: the rows pop in from the
## top down (a wide thing, so from ENTER_WIDE_FROM rather than nothing), the
## lids land last with the squash, a beat apart, and the sparks come up
## after them.
func _enter() -> void:
	_stop_entrance()
	for g in State.TRIES:
		var at := ENTER_ROW + Motion.stagger(g, Motion.ENTER_STAGGER)
		var pop: Tween = Motion.slide(_rows[g], "scale", Vector2.ONE * Motion.ENTER_WIDE_FROM, Vector2.ONE, Motion.ENTER_POP, at)
		if pop != null:
			_entrance.append(pop)
		var fade: Tween = Motion.appear(_rows[g], 0.0, 1.0, ENTER_ROW_FADE, at)
		if fade != null:
			_entrance.append(fade)
	for s in length:
		var at := ENTER_LID + s * ENTER_LID_STAGGER
		var pop: Tween = Motion.pop_in(_lid_seat[s], ENTER_LID_TIME, at)
		if pop != null:
			_entrance.append(pop)
		var fade: Tween = Motion.appear(_lid_seat[s], 0.0, 1.0, ENTER_LID_TIME, at)
		if fade != null:
			_entrance.append(fade)
	var sparks: Tween = Motion.appear(_sparks, 0.0, 1.0, ENTER_ROW_FADE, ENTER_SPARKS)
	if sparks != null:
		_entrance.append(sparks)
	fx.cue("enter")

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for row in _rows:
		row.scale = Vector2.ONE
		row.modulate.a = 1.0
	for seat in _lid_seat:
		seat.scale = Vector2.ONE
		seat.modulate.a = 1.0
	if _sparks != null:
		_sparks.modulate.a = 1.0

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a flight aimed at a seat that is
## about to go.
func _stop_all() -> void:
	_gen += 1
	_stop_entrance()
	Motion.stop(_slide_tw)
	Motion.stop(_press_tw)
	_touch_seat = -1
	for row in _seat_tw:
		for tw in row:
			Motion.stop(tw)
	for tw in _row_tw:
		Motion.stop(tw)
	for tw in _flash_tw.values():
		Motion.stop(tw)
	_flash_tw = {}

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	var gen := _gen
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

## The row that cracked the code hops in a wave and beams, the flat
## vocabulary's solve; the host brings the win screen in after the reveal
## (win_delay).
func _on_solved() -> void:
	var g: int = state.guesses.size() - 1
	if g < 0:
		return
	for s in length:
		var face: Control = _face[g][s]
		if face != null:
			face.expression = Face.Expr.JOY
		Motion.stop(_seat_tw[g][s])
		_seat_tw[g][s] = Motion.hop(_seat[g][s], Motion.SOLVE_HOP, Motion.SOLVE_TIME,
			Motion.SOLVE_DELAY + Motion.stagger(s, Motion.SOLVE_STAGGER), _seat_rest(g, s).y)
	fx.cue("solved")

# --- input ---

## Touch events only, as the flat Binairo takes them: the viewport hands a
## Control both the mouse event and the emulated touch, and two would fire
## twice. Only the active row's seats answer; the history and the code are a
## record, not a keyboard.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	if event.pressed:
		if _busy or not state.open():
			return
		var s := _seat_at(event.position)
		if s < 0:
			return
		# The seat sinks under the finger, as a Binairo tile does.
		_touch_seat = s
		Motion.stop(_press_tw)
		_press_tw = Motion.press(_seat[state.active()][s], true)
		return
	if _touch_seat < 0:
		return
	var was := _touch_seat
	_touch_seat = -1
	var g := state.active()
	if state.open() and not Motion.running(_seat_tw[g][was]):
		Motion.stop(_press_tw)
		_press_tw = Motion.press(_seat[g][was], false)
	if _busy or not state.open():
		return
	if _seat_at(event.position) == was:
		_send_back(was)

## The active row's seat under a board-local point, or -1.
func _seat_at(local: Vector2) -> int:
	var g := state.active()
	if g >= _rows.size():
		return -1
	var row: Control = _rows[g]
	var p: Vector2 = (local - _column.position) / _scale - row.position
	for s in length:
		if Rect2(_seat_rest(g, s), Vector2(_piece_big, _piece_big)).has_point(p):
			return s
	return -1

# --- small maths and the drawn pieces ---

static func _back_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 + 2.70158 * pow(u - 1.0, 3.0) + 1.70158 * pow(u - 1.0, 2.0)

static func _sine_io(u: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(u, 0.0, 1.0))

## A run of dashes along the x axis as one mesh.
static func _dash_line(w: float, dash: float, gap: float, width: float, colour: Color) -> ArrayMesh:
	var key := "line|%d|%d|%d|%d|%s" % [int(w), int(dash), int(gap), int(width), colour.to_html()]
	if _dash_cache.has(key):
		return _dash_cache[key]
	var b := Face.Builder.new()
	var x := 0.0
	while x < w:
		b.stroke(PackedVector2Array([Vector2(x, 0.0), Vector2(minf(x + dash, w), 0.0)]), width, colour, false, false)
		x += dash + gap
	var mesh := b.mesh()
	_dash_cache[key] = mesh
	return mesh

## A dashed circle about the origin as one mesh.
static func _dash_ring(r: float, dash: float, gap: float, width: float, colour: Color) -> ArrayMesh:
	var key := "ring|%d|%d|%d|%d|%s" % [int(r), int(dash), int(gap), int(width), colour.to_html()]
	if _dash_cache.has(key):
		return _dash_cache[key]
	var b := Face.Builder.new()
	var n := maxi(4, int(roundf(TAU * r / (dash + gap))))
	for i in n:
		var a := TAU * i / n
		b.stroke(Face.Builder.arc_points(Vector2.ZERO, r, a, a + dash / r), width, colour, false, false)
	var mesh := b.mesh()
	_dash_cache[key] = mesh
	return mesh

## A run of dashes, drawn as one command.
class Dashed extends Control:
	var mesh: ArrayMesh:
		set(v):
			mesh = v
			queue_redraw()

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, null)

## The two amber sparks flanking the lids: at each side, two short strokes
## fanning away from the code, as the re-render draws them. One mesh, drawn
## twice, the second mirrored. `flash()` swells and brightens them for a
## moment when the code stirs under its lids or comes out.
class Sparks extends Control:
	var left_x := 0.0
	var right_x := 0.0
	var cy := 0.0
	var length := 26.0:
		set(v):
			length = v
			_mesh = null
	var glow := 0.0:
		set(v):
			glow = v
			queue_redraw()
	var _mesh: ArrayMesh
	var _tw: Tween

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	## Swells to `peak` and settles back after `delay`.
	func flash(delay := 0.0, peak := 1.0) -> void:
		Motion.stop(_tw)
		if Motion.reduce:
			return
		_tw = create_tween()
		_tw.tween_interval(delay)
		_tw.tween_property(self, "glow", peak, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "glow", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _draw() -> void:
		if _mesh == null:
			# Two loose dashes, not a chevron: a short one high and tilted up,
			# a longer one low and nearly level, the way a shine is drawn.
			var b := Face.Builder.new()
			for d: Array in [[Vector2(0.55, -0.55), -0.6, 0.8], [Vector2(0.6, 0.28), 0.12, 1.1]]:
				var centre: Vector2 = d[0] * length
				var angle: float = d[1]
				var half: float = length * float(d[2]) * 0.5
				var dir := Vector2(cos(angle), sin(angle)) * half
				b.stroke(PackedVector2Array([centre - dir, centre + dir]), 7.0, Pal.SUN, false, true)
			_mesh = b.mesh()
		var k := 1.0 + 0.35 * glow
		var tint := Color(1.0, 1.0, 1.0, 0.85 + 0.15 * minf(glow, 1.0))
		draw_mesh(_mesh, null, Transform2D(0.0, Vector2(k, k), 0.0, Vector2(right_x, cy)), tint)
		draw_mesh(_mesh, null, Transform2D(0.0, Vector2(-k, k), 0.0, Vector2(left_x, cy)), tint)

## A wooden lid over one seat of the code: a plank with a screw and a carved
## question mark. It slides off to the right and falls away when the game
## ends.
class Lid extends Panel:
	var _mark: Label
	var _screw: Control

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		material = null
		_screw = Control.new()
		_screw.mouse_filter = MOUSE_FILTER_IGNORE
		_screw.draw.connect(func() -> void:
			_screw.draw_circle(_screw.size * 0.5, _screw.size.x * 0.5, Color(Pal.WOOD_DEEP, 0.55)))
		add_child(_screw)
		_mark = Label.new()
		_mark.text = "?"
		_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_mark.add_theme_font_override("font", CozyTheme.display(700))
		_mark.add_theme_color_override("font_color", Color(Pal.WOOD_DEEP, 0.85))
		_mark.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_mark)

	## Sizes the lid and everything on it to a `px`-square seat.
	func fit(px: float) -> void:
		size = Vector2(px, px)
		pivot_offset = size * 0.5
		add_theme_stylebox_override("panel", CozyTheme.card(Pal.WOOD, int(px * 0.22), Pal.WOOD_DEEP, 7, 0))
		var r := px * 0.045
		_screw.size = Vector2(r * 2.0, r * 2.0)
		_screw.position = Vector2(px * 0.5 - r, px * 0.22 - r)
		_screw.queue_redraw()
		_mark.size = size
		_mark.add_theme_font_size_override("font_size", int(px * 0.44))

## The pouch at the right of a played row: a filled slate pip for every
## friend in the right seat and a hollow ring for every right friend in the
## wrong seat, piled loose in two bands and jittered. **No pip carries a
## friend's colour and no socket is left for a miss**: a register of four
## sitting at the end of a row of four seats is exactly the thing an eye
## lays one over the other, and a filled first slot then reads as "seat one
## is right", which it never is. A row that scored nothing shows a dash,
## because that is a count too.
class Pouch extends Panel:
	var exact := 0
	var colours := 0
	## Whether a score has landed here; before one the pouch is an empty pill
	## waiting at the row's right, and draws nothing.
	var scored := false
	## 0 to 1 across the whole drop; each pip reads its own slice of it.
	var reveal := 1.0:
		set(v):
			reveal = v
			queue_redraw()
	var _tw: Tween

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		material = null
		add_theme_stylebox_override("panel", CozyTheme.card(
			Pal.PARCHMENT.lerp(Pal.SURFACE, 0.5), int(POUCH.y * 0.5), Color(Pal.LINE, 0.5), 5, 0))

	func set_score(ex: int, co: int) -> void:
		if scored and exact == ex and colours == co:
			return
		scored = true
		exact = ex
		colours = co
		queue_redraw()

	func clear() -> void:
		Motion.stop(_tw)
		scored = false
		exact = 0
		colours = 0
		reveal = 1.0
		queue_redraw()

	## The pips drop in one per PIP_STAGGER after `delay`, filled ones before
	## the rings, in the pile's own order and never the seats'; the pouch
	## gives a beat as the first lands.
	func reveal_from(delay: float) -> void:
		Motion.stop(_tw)
		if Motion.reduce:
			reveal = 1.0
			return
		reveal = 0.0
		_tw = create_tween()
		_tw.tween_interval(delay)
		_tw.tween_property(self, "reveal", 1.0, _span())
		Motion.bump(self, 0.12, 0.24, delay)

	func _span() -> float:
		return maxi(1, exact + colours) * PIP_STAGGER + PIP_POP

	func _draw() -> void:
		if not scored:
			return
		var n := exact + colours
		var clock := reveal * _span()
		if n == 0:
			if clock >= PIP_POP:
				var y := size.y * 0.5 - 3.0
				draw_line(Vector2(size.x * 0.5 - 17.0, y), Vector2(size.x * 0.5 + 17.0, y),
					Color(Pal.TEXT_DIM, 0.75), 5.0, true)
			return
		# Two bands from two pips up, so the pouch is always a pile and never
		# a line lying parallel to the seats.
		var bands := [n] if n <= 1 else [int(ceil(n / 2.0)), int(floor(n / 2.0))]
		var idx := 0
		for bi in bands.size():
			var c: int = bands[bi]
			var by: float = size.y * 0.5 - 3.0 + (0.0 if bands.size() == 1 else (bi - 0.5) * PIP_STEP * 0.94)
			for q in c:
				var jx := (_hash(idx * 17 + q, idx * 5 + 3) - 0.5) * PIP_JITTER
				var jy := (_hash(idx * 11 + 2, q * 7 + 1) - 0.5) * PIP_JITTER
				var at := Vector2(size.x * 0.5 + (q - (c - 1) * 0.5) * PIP_STEP + jx, by + jy)
				var u := clampf((clock - idx * PIP_STAGGER) / PIP_POP, 0.0, 1.0)
				var filled := idx < exact
				idx += 1
				if u <= 0.0:
					continue
				var r: float = PIP_R * _back_out(u)
				if filled:
					draw_circle(at, r, Color(Pal.TEXT, 0.88))
				else:
					draw_circle(at, r, Pal.SURFACE)
					draw_arc(at, r, 0.0, TAU, 24, Color(Pal.TEXT_DIM, 0.9), 5.0, true)

	static func _back_out(u: float) -> float:
		u = clampf(u, 0.0, 1.0)
		return 1.0 + 2.70158 * pow(u - 1.0, 3.0) + 1.70158 * pow(u - 1.0, 2.0)

	## A fixed pseudo-random number per pip, so a pouch's pile never shifts.
	static func _hash(a: int, b: int) -> float:
		return float(posmod(hash(Vector2i(a, b)), 1000)) / 1000.0
