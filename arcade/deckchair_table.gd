extends Control

## Deckchair's table: the cloth, the fifty-two cards and the fingers on
## them. It draws arcade/deckchair_sim.gd and hands it the player's moves;
## the screen round it (arcade/deckchair_screen.gd) keeps the score, the
## cards over it and the sound, and the tutorial's pages
## (ui/hud/deckchair_tutorial_diagram.gd) are this table alone with a hand
## scripted on it.
##
## Top row: the four homes on the left, then the waste and the stock on the
## right. Under it the seven columns, each fanned down the cloth.
##
## Play: tap the stock to turn a card. Tap a card and it goes where it may
## (its home first, else a column); or carry it, with what lies on it, to
## the column or home it is wanted on. A carried card's places wear a ring.
##
## Drawing: every card is one cached mesh (its face less the rank, or the
## back) laid by the transform, and a face's rank is one text draw. A card
## eases from where it is drawn to where the sim has it, and turns over on
## the way.
##
## The moments (2026-10-10), none of them under reduce motion and none a draw
## call at rest: whatever lights is built into one mesh (`_over`) for as long
## as it shows, and everything else is the card's own transform.

signal said(cue: String, pitch: float)
signal played(ev: Dictionary)
## The player did something the sim took: the screen reads the sim again.
signal acted

