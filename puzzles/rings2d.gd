extends "res://core/puzzle_base.gd"

## Rings as a flat board: pegs standing on two wooden shelves, rings dealt
## over them, and a pale post standing proud of every stack. Lift the top
## ring off a peg and set it down on an empty peg or on a ring of its own
## colour; the rules live in puzzles/rings_state.gd and the deal and its
## proof in puzzles/rings_gen.gd, which this only draws.
##
## **A ring is a donut seen from a little above** (2026-09-25 polish, after
## the user's reference, docs/art/concept-rings-ref.png): a band, a lighter
## top face and a dark hole, and the post goes *into* the top ring's hole
## rather than standing behind a pill. The ring above covers the one below
## down past its hole, so only a lip of each lower top face shows, the seam
## the reference draws between its rings. The pips stay on the band, because
## colour never stands alone on this board (core/palette.gd's Code Break
## rule). Every proportion is a fraction of the ring's width (`_append_donut`,
## `_append_peg`), so the menu card draws the same peg at 41 px wide.
##
## **Every move goes through one door, _settle**, so the lock, the toast and
## the tip line are decided in exactly one place -- Queens' _settle with a
## peg in place of a queen's sight. A tap on a peg lifts an empty hand's top
## ring, puts a held one back where it came from, or drops it (_tap);
## _peg_at tests the whole station column plus the held ring's headroom.
##
## **The motion.** A lifted ring slides up its post, stretching, and pops
## clear to breathe over it. A drop flies (_fly, _pose): up off its post if
## it starts on one (an undo, a hint), over in an arc that leans into its
## travel, and then **threaded down the target post** -- the board's
## signature, the post drawn back over the ring while it slides so the ring
## is visibly on it. It lands with a squash and a small bump that runs down
## the stack under it. A refused drop dips the held ring toward the peg that
## refused it and shivers that peg. A peg that locks keeps its colours --
## a glint runs down the stack and a gold cap pops onto the post and stays,
## the lasting mark -- because a wash toward gold turned four pink rings
## orange, and on a board coloured by index no state may be a shade of the
## piece's own colour (Pinwheel's rule). A reset drops every peg back on
## `Motion.RESET_STAGGER`, and a solve hops every peg on `Motion.SOLVE_HOP`
## with a stretch in the rings.
##
## **Drawn in a design box and scaled to the card.** Everything below is laid
## out in design pixels (DESIGN_W wide, at least MIN_H tall) and drawn under
## one transform (`_s`), so the win screen, which shrinks the card, shrinks
## the board with it instead of spilling its second row over the stats.
## Spare height is shared between the air above, the gap between the rows
## and the grass band, so the two rows sit in the middle of the card.
##
## **Two meshes.** The stations, shelves and band are one mesh rebuilt only
## while something on them moves (`_stations_moving`); the ring in hand or in
## flight is its own small mesh rebuilt every frame it moves. Caterpillar's
## lesson: a board whose idle breath rebuilt its whole mesh paid for it every
## frame. Both are kept in `_shown` until the next ones replace them (a canvas
## command holds a mesh by RID).
##
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md (the 2026-09-25
## amendment is this drawing). `ui/menu/card_art.gd`'s "rings" branch calls
## `_append_peg` and `RING_COLOURS` on purpose: one ring shape, not two, so a
## change here is checked on `tests/_shot_menu.gd -- page2` too.

const State = preload("res://puzzles/rings_state.gd")
const Gen = preload("res://puzzles/rings_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const CozyTheme = preload("res://ui/theme.gd")

# --- the design box ---
## The card's width in design pixels; the board scales to whatever it gets.
const DESIGN_W := 1000.0
const INSET := 28.0
const STATION_W := 236.0
const RING_W := 184.0

# --- a peg's shape, every figure a fraction of the ring's width ---
## The band's height between the top face's centre and the bottom's.
const SIDE := 0.32
## The top face's half height: how far "from above" the ring is seen.
const FACE := 0.16
## One slot to the next. SIDE + FACE - PITCH is how far a ring covers the
## one under it past that one's face centre -- more than the hole's depth,
## so no lower hole ever shows.
const PITCH := 0.42
const HOLE_X := 0.11
const HOLE_Y := 0.035
const POST := 0.13
## How far the post stands proud of a **full** stack's top face: what tells
## a player at a glance that a peg has room.
const POST_UP := 0.35
const DISH_X := 0.57
const DISH_Y := 0.15
const DISH_T := 0.08
## Ground to the bottom ring's lower face centre: the ring sits in the dish.
const SEAT := 0.25
const CAP_R := 0.085
## Clear air between a held ring and the post top under it.
const HOVER := 0.09

# --- the layout, in design pixels ---
## Ground to post top of a station. The 3 is Gen.CAP - 1, written out
## because a const from another script's constant does not always fold in
## GDScript.
const STATION_H := (SEAT + 3.0 * PITCH + SIDE + POST_UP) * RING_W
## A held ring's room over its post, plus a little air.
const HEAD := (SIDE + 2.0 * FACE + HOVER) * RING_W + 16.0
## The shelf a row stands on, below its ground line.
const SHELF_H := 40.0
const MID_GAP := 96.0
const BAND_H := 96.0
const MIN_H := HEAD + 2.0 * STATION_H + 2.0 * SHELF_H + MID_GAP + BAND_H

# --- this board's own motion (everything else is a recipe off core/motion.gd) ---
## Up the post and clear of it, for a lift.
const RISE_TIME := 0.16
## Its idle breath while it waits to be put down, and how long a breath takes.
const BOB := 5.0
const BOB_CYCLE := 1.9
## The arc from one peg to the next, how high it arches and how far it leans.
const ARC_TIME := 0.26
const ARC_LIFT := 40.0
const TILT := 0.16
## Down the target post.
const THREAD_TIME := 0.15
## The landing's bump running down the stack, a ring a step.
const BUMP_STEP := 0.035
## How far a refused ring dips toward the peg that refused it.
const DIP := 18.0
## How long "Nothing can move" stays up.
const TOAST_HOLD := 2.6
## The customary win wait: every board that plays a solve wave keeps its own
## copy of this name and this number.
const WIN_WAIT := 1.4

## The card's own rounded rect radius (ui/flat/flat_host.gd's stylebox), so
## the band is clipped to it rather than showing square corners.
const CARD_RADIUS := 32.0

## The ring colours and the pip count each one wears. core/palette.gd says it
## about Code Break's pegs -- "every peg also carries a pip mark, so colour
## never stands alone" -- and a game whose whole mechanic is matching colour is
## the game that rule was written for.
const RING_COLOURS := [Pal.BERRY, Pal.SUN, Pal.MOON_INK, Pal.ACORN, Pal.FLOWER, Pal.ACCENT]

## One coloured square per ring colour, in RING_COLOURS' own order, for
## share_glyphs() -- the same language Word Trail's green squares speak.
const SHARE_GLYPHS := ["🟥", "🟨", "🟦", "🟫", "🟪", "🟩"]

const TIP_CYCLE := 8.0
const TIPS := [
	"RG_TIP_LIFT",
	"RG_TIP_LANDS",
	"RG_TIP_LOCKS",
	"RG_TIP_UNDO",
]

const STUCK_MSG := "RG_STUCK"
const OUT_MSG := "RG_OUT"
const BUDGET_FONT := 34
const BUDGET_DROP := 56.0

const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 66.0

var _state = State.new()

var _opened := 0.0
## Design pixels to the control's own: `_s` scale, and the design box's size.
var _s := 1.0
var _dsize := Vector2(DESIGN_W, MIN_H)
## The two rows' ground lines, set by _layout() and read by _station().
var _ground: Array[float] = [HEAD + STATION_H, HEAD + 2.0 * STATION_H + SHELF_H + MID_GAP]

## The stations, shelves and band, rebuilt only while they move.
var _mesh: ArrayMesh
## The ring in hand or in flight, rebuilt every frame it moves.
var _live_mesh: ArrayMesh
var _shown: Array = []

var _tip_timer: Timer
var _tip_idx := 0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY

var fx: Fx2D

## Peg index -> the second it locked, for the glint and the cap. Derived, not
## truth: cleared for a peg that is no longer locked on every _settle.
var _lock_at: Dictionary = {}
## Peg index -> the second a drop on it was last refused, for its shiver.
var _shake_at: Dictionary = {}
## The last refusal, for the held ring's dip toward the peg that refused it.
var _refuse_at := -100.0
var _refuse_to := -1
var _press_i := -1
var _toast := ""
var _toast_at := -100.0
var _reset_at := -100.0
var _held_at := -100.0
## The one ring in flight, or {} for none: "colour", "from"/"to" (pegs),
## "slot" (landing slot), "from_slot" (the slot it rises off, or -1 when it
## starts in the hand), "at", "dur" and "settle" (whether it calls _settle
## when it lands -- a drop or a hint does, an undo never can lock a peg).
var _flight: Dictionary = {}
var _land_peg := -1
var _land_slot := -1
var _land_at := -100.0
var _solved_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

func puzzle_id() -> String: return "rings"
func title() -> String: return "Rings"

func rules() -> String:
	var line := tr("RG_RULES")
	if _state.par > 0:
		line += " " + tr("RG_RULES_INSANE")
	return line

## No hint on Insane: the only solver cheap enough for the phone plays lines
## twice the budget, so a hint would spend moves the player cannot win back.
func capabilities() -> Array[String]:
	if _state.par > 0:
		return ["undo"]
	return ["undo", "hint"]

func can_undo() -> bool:
	return not _state.log.is_empty()

func hints_left() -> int:
	return State.HINTS - hints_used

func card_height(available: float) -> float:
	return available

## False: card_height() hands back everything, and _layout centres the rows.
func card_centred() -> bool:
	return false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	fx = Fx2D.new()
	add_child(fx)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.build(rng, difficulty, bank_step)
	_layout()
	_enter()
	_tip_idx = 0
	_tip_text = tr(TIPS[0])
	_tip_mood = Face.Expr.HAPPY
	_press_i = -1
	_shake_at = {}
	_refuse_at = -100.0
	_refuse_to = -1
	_toast = ""
	_toast_at = -100.0
	_reset_at = -100.0
	_lock_at = {}
	_held_at = -100.0
	_flight = {}
	_land_peg = -1
	_land_slot = -1
	_land_at = -100.0
	_solved_at = -100.0
	_tip_timer.start()

# --- layout ---

## Rows of four at the hard band, four and three at the medium one, three and
## three at the easy one.
static func _rows_of(peg_count: int) -> Array:
	if peg_count <= 6:
		return [int(ceil(peg_count / 2.0)), int(floor(peg_count / 2.0))]
	return [4, peg_count - 4]

## Fits the design box to the card: as wide as the card at DESIGN_W, and never
## shorter than MIN_H, whichever binds. What height is left over goes four
## tenths above the rows, three between them and three to the band, so the
## rows sit in the middle of the card rather than hanging from its top.
func _layout() -> void:
	if size.x > 0.0 and size.y > 0.0:
		_s = minf(size.x / DESIGN_W, size.y / MIN_H)
		_dsize = size / _s
	else:
		_s = 1.0
		_dsize = Vector2(DESIGN_W, MIN_H)
	var extra := maxf(_dsize.y - MIN_H, 0.0)
	var g0 := HEAD + extra * 0.4 + STATION_H
	var g1 := g0 + SHELF_H + MID_GAP + extra * 0.3 + STATION_H
	_ground = [g0, g1]
	_toast_mesh = null
	_toast_mesh_for = ""
	_refresh()

## Where peg `i` stands, in design pixels: a short row is centred.
func _station(i: int) -> Dictionary:
	var counts := _rows_of(_state.pegs.size())
	var a: int = counts[0]
	var row := 0 if i < a else 1
	var k := i if row == 0 else i - a
	var n := a if row == 0 else int(counts[1])
	var x := (_dsize.x - float(n) * STATION_W) * 0.5 + float(k) * STATION_W
	var ground: float = _ground[row]
	return {"row": row, "x": x, "cx": x + STATION_W * 0.5, "ground": ground,
		"top": _post_top(ground, RING_W)}

## A ring's top face centre in slot `k` of a peg standing on `ground`.
static func _ring_yt(ground: float, w: float, k: int) -> float:
	return ground - (SEAT + float(k) * PITCH + SIDE) * w

static func _post_top(ground: float, w: float) -> float:
	return _ring_yt(ground, w, Gen.CAP - 1) - POST_UP * w

## A ring in hand: its bottom clear of the post top by HOVER.
static func _held_yt(ground: float, w: float) -> float:
	return _post_top(ground, w) - (SIDE + FACE + HOVER) * w

func _loc(p: Vector2) -> Vector2:
	return p * _s

# --- input and the one door every move goes through ---

## The peg under design point `p`: the station's column from its held ring's
## headroom down through its shelf. The second row's headroom stops at the
## first row's shelf, so the two never overlap.
func _peg_at(p: Vector2) -> int:
	for i in _state.pegs.size():
		var st := _station(i)
		var x: float = st["x"]
		var ground: float = st["ground"]
		var top: float = float(st["top"]) - HEAD
		if int(st["row"]) == 1:
			top = maxf(top, float(_ground[0]) + SHELF_H)
		if p.x >= x and p.x <= x + STATION_W and p.y >= top and p.y <= ground + SHELF_H:
			return i
	return -1

## Touch only, as every flat board takes it: the viewport hands a control
## both the mouse event and the emulated touch, and two would fire twice.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		var p: Vector2 = event.position / _s
		if event.pressed:
			_press_i = _peg_at(p)
		else:
			var i := _press_i
			_press_i = -1
			if i >= 0 and i == _peg_at(p):
				_tap(i)

## The one tap gesture this board takes: lift an empty hand's ring off peg
## `i`, put a held ring back where it came from, or drop it on `i` -- the
## only place state.drop() is ever called.
func _tap(i: int) -> void:
	if is_done():
		return
	if _state.held == -1:
		if _state.out_of_moves():
			_toast = OUT_MSG
			_toast_at = _now()
			fx.cue("refused")
			_say(tr(OUT_MSG), Face.Expr.WORRIED)
		elif _state.lift(i):
			_held_at = _now()
			fx.cue("lift")
			_say(tr("RG_HELD"), Face.Expr.HAPPY)
		elif (_state.pegs[i] as Array).is_empty():
			_shake_at[i] = _now()
			fx.cue("refused")
			_say(tr("RG_EMPTY_PEG"), Face.Expr.HAPPY)
		else:
			_shake_at[i] = _now()
			fx.cue("refused")
			_say(tr("RG_HOME_PEG"), Face.Expr.HAPPY)
	elif i == _state.held_from:
		# Back down its own post: the same thread a drop ends on.
		var colour_i: int = _state.held
		_state.put_back()
		_held_at = -100.0
		fx.cue("drop")
		_fly(colour_i, i, i, (_state.pegs[i] as Array).size() - 1, -1, _now(), false)
		_say(tr("RG_PUT_BACK"), Face.Expr.HAPPY)
	else:
		var from: int = _state.held_from
		var colour_i: int = _state.held
		var slot := _state.drop(i)
		if slot == -1:
			_shake_at[i] = _now()
			_refuse_at = _now()
			_refuse_to = i
			fx.cue("refused")
			_say(tr(_state.refusal(i)), Face.Expr.WORRIED)
		else:
			_held_at = -100.0
			fx.cue("drop")
			# The flight has to exist before note_move()'s check_solved() can
			# fire solved -- _on_solved reads _flight for the landing moment
			# its hop wave waits on.
			_fly(colour_i, from, i, slot, -1, _now(), true)
			note_move()
	_refresh()

## Sends a ring from `from` to `to`, landing in `slot`: up off `from`'s post
## first when `from_slot` says it starts on one, over, and down `to`'s post.
## Under reduce motion there is no flight: the ring is simply on its new peg,
## and _settle runs at once if asked.
##
## **Never blocks a second move.** A flight already live when a new one
## starts is landed on the spot (_land_flight), so its _settle -- and the
## lock it may carry -- is never lost to a player tapping faster than the
## arc (tests/test_rings.gd's overlapping-flight case).
func _fly(colour_i: int, from: int, to: int, slot: int, from_slot: int, at: float, settle: bool) -> void:
	_land_flight(at)
	if Motion.reduce:
		if settle:
			_settle(to, at)
		return
	var dur := ARC_TIME + THREAD_TIME + (RISE_TIME if from_slot >= 0 else 0.0)
	if from == to:
		dur = THREAD_TIME * 1.4
	_flight = {"colour": colour_i, "from": from, "to": to, "slot": slot, "from_slot": from_slot,
		"at": at, "dur": dur, "settle": settle}

## Resolves whatever flight is in the air right now, as if it had just
## landed at `at`. A no-op when nothing is flying.
func _land_flight(at: float) -> void:
	if _flight.is_empty():
		return
	var to: int = _flight["to"]
	var slot: int = _flight["slot"]
	var settle: bool = _flight.get("settle", false)
	_flight = {}
	_land_peg = to
	_land_slot = slot
	_land_at = at
	_mesh = null
	if settle:
		_settle(to, at)

## Drops `_lock_at`'s entry for any peg that is no longer locked, checked
## against the state fresh rather than trusted.
func _reconcile_locks() -> void:
	for i in _lock_at.keys().duplicate():
		if not _state.locked(int(i)):
			_lock_at.erase(i)

## Every move that can change the pegs comes through here, so the lock and
## the toast are decided in exactly one place.
func _settle(j: int, at: float) -> void:
	_reconcile_locks()
	if _state.locked(j):
		_lock_at[j] = at
		var st := _station(j)
		var top_pt := _loc(Vector2(float(st["cx"]), float(st["top"])))
		var colour: Color = RING_COLOURS[int(_state.pegs[j][0])]
		fx.ring(top_pt, RING_W * 0.5 * _s, Pal.SUN)
		fx.sparkle(top_pt, colour)
		fx.sparkle(top_pt, Pal.SUN)
		if not _state.is_solved():
			fx.cue("lock")
	if _state.is_solved():
		_say(tr("RG_WIN"), Face.Expr.JOY)
	elif _state.locked(j):
		_say(_home_line(), Face.Expr.JOY)
	else:
		_say(_left_line(), Face.Expr.HAPPY)
	if not _state.is_solved() and _state.is_stuck():
		_toast = STUCK_MSG
		_toast_at = at
	elif _state.out_of_moves():
		_toast = OUT_MSG
		_toast_at = at
	_mesh = null

func _colours_left() -> int:
	return _state.colours - _state.home_count()

func _home_line() -> String:
	var left := _colours_left()
	if left <= 0:
		return tr("RG_WIN")
	if left == 1:
		return tr("RG_ONE_LEFT")
	return tr("RG_HOME_N_LEFT") % left

func _left_line() -> String:
	var left := _colours_left()
	if left == _state.colours:
		return tr("RG_START")
	if left == 1:
		return tr("RG_ONE_LEFT")
	return tr("RG_N_LEFT") % left

## Sets the tip line and tells the host to re-read it.
func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

# --- undo, hint and reset ---

## Takes the last drop back exactly -- up off the peg it landed on, over and
## down the one it came from. Counts no move, and clears the toast.
func undo() -> bool:
	if is_done() or _state.log.is_empty():
		return false
	var m: Vector2i = _state.undo()
	if m.x < 0:
		return false
	_toast = ""
	_toast_at = -100.0
	# Immediate, not deferred to the flight's landing: a peg that just lost
	# its top ring is not locked the instant it loses it.
	_reconcile_locks()
	_held_at = -100.0
	var dst: Array = _state.pegs[m.x]
	var slot := dst.size() - 1
	var colour_i: int = dst[slot]
	_fly(colour_i, m.y, m.x, slot, (_state.pegs[m.y] as Array).size(), _now(), false)
	fx.cue("undo")
	_say(tr("RG_TAKEN_BACK") + " " + _left_line(), Face.Expr.HAPPY)
	_refresh()
	check_solved()
	return true

## Plays the solver's own next move exactly like a tapped drop, through the
## same _settle.
func hint() -> bool:
	if is_done():
		return false
	_toast = ""
	_toast_at = -100.0
	_held_at = -100.0
	var m: Vector2i = _state.hint()
	if m.x < 0:
		if _state.is_stuck():
			_toast = STUCK_MSG
			_toast_at = _now()
		_refresh()
		return false
	hints_used += 1
	fx.cue("hint")
	var dst: Array = _state.pegs[m.y]
	var slot := dst.size() - 1
	var colour_i: int = dst[slot]
	_fly(colour_i, m.x, m.y, slot, (_state.pegs[m.x] as Array).size(), _now(), true)
	check_solved()
	_refresh()
	return true

## Back to the dealt position in one step. Hints spent are not refunded.
func reset_board() -> void:
	_state.reset_board()
	_lock_at = {}
	_shake_at = {}
	_refuse_at = -100.0
	_refuse_to = -1
	_toast = ""
	_toast_at = -100.0
	_reset_at = _now()
	_held_at = -100.0
	_flight = {}
	_land_peg = -1
	_land_slot = -1
	_land_at = -100.0
	_solved_at = -100.0
	fx.cue("reset")
	_say(tr("RG_RESET"), Face.Expr.HAPPY)
	_refresh()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _state.pegs.is_empty():
		return
	var t := _now()
	if not _flight.is_empty():
		var land: float = float(_flight["at"]) + float(_flight["dur"])
		if t >= land:
			_land_flight(land)
	var redraw := false
	if _stations_moving(t):
		_mesh = null
		redraw = true
	if _ring_moving():
		_live_mesh = null
		redraw = true
	if _toast != "" and t - _toast_at < TOAST_HOLD:
		redraw = true
	if redraw:
		queue_redraw()

## The ring in hand breathes and the ring in flight flies: the small mesh.
func _ring_moving() -> bool:
	if Motion.reduce:
		return false
	return _state.held != -1 or not _flight.is_empty()

## Whether anything in the stations' mesh is still moving, asked wave by
## wave: the entrance, the landing squash and its bump down the stack, the
## refusal shiver, the lock's glint and cap, the reset and the solve. A board
## that rebuilds only while it is moving has to ask about **every** wave
## (oneline2d.gd once froze two lines at four fifths of their fade).
func _stations_moving(t: float) -> bool:
	if Motion.reduce:
		return false
	var n := maxi(_state.pegs.size() - 1, 0)
	var entrance := Motion.ENTER_DELAY + Motion.stagger(n, Motion.ENTER_STAGGER) + Motion.DROP_TIME
	if t - _opened < entrance:
		return true
	if t - _land_at < _LAND_SQUASH_TIME + float(Gen.CAP) * BUMP_STEP:
		return true
	if t - _reset_at < Motion.stagger(n, Motion.RESET_STAGGER) + Motion.HOP_TIME:
		return true
	for i in _shake_at.keys():
		if t - float(_shake_at[i]) < Motion.SHIVER_TIME:
			return true
	for j in _lock_at.keys():
		if t - float(_lock_at[j]) < float(Gen.CAP - 1) * Motion.WAVE_STEP + Motion.FLASH_IN + Motion.FLASH_OUT:
			return true
	if _solved_at >= 0.0 and t - _solved_at < Motion.SOLVE_DELAY + Motion.stagger(n, Motion.SOLVE_STAGGER) + Motion.SOLVE_TIME:
		return true
	return false

## Every colour on a peg of its own: every peg hops on the family's wave, off
## the moment the winning ring actually lands.
func _on_solved() -> void:
	var land := _now()
	if not _flight.is_empty():
		land = float(_flight["at"]) + float(_flight["dur"])
	_solved_at = land + (0.0 if Motion.reduce else float(Gen.CAP) * Motion.WAVE_STEP)
	_tip_timer.stop()
	fx.cue("solved")
	_refresh()

func _refresh() -> void:
	_mesh = null
	_live_mesh = null
	queue_redraw()

func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	_refresh()

func _draw() -> void:
	if _state.pegs.is_empty():
		return
	var t := _now()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_s, _s))
	if _mesh == null:
		_mesh = _build_mesh(t)
	if _mesh != null:
		draw_mesh(_mesh, null)
	if _live_mesh == null:
		_live_mesh = _build_live(t)
	if _live_mesh != null:
		draw_mesh(_live_mesh, null)
	_shown = [_mesh, _live_mesh]
	_draw_budget()
	_draw_toast(t, _shown)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Insane's moves left, centred under the second shelf.
