extends "res://core/puzzle_base.gd"

## Rings as a flat board: eight pegs standing in two rows, twenty-four rings
## dealt three to a peg, and a pale post standing proud of every stack. Lift
## the top ring off a peg and set it down on an empty peg or on a ring of its
## own colour; the rules live in puzzles/rings_state.gd and the deal and its
## proof in puzzles/rings_gen.gd, which this only draws.
##
## **Lifting, dropping, Undo, Hint and Reset are all here now.** Every move
## that can change the pegs goes through one door, _settle, so the wash and
## the toast are decided in exactly one place -- it is Queens' _settle with
## a peg in place of a queen's sight. A tap on a peg lifts an empty hand's
## top ring, puts a held one back where it came from, or drops it, in
## _gui_input/_tap; _peg_at tests the whole station column plus the lift's
## own headroom, because a thumb aiming at a peg with a ring hovering over
## it is still aiming at that peg.
##
## **The motion is here too now.** A held ring rises on the back ease and
## breathes; a dropped ring flies (_fly, _flight) rather than snapping, on a
## sine ease in x and an eased arc in y, clamped so it never leaves the card;
## `_settle` itself only runs once a flight lands, so the wash, the fx ring
## and the tip line all land with the ring rather than a beat early. A
## locked peg washes its rings gold top-down off `_lock_at` and nothing
## else, read through `Motion.flash_level`; a refusal shivers the station; a
## reset drops every peg back on `Motion.RESET_STAGGER`, and a solve hops
## every peg on `Motion.SOLVE_HOP`. The one toast this board owns
## (STUCK_MSG) is a small cached mesh, the way Hidden Word caches its own.
## Concept page's drawHeld, drawFlight, washOf, drawStation and drawToast are
## what all of this ports, number for shape rather than number for number
## where core/motion.gd already has the reader.
##
## How it is drawn. One mesh: the pegs at rest (their shadow, post, dish and
## rings, bottom-up) and the scenery band at the card's foot, rebuilt in
## _draw while the entrance is still running and kept in _shown until the
## next one replaces it (a canvas command holds a mesh by RID, and a harness
## that calls force_draw() without that photographs a freed one). A station's
## own entrance -- the drop from Motion.DROP above, staggered a peg apart --
## is baked straight into that station's vertices rather than played on a
## node, because Word Trail's and Queens' pieces are drawn rather than built
## of Controls; the whole board's own wide pop about its centre is baked the
## same way, scaling every station's already-offset points toward the
## board's middle.
##
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md, sections 1,
## 4 and 5. Concept page: docs/brainstorm/concepts.html#rings, whose
## drawRing, drawPost, drawStation, scenery, station and slotY are the shapes
## ported here number for number.
##
## **`ui/menu/card_art.gd`'s "rings" branch is a second consumer of
## `_append_ring`, `_slab_mapped`, `_fan_mapped` and `RING_COLOURS`.** Those
## three helpers carry a leading underscore because they are this board's
## own internals, not a published API -- GDScript does not enforce that,
## and the card calls them anyway, on purpose: the alternative was a second
## copy of the ring shape on the menu, and two copies drift the first time
## either one changes, which is exactly what a menu card is supposed to
## promise it won't do. The trade taken is one ring shape, not two -- so
## changing what a ring, a post or a base looks like here, or any of these
## four signatures, changes the menu card too, and that has to be checked
## (`tests/_shot_menu.gd -- page2`) alongside the board itself.

