extends Control

## Dominoes' table, seen from above: a felt mat on the deck. Along the top
## the other player's tiles, face down; in the middle the line; under it, on
## the left and clear of the thumb, the boneyard; along the bottom the
## player's own tiles, face up, the ones that fit standing a little proud.
##
## The line grows from its first tile both ways and turns when it reaches the
## side of the mat: one end turns down and comes back under itself, the other
## turns up and goes back over (`lay_line`). A double lies across. The whole
## line is then fitted to the room it has, so a long one is drawn smaller.
##
## Every tile is a sprite for the whole game: a place, a size, which way it
## lies and whether its face shows. `sync` reads the rules and gives each
## tile the place it should now be in, and the tiles go there; nothing else
## animates a move. A tile is one cached mesh for the way it lies (and one
## back each way), drawn under a transform, so nothing is rebuilt to move.
## What changes shape -- the places a chosen tile may go, the bulb's ring,
## the light on the boneyard -- is one small mesh rebuilt only while it
## shows.
##
## A tap on a tile that fits one end lays it there. One that fits both ends
## with different numbers is picked up first, and the two places light: a tap
## on either lays it. A tap on the boneyard draws, when no tile fits.
##
## A tile is also carried: a finger that moves with a tile under it takes the
## tile along, the places it fits light, and it is laid at the end it is let
## go on. Let go on an end it does not fit it is refused, and anywhere else
## it goes back to the hand.

## The player chose a move: `tile * 2 + end`.
signal chosen(move: int)
## The player tapped the boneyard while it is to be drawn from.
signal draw_asked
## Everything `setup` or `sync` set moving has arrived.
signal settled
## A tap that does nothing: "fit" a tile that fits neither end, "draw" the
## boneyard while a tile fits.
signal refused(reason: String)

const Rules = preload("res://versus/dominoes_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")

enum Zone { STOCK, MINE, THEIRS, LINE }

## Half a tile, a square, in a mesh's own space.
const H := 100.0
## Half the length of a row of the line, in halves of a tile.
const ROW := 6.0
## The most a half of a tile on the line is drawn, in pixels.
const UNIT_MAX := 74.0
const PAD := 14.0
const FAR_H := 124.0
const STOCK_H := 112.0
## The scale of a tile in the far hand, in the boneyard, and in the player's
## hand one row or two of seven, or rows of ten.
const FAR_S := 0.46
const STOCK_S := 0.42
const HAND_S := 1.18
const HAND_S_SMALL := 0.86
const STOCK_STEP := 50.0
const ROOM := Vector2(940.0, 1040.0)
const ROOM_PAGE := Vector2(940.0, 800.0)
const LIFT := 18.0
const LIFT_PICKED := 40.0
## A carried tile: how far the finger moves before it is one, how far over
## the finger it rides, how fast it follows, and how far past a place's edge
## it may be let go and still be laid there (in halves of a line's tile).
const DRAG_START := 14.0
const DRAG_RISE := 44.0
const DRAG_SPEED := 32.0
const DRAG_REACH := 0.9
const DRAG_REACH_MIN := 34.0

const FELT := Color("5c9c7c")
const FELT_DEEP := Color("4a8669")
const FELT_LIT := Color("6fae8d")
const IVORY := Color("f7f0df")
const IVORY_EDGE := Color("cbbb97")
const IVORY_LIT := Color("fffaf0")
const INK := Color("2c2a33")
const BRASS := Color("d9a441")
const WOOD := Color("b98457")
const WOOD_LIT := Color("d3a273")
const WOOD_DEEP := Color("7d5334")
const HALO := Color("fff6e0")
const HINT := Color("f9c04a")

## How fast a tile closes on its place (the share left falls by e every
## 1/SPEED s), the look at a landing before the game goes on, and the deal.
const SPEED := 11.0
const WATCH := 0.16
const DEAL := 0.055
## The notches are never the same sound twice: `place` was varied on landing
## only (not with reduced motion), `draw`, `lift` and `refused` were 1.0.
const TICK_VARY := Vector2(0.94, 1.06)
const VARIED := ["place", "draw", "lift", "refused"]

class Sprite:
	var zone := Zone.STOCK
	var pos := Vector2.ZERO
	var to := Vector2.ZERO
	var s := 0.4
	var to_s := 0.4
	## 0 lying, the low number left; 1 upright, low on top; 2 lying, low
	## right; 3 upright, low at the bottom.
	var o := 1
	var up := false
	var fly := false
	var wait := 0.0
	var land := false
	var shown := true