func _draw_budget() -> void:
	var left: int = _state.moves_left()
	if left < 0:
		return
	var text := tr("RG_ONE_MOVE_LEFT") if left == 1 else tr("RG_MOVES_LEFT") % left
	if _state.is_solved():
		text = tr("RG_SPARE") % left
	var font: Font = CozyTheme.body(700)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUDGET_FONT).x
	var y: float = float(_ground[1]) + SHELF_H + BUDGET_DROP
	var ink: Color = Pal.BAD if left == 0 and not _state.is_solved() else Pal.TEXT
	draw_string(font, Vector2((_dsize.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUDGET_FONT, ink)

# --- the stations' mesh ---

func _build_mesh(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_build_band(b)
	var centre := Vector2(_dsize.x * 0.5, (float(_ground[0]) + float(_ground[1]) - STATION_H) * 0.5)
	var wide := 1.0
	if not Motion.reduce:
		wide = Motion.wide_pop_scale(t - _opened - Motion.ENTER_DELAY)
	var gmap := func(p: Vector2) -> Vector2:
		return centre + (p - centre) * wide
	_build_shelves(b, gmap)
	for i in _state.pegs.size():
		_build_station(b, i, t, centre, wide)
	return b.mesh() if not b.verts.is_empty() else null

## A wooden shelf under each row: a top face the dishes sit in, its front
## edge and a soft shadow under it, so no peg stands on nothing.
func _build_shelves(b, map: Callable) -> void:
	var counts := _rows_of(_state.pegs.size())
	var top_col: Color = Pal.SCALE_WOOD.lerp(Pal.PAPER, 0.35)
	var front_col: Color = Pal.SCALE_DEEP.lerp(Pal.PAPER, 0.2)
	var lip: Color = top_col.lerp(Color.WHITE, 0.35)
	for row in 2:
		var n: int = counts[row]
		if n <= 0:
			continue
		var g: float = _ground[row]
		var w := float(n) * STATION_W + 24.0
		var x := (_dsize.x - w) * 0.5
		_fan_mapped(b, Face.Builder.ring(Vector2(_dsize.x * 0.5, g + SHELF_H - 2.0), w * 0.5, 12.0),
			Color(Pal.TEXT, 0.07), map)
		_fan_mapped(b, Face.Builder.round_rect(Vector2(x, g - 44.0), Vector2(w, 44.0 + SHELF_H - 6.0), 16.0),
			front_col, map)
		_fan_mapped(b, Face.Builder.round_rect(Vector2(x, g - 44.0), Vector2(w, 52.0), 16.0), top_col, map)
		_fan_mapped(b, Face.Builder.round_rect(Vector2(x + 14.0, g + 3.0), Vector2(w - 28.0, 4.0), 2.0),
			Color(lip, 0.8), map)

## One station: its entrance, reset hop, solve hop and shiver folded into one
## map, then `_append_peg` with this moment's squash, glint and cap.
func _build_station(b, i: int, t: float, centre: Vector2, wide: float) -> void:
	var st := _station(i)
	var since := t - _opened - Motion.ENTER_DELAY - Motion.stagger(i, Motion.ENTER_STAGGER)
	var seen := 1.0
	var lift := 0.0
	if not Motion.reduce:
		seen = Motion.appear_level(since)
		lift = Motion.drop_in_lift(since)
	if seen <= 0.0:
		return
	lift += -Motion.hop_lift(t - _reset_at - Motion.stagger(i, Motion.RESET_STAGGER), Motion.RESET_HOP, Motion.HOP_TIME)
	var hop := 0.0
	if _solved_at >= 0.0:
		hop = -Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY - Motion.stagger(i, Motion.SOLVE_STAGGER),
			Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		lift += hop * 2.2
	var dx := Motion.shiver_offset(t - float(_shake_at.get(i, -100.0)), Motion.SHIVER_PX * 2.0)
	var map := func(p: Vector2) -> Vector2:
		return centre + ((p + Vector2(dx, -lift)) - centre) * wide

	var pegs: Array = (_state.pegs[i] as Array).duplicate()
	# The destination slot of a live flight is drawn by the flight itself.
	if not _flight.is_empty() and int(_flight["to"]) == i and t < float(_flight["at"]) + float(_flight["dur"]):
		pegs.resize(mini(pegs.size(), int(_flight["slot"])))
	var scales: Array = []
	var glints: Array = []
	var stretch := hop / absf(Motion.SOLVE_HOP)
	for k in pegs.size():
		var sc := Vector2(1.0 - 0.04 * stretch, 1.0 + 0.07 * stretch)
		if i == _land_peg and k <= _land_slot:
			var e := t - _land_at - float(_land_slot - k) * BUMP_STEP
			var amount := 0.14 if k == _land_slot else 0.06
			sc *= _land_squash(e, amount)
		scales.append(sc)
		var glint := 0.0
		if _lock_at.has(i):
			glint = Motion.flash_level(t - float(_lock_at[i]) - float(Gen.CAP - 1 - k) * Motion.WAVE_STEP)
		glints.append(glint)
	var cap := 0.0
	if _state.locked(i) and _flight.get("to", -1) != i:
		cap = 1.0
		if _lock_at.has(i) and not Motion.reduce:
			cap = Motion.pop_in_scale(t - float(_lock_at[i]) - float(Gen.CAP - 1) * Motion.WAVE_STEP).x
	_append_peg(b, float(st["cx"]), float(st["ground"]), RING_W, pegs, map, seen, scales, glints, cap)

## A whole peg, `w` the ring's width: the dish's shadow and dish, the rings
## bottom-up, the post above the top ring (into its hole, or into the dish
## when the peg is empty) and, on a locked peg, the gold cap scaled by `cap`.
## The menu card draws its pegs through this too.
static func _append_peg(b, cx: float, ground: float, w: float, colours: Array, map: Callable,
		alpha := 1.0, scales: Array = [], glints: Array = [], cap := 0.0) -> void:
	var dish_bot := ground - DISH_Y * w
	var dish_top := dish_bot - DISH_T * w
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, ground - 2.0 * w / RING_W), DISH_X * w * 1.02, DISH_Y * w * 0.85),
		Color(Pal.TEXT, 0.10 * alpha), map)
	_fan_mapped(b, _capsule(cx, dish_top, dish_bot, DISH_X * w, DISH_Y * w), Color(Pal.LINE.lerp(Pal.SURFACE_HI, 0.25), alpha), map)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, dish_top), DISH_X * w, DISH_Y * w), Color(Pal.SURFACE, alpha), map)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, dish_top + DISH_Y * w * 0.12), DISH_X * w * 0.78, DISH_Y * w * 0.62),
		Color(Pal.SURFACE_HI, alpha), map)
	var top_y := _post_top(ground, w)
	var into := dish_top
	if colours.is_empty():
		_fan_mapped(b, Face.Builder.ring(Vector2(cx, dish_top), HOLE_X * w, HOLE_Y * w * 1.6),
			Color(Pal.LINE.lerp(Pal.TEXT, 0.3), alpha), map)
	for k in colours.size():
		var ci: int = colours[k]
		var sc: Vector2 = scales[k] if k < scales.size() else Vector2.ONE
		var glint: float = glints[k] if k < glints.size() else 0.0
		var yt := _ring_yt(ground, w, k)
		# A squash sits the ring on its own bottom rather than its middle.
		yt += (1.0 - sc.y) * (SIDE + FACE) * w
		_append_donut(b, cx, yt, w, RING_COLOURS[ci], ci + 1, alpha, map, sc, glint)
		into = yt
	_append_post(b, cx, top_y, into, w, alpha, map)
	if cap > 0.0:
		var r := CAP_R * w * cap
		var at := Vector2(cx, top_y)
		_fan_mapped(b, Face.Builder.ring(at + Vector2(0.0, r * 0.25), r, r), Color(Pal.SUN_DEEP, alpha), map)
		_fan_mapped(b, Face.Builder.ring(at, r, r), Color(Pal.SUN_RAY, alpha), map)
		_fan_mapped(b, Face.Builder.ring(at + Vector2(-r * 0.3, -r * 0.35), r * 0.32, r * 0.24),
			Color(Color.WHITE, 0.7 * alpha), map)