const State = preload("res://puzzles/rings_state.gd")
const Gen = preload("res://puzzles/rings_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const CozyTheme = preload("res://ui/theme.gd")

# --- the screen, measured (spec section 4) ---
## The card's inset, and the station a peg stands in.
const INSET := 28.0
const STATION_W := 236.0
const RING_W := 200.0
const RING_H := 92.0
const RING_GAP := 6.0
const POST_W := 30.0
## How far the post stands proud of a **full** stack. It is what tells a player
## at a glance that a peg of three has room for one more.
const POST_UP := 48.0
const BASE_W := 182.0
const BASE_H := 30.0
## CAP * (RING_H + RING_GAP) - RING_GAP, and BASE_H + STACK_H + POST_UP. Written
## out because a `const` initialised from another script's constant does not
## always fold in GDScript; if `Gen.CAP * ...` compiles, prefer the expression.
const STACK_H := 386.0
const STATION_H := 464.0
## The air over the top row is the lift's, not a taste: a ring in hand hovers
## LIFT_H over the post, so anything less and a held ring hangs out of the
## card. Found by shooting the concept tab with a ring up, not by reading it.
const TOP_AIR := 96.0
const MID_GAP := 96.0

# --- this board's own six (spec section 5); everything else the board reads
# is a recipe or a curve reader off core/motion.gd. None of the six is used
# yet -- lifting, dropping and the toast are a later task -- and they are
# declared here so that task adds behaviour and not arithmetic. ---
## How far a lifted ring floats over its post.
const LIFT_H := 40.0
## Its idle breath while it waits to be put down, and how long a breath takes.
const BOB := 5.0
const BOB_CYCLE := 1.9
## The flight from one peg to another.
const ARC_TIME := 0.34
## The little arch it makes on the way.
const ARC_LIFT := 26.0
## How long "Nothing can move" stays up.
const TOAST_HOLD := 2.6
## The customary win wait: every board that plays a solve wave keeps its own
## copy of this name and this number.
const WIN_WAIT := 1.4

## The card's own rounded rect, so the scenery band -- which is cut off flush
## with the card's edges, not inset like a board's usual field -- can be
## clipped to it rather than showing square corners past the round panel.
## Matches ui/flat/flat_host.gd's own board card stylebox radius.
const CARD_RADIUS := 32.0

## The ring colours and the pip count each one wears. core/palette.gd says it
## about Code Break's pegs -- "every peg also carries a pip mark, so colour
## never stands alone" -- and a game whose whole mechanic is matching colour is
## the game that rule was written for. A player who cannot tell the coral from
## the tan can still count.
const RING_COLOURS := [Pal.BERRY, Pal.SUN, Pal.MOON_INK, Pal.ACORN, Pal.FLOWER, Pal.ACCENT]

## One coloured square per ring colour, in RING_COLOURS' own order, for
## share_glyphs() -- the same language Word Trail's green squares speak.
const SHARE_GLYPHS := ["🟥", "🟨", "🟦", "🟫", "🟪", "🟩"]

const TIP_CYCLE := 8.0
const TIPS := [
	"Tap a peg to lift its top ring.",
	"A ring lands on its own colour, or on an empty peg.",
	"Four of a colour fills a peg, and it locks.",
	"Nothing is ever lost here. Undo is right above.",
]

## What the toast says when a move leaves nothing legal to play. Exactly the
## concept page's own string.
const STUCK_MSG := "Nothing can move. Undo, or start again."

## The toast pill's own shape -- layout, not motion, so these sit outside
## this board's six. Matches the concept page's own pill.
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
## How far the pill's own bottom sits above the card's bottom edge.
const TOAST_MARGIN := 66.0

var _state = State.new()

var _opened := 0.0
## The two rows' top y, set by _layout() and read by _station().
var _row_y: Array[float] = [0.0, 0.0]
var _inner_x := 0.0
var _inner_w := 0.0

## The pegs, dishes, rings at rest and the scenery band, one mesh, rebuilt
## whenever the entrance is still running.
var _mesh: ArrayMesh
## The mesh the last _draw actually handed to the canvas item -- kept so a
## harness's force_draw() never draws a freed RID.
var _shown: Array = []

var _tip_timer: Timer
var _tip_idx := 0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY

## Rings, puffs and sparkles (ui/fx2d.gd), fired at a post's mouth when it
## locks.
var fx: Fx2D

## Peg index -> the second it locked, for the gold wash's timing (Task 5).
## Derived, not truth: cleared for a peg that is no longer locked on every
## _settle, so an undo that breaks a peg takes its gold with it.
var _lock_at: Dictionary = {}
## Peg index -> the second a drop on it was last refused, for its shiver.
var _shake_at: Dictionary = {}
## The station under the finger when it pressed, so the release can tell it
## never left.
var _press_i := -1
## "" when nothing is up; otherwise the toast's line, and _toast_at says
## when it was raised.
var _toast := ""
var _toast_at := -100.0
## The moment reset_board() last ran, for its own drop-in wave.
var _reset_at := -100.0
## The moment the ring in hand was lifted, for its rise and its breathing.
## -100.0 (nothing held) rather than -1.0, matching every sentinel on this
## board and Hidden Word's own.
var _held_at := -100.0
## The one ring in flight between two pegs, or {} for none: "colour" (the
## ring's colour index), "from"/"to" (peg indices), "slot" (the slot it is
## landing in), "at" (when it left), "dur" (ARC_TIME, or 0 caught earlier by
## _fly under reduce motion, which never builds one), and "settle" (whether
## _process should call _settle once it lands -- true for a tapped or
## hinted drop, false for an undo, which can never newly lock a peg).
var _flight: Dictionary = {}
## Which peg and slot last landed, and when, for the landing's own squash --
## -1/-1/-100.0 for none. One slot is enough to remember because a new
## flight always resolves whatever is still in the air before it takes this
## slot (`_fly`'s own call to `_land_flight`), so there is never more than
## one flight, live or just-landed, to keep track of.
var _land_peg := -1
var _land_slot := -1
var _land_at := -100.0
## When is_solved() last turned true, for the win's hop wave -- -100.0
## rather than word_trail2d.gd's -1.0, matching this board's own sentinels.
var _solved_at := -100.0
## The toast pill's mesh, cached by its own text the way
## puzzles/hidden_word2d.gd caches _toast_mesh / _toast_mesh_for -- one
## message on this board today, but never special-cased for having only one.
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

func puzzle_id() -> String: return "rings"
func title() -> String: return "Rings"

func rules() -> String:
	return "Lift the top ring off any peg and set it down on an empty peg or on a ring of its own colour -- nowhere else. Four rings of the same colour fill a peg, and a peg that full locks: nothing ever comes off it again. Nothing here is ever lost, so play freely -- Undo and Reset are always one tap away. The board is done the moment every colour stands alone on a peg of its own."

func capabilities() -> Array[String]:
	return ["undo", "hint"]

func can_undo() -> bool:
	return not _state.log.is_empty()

func hints_left() -> int:
	return State.HINTS - hints_used

func card_height(available: float) -> float:
	return available

## False, and honestly so: card_height() hands back everything it is given, so
## there is no slack to centre.
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
	_state.build(rng, difficulty)
	_layout()
	_enter()
	_tip_idx = 0
	_tip_text = TIPS[0]
	_tip_mood = Face.Expr.HAPPY
	_press_i = -1
	_shake_at = {}
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

func _layout() -> void:
	_inner_x = INSET
	_inner_w = size.x - 2.0 * INSET
	var r0 := INSET + TOP_AIR
	var r1 := r0 + STATION_H + MID_GAP
	_row_y = [r0, r1]
	_toast_mesh = null
	_toast_mesh_for = ""
	_refresh()

## Where peg `i` stands: a short row is centred, so a station is 236 wide and
## a ring 200 whatever the band.
func _station(i: int) -> Dictionary:
	var counts := _rows_of(_state.pegs.size())
	var a: int = counts[0]
	var row := 0 if i < a else 1
	var k := i if row == 0 else i - a
	var n := a if row == 0 else int(counts[1])
	var x := _inner_x + (_inner_w - float(n) * STATION_W) * 0.5 + float(k) * STATION_W
	return {"row": row, "x": x, "cx": x + STATION_W * 0.5, "top": _row_y[row], "ground": _row_y[row] + STATION_H}

## The centre of slot `k` of station `st` (bottom slot is 0).
func _slot_y(st: Dictionary, k: int) -> float:
	return float(st["ground"]) - BASE_H - RING_H * 0.5 - float(k) * (RING_H + RING_GAP)

# --- input and the one door every move goes through ---

## The peg under `p`: the whole STATION_W by STATION_H column, plus the
## lift's own headroom above it (LIFT_H) -- a thumb aiming at a peg with a
## ring hovering over it is still aiming at that peg, not at the gap above
## the row.
func _peg_at(p: Vector2) -> int:
	for i in _state.pegs.size():
		var st := _station(i)
		var x: float = st["x"]
		var top: float = st["top"]
		var ground: float = st["ground"]
		if p.x >= x and p.x <= x + STATION_W and p.y >= top - LIFT_H and p.y <= ground:
			return i
	return -1

## Touch only, as every flat board takes it: the viewport hands a control
## both the mouse event and the emulated touch, and two would fire twice.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press_i = _peg_at(event.position)
		else:
			var i := _press_i
			_press_i = -1
			if i >= 0 and i == _peg_at(event.position):
				_tap(i)

## The one tap gesture this board takes: lift an empty hand's ring off peg
## `i`, put a held ring back where it came from, or drop it on `i` -- the
## only place state.drop() is ever called.
func _tap(i: int) -> void:
	if is_done():
		return
	if _state.held == -1:
		if _state.lift(i):
			_held_at = _now()
			_say("Drop it on its own colour, or on an empty peg.", Face.Expr.HAPPY)
		elif (_state.pegs[i] as Array).is_empty():
			_say("That peg is empty. Lift from a peg that has a ring.", Face.Expr.HAPPY)
		else:
			_say("That colour is home. Nothing comes off a finished peg.", Face.Expr.HAPPY)
	elif i == _state.held_from:
		_state.put_back()
		_held_at = -100.0
		_say("Back where it was.", Face.Expr.HAPPY)
	else:
		var from: int = _state.held_from
		var colour_i: int = _state.held
		var slot := _state.drop(i)
		if slot == -1:
			_shake_at[i] = _now()
			_say(_state.refusal(i), Face.Expr.WORRIED)
		else:
			_held_at = -100.0
			# The flight has to exist before note_move()'s check_solved() can
			# fire solved -- _on_solved reads _flight for the landing moment
			# its hop wave waits on.
			_fly(colour_i, from, i, slot, _now(), true)
			note_move()
	_refresh()

## Sends the ring last lifted or dropped flying from `from` to `to`, landing
## in `slot` of the destination -- the one place a ring's position changes
## over time on this board rather than at once. `settle` says whether
## _process should call _settle once it lands: true for a tapped or hinted
## drop, false for an undo, which can only ever shrink a peg and so can
## never newly lock one. Under reduce motion there is no flight at all (the
## brief's own words): the ring is simply on its new peg, and _settle runs
## at once if asked.
##
## **Never blocks a second move.** A ring sort invites fast tapping, and this
## board must not refuse a tap for ARC_TIME because a previous ring is still
## in the air. So a flight already live when a new one starts is landed
## right now, on the spot, rather than left to finish its arc: without this,
## re-lifting the ring just dropped (legal the instant drop() returns, since
## `_state` already carries it as that peg's top) overwrites `_flight`
## before `_process`'s own `t >= land` check ever fires for the first move,
## and its `_settle` -- and with it the wash on a peg it may have just
## locked -- never runs, silently, for the rest of the game. The ring simply
## snaps to its slot instead of finishing its arc, which is the one thing
## allowed to be lost to a player moving faster than the animation.
func _fly(colour_i: int, from: int, to: int, slot: int, at: float, settle: bool) -> void:
	_land_flight(at)
	if Motion.reduce:
		if settle:
			_settle(to, at)
		return
	_flight = {"colour": colour_i, "from": from, "to": to, "slot": slot, "at": at, "dur": ARC_TIME, "settle": settle}

## Resolves whatever flight is in the air right now, as if it had just
## landed at `at`: records the landing squash's peg/slot/moment and, if the
## flight was a genuine drop or hint (`settle`), calls _settle. A no-op when
## nothing is flying. Called both from _process, when a flight's own time is
## up, and from _fly, when a second move starts before the first has
## landed -- see _fly's own comment for why that must never be silent.
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
	if settle:
		_settle(to, at)

## Drops `_lock_at`'s entry for any peg that is no longer locked, checked
## against the state fresh rather than trusted -- the only way that happens
## is an undo breaking a peg, and it is the one thing that must never be
## copied twice: two copies of this invariant is how a stale gold wash
## survives an undo.
func _reconcile_locks() -> void:
	for i in _lock_at.keys().duplicate():
		if not _state.locked(int(i)):
			_lock_at.erase(i)

## Every move that can change the pegs comes through here, so the wash and
## the toast are decided in exactly one place. Nothing else may call
## state.drop.
func _settle(j: int, at: float) -> void:
	_reconcile_locks()
	if _state.locked(j):
		_lock_at[j] = at
		var st := _station(j)
		var top_pt := Vector2(float(st["cx"]), _slot_y(st, Gen.CAP - 1) - RING_H * 0.5 - POST_UP)
		var colour: Color = RING_COLOURS[int(_state.pegs[j][0])]
		fx.ring(top_pt, RING_W * 0.5, colour)
		fx.sparkle(top_pt, colour)
	if _state.is_solved():
		_say("Every colour on a peg of its own.", Face.Expr.JOY)
	elif _state.locked(j):
		_say(_home_line(), Face.Expr.JOY)
	else:
		_say(_left_line(), Face.Expr.HAPPY)
	if not _state.is_solved() and _state.is_stuck():
		_toast = STUCK_MSG
		_toast_at = at

## How many colours are still loose, in the tip's own two shapes: after a
## peg has just locked, and after a ring has merely moved.
func _colours_left() -> int:
	return _state.colours - _state.home_count()

func _home_line() -> String:
	var left := _colours_left()
	if left <= 0:
		return "Every colour on a peg of its own."
	if left == 1:
		return "One colour left to gather."
	return "That one is home. %d colours left." % left

func _left_line() -> String:
	var left := _colours_left()
	if left == _state.colours:
		return "Lift a ring and find it a peg."
	if left == 1:
		return "One colour left to gather."
	return "%d colours left to gather." % left

## Sets the tip card's line and tells the host to re-read it. The tip card
## only re-reads a board when the host refreshes it, and the host refreshes
## on this signal.
func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

# --- undo, hint and reset ---

## Takes the last drop back exactly, including one that finished a peg --
## no legality check, it was legal on the way out. Counts no move, and
## clears the toast: a board that can still be undone was never really
## stuck, so a stale "nothing can move" would be a lie the instant it lands.
func undo() -> bool:
	if is_done() or _state.log.is_empty():
		return false
	var m: Vector2i = _state.undo()
	if m.x < 0:
		return false
	_toast = ""
	_toast_at = -100.0
	# Immediate, not deferred to the flight's landing: a peg that just lost
	# its top ring is not locked the instant it loses it, and a stale gold
	# wash on the rings still under it would be a lie for however long the
	# ring takes to fly clear.
	_reconcile_locks()
	var dst: Array = _state.pegs[m.x]
	var slot := dst.size() - 1
	var colour_i: int = dst[slot]
	_fly(colour_i, m.y, m.x, slot, _now(), false)
	_say("Taken back. " + _left_line(), Face.Expr.HAPPY)
	_refresh()
	check_solved()
	return true

## Plays the solver's own next move exactly like a tapped drop, through the
## same _settle -- and, like a tapped drop, spends nothing when there is
## none to play. Counts no move (hints_used, not moves) but can finish the
## puzzle, so it calls check_solved() directly.
func hint() -> bool:
	if is_done():
		return false
	_toast = ""
	_toast_at = -100.0
	var m: Vector2i = _state.hint()
	if m.x < 0:
		if _state.is_stuck():
			_toast = STUCK_MSG
			_toast_at = _now()
		return false
	hints_used += 1
	var dst: Array = _state.pegs[m.y]
	var slot := dst.size() - 1
	var colour_i: int = dst[slot]
	_fly(colour_i, m.x, m.y, slot, _now(), true)
	check_solved()
	_refresh()
	return true

## Back to the dealt position in one step. Hints spent are not refunded.
func reset_board() -> void:
	_state.reset_board()
	_lock_at = {}
	_shake_at = {}
	_toast = ""
	_toast_at = -100.0
	_reset_at = _now()
	_held_at = -100.0
	_flight = {}
	_land_peg = -1
	_land_slot = -1
	_land_at = -100.0
	_solved_at = -100.0
	_say("The pegs as they were dealt.", Face.Expr.HAPPY)
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
	if _animating(t):
		_refresh()

## Whether anything on this board is still moving, asked wave by wave: the
## entrance, the held ring's rise and its breathing, the flight, the
## landing's own squash, the gold wash, the refusal shiver, the reset and
## the solve -- and the toast's own hold, which has to keep the frame coming
## under reduce motion too, since nothing else does there and it still has
## to leave on time. A board that rebuilds only while it is moving has to
## ask about **every** wave: oneline2d.gd once asked only its entrance and
## left two lines frozen at four fifths of their fade, and it showed on a
## rendered frame and in no test.
func _animating(t: float) -> bool:
	if _toast != "" and t - _toast_at < TOAST_HOLD:
		return true
	if Motion.reduce:
		return false
	if _state.held != -1:
		return true
	if not _flight.is_empty():
		return true
	if t - _land_at < _LAND_SQUASH_TIME:
		return true
	var n := maxi(_state.pegs.size() - 1, 0)
	var entrance := Motion.ENTER_DELAY + Motion.stagger(n, Motion.ENTER_STAGGER) + Motion.DROP_TIME
	if t - _opened < entrance:
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
## the moment the winning ring actually lands rather than the moment
## note_move() called check_solved() (which fires before the flight that
## carries it has finished) -- so the hop never starts a beat before the
## last ring is visibly home. `_flight` is only empty here under reduce
## motion, where the hop is zero anyway.
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
	queue_redraw()

func _enter() -> void:
	_opened = _now()
	_refresh()

func _draw() -> void:
	if _state.pegs.is_empty():
		return
	var t := _now()
	if _mesh == null:
		_mesh = _build_mesh(t)
	if _mesh != null:
		draw_mesh(_mesh, null)
	_shown = [_mesh]
	_draw_toast(t, _shown)

# --- the mesh ---

func _build_mesh(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_build_band(b)
	if not _state.pegs.is_empty():
		var centre := Vector2(size.x * 0.5, (_row_y[0] + _row_y[1] + STATION_H) * 0.5)
		var wide := 1.0
		if not Motion.reduce:
			wide = Motion.wide_pop_scale(t - _opened - Motion.ENTER_DELAY)
		for i in _state.pegs.size():
			_build_station(b, i, t, centre, wide)
		# The held ring and the one in flight stand outside every station's
		# own map -- they take the board's wide pop (drawn inside the same
		# scaled block on the concept page) but never a station's own
		# entrance lift, which is a station's alone.
		var gmap := func(p: Vector2) -> Vector2:
			return centre + (p - centre) * wide
		_build_held(b, t, gmap)
		_build_flight(b, t, gmap)
	return b.mesh() if not b.verts.is_empty() else null

## One station: the seat shadow, the post (drawn only from its top down to
## the top ring's centre, or to the dish when the peg is empty), the dish,
## then the rings bottom-up. `map` carries this station's own entrance --
## the drop from above and the board's wide pop about `centre` -- into every
## point drawn for it.
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
	# Reset's own drop-in wave and the solve's hop read the same way the
	# entrance's does: Motion.hop_lift's height is signed for a Control's
	# position (negative is up), and this map wants a magnitude that is
	# already up, so both are negated in.
	lift += -Motion.hop_lift(t - _reset_at - Motion.stagger(i, Motion.RESET_STAGGER), Motion.RESET_HOP, Motion.HOP_TIME)
	if _solved_at >= 0.0:
		lift += -Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY - Motion.stagger(i, Motion.SOLVE_STAGGER),
			Motion.SOLVE_HOP, Motion.SOLVE_TIME)
	var dx := Motion.shiver_offset(t - float(_shake_at.get(i, -100.0)))
	var map := func(p: Vector2) -> Vector2:
		return centre + ((p + Vector2(dx, -lift)) - centre) * wide

	var cx: float = st["cx"]
	var ground: float = st["ground"]
	var pegs: Array = _state.pegs[i]

	_fan_mapped(b, Face.Builder.ring(Vector2(cx, ground - 2.0), BASE_W * 0.58, 13.0),
		Color(Pal.TEXT, 0.08 * seen), map)

	var top_y := _slot_y(st, Gen.CAP - 1) - RING_H * 0.5 - POST_UP
	var bot_y := _slot_y(st, pegs.size() - 1) if not pegs.is_empty() else ground - BASE_H + 6.0
	var post: Color = Pal.CHEEK.lerp(Pal.SURFACE, 0.62)
	var post_deep: Color = Pal.CHEEK.lerp(Pal.TEXT, 0.18)
	_slab_mapped(b, Vector2(cx - POST_W * 0.5, top_y), Vector2(POST_W, bot_y - top_y), POST_W * 0.5, 5.0,
		Color(post, seen), Color(post_deep, seen), map)
	var post_hi: Color = post.lerp(Color.WHITE, 0.55)
	_fan_mapped(b, Face.Builder.round_rect(Vector2(cx - POST_W * 0.22, top_y + 8.0),
			Vector2(POST_W * 0.2, maxf(bot_y - top_y - 22.0, 0.0)), POST_W * 0.1),
		Color(post_hi, 0.75 * seen), map)

	_slab_mapped(b, Vector2(cx - BASE_W * 0.5, ground - BASE_H), Vector2(BASE_W, BASE_H), BASE_H * 0.5, 7.0,
		Color(Pal.SURFACE_HI, seen), Color(Pal.LINE, seen), map)

	for k in pegs.size():
		# The destination slot of a live flight is drawn there separately
		# (_build_flight); drawing it here too would show the ring twice.
		if not _flight.is_empty() and int(_flight["to"]) == i and int(_flight["slot"]) == k \
				and t < float(_flight["at"]) + float(_flight["dur"]):
			continue
		var colour_i: int = pegs[k]
		var ring_col: Color = RING_COLOURS[colour_i]
		if _lock_at.has(i):
			# Top ring down: k = CAP - 1 is the top and washes first.
			var wash := Motion.flash_level(t - float(_lock_at[i]) - float(Gen.CAP - 1 - k) * Motion.WAVE_STEP)
			if wash > 0.0:
				ring_col = ring_col.lerp(Pal.SUN_RAY, wash)
		var land_scale := Vector2.ONE
		if i == _land_peg and k == _land_slot:
			land_scale = _land_squash(t - _land_at)
		_append_ring(b, cx, _slot_y(st, k), RING_W, RING_H, ring_col, colour_i + 1, seen, map, land_scale)

## A rounded card of `box` at `at`: a rim colour under a face colour inset by
## `edge` at the bottom, the soft lip every card on these screens wears.
static func _slab_mapped(b, at: Vector2, box: Vector2, r: float, edge: float,
		face: Color, rim: Color, map: Callable) -> void:
	_fan_mapped(b, Face.Builder.round_rect(at, box, r), rim, map)
	_fan_mapped(b, Face.Builder.round_rect(at, Vector2(box.x, maxf(box.y - edge, 0.0)), r), face, map)

## One ring, `ring_w` by `ring_h`, centred on (cx, cy): the face, its bottom
## rim, the shoulder highlight, the post's dimple and its pips (spec
## section 4's table, ported number for number off drawRing).
static func _append_ring(b, cx: float, cy: float, ring_w: float, ring_h: float,
		colour: Color, pips: int, alpha: float, map: Callable, scale: Vector2 = Vector2.ONE) -> void:
	# The landing squash scales the ring about its own centre, before the
	# station's map (its entrance lift, the board's wide pop): a local
	# effect on the piece itself, same as every other drawn board's pop.
	var smap := map
	if scale != Vector2.ONE:
		var about := Vector2(cx, cy)
		smap = func(p: Vector2) -> Vector2:
			return map.call(about + (p - about) * scale)
	var face := colour
	var rim := colour.lerp(Pal.TEXT, 0.22)
	var edge := ring_h * (9.0 / 92.0)
	var at := Vector2(cx - ring_w * 0.5, cy - ring_h * 0.5)
	_fan_mapped(b, Face.Builder.round_rect(at, Vector2(ring_w, ring_h), ring_h * 0.5), Color(rim, alpha), smap)
	_fan_mapped(b, Face.Builder.round_rect(at, Vector2(ring_w, maxf(ring_h - edge, 0.0)), ring_h * 0.5),
		Color(face, alpha), smap)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx - ring_w * 0.22, cy - ring_h * 0.26), ring_w * 0.17, ring_h * 0.11),
		Color(Color.WHITE, 0.26 * alpha), smap)
	var dimple := face.lerp(Pal.TEXT, 0.30)
	var post_w := ring_w * (POST_W / RING_W)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, cy - ring_h * 0.21), post_w * 0.56, ring_h * 0.10),
		Color(dimple, 0.32 * alpha), smap)
	var pip_col := Color(dimple, 0.70 * alpha)
	var sp := ring_w * 0.098
	var x0 := -float(pips - 1) * sp * 0.5
	for p in pips:
		_fan_mapped(b, Face.Builder.ring(Vector2(cx + x0 + float(p) * sp, cy + ring_h * 0.17),
			ring_h * 0.075, ring_h * 0.075), pip_col, smap)