var rules: RefCounted
## The rules' side the player is: its tiles lie along the bottom.
var player := 0
var interactive := false:
	set(v):
		if interactive != v:
			interactive = v
			if not v:
				_picked = -1
				_grab = -1
				_drag = -1
			if rules != null and not _sprites.is_empty():
				_place_all(false)
			_touch()
## A picture, not a game (the Versus tab's card): the line alone, no input.
var still := false
## A tutorial page's table: it moves as a game's does, but hears no finger
## and makes no sound.
var deaf := false
## The rectangle the table takes.
var used_rect := Rect2()
## The room the table is laid out in (`ROOM` at the least, `ROOM_PAGE` on a
## tutorial page) and the scale that fits it to the control.
var _v := Vector2.ZERO
var _k := 1.0

var _sprites: Array[Sprite] = []
var _meshes := {}
var _mat: ArrayMesh
var _over_mesh: ArrayMesh
var _shown: Array = []
var _fx: Node2D
var _run := 0
var _t := 0.0
var _busy_until := 0.0
var _await := false
var _deal_due := false
var _await_at := 0.0
var _zone_line := Rect2()
var _zone_hand := Rect2()
var _zone_stock := Rect2()
## A half of a tile on the line in pixels, and where the line's origin is.
var _unit := UNIT_MAX
var _origin := Vector2.ZERO
## The tile picked up to choose an end for, the bulb's move, the far hand
## turned up, the boneyard lit to be drawn from.
var _picked := -1
var _hint := -1
## The tile under the finger since it came down, where the finger was then
## and the tile's middle from it; the tile being carried, and the end it is
## over now (-1 for none, whether it fits there or not).
var _grab := -1
var _grab_at := Vector2.ZERO
var _grab_off := Vector2.ZERO
var _drag := -1
var _drag_end := -1
var _reveal := false
var _must_draw := false
## How the game ended, "" while it is on.
var _mood := ""
var _down := false
var _shake_tile := -1
var _shake_at := -10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still or deaf else Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	if not still and not deaf:
		_fx = Fx2D.new()
		add_child(_fx)
	_layout()

# --- setting up ---

## The table showing `the_rules` as they stand, the player being `side`.
## With `enter` the tiles are mixed in the middle and dealt out, and
## `settled` is said when the last has arrived.
func setup(the_rules: RefCounted, side: int, enter := false) -> void:
	_run += 1
	rules = the_rules
	player = side
	_picked = -1
	_grab = -1
	_drag = -1
	_hint = -1
	_reveal = false
	_must_draw = false
	_mood = ""
	_down = false
	_await = false
	if _sprites.is_empty():
		for t in Rules.TILES:
			_sprites.append(Sprite.new())
	for sp in _sprites:
		sp.fly = false
		sp.wait = 0.0
		sp.land = false
	_place_all(true)
	_deal_due = false
	if enter and not still:
		if Motion.reduce:
			_expect(Motion.REDUCED_TIME)
		elif _v.x > 0.0:
			_deal()
		else:
			# Not laid out yet: dealt as soon as the table has its room.
			_deal_due = true
			_await = true
			_await_at = INF
	_busy(0.4)
	_touch()

## Every tile starts in a heap on the mat and goes to its place: the
## boneyard's at once, the two hands a tile at a time, turn about.
func _deal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _run * 977 + 5
	var heap := _zone_line.get_center()
	for sp in _sprites:
		sp.pos = heap + Vector2(rng.randf_range(-150.0, 150.0), rng.randf_range(-90.0, 90.0))
		sp.s = 0.5
		sp.fly = true
	for i in rules.stock.size():
		_sprites[rules.stock[i]].wait = 0.25 + 0.012 * i
	for side in 2:
		var hand: PackedInt32Array = rules.hands[side]
		for i in hand.size():
			_sprites[hand[i]].wait = 0.5 + DEAL * (i * 2 + (0 if side == rules.leader else 1))
	_cue("shuffle")
	_expect(WATCH)