## The post from its rounded top down to `bottom_y`, ending on the front half
## of its own cross-section there -- which is what makes it read as going
## *into* a hole at `bottom_y` rather than stopping in front of it.
static func _append_post(b, cx: float, top_y: float, bottom_y: float, w: float, alpha: float, map: Callable) -> void:
	if bottom_y <= top_y:
		return
	var r := POST * w * 0.5
	var ry := HOLE_Y * w * 0.7
	var pts := Face.Builder.arc_points(Vector2(cx, top_y + r), r, PI, TAU)
	var bottom := Face.Builder.arc_points(Vector2.ZERO, 1.0, 0.0, PI)
	for p in bottom:
		pts.append(Vector2(cx + p.x * r, maxf(bottom_y + p.y * ry, top_y + r)))
	var post: Color = Pal.CHEEK.lerp(Pal.SURFACE, 0.62)
	_fan_mapped(b, pts, Color(post, alpha), map)
	var hi_h := bottom_y - top_y - r * 1.2
	if hi_h > 2.0:
		_fan_mapped(b, Face.Builder.round_rect(Vector2(cx - r * 0.55, top_y + r * 0.6), Vector2(r * 0.4, hi_h), r * 0.2),
			Color(post.lerp(Color.WHITE, 0.55), 0.75 * alpha), map)
		_fan_mapped(b, Face.Builder.round_rect(Vector2(cx + r * 0.35, top_y + r * 0.8), Vector2(r * 0.45, hi_h), r * 0.2),
			Color(Pal.CHEEK.lerp(Pal.TEXT, 0.1), 0.35 * alpha), map)

