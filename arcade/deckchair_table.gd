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

signal said(cue: String, pitch: float)
signal played(ev: Dictionary)
## The player did something the sim took: the screen reads the sim again.
signal acted

const Sim = preload("res://arcade/deckchair_sim.gd")
const Art = preload("res://arcade/deckchair_art.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
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
	_cloth = Art.cloth(s)
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
			_order.append(card)
			y += (FAN_UP if i >= d else FAN_DOWN) * k * _h
	if snap or Motion.reduce:
		for card in N:
			if not _carry.has(card):
				_at[card] = _to[card]
			_up[card] = _want[card]
			_flip[card] = -1.0
			_delay[card] = 0.0

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

## Every card back in the stock's place and dealt out a row at a time.
func _deal_in() -> void:
	_sync(true)
	if Motion.reduce:
		return
	var k := 0
	for row in Sim.COLS:
		for c in range(row, Sim.COLS):
			var pile: Array = sim.cols[c]
			if row >= pile.size():
				continue
			var card: int = pile[row]
			_at[card] = stock_at()
			_up[card] = 0
			_delay[card] = k * DEAL_GAP
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
		said.emit("lift", randf_range(1.0 - VARY, 1.0 + VARY))
	var head := at + _carry_off - Vector2(0, 0.08 * _w)
	var k: float = _fan(sim.where(_press_card).y) if sim.where(_press_card).x == Sim.At.COL else 1.0
	for i in _carry.size():
		_at[int(_carry[i])] = head + Vector2(0, i * FAN_UP * k * _h)
	queue_redraw()

func release(at: Vector2) -> void:
	if not _down:
		return
	_down = false
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
## of theirs; over a place that is not, a shake; else back without a word.
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
		else:
			_at[card] += d * k
		if _flip[card] >= 0.0:
			_flip[card] += delta / FLIP_T
			if _flip[card] >= 0.5:
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
	_draw_rings()
	if not _carry.is_empty():
		draw_set_transform(_at[int(_carry[0])] + Vector2(0.05, 0.09) * _w)
		for i in _carry.size():
			draw_mesh(Art.shadow(_w), null, Transform2D(0.0, _at[int(_carry[i])] - _at[int(_carry[0])]))
		for card: int in _carry:
			_draw_card(font, card, _at[card])
	draw_set_transform(Vector2.ZERO)
	_draw_pops(font)

func _draw_card(font: Font, card: int, pos: Vector2) -> void:
	var sx := 1.0
	if _flip[card] >= 0.0:
		sx = maxf(absf(cos(PI * _flip[card])), 0.03)
	if _shake[card] > 0.0 and not Motion.reduce:
		pos.x += sin(_shake[card] * 26.0) * 0.07 * _w * _shake[card]
	draw_set_transform(pos + Vector2(_w * 0.5 * (1.0 - sx), 0), 0.0, Vector2(sx, 1.0))
	if _up[card] == 0:
		draw_mesh(Art.back(_w), null)
		return
	draw_mesh(Art.face(Sim.suit_of(card), _w), null)
	var text: String = Art.RANKS[Sim.rank_of(card)]
	var wide := text.length() > 1
	var fs := int(_w * (0.27 if wide else 0.31))
	draw_string(font, Vector2((0.07 if wide else 0.11) * _w, 0.325 * _w), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.ink(card))

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