## The held ring: risen LIFT_H over its post on the back ease over
## Motion.LIFT_TIME, then breathing BOB px on a BOB_CYCLE for as long as it
## waits -- forever, until it is put back or dropped. Under reduce motion it
## is simply up and does not breathe (the brief's own words).
func _build_held(b, t: float, map: Callable) -> void:
	if _state.held == -1:
		return
	var st := _station(_state.held_from)
	var cx: float = st["cx"]
	var up := _slot_y(st, Gen.CAP - 1) - RING_H * 0.5 - POST_UP - LIFT_H
	var y := up
	if not Motion.reduce:
		var since := t - _held_at
		var from_y := _slot_y(st, (_state.pegs[_state.held_from] as Array).size())
		var u := clampf(since / Motion.LIFT_TIME, 0.0, 1.0)
		y = lerpf(from_y, up, Motion.back_out(u)) + BOB * sin(since * TAU / BOB_CYCLE)
	_ring_shadow(b, cx, y, map)
	_append_ring(b, cx, y, RING_W, RING_H, RING_COLOURS[_state.held], _state.held + 1, 1.0, map)

## The one ring in flight: x on a sine ease between the two stations, y held
## near the lift height early and falling late (an eased arc), clamped so it
## never leaves the card. Under reduce motion _flight never exists (_fly
## settles at once instead), so this only ever draws when there is one.
func _build_flight(b, t: float, map: Callable) -> void:
	if _flight.is_empty():
		return
	var at: float = _flight["at"]
	var dur: float = float(_flight["dur"])
	var u := clampf((t - at) / dur, 0.0, 1.0) if dur > 0.0 else 1.0
	var a := _station(int(_flight["from"]))
	var d := _station(int(_flight["to"]))
	var y0 := _slot_y(a, Gen.CAP - 1) - RING_H * 0.5 - POST_UP - LIFT_H
	var y1 := _slot_y(d, int(_flight["slot"]))
	var ease := 0.5 - 0.5 * cos(PI * u)
	var x := lerpf(float(a["cx"]), float(d["cx"]), ease)
	var y := lerpf(y0, y1, u * u) - ARC_LIFT * sin(PI * u)
	y = maxf(y, INSET + RING_H * 0.5)
	_ring_shadow(b, x, y, map)
	var colour_i: int = _flight["colour"]
	_append_ring(b, x, y, RING_W, RING_H, RING_COLOURS[colour_i], colour_i + 1, 1.0, map)