## An ellipse's top half at `y0` joined to its bottom half at `y1`: the
## outline of a band seen from a little above -- a ring's, a dish's.
static func _capsule(cx: float, y0: float, y1: float, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in Face.Builder.arc_points(Vector2.ZERO, 1.0, PI, TAU):
		pts.append(Vector2(cx + p.x * rx, y0 + p.y * ry))
	for p in Face.Builder.arc_points(Vector2.ZERO, 1.0, 0.0, PI):
		pts.append(Vector2(cx + p.x * rx, y1 + p.y * ry))
	return pts

## One ring, `w` wide, its top face centred on (cx, yt): the band with its
## darker rim, its sheen, the pips, the lighter top face and the hole. `sc`
## squashes it and `tilt` leans it about its own middle, before `map`;
## `glint` lays white over it, the lock's shine.
static func _append_donut(b, cx: float, yt: float, w: float, colour: Color, pips: int, alpha: float,
		map: Callable, sc := Vector2.ONE, glint := 0.0, tilt := 0.0) -> void:
	var smap := map
	if sc != Vector2.ONE or tilt != 0.0:
		var about := Vector2(cx, yt + SIDE * w * 0.5)
		var rot := Transform2D(tilt, Vector2.ZERO)
		smap = func(p: Vector2) -> Vector2:
			return map.call(about + rot * ((p - about) * sc))
	var rx := w * 0.5
	var ry := FACE * w
	var yb := yt + SIDE * w
	var edge := w * 0.035
	var rim := colour.lerp(Pal.TEXT, 0.24)
	var band := colour.lerp(Pal.TEXT, 0.04)
	_fan_mapped(b, _capsule(cx, yt, yb, rx, ry), Color(rim, alpha), smap)
	_fan_mapped(b, _capsule(cx, yt, yb - edge, rx, ry), Color(band, alpha), smap)
	# The tube's roundness: its lower half turned away from the light, and a
	# lit strip just under the top face -- both edged on the ring's own
	# ellipse, so the shading curves round it the way a torus's does.
	_fan_mapped(b, _capsule(cx, yt + SIDE * w * 0.5, yb - edge, rx, ry), Color(rim, 0.32 * alpha), smap)
	_fan_mapped(b, _capsule(cx, yt, yt + SIDE * w * 0.28, rx * 0.985, ry), Color(Color.WHITE, 0.16 * alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx - rx * 0.62, yt + ry + SIDE * w * 0.42), rx * 0.13, SIDE * w * 0.26),
		Color(Color.WHITE, 0.20 * alpha), smap)
	var pip_col := Color(colour.lerp(Pal.TEXT, 0.38), 0.7 * alpha)
	var sp := w * 0.07
	var x0 := -float(pips - 1) * sp * 0.5
	var py := yt + ry + SIDE * w * 0.45
	for p in pips:
		_fan_mapped(b, Face.Builder.ring(Vector2(cx + x0 + float(p) * sp, py), w * 0.027, w * 0.027), pip_col, smap)
	var face := colour.lerp(Color.WHITE, 0.22)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, yt), rx, ry), Color(face, alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx - rx * 0.36, yt - ry * 0.42), rx * 0.26, ry * 0.2),
		Color(Color.WHITE, 0.32 * alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, yt), HOLE_X * w, HOLE_Y * w * 1.6), Color(colour.lerp(Pal.TEXT, 0.5), alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, yt + HOLE_Y * w * 0.5), HOLE_X * w * 0.8, HOLE_Y * w * 0.9),
		Color(colour.lerp(Pal.TEXT, 0.3), alpha), smap)
	if glint > 0.0:
		_fan_mapped(b, _capsule(cx, yt, yb, rx, ry), Color(Color.WHITE, 0.55 * glint * alpha), smap)