const Sim = preload("res://arcade/deckchair_sim.gd")
const Art = preload("res://arcade/deckchair_art.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

const N := Sim.DECK
## How far a finger moves, in the table's own pixels, before a press is a
## carry and not a tap.
const CARRY_AFTER := 18.0
const EASE := 17.0
const FLIP_T := 0.2
const DEAL_GAP := 0.034
## How much of a card shows under the next: face down, and face up (enough
## for the rank and the small mark).
const FAN_DOWN := 0.12
const FAN_UP := 0.27
const HINT_T := 2.6
const POP_T := 0.8
## A ticking sound never plays the same twice (docs/agents/sound.md).
const VARY := 0.06
## A card in the air swells by `AIR` at the middle of its way; one set down
## swells by `LAND_BUMP` and settles, a king by `KING_BUMP`, the card it was
## laid on by `ANSWER_BUMP`; the cards of a run settle one after another.
const AIR := 0.1
const LAND_BUMP := 0.07
const KING_BUMP := 0.13
const ANSWER_BUMP := 0.04
## A card home: its suit's light spreads from it and motes of it drift off
## for `HOME_TIME`, its mark swelling by `HOME_POP`; an ace, and a king that
## ends its suit or takes an empty column, is framed in brass (`CROWN_TIME`
## for the king home). A card turned up is met by the lamp's light.
const HOME_TIME := 0.7
const HOME_POP := 0.34
const HOME_POP_TIME := 0.34
const HOME_MOTES := 5
const CROWN_TIME := 1.0
const CROWN_MOTES := 9
const TURN_GLOW := 0.5
const SEAM_TIME := 0.4
const LIGHTS_MOST := 8
## The pack is tapped square before a deal (`DEAL_HOLD` s); the waste goes
## back to the stock a card at a time, all of it within `RECYCLE_T`.
const DEAL_HOLD := 0.3
const RECYCLE_T := 0.3
## A dead end: the columns sink by `SIGH` and come back. A deal won: the
## four kings hop one after another every `WIN_EVERY` s for `WIN_GLOW` s,
## their homes lit. The bulb's card hops every `HINT_EVERY` s.
const SIGH := 5.0
const SIGH_TIME := 0.55
const WIN_HOP := -14.0
const WIN_EVERY := 0.8
const WIN_STEP := 0.09
const WIN_GLOW := 2.6
const HINT_EVERY := 0.85
## Carried cards stand `CARRY_SWELL` larger and lean into the way they are
## taken, at most `LEAN_MOST` radians. The lemonade ripples for `RIPPLE_T`
## when a king is set down.
const CARRY_SWELL := 0.05
const LEAN_MOST := 0.11
const RIPPLE_T := 0.9
## What a card's landing means.
enum Mark { NONE, HOME, ACE, SUIT, KING, RUN, TURN }

var sim: RefCounted
var interactive := true
## How many cards' height a short table keeps room for (a tutorial page
## fans three or four cards and asks for less).
var tall_room := 3.1
## Where the card is drawn and where the sim has it.
var _at := PackedVector2Array()
var _to := PackedVector2Array()
## The side showing and the side wanted (1 the face).
var _up := PackedByteArray()
var _want := PackedByteArray()
## A turn under way, 0 to 1; under 0 for none.
var _flip := PackedFloat32Array()
var _delay := PackedFloat32Array()
var _shake := PackedFloat32Array()
## Whether a card at rest needs drawing at all: most of a pile is hidden.
var _vis := PackedByteArray()
## The cards from the cloth up: the stock, the waste, the homes, the columns.
var _order := PackedInt32Array()
var _w := 100.0
var _h := 142.0
var _gap := 12.0
var _left := 0.0
var _top := 0.0
var _row := 0.0
var _cloth: ArrayMesh
var _slots: ArrayMesh
var _down := false
var _press_at := Vector2.ZERO
var _press_card := -1
var _press_stock := false
## The cards under the finger, the head first, and the places they may go.
var _carry: Array = []
var _carry_off := Vector2.ZERO
var _targets: Array = []
var _hint: Dictionary = {}
var _hint_t := 0.0
var _pops: Array = []
var _clock := 0.0
## How far a card on its way set out to go (0 for none), what its landing
## means, how long after it the swell begins (a run's cards), the card its
## run was laid on (-1), when it last landed and by how much it swells.
var _span := PackedFloat32Array()
var _meant := PackedByteArray()
var _lag := PackedFloat32Array()
var _onto := PackedInt32Array()
var _land_at := PackedFloat32Array()
var _land_amt := PackedFloat32Array()
## Whether the card lies in a column (the sigh is the columns').
var _in_col := PackedByteArray()
## What is alight: {kind, at (the card's corner), t, dur, col, suit}.
var _lights: Array = []
var _over: ArrayMesh
var _deal_at := -10.0
var _sigh_at := -10.0
var _won_at := -10.0
var _ripple_at := -10.0
var _lift_at := -10.0
var _lean := 0.0
var _lean_to := 0.0
var _drag_x := 0.0
var _held_at := -10.0
var _let_at := -10.0
var _held_card := -1

func _init() -> void:
	_at.resize(N)
	_to.resize(N)
	_up.resize(N)
	_want.resize(N)
	_flip.resize(N)
	_delay.resize(N)
	_shake.resize(N)
	_vis.resize(N)
	_flip.fill(-1.0)
	_span.resize(N)
	_meant.resize(N)
	_lag.resize(N)
	_onto.resize(N)
	_land_at.resize(N)
	_land_amt.resize(N)
	_in_col.resize(N)
	_land_at.fill(-10.0)
	_onto.fill(-1)

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout()

# --- where things are ---

func _layout() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_gap = s.x * 0.014
	_w = (s.x - _gap * 8.0) / 7.0
	# a short table (a tutorial page) takes smaller cards, so a column still
	# has room to fan
	_w = minf(_w, (s.y - _gap * 4.0) / (Art.TALL * tall_room))
	_h = _w * Art.TALL
	_left = (s.x - _w * 7.0 - _gap * 6.0) * 0.5
	_top = _gap * 1.5
	_row = _top + _h + _gap * 2.2
	_cloth = Art.cloth(s, _w, _row, glass_at(), _glass_r())
	var b := Face.Builder.new()
	for suit in Sim.SUITS:
		Art.slot_into(b, home_at(suit), _w, suit)
	Art.slot_into(b, stock_at(), _w, -1, true)
	for c in Sim.COLS:
		Art.slot_into(b, Vector2(col_x(c), _row), _w)
	_slots = b.mesh()
	_sync(true)
	queue_redraw()

func col_x(c: int) -> float:
	return _left + c * (_w + _gap)

func home_at(suit: int) -> Vector2:
	return Vector2(col_x(suit), _top)

func waste_at() -> Vector2:
	return Vector2(col_x(5), _top)

func stock_at() -> Vector2:
	return Vector2(col_x(6), _top)

func card_size() -> Vector2:
	return Vector2(_w, _h)

## The glass stands in the top row's one empty place, left of where the
## waste fans to.
func glass_at() -> Vector2:
	return Vector2(col_x(4) + 0.33 * _w, _top + 0.56 * _h)

func _glass_r() -> float:
	return 0.31 * _w

## Where a card lies, its top left corner (for the tutorial's finger and the
## screen's bursts).
func card_at(card: int) -> Vector2:
	return _to[card]

## Where the next card set on a column would lie.
func col_next(c: int) -> Vector2:
	var pile: Array = sim.cols[c]
	if pile.is_empty():
		return Vector2(col_x(c), _row)
	return _to[int(pile[pile.size() - 1])] + Vector2(0, _fan(c) * FAN_UP * _h)

## A column's fan closes up when it would run off the cloth.
func _fan(c: int) -> float:
	var pile: Array = sim.cols[c]
	var d: int = sim.down[c]
	var run := d * FAN_DOWN + maxi(pile.size() - d - 1, 0) * FAN_UP
	var room := (size.y - _row - _gap) / _h - 1.0
	return 1.0 if run <= room or run <= 0.0 else maxf(room / run, 0.3)

## Reads the sim: where every card belongs and which side it shows. `snap`
## puts them there at once.
func _sync(snap := false) -> void:
	if sim == null or _w <= 0.0:
		return
	_order.clear()
	_in_col.fill(0)
	var n: int = sim.stock.size()
	for i in n:
		var card: int = sim.stock[i]
		_to[card] = stock_at() - Vector2(0, mini(i, 2) * 0.022 * _w)
		_want[card] = 0
		_vis[card] = 1 if i < 2 or i == n - 1 else 0
		_order.append(card)
	n = sim.waste.size()
	var spread := mini(n - 1, 2)
	for i in n:
		var card: int = sim.waste[i]
		var f := maxi(0, i - (n - 1 - spread))
		_to[card] = waste_at() - Vector2((spread - f) * 0.22 * _w, 0)
		_want[card] = 1
		_vis[card] = 1 if i >= n - 3 else 0
		_order.append(card)
	for suit in Sim.SUITS:
		var top: int = sim.home[suit]
		for r in top:
			var card := suit * Sim.RANKS + r
			_to[card] = home_at(suit)
			_want[card] = 1
			_vis[card] = 1 if r >= top - 2 else 0
			_order.append(card)
	for c in Sim.COLS:
		var pile: Array = sim.cols[c]
		var d: int = sim.down[c]
		var k := _fan(c)
		var y := _row
		for i in pile.size():
			var card: int = pile[i]
			_to[card] = Vector2(col_x(c), y)
			_want[card] = 1 if i >= d else 0
			_vis[card] = 1
			_in_col[card] = 1
			_order.append(card)
			y += (FAN_UP if i >= d else FAN_DOWN) * k * _h
	if snap or Motion.reduce:
		for card in N:
			if not _carry.has(card):
				_at[card] = _to[card]
			_up[card] = _want[card]
			_flip[card] = -1.0
			_delay[card] = 0.0
		_still()

## Nothing of a moment is left: the cards lie as they lie.
func _still() -> void:
	_span.fill(0.0)
	_meant.fill(Mark.NONE)
	_lag.fill(0.0)
	_onto.fill(-1)
	_land_at.fill(-10.0)
	_lights.clear()
	_sigh_at = -10.0
	_won_at = -10.0
	_ripple_at = -10.0
	_deal_at = -10.0

# --- the sim's events ---

## Takes in what the sim did: the sounds, the points lettered where they
## were made, and every card sent to its new place.
func play_events() -> void:
	if sim == null:
		return
	var evs: Array = sim.events.duplicate()
	sim.events.clear()
	for ev: Dictionary in evs:
		match String(ev.type):
			"deal":
				_deal_in()
			"move":
				if (ev.to as Vector2i).x == Sim.At.HOME:
					said.emit("home", 1.0 + 0.012 * mini(Sim.rank_of(int((ev.cards as Array)[0])), 12))
				else:
					said.emit("place", randf_range(1.0 - VARY, 1.0 + VARY))
			"flip":
				said.emit("flip", randf_range(1.0 - VARY, 1.0 + VARY))
			"draw":
				said.emit("draw", randf_range(1.0 - VARY, 1.0 + VARY))
			"recycle":
				said.emit("recycle", 1.0)
			"undo":
				said.emit("undo", randf_range(1.0 - VARY, 1.0 + VARY))
	_sync()
	_mark(evs)
	# points are lettered over where the card ends up, known only now
	for ev: Dictionary in evs:
		match String(ev.type):
			"move":
				_pop(int(ev.gain), _to[int((ev.cards as Array)[0])])
			"flip":
				_pop(int(ev.gain), _to[int(ev.card)])
		played.emit(ev)
	if not evs.is_empty():
		_hint = {}
		acted.emit()
	queue_redraw()

## What the sim's moves will look like when their cards get there: each
## card that sets out is given its way's length and what its landing means.
func _mark(evs: Array) -> void:
	if Motion.reduce:
		return
	for ev: Dictionary in evs:
		match String(ev.type):
			"undo", "deal":
				_meant.fill(Mark.NONE)
				_lag.fill(0.0)
				_lights.clear()
				_won_at = -10.0
				_sigh_at = -10.0
			"move":
				var cards: Array = ev.cards
				var head: int = cards[0]
				var to: Vector2i = ev.to
				_onto[head] = -1
				if to.x == Sim.At.HOME:
					var rank := Sim.rank_of(head)
					_meant[head] = Mark.SUIT if rank == Sim.KING else (Mark.ACE if rank == 0 else Mark.HOME)
				else:
					var pile: Array = sim.cols[to.y]
					var under := pile.find(head) - 1
					if under >= 0:
						_meant[head] = Mark.RUN
						_onto[head] = int(pile[under])
					else:
						_meant[head] = Mark.KING if Sim.rank_of(head) == Sim.KING else Mark.RUN
				for i in cards.size():
					_lag[int(cards[i])] = i * Motion.WAVE_STEP
			"flip":
				_meant[int(ev.card)] = Mark.TURN
			"recycle":
				# the waste goes back a card at a time, the one on top first
				var n: int = sim.stock.size()
				var gap := minf(0.022, RECYCLE_T / maxf(n, 1.0))
				for i in n:
					_delay[int(sim.stock[i])] = i * gap
			"stuck":
				_sigh_at = _clock + 0.12
			"win":
				_won_at = _clock
				_sigh_at = -10.0
	for card in N:
		if _carry.has(card):
			continue
		var d := _to[card].distance_to(_at[card])
		if d > _w * 0.6:
			_span[card] = d

## A card has got where it was going.
func _arrive(card: int) -> void:
	var meant := _meant[card]
	if _span[card] <= 0.0 and (meant == Mark.NONE or meant == Mark.TURN):
		return
	_span[card] = 0.0
	if Motion.reduce:
		_meant[card] = Mark.NONE
		return
	_land_at[card] = _clock + _lag[card]
	_land_amt[card] = LAND_BUMP
	_lag[card] = 0.0
	if meant == Mark.TURN:
		return
	_meant[card] = Mark.NONE
	var suit := Sim.suit_of(card)
	var col: Color = Art.LIGHT_RED if Sim.is_red(card) else Art.LIGHT_BLACK
	match meant:
		Mark.HOME:
			_light("home", _to[card], HOME_TIME, col, suit)
		Mark.ACE:
			_light("ace", _to[card], HOME_TIME, col, suit)
		Mark.SUIT:
			_land_amt[card] = KING_BUMP
			_light("suit", _to[card], CROWN_TIME, col, suit)
			_ripple_at = _clock
		Mark.KING:
			_land_amt[card] = KING_BUMP
			_light("king", _to[card], HOME_TIME, col, suit)
			_ripple_at = _clock
		Mark.RUN:
			var onto := _onto[card]
			if onto >= 0:
				_land_at[onto] = _clock
				_land_amt[onto] = ANSWER_BUMP
				_light("seam", _to[card], SEAM_TIME, Art.GLOW, suit)
	_onto[card] = -1

func _light(kind: String, at: Vector2, dur: float, col: Color, suit: int) -> void:
	if _lights.size() >= LIGHTS_MOST:
		_lights.pop_front()
	_lights.append({"kind": kind, "at": at, "t": 0.0, "dur": dur, "col": col, "suit": suit, "turn": randf() * TAU})

## Every card back in the stock's place and dealt out a row at a time, the
## pack tapped square first.
func _deal_in() -> void:
	_sync(true)
	if Motion.reduce:
		return
	_deal_at = _clock
	var k := 0
	for row in Sim.COLS:
		for c in range(row, Sim.COLS):
			var pile: Array = sim.cols[c]
			if row >= pile.size():
				continue
			var card: int = pile[row]
			_at[card] = stock_at()
			_up[card] = 0
			_delay[card] = DEAL_HOLD + k * DEAL_GAP
			k += 1

func _pop(gain: int, at: Vector2) -> void:
	if gain == 0 or Motion.reduce:
		return
	if _pops.size() >= 6:
		_pops.pop_front()
	_pops.append({"text": ("+%d" % gain) if gain > 0 else str(gain), "at": at + Vector2(_w * 0.5, -_w * 0.1), "t": 0.0, "good": gain > 0})

## Rings a way on: a card and where it goes, or the stock.
func show_hint(m: Dictionary) -> void:
	_hint = m
	_hint_t = HINT_T

# --- the fingers ---

func _gui_input(event: InputEvent) -> void:
	if not interactive or sim == null:
		return
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		accept_event()
		if event.pressed:
			press(event.position)
		else:
			release(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			press(event.position)
		else:
			release(event.position)
	elif event is InputEventScreenDrag:
		if event.index == 0 and _down:
			accept_event()
			drag(event.position)
	elif event is InputEventMouseMotion:
		if _down and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			accept_event()
			drag(event.position)

func press(at: Vector2) -> void:
	_down = true
	_press_at = at
	_carry = []
	_press_stock = Rect2(stock_at(), card_size()).grow(_gap * 0.5).has_point(at)
	_press_card = -1 if _press_stock else _card_under(at)
	# what is pressed sinks under the finger: a card, or the stock's top
	_held_card = _press_card
	if _press_stock and not sim.stock.is_empty():
		_held_card = int(sim.stock[sim.stock.size() - 1])
	_held_at = _clock
	_let_at = -10.0

func drag(at: Vector2) -> void:
	if not _down:
		return
	if _carry.is_empty():
		if _press_card < 0 or at.distance_to(_press_at) < CARRY_AFTER or not sim.movable(_press_card):
			return
		_carry = sim.run_of(_press_card)
		_carry_off = _at[_press_card] - _press_at
		_targets = []
		for suit in Sim.SUITS:
			if sim.can_drop(_press_card, Sim.At.HOME, suit):
				_targets.append(Vector2i(Sim.At.HOME, suit))
		for c in Sim.COLS:
			if sim.can_drop(_press_card, Sim.At.COL, c):
				_targets.append(Vector2i(Sim.At.COL, c))
		_hint = {}
		_lift_at = _clock
		_drag_x = at.x
		_lean = 0.0
		_held_card = -1
		said.emit("lift", randf_range(1.0 - VARY, 1.0 + VARY))
	# carried cards lean into the way they are taken
	_lean_to = clampf((at.x - _drag_x) / maxf(_w, 1.0) * 0.5, -LEAN_MOST, LEAN_MOST)
	_drag_x = at.x
	var head := at + _carry_off - Vector2(0, 0.08 * _w)
	var k: float = _fan(sim.where(_press_card).y) if sim.where(_press_card).x == Sim.At.COL else 1.0
	for i in _carry.size():
		_at[int(_carry[i])] = head + Vector2(0, i * FAN_UP * k * _h)
	queue_redraw()

func release(at: Vector2) -> void:
	if not _down:
		return
	_down = false
	_let_at = _clock
	if not _carry.is_empty():
		_set_down()
	elif _press_stock:
		if Rect2(stock_at(), card_size()).grow(_gap * 0.5).has_point(at):
			tap_stock()
	elif _press_card >= 0 and _card_under(at) == _press_card:
		tap(_press_card)
	_press_card = -1
	queue_redraw()

## The stock tapped: a card turned, or the waste taken back.
func tap_stock() -> void:
	if sim.draw():
		play_events()

## A card tapped: it goes where it may, or shakes its head.
func tap(card: int) -> void:
	if not sim.movable(card):
		return
	var dst: Vector2i = sim.auto_dst(card)
	if dst.x < 0:
		_refuse(card)
		return
	sim.drop(card, dst.x, dst.y)
	play_events()

## The carried cards let go: onto the place they cover most of, if it is one
## of theirs; over a place that is not, a shake; else back where they lay,
## set down a little lower.
func _set_down() -> void:
	var head: int = _carry[0]
	var mine := Rect2(_at[head], card_size())
	var best := Vector2i(-1, -1)
	var most := 0.0
	var wrong := false
	var from: Vector3i = sim.where(head)
	for suit in Sim.SUITS:
		var over := _overlap(mine, Rect2(home_at(suit), card_size()))
		if over <= 0.0:
			continue
		if _targets.has(Vector2i(Sim.At.HOME, suit)):
			if over > most:
				most = over
				best = Vector2i(Sim.At.HOME, suit)
		elif not (from.x == Sim.At.HOME and from.y == suit):
			wrong = true
	for c in Sim.COLS:
		var top := col_next(c) if not (from.x == Sim.At.COL and from.y == c) else Vector2(col_x(c), _row)
		var over := _overlap(mine, Rect2(Vector2(col_x(c), _row), Vector2(_w, maxf(top.y - _row, 0.0) + _h)))
		if over <= 0.0:
			continue
		if _targets.has(Vector2i(Sim.At.COL, c)):
			if over > most:
				most = over
				best = Vector2i(Sim.At.COL, c)
		elif not (from.x == Sim.At.COL and from.y == c):
			wrong = true
	_carry = []
	_targets = []
	if best.x >= 0:
		sim.drop(head, best.x, best.y)
		play_events()
	elif wrong:
		_refuse(head)
	else:
		said.emit("place", 0.84)

static func _overlap(a: Rect2, b: Rect2) -> float:
	var i := a.intersection(b)
	return i.size.x * i.size.y if i.size.x > 0.0 and i.size.y > 0.0 else 0.0

func _refuse(card: int) -> void:
	for c: int in sim.run_of(card):
		_shake[c] = 1.0
	said.emit("nope", 1.0)

## The card a point is on: the nearest the eye of whatever lies there.
func _card_under(at: Vector2) -> int:
	var sz := card_size()
	for c in Sim.COLS:
		var pile: Array = sim.cols[c]
		for i in range(pile.size() - 1, -1, -1):
			if Rect2(_to[int(pile[i])], sz).has_point(at):
				return int(pile[i])
	if not sim.waste.is_empty():
		var top: int = sim.waste[sim.waste.size() - 1]
		if Rect2(_to[top], sz).has_point(at):
			return top
	for suit in Sim.SUITS:
		if int(sim.home[suit]) > 0 and Rect2(home_at(suit), sz).has_point(at):
			return suit * Sim.RANKS + int(sim.home[suit]) - 1
	return -1

# --- every frame ---

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	_hint_t = maxf(0.0, _hint_t - delta)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p.t) < POP_T)
	if not _lights.is_empty():
		for l: Dictionary in _lights:
			l.t += delta
		_lights = _lights.filter(func(l: Dictionary) -> bool: return float(l.t) < float(l.dur))
	_lean = lerpf(_lean, _lean_to, 1.0 - exp(-delta * 14.0))
	_lean_to = lerpf(_lean_to, 0.0, 1.0 - exp(-delta * 9.0))
	var k := 1.0 - exp(-delta * EASE)
	for card in N:
		if _shake[card] > 0.0:
			_shake[card] = maxf(0.0, _shake[card] - delta * 3.2)
		if _carry.has(card):
			continue
		if _delay[card] > 0.0:
			_delay[card] -= delta
			continue
		var d := _to[card] - _at[card]
		if d.length_squared() < 0.3:
			_at[card] = _to[card]
			if _span[card] > 0.0 or _meant[card] != Mark.NONE:
				_arrive(card)
		else:
			_at[card] += d * k
		if _flip[card] >= 0.0:
			_flip[card] += delta / FLIP_T
			if _flip[card] >= 0.5:
				if _up[card] != _want[card] and _meant[card] == Mark.TURN:
					_meant[card] = Mark.NONE
					_light("turn", _to[card], TURN_GLOW, Art.GLOW, Sim.suit_of(card))
				_up[card] = _want[card]
			if _flip[card] >= 1.0:
				_flip[card] = -1.0
		elif _up[card] != _want[card] and d.length() < _w * 0.7:
			_flip[card] = 0.0
	queue_redraw()