## The rules have moved on: every tile goes to where it now belongs.
func sync() -> void:
	if rules == null:
		return
	_picked = -1
	_grab = -1
	_drag = -1
	_hint = -1
	_must_draw = false
	var before: Array[int] = []
	for sp in _sprites:
		before.append(sp.zone)
	_place_all(Motion.reduce)
	var drew := false
	for t in Rules.TILES:
		var sp := _sprites[t]
		if sp.zone == before[t]:
			continue
		if sp.zone == Zone.LINE:
			if Motion.reduce:
				_cue("place")
			else:
				sp.land = true
		elif before[t] == Zone.STOCK:
			drew = true
	if drew:
		_cue("draw")
	_expect(Motion.REDUCED_TIME if Motion.reduce else WATCH)
	_touch()

## The bulb's move (a tile and its end, or Rules.DRAW), -1 for none.
func set_hint(move: int) -> void:
	_hint = move
	_picked = -1
	if _drag >= 0:
		_drag = -1
		_place_all(false)
	_busy(0.3)
	_touch()

## The boneyard is lit: the player has no tile that fits and must draw.
func set_must_draw(on: bool) -> void:
	_must_draw = on
	_busy(0.3)
	_touch()

## The far hand is turned face up (a hand is over), or back down.
func reveal(on := true) -> void:
	_reveal = on
	_place_all(false)
	_busy(0.4)
	_touch()

## The game is over ("won", "lost", "draw"): the far hand is turned up.
func finish(outcome: String) -> void:
	_mood = outcome
	reveal(true)

func is_busy() -> bool:
	for sp in _sprites:
		if sp.fly or sp.wait > 0.0:
			return true
	return _deal_due

## Where a tile is going, the middle of the boneyard's next tile, and where
## a move would put its tile, in the board's own space (a tutorial's finger).
func tile_point(tile: int) -> Vector2:
	return _sprites[tile].to * _k

func stock_point() -> Vector2:
	if rules.stock.is_empty():
		return _zone_stock.get_center() * _k
	return _sprites[rules.stock[rules.stock.size() - 1]].to * _k

func slot_point(move: int) -> Vector2:
	return Vector2(_slot(move >> 1, move & 1).c) * _k

## Where a line of words can stand: across the top of the mat's middle.
func toast_point() -> Vector2:
	return Vector2(_v.x * 0.5, _zone_line.position.y + 54.0) * _k

# --- the line ---

## Where each tile of `plays` lies, in halves of a tile about the first:
## {c, o} a tile, in the order laid. End 1 runs right from the first tile and
## turns down at the side of the mat, end 0 runs left and turns up.
static func lay_line(plays: Array) -> Array:
	var out: Array = []
	if plays.is_empty():
		return out
	var first: int = plays[0].x
	var across := Rules.is_double(first)
	out.append({"c": Vector2.ZERO, "o": 1 if across else 0})
	var half := 0.5 if across else 1.0
	var tall := 1.0 if across else 0.5
	# an arm: its open edge and row, its heading, the way it turns, and how
	# far the last tile reaches from the row's middle
	var arms := [{"x": -half, "y": 0.0, "d": -1.0, "v": -1.0, "tall": tall},
		{"x": half, "y": 0.0, "d": 1.0, "v": 1.0, "tall": tall}]
	for i in range(1, plays.size()):
		var p: Vector3i = plays[i]
		var a: Dictionary = arms[p.y]
		var low: bool = Rules.LO[p.x] == p.z
		var double := Rules.is_double(p.x)
		var d: float = a.d
		if float(a.x) * d + (1.0 if double else 2.0) <= ROW:
			if double:
				out.append({"c": Vector2(a.x + d * 0.5, a.y), "o": 1})
				a.x += d
				a.tall = 1.0
			else:
				# the half that touches the line faces back along it
				out.append({"c": Vector2(a.x + d, a.y), "o": (0 if low else 2) if d > 0.0 else (2 if low else 0)})
				a.x += d * 2.0
				a.tall = 0.5
		else:
			# the turn: this tile stands on the last square of the row, and
			# the row beyond starts from its far half
			var v: float = a.v
			var col: float = a.x - d * 0.5
			var edge: float = a.y + v * float(a.tall)
			out.append({"c": Vector2(col, edge + v), "o": (1 if low else 3) if v > 0.0 else (3 if low else 1)})
			a.y = edge + v * 1.5
			a.d = -d
			a.x = col - d * 0.5
			a.tall = 0.5
	return out

static func _half_size(o: int) -> Vector2:
	return Vector2(1.0, 0.5) if o % 2 == 0 else Vector2(0.5, 1.0)