## `points`, each carried through `map`, as one fan.
static func _fan_mapped(b, points: PackedVector2Array, colour: Color, map: Callable) -> void:
	var mapped := PackedVector2Array()
	mapped.resize(points.size())
	for i in points.size():
		mapped[i] = map.call(points[i])
	b.fan(mapped, colour)

## The span Motion.squash's own tween plays, read as a curve, for a drawn
## ring (Motion has no reader for squash). 0.18 is that recipe's default time.
const _LAND_SQUASH_TIME := 0.18
static func _land_squash(elapsed: float, amount := 0.12) -> Vector2:
	if Motion.reduce or elapsed < 0.0 or elapsed >= _LAND_SQUASH_TIME:
		return Vector2.ONE
	var squashed := Vector2(1.0 + amount * 0.5, 1.0 - amount)
	var split := _LAND_SQUASH_TIME * 0.4
	if elapsed < split:
		return Vector2.ONE.lerp(squashed, sin(elapsed / split * PI * 0.5))
	return squashed.lerp(Vector2.ONE, Motion.back_out((elapsed - split) / (_LAND_SQUASH_TIME - split)))

# --- the ring in hand and the ring in flight ---

func _build_live(t: float) -> ArrayMesh:
	if _state.held == -1 and _flight.is_empty():
		return null
	var b := Face.Builder.new()
	var ident := func(p: Vector2) -> Vector2: return p
	if _state.held != -1:
		_build_held(b, t, ident)
	if not _flight.is_empty():
		_build_flight(b, t, ident)
	return b.mesh() if not b.verts.is_empty() else null