## The soft disc a held or flying ring casts, trailing below it -- the
## concept page's own `shadow` option on drawRing, always RING_H * 0.9 below
## the ring rather than pinned to the peg it is over, which is what makes it
## read as the ring's own shadow rather than the post's.
static func _ring_shadow(b, cx: float, cy: float, map: Callable) -> void:
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, cy + RING_H * 0.9), RING_W * 0.44, 12.0),
		Color(Pal.TEXT, 0.10), map)

## The span Motion.squash's own tween plays, read as a curve: this board
## draws its rings rather than tweening Control nodes (docs/art/flat-motion.md
## rule 8, Shikaku's precedent), and Motion has no reader for squash the way
## it does for every other recipe a drawn board calls. 0.12 and 0.18 are that
## recipe's own defaults, copied rather than read back out of it because
## GDScript cannot introspect a static function's default arguments -- not a
## number of this board's own, and not one of its six.
const _LAND_SQUASH_TIME := 0.18
static func _land_squash(elapsed: float) -> Vector2:
	if Motion.reduce or elapsed < 0.0 or elapsed >= _LAND_SQUASH_TIME:
		return Vector2.ONE
	var amount := 0.12
	var squashed := Vector2(1.0 + amount * 0.5, 1.0 - amount)
	var split := _LAND_SQUASH_TIME * 0.4
	if elapsed < split:
		return Vector2.ONE.lerp(squashed, sin(elapsed / split * PI * 0.5))
	return squashed.lerp(Vector2.ONE, Motion.back_out((elapsed - split) / (_LAND_SQUASH_TIME - split)))