## Where `tile` would lie were it laid at `end` now: {c, o}, in pixels.
func _slot(tile: int, end: int) -> Dictionary:
	var plays: Array = rules.plays.duplicate()
	if plays.is_empty():
		plays.append(Vector3i(tile, -1, Rules.LO[tile]))
	else:
		plays.append(Vector3i(tile, end, rules.ends[end]))
	var lay := lay_line(plays)
	var last: Dictionary = lay[lay.size() - 1]
	return {"c": _origin + Vector2(last.c) * _unit, "o": last.o}

# --- layout and time ---

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	used_rect = Rect2(Vector2.ZERO, size)
	var room := ROOM_PAGE if deaf else ROOM
	_k = 1.0 if still else minf(1.0, minf(size.x / room.x, size.y / room.y))
	_v = size / _k
	_mat = null
	if rules != null and not _sprites.is_empty():
		if _deal_due:
			_deal_due = false
			_place_all(true)
			_deal()
		else:
			# A deal under way goes on to the places as they now are.
			_place_all(not is_busy())
	queue_redraw()

## Gives every tile its zone and the place, size and lie that go with it.
## With `snap` they are there at once.
func _place_all(snap: bool) -> void:
	if _v.x <= 0.0 or _v.y <= 0.0:
		return
	var mine: PackedInt32Array = rules.hands[player]
	var theirs: PackedInt32Array = rules.hands[1 - player]
	# the player's hand: a row or two of seven, or rows of ten
	var per := 7 if mine.size() <= 14 else 10
	var hs := HAND_S if mine.size() <= 14 else HAND_S_SMALL
	var rows := maxi(1, ceili(mine.size() / float(per)))
	var row_h := 2.0 * H * hs + 16.0
	if still:
		_zone_line = Rect2(Vector2.ZERO, _v).grow(-10.0)
	else:
		var hand_h := rows * row_h + LIFT + PAD
		_zone_hand = Rect2(0.0, _v.y - hand_h, _v.x, hand_h)
		_zone_stock = Rect2(0.0, _zone_hand.position.y - STOCK_H, _v.x, STOCK_H)
		_zone_line = Rect2(PAD, FAR_H, _v.x - 2.0 * PAD, _zone_stock.position.y - FAR_H - 6.0)
	for sp in _sprites:
		sp.shown = false
	# the line, fitted to its room
	var lay := lay_line(rules.plays)
	var box := Rect2()
	for i in lay.size():
		var hsz := _half_size(lay[i].o)
		var r := Rect2(Vector2(lay[i].c) - hsz, hsz * 2.0)
		box = r if i == 0 else box.merge(r)
	_unit = UNIT_MAX
	if not lay.is_empty():
		_unit = minf(UNIT_MAX if not still else 1000.0,
			minf(_zone_line.size.x / (box.size.x + 0.5), _zone_line.size.y / (box.size.y + 0.5)))
	_origin = _zone_line.get_center() - box.get_center() * _unit
	for i in lay.size():
		var sp := _sprites[rules.plays[i].x]
		_aim(sp, Zone.LINE, _origin + Vector2(lay[i].c) * _unit, _unit / H, lay[i].o, true, snap)
	if still:
		return
	var step := H * hs + 12.0
	for i in mine.size():
		if mine[i] == _drag:
			# in the hand still, and wherever the finger has it
			_sprites[mine[i]].shown = true
			continue
		var row := i / per
		var in_row := mini(per, mine.size() - row * per)
		var at := Vector2(_v.x * 0.5 + (i % per - (in_row - 1) * 0.5) * step,
			_zone_hand.position.y + LIFT + row * row_h + H * hs)
		if interactive:
			if mine[i] == _picked:
				at.y -= LIFT_PICKED
			elif rules.fits(mine[i], 0) or rules.fits(mine[i], 1):
				at.y -= LIFT
		_aim(_sprites[mine[i]], Zone.MINE, at, hs, 1, true, snap)
	var far_step := minf(H * FAR_S + 8.0, (_v.x - 2.0 * PAD - H * FAR_S) / maxf(1.0, theirs.size() - 1.0))
	for i in theirs.size():
		var at := Vector2(_v.x * 0.5 + (i - (theirs.size() - 1) * 0.5) * far_step, FAR_H * 0.5 + 2.0)
		_aim(_sprites[theirs[i]], Zone.THEIRS, at, FAR_S, 1, _reveal, snap)
	for i in rules.stock.size():
		_aim(_sprites[rules.stock[i]], Zone.STOCK, _stock_at(i), STOCK_S, 1, false, snap)