## The held ring: up its post on the back ease over RISE_TIME, stretched
## while it slides, then breathing BOB px for as long as it waits. A refusal
## dips it toward the peg that refused it and shivers it there. Under reduce
## motion it is simply up and still.
func _build_held(b, t: float, map: Callable) -> void:
	var st := _station(_state.held_from)
	var cx: float = st["cx"]
	var ground: float = st["ground"]
	var up := _held_yt(ground, RING_W)
	var y := up
	var sc := Vector2.ONE
	if not Motion.reduce:
		var since := t - _held_at
		var from_y := _ring_yt(ground, RING_W, (_state.pegs[_state.held_from] as Array).size())
		var u := clampf(since / RISE_TIME, 0.0, 1.0)
		y = lerpf(from_y, up, Motion.back_out(u))
		var s := sin(PI * u)
		sc = Vector2(1.0 - 0.05 * s, 1.0 + 0.09 * s)
		var breath := clampf((since - RISE_TIME) / 0.3, 0.0, 1.0)
		y += BOB * sin(maxf(since - RISE_TIME, 0.0) * TAU / BOB_CYCLE) * breath
		if _refuse_to >= 0:
			var to := _station(_refuse_to)
			var dir := signf(float(to["cx"]) - cx)
			var e := t - _refuse_at
			cx += dir * Motion.nudge_offset(e, DIP, Motion.NUDGE_TIME, 0.0)
			cx += Motion.shiver_offset(e - Motion.NUDGE_TIME * 0.5, Motion.SHIVER_PX * 2.5)
	_ring_shadow(b, float(st["cx"]), float(st["top"]), map)
	_append_donut(b, cx, y, RING_W, RING_COLOURS[_state.held], _state.held + 1, 1.0, map, sc)
	# Still on its post while it slides: the post over the ring, into its hole.
	_append_post(b, float(st["cx"]), float(st["top"]), y, RING_W, 1.0, map)