## Nothing is on its way anywhere: the screen waits on this before a card
## goes over the table.
func settled() -> bool:
	for card in N:
		if _delay[card] > 0.0 or _flip[card] >= 0.0 or _at[card] != _to[card]:
			return false
	return true

func _resting(card: int) -> bool:
	return _delay[card] <= 0.0 and _flip[card] < 0.0 and _at[card] == _to[card] and _shake[card] <= 0.0

func _draw() -> void:
	if _cloth == null:
		return
	draw_mesh(_cloth, null)
	draw_mesh(_slots, null)
	if sim == null:
		return
	var font := CozyTheme.display(700)
	var late := PackedInt32Array()
	for card: int in _order:
		if _carry.has(card):
			continue
		if not _resting(card):
			late.append(card)
		elif _vis[card] == 1:
			_draw_card(font, card, _at[card])
	for card: int in late:
		_draw_card(font, card, _at[card])
	draw_set_transform(Vector2.ZERO)
	# the mesh a draw was handed is kept until the next replaces it
	var over := _build_over()
	if over != null:
		_over = over
		draw_mesh(_over, null)
	_draw_rings()
	if not _carry.is_empty():
		# the lot leans about the head card's top, and stands a little larger
		var head := _at[int(_carry[0])]
		var grow := 1.0
		var lean := 0.0
		if not Motion.reduce:
			grow = 1.0 + CARRY_SWELL * sin(clampf((_clock - _lift_at) / Motion.LIFT_TIME, 0.0, 1.0) * PI * 0.5)
			lean = _lean
		var pivot := head + Vector2(_w * 0.5, _h * 0.3)
		var base := Transform2D(lean, Vector2(grow, grow), 0.0, pivot) * Transform2D(0.0, -pivot)
		for i in _carry.size():
			draw_set_transform_matrix(base * Transform2D(0.0, _at[int(_carry[i])] + Vector2(0.05, 0.09) * _w))
			draw_mesh(Art.shadow(_w), null)
		for card: int in _carry:
			_draw_card(font, card, _at[card], base)
	draw_set_transform(Vector2.ZERO)
	_draw_pops(font)