## Where the boneyard's tile `i` lies: the two that are never drawn first,
## a little apart from the rest.
func _stock_at(i: int) -> Vector2:
	var x := PAD + 18.0 + H * STOCK_S * 0.5 + i * STOCK_STEP + (22.0 if i >= Rules.KEEP else 0.0)
	return Vector2(x, _zone_stock.position.y + STOCK_H * 0.5)

func _aim(sp: Sprite, zone: int, to: Vector2, s: float, o: int, up: bool, snap: bool) -> void:
	if sp.zone != zone and not snap:
		sp.fly = true
	sp.zone = zone
	sp.shown = true
	sp.to = to
	sp.to_s = s
	sp.o = o
	sp.up = up
	if snap:
		sp.pos = to
		sp.s = s
		sp.fly = false

func _process(delta: float) -> void:
	_t += delta
	var live := _t < _busy_until
	var k := 1.0 - exp(-delta * SPEED)
	var flying := false
	for t in _sprites.size():
		var sp := _sprites[t]
		if t == _drag:
			# under a finger: it keeps up, and is not a move to wait for
			live = true
			var kd := 1.0 if Motion.reduce else 1.0 - exp(-delta * DRAG_SPEED)
			sp.pos = sp.pos.lerp(sp.to, kd)
			sp.s = lerpf(sp.s, sp.to_s, kd)
			continue
		if sp.wait > 0.0:
			sp.wait -= delta
			flying = true
			live = true
			continue
		if sp.pos != sp.to or sp.s != sp.to_s:
			live = true
			sp.pos = sp.pos.lerp(sp.to, k)
			sp.s = lerpf(sp.s, sp.to_s, k)
			if sp.pos.distance_squared_to(sp.to) < 2.0:
				sp.pos = sp.to
				sp.s = sp.to_s
				if sp.land:
					sp.land = false
					_cue("place")
				if sp.fly:
					sp.fly = false
					_await_at = maxf(_await_at, _t + WATCH)
		if sp.fly:
			flying = true
	if _await and not flying and _t >= _await_at:
		_await = false
		settled.emit()
	if _must_draw or _hint >= 0 or _picked >= 0 or _drag >= 0:
		live = live or not Motion.reduce
	if live:
		queue_redraw()

## `settled` is owed once everything has landed, and no sooner than
## `seconds` from now.
func _expect(seconds: float) -> void:
	_await = true
	_await_at = _t + seconds

func _busy(seconds: float) -> void:
	_busy_until = maxf(_busy_until, _t + seconds)

func _touch() -> void:
	queue_redraw()