## Where the flying ring is at `t`: {x, yt, tilt, peg, u} -- `peg` the post
## it is on (rising off or threading down), or -1 while it is in the air, and
## `u` how far down the thread it is.
func _pose(t: float) -> Dictionary:
	var at: float = _flight["at"]
	var a := _station(int(_flight["from"]))
	var d := _station(int(_flight["to"]))
	var from_slot: int = _flight["from_slot"]
	var ya := _held_yt(float(a["ground"]), RING_W)
	var yd := _held_yt(float(d["ground"]), RING_W)
	var y_land := _ring_yt(float(d["ground"]), RING_W, int(_flight["slot"]))
	var e := t - at
	if int(_flight["from"]) == int(_flight["to"]):
		var u0 := clampf(e / float(_flight["dur"]), 0.0, 1.0)
		return {"x": float(d["cx"]), "yt": lerpf(yd, y_land, u0 * u0), "tilt": 0.0, "peg": int(_flight["to"]), "u": u0}
	if from_slot >= 0:
		if e < RISE_TIME:
			var u := e / RISE_TIME
			var y0 := _ring_yt(float(a["ground"]), RING_W, from_slot)
			return {"x": float(a["cx"]), "yt": lerpf(y0, ya, 1.0 - (1.0 - u) * (1.0 - u)), "tilt": 0.0,
				"peg": int(_flight["from"]), "u": 0.0}
		e -= RISE_TIME
	if e < ARC_TIME:
		var u := e / ARC_TIME
		var ease := 0.5 - 0.5 * cos(PI * u)
		var x := lerpf(float(a["cx"]), float(d["cx"]), ease)
		var y := lerpf(ya, yd, ease) - ARC_LIFT * sin(PI * u)
		y = maxf(y, FACE * RING_W + 8.0)
		var lean := TILT * sin(PI * u) * signf(float(d["cx"]) - float(a["cx"]))
		return {"x": x, "yt": y, "tilt": lean, "peg": -1, "u": 0.0}
	var v := clampf((e - ARC_TIME) / THREAD_TIME, 0.0, 1.0)
	return {"x": float(d["cx"]), "yt": lerpf(yd, y_land, v * v), "tilt": 0.0, "peg": int(_flight["to"]), "u": v}

func _build_flight(b, t: float, map: Callable) -> void:
	var p := _pose(t)
	var colour_i: int = _flight["colour"]
	var peg: int = p["peg"]
	if peg < 0:
		var d := _station(int(_flight["to"]))
		_ring_shadow(b, float(p["x"]), float(d["top"]), map)
	var sc := Vector2(1.0 + 0.04 * float(p["u"]), 1.0 - 0.02 * float(p["u"]))
	_append_donut(b, float(p["x"]), float(p["yt"]), RING_W, RING_COLOURS[colour_i], colour_i + 1, 1.0,
		map, sc, 0.0, float(p["tilt"]))
	if peg >= 0:
		var st := _station(peg)
		_append_post(b, float(st["cx"]), float(st["top"]), float(p["yt"]), RING_W, 1.0, map)

## A soft disc at the post top under a ring in the air: where it will go.
static func _ring_shadow(b, cx: float, y: float, map: Callable) -> void:
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, y + 6.0), RING_W * 0.3, 10.0), Color(Pal.TEXT, 0.08), map)