## `points`, each carried through `map`, as one fan.
static func _fan_mapped(b, points: PackedVector2Array, colour: Color, map: Callable) -> void:
	var mapped := PackedVector2Array()
	mapped.resize(points.size())
	for i in points.size():
		mapped[i] = map.call(points[i])
	b.fan(mapped, colour)

## The one thing this board can say that no other move answers: a position
## still legal and already lost. **Deliberately not announced past this
## pill** -- no dimming, no forced ending, nothing that treats it as the
## board's business rather than the player's. Measured while the concept
## page was built (2026-09-20): in 450 careless games it never fired at all,
## and asking whether it *could* have (is_stuck(), two loops and no solver)
## put the true rate at 4%, 9% and 11% by band. That is common enough that
## silence would read as a bug, and rare enough that a modal or a forced
## Reset would be a bigger interruption than the problem deserves; a toast
## that fades on its own, over a board that is still there to look at and
## still has Undo above it, is the smaller intrusion.
##
## Pal.TEXT under Pal.PAPER text, cached by its own line the way
## puzzles/hidden_word2d.gd caches _toast_mesh / _toast_mesh_for, up for
## TOAST_HOLD and fading at both ends over Motion.DROP_FADE -- there is only
## the one line here, so this reaches for that recipe's own edge rather than
## adding a number for a second fade.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var font: Font = CozyTheme.body(600)
	var w: float = minf(size.x - 120.0,
		font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x + TOAST_PAD)
	if _toast_mesh == null or _toast_mesh_for != _toast:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -TOAST_H) * 0.5, Vector2(w, TOAST_H), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = _toast
	if _toast_mesh == null:
		return
	var mid := Vector2(size.x * 0.5, size.y - TOAST_MARGIN - TOAST_H * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, Vector2.ONE, 0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var where := Vector2(-w * 0.5 + TOAST_PAD * 0.5,
		font.get_height(TOAST_FONT) * 0.5 - font.get_descent(TOAST_FONT))
	draw_set_transform(mid, 0.0, Vector2.ONE)
	font.draw_string(get_canvas_item(), where, _toast, HORIZONTAL_ALIGNMENT_LEFT, -1,
		TOAST_FONT, Color(Pal.PAPER, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- the scenery band at the card's foot ---

## The band the two rows leave at the card's foot: a bank of moss washed
## toward paper, grass blades standing out of it and three bushes on the
## ground line -- Word Trail's precedent, appended to this board's own
## builder instead of a Scenery node, so it stays one draw call. Unlike a
## board whose field sits inset from the card's edges, this band is drawn
## flush with them (the concept tab's own `scenery()`), so every shape here
## is clipped to the card's own rounded rect or a corner would show past it.
func _build_band(b) -> void:
	if _row_y.is_empty():
		return
	var band_top: float = _row_y[1] + STATION_H
	var gy: float = size.y - INSET
	var h: float = gy - band_top
	if h < 40.0:
		return
	var w: float = size.x
	var clip := _clip_rect()

	var bank: Color = Pal.MOSS.lerp(Pal.PAPER, 0.38)
	_clip_polygon(b, Face.Builder.round_rect(Vector2(-40.0, gy - 38.0), Vector2(w + 80.0, 120.0), 40.0), bank, clip)

	for i in 24:
		var bx: float = fmod(float(i * 149 + 37), w)
		var bh: float = 20.0 + float((i * 53) % 16)
		var foot := Vector2(bx, gy - 32.0)
		var tip := Vector2(bx + 2.0, gy - 32.0 - bh)
		var far := Vector2(bx + 9.0, gy - 32.0)
		var pts := Face.Builder.bezier2(foot, Vector2(bx + 4.0, gy - 32.0 - bh * 0.6), tip, 8)
		pts.append_array(Face.Builder.bezier2(tip, Vector2(bx + 8.0, gy - 32.0 - bh * 0.5), far, 8))
		pts.append(far)
		_clip_polygon(b, pts, Pal.MOSS, clip)

	var deep: Color = Pal.LEAF.lerp(Pal.TEXT, 0.12)
	var lit: Color = Pal.LEAF_LIGHT
	var bushes := [[86.0, 32.0], [w - 96.0, 28.0], [w * 0.47, 23.0]]
	for bush in bushes:
		var bx: float = bush[0]
		var br: float = bush[1]
		_clip_polygon(b, Face.Builder.ring(Vector2(bx, gy - 40.0), br, br), deep, clip)
		_clip_polygon(b, Face.Builder.ring(Vector2(bx - br * 0.8, gy - 32.0), br * 0.7, br * 0.7), deep, clip)
		_clip_polygon(b, Face.Builder.ring(Vector2(bx + br * 0.8, gy - 32.0), br * 0.7, br * 0.7), deep, clip)
		_clip_polygon(b, Face.Builder.ring(Vector2(bx - br * 0.3, gy - 52.0), br * 0.28, br * 0.28), lit, clip)

## The card's own rounded rect, a couple of pixels inside its edge so a
## clipped shape never rides over the panel's own border.
func _clip_rect() -> PackedVector2Array:
	var pad := 2.0
	return Face.Builder.round_rect(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0, maxf(CARD_RADIUS - pad, 0.0))

## `points` cut to `clip`, as however many simple polygons the intersection
## takes.
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
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

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
	return {"faces": faces, "subtitle": "Every colour on a peg of its own."}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A ring drawn on its own, for the win screen's cast: the same face, rim,
## highlight, dimple and pips as a station's ring, scaled to whatever square
## seat well_done.gd hands it. Nothing is added to ui/faces/ for this -- spec
## section 6 -- so this stands alone rather than joining that family. Its own
## small copy of _append_ring's shapes rather than a call to it: a nested
## class cannot reach the outer script's static functions unqualified, only
## its preloaded consts (GDScript resolves `Face` and `Pal` outward, but not
## a sibling function), and holding a reference back just to call one
## function once is not worth the indirection.
class RingIcon extends Control:
	var ring_colour: Color = Color.WHITE
	var pips: int = 1
	## Set by ui/flat/well_done.gd's set_cast on every face it seats; a ring
	## has no expression of its own, but the property has to exist.
	var expression: int = 0
	## Kept past the frame that builds it -- a canvas command holds a mesh by
	## RID, not by reference, and a purely local one is freed the instant
	## _draw() returns, which the win screen's own force_draw() outlives on
	## an idle frame. Found by actually shooting a win (Task 5); Task 3/4
	## never had a caller that rendered this far.
	var _mesh: ArrayMesh

	## well_done.gd's enter() calls this on every face it seats
	## (ui/faces/face.gd's own contract); a ring has nothing to idle -- no
	## blink, no rock, no turn -- so this is a no-op that only has to exist.
	## Found the same way as the mesh fix above: the win screen had never
	## actually been rendered for this board before Task 5 shot one.
	func set_idle(_on: bool) -> void:
		pass

	func _draw() -> void:
		var ring_w := size.x * 0.88
		var ring_h := ring_w * (RING_H / RING_W)
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var b := Face.Builder.new()
		var face := ring_colour
		var rim := ring_colour.lerp(Pal.TEXT, 0.22)
		var edge := ring_h * (9.0 / 92.0)
		var at := Vector2(cx - ring_w * 0.5, cy - ring_h * 0.5)
		b.fan(Face.Builder.round_rect(at, Vector2(ring_w, ring_h), ring_h * 0.5), rim)
		b.fan(Face.Builder.round_rect(at, Vector2(ring_w, maxf(ring_h - edge, 0.0)), ring_h * 0.5), face)
		b.ellipse(Vector2(cx - ring_w * 0.22, cy - ring_h * 0.26), ring_w * 0.17, ring_h * 0.11,
			Color(Color.WHITE, 0.26))
		var dimple := face.lerp(Pal.TEXT, 0.30)
		var post_w := ring_w * (POST_W / RING_W)
		b.ellipse(Vector2(cx, cy - ring_h * 0.21), post_w * 0.56, ring_h * 0.10, Color(dimple, 0.32))
		var pip_col := Color(dimple, 0.70)
		var sp := ring_w * 0.098
		var x0 := -float(pips - 1) * sp * 0.5
		for p in pips:
			b.disc(Vector2(cx + x0 + float(p) * sp, cy + ring_h * 0.17), ring_h * 0.075, pip_col)
		_mesh = b.mesh()
		if _mesh != null:
			draw_mesh(_mesh, null)