## How far a card stands off its place: the kings' hop on a deal won, the
## bulb's card beckoning, the columns' sigh at a dead end.
func _lift_of(card: int) -> float:
	var lift := 0.0
	if _won_at > -1.0 and Sim.rank_of(card) == Sim.KING:
		var t := _clock - _won_at - 0.15 - Sim.suit_of(card) * WIN_STEP
		if t > 0.0 and t < WIN_GLOW:
			lift += Motion.hop_lift(fposmod(t, WIN_EVERY), WIN_HOP, Motion.SOLVE_TIME)
	if _hint_t > 0.0 and _hint.has("card") and int(_hint.card) == card:
		lift += Motion.hop_lift(fposmod(HINT_T - _hint_t, HINT_EVERY), Motion.HOP)
	if _in_col[card] == 1 and _sigh_at > -1.0:
		lift += Motion.hop_lift(_clock - _sigh_at, SIGH, SIGH_TIME)
	return lift

func _draw_card(font: Font, card: int, pos: Vector2, base := Transform2D.IDENTITY) -> void:
	var sx := 1.0
	var grow := 1.0
	var turn := 0.0
	if _flip[card] >= 0.0:
		sx = maxf(absf(cos(PI * _flip[card])), 0.03)
	if _shake[card] > 0.0 and not Motion.reduce:
		pos.x += sin(_shake[card] * 26.0) * 0.07 * _w * _shake[card]
	if not Motion.reduce:
		pos.y += _lift_of(card)
		if _flip[card] >= 0.0:
			grow *= 1.0 + 0.08 * sin(PI * _flip[card])
		if _span[card] > 0.0 and _delay[card] <= 0.0:
			grow *= 1.0 + AIR * sin(PI * clampf(1.0 - _at[card].distance_to(_to[card]) / _span[card], 0.0, 1.0))
		grow *= Motion.bump_scale(_clock - _land_at[card], _land_amt[card])
		if card == _held_card:
			grow *= Motion.press_scale(_clock - _held_at, _clock - _let_at if _let_at > -1.0 else -1.0)
		# the pack is tapped square before it is dealt
		if _deal_at > -1.0 and (_delay[card] > 0.0 or (_in_col[card] == 0 and _want[card] == 0)):
			turn = Motion.wobble_angle(_clock - _deal_at, Motion.WOBBLE_ANGLE * 0.6)
	var mid := Vector2(_w, _h) * 0.5
	var m := Transform2D(turn, Vector2(sx * grow, grow), 0.0, Vector2.ZERO)
	m.origin = pos + mid - m.basis_xform(mid)
	draw_set_transform_matrix(base * m)
	if _up[card] == 0:
		draw_mesh(Art.back(_w), null)
		return
	draw_mesh(Art.face(Sim.suit_of(card), _w), null)
	var text: String = Art.RANKS[Sim.rank_of(card)]
	var wide := text.length() > 1
	var fs := int(_w * (0.27 if wide else 0.31))
	draw_string(font, Vector2((0.07 if wide else 0.11) * _w, 0.325 * _w), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.ink(card))