## The one thing this board can say that no other move answers: a position
## still legal and already lost. **Deliberately not announced past this
## pill** -- no dimming, no forced ending. Measured while the concept page
## was built (2026-09-20): the true stuck rate is 4%, 9% and 11% by band,
## common enough that silence would read as a bug, rare enough that a modal
## would be a bigger interruption than the problem deserves.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var line := tr(_toast)
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var font: Font = CozyTheme.body(600)
	var w: float = minf(_dsize.x - 120.0,
		font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x + TOAST_PAD)
	if _toast_mesh == null or _toast_mesh_for != line:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -TOAST_H) * 0.5, Vector2(w, TOAST_H), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = line
	if _toast_mesh == null:
		return
	var mid := Vector2(_dsize.x * 0.5, _dsize.y - TOAST_MARGIN - TOAST_H * 0.5)
	draw_set_transform(mid * _s, 0.0, Vector2(_s, _s))
	draw_mesh(_toast_mesh, null, Transform2D.IDENTITY, Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var where := Vector2(-w * 0.5 + TOAST_PAD * 0.5,
		font.get_height(TOAST_FONT) * 0.5 - font.get_descent(TOAST_FONT))
	font.draw_string(get_canvas_item(), where, line, HORIZONTAL_ALIGNMENT_LEFT, -1,
		TOAST_FONT, Color(Pal.PAPER, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_s, _s))

# --- the scenery band at the card's foot ---

## A bank of moss washed toward paper with grass blades and three bushes,
## flush with the card's edges and clipped to its rounded rect -- Word
## Trail's precedent, in this board's own builder so it stays one draw call.
func _build_band(b) -> void:
	var band_top: float = float(_ground[1]) + SHELF_H
	var gy: float = _dsize.y - INSET * 0.5
	var h: float = gy - band_top
	if h < 60.0:
		return
	var w: float = _dsize.x
	var clip := _clip_rect()

	var bank: Color = Pal.MOSS.lerp(Pal.PAPER, 0.45)
	_clip_polygon(b, Face.Builder.round_rect(Vector2(-40.0, gy - 30.0), Vector2(w + 80.0, 120.0), 40.0), bank, clip)

	var blade: Color = Pal.MOSS.lerp(Pal.PAPER, 0.15)
	for i in 28:
		var bx: float = fmod(float(i * 149 + 37), w)
		var bh: float = 16.0 + float((i * 53) % 14)
		var foot := Vector2(bx, gy - 24.0)
		var tip := Vector2(bx + 2.0, gy - 24.0 - bh)
		var far := Vector2(bx + 8.0, gy - 24.0)
		var pts := Face.Builder.bezier2(foot, Vector2(bx + 4.0, gy - 24.0 - bh * 0.6), tip, 8)
		pts.append_array(Face.Builder.bezier2(tip, Vector2(bx + 7.0, gy - 24.0 - bh * 0.5), far, 8))
		pts.append(far)
		_clip_polygon(b, pts, blade, clip)

	var deep: Color = Pal.LEAF.lerp(Pal.PAPER, 0.12)
	var lit: Color = Pal.LEAF_LIGHT
	var bushes := [[76.0, 28.0], [w - 90.0, 24.0], [w * 0.5, 18.0]]
	for bush in bushes:
		var bx: float = bush[0]
		var br: float = bush[1]
		_clip_polygon(b, Face.Builder.ring(Vector2(bx, gy - 32.0), br, br), deep, clip)
		_clip_polygon(b, Face.Builder.ring(Vector2(bx - br * 0.8, gy - 25.0), br * 0.7, br * 0.7), deep, clip)
		_clip_polygon(b, Face.Builder.ring(Vector2(bx + br * 0.8, gy - 25.0), br * 0.7, br * 0.7), deep, clip)
		_clip_polygon(b, Face.Builder.ring(Vector2(bx - br * 0.3, gy - 43.0), br * 0.28, br * 0.28), lit, clip)

## The card's own rounded rect in design pixels, a couple of pixels inside
## its edge so a clipped shape never rides over the panel's own border.
func _clip_rect() -> PackedVector2Array:
	var pad := 2.0 / _s
	var r := maxf(CARD_RADIUS / _s - pad, 0.0)
	return Face.Builder.round_rect(Vector2(pad, pad), _dsize - Vector2(pad, pad) * 2.0, r)

static func _clip_polygon(b, points: PackedVector2Array, colour: Color, clip: PackedVector2Array) -> void:
	for piece in Geometry2D.intersect_polygons(points, clip):
		b.polygon(piece, colour)

# --- the tip card ---

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

## Idles through the four opening tips while nothing has happened yet; the
## moment a ring is lifted or a move is logged, _settle and _tap are the
## only things allowed to speak, or a stale rule would paper over a live
## status line.
func _cycle_tip() -> void:
	if is_done() or not _state.log.is_empty() or _state.held != -1:
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

# --- the state PuzzleBase asks for ---

func is_solved() -> bool:
	return _state.is_solved()

## One coloured square per colour already home, in the order it actually
## came home: replays `log` from the dealt position rather than trusting
## anything stored, the same way every other derived read on this board
## does. A peg can only ever lock once play starts (undo removes the move
## that locked it along with the move itself), so nothing here can double
## it up.
func share_glyphs() -> String:
	var pegs: Array = []
	for s in _state.deal:
		pegs.append((s as Array).duplicate())
	var out := ""
	for m in _state.log:
		var ring = (pegs[m.x] as Array).pop_back()
		(pegs[m.y] as Array).append(ring)
		if Gen.locked(pegs[m.y]):
			out += SHARE_GLYPHS[int(pegs[m.y][0])]
	return out

# --- the win ---

## The day's colours as rings, one per colour with its own pip count, in
## place of the sun and the moon -- flat_win()'s "characters of the answer".
func flat_win() -> Dictionary:
	var faces: Array = []
	for i in _state.colours:
		var icon := RingIcon.new()
		icon.ring_colour = RING_COLOURS[i]
		icon.pips = i + 1
		faces.append(icon)
	return {"faces": faces, "subtitle": tr("RG_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A ring drawn on its own, for the win screen's cast: the board's own donut
## (`_append_donut`, reached through the script's own path because a nested
## class cannot call the outer script's statics unqualified), scaled to
## whatever square seat well_done.gd hands it.
class RingIcon extends Control:
	var ring_colour: Color = Color.WHITE
	var pips: int = 1
	## Set by ui/flat/well_done.gd's set_cast on every face it seats; a ring
	## has no expression of its own, but the property has to exist.
	var expression: int = 0
	## Kept past the frame that builds it -- a canvas command holds a mesh by
	## RID, not by reference.
	var _mesh: ArrayMesh

	## well_done.gd's enter() calls this on every face it seats; a ring has
	## nothing to idle.
	func set_idle(_on: bool) -> void:
		pass

	func _draw() -> void:
		var board = load("res://puzzles/rings2d.gd")
		var w := size.x * 0.9
		var tall: float = (board.SIDE + 2.0 * board.FACE) * w
		var yt: float = (size.y - tall) * 0.5 + board.FACE * w
		var b := Face.Builder.new()
		var ident := func(p: Vector2) -> Vector2: return p
		board._append_donut(b, size.x * 0.5, yt, w, ring_colour, pips, 1.0, ident)
		_mesh = b.mesh()
		if _mesh != null:
			draw_mesh(_mesh, null)