func _cue(cue_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if _fx != null:
		if cue_name in VARIED:
			pitch *= randf_range(TICK_VARY.x, TICK_VARY.y)
		_fx.cue(cue_name, pitch, volume_db)

# --- input ---

func _rect_of(sp: Sprite) -> Rect2:
	var hsz := _half_size(sp.o) * H * sp.to_s
	return Rect2(sp.to - hsz, hsz * 2.0)

func _gui_input(event: InputEvent) -> void:
	if still or deaf:
		return
	var press := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		press = event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		at = event.position
	elif event is InputEventScreenDrag:
		if event.index == 0 and _down:
			accept_event()
			_carry(event.position / _k)
		return
	elif event is InputEventMouseMotion:
		if _down and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			accept_event()
			_carry(event.position / _k)
		return
	else:
		return
	accept_event()
	if press:
		_down = true
		_grab = -1
		_drag = -1
		if interactive:
			_grab = _hand_tile(at / _k)
			if _grab >= 0:
				_grab_at = at / _k
				_grab_off = _sprites[_grab].to - _grab_at
		return
	if not _down:
		return
	_down = false
	var carried := _drag
	_grab = -1
	if carried >= 0:
		_drop(carried)
	elif interactive:
		_tap(at / _k)

## The player's tile under `at`, -1 for none.
func _hand_tile(at: Vector2) -> int:
	var mine: PackedInt32Array = rules.hands[player]
	for i in range(mine.size() - 1, -1, -1):
		if _rect_of(_sprites[mine[i]]).grow(5.0).has_point(at):
			return mine[i]
	return -1

## The finger is at `at` and has not let go: the tile it came down on goes
## with it once it has moved far enough to mean it, riding a little over the
## finger, and over a place it fits it lies as it would there.
func _carry(at: Vector2) -> void:
	if not interactive or _grab < 0:
		return
	if _drag < 0:
		if at.distance_to(_grab_at) < DRAG_START:
			return
		_drag = _grab
		_picked = -1
		_hint = -1
		_cue("lift")
		_place_all(false)
	var sp := _sprites[_drag]
	sp.to = at + _grab_off + Vector2(0.0, -DRAG_RISE)
	_drag_end = _end_under(_drag, sp.to)
	sp.o = 1
	sp.to_s = HAND_S if sp.to.y > _zone_hand.position.y else maxf(_unit / H, 0.6)
	if _drag_end >= 0 and rules.fits(_drag, _drag_end):
		var slot := _slot(_drag, _drag_end)
		sp.o = slot.o
		sp.to_s = _unit / H
	_touch()

## The end whose place for `tile` is under `c`, the nearer of two, -1 for
## neither. The place is there whether the tile fits it or not.
func _end_under(tile: int, c: Vector2) -> int:
	var best := -1
	var near := INF
	for end in 2:
		var slot := _slot(tile, end)
		var hsz := _half_size(slot.o) * _unit
		var reach := maxf(DRAG_REACH_MIN, _unit * DRAG_REACH)
		if not Rect2(Vector2(slot.c) - hsz, hsz * 2.0).grow(reach).has_point(c):
			continue
		var d := c.distance_squared_to(slot.c)
		# of two as near, the one it fits
		if d < near - 1.0 or (d < near + 1.0 and rules.fits(tile, end)):
			near = d
			best = end
	return best

## The carried tile is let go: laid at the end it is over if it fits there,
## refused if it does not, and back in the hand from anywhere else.
func _drop(tile: int) -> void:
	var end := _drag_end
	_drag = -1
	_drag_end = -1
	if not interactive or not rules.hands[player].has(tile):
		_place_all(false)
		_touch()
		return
	if end >= 0 and rules.fits(tile, end):
		chosen.emit(tile * 2 + end)
	elif end >= 0:
		_shake_tile = tile
		_shake_at = _t
		_busy(0.4)
		_cue("refused")
		refused.emit("fit")
	# not laid after all: home
	if rules.hands[player].has(tile):
		_place_all(false)
	_touch()

func _tap(at: Vector2) -> void:
	# the two places a picked tile may go
	if _picked >= 0:
		for end in 2:
			var slot := _slot(_picked, end)
			var hsz := _half_size(slot.o) * _unit
			if Rect2(Vector2(slot.c) - hsz, hsz * 2.0).grow(maxf(18.0, _unit * 0.5)).has_point(at):
				var move := _picked * 2 + end
				_picked = -1
				chosen.emit(move)
				return
	var mine: PackedInt32Array = rules.hands[player]
	for i in range(mine.size() - 1, -1, -1):
		var tile := mine[i]
		if not _rect_of(_sprites[tile]).grow(5.0).has_point(at):
			continue
		var a: bool = rules.fits(tile, 0)
		var b: bool = rules.fits(tile, 1)
		if not a and not b:
			_shake_tile = tile
			_shake_at = _t
			_busy(0.4)
			_cue("refused")
			refused.emit("fit")
		elif a and b and not rules.plays.is_empty() and rules.ends[0] != rules.ends[1]:
			_picked = -1 if _picked == tile else tile
			_hint = -1
			_cue("lift")
			_place_all(false)
			_busy(0.4)
		else:
			_picked = -1
			chosen.emit(tile * 2 + (0 if a else 1))
		_touch()
		return
	if Rect2(_zone_stock.position, Vector2(_stock_at(rules.stock.size()).x + 10.0, STOCK_H)).has_point(at) and not rules.stock.is_empty():
		if _must_draw:
			draw_asked.emit()
		else:
			_cue("refused")
			refused.emit("draw")
		return
	if _picked >= 0:
		_picked = -1
		_place_all(false)
		_touch()

# --- drawing ---

func _draw() -> void:
	if rules == null or size.x <= 0.0 or _sprites.is_empty():
		return
	if _mat == null:
		_mat = _build_mat()
	_over_mesh = _build_over()
	_shown = [_mat, _over_mesh]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k, _k))
	draw_mesh(_mat, null)
	# what lies still first, then what is in the air over it
	for pass_no in 2:
		for t in Rules.TILES:
			var sp := _sprites[t]
			if not sp.shown or ((sp.fly and sp.wait <= 0.0) or t == _drag) != (pass_no == 1):
				continue
			var at := sp.pos
			if t == _shake_tile:
				var since := _t - _shake_at
				if since < 0.3 and not Motion.reduce:
					at.x += sin(since * 60.0) * 6.0 * (1.0 - since / 0.3)
			var up := sp.up and sp.wait <= 0.0
			draw_mesh(_mesh(t if up else -1, sp.o), null, Transform2D(0.0, Vector2(sp.s, sp.s), 0.0, at))
	if _over_mesh != null:
		draw_mesh(_over_mesh, null)