## What is alight over the cards, or nothing: a card home in its suit's
## light, the brass round an ace and a king, the lamp on a card turned up
## and on a run's seam, the four homes of a deal won, the lemonade's ripple.
## Light is soft and round, never a ray.
func _build_over() -> ArrayMesh:
	if Motion.reduce:
		return null
	var won := _clock - _won_at
	var ripple := _clock - _ripple_at
	if _lights.is_empty() and (won < 0.0 or won >= WIN_GLOW) and (ripple < 0.0 or ripple >= RIPPLE_T):
		return null
	var b := Face.Builder.new()
	var mid := Vector2(_w, _h) * 0.5
	for l: Dictionary in _lights:
		var u: float = float(l.t) / float(l.dur)
		var out := 1.0 - (1.0 - u) * (1.0 - u)
		var c: Vector2 = Vector2(l.at) + mid
		var col: Color = l.col
		var kind: String = l.kind
		if kind == "seam":
			Scenery.soft_disc(b, Vector2(l.at) + Vector2(_w * 0.5, 0.0), _w * (0.75 + 0.45 * out), _h * (0.2 + 0.14 * out), Color(col, 0.7 * (1.0 - u)))
			continue
		if kind == "turn":
			var glow := _w * (0.85 + 0.6 * out)
			Scenery.soft_disc(b, c, glow, glow * 1.2, Color(col, 0.5 * (1.0 - u)))
			_motes(b, c, 4, float(l.turn), _w * (0.6 + 0.5 * out), u, col, 0.15 * _w)
			continue
		var crown := kind == "suit"
		var reach := _w * ((1.1 if crown else 0.9) + 0.8 * out)
		Scenery.soft_disc(b, c, reach, reach, Color(col, 0.6 * (1.0 - u)))
		if kind != "home":
			Art.frame_into(b, l.at, _w, (0.03 + (0.2 if crown else 0.13) * out) * _w, 0.055 * _w, Color(Art.BRASS, 0.95 * (1.0 - u)))
		if crown:
			Art.frame_into(b, l.at, _w, (0.03 + 0.42 * out) * _w, 0.035 * _w, Color(Art.BRASS, 0.6 * (1.0 - u)))
		_motes(b, c, CROWN_MOTES if crown else HOME_MOTES, float(l.turn), _w * (0.55 + (1.3 if crown else 0.8) * out), u, col, 0.19 * _w)
		if kind != "king":
			# the mark of the card that came home swells over it
			var pop := Motion.bump_scale(float(l.t), HOME_POP, HOME_POP_TIME)
			if pop > 1.0:
				Art.pip(b, int(l.suit), Vector2(l.at) + Vector2(0.5, 0.9) * _w, 0.27 * _w * pop, Art.RED if int(l.suit) % 2 == 1 else Art.BLACK)
	if won >= 0.0 and won < WIN_GLOW:
		# the four homes breathe brass, and motes of it drift down the cloth
		var fade := minf(1.0, won / 0.3) * minf(1.0, (WIN_GLOW - won) / 0.5)
		for suit in Sim.SUITS:
			var c := home_at(suit) + mid
			var beat := 0.75 + 0.25 * sin(won * 5.0 - suit * 0.9)
			Scenery.soft_disc(b, c, _w * 1.05 * beat, _h * 0.95 * beat, Color(Art.HALO, 0.32 * fade))
			Art.frame_into(b, home_at(suit), _w, 0.05 * _w * beat, 0.05 * _w, Color(Art.BRASS, 0.9 * fade))
			for i in 3:
				var u := fposmod(won * 0.55 + i / 3.0 + suit * 0.21, 1.0)
				var at := c + Vector2(sin(won * 1.3 + i * 2.1 + suit) * 0.35 * _w, _h * (0.55 + 1.5 * u))
				var r := _w * 0.15 * (1.0 - 0.4 * u)
				Scenery.soft_disc(b, at, r, r, Color(Art.HALO, 0.9 * sin(PI * u) * fade))
				Scenery.soft_disc(b, at, r * 0.5, r * 0.5, Color(Art.LAMP, sin(PI * u) * fade))
	if ripple >= 0.0 and ripple < RIPPLE_T:
		var g := _glass_r() * 0.56
		for i in 2:
			var u := clampf(ripple / RIPPLE_T - i * 0.25, 0.0, 1.0)
			if u > 0.0 and u < 1.0:
				b.stroke(Face.Builder.ring(glass_at(), g * (0.2 + 0.75 * u), g * (0.2 + 0.75 * u)), maxf(1.0, 0.02 * _w), Color(1, 1, 1, 0.8 * (1.0 - u)), true)
	return b.mesh()