## The mesh of a tile lying the way `o` says, -1 for a back.
func _mesh(tile: int, o: int) -> ArrayMesh:
	var key := (tile * 4 + o) if tile >= 0 else -1 - (o % 2)
	if not _meshes.has(key):
		_meshes[key] = _build_tile(tile, o)
	return _meshes[key]

## One tile about the origin: its shadow, the ivory's side and top, and face
## up the line across its middle with a brass pin, and each half's pips.
static func _build_tile(tile: int, o: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var upright := o % 2 == 1
	var sz := Vector2(H, 2.0 * H) if upright else Vector2(2.0 * H, H)
	var body := sz - Vector2(8.0, 8.0)
	var at := -body * 0.5
	var back := tile < 0
	b.fan(Face.Builder.round_rect(at + Vector2(1.0, 9.0), body, 16.0), Color(0.1, 0.06, 0.02, 0.26))
	b.fan(Face.Builder.round_rect(at + Vector2(0.0, 5.0), body, 16.0), WOOD_DEEP if back else IVORY_EDGE)
	b.fan(Face.Builder.round_rect(at, body, 16.0), WOOD if back else IVORY)
	b.stroke(Face.Builder.round_rect(at + Vector2(5.0, 5.0), body - Vector2(10.0, 10.0), 12.0), 3.0,
		Color(WOOD_LIT, 0.8) if back else Color(IVORY_LIT, 0.9), true)
	if back:
		var d := 13.0
		b.polygon(PackedVector2Array([Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0)]), Color(WOOD_LIT, 0.9))
		return b.mesh()
	var along := Vector2(0.0, 1.0) if upright else Vector2(1.0, 0.0)
	var cross := Vector2(along.y, along.x)
	b.stroke(PackedVector2Array([cross * -30.0, cross * 30.0]), 4.0, Color(INK, 0.75))
	b.disc(Vector2(0.0, 1.0), 8.0, BRASS.darkened(0.25))
	b.disc(Vector2.ZERO, 7.0, BRASS)
	b.disc(Vector2(-2.0, -2.0), 2.5, Color(1, 1, 1, 0.6))
	# the low number's half comes first along the tile for 0 and 1
	var first: int = Rules.LO[tile] if o < 2 else Rules.HI[tile]
	var second: int = Rules.HI[tile] if o < 2 else Rules.LO[tile]
	_pips(b, along * -H * 0.5, first, upright)
	_pips(b, along * H * 0.5, second, upright)
	return b.mesh()

## A half's pips about `c`: the die's patterns, the six in two lines along
## the tile.
static func _pips(b: Face.Builder, c: Vector2, n: int, upright: bool) -> void:
	var g := 25.0
	var spots: Array = []
	if n % 2 == 1:
		spots.append(Vector2.ZERO)
	if n >= 2:
		spots.append(Vector2(-g, -g))
		spots.append(Vector2(g, g))
	if n >= 4:
		spots.append(Vector2(g, -g))
		spots.append(Vector2(-g, g))
	if n == 6:
		spots.append(Vector2(-g, 0.0))
		spots.append(Vector2(g, 0.0))
	for p: Vector2 in spots:
		var q := p if upright else Vector2(p.y, -p.x)
		b.disc(c + q + Vector2(0.0, 1.0), 9.5, Color(1, 1, 1, 0.5))
		b.disc(c + q, 9.0, INK)