## Soft motes drifting off a middle, `n` of them `reach` out and a little up.
func _motes(b: Face.Builder, c: Vector2, n: int, turn: float, reach: float, u: float, col: Color, r: float) -> void:
	for i in n:
		var a := TAU * i / n + turn
		var at := c + Vector2(cos(a), sin(a) * 0.85) * reach + Vector2(0.0, -0.12 * _w * u)
		var rr := r * (1.0 - 0.5 * u)
		Scenery.soft_disc(b, at, rr, rr, Color(col.lightened(0.3), 1.0 - u))
		Scenery.soft_disc(b, at, rr * 0.5, rr * 0.5, Color(Art.LAMP, 1.0 - u))

## The rings: where the carried cards may go, and the hint's two.
func _draw_rings() -> void:
	var beat := 1.0 if Motion.reduce else 0.72 + 0.28 * sin(_clock * 7.0)
	var ring := Art.halo(_w)
	draw_set_transform(Vector2.ZERO)
	for tg: Vector2i in _targets:
		draw_mesh(ring, null, Transform2D(0.0, _place(tg)), Color(1, 1, 1, beat))
	if _hint.is_empty() or _hint_t <= 0.0:
		return
	var a := beat * minf(1.0, _hint_t / 0.3)
	if _hint.has("draw"):
		draw_mesh(ring, null, Transform2D(0.0, stock_at()), Color(1, 1, 1, a))
		return
	draw_mesh(ring, null, Transform2D(0.0, _to[int(_hint.card)]), Color(1, 1, 1, a))
	draw_mesh(ring, null, Transform2D(0.0, _place(Vector2i(int(_hint.kind), int(_hint.i)))), Color(1, 1, 1, a * 0.8))

## A place's top card, where a ring goes round it.
func _place(tg: Vector2i) -> Vector2:
	if tg.x == Sim.At.HOME:
		return home_at(tg.y)
	var pile: Array = sim.cols[tg.y]
	return Vector2(col_x(tg.y), _row) if pile.is_empty() else _to[int(pile[pile.size() - 1])]

func _draw_pops(font: Font) -> void:
	var fs := int(_w * 0.3)
	for p: Dictionary in _pops:
		var k: float = float(p.t) / POP_T
		var at: Vector2 = p.at + Vector2(0, -0.5 * _w * (1.0 - pow(1.0 - k, 2.0)))
		var a := 1.0 - k * k
		var text: String = p.text
		var half := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
		draw_string_outline(font, at - Vector2(half, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.3), Color(Art.CARD, a))
		draw_string(font, at - Vector2(half, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Art.STRIPE_DEEP if p.good else Art.RED, a))