## The felt, with a stitched line round it, and the darker beds the two
## hands and the boneyard lie in.
func _build_mat() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(Vector2(0.0, 6.0), _v - Vector2(0.0, 6.0), 30.0), Color(0.12, 0.07, 0.03, 0.3))
	b.fan(Face.Builder.round_rect(Vector2.ZERO, _v - Vector2(0.0, 6.0), 30.0), FELT)
	if not still:
		b.fan(Face.Builder.round_rect(Vector2(PAD, 8.0), Vector2(_v.x - 2.0 * PAD, FAR_H - 12.0), 20.0), Color(FELT_DEEP, 0.7))
		b.fan(Face.Builder.round_rect(Vector2(PAD, _zone_stock.position.y + 6.0),
			Vector2(_stock_at(Rules.TILES - Rules.HAND * 2).x - PAD - 8.0, STOCK_H - 12.0), 20.0), Color(FELT_DEEP, 0.7))
		# the two that stay have a bed of their own, fenced off
		var fence := _stock_at(Rules.KEEP).x - H * STOCK_S * 0.5 - 13.0
		b.stroke(PackedVector2Array([Vector2(fence, _zone_stock.position.y + 20.0), Vector2(fence, _zone_stock.end.y - 20.0)]), 4.0, Color(FELT_LIT, 0.9))
	b.stroke(Face.Builder.round_rect(Vector2(7.0, 7.0), _v - Vector2(14.0, 20.0), 24.0), 2.5, Color(FELT_LIT, 0.8), true)
	return b.mesh()

static func _frame(b: Face.Builder, c: Vector2, half: Vector2, grow: float, width: float, col: Color) -> void:
	b.stroke(Face.Builder.round_rect(c - half - Vector2.ONE * grow, (half + Vector2.ONE * grow) * 2.0, 14.0 + grow), width, col, true)

## What lies over the tiles: the places a picked tile may go, the ring round
## it, the bulb's ring and place, the light on the boneyard.
func _build_over() -> ArrayMesh:
	if still or rules == null:
		return null
	var b := Face.Builder.new()
	var beat := 0.0 if Motion.reduce else 0.5 + 0.5 * sin(_t * 5.0)
	if _picked >= 0 and interactive:
		var sp := _sprites[_picked]
		_frame(b, sp.pos, _half_size(sp.o) * H * sp.s, 3.0, 6.0, HALO)
		for end in 2:
			var slot := _slot(_picked, end)
			var half := _half_size(slot.o) * _unit - Vector2.ONE * 4.0
			b.fan(Face.Builder.round_rect(Vector2(slot.c) - half, half * 2.0, 10.0), Color(HALO, 0.3 + 0.15 * beat))
			_frame(b, slot.c, half, 2.0 * beat, 5.0, HALO)
	if _drag >= 0 and interactive:
		# the places the carried tile fits, the one it is over brighter
		for end in (1 if rules.plays.is_empty() else 2):
			if not rules.fits(_drag, end):
				continue
			var slot := _slot(_drag, end)
			var half := _half_size(slot.o) * _unit - Vector2.ONE * 4.0
			var over := end == _drag_end
			# the tile lies in the place it is over: a frame round it, no wash
			if not over:
				b.fan(Face.Builder.round_rect(Vector2(slot.c) - half, half * 2.0, 10.0), Color(HALO, 0.3 + 0.15 * beat))
			_frame(b, slot.c, half, (5.0 if over else 0.0) + 2.0 * beat, 5.0, HALO)
	if _hint >= 0:
		if _hint == Rules.DRAW:
			_light_stock(b, HINT, beat)
		elif rules.hands[player].has(_hint >> 1):
			var sp := _sprites[_hint >> 1]
			_frame(b, sp.pos, _half_size(sp.o) * H * sp.s, 3.0 + 3.0 * beat, 7.0, HINT)
			var slot := _slot(_hint >> 1, _hint & 1)
			var half := _half_size(slot.o) * _unit - Vector2.ONE * 4.0
			b.fan(Face.Builder.round_rect(Vector2(slot.c) - half, half * 2.0, 10.0), Color(HINT, 0.28))
			_frame(b, slot.c, half, 2.0 * beat, 6.0, HINT)
	if _must_draw and _hint != Rules.DRAW:
		_light_stock(b, HALO, beat)
	return null if b.verts.is_empty() else b.mesh()

## A frame round the boneyard's tile that would be drawn.
func _light_stock(b: Face.Builder, col: Color, beat: float) -> void:
	if rules.stock.size() <= Rules.KEEP:
		return
	var sp := _sprites[rules.stock[rules.stock.size() - 1]]
	_frame(b, sp.pos, _half_size(sp.o) * H * sp.s, 4.0 + 4.0 * beat, 6.0, col)
